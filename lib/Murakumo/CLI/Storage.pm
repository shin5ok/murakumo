use strict;
use warnings;
use 5.014;

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

  if (! $info) {
    croak "*** storage uuid $uuid is not found... failure";
  }

  my %result;
  for my $col ( qw( uuid export_path mount_path host type available ) ) {
    $result{$col} = $info->$col || "";
  }

  return \%result;

}

sub select {
  my ($self, @args ) = @_;

  require Murakumo::CLI::Storage::Select;
  return  Murakumo::CLI::Storage::Select->new->select( @args );
}

sub sorted {
  my ($self, @args ) = @_;

  require Murakumo::CLI::Storage::Select;
  return  Murakumo::CLI::Storage::Select->new->sorted( @args );
}

sub list {
  my ($self) = @_;
  my $resultset = $self->schema->resultset('Storage');
  my @storages = $resultset->search( { available => 1 } );

  my @lists;
  for my $storage ( @storages ) {
    my $x = {
      storage_tag => $storage->storage_tag,
      uuid        => $storage->uuid,
      mount_path  => $storage->mount_path,
      regist_time => $storage->regist_time,
      host        => $storage->host,
      type        => $storage->type,
      priority    => $storage->priority,
      export_path => $storage->export_path,
      iowait      => $storage->iowait,
      avail_size  => $storage->avail_size,
    };
    push @lists, $x;
  }

  return @lists;
}

sub register_status {
  my ($self, $uuid, $status) = @_;
  require Murakumo::CLI::Storage::Status;
  Murakumo::CLI::Storage::Status->new->regist( $uuid, $status );
}

1;
__END__

