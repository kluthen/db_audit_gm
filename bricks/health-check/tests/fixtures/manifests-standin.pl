#!/usr/bin/perl
# A stand-in for cold storage's GET /manifests (v0.5 capture W2 item 6;
# spec D362), for the health-check brick's stack test only: chunk 11
# builds the real stub. One request at a time on port 8000. It answers by
# the mode in /srv/standin/mode:
#   found    200, one basebackup manifest of db, received today;
#   missing  200, an empty list;
#   broken   200, a body that is not JSON.
# Each request line is appended to /srv/standin/requests.log. Core Perl only.
use strict;
use warnings;
use IO::Socket::INET;
use JSON::PP;
use POSIX qw(strftime);

my $DIR = '/srv/standin';
mkdir $DIR;
my $server = IO::Socket::INET->new(LocalPort => 8000, Listen => 16, ReuseAddr => 1, Proto => 'tcp')
    or die "listen: $!\n";
$| = 1;
print "manifests stand-in listening on 8000\n";

sub mode {
    open(my $fh, '<', "$DIR/mode") or return 'found';
    my $m = <$fh> // 'found';
    $m =~ s/\s+//g;
    return $m || 'found';
}

while (my $c = $server->accept) {
    $c->autoflush(1);
    local $SIG{ALRM} = sub { die "timeout\n" };
    eval {
        alarm 30;
        my $line = <$c> // die "no request\n";
        $line =~ s/\r?\n\z//;
        while (defined(my $l = <$c>)) { $l =~ s/\r?\n\z//; last if $l eq ''; }
        my ($method, $target) = split / /, $line;
        open(my $log, '>>', "$DIR/requests.log") or die "log: $!\n";
        print {$log} "$method $target\n";
        close $log;
        my ($status, $body) = (200, '[]');
        if ($method ne 'GET' || $target !~ m{^/manifests(\?|$)}) {
            ($status, $body) = (404, '{"detail":"not found"}');
        } elsif (mode() eq 'found') {
            my $today = strftime('%Y-%m-%d', gmtime());
            $body = JSON::PP->new->canonical->encode([{
                shipment_id => "db-basebackup-$today", type => 'basebackup', source => 'db',
                name => "base-$today.tar", rows_declared => 1, rows_received => 1, size => 4194304,
                date_from => $today, date_to => $today,
                received_at => strftime('%Y-%m-%dT%H:%M:%SZ', gmtime())}]);
        } elsif (mode() eq 'broken') {
            $body = '<html>maintenance</html>';
        }
        print {$c} "HTTP/1.1 $status " . ($status == 200 ? 'OK' : 'Not Found')
            . "\r\nContent-Type: application/json\r\nContent-Length: " . length($body)
            . "\r\nConnection: close\r\n\r\n$body";
        alarm 0;
    };
    print "request failed: $@" if $@;
    close($c);
}
