use strict;
use warnings;
package Murakumo::CLI::Schema;
use DBIx::Class::Schema::Loader;
use base q(DBIx::Class::Schema::Loader);

__PACKAGE__->loader_options(
  debug         => 0,
  naming        => 'v4',
  relationships => 1
);


1;
