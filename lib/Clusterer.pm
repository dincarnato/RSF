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

package Clusterer;

use strict;
use Carp;

sub new {
    
    my $class = shift;
    my %parameters = @_ if (@_);
    
    croak "\n  [!] Error: Distance must be comprised between 0 and 1 -> Caught" if ($parameters{distance} < 0 ||
                                                                                    $parameters{distance} > 1);
    
    my $self = { distance => $parameters{distance} || 0.5 };
    
    bless($self, $class);
    
    return($self);
    
}

sub cluster {
    
    my $self = shift;
    my $structures = shift;
    
    my (@clusters);
    
    croak "\n  [!] Error: cluster() method requires a reference to an array of structures -> Caught" if (!defined $structures ||
                                                                                                         ref($structures) ne "ARRAY");

    foreach my $structure (@{$structures}) {

        my $id = $self->_issimilar($structure, \@clusters);

        if (defined $id) { push(@{$clusters[$id]}, \$structure); }
        else { push(@clusters, [\$structure]); }
    
    }
    
    foreach my $cluster (@clusters) { $_ = ${$_} for (@{$cluster}); }

    return(wantarray() ? @clusters : \@clusters);
    
}

sub _issimilar {
    
    my $self = shift;
    my ($structure, $clusters) = @_;

    foreach my $i (0 .. $#$clusters) {
        
        my $distance = $self->_distance(\$structure, $clusters->[$i][0]);

        return($i) if ($distance < $self->{distance});
        
    }

    return();
    
}

sub _distance {
    
    my $self = shift;
    
    my ($distance, @structures);
    @structures = map { $$_ } @_;
    $distance = _hd(@structures);
    
    croak "\n  [!] Error: Unable to compute distance for structures -> Caught" if (!defined $distance);

    $distance /= length($structures[0]);

    return($distance);
    
}

sub _hd { return ($_[0] ^ $_[1]) =~ tr/\001-\255//; }

1;