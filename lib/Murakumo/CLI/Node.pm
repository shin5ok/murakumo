use strict;
use warnings;

package Murakumo::CLI::Node 0.03;
use URI;
use JSON;
use Carp;
use Data::Dumper;
use HTTP::Request::Common qw/ POST GET /;
use LWP::UserAgent;
use Socket;

use FindBin;
use lib qq{$FindBin::Bin/../lib};
use Murakumo::CLI::Utils;
use Murakumo::CLI::DB;
use Murakumo::CLI::Node::Select;
use base qw( Murakumo::CLI::DB );

my $utils  = Murakumo::CLI::Utils->new; 
my $config = $utils->config;

sub new {
  my ($class) = @_;
  my $obj = $class->SUPER::new( @_ );
  my $wwwua = LWP::UserAgent->new;
  $wwwua->timeout(10);

  $obj->{wwwua}      = $wwwua;
  $obj->{select_obj} = Murakumo::CLI::Node::Select->new;
  return $obj;
}

sub wwwua {
  return shift->{wwwua};
}

sub make_uri {
  my ($self, $node, $path, $schema) = @_;
  $schema ||= 'http';

  # ノードにポート番号がついていなかったら、付ける
  $node =~ /:\d+$/
     or $node .= ":" . $config->{api_port};

  my $uri = sprintf "%s://%s/%s", $schema, $node, $path;
  return URI->new( $uri );
}

sub select {
  my $self = shift;

  $self->{select_obj}->select( @_ );
  # Murakumo::CLI::Node::Select->new->select( @_ );
}

sub api_post {
  my ($self, $uri, $params) = @_;

  my $wwwua = $self->wwwua;

  my $request = POST $uri, [ $params ];
  
  my $response = $wwwua->request( $request );
  if ($response->is_success) {
    return $response->content;

  } else {
    croak "*** api_post $uri error";
 
  }

}

sub api_json_post {
  my ($self, $uri, $params) = @_;

  my $wwwua = $self->wwwua;

  my $request = HTTP::Request->new( 'POST', $uri );
  $request->header('Content-Type' => 'application/json');
  $request->content( encode_json $params );
  
  my $response = $wwwua->request( $request );
  if ($response->is_success) {
    return $response->content;

  } else {
    croak sprintf "*** http request error for %s (content: %s)",
                  $uri,
                  $response->content;
 
  }

}


sub is_valid_node {
  my ($self, $node, $uuid, $api_key) = @_;
  my $resultset     = $self->schema->resultset('NodeDefine');
  my ($node_define) = $resultset->search({ name => $node, uuid => $uuid });
  return $node_define->api_key eq $api_key;
}


sub register {
  my ($self, $node_name, $node_ref) = @_;
  my $resultset = $self->schema->resultset('Node');

  local $@;
  eval {
    no strict 'refs';
    $resultset->update_or_create( $node_ref );

  };
  if ($@) {
    warn $@;
    return 0;

  }
  return 1;
}

sub list {
  my ($self, $until)   = @_;
  my $resultset        = $self->schema->resultset('Node');
  my %auto_select_node = map { $_ => 1 }
                         $self->{select_obj}->get_auto_select_nodes;
  my @node_results;
  local $@;
  eval {

    my @nodes;

    if ($until) {
      warn "normal mode";
      my $query = { update_time => { '>' => $until } };
      @nodes = $resultset->search( $query, { order_by => 'name' });

    } else {
      warn "verbose mode";
      @nodes = $resultset->search( undef, { order_by => 'name' } );

    }

    @node_results = map {
                           my $uuid = $_->uuid;
                           +{
                              name         => $_->name,
                              cpu_total    => $_->cpu_total,
                              mem_total    => $_->mem_total,
                              mem_free     => $_->mem_free,
                              loadavg      => $_->loadavg,
                              vps_number   => $_->vps_number,
                              cpu_vps_used => $_->cpu_vps_used,
                              update_time  => $_->update_time,
                              regist_time  => $_->regist_time,
                              uuid         => $uuid,
                              auto_select  => $auto_select_node{$uuid} || 0,
                              ip           => _get_ip_by_nodename( $_->name ),

                            }

                         } @nodes;
  };
  $@ and warn $@;
  return @node_results;

}


sub _get_ip_by_nodename {
  my $name = shift;

  my $ip;
  eval {
    $ip = inet_ntoa(inet_aton( $name ));
  };

  return $ip || undef;

}


sub is_available {
  my ($self, $node) = @_;

  my $node_check_uri = exists $config->{node_check_uri}
                     ? $config->{node_check_uri}
                     : q{/check};

  my $uri = $self->make_uri( $node, $node_check_uri );
  my $r = $self->wwwua->get( $uri );

  return $r->is_success;
   
}

1;
__END__

