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

package Core::Utils;

use strict;
use Carp;
use Fcntl qw(F_GETFL SEEK_SET);
use File::Spec;
use Scalar::Util qw(reftype);
use Term::ReadKey;

use base qw(Exporter);

our @EXPORT = qw(is checkparameters blessed clonehashref
                 clonearrayref clonefh uriescape uriunescape
                 unquotemeta striptags questionyn uniq
                 randint randnum randalpha randalphanum
                 randmixed which);

sub uniq {
    
    my %seen = ();
    
    return(grep { !$seen{$_}++ } @_);

}

sub throw { croak _exception($_[0], $_[1] // $ENV{verbosity} // 0, 1); }

sub warn {

    my $verbosity = $_[1] // $ENV{verbosity} // 0;
    
    carp _exception($_[0], $verbosity, 0) if ($verbosity >= 0);
    
}

sub _exception {
    
    my $message = shift;
    my ($verbosity, $mode) = @_ if (@_);
    
    $message = "Undefined error" . ($verbosity == 1 ? "." : ". Increase verbosity level to 1 to get the complete stack trace-dump.") if (!defined $message);
    $message =~ s/(\n+?)/$1    /;
    
    my ($i, $dump, $package, $subroutine,
        @stack);
    $i = 2;
    
    while (my @caller = caller($i)) {
    
        unshift(@stack, \@caller);
        $dump = $caller[3] if ($caller[3] ne "(eval)");    
        $i++;
    
    }
    
    $dump =~ m/^([\w:]+?)::(\w+)$/;
    ($package, $subroutine) = ($1, $2);
    $message = "\n[!] " . ($mode ? "Exception" : "Warning") . (defined $dump ? " [" . $package . "->" . $subroutine . "()]:\n" : ":\n") . "    " . $message;

    if ($verbosity == 1 &&
        @stack) {
    
        $message .= "\n\n    Stack TraceDump (descending):\n";
    
        foreach my $caller (@stack) {
        
            my ($package, $file, $line, $subroutine) = @{$caller};
            $message .= "\n    [*] Package:    " . $package .
                        "\n        File:       " . $file .
                        "\n        Line:       " . $line .
                        "\n        Subroutine: " . $subroutine . "\n";
        
        }
        
    }
    
    $message .= "\n    -> Caught";

}

sub is {
    
    my ($string, $allowed) = @_;
    
    $allowed = quotemeta($allowed) if (defined $allowed);
    
    return(1) if ($string =~ m/^[$allowed]+$/i);
    
}

sub checkparameters {
    
    my ($default, $parameters) = @_;
    
    return unless(ref($default) eq "HASH" &&
                  ref($parameters) eq "HASH");
    
    foreach my $key (keys %{$parameters}) {
	
        next if (!exists $default->{$key} ||
                 substr($key, 0, 1) eq "_");
        
        if (ref($default -> {$key}) eq "ARRAY" &&
            ref($parameters -> {$key}) eq "ARRAY") {
            
            for(my $i=0;$i<@{$parameters->{$key}};$i++) { $default->{$key}->[$i] = $parameters->{$key}->[$i] if (defined $parameters->{$key}->[$i]); }
            
        }
        elsif (ref($default->{$key}) eq "HASH" &&
               ref($parameters->{$key}) eq "HASH") { $default->{$key} = checkparameters($default->{$key}, $parameters->{$key}); }
        else { $default->{$key} = $parameters->{$key} if (defined $parameters->{$key}); }
	
    }
    
    return($default);
    
}

sub blessed {
    
    my $reference = shift;
    
    return(1) if (ref($reference) &&
                  eval { $reference->can("can") });

}

sub clonearrayref {
    
    my $array = shift;
    
    my $clone = [];
    
    return unless(reftype($array) eq "ARRAY");
    
    for(my $i=0;$i<@{$array};$i++) {
                
        my $element = $array->[$i];
                
        if (defined $element &&
	    fileno($element)) { $clone->[$i] = clonefh($element); }
        elsif (blessed($element) &&
               $element->can("clone")) { $clone->[$i] = $element->clone(); }
        elsif (ref($element) eq "HASH") { $clone->[$i] = clonehashref($element); }
        else { $clone->[$i] = $array->[$i]; }
	
    }
    
    return($clone);
    
}

sub clonehashref {
    
    my $hash = shift;
    
    my $clone = {};
    
    return unless(reftype($hash) eq "HASH");
    
    foreach my $key (keys %{$hash}) {
	
	if (reftype($hash->{$key}) eq "ARRAY") { $clone->{$key} = clonearrayref($hash->{$key}); }
	elsif (reftype($hash->{$key}) eq "HASH") { $clone->{$key} = clonehashref($hash->{$key}); }
	else {
        
            my $element = $hash->{$key};
            
            if (defined $element &&
		fileno($element)) { $clone->{$key} = clonefh($element); }
            elsif (blessed($element) &&
                   $element->can("clone")) { $clone->{$key} = $element->clone(); }
            else { $clone->{$key} = $hash->{$key}; }    
            
        }
	
    }
    
    return($clone);
    
}

sub clonefh {
    
    my $fh = shift;
    
    my ($mode, $clone);
    $mode = _fhmode($fh);
    
    open($clone, $mode, $fh);
    seek($clone, 0, SEEK_SET);
    
    return($clone);
    
}

sub uriescape {
    
    my $uri = shift;
    
    $uri =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
    
    return($uri);
    
}

sub uriunescape {
    
    my $uri = shift;
    
    $uri =~ s/\%([A-Fa-f0-9]{2})/pack("C", hex($1))/seg;
    
    return($uri);
    
}

sub unquotemeta {
    
    my $string = shift;
    
    $string =~ s/(?:\\(?!\\))//g;
    $string =~ s/(?:\\\\)/\\/g;
    
    return($string);
    
}

sub striptags {

    my $html = shift;
    
    $html =~ s/(<br>)+/ /gi;
    $html =~ s/<.+?>//g;
    $html =~ s/&nbsp;/ /g;
    $html =~ s/&quot;/"/g;
    $html =~ s/&amp;/&/g;
    $html =~ s/&lt;/</g;
    $html =~ s/&gt;/>/g;
    $html =~ s/[\040\t\r\n]+/ /gi;
    $html =~ s/^\s+|\s+$//;

    return($html);
  
}

sub questionyn {
    
    my ($question, $default) = @_;
    
    my ($head, $tail, $possible, $answer);
    ($head, $tail) = $question =~ /^(\n+).+?(\n+)$/;
    $question =~ s/^(\n+)|(\n+)$//g;
    $question =~ s/\n+/\n      /g;
    $default = "y" unless($default =~ m/^y|n$/i);
    $possible = "[yn]";
    $possible =~ s/($default)/uc($1)/ie;
    
    ReadMode(3);
    print $head;
    
    while(1) {
	
	print "  [?] " . $question . " " . $possible . ": ";
	chomp($answer = ReadKey(0));
	$answer ||= $default; 
	print "\n";
	
	last if ($answer =~ m/^$possible$/i);
	
    }
    
    ReadMode(0);
    print $tail;
    
    return(1) if (lc($answer) eq "y");
    
}

sub randint {
    
    my $bits = shift || 16;
    
    my %bits = ( 4  => 0xf,
                 8  => 0xff,
                 16 => 0xffff,
                 32 => 0xffffffff );
    
    throw("Invalid number of bits") if (!exists $bits{$bits});
    
    return(int(rand($bits{$bits})));
    
}

sub randnum { return(_randstring("n", $_[0])); }

sub randalpha { return(_randstring("a", $_[0])); }

sub randalphanum { return(_randstring("an", $_[0])); }

sub randmixed { return(_randstring("m", $_[0])); }

sub which {
    
    my $file = shift || return();
    
    for (map { File::Spec->catfile($_, $file) } File::Spec->path()) { return($_) if (-x $_ &&
                                                                                     !-d $_); }
    
    return();
    
}

sub _randstring {
    
    my $type = shift;
    my $length = shift if (@_);
    
    $length =~ s/[^\d]//g;
    $length ||= 1;
    
    my (@alpha, @num, @punct, %chars);
    @alpha = ("a" .. "z", "A" .. "Z");
    @num = ("0" .. "9");
    @punct = map { chr($_); } (33 .. 47, 58 .. 64, 91 .. 96, 123 .. 126);
    
    %chars = ( a  => \@alpha,
               n  => \@num,
               an => [@alpha, @num],
               p  => \@punct,
               m  => [@alpha, @num, @punct] );
    
    return(join("", map { $chars{$type}->[int(rand(@{$chars{$type}}))]} (0 .. $length - 1)));
    
}

sub _fhmode {
    
    my $fh = shift;
    
    my $mode = fcntl($fh, F_GETFL, 0) & 3;
    $mode = $mode == 0 ? "<&" : ">&";
    
    return($mode);
    
    
}

1;
