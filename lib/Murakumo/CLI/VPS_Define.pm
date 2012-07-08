use strict;
use warnings;
package Murakumo::CLI::VPS_Define 0.01;

use JSON;
use Data::Dumper;
use XML::TreePP;
use DateTime;
use Carp;
use Path::Class;

use lib qw( /home/smc/Murakumo/lib );
use Murakumo::CLI::Utils;
use Murakumo::CLI::DB;
use base q(Murakumo::CLI::DB);
use Murakumo::CLI::VPS_Define::XML;

# utils オブジェクト
our $utils  = Murakumo::CLI::Utils->new;
our $config = $utils->config;

sub info_include_tmp {
  my ($self, $uuid) = @_;
  return $self->info($uuid, 1);
}

sub info {
  my ($self, $uuid, $include_tmp) = @_;

  my $vps_define_rs   = $self->schema->resultset('VpsDefine');
  my $disk_define_rs  = $self->schema->resultset('DiskDefine');
  my $iface_define_rs = $self->schema->resultset('InterfaceDefine');
  my $ip_rs           = $self->schema->resultset('Ip');
  my $r = {};
  local $@;
  eval {

    my %query = (
      vps   => { uuid     => $uuid },
      disk  => { vps_uuid => $uuid },
      iface => { vps_uuid => $uuid },
    );

    no strict 'refs';
    if ( ! $include_tmp ) {
      for my $x ( keys %query ) {
        $query{$x}->{ready} = 1;
      }
    }
    warn Dumper \%query if exists $ENV{DEBUG};

    my ($vps_r)  = $vps_define_rs  ->search( $query{vps}                                 ); 
    # diskは regist_timeでソート
    my @disk_rs  = $disk_define_rs ->search( $query{disk} , { order_by => 'regist_time' } );
    # interfacesは seqが登録順なので、それでソート
    my @iface_rs = $iface_define_rs->search( $query{iface}, { order_by => 'seq' }        );
    my @ip_rs_rs = $ip_rs          ->search( { used_vps_uuid => $uuid }                  );

    $r = {
      uuid         => $vps_r->uuid,
      name         => $vps_r->name,
      cpu_number   => $vps_r->cpu_number,
      memory       => $vps_r->memory,
      clock        => $vps_r->clock,
      cdrom_path   => $vps_r->cdrom_path,
      project_id   => $vps_r->project_id,
      vnc_password => $vps_r->vnc_password,
    };

    my %ips;
    for my $ip_r ( @ip_rs_rs ) {
      # 同じvlanに複数ある場合は上書きされて、新しいものが優先される
      my $x = {
        ip      => $ip_r->ip,
        mask    => $ip_r->mask,
        gw      => $ip_r->gw,
      };
      my $vlan_id = $ip_r->vlan_id;
      $ips{$vlan_id} = $x;
    }

    my @iface_results;
    for my $iface_r ( @iface_rs ) {
      my $vlan_id = $iface_r->vlan_id;
      my $ip_param = exists $ips{$vlan_id}
                   ? $ips{$vlan_id}
                   : undef;

      my $x = {
        vlan_id  => $vlan_id,
        mac      => $iface_r->mac,
        driver   => $iface_r->driver,
      };
      $ENV{DEBUG} and 
        $x->{sequence} = $iface_r->seq;

      $ip_param and $x->{ip} = $ip_param;

      push @iface_results, $x;
    }

    my @disk_results;
    for my $disk_r ( @disk_rs ) {
      my $x = {
        image_path => $disk_r->image_path,
        driver     => $disk_r->driver,
        size       => $disk_r->size,
      };
      push @disk_results, $x;
    }

    $r->{disks}      = \@disk_results;
    $r->{interfaces} = \@iface_results;

  };

  if ($@) {
    warn $@ if $ENV{DEBUG};
    return undef;
  }

  return $r;

}

sub get_define_json2 {
  my ($self, $uuid) = @_;
  my $ref = $self->info( $uuid );

  encode_json { root => $ref };

}

sub list { goto \&list_from_db; }

sub xml_sync {
  my ($self, @args) = @_;
  my $xml_obj = Murakumo::CLI::DB::VPS_Define::XML->new;
  $xml_obj->sync( @args );
}

sub all_deleted {
  my ($self, $uuid, $cancel) = @_;

  my $iface_define_rs = $self->schema->resultset('InterfaceDefine');
  my $disk_define_rs  = $self->schema->resultset('DiskDefine');
  my $vps_define_rs   = $self->schema->resultset('VpsDefine');
  my $ip_rs           = $self->schema->resultset('Ip');

  my $ok = 0;
  my $txn = $self->schema->txn_scope_guard;
  local $@;
  eval {

    if (! $cancel) {

      $disk_define_rs ->search({ vps_uuid => $uuid, try_remove => 1, })->delete; 
      $iface_define_rs->search({ vps_uuid => $uuid, try_remove => 1, })->delete;
      $vps_define_rs  ->search({     uuid => $uuid, try_remove => 1, })->delete;

      # ipは消さずに解放
      $ip_rs->search({ used_vps_uuid => $uuid, try_release => 1, })
            ->update({ 
                       mac           => undef,
                       used_vps_uuid => undef,
                       reserve_uuid  => undef,
                       try_release   => undef,
                     });

    } else {

      $disk_define_rs ->search({ vps_uuid => $uuid, try_remove => 1, })->update({ try_remove => undef, }); 
      $iface_define_rs->search({ vps_uuid => $uuid, try_remove => 1, })->update({ try_remove => undef, });
      $vps_define_rs  ->search({     uuid => $uuid, try_remove => 1, })->update({ try_remove => undef, });

      # ipは消さずに解放
      $ip_rs->search({ used_vps_uuid => $uuid, try_release => 1, })
            ->update({ try_release   => undef } );

    }
  };
  
  if ($@) {
    croak $@;
  } else {
    # 例外エラーがなければcommit
    $txn->commit;
  }

  return 1;
}

sub all_cancel_deleted {
  my ($self, $uuid) = @_;
  $self->all_deleted( $uuid, 1 );

}


sub delete {
  my ($self, $uuid) = @_;

  my $iface_define_rs = $self->schema->resultset('InterfaceDefine');
  my $disk_define_rs  = $self->schema->resultset('DiskDefine');
  my $vps_define_rs   = $self->schema->resultset('VpsDefine');
  my $ip_rs           = $self->schema->resultset('Ip');

  my $ok = 0;
  my $txn = $self->schema->txn_scope_guard;
  my %delete;
  local $@;
  eval {

    $delete{disk}  = $disk_define_rs ->search({ vps_uuid => $uuid })->update({ try_remove => 1 }); 
    $delete{iface} = $iface_define_rs->search({ vps_uuid => $uuid })->update({ try_remove => 1 });
    $delete{vps}   = $vps_define_rs  ->search({     uuid => $uuid })->update({ try_remove => 1 });

    # ipは消さずに解放
    $ip_rs->search({ used_vps_uuid => $uuid })
          ->update({ try_release   => 1     });
  };
  
  if ($@) {
    warn $@;
  } else {
    # 例外エラーがなければcommit
    $txn->commit;
    $ok = 1;
  }

  return { ok => $ok, deleted => \%delete };

}

sub create_disk_param_array {
  my ($self, $array_ref, $argv) = @_;
  warn "--- _create_disk_param_array ---";
  warn Dumper $argv;

  # ドライバは、ディスクを複数指定しても全ディスクで共通
  # いまは virtio の対応のみ
  my $driver = exists $argv->{driver}
             ? $argv->{driver}
             : "virtio";

  my $project_id = $argv->{project_id};
  my $uuid       = $argv->{uuid};

  if (! $project_id or ! $uuid) {
    croak "*** project_id or uuid has no value";
  }

  my @disks;

  my $number = exists $argv->{number}
             ? $argv->{number}
             : 1;

  $array_ref ||= [ "0" ];

  my $storage_uuid = $argv->{storage_uuid};

  if (! $storage_uuid) {
    require Murakumo::CLI::Storage;
    $storage_uuid = Murakumo::CLI::Storage->new->select;

  }

  $storage_uuid
    or croak "*** storage uuid get error...";
  warn "storage_uuid : $storage_uuid";

  my $vm_root = $config->{vm_root};
  $vm_root    =~ s{^/+}{};

  for my $size ( @$array_ref ) {
    my $suffix = sprintf "-%02d", $number;

    my $path    = sprintf "/%s/%s/%s/%s%s.img", $vm_root,
                                                  $storage_uuid,
                                                  $project_id,
                                                  $uuid,
                                                  $suffix;
    my %param = (
      size        => $size,
      image_path  => $path,
      driver      => $driver,
      project_id  => $project_id,
    );

    push @disks, \%param;
    $number++;

  }

  return @disks if wantarray;
  return $disks[0];
}

sub create_or_modify {
  my ($self, $project_id, $uuid, $vps_params) = @_;
  warn "--- ", __FILE__ , "#create_or_modify -----------";
  warn Dumper $vps_params;
  warn "-----------------------------------------------";

  # 引数
  # create_or_modify( プロジェクトID(ex: 111),
  #                   vpsのuuid(ex: cd9b431b-a612-4685-bb97-c44a07072382),
  #                   {
  #                     project_id => project_id の int(scalar),
  #                     vps        => vps       の hash ref,
  #                     interface  => interface の array ref,
  #                     disk       => disk      の array ref,
  #                   },
  #                  );

  my $vps_spec = $vps_params->{spec};

  my @iface_args_refs = exists $vps_params->{interface} 
                      ? @{$vps_params->{interface}}
                      : ();

  if (! $project_id) {
    croak "*** project_id param is required";
  }

  if (! exists $vps_spec->{uuid}) {
    $vps_spec->{uuid} = $uuid;
  }

  my $iface_define_rs = $self->schema->resultset('InterfaceDefine');
  my $disk_define_rs  = $self->schema->resultset('DiskDefine');
  my $vps_define_rs   = $self->schema->resultset('VpsDefine');
  my $ip_rs           = $self->schema->resultset('Ip');

  my @disk_args_refs;
  if (exists $vps_params->{disk}) {
    my @current_disks = $disk_define_rs->search({ vps_uuid => $uuid });

    my $storage_uuid;
    {
      no strict 'refs';
      $storage_uuid = $vps_params->{storage_uuid};
    }
    my $current_disk_number = @current_disks + 1;
    @disk_args_refs = $self->create_disk_param_array( $vps_params->{disk},
                                                     {
                                                       project_id   => $project_id,
                                                       uuid         => $uuid,
                                                       number       => $current_disk_number,
                                                       storage_uuid => $storage_uuid,
                                                     }
                                                    );
  }

  my @ip_params;
  my $reserve_uuid;
  my $ip_model;

  # トランザクション開始
  my $txn = $self->schema->txn_scope_guard;
  local $@;
  eval {
    # できれば mysqlの日付型に自動変換
    # my $now = $utils->now_string;
    my $now = DateTime->now(time_zone => 'Asia/Tokyo');

    my ($is_vps_exists) = $vps_define_rs->search({ uuid => $uuid });
   
    no strict 'refs';
    my $seq = 0;
    if ( @disk_args_refs > 0) {
      # vpsに関連付けられた既存のdiskのレコードを削除
      # my $delete_count = $disk_define_rs->search({ vps_uuid => $uuid })->delete;
      # warn "delete_count : $delete_count";
      # => 削除はしない 追加のみ

      # 新しくvpsに関連付けたdiskのレコードを追加
      for my $disk_args_ref ( @disk_args_refs ) {

        $disk_args_ref->{regist_time} = $now;
        $disk_args_ref->{project_id}  = $project_id;
        $disk_args_ref->{vps_uuid}    = $uuid;
        $disk_define_rs->create( $disk_args_ref );

      }
    }

    my @vlan_ids;
    if ( @iface_args_refs > 0 ) {
      # vpsに関連付けられた既存のinterfaceのレコードを削除
      $iface_define_rs->search({ vps_uuid => $uuid })->delete;

      # 新しくvpsに関連付けたinterfaceのレコードを追加
      my $seq = 0;
      for my $iface_args_ref ( @iface_args_refs ) {
        $iface_args_ref->{project_id}  = $project_id;
        $iface_args_ref->{vps_uuid}    = $uuid;
        $iface_args_ref->{regist_time} = $now;

        # interface は DBに入れることができれば、ready = 1;
        $iface_args_ref->{ready}       = 1;
        $iface_args_ref->{seq}         = ++$seq;
        
        warn Dumper $iface_args_ref;
        $iface_define_rs->create( $iface_args_ref );

      }
    }
   
    # 使われてない ip の解放
    # $ip_rs->search({ vps_uuid => $uuid })
    #       ->search(\@vlan_ids)
    #       ->update( {
    #                   used_vps_uuid => undef,
    #                   reserve_uuid  => undef,
    #                   try_release   => undef,
    #                   mac           => undef,
    #                  } );

    $vps_spec->{regist_time} = $now;

    $vps_spec->{project_id}  = $project_id;
    $vps_spec->{ready}       = $is_vps_exists
                             ? 1
                             : 0;

    $vps_define_rs->update_or_create( $vps_spec, { uuid => $uuid } );

  };

  my $defined_error = $@;

  # トランザクション確定
  $txn->commit;

  if ($defined_error) {
    warn "defined error > ", $defined_error;
    return 0;
  }

  return 1;
}

# vps一覧 => list()
sub list_from_db {
  my ($self, $project_id) = @_;
  if (! defined $project_id) {
    croak "project_id parameter must be specified...";
  }
  my $resultset = $self->schema->resultset('VpsDefine');
  # きちんとエラー処理をすること
  my $rs = $resultset->search( { project_id => $project_id, ready => 1, }, { order_by => 'regist_time' } );
  my @vpses;
  while (my $x = $rs->next) {
    push @vpses, {
                   name               => $x->name,
                   uuid               => $x->uuid,
                   memory             => $x->memory,
                   cpu_number         => $x->cpu_number,
                   update_time        => $x->update_time,
                   regist_time        => $x->regist_time,
                 };
  }
  return \@vpses;
}

sub record_cloning {
  my ( $self, $org_uuid, $args_ref, $opt_args_ref ) = @_;

  my $vps_define_rs   = $self->schema->resultset('VpsDefine');
  my $disk_define_rs  = $self->schema->resultset('DiskDefine');
  my $iface_define_rs = $self->schema->resultset('InterfaceDefine');

warn "record_cloning...";
warn Dumper $org_uuid;
warn Dumper $args_ref;

  my $uuid = $args_ref->{uuid};
  my $project_id;
  my $param_ref;

  my $org_info = $self->info( $org_uuid );

  # my $now = $utils->now_string;
  my $now = $utils->now;
  my $txn = $self->schema->txn_scope_guard;

  {
    no strict 'refs';

    $project_id = $args_ref->{project_id} || $org_info->{project_id};

    my %param = (
      memory        => $org_info->{memory},
      cpu_number    => $org_info->{cpu_number},
      uuid          => $uuid,
      name          => $uuid,
      project_id    => $project_id,
      clock         => $org_info->{clock},
      template_flag => 0,
      ready         => 0,
      regist_time   => $now,
    );  

    %param = (%param, %$args_ref);
    warn "record cloning vps";
    warn Dumper \%param;

    # 元となるvpsのname
    $param{'original'} = $org_uuid;

    local $@;
    eval {
      warn Dumper \%param;
      my ($created) = $vps_define_rs->create( \%param );

      if (! $created) {
        warn   "create error";
        return "create error";
      }
    };

    if ($@) {
      croak $@;
    }
    $param_ref = \%param;

  }

  {

    my $number = 1;

    my @disks = @{$org_info->{disks}};
    if (@disks > 0) {
      for my $disk ( $disks[0] ) { # とりあえず、最初の1つだけ作成する

        my $dst_image = $self->create_disk_param_array( 0,  # 名前だけがほしいので、サイズは 0
                                                       {
                                                         number     => $number,
                                                         project_id => $project_id,
                                                         uuid       => $uuid,
                                                       },
                                                      );

        # clone をするノードに伝える dst_diskパス名
        $param_ref->{dst_image_path} = $dst_image->{image_path};
        # clone をするノードに伝える src_diskパス名
        $param_ref->{src_image_path} = $disk->{image_path};

        my %param = (
          project_id  => $project_id,
          image_path  => $dst_image->{image_path},
          driver      => $disk->{driver},
          vps_uuid    => $uuid,
          size        => $disk->{size},
          regist_time => $now,
        );  


        local $@;
        eval {
        warn Dumper \%param;
          my ($created) = $disk_define_rs->create( \%param );

          if (! $created) {
            croak "disk create error";
          }
        };

        if ($@) {
          warn $@;
          return 0;
        }
      }
    }

    $number++;

  }

  my @specify_vlan_ids;
  if (exists $opt_args_ref->{vlan_id} and $opt_args_ref->{vlan_id}) {
    @specify_vlan_ids = split /,/, $opt_args_ref->{vlan_id};
  }

  my $mac_of_first;
  {

    my $number = 0;

    my @ifaces = @{$org_info->{interfaces}};
    if (@ifaces > 0) {
      for my $interface ( $ifaces[0] ) {

        my $mac = $utils->create_random_mac;
        $mac_of_first ||= $mac;

        my %param = (
          project_id  => $project_id,
          vlan_id     => exists $specify_vlan_ids[$number]
                         ? $specify_vlan_ids[$number]
                         : $interface->{vlan_id},
          # vlan_id     => $interface->{vlan_id},
          driver      => $interface->{driver},
          ip          => undef,
          vps_uuid    => $uuid,
          mac         => $mac,
          regist_time => $now,
          seq         => ++$number,
        );

        local $@;
        eval {
        warn Dumper \%param;
          my ($created) = $iface_define_rs->create( \%param );

          if (! $created) {
            croak "interface create error";
          }
        };

        if ($@) {
          warn $@;
          return 0;
        }
      }
    }
   
  }

  # 最初のmacアドレスを設定
  $param_ref->{mac} = $mac_of_first;
  $txn->commit;

  return $param_ref;

}

sub commit_define {
  my ($self, $project_id, $uuid) = @_;

  my $vps_define_rs   = $self->schema->resultset('VpsDefine');
  my $disk_define_rs  = $self->schema->resultset('DiskDefine');
  my $iface_define_rs = $self->schema->resultset('InterfaceDefine');

  my $txn = $self->schema->txn_scope_guard;
  local $@;
  eval {
    $vps_define_rs  ->search({ uuid     => $uuid, project_id => $project_id, })->update({ ready => 1 }); 
    $disk_define_rs ->search({ vps_uuid => $uuid, project_id => $project_id, })->update({ ready => 1 });  
    $iface_define_rs->search({ vps_uuid => $uuid, project_id => $project_id, })->update({ ready => 1 });
  };
  if ($@) {
    warn __FILE__, ": ", $@;
    return 0;

  } else {
    $txn->commit;
    return 1;
  }

}

sub cancel_define {
  my ($self, $project_id, $uuid) = @_;

  my $vps_define_rs   = $self->schema->resultset('VpsDefine');
  my $disk_define_rs  = $self->schema->resultset('DiskDefine');
  my $iface_define_rs = $self->schema->resultset('InterfaceDefine');

  my $txn = $self->schema->txn_scope_guard;
  local $@;
  eval {
    $vps_define_rs  ->search({ uuid     => $uuid, project_id => $project_id, ready => 0 })->delete;
    $disk_define_rs ->search({ vps_uuid => $uuid, project_id => $project_id, ready => 0 })->delete;  
    $iface_define_rs->search({ vps_uuid => $uuid, project_id => $project_id, ready => 0 })->delete;
  };
  $@ or $txn->commit;

}

1;
