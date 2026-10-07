# Audit — PR 1 — replicate-export-ignored-args

**Verdict**: PASS
**Date**: 2026-10-07

Branch `fix/replicate-export-ignored-args`, HEAD `1650f93`, base
`origin/develop` `a9e501b`. Oracle: `survey` 4.5 under R 4.6.1, the version
`test-spec.md` §3 records, so the condition texts were not re-derived.

## Per-Test Result Table

Fixtures: F2 = `make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L,
design = "replicate", type = "brr", seed = 430L)`, R = 5. F1 =
`make_survey_data(n = 200, n_psu = 20, n_strata = 4, design = "replicate",
type = "jk1", seed = 15)`, R = 20. Both fixtures in the test blocks match
`test-spec.md` §4. "Got" values come from a separate probe script that
repeats each block's calls; the blocks themselves were run with
`testthat::test_file()`.

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| 7.2 ACS: warnings from `svrepdesign()` | 0 | 0 | exact | ✓ |
| 7.2 ACS: `d@variables$rscales` | `rep(1, 5)`, `identical()` TRUE | `rep(1, 5)` | identical | ✓ |
| 7.2 ACS: warnings from `as_svydesign()` | 0 | 0 | exact | ✓ |
| 7.2 ACS: SE `sv` against SE `src` | 0.444769633676 / 0.444769633676 (diff 0) | equal | 1e-8 | ✓ |
| 7.2 successive-difference: warnings from `svrepdesign()` | 0 | 0 | exact | ✓ |
| 7.2 successive-difference: `d@variables$rscales` | `rep(1, 5)`, `identical()` TRUE | `rep(1, 5)` | identical | ✓ |
| 7.2 successive-difference: warnings from `as_svydesign()` | 0 | 0 | exact | ✓ |
| 7.2 successive-difference: SE `sv` against SE `src` | 0.444769633676 / 0.444769633676 (diff 0) | equal | 1e-8 | ✓ |
| 7.2 block at PR head | 8 expectations, 0 failed | pass | — | ✓ |
| 7.2 block against develop's `R/methods-conversion.R` and `R/utils.R` (AC-2 worktree) | 2 of 8 failed; the only failing block in the file | fails | — | ✓ |
| 7.3 JK2: conditions from `as_survey_replicate()` | 0 | 0 (`expect_no_condition()`) | exact | ✓ |
| 7.3 JK2: warnings from `as_svydesign()` | 1, "with type JK2 scale= and rscales= are not needed and will be ignored" | 1, same text, `fixed = TRUE` | exact | ✓ |
| 7.3 JK2: SE `sv` against `get_means()` SE | 0.497267567614 / 0.497267567614 (diff 6.55e-15) | equal | 1e-8 | ✓ |
| 7.4 BRR: warnings from `svrepdesign()` | 0 | 0 | exact | ✓ |
| 7.4 BRR: `d@variables$scale` | 0.2 | 1 / 5 | 1e-8 | ✓ |
| 7.4 BRR: warnings from `as_svydesign()` | 0 | 0 | exact | ✓ |
| 7.4 BRR: SE `sv` against SE `src` | 0.222384816838 / 0.222384816838 (diff 0) | equal | 1e-8 | ✓ |
| 7.4 NULL type: error from `as_svydesign()` | none | none | — | ✓ |
| 7.4 NULL type: warnings | 1, "type='BRR' does not use 'scale=' argument" | 1, same text, `fixed = TRUE` | exact | ✓ |
| 7.4 NULL type: class of `sv` | `svyrep.design` | `svyrep.design` | — | ✓ |
| 7.4 NULL type: `sv$scale` | 0.2 | 0.2 | 1e-8 | ✓ |
| 7.4 existing "as_svydesign() reproduces a replicate nonprob's mean and SE [numerical]" | 2 expectations, 0 failed; not in the diff | passes unchanged | — | ✓ |
| 6.10 JKn on F1 with no `rscales` | error "Must provide rscales for combined JKn weights" (`simpleError`) | same text, `fixed = TRUE` | exact | ✓ |
| T12 "as_svydesign() warns and converts for every replicate type carrying an FPC" | 20 expectations, 0 failed; comment says "Only JK2" | passes, comment only | — | ✓ |
| AC-6 "every accepted replicate type crosses both conversion routes" | 55 expectations, 0 failed | passes | — | ✓ |
| AC-6 `grep -c "ignore a scale"` | 0 | 0 | exact | ✓ |
| AC-6 `grep -c "with type ACS scale="` | 0 | 0 | exact | ✓ |
| AC-6 `grep -ci "only JK2"` | 2 | 2 or more | — | ✓ |
| AC-6 removed non-comment lines in `test-conversion.R` | 0 | 0 | exact | ✓ |
| 9.1 `plans/error-messages.md` section | ends with `### replicate-supplied-args rows (2026-10-01)`: RS-1 `surveycore_warning_replicate_arg_ignored`, RS-2 and RS-3 `surveycore_error_stratified_jk_rscales_unset`, FR-3 note naming both classes | as specified | — | ✓ |
| 9.1 / AC-1 register commit before first `R/` commit | `49be866` is an ancestor of `cc98f9b`; `merge-base --is-ancestor` exit 0 | exit 0 | — | ✓ |
| Explicit `tolerance =` on every new `expect_equal()` | 6 of 6, values 1e-8 (SE and scale) | plan values | — | ✓ |
| New `test_invariants()` calls | 0 | 0 | — | ✓ |
| Added `suppressWarnings(` / `expect_failure(` code lines in `tests/` | 0 | 0 | — | ✓ |
| Each new block that calls `survey` starts with `skip_if_not_installed("survey")` | 5 of 5 | all | — | ✓ |

## Before/After Comparison

Before = dispatch baseline (develop `a9e501b`). After = leader's gate run on
tree `5fb3cb8`.

| Metric | Before PR | After PR | Δ |
|---|---|---|---|
| tests passing | 12353 | 12374 | +21 |
| test failures | 0 | 0 | 0 |
| test warnings | 256 | 256 | 0 |
| coverage | 96.17% | 96.17% | 0.00 |
| R CMD check notes | 1 (baseline as dispatched: pre-approved only) | 1 (`checking CRAN incoming feasibility`) | 0 |

## Profile gates

The leader ran the gates on this tree. This audit did not re-run them (the
dispatch forbids it, because of host memory). The `Status:` line and the test
summary were confirmed in the logs under `logs/`.

| Gate | Result | Notes |
|---|---|---|
| devtools::document() | PASS | wrote nothing; no diff in `man/` or `NAMESPACE` |
| devtools::test() | PASS | `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 12374 ]`; 256 = baseline, no new warning |
| devtools::run_examples() | PASS | |
| R CMD build | PASS | |
| R CMD check --as-cran --no-manual | PASS | `Status: 1 NOTE` present in the log; the note is `checking CRAN incoming feasibility` (pre-approved) |
| pkgdown | PASS | no errored page |
| covr (NOT_CRAN=true) | 96.17% | no drop; uncovered lines in changed files are methods-conversion.R:635, utils.R:377, utils.R:487, none of them an added line (added hunks: methods-conversion.R 370-381, 386-390, 482; utils.R 1201-1218) |
| air format --check (PR's 4 `.R` files) | PASS | exit 0 |
| Snapshots | PASS | no file under `tests/testthat/_snaps/` in the PR diff |
| Diff paths (G9) | PASS | no `.surveycore-workspace/` path; every path is in Files touched or under `plans/` |
| `as_survey_nonprob()` body (G10) | PASS | `R/core-constructors.R` not in the diff |
| CRAN cookbook scan | PASS | none |

Tree: 5fb3cb8e3cd9ffb101a7222d33d4548059738372

## CRAN cookbook violations

None. Scanned the 34 added lines under `R/` and the whole of
`R/methods-conversion.R` and `R/utils.R` for every pattern in
`r-package-profile.md` §CRAN cookbook scan.

## Notes

- The AC-2 worktree run left the main checkout clean. The worktree was
  removed, and `tests/testthat/_snaps/` was restored after the local test
  runs.
- In the AC-2 worktree, the NULL-type block also passed against develop's
  route. The plan requires only the ACS/successive-difference block to fail
  there, so this is not a finding.

## BLOCKs

None.
