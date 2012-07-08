package Murakumo::Controller::Project;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Murakumo::Controller::Project - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

use Data::Dumper;

sub is_valid_project :Private {
  my ( $self, $c ) = @_;
  no strict 'refs';

  # GET でも POST でも project_id をセットする
  my $project_id = $c->request->param('project_id');

  my $project_model = $c->model('Project');
  $project_model->is_exist( $project_id );

  # このあとにリソースやクオータをチェック

}

sub default :Path{
  my ( $self, $c, $project_id, @args ) = @_;

  $c->stash->{project_id} = $project_id;
  my $args = $c->request->args;

  warn "----- detach -----";
  warn Dumper \@args;
  warn "------------------";

  my $url = join "/", @args;

  $c->request->args([]);

  $c->detach( "/$url", [] );

}


=head1 AUTHOR

shingo

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
