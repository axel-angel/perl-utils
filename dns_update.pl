#!/usr/bin/perl
use strict;
use warnings;

use Getopt::ArgParse;
use Net::DNS::Update;
use Net::DNS;
use MIME::Base64;
use Digest::HMAC_SHA1;

my $ap = Getopt::ArgParse->new_parser();
$ap->add_arg('--syslog', type => 'Bool');
$ap->add_arg('--verbose', '-v', type => 'Bool');
$ap->add_arg('--ttl', type => 'Scalar', default => 300);
$ap->add_arg('--server', '-s', type => 'Scalar', required => 1);
$ap->add_arg('--zone', '-z', type => 'Scalar', required => 1);
$ap->add_arg('--name', '-n', type => 'Scalar', required => 1);
$ap->add_arg('--address', '-a', type => 'Scalar', required => 1);
$ap->add_arg('--keyfile', '-k', type => 'Scalar', required => 1);
$ap->add_arg('--keyname', '-i', type => 'Scalar', required => 1);

my $a = $ap->parse_args();

if ($a->syslog) {
    use Sys::Syslog qw(:standard :macros);
    openlog('dns_update', 'ndelay,nofatal,pid', 'user');
}


=pod
Update or create the A record for C<name> in C<zone> with the new C<address>.
=cut
my $fqdn = sprintf "%s.%s", $a->name, $a->zone;
my $record = sprintf "%s %s A %s", $fqdn, $a->ttl, $a->address;
print "Preparing record: $record\n" if $a->verbose;

# Load DNS key
my $file;
if (!open($file, "<", $a->keyfile)) {
    syslog(LOG_ERR, "Can't open '$a->keyfile' for reading DNS key: $!") if $a->syslog;
    die("Can't open '$a->keyfile' for reading DNS key: $!");
}
my $key = <$file>;
chomp($key);
print "Read keyfile, content: $key\n" if $a->verbose;

# Replace all entries by the new one.
my $update = Net::DNS::Update->new($a->zone);
$update->push(update => rr_del($fqdn));
$update->push(update => rr_add($record));

# Sign the update
my $tsig = Net::DNS::RR->new(
    name => $a->keyname,
    type => 'TSIG',
    algorithm => 'HMAC-SHA512',
    key => $key,
);
$update->sign_tsig($tsig);
print "Created request, signed\n" if $a->verbose;

# Send the packet
my $resolver = Net::DNS::Resolver->new;
$resolver->nameservers($a->server);
my $reply = $resolver->send($update);
print "Prepared resolver, sending update\n" if $a->verbose;

# Check if it worked
unless ($reply) {
    my $err = $resolver->errorstring;
    syslog(LOG_ERR, "DNS update for '$record' failed: $err") if $a->syslog;
    die ("DNS update for '$record' failed: $err");
}

my $rcode = $reply->header->rcode;
if ($rcode eq 'NOERROR') {
    syslog(LOG_INFO, "DNS update: $record") if $a->syslog;
    print "OK, update done successfully\n" if $a->verbose;
} else {
    syslog(LOG_ERR, "DNS update for '$record' failed: $rcode") if $a->syslog;
    die("DNS update for '$record' failed: $rcode");
}

exit 0;