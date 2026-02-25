# Changelog: feature/phase1-meta-helpers

**PR:** Phase 1 PR 1
**Branch:** `feature/phase1-meta-helpers`
**Date:** 2026-02-25

## Summary

Adds the shared infrastructure required by all six Phase 1 analysis functions:
the `meta()` generic, the `survey_result` base class, and the shared internal
helpers in `R/09-analysis-helpers.R`.

## New files

- `R/09-meta.R` — `meta()` generic + `meta.survey_result()` method +
  `print.survey_result` S3 method
- `R/09-analysis-helpers.R` — seven meta-key constants (`FREQS_SINGLE_META_KEYS`,
  `FREQS_MULTI_META_KEYS`, `MEANS_META_KEYS`, `TOTALS_META_KEYS`,
  `CORR_META_KEYS`, `QUANTILES_META_KEYS`, `RATIOS_META_KEYS`) and ten shared
  internal helpers (`.resolve_groups()`, `.apply_domain()`, `.build_meta()`,
  `.make_result_tibble()`, `.validate_shared_args()`, `.apply_name_style()`,
  `.check_unsupported_class()`, `.add_variance_cols()`, `.degf()`,
  `.degf_taylor()`)
- `tests/testthat/test-analysis-helpers.R` — 54 unit tests across 9 categories

## Modified files

- `tests/testthat/helper-test-data.R` — added `n_respondents` check to
  `test_result_invariants()`
- `_pkgdown.yml` — added `meta` to the "Estimation" reference section

## New exports

- `meta()` — generic accessor for survey result metadata
- `print.survey_result` — S3 print method for survey result objects
