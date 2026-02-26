# feat(analysis): implement get_quantiles() — survey-weighted quantile estimation

**Date**: 2026-02-25
**Branch**: feature/phase1-quantiles
**Phase**: Phase 1

## Changes

- Implement `get_quantiles()` using the Woodruff (1952) linearization method for all five design classes (`survey_srs`, `survey_taylor`, `survey_replicate`, `survey_calibrated`, `survey_twophase`)
- Vendor `.last()` and `.wtd_qs()` from `survey:::.last()` and `survey:::qs()` (GPL-3 compatible); attributed in `VENDORED.md`
- Support multiple `probs` values in a single call; output column `quantile` uses labels like `"p25"`, `"p50"`, `"p75"`
- Support grouped estimation (via `@groups`), domain filtering, and confidence interval methods (`mean`, `beta`, `xlogit`, `asin`, `score`)
- Add `na.rm`, `vartype`, `level`, `deff`, and `keep_vars` arguments consistent with the rest of the Phase 1 API
- Add oracle tests comparing against `survey::svyquantile()` for Taylor, replicate, and SRS designs
- Update `@seealso` cross-references in all other Phase 1 analysis functions to include `get_quantiles()`
- Register `get_quantiles` in `_pkgdown.yml` and export in `NAMESPACE`

## Files Modified

- `R/13-analysis-quantiles.R` — new file: `get_quantiles()` implementation with Woodruff helpers
- `tests/testthat/test-analysis-quantiles.R` — new file: happy path, error paths, edge cases, oracle tests
- `tests/testthat/_snaps/analysis-quantiles.md` — new file: CLI error message snapshots
- `man/get_quantiles.Rd` — new file: generated documentation
- `man/get_corr.Rd`, `man/get_freqs.Rd`, `man/get_means.Rd`, `man/get_totals.Rd`, `man/meta.Rd` — updated `@seealso` to include `get_quantiles()`
- `NAMESPACE` — export `get_quantiles`
- `VENDORED.md` — add Woodruff quantile helpers attribution table
- `_pkgdown.yml` — add `get_quantiles` to analysis functions reference
- `plans/phase-1-implementation-plan.md` — mark PR 5a complete
