use strict;
use warnings;

use Test::More;
use lib 'lib';

use TechTradeASX::Symbols qw(read_symbols_from_string);

my @symbols = read_symbols_from_string(<<'SYMBOLS');
# banks and miners
CBA.AX BHP.AX

WES.AX
CSL.AX   TLS.AX   # defensive and telco
SYMBOLS

is_deeply(
    \@symbols,
    [qw(CBA.AX BHP.AX WES.AX CSL.AX TLS.AX)],
    'parses line-separated and whitespace-separated symbols'
);

my @empty = read_symbols_from_string("\n# comment only\n   \n");
is_deeply(\@empty, [], 'ignores blank lines and comments');

done_testing();
