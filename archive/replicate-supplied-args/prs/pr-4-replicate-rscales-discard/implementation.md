# Implementation — PR 4 — replicate-rscales-discard

Branch base: commit `15bb7ef0a73867f124f27c1754356f38efc8361f`, tree
`338bf5f24b94b10f276c954c09e552be1c8f320a`. Both hashes were verified
before work started.

## Write surface
- `R/core-constructors.R` — modified
- `tests/testthat/test-constructors.R` — modified
- `tests/testthat/_snaps/constructors.md` — modified (2 new entries only)
- `tests/testthat/test-conversion.R` — modified (1 line)

## Summary
- `as_survey_replicate()` now calls `.replicate_ignores_rscales()` in the
  discard step (spec §III step 9). When it returns `TRUE` and `rscales` is
  not `NULL`, `"rscales"` is appended to `ignored` after `"scale"`.
- After the one `surveycore_warning_replicate_arg_ignored` warning,
  `rscales` is set to `NULL` when `"rscales"` is in `ignored`. The warning
  template does not change. The comment above the step now covers
  `rscales`.
- The `as_survey_nonprob()` function body is byte-identical to
  `origin/develop` (checked with `parse()` and a line-by-line comparison).
- 11 new `test_that()` blocks in `test-constructors.R`, placed after
  "as_survey_replicate() builds JKn with rscales and stores scale 1". Two
  are snapshot blocks, and they add the two snapshot entries that tasks 2
  and 3 name. No existing snapshot entry changed.
- `test-conversion.R`: the `rs <-` line in "every accepted replicate type
  crosses both conversion routes" now passes `rscales` to `"JKn"` only.
  This is the only removed line in that file.

## Task checklist
- [x] 1. "as_survey_replicate() discards a supplied rscales for JK2, ACS and
  successive-difference"
- [x] 2. "as_survey_replicate() discard warning names scale and rscales
  together" (snapshot)
- [x] 3. "as_survey_replicate() discard warning names rscales alone"
  (snapshot)
- [x] 4. "as_survey_replicate() raises one discard warning for scale and
  rscales together"
- [x] 5. "as_survey_replicate() discards scale and rscales by the closed type
  sets"
- [x] 6. Six blocks that pin behaviour already in place: keeps rscales for
  six types; JK2 with no rscales raises nothing; length check before the
  discard; value check before the discard; explicit `rscales = NULL` JKn
  refusal; one-row JKn frame refused with `surveycore_error_single_row`
- [x] 7. The `"rscales"` half of the discard step in `as_survey_replicate()`
- [x] 8. Retarget of the `rs <-` line in `test-conversion.R`
- [x] 9. "as_survey_replicate() refuses five frames before the scale switch"
  passes unchanged
- [x] 10. Two snapshot entries read against the task 2 and task 3 texts,
  word for word

## Signals raised
- None.

## Notes for tester
- Commits: `29c3a70` (constructor change, tests, snapshots) and `c00b2b7`
  (conversion retarget).
- `air format --check` passes on `R/core-constructors.R` and
  `tests/testthat/test-conversion.R`. `tests/testthat/test-constructors.R`
  fails it on develop. On a formatted copy, air proposes changes from line
  4163 onwards only. The added lines are 1988 to 2297, and air proposes no
  change inside them.
- No roxygen changed, so `devtools::document()` was not needed.
- A test run rewrites line endings in about 30 `tests/testthat/_snaps/`
  files. These were reverted with `git checkout --` before the commit.
- The plan check for added `suppressWarnings(` or `expect_failure(` code
  lines in `tests` returns 0.
