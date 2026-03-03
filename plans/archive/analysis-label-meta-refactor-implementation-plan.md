# Implementation Plan: Analysis Label & Meta Restructure

**Status:** Ready for implementation
**Created:** 2026-02-26

---

## Overview

Two related improvements to all six analysis functions:

**Feature 1 — Group label conversion in output columns**
When a grouping variable has haven-style value labels or is a plain R factor,
replace raw codes with label strings in the output tibble and convert the
column to a factor. Column type changes from `<int>` (or original type) to
`<fct>`. Factor levels are ordered by code value for haven-labelled columns,
or match the original `levels()` for plain R factors. Unlabelled columns
are unchanged.

**Feature 2 — Meta restructure (Option C with argument names)**
Replace the current flat `.meta` keys with a nested structure that mirrors
function argument names. Removes `group_names`, `group_labels`, `variable`,
`variable_label`, `question_preface`, `value_labels` as flat top-level keys.
Replaces them with `group` (named list) and `x` / `numerator` / `denominator`
(named list or flat list depending on function).

**Decisions locked:**
- Labels are always stored in `.meta` regardless of `label_values`/`label_vars` args
- `question_preface` is included in group metadata for completeness
- Factor group/x variables: extract `levels()` as `value_labels`
  (format: named integer `c("Male" = 1L, "Female" = 2L)`, matching haven convention)
- `get_corr()` reads `design@groups` for group metadata (set by surveytidy's `group_by()`);
  `group` in `.meta` is `list()` only when no groups are active — not hardcoded empty
- `get_totals()` with no `x`: `x = NULL` in `.meta`
- `x` is always a named list (single-x functions have length-1 list; consistent
  with multi-x functions like `get_freqs()` and `get_corr()`)
- `get_freqs()` FREQS_SINGLE_META_KEYS and FREQS_MULTI_META_KEYS merged into
  one FREQS_META_KEYS constant; mode is inferred from `length(meta$x)`
- `label_values` gates group column value conversion in the output: when
  `label_values = FALSE`, `.apply_group_labels()` is skipped and group columns
  retain raw codes. `.meta` always stores value_labels regardless.
- `label_vars` has no effect on group column names — group columns are always
  named after the raw variable name (e.g. `gender`, not `"Respondent gender"`)
- All non-numeric output columns that represent coded values are `<fct>`, not
  `<chr>`. Specifically:
    - Group columns (when `label_values = TRUE` and labels exist or source is
      a factor): `<fct>` with levels in code order (haven) or original level
      order (factor)
    - `get_freqs()` `value` column (when `label_values = TRUE` and value labels
      exist): `<fct>` with levels ordered by code value (`names(value_labels)`)
    - `get_freqs()` `name` column in multi-var mode (when `label_vars = TRUE`):
      `<fct>` with levels in variable supply order (using label string as level
      when `label_vars = TRUE`, raw variable name otherwise)
    - `get_corr()` `var1`/`var2` columns: `<fct>` with levels in variable
      supply order; when `label_vars = TRUE`, display string is variable label
      (falling back to variable name when no label set)

---

## New `.meta` Structure Reference

### Single-x functions (`get_means`, `get_totals`, `get_quantiles`)

```r
list(
  design_type   = "taylor",          # from .build_meta()
  n_respondents = 1000L,             # from .build_meta()
  conf_level    = 0.95,
  call          = <call>,
  probs         = c(0.25, 0.5, 0.75),  # get_quantiles only; absent for others
  group         = list(
    gender = list(
      variable_label   = "Respondent gender",
      question_preface = NULL,
      value_labels     = c("Male" = 1L, "Female" = 2L)
    )
  ),                                 # list() when no groups
  x             = list(
    income = list(
      variable_label   = "Annual household income",
      question_preface = NULL,
      value_labels     = NULL
    )
  )                                  # NULL for get_totals() when x not supplied
)
```

### Multi-x function (`get_freqs`)

```r
list(
  design_type   = "taylor",
  n_respondents = 1000L,
  conf_level    = 0.95,
  call          = <call>,
  group         = list(
    gender = list(variable_label = "Gender", question_preface = NULL,
                  value_labels = c("Male" = 1L, "Female" = 2L))
  ),
  x             = list(
    q1 = list(variable_label   = "Q1: Satisfaction",
              question_preface = "How satisfied are you?",
              value_labels     = c("Agree" = 1L, "Disagree" = 2L)),
    q2 = list(variable_label   = "Q2: Support",
              question_preface = NULL,
              value_labels     = c("Yes" = 1L, "No" = 2L))
  )
)
```

### Multi-x, no group arg (`get_corr`)

```r
list(
  design_type   = "taylor",
  n_respondents = 1000L,
  conf_level    = 0.95,
  call          = <call>,
  method        = "pearson",
  group         = list(),            # list() when no group_by() active; non-empty
                                     # when design@groups is set via surveytidy
  x             = list(
    income    = list(variable_label = "Income", question_preface = NULL,
                     value_labels = NULL),
    age       = list(variable_label = "Age",    question_preface = NULL,
                     value_labels = NULL)
  )
)
```

### Named-role function (`get_ratios`)

```r
list(
  design_type   = "taylor",
  n_respondents = 1000L,
  conf_level    = 0.95,
  call          = <call>,
  group         = list(
    race = list(variable_label = "Race/ethnicity", question_preface = NULL,
                value_labels = c("White" = 1L, "Black" = 2L))
  ),
  numerator     = list(
    name             = "income",
    variable_label   = "Annual income",
    question_preface = NULL,
    value_labels     = NULL
  ),
  denominator   = list(
    name             = "expenses",
    variable_label   = "Annual expenses",
    question_preface = NULL,
    value_labels     = NULL
  )
)
```

---

## PR Checklist

- [x] PR 1: `feature/analysis-label-meta-helpers` — shared helpers + meta doc update
- [x] PR 2: `feature/analysis-label-meta-apply-all` — apply to all five functions (get_means, get_totals, get_freqs, get_quantiles, get_corr, get_ratios)

PR 2 depends on PR 1.

---

## PR 1: `feature/analysis-label-meta-helpers`

**Files changed:** `R/analysis-helpers.R`, `R/analysis-meta.R`,
`tests/testthat/test-analysis-helpers.R`

### 1a. Add `.extract_var_meta()` to `R/analysis-helpers.R`

Add after the existing meta-key constants block (after line ~55). Used by all
functions to get uniform per-variable metadata.

```r
# Returns a list(variable_label, question_preface, value_labels) for one variable.
# Checks @metadata first; falls back to haven attributes on the column.
# For factor columns with no haven labels, surfaces levels() as value_labels
# in haven format: named integer where names are level strings.
.extract_var_meta <- function(design, var_name) {
  col <- design@data[[var_name]]

  variable_label <- design@metadata@variable_labels[[var_name]] %||%
    attr(col, "label", exact = TRUE)

  question_preface <- design@metadata@question_prefaces[[var_name]]

  value_labels <- design@metadata@value_labels[[var_name]] %||%
    attr(col, "labels", exact = TRUE)

  if (is.null(value_labels) && is.factor(col)) {
    lvls <- levels(col)
    value_labels <- stats::setNames(seq_along(lvls), lvls)
  }

  list(
    variable_label   = variable_label,
    question_preface = question_preface,
    value_labels     = value_labels
  )
}
```

### 1b. Add `.build_group_meta()` to `R/analysis-helpers.R`

Builds the `group` named list for `.meta`. Add immediately after
`.extract_var_meta()`.

```r
# Returns a named list, one entry per group variable, each being the output
# of .extract_var_meta(). Returns list() when group_vars is empty.
.build_group_meta <- function(design, group_vars) {
  if (length(group_vars) == 0L) return(list())
  meta <- lapply(group_vars, function(gv) .extract_var_meta(design, gv))
  stats::setNames(meta, group_vars)
}
```

### 1c. Add `.apply_group_labels()` to `R/analysis-helpers.R`

Converts haven-labelled or factor group columns in a group_combos data frame
to labelled factors. Raw/unlabelled columns are unchanged. Add immediately
after `.build_group_meta()`.

```r
# Converts coded group columns to ordered factors in-place.
# Haven-labelled: produces a factor whose levels are the label strings in
#   code-value order (i.e., the order of names(labels)), so that numeric
#   sort order is preserved as factor level order.
# Factor: re-factors preserving original levels() order exactly.
# Other columns: unchanged.
# When label_values = FALSE, returns group_combos unmodified.
# IMPORTANT: must be called AFTER group_combos is sorted on raw codes;
#   sorting after conversion would use factor level order, not raw numeric.
# Returns the modified group_combos data frame.
.apply_group_labels <- function(group_combos, group_vars, design,
                                label_values = TRUE) {
  if (!label_values) return(group_combos)
  for (gv in group_vars) {
    col     <- group_combos[[gv]]
    src_col <- design@data[[gv]]

    labels <- design@metadata@value_labels[[gv]] %||%
      attr(src_col, "labels", exact = TRUE)

    if (!is.null(labels)) {
      # labels: c("Male" = 1, "Female" = 2) — names=labels, values=codes
      # level order: names(labels) in declaration order = ascending code order
      label_map <- stats::setNames(names(labels), as.character(unname(labels)))
      group_combos[[gv]] <- factor(
        label_map[as.character(col)],
        levels = names(labels)
      )
    } else if (is.factor(src_col)) {
      # Re-factor preserving original level order
      group_combos[[gv]] <- factor(as.character(col), levels = levels(src_col))
    }
    # else: leave unchanged (stays integer/numeric/character as-is)
  }
  group_combos
}
```

### 1d. Update meta-key constants in `R/analysis-helpers.R`

**Add** the new simplified constants alongside the existing ones. Do NOT delete
`FREQS_SINGLE_META_KEYS` or `FREQS_MULTI_META_KEYS` in this PR — `analysis-freqs.R`
still references them and will be updated in PR 3. Deleting them here would
break `devtools::check()` on `develop` between PRs 1 and 3.

```r
FREQS_META_KEYS     <- c("group", "x")      # replaces FREQS_SINGLE + FREQS_MULTI
MEANS_META_KEYS     <- c("group", "x")
TOTALS_META_KEYS    <- c("group", "x")
CORR_META_KEYS      <- c("group", "x", "method")
QUANTILES_META_KEYS <- c("group", "x", "probs")
RATIOS_META_KEYS    <- c("group", "numerator", "denominator")
```

The old `FREQS_SINGLE_META_KEYS` and `FREQS_MULTI_META_KEYS` constants remain
until PR 3. PR 3 will switch `analysis-freqs.R` to use `FREQS_META_KEYS` and
then delete the old constants in the same commit.

### 1e. Update `R/analysis-meta.R` documentation

Update the meta structure docstring (lines 20–37) to describe the new nested
structure. Update the `@examples` section if present to show the new access
pattern.

New documentation should describe:
- `group`: Named list. One entry per group variable; each entry is a list with
  `variable_label` (character or NULL), `question_preface` (character or NULL),
  `value_labels` (named vector or NULL). Empty list when no groups.
- `x`: Named list. One entry per focal variable (length 1 for single-x
  functions; length N for multi-x). Same sub-structure as group entries.
  NULL for `get_totals()` when called without an `x` argument.
- `numerator` / `denominator` (get_ratios only): Flat list with `name`,
  `variable_label`, `question_preface`, `value_labels`.
- `probs` (get_quantiles only): Numeric vector of quantile probabilities.

### 1f. Tests for new helpers

File: `tests/testthat/test-analysis-helpers.R` (new section or new file;
follow project convention)

Write tests for each of the three new helpers:

`.extract_var_meta()`:
- Returns all-NULL list for a plain numeric column with no metadata
- Returns `variable_label` from `@metadata@variable_labels` when set
- Falls back to `attr(col, "label")` when @metadata is NULL
- Returns `question_preface` from `@metadata@question_prefaces`
- Returns `value_labels` from `@metadata@value_labels` when set
- Falls back to `attr(col, "labels")` for haven-labelled column
- Returns `value_labels` as named integer from `levels()` for a factor column
- @metadata takes precedence over haven attrs for all three fields

`.build_group_meta()`:
- Returns `list()` for empty `group_vars`
- Returns named list of length 1 for one group var
- Returns named list of length N for N group vars, names matching var names
- Each entry has the three sub-keys (variable_label, question_preface, value_labels)

`.apply_group_labels()`:
- Leaves unlabelled integer columns unchanged
- Converts haven-labelled integer codes to character label strings
- Converts factor column to character via level names
- Handles group_combos with multiple group columns (only converts labelled ones)
- Returns data frame with converted columns

---

## PR 2: `feature/analysis-label-meta-apply-all`

Apply the new meta structure and group label conversion to all five analysis
functions in a single branch. Each sub-section below covers one function's
changes. All steps follow the same four-step pattern established in the plan.

**Files changed:**
- `R/analysis-means.R`, `tests/testthat/test-analysis-means.R`, `tests/testthat/_snaps/analysis-means.md`
- `R/analysis-totals.R`, `tests/testthat/test-analysis-totals.R`, `tests/testthat/_snaps/analysis-totals.md`
- `R/analysis-freqs.R`, `tests/testthat/test-analysis-freqs.R`, `tests/testthat/_snaps/analysis-freqs.md`
- `R/analysis-quantiles.R`, `tests/testthat/test-analysis-quantiles.R`, `tests/testthat/_snaps/analysis-quantiles.md`
- `R/analysis-corr.R`, `tests/testthat/test-analysis-corr.R`, `tests/testthat/_snaps/analysis-corr.md`
- `R/analysis-ratios.R`, `tests/testthat/test-analysis-ratios.R`, `tests/testthat/_snaps/analysis-ratios.md`
- `R/analysis-helpers.R` (delete `FREQS_SINGLE_META_KEYS` / `FREQS_MULTI_META_KEYS` — previously kept for PR 3, now safe to remove here)

**Prerequisite:** PR 1 merged.

---

### 2a. get_means() + get_totals()

#### get_means() changes (`R/analysis-means.R`)

**Step 1 — Replace group_labels extraction (lines 249–256) with `.build_group_meta()`:**

Remove:
```r
group_labels_list <- lapply(
  group_vars,
  function(gv) design@metadata@variable_labels[[gv]] %||%
    attr(design@data[[gv]], "label", exact = TRUE)
)
if (length(group_vars) > 0L) {
  names(group_labels_list) <- group_vars
}
```

Replace with:
```r
group_meta <- .build_group_meta(design, group_vars)
```

**Step 2 — Replace val_labels extraction (lines 158–161) with `.extract_var_meta()`:**

Remove:
```r
val_labels   <- design@metadata@value_labels[[x_name]] %||%
  attr(design@data[[x_name]], "labels", exact = TRUE)
val_labels_l <- list(val_labels)
names(val_labels_l) <- x_name
```

Also remove the separate `var_label` and `q_preface` extractions wherever they
appear. Replace all three with a single call:

For `get_means()` (x is always required):
```r
x_meta <- .extract_var_meta(design, x_name)
```

For `get_totals()` (x is optional — null-guard required):
```r
x_meta <- if (!is.null(x_name)) .extract_var_meta(design, x_name) else NULL
```

**Step 3 — Apply group labels to group_combos (after group_combos is built, ~line 152):**

Add after the existing group_combos sort block (sorting must happen first, on
raw codes — label conversion after sorting ensures numeric order is preserved):
```r
if (length(group_vars) > 0L) {
  group_combos <- .apply_group_labels(group_combos, group_vars, design,
                                      label_values)
}
```

**Step 4 — Replace meta_args assembly (lines 258–267):**

Remove old flat assembly. Replace with:
```r
x_list      <- stats::setNames(list(x_meta), x_name)
meta_args   <- list(
  conf_level = conf_level,
  call       = match.call(),
  group      = group_meta,
  x          = x_list
)
```

#### get_totals() changes (`R/analysis-totals.R`)

Same four steps as get_means() above, with one difference in Step 4:

```r
x_list <- if (is.null(x_name)) {
  NULL
} else {
  stats::setNames(list(x_meta), x_name)
}
meta_args <- list(
  conf_level = conf_level,
  call       = match.call(),
  group      = group_meta,
  x          = x_list
)
```

### Test changes

For both test files:
- Update any assertion that accesses `meta(result)$variable` → `meta(result)$x[[1]]$variable_label`
  (or use named access: `meta(result)$x$income$variable_label`)
- Update any assertion on `meta(result)$variable_label` → same as above
- Update any assertion on `meta(result)$group_names` → `names(meta(result)$group)`
- Update any assertion on `meta(result)$group_labels$gender` → `meta(result)$group$gender$variable_label`
- Add new assertions: `meta(result)$group$gender$value_labels` for labelled group vars
- Verify group columns now contain character strings when group var has labels
- Regenerate all affected snapshots via `testthat::snapshot_review()`

---

---

### 2b. get_freqs()

#### get_freqs() changes (`R/analysis-freqs.R`)

**Step 1 — Replace the per-variable metadata extraction loop (lines 213–236):**

Remove the three separate `lapply`/loop blocks for `var_labels_list`,
`q_prefaces_list`, `val_labels_list`. Replace with:

```r
x_meta_list <- lapply(var_names, function(vn) .extract_var_meta(design, vn))
names(x_meta_list) <- var_names
```

This single call replaces all three separate lists. Any downstream code that
references `var_labels_list[[vn]]`, `q_prefaces_list[[vn]]`, or
`val_labels_list[[vn]]` must be updated to use
`x_meta_list[[vn]]$variable_label`, `x_meta_list[[vn]]$question_preface`,
`x_meta_list[[vn]]$value_labels`.

Note: `get_freqs()` uses `val_labels_list` to build the level-to-label
mapping for displaying frequency rows. Keep that usage but source it from
`x_meta_list[[vn]]$value_labels` instead.

The `value` column must now be produced as a factor (not character) when
`label_values = TRUE` and value labels exist. Factor levels = `names(value_labels)`
in code order. When `label_values = FALSE` or no value labels exist, the
column retains its current type.

The `name` column in multi-var mode must be produced as a factor. Factor
levels = the display strings for each variable in supply order (variable label
when `label_vars = TRUE`, raw variable name otherwise). This ensures ggplot2
and other tools respect variable order rather than sorting alphabetically.

**Step 2 — Replace group_labels extraction (lines 429–436):**

Same as PR 2: remove block, replace with:
```r
group_meta <- .build_group_meta(design, group_vars)
```

**Step 3 — Apply group labels to group_combos (after group_combos block, ~line 210):**

Add after the group_combos sort block (sort on raw codes must come first):
```r
if (length(group_vars) > 0L) {
  group_combos <- .apply_group_labels(group_combos, group_vars, design,
                                      label_values)
}
```

**Step 4 — Replace dual meta_args assembly (lines 438–462) with single block:**

Remove the single-var and multi-var branches entirely. Replace both with:
```r
meta_args     <- list(
  conf_level = conf_level,
  call       = match.call(),
  group      = group_meta,
  x          = x_meta_list
)
required_keys <- FREQS_META_KEYS
```

The `mode` field is dropped. Callers who need to know single vs. multi can
check `length(meta(result)$x)`.

**Step 5 — Delete old constants (in this same PR):**

Now that `analysis-freqs.R` no longer references them, delete `FREQS_SINGLE_META_KEYS`
and `FREQS_MULTI_META_KEYS` from `R/analysis-helpers.R`. This is safe to do here
because PR 3 updates all references in the same commit.

### Test changes

- Update meta access patterns as described in PR 2
- Add tests: single-x and multi-x both produce correct named list in `meta$x`
- Verify `length(meta$x) == 1` for single-x calls, `length(meta$x) == N` for multi-x
- Regenerate snapshots

---

---

### 2c. get_quantiles()

#### get_quantiles() changes (`R/analysis-quantiles.R`)

Same four steps as get_means() in PR 2, including the `label_values` argument
on the `.apply_group_labels()` call in Step 3. One addition in Step 4 — include
`probs` at the top level of `meta_args`:

```r
x_list    <- stats::setNames(list(x_meta), x_name)
meta_args <- list(
  conf_level = conf_level,
  call       = match.call(),
  probs      = probs,
  group      = group_meta,
  x          = x_list
)
```

### Test changes

- Same meta access pattern updates as PR 2
- Add test: `meta(result)$probs` matches the `probs` argument passed
- Regenerate snapshots

---

---

### 2d. get_corr()

#### get_corr() changes (`R/analysis-corr.R`)

`get_corr()` has no `group=` argument but derives group vars from `@groups`.
It also has no `group_combos` block (correlation doesn't iterate over groups
the same way). The main changes are:

**Step 1 — Replace variable metadata extraction:**

`get_corr()` currently builds `variable_labels`, `question_prefaces`,
`value_labels` lists per-variable (similar to `get_freqs()` multi-var pattern).
Replace with:
```r
x_meta_list <- lapply(x_vars, function(vn) .extract_var_meta(design, vn))
names(x_meta_list) <- x_vars
```

**Step 2 — Replace group metadata extraction:**

`get_corr()` may or may not currently extract group metadata.
Add/replace with:
```r
group_vars <- design@groups   # get_corr has no group= arg; uses @groups only
group_meta <- .build_group_meta(design, group_vars)
```

**Step 3 — Apply group labels to group_combos if applicable:**

If `get_corr()` has a group_combos block, apply `.apply_group_labels()` after
sorting (sort on raw codes first), passing `label_values`:
```r
if (length(group_vars) > 0L) {
  group_combos <- .apply_group_labels(group_combos, group_vars, design,
                                      label_values)
}
```
If `get_corr()` doesn't iterate groups in the same way, add the call where
group values first appear in the result rows.

**Step 4 — Replace meta_args assembly:**

```r
meta_args <- list(
  conf_level = conf_level,
  call       = match.call(),
  method     = method,
  group      = group_meta,
  x          = x_meta_list
)
```

**Step 5 — Convert `var1`/`var2` columns to labelled factors:**

After the result tibble is assembled, replace the `var1` and `var2` columns
with factors. The display string for each variable is its variable label when
`label_vars = TRUE` and a label exists, otherwise the raw variable name.
Factor levels = display strings in variable supply order.

```r
# Build the display name for each x variable
x_display <- vapply(x_vars, function(vn) {
  if (label_vars) x_meta_list[[vn]]$variable_label %||% vn else vn
}, character(1L))
# x_display: named character vector, names = raw var names, values = display strings

result$var1 <- factor(x_display[result$var1], levels = unique(x_display))
result$var2 <- factor(x_display[result$var2], levels = unique(x_display))
```

### Test changes

- Add test: `meta(result)$group` is always present; is `list()` when no
  `group_by()` has been applied to the design; is non-empty when
  `design@groups` is set via `surveytidy::group_by()`
- Add test: `var1`/`var2` are `<fct>` columns with levels in supply order
- Add test: `var1`/`var2` show variable labels when `label_vars = TRUE`
- Add test: `var1`/`var2` show raw variable names when `label_vars = FALSE`
- Update meta access patterns
- Regenerate snapshots

---

---

### 2e. get_ratios()

#### get_ratios() changes (`R/analysis-ratios.R`)

`get_ratios()` uses named roles (`numerator`, `denominator`) instead of `x`.

**Step 1 — Replace variable metadata extraction (lines 206–219):**

Remove the manual `num_label`, `denom_label`, `q_prefaces`, `val_labels`
extractions. Replace with:
```r
num_meta   <- .extract_var_meta(design, num_name)
denom_meta <- .extract_var_meta(design, denom_name)
```

**Step 2 — Replace group metadata extraction (lines 365–372):**

Same as all other functions:
```r
group_meta <- .build_group_meta(design, group_vars)
```

**Step 3 — Apply group labels to group_combos (after ~line 203):**

Add after the group_combos sort block (sort on raw codes must come first):
```r
if (length(group_vars) > 0L) {
  group_combos <- .apply_group_labels(group_combos, group_vars, design,
                                      label_values)
}
```

**Step 4 — Replace meta_args assembly (lines 374–385):**

```r
meta_args <- list(
  conf_level  = conf_level,
  call        = match.call(),
  group       = group_meta,
  numerator   = c(list(name = num_name),   num_meta),
  denominator = c(list(name = denom_name), denom_meta)
)
```

This produces the flat-with-`name` structure for each role:
```r
# meta$numerator:
# list(name = "income", variable_label = "...", question_preface = NULL,
#      value_labels = NULL)
```

### Test changes

- Update `meta$numerator` access from old flat keys
  (`meta$numerator` was previously just the column name string) to the new
  list structure (`meta$numerator$name`, `meta$numerator$variable_label`)
- Update `meta$denominator` similarly
- Update group meta access patterns
- Regenerate snapshots

---

## Cross-cutting test notes

**For all PRs 2–6:**

1. Snapshot files in `tests/testthat/_snaps/` will change for any test that
   prints a result or calls `meta()`. Run `testthat::snapshot_review()` after
   implementation; review each diff individually before accepting.

2. Any test that currently does:
   ```r
   expect_equal(meta(result)$group_names, c("gender"))
   ```
   Must become:
   ```r
   expect_equal(names(meta(result)$group), c("gender"))
   ```

3. Any test that currently does:
   ```r
   expect_equal(meta(result)$variable, "income")
   ```
   Must become:
   ```r
   expect_equal(names(meta(result)$x), "income")
   # or
   expect_equal(meta(result)$x$income$variable_label, "Annual income")
   ```

4. Add new test in each function's test file:
   - Group column is `<fct>` when group var has haven labels and
     `label_values = TRUE`; factor levels match `names(value_labels)` in
     code order
   - Group column is `<fct>` when group var is a plain R factor and
     `label_values = TRUE`; factor levels match `levels(src_col)` exactly
   - Group column retains raw codes (original type, not factor) when
     `label_values = FALSE`
   - Group column is unchanged (type and values) when group var has no labels
     and is not a factor
   - `meta$group$gender$value_labels` matches the haven labels on the column
     regardless of `label_values` (`.meta` always stores labels)

5. `label_values = FALSE` and `label_vars = FALSE` still produce the same
   `.meta` structure — labels always stored regardless of those args.
   Add a regression test for this per function.

6. `label_vars` has no effect on group column names — group column names are
   always the raw variable name. Add a test asserting that the column is named
   `"gender"` (not `"Respondent gender"`) regardless of `label_vars`.

7. For `get_freqs()` specifically:
   - `value` column is `<fct>` with correct levels when `label_values = TRUE`
     and value labels exist
   - `value` column level order matches code order, not alphabetical
   - `name` column (multi-var) is `<fct>` with levels in variable supply order
