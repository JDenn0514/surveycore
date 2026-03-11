# Changelog — feature/metadata-setters

**PR:** `feature/metadata-setters`
**Depends on:** `feature/metadata-helpers` (PR 2)
**Date:** 2026-03-11

## Summary

Replaces the old singular/plural setter dichotomy with a unified three-convention
API for all metadata setters, adds two new setters (`set_universe()`,
`set_missing_codes()`), removes the deprecated plural setters
(`set_variable_labels()`, `set_value_labels()`, `set_question_prefaces()`,
`set_variable_notes()`), updates `.extract_haven_metadata()` to populate the new
fields, and removes `.check_is_survey()` in favour of `.check_is_survey_or_df()`.

## New exported functions

- `set_universe(x, ..., variable = NULL, universe = NULL)` — sets universe
  string on `survey_metadata@universe` for one or more variables via the
  three-convention API.
- `set_missing_codes(x, ..., variable = NULL, codes = NULL)` — sets missing
  code vectors on `survey_metadata@missing_codes` for one or more variables.

## Updated exported functions

All four existing setters now use the unified three-convention API:
- `set_var_label(x, ..., variable = NULL, label = NULL)`
- `set_val_labels(x, ..., variable = NULL, labels = NULL)`
- `set_question_preface(x, ..., variable = NULL, preface = NULL)`
- `set_var_note(x, ..., variable = NULL, note = NULL)`

Each setter accepts:
- Convention 1: named `...` (e.g., `set_var_label(svy, age = "Age in years")`)
- Convention 2: single named vector/list in `...`
  (e.g., `set_var_label(svy, c(age = "Age in years"))`)
- Convention 3: `variable` + content arg
  (e.g., `set_var_label(svy, variable = "age", label = "Age in years")`)

All setters also accept plain data frames as `x` (sets `attr(df$col, "label")`
for `set_var_label`, `attr(df$col, "labels")` for `set_val_labels`, etc.).

## Removed exports

- `set_variable_labels()` — removed (was plural wrapper; replaced by Convention 1/2 of `set_var_label()`)
- `set_value_labels()` — removed (replaced by Convention 1/2 of `set_val_labels()`)
- `set_question_prefaces()` — removed (replaced by Convention 1/2 of `set_question_preface()`)
- `set_variable_notes()` — removed (replaced by Convention 1/2 of `set_var_note()`)

## Internal changes

- `.check_is_survey()` removed; all callers now use `.check_is_survey_or_df()`
- `.extract_haven_metadata()` updated to extract `universe` and `missing_codes`
  attributes from haven-labelled columns

## Test coverage

165 new test blocks in `tests/testthat/test-metadata-system.R` covering:
- All three conventions for each setter (happy paths)
- Data frame support for each setter
- NULL value handling (key deletion)
- Pipe chain survival
- All error classes: `surveycore_error_not_survey_or_df`,
  `surveycore_error_setter_ambiguous`, `surveycore_error_setter_empty`,
  `surveycore_error_setter_mismatched_lengths`,
  `surveycore_error_setter_mixed_dots`, `surveycore_error_old_positional_setter`,
  `surveycore_error_label_not_scalar`
- Warning classes: `surveycore_warning_var_not_found`,
  `surveycore_warning_setter_empty_variables`
- Snapshot tests for all error/warning messages

## Quality gates

- `devtools::test()` — 0 failures
- `devtools::check()` — 0 errors, 0 warnings, 2 notes (both pre-approved)
- NAMESPACE updated: `set_missing_codes` and `set_universe` added;
  `set_variable_labels`, `set_value_labels`, `set_question_prefaces`,
  `set_variable_notes` removed
