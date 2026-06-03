# Test-spec — corr-nonprob-latent

## Reference oracle

- `survey_replicate` path: existing `get_corr()` tests on `survey_replicate`
  designs serve as the behavioral oracle. A `survey_nonprob` with replicate
  weights processed through the same `.corr_replicate_variance_latent()` path
  must produce structurally identical output (finite `r`, finite `ci_low` /
  `ci_high`, `ci_low < ci_high`, bounds in `[-1, 1]`).
- No external reference package is required for structural validation; the
  design-based polychoric estimator is implemented from scratch in surveycore.
  Numerical spot-checks compare against `survey_replicate` results on the same
  data to verify routing correctness.

## Datasets

- `make_survey_data(n = 200L, design = "taylor", seed = ...)` with manual
  replicate weight generation and `as_survey_nonprob(..., repweights = ...)` —
  for happy-path and numerical routing tests.
- Inline data frames constructed inside test blocks — for error-path and
  edge-case tests where exact column configurations must be controlled.

## Per-function test plan

### `get_corr()` — latent methods on `survey_nonprob` with replicate weights

#### Happy path — polychoric

- **Scenario**: `survey_nonprob` with `R >= 10` bootstrap replicate weights,
  two ordinal columns (ordered factors with >= 3 levels), `method = "polychoric"`.
- **Dataset**: `make_survey_data(n = 200L, design = "taylor", seed = 101L)`;
  manually add integer ordinal columns (coerce `y1` and `y2` to ordered factor
  with 5 levels); generate `R = 10` replicate weight columns (lognormal
  perturbations of `wt`); construct with `as_survey_nonprob(..., repweights =
  starts_with("repwt_"), type = "bootstrap")`.
- **Assertion set**:
  - `test_invariants(design)` first.
  - Result inherits from `"survey_corr"` (use `test_result_invariants()`).
  - `result$r[[1L]]` is finite and in `[-1, 1]`.
  - `result$ci_low[[1L]]` and `result$ci_high[[1L]]` are finite.
  - `result$ci_low[[1L]] >= -1` and `result$ci_high[[1L]] <= 1`.
  - `result$ci_low[[1L]] < result$ci_high[[1L]]`.
  - `nrow(result) == 1L` for a two-variable input.

#### Happy path — polyserial

- **Scenario**: `survey_nonprob` with `R >= 10` bootstrap replicate weights,
  one ordered-factor column and one numeric column, `method = "polyserial"`.
- **Dataset**: same base data as above; use one ordered-factor column and one
  raw numeric column.
- **Assertion set**: same structural assertions as polychoric happy path above.

#### Happy path — replicate path numerical agreement

- **Scenario**: The same ordinal data built as both a `survey_replicate` and a
  `survey_nonprob` with identical replicate weights and replicate parameters.
  Both are called with `method = "polychoric"`.
- **Purpose**: Confirm that the `survey_nonprob` routing reaches the same
  variance path as `survey_replicate` when the underlying replicate weight
  arrays are identical.
- **Assertion**: `result_nonprob$r[[1L]]` equals `result_rep$r[[1L]]` within
  tolerance 1e-10. `result_nonprob$ci_low[[1L]]` equals
  `result_rep$ci_low[[1L]]` within tolerance 1e-6.

#### Error path — `survey_nonprob` without repweights raises PC-7

- **Scenario**: `survey_nonprob` constructed without `repweights`
  (`@variables$repweights` is `NULL`), called with `method = "polychoric"`.
- **Dual pattern**:
  - `expect_error(..., class = "surveycore_error_polychoric_design_unsupported")`
  - `expect_snapshot(error = TRUE, ...)`
- Repeat for `method = "polyserial"`.

#### Error path — `survey_twophase` still raises PC-7 (regression guard)

- **Scenario**: `survey_twophase` design, `method = "polychoric"`.
- **Assertion**: `expect_error(..., class =
  "surveycore_error_polychoric_design_unsupported")`.
- This is a regression guard confirming the `survey_twophase` branch of PC-7
  was not accidentally removed.

#### Edge case — single replicate weight column raises NB-3 at construction time

- **Scenario**: `as_survey_nonprob(..., repweights = one_column)` with only one
  replicate weight column.
- **Assertion**: construction itself raises
  `surveycore_error_repweights_single`. No latent correlation test needed —
  this is a constructor-level guard, not a `get_corr()` guard. Include only to
  confirm the guard prevents a degenerate `survey_nonprob` from reaching
  `get_corr()`.

#### Edge case — `survey_nonprob` with repweights + `method = "pearson"` is unchanged

- **Scenario**: `survey_nonprob` with replicate weights, `method = "pearson"`
  (default).
- **Assertion**: result is a valid `survey_corr` tibble with finite `r`. This
  confirms that the PC-7 gate relaxation does not accidentally affect the
  Pearson path (which never touches PC-7).

#### Edge case — PC-4 fires through the nonprob latent path

- **Scenario**: `survey_nonprob` with replicate weights; ordinal variable that
  has only one observed level in the active domain (e.g., all values are the
  same integer category).
- **Assertion**: `expect_error(..., class =
  "surveycore_error_polychoric_single_level_ordinal")`. Confirms PC-4 is still
  evaluated after PC-7 passes.

#### Edge case — PC-12 (< 20% replicate convergence failures) produces warning

- **Scenario**: Hard to construct deterministically; skip this edge case via
  `skip("replicate convergence edge case requires contrived weights")` if
  synthetic construction is too brittle. Document as a known gap in the test
  notes.
- Alternative: verify that the `survey_nonprob` path inherits PC-12 / PC-8
  behavior by confirming the same `.corr_replicate_variance_latent()` is called
  (structural test — not a convergence test).

#### Edge case — 0-row active domain passes PC-7 and lets PC-4/PC-5 fire

- **Scenario**: `survey_nonprob` with replicate weights; active domain
  filtered to 0 rows (e.g., via a domain mask that matches nothing).
- **Assertion**: `get_corr()` with a latent method does not raise PC-7;
  instead raises `surveycore_error_polychoric_single_level_ordinal` (PC-4)
  or a similar gate that fires when the active domain contains insufficient
  data. Confirms the PC-7 relaxation does not bypass downstream validation.

#### Edge case — single-row design raises error before latent path

- **Scenario**: `survey_nonprob` constructed from a 1-row data frame with
  replicate weights.
- **Assertion**: An error is raised — either at construction (`as_survey_nonprob()`)
  or at `get_corr()` time. The test verifies that single-row data does not
  silently produce degenerate estimates. Document which layer fires and the
  expected error class.

#### Edge case — all-NA ordinal column fires PC-4 through nonprob latent path

- **Scenario**: `survey_nonprob` with replicate weights; ordinal variable is
  entirely `NA` in the active domain.
- **Dual pattern**:
  - `expect_error(..., class = "surveycore_error_polychoric_single_level_ordinal")`
  - `expect_snapshot(error = TRUE, ...)`
- Confirms PC-4 fires after PC-7 passes on the nonprob path.

## Tolerances

- Point estimates (`r`): 1e-10
- SE / variance: 1e-8
- CI bounds: 1e-6
- Deviations: none

## Profile gates

- [ ] devtools::document() clean
- [ ] devtools::test() all pass
- [ ] devtools::run_examples() all pass
- [ ] R CMD check --as-cran (0 err, 0 warn, notes reviewed)
- [ ] pkgcheck PASS
- [ ] pkgdown::build_site() clean
- [ ] covr::package_coverage() >= 95% (target 98%)
- [ ] CRAN cookbook scan clean (see r-package-profile.md)
