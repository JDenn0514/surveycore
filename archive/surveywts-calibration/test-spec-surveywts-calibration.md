# Test-spec — surveywts-calibration

---

## Reference oracle

- `survey` package (CRAN), `survey::svymean()`, `survey::svytotal()`,
  `survey::calibrate()`, `survey::rake()`, `survey::SE()`, `survey::weights()`
- Used for numerical accuracy assertions (calibration-adjusted SE within 1e-8
  of survey oracle).
- All oracle tests require `skip_if_not_installed("survey")`.

---

## Datasets

- `nhanes_2017` — numerical accuracy tests for calibrated Taylor variance
  (real design structure, real calibration auxiliary variables)
- `make_survey_data(seed = N)` — all constructor validation tests, structural
  tests, and edge-case tests
- Inline synthetic data — for tests requiring exact control of weights,
  g-factors, or model matrix rank

---

## Per-function test plan

---

### `as_caldata()`

These tests cover the existing implementation, which is not changed by this
run. They are carried forward to ensure no regression.

**Happy paths** (all require no `skip_if_not_installed`):

- Returns a named list with exactly the fields `qr`, `w`, `stage`, `index`
  for valid inputs.
- `w` slot equals `g_weights * sqrt(base_weights)` for a representative input.
- `qr` slot has `$rank` and `$pivot` matching the QR of
  `sqrt(base_weights) * model_matrix`.
- Works with a single-column model matrix (intercept-only calibration).
- Works with all `g_weights` equal to 1.0 (no calibration effect, but caldata
  is valid).
- Works with n = 1 (single observation).
- Rank-deficient `model_matrix` (e.g., a column that is all zeros): no error
  thrown; `qr$rank` is less than `ncol(model_matrix)`.

**Error paths** (dual pattern: `expect_error(class=)` + `expect_snapshot(error=TRUE)`):

- CAL-1: `base_weights` contains `NA` → `surveycore_error_caldata_weights_missing`
- CAL-1: `base_weights` contains `Inf` → `surveycore_error_caldata_weights_missing`
- CAL-2: `base_weights` contains a zero → `surveycore_error_caldata_weights_nonpositive`
- CAL-2: `base_weights` contains a negative → `surveycore_error_caldata_weights_nonpositive`
- CAL-2: `base_weights` has length 0 → `surveycore_error_caldata_weights_nonpositive`
- CAL-3: `g_weights` contains `NA` → `surveycore_error_caldata_gweights_missing`
- CAL-4: `g_weights` contains a non-positive value →
  `surveycore_error_caldata_gweights_nonpositive`
- CAL-5: `g_weights` has different length than `base_weights` →
  `surveycore_error_caldata_gweights_length_mismatch`
- CAL-6: `g_weights * sqrt(base_weights)` produces near-zero product →
  `surveycore_error_caldata_weights_near_zero`
- CAL-7: `nrow(model_matrix) != length(base_weights)` →
  `surveycore_error_caldata_dimension_mismatch`
- CAL-8: `model_matrix` has 0 columns →
  `surveycore_error_caldata_empty_model_matrix`
- CAL-9: `model_matrix` contains `NA` →
  `surveycore_error_caldata_model_matrix_invalid`
- CAL-9: `model_matrix` contains `Inf` →
  `surveycore_error_caldata_model_matrix_invalid`

**Edge cases**:

- Empty `base_weights` (length 0): triggers CAL-2 before any other check.
- All-one `g_weights`: valid; returned `w` equals `sqrt(base_weights)`.

---

### `as_survey()` — `calibration =` parameter

All tests in this section use `make_survey_data(seed = N)` unless otherwise
noted. Every test that creates a survey design object must call
`test_invariants(design)` as the first assertion.

**Happy paths**:

- `calibration = NULL` (default): `@calibration` is `NULL`.
  `test_invariants(design)` must pass. Confirm `is.null(design@calibration)`.

- `calibration = list(cd)` where `cd` is a valid `as_caldata()` output with
  `length(cd$w) == nrow(data)`: `@calibration` is identical to `list(cd)`.
  `test_invariants(design)` must pass.

- `calibration = list(cd1, cd2)` (two valid caldata elements): `@calibration`
  is identical to `list(cd1, cd2)`. `test_invariants(design)` must pass.

- `calibration = list()` (empty list): `@calibration` is `list()`.
  `test_invariants(design)` must pass. No error thrown.

- Stored value is identical to a caldata element assigned post-construction via
  `design@calibration <- list(cd)`. Confirm both approaches produce the same
  `@calibration` value (`expect_identical`).

**Error paths** (dual pattern: `expect_error(class=)` + `expect_snapshot(error=TRUE)`):

- CAL-15: `calibration` is a bare caldata list (not wrapped in a `list()`) →
  `surveycore_error_calibration_not_list`
- CAL-15: `calibration` is a numeric vector → `surveycore_error_calibration_not_list`
- CAL-15: `calibration` is a data frame → `surveycore_error_calibration_not_list`
- CAL-16: `calibration = list(cd)` where `cd` is missing a required field
  (e.g., `list(qr = qr(matrix(1)), w = 1, stage = 0L)` — no `index`) →
  `surveycore_error_caldata_invalid_element`
- CAL-16: `calibration = list(cd)` where `cd` is `NULL` →
  `surveycore_error_caldata_invalid_element`
- CAL-16: `calibration = list(cd)` where `length(cd$w) != nrow(data)` →
  `surveycore_error_caldata_invalid_element`
- CAL-16: `calibration = list(valid_cd, bad_cd)` where only the second element
  is malformed → `surveycore_error_caldata_invalid_element`

**Edge cases**:

- `calibration = list()`: no error; `@calibration` is `list()`.
- Inline caldata passed directly (not wrapped): triggers CAL-15.
- `calibration` with a list element that is a list with all four required
  fields but `length(cd$w)` off by 1 → CAL-16.

---

### `as_survey_replicate()` — `calibration =` parameter

All tests use `make_survey_data(n = 200, design = "replicate", seed = N)`.
Every test that constructs a survey design calls `test_invariants(design)` as
the first assertion.

**Happy paths**:

- `calibration = NULL` (default): `@calibration` is `NULL`.
  `test_invariants(design)` passes.

- `calibration = list(cd)` with a valid caldata element: `@calibration` is
  identical to `list(cd)`. `test_invariants(design)` passes.

- `calibration = list()`: `@calibration` is `list()`. No error.

- Provenance-only assertion: calling `get_means(design_with_calibration, y1)`
  and `get_means(design_without_calibration, y1)` on otherwise identical
  `survey_replicate` objects returns identical SE values (tolerance 1e-12).
  This verifies that `@calibration` is not used in the replicate variance path.

**Error paths** (dual pattern):

- CAL-15: `calibration` is a bare caldata list → `surveycore_error_calibration_not_list`
- CAL-16: any element fails the caldata structure check →
  `surveycore_error_caldata_invalid_element`
- CAL-16: `calibration = list(cd)` where `length(cd$w) != nrow(data)` →
  `surveycore_error_caldata_invalid_element`

**Edge cases**:

- `calibration = NULL` and then `design@calibration <- list(cd)` post-hoc:
  SE is still unchanged vs. the same design with `calibration = NULL`.
  Confirms replicate path never reads `@calibration`.

---

### Numerical accuracy — calibrated Taylor variance

All numerical tests require `skip_if_not_installed("survey")`. All use
`nhanes_2017` filtered to exam participants (`ridstatr == 2`, `wtmec2yr > 0`).

**GREG calibration oracle (`survey::calibrate()`)**:

- Calibrate on `riagendr` (gender): calibration-adjusted SE from
  `get_means(design, bpxsy1)` must equal `survey::svymean(~bpxsy1, sv_cal)` SE
  within 1e-8.
- Post-calibration point estimate matches `survey::svymean()` within 1e-10.
- Calibration-adjusted SE from `get_totals()` matches `survey::svytotal()` SE
  within 1e-8.
- Calibration reduces SE when the auxiliary variable is correlated with the
  outcome (directional: uncalibrated SE differs from calibrated SE by more than
  1e-10).
- SRS-style design (no ids/strata) with intercept-only calibration: SE matches
  oracle within 1e-8.
- Alternative auxiliary variable (`ridageyr`): SE matches oracle within 1e-8.

**Raking oracle (`survey::rake()`) — NEW, replaces prior two-calibrate test**:

- Build a two-margin rake (gender × age group) using `survey::rake()` on the
  NHANES design.
- Build the combined model matrix: column-bind the gender indicator matrix and
  the age-group indicator matrix, drop one column per margin for
  identifiability.
- Compute g-weights as `weights(sv_raked) / base_weights` (final converged
  weights from `survey::rake()`).
- Construct a single `as_caldata()` element from combined model matrix and
  g-weights.
- Store this single caldata element at `design@calibration`.
- Assert that `get_means(design, bpxsy1)` SE matches
  `survey::SE(survey::svymean(~bpxsy1, sv_raked))` within 1e-8.

**Domain estimates**:

- `get_means(design, bpxsy1, group = riagendr)` SE matches
  `survey::svyby(~bpxsy1, ~riagendr, sv_cal, survey::svymean)` SE within 1e-8.

**Domain edge cases with calibration**:

- Calibrated design where ONE group in a `group =` call has all-NA outcomes
  while other groups have valid data: the all-NA group returns SE = NA and
  point estimate = NA; other groups return valid calibrated SE. No error thrown.
- Calibrated design where the outcome column is all-NA for ALL observations:
  SE = NA, point estimate = NA for all outputs. No error thrown.
- Calibrated design with a `group =` variable that creates a single-observation
  group: the single-observation group returns a valid (non-NaN, non-Inf) result
  or NA if variance is undefined; no error thrown.

**Edge cases (behavioral)**:

- `@calibration = NULL`: SE is positive numeric; no change from non-calibrated
  path.
- `@calibration = list()` (empty list): SE is identical to NULL case (no
  projection applied).
- All-NA outcome column on a calibrated design: SE and point estimate are both
  NA (no error thrown).
- Two accumulated caldata entries: degrees-of-freedom column in output equals
  the design df minus the sum of QR ranks from both entries.
- Warning when df reduction produces `df_final <= 0`: emits
  `surveycore_warning_zero_df_after_calibration` and df is clamped to
  `max(1L, df_final)`.

---

### Df-adjustment tests

- Calibrated design has df in output equal to `design_df - qr$rank` for a
  single caldata entry.
- Calibrated design with two caldata entries has df equal to
  `design_df - rank1 - rank2` (tests two independent calibration events, not
  per-margin raking).
- No `df` column in output when `@calibration` is `NULL`.
- Warning `surveycore_warning_zero_df_after_calibration` emitted when df
  reduction exceeds design df; result still returned with df clamped to 1.

**Warning dual pattern** — `surveycore_warning_zero_df_after_calibration`:

```
# Both assertions required:
expect_warning(
  result <- get_means(over_calibrated_design, y1),
  class = "surveycore_warning_zero_df_after_calibration"
)
expect_snapshot(warning = TRUE, get_means(over_calibrated_design, y1))
```

The `over_calibrated_design` is constructed by assigning a full-rank n × n
model matrix as caldata to a design with fewer PSUs than columns, forcing
`df_reduction >= design_df`.

### Zero-weight rows

- Calibrated Taylor design with one observation having a near-minimum-positive
  base weight (above `.Machine$double.eps^0.5` to pass `as_caldata()` checks):
  `get_means()` returns a valid (non-NaN, non-Inf) point estimate and SE.
  No error thrown.

---

## Invariants

- `test_invariants(design)` is the first assertion in every test block that
  creates a survey object via `as_survey()` or `as_survey_replicate()`.
- After calling `as_survey(data, ..., calibration = list(cd))`, the returned
  design's `@calibration` is `identical` to `list(cd)`.
- For `survey_replicate`, setting `@calibration` to any valid caldata list does
  not change the SE output of any `get_*()` function.

---

## Tolerances

- Point estimates: 1e-10
- SE / variance: 1e-8
- CI bounds: 1e-6
- df column comparisons: exact integer equality (`expect_equal` or
  `expect_identical`)
- SE identity for replicate designs with and without calibration: 1e-12
  (tighter than SE tolerance because no calibration correction is expected to
  apply; any difference indicates a regression)

Deviations from defaults: the 1e-12 tolerance for the replicate provenance
test is tighter than the 1e-8 SE default because we are asserting complete
non-interference, not approximate equality.

---

## Profile gates

- [ ] devtools::document() clean
- [ ] devtools::test() all pass
- [ ] devtools::run_examples() all pass
- [ ] R CMD check --as-cran (0 err, 0 warn, notes reviewed)
- [ ] pkgcheck PASS
- [ ] pkgdown::build_site() clean
- [ ] covr::package_coverage() >= 95% (target 98%)
- [ ] CRAN cookbook scan clean (see r-package-profile.md)
