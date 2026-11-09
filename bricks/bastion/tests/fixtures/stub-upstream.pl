#!/usr/bin/perl
# Stub upstream of the bastion's stack test: a web interface that answers
# every request with 200 and the request line and headers it received, so
# the test sees what the web front forwards. It also sends a challenge of
# its own, which the front must not pass on. Also a partner's endpoint
# (v0.5 chunk 17a): GET /orders answers 200 only with `Authorization: Bearer
# <the credential>`, the file /opt/partner/credential, else 401. Runs in
# debian:13-slim (perl-base only); listens on port 9090.
use strict;
use warnings;
use IO::Socket::INET;

my $server = IO::Socket::INET->new(LocalPort => 9090, Listen => 16, ReuseAddr => 1,
                                   Proto => 'tcp') or die "stub: listen: $!\n";
$SIG{TERM} = sub { exit 0 };
while (my $client = $server->accept) {
    my $request = '';
    while (my $line = <$client>) {
        last if $line =~ /^\r?\n$/;
        $request .= $line;
    }
    $request =~ s/\r//g;
    if ($request =~ m{^GET /orders }) {
        my $key = '';
        if (open(my $fh, '<', '/opt/partner/credential')) { local $/; $key = <$fh>; close $fh; }
        $key =~ s/\s+$//;
        my $ok = $key ne '' && $request =~ m{^authorization: Bearer \Q$key\E$}mi;
        my $body = $ok ? "order accepted\n" : "unauthorized\n";
        print $client ($ok ? "HTTP/1.1 200 OK" : "HTTP/1.1 401 Unauthorized")
            . "\r\nContent-Type: text/plain\r\nContent-Length: " . length($body)
            . "\r\nConnection: close\r\n\r\n$body";
        close $client;
        next;
    }
    my $body = "stub saw:\n$request";
    print $client "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n"
        . "WWW-Authenticate: Basic realm=\"stub\"\r\n"
        . "Content-Length: " . length($body) . "\r\nConnection: close\r\n\r\n$body";
    close $client;
}
