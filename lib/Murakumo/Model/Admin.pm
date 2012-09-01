package Murakumo::Model::Admin;
use strict;
use warnings;
use base 'Catalyst::Model::Adaptor';

__PACKAGE__->config( 
    class       => 'Murakumo::CLI::Admin',
    constructor => 'new',
);

1;
