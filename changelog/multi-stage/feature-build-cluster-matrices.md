# feat(utils): add .build_cluster_matrices() for multi-stage variance

**Date**: 2026-03-13
**Branch**: feature/build-cluster-matrices
**Phase**: Multi-stage

## Changes
- Add `.build_cluster_matrices(data, vars)` internal helper to `R/utils.R`
  that builds clusters, strata, and FPC matrices for 1..k stage designs
- Replace inline FPC/matrix-building block in `.vcov_pair_srs()` with a
  call to `.build_cluster_matrices()`
- Add 7 unit tests for `.build_cluster_matrices()` covering single-stage,
  2-stage, 3-stage, NULL ids, nest adjustment, partial FPC, and sampsize
  correctness
- Add 1 regression oracle test confirming `.vcov_pair_srs()` output is
  unchanged after refactor

## Files Modified
- `R/utils.R` — Add `.build_cluster_matrices()` (multi-stage matrix builder)
- `R/variance-srs.R` — Replace inline cluster/strata/FPC block in `.vcov_pair_srs()` with `.build_cluster_matrices()` call
- `tests/testthat/test-variance-taylor.R` — Add 7 unit tests for `.build_cluster_matrices()`
- `tests/testthat/test-variance-srs.R` — Add 1 regression oracle test for SRS refactor
