use strict;
use warnings;
package Murakumo::CLI::Storage::Status 0.01;
use Data::Dumper;
use Carp;

use FindBin;
use lib qq{$FindBin::Bin/../lib};
use Murakumo::CLI::Utils;
use Murakumo::CLI::DB;
use base qw( Murakumo::CLI::DB );

sub regist {
  my ($self, $uuid, $params) = @_;
  my $resultset = $self->schema->resultset('Storage');

  my $query = {
    uuid => $uuid,
  };

  %$query = (%$query, %$params);

  $resultset->update_or_create( $query );

}

1;
