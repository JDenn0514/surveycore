# Implementation Plan: `survey_collection`

**ID:** survey-collection
**Spec:** `plans/spec-survey-collection.md` (v1.1, Approved — Stage 4 Pass 2 complete)
**Status:** Draft — pending Stage 2 adversarial review

---

## Overview

This plan delivers `survey_collection`, an S7 container that holds multiple
independent `survey_base` objects for comparative analysis, and wires the nine
tibble-returning `get_*()` functions to dispatch over collections. The work
splits into two PRs: the container class (S7 class, constructor, methods,
mutators) ships first as a standalone, inert data structure; the dispatch
surface (helper, pre-checks, per-function branches, `survey_glm()` /
`get_anova()` guards) ships second on top of it.

---

## PR Map

- [x] **PR 1** — `feature/survey-collection-class` — Add the `survey_collection`
  S7 class, `as_survey_collection()` constructor, `add_survey()` /
  `remove_survey()` mutators, `print` / `[[` / `length` / `names` methods,
  and the full test suite for the container (no estimation dispatch yet).
- [x] **PR 2a** — `chore/code-style-named-only-carve-out` — Append the
  "named-only control args go after `...`" carve-out to
  `.claude/rules/code-style.md §4` (spec §4.3). Tiny, reviewable in
  isolation; merges before PR 2 so the code-style rule is a merged
  precedent PR 2 can cite. **Already shipped in PR #96 (commit `76e8a34`,
  `feat(analysis)!: polymorphic object arg for get_anova()`); no separate
  PR needed.**
- [x] **PR 2** — `feature/survey-collection-dispatch` — Add
  `.dispatch_over_collection()`, `.warn_on_meta_divergence()`, pre-checks
  raising `surveycore_error_variable_not_found` in every `get_*()` listed in
  §4.2, the three-line dispatch branch plus `.id` / `.on_missing` params in
  each of those nine functions, and the `survey_glm()` / `get_anova()` C12
  guards.

Dispatch is locked as a single PR per spec §IX step 7 (mechanical template
applied nine times; one PR keeps reviewer overhead proportional to the
change).

---

## PR 1: `survey_collection` Container Class

**Branch:** `feature/survey-collection-class`
**Depends on:** none

### Files

Created:
- `R/survey-collection.R` — `add_survey()`, `remove_survey()`, the internal
  duplicate-name repair helper `.repair_collection_names()`, and (PR 2) the
  dispatch helpers. Created in this PR so PR 2 can append without
  reorganising file structure.
- `tests/testthat/test-survey-collection.R` — all collection-specific tests
  (constructor, mutators, validator, `[[` / `length` / `names`,
  heterogeneous schemas scaffolding).
- `changelog/survey-collection/pr-1-container-class.md` — written last.

Modified:
- `plans/error-messages.md` — append rows C1, C2, C2a, C3, C4, C8 from spec
  §VI (container-class error/warning classes).
- `R/core-classes.R` — add `survey_collection` class definition and validator
  (§3.1).
- `R/core-constructors.R` — add `as_survey_collection()` (§3.3).
- `R/methods-print.R` — add `print`, `[[`, `length`, `names` S7 methods
  (§3.5, §3.6).
- `tests/testthat/helper-test-data.R` — add `test_collection_invariants()`
  helper (§7.2.1).
- `tests/testthat/test-methods-print.R` — add `print.survey_collection`
  snapshot tests (small collection + length-25 abbreviation branch).
- `NAMESPACE` — regenerated via `devtools::document()`. Exports
  `as_survey_collection`, `add_survey`, `remove_survey`, `survey_collection`.

### Step-by-Step Tasks

#### Infrastructure

- [x] **Task 1.0** — Precondition check. Verify on the `develop` branch, and
  that `survey_base` is defined in `R/core-classes.R` (used by validator
  invariant 3). If either is wrong, stop.

- [x] **Task 1.1** — Append rows C1, C2, C2a, C3, C4, C8 to
  `plans/error-messages.md` verbatim from spec §VI. Preserve existing row
  numbering convention (append at the end of the Phase 1/2 section with
  a "survey_collection rows" subheader). Commit this change alone on the
  branch so the error table change is reviewable in isolation.

#### TDD Cycle A — S7 class + validator

- [x] **Task 2.1** — Create `tests/testthat/test-survey-collection.R`. Write
  the S7-validator test blocks (§7.1 Section 2). Layer 1 validator errors
  use `class=` only — no snapshot (per `testing-surveycore.md`).

  **Validator happy path:**
  - `survey_collection(surveys = list(a = d1, b = d2))` returns a valid
    object (constructed directly, not via `as_survey_collection()`).

  **Validator errors (`class=` only):**
  - Empty list → `surveycore_error_collection_empty`
  - Unnamed element (e.g., `list(d1, d2)`) →
    `surveycore_error_collection_empty` via the missing-names branch (spec
    §3.1 validator message "All surveys in the collection must be named"
    — needs its own class). **Check:** spec §VI row C1 lumps both into a
    single class. Follow the spec — the validator returns different
    message strings for "empty" vs "unnamed" but both carry
    `surveycore_error_collection_empty` per row C1's template text. Test
    assertion targets the class only.
  - Duplicate names via direct constructor bypass (`survey_collection(surveys
    = list(a = d1, a = d2))`) → `surveycore_error_collection_duplicate_name`
  - Non-`survey_base` element (e.g., `list(a = d1, b = data.frame(x = 1))`)
    → `surveycore_error_collection_bad_element`
  - Nested `survey_collection` (inner collection passed as an element) →
    `surveycore_error_collection_bad_element` (invariant 4 reduces to
    invariant 3 — §3.1 non-inheritance note)

- [x] **Task 2.2** — Run `devtools::test(filter = "survey-collection")`.
  Confirm the validator-error blocks all fail RED with "could not find
  function `survey_collection`". Record failing count.

- [x] **Task 3.1** — In `R/core-classes.R`, add `survey_collection` class
  per spec §3.1, but with the validator body implemented via
  `cli::cli_abort(..., class = "surveycore_error_...")` inside each
  branch instead of `return("...")`. Spec §3.1 pseudocode uses
  `return("...")` for illustration only — the real implementation needs
  typed error classes to satisfy §VI rows C1/C2/C4 (spec §VI requires
  `class=` on every row).

  Other surveycore S7 validators (`survey_taylor`, `survey_replicate`,
  `survey_twophase` in `R/core-classes.R`) already follow this
  `cli_abort()`-per-branch idiom — verified 2026-04-20 via Grep at lines
  225+, 398+, 542+. Match the existing pattern exactly.

  ```r
  survey_collection <- S7::new_class(
    "survey_collection",
    properties = list(surveys = S7::class_list),
    validator = function(self) {
      # empty → surveycore_error_collection_empty (C1)
      # unnamed / NA name / empty name → surveycore_error_collection_empty (C1)
      # duplicate names → surveycore_error_collection_duplicate_name (C2)
      # non-survey_base element → surveycore_error_collection_bad_element (C4)
    }
  )
  ```

  Branch-to-class mapping:
  - empty list (length 0) → `surveycore_error_collection_empty`
  - any name `is.null(nms) || "" %in% nms || NA %in% nms` →
    `surveycore_error_collection_empty` (spec §VI row C1 lumps both into
    a single class)
  - duplicate names → `surveycore_error_collection_duplicate_name`
  - any element fails `S7::S7_inherits(x, survey_base)` →
    `surveycore_error_collection_bad_element`

  **Do NOT** have `survey_collection` inherit from `survey_base` (§3.1
  non-inheritance note). This is what makes the nested-collection case
  fall out of invariant 3 automatically.

- [x] **Task 3.2** — Add `test_collection_invariants()` helper to
  `tests/testthat/helper-test-data.R` per spec §7.2.1 verbatim. Five
  invariants: (1) inherits `survey_collection`, (2) `@surveys` is list
  length ≥ 1, (3) fully named no-empty-no-NA-no-dup, (4) every element
  inherits `survey_base`, (5) collection itself does **not** inherit
  `survey_base`.

- [x] **Task 3.3** — Run `devtools::test(filter = "survey-collection")`.
  Confirm validator blocks pass GREEN.

#### TDD Cycle B — `as_survey_collection()` constructor

- [x] **Task 4.1** — Append constructor-test blocks to
  `test-survey-collection.R` (§7.1 Sections 1, 3, 10).

  Each `test_that()` block that builds a collection must call
  `test_collection_invariants(coll)` as its **first assertion**.

  **Happy path:**
  - Explicit names: `as_survey_collection("2017-18" = d1, "2019-20" = d2)`
    → names match, length 2
  - Bare-symbol auto-naming: `as_survey_collection(d_2017, d_2019)` →
    names `"d_2017"`, `"d_2019"`
  - Mixed named + bare: `as_survey_collection("wave1" = d1, d_2019)` →
    names `"wave1"`, `"d_2019"`
  - Mixed design types in one collection (taylor + replicate + srs) —
    accept; no warning (§V row 13)
  - Length-1 collection: `as_survey_collection("d" = d1)` — valid

  **Constructor errors (dual pattern — `class=` + snapshot):**
  - Unnamed non-symbol argument: `as_survey_collection(as_survey(df,
    weights = w))` → `surveycore_error_collection_unnamed_expr` (row C3)

  **Duplicate-name repair (dual pattern — warning):**
  - Duplicate names across args: `as_survey_collection(d1, d1)` → names
    repaired to `"d1"`, `"d1_1"`; warning
    `surveycore_warning_collection_duplicate_name_repaired` fires naming
    the mapping. Snapshot the warning CLI text.
  - Cascading repair: `as_survey_collection("x" = d1, "x" = d2, "x_1" = d3)`
    → repaired to `"x"`, `"x_1_1"`, `"x_1"` per §3.3.1 algorithm (the
    repair for the second `"x"` lands on `"x_1"` but that name is already
    taken by arg 3 → bumps to `"x_1_1"`). Snapshot to lock the algorithm.
  - Edge case: all names identical, three args: `("y" = d1, "y" = d2, "y"
    = d3)` → `"y"`, `"y_1"`, `"y_2"`; one warning.

- [x] **Task 4.2** — Run `devtools::test(filter = "survey-collection")`.
  Confirm constructor blocks fail RED.

- [x] **Task 5.1** — In `R/core-constructors.R`, add `as_survey_collection()`
  per spec §3.3. Implementation steps in order:
  1. Capture args with `rlang::enquos(...)`.
  2. Compute `caller_names` via `.resolve_caller_names(quosures)` (Task
     5.2b) — single source of truth for the named/bare-symbol/error
     logic. Row C3 is raised by the helper.
  3. Call `.repair_collection_names(caller_names)` (new helper in
     `R/survey-collection.R`, Task 5.2). If any renames occurred, emit
     `surveycore_warning_collection_duplicate_name_repaired` with the
     `original → repaired` mapping formatted as
     `{.code old1 → new1, old2 → new2}` (row C2a).
  4. Evaluate each quosure with `rlang::eval_tidy()`.
  5. Assemble a named list and construct `survey_collection(surveys =
     named_list)`. The S7 validator enforces invariants 3 and 4 (bad
     elements, nested collections).

  Add roxygen2 with `@export`, `@family collections`, `@param ...` using
  fuller treatment (it accepts named or bare-symbol args — call out the
  repair behavior), `@return A `survey_collection` object.`, and one
  `@examples` block using `gss_2024` (per CLAUDE.md).

- [x] **Task 5.2** — In `R/survey-collection.R`, create the file and add
  `.repair_collection_names(nms)` per spec §3.3.1 pseudocode verbatim.
  `@keywords internal`, `@noRd`. Returns a list with `repaired` (the new
  name vector) and `mapping` (named character of changes, or `character(0)`
  if no changes).

- [x] **Task 5.2b** — In the same file, add `.resolve_caller_names(quosures)`
  per spec §3.3 behavior step 2. For each quosure:
  1. If the caller supplied a name (non-empty, non-NA), use it.
  2. Else if the expression is a bare symbol
     (`rlang::quo_is_symbol(q)`), use
     `rlang::as_name(rlang::quo_get_expr(q))`.
  3. Else raise `surveycore_error_collection_unnamed_expr` naming the
     1-based position `i` of the offending argument.

  Returns a character vector of resolved names (same length as input).
  `@keywords internal`, `@noRd`. Both `as_survey_collection()` (Task 5.1
  step 2) and `add_survey()` (Task 9.1 step 2) call this helper instead
  of duplicating the logic. Centralising the error-class choice and the
  position-index formatting prevents drift between the two sites
  (engineering-preferences.md §1 — DRY).

- [x] **Task 5.3** — Run `devtools::test(filter = "survey-collection")`.
  All constructor happy-path and duplicate-repair blocks pass GREEN.
  Fix any failures before proceeding.

#### TDD Cycle C — Methods (`print`, `[[`, `length`, `names`)

- [x] **Task 6.1** — Append method-test blocks to `test-survey-collection.R`
  (§7.1 Section 1 — ergonomics) and to
  `tests/testthat/test-methods-print.R` (Section 11 — print snapshots).

  **Ergonomics (`test-survey-collection.R`):**
  - `length(coll)` returns integer scalar equal to element count
  - `names(coll)` returns the character vector of survey names
  - `coll[["wave1"]]` returns the underlying `survey_base` and
    `S7::S7_inherits(., survey_base)` is `TRUE`
  - `coll[[1L]]` returns the first survey (integer indexing)
  - `coll[["nonexistent"]]` returns `NULL` (base R list semantics for
    character OOB — §3.6)
  - `coll[[99L]]` errors (base R list semantics for integer OOB —
    `expect_error(coll[[99L]])` without a class, since this is a base R
    condition, not a surveycore-typed one)

  **Print snapshots (`test-methods-print.R`):**
  - Small 3-survey collection: snapshot full body with header + 3 lines.
    Fixture uses three `make_survey_data()` seeds for distinct row counts
    so `format(..., big.mark = ",")` is exercised on values ≥ 1,000.
  - Length-25 collection: snapshot the abbreviation branch — first 10
    lines, single `  ... and {N} more` line, last 3 lines, header still
    shows full count. Fixture uses `replicate(25, make_survey_data(seed =
    ...))`.
  - Pluralisation: a length-1 collection snapshot to verify `"survey"`
    vs `"surveys"` rendering.

- [x] **Task 6.2** — Run the two test files. Confirm blocks fail RED.

- [x] **Task 7.1** — In `R/methods-print.R`, add method definitions per
  spec §3.5 and §3.6. Each with a `# Class defined in R/core-classes.R`
  pointer comment (code-style.md §2 — S7 method file organization):
  ```r
  S7::method(print, survey_collection) <- function(x, ...) { ... }
  S7::method(`[[`, survey_collection) <- function(x, i) x@surveys[[i]]
  S7::method(length, survey_collection) <- function(x) length(x@surveys)
  S7::method(names, survey_collection) <- function(x) names(x@surveys)
  ```

  The `[[` body is literally `x@surveys[[i]]` — base R list semantics
  give us the character-OOB-returns-NULL / integer-OOB-errors behavior
  for free (§3.6). Do not wrap it.

  `print.survey_collection()` body follows §3.5 formatting rules:
  - Header: `A survey_collection with {n} survey{?s}:` via cli
    pluralisation
  - Per-survey line: `  "{name}": {class_name}, {rows} rows, {vars} variables`
    with `format(..., big.mark = ",")` on rows/vars,
    `S7::class_name(s)[1]` for class (leaf, bare, no angle brackets)
  - Abbreviation: if `length(x) > 20`, print first 10 + `  ... and {N} more`
    + last 3; `N = length(x) - 13`. Else print all.
  - Return `invisible(x)` per code-style.md §4.

- [x] **Task 7.2** — Run `devtools::test(filter = "survey-collection|methods-print")`.
  Confirm method tests pass GREEN. Run `testthat::snapshot_review()` to
  accept the print snapshots if they are the expected format.

#### TDD Cycle D — `add_survey()` / `remove_survey()`

- [x] **Task 8.1** — Append mutator test blocks to `test-survey-collection.R`
  (§7.1 Section 1 — happy paths; Section 10 — errors and repair).

  **`add_survey()` happy paths:**
  - `add_survey(coll, "new" = d3)` → returns new collection with
    `names()` appending `"new"`; original collection unchanged
  - Bare-symbol auto-naming: `add_survey(coll, d3)` → appended as `"d3"`
  - Multiple additions in one call: `add_survey(coll, "a" = d3, "b" = d4)`

  **`add_survey()` duplicate-name repair (dual pattern):**
  - New name matches existing: `add_survey(coll_with_x, "x" = d3)` →
    appended as `"x_1"`; warning
    `surveycore_warning_collection_duplicate_name_repaired` fires
  - Existing names are never modified during repair (spec §3.7)

  **`remove_survey()` happy paths:**
  - `remove_survey(coll, "wave1")` → returns collection without `"wave1"`
  - Multiple: `remove_survey(coll, c("wave1", "wave2"))` → both removed

  **`remove_survey()` errors (dual pattern):**
  - Unknown name: `remove_survey(coll, "nope")` →
    `surveycore_error_collection_name_not_found` (row C8) naming
    available names
  - Removing all surveys: `remove_survey(coll, names(coll))` → validator
    fires `surveycore_error_collection_empty` (row C1) via
    `survey_collection(surveys = list())` on the reduced list

- [x] **Task 8.2** — Run tests. Confirm RED.

- [x] **Task 9.1** — Append `add_survey()` and `remove_survey()` to
  `R/survey-collection.R` per spec §3.7.

  `add_survey(x, ...)`:
  1. Validate `x` is a `survey_collection` (`S7::S7_inherits`).
  2. Capture `...` via `rlang::enquos()`; compute `new_caller_names` via
     `.resolve_caller_names(quosures)` (Task 5.2b — same helper used by
     `as_survey_collection()`, guaranteeing consistent naming and error
     behavior).
  3. Pass `c(names(x@surveys), new_caller_names)` through
     `.repair_collection_names()`. Only the tail (new names) may be
     renamed — the algorithm in §3.3.1 preserves the first occurrence,
     and existing names come first. Assert this with
     `stopifnot(identical(repaired[seq_along(x@surveys)], names(x@surveys)))`
     before proceeding.
  4. If any renames, warn `surveycore_warning_collection_duplicate_name_repaired`.
  5. Evaluate new quosures; build combined list; construct a new
     `survey_collection`. Validator re-runs.

  `remove_survey(x, name)`:
  1. Validate `x` is a `survey_collection`.
  2. `missing_names <- setdiff(name, names(x@surveys))` → if any, abort
     `surveycore_error_collection_name_not_found` listing missing + have.
  3. `new_list <- x@surveys[setdiff(names(x@surveys), name)]`.
  4. Construct `survey_collection(surveys = new_list)`. If empty, the
     validator catches it → `surveycore_error_collection_empty` (row C1,
     §V row 10).

  Both return visibly (not `invisible()`). Add roxygen2 with
  `@family collections`, fuller `@param` descriptions, runnable
  `@examples` using `gss_2024`.

  **No-arg behavior.** `add_survey(x)` with no `...` is a silent no-op:
  `rlang::enquos()` on an empty `...` returns `list()`, the name
  resolution no-ops, the combined list equals the original, and the
  validator re-runs and passes → returns a structurally identical copy
  of `x`. Document this explicitly in `@details` for `add_survey()`:
  *"Calling `add_survey(x)` with no additional surveys returns `x`
  unchanged; no error is raised."*

- [x] **Task 9.2** — Run tests. Confirm GREEN.

#### Final Checks (PR 1)

- [x] **Task 10.1** — Run `devtools::document()`. Verify `NAMESPACE` exports
  `survey_collection`, `as_survey_collection`, `add_survey`,
  `remove_survey`. Verify `man/` pages render with runnable examples.

- [x] **Task 10.2** — Run `devtools::check()`. Must pass with 0 errors, 0
  warnings, ≤ 2 pre-approved notes (global-variable note from NSE is
  universal; see `r-package-conventions.md`).

- [x] **Task 10.3** — Verify coverage via
  `covr::file_coverage("R/survey-collection.R", "tests/testthat/test-survey-collection.R")`.
  In PR 1, `R/survey-collection.R` contains only the three container
  helpers added by this PR (`.repair_collection_names()`,
  `.resolve_caller_names()`, `add_survey()`, `remove_survey()` — four
  helpers after Issue 10 resolution). Target: 98%+ on the file. Dispatch
  helpers are added in PR 2; they do not exist in this file yet.

- [x] **Task 10.4** — Write `changelog/survey-collection/pr-1-container-class.md`
  with **Date**, **Branch**, **Plan** pointer, **Changes** (bulleted:
  new S7 class + validator, constructor, four methods, two mutators,
  six new error/warning classes, test-invariant helper), **Files
  Modified**. Commit last.

### Acceptance Criteria (PR 1)

- [ ] Every `test_that()` block that builds a `survey_collection` calls
  `test_collection_invariants(coll)` as first assertion
- [ ] All new tests confirmed RED before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤ 2 pre-approved notes
- [ ] `devtools::document()` run; `NAMESPACE` and `man/` in sync
- [ ] Validator errors tested with `class=` only (Layer 1)
- [ ] Constructor + mutator errors tested with dual pattern (`class=` +
  `expect_snapshot(error = TRUE)`)
- [ ] Duplicate-name repair warnings tested with dual pattern
- [ ] Print snapshots cover small collection, length-25 abbreviation, and
  length-1 pluralisation
- [ ] `plans/error-messages.md` updated with rows C1, C2, C2a, C3, C4, C8
- [ ] Changelog entry written and committed

### Notes for the Implementor (PR 1)

**Validator aborts, not returns.** Spec §3.1 shows `return("message")`
pseudocode; the real implementation must use `cli::cli_abort(..., class =
"surveycore_error_...")` inside each branch so C1/C2/C4 carry their typed
classes. See `R/core-classes.R` for the existing pattern used by
`survey_taylor` / `survey_replicate` / `survey_twophase` validators.

**Non-inheritance is load-bearing.** `survey_collection` must not inherit
from `survey_base`. A future refactor that makes it inherit would silently
permit nested collections — the validator test block for invariant 4
(nested collection rejection) is the regression guard.

**`.repair_collection_names()` is shared between `as_survey_collection()`
and `add_survey()`.** Place it in `R/survey-collection.R` (lives alongside
the dispatch helper added in PR 2 — the feature-group file). Prefix with
`.`. Not exported.

**Invisible return policy.** Constructors, mutators, and extractors return
visibly. Only setters (`set_var_label()` family) use `invisible(x)`.
`add_survey()` / `remove_survey()` produce new objects — visible.

**Print method pluralisation.** Use cli's native pluralisation (`{?s}`)
rather than manual `ifelse(n == 1, ...)`. Matches the idiom in existing
`print.survey_*` methods.

**`[[` method body.** Exactly `function(x, i) x@surveys[[i]]` — base R
list semantics produce the intended NULL-on-missing-character /
error-on-missing-integer behavior. Do not normalise. The two `[[` test
cases (character + integer OOB) are the regression guard.

---

## PR 2: Collection Dispatch + Per-Function Branches

**Branch:** `feature/survey-collection-dispatch`
**Depends on:** PR 1 merged to `develop`

### Files

Created:
- `tests/testthat/test-survey-collection-dispatch.R` — dispatch-specific
  tests (happy paths, oracle tests, errors, `.on_missing` modes, `.meta`
  carry-over, divergence warning, NSE-arg forwarding oracle).
- `changelog/survey-collection/pr-2-dispatch.md` — written last.

Modified:
- `plans/error-messages.md` — append rows C5, C6, C7, C9, C10, C11, C12
  from spec §VI (dispatch and cross-function error/warning classes).
- `R/survey-collection.R` — append `.dispatch_over_collection()`,
  `.warn_on_meta_divergence()`.
- Each of the following `get_*()` source files (per spec §4.2):
  - `R/analysis-freqs.R` — `get_freqs()`: add pre-check + dispatch branch +
    `.id` / `.on_missing` params
  - `R/analysis-means.R` — `get_means()`: same
  - `R/analysis-totals.R` — `get_totals()`: same
  - `R/analysis-quantiles.R` — `get_quantiles()`: same
  - `R/analysis-ratios.R` — `get_ratios()`: same
  - `R/analysis-corr.R` — `get_corr()`: same
  - `R/analysis-diffs.R` — `get_diffs()`: same
  - `R/analysis-t-test.R` — `get_t_test()` **and** `get_pairwise()`: same
    (both functions co-live in this file; one edit per function, two edits
    total to the same file)
  (File names verified against `R/` on 2026-04-20. If a file has moved,
  re-verify via `Glob("R/analysis-*.R")` at Task 12.0 before editing.)
- `R/glm.R` — `survey_glm()`: add `survey_collection` early-check guard
  raising C12.
- `R/glm-anova.R` — `get_anova()`: add `survey_collection` early-check
  guard raising C12.
- `R/analysis-helpers.R` — add `.precheck_vars_present(design, var_names)`
  helper that raises `surveycore_error_variable_not_found` (C10) — reused
  by all nine `get_*()` pre-check sites; factored out so the wording and
  cause-wrapping are consistent across call sites.
- `.claude/rules/code-style.md` — shipped in PR 2a (see PR Map). PR 2
  depends on PR 2a being merged; no edit to code-style.md happens in
  this PR.
- `NAMESPACE` — regenerated via `devtools::document()`. No new exports
  from PR 2 (dispatch helpers are internal; the `.id` / `.on_missing`
  params are non-exported additions to existing exports).

### Step-by-Step Tasks

#### Infrastructure

- [ ] **Task 11.0** — Precondition check. Verify PR 1 is merged to
  `develop`: `survey_collection` class exists,
  `as_survey_collection` / `add_survey` / `remove_survey` are exported,
  `test_collection_invariants()` helper is in
  `tests/testthat/helper-test-data.R`. If any piece is missing, stop.

- [ ] **Task 11.1** — Append rows C5, C6, C7, C9, C10, C11, C12, C13, C14
  to `plans/error-messages.md` verbatim from spec §VI. Commit this change
  alone on the branch. Note that row C10
  (`surveycore_error_variable_not_found`) may shadow existing
  `vctrs_error_subscript_oob` behavior in every `get_*()`; document in
  the changelog that this is a surveycore-owned class and wraps the
  vctrs cause as `parent`.

- [ ] **Task 11.2** — *(Moved to PR 2a — see PR Map.)* Verify PR 2a
  (`chore/code-style-named-only-carve-out`) has merged into `develop`
  before starting PR 2 work. PR 2a adds the named-only-after-`...`
  carve-out to `.claude/rules/code-style.md §4`. If PR 2a is not yet
  merged, pause PR 2 and complete PR 2a first.

- [ ] **Task 11.3** — In `R/analysis-helpers.R`, add
  `.precheck_vars_present(design, var_names)`:
  ```r
  .precheck_vars_present <- function(design, var_names) {
    missing <- var_names[!var_names %in% names(design@data)]
    if (length(missing) == 0) return(invisible(TRUE))
    have <- names(design@data)
    cli::cli_abort(
      c(
        "x" = "Variable{?s} {.val {missing}} not found in survey data.",
        "i" = "Available: {.val {have}}."
      ),
      class = "surveycore_error_variable_not_found"
    )
  }
  ```
  cli `{?s}` pluralisation handles both single and multi-missing cases;
  the user sees every missing variable at once (no fix-and-retry per
  variable) when multiple NSE args resolve to absent columns.
  `@keywords internal`, `@noRd`.

  **Parent-cause wrapping — locked.** The pre-check runs **before**
  tidyselect would raise `vctrs_error_subscript_oob`, so there is no
  vctrs condition to wrap. `parent = NULL` is the only path in
  `.precheck_vars_present()`. Spec §VI row C10's "(wraps the underlying
  `vctrs_error_subscript_oob` as `parent`)" language is a remnant of the
  pre-pre-check design and will be edited in this PR (see Task 11.4
  below). Document in the changelog under **Behavioral Changes**.

- [ ] **Task 11.4** — *(Already applied in Stage 3, 2026-04-20.)* Spec
  §VI row C10 now reads `"(pre-check runs before tidyselect; parent =
  NULL)"` with `{?s}` pluralisation. Verify the row matches the
  pseudocode in Task 11.3 before opening PR 2.

#### TDD Cycle E — `.dispatch_over_collection()` happy paths + NSE forwarding

- [ ] **Task 12.0** — Run `Glob("R/analysis-*.R")` to confirm the nine
  target file paths. Record the exact filename for each of the nine
  `get_*()` functions so subsequent tasks reference them correctly.

- [ ] **Task 12.1** — Create `tests/testthat/test-survey-collection-dispatch.R`.
  Write the happy-path and oracle test blocks (§7.1 Section 4).

  **Per-function happy path (one block per function in §4.2 table):**
  - `get_freqs()`, `get_means()`, `get_totals()`, `get_quantiles()`,
    `get_ratios()`, `get_corr()`, `get_diffs()`, `get_t_test()`,
    `get_pairwise()` — each gets one test exercising a homogeneous
    3-survey collection. Assert: result is a tibble, `.survey` is the
    first column, `.survey` values match names of the collection, row
    count equals sum of per-survey row counts.

  **Custom `.id`:**
  - `get_freqs(coll, x, .id = "wave")` → first column is `wave`

  **`.meta` carry-over:**
  - `attr(out, ".meta")$collection$surveys` equals `names(coll)` for
    included surveys
  - `attr(out, ".meta")$collection$survey_classes` is named character
    vector with `S7::class_name()[1]` per survey
  - `attr(out, ".meta")$per_survey[[nm]]` preserves each survey's
    original `.meta` attr
  - Top-level `.meta` (non-`$collection`, non-`$per_survey` keys) equals
    the first survey's `.meta` for backward compatibility

  **Single-design ignores `.id` / `.on_missing`:**
  - `get_means(d1, y1, .id = "ignored", .on_missing = "skip")` — result
    shape identical to `get_means(d1, y1)`; both args silently ignored
    (one `test_that()` block per function is unnecessary — one
    representative test on `get_means()` covers the pass-through
    mechanism since it is shared).

  **Dispatch-identity oracle tests** (spec §7.1 Section 4 — regression
  against helper mutation):
  - For `get_means()`, `get_totals()`, `get_freqs()`: assert
    `get_fn(coll, ...)` equals
    `dplyr::bind_rows(lapply(names(coll), function(nm) get_fn(coll[[nm]], ...)), .id = ".survey")`
    up to column order; numeric columns compared at `tolerance = 1e-12`.

  **NSE-arg forwarding oracle tests** (spec §4.2 — regression against
  dropped `{{ }}` forwarding):
  - `get_means(coll, y1, group = grp)` — `group` populated
  - `get_ratios(coll, num, denom, group = grp)` — all three NSE args
    populated; swap `group` for absent and verify divergence from oracle
  - `get_diffs(coll, y, treats = t, group = g, covariates = c(age, sex))`
    — every NSE arg populated
  - `get_t_test(coll, y, by = grp)`, `get_pairwise(coll, y, by = grp)` —
    `by` populated

    Each oracle test compares dispatch output to the per-survey bind
    pattern; if a `{{ }}` forwarding line is dropped, per-survey calls
    would run with the NSE arg defaulted, producing different results
    and a RED test immediately.

- [ ] **Task 12.2** — Run `devtools::test(filter = "survey-collection-dispatch")`.
  Confirm RED.

- [ ] **Task 13.1** — Append `.dispatch_over_collection()` to
  `R/survey-collection.R` per spec §4.1 verbatim. Implement in order:
  0. Validate `.id`: `is.character(.id) && length(.id) == 1L &&
     !is.na(.id) && nchar(.id) > 0L`. If false, raise
     `surveycore_error_collection_invalid_id` (row C13) with template
     from spec §VI.
  1. `rlang::arg_match(.on_missing)`
  2. Per-survey loop with `tryCatch(fn(...), surveycore_error_variable_not_found
     = function(cnd) { ... })` branching on `.on_missing`
  3. Skipped-survey info message (row C9)
  4. All-skipped error (row C6)
  5. `.id` collision check against first result's colnames **before**
     attaching `.id` (row C7; verified by the decision log — check runs
     pre-assignment so it can actually fire)
  6. Attach `.id` to each result with `results[[nm]][[.id]] <- nm`
  7. Call `dplyr::bind_rows(results)` inside `tryCatch()` — catch
     `vctrs_error_incompatible_type` (and the broader `vctrs_error`
     umbrella as fallback) and re-raise as
     `surveycore_error_collection_bind_type_mismatch` (row C14) with
     `parent = cnd`. This keeps the error surface surveycore-owned
     rather than leaking vctrs internals. Reorder columns so `.id` is
     first.
  8. Build `new_meta` by **concatenating the first survey's `.meta`**
     with `list(per_survey = ..., collection = list(surveys =
     names(results), survey_classes = ...))`. Note: `$collection$surveys`
     uses `names(results)` (surveys that **contributed rows**) — not
     `names(collection@surveys)` — so skipped surveys are absent.
     `$per_survey` is keyed the same way (`names(results)`). The first
     survey whose meta is concatenated is `results[[1]]`'s source
     survey, which is the first **contributing** survey (never a
     skipped one). The first-survey concatenation preserves
     top-level keys (e.g., `design_type`, `n_respondents`) for backward
     compatibility with downstream consumers (`clean()`, `gt()`) that
     introspect `attr(result, ".meta")$<key>` directly. Additive keys
     `$per_survey` and `$collection` are new. Call
     `.warn_on_meta_divergence(per_survey_meta)` after the meta is
     attached.
  9. Restore S3 class from first result; return

- [ ] **Task 13.2** — Append `.warn_on_meta_divergence()` to
  `R/survey-collection.R` per spec §4.1.1. The closed set of
  `(slot, var, field)` triples:
  - `slot ∈ {"group", "x"}`
  - `var` = union of variable keys appearing under either slot across
    all surveys
  - `field ∈ {"value_labels", "variable_label", "question_preface"}`

  For each triple, collect values across surveys (treating absent keys
  as `NULL`); if more than one unique value under `identical()`, mark
  that `var` as divergent. If `length(per_survey_meta) <= 1` or no
  divergent vars, return invisibly.

  Emit `surveycore_warning_collection_meta_divergence` (row C11) with
  the sorted-unique divergent variable list.

  Roxygen `@details` documents the closed-set policy (spec §4.1.1).
  `@keywords internal`, `@noRd`.

- [ ] **Task 13.3** — Run `devtools::test(filter = "survey-collection-dispatch")`.
  **Happy paths and NSE-forwarding oracles remain RED** at this point:
  they call `get_*(coll, ...)`, which still routes through
  `.check_unsupported_class()` and errors with
  `surveycore_error_unsupported_class` because the per-function dispatch
  branches do not exist yet. The dispatch helper `.dispatch_over_collection()`
  is complete and unit-testable in isolation — confirm it loads without
  error (`devtools::load_all()` succeeds; no `devtools::check()` warnings)
  — but the end-to-end RED→GREEN transition for these tests happens at
  Task 14.6, after the per-function branches land. Proceed to Task 14.1.

#### TDD Cycle F — Per-function dispatch branches + pre-checks

- [ ] **Task 14.0** — For each of the nine target functions, record the
  current signature (argument names, defaults, order) so the dispatch
  branch insert preserves existing behavior. Use `Grep` on the function
  definition. The NSE-arg table from spec §4.2 is the target set to
  forward:

- [ ] **Task 14.0b** — **Signature adjustments.** Only `get_freqs()` has a
  mid-signature `...` today; `get_diffs()` has a trailing `...`; the other
  seven have **no `...` at all**. Spec §4.3 locks `.id` and `.on_missing`
  as named-only control args that go **after `...`**. Adjustments per
  function:

  | Function | Current `...` position | Action |
  |---|---|---|
  | `get_freqs()` | Mid (after `x`, before post-`...` control args) | Append `.id = ".survey", .on_missing = "error"` at the end of the current post-`...` control args (`group`, `names_to`, `values_to`, `variance`, `conf_level`, …). |
  | `get_means()` | None | Insert `...` immediately after the last existing arg; then append `.id = ".survey", .on_missing = "error"`. |
  | `get_totals()` | None | Same as `get_means()`. |
  | `get_quantiles()` | None | Same. |
  | `get_ratios()` | None | Same. |
  | `get_corr()` | None | Same. |
  | `get_t_test()` | None | Same. |
  | `get_pairwise()` | None | Same. |
  | `get_diffs()` | Trailing | Append `.id = ".survey", .on_missing = "error"` **after** the existing trailing `...` (preserving the `...` position). |

  For the seven functions that gain a `...`: the `...` is absorbed-and-
  ignored (standard tidyverse pattern). No existing callers break — `...`
  at the end of the signature accepts no positional args and any stray
  named args are silently dropped by R's argument matching.

  **Out of scope for this PR:** moving existing post-`...` convention
  adopters like `get_freqs()`'s `names_to` / `values_to` to a different
  position, or retrofitting pre-`...` control args (`variance`,
  `conf_level`) to post-`...` for cross-function consistency. That
  refactor (if desired) is its own PR against `code-style.md`.

  Record each function's **full new signature** in the task list before
  editing so the before/after is obvious during review.

  | Function | NSE args to forward via `{{ }}` |
  |---|---|
  | `get_freqs()` | `x`, `group` |
  | `get_means()` | `x`, `group` |
  | `get_totals()` | `x`, `group` |
  | `get_quantiles()` | `x`, `group` |
  | `get_ratios()` | `numerator`, `denominator`, `group` |
  | `get_corr()` | `x`, `group` |
  | `get_diffs()` | `x`, `treats`, `group`, `covariates` |
  | `get_t_test()` | `x`, `by`, `group` |
  | `get_pairwise()` | `x`, `by`, `group` |

- [ ] **Task 14.1** — Edit `R/analysis-freqs.R` — `get_freqs()`:
  1. Add `.id = ".survey"` and `.on_missing = "error"` after `...` in
     the signature.
  2. Insert the dispatch branch as the **literal first line of the
     function body** — above `.check_unsupported_class(design, "get_freqs")`
     and any other existing validation. `survey_collection` does not
     inherit `survey_base`, so if `.check_unsupported_class()` runs first
     it raises `surveycore_error_unsupported_class` and the dispatch
     branch is never reached. Template per spec §4.2:
     ```r
     if (S7::S7_inherits(design, survey_collection)) {
       return(.dispatch_over_collection(
         get_freqs, design,
         x = {{ x }}, group = {{ group }}, ...,
         .id = .id, .on_missing = .on_missing
       ))
     }
     ```
  3. After the existing tidy-select step (before `@data` subsetting),
     insert the pre-check: gather the resolved names for **every declared
     NSE argument** the function exposes (per the "Pre-check inputs"
     table below, mirroring spec §4.2 / §III.4), drop `NULL`s (args that
     default to `NULL` and the caller did not supply), and call
     `.precheck_vars_present(design, resolved_names)`.

  **Pre-check inputs (per-function — spec §III.4 / §4.2):**

  | Function | NSE args resolved into the pre-check vector |
  |---|---|
  | `get_freqs()` | `x`, `group` |
  | `get_means()` | `x`, `group` |
  | `get_totals()` | `x`, `group` |
  | `get_quantiles()` | `x`, `group` |
  | `get_ratios()` | `numerator`, `denominator`, `group` |
  | `get_corr()` | `x`, `group` |
  | `get_diffs()` | `x`, `treats`, `group`, `covariates` |
  | `get_t_test()` | `x`, `by`, `group` |
  | `get_pairwise()` | `x`, `by`, `group` |

  Rationale (spec §III.4): a survey that cannot supply every input the
  function requires cannot produce a comparable row. Under
  `.on_missing = "skip"` the whole survey is skipped; under `"error"`
  the specific missing variable is named.
  4. Add roxygen2 `@param` blocks for `.id` and `.on_missing` with the
     exact wording required by spec §4.3: *"Only used when the first
     argument is a `survey_collection`; silently ignored otherwise."*

- [ ] **Task 14.2** — Repeat Task 14.1 structure for each of the other
  eight functions (`get_means`, `get_totals`, `get_quantiles`,
  `get_ratios`, `get_corr`, `get_diffs`, `get_t_test`, `get_pairwise`),
  forwarding the NSE args from the §4.2 table. **Single commit for all
  nine function edits** (`feat(analysis): dispatch collections through
  get_*() entry points`) — spec §IX step 7 already locks the bundled
  PR, and the edits are a mechanical template. Staged commits would
  leave intermediate CI RED because the dispatch test file exercises
  all nine; one commit keeps CI GREEN at every visible point on the
  branch.

- [ ] **Task 14.3** — In `R/glm.R` (`survey_glm()`) and `R/glm-anova.R`
  (`get_anova()`), add the C12 early-check guard as the **literal first
  line of each function body** — above `.check_unsupported_class()` and
  any other existing validation. `survey_collection` deliberately does not
  inherit `survey_base` (spec §3.1 non-inheritance note), so
  `.check_unsupported_class()` would otherwise raise
  `surveycore_error_unsupported_class` before the C12 guard can fire. The
  guard must run before the generic type check:
  ```r
  if (S7::S7_inherits(design, survey_collection)) {
    cli::cli_abort(
      c(
        "x" = "{.fn {fn_name}} does not yet support {.cls survey_collection} inputs.",
        "i" = "Run {.fn {fn_name}} on each survey individually, or see {.topic survey_collection} for the current dispatch coverage."
      ),
      class = "surveycore_error_collection_not_supported_by_fn"
    )
  }
  ```
  where `fn_name` is bound locally (`"survey_glm"` or `"get_anova"`).

- [ ] **Task 14.4** — Run `devtools::document()`. Verify the nine `get_*()`
  man pages regenerate with the two new `@param` entries. No new
  `@export` tags added.

- [ ] **Task 14.5** — Append per-function dispatch and error tests to
  `test-survey-collection-dispatch.R` (§7.1 Section 5, 6, 7, 8, 9,
  11).

  **Error paths — dispatch (dual pattern):**
  - `surveycore_error_collection_missing_var` (C5): one survey missing
    the focal variable, default `.on_missing = "error"` →
    dispatched call aborts. Snapshot.
  - `surveycore_error_collection_all_skipped` (C6): all surveys missing
    variable, `.on_missing = "skip"` → aborts. Snapshot.
  - `surveycore_error_collection_id_collision` (C7):
    `get_means(coll, y1, .id = "mean")` → aborts with dedicated class.
    Snapshot.
  - `surveycore_error_collection_not_supported_by_fn` (C12):
    `survey_glm(coll, formula, ...)` → aborts. Snapshot. Same for
    `get_anova(coll)`.
  - `surveycore_error_collection_invalid_id` (C13): one
    `expect_error(class=)` assertion per invalid input —
    `.id = NULL`, `.id = ""`, `.id = NA_character_`, `.id = c("a", "b")`,
    `.id = 1L`. One snapshot of the error message (using `.id = NULL`)
    to lock the wording.
  - `surveycore_error_collection_bind_type_mismatch` (C14):
    construct two surveys whose `get_means()` outputs have the same
    column as different types (e.g., via a factor in one, character in
    the other). Dispatch must raise C14 with the vctrs error as
    `parent`. Dual pattern (`class=` + snapshot).
  - Every `get_*()` in §4.2 raises `surveycore_error_variable_not_found`
    (C10) when its tidy-selected variable is absent. Dual pattern for
    `get_means()` (snapshot); `class=` only for the other eight.

  **NSE-arg scope test** (§III.4, §4.2):
  - `get_means(coll, y1, group = grp_missing_in_s2, .on_missing = "skip")`
    — skips survey 2 only; the `.on_missing` pre-check covers every
    NSE arg, not just focal `x`. Confirms broadened scope.
  - Variant: `get_diffs(coll, y, treats = t, covariates = c(age,
    sex_missing_in_s2), .on_missing = "skip")` — skips survey 2 from
    a covariate miss (covariates participate).

  **Messages:**
  - `.on_missing = "skip"` with one survey missing variable emits
    `surveycore_message_collection_skipped_surveys` (C9, message class).
  - In the same `.on_missing = "skip"` test, assert
    `attr(out, ".meta")$collection$surveys` **excludes** the skipped
    survey name, and `attr(out, ".meta")$per_survey` has no entry keyed
    by the skipped survey — confirming the contributing-only scope from
    Task 13.1 step 8.

  **Length-1 collection edge:**
  - `get_means()` on length-1 collection — tibble with one `.survey`
    value; row count matches direct per-survey call.
  - `.on_missing = "skip"` + single survey missing variable →
    `surveycore_error_collection_all_skipped` (not a silent empty
    result).

  **Heterogeneous schemas:**
  - Two surveys with different column sets; `get_freqs()` on a shared
    var works; `bind_rows()` NA-fills extras if a result column is
    absent from one survey's output.

  **`.meta` carry-over + divergence:**
  - Happy path: identical `value_labels` / `variable_label` /
    `question_preface` across surveys → `attr(out, ".meta")$per_survey[[nm]]`
    populated for every survey; top-level `.meta` equals first survey's;
    **no** warning emitted.
  - Divergence: two surveys disagree on `value_labels` for focal var →
    `surveycore_warning_collection_meta_divergence` (C11, dual pattern —
    class + snapshot); `per_survey` still preserves each meta.
  - Absence-vs-presence: survey A has `$x$age$value_labels` populated,
    survey B does not have the key at all → counts as divergence
    (spec §4.1.1 absence-vs-presence policy). Dedicated test.
  - Closed-set: add a `$x$age$variable_note` (a key NOT in the closed
    set) that differs across surveys → no warning fires. Regression
    for the closed-set policy.

- [ ] **Task 14.6** — Run `devtools::test(filter = "survey-collection")`
  (both the container test file and the dispatch test file). Confirm
  all blocks pass GREEN. Fix any failures.

#### Final Checks (PR 2)

- [ ] **Task 15.1** — Run `devtools::document()`. Verify the nine `get_*()`
  man pages carry the new `@param .id` and `@param .on_missing`
  entries. Verify no new `@importFrom` tags anywhere.

- [ ] **Task 15.2** — Run `devtools::check()`. Must pass with 0 errors, 0
  warnings, ≤ 2 pre-approved notes. Pay attention to the examples —
  the existing `get_*()` `@examples` blocks must still run under the
  modified signature (adding two defaulted params after `...` does
  not break existing calls, but re-running check confirms it).

- [ ] **Task 15.3** — Verify coverage:
  - `covr::file_coverage("R/survey-collection.R", ...)` — 98%+ on the
    combined file (container + dispatch helpers together).
  - The three-line dispatch branch in each of the nine `get_*()` files
    is exercised by the per-function happy-path test; verify each
    branch line is covered.

- [ ] **Task 15.4** — Numerical invariance check: for each of
  `get_means()`, `get_totals()`, `get_freqs()`, assert the
  dispatch-identity oracle holds at `tolerance = 1e-12` (Task 12.1
  implements this). No new `tolerance = 1e-8 / 1e-10` oracles against
  `survey::` — the dispatch helper performs no numerics, it just
  row-binds. The existing per-function oracle tests in the respective
  `test-*.R` files already cover the single-design numerical path.

- [ ] **Task 15.5** — Write `changelog/survey-collection/pr-2-dispatch.md`.
  Sections: **Date**, **Branch**, **Plan**, **Changes** (dispatch
  helper, divergence helper, nine `get_*()` pre-checks + branches +
  new params, two C12 guards, seven new error/warning classes,
  code-style carve-out rule), **Files Modified**, **Behavioral
  Changes** (callout: `vctrs_error_subscript_oob` from tidy-select on
  missing variables is now wrapped as surveycore-owned
  `surveycore_error_variable_not_found`; downstream code that catches
  the vctrs class must update). Commit last.

### Acceptance Criteria (PR 2)

- [ ] PR 1 merged to `develop` before PR 2 branch cut
- [ ] All new tests confirmed RED before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤ 2 pre-approved notes
- [ ] `devtools::document()` run; `NAMESPACE` and `man/` in sync
- [ ] Every `get_*()` in §4.2 dispatches correctly on a collection
  (per-function happy-path test GREEN)
- [ ] Dispatch-identity oracle holds at `1e-12` for `get_means()`,
  `get_totals()`, `get_freqs()`
- [ ] NSE-arg forwarding oracle GREEN for all nine functions (catches
  dropped `{{ }}` regression)
- [ ] `.on_missing` pre-check scope covers every named NSE arg (not just
  focal `x`) — regression test GREEN
- [ ] `.id` collision check fires (runs before `.id` assignment — spec
  decision A resolution)
- [ ] `.meta` carry-over: `collection$surveys`, `collection$survey_classes`,
  `per_survey[[nm]]`, top-level from first survey — all test-covered
- [ ] Divergence warning fires on value_labels / variable_label /
  question_preface differences; does NOT fire on closed-set non-members
- [ ] Absence-vs-presence policy: divergence fires when survey A has a
  key populated and survey B does not
- [ ] `survey_glm()` / `get_anova()` on a collection raise C12 with the
  deferral message
- [ ] All seven new error/warning classes (C5, C6, C7, C9, C10, C11,
  C12) have typed tests; dual pattern where required by spec §7.1
- [ ] `plans/error-messages.md` updated with rows C5, C6, C7, C9, C10,
  C11, C12
- [ ] `.claude/rules/code-style.md` updated with named-only-control-args
  carve-out
- [ ] Changelog entry written (including the C10 behavioral-change
  callout) and committed

### Notes for the Implementor (PR 2)

**`.id` collision check order is load-bearing.** Run the check against
`names(results[[1]])` **before** attaching `.id` to any result (spec
§4.1 comment block, decisions-survey-collection.md resolution A). If
the check runs after assignment, `.id` is always in the colnames and
the check can never fire. The C7 error-path test is the regression
guard.

**Pre-check covers every NSE arg, not just `x`.** Spec §III.4 resolution:
the pre-check passes every NSE arg that resolves to a variable name
into `.precheck_vars_present()`. For `get_diffs()` that means `x`,
`treats`, `group`, `covariates` — a survey missing any one is skipped
under `"skip"` or errors under `"error"`. The Task 14.5 NSE-arg scope
test (`grp_missing_in_s2`) is the regression.

**`vctrs_error_subscript_oob` shadowing.** The pre-check runs before
tidyselect would raise the vctrs condition, so the vctrs error is
short-circuited. This is intentional (spec §III.4 — "pre-check the
tidy-select resolution against `names(design@data)`"). Downstream
code that `tryCatch`ed on `vctrs_error_subscript_oob` from within
`get_*()` callsites will now see `surveycore_error_variable_not_found`
instead. Document in the changelog as a behavioral change; surface in
Stage 2 review whether a `parent = cnd` wrap is still needed despite
the short-circuit (the spec's wording implies yes; the implementation
produces `parent = NULL`).

**Dispatch branch forwarding via `{{ }}`.** Every named NSE formal
declared by a function must be forwarded with `{{ arg }}` — relying on
`...` is insufficient because named formals are bound to the
function's own parameter name and are NOT present in `...`. The
NSE-arg forwarding oracle (Task 12.1) is the regression: a
`get_means(coll, y1, group = grp)` call that drops `group = {{ group
}}` forwarding would run per-survey with `group = NULL` and fail the
oracle immediately.

**S7 dispatch is by the first positional arg.** The dispatch helper
passes each `survey_base` through as `fn(collection@surveys[[nm]],
...)`. The argument name on each function's first parameter is
irrelevant (most are `design`, but the helper positionally binds) —
do not rename any `get_*()` first argument during this PR.

**Dispatch branch placement.** Insert **before** any existing
validation, including tidy-select resolution. The branch short-circuits
on collections; the rest of the function body assumes a `survey_base`
first argument (which is what the spec locks). If existing validation
runs first, the `survey_collection` gets type-checked against
`survey_base` and errors out incorrectly.

**Meta divergence closed-set policy.** Only `value_labels`,
`variable_label`, `question_preface` are compared. `variable_note` and
user-added keys are NOT compared (spec §4.1.1). If a future spec change
adds a new correctness-critical field, update the helper explicitly —
this is documented in the helper's roxygen `@details`.

**`@keywords internal` + `@noRd` on helpers.** `.dispatch_over_collection()`
and `.warn_on_meta_divergence()` generate no `.Rd`. They are still
documented in the source via roxygen for grepability.

**`.meta` structure preservation.** The helper at step 8 builds
`new_meta` by **concatenating** the first survey's `.meta` with
`list(per_survey = ..., collection = ...)`. This preserves the first
survey's top-level keys (e.g., `design_type`, `n_respondents`) for
backward compatibility with downstream consumers (`clean()`, `gt()`
helpers) that introspect `attr(result, ".meta")$design_type` directly.
The `per_survey` and `collection` keys are additive.

**Code-style rule ships with the code.** The carve-out for named-only
control args after `...` is new — it is referenced by spec §4.3. Update
the rule in the same PR (committed separately as a `chore(rules)`
commit) so the rule change is reviewable and the code can cite it.

---

## Summary

Two PRs: container class first (inert but fully tested), dispatch surface
second (with per-function pre-checks, branches, and `survey_glm` /
`get_anova` guards). The dispatch PR is the mechanical locked bundle per
spec §IX step 7 — ~27 lines of dispatch template plus the corresponding
pre-check sites and tests. No deviation from the spec's locked decisions.
