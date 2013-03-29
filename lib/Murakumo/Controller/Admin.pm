package Murakumo::Controller::Admin;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Murakumo::Controller::Admin - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut
use Carp;
use Data::Dumper;
use JSON;
use Murakumo::CLI::Utils;

my $config = Murakumo::CLI::Utils->config;

sub vps_define_list_all :Local {

  no strict 'refs';

  my ($self, $c, @args) = @_;

  my $project_id = $c->stash->{project_id} || $args[0];
  my $tag        = $c->request->query_params->{tag};

  my $admin_model = $c->model('Admin');

  my $query = {};
  $project_id and $query->{project_id} = $project_id;
  $tag        and $query->{tag}        = $tag;

  $c->stash->{data}   = $admin_model->vps_define_list( $query );
  $c->stash->{result} = 1;

}


sub vps_list_all :Local {

  no strict 'refs';

  my ($self, $c, @args) = @_;

  my $project_id = $c->stash->{project_id} || $args[0];
  my $params     = $c->request->query_params;
  my $tag        = $params->{tag};

  my $admin_model = $c->model('Admin');

  my $query = {};
  $project_id and $query->{project_id} = $project_id;
  $tag        and $query->{tag}        = $tag;

  my $time_until;
  {
    no strict 'refs';
    my $verbose = $params->{'verbose'};
    if (! $verbose) {
      $time_until = DateTime->now(time_zone => 'Asia/Tokyo');
      $time_until->subtract( seconds => $c->config->{vps_list_expire_second} );
    }
  }

  $c->stash->{data}   = $admin_model->vps_list( $query, $time_until );
  $c->stash->{result} = 1;

}


sub project_list :Local {
  my ($self, $c) = @_;

  my $admin_model = $c->model('Admin');

  $c->stash->{data}   = $admin_model->project_list;
  $c->stash->{result} = 1;

}


sub project_register :Local {
  my ($self, $c) = @_;

  my $admin_model = $c->model('Admin');

  my $body       = $c->request->body;
  my $params     = decode_json <$body>;
  my $project_id = $params->{project_id};

  if (! defined $project_id) {
    croak "*** project_id is empty";
  }

  if ($project_id !~ /$config->{project_id_regex}/i) {
    croak "*** invalid project_id";
  }

  if (my $data = $admin_model->project_register( $project_id )) {
    $c->stash->{result} = 1;
    $c->stash->{data}   = $data;

  }

}


sub ip_with_name :Local {
  my ($self, $c, $vlan_id) = @_;

  my $ip_model = $c->model('IP');

  $c->stash->{result} = 1;
  $c->stash->{data}   = $ip_model->ip_with_name( $vlan_id );

}


=head2 index

=cut

sub auto :Private {
  my ($self, $c) = @_;

  no strict 'refs';
  if (! $c->stash->{is_admin}) {
    croak "*** You must be admin";
  }

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
