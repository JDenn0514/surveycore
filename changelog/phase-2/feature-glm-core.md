# feature/glm-core — Phase 2: survey_glm_fit + survey_glm() + Variance Engine

**Branch:** `feature/glm-core`
**Date:** 2026-03-08

## Summary

Implements the core of Phase 2 (survey-weighted GLM): the `survey_glm_fit`
S7 class, the `survey_glm()` constructor, and the full Binder (1983) sandwich
variance engine for all five design classes. Also upgrades `.degf()` from the
old `Inf` stub to real design-based degrees of freedom, and adds the shared
`.glm_confint()` helper used by PR 3 and PR 4.

## Changes

### `R/glm.R` (new)

New file containing:

- **`survey_glm_fit`** — S7 class with 16 properties (`coefficients`, `vcov`,
  `fitted_values`, `residuals`, `weights`, `design`, `degf`, `family`,
  `formula`, `null_deviance`, `deviance`, `df_null`, `df_residual`,
  `converged`, `call`, `fit_`) and a 7-condition S7 validator.
- **`survey_glm()`** — Constructor for survey-weighted GLM. Steps 1–6 per
  spec §II–IV:
  - Step 1: Input validation — formula/response-predictors interface,
    `cbind()` LHS rejection, response/predictor existence checks, design
    variable warnings
  - Step 2: Domain extraction via `.apply_domain()`
  - Step 3: Weight validation (NA and non-positive)
  - Step 4: Weighted GLM fit via `stats::glm()` with `do.call()` to avoid
    symbol-lookup issues; `binomial()`/`quasibinomial()` wrapped in
    `suppressWarnings()`
  - Step 5: Design-based variance via `.glm_vcov_dispatch()`
  - Step 6: Degrees of freedom via `.glm_degrees_of_freedom()` and
    `survey_glm_fit()` assembly
- **`.glm_score()`** — Per-observation score matrix (n × p) for the sandwich:
  `u_i = w_i * x_i * e_i` using working residuals (correct for all families).
- **`.glm_sandwich_vcov()`** — Assembles bread · meat · bread.
- **`.taylor_var_score_matrix()`** — p × p meat matrix for Taylor designs via
  the existing `.svy_recvar()` machinery (no new variance code).
- **`.twophase_var_score_matrix()`** — p × p meat matrix for twophase designs
  using the polarization identity: `Cov(A,B) = (Var(A+B) - Var(A) - Var(B)) / 2`.
- **`.glm_replicate_vcov()`** — Replicate-weight variance: refit per replicate,
  accumulate `scale * Σ rscales_r * d_r d_r'`; non-converging replicates warn
  with `surveycore_warning_glm_convergence` and use zero deviation.
- **`.glm_srs_vcov()`** — SRS/calibrated sandwich using the full p × p sample
  covariance of the score matrix (off-diagonal terms preserved).
- **`.glm_vcov_dispatch()`** — Routes to the correct variance path based on
  design class (`survey_taylor` → Taylor; `survey_twophase` → twophase;
  `survey_replicate` → replicate; `survey_srs`/`survey_nonprob` → SRS).
- **`.glm_degrees_of_freedom()`** — Clamped design df with
  `surveycore_warning_insufficient_df` when `degf_raw - (p - 1) <= 0`.

### `R/utils.R`

Added **`.glm_confint()`** — shared CI helper used by both
`confint.survey_glm_fit()` (PR 3) and `clean()` (PR 4). Computes:
`estimate ± qt((1 + level) / 2, df = max(1, degf - (p - 1))) * se`.
Single implementation guarantees numerical identity between the two callers.

### `R/analysis-helpers.R`

Updated **`.degf()`** from returning `Inf` (placeholder) to real
design-based degrees of freedom, matching `survey::degf()`:

| Design | Formula |
|---|---|
| `survey_taylor` | `Σ(n_h - 1)` via `.degf_taylor()` |
| `survey_replicate` | `R - 1` (R = replicate columns) |
| `survey_twophase` | Phase-1 Taylor df |
| `survey_srs` / `survey_nonprob` | `n - 1` |

All return values are clamped to `max(1, ...)`.

### `R/analysis-freqs.R`, `R/analysis-means.R`, `R/analysis-ratios.R`, `R/analysis-totals.R`

Changed `degf <- .degf(design)` to `degf <- Inf` (hardcoded normal
approximation). Phase 1 analysis functions use the normal approximation to
match `survey::svymean()` / `survey::svytotal()` defaults. Now that `.degf()`
returns finite values, the hardcoded `Inf` makes the intent explicit and keeps
Phase 1 CI behavior unchanged.

### `tests/testthat/test-glm.R` (new)

Comprehensive test suite for `survey_glm()`:

- Happy-path tests: basic Gaussian fit, formula vs programmatic interface
  identity (`1e-15`), `lapply()` state isolation, intercept-only model,
  factor predictor, interaction terms, NA handling with `na.omit`,
  binomial family, domain estimation
- All 15 constructor error/warning classes from spec §4.7, using the dual
  pattern (`class=` + `expect_snapshot(error = TRUE)`) for user-facing errors
  and `class=` only for S7 validator conditions
- All 7 S7 validator conditions
- Section 9.4 edge cases: `na.action = na.fail` with NAs, insufficient df
  clamping, `@groups` warning
- `test_glm_fit_invariants()` called as first assertion in every constructor
  test block

### `tests/testthat/test-analysis-helpers.R`

Updated `.degf()` test blocks to expect finite design-based values instead
of `Inf`. Added assertions that returned values are `>= 1` and finite.

### `tests/testthat/_snaps/glm.md` (new)

Snapshot file for GLM constructor error messages. Covers all `expect_snapshot(error = TRUE)` calls in `test-glm.R`.

### `plans/impl-phase-2.md`

Marked PR 2 (`feature/glm-core`) as `[x]` complete.

### `NAMESPACE`, `man/survey_glm.Rd`, `man/survey_glm_fit.Rd`, `man/*.Rd` (updated)

Generated by `devtools::document()`. New `survey_glm` and `survey_glm_fit`
exports added to NAMESPACE; existing constructor Rd files updated.

### `_pkgdown.yml`

Added `survey_glm` and `survey_glm_fit` to the pkgdown reference index.
