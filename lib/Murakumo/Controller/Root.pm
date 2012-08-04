package Murakumo::Controller::Root;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(namespace => '');

=head1 NAME

Murakumo::Controller::Root - Root Controller for Murakumo

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=head2 index

The root page (/)

=cut

use Data::Dumper;
use Murakumo::CLI::Utils;

sub stop_error :Private {
  my ( $self, $c ) = @_;
  my $error_message = $c->request->args->[0];

  # error set
  $c->stash->{result} = "0";

  if (defined $error_message) {
    $c->stash->{message} = $error_message;
  }

  return;

}

sub auto :Private {
  my ( $self, $c ) = @_;

  # default値の設定
  $c->stash->{message} = qq{};
  $c->stash->{result}  = 0;

  # stub for now
  return 1;

  # # project is exists? and resource check  validation
  # $c->forward( '/project/is_valid_project/' );
  my $project_model = $c->model('Project');
  {
    no strict 'refs';
    my $project_id = $c->request->param('project_id');
    $project_model->is_exist( $project_id );
  }

  return 1;
  
}

# default view
sub end : ActionClass('RenderView') {
    my ( $self, $c ) = @_;

    if ($@) {
      $c->stash->{result}  = "0";
      # defaut error
      if (! exists $c->stash->{message}) {
        warn "--- default error -------------";
        $c->stash->{message} = $@;
      }
      return;
    }

    if ((my @errors = @{$c->error}) > 0) {
      $c->stash->{result}  = "0";
      $c->stash->{message} = join ",", @errors;

      $c->clear_errors;
    }

}

=head2 default

Standard 404 error page

=cut

sub default :Path{
  my ( $self, $c, $project_id, @args ) = @_;

  $c->stash->{project_id} = $project_id;

  # 371ff666-c581-40a4-9bab-1260975464bd
  my $like_uuid = qr{
    ^
      [0-9a-f]{8} \-
      [0-9a-f]{4} \-
      [0-9a-f]{4} \-
      [0-9a-f]{4} \-
      [0-9a-f]{12}
      / *
    $
  }xo;

  if ($args[-1] =~ /$like_uuid/) {
    $c->stash->{uuid} = pop @args;
  }

  my $url = join "/", @args;

  warn "----- detach -----";
  warn Dumper \@args;
  warn "------------------";
  warn "url /$url";

  $c->request->args([]);
  $c->detach( "/$url" );

}

=head2 end

Attempt to render a view, if needed.

=cut

# sub end : ActionClass('RenderView') {}

=head1 AUTHOR

shingo

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
