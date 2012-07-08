use warnings;
use strict;

use lib q(/home/smc/Murakumo/lib);
use Murakumo::CLI::DB::VPS;

my $node_uuid = q|8e969471-1489-4dff-8113-a7f3426ec9cc|;
chomp ( my $uuid = `uuidgen` );
my $s = {
    # `vps_name` varchar(64) NOT NULL DEFAULT '',
    # `uuid` varchar(48) DEFAULT NULL,
    # `node_uuid` varchar(48) DEFAULT NULL,
    # `ip` varchar(16) DEFAULT NULL,
    # `enable` tinyint(1) DEFAULT NULL,
    # `status` varchar(32) DEFAULT NULL,
    # `regist_time` time DEFAULT NULL,
    # `update_key` varchar(48) DEFAULT NULL,
    uuid      => shift,
    vps_name  => shift,
    node_uuid => shift,
    ip        => shift,
    status    => shift,
};
my $x = Murakumo::CLI::DB::VPS->list;
print $x, "\n";
