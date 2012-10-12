package Murakumo::Controller::Job 0.01;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Murakumo::Controller::Job - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

use Carp;
use JSON;
use Data::Dumper;

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched Murakumo::Controller::Job in Job.');
}

sub update :Local {
  my ($self, $c) = @_;
  my $model = $c->model('Job');

  # { job_id => $job_id, job_result => $job_result, message => $message }
  my $body      = $c->request->body;
  my $params    = decode_json <$body>;
  my $job_uuid  = $params->{job_uuid};

  $job_uuid
    or croak "*** $job_uuid uuid is not found parameter";

  my $r;
  local $@;
  eval {
    $r = $model->update( $job_uuid, $params );
  };

  if ($@ or ! $r) {
    $c->stash->{result}  = 0;
    $@ and $c->stash->{message} = $@;
    $c->log->info( $job_uuid . " is update error" );

  } else {
    $c->stash->{result} = 1;
    $c->log->info( $job_uuid . " is update ok" );

  }

}

sub list :Local {
  my ($self, $c) = @_;

  no strict 'refs';
  # GET
  my $project_id = $c->stash->{project_id};
  my $job_uuid   = $c->stash->{uuid};

  my $model   = $c->model('Job');
  my $job_ref = $model->get_status( $project_id, $job_uuid );

  no strict 'refs';
  if ($job_ref) {
    $c->stash->{result} = 1; 
    $c->stash->{list}   = $job_ref;

  } else {
    $c->stash->{result}   = 0; 
    $c->stash->{message}  = 'job result failure';
  }
  
}


=head1 AUTHOR

shingo

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
