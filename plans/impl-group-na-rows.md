# Implementation Plan: NA Group Rows (`group-na-rows`)

**Version:** 1.0
**Date:** 2026-03-02
**Spec:** `plans/spec-group-na-rows.md`
**Decisions log:** `plans/decisions-group-na-rows.md`
**Feature branch base:** `develop`

---

## Overview

This plan implements the `na.rm` extension for group variables across all six
analysis functions. When `na.rm = FALSE`, rows where a grouping variable is `NA`
are collected into their own output row instead of being silently dropped. The
implementation introduces two shared helpers (`.build_group_combos()` and
`.match_group_combo()`) that replace two divergent existing patterns (Pattern A
and Pattern B) across six source files, plus all required tests.

All behavioral contracts are in `plans/spec-group-na-rows.md`. This plan focuses
on build order, file locations, and implementation-level gotchas.

---

## PR Map

PRs 2–5 must branch from `develop` **only after PR 1 is merged to `develop`**.
The shared helpers (`.build_group_combos()`, `.match_group_combo()`,
`get_na_group_rows()`) live in PR 1; PRs 2–5 will fail to compile without them.

- [x] PR 1: `fix/group-na-rows-helpers` — Add shared helpers and NA-group test fixtures
- [x] PR 2: `fix/group-na-rows-freqs` — Extend `get_freqs()` to include NA group rows
- [ ] PR 3: `fix/group-na-rows-means-totals` — Extend `get_means()` and `get_totals()`
- [ ] PR 4: `fix/group-na-rows-corr-quantiles` — Extend `get_corr()` and `get_quantiles()`
- [ ] PR 5: `fix/group-na-rows-ratios` — Extend `get_ratios()`

---

## PR 1: Shared helpers and test fixtures

**Branch:** `fix/group-na-rows-helpers`
**Depends on:** none (branch directly from `develop`)
**Note:** PRs 2–5 must wait for this PR to merge before branching.

### Files (TDD order — tests first)

- `tests/testthat/helper-test-data.R` — add `make_na_group_design()` and
  `make_all_na_group_design()`
- `tests/testthat/test-analysis-helpers.R` — add unit tests for
  `.build_group_combos()`, `.match_group_combo()`, and the tagged-NA path in
  `.apply_group_labels()`
- `R/analysis-helpers.R` — add `.build_group_combos()` and `.match_group_combo()`;
  update `.apply_group_labels()` to convert tagged NAs to factor levels

### Acceptance criteria

- [ ] All helper unit tests confirmed failing (red) before helpers were added
- [ ] `.build_group_combos(na.rm = TRUE)` excludes NA rows
- [ ] `.build_group_combos(na.rm = FALSE)` includes NA rows
- [ ] `.build_group_combos()` sorts NA combos after non-NA combos (leftmost var
  is primary key, `na.last = TRUE`)
- [ ] `.build_group_combos()` returns empty data.frame immediately when
  `nrow(combos) == 0L`
- [ ] `.match_group_combo()` matches NA values via `is.na()`, not `==`
- [ ] `.match_group_combo()` does not match non-NA values via `NA == value`
- [ ] `.apply_group_labels()` converts tagged NAs to their label string and
  includes them as factor levels (not `NA`) when a matching label exists
- [ ] `.apply_group_labels()` tagged-NA path unit-tested directly (synthetic
  vector with `na_tag` attribute — no full design object required)
- [ ] `.apply_group_labels()` leaves plain (non-tagged) NAs as `NA` in the factor
  output when no matching label exists (7a behavior unchanged)
- [ ] `make_na_group_design()` returns a `survey_taylor` object with `grp`
  (~20% NA) and `grp2` (no NA) columns
- [ ] `make_all_na_group_design()` returns a `survey_taylor` object with all-NA
  `grp`
- [ ] `get_na_group_rows(result, group_col)` helper added to `helper-test-data.R`
  and unit-tested (returns NA rows; returns empty tibble when none present)
- [ ] `.validate_shared_args()` updated to reject `na.rm = NA` (and any non-logical
  value) with `surveycore_error_na_rm_not_logical`; class added to
  `plans/error-messages.md`
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and `man/` in sync

### Implementation notes

**`.build_group_combos(domain_data, na.rm)`** — add after the last existing
helper in `R/analysis-helpers.R`. Exact implementation per spec §II:

```r
# Sync note: spec §II is authoritative — keep this block in sync with the spec
# if either changes. Do not edit one without updating the other.
.build_group_combos <- function(domain_data, na.rm) {
  if (na.rm) {
    domain_data <- domain_data[stats::complete.cases(domain_data), , drop = FALSE]
  }
  combos <- unique(domain_data)
  if (nrow(combos) == 0L) return(combos)
  # Sort: non-NA combos first, NA combos last.
  # Leftmost group variable is the primary sort key.
  # unname() prevents column names from colliding with order()'s named
  # formals (decreasing, method, na.last) if a group var shares a name.
  # rownames reset AFTER subsetting — before would leave non-sequential names.
  sort_vecs         <- unname(lapply(names(combos), function(v) combos[[v]]))
  ord               <- do.call(order, c(sort_vecs, list(na.last = TRUE)))
  combos            <- combos[ord, , drop = FALSE]
  rownames(combos)  <- NULL
  combos
}
```

**`.match_group_combo(data_cols, combo_row)`** — add immediately after
`.build_group_combos()`. Exact implementation per spec §II:

```r
# Sync note: spec §II is authoritative — keep this block in sync with the spec
# if either changes. Do not edit one without updating the other.
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

**`data_cols` must be full-design-length** (not domain-filtered). Build it as
`as.list(design@data[group_vars])`. Apply `domain_mask` after:
`active_mask <- domain_mask & .match_group_combo(data_cols, combo_row)`.
This matches the existing pattern in all 6 functions.

**`make_na_group_design()` fixture** — add to the bottom of
`tests/testthat/helper-test-data.R`, after `make_all_designs()`:

```r
# Sync note: spec §VI is authoritative for these fixture definitions.
# set.seed(seed + 1L) isolates the grp/grp2 RNG from make_survey_data()'s
# internal RNG consumption, so fixture values are stable even if
# make_survey_data() changes internally.
make_na_group_design <- function(n = 200, na_frac = 0.2, seed = 42) {
  df     <- make_survey_data(n = n, seed = seed)
  set.seed(seed + 1L)
  na_idx <- sample(seq_len(n), size = floor(n * na_frac))
  df$grp <- sample(c("A", "B", "C"), n, replace = TRUE)
  df$grp[na_idx] <- NA_character_
  df$grp2 <- sample(c("X", "Y"), n, replace = TRUE)
  as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc, nest = TRUE)
}

make_all_na_group_design <- function(n = 100, seed = 1) {
  df     <- make_survey_data(n = n, seed = seed)
  df$grp <- NA_character_
  as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc, nest = TRUE)
}

# Extract rows where the named group column is NA.
# DRY helper used in Test Blocks 3, 4, 6, 9, 10, and all oracle tests.
get_na_group_rows <- function(result, group_col) {
  result[is.na(result[[group_col]]), ]
}
```

Note: `make_survey_data()` uses `wt` (not `weight`) as the weight column name,
per existing helper-test-data.R usage in `make_all_designs()`.

**Required unit tests for `.build_group_combos()`:**
```r
test_that(".build_group_combos() excludes NA rows when na.rm = TRUE", ...)
test_that(".build_group_combos() includes NA rows when na.rm = FALSE", ...)
test_that(".build_group_combos() sorts NA combos after non-NA combos", ...)
test_that(".build_group_combos() returns empty data.frame when input has 0 rows", ...)
```

**Required unit tests for `.match_group_combo()`:**
```r
test_that(".match_group_combo() matches NA values via is.na()", ...)
test_that(".match_group_combo() does not match non-NA values when combo value is NA", ...)
test_that(".match_group_combo() matches non-NA values correctly", ...)
```

**`.apply_group_labels()` tagged-NA update** — update the existing helper in
`R/analysis-helpers.R`. Tagged NAs are ordinary doubles with an `na_tag`
attribute set by `haven::tagged_na()` (e.g., `attr(x, "na_tag") == "r"`).
No `haven` import is needed at runtime — detect via `attr()` directly.

The update should handle the lookup loop over each value: if a value is `NA`,
check `attr(val, "na_tag")`; if the tag is non-NULL, look up the label by
comparing `attr(label_val, "na_tag")` across the entries in `val_labels` that
are themselves tagged NAs. If a matching label is found, return the label
string; otherwise leave the value as `NA`.

**`.validate_shared_args()` update** — add immediately before the existing
`na.rm` handling in `.validate_shared_args()` in `R/analysis-helpers.R`.
Exact implementation per spec §V:

```r
# Sync note: spec §V is authoritative — keep in sync if validation logic changes.
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

Before adding this, add `surveycore_error_na_rm_not_logical` to
`plans/error-messages.md` with the message template above.

**Required unit tests for `.apply_group_labels()` tagged-NA path:**
```r
test_that(".apply_group_labels() converts tagged NAs to factor levels when label exists", {
  skip_if_not_installed("haven")
  # construct a col with tagged NA values and a labels attr
  # verify the result is a factor with the tagged-NA label as a level
  ...
})
test_that(".apply_group_labels() leaves plain NAs as NA when no label exists", {
  # col with plain NA (no na_tag); verify NA remains in factor output
  ...
})
```

---

## PR 2: `get_freqs()`

**Branch:** `fix/group-na-rows-freqs`
**Depends on:** PR 1 — branch from `develop` only after PR 1 is merged to `develop`

### Files (TDD order)

- `tests/testthat/test-analysis-freqs.R` — add Test Blocks 1–8 (per spec §VI)
  plus oracle tests for all 5 design classes
- `R/analysis-freqs.R` — replace Pattern A, replace inline loop, widen
  warning condition to `< 2L`, update `@param na.rm`
- `changelog/phase-1/fix-group-na-rows.md` — create changelog entry covering
  the full fix set (PRs 2–5 will note "changelog created in PR 1")

### Acceptance criteria

- [ ] All new tests confirmed failing (red) before source code changes
- [ ] Test Block 1: default `na.rm = TRUE` excludes NA group rows
- [ ] Test Block 2: `na.rm = FALSE` includes NA group row
- [ ] Test Block 3: NA group row is the last row
- [ ] Test Block 4: NA group row has finite `prop` estimate
- [ ] Test Block 5a: multi-group — NA in first group var produces NA-group rows
- [ ] Test Block 5b: multi-group — NA in second group var produces NA-group rows (inline fixture; `grp2` has NAs, `grp` does not)
- [ ] Test Block 6: all-NA group var produces 1 output row; `surveycore_warning_single_level` fired (condition widened from `== 1L` to `< 2L`)
- [ ] Test Block 7a: regular NA group row remains `NA` (not a factor level) when
  `label_values = TRUE`
- [ ] Test Block 7b: haven-labeled NA group rows become factor levels when
  `label_values = TRUE` (requires `skip_if_not_installed("haven")`)
- [ ] Test Block 8: NA group rows appear when groups set via `group_by()`
  (requires `skip_if_not_installed("surveytidy")`)
- [ ] Test Block 8c: `na.rm = NA` rejected with `surveycore_error_na_rm_not_logical`
  (dual pattern: `expect_error(class=)` + `expect_snapshot(error=TRUE)`)
- [ ] Oracle test for all 5 design classes: `prop` value matches filtered design
  (tolerance `1e-10`)
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and `man/` in sync
- [ ] Changelog entry created at `changelog/phase-1/fix-group-na-rows.md`

### Implementation notes

**Pattern A replacement** — in `analysis-freqs.R` the current combo-building
block (lines ~199–214) looks like:

```r
if (length(group_vars) > 0L) {
  domain_data   <- design@data[domain_mask, group_vars, drop = FALSE]
  complete_idx  <- stats::complete.cases(domain_data)
  group_combos  <- unique(domain_data[complete_idx, , drop = FALSE])
  ord <- do.call(order, lapply(group_vars, function(gv) group_combos[[gv]]))
  group_combos <- group_combos[ord, , drop = FALSE]
  rownames(group_combos) <- NULL
  n_combos <- nrow(group_combos)
} else {
  group_combos <- data.frame()
  n_combos     <- 1L
}
```

Replace the `if` branch body with:

```r
if (length(group_vars) > 0L) {
  domain_data  <- design@data[domain_mask, group_vars, drop = FALSE]
  group_combos <- .build_group_combos(domain_data, na.rm)
  n_combos     <- nrow(group_combos)
} else {
  group_combos <- data.frame()
  n_combos     <- 1L
}
```

**Inline loop replacement** — in the main cell loop, the current matching code
is:

```r
combo_row   <- group_combos[ci, , drop = FALSE]
group_match <- rep(TRUE, nrow(design@data))
for (gv in group_vars) {
  gv_col <- design@data[[gv]]
  cv     <- combo_row[[gv]]
  group_match <- group_match & !is.na(gv_col) & (gv_col == cv)
}
active_mask <- domain_mask & group_match
```

Replace with:

```r
combo_row   <- group_combos[ci, , drop = FALSE]
data_cols   <- as.list(design@data[group_vars])
group_match <- .match_group_combo(data_cols, combo_row)
active_mask <- domain_mask & group_match
```

**`@param na.rm` replacement** — `get_freqs()` uses the **extended** version
from spec §IV (different from the other 5 functions). Replace the existing
`@param na.rm` roxygen line(s) in `analysis-freqs.R` with:

```
#' @param na.rm Logical. If `TRUE` (default), `NA` values are excluded from
#'   analysis: observations where the focal variable is `NA` are dropped from
#'   frequency counts, and observations where any group variable is `NA` are
#'   excluded from the output. If `FALSE`, `NA` values in the focal variable
#'   appear as a dedicated frequency row in the output (not merely counted),
#'   and observations where a group variable is `NA` are collected into their
#'   own group row (appearing after all non-`NA` group rows).
```

**Test Block 7a fixture** — Requires a design where the group variable has value
labels but some regular (non-haven-tagged) NA values. Construct inline:

```r
df <- make_survey_data(n = 200, seed = 42)
df$grp <- sample(c(1L, 2L, NA_integer_), 200, replace = TRUE)
attr(df$grp, "labels") <- c("GroupA" = 1L, "GroupB" = 2L)
design_with_labels <- as_survey(df, ids = psu, weights = wt, strata = strata,
                                fpc = fpc, nest = TRUE)
```

**Test Block 7b fixture** — Requires a design where the group variable has
haven-style tagged NAs with associated value labels. Construct inline:

```r
# A tagged NA for "Refused" — requires haven::tagged_na() or hand-crafting
# the tagged NA value. Skip this test block if haven is not installed:
skip_if_not_installed("haven")
df <- make_survey_data(n = 200, seed = 42)
df$grp <- sample(c(1L, 2L), 200, replace = TRUE)
df$grp[sample(200, 40)] <- haven::tagged_na("r")  # "r" for Refused
attr(df$grp, "labels") <- c("GroupA" = 1L, "GroupB" = 2L,
                             "Refused" = haven::tagged_na("r"))
design_with_labeled_nas <- as_survey(df, ids = psu, weights = wt,
                                      strata = strata, fpc = fpc, nest = TRUE)
```

**Oracle test setup for all 5 design classes** — Use the `make_all_designs()`
helper pattern from `helper-test-data.R` but add a `grp` column with NAs to the
raw data frame before constructing each design. Mirror the setup in
`make_all_designs()` for constructor arguments.

**Critical:** Do NOT use `subset(design_oracle, is.na(grp))` to build the oracle
design — `subset()` emits a `surveycore_warning_subset` on every call, making CI
output noisy and potentially causing failures with `options(warn = 2)`. Instead,
pre-filter the data frame before constructing the oracle design.

Example for taylor class:

```r
df     <- make_survey_data(n = 100L, n_psu = 10L, n_strata = 2L, seed = 42L)
set.seed(43L)
df$grp <- sample(c("A", "B", NA_character_), 100L, replace = TRUE)
design_oracle <- as_survey(df, ids = psu, weights = wt, strata = strata,
                            fpc = fpc, nest = TRUE)
# Oracle: pre-filter data frame — do NOT use subset(design_oracle, is.na(grp))
na_df     <- df[is.na(df$grp), ]
na_design <- as_survey(na_df, ids = psu, weights = wt, strata = strata,
                        fpc = fpc, nest = TRUE)
expected  <- get_freqs(na_design, y3)
result    <- get_freqs(design_oracle, y3, group = grp, na.rm = FALSE)
na_row    <- get_na_group_rows(result, "grp")
expect_equal(na_row$prop, expected$prop, tolerance = 1e-10)
expect_equal(na_row$se,   expected$se,   tolerance = 1e-8)
expect_equal(na_row$n,    expected$n)
```

Use `y3` (binary 0/1, 2 levels) as the focal variable — not `y1` (continuous).
`y3` produces 2 oracle rows (one per level), making failures interpretable and
testing the primary `get_freqs()` use case (categorical focal variable).

For the replicate oracle, add `grp` to `df_r` before calling `as_survey_rep()`.
For twophase, add `grp` to `df_p` before `as_survey_twophase()`. For calibrated,
add `grp` to `df_c` before `as_survey_calibrated()`. For srs, add `grp` to
`df_s` before `as_survey_srs()`. Use `set.seed(43L)` before each `sample()` call
for `grp` to isolate RNG from `make_survey_data()`'s internal state.

---

## PR 3: `get_means()` and `get_totals()`

**Branch:** `fix/group-na-rows-means-totals`
**Depends on:** PR 1 — branch from `develop` only after PR 1 is merged to `develop`

### Files (TDD order)

- `tests/testthat/test-analysis-means.R` — add Test Blocks 1–8 plus oracle
  tests for all 5 design classes
- `tests/testthat/test-analysis-totals.R` — add Test Blocks 1–8 plus oracle
  tests for all 5 design classes
- `R/analysis-means.R` — replace `unique(domain_data)` block, replace inline
  loop, widen warning condition to `< 2L`, update `@param na.rm`
- `R/analysis-totals.R` — same changes as `analysis-means.R`

### Acceptance criteria

- [ ] All new tests confirmed failing (red) before source code changes
- [ ] Test Blocks 1–8 pass for `get_means()` (Block 6 uses `surveycore_warning_single_level`; Block 8 requires `skip_if_not_installed("surveytidy")`)
- [ ] Test Block 8c passes for `get_means()` (`na.rm = NA` error; dual pattern)
- [ ] Test Blocks 1–8 pass for `get_totals()` (Block 6 uses `surveycore_warning_single_level`; Block 8 requires `skip_if_not_installed("surveytidy")`)
- [ ] Test Block 8c passes for `get_totals()` (`na.rm = NA` error; dual pattern)
- [ ] Oracle tests for all 5 design classes: `mean` column matches filtered design
  (tolerance `1e-10`) for `get_means()`
- [ ] Oracle tests for all 5 design classes: `total` column matches filtered
  design (tolerance `1e-10`) for `get_totals()`
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and `man/` in sync
- [ ] Changelog already created in PR 1; no additional entry needed

### Implementation notes

**`analysis-means.R` current pattern (lines ~142–156):**

```r
if (length(group_vars) > 0L) {
  domain_data  <- design@data[domain_mask, group_vars, drop = FALSE]
  group_combos <- unique(domain_data)
  ord <- do.call(order, lapply(group_vars, function(gv) group_combos[[gv]]))
  group_combos <- group_combos[ord, , drop = FALSE]
  rownames(group_combos) <- NULL
  n_combos <- nrow(group_combos)
} else {
  group_combos <- data.frame()
  n_combos     <- 1L
}
```

**Important behavioral note:** Unlike `get_freqs()` (which used `complete.cases`
to pre-filter), `get_means()` and `get_totals()` use bare `unique(domain_data)`
today. This means that with `na.rm = TRUE`, the inline loop currently acts as
the sole NA filter — but `group_combos` may already contain NA-valued combination
rows (since no pre-filter). The replacement `.build_group_combos(domain_data, na.rm)`
corrects both cases: with `na.rm = TRUE`, NAs are filtered before `unique()`;
with `na.rm = FALSE`, all combinations (including NA) are included.

Replace the `if` branch body with (same as freqs):

```r
if (length(group_vars) > 0L) {
  domain_data  <- design@data[domain_mask, group_vars, drop = FALSE]
  group_combos <- .build_group_combos(domain_data, na.rm)
  n_combos     <- nrow(group_combos)
} else {
  group_combos <- data.frame()
  n_combos     <- 1L
}
```

**Inline loop replacement** — same `data_cols` / `.match_group_combo()` swap as
PR 2 (see PR 2 notes).

**`@param na.rm` replacement** — `get_means()` and `get_totals()` use the
**unified** version from spec §IV:

```
#' @param na.rm Logical. If `TRUE` (default), `NA` values are excluded from
#'   analysis: observations where the analysis variable is `NA` are dropped
#'   from calculations, and observations where any group variable is `NA` are
#'   excluded from the output. If `FALSE`, `NA` observations in the analysis
#'   variable are included in calculations, and observations where a group
#'   variable is `NA` are collected into their own group row in the output
#'   (appearing after all non-`NA` group rows).
```

**`analysis-totals.R`** — verify the pattern mirrors `analysis-means.R` exactly
(the grep confirms it does). Apply identical changes.

**Test Blocks 7a/7b** — same fixture construction as PR 2. Explicit call sites:

```r
# Block 7a — get_means()
get_means(design_with_labels, y1, group = grp, na.rm = FALSE, label_values = TRUE)
# Block 7b — get_means() with haven-tagged NA
get_means(design_with_labeled_nas, y1, group = grp, na.rm = FALSE, label_values = TRUE)

# Block 7a — get_totals()
get_totals(design_with_labels, y1, group = grp, na.rm = FALSE, label_values = TRUE)
# Block 7b — get_totals() with haven-tagged NA
get_totals(design_with_labeled_nas, y1, group = grp, na.rm = FALSE, label_values = TRUE)
```

For `get_means()`, the oracle compares `mean` column; for `get_totals()`, the
oracle compares `total` column.

---

## PR 4: `get_corr()` and `get_quantiles()`

**Branch:** `fix/group-na-rows-corr-quantiles`
**Depends on:** PR 1 — branch from `develop` only after PR 1 is merged to `develop`

### Files (TDD order)

- `tests/testthat/test-analysis-corr.R` — add Test Blocks 1–8 plus oracle tests
  for all 5 design classes
- `tests/testthat/test-analysis-quantiles.R` — add Test Blocks 1–8 plus oracle
  tests for all 5 design classes
- `R/analysis-corr.R` — replace Pattern B, replace inline loop, widen
  warning condition to `< 2L`, update `@param na.rm`
- `R/analysis-quantiles.R` — replace Pattern A (`complete.cases`), replace
  inline loop, widen warning condition to `< 2L`, update `@param na.rm`

### Acceptance criteria

- [ ] All new tests confirmed failing (red) before source code changes
- [ ] Test Blocks 1–8 pass for `get_corr()` (Block 6 uses `surveycore_warning_single_level`; Block 8 requires `skip_if_not_installed("surveytidy")`)
- [ ] Test Block 8c passes for `get_corr()` (`na.rm = NA` error; dual pattern)
- [ ] Test Blocks 1–8 pass for `get_quantiles()` (Block 6 uses `surveycore_warning_single_level`; Block 8 requires `skip_if_not_installed("surveytidy")`)
- [ ] Test Block 8c passes for `get_quantiles()` (`na.rm = NA` error; dual pattern)
- [ ] Oracle tests for all 5 design classes: `correlation` matches filtered
  design (tolerance `1e-10`) for `get_corr()`
- [ ] Oracle tests for all 5 design classes: `quantile` matches filtered design
  (tolerance `1e-10`) for `get_quantiles()`
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and `man/` in sync
- [ ] Changelog already created in PR 1; no additional entry needed

### Implementation notes

**`analysis-corr.R` Pattern B (lines ~220–235):**

```r
if (length(group_vars) > 0L) {
  has_na       <- Reduce(`|`, lapply(group_vars,
                   function(gv) is.na(domain_data[[gv]])))
  group_combos <- unique(domain_data[!has_na, , drop = FALSE])
  ord <- do.call(order, lapply(group_vars, function(gv) group_combos[[gv]]))
  group_combos <- group_combos[ord, , drop = FALSE]
  rownames(group_combos) <- NULL
  n_combos <- nrow(group_combos)
} else {
  group_combos <- data.frame()
  n_combos     <- 1L
}
```

Confirm that `domain_data` is constructed earlier in the function as
`design@data[domain_mask, group_vars, drop = FALSE]` (check the lines preceding
line ~224). If not, add that line. Then apply the same replacement:

```r
if (length(group_vars) > 0L) {
  domain_data  <- design@data[domain_mask, group_vars, drop = FALSE]
  group_combos <- .build_group_combos(domain_data, na.rm)
  n_combos     <- nrow(group_combos)
} else {
  group_combos <- data.frame()
  n_combos     <- 1L
}
```

If `domain_data` was already built earlier in the function for Pattern B, remove
the duplication (don't declare it twice).

**`get_corr()` oracle** — `get_corr()` selects focal variables via its first `x`
argument using tidy-select. Pass both variables together:
`get_corr(na_design, c(y1, y2))`. Do NOT use positional notation
`get_corr(na_design, y1, y2)` — the third positional argument is `group`, not a
second focal variable. Compare `correlation` column.

**`get_corr()` Test Blocks 2–6** — use `y1` and `y2` as the two focal variables.

**Test Blocks 7a/7b** — same fixture construction as PR 2. Explicit call sites:

```r
# Block 7a — get_corr()
get_corr(design_with_labels, c(y1, y2), group = grp, na.rm = FALSE,
         label_values = TRUE)
# Block 7b — get_corr() with haven-tagged NA
get_corr(design_with_labeled_nas, c(y1, y2), group = grp, na.rm = FALSE,
         label_values = TRUE)

# Block 7a — get_quantiles()
get_quantiles(design_with_labels, y1, probs = 0.5, group = grp,
              na.rm = FALSE, label_values = TRUE)
# Block 7b — get_quantiles() with haven-tagged NA
get_quantiles(design_with_labeled_nas, y1, probs = 0.5, group = grp,
              na.rm = FALSE, label_values = TRUE)
```

**`analysis-quantiles.R`** — currently uses Pattern A with `complete.cases`
(same as freqs). Apply the identical replacement as PR 2. Also uses the unified
`@param na.rm` text (not the freqs-specific version).

**`get_quantiles()` oracle** — `get_quantiles()` requires a `probs` argument.
For oracle tests, pre-filter the data frame (do NOT use `subset(design, ...)`):

```r
na_df     <- df[is.na(df$grp), ]
na_design <- as_survey(na_df, ids = psu, weights = wt, strata = strata,
                        fpc = fpc, nest = TRUE)
expected  <- get_quantiles(na_design, y1, probs = 0.5)
na_row    <- get_na_group_rows(result, "grp")
expect_equal(na_row$quantile, expected$quantile, tolerance = 1e-10)
expect_equal(na_row$se,       expected$se,       tolerance = 1e-8)
expect_equal(na_row$n,        expected$n)
```

Compare `quantile` column.

---

## PR 5: `get_ratios()`

**Branch:** `fix/group-na-rows-ratios`
**Depends on:** PR 1 — branch from `develop` only after PR 1 is merged to `develop`

### Files (TDD order)

- `tests/testthat/test-analysis-ratios.R` — add Test Blocks 1–8 plus oracle
  tests for all 5 design classes
- `R/analysis-ratios.R` — replace Pattern A (`complete.cases`), replace inline
  loop, widen warning condition to `< 2L`, update `@param na.rm`

### Acceptance criteria

- [ ] All new tests confirmed failing (red) before source code changes
- [ ] Test Blocks 1–8 pass for `get_ratios()` (Block 6 uses `surveycore_warning_single_level`; Block 8 requires `skip_if_not_installed("surveytidy")`)
- [ ] Test Block 8c passes for `get_ratios()` (`na.rm = NA` error; dual pattern)
- [ ] Oracle tests for all 5 design classes: `ratio` column matches filtered
  design (tolerance `1e-10`)
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and `man/` in sync
- [ ] Changelog already created in PR 1; no additional entry needed

### Implementation notes

**`analysis-ratios.R` Pattern A (lines ~192–205):**

```r
if (length(group_vars) > 0L) {
  domain_data  <- design@data[domain_mask, group_vars, drop = FALSE]
  complete_idx <- stats::complete.cases(domain_data)
  group_combos <- unique(domain_data[complete_idx, , drop = FALSE])
  ord <- do.call(order, lapply(group_vars, function(gv) group_combos[[gv]]))
  group_combos <- group_combos[ord, , drop = FALSE]
  rownames(group_combos) <- NULL
  n_combos <- nrow(group_combos)
} else {
  group_combos <- data.frame()
  n_combos     <- 1L
}
```

Replace the `if` branch body with the standard helper call (same as PRs 2–4).

**`get_ratios()` signature** — takes `numerator` and `denominator` arguments.
For oracle tests, pre-filter the data frame (do NOT use `subset(design, ...)`):

```r
na_df     <- df[is.na(df$grp), ]
na_design <- as_survey(na_df, ids = psu, weights = wt, strata = strata,
                        fpc = fpc, nest = TRUE)
expected  <- get_ratios(na_design, y1, y2)
na_row    <- get_na_group_rows(result, "grp")
expect_equal(na_row$ratio, expected$ratio, tolerance = 1e-10)
expect_equal(na_row$se,    expected$se,    tolerance = 1e-8)
expect_equal(na_row$n,     expected$n)
```

Compare `ratio` column.

**Test Blocks 7a/7b** — same fixture construction as PR 2. Explicit call sites:

```r
# Block 7a — get_ratios()
get_ratios(design_with_labels, y1, y2, group = grp, na.rm = FALSE,
           label_values = TRUE)
# Block 7b — get_ratios() with haven-tagged NA
get_ratios(design_with_labeled_nas, y1, y2, group = grp, na.rm = FALSE,
           label_values = TRUE)
```

**`.meta` structure** — `get_ratios()` uses `numerator` / `denominator` meta
keys instead of `x`. This does not affect group combo building or matching, but
confirm the test fixtures use two distinct numeric variables (e.g., `y1`, `y2`).

**`@param na.rm` replacement** — uses the unified version (same as `get_means()`,
`get_totals()`; see PR 3 for the text).

---

## Cross-cutting notes

### Test oracle design class setup (all PRs 2–5)

Two oracle suites are required per function:

1. **Single-group oracle** — one design class block per PR; 5 blocks total (one
   per class). Tests variance path correctness for the NA-group row.
2. **Multi-group oracle** — same structure. Tests `.match_group_combo()` for
   the two-column NA matching path not exercised by the single-group oracle.
   Required for all 5 design classes (same rationale as single-group).

For both suites: build each design class inline following the `make_all_designs()`
pattern in `helper-test-data.R`. Add `grp` (and `grp2` for multi-group) with
`set.seed(43L)` before each `sample()` call to isolate RNG from
`make_survey_data()` internals.

**Critical:** Build oracle designs from pre-filtered data frames — do NOT use
`subset(design, ...)`. See PR 2 implementation notes for the correct pattern.

Single-group example for replicate class:

```r
df_r       <- make_survey_data(n = 100L, n_psu = 10L, n_strata = 2L,
                                design = "replicate", type = "brr", seed = 42L)
set.seed(43L)
df_r$grp   <- sample(c("A", "B", NA_character_), 100L, replace = TRUE)
repwt_cols <- grep("^repwt_", names(df_r), value = TRUE)
design_rep <- as_survey_rep(df_r, weights = wt,
                             repweights = tidyselect::all_of(repwt_cols),
                             type = "BRR")
na_df_rep  <- df_r[is.na(df_r$grp), ]
repwt_cols_na <- grep("^repwt_", names(na_df_rep), value = TRUE)
na_design_rep <- as_survey_rep(na_df_rep, weights = wt,
                                repweights = tidyselect::all_of(repwt_cols_na),
                                type = "BRR")
expected   <- get_X(na_design_rep, x)
result     <- get_X(design_rep, x, group = grp, na.rm = FALSE)
na_row     <- get_na_group_rows(result, "grp")
expect_equal(na_row$<estimate_col>, expected$<estimate_col>, tolerance = 1e-10)
expect_equal(na_row$se,             expected$se,             tolerance = 1e-8)
expect_equal(na_row$n,              expected$n)
```

Multi-group example for taylor class (add `grp2` alongside `grp`):

```r
df     <- make_survey_data(n = 100L, n_psu = 10L, n_strata = 2L, seed = 42L)
set.seed(43L)
df$grp  <- sample(c("A", "B", NA_character_), 100L, replace = TRUE)
df$grp2 <- sample(c("X", "Y"), 100L, replace = TRUE)
design_multi <- as_survey(df, ids = psu, weights = wt, strata = strata,
                           fpc = fpc, nest = TRUE)
result <- get_X(design_multi, x, group = c(grp, grp2), na.rm = FALSE)
# Oracle for the (NA, "X") combo
oracle_df     <- df[is.na(df$grp) & df$grp2 == "X", ]
oracle_design <- as_survey(oracle_df, ids = psu, weights = wt,
                            strata = strata, fpc = fpc, nest = TRUE)
expected      <- get_X(oracle_design, x)
na_x_rows     <- result[is.na(result$grp) & result$grp2 == "X", ]
expect_equal(na_x_rows$<estimate_col>, expected$<estimate_col>, tolerance = 1e-10)
expect_equal(na_x_rows$se,             expected$se,             tolerance = 1e-8)
expect_equal(na_x_rows$n,              expected$n)
```

**Twophase oracle construction** — `as_survey_twophase()` requires a two-step
construction that differs from all other design classes. The oracle for the NA
group rows must mirror this two-step pattern.

Full design construction:
```r
df_p <- make_survey_data(n = 100L, n_psu = 10L, n_strata = 2L,
                          design = "twophase", seed = 42L)
set.seed(43L)
df_p$grp     <- sample(c("A", "B", NA_character_), 100L, replace = TRUE)
phase1_design <- as_survey(df_p, ids = psu, weights = wt,
                            strata = strata, fpc = fpc, nest = TRUE)
design_twophase <- as_survey_twophase(phase1_design,
                                       subset = phase2_flag,
                                       method = "approx")
```

Oracle design construction (pre-filter data frame, then two-step):
```r
na_df_p        <- df_p[is.na(df_p$grp), ]
na_phase1      <- as_survey(na_df_p, ids = psu, weights = wt,
                             strata = strata, fpc = fpc, nest = TRUE)
na_design_twophase <- as_survey_twophase(na_phase1,
                                          subset = phase2_flag,
                                          method = "approx")
expected <- get_X(na_design_twophase, x)
```

Note: `phase2_flag` is the column name that `make_survey_data(design = "twophase")`
generates to indicate phase 2 membership. Verify the exact column name against
the helper output before writing oracle tests.

### Single-level group warning in Test Block 6

Test Block 6 calls `get_X()` on a design where the group variable is entirely
`NA`. The warning class is `surveycore_warning_single_level` (the existing
class used by all 6 functions — no new class needed). The warning fires because
each function PR widens the existing condition from `length(uniq_lvls) == 1L`
to `length(uniq_lvls) < 2L`, so the all-NA case (length 0) also triggers it.
Use the pattern from `testing-standards.md §3`:

```r
expect_warning(
  result <- get_X(design_all_na_group, x, group = grp, na.rm = FALSE),
  class = "surveycore_warning_single_level"
)
expect_equal(nrow(result), 1L)
expect_true(is.na(result$grp[[1L]]))
```

### `devtools::document()` required after every PR

Each PR that modifies roxygen2 content in an `R/*.R` file must run
`devtools::document()` before opening the PR. The `@param na.rm` updates in
PRs 2–5 all trigger this requirement.

### Quality gates (spec §VII)

Before the final PR is merged, verify all spec §VII quality gates:
- All 6 functions use `.build_group_combos()` — no Pattern A, B, or C code remains
- All 6 functions use `.match_group_combo()` — no inline `!is.na(gv_col) & (gv_col == cv)` remains
- No `== 1L` check on `uniq_lvls` remains — all widened to `< 2L`
  (`grep "uniq_lvls == 1L" R/analysis-*.R` returns 0)
- `@param na.rm` updated in all 6 function files
- All required test block types present per function (Blocks 1–10; Block 10 is
  `get_freqs()` only)
- Single-group oracle run for all 5 design classes per function; SE comparison
  included at tolerance `1e-8`
- Multi-group oracle run for all 5 design classes per function
- `make_na_group_design()`, `make_all_na_group_design()`, and
  `get_na_group_rows()` added to `helper-test-data.R`
- No `subset(design, ...)` calls in oracle tests
