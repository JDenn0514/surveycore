# feat(metadata): implement infer_question_prefaces()

**Date**: 2026-02-27
**Branch**: feature/infer-question-prefaces
**Phase**: Phase 1

## Changes

- Add `infer_question_prefaces()` — auto-detects shared question battery
  prefaces from variable labels using a two-pass algorithm (separator-based
  first, LCP-based fallback) and writes results to `question_preface` metadata
- Support dispatch on both survey design objects (writes to
  `@metadata@question_prefaces` and `@metadata@variable_labels`) and plain
  data frames (writes to `attr(col, "question_preface")` and
  `attr(col, "label")`)
- Update `.extract_haven_metadata()` to read `attr(col, "question_preface")`
  so data frames pre-processed by `infer_question_prefaces()` roundtrip
  correctly through `as_survey()`
- Add 3 new typed error/warning classes: `surveycore_error_not_survey_or_df`,
  `surveycore_warning_preface_not_overwritten`,
  `surveycore_warning_empty_label_after_trim`

## Files Modified

- `R/metadata-infer.R` — new file; `infer_question_prefaces()` and 4 internal
  helpers (`.collect_labels_survey()`, `.collect_labels_df()`, `.find_lcp()`,
  `.trim_to_word_boundary()`)
- `R/core-metadata.R` — update `.extract_haven_metadata()` to collect and
  pass `question_prefaces` from `attr(col, "question_preface")`
- `tests/testthat/test-metadata-infer.R` — new file; 69 tests covering
  separator detection, LCP detection, both dispatch paths, `overwrite`
  argument, all edge cases, and error snapshot
- `plans/error-messages.md` — add rows 78–80 and update the coverage map
