use strict;
use warnings;

use Config::General;  

my $c = Config::General->new( shift );
use Data::Dumper;
warn Dumper $c;

