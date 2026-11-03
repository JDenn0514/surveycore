# Changelog: fix/twophase-quantiles

**Branch:** `fix/twophase-quantiles`
**Status:** Complete
**Date:** 2026-10-21
**Issue:** #328

## Summary

Refs #328. `get_quantiles()` on a `survey_twophase` design computed its
weighted ECDF and its Woodruff interval over every row in `@data`, the
phase-1-only rows included. A two-phase design keeps those rows, and
`.compute_phase2_probs()` gives them a placeholder phase-2 probability of 1,
so they entered the quantile with their full phase-1 weight. A code comment
claimed they got an infinite weight and could never contribute, and that was
wrong. The CDF proportion's standard error was already right, because
`.twophase_mean_cell()` restricts to phase 2 itself. That is why
`get_means()` agreed with `survey::svymean()` while the quantiles did not.
The reported `n` was the phase-1 sample size.

`get_quantiles()` now restricts its domain mask to the phase-2 subset on a
two-phase design. The estimate, the Woodruff back-transformation, the
group combinations, the small-cell count, `n`, and the `na.rm = FALSE`
missing-value check all use phase-2 rows only, as `survey::svyquantile()`
does. `R/variance-twophase.R` is unchanged.

### Published numbers move

Every two-phase quantile estimate, SE and CI moves, and `n` falls to the
phase-2 count. On the issue's fixture (400 phase-1 rows, 167 phase-2 rows,
`method = "approx"`):

| Quantile | Before | After = `svyquantile()` | SE before | SE after = `svyquantile()` |
|---|---|---|---|---|
| p25 | 42.548 | 42.688 | 1.0067 | 0.7677 |
| p50 | 49.694 | 49.125 | 0.9212 | 1.0169 |
| p75 | 57.129 | 57.016 | 1.2820 | 1.4972 |

A design whose phase-2 variable is `NA` on the phase-1-only rows no longer
returns `NA` under `na.rm = FALSE`, and a group level seen only on
phase-1-only rows no longer produces an empty group row.

### Not closed here

Under `method = "approx"` the quantiles now match `survey` exactly. Under
`"simple"` and `"full"` the estimates match but the SEs do not. The same SE
gaps show up in `get_means()`, so they come from the two-phase variance, not
the quantile path: `"full"` is #329, and `"simple"` is #330: `survey`
treats it as `"approx"`, and surveycore computes a phase-1 term only, so
`get_means()` gives 0.8512 against `survey`'s 0.8688 on the same fixture.

## Files Modified

- `R/analysis-quantiles.R` — restricts the domain mask to phase-2 rows on a
  two-phase design
- `R/analysis-quantiles-helpers.R` — corrects the `.get_quantile_weights()`
  comment on the weight phase-1-only rows receive
- `tests/testthat/test-analysis-quantiles.R` — oracle blocks against
  `svyquantile()` for unfiltered, filtered and grouped `approx` designs, a
  phase-2 `n` block, and an `na.rm = FALSE` block with phase-1-only `NA`s

## Changes

- Restrict `get_quantiles()` on a two-phase design to phase-2 rows, so its
  estimate, SE, CI and `n` match `survey::svyquantile()`
