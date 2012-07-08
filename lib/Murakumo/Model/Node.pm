package Murakumo::Model::Node;
use strict;
use warnings;
use base 'Catalyst::Model::Adaptor';

__PACKAGE__->config( 
    class       => 'Murakumo::CLI::Node',
    constructor => 'new',
);

1;
