# Audit — PR 5: test/replicate-supplied-scale-oracle

**Verdict: PASS**

- Request: replicate-supplied-args (issue #255)
- Branch: `test/replicate-supplied-scale-oracle`, HEAD `4d4bf23`
- Tree: 117bc789deb39f3fcbe1d656b7720e540074f848
- Base: `origin/develop` `2c46f62`
- Rows validated: §6 6.1 to 6.9; §7 7.1
- Oracle: `survey` 4.5 under R 4.6.1, the versions the test-spec records

## Profile gates

The leader ran the gates on tree `117bc78`. The tester did not rerun them, as the dispatch instructed. The tester read the summary line of each log.

| # | Gate | Result | Log |
|---|---|---|---|
| 1 | `devtools::document()` | PASS — wrote nothing | `logs/gate-1-document.log` |
| 2 | `devtools::test()` | PASS — `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 12712 ]` | `logs/gate-2-test.log` |
| 3 | `devtools::run_examples()` | PASS — the "error" matches in the log are value labels and warning text | `logs/gate-3-examples.log` |
| 4 | `R CMD build` | PASS — `surveycore_1.1.0.9000.tar.gz` built | `logs/gate-4-build.log` |
| 5 | `R CMD check --as-cran --no-manual` | PASS — `Status: 1 NOTE`, the Status line is present | `logs/gate-5-check.log`, `logs/gate-5-00check.log` |
| 6 | `pkgdown::build_site()` | SKIPPED — scope. The write surface is `tests/` and `plans/` only. It touches no `R/`, `vignettes/`, README, `_pkgdown.yml`, `DESCRIPTION`, `NAMESPACE` or `man/` (r-package-profile.md §pkgdown skip condition) | — |
| 7 | `covr` (`NOT_CRAN=true`) | PASS — 96.18% (`COVERAGE_PCT=96.18`), at or above the 95% floor | `logs/gate-7-covr.log` |

NOTEs:

| NOTE | Pre-approved |
|---|---|
| `checking CRAN incoming feasibility` | Yes |

The pre-existing `.git` hidden-file note did not appear in this run.

Criterion G, items the tester checked:

| G item | Result |
|---|---|
| 6, added `R/` lines reached | None to check: `git rev-parse HEAD:R` = `origin/develop:R` = `5d2ff1168fad0f0d05bfbf28fd1285777dfeb309` |
| 7, `air format --check` on the changed `.R` files | Exit 0 on `test-variance-replicate.R` and `test-conversion.R` |
| 8, snapshots | `git diff origin/develop...HEAD -- tests/testthat/_snaps` is empty |
| 9, paths | `plans/implementation-plan-replicate-supplied-args.md`, `plans/pr-budget-calibration.md`, `tests/testthat/test-conversion.R`, `tests/testthat/test-variance-replicate.R`. No path under `.surveycore-workspace/`. The two `plans/` paths are the leader's bookkeeping commit `0e4da06` |
| 10, `as_survey_nonprob()` body | `R/` subtree hash unchanged, so the body is byte-identical |

## Probe of `survey` condition texts (plan task 1)

Built on the installed `survey` 4.5 on F1. Each text matches the plan's §`survey` condition texts table character for character. No HOLD.

| Call | Warnings observed | Text |
|---|---|---|
| JK1, JKn, bootstrap, Fay with `scale = 0.6` | 0 | — |
| `other`, `scale = 0.6`, no `rscales` | 1 | `scale or rscales not specified, set to 1` |
| BRR, `scale = 0.6` | 1 | `type='BRR' does not use 'scale=' argument` |
| JK2, `scale = 0.6` | 1 | `with type JK2 scale= and rscales= are not needed and will be ignored` |
| ACS, `scale = 0.6` | 1 | `with type ACS scale= and rscales= are not needed and will be ignored` |
| successive-difference, `scale = 0.6` | 1 | `with type successive-difference scale= and rscales= are not needed and will be ignored` |
| JKn, no `rscales` (error) | error | `Must provide rscales for combined JKn weights` |

## Per-test result table

Got = surveycore value. Expected = `survey` value or the literal. Values are from a scratch script outside the repository that rebuilds each block on F1 (R = 20). The test files themselves also ran green at this tree (see the next section).

### Rows 6.1 to 6.4: supplied scale kept

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| 6.1 JK1 mean | 50.4365426842 | 50.4365426842 | 1e-10 | ✓ |
| 6.1 JK1 SE | 0.190881104233 | 0.190881104233 | 1e-8 | ✓ |
| 6.1 JK1 ci_low / ci_high | 50.06242259 / 50.81066277 | 50.06242259 / 50.81066277 | 1e-6 | ✓ |
| 6.1 JK1 stored scale sc / sv | 0.6 / 0.6 | 0.6 | 1e-8 | ✓ |
| 6.1 JK1 SE ratio | 0.794719414239 | sqrt(0.6 / (19 / 20)) = 0.794719414239 | 1e-8 | ✓ |
| 6.1 JK1 conditions | none / none | `expect_no_warning()` both | — | ✓ |
| 6.2 JKn mean | 50.4365426842 | 50.4365426842 | 1e-10 | ✓ |
| 6.2 JKn SE | 0.190881104233 | 0.190881104233 | 1e-8 | ✓ |
| 6.2 JKn ci_low / ci_high | 50.06242259 / 50.81066277 | 50.06242259 / 50.81066277 | 1e-6 | ✓ |
| 6.2 JKn stored scale sc / sv | 0.6 / 0.6 | 0.6 | 1e-8 | ✓ |
| 6.2 JKn SE ratio | 0.774596669241 | sqrt(0.6 / 1) = 0.774596669241 | 1e-8 | ✓ |
| 6.2 JKn conditions | none / none | `expect_no_warning()` both | — | ✓ |
| 6.3 bootstrap mean | 50.4365426842 | 50.4365426842 | 1e-10 | ✓ |
| 6.3 bootstrap SE | 0.190881104233 | 0.190881104233 | 1e-8 | ✓ |
| 6.3 bootstrap ci_low / ci_high | 50.06242259 / 50.81066277 | 50.06242259 / 50.81066277 | 1e-6 | ✓ |
| 6.3 bootstrap stored scale sc / sv | 0.6 / 0.6 | 0.6 | 1e-8 | ✓ |
| 6.3 bootstrap SE ratio | 3.37638860323 | sqrt(0.6 / (1 / 19)) = 3.37638860323 | 1e-8 | ✓ |
| 6.3 bootstrap conditions | none / none | `expect_no_warning()` both | — | ✓ |
| 6.4 other mean | 50.4365426842 | 50.4365426842 | 1e-10 | ✓ |
| 6.4 other SE | 0.190881104233 | 0.190881104233 | 1e-8 | ✓ |
| 6.4 other ci_low / ci_high | 50.06242259 / 50.81066277 | 50.06242259 / 50.81066277 | 1e-6 | ✓ |
| 6.4 other stored scale sc / sv | 0.6 / 0.6 | 0.6 | 1e-8 | ✓ |
| 6.4 other SE ratio | 0.774596669241 | sqrt(0.6 / 1) = 0.774596669241 | 1e-8 | ✓ |
| 6.4 other conditions | sc none; sv exactly 1, `scale or rscales not specified, set to 1` | same | — | ✓ |

### Rows 6.5 to 6.9: supplied scale discarded

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| 6.5 BRR mean | 50.4365426842 | 50.4365426842 | 1e-10 | ✓ |
| 6.5 BRR SE | 0.0551026284561 | 0.0551026284561 | 1e-8 | ✓ |
| 6.5 BRR ci_low / ci_high | 50.32854352 / 50.54454185 | 50.32854352 / 50.54454185 | 1e-6 | ✓ |
| 6.5 BRR stored scale sc / sv | 0.05 / 0.05 | 1 / 20 | 1e-8 | ✓ |
| 6.5 BRR conditions | sc `surveycore_warning_replicate_arg_ignored`; sv exactly 1, `type='BRR' does not use 'scale=' argument` | same | — | ✓ |
| 6.6 Fay mean | 50.4365426842 | 50.4365426842 | 1e-10 | ✓ |
| 6.6 Fay SE | 0.0787180406515 | 0.0787180406515 | 1e-8 | ✓ |
| 6.6 Fay ci_low / ci_high | 50.28225816 / 50.59082721 | 50.28225816 / 50.59082721 | 1e-6 | ✓ |
| 6.6 Fay stored scale sc / sv | 0.102040816327 / 0.102040816327 | 1 / (20 * 0.7^2) | 1e-8 | ✓ |
| 6.6 Fay conditions | none / none | `expect_no_warning()` both | — | ✓ |
| 6.7 JK2 mean | 50.4365426842 | 50.4365426842 | 1e-10 | ✓ |
| 6.7 JK2 SE | 0.246426445933 | 0.246426445933 | 1e-8 | ✓ |
| 6.7 JK2 ci_low / ci_high | 49.95355573 / 50.91952964 | 49.95355573 / 50.91952964 | 1e-6 | ✓ |
| 6.7 JK2 stored scale sc / sv | 1 / 1 | 1 | 1e-8 | ✓ |
| 6.7 JK2 conditions | sc `surveycore_warning_replicate_arg_ignored`; sv exactly 1, JK2 text | same | — | ✓ |
| 6.8 ACS mean | 50.4365426842 | 50.4365426842 | 1e-10 | ✓ |
| 6.8 ACS SE | 0.110205256912 | 0.110205256912 | 1e-8 | ✓ |
| 6.8 ACS ci_low / ci_high | 50.22054435 / 50.65254102 | 50.22054435 / 50.65254102 | 1e-6 | ✓ |
| 6.8 ACS stored scale sc / sv | 0.2 / 0.2 | 4 / 20 | 1e-8 | ✓ |
| 6.8 ACS conditions | sc `surveycore_warning_replicate_arg_ignored`; sv exactly 1, ACS text | same | — | ✓ |
| 6.9 successive-difference mean | 50.4365426842 | 50.4365426842 | 1e-10 | ✓ |
| 6.9 successive-difference SE | 0.110205256912 | 0.110205256912 | 1e-8 | ✓ |
| 6.9 successive-difference ci_low / ci_high | 50.22054435 / 50.65254102 | 50.22054435 / 50.65254102 | 1e-6 | ✓ |
| 6.9 successive-difference stored scale sc / sv | 0.2 / 0.2 | 4 / 20 | 1e-8 | ✓ |
| 6.9 successive-difference conditions | sc `surveycore_warning_replicate_arg_ignored`; sv exactly 1, successive-difference text | same | — | ✓ |

### Row 7.1 and the block run

`testthat::test_file()` at this tree, `NOT_CRAN=true`, `pkgload::load_all(helpers = TRUE)`:

| Block | Expectations | Failed | Warnings | Pass |
|---|---|---|---|---|
| 6.1 kept — JK1 | 10 | 0 | 0 | ✓ |
| 6.2 kept — JKn | 10 | 0 | 0 | ✓ |
| 6.3 kept — bootstrap | 10 | 0 | 0 | ✓ |
| 6.4 kept — other | 11 | 0 | 0 | ✓ |
| 6.5 discarded — BRR | 9 | 0 | 0 | ✓ |
| 6.6 discarded — Fay | 8 | 0 | 0 | ✓ |
| 6.7 discarded — JK2 | 9 | 0 | 0 | ✓ |
| 6.8 discarded — ACS | 9 | 0 | 0 | ✓ |
| 6.9 discarded — successive-difference | 9 | 0 | 0 | ✓ |
| 7.1 `as_svydesign()` reproduces `get_means()` for all nine types built with a supplied scale | 47 | 0 | 0 | ✓ |
| `test-variance-replicate.R`, whole file | 343 passed, 51 blocks | 0 | 1, in a pre-existing block | ✓ |
| `test-conversion.R`, whole file | 912 passed, 186 blocks | 0 | 0 | ✓ |

Block 7.1 asserts, for each of the nine types: the constructor condition, the `as_svydesign()` condition (exactly one warning with the text for JK2 and `other`, `expect_no_warning()` for the other seven), estimate at 1e-10, SE at 1e-8, and `sv$scale` against the per-type literal at 1e-8. The literals in the block are 0.6 (JK1, JKn, bootstrap, other), 1 / 5 (BRR), 1 / (5 * 0.7^2) (Fay), 1 (JK2), 4 / 5 (ACS, successive-difference). These match test-spec §7 row 7.1.

## Can each oracle block fail? (oracle rule 4)

Method: a scratch script outside the repository built each block's surveycore design, overwrote the design's stored scale with a defect value (`v <- sc@variables; v$scale <- defect; sc@variables <- v`), and compared `get_means()` against the unchanged `survey` side. The kept types got the type default (surveycore drops the supplied 0.6). The discarded types got 0.6 (surveycore keeps it, the defect issue #255 reports). No file under `R/` or `tests/` was edited.

| Type | Defect scale | Mean agrees (1e-10) | SE agrees (1e-8) | SE rel. error | ci_low agrees (1e-6) | ci_low rel. error | ci_high agrees (1e-6) | ci_high rel. error |
|---|---|---|---|---|---|---|---|---|
| JK1 | 19 / 20 | yes | no | 0.258 | no | 1.93e-3 | no | 1.90e-3 |
| JKn | 1 | yes | no | 0.291 | no | 2.17e-3 | no | 2.14e-3 |
| bootstrap | 1 / 19 | yes | no | 0.704 | no | 5.26e-3 | no | 5.18e-3 |
| other | 1 | yes | no | 0.291 | no | 2.17e-3 | no | 2.14e-3 |
| BRR | 0.6 | yes | no | 2.46 | no | 5.29e-3 | no | 5.27e-3 |
| Fay | 0.6 | yes | no | 1.42 | no | 4.37e-3 | no | 4.35e-3 |
| JK2 | 0.6 | yes | no | 0.225 | no | 2.18e-3 | no | 2.14e-3 |
| ACS | 0.6 | yes | no | 0.732 | no | 3.15e-3 | no | 3.12e-3 |
| successive-difference | 0.6 | yes | no | 0.732 | no | 3.15e-3 | no | 3.12e-3 |

On all nine types the point estimate stays green and the SE and both bounds turn red, by at least 1.9e3 times the bound tolerance. Each block also asserts the stored scale against a literal, which turns red under the same defect. The four kept blocks carry a ratio assertion, which reads 1 under a dropped scale and turns red.

## Oracle rule compliance

Counts by `parse(keep.source = TRUE)` plus `utils::getParseData()`, `SYMBOL_FUNCTION_CALL` tokens, `origin/develop` against HEAD:

| File | Call | develop | HEAD | Δ |
|---|---|---|---|---|
| `test-variance-replicate.R` | `svrepdesign` | 18 | 27 | +9 |
| | `suppressWarnings` | 0 | 0 | 0 |
| | `expect_failure` | 0 | 0 | 0 |
| | `test_invariants` | 1 | 1 | 0 |
| | `skip_if_not_installed` | 24 | 33 | +9 |
| | `test_that` | 42 | 51 | +9 |
| `test-conversion.R` | `svrepdesign` | 30 | 30 | 0 |
| | `suppressWarnings` | 41 | 41 | 0 |
| | `expect_failure` | 0 | 0 | 0 |
| | `test_invariants` | 6 | 6 | 0 |
| | `test_that` | 185 | 186 | +1 |

Per-block inspection of the parsed expressions in the ten new blocks:

| Check | Result |
|---|---|
| First statement is `skip_if_not_installed("survey")` | 10 of 10 |
| Every `expect_equal()` names `tolerance =` | 10 of 10; values are 1e-10 (mean), 1e-8 (SE, scales, ratio), 1e-6 (bounds) only |
| `suppressWarnings()` / `expect_failure()` / `test_invariants()` in a new block | 0 / 0 / 0 |
| Rule 2 — `scale` passed to `svrepdesign()` | The literal `0.6` in all nine oracle blocks. No value is read off a surveycore design. This is the test-spec §3 exception: 0.6 equals none of the nine defaults at R = 20, and the defect test above proves each block independent |
| Rule 3 — `rscales` passed to `svrepdesign()` | The JKn block only, the literal `rep(1, 20)` |
| Rule 5 — `survey` warnings | Captured with `testthat::capture_warnings()`, counted with `expect_length(w, 1L)`, matched with `expect_match(..., fixed = TRUE)`. None silenced |
| Each stored scale asserted against a literal, not the other side | Yes, 9 of 9 |
| Block 7.1 | Round-trip test, so rule 2 does not reach it; the block comment says so. It calls no `svrepdesign()` |
| Plan's textual count check (`suppressWarnings(` / `expect_failure(` on added code lines) | 0 |

## CRAN cookbook violations

None. No file under `R/` changed. A scan of the added test code lines for `<<-`, `options(`, `par(`, `setwd(`, `set.seed(`, `installed.packages(`, `mc.cores` and bare `T`/`F` found no hit.

## Before/After comparison

Before is the dispatch baseline (develop after PR 4). After is the leader's gate run on tree `117bc78`.

| Metric | Before PR | After PR | Δ |
|---|---|---|---|
| tests passing | 12580 | 12712 | +132 |
| test failures | 0 | 0 | 0 |
| test warnings | 256 | 256 | 0 |
| coverage | 96.18% | 96.18% | 0.00 |
| R CMD check notes | — | 1 (CRAN incoming feasibility, pre-approved) | — |

The +132 is fully accounted for: 10 + 10 + 10 + 11 + 9 + 8 + 9 + 9 + 9 = 85 expectations in the nine oracle blocks, plus 47 in block 7.1 (5 for each of seven types, 6 for JK2 and `other`).

Coverage is 96.18%, below the 98% target and above the 95% floor, and it did not move. No HOLD: the HOLD condition needs a drop.

## Signals

None. No HOLD, no BLOCK.
