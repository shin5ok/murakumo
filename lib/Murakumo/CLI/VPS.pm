use strict;
use warnings;
package Murakumo::CLI::VPS;

use JSON;
use Carp;
use Data::Dumper;
use FindBin;
use lib qq{$FindBin::Bin/../lib};
use Murakumo::CLI::Utils;
use Murakumo::CLI::DB;
use base q(Murakumo::CLI::DB);

our $VERSION = q(0.0.1);

our $root_itemname = q{root};

sub vps_register_json {
  my ($self, $json_data) = @_;
  my $json;
  eval {
    my $decoded_json = decode_json $json_data;
    $json = $decoded_json->{$root_itemname};
  };
  return $self->vps_register( $json->{node}->{name}, $json->{update_key}, $json->{vpses} );
}

sub vps_register {
  my ($self, $node, $update_key, $vpses_ref) = @_;
  # my ($self, $node, $update_key, $vpses_ref) = @_;
  # node 及び updateキーを指定して、vpsのarray referenceを渡す
  my $resultset = $self->schema->resultset('Vps');

  my $update_ok = 0;
  my @vpses     = @$vpses_ref;
  for my $vps (@vpses) {
    $vps->{update_key} = $update_key;
    local $@;
    eval {
      # エラー処理はどうするか・・・そもそも↓は例外を出すのか
      # $resultset->update_or_create($vps);
      no strict 'refs';
      $vps->{node} = $node;
      $resultset->update_or_create($vps, { uuid => $vps->{uuid} });
    };
    if ($@) {
      warn $@;
    } else {
      $update_ok++;
    }
  }
  $resultset->search_literal(q{node = ? and update_key != ? and state != 0}, $node, $update_key)->delete;
  return $update_ok == @vpses;
}

# エイリアス
sub register_json {
  goto &vps_register_json;
}

# エイリアス
sub register {
  goto &vps_register;
}

# vps の現在の状態
sub get_status {

}

# vps一覧
sub list {
  my $self  = shift;
  my $until = shift;
  my $resultset = $self->schema->resultset('Vps');
  # きちんとエラー処理をすること
  my $query_hash_ref = { state => 1 };
  $until and
    $query_hash_ref->{update_time} = { '>' => $until };
  my $rs = $resultset->search($query_hash_ref);
  my @vpses;
  while (my $x = $rs->next) {
    push @vpses, {
                   name        => $x->name,
                   uuid        => $x->uuid,
                   node        => $x->node,
                   memory      => $x->memory,
                   cpu         => $x->cpu,
                   state       => $x->state,
                   update_time => $x->update_time,
                   vnc_port    => $x->vnc_port,
                   enable      => $x->enable,
                 };
  }
  warn Dumper \@vpses;

  return \@vpses;

}

sub get_node {
  my $self = shift;
  my $uuid = shift;
  my $uri_base = qq{};
  my $resultset = $self->schema->resultset('Vps');
  local $@;
  {
    warn $uuid , " is search";
    my ($rs) = $resultset->search({ uuid => $uuid });
    $rs or croak "$uuid is not found";

    my $node_obj = $rs;

    if ( $node_obj->isa('Murakumo::CLI::DB') ) {
      croak "*** no node has $uuid... vm is destroyed...??";
    }

    $uri_base = $node_obj->node;
  }
  warn $@ if $@;

  return $uri_base;
}


# 二重起動を防ぐため、起動前に実施します
sub set_tmp_active_vps {
  my ($self, $uuid) = @_;
  if (! $uuid) {
    warn "uuid is not found parameter";
    return 0;
  }
  my $vps_rs = $self->schema->resultset('Vps');
  local $@;
  eval {
    my $vps = $vps_rs->create({ uuid => $uuid, state => 0, });
    $vps->uuid;
  };
  if ($@) {
    # 例外が出たらテンポラリの設定ができない
    # つまり、起動しているか？
    # warn $@;
    return 0;
  } else {
    return 1;
  }
  
}

# 起動前が失敗したら
sub unset_tmp_active_vps {
  my ($self, $uuid) = @_;
  if (! $uuid) {
    warn "uuid is not found parameter";
    return 0;
  }
  my $vps_rs = $self->schema->resultset('Vps');
  local $@;
  eval {
    $vps_rs->search({ uuid => $uuid, state => 0, })->delete;
    # $vps->uuid;
  };
  if ($@) {
    # 例外が出たら削除ができない
    croak "unset error : $@";
  } else {
    return 1;
  }
  
}

# vpsがactiveか
sub is_active_vps {
  my ($self, $uuid) = @_;
  my $vps_rs = $self->schema->resultset('Vps');
  local $@;
  my $uuid_from_vps = "";
  eval {
    my $vps = $vps_rs->search({ uuid => $uuid });
    $uuid_from_vps = $vps->next->uuid;
  };
  if (! $uuid_from_vps or $@) {
    # 例外が出たら起動していない
    return 0;
  } else {
    return 1;
  }
}

1;
__END__
