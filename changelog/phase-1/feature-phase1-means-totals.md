# feat(analysis): implement get_means() and get_totals()

**Date**: 2026-02-25
**Branch**: feature/phase1-means-totals
**Phase**: Phase 1

## Changes

- Implement `get_means()` — weighted mean estimation for all five survey
  design types (taylor, replicate, srs, twophase, calibrated) with full
  variance support (`se`, `ci`, `var`, `cv`, `moe`, `deff`), group/domain
  estimation, metadata-driven labelling, and AAPOR small-cell warnings.
- Implement `get_totals()` — weighted total estimation in two modes:
  variable mode (estimate population-level total for a numeric column with
  `n` column) and population-size mode (no variable → estimate population
  size, no `n` column).
- Remove Phase 0 stubs for `get_means()` and `get_totals()` from
  `R/06-variance-dispatch.R`; the full Phase 1 implementations now live in
  `R/11-analysis-means.R`.
- Fix CV calculation: `cv = se / estimate` (ratio), not `se / estimate * 100`
  (was incorrectly scaled as a percentage in the shared helper).
- Switch `.degf()` to return `Inf` for all design types (normal approximation
  CI), matching `survey::confint.svystat()` default. Finite-df correction
  only applies when users pass `df=` explicitly to the survey package.
- Update existing oracle tests in `test-variance-taylor.R`,
  `test-variance-replicate.R`, `test-variance-srs.R`, and
  `test-variance-twophase.R` to use the new `variance = c("se", "ci")` API
  and add CI bound assertions.
- Archive old Phase 0.75 plan files to `plans/archive/`.
- Update `test-constructors.R` and `test-analysis-helpers.R` to reflect the
  new API and corrected CV formula.

## Files Modified

- `R/11-analysis-means.R` (new) — full `get_means()` and `get_totals()` implementations with all cell helpers and dispatchers
- `R/06-variance-dispatch.R` — remove Phase 0 stubs; leave stub comment pointing to new file
- `R/09-analysis-helpers.R` — fix `cv = se / estimate` (remove ×100); switch `.degf()` to return `Inf` for all designs
- `tests/testthat/test-analysis-means.R` (new) — 31 test blocks covering happy paths, all design types, group estimation, domain estimation, error paths, edge cases, and oracle tests
- `tests/testthat/test-analysis-totals.R` (new) — 27 test blocks covering both modes (variable and population size), all design types, group/domain estimation, error paths, and oracle tests
- `tests/testthat/_snaps/analysis-means.md` (new) — snapshot baselines for `get_means()` error messages
- `tests/testthat/_snaps/analysis-totals.md` (new) — snapshot baselines for `get_totals()` error messages
- `tests/testthat/test-analysis-helpers.R` — update `.degf()` tests to expect `Inf`; update CV test expectation
- `tests/testthat/test-constructors.R` — update `get_means()`/`get_totals()` calls to new API (`variance = "se"`, `meta()`, `[[1L]]` indexing)
- `tests/testthat/test-variance-taylor.R` — add `variance = c("se", "ci")` and CI bound assertions
- `tests/testthat/test-variance-replicate.R` — add `variance = c("se", "ci")` and CI bound assertions
- `tests/testthat/test-variance-srs.R` — add `variance = c("se", "ci")` and CI bound assertions
- `tests/testthat/test-variance-twophase.R` — add `variance = c("se", "ci")` and CI bound assertions
- `tests/testthat/test-variance-dispatch.R` — deleted (stubs removed; dispatch tests now in analysis-means/totals files)
- `man/get_means.Rd` — regenerated for new full API
- `man/get_totals.Rd` — regenerated for new full API
- `man/get_freqs.Rd` — minor regeneration
- `man/meta.Rd` — minor update
- `plans/phase-1-implementation-plan.md` — mark PR 3 as complete
- `plans/archive/aapor-compliance-review.md` (new) — archived
- `plans/archive/implementation-plan-phase-0.75.md` (new) — archived
- `plans/archive/phase-0.75-formal-specification.md` (new) — archived
- `CLAUDE.md` — update status notes
