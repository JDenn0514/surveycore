# chore/ropensci-srr-distribution — rOpenSci srr Compliance & pkgcheck Green

**Branch:** `chore/ropensci-srr-distribution`
**Date:** 2026-03-27

## Summary

Completes rOpenSci software peer review submission prep. Distributes srr
compliance tags across source files (away from the central `srr-stats-standards.R`),
fixes the `data.R` roxygen parser error that caused an `srr_stats_pre_submit()`
failure, adds edge-case and GLM compliance tests, adds the `quiet=` parameter
to `survey_glm()`, adds `plot.survey_glm_fit()`, and fixes Unicode characters
in roxygen docs that caused LaTeX PDF warnings. After these changes
`pkgcheck::pkgcheck()` reports "AWWW — mind-blowing code" (all blockers cleared).

## Changes

### `R/srr-stats-standards.R`
- Fixed `data.R:100` brace-counting parser error: converted `acs_pums_wy`
  `@format` block from `\describe{}`/`\item{}{}` LaTeX markup to markdown
  list; collapsed 80 identical replicate-weight entries into one sentence.
- Removed 28 duplicate `@srrstats` tags that had been copied to their
  canonical source files in previous passes. Count returns to 108 complied +
  42 N/A.

### `R/core-validators.R`
- Added `@srrstats` block: G2.0, G2.1, G2.1a, G2.13, G2.14a, G2.15
  (input validation standards).

### `R/analysis-helpers.R`
- Added `@srrstats` block: EA2.4, EA2.6, EA3.0–EA3.1, EA4.0–EA4.2,
  EA5.2–EA5.3, EA6.0–EA6.0e, EA4.1 (analysis output standards).

### `R/glm.R`
- Added `@srrstats` block: RE1.0–RE2.4b, RE3.0–RE3.3, RE4.0, RE5.0
  (regression function standards).
- Added `quiet =` parameter to `survey_glm()` to suppress convergence
  warnings (RE3.1 compliance).
- Fixed Unicode chars in roxygen: `W̃X)⁻¹` → `WX)^(-1)`, `n × p` → `n x p`,
  `p × p` → `p x p`.

### `R/glm-methods.R`
- Added `@srrstats` block: RE4.2–RE4.18, RE6.0–RE6.2, RE7.3
  (regression method standards).
- Added `plot.survey_glm_fit()` method (RE6.0–RE6.2 compliance): dot-and-
  whisker coefficient plot with design-based Wald CIs; registered via
  `registerS3method()` in `.onLoad()`.

### `R/analysis-corr.R`
- Fixed Unicode: `−1` (U+2212) → `-1` (ASCII) in CI bounds description.

### `R/analysis-totals.R`
- Fixed Unicode: `Σ w_i` and `Σ w_i × x_i` → ASCII equivalents in `@param x`.

### `tests/testthat/test-srr-compliance.R` *(new file)*
- Added `@srrstats` block: G5.3, G5.8–G5.8d, G5.9–G5.9a, G5.10, G5.12,
  RE7.0–RE7.2 (testing standards).
- Added edge-case tests: zero-length data, unsupported column types, all-NA
  outcomes, singular model matrix, noise susceptibility, parameter recovery,
  row-name preservation, `plot.survey_glm_fit()`, `quiet=`, extended tests.

### `.github/CONTRIBUTING.md`
- Added "Extended tests" section documenting `SURVEYCORE_EXTENDED_TESTS=true`
  activation (G5.10, G5.12 compliance).

### `.github/workflows/pkgcheck.yaml` *(new file)*
- Added pkgcheck GitHub Actions workflow for automated rOpenSci compliance CI.

### `codemeta.json` *(new file)*
- Added CodeMeta metadata file (rOpenSci submission requirement).

### `DESCRIPTION`, `inst/CITATION`, `README.md`
- Added URL, BugReports, and citation fields for rOpenSci submission.

### `R/zzz.R`, `R/core-constructors.R`
- Minor updates for S3 method registration and constructor compatibility.

### `man/` *(regenerated)*
- Updated `acs_pums_wy.Rd`, `get_corr.Rd`, `get_totals.Rd`, `survey_glm.Rd`,
  `survey_glm_fit.Rd`, `as_survey.Rd`, `as_survey_replicate.Rd`,
  `as_survey_twophase.Rd`, `get_diffs.Rd` from roxygen source changes.

### `archive/get_diffs/`, `plans/` cleanup
- Archived completed get_diffs plan files; added future/pairwise spec stubs.
