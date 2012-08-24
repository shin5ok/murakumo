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
  warn Dumper $c->stash;

  # error set
  $c->stash->{result} = "0";

  if (defined $error_message) {
    $c->log->warn($error_message);
    $c->stash->{message} = $error_message;
  }

  return;

}

sub auto :Private {
  my ( $self, $c, @args ) = @_;

  $c->log->info($c->request->uri);

  # すでに認証されていれば
  {
    no strict 'refs';
    $c->stash->{authed} and return 1;
  }

  my $project_model = $c->model('Project');
  my $node_model    = $c->model('Node');

  my $api_key       = $c->request->query_params->{'key'};
  my $node_uuid     = $c->request->query_params->{'node_uuid'};
  my $node_name     = $c->request->query_params->{'name'};
  my $admin_api_key = $c->request->query_params->{'admin_api_key'};

  if ( $admin_api_key ) {

    if (! $project_model->is_admin_access( $admin_api_key, $c->request ) ) {
      $c->response->body( 'forbidden' );
      $c->response->status( 403 );
      $c->log->warn( "error forbidden" );
      return 0;
    }

  }
  elsif ($node_uuid and $node_name and $api_key) {

    if (! $node_model->is_valid_node( $node_name, $node_uuid, $api_key ) ) {
      $c->response->body( 'forbidden' );
      $c->response->status( 403 );
      $c->log->warn( "error forbidden" );
      return 0;
    }

  } else {

    my $project_id = shift @args;

    if (! $project_model->auth( $project_id, $api_key ) ) {
      $c->response->body( 'forbidden' );
      $c->response->status( 403 );
      return 0;

    } else {
      $c->stash->{project_id} = $project_id;
    }

  }

  # default値の設定
  $c->stash->{message} = qq{};
  $c->stash->{result}  = 0;
  $c->stash->{authed}  = 1;

  # stub for now
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

  # # 371ff666-c581-40a4-9bab-1260975464bd
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

  $c->log->info("/ => detach to $url");

  $c->request->args([]);
  $c->go( "/$url" );
  # $c->detach( "/$url" );

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
