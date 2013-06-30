use strict;
use warnings;
use Test::More;

BEGIN {
  use_ok("Murakumo::CLI::Utils");
};

can_ok("main", "dumper");
can_ok("main", "is_debug");
can_ok("main", "logging");

my $obj = Murakumo::CLI::Utils->new;

my @methods = qw(
  user_agent
  now_string
  wwwua
  create_uuid
  make_uri
  my_hostname
  config
  api_post
  config
  create_random_mac
  get_api_key
  is_valid_api_key
  is_debug
  logging
);
can_ok($obj, @methods);

isa_ok( $obj->now, "DateTime" );

my $like_uuid = qr/
    ^
      [0-9a-f]{8} \-
      [0-9a-f]{4} \-
      [0-9a-f]{4} \-
      [0-9a-f]{4} \-
      [0-9a-f]{12}
    $
/x;
like( $obj->create_uuid, qr/$like_uuid/, "create uuid ok" );

is( ref $obj->config, q{HASH}, "get config is ok" );

isa_ok( $obj->wwwua, q{LWP::UserAgent} );

done_testing();

