use strict;
use warnings;
package Murakumo::CLI::VPS 0.02;

use JSON;
use Carp;
use Data::Dumper;
use FindBin;
use lib qq{$FindBin::Bin/../lib};
use Murakumo::CLI::Utils;
use Murakumo::CLI::DB;
use base q(Murakumo::CLI::DB);

sub vps_register {
  my ($self, $node, $update_key, $vpses_ref) = @_;
  my $resultset = $self->schema->resultset('Vps');

  my $update_ok = 0;
  my @vpses     = @$vpses_ref;
  for my $vps (@vpses) {
    $vps->{update_key} = $update_key;
    local $@;
    eval {
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
sub register {
  goto &vps_register;
}

# vps一覧
sub list {
  my $self       = shift;
  my $project_id = shift;
  my $until      = shift;
  my $resultset        = $self->schema->resultset('Vps');
  my $define_resultset = $self->schema->resultset('VpsDefine');

  my %project_uuids = map { $_->uuid => 1 }
                          $define_resultset
                          ->search( { project_id => $project_id } );

  my $query_hash_ref = +{};
  $until and
    $query_hash_ref->{update_time} = { '>' => $until };
  my $rs = $resultset->search($query_hash_ref);
  my @vpses;

  no strict 'refs';
  while (my $x = $rs->next) {
    my $uuid  = $x->uuid;
    my $state = $x->state;

    $project_uuids{$uuid} or  next;
    # とりあえず state 0 (bootup temporary) は除外
    # 本当は、query レベルで除外する
    $state eq '0'         and next;

    push @vpses, {
                   name        => $x->name,
                   uuid        => $uuid,
                   node        => $x->node,
                   memory      => $x->memory,
                   cpu         => $x->cpu,
                   state       => $state,
                   update_time => $x->update_time,
                   vnc_port    => $x->vnc_port,
                   enable      => $x->enable,
                 };
  }

  return \@vpses;

}

sub get_node {
  my $self = shift;
  my $uuid = shift;
  my $uri_base = qq{};
  my $resultset = $self->schema->resultset('Vps');
  local $@;
  {
    my ($rs) = $resultset->search({ uuid => $uuid });
    $rs or croak "$uuid is not found";

    my $node_obj = $rs;

    if ( $node_obj->isa('Murakumo::CLI::DB') ) {
      croak "*** no node has $uuid... vm is destroyed...??";
    }

    $uri_base = $node_obj->node;
  }

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
    $vps_rs->create({ uuid => $uuid, state => 0, });
  };
  if ($@) {
    return 0;
  } else {
    return 1;
  }
  
}

# 起動が失敗したら
sub unset_tmp_active_vps {
  my ($self, $uuid) = @_;
  if (! $uuid) {
    croak "uuid is not found parameter";
  }

  my $vps_rs = $self->schema->resultset('Vps');

  my $delete_count = $vps_rs->search({ uuid => $uuid, state => 0, })
                             ->delete;

  # 削除する対象がなかったら
  if ($delete_count == 0) {
    return 0;

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
    my ($vps) = $vps_rs->search({ uuid => $uuid });
    $uuid_from_vps = $vps->uuid;
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
