# Audit — PR 3 `fix/replicate-scale-discard` (issue #255)

**Verdict: PASS**

Tree: fb291a3eef5c905d468f01028dfd650a268c0f2c (HEAD 56caab0, base origin/develop 0d2faa2)

## Profile gates

The leader ran gates 1 to 7 on tree fb291a3. The tester did not re-run them. The tester read the `Status:` line and the test totals line in the logs.

| Gate | Result | Evidence |
|---|---|---|
| 1 `devtools::document()` | PASS | wrote nothing |
| 2 `devtools::test()` | PASS | `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 12509 ]` (`logs/gate-2-test.log`); warnings held at 256 |
| 3 `run_examples()` | PASS | leader |
| 4 `R CMD build` | PASS | leader |
| 5 `R CMD check --as-cran --no-manual` | PASS | `Status: 1 NOTE` (`logs/gate-5-00check.log`); the one note is `checking CRAN incoming feasibility`, pre-approved |
| 6 `pkgdown::build_site()` | PASS | leader |
| 7 `covr` (`NOT_CRAN=true`) | PASS | 96.18% (was 96.17%). Uncovered lines in `R/core-constructors.R`: 414, 2062, 2153, the three pre-existing lines (414, 2026, 2117 on develop) moved by the 36-line hunk. Added hunk is lines 963 to 998; no added line is uncovered |
| 8 snapshots | PASS | `_snaps/constructors.md` diff: one new entry, "as_survey_replicate() discard warning names scale alone". No existing entry changes |
| 9 changed paths | PASS | `R/core-constructors.R`, `tests/testthat/test-constructors.R`, `tests/testthat/_snaps/constructors.md` (Files touched), plus two files under `plans/`. Nothing under `.surveycore-workspace/` |
| 10 `as_survey_nonprob()` body | PASS | top-level expression text from `getParseData()` on origin/develop and HEAD: 9063 characters each, `identical()` TRUE |
| `air format --check` | PASS | `R/core-constructors.R` clean (exit 0). A formatted copy of `test-constructors.R` changes lines from 3853 on only, all pre-existing; the added lines 1650 to 1986 get no change |

## Per-test result table

The tester ran `testthat::test_file("tests/testthat/test-constructors.R", load_package = "source")` with `NOT_CRAN=true`. File totals: 1026 expectations, 0 failed, 0 errors, 0 skipped. Fixture F1 has 20 replicate columns (checked).

| Row | Test block | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|---|
| 5.1 | discards a supplied scale for BRR, JK2, ACS and successive-difference | 16 expectations, 0 failed, 0 warnings | warn class `surveycore_warning_replicate_arg_ignored`; stored 1/20, 1, 4/20, 4/20; `@variables` identical to `d_plain`; no warning on `d_plain` | 1e-8 | ✓ |
| 5.2 | discards a supplied scale for Fay with no warning (existing, unchanged) | 2 expectations, 0 failed | no warning; stored `1 / (20 * 0.7^2)` | 1e-8 | ✓ |
| 5.3 | warns for a supplied BRR scale equal to the default | 1, 0 failed | warns with the class | n/a | ✓ |
| 5.4 | discards a non-numeric scale without checking it | 12, 0 failed | no error around the warning; stored own scale on all four types | 1e-8 | ✓ |
| 5.6 | discard warning names scale alone | 1 snapshot, 0 failed | singular text; snapshot matches test-spec §2 word for word | n/a | ✓ |
| 5.28 | never checks a discarded scale | 70, 0 failed | five values x four warning types (warn, own scale, identical `@variables`) plus Fay `expect_no_condition()` and `1 / (20 * 0.7^2)` | 1e-8 | ✓ |
| 5.24 | discards a supplied scale at one replicate column | 8, 0 failed | BRR/ACS/SD warn and store 1, 4, 4; JKn `rscales = 1` no condition, stores 1 | 1e-8 | ✓ |
| 5.25 | discards a supplied scale on an all-NA outcome frame | 3, 0 failed | JK2 warns; stores 1; `y1` all NA | 1e-8 | ✓ |
| 5.10 | keeps a supplied scale for JK1, JKn, bootstrap and other | 8, 0 failed | no warning; stores 0.6 | 1e-8 | ✓ |
| 5.12 | raises no warning on any type when scale and rscales are not supplied | 9, 0 failed | no warning on all nine types | n/a | ✓ |
| 5.13 | treats an explicit NULL scale and rscales as not supplied | 4, 0 failed | no warning on the four types | n/a | ✓ |
| 5.20 | builds JKn with rscales and stores scale 1 | 2, 0 failed | no condition; stores 1 | 1e-8 | ✓ |

Checks on the added test code:

- Every added `expect_equal()` (nine call sites) carries `tolerance = 1e-8`, the plan's value for a stored scale. None relies on the testthat default.
- Every warning is captured with `expect_warning(d <- ..., class = ...)`.
- Added code lines with `suppressWarnings(`, `expect_failure(`, `withCallingHandlers(` or `tryCatch(`: 0.
- The added blocks call `test_invariants()` 0 times.
- Row 5.28 in test-spec names BRR only for part (a). The block covers all four warning types, per plan task 5. This is a superset.

## CRAN cookbook violations

None. The scan covered the 28 added non-comment code lines in `R/core-constructors.R`.

## Before/After comparison

| Metric | Before PR (develop after PR 2) | After PR | Δ |
|---|---|---|---|
| tests passing | 12375 | 12509 | +134 |
| test failures | 0 | 0 | 0 |
| test warnings | 256 | 256 | 0 |
| coverage | 96.17% | 96.18% | +0.01% |
| R CMD check notes | 1 | 1 | 0 |

The +134 equals the expectations in the eleven new blocks: 16 + 1 + 12 + 1 + 70 + 8 + 3 + 8 + 9 + 4 + 2 = 134.

## Signals

No HOLD and no BLOCK.
