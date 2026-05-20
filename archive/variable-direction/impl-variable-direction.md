---
Version: 1.0
Date: 2026-05-07
Spec: plans/spec-variable-direction.md (v0.3)
Status: Draft
---

# Implementation Plan — Variable Direction Attributes

## Overview

This plan delivers three sequential PRs from `plans/spec-variable-direction.md` (v0.3).
PR 1 adds `higher_is` to `survey_metadata` plus its setter/extractor and updates
`.extract_var_meta()`. PR 2 adds `reverse_coded` to `survey_metadata` plus its
setter/extractor (infrastructure only — no consumer in this plan). PR 3 extends
`get_diffs()` with `alpha` and `show_favorability` arguments that produce
`favorable`/`backlash` columns by reading `higher_is` from `.meta`. PR 3 must
not open until PR 1 is fully merged to `develop`.

## PR Map

- [x] PR 1: `feature/higher-is` — `higher_is` property, `set_higher_is()`, `extract_higher_is()`, `.extract_var_meta()` update
- [x] PR 2: `feature/reverse-coded` — `reverse_coded` property, `set_reverse_coded()`, `extract_reverse_coded()`
- [x] PR 3: `feature/diffs-favorability` — `get_diffs()` `alpha` + `show_favorability` args, `favorable`/`backlash` columns

---

## PR 1: `higher_is` attribute

**Branch:** `feature/higher-is`
**Depends on:** none

### Files (TDD order — tests first)

- `plans/error-messages.md` — add PR 1 error/warning classes before any code is written
- `tests/testthat/test-metadata-system.R` — write all PR 1 test blocks (failing)
- `R/core-classes.R` — add `higher_is` property to `survey_metadata`
- `R/core-metadata.R` — implement `set_higher_is()` and `extract_higher_is()`
- `R/analysis-helpers.R` — update `.extract_var_meta()` to include `higher_is`
- `NEWS.md` — add entry for `set_higher_is()` and `extract_higher_is()`

### Step-by-step (TDD)

**Step 1: Add error classes to `plans/error-messages.md`**

Add rows for all PR 1 classes before writing any code. Classes to add:
- `surveycore_error_direction_invalid` — `direction` not `"better"`, `"worse"`, or `NULL`
- `surveycore_error_higher_is_ambiguous_input` — both `...` and `variable` supplied (shared by setter and extractor)
- `surveycore_error_higher_is_no_vars` — no variable names provided to setter
Follow the existing table format. Reference `surveycore_warning_var_not_found` (already exists — reused, not added).

**Step 2: Write failing tests in `tests/testthat/test-metadata-system.R`**

Add a clearly labelled "PR 1 — higher_is" section. Write all blocks in the spec VI §PR1
test plan. Each `test_that()` block should fail at this point (functions don't exist yet).

Happy-path blocks:
- Convention 1: `set_higher_is(d, anxiety = "worse")` stores `"worse"` under `anxiety`
- Convention 1 multi-var: `set_higher_is(d, anxiety = "worse", agreement = "better")` stores both
- Convention 2: `set_higher_is(d, c(anxiety = "worse", agreement = "better"))` stores both
- Convention 3 scalar: `set_higher_is(d, variable = "anxiety", direction = "worse")`
- Convention 3 vector: `set_higher_is(d, variable = c("anxiety", "worry"), direction = c("worse", "worse"))`
- Unset: `set_higher_is(d, anxiety = NULL)` removes the entry
- Data frame: `set_higher_is(df, anxiety = "worse")` stores attr on column
- `extract_higher_is(d, anxiety)` returns `c(anxiety = "worse")`
- `extract_higher_is(d, c(anxiety, agreement))` returns both
- `extract_higher_is(d)` returns all variables; unset → `NA_character_`
- `extract_higher_is(d, variable = "anxiety")` returns `c(anxiety = "worse")`

Error-path blocks (one block each, dual pattern: `expect_error(class=)` + `expect_snapshot(error=TRUE)`):
- `not_survey_or_df` (setter): `set_higher_is(list(), anxiety = "worse")`
- `not_survey_or_df` (extractor): `extract_higher_is(list(), anxiety)`
- `direction_invalid` (Convention 1): `set_higher_is(d, anxiety = "neutral")` — exercises per-pair loop validation
- `direction_invalid` (Convention 3): `set_higher_is(d, variable = "anxiety", direction = "neutral")` — exercises pre-check validation path
- `higher_is_ambiguous_input` (setter): `set_higher_is(d, anxiety = "worse", variable = "anxiety")`
- `higher_is_ambiguous_input` (extractor): `extract_higher_is(d, anxiety, variable = "anxiety")`
- `higher_is_no_vars`: `set_higher_is(d)`
- `var_not_found` (setter, warning): `set_higher_is(d, nonexistent = "worse")` — expect_warning + snapshot
- `var_not_found` (extractor, warning + return shape): `extract_higher_is(d, variable = "nonexistent")` — expect_warning + verify return is `character(0)` with no names

Edge-case blocks:
- Overwrite: set `"worse"` then set `"better"` — verify last write wins
- No `higher_is` set on any variable — `extract_higher_is(d)` returns all `NA_character_`
- `.extract_var_meta()` includes `higher_is` key: call `.extract_var_meta(d, "anxiety")` directly after `set_higher_is(d, anxiety = "worse")` — verify `result$higher_is == "worse"`

**Step 3: Confirm all new test blocks fail (red)**

Run `devtools::test(filter = "metadata-system")`. Every new block must fail. If any pass, the test is wrong.

**Step 4: Add `higher_is` property to `survey_metadata` in `R/core-classes.R`**

After the `sata` property definition, insert:

```r
higher_is = S7::new_property(
  S7::class_list,
  default = quote(list())
),
```

Each entry maps a variable name to `"better"` or `"worse"`. Absent keys mean unset.
Update the `survey_metadata` roxygen `@param` section to document `higher_is`.

**Step 5: Implement `set_higher_is()` in `R/core-metadata.R`**

Pattern: `.parse_setter_input()` with `content_type = "scalar"` — exactly the same
structure as `set_var_label()`. Key specifics:

- `content_arg_name = "direction"`; `fn_name = "set_higher_is"`
- Validate `direction` before calling `.parse_setter_input()`: any direction value not in `c("better", "worse")` and not `NULL` fires `surveycore_error_direction_invalid`. Apply this check per-value in the map returned by `.parse_setter_input()`.
- For survey objects: `x@metadata@higher_is[[v]] <- value` (or `<- NULL` to remove)
- For data frames: `attr(x[[v]], "higher_is") <- value` (or `<- NULL`)
- Returns `invisible(x)`

Note: `.parse_setter_input()` already handles the ambiguous-input and empty-input errors
using `surveycore_error_setter_ambiguous` and `surveycore_error_setter_empty`. The spec
defines `surveycore_error_higher_is_ambiguous_input` and `surveycore_error_higher_is_no_vars`
as distinct classes for this function. **Do not** reuse the generic setter classes here —
pass `class = "surveycore_error_higher_is_ambiguous_input"` etc. directly in the error
calls inside `set_higher_is()` before calling `.parse_setter_input()`, matching the
`set_sata()` pattern (which also checks ambiguity/no-vars before delegating).

Actually, re-reading `.parse_setter_input()` vs. `set_sata()`: `.parse_setter_input()` does
its own ambiguity/empty checks internally. `set_sata()` does its own checks inline.
`set_higher_is()` must use `.parse_setter_input()` (spec §III). To get the right error
classes, the simplest approach: let `.parse_setter_input()` run — it fires
`surveycore_error_setter_ambiguous` / `surveycore_error_setter_empty`. BUT the spec defines
distinct higher_is error classes. Resolution: do the ambiguous/no-vars checks inline in
`set_higher_is()` (before calling `.parse_setter_input()` or instead of it for those paths),
then call `.parse_setter_input()` only for the Convention 1/2/3 content parsing. This matches
the approach used throughout the existing setters where per-function classes are needed.

Concrete structure:
```
set_higher_is <- function(x, ..., variable = NULL, direction = NULL) {
  call <- rlang::caller_env()
  .check_is_survey_or_df(x, call = call)

  dots <- rlang::list2(...)
  dots_used <- length(dots) > 0L
  var_used <- !is.null(variable)

  # ambiguous-input check (fires surveycore_error_higher_is_ambiguous_input)
  if (dots_used && var_used) { ... }

  # no-vars check (fires surveycore_error_higher_is_no_vars)
  if (!dots_used && !var_used) { ... }

  # direction validation (fires surveycore_error_direction_invalid) — only when
  # direction is a scalar and not one of c("better", "worse"); vectors are
  # validated per-element in the loop below
  if (length(direction) == 1L && !is.null(direction) && !direction %in% c("better", "worse")) { ... }

  # Parse using .parse_setter_input() for Convention 1/2/3 routing
  pairs <- .parse_setter_input(
    dots = dots,
    variable = variable,
    content = direction,
    content_arg_name = "direction",
    content_type = "scalar",
    fn_name = "set_higher_is",
    call = call
  )

  # Apply each pair
  all_cols <- .get_data_cols(x)
  for (v in names(pairs)) {
    if (!v %in% all_cols) {
      cli::cli_warn(..., class = "surveycore_warning_var_not_found")
      next
    }
    val <- pairs[[v]]
    if (!is.null(val) && !val %in% c("better", "worse")) {
      cli::cli_abort(..., class = "surveycore_error_direction_invalid")
    }
    if (S7::S7_inherits(x, survey_base)) {
      x@metadata@higher_is[[v]] <- val  # NULL removes the entry
    } else {
      attr(x[[v]], "higher_is") <- val
    }
  }
  invisible(x)
}
```

**Step 6: Implement `extract_higher_is()` in `R/core-metadata.R`**

Pattern: inline `extract_var_label()` approach.

```
extract_higher_is <- function(x, ..., variable = NULL) {
  call <- rlang::caller_env()
  .check_is_survey_or_df(x, call = call)

  dots_used <- ...length() > 0L
  var_used <- !is.null(variable)

  if (dots_used && var_used) {
    cli::cli_abort(..., class = "surveycore_error_higher_is_ambiguous_input")
  }

  all_cols <- .get_data_cols(x)

  if (dots_used) {
    var_names <- names(tidyselect::eval_select(
      rlang::expr(c(...)),
      data = .get_data_for_select(x)
    ))
  } else if (var_used) {
    missing <- setdiff(variable, all_cols)
    if (length(missing) > 0L) {
      cli::cli_warn(..., class = "surveycore_warning_var_not_found")
    }
    var_names <- intersect(variable, all_cols)
  } else {
    var_names <- all_cols
  }

  out <- vapply(var_names, function(v) {
    if (S7::S7_inherits(x, survey_base)) {
      x@metadata@higher_is[[v]] %||% NA_character_
    } else {
      attr(x[[v]], "higher_is", exact = TRUE) %||% NA_character_
    }
  }, character(1L))

  out
}
```

The return value is a named character vector. Unset variables return `NA_character_`.
When `var_names` is length 0 (all specified names were missing), returns `character(0)`
(named, zero-length) — `vapply` over zero-length input produces this automatically.

**Step 7: Update `.extract_var_meta()` in `R/analysis-helpers.R`**

Add `higher_is` to the return list. Reads from `design@metadata@higher_is[[var_name]]`
with `NULL` fallback (when absent, returns `NULL`):

```r
higher_is <- design@metadata@higher_is[[var_name]] %||% NULL

list(
  variable_label  = variable_label,
  question_preface = question_preface,
  value_labels    = value_labels,
  sata            = sata,
  higher_is       = higher_is
)
```

Note: for data frames, `higher_is` will always be `NULL` here since `.extract_var_meta()`
only accepts survey design objects. The `higher_is` attribute on data frame columns is
accessible only through `extract_higher_is()`.

Update the function's roxygen `@return` documentation to include `higher_is`.

**Step 8: Confirm all new test blocks pass (green)**

Run `devtools::test(filter = "metadata-system")`. All new blocks must pass. Also run
`devtools::test(filter = "analysis-diffs")` to verify no regressions in `.extract_var_meta()`.

**Step 9: Run `devtools::document()` and `devtools::check()`**

Confirm 0 errors, 0 warnings, ≤2 pre-approved notes.

### Acceptance criteria

- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] All PR 1 error classes added to `plans/error-messages.md` before code was written
- [ ] 98%+ line coverage on new code; overall package coverage ≥ 95% (verified with `covr::package_coverage()`)
- [ ] Happy paths: all three calling conventions work; data frame path works
- [ ] Error paths: all 9 error-path blocks written (5 unique classes; `not_survey_or_df` and `ambiguous_input` tested separately for setter and extractor; `direction_invalid` tested for both Convention 1 and Convention 3)
- [ ] Edge cases: overwrite, all-NA extract, `.extract_var_meta()` includes `higher_is`
- [ ] No existing test regressions in `test-metadata-system.R` or analysis test files
- [ ] `NEWS.md` entry written under the appropriate version heading
- [ ] Snapshot tests reviewed via `testthat::snapshot_review()` before PR opened

### Notes

- `set_higher_is()` uses `.parse_setter_input()` for Convention 1/2/3 input routing
  but does its own ambiguous/no-vars checks inline with higher_is-specific error classes
  (same structure as `set_sata()`). Do not let `.parse_setter_input()` fire its generic
  `surveycore_error_setter_ambiguous` / `surveycore_error_setter_empty` classes for this function.
- Convention 3 length mismatch (`direction` and `variable` lengths differ and neither is scalar-to-be-recycled) is handled by `.parse_setter_input()` via `surveycore_error_setter_mismatched_lengths` (existing class) — no new class needed.
- `.extract_var_meta()` update is free for all analysis functions: every `get_*()` that calls `.extract_var_meta()` will automatically carry `higher_is` in `.meta` from PR 1 onward.
- The `%||%` operator is defined in `R/utils.R` — no new import needed.

---

## PR 2: `reverse_coded` attribute

**Branch:** `feature/reverse-coded`
**Depends on:** PR 1 merged to `develop` (recommended, though not strictly required — no code dependency between PRs 1 and 2)

### Files (TDD order)

- `plans/error-messages.md` — add PR 2 error/warning classes before any code is written
- `tests/testthat/test-metadata-system.R` — write all PR 2 test blocks (failing)
- `R/core-classes.R` — add `reverse_coded` property to `survey_metadata`
- `R/core-metadata.R` — implement `set_reverse_coded()` and `extract_reverse_coded()`
- `NEWS.md` — add entry for `set_reverse_coded()` and `extract_reverse_coded()`

### Step-by-step (TDD)

**Step 1: Add error classes to `plans/error-messages.md`**

Add rows for PR 2 classes:
- `surveycore_error_reverse_coded_not_logical` — `reverse_coded` is not `TRUE` or `FALSE`
- `surveycore_error_reverse_coded_ambiguous_input` — both `...` and `variable` supplied
- `surveycore_error_reverse_coded_no_vars` — no variable names provided

**Step 2: Write failing tests in `tests/testthat/test-metadata-system.R`**

Add a "PR 2 — reverse_coded" section. All blocks fail at this point.

Happy-path blocks:
- `set_reverse_coded(d, anxiety)` stores `TRUE` for `anxiety`
- `set_reverse_coded(d, anxiety, worry)` stores `TRUE` for both
- `set_reverse_coded(d, anxiety, reverse_coded = FALSE)` removes the entry
- Convention 3 (vector): `set_reverse_coded(d, variable = c("anxiety", "worry"))` — verifies both variables are flagged
- Data frame: `set_reverse_coded(df, anxiety)` stores attr on column
- `extract_reverse_coded(d, anxiety)` returns `c(anxiety = TRUE)`
- `extract_reverse_coded(d)` returns all variables; unset → `FALSE`
- `extract_reverse_coded(d, variable = "anxiety")` returns `c(anxiety = TRUE)`

Error-path blocks (dual pattern):
- `not_survey_or_df` (setter): `set_reverse_coded(list(), anxiety)`
- `not_survey_or_df` (extractor): `extract_reverse_coded(list(), anxiety)`
- `reverse_coded_not_logical`: `set_reverse_coded(d, anxiety, reverse_coded = NA)`
- `reverse_coded_ambiguous_input` (setter): both `...` and `variable`
- `reverse_coded_ambiguous_input` (extractor): both `...` and `variable`
- `reverse_coded_no_vars`: `set_reverse_coded(d)`
- `var_not_found` (setter, warning): unknown variable warns + result skipped
- `var_not_found` (extractor, warning + return shape): `extract_reverse_coded(d, variable = "nonexistent")` warns + returns `logical(0)`

Edge-case blocks:
- Set then unset: `extract_reverse_coded()` returns `FALSE` after `reverse_coded = FALSE`

**Step 3: Confirm all new test blocks fail (red)**

Run `devtools::test(filter = "metadata-system")`. Only new PR 2 blocks should fail.

**Step 4: Add `reverse_coded` property to `survey_metadata` in `R/core-classes.R`**

After the `higher_is` property:

```r
reverse_coded = S7::new_property(
  S7::class_list,
  default = quote(list())
),
```

Each entry maps a variable name to `TRUE`. Absent key = not reverse-coded. No stored `FALSE`.

**Step 5: Implement `set_reverse_coded()` in `R/core-metadata.R`**

Pattern: inline `set_sata()` pattern — manual ambiguity/no-vars checks, then
`tidyselect::eval_select` for `...` or direct `variable` vector.

```
set_reverse_coded <- function(x, ..., variable = NULL, reverse_coded = TRUE) {
  call <- rlang::caller_env()
  .check_is_survey_or_df(x, call = call)

  if (!is.logical(reverse_coded) || length(reverse_coded) != 1L || is.na(reverse_coded)) {
    cli::cli_abort(
      c("x" = "{.arg reverse_coded} must be {.code TRUE} or {.code FALSE}."),
      class = "surveycore_error_reverse_coded_not_logical",
      call = call
    )
  }

  dots_used <- ...length() > 0L
  var_used <- !is.null(variable)

  if (dots_used && var_used) { ... class = "surveycore_error_reverse_coded_ambiguous_input" }
  if (!dots_used && (!var_used || length(variable) == 0L)) { ... class = "surveycore_error_reverse_coded_no_vars" }

  all_cols <- .get_data_cols(x)

  if (dots_used) {
    var_names <- names(tidyselect::eval_select(rlang::expr(c(...)), data = .get_data_for_select(x)))
  } else {
    missing <- setdiff(variable, all_cols)
    if (length(missing) > 0L) cli::cli_warn(..., class = "surveycore_warning_var_not_found")
    var_names <- intersect(variable, all_cols)
  }

  for (v in var_names) {
    if (S7::S7_inherits(x, survey_base)) {
      x@metadata@reverse_coded[[v]] <- if (isTRUE(reverse_coded)) TRUE else NULL
    } else {
      attr(x[[v]], "reverse_coded") <- if (isTRUE(reverse_coded)) TRUE else NULL
    }
  }
  invisible(x)
}
```

**Step 6: Implement `extract_reverse_coded()` in `R/core-metadata.R`**

Same pattern as `extract_higher_is()`. Key differences:
- Returns named logical vector (not character)
- Unset variables return `FALSE` (not `NA_character_`)
- Uses `x@metadata@reverse_coded[[v]]` (or `attr(x[[v]], "reverse_coded", exact = TRUE)`)
- Absent entry → `isTRUE(NULL)` → `FALSE`

```r
out <- vapply(var_names, function(v) {
  if (S7::S7_inherits(x, survey_base)) {
    isTRUE(x@metadata@reverse_coded[[v]])
  } else {
    isTRUE(attr(x[[v]], "reverse_coded", exact = TRUE))
  }
}, logical(1L))
```

**Step 7: Confirm all PR 2 tests pass (green)**

Run `devtools::test(filter = "metadata-system")`. All PR 2 blocks pass.

**Step 8: Run `devtools::document()` and `devtools::check()`**

### Acceptance criteria

- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] All PR 2 error classes added to `plans/error-messages.md` before code was written
- [ ] 98%+ line coverage on new code; overall package coverage ≥ 95% (verified with `covr::package_coverage()`)
- [ ] Happy paths: Convention 1 (bare names), Convention 3 (variable=), data frame; extractor `FALSE` for unset variables
- [ ] Error paths: all 8 error-path blocks written (5 unique classes; `not_survey_or_df` and `ambiguous_input` tested separately for setter and extractor)
- [ ] Edge cases: set-then-unset returns `FALSE`; zero-length return is `logical(0)`
- [ ] No PR 1 regressions
- [ ] `NEWS.md` entry written under the appropriate version heading
- [ ] Snapshot tests reviewed before PR opened

### Notes

- `set_reverse_coded()` does **not** support Convention 2 (named vector in `...`). It follows the `set_sata()` inline pattern: tidy-select `...` for bare names, `variable` for character vector — no `.parse_setter_input()`.
- The absence-equals-`FALSE` semantics mirror `sata`: no stored `FALSE` in the list; removing the entry is done by setting to `NULL`.
- `extract_reverse_coded()` has no `format` or `fill` arguments (unlike `extract_sata()`). It always returns a named logical vector.

---

## PR 3: `get_diffs()` favorability extensions

**Branch:** `feature/diffs-favorability`
**Depends on:** PR 1 fully merged to `develop` (`higher_is` must be in `survey_metadata`
and `.extract_var_meta()` must return `higher_is`)

**HARD GATE: Do not open this branch until PR 1 is merged.**

### Files (TDD order)

- `plans/error-messages.md` — add `surveycore_error_alpha_invalid`
- `tests/testthat/test-analysis-diffs.R` — write all PR 3 test blocks (failing)
- `R/analysis-diffs.R` — add `alpha`, `show_favorability` args; add favorability logic
- `NEWS.md` — add entry for `get_diffs()` `alpha` and `show_favorability` arguments

### Step-by-step (TDD)

**Step 1: Add error class to `plans/error-messages.md`**

Add one new row: `surveycore_error_alpha_invalid`.
Message template: `"{.arg alpha} must be a single numeric value strictly between 0 and 1. Got {.val {alpha}}."`

**Step 2: Write failing tests in `tests/testthat/test-analysis-diffs.R`**

Add a "PR 3 — favorability" section. Use existing test design setup from the file.
Set `higher_is` on the `x` variable via `set_higher_is()` before calling `get_diffs()`.

Happy-path blocks:
- `show_favorability = FALSE` (default): no `favorable`/`backlash` columns; `attr(result, ".meta")$x[[x_name]]$higher_is` equals `"worse"` (not just non-NULL — assert the value)
- `show_favorability = TRUE` + `higher_is = "worse"` + negative significant diff: `favorable = TRUE`, `backlash = FALSE`; `attr(result$favorable, "label")` equals `"Favorable"`; `attr(result$backlash, "label")` equals `"Backlash"`
- `show_favorability = TRUE` + `higher_is = "better"` + negative significant diff: `favorable = FALSE`, `backlash = TRUE`
- `show_favorability = TRUE` + non-significant result: `favorable = FALSE`, `backlash = FALSE`
- Custom `alpha = 0.01`: result with `p = 0.03` is not favorable/backlash (both `FALSE`)
- `name_style = "broom"` + `show_favorability = TRUE`: `favorable`/`backlash` present; classification uses `p.value` column
- `group` + `show_favorability = TRUE`: columns present; rows align correctly per group
- `pval_adj` set + `show_favorability = TRUE`: classification uses adjusted p-value

Error-path blocks (dual pattern):
- `alpha_invalid`: `alpha = 1.5`
- `alpha_invalid`: `alpha = 0`
- `alpha_invalid`: `alpha = "0.05"`
- `alpha_invalid`: `alpha = NA`
- `alpha_invalid`: `alpha = Inf`
- `alpha_invalid`: `alpha = c(0.05, 0.1)`

Edge-case blocks:
- `show_favorability = TRUE` with no `higher_is` set on `x`: both columns all `FALSE`; no warning
- `p_value` exactly equal to `alpha`: not significant — both `FALSE` (strict `<`, not `<=`)

**Step 3: Confirm all new test blocks fail (red)**

Run `devtools::test(filter = "analysis-diffs")`. All new blocks fail.

**Step 4: Add arguments to `get_diffs()` in `R/analysis-diffs.R`**

Insert `alpha` and `show_favorability` after `conf_level` in the signature:

```r
conf_level = 0.95,
alpha = 0.05,
show_favorability = FALSE,
min_cell_n = 30L,
```

Add `alpha` validation immediately after `.validate_shared_args()`:

```r
if (
  !is.numeric(alpha) ||
    length(alpha) != 1L ||
    is.na(alpha) ||
    !is.finite(alpha) ||
    alpha <= 0 ||
    alpha >= 1
) {
  cli::cli_abort(
    c(
      "x" = paste0(
        "{.arg alpha} must be a single numeric value strictly between ",
        "0 and 1. Got {.val {alpha}}."
      )
    ),
    class = "surveycore_error_alpha_invalid"
  )
}
```

Update roxygen docs for `get_diffs()`:
- Add `@param alpha` entry
- Add `@param show_favorability` entry
- Update `@return` to mention the optional `favorable`/`backlash` columns

**Step 5: Implement favorability logic in `R/analysis-diffs.R`**

Insert after `x_meta <- .extract_var_meta(design, x_name)` is assigned (after `.apply_name_style()`) and before `attr(result, ".meta") <- .build_meta(...)` is called. `x_meta` is the local variable holding the x-variable metadata; the block uses `x_meta$higher_is` directly, so it does not depend on `.meta` being attached to `result` yet:

```r
if (isTRUE(show_favorability)) {
  # Read higher_is from x_meta (the local variable set just before .build_meta())
  higher_is_val <- x_meta$higher_is

  # Detect which p-value column name is present (surveycore or broom)
  pval_col <- if ("p_value" %in% names(result)) "p_value" else "p.value"
  p_vals <- result[[pval_col]]

  sig <- !is.na(p_vals) & p_vals < alpha  # strict <

  favorable <- logical(nrow(result))
  backlash  <- logical(nrow(result))

  if (!is.null(higher_is_val)) {
    est <- result$estimate  # column name is "estimate" in get_diffs()
    if (higher_is_val == "better") {
      favorable[sig] <- est[sig] > 0
      backlash[sig]  <- est[sig] < 0
    } else if (higher_is_val == "worse") {
      favorable[sig] <- est[sig] < 0
      backlash[sig]  <- est[sig] > 0
    }
  }
  # If higher_is_val is NULL, favorable/backlash remain all FALSE

  attr(favorable, "label") <- "Favorable"
  attr(backlash,  "label") <- "Backlash"

  saved_meta  <- attr(result, ".meta")
  saved_class <- class(result)
  result$favorable <- favorable
  result$backlash  <- backlash
  attr(result, ".meta") <- saved_meta
  class(result) <- saved_class
}
```

Important ordering constraint: favorability uses the adjusted p-value (if `pval_adj` was
applied) because the p-value column already contains the adjusted values by the time
this block runs. This is correct per spec rule 4.

**Step 6: Confirm all PR 3 tests pass (green)**

Run `devtools::test(filter = "analysis-diffs")`. All new blocks pass. No regressions.

**Step 7: Run `devtools::document()` and `devtools::check()`**

### Acceptance criteria

- [ ] All new tests confirmed failing (red) before implementation began
- [ ] PR 1 is confirmed merged to `develop` before this branch opens
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] `alpha_invalid` error class added to `plans/error-messages.md` before code written
- [ ] Happy paths: `show_favorability = FALSE` (default, no columns), `"better"` direction, `"worse"` direction, non-significant → both `FALSE`
- [ ] Column label attributes `"Favorable"` and `"Backlash"` asserted in happy-path test
- [ ] `.meta$x[[x_name]]$higher_is` asserted to equal `"worse"` (not just non-NULL)
- [ ] `name_style = "broom"` path tested: `favorable`/`backlash` present, classification uses `p.value`
- [ ] `group` path tested: columns aligned across groups
- [ ] `pval_adj` path tested: classification uses adjusted p-value
- [ ] Error paths: all 6 `alpha_invalid` variants produce snapshot-matched messages
- [ ] Edge cases: `higher_is` unset → both `FALSE`; `p == alpha` → both `FALSE`
- [ ] No regressions in any existing `test-analysis-diffs.R` blocks
- [ ] 98%+ line coverage on new code; overall package coverage ≥ 95% (verified with `covr::package_coverage()`)
- [ ] `NEWS.md` entry written under the appropriate version heading
- [ ] Snapshot tests reviewed before PR opened

### Notes

- Favorability block is inserted after `x_meta <- .extract_var_meta(design, x_name)` is assigned and after `.apply_name_style()` runs (so `p.value` vs. `p_value` detection works), but BEFORE `attr(result, ".meta") <- .build_meta(...)`. Using `x_meta$higher_is` (not `attr(result, ".meta")$x[[x_name]]$higher_is`) means the block has no ordering dependency on `.meta` being attached to `result`. Do not add `favorable`/`backlash` to the broom rename map — they are invariant.
- `favorable` and `backlash` are appended to the result tibble last (after all other columns). Save and restore `.meta` and S3 class around the assignment to avoid attribute loss.
- When `show_favorability = FALSE` (default), the `higher_is` value is still present in `.meta` (via PR 1's `.extract_var_meta()` update) — the test for this must assert the actual value, not just non-NULL.
- The estimate column in `get_diffs()` output is named `"estimate"` — no need to handle multiple possible names.
- `is.finite(alpha)` is `FALSE` for both `NA` and `Inf`, so a single `!is.finite(alpha)` check covers both. Use the combined validation shown above.

---

## Post-PR 3 checklist

- [ ] All three PRs merged to `develop`
- [ ] `develop` green on CI
- [ ] Move `plans/spec-variable-direction.md`, `plans/spec-review-variable-direction.md`, `plans/decisions-variable-direction.md`, `plans/impl-variable-direction.md` to `archive/variable-direction/`
- [ ] Update `CLAUDE.md` implementation status table

> Review the PR map carefully — the scope of each PR is harder to change once
> implementation starts. Confirm that no PR bundles functions that should be separate.
> Run Stage 2 in a new session for an adversarial review of this plan before
> handing off to `/r-implement`.
