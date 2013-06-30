use strict;
use warnings;
use Test::More;

require_ok("Murakumo::CLI::Admin");

isa_ok(Murakumo::CLI::Admin->new, "Murakumo::CLI::DB");

my @methods = qw(
  is_admin_access
  vps_define_list
  vps_list
  project_list
  project_register
);
can_ok("Murakumo::CLI::Admin", @methods);

done_testing();
