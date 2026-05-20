# Implementation plan — collection-id-if-missing-var

## Overview

The spec promotes `.id` and `.if_missing_var` (renamed from `.on_missing`) from
per-call dispatcher arguments to first-class properties on `survey_collection`,
adds two exported setters, fixes a silent no-op in `as_survey_collection()`,
and renames `.on_missing` → `.if_missing_var` across the analysis layer. The
work splits into two PRs whose write surfaces are disjoint (modulo `NAMESPACE`
/ `NEWS.md` regenerated artifacts) so reviewers can evaluate the design change
and the wide rename independently:

- **PR 1** introduces all the new state and contracts: class properties,
  validators, validator helpers, constructor wiring, dispatcher precedence
  resolution, two new setters, print-method rendering, and
  `add_survey()`/`remove_survey()` preservation. It is self-contained — the
  10 analysis source files keep their existing `.on_missing` argument name in
  PR 1 and forward it through to the dispatcher's new `.if_missing_var`
  parameter via a one-line bridge per file (`.if_missing_var = .on_missing`).
- **PR 2** is purely the wide rename: the 11 analysis functions across 10
  source files flip `.on_missing` → `.if_missing_var` at the signature level,
  flip the defaults to `NULL`, and refresh every snapshot pinned to the old
  name.

PR 2 must merge after PR 1 because PR 2 removes the `.if_missing_var =
.on_missing` bridge introduced in PR 1 once the analysis-function signatures
catch up to the dispatcher's new parameter name. The two PRs share `NAMESPACE`
and `NEWS.md` only; everything else is disjoint.

## PR map

- [x] PR 1: `feature/collection-id-if-missing-var-class` — Class properties,
      validator helpers, constructor wiring, dispatcher precedence, two new
      setters, print-method rendering, preservation across mutators.
      Merged as #111 (commit `9a272b8`).
- [x] PR 2: `feature/collection-if-missing-var-rename` — Wide rename of
      `.on_missing` → `.if_missing_var` across 11 analysis functions and
      every pinned snapshot.
      Merged as #112 (commit `a616549`).

---

## PR 1 — `feature/collection-id-if-missing-var-class`

**Goal**: Add `@id` and `@if_missing_var` properties (with validators) to the
`survey_collection` S7 class, wire `as_survey_collection()` to set them,
implement two-tier precedence resolution in `.dispatch_over_collection()`, add
exported `set_collection_id()` / `set_collection_if_missing_var()` setters,
preserve both properties through `add_survey()` / `remove_survey()`, render
both lines in the `survey_collection` print method, and update the dispatcher
hint text to reference the new setter.

### Tasks (TDD order)

#### Pre-flight

1. Confirm `plans/error-messages.md` already contains the C15 row for
   `surveycore_error_collection_invalid_if_missing_var` adjacent to the
   existing C13 (`surveycore_error_collection_invalid_id`) row, with the
   cli template specified in spec §New error class. Do **not** modify
   `plans/error-messages.md` in this PR — it is a pre-flight gate only.
   If C15 is missing, HOLD and stop.

#### Validator helpers (TDD)

2. Write failing test: `.validate_collection_id(NA_character_, "id")` raises
   `surveycore_error_collection_invalid_id`. Add to
   `tests/testthat/test-survey-collection.R` under a new `describe`-free block
   "validator helpers — id".
3. Write failing test: `.validate_collection_id("ok", "id")` returns
   `invisible("ok")` and is silent.
4. Implement `.validate_collection_id(value, arg_name)` in
   `R/survey-collection.R`. Body: length-1 + character + non-NA + nzchar
   gate; raise the existing class on failure. Verify tests pass.
5. Write failing test: `.validate_collection_if_missing_var("warn",
   "if_missing_var")` raises `surveycore_error_collection_invalid_if_missing_var`.
6. Write failing test: `.validate_collection_if_missing_var("skip",
   "if_missing_var")` returns `invisible("skip")`.
7. Implement `.validate_collection_if_missing_var(value, arg_name)` in
   `R/survey-collection.R`. Body: length-1 + character + non-NA + value in
   `c("error", "skip")` gate. Verify tests pass.
8. Write failing tests covering each of the 4 reject branches per helper
   (NA, length 0, length > 1, wrong type for `id`; NA, not in set, length >
   1, wrong type for `if_missing_var`). Each branch gets one test
   exercising via the public API (the S7 validator) using `expect_error(class
   = ...)`. Verify all pass after implementing the helpers.

#### S7 class properties + validator (TDD)

9. Write failing test: `survey_collection(surveys = list(a = d))` (with `d`
   from `make_survey_data()`) returns an object whose `@id == ".survey"`
   and `@if_missing_var == "error"`. (`test_invariants(d)` is the first
   assertion.)
10. Write failing test: `survey_collection(surveys = list(a = d), id =
    "wave", if_missing_var = "skip")` round-trips both properties via
    `expect_identical()`.
11. Add `id` and `if_missing_var` properties to the `survey_collection` S7
    class definition in `R/core-classes.R`. Both `S7::class_character` with
    appropriate defaults.
12. Update the `survey_collection` S7 validator block in `R/core-classes.R`
    to call both helpers (id first, then if_missing_var) before the
    existing C1/C2/C4/G1/G1b/G1c block. Verify tests pass.
13. Write failing test: validator-ordering — construct with both `id =
    NA_character_` and `if_missing_var = "bogus"`. Assert the raised class
    is `surveycore_error_collection_invalid_id` (not the if_missing_var
    class). Verify it passes.

#### Constructor wiring (TDD)

14. Write failing tests for `as_survey_collection()` happy paths: defaults,
    explicit `.id = "wave"`, explicit `.if_missing_var = "skip"`, both
    explicit, mixed (one explicit + one default).
15. Write failing tests for `as_survey_collection()` error paths (Layer 3 —
    dual pattern: `expect_error(class = ...)` + `expect_snapshot(error =
    TRUE)`):
    - `.id = NA_character_`, `.id = c("a", "b")`, `.id = ""` →
      `surveycore_error_collection_invalid_id`.
    - `.if_missing_var = "warn"`, `.if_missing_var = NA_character_` →
      `surveycore_error_collection_invalid_if_missing_var`.
16. Write failing test: `as_survey_collection(d, .on_missing = "skip")`
    raises an "unused argument" error (class-free `expect_error()`),
    confirming the silent no-op argument is gone.
17. Update `as_survey_collection()` in `R/core-constructors.R`:
    - Replace `.on_missing` parameter with `.if_missing_var`. Default keeps
      `".error"` semantics — i.e., `.if_missing_var = "error"`.
    - Keep `.id = ".survey"`.
    - Validate both args via the helpers (passing `arg_name = ".id"` and
      `".if_missing_var"`).
    - Forward both to `survey_collection(...)`.
    - Replace the misleading "Stored on the collection for later
      consumption" roxygen with the precise prose in spec §`as_survey_collection()`.
    Verify tests pass.

#### Dispatcher precedence (TDD)

18. Write failing test: `get_means(coll, y1)` on a collection built with
    `.id = "wave"` (call without `.id`) produces a column named `"wave"`.
19. Write failing test: same collection, but call with `.id = "year"` —
    column is `"year"` (call-site wins).
20. Write failing test: `get_means(coll, y1)` on a collection built with
    `.if_missing_var = "skip"` (one inline-frame member missing the
    variable) succeeds and emits the
    `surveycore_message_collection_skipped_surveys` informational message.
21. Write failing test: same collection with `.if_missing_var = "skip"`
    stored, but call-site `.if_missing_var = "error"` raises
    `surveycore_error_collection_missing_var`.
22. Update `.dispatch_over_collection()` signature in `R/survey-collection.R`
    from `(.id = ".survey", .on_missing = c("error", "skip"))` to
    `(.id = NULL, .if_missing_var = NULL)`. Implement the two-tier
    resolution at function entry:
    ```
    resolved_id <- .id %||% collection@id
    resolved_if_missing_var <- .if_missing_var %||% collection@if_missing_var
    ```
    Validate both resolved values via the helpers. Replace every internal
    reference to `.id` / `.on_missing` with `resolved_id` /
    `resolved_if_missing_var`. Verify tests pass.
23. Update the cli `"v"` bullet on `surveycore_error_collection_id_collision`
    to mention `set_collection_id()` as an alternate fix path (verbatim
    text from spec §`.dispatch_over_collection()` edge cases). Update the
    `"v"` bullet on `surveycore_error_collection_missing_var` to read
    `Set {.code .if_missing_var = "skip"} ...`. Update affected snapshots.
    Run `testthat::snapshot_review()` on `_snaps/analysis-covariance.md`
    and `_snaps/analysis-variance-collection.md` after the cli hint text
    change; approve both diffs individually.
24. Bridge step (PR-1-only, removed in PR 2): in each of the 10 analysis
    source files (`analysis-means.R`, `analysis-totals.R`,
    `analysis-freqs.R`, `analysis-ratios.R`, `analysis-diffs.R`,
    `analysis-corr.R`, `analysis-variance.R`, `analysis-quantiles.R`,
    `analysis-covariance.R`, `analysis-t-test.R`), the dispatch-branch
    forwarding line that today calls
    `.dispatch_over_collection(fn, design, ..., .id = .id, .on_missing =
    .on_missing)` becomes
    `.dispatch_over_collection(fn, design, ..., .id = .id, .if_missing_var
    = .on_missing)`. The function signatures stay at `.on_missing = "error"`
    in PR 1; only the inner call site renames the named-argument key. This
    is the only edit each analysis file receives in PR 1.

    NOTE: this is the **only** edit to the analysis files in PR 1. No
    signature change, no roxygen change, no test or snapshot update for
    those files in PR 1.

#### Setters (TDD)

25. Write failing tests for `set_collection_id()` happy path:
    `withVisible(set_collection_id(coll, "wave"))$visible == FALSE`;
    `r$value@id == "wave"`; other properties unchanged. Idempotence:
    `set_collection_id(coll, coll@id)` returns equivalent object.
26. Write failing tests for `set_collection_id()` error paths (dual
    pattern):
    - `coll = list()` (not a collection) →
      `surveycore_error_not_survey_collection`.
    - `id = NA_character_` / `c("a", "b")` / `""` / `1L` →
      `surveycore_error_collection_invalid_id`.
27. Implement `set_collection_id(x, id)` in `R/survey-collection.R`:
    - First check `S7::S7_inherits(x, survey_collection)` (class object,
      not string). Raise `surveycore_error_not_survey_collection` on
      failure.
    - Call `.validate_collection_id(id, "id")`.
    - Set `x@id <- id`, return `invisible(x)`.
    Add `@export` and `@family collections` roxygen.
28. Write failing tests for `set_collection_if_missing_var()` happy +
    error paths matching the same shape as the id setter.
29. Implement `set_collection_if_missing_var(x, if_missing_var)` in
    `R/survey-collection.R` with the same shape. Add `@export` and
    `@family collections` roxygen.
30. Write failing test: downstream `get_means()` after a successful
    `set_collection_id()` reflects the new id in the result column name.
31. Write failing test: downstream `get_means()` after
    `set_collection_if_missing_var(coll, "skip")` skips the missing
    member instead of erroring.

#### Preservation through mutators (TDD)

32. Write failing test: `add_survey()` on a collection with non-default
    `@id` / `@if_missing_var` returns a collection whose properties are
    `identical()` to the source's. Cover: append zero, append one, append
    multiple, name-repair-warning path.
33. Write failing test: `remove_survey()` on a non-default collection
    returns a collection whose properties match. Cover: remove one by
    name, remove multiple.
34. Update every code path inside `add_survey()` and `remove_survey()`
    (in `R/survey-collection.R`) that constructs the returned
    `survey_collection` to explicitly pass `id = <source>@id` and
    `if_missing_var = <source>@if_missing_var`. Verify tests pass.

#### Print method (TDD)

35. Locate `print(survey_collection)` in `R/methods-print.R` and add the
    two new lines.
36. Write failing snapshot test: `print()` on a default-constructed
    one-member collection renders the four lines in spec §`print(survey_collection)`
    sample (or with cli formatting at the writer's discretion) including
    `id: ".survey"` and `if_missing_var: "error"`.
37. Write failing snapshot test: `print()` on a non-default collection
    (`@id = "wave"`, `@if_missing_var = "skip"`, two members) renders the
    non-default values.
38. Write failing snapshot test: `print()` on a multi-member grouped
    collection renders both new lines exactly once (not per-member).
39. Extend the print method to render both lines unconditionally (always,
    not only when non-default). Place them within the collection-summary
    block, after `groups:`. Verify all snapshot tests pass.

#### Documentation, NEWS, NAMESPACE

40. Add roxygen `@param .id` / `@param .if_missing_var` blocks on
    `as_survey_collection()` matching spec §`as_survey_collection()` prose.
41. Add roxygen `@param .id` / `@param .if_missing_var` to the internal
    `.dispatch_over_collection()` header documenting the canonical
    NULL-fallback precedence rule. Builder picks the inheritance pattern
    (`@inheritParams` vs verbatim re-statement) for each `get_*()` in
    PR 2; do not touch the get_*() roxygen in PR 1.
42. Add a `# surveycore (development version)` heading and a
    `## Breaking changes` block to `NEWS.md`. The block must mention:
    (a) the silent-no-op fix on `as_survey_collection()` and the two new
    properties, and (b) the two new exported setters. (The `.on_missing`
    rename text is added in PR 2.)
43. Run `devtools::document()`. Confirm `NAMESPACE` gains
    `set_collection_id` and `set_collection_if_missing_var` exports and
    nothing else. Confirm `man/*.Rd` for the two new exports is
    generated. Stage the regenerated artifacts.
44. Run `devtools::test()` and confirm all tests (including snapshots)
    pass. Run `testthat::snapshot_review()` for any new / updated
    snapshots and approve diffs individually.
45. Run `devtools::check()`. Confirm 0 errors, 0 warnings, ≤ 2
    pre-approved notes.
46. Run `covr::package_coverage()`. Confirm new code paths
    (validator helpers, setters, dispatcher precedence, print-method
    extension, mutator preservation lines) hit ≥ 98 % per-target table in
    test-spec §Coverage targets. Overall package coverage stays ≥ 95 %.

### Acceptance criteria

- `survey_collection` class has `@id` and `@if_missing_var` properties with
  defaults `".survey"` and `"error"`.
- S7 validator raises `surveycore_error_collection_invalid_id` for invalid
  `@id` and `surveycore_error_collection_invalid_if_missing_var` for invalid
  `@if_missing_var`. The `@id` validator fires first when both are invalid
  (verified by the dedicated ordering test).
- `as_survey_collection()` accepts `.id` / `.if_missing_var`, validates them,
  stores them on the returned collection. The previously silent
  `.on_missing` argument no longer exists at this call site (R's
  "unused argument" error fires when supplied).
- `.dispatch_over_collection()` signature is `(.id = NULL, .if_missing_var =
  NULL)`. Resolution is two-tier: call-site non-NULL beats stored property.
  Verified by tests in `test-survey-collection-dispatch.R` covering all four
  `.id` scenarios (default-stored × no call-arg, default-stored × call-arg,
  non-default-stored × no call-arg, non-default-stored × call-arg) and the
  parallel four `.if_missing_var` scenarios — 8 tests total.
- `set_collection_id(x, id)` and `set_collection_if_missing_var(x,
  if_missing_var)` are exported, return `invisible(x)`, validate via the
  shared helpers, raise `surveycore_error_not_survey_collection` for
  non-collection input.
- `add_survey()` and `remove_survey()` preserve `@id` and `@if_missing_var`
  across every accepted code path. Verified via `expect_identical()` on
  both properties.
- `print(survey_collection)` renders `id:` and `if_missing_var:` lines
  unconditionally, in the collection-summary block. Three snapshot tests
  cover default, non-default, and multi-member-grouped scenarios.
- The `surveycore_error_collection_id_collision` cli `"v"` bullet
  references `set_collection_id()` as a fix path.
- The `surveycore_error_collection_missing_var` cli `"v"` bullet reads
  `Set {.code .if_missing_var = "skip"} ...`.
- All 10 analysis files have the one-line bridge `.if_missing_var =
  .on_missing` at the inner dispatcher call site; their signatures still
  read `.on_missing = "error"` (PR 2 will rename them).
- `NEWS.md` has a `# surveycore (development version)` / `## Breaking
  changes` block describing the silent-no-op fix and the new properties /
  setters.
- `devtools::document()` clean. `NAMESPACE` adds two new exports and
  removes nothing.
- `devtools::test()` passes. New and updated snapshots in
  `_snaps/survey-collection.md` (Layer 3 constructor errors, validator
  helpers, setter errors), `_snaps/survey-collection-dispatch.md` (renamed
  dispatcher hint text + `set_collection_id()` reference in `id_collision`
  hint), `_snaps/analysis-covariance.md` (regenerated for renamed
  dispatcher hint text), and `_snaps/analysis-variance-collection.md`
  (same) reviewed via `testthat::snapshot_review()` and approved
  individually.
- `devtools::check()`: 0 errors, 0 warnings, ≤ 2 pre-approved notes.
- `covr::package_coverage()`: ≥ 95 % overall (no regression vs `develop`
  baseline). ≥ 98 % line coverage on each new code path:
  `.validate_collection_id()` (5 reject branches + 1 success branch);
  `.validate_collection_if_missing_var()` (5 reject branches + 1 success
  branch); `set_collection_id()` body; `set_collection_if_missing_var()`
  body; `.dispatch_over_collection()` precedence resolution (4 branches:
  2 per argument, call-site non-NULL vs fall-back); print-method extension
  lines; `add_survey()` / `remove_survey()` property-forward lines.
- `plans/error-messages.md` contains row C15
  (`surveycore_error_collection_invalid_if_missing_var`) in the
  `survey_collection` block, with the cli template specified in spec §New
  error class, before any PR 1 code is written. Pre-implementation gate —
  if missing, builder HOLDs.

### Files touched (write surface)

- `R/core-classes.R` — add 2 properties + 2 validator branches on
  `survey_collection`.
- `R/core-constructors.R` — `as_survey_collection()` signature, validation,
  forwarding, roxygen rewrite.
- `R/survey-collection.R` — 2 validator helpers, dispatcher signature +
  precedence, 2 new exported setters, `add_survey()` / `remove_survey()`
  preservation lines, dispatcher cli hint text.
- `R/methods-print.R` — the `print(survey_collection)` S7 method (confirmed
  location at line 769).
- `R/analysis-means.R`, `R/analysis-totals.R`, `R/analysis-freqs.R`,
  `R/analysis-ratios.R`, `R/analysis-diffs.R`, `R/analysis-corr.R`,
  `R/analysis-variance.R`, `R/analysis-quantiles.R`,
  `R/analysis-covariance.R`, `R/analysis-t-test.R` — single-line bridge
  `.if_missing_var = .on_missing` at the inner dispatcher call site.
  Signatures unchanged in PR 1.
- `tests/testthat/test-survey-collection.R` — class property tests,
  validator-ordering test, validator-helper tests, setters tests,
  preservation tests, print snapshot tests.
- `tests/testthat/test-survey-collection-dispatch.R` — dispatcher
  precedence tests via `get_means()` (canonical precedence function per
  test-spec §Test scope split). Create file if it does not exist.
- `tests/testthat/_snaps/survey-collection.md` — new snapshots for
  `as_survey_collection()` error-path messages, validator helpers (Layer
  3 only — Layer 1 S7 validator errors are class-only per
  testing-surveycore.md).
- `tests/testthat/_snaps/survey-collection-dispatch.md` — new / updated
  snapshots for the renamed dispatcher hint text and the
  `set_collection_id()` cli bullet.
- `tests/testthat/_snaps/analysis-covariance.md` — regenerated for the
  renamed dispatcher hint text in `surveycore_error_collection_missing_var`.
- `tests/testthat/_snaps/analysis-variance-collection.md` — regenerated for
  the same renamed dispatcher hint text.
- `NAMESPACE` — regenerated by `devtools::document()` (adds two exports).
- `man/set_collection_id.Rd`, `man/set_collection_if_missing_var.Rd` — new
  files generated by `devtools::document()`.
- `man/as_survey_collection.Rd`, `man/survey_collection.Rd` — regenerated
  by `devtools::document()` to reflect roxygen edits.
- `NEWS.md` — new development-version block (this PR's scope: silent-no-op
  fix + new properties / setters; the rename text is added in PR 2).

**Strictly out-of-bounds for PR 1**: any signature change in the 10
analysis files; any roxygen `@param .on_missing` / `.if_missing_var`
edit in those files; any `_snaps/analysis-*.md` snapshot regeneration;
`plans/error-messages.md` (pre-flight gate only).

If builder finds a needed change outside this list, builder HOLDs.

### Pipeline split

`recommended` — methods-heavy class change, two new exports, dispatcher
precedence rewrite. Standard planner / builder / tester / reviewer pipeline.

---

## PR 2 — `feature/collection-if-missing-var-rename`

**Goal**: Rename `.on_missing` → `.if_missing_var` across all 11
collection-dispatching `get_*()` functions, flip both trailing defaults to
`NULL`, regenerate every snapshot pinned to the old name, and update the
canonical NULL-fallback prose in each function's roxygen. Remove the
PR-1 bridge.

### Tasks (TDD order)

#### Test migration audit (pre-edit)

1. Run a `grep -rn "\.on_missing" tests/testthat/` audit. Catalogue every
   match and classify it as: (a) a real call site to be renamed, or (b)
   a deliberate "old name no longer accepted" assertion to be repurposed.
2. Run a `grep -rn "\.on_missing" tests/testthat/_snaps/` audit. List
   every snapshot file pinned to the old name.

#### Per-function rename (TDD, repeat for each of 11 functions)

For each of `get_means`, `get_totals`, `get_freqs`, `get_ratios`,
`get_diffs`, `get_corr`, `get_variance`, `get_quantiles`,
`get_covariance`, `get_t_test`, `get_pairwise`:

3. Write failing test in the function's analysis test file (one per
   function): "calling with `.if_missing_var = \"skip\"` succeeds (no
   syntax / signature error)" — minimal smoke test using
   `make_survey_data()` plus a 2-member collection.
4. Write failing test in the same file: "calling with `.on_missing =
   \"skip\"` raises an unused-argument error" (`expect_error()` without
   class).
5. Edit the function in its `R/analysis-*.R` source file:
   - Rename `.on_missing` → `.if_missing_var` in the signature.
   - Flip default from `.id = ".survey"` to `.id = NULL`.
   - Flip default from `.on_missing = "error"` to `.if_missing_var =
     NULL`.
   - At the inner `.dispatch_over_collection()` call, change the bridge
     `.if_missing_var = .on_missing` (introduced in PR 1) to
     `.if_missing_var = .if_missing_var`.
   - Update `@param .on_missing` roxygen to `@param .if_missing_var`
     with the canonical NULL-fallback clause from spec §"Every `get_*()`
     with a collection dispatch branch".
6. Verify both new tests pass for that function.
7. Migrate every existing test in the function's test file that used
   `.on_missing` → `.if_missing_var`. Run the file. Tests must still
   pass.

#### Snapshot regeneration

8. For each `_snaps/analysis-*.md` file flagged in Task 2: delete the
   stale snapshot blocks that pinned `.on_missing` text. Re-run
   `devtools::test()` to capture new snapshots. Run
   `testthat::snapshot_review()` and approve every diff individually.
   No `snapshot_accept()`.
9. For each `_snaps/survey-collection-dispatch.md` block that was not
   already updated in PR 1 (e.g., per-function dispatcher snapshots
   triggered through the renamed signature): same review-and-approve
   loop.

#### Migration audit (post-edit)

10. Re-run `grep -rn "\.on_missing" R/`. Expected: zero matches. Any
    match blocks the PR.
11. Re-run `grep -rn "\.on_missing" tests/testthat/`. Expected: only
    the deliberate "unused argument" assertions in the rename smoke
    tests.
12. Run `devtools::document()`, then `grep -rn "\.on_missing" man/`.
    Expected: zero matches.
13. Run `grep -n "\.on_missing" NEWS.md`. Expected: one or more matches
    in the breaking-changes entry. (`NEWS.md` is the only file allowed
    to mention the old name.)
14. Record each grep's match count in the PR description as a
    migration-audit checklist (per test-spec §Migration audit).

#### NEWS, NAMESPACE, package check

15. Extend the `## Breaking changes` block in `NEWS.md` (added in PR 1)
    to additionally mention the rename of `.on_missing` →
    `.if_missing_var` across every collection-dispatching `get_*()`.

    Note: this edit is additive within the existing `## Breaking changes`
    block (introduced in PR 1). If a hotfix lands between PR 1 and PR 2
    and also extends this block, resolve the merge conflict by listing
    all breaking changes in logical order.
16. Run `devtools::document()`. Confirm `NAMESPACE` is unchanged
    (no new exports in PR 2). Confirm `man/*.Rd` regenerates with the
    renamed `@param`.
17. Run `devtools::test()`. All tests pass.
18. Run `devtools::check()`. 0 errors, 0 warnings, ≤ 2 pre-approved
    notes.
19. Run `covr::package_coverage()`. Confirm no regression versus the
    PR-1-merged baseline.

### Acceptance criteria

- All 11 functions have signature `.id = NULL, .if_missing_var = NULL` as
  the trailing two named-only arguments.
- For each of the 11 functions, calling with `.if_missing_var = "skip"`
  succeeds; calling with `.on_missing = "skip"` raises R's unused-argument
  error.
- Every `@param .on_missing` line is renamed to `@param .if_missing_var`
  with the canonical NULL-fallback clause (or via `@inheritParams
  .dispatch_over_collection` — pick one pattern, apply consistently).
- Migration audit recorded in PR 2 description as a checklist with explicit
  grep match counts: `R/`: 0 matches; `tests/testthat/`: only inside the
  deliberate 'unused argument' assertions (one per `get_*()` rename smoke
  test); `_snaps/`: 0 matches; `man/`: 0 matches; `NEWS.md`: ≥ 1 match
  (allowed).
- `tests/testthat/` may only mention `.on_missing` inside the deliberate
  "unused argument" assertions — every match outside that scope is a
  bug.
- The PR-1 bridge (`.if_missing_var = .on_missing`) is removed from every
  analysis source file.
- `NEWS.md` `## Breaking changes` block now mentions the rename in
  addition to the PR-1 content.
- `devtools::document()`: clean. `NAMESPACE`: unchanged from PR 1.
- `devtools::test()`: passes. All new / updated snapshots reviewed.
- `devtools::check()`: 0 errors, 0 warnings, ≤ 2 pre-approved notes.
- `covr::package_coverage()`: no regression vs PR-1-merged baseline.

### Files touched (write surface)

- `R/analysis-means.R` — `get_means()` signature + roxygen + bridge removal.
- `R/analysis-totals.R` — `get_totals()` same shape.
- `R/analysis-freqs.R` — `get_freqs()` same shape.
- `R/analysis-ratios.R` — `get_ratios()` same shape.
- `R/analysis-diffs.R` — `get_diffs()` same shape.
- `R/analysis-corr.R` — `get_corr()` same shape.
- `R/analysis-variance.R` — `get_variance()` same shape.
- `R/analysis-quantiles.R` — `get_quantiles()` same shape.
- `R/analysis-covariance.R` — `get_covariance()` same shape.
- `R/analysis-t-test.R` — `get_t_test()` and `get_pairwise()` same shape
  (one file, two functions).
- `tests/testthat/test-analysis-*.R` — every test file that referenced
  `.on_missing`. Builder must enumerate via `grep -rn "\.on_missing"
  tests/testthat/` and rename each match.
- `tests/testthat/_snaps/analysis-*.md` — every snapshot file pinned to
  `.on_missing`. Builder enumerates via the same grep.
- `man/get_means.Rd`, `man/get_totals.Rd`, `man/get_freqs.Rd`,
  `man/get_ratios.Rd`, `man/get_diffs.Rd`, `man/get_corr.Rd`,
  `man/get_variance.Rd`, `man/get_quantiles.Rd`, `man/get_covariance.Rd`,
  `man/get_t_test.Rd`, `man/get_pairwise.Rd` — regenerated by
  `devtools::document()`.
- `NAMESPACE` — regenerated; expected unchanged from post-PR-1 state.
- `NEWS.md` — extend the existing PR-1 breaking-changes block with the
  rename text.

**Strictly out-of-bounds for PR 2**: `R/core-classes.R`,
`R/core-constructors.R`, `R/survey-collection.R`, `R/core-methods.R`,
any setter / class / dispatcher / print logic. PR 2 is a wide rename
only — if builder finds a needed change in any of those files, builder
HOLDs.

### Pipeline split

`recommended` — wide rename across 10 source files plus extensive
snapshot churn benefits from a focused tester pass that runs the full
migration audit before approval.

---

## Sequencing note

PR 1 must merge before PR 2 because:

1. PR 1 introduces the dispatcher's new `.if_missing_var` parameter; PR 2
   removes the analysis-layer bridge that depends on that parameter
   already existing.
2. PR 1 introduces the C15 error class; PR 2's dual-pattern snapshots for
   the renamed-argument constructor errors need that class registered.
3. PR 1 and PR 2 both touch `NEWS.md` and `NAMESPACE` (PR 2 only
   `NEWS.md`, since no new exports). Sequential merge avoids merge
   conflicts on those two files.

The two PRs share only `NEWS.md` and `NAMESPACE` as overlapping write
surfaces. All R source-file edits are disjoint: PR 1 touches
`core-classes.R`, `core-constructors.R`, `survey-collection.R`,
`core-methods.R`, plus a one-line bridge in each of the 10 analysis
files; PR 2 touches **only** the 10 analysis files and their tests /
snapshots / man files.
