# Audit: PR 8, fix/twophase-replicate-phase1

Verdict: **PASS**

Tree: 4109fb32ea236a0061db32a3a0733815ea39d760
HEAD: c880ebd. Base: develop ae37e4e (tree 872352e).

## Profile gates

The orchestrator ran the gates on this tree. The tester did not re-run them (low memory). Logs: `RUN/prs/pr-8-twophase-replicate-phase1/gates/`.

| Gate | Result | Notes |
|---|---|---|
| devtools::document() | PASS | document() wrote nothing |
| devtools::test() | PASS | FAIL 0, WARN 256, SKIP 4, PASS 12353 |
| run_examples() | PASS | all examples ran |
| R CMD build | PASS | surveycore_1.1.0.9000.tar.gz |
| R CMD check --as-cran --no-manual | PASS | Status: 2 NOTEs |
| pkgdown | PASS | site built |
| covr | PASS | 96.17% |

Tree: 4109fb32ea236a0061db32a3a0733815ea39d760

NOTE review (gate-5-check.log):

- `checking CRAN incoming feasibility`: pre-approved.
- `checking for hidden files and directories` (`.git`): this note is also on the baseline. `.Rbuildignore` causes it, and the CLAUDE.md archive entry for `as-svydesign-bridge` records it as pre-existing. The count is the same as the baseline (2 to 2).

Warnings: 256 against 256 on the baseline, so the PR adds no warning. The tester's filtered run (`constructors|variance-twophase`) gave FAIL 0, WARN 21, PASS 996. Every warning came from a pre-existing nonprob or AAPOR small-cell block. None came from a new block.

Coverage: `R/core-constructors.R` is at 96.88%. The uncovered lines are 414, 2001 and 2092. The PR's hunks in that file cover lines 1016 to 1166, so none of the three lines is in this PR's diff. The TP-1 abort is covered by rows 7.1 to 7.3 and 1.26.

## Per-test result table

No new block has a numeric `expect_equal()`, so no tolerance applies to this PR's rows. The deleted block "carries the phase-1 scale of both changed types" held two `expect_equal(..., tolerance = 1e-8)` scale assertions. The test-spec deletes that block by name.

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| 7.1 JK1 phase 1 on FP refused, class | `surveycore_error_twophase_replicate_phase1` | same | class | ✓ |
| 7.1 snapshot | TP-1 x/i/v text; the `v` line names `as_survey()` | TP-1 template | exact | ✓ |
| 7.2 eight types without `rho` on FP (JK1, JK2, JKn, BRR, bootstrap, ACS, successive-difference, other) | refused, all 8 | refused | class | ✓ |
| 7.2 Fay `rho = 0.3` on FP | refused | refused | class | ✓ |
| 7.3 JK1, no `subset` | `twophase_replicate_phase1`, not `subset_missing` | same | class | ✓ |
| 7.4 taylor phase-1 block | builds `survey_twophase`; holds the one twophase `test_invariants()` call | same | n/a | ✓ |
| 7.5 nonprob phase 1 | `expect_no_error(class = TP-1)` passes | no TP-1 | class | ✓ |
| 7.6 data.frame phase 1 [row 19] | `surveycore_error_phase1_class`; the `i` line reads "Create it first with `as_survey()`." | same | class + snapshot | ✓ |
| 1.26 Fay `rho = 0.3` on FA, `half` subset | refused | refused | class | ✓ |
| 6.10 `?as_survey_twophase` | `@param phase1` says a replicate phase 1 is refused; See also links only `as_survey()` | same | n/a | ✓ |
| 6.11 NEWS.md breaking change | names `surveycore_error_twophase_replicate_phase1` and "This reverses PR #74" | same | n/a | ✓ |

FA fixture check (1.26): the block uses `make_survey_data(n = 200, n_psu = 20, n_strata = 4, design = "replicate", type = "fay", seed = 15)`. This matches test-spec §Datasets FA. FP (7.1 to 7.3): `n = 100, n_psu = 10L, seed = 20L` with `in_phase2` set to 50 TRUE and 50 FALSE. This matches §7.

## Specific checks

| Check | Result | Pass |
|---|---|---|
| TP-1 placement | directly after the Error 19 `phase1_class` block; Error 20 (`subset_missing`) and every later subset check come after it; uses `S7::S7_inherits(phase1, survey_replicate)` | ✓ |
| `test_invariants()` count, by `utils::getParseData()` | test-constructors.R: 4 calls in total, exactly 1 in a block that calls `as_survey_twophase()` (the taylor phase-1 block). test-variance-twophase.R: 0 calls, and the PR adds none | ✓ |
| Snapshot diff `git diff ae37e4e -- tests/testthat/_snaps/` | only `_snaps/constructors.md`: the changed row-19 `i` line plus the new TP-1 entry | ✓ |
| plans/error-messages.md | TP-1 row added; row 19 restated as x + i "Create it first with {.fn as_survey}." | ✓ |
| NEWS.md | the breaking-change item names the class and PR #74 | ✓ |
| No two-phase design on a replicate phase 1 | both deleted blocks are gone; the section header reads "Section 5: SRS phase-1 designs"; the vignette two-phase chunk builds phase 1 with `as_survey()`. Runtime proof: the full suite passes with FAIL 0, and any such construction outside an `expect_error()` now aborts | ✓ |
| Files touched against the plan list | 7 files, identical to the plan's Files touched list | ✓ |

## Acceptance criteria (PR 8)

| # | Criterion | Pass |
|---|---|---|
| 1 | JK1 refused, snapshot shows TP-1 and names `as_survey()` | ✓ |
| 2 | nine types on FP and Fay on FA refused | ✓ |
| 3 | no-subset case gives the replicate refusal | ✓ |
| 4 | taylor block builds and holds the one invariants call; nonprob not refused | ✓ |
| 5 | row 19 class and new `i` line; error-messages.md rows | ✓ |
| 6 | no replicate-phase-1 two-phase construction remains; header renamed | ✓ |
| 7 | the man page and the NEWS item | ✓ |
| 8 | G (all gates clean) | ✓ |

## CRAN cookbook violations

None. The scan covered the lines that the PR adds to `R/core-constructors.R`, the only changed `R/` file.

## Before/After comparison

| Metric | Before PR (ae37e4e) | After PR (4109fb3) | Δ |
|---|---|---|---|
| tests passing | 12350 | 12353 | +3 |
| tests failing | 0 | 0 | 0 |
| warnings | 256 | 256 | 0 |
| skips | 4 | 4 | 0 |
| coverage | 96.16% | 96.17% | +0.01% |
| R CMD check notes | 2 | 2 | 0 |

Coverage is below the 98% target but above the 95% floor, and it did not drop.

## Signals

No HOLD. No BLOCK.
