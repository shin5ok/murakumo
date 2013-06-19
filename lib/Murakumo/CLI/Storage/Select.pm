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
  my ($self, $size, $query_args) = @_;
  my $resultset = $self->schema->resultset('Storage');

  $query_args //= +{};

  {
    no strict 'refs';
    if ($size and $config->{check_storage_size}) {
      $query_args->{avail_size} = +{ '>' => $size };
    }
  }

  my @rs = $resultset->search($query_args, { order_by => { -desc => [ 'priority' ] } });
  if (@rs == 0) {
    croak "*** no storage is available";
  }

  my $priority = $rs[0]->priority;

  @rs = sort { $a->iowait <=> $b->iowait }
        grep { $_->priority == $priority }
        @rs;

  if (is_debug) {
    warn sprintf "uuid %s: iowait %s",
                 $_->uuid,
                 $_->iowait
         for @rs;
    warn "auto select uuid ", $rs[0]->uuid if is_debug;
  }
  return $rs[0]->uuid;

}

1;

