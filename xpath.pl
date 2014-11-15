#!/usr/bin/perl
use strict;
use warnings;

use HTML::TreeBuilder::XPath;
use Switch;

my $content;
{
    local $/=undef;
    $content = <STDIN>;
}

my $tree = HTML::TreeBuilder::XPath->new;
$tree->parse($content);
my @xs = $tree->findnodes($ARGV[0]);

$\="\n";
foreach (@xs) {
    switch (ref $_) {
        case "HTML::Element" {
            print $_->as_text();
        }
        case "HTML::TreeBuilder::XPath::Attribute" {
            print $_->{_value};
        }
        case "HTML::TreeBuilder::XPath::TextNode" {
            print $_->{_content};
        }
        else {
            die((ref $_) .": unknown return type");
        }
    }
}

$tree->delete; # to avoid memory leaks, if you parse many HTML documents 
