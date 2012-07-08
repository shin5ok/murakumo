use strict;
use warnings;
package Murakumo::CLI::Schema;
use DBIx::Class::Schema::Loader;
use base q(DBIx::Class::Schema::Loader);

__PACKAGE__->loader_options(
  debug         => 0,
  # debug         => exists $ENV{DEBUG},
  naming        => 'v4',
  relationships => 1
);


# __PACKAGE__->load_components( qw( InflateColumn::DateTime ) );

1;
