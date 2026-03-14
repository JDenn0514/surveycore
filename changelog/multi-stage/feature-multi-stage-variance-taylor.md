# refactor(variance): use .build_cluster_matrices() in Taylor variance engine

**Date**: 2026-03-13
**Branch**: feature/multi-stage-variance-taylor
**Phase**: Multi-stage

## Changes
- Refactor `.taylor_build_inputs()` to use `.build_cluster_matrices()`
  instead of inline matrix-building code; now returns n x k matrices
  for k-stage designs (previously always n x 1)
- Refactor `.vcov_pair_taylor()` to use `.build_cluster_matrices()`
  instead of duplicated inline cluster/strata/FPC block
- Remove `# nocov start/end` markers from `.svy_multistage()` multi-stage
  recursion path (lines 141-157); path is now exercisable via
  multi-stage designs with FPC
- Preserve `.svy_onestrat()` `# nocov` markers (different unreachable
  branches)
- sampsize is now computed from the full dataset before na.rm filtering,
  matching survey package semantics
- Add regression oracle test confirming single-stage NHANES values
  unchanged after refactor
- Add shape tests for `.taylor_build_inputs()` output dimensions
  (1-stage and 2-stage)
- Add multi-stage oracle tests (2-stage no FPC) comparing get_means()
  and get_totals() against survey::svymean()/svytotal()
- Add na.rm semantics test for multi-stage designs

## Files Modified
- `R/variance-taylor.R` — Refactor `.taylor_build_inputs()` and
  `.vcov_pair_taylor()` to use `.build_cluster_matrices()`; remove
  `# nocov` from `.svy_multistage()` multi-stage path
- `tests/testthat/test-variance-taylor.R` — Add 7 new tests (regression
  oracle, shape tests, multi-stage oracle, na.rm semantics)
