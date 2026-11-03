# Changelog: fix/marginaleffects-rowid

**Branch:** `fix/marginaleffects-rowid`
**Status:** Complete
**Date:** 2026-08-25

## Summary

Fixes #153: `get_diffs()` and the marginaleffects extension interface
(`avg_slopes()`, `avg_predictions()`) raised `missing value where TRUE/FALSE
needed` errors and returned rows with a missing group value under the
in-development `marginaleffects` 1.0.0.

`get_predict.survey_glm_fit()` always fabricated a fresh
`rowid = seq_len(nrow(newdata))`, discarding a `rowid` column already present
on `newdata`. marginaleffects 1.0.0 relies on `rowid` to reattach grouping
columns onto contrast rows; the real `rowid` resets partway through a
stacked hi/lo contrast block, so the fabricated sequential one stopped
matching and the merge silently dropped or misattributed the group.

Reproduced locally by installing `marginaleffects` from GitHub (1.0.0 is not
yet on CRAN); confirmed the fix against both the CRAN release (0.32.0) and
the GitHub dev version.

## Files Modified

- `R/glm-marginaleffects.R` — `get_predict.survey_glm_fit()` now returns
  `newdata$rowid` unchanged when present, falling back to `seq_len()` only
  when `newdata` has no `rowid` column
- `tests/testthat/test-glm-marginaleffects.R` — regression test asserting
  `get_predict()` preserves a supplied `newdata$rowid`
- `NEWS.md` — bug fix entry

## Changes

- Preserve `newdata$rowid` in `get_predict.survey_glm_fit()` instead of
  always fabricating a sequential one, fixing grouped `avg_slopes()` /
  `avg_predictions()` results under `marginaleffects` 1.0.0
