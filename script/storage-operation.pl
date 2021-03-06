#!/usr/bin/env murakumo-perl
use strict;
use warnings;
use JSON;
use Carp;
use FindBin;
use lib qq($FindBin::Bin/../../lib);
use Murakumo::CLI::DB;
use opts;

opts my $export_path => 'Str',
     my $host        => 'Str',
     my $tag         => 'Str',
     my $type        => 'Str',
     my $priority    => 'Int';

my @storage_types = qw( nfs glusterfs );

if ($> != 0) {
  croak "*** $0 must be run by super user";
}

my $mode = shift || "";
$priority ||= 100;
$type     ||= "nfs";
if ($mode eq 'add') {
  if ( ! $host or ! $export_path ) {
    usage();
    exit 255;
  }
} else {
  usage();
  exit 0;
}

if (! grep { $_ eq $type } @storage_types) {
  usage();
  exit 255;
}

my $db = Murakumo::CLI::DB->new->schema;
my $rs = $db->resultset('Storage');

# +-------------+--------------+------+-----+-------------------+-----------------------------+
# | Field       | Type         | Null | Key | Default           | Extra                       |
# +-------------+--------------+------+-----+-------------------+-----------------------------+
# | uuid        | varchar(48)  | NO   | PRI |                   |                             |
# | tag         | varchar(32)  | YES  |     | NULL              |                             |
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
  storage_tag => $tag // qq{},
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
  my $storage_type_string = join " / ",@storage_types;

  print << "__USAGE__";
(root)# $0 add --export_path string --host string [ --type string --priority int --tag ]
        (attention: --type support $storage_type_string)
  ex:
  (root)# $0 add --export_path /nfs/vm --host 192.168.1.24 --tag FOR_BACKUP


__USAGE__
}

