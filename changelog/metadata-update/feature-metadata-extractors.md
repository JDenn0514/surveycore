# Changelog: feature/metadata-extractors

## Summary

Updated all four existing extractors (`extract_var_label`, `extract_val_labels`,
`extract_question_preface`, `extract_var_note`) with new multi-variable API
and added three new functions (`extract_universe`, `extract_missing_codes`,
`extract_metadata`).

## Changes

### R/core-metadata.R

- **Updated** `extract_var_label()`: new signature `(x, ..., format, fill)`;
  returns named character vector; supports all data formats; works on survey
  objects and data frames.
- **Updated** `extract_val_labels()`: new signature `(x, ..., format, fill)`;
  returns named list; supports "list" and "data_frame" formats.
- **Updated** `extract_question_preface()`: new signature `(x, ..., format, fill)`;
  returns named character vector; data frame support.
- **Updated** `extract_var_note()`: new signature `(x, ..., format, fill)`;
  returns named character vector; data frame support.
- **Added** `extract_universe()`: extract universe annotations; same API as
  `extract_var_label()`.
- **Added** `extract_missing_codes()`: extract missing value code vectors; same
  API as `extract_val_labels()` with "variable/description/code" data frame
  columns.
- **Added** `extract_metadata()`: summary function; returns per-variable named
  list with 7 keys: `variable_label`, `value_labels`, `question_preface`,
  `note`, `universe`, `missing_codes`, `transformations`.
- **Added** `.check_extractor_fill()` and `.check_extractor_format()` internal
  validation helpers shared across all extractor functions.
- **Fixed** `.format_scalar_result()`: returns `character(0)` (not `NULL`) for
  empty "named_vector" format.

### NEWS.md

Added `### Breaking Changes` (4 items) and `### New Functions` sections under
the current development version.

### tests/testthat/test-metadata-system.R

- Replaced old extractor tests (9 blocks) with expanded new API tests (~90
  blocks covering multi-variable, format, fill, data frame, error, and snapshot
  behavior for all 6 extractors).
- Added 6 round-trip tests (data frame → as_survey() → extractor).
- Added 20+ `extract_metadata()` tests.
- Updated `make_labeled_design()` to use `y3 = c(No = 0L, Yes = 1L)` for value
  labels (was: strata with mismatched integer codes).
