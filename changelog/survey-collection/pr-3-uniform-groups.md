# feat(classes)!: enforce uniform @groups across survey_collection members

**Date**: 2026-04-23
**Branch**: feature/survey-collection-groups
**Plan**: collection-uniform-groups

## Changes

- Add `@groups` property to `survey_collection` (S7 `class_character`, default
  `character(0)`). Class validator enforces three invariants after the existing
  C1–C4 checks: (G1) every member's `@groups` is `identical()` to
  `self@groups`, reporting the first divergent member by name; (G1b) when
  `@groups` is non-empty, every named column exists in every member's `@data`,
  reporting the first offending member + missing column; (G1c) `@groups` is
  well-formed (no `NA`, no `""`, no duplicates), with one `"i"` bullet per
  failing condition.
- Add `group =` argument to `as_survey_collection(..., group, .id,
  .on_missing)`. Named-only (after `...`). Accepts tidy-select column names
  (bare, `c()`, `all_of()`). Missing or empty-resolved `group` (including
  `NULL`, `character(0)`, `c()`, `all_of(character(0))`) collapses to the
  adopt-from-members branch; supplied non-empty `group` resolves via
  `tidyselect::eval_select()` against the first member's `@data`, validates
  that every other member has those columns (G3), and then for each member
  either silently propagates onto empty / matching `@groups` or overrides
  divergent non-empty `@groups` with a typed
  `surveycore_warning_collection_group_overridden` (G8) — one warning per
  divergent member. Final `survey_collection(surveys = ..., groups = target)`
  runs the validator as a backstop.
- Update `add_survey()` to propagate collection-level `@groups` onto any
  empty-grouped new member and error `surveycore_error_collection_group_conflict`
  (G4) on ungrouped-coll + grouped-new or grouped-coll + divergent-grouped-new.
  Build the full validated member list before the single final
  `survey_collection()` construction call so errors leave the caller's
  collection untouched (atomicity).
- Update `remove_survey()` to pass `groups = x@groups` through to the
  reconstructed `survey_collection()` call (one-line change). Without this,
  every removal silently de-grouped the collection.
- Add `.check_groups_match(candidate, target, error_class, context)` —
  order-sensitive equality check used by the validator to enforce G1.
  Deviates from spec §II by taking `error_class` explicitly (the spec
  listed only `context`); this matches the sibling `.propagate_or_match()`
  signature and removes the spec's hidden context → class lookup.
- Add `.propagate_or_match(candidate, target, name, error_class)` —
  propagates `target` when `candidate` is empty, returns `candidate` when
  already identical, errors `error_class` on non-empty mismatch. Used by
  `add_survey()` on the grouped-coll branch.
- Add `Groups: <vars>` line under the collection header in
  `print.survey_collection` when `length(x@groups) > 0L`.
- Add a `@section Collection grouping:` block to
  `.dispatch_over_collection()` documenting that per-survey `@groups` is
  guaranteed uniform by the class invariant, so
  `.resolve_groups()` at `R/analysis-helpers.R:441` sees the
  collection-level grouping without any dispatch-layer branching.
  Call-site `group =` stacks with `coll@groups` (Decision 5) — no code
  change; exercised by the dispatch regression tests.
- Add `test_collection_groups_invariant(coll)` helper in
  `tests/testthat/helper-test-data.R`. Used as the second assertion in
  every constructor-producing test block (after `test_invariants(coll)`).
- Add `tests/testthat/test-collection-groups.R` covering: the two
  internal helpers; all three validator invariants (G1 / G1b / G1c) with
  Layer 1 `class=`-only assertions; constructor happy paths
  (adopt-from-members, `group =` propagation, multi-var groups, all four
  empty-`group` forms); constructor override warning (G8); constructor
  error paths (G2, G3, C1 regression); the `add_survey()` Decision 2
  matrix (all 5 rows + atomicity); `remove_survey()` preservation + C1
  regression on removal to zero; G1b firing through the `add_survey()`
  propagation path; dispatch regressions confirming `coll@groups` columns
  come before call-site `group =` columns in the result; and
  grouped-vs-ungrouped print snapshots.

## Deferred (see `plans/decisions-collection-uniform-groups.md`, 2026-04-23 "defer `[[<-`")

- The spec's `[[<-` method on `survey_collection` was implemented end-to-end
  (all 126 tests passing locally) but removed before merge.
  `S7::method("[[<-", survey_collection) <- function(x, i, ..., value)`
  registers the method in the S3methods metadata with the function object
  in the method column rather than a character name; `tools::checkReplaceFuns`
  then coerces that entry to `""` and later calls `get("", envir = code_env)`,
  which fails with `invalid first argument` and surfaces as a spurious
  `R CMD check` WARNING. Option A (defer) was chosen over Option B (S4
  setMethod — rejected as hacky) and Option C (exported `replace_survey()`
  verb — rejected as surface-area growth for workaround sake). Error classes
  G5, G5b, G6, G7, G7b are deferred with the method; users mutate via
  `add_survey()` / `remove_survey()`. If a workaround lands later the method
  can be reinstated additively.

## Files Modified

- `R/core-classes.R` — add `@groups` property and three validator invariants
  (G1, G1b, G1c) to `survey_collection`.
- `R/core-constructors.R` — extend `as_survey_collection()` signature with
  `group = `, `.id = ".survey"`, `.on_missing = "error"`; implement the
  supplied / adopt-from-members branches per Decision 4; emit G8 per
  divergent member; construct with `groups = target`.
- `R/survey-collection.R` — add `.check_groups_match()` and
  `.propagate_or_match()` helpers; update `add_survey()` to enforce
  Decision 2 matrix with atomic final construction; update `remove_survey()`
  to pass `groups = x@groups` through; add `@section Collection grouping:`
  block to `.dispatch_over_collection()` docs.
- `R/methods-print.R` — print `Groups: <vars>` line under the
  `survey_collection` header when `@groups` is non-empty; block comment
  explaining why no `[[<-` method is registered and pointing at
  `add_survey()` / `remove_survey()`.
- `man/survey_collection.Rd`, `man/as_survey_collection.Rd` — regenerated
  from roxygen edits.
- `plans/error-messages.md` — add G1, G1b, G1c, G2, G3, G4, G8; include an
  italic note on the deferred G5 / G5b / G6 / G7 / G7b rows and the
  `checkReplaceFuns` reason.
- `tests/testthat/helper-test-data.R` — add
  `test_collection_groups_invariant()` helper.
- `NEWS.md` — add breaking-change bullet + three-bullet "Uniform grouping
  on `survey_collection`" section under `(development version)`.

## Files Created

- `plans/spec-collection-uniform-groups.md` — spec v0.4 (was v0.3 before the
  `[[<-` amendment).
- `plans/spec-review-collection-uniform-groups.md` — Stage 3 code/architecture
  review (Passes 1 + 2).
- `plans/spec-methods-review-collection-uniform-groups.md` — Stage 2 methods
  self-assessment (N/A — no statistical content).
- `plans/decisions-collection-uniform-groups.md` — Stage 4 decisions log
  covering Passes 1 + 2 spec resolution, Passes 1 + 2 plan-review resolution,
  and the implementation-time decision to defer `[[<-`.
- `plans/plan-review-collection-uniform-groups.md` — Passes 1 + 2 plan-review
  critique.
- `tests/testthat/test-collection-groups.R` — 81 tests across helpers, validator
  invariants, constructor, `add_survey()`, `remove_survey()`, G1b propagation,
  dispatch regressions, and print snapshots.
- `tests/testthat/_snaps/collection-groups.md` — cli snapshots for G2, G3, G4,
  G8 warning, and print output.

## Breaking change

Constructing a `survey_collection` from member surveys with divergent
`@groups` now errors `surveycore_error_collection_group_divergent` (G2).
Previously, a mixed-grouping collection would dispatch analysis functions
per-survey and stitch a patchwork of grouped and ungrouped rows together
via `bind_rows()`, violating the pseudo-data.frame mental model. Callers
must either share `@groups` across members or supply `group =` explicitly
on `as_survey_collection()`. Users who want the pre-change behavior can
rebuild their members ungrouped before constructing the collection.
