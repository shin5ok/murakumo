use strict;
use warnings;
use Data::Dumper;
use opts;

if (@ARGV > 3) {
  opts my $test => 'Str',
       my $number => 'Int';
   
  my @args = @ARGV;
  print Dumper \@args;

} else {
  opts my $test2 => 'Str',
       my $number2 => 'Int';
   
  my @args = @ARGV;
  print Dumper \@args;

}
