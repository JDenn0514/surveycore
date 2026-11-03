# Changelog: test/nonprob-ratios-se-vacuous

**Branch:** `test/nonprob-ratios-se-vacuous`
**Status:** Complete
**Date:** 2026-10-23

## Summary

Refs #292. The block "get_ratios() SE matches equivalent survey_replicate
for survey_nonprob" in `test-nonprob-bootstrap-variance.R` called
`get_ratios()` without `variance = "se"`. `get_ratios()` defaults to
`variance = "ci"` and then returns no `se` column. Both sides of
`expect_equal(result_np$se, result_rep$se)` were `NULL`, so the block
passed without checking anything. testthat logged "Unknown or uninitialised
column: `se`" twice.

The block now asks for the SE and asserts the same scale gap as the sibling
`get_means()` block, which #253 retargeted. Under decision D1 of
`plans/issue-cleanup.md`, `as_survey_nonprob()` keeps the bootstrap scale
`1/R`, and `as_survey_replicate()` uses `1/(R-1)`. The nonprob SE is
therefore smaller by exactly `sqrt((R-1)/R)`.

**No behaviour changes.** Test files only.

## Files Modified

- `tests/testthat/test-nonprob-bootstrap-variance.R` — the `get_ratios()`
  block in Section 4 is retitled and now asserts something

## Changes

- Pass `variance = "se"` to both `get_ratios()` calls
- Assert `result_np$se / result_rep$se` equals `sqrt((R - 1) / R)` at
  `R = 20`, with `tolerance = 1e-8`, the SE/variance row
- Assert the two `ratio` point estimates are `expect_identical()`, because
  the scale enters only the variance
- Retitle the block to "get_ratios() nonprob SE is sqrt((R-1)/R) of the
  replicate SE", matching the sibling block

## Verification

- Measured ratio at `R = 20`: 0.97467943448089644 against
  `sqrt(19 / 20)` = 0.97467943448089633, a gap of 1.1e-16
- The two `ratio` values are bitwise identical
- With the expected value replaced by `1`, the block fails at line 209
  (`actual` 0.975, `expected` 1.000). The file was then restored.
- The two "Unknown or uninitialised column: `se`" warnings are gone
