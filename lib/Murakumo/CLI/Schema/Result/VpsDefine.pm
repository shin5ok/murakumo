use strict;
use warnings;

package Murakumo::CLI::Schema::Result::VpsDefine 0.01 {

  __PACKAGE__->has_one(
                        vps_rel => 'Murakumo::CLI::Schema::Result::Vps',
                      );

}

1;
