package Murakumo::Controller::Storage;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Murakumo::Controller::Storage - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

use JSON;

sub info :Local {

  my ($self, $c) = @_;
  my $uuid = $c->stash->{uuid}
          || $c->request->query_params->{uuid};

  local $@;

  eval {
    my $storage_model = $c->model('Storage');
    my $info = $storage_model->info( $uuid );

    $c->stash->{data}   = $info;
    $c->stash->{result} = 1;
  };

  return $c->forward( $c->view('JSON') );

}

sub select :Local {
  my ($self, $c) = @_;

  my $q = $c->request->query_params;

  my $size = $q->{size};
  if (! defined $size) {
    $c->detach('/stop_error', ["size is required"]);

  }

  my $query_args = +{};
  exists $q->{tag}
    and $query_args->{storage_tag} = $q->{tag};

  local $@;
  eval {
    my $storage_model = $c->model('Storage');

    my $uuid = $storage_model->select( $size, $query_args );

    $c->stash->{data}   = { uuid => $uuid };
    $c->stash->{result} = 1;
  };
  warn $@ if $@;

}

sub list :Local {
  my ($self, $c) = @_;

  eval {
    my $storage_model   = $c->model('Storage');
    $c->stash->{result} = 1;
    $c->stash->{data}   = [ $storage_model->list ];

  };

}

=head1 AUTHOR

kawano

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
