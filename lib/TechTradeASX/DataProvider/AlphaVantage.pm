package TechTradeASX::DataProvider::AlphaVantage;

use strict;
use warnings;

use JSON qw(decode_json);
use LWP::UserAgent;
use URI;

sub new {
    my ($class, %args) = @_;

    my $api_key = $args{api_key} || $ENV{ALPHAVANTAGE_API_KEY};
    die "ALPHAVANTAGE_API_KEY is not set\n"
        unless defined $api_key && length $api_key;

    my $self = {
        api_key  => $api_key,
        base_url => $args{base_url} || 'https://www.alphavantage.co/query',
        ua       => $args{ua} || LWP::UserAgent->new(
            agent  => 'TechTradeASX/0.2',
            timeout => $args{timeout} || 30,
        ),
    };

    return bless $self, $class;
}

sub fetch_daily_series {
    my ($self, $symbol) = @_;

    my $uri = URI->new($self->{base_url});
    $uri->query_form(
        function   => 'TIME_SERIES_DAILY_ADJUSTED',
        symbol     => $symbol,
        outputsize => 'compact',
        apikey     => $self->{api_key},
    );

    my $res = $self->{ua}->get($uri);

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

1;

__END__

=head1 NAME

TechTradeASX::DataProvider::AlphaVantage - Alpha Vantage market data client

=head1 DESCRIPTION

Fetches adjusted daily time series data from Alpha Vantage for ASX symbols.
The provider expects an API key to be supplied either via constructor argument
or the C<ALPHAVANTAGE_API_KEY> environment variable.

=cut
