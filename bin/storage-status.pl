#!/usr/bin/env murakumo-perl
use strict;
use warnings;
use LWP::UserAgent;
use Carp;
use JSON;
use URI;
use Net::SNMP;
use Net::Ping;
use FindBin;
use Data::Dumper;
use lib qq{$FindBin::Bin/../lib};
use Murakumo::CLI::Utils;
use Murakumo::CLI::Storage::Status;

my $config_path = exists $ENV{MURAKUMO_STORAGE_STATUS_CONFIG}
                ? $ENV{MURAKUMO_STORAGE_STATUS_CONFIG}
                : qq{/root/storage-status.json};

warn $config_path;
my $config = -f $config_path
           ? do {
                  open my $fh, "<", $config_path;
                  local $/;
                  my $data = <$fh>;
                  close $fh;
                  decode_json $data;
              }
           : +{};

warn Dumper $config;

# MURAKUMO_PROJECT_ID=00000001
# MURAKUMO_ADMIN_KEY=b348b62c65ec47ce800807a995716668
# MURAKUMO_API_URI=http://172.24.1.227:3000
# MURAKUMO_API_KEY=466999d430684e87a46234ca7234b0e2
my $admin_key = $ENV{MURAKUMO_ADMIN_KEY};
my $api_uri   = $ENV{MURAKUMO_API_URI};

my $ua  = Murakumo::CLI::Utils::user_agent();

my $uri = URI->new( sprintf "%s/admin/storage/list", $api_uri );
$uri->query_form( admin_key => $admin_key );
warn $uri;
my $response = $ua->get( $uri );

if (! $response->is_success) {
  croak sprintf "*** %s is get api failure(status code:%d)",
                $0,
                $response->code;

}

my $content = $response->content;

my $ref = decode_json $content;

no strict 'refs';
my $storage_config = $config->{storage} // +{};

my $storage_status = Murakumo::CLI::Storage::Status->new;

for my $s ( @{$ref->{data}} ) {
  my $uuid = $s->{uuid};
  my $host = $s->{host};


  my $params = {
                 method    => q{snmp},
                 params => {
                   host      => $host,
                   community => $config->{default_community} // q{public},
                 },
               },;

  if (exists $storage_config->{$uuid}) {
    warn "config for $uuid is exist";
    %$params = (%$params, %{$storage_config->{$uuid}});
  }

  status_register(
    $uuid,
    $params,
  );

}


sub status_register {
  my $uuid   = shift;
  my $ref    = shift;
  my $method = $ref->{method};

  warn Dumper $ref;

  local $@;
  eval {
    my $status = GET_STATUS->$method( $ref->{params} // {} );
    $storage_status->regist( $uuid, $status );
  };

  warn $@ if $@;

}

package GET_STATUS {
  require Net::SNMP;
  use Data::Dumper;
  use Carp;

  sub snmp {
    my ($self, $params) = @_;

    my ($session, $error) = Net::SNMP->session(
                                        -hostname  => $params->{host},
                                        -community => $params->{community},
                                        -timeout   => 10,
                                      );
    croak $error if $error;

    no strict 'refs';
    my $number = $params->{partition_number} // 1;

    my %oids = (
      iowait     => qq{.1.3.6.1.4.1.2021.11.54},
      avail_size => qq{.1.3.6.1.4.1.2021.9.1.7},
    );

    my %result;
    for my $name ( keys %oids ) {
      my $r = $session->get_table( -baseoid => $oids{$name} );
      my $error = $session->error;

      if ($name eq q{avail_size}) {
        my $index = $oids{avail_size} . ".$number";
        warn $index;
        $result{avail_size} = $r->{$index};
      } else {
        my $index = $oids{iowait}     . ".0";
        $result{iowait}     = $r->{$index};
      }

    }

    warn Dumper \%result;
    return \%result;

  }

  sub ssh {

  }

}



__END__
+--- request debug -----------------------------------------------------------------------------------------------+
method: GET
uri:    http://172.24.1.227:3000/00000001/storage/list/?admin_key=b348b62c65ec47ce800807a995716668
+-----------------------------------------------------------------------------------------------------------------+
+--- response debug ----------------------------------------------------------------------------------------------+
{
   "authed" : 1,
   "is_admin" : 1,
   "data" : [
      {
         "priority" : "100",
         "avail_size" : "0",
         "export_path" : "/home/vps",
         "uuid" : "cf25df7f-062a-4270-87eb-d326441fe73b",
         "host" : "10.10.1.234",
         "mount_path" : "/nfs/cf25df7f-062a-4270-87eb-d326441fe73b",
         "regist_time" : "2012-11-08 20:08:26",
         "tag" : null,
         "type" : "nfs",
         "iowait" : "0"
      },
      {
         "priority" : "500",
         "avail_size" : "0",
         "export_path" : "/export/vps",
         "uuid" : "0525dc31-9a12-465c-944f-72442d22eeed",
         "host" : "10.10.1.234",
         "mount_path" : "/nfs/0525dc31-9a12-465c-944f-72442d22eeed",
         "regist_time" : "2012-11-08 19:53:48",
         "tag" : null,
         "type" : "nfs",
         "iowait" : "0"
      },
      {
         "priority" : "100",
         "avail_size" : "100",
         "export_path" : "/export/vps",
         "uuid" : "46955c8a-3cae-43f6-8f5a-2cc36ffe8fa5",
         "host" : "10.10.1.235",
         "mount_path" : "/nfs/46955c8a-3cae-43f6-8f5a-2cc36ffe8fa5",
         "regist_time" : "2013-06-13 18:08:41",
         "tag" : null,
         "type" : "nfs",
         "iowait" : "5"
      },
      {
         "priority" : "100",
         "avail_size" : "0",
         "export_path" : "/dummy",
         "uuid" : "1864ab1b-60d8-452a-9f1c-c39b5c4a7b6d",
         "host" : "172.24.1.227",
         "mount_path" : "/nfs/1864ab1b-60d8-452a-9f1c-c39b5c4a7b6d",
         "regist_time" : "2013-04-19 10:28:36",
         "tag" : null,
         "type" : "nfs",
         "iowait" : "0"
      }
   ],
   "project_id" : "00000001",
   "message" : "",
   "result" : 1
}
+-----------------------------------------------------------------------------------------------------------------+
.-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------.
| uuid                                 | type | export_path | host         | mount_path                                | priority | avail_size | iowait | regist_time         |
+--------------------------------------+------+-------------+--------------+-------------------------------------------+----------+------------+--------+---------------------+
| cf25df7f-062a-4270-87eb-d326441fe73b | nfs  | /home/vps   | 10.10.1.234  | /nfs/cf25df7f-062a-4270-87eb-d326441fe73b | 100      | 0          | 0      | 2012-11-08 20:08:26 |
| 0525dc31-9a12-465c-944f-72442d22eeed | nfs  | /export/vps | 10.10.1.234  | /nfs/0525dc31-9a12-465c-944f-72442d22eeed | 500      | 0          | 0      | 2012-11-08 19:53:48 |
| 46955c8a-3cae-43f6-8f5a-2cc36ffe8fa5 | nfs  | /export/vps | 10.10.1.235  | /nfs/46955c8a-3cae-43f6-8f5a-2cc36ffe8fa5 | 100      | 100        | 5      | 2013-06-13 18:08:41 |
| 1864ab1b-60d8-452a-9f1c-c39b5c4a7b6d | nfs  | /dummy      | 172.24.1.227 | /nfs/1864ab1b-60d8-452a-9f1c-c39b5c4a7b6d | 100      | 0          | 0      | 2013-04-19 10:28:36 |
'--------------------------------------+------+-------------+--------------+-------------------------------------------+----------+------------+--------+---------------------'
