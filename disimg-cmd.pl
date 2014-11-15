#!/bin/perl
use strict;
use warnings;

use Tk;
use Tk::JPEG;
use Tk::PNG;
use Tk::Pane;

my $dir = $ENV{PWD};

chdir $dir or die "Can't go do $dir - $!\n";

my $filespec = '*.{jpg,gif,png}';
my @files = (sort glob $filespec)
    or die "No files matching $filespec in $dir !\n";

my $ii = -1; # image index

my $mw = new MainWindow;

my $scrolled = $mw
    ->Scrolled( 'Pane', -scrollbars => 'osoe', -width => 640, -height => 480, )
    ->pack( -expand => 1, -fill => 'both', );

my $imagit = $scrolled
    ->Label
    ->pack( -expand => 1, -fill => 'both', );

my( $xscroll, $yscroll ) = $scrolled->Subwidget( 'xscrollbar', 'yscrollbar' );

my $img2;

my( $last_x, $last_y );

foreach (@ARGV) {
    my( $key, $cmd ) = split /=>/, $_, 2;
    print "bind <$key> => $cmd\n";
    $mw->bind( "<$key>" => \sub { key_press($key, $cmd) } );
}

$mw->bind( '<Left>'  => \&prev_image );
$mw->bind( '<Right>' => \&next_image );

$imagit->bind( '<Button1-ButtonRelease>' => sub { undef $last_x } );
$imagit->bind( '<Button1-Motion>' => [ \&drag, Ev('X'), Ev('Y'), ] );

sub drag {
    my( $w, $x, $y ) = @_;
    if ( defined $last_x ) {
        my( $dx, $dy ) = ( $x-$last_x, $y-$last_y );
        my( $xf1, $xf2 ) = $xscroll->get;
        my( $yf1, $yf2 ) = $yscroll->get;
        my( $iw, $ih ) = ( $img2->width, $img2->height );
        if ( $dx < 0 ) {
            $scrolled->xview( moveto => $xf1-($dx/$iw) );
        } else {
            $scrolled->xview( moveto => $xf1-($xf2*$dx/$iw) );
        }
        if ( $dy < 0 ) {
            $scrolled->yview( moveto => $yf1-($dy/$ih) );
        } else {
            $scrolled->yview( moveto => $yf1-($yf2*$dy/$ih) );
        }
    }
    ( $last_x, $last_y ) = ( $x, $y );
}

sub get_image {
    return $files[$ii];
}

sub show_image {
    my $imgfile = get_image();
    $mw->configure( -title => "($ii) - - - - - - -" );
    $img2 = $mw->Photo( -file => $imgfile );
    $imagit->configure(
        -image => $img2,
        -width => $img2->width,
        -height => $img2->height,
    );
    $mw->configure( -title => "($ii) $imgfile" );
}

sub prev_image {
    $ii = ( $ii + @files - 1 ) % @files;
    show_image();
}

sub next_image {
    $ii = ( $ii + 1 ) % @files;
    show_image();
}

sub key_press {
    my( $key, $cmd ) = @_;
    my $filename = get_image();
    $cmd =~ s{%%%}{$dir/$filename}g;
    print "launch $cmd\n";
    print qx{$cmd};
}

$mw->after( 0, \&next_image );

MainLoop;
