package TechTradeASX::Util::Stats;

use strict;
use warnings;

use Exporter qw(import);
use List::Util qw(sum min max);

our @EXPORT_OK = qw(mean highest lowest pct_change);

sub mean {
    my (@values) = @_;
    return unless @values;
    return sum(@values) / @values;
}

sub highest {
    my (@values) = @_;
    return unless @values;
    return max(@values);
}

sub lowest {
    my (@values) = @_;
    return unless @values;
    return min(@values);
}

sub pct_change {
    my ($old, $new) = @_;
    return unless defined $old && defined $new;
    return if $old == 0;
    return (($new - $old) / $old) * 100;
}

1;
