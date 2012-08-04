use strict;
use warnings;
package Murakumo::CLI::VPS_Define::XML 0.01;

use JSON;
use Data::Dumper;
use XML::TreePP;
use Carp;
use Path::Class;

our $VERSION = q(0.0.1);
# これ設定ファイルから取る
our $base_path = q{/vm/config};

sub sync {
  my ( $self, $user_id ) = @_;
  my $d_obj = dir( $base_path, $user_id );

  $d_obj or croak "*** $user_id dir cannot open";

  # force_array オプションが必要・・・ disk と interface は必ず array
  my @xmls;
  my $xml_tpp = XML::TreePP->new( force_array => ["disk", "interface"] );
  for my $file ( $d_obj->children ) {
    $file =~ / \.xml $/xo or next;
    my $x = $xml_tpp->parsefile( $file )->{domain};
  }

}

sub xml_sync {
  my ($self, @args) = @_;
  my $xml_obj = Murakumo::CLI::DB::VPS_Define::XML->new;
  $xml_obj->sync( @args );
}

1;
