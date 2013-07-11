use strict;
use warnings;
use Test::More;
use JSON;
use URI;


use Catalyst::Test 'Murakumo';
use Murakumo::Controller::IP;

my $api_key    = $ENV{MURAKUMO_API_KEY};
my $admin_key  = $ENV{MURAKUMO_ADMIN_KEY};
my $api_uri    = $ENV{MURAKUMO_API_URI};
my $project_id = $ENV{MURAKUMO_PROJECT_ID};
$admin_key   //= qq{};


subtest "api /string-of-project/ip/list" => sub {
  my $path = URI->new( qq{/admin/ip/list} );
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
    my $path = URI->new( qq{/$project_id/ip/list} );
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

    is_deeply( $ref->{data}, $data );

  }

};

subtest "api /string-of-project/ip/list_count" => sub {
  my $path = URI->new( qq{/admin/ip/list_count} );
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
    my $path = URI->new( qq{/$project_id/ip/list_count} );
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

    is_deeply( $ref->{data}, $data );

  }

};

done_testing();

