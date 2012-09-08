use strict;
use warnings;
package Murakumo::CLI::Storage 0.01;
use URI;
use JSON;
use Data::Dumper;
use Carp;

use FindBin;
use lib qq{$FindBin::Bin/../lib};
use Murakumo::CLI::DB;
use base qw( Murakumo::CLI::DB );

sub info {
  my ($self, $uuid) = @_;
  $uuid or croak "*** uuid is empty";

  my $resultset = $self->schema->resultset('Storage');
  my ($info) = $resultset->search({ uuid => $uuid });

  my %result;
  for my $col ( qw( uuid export_path mount_path host type available ) ) {
    $result{$col} = $info->$col || "";
  }

  return \%result;

}

sub select {
  my ($self) = @_;
  my $resultset = $self->schema->resultset('Storage');
  my ($storage_obj) = $resultset->search({}, { order_by => { -desc => [ 'priority' ] } });
  return $storage_obj->uuid;
}

sub list {
  my ($self) = @_;
  my $resultset = $self->schema->resultset('Storage');
  my @storages = $resultset->search( { available => 1 } );

  my @lists;
  for my $storage ( @storages ) {
    my $x = {
      uuid        => $storage->uuid,
      mount_path  => $storage->mount_path,
      regist_time => $storage->regist_time,
      host        => $storage->host,
      type        => $storage->type,
      priority    => $storage->priority,
      export_path => $storage->export_path,
    };
    push @lists, $x;
  }

  return @lists;
}

1;
__END__

