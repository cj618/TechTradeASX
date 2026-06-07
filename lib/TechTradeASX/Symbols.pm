package TechTradeASX::Symbols;

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = qw(read_symbols_from_file read_symbols_from_string);

sub read_symbols_from_file {
    my ($file) = @_;

    open my $fh, '<', $file
        or die "Cannot open $file: $!\n";

    local $/;
    my $content = <$fh>;
    close $fh;

    return read_symbols_from_string($content);
}

sub read_symbols_from_string {
    my ($content) = @_;

    return unless defined $content;

    my @symbols;

    for my $line (split /\n/, $content) {
        $line =~ s/#.*$//;       # allow shell-style comments
        $line =~ s/^\s+//;
        $line =~ s/\s+$//;
        next unless length $line;

        push @symbols, split /\s+/, $line;
    }

    return @symbols;
}

1;

__END__

=head1 NAME

TechTradeASX::Symbols - symbol file parsing for TechTrade ASX

=head1 DESCRIPTION

Reads ASX symbols from text files. Symbols may be listed one per line or
separated by whitespace. Blank lines and comments beginning with C<#> are
ignored.

=cut
