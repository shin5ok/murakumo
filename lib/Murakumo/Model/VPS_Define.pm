package Murakumo::Model::VPS_Define;
use strict;
use warnings;
use base 'Catalyst::Model::Adaptor';

__PACKAGE__->config( 
    class       => 'Murakumo::CLI::VPS_Define',
    constructor => 'new',
);

1;
