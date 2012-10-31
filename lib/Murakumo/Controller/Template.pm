package Murakumo::Controller::Template;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Murakumo::Controller::Template - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub list :Private {
  my ($self, $c) = @_;

  my $tag = $c->request->query_params->{tag};

  my $define_model    = $c->model('VPS_Define');
  $c->stash->{data}   = $define_model->list_template( $tag );
  $c->stash->{result} = 1;

}

sub clone :Private {
  my ($self, $c) = @_;

  $c->detach('/vps/define/clone');

}

sub auto :Private {
  return 1;
}

=head1 AUTHOR

A clever guy

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
