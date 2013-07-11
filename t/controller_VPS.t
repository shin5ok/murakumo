use strict;
use warnings;
use Test::More;
use JSON;
use URI;

use Catalyst::Test 'Murakumo';
use Murakumo::Controller::VPS;

my $api_key    = $ENV{MURAKUMO_API_KEY};
my $admin_key  = $ENV{MURAKUMO_ADMIN_KEY};
my $api_uri    = $ENV{MURAKUMO_API_URI};
my $project_id = $ENV{MURAKUMO_PROJECT_ID};
$admin_key   //= qq{};

my $vps_uuid;

subtest "api /vps/list" => sub {
  my $path = URI->new( qq{/$project_id/vps/define/list} );
  $path->query_form( admin_key => $admin_key );

  my ($r, $c) = ctx_request( $path );

  ok($r->is_success);

  diag $r->content;

  my $ref;
  eval {
    $ref = decode_json $r->content;
  };
  is(ref $ref, 'HASH');
  is(ref $ref->{data}, 'ARRAY');
  is($ref->{result}, 1);

  $vps_uuid = $ref->{data}->[0]->{uuid};

};

SKIP: {
  subtest "api /vps/boot/uuid-of-vps" => sub {
    ok 1;
  };
}

SKIP: {
  subtest "api /vps/shutdown/uuid-of-vps" => sub {
    ok 1;
  };
}

SKIP: {
  subtest "api /vps/migration/uuid-of-vps" => sub {
    ok 1;
  };
}

SKIP: {
  subtest "api /vps/terminate/uuid-of-vps" => sub {
    ok 1;
  };
}

SKIP: {
  subtest "api /vps/boot_tmp_cleanup/uuid-of-vps" => sub {
    ok 1;
  };
}

done_testing();
