#!/usr/bin/env perl
use strict;
use warnings;
use JSON;
use Carp;
use FindBin;
use lib qq($FindBin::Bin/../../lib);
use Murakumo::CLI::DB;

if ($> != 0) {
  croak "*** $0 must be run by super user";
}

our $tmpfile;
my $node = shift;

if (! $node) {
  _usage();
  exit 0;
}
my $auto_select = shift;

$auto_select //= 1;

my $api_key = make_api_key();
chomp ( my $uuid = `uuidgen` );
my $db = Murakumo::CLI::DB->new->schema; 
my $rs = $db->resultset('NodeDefine');
if (make_key_file_over_ssh( $node, { node_uuid => $uuid, api_key => $api_key, } )) {
  $rs->create({ name => $node, uuid => $uuid, api_key => $api_key, auto_select => $auto_select, });
}

sub make_key_file_over_ssh {
  my $node     = shift;
  my $hash_ref = shift;
  my $hostname = `ssh $node hostname`;
  chomp $hostname;
  if ( $hostname ne $node ) {
    croak "make_key_file_over_ssh is failure on ssh( hostname error: $hostname ne $node )";
  }

  $tmpfile = "$node.$$." . rand();
  open my $fh, ">", $tmpfile;
  flock $fh, 2;
  print {$fh} encode_json( $hash_ref );
  close $fh;

  local $?;
  if (-e $tmpfile) {
    system "chmod 600 $tmpfile";
    system "scp $tmpfile $node:/root/murakumo_node.key";
    system "ssh $node /etc/init.d/murakumo_node_submit stop";
    sleep 1;
    system "ssh $node /etc/init.d/murakumo_node_submit start";
    return 1;

  }

  return 0;

}

sub make_api_key {
  my $uuid = lc `uuidgen`;
  chomp $uuid;
  $uuid =~ s/\-//g;
  $uuid;
}

END {
  ( $tmpfile and -f $tmpfile )
    and unlink $tmpfile;
}

sub _usage {
  print << "_END_OF_MESSAGE_";
  (root) # $0 hostname-of-node auto_select_flag
  ex:
  (root) # $0 node000 1
  (root) # $0 node999 0

_END_OF_MESSAGE_
}


