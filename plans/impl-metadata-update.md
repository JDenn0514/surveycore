# Implementation Plan — surveycore metadata-update

**Spec:** `plans/spec-metadata-update.md` (v3.0, approved)
**Decisions log:** `plans/decisions-metadata-update.md`
**Plan review:** `plans/plan-review-metadata-update.md` (Pass 1 + Pass 2 resolved — approved)

---

## Overview

This plan implements the metadata API update specified in `spec-metadata-update.md`.
It adds two new `survey_metadata` fields (`universe`, `missing_codes`), replaces
the existing singular/plural setter dichotomy with a unified three-convention API,
extends all extractors with multi-variable support and output format control, adds
`extract_metadata()` as a summary function, and enables data frame support
throughout. The deprecated plural setters (`set_variable_labels()`, etc.) remain as
thin `lifecycle::deprecate_soft()` wrappers. All changes land in two existing files
(`R/core-classes.R`, `R/core-metadata.R`) and two existing test files.

---

## PR Map

- [x] PR 1: `feature/metadata-s7-classes` — Add `universe`/`missing_codes` to `survey_metadata`; update error catalog
- [x] PR 2: `feature/metadata-helpers` — New internal helper infrastructure (`core-metadata.R` top section)
- [ ] PR 3: `feature/metadata-setters` — Unified setter API + deprecations + `.extract_haven_metadata()` update
- [ ] PR 4: `feature/metadata-extractors` — Updated extractors + `extract_universe()`, `extract_missing_codes()`, `extract_metadata()`

---

## PR 1: S7 Class Properties + Error Catalog

**Branch:** `feature/metadata-s7-classes`
**Depends on:** none

### Files (TDD order — tests first)

- `plans/error-messages.md` — Add all new error/warning classes from spec Section IX
- `tests/testthat/test-s7-classes.R` — New test blocks for `universe` and `missing_codes`
- `R/core-classes.R` — Add `universe` and `missing_codes` properties to `survey_metadata`
- `changelog/metadata-update/feature-metadata-s7-classes.md` — Changelog entry for this PR

### Tasks

**Step 1.1:** Update `plans/error-messages.md` before any code.
Add rows for the following classes (spec Section IX). Use the class names and
message templates exactly as specified:
- `surveycore_error_not_survey_or_df` (M-1, already row 78 — verify it exists; if yes, no change needed)
- `surveycore_warning_var_not_found` (M-2, M-7 — check if already exists; add if missing)
- `surveycore_error_setter_ambiguous` (M-3)
- `surveycore_error_setter_empty` (M-4)
- `surveycore_error_setter_mismatched_lengths` (M-5)
- `surveycore_error_format_invalid` (M-6)
- `surveycore_error_labels_unnamed` (M-8, already exists — verify row number)
- `surveycore_warning_missing_labels` (M-9, already exists — verify row number)
- `surveycore_error_missing_codes_not_vector` (M-10)
- `surveycore_error_old_positional_setter` (M-11)
- `surveycore_error_setter_mixed_dots` (M-12)
- `surveycore_error_label_not_scalar` (M-13)
- `surveycore_warning_setter_empty_variables` (M-14)
- `surveycore_error_fill_invalid` (M-15)

**Step 1.2:** Write failing tests in `tests/testthat/test-s7-classes.R`:
```
test_that("survey_metadata() stores universe as empty list by default")
test_that("survey_metadata() stores missing_codes as empty list by default")
test_that("survey_metadata(universe = list(...)) stores value correctly")
test_that("survey_metadata(missing_codes = list(...)) stores value correctly")
test_that("universe @ assignment round-trips on survey_metadata object")
test_that("missing_codes @ assignment round-trips on survey_metadata object")
```

**Step 1.3:** Run `devtools::test(filter = "s7-classes")` → confirm all 6 new blocks fail
(properties do not yet exist).

**Step 1.4:** Add two properties to `survey_metadata` in `R/core-classes.R`:

```r
universe = S7::new_property(
  S7::class_list,
  default = quote(list())
),
missing_codes = S7::new_property(
  S7::class_list,
  default = quote(list())
)
```

Add corresponding `@param universe` and `@param missing_codes` entries to the
`survey_metadata` roxygen block. The `@param` style matches existing entries.

**Step 1.5:** Run `devtools::test(filter = "s7-classes")` → confirm all 6 new blocks pass.

**Step 1.6:** Run `devtools::document()` → confirm NAMESPACE and `man/survey_metadata.Rd`
regenerated without errors.

**Step 1.7:** Run `devtools::check()` → must pass 0 errors, 0 warnings, ≤ 2 notes.

### Acceptance criteria

- [ ] `plans/error-messages.md` contains rows for all 15 error/warning classes in spec Section IX
- [ ] All 6 new S7 class test blocks pass
- [ ] `survey_metadata()` creates objects with `universe` and `missing_codes` properties (both `list()` by default)
- [ ] `air::format_package()` — no diffs
- [ ] `lintr::lint_package()` — 0 lints
- [ ] `devtools::check()` 0/0/≤2
- [ ] `devtools::document()` run; NAMESPACE and `man/survey_metadata.Rd` in sync
- [ ] `covr::package_coverage()` ≥ 98%
- [ ] Changelog entry written and committed on this branch

**Notes:**
- Do NOT change any function in `core-metadata.R` during this PR. The S7 property
  addition is the only code change.
- Layer 1 (S7 validator) test pattern: `class=` only, no snapshot (per testing-surveycore.md).

---

## PR 2: Internal Helper Infrastructure

**Branch:** `feature/metadata-helpers`
**Depends on:** PR 1

### Files (TDD order — tests first)

- `tests/testthat/test-metadata-system.R` — Direct unit tests for `.check_is_survey_or_df()` and `.parse_setter_input()`
- `R/core-metadata.R` — New internal helpers added at the top of the file (before existing functions)
- `changelog/metadata-update/feature-metadata-helpers.md` — Changelog entry for this PR

### Tasks

**Step 2.1:** Write failing tests for `.check_is_survey_or_df()` in `test-metadata-system.R`.
Add a labeled section `# ── .check_is_survey_or_df() ────` with blocks:
```
test_that(".check_is_survey_or_df() returns invisibly NULL for a survey_taylor object")
test_that(".check_is_survey_or_df() returns invisibly NULL for a plain data.frame")
test_that(".check_is_survey_or_df() errors with surveycore_error_not_survey_or_df for list input")
test_that(".check_is_survey_or_df() errors with surveycore_error_not_survey_or_df for character input")
test_that(".check_is_survey_or_df() error snapshot for list input")
```

**Step 2.2:** Write failing tests for `.parse_setter_input()` in `test-metadata-system.R`.
Add a labeled section `# ── .parse_setter_input() ────` with blocks:
```
test_that(".parse_setter_input() convention 1 (named ...) returns correct named list")
test_that(".parse_setter_input() convention 1 with !!! splicing returns correct named list")
test_that(".parse_setter_input() convention 2 scalar (single named char vector) returns correct named list")
test_that(".parse_setter_input() convention 2 vector (single named list) returns correct named list")
test_that(".parse_setter_input() convention 3 (variable + content) returns correct named list")
test_that(".parse_setter_input() convention 3 length mismatch errors with surveycore_error_setter_mismatched_lengths")
test_that(".parse_setter_input() both ... and variable errors with surveycore_error_setter_ambiguous")
test_that(".parse_setter_input() neither ... nor variable errors with surveycore_error_setter_empty")
test_that(".parse_setter_input() unnamed ... elements errors with surveycore_error_setter_mixed_dots")
test_that(".parse_setter_input() NULL values pass through in returned list")
test_that("snapshot: surveycore_error_setter_mismatched_lengths message")
test_that("snapshot: surveycore_error_setter_ambiguous message")
test_that("snapshot: surveycore_error_setter_empty message")
test_that("snapshot: surveycore_error_setter_mixed_dots message")
```

Add a `# ── .resolve_vars() ────` section with blocks:
```
test_that(".resolve_vars() with empty var_exprs returns all column names")
test_that(".resolve_vars() with specified names returns just those names")
test_that(".resolve_vars() warns with surveycore_warning_var_not_found for missing var")
test_that(".resolve_vars() returns only valid names after warning")
test_that("snapshot: .resolve_vars() surveycore_warning_var_not_found message")
```

Add a `# ── .format_scalar_result() ────` section with blocks:
```
test_that(".format_scalar_result() format = 'named_vector' returns named character vector")
test_that(".format_scalar_result() format = 'list' returns named list")
test_that(".format_scalar_result() format = 'data_frame' returns tibble with variable/label columns")
test_that(".format_scalar_result() fill = NULL omits entries with NULL values")
test_that(".format_scalar_result() fill = NA_character_ includes entries with NA")
```

Add a `# ── .format_list_result() ────` section with blocks:
```
test_that(".format_list_result() format = 'list' returns named list")
test_that(".format_list_result() format = 'data_frame' returns long tibble")
test_that(".format_list_result() format = 'named_vector' errors with surveycore_error_format_invalid")
test_that("snapshot: .format_list_result() surveycore_error_format_invalid message")
```

**Step 2.3:** Run `devtools::test(filter = "metadata-system")` on just the new blocks
→ confirm all fail (helpers do not exist yet).

**Step 2.4:** Add the following internal helpers to the TOP of `R/core-metadata.R`
(before the existing `.check_is_survey()` function, which remains untouched until PR 3):

1. `.check_is_survey_or_df(x, call)` — type guard for survey + data.frame;
   errors with `surveycore_error_not_survey_or_df` (spec Section 3.2).

2. `.get_data_cols(x)` — returns `names(x)` for data frames, `names(x@data)` for
   survey objects (spec Section 3.2).

3. `.get_metadata(x)` — returns `x@metadata` for survey objects, `NULL` for data
   frames (spec Section 3.2).

4. `.parse_setter_input(dots, variable, content, content_arg_name, content_type, fn_name, call)`
   — shared setter convention detection (spec Section 3.2 and 4.1). Handles:
   - Convention 1: non-empty named list from `rlang::list2(...)`
   - Convention 2 scalar: single unnamed element that is a named character vector
     (when `content_type = "scalar"`)
   - Convention 2 vector: single unnamed element that is a named list
     (when `content_type = "vector"`)
   - Convention 3: `variable` non-NULL, `...` empty
   - Ambiguity: both `...` and `variable` provided → `surveycore_error_setter_ambiguous`
   - Empty: neither provided → `surveycore_error_setter_empty`
   - Unnamed/mixed elements → `surveycore_error_setter_mixed_dots`
   - Returns named list; `NULL` values allowed (signal key deletion in metadata)

5. `.resolve_vars(x, var_exprs, call)` — resolves `...` quosures for extractors.
   If `var_exprs` is empty (length 0), returns `.get_data_cols(x)`. Otherwise
   evaluates bare names / character vectors; issues `surveycore_warning_var_not_found`
   for missing names and returns only valid ones (spec Section 3.2).

6. `.format_scalar_result(result_list, format, col_name, empty_value)` — converts
   named list of character scalars into `"named_vector"`, `"list"`, or `"data_frame"`
   output (spec Section 3.2). Validates `format` against valid options.

7. `.format_list_result(result_list, format, fn_name)` — converts named list of
   vectors into `"list"` or `"data_frame"` output. `fn_name` used in
   `surveycore_error_format_invalid` message (spec Section 3.2).

**Step 2.5:** Run `devtools::test(filter = "metadata-system")` on all new blocks
→ confirm all pass.

**Step 2.6:** Run full `devtools::test()` → confirm existing tests still pass
(no regressions; old functions unchanged).

**Step 2.7:** Run `devtools::document()` + `devtools::check()` → 0/0/≤2.

### Acceptance criteria

- [ ] All `.check_is_survey_or_df()` test blocks pass (both happy paths + error class + snapshot)
- [ ] All `.parse_setter_input()` test blocks pass (conventions 1/2/3, all error classes, snapshots)
- [ ] All `.resolve_vars()` test blocks pass (empty → all cols, specified names, warning + skip, snapshot)
- [ ] All `.format_scalar_result()` test blocks pass (3 formats, fill = NULL, fill = NA_character_)
- [ ] All `.format_list_result()` test blocks pass (list, data_frame, named_vector error + snapshot)
- [ ] Existing `test-metadata-system.R` tests still pass (old functions untouched)
- [ ] `air::format_package()` — no diffs
- [ ] `lintr::lint_package()` — 0 lints
- [ ] `devtools::document()` run; NAMESPACE and `man/` unchanged (no new exports in this PR)
- [ ] `devtools::check()` 0/0/≤2
- [ ] `covr::package_coverage()` ≥ 98%
- [ ] All snapshot tests reviewed with `testthat::snapshot_review()` — no unreviewed diffs
- [ ] Changelog entry written and committed on this branch

**Notes:**
- `.parse_setter_input()` receives `dots` as an **evaluated list** (`rlang::list2(...)` at the caller),
  NOT quosures. The old-positional-form quosure check is the caller's responsibility (`set_var_label()`
  only — see PR 3).
- Test these helpers with direct calls (not through the public API). Use synthetic data from
  `make_survey_data()` to build a survey object for `.check_is_survey_or_df()` tests.
- Convention 2 scalar: `c(age = "Age in years")` — a named character vector.
- Convention 2 vector: `list(sex = c(Male = 1L, Female = 2L))` — a named list.
- `NULL` in returned list: `list(age = NULL)` means "delete key `age`" — each setter
  must handle this by doing `x@metadata@variable_labels[["age"]] <- NULL`.

---

## PR 3: Unified Setters + Deprecations

**Branch:** `feature/metadata-setters`
**Depends on:** PR 1, PR 2

### Files (TDD order — tests first)

- `tests/testthat/test-metadata-system.R` — Replace existing setter tests; add new
  convention/error/warning/data-frame test blocks; add `make_labeled_design()` helper
- `R/core-metadata.R` — Replace all setter functions; update `.extract_haven_metadata()`;
  remove `.check_is_survey()`
- `changelog/metadata-update/feature-metadata-setters.md` — Changelog entry for this PR

### Tasks

**Step 3.1:** Add `make_labeled_design()` helper at the top of `test-metadata-system.R`
(per spec Section 10.9):
```r
make_labeled_design <- function(seed = 42) {
  df  <- make_survey_data(n = 100, seed = seed)
  svy <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
  svy <- set_var_label(svy, y1 = "Outcome 1", y2 = "Outcome 2")
  svy <- set_val_labels(
    svy,
    strata = setNames(seq_len(5L), paste0("Stratum ", seq_len(5L)))
  )
  svy <- set_universe(svy, y1 = "All respondents")
  svy <- set_missing_codes(svy, y1 = c("Missing" = -1L))
  svy
}
```

Note: This helper uses the new unified setters. Write it now but it will only work
after the setters are implemented in Steps 3.4–3.11. Tests referencing it will fail
until the relevant setter is implemented.

Note: Data frame round-trip blocks (6 total) are intentionally placed in **PR 4 Step 4.1** —
they depend on the updated extractor return types only implemented in PR 4.

**Step 3.2a:** Write test blocks for `set_var_label()` in `test-metadata-system.R`.
Add a labeled section `# ── set_var_label() ────` with blocks:
```
test_that("set_var_label() convention 1 sets label for one variable")
test_that("set_var_label() convention 1 sets labels for multiple variables")
test_that("set_var_label() convention 1 with !!! splicing sets labels")
test_that("set_var_label() convention 2 (named char vector in ...) sets labels")
test_that("set_var_label() convention 3 (variable + label) sets labels")
test_that("set_var_label() returns x invisibly")
test_that("set_var_label() survives pipe chain of three calls")
test_that("set_var_label() NULL label deletes the existing entry")
test_that("set_var_label() data frame: sets attr(df$age, 'label')")
test_that("set_var_label() errors with surveycore_error_not_survey_or_df for list x")
test_that("set_var_label() errors with surveycore_error_setter_ambiguous")
test_that("set_var_label() errors with surveycore_error_setter_empty")
test_that("set_var_label() errors with surveycore_error_setter_mismatched_lengths")
test_that("set_var_label() errors with surveycore_error_old_positional_setter for old form")
test_that("set_var_label() errors with surveycore_error_label_not_scalar for non-character")
test_that("set_var_label() errors with surveycore_error_label_not_scalar for length > 1")
test_that("set_var_label() errors with surveycore_error_setter_mixed_dots for unnamed ...")
test_that("set_var_label() warns with surveycore_warning_var_not_found for missing variable")
test_that("set_var_label() skips missing var but still sets valid vars")
test_that("set_var_label() warns with surveycore_warning_setter_empty_variables for variable = character(0)")
test_that("snapshot: set_var_label() surveycore_error_not_survey_or_df")
test_that("snapshot: set_var_label() surveycore_error_setter_ambiguous")
test_that("snapshot: set_var_label() surveycore_error_setter_empty")
test_that("snapshot: set_var_label() surveycore_error_setter_mismatched_lengths")
test_that("snapshot: set_var_label() surveycore_error_old_positional_setter")
test_that("snapshot: set_var_label() surveycore_error_label_not_scalar")
test_that("snapshot: set_var_label() surveycore_warning_var_not_found")
test_that("snapshot: set_var_label() surveycore_warning_setter_empty_variables")
```

**Step 3.3:** Run `devtools::test(filter = "metadata-system")` on the `set_var_label()`
section → confirm all new blocks fail.

**Step 3.4:** Implement `set_var_label()` in `R/core-metadata.R`:
- New signature: `set_var_label(x, ..., variable = NULL, label = NULL)`
- `set_var_label()` ONLY: capture `...` as quosures via `rlang::enquos(...)` first;
  detect old positional form (exactly 2 `...`, first is unquoted symbol, second is
  scalar string with no name) → error `surveycore_error_old_positional_setter`
- After old-form check: evaluate `...` via `rlang::list2(...)`; call
  `.parse_setter_input(dots, variable, label, "label", "scalar", "set_var_label", call)`
- For each `var_name -> content` pair in result:
  - If survey object: check var in `.get_data_cols(x)`, warn + skip if missing
  - If `content` is not NULL: validate character scalar → error `surveycore_error_label_not_scalar`
  - Set `x@metadata@variable_labels[[var_name]] <- content` (NULL removes key)
  - If data frame: `attr(x[[var_name]], "label") <- content`
- Return `invisible(x)`
- Full roxygen2 block: `@param x`, `@param ...`, `@param variable`, `@param label`,
  `@return`, `@examples` (3 conventions), `@family metadata`, `@export`

**Step 3.5:** Run `devtools::test(filter = "metadata-system")` on `set_var_label()` blocks
→ confirm passing.

**Step 3.2b:** Write test blocks for `set_val_labels()`. Add a labeled section
`# ── set_val_labels() ────` with blocks (note the bare-vector exception for Conv. 3):
```
test_that("set_val_labels() convention 1 sets labels for one variable")
test_that("set_val_labels() convention 1 sets labels for multiple variables")
test_that("set_val_labels() convention 2 (single named list in ...) sets labels")
test_that("set_val_labels() convention 3 (variable + labels list) sets labels")
test_that("set_val_labels() convention 3 bare named vector accepted when length(variable) == 1")
test_that("set_val_labels() returns x invisibly")
test_that("set_val_labels() NULL value deletes the entry")
test_that("set_val_labels() data frame: sets attr(df$sex, 'labels')")
test_that("set_val_labels() errors with surveycore_error_labels_unnamed for unnamed vector")
test_that("set_val_labels() warns with surveycore_warning_missing_labels for partially labeled")
test_that("set_val_labels() warns with surveycore_warning_missing_labels on data frame")
test_that("set_val_labels() [error/warning snapshots as above]")
```
Run `devtools::test(filter = "metadata-system")` on new blocks → confirm fail.

**Step 3.6:** Implement `set_val_labels()`:
- New signature: `set_val_labels(x, ..., variable = NULL, labels = NULL)`
- Evaluate `...` via `rlang::list2(...)` (no old-form check needed)
- Call `.parse_setter_input(dots, variable, labels, "labels", "vector", "set_val_labels", call)`
- Convention 3 exception: if `length(variable) == 1L` and `labels` is a bare named
  vector (not a list), wrap in a list before passing to `.parse_setter_input()`
- For each pair: check var exists, validate named vector (`surveycore_error_labels_unnamed`),
  run `.validate_val_labels()` check for M-9, set metadata or attribute
- Survey objects: `x@metadata@value_labels[[var_name]] <- content`
- Data frames: `attr(x[[var_name]], "labels") <- content`
- The `.validate_val_labels()` check reads `x@data[[var]]` for survey objects,
  `x[[var]]` for data frames (per spec Issue 25 resolution)

**Step 3.7:** Run tests on `set_val_labels()` blocks → confirm passing.

**Step 3.2c:** Write test blocks for `set_question_preface()`. Add a labeled section
`# ── set_question_preface() ────` with analogous blocks covering conventions 1/2/3,
return invisibly, NULL deletion, data frame attribute setting, all applicable
error/warning classes (`content_type = "scalar"`).
Run `devtools::test(filter = "metadata-system")` on new blocks → confirm fail.

**Step 3.8:** Implement `set_question_preface()`:
- Signature: `set_question_preface(x, ..., variable = NULL, preface = NULL)`
- `content_type = "scalar"`, `content_arg_name = "preface"`
- Scalar validation per Section 4.1 unified rule (error `surveycore_error_label_not_scalar`)
- Survey: `x@metadata@question_prefaces[[var_name]] <- content`
- Data frame: `attr(x[[var_name]], "question_preface") <- content`

Run `devtools::test(filter = "metadata-system")` on `set_question_preface()` blocks
→ confirm passing.

**Step 3.2d:** Write test blocks for `set_var_note()`. Add a labeled section
`# ── set_var_note() ────` with analogous blocks (same pattern as `set_question_preface()`).
Run `devtools::test(filter = "metadata-system")` on new blocks → confirm fail.

**Step 3.9:** Implement `set_var_note()`:
- Signature: `set_var_note(x, ..., variable = NULL, note = NULL)`
- Same pattern as `set_question_preface()`
- Survey: `x@metadata@notes[[var_name]] <- content`
- Data frame: `attr(x[[var_name]], "note") <- content`

Run `devtools::test(filter = "metadata-system")` on `set_var_note()` blocks → confirm passing.

**Step 3.2e:** Write test blocks for `set_universe()`. Add a labeled section
`# ── set_universe() ────` with analogous blocks (same pattern as `set_var_note()`).
Run `devtools::test(filter = "metadata-system")` on new blocks → confirm fail.

**Step 3.10:** Implement `set_universe()` (new):
- Signature: `set_universe(x, ..., variable = NULL, universe = NULL)`
- Same pattern as `set_var_note()`
- Survey: `x@metadata@universe[[var_name]] <- content`
- Data frame: `attr(x[[var_name]], "universe") <- content`

Run `devtools::test(filter = "metadata-system")` on `set_universe()` blocks → confirm passing.

**Step 3.2f:** Write test blocks for `set_missing_codes()`. Add a labeled section
`# ── set_missing_codes() ────` with analogous blocks covering conventions 1/2/3,
Convention 3 bare-vector exception, `surveycore_error_missing_codes_not_vector`,
return invisibly, NULL deletion, data frame attribute setting.
Run `devtools::test(filter = "metadata-system")` on new blocks → confirm fail.

**Step 3.11:** Implement `set_missing_codes()` (new):
- Signature: `set_missing_codes(x, ..., variable = NULL, codes = NULL)`
- `content_type = "vector"`, `content_arg_name = "codes"`
- Convention 3 exception: same bare-vector exception as `set_val_labels()` when
  `length(variable) == 1L` — a bare atomic vector for `codes` is wrapped in a list
- Validation: each entry must be an atomic vector; list entries → `surveycore_error_missing_codes_not_vector`
- Survey: `x@metadata@missing_codes[[var_name]] <- content`
- Data frame: `attr(x[[var_name]], "missing_codes") <- content`

Run `devtools::test(filter = "metadata-system")` on `set_missing_codes()` blocks
→ confirm passing.

**Step 3.12:** Run `devtools::test(filter = "metadata-system")` on all setter blocks
→ confirm all pass. Also update existing test blocks that assert
`class = "surveycore_error_not_survey"`: change to
`class = "surveycore_error_not_survey_or_df"`.

**Step 3.2g:** Write 4 deleted-function confirmation test blocks in
`test-metadata-system.R`. Add a labeled section `# ── Removed plural setters ────`:
```
test_that("set_variable_labels() is removed — calling it errors with 'could not find function'")
test_that("set_value_labels() is removed — calling it errors with 'could not find function'")
test_that("set_question_prefaces() is removed — calling it errors with 'could not find function'")
test_that("set_variable_notes() is removed — calling it errors with 'could not find function'")
```
Run `devtools::test(filter = "metadata-system")` on these blocks → confirm fail
(the functions still exist at this point).

**Step 3.13:** Delete the four plural setter functions from `R/core-metadata.R`:
remove `set_variable_labels()`, `set_value_labels()`, `set_question_prefaces()`, and
`set_variable_notes()` entirely. The package is pre-1.0 and not on CRAN; a clean
breaking removal is preferred over deprecation wrappers. Remove the corresponding
`@export` tags (if any inline docs exist for these functions). `devtools::document()`
in Step 3.17 will update NAMESPACE automatically.

Run `devtools::test(filter = "metadata-system")` on the `# ── Removed plural setters ────`
section → confirm all 4 blocks now pass (functions are gone).

**Step 3.14:** Update `.extract_haven_metadata()` to also read `"note"`, `"universe"`,
and `"missing_codes"` column attributes. The updated function must:
- Read `attr(col, "note", exact = TRUE)` → store if non-NULL character scalar
- Read `attr(col, "universe", exact = TRUE)` → store if non-NULL character scalar
- Read `attr(col, "missing_codes", exact = TRUE)` → store if non-NULL atomic vector
- Pass all six fields to `survey_metadata()` constructor call at the end

**Step 3.15:** Conditionally remove `.check_is_survey()` from `R/core-metadata.R`:
1. Run `grep -r ".check_is_survey(" R/` to find all call sites.
2. If the only match is inside `core-metadata.R` itself (zero external callers): delete
   the function.
   If any external callers are found: leave `.check_is_survey()` in place and do not
   remove it.

**Step 3.16:** Run `devtools::test(filter = "metadata-system")` → all blocks pass.
Run `devtools::test()` (full suite) → no regressions.

**Step 3.17:** Run `devtools::document()` + `devtools::check()` → 0/0/≤2.

### Acceptance criteria

- [ ] All 6 unified setter functions work with conventions 1, 2, and 3
- [ ] Convention 2 detection distinguishes scalar vs. vector content correctly
- [ ] Old positional form `set_var_label(x, var, "label")` → `surveycore_error_old_positional_setter`
- [ ] All scalar-content setters → `surveycore_error_label_not_scalar` for non-char or length > 1
- [ ] `set_val_labels()` and `set_missing_codes()` Convention 3 bare-vector exception works
- [ ] All 6 setters work on both survey objects and data frames with correct attributes
- [ ] 4 plural setters (`set_variable_labels()`, `set_value_labels()`, `set_question_prefaces()`, `set_variable_notes()`) deleted; `grep -r "set_variable_labels\|set_value_labels\|set_question_prefaces\|set_variable_notes" R/` returns 0 results
- [ ] `.extract_haven_metadata()` reads all 6 field attributes
- [ ] `.check_is_survey()` removed if no external callers found (see Step 3.15)
- [ ] Existing test expectations updated from `surveycore_error_not_survey` to `surveycore_error_not_survey_or_df`
- [ ] `air::format_package()` — no diffs
- [ ] `lintr::lint_package()` — 0 lints
- [ ] `devtools::document()` run; NAMESPACE and `man/` updated for all 6 exported setter functions
- [ ] `devtools::check()` 0/0/≤2
- [ ] `covr::package_coverage()` ≥ 98%
- [ ] All snapshot tests reviewed with `testthat::snapshot_review()` — no unreviewed diffs
- [ ] Changelog entry written and committed on this branch

**Notes:**
- `variable = character(0)` (length-0 explicit arg) → `surveycore_warning_setter_empty_variables` + `invisible(x)`.
  This is distinct from omitting `variable` (which triggers `surveycore_error_setter_empty`).
- `NULL` content removes the metadata key (`x@metadata@variable_labels[["age"]] <- NULL` —
  this truly removes the key, not stores NULL). Verify with `"age" %in% names(...)`.
- `set_val_labels()` M-9 warning: compare `unique(var[!is.na(var)])` values against label codes.
  For data frames, `var = x[[var_name]]`; for survey objects, `var = x@data[[var_name]]`.
- The `.validate_val_labels()` internal helper already implements M-9 correctly — reuse it.
- `!!! splicing`: automatically supported because callers use `rlang::list2(...)`.
- For data frame setter behavior when `NULL` content (deletion): `attr(x[[var_name]], "label") <- NULL`
  removes the attribute. This is standard R behavior.
- The `make_labeled_design()` helper in `test-metadata-system.R` uses new unified setters —
  it will work correctly once Step 3.4–3.11 are complete.

---

## PR 4: Updated Extractors + `extract_metadata()`

**Branch:** `feature/metadata-extractors`
**Depends on:** PR 1, PR 2, PR 3

### Files (TDD order — tests first)

- `tests/testthat/test-metadata-system.R` — Replace existing extractor tests; add new
  format/fill/data-frame test blocks; add `extract_metadata()` tests
- `R/core-metadata.R` — Replace all 4 extractors; add `extract_universe()`,
  `extract_missing_codes()`, `extract_metadata()`
- `NEWS.md` — Add `### Breaking Changes` section (spec Section 8.3)
- `changelog/metadata-update/feature-metadata-extractors.md` — Changelog entry for this PR

### Tasks

**Step 4.1:** Write failing test blocks for all updated extractors in `test-metadata-system.R`.

For `extract_var_label()` (and parallel structure for `extract_question_preface()`,
`extract_var_note()`, `extract_universe()`):

```
test_that("extract_var_label() single variable returns named character vector (not scalar)")
test_that("extract_var_label() multiple variables returns named char vector with all names")
test_that("extract_var_label() no var arg returns metadata for all variables")
test_that("extract_var_label() no var arg returns empty char(0) when no labels set")
test_that("extract_var_label() format = 'named_vector' (default) returns named char vector")
test_that("extract_var_label() format = 'list' returns named list")
test_that("extract_var_label() format = 'data_frame' returns tibble with variable/label columns")
test_that("extract_var_label() format = 'data_frame' empty result: zero-row tibble with correct types")
test_that("extract_var_label() fill = NULL (default): unlabeled variables omitted")
test_that("extract_var_label() fill = NA_character_: unlabeled variables included with NA")
test_that("extract_var_label() fill = NA_character_ in 'list' format: NA_character_ list entry")
test_that("extract_var_label() mix: some labeled, some not — fill = NULL omits unset")
test_that("extract_var_label() data frame: reads attr(df[[var]], 'label')")
test_that("extract_var_label() data frame: returns same structure as for survey objects")
test_that("extract_var_label() errors with surveycore_error_not_survey_or_df for list x")
test_that("extract_var_label() errors with surveycore_error_format_invalid for invalid format")
test_that("extract_var_label() warns with surveycore_warning_var_not_found for missing var")
test_that("extract_var_label() result excludes missing var after warning")
test_that("extract_var_label() errors with surveycore_error_fill_invalid for fill = 'include'")
test_that("snapshot: extract_var_label() surveycore_error_format_invalid")
test_that("snapshot: extract_var_label() surveycore_warning_var_not_found")
```

For `extract_val_labels()` (format: `"list"`, `"data_frame"` only):
```
test_that("extract_val_labels() single variable returns named list (not bare named vector)")
test_that("extract_val_labels() format = 'list' (default) returns named list")
test_that("extract_val_labels() format = 'data_frame' returns long tibble with variable/label/value cols")
test_that("extract_val_labels() format = 'data_frame' coerces codes to character")
test_that("extract_val_labels() format = 'named_vector' errors with surveycore_error_format_invalid")
test_that("extract_val_labels() fill = NA_character_ in 'list' format: NULL entries (not NA)")
test_that("extract_val_labels() data frame: reads attr(df[[var]], 'labels')")
```

For `extract_missing_codes()`:
```
test_that("extract_missing_codes() single variable returns named list")
test_that("extract_missing_codes() format = 'list' (default): named list with named/unnamed codes preserved")
test_that("extract_missing_codes() format = 'data_frame': long tibble with variable/description/code cols")
test_that("extract_missing_codes() format = 'data_frame': description = NA when codes vector is unnamed")
test_that("extract_missing_codes() format = 'named_vector' errors")
test_that("extract_missing_codes() fill = NA_character_ in 'list' format: NULL entries")
test_that("extract_missing_codes() data frame: reads attr(df[[var]], 'missing_codes')")
```

Data frame round-trip blocks (6 total — one per field, moved here from PR 3 because they
depend on the updated named-vector return type implemented in this PR):
```
test_that("round-trip: set_var_label() on df -> as_survey() -> extract_var_label() matches")
test_that("round-trip: set_val_labels() on df -> as_survey() -> extract_val_labels() matches")
test_that("round-trip: set_question_preface() on df -> as_survey() -> extract_question_preface() matches")
test_that("round-trip: set_var_note() on df -> as_survey() -> extract_var_note() matches")
test_that("round-trip: set_universe() on df -> as_survey() -> extract_universe() matches")
test_that("round-trip: set_missing_codes() on df -> as_survey() -> extract_missing_codes() matches")
```

For `extract_metadata()`:
```
test_that("extract_metadata() single variable with all fields returns 7-key list")
test_that("extract_metadata() result keys are in spec order: variable_label, value_labels, question_preface, note, universe, missing_codes, transformations")
test_that("extract_metadata() does NOT include weighting_history in any entry")
test_that("extract_metadata() transformations is always list(), never NULL")
test_that("extract_metadata() fill = NULL (default): variable with at least one field included")
test_that("extract_metadata() fill = NULL: variable with no fields omitted")
test_that("extract_metadata() fill = 'include': variable with no fields included with all-NULL values")
test_that("extract_metadata() multiple variables, mixed metadata: fill = NULL returns only annotated")
test_that("extract_metadata() multiple variables: fill = 'include' returns all")
test_that("extract_metadata() no var arg: fill = NULL returns only annotated variables")
test_that("extract_metadata() no var arg: fill = 'include' returns all columns")
test_that("extract_metadata() all variables with no metadata + fill = NULL: returns list()")
test_that("extract_metadata() all variables with no metadata + fill = 'include': returns full-length list")
test_that("extract_metadata() single-column data frame with fill = 'include'")
test_that("extract_metadata() data frame: reads column attributes correctly")
test_that("extract_metadata() data frame: transformations = list() for all variables")
test_that("extract_metadata() errors with surveycore_error_not_survey_or_df for list x")
test_that("extract_metadata() warns with surveycore_warning_var_not_found; result skips missing var")
test_that("extract_metadata() errors with surveycore_error_fill_invalid for fill = NA_character_")
test_that("snapshot: extract_metadata() surveycore_error_not_survey_or_df")
test_that("snapshot: extract_metadata() surveycore_error_fill_invalid")
```

**Step 4.2:** Run `devtools::test(filter = "metadata-system")` on new blocks
→ confirm all fail (functions not yet updated).

**Step 4.3:** Implement updated `extract_var_label()`:
- New signature: `extract_var_label(x, ..., format = "named_vector", fill = NULL)`
- Validate `fill` against `c(NULL, NA_character_)` → `surveycore_error_fill_invalid`
  if any other value (e.g., `"include"`)
- Validate `format` against `c("named_vector", "list", "data_frame")` → `surveycore_error_format_invalid`
- Capture `...` as quosures via `rlang::enquos(...)`; call `.resolve_vars(x, var_exprs)`
  to get variable names (issues `surveycore_warning_var_not_found` for missing names)
- For survey objects: read from `x@metadata@variable_labels`
- For data frames: read `attr(x[[var_name]], "label", exact = TRUE)`
- Collect results into named list; apply `fill` filtering
- Call `.format_scalar_result(result_list, format, "label", fill)` to produce output
- Update roxygen2: `@param x`, `@param ...`, `@param format`, `@param fill`,
  `@return` (describes all 3 formats), `@examples` (3 format examples, omit/fill examples),
  `@family metadata`, `@export`

**Step 4.4:** Implement updated `extract_val_labels()`:
- New signature: `extract_val_labels(x, ..., format = "list", fill = NULL)`
- Valid formats: `"list"`, `"data_frame"` only (reject `"named_vector"` → M-6)
- For data frames: read `attr(x[[var_name]], "labels", exact = TRUE)`
- `fill = NA_character_` in `"list"` format: `NULL` entries (not `NA_character_`) for
  vector-content extractors (per spec Section 5.1 note)
- Use `.format_list_result(result_list, format, "extract_val_labels")`
- `"data_frame"` format: long tibble — columns `variable` (chr), `label` (chr), `value` (chr).
  Coerce codes to character for uniform typing. One row per label-code pair.

**Step 4.5:** Implement updated `extract_question_preface()`:
- Same pattern as `extract_var_label()`; reads `x@metadata@question_prefaces` or
  `attr(x[[var_name]], "question_preface", exact = TRUE)`
- `"data_frame"` columns: `variable` (chr), `preface` (chr)

**Step 4.6:** Implement updated `extract_var_note()`:
- Same pattern; reads `x@metadata@notes` or `attr(x[[var_name]], "note", exact = TRUE)`
- `"data_frame"` columns: `variable` (chr), `note` (chr)

**Step 4.7:** Implement `extract_universe()` (new):
- Same pattern as `extract_var_label()`; reads `x@metadata@universe` or
  `attr(x[[var_name]], "universe", exact = TRUE)`
- `"data_frame"` columns: `variable` (chr), `universe` (chr)
- Full roxygen2 block with `@examples`

**Step 4.8:** Implement `extract_missing_codes()` (new):
- Same pattern as `extract_val_labels()` (vector-content)
- Reads `x@metadata@missing_codes` or `attr(x[[var_name]], "missing_codes", exact = TRUE)`
- `"data_frame"` format: long tibble — columns `variable` (chr), `description` (chr,
  `NA` if codes vector is unnamed), `code` (chr — coerced from original type).
  One row per code value.
- Full roxygen2 block with `@examples`

**Step 4.9:** Implement `extract_metadata()` (new):
- Signature: `extract_metadata(x, ..., fill = NULL)`
- Valid `fill` values: `NULL` or `"include"` — anything else → `surveycore_error_fill_invalid`
  (including `NA_character_`, which individual extractors accept)
- No `format` argument — always returns a named list
- For each resolved variable name, build a 7-key named list:
  `variable_label`, `value_labels`, `question_preface`, `note`, `universe`,
  `missing_codes`, `transformations`
- For survey objects: read from `x@metadata@*` fields
- For data frames: read column attributes; `transformations = list()` always
- `fill = NULL` (default): omit variables where all six content fields are NULL
  AND `transformations = list()`
- `fill = "include"`: include all resolved variables regardless
- Key order must match spec Section 6.4 exactly
- Full roxygen2 block with `@examples` showing list output structure
- `@family metadata`, `@export`

**Step 4.10:** Run `devtools::test(filter = "metadata-system")` → all blocks pass.
Run `devtools::test()` (full suite) → no regressions.

**Step 4.11:** Run `devtools::document()` + `devtools::check()` → 0/0/≤2.

**Step 4.12:** Update `NEWS.md` — add a `### Breaking Changes` section and a
`### New Functions` section under the current development version heading.

`### Breaking Changes`:
1. Old positional setter form `set_var_label(svy, age, "label")` is removed; use `set_var_label(svy, age = "label")`.
2. `extract_var_label()`, `extract_question_preface()`, and `extract_var_note()` now return a named character vector (not a plain scalar) for single-variable calls.
3. `extract_val_labels()` now returns a named list (not a bare named vector).
4. `set_variable_labels()`, `set_value_labels()`, `set_question_prefaces()`, and `set_variable_notes()` have been removed. Use `set_var_label()`, `set_val_labels()`, `set_question_preface()`, and `set_var_note()` respectively.

`### New Functions`:
- `set_universe()` — set universe annotations for survey variables
- `set_missing_codes()` — set missing code vectors for survey variables
- `extract_universe()` — extract universe annotations for one or more variables
- `extract_missing_codes()` — extract missing code vectors for one or more variables
- `extract_metadata()` — summary function returning all metadata fields for one or more variables

**Step 4.13:** Run `covr::package_coverage()` → ≥ 98% line coverage.
Run `testthat::snapshot_review()` → approve all new snapshots (no unreviewed diffs).

### Acceptance criteria

- [ ] All updated extractors return named vectors (not scalars) for single-variable calls
- [ ] All extractors support `format = "named_vector"`, `"list"`, `"data_frame"` (scalar-content)
- [ ] `extract_val_labels()` and `extract_missing_codes()` reject `format = "named_vector"`
- [ ] `fill = NULL` omits variables with no metadata; `fill = NA_character_` includes with NA/NULL
- [ ] `fill = NA_character_` in `"list"` format: `NA_character_` for scalar fields, `NULL` for vector fields
- [ ] All extractors work on both survey objects and data frames
- [ ] `extract_universe()` and `extract_missing_codes()` fully implemented and exported
- [ ] `extract_metadata()` returns exactly 7 keys per variable in spec-specified order
- [ ] `extract_metadata()` never includes `weighting_history`
- [ ] `extract_metadata()` `fill = "include"` returns all variables; `fill = NA_character_` → error
- [ ] `air::format_package()` — no diffs
- [ ] `lintr::lint_package()` — 0 lints
- [ ] `devtools::document()` run; NAMESPACE and `man/` updated for all new exported functions
- [ ] `covr::package_coverage()` ≥ 98%
- [ ] All snapshot tests match (`testthat::snapshot_review()` before merge)
- [ ] `devtools::check()` 0/0/≤2
- [ ] `NEWS.md` includes `### Breaking Changes` entry (4 items: positional setter, extractor return types, val_labels return type, removed plural setters)
- [ ] Changelog entry written and committed on this branch

**Notes:**
- The breaking return-type changes from the old API (single-var calls now return named vectors,
  not scalars) are documented in spec Section 8.3 / NEWS.md. Do NOT add backward-compat shims.
- `fill` argument validation: check at the top of each function body with
  `match.arg(fill, choices = c("named_vector", "list", "data_frame"))` — wait, that's for format.
  For `fill`, use explicit checks: `if (!is.null(fill) && !identical(fill, NA_character_))`.
  For `extract_metadata()` use: `if (!is.null(fill) && !identical(fill, "include"))`.
- The `fill` check must be done BEFORE resolving variables.
- `"data_frame"` output uses `tibble::tibble()` — this is already in `Imports`.
- For the round-trip guarantee in spec Section 7.5 — the 6 round-trip test blocks are in
  PR 4 Step 4.1. They assert the new named-vector return types. Confirm all 6 pass after
  implementing the updated extractors.
- `extract_metadata()` entry order follows `names(x@data)` column order when `...` is omitted;
  follows order of `...` arguments when specified.

---

## Quality Gates (All PRs)

Before opening any PR:
- [ ] `devtools::document()` — no errors; NAMESPACE and man/ in sync
- [ ] `air::format_package()` — no diffs
- [ ] `lintr::lint_package()` — 0 lints
- [ ] `devtools::check()` — 0 errors, 0 warnings, ≤ 2 pre-approved notes
- [ ] Every new error class has `expect_error(class = "surveycore_error_...")` test
- [ ] Every new warning class has `expect_warning(class = "surveycore_warning_...")` test
- [ ] Snapshot tests reviewed with `testthat::snapshot_review()` (not auto-accepted)

---

> **Review the PR map carefully** — the scope of each PR is harder to change once
> implementation starts. In particular, confirm that PR 3 (setters) and PR 4 (extractors)
> are correctly separated — the extractors cannot be implemented before the helpers and
> setters because the round-trip tests depend on both. Run Stage 2 in a new session for
> an adversarial review of this plan before handing off to `/r-implement`.
