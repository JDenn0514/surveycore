# feat(utils): extend make_survey_data() with n_ssu and n_unit parameters

**Date**: 2026-03-13
**Branch**: feature/multi-stage-test-helper
**Phase**: Multi-stage

## Changes
- Add `n_ssu` parameter to `make_survey_data()` for generating SSU IDs and stage-2 FPC
- Add `n_unit` parameter for generating unit IDs and stage-3 FPC (requires `n_ssu`)
- SSU IDs use format `"{psu}_s{j}"`, assigned round-robin within each PSU
- Unit IDs use format `"{ssu}_u{j}"`, assigned round-robin within each SSU
- `fpc2` = `n_ssu * 2L` (constant within PSU); `fpc3` = `n_unit * 2L` (constant within SSU)
- Error when `n_unit` is specified without `n_ssu`
- Default behavior (both NULL) is identical to previous version

## Files Modified
- `tests/testthat/helper-test-data.R` — add `n_ssu` and `n_unit` parameters to `make_survey_data()`
- `tests/testthat/test-constructors.R` — add 4 new test cases for multi-stage data generation
