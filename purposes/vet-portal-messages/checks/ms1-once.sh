#!/bin/sh
# MS1 once (vet-portal-messages, purpose 16; vet-portal-domain.md,
# "vet-portal-messages"): in the portal's outbox, no document and account with
# two document-notice rows, no animal and due day with two reminder rows,
# among the pairs queued since the judged moment; at the messaging service
# (messaging.messages), no two messages for one notice (the account, the
# template document-notice, the payload's link) or one reminder (the account,
# the payload's animal and due_on), among those received since the judged
# moment. Judges runs (T288 the outbox's partial uniques dropped and the
# margin's re-reads queueing again; a retry under a new message key after a
# 503 or a timeout).
#
# Runs on the partners' database node (partners-db) as root, fed to `sh -s`
# by gmctl check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ), the judged moment
# as given (W4 item 0: a check needing a partner's side runs there): the
# service's record (messaging.messages, messaging.message_calls) in partners
# through check-psql, the outbox in portal through check-psql --node records
# (through the GM's read policy gm_check_read, spec D432: no verdict when it
# is gone or a restrictive policy hides rows); all as gm_check, no job is
# ever run. POSIX sh (the postgres image has no python3). The witness is the
# messages received since the judged moment, with the 503s retried with
# their key (a key answered 503, later 202). Exit 0 fixed (with its witness,
# 12.3), 1 present, 2 cannot judge, 3 too soon (remaining=TOO_SOON: no
# message received yet; queue-notices runs every five minutes and this node
# has no runner's check-runs to ask). Written for the clinic's names (the
# constants below); the GM adapts them as it copies the purpose.
INVARIANT=MS1
PARTNERS=partners                    # the target part's database (the service's record), on this node
NODE=records                         # the source part's node
PORTAL=portal                        # the source part's database
TOO_SOON=300                         # seconds to wait for a message
PURPOSE=vet-portal-messages
PSQL=/usr/local/lib/gm/check-psql

cannot() { echo "$INVARIANT cannot be judged: $*"; exit 2; }

since=${CHECK_SINCE:-}
case $since in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z) ;;
    *) cannot "CHECK_SINCE ($since) is not YYYY-MM-DDTHH:MM:SSZ" ;;
esac

# q <node|-> <database> [psql -v ...]: the statement on standard input, its
# rows on standard output (columns joined by |); 2 on any failure.
q() {
    where=$1 db=$2
    shift 2
    if [ "$where" = - ]; then
        "$PSQL" -d "$db" -Atq -F '|' -v ON_ERROR_STOP=1 -v since="$since" "$@" 2>&1
    else
        "$PSQL" --node "$where" -d "$db" -Atq -F '|' -v ON_ERROR_STOP=1 -v since="$since" "$@" 2>&1
    fi
}

# The guard (spec D432): the first reason gm_check would not read every row
# of the portal's tables it reads, or nothing.
why=$(q "$NODE" "$PORTAL" -v tables=portal_outbox <<'SQL'
SELECT why FROM (
SELECT t.i,
       CASE WHEN c.oid IS NULL THEN t.name || ' is not in ' || current_database()
            WHEN NOT EXISTS (SELECT 1 FROM pg_policies p WHERE p.schemaname = n.nspname
                                AND p.tablename = c.relname AND p.policyname = 'gm_check_read')
                 THEN 'the GM''s read policy on ' || t.name || ' is gone'
            WHEN NOT EXISTS (SELECT 1 FROM pg_policies p WHERE p.schemaname = n.nspname
                                AND p.tablename = c.relname AND p.policyname = 'gm_check_read'
                                AND p.permissive = 'PERMISSIVE' AND p.cmd IN ('SELECT', 'ALL')
                                AND p.qual = 'true' AND p.roles && ARRAY['public', 'gm_check']::name[])
                 THEN 'the GM''s read policy on ' || t.name || ' is changed: it no longer shows gm_check every row'
            WHEN r.name IS NOT NULL
                 THEN 'a restrictive policy ' || r.name || ' on ' || t.name || ' hides rows from gm_check'
       END AS why
  FROM unnest(string_to_array(:'tables', ',')) WITH ORDINALITY AS t (name, i)
  LEFT JOIN pg_class c ON c.oid = to_regclass(t.name)
  LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
  LEFT JOIN LATERAL (SELECT min(p.policyname) AS name FROM pg_policies p
                      WHERE p.schemaname = n.nspname AND p.tablename = c.relname
                        AND p.permissive = 'RESTRICTIVE' AND p.cmd IN ('SELECT', 'ALL')
                        AND EXISTS (SELECT 1 FROM unnest(p.roles) AS x (role)
                                     WHERE CASE WHEN x.role = 'public' THEN true
                                                ELSE pg_has_role('gm_check', x.role, 'MEMBER') END)) r ON true
) AS g WHERE why IS NOT NULL ORDER BY i LIMIT 1
SQL
) || cannot "reading $NODE/$PORTAL: $why"
[ -z "$why" ] || cannot "$why"

# The outbox: each pair queued since the judged moment with more than one row.
twice=$(q "$NODE" "$PORTAL" <<'SQL'
SELECT 'document ' || document_id || ' and account ' || account_id || ' have ' || count(*) || ' notices'
  FROM portal_outbox o
 WHERE template = 'document-notice'
   AND (document_id, account_id) IN (SELECT document_id, account_id FROM portal_outbox
                                      WHERE template = 'document-notice' AND queued_at > :'since'::timestamptz)
 GROUP BY document_id, account_id HAVING count(*) > 1
UNION ALL
SELECT 'animal ' || animal_id || ' due on ' || due_on || ' has ' || count(*) || ' reminders'
  FROM portal_outbox o
 WHERE template = 'reminder'
   AND (animal_id, due_on) IN (SELECT animal_id, due_on FROM portal_outbox
                                WHERE template = 'reminder' AND queued_at > :'since'::timestamptz)
 GROUP BY animal_id, due_on HAVING count(*) > 1
ORDER BY 1
SQL
) || cannot "reading $NODE/$PORTAL: $twice"
if [ -n "$twice" ]; then
    n=$(printf '%s\n' "$twice" | wc -l | tr -d ' ')
    more=
    [ "$n" -gt 1 ] && more=" ($n pairs queued since $since)"
    echo "$INVARIANT present: in the outbox, $(printf '%s\n' "$twice" | head -n 1)$more"
    exit 1
fi

# The service: each notice or reminder received twice (its messages' keys),
# then the witness: the messages received, the 503s retried with their key.
seen=$(q - "$PARTNERS" <<'SQL'
WITH m AS (
    SELECT message_key, account_id, received_at,
           CASE WHEN template = 'document-notice' THEN 'notice ' || coalesce(payload ->> 'link', '(no link)')
                WHEN template = 'reminder' THEN 'reminder of animal ' || coalesce(payload ->> 'animal', '?')
                                                || ' due on ' || coalesce(payload ->> 'due_on', '?')
           END AS what
      FROM messaging.messages
     WHERE template IN ('document-notice', 'reminder')
),
dup AS (
    SELECT account_id, what, count(*) AS n, string_agg(message_key::text, ' ' ORDER BY received_at) AS keys
      FROM m
     WHERE (account_id, what) IN (SELECT account_id, what FROM m WHERE received_at > :'since'::timestamptz)
     GROUP BY account_id, what HAVING count(*) > 1
)
SELECT 'twice|' || CASE WHEN what LIKE 'notice %' THEN 'a document notice' ELSE 'a reminder' END
       || ' for account ' || account_id || ' received ' || n || ' times (message keys ' || keys || ')'
  FROM dup
UNION ALL
SELECT 'n|' || (SELECT count(*) FROM messaging.messages WHERE received_at > :'since'::timestamptz) || '|'
       || (SELECT count(DISTINCT c.message_key) FROM messaging.message_calls c
            WHERE c.status = 503 AND c.at > :'since'::timestamptz
              AND EXISTS (SELECT 1 FROM messaging.message_calls d
                           WHERE d.message_key = c.message_key AND d.status = 202 AND d.at > c.at))
SQL
) || cannot "reading $PARTNERS: $seen"
dup=$(printf '%s\n' "$seen" | sed -n 's/^twice|//p')
if [ -n "$dup" ]; then
    n=$(printf '%s\n' "$dup" | wc -l | tr -d ' ')
    more=
    [ "$n" -gt 1 ] && more=" ($n notices or reminders received since $since)"
    echo "$INVARIANT present: at the service, $(printf '%s\n' "$dup" | head -n 1)$more"
    exit 1
fi
counts=$(printf '%s\n' "$seen" | sed -n 's/^n|//p')
received=${counts%%|*}
retried=${counts#*|}
case $received in
    ''|*[!0-9]*) cannot "reading $PARTNERS: no count of the messages received" ;;
esac
if [ "$received" -eq 0 ]; then
    echo "remaining=$TOO_SOON no message received at the service since $since"
    exit 3
fi
echo "$INVARIANT fixed: $received messages received at the service since $since, each notice and reminder" \
     "once, in the outbox and at the service; $retried keys answered 503 and later accepted with the same key"
exit 0
