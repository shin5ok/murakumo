use strict;
use warnings;
package Murakumo::CLI::Schema;
use DBIx::Class::Schema::Loader;
use base q(DBIx::Class::Schema::Loader);

use lib qq{$FindBin::Bin/../lib};
use Murakumo::CLI::Utils;

__PACKAGE__->loader_options(
  debug         => is_debug,
  naming        => 'v4',
  relationships => 1
);


1;
