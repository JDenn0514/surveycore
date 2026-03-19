# feature/multi-stage-analysis

## Summary

Refactored three Taylor-linearization analysis helpers to use the shared
`.build_cluster_matrices()` helper, replacing inline single-stage matrix
construction with the multi-stage-aware version. Added a comprehensive
oracle test suite comparing surveycore multi-stage results against the
`survey` R package.

## Changes

### Source files modified

- `R/analysis-means-helpers.R` — `.taylor_mean_cell()`: replaced inline
  strata/cluster/FPC matrix construction with `.build_cluster_matrices()`
  call and `mats$` references.
- `R/analysis-freqs-helpers.R` — `.taylor_freq_cell()`: same refactor.
- `R/analysis-totals-helpers.R` — `.taylor_total_cell()`: same refactor.

### Tests added

- `tests/testthat/test-variance-taylor.R` — Block 17: multi-stage oracle
  suite (~11 tests) comparing `get_means()`, `get_freqs()`, `get_totals()`,
  `get_corr()`, `get_quantiles()`, and `get_ratios()` against `survey`
  package for 2-stage and 3-stage designs with and without FPC.
- `tests/testthat/test-variance-taylor.R` — Block 18: multi-stage edge
  case tests (~7 tests) covering single-PSU strata, na.rm with multi-stage,
  and single-stratum designs.

## Behavior

No user-visible behavior change. The refactoring is internal only —
multi-stage variance estimation was already enabled by PR 4
(`feature/multi-stage-variance-taylor`). This PR ensures the analysis
helpers use the shared helper and adds comprehensive oracle validation.
