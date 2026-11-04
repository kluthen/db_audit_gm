#!/usr/bin/perl
# A stand-in for cold storage's POST /shipments (v0.5 master spec 10.4;
# capture W1 item 6), for the PostgreSQL brick's stack test only: chunk 11
# builds the real stub. One request at a time on port 8080. It checks the
# credential (Authorization: Bearer <the file /run/secrets/vault_credential>),
# reads the body whole, and answers by the mode in /srv/vault/mode:
#   accept  201 and the receipt {shipment_id, type, rows_declared,
#           rows_received, size, received_at}, `size` the bytes received;
#   refuse  503, a refusal;
#   short   201 with `size` one byte short of what it received.
# Each request is appended to /srv/vault/shipments.ndjson: its headers
# Shipment-*, the bytes received, whether the credential matched, the
# status answered. Core Perl only.
use strict;
use warnings;
use IO::Socket::INET;
use JSON::PP;
use POSIX qw(strftime);

my $DIR = '/srv/vault';
mkdir $DIR;
my $expected = do {
    open(my $fh, '<', '/run/secrets/vault_credential') or die "no credential: $!\n";
    local $/; my $v = <$fh>; $v =~ s/\s+\z//; $v;
};
my $json = JSON::PP->new->canonical;
my $server = IO::Socket::INET->new(LocalPort => 8080, Listen => 16, ReuseAddr => 1, Proto => 'tcp')
    or die "listen: $!\n";
$| = 1;
print "vault stand-in listening on 8080\n";

sub mode {
    open(my $fh, '<', "$DIR/mode") or return 'accept';
    my $m = <$fh> // 'accept';
    $m =~ s/\s+//g;
    return $m || 'accept';
}

sub answer {
    my ($c, $status, $reason, $body) = @_;
    print {$c} "HTTP/1.1 $status $reason\r\nContent-Type: application/json\r\n"
        . "Content-Length: " . length($body) . "\r\nConnection: close\r\n\r\n$body";
}

while (my $c = $server->accept) {
    binmode($c);
    $c->autoflush(1);
    local $SIG{ALRM} = sub { die "timeout\n" };
    eval {
        alarm 120;
        my $line = <$c> // die "no request\n";
        $line =~ s/\r?\n\z//;
        my ($method, $path) = split / /, $line;
        my %h;
        while (defined(my $l = <$c>)) {
            $l =~ s/\r?\n\z//;
            last if $l eq '';
            my ($k, $v) = split /:\s*/, $l, 2;
            $h{lc $k} = $v;
        }
        my $len = $h{'content-length'} // 0;
        my ($got, $buf) = (0, '');
        while ($got < $len) {
            my $n = read($c, $buf, ($len - $got > 1 << 20 ? 1 << 20 : $len - $got));
            last unless $n;
            $got += $n;
        }
        my $auth = ($h{authorization} // '') eq "Bearer $expected";
        my %rec = (method => $method, path => $path, received => $got, credential_ok => $auth ? JSON::PP::true : JSON::PP::false,
                   map { (my $k = $_) =~ s/^shipment-//; ($k => $h{$_}) } grep { /^shipment-/ } keys %h);
        my ($status, $reason, $body);
        if ($method ne 'POST' || $path ne '/shipments') {
            ($status, $reason, $body) = (404, 'Not Found', '{"error":"not found"}');
        } elsif (!$auth) {
            ($status, $reason, $body) = (401, 'Unauthorized', '{"error":"credential"}');
        } elsif (mode() eq 'refuse') {
            ($status, $reason, $body) = (503, 'Service Unavailable', '{"error":"the vault refuses shipments now"}');
        } else {
            my $size = mode() eq 'short' ? $got - 1 : $got;
            ($status, $reason) = (201, 'Created');
            $body = $json->encode({shipment_id => $h{'shipment-id'}, type => $h{'shipment-type'},
                                   rows_declared => 0 + ($h{'shipment-rows'} // 0), rows_received => 1,
                                   size => $size, received_at => strftime('%Y-%m-%dT%H:%M:%SZ', gmtime())});
        }
        $rec{status} = $status;
        open(my $log, '>>', "$DIR/shipments.ndjson") or die "log: $!\n";
        print {$log} $json->encode(\%rec), "\n";
        close($log);
        answer($c, $status, $reason, $body);
        alarm 0;
    };
    print "request failed: $@" if $@;
    close($c);
}
