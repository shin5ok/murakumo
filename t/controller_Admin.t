use strict;
use warnings;
use Test::More;

use URI;
use JSON;

use Catalyst::Test 'Murakumo';
use Murakumo::Controller::Admin;

my $api_key    = $ENV{MURAKUMO_API_KEY};
my $admin_key  = $ENV{MURAKUMO_ADMIN_KEY};
my $api_uri    = $ENV{MURAKUMO_API_URI};
$admin_key   //= qq{};

subtest "api /admin/vps_define_list_all" => sub {
  my $path = URI->new( qq{/admin/vps_define_list_all} );
  {
    $path->query_form( admin_key => $admin_key );

    my ($r, $c) = ctx_request( $path );

    ok($r->is_success);

    my $ref;
    eval {
      $ref = decode_json $r->content;
    };
    is(ref $ref, 'HASH');
    is(ref $ref->{data}, 'ARRAY');
    is($ref->{result}, 1);
  }

  {
    $path->query_form( key => $api_key );

    my ($r, $c) = ctx_request( $path );

    ok(! $r->is_success);
    is($r->code, 403);
  }

};

subtest "api /admin/vps_list_all" => sub {
  my $path = URI->new( qq{/admin/vps_list_all} );
  $path->query_form( admin_key => $admin_key );

  my ($r, $c) = ctx_request( $path );

  ok($r->is_success);

  my $ref;
  eval {
    $ref = decode_json $r->content;
  };
  is(ref $ref, 'HASH');
  is(ref $ref->{data}, 'ARRAY');
  is($ref->{result}, 1);

  {
    $path->query_form( key => $api_key );

    my ($r, $c) = ctx_request( $path );

    ok(! $r->is_success);
    is($r->code, 403);
  }

};

subtest "api /admin/project_list" => sub {
  my $path = URI->new( qq{/admin/project_list} );
  $path->query_form( admin_key => $admin_key );

  my ($r, $c) = ctx_request( $path );

  ok($r->is_success);

  my $ref;
  eval {
    $ref = decode_json $r->content;
  };
  is(ref $ref, 'HASH');
  is(ref $ref->{data}, 'ARRAY');
  is($ref->{result}, 1);

  {
    $path->query_form( key => $api_key );

    my ($r, $c) = ctx_request( $path );

    ok(! $r->is_success);
    is($r->code, 403);
  }

};

SKIP: {
  subtest "api /admin/project_register" => sub {
    ok 1;
  };
}

done_testing();
