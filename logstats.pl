#!/usr/bin/perl -w
use strict;
use Data::Dumper;
use List::Util;
use Getopt::Long;
use FindBin;                 # locate this script

use open qw< :encoding(UTF-8) >;

my $state = {
    input => {},
    config => {
        config_files => [$FindBin::Bin.'/standard.config'],
        input_files => [],
        outdir => '.',
        debug_string => '',
    },
};

GetOptions (
    'file=s' => \$state->{config}{file},
    'glob=s' => \$state->{config}{glob},
    'outdir=s' => \$state->{config}{outdir},
    'debug' => \$state->{config}{debug},
    'namefrom=s' => \$state->{config}{namefrom},
    'nameto=s' => \$state->{config}{nameto},
);

resolve_options ($state);



# $state->{config}
#       ->{config}{config_files}
#       ->{config}{options}
#       ->{config}{filenames}
#       ->{input}{filename}
#                {line_number}
#                {line}
#       ->{scratch}   for scratch during line match
#       ->{scratch}{timestamp}
#       ->{scratch}{forests}
#       ->{scratch}{text}
#       ->{scratch}{values}    []
#       ->{stats}{$node}{$resource}{$action}{$value}     blank for value if none (e.g., restart)?


read_configs ($state);


open my $fh_out, '>', 'logstats.csv';
$state->{fh_out} = $fh_out;
my $headers = $state->{headers};
print $fh_out "$headers\n" if ($headers);
$state->{total_time} = -time;

foreach my $file (@{$state->{config}{input_files}}) {
    print "< $file\n";
    $state->{input} = {
        node => $file,
        filename => $file,
        line_number => 0,
    };
    open my $fh, '<', $file;
    while (my $line = <$fh>) {
        $state->{input}{line} = $line;
        $state->{input}{line_number}++;
        $state->{scratch} = {};
        check_line ($state);
    }
    close $fh;
    my $line_number = $state->{input}{line_number};
    $state->{total_lines} += $line_number;
    print "lines read for $file: $line_number.\n";
}

$state->{total_time} += time;
my $lines_per_second = $state->{total_time} > 0 ? int ($state->{total_lines} / $state->{total_time}) : 'Inf';
print "\n$state->{total_lines} in $state->{total_time} seconds ($lines_per_second l/s).\n";


#dump_stats ($state);
dump_counts ($fh_out, $state->{counts}, '');

close $fh_out;

#print STDERR Dumper $state;

############ subs

sub check_line {
    my ($state) = @_;
    my $line = $state->{input}{line};
    foreach my $matcher (@{$state->{matchers}}) {
        if ($matcher->{disabled}) { next }
        my $matched = 0;
        my $regex = $matcher->{regex};
        unless (defined $regex) { next }
        $state->{current_matcher} = $matcher;
        if ($regex eq '*') {
            $matched = 1
        } else {
            my $regex_compiled = $matcher->{regex_compiled};
            my $text = exists $state->{scratch}{text} ? $state->{scratch}{text} : '';
            my $match_full_line = ($matcher->{match} && $matcher->{match} eq 'line' ? 1 : 0);
            my @values = (($match_full_line ? $line : $text) =~ /$regex_compiled/g);
            if (scalar @values) {
                $state->{scratch}{values} = \@values;
                $matched = 1
            }
        }
        my $actions = $matched ? 'matched' : 'unmatched';
        foreach my $action (@{$matcher->{$actions}}) { $action->($state) }
        
        if ($state->{scratch}{break}) { last }
    }

    if ($state->{ship} && scalar @{$state->{ship}}) {
        my $output = $state->{fh_out};
        foreach $line (@{$state->{ship}}) {
            print $output join ('\t', @$line), "\n";
        }
    }

    $state->{ship} = [];
}


sub read_configs {
    my ($state) = @_;
    local $/;   # Set input to "slurp" mode.
    foreach my $config_file (@{$state->{config}{config_files}}) { 
        #unless (-f $config_file) { carp "No such config $config_file, skipping.\n"; }
        my ($fh, $dstruct);
        my $error;
        if (open my $fh, '<', $config_file) {
            my $config_string = <$fh>;
            $dstruct = eval $config_string;
            if (defined $dstruct) {
                # check.  no dup classifications.  each has to have (what?)
                # should be array of hashes, no?
            } else {
                $error = "Error, skipping config file $config_file: $@";
            }
            close $fh;
        } else {
            $error = "$config_file can't be read, skipping.\n";
        } 
        if (defined $error) {
            print STDERR $error;
        } else {
            push @{$state->{matchers}}, @$dstruct;
        }
    }

    # initialize
    foreach my $matcher (@{$state->{matchers}}) {
        if ($matcher->{disabled}) { next }
        $state->{current_matcher} = $matcher;
        if ($matcher->{regex} && $matcher->{regex} ne '*') {
            $matcher->{regex_compiled} = qr/$matcher->{regex}/;
        }
        foreach my $init_action (@{$matcher->{init}}) {
            $init_action->($state);
        }
    }
}

sub dump_counts {
    my ($fh_out, $ref, $prefix) = @_;
    unless (defined $ref)  { return }
    if (ref $ref eq 'HASH') {
        foreach my $key (sort keys %$ref) {
            dump_counts ($fh_out, $ref->{$key}, "$prefix$key,");
        }
    } else {
        print $fh_out "$prefix$ref\n";
    }
}

sub resolve_options {
    my ($self) = @_;
    # check files in
    if   ($self->{config}{glob}) {
        foreach my $glob (split (/\s*,\s*/, $self->{config}{glob})) {
            push @{$self->{config}{input_files}}, grep { -f } glob ($glob);
        }
    }
    elsif ($self->{config}{file}) { $self->{config}{input_files} = [grep { -f } (split (',', $self->{config}{file}))] }
    else { }
    unless (scalar @{$self->{config}{input_files}}) { die "No filenames provided/found.\n"; }
}
