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
  $project_id and $api_key
    or return 0;

  my $resultset = $self->schema->resultset('Project');
  my ($x) = $resultset->search({ project_id => $project_id } );
  return $x->api_key eq $api_key;
}

sub is_admin_access {
  my ($self, $admin_api_key, $request_object) = @_;
  # キーに加え、ipアドレスとかでも認証する
  1;
}

1;
__END__


