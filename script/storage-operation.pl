#!/usr/bin/env perl
use strict;
use warnings;
use JSON;
use Carp;
use FindBin;
use lib qq($FindBin::Bin/../../lib);
use Murakumo::CLI::DB;
use opts;

if ($> != 0) {
  croak "*** $0 must be run by super user";
}

my $mode = shift || "";
opts my $export_path => 'Str',
     my $host        => 'Str',
     my $type        => 'Str',
     my $priority    => 'Int';

$priority ||= 100;
$type     ||= "nfs";
if ($mode eq 'add' and ( ! $host or ! $export_path ) ) {
  usage();
  exit 255;
} else {
  usage();
  exit 0;
}

my $db = Murakumo::CLI::DB->new->schema; 
my $rs = $db->resultset('Storage');

# +-------------+--------------+------+-----+-------------------+-----------------------------+
# | Field       | Type         | Null | Key | Default           | Extra                       |
# +-------------+--------------+------+-----+-------------------+-----------------------------+
# | uuid        | varchar(48)  | NO   | PRI |                   |                             |
# | export_path | varchar(255) | YES  |     | NULL              |                             |
# | mount_path  | varchar(255) | YES  |     | NULL              |                             |
# | host        | varchar(64)  | YES  |     | NULL              |                             |
# | type        | varchar(8)   | YES  |     | NULL              |                             |
# | available   | int(128)     | YES  |     | NULL              |                             |
# | priority    | int(8)       | YES  |     | 0                 |                             |
# | regist_time | timestamp    | NO   |     | CURRENT_TIMESTAMP | on update CURRENT_TIMESTAMP |
# +-------------+--------------+------+-----+-------------------+-----------------------------+

my $uuid = make_uuid();
my $params = {
  uuid        => $uuid,
  export_path => $export_path,
  host        => $host,
  mount_path  => make_mount_path( $uuid ),
  type        => $type,
  available   => 1,
  priority    => $priority,
};

$rs->create( $params );

print "[storage registered successful]\n";
for my $name ( keys %$params ) {
  printf "%-16s: %s\n", $name, $params->{$name};
}
print "\n";

sub make_uuid {
  my $uuid = `uuidgen`;
  chomp $uuid;
  $uuid;
}

sub make_mount_path {
  sprintf "/nfs/%s", shift;
}

sub usage {
  print << "__USAGE__";
(root)# $0 add --export_path string --host string [ --type string --priority int ]
        (attention: --type support for 'nfs' only)
  ex:
  (root)# $0 add --export_path /nfs/vm --host 192.168.1.24


__USAGE__
}

