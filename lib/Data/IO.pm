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

package Data::IO;

use strict;
use Fcntl qw(SEEK_SET);
use LWP::UserAgent;
use Core::Mathematics;
use Core::Utils;

use base qw(Core::Base);

sub new {
    
    my $class = shift;
    my %parameters = @_ if (@_);
    
    my $self = $class->SUPER::new(%parameters);
    $self->_init({ file      => undef,
                   data      => undef,
                   mode      => "r",
                   flush     => 0,
                   autoreset => 0,
                   timeout   => 10,
                   retries   => 3,
                   _prev     => [],
                   _fh       => undef }, \%parameters);
    
    $self->_checkfile();
    $self->flush($self->{flush});
    
    return($self);
    
}

sub _validate {
    
    my $self = shift;
    
    $self->{mode} = lc($self->{mode});
    
    $self->throw("Invalid mode \"" . $self->{mode} . "\"") unless ($self->{mode} =~ m/^(r|w\+?)$/i);
    $self->throw("No file or data provided") if ($self->{mode} =~ m/^r$/i &&
                                                 !defined $self->{file} &&
                                                 !defined $self->{data});
    $self->throw("No output file has been specified") if ($self->{mode} =~ m/^w\+?$/i &&
                                                          !defined $self->{file});
    $self->throw("Flush parameter's allowed values are 0 or 1") if ($self->{mode} =~ m/^w\+?$/i &&
                                                                    $self->{flush} !~ m/^[01]$/);
    $self->throw("Timeout parameter must be an integer greater than 0") if (!isint($self->{timeout}) &&
                                                                            $self->{timeout} <= 0);
    $self->throw("Retries parameter must be an integer greater than 0") if (!isint($self->{retries}) &&
                                                                            $self->{retries} <= 0);
    
}

sub _checkfile {
    
    my $self = shift;
    
    my ($file, $data);
    $file = $self->{file};
    $data = $self->{data};
    $self->{mode} = "w" if ($self->{mode} eq "w+" &&
                            ref($self) eq "Data::IO::Sequence::2bit");
    
    if ($self->{mode} eq "r") {
        
        if (defined $data) { $self->{data} = \$data; }
        else {
            
            if ($file =~ m/^(https?|ftp):\/\//) {
                
                for (1 .. $self->{retries}) {
            
                    my ($useragent, $reply);
                    $useragent = LWP::UserAgent->new( agent   => "Chimaera",
                                                      timeout => $self->{timeout} );
                    $reply = $useragent->get($file);
                        
                    if (!$reply->is_success()) { $self->warn($reply->status_line()); }
                    else {
                        
                        $data = $reply->content();
                    
                        last;
                        
                    }
                
                }
                
                if (defined $data) { $self->{data} = \$data; }
                else { $self->throw("Unable to retrieve data file after " . $self->{retries} . " attemps"); }
                    
            }
            else {
                    
                $self->throw("Provided file \"" . $file . "\" doesn't exist") unless (-e $file);
                $self->{data} = $file;
                    
            }
            
        }
            
    }
    elsif ($self->{mode} eq "w") {
        
        if (-e $file) {
            
            if (questionyn("Provided file already exists.\nAppend data to file")) { $self->{mode} = "w+"; }
            else {
                
                if (questionyn("Overwrite file", "n")) {
                    
                    unlink($file) or $self->throw("Provided file isn't writeable");
                    
                    open(my $fh, ">" . $file);
                    close($fh);
                    
                    $self->{mode} = "w+";
                    
                }
                else { $self->throw("Unable to write to output file \"" . $file . "\""); }
                
            }
        
        }
        
    }
    
}

sub _openfh {
    
    my $self = shift;
    
    my $mode = $self->{mode};
    $self->{data} = $self->{file} if ($mode =~ m/w/);
    $mode =~ tr/rw+/<>>/;
        
    open(my $fh, $mode, $self->{data}) or $self->throw($!);
        
    $self->{_fh} = $fh;
    
}

sub read {
    
    my $self = shift;
    
    $self->throw("Unable to call method on a generic object");
    
}

sub write {
    
    my $self = shift;
    
    $self->throw("Unable to call method on a generic object");
    
}

sub back {
    
    my $self = shift;
    my $index = @_ ? shift : 0;
    
    $self->throw("Backward index must be a positive integer") unless (isint($index) &&
                                                                      ispositive($index));
    
    if (ref($self) =~ m/^Data::IO::(?:Track|Sequence)::\w+$/) {
        
        splice(@{$self->{_prev}}, (@{$self->{_prev}} - $index), $index);
        
        push(@{$self->{_prev}}, 0) unless (@{$self->{_prev}});
        seek($self->{_fh}, pop(@{$self->{_prev}}), SEEK_SET);
        
    }
    else { $self->throw("Unable to call method on a generic object"); }
    
}

sub mode {
    
    my $self = shift;
    
    return($self->{mode});
    
}

sub format {
    
    my $self = shift;
    
    return($self->{format});
    
}

sub file {
    
    my $self = shift;
    
    return($self->{file});
    
}

sub flush {
    
    my $self = shift;
    my $flush = shift if (@_);
    
    $self->{flush} = $flush if ($flush =~ m/^[01]$/);
    
    if (defined $self->{_fh}) { select((select($self->{_fh}), $| = 1)[0]) if ($self->{flush} &&
                                                                              fileno($self->{_fh}) &&
                                                                              $self->mode() ne "r"); }
    
}

sub reset {
    
    my $self = shift;
    
    seek($self->{_fh}, 0, 0) if (fileno($self->{_fh}));
    
}

sub DESTROY {
    
    my $self = shift;
    
    delete($self->{file});
    delete($self->{data});
    
    if (defined $self->{_fh}) { close($self->{_fh}) if (fileno($self->{_fh})); }
    
}

1;