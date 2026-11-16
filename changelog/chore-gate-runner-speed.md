# Changelog: chore/gate-runner-speed

**Branch:** `chore/gate-speed`
**Status:** Complete
**Date:** 2026-11-16

## Summary

The pipeline gate runner, `.claude/scripts/run-gates.sh`, took about 46
minutes on PR 6 of the analysis-cell-performance arc. About 34 of those
minutes were the test suite, run three times: by `devtools::test()`, inside
`R CMD check`, and under covr. The examples ran twice, and pkgdown built the
whole site, which CI also builds on every PR.

This change removes the repeats. `R CMD check` runs with `--no-tests`, the
separate `run_examples()` gate is gone, and the pkgdown gate runs
`pkgdown::check_pkgdown()` in place of `build_site()`. The covr gate skips
when no `R/` file changed. Otherwise it runs only the test files of the
changed files' family, for example every `test-analysis-*.R` file when an
`R/analysis-*.R` file changed.

The local covr gate no longer reports the package total. The 95% package
floor is enforced only by the CI test-coverage job. The local gate answers
whether this PR's changed lines are tested. `--baseline` mode still runs the
full suite and the full covr run.

## Files Modified

- `.claude/scripts/run-gates.sh` — removes gate 3, adds `--no-tests` to
  `R CMD check`, runs `check_pkgdown()`, and adds the covr skip and scoped
  modes
- `.claude/scripts/covr-report.R` — adds `COVR_MODE`; scoped mode maps each
  changed file to its family's test files and runs only those
- `.claude/skills/pipeline-shared/references/r-package-profile.md` —
  updates the gate table, the canonical runner and the pkgdown skip rule,
  and states that the 95% floor is CI-only

## Changes

- Run `R CMD check` with `--no-tests`; gate 2 already ran the suite
- Remove the `run_examples()` gate; `R CMD check` runs the examples
- Run `pkgdown::check_pkgdown()` in place of `pkgdown::build_site()`
- Skip covr when no `R/` file changed; otherwise run only the mapped test
  files, with a full-suite fallback when a changed file has no test file
- Move the 95% package coverage floor to CI only

## Verification

Scoped covr on the PR 7 tree (`d504bc1`, 11 changed `analysis-*` files),
against the full covr run from that tree's gate run:

| Run | Time | Test files | Uncovered lines | Lines flagged that the full run covers |
|---|---|---|---|---|
| Full | about 12 min | all | 36 | 0 |
| Family-scoped | 389 s | 22 | 39 | 3 |

The 3 extra lines are the `survey_collection` dispatch lines in
`analysis-freqs.R`, `analysis-means.R` and `analysis-totals.R`. Tests outside
the analysis family reach them. `bash -n` passes on `run-gates.sh`, and the
SKIPPED path was run on a tree with no `R/` change. The full gate script was
not run end to end.
