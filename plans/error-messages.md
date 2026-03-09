# surveycore Canonical Error Message Table

**Version:** 1.0
**Created:** February 2025
**Status:** Authoritative — spec prose and plan templates must match this table exactly.

**Phase 1 rows:** 43–64 (analysis functions)
**Phase 2 rows:** 65–87 (survey GLM — 19 new + 2 reused from Phase 1)

---

## Purpose

This file is the single source of truth for all error and warning messages in
surveycore Phase 0. Tests that use `expect_snapshot(error = TRUE)` are testing
against the messages defined here.

**Rules:**
- All `cli_abort()` calls must have an error `class` argument (typed errors)
- Error class format: `"surveycore_error_<snake_case_condition>"`
- Warning class format: `"surveycore_warning_<snake_case_condition>"`
- Message templates use cli inline markup: `{.arg}`, `{.field}`, `{.fn}`, `{.val}`, `{.cls}`

---

## Error Case Table

| # | Function | Condition | Level | Error Class | cli Message Template |
|---|----------|-----------|-------|-------------|----------------------|
| 1 | `as_survey()` | `data` is not a data frame | ERROR | `surveycore_error_not_data_frame` | `"{.arg data} must be a data frame, not {.cls {class(data)}}"` |
| 2 | `as_survey()` | `data` has 0 rows | ERROR | `surveycore_error_empty_data` | `"{.arg data} must have at least one row"` |
| 3 | `as_survey()` | `data` has duplicate column names | ERROR | `surveycore_error_duplicate_names` | `"Column names in {.arg data} must be unique. Duplicates: {.field {dupes}}"` |
| 4 | `as_survey()` | `data` has 1 row | WARN | `surveycore_warning_single_row` | `"{.arg data} has only 1 row — variance cannot be estimated"` |
| 5 | `as_survey()` | Both `probs` and `weights` provided, inconsistent values | ERROR | `surveycore_error_probs_weights_conflict` | `"Cannot specify both {.arg probs} and {.arg weights} with inconsistent values. {.arg weights} should equal 1 / {.arg probs}"` |
| 6 | `as_survey()` | Both `probs` and `weights` provided, consistent values | INFO | `surveycore_inform_probs_weights_consistent` | `"Using {.arg weights}; provided {.arg probs} is consistent (weights = 1/probs)"` |
| 7 | `as_survey()` | No weights, probs, or ids (SRS) | WARN | `surveycore_warning_srs_no_weights` | `"No weights or population size provided. Treating as equal-probability SRS with unknown population size. Valid: means, proportions, correlations. Invalid: population totals."` |
| 8 | `as_survey()` | `weights` selects 0 columns | ERROR | `surveycore_error_weights_not_found` | `"{.arg weights} matched no columns in {.arg data}"` |
| 9 | `as_survey()` | `weights` selects >1 column | ERROR | `surveycore_error_weights_multiple` | `"{.arg weights} must select exactly one column, not {length(weights_cols)}"` |
| 10 | `as_survey()` | `weights` all zero | ERROR | `surveycore_error_weights_all_zero` | `"All values in {.arg weights} ({.field {weights_var}}) are zero or missing — no valid weights"` |
| 11 | `as_survey()` | `strata` selects 0 columns | ERROR | `surveycore_error_strata_not_found` | `"{.arg strata} matched no columns in {.arg data}"` |
| 11b | `as_survey()` | `strata` selects >1 column | ERROR | `surveycore_error_strata_multiple` | `"{.arg strata} must select exactly one column, not {length(strata_cols)}"` |
| 12 | `as_survey()` | `strata` resolves to 1 unique value | WARN | `surveycore_warning_single_stratum` | `"{.arg strata} ({.field {strata_var}}) has only 1 unique value — stratification has no effect"` |
| 13 | `as_survey()` / `as_survey_repweights()` | `fpc` selects 0 columns | ERROR | `surveycore_error_fpc_not_found` | `"{.arg fpc} matched no columns in {.arg data}"` |
| 13b | `as_survey()` / `as_survey_repweights()` | `fpc` selects >1 column | ERROR | `surveycore_error_fpc_multiple` | `"{.arg fpc} must select exactly one column, not {length(fpc_cols)}"` |
| 14 | `as_survey()` | `fpc` column contains `NA` | ERROR | `surveycore_error_fpc_na` | `"{.arg fpc} column {.field {fpc_var}} contains {sum(is.na(fpc_col))} NA value(s). FPC must be fully observed."` |
| 15 | `as_survey()` | `nest = TRUE` with no `strata` | ERROR | `surveycore_error_nest_without_strata` | `"{.arg nest = TRUE} requires {.arg strata} to be specified"` |
| 16 | `as_survey_repweights()` | `repweights` selects 0 columns | ERROR | `surveycore_error_repweights_empty` | `"{.arg repweights} must select at least one column"` |
| 17 | `as_survey_repweights()` | `scale`/`rscales` length mismatch | ERROR | `surveycore_error_rscales_length` | `"Length of {.arg rscales} ({length(rscales)}) must equal number of replicate weights ({n_rep})"` |
| 18 | `as_survey_repweights()` | `type` not in valid set | ERROR | *(handled by match.arg)* | `"'{type}' is not a valid replicate type. Choose from: {.val {valid_types}}"` |
| 19 | `as_survey_twophase()` | `phase1` is not a `survey_taylor` | ERROR | `surveycore_error_phase1_class` | `"{.arg phase1} must be a {.cls survey_taylor} object, not {.cls {class(phase1)[[1]]}}. Create it first with {.fn as_survey}."` |
| 20 | `as_survey_twophase()` | `subset` not provided (missing) | ERROR | `surveycore_error_subset_missing` | `"{.arg subset} is required: a logical column indicating Phase 2 membership"` |
| 21 | `as_survey_twophase()` | `subset` selects >1 column | ERROR | `surveycore_error_subset_multiple` | `"{.arg subset} must select exactly one column, not {length(subset_cols)}"` |
| 22 | `as_survey_twophase()` | `subset` column is not logical | ERROR | `surveycore_error_subset_not_logical` | `"{.arg subset} column {.field {subset_var}} must be logical, not {.cls {class(data[[subset_var]])}}"` |
| 23 | `as_survey_twophase()` | `subset` is all TRUE or all FALSE (among non-NA) | ERROR | `surveycore_error_subset_degenerate` | `"{.arg subset} column {.field {subset_var}} must contain both TRUE and FALSE values (non-NA). Found {n_true} TRUE and {n_false} FALSE (non-NA) value(s)."` |
| 23b | `as_survey_twophase()` | `subset` column contains NA values | ERROR | `surveycore_error_subset_na` | `"x" = "{.arg subset} column {.field {subset_var}} contains {n_na} NA value(s).", "i" = "The phase 2 membership indicator must be fully observed for all phase 1 units.", "v" = "Remove rows with missing {.arg subset} values before calling {.fn as_survey_twophase}."` |
| 24 | `as_survey_twophase()` | `method = "simple"` + clustered Phase 1 | WARN | `surveycore_warning_simple_clustered` | `'{.code method = "simple"} ignores the Phase 1 cluster design (PSUs: {.field {phase1@variables$ids}}). This understates variance. Use {.code method = "full"} or {.code method = "approx"}.'` |
| 26 | `as_survey_twophase()` (validator) | Phase 2 design var all-NA within Phase 2 subset | WARN | `surveycore_warning_phase2_all_na` | `"Phase 2 design variable {.field {var}} is all NA within the Phase 2 subset. Check rows where {.field {subset_var}} is TRUE."` |
| 27 | `set_var_label()` | Variable not found in data | ERROR | `surveycore_error_var_not_found` | `"Variable {.field {var_name}} not found in {.arg x}. Available: {.field {names(x@data)}}"` |
| 28 | `set_variable_labels()` | One or more variables not found | ERROR | `surveycore_error_vars_not_found` | `"Variable(s) not found in {.arg x}: {.field {missing}}"` |
| 29 | `set_val_labels()` | `labels` is not a named vector | ERROR | `surveycore_error_labels_unnamed` | `"{.arg labels} must be a fully named vector. All elements must have names."` |
| 30 | `set_val_labels()` | Some data values lack a label | WARN | `surveycore_warning_missing_labels` | `"Not all values of {.field {var_name}} are labeled. Unlabeled values: {.val {missing}}"` |
| 31 | S7 validator (`survey_taylor`) | Design variable not in data | ERROR | `surveycore_error_design_var_missing` | `"Design variable(s) not found in {.arg data}: {.field {missing}}"` |
| 32 | S7 validator (`survey_taylor`) | Weight column not numeric | ERROR | `surveycore_error_weights_not_numeric` | `"Weight column {.field {weights_var}} must be numeric, not {.cls {class(wt_col)}}"` |
| 33 | S7 validator (`survey_taylor`) | Weight column has non-positive values | ERROR | `surveycore_error_weights_nonpositive` | `"Weight column {.field {weights_var}} has {n_bad} non-positive value(s). All non-NA weights must be > 0."` |
| 34 | S7 validator (`survey_taylor`) | Design variable is a list-column | ERROR | `surveycore_error_design_var_list` | `"Design variable {.field {var}} is a list-column. Design variables must be atomic vectors."` |
| 35 | S7 validator (all) | PSU appears in multiple strata | WARN | `surveycore_warning_psu_multi_strata` | `"Some PSUs appear in more than one stratum: {.val {head(multi_strata_psus, 5)}}. If PSUs are nested within strata, set {.code nest = TRUE}."` |
| 36 | `update_design()` | Any design variable update | WARN | *(inform, not warn)* | `"Survey design updated. This may affect statistical validity. Updated: {.field {changed_vars}}"` |
| 37 | S7 validator (`survey_replicate`) | Replicate weight column not numeric | ERROR | `surveycore_error_repweights_not_numeric` | `"Replicate weight column {.field {rw}} must be numeric, not {.cls {class(rw_col)}}"` |
| 38 | S7 validator (`survey_twophase`) | Subset column is not logical | ERROR | `surveycore_error_subset_not_logical` | `"Subset column {.field {subset_var}} must be logical, not {.cls {col_class}}"` |
| 39 | S7 validator (`survey_twophase`) | Phase 2 design var all-NA within Phase 2 subset | WARN | `surveycore_warning_phase2_all_na` | `"Phase 2 design variable {.field {v}} is all NA within the Phase 2 subset. Check rows where {.field {subset_var}} is TRUE."` |
| 40 | `filter()` (surveytidy) | filter() produces all-FALSE domain | WARN | `surveycore_warning_empty_domain` | `"filter() produced an empty domain — no rows match the supplied condition. Variance estimation on this domain will fail."` |
| 41 | `mutate()` (surveytidy) | mutate() modifies the weight column | WARN | `surveycore_warning_weight_modified` | `"mutate() modified the weight column {.field {wt_var}}. This changes the survey design. Use {.fn update_design} to update the weight column explicitly."` |
| 42 | `subset()` (surveytidy) | subset() physically removes rows | WARN | `surveycore_warning_physical_subset` | `"subset() physically removes rows from the survey data. This is different from filter(), which preserves all rows for correct variance estimation. Subpopulation analyses should use filter() instead."` |
| 43 | `get_means()`, `get_totals()`, `get_corr()`, `get_ratios()` | Non-numeric column passed | ERROR | `surveycore_error_non_numeric_variable` | `"{.arg x} must be numeric, not {.cls {class(col)}}. Column {.field {var}} cannot be used with {.fn {fn_name}}."` |
| 44 | `get_corr()` | Fewer than 2 variables supplied | ERROR | `surveycore_error_insufficient_variables` | `"{.fn get_corr} requires at least 2 variables, but {.arg x} resolved to {length(vars)} variable{?s}."` |
| 45 | all `get_*()` | Unknown value for `variance` argument | ERROR | `surveycore_error_invalid_variance_arg` | `'{.arg variance} values must be from {.val {valid_variance}}. Unknown value{?s}: {.val {bad_vals}}.'` |
| 45a | all `get_*()` | `conf_level` not a single number strictly between 0 and 1 | ERROR | `surveycore_error_invalid_conf_level` | `"{.arg conf_level} must be a single number strictly between 0 and 1. Got {.val {conf_level}}."` |
| 45b | all `get_*()` | `decimals` is not a non-negative whole number or `NULL` | ERROR | `surveycore_error_invalid_decimals` | `"{.arg decimals} must be a non-negative whole number or {.code NULL}. Got {.val {decimals}}."` |
| 46 | all `get_*()` | Unknown value for `name_style` argument | ERROR | `surveycore_error_invalid_name_style` | `'{.arg name_style} must be {.val "surveycore"} or {.val "broom"}, not {.val {name_style}}.'` |
| 47 | `get_quantiles()` | `probs` outside (0,1) or length 0 | ERROR | `surveycore_error_invalid_probs` | `"{.arg probs} must be a non-empty numeric vector with all values in (0, 1). Invalid value{?s}: {.val {bad_probs}}."` |
| 48 | `get_ratios()` | All denominator values are zero | ERROR | `surveycore_error_ratio_zero_denominator` | `"All values of the denominator ({.field {denom_var}}) are zero. Cannot compute ratio."` |
| 49 | all `get_*()` | Any cell has unweighted `n < min_cell_n` (default 30, AAPOR guidance; for `get_corr()` "cell" = variable pair, threshold applies to pairwise n) | WARN | `surveycore_warning_small_cell` | `"{n_small} cell{?s} {?has/have} fewer than {min_cell_n} unweighted observations. Estimates in these cells may be unreliable for public reporting (AAPOR guidance)."` |
| 50 | all `get_*()` | A grouping variable has only one observed level | WARN | `surveycore_warning_single_level` | `"Grouping variable {.field {var}} has only one observed level ({.val {level}}). Grouped estimates will have a single row."` |
| 51 | `get_corr()` | Non-numeric variable in `x` silently dropped | WARN | `surveycore_warning_corr_non_numeric` | `"{.fn get_corr} requires numeric variables. Dropping non-numeric column{?s}: {.field {dropped}}."` |
| 52 | `get_freqs()` multi-var | Variables have different non-NULL question prefaces | WARN | `surveycore_warning_mixed_prefaces` | `"{length(unique_prefaces)} different question prefaces found across {length(vars)} variables. Variables with different prefaces may not belong in the same {.fn get_freqs} call. Prefaces stored in {.code meta(result)$question_prefaces}."` |
| 53 | `get_freqs()` | Focal variable all NA with `na.rm = FALSE` (categorical only — no levels to tabulate; numeric functions propagate NA naturally) | ERROR | `surveycore_error_all_na` | `"All values of {.field {var}} are {.code NA}. Cannot compute estimate with {.arg na.rm = FALSE}. Set {.arg na.rm = TRUE} to exclude {.code NA} values."` |
| 54 | all `get_*()` | `variance = "cv"` but estimate is 0 or negative | WARN | `surveycore_warning_cv_undefined` | `'{.arg variance = "cv"} is undefined for {n_undef} cell{?s} where the estimate is 0 or negative. {.code cv} set to {.code NA} for those cells.'` |
| 55 | `get_freqs()` | All values of focal variable are `NA` with `na.rm = TRUE` | WARN | `surveycore_warning_all_na_freqs` | `"All values of {.field {var}} are {.code NA} with {.arg na.rm = TRUE}. Returning 0 rows."` |
| 56 | `as_survey_srs()` | Both `weights` and `probs` supplied | ERROR | `surveycore_error_weights_probs_both` | `"Supply {.arg weights} or {.arg probs}, not both."` |
| 57 | `as_survey_srs()` | `fpc` column has non-positive values | ERROR | `surveycore_error_fpc_nonpositive` | `"{.arg fpc} column {.field {fpc_var}} has {n_bad} non-positive value(s). FPC values must be > 0."` |
| 58 | `as_survey_srs()` | `fpc` column mixes values > 1 and ≤ 1 | ERROR | `surveycore_error_fpc_ambiguous` | `"{.arg fpc} column {.field {fpc_var}} mixes values > 1 (population sizes) and values \u2264 1 (sampling fractions). All FPC values must be consistently one type."` |
| 59 | `as_survey_srs()` | `fpc` population size < sample size | ERROR | `surveycore_error_fpc_below_sample` | `"{.arg fpc} column {.field {fpc_var}} has {n_bad} value(s) smaller than the sample size ({n}). Population size cannot be smaller than the number of sampled units."` |
| 60 | `as_survey()` | No `ids` or `strata` — dispatching to `survey_srs` | WARN | `surveycore_warning_as_survey_srs_fallback` | `c("!" = "No {.arg ids} or {.arg strata} specified.", "i" = "Creating a {.cls survey_srs} design (equal-probability SRS).", "v" = "Use {.fn as_survey_srs} to create SRS designs without this warning.")` |
| 61 | `as_survey_srs()` | No `weights` provided — auto-assigning uniform weights | WARN | `surveycore_warning_srs_no_weights` | `"No {.arg weights} provided to {.fn as_survey_srs}. Assigning uniform weights ({.code ..surveycore_wt.. = 1}). Population size unknown — total estimates will use {.code \u03a3w_i = n} as the estimated N."` |
| 62 | `from_svydesign()` (twophase) | Could not determine two-phase variance method | WARN | `surveycore_warning_twophase_method_unknown` | `"Could not determine two-phase variance method from the survey object. Defaulting to {.val \"approx\"}."` |
| 63 | `.twophasevar()` (via `.twophase_mean()` / `.twophase_total()`) | `method = "full"` but `@variables$phase2` has no `ids`, `strata`, or `probs` | ERROR | `surveycore_error_full_requires_phase2` | `"x" = "Two-phase variance method {.val full} requires phase 2 design structure.", "i" = "No {.arg ids2}, {.arg strata2}, or {.arg probs2} were specified in {.fn as_survey_twophase}.", "v" = 'Reconstruct with {.arg method = "approx"} or supply phase 2 design variables.'` |
| 64 | `.check_unsupported_class()`, `.build_meta()` fallback | Object does not inherit from `survey_base` (`.check_unsupported_class()`), or inherits from `survey_base` but is not one of the five supported subclasses (`.build_meta()`) | ERROR | `surveycore_error_unsupported_class` | `.check_unsupported_class()`: `"{.fn {fn_name}} requires a survey design object. Got {.cls {class(design)[[1]]}}."` / `.build_meta()`: `"Unrecognized design class {.cls {class(design)[1]}}."` |
| 65 | `survey_glm()` | `formula` is `NULL` (not supplied by caller) | ERROR | `surveycore_error_formula_missing` | `"{.arg formula} is required."` |
| 66 | `survey_glm()` | `formula` not a formula object | ERROR | `surveycore_error_formula_invalid` | `"{.arg formula} must be a formula object, not {.cls {class(formula)[1]}}."` |
| 67 | `survey_glm()` | Response variable absent from `design@data` | ERROR | `surveycore_error_response_not_found` | `"Response variable {.field {resp}} not found in survey data."` |
| 68 | `survey_glm()` | Predictor absent from `design@data` | ERROR | `surveycore_error_predictor_not_found` | `"Predictor {.field {pred}} not found in survey data. Available columns: {.field {names(design@data)}}."` |
| 69 | `survey_glm()` | GLM did not converge | WARN | `surveycore_warning_glm_convergence` | `"{.fn survey_glm} did not converge. {.i Increase {.arg control$maxit} or simplify the model.}"` |
| 70 | `survey_glm()` | Response is a design variable | WARN | `surveycore_warning_response_is_design_var` | `"Response variable {.field {resp}} is a design variable ({.field {role}}). Results may be misleading."` |
| 71 | `survey_glm()` | Perfect separation (binomial family) | WARN | `surveycore_warning_perfect_separation` | `"Fitted probabilities are numerically 0 or 1. Perfect or quasi-complete separation may have occurred."` |
| 72 | `survey_glm()` | Singular or aliased model matrix | ERROR | `surveycore_error_singular_model_matrix` | `"Model matrix is singular. Check for perfect collinearity or empty factor levels."` |
| 73 | `survey_glm()` | `@groups` set on design | WARN | `surveycore_warning_groups_ignored_in_glm` | `"{.fn survey_glm} does not support grouped designs. The {.field @groups} property is ignored. Use {.fn surveytidy::group_by} after fitting to group results."` |
| 74 | `survey_glm()` | Weight column contains `NA` | ERROR | `surveycore_error_na_weights` | `"Weight column {.field {wt_var}} contains {sum(is.na(wt))} NA value(s). Survey weights must be fully observed. Remove rows with missing weights or impute before calling {.fn survey_glm}."` |
| 75 | `clean()` | `model` not a `survey_glm_fit` | ERROR | `surveycore_error_not_glm_fit` | `"{.arg model} must be a {.cls survey_glm_fit} object, not {.cls {class(model)[1]}}."` |
| 76 | `predict.survey_glm_fit()`, `residuals.survey_glm_fit()` | `fit_` slot is `NULL` | ERROR | `surveycore_error_predict_no_fit` | `"The internal {.field fit_} slot is NULL. This can happen after serialization. Refit the model to restore prediction support."` |
| 77 | `survey_glm()` | `df_residual` would be ≤ 0 | WARN | `surveycore_warning_insufficient_df` | `"Design degrees of freedom ({degf}) minus model parameters ({p - 1}) is ≤ 0. Clamping {.code df_residual = 1}. CI bounds and p-values are conservative."` |
| 82 | `survey_glm()` | Both `formula` and `response`/`predictors` supplied | ERROR | `surveycore_error_formula_conflict` | `"{.arg formula} and {.arg response}/{.arg predictors} are mutually exclusive. {.i Specify the model using either {.arg formula} or {.arg response}/{.arg predictors}, not both.}"` |
| 83 | `survey_glm()` | Active domain contains zero in-domain rows | ERROR | `surveycore_error_empty_domain` | `"Active domain contains no in-domain rows. {.i Apply a less restrictive {.fn surveytidy::filter} before calling {.fn survey_glm}.}"` |
| 84 | `clean()` | `exponentiate = TRUE` with non-log link | WARN | `surveycore_warning_exponentiate_nonlog` | `"{.arg exponentiate = TRUE} with a non-log link ({.val {model@family$link}}) may produce uninterpretable estimates."` |
| 85 | `survey_glm()` | Weight column contains zero or negative values | WARN | `surveycore_warning_nonpositive_weights` | `"Weight column {.field {wt_var}} contains {sum(wt <= 0)} non-positive value(s). {.i Zero-weight rows are excluded from fitting by {.fn stats::glm}. Negative weights are statistically invalid.}"` |
| 86 | `survey_glm()` | `cbind()` on LHS of formula | ERROR | `surveycore_error_cbind_response_unsupported` | `"{.code cbind()} on the left-hand side of {.arg formula} is not supported. {.i Multinomial logistic regression is deferred to a later phase. Use a single binary or continuous response variable.}"` |
| 87 | `survey_glm()` | `na.action = na.fail` and response/predictor has NA | ERROR | `surveycore_error_na_in_data` | `"x" = "{n_na_cols} column{?s} in the model {?has/have} NA values with {.arg na.action = na.fail}: {.field {na_info}}.", "v" = "Set {.arg na.action = na.omit} to drop rows with NA, or remove them manually before calling {.fn survey_glm}."` |
| 78 | `infer_question_prefaces()` | `x` is not a survey object or data frame | ERROR | `surveycore_error_not_survey_or_df` | `"{.arg x} must be a survey design object or a data frame, not {.cls {class(x)[[1L]]}}."` |
| 79 | `infer_question_prefaces()` | Variable already has `question_preface` and `overwrite = FALSE` | WARN | `surveycore_warning_preface_not_overwritten` | `"{length(skipped)} variable{?s} already {?has/have} a question preface and {?was/were} skipped. Set {.arg overwrite = TRUE} to replace them."` |
| 80 | `infer_question_prefaces()` | Trimming the preface leaves an empty label | WARN | `surveycore_warning_empty_label_after_trim` | `"Variable {.field {var_name}} would have an empty label after trimming the preface. Skipping."` |
| 81 | all `get_*()` (via `.validate_shared_args()`) | `na.rm` is not `TRUE` or `FALSE` (e.g., `NA`, `1`, `"yes"`) | ERROR | `surveycore_error_na_rm_not_logical` | `"x" = "{.arg na.rm} must be {.code TRUE} or {.code FALSE}.", "i" = "Got {.obj_type_friendly {na.rm}}."` |

---

## Notes on Typed Errors

All `cli_abort()` calls must include a `class` argument so tests can match on
error class without depending on exact message text:

```r
cli::cli_abort(
  c("x" = "{.arg data} must be a data frame, not {.cls {class(data)}}"),
  class = "surveycore_error_not_data_frame"
)
```

Tests should use BOTH:
1. `expect_error(..., class = "surveycore_error_not_data_frame")` — tests that the right error fires
2. `expect_snapshot(error = TRUE, ...)` — tests the exact message text (golden test)

---

## Snapshot Test Policy

- Snapshot tests live in `tests/testthat/_snaps/`
- One snapshot file per source test file (e.g., `test-constructors.R` → `_snaps/test-constructors.md`)
- Run `testthat::snapshot_review()` to review and approve message text changes
- Snapshot tests are brittle to cli formatting changes — only snapshot the message
  body, not ANSI codes. Use `cli::test_that_cli()` if needed.

---

## Coverage Map

Which test files cover which error table rows:

| Test File | Error Rows Covered |
|-----------|-------------------|
| `test-constructors.R` | 1–24, 23b, 56–61 |
| `test-variance-twophase.R` | 63 |
| `test-validators.R` | 27–35 |
| `test-metadata-system.R` | 27–30 |
| `test-s7-classes.R` | 31–35, 37–39 |
| `test-update-design.R` | 36 |
| `test-analysis-helpers.R` | 45, 45a, 45b, 46 (direct unit tests on `.validate_shared_args()` and `.apply_decimals()`); 64 (`.check_unsupported_class()` and `.build_meta()` fallback); also integration-checked in per-function files |
| `test-analysis-freqs.R` | 45, 45a, 45b, 46, 49, 50, 52, 53, 55 |
| `test-analysis-means.R` | 43, 45, 45a, 45b, 46, 49, 50, 54 |
| `test-analysis-totals.R` | 43, 45, 45a, 45b, 46, 49, 50, 54 |
| `test-analysis-corr.R` | 43, 44, 45, 45a, 45b, 46, 49, 50, 51, 54 |
| `test-analysis-quantiles.R` | 45, 45a, 45b, 46, 47, 49, 50, 54 |
| `test-analysis-ratios.R` | 43, 45, 45a, 45b, 46, 48, 49, 50, 54 |
| `test-glm.R` | 64 (via `.check_unsupported_class()`), 65–74, 77, 82–87 (Layer 3 dual pattern); S7 validator errors in Section 3.3 (class= only, not in this table) |
| `test-glm-methods.R` | 76 |
| `test-glm-clean.R` | 75, 84 |
| `test-metadata-infer.R` | 78, 79, 80 |
