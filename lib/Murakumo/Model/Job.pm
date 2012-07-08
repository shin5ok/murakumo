package Murakumo::Model::Job;
use strict;
use warnings;
use base 'Catalyst::Model::Adaptor';

__PACKAGE__->config( 
    class       => 'Murakumo::CLI::Job',
    constructor => 'new',
);

1;
