package RSF::Data::IO::RTC;

use strict;
use Fcntl qw(SEEK_SET SEEK_END);
use RSF::Data::RTC;

use base qw(Data::IO);

our (%bases);

BEGIN {
    
    my $i = 5;
    %bases = map { --$i => $_ } qw(N T G C A);
    
}

sub new {
    
    my $class = shift;
    my %parameters = @_ if (@_);
    
    my $self = $class->SUPER::new(%parameters);
    $self->_init({ index      => undef,
                   buildindex => 0,
                   _offsets   => {} }, \%parameters);
    
    $self->_openfh();
    
    binmode($self->{_fh});
    
    $self->_validate();
    $self->_loadindex();
        
    return($self);
    
}

sub _validate {
    
    my $self = shift;

    my ($fh, $eof);
    $fh = $self->{_fh};
    
    $self->SUPER::_validate();
    
    seek($fh, -8, SEEK_END);
    read($fh, $eof, 8);

    $self->throw("Invalid RTC file (EOF marker is absent)") unless ($eof eq "\x5b\x65\x6f\x66\x72\x74\x63\x5d");
    
    $self->reset();
    
    $self->{index} = $self->{file} . ".rti" if ($self->{buildindex} &&
                                                defined $self->{file} &&
                                                !defined $self->{index});
    
}

sub _loadindex {
    
    my $self = shift;
    
    my $fh = $self->{_fh};
        
    if (-e $self->{index}) {
    
        my ($data, $idlen, $id, $offset);
        
        open(my $ih, "<:raw", $self->{index}) or $self->throw("Unable to read from RTI index file (" . $! . ")");
        while(!eof($ih)) {
            
            read($ih, $data, 4);
            $idlen = unpack("L<", $data);

            read($ih, $data, $idlen);
            $id = substr($data, 0, -1); # Removes the "\x00" string terminator

            read($ih, $data, 4);
            $offset = unpack("L<", $data);
            $self->{_offsets}->{$id} = $offset; # Stores the offset for ID
            
            # Validates offset
            seek($fh, $offset + 4, SEEK_SET);
            read($fh, $data, $idlen);
            
            $self->throw("Invalid offset in RTI index file for transcript \"" . $id . "\"") if (substr($data, 0, -1) ne $id);
            
        }
        close($ih);
    
    }
    elsif ($self->{buildindex}) { # Builds missing index
        
        my ($data, $offset, $idlen, $id,
            $length);
        $offset = 0;
        
        while($offset < (-s $self->{file}) - 8) { # While the 8 bytes of EOF Marker are reached
            
            read($fh, $data, 4);
            $idlen = unpack("L<", $data);
               
            read($fh, $data, $idlen);    
            $id = substr($data, 0, -1); # Removes the "\x00" string terminator
                       
            read($fh, $data, 4);
            $length = unpack("L<", $data);
            
            $self->{_offsets}->{$id} = $offset;
            
            $offset += 4 * ($length * 2 + 2) + length($id) + 1 + ($length + ($length % 2)) / 2;
            
            seek($fh, $offset, SEEK_SET); 
            
        }
        
        if (defined $self->{index}) {
            
            open(my $ih, ">:raw", $self->{index}) or $self->throw("Unable to write RTI index file (" . $! . ")");
            select((select($ih), $|=1)[0]);
            
            foreach my $id (keys %{$self->{_offsets}}) {
                
                print $ih pack("L<", length($id) + 1) .                 # len_transcript_id (int32_t)
                          $id . "\0" .                                  # transcript_id (char[len_transcript_id])
                          pack("L<", $self->{_offsets}->{$id});         # offset in count table (int32_t)
                
            }
         
            close($ih);
            
        }
        
    }
    
    $self->reset();
    
}

sub read {
    
    my $self = shift;
    my $seqid = shift if (@_);
    
    my ($fh, $data, $idlen, $id,
        $length, $sequence, $entry, $eightbytes,
        @stops, @coverage);
    
    $self->throw("Filehandle isn't in read mode") unless ($self->mode() eq "r");
    
    $fh = $self->{_fh};
    
    if (defined $seqid) {
        
        if (exists $self->{_offsets}->{$seqid}) {
            
            seek($fh, $self->{_offsets}->{$seqid}, SEEK_SET);
            
            # Re-build the prev array to allow ->back() call after seeking to a specific sequence
            my @prev = grep {$_ <= $self->{_offsets}->{$seqid}} sort {$a <=> $b} values %{$self->{_offsets}};
            $self->{_prev} = \@prev;
            
        }
        else { return; }
        
    }
    
    # Checks whether RTCEOF marker has been reached
    read($fh, $eightbytes, 8);
    seek($fh, tell($fh) - 8, SEEK_SET);
        
    if ($eightbytes eq "\x5b\x65\x6f\x66\x72\x74\x63\x5d") {
    
        $self->reset() if ($self->{autoreset});
    
        return;
    
    }
    
    push(@{$self->{_prev}}, tell($fh)) if (!defined $seqid);
    
    read($fh, $data, 4); #read id length
    $idlen = unpack("L<", $data);

    read($fh, $data, $idlen);
    $id = substr($data, 0, -1);

    read($fh, $data, 4);
    $length = unpack("L<", $data);

    for (0 .. ($length + ($length % 2)) / 2 - 1) {

        read($fh, $data, 1);
        
        foreach my $i (1, 0) { $sequence .= $bases{vec($data, $i, 4)}; }
        
    }

    $sequence = substr($sequence, 0, $length);

    read($fh, $data, 4 * $length);
    @stops = unpack("L<*", $data);

    read($fh, $data, 4 * $length);
    @coverage = unpack("L<*", $data);
    
    $entry = RSF::Data::RTC->new( id       => $id,
                                  sequence => $sequence,
                                  rtstops  => \@stops,
                                  coverage => \@coverage );
    
    return($entry);
    
}

sub ids {
    
    my $self = shift;
    
    my @ids = sort keys %{$self->{_offsets}};
    
    return(wantarray() ? @ids : \@ids);
           
}

1;