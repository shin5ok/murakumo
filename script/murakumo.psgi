#!/usr/bin/env perl
use strict;
use warnings;
use Murakumo;

Murakumo->setup_engine('PSGI');
my $app = sub { Murakumo->run(@_) };

