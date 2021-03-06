use strict;
use warnings;
use 5.014;

package Murakumo::CLI::Job 0.01;

use JSON;
use Carp;
use Data::Dumper;
use FindBin;
use lib qq{$FindBin::Bin/../lib};
use Murakumo::CLI::Utils;
use Murakumo::CLI::DB;
use base q(Murakumo::CLI::DB);

sub update {
  my ($self, $job_uuid, $param_ref) = @_;
  $job_uuid or croak "*** update uuid is empty...?";

  my $r;
  my $txn = $self->schema->txn_scope_guard;
  local $@;
  eval {
    my $resultset = $self->schema->resultset('Job');
    $r = $resultset->search( { job_uuid => $job_uuid } )->update( $param_ref );

  };

  if ($@ and ! $r) {
    warn $@ if $@;
    return 0;

  } else {
    $txn->commit;
    return 1;
  }

}

sub get_status {
  my ($self, $project_id, $job_uuid) = @_;

  if (! $project_id) {
    croak "*** project_id must be set...";
  }

  my @rs;
  local $@;
  eval {
    my $resultset = $self->schema->resultset('Job');

    my $query_ref = { project_id => $project_id };
    $job_uuid and $query_ref->{job_uuid} = $job_uuid;

    @rs = $resultset->search( $query_ref, { order_by => 'update_time' } );

  };

  if ($@ or @rs == 0) {
    return undef;

  } else {
     my @jobs;
     for my $r ( @rs ) {
       push @jobs, {
                     job_uuid    => $r->job_uuid,
                     result      => $r->result,
                     request_job => $r->request_job,
                     message     => $r->message,
                     update_time => $r->update_time,
                   };
     }
    return \@jobs;

  }

}

sub delete {
  my ($self, $param_ref) = @_;
  if (! exists $param_ref->{job_uuid}) {
    croak "*** uuid find error";
  }

  my $r;
  my $txn = $self->schema->txn_scope_guard;

  local $@;
  eval {
    my $resultset = $self->schema->resultset('Job');
    $r = $resultset->search( $param_ref )->delete;

  };

  if ($@ or ! $r) {
    warn "$param_ref->{job_uuid} delete error";
    return 0;
  }
  $txn->commit;

  return 1;

}

sub is_locked_by_uuid {
  my ($self, $uuid) = @_;
  my @rs;

  local $@;
  eval {
    my $resultset = $self->schema->resultset('Job');
    @rs = $resultset->search( { result      => { is => undef } } )
                    ->search( { lock_target => $uuid           } );
  };
  if ($@) {
    warn $@;
    return 0;
  }
  # ロックされていたら
  return @rs >= 1;
}

sub create {
  # { request_job => '', job_uuid => '', }
  my ($self, $param_ref) = @_;

  no strict 'refs';
  my $uuid = $param_ref->{job_uuid} || "";
  $uuid ||= Murakumo::CLI::Utils->create_uuid;
  if (! $uuid) {
    croak "*** uuid getting error";
  }

  $param_ref ||= { result => 0, };
  (exists $param_ref->{job_uuid} and $param_ref->{job_uuid})
    or $param_ref->{job_uuid} = $uuid;

  my $txn = $self->schema->txn_scope_guard;

  my @created;
  local $@;
  eval {
    my $resultset = $self->schema->resultset('Job');
    @created = $resultset->create( $param_ref );

  };

  $txn->commit;

  if ($@ and @created == 0) {
    warn Dumper $param_ref if is_debug;
    warn "uuid create error $uuid" . $@ if $@;
    return "uuid create error $uuid $@";

  } else {
    return $uuid;
  }

}

1;
__END__
