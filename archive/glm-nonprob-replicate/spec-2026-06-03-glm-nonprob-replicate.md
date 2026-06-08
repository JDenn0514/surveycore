# Spec — glm-nonprob-replicate

**Status**: DRAFT
**Target version**: X.Y.Z.9000
**PR range**: PR 1

## Scope

### In

- Add a replicate-weight routing branch inside the `survey_nonprob` arm of
  `.glm_vcov_dispatch()`: when `design@variables$repweights` is non-NULL,
  call `.glm_replicate_vcov()`; otherwise warn and call
  `.glm_calibrated_vcov()` (existing behaviour).
- The `surveycore_warning_nonprob_srs_fallback` warning, already present in
  all other analysis functions for the no-repweights path, is now also emitted
  by `survey_glm()` on the no-repweights path.

### Out

- No changes to `get_diffs()`, `get_t_test()`, `get_pairwise()`, or
  `get_anova()`. These functions derive their variance from `survey_glm()` and
  inherit the fix automatically.
- No changes to `survey_glm()` public signature or `survey_glm_fit` S7 class.
- No changes to `.glm_replicate_vcov()` or `.glm_calibrated_vcov()`.
- No changes to `survey_nonprob` class definition or constructor.

## Architecture

- Files touched:
  - `R/glm.R` — add repweights branch to `.glm_vcov_dispatch()`
  - `tests/testthat/test-glm.R` — new tests for the nonprob replicate path
- Functions added: none
- Functions modified:
  - `.glm_vcov_dispatch(fit, design, row_mask, domain_mask)` — internal helper;
    the `survey_nonprob` branch gains a sub-branch that routes to
    `.glm_replicate_vcov()` when `!is.null(design@variables$repweights)` and
    warns + routes to `.glm_calibrated_vcov()` otherwise.
  - `survey_glm(design, formula, ...)` — public behaviour changes because
    `survey_glm()` calls `.glm_vcov_dispatch()`. The new warning is now
    emitted on the no-repweights `survey_nonprob` path.
- Class changes: none

## Function contracts

### `survey_glm(design, formula, ...)`

- **Signature**:
  ```r
  survey_glm(
    design,
    formula = NULL,
    response = NULL,
    predictors = NULL,
    family = stats::gaussian(),
    na.action = stats::na.omit,
    start = NULL,
    etastart = NULL,
    mustart = NULL,
    control = list(),
    quiet = FALSE
  )
  ```

- **Arguments**: unchanged from existing contract. `design` now has fully
  correct variance routing for `survey_nonprob` objects regardless of whether
  replicate weights are present.

- **Returns**: a `survey_glm_fit` S7 object. Class, shape, and slot names are
  unchanged. For a `survey_nonprob` design with non-NULL `repweights`, the
  returned `@vcov` is now computed by the replicate-weight estimator (same
  algorithm used for `survey_replicate`). For a `survey_nonprob` with NULL
  `repweights`, `@vcov` is computed by the SRS calibrated estimator (unchanged
  from existing behaviour).

- **Errors**: all existing error classes apply unchanged. No new error classes
  introduced by this change.

- **Warnings**:
  - `surveycore_warning_nonprob_srs_fallback` — emitted when `design` is a
    `survey_nonprob` with NULL `repweights`. The class name is pre-existing
    (row NB-2 in `plans/error-messages.md`); this is a NEW emission point
    for `survey_glm()`. The exact `cli::cli_warn()` call must use:
    ```r
    cli::cli_warn(
      c(
        "!" = paste0(
          "{.cls survey_nonprob} object has no bootstrap replicate ",
          "weights. Standard errors use an SRS approximation that ",
          "underestimates calibration uncertainty."
        ),
        "i" = paste0(
          "Run {.fn surveywts::create_bootstrap_weights} on this ",
          "design for correct SEs."
        )
      ),
      class = "surveycore_warning_nonprob_srs_fallback"
    )
    ```
    This text is identical to the NB-2 message in all other analysis
    functions. `plans/error-messages.md` row NB-2 must be updated to add
    `survey_glm()` to the "Function" column.

- **Edge cases**:
  - `survey_nonprob` with non-NULL `repweights` (happy path for the new branch):
    `@vcov` matches the numerical output of `.glm_replicate_vcov()` applied
    with the same replicate weight matrix, scale, rscales, and mse settings.
    No warning is emitted.
  - `survey_nonprob` with NULL `repweights` (fallback path): `@vcov` is
    unchanged from current behaviour. `surveycore_warning_nonprob_srs_fallback`
    is emitted exactly once per `survey_glm()` call.
  - `survey_nonprob` with a single replicate weight column: `as_survey_nonprob()`
    rejects this at construction time (error NB-3). This state cannot reach
    `survey_glm()`.
  - `survey_nonprob` with all-zero replicate weights in one replicate: "all-
    zero" means all elements in `repweights[fit_rows, r]` are non-positive
    (≤ 0). When this causes `stats::glm(..., weights = wr)` to fail or
    produce degenerate output, `.glm_replicate_vcov()` uses the zero-deviation
    fallback (replicate deviation treated as zero). Mixed positive/zero weights
    (e.g., `c(1, 0, 0, 2)`) produce a valid refit and are not affected.
  - `survey_nonprob` with `mse = FALSE`: handled by existing
    `.glm_replicate_vcov()` logic; `center` is set to the mean of replicate
    coefficients.
  - Domain estimation (filtered `survey_nonprob` with repweights): `row_mask`
    and `domain_mask` are passed through to `.glm_replicate_vcov()` and
    intersected internally via `fit_rows[domain_mask[fit_rows]]` to ensure
    replicate refitting uses only rows that are both (a) in the active domain
    and (b) included in the main GLM fit. Behaviour is identical to
    `survey_replicate` domain estimation.
  - Design variables guarantee: when `survey_nonprob@variables$repweights`
    is non-NULL, `scale`, `rscales` (a numeric vector of length equal to
    the number of replicate weight columns), and `mse` (logical) are also
    non-NULL, set and validated by `as_survey_nonprob()` at construction
    time. These are required inputs to `.glm_replicate_vcov()`.
  - Empty domain (zero in-domain rows) with repweights: existing
    `surveycore_error_empty_domain` error fires before `.glm_vcov_dispatch()`
    is reached; no change needed.

## Quality gates

- `survey_glm()` on a `survey_nonprob` design with `repweights` must produce
  numerical output (coefficients and `@vcov`) identical to what the same call
  produces on a `survey_replicate` design with the same data, weights,
  repweights, and model formula.
- `survey_glm()` on a `survey_nonprob` design with NULL `repweights` must
  emit `surveycore_warning_nonprob_srs_fallback` and produce the same `@vcov`
  as the current implementation.
- All existing `test-glm.R` tests pass without modification.
- `devtools::check()` 0 errors, 0 warnings, notes reviewed.

## Pipeline split

recommended — numerical behaviour change to `survey_glm()`, which underlies
`get_diffs()`, `get_t_test()`, `get_pairwise()`, and `get_anova()`.
