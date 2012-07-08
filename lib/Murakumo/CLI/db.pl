#!/usr/bin/env perl
use strict;
use warnings;
use lib q(/home/smc/Murakumo/lib);
use Data::Dumper;
BEGIN {
warn 1;
use Murakumo::CLI::DB::VPS;
warn 2;
};
my $x = Murakumo::CLI::DB::VPS->new->list;

warn Dumper $x;

warn Dumper \%INC;

 
1;
