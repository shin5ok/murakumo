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

# my $config = Murakumo::CLI::Utils->config;

sub select {
  my ($self, $size, $query_args) = @_;
  my $resultset = $self->schema->resultset('Storage');

  $query_args //= +{};
  $query_args->{avail_size} = +{ '>' => $size };

  warn Dumper $query_args;

  my @rs = $resultset->search($query_args, { order_by => { -desc => [ 'priority' ] } });
  @rs = sort { $a->iowait <=> $b->iowait } @rs;

  if (@rs == 0) {
    croak "*** no storage available";
  }

  return $rs[0]->uuid;

}

1;

