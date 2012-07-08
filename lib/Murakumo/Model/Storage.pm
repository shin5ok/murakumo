package Murakumo::Model::Storage;
use strict;
use warnings;
use base 'Catalyst::Model::Adaptor';

__PACKAGE__->config( 
    class       => 'Murakumo::CLI::Storage',
    constructor => 'new',
);

1;
