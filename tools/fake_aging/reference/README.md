# The shop's real-aging reference

The research's real run of the shop, run R, is the only real-aging
reference (v0.6 master spec 12.3). None of it is in git, small files
included (spec D519): the whole folder is kept as one archive outside
git, on armenelos. Git keeps only this pointer, the per-file manifest
and the extraction script.

## Run R

- The game `fa-real`, game id `tarnbeck-outdoor-shop-z8415w`, the
  scenario `tarnbeck-outdoor-shop`, aged for real from 2026-11-14 to
  2026-11-15 (its measurement point 2026-11-15T08:00Z).
- The research: branch `research/fake-aging` at `10d1bc6`, prototypes in
  `tools/research/fake_aging/`, test plan, run and results in
  `specs/research/fake-aging/` on that branch. The folder archived is
  that worktree's untracked `tools/research/fake_aging/results/`, as it
  stood on 2026-11-15 (last write 17:06).
- Beside R, the research ran six fake-aged games, F1 to F6; their
  results are in the same folder and archived with it, for the record.

## The archive

| | |
|---|---|
| Path | `/home/bastien/archive/db_audit_gm/fake-aging-shop-reference/results-20261115.tar.zst` |
| Checksum | `results-20261115.tar.zst.sha256` beside it |
| SHA-256 | `26faa9e010a449abad9e17472fdea1cfc96dca3614df9cd6cd5c2ed2ed838a55` |
| Size | 326,495,975 bytes (312 MiB), `tar --zstd` |
| Unpacked | 507 files, 2,031,069,790 bytes (1.9 GiB) |
| Made with | `tar --zstd -cf <archive> -C <research worktree>/tools/research/fake_aging results` |

Its members are `results/<path>`. [`MANIFEST.sha256`](MANIFEST.sha256)
lists every file's SHA-256 with `<path>` relative to `results/`, the
name every tool and chunk uses. The archive also holds five empty
folders the manifest cannot list, `hist-f2/tmp` to `hist-f6/tmp`.

## What it holds

Run R's members, the ones v0.6 reads:

| Member | What it is | Read by |
|---|---|---|
| `calibrate-r-producer-20261115.txt`, `calibrate-r-consumer-20261115.txt` | the latency model against R: per key and customer hour, the median and 90th percentile of p50 and p95 across minutes, R's scheduler log against the model (the research's `calibrate.py`) | chunks 8 (service times) and 11 (the calibration tool) |
| `calibrate-r-producer-f5-20261115.txt` | the same for the producer around f5's close-day | chunks 8 and 11 |
| `m1-fa-real-20261115T0800/` (21 files: `statements.csv`, `table_stats.csv`, `database_stats.csv`, `relation_sizes.csv`, `all.txt`, ...) | M1: R's database dump at the measurement point | chunks 12 (the M1 comparison) and 11 (the signatures' measured costs) |
| `m1-fa-real.log` | the M1 dump's log | none |
| `m3-r-20261115.json` | M3: R's Prometheus profile | chunks 12 (the M3 comparison) and 11 |
| `m4-r-20261115.txt` | M4: R's tells | chunk 12, if its tells script compares with R's |
| `fa-real-handover-check.txt` | the hand-over check on R before the measurements | none |
| `prom-r-20261115T0800/volume.tar` (34 MiB) | a copy of R's Prometheus volume | chunk 11, as needed |
| `r-dump/r.om` (1.5 GiB) | R's OpenMetrics dump, 2026-11-14T08:00Z to 2026-11-15T05:00Z, from the Prometheus copy | chunk 11, as needed |
| `r-dump/tsdb/` (55 files, 34 MiB) | R's TSDB copy | none |

The F runs' members, kept for the record; no v0.6 chunk reads them:

| Members | What they are |
|---|---|
| `m1-fa-fake-f<n>-<time>/` | F1 to F6's M1 dumps |
| `m1-compare-r-f1f3f2f5.txt`, `m1-compare-r-f5f4.txt`, `m3-compare-r-f6.txt` | the M1 and M3 comparisons with R |
| `m3-f6-20261115.json` | F6's M3 profile |
| `m4-f4-20261115.txt`, `m4-f6-20261115.txt` | F4's and F6's tells |
| `m7-f4-20261115.txt` | M7, the hiding pair, on F4 |
| `prom-f<n>-<time>/volume.tar` | copies of F1 to F6's Prometheus volumes |
| `hist-f<n>/` | the forged histories: `history.om.zst`, the generator's logs and report, the seam check, the imported blocks |
| `fa-fake-{deploy,fill,import,run,tail}-f<n>.log`, `fa-fake-tail-rehearsal.log` | the F runs' logs |

Chunk 11 names the R members it read in capture W3.

## Extracting it

```sh
sh tools/fake_aging/reference/extract.sh [--archive <path>] <member>...
```

- `<member>`: a manifest path; a folder ending `/` takes every file
  under it; a quoted shell pattern (`'calibrate-r-*-20261115.txt'`)
  every manifest path it matches. A member matching nothing is an
  error, whether the archive is there or not.
- `--archive <path>`: another archive, its checksum read from
  `<path>.sha256`; the default is the path above.
- It checks the archive against its `.sha256` once a run, extracts each
  member at its path into `tools/fake_aging/reference/extracted/`
  beside the script (ignored by git; each worktree its own), checks each
  file against `MANIFEST.sha256`, and prints each file's absolute path,
  one a line, on standard output; messages go to standard error. A file
  already there and matching the manifest is not extracted again.
- Exit status: 0 done; 1 a check failed (the archive's checksum, a
  file's manifest line, an unknown member) or the extraction failed; 2
  usage; **77, skip**: the archive is absent, with
  `extract.sh: SKIP: the reference archive <path> is absent (kept outside git, spec D519; see tools/fake_aging/reference/README.md)`
  on standard error. Only absence skips: a checksum mismatch fails.
- A Python test seeing 77 calls `skipTest` with that line; a shell test
  prints `SKIP` and counts no failure.
- `extracted/` is a cache, deleted at will and taken away with its
  worktree. Never extract `r-dump/` whole when one file serves.

For example, the calibrations:

```sh
sh tools/fake_aging/reference/extract.sh 'calibrate-r-*-20261115.txt'
```

To check the archive by hand, or the whole folder once unpacked:

```sh
cd /home/bastien/archive/db_audit_gm/fake-aging-shop-reference
sha256sum -c results-20261115.tar.zst.sha256
tar --zstd -xf results-20261115.tar.zst -C <somewhere>   # 1.9 GiB
cd <somewhere>/results && sha256sum -c <repo>/tools/fake_aging/reference/MANIFEST.sha256
```
