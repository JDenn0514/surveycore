# Audit — PR 0 — nonprob-domain-se-correction

**Verdict**: PASS
**Run by**: orchestrator (pipeline-ship), not a tester agent. PR 0 sits outside
the frozen plan and has no `test-spec.md`, so there was no test-spec for a
tester to audit against. The gates below are the full profile suite, run in one
foreground call per `r-package-profile.md` §Canonical runner.
**Tree**: 34b15df1bd90b6611df9c48bfb42dfa03eaa4e98
**Branch**: `fix/nonprob-domain-se-correction` @ `3a9b2c8`
**Logs**: `.surveycore-workspace/runs/2026-09-09-as-svydesign-domain/logs/pr-0`

## Profile gates

| Gate | Result | Notes |
|---|---|---|
| `devtools::document()` | PASS | wrote nothing — helper is internal, no roxygen |
| `devtools::test()` | PASS | FAIL 0, WARN 256, SKIP 4, PASS 11635 |
| `devtools::run_examples()` | PASS | all examples ran |
| `R CMD build` | PASS | `surveycore_1.1.0.9000.tar.gz` |
| `R CMD check --as-cran` | PASS | Status: 2 NOTEs, both accepted — see below |
| `pkgdown::build_site()` | PASS | site built. Not skipped: the write surface touches `R/` |
| `covr::package_coverage()` | PASS | 96.25% |

## Before / After

| Measure | Before (`develop` a545505, tree 2e14b3b) | After |
|---|--:|--:|
| Passing expectations | 11606 | 11635 |
| Failures | 0 | 0 |
| Warnings | 256 | 256 |
| Skips | 4 | 4 |
| Coverage | 96.24% | 96.25% |

The 256 warnings are the pre-existing AAPOR small-cell warnings on clean
`develop`, unchanged in count. The +29 expectations are PR 0's five new blocks.
Coverage rose 0.01 points.

## NOTEs, both accepted

| NOTE | Status |
|---|---|
| `checking CRAN incoming feasibility` | Pre-approved in `r-package-conventions.md`. Body is the maintainer line plus "Version contains large components (1.1.0.9000)", which is the `.9000` development suffix |
| `checking for hidden files and directories` — found `.git` | Pre-existing, caused by `.Rbuildignore`, and not fixable in any PR. Recorded in `archive/as-svydesign-bridge/` under AC-6 for the same reason |

No new NOTE pattern appeared.

## Coverage of the changed file

`R/analysis-means-helpers.R` — 95.95%, 3 uncovered lines: 180, 268, 336.

None is in this PR's diff. Lines 268 and 336 are the `else { 0 }` arm of the
`se_srs` computation, unreachable because the `n_d == 1L` early return fires
first; line 180 is a `.nonprob_rep_na_warn()` return branch. All three
pre-date this PR. The two lines this PR adds — `n_full <- nrow(data)` and the
rewritten `var_ybar` — are both covered.

## CRAN cookbook scan

Clean on both changed files. No `T`/`F` as logicals, no `set.seed()` in `R/`,
no bare `print()`/`cat()`, no `options(warn = -1)`, no `installed.packages()`,
no `<<-`, no unrestored state, no writes outside `tempdir()`, no core count
above 2.

## Numerical verification

The builder measured parity against `survey` 4.5 independently, on seeds and
frames the orchestrator did not supply: ten cases covering five domain sizes,
three groups of a grouped call, an `NA`-outcome case and the full sample. Every
absolute SE difference was at or below 4.5e-16, against a 1e-8 tolerance. The
full table is in `implementation.md` §Parity measurements.

The orchestrator's own earlier measurement, on a different frame and different
domain splits, agreed: parity to at most 4.44e-16 at six domain sizes.

Two independent measurements, different data, same conclusion.

## Open signal

One HOLD, transcribed to `decisions.md` and resolved there as D17 (DEFERRED):
a one-row calibrated domain keeps `se = NA_real_` where `survey` returns `0`.
Out of this PR's scope, pinned by an existing test, and reached by none of this
PR's parity blocks.
