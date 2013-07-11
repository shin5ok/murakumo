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
    $c->log->warn( $c->stash->{message} );
  }

  return;

}

sub auto :Private {
  my ( $self, $c, @args ) = @_;

  my $request_uri = $c->request->uri;
  $c->log->info($request_uri);

  # 設定で禁止されたapi
  if (exists $c->config->{'forbidden_api'}) {

    my $request_path = $c->request->path;

    my $forbidden_api  = $c->config->{'forbidden_api'};
    my @forbidden_apis = ref $forbidden_api eq 'ARRAY'
                       ? @$forbidden_api
                       : ($forbidden_api);

    for my $api ( @forbidden_apis ) {
      if ($request_path =~ m{$api}) {
        $c->response->body( 'forbidden' );
        $c->response->status( 403 );
        $c->log->warn( "$request_path forbidden api" );
        return 0;
      }

    }

  }

  # すでに認証されていれば
  {
    no strict 'refs';
    $c->stash->{authed} and return 1;
  }

  my $project_model = $c->model('Project');
  my $node_model    = $c->model('Node');
  my $admin_model   = $c->model('Admin');

  my $query_params  = $c->request->query_params;
  my $admin_api_key = $query_params->{'admin_key'};
  my $api_key       = $query_params->{'key'};
  my $node_uuid     = $query_params->{'node_uuid'};
  my $node_name     = $query_params->{'name'};

  my $project_id = $args[0] || q{};

  my $src_ip = $c->request->address;
  if ( $c->request->path =~ m{^admin/?}i ) {

    if ( $admin_api_key ) {

      $c->log->debug("admin api from $src_ip");
      if ($admin_model->is_admin_access( $admin_api_key, { src_ip => $src_ip } ) ) {
        $c->stash->{authed}   = 1;
        $c->stash->{is_admin} = 1;

      }
    }

  }
  elsif ($project_id and $project_model->is_exist( $project_id )) {
    shift @args;
    $c->stash->{project_id} = $project_id;

    if ( $admin_api_key ) {

      if ($admin_model->is_admin_access( $admin_api_key, { src_ip => $src_ip } ) ) {
        $c->stash->{authed}   = 1;
        $c->stash->{is_admin} = 1;

      }

    } else {

      if ($project_model->auth( $project_id, $api_key ) ) {
        $c->stash->{authed} = 1;
      }

    }

  } else {

    if ($node_model->is_valid_node( $node_name, $node_uuid, $api_key ) ) {
      $c->stash->{authed}     = 1;
      $c->stash->{valid_node} = 1;
    }

  }

  if (! $c->stash->{authed}) {
     $c->response->body( 'forbidden' );
     $c->response->status( 403 );
     $c->log->warn( "error forbidden" );
     return 0;
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
        warn "--- default error -------------" if is_debug;
        $c->stash->{message} = $@;
      }

    }

    if ((my @errors = @{$c->error}) > 0) {
      $c->stash->{result}  = "0";
      $c->stash->{message} = join ",", @errors;

      $c->clear_errors;
    }

    return $c->forward( $c->view( 'JSON' ) );

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

  $c->log->info("/ => detach to $url");

  $c->request->args([]);

  # detach や go では、
  # 戻ってこない動きの実現のため
  # die $Catalyst::DETACH;
  # してるみたいなので $@ がセットされる
  # なので、$@ はエラーではないので評価しない
  eval {
    $c->log->info("go /$url");
    $c->go( "/$url" );
  };

}

=head2 end

Attempt to render a view, if needed.

=cut

# sub end : ActionClass('RenderView') {}

=head1 AUTHOR

shin5ok

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
