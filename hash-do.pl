#!/usr/bin/perl -s
use strict;
use warnings;
use File::Basename qw(basename);
use Digest::MD5;
$|=1;

$::check //= 1;
$::update //= 0;
$::recursion //= 1;
$::update_dry //= 0;
$::dir_stdin //= 0;
$::hash_name //= ".md5";
$::exclude_dotfiles //= 1;

my %counter;

sub make_hash {
    my $file = shift;
    my $md5 = Digest::MD5->new;

    my $fd;
    if (!open($fd, '<', $file)) {
        print STDERR "error: cannot open file $file ($!)\n";
        ++$counter{cannot_open_file};
        return "cannot_open_file";
    }
    $md5->addfile($fd);
    close($fd);

    return $md5->hexdigest;
}

sub process {
    my $path = shift;
    my %hashes;
    my %hashes_new;
    my @comments;

    print "entering directory at $path\n";

    # parse the directory hashfile
    if (open(my $fd, '<', "$path/$::hash_name")) {
        while (<$fd>) {
            chop;
            if (m/^#/) {
                push @comments, $_;
            } else {
                my ($hash, $file) = split / /, $_, 2;
                if (defined $file and defined $hashes{$file}) {
                    print STDERR "error: duplicate hash for $file in $path (hash: $hash)\n";
                }
                else {
                    $hashes{$file} = $hash;
                }
            }
        }
        close($fd);
    }

    # select the output for the hasher (stdout or hashfile)
    my $fd;
    my $hashfile_failed = 0;
    if ($::update_dry) {
        $fd = *STDOUT;
    } elsif ($::update) {
        my $hash_file = "$path/$::hash_name";
        if (!open($fd, '>', $hash_file)) {
            print STDERR "error: cannot write to hashfile $path/$::hash_name ($!), writing to stdout\n";
            ++$counter{cannot_write_hashfile};
            $fd = *STDOUT;
            $hashfile_failed = 1;
        }

        print $fd "$_\n" foreach (@comments);
    }

    # iterate over file and check them
    my $dir;
    if (!opendir($dir, "$path")) {
        print STDERR "error: cannot open directory $path ($!)\n";
        ++$counter{cannot_open_directory};
        return;
    }

    # we read the directory and process all files and directories recursively
    while (my $_ = readdir($dir)) {
        $_ = basename $_;
        next if m/^\./ and $::exclude_dotfiles; # exclude hidden files
        next if $_ eq $::hash_name; # exclude the hash file itself
        my $event;

        if (-f "$path/$_") {
            if (!defined $hashes{$_}) {
                if (defined $fd && !$hashfile_failed) {
                    print "$_ creating new...";
                    my $file_hash = make_hash "$path/$_";
                    print "\r" . ' 'x80 . "\r";
                    print "$_ hash created ($file_hash)\n";
                    $event = "new";
                    $hashes_new{$_} = $file_hash;
                } else {
                    print STDERR "error: $path/$_ doesn't have a hash\n";
                    $event = "no_hash";
                }
            } else {
                if ($::check) {
                    print "$_ hashing...";
                    my $file_hash = make_hash "$path/$_";
                    print "\r" . ' 'x80 . "\r";
                    if ($hashes{$_} eq $file_hash) {
                        print "$_ hash match ($file_hash)\n";
                        $event = "ok";
                    } else {
                        print STDERR "error: $path/$_ hash don't match ($file_hash vs $hashes{$_})\n";
                        print $fd "##$_ $hashes{$_} != $file_hash ".time."\n" if defined $fd;
                        $event = "bad";
                    }
                }
                $hashes_new{$_} = $hashes{$_};
                delete $hashes{$_};
            }
        }
        elsif (-d "$path/$_") {
            if ($::recursion) {
                process("$path/$_/");
            } else {
                print "skipping directory $_";
            }
        }
        else {
            print STDERR "error: inode $path/$_ ignored (unknown type)\n";
            $event = "unknown";
        }

        # write the event that happened
        if (defined $event) {
            print $fd "#$_ $event ".time."\n" if defined $fd;
            ++$counter{$event};
        }
    }
    closedir($dir);

    # check missing files
    foreach (keys %hashes) {
        print STDERR "error: $path/$_ was not found\n";
        print $fd "#$_ not_found ".time."\n" if defined $fd;
        ++$counter{not_found};
    }

    # rewrite hash
    if (defined $fd) {
        foreach (sort keys %hashes_new) {
            print $fd "$hashes_new{$_} $_\n";
        }
        close($fd) unless $fd eq *STDOUT;
    }

    print "exiting directory $path\n";
}


print "hash checker check:$::check update:$::update recursion:$::recursion update_dry:$::update_dry dir_stdin:$::dir_stdin exclude_dotfiles:$::exclude_dotfiles\n";

if ($::dir_stdin) {
    foreach (<STDIN>) {
        chop;
        process($_);
    }
} else {
    process(".");
}

print STDERR "summary:\n";
print STDERR "$_ $counter{$_}\n" foreach (keys %counter);
