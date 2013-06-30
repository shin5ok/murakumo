use strict;
use warnings;
use Test::More;

require_ok("Murakumo::CLI::Node");

my $obj = Murakumo::CLI::Node->new;

my @methods = qw(
  wwwua
  make_uri
  select
  api_post
  api_json_post
  is_valid_node
  register
  list
  is_available
);
can_ok($obj, @methods);

ok($obj->wwwua, q{LWP::UserAgent});

done_testing();




