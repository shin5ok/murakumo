use strict;
use warnings;
use 5.014;

package Murakumo::CLI::Node::Select 0.08;
use Data::Dumper;
use Carp;
use List::Util qw(shuffle);

use FindBin;
use lib qq{$FindBin::Bin/../lib};
use Murakumo::CLI::Utils;
use Murakumo::CLI::DB;
use base qw( Murakumo::CLI::DB );

my $config = Murakumo::CLI::Utils->config;

our $default_api_port = $config->{api_port} // 3000;

sub select {
  my ($self, %require_params) = @_;

  if (is_debug) {
    warn "--- select require_params ---";
    warn Dumper \%require_params;
    warn "-----------------------------";
  }

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
  my %auto_select_node = map { $_ => 1 } $self->get_auto_select_nodes;

  my $until = Murakumo::CLI::Utils->now;
     $until->subtract( seconds => $config->{node_list_expire_second} );

  my $query = {
                 disable     => { '!=' => 1      },
                 update_time => { '>'  => $until }, # 期限切れは対象外
              };

  # 後でplan を指定するようにする
  # $plan and 
  #   $query->{plan} = $plan;

  $require_cpu_number
    and $query->{cpu_available} = { '>' => $require_cpu_number };
  $require_memory
    and $query->{mem_free}      = { '>' => $require_memory     };

  my @rses = $resultset->search($query);

  # コア数 を vpsで使っているcpu数を超えていないノードのみ対象
  # 使っているコア数が少ない順に並び替え
  @rses = sort { $a->cpu_vps_used <=> $b->cpu_vps_used }
          grep { $_->cpu_vps_used <=  $_->cpu_total    }
          grep { exists $auto_select_node{$_->uuid}    }
          @rses;

  if (@rses == 0) {
    croak "*** available node is not found";
  }

  # シャッフル
  @rses = shuffle @rses;
  # 仮に1台めのノードのオブジェクトをセット
  $selected_node = shift @rses;

  for my $r (@rses) {

    # ロードアベレージが少ないノードを選択
    if ($selected_node->loadavg > $r->loadavg) {
      $selected_node = $r;
    }
  }

  my $config = Murakumo::CLI::Utils->new->config;
  my $port   = exists $config->{api_port}
             ? $config->{api_port}
             : $default_api_port;

  return $selected_node->name;
  # return sprintf "%s:%d", $selected_node->name, $port;

}

sub get_auto_select_nodes {
  my $self = shift;
  my $define_resultset = $self->schema->resultset('NodeDefine');
  map { $_->uuid => 1 }
      $define_resultset->search({ auto_select => 1 });
}


1;
