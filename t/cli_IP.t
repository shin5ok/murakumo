use strict;
use warnings;
use Test::More;

require_ok("Murakumo::CLI::IP");

my $obj = Murakumo::CLI::IP->new;
isa_ok( $obj, "Murakumo::CLI::DB" );

my @methods = qw(
  reserve_ip
  get_assign_ip
  add_ip
  set_free_ip
  commit_assign_ip
  cancel_reserve_ip
  release_ip
  list_count
  list
  ip_with_name
);

can_ok("Murakumo::CLI::IP", @methods);

done_testing();


