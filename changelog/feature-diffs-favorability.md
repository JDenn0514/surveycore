# feat(analysis): add `show_favorability` and `alpha` arguments to `get_diffs()`

**Date**: 2026-05-11
**Branch**: feature/diffs-favorability
**Phase**: Post-Phase 2 (PR 3 of variable-direction plan)

## Changes

- Add `show_favorability` argument to `get_diffs()` — when `TRUE`, appends
  `favorable` and `backlash` logical columns classifying whether each
  treatment–reference difference is statistically significant and in the
  expected direction per `higher_is` metadata; both columns are all `FALSE`
  when no `higher_is` metadata is set
- Add `alpha` argument to `get_diffs()` — significance threshold (default
  `0.05`) used for classifying differences; validated to be a single numeric
  value strictly between 0 and 1
- Add `surveycore_error_alpha_invalid` error class for invalid `alpha` input
- Update NEWS.md to reflect the new arguments
- Update `plans/error-messages.md` with the new error class row

## Files Modified

- `R/analysis-diffs.R` — add `alpha` and `show_favorability` params, alpha
  validation, and favorability-column construction step (Step 20a)
- `man/get_diffs.Rd` — updated roxygen2 docs for new params and return value
- `tests/testthat/test-analysis-diffs.R` — new test section (PR 3) covering
  all `alpha_invalid` error paths and `show_favorability` happy paths
- `tests/testthat/_snaps/analysis-diffs.md` — new snapshots for alpha error
  messages
- `plans/error-messages.md` — new `surveycore_error_alpha_invalid` row
- `NEWS.md` — entry for `get_diffs(alpha, show_favorability)`
