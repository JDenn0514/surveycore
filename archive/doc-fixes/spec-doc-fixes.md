# Spec — doc-fixes

**Status**: DRAFT
**Target version**: X.Y.Z.9000
**PR range**: PR 1–2

---

## Scope

### In

- Fix all 6 code bugs (B1–B6).
- Register 5 missing or misassigned error classes in `plans/error-messages.md`
  (E1–E5) and update the code sites that raise them.
- Fix 75 documentation issues (D1–D75, W1–W3, S1–S7, T1–T5, M1–M4,
  X1–X13) — correcting @param/@return text, @examples, stale file references,
  contradictory roxygen tags, mixed comment styles, and miscellaneous
  inaccuracies.
- Remove the unused variable `n_full` (X5).
- Resolve the no-op fallback in `.glm_value_label_for()` (X9) — correct the
  comment to match actual behavior (both branches return the same thing).
- Fix the `" "` space bullet in `.check_is_survey()` (D44).
- Fix `extract_sata()` firing the wrong error class (D45).

### Out

- No new exported functions.
- No changes to exported function signatures.
- No changes to numerical variance algorithms.
- No changes to the package's statistical behavior.
- No vignette changes.
- No DESCRIPTION changes (RoxygenNote may auto-update on `devtools::document()`).
- No changes to `NAMESPACE` contents beyond what `devtools::document()` produces
  after the roxygen tag corrections (T1–T5).

---

## Architecture

**Files touched (PR 1 — code bugs + error class additions):**

- `R/analysis-t-test.R` — fix B1, B2 via shared helper `.extract_print_label()`
  (see Architecture note below); add missing `@method` tags (D74)
- `R/analysis-corr-latent.R` — fix B3 (threshold value in warning message)
- `R/glm-methods.R` — fix B4 (label for `survey_nonprob`), B5 (argument name
  in `confint` error message), B6 (wrong error class in `update.survey_glm_fit`,
  introducing `surveycore_error_update_no_call`)
- `R/core-classes.R` — fix D20 / E5: give the unnamed-surveys validator
  condition a distinct error class (`surveycore_error_collection_unnamed`)
- `R/survey-collection.R` — fix D56 / E4: give `remove_survey()` invalid-`name`-
  type branch a distinct error class (`surveycore_error_invalid_name_type`)
- `R/variance-taylor.R` — fix X5 (remove unused variable), X6 (give the
  "unknown option" branch its own error class
  `surveycore_error_lonely_psu_unknown_option`)
- `R/variance-replicate.R` — E2 already uses `surveycore_error_all_replicates_na`;
  only registration in `plans/error-messages.md` is missing (no code change)
- `plans/error-messages.md` — add rows for E1–E5 and X6

**Files touched (PR 2 — documentation-only):**

- `R/analysis-t-test.R` — D38, D74, D75 (remaining doc-only items)
- `R/analysis-corr-latent.R` — D70 (stale file header)
- `R/analysis-corr.R` — D33, D34, D35, D36, W2
- `R/analysis-covariance.R` — W3
- `R/analysis-diffs.R` — D13, D71
- `R/analysis-effective-n.R` — D75
- `R/analysis-freqs-helpers.R` — D8
- `R/analysis-freqs.R` — D36
- `R/analysis-helpers.R` — D6, D7, D32
- `R/analysis-means-helpers.R` — D29, D30, D31, D32
- `R/analysis-means.R` — D4, D17, D24
- `R/analysis-meta.R` — D39, T3, T4, T5
- `R/analysis-quantiles.R` — D10, D15, D18
- `R/analysis-ratios.R` — D16
- `R/analysis-totals-helpers.R` — D25, D26, D27, D28
- `R/analysis-totals.R` — D5, D19, D37
- `R/analysis-variance.R` — D21, D22, D23, M3, W1
- `R/calibration.R` — D61, D62, D63
- `R/core-classes.R` — D9, S1, T3, X1
- `R/core-constructors.R` — D1, D2, D3, S2, X2
- `R/core-metadata.R` — D42, D43, D44, D45, X4
- `R/core-validators.R` — S3
- `R/data.R` — D12, X10
- `R/glm-anova-dispatch.R` — D57, D58, D72
- `R/glm-anova.R` — D59
- `R/glm-clean.R` — X9
- `R/glm-methods.R` — D60
- `R/glm.R` — D11, D40, D41
- `R/metadata-infer.R` — D64
- `R/methods-compat.R` — D51
- `R/methods-conversion.R` — D49, D50
- `R/methods-print.R` — S4, X11
- `R/srr-stats-standards.R` — D65, D66, D67
- `R/survey-collection.R` — D52, D53, D54, D55
- `R/update-design.R` — D46, D47, D48, X3
- `R/utils.R` — T1, T2, X12
- `R/variance-replicate.R` — D73, M2, S6
- `R/variance-taylor.R` — M1, S5, X7
- `R/variance-twophase.R` — D14, S7
- `R/zzz.R` — D68, D69
- `R/analysis-covariance-helpers.R` — M4

**Functions added:** none

**Shared internal helper (B1 + B2):**
- `.extract_print_label(m)` — extracts `m$by$variable_label` with correct
  fallback to `deparse(m$call$by)` when the label is `NULL` or empty string.
  Defined in `R/analysis-t-test.R` (used in 2 places in the same file).
  Both `print.survey_t_test` and `print.survey_pairwise` call this helper
  instead of duplicating the label-extraction logic inline.

**Functions modified (behavior):**
- `print.survey_t_test` — fix B1: calls `.extract_print_label(m)` for by-variable label
- `print.survey_pairwise` — fix B2: same
- `.glm_design_type_label()` — fix B4: returns `"Non-probability"` for
  `survey_nonprob`
- `confint.survey_glm_fit` — fix B5: error text uses `{.arg level}` not
  `{.arg conf_level}`
- `update.survey_glm_fit` — fix B6: raises `surveycore_error_update_no_call`
- `survey_collection` S7 validator — fix D20 / E5: missing/empty/NA names
  branch now raises `surveycore_error_collection_unnamed`
- `remove_survey()` — fix D56 / E4: invalid `name` type raises
  `surveycore_error_invalid_name_type`
- `.vcov_pair_taylor()` — fix X5 (remove unused `n_full`), X6 (split error
  class)
- `.check_is_survey()` — fix D44: replace `" "` bullet key with a valid merge
  into `"v"` bullet
- `extract_sata()` — fix D45: use a new fill-specific error class
  `surveycore_error_fill_not_logical` instead of `surveycore_error_sata_not_logical`

**Class changes:** none (S7 classes unchanged; only roxygen tags corrected)

---

## Function contracts

The contracts below cover all functions whose **behavior changes** in PR 1.
Documentation-only changes (PR 2) do not alter contracts and are listed only
in the scope table above.

---

### `print.survey_t_test(x, ...)`

- **Signature**: `print.survey_t_test(x, ...)`
- **Arguments**:
  - `x` — A `survey_t_test` object (tibble with `.meta` attribute).
  - `...` — Passed to `NextMethod()`.
- **Returns**: `x`, invisibly.
- **Errors**: none raised directly.
- **Warnings**: none raised directly.
- **Edge cases**:
  - Uses shared helper `.extract_print_label(m)`. When `m$by$variable_label`
    is `NULL` or empty string, the helper returns `deparse(m$call$by)` (the
    bare column name). Previously a self-assignment no-op (`by_label <- by_label`)
    left this always `NULL` or `""`. After the fix the header line shows the
    column name instead of a blank field.

---

### `print.survey_pairwise(x, ...)`

- **Signature**: `print.survey_pairwise(x, ...)`
- **Arguments**:
  - `x` — A `survey_pairwise` object.
  - `...` — Passed to `NextMethod()`.
- **Returns**: `x`, invisibly.
- **Errors**: none raised directly.
- **Warnings**: none raised directly.
- **Edge cases**:
  - Uses same shared helper `.extract_print_label(m)` as `print.survey_t_test`.
    Previously had the identical self-assignment no-op; after the fix, falls
    back to `deparse(m$call$by)` when `m$by$variable_label` is absent or empty.

---

### `.glm_design_type_label(fit)`

- **Signature**: `.glm_design_type_label(fit)` (internal)
- **Arguments**:
  - `fit` — A `survey_glm_fit` object.
- **Returns**: Character(1). One of `"Taylor series"`, `"Replicate weights"`,
  `"Two-phase"`, `"Non-probability"`, `"Unknown"`.
- **Errors**: none.
- **Warnings**: none.
- **Edge cases**:
  - `survey_nonprob` input: previously returned `"Calibrated"`, now returns
    `"Non-probability"` (matching the dispatch function at
    `glm-anova-dispatch.R:606`). Always returns `"Non-probability"` for
    `survey_nonprob` regardless of calibration status — intentional design
    decision, as the design type label describes the sampling mechanism, not
    the post-hoc adjustment.
  - All other branches unchanged.

---

### `confint.survey_glm_fit(object, parm, level, ...)`

- **Signature**: `confint.survey_glm_fit(object, parm = NULL, level = 0.95, ...)`
- **Arguments**:
  - `object` — A `survey_glm_fit`.
  - `parm` — Optional character vector of parameter names to include.
  - `level` — Numeric scalar in `(0, 1)`.
  - `...` — Unused.
- **Returns**: A numeric matrix with columns named `"X% %"` and `"Y% %"`.
- **Errors**:
  - `surveycore_error_invalid_conf_level` — when `level` is not a single
    finite number strictly between 0 and 1. Error text uses `{.arg level}`
    (previously incorrectly used `{.arg conf_level}`).
- **Warnings**: none.
- **Edge cases**:
  - `level = 0` or `level = 1`: raises `surveycore_error_invalid_conf_level`.
  - `level = NA`: raises `surveycore_error_invalid_conf_level`.

---

### `update.survey_glm_fit(object, formula., ...)`

- **Signature**: `update.survey_glm_fit(object, formula., ...)`
- **Arguments**:
  - `object` — A `survey_glm_fit`.
  - `formula.` — Optional formula update.
  - `...` — Additional argument updates.
- **Returns**: A new `survey_glm_fit` evaluated in the caller's frame.
- **Errors**:
  - `surveycore_error_update_no_call` — when `object@call` is `NULL` (object
    was serialized or constructed without recording a call). Previously raised
    `surveycore_error_predict_no_fit`, which is semantically wrong (that class
    belongs to a missing `fit_` slot).
- **Warnings**: none.
- **Edge cases**:
  - Serialized objects that lack `@call`: raise `surveycore_error_update_no_call`.
  - When `formula.` is omitted and `...` is empty, the original model is
    re-evaluated in the caller's frame with no changes (standard
    `update.default()` semantics).

---

### `survey_collection` S7 class validator (unnamed-surveys condition)

This is an S7 validator, not a user-facing function. The contract change is on
the error class only.

- **Condition**: `@surveys` list has missing names, empty-string names, or
  `NA` names.
- **Before**: raised `surveycore_error_collection_empty` (same class as the
  empty-collection condition).
- **After**: raises `surveycore_error_collection_unnamed`.
- **Message**: `"All surveys in the collection must be named."` (unchanged
  text; only the `class=` argument changes).
- **Layer**: Layer 1 (S7 validator). Testing: `class=` only, no snapshot.

---

### `remove_survey(x, name)`

- **Signature**: `remove_survey(x, name)` (exported)
- **Arguments**:
  - `x` — A `survey_collection`.
  - `name` — Character vector of survey names to remove.
- **Returns**: A `survey_collection` with the named surveys removed.
- **Errors**:
  - `surveycore_error_not_survey_collection` — when `x` is not a
    `survey_collection`.
  - `surveycore_error_invalid_name_type` — when `name` is not character.
    Previously raised `surveycore_error_not_survey_collection` (wrong class).
  - `surveycore_error_collection_name_not_found` — when any name is absent
    from the collection.
- **Warnings**: none.
- **Edge cases**:
  - `name = 1L` (integer): raises `surveycore_error_invalid_name_type`.
  - `name = NULL`: raises `surveycore_error_invalid_name_type`.
  - `name = NA_character_`: type check passes (character), then name-lookup
    fails with `surveycore_error_collection_name_not_found`.
  - `name = character(0)` (empty character vector): passes the type check,
    matches no names, and returns `x` unchanged.
  - Removing all surveys from a collection causes the S7 validator to raise
    `surveycore_error_collection_empty` after the S7 object is reconstructed.

---

### `.vcov_pair_taylor()` — error class split (X6)

The `switch` in `.vcov_pair_taylor()` has two `cli_abort()` branches:

1. `lonely.psu = "fail"` → stratum has one PSU → raises
   `surveycore_error_lonely_psu` (existing, registered).
2. Unknown `lonely.psu` value (fall-through) → raises
   `surveycore_error_lonely_psu_unknown_option` (new, distinct class).

After X6, these two branches carry distinct classes so tests can verify each
independently.

---

### `extract_sata()` — fill argument error class (D45)

- **Condition**: `fill` argument is not a valid logical scalar or `NULL`.
- **Before**: raised `surveycore_error_sata_not_logical` (shared with the
  `sata` setter argument, semantically wrong for `fill`).
- **After**: raises `surveycore_error_fill_not_logical`.
- **Message**: `"x" = "{.arg fill} must be {.code FALSE} or {.code NULL}."`
- **Layer**: Layer 3 (constructor / function validation). Testing: dual
  pattern (class + snapshot).

---

### `.check_is_survey()` — cli bullet fix (D44)

- **Before**: used `" "` (space) as a bullet key in the `cli_abort()` call,
  which is not a valid `cli` bullet type.
- **After**: the `"v"` and `" "` bullets are merged into a single `"v"` bullet
  using `paste0()`:
  ```r
  "v" = paste0(
    "Create a survey object with {.fn as_survey}, ",
    "{.fn as_survey_replicate}, or {.fn as_survey_twophase}."
  )
  ```
- No change to the error class or visible message semantics; the fix removes
  the invalid `" "` (space) bullet key.

---

## New error classes to add to `plans/error-messages.md`

| Class | Function | Condition | Level | "x" bullet |
|-------|----------|-----------|-------|------------|
| `surveycore_error_update_no_call` | `update.survey_glm_fit` | `object@call` is `NULL` | ERROR | `"Cannot update {.cls survey_glm_fit}: {.field @call} is NULL."` |
| `surveycore_error_collection_unnamed` | `survey_collection` S7 validator | `@surveys` list has missing, empty, or NA names | ERROR | `"All surveys in the collection must be named."` |
| `surveycore_error_invalid_name_type` | `remove_survey()` | `name` argument is not a character vector | ERROR | `"{.arg name} must be a character vector, not {.cls {class(name)[[1L]]}}."` |
| `surveycore_error_lonely_psu_unknown_option` | `.vcov_pair_taylor()` | `lonely.psu` option is not one of the valid set | ERROR | `"Unknown {.arg lonely.psu} value: {.val {lonely.psu}}."` |
| `surveycore_error_fill_not_logical` | `extract_sata()` | `fill` is not `FALSE` or `NULL` | ERROR | `"{.arg fill} must be {.code FALSE} or {.code NULL}."` |

Existing classes confirmed present and unchanged:
- `surveycore_error_lonely_psu` — already in code; add to table as E1
- `surveycore_error_all_replicates_na` — already in code; add to table as E2

---

## Documentation corrections (PR 2 catalogue)

Each item below lists the finding ID, the file, and the required change.
No behavioral change; all are textual corrections to roxygen2 or internal
comments.

**@param corrections:**
- D1 `as_survey_replicate()` `@param mse` — remove false claim that default
  differs between functions.
- D2 `as_survey_replicate()` `@param scale` — replace `"NULL sets 1/R"` with
  type-specific description.
- D9 `survey_nonprob` `@section` — add `"JK1"`, `"JK2"`, `"JKn"` to the
  listed supported types.
- D10 `get_quantiles()` `@param na.rm` — fix: NAs cause all estimates to be
  `NA_real_`, not "included".
- D15 `get_quantiles()` `@return n` — fix: when `na.rm = FALSE`, `n` counts
  all active-domain rows including NAs.
- D16 `get_ratios()` `@param label_values` — remove "no visible effect" claim;
  replace with: "Logical. Accepted for API consistency across `get_*()` functions.
  For `get_ratios()`, no value-level cells appear in the output, so this
  parameter has no effect. Default `TRUE`."
- D17 `get_means()` `@param label_values` — same pattern; replace with:
  "Logical. Accepted for API consistency across `get_*()` functions. For
  `get_means()`, no value-level cells appear in the output, so this parameter
  has no effect. Default `TRUE`."
- D18 `get_quantiles()` `@param label_values` — same pattern; replace with:
  "Logical. Accepted for API consistency across `get_*()` functions. For
  `get_quantiles()`, no value-level cells appear in the output, so this
  parameter has no effect. Default `TRUE`."
- D19 `get_totals()` `@param label_values` — same pattern; replace with:
  "Logical. Accepted for API consistency across `get_*()` functions. For
  `get_totals()`, no value-level cells appear in the output, so this parameter
  has no effect. Default `TRUE`."
- D23 `get_variance()` `@param label_values` — same pattern; replace with:
  "Logical. Accepted for API consistency across `get_*()` functions. For
  `get_variance()`, no value-level cells appear in the output, so this
  parameter has no effect. Default `TRUE`."
- D34 `get_corr()` `@param na.rm` — correct description of NA handling.
- D35 `get_corr()` `@param decimals` — document that `decimals` is silently
  ignored for `format = "wide"`.
- D36 `get_freqs()`, `get_totals()` `@param ...` — correct "unused" to note
  forwarding to `.dispatch_over_collection()`.
- D38 `get_t_test()`, `get_pairwise()` `@param ...` — same correction.
- D41 `survey_glm_fit` `@param degf` — update description: SRS is absorbed into
  taylor; add `survey_nonprob` returns `Inf`; add `survey_twophase` behavior.
- D42 `extract_val_labels()` `@param fill` — clarify: in `"data_frame"` format
  variables with no labels are always excluded regardless of `fill`.
- D43 `extract_missing_codes()` `@param fill` — same.
- D46 `update_design()` `@param validate` — replace with: "If `FALSE`,
  temporarily marks the object to suppress validation during the variable
  update. In practice this has no observable effect on the returned object;
  `validate` is accepted for interface compatibility."
- D49 `as_tbl_svy()` `@param x` — note that `survey_nonprob` is not supported.
- D50 `from_svydesign()` `@param x` — mention `survey::twophase2` dispatch.
- D62 `as_caldata()` `@param` — document the near-zero product constraint.

**@return corrections:**
- D4 `get_means()` — `meta(result)$variable` → `meta(result)$x`.
- D5 `get_totals()` — same.
- D21 `get_variance()` — add `[.id]` column note for `survey_collection`.
- D22 `get_variance()` — distinguish `variance` vs `var` columns.
- D24 `get_means()` — add `df` column note for calibrated Taylor designs.
- D26 `.taylor_total_cell()` — add `df` field.
- D28 `.total_cell()` — add `df` for Taylor path.
- D30 `.taylor_mean_cell()` — add `df` field.
- D31 `.mean_cell()` — add `df` for Taylor path.
- D48 `update_design()` — mention `cli_inform()` side effect listing changes.
- D57 `get_anova()` — note renaming of `p_value`/`ddf` when `name_style =
  "broom"`.
- D61 `as_caldata()` `@return w` — correct description of intermediate quantity.
- D75 `print.survey_effective_n` — add `@return x, invisibly.`

**@details corrections:**
- D3 `as_survey_twophase()` — change "issues a warning and falls back" to "an
  error is raised".
- D11 `survey_glm()` — change "five design classes" to four; note
  `survey_collection` is rejected.
- D13 `get_diffs()` — add: non-Gaussian `scale = "link"` also takes the clean
  path.
- D14 `variance-twophase.R` formula comment — add the FPC factor `f_s`.
- D40 `survey_glm()` bread formula — correct to `(X'W̃X)^(-1)`.
- D58 `get_anova()` `@description` — add: function also implements Wald tests.
- D64 `infer_question_prefaces()` `@description` — clarify: for data frames,
  prefaces go to `attr(col, "question_preface")`, not a metadata object.

**@examples corrections:**
- D12 `nhanes_2017` `@details` design example — add `nest = TRUE`.
- D71 `get_diffs()` — remove unnecessary `library(marginaleffects)` from
  example that does not use it.
- D72 `get_anova()` — replace `gss_2024` with `gss` dataset per CLAUDE.md rule.
- W1 `get_variance()` example — change `wtint2yr` to `wtmec2yr`.
- W2 `get_corr()` example — same.
- W3 `get_covariance()` example — same.
- X1 `core-classes.R` `@examples` — replace direct `@` property access with
  function-call style.
- X2 `core-constructors.R` `@examples` — replace `coll3@groups` with function
  call.

**@seealso corrections:**
- D47 `update_design()` — add `[as_survey_twophase()]` to `@seealso`.
- D63 `as_caldata()` — add `@seealso` linking to sibling constructors.
- X13 `set_universe()`, `set_missing_codes()` — add `@seealso` to extractor
  counterparts.

**Contradictory tag fixes:**
- T1 `SURVEYCORE_DOMAIN_COL` — drop `@keywords internal` (keep `@export`).
- T2 `.get_design_vars_flat` — drop `@keywords internal` (keep `@export`).
- T3 `survey_nonprob` — drop `@keywords internal` (keep `@family constructors`).
- T4 `print.survey_result` — drop `@keywords internal` (keep `@export`).
- T5 `print.survey_diffs` — same.

**Missing @method tags:**
- D74 `print.survey_t_test` — add `@method print survey_t_test`.
- D74 `print.survey_pairwise` — add `@method print survey_pairwise`.
- D75 `print.survey_effective_n` — add `@keywords internal`.
- D59 `anova.survey_glm_fit`, `print.survey_anova` — add `@rdname`, `@title`,
  `@param`, `@return` stubs so they are documentable.

**@family fixes:**
- X3 `update_design()` `@family update` — remove the `@family` tag entirely
  (`update_design()` has no sibling functions; grouping it with constructors
  is semantically incorrect as it modifies an existing design, not creates one).
- X12 `survey_data()` — change `@family constructors` to `@family accessors`.

**Stale file reference corrections:**
- S1 `core-classes.R` — `R/03-constructors.R` → `R/core-constructors.R`.
- S2 `core-constructors.R` — update all three stale paths.
- S3 `core-validators.R` — update stale paths.
- S4 `methods-print.R` (9 occurrences) — `R/00-s7-classes.R` → `R/core-classes.R`.
- S5 `variance-taylor.R` — `R/06-variance-taylor.R` → `R/variance-taylor.R`.
- S6 `variance-replicate.R` — `R/06-variance-replicate.R` → `R/variance-replicate.R`.
- S7 `variance-twophase.R` — `R/06-variance-twophase.R` → `R/variance-twophase.R`.

**Stale internal comment corrections:**
- D6 `analysis-helpers.R` — `survey_nonprob` returns `Inf`, not `n - 1`.
- D7 `analysis-helpers.R` — "four" concrete design classes, not five.
- D8 `analysis-freqs-helpers.R` — remove false delegation claim for
  `.calibrated_freq_cell()`.
- D25 `.taylor_total_cell()` — remove `survey_nonprob` from `@param design`.
- D27 `.replicate_total_cell()` — add `survey_nonprob` (with repweights).
- D29 `.taylor_mean_cell()` — remove `survey_nonprob` from `@param design`.
- D32 `.mean_domain_vec()` — fix `@return`: remove stale `design` parameter
  reference; `length(active_mask)` is the length.
- D33 `get_corr()` `@return` — note that `r` and `statistic` are method-
  specific; `df` is `NA_integer_` for latent methods.
- D39 `meta()` `@return` — remove `"srs"` as a valid `design_type`.
- D51 `glance.survey_covariance` — correct comment: `n_pairs` equals `nrow(x)`,
  not a "unique-pair count".
- D52, D53 `survey-collection.R` — fix call-site counts (four, not five).
- D54 `survey-collection.R` — fix `.resolve_caller_names()` error to handle
  both `as_survey_collection` and `add_survey()` callers.
- D55 `survey-collection.R` `remove_survey()` `@return` — note that the
  empty-collection error is raised by the S7 validator, not `remove_survey()`
  itself.
- D60 `glm-methods.R` — update count comment from "20 + getCall" to
  "22 + getCall" (23 total).
- D65 `srr-stats-standards.R` — "19 helpers", not "16".
- D66 `srr-stats-standards.R` — `factor()`, not `as.factor()`.
- D67 `srr-stats-standards.R` — remove "planned future phase" for calibration;
  it shipped in PRs #139–142.
- D68 `zzz.R` — "22 + getCall", not "20 + getCall".
- D69 `zzz.R` — remove or update cross-reference to `MEMORY.md`.
- D70 `analysis-corr-latent.R` — replace stale file header with accurate
  function list.
- D73 `variance-replicate.R` — correct `combined.weights = TRUE` comment:
  surveycore has no alternative mode.
- X7 `variance-taylor.R` — remove stale "Phase 0" comment.
- X8 `variance-replicate.R` — remove misleading "Section 3b" label.
- X9 `glm-clean.R` — correct comment: both branches of `.glm_value_label_for()`
  return `level_name` identically; the comment should not imply differentiated
  behavior.
- X10 `data.R` — `ns_wave1` `@references`: correct to July 2019 (Wave 1).
- X11 `methods-print.R` — fix internal titles for `survey_nonprob`: calibration
  is optional, not inherent; drop "Calibrated / Non-Probability" to just
  "Non-Probability".

**Mixed comment style fixes:**
- M1 `variance-taylor.R` — `.vcov_pair_taylor` block: convert all `#` to `#'`
  or convert all to plain `#` (no mixed `#`/`#'`).
- M2 `variance-replicate.R` — `.replicate_estimate` and `.vcov_pair_replicate`
  blocks: same.
- M3 `analysis-variance.R` — `.attach_variance_labels` block: same.
- M4 `analysis-covariance-helpers.R` — `.attach_covariance_labels` block: same.

**File header correction:**
- X4 `core-metadata.R` — update file header function list to cover all ~25+
  exported functions (not the ~10 currently listed).

---

## Quality gates

- `devtools::document()` runs clean with no warnings about conflicting tags.
- `devtools::run_examples()` runs clean; all NHANES examples use `wtmec2yr`.
- `R CMD check` passes with 0 errors, 0 warnings, ≤ 2 pre-approved notes.
- All five new error classes exist in `plans/error-messages.md` before any PR
  is opened.
- After PR 1: `print.survey_t_test` and `print.survey_pairwise` display the
  by-variable column name when no label is set.
- After PR 1: `update.survey_glm_fit` with `@call = NULL` raises
  `surveycore_error_update_no_call`.
- After PR 1: `survey_collection` validator raises
  `surveycore_error_collection_unnamed` (not `surveycore_error_collection_empty`)
  for unnamed-surveys condition.
- After PR 1: `remove_survey()` with non-character `name` raises
  `surveycore_error_invalid_name_type`.
- After PR 1: `.glm_design_type_label()` returns `"Non-probability"` for
  `survey_nonprob` fit.
- After PR 1: boundary warning in polychoric path shows `1e-4` not `1e-6`.

---

## Pipeline split

**optional** — No new exported function, no numerical method change, no
contract change on any public analysis function. Only two PRs, both touch
doc text and a small set of bug fixes in print/dispatch helpers. The split
is logical (code bugs vs. doc-only) but either PR could be shipped
independently.
