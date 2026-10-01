# Audit: PR 3 — fay-rho-constructor-edges

**Verdict: PASS**

Branch: `test/fay-rho-constructor-edges`, HEAD `2e24a81`, base `develop` `b4c0a88`.
Tree: b6526285931d93e73ff812d170ccd9c409bdca1a

## Profile gates

The orchestrator ran the gates on this tree. The tester did not re-run them (low memory). Logs: `prs/pr-3-fay-rho-constructor-edges/gates/`.

| Gate | Result | Notes |
|---|---|---|
| devtools::document() | PASS | document() wrote nothing |
| devtools::test() | PASS | FAIL 0, WARN 256, SKIP 4, PASS 12199 |
| run_examples() | PASS | all examples ran |
| R CMD build | PASS | surveycore_1.1.0.9000.tar.gz |
| R CMD check --as-cran --no-manual | PASS | 0 errors, 0 warnings, 2 NOTEs |
| pkgdown | PASS | site built |
| covr | PASS | 96.16% (floor 95%) |

Tree: b6526285931d93e73ff812d170ccd9c409bdca1a

NOTE review (gate-5-check.log lines 14 and 37):

- "checking CRAN incoming feasibility": pre-approved.
- "checking for hidden files and directories" (`.git`): pre-existing, and named as allowed in plan criterion G4.

The covr "changed R/ files: 3" line uses a stale local `develop` ref. `git diff --name-only b4c0a88...HEAD` lists one file, `tests/testthat/test-constructors.R`. The PR changes no file under `R/`.

Other criterion G items:

| Item | Result | Evidence |
|---|---|---|
| G7 air | PASS | `air format` on the base file and the head file gives 58 hunks each. No hunk falls in the added range (lines 1390 to 1625). All 58 are pre-existing. |
| G8 snapshots | PASS | `git diff b4c0a88...HEAD -- tests/testthat/_snaps` is empty |
| G9 files touched | PASS | only `tests/testthat/test-constructors.R`, as the plan lists |

## Per-test result table

Filtered run: `NOT_CRAN=true`, `devtools::test(filter = "constructors")`. The file has 305 blocks and 885 expectations, with 0 failures and 0 errors. The 16 warnings are from pre-existing nonprob blocks near line 3104. The 12 new blocks raise 0 warnings.

| Row | Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|---|
| 1.14 | rho = 0: rho, scale, type | 3/3 expectations pass | rho 0; scale 1/20; type "Fay" | rho 1e-10; scale 1e-8; type identical | ✓ |
| 1.15 | rho = 0L stored as double | 1/1 | identical to 0 | identical | ✓ |
| 1.16 | rho = c(a = 0.3) stored unnamed | 2/2 | names NULL; value 0.3 | 1e-10 | ✓ |
| 1.17 | rho = 0.999 scale | 1/1 | 1/(20*(1-0.999)^2) | 1e-8 | ✓ |
| 1.18 | scale = 99 discarded, no warning | 2/2 | expect_no_warning; 1/(20*(1-0.3)^2) | 1e-8 | ✓ |
| 1.19 | rscales = rep(2, 20) kept | 2/2 | identical rep(2, 20); Fay scale | identical; 1e-8 | ✓ |
| 1.20 | mse = FALSE | 1/1 | mse identical FALSE | identical | ✓ |
| 1.21 | one replicate column, rho = 0.5 | 3/3 | repweights "rep1"; scale 1/(1-0.5)^2 and 4 | 1e-8 | ✓ |
| 1.22 | zero-row frame, no rho | 1/1 | surveycore_error_empty_data | class | ✓ |
| 1.23 | one-row frame, no rho | 1/1 | surveycore_error_single_row | class | ✓ |
| 1.24 | rscales length 3, no rho | 1/1 | surveycore_error_rscales_length | class | ✓ |
| 1.25 | update_design(weights = wt2) keeps rho | 2/2 | weights "wt2"; rho 0.3 | identical; 1e-10 | ✓ |

Tolerance integrity: every numeric `expect_equal()` in the new blocks sets an explicit tolerance. Stored rho uses 1e-10, and stored scale uses 1e-8. Those are the values that test-spec §Tolerances gives. No tolerance was relaxed.

Row 1.25 handles the `update_design()` message with `suppressMessages()`. The existing blocks in `test-update-design.R` use the same pattern (lines 14 onward). No new block calls `test_invariants()`. The file already calls it at lines 22, 479, 2332 and 2737, so the once-per-constructor-per-file rule holds.

The acceptance criteria for PR 3 in the implementation plan:

| Criterion | Rows | Result |
|---|---|---|
| 1 | 1.14 to 1.17 | ✓ |
| 2 | 1.18 | ✓ |
| 3 | 1.19, 1.20 | ✓ |
| 4 | 1.21 | ✓ |
| 5 | 1.22 to 1.24 | ✓ |
| 6 | 1.25 | ✓ |
| 7 (G) | gates above | ✓ |

## CRAN cookbook violations

None. The PR changes no `R/` file. The added test lines contain no T/F abbreviation, no `set.seed(`, no `<<-`, no `options(`/`par(`/`setwd(`, no `installed.packages(`, and no bare `print(`/`cat(`.

## Before/After comparison

| Metric | Before PR (develop b4c0a88, tree 9afc8f1) | After PR (tree b652628) | Δ |
|---|---|---|---|
| tests passing | 12179 | 12199 | +20 |
| failures | 0 | 0 | 0 |
| warnings | 256 | 256 | 0 |
| skips | 4 | 4 | 0 |
| coverage | 96.16% | 96.16% | 0.00 |
| R CMD check NOTEs | 2 | 2 | 0 |

The +20 matches the 20 expectations in the 12 new blocks (3+1+2+1+2+2+1+3+1+1+1+2).

## HOLDs

None.
