use strict;
use warnings;
use Test::More;

use JSON;

use Catalyst::Test 'Murakumo';
use Murakumo::Controller::Admin;

my $api_key   = $ENV{MURAKUMO_API_KEY};
my $admin_key = $ENV{MURAKUMO_ADMIN_KEY};
my $api_uri   = $ENV{MURAKUMO_API_URI};

my @gets = qw(
  vps_define_list_all
  vps_list_all
  project_list
  ip_with_name
);

for my $uri_path ( @gets ) {
  my $path = qq{/admin/$uri_path};
  $path .= "?admin_key=$admin_key";
  my ($r, $c) = ctx_request($path);

  ok($r->is_success);

  eval {
    my $ref = to_json $r->content;
    is(ref $ref, 'HASH');
    is($ref->{result}, 1);
  };
}

for my $uri_path ( @gets ) {
  my $path = qq{/admin/$uri_path};
  $path .= "?api_key=$api_key";
  my ($r, $c) = ctx_request($path);

  ok(! $r->is_success);

  eval {
    my $ref = to_json $r->content;
    is(ref $ref, 'HASH');
    is($ref->{result}, 0);
  };
}


done_testing();
