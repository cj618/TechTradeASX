# TECHTRADE ASX

TechTrade ASX is a Perl-based technical analysis tool for Australian Securities Exchange securities.

This is an experimental trading research tool. It is not financial advice, and it does not guarantee profitable trading.

## Current features

- Downloads daily adjusted price data from Alpha Vantage
- Reads ASX symbols from `data/symbols.txt`
- Calculates simple support and resistance from the last 90 trading days
- Suggests a basic BUY / SELL / HOLD signal based on proximity to support and resistance
- Writes results to `output/signals.csv`

## Requirements

Perl 5 with the following modules:

- File::Path
- JSON
- List::Util
- LWP::UserAgent
- Text::CSV
- URI

These can usually be installed through CPAN or your operating system package manager.

## Setup

Get an Alpha Vantage API key and export it in your shell:

```sh
export ALPHAVANTAGE_API_KEY="your_key_here"
```

Then run:

```sh
perl TT.pl
```

The output will be written to:

```text
output/signals.csv
```

## Symbols

Edit:

```text
data/symbols.txt
```

Example:

```text
CBA.AX
BHP.AX
WES.AX
CSL.AX
TLS.AX
```

Blank lines and comments are ignored. Symbols may be listed one per line or separated by whitespace.

## Optional environment variables

```sh
export TECHTRADE_SYMBOL_FILE="data/symbols.txt"
export TECHTRADE_OUTPUT_FILE="output/signals.csv"
export TECHTRADE_THRESHOLD_PCT="5"
export TECHTRADE_DAYS="90"
```

## Current limitations

The current strategy is intentionally simple. A stock being near a 90-day low is not automatically a good buying opportunity. It may be a falling knife.

Future versions should include trend filters, volatility filters, liquidity checks, brokerage, slippage, backtesting, paper trading and position sizing.

## Development direction

The next major step is to split the single script into reusable Perl modules and add tests. Suggested early modules:

```text
lib/TechTradeASX/Symbols.pm
lib/TechTradeASX/DataProvider/AlphaVantage.pm
lib/TechTradeASX/Indicators.pm
lib/TechTradeASX/Signal.pm
```

Suggested early tests:

```text
t/001_symbols.t
t/002_support_resistance.t
t/003_signal_logic.t
t/004_alpha_vantage_parse.t
```
