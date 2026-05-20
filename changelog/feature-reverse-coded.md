# feat(metadata): add `reverse_coded` flag attribute

**Date**: 2026-05-08
**Branch**: feature/reverse-coded
**Phase**: Post-Phase 2 metadata extension (PR 2 of variable-direction plan)

## Changes

- Add `reverse_coded` property to `survey_metadata` S7 class — a named list mapping variable names to `TRUE` for reverse-coded variables; absent keys mean the variable is not reverse-coded
- Implement `set_reverse_coded()` — marks one or more variables as reverse-coded on survey design objects or data frames via two calling conventions (tidy-select `...` or `variable =` character vector); `reverse_coded = FALSE` removes the flag; warns on unknown variables in the `variable =` path
- Implement `extract_reverse_coded()` — retrieves reverse-coded status as a named logical vector; unmarked variables return `FALSE`; zero-argument form returns status for all columns
- Add error classes `surveycore_error_reverse_coded_ambiguous_input`, `surveycore_error_reverse_coded_no_vars`, `surveycore_error_reverse_coded_not_logical` to `plans/error-messages.md`
- Add `NEWS.md` entry under current development version

## Files Modified

- `R/core-classes.R` — add `reverse_coded = S7::new_property(S7::class_list, ...)` to `survey_metadata`
- `R/core-metadata.R` — implement `set_reverse_coded()` and `extract_reverse_coded()`
- `tests/testthat/test-metadata-system.R` — new test section covering happy paths, all error/warning classes, edge cases
- `tests/testthat/_snaps/metadata-system.md` — new snapshots for all error/warning messages
- `plans/error-messages.md` — three new error class rows
- `NAMESPACE` — export `set_reverse_coded` and `extract_reverse_coded`
- `man/set_reverse_coded.Rd` — new roxygen2-generated man page
- `man/extract_reverse_coded.Rd` — new roxygen2-generated man page
- `NEWS.md` — feature entry for `set_reverse_coded()` and `extract_reverse_coded()`
- `_pkgdown.yml` — add `set_reverse_coded` and `extract_reverse_coded` to metadata reference section
- Various `man/*.Rd` — updated due to `devtools::document()` run
