# Changelog: fix/collection-bind-snapshot-vctrs-hash

**Branch:** `fix/collection-bind-snapshot-vctrs-hash`
**Status:** Complete
**Date:** 2026-08-20

## Summary

Fixes the R-CMD-check failure on `develop` (run 32404634951). The C14 test in
`test-survey-collection-dispatch.R` snapshots an error message from
`dplyr::bind_rows()`. That message embeds a vctrs factor hash (for example
`<factor<38051>>`). The hash changed with vctrs 0.7.3, so the snapshot could
never match on CI. No package code changed behavior — the typed error class
`surveycore_error_collection_bind_type_mismatch` still fires correctly.

Per `.claude/rules/testing-standards.md`, an error whose text cannot be made
stable is tested with `expect_error(class = ...)` only. The snapshot is
removed; the typed class check stays.

## Files Modified

- `tests/testthat/test-survey-collection-dispatch.R` — removed the
  `expect_snapshot()` call from the C14 test; added a comment that explains
  why no snapshot exists
- `tests/testthat/_snaps/survey-collection-dispatch.md` — removed the stale
  C14 snapshot block

## Changes

- Dropped the environment-dependent snapshot of the bind-type-mismatch error;
  the `expect_error(class = "surveycore_error_collection_bind_type_mismatch")`
  assertion remains as the regression test for this error path
