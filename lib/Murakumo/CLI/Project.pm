use strict;
use warnings;
package Murakumo::CLI::Project 0.01;
use JSON;
use Carp;
use Data::Dumper;
use FindBin;
use lib qq{$FindBin::Bin/../lib};
use Murakumo::CLI::Utils;
use Murakumo::CLI::DB;
use base q(Murakumo::CLI::DB);

sub is_exist {
  my ($self, $project_id) = @_;

  if (! defined $project_id ) {
    # project_id の指定がなければ( これは ダミー )
    croak "project_id is none.";

  }

  my $resultset = $self->schema->resultset('Project');
  my $count = $resultset->search( { project_id => $project_id, } )->count;
  if ($count != 1) {
    croak "*** project id is invalid";
  }
  return 1;

}

sub auth {
  my ($self, $project_id, $api_key) = @_;
  my $resultset = $self->schema->resultset('Project');
  my ($x) = $resultset->search({ project_id => $project_id } );
  warn "project_id: $project_id" if $project_id;
  warn "################### ", $x->api_key, " eq $api_key";
  return $x->api_key eq $api_key;
}

1;
__END__


