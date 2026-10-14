# Implementation — PR 1 — replicate-export-ignored-args

Worktree: `C:/Users/jdennen/surveycore/.claude/worktrees/agent-ad5d8670c8998508c`
Branch: `worktree-agent-ad5d8670c8998508c` (the name
`fix/replicate-export-ignored-args` is checked out in the main checkout, so
git refuses it in a second worktree). Base: `eec6ce1`, tree `c98c3ef`,
verified before the first edit. Head: `1650f93`. Not pushed.

## Write surface
- `plans/error-messages.md` — modified
- `R/utils.R` — modified
- `R/methods-conversion.R` — modified
- `tests/testthat/test-conversion.R` — modified
- `tests/testthat/test-variance-replicate.R` — modified

The four `plans/*-replicate-supplied-args.md` planning copies were already on
the base commit and were not edited.

## Commits
1. `49be866` docs(plans): register RS-1 to RS-3 and the FR-3 second class
2. `cc98f9b` fix(utils): stop passing scale and rscales that survey overrides
   on export
3. `4c695a8` test(conversion): pin the scale and rscales the export route
   passes
4. `1650f93` test(variance): guard survey's refusal of JKn with no rscales

The register commit is the first commit on the branch and an ancestor of the
first commit that touches `R/`.

## Summary
- `plans/error-messages.md` ends with the section
  `### replicate-supplied-args rows (2026-10-01)`: intro, variable bindings,
  rows RS-1, RS-2, RS-3, and the FR-3 note under
  `**Updated trigger descriptions for existing rows:**`. The RS-3 template
  was checked against the shipped `as_survey_nonprob()` source.
- `R/utils.R` gains `.replicate_ignores_scale()` and
  `.replicate_ignores_rscales()`, word for word as `spec.md` §II.
- `.as_svydesign_replicate()` computes `scale_arg` and `rscales_arg` through
  the two predicates, each inside `isTRUE()`, and passes them as `scale =`
  and `rscales =`. The comment above them states the three facts of
  `spec.md` §IV. No other argument or step changed.
- Five new test blocks (four in `test-conversion.R`, one in
  `test-variance-replicate.R`) and two rewritten comments in
  `test-conversion.R`. Every new `expect_equal()` carries an explicit
  `tolerance =`. No `suppressWarnings()` or `expect_failure()` on an added
  code line.

## Task checklist
- [x] 1. Register section in `plans/error-messages.md`, committed first
- [x] 2. "as_svydesign() passes no scale or rscales for an imported ACS or
  successive-difference design" (failed against `develop`'s R code with
  survey's `not needed` warning for both types, passes after task 7;
  `expect_identical(d@variables$rscales, rep(1, 5))` held, so the
  `expect_equal()` fallback was not needed)
- [x] 3. "as_svydesign() raises only survey's JK2 warning for a JK2 design
  built with no scale"
- [x] 4. "as_svydesign() passes no scale for an imported BRR design"
- [x] 5. "survey::svrepdesign() refuses JKn combined weights with no
  rscales", on F1
- [x] 6. The two predicates in `R/utils.R`
- [x] 7. The export route change in `R/methods-conversion.R`
- [x] 8. "as_svydesign() converts a replicate design that stores no type"
- [x] 9. "as_svydesign() reproduces a replicate nonprob's mean and SE
  [numerical]" passes unchanged
- [x] 10. Two comments rewritten; both contain "only JK2"; no call or
  assertion changed
- [x] 11. New tests pass; local parts of G checked (see below)

## Signals raised
- None.

## Notes for tester
- Probe on the installed versions: `survey` 4.5, R 4.6.1 (ucrt). Every
  condition text the new blocks use matched the plan's transcription:
  `type='BRR' does not use 'scale=' argument`;
  `with type JK2 scale= and rscales= are not needed and will be ignored`;
  `with type ACS scale= and rscales= are not needed and will be ignored`;
  `with type successive-difference scale= and rscales= are not needed and will be ignored`;
  `scale or rscales not specified, set to 1`;
  `Must provide rscales for combined JKn weights`. A `NULL` type falls back
  to BRR, raises the BRR text once, and stores `scale` 0.2.
- AC-2 evidence: `R/` at the base commit `eec6ce1` is identical to
  `origin/develop` (`git diff --stat origin/develop eec6ce1 -- R` is empty).
  The new tests were run against that code before task 7 and the ACS /
  successive-difference block reported two failures, one per type, each
  naming survey's `not needed` warning.
- `devtools::document()` left no diff. `air format --check` passes on the
  four changed `.R` files.
- `Rscript -e` with a `|` inside the argument fails on this Windows host
  ("The system cannot find the path specified"); run a filter such as
  `"conversion|variance-replicate"` from a script file.
- A test run marks about 30 `tests/testthat/_snaps/` files modified with
  line-ending changes only (`git diff --ignore-cr-at-eol` is empty). They
  were restored with `git checkout`.

## CRAN compliance
- [x] TRUE/FALSE used throughout
- [x] :: used for external calls
- [x] No bare print()/cat()
- [x] devtools::document() run
