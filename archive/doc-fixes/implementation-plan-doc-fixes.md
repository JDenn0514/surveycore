# Implementation plan — doc-fixes

## PR map

- [x] PR 1: feature/doc-fixes-pr1 — Code bugs + error class registrations
  - **Tasks** (2–5 min each, TDD sub-steps explicit for behavior-changing items)

    1. Register E1–E5 and X6 in `plans/error-messages.md`:
       - Add row for `surveycore_error_update_no_call` (B6 / E5)
       - Add row for `surveycore_error_collection_unnamed` (D20 / E3)
       - Add row for `surveycore_error_invalid_name_type` (D56 / E4)
       - Add row for `surveycore_error_lonely_psu_unknown_option` (X6)
       - Add row for `surveycore_error_fill_not_logical` (D45)
       - Add entry for `surveycore_error_lonely_psu` (E1 — already in code, registration only)
       - Add entry for `surveycore_error_all_replicates_na` (E2 — already in code, registration only)
       Do this before touching any source file so that every class exists in the
       table before the code sites are modified.

    2. Write failing test for B1 (`print.survey_t_test` by-variable label fallback):
       - In `tests/testthat/test-analysis-t-test.R`, add a `test_that` block
         that builds a `survey_t_test` result via `get_t_test()` on a design
         where `sex` has no variable label, captures printed output, and asserts
         the "By:" field shows `"sex"` (raw column name), not an empty string.
       - Add a second block that sets a label via `set_var_label()` and asserts
         the "By:" field shows the label text.

    3. Fix B1 in `R/analysis-t-test.R`:
       - Add `.extract_print_label(m)` helper before `print.survey_t_test`:
         returns `m$by$variable_label` when non-NULL and non-empty, otherwise
         returns `deparse(m$call$by)`.
       - In `print.survey_t_test`, replace the self-assignment no-op
         (`by_label <- by_label`) with `by_label <- .extract_print_label(m)`.
       - Verify both B1 test blocks pass.

    4. Write failing test for B2 (`print.survey_pairwise` by-variable label fallback):
       - In `tests/testthat/test-analysis-t-test.R`, mirror the B1 test blocks
         for `get_pairwise()` / `print.survey_pairwise`.

    5. Fix B2 in `R/analysis-t-test.R`:
       - In `print.survey_pairwise`, replace the same self-assignment no-op with
         `by_label <- .extract_print_label(m)` (reuses the helper from task 3).
       - Verify both B2 test blocks pass.

    6. Write failing test for B3 (boundary warning threshold value):
       - In `tests/testthat/test-analysis-corr-latent.R` (or
         `test-analysis-corr.R`), add a test that calls
         `get_corr(design_with_near_perfect_pair, c(x, y), method = "polychoric")`
         on a crafted two-level ordinal pair with near-perfect concordance,
         captures the warning, and asserts the message text contains `"1e-4"`
         (not `"1e-6"`).
       - Add a snapshot test for the warning message.

    7. Fix B3 in `R/analysis-corr-latent.R`:
       - In the `cli_warn()` call for `surveycore_warning_polychoric_boundary_rho`
         (around line 1633), change `{.val 1e-6}` to `{.val 1e-4}` to match the
         actual threshold used by `.corr_detect_boundary_rho()`.
       - Verify the B3 test passes and snapshot is updated.

    8. Write failing test for B4 (`.glm_design_type_label()` for `survey_nonprob`):
       - In `tests/testthat/test-glm-methods.R`, add a test that fits
         `survey_glm()` on a `survey_nonprob` design, captures `print()` output,
         and asserts it contains `"Non-probability"` and does not contain
         `"Calibrated"`.

    9. Fix B4 in `R/glm-methods.R`:
       - In `.glm_design_type_label()`, change the `survey_nonprob` branch from
         returning `"Calibrated"` to returning `"Non-probability"`.
       - Verify the B4 test passes.

    10. Write failing test for B5 (`confint.survey_glm_fit` error text):
        - In `tests/testthat/test-glm-methods.R`, add a test that calls
          `confint(fit, level = 1.5)` and takes a snapshot of the error. The
          snapshot must contain `"{.arg level}"`, not `"{.arg conf_level}"`.
        - Add `expect_error` checks for `level = 0`, `level = NA`, `level = "a"`,
          all expecting class `surveycore_error_invalid_conf_level`.

    11. Fix B5 in `R/glm-methods.R`:
        - In `confint.survey_glm_fit`, change the `"x"` bullet from
          `"{.arg conf_level} must be a single number..."` to
          `"{.arg level} must be a single number..."`.
        - Verify the B5 tests pass and snapshot is updated.

    12. Write failing test for B6 (`update.survey_glm_fit` wrong error class):
        - In `tests/testthat/test-glm-methods.R`, construct a `survey_glm_fit`
          object whose `@call` slot is `NULL` (manually set after fitting or
          using a helper that produces a no-call object).
        - Assert `expect_error(update(fit_no_call), class = "surveycore_error_update_no_call")`.
        - Assert `expect_snapshot(error = TRUE, update(fit_no_call))`.
        - Assert the snapshot does NOT contain the string `"predict_no_fit"`.

    13. Fix B6 in `R/glm-methods.R`:
        - In `update.survey_glm_fit`, change the `class=` argument from
          `"surveycore_error_predict_no_fit"` to
          `"surveycore_error_update_no_call"`.
        - Update the error message text: change `"{.arg object@call} is NULL"`
          to `"Cannot update {.cls survey_glm_fit}: {.field @call} is NULL."`.
        - Verify the B6 tests pass.

    14. Write failing test for D20 / E3 (`survey_collection` unnamed-surveys condition):
        - In `tests/testthat/test-survey-collection.R`, add tests that construct
          an unnamed collection (no names, empty-string names, NA names) and
          assert `class = "surveycore_error_collection_unnamed"`.
        - Add a regression test that an empty collection still raises
          `surveycore_error_collection_empty`.

    15. Fix D20 / E3 in `R/core-classes.R`:
        - In the `survey_collection` S7 validator, change `class=` on the
          unnamed-surveys branch from `"surveycore_error_collection_empty"` to
          `"surveycore_error_collection_unnamed"`.
        - Verify the D20/E3 tests pass.

    16. Write failing test for D56 / E4 (`remove_survey()` invalid `name` type):
        - In `tests/testthat/test-survey-collection.R`, add tests for
          `remove_survey(coll, name = 1L)`, `remove_survey(coll, name = TRUE)`,
          and `remove_survey(coll, name = NULL)`, each asserting
          `class = "surveycore_error_invalid_name_type"`.
        - Add snapshot test for `remove_survey(coll, name = 1L)`.
        - Add regression test that non-survey_collection `x` still raises
          `surveycore_error_not_survey_collection`.
        - Add edge-case test that `name = NA_character_` raises
          `surveycore_error_collection_name_not_found`.

    17. Fix D56 / E4 in `R/survey-collection.R`:
        - In `remove_survey()`, add a type check before the name-lookup that
          raises `surveycore_error_invalid_name_type` when `name` is not a
          character vector.
        - Verify all D56/E4 tests pass.

    18. Write failing test for X6 (`.vcov_pair_taylor()` error class split):
        - In `tests/testthat/test-variance-taylor.R`, add a test that triggers
          the `lonely.psu = "fail"` branch (single-PSU stratum with failing
          option) and asserts `class = "surveycore_error_lonely_psu"`.
        - Add a test that passes an unknown `lonely.psu` value and asserts
          `class = "surveycore_error_lonely_psu_unknown_option"`, plus snapshot.
        - Verify both tests fail before the fix.

    19. Fix X5 and X6 in `R/variance-taylor.R`:
        - Remove the unused `n_full <- nrow(data)` assignment (X5).
        - In `.vcov_pair_taylor()`, change the fall-through `cli_abort()` branch
          `class=` from `"surveycore_error_lonely_psu"` to
          `"surveycore_error_lonely_psu_unknown_option"` (X6).
        - Verify both X5 and X6 tests pass.

    20. Write failing test for D44 (`.check_is_survey()` cli bullet fix):
        - In `tests/testthat/test-metadata-system.R` (or wherever
          `.check_is_survey()` is exercised), verify that calling a metadata
          function on a non-survey object produces a snapshot that does not
          contain a bare `" "` space key, and that the `"v"` bullet includes
          all three constructor function names.

    21. Fix D44 in `R/core-metadata.R`:
        - In `.check_is_survey()`, remove the `" " = "or {.fn as_survey_twophase}."` bullet.
        - Merge that text into the `"v"` bullet using `paste0()` so it reads:
          `"Create a survey object with {.fn as_survey}, {.fn as_survey_replicate}, or {.fn as_survey_twophase}."`.
        - Verify the D44 test passes.

    22. Write failing test for D45 (`extract_sata()` fill error class):
        - In `tests/testthat/test-metadata-system.R`, add a test that calls
          `extract_sata(design, x, fill = "yes")` and asserts
          `class = "surveycore_error_fill_not_logical"`.
        - Add snapshot test for `extract_sata(design, x, fill = "yes")`.
        - Add `expect_error(extract_sata(design, x, fill = 1L), class = "surveycore_error_fill_not_logical")`.
        - Add regression test that `set_sata(design, x, sata = "yes")` still
          raises `surveycore_error_sata_not_logical`.

    23. Fix D45 in `R/core-metadata.R`:
        - In `extract_sata()`, change the `class=` on the invalid-`fill` branch
          from `"surveycore_error_sata_not_logical"` to
          `"surveycore_error_fill_not_logical"`.
        - Verify all D45 tests pass.

    24. Add `@method` tags to `print.survey_t_test` and `print.survey_pairwise`
        in `R/analysis-t-test.R` (D74). Run `devtools::document()` and confirm
        `NAMESPACE` is updated correctly.

    25. Confirm test coverage for E2 (`surveycore_error_all_replicates_na`):
        - In `tests/testthat/test-variance-replicate.R`, check whether a test
          for this error class already exists. If absent, add a direct test of
          `.svy_rep_var()` with all-NA `thetas` using `expect_error(class = ...)` plus
          snapshot. This is registration-only for `plans/error-messages.md`; the
          code already raises the correct class.

    26. Run `devtools::document()`, `devtools::test()`, `devtools::check()`.
        Confirm 0 errors, 0 warnings.

  - **Acceptance criteria**
    - All new rows exist in `plans/error-messages.md` before any PR is opened.
    - `tests/testthat/test-analysis-t-test.R`: `print.survey_t_test` and
      `print.survey_pairwise` tests with unlabeled `by` variable pass —
      output contains raw column name, not blank.
    - `tests/testthat/test-analysis-corr-latent.R`: boundary warning snapshot
      contains `"1e-4"`, not `"1e-6"`.
    - `tests/testthat/test-glm-methods.R`: `print()` output for a
      `survey_nonprob` fit contains `"Non-probability"`, not `"Calibrated"`.
    - `tests/testthat/test-glm-methods.R`: `confint()` error snapshot contains
      `level`, not `conf_level`; `update()` with `@call = NULL` raises
      `surveycore_error_update_no_call` (snapshot contains no `"predict_no_fit"`).
    - `tests/testthat/test-survey-collection.R`: unnamed-surveys branch raises
      `surveycore_error_collection_unnamed`; empty-collection branch still raises
      `surveycore_error_collection_empty` (regression). `remove_survey()` with
      non-character `name` raises `surveycore_error_invalid_name_type`.
    - `tests/testthat/test-variance-taylor.R`: `lonely.psu = "fail"` raises
      `surveycore_error_lonely_psu`; unknown option raises
      `surveycore_error_lonely_psu_unknown_option` (distinct classes).
    - `tests/testthat/test-metadata-system.R`: `extract_sata(fill = "yes")`
      raises `surveycore_error_fill_not_logical`; `set_sata(sata = "yes")`
      still raises `surveycore_error_sata_not_logical` (regression).
    - `devtools::test()` passes with no failures.
    - `devtools::check()` passes: 0 errors, 0 warnings, ≤ 2 pre-approved notes.

  - **Files touched**
    - `plans/error-messages.md`
    - `R/analysis-t-test.R`
    - `R/analysis-corr-latent.R`
    - `R/glm-methods.R`
    - `R/core-classes.R`
    - `R/survey-collection.R`
    - `R/variance-taylor.R`
    - `R/core-metadata.R`
    - `tests/testthat/test-analysis-t-test.R`
    - `tests/testthat/test-analysis-corr-latent.R` (or `test-analysis-corr.R`)
    - `tests/testthat/test-glm-methods.R`
    - `tests/testthat/test-survey-collection.R`
    - `tests/testthat/test-variance-taylor.R`
    - `tests/testthat/test-variance-replicate.R`
    - `tests/testthat/test-metadata-system.R`

  - **Pipeline split**: optional


- [x] PR 2: feature/doc-fixes-pr2 — Documentation-only corrections (D1–D75, W1–W3, S1–S7, T1–T5, M1–M4, X1–X13)
  - **Tasks** (2–5 min each; grouped by file or theme; no TDD sub-steps needed — doc-only)

    1. `R/core-constructors.R` — `@param` corrections (D1, D2, D3, S2, X2):
       - D1: Fix `@param mse` in `as_survey_replicate()` — remove false claim
         that default differs between functions.
       - D2: Fix `@param scale` in `as_survey_replicate()` — replace
         `"NULL sets 1/R"` with type-specific description.
       - D3: Fix `@details` in `as_survey_twophase()` — change "issues a warning
         and falls back" to "an error is raised".
       - S2: Update all three stale file paths in internal comments.
       - X2: Replace `coll3@groups` with function-call style in `@examples`.

    2. `R/core-classes.R` — tag and example corrections (D9, S1, T3, X1):
       - D9: Fix `survey_nonprob` `@section` — add `"JK1"`, `"JK2"`, `"JKn"` to
         the supported replicate types list.
       - S1: Update stale path `R/03-constructors.R` → `R/core-constructors.R`
         in comments.
       - T3: Drop `@keywords internal` from `survey_nonprob` (keep
         `@family constructors`).
       - X1: Replace direct `@` property access in `@examples` with
         function-call style.

    3. `R/core-metadata.R` — param/header fixes (D42, D43, D44 doc part, D45 doc part, X4):
       - D42: Fix `@param fill` in `extract_val_labels()` — clarify that in
         `"data_frame"` format, variables with no labels are always excluded.
       - D43: Fix `@param fill` in `extract_missing_codes()` — same.
       - X4: Update the file header function list to cover all ~25+ exported
         functions.
       (D44 code fix is in PR 1; D45 code fix is in PR 1.)

    4. `R/core-validators.R` — stale path fix (S3):
       - S3: Update stale file paths in comments.

    5. `R/utils.R` — contradictory tag fixes (T1, T2, X12):
       - T1: Drop `@keywords internal` from `SURVEYCORE_DOMAIN_COL` (keep
         `@export`).
       - T2: Drop `@keywords internal` from `.get_design_vars_flat` (keep
         `@export`).
       - X12: Change `@family constructors` to `@family accessors` for
         `survey_data()`.

    6. `R/analysis-helpers.R` — stale comment corrections (D6, D7, D32):
       - D6: Fix comment — `survey_nonprob` returns `Inf` degrees of freedom,
         not `n - 1`.
       - D7: Fix comment — "four" concrete design classes, not five.
       - D32: Fix `@return` for `.mean_domain_vec()` — remove stale `design`
         parameter reference.

    7. `R/analysis-means.R` — `@return` and `@param` corrections (D4, D17, D24):
       - D4: Fix `@return` — `meta(result)$variable` → `meta(result)$x`.
       - D17: Fix `@param label_values` — replace "no visible effect" with the
         standard API-consistency phrasing.
       - D24: Add `df` column note for calibrated Taylor designs.

    8. `R/analysis-totals.R` — `@return`, `@param`, and `@param ...` fixes
       (D5, D19, D37):
       - D5: Fix `@return` — `meta(result)$variable` → `meta(result)$x`.
       - D19: Fix `@param label_values` — standard API-consistency phrasing.
       - D37: Fix `@param ...` — change "unused" to note forwarding to
         `.dispatch_over_collection()`.

    9. `R/analysis-totals-helpers.R` — `@return` and `@param` additions
       (D25, D26, D27, D28):
       - D25: Remove `survey_nonprob` from `@param design` in
         `.taylor_total_cell()`.
       - D26: Add `df` field to `@return` of `.taylor_total_cell()`.
       - D27: Add `survey_nonprob` (with repweights) to `@param design` in
         `.replicate_total_cell()`.
       - D28: Add `df` for Taylor path in `.total_cell()` `@return`.

    10. `R/analysis-means-helpers.R` — stale comment and `@return` fixes
        (D29, D30, D31, D32):
        - D29: Remove `survey_nonprob` from `@param design` in
          `.taylor_mean_cell()`.
        - D30: Add `df` field to `@return` of `.taylor_mean_cell()`.
        - D31: Add `df` for Taylor path in `.mean_cell()` `@return`.
        - D32 (second instance): Fix `@return` for `.mean_domain_vec()`.

    11. `R/analysis-quantiles.R` — `@param` corrections (D10, D15, D18):
        - D10: Fix `@param na.rm` — NAs cause all estimates to be `NA_real_`,
          not "included".
        - D15: Fix `@return n` — when `na.rm = FALSE`, `n` counts all
          active-domain rows including NAs.
        - D18: Fix `@param label_values` — standard API-consistency phrasing.

    12. `R/analysis-ratios.R` — `@param` correction (D16):
        - D16: Fix `@param label_values` — standard API-consistency phrasing
          noting no value-level cells appear in the output.

    13. `R/analysis-variance.R` — `@return`, `@param`, mixed comment fix, and
        example correction (D21, D22, D23, M3, W1):
        - D21: Add `[.id]` column note for `survey_collection` to `@return`.
        - D22: Distinguish `variance` vs `var` columns in `@return`.
        - D23: Fix `@param label_values` — standard API-consistency phrasing.
        - M3: Convert `.attach_variance_labels` block to consistent `#` style
          (no mixed `#`/`#'`).
        - W1: Change example weight column from `wtint2yr` to `wtmec2yr`.

    14. `R/analysis-corr.R` — `@param` and `@return` corrections, example fix
        (D33, D34, D35, D36, W2):
        - D33: Fix `get_corr()` `@return` — note that `r` and `statistic` are
          method-specific; `df` is `NA_integer_` for latent methods.
        - D34: Fix `@param na.rm` — correct NA handling description.
        - D35: Fix `@param decimals` — document that `decimals` is silently
          ignored for `format = "wide"`.
        - D36: Fix `@param ...` for `get_freqs()` and `get_totals()` — correct
          "unused" claim (also requires change in `R/analysis-freqs.R` for D36).
        - W2: Change example weight column from `wtint2yr` to `wtmec2yr`.

    15. `R/analysis-freqs.R` — `@param ...` correction (D36 second instance):
        - D36: Correct "unused" to note forwarding to
          `.dispatch_over_collection()`.

    16. `R/analysis-freqs-helpers.R` — stale comment correction (D8):
        - D8: Remove false delegation claim for `.calibrated_freq_cell()`.

    17. `R/analysis-covariance.R` — example correction (W3):
        - W3: Change example weight column from `wtint2yr` to `wtmec2yr`.

    18. `R/analysis-covariance-helpers.R` — mixed comment fix (M4):
        - M4: Convert `.attach_covariance_labels` block to consistent comment
          style.

    19. `R/analysis-diffs.R` — `@details` and example corrections (D13, D71):
        - D13: Add note that non-Gaussian `scale = "link"` also takes the clean
          path.
        - D71: Remove unnecessary `library(marginaleffects)` from example that
          does not use it.

    20. `R/analysis-meta.R` — `@return` correction and contradictory tag fixes
        (D39, T3, T4, T5):
        - D39: Remove `"srs"` as a valid `design_type` from `meta()` `@return`.
        - T3 (second instance): Drop `@keywords internal` from `print.survey_result`
          (keep `@export`).
        - T4: Drop `@keywords internal` from `print.survey_diffs` (keep
          `@export`).
        - T5: Same for any remaining contradictory tags in this file.

    21. `R/glm.R` — `@details` and formula comment corrections (D11, D40, D41):
        - D11: Change "five design classes" to four in `@details`; note
          `survey_collection` is rejected.
        - D40: Correct bread formula to `(X'W̃X)^(-1)`.
        - D41: Update `@param degf` — SRS absorbed into taylor; add
          `survey_nonprob` returns `Inf`; add `survey_twophase` behavior.

    22. `R/glm-methods.R` — stale count comment correction (D60):
        - D60: Update method count comment from `"20 + getCall"` to
          `"22 + getCall"` (23 total).

    23. `R/glm-clean.R` — stale comment correction (X9):
        - X9: Correct the comment about `.glm_value_label_for()` — both
          branches return `level_name` identically; remove any implication of
          differentiated behavior.

    24. `R/glm-anova-dispatch.R` — `@return` and `@description` corrections
        (D57, D58, D72):
        - D57: Note renaming of `p_value`/`ddf` when `name_style = "broom"`.
        - D58: Add to `get_anova()` `@description` that the function also
          implements Wald tests.
        - D72: Fix example to use `gss` dataset instead of `gss_2024`.

    25. `R/glm-anova.R` — missing `@method` tag (D59):
        - D59: Add `@rdname`, `@title`, `@param`, and `@return` stubs to
          `anova.survey_glm_fit` and `print.survey_anova` so they are
          documentable.

    26. `R/calibration.R` — `@param`, `@return`, and `@seealso` additions
        (D61, D62, D63):
        - D61: Fix `@return w` — correct description of intermediate quantity
          in `as_caldata()`.
        - D62: Document the near-zero product constraint in `@param`.
        - D63: Add `@seealso` to `as_caldata()` linking to sibling constructors.

    27. `R/metadata-infer.R` — `@description` correction (D64):
        - D64: Clarify `infer_question_prefaces()` `@description` — for data
          frames, prefaces go to `attr(col, "question_preface")`, not a metadata
          object.

    28. `R/methods-compat.R` — stale comment correction (D51):
        - D51: Correct comment — `n_pairs` equals `nrow(x)`, not a
          "unique-pair count".

    29. `R/methods-conversion.R` — `@param` corrections (D49, D50):
        - D49: Fix `@param x` in `as_tbl_svy()` — note `survey_nonprob` is not
          supported.
        - D50: Fix `@param x` in `from_svydesign()` — mention
          `survey::twophase2` dispatch.

    30. `R/methods-print.R` — stale path and comment fixes (S4, X11):
        - S4: Update 9 occurrences of `R/00-s7-classes.R` →
          `R/core-classes.R` in comments.
        - X11: Fix internal title for `survey_nonprob` — drop "Calibrated /
          Non-Probability" to just "Non-Probability".

    31. `R/update-design.R` — `@param`, `@return`, and `@seealso` fixes
        (D46, D47, D48, X3):
        - D46: Fix `@param validate` — replace current description with the
          correct one about suppressing validation during variable update.
        - D47: Add `[as_survey_twophase()]` to `@seealso`.
        - D48: Add `cli_inform()` side-effect note to `@return`.
        - X3: Remove `@family update` tag (no sibling functions; grouping is
          semantically incorrect).

    32. `R/survey-collection.R` — stale comment corrections (D52, D53, D54, D55):
        - D52, D53: Fix call-site counts — "four", not "five".
        - D54: Fix `.resolve_caller_names()` comment to handle both
          `as_survey_collection` and `add_survey()` callers.
        - D55: Note in `remove_survey()` `@return` that the empty-collection
          error is raised by the S7 validator, not `remove_survey()` itself.

    33. `R/variance-taylor.R` — stale path, mixed comment, and Phase-0 comment
        fixes (M1, S5, X7):
        - M1: Convert `.vcov_pair_taylor` block to consistent comment style
          (no mixed `#`/`#'`).
        - S5: Update stale path `R/06-variance-taylor.R` →
          `R/variance-taylor.R`.
        - X7: Remove stale "Phase 0" comment.

    34. `R/variance-replicate.R` — stale path, mixed comment, and stale comment
        fixes (D73, M2, S6):
        - D73: Correct `combined.weights = TRUE` comment — surveycore has no
          alternative mode.
        - M2: Convert `.replicate_estimate` and `.vcov_pair_replicate` blocks to
          consistent comment style.
        - S6: Update stale path `R/06-variance-replicate.R` →
          `R/variance-replicate.R`.

    35. `R/variance-twophase.R` — stale path and formula comment fix (D14, S7):
        - D14: Add the FPC factor `f_s` to the formula comment.
        - S7: Update stale path `R/06-variance-twophase.R` →
          `R/variance-twophase.R`.

    36. `R/analysis-corr-latent.R` — stale file header fix (D70):
        - D70: Replace stale file header with accurate list of functions defined
          in the file.

    37. `R/analysis-effective-n.R` — missing tag (D75):
        - D75: Add `@return x, invisibly.` to `print.survey_effective_n`.
        - Add `@keywords internal` per spec.

    38. `R/analysis-t-test.R` — remaining doc fixes (D38, D74 doc part, D75 second
        instance if applicable):
        - D38: Fix `@param ...` for `get_t_test()` and `get_pairwise()` —
          correct "unused" to note collection forwarding.
        - D74 doc part: Remaining roxygen stubs for `print.survey_t_test` and
          `print.survey_pairwise` (code-level `@method` tags were added in PR 1;
          this task adds any remaining `@return` / `@description` stubs).

    39. `R/srr-stats-standards.R` — stale comment corrections (D65, D66, D67):
        - D65: Change "16 helpers" to "19 helpers".
        - D66: Change `as.factor()` to `factor()`.
        - D67: Remove "planned future phase" note for calibration (shipped in
          PRs #139–142).

    40. `R/zzz.R` — stale comment corrections (D68, D69):
        - D68: Change "20 + getCall" to "22 + getCall".
        - D69: Remove or update cross-reference to `MEMORY.md`.

    41. `R/data.R` — stale reference correction (X10):
        - X10: Fix `ns_wave1` `@references` — correct to July 2019 (Wave 1).

    42. `R/metadata-infer.R` — `@seealso` additions (X13):
        - X13: Add `@seealso` to `set_universe()` and `set_missing_codes()`
          linking to their extractor counterparts.

    43. Run `devtools::document()`. Confirm NAMESPACE is consistent and no
        roxygen tag warnings appear. Run `devtools::run_examples()` and confirm
        all examples pass — in particular: all NHANES examples use `wtmec2yr`,
        no `gss_2024` in examples, no `library(marginaleffects)` without use.
        Run `devtools::check()`. Confirm 0 errors, 0 warnings.

  - **Acceptance criteria**
    - `devtools::document()` runs clean: no warnings about conflicting tags,
      `NAMESPACE` consistent with source.
    - `devtools::run_examples()` runs clean: no errors, no `wtint2yr`,
      no `gss_2024`, no spurious `library()` calls.
    - `R CMD check --as-cran`: 0 errors, 0 warnings, ≤ 2 pre-approved notes.
    - `pkgdown::build_site()` runs clean.
    - `covr::package_coverage()` >= 95% (no coverage regression from doc-only
      changes).

  - **Files touched**
    - `R/analysis-corr-latent.R`
    - `R/analysis-corr.R`
    - `R/analysis-covariance.R`
    - `R/analysis-covariance-helpers.R`
    - `R/analysis-diffs.R`
    - `R/analysis-effective-n.R`
    - `R/analysis-freqs-helpers.R`
    - `R/analysis-freqs.R`
    - `R/analysis-helpers.R`
    - `R/analysis-means-helpers.R`
    - `R/analysis-means.R`
    - `R/analysis-meta.R`
    - `R/analysis-quantiles.R`
    - `R/analysis-ratios.R`
    - `R/analysis-t-test.R`
    - `R/analysis-totals-helpers.R`
    - `R/analysis-totals.R`
    - `R/analysis-variance.R`
    - `R/calibration.R`
    - `R/core-classes.R`
    - `R/core-constructors.R`
    - `R/core-metadata.R`
    - `R/core-validators.R`
    - `R/data.R`
    - `R/glm-anova-dispatch.R`
    - `R/glm-anova.R`
    - `R/glm-clean.R`
    - `R/glm-methods.R`
    - `R/glm.R`
    - `R/metadata-infer.R`
    - `R/methods-compat.R`
    - `R/methods-conversion.R`
    - `R/methods-print.R`
    - `R/srr-stats-standards.R`
    - `R/survey-collection.R`
    - `R/update-design.R`
    - `R/utils.R`
    - `R/variance-replicate.R`
    - `R/variance-taylor.R`
    - `R/variance-twophase.R`
    - `R/zzz.R`

  - **Pipeline split**: optional
