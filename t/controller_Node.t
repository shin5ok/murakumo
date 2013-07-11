use strict;
use warnings;
use Test::More;
use JSON;
use URI;

use Catalyst::Test 'Murakumo';
use Murakumo::Controller::Node;

my $api_key    = $ENV{MURAKUMO_API_KEY};
my $admin_key  = $ENV{MURAKUMO_ADMIN_KEY};
my $api_uri    = $ENV{MURAKUMO_API_URI};
my $project_id = $ENV{MURAKUMO_PROJECT_ID};
$admin_key   //= qq{};

SKIP: {
  subtest "api /node/job" => sub {
    ok 1;
  };
}

SKIP: {
  subtest "api /node/register" => sub {
    ok 1;
  };
}

subtest "api /string-of-project/node/list" => sub {
  my $path = URI->new( qq{/$project_id/node/list} );

  my $data;
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

    $data = $ref->{data};

  }

  {
    $path->query_form( key => $api_key );

    my ($r, $c) = ctx_request( $path );

    ok($r->is_success);

    my $ref;
    eval {
      $ref = decode_json $r->content;
    };
    is(ref $ref, 'HASH');
    is(ref $ref->{data}, 'ARRAY');
    is($ref->{result}, 1);

    is_deeply( $data, $ref->{data} );

  }

};

done_testing();
