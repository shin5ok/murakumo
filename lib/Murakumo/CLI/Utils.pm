use strict;
use warnings;
package Murakumo::CLI::Utils;
use URI;
use JSON;
use Carp;
use Data::Dumper;
use DateTime;
use HTTP::Request::Common qw/ POST GET /;
use LWP::UserAgent;
use Data::UUID;
use Config::General;
use IPC::Open2;
use Sys::Hostname;
use FindBin;

our $VERSION = q(0.0.3);

our $config_path   = qq{$FindBin::Bin/../Murakumo.conf};
our $root_itemname = q{root};

sub import {
  my $caller = caller;
  no strict 'refs';
  *{"${caller}::dumper"} = \&dumper;
}

sub new {
  my $class = shift;
  bless {
    wwwua => LWP::UserAgent->new,
  }, $class;
}

sub dumper {
  my $ref = shift;

  my ($package, $filename, $line) = caller;
  my $file_path = sprintf "/tmp/%s,%s",
                           $package,
                           $line;
  warn "file_path: ", $file_path;
  open my $fh, ">", $file_path;
  flock $fh, 2;
  print {$fh}     Dumper($ref);
  print {*STDERR} Dumper($ref);
  close $fh;
}

sub now_string {
  my $now = now();
  my $now_string = $now->strftime("%Y-%m-%dT%H:%M:%S");
  return $now_string;
}

sub now {
  my $now = DateTime->now( time_zone => 'Asia/Tokyo' );
  return $now;
}

sub wwwua {
  return shift->{wwwua};
}

sub create_uuid {
  return lc Data::UUID->new->create_str;
}

sub make_uri {
  my ($self, $node, $path, $schema) = @_;
  $schema ||= 'http';
  my $uri = sprintf "%s://%s/%s", $schema, $node, $path;
  return URI->new( $uri );
}

sub my_hostname {
  my ($hostname)  = hostname() =~ /^([^\.]+)/;
  use Socket;
  my $private_ip = inet_ntoa(inet_aton($hostname));
  return ($hostname, $private_ip) if wantarray;
  return  $hostname;
}

sub api_post {

  my ($self, $uri, $param) = @_;

  my $wwwua = $self->wwwua;

  my $request = POST $uri, [ $param ];
  warn Dumper $request;
  
  my $response = $wwwua->request( $request );
  if ($response->is_success) {
    return $response->content;

  } else {
    warn "*** http request error for $uri";
    return undef;
 
  }

}

sub config {
  my ($self, $config) = @_; 
  $config ||= $config_path;

  my %param;
  local $@;
  eval {
    my $c  = Config::General->new( $config );
    %param = $c->getall;
  };

  if ($@) {
    warn $@;
    return {};
  }

  return \%param;

}

sub create_random_mac {
  my ($self) = @_;
  # python の virtinstモジュールが入っている必要があります
  my $pid = open2 my $r, my $w, "/usr/bin/python";
  my $python_code = << '__PYTHON__';
import virtinst.util as u
mac = u.randomMAC("qemu")
print mac,
__PYTHON__
  print {$w} $python_code;
  close $w;
  chomp ( my $mac = <$r> );
  $mac =~ /^
              [0-9a-f]{2}: 
              [0-9a-f]{2}: 
              [0-9a-f]{2}: 
              [0-9a-f]{2}: 
              [0-9a-f]{2}: 
              [0-9a-f]{2}
           $/xms or croak "mac address create failure...";
  return $mac;
}

1;
__END__


