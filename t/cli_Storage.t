use strict;
use warnings;
use Test::More;

require_ok("Murakumo::CLI::Storage");

my $obj = Murakumo::CLI::Storage->new;

my @methods = qw(
  info
  select
  list
  register_status
);

can_ok($obj, @methods);

done_testing();


