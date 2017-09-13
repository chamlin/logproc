#!/usr/bin/perl -w
use strict;
use POSIX;
use Data::Dumper;
use Getopt::Long;

my %days = (
    'Sun' => 1,
    'Mon' => 1,
    'Tue' => 1,
    'Wed' => 1,
    'Thu' => 1,
    'Fri' => 1,
    'Sat' => 1,
);

my $stats = {
    config => {
        node => 'nodex',
        file => 'pmap.log',
        min_mb => 0,  # in MB
    },
};

GetOptions (
    'node=s' => \$stats->{config}{node},
    'file=s' => \$stats->{config}{file},
    'min=i' => \$stats->{config}{min_mb},
);

my $date_time = undef;

open my $fh, '<', $stats->{config}{file} or die "Can't open $stats->{config}{file}.\n";
while (<$fh>) {
    chomp;
    $stats->{line} = $_;
#print STDERR "\n\n";
    my @parts = split /\s+/;
#print STDERR "$_: |", join ('|', @parts), "|\n";
    if (exists $days{$parts[0]}) {
# print "date line: @parts\n";
        $stats->{date_time} = iso_from_pstack ($_);
    } elsif (/^\s+total\s/) {
        # junk totals line
    } elsif (/^\S+:\s+\S+$/) {
        # junk base line
    } else {
        my ($address, $size, $permissions) = ($parts[0], $parts[1], $parts[2]);
        my $whatis = join (' ', @parts[3 .. $#parts]);
#print "($address, $size, $permissions, $whatis)\n";
        add_line ($stats, $address, $size, $permissions, $whatis);
    }
}
close $fh;

dump_stats ($stats);

#print STDERR Dumper $stats;

sub iso_from_pstack {
    my ($s) = @_;
    my ($day, $mo, $date, $time, $offset, $year) = split (/\s+/, $s);
    my %mos = (
        Jan => 1, Feb => 2, Mar => 3, Apr => 4, May => 5, Jun => 6, Jul => 7, Aug => 8, Sep => 9, Oct => 10, Nov => 11, Dec => 12
    );
    my $iso = sprintf ('%04d-%02d-%02d', $year, $mos{$mo}, $date, ) . ' ' . $time;
    unless ($iso =~ /2\d\d\d-\d[1-9]-\d\d \d\d:\d\d:\d\d/) {
        print STDERR "Can't make timestamp from $s.\n";
        return "1970-01-01 00:00:00";
    }
    return $iso;
}

# dt, node, reading, resource, action, value
sub dump_stats {
    my ($stats) = @_;
    my $MB = 1024;
    foreach my $date_time (sort keys %{$stats->{dt}}) {
        my $total = 0;
        foreach my $whatis (sort {$stats->{dt}{$date_time}{$b} <=> $stats->{dt}{$date_time}{$a}} keys %{$stats->{dt}{$date_time}}) {
            my $value = $stats->{dt}{$date_time}{$whatis};
            $total += $value;
            if ($value < $MB) {
                next;  # less than a meg?
            } else {
                $value = floor ($value / $MB + 0.5);
            }
            if ($value > $stats->{config}{min_mb}) {
                print "$date_time\t$stats->{config}{node}\tpmap_mb\tmemory\t$whatis\t$value\n";
            }
        }
        print "$date_time\t$stats->{config}{node}\tpmap_mb\tmemory\ttotal\t$total\n";
    }
}

sub add_line {
    my ($stats, $address, $size, $permissions, $whatis) = @_;
    $size =~ s/K$//;
    if ($whatis =~ /MarkLogic$/) { # proc
        $stats->{dt}{$stats->{date_time}}{$whatis} += $size;
    } elsif ($whatis =~ /anon_hugepage/) {
        my $type = 'anon_hugepage';
        if ($whatis =~ /deleted/) { $type .= '_deleted' }
        $stats->{dt}{$stats->{date_time}}{$type} += $size;
    } elsif (/\[\s(\S+)\s\]/) {
        $stats->{dt}{$stats->{date_time}}{$1} += $size;
    } elsif ($whatis =~ m|/Forests/|) { # forest data files
        if ($whatis =~ /(StringData|AtomData|StringIndex|AtomIndex|TripleDocIndex|BinaryKeys|Timestamps|Ordinals|URIKeys|UniqKeys|TreeIndex|Frequencies|Lexicon|TripleTypeData|TripleTypeIndex|TripleValueFreqsIndex|TripleValueIndex|TripleIndex|LinkKeys|ListIndex|Qualities|dateTime|StopKeySet|TripleValueFreqs|unsignedLong|string|date|decimal)(=|-|\?|-\?)?$/) {
            $stats->{dt}{$stats->{date_time}}{$1} += $size;
        } else {
            die "What's $whatis?\n";
        }
    } elsif ($whatis =~ m|^(/[^/ ]+)+|) {
        $stats->{dt}{$stats->{date_time}}{$whatis} += $size;
    } else {
print Dumper $stats;
        die "What's $whatis?\n";
    } 
}




