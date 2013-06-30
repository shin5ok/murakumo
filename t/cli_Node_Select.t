use strict;
use warnings;
use Test::More;

require_ok("Murakumo::CLI::Node::Select");

my $obj = Murakumo::CLI::Node::Select->new;
isa_ok($obj, "Murakumo::CLI::DB");

my @methods = qw(
  select
  get_auto_select_nodes
);
can_ok($obj, @methods);

done_testing();


