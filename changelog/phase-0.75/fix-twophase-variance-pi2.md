# fix(variance): correct pi2 in two-phase Phase 1 variance formula

**Date**: 2026-03-09
**Branch**: fix/twophase-variance-pi2
**Phase**: Phase 0.75

## Changes

- Fix `R/variance-twophase.R` `.twophase_phase1_var()`: replace incorrect
  row-level Phase 2 fraction (`pi2_agg`) with the PSU-level stratum sampling
  fraction (survey's `usu` = `n_Ph2_PSU_s / n_Ph1_PSU_s`), resolving ~2×
  variance underestimation for `method = "approx"` and `"full"` designs
- When `strata2` is specified, compute `pi2_agg` per Phase 2 stratum
  (`n_Ph2_PSU_in_strata2 / n_Ph1_PSU_in_strata2`) rather than per Phase 1
  stratum — matches survey's `usu` formula for the stratified Phase 2 case
- Remove the now-unused `pi2` parameter from `.twophase_phase1_var()`; remove
  the corresponding `.compute_phase2_probs()` call from `.twophasevar()` (the
  row-level pi2 is still used correctly in `.twophase_build_inputs()` for
  calibrated weights / point estimates)
- Update three unit tests that called `.twophase_phase1_var()` directly with
  the old 5-argument signature to the new 4-argument signature
- Mark `plans/investigation-twophase-variance.md` as fixed

## Files Modified

- `R/variance-twophase.R` — bug fix in `.twophase_phase1_var()` and
  `.twophasevar()` (pi2 parameter removed; usu computation added)
- `tests/testthat/test-variance-twophase.R` — update three direct
  `.twophase_phase1_var()` calls to new signature
- `plans/investigation-twophase-variance.md` — status updated to "Fixed"
