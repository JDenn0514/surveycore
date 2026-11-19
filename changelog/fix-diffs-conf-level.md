# Changelog: fix/377-diffs-conf-level

**Branch:** `fix/377-diffs-conf-level`
**Status:** Complete
**Date:** 2026-11-19

## Summary

`get_diffs()` ignored `conf_level` when it estimated through
marginaleffects. That path runs when the call has `group`, has
`covariates`, or fits a non-gaussian family with `scale = "ame"`.
`.extract_me_estimates()` had no `conf_level` argument, and its calls to
`marginaleffects::avg_slopes()` and `marginaleffects::avg_predictions()`
passed none, so every interval was 95%. The result metadata recorded the
requested level, so the label was wrong. Issue #377.

The helper now takes `conf_level` as a required argument and passes it to
all four marginaleffects calls. `get_diffs()` passes it at the call site.

## Files Modified

- `R/analysis-diffs-helpers.R`: `conf_level` argument on
  `.extract_me_estimates()`, passed to the four marginaleffects calls
- `R/analysis-diffs.R`: passes `conf_level` to `.extract_me_estimates()`
- `tests/testthat/test-analysis-diffs.R`: two blocks, one with `group` and
  one with `covariates`. Each asserts that the 90% half-width over the SE
  is `qt(0.95, df)` and that the 90% to 95% width ratio is
  `qt(0.95, df) / qt(0.975, df)`, at `tolerance = 1e-8`
- `tests/testthat/test-analysis-diffs-helpers.R`: the 14 direct calls to
  `.extract_me_estimates()` pass `0.95` as `conf_level`
- `NEWS.md`: Bug fixes entry

## Changes

- fix(analysis): `get_diffs()` honours `conf_level` on the marginaleffects
  path
