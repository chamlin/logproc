#!/usr/bin/perl -w
use strict;
use Data::Dumper;
use Carp;

print "ohai\n";

my $state = {};

my $config_file = 'standard.config';

read_configs ($state, [$config_file]);

my $s = "2015-03-28 00:04:17.959 Info: TaskServer: Starting phony process";

foreach my $matcher (@{$state->{matchers}}) {
    my $regex = $matcher->{regex};
    print "trying $regex.\n";
    my @values = ($s =~ /$regex/);
    print "values = ", join ('|', @values), ".\n";
    if (scalar @values) {
        $state->{values} = \@values;
        foreach my $action (@{$matcher->{actions}}) {
            $action->($state);
        }
    }
}


print "obai\n";

print Dumper $state;

sub read_configs {
    my ($state, $config_files) = @_;
    local $/;   # Set input to "slurp" mode.
    foreach my $config_file (@$config_files) { 
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
