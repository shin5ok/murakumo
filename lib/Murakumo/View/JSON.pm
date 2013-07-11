package Murakumo::View::JSON;

use strict;
use base 'Catalyst::View::JSON';

use JSON::XS ();

sub encode_json {
  my ($self, $c, $data) = @_;

  JSON::XS->new->allow_nonref->pretty->encode( $data );

}

=head1 NAME

Murakumo::View::JSON - Catalyst JSON View

=head1 SYNOPSIS

See L<Murakumo>

=head1 DESCRIPTION

Catalyst JSON View.

=head1 AUTHOR

shin5ok

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
