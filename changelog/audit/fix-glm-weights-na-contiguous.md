# fix(glm): correct weight indexing for non-contiguous NAs with na.omit

**Date**: 2026-03-16
**Branch**: fix/glm-weights-na-contiguous
**Phase**: Audit remediation

## Changes

- Fixed incorrect weight vector indexing in `survey_glm()` when `na.action = na.omit` drops non-contiguous rows
- Previously, `wt_fit[seq_len(length(fitted(fit)))]` always took the first N weights, which is wrong when dropped rows are non-contiguous
- Now uses `wt_fit[-na_idx]` to select weights corresponding to rows actually used in the fit
- Added 2 new tests covering non-contiguous NA weight correctness and equivalence with manually-cleaned data

## Files Modified

- `R/glm.R` — replaced `seq_len(length(fitted(fit)))` with `na_idx`-aware indexing at the `survey_glm_fit()` constructor call
- `tests/testthat/test-glm.R` — added 2 tests for non-contiguous NA weight correctness
