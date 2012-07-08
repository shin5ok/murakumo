use strict;
use warnings;
package Murakumo::CLI::Node::Select;
use Data::Dumper;
use Carp;
use List::Util qw(shuffle);

use FindBin;
use lib qq{$FindBin::Bin/../lib};
use Murakumo::CLI::Utils;
use Murakumo::CLI::DB;
use base qw( Murakumo::CLI::DB );

our $VERSION          = q(0.0.8);

our $default_api_port = 3000;

my $config = Murakumo::CLI::Utils->config;

sub select {
  my ($self, %require_params) = @_;

  warn "--- select require_params ---";
  warn Dumper \%require_params;
  warn "-------------------";

  my $require_cpu_number;
  my $require_memory    ;
  {
    no strict 'refs';

    # ノードのOSに必要なcpu
    my $require_cpu_for_node    = $config->{require_cpu_for_node};
    # ノードのOSに必要なメモリ
    my $require_memory_for_node = $config->{require_memory_for_node};

    $require_cpu_number = $require_params{cpu_number};
    $require_memory     = $require_params{memory};

    defined $require_cpu_for_node
      and $require_cpu_number += $require_cpu_number;

    defined $require_memory_for_node
      and $require_memory     += $require_memory_for_node;
  }

  my $selected_node;
  my $rs;
  local $@;
  my $resultset = $self->schema->resultset('Node');

  my $until = DateTime->now(time_zone => 'Asia/Tokyo');
     $until->subtract( seconds => $config->{vps_list_expire_second} );

  my $query = {
                 disable     => { '!=' => 1      },
                 update_time => { '>'  => $until }, # 期限切れは対象外
              };
  $require_cpu_number
    and $query->{cpu_available} = { '>' => $require_cpu_number };
  $require_memory
    and $query->{mem_free}      = { '>' => $require_memory     };

  my @rses = $resultset->search($query);

  # my @rses = $rs->search;
  # コア数 を vpsで使っているcpu数を超えていないノードのみ対象
  # 使っているコア数が少ない順に並び替え
  @rses = sort { $a->cpu_vps_used <=> $b->cpu_vps_used }
          grep { $_->cpu_vps_used <= $_->cpu_total }
          @rses;

  if (@rses == 0) {
    croak "*** available node is not found";
  }

  # シャッフル
  @rses = shuffle @rses;
  # 仮に1台めのノードのオブジェクトをセット
  $selected_node = shift @rses;

  for my $r (@rses) {
#warn sprintf "selected: %s(loadavg %s), current: %s(loadavg %s)", $selected_node->name, $selected_node->loadavg, $r->name, $r->loadavg;

    # ロードアベレージが少ないノードを選択
    if ($selected_node->loadavg > $r->loadavg) {
      $selected_node = $r;
    }
    # メモリ空容量が多いノードを選択
    # if ($selected_node->mem_free < $r->mem_free) {
    #   $selected_node = $r;
    # }
  }

  my $config = Murakumo::CLI::Utils->new->config;
  my $port   = exists $config->{api_port}
             ? $config->{api_port}
             : $default_api_port;

  return sprintf "%s:%d", $selected_node->name, $port;

}

1;
__END__
mysql> select * from selected_node;
+-------------------------+------+-----------+-----------+----------+------------+--------------+---------------------+---------+
| name                    | uuid | cpu_total | mem_total | mem_free | vps_number | cpu_vps_used | regist_time         | disable |
+-------------------------+------+-----------+-----------+----------+------------+--------------+---------------------+---------+
| relay301.hosting-pf.net | NULL |         4 |   8175972 |  7507364 |          0 |            0 | 2012-02-14 05:36:07 |    NULL |
| relay302.hosting-pf.net | NULL |         4 |   8043876 |  7311604 |          1 |            2 | 2012-02-14 05:36:07 |    NULL |
+-------------------------+------+-----------+-----------+----------+------------+--------------+---------------------+---------+

