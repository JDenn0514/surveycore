# fix(constructors): downgrade as_survey() SRS fallback from warning to message

**Date**: 2026-03-12
**Branch**: fix/as-survey-srs-warning
**Phase**: Post-Phase-2 Audit Remediation (PR 9)

## Changes

- Downgrade `cli_warn()` to `cli_inform()` in `as_survey()` when no `ids` or
  `strata` are supplied and dispatch falls through to `as_survey_srs()`
- Rename the class from `surveycore_warning_as_survey_srs_fallback` to
  `surveycore_message_as_survey_srs_fallback` to match the new severity level
- Simplify the message to two `"i"` bullets (drop the `"!"` and `"v"` bullets)
- Update `plans/error-messages.md` row 60 to reflect INFO type and new class
- Update all `expect_warning()` calls in tests to `expect_message()` with the
  new class name
- Update CLI snapshots in `_snaps/constructors.md` to show `Message` output
  instead of `Warning`

## Files Modified

- `R/core-constructors.R` — change `cli_warn()` to `cli_inform()`, update
  message text and class (~line 348)
- `plans/error-messages.md` — update row 60 severity and class
- `tests/testthat/test-constructors.R` — update `expect_warning()` to
  `expect_message()` with new class name (3 test blocks)
- `tests/testthat/_snaps/constructors.md` — regenerated CLI snapshots
