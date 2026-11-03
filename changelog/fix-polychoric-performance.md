# Changelog: fix/polychoric-performance

**Branch:** `fix/polychoric-performance`
**Status:** Complete
**Date:** 2026-08-27

## Summary

Fixes #177: `get_corr(method = "polychoric")` was ~247x slower than
`polycor::polychor()` on the same data (29.69 s vs 0.12 s on a 6x7 table,
n = 300). The result was correct; only the speed was wrong.

Three changes, each verified bit-identical to the old code before
implementation (all reported estimates, SEs, and CI bounds reproduce the
baseline digit for digit):

1. **Vectorised CDF grid.** The scalar `.corr_bivnorm_cdf()` wrapper made
   168 separate `pbivnorm` entries per log-likelihood evaluation — ~55% of
   the run was the wrapper's per-call entry overhead. One vectorised call
   per rho over the threshold grid replaces them.
2. **Lean refit mode.** The influence-function and replicate refits read
   only `$rho`, but each refit still paid a 5-point objective probe (5 of
   16 evaluations) and a sparse-cell count it discarded. A `refit = TRUE`
   internal argument skips both.
3. **Delta refit setup.** Each of the n influence refits rebuilt thresholds
   and cell counts from all n rows — O(n^2) across the loop. A perturbation
   touches one level sum per margin and one cell; the delta path recomputes
   only those, with the same accumulation order, so the results are
   bit-identical.

Measured after the fix: the 6x7 benchmark runs in 0.99 s (30x), and the two
slow polychoric test files fell from 355.4 s to 77.5 s. All existing test
tolerances are untouched. Follow-ups (refit dedup by cell/weight key, and
an analytic influence function) are out of scope and tracked separately.

## Files Modified

- `R/analysis-corr-latent.R` — added `.corr_bivnorm_cdf_grid()`,
  `.corr_cell_prob_matrix()`, `.corr_polychoric_fit_core()`,
  `.corr_polychoric_influence_setup()`, `.corr_polychoric_delta_refit()`,
  and `.corr_influence_pc6_abort()`; deleted `.corr_bivnorm_cdf()`;
  rewrote `.corr_polychoric_loglik()` and `.corr_count_sparse_cells()`
  over the grid helpers; added `refit = FALSE` to the two MLE functions;
  `.corr_estimate_thresholds()` also returns its per-level weight sums
- `tests/testthat/test-analysis-corr-latent-primitives.R` — six new tests:
  grid precedence rules, grid vs scalar reference, cell-probability sums,
  sparse-cell parity, `refit = TRUE` identity, and the delta refit pinned
  `expect_identical()` against a brute-force full rebuild
- `tests/testthat/_snaps/analysis-corr-latent-primitives.md` — one snapshot
  header updated (`.corr_polychoric_mle()` → `.corr_polychoric_fit_core()`);
  message and error class unchanged
- `plans/implementation-plan-polychoric-performance.md` — the implementation
  plan, including the baseline measurements and the bit-identity
  verification record

## Changes

- Evaluate the polychoric bivariate-normal CDF grid in one vectorised
  `pbivnorm` call per rho instead of four scalar calls per cell
- Skip the objective probe and the sparse-cell count in influence and
  replicate refits (`refit = TRUE`), which consume only `$rho`
- Delta-update thresholds and cell counts across influence refits instead
  of rebuilding them from all n rows per refit
- Pin the refit paths bit-identical to the full rebuild in tests
