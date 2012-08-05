use strict;
use warnings;
package Murakumo::CLI::DB;
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
    # warn "conn: ", ref $conn;
    $obj->schema( $conn );
    # warn qq(connect( $dsn, $user ));
  };
  if ($@) {
    croak "*** $dsn connection error($@)";
  }

  return $obj;
}

sub schema {
  my ($self, $schema) = @_;
  # warn "schema: ", ref $schema;
  if ($schema) {
    $self->{schema} = $schema;
  }

  return $self->{schema};
}

1;


