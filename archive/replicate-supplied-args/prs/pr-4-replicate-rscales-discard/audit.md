# Audit — PR 4: fix/replicate-rscales-discard

**Verdict: PASS**

Tree: d4c69f7c35c30e9ef3720327b9fedb2d34518473
HEAD: c00b2b7 (base origin/develop a2d4759)
Request: replicate-supplied-args, issue #255
Date: 2026-10-13

## Profile gates

The leader ran gates 1 to 7 on tree d4c69f7. The tester did not re-run them. The logs are in `prs/pr-4-replicate-rscales-discard/logs/`. The tester read the `Status:` line in `gate-5-check.log` and the summary lines of gates 2 and 7.

| # | Gate | Result | Evidence |
|---|---|---|---|
| 1 | `devtools::document()` | PASS | wrote nothing |
| 2 | `devtools::test()` | PASS | `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 12580 ]`; 256 warnings = the pre-existing AAPOR count |
| 3 | `devtools::run_examples()` | PASS | |
| 4 | `R CMD build` | PASS | |
| 5 | `R CMD check --as-cran --no-manual` | PASS | `Status: 1 NOTE` (line 93); the NOTE is `checking CRAN incoming feasibility` (line 14), pre-approved |
| 6 | `pkgdown::build_site()` | PASS | |
| 7 | covr, `NOT_CRAN=true` | PASS | 96.18% (develop 96.18%); `UNCOVERED_COUNT=3`, lines 414, 2071, 2162 of `R/core-constructors.R` = develop's 414, 2062, 2153 shifted by +9. Added hunks 964–971, 981–983, 1003–1005 have no uncovered line |
| G7 | `air format --check` | PASS | `R/core-constructors.R` and `tests/testthat/test-conversion.R`: exit 0. `test-constructors.R`: a formatted copy differs only at lines 4163 and later; the PR adds lines 1988–2297, so air proposes no change inside the PR's lines |
| G8 | Snapshots | PASS | `_snaps/constructors.md` diff is two added entries only (5.7, 5.8); no existing entry changed |
| G9 | Paths | PASS | no path under `.surveycore-workspace/`; other paths are in Files touched or under `plans/` |
| G10 | `as_survey_nonprob()` body | PASS | parsed from both trees by srcref: 298 lines each, `identical() = TRUE` |

## Per-test result table

The tester ran `test-constructors.R` and `test-conversion.R` with `testthat::test_file()` after `load_all()`, `NOT_CRAN=true`. Both files: 0 failed, 0 errored. The `nb` column is the expectation count per block.

| Row | Block | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|---|
| 5.5 | discards a supplied rscales for JK2, ACS and successive-difference | 12 exp, 0 fail, 0 warn | warns with `replicate_arg_ignored`; `rscales` NULL; `@variables` identical to plain; SE equal, 3 types | SE 1e-8 | ✓ |
| 5.7 | discard warning names scale and rscales together | 1 exp, 0 fail | snapshot text = task 2 text word for word | — | ✓ |
| 5.8 | discard warning names rscales alone | 1 exp, 0 fail | snapshot text = task 3 text word for word ("has", "was", "value") | — | ✓ |
| 5.9 | raises one discard warning for scale and rscales together | 9 exp, 0 fail | `length(w) = 1`; scale 1, 4/20, 4/20; `rscales` NULL | scale 1e-8 | ✓ |
| 5.11 | keeps a supplied rscales for JK1, JKn, BRR, Fay, bootstrap and other | 12 exp, 0 fail | no warning; `rscales` identical to `rep(0.5, 20)`, 6 types | — | ✓ |
| 5.14 | checks rscales length before discarding it | 2 exp, 0 fail | `rscales_length` error, no warning | — | ✓ |
| 5.15 | checks rscales values before discarding them | 2 exp, 0 fail | `rscales_na` error, no warning | — | ✓ |
| 5.17 | refuses JKn with rscales = NULL passed explicitly | 1 exp, 0 fail | `stratified_jk_rscales_unset` | — | ✓ |
| 5.19 | refuses a one-row JKn frame before the JKn refusal | 1 exp, 0 fail | `single_row` | — | ✓ |
| 5.19 (pinned) | refuses five frames before the scale switch (existing) | 5 exp, 0 fail | unchanged, passes | — | ✓ |
| 5.21 | builds JK2 with no rscales and raises nothing | 3 exp, 0 fail | no condition; `rscales` NULL; scale 1 | scale 1e-8 | ✓ |
| 5.27 | discards scale and rscales by the closed type sets | 27 exp, 0 fail | 9 types, each condition, scale and `rscales` = the test-spec §5.27 table | scale 1e-8 | ✓ |
| T11 | every accepted replicate type crosses both conversion routes | 55 exp, 0 fail, 0 warn | `rscales` to JKn only; no unasserted surveycore warning | unchanged | ✓ |

### Row 5.17 confirmation

Row 5.17 lands in this PR. The block "as_survey_replicate() refuses JKn with rscales = NULL passed explicitly" passes `rscales = NULL` written out on F1 and asserts `class = "surveycore_error_stratified_jk_rscales_unset"`. It passes. T4 ("JKn with rscales = NULL stores scale = 1") is absent from the file (0 matches). Rows 5.16 (PR 2) and 5.17 (this PR) together replace T4.

### Content checks on the new blocks

- The 5.27 block's expected list matches the test-spec table on all nine rows, including BRR keeping `rep(0.5, 20)` and Fay storing `1 / (20 * (1 - 0.3)^2)`.
- Every new `expect_equal()` carries `tolerance = 1e-8`. None uses the testthat default.
- Warnings use `expect_warning(d <- ..., class = ...)`. The count rows use `testthat::capture_warnings()`, as rows 5.9 specifies.
- All fixtures are F1 as written in the plan.
- No new `test_invariants()` call (0 added lines). No added `suppressWarnings(` or `expect_failure(` (plan check: 0).
- T11 textual checks, as the plan writes them: `c("JK2", "JKn")) rep(1, 5L)` = 0; `identical(ty, "JKn")) rep(1, 5L)` = 1; the one removed line is the old `rs <-` line. The comment above the block names no ACS `survey` warning.

### Pass delta

Develop after PR 3: 12509. This PR: 12580. Delta +71. The 11 new blocks carry 12 + 1 + 1 + 9 + 27 + 12 + 3 + 2 + 2 + 1 + 1 = 71 expectations. T11 changes no count, because its loop and assertions are unchanged. The delta is accounted for in full.

## CRAN cookbook violations

None. The scan read the 14 added lines in `R/core-constructors.R`, with comments and strings removed. A scan of the whole file finds only `#' set.seed(1)` at lines 749 and 1608, which are roxygen examples and are present on develop.

## Before/After comparison

| Metric | Before PR (develop after PR 3) | After PR | Δ |
|---|---|---|---|
| tests passing | 12509 | 12580 | +71 |
| test failures | 0 | 0 | 0 |
| test warnings | 256 | 256 | 0 |
| coverage | 96.18% | 96.18% | 0 |
| uncovered lines, `R/core-constructors.R` | 3 (414, 2062, 2153) | 3 (414, 2071, 2162) | 0 |
| R CMD check notes | not in baseline | 1 (CRAN incoming feasibility) | — |

Coverage is 96.18%, above the 95% floor and unchanged. No HOLD condition applies.

## Signals

None. No HOLD, no BLOCK.
