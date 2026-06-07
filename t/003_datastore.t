use strict;
use warnings;

use Test::More;
use File::Temp qw(tempdir);
use lib 'lib';

use TechTradeASX::DataStore::SQLite;

my $dir = tempdir(CLEANUP => 1);
my $db = "$dir/test.db";
my $store = TechTradeASX::DataStore::SQLite->new(db_file => $db);

ok($store->init_schema, 'schema initialised');
ok($store->upsert_symbol(symbol => 'CBA.AX'), 'symbol stored');

$store->upsert_daily_price(
    symbol => 'CBA.AX',
    date => '2026-01-02',
    open => 100,
    high => 105,
    low => 99,
    close => 104,
    adjusted_close => 104,
    volume => 1000000,
    source => 'test',
);

my @rows = $store->get_daily_prices(symbol => 'CBA.AX');
is(scalar @rows, 1, 'one price row returned');
is($rows[0]{close}, 104, 'close stored');

done_testing();
