# Changelog: refactor/polyserial-loglik-ifelse

**Branch:** `refactor/polyserial-loglik-ifelse`
**Status:** Complete
**Date:** 2026-11-19

## Summary

`.corr_polyserial_loglik()` no longer wraps its two `stats::pnorm()` calls
in `ifelse()`. The `ifelse()` calls set the probability to 1 or 0 at the
`+Inf` and `-Inf` threshold sentinels. `pnorm(Inf)` is exactly 1 and
`pnorm(-Inf)` is exactly 0, so for finite `z` the branches changed nothing.

A polyserial `get_corr()` on a Taylor design with n = 2000 took 23.5 s and
now takes 19.9 s, 15% faster. An Rprof profile put `ifelse()` and
`is.infinite()` at about 17% of the call's time.

**No behaviour changes.** Measured in a scratch comparison against the old
function:

- 2,000 random inputs, varying n, levels, rho, NA values and zero weights:
  `identical()` TRUE on all.
- The whole `get_corr(method = "polyserial")` result at n = 2000:
  `identical()` TRUE.
- 16 edge cases: identical on 14. The two that differ need `z` = `+Inf` in
  the top level or `-Inf` in the bottom level, with rho not 0. The new code
  computes `Inf - Inf = NaN`, and the cell floor catches it.

The public API cannot produce an infinite `z`. `.corr_weighted_standardize()`
turns any infinite input into an all-`NaN` `z`, and the `use` filter drops
`NaN`. A finite input gives `|z_i| <= sqrt(sum(w) / w_i)`, which overflows
only when the largest weight is more than about 1e616 times the smallest.
The function comment now states that `z` must be finite.

The four correlation test files pass. `test-analysis-corr.R` raises the same
9 warnings with and without the change.

## Files Modified

- `R/analysis-corr-latent.R`: `.corr_polyserial_loglik()` computes
  `p_mi` as `stats::pnorm(u_hi) - stats::pnorm(u_lo)`; the comments state
  that `z` must be finite and why
- `changelog/refactor-polyserial-loglik-ifelse.md`: this file

## Changes

- refactor: remove the redundant `ifelse()` calls from the polyserial
  log-likelihood
