# Spec — corr-nonprob-latent

**Status**: DRAFT
**Target version**: X.Y.Z.9000
**PR range**: PR 1

## Scope

### In

- Relax the PC-7 gate in `.corr_latent_pair()` so that `survey_nonprob` objects
  with `@variables$repweights` non-`NULL` pass through to the variance path.
- Add a `survey_nonprob` branch in the variance dispatch block of
  `.corr_latent_pair()` that routes to `.corr_replicate_variance_latent()` when
  replicate weights are present, and raises
  `surveycore_error_polychoric_design_unsupported` when they are absent.
- Update the `@param design` roxygen2 tag on `get_corr()` to document that
  `survey_nonprob` with replicate weights is now supported for
  `method = "polychoric"` and `method = "polyserial"`.

### Out

- No changes to the Pearson path (`analysis-corr-helpers.R` or
  `analysis-corr.R` logic — only the `@param` docstring update in
  `analysis-corr.R`).
- No changes to `survey_twophase` behavior — it remains unconditionally rejected
  by PC-7.
- No changes to `survey_nonprob` without replicate weights for Pearson — that
  path is unchanged (warn + SRS fallback).
- No new exported functions. No changes to `get_corr()` signature.
- No changes to `survey_replicate` or `survey_taylor` paths.

## Architecture

- **Files touched**:
  - `R/analysis-corr-latent.R` — relax PC-7 gate; add `survey_nonprob` branch
    in variance dispatch
  - `R/analysis-corr.R` — update `@param design` roxygen2 tag only
  - `tests/testthat/test-analysis-corr.R` — new tests for the nonprob latent
    path
- **Functions added**: none
- **Functions modified** (internal behavior change only):
  - `.corr_latent_pair(design, x_col, y_col, method, active_domain, na.rm, conf_level)`
    — PC-7 gate condition and variance dispatch block
- **Class changes**: none

## Function contracts

The only public-facing contract change is in `get_corr()`'s documentation. The
internal function `.corr_latent_pair()` gains a new branch but its signature is
unchanged.

### `get_corr(design, x, ..., group, format, redundant, diagonal, variance, conf_level, n_weighted, decimals, min_cell_n, na.rm, label_values, name_style, method)`

This contract section documents only the items whose behavior changes. All
other argument contracts are unchanged.

- **Signature**: unchanged — no new arguments, no removed arguments
- **Arguments**:
  - `design`: A survey design object inheriting from `survey_base`.
    `method = "polychoric"` and `method = "polyserial"` are now supported for
    `survey_nonprob` designs that supply replicate weights
    (`@variables$repweights` non-`NULL`). `survey_nonprob` designs without
    replicate weights still raise
    `surveycore_error_polychoric_design_unsupported` for latent methods.
    `survey_twophase` continues to raise
    `surveycore_error_polychoric_design_unsupported` for latent methods
    regardless of any properties.
  - All other arguments: unchanged from existing contract.
- **Returns**: unchanged — same `survey_corr` tibble structure regardless of
  the design class, when estimation succeeds.
- **Errors**:
  - `surveycore_error_polychoric_design_unsupported` (PC-7) — fires when:
    (a) `design` is `survey_twophase`, regardless of any properties, or
    (b) `design` is `survey_nonprob` and `@variables$repweights` is `NULL`, or
    (c) `design` is any other unsupported class.
    For case (b), the error must include an `"i"` bullet distinguishing it
    from the `survey_twophase` case and pointing to the remedy:
    `"i" = "Supply bootstrap replicate weights via {.arg repweights} in
    {.fn as_survey_nonprob} to use this method."`. The PC-7 class name and
    the `"x"` bullet text are shared between cases (a) and (b).
  - All other error classes: unchanged.
- **Warnings**: unchanged from existing contract.
- **Edge cases**:
  - `survey_nonprob` with `repweights` non-`NULL` and `method = "polychoric"`:
    routes to the replicate variance path (`.corr_replicate_variance_latent()`),
    same as `survey_replicate`. All PC-8 / PC-12 replicate convergence
    conditions apply.
  - `survey_nonprob` with `repweights` non-`NULL` and `method = "polyserial"`:
    same routing, same convergence conditions.
  - `survey_nonprob` with `repweights = NULL` and any latent method: raises
    `surveycore_error_polychoric_design_unsupported` (no SRS fallback for latent
    methods — unlike the Pearson path, there is no SRS-equivalent latent
    variance).
  - `survey_twophase` with any latent method: raises
    `surveycore_error_polychoric_design_unsupported` (unchanged behavior).
  - All-NA ordinal column, single observed level, < 4 cells: PC-4 and PC-5
    are evaluated once on the full-sample active domain before any replicate
    fitting begins. A per-replicate level shortfall (fewer than 2 levels in
    a single replicate's sub-sample) causes that replicate's MLE to fail
    silently and be counted as NA in `n_failed`, rather than triggering a
    PC-4 abort.
  - `mse = FALSE` on `survey_nonprob` with replicate weights: the latent-
    method replicate variance path always uses MSE form (`mse = TRUE` in
    `.svy_rep_var()`) regardless of the design object's stored `mse` field.
    This matches `survey_replicate` behaviour for the polychoric / polyserial
    paths.
  - Zero-weight replicate: when all in-domain weights for replicate `r` are
    non-positive (≤ 0), the per-replicate MLE fails and is counted as NA in
    `n_failed`, contributing to PC-12 / PC-8 thresholds.
  - `var_z_srs = NA`: the SRS-equivalent variance (used for DEFF) may be
    `NA_real_` when the full-sample or all per-replicate unit-weight MLEs
    fail. This only affects the `deff` variance column — it does not affect
    the main `r`, `se`, or CI columns, which are based on `var_z`.

## Quality gates

- The `nocov` comment on the defensive fallback branch inside the variance
  dispatch block must be removed or updated if `survey_nonprob` is routed there.
  After this change the `survey_nonprob` branch is exercised by tests; the
  remaining `else` (truly unreachable) may keep `# nocov`.
- `test_invariants(design)` is the first assertion in every test block that
  constructs a survey design object.
- All existing `get_corr()` tests continue to pass.
- The `@param design` docstring in `get_corr()` must accurately describe the
  new `survey_nonprob` + replicate weights support for latent methods.

## Pipeline split

recommended — changes numerical behavior of an existing exported function and
touches a methods-heavy variance path.
