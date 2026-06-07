package TechTradeASX::Risk;

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = qw(position_size);

sub position_size {
    my (%args) = @_;

    my $capital       = $args{capital}       || 0;
    my $risk_pct      = $args{risk_pct}      || 1;
    my $entry_price   = $args{entry_price}   || 0;
    my $stop_price    = $args{stop_price}    || 0;
    my $max_pos_pct   = $args{max_pos_pct}   || 10;
    my $min_trade_val = $args{min_trade_val} || 0;

    return 0 unless $capital > 0;
    return 0 unless $entry_price > 0;
    return 0 unless $stop_price > 0;
    return 0 unless $entry_price > $stop_price;

    my $risk_dollars = $capital * ($risk_pct / 100);
    my $risk_per_share = $entry_price - $stop_price;
    my $shares_by_risk = int($risk_dollars / $risk_per_share);

    my $max_position_value = $capital * ($max_pos_pct / 100);
    my $shares_by_cap = int($max_position_value / $entry_price);

    my $shares = $shares_by_risk < $shares_by_cap ? $shares_by_risk : $shares_by_cap;
    return 0 if $shares < 1;

    my $trade_value = $shares * $entry_price;
    return 0 if $trade_value < $min_trade_val;

    return $shares;
}

1;
