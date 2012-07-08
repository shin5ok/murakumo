use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Murakumo';
use Murakumo::Controller::Storage;

ok( request('/storage')->is_success, 'Request should succeed' );
done_testing();
