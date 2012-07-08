#!/home/smc/bin/perl
use strict;
use warnings;
# use XML::TreePP;
use JSON;
use Data::Dumper;
use Carp;
use HTTP::Request::Common qw(POST GET);
use LWP::UserAgent;

use lib qw(/home/smc/Murakumo/lib);
use Murakumo::CLI::Utils;

my $uri = 'http://127.0.0.1:3000/';

my $data = "";
my $method;
my $uri_arg;
eval {
  $SIG{ALRM} = sub { croak "*** timeout" };
  alarm 10;
  my $body_flag;
  while (my $line = <STDIN>) {
    if (! $body_flag) {
      if ($line =~ /^X\-API\-URI:\s*(\S+)/) {
        $uri_arg = $1;
      }
      if ($line =~ /^X\-API\-METHOD:\s*(\S+)/) {
        $method = $1;
      }
      if ($line =~ /^\s*$/) {
        $body_flag = 1;
      }
    }
    $body_flag or next;
    $data .= $line;
  }
  alarm 0;
};

alarm 0;

my $ref;
eval {
  $ref = decode_json $data;
};
if ($@) {
  _log( $@ );
  exit 75; # 再送
}

my $ua = LWP::UserAgent->new;
$ua->timeout(10);

my $param_ref = $ref;
{
  open my $v, ">", "/tmp/json-tmp.txt";
  flock $v, 2;
  print {$v} Dumper $param_ref;
  close $v;
}

my $request;
my $query_ref = { json => encode_json $ref };
if ($method eq 'GET') {
  $request = GET  $uri, [ $query_ref ];
} else {
  $uri    .= $uri_arg;
  $request = POST $uri, [ $query_ref ];
}

_log("#");
my $response = $ua->request( $request );

_log("##");

# ちゃんとログに出すようにする
my $log = sprintf "web server method (%s)", Dumper $ref;
if (! $response->is_success) {
  _log( "$log is *** NG" );
  warn;
  exit 75;  # 再送
} else {
  _log( "$log is ok" );
  my $r = $response->content;
  print $r,"\n";
  exit 0;
}

sub _log {
  open my $v, ">>", "/tmp/log";
  flock $v, 2;
  print {$v} shift, "\n";
  close $v;
#  warn shift;
}
