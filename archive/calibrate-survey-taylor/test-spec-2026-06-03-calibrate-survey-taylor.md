# Test-spec — calibrate-survey-taylor

---

## Reference oracle

- `survey` package (CRAN), functions `survey::calibrate()`, `survey::rake()`, `survey::svymean()` / `survey::svytotal()`
- Use `skip_if_not_installed("survey")` for all oracle-comparison tests

---

## Datasets

| Dataset | Purpose |
|---------|---------|
| `nhanes_2017` | Numerical accuracy: calibration-adjusted SE vs `survey` oracle |
| `make_survey_data(seed = N)` | Unit tests: class structure, error paths, edge cases |
| Inline data frames | Degenerate inputs: non-positive weights, dimension mismatches, NA values |

---

## Tolerances

- Point estimates: `1e-10`
- SE / variance: `1e-8`
- CI bounds: `1e-6`

---

## Per-function test plan

### `survey_taylor` — `@calibration` property

**Happy path:**

- `test_that("survey_taylor has @calibration == NULL by default")`
  - Construct via `as_survey()` using `make_survey_data(seed = 1)`.
  - `test_invariants(design)` first.
  - `expect_null(design@calibration)`.

- `test_that("survey_taylor @calibration accepts a list")`
  - Construct design. Build a caldata entry via `as_caldata()`. Assign `design@calibration <- list(cd)`.
  - `test_invariants(design)`.
  - `expect_type(design@calibration, "list")`.
  - `expect_length(design@calibration, 1L)`.

**S7 validator (Layer 1 — `class=` only, no snapshot):**

- `test_that("survey_taylor S7 validator passes when @calibration is NULL")`
- `test_that("survey_taylor S7 validator passes when @calibration is a non-empty list")`

---

### `survey_replicate` — `@calibration` property

**Happy path:**

- `test_that("survey_replicate has @calibration == NULL by default")`
  - Construct via `as_survey_rep()` using `make_survey_data(design = "replicate", seed = 1)`.
  - `test_invariants(design)` first.
  - `expect_null(design@calibration)`.

- `test_that("survey_replicate @calibration accepts a list")`
  - Build a caldata entry via `as_caldata()`. Assign `design@calibration <- list(cd)`.
  - `test_invariants(design)`.
  - `expect_type(design@calibration, "list")`.

**S7 validator (Layer 1 — `class=` only, no snapshot):**

- `test_that("survey_replicate S7 validator passes when @calibration is NULL")`
- `test_that("survey_replicate S7 validator passes when @calibration is a non-empty list")`

---

### `as_caldata()`

**Happy path:**

- `test_that("as_caldata() returns a list with the correct four names")`
  - `base_w <- rep(1, 10); g <- rep(1.1, 10); mm <- matrix(1, 10, 2)`
  - `cd <- as_caldata(base_w, g, mm)`
  - `expect_named(cd, c("qr", "w", "stage", "index"))`.
  - `expect_s3_class(cd$qr, "qr")`.
  - `expect_equal(cd$stage, 0L)`.
  - `expect_null(cd$index)`.

- `test_that("as_caldata() w slot equals g_weights * sqrt(base_weights)")`
  - `expect_equal(cd$w, g * sqrt(base_w), tolerance = 1e-15)`.

- `test_that("as_caldata() qr slot is qr of sqrt(base_w) * model_matrix")`
  - `expected_qr <- qr(sqrt(base_w) * mm)`
  - `expect_equal(cd$qr$qr, expected_qr$qr, tolerance = 1e-15)`.

- `test_that("as_caldata() works with single-column model matrix (~1 intercept)")`
  - `mm1 <- matrix(1, 10, 1)`.
  - `cd1 <- as_caldata(base_w, g, mm1)`.
  - `expect_equal(ncol(cd1$qr$qr), 1L)`.

- `test_that("as_caldata() works with g_weights all equal to 1.0 (no calibration effect)")`
  - `cd_id <- as_caldata(base_w, rep(1, 10), mm)`.
  - No error; `cd_id$w` equals `sqrt(base_w)`.

**Error paths (dual pattern — `expect_error(class=)` + `expect_snapshot(error=TRUE)`):**

- `test_that("as_caldata() rejects non-positive base_weights")`
  - `base_w_bad <- c(rep(1, 9), 0)`.
  - `expect_error(as_caldata(base_w_bad, g, mm), class = "surveycore_error_caldata_weights_nonpositive")`.
  - `expect_snapshot(error = TRUE, as_caldata(base_w_bad, g, mm))`.

- `test_that("as_caldata() rejects non-positive g_weights")`
  - `g_bad <- c(rep(1.1, 9), -0.1)`.
  - `expect_error(as_caldata(base_w, g_bad, mm), class = "surveycore_error_caldata_gweights_nonpositive")`.
  - `expect_snapshot(error = TRUE, as_caldata(base_w, g_bad, mm))`.

- `test_that("as_caldata() rejects near-zero g_weights * sqrt(base_weights)")`
  - `g_tiny <- c(rep(1.1, 9), .Machine$double.eps^0.6)` (product below threshold).
  - `expect_error(as_caldata(base_w, g_tiny, mm), class = "surveycore_error_caldata_weights_near_zero")`.
  - `expect_snapshot(error = TRUE, as_caldata(base_w, g_tiny, mm))`.

- `test_that("as_caldata() rejects model_matrix with wrong number of rows")`
  - `mm_bad <- matrix(1, 5, 2)` (n=10, matrix has 5 rows).
  - `expect_error(as_caldata(base_w, g, mm_bad), class = "surveycore_error_caldata_dimension_mismatch")`.
  - `expect_snapshot(error = TRUE, as_caldata(base_w, g, mm_bad))`.

- `test_that("as_caldata() rejects model_matrix with 0 columns")`
  - `mm_empty <- matrix(numeric(0), nrow = 10, ncol = 0)`.
  - `expect_error(as_caldata(base_w, g, mm_empty), class = "surveycore_error_caldata_empty_model_matrix")`.
  - `expect_snapshot(error = TRUE, as_caldata(base_w, g, mm_empty))`.

- `test_that("as_caldata() rejects model_matrix with NA values")`
  - `mm_na <- mm; mm_na[1, 1] <- NA`.
  - `expect_error(as_caldata(base_w, g, mm_na), class = "surveycore_error_caldata_model_matrix_invalid")`.
  - `expect_snapshot(error = TRUE, as_caldata(base_w, g, mm_na))`.

- `test_that("as_caldata() rejects model_matrix with Inf values")`
  - `mm_inf <- mm; mm_inf[1, 1] <- Inf`.
  - `expect_error(as_caldata(base_w, g, mm_inf), class = "surveycore_error_caldata_model_matrix_invalid")`.
  - `expect_snapshot(error = TRUE, as_caldata(base_w, g, mm_inf))`.

- `test_that("as_caldata() rejects g_weights of wrong length (B-3)")`
  - `g_wrong <- rep(1.1, 5)` (n = 10, g is length 5).
  - `expect_error(as_caldata(base_w, g_wrong, mm), class = "surveycore_error_caldata_gweights_length_mismatch")`.
  - `expect_snapshot(error = TRUE, as_caldata(base_w, g_wrong, mm))`.

- `test_that("as_caldata() rejects NA in base_weights (B-4)")`
  - `base_w_na <- base_w; base_w_na[1] <- NA_real_`.
  - `expect_error(as_caldata(base_w_na, g, mm), class = "surveycore_error_caldata_weights_missing")`.
  - `expect_snapshot(error = TRUE, as_caldata(base_w_na, g, mm))`.

- `test_that("as_caldata() rejects NA in g_weights (B-4)")`
  - `g_na <- g; g_na[1] <- NA_real_`.
  - `expect_error(as_caldata(base_w, g_na, mm), class = "surveycore_error_caldata_gweights_missing")`.
  - `expect_snapshot(error = TRUE, as_caldata(base_w, g_na, mm))`.

- `test_that("as_caldata() rejects Inf in base_weights (B-4)")`
  - `base_w_inf <- base_w; base_w_inf[1] <- Inf`.
  - `expect_error(as_caldata(base_w_inf, g, mm), class = "surveycore_error_caldata_weights_missing")`.
  - `expect_snapshot(error = TRUE, as_caldata(base_w_inf, g, mm))`.

- `test_that("as_caldata() works with n = 1 (single observation, R-6)")`
  - `base_w1 <- 1; g1 <- 1.1; mm1x1 <- matrix(1, 1, 1)`.
  - `cd1 <- as_caldata(base_w1, g1, mm1x1)`.
  - `expect_s3_class(cd1$qr, "qr")`.
  - `expect_equal(cd1$stage, 0L)`.
  - `expect_null(cd1$index)`.

- `test_that("as_caldata() errors on empty base_weights (n = 0, R-6)")`
  - `expect_error(as_caldata(numeric(0), numeric(0), matrix(numeric(0), 0, 1)), class = "surveycore_error_caldata_weights_nonpositive")`.

---

### `.apply_caldata_projection()` — internal error paths

These test the internal validation that can only be triggered by constructing invalid caldata directly (bypassing `as_caldata()`), so they are direct tests.

- `test_that(".apply_caldata_projection() errors when any caldata entry has stage != 0L [direct]")`
  - Build a valid `cd` via `as_caldata()`.
  - Manually override: `cd_bad <- cd; cd_bad$stage <- 1L`.
  - `u <- matrix(rnorm(10), 10, 1)`.
  - `expect_error(.apply_caldata_projection(u, list(cd_bad)), class = "surveycore_error_caldata_within_stage_unsupported")`.
  - `expect_snapshot(error = TRUE, .apply_caldata_projection(u, list(cd_bad)))`.

- `test_that(".apply_caldata_projection() errors on dimension mismatch between u and cd$w [direct]")`
  - `cd_5 <- as_caldata(rep(1, 5), rep(1.1, 5), matrix(1, 5, 1))`.
  - `u_10 <- matrix(rnorm(10), 10, 1)` (different length than cd$w).
  - `expect_error(.apply_caldata_projection(u_10, list(cd_5)), class = "surveycore_error_caldata_projection_dimension_mismatch")`.
  - `expect_snapshot(error = TRUE, .apply_caldata_projection(u_10, list(cd_5)))`.

- `test_that(".apply_caldata_projection() returns u unchanged when u is all-NA")`
  - `cd <- as_caldata(rep(1, 10), rep(1.1, 10), matrix(1, 10, 1))`.
  - `u_na <- matrix(NA_real_, 10, 1)`.
  - `result <- .apply_caldata_projection(u_na, list(cd))`.
  - `expect_true(all(is.na(result)))`.

- `test_that(".apply_caldata_projection() returns u unchanged when caldata is empty list [direct, B-7]")`
  - `u <- matrix(rnorm(10), 10, 1)`.
  - `result <- .apply_caldata_projection(u, list())`.
  - `expect_identical(result, u)`.

- `test_that(".apply_caldata_projection() errors on NULL element in caldata list [direct, B-5]")`
  - `cd <- as_caldata(rep(1, 10), rep(1.1, 10), matrix(1, 10, 1))`.
  - `u <- matrix(rnorm(10), 10, 1)`.
  - `expect_error(.apply_caldata_projection(u, list(cd, NULL)), class = "surveycore_error_caldata_invalid_element")`.
  - `expect_snapshot(error = TRUE, .apply_caldata_projection(u, list(cd, NULL)))`.

---

### Calibration-adjusted variance — numerical accuracy vs. `survey` oracle

All tests require `skip_if_not_installed("survey")`.

The oracle setup: construct an equivalent `svydesign`, apply `survey::calibrate()`, then compare `survey::svymean()` / `survey::svytotal()` output against surveycore's `get_means()` / `get_totals()` on a `survey_taylor` whose `@calibration` was manually populated via `as_caldata()`.

**SE matches oracle — linear calibration, `get_means()`:**

- `test_that("calibration-adjusted SE from get_means() matches survey oracle [linear, nhanes]")`
  - `skip_if_not_installed("survey")`.
  - Construct `sc_design <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtmec2yr, strata = sdmvstra, nest = TRUE)`.
  - `test_invariants(sc_design)`.
  - Compute g-weights using linear calibration to `ridageyr` totals (matching what `survey::calibrate()` produces).
  - Populate `@calibration` via `as_caldata()`. Update weight column. Store in `sc_cal`.
  - `test_invariants(sc_cal)`.
  - `sc_se <- get_means(sc_cal, bpxsy1)$se`.
  - Construct `sv_cal` via `survey::svydesign()` + `survey::calibrate()` with the same targets.
  - `sv_se <- SE(survey::svymean(~bpxsy1, sv_cal, na.rm = TRUE))[["bpxsy1"]]`.
  - `expect_equal(sc_se, sv_se, tolerance = 1e-8)`.

**Point estimate matches oracle:**

- `test_that("post-calibration point estimate from get_means() matches survey oracle [linear, nhanes]")`
  - `skip_if_not_installed("survey")`.
  - `expect_equal(sc_mean, sv_mean, tolerance = 1e-10)`.

**Calibration does not affect survey_replicate SE (B-2):**

- `test_that("get_means() on survey_replicate with @calibration set returns same SE as uncalibrated")`
  - Construct `sc_rep` via `as_survey_rep()` using `make_survey_data(design = "replicate", seed = 42)`.
  - `se_uncal <- get_means(sc_rep, y1)$se`.
  - Build a caldata entry: `cd <- as_caldata(sc_rep@data$wt, rep(1.05, nrow(sc_rep@data)), matrix(1, nrow(sc_rep@data), 1))`.
  - `sc_rep@calibration <- list(cd)`.
  - `se_cal <- get_means(sc_rep, y1)$se`.
  - `expect_equal(se_cal, se_uncal, tolerance = 1e-15)` — calibration must not affect replicate variance.

**SE matches oracle — SRS design (R-5):**

- `test_that("calibration-adjusted SE matches oracle on SRS design [get_means, R-5]")`
  - `skip_if_not_installed("survey")`.
  - Construct SRS design from `make_survey_data(seed = 7)` with no `ids` or `strata`: `sc_srs <- as_survey(df, weights = wt)`.
  - `test_invariants(sc_srs)`.
  - Compute g-weights using linear calibration to `y2` total. Populate `@calibration` via `as_caldata()`. Update weight column.
  - Construct equivalent `sv_srs_cal` via `survey::svydesign()` + `survey::calibrate()`.
  - `expect_equal(get_means(sc_srs_cal, y1)$se, SE(survey::svymean(~y1, sv_srs_cal, na.rm = TRUE))[[1]], tolerance = 1e-8)`.

**SE matches oracle — `get_totals()`:**

- `test_that("calibration-adjusted SE from get_totals() matches survey oracle [linear, nhanes]")`
  - `skip_if_not_installed("survey")`.
  - Same setup; compare `get_totals()` against `survey::svytotal()`.
  - `expect_equal(sc_se_total, sv_se_total, tolerance = 1e-8)`.

**Calibration reduces SE (directional test):**

- `test_that("calibration reduces SE when auxiliary variable correlates with outcome [nhanes]")`
  - `skip_if_not_installed("survey")`.
  - `se_uncal <- get_means(sc_design, bpxsy1)$se`.
  - `se_cal   <- get_means(sc_cal,    bpxsy1)$se`.
  - `expect_lt(se_cal, se_uncal)`.

**Uncalibrated path is unchanged when `@calibration` is NULL (regression):**

- `test_that("get_means() SE is unchanged when @calibration is NULL [regression]")`
  - Verify SE from `get_means()` on an uncalibrated design is identical before and after manually assigning `design@calibration <- NULL`.
  - Ensures the projection code path is not activated for uncalibrated designs.

**Empty `@calibration` list is treated as uncalibrated:**

- `test_that("get_means() SE is unchanged when @calibration is an empty list")`
  - `design@calibration <- list()` (non-NULL but empty).
  - SE should equal SE from `design@calibration <- NULL`.
  - Verifies the `length > 0` condition correctly skips projection.

**All-NA outcome propagates correctly through calibration path (R-8):**

- `test_that("get_means() returns NA SE on calibrated design with all-NA outcome column [R-8]")`
  - Construct calibrated design `sc_cal` (from the nhanes setup above).
  - `sc_cal@data$y_na <- NA_real_`.
  - `result <- get_means(sc_cal, y_na)`.
  - `expect_true(is.na(result$se))`.
  - This validates that the NA pass-through in `.apply_caldata_projection()` integrates correctly with `.taylor_mean()`'s NA handling.

**Multiple accumulated caldata (two successive calibrations):**

- `test_that("two accumulated caldata entries both applied by .apply_caldata_projection()")`
  - Populate `design@calibration` with two caldata entries (two separate `as_caldata()` calls).
  - Verify `get_means()` runs without error.
  - Verify SE is ≤ SE from a design with only the first caldata entry (additional calibration does not inflate SE beyond the first projection).

**Domain/group estimation is calibration-aware:**

- `test_that("calibration-adjusted SE is applied to domain estimates [get_means with group]")`
  - `skip_if_not_installed("survey")`.
  - Compute `get_means(sc_cal, bpxsy1, group = gender)$se`.
  - Verify domain SEs match `survey::svymean(~bpxsy1, subset(sv_cal, gender == "Female"))` within 1e-8.
  - This tests that `.taylor_mean_cell()` is calibration-aware.

**Raking quality gate (quality gate 10):**

- `test_that("calibration-adjusted SE from get_means() matches survey::rake() oracle [raking, nhanes]")`
  - `skip_if_not_installed("survey")`.
  - Construct `sc_design` from `nhanes_2017` as above.
  - Apply two-margin raking calibration: calibrate to `ridageyr` totals, then to sex distribution. Accumulate two caldata entries in `design@calibration`.
  - Construct equivalent `sv_raked` via `survey::rake()` with the same margins.
  - Compare `get_means(sc_raked, bpxsy1)$se` against `SE(survey::svymean(~bpxsy1, sv_raked, na.rm = TRUE))[["bpxsy1"]]` within tolerance `1e-8`.
  - This validates sequential QR projection for multi-margin calibration.

---

### Degrees-of-freedom adjustment

- `test_that("calibrated design has reduced df in get_means() output [nhanes, linear]")`
  - `skip_if_not_installed("survey")`.
  - `df_uncal <- get_means(sc_design, bpxsy1)$df`.
  - `df_cal   <- get_means(sc_cal,    bpxsy1)$df`.
  - `expect_lt(df_cal, df_uncal)`.
  - `expect_equal(df_uncal - df_cal, sc_cal@calibration[[1]]$qr$rank)`.

- `test_that("df column in get_means() decreases by qr$rank for each caldata entry")`
  - Two caldata entries with known ranks `r1` and `r2`.
  - `expect_equal(df_uncal - df_2cal, r1 + r2)`.

- `test_that("get_means() warns when calibration df reduction >= design df [R-7]")`
  - Construct a minimal design with very few PSUs (low df) and populate `@calibration` with enough columns to exhaust the df.
  - `expect_warning(result <- get_means(sc_overfit_cal, y1), class = "surveycore_warning_zero_df_after_calibration")`.
  - `expect_gte(result$df, 1L)` — clamped to at least 1.

---

### update_design() calibration guard

- `test_that("update_design() warns when weight column changes on calibrated design [B-6]")`
  - Construct `sc_cal` with `@calibration` non-NULL.
  - `expect_warning(update_design(sc_cal, weights = y2), class = "surveycore_warning_weight_change_invalidates_calibration")`.
  - `expect_snapshot(error = FALSE, withCallingHandlers(update_design(sc_cal, weights = y2), warning = function(w) { cat(conditionMessage(w)); invokeRestart("muffleWarning") }))`.

---

## Invariants required in every test that constructs a survey object

Every `test_that()` block that calls `as_survey()`, `as_survey_rep()`, or manually constructs a design must call `test_invariants(design)` as its **first assertion** on the resulting object.

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
