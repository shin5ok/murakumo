use strict;
use warnings;
use 5.014;

package Murakumo::CLI::Admin 0.01 {

  use Carp;
  use Net::CIDR;
  use Data::Dumper;
  use FindBin;
  use URI::Escape;
  use lib qq{$FindBin::Bin/../lib};
  use Murakumo::CLI::Utils;
  use Murakumo::CLI::DB;
  use base q(Murakumo::CLI::DB);

  sub is_admin_access {
    my ($self, $admin_api_key, $params) = @_;

    my $resultset = $self->schema->resultset('Admin');
    my @rs = $resultset->search;

    my $src_ip = $params->{src_ip};
    if ( ! defined $src_ip ) {
      croak "*** source ip address is empty";
    }

    logging 'debug', "try admin api from $src_ip";

    my $is_ok = 0;
    _RS_: for my $r ( @rs ) {
      if (my $networks = $r->allow_network) {
         if (Net::CIDR::cidrlookup( $src_ip, ( split /,/, $networks ) )) {
           if ($r->api_key eq $admin_api_key) {
             $is_ok = 1;
             last _RS_;
           }
         }
      }
    }

    logging 'debug', "admin auth $is_ok";
    return $is_ok;

  }

  sub vps_define_list {
    my ($self, $query) = @_;

    my $resultset = $self->schema->resultset('VpsDefine');

    $query->{ready} = 1;

    my $rs = $resultset->search( $query, { order_by => 'regist_time' } );
    my @vpses;
    while (my $x = $rs->next) {
      push @vpses, {
                     project_id  => $x->project_id,
                     name        => $x->name,
                     uuid        => $x->uuid,
                     memory      => $x->memory,
                     cpu_number  => $x->cpu_number,
                     update_time => $x->update_time,
                     regist_time => $x->regist_time,
                     tag         => $x->tag || qq{},
                   };
    }
    return [ sort { $a->{project_id} cmp $b->{project_id} } @vpses ];

  }

  sub vps_list {
    my ($self, $query_hash_ref, $until) = @_;

    my $resultset = $self->schema->resultset('Vps');

    $query_hash_ref //= +{};

    $query_hash_ref->{state} = +{ "!=" => "0" };

    $until and
      $query_hash_ref->{'me.update_time'} = { '>' => $until };

    my $rs = $resultset->search(
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
                     project_id  => $x->vps_define_rel->project_id,
                   };
    }

    return [ sort { $a->{project_id} cmp $b->{project_id} } @vpses ];

  }

  sub project_list {
    my ($self) = @_;

    my $resultset = $self->schema->resultset('Project');
    my $rs = $resultset->search;

    my @projects;
    while (my $x = $rs->next) {
      push @projects, {
                        project_id  => $x->project_id,
                        api_key     => $x->api_key,
                        regist_time => $x->regist_time,
                      };
    }

    return \@projects;
  }

  sub project_register {
    my ($self, $project_id) = @_;

    my $resultset = $self->schema->resultset('Project');

    my $key = Murakumo::CLI::Utils::create_uuid();
       $key =~ s/\-//g;

    if ( lc $project_id eq 'admin' ) {
      croak "*** project_id 'admin' cannot use";
    }

    my %project_args = (
                         project_id => $project_id,
                         api_key    => $key,
                       );

    $resultset->create( \%project_args );

    return \%project_args;

  }

}

1;

