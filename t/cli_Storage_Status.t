use strict;
use warnings;
use Test::More;

require_ok("Murakumo::CLI::Storage::Status");

my $obj = Murakumo::CLI::Storage::Status->new;

can_ok("Murakumo::CLI::Storage::Status", q{regist});

done_testing();

