# chore(cleanup): fix test warnings and update stale Phase 0.5 comments

**Date**: 2026-02-24
**Branch**: chore/file-structure-cleanup
**Phase**: Phase 0.75

## Changes

- Remove two dead tests and one dead test block that referenced removed behavior
  in `test-conversion.R` and `test-methods-print.R`
- Remove stale `# nocov` markers from `R/05-methods-conversion.R` that tagged
  reachable branches as uncoverable
- Fix 23 leaked SRS dispatch warnings in `test-constructors.R`: `as_survey()`
  without ids/strata now dispatches to `survey_srs` and fires
  `surveycore_warning_as_survey_srs_fallback`; tests not asserting on that
  warning now wrap calls in `suppressWarnings()`
- Update stale "Phase 0.5" references in R source files and test helpers to
  reference "surveytidy" (the shipped package) instead of the planning-era label

## Files Modified

- `R/00-s7-classes.R` — replace Phase 0.5 `@groups` reserve comments with
  accurate surveytidy references
- `R/04-methods-print.R` — replace Phase 0.5 nocov labels with surveytidy
  references
- `R/07-utils.R` — replace two Phase 0.5 comments with surveytidy references
- `tests/testthat/helper-test-data.R` — replace one Phase 0.5 comment with
  surveytidy reference
- `tests/testthat/test-constructors.R` — suppress 23 leaked SRS dispatch
  warnings via three `suppressWarnings()` patterns
