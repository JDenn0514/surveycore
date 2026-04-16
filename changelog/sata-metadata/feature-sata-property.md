# feat(metadata): add sata property to survey_metadata

**Date**: 2026-04-16
**Branch**: feature/sata-property
**Phase**: Phase sata-metadata

## Changes

- Add `sata` property (`S7::class_list`, default `list()`) to `survey_metadata`
  S7 class for sparse storage of select-all-that-apply flags per variable
- Add `.get_data_for_select()` internal helper to `R/utils.R` for returning
  the correct data frame to pass to `tidyselect::eval_select()` in upcoming
  `set_sata()` and `extract_sata()` functions
- Update `.rename_metadata_keys()` in `R/core-validators.R` to propagate
  `sata` flags when variables are renamed

## Files Modified

- `R/core-classes.R` — added `sata` property to `survey_metadata` with
  `S7::class_list` type and `list()` default; updated `@param` roxygen doc
- `R/utils.R` — added `.get_data_for_select()` helper (not exported)
- `R/core-validators.R` — added `metadata@sata <- .rename_list_keys(...)` call
  in `.rename_metadata_keys()`
- `tests/testthat/test-s7-classes.R` — added two test blocks covering `sata`
  property default and named-list acceptance
- `tests/testthat/test-metadata-system.R` — added test block verifying
  `.rename_metadata_keys()` propagates `sata` flags through rename operations
