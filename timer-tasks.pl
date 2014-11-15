#!/usr/bin/perl
use strict;
use warnings;

use Term::ANSIColor;
use Term::ANSIScreen qw(cls);

my @tasks;

my $start_offset = pop @ARGV if $ARGV[0];
my $start = time() - $start_offset;

while (<>) {
    push @tasks, [$1, $2] if m/(\d?\.?\d+)mn\s+(.*)\s*/;
}

while (1) {
    cls();
    my $ctime = time();
    my $lastend = $start;

    foreach my $task (@tasks) {
        my ($time, $name) = @$task;
        my $taskstart = $lastend;
        my $taskend = $taskstart + $time * 60;
        my $current = ($ctime >= $taskstart && $ctime < $taskend);

        if ($current) {
            my $left = ($taskend - $ctime) / 60;
            print "->";
            print color 'bold';
            printf "\t| left: %5.1fmn |", $left;
        }
        elsif ($taskend <= $ctime) {
                printf "  \t_________________";
        }
        else {
            my $startin = ($taskstart - $ctime) / 60;
            printf "  \t|   in: %5.1fmn |", $startin;
        }

        print "\t $name";
        print color 'reset';
        print "  <-" if $current;
        print "\n";
        $lastend = $taskend;
    }

    my $total = ($ctime - $start)/60;
    printf "\ncurrent %.1fmn (start: %i)\n", $total, $start;

    sleep 5.0;
}
