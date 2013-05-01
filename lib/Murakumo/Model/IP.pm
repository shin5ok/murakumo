package Murakumo::Model::IP;
use strict;
use warnings;
use base 'Catalyst::Model::Adaptor';

__PACKAGE__->config(
    class       => 'Murakumo::CLI::IP',
    constructor => 'new',
);

1;
