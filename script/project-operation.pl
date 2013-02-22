#!/usr/bin/env perl
use strict;
use warnings;
use JSON;
use Carp;
use FindBin;
use lib qq($FindBin::Bin/../../lib);
use Murakumo::CLI::DB;
use opts;

opts my $project_id => 'Str';

my $mode = shift || "";
if ($> != 0) {
  croak "*** $0 must be run by super user";
}

if ($project_id eq 'admin') {
  croak "*** 'admin' is invalid project id";
}

if ($mode eq 'add') {
  if (! $project_id) {
    usage();
    exit 255;
  }
} else {
  usage();
  exit 0;
}

my $db = Murakumo::CLI::DB->new->schema;
my $rs = $db->resultset('Project');

chomp( my $api_key = `uuidgen` );
$api_key =~ s/\-//g;

$rs->create({
   project_id => $project_id,
   api_key    => $api_key,
});

my ($result) = $rs->search({ project_id => $project_id });

if (! $result) {
  croak "*** register failure??? project_id may be too long???";
}

print << "__MESSAGE__";
[project registered successful]
  project_id: $project_id
  api_key   : $api_key

__MESSAGE__


sub usage {
  print << "__USAGE__";
(root)# $0 add --project_id integer
  ex:
  (root)# $0 add --project_id 00000001

__USAGE__
}


