use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Murakumo';
use Murakumo::Controller::Job;

ok( request('/job')->is_success, 'Request should succeed' );
done_testing();
