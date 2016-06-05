#!/usr/bin/perl

##
# Chimaera Framework
# Epigenetics Unit @ HuGeF [Human Genetics Foundation]
#
# Author:  Danny Incarnato (danny.incarnato[at]hugef-torino.org)
#
# This program is free software, and can be redistribute  and/or modified
# under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# Please see <http://www.gnu.org/licenses/> for more informations.
##

package Core::Mathematics;

use strict;
use POSIX;
use Core::Utils;

use constant e    => exp(1);
use constant pi   => 4 * atan2(1, 1);
use constant inf  => 0 + q{Inf};
use constant pinf => inf;
use constant ninf => -(inf);
use constant nan  => 0 + q{NaN};

use base qw(Exporter);

our @EXPORT = qw(isint isfloat isexp isinf
                 isnan isnumeric ispositive isnegative
                 isreal);

our %EXPORT_TAGS = ( constants => [ qw(e pi inf pinf ninf nan) ],
                     functions => [ qw(logarithm min max mean
                                       average geomean midrange stdev
                                       mode median round sum
                                       product maprange) ] );

{ my (%seen);
  push(@{$EXPORT_TAGS{$_}}, @EXPORT) foreach (keys %EXPORT_TAGS);
  push(@{$EXPORT_TAGS{all}}, grep {!$seen{$_}++} @{$EXPORT_TAGS{$_}}) foreach (keys %EXPORT_TAGS); }

our @EXPORT_OK = ( @{$EXPORT_TAGS{constants}},
                   @{$EXPORT_TAGS{functions}} );

sub isint {

    my @values = @_;
    
    for (@values) { return if (!isreal($_) ||
                               int($_) != $_); }
    
    return(1);
    
}

sub isfloat {
    
    my @values = @_;
    
    for (@values) { return if (!isreal($_) ||
                               int($_) == $_); }
    
    return(1);
    
}

sub isinf {
    
    my @values = @_;
    
    for (@values) { return if ($_ !~ m/^[+-]?Inf$/i); }
    
    return(1);
    
}

sub isnan {
    
    my @values = @_;
    
    for (@values) { return if ($_ !~ m/^[+-]?NaN?$/i); }
    
    return(1);
    
}

sub isreal {
    
    my @values = @_;
    
    for (@values) { return if ($_ !~ m/^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/); }
    
    return(1);
    
}

sub isnumeric {
    
    my @values = @_;
    
    for (@values) { return if (!isreal($_) &&
                               !isinf($_)); }
    
    return(1);
    
}

sub ispositive {
    
    my @values = @_;
    
    for (@values) { return if (!isnumeric($_) ||
                               $_ < 0); }
    
    return(1);
    
}

sub isnegative {
    
    my @values = @_;
    
    for (@values) { return if (!isnumeric($_) ||
                               $_ >= 0); }
    
    return(1);
    
}

sub ispercentage {
    
    my @values = @_;
    
    for (@values) {
        
        return unless ($_ =~ m/\%$/);
        
        $_ =~ s/\%$//;
            
        return if (!isreal($_) ||
                   isnegative($_) ||
                   $_ > 100);
            
            
    }
    
    return(1);
    
}

sub percentage2frequency {
    
    my @values = @_;
    
    for (@values) {
        
        return unless (ispercentage($_));
        
        $_ =~ s/\%$//;
        $_ /= 100;
        
    }
    
    return(@values);
    
}

sub logarithm {

    my $argument = shift;
    my $base = shift // e;
    
    Core::Utils::throw("Logarithm argument is not numeric") if (!isnumeric($argument));
    Core::Utils::throw("Invalid logarithm base") if (!isnumeric($base));
    
    return(inf) if ($base == 1);
    return(inf) if ($argument == 0);
    return(nan) if (isnegative($argument) ||
                    isnegative($base));
    
    return(log($argument) / ($base ? log($base) : ninf));
    
}

sub min {
    
    my @values = @_;
    
    Core::Utils::throw("Values array is empty") if (!@values);
    Core::Utils::throw("Values must be numeric") if (!isnumeric(@values));
    
    @values = sort {$a <=> $b} @values;

    return(shift(@values));
    
    
}

sub max {
    
    my @values = @_;
    
    Core::Utils::throw("Values array is empty") if (!@values);
    Core::Utils::throw("Values must be numeric") if (!isnumeric(@values));
    
    @values = sort {$a <=> $b} @values;

    return(pop(@values));
    
}

sub average {
    
    my @values = @_;
    
    my ($avg);
    
    Core::Utils::throw("Values array is empty") if (!@values);
    Core::Utils::throw("Values must be numeric") if (!isnumeric(@values));
    
    return($values[0]) if (@values == 1);
    
    $avg += $_ for (@values);
    $avg /= @values;
    
    return($avg);
    
}

sub mean { return(average(@_)); }

sub geomean {
    
    my @values = @_;
    
    my ($avg);
    
    Core::Utils::throw("Values array is empty") if (!@values);
    Core::Utils::throw("Values must be positive numbers") if (!ispositive(@values));
    
    return($values[0]) if (@values == 1);
    
    $_ = logarithm($_) for (@values);
    $avg  = exp(mean(@values));
    
    return($avg);
    
}

sub midrange {
    
    my @values = @_;
    
    Core::Utils::throw("Values array is empty") if (!@values);
    Core::Utils::throw("Values must be numeric") if (!isnumeric(@values));
    
    return((max(@values) + min(@values)) / 2);
    
}

sub stdev {
    
    my @values = @_;
    
    my ($avg, $sq, $stdev);
    $sq = 0;
    
    Core::Utils::throw("Values array is empty") if (!@values);
    Core::Utils::throw("Values must be numeric") if (!isnumeric(@values));
    
    return(0) if (@values == 1);
    
    $avg = mean(@values);
    $sq += ($avg - $_) ** 2 for (@values);
    $stdev = sqrt($sq / @values);
    
    return($stdev);
    
}

sub mode {
    
    my @values = @_;
    
    my (%counts);
    
    Core::Utils::throw("Values array is empty") if (!@values);
    Core::Utils::throw("Values must be numeric") if (!isnumeric(@values));
    
    return($values[0]) if (@values == 1);
    
    $counts{$_}++ for (@values);
    @values = sort {$counts{$b} <=> $counts{$a}} keys %counts;
    
    return(shift(@values));
    
}

sub median {
    
    my @values = @_;
    
    Core::Utils::throw("Values array is empty") if (!@values);
    Core::Utils::throw("Values must be numeric") if (!isnumeric(@values));
    
    return $values[0] if (@values == 1);
    
    @values = sort {$a <=> $b} @values;
    
    if (@values % 2) { return($values[int(@values / 2)]); }
    else { return(mean($values[(@values / 2) - 1], $values[(@values / 2)])); }
    
}

sub round {
    
    my $value = shift;
    
    Core::Utils::throw("No value has been provided") if (!$value);
    Core::Utils::throw("Value must be a real number") if (!isreal($value));
    
    my $int = floor($value);
    
    if ($value >= ($int + 0.5)) { return(ceil($value)); }
    else { return($int); }
    
}

sub sum {
    
    my @values = @_;
    
    Core::Utils::throw("Values array is empty") if (!@values);
    Core::Utils::throw("Values must be numeric") if (!isnumeric(@values));
    
    my ($sum);
    
    $sum += $_ for (@values);
    
    return($sum);
    
}

sub product {
    
    my @values = @_;
    
    Core::Utils::throw("Values array is empty") if (!@values);
    Core::Utils::throw("Values must be numeric") if (!isnumeric(@values));
    
    my ($product);
    
    $product *= $_ for (@values);
    
    return($product);
    
}

sub maprange {

    my ($oldmin, $oldmax, $newmin, $newmax, $value) = @_;
    
    Core::Utils::throw("Invalid old range boundaries (old minimum is equal to old maximum)") if ($oldmin == $oldmax);
    Core::Utils::throw("Invalid new range boundaries (new minimum is equal to new maximum)") if ($newmin == $newmax);
    
    return(((($value - $oldmin) * ($newmax - $newmin)) / ($oldmax - $oldmin)) + $newmin);

}
               
1;
