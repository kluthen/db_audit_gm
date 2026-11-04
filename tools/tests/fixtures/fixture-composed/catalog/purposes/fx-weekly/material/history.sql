-- fx-weekly's history (tools/tests, v0.5 chunk 8): the past weeks' counts,
-- planted in its target, reading its source through gm_src_source.
INSERT INTO weekly_stays (week, stays)
SELECT date_trunc('week', s.admitted_at)::date AS c8_history_canary, count(*)
  FROM gm_src_source.stays s
 GROUP BY 1;
