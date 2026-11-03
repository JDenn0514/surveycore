# Implementation — PR 5 — replicate-supplied-scale-oracle

Branch `test/replicate-supplied-scale-oracle-pr5` in worktree
`C:/Users/jdennen/surveycore/.claude/worktrees/agent-a36ccb3e9bdfe9be7`.
Base: commit `0e4da069b205f9d93cc3fdd8b1099793b63dc43e`, tree
`f30cdf6dd070bedc92a3756654d602e50d8b39a5`. Both hashes were verified after
`git reset --hard`.

Commits:

- `f769425` test(variance): oracle blocks for a supplied scale on all nine replicate types
- `4d4bf23` test(conversion): export parity on all nine types built with a supplied scale

## Write surface

- `tests/testthat/test-variance-replicate.R` — modified (588 lines added, none removed)
- `tests/testthat/test-conversion.R` — modified (lines added only)

`git rev-parse HEAD:R` equals the base `R` subtree hash:
`5d2ff1168fad0f0d05bfbf28fd1285777dfeb309` on both. Nothing under `R/`,
`man/` or `NAMESPACE` changed.

## Summary

- `test-variance-replicate.R` gains a new section, "Block 26: Oracle blocks
  for a supplied scale — issue #255", at the end of the file. It holds nine
  oracle blocks on F1 (`R = 20`), one per type. Each block builds both sides
  with `mse = TRUE` and `scale = 0.6`, and asserts the mean (1e-10), the SE
  (1e-8), both confidence bounds (1e-6), and each side's stored scale against
  the literal (1e-8).
- The four "kept" blocks (JK1, JKn, bootstrap, other) also build a
  surveycore design with no `scale` and assert the SE ratio against
  `sqrt(0.6 / default)`: `19 / 20`, `1`, `1 / 19` and `1` (1e-8).
- The five "discarded" blocks (BRR, Fay, JK2, ACS, successive-difference)
  assert surveycore's `surveycore_warning_replicate_arg_ignored` (Fay: no
  warning) and exactly one `survey` warning by text (Fay: no warning).
- `test-conversion.R` gains one block, "as_svydesign() reproduces
  get_means() for all nine types built with a supplied scale", after the
  block "as_svydesign() converts a replicate design that stores no type". It
  loops over the nine types on F2 (`R = 5`) and checks the constructor
  condition, the export condition, the mean, the SE and `sv$scale`.
- Each oracle block carries a comment on why oracle rule 2 allows `0.6` on
  both sides. JKn is the only block that passes `rscales` to `survey`.

## Task checklist

- [x] 1. Probe the installed `survey` (results below)
- [x] 2. Nine oracle blocks in `tests/testthat/test-variance-replicate.R`
- [x] 3. Export-parity block in `tests/testthat/test-conversion.R`
- [x] 4. Verify: the ten new blocks pass. The leader runs gate G.

## Probe results (task 1)

`survey` 4.5 under R 4.6.1 (2026-06-24 ucrt). Every text and value matched
the plan. No HOLD.

`survey::svrepdesign(..., mse = TRUE, scale = 0.6)` on F1 (`R = 20`); JKn
also got `rscales = rep(1, 20)`, Fay also got `rho = 0.3`:

| Type | `sv$scale` | `survey` warnings |
|---|---|---|
| JK1 | 0.6 | none |
| JKn | 0.6 | none |
| bootstrap | 0.6 | none |
| other | 0.6 | 1: `scale or rscales not specified, set to 1` |
| BRR | 0.05 | 1: `type='BRR' does not use 'scale=' argument` |
| Fay | 0.102040816326531 | none |
| JK2 | 1 | 1: `with type JK2 scale= and rscales= are not needed and will be ignored` |
| ACS | 0.2 | 1: `with type ACS scale= and rscales= are not needed and will be ignored` |
| successive-difference | 0.2 | 1: `with type successive-difference scale= and rscales= are not needed and will be ignored` |

The same calls on F2 (`R = 5`, JKn `rscales = rep(1, 5)`): JK1, JKn,
bootstrap and other 0.6; BRR 0.2; Fay 0.408163265306123; JK2 1; ACS and
successive-difference 0.8. The warnings were the same as on F1.

Other probes, on both frames:

- `type = "JKn"` with no `rscales`: error
  `Must provide rscales for combined JKn weights`.
- `type = "other"` with no `scale`: one warning,
  `scale or rscales not specified, set to 1`.
- `type = "JK2"` with no `scale`: one warning, the JK2 text.
- No call raised "Data do not look like combined weights".

The surveycore side with `scale = 0.6` stored the same values as `survey` on
all nine types, on both frames. It warned once with the arg-ignored warning
for BRR, JK2, ACS and successive-difference, and raised nothing for the other
five. `as_svydesign()` on those designs gave the same `sv$scale`. It raised
one `survey` warning for JK2 (the JK2 text) and for other (the "set to 1"
text), and none for the other seven.

## Signals raised

- None.

## Notes for tester

- Defect simulation, run outside the test files with no change to `R/`. On
  each F1 design, the stored scale was overwritten with the defect value:
  `0.6` for the five discarding types (the issue #255 defect), and the type
  default for the four keeping types (a constructor that drops the supplied
  scale). In all nine cases the mean still agreed with `survey`, and the SE
  and `ci_low` disagreed. So each oracle block turns red on the SE and the
  bounds, not on the estimate.
- Parse-data counts (`SYMBOL_FUNCTION_CALL`), base to head:
  - `test-variance-replicate.R`: `test_that` 42 → 51, `svrepdesign`
    18 → 27, `test_invariants` 1 → 1, `suppressWarnings` 0 → 0,
    `expect_failure` 0 → 0.
  - `test-conversion.R`: `test_that` 185 → 186, `svrepdesign` 30 → 30,
    `test_invariants` 6 → 6, `suppressWarnings` 41 → 41,
    `expect_failure` 0 → 0.
- The plan's added-line check (`grep -cE 'suppressWarnings\(|expect_failure\('`
  on added code lines) reads 0.
- `air format --check` passes on both files. `air format` changed nothing
  in either file.
- In the conversion block, the JK2 export text is built with `paste()` over
  two literals to keep the line within 80 columns. The joined string equals
  the plan's text.
- The conversion block passes `info = ty` to its `expect_equal()` and
  `expect_match()` calls, so a failure names the type.
