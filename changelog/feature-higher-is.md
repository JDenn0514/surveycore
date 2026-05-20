# feat(metadata): add `higher_is` direction-of-improvement attribute

**Date**: 2026-05-08
**Branch**: feature/higher-is
**Phase**: Post-Phase 2 metadata extension (PR 1 of variable-direction plan)

## Changes

- Add `higher_is` property to `survey_metadata` S7 class — a named list mapping variable names to `"better"` or `"worse"`, indicating the direction of improvement; absent keys mean the direction is unset
- Implement `set_higher_is()` — sets the direction attribute on survey objects or data frames via three calling conventions (named `...`, named vector, or `variable`/`direction` pair); validates that each direction value is `"better"`, `"worse"`, or `NULL`; warns on unknown variables
- Implement `extract_higher_is()` — retrieves direction attributes as a named character vector; unset variables return `NA_character_`; all-variable form returns every column's direction
- Update `.extract_var_meta()` in `R/analysis-helpers.R` to include `higher_is` in the per-variable metadata map — makes the attribute automatically available to `get_diffs()` and all other `get_*()` functions
- Add error classes `surveycore_error_direction_invalid`, `surveycore_error_higher_is_ambiguous_input`, `surveycore_error_higher_is_no_vars` to `plans/error-messages.md`
- Add `NEWS.md` entry under current development version

## Files Modified

- `R/core-classes.R` — add `higher_is = S7::new_property(S7::class_list, ...)` to `survey_metadata`
- `R/core-metadata.R` — implement `set_higher_is()` and `extract_higher_is()`
- `R/analysis-helpers.R` — extend `.extract_var_meta()` return list with `higher_is` key
- `tests/testthat/test-metadata-system.R` — new test section covering happy paths, all error/warning classes, edge cases, and `.extract_var_meta()` integration
- `tests/testthat/_snaps/metadata-system.md` — new snapshots for all error/warning messages
- `plans/error-messages.md` — three new error class rows
- `NAMESPACE` — export `set_higher_is` and `extract_higher_is`
- `man/set_higher_is.Rd` — new roxygen2-generated man page
- `man/extract_higher_is.Rd` — new roxygen2-generated man page
- `NEWS.md` — feature entry for `set_higher_is()` and `extract_higher_is()`
