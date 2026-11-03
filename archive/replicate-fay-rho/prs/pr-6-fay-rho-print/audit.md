# Audit — PR 6 fay-rho-print

**Verdict**: PASS
**Branch**: feature/fay-rho-print, HEAD f6b19a1
**Branch point**: develop 5273462 (tree 8183fde)
Tree: 43958277b43d0f9e2e3ee6839bae51339351e6a2

## Profile gates

The orchestrator ran the gates on this tree. The tester did not re-run them,
because memory is low. Logs: `prs/pr-6-fay-rho-print/gates/`.

| Gate | Result | Notes |
|---|---|---|
| devtools::document() | PASS | document() wrote nothing |
| devtools::test() | PASS | FAIL 0, WARN 256, SKIP 4, PASS 12284 |
| run_examples() | PASS | all examples ran |
| R CMD build | PASS | surveycore_1.1.0.9000.tar.gz |
| R CMD check --as-cran --no-manual | PASS | 0 errors, 0 warnings, 2 NOTEs |
| pkgdown | PASS | site built |
| covr (NOT_CRAN=true) | PASS | 96.16%, above the 95% floor |

Tree: 43958277b43d0f9e2e3ee6839bae51339351e6a2

NOTE review (gate-5-check.log):

- `checking CRAN incoming feasibility`: pre-approved.
- `checking for hidden files and directories` (`.git`): pre-existing. Criterion
  G item 4 accepts it.

Coverage of `R/methods-print.R` is 98.87%. The uncovered lines are 556, 559,
582, 659, 909 and 915. The PR's added lines in that file are 337-348,
379-390, 423-425, 831-841 and 855-857. No uncovered line is in the diff.

Tester checks, run in the foreground:

| Check | Result |
|---|---|
| `devtools::test(filter = "methods-print")`, NOT_CRAN=true | FAIL 0, WARN 0, SKIP 0, PASS 468 |
| `air format --check` on the two changed `.R` files | exit 0 |
| `git diff --name-only 5273462...HEAD` | 3 files, equal to Files touched |

## Per-test result table

Fixture FA as Fay, `rho = 0.5`, scale 0.4. Snapshot text is read from
`tests/testthat/_snaps/methods-print.md`. The snapshot renders the cli bullet
as `*` (the ASCII form). The block for row 5.2 strips the bullet glyph, so it
asserts the line order in either locale.

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| 5.1 class line | `<survey_replicate> (FAY, 10 replicates, rho = 0.5)` | same | exact | ✓ |
| 5.1 stored scale | 0.4 | 0.4 | 1e-8 | ✓ |
| 5.2 line after `Scale: 0.4` | `Rho: 0.5`, then `MSE: TRUE` | `Rho: 0.5` | exact | ✓ |
| 5.3 type line | `Type: replicate weights (FAY, 10 replicates, rho = 0.5)` | same | exact | ✓ |
| 5.3 line after `Scale: 0.4` | `Rho: 0.5` | `Rho: 0.5` | exact | ✓ |
| 5.4 no rho key: print full | class line `(FAY, 10 replicates)`, no `Rho:` | no `Rho:`, no `rho =` | exact | ✓ |
| 5.4 no rho key: summary | type line `(FAY, 10 replicates)`, no `Rho:` | no `Rho:`, no `rho =` | exact | ✓ |
| 5.4 key absent | `"rho" %in% names(d@variables)` is FALSE | FALSE | exact | ✓ |
| 5.5 snapshot diff | 173 added, 0 removed, 0 changed | added entries only | exact | ✓ |
| extra: unusable stored rho (6 values) | no `rho` text | no `rho` text | exact | ✓ |
| extra: BRR with a stored rho key | no `rho` text | no `rho` text | exact | ✓ |

`test_invariants()`: the file calls it once for `as_survey_replicate()`, at
line 1935, in the first block that builds with that constructor. No earlier
block in the file calls it on a replicate design.

## Acceptance criteria (PR 6)

| # | Criterion | Evidence | Pass |
|---|---|---|---|
| 1 | Default print class line with `rho = 0.5` | row 5.1 | ✓ |
| 2 | Full print, `Rho: 0.5` after `Scale: 0.4` | row 5.2 | ✓ |
| 3 | summary type line and `Rho:` after `Scale:` | row 5.3 | ✓ |
| 4 | No rho key prints and summarises no rho | row 5.4 | ✓ |
| 5 | Snapshot diff is additions only | numstat 173/0 | ✓ |
| 6 | Criterion G, items 1-9 | gate table, air exit 0, 3 files touched | ✓ |

The builder accepted the snapshots after reading them, because
`snapshot_review()` is interactive. The four new entries match the plan text.

## CRAN cookbook violations

None. The scan covered the added lines of `R/methods-print.R`, the one
changed `R/` file.

## Before/After comparison

| Metric | Before PR (5273462) | After PR (4395827) | Δ |
|---|---|---|---|
| tests passing | 12242 | 12284 | +42 |
| test failures | 0 | 0 | 0 |
| test warnings | 256 | 256 | 0 |
| test skips | 4 | 4 | 0 |
| coverage | 96.16% | 96.16% | 0 |
| R CMD check notes | 2 | 2 | 0 |

## Verdict

PASS. Every row passes. All gates are clean. The cookbook scan has no hit.
No metric regressed.
