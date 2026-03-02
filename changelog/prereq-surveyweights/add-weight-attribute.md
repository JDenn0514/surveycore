# feat(metadata): add weighting_history promotion and survey_weighting_history() accessor

**Date**: 2026-03-02
**Branch**: fix/add-weight-attribute
**Phase**: Prereq — surveyweights

## Changes

- Add `survey_weighting_history()` — exported accessor that returns
  `@metadata@weighting_history` from any `survey_base` subclass; returns
  `list()` when no history is present
- Add `.promote_weighting_history()` — internal helper that checks for a
  `"weighting_history"` attribute on the incoming data frame and copies it to
  `@metadata@weighting_history` on the resulting survey object
- Wire promotion into `as_survey()`, `as_survey_rep()`, and `as_survey_srs()` —
  each now calls `.promote_weighting_history()` after `.extract_haven_metadata()`;
  `as_survey_twophase()` needs no change as it inherits metadata from phase1

## Files Modified

- `R/utils.R` — add `survey_weighting_history()` (exported) and
  `.promote_weighting_history()` (internal helper)
- `R/core-constructors.R` — add `metadata <- .promote_weighting_history(data, metadata)`
  in `as_survey_srs()`, `as_survey()`, and `as_survey_rep()`
- `_pkgdown.yml` — add `survey_weighting_history` to Metadata — extractors section
- `tests/testthat/test-constructors.R` — 4 new tests: promotion in each of the
  three constructors, and plain data.frame leaves history as `list()`
- `tests/testthat/test-metadata-system.R` — 2 new tests for `survey_weighting_history()`
