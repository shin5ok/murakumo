use strict;
use warnings;
use Test::More;
use JSON;
use URI;


use Catalyst::Test 'Murakumo';
use Murakumo::Controller::Template;

my $api_key    = $ENV{MURAKUMO_API_KEY};
my $admin_key  = $ENV{MURAKUMO_ADMIN_KEY};
my $api_uri    = $ENV{MURAKUMO_API_URI};
my $project_id = $ENV{MURAKUMO_PROJECT_ID};
$admin_key   //= qq{};


my $template_uuid;
subtest "api /string-of-project/template/list" => sub {
  my $path = URI->new( qq{/$project_id/template/list} );

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

    $template_uuid //= $ref->{data}->[0]->{uuid};

  }

};

SKIP: {
  subtest "api /string-of-project/template/clone/uuid-of-template" => sub {
    ok 1;
  };
}

subtest "api /string-of-project/template/info/uuid-of-template" => sub {
  my $path = URI->new( qq{/$project_id/template/info/$template_uuid} );

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

    diag $r->content;

    is_deeply( $data, $ref->{data} );

  }

};

done_testing();
