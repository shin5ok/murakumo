use strict;
use warnings;

package Murakumo::CLI::Schema::Result::Ip 0.01 {

  __PACKAGE__->belongs_to(
                           vps_define_rel => 'Murakumo::CLI::Schema::Result::VpsDefine',
                           { 'foreign.uuid' => 'self.used_vps_uuid' },
                         );

}

1;
