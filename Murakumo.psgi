use strict;
use warnings;

use Murakumo;

my $app = Murakumo->apply_default_middlewares(Murakumo->psgi_app);
$app;

