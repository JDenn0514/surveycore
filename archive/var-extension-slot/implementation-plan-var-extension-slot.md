# Implementation plan — var-extension-slot

**Version**: 1.1
**Status**: REVIEWED (plan-review.md Pass 1 resolved — 0 blocking,
3 required, 12 suggestion; all addressed)
**Based on**: `spec.md` (Status: SPEC_READY, v1.1), `test-spec.md` (v1.1,
amended with a Class/foundation table during plan-review resolution),
`decisions.md` (2026-08-27, both entries locked).

## PR map

- [ ] PR 1: `feature/var-extension-slot` — add the `var_extra` metadata
  slot (`survey_metadata` property, `set_var_extra()`,
  `extract_var_extra()`, and lifecycle wiring) as a single reviewable unit.

  ### Tasks (2–5 min each, TDD sub-steps explicit)

  **A. Foundation — `survey_metadata` class property**

  1. Write failing test in `tests/testthat/test-s7-classes.R` asserting a
     freshly constructed `survey_metadata()` object has a `var_extra`
     property equal to `list()` by default.
  2. Write failing test asserting `survey_metadata(var_extra = list(age =
     list(role = "demographic")))` stores the value unchanged
     (`identical()`).
  3. Add the `var_extra` property (`S7::class_list`, `default =
     quote(list())`) to the `survey_metadata` class definition in
     `R/core-classes.R`; add the corresponding `@param var_extra` doc
     line.
  4. Run `devtools::document()`; verify both tests from steps 1–2 pass.
  4.1. Write failing test: `as_survey()`, `as_survey_replicate()`,
     `as_survey_twophase()`, and `as_survey_nonprob()` each build an
     object whose `@metadata@var_extra` is present and equals `list()`
     when no payload has been set (per test-spec.md's new
     "Class/foundation" table) — confirms the class default flows
     through every constructor path, not only direct `survey_metadata()`
     construction.
  4.2. Verify test from step 4.1 passes with no further code change
     (confirms constructors inherit `survey_metadata()`'s default
     unchanged).

  **B. `set_var_extra()` — scaffold and Convention 1/2/3 storage (survey
  objects)**

  5. Write failing test: Convention 1, single named argument (`age =
     list(role = "demographic")`) on a `survey_taylor` object built with
     `make_survey_data()`; assert `d@metadata@var_extra[["age"]]` is
     `identical()` to the payload passed in. Call `test_invariants(d)`
     first in this block (first constructor use in the file).
  6. Implement `set_var_extra(x, ..., variable = NULL, extra = NULL)` in
     `R/core-metadata.R`: guard with `.check_is_survey_or_df()`, call
     `.parse_setter_input()` with `content_type = "vector"` to resolve
     per-variable payloads for Conventions 1–3, then loop over resolved
     variables storing into `x@metadata@var_extra[[var_name]]` (survey
     branch) with `invisible(x)` return. Add the function to the
     file-header inventory comment. No payload-shape validation yet
     (added in section C).
  7. Verify test from step 5 passes.
  8. Write failing test: Convention 1, multiple named arguments in one
     call; assert each variable's stored payload is correct
     independently.
  9. Write failing test: Convention 2, single unnamed named list in
     `...` mapping multiple variables to payloads; assert every listed
     variable's payload is stored correctly regardless of argument
     order.
  10. Write failing test: Convention 3, `variable = "age"`, `extra =
      list(list(role = "demographic"))`; assert the stored payload is
      `identical()` to `list(role = "demographic")` (catches the
      forgot-to-double-wrap failure mode).
  11. Write failing test: Convention 3, `variable = c("age",
      "q13_text")`, two-element `extra`; assert each variable's payload
      matches its positional entry.
  12. Verify all four tests from steps 8–11 pass against the
      implementation from step 6 (no code change expected — confirms
      `.parse_setter_input()` already generalizes across conventions).

  **C. `set_var_extra()` — payload-shape validation**

  13. Write failing tests for the bare-scalar `surveycore_error_var_extra_not_list`
      violations: payload is a bare character string; payload is a bare
      numeric vector; payload is a bare named atomic vector (e.g. `c(role
      = "x")`). One `test_that()` block per scenario, `expect_error(class =
      "surveycore_error_var_extra_not_list")` plus a paired
      `expect_snapshot(error = TRUE)` for each.
  14. Write failing tests for the malformed-list `surveycore_error_var_extra_not_list`
      violations: non-empty list with unnamed top-level elements (e.g.
      `list("free_text", 3)`); non-empty list with a duplicated top-level
      name; non-empty list with an empty-string top-level name. Same dual
      pattern per scenario.
  15. Implement the payload-shape validator inside `set_var_extra()` (or
      as a small helper if it grows past ~10 lines): for each resolved,
      *present* variable, before storing, check the payload is `NULL` or
      a list; if a non-empty list, check `names()` is non-`NULL`, has no
      empty strings, and has no duplicates. Raise
      `surveycore_error_var_extra_not_list` (message per
      `plans/error-messages.md` row M-16) on the first violation
      encountered, in variable-processing order.
  16. Verify the six tests from steps 13–14 pass.
  17. Write failing test: payload `list()` (empty, not `NULL`) is
      accepted and stored as `list()` (not rejected — the empty-list case
      has no names to violate the rule).
  18. Verify test from step 17 passes without further code change
      (confirms the validator's non-empty guard is correct).
  19. Write failing test: a payload whose top level is fully named but
      one entry's *value* is itself an unnamed list (e.g. `list(role =
      "free_text", tags = list("a", "b"))`) is accepted unchanged —
      confirms validation never recurses into nested values.
  20. Write failing test: a payload containing an unusual-type value at
      the top level (a function, a data frame, or `NA`), with the top
      level fully named, is accepted and round-trips via direct property
      access unchanged.
  21. Verify tests from steps 19–20 pass without further code change.

  **D. `set_var_extra()` — ambiguous-wrap guard (Convention 3)**

  22. Write failing test: `surveycore_error_var_extra_ambiguous_wrap`
      fires when `length(variable) == 1` and `extra` is itself a named
      list of length 1 (e.g. `variable = "age", extra = list(role =
      "demographic")`). Dual pattern (`expect_error(class = ...)` +
      `expect_snapshot(error = TRUE)`).
  23. Implement the guard in `set_var_extra()`: when Convention 3 is used
      with `length(variable) == 1` and `extra` is a named list of length
      1, raise `surveycore_error_var_extra_ambiguous_wrap` (message per
      `plans/error-messages.md` row M-17) before calling
      `.parse_setter_input()`. Place the check so it does not
      misclassify the correctly-wrapped form (`extra =
      list(list(role = "demographic"))`, an unnamed length-1 outer
      list) as ambiguous.
  24. Verify test from step 22 passes, and re-run the Convention-3
      happy-path tests from steps 10–11 to confirm the guard does not
      false-positive on correctly wrapped payloads.

  **E. `set_var_extra()` — reused setter errors (pass-through from
  `.parse_setter_input()` / `.check_is_survey_or_df()`)**

  25. Write failing tests, dual pattern, for the five reused error
      classes: `surveycore_error_not_survey_or_df` (`x` is a plain
      vector); `surveycore_error_setter_ambiguous` (both `...` and
      `variable` supplied); `surveycore_error_setter_empty` (neither
      supplied); `surveycore_error_setter_mismatched_lengths`
      (`variable` length 2, `extra` length 1); `surveycore_error_setter_mixed_dots`
      (one named, one unnamed argument in `...`).
  26. Verify all five tests from step 25 pass with no further
      implementation change (confirms `set_var_extra()` correctly
      delegates to the shared helpers with no re-implementation of their
      validation).

  **F. `set_var_extra()` — warnings and multi-variable ordering**

  27. Write failing test: `surveycore_warning_var_not_found` fires when
      one of several named variables is absent from `x`'s columns;
      capture with `expect_warning(result <- set_var_extra(...), class =
      ...)`; assert the variables that do exist still received their
      payloads and the missing one is absent as a key.
  28. Write failing test: `surveycore_warning_setter_empty_variables`
      fires for `variable = character(0)`; assert the returned object's
      `var_extra` is unchanged from the input.
  29. Implement the two warnings (or confirm they already fire via
      `.parse_setter_input()`/existing sibling pattern — check
      `set_var_note()`'s implementation for the exact call site and
      mirror it for `set_var_extra()`).
  30. Verify tests from steps 27–28 pass.
  31. Write failing test: one absent-and-invalid variable alongside one
      present-and-valid variable in the same call — only
      `surveycore_warning_var_not_found` fires (the absent variable's
      payload shape is never checked); the present variable's payload is
      stored; no error.
  32. Write failing test: two present variables in one call via
      Convention 1, both with invalid payloads — `set_var_extra()` aborts
      with `surveycore_error_var_extra_not_list` on the first in argument
      order; the caller's original object (captured before the call) is
      unaffected (`identical(x, x_before)`).
  33. Write failing test: same scenario via Convention 2 (single unnamed
      named list) — abort happens on the first invalid entry in list
      order, not necessarily first-argument-textually order.
  34. Confirm the processing order (existence check before shape
      validity, one variable at a time, abort-on-first-invalid, no
      partial write reaches the caller) matches `set_missing_codes()`'s
      established precedent. This step is expected to be
      confirmation-only — the validator from step 15 already operates
      on a per-variable working copy that is only returned at the very
      end of the function, so no code change is anticipated. If steps
      31–33's tests reveal an actual ordering bug, treat that as a new
      defect against step 15's validator (not a silent respec of
      section C) and note the fix explicitly in `implementation.md`.
  35. Verify tests from steps 31–33 pass.

  **G. `set_var_extra()` — edge cases**

  36. Write failing test: smallest constructible survey design
      (`make_survey_data(n = 2)`) — `set_var_extra()` succeeds and stores
      the payload identically to a larger design.
  37. Write failing test: single-row `data.frame` (not a survey object)
      — `set_var_extra()` succeeds; `attr(x[[var]], "var_extra")` is set
      on the correct column.
  38. Write failing test: `data.frame` (non-single-row) mode more
      generally — assert `attr(x[[var]], "var_extra")` equals the
      payload after the call (the data-frame branch of `set_var_extra()`
      storing into a column attribute rather than `@metadata@var_extra`).
  39. Implement the `data.frame` storage branch in `set_var_extra()`:
      when `x` is a data frame (not a survey object), set/remove
      `attr(x[[var_name]], "var_extra")` instead of writing to
      `@metadata@var_extra`.
  40. Verify tests from steps 37–38 pass.
  41. Write failing test: target variable's data column is entirely `NA`
      — `set_var_extra()` succeeds identically (it never reads column
      values).
  42. Write failing test: `variable`/`...` name is the internal sentinel
      column `..surveycore_wt..` — payload is stored under that literal
      name with no special-casing.
  43. Write failing test: `variable`/`...` name matches a design variable
      (e.g. the survey's weight column) — `set_var_extra()` succeeds;
      the design variable's own value/identity in `@data` and
      `@variables` is unchanged after the call.
  44. Write failing test: setting a payload for every existing column in
      one call via Convention 2 — all payloads stored correctly with no
      cross-variable interaction.
  45. Verify tests from steps 41–44 pass with no further code change
      (confirms the implementation never branches on column identity or
      values).
  46. Write failing test: `extra = NULL` for a variable that already has
      a payload — after the call, that variable's key is fully absent
      from `var_extra` (not present with a `NULL` value).
  47. Write failing test: Convention 3 with `variable` supplied and
      `extra` omitted (left `NULL`), for two or more variables that each
      already have a payload — every listed variable's payload is
      cleared; unlisted variables are unaffected.
  48. Write failing test: payload of `list()` (empty, not `NULL`) is
      stored as `list()`, distinguishable from "never set" via a direct
      property check (`"age" %in% names(d@metadata@var_extra)` is
      `TRUE`, value is `list()`).
  49. Write failing test: calling `set_var_extra()` twice on the same
      variable with different payloads — the second call's payload fully
      replaces the first (no merge).
  49.1. Write failing test: the same variable named twice within one
     Convention 1 call (e.g. `set_var_extra(x, age = list(a = 1), age =
     list(b = 2))`) — R's own `...` semantics apply (last value for a
     duplicate name wins); `set_var_extra()` adds no duplicate-detection
     beyond what `...` already provides. Verify it passes with no further
     code change (spec §III edge case: "same variable named twice").
  50. Verify tests from steps 46–49 pass; confirm the assignment
      (`x@metadata@var_extra[[var_name]] <- content`) already gives
      correct `NULL`-removes-key and full-replace semantics via ordinary
      R list-assignment (no special-case code expected).

  **H. `extract_var_extra()` — scaffold and `format = "list"`**

  51. Write failing test: `format = "list"` (default), one variable with
      a payload set via `set_var_extra()` — returned list has one entry,
      keyed by variable name, `identical()` to the stored payload.
  52. Implement `extract_var_extra(x, ..., format = "list", fill =
      NULL)` in `R/core-metadata.R`: guard with `.check_is_survey_or_df()`,
      validate `format` via `.check_extractor_format(valid_formats =
      c("list", "data_frame"))` and `fill` via
      `.check_extractor_fill()`, resolve the queried columns via
      `tidyselect::eval_select(rlang::expr(c(...)), data =
      .get_data_for_select(x))`, and build the `"list"`-format result by
      reading `x@metadata@var_extra[[v]]` (survey branch) or
      `attr(x[[v]], "var_extra", exact = TRUE)` (data-frame branch),
      applying the `fill` rule (`NULL` omits unset variables;
      `NA_character_` includes them with a `NULL` value). Add the
      function to the file-header inventory comment. Note: unlike
      section B's staged rollout of `set_var_extra()` (survey branch in
      step 6, data-frame branch deferred to step 39), both read branches
      are implemented together here because they are two sides of one
      trivial read; the data-frame branch is intentionally implemented
      ahead of its own dedicated test, which arrives in section J
      (task 67).
  53. Verify test from step 51 passes.
  54. Write failing test: `format = "list"`, no variables selected via
      `...` (defaults to all columns) — result contains only columns
      that have a payload set (default `fill = NULL`).
  55. Write failing test: `format = "list"`, `fill = NA_character_`, a
      variable with no payload included in the selection — appears in
      the result with a `NULL` value.
  56. Verify tests from steps 54–55 pass.
  57. Write failing test: deeply nested payload (list containing a list
      containing a numeric vector and a character scalar), round-tripped
      through `set_var_extra()` then `extract_var_extra(...,
      format = "list")` — `identical()` equality, nothing flattened,
      coerced, or reordered.
  58. Verify test from step 57 passes (first test in the suite that
      chains both functions together).

  **I. `extract_var_extra()` — `format = "data_frame"`**

  59. Write failing test: `format = "data_frame"`, one variable with a
      2-key payload — returned tibble has exactly 2 rows for that
      variable, columns `variable`, `key`, `value`; `key` matches the
      payload's names; `value` matches positionally.
  60. Decide and implement the `"data_frame"` builder: either generalize
      `.format_list_result()` to parameterize output column names and
      whether `value` is coerced to `character` or kept as a raw
      list-column, or write a dedicated inline block in
      `extract_var_extra()`. Builder discretion per spec §IV Returns —
      document the choice in `implementation.md`.
  61. Verify test from step 59 passes.
  62. Write failing test: `format = "data_frame"`, a variable with
      payload `list()` (explicitly emptied) — contributes zero rows.
  63. Write failing test: `format = "data_frame"`, no variable has any
      payload — zero-row tibble with columns `variable`, `key`, `value`
      present and correctly typed (assert column names/count, not just
      `nrow() == 0`).
  64. Verify tests from steps 62–63 pass.
  65. Write failing test: payload value containing a nested list,
      retrieved via `format = "data_frame"` — the `value` list-column's
      corresponding element is `identical()` to the original nested
      list, not flattened or coerced to character. In the same block,
      also cover a top-level key whose value is literally `NULL` (e.g.
      `list(role = "demographic", note = NULL)`) — the corresponding
      `value` list-column element is `NULL`, not dropped or coerced
      (spec §IV edge case).
  66. Verify test from step 65 passes.

  **J. `extract_var_extra()` — data-frame mode, `any_of()`, errors, edge
  cases**

  67. Write failing test: reading a payload set via `set_var_extra()` on
      a `data.frame` — `extract_var_extra()` on the same frame returns
      the payload from the `"var_extra"` attribute (both-modes row: read
      path differs by mode).
  68. Write failing test: `any_of()` used to select a mix of existing and
      non-existing variable names — non-existing names silently skipped;
      no warning, no error; result includes only existing ones.
  69. Verify tests from steps 67–68 pass with no further code change.
  70. Write failing tests, dual pattern, for the three
      `extract_var_extra()` error classes: `surveycore_error_not_survey_or_df`
      (`x` a plain vector); `surveycore_error_format_invalid` for
      `format = "named_vector"` and separately for `format =
      "something_invalid"`; `surveycore_error_fill_invalid` for `fill =
      TRUE`.
  71. Verify the four tests from step 70 pass (confirms delegation to
      `.check_extractor_format()`/`.check_extractor_fill()` needs no
      extra logic).
  72. Write failing test: smallest constructible design
      (`make_survey_data(n = 2)`) — `extract_var_extra()` returns the
      correct result regardless of row count.
  73. Write failing test: queried variable's data column is entirely
      `NA` — `extract_var_extra()` returns the stored payload (if any)
      unaffected by the column's values.
  74. Write failing test: a variable with payload `list()` vs. a
      variable never given a payload, both queried with `format =
      "list"` and default `fill = NULL` — the `list()` variable is
      present with value `list()`; the never-set variable is absent.
  75. Verify tests from steps 72–74 pass with no further code change.
  75.1. Write failing test: construct a `survey_replicate` object via
     `make_survey_data(design = "replicate")` |> `as_survey_replicate()`;
     call `set_var_extra()` and `extract_var_extra()` directly on it;
     assert the round-trip is `identical()`. Required so the spec §I
     Class/design support matrix ("Yes" for `survey_replicate`) has
     direct test evidence, per test-spec.md's Datasets requirement that
     all four survey classes be exercised at least once with both
     functions.
  75.2. Write failing test: same as step 75.1 but for a `survey_twophase`
     object (`make_survey_data(design = "twophase")` |>
     `as_survey_twophase()`). Required for the same reason — closes the
     spec-coverage gap where only `survey_taylor` (task 5) and
     `survey_nonprob` (tasks 88–89) had dedicated direct-exercise tasks.
  75.3. Verify tests from steps 75.1–75.2 pass with no further code
     change (confirms `set_var_extra()`/`extract_var_extra()` branch only
     on `.check_is_survey_or_df()`, never on the specific survey subclass).

  **K. Lifecycle wiring — `.rename_metadata_keys()`,
  `.delete_metadata_col()`, `.extract_haven_metadata()` promotion block**

  (Both functions now exist; lifecycle tests exercise both.)

  76. Write failing test in `tests/testthat/test-validators.R` (or the
      file the equivalent `notes`-rename test currently lives in): a
      variable with a payload set via `set_var_extra()` is renamed via
      the package's existing rename entry point — the payload is
      retrievable under the new name via `extract_var_extra()` and no
      longer retrievable under the old name.
  77. Add one line to `.rename_metadata_keys()` in `R/core-validators.R`
      renaming `metadata@var_extra` the same way `metadata@notes` is
      renamed.
  78. Verify test from step 76 passes.
  79. Write failing test: a variable with a payload set via
      `set_var_extra()` is removed from the design via the package's
      existing column-removal entry point — the payload no longer
      appears anywhere in the design's stored metadata (a subsequent
      `extract_var_extra()` call does not surface it).
  80. Add one line to `.delete_metadata_col()` in
      `R/core-validators.R` clearing `md@var_extra[[col]]` the same way
      `md@notes[[col]]` is cleared.
  81. Verify test from step 79 passes.
  82. Write failing test: a variable with **no** payload set is renamed
      or removed — no error, no warning; other variables' payloads
      unaffected.
  83. Write failing test: renaming one variable does not disturb another
      variable's stored payload — confirm the untouched variable's
      payload is unchanged after the rename.
  84. Verify tests from steps 82–83 pass with no further code change.
  85. Write failing test: setting a payload on a `data.frame`, then
      constructing a survey object from that frame via `as_survey()` (or
      `as_survey_replicate()`/`as_survey_twophase()`/
      `as_survey_nonprob()`) — `extract_var_extra()` on the resulting
      survey object returns the same payload that was set on the data
      frame before construction.
  86. Add the `var_extra` promotion block to `.extract_haven_metadata()`
      in `R/core-metadata.R`: read `attr(col, "var_extra", exact =
      TRUE)` for each column and promote whenever the value is
      non-`NULL`, regardless of length — explicitly do NOT reuse the
      `note`/`universe`/`missing_codes` emptiness filter
      (`is.character(...) && nzchar(...)` / `is.atomic(...) &&
      length(...) > 0L`); a payload of `list()` must promote unchanged.
      Pass the collected `var_extra` list into the `survey_metadata()`
      constructor call at the end of the function.
  87. Verify test from step 85 passes. Write and verify a companion test
      confirming a `data.frame` column with `attr(col, "var_extra") <-
      list()` (empty, not `NULL`) is promoted as `list()` and not dropped
      — the specific regression this block exists to prevent.
  88. Write failing test: `x` is a `survey_nonprob` object with a
      `@reference_sample`; a payload is set on the same variable name on
      both `x` and `x@reference_sample`, with different content —
      `extract_var_extra(x, v)` and `extract_var_extra(x@reference_sample,
      v)` return their own independently-set payloads.
  89. Verify test from step 88 passes with no further code change
      (confirms `set_var_extra()`/`extract_var_extra()` never read or
      write `x@reference_sample@metadata@var_extra`).
  90. Write failing test: a payload containing only plain
      R-serializable content (character/numeric/list, no
      connections/environments) round-trips through `saveRDS()` then
      `readRDS()` with `identical()` equality on the
      `extract_var_extra()` output.
  91. Verify test from step 90 passes (structural — no code change
      expected; confirms the S7 property itself serializes correctly).

  **L. Round-trip fidelity quality gate and grep audit**

  92. Write a dedicated test (or confirm existing tests jointly cover
      it) asserting: for every payload value accepted by
      `set_var_extra()` across the suite's happy-path scenarios, the
      value returned by `extract_var_extra(..., format = "list")` is
      `identical()` to what was set.
  93. Grep the `R/` directory to confirm the only production references
      to `@metadata@var_extra`'s *contents* (not merely its presence)
      are in `set_var_extra()`, `extract_var_extra()`,
      `.rename_metadata_keys()`, `.delete_metadata_col()`, and the
      `.extract_haven_metadata()` promotion block. Record the grep
      result in `implementation.md`.

  **M. Documentation and housekeeping**

  94. Write `@param`/`@return`/`@examples`/`@family metadata`/`@seealso`
      roxygen blocks for `set_var_extra()` and `extract_var_extra()`
      (mirroring `set_var_note()`/`extract_var_note()`'s documentation
      structure); add both functions to the file-header inventory
      comment in `R/core-metadata.R` (confirm done, from steps 6/52).
  95. Run `devtools::document()`; confirm `NAMESPACE`,
      `man/set_var_extra.Rd`, and `man/extract_var_extra.Rd` are
      generated with no manual edits.
  96. Add a `NEWS.md` entry describing the new `var_extra` slot,
      `set_var_extra()`, and `extract_var_extra()` (bullet under the
      unreleased/development heading).
  97. Run `devtools::test()` — full suite passes, including all tasks
      above.
  98. Run `covr::package_coverage()` — confirm the new code in
      `R/core-classes.R`, `R/core-metadata.R`, and `R/core-validators.R`
      meets the project's coverage floor (≥95% required, ≥98% target,
      per `test-spec.md`'s profile gates).
  99. Run `devtools::check()` locally, then confirm CI's `R CMD check
      --as-cran` gate: 0 errors, 0 warnings, ≤2 pre-approved notes.
  100. Run `pkgdown::build_site()` locally if roxygen/vignette content
      changed structurally (it does not here beyond new `.Rd` files);
      confirm no build errors.

  ### Acceptance criteria (observable outcomes before merge)

  **Class/foundation** (test-spec.md §Class/foundation)
  - Every `survey_metadata()` object — built directly or implicitly via
    `as_survey()`, `as_survey_replicate()`, `as_survey_twophase()`, or
    `as_survey_nonprob()` — has a `var_extra` property present and
    defaulting to `list()`.
  - `set_var_extra()`/`extract_var_extra()` are each exercised directly
    (not just via S7-inheritance assertion) against a `survey_taylor`, a
    `survey_replicate`, a `survey_twophase`, and a `survey_nonprob`
    object at least once across the suite.

  **`set_var_extra()` — happy path** (all rows in test-spec's happy-path
  table pass)
  - Convention 1 (single and multiple named arguments), Convention 2
    (single unnamed named list), and Convention 3 (single- and
    multi-variable, correctly wrapped) all store the exact payload
    passed in, verified by `identical()`.
  - A deeply nested payload round-trips through `set_var_extra()` then
    `extract_var_extra(format = "list")` unchanged.
  - A payload with an unnamed nested list *value* (top level fully
    named) is accepted and stored unchanged.
  - A payload containing a function, data frame, or `NA` as a top-level
    value (top level fully named) is accepted and stored unchanged.
  - Setting a payload on a `data.frame` sets `attr(x[[var]],
    "var_extra")`; constructing a survey object from that frame later
    (via any of the four constructors) promotes the payload into
    `@metadata@var_extra`, retrievable via `extract_var_extra()`.
  - Convention 3 with `extra` omitted clears every listed variable's
    payload; unlisted variables are unaffected.
  - Setting a payload under a design-variable name (e.g. the weight
    column) succeeds without altering the design variable's own value
    or identity.
  - A payload value that is a non-serializable R object (an open
    connection or an environment), with the top level fully named, is
    accepted by `set_var_extra()` without error.
  - Separately, a payload containing only R-serializable content
    round-trips through `saveRDS()`/`readRDS()` with `identical()`
    equality.
  - `extract_var_extra(x, v)` and `extract_var_extra(x@reference_sample,
    v)` on a `survey_nonprob` object return independently-set payloads
    for the same variable name `v`.
  - `extra = NULL` removes a variable's key entirely (not present with a
    `NULL` value).
  - A payload of `list()` is stored and distinguishable from "never
    set."
  - Calling `set_var_extra()` twice on the same variable fully replaces
    the first payload (no merge).

  **`set_var_extra()` — error paths** (dual pattern:
  `expect_error(class = ...)` + `expect_snapshot(error = TRUE)`, all
  pass)
  - `surveycore_error_not_survey_or_df` — `x` not a survey object or
    data frame.
  - `surveycore_error_setter_ambiguous` — both `...` and `variable`
    supplied.
  - `surveycore_error_setter_empty` — neither supplied.
  - `surveycore_error_setter_mismatched_lengths` — `variable`/`extra`
    length mismatch.
  - `surveycore_error_setter_mixed_dots` — mixed named/unnamed `...`.
  - `surveycore_error_var_extra_not_list` — fires for: bare character
    string; bare numeric vector; bare named atomic vector; non-empty
    list with unnamed elements; non-empty list with a duplicated name;
    non-empty list with an empty-string name. (Six scenarios, one
    class.)
  - `surveycore_error_var_extra_ambiguous_wrap` — Convention 3,
    single variable, `extra` a named list of length 1 not wrapped in an
    outer list.

  **`set_var_extra()` — warnings**
  - `surveycore_warning_var_not_found` — absent variable skipped;
    present variables in the same call still receive their payloads.
  - `surveycore_warning_setter_empty_variables` — `variable =
    character(0)` is a no-op; object returned unchanged.
  - Multi-variable ordering: existence checked before shape validity;
    the first *present* invalid payload aborts the whole call with
    `surveycore_error_var_extra_not_list`, leaving the caller's original
    object untouched; this ordering holds for both Convention 1 and
    Convention 2.

  **`set_var_extra()` — edge cases**
  - Smallest constructible design (`n = 2`) and single-row/all-NA data
    frames: behavior unaffected by row count or column values.
  - `..surveycore_wt..` sentinel column name accepted with no special
    casing.
  - Setting a payload for every existing column in one call: no
    cross-variable interaction.

  **`extract_var_extra()` — happy path**
  - `format = "list"` default: returns only variables with a payload
    set, keyed correctly, values `identical()` to stored payloads.
  - `fill = NA_character_` includes unset variables with a `NULL`
    value.
  - `format = "data_frame"`: correct `(variable, key, value)` row count
    and content for a multi-key payload; a `list()` payload contributes
    zero rows; a payload set with no variables contributes a
    correctly-typed zero-row tibble; nested list values in the `value`
    column are preserved via `identical()`, never coerced.
  - Reading a `data.frame`-mode payload via the `"var_extra"` attribute
    returns the same payload set by `set_var_extra()`.
  - `any_of()` silently skips non-existent variable names with no
    warning or error.

  **`extract_var_extra()` — error paths** (dual pattern, all pass)
  - `surveycore_error_not_survey_or_df`, `surveycore_error_format_invalid`
    (for both `"named_vector"` and an arbitrary invalid string), and
    `surveycore_error_fill_invalid`.

  **`extract_var_extra()` — edge cases**
  - Smallest constructible design and all-NA-column queries return
    correct results unaffected by row count or column values.
  - A `list()`-payload variable and a never-set variable are
    distinguishable under `format = "list"`, default `fill = NULL`.

  **Lifecycle**
  - Renaming a column carries its `var_extra` entry to the new name; the
    entry is no longer retrievable under the old name.
  - Removing a column deletes its `var_extra` entry; no longer surfaced
    by any subsequent `extract_var_extra()` call.
  - A variable with no payload set is renamed/removed with no error or
    warning; other variables' payloads are unaffected; renaming one
    variable does not disturb another's stored payload.
  - Constructing a survey object from a `data.frame` whose column carries
    a `"var_extra"` attribute of `list()` (explicitly emptied, not unset)
    promotes it unchanged — the promotion path never silently drops an
    empty-but-set payload back to "never set."

  **Quality gates**
  - Round-trip fidelity: every payload value accepted by
    `set_var_extra()` across the suite returns `identical()` from
    `extract_var_extra(format = "list")`.
  - No production code outside the new setter, extractor, and lifecycle
    call sites reads or branches on `@metadata@var_extra`'s contents
    (verified by grep, recorded in `implementation.md`).
  - `devtools::document()` runs clean; `NAMESPACE`,
    `man/set_var_extra.Rd`, `man/extract_var_extra.Rd` are generated,
    not hand-edited.
  - `devtools::test()` — full suite passes.
  - `covr::package_coverage()` on new code meets the project floor
    (≥95%, target ≥98%, per `test-spec.md`'s profile gates).
  - `R CMD check --as-cran` — 0 errors, 0 warnings, ≤2 pre-approved
    notes.
  - `pkgdown::build_site()` — clean.
  - Profile gates checklist from `test-spec.md` (document, test,
    run_examples, R CMD check --as-cran, pkgcheck, pkgdown, covr, CRAN
    cookbook scan) all pass.

  ### Files touched (write surface)

  - `R/core-classes.R` — modified (add `var_extra` property to
    `survey_metadata` + roxygen `@param`).
  - `R/core-metadata.R` — modified (add `set_var_extra()`,
    `extract_var_extra()`, roxygen docs, file-header inventory update,
    `var_extra` promotion block in `.extract_haven_metadata()`;
    optionally generalize `.format_list_result()`).
  - `R/core-validators.R` — modified (`.rename_metadata_keys()`,
    `.delete_metadata_col()`).
  - `tests/testthat/test-s7-classes.R` — modified (class property
    default + explicit-value tests).
  - `tests/testthat/test-metadata-system.R` — modified (all
    `set_var_extra()`/`extract_var_extra()` happy-path, error, warning,
    and edge-case tests; round-trip fidelity test; grep-audit
    documentation).
  - `tests/testthat/test-validators.R` — modified (rename lifecycle tests
    for `var_extra`, mirroring the existing `notes`-rename tests).
  - `tests/testthat/test-utils.R` — modified (`.delete_metadata_col()`
    lifecycle tests for `var_extra`) — this is where the existing
    `.delete_metadata_col()` coverage for `notes`/`variable_labels`/
    `transformations` already lives, confirmed during task 76; resolved
    per §Files touched of `test-spec.md`'s "mirror that exact mechanism"
    instruction rather than `test-validators.R`.
  - `tests/testthat/_snaps/metadata-system.md` — new/updated snapshots
    for the two new error classes' `cli_abort()` messages (testthat
    strips the `test-` prefix from snapshot filenames).
  - `NAMESPACE` — generated by `devtools::document()`.
  - `man/set_var_extra.Rd`, `man/extract_var_extra.Rd` — generated by
    `devtools::document()`.
  - `man/survey_metadata.Rd` — regenerated by `devtools::document()` as a
    side effect of the `R/core-classes.R` `@param var_extra` addition.
  - `NEWS.md` — modified (entry for the new slot and functions).

  ### Pipeline split

  **recommended** — carried forward from `spec.md` §Pipeline split: this
  PR adds two new exported functions and a new S7 class property (a
  contract change to `survey_metadata`), which fails all four
  "optional" criteria in the pipeline-simplified smallness test (no new
  exported function / no numerical method change / no contract change /
  ≤3 files touched — this PR violates the first, third, and fourth).
