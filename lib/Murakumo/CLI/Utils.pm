use strict;
use warnings;
package Murakumo::CLI::Utils 0.03;
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
use Log::Log4perl;

our $config_path     = qq{$FindBin::Bin/../murakumo.conf};
our $log_config_path = qq{$FindBin::Bin/../log4perl.conf};

sub import {
  my $caller = caller;
  no strict 'refs';
  *{"${caller}::dumper"}   = \&dumper;
  *{"${caller}::is_debug"} = \&is_debug;
  *{"${caller}::logger"}   = \&logger;
}

sub new {
  my $class = shift;
  bless {
    wwwua => user_agent(),
  }, $class;
}

sub user_agent {
  my $ua = LWP::UserAgent->new;
  $ua->ssl_opts( verify_hostname => 0, SSL_verify_mode => q{SSL_VERIFY_NONE} );
  $ua->timeout( 30 );
  return $ua;
}

sub dumper {
  my $ref = shift;

  my ($package, $filename, $line) = caller;
  my $file_path = sprintf "/tmp/%s,%s",
                           $package,
                           $line;
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
  my $self = shift;

  my $time_zone;
  eval {
    no strict 'refs';
    $time_zone = $self->config->{time_zone};
  };
  $time_zone //= qq{Asia/Tokyo};

  my $now = DateTime->now( time_zone => $time_zone );
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
  close $r;
  return $mac;
}

sub get_api_key {
  my ($self) = @_;
  open my $fh, "<", $self->config->{api_key_file}
    or croak "api key file open error";
  my $api_key_text = <$fh>;
  close $fh;
  my ($api_key) = $api_key_text =~ /(\S+)/;

  return $api_key;
}

sub is_valid_api_key {
  my ($self, $api_key_of_node) = @_;
  my $api_key = $self->get_api_key;

  if ($api_key eq $api_key_of_node) {
    return 1;
  }
  croak "*** api key error";

}

sub is_debug {
  my @callers = caller;
  return exists $ENV{DEBUG} and $ENV{DEBUG};
}

sub logger {
  Log::Log4perl->init( $log_config_path );
  my $log = Log::Log4perl->get_logger;
  my $level      = shift;
  my $log_string = shift;
  $log->$level( $log_string );
}


1;
__END__



