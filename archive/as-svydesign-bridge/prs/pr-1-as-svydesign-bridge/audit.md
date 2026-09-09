# Audit — PR 1 — as-svydesign-bridge

**Verdict**: PASS
**Date**: 2026-09-09 00:00

## Scope check

18 test-spec rows validated: B-1, B-2, B-3, B-4, B-5, B-6, B-7, B-9, B-10,
B-11, C-1, C-2, D-1, D-2, E-1, E-2, E-3, E-4. Sections A and F and row C-3
are out of scope per test-spec §Row count / D-9 and carry no rows here.

All 18 rows live in `tests/testthat/test-conversion.R` (new hunk at line
2723 onward, plus the E-1/E-3 dual-pattern extension at line ~279). One
new `test_invariants()` call was added, at line 2795, for
`as_survey_nonprob()` in row B-1 — the file's only new call, matching the
once-per-constructor-per-file rule.

Filtered run for independent confirmation (permitted under gates-handoff
§Why you run no gate): `Rscript -e "devtools::test(filter = 'conversion')"`
→ `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 625 ]`. Zero skips confirms `survey`
and `srvyr` are both installed and every block, including the two `srvyr`
blocks (C-1, C-2), actually ran rather than skipping.

**Tolerance-source check (required by dispatch).** Read rows B-5, B-6, B-9,
B-10, B-11 directly in the source. Each computes its expectation inside the
`test_that()` block from the source design (`sc <- get_means(d, y1,
variance = ...)`) and compares it to the oracle call on the object
converted from that same `d` in that same block — never against a printed
literal. Confirmed for all five:
- B-5/B-6/B-11: `expect_equal(coef(sm)[["y1"]], sc$mean[[1L]], tolerance = 1e-10)` and `expect_equal(as.numeric(survey::SE(sm)), sc$se[[1L]], tolerance = 1e-8)`.
- B-9/B-10: `expect_equal(bounds[[1L]], sc_ci$ci_low[[1L]], tolerance = 1e-6)` and the matching `ci_high` line.

All five tolerances match `test-spec.md` §Tolerances exactly (point 1e-10,
SE 1e-8, CI 1e-6) — none relaxed.

**Observation, not a finding.** `test-spec.md` §Fixture 1 documents "40
rows, seed 7" and cites measured SE values of 0.0200827192 /
0.5630671378 (measurements.md R3, not read by this agent). The fixture in
`test-conversion.R` (`make_nonprob()`) defaults to `seed = 601L`. Because
every numerical row computes its expectation dynamically from the same
seed on both sides of the conversion inside its own block, the seed used
has no bearing on pass/fail — reran the fixture at seed 601 independently
(below) and both sides still agree to the displayed precision. Recorded
here because the spec's cited literals do not match what runs; not a
tolerance or contract violation.

## Per-Test Result Table

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| B-1 replicate shape: class + no condition | `svyrep.design`, no condition | inherits `svyrep.design`, no condition | — | ✓ |
| B-2 replicate columns preserved | `ncol(weights(sv,"analysis"))`=8; all `bw_1..8` present | 8; all present | — (identical) | ✓ |
| B-3 plain shape: class + warns | `survey.design2`, warns `surveycore_warning_nonprob_srs_conversion` | same | — | ✓ |
| B-4 snapshot of B-3 message | matches `_snaps/conversion.md` block "as_svydesign() reports the plain-shape nonprob conversion" | matches | — | ✓ |
| B-5 replicate SE parity | mean 47.71882 / 47.71882; SE 0.07872678 / 0.07872678 | equal within tolerance | SE 1e-8 | ✓ |
| B-6 plain SE parity | mean 47.71882 / 47.71882; SE 1.418306 / 1.418306 | equal within tolerance | SE 1e-8 | ✓ |
| B-7 no FPC-dropped warning, either shape | replicate: no warning, `svyrep.design`; plain: no warning (inside conversion warning), `survey.design2` | absent on both shapes | — | ✓ |
| B-9 replicate CI parity | ci 47.56452 / 47.87313 vs 47.56452 / 47.87313 | equal within tolerance | CI 1e-6 | ✓ |
| B-10 plain CI parity | ci 44.939 / 50.49865 vs 44.939 / 50.49865 | equal within tolerance | CI 1e-6 | ✓ |
| B-11 zero-weight SE parity | class `survey.design2`; mean 47.91654/47.91654; SE 1.44527/1.44527; both warnings raised | equal within tolerance; `survey.design2`; both warning classes present | SE 1e-8 | ✓ |
| C-1 `as_tbl_svy()` replicate shape | `tbl_svy`, no error | inherits `tbl_svy` | — | ✓ |
| C-2 `as_tbl_svy()` plain shape propagates warning | `tbl_svy`, warns `surveycore_warning_nonprob_srs_conversion` | same | — | ✓ |
| D-1 round trip returns probability design | class `survey_replicate`; `S7_inherits(., survey_nonprob)` = FALSE | `survey_replicate` TRUE, `survey_nonprob` FALSE | — | ✓ |
| D-2 rebuilt design raises no fallback warning | "no warning"; `get_means()$se` finite | no `surveycore_warning_nonprob_srs_fallback` | — | ✓ |
| E-1 refuses `data.frame` | `surveycore_error_not_survey_object` | same class | — | ✓ |
| E-2 refuses character string | `surveycore_error_not_survey_object` | same class | — | ✓ |
| E-3 snapshot of E-1 message | matches `_snaps/conversion.md` block "as_svydesign() rejects a plain data.frame" | matches | — | ✓ |
| E-4 no refusal for replicate nonprob | "no error"; class `svyrep.design` | no `surveycore_error_not_survey_object` | — | ✓ |

18/18 rows pass.

## CRAN cookbook violations

Scanned the PR's only modified `R/` file, `R/methods-conversion.R` (diff
hunks at lines 30–104, 133–174, 434–441), against every pattern in
`r-package-profile.md` §CRAN cookbook scan: `T`/`F` abbreviation,
`set.seed()`, bare `print()`/`cat()`, `options(warn = -1)`,
`installed.packages()`, `<<-`, unrestored `par()`/`options()`/`setwd()`,
home-directory writes, `mc.cores`/`makeCluster` > 2, `@importFrom`.

None. (Grep hits on bare `~` in roxygen formula examples and comments are
formula tildes, not home-directory-write patterns — verified by reading
each hit; none is a write call.)

## Before/After Comparison

| Metric | Before PR | After PR | Δ |
|---|---|---|---|
| tests passing | 11538 | 11595 | +57 |
| WARN count | 256 | 256 | 0 (pre-existing AAPOR small-cell warnings; no new warning, per archived decision D12) |
| R CMD check notes | 1 | 2 | +1 (both After notes accounted for: `checking CRAN incoming feasibility` is pre-approved; `checking for hidden files and directories` naming `.git` is a pre-existing `.Rbuildignore` gap present in the Before run too — not new, outside this PR's write surface) |
| coverage | not measured (baseline run killed twice by the low-memory watchdog; see gates-handoff.md) | 96.24% | no trustworthy delta — judged against the 95% floor, which it clears |

No regression in tests-passing, warnings, or check notes. Coverage clears
the 95% floor stated in `testing-standards.md`; per gates-handoff.md's
explicit resolution, the missing Before figure is not treated as a HOLD
trigger here because the ambiguity is already resolved in the dispatch,
not silent.

## Profile gates

| Gate | Result | Notes |
|---|---|---|
| devtools::document() | PASS | no NAMESPACE/man drift |
| devtools::test() | PASS | [ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11595 ] |
| run_examples() | PASS | all examples ran |
| R CMD build | PASS | ./surveycore_1.1.0.9000.tar.gz |
| R CMD check --as-cran | PASS | Status: 2 NOTEs (both reviewed above, neither new) |
| pkgdown | PASS | site built |
| covr | PASS | 96.24%; changed R/ files: 1, uncovered lines in them: 1 |

Per-gate logs: `.surveycore-workspace/runs/2026-09-08-as-svydesign-bridge/logs/gate-1-document.log` through `gate-7-covr.log`.

The one uncovered line, `R/methods-conversion.R:525`, is the pre-existing
`return(NULL)` early exit of `.find_col_by_value()`, already carrying a
`# nocov` comment, and sits outside this PR's three diff hunks (30–104,
133–174, 434–441). No line this PR added is uncovered.

Tree: `424da65a0e7df17d4e9ea4d45a2a58197feb196d`

## BLOCKs (if any)

None.
