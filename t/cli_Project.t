use strict;
use warnings;
use Test::More;

require_ok("Murakumo::CLI::Project");

my $obj = Murakumo::CLI::Project->new;

my @methods = qw(
  is_exist
  auth
);
can_ok($obj, @methods);

done_testing();
