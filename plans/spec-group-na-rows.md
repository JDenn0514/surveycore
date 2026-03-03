# Spec: NA Group Rows in Analysis Functions

**Version:** 1.0
**Date:** 2026-03-02
**Status:** Draft
**Feature branch:** `fix/group-na-rows`
**Spec ID:** `group-na-rows`

---

## Document Purpose

This is the authoritative specification for extending the `na.rm` argument in
all six surveycore analysis functions to include rows where a **grouping
variable** is `NA` in the output when `na.rm = FALSE`. Currently, such rows are
silently dropped regardless of `na.rm`. This spec defines the exact behavioral
contract, the shared helper changes, and the required test coverage. All
implementation decisions must trace back to this document.

---

## I. Scope

### What this spec delivers

| Item | Description |
|---|---|
| Extended `na.rm` semantics | `na.rm` now controls NAs in both focal variables and group variables |
| NA group rows in output | When `na.rm = FALSE`, an NA-valued group combination appears as its own row |
| Consistent implementation | Two new shared helpers replace two divergent patterns across 6 functions |
| Unified sorting of NA rows | NA-containing group combos always sorted after non-NA combos |
| Updated roxygen docs | `@param na.rm` updated in all 6 function files |

### What this spec does NOT deliver

- A separate `group_na.rm` argument — the `na.rm` argument is unified
- Changes to focal-variable NA handling — existing `na.rm` behavior for
  focal variables is preserved
- Changes to `na.rm` default — remains `TRUE` (excluding NAs by default)
- Changes to how NAs in the focal variable appear in `get_freqs()` — that
  behavior is governed by the existing `na.rm = FALSE` contract

### Design class support matrix

All 6 analysis functions support all 5 design classes, unchanged:

| Function | `survey_taylor` | `survey_replicate` | `survey_twophase` | `survey_srs` | `survey_calibrated` |
|---|---|---|---|---|---|
| `get_freqs()` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `get_means()` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `get_totals()` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `get_corr()` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `get_quantiles()` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `get_ratios()` | ✓ | ✓ | ✓ | ✓ | ✓ |

---

## II. Architecture

### Existing inconsistency (to be resolved)

Two patterns currently exist for building group combinations from NA-containing
data:

**Pattern A** (`complete.cases` pre-filter) — used in `get_freqs()`,
`get_quantiles()`, `get_ratios()`:
```r
complete_idx  <- stats::complete.cases(domain_data)
group_combos  <- unique(domain_data[complete_idx, , drop = FALSE])
```

**Pattern B** (`Reduce` / `has_na`) — used in `get_corr()`:
```r
has_na       <- Reduce(`|`, lapply(group_vars, function(gv) is.na(domain_data[[gv]])))
group_combos <- unique(domain_data[!has_na, , drop = FALSE])
```

**Pattern C** (bare `unique()` with no explicit NA filter) — used in
`get_means()`, `get_totals()`:
```r
group_combos <- unique(domain_data)
```
Pattern C relies on the inline matching loop's `!is.na(gv_col)` guard to
implicitly skip NA combos. NA-valued combination rows may still appear in
`group_combos` (since no pre-filter exists), but the loop never selects them.

All three patterns achieve the same result (exclude NA rows from output) but
diverge in implementation. All three are replaced by a single shared helper.

### File organization

No new files. Changes are confined to:

```
R/
  analysis-helpers.R       ← add .build_group_combos() and .match_group_combo()
  analysis-freqs.R         ← replace pattern + update @param na.rm
  analysis-means.R         ← replace pattern + update @param na.rm
  analysis-totals.R        ← replace pattern + update @param na.rm
  analysis-corr.R          ← replace pattern + update @param na.rm
  analysis-quantiles.R     ← replace pattern + update @param na.rm
  analysis-ratios.R        ← replace pattern + update @param na.rm

tests/testthat/
  test-analysis-freqs.R    ← add NA group row tests
  test-analysis-means.R    ← add NA group row tests
  test-analysis-totals.R   ← add NA group row tests
  test-analysis-corr.R     ← add NA group row tests
  test-analysis-quantiles.R← add NA group row tests
  test-analysis-ratios.R   ← add NA group row tests
```

Consistent with the existing analysis helper pattern established in Phase 1,
new helpers used across 2+ analysis source files live in `R/analysis-helpers.R`
(not `utils.R`, which is for package-wide utilities).

### New shared helpers (added to `R/analysis-helpers.R`)

**`.build_group_combos(domain_data, na.rm)`**

Builds the data frame of unique group value combinations from `domain_data`
(a data frame already filtered to the active domain rows, containing only the
group variable columns). When `na.rm = TRUE`, rows with any `NA` are excluded
before `unique()`. When `na.rm = FALSE`, all rows including NA-containing are
used. Output is sorted: non-NA-containing combos first (sorted ascending),
NA-containing combos last.

```r
# @param domain_data  data.frame; rows = active domain; cols = group vars only
# @param na.rm        logical; if TRUE, NA rows excluded before unique()
# @return             data.frame of unique group combinations, sorted
.build_group_combos <- function(domain_data, na.rm) {
  if (na.rm) {
    domain_data <- domain_data[stats::complete.cases(domain_data), , drop = FALSE]
  }
  combos <- unique(domain_data)
  if (nrow(combos) == 0L) return(combos)
  # Sort: non-NA combos first (sorted ascending), NA combos last.
  # order() with na.last = TRUE puts NA values after non-NA values.
  # Leftmost group variable is the primary sort key.
  # unname() prevents column names from colliding with order()'s named
  # formals (decreasing, method, na.last) if a group var shares a name.
  sort_vecs         <- unname(lapply(names(combos), function(v) combos[[v]]))
  ord               <- do.call(order, c(sort_vecs, list(na.last = TRUE)))
  combos            <- combos[ord, , drop = FALSE]
  rownames(combos)  <- NULL
  combos
}
```

**`.match_group_combo(data_cols, combo_row)`**

Returns a logical vector indicating which rows in `data_cols` match the
single group combination `combo_row`. Handles `NA` correctly: when
`combo_row[[gv]]` is `NA`, matches rows where `data_cols[[gv]]` is also
`NA`. This replaces the inline `!is.na(gv_col) & (gv_col == cv)` loop in
all 6 functions. **Audit confirmed:** all 6 functions (`get_freqs()`,
`get_means()`, `get_totals()`, `get_corr()`, `get_quantiles()`,
`get_ratios()`) have the identical inline loop at their cell-computation
stage and must be updated.

**Call-site pattern (used identically in all 6 functions):**

```r
# data_cols is built from the FULL design (not domain-filtered).
# The domain mask is applied AFTER combining with the group match.
data_cols   <- as.list(design@data[group_vars])     # full-length columns
group_match <- .match_group_combo(data_cols, combo_row)
active_mask <- domain_mask & group_match            # domain applied here
```

`data_cols` must be full-design length because `active_mask` combines
`domain_mask` (full length) with the returned vector via `&`. Building
`data_cols` from domain-filtered rows would produce a vector of the wrong
length and cause an error.

```r
# @param data_cols  named list; one element per group var; each a vector of
#                   length nrow(design@data) — full design, NOT domain-filtered
# @param combo_row  single-row data.frame; colnames match names(data_cols)
# @return           logical vector; TRUE where the row matches the combo
.match_group_combo <- function(data_cols, combo_row) {
  match_vec <- rep(TRUE, length(data_cols[[1L]]))
  for (gv in names(combo_row)) {
    gv_col <- data_cols[[gv]]
    cv     <- combo_row[[gv]]
    if (is.na(cv)) {
      match_vec <- match_vec & is.na(gv_col)
    } else {
      match_vec <- match_vec & !is.na(gv_col) & (gv_col == cv)
    }
  }
  match_vec
}
```

---

## III. Behavioral Contract (all functions)

### `na.rm = TRUE` (default) — no change

Group variable NAs are excluded from group combinations (current behavior).
Focal variable NAs are excluded from calculations (current behavior).

### `na.rm = FALSE` — extended behavior

Rows where any group variable is `NA` are collected into their own combination
row in the output. That combination row appears after all non-NA combination
rows, with `NA` in the group column(s).

Focal variable NAs are included in calculations (current behavior).

When domain estimation is active, the NA group row (if any) is derived from
domain-eligible rows only. If no domain-eligible row has a group variable equal
to `NA`, no NA group row appears in the output. More generally, if
`active_mask` selects zero rows for any group combo (NA or non-NA), that combo
is silently dropped from the output. Domain estimation in surveycore is applied
via `surveytidy::filter()` before calling the analysis function — not via a
`domain =` argument. The `.apply_domain(design)` helper extracts the domain
mask set by `filter()`.

### Multi-variable groups

When `group = c(region, gender)` and `region` has `NA` values, the output
includes one row per unique (region, gender) combination, including combinations
where `region` is `NA`. For example:

| region | gender | mean | se |
|---|---|---|---|
| East | F | … | … |
| East | M | … | … |
| West | F | … | … |
| West | M | … | … |
| NA | F | … | … |
| NA | M | … | … |

This is consistent with how R's `order()` treats `NA` (put last) and how
`dplyr::group_by()` / `summarise()` behaves with `na.rm` off.

When multiple group variables have `NA` values simultaneously for the same row,
the `(NA, NA, ...)` combination appears as a single row in the output (not one
row per variable).

### NA rows and the single-level group warning

The warning that fires when a group variable has only one non-NA unique value
checks `unique(gv_vals[!is.na(gv_vals)])`. This check is unchanged: the warning
remains based on non-NA levels only. The presence of an NA group row does not
affect the warning condition.

### Output column types

The group column type in the NA row is the same as the non-NA rows (character,
factor, integer, etc.). An `NA` of the appropriate type is used.

When `label_values = TRUE` converts a group column to a factor, two cases apply:

- **Regular `NA`** (no associated value label): remains `NA` in the factor —
  it is not promoted to a new factor level.
- **Haven-labeled `NA`** (a tagged NA with an associated value label, e.g., a
  coded "Refused" or "Don't know" value): converted to a factor level using its
  label, consistent with how `label_values = TRUE` handles other labeled coded
  values. This preserves the semantic meaning of the coded NA category.

### `.meta` structure

The `.meta` attribute on the result object is unchanged. Group variable metadata
(`value_labels`, `variable_label`, `question_preface`) is still derived from
non-NA observations. No new `.meta` keys are introduced.

---

## IV. Updated `@param na.rm` (all 6 functions)

Replace existing `@param na.rm` documentation in each function file with:

**For `get_means()`, `get_totals()`, `get_corr()`, `get_quantiles()`,
`get_ratios()` — unified text:**

```
#' @param na.rm Logical. If `TRUE` (default), `NA` values are excluded from
#'   analysis: observations where the analysis variable is `NA` are dropped
#'   from calculations, and observations where any group variable is `NA` are
#'   excluded from the output. If `FALSE`, `NA` observations in the analysis
#'   variable are included in calculations, and observations where a group
#'   variable is `NA` are collected into their own group row in the output
#'   (appearing after all non-`NA` group rows).
```

**For `get_freqs()` — extended text (focal-variable NA behavior differs):**

```
#' @param na.rm Logical. If `TRUE` (default), `NA` values are excluded from
#'   analysis: observations where the focal variable is `NA` are dropped from
#'   frequency counts, and observations where any group variable is `NA` are
#'   excluded from the output. If `FALSE`, `NA` values in the focal variable
#'   appear as a dedicated frequency row in the output (not merely counted),
#'   and observations where a group variable is `NA` are collected into their
#'   own group row (appearing after all non-`NA` group rows).
```

---

## V. Error and Warning Contracts

One new error class is introduced by this spec:

**`surveycore_error_na_rm_not_logical`** — fires when `na.rm` is not `TRUE`
or `FALSE` (e.g., `na.rm = NA`, `na.rm = 1`, `na.rm = "yes"`). The validation
is added to `.validate_shared_args()` in `R/analysis-helpers.R` so all 6
functions are covered by a single change:

```r
if (!isTRUE(na.rm) && !isFALSE(na.rm)) {
  cli::cli_abort(
    c(
      "x" = "{.arg na.rm} must be {.code TRUE} or {.code FALSE}.",
      "i" = "Got {.obj_type_friendly {na.rm}}."
    ),
    class = "surveycore_error_na_rm_not_logical"
  )
}
```

This class must be added to `plans/error-messages.md` before implementation.

The single-level group warning (`surveycore_warning_single_level`) fires when
`length(unique(gv_vals[!is.na(gv_vals)])) < 2L` — i.e., fewer than 2 distinct
**non-NA** values in the group variable within the domain. As part of this fix,
the existing condition in all 6 functions is widened from `== 1L` to `< 2L`,
so the all-NA group case (0 non-NA unique values) also fires the warning.

---

## VI. Testing

Tests follow `testing-standards.md` and `testing-surveycore.md`. New test
blocks are added to each existing analysis test file.

### Shared test fixtures (add to `tests/testthat/helper-test-data.R`)

All 6 test files share these fixtures. Do not reimplement per-file.

```r
# Standard NA-group design: ~20% of grp values are NA
# set.seed(seed + 1L) isolates grp/grp2 RNG from make_survey_data() internals,
# keeping fixture values stable if make_survey_data() changes internally.
make_na_group_design <- function(n = 200, na_frac = 0.2, seed = 42) {
  df      <- make_survey_data(n = n, seed = seed)
  set.seed(seed + 1L)
  na_idx  <- sample(seq_len(n), size = floor(n * na_frac))
  df$grp  <- sample(c("A", "B", "C"), n, replace = TRUE)
  df$grp[na_idx] <- NA_character_
  df$grp2 <- sample(c("X", "Y"), n, replace = TRUE)  # second group var (no NAs)
  as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc, nest = TRUE)
}

# All-NA group design (for Test Block 6)
make_all_na_group_design <- function(n = 100, seed = 1) {
  df      <- make_survey_data(n = n, seed = seed)
  df$grp  <- NA_character_
  as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc, nest = TRUE)
}
```

### Estimate column names (per function)

| Function | Estimate column | SE column |
|---|---|---|
| `get_freqs()` | `prop` | `se` |
| `get_means()` | `mean` | `se` |
| `get_totals()` | `total` | `se` |
| `get_corr()` | `correlation` | `se` |
| `get_quantiles()` | `quantile` | `se` |
| `get_ratios()` | `ratio` | `se` |

### Required test blocks (per function, 6 functions total)

**1. Default behavior unchanged (regression guard)**
```r
test_that("get_X() default (na.rm = TRUE) excludes group NA rows", {
  # Set up design where group var has NA values
  # Call with default na.rm (TRUE)
  result <- get_X(design, x, group = grp)
  expect_false(anyNA(result$grp))
})
```

**2. `na.rm = FALSE` includes NA group row**
```r
test_that("get_X() includes NA group row when na.rm = FALSE", {
  result <- get_X(design, x, group = grp, na.rm = FALSE)
  expect_true(any(is.na(result$grp)))
})
```

**3. NA group row is last**
```r
test_that("get_X() places NA group row after non-NA rows", {
  result <- get_X(design, x, group = grp, na.rm = FALSE)
  na_rows <- which(is.na(result$grp))
  nonna_rows <- which(!is.na(result$grp))
  expect_true(all(na_rows > max(nonna_rows)))
})
```

**4. NA group row contains estimates (not all-NA values)**
```r
test_that("get_X() NA group row has finite estimates", {
  result <- get_X(design, x, group = grp, na.rm = FALSE)
  na_row <- result[is.na(result$grp), ]
  # Replace <estimate_col> with the function-specific column (see table above):
  #   get_freqs(): prop    get_means(): mean    get_totals(): total
  #   get_corr(): correlation             get_quantiles(): quantile
  #   get_ratios(): ratio
  expect_true(is.finite(na_row$<estimate_col>[[1L]]))
})
```

Per-function versions:
```r
# get_freqs()
expect_true(is.finite(na_row$prop[[1L]]))
# get_means()
expect_true(is.finite(na_row$mean[[1L]]))
# get_totals()
expect_true(is.finite(na_row$total[[1L]]))
# get_corr()
expect_true(is.finite(na_row$correlation[[1L]]))
# get_quantiles()
expect_true(is.finite(na_row$quantile[[1L]]))
# get_ratios()
expect_true(is.finite(na_row$ratio[[1L]]))
```

**5a. Multi-group: NA in the first group var, non-NA in the second**
```r
test_that("get_X() handles NA in first of two group vars (na.rm = FALSE)", {
  # make_na_group_design() has NA in grp, grp2 is always non-NA
  result <- get_X(make_na_group_design(), x, group = c(grp, grp2), na.rm = FALSE)
  expect_true(any(is.na(result$grp) & !is.na(result$grp2)))
})
```

**5b. Multi-group: NA in the second group var, non-NA in the first**

This exercises a different iteration order in `.match_group_combo()`'s
`for (gv in names(combo_row))` loop from Block 5a.

```r
test_that("get_X() handles NA in second of two group vars (na.rm = FALSE)", {
  df <- make_survey_data(n = 200L, seed = 42L)
  set.seed(43L)
  df$grp  <- sample(c("A", "B", "C"), 200L, replace = TRUE)  # no NAs
  df$grp2 <- sample(c("X", "Y", NA_character_), 200L, replace = TRUE)
  design_na_grp2 <- as_survey(df, ids = psu, weights = wt, strata = strata,
                               fpc = fpc, nest = TRUE)
  result <- get_X(design_na_grp2, x, group = c(grp, grp2), na.rm = FALSE)
  expect_true(any(!is.na(result$grp) & is.na(result$grp2)))
})
```

**6. All-NA group var (edge case)**

Note: when all group values are `NA`, `unique(gv_vals[!is.na(gv_vals)])` returns
`character(0)` (length 0), which is fewer than 2 non-NA unique values — so
`surveycore_warning_single_level` fires (condition widened to `< 2L`). The test
must expect this warning.

```r
test_that("get_X() handles group var that is entirely NA (na.rm = FALSE)", {
  design_all_na_group <- make_all_na_group_design(n = 100, seed = 1)
  # When all group values are NA, output should have exactly 1 row (the NA row).
  # The single-level group warning fires because there are 0 non-NA unique values.
  expect_warning(
    result <- get_X(design_all_na_group, x, group = grp, na.rm = FALSE),
    class = "surveycore_warning_single_level"
  )
  expect_equal(nrow(result), 1L)
  expect_true(is.na(result$grp[[1L]]))
  # NA group row has a finite estimate
  # Replace <estimate_col> per-function (see table above):
  #   get_freqs(): prop    get_means(): mean    get_totals(): total
  #   get_corr(): correlation    get_quantiles(): quantile    get_ratios(): ratio
  expect_true(is.finite(result$<estimate_col>[[1L]]))
  # Oracle: when all rows have NA group, grouped result should equal ungrouped
  ungrouped <- get_X(design_all_na_group, x)
  expect_equal(result$<estimate_col>, ungrouped$<estimate_col>, tolerance = 1e-10)
})

Per-function versions:
```r
# get_freqs()
expect_true(is.finite(result$prop[[1L]]))
expect_equal(result$prop, ungrouped$prop, tolerance = 1e-10)
# get_means()
expect_true(is.finite(result$mean[[1L]]))
expect_equal(result$mean, ungrouped$mean, tolerance = 1e-10)
# get_totals()
expect_true(is.finite(result$total[[1L]]))
expect_equal(result$total, ungrouped$total, tolerance = 1e-10)
# get_corr()
expect_true(is.finite(result$correlation[[1L]]))
expect_equal(result$correlation, ungrouped$correlation, tolerance = 1e-10)
# get_quantiles()
expect_true(is.finite(result$quantile[[1L]]))
expect_equal(result$quantile, ungrouped$quantile, tolerance = 1e-10)
# get_ratios()
expect_true(is.finite(result$ratio[[1L]]))
expect_equal(result$ratio, ungrouped$ratio, tolerance = 1e-10)
```
```

**7a. `label_values = TRUE`: regular NA group row remains `NA` in factor output**
```r
test_that("get_X() regular NA group row is NA (not a factor level) when label_values = TRUE", {
  # design_with_labels has group var with haven-style value labels but some
  # regular NA values (no associated value label)
  result <- get_X(design_with_labels, x, group = grp,
                  na.rm = FALSE, label_values = TRUE)
  na_row <- result[is.na(result$grp), ]
  expect_true(nrow(na_row) > 0L)
  # grp should be a factor, and the NA row's grp value is NA (not "NA")
  expect_true(is.factor(result$grp))
  expect_true(is.na(na_row$grp[[1L]]))
})
```

**7b. `label_values = TRUE`: haven-labeled NA group rows are converted to factor levels**
```r
test_that("get_X() haven-labeled NA group rows become factor levels when label_values = TRUE", {
  # design_with_labeled_nas has a group var where some NAs are haven tagged NAs
  # with value labels (e.g., tagged NA with label "Refused")
  result <- get_X(design_with_labeled_nas, x, group = grp,
                  na.rm = FALSE, label_values = TRUE)
  # The "Refused" labeled NA should appear as a factor level, not as NA
  expect_true(is.factor(result$grp))
  expect_true("Refused" %in% levels(result$grp))
  # The "Refused" row should not be NA
  refused_row <- result[result$grp == "Refused" & !is.na(result$grp), ]
  expect_true(nrow(refused_row) > 0L)
})
```

**8. `group_by()` path: NA group rows appear when groups set via `group_by()`**
```r
test_that("get_X() includes NA group row when group set via group_by() and na.rm = FALSE", {
  skip_if_not_installed("surveytidy")
  design_grouped <- surveytidy::group_by(make_na_group_design(), grp)
  result <- get_X(design_grouped, x, na.rm = FALSE)
  expect_true(anyNA(result$grp))
})
```

**8b. `group_by()` path: NA group rows excluded by default (`na.rm = TRUE`)**
```r
test_that("get_X() excludes NA group rows by default when group set via group_by()", {
  skip_if_not_installed("surveytidy")
  design_grouped <- surveytidy::group_by(make_na_group_design(), grp)
  result <- get_X(design_grouped, x)   # na.rm = TRUE is the default
  expect_false(anyNA(result$grp))
})
```

**8c. `na.rm = NA` is rejected with a typed error**

```r
test_that("get_X() rejects na.rm = NA with surveycore_error_na_rm_not_logical", {
  expect_error(
    get_X(make_na_group_design(), x, group = grp, na.rm = NA),
    class = "surveycore_error_na_rm_not_logical"
  )
  expect_snapshot(
    error = TRUE,
    get_X(make_na_group_design(), x, group = grp, na.rm = NA)
  )
})
```

**9. Domain estimation respects `na.rm = FALSE` for NA group rows**

Domain estimation in surveycore is applied via `surveytidy::filter()` before
calling the analysis function. This test verifies that the NA group row
reflects domain-eligible rows only (via `active_mask <- domain_mask & group_match`).

```r
test_that("get_X() NA group row reflects domain-eligible rows only (na.rm = FALSE)", {
  skip_if_not_installed("surveytidy")
  # filter() marks domain membership — keeps all rows, restricts analysis
  design_domain <- surveytidy::filter(make_na_group_design(), y1 > 0)
  result <- get_X(design_domain, x, group = grp, na.rm = FALSE)
  na_row_domain <- get_na_group_rows(result, "grp")
  if (nrow(na_row_domain) > 0L) {
    expect_true(is.finite(na_row_domain$<estimate_col>[[1L]]))
    # Oracle: NA group row should match estimate from domain-eligible NA-grp rows
    df_domain_na  <- df[is.na(df$grp) & df$y1 > 0, ]
    oracle_design <- as_survey(df_domain_na, ids = psu, weights = wt,
                                strata = strata, fpc = fpc, nest = TRUE)
    expected      <- get_X(oracle_design, x)
    expect_equal(na_row_domain$<estimate_col>, expected$<estimate_col>,
                 tolerance = 1e-10)
  }
})
```

**10. (`get_freqs()` only) Focal-variable NA × group-variable NA combination**

When `na.rm = FALSE` and both the focal variable and a group variable have NA
values, the output should contain both (a) focal-variable NA rows within each
non-NA group, and (b) a dedicated NA-group row that itself contains focal-variable
NA frequency rows.

```r
test_that("get_freqs() includes both focal-NA row and NA-group row when na.rm = FALSE", {
  df <- make_survey_data(n = 200L, seed = 42L)
  set.seed(100L)
  df$focal  <- sample(c(0L, 1L, NA_integer_), 200L, replace = TRUE)
  df$grp_na <- sample(c("A", "B", NA_character_), 200L, replace = TRUE)
  design_both_na <- as_survey(df, ids = psu, weights = wt, strata = strata,
                               fpc = fpc, nest = TRUE)
  result <- get_freqs(design_both_na, focal, group = grp_na, na.rm = FALSE)
  # NA-group row exists
  expect_true(any(is.na(result$grp_na)))
  # Within NA-group rows, a focal-variable NA row exists
  na_group_rows <- get_na_group_rows(result, "grp_na")
  expect_true(any(is.na(na_group_rows$focal)))
})
```

### Shared test helper (add to `tests/testthat/helper-test-data.R`)

Add this helper for extracting NA-group rows. Used in Test Blocks 3, 4, 6, 9,
10, and all oracle tests — prevents 48+ identical inline extractions:

```r
# Extract rows where the named group column is NA.
# Used in NA-group-row test blocks and oracle tests.
get_na_group_rows <- function(result, group_col) {
  result[is.na(result[[group_col]]), ]
}
```

Unit tests for this helper:
```r
test_that("get_na_group_rows() returns rows where group_col is NA", { ... })
test_that("get_na_group_rows() returns empty tibble when no NA group rows exist", { ... })
```

### Helper unit tests (added to `test-analysis-helpers.R` or inline)

Test `.build_group_combos()` and `.match_group_combo()` directly:

```r
test_that(".build_group_combos() excludes NA rows when na.rm = TRUE", { ... })
test_that(".build_group_combos() includes NA rows when na.rm = FALSE", { ... })
test_that(".build_group_combos() sorts NA combos last", { ... })
test_that(".build_group_combos() returns empty data.frame when input has 0 rows", { ... })
test_that(".match_group_combo() matches NA values via is.na()", { ... })
test_that(".match_group_combo() does not match non-NA values when combo value is NA", { ... })
test_that(".match_group_combo() matches non-NA values correctly", { ... })
```

### Numerical accuracy

NA group rows use the same variance estimation path as non-NA rows. Correctness
is validated by matching the NA-group-row estimate against a filtered design
(all rows outside the domain excluded). This oracle test is **required for each
of the 5 design classes** (`survey_taylor`, `survey_replicate`, `survey_twophase`,
`survey_srs`, `survey_calibrated`) to catch per-class variance path bugs.

Build the oracle design by pre-filtering the data frame — do NOT use
`subset(design, is.na(grp))`, which emits a `surveycore_warning_subset`
on every call and produces noisy CI output.

```r
test_that("get_X() NA group row estimate matches filtered design [taylor]", {
  df        <- make_survey_data(n = 100L, n_psu = 10L, n_strata = 2L, seed = 42L)
  set.seed(43L)
  df$grp    <- sample(c("A", "B", NA_character_), 100L, replace = TRUE)
  design_oracle <- as_survey(df, ids = psu, weights = wt, strata = strata,
                              fpc = fpc, nest = TRUE)
  # Oracle: construct from pre-filtered data (avoids surveycore_warning_subset)
  na_df     <- df[is.na(df$grp), ]
  na_design <- as_survey(na_df, ids = psu, weights = wt, strata = strata,
                          fpc = fpc, nest = TRUE)
  expected  <- get_X(na_design, x)
  result    <- get_X(design_oracle, x, group = grp, na.rm = FALSE)
  na_row    <- get_na_group_rows(result, "grp")
  # Per-function estimate column (see table above):
  #   get_freqs(): prop    get_means(): mean    get_totals(): total
  #   get_corr(): correlation    get_quantiles(): quantile    get_ratios(): ratio
  expect_equal(na_row$<estimate_col>, expected$<estimate_col>, tolerance = 1e-10)
  expect_equal(na_row$se,             expected$se,             tolerance = 1e-8)
  # n column: unweighted count must be positive and match oracle
  expect_equal(na_row$n, expected$n)
})
# Repeat for design_replicate, design_srs, design_calibrated using the same
# pre-filter pattern. For design_twophase, use the two-step construction below.
```

**Twophase oracle construction** — `as_survey_twophase()` requires a two-step
construction. Build the full and oracle twophase designs as follows:

```r
# Full twophase design
df_p <- make_survey_data(n = 100L, ..., design = "twophase", seed = 42L)
set.seed(43L)
df_p$grp <- sample(c("A", "B", NA_character_), 100L, replace = TRUE)
phase1   <- as_survey(df_p, ids = psu, weights = wt, strata = strata,
                      fpc = fpc, nest = TRUE)
design_twophase <- as_survey_twophase(phase1, subset = phase2_flag,
                                      method = "approx")

# Oracle: pre-filter data frame, then two-step construction
na_df_p            <- df_p[is.na(df_p$grp), ]
na_phase1          <- as_survey(na_df_p, ids = psu, weights = wt,
                                strata = strata, fpc = fpc, nest = TRUE)
na_design_twophase <- as_survey_twophase(na_phase1, subset = phase2_flag,
                                         method = "approx")
expected <- get_X(na_design_twophase, x)
```

Note: `phase2_flag` is the subset indicator column produced by
`make_survey_data(design = "twophase")`. Verify the exact column name against
the helper output before coding oracle tests.

Per-function `expect_equal` lines:
```r
# get_freqs()
expect_equal(na_row$prop, expected$prop, tolerance = 1e-10)
expect_equal(na_row$se,   expected$se,   tolerance = 1e-8)
expect_equal(na_row$n,    expected$n)
# get_means()
expect_equal(na_row$mean, expected$mean, tolerance = 1e-10)
expect_equal(na_row$se,   expected$se,   tolerance = 1e-8)
expect_equal(na_row$n,    expected$n)
# get_totals()
expect_equal(na_row$total, expected$total, tolerance = 1e-10)
expect_equal(na_row$se,    expected$se,    tolerance = 1e-8)
expect_equal(na_row$n,     expected$n)
# get_corr()
expect_equal(na_row$correlation, expected$correlation, tolerance = 1e-10)
expect_equal(na_row$se,          expected$se,          tolerance = 1e-8)
expect_equal(na_row$n,           expected$n)
# get_quantiles()
expect_equal(na_row$quantile, expected$quantile, tolerance = 1e-10)
expect_equal(na_row$se,       expected$se,       tolerance = 1e-8)
expect_equal(na_row$n,        expected$n)
# get_ratios()
expect_equal(na_row$ratio, expected$ratio, tolerance = 1e-10)
expect_equal(na_row$se,    expected$se,    tolerance = 1e-8)
expect_equal(na_row$n,     expected$n)
```

### Multi-group NA oracle (all 5 design classes per function)

These oracle tests validate `.match_group_combo()` for the two-column NA matching
path, which the single-group oracle does not exercise. Required for all 5 design
classes (same rationale as single-group oracle — catches per-class variance
path bugs).

```r
test_that("get_X() multi-group NA row matches filtered design [taylor]", {
  df       <- make_survey_data(n = 100L, n_psu = 10L, n_strata = 2L, seed = 42L)
  set.seed(43L)
  df$grp   <- sample(c("A", "B", NA_character_), 100L, replace = TRUE)
  df$grp2  <- sample(c("X", "Y"), 100L, replace = TRUE)
  design_multi <- as_survey(df, ids = psu, weights = wt, strata = strata,
                             fpc = fpc, nest = TRUE)
  result <- get_X(design_multi, x, group = c(grp, grp2), na.rm = FALSE)
  # Extract the (NA, "X") combo row
  na_x_rows <- result[is.na(result$grp) & result$grp2 == "X", ]
  # Oracle: pre-filtered data frame for that combo
  oracle_df     <- df[is.na(df$grp) & df$grp2 == "X", ]
  oracle_design <- as_survey(oracle_df, ids = psu, weights = wt,
                              strata = strata, fpc = fpc, nest = TRUE)
  expected      <- get_X(oracle_design, x)
  expect_equal(na_x_rows$<estimate_col>, expected$<estimate_col>, tolerance = 1e-10)
  expect_equal(na_x_rows$se,             expected$se,             tolerance = 1e-8)
})
# Repeat for design_replicate, design_srs, design_calibrated using the same
# pre-filter pattern. For design_twophase, use the two-step construction shown
# in the single-group oracle section above.
```

---

## VII. Quality Gates

All must be satisfied before the PR is opened:

- [ ] `devtools::check()` passes with 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::test()` passes with 0 failures
- [ ] `covr::package_coverage()` ≥ 95% (target: ≥ 98%)
- [ ] All 6 analysis functions use `.build_group_combos()` — no Pattern A or
      Pattern B code remains
- [ ] All 6 analysis functions use `.match_group_combo()` — no inline
      `!is.na(gv_col) & (gv_col == cv)` remains
- [ ] No `== 1L` check on `uniq_lvls` remains in any analysis source file —
      all widened to `< 2L` (`grep "uniq_lvls == 1L" R/analysis-*.R` returns 0)
- [ ] `@param na.rm` updated in all 6 function files
- [ ] `devtools::document()` run; `NAMESPACE` and `man/` files committed
- [ ] All required test block types (§VI blocks 1–10) present for each function
      (Block 10 is `get_freqs()` only)
- [ ] Single-group oracle test run for all 5 design classes per function
      (`survey_calibrated` included); SE comparison included at tolerance `1e-8`
- [ ] Multi-group oracle test run for all 5 design classes per function
- [ ] `make_na_group_design()`, `make_all_na_group_design()`, and
      `get_na_group_rows()` added to `helper-test-data.R`
- [ ] No `subset(design, ...)` calls in oracle tests — all use pre-filtered
      data frame construction

---

## VIII. Integration

### surveytidy

No changes to surveytidy. The `group_by()` verb sets `design@groups`, which
`analysis-helpers.R:.resolve_groups()` already merges with the `group=`
argument. Groups set via `group_by()` obey the same `na.rm` contract as
groups set via `group=` directly — no separate handling needed.

### survey (reference package)

The `survey` package's `svyby()` function excludes NAs in grouping variables by
default and provides no direct equivalent to `na.rm = FALSE` for group vars.
The new behavior is a surveycore extension beyond `survey`'s API.
