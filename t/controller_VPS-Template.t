use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Murakumo';
use Murakumo::Controller::VPS::Template;

ok( request('/vps/template')->is_success, 'Request should succeed' );
done_testing();
