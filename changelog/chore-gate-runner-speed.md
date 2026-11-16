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

This change runs the test suite once. Gate 2 is now one covr run that also
reports the test results. It replaces the `devtools::test()` gate and the
covr gate (gate 7). With covr 4.0.0 a full covr run took 574 s and
`devtools::test()` took 557 s on the same tree, so the second run gave no
new answer for its cost. `R CMD check` runs with `--no-tests`, the separate
`run_examples()` gate is gone, and the pkgdown gate runs
`pkgdown::check_pkgdown()` in place of `build_site()`.

Gate 2 reports the package total and enforces the 95% floor locally again.
It runs on every PR, also when no `R/` file changed.

covr 4.0.0 counts lines differently from 3.6.5. On the PR 7 tree it reports
96.33% where 3.6.5 reported 96.66%. A Before figure from one version and an
After figure from the other are not comparable.

## Files Modified

- `.claude/scripts/run-gates.sh` — removes gates 3 and 7, makes gate 2 the
  covr run, adds `--no-tests` to `R CMD check`, and runs `check_pkgdown()`
- `.claude/scripts/covr-report.R` — runs the whole test suite under covr
  with `testthat::test_dir()` and prints the test counts, the package total
  and the per-file detail
- `.claude/skills/pipeline-shared/references/r-package-profile.md` —
  updates the gate table, the gate 2 text, the canonical runner and the
  pkgdown skip rule, and notes the covr 4.0.0 change

## Changes

- Run the test suite once, under covr, as gate 2; log it to
  `gate-2-test-covr.log`
- Print the test counts as `[ FAIL n | WARN n | SKIP n | PASS n ]`
- Fail gate 2 when a test fails, when covr did not run, or when coverage is
  below 95%
- Remove the separate `devtools::test()` gate and the covr gate 7
- `--baseline` runs gate 2 only
- Run `R CMD check` with `--no-tests`; gate 2 already ran the suite
- Remove the `run_examples()` gate; `R CMD check` runs the examples
- Run `pkgdown::check_pkgdown()` in place of `pkgdown::build_site()`

## Verification

The new `covr-report.R` ran on the PR 7 tree (`d504bc1`) with
`NOT_CRAN=true` and the 11 changed `analysis-*` files, under covr 4.0.0.
It took 584 s. The results match the two separate runs on that tree:

| Measure | Separate runs | New gate 2 |
|---|---|---|
| Test counts | `[ FAIL 0 \| WARN 254 \| SKIP 4 \| PASS 16735 ]` (`devtools::test()`) | `[ FAIL 0 \| WARN 254 \| SKIP 4 \| PASS 16735 ]` |
| Package coverage | 96.33% (full covr run) | 96.33% |
| Uncovered lines in the changed files | 47 (full covr run) | 47 |

The run left the tree clean. `bash -n` passes on `run-gates.sh`, and the
gate's parse of the log was checked against this run's log. The full gate
script was not run end to end.
