# Implementation plan — calibrate-survey-taylor

## PR map

---

- [x] PR 1: feature/calibrate-survey-taylor-class-ascaldata — Add `@calibration` property to `survey_taylor` and `survey_replicate`; implement and export `as_caldata()`; add new error classes to `plans/error-messages.md`

  - **Tasks** (TDD sub-steps explicit)

    1. Add 14 new error/warning class rows to `plans/error-messages.md`.
       - Rows: `surveycore_error_caldata_weights_nonpositive`, `surveycore_error_caldata_weights_missing`, `surveycore_error_caldata_gweights_nonpositive`, `surveycore_error_caldata_gweights_missing`, `surveycore_error_caldata_gweights_length_mismatch`, `surveycore_error_caldata_weights_near_zero`, `surveycore_error_caldata_dimension_mismatch`, `surveycore_error_caldata_empty_model_matrix`, `surveycore_error_caldata_model_matrix_invalid`, `surveycore_error_caldata_within_stage_unsupported`, `surveycore_error_caldata_projection_dimension_mismatch`, `surveycore_error_caldata_invalid_element`, `surveycore_warning_weight_change_invalidates_calibration`, `surveycore_warning_zero_df_after_calibration`.
       - Follow the exact column format of existing rows (Function, Condition, Level, Error Class, cli Message Template).

    2. Write failing tests for `survey_taylor @calibration` property — four tests in `tests/testthat/test-s7-classes.R`:
       - `test_that("survey_taylor has @calibration == NULL by default")` — construct via `as_survey()`, `test_invariants(design)`, `expect_null(design@calibration)`.
       - `test_that("survey_taylor @calibration accepts a list")` — assign a single caldata stub (use `list(list(qr = qr(matrix(1,2,1)), w = c(1,1), stage = 0L, index = NULL))`), `test_invariants(design)`, `expect_type(design@calibration, "list")`, `expect_length(design@calibration, 1L)`.
       - `test_that("survey_taylor S7 validator passes when @calibration is NULL")` — verify no error.
       - `test_that("survey_taylor S7 validator passes when @calibration is a non-empty list")` — verify no error.
       - Run `devtools::test(filter = "test-s7-classes")` — expect failures because `@calibration` property does not yet exist.

    3. Write failing tests for `survey_replicate @calibration` property — four analogous tests in `tests/testthat/test-s7-classes.R`:
       - `test_that("survey_replicate has @calibration == NULL by default")`
       - `test_that("survey_replicate @calibration accepts a list")`
       - `test_that("survey_replicate S7 validator passes when @calibration is NULL")`
       - `test_that("survey_replicate S7 validator passes when @calibration is a non-empty list")`
       - Run `devtools::test(filter = "test-s7-classes")` — expect continued failures.

    4. Add `@calibration` property (`S7::new_property(default = NULL)`) to `survey_taylor` in `R/core-classes.R`.
       - Locate the `survey_taylor <- S7::new_class("survey_taylor", parent = survey_base, properties = list(), ...)` definition (line 237).
       - Change `properties = list()` to `properties = list(calibration = S7::new_property(default = NULL))`.
       - Do NOT add any structural validation of the list contents to the S7 validator — deep validation lives in `as_caldata()`.

    5. Add `@calibration` property (`S7::new_property(default = NULL)`) to `survey_replicate` in `R/core-classes.R`.
       - Locate the `survey_replicate <- S7::new_class("survey_replicate", parent = survey_base, properties = list(), ...)` definition (line 410).
       - Same change as survey_taylor.

    6. Run `devtools::test(filter = "test-s7-classes")` — the four `survey_taylor` and four `survey_replicate` property tests must now pass.

    7. Create `tests/testthat/test-calibration.R`. Write all 12 `as_caldata()` happy-path and error-path tests (these will fail until the function exists):
       - `test_that("as_caldata() returns a list with the correct four names")`
       - `test_that("as_caldata() w slot equals g_weights * sqrt(base_weights)")`
       - `test_that("as_caldata() qr slot is qr of sqrt(base_w) * model_matrix")`
       - `test_that("as_caldata() works with single-column model matrix (~1 intercept)")`
       - `test_that("as_caldata() works with g_weights all equal to 1.0 (no calibration effect)")`
       - `test_that("as_caldata() works with n = 1 (single observation, R-6)")`
       - `test_that("as_caldata() errors on empty base_weights (n = 0, R-6)")`
       - `test_that("as_caldata() rejects non-positive base_weights")`
       - `test_that("as_caldata() rejects NA in base_weights (B-4)")`
       - `test_that("as_caldata() rejects Inf in base_weights (B-4)")`
       - `test_that("as_caldata() rejects non-positive g_weights")`
       - `test_that("as_caldata() rejects NA in g_weights (B-4)")`
       - `test_that("as_caldata() rejects g_weights of wrong length (B-3)")`
       - `test_that("as_caldata() rejects near-zero g_weights * sqrt(base_weights)")`
       - `test_that("as_caldata() rejects model_matrix with wrong number of rows")`
       - `test_that("as_caldata() rejects model_matrix with 0 columns")`
       - `test_that("as_caldata() rejects model_matrix with NA values")`
       - `test_that("as_caldata() rejects model_matrix with Inf values")`
       - Every error-path test uses the dual pattern: `expect_error(..., class = "surveycore_error_*")` + `expect_snapshot(error = TRUE, ...)`.
       - Run `devtools::test(filter = "test-calibration")` — expect failures because `as_caldata()` does not yet exist.

    8. Create `R/calibration.R`. Implement `as_caldata(base_weights, g_weights, model_matrix)`:
       - Validation order (this order determines which error fires when multiple conditions are violated simultaneously):
         a. `base_weights` missing check: `if (any(!is.finite(base_weights))) cli::cli_abort(..., class = "surveycore_error_caldata_weights_missing")` — catches `NA`, `NaN`, `Inf` in a single test.
         b. `base_weights` positivity: `if (any(base_weights <= 0)) cli::cli_abort(..., class = "surveycore_error_caldata_weights_nonpositive")` — also fires for `length(base_weights) == 0` because `any(numeric(0) <= 0)` is `FALSE` but the preceding `!is.finite(numeric(0))` also returns `FALSE`; the `<= 0` check on an empty vector is `FALSE` — however, `length(base_weights) == 0` means `!any(base_weights > 0)` is `TRUE`, so implement as `if (length(base_weights) == 0 || any(base_weights <= 0)) cli::cli_abort(...)`.
         c. `g_weights` missing check: same pattern as (a).
         d. `g_weights` positivity: same pattern as (b).
         e. `g_weights` length: `if (length(g_weights) != length(base_weights)) cli::cli_abort(..., class = "surveycore_error_caldata_gweights_length_mismatch")`.
         f. Near-zero product: `w_prod <- g_weights * sqrt(base_weights); if (any(w_prod < .Machine$double.eps^0.5)) cli::cli_abort(..., class = "surveycore_error_caldata_weights_near_zero")`.
         g. Model matrix row count: `if (nrow(model_matrix) != length(base_weights)) cli::cli_abort(..., class = "surveycore_error_caldata_dimension_mismatch")`.
         h. Model matrix column count: `if (ncol(model_matrix) == 0L) cli::cli_abort(..., class = "surveycore_error_caldata_empty_model_matrix")`.
         i. Model matrix finite check: `if (any(!is.finite(model_matrix))) cli::cli_abort(..., class = "surveycore_error_caldata_model_matrix_invalid")`.
       - Return value: `list(qr = qr(sqrt(base_weights) * model_matrix), w = w_prod, stage = 0L, index = NULL)`.
       - Add roxygen2 block with `@export`, `@family constructors`, `@return`, `@details` (GLM limitation note), `@examples` (3-row synthetic example assigning to `design@calibration`).
       - Do NOT implement `.apply_caldata_projection()`, `.maybe_apply_calibration()`, or `.get_calibration_df_reduction()` in PR 1 — those live in PR 2.

    9. Run `devtools::test(filter = "test-calibration")` — all 18 `as_caldata()` tests must pass. Update snapshots with `testthat::snapshot_review()` after confirming message text matches `plans/error-messages.md`.

    10. Run `devtools::document()` to update `NAMESPACE` (adds `export(as_caldata)`) and generate `man/as_caldata.Rd`.

    11. Run `devtools::check()` — 0 errors, 0 warnings, ≤2 notes.

  - **Acceptance criteria** (observable, before merge)

    - `test_that("survey_taylor has @calibration == NULL by default")` passes.
    - `test_that("survey_taylor @calibration accepts a list")` passes.
    - `test_that("survey_taylor S7 validator passes when @calibration is NULL")` passes.
    - `test_that("survey_taylor S7 validator passes when @calibration is a non-empty list")` passes.
    - `test_that("survey_replicate has @calibration == NULL by default")` passes.
    - `test_that("survey_replicate @calibration accepts a list")` passes.
    - `test_that("survey_replicate S7 validator passes when @calibration is NULL")` passes.
    - `test_that("survey_replicate S7 validator passes when @calibration is a non-empty list")` passes.
    - All 18 `as_caldata()` tests in `test-calibration.R` pass (5 happy path + 13 error paths).
    - `tests/testthat/_snaps/test-calibration.md` contains 13 error-path snapshots for `as_caldata()` and is committed after `testthat::snapshot_review()`.
    - `devtools::document()` produces `NAMESPACE` containing `export(as_caldata)` and `man/as_caldata.Rd` exists.
    - `NEWS.md` updated with a bullet for `as_caldata()` under the development version heading.
    - `devtools::check()` 0 errors, 0 warnings.

  - **Files touched** (write surface)

    - `R/core-classes.R` — add `@calibration` property to `survey_taylor` (line ~240) and `survey_replicate` (line ~413)
    - `R/calibration.R` — new file; `as_caldata()` only
    - `plans/error-messages.md` — 14 new rows (12 errors + 2 warnings)
    - `tests/testthat/test-s7-classes.R` — 8 new `test_that()` blocks (4 for `survey_taylor`, 4 for `survey_replicate`)
    - `tests/testthat/test-calibration.R` — new file; all `as_caldata()` tests
    - `tests/testthat/_snaps/test-calibration.md` — new snapshot file (auto-generated)
    - `NAMESPACE` — regenerated by `devtools::document()`
    - `man/as_caldata.Rd` — new file (auto-generated by `devtools::document()`)
    - `NEWS.md` — new bullet under development version heading

  - **Pipeline split**: recommended

---

- [x] PR 2: feature/calibrate-survey-taylor-variance — Add `.apply_caldata_projection()`, `.maybe_apply_calibration()`, `.get_calibration_df_reduction()`; wire calibration into `.taylor_mean()`, `.taylor_mean_cell()`, `.taylor_total()`; add df adjustment; add `update_design()` calibration guard; extend test suite with numerical and guard tests

  - **Depends on**: PR 1 merged into `develop`

  - **Tasks** (TDD sub-steps explicit)

    1. Write failing tests for `.apply_caldata_projection()` direct error paths — add to `tests/testthat/test-calibration.R`:
       - `test_that(".apply_caldata_projection() errors when any caldata entry has stage != 0L [direct]")` — build valid `cd` via `as_caldata()`, manually override `cd_bad$stage <- 1L`, `expect_error(.apply_caldata_projection(matrix(rnorm(10), 10, 1), list(cd_bad)), class = "surveycore_error_caldata_within_stage_unsupported")` + snapshot.
       - `test_that(".apply_caldata_projection() errors on dimension mismatch between u and cd$w [direct]")` — `cd_5 <- as_caldata(rep(1,5), rep(1.1,5), matrix(1,5,1))`, `u_10 <- matrix(rnorm(10), 10, 1)`, `expect_error(.apply_caldata_projection(u_10, list(cd_5)), class = "surveycore_error_caldata_projection_dimension_mismatch")` + snapshot.
       - `test_that(".apply_caldata_projection() returns u unchanged when u is all-NA")` — `expect_true(all(is.na(result)))`.
       - `test_that(".apply_caldata_projection() returns u unchanged when caldata is empty list [direct, B-7]")` — `expect_identical(result, u)`.
       - `test_that(".apply_caldata_projection() errors on NULL element in caldata list [direct, B-5]")` — `expect_error(.apply_caldata_projection(u, list(cd, NULL)), class = "surveycore_error_caldata_invalid_element")` + snapshot.
       - Run `devtools::test(filter = "test-calibration")` — expect 5 failures because `.apply_caldata_projection()` does not yet exist.

    2. Implement `.apply_caldata_projection(u, caldata)` in `R/calibration.R`:
       - Guard 0 (empty list pass-through): `if (length(caldata) == 0L) return(u)`.
       - Guard 1 (all-NA pass-through): `if (all(is.na(u))) return(u)`.
       - Guard 1b (NULL element): `bad_idx <- which(vapply(caldata, is.null, logical(1))); if (length(bad_idx) > 0L) cli::cli_abort(..., class = "surveycore_error_caldata_invalid_element")`.
       - Guard 2 (stage): `if (any(vapply(caldata, function(cd) cd$stage != 0L, logical(1)))) cli::cli_abort(..., class = "surveycore_error_caldata_within_stage_unsupported")`.
       - Loop: for each `cd` in caldata — Guard 3 (dimension): `if (nrow(u) != length(cd$w)) cli::cli_abort(..., class = "surveycore_error_caldata_projection_dimension_mismatch")`; then `u <- qr.resid(cd$qr, u / cd$w) * cd$w`.
       - Return `u`.
       - No `@export` — internal function.

    3. Implement `.maybe_apply_calibration(linearized, design)` in `R/calibration.R`:
       - `if (!is.null(design@calibration) && length(design@calibration) > 0L) .apply_caldata_projection(linearized, design@calibration) else linearized`.

    4. Implement `.get_calibration_df_reduction(design)` in `R/calibration.R`:
       - `if (!is.null(design@calibration) && length(design@calibration) > 0L) sum(vapply(design@calibration, function(cd) cd$qr$rank, integer(1))) else 0L`.

    5. Run `devtools::test(filter = "test-calibration")` — the 5 `.apply_caldata_projection()` tests added in task 1 must now pass. Update snapshots.

    6. Write failing numerical-accuracy tests — add to `tests/testthat/test-calibration.R`:
       - `test_that("calibration-adjusted SE from get_means() matches survey oracle [linear, nhanes]")` — `skip_if_not_installed("survey")`.
       - `test_that("post-calibration point estimate from get_means() matches survey oracle [linear, nhanes]")` — `skip_if_not_installed("survey")`.
       - `test_that("calibration-adjusted SE from get_totals() matches survey oracle [linear, nhanes]")` — `skip_if_not_installed("survey")`.
       - `test_that("calibration reduces SE when auxiliary variable correlates with outcome [nhanes]")` — `skip_if_not_installed("survey")`.
       - `test_that("calibration-adjusted SE matches oracle on SRS design [get_means, R-5]")` — `skip_if_not_installed("survey")`.
       - `test_that("get_means() SE is unchanged when @calibration is NULL [regression]")`.
       - `test_that("get_means() SE is unchanged when @calibration is an empty list")`.
       - `test_that("get_means() on survey_replicate with @calibration set returns same SE as uncalibrated")`.
       - `test_that("get_means() returns NA SE on calibrated design with all-NA outcome column [R-8]")`.
       - `test_that("two accumulated caldata entries both applied by .apply_caldata_projection()")`.
       - `test_that("calibration-adjusted SE is applied to domain estimates [get_means with group]")` — `skip_if_not_installed("survey")`.
       - `test_that("calibration-adjusted SE from get_means() matches survey::rake() oracle [raking, nhanes]")` — `skip_if_not_installed("survey")`.
       - Run `devtools::test(filter = "test-calibration")` — expect failures because `.taylor_mean()` etc. are not yet calibration-aware.

    7. Write failing df-adjustment tests — add to `tests/testthat/test-calibration.R`:
       - `test_that("calibrated design has reduced df in get_means() output [nhanes, linear]")` — `skip_if_not_installed("survey")`. Assert `expect_lt(df_cal, df_uncal)` and `expect_equal(df_uncal - df_cal, sc_cal@calibration[[1]]$qr$rank)`.
       - `test_that("df column in get_means() decreases by qr$rank for each caldata entry")`.
       - `test_that("get_means() warns when calibration df reduction >= design df [R-7]")` — `expect_warning(result <- get_means(...), class = "surveycore_warning_zero_df_after_calibration")`; `expect_gte(result$df, 1L)`.
       - Run — expect failures.

    8. Modify `.taylor_mean()` in `R/variance-taylor.R`:
       - After computing `x_centered <- sweep(x, 2L, average)` and before calling `.svy_recvar()`, insert two lines:
         ```r
         linearized <- .maybe_apply_calibration(x_centered * w / psum, design)
         cal_df_reduction <- .get_calibration_df_reduction(design)
         ```
       - Replace the `x_centered * w / psum` argument to `.svy_recvar()` with `linearized`.
       - After `.svy_recvar()` returns `v`, apply df adjustment where the `df` is computed: `df_final <- df_design - cal_df_reduction`. Add the negative-df guard with `surveycore_warning_zero_df_after_calibration` and `df_final <- max(1L, df_final)`.
       - Note: Check how `df_design` is currently computed in `.taylor_mean()` — if not currently computed, identify where in the caller (`get_means()`) the df is calculated and apply the adjustment there. The df column reported by `get_means()` must reflect `cal_df_reduction`.
       - **df traceability note**: The shared `.get_calibration_df_reduction()` helper is called identically in tasks 8, 9, and 10. Test coverage per path: `.taylor_mean()` df tested by the "calibrated design has reduced df" test (task 7 block 1); `.taylor_total()` df tested implicitly via the `get_totals()` oracle test (task 6 block 3); `.taylor_mean_cell()` df tested via the domain-estimate oracle test (task 6 block 11, `calibration-adjusted SE is applied to domain estimates`). All three paths are covered.

    9. Modify `.taylor_total()` in `R/variance-taylor.R`:
       - Same pattern: after computing `x * w` and before `.svy_recvar()`, insert the two `.maybe_apply_calibration()` and `.get_calibration_df_reduction()` calls.
       - Apply df adjustment in the same manner as for `.taylor_mean()`.

    10. Modify `.taylor_mean_cell()` in `R/analysis-means-helpers.R`:
        - After computing `infl_mat <- matrix(w * u / N_d, ncol = 1L, ...)` and before calling `.svy_recvar()`, insert:
          ```r
          infl_mat <- .maybe_apply_calibration(infl_mat, design)
          cal_df_reduction <- .get_calibration_df_reduction(design)
          ```
        - Apply df adjustment to whatever `df` is propagated from this cell function to `get_means()`.

    11. Run `devtools::test(filter = "test-calibration")` — all numerical-accuracy tests and df-adjustment tests added in tasks 6–7 must now pass. Confirm oracle tolerances: SE `1e-8`, point `1e-10`.

    12. Write failing `update_design()` calibration guard test — add to `tests/testthat/test-update-design.R`:
        - `test_that("update_design() warns when weight column changes on calibrated design [B-6]")` — construct calibrated design, `expect_warning(update_design(sc_cal, weights = y2), class = "surveycore_warning_weight_change_invalidates_calibration")` + snapshot.
        - Run `devtools::test(filter = "test-update-design")` — expect 1 failure.

    13. Add calibration guard to `update_design()` in `R/update-design.R`:
        - In the `survey_taylor` branch, after `if (!is.null(new_weights))` confirms the weight column is changing, check `if (!is.null(x@calibration)) cli::cli_warn(..., class = "surveycore_warning_weight_change_invalidates_calibration")`. Add the analogous guard in the `survey_replicate` branch.
        - The guard emits the warning but does NOT clear `@calibration` — user must clear it explicitly.

    14. Run `devtools::test(filter = "test-update-design")` — the guard test must now pass.

    15. Run `devtools::test()` (full test suite) — all tests must pass.

    16. Run `devtools::document()` — no new exports; verify `NAMESPACE` unchanged from PR 1 on this dimension.

    17. Run `devtools::check()` — 0 errors, 0 warnings, ≤2 notes.

  - **Acceptance criteria** (observable, before merge)

    - `test_that(".apply_caldata_projection() errors when any caldata entry has stage != 0L [direct]")` passes.
    - `test_that(".apply_caldata_projection() errors on dimension mismatch between u and cd$w [direct]")` passes.
    - `test_that(".apply_caldata_projection() returns u unchanged when u is all-NA")` passes.
    - `test_that(".apply_caldata_projection() returns u unchanged when caldata is empty list [direct, B-7]")` passes.
    - `test_that(".apply_caldata_projection() errors on NULL element in caldata list [direct, B-5]")` passes.
    - `test_that("calibration-adjusted SE from get_means() matches survey oracle [linear, nhanes]")` passes with SE tolerance `1e-8`.
    - `test_that("post-calibration point estimate from get_means() matches survey oracle [linear, nhanes]")` passes with point tolerance `1e-10`.
    - `test_that("calibration-adjusted SE from get_totals() matches survey oracle [linear, nhanes]")` passes.
    - `test_that("calibration reduces SE when auxiliary variable correlates with outcome [nhanes]")` passes (directional `expect_lt`).
    - `test_that("calibration-adjusted SE matches oracle on SRS design [get_means, R-5]")` passes.
    - `test_that("get_means() SE is unchanged when @calibration is NULL [regression]")` passes.
    - `test_that("get_means() SE is unchanged when @calibration is an empty list")` passes.
    - `test_that("get_means() on survey_replicate with @calibration set returns same SE as uncalibrated")` passes with tolerance `1e-15`.
    - `test_that("get_means() returns NA SE on calibrated design with all-NA outcome column [R-8]")` passes.
    - `test_that("two accumulated caldata entries both applied by .apply_caldata_projection()")` passes.
    - `test_that("calibration-adjusted SE is applied to domain estimates [get_means with group]")` passes with tolerance `1e-8`.
    - `test_that("calibration-adjusted SE from get_means() matches survey::rake() oracle [raking, nhanes]")` passes with tolerance `1e-8`.
    - `test_that("calibrated design has reduced df in get_means() output [nhanes, linear]")` passes (both `expect_lt` and exact rank subtraction).
    - `test_that("df column in get_means() decreases by qr$rank for each caldata entry")` passes.
    - `test_that("get_means() warns when calibration df reduction >= design df [R-7]")` passes; `result$df >= 1L`.
    - `test_that("update_design() warns when weight column changes on calibrated design [B-6]")` passes.
    - All previously passing tests continue to pass; 20 new test blocks in `test-calibration.R` (5 direct + 12 numerical/behavioral + 3 df-adjustment) and 1 new block in `test-update-design.R` all pass.
    - `devtools::check()` 0 errors, 0 warnings.

  - **Files touched** (write surface)

    - `R/calibration.R` — add `.apply_caldata_projection()`, `.maybe_apply_calibration()`, `.get_calibration_df_reduction()` (appended to existing file from PR 1)
    - `R/variance-taylor.R` — modify `.taylor_mean()` and `.taylor_total()` to call `.maybe_apply_calibration()` and `.get_calibration_df_reduction()`, and apply df adjustment
    - `R/analysis-means-helpers.R` — modify `.taylor_mean_cell()` to call `.maybe_apply_calibration()` and `.get_calibration_df_reduction()`, and propagate df adjustment
    - `R/update-design.R` — add calibration guard warning in both `survey_taylor` and `survey_replicate` branches
    - `tests/testthat/test-calibration.R` — extend with 17 new `test_that()` blocks (5 `.apply_caldata_projection()` direct tests + 12 numerical/behavioral tests)
    - `tests/testthat/test-update-design.R` — add 1 new `test_that()` block (calibration guard warning)
    - `tests/testthat/_snaps/test-calibration.md` — updated with new snapshots (`.apply_caldata_projection()` errors + df warning)
    - `tests/testthat/_snaps/test-update-design.md` — updated with new snapshot (calibration guard warning)

  - **Pipeline split**: recommended
