#!/usr/bin/perl
# node-health: this node's health in Prometheus' text format, on port 9110
# (v0.2 master spec 7.1). Companion material of the `prometheus` brick,
# mounted by the GM into every node of a game that has a `prometheus` node;
# versioned with that brick. DO NOT TAMPER: root-owned and read-only.
#
# Reads /opt/gm/node-health/node.conf (one key=value a line, written per node
# by the GM): node, services, disk_reservation (bytes), volumes (paths).
#
# One s6 service (gm-node-health), two processes:
#   - the sampler, root: every 5 s the status of the listed services
#     (s6-svstat: their supervise/ directories are root-only), every 30 s the
#     space used by the node's volumes (du: some belong to other accounts with
#     mode 0700) and the host's free space (df); writes them to
#     /run/gm-node-health/sample.prom. It keeps no socket open.
#   - the listener, forked by the sampler, runs as nobody:nogroup and answers
#     GET /metrics: CPU and memory read from the node's own cgroup v2 files
#     (/sys/fs/cgroup) at request time, then the latest sample.
# Only perl-base modules; commands: s6-svstat, du, df.
use strict;
use warnings;
use IO::Socket::INET;
use POSIX ();

my $CONF          = '/opt/gm/node-health/node.conf';
my $PORT          = 9110;
my $STATE_DIR     = '/run/gm-node-health';
my $SAMPLE        = "$STATE_DIR/sample.prom";
my $CGROUP        = '/sys/fs/cgroup';
my $SERVICE_DIR   = '/run/service';
my $SERVICE_EVERY = 5;     # seconds between two service samples
my $DISK_EVERY    = 6;     # service samples between two disk samples (30 s)
my $ACCOUNT       = 'nobody';

$| = 1;
sub logmsg { print STDERR "gm-node-health: @_\n" }

# --- configuration ----------------------------------------------------------
sub read_conf {
    my ($path) = @_;
    open(my $fh, '<', $path) or return (undef, "cannot read $path: $!");
    my %c;
    while (my $line = <$fh>) {
        $line =~ s/\r?\n\z//;
        next if $line =~ /^\s*(#|$)/;
        return (undef, "$path:$.: not a key=value line") unless $line =~ /^([a-z_]+)=(.*)$/;
        $c{$1} = $2;
    }
    close $fh;
    for my $k (qw(node services disk_reservation volumes)) {
        return (undef, "$path: key $k is missing") unless defined $c{$k};
    }
    return (undef, "$path: node: not a node name") unless $c{node} =~ /^[A-Za-z0-9][A-Za-z0-9_.-]*$/;
    return (undef, "$path: disk_reservation: not a number of bytes") unless $c{disk_reservation} =~ /^[0-9]+$/;
    my @services = split ' ', $c{services};
    for (@services) {
        return (undef, "$path: services: $_ is not a service name") unless /^[A-Za-z0-9_][A-Za-z0-9_.-]*$/;
    }
    my @volumes = split ' ', $c{volumes};
    for (@volumes) {
        return (undef, "$path: volumes: $_ is not an absolute path") unless m{^/} && !m{(^|/)\.\.?(/|$)};
    }
    return ({ node => $c{node}, services => \@services,
              disk_reservation => $c{disk_reservation}, volumes => \@volumes }, undef);
}

# --- Prometheus text format ---------------------------------------------------
sub esc { my $v = shift; $v =~ s/([\\"])/\\$1/g; $v =~ s/\n/\\n/g; return $v }

sub family {    # family(name, type, help, [[labels-hashref, value], ...])
    my ($name, $type, $help, @samples) = @_;
    return '' unless @samples;
    my $out = "# HELP $name $help\n# TYPE $name $type\n";
    for my $s (@samples) {
        my ($labels, $value) = @$s;
        my $l = join(',', map { "$_=\"" . esc($labels->{$_}) . '"' } sort keys %$labels);
        $out .= "$name\{$l\} $value\n";
    }
    return $out;
}

# Run a command (no shell), stdout returned, stderr discarded.
sub run_cmd {
    my @cmd = @_;
    my $pid = open(my $fh, '-|');
    return undef unless defined $pid;
    if ($pid == 0) {
        open(STDERR, '>', '/dev/null');
        exec { $cmd[0] } @cmd or POSIX::_exit(127);
    }
    local $/;
    my $out = <$fh>;
    close $fh;
    return defined $out ? $out : '';
}

# --- sampler (root) ---------------------------------------------------------------
sub sample_services {
    my ($c) = @_;
    my (@up, @wanted, @since);
    for my $svc (@{ $c->{services} }) {
        my %l = (node => $c->{node}, service => $svc);
        my $out = run_cmd('s6-svstat', '-o', 'up,wantedup,updownfor', "$SERVICE_DIR/$svc");
        if (defined $out && $? == 0 && $out =~ /^(true|false) (true|false) (\d+)/) {
            push @up,     [\%l, $1 eq 'true' ? 1 : 0];
            push @wanted, [\%l, $2 eq 'true' ? 1 : 0];
            push @since,  [\%l, $3];
        } else {
            push @up, [\%l, 0];    # no such service, or no supervisor: down
        }
    }
    return family('node_health_service_up', 'gauge',
                  'Whether the service is up under s6 (s6-svstat), 1 or 0.', @up)
         . family('node_health_service_wanted_up', 'gauge',
                  'Whether s6 is asked to keep the service up, 1 or 0 (0 after s6-svc -d).', @wanted)
         . family('node_health_service_state_seconds', 'gauge',
                  'Seconds since the service last went up or down.', @since);
}

sub sample_disk {
    my ($c) = @_;
    my %n = (node => $c->{node});
    my (@vol, $total);
    if (@{ $c->{volumes} }) {
        my $out = run_cmd('du', '-s', '-k', '-x', '--', @{ $c->{volumes} }) // '';
        for my $line (split /\n/, $out) {
            next unless $line =~ /^(\d+)\t(.+)$/;
            push @vol, [{ %n, path => $2 }, $1 * 1024];
            $total += $1 * 1024;
        }
    }
    my $text = family('node_health_volume_used_bytes', 'gauge',
                      'Space used by one of the node\'s volumes (du).', @vol)
             . family('node_health_disk_used_bytes', 'gauge',
                      'Space used by all the node\'s volumes (du), against its disk reservation.',
                      [\%n, $total // 0])
             . family('node_health_disk_reservation_bytes', 'gauge',
                      'The node\'s declared disk reservation.', [\%n, $c->{disk_reservation}]);
    my $where = @{ $c->{volumes} } ? $c->{volumes}[0] : '/';
    my $df = run_cmd('df', '-P', '-k', '--', $where) // '';
    if ($df =~ /\n\S+\s+(\d+)\s+\d+\s+(\d+)\s/) {
        $text .= family('node_health_host_free_bytes', 'gauge',
                        'Free space on the host filesystem holding the volumes (df); the same on every node of a host.',
                        [\%n, $2 * 1024])
               . family('node_health_host_size_bytes', 'gauge',
                        'Size of the host filesystem holding the volumes (df).', [\%n, $1 * 1024]);
    }
    return $text;
}

sub write_sample {
    my ($text) = @_;
    my $tmp = "$SAMPLE.tmp";
    open(my $fh, '>', $tmp) or do { logmsg("cannot write $tmp: $!"); return };
    print $fh $text;
    close $fh or do { logmsg("cannot write $tmp: $!"); return };
    chmod 0644, $tmp;
    rename $tmp, $SAMPLE or logmsg("cannot rename $tmp: $!");
}

# --- listener (nobody) --------------------------------------------------------------
sub read_file {
    my ($path) = @_;
    open(my $fh, '<', $path) or return undef;
    local $/;
    my $v = <$fh>;
    close $fh;
    return $v;
}

sub keyed {    # value of <key> in a "key value" cgroup file
    my ($text, $key) = @_;
    return (defined $text && $text =~ /^\Q$key\E (\d+)$/m) ? $1 : undef;
}

sub cgroup_metrics {
    my ($c) = @_;
    my %n = (node => $c->{node});
    my $text = '';
    my $cpu = read_file("$CGROUP/cpu.stat");
    if (defined(my $u = keyed($cpu, 'usage_usec'))) {
        $text .= family('node_health_cpu_seconds_total', 'counter',
                        'CPU time used by the node (cgroup cpu.stat usage_usec).', [\%n, $u / 1e6]);
    }
    if (defined(my $t = keyed($cpu, 'throttled_usec'))) {
        $text .= family('node_health_cpu_throttled_seconds_total', 'counter',
                        'Time the node was held back by its CPU limit (cgroup cpu.stat throttled_usec).',
                        [\%n, $t / 1e6]);
    }
    my $max = read_file("$CGROUP/cpu.max");
    if (defined $max && $max =~ /^(\d+) (\d+)/ && $2 > 0) {
        $text .= family('node_health_cpu_limit_cores', 'gauge',
                        'The node\'s CPU limit in CPUs (cgroup cpu.max).', [\%n, $1 / $2]);
    }
    my $current = read_file("$CGROUP/memory.current");
    if (defined $current && $current =~ /^(\d+)/) {
        my $used = $1;
        my $inactive = keyed(read_file("$CGROUP/memory.stat"), 'inactive_file') // 0;
        my $ws = $used - $inactive;
        $text .= family('node_health_memory_used_bytes', 'gauge',
                        'Memory charged to the node, page cache included (cgroup memory.current).', [\%n, $used])
               . family('node_health_memory_working_set_bytes', 'gauge',
                        'Memory used less the inactive page cache, what the limit is measured against in practice.',
                        [\%n, $ws > 0 ? $ws : 0]);
    }
    my $mmax = read_file("$CGROUP/memory.max");
    if (defined $mmax && $mmax =~ /^(\d+)/) {
        $text .= family('node_health_memory_limit_bytes', 'gauge',
                        'The node\'s memory limit (cgroup memory.max).', [\%n, $1]);
    }
    if (defined(my $oom = keyed(read_file("$CGROUP/memory.events"), 'oom_kill'))) {
        $text .= family('node_health_memory_oom_kills_total', 'counter',
                        'Processes of the node killed for lack of memory (cgroup memory.events oom_kill).',
                        [\%n, $oom]);
    }
    return $text;
}

sub metrics {
    my ($c) = @_;
    my $text = cgroup_metrics($c);
    my $sample = read_file($SAMPLE);
    my @st = stat($SAMPLE);
    if (defined $sample && @st) {
        $text .= $sample
               . family('node_health_sample_age_seconds', 'gauge',
                        'Age of the latest disk and service sample.',
                        [{ node => $c->{node} }, time() - $st[9]]);
    }
    return $text;
}

sub respond {
    my ($sock, $status, $body, $head) = @_;
    my $type = $status =~ /^200/ ? 'text/plain; version=0.0.4; charset=utf-8' : 'text/plain; charset=utf-8';
    print $sock "HTTP/1.0 $status\r\nContent-Type: $type\r\nContent-Length: "
              . length($body) . "\r\nConnection: close\r\n\r\n" . ($head ? '' : $body);
}

sub serve {
    my ($c) = @_;
    $SIG{PIPE} = 'IGNORE';
    my $server = IO::Socket::INET->new(LocalAddr => '0.0.0.0', LocalPort => $PORT, Proto => 'tcp',
                                       Listen => 16, ReuseAddr => 1)
        or die "cannot listen on port $PORT: $@\n";
    logmsg("node $c->{node}: serving /metrics on port $PORT as $ACCOUNT");
    while (1) {
        my $sock = $server->accept or next;
        my $request = eval {
            local $SIG{ALRM} = sub { die "timeout\n" };
            alarm 5;
            my $first = <$sock>;
            while (defined(my $h = <$sock>)) { last if $h =~ /^\r?\n\z/ }
            alarm 0;
            $first;
        };
        alarm 0;
        if (defined $request && $request =~ m{^(GET|HEAD) (/[^ ?]*)\S* HTTP/1\.[01]\r?\n\z}) {
            my ($method, $path) = ($1, $2);
            if ($path eq '/metrics') {
                respond($sock, '200 OK', metrics($c), $method eq 'HEAD');
            } elsif ($path eq '/') {
                respond($sock, '200 OK', "node-health of $c->{node}: see /metrics\n", $method eq 'HEAD');
            } else {
                respond($sock, '404 Not Found', "not found; see /metrics\n", $method eq 'HEAD');
            }
        } elsif (defined $request && $request =~ /^[A-Z]+ /) {
            respond($sock, '405 Method Not Allowed', "GET /metrics only\n");
        }
        close $sock;
    }
}

sub drop_privileges {
    my ($uid, $gid) = (getpwnam($ACCOUNT))[2, 3];
    die "no account $ACCOUNT\n" unless defined $uid;
    $) = "$gid $gid";
    POSIX::setgid($gid) or die "setgid $gid: $!\n";
    POSIX::setuid($uid) or die "setuid $uid: $!\n";
    die "privileges not dropped\n" if $< == 0 || $> == 0 || $( == 0 || $) =~ /\b0\b/;
}

# --- main ----------------------------------------------------------------------------
my ($c, $err) = read_conf($CONF);
unless ($c) {
    # A missing or broken per-node file is the GM's to fix: say so, then let
    # s6 start the service again, slowly.
    logmsg("fatal: $err");
    sleep 30;
    exit 1;
}
mkdir $STATE_DIR, 0755 unless -d $STATE_DIR;
chmod 0755, $STATE_DIR;
my $disk = sample_disk($c);
write_sample($disk . sample_services($c));

my $listener = fork;
die "fork: $!\n" unless defined $listener;
if ($listener == 0) {
    drop_privileges();
    serve($c);
    exit 0;
}
$SIG{TERM} = $SIG{INT} = sub { kill 'TERM', $listener; exit 0 };
my $round = 0;
while (1) {
    sleep $SERVICE_EVERY;
    if (waitpid($listener, POSIX::WNOHANG()) == $listener) {
        logmsg("the listener exited (status $?); restarting");
        exit 1;
    }
    $round++;
    $disk = sample_disk($c) if $round % $DISK_EVERY == 0;
    write_sample($disk . sample_services($c));
}
