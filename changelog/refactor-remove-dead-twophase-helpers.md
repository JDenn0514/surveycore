# Changelog: refactor/remove-dead-twophase-helpers

**Branch:** `refactor/remove-dead-twophase-helpers`
**Status:** Complete
**Date:** 2026-06-24

## Summary

Removes four dead internal functions from `R/variance-twophase.R` that had no
callers in the production path: `.twophase_build_inputs()`, `.twophase_mean()`,
`.twophase_total()`, and `.twophase_df()`. These were superseded by the
`_cell()` variants in `analysis-means-helpers.R` and `analysis-totals-helpers.R`
and by `.degf()` / `.degf_taylor()` in `analysis-helpers.R`, but were never
deleted. Also removes the tests that exercised these dead functions directly,
and rewrites the `method = "full"` error-path test to go through the production
`get_means()` path instead.

## Files Modified

- `R/variance-twophase.R` — removed Section 4 (`.twophase_build_inputs()`,
  `.twophase_mean()`, `.twophase_total()`) and Section 5 (`.twophase_df()`);
  renumbered Section 6 to Section 5
- `tests/testthat/test-variance-twophase.R` — removed tests for the deleted
  functions; rewrote `method = "full"` error test to use `get_means()`
- `tests/testthat/_snaps/variance-twophase.md` — updated snapshot to reflect
  `get_means()` call site in the error test

## Changes

- Deleted `.twophase_build_inputs()` (~73 lines), `.twophase_mean()` (~11
  lines), `.twophase_total()` (~11 lines), `.twophase_df()` (~23 lines) from
  `R/variance-twophase.R`
- Removed Section 1 engine unit tests and Section 5 edge case tests from
  `test-variance-twophase.R` that called these functions directly (~165 lines
  of test code removed)
- Rewritten error-path snapshot test now calls `get_means(d, y1)` instead of
  `.twophase_mean(d, "y1")`
