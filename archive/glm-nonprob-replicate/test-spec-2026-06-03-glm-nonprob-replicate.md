# Test-spec — glm-nonprob-replicate

## Reference oracle

- `survey_glm()` called on a `survey_replicate` design constructed from the
  same data, weights, repweights, scale, rscales, and mse settings as the
  `survey_nonprob` under test. Numerical equality of `@vcov` and
  `@coefficients` between the nonprob-replicate path and this oracle is the
  primary numerical assertion.
- `survey_glm()` on a `survey_nonprob` design with NULL repweights (existing
  pre-change behaviour) serves as the regression baseline for the calibrated
  fallback path.

## Datasets

- `make_survey_data(design = "replicate", type = "brr", seed = N)` — primary
  synthetic dataset for happy-path and numerical comparison tests. Provides
  `wt` (calibrated weight) and `repwt_1 … repwt_R` columns (replicate weights).
  Construct the oracle pair as:
  ```r
  df <- make_survey_data(design = "replicate", type = "brr", seed = 1L)
  # Oracle: survey_replicate
  d_rep <- as_survey_replicate(
    df,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "BRR"
  )
  # Under test: survey_nonprob with matching replicate structure
  d_np <- as_survey_nonprob(
    df,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "bootstrap",
    scale = d_rep@variables$scale,
    rscales = d_rep@variables$rscales,
    mse = TRUE
  )
  ```
  The `survey_nonprob` and `survey_replicate` share identical weight/repweight
  arrays so their `@vcov` outputs must agree within tolerance.
- Inline constructions — for edge cases (NULL repweights fallback, domain
  estimation, mse settings) that require atypical structure.

## Per-function test plan

### `survey_glm()` — `survey_nonprob` with replicate weights (new branch)

- **Happy path**:
  - Construct a `survey_nonprob` design from `make_survey_data(design = "replicate", type = "brr", seed = 1)` by registering the replicate weight columns via `as_survey_nonprob()`.
  - Construct a parallel `survey_replicate` design from the same data.
  - Call `survey_glm(nonprob_design, y1 ~ y2)` and `survey_glm(replicate_design, y1 ~ y2)`.
  - Assert: `test_glm_fit_invariants(fit_nonprob)`.
  - Assert: `fit_nonprob@coefficients` equals oracle `fit_replicate@coefficients`, tolerance 1e-10.
  - Assert: `fit_nonprob@vcov` equals oracle `fit_replicate@vcov`, tolerance 1e-8.
  - Assert: no warning of class `surveycore_warning_nonprob_srs_fallback` is emitted.

- **Happy path — multiple predictors**:
  - Same construction as above; formula `y1 ~ y2 + y3`.
  - Assert: `@vcov` is a 3 × 3 matrix; diagonal entries are positive; values
    match oracle tolerance 1e-8.

- **Happy path — binomial family**:
  - Construct `survey_nonprob` with repweights; binary outcome (e.g., `y1 > 0`).
  - Assert `test_glm_fit_invariants(fit)`.
  - Assert `@vcov` is finite and symmetric.

- **Error paths**: no new error classes are introduced. All existing error-class
  tests for `survey_glm()` continue to pass unchanged.

- **Warning path — NULL repweights emits `surveycore_warning_nonprob_srs_fallback`**:
  - Construct a `survey_nonprob` design with `repweights = NULL`.
  - Call `survey_glm(nonprob_no_rep, y1 ~ y2)`.
  - Assert: `expect_warning(..., class = "surveycore_warning_nonprob_srs_fallback")`.
  - Assert: `expect_snapshot(warning = TRUE, ...)` — snapshot must match
    the NB-2 message text in `plans/error-messages.md` verbatim.
  - Assert: the returned fit is a valid `survey_glm_fit` (invariants hold).
  - Assert: `@vcov` diagonal is positive; values match the pre-change
    calibrated-fallback baseline at tolerance 1e-8.

- **Warning path — warning emitted exactly once per call**:
  - Wrap `survey_glm(nonprob_no_rep, y1 ~ y2)` in `withCallingHandlers()` and
    count emissions of `surveycore_warning_nonprob_srs_fallback`.
  - Assert count equals 1L.

- **Edge case — domain estimation with repweights**:
  - Apply `surveytidy::filter()` to the `survey_nonprob` with repweights design
    to create an active domain. Apply the same filter to the oracle
    `survey_replicate` design.
  - Call `survey_glm()` on both.
  - Assert `test_glm_fit_invariants(fit_nonprob)`.
  - Assert `fit_nonprob@vcov` equals oracle `fit_replicate@vcov`, tolerance 1e-8.
  - Assert `@vcov` is finite and positive-definite (all diagonal entries > 0).

- **Edge case — `mse = FALSE` with repweights**:
  - Construct `survey_nonprob` with repweights and `mse = FALSE`.
  - Call `survey_glm()`.
  - Assert `test_glm_fit_invariants(fit)`.
  - Assert `@vcov` is finite; no error thrown.

- **Edge case — `survey_nonprob` with NULL repweights, regression guard**:
  - Construct a `survey_nonprob` with NULL repweights; suppress the warning.
  - Assert: `@vcov` diagonal is positive.
  - Assert: the returned `@vcov` matches the oracle from the reference
    baseline (no regression in the fallback path).

- **Regression smoke — `get_diffs()` inherits nonprob replicate fix**:
  - Construct a `survey_nonprob` with repweights; apply a domain filter to
    create two subgroups.
  - Call `get_diffs(design, y = y1, group = y3_binary)`.
  - Assert: the result has finite `diff` and `se` columns with no
    `surveycore_warning_nonprob_srs_fallback` emitted. This confirms the
    inheritance chain from `survey_glm()` is unbroken.

- **Invariant — `test_glm_fit_invariants(fit)` as first assertion**:
  - Every test block that calls `survey_glm()` and assigns the result must call
    `test_glm_fit_invariants(fit)` as its first non-construction assertion.

## Tolerances

- Point estimates (`@coefficients`): 1e-10
- SE / variance (`@vcov` entries): 1e-8
- CI bounds: 1e-6
- Deviations: none. The numerical comparison between the `survey_nonprob`
  replicate path and the `survey_replicate` oracle is exact up to floating-point
  rounding; 1e-8 tolerance on `@vcov` entries is sufficient.

## Profile gates

- [ ] devtools::document() clean
- [ ] devtools::test() all pass
- [ ] devtools::run_examples() all pass
- [ ] R CMD check --as-cran (0 err, 0 warn, notes reviewed)
- [ ] pkgcheck PASS
- [ ] pkgdown::build_site() clean
- [ ] covr::package_coverage() >= 95% (target 98%)
- [ ] CRAN cookbook scan clean (see r-package-profile.md)
