use strict;
use warnings;

use Config::General;
my $x = Config::General->new(shift);

use Data::Dumper;
warn Dumper $x->getall;
