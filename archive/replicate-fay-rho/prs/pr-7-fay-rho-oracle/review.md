# Review — PR 7 fay-rho-oracle

**Verdict**: PASS
**Branch**: `test/fay-rho-oracle`, HEAD `ad1350f`, tree `872352e`
**Base**: `develop` `dbe8b93`
**survey**: 4.5

## 1. Convergence

| Check | Result |
|---|---|
| Test-spec rows 2.1 to 2.11 and 6.12 each have an audit row | Yes. Every row in the plan's PR 7 budget appears in `audit.md` §Per-test result table |
| Each row has a block in the file | Yes. Twelve blocks, lines 975 to 1365: the refusal guard, seven oracle blocks (2.1 to 2.7), four surveycore-only blocks (2.8 to 2.11) |
| Plan tasks 1 to 10 | All done. Task 1: the refusal block keeps one text-matched assertion and loses the `1 / R` assertion and the "compares nothing" comment. Task 9: `test_invariants` stays at 1 call |
| Write surface against Files touched | Match. `git diff --name-only dbe8b93...HEAD` lists only `tests/testthat/test-variance-replicate.R` |

## 2. Tolerance integrity

A parse of the 12 Fay blocks (`parse()` walk, not `grep -c`) finds 48 `expect_equal()` calls. Every one sets `tolerance`: 8 at 1e-10, 26 at 1e-8, 14 at 1e-6. None uses the testthat default. These figures agree with `audit.md`. Every value equals `test-spec.md` §Tolerances, including the 1e-8 for stored scales and SE ratios. No tolerance is looser or tighter than the spec.

## 3. Oracle rule, per comparison (rows 2.1 to 2.7)

| Rule | Result |
|---|---|
| 1. Same inputs, `mse` explicit on both sides | `make_fay_oracle_pair()` builds fixture FA once. It gives `d$wt` and `d[, repwt_cols]` to `survey`, and `wt` with the same columns to surveycore. `mse` and `rho` go to both sides from the same block literal |
| 2. `scale` passed to neither side | No `scale =` in any call in lines 975 to 1365 |
| 3. `rscales` only for JKn | No oracle call passes `rscales`. Row 2.10 passes it to surveycore only, with no `survey` side |
| 4. SE and bounds asserted | Each of the seven blocks asserts the estimate, SE, `ci_low` and `ci_high`. Row 2.7 matches rows by group level through `match()` and asserts that no level is missing |
| 5. Conditions asserted, not silenced | Both constructors sit in `expect_no_warning()` in the helper. The file has 0 `suppressWarnings()` calls. The refusal is matched by message text |
| Stored scale against a literal, each side alone | Each block asserts `pair$sc@variables$scale` and `pair$sv$scale` separately against `1 / (10 * (1 - rho)^2)` (`1 / 10` at rho 0). No assertion compares one side with the other |
| Formula used only as an assertion literal | Yes. The scale formula appears only inside `expect_equal()` |
| Match `survey` conditions by text | Yes, `fixed = TRUE` on "With type='Fay' you must supply the correct rho" |

**The helper.** `make_fay_oracle_pair()` reads only the frame it builds, `repwt_cols`, and its two arguments. It passes no surveycore number to `survey`. It holds the two `expect_no_warning()` wrappers. Each of the seven oracle blocks calls it inside its own `test_that()`, so both wrappers run in every block. The helper does not hold the stored-scale assertions; each block writes its own two literals. No required assertion is hidden.

**Degrees-of-freedom comment.** The Block 24b header (lines 1018 to 1024) states the precondition, names both sides (surveycore infinite df, `confint()` default `df = Inf`), says a df move shifts bounds while mean and SE stay, and says to read that as a df change. `degf <- Inf` is present in `R/analysis-means.R:166` and `R/analysis-totals.R:166`, so the comment is true of the shipped code.

## 4. Scope and regressions

`HEAD:R` = `dbe8b93:R` = `cfa0dbed`. Warnings stay at 256, skips at 4, failures at 0. No test outside the PR changed state. No `_snaps/` change.

## 5. Gates and coverage

All eight gates PASS on tree `872352e`; logs in `gates/`. R CMD check: 0 errors, 0 warnings, 2 NOTEs (CRAN incoming feasibility, pre-approved; `.git` hidden files, allowed by criterion G item 4). Coverage 96.16%, unchanged; the PR adds no line under `R/`. CRAN cookbook: none.

## 6. Comprehension alignment

The gotchas that reach this PR are covered. `rho = 0` is rows 2.2 and 2.8. `rho` near 1 is row 2.4. `mse` is row 2.5. `rscales` is row 2.10. Degrees of freedom is the comment. All-NA is row 2.11. The out-of-scope gotchas carry reasons in `test-spec.md` §Gotchas out of scope.

## 7. For PR 9

After this PR, the Fay comparisons are ordinary oracle tests that need no sanctioned exception. The spec §VIII.4 paragraph ("the Fay block became an ordinary oracle test") is true of Block 24b. One block remains, "survey::svrepdesign() refuses Fay without rho — Fay design". It compares nothing, by plan task 1. It asserts only `survey`'s own refusal and reads no surveycore value, so the oracle rule does not reach it and it is not an exception. PR 9 must not describe that guard block as an oracle test.

## Non-blocking notes

- Row 2.11 passes trivially if both sides return all `NA`, which they do. The test-spec allows that outcome.
- The comment "Both return; neither raises" in row 2.11 is not asserted for warnings. The suite warning count (256, unchanged) shows neither call warns.

## Signals

PASS. No BLOCK, no STOP.
