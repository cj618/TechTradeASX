package TechTradeASX::Range;

use strict;
use warnings;

use Exporter qw(import);
use List::Util qw(max min);

our @EXPORT_OK = qw(analyze_closes analyze_daily_series);

sub analyze_daily_series {
    my (%args) = @_;

    my $symbol     = $args{symbol};
    my $timeseries = $args{timeseries};
    my $days       = $args{days} || 90;
    my $threshold  = defined $args{threshold_pct} ? $args{threshold_pct} : 5;

    return unless defined $timeseries && ref $timeseries eq 'HASH';

    my @dates = sort { $b cmp $a } keys %{$timeseries};
    return if @dates < $days;

    my @closes;

    for my $date (@dates[0 .. $days - 1]) {
        my $row = $timeseries->{$date};
        next unless ref $row eq 'HASH';
        next unless defined $row->{'4. close'};

        push @closes, $row->{'4. close'} + 0;
    }

    return unless @closes == $days;

    return analyze_closes(
        symbol        => $symbol,
        closes        => \@closes,
        days          => $days,
        threshold_pct => $threshold,
    );
}

sub analyze_closes {
    my (%args) = @_;

    my $symbol    = $args{symbol};
    my $closes    = $args{closes};
    my $days      = $args{days} || 90;
    my $threshold = defined $args{threshold_pct} ? $args{threshold_pct} : 5;

    return unless defined $closes && ref $closes eq 'ARRAY' && @{$closes};

    my $support    = min @{$closes};
    my $resistance = max @{$closes};
    my $latest     = $closes->[0];

    return unless $support && $resistance;

    my $pct_from_support    = (($latest - $support) / $support) * 100;
    my $pct_from_resistance = (($resistance - $latest) / $resistance) * 100;

    my $signal = 'HOLD';
    my $notes  = 'No simple range signal';

    if ($pct_from_support <= $threshold) {
        $signal = 'BUY';
        $notes  = "Latest close is within $threshold% of simple ${days}-day support";
    }

    if ($pct_from_resistance <= $threshold) {
        $signal = 'SELL';
        $notes  = "Latest close is within $threshold% of simple ${days}-day resistance";
    }

    return {
        symbol              => $symbol,
        support             => sprintf('%.4f', $support),
        resistance          => sprintf('%.4f', $resistance),
        latest              => sprintf('%.4f', $latest),
        pct_from_support    => $pct_from_support,
        pct_from_resistance => $pct_from_resistance,
        signal              => $signal,
        notes               => $notes,
    };
}

1;

__END__

=head1 NAME

TechTradeASX::Range - simple support and resistance analysis

=head1 DESCRIPTION

Implements the original TechTrade ASX range signal logic. This module is a
baseline strategy component, not a complete trading system.

=cut
