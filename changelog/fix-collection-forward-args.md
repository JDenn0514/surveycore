# Changelog: fix/collection-forward-args

**Branch:** `fix/375-collection-forward-args`
**Status:** Complete
**Date:** 2026-11-18
**Issue:** #375

## Summary

Refs #375. On a `survey_collection`, 11 analysis functions ignored every
argument except the tidy-select variables, `...`, `.id` and
`.if_missing_var`. Each function's collection branch passed only those to
`.dispatch_over_collection()`, so each member survey ran with the defaults.
The affected functions are `get_corr()`, `get_covariance()`, `get_diffs()`,
`get_freqs()`, `get_means()`, `get_pairwise()`, `get_quantiles()`,
`get_ratios()`, `get_t_test()`, `get_totals()` and `get_variance()`. For
example, `get_diffs(coll, ..., min_cell_n = 10L)` still raised 18 small-cell
warnings that the same call on one member survey did not raise.

`.dispatch_over_collection()` gains `.caller_env`. When it is set, the new
helper `.collection_supplied_formals()` collects every formal the caller
supplied that `...` does not already name, and the dispatcher forwards them
to each survey. A formal the caller left out is not forwarded, so each
survey applies its own default. All 12 dispatch branches, including
`get_effective_n()`, pass `environment()`. A formal added to a function
later is forwarded with no edit to its branch.

`.caller_env` defaults to `NULL`, which forwards `...` only. Five existing
tests call the dispatcher directly and rely on that default.

### Found and not fixed here

`get_diffs()` ignores `conf_level` on its marginaleffects path, for a single
survey as well as a collection. That is issue #377. The `get_diffs()` test
here uses `pval_adj` for that reason.

## Files Modified

- `R/survey-collection.R` — new helper `.collection_supplied_formals()`;
  `.dispatch_over_collection()` gains `.caller_env` and forwards the
  supplied formals
- `R/analysis-corr.R`, `R/analysis-covariance.R`, `R/analysis-diffs.R`,
  `R/analysis-effective-n.R`, `R/analysis-freqs.R`, `R/analysis-means.R`,
  `R/analysis-quantiles.R`, `R/analysis-ratios.R`, `R/analysis-t-test.R`
  (two branches), `R/analysis-totals.R`, `R/analysis-variance.R` — each
  collection branch passes `.caller_env = environment()`
- `tests/testthat/test-survey-collection-dispatch.R` — 12 new blocks in a
  new section on named-argument forwarding
- `NEWS.md` — a Bug fixes entry

## Changes

- Forward every supplied named argument from each collection branch to
  every member survey
- Add one oracle block per fixed function: the collection result with a
  non-default argument equals the per-survey bind with the same argument,
  and differs from the collection result at the default
- Add a block that `get_diffs(coll, ..., min_cell_n = 10L)` raises no
  warning

## Verification

- All 12 new blocks fail on `develop`'s `R/` code and pass on this branch.
- Full suite with `NOT_CRAN=true` on Windows: 0 failures and 206 warnings
  on this branch. The #376 commit reports 206 for `develop` at `dd4b5e6`,
  so the warning count is unchanged.
- Before #376, the same suite gave 254 warnings on `develop` at `c3add3a`
  and 254 with the fix alone, with the same per-test set.
