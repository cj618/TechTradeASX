#!/usr/bin/env perl
#
# TECHTRADE ASX
#
# Copyright (c) 2025 C Jervis. All rights reserved.
#
# Redistribution and use in source and binary form, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
# VERSION 0.1b - TESTING VERSION ONLY

use strict;
use warnings;

use File::Path qw(make_path);
use JSON qw(decode_json);
use List::Util qw(max min);
use LWP::UserAgent;
use Text::CSV;
use URI;

# Configuration. These defaults keep the old tree layout intact while allowing
# local overrides from the shell.
my $symbol_file     = $ENV{TECHTRADE_SYMBOL_FILE}     || 'data/symbols.txt';
my $output_file     = $ENV{TECHTRADE_OUTPUT_FILE}     || 'output/signals.csv';
my $api_key         = $ENV{ALPHAVANTAGE_API_KEY};
my $base_url        = 'https://www.alphavantage.co/query';
my $threshold_pct   = $ENV{TECHTRADE_THRESHOLD_PCT}   || 5;
my $days_to_analyze = $ENV{TECHTRADE_DAYS}            || 90;

 die_if_bad_config();

my @symbols = read_symbols($symbol_file);
die "No symbols found in $symbol_file\n" unless @symbols;

ensure_output_dir($output_file);

my $ua = LWP::UserAgent->new(
    agent  => 'TechTradeASX/0.1b',
    timeout => 30,
);

open my $out, '>', $output_file
    or die "Cannot write to $output_file: $!\n";

my $csv = Text::CSV->new({ binary => 1, eol => $/ })
    or die "Cannot create CSV writer\n";

$csv->print($out, [
    qw(Symbol Support Resistance Latest PctFromSupport PctFromResistance Signal Notes)
]);

for my $symbol (@symbols) {
    print STDERR "Analyzing $symbol...\n";

    my $timeseries = fetch_daily_series($ua, $symbol);

    unless ($timeseries) {
        $csv->print($out, [
            $symbol, '', '', '', '', '', 'ERROR', 'No usable daily time series returned'
        ]);
        next;
    }

    my $result = analyze_symbol($symbol, $timeseries, $days_to_analyze, $threshold_pct);

    unless ($result) {
        $csv->print($out, [
            $symbol, '', '', '', '', '', 'ERROR',
            "Not enough usable data for ${days_to_analyze}-day analysis"
        ]);
        next;
    }

    $csv->print($out, [
        $result->{symbol},
        $result->{support},
        $result->{resistance},
        $result->{latest},
        sprintf('%.2f', $result->{pct_from_support}),
        sprintf('%.2f', $result->{pct_from_resistance}),
        $result->{signal},
        $result->{notes},
    ]);
}

close $out;
print "Analysis complete. Report contained in $output_file\n";

sub die_if_bad_config {
    die "ALPHAVANTAGE_API_KEY is not set. Export it before running this script.\n"
        unless defined $api_key && length $api_key;

    die "TECHTRADE_DAYS must be a positive integer\n"
        unless defined $days_to_analyze && $days_to_analyze =~ /^\d+$/ && $days_to_analyze > 0;

    die "TECHTRADE_THRESHOLD_PCT must be a non-negative number\n"
        unless defined $threshold_pct && $threshold_pct =~ /^\d+(?:\.\d+)?$/;
}

sub read_symbols {
    my ($file) = @_;

    open my $fh, '<', $file
        or die "Cannot open $file: $!\n";

    my @symbols;

    while (my $line = <$fh>) {
        chomp $line;
        $line =~ s/#.*$//;       # allow comments
        $line =~ s/^\s+//;
        $line =~ s/\s+$//;
        next unless length $line;

        push @symbols, split /\s+/, $line;
    }

    close $fh;
    return @symbols;
}

sub ensure_output_dir {
    my ($file) = @_;

    if ($file =~ m{^(.+)/[^/]+$}) {
        my $dir = $1;
        make_path($dir) unless -d $dir;
    }

    return 1;
}

sub fetch_daily_series {
    my ($ua, $symbol) = @_;

    my $uri = URI->new($base_url);
    $uri->query_form(
        function   => 'TIME_SERIES_DAILY_ADJUSTED',
        symbol     => $symbol,
        outputsize => 'compact',
        apikey     => $api_key,
    );

    my $res = $ua->get($uri);

    unless ($res->is_success) {
        warn "Failed to fetch data for $symbol: " . $res->status_line . "\n";
        return;
    }

    my $payload;
    eval {
        $payload = decode_json($res->decoded_content);
        1;
    } or do {
        warn "Failed to decode JSON for $symbol: $@\n";
        return;
    };

    for my $key ('Error Message', 'Information', 'Note') {
        if (exists $payload->{$key}) {
            warn "Alpha Vantage returned $key for $symbol: $payload->{$key}\n";
            return;
        }
    }

    unless (exists $payload->{'Time Series (Daily)'}) {
        warn "No daily time series found for $symbol\n";
        return;
    }

    return $payload->{'Time Series (Daily)'};
}

sub analyze_symbol {
    my ($symbol, $timeseries, $days, $threshold) = @_;

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

    my $support    = min @closes;
    my $resistance = max @closes;
    my $latest     = $closes[0];

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
