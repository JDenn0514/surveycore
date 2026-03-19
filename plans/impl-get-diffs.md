# Implementation Plan — `get_diffs()`

## Overview

This plan implements treatment effect estimation via `get_diffs()`, building on
the Phase 2 GLM infrastructure (`survey_glm()`, `clean()`, marginaleffects
extension) and Phase 1 analysis function patterns. The spec is at
`plans/spec-get-diffs.md` (v1.5, methodology-locked, code-reviewed through
Pass 3).

Two PRs: (1) shared infrastructure changes to existing helpers, plus the
`get_diffs()`-specific helpers and print method; (2) the `get_diffs()` function
itself with all three test files.

---

## PR Map

- [x] PR 1: `feature/diffs-infrastructure` — Shared helper changes + `.stars_pval()` + `print.survey_diffs()` + error class registration (PR #77)
- [x] PR 2: `feature/get-diffs` — `get_diffs()` function + all tests (happy path, error path, edge case, numerical oracle, marginaleffects path) (PR #78)

---

## PR 1: Diffs Infrastructure

**Branch:** `feature/diffs-infrastructure`
**Depends on:** none (builds on develop)

**Files (in TDD order — tests first):**
- `tests/testthat/test-analysis-diffs-helpers.R` — tests for `.stars_pval()` and `.apply_name_style(exclude)`
- `R/analysis-diffs-helpers.R` — `.stars_pval()` internal helper
- `R/analysis-helpers.R` — add `DIFFS_META_KEYS` constant + `exclude` parameter on `.apply_name_style()`
- `R/analysis-meta.R` — add `print.survey_diffs()` method
- `plans/error-messages.md` — add 9 new error/warning classes for `get_diffs()`

**Acceptance criteria:**
- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] `.stars_pval()` tested for all cutpoints (0.001, 0.01, 0.05, 0.1) + NA handling + boundary values
- [ ] `.apply_name_style(exclude = "mean")` tested: `mean` column preserved, other columns renamed
- [ ] `.apply_name_style(exclude = NULL)` backward-compatible with all existing call sites
- [ ] `print.survey_diffs()` snapshot test (requires manually constructing a `survey_diffs` object)
- [ ] 98%+ line coverage on `R/analysis-diffs-helpers.R`
- [ ] All 9 new error/warning classes documented in `plans/error-messages.md`
- [ ] Changelog entry written and committed on this branch

**Notes:**
- `print.survey_diffs()` can be snapshot-tested by manually constructing a
  `survey_diffs` tibble with the right class vector and `.meta` attributes.
  No need for a working `get_diffs()`.
- The `.apply_name_style()` change adds `exclude = NULL` as a default parameter.
  All 6 existing call sites pass only 2 arguments (`result, name_style`) and
  are unaffected. Verify with `devtools::check()`.
- `DIFFS_META_KEYS` has 10 entries (more than Phase 1 functions which have 2–3):
  `"group"`, `"x"`, `"treats"`, `"covariates"`, `"family"`, `"link"`,
  `"pval_adj"`, `"estimate_method"`, `"mean_method"`, `"estimate_scale"`.

### Tasks

#### 1. Tests for `.stars_pval()`

1.1. Create `tests/testthat/test-analysis-diffs-helpers.R`. Write tests for
     `.stars_pval()`:
     - `p = 0.0005` → `"***"` (below 0.001)
     - `p = 0.005` → `"**"` (below 0.01)
     - `p = 0.03` → `"*"` (below 0.05)
     - `p = 0.08` → `"."` (below 0.1)
     - `p = 0.15` → `""` (above 0.1)
     - `p = NA` → `""`
     - Boundary values: `p = 0.001` → `"**"` (equals cutpoint, not below)
     - Boundary: `p = 0.01` → `"*"`
     - Boundary: `p = 0.05` → `"."` (equals cutpoint, not below)
     - Boundary: `p = 0.1` → `""` (equals cutpoint, not below)
     - Vector input: verify vectorized behavior

1.2. Run tests → confirm all fail (`.stars_pval()` does not exist yet).

#### 2. Implement `.stars_pval()`

2.1. Create `R/analysis-diffs-helpers.R`. Implement `.stars_pval(p)`:
     - Use `dplyr::case_when()` or base `ifelse()` chain with cutpoints:
       `*** < 0.001`, `** < 0.01`, `* < 0.05`, `. < 0.1`, `""` otherwise.
     - `NA` p-values → `""`.
     - Returns character vector same length as `p`.
     - **Use base R** (no dplyr dependency for a helper): nested `ifelse()` or
       `cut()` + level mapping.

2.2. Run tests → confirm all pass.

#### 3. Tests for `.apply_name_style(exclude)`

3.1. In `test-analysis-diffs-helpers.R`, add tests for the new `exclude`
     parameter on `.apply_name_style()`:
     - `exclude = "mean"` with `name_style = "broom"`: `mean` column stays as
       `mean`, `se` → `std.error`, `ci_low` → `conf.low`, `ci_high` →
       `conf.high`, `p_value` → `p.value`, `estimate` → `estimate`.
     - `exclude = NULL` (default): existing behavior unchanged — `mean` would
       be renamed to `estimate` (matching Phase 1 behavior).
     - `exclude = "mean"` with `name_style = "surveycore"`: no-op (returns
       unchanged).
     - Verify `.meta` attribute and S3 class are preserved across rename with
       `exclude`.

3.2. Run tests → confirm the `exclude` tests fail (parameter doesn't exist
     yet).

#### 4. Implement `.apply_name_style(exclude)` change

4.1. In `R/analysis-helpers.R`, modify `.apply_name_style()` signature from
     `.apply_name_style(result, name_style)` to
     `.apply_name_style(result, name_style, exclude = NULL)`.
     After computing `to_rename`, add:
     ```r
     if (!is.null(exclude)) {
       to_rename <- setdiff(to_rename, exclude)
     }
     ```

4.2. Run tests → confirm all pass (including existing test suites for Phase 1
     functions).

#### 5. Add `DIFFS_META_KEYS` constant

5.1. In `R/analysis-helpers.R`, after the existing `RATIOS_META_KEYS` line,
     add:
     ```r
     DIFFS_META_KEYS <- c(
       "group", "x", "treats", "covariates", "family", "link",
       "pval_adj", "estimate_method", "mean_method", "estimate_scale"
     )
     ```

#### 6. Implement `print.survey_diffs()`

6.1. In `test-analysis-diffs-helpers.R`, add a snapshot test for
     `print.survey_diffs()`. Manually construct a `survey_diffs` object:
     ```r
     mock_diffs <- tibble::tibble(
       message_arm = factor(c("Control", "Msg A", "Msg B")),
       estimate    = c(0, 0.082, 0.103),
       mean        = c(0.401, 0.483, 0.504),
       n           = c(752L, 748L, 751L),
       ci_low      = c(NA, 0.042, 0.063),
       ci_high     = c(NA, 0.122, 0.143),
       p_value     = c(NA, 0.001, 0.000),
       stars       = c("", "**", "***")
     )
     attr(mock_diffs, ".meta") <- list(
       design_type     = "taylor",
       conf_level      = 0.95,
       call            = quote(get_diffs(d, agree_trope, message_arm)),
       n_respondents   = 2251L,
       group           = list(),
       x               = list(agree_trope = list(
         variable_label = "Agree with trope", question_preface = NULL,
         value_labels = NULL
       )),
       treats          = list(
         variable_label = "Message arm", question_preface = NULL,
         value_labels = NULL, name = "message_arm", ref_level = "Control"
       ),
       covariates      = NULL,
       family          = "gaussian",
       link            = "identity",
       pval_adj        = NULL,
       estimate_method = "coefficient",
       mean_method     = "intercept",
       estimate_scale  = "coefficient"
     )
     class(mock_diffs) <- c("survey_diffs", "survey_result",
                            "tbl_df", "tbl", "data.frame")
     ```
     Use `expect_snapshot(print(mock_diffs))` to verify the 4 header lines.

6.2. Run test → confirm failure (`print.survey_diffs` does not exist).

6.3. In `R/analysis-meta.R`, below `print.survey_result()`, add
     `print.survey_diffs()`:
     - Line 1: `# A survey_diffs result`
     - Line 2: `# Design: {design_type} | Family: {family} ({link})`
       where `design_type` is title-cased from `.meta$design_type`
       (e.g., `"taylor"` → `"Taylor series"`).
     - Line 3: `# DV: {x_name} | Treatment: {treats_name} (ref: {ref_level})`
       using `.meta$x` (first name), `.meta$treats$name`, `.meta$treats$ref_level`.
     - Line 4: `# Method: {estimate_method} / {mean_method}`
     - Then delegate to `NextMethod()` for the tibble body.
     - Return `invisible(x)`.
     - **Design type display names:** `"taylor"` → `"Taylor series"`,
       `"replicate"` → `"Replicate weights"`, `"twophase"` → `"Two-phase"`,
       `"calibrated"` → `"Calibrated"`.
       (Note: `.build_meta()` maps `survey_nonprob` to `"calibrated"`.
       A future rename is tracked in `plans/future/rename-nonprob-design-type.md`.)
     - Use roxygen `#' @method print survey_diffs` + `#' @export` above
       the function definition (matching the `print.survey_result()` pattern).
       Do NOT register in `zzz.R` — `survey_diffs` is a plain S3 class,
       not an S7 namespaced class.

6.4. Run tests → confirm snapshot passes.

#### 7. Update error-messages.md

7.1. In `plans/error-messages.md`, add 9 new rows after row 91 (the last
     existing row). New classes:

| # | Function | Condition | Level | Error Class | Message |
|---|---|---|---|---|---|
| 92 | `get_diffs()` | `x` resolves to != 1 column | ERROR | `surveycore_error_wrong_variable_count` | `"{.arg x} must select exactly one column."` |
| 93 | `get_diffs()` | `treats` resolves to != 1 column | ERROR | `surveycore_error_treats_single` | `"{.arg treats} must select exactly one column."` |
| 94 | `get_diffs()` | `ref_level` not in levels of treats | ERROR | `surveycore_error_ref_level_not_found` | `"{.arg ref_level} {.val {ref_level}} not found in levels of {.field {treats_name}}."` |
| 95 | `get_diffs()` | `treats` has < 2 levels after NA removal | ERROR | `surveycore_error_treats_one_level` | `"{.arg treats} must have at least 2 levels. {.field {treats_name}} has only 1."` |
| 96 | `get_diffs()` | `pval_adj` not a valid method | ERROR | `surveycore_error_invalid_pval_adj` | `"{.arg pval_adj} must be a valid method for {.fn stats::p.adjust}."` |
| 97 | `get_diffs()` | `covariates` is not character | ERROR | `surveycore_error_covariates_not_character` | `"{.arg covariates} must be a character vector of model terms."` |
| 98 | `get_diffs()` | `clean()` output missing intercept | ERROR | `surveycore_error_reference_row_not_found` | `"Reference row not found in model output. Expected exactly one intercept row."` |
| 99 | `get_diffs()` | `show_pct_change = TRUE` and ref mean is 0 | WARN | `surveycore_warning_pct_change_zero_ref` | `"Reference group mean is 0; percentage change is undefined."` |
| 100 | `get_diffs()` | `treats` column not a factor | WARN | `surveycore_warning_treats_coerced` | `"{.field {treats_name}} coerced to factor."` |

Also update the coverage map table to add:
`test-analysis-diffs.R` covers rows 43 (reused), 45/45a/45b/46 (reused),
49 (reused), 64 (reused), 81 (reused), 92–100 (new).

#### 8. Final checks for PR 1

8.1. Run `devtools::document()`.

8.2. Run `devtools::check()` — 0 errors, 0 warnings, ≤2 pre-approved notes.

8.3. Verify all existing test suites still pass (no regressions from
     `.apply_name_style()` change).

---

## PR 2: `get_diffs()` Function

**Branch:** `feature/get-diffs`
**Depends on:** PR 1 (`feature/diffs-infrastructure`)

**Files (in TDD order — tests first):**
- `tests/testthat/test-analysis-diffs.R` — happy paths + error paths + edge cases + snapshots
- `tests/testthat/test-analysis-diffs-numerical.R` — oracle tests vs `survey` + manual computation
- `tests/testthat/test-analysis-diffs-marginaleffects.R` — `avg_slopes`/`avg_predictions` path tests
- `R/analysis-diffs.R` — `get_diffs()` exported function
- `DESCRIPTION` — move `marginaleffects` from Suggests to Imports

**Acceptance criteria:**
- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] Error path tests: one `test_that()` per error class (dual pattern: `expect_error(class=)` + `expect_snapshot(error=TRUE)`)
- [ ] Happy path tests: bivariate gaussian, with group, with covariates, covariates+group, non-gaussian (quasibinomial), all 4 design classes, show_means=FALSE, show_pct_change=TRUE, pval_adj, all variance combos, ref_level, decimals, label_values, name_style, n_weighted, min_cell_n, domain estimation, print snapshot
- [ ] Edge case tests: 2 levels, 10+ levels, treats-as-character, ref-mean-zero, single-obs-level, all-NA-level, group-with-1-value, na.rm=FALSE+NAs, gaussian ame==link, link+non-gaussian suppression
- [ ] Numerical oracle tolerance: point 1e-10, SE 1e-8, CI 1e-6 (marginaleffects path); point 1e-8, SE 1e-6 (clean path)
- [ ] `.meta` contract verified on every happy path test
- [ ] Column-level labels tested (every column has `label` attribute)
- [ ] 98%+ line coverage on `R/analysis-diffs.R`
- [ ] `marginaleffects` moved from Suggests to Imports in DESCRIPTION
- [ ] Changelog entry written and committed on this branch

**Notes:**
- The function has two estimation paths (clean + marginaleffects) that must
  be implemented together — they share the same output assembly logic.
- Use `make_survey_data()` from `helper-test-data.R` for test data. For
  treatment effect tests, add a factor column to the synthetic data.
- Domain estimation tests are gated with `skip_if_not_installed("surveytidy")`.
- Marginaleffects tests gated with `skip_if_not_installed("marginaleffects")`.
- Numerical oracle tests gated with `skip_if_not_installed("survey")` and
  `skip_if_not_installed("marginaleffects")`.
- The `survey_diffs` class vector is:
  `c("survey_diffs", "survey_result", "tbl_df", "tbl", "data.frame")`.
- When moving `marginaleffects` to Imports, also update the minimum version
  pin: `marginaleffects (>= 0.18.0)` (required for `df` argument support).

### Tasks

#### Phase A: Error path tests + argument validation

A.1. Create `tests/testthat/test-analysis-diffs.R`. Write error path tests
     (one `test_that()` per error class, dual pattern):
     - `surveycore_error_unsupported_class` — pass a plain data.frame
     - `surveycore_error_wrong_variable_count` — `x` resolving to 0 or 2 columns
     - `surveycore_error_treats_single` — `treats` resolving to 0 or 2 columns
     - `surveycore_error_non_numeric_variable` — `x` is character/factor
     - `surveycore_error_treats_one_level` — treats with only 1 unique value
     - `surveycore_error_ref_level_not_found` — ref_level = "nonexistent"
     - `surveycore_error_invalid_pval_adj` — pval_adj = "invalid_method"
     - `surveycore_error_covariates_not_character` — covariates = 42
     - `surveycore_error_na_rm_not_logical` — na.rm = "yes" (reused)
     - `surveycore_error_invalid_variance_arg` — variance = "deff" (reused)
     - `surveycore_error_invalid_conf_level` — conf_level = 2 (reused)
     - `surveycore_error_invalid_name_style` — name_style = "tidy" (reused)

A.2. Run tests → confirm all fail.

A.3. Create `R/analysis-diffs.R`. Implement the function skeleton with roxygen
     and argument validation only (Steps 1–8 from spec Section VII):
     - `@export` with full roxygen docs (signature, `@param`, `@return`,
       `@details`, `@examples`, `@family analysis`)
     - Step 1: `.validate_shared_args()` with
       `valid_variance = c("se", "ci")`
     - Step 2: `.check_unsupported_class(design, "get_diffs")`
     - Step 3: Resolve `x`, `treats`, `group` via tidy-select
       (`rlang::ensym()` + `rlang::as_name()` for single-column;
       `.resolve_groups()` for group)
     - Step 4: Validate `x` is numeric; validates `treats` has ≥ 2 levels
     - Step 4a: Validate `covariates` is character or NULL; validate `pval_adj`
     - Step 5: Handle `ref_level` (default or validate user-supplied)
     - Step 6: `na.rm` → `na.action` translation
     - Step 7: Coerce treats to factor + relevel + force `contr.treatment`
     - Step 8: Build formula via `stats::reformulate()`
     - **Stop here** — no estimation logic yet. The function should error
       with "not yet implemented" after formula construction, or just
       return NULL. The goal is to pass the error path tests.

A.4. Run `devtools::document()`.

A.5. Run error path tests → confirm all pass.

#### Phase B: Clean path (bivariate + gaussian + no group)

B.1. Write happy path test: "bivariate gaussian, no group" — basic
     `DV ~ treats` with `survey_taylor` design.
     Create test data: `make_survey_data()` + add a 3-level treatment factor
     and a continuous DV (e.g., `treats = sample(c("A", "B", "C"), n, replace = TRUE)`,
     `dv = rnorm(n, mean = ifelse(treats == "A", 0.4, ifelse(treats == "B", 0.5, 0.45)), sd = 0.3)`).
     Assert: correct class, correct number of rows (3 with ref + 2 treatment),
     correct column names, reference row has estimate = 0, all non-ref rows
     have non-NA estimates, `.meta$estimate_method == "coefficient"`,
     `.meta$mean_method == "intercept"`, `.meta$family == "gaussian"`.

B.2. Write happy path test: "show_means = FALSE" — no reference row, no
     `mean` column.
     Assert: 2 rows (not 3), no `mean` column, no row with estimate = 0.

B.3. Write happy path test: "show_pct_change = TRUE" — `pct_change` column
     present.
     Assert: `pct_change` column present, reference row pct_change = NA,
     non-ref rows have numeric pct_change values.

B.4. Write happy path test: "ref_level specified" — different reference level.
     Assert: specified level appears as reference row (estimate = 0).

B.5. Write happy path test: "variance = 'se'" — SE present, no CI columns.
     Assert: `se` column present, no `ci_low`/`ci_high`.

B.6. Write happy path test: "variance = c('se', 'ci')" — both present.

B.7. Write happy path test: "variance = NULL" — no SE or CI columns.

B.8. Write happy path test: "decimals" — numeric columns rounded.
     Assert: values are rounded to specified decimal places.

B.8a. Write happy path test: "decimals + pct_change rounds to decimals + 2" —
      `get_diffs(d, dv, treats, show_pct_change = TRUE, decimals = 2)`.
      Assert: `estimate` rounded to 2 places, `pct_change` rounded to 4
      places (not 2). Verifies the `decimals + 2` rule from spec Section 3.12.

B.9. Write happy path test: "pval_adj = 'BH'" — p-values adjusted.
     Assert: `.meta$pval_adj == "BH"`, p_values differ from unadjusted.

B.10. Write happy path test: "label_values = TRUE" — treats column has factor
      labels from metadata.

B.11. Write happy path test: "label_values = FALSE" — treats column has raw
      codes.

B.12. Write happy path test: "name_style = 'broom'" — columns renamed,
      `mean` excluded from rename.
      Assert: `std.error`, `conf.low`, `conf.high`, `p.value` present;
      `mean` still named `mean` (not `estimate`).

B.13. Write happy path test: "n_weighted = TRUE" — `n_weighted` column present.

B.14. Write happy path test: "min_cell_n custom" — warning fires at threshold.
      Create data with one treatment level having very few observations.
      Assert: `expect_warning(class = "surveycore_warning_small_cell")`.

B.15. Write happy path test: "column labels set on all columns".
      ```r
      for (col in names(result)) {
        expect_false(is.null(attr(result[[col]], "label")))
      }
      ```

B.16. Write happy path test: "print snapshot" — `expect_snapshot(print(result))`
      verifying all 4 header lines + tibble body.

B.17. Run tests → confirm all B.* tests fail.

B.18a. Call `survey_glm()` and determine estimation path (Steps 9–10):
       - Call `survey_glm(design, formula, na.action, ...)`
       - `scale <- match.arg(scale)`
       - Determine `use_marginaleffects` per spec Section 7.2
       - For this phase, only the clean path fires (bivariate + gaussian +
         no group). Add the marginaleffects branch as a placeholder that
         errors with "not yet implemented".

B.18b. Extract estimates via `clean()` for the clean path (Step 11):
       - `clean(fit, conf_level = conf_level, include_reference = TRUE)`
       - Extract reference mean from intercept row (defensive check:
         exactly one `(Intercept)` row, else
         `surveycore_error_reference_row_not_found`)
       - Extract treatment rows: `estimate`, `se`, `ci_low`, `ci_high`,
         `p_value` from non-reference, non-intercept rows
       - Compute `mean = reference_mean + estimate` for each treatment row

B.18c. Compute domain-aware `n` per treatment level (Step 12):
       - Always compute `n` from `design@data` (not from `clean()`) —
         one code path for all cases
       - If `..surveycore_domain..` column exists, count only in-domain rows
       - If `n_weighted = TRUE`, compute sum of weights per treatment level
       - Fire `surveycore_warning_small_cell` for levels below `min_cell_n`

B.18d. Apply `pval_adj` and link-scale suppression (Steps 13–14):
       - If `pval_adj` is non-NULL, apply `stats::p.adjust()` to
         comparison rows (exclude reference row where `estimate == 0`)
       - Link-scale suppression check: if `scale = "link"` and family is
         non-gaussian, set flags to omit `mean` and `pct_change` columns
         (no-op for gaussian in this phase)

B.18e. Compute `pct_change` + assign stars (Steps 15–16):
       - If `show_pct_change = TRUE` and not suppressed: `pct_change =
         estimate / reference_mean`; reference row = NA
       - If `reference_mean == 0`, fire
         `surveycore_warning_pct_change_zero_ref` and set `pct_change = NA`
       - Assign stars via `.stars_pval(p_value)` on all rows

B.18f. Assemble output tibble + apply label_values (Steps 17–17a):
       - Build tibble in spec column order (Section 5.2)
       - Build reference row per contract (Section 5.4): `estimate = 0`,
         `mean = reference_mean`, `se/ci_low/ci_high/p_value = NA`,
         `stars = ""`
       - Handle `show_means = FALSE`: omit reference row and `mean` column
       - Apply `label_values` via `.apply_group_labels()` to treats and
         group columns

B.18g. Apply decimals, name_style, attach .meta (Steps 18–20):
       - If `decimals` is non-NULL: `.apply_decimals(result, decimals)`,
         then round `pct_change` separately to `decimals + 2`
       - `.apply_name_style(result, name_style, exclude = "mean")`
       - Build `meta_args` with all `DIFFS_META_KEYS` entries
       - Attach `.meta` via `.make_result_tibble()`

B.18h. Attach column-level labels + set class + return (Steps 21–22):
       - Set `attr(col, "label")` on every output column per Section 5.5
       - Set class to `c("survey_diffs", "survey_result", "tbl_df", "tbl",
         "data.frame")`
       - Return result

B.19. Run `devtools::document()`.

B.20. Run tests → confirm all B.* tests pass.

#### Phase C: Marginaleffects path (covariates, non-gaussian, group)

C.1. Write happy path test: "with covariates, no group" — covariates forces
     marginaleffects path.
     Assert: `.meta$estimate_method == "avg_slopes"`,
     `.meta$mean_method == "avg_predictions"`.

C.2. Write happy path test: "with covariates and group" — interaction model.
     Assert: group column present, rows grouped by group values, reference
     row per group.

C.3. Write happy path test: "with group, no covariates" — interaction +
     marginaleffects path.

C.4. Write happy path test: "non-gaussian family (quasibinomial)" — binary DV
     with `family = quasibinomial()`.
     Create binary DV test data (0/1 values).
     Assert: `.meta$family == "quasibinomial"`,
     `.meta$estimate_scale == "ame"`, estimates are on probability scale.

C.5. Write happy path test: "scale = 'link' + non-gaussian" — link-scale
     suppression.
     **Note:** Despite being in Phase C, this test exercises the **clean path**
     when no covariates or groups are present (per routing logic, Section 7.2:
     `scale = "link"` + non-gaussian + no covariates + no group → clean path).
     Assert: no `mean` column, no `pct_change` column, reference row still
     present with `estimate = 0`,
     `.meta$estimate_method == "coefficient"` (confirms clean path).

C.6. Write happy path test: "gaussian scale = 'ame' == scale = 'link'" —
     both scales produce identical output for gaussian family.
     Assert: estimates, SEs, CI bounds match within tolerance 1e-10 (point),
     1e-8 (SEs).

C.7. Write happy path test: "pval_adj with group" — adjustment within each
     group independently.

C.8. Run tests → confirm all C.* tests fail.

C.9a. Compute marginaleffects common parameters (spec Section 3.9.1):
      - `res_df <- max(1, fit@degf - (p - 1L))` where `p = length(coef(fit))`
      - `me_type <- if (scale == "link") "link" else "response"`
      - Remove the "not yet implemented" placeholder from B.18a

C.9b. Call `avg_slopes()` for treatment effect estimates (Section 3.9.2):
      - Without group: `avg_slopes(fit, variables = treats_name, type = me_type, wts = TRUE, df = res_df)`
      - With group: add `by = group_names`
      - Map column names: `estimate`, `std.error` → `se`, `conf.low` → `ci_low`,
        `conf.high` → `ci_high`, `p.value` → `p_value`

C.9c. Call `avg_predictions()` for means (Section 3.9.3):
      - Skip entirely if link-scale suppression applies (Section 3.2)
      - Without group: `avg_predictions(fit, by = treats_name, type = me_type, wts = TRUE, df = res_df)`
      - With group: `by = c(treats_name, group_names)`
      - `preds$estimate` → `mean`

C.9d. Assemble marginaleffects output and route to shared pipeline
      (Section 3.9.4):
      - Left-join `slopes` and `preds` on treatment level (+ group if applicable)
      - Reference level: `preds` has a row but `slopes` does not — when
        `show_means = TRUE`, set `estimate = 0`, `mean = preds$estimate`,
        `p_value = NA`
      - Route into the shared post-estimation pipeline (Steps 12–22, same
        code as clean path starting from B.18c)

C.10. Run tests → confirm all C.* tests pass.

#### Phase D: Design class coverage + domain estimation

D.1. Write happy path test: "survey_replicate design" — basic get_diffs call
     on a replicate weight design.
     Assert: correct class, `.meta$design_type == "replicate"`.

D.2. Write happy path test: "survey_twophase design" — basic get_diffs on a
     two-phase design.
     Assert: `.meta$design_type == "twophase"`.

D.3. Write happy path test: "survey_nonprob design" — basic get_diffs on a
     non-probability design.
     Assert: `expect_identical(meta(result)$design_type, "calibrated")`.

D.4. Write happy path test: "domain estimation" — `filter(design, cond) |>
     get_diffs(...)`. Gated with `skip_if_not_installed("surveytidy")`.
     Assert: `n` counts are in-domain only (smaller than total n).

D.5. Write happy path test: "@groups integration" —
     `group_by(design, group_var) |> get_diffs(dv, treats)`.
     Gated with `skip_if_not_installed("surveytidy")`.
     Assert: group column appears in output, rows grouped by group values,
     reference row per group.

D.6. Run tests → confirm pass (implementation from Phase B/C should handle
     all design classes already via `survey_glm()` delegation).

#### Phase E: Edge case tests

E.1. Write edge case test: "treats with 2 levels" — simplest case: 1
     reference + 1 treatment row.

E.2. Write edge case test: "treats with 10+ levels" — verify all non-reference
     levels appear.

E.3. Write edge case test: "treats as character (not factor)" — coerced with
     warning `surveycore_warning_treats_coerced`.

E.4. Write edge case test: "reference mean = 0 with show_pct_change" —
     warning `surveycore_warning_pct_change_zero_ref` + `pct_change = NA`.

E.5. Write edge case test: "single observation in one treatment level" —
     `surveycore_warning_small_cell` fires.

E.6. Write edge case test: "group with only 1 unique value" — propagates
     `surveycore_error_singular_model_matrix` from `survey_glm()`.

E.7. Write edge case test: "na.rm = FALSE with NAs present" — propagates
     `surveycore_error_na_in_data`.

E.8. Write edge case test: "scale = 'link' + non-gaussian" — `mean` and
     `pct_change` columns omitted.
     (Overlap with C.5 is intentional — this one focuses on column absence.)

E.9. Run tests → confirm all pass (implementation should already handle these).

#### Phase F: Numerical oracle tests

F.1. Create `tests/testthat/test-analysis-diffs-numerical.R`. Gate with
     `skip_if_not_installed("survey")`.

F.2. Write numerical test: "bivariate OLS vs manual computation" —
     `clean()` coefficient = hand-computed diff of weighted means.
     Use GSS data or synthetic data.

F.3. Write numerical test: "multivariate OLS vs survey + marginaleffects" —
     `avg_slopes()` output matches `survey::svyglm() + marginaleffects::avg_slopes()`.
     Gate additionally with `skip_if_not_installed("marginaleffects")`.

F.4. Write numerical test: "logistic AME vs survey + marginaleffects" —
     binary DV with `quasibinomial()` family: AME and SE match
     `survey::svyglm(..., family = quasibinomial()) + marginaleffects::avg_slopes()`.

F.5. Write numerical test: "replicate design non-integer df" —
     replicate design with non-integer `degf` produces CI bounds matching
     manual `qt(0.975, df = degf_value)`.

F.6. Write numerical test: "Poisson AME vs survey + marginaleffects" —
     count DV with `poisson()` family: AME and SE match
     `survey::svyglm(..., family = poisson()) + marginaleffects::avg_slopes()`.
     Gate with `skip_if_not_installed("marginaleffects")`.

F.7. Write numerical test: "SRS full covariance matrix verification" —
     for multivariate model, verify off-diagonal elements of `fit@vcov`
     are non-zero (where expected) and match `survey::svyglm()` within
     tolerance 1e-8. A diagonal-only implementation would pass point-
     estimate tests but produce wrong SEs when covariates are correlated.

F.8. Write numerical test: "replicate domain convergence" —
     call `get_diffs()` on a replicate design with a tight domain filter
     causing some replicates to have near-zero in-domain rows. Verify
     warnings from `survey_glm()` propagate and results are finite (no
     silent NaN propagation). Gate with `skip_if_not_installed("surveytidy")`.

F.9. Run tests → confirm all pass.

#### Phase G: Marginaleffects-specific tests

G.1. Create `tests/testthat/test-analysis-diffs-marginaleffects.R`. Gate
     with `skip_if_not_installed("marginaleffects")`.

G.2. Write test: "`avg_slopes()` produces correct number of rows" — one row
     per non-reference treatment level (× group).

G.3. Write test: "`avg_predictions()` produces correct means" — one row per
     treatment level (× group).

G.4. Write test: "`wts = TRUE` produces weighted averages" — compare against
     manual weighted computation.

G.5. Run tests → confirm all pass.

#### Phase H: DESCRIPTION + final checks

H.1. In `DESCRIPTION`, move `marginaleffects (>= 0.18.0)` from `Suggests`
     to `Imports`.

H.1a. Remove `skip_if_not_installed("marginaleffects")` from all new test
      files (`test-analysis-diffs.R`, `test-analysis-diffs-numerical.R`,
      `test-analysis-diffs-marginaleffects.R`). After moving to Imports,
      marginaleffects is always installed — the skip guards would never
      fire. Keep `skip_if_not_installed("survey")` and
      `skip_if_not_installed("surveytidy")` (still in Suggests).

H.2. Run `devtools::document()` — update NAMESPACE.

H.3. Run `devtools::check()` — 0 errors, 0 warnings, ≤2 pre-approved notes.

H.4. Verify full test suite passes (all existing + all new tests).

---

## Dependency Graph

```
PR 1: feature/diffs-infrastructure
  ├── R/analysis-diffs-helpers.R  (.stars_pval)
  ├── R/analysis-helpers.R        (DIFFS_META_KEYS, .apply_name_style exclude)
  ├── R/analysis-meta.R           (print.survey_diffs)
  └── plans/error-messages.md     (9 new rows)

PR 2: feature/get-diffs (depends on PR 1)
  ├── R/analysis-diffs.R          (get_diffs, exported)
  ├── tests/testthat/test-analysis-diffs.R
  ├── tests/testthat/test-analysis-diffs-numerical.R
  ├── tests/testthat/test-analysis-diffs-marginaleffects.R
  └── DESCRIPTION                 (marginaleffects → Imports)
```

---

## Risk Notes

1. **marginaleffects API stability**: The `wts` and `df` arguments are
   documented in marginaleffects ≥ 0.18.0. Pin the minimum version.

2. **`contr.treatment` enforcement**: The spec requires explicitly setting
   treatment contrasts (Section 3.7 Step 5) to guard against non-default
   global contrast settings. This modifies `design@data` in place before
   the GLM call — verify this doesn't affect the original design object
   (it shouldn't, since R uses copy-on-modify).

3. **S3 print dispatch**: `print.survey_diffs` must be registered in
   `.onLoad()` for installed packages. `devtools::load_all()` finds it
   automatically but installed packages need the explicit registration.

4. **Column-level labels**: `attr(col, "label")` must be set AFTER
   `.make_result_tibble()` constructs the final tibble, because tibble
   operations can strip attributes.
