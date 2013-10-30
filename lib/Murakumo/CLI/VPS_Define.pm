use strict;
use warnings;
use 5.014;

package Murakumo::CLI::VPS_Define 0.01;

use JSON;
use Data::Dumper;
use File::Basename;
use XML::TreePP;
use DateTime;
use Carp;
use Path::Class;
use URI::Escape;

use FindBin;
use lib qq{$FindBin::Bin/../lib};
use Murakumo::CLI::Utils;
use Murakumo::CLI::DB;
use Murakumo::CLI::Storage;
use base q(Murakumo::CLI::DB);

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
    warn Dumper \%query if is_debug;

    my ($vps_r)  = $vps_define_rs  ->search( $query{vps}  );
    # diskは 検索後、後で image_path の basename でソート
    my @disk_rs  = $disk_define_rs ->search( $query{disk} );
    # interfacesは seqが登録順なので、それでソート
    my @iface_rs = $iface_define_rs->search( $query{iface}, { order_by => 'seq' } );
    my @ip_rs_rs = $ip_rs          ->search( { used_vps_uuid => $uuid }           );

    $r = {
      uuid            => $vps_r->uuid,
      name            => $vps_r->name,
      cpu_number      => $vps_r->cpu_number,
      memory          => $vps_r->memory,
      clock           => $vps_r->clock,
      cdrom_path      => $vps_r->cdrom_path,
      project_id      => $vps_r->project_id,
      vnc_password    => $vps_r->vnc_password,
      tag             => $vps_r->tag  || qq{},
      extra_info      => $vps_r->extra_info || qq{},
      public_template => $vps_r->public_template,
    };

    my %ips;
    my %secondary_ips;
    for my $ip_r ( @ip_rs_rs ) {
      my $vlan_id = $ip_r->vlan_id;

      if ($ip_r->secondary) {

        if (not exists $secondary_ips{$vlan_id}) {
          $secondary_ips{$vlan_id} = [];
        }

        push @{$secondary_ips{$vlan_id}}, $ip_r->ip;
        next;
      }

      my $x = {
        ip   => $ip_r->ip,
        mask => $ip_r->mask,
        gw   => $ip_r->gw,
      };
      $ips{$vlan_id} = $x;

    }

    for my $vlan_id (keys %secondary_ips) {

      if (exists $ips{$vlan_id}) {
        $ips{$vlan_id}->{secondary_ip} = $secondary_ips{$vlan_id};
      }

    }

    my @iface_results;
    for my $iface_r ( @iface_rs ) {
      my $vlan_id = $iface_r->vlan_id;

      my $ip_param = exists $ips{$vlan_id}
                   ? $ips{$vlan_id}
                   : undef;

      my $x = {
        vlan_id => $iface_r->proxy_vlan_id // $vlan_id,
        mac     => $iface_r->mac,
        driver  => $iface_r->driver,
      };

      if ($x->{vlan_id} ne $vlan_id) {
        $x->{org_vlan_id} = $vlan_id;
      }

      $ENV{DEBUG} and
        $x->{sequence} = $iface_r->seq;

      $ip_param and $x->{ip} = $ip_param;

      push @iface_results, $x;
    }

    my @disk_results;
    for my $disk_r ( @disk_rs ) {
      my $image_path = $disk_r->image_path;
      my $image_name = basename $image_path;
      my $x = {
        image_path => $image_path,
        image_name => $image_name,
        driver     => $disk_r->driver,
        size       => $disk_r->size,
      };
      push @disk_results, $x;
    }

    $r->{disks} = [
                    sort {
                            $a->{image_name} cmp $b->{image_name}
                         }
                    @disk_results
                  ];

    $r->{interfaces} = \@iface_results;

  };

  if ($@) {
    warn $@ if $ENV{DEBUG};
    return undef;
  }

  return $r;

}

sub list { goto \&list_from_db; }

sub all_deleted {
  my ($self, $uuid, $cancel, $option) = @_;

  my $iface_define_rs = $self->schema->resultset('InterfaceDefine');
  my $disk_define_rs  = $self->schema->resultset('DiskDefine');
  my $vps_define_rs   = $self->schema->resultset('VpsDefine');
  my $ip_rs           = $self->schema->resultset('Ip');

  my $ok = 0;
  my $txn = $self->schema->txn_scope_guard;
  local $@;
  eval {

    if (! $cancel) {

      no strict 'refs';
      if (! $option->{force_remove}) {
        $disk_define_rs ->search({ vps_uuid => $uuid, try_remove => 1, })->delete; 
        $iface_define_rs->search({ vps_uuid => $uuid, try_remove => 1, })->delete;
        $vps_define_rs  ->search({     uuid => $uuid, try_remove => 1, })->delete;

      } else {

        # force_remove を指定して、強制削除 主にお掃除用
        $disk_define_rs ->search({ vps_uuid => $uuid })->delete; 
        $iface_define_rs->search({ vps_uuid => $uuid })->delete;
        $vps_define_rs  ->search({     uuid => $uuid })->delete;

      }

      # ipは消さずに解放
      $ip_rs->search({ used_vps_uuid => $uuid, try_release => 1, })
            ->update({ 
                       mac           => undef,
                       used_vps_uuid => undef,
                       reserve_uuid  => undef,
                       try_release   => undef,
                       secondary     => 0,
                     });

    } else {

      $disk_define_rs ->search({ vps_uuid => $uuid, try_remove => 1, })->update({ try_remove => undef, }); 
      $iface_define_rs->search({ vps_uuid => $uuid, try_remove => 1, })->update({ try_remove => undef, });
      $vps_define_rs  ->search({     uuid => $uuid, try_remove => 1, })->update({ try_remove => undef, });

      # ipは消さずに解放
      $ip_rs->search({ used_vps_uuid => $uuid, try_release => 1, })
            ->update({ try_release   => undef, secondary   => 0, });

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
  my ($self, $uuid, $option) = @_;
  $self->all_deleted( $uuid, 1, $option );

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

  if (is_debug) {
    warn "--- create_disk_param_array ---";
    warn Dumper $argv;
  }

  # ドライバは、ディスクを複数指定しても全ディスクで共通
  # いまは virtio の対応のみ
  my $driver = exists $argv->{driver}
             ? $argv->{driver}
             : "virtio";

  my $project_id = $argv->{project_id};
  my $uuid       = $argv->{uuid};
  my $disk_path  = $argv->{disk_path};

  if (! $project_id or ! $uuid) {
    croak "*** project_id or uuid has no value";
  }

  my @disks;

  my $number = exists $argv->{number}
             ? $argv->{number}
             : 1;

  $array_ref ||= [ "0" ];

  my $vm_root = $config->{vm_root};
  $vm_root    =~ s{^/+}{};

  my $storage_uuid = $argv->{storage_uuid};

  my $disk_dir_path;
  if (! $storage_uuid) {
    no strict 'refs';
    my $query = {};
    if (defined $argv->{storage_tag}) {
      $query->{storage_tag} = $argv->{storage_tag};
    }

    # 今回要求したディスクの合計値
    # つまり、1回の要求で複数のディスクを要求しても、それらは同じストレージに置かれる
    my $total_size = 0;
    $total_size += $_ for @$array_ref;

    $storage_uuid = Murakumo::CLI::Storage->new->select( $total_size, $query );

    $disk_dir_path = sprintf "%s/%s/%s", $vm_root, $storage_uuid, $project_id;

  } elsif (defined $disk_path) {
    $disk_dir_path = $disk_path;

  }

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
  my ($self, $project_id, $uuid, $vps_params, $options) = @_;

  if ($ENV{DEBUG}) {
    warn "--- ", __FILE__ , "#create_or_modify -----------";
    warn Dumper $vps_params;
    warn "-----------------------------------------------";
  }

  my $iface_define_rs = $self->schema->resultset('InterfaceDefine');
  my $disk_define_rs  = $self->schema->resultset('DiskDefine');
  my $vps_define_rs   = $self->schema->resultset('VpsDefine');
  my $ip_rs           = $self->schema->resultset('Ip');

  no strict 'refs';
  my $vps_spec = $vps_params->{spec};

  if ($options->{mode} eq 'create') {
    my ($is_named_vps) = $vps_define_rs->search({
                                                  project_id => $project_id, 
                                                  name       => $vps_spec->{name},
                                                });
    if ($is_named_vps) {
      croak "*** $vps_spec->{name}\@$project_id is already exist";
    }
  }

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

  my @iface_args_refs = exists $vps_params->{interface} 
                      ? @{$vps_params->{interface}}
                      : ();

  if (! $project_id) {
    croak "*** project_id param is required";
  }

  if (! exists $vps_spec->{uuid}) {
    $vps_spec->{uuid} = $uuid;
  }

  my @disk_args_refs;
  if (exists $vps_params->{disk} and @{$vps_params->{disk}} > 0) {
    my @current_disks = $disk_define_rs->search({ vps_uuid => $uuid });

    my $storage_uuid;
    my $storage_tag;
    my $driver;
    my $disk_path;
    {
      $storage_tag  = $vps_params->{storage_tag};
      $storage_uuid = $vps_params->{storage_uuid};
      $driver       = $options->{driver} || "virtio";
      $disk_path    = $vps_params->{disk_path};
    }
    my $current_disk_number = @current_disks + 1;
    @disk_args_refs = $self->create_disk_param_array( $vps_params->{disk},
                                                     {
                                                       project_id   => $project_id,
                                                       uuid         => $uuid,
                                                       number       => $current_disk_number,
                                                       storage_uuid => $storage_uuid,
                                                       storage_tag  => $storage_tag,
                                                       driver       => $driver,
                                                       disk_path    => $disk_path,
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
    my $now = Murakumo::CLI::Utils->now;

    my ($is_vps_exists) = $vps_define_rs->search({ uuid => $uuid, project_id => $project_id });

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
      my $now_iface_rs = $iface_define_rs->search({ vps_uuid => $uuid });
      my %now_vlan;
      while (my $row = $now_iface_rs->next) {
        $now_vlan{$row->vlan_id} = $row->mac;
      }
      $now_iface_rs->delete;

      # 新しくvpsに関連付けたinterfaceのレコードを追加
      my %already_vlan_id_cache;
      my $seq = 0;
      for my $iface_args_ref ( @iface_args_refs ) {

        exists $already_vlan_id_cache{$iface_args_ref->{vlan_id}}
          and croak "*** vlan_id duplicate error";

        $already_vlan_id_cache{$iface_args_ref->{vlan_id}} = 1;

        $iface_args_ref->{project_id}  = $project_id;
        $iface_args_ref->{vps_uuid}    = $uuid;
        $iface_args_ref->{regist_time} = $now;

        # interface は DBに入れることができれば、ready = 1;
        $iface_args_ref->{ready}       = 1;
        $iface_args_ref->{seq}         = ++$seq;

        if ( my $now_mac = delete $now_vlan{$iface_args_ref->{vlan_id}} ) {
          $iface_args_ref->{mac}   = $now_mac;
        } else {
          $iface_args_ref->{mac} ||= $utils->create_random_mac;
        }

        $iface_define_rs->create( $iface_args_ref );

      }
    }

    $vps_spec->{regist_time} = $now if not $is_vps_exists;

    $vps_spec->{project_id}  = $project_id;
    $vps_spec->{ready}       = $is_vps_exists
                             ? 1
                             : 0;

    $vps_define_rs->update_or_create( $vps_spec );

  };

  croak "vps defined error > ", $@ if $@;

  # トランザクション確定
  $txn->commit;


  return 1;
}


sub list_template {
  my ($self, $tag) = @_;

  my $resultset = $self->schema->resultset('VpsDefine');
  my $query     = +{ public_template => 1 };
  $tag and $query->{tag} = $tag;

  my $rs = $resultset->search( $query, { order_by => 'regist_time' } );
  my @vpses;
  while (my $x = $rs->next) {
    push @vpses, {
                   name               => $x->name,
                   uuid               => $x->uuid,
                   memory             => $x->memory,
                   cpu_number         => $x->cpu_number,
                   update_time        => $x->update_time,
                   regist_time        => $x->regist_time,
                   tag                => $x->tag || qq{},
                 };
  }
  return \@vpses;

}

sub info_list {
  my ($self, $project_id, $tag) = @_;

  if (! defined $project_id) {
    croak "project_id parameter must be specified...";
  }

  my $define_vps = $self->list( $project_id, $tag );
  my @uuids = map { $_->{uuid} } @$define_vps;

  my @infos;
  for my $uuid ( @uuids ) {
    my $info = $self->info( $uuid );
    push @infos, $info;

  }

  return \@infos;

}


# vps一覧 => list()
sub list_from_db {
  my ($self, $project_id, $tag) = @_;

  if (! defined $project_id) {
    croak "project_id parameter must be specified...";
  }

  my $resultset = $self->schema->resultset('VpsDefine');
  my $query = { project_id => $project_id, ready => 1, };
  $tag and $query->{tag} = uri_unescape $tag;

  my $rs = $resultset->search( $query, { order_by => 'regist_time' } );
  my @vpses;
  while (my $x = $rs->next) {
    push @vpses, {
                   name        => $x->name,
                   uuid        => $x->uuid,
                   memory      => $x->memory,
                   cpu_number  => $x->cpu_number,
                   update_time => $x->update_time,
                   regist_time => $x->regist_time,
                   tag         => $x->tag || qq{},
                 };
  }
  return \@vpses;
}


sub tag_list {
  my ($self, $project_id) = @_;
  my $vps_ref = $self->list( $project_id );

  no strict 'refs';
  my %tag = map { $_->{tag} => 1 }
            grep { $_->{tag} }
            @$vps_ref;

  [ keys %tag ];

}

sub record_cloning {
  my ( $self, $src_uuid, $args_ref, $opt_args_ref ) = @_;

  logging "debug", "call record_cloning";

  my $vps_define_rs   = $self->schema->resultset('VpsDefine');
  my $disk_define_rs  = $self->schema->resultset('DiskDefine');
  my $iface_define_rs = $self->schema->resultset('InterfaceDefine');

  if (is_debug) {
    warn "record_cloning...";
    warn Dumper $src_uuid;
    warn Dumper $args_ref;
  }

  my $project_id;
  my $param_ref;

  my $org_info = $self->info( $src_uuid );

  my $now = $utils->now;
  my $txn = $self->schema->txn_scope_guard;

  my ($uuid, $storage_uuid, $tag);
  {
    no strict 'refs';
    $uuid         = $args_ref->{uuid};
    $tag          = $opt_args_ref->{tag} // $org_info->{tag};
    $storage_uuid = $opt_args_ref->{storage_uuid};

    # storage_uuid が指定されていれば
    # storage_uuid が登録されているかチェック
    # なければ例外
    if ($storage_uuid) {
      Murakumo::CLI::Storage->new->info( $storage_uuid );
    }

    $project_id = $args_ref->{project_id} // $org_info->{project_id};

    my %param = (
      memory          => $org_info->{memory},
      cpu_number      => $org_info->{cpu_number},
      uuid            => $uuid,
      tag             => $tag,
      name            => $uuid,
      project_id      => $project_id,
      clock           => $org_info->{clock},
      public_template => 0,
      ready           => 0,
      regist_time     => $now,
    );

    %param = (%param, %$args_ref);
    if (is_debug) {
      warn "record cloning vps";
      warn Dumper \%param;
    }

    # 元となるvpsのname
    $param{'original'} = $src_uuid;

    local $@;
    eval {
      $vps_define_rs->create( \%param );

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
                                                         number       => $number,
                                                         project_id   => $project_id,
                                                         uuid         => $uuid,
                                                         storage_uuid => $storage_uuid,
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
          $disk_define_rs->create( \%param );

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
  my %already_vlan_id_cache;
  if (exists $opt_args_ref->{vlan_id} and $opt_args_ref->{vlan_id}) {
    for my $id ( split /,/, $opt_args_ref->{vlan_id} ) {

      exists $already_vlan_id_cache{$id}
        and croak "*** vlan_id duplicate error";

      push @specify_vlan_ids, $id;
      $already_vlan_id_cache{$id} = 1;

    }
  }

  my $mac_of_first;
  {

    my $number = 0;

    my @ifaces = @{$org_info->{interfaces}};
    my $n = 0;
    if (@specify_vlan_ids > 0) {
      for my $specify_vlan_id ( $specify_vlan_ids[0] ) { # とりあえず、最初の1つだけ作成する

        my $mac = $utils->create_random_mac;
        $mac_of_first ||= $mac;

        my %param = (
          project_id  => $project_id,
          vlan_id     => $specify_vlan_id,
          driver      => exists $ifaces[$n]->{driver}
                         ? $ifaces[$n]->{driver}
                         : "virtio",
          ip          => undef,
          vps_uuid    => $uuid,
          mac         => $mac,
          regist_time => $now,
          seq         => ++$number,
        );

        $n++;

        local $@;
        eval {
          $iface_define_rs->create( \%param );
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
  my ($self, $uuid) = @_;

  my $vps_define_rs   = $self->schema->resultset('VpsDefine');
  my $disk_define_rs  = $self->schema->resultset('DiskDefine');
  my $iface_define_rs = $self->schema->resultset('InterfaceDefine');

  my $txn = $self->schema->txn_scope_guard;
  local $@;
  eval {
    $vps_define_rs  ->search({ uuid     => $uuid })->update({ ready => 1 });
    $disk_define_rs ->search({ vps_uuid => $uuid })->update({ ready => 1 });
    $iface_define_rs->search({ vps_uuid => $uuid })->update({ ready => 1 });
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
  my ($self, $uuid) = @_;

  my $vps_define_rs   = $self->schema->resultset('VpsDefine');
  my $disk_define_rs  = $self->schema->resultset('DiskDefine');
  my $iface_define_rs = $self->schema->resultset('InterfaceDefine');

  my $txn = $self->schema->txn_scope_guard;
  local $@;
  eval {
    $vps_define_rs  ->search({ uuid     => $uuid, ready => 0 })->delete;
    $disk_define_rs ->search({ vps_uuid => $uuid, ready => 0 })->delete;
    $iface_define_rs->search({ vps_uuid => $uuid, ready => 0 })->delete;
  };
  $@ or $txn->commit;

}

sub is_valid_vps_for_project {
  my ($self, $project_id, $uuid) = @_;

  if (! $project_id or ! $uuid) {
    croak "project_id or uuid is empty";
  }
  my $vps_define_rs = $self->schema->resultset('VpsDefine');
  my $count = $vps_define_rs->search({
                                     project_id => $project_id,
                                     uuid       => $uuid,
                                    })->count;

  if ( $count != 1 ){
    croak "*** vps $uuid is invalid for project $project_id";
  }

  return 1;
}

sub is_template_uuid {
  my ($self, $uuid) = @_;

  if (! $uuid) {
    croak "*** uuid is empty";

  }

  my $vps_define_rs = $self->schema->resultset('VpsDefine');
  my $count = $vps_define_rs->search({
                                       uuid            => $uuid,
                                       public_template => 1,
                                    })->count;

  if ( $count != 1 ){
    croak "*** $uuid is invalid for template";
  }

  return 1;

}

sub set_proxy_vlan_id {
  my ($self, $uuid, $params) = @_;

  my $iface_define_rs = $self->schema->resultset('InterfaceDefine');

  no strict 'refs';
  $iface_define_rs->search({
                             vps_uuid => $uuid,
                             vlan_id  => $params->{vlan_id},
                           })
                  ->update({
                             proxy_vlan_id => $params->{proxy_vlan_id} || undef,
                           });

}

1;
