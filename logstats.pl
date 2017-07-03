#!/usr/bin/perl -w
use strict;
use Data::Dumper;
use List::Util;

# $state->{config}
#       ->{config}{config_files}
#       ->{config}{options}
#       ->{input}{filename}
#                {line_number}
#                {line}
#       ->{scratch}   for scratch during line match
#       ->{scratch}{timestamp}
#       ->{scratch}{forests}
#       ->{scratch}{text}
#       ->{scratch}{values}    []
#       ->{stats}{$node}{$resource}{$action}{$value}     blank for value if none (e.g., restart)?

print "ohai\n";

my $state = {
    input => {},
    config => {
        config_files => ['standard.config'],
        data_files => ['short'],
    },
};


read_configs ($state);

foreach my $file (@{$state->{config}{data_files}}) {
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
    print "lines read for $file: $state->{input}{line_number}.\n";
}


print "obai\n";

dump_stats ($state);

print Dumper $state;

############ subs

sub check_line {
    my ($state) = @_;
    my $line = $state->{input}{line};
    foreach my $matcher (@{$state->{matchers}}) {
        if ($matcher->{disabled}) { next }
        my $matched = 0;
        my $regex = $matcher->{regex};
        $state->{current_matcher} = $matcher;
        if ($regex eq '*') {
            $matched = 1
        } else {
            my $regex_compiled = $matcher->{regex_compiled};
            my $text = $state->{scratch}{text};
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
        $state->{current_matcher} = $matcher;
        if ($matcher->{regex} && $matcher->{regex} ne '*') {
            $matcher->{regex_compiled} = qr/$matcher->{regex}/;
        }
        foreach my $init_action (@{$matcher->{init}}) {
            $init_action->($state);
        }
    }
}

sub dump_stats {
    my ($state) = @_;
    open my $fh, '>', 'logstats.csv';
    foreach my $timestamp (sort keys %{$state->{stats}}) {
        foreach my $node (sort keys %{$state->{stats}{$timestamp}}) {
            foreach my $resource (sort keys %{$state->{stats}{$timestamp}{$node}}) {
                foreach my $action (sort keys %{$state->{stats}{$timestamp}{$node}{$resource}}) {
                    my $value = $state->{stats}{$timestamp}{$node}{$resource}{$action};
                    if (ref $value eq 'ARRAY') {
                        # aggregate
                        $value = List::Util::sum (@$value);
                    }
                    print $fh join (',', ($timestamp, $node, $resource, $action, $value)), "\n";
                }
            }
        }
    }
    close $fh;
}
