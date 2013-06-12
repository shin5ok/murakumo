use strict;
use warnings;
package Murakumo::CLI::Storage::Select 0.01;
use Data::Dumper;
use Carp;
use List::Util qw(shuffle);

use FindBin;
use lib qq{$FindBin::Bin/../lib};
use Murakumo::CLI::Utils;
use Murakumo::CLI::DB;
use base qw( Murakumo::CLI::DB );

my $config = Murakumo::CLI::Utils->config;

sub select {
  my ($self, $query_args) = @_;
  my $resultset = $self->schema->resultset('Storage');

  # tag が入ってくることを想定
  my $query_args //= +{};

  my ($storage_obj) = $resultset->search($query_args, { order_by => { -desc => [ 'priority' ] } });

  return $storage_obj->uuid;

}

1;

