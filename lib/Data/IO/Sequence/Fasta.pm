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

package Data::IO::Sequence::Fasta;

use strict;
use Carp;
use Core::Utils;
use Data::Sequence;
use Data::Sequence::Utils;

use base qw(Data::IO::Sequence);

sub read {
    
    my $self = shift;
    
    my ($fh, $stream, $header, $id,
        $description, $gi, $accession, $version,
        $sequence, $object);
    
    $self->throw("Filehandle isn't in read mode") unless ($self->mode() eq "r");
    
    $fh = $self->{_fh};
    
    if (eof($fh)) {
        
        $self->reset() if ($self->{autoreset});
        
        return;
        
    }
    
    local $/ = "\n>";
    $stream = <$fh>;
    
    foreach my $line (split(/\n/, $stream)) {
        
        next if ($line =~ m/^\s*$/ ||
                 $line =~ m/^#/);
        
        if (!defined $header) {
            
            $header = $line;
            $header =~ s/^>//;
            $header = striptags($header);
            
            next;
            
        }
        
        $sequence .= $line;
        
    }
    
    if ($header =~ m/^\s*?(\S+)\s+?(.+)$/) {
        
        ($id, $description) = ($1, $2);
        $id = $description unless ($id);
    
    }
    else { $id = $header; }
    
    if ($id =~ m/gi\|(\d+)\|/) { $gi = $1; }
    if ($id =~ m/ref\|([\w\.]+)\|/) {
        
        $accession = $1;
        
        if ($accession =~ m/\.(\w+)$/) {
            
            $version = $1;
            $accession =~ s/\.$version$//;
            
        }
        
    }
    
    $sequence = striptags($sequence);
    $sequence =~ s/[\s\r>]//g;
    
    return($self->read()) if (!defined $sequence ||
                              !isseq($sequence, "-"));
    
    $object = Data::Sequence->new( id          => $id,
                                   name        => $header,
                                   gi          => $gi,
                                   accession   => $accession,
                                   version     => $version,
                                   sequence    => $sequence,
                                   description => $description );
    
    return($object);
    
}

sub write {
    
    my $self = shift;
    my @sequences = @_ if (@_);
    
    $self->throw("Filehandle isn't in write/append mode") unless ($self->{mode} =~ m/^w\+?$/);
    
    for(my $i=0;$i<@sequences;$i++) {
    
        if (!blessed($sequences[$i]) ||
            !$sequences[$i]->isa("Data::Sequence")) {
            
            $self->warn("Method requires a valid Data::Sequence object");
            
            next;
            
        }
    
        my ($fh, $id, $sequence);
        $fh = $self->{_fh};
        $sequence = $sequences[$i]->sequence();
    
        if (!defined $sequence) {
            
            $self->warn("Empty Data::Sequence object");
            
            next;
            
        }
    
        $self->{_lastid} = 1 unless($self->{_lastid});
    
        if (!defined $sequences[$i]->id()) {
        
            if (defined $sequences[$i]->gi()) {
            
                $id = "gi|" . $sequences[$i]->gi();
                $id .= "|ref|" . $sequences[$i]->accession() if defined($sequences[$i]->accession());
                $id .= "." . $sequences[$i]->version() if defined($sequences[$i]->version() &&
                                                                  $sequences[$i]->accession !~ m/\.\w+$/);
            
            }
            else {
            
                $id = "Sequence_" . $self->{_lastid};
                $self->{_lastid}++;
            
            }
        
        }
        else { $id = $sequences[$i]->id(); }
    
        $id .= " " . $sequences[$i]->description() if defined($sequences[$i]->description());
        $sequence =~ s/(\w{60})/$1\n/g;
    
        print $fh ">" . $id . "\n" .
                  $sequence . "\n\n";
              
        $self->flush();
        
    }
    
}

1;