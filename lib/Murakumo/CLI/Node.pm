use strict;
use warnings;
package Murakumo::CLI::Node;
use URI;
use JSON;
use Data::Dumper;
use HTTP::Request::Common qw/ POST GET /;
use LWP::UserAgent;

use FindBin;
use lib qq{$FindBin::Bin/../lib};
use Murakumo::CLI::Utils;
use Murakumo::CLI::DB;
use base qw( Murakumo::CLI::DB );

our $VERSION = q(0.0.1);

our $root_itemname = q{root};

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
  warn Dumper $request;
  
  my $response = $wwwua->request( $request );
  if ($response->is_success) {
    return $response->content;

  } else {
    return undef;
 
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
    warn "*** http request error for $uri";
    warn $response->content;
    return undef;
 
  }

}

sub api_get {

}

sub register_json {
  my ($self, $json_data) = @_;
  my $json;
  eval {
    my $decoded_json = decode_json $json_data;
    $json = $decoded_json->{$root_itemname};
  };
  return $self->register( $json->{node}->{name}, $json->{node} );
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

# sub should_be_status {
#   my ($self) = @_;
# 
#   my $resultset = $self->schema->resultset('Node');
# 
# }

sub list {
  my ($self, $until) = @_;
  my $resultset = $self->schema->resultset('Node');
  my @node_results;
  local $@;
  eval {

    my @nodes;

    if ($until) {
    warn "not verbose mode";
      my $query = { update_time => { '>' => $until } };
      @nodes = $resultset->search( $query, { order_by => 'name' });

    } else {
    warn "verbose mode";
      @nodes = $resultset->search( undef, { order_by => 'name' } );

    }

    # +--------------+--------------+------+-----+-------------------+-----------------------------+
    # | Field        | Type         | Null | Key | Default           | Extra                       |
    # +--------------+--------------+------+-----+-------------------+-----------------------------+
    # | name         | varchar(255) | NO   | PRI |                   |                             |
    # | uuid         | varchar(48)  | YES  |     | NULL              |                             |
    # | cpu_total    | int(8)       | YES  |     | NULL              |                             |
    # | mem_total    | int(64)      | YES  |     | NULL              |                             |
    # | mem_free     | int(64)      | YES  |     | NULL              |                             |
    # | vps_number   | int(8)       | YES  |     | NULL              |                             |
    # | cpu_vps_used | int(8)       | YES  |     | NULL              |                             |
    # | regist_time  | timestamp    | NO   |     | CURRENT_TIMESTAMP | on update CURRENT_TIMESTAMP |
    # | disable      | tinyint(4)   | YES  |     | 0                 |                             |
    # +--------------+--------------+------+-----+-------------------+-----------------------------+
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
