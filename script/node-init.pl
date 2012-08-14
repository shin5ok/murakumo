#!/usr/bin/env perl
use strict;
use warnings;
use JSON;
use Carp;
use FindBin;
use lib qq($FindBin::Bin/../lib);
use Murakumo::CLI::DB;

our $tmpfile;
my $node = shift;
my $api_key = make_api_key();
chomp ( my $uuid = `uuidgen` );
if (make_key_file_over_ssh( $node, { uuid => $uuid, api_key => $api_key, } )) {

  my $db = Murakumo::CLI::DB->new->schema; 
  my $rs = $db->resultset('NodeDefine');
  $rs->create({ name => $node, uuid => $uuid, api_key => $api_key });

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
    return $? == 0;
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
  -f $tmpfile
    and unlink $tmpfile;
}

