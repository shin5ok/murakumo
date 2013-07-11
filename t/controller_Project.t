use strict;
use warnings;
use Test::More;
use JSON;
use URI;


use Catalyst::Test 'Murakumo';
use Murakumo::Controller::Project;

my $api_key    = $ENV{MURAKUMO_API_KEY};
my $admin_key  = $ENV{MURAKUMO_ADMIN_KEY};
my $api_uri    = $ENV{MURAKUMO_API_URI};
my $project_id = $ENV{MURAKUMO_PROJECT_ID};
$admin_key   //= qq{};

SKIP: {
  subtest "api test" => sub {
    ok 1;
  };
}

done_testing();
