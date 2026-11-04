-- The test part's derivation (tools/tests, v0.5 chunk 8): each stay's document
-- copies it field by field, read through gm_src_fx_core.
INSERT INTO documents (stay_id, title, digest)
SELECT s.id, a.name || ' (' || a.species || ')' AS c8_derive_canary,
       encode(digest(a.name || s.admitted_at::text, 'sha256'), 'hex')
  FROM gm_src_fx_core.stays s JOIN gm_src_fx_core.animals a ON a.id = s.animal_id
 WHERE s.id BETWEEN pg_temp.core_stay(1) AND pg_temp.core_stay(6);
