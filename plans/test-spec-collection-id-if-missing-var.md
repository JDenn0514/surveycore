# Test-spec — collection-id-if-missing-var

## Top-of-file conventions

- **`test_invariants()` placement rule**: `test_invariants(design)` is
  the **first assertion** in every `test_that()` block that constructs
  or retrieves a `survey_base` object from a collection. This applies
  to happy-path, error-path, and edge-case blocks alike. When a block
  uses multiple member surveys, every member is verified before any
  collection-level assertion runs. (See `.claude/rules/testing-surveycore.md`
  for the canonical wording.)
- **Migration audit (PR 2 prerequisite)**: see §Migration audit at the
  end of this file. Tester runs the audit before declaring PR 2 ready
  for review.
- **Coverage targets**: see §Coverage targets at the end of this file
  for the quantified per-path targets.

## Reference oracle

None. This work is API / state-management only — no numerical comparison
against `survey`, `srvyr`, or any external implementation. All
assertions are exact-equality / class-membership / structural checks.

## Datasets

- `make_survey_data(seed = ...)` — primary fixture for constructing
  every `survey_taylor` / `survey_replicate` / `survey_twophase` design
  used to populate test collections. Use one shared `seed` per test so
  collections are deterministic.
- Inline tiny `data.frame`s — used for edge-case scenarios that need
  specific atypical values (e.g., a one-variable frame for the
  `.if_missing_var = "skip"` precedence test where one collection
  member is missing the variable).
- `gss_2024` — only as needed for analysis-function smoke tests when
  asserting that the renamed `.if_missing_var` argument flows through a
  full `get_*()` call without numerical regression.

No new dataset additions. No real-data oracle.

## Per-function test plan

### `survey_collection` class — direct construction

- **Happy path**:
  - Construct with all defaults: `survey_collection(surveys = list(a = d))`
    where `d` is from `make_survey_data()`. Assert `coll@id == ".survey"`
    and `coll@if_missing_var == "error"`. First assertion in the block
    must be `test_invariants(d)` for the underlying survey object.
  - Construct with explicit `id = "wave"` and
    `if_missing_var = "skip"`. Assert both properties round-trip
    exactly via `expect_identical()`.
  - Construct with `id = "wave"` only (default `if_missing_var`).
    Assert mixed-default behavior.
- **Error paths** (Layer 1 — `class=`-only, no snapshot):
  - `id = c("a", "b")` → `surveycore_error_collection_invalid_id`.
  - `id = NA_character_` → `surveycore_error_collection_invalid_id`.
  - `id = ""` → `surveycore_error_collection_invalid_id`.
  - `id = 1L` (wrong type) → `surveycore_error_collection_invalid_id`.
  - `if_missing_var = "warn"` →
    `surveycore_error_collection_invalid_if_missing_var`.
  - `if_missing_var = NA_character_` →
    `surveycore_error_collection_invalid_if_missing_var`.
  - `if_missing_var = c("error", "skip")` →
    `surveycore_error_collection_invalid_if_missing_var`.
  - `if_missing_var = TRUE` (wrong type) →
    `surveycore_error_collection_invalid_if_missing_var`.
- **Edge cases**:
  - Default-construction round-trip: a freshly constructed default
    collection prints with both lines visible (covered under print
    tests).
  - All other invariants of the existing class continue to fire on
    invalid `surveys` / `groups`; spot-check one to ensure ordering of
    error reporting hasn't regressed (e.g., empty surveys list still
    raises `surveycore_error_collection_empty`).
- **Validator ordering test (dedicated block)**: construct
  `survey_collection(surveys = good, id = NA_character_, if_missing_var = "bogus")`
  where both `id` and `if_missing_var` are simultaneously invalid.
  Assert the `@id` validator fires first — the error class is
  `surveycore_error_collection_invalid_id`, **not**
  `surveycore_error_collection_invalid_if_missing_var`. This pins the
  ordering documented in spec.md (`@id` checked before
  `@if_missing_var`) so a future refactor can't silently swap the order.
- **Invariants**: every test that materializes a `survey_base` member
  asserts `test_invariants(member)` first.

### `as_survey_collection()`

- **Happy path**:
  - Default args: assert returned object has `@id == ".survey"`,
    `@if_missing_var == "error"`.
  - Explicit `.id = "wave"` and `.if_missing_var = "skip"`: assert both
    properties stored exactly.
  - Explicit `.id = "wave"` only, `.if_missing_var` defaulted: assert
    mixed.
  - Multiple surveys (2+ members): assert properties stored once on the
    collection (not per-member).
- **Error paths** (Layer 3 — dual: `expect_error(class=)` AND
  `expect_snapshot(error = TRUE)`):
  - `.id = NA_character_` →
    `surveycore_error_collection_invalid_id`.
  - `.id = c("a", "b")` →
    `surveycore_error_collection_invalid_id`.
  - `.id = ""` →
    `surveycore_error_collection_invalid_id`.
  - `.if_missing_var = "warn"` →
    `surveycore_error_collection_invalid_if_missing_var`.
  - `.if_missing_var = NA_character_` →
    `surveycore_error_collection_invalid_if_missing_var`.
- **Edge cases**:
  - Confirm the previously silent `.on_missing` argument no longer
    exists at this call site: calling `as_survey_collection(d, .on_missing = "skip")`
    raises an error (R's standard "unused argument" error — class-free,
    via `expect_error()` without a class).
  - Combining `.id` / `.if_missing_var` with `group =` produces a valid
    collection with all four pieces of state set as expected.
- **Invariants**: `test_invariants(member)` first for each survey
  member used in a constructor call.

### `.dispatch_over_collection()` precedence (verified via public
`get_*()` calls — no direct testing of the internal helper)

- **Happy path — `.id` precedence** (use `get_means(coll, y1)` against
  a 2-member collection of `make_survey_data()`-built designs):
  - Collection built with `.id = ".survey"` (default), call without
    `.id`: result column name is `".survey"`.
  - Collection built with `.id = "wave"`, call without `.id`: result
    column name is `"wave"`.
  - Collection built with `.id = "wave"`, call with explicit
    `.id = "year"`: result column name is `"year"` (call-site wins).
  - Collection built with `.id = ".survey"`, call with explicit
    `.id = "wave"`: result column name is `"wave"`.
- **Happy path — `.if_missing_var` precedence** (use a contrived
  collection where one member is missing the variable; build via
  trimmed inline frames):
  - Collection built with `.if_missing_var = "error"` (default), call
    without `.if_missing_var`: missing-variable behavior is the
    `surveycore_error_collection_missing_var` error.
  - Collection built with `.if_missing_var = "skip"`, call without
    `.if_missing_var`: missing surveys are skipped (informational
    `surveycore_message_collection_skipped_surveys`).
  - Collection built with `.if_missing_var = "skip"`, call with
    explicit `.if_missing_var = "error"`: error is raised (call-site
    wins over stored property).
  - Collection built with `.if_missing_var = "error"`, call with
    explicit `.if_missing_var = "skip"`: surveys are skipped (call-site
    wins).
- **Error paths**:
  - Existing `surveycore_error_collection_missing_var` snapshot must be
    refreshed to reflect the renamed hint string (`Set {.code
    .if_missing_var = "skip"} ...`).
  - All existing dispatcher error classes (`C5`, `C6`, `C7`, `C9`,
    `C13`, `C14`) continue to fire correctly. Spot-check one snapshot
    per class to confirm no message text regressed beyond the rename.
- **Edge cases**:
  - Calling `get_*(coll, ...)` with `.id = NULL` and a collection whose
    `@id` is `".survey"` produces the same result as today's default
    behavior (back-compat for the most common code path).
  - Calling with both args at default values on a default-constructed
    collection — output matches the legacy behavior byte-for-byte
    except for any renamed text.
- **Invariants**: `test_invariants(member)` first for every survey
  inside the test collection.

### `set_collection_id()`

- **Happy path**:
  - Default-constructed collection, set to `"wave"`: returned object's
    `@id == "wave"`. All other properties (`@surveys`, `@groups`,
    `@if_missing_var`) unchanged.
  - Returned object is invisible. Use the `withVisible()` idiom (per
    `.claude/rules/testing-surveycore.md`):

    ```r
    r <- withVisible(set_collection_id(coll, "wave"))
    expect_false(r$visible)
    expect_identical(r$value@id, "wave")
    ```

    The block must explicitly assert `r$visible == FALSE` and that the
    captured value carries the new `@id`. Do not use
    `expect_invisible()` shortcuts — `withVisible()` is the canonical
    pattern surveycore uses elsewhere for setter invisibility.
  - Idempotent: setting `@id` to its current value returns an
    equivalent object; no error / warning emitted.
- **Error paths** (Layer 3 — dual pattern):
  - `coll` is not a `survey_collection` →
    `surveycore_error_not_survey_collection`.
  - `id = NA_character_` →
    `surveycore_error_collection_invalid_id`.
  - `id = c("a", "b")` →
    `surveycore_error_collection_invalid_id`.
  - `id = ""` →
    `surveycore_error_collection_invalid_id`.
  - `id = 1L` →
    `surveycore_error_collection_invalid_id`.
- **Edge cases**:
  - After a successful set, downstream `get_*()` dispatch uses the new
    value (smoke test: `get_means(coll, y1)` column-name reflects the
    new `@id`).
  - Setting on a multi-member collection does not perturb member
    `@groups` / member `@data`.
- **Invariants**: `test_invariants(member)` first for every survey in
  the test collection.

### `set_collection_if_missing_var()`

- **Happy path**:
  - Default-constructed collection, set to `"skip"`: returned object's
    `@if_missing_var == "skip"`. All other properties unchanged.
  - Returned object is invisible. Use the `withVisible()` idiom:

    ```r
    r <- withVisible(set_collection_if_missing_var(coll, "skip"))
    expect_false(r$visible)
    expect_identical(r$value@if_missing_var, "skip")
    ```

    Same convention as `set_collection_id()` above.
  - Idempotent: setting to current value returns equivalent object;
    no error / warning emitted.
- **Error paths** (Layer 3 — dual pattern):
  - `coll` is not a `survey_collection` →
    `surveycore_error_not_survey_collection`.
  - `if_missing_var = "warn"` →
    `surveycore_error_collection_invalid_if_missing_var`.
  - `if_missing_var = NA_character_` →
    `surveycore_error_collection_invalid_if_missing_var`.
  - `if_missing_var = c("error", "skip")` →
    `surveycore_error_collection_invalid_if_missing_var`.
  - `if_missing_var = TRUE` →
    `surveycore_error_collection_invalid_if_missing_var`.
- **Edge cases**:
  - After a successful set, downstream `get_*()` dispatch uses the new
    value (smoke test: a missing-variable scenario raises vs skips
    according to the new property).
- **Invariants**: `test_invariants(member)` first for every survey in
  the test collection.

### `add_survey()` — property preservation

- **Happy path**:
  - Source collection built with `.id = "wave"` and
    `.if_missing_var = "skip"`. Append a survey via `add_survey()`.
    Resulting collection's `@id` and `@if_missing_var` are `identical()`
    to the source's.
  - Append zero surveys (`add_survey(coll)`): returned collection's
    `@id` and `@if_missing_var` are `identical()` (trivially, by early
    return).
  - Append multiple surveys at once: properties preserved.
- **Edge cases**:
  - Appending into a default-constructed collection preserves the
    default values (no rewrites).
  - Appending preserves properties even when name-repair fires (i.e.,
    `surveycore_warning_collection_duplicate_name_repaired` warning is
    raised).
- **Invariants**: `test_invariants(member)` first for every survey in
  the test collection.

### `remove_survey()` — property preservation

- **Happy path**:
  - Source collection built with non-default `.id` / `.if_missing_var`,
    multi-member. Remove one member by name. Result collection's
    `@id` and `@if_missing_var` are `identical()` to the source's.
  - Remove multiple members in one call: properties preserved.
- **Edge cases**:
  - Removing the last member would empty the collection — error
    `surveycore_error_collection_empty` fires (existing behavior). The
    error path does not need to test property preservation because no
    object is returned.
- **Invariants**: `test_invariants(member)` first for every survey in
  the test collection.

### `print(survey_collection)`

- **Happy path** (snapshot tests):
  - Default-constructed collection (one member,
    `@id == ".survey"`, `@if_missing_var == "error"`):
    `expect_snapshot(print(coll))` shows both new lines.
  - Non-default collection (`@id == "wave"`,
    `@if_missing_var == "skip"`): snapshot shows the non-default
    values.
  - Multi-member, grouped collection: snapshot still shows both new
    lines exactly once (not per-member).
- **Edge cases**:
  - Print on a freshly mutated collection (post `add_survey()`) renders
    the preserved property values — covered by the
    `add_survey()`/`remove_survey()` round-trip tests above with an
    additional `expect_snapshot(print(...))` call.
- **Invariants**: `test_invariants(member)` first for every survey in
  the test collection.

### Every `get_*()` with a collection dispatch branch — argument rename

The full set of functions is: `get_means`, `get_totals`, `get_freqs`,
`get_ratios`, `get_diffs`, `get_corr`, `get_variance`,
`get_quantiles`, `get_covariance`, `get_t_test`, `get_pairwise`
(11 functions, 10 source files — `analysis-t-test.R` owns
`get_t_test()` and `get_pairwise()`).

**Test scope split**:

- **Canonical precedence function — `get_means()`**: `get_means()` is
  the **single** `get_*()` function used to verify the four
  precedence scenarios for `.id` and the four scenarios for
  `.if_missing_var`. Those eight scenarios live in the
  `.dispatch_over_collection()` precedence block above (which
  exercises the dispatcher via `get_means()`). They are not repeated
  for any other function. Justification: precedence is enforced
  inside `.dispatch_over_collection()`, which is called identically
  by every analysis function — duplicating the four-by-four matrix
  10 times would be redundant.
- **Rename-only tests for the other 10 functions** (`get_totals`,
  `get_freqs`, `get_ratios`, `get_diffs`, `get_corr`,
  `get_variance`, `get_quantiles`, `get_covariance`, `get_t_test`,
  `get_pairwise`): each gets exactly one test block confirming:
  - Calling with `.if_missing_var = "skip"` succeeds (no syntax /
    signature error).
  - Calling with the old name `.on_missing = "skip"` raises R's
    standard "unused argument" error (`expect_error()` without a
    class). This confirms no compatibility shim leaked through.
  No precedence assertions, no `.id` matrix, no per-scenario
  snapshots — just the rename smoke test.

- **Snapshot updates**:
  - Every existing `_snaps/` entry that pinned the old `.on_missing`
    string must be regenerated. Tester reviews each diff individually
    (no `snapshot_accept()`).
- **Invariants**: `test_invariants(member)` first for every survey in
  the test collection.

### `NEWS.md` and `plans/error-messages.md` content checks

These are not unit tests but are part of the test-spec coverage so the
tester confirms they exist before the audit closes:

- `NEWS.md` contains a `# surveycore (development version)` heading and
  a `## Breaking changes` block under it. The block mentions the
  rename of `.on_missing` → `.if_missing_var`, the no-longer-silent
  behavior of `as_survey_collection()`, and the two new exported
  setters.
- `plans/error-messages.md` contains a row whose error class column is
  `surveycore_error_collection_invalid_if_missing_var` in the
  `survey_collection` block.
- The `Coverage Map` at the bottom of `plans/error-messages.md` lists
  the new class in `test-survey-collection.R`'s row.

## Tolerances

(No numerical tests in this work. Defaults retained for completeness.)

- Point estimates: 1e-10
- SE / variance: 1e-8
- CI bounds: 1e-6
- Deviations (with justification): none.

## Migration audit (PR 2 prerequisite)

Before PR 2 can merge, the tester runs the following audit and records
the results in the PR description. The audit confirms the rename is
truly global — no `.on_missing` literal or hint string survives outside
`NEWS.md`.

1. **Source audit (`R/`)**: grep `R/` for the literal string
   `.on_missing`. Expected matches: zero, after PR 2 lands. Any match
   blocks the merge.
2. **Test audit (`tests/testthat/`)**: grep `tests/testthat/` for the
   literal string `.on_missing`. Every match must be either:
   (a) renamed to `.if_missing_var` if it was a real call site, or
   (b) repurposed into the deliberate rename-test block (`expect_error()`
   on `.on_missing = ...`) if it was asserting that the old name no
   longer works.
3. **Snapshot audit (`tests/testthat/_snaps/`)**: grep `_snaps/` for
   `.on_missing`. Every match is in a snapshot file pinned to old hint
   text. For each affected snapshot, run
   `testthat::snapshot_review()` and individually approve each diff
   (no `snapshot_accept()`).
4. **Roxygen audit (`man/`)**: regenerate via `devtools::document()`
   and grep `man/` for `.on_missing`. Expected matches: zero.
5. **NEWS.md exception**: `NEWS.md` may reference `.on_missing` in the
   breaking-changes entry. This is the only acceptable mention.

The audit is recorded as a checklist in the PR 2 description with a
line-count for each grep step.

## Coverage targets

New code paths must hit ≥98% line coverage as measured by
`covr::package_coverage()`. The specific paths the tester must verify:

| Code path | Target |
|-----------|--------|
| `.validate_collection_id()` body (all 4 reject branches: NA, length 0, length > 1, non-character; plus the success branch) | ≥98% line, all 5 branches covered |
| `.validate_collection_if_missing_var()` body (all 4 reject branches: NA, not in `c("error", "skip")`, length > 1, non-character; plus the success branch) | ≥98% line, all 5 branches covered |
| `set_collection_id()` body (the `S7::S7_inherits()` reject branch and the happy path) | 100% line |
| `set_collection_if_missing_var()` body (same shape) | 100% line |
| `.dispatch_over_collection()` precedence resolution (4 branches: `.id` non-NULL, `.id` NULL → stored; `.if_missing_var` non-NULL, `.if_missing_var` NULL → stored) | 100% branch |
| `print(survey_collection)` extension lines (the new `id:` and `if_missing_var:` lines, both rendered unconditionally) | 100% line |
| `add_survey()` and `remove_survey()` property-forward lines (the lines that pass `id = ` and `if_missing_var = ` to the inner `survey_collection(...)` call) | 100% line |

Overall package coverage target remains ≥95%; the new-code-path target
is ≥98% per row above.

## Profile gates

- [ ] devtools::document() clean (no roxygen warnings; NAMESPACE diff
      contains the two new exports plus removal of nothing else).
- [ ] devtools::test() all pass; new test files for setters and
      precedence are picked up.
- [ ] devtools::run_examples() all pass — examples on
      `as_survey_collection()`, the two new setters, and any updated
      `get_*()` examples must run cleanly.
- [ ] R CMD check --as-cran (0 err, 0 warn, ≤ 2 pre-approved notes).
- [ ] pkgcheck PASS — at least no regressions vs the prior pkgcheck
      baseline.
- [ ] pkgdown::build_site() clean — the rendered references for the new
      setters and the updated `as_survey_collection()` show the
      corrected prose.
- [ ] covr::package_coverage() ≥ 95 % overall (target 98 %); new code
      paths ≥ 98 %.
- [ ] CRAN cookbook scan clean (see r-package-profile.md).
