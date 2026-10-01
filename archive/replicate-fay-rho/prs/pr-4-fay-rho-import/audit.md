# Audit — PR 4 `feature/fay-rho-import`

**Verdict: PASS**

Tree: dd70f9edfd9c23173e1016c0e29c431519454d5d
HEAD: 8aa215e. Base: develop d9d38ee (tree b652628).
Installed `survey`: 4.5 (confirmed with `packageVersion("survey")`).

## Profile gates

The orchestrator ran the gates on tree dd70f9e before dispatch. Logs are in
`prs/pr-4-fay-rho-import/gates/`. The tester did not re-run them, because
the host is low on memory.

| Gate | Result | Notes |
|---|---|---|
| devtools::document() | PASS | document() wrote nothing |
| devtools::test() | PASS | FAIL 0, WARN 256, SKIP 4, PASS 12213 |
| run_examples() | PASS | all examples ran |
| R CMD build | PASS | surveycore_1.1.0.9000.tar.gz |
| R CMD check --as-cran --no-manual | PASS | first run (gate-5-check.log) killed at the test phase, no Status line; re-run on the same tree (gate-5b-check.log) gives `Status: 2 NOTEs` |
| pkgdown | PASS | site built |
| covr | PASS | 96.16%; R/methods-conversion.R 99.77% |

Tree: dd70f9edfd9c23173e1016c0e29c431519454d5d

NOTE review (gate-5b-check.log):

- `checking CRAN incoming feasibility`: pre-approved.
- `checking for hidden files and directories` (`.git`): pre-existing on
  develop, caused by `.Rbuildignore` in a worktree checkout. This PR does
  not touch it. The Before column also carries 2 NOTEs.

Coverage: the one uncovered line in R/methods-conversion.R is line 649. The
PR diff touches only lines 1009 to 1031 of that file
(`git diff d9d38ee...HEAD`), so line 649 is not in this PR's diff.

WARN 256: equal to the develop baseline (the 256 pre-existing AAPOR
small-cell warnings, D12 of the svydesign-replicate-bridge archive). No new
warning.

Filtered run on the tester's side:
`devtools::test(filter = "conversion")` gave no failure, no warning and no
skip.

## Per-test result table

Measured values come from a probe script that rebuilt each fixture. The
assertions and tolerances come from the test file.

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| 4.1 imported `rho` (Fay, fay.rho = 0.3) | 0.3 | 0.3 | 1e-10 | ✓ |
| 4.1 imported scale vs `src$scale` | 0.25510204081632659 | 0.25510204081632659 | 1e-10 | ✓ |
| 4.1 `get_means(y1)` SE vs `survey::svymean()` SE | 0.31878610000670371 | 0.31878610000670043 (diff 3.3e-15) | 1e-8 | ✓ |
| 4.2 source `$rho` (BRR) | 0 | 0 | identical | ✓ |
| 4.2 key `rho` present | TRUE | TRUE | expect_true | ✓ |
| 4.2 imported `rho` | NULL | NULL | identical | ✓ |
| 4.3 survey warning on BRR with rho = 0.3 | "type='BRR' does not use 'rho=' argument, you may want type='Fay'" | text "does not use 'rho=' argument" | expect_warning, fixed = TRUE | ✓ |
| 4.3 source `$rho` | 0.3 | 0.3 | 1e-10 | ✓ |
| 4.3 key `rho` present, imported `rho` | TRUE, NULL | TRUE, NULL | identical | ✓ |
| 4.4 imported `type` (BRR with fay.rho = 0.3) | "Fay" | "Fay" | identical | ✓ |
| 4.4 imported `rho` | 0.3 | 0.3 | 1e-10 | ✓ |
| 4.6 round-trip block, intermediate `rho` (fay.rho = 0.5) | 0.5 | 0.5 | 1e-10 | ✓ |
| 4.6 round-trip block, existing assertions | unchanged, pass | pass | as before | ✓ |
| 4.6 all-types block, Fay pass re-import `rho` | 0.3 | 0.3 | 1e-10 | ✓ |

Tolerance integrity: every new or edited numeric `expect_equal()` sets an
explicit tolerance. Five set 1e-10 (rho and scale values; the scale row is
tighter than the 1e-8 floor, which is allowed). One sets 1e-8 (the SE in
4.1). No tolerance is looser than the test-spec value.

Oracle rule: row 4.3 captures survey's bare warning with `expect_warning()`
and matches it by message text (`fixed = TRUE`). No `suppressWarnings()`
appears in the new blocks. No block passes `scale` to `survey`. Rows 4.1
and 4.6 are round-trip rows, which the oracle rule does not reach.

`test_invariants()`: not called in the new blocks. test-conversion.R
already calls it for the constructors it uses; the per-file rule does not
ask for a new call.

## Acceptance criteria (implementation-plan.md, PR 4)

| Criterion | Evidence | Met |
|---|---|---|
| 1. Fay import: rho 0.3, scale at 1e-10, SE at 1e-8 (4.1) | rows 4.1 | ✓ |
| 2. BRR imports with key present and NULL, both sources (4.2, 4.3) | rows 4.2, 4.3 | ✓ |
| 3. BRR with fay.rho = 0.3 imports as "Fay" with rho 0.3 (4.4) | row 4.4 | ✓ |
| 4. Fay round trip intermediate rho 0.5; all-types Fay pass rho 0.3 (4.6) | rows 4.6 | ✓ |
| 5. G (gates) | gate table | ✓ |

Files touched: `R/methods-conversion.R` and
`tests/testthat/test-conversion.R` only, which matches the plan.

## CRAN cookbook violations

None. The added lines in R/methods-conversion.R are one comment block, one
`rho <- if (identical(x$type, "Fay")) x$rho else NULL` assignment, and one
`rho = rho,` argument. No pattern from the profile matches.

## Before/After comparison

| Metric | Before PR (develop d9d38ee) | After PR (dd70f9e) | Δ |
|---|---|---|---|
| tests passing | 12199 | 12213 | +14 |
| tests failing | 0 | 0 | 0 |
| warnings | 256 | 256 | 0 |
| skips | 4 | 4 | 0 |
| coverage | 96.16% | 96.16% | 0 |
| R CMD check notes | 2 | 2 | 0 |

## HOLDs

None.
