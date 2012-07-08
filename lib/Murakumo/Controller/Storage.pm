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

sub info :Local {

  my ($self, $c) = @_;
  my $uuid = $c->request->query_params->{uuid};

  local $@;

  eval {
    my $storage_model = $c->model('Storage');
    my $info = $storage_model->info( $uuid );

    $c->stash->{data}   = $info;
    $c->stash->{result} = 1;
  };

  return $c->forward( $c->view('JSON') );

}

sub list :Local {
  my ($self, $c) = @_;

  eval {
    my $storage_model   = $c->model('Storage');
    $c->stash->{result} = 1;
    $c->stash->{list}   = [ $storage_model->list ];

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
