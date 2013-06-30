use strict;
use warnings;
use Test::More;

require_ok("Murakumo::CLI::VPS_Define");

my $obj = Murakumo::CLI::VPS_Define->new;

my @methods = qw(
  info_include_tmp
  info
  list
  all_deleted
  all_cancel_deleted
  delete
  create_disk_param_array
  create_or_modify
  list_template
  info_list
  list_from_db
  tag_list
  record_cloning
  commit_define
  cancel_define
  is_valid_vps_for_project
  is_template_uuid
  set_proxy_vlan_id
);

can_ok($obj, @methods);

done_testing();


