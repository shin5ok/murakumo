use strict;
use warnings;
package Murakumo::CLI::Admin 0.01 {

  use Carp;
  use Net::CIDR;
  use Data::Dumper;
  use FindBin;
  use lib qq{$FindBin::Bin/../lib};
  use Murakumo::CLI::DB;
  use base q(Murakumo::CLI::DB);
  
  sub is_admin_access {
    my ($self, $admin_api_key, $request_object) = @_;

    my $resultset = $self->schema->resultset('Admin');
    my @rs = $resultset->search;
  
    my $src_ip = $request_object->address;
  
    for my $r ( @rs ) {
      if (my $networks = $r->allow_network) {
         if (! Net::CIDR::cidrlookup( $src_ip, ( split /,/, $networks ) )) {
           croak "*** $src_ip is invalid allow network"; 
         }
  
      }
    }
  
    return $x->api_key eq $admin_api_key;

  }
}

1;
__END__


