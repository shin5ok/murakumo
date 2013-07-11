use strict;
use warnings;
use Test::More;
use JSON;

use Catalyst::Test 'Murakumo';
use Murakumo::Controller::Job;

my $api_key    = $ENV{MURAKUMO_API_KEY};
my $admin_key  = $ENV{MURAKUMO_ADMIN_KEY};
my $api_uri    = $ENV{MURAKUMO_API_URI};
my $project_id = $ENV{MURAKUMO_PROJECT_ID};
$admin_key   //= qq{};

SKIP: {
  subtest "api /string-of-project/job/update" => sub {
    ok 1;
  };
}

my $job_uuid;
subtest "api /string-of-project/job/list" => sub {
  my $path = URI->new( qq{/$project_id/job/list} );

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

    $job_uuid = $ref->{data}->[0]->{job_uuid};
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

subtest "api /string-of-project/job/list/uuid-of-string" => sub {
  my $path = URI->new( qq{/$project_id/job/list/$job_uuid} );

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
    is(ref $ref->{data}->[0], 'HASH');
    is($ref->{result}, 1);

    $job_uuid = $ref->{data}->[0]->{job_uuid};
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
    is(ref $ref->{data}->[0], 'HASH');
    is($ref->{result}, 1);

    is_deeply( $data, $ref->{data} );

  }

};

subtest "api /string-of-project/job/result/uuid-of-string" => sub {
  my $path = URI->new( qq{/$project_id/job/result/$job_uuid} );

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
    is(ref $ref->{data}, 'HASH');
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
    is(ref $ref->{data}, 'HASH');
    is($ref->{result}, 1);

    is_deeply( $data, $ref->{data} );

  }

};

done_testing();
