---
Version: 0.4
Date: 2026-05-07
Status: Approved
---

# Spec: Variable Direction Attributes

## Document Purpose

This spec defines two new item-level metadata attributes for survey variables
(`higher_is` and `reverse_coded`), the setters and extractors for each, and
targeted extensions to `get_diffs()` that use `higher_is` to classify results
as favorable or backlash. It is the authoritative source of truth for three
sequential PRs.

---

## I. Scope

### What this spec delivers

| PR | Deliverable | Description |
|----|-------------|-------------|
| 1 | `higher_is` property on `survey_metadata` | New list property storing direction per variable |
| 1 | `set_higher_is()` | Set direction attribute for one or more variables |
| 1 | `extract_higher_is()` | Retrieve direction attribute for one or more variables |
| 1 | `.extract_var_meta()` update | Include `higher_is` so it flows into all analysis `.meta` |
| 2 | `reverse_coded` property on `survey_metadata` | New list property storing reverse-coding flag per variable |
| 2 | `set_reverse_coded()` | Set reverse-coded flag for one or more variables |
| 2 | `extract_reverse_coded()` | Retrieve reverse-coded flag for one or more variables |
| 3 | `get_diffs()` extensions | `alpha`, `show_favorability` arguments; `favorable`/`backlash` columns; `.meta` enrichment |

### What this spec does NOT deliver

- `compute_scale()`, row-means, or row-sums functions — `reverse_coded` is
  infrastructure only; there is no consumer yet
- Changes to any `get_*()` function other than `get_diffs()`
- Automatic scale scoring or reversal

### Design/class support matrix

PRs 1 and 2 (setters/extractors): `survey_taylor`, `survey_replicate`,
`survey_twophase`, plain `data.frame`.

PR 3 (`get_diffs()` extensions): all design types supported by the current
`get_diffs()` implementation.

---

## II. Architecture

### File changes

```
R/
  core-classes.R          # Add higher_is and reverse_coded properties to survey_metadata
  core-metadata.R         # Add set_higher_is(), extract_higher_is(),
                          #     set_reverse_coded(), extract_reverse_coded()
  analysis-helpers.R      # Update .extract_var_meta() to include higher_is
  analysis-diffs.R        # Add alpha, show_favorability arguments; favorable/backlash logic

tests/testthat/
  test-metadata-system.R  # PR 1 and PR 2 tests (existing file)
  test-analysis-diffs.R   # PR 3 tests (existing file)

plans/
  error-messages.md       # New error/warning classes for all three PRs
```

### Variable name resolution patterns

All four functions resolve variable names from either tidy-select `...` or
`variable = character`. Follow these existing patterns — do not write new
resolution logic:

| Function | Pattern to follow |
|----------|-------------------|
| `set_higher_is()` | `.parse_setter_input()` with `content_type = "scalar"` (same as `set_var_label()`) |
| `set_reverse_coded()` | Inline `set_sata()` pattern: manual ambiguous-input check, then `tidyselect::eval_select` for `...` or direct `variable` vector |
| `extract_higher_is()` | Inline `extract_var_label()` pattern: `tidyselect::eval_select(rlang::expr(c(...)), ...)` for `...`; `.get_data_cols(x)` when `...` is empty |
| `extract_reverse_coded()` | Same as `extract_higher_is()` |

---

### Key shared helper

`.extract_var_meta(design, var_name)` in `R/analysis-helpers.R` — updated in
PR 1 to include `higher_is`. After PR 1, its return list will be:

```r
list(
  variable_label  = character(1) or NULL,
  question_preface = character(1) or NULL,
  value_labels    = named vector or NULL,
  sata            = logical(1),
  higher_is       = "better" | "worse" | NULL
)
```

This update is free — every analysis function that calls `.extract_var_meta()`
will automatically carry `higher_is` in its `.meta` without further changes.

---

## III. PR 1 — `higher_is` attribute

### `survey_metadata` property

Add to `survey_metadata` in `R/core-classes.R`:

```r
higher_is = S7::new_property(
  S7::class_list,
  default = quote(list())
)
```

Each entry maps a variable name (character key) to `"better"` or `"worse"`.
Absent keys mean the attribute is unset for that variable.

---

### `set_higher_is()`

**Signature:**
```r
set_higher_is(x, ..., variable = NULL, direction = NULL)
```

Follows the `set_var_label()` pattern. `direction` is the scalar content
argument (parallel to `label` in `set_var_label()`).

**Argument table:**

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | survey design or `data.frame` | required | Object to modify |
| `...` | named pairs | — | Variable-direction pairs, e.g. `anxiety = "worse"` |
| `variable` | `character` | `NULL` | Variable name(s); use with `direction` |
| `direction` | `character` or `NULL` | `NULL` | `"better"`, `"worse"`, or `NULL` to unset |

**Calling conventions (three supported, matching `set_var_label()`):**

Convention 1 — named `...` (recommended):
```r
set_higher_is(x, anxiety = "worse", agreement = "better")
```

Convention 2 — single named character vector in `...`:
```r
set_higher_is(x, c(anxiety = "worse", agreement = "better"))
```
Detection rule (handled by `.parse_setter_input()`): `...` contains exactly one
unnamed element that is a named character vector with no empty names. An unnamed
list or a mixed named/unnamed `...` is not Convention 2 — it errors with
`surveycore_error_setter_mixed_dots`.

Note: `set_reverse_coded()` does **not** support Convention 2 — it follows the
`set_sata()` inline pattern, which only supports Conventions 1 and 3.

Convention 3 — `variable` + `direction`:
```r
set_higher_is(x, variable = "anxiety", direction = "worse")
set_higher_is(x, variable = c("anxiety", "worry"), direction = c("worse", "worse"))
```

**Unsetting (pass `NULL` as direction):**
```r
set_higher_is(x, anxiety = NULL)
set_higher_is(x, variable = "anxiety", direction = NULL)
```

**Output contract:**
- Returns `invisible(x)` — see `surveycore-conventions.md §2` (setter return)
- For survey objects: writes to `x@metadata@higher_is[[var_name]]`
- For data frames: writes to `attr(x[[var_name]], "higher_is")`
- `NULL` direction removes the entry

**Behavior rules:**
1. Variable names not found in `x` are skipped with `surveycore_warning_var_not_found`
2. `direction` must be `"better"`, `"worse"`, or `NULL`; any other value is an error
3. Cannot supply both `...` and `variable` simultaneously
4. At least one variable name must be provided
5. In Convention 3, `direction` must be the same length as `variable`, or `NULL` (applies to all); length mismatch is `surveycore_error_setter_mismatched_lengths` (existing class from `.parse_setter_input()`)

**Error table:**

| Class | Trigger | Message template |
|-------|---------|-----------------|
| `surveycore_error_not_survey_or_df` | `x` is not a survey object or data frame | `"{.arg x} must be a survey design object or data frame."` |
| `surveycore_error_direction_invalid` | `direction` is not `"better"`, `"worse"`, or `NULL` | `"{.arg direction} must be {.val \"better\"}, {.val \"worse\"}, or {.code NULL}. Got {.val {direction}}."` |
| `surveycore_error_higher_is_ambiguous_input` | Both `...` and `variable` supplied | `"Provide variable names via {.arg ...} or {.arg variable}, not both."` |
| `surveycore_error_higher_is_no_vars` | No variable names provided | `"{.fn set_higher_is} requires at least one variable name."` |
| `surveycore_error_setter_mismatched_lengths` | `direction` and `variable` lengths differ (Convention 3) | (existing class; message from `.parse_setter_input()`) |
| `surveycore_error_setter_mixed_dots` | `...` is an unnamed list or mixed named/unnamed (invalid Convention 2 input) | (existing class; message from `.parse_setter_input()`) |
| `surveycore_warning_var_not_found` | Variable name not in `x` | `"Variable {.field {var_name}} not found in {.arg x} and was skipped."` (existing class) |

---

### `extract_higher_is()`

**Signature:**
```r
extract_higher_is(x, ..., variable = NULL)
```

**Argument table:**

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | survey design or `data.frame` | required | Object to query |
| `...` | tidy-select | — | Variable names (bare); omit to return all variables |
| `variable` | `character` | `NULL` | Variable name(s) as character; alternative to `...` |

**Output contract:**
- Returns a named `character` vector
- Names are variable names; values are `"better"`, `"worse"`, or `NA_character_`
  (unset variables return `NA_character_`, not `NULL`)
- If no variables are specified (`...` empty, `variable = NULL`), returns all
  variables in `x` (including those with `NA_character_`)
- If no variables match, returns a zero-length named `character(0)`
- For survey objects: reads from `x@metadata@higher_is`
- For data frames: reads from `attr(x[[var]], "higher_is")`

**Examples:**
```r
d <- set_higher_is(d, anxiety = "worse", agreement = "better")

extract_higher_is(d, anxiety)
#>   anxiety
#> "worse"

extract_higher_is(d, c(anxiety, agreement))
#>    anxiety  agreement
#>    "worse"  "better"

extract_higher_is(d)  # all variables; unset → NA_character_
#>    anxiety  agreement     income
#>    "worse"  "better"         NA
```

**Behavior rules:**
1. Variables with no `higher_is` set return `NA_character_` (not `NULL`)
2. Cannot supply both `...` and `variable`
3. Returns visible (not `invisible`)

**Error table:**

| Class | Trigger | Message template |
|-------|---------|-----------------|
| `surveycore_error_not_survey_or_df` | `x` is not a survey object or data frame | `"{.arg x} must be a survey design object or data frame."` |
| `surveycore_error_higher_is_ambiguous_input` | Both `...` and `variable` supplied | `"Provide variable names via {.arg ...} or {.arg variable}, not both."` (same class as setter) |
| `surveycore_warning_var_not_found` | Named variable not in `x` | `"Variable {.field {var_name}} not found in {.arg x} and was skipped."` (existing class) |

---

## IV. PR 2 — `reverse_coded` attribute

### `survey_metadata` property

Add to `survey_metadata` in `R/core-classes.R`:

```r
reverse_coded = S7::new_property(
  S7::class_list,
  default = quote(list())
)
```

Each entry maps a variable name to `TRUE`. Absent keys mean the variable is
not reverse-coded. There is no stored `FALSE` — absence equals `FALSE`.

---

### `set_reverse_coded()`

`reverse_coded` is boolean — follows the `set_sata()` pattern. Variable names
go in `...` or `variable`; the boolean value is a separate argument.

**Signature:**
```r
set_reverse_coded(x, ..., variable = NULL, reverse_coded = TRUE)
```

**Argument table:**

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | survey design or `data.frame` | required | Object to modify |
| `...` | tidy-select | — | Variable names (bare) to flag |
| `variable` | `character` | `NULL` | Variable name(s) as character; alternative to `...` |
| `reverse_coded` | `logical(1)` | `TRUE` | `TRUE` to flag; `FALSE` to unset |

**Calling conventions (matching `set_sata()`):**
```r
# Flag variables
set_reverse_coded(x, anxiety, worry)

# Unset
set_reverse_coded(x, anxiety, reverse_coded = FALSE)

# Via variable argument
set_reverse_coded(x, variable = c("anxiety", "worry"))
```

**Output contract:**
- Returns `invisible(x)`
- When `reverse_coded = TRUE`: `x@metadata@reverse_coded[[var_name]] <- TRUE`
- When `reverse_coded = FALSE`: removes the entry (sets to `NULL`)
- For data frames: `attr(x[[var_name]], "reverse_coded") <- TRUE` or `NULL`

**Behavior rules:**
1. Variable names not found in `x` are skipped with `surveycore_warning_var_not_found`
2. `reverse_coded` must be `TRUE` or `FALSE`; `NA` is an error
3. Cannot supply both `...` and `variable`
4. At least one variable name must be provided

**Error table:**

| Class | Trigger | Message template |
|-------|---------|-----------------|
| `surveycore_error_not_survey_or_df` | `x` is not a survey object or data frame | `"{.arg x} must be a survey design object or data frame."` |
| `surveycore_error_reverse_coded_not_logical` | `reverse_coded` is not `TRUE` or `FALSE` | `"{.arg reverse_coded} must be {.code TRUE} or {.code FALSE}."` |
| `surveycore_error_reverse_coded_ambiguous_input` | Both `...` and `variable` supplied | `"Provide variable names via {.arg ...} or {.arg variable}, not both."` |
| `surveycore_error_reverse_coded_no_vars` | No variable names provided | `"{.fn set_reverse_coded} requires at least one variable name."` |
| `surveycore_warning_var_not_found` | Variable name not in `x` | `"Variable {.field {var_name}} not found in {.arg x} and was skipped."` (existing class) |

---

### `extract_reverse_coded()`

**Signature:**
```r
extract_reverse_coded(x, ..., variable = NULL)
```

**Argument table:**

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | survey design or `data.frame` | required | Object to query |
| `...` | tidy-select | — | Variable names (bare); omit to return all variables |
| `variable` | `character` | `NULL` | Variable name(s) as character; alternative to `...` |

**Output contract:**
- Returns a named `logical` vector
- Names are variable names; values are `TRUE` or `FALSE`
- Variables with no `reverse_coded` flag return `FALSE` (boolean semantics;
  contrast with `extract_higher_is()` which returns `NA_character_` for unset)
- If no variables are specified, returns all variables in `x`
- Returns visible

**Examples:**
```r
d <- set_reverse_coded(d, anxiety, worry)

extract_reverse_coded(d, anxiety)
#>  anxiety
#>     TRUE

extract_reverse_coded(d)  # all variables; unset → FALSE
#>    anxiety     worry    income
#>       TRUE      TRUE     FALSE
```

**Behavior rules:**
1. Variables with no flag return `FALSE`, not `NA`
2. Cannot supply both `...` and `variable`

**Error table:**

| Class | Trigger | Message template |
|-------|---------|-----------------|
| `surveycore_error_not_survey_or_df` | `x` is not a survey object or data frame | `"{.arg x} must be a survey design object or data frame."` |
| `surveycore_error_reverse_coded_ambiguous_input` | Both `...` and `variable` supplied | `"Provide variable names via {.arg ...} or {.arg variable}, not both."` (same class as setter) |
| `surveycore_warning_var_not_found` | Named variable not in `x` | `"Variable {.field {var_name}} not found in {.arg x} and was skipped."` (existing class) |

---

## V. PR 3 — `get_diffs()` extensions

PR 3 depends on PR 1 being merged. It must not be opened until `higher_is` is
available on `survey_metadata` and in `.extract_var_meta()`.

### New arguments

Two new optional scalar arguments, placed after `conf_level` and before
`min_cell_n` to group them with other inference-control parameters:

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `alpha` | `numeric(1)` | `0.05` | Significance threshold for `favorable`/`backlash` classification; must be in (0, 1) exclusive |
| `show_favorability` | `logical(1)` | `FALSE` | If `TRUE`, add `favorable` and `backlash` columns to output |

### Favorability logic

`higher_is` is read from the design for the `x` variable (via `.meta` populated
by `.extract_var_meta()`). The p-value column used is `p_value` (surveycore
name style) or `p.value` (broom name style) — whichever is present after
`name_style` is applied.

| `higher_is` | `estimate` sign | `p < alpha`? | `favorable` | `backlash` |
|-------------|-----------------|--------------|-------------|------------|
| `"better"` | positive | yes | `TRUE` | `FALSE` |
| `"better"` | negative | yes | `FALSE` | `TRUE` |
| `"worse"` | negative | yes | `TRUE` | `FALSE` |
| `"worse"` | positive | yes | `FALSE` | `TRUE` |
| any | any | no (p ≥ alpha) | `FALSE` | `FALSE` |
| `NULL` (unset) | any | any | `FALSE` | `FALSE` |

Significance comparison is **strict**: `p < alpha`, not `p <= alpha`.

### Output changes

**New columns (when `show_favorability = TRUE`):**

| Column | Type | Values | Description |
|--------|------|--------|-------------|
| `favorable` | `logical` | `TRUE`/`FALSE` | Significant movement in the good direction |
| `backlash` | `logical` | `TRUE`/`FALSE` | Significant movement in the bad direction |

Columns are appended after the last existing column. Column-level `label`
attributes follow the same pattern as other columns:
- `attr(result$favorable, "label") <- "Favorable"`
- `attr(result$backlash, "label") <- "Backlash"`

`favorable` and `backlash` are surveycore-native columns with no broom
equivalent. Their names are invariant across `name_style` — they are always
`favorable` and `backlash` regardless of whether `name_style = "surveycore"`
or `name_style = "broom"` is used.

**`.meta` enrichment (always, regardless of `show_favorability`):**

PR 1's `.extract_var_meta()` update means `x_meta` in `get_diffs()` already
includes `higher_is`. No additional `.meta` wiring is needed in PR 3 — the
value is accessible at `attr(result, ".meta")$x[[x_name]]$higher_is`.

**Console output example (with `show_favorability = TRUE`, `name_style = "surveycore"`):**

```
# A <survey_diffs> [4 × 9]
  treatment  estimate    se  ci_low ci_high p_value stars favorable backlash
  <chr>         <dbl> <dbl>   <dbl>   <dbl>   <dbl> <chr> <lgl>     <lgl>
1 Message A     0.300 0.100   0.104   0.496   0.003  **    FALSE     TRUE
2 Message B    -0.200 0.100  -0.396  -0.004   0.048  *     TRUE      FALSE
3 Message C     0.100 0.100  -0.096   0.296   0.340        FALSE     FALSE
4 Message D    -0.100 0.100  -0.296   0.004   0.021  *     TRUE      FALSE
```

*(`x = anxiety`, `higher_is = "worse"` — negative diff on a "worse" variable is favorable)*

**Behavior rules:**
1. `alpha` must be a single finite numeric in (0, 1) exclusive; `NA`, `Inf`,
   `0`, `1`, or non-numeric values are an error
2. `show_favorability = FALSE` (default): no `favorable`/`backlash` columns; `higher_is`
   is still present in `.meta` via the PR 1 `.extract_var_meta()` update
3. `show_favorability = TRUE` with `higher_is` unset on the `x` variable: both columns
   all `FALSE`; no warning (the user set `show_favorability = TRUE` intentionally)
4. `show_favorability = TRUE` does not affect `pval_adj` application — classification
   uses the adjusted p-value if `pval_adj` is set

**Error table (new errors only):**

| Class | Trigger | Message template |
|-------|---------|-----------------|
| `surveycore_error_alpha_invalid` | `alpha` is not a single numeric in (0, 1) | `"{.arg alpha} must be a single numeric value strictly between 0 and 1. Got {.val {alpha}}."` |

---

## VI. Testing

See `testing-standards.md` and `testing-surveycore.md` for general
conventions. Only surveycore-specific additions are listed here.

### PR 1 — `set_higher_is()` / `extract_higher_is()`

File: `tests/testthat/test-metadata-system.R`

**Happy paths:**
- `set_higher_is(x, anxiety = "worse")` stores `"worse"` for `anxiety`
- `set_higher_is(x, anxiety = "worse", agreement = "better")` stores both
- Convention 2 (`set_higher_is(x, c(anxiety = "worse", agreement = "better"))`) stores both values correctly
- Convention 3 (`variable = "anxiety", direction = "worse"`) stores correctly
- `set_higher_is(x, anxiety = NULL)` removes the entry
- Works on a plain `data.frame`; attribute stored on the column
- `extract_higher_is(d, anxiety)` returns `c(anxiety = "worse")`
- `extract_higher_is(d, c(anxiety, agreement))` returns both
- `extract_higher_is(d)` returns all variables, `NA_character_` for unset

**Error paths (one block per class):**
- `not_survey_or_df` (setter): `set_higher_is(list(), anxiety = "worse")` errors with snapshot
- `not_survey_or_df` (extractor): `extract_higher_is(list(), anxiety)` errors with snapshot
- `direction_invalid`: `set_higher_is(x, anxiety = "neutral")` errors with snapshot; also `set_higher_is(x, anxiety = NA_character_)` errors with snapshot
- `setter_mixed_dots`: `set_higher_is(x, list(anxiety = "worse"))` (unnamed list in `...`) errors with snapshot
- `higher_is_ambiguous_input` (setter): both `...` and `variable` supplied to `set_higher_is()` errors with snapshot
- `higher_is_ambiguous_input` (extractor): both `...` and `variable` supplied to `extract_higher_is()` errors with snapshot
- `higher_is_no_vars`: no variable supplied errors with snapshot
- `var_not_found`: unknown variable name warns with snapshot

**Edge cases:**
- Overwrite: `set_higher_is(x, anxiety = "worse")` then `set_higher_is(x, anxiety = "better")` — last write wins
- `extract_higher_is()` with no `higher_is` set on any variable — returns all `NA_character_`
- `.extract_var_meta()` includes `higher_is` after PR 1 — test directly that the
  returned list has the `higher_is` key
- `extract_higher_is(d, variable = "nonexistent")` — warns with `var_not_found` and returns named `character(0)`

### PR 2 — `set_reverse_coded()` / `extract_reverse_coded()`

File: `tests/testthat/test-metadata-system.R`

**Happy paths:**
- `set_reverse_coded(x, anxiety)` sets `TRUE` for `anxiety`
- `set_reverse_coded(x, anxiety, reverse_coded = FALSE)` removes the entry
- Works on a plain `data.frame`
- `extract_reverse_coded(d, anxiety)` returns `c(anxiety = TRUE)`
- `extract_reverse_coded(d)` returns all variables; unset → `FALSE`

**Error paths (one block per class):**
- `not_survey_or_df` (setter): `set_reverse_coded(list(), anxiety)` errors with snapshot
- `not_survey_or_df` (extractor): `extract_reverse_coded(list(), anxiety)` errors with snapshot
- `reverse_coded_not_logical`: `set_reverse_coded(x, anxiety, reverse_coded = NA)` errors with snapshot
- `reverse_coded_ambiguous_input` (setter): both `...` and `variable` supplied to `set_reverse_coded()` errors with snapshot
- `reverse_coded_ambiguous_input` (extractor): both `...` and `variable` supplied to `extract_reverse_coded()` errors with snapshot
- `reverse_coded_no_vars`: no variables errors with snapshot
- `var_not_found`: unknown variable warns with snapshot

**Edge cases:**
- Set then unset: `extract_reverse_coded()` returns `FALSE` after unsetting
- `extract_reverse_coded(d, variable = "nonexistent")` — warns with `var_not_found` and returns named `logical(0)`

### PR 3 — `get_diffs()` extensions

File: `tests/testthat/test-analysis-diffs.R`

**Happy paths:**
- `show_favorability = FALSE` (default): no `favorable`/`backlash` columns in result;
  `meta(result)$x[[x_name]]$higher_is` equals `"worse"` (when `higher_is = "worse"` was set on the `x` variable)
- `show_favorability = TRUE` with `higher_is = "worse"` and negative significant diff:
  `favorable = TRUE`, `backlash = FALSE`; `attr(result$favorable, "label")` equals `"Favorable"`;
  `attr(result$backlash, "label")` equals `"Backlash"`; `expect_snapshot(print(result))` verifies column layout
- `show_favorability = TRUE` with `higher_is = "better"` and negative significant diff:
  `favorable = FALSE`, `backlash = TRUE`
- `show_favorability = TRUE` with non-significant result: both `FALSE`
- Custom `alpha = 0.01`: a result with `p = 0.03` is not favorable/backlash

**Error paths:**
- `alpha_invalid`: `get_diffs(..., alpha = 1.5)` errors with snapshot
- `alpha_invalid`: `get_diffs(..., alpha = 0)` errors with snapshot
- `alpha_invalid`: `get_diffs(..., alpha = "0.05")` errors with snapshot
- `alpha_invalid`: `get_diffs(..., alpha = NA)` errors with snapshot
- `alpha_invalid`: `get_diffs(..., alpha = Inf)` errors with snapshot
- `alpha_invalid`: `get_diffs(..., alpha = c(0.05, 0.1))` errors with snapshot

**Edge cases:**
- `show_favorability = TRUE` with no `higher_is` set on `x`: both columns all `FALSE`
- `p_value` exactly equal to `alpha`: not significant — both `FALSE` (strict `<`)
- `pval_adj` set: `favorable`/`backlash` use the adjusted p-value, not raw
- `show_favorability = TRUE` with `name_style = "broom"`: `favorable`/`backlash` columns present; classification uses `p.value` column
- `show_favorability = TRUE` with `group`: `favorable`/`backlash` columns present; rows align correctly across groups

---

## VII. Quality Gates

Before opening each PR:

- [ ] `devtools::document()` run; `NAMESPACE` and `man/` files updated
- [ ] `devtools::check()` passes: 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] All new error classes in this spec added to `plans/error-messages.md`
- [ ] 98%+ line coverage on new code; overall package coverage ≥ 95%
- [ ] Snapshot tests for all new error/warning messages reviewed via
  `testthat::snapshot_review()` before PR is opened
- [ ] PR 3 is not opened until PR 1 is fully merged to `develop`

---

## VIII. Integration

No external package contracts change. `higher_is` and `reverse_coded` are
internal `survey_metadata` properties — downstream packages (surveytidy) do
not read them. The `.meta$x$higher_is` field is a surveycore-internal contract
for future reporting functions.

`reverse_coded` has no consumer in this spec. It is infrastructure only.
`compute_scale()` or equivalent functions are explicitly out of scope.
