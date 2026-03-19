# Changelog: Relax `survey_nonprob` Validator -- Zero Weights

**Branch:** `feature/nonprob-zero-weights`
**Date:** 2026-03-18

## Summary

Split the `survey_nonprob` validator condition 4 into two checks: condition 4a
rejects negative weights (new class `surveycore_error_weights_negative`) and
condition 4b rejects all-zero weights (reuses `surveycore_error_weights_all_zero`).
Zero weights are now accepted when at least one positive weight exists, unblocking
the surveywts `adjust_nonresponse()` workflow.

## Files changed

- `R/core-classes.R` -- Split condition 4 into 4a (negative) and 4b (all-zero)
- `tests/testthat/test-s7-classes.R` -- Added 9 new validator tests (happy path, error paths, edge cases)
- `tests/testthat/test-constructors.R` -- Deleted duplicate test; updated error class name
- `tests/testthat/helper-test-data.R` -- Updated `test_invariants()` nonprob branch: `>= 0` with `any > 0`
- `plans/error-messages.md` -- Added row 101; updated rows 10 and 33

## Check results

- `devtools::test()`: 7581 tests, 0 failures
- `devtools::check()`: 0 errors, 0 warnings, 2 notes (pre-approved)
