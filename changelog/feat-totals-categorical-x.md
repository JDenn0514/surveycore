# Changelog: feat/totals-categorical-x

**Branch:** `feature/joint-vcov-totals-factor`
**Status:** Complete
**Date:** 2026-10-22
**Issue:** #199

## Summary

Closes #199. Refs #200.

`get_totals()` refused a factor `x` with `surveycore_error_non_numeric_variable`,
though a factor's level totals are well defined and `survey::svytotal()`
returns one total and one standard error per level. `get_totals()` now accepts
a factor or character `x` and returns one row per level. Each level's total is
the total of its 0/1 indicator, sent through the existing numeric total path,
so every design class (Taylor, replicate, two-phase, non-probability) is
covered and the numeric path is unchanged. Totals, standard errors and
confidence bounds match `survey::svytotal()` and `survey::svyby()` on Taylor
and replicate designs, filtered and unfiltered.

The level column is named after the variable and sits between the group
columns and `total`, as in `get_freqs()`. A level with no observed rows is
dropped, as in `get_freqs()`; `svytotal()` returns it as a zero row, which
would give a singular covariance matrix downstream. With `na.rm = FALSE`, the
rows where `x` is `NA` form their own level row, last. For a categorical `x`,
`n` and `n_weighted` count the rows at the level. `coef()` names the rows
`variable.level`. Logical columns are still rejected.

### Fixed in passing: `get_freqs()` mislabelled numeric-looking factor levels

`get_freqs()` on a factor whose levels look like numbers, such as
`factor(nhanes_2017$ridreth3)` with levels `"1"`, `"2"`, `"3"`, `"4"`, `"6"`,
`"7"`, labelled two rows `"7"`. The labels inferred from a factor are coded
1 to k by position, and the level string `"6"` was looked up as code 6, which
is the label of the sixth level. A factor's levels are already its labels, so
the code lookup now applies to non-factor columns only. The estimates were
always right; only the row labels were wrong. The level-display code moved to
shared helpers in `R/analysis-helpers.R`, which `get_totals()` also uses.

## Files Modified

- `R/analysis-totals.R` — accepts a factor or character `x`, expands it into one indicator per level, adds the level column, and documents the categorical mode.
- `R/analysis-helpers.R` — gains `.get_levels()` (moved from `R/analysis-freqs-helpers.R`), `.level_display()`, `.value_label_map()` and `.focal_level_column()`.
- `R/analysis-freqs.R` — uses the shared level-display helpers; a factor no longer goes through the code lookup.
- `R/analysis-freqs-helpers.R` — `.get_levels()` moved out.
- `R/analysis-methods-coef-vcov.R` — `coef()` names categorical totals `variable.level`.
- `plans/error-messages.md` — row 43 lists the functions that actually raise `surveycore_error_non_numeric_variable`; row 53 adds `get_totals()`; new row 55a, `surveycore_warning_all_na_totals`.
- `man/get_totals.Rd` — regenerated.
- `tests/testthat/test-analysis-totals.R` — 14 blocks for the categorical mode, including oracles against `svytotal()` (NHANES Taylor, ACS replicate), `svyby()` and a filtered design.
- `tests/testthat/test-analysis-freqs.R` — one block for the mislabelling fix.

## Changes

- `get_totals()` accepts a factor or character `x` and returns one total per level.
- New warning `surveycore_warning_all_na_totals` when a categorical `x` is all `NA` with `na.rm = TRUE`; `surveycore_error_all_na` when it is all `NA` with `na.rm = FALSE`.
- `get_freqs()` labels each row of a numeric-looking factor with its own level.
- `surveycore_error_non_numeric_variable` catalogue row corrected.
