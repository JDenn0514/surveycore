# Changelog: `get_t_test()` and `get_pairwise()`

**Branch:** `feature/get-t-test-pairwise`
**PR:** TBD
**Date:** 2026-04-15

---

## Summary

Implements two new exported analysis functions for design-based group
comparisons:

- `get_t_test()` — design-based two-sample t-test comparing group means
- `get_pairwise()` — all k(k−1)/2 pairwise comparisons with p-value adjustment

Neither function uses the `survey` package. Both delegate variance estimation
to `survey_glm()`, following the mathematical model of `survey::svyttest()`.
Results match `survey::svyttest()` exactly at tolerance 1e-10 for point
estimates, 1e-10 for t-statistic and df, and 1e-6 for CI bounds.

---

## New Exports

### `get_t_test(design, x, by, ...)`

Design-based two-sample t-test. Arguments:

| Argument | Default | Description |
|---|---|---|
| `design` | — | Survey design object |
| `x` | — | Numeric outcome variable (unquoted) |
| `by` | — | Grouping variable with exactly 2 active levels (unquoted) |
| `group` | `NULL` | Optional stratification variable(s); one row per stratum |
| `conf_level` | `0.95` | Confidence level for CI |
| `variance` | `c("se", "ci")` | Which variance columns to include |
| `na.rm` | `TRUE` | Accepted for API uniformity; NAs always excluded |
| `min_cell_n` | `5L` | Minimum unweighted n per cell before warning |
| `label_values` | `TRUE` | Convert factor codes to value labels |
| `label_vars` | `TRUE` | Accepted for API uniformity; column names are fixed |
| `name_style` | `"surveycore"` | `"broom"` renames to tidyverse conventions |
| `decimals` | `NULL` | Round all double columns to N decimal places |

Returns a `survey_t_test` tibble (also `survey_result`) with columns:
`level_a`, `level_b`, `estimate`, `mean_a`, `mean_b`, `n_a`, `n_b`,
`ci_low`, `ci_high`, `t_stat`, `df`, `p_value`, `stars`, plus any `group`
columns.

### `get_pairwise(design, x, by, ...)`

All-pairs pairwise t-tests with multiple-comparison adjustment. Additional
arguments beyond `get_t_test()`:

| Argument | Default | Description |
|---|---|---|
| `pval_adj` | `"holm"` | P-value adjustment method (any `stats::p.adjust()` method, or `"none"`) |

Returns a `survey_pairwise` tibble with one row per pair (or per pair per
group stratum). Pairs are in lexicographic factor-level order. P-value
adjustment is applied separately within each group stratum.

---

## New S3 Classes

| Class | Inherits | Description |
|---|---|---|
| `survey_t_test` | `survey_result`, `tbl_df` | Result of `get_t_test()` |
| `survey_pairwise` | `survey_result`, `tbl_df` | Result of `get_pairwise()` |

Both classes have custom `print()` methods with a header showing design type,
N, outcome variable, and grouping variable.

---

## New Meta-Key Constants

Added to `R/analysis-helpers.R`:

- `T_TEST_META_KEYS` — `c("group", "x", "by")`
- `PAIRWISE_META_KEYS` — `c("group", "x", "by", "pval_adj")`

---

## New Error and Warning Classes

Five new entries in `plans/error-messages.md`:

| ID | Class | Trigger |
|---|---|---|
| T-1 | `surveycore_error_by_not_two_levels` | `by` has ≠ 2 active groups |
| T-2 | `surveycore_warning_by_coerced` | `by` is character/integer/logical, coerced to factor |
| T-3 | `surveycore_error_by_empty_cell` | One `by` level has no non-NA observations |
| T-3g | `surveycore_error_by_empty_cell` | Empty cell in a group stratum (same class, different message) |
| P-1 | `surveycore_error_by_one_level` | `by` has < 2 active groups in `get_pairwise()` |

---

## Files Changed

**New files:**
- `R/analysis-t-test.R` — `get_t_test()`, `get_pairwise()`, print methods,
  `.enumerate_pairs()` helper
- `tests/testthat/test-analysis-t-test.R` — 170+ unit tests (happy path,
  error path, edge cases, print snapshots, meta contract)
- `tests/testthat/test-analysis-t-test-numerical.R` — oracle tests vs
  `survey::svyttest()`
- `man/get_t_test.Rd`, `man/get_pairwise.Rd` — generated documentation

**Modified files:**
- `R/analysis-helpers.R` — added `T_TEST_META_KEYS`, `PAIRWISE_META_KEYS`
- `plans/error-messages.md` — added T-1, T-2, T-3, T-3g, P-1 rows
- `NAMESPACE` — exports `get_t_test`, `get_pairwise`
- `_pkgdown.yml` — added `get_t_test`, `get_pairwise` to Analysis section

---

## Test Coverage

- `R/analysis-t-test.R`: 100% line coverage
- All 5 new error/warning classes have typed `expect_error(class = ...)` /
  `expect_warning(class = ...)` tests
- All 4 design classes (`survey_taylor`, `survey_replicate`, `survey_twophase`,
  `survey_nonprob`) have ≥1 happy-path test for both functions
- Numerical oracle tests pass vs `survey::svyttest()` on NHANES:
  - Point estimate: tolerance 1e-10
  - t-statistic: tolerance 1e-10
  - df: tolerance 1e-10
  - p-value: tolerance 1e-10
  - CI bounds: tolerance 1e-6
- `get_pairwise()` on 2-level `by` matches `get_t_test()` (quality gate)
