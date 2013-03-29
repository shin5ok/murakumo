use strict;
use warnings;

package Murakumo::CLI::Schema::Result::VpsDefine 0.01 {

  __PACKAGE__->has_many(
                         ip => 'Murakumo::CLI::Schema::Result::Ip',
                         'used_vps_uuid',
                       );

}

1;
