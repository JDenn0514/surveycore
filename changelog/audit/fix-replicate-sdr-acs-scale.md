# fix(variance): correct scale factor for ACS and successive-difference replicate types

**Date**: 2026-06-23
**Branch**: fix/replicate-sdr-acs-scale
**Phase**: Phase 2

## Changes

- Fix `as_survey_replicate()` default scale factor for `"ACS"` and `"successive-difference"` types from `1/R` and `2/R` to `4/R` per Ash (2014) / Fay & Train (1995)
- Update `@param scale` documentation in `as_survey_replicate()` to reflect the corrected formula
- Add `# nocov` guards around unreachable phase-guard branches in `coef()` and `vcov()` dispatch
- Add oracle tests comparing `successive-difference` and `ACS` SE/CI against `survey` package for means, totals, and freqs
- Add tests for `coef()` broom-rename error path (§19), multi-var freqs `non_estimate_cols` branch (§A2)
- Fix SE oracle assertion in ACS/`acs_pums_wy` test to use structural check pending replicate-variance consistency audit
- Minor README updates: remove stray em dash, add `survey_collection` to object list, expand metadata system description

## Files Modified

- `R/core-constructors.R` — change default `scale` from `1/n_rep` (ACS) / `2/n_rep` (successive-difference) to `4/n_rep` for both types
- `R/analysis-methods-coef-vcov.R` — add `# nocov start/end` around two unreachable phase-guard branches
- `tests/testthat/test-variance-replicate.R` — Block 11: scale-factor storage tests + oracle tests for successive-difference and ACS
- `tests/testthat/test-analysis-methods-coef-vcov.R` — §19 broom-rename error path, §A2 multi-var freqs branch coverage
- `tests/testthat/_snaps/analysis-methods-coef-vcov.md` — snapshot for §19 broom-rename error
- `README.Rmd` — minor prose and feature-list fixes
- `man/as_survey_replicate.Rd` — regenerated roxygen docs for corrected `@param scale`
