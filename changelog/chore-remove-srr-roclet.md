# Changelog: chore/remove-srr-roclet

**Branch:** `chore/remove-srr-roclet`
**Status:** Complete
**Date:** 2026-11-02

## Summary

Removes the rOpenSci `srr` standards machinery. surveycore is not heading for
rOpenSci statistical software review, and `DESCRIPTION` naming
`srr::srr_stats_roclet` made `devtools::document()` fail outright wherever
`srr` was not installed (`there is no package called 'srr'`), as in the cloud
sessions, where `srr` comes from r-universe rather than CRAN.

Dropping the roclet alone would have left 138 `@srrstats`, `@srrstatsNA` and
`@srrstatsVerbose` tags that roxygen2 reports as unknown on every run, the
state `chore/srr-roclet-registration` (#160) fixed. So the tags go too. None
of them produced an Rd file, an export or any runtime code: every block was
`@noRd` and attached to `NULL`. `NAMESPACE` and `man/` are unchanged.

## Files Modified

- `DESCRIPTION` — `Roxygen: list(markdown = TRUE)`; roxygen2's default
  roclets are the `collate`, `namespace` and `rd` set the field named before
- `R/srr-stats-standards.R` — deleted (82 tags, nothing else)
- `R/analysis-helpers.R`, `R/glm.R`, `R/glm-methods.R` — the standalone
  `@srrstats` block removed from each
- `R/core-validators.R` — the `@srrstats` tags removed; the block's own
  description of the validator helpers stays
- `tests/testthat/test-srr-compliance.R` → `tests/testthat/test-edge-conditions.R`
  — renamed, and the `@srrstats` header replaced by a plain comment. Every
  test block is unchanged
- `.claude/scripts/cloud-session-start.sh`, `.claude/scripts/cloud-env-setup.sh`
  — no longer install `srr`

## Changes

- Remove the `srr` roclet and every `srr` standards tag, so
  `devtools::document()` runs without `srr` installed
