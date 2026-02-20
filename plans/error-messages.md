# surveycore Canonical Error Message Table

**Version:** 1.0
**Created:** February 2025
**Status:** Authoritative — spec prose and plan templates must match this table exactly.

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
| 6 | `as_survey()` | Both `probs` and `weights` provided, consistent values | INFO | *(inform, no class)* | `"Using {.arg weights}; provided {.arg probs} is consistent (weights = 1/probs)"` |
| 7 | `as_survey()` | No weights, probs, or ids (SRS) | WARN | `surveycore_warning_srs_no_weights` | `"No weights or population size provided. Treating as equal-probability SRS with unknown population size. Valid: means, proportions, correlations. Invalid: population totals."` |
| 8 | `as_survey()` | `weights` selects 0 columns | ERROR | `surveycore_error_weights_not_found` | `"{.arg weights} matched no columns in {.arg data}"` |
| 9 | `as_survey()` | `weights` selects >1 column | ERROR | `surveycore_error_weights_multiple` | `"{.arg weights} must select exactly one column, not {length(weights_cols)}"` |
| 10 | `as_survey()` | `weights` all zero | ERROR | `surveycore_error_weights_all_zero` | `"All values in {.arg weights} ({.field {weights_var}}) are zero or missing — no valid weights"` |
| 11 | `as_survey()` | `strata` selects 0 columns | ERROR | `surveycore_error_strata_not_found` | `"{.arg strata} matched no columns in {.arg data}"` |
| 11b | `as_survey()` | `strata` selects >1 column | ERROR | `surveycore_error_strata_multiple` | `"{.arg strata} must select exactly one column, not {length(strata_cols)}"` |
| 12 | `as_survey()` | `strata` resolves to 1 unique value | WARN | `surveycore_warning_single_stratum` | `"{.arg strata} ({.field {strata_var}}) has only 1 unique value — stratification has no effect"` |
| 13 | `as_survey()` / `as_survey_rep()` | `fpc` selects 0 columns | ERROR | `surveycore_error_fpc_not_found` | `"{.arg fpc} matched no columns in {.arg data}"` |
| 13b | `as_survey()` / `as_survey_rep()` | `fpc` selects >1 column | ERROR | `surveycore_error_fpc_multiple` | `"{.arg fpc} must select exactly one column, not {length(fpc_cols)}"` |
| 14 | `as_survey()` | `fpc` column contains `NA` | ERROR | `surveycore_error_fpc_na` | `"{.arg fpc} column {.field {fpc_var}} contains {sum(is.na(fpc_col))} NA value(s). FPC must be fully observed."` |
| 15 | `as_survey()` | `nest = TRUE` with no `strata` | ERROR | `surveycore_error_nest_without_strata` | `"{.arg nest = TRUE} requires {.arg strata} to be specified"` |
| 16 | `as_survey_rep()` | `repweights` selects 0 columns | ERROR | `surveycore_error_repweights_empty` | `"{.arg repweights} must select at least one column"` |
| 17 | `as_survey_rep()` | `scale`/`rscales` length mismatch | ERROR | `surveycore_error_rscales_length` | `"Length of {.arg rscales} ({length(rscales)}) must equal number of replicate weights ({n_rep})"` |
| 18 | `as_survey_rep()` | `type` not in valid set | ERROR | *(handled by match.arg)* | `"'{type}' is not a valid replicate type. Choose from: {.val {valid_types}}"` |
| 19 | `as_survey_twophase()` | `phase1` is not a `survey_taylor` | ERROR | `surveycore_error_phase1_class` | `"{.arg phase1} must be a {.cls survey_taylor} object, not {.cls {class(phase1)[[1]]}}. Create it first with {.fn as_survey}."` |
| 20 | `as_survey_twophase()` | `subset` not provided (missing) | ERROR | `surveycore_error_subset_missing` | `"{.arg subset} is required: a logical column indicating Phase 2 membership"` |
| 21 | `as_survey_twophase()` | `subset` selects >1 column | ERROR | `surveycore_error_subset_multiple` | `"{.arg subset} must select exactly one column, not {length(subset_cols)}"` |
| 22 | `as_survey_twophase()` | `subset` column is not logical | ERROR | `surveycore_error_subset_not_logical` | `"{.arg subset} column {.field {subset_var}} must be logical, not {.cls {class(data[[subset_var]])}}"` |
| 23 | `as_survey_twophase()` | `subset` is all TRUE or all FALSE | ERROR | `surveycore_error_subset_degenerate` | `"{.arg subset} column {.field {subset_var}} must contain both TRUE and FALSE values. Found {sum(subset_vals)} TRUE out of {length(subset_vals)} rows."` |
| 24 | `as_survey_twophase()` | `method = "simple"` + clustered Phase 1 | WARN | `surveycore_warning_simple_clustered` | `'{.code method = "simple"} ignores the Phase 1 cluster design (PSUs: {.field {phase1@variables$ids}}). This understates variance. Use {.code method = "full"} or {.code method = "approx"}.'` |
| 25 | `as_survey_twophase()` | `method = "full"` + no Phase 2 design info | WARN | `surveycore_warning_full_no_phase2` | `'No Phase 2 design information provided with {.code method = "full"}. Phase 2 selection treated as simple random subsampling within Phase 1 strata.'` |
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
| `test-constructors.R` | 1–26 |
| `test-validators.R` | 27–35 |
| `test-metadata-system.R` | 27–30 |
| `test-s7-classes.R` | 31–35, 37–39 |
| `test-update-design.R` | 36 |
