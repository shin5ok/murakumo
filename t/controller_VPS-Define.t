use strict;
use warnings;
use Test::More;

use URI;
use JSON;


use Catalyst::Test 'Murakumo';
use Murakumo::Controller::VPS::Define;

my $api_key    = $ENV{MURAKUMO_API_KEY};
my $admin_key  = $ENV{MURAKUMO_ADMIN_KEY};
my $api_uri    = $ENV{MURAKUMO_API_URI};
my $project_id = $ENV{MURAKUMO_PROJECT_ID};
$admin_key   //= qq{};

my $vps_uuid;

subtest "api /vps/define/list" => sub {
  my $path = URI->new( qq{/$project_id/vps/define/list} );
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


  $vps_uuid = $ref->{data}->[0]->{uuid};

};


subtest "api /vps/define/info_list" => sub {
  my $path = URI->new( qq{/$project_id/vps/define/info_list} );
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

};

SKIP: {
  subtest "api /vps/define/clone" => sub {
    ok 1;
  };
}

SKIP: {
  subtest "api /vps/define/remove_commit" => sub {
    ok 1;
  };
}

SKIP: {
  subtest "api /vps/define/commit" => sub {
    ok 1;
  };
}

SKIP: {
  subtest "api /vps/define/create" => sub {
    ok 1;
  };
}

SKIP: {
  subtest "api /vps/define/modify" => sub {
    ok 1;
  };
}

SKIP: {
  subtest "api /vps/define/remove" => sub {
    ok 1;
  };
}

subtest "api /vps/define/info/uuid-of-vps" => sub {
  my $path = URI->new( qq{/$project_id/vps/define/info/$vps_uuid} );
  $path->query_form( admin_key => $admin_key );

  my ($r, $c) = ctx_request( $path );

  ok($r->is_success);

  my $ref;
  eval {
    $ref = decode_json $r->content;
    diag $r->content;
  };
  is(ref $ref, 'HASH');
  is(ref $ref->{data}, 'HASH');
  is($ref->{result}, 1);

};

SKIP: {
  subtest "api /vps/define/add_ip" => sub {
    ok 1;
  };
}

SKIP: {
  subtest "api /vps/define/proxy_vlan_id" => sub {
    ok 1;
  };
}

done_testing();
