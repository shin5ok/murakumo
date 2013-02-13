use strict;
use warnings;
package Murakumo::CLI::DB 0.03 {
  use Carp;
  use FindBin;
  use lib qq{$FindBin::Bin/../lib};
  use Murakumo::CLI::Utils;
  use Murakumo::CLI::Schema;
  use base q(Murakumo::CLI::Schema);
  
  {
    my $config = Murakumo::CLI::Utils->new->config;
    our $dsn  = $config->{db_dsn};
    our $pass = $config->{db_pass};
    our $user = $config->{db_user};
    our $conn;
  }
  
  sub new {
    my ($class) = @_;
    my $obj = bless +{}, $class;
  
    local $@;
    our ($dsn, $pass, $user);
    our $conn;
    eval {
      $conn ||= $class->connect( $dsn, $user, $pass );
      $obj->schema( $conn );
    };
    if ($@) {
      croak "*** $dsn connect error($@)";
    }
  
    return $obj;
  }
  
  sub schema {
    my ($self, $schema) = @_;
  
    if ($schema) {
      $self->{schema} = $schema;
    }
  
    return $self->{schema};
  }
  
}

1;

