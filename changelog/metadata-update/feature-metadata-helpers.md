# Changelog — feature/metadata-helpers

**PR:** `feature/metadata-helpers`
**Depends on:** `feature/metadata-s7-classes` (PR 1)
**Date:** 2026-03-11

## Summary

Adds internal helper infrastructure to `R/core-metadata.R` in preparation for
the unified setter API (PR 3) and extended extractors (PR 4).

## New internal helpers (not exported)

- `.check_is_survey_or_df(x, call)` — type guard accepting survey objects and
  plain data frames; fires `surveycore_error_not_survey_or_df` for anything
  else. Replaces `.check_is_survey()` once PR 3 updates all callers.
- `.get_data_cols(x)` — returns `names(x)` for data frames, `names(x@data)`
  for survey objects.
- `.get_metadata(x)` — returns `x@metadata` for survey objects, `NULL` for
  data frames.
- `.parse_setter_input(dots, variable, content, content_arg_name, content_type,
  fn_name, call)` — shared convention detection for all unified setters.
  Handles Conventions 1, 2 (scalar and vector), and 3; errors for ambiguity,
  empty input, length mismatch, and mixed/unnamed `...` elements.
- `.resolve_vars(x, var_exprs, call)` — resolves `...` quosures for extractor
  functions; returns all columns when empty; warns and skips missing variables.
- `.format_scalar_result(result_list, format, col_name, empty_value)` —
  converts named list of scalars to `"named_vector"`, `"list"`, or
  `"data_frame"` output.
- `.format_list_result(result_list, format, fn_name)` — converts named list of
  vectors to `"list"` or `"data_frame"` output; rejects `"named_vector"` with
  `surveycore_error_format_invalid`.

## Test coverage

33 new test blocks in `tests/testthat/test-metadata-system.R` covering:
- All happy paths for each helper
- All error classes: `surveycore_error_not_survey_or_df`,
  `surveycore_error_setter_ambiguous`, `surveycore_error_setter_empty`,
  `surveycore_error_setter_mismatched_lengths`,
  `surveycore_error_setter_mixed_dots`, `surveycore_error_format_invalid`
- Warning class: `surveycore_warning_var_not_found`
- Snapshot tests for all error/warning messages

## Quality gates

- `devtools::test()` — 0 failures (6637 tests pass)
- `devtools::check()` — 0 errors, 0 warnings, 2 notes (both pre-approved)
- No new exports; NAMESPACE unchanged
