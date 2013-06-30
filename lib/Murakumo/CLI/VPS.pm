use strict;
use warnings;
use 5.014;

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

  my $txn = $self->schema->txn_scope_guard;
  my $resultset = $self->schema->resultset('Vps');

  my $update_ok = 0;
  my @vpses     = @$vpses_ref;
  no strict 'refs';
  for my $vps (@vpses) {
    $vps->{state} == 1 or next;
    $vps->{update_key} = $update_key;

    local $@;
    eval {
      $vps->{node} = $node;
      $resultset->update_or_create( $vps );
    };
    if ($@) {
      warn $@;
    } else {
      $update_ok++;
    }
  }

  my $no_current_rs = $resultset->search({
                                           node       => $node,
                                           update_key => { '!=' => $update_key },
                                           state      => { '!=' => 0 },
                                         });
  if ($no_current_rs->count > 0) {
    $no_current_rs->delete;
  }

  if ($update_ok == @vpses) {
    return $txn->commit;

  } else {
    croak "*** vps register error";

  }

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
  my $resultset  = $self->schema->resultset('Vps');

  my $query_hash_ref = +{ state => { "!=" => "0" } };

  $until and
    $query_hash_ref->{'me.update_time'} = { '>' => $until };

  my $rs = $resultset->search(
                               {
                                'vps_define_rel.project_id' => $project_id,
                               }
                             )
                     ->search(
                               $query_hash_ref,
                               {
                                 prefetch => [ 'vps_define_rel', ],
                               }
                             );

  my @vpses;

  no strict 'refs';
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
    croak "uuid is not found parameter";

  }
  my $vps_rs = $self->schema->resultset('Vps');
  local $@;
  eval {
    $vps_rs->create({ uuid => $uuid, state => 0, });
  };
  if ($@) {
    logging 'info', $@;
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
