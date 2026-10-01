# Audit — PR 2: fay-rho-constructor-conditions

**Verdict: PASS**

Branch `test/fay-rho-constructor-conditions`, HEAD `46d58f1`, base `develop` `6801065`.

Tree: 9afc8f1f50347474d6323afc95b6cccc71a97b5c

## Profile gates

The orchestrator ran the gates on this tree. Logs are in `gates/`. The tester did not re-run them.

| Gate | Result | Notes |
|---|---|---|
| devtools::document() | PASS | wrote nothing |
| devtools::test() | PASS | FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 12179 |
| run_examples() | PASS | all examples ran |
| R CMD build | PASS | surveycore_1.1.0.9000.tar.gz |
| R CMD check --as-cran --no-manual | PASS | 0 errors, 0 warnings, 2 NOTEs |
| pkgdown | PASS | site built |
| covr | PASS | 96.16% |

Tree: 9afc8f1f50347474d6323afc95b6cccc71a97b5c

NOTE review (gate-5-check.log lines 14, 37):

- `checking CRAN incoming feasibility`: pre-approved.
- `hidden files and directories: .git`: pre-existing, caused by `.Rbuildignore`, accepted by plan criterion G.4.

Coverage, changed `R/` files: core-classes.R 94.22%, core-constructors.R 96.83%, utils.R 99.59%.

- The uncovered lines are core-classes.R 348, 349, 355-357, 372, 710; core-constructors.R 414, 1980, 2071; utils.R 377, 487.
- The PR's `R/` changes are roxygen only: core-classes.R 584, 610-611, 653; core-constructors.R 779. No uncovered line is in the diff.
- PR 1's uncovered line core-constructors.R:902 (`"a value of length 0"`) is now line 901, because this PR removed one roxygen line above it. Line 901 is not in the uncovered list, so the `numeric(0)` snapshot (row 1.9 area, task 4) covers it.

Filtered run by the tester: `NOT_CRAN=true devtools::test(filter = "^constructors$")` finished with no failure. No warning comes from the new blocks (test-constructors.R lines 1177-1389).

## Per-test result table

| Row | Test | Got | Expected | Tolerance in code | Pass |
|---|---|---|---|---|---|
| 1.3 | eight non-Fay types: `rho` key present, value `NULL` | TRUE / NULL (16 expectations) | TRUE / NULL | identical | ✓ |
| 1.4 | Fay `rho = 0.3`: `rho` key present | TRUE | TRUE | n/a | ✓ |
| 1.4b | positional call: `@variables$rho` | 0.3 | 0.3 | `tolerance = 1e-10` | ✓ |
| 1.4b | positional call: `@variables$scale` | 1 / (20 * 0.7^2) | `1 / (20 * (1 - 0.3)^2)` | `tolerance = 1e-8` | ✓ |
| 1.6 | Fay, `rho = NULL` explicit | `surveycore_error_fay_rho_missing` | same | class only | ✓ |
| 1.8 | Fay, `rho = "0.5"` class | `surveycore_error_fay_rho_invalid` | same | class | ✓ |
| 1.8 | snapshot names the class | `Got <character>: 0.5.` | names `character` | snapshot | ✓ |
| task 4 | `numeric(0)` snapshot | `Got <numeric>: a value of length 0.` | "a value of length 0" | snapshot | ✓ |
| task 4 | six-value snapshot | `0.1, 0.2, 0.3, 0.4, 0.5` | first five values | snapshot | ✓ |
| 1.9 | 14 invalid `rho` values | each `surveycore_error_fay_rho_invalid`; list length asserted 14L | same | class only | ✓ |
| 1.12 | eight non-Fay types, no `rho` | no warning | `expect_no_warning()` | n/a | ✓ |
| 1.13 | BRR, `rho = "a"` | `surveycore_warning_rho_ignored`, no error, `rho` NULL | only that warning | class | ✓ |
| 6.2 | Judkins (1990) citation in both Rd files | JOS 6(3), 223--239 (as_survey_replicate.Rd:240-241, survey_replicate.Rd:95-96) | JOS, never JASA | text | ✓ |
| 6.3 | `rho` among design variables in survey_replicate.Rd | lines 24 and 61 | listed | text | ✓ |

Row 1.13 "only": `expect_warning(class =)` does not fail on a second warning. The gate-2 warning count stayed at 256, the develop baseline, and the filtered run shows no warning from the block. So no second warning occurs.

The only numeric `expect_equal()` calls in the new blocks are the two in row 1.4b. Both set a tolerance: 1e-10 on `rho`, 1e-8 on `scale`. These match the test-spec: point 1e-10, stored scale 1e-8.

`test_invariants()`: the diff adds no call. The file keeps its existing calls (lines 22, 479, 2096, 2501). This matches the test-spec §1 note.

No test title carries a row id.

## Acceptance criteria (implementation-plan PR 2)

| # | Criterion | Evidence | Pass |
|---|---|---|---|
| 1 | `rho` key on every FT design | rows 1.3, 1.4 | ✓ |
| 2 | positional call stores 0.3 and the Fay scale | row 1.4b | ✓ |
| 3 | explicit `rho = NULL` refused | row 1.6 | ✓ |
| 4 | `"0.5"` snapshot names `character`; length-0 and five-value snapshots; 14 values refused | rows 1.8, 1.9, task 4 | ✓ |
| 5 | no warning for eight types; BRR `"a"` warns only | rows 1.12, 1.13 | ✓ |
| 6 | Judkins in JOS in both Rd files; `rho` listed | rows 6.2, 6.3 | ✓ |
| 7 | G | see below | ✓ |

Criterion G:

- G1-G6: see the gate table.
- G7 (air): `air format --check` flags test-constructors.R on develop and on HEAD. The tester formatted copies of both with air 0.11.0. Each gives 58 hunks, and no hunk is in the PR's lines 1177-1389. The PR adds no air violation. Four new test titles run past 80 columns; air does not rewrap strings, and existing titles in the file do the same.
- G8: `_snaps/constructors.md` gains one entry, the new block, with its three snapshots. No other snapshot changed.
- G9: `git diff --name-only 6801065...HEAD` lists R/core-classes.R, R/core-constructors.R, man/as_survey_replicate.Rd, man/survey_replicate.Rd, tests/testthat/_snaps/constructors.md, tests/testthat/test-constructors.R. All six are in Files touched. The R/core-constructors.R change is the `@references` roxygen only (3 lines to 2), so task 9 found no PR 1 defect.

## CRAN cookbook violations

None. The scan covered the added non-comment lines of every changed `.R` file. The `R/` changes are roxygen comments only.

## Before/After comparison

| Metric | Before PR (develop a11fe29) | After PR (9afc8f1) | Δ |
|---|---|---|---|
| tests passing | 12129 | 12179 | +50 |
| tests failing | 0 | 0 | 0 |
| warnings | 256 | 256 | 0 |
| skips | 4 | 4 | 0 |
| coverage | 96.15% | 96.16% | +0.01% |
| R CMD check notes | 2 | 2 | 0 |

No regression. Coverage is above the 95% floor.

## HOLDs

None.
