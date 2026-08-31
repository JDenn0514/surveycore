# Spec — var-extension-slot

**Version**: 1.1
**Date**: 2026-08-27
**Status**: SPEC_READY
**Target version**: X.Y.Z.9000 (next `develop` version after this PR)
**PR range**: PR 1 (single PR — see `implementation-plan.md`)

## Document Purpose

This document is the source of truth for the builder implementing the
per-variable extension slot on `survey_metadata` (GitHub issue #176,
Proposal A). It fully specifies the new S7 property, the two new exported
functions, their error/warning behavior, and their lifecycle wiring. The
builder implements from this document alone.

Two decisions are locked by the maintainer and are out of scope to
reconsider (`decisions.md`, 2026-08-27):

1. Scope is Proposal A only. The `measure` property (Proposal B) is not
   part of this PR and must not be added, even as a stretch goal.
2. Shape is a flat named list per variable, not namespaced by package.

---

## I. Scope

### In

| Item | Description |
|---|---|
| New `survey_metadata` property | `var_extra` — a named list keyed by variable name; each value is itself a named list (the extension payload) or `NULL`. |
| New exported function | `set_var_extra()` — unified setter (Conventions 1/2/3), survey objects and data frames. |
| New exported function | `extract_var_extra()` — extractor, survey objects and data frames. |
| Lifecycle wiring | `var_extra` participates in the same rename-on-column-rename and delete-on-column-removal behavior as the other per-variable metadata slots (`variable_labels`, `value_labels`, `question_prefaces`, `notes`, `transformations`). |
| New error classes | `surveycore_error_var_extra_not_list` (row M-16) and `surveycore_error_var_extra_ambiguous_wrap` (row M-17) in `plans/error-messages.md`. |
| Minimal shape validation | surveycore never inspects, type-checks, or acts on the *values* inside a payload — only that the payload itself is a list or `NULL`, and that a non-empty payload's top-level names are present, non-empty, and unique (required so `format = "data_frame"` can always enumerate `(variable, key)` pairs — see `extract_var_extra()` §Returns). |

### Out

| Item | Why |
|---|---|
| `measure` property (Proposal B) | Locked decision — deferred to a separate future request. |
| A house `role` taxonomy owned by surveycore | The request explicitly rejects this; `var_extra` is a pass-through container, not a controlled vocabulary. |
| Namespacing the payload by package | Locked decision — flat shape only. |
| A separate plural setter (e.g. `set_variable_extras()`) | See "No plural setter" below. |
| Adding `var_extra` to `extract_metadata()`'s aggregate output | See "extract_metadata() is intentionally unchanged" below. |
| `survey_collection` support | No existing per-variable metadata setter/extractor accepts a `survey_collection` directly; `var_extra` follows the same restriction. Operate on member surveys individually. |

### No plural setter

The codebase previously had plural setters (`set_variable_labels()`,
`set_value_labels()`, `set_question_prefaces()`, `set_variable_notes()`)
and removed them in favor of one unified setter per metadata field that
supports three calling conventions (named `...`, a single named
vector/list in `...`, or explicit `variable` + content arguments). Calling
any of the old plural names now raises `could not find function` by
design (see `tests/testthat/test-metadata-system.R`, the
"`set_variable_labels()` is removed" tests and siblings). `set_var_extra()`
follows the *current* convention: one setter, three calling conventions,
matching `set_var_note()`, `set_universe()`, and `set_missing_codes()`.
There is no `set_variable_extras()`.

### extract_metadata() is intentionally unchanged

`extract_metadata()` aggregates `variable_label`, `value_labels`,
`question_preface`, `note`, `universe`, `missing_codes`, and
`transformations` per variable. It does not include `sata`, `higher_is`,
or `reverse_coded` either — those were added in later PRs without
extending `extract_metadata()`. This PR follows that precedent and does
not add `var_extra` to `extract_metadata()`'s output. Use
`extract_var_extra()` directly.

### Class/design support matrix

| Class | Supported |
|---|---|
| `survey_taylor` | Yes — inherits `survey_metadata` via `survey_base`. |
| `survey_replicate` | Yes |
| `survey_twophase` | Yes |
| `survey_nonprob` | Yes |
| `survey_collection` | No — rejected by `.check_is_survey_or_df()`, same as every other per-variable metadata function. |
| `data.frame` | Yes — payload stored as a `"var_extra"` attribute on the column, mirroring `"note"`, `"universe"`, `"missing_codes"`. When such a data frame is later passed to `as_survey()`/`as_survey_replicate()`/`as_survey_twophase()`/`as_survey_nonprob()`, the attribute is promoted into `@metadata@var_extra` — the same promotion path those three siblings already get, via `.extract_haven_metadata()`. |

---

## II. Architecture

### Files touched

- `R/core-classes.R` — add the `var_extra` property to the `survey_metadata`
  class definition and its `@param` doc block.
- `R/core-metadata.R` — add `set_var_extra()` and `extract_var_extra()`;
  update the file's function-inventory header comment to list both. Also
  add a `var_extra` block to `.extract_haven_metadata()`, so a
  `"var_extra"` column attribute set on a `data.frame` before
  construction is promoted into the new object's `@metadata@var_extra` —
  the same promotion path `note`/`universe`/`missing_codes` already get.
  Without this, a payload set via `set_var_extra()` on a `data.frame`
  would be silently lost the moment that frame is passed to
  `as_survey()`/`as_survey_replicate()`/`as_survey_twophase()`/
  `as_survey_nonprob()`.

  **Do not copy the sibling blocks' emptiness filter.** The `note`/
  `universe` blocks only promote when `is.character(...) && nzchar(...)`,
  and the `missing_codes` block only promotes when
  `is.atomic(...) && length(...) > 0L` — all three intentionally drop
  falsy/empty attribute values. `var_extra` must NOT reuse that filter:
  promote the attribute whenever it is non-`NULL`, regardless of length,
  including a payload of `list()`. §III's edge cases establish that
  `list()` is a valid, meaningful payload distinct from "never set," and
  the Round-trip fidelity quality gate requires it survive unchanged —
  an emptiness filter here would silently revert it to "never set" during
  promotion, recreating a narrower version of the exact data-loss bug
  this block exists to close.
- `R/core-validators.R` — add `var_extra` to `.rename_metadata_keys()` and
  `.delete_metadata_col()`.
- `plans/error-messages.md` — rows M-16 and M-17 already added (this
  document references them; no further edit needed by the builder).
- `NAMESPACE`, `man/set_var_extra.Rd`, `man/extract_var_extra.Rd` —
  generated by `devtools::document()`.

### Class changes

`survey_metadata` gains one property:

```r
var_extra = S7::new_property(
  S7::class_list,
  default = quote(list())
)
```

Placed alongside the other per-variable list properties (after `notes`,
before `universe`, or in whatever position keeps the property block
alphabetically/logically grouped with its siblings — exact position is a
builder discretion call, not a behavioral contract).

### Shared internal helpers reused (no signature changes)

- `.check_is_survey_or_df(x, call)` — type guard, reused as-is.
- `.get_data_cols(x)` — column-name accessor, reused as-is.
- `.get_data_for_select(x)` — tidy-select data source for `extract_var_extra()`'s `...`, reused as-is (same call every sibling extractor makes: `tidyselect::eval_select(rlang::expr(c(...)), data = .get_data_for_select(x))`).
- `.parse_setter_input(dots, variable, content, content_arg_name, content_type, fn_name, call)` — reused with `content_type = "vector"`. This is the same code path `set_missing_codes()` and `set_val_labels()` use: Convention 1 (named `...`) and Convention 2 (single unnamed named list in `...`) require no new logic in this helper, because the helper treats each variable's resolved payload as an opaque value it never inspects. After `.parse_setter_input()` resolves the per-variable payload list, `set_var_extra()` performs its own validation pass on each resolved payload (list-or-`NULL` check, top-level name check) before storing — see §Errors.
- `.check_extractor_fill(fill, fn_name, call)` — reused as-is (valid values: `NULL`, `NA_character_`).
- `.check_extractor_format(format, fn_name, valid_formats, call)` — reused as-is with `valid_formats = c("list", "data_frame")`.
- `.rename_metadata_keys(metadata, rename_map)` — modified: add one line
  renaming `metadata@var_extra` the same way `metadata@notes` is renamed.
- `.delete_metadata_col(design, col)` — modified: add one line clearing
  `md@var_extra[[col]]` the same way `md@notes[[col]]` is cleared.

### Functions added

```r
set_var_extra(x, ..., variable = NULL, extra = NULL)
extract_var_extra(x, ..., format = "list", fill = NULL)
```

---

## III. `set_var_extra()`

Sets the extension-slot payload for one or more variables. surveycore
stores the payload and never reads, validates, or acts on the *values*
inside it — it confirms only that the top-level value is a list or
`NULL`, and that a non-empty list's top-level names are present,
non-empty, and unique.

> Note applying to both `set_var_extra()` (this section) and
> `extract_var_extra()` (§IV): grouping, weighting, and stratification
> are out of scope for both functions and are not reiterated per
> edge-case table below — neither function has a `group` argument or
> reads weight/strata/FPC columns, so no combination of those inputs
> changes either function's behavior.

### Signature

```r
set_var_extra(x, ..., variable = NULL, extra = NULL)
```

### Arguments

Supports Conventions 1, 2, and 3 — see `set_var_label()` for the general
mechanics (named `...`, a single unnamed named list in `...`, or explicit
`variable` + content arguments).

| Name | Type | Default | Description |
|---|---|---|---|
| `x` | survey design object or `data.frame` | — (required) | The object to modify. |
| `...` | named arguments, or a single unnamed named list | — | Convention 1 or 2. Each resolved payload value must be a list or `NULL`. Mutually exclusive with `variable`. |
| `variable` | `character` | `NULL` | Convention 3: variable name(s), used with `extra`. Mutually exclusive with `...`. |
| `extra` | `list` | `NULL` | Convention 3 only. A list of payloads, one element per entry of `variable`, in the same order. Each element must itself be a list or `NULL`. Unlike `set_missing_codes()`'s bare-atomic-vector shorthand, there is **no** bare-payload shorthand for the single-variable case — a bare named list cannot be distinguished from a one-element outer list. For a single variable, wrap the payload in an outer list: `set_var_extra(x, variable = "age", extra = list(list(role = "demographic")))`. **Guard**: when `length(variable) == 1`, if `extra` itself is a *named* list of length 1 (the outer wrap was omitted, e.g. `extra = list(role = "demographic")`), `set_var_extra()` raises `surveycore_error_var_extra_ambiguous_wrap` rather than silently reinterpreting `extra`'s own name as the payload key. |

### Returns

The modified object (survey design object or `data.frame`), invisibly.

- Survey design objects: `x@metadata@var_extra[[var_name]]` is set to the
  payload (or removed if the payload is `NULL`).
- Data frames: `attr(x[[var_name]], "var_extra")` is set to the payload (or
  removed if the payload is `NULL`).

Assigning `NULL` as a variable's payload removes that variable's entry
from `var_extra` entirely (ordinary R list-assignment semantics — the same
behavior `set_var_note(x, age = NULL)` already has for `@metadata@notes`).

### Errors

| Error class | Trigger |
|---|---|
| `surveycore_error_not_survey_or_df` | `x` is neither a survey design object nor a `data.frame`. |
| `surveycore_error_setter_ambiguous` | Both `...` and `variable` are supplied. |
| `surveycore_error_setter_empty` | Neither `...` nor `variable` is supplied. |
| `surveycore_error_setter_mismatched_lengths` | `length(variable) != length(extra)` when both are supplied and `extra` is non-`NULL`. |
| `surveycore_error_setter_mixed_dots` | `...` contains a mix of named and unnamed elements (and is not the single-unnamed-named-list Convention 2 form). |
| `surveycore_error_var_extra_not_list` | A resolved payload for one variable is non-`NULL` and is not a list (e.g. a bare character string, number, or atomic vector), OR is a non-empty list with one or more unnamed, empty-string, or duplicated top-level names. |
| `surveycore_error_var_extra_ambiguous_wrap` | Convention 3, `length(variable) == 1`, and `extra` itself is a named list of length 1 (the single-variable payload was not wrapped in an outer list). |

### Warnings

| Warning class | Trigger |
|---|---|
| `surveycore_warning_var_not_found` | One or more named variables are not present in `x`'s columns. That variable's payload is skipped (not set); processing continues for the remaining variables. |
| `surveycore_warning_setter_empty_variables` | `variable` is supplied as `character(0)`. No-op; returns `x` unchanged. |

### Edge cases

| Case | Behavior |
|---|---|
| `x` has 0 rows | No effect on this function — `var_extra` is keyed by variable name, not by row. Behaves identically to any other row count. |
| `x` has 1 row | Same as above — unaffected by row count. |
| All-NA outcome column | Not applicable — `set_var_extra()` never inspects column values, only column names. |
| Payload is `list()` (empty list, not `NULL`) | Valid and distinct from "no payload set." Stored as `list()`. `extract_var_extra()` (default `fill = NULL`) does **not** omit this variable, because its stored value is non-`NULL` (see extractor edge cases). |
| `variable`/`...` name is the internal sentinel column `..surveycore_wt..` (used for probability-derived SRS designs) | Permitted, no special-casing — it is a valid, if unusual, `var_extra` key like any other column name. |
| Payload contains nested lists, `NULL` values inside the payload, functions, data frames, or any other R object as a *value* within the payload | Accepted without validation — only the top-level payload's own type (list or `NULL`) and its top-level names are checked; values (however deeply nested) are never inspected. |
| Payload's own top-level keys are unnamed, duplicated, or empty strings (and the payload is non-empty) | Rejected with `surveycore_error_var_extra_not_list`. Required so `format = "data_frame"` can always enumerate `(variable, key)` pairs unambiguously; without this, an unnamed payload is indistinguishable from "no payload set" in that format. An empty payload (`list()`) has no names to violate this rule and remains valid — see the `list()` row below. |
| Same variable named twice across the setter call (e.g. Convention 1 `set_var_extra(x, age = list(...), age = list(...))`) | R's own `...`/named-list semantics apply (last value for a duplicate name wins); surveycore does not add duplicate-detection beyond what `...` already does. |
| Variable exists in `x` but was never given a payload | Never appears as a key in `var_extra`; `extract_var_extra()` omits it by default. |
| Convention 3 with `variable` supplied and `extra` omitted (left `NULL`) | Clears every listed variable's payload — removes each from `var_extra` entirely, the same bulk behavior `.parse_setter_input()` already gives every sibling setter (e.g. `set_var_note(x, variable = c("age", "income"), note = NULL)`). Not an error. |
| `variable`/`...` name matches a design variable (`ids`, `weights`, `strata`, `fpc`, or a `repwt_*` column) | Permitted — `var_extra` follows the same precedent as `set_var_note()`, which already allows notes on design-variable columns. Setting or removing a payload never removes, renames, or otherwise modifies the design variable itself; the "design variables are sacred" rule concerns the design variable's own identity and values, not arbitrary per-variable metadata attached to its name. |
| A payload value is a non-serializable R object (an open connection, an environment, an external pointer) | Accepted by `set_var_extra()` — surveycore validates only the payload's top-level shape (§Errors), never value types. surveycore guarantees only that the `var_extra` *property itself* round-trips through S7's serialization mechanism for R-serializable content; it makes no guarantee that a non-serializable *value* a caller chooses to store survives `saveRDS()`/`readRDS()`. This is the caller's responsibility, same as storing such a value in any other R list a user intends to serialize. |
| `x` is a `survey_nonprob` object with a `@reference_sample` (a nested `survey_taylor`) | `set_var_extra()`/`extract_var_extra()` operate only on `x`'s own `@metadata@var_extra` and never read or write `x@reference_sample@metadata@var_extra`. The two objects' extension slots are independent and are never synchronized or cross-referenced by this feature, even when both contain a variable of the same name. |
| Multiple variables in one call, more than one with an invalid payload, and/or one or more absent from `x`'s columns | Per variable, processed in the order given (argument order for Convention 1/3, list order for Convention 2): absence is checked before payload-shape validity, matching the existing `set_missing_codes()` precedent. A variable absent from `x`'s columns triggers `surveycore_warning_var_not_found` and is skipped — its payload (even if it would otherwise be invalid) is never shape-checked. Validation and storage happen together, one variable at a time, in that order; the first *present* variable with an invalid payload aborts the call immediately with `surveycore_error_var_extra_not_list`. Because the abort happens inside the function before it returns the modified object, the caller's original object is unaffected regardless of how many earlier variables in the same call were already stored on the function's internal copy — the caller never sees a partially-updated result. |

---

## IV. `extract_var_extra()`

Returns the extension-slot payload for one or more variables. Read-only;
performs no validation of payload contents.

### Signature

```r
extract_var_extra(x, ..., format = "list", fill = NULL)
```

### Arguments

| Name | Type | Default | Description |
|---|---|---|---|
| `x` | survey design object or `data.frame` | — (required) | The object to query. |
| `...` | tidy-select | — | Variables to query. Supports `tidyselect::starts_with()`, `all_of()`, `any_of()`, `matches()`, etc. If empty, returns the payload for every column in `x`. Use `any_of()` to silently skip names absent from `x`. |
| `format` | `character(1)` | `"list"` | `"list"` or `"data_frame"`. `"named_vector"` is invalid for this function (payloads are not scalar). |
| `fill` | scalar or `NULL` | `NULL` | `NULL` omits variables with no payload (i.e. `var_extra[[v]]` is `NULL`). `NA_character_` includes them, with a `NULL` payload in `"list"` format. In `"data_frame"` format, variables with no payload are always excluded regardless of `fill` (there are no keys to produce a row for). |

### Returns

- `format = "list"` (default): a named list. Keys are variable names.
  Values are each variable's stored payload (a named list), or `NULL` for
  variables included via `fill = NA_character_` that have no payload
  set. Empty result: `list()`.
- `format = "data_frame"`: a tibble with columns `variable` (`character`),
  `key` (`character`), and `value` (a list-column — one raw payload value
  per row, unvalidated and untouched, of whatever type the caller stored).
  One row per `(variable, key)` pair present in that variable's payload.
  A variable whose payload is `list()` (empty) or unset contributes zero
  rows. Empty result: a zero-row tibble with the three columns typed as
  above.

  The codebase already has two builders of this "named list → long-format
  tibble" shape: `.format_list_result()` (used by `extract_val_labels()`)
  and an inline block in `extract_missing_codes()`. Before writing a third
  copy, consider generalizing `.format_list_result()` (parameterize the
  output column names and whether `value` is coerced to `character` or
  kept as a raw list-column) so `extract_var_extra()` reuses it. Not a
  behavioral requirement — a builder discretion call — but avoids a third
  divergent implementation of the same row-building logic.

### Errors

| Error class | Trigger |
|---|---|
| `surveycore_error_not_survey_or_df` | `x` is neither a survey design object nor a `data.frame`. |
| `surveycore_error_format_invalid` | `format` is not `"list"` or `"data_frame"` (including `"named_vector"`). |
| `surveycore_error_fill_invalid` | `fill` is not `NULL` or `NA_character_`. |

### Warnings

None specific to this function. (Tidy-select's own behavior governs
missing-name handling: a bare symbol naming a column absent from `x`
errors via `tidyselect`; `any_of()` silently skips it — identical to
`extract_var_note()`, `extract_universe()`, and `extract_missing_codes()`.)

### Edge cases

| Case | Behavior |
|---|---|
| `x` has 0 or 1 rows | No effect — this function reads variable-level metadata only. |
| No variables have any payload set | `format = "list"` with default `fill = NULL` returns `list()`. `format = "data_frame"` returns a zero-row tibble. |
| A variable's payload is `list()` (explicitly set, empty) | With `fill = NULL`: included in `"list"` format output as `list()` (it is non-`NULL`, so not omitted). In `"data_frame"` format: contributes zero rows (nothing to enumerate), same as an unset variable — the caller distinguishes "payload set but empty" from "never set" only via `"list"` format, not `"data_frame"` format. |
| A payload value for a given key is itself `NULL`, a list, or any other type | Returned as stored, in the `value` list-column (data_frame format) or nested inside the payload list (list format) — never coerced or altered. |
| `...` resolves to zero variables (empty tidy-select, no columns in `x`) | Returns the appropriate empty result for the requested `format`. |

---

## Quality gates

- Neither function introduces a new S3/S4/S7 result class: `set_var_extra()`
  returns the input object type unchanged, and `extract_var_extra()`'s
  outputs use base list and standard tibble printing as-is. No
  print-snapshot tests are required for this feature.
- Every `survey_metadata()` object — including ones built implicitly by
  `as_survey()`, `as_survey_replicate()`, `as_survey_twophase()`,
  `as_survey_nonprob()`, and by calling `survey_metadata()` directly —
  has a `var_extra` property present and defaulting to `list()`.
- Round-trip fidelity: for any payload value accepted by `set_var_extra()`
  (a list, arbitrarily nested, or `NULL`), the value returned by
  `extract_var_extra(..., format = "list")` for that variable is
  identical (`identical()`) to what was set, with no coercion.
- No code elsewhere in `R/` reads or branches on the *contents* of
  `@metadata@var_extra` — grep confirms the only production references
  are in `set_var_extra()`, `extract_var_extra()`,
  `.rename_metadata_keys()`, `.delete_metadata_col()`, and the
  `var_extra` promotion block in `.extract_haven_metadata()`. Unlike the
  `note`/`universe`/`missing_codes` blocks beside it, the `var_extra`
  block does not filter on emptiness — it promotes the attribute
  whenever it is present and non-`NULL` (see Architecture § Files
  touched).
- Renaming a column carries its `var_extra` entry to the new name
  (`.rename_metadata_keys()`).
- Removing a column deletes its `var_extra` entry
  (`.delete_metadata_col()`).
- `R CMD check`: 0 errors, 0 warnings, ≤2 pre-approved notes.
- New code reaches ≥98% line coverage.

## Pipeline split

**recommended** — this PR adds two new exported functions and a new S7
class property (a contract change to `survey_metadata`), which fails all
four "optional" criteria in the pipeline-simplified smallness test.

## Integration

- **Downstream packages** (`adldata`, `surveyreports`, and others):
  consume `var_extra` exclusively through `extract_var_extra()`. surveycore
  makes no forward-compatibility promise about *contents* — any key/value
  shape downstream packages choose (e.g. `role = "free_text"`,
  `role = "paradata"`, or an entirely different taxonomy) is preserved
  as-is and requires no surveycore release to adopt.
- **`update_design()`**: not affected by this PR. `var_extra` is
  per-variable metadata, not a design variable (`ids`/`weights`/`strata`/
  `fpc`), and `update_design()`'s warning (`surveycore_warning_...`,
  row 36) is unrelated.
- **Proposal B (`measure`)**: explicitly out of scope (locked decision).
  A future spec for `measure` must not assume `var_extra`'s shape or
  reuse its property — treat them as independent additions.
- **`surveytidy`**: `select()`/`rename()` (implemented in `surveytidy`,
  not in this package) call the internal helpers
  `.rename_metadata_keys()` and `.delete_metadata_col()` from
  `R/core-validators.R`. Both are updated by this PR so `var_extra`
  participates in the same lifecycle as `notes`, `variable_labels`,
  `value_labels`, `question_prefaces`, and `transformations` without any
  change required on the `surveytidy` side.

> ⚠️ GAP: `.rename_metadata_keys()` currently renames
> `variable_labels`, `value_labels`, `question_prefaces`, `notes`,
> `transformations`, and `sata`. `.delete_metadata_col()` currently
> clears only `variable_labels`, `value_labels`, `question_prefaces`,
> `notes`, and `transformations` (not `sata`). Neither function touches
> `universe`, `missing_codes`, `higher_is`, or `reverse_coded` at all.
> This is a pre-existing inconsistency in the codebase, unrelated to
> this feature, and out of scope for this PR — `var_extra` is wired into
> both functions correctly regardless. Flagging so the maintainer has an
> accurate inventory if a follow-up issue is opened.
