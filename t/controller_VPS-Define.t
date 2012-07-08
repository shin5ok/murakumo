use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Murakumo';
use Murakumo::Controller::VPS::Define;

ok( request('/vps/define')->is_success, 'Request should succeed' );
done_testing();
