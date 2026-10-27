# Changelog: test/brr-mse-scale-tolerance

**Branch:** `test/brr-mse-scale-tolerance`
**Status:** Complete
**Date:** 2026-10-27

## Summary

Refs #290. Two test-hygiene gaps in `test-variance-replicate.R`, both
recorded as findings N1 and N2 of the replicate-oracle arc.

Three BRR oracle blocks passed `mse = TRUE` to `survey::svrepdesign()` and
nothing to `as_survey_replicate()`. They agreed only because the
constructor's default is `TRUE`, which breaks rule 1 of the oracle rule in
`.claude/rules/testing-surveycore.md`. The issue names two blocks. A parse
of the file found a third with the same breach, "get_means() BRR scale
formula 1/n_rep is correct for n_rep != 4", and it is fixed here too.

Three assertions of surveycore's stored scale carried no `tolerance`, where
every assertion of `survey`'s stored scale carries `tolerance = 1e-8`.

**No behaviour changes.** Test files only. Nothing under `R/` changed.

## Files Modified

- `tests/testthat/test-variance-replicate.R` — three constructor calls gain
  `mse = TRUE`; three stored-scale assertions gain `tolerance = 1e-8`

## Changes

- Pass `mse = TRUE` to `as_survey_replicate()` in the blocks "get_means()
  replicate SE matches survey::svymean() — BRR design", "get_totals()
  replicate SE matches survey::svytotal() — BRR design" and "get_means()
  BRR scale formula 1/n_rep is correct for n_rep != 4", matching the value
  each block passes to `survey`
- Add `tolerance = 1e-8`, the SE/variance row, to the stored-scale
  assertions in "get_means() replicate SE matches survey::svymean() — JK2
  design", "as_survey_replicate() stores scale = 4/n_rep for
  successive-difference" and "as_survey_replicate() stores scale = 4/n_rep
  for ACS"

## Verification

- Counted with the R parser, not `grep`: after the change, no `test_that()`
  block passes `mse` to `svrepdesign()` and omits it from
  `as_survey_replicate()`, and no `expect_equal()` on a stored `scale`
  lacks a `tolerance`
- `test-variance-replicate.R`: 51 blocks and 348 expectations pass before
  and after, with 1 warning both times
- With `mse = FALSE` passed to `as_survey_replicate()` in the first BRR
  block, the block fails on the SE (0.06120 against 0.06143) and both
  confidence bounds, and the point estimate still passes. The file was
  then restored.
- `air format --check` passes on the whole file
