use warnings;
use strict;

package Murakumo::CLI::IP 0.01;
use Carp;
use Data::Dumper;
use FindBin;
use lib qq{$FindBin::Bin/../lib};
use base q(Murakumo::CLI::DB);
use Murakumo::CLI::Utils;

# フリーのipを割り当てのため予約
sub reserve_ip {
  my ($self, $param_ref) = @_;

  if (is_debug) {
    warn Dumper $param_ref;
  }

  no strict 'refs';
  my $resultset = $self->schema->resultset('Ip');

  # vlan と、ipが管理されているか
  my $is_manage_vlan = $resultset->search( { vlan_id => $param_ref->{vlan_id} } )->count;
  if ( $is_manage_vlan == 0 ) {
    return undef;
  }

  # すでにこのvlanのipが割り当てられていれば
  if (defined $param_ref->{used_vps_uuid}) {
    my @ips = $resultset->search({
                                   vlan_id       => $param_ref->{vlan_id},
                                   used_vps_uuid => $param_ref->{used_vps_uuid},
                                 });
    if ( @ips > 0 ) {
      return [ map { +{ $_->get_columns } } @ips ] if @ips > 2;
      return ( $ips[0]->ip, $ips[0]->mask, $ips[0]->gw );
    }
  }

  if (! exists $param_ref->{reserve_uuid}) {
    croak "*** reserve_uuid is empty";
  }

  my $reserve_uuid = $param_ref->{reserve_uuid};

  # トランザクション 開始
  my $txn = $self->schema->txn_scope_guard;
  local $@;
  eval {

    my $r = $self->get_free_ip_object({
                                        vlan_id       => $param_ref->{vlan_id},
                                        ip            => $param_ref->{ip},
                                        used_vps_uuid => $param_ref->{used_vps_uuid},
                                      });

    $r or croak "*** query execute error";

    $r->update( { reserve_uuid => $reserve_uuid } );

  };

  if ($@) {
    croak "get_assign_ip is failure(eval error: $@)";

  }

  # トランザクション 完了
  $txn->commit;

  my ($x) = $resultset->search({ reserve_uuid => $reserve_uuid });

  return ($x->ip, $x->mask, $x->gw);

}

# 指定したvlanで、空いているip の ResultSet オブジェクトを返す
sub get_free_ip_object {
  my ($self, $params) = @_;
  no strict 'refs';
  my $vlan_id       = $params->{vlan_id};
  my $ip            = $params->{ip};

  defined $vlan_id
    or croak "*** vlan id is not found";

  my $resultset = $self->schema->resultset('Ip');
  my $rs;
  local $@;
  eval {
    my $query = { vlan_id => $vlan_id };
    $ip and $query->{ip} = $ip;

    $rs   = $resultset->search($query);
    ($rs) = $rs->search({ used_vps_uuid => { is => undef         ,}})
               ->search({ reserve_uuid  => { is => undef         ,}})
               ->search(
                          undef,
                          {
                            order_by => { -asc => 'id' },
                            rows     => 1,
                          },
                        );

  };
  if ($@) {
    croak "get free ip object is failure($@)";
  }

  if (! $rs) {
    croak "*** error";

  }
  return $rs;

}

# 予約した ip を vpsに割り当てて、確定します
sub commit_assign_ip {
  my ($self, $param_ref) = @_;
  no strict 'refs';

  my ($reserve_uuid, $vps_uuid)
    = ($param_ref->{reserve_uuid}, $param_ref->{vps_uuid});

  if (! $reserve_uuid or ! $vps_uuid) {
     croak "reserve_uuid: $reserve_uuid | vps_uuid:$vps_uuid is not found";
  }

  my $update_param_ref = {
                           used_vps_uuid => $vps_uuid,
                           reserve_uuid  => undef,
                           secondary     => $param_ref->{secondary} ? 1 : 0,
                         };

  my $resultset = $self->schema->resultset('Ip');
  my $updated;
  local $@;
  eval {
    my $rs = $resultset->search( { reserve_uuid => $reserve_uuid } );
    $updated = $rs->update( $update_param_ref );
  };

  if ($@) {
    my $dump = Dumper $param_ref;
    croak "update failure...$@($dump)";
  }

  return 1;

}

# 予約したip をジョブ失敗等のために キャンセルします
sub cancel_reserve_ip {
  my ($self, $param_ref) = @_;

  no strict 'refs';
  my $reserve_uuid = $param_ref->{reserve_uuid};

  if (! $reserve_uuid) {
     croak "reserve_uuid not found";
  }

  my $resultset = $self->schema->resultset('Ip');
  my $txn = $self->schema->txn_scope_guard;

  local $@;
  eval {
    $resultset->search( { reserve_uuid => $reserve_uuid, } )
              ->update( { reserve_uuid => undef,         } );
  };

  if ($@) {
    my $dump = Dumper $param_ref;
    croak "update failure...$@($dump)";
  }

  $txn->commit;
}

sub release_ip {
  my ($self, $vlan_id, $used_vps_uuid) = @_;

  my $resultset = $self->schema->resultset('Ip');
  my $txn = $self->schema->txn_scope_guard;

  local $@;
  eval {
    $resultset->search( {
                          vlan_id       => $vlan_id,
                          used_vps_uuid => $used_vps_uuid,
                        } )
              ->update( {
                          used_vps_uuid => undef,
                          reserve_uuid  => undef,
                          try_release   => undef,
                          mac           => undef,
                         } );
  };

  if ($@) {
    croak "*** release ip error vlan:${vlan_id}, used_vps_uuid:${used_vps_uuid}";
  }

  $txn->commit;
}


sub list_count {
  my ($self) = @_;

  my $list_ref = $self->list;

  no strict 'refs';
  my %count;
  for my $vlan_id ( keys %$list_ref ) {

    for my $v ( @{$list_ref->{$vlan_id}} ) {

      $count{$vlan_id}->{total}++;

      exists $count{$vlan_id}->{used}
        or $count{$vlan_id}->{used} = 0;

      exists $count{$vlan_id}->{free}
        or $count{$vlan_id}->{free} = 0;

      exists $count{$vlan_id}->{network}
        or $count{$vlan_id}->{network} = $v->{network};

      exists $count{$vlan_id}->{netmask}
        or $count{$vlan_id}->{netmask} = $v->{netmask};

      if ($v->{used}) {
        $count{$vlan_id}->{used}++;

      } else {
        $count{$vlan_id}->{free}++;

      }
    }
  }

  return \%count;

}


sub list {
  my ($self, $query) = @_;
  # { network => $network }
  # または
  # { vlan_id => $vlan_id }

  my $resultset = $self->schema->resultset('Ip');
  my @ips       = $resultset->search( $query );

  my %hash;
  for my $ip ( @ips ) {
    my $vlan_id = $ip->vlan_id;
    
    if (! exists $hash{$vlan_id}) {
      $hash{$vlan_id} = [];
    }

    my $used = $ip->used_vps_uuid or $ip->reserve_uuid
             ? 1
             : 0;

    push @{$hash{$vlan_id}}, {
                               network => $ip->network,
                               ip      => $ip->ip,
                               netmask => $ip->mask,
                               gw      => $ip->gw,
                               used    => $used,
                             };

  }

  return \%hash;

}

1;
