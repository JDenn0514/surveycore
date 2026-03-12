# Changelog: Domain Info Line in Print Methods

**Branch:** `feature/print-domain-info`
**Date:** 2026-03-03

## Summary

All five `print()` methods now surface a `Domain: <n> of <N> rows` line when
`surveytidy::filter()` has been applied to a survey design object. The line
appears after the sample size line and before the `Groups:` line.

## Changes

### `R/methods-print.R`

- Added `.print_domain_info()` internal helper that reads
  `SURVEYCORE_DOMAIN_COL` from `@data` and emits a `cli_text()` line when
  present; returns `invisible(NULL)` silently when the column is absent.
- For `survey_twophase`, uses Phase 2 row counts (`x@variables$subset` mask)
  to match what analysis functions estimate.
- Added `.print_domain_info(x)` call site in all five print methods:
  `survey_taylor`, `survey_srs`, `survey_replicate`, `survey_twophase`,
  `survey_nonprob`.

### `tests/testthat/test-methods-print.R`

- Added `expect_false(SURVEYCORE_DOMAIN_COL %in% names(d@data))` to existing
  default-output snapshot tests (1, 7, 10, 18) to document the no-domain
  invariant explicitly.
- Added test blocks 28–36 for domain info line behaviour:
  - 28: `survey_taylor` domain line present (snapshot)
  - 29: `survey_taylor` domain count excludes NAs (snapshot)
  - 30: `survey_taylor` domain line before groups line (snapshot)
  - 31: `survey_srs` domain line present (snapshot)
  - 32: `survey_replicate` domain line present (snapshot)
  - 33: `survey_twophase` domain line present — Phase 2 counts (snapshot)
  - 34: `survey_nonprob` default output — net-new baseline (snapshot)
  - 35: `survey_nonprob` domain line present (snapshot)
  - 36: `survey_taylor` zero rows in domain (snapshot)
