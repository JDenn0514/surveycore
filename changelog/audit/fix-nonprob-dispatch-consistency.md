# fix(analysis): route survey_nonprob through calibrated HT path in get_freqs()

**Date**: 2026-03-16
**Branch**: fix/nonprob-dispatch-consistency
**Phase**: Audit remediation

## Changes

- Add `.calibrated_freq_cell()` — HT proportion variance for `survey_nonprob` designs, consistent with the HT path used by the other five analysis functions
- Update `.freq_cell()` dispatcher to route `survey_nonprob` to `.calibrated_freq_cell()` instead of `.taylor_freq_cell()`
- Add 4 new test cases verifying `survey_nonprob` dispatch consistency in `get_freqs()`

## Files Modified

- `R/analysis-freqs-helpers.R` — added `.calibrated_freq_cell()`, updated `.freq_cell()` dispatcher and comments
- `tests/testthat/test-analysis-freqs.R` — added consistency, oracle, grouped, and edge case tests for `survey_nonprob` freqs
