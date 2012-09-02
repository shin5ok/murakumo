package Murakumo::Controller::Node;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Murakumo::Controller::Node - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut
use Carp;
use Data::Dumper;
use JSON;
use Murakumo::CLI::Utils;

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched Murakumo::Controller::Node in Node.');
}

sub run :Local {

  my ($self, $c, @args) = @_;

  my $request_arg = @args >= 2
                  ? join '/', grep { warn $_;defined $_ } @args # なぜかundef が入っているので
                  : $args[0];

  my $body   = $c->request->body;
  my $params = decode_json <$body>;

  my $vps_model  = $c->model('VPS');
  my $node_model = $c->model('Node');

  # どのノードに処理をさせるか
  my $node;

  # uuid指定で、起動中のvps にshutdownや、操作をする場合
  if (exists $params->{uuid} and $params->{uuid}) {
    $node = $vps_model->get_node( $params->{uuid} );
  }

  # ノードにポート番号がついていなかったら、付ける
  $node =~ /:\d+$/
     or $node .= ":" . $c->config->{api_port};

  my $uri = $node_model->make_uri(
                              $node,
                              $request_arg,
                            );
  # デフォルト失敗
  # $c->stash->{result} = 0;

  my $response_json = $node_model->api_json_post($uri, $params);
  my $response_hash = decode_json $response_json;

  if (! $response_json) {
    $c->detach('/stop_error', ["api request error($uri, $params)"]);
  }

  for my $key_of_hash ( keys %$response_hash ) {
    $c->stash->{$key_of_hash} = $response_hash->{$key_of_hash};
  }


}

sub job :Local {
  my ($self, $c, @args) = @_;
  # nodeにリクエストを送るから model Node
  my $node_model = $c->model('Node');
  my $ip_model   = $c->model('IP');
  my $job_model  = $c->model('Job');
  my $vps_model  = $c->model('VPS');

  my $request_arg = @args >= 2
                  ? join '/', grep { defined $_ } @args # なぜかundef が入っているので
                  : $args[0];

  my $params     = delete $c->stash->{to_job_params};
  my $project_id = $c->stash->{project_id};
  $params->{project_id} = $project_id;

  dumper($params);

  my $job_uuid   = exists $params->{'job_uuid'}
                 ? $params->{'job_uuid'}
                 : "";

  my $callback_func;
  # エラー処理用のサブルーチン
  if (exists $c->stash->{__callback_for_error}) {
    $callback_func = $c->stash->{__callback_for_error};
    delete $c->stash->{__callback_for_error};
  }

  # どのノードに処理をさせるか
  my $node;

  # ストレージ操作、スイッチ操作とか、並列に動作させない処理は固定のノードに
  my $fix_request_arg = $c->config->{'fix_request_arg'};
  if ( grep { /$request_arg/ } @$fix_request_arg ) {
    $c->log->info( "url /$request_arg/ fix request node => " . $c->config->{'fix_request_node'} );
    $node = $c->config->{'fix_request_node'};

  }

  # でも、直に指定したら、そっち優先↓で
  if (exists $params->{node} and $params->{node}) {
    $node = $params->{node};

  }
  # uuid指定で、起動中のvps にshutdownや、操作をする場合
  elsif (exists $params->{uuid} and $params->{uuid}) {
    my $vps_node;
    local $@;
    eval {
      $vps_node = $vps_model->get_node( $params->{uuid} );
    };
    $@ and warn $@;

    # uuidが起動しているnodeが取得できたら
    $vps_node and $node = $vps_node;

  }

  # uuidが指定できない、つまり、起動していないvpsについて
  # や起動をする場合
  # ノードを選択する
  if (! $node) {

    my %require_params = ();
    if (exists $params->{vps}->{spec}) {
      my $spec = $params->{vps}->{spec};
      %require_params = (
                          cpu_number => $spec->{cpu_number},
                          memory     => $spec->{memory},
                        );
    }

    local $@;
    eval {
      $node = $node_model->select(%require_params);
    };
    if ($@ or ! $node) {
      warn $@;
      $c->stash->{message} = "available node is none";
      $@ and $c->stash->{message} .= "($@)";

      $c->log->warn( $c->stash->{message} );

      # コールバック関数を呼ぶ... revert
      ref $callback_func eq 'CODE' and $callback_func->();
      return $c->forward( $c->view('JSON') );

    }
  }

  # ノードにポート番号がついていなかったら、付ける
  $node =~ /:\d+$/
     or $node .= ":" . $c->config->{api_port};

  $c->stash->{node} = $node;

  my $uri = $node_model->make_uri(
                              $node,
                              $request_arg,
                            );

  $c->log->info("select node => $node");
  $c->log->info("uri => $uri");

  # request_job は空で登録し、いったん、job_uuid を取得
  $job_uuid = $job_model->create( { request_job => "", project_id => $project_id, job_uuid => $job_uuid, } );
  $params->{job_uuid} = $c->stash->{job_uuid} = $job_uuid;

  my $request_job;
  {
    local $Data::Dumper::Terse = 1;
    $request_job = sprintf "api_target => %s, call => %s, param => %s",
                           $node,
                           $request_arg,
                           Dumper $params;
  }

  $job_model->update( $job_uuid, { request_job => $request_job } );

  # node にproxy的に送ります
  my $utils     = Murakumo::CLI::Utils->new;
  my @hostnames = $utils->my_hostname;

  $params->{callback_host} = $hostnames[1];
  my $response_json = $node_model->api_json_post($uri, $params);

  if (! $response_json) {
    $c->detach('/stop_error', ["api request error($uri, $params)"]);

  }

  my $response_hash = decode_json $response_json;

  for my $key_of_hash ( keys %$response_hash ) {
    $c->stash->{$key_of_hash} = $response_hash->{$key_of_hash};
  }

  $c->log->info("node job " . Dumper $c->stash );

}

sub register :Local {
  my ($self, $c) = @_;

  my $body   = $c->request->body;
  my $params = decode_json <$body>;

  my $vps_model  = $c->model('VPS');
  my $node_model = $c->model('Node');

  my $vps_r  = $vps_model->register(
                                     $params->{node}->{name},
                                     $params->{update_key},
                                     $params->{vpses},
                                   );
  my $node_r = $node_model->register(
                                     $params->{node}->{name},
                                     $params->{node},
                                    );

  if ( $vps_r and $node_r ) {
    $c->stash->{result} = 1;
  } else {
    $c->stash->{result} = 0;
  }

}

sub list :Local {

  my ($self, $c) = @_;
  my $node_model = $c->model('Node');
  $c->log->info("node list called");

  my $params  = $c->request->query_params;
  my $verbose;
  {
    no strict 'refs';
    $verbose = $params->{'verbose'} || "";
  }

  my $time_until;
  if (! $verbose) {
    $time_until = DateTime->now(time_zone => 'Asia/Tokyo');
    $time_until->subtract( seconds => $c->config->{node_list_expire_second} );
    warn "time_until apply";
  }

  $c->stash->{result} = 0;
  $c->stash->{node}   = [];
  if (my @node_lists = $node_model->list($time_until)) {
    $c->stash->{node}   = \@node_lists;
    $c->stash->{result} = 1;
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
