use strict;
use warnings;
use Test::More;

require_ok("Murakumo::CLI::Job");

my $obj = Murakumo::CLI::Job->new;
isa_ok($obj, "Murakumo::CLI::DB");

my @methods = qw(
  update
  get_status
  delete
  is_locked_by_uuid
  create
);
can_ok($obj, @methods);

done_testing();

