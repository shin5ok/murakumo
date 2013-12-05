package Murakumo::Controller::VPS;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Murakumo::Controller::VPS - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

use Socket;
use JSON;
use Carp;
use DateTime;
use Data::Dumper;
use Murakumo::CLI::Utils;

sub default :Path {
  my ($self, $c, @args) = @_;
  if (@args > 0) {
    $c->go( join "/", @args );
  }
  if ($c->request->method eq 'GET' ) {
    goto \&list;
  }
}

sub list :Private {
  my ($self, $c, $args) = @_;
  my $params     = $c->request->query_params;
  my $project_id = $c->stash->{project_id};
  if (! $project_id) {
    $c->detach("/stop_error", ["project_id is empty"]);
  }

  my $vps_model    = $c->model('VPS');
  my $define_model = $c->model('VPS_Define');
  $c->log->info("vps list called");

  my $time_until;
  {
    no strict 'refs';
    my $verbose = $params->{'verbose'};
    if (! $verbose) {
      $time_until = Murakumo::CLI::Utils->now;
      $time_until->subtract( seconds => $c->config->{vps_list_expire_second} );
    }
  }

  my $method = qq{list};
  if (defined $args) {
    $method = $args;
  }

  my $vpses_ref       = $vps_model->$method( $project_id, $time_until );
  $c->stash->{data}   = $vpses_ref;
  $c->stash->{result} = 1;

  return $vpses_ref;

}

sub console_list :Private {
  my ($self, $c) = @_;
  # $c->detach("list", [ "console_list" ]);

  my $vpses_ref = $c->forward('list');
  $c->stash->{result} = 0;

  my @vps_consoles;
  for my $v ( @$vpses_ref ) {
    my $ip;
    local $@;
    eval {
      my $packed = gethostbyname( $v->{node} );
      $ip = inet_ntoa( $packed );
    };

    warn Dumper $v;

    my $protocol = $v->{use_spice} == 1
                 ? 'spice'
                 : 'vnc';

    $ip //= $v->{node};
    my $console = sprintf "%s://%s:%d",
                          $protocol,
                          $ip,
                          $v->{vnc_port};

    push @vps_consoles, {
                          name    => $v->{name},
                          uuid    => $v->{uuid},
                          console => $console,
                        };

  }

  $c->stash->{result} = 1;
  $c->stash->{data}   = \@vps_consoles;

}

# nodeコントローラに処理を委譲
sub boot :Private {
  my ($self, $c) = @_;

  no strict 'refs';
  my $body   = $c->request->body;
  my $params = decode_json <$body>;
  my $uuid   = $c->stash->{uuid};

  my $project_id = $c->stash->{project_id};
  if (! $project_id or ! $uuid ) {
    $c->detach( "/stop_error", ["project_id or uuid is empty"]);
  }

  my $vps_model    = $c->model('VPS');
  my $define_model = $c->model('VPS_Define');
  my $node_model   = $c->model('Node');

  if (! $vps_model->set_tmp_active_vps( $uuid ) ) {
    $c->detach( "/stop_error", ["$uuid is already active or booting processing..."]);
  }

  my $info_for_boot = $define_model->info( $uuid );
  $params->{vps_params}  = $info_for_boot;
  $info_for_boot->{name} = sprintf "%s@%s", $info_for_boot->{name}, $project_id;

  if (! $params->{node} and $info_for_boot->{boot_node}) {
    $params->{node} = $info_for_boot->{boot_node};
  }

  if ($params->{node}) {
    $node_model->is_available($params->{node})
      or croak "*** $params->{node} is not available";
  }

  $c->stash->{__callback_for_error} = sub {
    $vps_model->unset_tmp_active_vps( $uuid );
  };

  $c->stash->{to_job_params} = $params;

  $c->log->info( "$uuid try boot request forward to node" );
  $c->detach( '/node/job/vps/boot/', [] );

}

sub boot_tmp_cleanup :Local {
  my ($self, $c) = @_;
  my $vps_model  = $c->model('VPS');

  my $body   = $c->request->body;
  my $params = decode_json <$body>;

  no strict 'refs';
  my $uuid   = $c->stash->{uuid} || $params->{uuid};
  my $node   = $params->{node};
  my $r      = $vps_model->unset_tmp_active_vps( $uuid );

  $c->stash->{result} = 0;
  if ($r) {
    $c->stash->{result}   = 1;
    $c->stash->{message}  = "cleanup for boot temporary record for $uuid";
    $node and
      $c->stash->{message} .= " on $node";
  }

}

# nodeコントローラに処理を委譲
sub shutdown :Private {
  my ($self, $c, @args) = @_;

  my $project_id = $c->stash->{project_id};
  if (! $project_id) {
    $c->detach("/stop_error", ["project_id is empty"]);
  }

  my $body   = $c->request->body;
  my $params = decode_json <$body>;

  my $uuid   = $c->stash->{uuid};

  my $to_params = {
                     uuid       => $uuid,
                     project_id => $project_id,
                   };


  $c->stash->{to_job_params} = $to_params;

  $c->log->info( "$uuid try shutdown request forward to node" );
  $c->detach( '/node/job/vps/shutdown/', \@args );
}

# nodeコントローラに処理を委譲
sub terminate :Private {
  my ($self, $c, @args) = @_;

  my $project_id = $c->stash->{project_id};
  if (! $project_id) {
    $c->detach("/stop_error", ["project_id is empty"]);
  }

  my $body   = $c->request->body;
  my $params = decode_json <$body>;

  my $uuid   = $c->stash->{uuid};

  my $to_params = {
                     uuid       => $uuid,
                     project_id => $project_id,
                   };

  $c->stash->{to_job_params} = $to_params;

  $c->log->info( "$uuid try terminate request forward to node" );
  $c->detach( '/node/job/vps/terminate/', \@args );
}


sub migration :Private {
  my ($self, $c, @args) = @_;

  my $project_id = $c->stash->{project_id};
  if (! $project_id) {
    $c->detach("/stop_error", ["project_id is empty"]);
  }

  my $body   = $c->request->body;
  my $params = decode_json <$body>;

  my $uuid   = $c->stash->{uuid};

  if (! $project_id) {
    $c->detach("/stop_error", ["project_id is empty"]);
  }

  my $define_model = $c->model('VPS_Define');
  my $info = $define_model->info( $uuid );

  my $to_params = {
                    uuid     => $uuid,
                    dst_node => $params->{dst_node},
                    info     => $info,
                  };

  $c->stash->{to_job_params} = $to_params;

  $c->log->info( "$uuid try migration request forward to node" );
  $c->detach( '/node/job/vps/migration/', \@args );

}

sub auto :Private {
  my ($self, $c) = @_;

  no strict 'refs';
  if ($c->stash->{valid_node}) {
    return 1;
  }

  if (exists $c->stash->{uuid} and exists $c->stash->{project_id}) {
    my $vps_define_model = $c->model('VPS_Define');

    # だめなら例外
    my $valid = $vps_define_model->is_valid_vps_for_project( $c->stash->{project_id}, $c->stash->{uuid} );

    return $valid;

  }
  elsif ( not exists $c->stash->{uuid} and $c->stash->{project_id} ) {
    return 1;

  }

  warn "auth failed";

  return 0;

}


=head1 AUTHOR

shin5ok

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;


1;
