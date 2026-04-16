# Implementation Plan: SATA Metadata & tidyselect Extractor Migration

**Spec:** `plans/spec-sata-metadata.md` (v1.0, approved 2026-04-16)
**Decisions:** `plans/decisions-sata-metadata.md`
**Branch ID:** `sata-metadata`

---

## Overview

This plan delivers the SATA metadata system from the approved spec: the `sata`
property on `survey_metadata`, `set_sata()`, `extract_sata()`, and
`classify_question_type()`. It also migrates all seven existing `extract_*()`
functions from `.resolve_vars()` to `tidyselect::eval_select()`, establishing
a consistent set/get API where both setters and getters accept the same
tidyselect helpers (`starts_with()`, `all_of()`, `any_of()`, etc.).

Four PRs in strict sequence. PRs 1 and 2 lay shared infrastructure; PRs 3 and 4
add the new SATA functions. The tidyselect migration (PR 2) ships before the new
SATA functions (PR 3) so the pattern is established before it is followed.

---

## PR Map

- [x] PR 1: `feature/sata-property` — Add `sata` property to `survey_metadata`, `.get_data_for_select()` helper, and update `.rename_metadata_keys()`
- [x] PR 2: `feature/extract-tidyselect` — Migrate all seven `extract_*()` functions from `.resolve_vars()` to `tidyselect::eval_select()`
- [x] PR 3: `feature/set-extract-sata` — Implement `set_sata()` and `extract_sata()` with `.format_logical_result()`
- [ ] PR 4: `feature/classify-question-type` — Implement `classify_question_type()` and update `.extract_var_meta()`

---

## PR 1: `sata` Property + Shared Infrastructure

**Branch:** `feature/sata-property`
**Depends on:** none

### Files (TDD order)

- `tests/testthat/test-s7-classes.R` — add `sata` property presence and default tests
- `tests/testthat/test-metadata-system.R` — add `.rename_metadata_keys()` + sata integration test
- `R/core-classes.R` — add `sata` property to `survey_metadata`
- `R/utils.R` — add `.get_data_for_select()` helper
- `R/core-validators.R` — add `sata` to `.rename_metadata_keys()`
- `changelog/sata-metadata/feature-sata-property.md` — created last, before opening PR

### Step-by-step tasks

**Step 1.1 — Write failing tests (red)**

In `test-s7-classes.R`, add:
```r
test_that("survey_metadata has a sata property with list() default", {
  m <- survey_metadata()
  expect_true(S7::S7_inherits(m, survey_metadata))
  expect_identical(m@sata, list())
  expect_identical(length(m@sata), 0L)
})

test_that("survey_metadata sata accepts a named list", {
  m <- survey_metadata(sata = list(news_tv = TRUE, news_online = TRUE))
  expect_identical(m@sata$news_tv, TRUE)
})
```

In `test-metadata-system.R`, add a block for rename + sata:
```r
test_that(".rename_metadata_keys() propagates sata flag through rename", {
  d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtint2yr,
                 strata = sdmvstra, nest = TRUE)
  d@metadata@sata[["riagendr"]] <- TRUE
  d@metadata <- surveycore:::.rename_metadata_keys(
    d@metadata,
    c(riagendr = "gender")
  )
  expect_null(d@metadata@sata[["riagendr"]])
  expect_true(isTRUE(d@metadata@sata[["gender"]]))
})
```

Run `devtools::test(filter = "s7-classes")` and `devtools::test(filter = "metadata-system")`. Confirm the new blocks fail.

**Step 1.2 — Implement**

In `R/core-classes.R`, add to `survey_metadata` properties:
```r
sata = S7::new_property(
  S7::class_list,
  default = quote(list())
),
```
Place after `missing_codes` and before `transformations` (keeping existing
property order). Also add `sata` to the `@param` block in the roxygen doc.

In `R/utils.R`, add at the bottom:
```r
# .get_data_for_select(x)
# Returns the data frame to pass to tidyselect::eval_select().
# For data frames, returns x directly. For survey objects, returns x@data.
# Two confirmed call sites: set_sata() and extract_sata().
.get_data_for_select <- function(x) {
  if (is.data.frame(x)) x else x@data
}
```

In `R/core-validators.R`, inside `.rename_metadata_keys()` after the last
`.rename_list_keys()` call:
```r
metadata@sata <- .rename_list_keys(metadata@sata, rename_map)
```

**Step 1.3 — Verify and document**

Run `devtools::test(filter = "s7-classes")` and `devtools::test(filter = "metadata-system")`. Confirm new tests pass. Run `devtools::document()` and confirm `man/survey_metadata.Rd` is updated. Run `devtools::check()`.

### Acceptance criteria

- [ ] All new test blocks confirmed failing before Step 1.2
- [ ] `survey_metadata()@sata` is `list()`
- [ ] `survey_metadata(sata = list(x = TRUE))@sata$x` is `TRUE`
- [ ] `.rename_metadata_keys()` renames `sata` keys correctly
- [ ] `devtools::document()` run; `man/survey_metadata.Rd` updated
- [ ] Coverage ≥ 98% for all new/changed code
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 notes
- [ ] Changelog entry written

---

## PR 2: Migrate `extract_*()` to tidyselect

**Branch:** `feature/extract-tidyselect`
**Depends on:** PR 1 (for `.get_data_for_select()`)

### Overview

The seven `extract_*()` functions currently resolve `...` via `.resolve_vars()`,
which evaluates bare symbols and character expressions but does not support
tidyselect helpers like `starts_with()`, `all_of()`, or `matches()`. This PR
replaces that resolution with `tidyselect::eval_select()`.

**Behavior change (breaking for one edge case):**
Passing a bare name that does not exist in `x` currently produces a
`surveycore_warning_var_not_found` warning and skips the variable. After this
PR, it produces a tidyselect error (rlang-style, with "did you mean...?" support
when there is a near-match). Users who want "skip if not found" semantics for
programmatic name lists should use `any_of()`:
```r
# Old: warns and skips
extract_var_label(d, nonexistent_col)          # was: warn + skip

# New: use any_of() for skip-if-missing semantics
extract_var_label(d, any_of("nonexistent_col"))  # silently omitted
```
This is documented in the `@param ...` change below.

**`tidyselect` is already in `Imports` (`DESCRIPTION` line 26). No change needed.**

### Files (TDD order)

- `tests/testthat/test-metadata-system.R` — add tidyselect behavior tests; remove `.resolve_vars()` direct tests; update snapshots
- `R/core-metadata.R` — replace `.resolve_vars()` calls in all 7 extractors; remove `.resolve_vars()` definition
- `changelog/sata-metadata/feature-extract-tidyselect.md` — created last

### Step-by-step tasks

**Step 2.1 — Write new tests (they will pass before the migration, or fail if they use new selectors)**

Add a block in `test-metadata-system.R` that tests tidyselect helpers across
the extractors. Use at least `starts_with()` and `all_of()` on two different
extractors as representative coverage:
```r
test_that("extract_var_label() supports starts_with() selector", {
  d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtint2yr,
                 strata = sdmvstra, nest = TRUE)
  result <- extract_var_label(d, starts_with("sdmv"))
  expect_true(all(startsWith(names(result), "sdmv")))
})

test_that("extract_question_preface() supports all_of() selector", {
  d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtint2yr,
                 strata = sdmvstra, nest = TRUE)
  d <- set_question_preface(d, riagendr = "Demographics")
  result <- extract_question_preface(d, all_of(c("riagendr", "ridageyr")))
  expect_true("riagendr" %in% names(result))
})

test_that("extract_var_label() any_of() silently omits missing columns", {
  d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtint2yr,
                 strata = sdmvstra, nest = TRUE)
  result <- extract_var_label(d, any_of(c("riagendr", "col_that_does_not_exist")))
  expect_false("col_that_does_not_exist" %in% names(result))
  expect_true("riagendr" %in% names(result))
})
```

Run `devtools::test(filter = "metadata-system")`. The `starts_with()` and
`all_of()` tests should fail (`.resolve_vars()` doesn't support them).

**Step 2.2 — Remove `.resolve_vars()` direct tests**

In `test-metadata-system.R`, delete the five direct `.resolve_vars()` test
blocks (the section starting `# ── .resolve_vars() ─────`). Also delete the
corresponding snapshot from `tests/testthat/_snaps/metadata-system.md`.

**Step 2.3 — Migrate all 7 extractors**

The pattern change in `R/core-metadata.R` for every extractor:

```r
# BEFORE (remove this line):
var_names <- .resolve_vars(x, rlang::enquos(...), call = call)

# AFTER (replace with these lines):
var_names <- if (...length() == 0L) {
  .get_data_cols(x)
} else {
  names(tidyselect::eval_select(rlang::expr(c(...)), data = .get_data_for_select(x)))
}
```

Apply this change to all 7 extractors:
- `extract_var_label()` (line ~464)
- `extract_val_labels()` (line ~513)
- `extract_question_preface()` (line ~575)
- `extract_var_note()` (line ~629)
- `extract_universe()` (line ~684)
- `extract_missing_codes()` (line ~735)
- `extract_metadata()` (line ~832)

After all 7 are migrated, delete the `.resolve_vars()` function definition
(lines ~206–247 of `R/core-metadata.R`).

**Step 2.4 — Update `@param ...` documentation**

In all 7 extractors, change the `@param ...` description from:
```r
#' @param ... <[`data-masked`][rlang::args_data_masking]> Variable names
#'   (bare, unquoted). If empty, metadata for all variables is returned.
```
to:
```r
#' @param ... <[`tidy-select`][tidyselect::language]> Variables to query.
#'   Supports selection helpers: [tidyselect::starts_with()],
#'   [tidyselect::all_of()], [tidyselect::any_of()], [tidyselect::matches()],
#'   etc. If empty, returns metadata for all variables. Use [tidyselect::any_of()]
#'   to silently skip missing variable names.
```

**Step 2.5 — Verify**

Run `devtools::test(filter = "metadata-system")`. All new tests should pass.
Run `devtools::document()` and review updated `.Rd` files. Run `devtools::check()`.

### Acceptance criteria

- [ ] All 7 extractors support `starts_with()`, `all_of()`, `any_of()`, `matches()`
- [ ] Empty `...` still returns metadata for all columns
- [ ] `.resolve_vars()` definition removed from `R/core-metadata.R`
- [ ] `.resolve_vars()` direct tests removed from `test-metadata-system.R`
- [ ] Old `.resolve_vars()` snapshot removed from `_snaps/metadata-system.md`
- [ ] New tidyselect behavior tests added and passing
- [ ] `@param ...` updated to `tidy-select` in all 7 extractors
- [ ] `devtools::document()` run; all 7 `.Rd` files updated
- [ ] Coverage ≥ 98% for all new/changed code
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 notes
- [ ] Changelog entry written

---

## PR 3: `set_sata()` and `extract_sata()`

**Branch:** `feature/set-extract-sata`
**Depends on:** PR 1 (for `sata` property and `.get_data_for_select()`)

### Files (TDD order)

- `tests/testthat/test-metadata-system.R` — add `set_sata()` + `extract_sata()` tests
- `plans/error-messages.md` — add new error/warning classes before writing code
- `R/core-metadata.R` — add `.format_logical_result()`, `set_sata()`, `extract_sata()`
- `changelog/sata-metadata/feature-set-extract-sata.md` — created last

### New error classes (add to `plans/error-messages.md` first)

| Class | Level | Function |
|-------|-------|----------|
| `surveycore_error_sata_ambiguous_input` | ERROR | `set_sata()`, `extract_sata()` |
| `surveycore_error_sata_no_vars` | ERROR | `set_sata()` |
| `surveycore_error_sata_not_logical` | ERROR | `set_sata()`, `extract_sata()` |

The `surveycore_warning_var_not_found` class already exists — reuse it.

### Step-by-step tasks

**Step 3.1 — Add error classes to `plans/error-messages.md`**

Add the three new error class rows to the table. This must be done before
writing any code that references these classes.

**Step 3.2 — Write all failing tests (red)**

Add the following test sections to `test-metadata-system.R`:

```
# ── set_sata() — happy path ────────────────────────────────────────────────

test_that("set_sata() marks variables as SATA on a survey object")
test_that("set_sata() marks variables as SATA on a plain data frame")
test_that("set_sata() works with tidy-select starts_with()")
test_that("set_sata() Convention B: variable = character vector")
test_that("set_sata(sata = FALSE) removes SATA flag from survey object")
test_that("set_sata() on already-SATA variable is idempotent (no error)")
test_that("set_sata(sata = FALSE) on non-SATA variable is a no-op")
test_that("set_sata() returns invisible(x)")

# ── set_sata() — error paths ───────────────────────────────────────────────

test_that("set_sata() errors when x is not a survey or data frame")
test_that("snapshot: set_sata() not-survey-or-df error message")
test_that("set_sata() errors when both ... and variable provided")
test_that("snapshot: set_sata() ambiguous input error message")
test_that("set_sata() errors when neither ... nor variable provided")
test_that("snapshot: set_sata() no vars error message")
test_that("set_sata() errors when sata = NA")
test_that("snapshot: set_sata() sata = NA error message")
test_that("set_sata() errors when sata = 'yes' (non-logical)")
test_that("snapshot: set_sata() non-logical sata error message")
test_that("set_sata(variable = character(0)) errors like no-vars")
test_that("set_sata() warns for non-existent variable (variable = path)")

# ── extract_sata() — happy path ────────────────────────────────────────────

test_that("extract_sata() returns TRUE for marked variables")
test_that("extract_sata() returns FALSE for unmarked variables (default fill)")
test_that("extract_sata() fill = NULL returns only marked variables")
test_that("extract_sata() format = 'data_frame' returns correct tibble")
test_that("extract_sata() format = 'list' returns correct list")
test_that("extract_sata() on data frame reads column attributes")
test_that("extract_sata() empty ... + fill = FALSE returns dense result")
test_that("extract_sata() empty ... + fill = NULL returns sparse result")
test_that("extract_sata() with named vars + fill = NULL omits non-SATA vars")
test_that("roundtrip: set_sata() then extract_sata() recovers flags")
test_that("survey object with zero SATA variables: length(x@metadata@sata) == 0L")

# ── extract_sata() — error paths ──────────────────────────────────────────

test_that("extract_sata() errors when x is not a survey or data frame")
test_that("snapshot: extract_sata() not-survey-or-df error message")
test_that("extract_sata() errors when fill = TRUE")
test_that("snapshot: extract_sata() fill = TRUE error message")
test_that("extract_sata() errors when fill = 'x' (invalid)")
test_that("snapshot: extract_sata() invalid fill error message")
test_that("extract_sata() errors when format is invalid")
test_that("snapshot: extract_sata() invalid format error message")
```

Run `devtools::test(filter = "metadata-system")`. Confirm all new blocks fail.

**Step 3.3 — Add `.format_logical_result()` helper**

In `R/core-metadata.R`, add the helper (used only by `extract_sata()`):

```r
# .format_logical_result(result, format)
# Converts a named logical vector to the requested output format.
# result: named logical vector (names = variable names, values = TRUE/FALSE)
# format: one of "named_vector", "list", "data_frame"
# Empty input returns logical(0), list(), or a zero-row tibble.
.format_logical_result <- function(result, format) {
  switch(
    format,
    named_vector = result,
    list         = as.list(result),
    data_frame   = tibble::tibble(
      variable = names(result),
      sata     = unname(result)
    )
  )
}
```

Place this in the `# ── Extractors ────` section near the other format helpers.

**Step 3.4 — Implement `set_sata()`**

```r
#' Set SATA (Select-All-That-Apply) Flag
#'
#' Marks one or more variables as select-all-that-apply (SATA) in a survey
#' design object or data frame.
#'
#' @param x A survey design object or `data.frame`.
#' @param ... <[`tidy-select`][tidyselect::language]> Variables to mark.
#'   Supports selection helpers: [tidyselect::starts_with()],
#'   [tidyselect::all_of()], [tidyselect::any_of()], etc.
#'   Cannot be combined with `variable`.
#' @param variable `character`. Alternative programmatic interface: character
#'   vector of variable names. Cannot be combined with `...`.
#' @param sata `logical(1)`. `TRUE` (default) to mark as SATA; `FALSE` to unmark.
#'
#' @return The modified object, invisibly.
#'
#' @examples
#' d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtint2yr,
#'                strata = sdmvstra, nest = TRUE)
#' d <- set_sata(d, riagendr, ridageyr)
#' d <- set_sata(d, sata = FALSE, riagendr)
#'
#' @family metadata
#' @export
set_sata <- function(x, ..., variable = NULL, sata = TRUE) {
  call <- rlang::caller_env()
  .check_is_survey_or_df(x, call = call)

  # Validate sata argument
  if (!is.logical(sata) || length(sata) != 1L || is.na(sata)) {
    cli::cli_abort(
      c("x" = "{.arg sata} must be {.code TRUE} or {.code FALSE}."),
      class = "surveycore_error_sata_not_logical",
      call = call
    )
  }

  # Resolve variables — exactly one of ... or variable
  dots_used <- ...length() > 0L
  var_used  <- !is.null(variable) && length(variable) > 0L

  if (dots_used && !is.null(variable)) {
    cli::cli_abort(
      c("x" = "Provide variable names via {.arg ...} or via {.arg variable}, not both."),
      class = "surveycore_error_sata_ambiguous_input",
      call = call
    )
  }

  if (!dots_used && (!var_used || identical(variable, character(0)))) {
    cli::cli_abort(
      c("x" = "{.fn set_sata} requires at least one variable name."),
      class = "surveycore_error_sata_no_vars",
      call = call
    )
  }

  if (dots_used) {
    var_names <- names(
      tidyselect::eval_select(rlang::expr(c(...)), data = .get_data_for_select(x))
    )
  } else {
    # variable = character vector path: warn and skip missing names
    all_cols  <- .get_data_cols(x)
    missing   <- setdiff(variable, all_cols)
    if (length(missing) > 0L) {
      cli::cli_warn(
        c("!" = paste0(
          "{length(missing)} variable{?s} not found in {.arg x}",
          " and {?was/were} skipped: {.field {missing}}."
        )),
        class = "surveycore_warning_var_not_found",
        call = call
      )
    }
    var_names <- intersect(variable, all_cols)
  }

  # Apply flag
  for (v in var_names) {
    if (S7::S7_inherits(x, survey_base)) {
      if (isTRUE(sata)) {
        x@metadata@sata[[v]] <- TRUE
      } else {
        x@metadata@sata[[v]] <- NULL
      }
    } else {
      attr(x[[v]], "sata") <- if (isTRUE(sata)) TRUE else NULL
    }
  }

  invisible(x)
}
```

**Step 3.5 — Implement `extract_sata()`**

```r
#' Extract SATA Flags
#'
#' Returns the select-all-that-apply (SATA) status for variables in a survey
#' design object or data frame.
#'
#' @param x A survey design object or `data.frame`.
#' @param ... <[`tidy-select`][tidyselect::language]> Variables to query.
#'   If empty, returns SATA status for all variables.
#' @param format `character(1)`. Output format: `"named_vector"` (default),
#'   `"list"`, or `"data_frame"`.
#' @param fill `FALSE` (default) or `NULL`. Controls how unmarked variables
#'   are reported. `FALSE` includes them as `FALSE`; `NULL` omits them.
#'   `TRUE` is not accepted and will error.
#'
#' @return
#' - `"named_vector"` (default): named logical vector. Empty: `logical(0)`.
#' - `"list"`: named list of logical scalars. Empty: `list()`.
#' - `"data_frame"`: tibble with columns `variable` (character) and `sata`
#'   (logical). Empty: zero-row tibble.
#'
#' @examples
#' d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtint2yr,
#'                strata = sdmvstra, nest = TRUE)
#' d <- set_sata(d, riagendr)
#' extract_sata(d)
#' extract_sata(d, riagendr, fill = NULL)
#'
#' @family metadata
#' @export
extract_sata <- function(x, ..., format = "named_vector", fill = FALSE) {
  call <- rlang::caller_env()
  .check_is_survey_or_df(x, call = call)

  # Validate fill — only FALSE or NULL are accepted; TRUE is not a supported value
  if (!is.null(fill) && !identical(fill, FALSE)) {
    cli::cli_abort(
      c("x" = "{.arg fill} must be {.code FALSE} or {.code NULL}."),
      class = "surveycore_error_sata_not_logical",
      call = call
    )
  }

  # Validate format
  .check_extractor_format(format, "extract_sata", c("named_vector", "list", "data_frame"), call)

  # Resolve variables
  if (...length() == 0L) {
    var_names <- .get_data_cols(x)
  } else {
    var_names <- names(
      tidyselect::eval_select(rlang::expr(c(...)), data = .get_data_for_select(x))
    )
  }

  # Build result: named logical vector
  result <- stats::setNames(
    vapply(var_names, function(v) {
      raw <- if (S7::S7_inherits(x, survey_base)) {
        x@metadata@sata[[v]]
      } else {
        attr(x[[v]], "sata", exact = TRUE)
      }
      isTRUE(raw)
    }, logical(1L)),
    var_names
  )

  # Apply fill
  if (is.null(fill)) {
    result <- result[result]  # keep only TRUE entries
  }
  # fill = FALSE: already FALSE for unmarked (no further action needed)

  .format_logical_result(result, format)
}
```

**Step 3.6 — Verify**

Run `devtools::test(filter = "metadata-system")`. All blocks should pass.
Run `devtools::snapshot_review()` to approve new snapshot files. Run
`devtools::document()`. Run `devtools::check()`.

### Acceptance criteria

- [ ] All new test blocks confirmed failing before Step 3.4
- [ ] `set_sata()` Convention A (tidyselect `...`) marks variables correctly
- [ ] `set_sata()` Convention B (`variable =`) marks variables correctly
- [ ] `set_sata(sata = FALSE)` removes flag from `x@metadata@sata`
- [ ] `set_sata()` with `starts_with()` marks all matching columns
- [ ] `set_sata()` on already-SATA variable is idempotent
- [ ] `set_sata(sata = FALSE)` on non-SATA variable is a no-op (no error)
- [ ] `set_sata()` returns `invisible(x)`
- [ ] `set_sata()` with non-survey non-df `x` → `surveycore_error_not_survey_or_df`
- [ ] `set_sata(sata = NA)` → `surveycore_error_sata_not_logical`
- [ ] `set_sata()` with both `...` and `variable` → `surveycore_error_sata_ambiguous_input`
- [ ] `set_sata()` with neither → `surveycore_error_sata_no_vars`
- [ ] `set_sata(variable = character(0))` → `surveycore_error_sata_no_vars`
- [ ] `set_sata()` with nonexistent name in `variable =` → `surveycore_warning_var_not_found`
- [ ] `extract_sata()` dense view (`fill = FALSE`, empty `...`) returns all cols as logical
- [ ] `extract_sata()` sparse view (`fill = NULL`, empty `...`) returns only flagged vars
- [ ] `extract_sata(d, var1, var2, fill = NULL)` where only `var1` is SATA → only `var1` in result
- [ ] `extract_sata()` all three formats correct
- [ ] `extract_sata()` on data frame reads `attr(col, "sata", exact = TRUE)`
- [ ] Roundtrip: set then extract recovers exact flags
- [ ] `extract_sata()` with non-survey non-df `x` → `surveycore_error_not_survey_or_df`
- [ ] `extract_sata(fill = TRUE)` → `surveycore_error_sata_not_logical`
- [ ] Other invalid `fill` (e.g., `"x"`) → `surveycore_error_sata_not_logical`
- [ ] Invalid `format` → `surveycore_error_format_invalid`
- [ ] All error paths tested with dual pattern: `expect_error(class=)` + `expect_snapshot(error=TRUE)`
- [ ] New error classes in `plans/error-messages.md`
- [ ] `devtools::document()` run; `man/set_sata.Rd` and `man/extract_sata.Rd` created
- [ ] Coverage ≥ 98% for all new/changed code
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 notes
- [ ] Changelog entry written

---

## PR 4: `classify_question_type()` + `.extract_var_meta()` update

**Branch:** `feature/classify-question-type`
**Depends on:** PR 3 (for `set_sata()`, needed in tests to mark variables)

### Files (TDD order)

- `tests/testthat/test-sata-detection.R` — NEW file: all `classify_question_type()` tests
- `tests/testthat/test-metadata-system.R` — add `.extract_var_meta()` integration test
- `plans/error-messages.md` — add new error/warning classes before writing code
- `R/core-metadata.R` — add `classify_question_type()`
- `R/analysis-helpers.R` — update `.extract_var_meta()` to include `sata`
- `changelog/sata-metadata/feature-classify-question-type.md` — created last

### New error/warning classes (add to `plans/error-messages.md` first)

| Class | Level | Function |
|-------|-------|----------|
| `surveycore_error_detect_ambiguous_input` | ERROR | `classify_question_type()` |
| `surveycore_error_detect_no_vars` | ERROR | `classify_question_type()` |
| `surveycore_warning_sata_no_preface` | WARN | `classify_question_type()` |
| `surveycore_warning_sata_mixed_group` | WARN | `classify_question_type()` |

### Step-by-step tasks

**Step 4.1 — Add error classes to `plans/error-messages.md`**

Add the four new rows to the table. Do this before writing any code.

**Step 4.2 — Write failing tests for `classify_question_type()` (red)**

Create `tests/testthat/test-sata-detection.R`. Add all test blocks from spec
Section IX (`classify_question_type()` test plan):

```
# ── classify_question_type() — happy path ──────────────────────────────────

test_that("single-response variables (no question_preface) → type = 'single'")
test_that("SATA variables (shared preface + sata = TRUE) → type = 'sata'")
test_that("battery variables (shared preface, no sata) → type = 'battery'")
test_that("mixed types in one call: each group classified correctly")
test_that("group numbers are sequential by first appearance")
test_that("output tibble has variable, question_preface, type, group columns")
test_that("variable = interface works for programmatic use")

# ── classify_question_type() — error paths ─────────────────────────────────

test_that("no variables provided → surveycore_error_detect_no_vars")
test_that("snapshot: classify_question_type() no-vars error message")
test_that("both ... and variable provided → surveycore_error_detect_ambiguous_input")
test_that("snapshot: classify_question_type() ambiguous input error message")
test_that("non-survey non-data-frame input → surveycore_error_not_survey_or_df")
test_that("snapshot: classify_question_type() not-survey-or-df error message")

# ── classify_question_type() — edge cases ─────────────────────────────────

test_that("single var with question_preface (no peers) → type = 'single'")
test_that("SATA var with no shared question_preface → type = 'single' + warning")
test_that("mixed SATA/non-SATA in same preface group → type = 'sata' + warning")
test_that("all requested variables not found → zero-row tibble")
test_that("variable = character(0) → surveycore_error_detect_no_vars")
test_that("data frame input classifies correctly via column attributes")
```

Run `devtools::test(filter = "sata-detection")`. Confirm all blocks fail.

**Step 4.3 — Write failing `.extract_var_meta()` test (red)**

In `test-metadata-system.R`, add:
```r
test_that(".extract_var_meta() includes sata key in output", {
  d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtint2yr,
                 strata = sdmvstra, nest = TRUE)
  d <- set_sata(d, riagendr)
  meta_sata    <- surveycore:::.extract_var_meta(d, "riagendr")
  meta_no_sata <- surveycore:::.extract_var_meta(d, "ridageyr")
  expect_true(meta_sata$sata)
  expect_false(meta_no_sata$sata)
})
```

Run `devtools::test(filter = "metadata-system")`. Confirm this block fails.

**Step 4.4 — Update `.extract_var_meta()` in `R/analysis-helpers.R`**

Add `sata` extraction and include it in the return list:

```r
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
    storage.mode(value_labels) <- "integer"
  }

  sata <- isTRUE(design@metadata@sata[[var_name]])

  list(
    variable_label   = variable_label,
    question_preface = question_preface,
    value_labels     = value_labels,
    sata             = sata
  )
}
```

Run `.extract_var_meta()` test to confirm it passes.

**Step 4.4b — Update existing test that checks `.extract_var_meta()` output names**

In `tests/testthat/test-analysis-helpers.R`, find the assertion at approximately
line 779 that reads:
```r
expect_identical(
  names(result),
  c("variable_label", "question_preface", "value_labels")
)
```
Update it to include the new `sata` key:
```r
expect_identical(
  names(result),
  c("variable_label", "question_preface", "value_labels", "sata")
)
```

Run `devtools::test(filter = "analysis-helpers")` to confirm the test passes.
This step must be completed before Step 4.5 to keep the test suite green.

**Step 4.5 — Implement `classify_question_type()`**

The function classifies variables into `"single"`, `"sata"`, or `"battery"`
based on their `question_preface` and `sata` metadata. See spec Section VI
for the full algorithm.

Key implementation points:
- Accept `...` (tidyselect) or `variable =` (character vector); exactly one required
- Resolve `...` via `tidyselect::eval_select()` or `variable =` via name validation
- Use `x@metadata@question_prefaces[[v]]` and `x@metadata@sata[[v]]` for survey objects
- Use `attr(x[[v]], "question_preface", exact = TRUE)` and `attr(x[[v]], "sata", exact = TRUE)` for data frames
- Group by `question_preface`: variables with the same non-NA preface share a group
- A group of 1 (unique preface among requested vars) → `"single"` regardless of preface content
- Groups with 2+ members: check any `sata = TRUE` → `"sata"` for all in group; else `"battery"`
- If a group has mixed sata status, issue `surveycore_warning_sata_mixed_group` (whole group = `"sata"`)
- If a variable is marked SATA but has no shared preface (group of 1), issue `surveycore_warning_sata_no_preface` (type = `"single"`)
- Group numbers: sequential integer by first appearance of each group in the requested var list
- Returns tibble with columns: `variable` (chr), `question_preface` (chr), `type` (chr), `group` (int)
- Use `.check_is_survey_or_df(x, call = rlang::caller_env())` as first validation

Signature:
```r
classify_question_type <- function(x, ..., variable = NULL)
```

**Step 4.6 — Verify**

Run `devtools::test(filter = "sata-detection")`. Run
`devtools::test(filter = "metadata-system")`. Run `devtools::snapshot_review()`
to approve new snapshot files. Run `devtools::document()`. Run `devtools::check()`.

### Acceptance criteria

- [ ] All new test blocks confirmed failing before Steps 4.4–4.5
- [ ] `classify_question_type()` `...` interface works (tidyselect)
- [ ] `classify_question_type()` `variable =` interface works (programmatic)
- [ ] `type = "single"` for vars with no `question_preface`
- [ ] `type = "sata"` for vars sharing a `question_preface` where any has `sata = TRUE`
- [ ] `type = "battery"` for vars sharing a `question_preface` where none has `sata = TRUE`
- [ ] Group numbers sequential by first appearance
- [ ] Output tibble has `variable`, `question_preface`, `type`, `group` columns with correct types
- [ ] SATA var with unique preface → `"single"` + `surveycore_warning_sata_no_preface`
- [ ] Mixed sata within preface group → `"sata"` + `surveycore_warning_sata_mixed_group`
- [ ] All-not-found vars → zero-row tibble
- [ ] Data frame path works via column attributes
- [ ] `variable = character(0)` → `surveycore_error_detect_no_vars`
- [ ] All error/warning paths tested with dual pattern
- [ ] `.extract_var_meta()` returns `sata = TRUE/FALSE` key
- [ ] `test-analysis-helpers.R` names assertion updated to include `sata` (line ~779)
- [ ] New error/warning classes in `plans/error-messages.md`
- [ ] `devtools::document()` run; `man/classify_question_type.Rd` created
- [ ] Snapshot files for all new error/warning messages created and committed
- [ ] Coverage ≥ 98% for all new/changed code
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 notes
- [ ] Changelog entry written

---

## Cross-Cutting Notes

### `.get_data_for_select()` — two call sites after PR 3

After PR 3 ships, `.get_data_for_select()` has call sites in:
1. All 7 extractors (via the tidyselect resolution block in PR 2)
2. `set_sata()` (PR 3)
3. `extract_sata()` (PR 3)
4. `classify_question_type()` (PR 4, if it uses tidyselect for `...`)

This meets and exceeds the two-call-site threshold for a named helper in
`R/utils.R` (code-style.md §4).

### `DESCRIPTION` — no changes needed

`tidyselect` is already in `Imports` (line 26). `tibble` is already imported.

### `error-messages.md` update cadence

Add error classes to `plans/error-messages.md` at the START of each PR
(before writing implementation code). This ensures classes are in the
canonical table before any test references them.

### Snapshot management

Each PR that adds `expect_snapshot(error = TRUE)` blocks will generate new
`.md` files in `tests/testthat/_snaps/`. Run `devtools::snapshot_review()`
to review and accept these before committing. Never run
`testthat::snapshot_accept()` blindly.

### `.extract_var_meta()` downstream impact

After PR 4, `.extract_var_meta()` returns `sata = TRUE/FALSE` in its list.
Any existing tests in `test-analysis-*.R` that check `.meta$x` structure
will need to be updated to include the new `sata` key. Scan for uses before
marking PR 4 complete.
