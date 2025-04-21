# TECHTRADE ASX

# This Perl-based tool analyzes ASX stock data to identify trading ranges and generate buy/sell signals.

## Features
- Downloads daily price data from Alpha Vantage
- Calculates support and resistance from the last 90 days
- Suggests BUY/SELL/HOLD based on proximity to support/resistance levels

## Setup

1. Install dependencies:
   - Perl modules: LWP::UserAgent, JSON, Text::CSV, List::Util

2. Get a free API key from [Alpha Vantage](https://www.alphavantage.co/support/#api-key)

3. Edit `asx_range_trader.pl` and insert your API key.

4. Run the script:
   ```bash
   perl asx_range_trader.pl
   ```

5. Output will be saved in `output/signals.csv`

## Example Stocks
Includes some sample ASX stocks in `data/symbols.txt`
