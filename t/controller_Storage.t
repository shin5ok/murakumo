use strict;
use warnings;
use Test::More;
use JSON;
use URI;


use Catalyst::Test 'Murakumo';
use Murakumo::Controller::Storage;

my $api_key    = $ENV{MURAKUMO_API_KEY};
my $admin_key  = $ENV{MURAKUMO_ADMIN_KEY};
my $api_uri    = $ENV{MURAKUMO_API_URI};
my $project_id = $ENV{MURAKUMO_PROJECT_ID};
$admin_key   //= qq{};


my $storage_uuid;
subtest "/string-of-project_id/storage/list" => sub {

  my $path = URI->new( qq{/$project_id/storage/list} );

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

subtest "/string-of-project_id/storage/select" => sub {

  my $path = URI->new( qq{/$project_id/storage/select} );

  my $data;
  {
    $path->query_form(
                       admin_key => $admin_key,
                       size      => 1024000,
                     );

    my ($r, $c) = ctx_request( $path );

    ok($r->is_success);
    diag $r->content;

    my $ref;
    eval {
      $ref = decode_json $r->content;
    };
    is(ref $ref, 'HASH');
    is(ref $ref->{data}, 'HASH');
    is($ref->{result}, 1);

  }

  {
    $path->query_form(
                       key  => $api_key,
                       size => 1024000,
                      );

    my ($r, $c) = ctx_request( $path );

    ok($r->is_success);
    diag $r->content;

    my $ref;
    eval {
      $ref = decode_json $r->content;
    };
    is(ref $ref, 'HASH');
    is(ref $ref->{data}, 'HASH');
    is($ref->{result}, 1);

    $storage_uuid //= $ref->{data}->{uuid};

  }

};

subtest "/string-of-project_id/storage/info/string-of-storage-uuid" => sub {

  my $path = URI->new( qq{/$project_id/storage/info/$storage_uuid} );

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
    $path->query_form( key  => $api_key );

    my ($r, $c) = ctx_request( $path );

    ok($r->is_success);
    diag $r->content;

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

