# Changelog: test/analysis-cell-golden

**Branch:** `test/analysis-cell-golden`
**Status:** Complete
**Date:** 2026-11-12

## Summary

This is the first PR of the analysis-cell-performance arc
(`plans/spec-analysis-cell-performance.md`). The arc will change how six
analysis functions build their per-cell variance: `get_freqs()`,
`get_means()`, `get_totals()`, `get_variance()`, `get_covariance()` and
`get_ratios()`. The arc's rule is that no result may move. This PR builds
the test that holds the later PRs to that rule. It changes no file under
`R/`.

A fixture records the results of 261 scenarios on the base commit
`0c0a987`: the estimates, the standard errors, and the warning classes each
call raised. A new test file compares every scenario against the fixture at
`tolerance = 1e-12`. The scenarios cover all six functions on Taylor,
replicate, two-phase, calibrated and non-probability designs, with groups,
domains, `NA` values and the lonely-PSU options. The test file also covers
`get_quantiles()` and `get_effective_n()`, and the rows that compare a
grouped call against the same call on a domain.

The generator in `data-raw/` refuses to write the fixture unless the source
tree it loads is the base commit with no change under `R/`.

This PR holds plan PRs 1 and 2 together. The arc is a trial of a shorter
pipeline (`plans/decisions-analysis-cell-performance.md`, D17).

**No behaviour changes.** Test files, a `data-raw/` script and planning
documents only.

## Files Modified

- `tests/testthat/helper-cell-golden.R` (new): the design and frame
  builders, the 261-scenario catalogue, the noisy-scenario warning table,
  and the comparison helpers
- `tests/testthat/test-analysis-cell-equivalence.R` (new): 21 blocks,
  3,664 expectations; adds no warning to the suite
- `tests/testthat/fixtures/analysis-cell-golden.rds` (new): the base-commit
  results, 182 KB, xz-compressed
- `data-raw/analysis-cell-golden.R` (new): the fixture generator and its
  base-commit guard
- `plans/{spec,test-spec,decisions,comprehension,implementation-plan}-analysis-cell-performance.md`
  (new): the arc's planning documents

## Changes

- test: golden fixture and equivalence tests for the six analysis functions
