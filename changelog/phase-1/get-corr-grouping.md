# feat(analysis): add group parameter to get_corr()

**Date**: 2026-02-27
**Branch**: feature/get-corr-grouping
**Phase**: Phase 1

## Changes

- Add `group = NULL` parameter to `get_corr()` for per-group survey-weighted correlations, matching the grouping interface of all other Phase 1 analysis functions
- `@groups` set via `group_by()` is now respected in `get_corr()` (was silently ignored before)
- Group columns are prepended in both long and wide output when `group` is active
- Extract `.corr_build_matrix_col_vecs()` from the old `.corr_wide()` helper; delete `.corr_wide()` (no callers)
- Update `label_values` documentation: group column is converted to a labelled factor when the group variable has value labels
- Add full test coverage for grouped `get_corr()`: group columns, wide + groups, group labels, meta$group, numerical accuracy, single-level warning, NA exclusion, redundant/diagonal row counts
- Update `vignettes/getting-started.Rmd` with grouped correlation example
- Update pew Jewish 2020 survey data

## Files Modified

- `R/analysis-corr.R` — add `group` param; outer group-combo loop; wide stacked matrix path; group metadata; `group_meta` passed to `.make_result_tibble()`
- `R/analysis-corr-helpers.R` — extract `.corr_build_matrix_col_vecs()`; delete `.corr_wide()`
- `tests/testthat/test-analysis-corr.R` — replace "ignores @groups" test; add 10+ grouping tests; regenerate snapshots
- `man/get_corr.Rd` — auto-updated by `devtools::document()`
- `NEWS.md` — new `get_corr()` grouping entry under development version
- `vignettes/getting-started.Rmd` — grouped correlation example
- `data-raw/prepare-pew-jewish-2020.R` — update pew Jewish 2020 data preparation
- `data/pew_jewish_2020.rda` — updated pew Jewish 2020 dataset
