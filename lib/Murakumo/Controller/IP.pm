package Murakumo::Controller::IP;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Murakumo::Controller::IP - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub list :Local {
  my ($self, $c) = @_;
  my $vlan_id = $c->request->query_params->{vlan_id};
  
  my $ip_model = $c->model('IP');
  $c->stash->{list} = $ip_model->list( $vlan_id );
  $c->stash->{result} = 1;

}

sub list_count :Local {
  my ($self, $c) = @_;
  
  my $ip_model = $c->model('IP');
  $c->stash->{list}   = $ip_model->list_count;
  $c->stash->{result} = 1;

}


=head1 AUTHOR

kawano

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
