use strict;
use warnings;
use Test::More qw(no_plan);
use Data::Dumper;

use lib qw(/home/Murakumo/lib);

BEGIN {
  use_ok ('Murakumo::CLI::VPS_Define');
  use_ok ('Murakumo::CLI::Utils');
};

# local $ENV{DBIC_TRACE} = exists $ENV{DEBUG};

my $vps_define = Murakumo::CLI::VPS_Define->new;

is(ref $vps_define, 'Murakumo::CLI::VPS_Define', "object ref valid type");

my @methods = qw(
  info
  list
  xml_sync
  delete
  create_or_modify
  list_from_db
  record_cloning
  commit_define
  cancel_define
  get_define_json
);

for my $method ( @methods ) {
  can_ok($vps_define, $method);
}

my $uuid = shift || Murakumo::CLI::Utils->create_uuid;
# b8812882-94d5-4f91-90e7-837c1658fca7
ok($uuid =~ /^
              [0-9a-z]{8} \-
              [0-9a-z]{4} \-
              [0-9a-z]{4} \-
              [0-9a-z]{4} \-
              [0-9a-z]{12}
           $/xmsi, "uuid create");

my $mac = Murakumo::CLI::Utils->create_random_mac();
ok($mac =~ /^
              [0-9a-f]{2}: 
              [0-9a-f]{2}: 
              [0-9a-f]{2}: 
              [0-9a-f]{2}: 
              [0-9a-f]{2}: 
              [0-9a-f]{2}
           $/xms, "mac create");
my @disks;
my @interfaces;

my $project_id = 99999;

push @disks,
{
  image_path => "/vm/$project_id/$uuid.img",
  driver     => "virtio",
};

push @interfaces,
{
  bridge     => "br0200", 
  mac        => $mac,
  ip         => "172.24.1.43",
  driver     => "virtio",
};

# 基本vps定義データの構造 ##################################
my $data = {
  vps => {
    uuid       => $uuid,
    name       => $uuid,
    memory     => 102400,
    clock      => 'utc',
    cpu_number => 2,
    project_id => $project_id,
  },
  disk      => \@disks,
  interface => \@interfaces,
};
#############################################################

my $created = $vps_define->create_or_modify( $project_id, $uuid, $data );
ok($created, "vps $uuid create");

# 作ったvpsのデータを取得
{
  my $vps_info = $vps_define->info($uuid);
  {
    local $Data::Dumper::Terse = 1;
    warn Dumper $vps_info;
  }
  ok($vps_info, "vps info get");
}

@disks = ();
@interfaces = ();
$data->{vps}->{memory}     = 204800;
$data->{vps}->{cpu_number} = 5;
$data->{vps}->{clock}      = 'localtime';
push @disks,
{
  image_path => "/vm/$project_id/${uuid}.img",
  driver     => "virtio",
};
push @disks,
{
  image_path => "/vm/$project_id/${uuid}-02.img",
  driver     => "virtio",
};
push @interfaces,
{
  bridge     => "br0300", 
  mac        => Murakumo::CLI::Utils->create_random_mac,
  ip         => "172.24.250.100",
  driver     => "virtio",
};
push @interfaces,
{
  bridge     => "br0200", 
  mac        => $mac,
  ip         => "172.24.1.43",
  driver     => "virtio",
};
$data->{disk}      = \@disks;
$data->{interface} = \@interfaces;
$data->{ip} = '172.24.100.1';
$data->{vlan_id} = 200;

my $modified = $vps_define->create_or_modify( $project_id, $uuid, $data );
ok($modified, "vps $uuid modified");

# 修正したvpsのデータを取得
{
  my $vps_info = $vps_define->info($uuid);
  {
    local $Data::Dumper::Terse = 1;
    warn Dumper $vps_info;
  }
  ok($vps_info, "vps info get");

  my $vps_ref = $vps_define->list( $project_id );
  ok( @$vps_ref > 0, "vps list (from_db)" );
  ok( ref $vps_ref eq 'ARRAY', "vps list return array ref");
  ok( exists $vps_ref->[0]->{'uuid'}, "vps list return array ref has uuid key");

}

my $deleted = $vps_define->delete($uuid);
ok($deleted, "vps $uuid define delete");

my $deleted_vps_info = $vps_define->info($uuid);
ok(! $deleted_vps_info, "vps info is deleted");
# warn Dumper $deleted_vps_info;

