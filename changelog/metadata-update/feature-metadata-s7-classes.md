# Changelog — feature/metadata-s7-classes

**PR:** PR 1 of metadata-update
**Branch:** `feature/metadata-s7-classes`
**Depends on:** none

## Changes

### `R/core-classes.R`
- Added `universe` property (`S7::class_list`, default `list()`) to `survey_metadata`
- Added `missing_codes` property (`S7::class_list`, default `list()`) to `survey_metadata`
- Added `@param universe` and `@param missing_codes` to `survey_metadata` roxygen block

### `tests/testthat/test-s7-classes.R`
- Added 6 new test blocks for `universe` and `missing_codes` properties:
  - Default `list()` for both properties
  - Constructor accepts and stores values for both
  - `@` assignment round-trips for both

### `plans/error-messages.md`
- Added 11 new rows for metadata-update error/warning classes (M-2/M-7 through M-15)
- Updated coverage map for `test-metadata-system.R`

## Notes
- `universe` and `missing_codes` follow the same pattern as existing `notes` and
  `value_labels` properties — `S7::class_list` with `default = quote(list())`
- No changes to any function in `core-metadata.R` (deferred to PR 3)
