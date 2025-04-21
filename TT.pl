#!/usr/bin/perl

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
#
#
# VERSION 0.1a - TESTING VERSION ONLY

use strict;
use warnings;
use LWP::UserAgent;
use JSON;
use List::Util qw(min max);
use Text::CSV;
use Time::Piece;

# Configuration
my $symbol_file = "data/symbols.txt";
my $output_file = "output/signals.csv";
my $api_key = "YOUR_ALPHA_VANTAGE_API_KEY"; # Replace with actual API key
my $base_url = "https://www.alphavantage.co/query";

# Parameters
my $threshold_pct = 5;
my $days_to_analyze = 90;

# Setup user agent
my $ua = LWP::UserAgent->new;

# Open symbol file
open my $sfh, '<', $symbol_file or die "Cannot open $symbol_file: $!";
my @symbols = <$sfh>;
chomp @symbols;
close $sfh;

# Prepare CSV output
open my $out, '>', $output_file or die "Cannot write to $output_file: $!";
my $csv = Text::CSV->new({ binary => 1, eol => $/ });
$csv->print($out, [qw(Symbol Support Resistance Latest Signal)]);

foreach my $symbol (@symbols) {
    print "Analyzing $symbol...
";
    my $url = "$base_url?function=TIME_SERIES_DAILY_ADJUSTED&symbol=$symbol&outputsize=compact&apikey=$api_key";

    my $res = $ua->get($url);
    unless ($res->is_success) {
        warn "Failed to fetch data for $symbol: " . $res->status_line;
        next;
    }

    my $data = decode_json($res->decoded_content);
    next unless exists $data->{'Time Series (Daily)'};

    my %timeseries = %{ $data->{'Time Series (Daily)'} };
    my @dates = sort { $b cmp $a } keys %timeseries;
    my @closes;

    for my $date (@dates[0..$days_to_analyze-1]) {
        push @closes, $timeseries{$date}->{'4. close'};
    }

    next unless @closes == $days_to_analyze;

    my $support = min @closes;
    my $resistance = max @closes;
    my $latest = $closes[0];

    my $pct_from_support = (($latest - $support) / $support) * 100;
    my $pct_from_resistance = (($resistance - $latest) / $resistance) * 100;

    my $signal = "HOLD";
    $signal = "BUY" if $pct_from_support <= $threshold_pct;
    $signal = "SELL" if $pct_from_resistance <= $threshold_pct;

    $csv->print($out, [$symbol, $support, $resistance, $latest, $signal]);
}

close $out;
print "Analysis complete. Report contained in $output_file\n";
