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
# VERSION 0.2 - TESTING VERSION ONLY

use strict;
use warnings;

use lib 'lib';

use File::Path qw(make_path);
use Text::CSV;

use TechTradeASX::DataProvider::AlphaVantage;
use TechTradeASX::Range qw(analyze_daily_series);
use TechTradeASX::Symbols qw(read_symbols_from_file);

# Configuration. These defaults keep the old tree layout intact while allowing
# local overrides from the shell.
my $symbol_file     = $ENV{TECHTRADE_SYMBOL_FILE}   || 'data/symbols.txt';
my $output_file     = $ENV{TECHTRADE_OUTPUT_FILE}   || 'output/signals.csv';
my $threshold_pct   = $ENV{TECHTRADE_THRESHOLD_PCT} || 5;
my $days_to_analyze = $ENV{TECHTRADE_DAYS}          || 90;

die_if_bad_config();

my @symbols = read_symbols_from_file($symbol_file);
die "No symbols found in $symbol_file\n" unless @symbols;

ensure_output_dir($output_file);

my $provider = TechTradeASX::DataProvider::AlphaVantage->new;

open my $out, '>', $output_file
    or die "Cannot write to $output_file: $!\n";

my $csv = Text::CSV->new({ binary => 1, eol => $/ })
    or die "Cannot create CSV writer\n";

$csv->print($out, [
    qw(Symbol Support Resistance Latest PctFromSupport PctFromResistance Signal Notes)
]);

for my $symbol (@symbols) {
    print STDERR "Analyzing $symbol...\n";

    my $timeseries = $provider->fetch_daily_series($symbol);

    unless ($timeseries) {
        $csv->print($out, [
            $symbol, '', '', '', '', '', 'ERROR', 'No usable daily time series returned'
        ]);
        next;
    }

    my $result = analyze_daily_series(
        symbol        => $symbol,
        timeseries    => $timeseries,
        days          => $days_to_analyze,
        threshold_pct => $threshold_pct,
    );

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
        unless defined $ENV{ALPHAVANTAGE_API_KEY} && length $ENV{ALPHAVANTAGE_API_KEY};

    die "TECHTRADE_DAYS must be a positive integer\n"
        unless defined $days_to_analyze && $days_to_analyze =~ /^\d+$/ && $days_to_analyze > 0;

    die "TECHTRADE_THRESHOLD_PCT must be a non-negative number\n"
        unless defined $threshold_pct && $threshold_pct =~ /^\d+(?:\.\d+)?$/;
}

sub ensure_output_dir {
    my ($file) = @_;

    if ($file =~ m{^(.+)/[^/]+$}) {
        my $dir = $1;
        make_path($dir) unless -d $dir;
    }

    return 1;
}
