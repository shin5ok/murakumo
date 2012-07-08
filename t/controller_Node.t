use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Murakumo';
use Murakumo::Controller::Node;

ok( request('/node')->is_success, 'Request should succeed' );
done_testing();
