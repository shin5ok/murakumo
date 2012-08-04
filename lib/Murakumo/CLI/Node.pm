use strict;
use warnings;
package Murakumo::CLI::Node 0.03;
use URI;
use JSON;
use Carp;
use Data::Dumper;
use HTTP::Request::Common qw/ POST GET /;
use LWP::UserAgent;

use FindBin;
use lib qq{$FindBin::Bin/../lib};
use Murakumo::CLI::Utils;
use Murakumo::CLI::DB;
use base qw( Murakumo::CLI::DB );

my $utils = Murakumo::CLI::Utils->new; 

sub new {
  my ($class) = @_;
  my $obj = $class->SUPER::new( @_ );
  my $wwwua = LWP::UserAgent->new;
  $wwwua->timeout(10);

  $obj->{wwwua} = $wwwua;
  return $obj;
}

sub wwwua {
  return shift->{wwwua};
}

sub make_uri {
  my ($self, $node, $path, $schema) = @_;
  $schema ||= 'http';
  my $uri = sprintf "%s://%s/%s", $schema, $node, $path;
  return URI->new( $uri );
}

sub select {
  # my ($self, @keys) = @_;
  # 選定基準としたいキーがあれば、それを順番に指定
  # my $resultset = $self->schema->resultset('Node');

  require Murakumo::CLI::Node::Select;
  goto \&Murakumo::CLI::Node::Select::select;

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

sub register {
  my ($self, $node_name, $node_ref) = @_;
  my $resultset = $self->schema->resultset('Node');

  local $@;
  eval {
    # エラー処理はどうするか・・・そもそも↓は例外を出すのか
    no strict 'refs';
    $resultset->update_or_create($node_ref, { node => $node_name });
  };
  if ($@) {
    warn $@;
    return 0;
  }
  return 1;
}

sub list {
  my ($self, $until) = @_;
  my $resultset = $self->schema->resultset('Node');
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
                              # $_->update_time,
                            }

                         } @nodes;
  };
  $@ and warn $@;
  return @node_results;

}

1;
__END__

