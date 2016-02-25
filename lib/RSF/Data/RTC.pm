package RSF::Data::RTC;

use strict;
use Core::Mathematics qw(:all);
use Data::Sequence::Utils;

use base qw(Core::Base);

sub new {
    
    my $class = shift;
    my %parameters = @_ if (@_);
    
    my $self = $class->SUPER::new(%parameters);
    $self->_init({ id       => undef,
                   sequence => undef,
                   rtstops  => [],
                   coverage => [] }, \%parameters);
    
    $self->_validate();
    $self->{sequence} = uc(rna2dna($self->{sequence})) if (defined $self->{sequence});
    
    return($self);
    
}

sub _validate {
    
    my $self = shift;

    $self->throw("Sequence contains invalid characters") if (defined $self->{sequence} &&
                                                             !isna($self->{sequence}));
    $self->throw("RT-stops must be provided as an ARRAY reference") if (ref($self->{rtstops}) ne "ARRAY");
    $self->throw("Coverage must be provided as an ARRAY reference") if (ref($self->{coverage}) ne "ARRAY");
    $self->throw("Different number of elements for RT-stops and coverage arrays") if (@{$self->{rtstops}} != @{$self->{coverage}});
    $self->throw("Number of elements for RT-stops and coverage arrays differs from sequence length") if (@{$self->{rtstops}} != length($self->{sequence}));
    
}

sub id { return($_[0]->{id}); }

sub sequence { return($_[0]->{sequence}); }

sub rtstops { return(wantarray() ? @{$_[0]->{rtstops}} : $_[0]->{rtstops}); }

sub coverage { return(wantarray() ? @{$_[0]->{coverage}} : $_[0]->{coverage}); }

sub meancoverage { return(mean(@{$_[0]->{coverage}})); }

sub mediancoverage { return(median(@{$_[0]->{coverage}})); }

sub length { return(length($_[0]->{sequence})); }

sub DESTROY {
    
    my $self = shift;
    
    delete($self->{sequence});
    delete($self->{rtstops});
    delete($self->{coverage});
    
}

1;
