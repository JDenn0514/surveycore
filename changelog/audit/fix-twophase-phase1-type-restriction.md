# fix(constructors): allow survey_srs and survey_replicate as two-phase phase-1

**Date**: 2026-03-16
**Branch**: fix/twophase-phase1-type-restriction
**Phase**: Audit remediation

## Changes

- Relaxed `as_survey_twophase()` phase-1 type check from `survey_taylor` to `survey_base`, allowing `survey_srs` and `survey_replicate` phase-1 designs
- Updated error message (row 19) to reference `survey_base` instead of `survey_taylor`
- Added acceptance tests for `survey_srs` and `survey_replicate` phase-1
- Added oracle tests comparing SRS phase-1 two-phase estimates against `survey` package
- Added smoke test for `survey_replicate` phase-1 two-phase estimation

## Files Modified

- `R/core-constructors.R` — relaxed type check from `survey_taylor` to `survey_base`; updated roxygen `@param phase1` docs
- `man/as_survey_twophase.Rd` — regenerated from roxygen
- `tests/testthat/test-constructors.R` — replaced replicate rejection test with acceptance test; added SRS acceptance test; added plain list rejection test
- `tests/testthat/test-variance-twophase.R` — added SRS phase-1 oracle tests for means and totals; added replicate phase-1 smoke test
- `tests/testthat/_snaps/constructors.md` — updated snapshot for new error message text
- `plans/error-messages.md` — updated row 19 description
