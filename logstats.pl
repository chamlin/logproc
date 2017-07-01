#!/usr/bin/perl -w
use strict;
use Data::Dumper;
use Carp;

# $state->{config}
#       ->{config}{config_files}
#       ->{config}{options}
#       ->{input}{filename}
#                {line_number}
#                {line}
#       ->{scratch}   for scratch during line match
#       ->{scratch}{timestamp}
#       ->{scratch}{text}
#       ->{scratch}{values}    []

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
        filename => $file,
        line_number => 0,
    };
    open my $fh, '<', $file;
    while (my $line = <$fh>) {
        $state->{input}{line} = $line;
        $state->{input}{line_number}++;
    }
    close $fh;
}

check_line ($state);

print "obai\n";

print Dumper $state;

############ subs

sub check_line {
    my ($state) = @_;
    my $line = $state->{input}{line};
    foreach my $matcher (@{$state->{matchers}}) {
        my $regex = $matcher->{regex};
        my $text = $state->{scratch}{text};
        print "trying", Dumper ($matcher), ".\n";
        my $match_full_line = ($matcher->{match} && $matcher->{match} eq 'line' ? 1 : 0);
print "mfl: $match_full_line.\n";
        my @values = (($match_full_line ? $line : $text) =~ /$regex/);
        print "values = ", join ('|', @values), ".\n";
        if (scalar @values) {
            $state->{scratch}{values} = \@values;
            foreach my $action (@{$matcher->{actions}}) { $action->($state) }
        }
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
}
