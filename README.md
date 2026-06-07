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
- Provides a SQLite datastore for symbols, daily prices and backtest result tables
- Provides a basic position sizing helper for risk-based trade sizing

## Requirements

Perl 5 with the following modules:

- DBI
- DBD::SQLite
- File::Path
- File::Temp, for the datastore test
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

## Local database

Initialise the local SQLite database with:

```sh
perl tools/initdb
```

By default this creates:

```text
var/techtrade.db
```

To use a different database path:

```sh
export TECHTRADE_DB="var/other.db"
perl tools/initdb
```

## Running tests

Run the initial test suite with:

```sh
prove -l t
```

The tests currently cover symbol parsing, the baseline range signal logic and the SQLite datastore.

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
export TECHTRADE_DB="var/techtrade.db"
```

## Current module layout

```text
TT.pl
lib/TechTradeASX/Symbols.pm
lib/TechTradeASX/DataProvider/AlphaVantage.pm
lib/TechTradeASX/DataStore/SQLite.pm
lib/TechTradeASX/Range.pm
lib/TechTradeASX/Risk.pm
lib/TechTradeASX/Util/Stats.pm
t/001_symbols.t
t/002_range.t
t/003_datastore.t
tools/initdb
```

`TT.pl` remains the command-line entry point. The reusable code now lives in modules so the project can grow into a more serious research platform without turning the script into an unmaintainable pile.

## Current limitations

The current strategy is intentionally simple. A stock being near a 90-day low is not automatically a good buying opportunity. It may be a falling knife.

The datastore and risk modules are foundations for backtesting, but the project does not yet include a complete portfolio backtester, market-regime filter, reporting engine or paper-trading loop.

## Development direction

The next major development target is the backtesting layer:

```text
lib/TechTradeASX/Backtest.pm
lib/TechTradeASX/Strategy/RangeReversion.pm
lib/TechTradeASX/Report/CSV.pm
script/fetch-history.pl
script/backtest.pl
```

The backtester should use the SQLite price cache, apply brokerage and slippage, record trades into the datastore, and compare results against a benchmark such as STW.AX or IOZ.AX.
