# Changelog: fix/confint-df-consistency

**Branch:** `fix/confint-df-consistency`
**Status:** Complete
**Date:** 2026-10-21
**Issue:** #271

## Summary

Refs #271. `confint()` on a result from `get_means()`, `get_totals()`,
`get_freqs()`, `get_ratios()` or `get_covariance()` on a Taylor or two-phase
design returned a different interval from the result's own `ci_low` and
`ci_high` columns. The columns use the normal approximation (`df = Inf`),
which matches `survey`'s `confint()` default. `confint()` used a t quantile
with the full design's degrees of freedom, which those five functions stored
on the result's `.survey_result` attribute. The issue reported this for a
filtered (domain) design, but it held on every non-calibrated Taylor and
two-phase design. On the issue's 200-row example, `confint()` gave
-0.2703 to 0.3102 against the columns' -0.2470 to 0.2869.

The five functions now leave the stored df at its `Inf` default, the df
behind the CI columns. `confint()` therefore reproduces `ci_low` and
`ci_high`, and agrees with `confint()` on the matching `survey` object, on
full and filtered designs alike. This restores decision Q4 of the
coef-vcov-methods work (`archive/coef-vcov-methods/decisions-coef-vcov-methods.md`),
which chose `Inf` for exactly this consistency. Calibrated Taylor designs
already stored the per-cell df the columns use, and are unchanged. Replicate
and non-probability designs already stored `Inf`.

No estimate, standard error or CI column changes. Only `confint()` output
changes: it narrows from a t interval to the normal interval for Taylor and
two-phase designs, by about 8% at design df 15 and by more on smaller designs.

### Not changed here

Which finite df a filtered design should use (the full design's, or the
domain's as `survey::degf(subset(...))` counts it) is a separate decision.
It still affects `get_quantiles()`, calibrated Taylor designs and
`survey_glm()`-based inference, none of which this change touches.
`get_quantiles()` and `get_corr()` still store `.degf(design)`: the quantile
interval is Woodruff's, so `confint()` cannot reproduce it by df alone, and
`confint()` on a correlation result returns `NA`.

## Files Modified

- `R/analysis-means.R` — the stored df is the per-cell df for calibrated Taylor and `Inf` otherwise; the `df` return doc says `confint()` uses it.
- `R/analysis-totals.R`, `R/analysis-ratios.R` — drop the `.degf()` override of the stored df.
- `R/analysis-freqs.R`, `R/analysis-covariance.R` — drop the `.degf()` override of the stored df.
- `R/analysis-methods-coef-vcov.R` — `confint()` docs state that it reproduces the CI columns.
- `R/analysis-helpers.R` — `.degf()` docs name the two functions that still call it.
- `man/confint.survey_result.Rd`, `man/get_means.Rd` — regenerated.
- `tests/testthat/test-analysis-methods-coef-vcov.R` — four finite-df pins become `Inf` and column-agreement assertions; seven new blocks check that `confint()` reproduces the columns for all five functions on a filtered Taylor design and for `get_means()` on a two-phase design, and that the stored df is `Inf`.
- `tests/testthat/test-variance-taylor.R` — eight oracle blocks against `survey` on a filtered Taylor design: the estimate, SE and CI columns, and `confint()`, for means, totals, ratios and frequencies.
- `tests/testthat/test-analysis-{means,totals,freqs,ratios,covariance}.R` — the finite-df pins become `Inf` pins.
- `tests/testthat/_snaps/analysis-methods-coef-vcov.md` — two printed `confint()` matrices narrow to the normal interval.

## Changes

- `confint()` on Taylor and two-phase results from five `get_*()` functions now agrees with the result's `ci_low`/`ci_high` columns and with `survey`'s `confint()`.
- First tests to assert a filtered design's CI, its stored df and `confint()` against `survey`.
