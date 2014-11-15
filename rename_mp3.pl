#!/usr/bin/perl
use strict;
use warnings;
use utf8;

use MP3::Info;
use File::Path qw(make_path);

sub myescape {
    my $field = shift;
    $field =~ s{/}{_}g;
    return $field;
}

foreach (@ARGV) {
    my $tag = get_mp3tag($_);
    if (!$tag) {
        warn("cannot open tag for $_");
        next;
    }

    my $artist = myescape $tag->{ARTIST};
    my $album = myescape $tag->{ALBUM};
    my $track = $1 if $tag->{TRACKNUM} =~ m{^(\d+)};
    my $trackstr = sprintf "%02d", $track;
    my $title = myescape $tag->{TITLE};

    if (!$artist or !$album or !$track or !$title) {
        warn("one tag is missing in $_");
        next;
    }

    my $path = "${artist}/${album}";
    my $newfile = "$trackstr - $title.mp3";
    my $newpath = "${path}/${newfile}";

    make_path($path);
    if (-e $newpath) {
        warn("file already exists $newpath (for $_)");
        next;
    }
    link $_, $newpath or die("cannot create file $newpath");
    print "link $_ -> $newpath\n";
}
