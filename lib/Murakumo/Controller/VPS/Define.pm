package Murakumo::Controller::VPS::Define;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Murakumo::Controller::VPS::Define - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

use Carp;
use JSON;
use Data::Dumper;
use Path::Class;
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

sub tag_list :Private {
  my ($self, $c) = @_;

  my $project_id = $c->stash->{project_id};
  if (! $project_id) {
    $c->detach("/stop_error", ["project_id is empty"]);
  }

  my $define_model    = $c->model('VPS_Define');
  $c->stash->{data}   = $define_model->tag_list( $project_id );
  $c->stash->{result} = 1;

}

sub list :Private {
  my ($self, $c) = @_;

  my $project_id = $c->stash->{project_id};
  if (! $project_id) {
    $c->detach("/stop_error", ["project_id is empty"]);
  }

  my $tag             = $c->request->query_params->{tag} || '';
  my $define_model    = $c->model('VPS_Define');
  $c->stash->{data}   = $define_model->list( $project_id, $tag );
  $c->stash->{tag}    = $tag;
  $c->stash->{result} = 1;

}

sub info_list: Private {
  my ($self, $c) = @_;
  my $project_id = $c->stash->{project_id};
  if (! $project_id) {
    $c->detach("/stop_error", ["project_id is empty"]);
  }

  my $tag             = $c->request->query_params->{tag} || '';
  my $define_model    = $c->model('VPS_Define');
  $c->stash->{data}   = $define_model->info_list( $project_id, $tag );
  $c->stash->{tag}    = $tag;
  $c->stash->{result} = 1;

}

sub clone :Private {
  my ($self, $c) = @_;
  $c->log->info("clone start");
  my $body   = $c->request->body;
  my $params = decode_json <$body>;

  dumper($c->stash);
  dumper($params);

  no strict 'refs';

  my $project_id = $c->stash->{project_id};
  if (! $project_id) {
    $c->detach("/stop_error", ["project_id is empty"]);
  }

  my $define_model = $c->model('VPS_Define');
  my $vps_model    = $c->model('VPS');
  my $ip_model     = $c->model('IP');

  my $src_uuid     = $params->{src_uuid} = $c->stash->{uuid};

  if ($vps_model->is_active_vps( $src_uuid )) {
    $c->detach("/stop_error", ["vps($src_uuid) is already active"]);
  }

  my $utils        = Murakumo::CLI::Utils->new;
  my $dst_uuid     = $utils->create_uuid;
  my $reserve_uuid = $utils->create_uuid;

  $params->{dst_uuid} = $dst_uuid;

  # ipを予約
  if (exists $params->{'assign_ip'}
         and $params->{'assign_ip'}
           and exists $params->{vlan_id}) {
    my ($ip, $mask, $gw) = $ip_model->reserve_ip({
                                                   reserve_uuid => $reserve_uuid,
                                                   vlan_id      => $params->{vlan_id},
                                                 });

    if (! $ip) {
      croak "ip reserve error";
    }
    # 取得した ip他のパラメータをクエリにセット
    $params->{reserve_uuid} = $reserve_uuid;
    $params->{ip}   = $ip;
    $params->{mask} = $mask;
    $params->{gw}   = $gw;
  }

  my $dst_name = exists $params->{name}
               ? $params->{name}
               : $dst_uuid;

  my $storage_uuid = $params->{storage_uuid};

  my $r;
  local $@;
  eval {

    # 指定されてないなら、undef で渡す
    my $vlan_id  = $params->{vlan_id};

    $r = $define_model->record_cloning( $src_uuid, {
                                                     uuid            => $dst_uuid,
                                                     name            => $dst_name,
                                                     instance_status => undef,
                                                     project_id      => $project_id,
                                                    },
                                                    {
                                                      vlan_id      => $vlan_id,
                                                      storage_uuid => $storage_uuid,
                                                    },
                                      );
  };

  if (! $r or $@) {
    my $error_message      = "record_cloning error";
    $@ and $error_message .= "($@)";
    $c->detach("/stop_error", [ $error_message ]);

  }

  $params->{mac}            = $r->{mac};
  $params->{dst_image_path} = $r->{dst_image_path};
  $params->{src_image_path} = $r->{src_image_path};
  $params->{dst_hostname}   = $dst_name;

  $c->stash->{to_job_params} = $params;

  $c->log->info( Dumper $c->stash->{to_job_params} );
  $c->detach( '/node/job/vps/clone/' );

}

sub remove_commit :Local {

  my ($self, $c) = @_;
  my $body   = $c->request->body;
  my $params = decode_json <$body>;
  dumper( $params );
  dumper( $c->stash );

  no strict 'refs';

  my $define_model       = $c->model('VPS_Define');
  my $disk_define_model  = $c->model('DiskDefine');
  my $iface_define_model = $c->model('InterfaceDefine');
  my $ip_model           = $c->model('IP');

  my $force_flag = $params->{force_remove};
  my $vps_uuid   = $c->stash->{uuid} || $params->{vps_uuid};

  my $result   = $params->{result} || 0;

  local $@;
  eval {
    if ($result) { 
      $define_model->all_deleted( $vps_uuid, 0, { force_remove => $force_flag } );
    } else {
      $define_model->all_cancel_deleted( $vps_uuid );
    }
  };
  
  if ($@) {
    $c->log->warn( "eval error: $@" );
    $c->stash->{message} = $@;
    $c->stash->{result}  = 0;
  }
  $c->stash->{result} = 1;

  $c->log->info( $c->stash->{message} );

}


# Node から コールバックされる用のapi
sub commit :Local {
  my ($self, $c) = @_;

  my $body   = $c->request->body;
  my $params = decode_json <$body>;
  dumper($params);

  no strict 'refs';

  my $define_model       = $c->model('VPS_Define');
  my $disk_define_model  = $c->model('DiskDefine');
  my $iface_define_model = $c->model('InterfaceDefine');
  my $ip_model           = $c->model('IP');

  my $project_id   = $params->{project_id};
  my $vps_uuid     = $params->{vps_uuid};
  my $reserve_uuid = $params->{reserve_uuid};

  my $result       = $params->{result} || 0;

  local $@;
  eval {

    no strict 'refs';

    $c->stash->{result} = $result;

    if ( ! $result ) {
      local $Data::Dumper::Terse = 1;
      $c->stash->{message} = sprintf "vps define create/clone miss (%s)", Dumper $params;
      $@ and $c->stash->{message} .= " eval error $@";

      $c->log->warn( $c->stash->{message} );

      # 本当は、IPのmodelに切り出して、forwardした方がきれいかも

      # 予約したipをキャンセル
      $ip_model->cancel_reserve_ip( { reserve_uuid => $reserve_uuid } );

      $define_model->cancel_define( $vps_uuid );

    } else {

      # 本当は、IPのmodelに切り出して、forwardした方がきれいかも
      # ipを確定
      my $return_param = {
                           reserve_uuid => $reserve_uuid,
                           vps_uuid     => $vps_uuid,
                         };
      $reserve_uuid and
         $ip_model->commit_assign_ip( $return_param );

      $define_model->commit_define( $vps_uuid );

      $c->stash->{param}= $return_param;
    }

  };

  if ($@) {
    $c->log->warn( "eval error: $@" );
    $c->stash->{error} = $@;
  }

  $c->stash->{result} = 1;
  $c->log->info( sprintf "commit ok(%s)", Dumper $params );

}

sub create_or_modify: Private {

  my ($self, $c) = @_;
  my $mode   = $c->request->args->[0];
  my $body   = $c->request->body;
  my $params = decode_json <$body>;

  my $args = {};

  no strict 'refs';

  my $uuid       = $c->stash->{uuid};
  my $project_id = $c->stash->{project_id};
  if (! $project_id) {
    $c->detach("/stop_error", ["project_id is empty"]);
  }

  my $vps_params = $params->{vps};

  my $utils = Murakumo::CLI::Utils->new;

  my $vps_define_model = $c->model('VPS_Define');
  if ($mode eq 'modify') {

    if (! $vps_define_model->info($uuid)) {
      $c->detach( '/stop_error', [ "*** vps $uuid is not found..." ] );
    }

  }
  elsif ($mode eq 'create') {

    if (not exists $vps_params->{disk}->[0]) {
      $c->detach('/stop_error', ["disk parameter is required"]);
    }

    # create で uuidが指定されなかったら自動生成
    if (! $uuid) {
      $uuid = $utils->create_uuid;
      warn "controller /vps/define/create/ create uuid: $uuid";
    }

    # create の場合、name が指定されていなかったら、uuidを入れる
    defined $vps_params->{spec}->{name}
      or $vps_params->{spec}->{name} = $uuid;


  } else {
    $c->detach('/stop_error', ["mode: $mode is error"]);

  }

  my $ip_model = $c->model('IP');
  my $reserve_uuid;

  my $to_params;
  local $@;
  eval {

    dumper($vps_params);

    my $options = {};
    exists $params->{driver} and
      $options->{driver} = $params->{driver};

    $options->{mode} = $mode;

    if ( $vps_define_model->create_or_modify($project_id, $uuid, $vps_params, $options) ) {

      my $info = $vps_define_model->info_include_tmp($uuid);
      my $disks_ref = $info->{disks};

      # disk のハッシュを JSON化 失敗したら例外
      $to_params->{disks} = $disks_ref;

      # ipを予約
      if (exists $params->{'assign_ip'}
             and $params->{'assign_ip'}
               and exists $params->{vlan_id}) {

        $reserve_uuid = $utils->create_uuid;
        my @vlan_ids = split /,/, $params->{vlan_id};

        for my $vlan_id ( @vlan_ids ) {
          my @ip_params = $ip_model->reserve_ip( {
                                                   reserve_uuid  => $reserve_uuid,
                                                   vlan_id       => $vlan_id,
                                                   used_vps_uuid => $mode eq 'modify'
                                                                  ? $uuid
                                                                  : undef,
                                                  } );

          if (@ip_params != 3) {
            warn "ip of vlan $vlan_id reserve none";

          } else {
            if ($mode eq 'modify') {
              # modifyのときはすぐにcommit
              $ip_model->commit_assign_ip({
                                            reserve_uuid => $reserve_uuid,
                                            vps_uuid     => $uuid,
                                          });

            } else {
              # 取得した reserve_uuid をクエリにセット
              $to_params->{reserve_uuid} = $reserve_uuid;

            }
          }
        }
      }
     
     } else {
       $c->detach("/stop_error", ["vps define create error project: $project_id, uuid: $uuid"] );

     }

   };

   if (! $@) {

      $to_params->{vps_uuid} = $uuid;

      $c->log->info("vps define $mode...");

      # disk の作成処理が入っていたら
      # ip の コミット、キャンセルは、callback に任せる
      if (exists $vps_params->{disk} and @{$vps_params->{disk}} > 0) {
        # ['create'] をいったん空に
        $c->request->args([]); 
        $c->stash->{to_job_params} = $to_params;

        $c->detach( '/node/job/vps/create/' );

      } else {
        if ($mode eq 'create') {
          $c->stash->{message} = "vps $uuid is created(no disk create)";
        } else {
          $c->stash->{message} = "vps $uuid is modified(no disk modify)";
        }

        $c->log->info( $c->stash->{message} );

        if (exists $params->{reserve_uuid} and $params->{reserve_uuid}) {
          my $ip_param_commit = {
                                  reserve_uuid => $reserve_uuid,
                                  vps_uuid     => $uuid,
                                };
          $ip_model->commit_assign_ip( $ip_param_commit );
        }
        $c->stash->{result}  = 1;
        return $c->forward( $c->view('JSON') );

      }
    }

    # ここからエラーのパート
    # ip をキャンセル
    if ($reserve_uuid) {
      $ip_model->cancel_reserve_ip( { reserve_uuid => $reserve_uuid } );
    }

    $c->stash->{result}   = 0;
    $c->stash->{message}  = "vps $uuid is create error";
    $c->stash->{message} .= "($@)" if $@;

    $c->log->warn( $c->stash->{message} );

}


sub create :Private {
  my ($self, $c) = @_;
  $c->detach('create_or_modify', ['create']);
}

sub modify :Private {
  my ($self, $c) = @_;
  $c->detach('create_or_modify', ['modify']);
}

sub remove :Private {
  my ($self, $c) = @_;
  my $body   = $c->request->body;
  my $params = decode_json <$body>;

  my $uuid       = $c->stash->{uuid};
  my $project_id = $c->stash->{project_id};

  if (! $project_id) {
    $c->detach("/stop_error", ["project_id is empty"]);
  }

  my $define_model = $c->model('VPS_Define');
  my $vps_model    = $c->model('VPS');

  $c->{stash}->{result} = 0;

  # 起動しているかチェック
  if ($vps_model->is_active_vps( $uuid )) {
    $c->{stash}->{message} = "vps $uuid is already active... delete error.";
    return $c->forward( $c->view('JSON') );

  }

  my $info = $define_model->info( $uuid );
  my @paths;
  for my $disk_info ( @{$info->{disks}} ) {
    push @paths, $disk_info->{image_path};

  }
  # 削除すべきディスクのパスをセット
  $c->stash->{to_job_params} = {
                                  disks      => \@paths,
                                  uuid       => $uuid,
                                  project_id => $project_id,
                                };

  my $delete_result = $define_model->delete($uuid);

  no strict 'refs';
  if ($delete_result->{ok}) {
    $c->{stash}->{message} = "vps $uuid has deleted.";
    $c->{stash}->{result}  = 1;

  } else {
    $c->{stash}->{message} = "vps $uuid has delete error.";

  }

  $c->log->info( $c->{stash}->{message} );

  if ($delete_result->{deleted}->{disk} > 0) {
    $c->detach('/node/job/vps/remove/');

  } else {
    $c->forward( $c->view('JSON') );

  }
}

sub info :Private {

  my ($self, $c) = @_;

  my $project_id = $c->stash->{project_id};
  if (! $project_id) {
    $c->detach("/stop_error", ["project_id is empty"]);
  }

  my $params = $c->request->query_params;
  my $uuid   = $c->stash->{uuid};

  my $define_model = $c->model('VPS_Define');
  my $info = $define_model->info( $uuid );

  my $json;
  if ($@) {
    $c->stash->{result}  = 0;
    $c->stash->{message} = $@;
  } else {
    $c->stash->{result}  = 1;
    $c->stash->{data}    = $info;
  }

}


sub add_ip :Private {
  my ($self, $c) = @_;

  my $body   = $c->request->body;
  my $params = decode_json <$body>;

  my $uuid       = $c->stash->{uuid};
  my $project_id = $c->stash->{project_id};

  if (! $project_id) {
    $c->detach("/stop_error", ["project_id is empty"]);
  }

  no strict 'refs';
  my $vlan_ids      = $params->{vlan_id};
  my $add_ip_number = $params->{add_ip_number} || 1;

  my $ip_model = $c->model('IP');

  for my $vlan_id ( split /,/, $vlan_ids ) {
    $ip_model->add_ip( $vlan_id, $uuid, $add_ip_number );

  }

  $c->stash->{result} = 1;


}


sub auto :Private {
  my ($self, $c) = @_;

  if (exists $c->stash->{uuid} and exists $c->stash->{project_id}) {
    my $vps_define_model = $c->model('VPS_Define');

    # だめなら例外
    $vps_define_model->is_valid_vps_for_project( $c->stash->{project_id}, $c->stash->{uuid} );

  }

  return 1;

}


=head1 AUTHOR

shingo

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
