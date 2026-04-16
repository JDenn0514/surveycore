# refactor(metadata): migrate extract_*() functions to tidyselect

**Date**: 2026-04-16
**Branch**: feature/extract-tidyselect
**Phase**: Phase sata-metadata

## Changes

- Migrated all seven `extract_*()` metadata functions from `.resolve_vars()` to
  `tidyselect::eval_select()`, enabling tidyselect helpers like `starts_with()`,
  `all_of()`, `any_of()`, and `matches()`
- Removed `.resolve_vars()` function definition from `R/core-metadata.R`
- Updated `@param ...` documentation in all 7 extractors to use
  `tidy-select` markup and document available helpers
- Updated tests: replaced "warn and skip" behavior tests with new tidyselect
  behavior tests; removed `.resolve_vars()` direct test blocks and snapshot
- Added 3 new tidyselect behavior tests covering `starts_with()`, `all_of()`,
  and `any_of()` selectors

## Files Modified

- `R/core-metadata.R` — replaced `.resolve_vars()` calls in all 7 extractors;
  removed `.resolve_vars()` definition; updated `@param ...` docs in 7 functions
- `tests/testthat/test-metadata-system.R` — removed `.resolve_vars()` direct
  tests; updated "missing var" behavior tests; added 3 new tidyselect tests
- `tests/testthat/_snaps/metadata-system.md` — removed `.resolve_vars()` and
  `extract_var_label()` warning snapshots
- `man/extract_var_label.Rd` — updated by `devtools::document()`
- `man/extract_val_labels.Rd` — updated by `devtools::document()`
- `man/extract_question_preface.Rd` — updated by `devtools::document()`
- `man/extract_var_note.Rd` — updated by `devtools::document()`
- `man/extract_universe.Rd` — updated by `devtools::document()`
- `man/extract_missing_codes.Rd` — updated by `devtools::document()`
- `man/extract_metadata.Rd` — updated by `devtools::document()`
