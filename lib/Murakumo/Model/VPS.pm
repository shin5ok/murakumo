package Murakumo::Model::VPS;
use strict;
use warnings;
use base 'Catalyst::Model::Adaptor';

__PACKAGE__->config( 
    class       => 'Murakumo::CLI::VPS',
    constructor => 'new',
);

1;
