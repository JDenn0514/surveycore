# Review — PR 3 — fay-rho-constructor-edges

**Verdict**: PASS
**Date**: 2026-09-30

Branch `test/fay-rho-constructor-edges`, HEAD `2e24a81`, tree
`b6526285931d93e73ff812d170ccd9c409bdca1a`, base `develop` `b4c0a88`.
The reviewer read the diff `b4c0a88..HEAD` (one file, 236 added lines) and
ran no gate.

## Convergence checks

- Spec coverage: y. The PR's slice of `spec.md` is §Order of checks step 1
  and nine rows of §Edge cases: `rho = 0`, `0L`, `0.999`, `c(a = 0.3)`, a
  supplied `scale`, `rscales`, `mse = FALSE`, one replicate column, and the
  empty and single-row frames. Add the `rscales`-length order check and the
  §Out of scope `update_design()` note ("copies `@variables` and keeps
  `rho`"). Each has one audit row, 1.14 to 1.25. The other edge-case rows
  (`rho = 1`, `NA`, length, type, `dim`, explicit `NULL`) belong to PRs 1
  and 2 by the plan's row assignment.
- Test coverage of spec: y. Every item above has a test-spec §1 row, and
  every row maps to a new block in the diff.
- Tolerance integrity: y. The diff has nine numeric `expect_equal()` calls
  and each sets an explicit tolerance: 1e-8 on the six stored-scale calls
  (rows 1.14, 1.17, 1.18, 1.19, and two in 1.21) and 1e-10 on the three
  stored-`rho` calls (1.14, 1.16, 1.25). The 1e-8 matches test-spec
  §Tolerances "Stored scale against its literal". test-spec names no `rho`
  tolerance. 1e-10 is the tightest value in that section, so it is not
  looser than any default. The PR 1 defect (no `tolerance =`, so testthat
  used about 1.49e-8) does not occur here. The audit's tolerance column
  agrees with the code on every row.
- Scope discipline: y. `implementation.md` §Write surface, the plan's Files
  touched and `git diff --stat` all name only
  `tests/testthat/test-constructors.R`. No `R/` file changed, which agrees
  with task 7 (no PR 1 defect found).
- Regression safety: y. Suite 12179 to 12199 passing (+20). The 20 is the
  expectation count in the diff (3+1+2+1+2+2+1+3+1+1+1+2). Failures 0,
  warnings held at 256, skips held at 4, no `_snaps/` change.

## Other checks

- CRAN cookbook: "None", and the audit verdict is PASS. The diff has no
  `set.seed(`, `options(`, `<<-`, or bare `print(`/`cat(`.
- Profile gates: all seven carry a result. R CMD check shows 2 NOTEs: the
  pre-approved CRAN-incoming note and the `.git` hidden-file note that
  plan criterion G4 allows.
- air (G7): 58 hunks on the base file and 58 on the head file, none in
  lines 1390 to 1625. The reviewer reads this gate as covering only the
  PR's own lines, as the orchestrator said. The added lines are air-clean.
- Coverage: 96.16% before and after. The PR adds no line under `R/`, so no
  new code can be uncovered.
- Comprehension alignment: the gotchas this PR reaches (`rho = 0`, `rho`
  near 1, `0L`, supplied `scale`, `rscales`, `mse`, empty and single-row
  frames) each have a row. The rest belong to other PRs or appear in
  test-spec §Gotchas out of scope.

## Cross-consistency notes

- Eleven of the twelve blocks rebuild fixture FT inline. The plan says the
  builder builds each fixture in the block that needs it, so this follows
  the plan. It is not a DRY finding against this PR.
- Several block titles are longer than 80 characters. `air` does not wrap
  strings, and the file already carries long titles, so no gate reads
  them. This is a note only.
- Row 1.25 wraps `update_design()` in `suppressMessages()`, as
  `test-update-design.R` does. A warning would still surface, and the audit
  reports 0 warnings from the new blocks.

## Decision

PASS. Builder and tester agree on all 12 rows. Every numeric assertion sets
the tolerance that test-spec gives. The write surface is the one file the
plan names, and every gate is clean or reads as the plan allows.
