# refactor(glm): replace inline FPC block with .build_cluster_matrices()

**Date**: 2026-03-13
**Branch**: feature/multi-stage-glm
**Phase**: Multi-stage

## Changes
- Replace inline cluster/strata/FPC matrix-building block in
  `.taylor_var_score_matrix()` (R/glm.R) with a call to the shared
  `.build_cluster_matrices()` helper, enabling multi-stage Taylor
  variance for GLM models
- Add 2-stage GLM oracle test comparing `survey_glm()` against
  `survey::svyglm()` for coefficients (1e-10) and SEs (1e-8)
- Add smoke test verifying `survey_glm()` accepts multi-stage designs
  without error

## Files Modified
- `R/glm.R` — Replace inline block in `.taylor_var_score_matrix()` with
  `.build_cluster_matrices()` call (SRS-specific FPC reference unchanged)
- `tests/testthat/test-glm.R` — Add multi-stage GLM oracle and smoke tests
