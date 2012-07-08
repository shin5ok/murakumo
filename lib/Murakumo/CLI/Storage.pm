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
  # my ($info) = $resultset->find( $uuid );
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
  my @storage_objs = $resultset->search({}, { order_by => { -desc => [ 'priority' ] } });
  return $storage_objs[0]->uuid;
}

sub list {
  my ($self) = @_;
  my $resultset = $self->schema->resultset('Storage');
  my @storages = $resultset->search( { available => 1 } );

  # +-------------+--------------+------+-----+---------+-------+
  # | Field       | Type         | Null | Key | Default | Extra |
  # +-------------+--------------+------+-----+---------+-------+
  # | uuid        | varchar(48)  | NO   | PRI |         |       |
  # | export_path | varchar(255) | YES  |     | NULL    |       |
  # | mount_path  | varchar(255) | YES  |     | NULL    |       |
  # | host        | varchar(64)  | YES  |     | NULL    |       |
  # | type        | varchar(8)   | YES  |     | NULL    |       |
  # | available   | int(128)     | YES  |     | NULL    |       |
  # | priority    | int(8)       | YES  |     | 0       |       |
  # +-------------+--------------+------+-----+---------+-------+

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
# Field	Type	Null	Key	Default	Extra
# uuid	varchar(48)	NO	PRI		
# export_path	varchar(255)	YES		NULL	
# host	varchar(64)	YES		NULL	
# type	varchar(8)	YES		NULL	
# available	int(128)	YES		NULL	
