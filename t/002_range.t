use strict;
use warnings;

use Test::More;
use lib 'lib';

use TechTradeASX::Range qw(analyze_closes analyze_daily_series);

my $buy = analyze_closes(
    symbol        => 'CBA.AX',
    closes        => [101, 100, 110, 120],
    days          => 4,
    threshold_pct => 5,
);

is($buy->{signal}, 'BUY', 'flags a close near support as BUY');
is($buy->{support}, '100.0000', 'calculates support');
is($buy->{resistance}, '120.0000', 'calculates resistance');

my $sell = analyze_closes(
    symbol        => 'BHP.AX',
    closes        => [119, 100, 110, 120],
    days          => 4,
    threshold_pct => 5,
);

is($sell->{signal}, 'SELL', 'flags a close near resistance as SELL');

my $hold = analyze_closes(
    symbol        => 'WES.AX',
    closes        => [110, 100, 120],
    days          => 3,
    threshold_pct => 5,
);

is($hold->{signal}, 'HOLD', 'flags mid-range close as HOLD');

my $series = {
    '2025-01-04' => { '4. close' => '101.00' },
    '2025-01-03' => { '4. close' => '100.00' },
    '2025-01-02' => { '4. close' => '110.00' },
    '2025-01-01' => { '4. close' => '120.00' },
};

my $from_series = analyze_daily_series(
    symbol        => 'CSL.AX',
    timeseries    => $series,
    days          => 4,
    threshold_pct => 5,
);

is($from_series->{latest}, '101.0000', 'uses most recent daily close');
is($from_series->{signal}, 'BUY', 'analyzes Alpha Vantage style daily series');

my $insufficient = analyze_daily_series(
    symbol        => 'TLS.AX',
    timeseries    => $series,
    days          => 5,
    threshold_pct => 5,
);

ok(!defined $insufficient, 'returns undef when insufficient history is available');

done_testing();
