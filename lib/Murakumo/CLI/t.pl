#!/usr/bin/env perl
use warnings;
use strict;
use lib qw(/home/smc/Murakumo/lib);
use Murakumo::CLI::Schema;
sub {
  local $ENV{DBIC_TRACE} = 1;
  my $schema = Murakumo::CLI::Schema->connect('dbi:mysql:dbname=vpsdb', 'root', 'MCsquare');
  my $rs_vps = $schema->resultset('Vps')->search;
  my @rs = $rs_vps->search;
  warn @rs. "";
  chomp ( my $uuid = `uuidgen` );
  $rs_vps->create({ vps_name => "test-$uuid" });
}->()
