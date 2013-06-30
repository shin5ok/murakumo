use strict;
use warnings;
use Test::More;

require_ok("Murakumo::CLI::DB");

{
  no warnings;
  ok( defined $Murakumo::CLI::DB::dsn );
}

ok( Murakumo::CLI::DB->new );
can_ok("Murakumo::CLI::DB", q{schema});

done_testing();

