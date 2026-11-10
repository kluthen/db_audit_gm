-- vet-portal-messages' history (v0.5 master spec 12.1, 12.2 purpose 16;
-- vet-portal-domain.md, "vet-portal-messages", "History"; spec D401, D404,
-- D432; capture W4 items 0, 6 and 7 of specs/versions/v0.5/wave-log.md): what
-- the messaging service received in the 14 days before T0, so the owners'
-- route finds its invitations' and resets' tokens, its reminders' keys and
-- its recent recipients from the start. No periodic job extends it (no
-- feeder, chunk 29's (c)).
--
-- Named by purpose.yaml's history:. load-data runs it after the domains'
-- loads and the derivations, as postgres, unseen, in the target database
-- (the partners' database, partners, where the stub's data.sql, copied into
-- partners-db's data file, has made messaging.messages), the portal read
-- through postgres_fdw as gm_check, as gm_src_source: portal_outbox under its
-- forced row-level security, through the gm_check_read policy load-data's
-- step (2c) adds (W4 item 7; refused below when the read returns nothing).
--
-- Planted: every outbox row sent in the 14 days before load_epoch, as the
-- service received it (received_at = sent_at, its provider_id the
-- derivation's). Then owners (vet-portal's owners' traffic, whose data.sql
-- runs after partners-db's data file) may read the messages.
\if :{?load_epoch}
SELECT :'load_epoch'::timestamptz AS pm_t0 \gset
\else
SELECT now() AS pm_t0 \gset
\endif

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM gm_src_source.portal_outbox LIMIT 1) THEN
        RAISE EXCEPTION 'vet-portal-messages history: portal_outbox reads no row as gm_check '
                        '(the derivation not run, or its gm_check_read policy missing)';
    END IF;
END $$;

INSERT INTO messaging.messages (message_key, provider_id, channel, address, template, account_id, payload,
                                received_at)
SELECT o.message_key, o.provider_id, o.channel, o.address, o.template, o.account_id, o.payload, o.sent_at
  FROM gm_src_source.portal_outbox AS o
 WHERE o.sent_at IS NOT NULL AND o.provider_id IS NOT NULL
   AND o.sent_at >= :'pm_t0'::timestamptz - interval '14 days' AND o.sent_at < :'pm_t0'::timestamptz
ON CONFLICT (message_key) DO NOTHING;

DO $$ BEGIN IF to_regrole('owners') IS NOT NULL THEN
GRANT USAGE ON SCHEMA messaging TO owners;
GRANT SELECT ON messaging.messages TO owners;
END IF; END $$;
