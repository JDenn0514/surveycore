# feat(methods): add names() method for survey objects to enable IDE autocomplete

**Date**: 2026-03-03
**Branch**: feature/survey-names-completion
**Phase**: Phase 1

## Changes

- Add `S7::method(names, survey_base)` that delegates to `names(x@data)`, enabling
  column name autocomplete in RStudio and Positron when a survey design object is
  the left-hand side of a pipe (e.g., `design |> get_means(`)
- Add tests covering `names()` for all five design types: `survey_taylor`,
  `survey_replicate`, `survey_twophase`, `survey_srs`, and consistency with
  `survey_data()`

## Files Modified

- `R/methods-compat.R` — new file with `S7::method(names, survey_base)` for IDE compatibility
- `tests/testthat/test-methods-compat.R` — 5 tests covering all design types
