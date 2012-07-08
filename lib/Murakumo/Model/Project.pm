package Murakumo::Model::Project;
use strict;
use warnings;
use base 'Catalyst::Model::Adaptor';

__PACKAGE__->config( 
    class       => 'Murakumo::CLI::Project',
    constructor => 'new',
);

1;
