# Changelog: feature/phase1-freqs

## Summary

Implement `get_freqs()` — weighted frequency tables for categorical survey variables.

## New exports

- `get_freqs()` — compute weighted proportions (percentages) for one or more
  categorical variables across all five survey design types (`survey_taylor`,
  `survey_replicate`, `survey_srs`, `survey_twophase`, `survey_calibrated`).

## Features

- **Single-variable mode**: the variable name becomes the first column; rows
  follow factor level order (or ascending sort for non-factors).
- **Multi-variable mode**: stacked long format when `x` resolves to 2+
  variables; `names_to` and `values_to` control the stacking column names.
- **Domain estimation**: ratio linearization approach equivalent to
  `survey::svymean()` on a 0/1 indicator — uses the full design structure
  for variance, never physically subsets rows.
- **All variance types**: `se`, `ci`, `var`, `cv`, `moe`, `deff` via the
  shared `.add_variance_cols()` helper.
- **Metadata-driven labelling**: `label_values` applies value labels;
  `label_vars` applies variable labels in the `names_to` column (multi-var).
- **na.rm=FALSE**: `NA` appears as an extra last level; denominator includes
  NA rows so all pct values sum to 100.
- **n_weighted**: optional weighted population count column.
- **AAPOR small-cell warning**: fires at `n < min_cell_n` (default 30).

## Internal helpers (single-use, defined in R/10-analysis-freqs.R)

- `.get_levels()` — ordered unique levels (factor-order or ascending sort);
  NA appended last when `na.rm=FALSE`.
- `.taylor_freq_cell()` — ratio linearization for `survey_taylor` and
  `survey_calibrated`.
- `.replicate_freq_cell()` — per-replicate proportion via `.svy_rep_var()`.
- `.srs_freq_cell()` — classical SRS proportion variance.
- `.twophase_freq_cell()` — calibrated-weight ratio with `.twophasevar()`.
- `.freq_cell()` — design-class dispatcher.

## Files changed

- `R/10-analysis-freqs.R` (new)
- `tests/testthat/test-analysis-freqs.R` (new, 341 tests)
- `_pkgdown.yml` (added `get_freqs` to Estimation section)
- `man/get_freqs.Rd` (generated)
- `NAMESPACE` (updated)
- `R/09-meta.R` (add `@keywords internal` to `print.survey_result` — fixes pkgdown CI)
- `man/print.survey_result.Rd` (regenerated)
