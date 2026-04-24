# Spec — collection-id-if-missing-var

**Status**: DRAFT
**Target version**: 0.7.2.9000
**PR range**: PR 1–2

## Scope

### In

1. Add two new properties to the `survey_collection` S7 class:
   - `id`: `character(1)`, default `".survey"`. Validator: length 1, character,
     non-`NA`, non-empty (`nzchar`). Error class on validation failure:
     `surveycore_error_collection_invalid_id` (existing class, reused).
   - `if_missing_var`: `character(1)`, default `"error"`. Validator: must be
     one of `c("error", "skip")`. Error class on validation failure:
     `surveycore_error_collection_invalid_if_missing_var` (NEW — added to
     `plans/error-messages.md`).
2. Update `as_survey_collection()`: replace the silent no-op `.on_missing`
   argument with `.if_missing_var`; keep `.id`. Wire both arguments through
   to the `survey_collection()` constructor so they are stored on the
   returned object's `@id` and `@if_missing_var` properties. Validate both
   args at the constructor with the same error classes the S7 validator
   uses, so user-facing CLI formatting is preserved.
3. Rename the dispatcher helper argument and every public-facing argument
   from `.on_missing` to `.if_missing_var`. Values unchanged: `"error"`
   (default) or `"skip"`. No deprecation shim — pre-1.0 breaking rename.
4. Re-specify `.dispatch_over_collection()` precedence as a two-tier fallback:
   call-site non-`NULL` value beats stored property value. Because the class
   guarantees a non-`NULL` default for both properties, no third fallback
   tier is needed at dispatch time.
5. Flip the analysis-function defaults: every `get_*()` with a collection
   dispatch branch becomes `.id = NULL, .if_missing_var = NULL` and forwards
   the raw values to `.dispatch_over_collection()`. For non-collection
   inputs these arguments remain unused (no behavioral change).
6. Add two new exported setters with `@family collections`. Both follow
   surveycore's existing setter convention (`set_var_label(x, ...)`,
   `set_val_labels(x, ...)`, etc.) and use `x` as the first parameter:
   - `set_collection_id(x, id)` — returns `invisible(x)`.
   - `set_collection_if_missing_var(x, if_missing_var)` — returns
     `invisible(x)`.
   Each validates its argument via the new internal validator helpers
   and raises the same error class the S7 validator does. Both are
   plain functions (not S7 methods on a generic) per
   `.claude/rules/code-style.md` §4 — the first thing each does is
   `if (!S7::S7_inherits(x, survey_collection))` (class object, never
   a string), throwing `surveycore_error_not_survey_collection` (existing
   class) on failure.
7. `add_survey()` and `remove_survey()` preserve `@id` and
   `@if_missing_var` across the mutation. Whichever code path returns a new
   `survey_collection`, both properties carry over from the source
   collection.
8. Update the `print` method for `survey_collection` to display both `@id`
   and `@if_missing_var` on every print (always, not conditionally — see
   Architecture §Print decision below).
9. Rename every existing `.on_missing` mention in error/hint text and
   roxygen prose to `.if_missing_var`. Update every snapshot file that
   pinned the old hint string.
10. Add a `# surveycore (development version)` / `## Breaking changes`
    block to `NEWS.md` covering: (a) the rename of `.on_missing` →
    `.if_missing_var` on every `get_*()`, (b) the silent-no-op behavior
    change on `as_survey_collection()`, and (c) the two new class
    properties + two new setters.

### Out

- No numerical changes. No estimator behavior is altered.
- No new analysis functions.
- No changes to non-collection code paths in any `get_*()` (when `design`
  is a single survey, the new arguments are inert).
- No deprecation / backwards-compatible shim for `.on_missing` (package is
  pre-1.0; per request).
- No removal of any existing error class, only one addition.
- No changes to `@groups` semantics or to G-series error classes.
- No changes to `survey_collection` element-type validators (`C1`, `C2`,
  `C3`, `C4`, `C8`, etc.).
- No changes to the polychoric/polyserial dispatcher behavior.

## Architecture

### Files touched (write surface)

PR 1 (class + constructor + dispatcher precedence + setters + print):

- `R/core-classes.R` — add two properties + two validator branches to
  `survey_collection`. Both branches delegate to the new validator
  helpers (see §Internal helpers below).
- `R/core-constructors.R` — replace `.on_missing` with `.if_missing_var`
  in `as_survey_collection()`, wire both new args to the constructor,
  rewrite the misleading roxygen. Constructor calls the validator
  helpers on `.id` and `.if_missing_var` before forwarding to
  `survey_collection(...)`.
- `R/survey-collection.R` — update `.dispatch_over_collection()` signature
  and precedence resolution; add `set_collection_id()` and
  `set_collection_if_missing_var()`; add the two new internal validator
  helpers `.validate_collection_id()` and
  `.validate_collection_if_missing_var()`; verify `add_survey()` and
  `remove_survey()` carry `@id` / `@if_missing_var` through (small fix
  in the final `survey_collection(...)` call sites).
- The file that owns `print(survey_collection)` — extend the existing
  print method to render the two new property lines. (One-line change at
  the writer's discretion of file location.)
- `plans/error-messages.md` — add one new row for
  `surveycore_error_collection_invalid_if_missing_var`. **PR 1
  acceptance criterion**: before any implementation lands, this row
  must already exist in `plans/error-messages.md` adjacent to the
  existing `surveycore_error_collection_invalid_id` row, with the cli
  template specified in §New error class below.
- `NEWS.md` — add the breaking-changes entry.

### Internal helpers (added in PR 1)

Both helpers live in `R/survey-collection.R`. Both are not exported and
prefixed with `.` per `.claude/rules/code-style.md` §4. They centralise
the validation logic that would otherwise be duplicated across the S7
validator, the constructor, the dispatcher's resolution branch, and the
two setters — five call sites per property.

- `.validate_collection_id(value, arg_name)` — accepts the value and the
  user-facing argument label (one of `"id"`, `".id"`). Raises
  `surveycore_error_collection_invalid_id` (existing class) when
  `value` is not a length-1 non-`NA` non-empty character string. Returns
  `invisible(value)` on success.
- `.validate_collection_if_missing_var(value, arg_name)` — accepts the
  value and the user-facing argument label (one of `"if_missing_var"`,
  `".if_missing_var"`). Raises
  `surveycore_error_collection_invalid_if_missing_var` (NEW class) when
  `value` is not a length-1 non-`NA` character string in
  `c("error", "skip")`. Returns `invisible(value)` on success.

Five call sites per helper:

| Call site | Helper invoked | `arg_name` passed |
|-----------|----------------|-------------------|
| S7 class validator (`survey_collection` validator branch) | both | `"id"` / `"if_missing_var"` |
| `as_survey_collection()` constructor | both | `".id"` / `".if_missing_var"` |
| `.dispatch_over_collection()` (after resolution) | both | `".id"` / `".if_missing_var"` |
| `set_collection_id()` | id helper only | `"id"` |
| `set_collection_if_missing_var()` | if_missing_var helper only | `"if_missing_var"` |

PR 2 (rename `.on_missing` → `.if_missing_var` across all analysis
functions + snapshot churn):

- Every `get_*()` analysis source file that contains a
  `.dispatch_over_collection()` forwarding branch:
  - `analysis-means.R`
  - `analysis-totals.R`
  - `analysis-freqs.R`
  - `analysis-ratios.R`
  - `analysis-diffs.R`
  - `analysis-corr.R`
  - `analysis-variance.R`
  - `analysis-quantiles.R`
  - `analysis-covariance.R`
  - `analysis-t-test.R` (covers both `get_t_test()` and `get_pairwise()`)
- Snapshot files under `tests/testthat/_snaps/` that pin the
  `.on_missing` literal in any error / hint string.
- Roxygen `@param` lines for the renamed argument on every affected
  function.

### Functions added

- `set_collection_id(x, id)` — exported. Plain function (not an S7
  method); first check is `S7::S7_inherits(x, survey_collection)`
  against the class object, throwing
  `surveycore_error_not_survey_collection` on failure.
- `set_collection_if_missing_var(x, if_missing_var)` — exported. Same
  dispatch and type-check pattern as above.
- `.validate_collection_id(value, arg_name)` — internal helper.
- `.validate_collection_if_missing_var(value, arg_name)` — internal
  helper.

### Functions modified (signatures)

- `survey_collection(surveys = list(), groups = character(0),
  id = ".survey", if_missing_var = "error")` — two new properties, both
  defaulted.
- `as_survey_collection(..., group, .id = ".survey", .if_missing_var = "error")`
  (was: `.on_missing = "error"`).
- `.dispatch_over_collection(fn, collection, ..., .id = NULL, .if_missing_var = NULL)`
  (was: `.id = ".survey", .on_missing = c("error", "skip")`).
- Every `get_*()` with a collection dispatch branch — **11 functions**
  across 10 source files (`analysis-t-test.R` owns both `get_t_test()`
  and `get_pairwise()`). Canonical list, derived by grepping `R/` for
  call sites of `.dispatch_over_collection(`:
  `get_means`, `get_totals`, `get_freqs`, `get_ratios`, `get_diffs`,
  `get_corr`, `get_variance`, `get_quantiles`, `get_covariance`,
  `get_t_test`, `get_pairwise`. The trailing two args become
  `.id = NULL, .if_missing_var = NULL`. The dispatch-branch body forwards
  the two values verbatim to `.dispatch_over_collection()`.

### Class changes

- `survey_collection` gains two properties:
  - `id` — `S7::class_character` with `default = ".survey"`.
  - `if_missing_var` — `S7::class_character` with `default = "error"`.
- New validator branches (run before the existing C1/C2/C4/G1/G1b/G1c
  block; ordering keeps the most descriptive error first when multiple
  invariants would fire):
  - If `length(self@id) != 1L || !is.character(self@id) ||
    is.na(self@id) || !nzchar(self@id)`, raise
    `surveycore_error_collection_invalid_id`.
  - If `length(self@if_missing_var) != 1L ||
    !is.character(self@if_missing_var) ||
    is.na(self@if_missing_var) ||
    !(self@if_missing_var %in% c("error", "skip"))`, raise
    `surveycore_error_collection_invalid_if_missing_var`.

### Print decision (D8)

The `survey_collection` print method shows both `@id` and
`@if_missing_var` on **every** print, regardless of whether they hold the
default values. Justification: predictable output beats conditional
rendering — users always see the resolution rules in effect, and the
two extra lines do not crowd the existing output. Rendering format is
left to the writer but must be cli-formatted in the same style as the
existing `surveys:` / `groups:` lines (e.g.,
`id: ".survey"` and `if_missing_var: "error"`).

## Function contracts

### `survey_collection` (S7 class)

- **Properties**:
  - `surveys`: named list of `survey_base` objects (existing).
  - `groups`: character vector, default `character(0)` (existing).
  - `id`: `character(1)`, default `".survey"`. Stored on the collection
    and consumed by `.dispatch_over_collection()` as the per-call default.
  - `if_missing_var`: `character(1)`, default `"error"`. Must be one of
    `c("error", "skip")`. Stored on the collection and consumed by
    `.dispatch_over_collection()` as the per-call default.
- **Validators** (Layer 1, structural — `class=`-only, no snapshot):
  - `surveycore_error_collection_invalid_id` — when `@id` is not a
    single non-empty non-`NA` character string.
  - `surveycore_error_collection_invalid_if_missing_var` — when
    `@if_missing_var` is not a length-1 non-`NA` character string in
    `c("error", "skip")`.
  - All existing validators (`C1`/`C2`/`C4`/`G1`/`G1b`/`G1c`) continue to
    apply and remain unchanged.
- **Edge cases**:
  - `id = NA_character_` → `surveycore_error_collection_invalid_id`.
  - `id = ""` (empty string) → `surveycore_error_collection_invalid_id`.
  - `id = c("a", "b")` (length > 1) →
    `surveycore_error_collection_invalid_id`.
  - `id = 1L` or any non-character type →
    `surveycore_error_collection_invalid_id`.
  - `id = NULL` → `surveycore_error_collection_invalid_id` (length 0
    fails the length-1 check; `NULL` is not character).
  - `if_missing_var = NA_character_` →
    `surveycore_error_collection_invalid_if_missing_var`.
  - `if_missing_var = "warn"` (or any string outside
    `c("error", "skip")`) →
    `surveycore_error_collection_invalid_if_missing_var`.
  - `if_missing_var = c("error", "skip")` (length > 1) →
    `surveycore_error_collection_invalid_if_missing_var`.
  - `if_missing_var = TRUE` or any non-character type →
    `surveycore_error_collection_invalid_if_missing_var`.
- **Direct S7 construction**: calling
  `survey_collection(surveys = ..., id = ..., if_missing_var = ...)`
  directly (bypassing `as_survey_collection()`) routes through the S7
  class validator, which calls the same two helpers
  (`.validate_collection_id()`,
  `.validate_collection_if_missing_var()`) — so the same error
  classes fire whether the user reaches the validator via the S7
  constructor or via `as_survey_collection()`.
- **Validator ordering**: `@id` is validated **before**
  `@if_missing_var`. When both are simultaneously invalid, the `@id`
  error fires first. (Tester verifies via dedicated ordering test —
  see test-spec.)

### `as_survey_collection()`

- **Signature**:
  `as_survey_collection(..., group, .id = ".survey", .if_missing_var = "error")`
- **Arguments**:
  - `...` — one or more `survey_base` objects (existing semantics).
  - `group` — tidy-select grouping spec (existing semantics).
  - `.id` — character(1), name of the identifier column injected by
    `.dispatch_over_collection()`. Stored on `coll@id`. Validated
    user-side: must be a length-1 non-`NA` non-empty character string.
  - `.if_missing_var` — character(1), one of `c("error", "skip")`.
    Stored on `coll@if_missing_var`. Validated user-side.
- **Returns**: a `survey_collection` whose `@id` and `@if_missing_var`
  hold the resolved argument values.
- **Errors**:
  - `surveycore_error_collection_invalid_id` — invalid `.id`. CLI
    message uses the existing template (`{.arg .id} must be a single
    non-empty, non-NA character string.`).
  - `surveycore_error_collection_invalid_if_missing_var` — invalid
    `.if_missing_var`. CLI message: see "New error class" below.
  - All existing constructor error classes (C1, C2a-warning, C3, G2,
    G3, G8-warning) continue to apply.
- **Edge cases**:
  - When both `.id` and `.if_missing_var` are at their default values,
    behavior matches today's collection w.r.t. dispatch resolution
    (the previously silently-ignored `.on_missing` is now honored).
  - `.id = NA_character_` → `surveycore_error_collection_invalid_id`.
  - `.id = ""` (empty string) →
    `surveycore_error_collection_invalid_id`.
  - `.id = c("a", "b")` (length > 1) →
    `surveycore_error_collection_invalid_id`.
  - `.id` of any non-character type →
    `surveycore_error_collection_invalid_id`.
  - `.if_missing_var = NA_character_` →
    `surveycore_error_collection_invalid_if_missing_var`.
  - `.if_missing_var = "warn"` (or any string outside
    `c("error", "skip")`) →
    `surveycore_error_collection_invalid_if_missing_var`.
  - `.if_missing_var = c("error", "skip")` (length > 1) →
    `surveycore_error_collection_invalid_if_missing_var`.
  - `.if_missing_var` of any non-character type →
    `surveycore_error_collection_invalid_if_missing_var`.
- **Validation routing**: the constructor calls
  `.validate_collection_id(.id, ".id")` and
  `.validate_collection_if_missing_var(.if_missing_var, ".if_missing_var")`
  before forwarding to `survey_collection(...)`. The S7 class
  validator runs the same two helpers a second time on the resulting
  object — defensive but free, since both helpers are pure.
- **Roxygen correction**: remove the misleading "Stored on the collection
  for later consumption" claim from the existing prose for `.id`. Replace
  with a precise statement: "Stored on the returned collection's `@id`
  property and used as the default by `.dispatch_over_collection()` when
  a per-call `.id` is not supplied." Equivalent prose for
  `.if_missing_var`.

### `.dispatch_over_collection()`

- **Signature** (internal):
  `.dispatch_over_collection(fn, collection, ..., .id = NULL, .if_missing_var = NULL)`
- **Precedence**:
  - `resolved_id <- .id %||% collection@id`
  - `resolved_if_missing_var <- .if_missing_var %||% collection@if_missing_var`
- **Behavior**: identical to today's behavior with `resolved_id` /
  `resolved_if_missing_var` substituted for the previously hard-coded
  `.id` / `.on_missing` values. The existing validation (`.id` must be a
  single non-empty non-`NA` character string; `.if_missing_var` must be
  one of `c("error", "skip")`) runs against the resolved values.
- **Error / hint text rename**: the hint that currently reads `Set
  {.code .on_missing = "skip"} ...` (in the
  `surveycore_error_collection_missing_var` error body) becomes `Set
  {.code .if_missing_var = "skip"} ...`. No error class is renamed.
- **Returns**: same as today — a tibble with the same S3 class as the
  per-survey result; `.meta` carries `per_survey` and `collection`.
- **Edge cases**:
  - When the caller passes `.id = NULL` and the collection's `@id` is
    `".survey"`, the column name is `".survey"`. When the caller passes
    `.id = "wave"`, the column name is `"wave"` regardless of the
    collection's `@id`. Same precedence applies to `.if_missing_var`.
  - **All-skipped under precedence**: when `.if_missing_var` resolves
    to `"skip"` (whether from call-site or stored property) and every
    member of the collection is missing the requested variable, the
    existing `surveycore_error_collection_all_skipped` path fires
    unchanged. Resolution does not alter the all-skipped detection
    logic — only the gate that decides whether to skip vs error in
    the first place.
  - **Id collision under precedence**: the existing
    `surveycore_error_collection_id_collision` path fires identically
    whether the resolved `.id` came from call-site or stored `@id`.
    When the collision is triggered by a stored `@id` (i.e., the
    caller passed `.id = NULL` and the collection's `@id` clashed with
    an analysis-function output column), the cli `"v"` bullet must
    mention `set_collection_id()` as a fix path *in addition to* the
    existing call-site `.id =` override hint. Concretely, the bullet
    reads (when stored): "Pass a different {.arg .id} to override
    (e.g., {.code .id = \"wave\"}) or update the stored property via
    {.fn set_collection_id}."
  - **Validation timing**: because the S7 class validator guarantees
    `@id` and `@if_missing_var` are always valid for any
    `survey_collection` object that exists at runtime, the
    dispatcher's resolved values are guaranteed valid whenever they
    fall back to the stored properties. No defensive re-checks are
    needed on the stored branch. The dispatcher still validates the
    resolved values via the helpers — but only as a single
    post-resolution gate, not as a per-branch check.

### `set_collection_id(x, id)`

- **Signature**: `set_collection_id(x, id)`
- **Dispatch**: plain function (not an S7 method on a generic), per
  `.claude/rules/code-style.md` §4. First operation is an
  `S7::S7_inherits(x, survey_collection)` check against the class
  object — never a string — throwing
  `surveycore_error_not_survey_collection` on failure.
- **Arguments**:
  - `x` — a `survey_collection`. (First parameter named `x` to match
    every existing surveycore setter, e.g. `set_var_label(x, ...)`.)
  - `id` — character(1), non-`NA`, non-empty.
- **Returns**: `invisible(x)` with `x@id` updated. The `invisible(x)`
  return supports the canonical pipeline pattern:
  `coll |> set_collection_id("wave") |> get_means(y)` returns the
  expected `get_means()` result; the intermediate setter does not print
  but its value flows through the pipe.
- **Errors**:
  - `surveycore_error_not_survey_collection` — when `x` is not a
    `survey_collection`. (Existing class.)
  - `surveycore_error_collection_invalid_id` — when `id` is not a
    length-1 non-`NA` non-empty character string. Raised by the shared
    helper `.validate_collection_id(id, "id")`. (Existing class.)
- **Edge cases**:
  - Setting the same value as the existing `@id` returns the collection
    unchanged (no error, no warning). All other invariants on the
    collection (`@surveys`, `@groups`, `@if_missing_var`) are preserved.
  - `id = NA_character_` → `surveycore_error_collection_invalid_id`.
  - `id = ""` (empty string) → `surveycore_error_collection_invalid_id`.
  - `id = c("a", "b")` (length > 1) →
    `surveycore_error_collection_invalid_id`.
  - `id = 1L` or any non-character type →
    `surveycore_error_collection_invalid_id`.

### `set_collection_if_missing_var(x, if_missing_var)`

- **Signature**: `set_collection_if_missing_var(x, if_missing_var)`
- **Dispatch**: plain function (not an S7 method on a generic), per
  `.claude/rules/code-style.md` §4. First operation is an
  `S7::S7_inherits(x, survey_collection)` check against the class
  object — never a string — throwing
  `surveycore_error_not_survey_collection` on failure.
- **Arguments**:
  - `x` — a `survey_collection`. (First parameter named `x` to match
    every existing surveycore setter.)
  - `if_missing_var` — character(1), one of `c("error", "skip")`.
- **Returns**: `invisible(x)` with `x@if_missing_var` updated. The
  `invisible(x)` return supports the canonical pipeline pattern:
  `coll |> set_collection_if_missing_var("skip") |> get_means(y)`
  returns the expected `get_means()` result; the intermediate setter
  does not print but its value flows through the pipe.
- **Errors**:
  - `surveycore_error_not_survey_collection` — when `x` is not a
    `survey_collection`. (Existing class.)
  - `surveycore_error_collection_invalid_if_missing_var` — when
    `if_missing_var` is not a length-1 character string in
    `c("error", "skip")`. Raised by the shared helper
    `.validate_collection_if_missing_var(if_missing_var, "if_missing_var")`.
    (NEW class.)
- **Edge cases**:
  - Setting the same value as the existing `@if_missing_var` returns
    the collection unchanged (no error, no warning). All other
    invariants on the collection are preserved.
  - `if_missing_var = NA_character_` →
    `surveycore_error_collection_invalid_if_missing_var`.
  - `if_missing_var = "warn"` (any string outside `c("error", "skip")`)
    → `surveycore_error_collection_invalid_if_missing_var`.
  - `if_missing_var = c("error", "skip")` (length > 1) →
    `surveycore_error_collection_invalid_if_missing_var`.
  - `if_missing_var = TRUE` or any non-character type →
    `surveycore_error_collection_invalid_if_missing_var`.

### `add_survey()` / `remove_survey()`

- **Signature**: unchanged.
- **Behavior change**: each of these functions terminates by calling the
  `survey_collection()` constructor with the new `surveys` / `groups`
  arguments. Both functions must additionally pass `id = .collection@id`
  (or `id = x@id`) and `if_missing_var = .collection@if_missing_var` (or
  `if_missing_var = x@if_missing_var`) so the returned collection
  preserves the source collection's properties.
- **Returns**: a new `survey_collection` whose `@id` and `@if_missing_var`
  match the source collection's. All existing return behavior preserved.
- **Errors / warnings**: unchanged.
- **Preservation invariant** (must hold for every accepted call —
  including non-default `@id` / `@if_missing_var`):
  - `identical(add_survey(coll, ...)@id, coll@id) == TRUE`
  - `identical(add_survey(coll, ...)@if_missing_var, coll@if_missing_var) == TRUE`
  - `identical(remove_survey(coll, ...)@id, coll@id) == TRUE`
  - `identical(remove_survey(coll, ...)@if_missing_var, coll@if_missing_var) == TRUE`
  These hold across every code path that returns a new collection,
  including: appending zero surveys, appending multiple, name-repair
  paths, and removal of any subset (so long as the result is non-empty).
- **Edge cases**: `add_survey(coll)` (no arguments forwarded) returns
  `coll` unchanged — `@id` and `@if_missing_var` are trivially preserved
  by the early return.

### Every `get_*()` with a collection dispatch branch

The following 11 functions (across 10 source files —
`analysis-t-test.R` owns both `get_t_test()` and `get_pairwise()`) all
share the same shape change. Canonical list confirmed by grepping `R/`
for `.dispatch_over_collection(`:

- `get_means`, `get_totals`, `get_freqs`, `get_ratios`, `get_diffs`,
  `get_corr`, `get_variance`, `get_quantiles`, `get_covariance`,
  `get_t_test`, `get_pairwise`.

- **Signature change** (suffix only): the pair of trailing named-only
  arguments
  - was: `.id = ".survey", .on_missing = "error"`
  - becomes: `.id = NULL, .if_missing_var = NULL`
- **Behavior**:
  - Non-collection input: arguments are inert. No behavioral change.
  - Collection input: forward both values verbatim to
    `.dispatch_over_collection(fn, design, ..., .id = .id,
    .if_missing_var = .if_missing_var)`. Resolution against the
    collection's stored properties happens inside the dispatcher.
- **Errors**: unchanged. New error classes inherited via the dispatcher
  apply when invalid values are forwarded.
- **Roxygen**: every `@param .on_missing` line is renamed to
  `@param .if_missing_var`. Where the prose mentioned `.on_missing`,
  rename. Both `@param .id` and `@param .if_missing_var` on every
  affected `get_*()` must include the canonical NULL-means-fallback
  clause, copied verbatim:

  > For collection inputs, `NULL` (the default) resolves to the
  > collection's stored `@id` / `@if_missing_var` property. Pass a
  > non-`NULL` value to override.

  The full precedence rule is documented exactly **once**, in the
  internal `.dispatch_over_collection()` roxygen header. Each
  `get_*()` either (a) repeats the short clause above or (b) uses
  `@inheritParams .dispatch_over_collection` and lets the inherited
  prose carry the NULL-fallback semantics. Builder picks one of the
  two patterns and applies it consistently across all 11 functions.

### `print(survey_collection)`

- **Signature**: unchanged (S7 method on the existing generic).
- **Behavior**: in addition to the existing rendering of `surveys:` and
  `groups:`, append two lines that display the values of `@id` and
  `@if_missing_var`. Both lines are emitted on every call — no
  conditional rendering on default vs non-default.
- **Returns**: `invisible(x)` (existing).
- **Edge cases**: line ordering is at the writer's discretion as long as
  the new lines appear within the collection-summary block (not
  separated by survey-by-survey output).
- **Sample rendering** (literal, default-constructed collection with
  one member named `"a"`):

  ```
  <survey_collection>
  surveys: "a"
  groups: <none>
  id: ".survey"
  if_missing_var: "error"
  ```

  And for a non-default collection (`@id = "wave"`,
  `@if_missing_var = "skip"`, two members):

  ```
  <survey_collection>
  surveys: "y2018", "y2020"
  groups: <none>
  id: "wave"
  if_missing_var: "skip"
  ```

  Exact cli formatting (colour, brackets) is at the writer's
  discretion; the relative ordering of the four lines and the literal
  property names (`id:`, `if_missing_var:`) are not.

## New error class

To be added to `plans/error-messages.md` (single new row, in the
`survey_collection rows (PR 1)` block):

| # | Function | Condition | Level | Error Class | cli Message Template |
|---|----------|-----------|-------|-------------|----------------------|
| C15 | S7 validator (`survey_collection`) / `as_survey_collection()` / `set_collection_if_missing_var()` | `.if_missing_var` / `if_missing_var` is not a length-1 character string in `c("error", "skip")` | ERROR | `surveycore_error_collection_invalid_if_missing_var` | `"x" = "{.arg .if_missing_var} must be one of {.val \"error\"} or {.val \"skip\"}.", "i" = "Got {.cls {class(if_missing_var)[[1L]]}} of length {.val {length(if_missing_var)}}: {.val {if_missing_var}}."` |

The constructor / setter call sites use `{.arg .if_missing_var}` /
`{.arg if_missing_var}` per their argument names; the validator branch
uses `{.arg if_missing_var}` (property name).

Coverage map line in `plans/error-messages.md` is updated:
`test-survey-collection.R | C1, C2, C2a, C3, C4, C8, C13, C15`.

## Quality gates

Invariants that must hold before any PR in this plan merges:

- For every `survey_collection` instance produced by any constructor or
  mutator: `length(coll@id) == 1L`, `is.character(coll@id)`,
  `!is.na(coll@id)`, `nzchar(coll@id)`.
- For every `survey_collection` instance: `length(coll@if_missing_var) == 1L`,
  `coll@if_missing_var %in% c("error", "skip")`, `!is.na(coll@if_missing_var)`.
- Round-trip preservation: `add_survey(coll, ...)` and
  `remove_survey(coll, ...)` produce a collection whose `@id` and
  `@if_missing_var` are `identical()` to those of the source collection.
- Precedence: when a `.dispatch_over_collection()`-driven `get_*()` call
  receives a non-`NULL` `.id`, the resolved column name equals that
  value; when `.id = NULL`, the resolved name equals `coll@id`. Same for
  `.if_missing_var`.
- No remaining string literal `".on_missing"` in any `R/` source file,
  `tests/testthat/` test file, or `tests/testthat/_snaps/` snapshot file
  after PR 2 merges. Exception: `NEWS.md` may reference the old name in
  the breaking-changes entry.
- `R CMD check --as-cran`: 0 errors, 0 warnings, ≤ 2 notes (the standard
  pre-approved set).
- `covr::package_coverage()` ≥ 95 % overall, with new code paths
  (validators, setters, dispatcher precedence) ≥ 98 %.

## Pipeline split

**recommended** — full split with the standard planner / builder /
tester / reviewer pipeline.

PR map:

- **PR 1 — `feature/collection-id-if-missing-var-class`** —
  Class properties, constructor wiring, dispatcher precedence rules,
  setters, print method, error-messages.md row, NEWS.md breaking-change
  entry.
  - **Acceptance criterion (pre-implementation)**: before any code
    lands, `plans/error-messages.md` must contain a row for
    `surveycore_error_collection_invalid_if_missing_var` with the
    full cli template specified in §New error class, placed adjacent
    to the existing `surveycore_error_collection_invalid_id` row.
    This row is the typed-error contract that every test in PR 1
    asserts against.
  Self-contained: this PR alone leaves
  `.on_missing` references intact across `get_*()` files (those are
  renamed in PR 2). The `as_survey_collection()` constructor's `.on_missing`
  is renamed in **this** PR (since the spec removes it entirely from the
  constructor, with no shim). The dispatcher's argument is also renamed
  in this PR; the analysis functions still call it through the *new*
  name in PR 2. To keep PR 1 internally consistent without a wide
  rename, the analysis-function dispatch-branch forwards in PR 1 are
  temporarily rewritten to pass `.if_missing_var = .on_missing` (i.e., the
  old `.on_missing` argument is forwarded into the new `.if_missing_var`
  parameter) — this is a one-line touch per file and is removed in PR 2
  when the argument is renamed at the function signature level. **OR**
  — the planner explicitly defers the rename of the dispatcher
  argument to PR 2, so PR 1 keeps the dispatcher's argument as
  `.on_missing` and only PR 2 does the wide rename. Builder picks
  whichever keeps PR 1's diff smallest; tester accepts either.
- **PR 2 — `feature/collection-if-missing-var-rename`** —
  Rename `.on_missing` → `.if_missing_var` across every `get_*()`
  function in the analysis layer (10 files). Update every snapshot
  string that pinned `.on_missing`. Update every `@param` line. Verify
  no remaining `.on_missing` string literal in `R/`, `tests/`, or
  `_snaps/`.

Justification: PR 1 is the heart of the design (new state + new
contracts) and is the larger semantic change but is reviewable in
isolation against the existing `get_*()` argument names. PR 2 is purely
a rename + snapshot refresh and is safe to review without re-evaluating
the design. Concurrent PRs would share files (e.g., the dispatcher
file), so they must merge sequentially.
