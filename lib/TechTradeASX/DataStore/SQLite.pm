package TechTradeASX::DataStore::SQLite;

use strict;
use warnings;

use DBI;
use File::Path qw(make_path);

sub new {
    my ($class, %args) = @_;

    my $db_file = $args{db_file} || $ENV{TECHTRADE_DB} || 'var/techtrade.db';
    _ensure_parent_dir($db_file);

    my $dbh = DBI->connect(
        "dbi:SQLite:dbname=$db_file",
        '',
        '',
        {
            RaiseError => 1,
            PrintError => 0,
            AutoCommit => 1,
            sqlite_unicode => 1,
        }
    );

    my $self = {
        db_file => $db_file,
        dbh     => $dbh,
    };

    return bless $self, $class;
}

sub dbh {
    my ($self) = @_;
    return $self->{dbh};
}

sub init_schema {
    my ($self) = @_;
    my $dbh = $self->dbh;

    $dbh->do(<<'SQL');
CREATE TABLE IF NOT EXISTS symbols (
    symbol      TEXT PRIMARY KEY,
    name        TEXT,
    sector      TEXT,
    active      INTEGER NOT NULL DEFAULT 1,
    created_at  TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
)
SQL

    $dbh->do(<<'SQL');
CREATE TABLE IF NOT EXISTS daily_prices (
    symbol          TEXT NOT NULL,
    date            TEXT NOT NULL,
    open            REAL,
    high            REAL,
    low             REAL,
    close           REAL NOT NULL,
    adjusted_close  REAL,
    volume          INTEGER,
    source          TEXT NOT NULL,
    created_at      TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (symbol, date)
)
SQL

    $dbh->do(<<'SQL');
CREATE INDEX IF NOT EXISTS idx_daily_prices_symbol_date
ON daily_prices(symbol, date)
SQL

    $dbh->do(<<'SQL');
CREATE TABLE IF NOT EXISTS backtest_runs (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    name            TEXT NOT NULL,
    strategy        TEXT NOT NULL,
    started_at      TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    starting_cash   REAL NOT NULL,
    final_equity    REAL,
    total_return    REAL,
    max_drawdown    REAL,
    trade_count     INTEGER,
    notes           TEXT
)
SQL

    $dbh->do(<<'SQL');
CREATE TABLE IF NOT EXISTS backtest_trades (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id          INTEGER NOT NULL,
    symbol          TEXT NOT NULL,
    entry_date      TEXT NOT NULL,
    entry_price     REAL NOT NULL,
    exit_date       TEXT,
    exit_price      REAL,
    shares          INTEGER NOT NULL,
    stop_price      REAL,
    pnl             REAL,
    pnl_pct         REAL,
    entry_reason    TEXT,
    exit_reason     TEXT,
    FOREIGN KEY(run_id) REFERENCES backtest_runs(id)
)
SQL

    return 1;
}

sub upsert_symbol {
    my ($self, %args) = @_;

    die "symbol required\n" unless $args{symbol};

    $self->dbh->do(
        <<'SQL', undef,
        $args{symbol}, $args{name}, $args{sector}, defined $args{active} ? $args{active} : 1,
        $args{name}, $args{sector}, defined $args{active} ? $args{active} : 1,
    );
INSERT INTO symbols(symbol, name, sector, active)
VALUES (?, ?, ?, ?)
ON CONFLICT(symbol) DO UPDATE SET
    name = COALESCE(?, symbols.name),
    sector = COALESCE(?, symbols.sector),
    active = ?,
    updated_at = CURRENT_TIMESTAMP
SQL

    return 1;
}

sub upsert_daily_price {
    my ($self, %args) = @_;

    die "symbol required\n" unless $args{symbol};
    die "date required\n"   unless $args{date};
    die "close required\n"  unless defined $args{close};

    $self->dbh->do(
        <<'SQL', undef,
        @args{qw(symbol date open high low close adjusted_close volume source)},
        @args{qw(open high low close adjusted_close volume source)},
    );
INSERT INTO daily_prices(symbol, date, open, high, low, close, adjusted_close, volume, source)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(symbol, date) DO UPDATE SET
    open = ?,
    high = ?,
    low = ?,
    close = ?,
    adjusted_close = ?,
    volume = ?,
    source = ?
SQL

    return 1;
}

sub store_alpha_vantage_series {
    my ($self, $symbol, $series) = @_;

    die "symbol required\n" unless $symbol;
    die "series hash required\n" unless ref $series eq 'HASH';

    $self->upsert_symbol(symbol => $symbol);

    my $count = 0;

    for my $date (sort keys %{$series}) {
        my $row = $series->{$date};
        next unless ref $row eq 'HASH';
        next unless defined $row->{'4. close'};

        $self->upsert_daily_price(
            symbol         => $symbol,
            date           => $date,
            open           => _num($row->{'1. open'}),
            high           => _num($row->{'2. high'}),
            low            => _num($row->{'3. low'}),
            close          => _num($row->{'4. close'}),
            adjusted_close => _num($row->{'5. adjusted close'}),
            volume         => defined $row->{'6. volume'} ? int($row->{'6. volume'}) : undef,
            source         => 'alphavantage',
        );

        $count++;
    }

    return $count;
}

sub get_daily_prices {
    my ($self, %args) = @_;

    die "symbol required\n" unless $args{symbol};

    my @bind = ($args{symbol});
    my $sql = <<'SQL';
SELECT symbol, date, open, high, low, close, adjusted_close, volume, source
FROM daily_prices
WHERE symbol = ?
SQL

    if ($args{from}) {
        $sql .= " AND date >= ?";
        push @bind, $args{from};
    }

    if ($args{to}) {
        $sql .= " AND date <= ?";
        push @bind, $args{to};
    }

    $sql .= " ORDER BY date ASC";

    my $sth = $self->dbh->prepare($sql);
    $sth->execute(@bind);

    my @rows;
    while (my $row = $sth->fetchrow_hashref) {
        push @rows, $row;
    }

    return @rows;
}

sub list_symbols {
    my ($self) = @_;

    my $sth = $self->dbh->prepare('SELECT symbol FROM symbols WHERE active = 1 ORDER BY symbol');
    $sth->execute;

    my @symbols;
    while (my ($symbol) = $sth->fetchrow_array) {
        push @symbols, $symbol;
    }

    return @symbols;
}

sub create_backtest_run {
    my ($self, %args) = @_;

    $self->dbh->do(
        <<'SQL', undef,
        $args{name} || 'Backtest',
        $args{strategy} || 'unknown',
        $args{starting_cash} || 0,
        $args{notes},
    );
INSERT INTO backtest_runs(name, strategy, starting_cash, notes)
VALUES (?, ?, ?, ?)
SQL

    return $self->dbh->sqlite_last_insert_rowid;
}

sub update_backtest_run {
    my ($self, %args) = @_;

    die "run id required\n" unless $args{id};

    $self->dbh->do(
        <<'SQL', undef,
        $args{final_equity}, $args{total_return}, $args{max_drawdown}, $args{trade_count}, $args{id},
    );
UPDATE backtest_runs
SET final_equity = ?, total_return = ?, max_drawdown = ?, trade_count = ?
WHERE id = ?
SQL

    return 1;
}

sub insert_backtest_trade {
    my ($self, %args) = @_;

    $self->dbh->do(
        <<'SQL', undef,
        @args{qw(run_id symbol entry_date entry_price exit_date exit_price shares stop_price pnl pnl_pct entry_reason exit_reason)},
    );
INSERT INTO backtest_trades(
    run_id, symbol, entry_date, entry_price, exit_date, exit_price, shares,
    stop_price, pnl, pnl_pct, entry_reason, exit_reason
)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
SQL

    return 1;
}

sub _ensure_parent_dir {
    my ($file) = @_;

    if ($file =~ m{^(.+)/[^/]+$}) {
        make_path($1) unless -d $1;
    }
}

sub _num {
    my ($value) = @_;
    return undef unless defined $value;
    return $value + 0;
}

1;

__END__

=head1 NAME

TechTradeASX::DataStore::SQLite - SQLite persistence for TechTrade ASX

=head1 DESCRIPTION

Stores symbols, daily OHLCV data and backtest results in a local SQLite database.

=cut
