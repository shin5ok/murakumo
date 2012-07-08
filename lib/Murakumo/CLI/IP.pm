use warnings;
use strict;
package Murakumo::CLI::IP;
use Carp;
use Data::Dumper;
use FindBin;
use lib qq{$FindBin::Bin/../lib};
use base q(Murakumo::CLI::DB);
our $VERSION = q(0.0.1);

# フリーのipを割り当てのため予約
sub reserve_ip {
  my ($self, $param_ref) = @_;
  # $param_ref = {
  #   reserve_uuid  => String,
  #   vlan_id       => Int,
  #   ip            => String,
  #   used_vps_uuid => String,
  # };
  warn "--- ", __PACKAGE__, " ---";
  warn Dumper $param_ref;

  my $resultset = $self->schema->resultset('Ip');

  # vlan と、ipが管理されているか
  my $is_manage_vlan = $resultset->search( { vlan_id => $param_ref->{vlan_id} } )->count;
  if ( $is_manage_vlan == 0 ) {
    return undef;
  }

  # すでにこのvlanのipが割り当てられていれば
  if (defined $param_ref->{used_vps_uuid}) {
    my ($x) = $resultset->search({
                                   vlan_id       => $param_ref->{vlan_id},
                                   used_vps_uuid => $param_ref->{used_vps_uuid},
                                 });
    if (defined $x and $x->can("ip")) {
    warn $x->ip;
      return ($x->ip, $x->mask, $x->gw);
    }
  } 

  no strict 'refs';
  if (! exists $param_ref->{reserve_uuid}) {
    croak "*** reserve_uuid is empty";
  }
  my $reserve_uuid = $param_ref->{reserve_uuid};

  # トランザクション 開始
  my $txn = $self->schema->txn_scope_guard;
  local $@;
  eval {
    my @request_params = ( $param_ref->{vlan_id} );
    exists $param_ref->{ip}
      and push @request_params, $param_ref->{ip};

    my $r = $self->get_free_ip_object({
                                        vlan_id       => $param_ref->{vlan_id},
                                        ip            => $param_ref->{ip},
                                        used_vps_uuid => $param_ref->{used_vps_uuid},
                                      });

    $r or croak "*** query execute error";

    $r->update( { reserve_uuid => $reserve_uuid });

  };

  if ($@) {
    warn "get_assign_ip is failure(eval error: $@)";
    return undef;
  }

  # トランザクション 完了
  $txn->commit;

  my ($x) = $resultset->search({ reserve_uuid => $reserve_uuid });
  # my $x = $rses[0];

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

  # warn $r->next->ip if exists $ENV{DEBUG};
  return $rs;
}

# 予約した ip を vpsに割り当てて、確定します
sub commit_assign_ip {
  my ($self, $param_ref) = @_;
  no strict 'refs';
  warn "----- commit_assign_ip -----";
  warn Dumper $param_ref;
  warn "----------------------------";
  my ($reserve_uuid, $vps_uuid)
    = ($param_ref->{reserve_uuid}, $param_ref->{vps_uuid});

  if (! $reserve_uuid or ! $vps_uuid) {
     warn "reserve_uuid: $reserve_uuid | vps_uuid:$vps_uuid is not found";
     return 0;
  }

  my $update_param_ref = {
                           used_vps_uuid => $vps_uuid,
                           reserve_uuid  => undef,
                         };

  my $resultset = $self->schema->resultset('Ip');
  my $updated;
  local $@;
  eval {
    local $ENV{DBIC_TRACE} = 1;
    warn Dumper $update_param_ref;
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

  warn "cancel_reserve_ip: ", Dumper $param_ref;

  if (! $reserve_uuid) {
     croak "reserve_uuid not found";
  }

  my $resultset = $self->schema->resultset('Ip');
  local $@;
  eval {
    $resultset->search( { reserve_uuid => $reserve_uuid, } )
              ->update( { reserve_uuid => undef,         } );
  };

  if ($@) {
    my $dump = Dumper $param_ref;
    croak "update failure...$@($dump)";
  }

  return 1;
}

sub release_ip {
  my ($self, $vlan_id, $used_vps_uuid) = @_;

  my $resultset = $self->schema->resultset('Ip');
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

  return 1;


}

1;
__END__
+---------------+--------------+------+-----+-------------------+-----------------------------+
| Field         | Type         | Null | Key | Default           | Extra                       |
+---------------+--------------+------+-----+-------------------+-----------------------------+
| id            | mediumint(9) | NO   | PRI | NULL              | auto_increment              |
| network       | varchar(32)  | YES  |     | NULL              |                             |
| ip            | varchar(16)  | NO   |     |                   |                             |
| used_vps_uuid | varchar(48)  | YES  |     | NULL              |                             |
| start_time    | time         | YES  |     | NULL              |                             |
| end_time      | time         | YES  |     | NULL              |                             |
| enable        | tinyint(1)   | YES  |     | NULL              |                             |
| update_time   | timestamp    | NO   |     | CURRENT_TIMESTAMP | on update CURRENT_TIMESTAMP |
+---------------+--------------+------+-----+-------------------+-----------------------------+


