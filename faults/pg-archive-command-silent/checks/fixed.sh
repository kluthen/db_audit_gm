#!/bin/sh
# Sealed check of pg-archive-command-silent (v0.5 master spec 17.2, s2;
# capture W5 item 2; spec D382). Run as root on the archiving database node,
# fed to `sh -s` by gmctl check. Live state: the latest segment
# pg_stat_archiver counts archived (read as the GM check role through
# check-psql) must have a wal manifest from this node in the vault, read on
# cold storage's public GET /manifests (Perl HTTP::Tiny, as vault-post; no
# curl on a database node). The vault is evidence, never judged (master spec
# 6.3): a vault that cannot be read is an error, not a verdict.
#
# The node's latest manifest is found by received_at, never by name: the
# vault's planted history (partners/coldstore/planted.sql) names segments
# that sort above a fresh cluster's live ones (spec D382, a setup limit).
#
# Exit 0: the latest segment archived is in the vault (a segment switched
# after the fix). Exit 1: it is not: the archiver counts segments the vault
# never received. Exit 3: no segment archived yet since the server started.
# Exit 2: PostgreSQL or the vault cannot be read, or no vault is configured.
set -u
CHECK_PSQL=/usr/local/lib/gm/check-psql
TARGET_FILE=/run/gm-vault/target

cannot() { echo "the archive cannot be judged: $*"; exit 2; }
[ -x "$CHECK_PSQL" ] || cannot "no $CHECK_PSQL on this node (postgres 0.5.0 needed)"
[ -r "$TARGET_FILE" ] || cannot "no vault configured on this node ($TARGET_FILE: the node's vault_target is unset)"
target=$(head -n 1 "$TARGET_FILE")

# last archived segment|its time (UTC)|the day before it|archived|failed
row=$("$CHECK_PSQL" -d postgres -Atq -v ON_ERROR_STOP=1 <<'SQL'
SELECT coalesce(last_archived_wal, '') || '|' ||
       coalesce(to_char(last_archived_time AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI:SS'), '') || '|' ||
       coalesce(to_char((last_archived_time AT TIME ZONE 'UTC')::date - 1, 'YYYY-MM-DD'), '') || '|' ||
       archived_count || '|' || failed_count
  FROM pg_stat_archiver
SQL
) || cannot "pg_stat_archiver cannot be read as the GM check role"
seg=$(printf '%s' "$row" | cut -d'|' -f1)
at=$(printf '%s' "$row" | cut -d'|' -f2)
since=$(printf '%s' "$row" | cut -d'|' -f3)
archived=$(printf '%s' "$row" | cut -d'|' -f4)
failed=$(printf '%s' "$row" | cut -d'|' -f5)
if [ -z "$seg" ]; then
    echo "too soon to tell: pg_stat_archiver reports no segment archived since the server started (switch one with SELECT pg_switch_wal(), or wait archive_timeout)"
    exit 3
fi

# The vault's answer: "found <received_at>" or "missing", then the node's
# latest wal manifest by received_at, "<name> <received_at>" or "none";
# exit 2 with the reason when the vault cannot be read.
answer=$(perl -e '
use strict; use warnings;
use HTTP::Tiny; use JSON::PP ();
use Sys::Hostname qw(hostname);
my ($target, $seg, $since) = @ARGV;
(my $source = hostname()) =~ s/\..*//;
my $url = "http://$target/manifests?type=wal&source=$source" . ($since ne "" ? "&from=$since" : "");
my $res = HTTP::Tiny->new(timeout => 20, agent => "gm-check ($source)")->get($url);
if (!$res->{success}) {
    my $why = $res->{status} == 599 ? ($res->{content} // "no answer") : "$res->{status} $res->{reason}";
    $why =~ s/\s+/ /g;
    print "GET $url: " . substr($why, 0, 160) . "\n";
    exit 2;
}
my $list = eval { JSON::PP->new->decode($res->{content}) };
if (ref $list ne "ARRAY") { print "GET $url: no JSON list\n"; exit 2; }
my ($found, $latest);
for my $m (@$list) {
    next unless ref $m eq "HASH" && ($m->{type} // "") eq "wal" && ($m->{source} // "") eq $source;
    $found = $m->{received_at} if ($m->{name} // "") eq $seg;
    $latest = $m if !defined $latest || ($m->{received_at} // "") gt ($latest->{received_at} // "");
}
print defined $found ? "found $found\n" : "missing\n";
print defined $latest ? "$latest->{name} $latest->{received_at}\n" : "none\n";
' "$target" "$seg" "$since") || cannot "the vault at $target cannot be read: $(printf '%s' "$answer" | head -n 1)"

verdict=$(printf '%s\n' "$answer" | sed -n 1p)
latest=$(printf '%s\n' "$answer" | sed -n 2p)
case $verdict in
    found\ *)
        echo "the latest segment archived, $seg ($at UTC), is in the vault (received at ${verdict#found }): the archive ships."
        exit 0 ;;
    missing)
        if [ "$latest" = none ]; then latest="no wal manifest from this node since $since"
        else latest="this node's latest wal manifest, by received_at, is ${latest% *} (received at ${latest#* })"; fi
        echo "pg_stat_archiver reports $seg archived at $at UTC ($archived archived, $failed failed), but the vault holds no manifest naming it; $latest."
        exit 1 ;;
    *)
        cannot "unexpected answer from the vault's reading: $verdict" ;;
esac
