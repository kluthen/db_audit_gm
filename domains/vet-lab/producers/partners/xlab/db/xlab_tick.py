"""The external lab's tick, its database side (vet-lab's xlab stub): the
send-outs due, as the role xlab, and their answers posted to lab-api through
the connection xlab-lab. An answer is the lab's report for its test, built
once from the send-out's own columns (a hash of its send_key, never random)
and kept in xlab.orders.answer with the number of times it was posted; a
chase (resends) above that number posts it again. An answer lab-api refuses
(an error status, a timeout) stays due for the next tick."""

import hashlib
import json

import gm_api

BATCH = 5
UTC = "'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'"

# What each kind of test reports, by the analyte codes the centre's lab knows
# (vet-lab's lab_analytes): hormones and lead a number in their range, the
# molecular tests a qualitative result, every other test a written report.
NUMERIC = {"NL-TT4": ("T4", "nmol/L", 13, 51), "NL-FT4": ("T4", "nmol/L", 13, 51),
           "NL-ACTHST": ("CORT", "nmol/L", 25, 150), "NL-LDDS": ("CORT", "nmol/L", 25, 150),
           "NL-EACTH": ("ACTH", "pg/mL", 9, 35), "NL-PB": ("PB", "umol/L", 0, 0.5)}
MOLECULAR = {"NL-PCRSA", "NL-STREP", "NL-BVDPCR", "NL-BTPCR", "NL-FMDPCR", "NL-EHV1", "NL-LEPPCR",
             "NL-FCVPCR", "NL-CRDPCR", "NL-MYCPCR", "NL-BABPCR", "NL-AHSPCR"}
REPORTS = ("No significant abnormality detected.", "Findings consistent with chronic inflammation.",
           "Neoplasia not identified in the sections examined.", "Within the reference range for the species.",
           "Moderate changes; correlate with clinical findings.")


def _u(send_key, salt):
    return int(hashlib.sha256(f"{send_key}:{salt}".encode()).hexdigest()[:8], 16) / 2 ** 32


def answer(send_key, accession, test_code, resulted_at):
    """The body posted to lab-api for one send-out."""
    if test_code in NUMERIC:
        analyte, unit, low, high = NUMERIC[test_code]
        value = round(low + (high - low) * (1.3 * _u(send_key, 1) - 0.1), 2)
        flag = "low" if value < low else "high" if value > high else "normal"
        result = {"analyte": analyte, "numeric_value": value, "unit": unit, "flag": flag}
    elif test_code in MOLECULAR:
        result = {"analyte": "QUAL", "text_value": "positive" if _u(send_key, 2) < 0.08 else "negative"}
    else:
        result = {"analyte": "REPORT", "text_value": REPORTS[int(_u(send_key, 3) * len(REPORTS))]}
    return {"accession": accession, "resulted_at": resulted_at, "results": [result]}


def tick():
    """-> {posted, refused}."""
    with gm_api.connection("xlab-db") as conn:
        due = conn.execute(
            f"SELECT send_key::text, accession, test_code, answer, to_char(now() AT TIME ZONE 'UTC', {UTC}) "
            "FROM xlab.orders WHERE due_at <= now() "
            "AND (answered_at IS NULL OR coalesce((answer->>'posts')::integer, 0) <= resends) "
            "ORDER BY due_at, send_key LIMIT %s", (BATCH,)).fetchall()
    lab = gm_api.client("xlab-lab")
    posted = refused = 0
    for send_key, accession, test_code, kept, now in due:
        body = {k: v for k, v in kept.items() if k != "posts"} if kept else answer(send_key, accession,
                                                                                    test_code, now)
        try:
            ok = lab.post(f"/send-outs/{send_key}/result", body).status == 200
        except gm_api.HttpError:
            ok = False
        if not ok:
            refused += 1
            continue
        posted += 1
        with gm_api.connection("xlab-db") as conn:
            conn.execute(
                "UPDATE xlab.orders SET answered_at = coalesce(answered_at, now()), "
                "answer = %s::jsonb || jsonb_build_object('posts', coalesce((answer->>'posts')::integer, 0) + 1) "
                "WHERE send_key = %s", (json.dumps(body), send_key))
            conn.commit()
    return {"posted": posted, "refused": refused}
