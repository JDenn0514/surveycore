# Changelog: fix/domain-degf

**Branch:** `fix/domain-degf`
**Status:** Complete
**Date:** 2026-10-21
**Issue:** #326

## Summary

Refs #326. Wherever surveycore uses a finite design df, it counted the PSUs
and strata of the whole design, even when the estimate used fewer rows.
`survey` counts only the PSUs and strata that hold a row the estimate uses.
`survey::degf()` is computed on the design `survey` analyses, after
`subset()`, after `svyquantile()`'s own `na.rm = TRUE` row drop, within each
`svyby()` group, and over `svyglm()`'s complete cases. So on a filtered
design, a grouped quantile, or a fit whose missing values empty a stratum,
surveycore's intervals were narrower than `survey`'s. Measured on a 40-PSU,
8-stratum design where the estimate's rows sit in 2 strata: surveycore used
df 32, `survey` used 8.

`.degf()` now takes the rows that enter an estimate, defaulting to the
active domain, and counts only their PSUs and strata. Each caller passes its
rows:

- `get_quantiles()` computes the Woodruff df once per group cell, over the
  cell's non-missing rows. The CI columns, the SE derived from them, and the
  stored `.survey_result` df all follow it.
- `survey_glm()` uses the rows used in the fit, which is the domain less any
  rows `na.action` dropped. That moves its `@degf`, and with it the
  `confint()`, p-values, `get_diffs()` and `get_t_test()` built on the fit.
- The calibrated Taylor per-cell df in `get_means()` (and the unused one in
  `get_totals()`) counts the cell's rows.

The variance is unchanged: every PSU still enters the sum, and only the df
moved. Replicate designs keep `R - 1`, which `subset()` does not change in
`survey` either. `survey_nonprob` keeps `Inf`.

### Published numbers move

Intervals get wider wherever the estimate's rows miss whole PSUs or strata.
That covers a filtered design, a grouped `get_quantiles()` call, and missing
values concentrated in some strata. An unfiltered, ungrouped estimate whose
rows touch every PSU is unchanged. `get_means()`, `get_totals()`,
`get_freqs()`, `get_ratios()` and `get_covariance()` on non-calibrated
designs use `df = Inf` (#325), so this change does not reach them.

### Two-phase designs

surveycore's two-phase df is phase-1 PSUs minus phase-1 strata over the
phase-2 rows, now restricted to the estimate's rows. `survey::degf()` on a
two-phase design uses the phase-2 design instead (41 against surveycore's 8
on the `make_all_designs()` fixture, with no filter). That basis difference
predates this change and is not resolved here.

## Files Modified

- `R/analysis-helpers.R` — `.degf()` gains `rows`, defaulting to `.apply_domain(design)`, and counts only those rows' PSUs and strata.
- `R/analysis-quantiles.R` — per-cell Woodruff df over the cell's non-missing rows; the stored df follows it.
- `R/analysis-quantiles-helpers.R` — `.degf_woodruff()` removed; it duplicated `.degf()`.
- `R/glm.R` — `.glm_degrees_of_freedom()` takes the rows used in the fit; roxygen for `survey_glm()` and `survey_glm_fit` says so.
- `R/analysis-means-helpers.R`, `R/analysis-totals-helpers.R` — the calibrated per-cell df counts the cell's rows.
- `R/analysis-means.R` — the `df` return doc says the count is per cell.
- `man/get_means.Rd`, `man/get_quantiles.Rd`, `man/survey_glm.Rd`, `man/survey_glm_fit.Rd` — regenerated.
- `tests/testthat/test-analysis-quantiles.R` — oracle blocks against `svyquantile()` on a filtered design, per group subset, and with `na.rm = TRUE`, plus the stored domain df.
- `tests/testthat/test-glm.R` — oracle blocks against `svyglm()` on a filtered design and with NA rows: `@degf`, SE and `confint()`.
- `tests/testthat/test-calibration.R` — calibrated df on a filtered design against `survey::degf(subset())`.
- `tests/testthat/test-analysis-helpers.R` — `.degf()` on the domain, on supplied rows, at the floor of 1, and for replicate and two-phase designs.

## Changes

- Finite design df counts only the PSUs and strata of the rows an estimate uses, matching `survey::degf()` on the design `survey` analyses.
- `get_quantiles()` CI columns and `survey_glm()` inference on filtered, grouped or NA-reduced data now match `survey`.
