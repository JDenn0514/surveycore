# Review — plan PR 9: `refactor/analysis-cell-performance`

**Reviewer**: opus, 2026-11-17. Branch at `ae73ecb` (tree `dcaad9f`),
against `origin/develop` `f1581e2`. Reviewer scripts and logs are in the
session scratchpad `rv9/` (`check.R`, `check.log`, `timing_rv.R`,
`lonely.R`, `run_rv.sh`, `rv.log`), not in the repository.

## Verdict: PASS

No defect in the code, the `NEWS.md` text or the changelog. Two
FIX-BEFORE-MERGE items remain. Both are leader steps that the plan assigns
after the builder, and the builder named both (E-9, `{ref}`).

## FIX-BEFORE-MERGE

1. **`{ref}` is still literal in `NEWS.md`, lines 13 and 20.** Criterion 6
   and task 7 say no `{` field is left at merge. Open the PR, then fill both
   with the issue number or the PR number in a follow-up commit.
2. **The PR description must carry the §XII table and the committed value
   `TAYLOR_SE_BLOCK = 32`** (task 8, criterion 7). The table is ready in
   `table.md`. It is identical to the changelog's 31 rows (checked with
   `diff`).

## FOLLOW-UP

1. **The `CLAUDE.md` baseline command does not work on this machine (E-1
   is real).** With `LANG=C.UTF-8 LC_ALL=C.UTF-8`, R 4.6.1 ucrt prints
   "Setting LC_CTYPE=C.UTF-8 failed" (also LC_COLLATE, LC_MONETARY,
   LC_TIME), `Sys.getlocale()` returns `"C"` and `l10n_info()[["UTF-8"]]` is
   `FALSE`. Without the variables the locale is `English_United
   States.utf8` and UTF-8 is `TRUE`. I did not re-run the suite under the C
   locale; the 10 snapshot failures are the builder's measurement. Open an
   issue to change the command in `CLAUDE.md` §CI / Package Development for
   Windows. That file is outside this PR.
2. **The block-size pick is inside the noise.** See check 1. The rule was
   applied once, as the spec says, and 32 is a sound value. A later change
   that needs a different size should measure more than 3 runs per size.

## NOTE

1. The changelog says "R4 decides the selection". That is true of the
   recorded table. My re-run shows that R4 moves by up to 0.77 s between two
   passes at the same `B`, so the R4 gap between sizes is not a real effect.
   An optional sentence in the changelog can say this.
2. The changelog sentence "a call that fails now computes every cell
   first" is the spec text, word for word. It is not true of `get_ratios()`,
   which still aborts in call 1 of the first cell (spec §III.4). The
   `NEWS.md` bullet names the five functions correctly. No change: the
   wording is fixed by §XIII.
3. "Files Modified" in the changelog lists 3 files. The PR diff has 6: the
   bookkeeping commit `1eb5bd6` adds 3 `plans/` files. That commit is the
   leader's, and E-8 explains the scope. No change.
4. Gate summary `gates-summary.txt` still shows gates 4 and 5 as FAIL from
   the first run. `gate-4-build.log` and `gate-5-check.log` now show the
   re-run: tarball built, `Status: 1 NOTE` (CRAN incoming feasibility). The
   summary file was not re-written.
5. Gate 2's five uncovered lines in `R/analysis-helpers.R` (897, 903, 904,
   1080, 1245) are outside this PR's hunk (1309 to 1315).

## Checks

### 1. Block size (§XII.5)

Re-derived from `after_blk/block.csv`. The stored medians agree with the
stored runs.

| `B` | Sum (s) |
|---|---|
| 16 | 7.81 |
| 32 | 7.13 |
| 64 | 7.34 |

The bound is 7.13 × 1.05 = 7.4865. Only 32 and 64 are within it, so the
rule picks 32. The pick is also 32 when the sums use the minimum, the mean
or the maximum of the three runs in place of the median.

Robustness. The rule picks the smallest qualifying `B`, so a reordering of
32 and 64 cannot change the pick. Only B = 16 can take it, and only when
both other sums reach 7.44 s or more. In the recorded table that needs R4
at B = 32 about 0.31 s slower. I re-timed in a fresh session on the
installed branch head (`lib_after`, 32 by default, set per size with
`assignInNamespace()`), in reversed order, with a second pass at 32. No
other R process ran (the driver waited for an empty process list before
each R call).

| `B` (order run) | V3 | C2 | R4 | Sum |
|---|---|---|---|---|
| 64 (1st) | 1.22 | 1.90 | 2.70 | 5.82 |
| 32 (2nd) | 1.17 | 1.56 | 2.68 | 5.41 |
| 16 (3rd) | 1.21 | 1.79 | 2.97 | 5.97 |
| 32 (4th) | 1.14 | 1.59 | 3.45 | 6.18 |

With the first 32 pass the rule picks 32 (bound 5.68). With the second 32
pass it picks 16 (minimum 5.82 at 64, bound 6.11, 16 at 5.97). So the pick
is not stable across repeats: the same `B` moves R4 by 0.77 s, more than
any gap between sizes. The builder's R4 at B = 16 (4.03 s) did not
reproduce; my two readings were 2.97 and 3.36 (the second from a run I
discarded because another R process was alive). This does not block: all
three sizes give `identical()` results, the rule was applied once as the
spec states, and 32 uses less memory per stacked call than 64. Recorded as
FOLLOW-UP 2.

Equality at each size, from the saved RDS files:

| Scenario | B = 16 | B = 32 | B = 64 |
|---|---|---|---|
| V3 | `identical()` | `identical()` | `identical()` |
| C2 | `identical()` | `identical()` | `identical()` |
| R4 | `identical()` | `identical()` | `identical()` |

The base results in `before_blk/` are also `identical()` to the base
results in `out_before/`, so E-2's contaminated base run produced the right
values.

### 2. `identical(before, after)`, 31 scenarios

Re-run from `out_before/` and `out_after/` with my own script: 31 of 31
`TRUE`. Each file holds a full result object (class `survey_freqs` to
`survey_ratios`, 1 to 360 rows, `.vcov` present on the freqs, means,
totals and ratios results). Row counts match the table.

### 3. Re-timing

Fresh `Rscript` session per library, `timing.R` unchanged, one warm-up then
the median of 5 runs (3 when the warm-up took more than 1 s). The process
count inside the run read 2 (the run itself) for every scenario.

| Scenario | Builder before | Builder after | Builder ratio | Reviewer before | Reviewer after | Reviewer ratio |
|---|---|---|---|---|---|---|
| M7 | 2.75 | 0.48 | 0.17 | 3.04 | 0.48 | 0.16 |
| C2 | 13.52 | 1.56 | 0.12 | 14.69 | 1.63 | 0.11 |
| F5 | 1.61 | 0.20 | 0.12 | 1.73 | 0.22 | 0.13 |
| R2 | 2.36 | 0.83 | 0.35 | 2.55 | 0.79 | 0.31 |

The speed-ups hold. My before times are 7% to 10% higher; the after times
agree within 0.07 s. The M7 times in `NEWS.md` (2.75 s and 0.48 s) are the
recorded table's values; my M7 after reading is the same.

Gate 9 on the recorded table: no scenario has an after time above its
before time, so none is flagged. Every stored median equals the median of
its stored runs, and the 3-or-5 run rule held on every row of both passes.

### 4. Criterion 4, call counts at B = 32

From `out_after/counts.csv`, measured on the `32de4c5` install:

- `.build_cluster_matrices()` = 1 on all 22 Taylor scenarios.
- `.svy_recvar()` = 1 on F1 to F6, M1 to M7, T1 and T2.
- V1: `ceiling(40 / 32)` = 2. V3: `ceiling(180 / 32)` = 6. C1:
  `ceiling(20 / 32)` = 1. C2: `ceiling(360 / 32)` = 12. All match.
- R1: 5 + 5 + `ceiling(5 / 32)` + 1 = 12. R2: 20 + 20 + 1 + 1 = 42. R4:
  60 + 60 + `ceiling(60 / 32)` + 1 = 123. All match.
- Both counts 0 on F7 to F9, M8, M9, T3, V2, C3, R3.

V1 = 2 shows the counts were taken at 32: at 64 it would be 1.

### 5. `NEWS.md` against §XIII

The spec template, with `{functions}`, `{M7 before}` and `{M7 after}`
replaced by the PR's values and whitespace collapsed, is byte-identical to
`NEWS.md` lines 1 to 21 (`cmp`). Field rules:

- `{functions}`: all six qualify. One qualifying scenario per function:
  F1 (0.23 s, 0.13), M2 (0.16 s, 0.19), T1 (0.16 s, 0.19), V1 (1.62 s,
  0.14), C1 (0.85 s, 0.16), R1 (0.40 s, 0.27). Listed in §I.2 order.
- `{M7 before}` 2.75 and `{M7 after}` 0.48 match the table at two decimals.
- No fallback applies.
- `{ref}` is literal twice (FIX-BEFORE-MERGE 1). No other `{` field.
- The heading `# surveycore (development version)` and `## Performance` sit
  above `# surveycore 1.2.0`; no development section existed before.

The lonely-PSU bullet is true of the code. I ran one design with a
single-PSU stratum on both libraries under `survey.lonely.psu = "fail"` and
under an unknown value:

| Call | Base | Branch |
|---|---|---|
| `get_freqs(d, c(v, allna), na.rm = FALSE)` | `surveycore_error_lonely_psu` | `surveycore_error_all_na` |
| `get_means()`, `get_totals()`, `get_variance()`, `get_covariance()`, grouped | lonely-PSU class | same class |
| `get_ratios()`, grouped | lonely-PSU class | same class |

The unknown value gives `surveycore_error_lonely_psu_unknown_option` in
the same pattern. The `get_freqs()` row is the bullet's "an error from one
of them replaces it". `get_ratios()` is correctly left out of the bullet.

### 6. Changelog against task 8

- House shape: branch, status, date, summary, files modified, changes.
  Present.
- §XII table: 31 rows, all eight columns filled, identical to `table.md`
  and to my recomputation from `times.csv` and `counts.csv`.
- Environment lines: R 4.6.1 (2026-06-24 ucrt), BLAS and LAPACK empty
  (reference), `matprod` `"default"`. Matches `speed.log` and `block.log`.
- Block-size table: `B`, three medians, sum, equality per scenario.
  Matches `block.csv`.
- §XV `identical()` evidence: all 7 table rows are in the changelog
  verbatim (`grep -F`). The §XV speed-up paragraph is left out; it is not
  `identical()` evidence.
- The two sentences and the D13 lifecycle line: each found word for word,
  with whitespace collapsed.

### 7. Criterion 2

- `git merge-base --is-ancestor 32de4c5 32de4c5` exits 0.
- The extract `pr9-src/src_after/` matches `32de4c5` on every file in
  `R/`, `DESCRIPTION` and `NAMESPACE` by git blob hash. Against `1eb5bd6`
  it differs in `R/analysis-helpers.R` only.
- The installed `lib_after` reports `TAYLOR_SE_BLOCK` = 32 on load, and
  `git diff 1eb5bd6 32de4c5 -- R/` is that one constant. `ae73ecb` touches
  no file in `R/`. So the installed code equals the `R/` tree of `32de4c5`
  and of HEAD.
- `src_before/R/` matches `0c0a987` on all 48 files.

### 8. E-1

Real. See FOLLOW-UP 1.

## Errata

| Erratum | Judgment |
|---|---|
| E-1 | Accepted. The locale fallback is confirmed (check 8). The counted run without the variables is the right reading; 254 equals D21. |
| E-2 | Accepted. The discarded base times are not used. The base results it saved are `identical()` to the clean `out_before/` results. |
| E-3 | Accepted, with FOLLOW-UP 2. The rule was applied once as written. My re-run shows the R4 gap is noise, and that a repeat could pick 16. |
| E-4 | Accepted. Blob hashes tie the extracts to `0c0a987` and `32de4c5`. |
| E-5 | Accepted. `R/` differs between `1eb5bd6` and `32de4c5` only in the constant, which was set per size in the session. |
| E-6 | Accepted. §XII.4 sets the run count per warm-up, so a library can use 3 runs where the other uses 5. |
| E-7 | Accepted. `degree` has 5 non-empty cells; 12 matches the formula. |
| E-8 | Accepted. See NOTE 3. |
| E-9 | Accepted as a leader step. FIX-BEFORE-MERGE 2. |
| E-10 | Accepted. The leader's gate run on `dcaad9f` covers G. |

## Process note

My first block re-run started while another session's `Rscript` was alive
(340 MB). I discarded it. A stale copy of my driver then started one base
timing while 10 other R processes were alive; I killed it and discarded
that reading too. Every number in this review comes from runs that started
with no other R process alive.
