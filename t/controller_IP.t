use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Murakumo';
use Murakumo::Controller::IP;

my $api_key    = $ENV{MURAKUMO_API_KEY};
my $admin_key  = $ENV{MURAKUMO_ADMIN_KEY};
my $api_uri    = $ENV{MURAKUMO_API_URI};
my $project_id = $ENV{MURAKUMO_PROJECT_ID};

my @gets = qw(
  list
  list_count
);

# adminユーザでのアクセス
for my $uri_path ( @gets ) {
  my $path = qq{/$project_id/$uri_path};
  $path .= "?admin_key=$admin_key";
  my ($r, $c) = ctx_request($path);

  ok($r->is_success);

  eval {
    my $ref = to_json $r->content;
    is(ref $ref, 'HASH');
    is($ref->{result}, 1);
  };
}

# 一般ユーザでのアクセス
for my $uri_path ( @gets ) {
  my $path = qq{/$project_id/$uri_path};
  $path .= "?api_key=$api_key";
  my ($r, $c) = ctx_request($path);

  ok($r->is_success);

  eval {
    my $ref = to_json $r->content;
    is(ref $ref, 'HASH');
    is($ref->{result}, 1);
  };
}


done_testing();
