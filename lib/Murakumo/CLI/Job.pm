use strict;
use warnings;
package Murakumo::CLI::Job;

use JSON;
use Carp;
use Data::Dumper;
use FindBin;
use lib qq{$FindBin::Bin/../lib};
use Murakumo::CLI::DB;
use base q(Murakumo::CLI::DB);

our $VERSION = q(0.0.1);

sub update {
  my ($self, $job_uuid, $param_ref) = @_;
  my $r;
  local $@;
  eval {
    my $resultset = $self->schema->resultset('Job');
    # my $job_uuid = delete $param_ref->{job_uuid};

    $job_uuid or croak "*** update uuid is empty...?";

    $r = $resultset->search( { job_uuid => $job_uuid } )->update( $param_ref );

  };

  if ($@ and ! $r) {
    warn $@ if $@;
    return 0;

  } else {
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
  local $@;
  eval {
    my $resultset = $self->schema->resultset('Job');
    $r = $resultset->search( $param_ref )->delete;

  };

  if ($@ or ! $r) {
    warn "$param_ref->{job_uuid} delete error";
    return 0;
  }
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
  warn "### Job ##############";
  warn Dumper $param_ref;
  warn "######################";
  no strict 'refs';
  my $uuid = $param_ref->{job_uuid} || "";
  $uuid ||= Murakumo::CLI::Utils->create_uuid;
  if (! $uuid) {
    croak "*** uuid getting error";
  }

  $param_ref ||= { result => 0, };
  (exists $param_ref->{job_uuid} and $param_ref->{job_uuid})
    or $param_ref->{job_uuid} = $uuid;
  warn "### Job ##############";
  warn Dumper $param_ref;
  warn "######################";

  my @created;
  local $@;
  eval {
    my $resultset = $self->schema->resultset('Job');
    @created = $resultset->create( $param_ref );

  };
  warn Dumper $param_ref;

  if ($@ and @created == 0) {
    warn Dumper $param_ref;
    warn "uuid create error $uuid" . $@ if $@;
    return "uuid create error $uuid $@";

  } else {
    return $uuid;
  }

}

1;
__END__
