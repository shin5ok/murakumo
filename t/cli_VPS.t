use strict;
use warnings;
use Test::More;

require_ok("Murakumo::CLI::VPS");

my $obj = Murakumo::CLI::VPS->new;
isa_ok( $obj, q{Murakumo::CLI::DB} );

my @methods = qw(
  vps_register
  list
  get_node
  set_tmp_active_vps
  unset_tmp_active_vps
  is_active_vps
);

done_testing();


