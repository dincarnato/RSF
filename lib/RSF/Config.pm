package RSF::Config;

use strict;
use Config::Simple;
use Core::Mathematics;
use Core::Utils;
use Data::Sequence::Utils;
use Term::Table;

use base qw(Core::Base);

sub new {
    
    my $class = shift;
    my %parameters = @_ if (@_);
    
    if (exists $parameters{file} &&
        -e $parameters{file}) {
        
        eval { Config::Simple->import_from($parameters{file}, \%parameters); } or Core::Utils::throw("Malformed configuration file");
        
        # This removes the leading 'default.' prefix added by Config::Simple when parsing 'key=value' pairs
        %parameters = map { lc(s/^default.//r) => $parameters{$_} } keys(%parameters); 
        
    } 
    
    my $self = $class->SUPER::new(%parameters);
    $self->_init({ file            => undef,
                   scoremethod     => "Ding",
                   normmethod      => "2-8\%",
                   normwindow      => 50,
                   windowoffset    => 50,
                   reactivebases   => "all",
                   normindependent => 0,
                   pseudocount     => 1,
                   maxscore        => 10,
                   meancoverage    => 1,
                   mediancoverage  => 1,
                   autowrite       => 1 }, \%parameters); 
    
    $self->_validate();
    $self->_fixproperties();
    
    $self->write() if (defined $self->{file} &&
                       !-e $self->{file} &&
                       $self->{autowrite});
    
    return($self);
    
}

sub _validate {
    
    my $self = shift;

    $self->throw("Invalid scoreMethod value") if ($self->{scoremethod} !~ m/^Ding|Rouskin|[12]$/i);
    $self->throw("Invalid normMethod value") if ($self->{normmethod} !~ m/^(2-8\%|90\% Winsorising|Box-?plot|[123])$/i);
    $self->throw("Invalid normWindow value") if (!isint($self->{normwindow}));
    $self->throw("normWindow value should be greater than or equal to 3") if ($self->{normwindow} < 3);
    $self->throw("Invalid windowOffset value") if (!isint($self->{windowoffset}) ||
                                                   $self->{windowoffset} < 1);
    $self->throw("windowOffset value cannot exceed than normWindow size") if ($self->{windowoffset} > $self->{normwindow});
    $self->throw("Invalid reactive bases") if ($self->{reactivebases} !~ m/^all$/i &&
                                               !isiupac($self->{reactivebases}));
    $self->throw("normIndependent value must be boolean") if ($self->{normindependent} !~ m/^TRUE|FALSE|yes|no|[01]$/i);
    $self->throw("Invalid pseudoCount value") if (!isint($self->{pseudocount}) ||
                                                  !ispositive($self->{pseudocount}));
    $self->throw("pseudoCount value should be greater than 0") if ($self->{pseudocount} <= 0);
    $self->throw("Invalid maxScore value") if (!ispositive($self->{maxscore}));
    $self->throw("maxScore value should be greater than or equal to 1") if ($self->{maxscore} < 1);
    $self->throw("Invalid meanCoverage value") if (!ispositive($self->{meancoverage}));
    $self->throw("Invalid medianCoverage value") if (!ispositive($self->{mediancoverage}));
    $self->throw("Automatic configuration file writing should be boolean") if ($self->{autowrite} !~ m/^[01]$/);
    
}

sub _fixproperties {
    
    my $self = shift;
    
    $self->{scoremethod} = $self->{scoremethod} =~ m/^Ding|1$/i ? 1 : 2;
    $self->{normmethod} = $self->{normmethod} =~ m/^2-8\%|1$/ ? 1 : ($self->{normmethod} =~ m/^(90\% Winsorising|2)$/i ? 2 : 3);
    $self->{reactivebases} = $self->{reactivebases} =~ m/^all$/i ? "ACGT" : join("", sort(uniq(iupac2nt(rna2dna($self->{reactivebases})))));
    $self->{normindependent} = $self->{normindependent} =~ m/^TRUE|yes|1$/i ? 1 : 0;
    
}

sub scoremethod { return($_[1] ? ($_[0]->{scoremethod} == 1 ? "Ding" : "Rouskin") : $_[0]->{scoremethod}); }

sub normmethod { return($_[1] ? ($_[0]->{normmethod} == 1 ? "2-8\%" : ($_[0]->{normmethod} == 2 ? "90\% Winsorising" : "Box-plot")) : $_[0]->{normmethod}); }

sub normwindow { return($_[0]->{normwindow}); }

sub windowoffset { return($_[0]->{windowoffset}); }

sub reactivebases { return($_[0]->{reactivebases}); }

sub normindependent { return($_[0]->{normindependent}); }

sub pseudocount { return($_[0]->{pseudocount}); }

sub maxscore { return($_[0]->{maxscore}); }

sub meancoverage { return($_[0]->{meancoverage}); }

sub mediancoverage { return($_[0]->{mediancoverage}); }

sub summary {
    
    my $self = shift;
    
    my $table = Term::Table->new(indent => 2);
    $table->head("Parameter", "Value");
    $table->row("Scoring method", $self->scoremethod(1));
    $table->row("Normalization method", $self->normmethod(1));
    
    if ($self->{scoremethod} == 1) { # Ding
        
        $table->row("Pseudocount", $self->{pseudocount});
        $table->row("Maximum score", $self->{maxscore});
        
    }
        
    $table->row("Normalization window", $self->{normwindow});
    $table->row("Window sliding offset", $self->{windowoffset});
    $table->row("Reactive bases", $self->{reactivebases});
    $table->row("Normalize each base independently", ($self->{normindependent} ? "Yes" : "No"));
    $table->row("Minimum mean coverage", $self->{meancoverage});
    $table->row("Minimum median coverage", $self->{mediancoverage});
    $table->blank();
    
    print "\n[+] Configuration summary:\n\n";
    $table->print();
    
}

sub write {
    
    my $self = shift;
    my $file = shift || $self->{file};
    
    return if (!defined $file);
    
    open(my $fh, ">", $file) or $self->throw("Unable to write configuration file \"" . $file . "\" (" . $! . ")");
    
    print $fh "scoreMethod=" . ($self->{scoremethod} == 1 ? "Ding" : "Rouskin") . "\n" .
              "normMethod=" . ($self->{normmethod} == 1 ? "2-8\%" : ($self->{normmethod} == 2 ? "90\% Winsorising" : "Box-plot")) . "\n";
    
    if ($self->{scoremethod} == 1) { # Ding
        
        print $fh "pseudoCount=" . $self->{pseudocount} . "\n" .
                  "maxScore=" . $self->{maxscore} . "\n";
        
    }
    
    print $fh "normWindow=" . $self->{normwindow} . "\n" .
              "windowOffset=" . $self->{windowoffset} . "\n" .
              "reactiveBases=" . $self->{reactivebases} . "\n" .
              "normIndependent=" . ($self->{normindependent} ? "yes" : "no") . "\n" .
              "meanCoverage=" . $self->{meancoverage} . "\n" .
              "mediancoverage=" . $self->{mediancoverage} . "\n";
              
    close($fh);
    
}

1;
