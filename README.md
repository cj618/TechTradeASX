# TECHTRADE ASX

TechTrade ASX is a Perl-based technical analysis tool for Australian Securities Exchange securities.

This is an experimental trading research tool. It is not financial advice, and it does not guarantee profitable trading.

## Current features

- Downloads daily adjusted price data from Alpha Vantage
- Reads ASX symbols from `data/symbols.txt`
- Calculates simple support and resistance from the last 90 trading days
- Suggests a basic BUY / SELL / HOLD signal based on proximity to support and resistance
- Writes results to `output/signals.csv`
- Keeps the main script small by using reusable modules under `lib/TechTradeASX/`
- Includes initial regression tests under `t/`

## Requirements

Perl 5 with the following modules:

- File::Path
- JSON
- List::Util
- LWP::UserAgent
- Text::CSV
- URI
- Test::More, for running the test suite

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

## Running tests

Run the initial test suite with:

```sh
prove -l t
```

The tests currently cover symbol parsing and the baseline range signal logic.

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

## Current module layout

```text
TT.pl
lib/TechTradeASX/Symbols.pm
lib/TechTradeASX/DataProvider/AlphaVantage.pm
lib/TechTradeASX/Range.pm
t/001_symbols.t
t/002_range.t
```

`TT.pl` remains the command-line entry point. The reusable code now lives in modules so the project can grow into a more serious research platform without turning the script into an unmaintainable pile.

## Current limitations

The current strategy is intentionally simple. A stock being near a 90-day low is not automatically a good buying opportunity. It may be a falling knife.

Future versions should include trend filters, volatility filters, liquidity checks, brokerage, slippage, backtesting, paper trading and position sizing.

## Development direction

Suggested next modules:

```text
lib/TechTradeASX/Indicators.pm
lib/TechTradeASX/Strategy/RangeReversion.pm
lib/TechTradeASX/Risk.pm
lib/TechTradeASX/Report/CSV.pm
lib/TechTradeASX/DataStore/SQLite.pm
```

Suggested next tests:

```text
t/003_indicators.t
t/004_alpha_vantage_parse.t
t/005_risk.t
t/006_csv_report.t
```
