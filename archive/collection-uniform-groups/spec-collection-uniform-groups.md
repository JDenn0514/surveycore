# Spec: `survey_collection` Uniform Grouping

**ID:** `collection-uniform-groups`
**Version:** 0.4 (amended during implementation)
**Date:** 2026-04-23
**Status:** Implemented — shipped minus the `[[<-` method (see §I Scope "Deferred")

## Amendment log

**v0.4 (2026-04-23, during `/r-implement`)** — The `[[<-` method on
`survey_collection` was deferred. Rationale:
`S7::method("[[<-", survey_collection) <- function(x, i, ..., value)` causes
`R CMD check`'s `checkReplaceFuns` to surface a spurious WARNING
(`Error in get(f, envir = code_env) : invalid first argument`) because S7
registers the method in the S3methods metadata with the function object in
the method column, not a character name; the check's coercion path
substitutes `""` and then calls `get("", envir = code_env)`. Error classes
G5, G5b, G6, G7, G7b are deferred with the method. All other parts of the
spec shipped as written. See `decisions-collection-uniform-groups.md`
(2026-04-23, "Defer `[[<-`") for the full rationale.

---

## Document Purpose

This spec is the source of truth for how `survey_collection` handles grouping.
It extends the shipped container (PRs #97, #98; `archive/survey-collection/`)
with a **uniform-grouping invariant**: the collection owns a single grouping
vector, and every member survey's `@groups` mirrors it. The implementation
plan at `/Users/jacobdennen/surveycore/plans/impl-collection-uniform-groups.md`
(Decisions 1–10) is the authority on design rationale; this document captures
the contract in the structural form used by all surveyverse specs.

Rules from `code-style.md`, `r-package-conventions.md`,
`surveycore-conventions.md`, `testing-standards.md`, and
`testing-surveycore.md` apply throughout and are referenced where relevant
rather than restated.

---

## I. Scope

### Delivered

| Deliverable | Description |
|---|---|
| `survey_collection@groups` | New `S7::class_character` property on the class, default `character(0)`. |
| Uniform-groups invariant | Class validator asserts every member survey's `@groups` is `identical()` to the collection's `@groups`. |
| `as_survey_collection()` `group =` argument | New named-only arg; propagates onto members or adopts from uniformly-grouped members. |
| `add_survey()` propagation | Empty `@groups` on a new survey coerces to collection groups; non-empty mismatches error. |
| `print.survey_collection` update | Emits a `Groups:` line when `coll@groups` is non-empty. |
| Error-class rows | Six new rows in `plans/error-messages.md` (G1, G1b, G1c, G2, G3, G4, G8) — see §Error Table. |
| Test file | `tests/testthat/test-collection-groups.R` covering constructor, mutators, dispatch regressions. |

### Deferred (v0.4 amendment)

| Deferred | Reason |
|---|---|
| `[[<-` method for `survey_collection` | `S7::method("[[<-", ...)` triggers a spurious `R CMD check` `checkReplaceFuns` WARNING (the S3methods metadata stores the method function, not a name, which the check's coercion path converts to `""` and then passes to `get()`). Deferred pending an S7-side fix or R-side check fix. Users mutate collections via `add_survey()` / `remove_survey()`. Error classes G5 / G5b / G6 / G7 / G7b are deferred with the method and are NOT in `plans/error-messages.md`. |

### NOT delivered

| Non-deliverable | Rationale |
|---|---|
| `group_by.survey_collection()` / `ungroup.survey_collection()` | Lives in surveytidy; tracked as a follow-up PR there. This spec defines only the surveycore-side invariant those methods must preserve. |
| Changes to `.dispatch_over_collection()` behavior | The uniform-groups invariant makes per-survey `.resolve_groups()` see the collection-level grouping without dispatch-layer changes. |
| Changes to `.warn_on_meta_divergence()` scope | Out of scope. |
| Changes to `.id` / `.on_missing` semantics | Unchanged. |
| Override semantics for call-site `group =` | Explicitly rejected (Decision 5); call-site `group` stacks with `coll@groups`. |
| Surveycore-side ungroup API | Explicitly rejected (Decision 7); routes exclusively through surveytidy. |

### Class / design support matrix

The invariant applies to every concrete subclass of `survey_base` that a
collection can already contain. No class-specific branching is introduced.

| Member class | Supported in grouped collection? |
|---|---|
| `survey_taylor` | Yes |
| `survey_replicate` | Yes |
| `survey_twophase` | Yes |
| `survey_nonprob` | Yes |

---

## II. Architecture

### File map

```
R/
├── core-classes.R          [MODIFY]  add @groups property; extend validator
├── core-constructors.R     [MODIFY]  add group= arg to as_survey_collection()
├── survey-collection.R     [MODIFY]  add_survey() propagation;
│                                     .check_groups_match() /
│                                     .propagate_or_match() helpers
├── methods-print.R         [MODIFY]  show Groups: in print.survey_collection;
│                                     add S7::method("[[<-", survey_collection)
│                                     next to existing [[, length, names
└── analysis-helpers.R      [UNCHANGED]  .resolve_groups() already works

tests/testthat/
└── test-collection-groups.R  [NEW]  see §Testing
```

No new R source file. `[[<-` is colocated with the sibling accessors
`[[`, `length`, and `names` in `R/methods-print.R` (per `code-style.md
§2 — S7 method file organization`: methods grouped by type). The file
name is a historical artifact — it already houses non-print methods;
a rename is out of scope for this spec. `NAMESPACE` is regenerated via
`devtools::document()`.

### Invariant helpers

Two narrowly-scoped internal helpers keep validation logic DRY. The three
call sites need three different rules, so a single helper cannot serve all
of them — an equality checker cannot express the "propagate when empty"
branch required by the constructor and `add_survey()`, and a tagged-action
return (`list(action = "ok"|"propagate"|"error")`) would hide control flow
behind a string label (`engineering-preferences.md §5`).

```r
# R/survey-collection.R

#' Assert two @groups vectors are identical (order-sensitive)
#'
#' Equality-only check used by the S7 validator and the `[[<-` setter,
#' where "propagate when empty" is deliberately NOT applied (Decision 3).
#'
#' @param candidate_groups  character. `@groups` of the incoming survey.
#' @param target_groups     character. `@groups` of the receiving collection.
#' @param context           character(1). Caller name for the error message
#'   (e.g., "[[<-", "validator").
#' @return `invisible(TRUE)` on match; errors with the caller-appropriate
#'   class otherwise.
#' @keywords internal
#' @noRd
.check_groups_match <- function(candidate_groups, target_groups, context) { ... }

#' Resolve candidate groups against a target: propagate when empty, else match
#'
#' Used by `as_survey_collection()` and `add_survey()`. Returns the groups
#' to apply to the member, or errors on a non-empty mismatch. The caller
#' is responsible for assigning the returned value to `member@groups`.
#'
#' @param candidate_groups  character. `@groups` of the incoming survey.
#' @param target_groups     character. `@groups` of the receiving collection.
#' @param name              character(1). Member name for the error message
#'   (e.g., `"wave1"`).
#' @param error_class       character(1). Error class to throw on mismatch
#'   (e.g., `"surveycore_error_collection_group_conflict"`).
#' @return character. Groups to assign to the member (`target_groups` when
#'   propagating; `candidate_groups` when they already match). Errors on
#'   non-empty mismatch.
#' @keywords internal
#' @noRd
.propagate_or_match <- function(
  candidate_groups, target_groups, name, error_class
) { ... }
```

Call-site mapping:

| Call site | Helper | Behavior on empty candidate | Behavior on non-empty mismatch |
|---|---|---|---|
| S7 class validator | `.check_groups_match()` | Error G1 | Error G1 |
| `[[<-` | `.check_groups_match()` | Error G5 (Decision 3 — no propagation) | Error G5 |
| `add_survey()` | `.propagate_or_match()` | Propagate `coll@groups` | Error G4 |
| `as_survey_collection()` with `group =` supplied | (inline; warns on override) | Propagate `target` silently | Override + warn G8 |
| `as_survey_collection()` adopt-from-members path | (inline; compares all members) | — | Error G2 |

`as_survey_collection()` with `group =` is inlined because it needs
override-with-warning semantics that neither helper provides; adding a
third helper for a single site would violate `engineering-preferences.md
§3` (engineered enough).

The S7 class validator is the **final backstop** — if any code path forgets
to call a helper, the structural check still fires on construction.

---

## III. Class: `survey_collection`

### New property

| Property | Type | Default | Description |
|---|---|---|---|
| `@groups` | `S7::class_character` | `character(0)` | Grouping variables that every member survey mirrors. Empty vector means the collection is ungrouped. |

Property access follows `code-style.md §2 — Property access`: internal code
uses `coll@groups` directly; no accessor function.

### Validator rule (extends existing C1–C4)

After the current checks, assert **two** uniform-groups invariants.

**Invariant 1 — Equality across members.** For every member:

```
identical(coll@groups, coll@surveys[[i]]@groups)   # for every i in seq_along(coll@surveys)
```

**Order is part of the invariant.** `identical()` is order-sensitive;
`c("region", "stratum")` and `c("stratum", "region")` are *not* equal
groupings for the purpose of this check. Order carries semantic weight
in downstream output (e.g., `.resolve_groups()` concatenates
`coll@groups` before call-site groups via
`unique(c(from_groups_prop, from_arg))`, which determines column order
in `get_means()` results; `group_by(a, b)` vs `group_by(b, a)` produce
different orderings). Any surveytidy method that sets both
`coll@groups` and member `@groups` must use the same order in both.

On failure, abort with `surveycore_error_collection_groups_invariant` (G1)
naming the first divergent member (by name, not index). Validator text is
Layer 1 (`class=`-only test; no snapshot, per `testing-surveycore.md`).

**Invariant 2 — Resolvability in each member's `@data`.** For every
member, every column named in `coll@groups` must exist in that member's
`@data`:

```
all(coll@groups %in% names(coll@surveys[[i]]@data))   # for every i
```

This closes a gap that Invariant 1 alone cannot: Invariant 1 only
asserts *equality* of `@groups` across members, not *resolvability* of
those names against each member's data. Without Invariant 2, the
propagation paths in `add_survey()` and `[[<-` (replace-by-name) can
assign a mirrored `@groups` onto a member whose `@data` does not
contain the named column(s); the structural check still passes, but
the first analysis call (e.g., `get_means(coll, y)`) fails cryptically
from `.resolve_groups()` with a generic "column not found."

On failure, abort with `surveycore_error_collection_group_not_in_member_data`
(G1b) naming the first member that fails and the first missing column.
Layer 1 test (`class=`-only, no snapshot).

**Invariant 3 — Well-formed `@groups` contents.** `coll@groups` must
be a character vector with no `NA`, no empty-string (`""`), and no
duplicated entries:

```
!any(is.na(coll@groups))
!any(coll@groups == "")
!anyDuplicated(coll@groups)
```

The normal construction path (`as_survey_collection(group = ...)` via
tidyselect) never produces any of these, but direct S7 construction
(`survey_collection(surveys = ..., groups = c("a", NA_character_, "a"))`)
bypasses tidyselect and could otherwise slip through to
`.resolve_groups()` and produce cryptic failures or duplicate output
columns.

On failure, abort with `surveycore_error_collection_groups_malformed`
(G1c). The error message lists each failing condition it detects
(`NA` present, empty-string present, duplicates present) as separate
`"i"` bullets so that a maliciously-constructed vector triggering
multiple conditions is fully reported in one pass. Layer 1 test
(`class=`-only, no snapshot).

The validator is the final backstop for every entry path (direct S7
construction, `as_survey_collection()`, `add_survey()`, `[[<-`, future
surveytidy methods): if any helper forgets a check, Invariants 1–3
still fire at construction time.

### Print method

When `length(coll@groups) > 0L`, `print.survey_collection` emits a
`Groups:` line immediately after the existing header line
(`R/methods-print.R:772`) and before the member listing
(`.fmt_collection_line()` output at `R/methods-print.R:760–767`). The
header text itself is not changed by this spec.

Ungrouped (unchanged):
```
A <survey_collection> with 2 survey(s):
  "wave1": survey_taylor, 100 rows, 5 variables
  "wave2": survey_taylor, 100 rows, 5 variables
```

Grouped:
```
A <survey_collection> with 2 survey(s):
Groups: region, stratum
  "wave1": survey_taylor, 100 rows, 5 variables
  "wave2": survey_taylor, 100 rows, 5 variables
```

When `length(coll@groups) == 0L`, no `Groups:` line is printed (existing
behavior). Exact snapshot format captured in `test-methods-print.R`.

---

## IV. Function: `as_survey_collection()`

### Signature

```r
as_survey_collection(
  ...,
  group       = rlang::missing_arg(),
  .id         = ".survey",
  .on_missing = "error"
)
```

`group` precedes `.id` / `.on_missing` (Decision 6). All three are
named-only (after `...`), per `code-style.md §4`.

`group` has no scalar default. Use `group = rlang::missing_arg()` in the
signature and detect absence with
`rlang::quo_is_missing(rlang::enquo(group))`. This matches the pattern
used elsewhere in surveycore for tidy-select arguments and cleanly
threads the quosure to downstream tidyselect evaluation when `group` is
supplied.

### Arguments

| Arg | Type | Default | Description |
|---|---|---|---|
| `...` | `survey_base` objects | — | Member surveys. Optionally named. Existing name-repair rules apply. |
| `group` | character or bare names | missing | Grouping variable(s) to apply uniformly across members. Tidy-select semantics (bare names, `c()`, `all_of()`). `missing` means "adopt from members or leave ungrouped." An empty resolution — `group = NULL`, `group = character(0)`, `group = c()`, or `group = all_of(character(0))` — is treated as equivalent to `missing(group)` (consistent with tidyselect conventions). To remove grouping from a pre-grouped member, use `surveytidy::ungroup()` on the member first. |
| `.id` | character(1) | `".survey"` | Identifier column name on dispatched results. Unchanged from shipped behavior. |
| `.on_missing` | character(1) | `"error"` | `"error"` or `"skip"`. Unchanged from shipped behavior. |

### Behavior

1. Existing steps: name resolution, survey evaluation, duplicate-name repair.
2. **Compute target `@groups`** (Decision 4):
   - If `group` is supplied AND resolves to a non-empty character vector:
     resolve via tidy-select against each member's `@data`; every named
     column must exist in every member (else G3).
     Then, for each member:
     - If `member@groups` is `character(0)` OR
       `identical(member@groups, target)`: set `member@groups <- target`
       (silent propagation).
     - Otherwise (`member@groups` is non-empty and differs from `target`):
       set `member@groups <- target` AND emit
       `surveycore_warning_collection_group_overridden` (G8), naming the
       member, the dropped groups, and the new `target`. One warning per
       divergent member.
   - Else (`group` missing OR resolves to an empty character vector),
     consult the members:
     - If every member has identical non-empty `@groups`: adopt that
       value as the collection's `@groups`.
     - Else if some members differ (including mix of empty / non-empty):
       error `surveycore_error_collection_group_divergent` (G2).
     - Else (all members ungrouped): `@groups = character(0)`.
3. Construct `survey_collection(surveys = ..., groups = target)`; the
   validator re-asserts the invariant as a final backstop.
4. Empty `...` errors via existing C1 (unchanged — Decision 8).

### Output contract

Returns a `survey_collection` with `length(coll@groups) == length(group)`
(0 if ungrouped) and every `coll@surveys[[i]]@groups` identical to
`coll@groups`.

### Error conditions

See consolidated table in §VIII.

---

## V. Function: `add_survey()`

### Signature

Unchanged. This spec modifies only the body.

### Behavior (Decision 2)

For each new survey `new`:

| `coll@groups` | `new@groups` | Action |
|---|---|---|
| `character(0)` | `character(0)` | Insert unchanged. |
| `character(0)` | non-empty | Error `surveycore_error_collection_group_conflict`. |
| non-empty | `character(0)` | **Propagate**: `new@groups <- coll@groups`; insert. |
| non-empty, identical to `new@groups` | non-empty, identical | Insert unchanged. |
| non-empty | non-empty, differs | Error `surveycore_error_collection_group_conflict`. |

After processing all new surveys, construct the final collection with
`groups = coll@groups` so the validator re-asserts the invariant.

**Atomicity.** If any new survey errors during per-survey processing
(e.g., a G4 mismatch on the second of three), no member is added and
`coll` is unchanged. The only observable mutation is the final
`survey_collection()` construction at the end of the loop; an error
raised before that point aborts without side effects.

### Output contract

Returns a `survey_collection` whose `@groups` equals the pre-call
`coll@groups` and whose `@surveys` is the concatenation of existing plus
propagated-or-validated new members.

---

## VI. Method: `[[<-` on `survey_collection`

### Signature

```r
S7::method("[[<-", survey_collection) <- function(x, i, ..., value) { ... }
```

### Behavior (Decisions 3, 9)

1. **Validate `value`:** must inherit `survey_base` (else
   `surveycore_error_not_survey_base`). In particular,
   `coll[[i]] <- NULL` errors G6 — `[[<-` does not delete members.
   Use `remove_survey()` for removal.
2. **Validate `i` shape:** `i` must be a length-1 atomic vector of
   class `character` or integerish numeric. Anything else (multi-length,
   `NA`, logical, factor, zero-length, `NULL`, non-integer double,
   negative) errors G7b (`surveycore_error_collection_index_bad_type`).
3. **Classify the call as replace or append.** Within the two valid
   `i` shapes:
   - **Character, length 1:**
     - If `i %in% names(x@surveys)` — **replace**: overwrite the existing
       member at that name. Length unchanged; no name repair; no warning.
       This matches base-R `[[<-` list semantics.
     - Else — **append with name repair**: run the new name through
       `.repair_collection_names()` against `c(names(x@surveys), i)`;
       emit `surveycore_warning_collection_duplicate_name_repaired` if
       the name was repaired. Length grows by 1.
     - `i == ""` (empty string) is treated as "no name supplied" and
       routed through the append path; the repaired name is assigned
       (`..<length+1>` by default).
   - **Numeric, length 1:** must satisfy
     `i %in% seq_len(length(x@surveys) + 1L)`. `i %in% seq_len(length)`
     **replaces**; `i == length + 1L` **appends**. In the append case,
     the new element is auto-named `paste0("..", i)`, then run through
     `.repair_collection_names()` alongside existing names to resolve
     any collision (e.g., existing member `"..3"` when appending at
     `i = 3L`). Out-of-range numeric `i` errors G7
     (`surveycore_error_collection_index_out_of_range`).
4. **Validate `@groups` against the classified path:**
   `identical(value@groups, x@groups)` must hold. **Order-sensitive**
   (per §III Invariant 1): `value@groups = c("stratum", "region")`
   against `x@groups = c("region", "stratum")` errors even though the
   two name the same set. Empty-propagation convenience from
   `add_survey()` does **not** apply here (Decision 3).
   The error class depends on the path classified in step 3, because
   each path has a different user remedy:
   - Replace path → `surveycore_error_collection_group_mismatch_on_replace`
     (G5). Hint directs the user to align `value@groups` with `x@groups`
     before assignment — appending via `add_survey()` would not preserve
     the replace semantics.
   - Append path → `surveycore_error_collection_group_mismatch_on_append`
     (G5b). Hint directs the user to `add_survey()` for automatic
     empty-groups propagation, or to set `value@groups` manually first.
5. **Assign + re-validate:** build a new `@surveys` list with `value` at
   position `i`, then construct `survey_collection(surveys = ..., groups =
   x@groups)`. The validator backstop catches any invariant violation the
   helper missed.

### Output contract

Returns a `survey_collection` with:
- `length(coll@surveys)` equal to the prior length (replacement) or
  prior length + 1 (append).
- `coll@groups` unchanged from `x@groups`.
- Every member still mirrors `coll@groups`.

---

## VII. Function: `remove_survey()` (no behavior change)

Documented here for completeness (Decision 10). The existing implementation
(`R/survey-collection.R:228`) delegates to `survey_collection(surveys =
new_list)`. With the new `@groups` property defaulting from the caller's
collection (passed explicitly in the implementation), the invariant is
preserved trivially:
- Remaining members already mirror `coll@groups`, so no mutation needed.
- Removal to zero members errors via the existing C1 validator path
  (`surveycore_error_collection_empty`) — Decision 8.

**Code change required:** `remove_survey()` must pass `groups =
x@groups` through to the reconstructed `survey_collection()` call, or
the reconstruction loses the collection-level grouping. One-line change.

---

## VIII. Error Table

All rows are additions to `plans/error-messages.md`. Class naming follows
`code-style.md §3 — Error and warning classes`.

| # | Function | Condition | Severity | Class | Message |
|---|---|---|---|---|---|
| G1 | `survey_collection` validator | Any member's `@groups` differs from `coll@groups` | ERROR | `surveycore_error_collection_groups_invariant` | `"Member {.val {first_divergent_name}} has @groups {.val {member_groups}}, collection has {.val {coll_groups}}."` (Layer 1 — `class=`-only test; no snapshot, per `testing-surveycore.md`) |
| G1b | `survey_collection` validator | A member's `@groups` names a column not present in that member's `@data` | ERROR | `surveycore_error_collection_group_not_in_member_data` | `"Member {.val {name}} has @groups {.val {member_groups}} but column {.field {missing_col}} is not in its @data."` `"i" = "Columns available: {.val {member_data_cols}}."` (Layer 1 — `class=`-only test; no snapshot) |
| G1c | `survey_collection` validator | `coll@groups` contains `NA`, empty string, or duplicates | ERROR | `surveycore_error_collection_groups_malformed` | `"x" = "{.arg groups} must be a character vector of column names with no {.val NA}, empty strings, or duplicates."` plus one `"i"` bullet per failing condition: `"i" = "Contains {.val {sum(is.na(groups))}} {.val NA} value(s)."` `"i" = "Contains {.val {sum(groups == \"\")}} empty string(s)."` `"i" = "Duplicates: {.val {duplicated_names}}."` (Layer 1 — `class=`-only test; no snapshot) |
| G2 | `as_survey_collection()` | Members have divergent `@groups` and no `group =` supplied | ERROR | `surveycore_error_collection_group_divergent` | `"x" = "Member surveys have different @groups, and no {.arg group} was supplied."` `"i" = "Found: {divergence summary}."` `"v" = "Supply {.arg group} explicitly, or ungroup members first via {.fn surveytidy::ungroup}."` |
| G3 | `as_survey_collection()` | `group =` names a column missing from a member | ERROR | `surveycore_error_collection_group_var_not_found` | `"x" = "Column {.field {var}} (from {.arg group}) not found in member {.val {name}}."` `"i" = "Members: {.val {member_names}}."` |
| G4 | `add_survey()` | New survey `@groups` mismatches collection | ERROR | `surveycore_error_collection_group_conflict` | `"x" = "Cannot add survey {.val {name}}: {.arg @groups} differs from collection."` `"i" = "Collection: {.val {coll_groups}}; survey: {.val {new_groups}}."` `"v" = "Ungroup the survey via {.fn surveytidy::ungroup} before adding, or group the collection to match."` |
| G5 | `[[<-` (replace path: character `i` matches an existing name, or numeric `i %in% seq_len(length)`) | Assigned survey `@groups` mismatches collection | ERROR | `surveycore_error_collection_group_mismatch_on_replace` | `"x" = "{.arg value}@groups must match {.arg x}@groups to replace member {.val {i_or_name}}."` `"i" = "Expected {.val {coll_groups}}; got {.val {value_groups}}."` `"v" = "Set {.code value@groups <- x@groups} (and ensure the grouping columns are present in {.code value@data}) before assignment."` |
| G5b | `[[<-` (append path: character `i` not in names, `i == ""`, or numeric `i == length + 1L`) | Assigned survey `@groups` mismatches collection | ERROR | `surveycore_error_collection_group_mismatch_on_append` | `"x" = "{.arg value}@groups must match {.arg x}@groups to append to this collection."` `"i" = "Expected {.val {coll_groups}}; got {.val {value_groups}}."` `"v" = "Use {.fn add_survey} if you want empty groups propagated automatically, or set {.code value@groups} to match before assignment."` |
| G6 | `[[<-` | `value` is not a `survey_base` | ERROR | `surveycore_error_not_survey_base` | `"x" = "{.arg value} must be a {.cls survey_base}, not {.cls {class(value)[[1]]}}."` |
| G7 | `[[<-` | Numeric `i` in valid shape but not in `1:(length+1)` | ERROR | `surveycore_error_collection_index_out_of_range` | `"x" = "{.arg i} must be an index in {.code 1:{.val {length(x@surveys) + 1L}}}."` `"i" = "Got {.val {i}}."` |
| G7b | `[[<-` | `i` has wrong shape or type (multi-length, `NA`, logical, factor, non-integer, zero-length, `NULL`, negative) | ERROR | `surveycore_error_collection_index_bad_type` | `"x" = "{.arg i} must be a length-1 {.cls character} or integerish {.cls numeric}, not {.cls {class(i)[[1]]}} of length {.val {length(i)}}."` `"v" = "Use a single name or index in {.code 1:{.val {length(x@surveys) + 1L}}}."` |
| G8 | `as_survey_collection()` | `group =` supplied; a member's non-empty `@groups` differs from the resolved target and is being overridden | WARNING | `surveycore_warning_collection_group_overridden` | `"!" = "Member {.val {name}} had @groups {.val {member_groups}}; overriding with {.val {target}}."` `"i" = "The {.arg group} argument to {.fn as_survey_collection} takes precedence over pre-existing member grouping."` `"i" = "If this was unintentional, call {.fn surveytidy::ungroup} on the member first, or omit {.arg group} to adopt from members."` |

Existing classes reused without modification:
- `surveycore_error_collection_empty` (C1) — empty construction path.
- `surveycore_warning_collection_duplicate_name_repaired` — name repair
  in `[[<-` append path.

---

## IX. Integration Contract with surveytidy

### Required of the surveytidy follow-up PR

When surveytidy implements `group_by.survey_collection()` and
`ungroup.survey_collection()`, it **must** preserve the uniform-groups
invariant. The two acceptable strategies:

1. **Reconstruct via `as_survey_collection()`**: extract members, rewrap
   with `group = <new>`. Recommended — delegates invariant enforcement
   to the surveycore constructor.
2. **Manual propagation**: mutate each member's `@groups`, then set
   `coll@groups`. Requires surveytidy to call the reconstructed
   `survey_collection()` constructor to trigger the validator backstop.

Any implementation that sets `coll@groups` without mirroring onto members
(or vice versa) will fail the validator at the first analysis call — this
is intentional.

### Out of scope for this spec

- The surveytidy-side API shape for `group_by.survey_collection()`.
- Whether `ungroup()` accepts a `vars` argument, per-member or whole-collection.
- Any surveytidy tests or CI.

Filed as a follow-up issue on the surveytidy repo.

---

## X. Testing

Test file: `tests/testthat/test-collection-groups.R`.
Follows `testing-standards.md` (flat `test_that()`, one behavior per block)
and `testing-surveycore.md` (dual-pattern Layer 3 errors; `class=`-only
Layer 1 errors; `make_survey_data()` for synthetic inputs).

### Test-layer mechanics (per §VIII class)

Explicit enumeration of which assertion pattern applies to each class
in §VIII, so the implementer does not have to re-derive it per block:

| Class | Layer | Assertion pattern |
|---|---|---|
| G1 (`..._groups_invariant`) | 1 | `expect_error(class = ...)` only |
| G1b (`..._group_not_in_member_data`) | 1 | `expect_error(class = ...)` only |
| G1c (`..._groups_malformed`) | 1 | `expect_error(class = ...)` only |
| G2 (`..._group_divergent`) | 3 | `expect_error(class = ...)` + `expect_snapshot(error = TRUE)` |
| G3 (`..._group_var_not_found`) | 3 | `expect_error(class = ...)` + `expect_snapshot(error = TRUE)` |
| G4 (`..._group_conflict`) | 3 | `expect_error(class = ...)` + `expect_snapshot(error = TRUE)` |
| G5 (`..._group_mismatch_on_replace`) | 3 | `expect_error(class = ...)` + `expect_snapshot(error = TRUE)` |
| G5b (`..._group_mismatch_on_append`) | 3 | `expect_error(class = ...)` + `expect_snapshot(error = TRUE)` |
| G6 (`..._not_survey_base`) | 3 | `expect_error(class = ...)` + `expect_snapshot(error = TRUE)` |
| G7 (`..._index_out_of_range`) | 3 | `expect_error(class = ...)` + `expect_snapshot(error = TRUE)` |
| G7b (`..._index_bad_type`) | 3 | `expect_error(class = ...)` + `expect_snapshot(error = TRUE)` |
| G8 (`..._group_overridden`, warning) | 3 | `expect_warning(class = ...)` + `expect_snapshot()` |

Layer 1 (S7 validator) classes are `class=`-only per
`testing-surveycore.md`; their messages are not CLI-formatted through
the `cli_abort()` wrapper that produces stable snapshot text. Every
other class is dual-tested.

### Helper

Each constructor block calls `test_invariants(coll)` first, then adds:

```r
test_collection_groups_invariant <- function(coll) {
  for (nm in names(coll@surveys)) {
    expect_identical(coll@surveys[[nm]]@groups, coll@groups)
  }
}
```

Defined in `tests/testthat/helper-test-data.R`.

### Test blocks

**Class invariant (Layer 1 — `class=` only)**
- Direct construction `survey_collection(surveys = list(a = d_grouped),
  groups = character(0))` errors
  `surveycore_error_collection_groups_invariant`.
- Direct construction with mismatched member `@groups` and non-empty
  `coll@groups` errors the same class and names the first divergent
  member.
- **Order sensitivity:** direct construction with
  `coll@groups = c("a","b")` and a member carrying
  `@groups = c("b","a")` errors G1 — confirms `identical()` is
  order-sensitive and that order is part of the invariant.
- **Invariant 2 (G1b) — column not in member `@data`:** direct
  construction where member `@groups = "region"` matches
  `coll@groups = "region"` but member's `@data` has no `region` column
  errors `surveycore_error_collection_group_not_in_member_data` and
  names the offending member plus the missing column.
- **G1b fires through propagation paths too:** `add_survey(coll,
  wave2 = d_no_region)` onto a `region`-grouped collection — where
  `d_no_region`'s `@data` lacks `region` — errors G1b (regression
  against Issue 16). Same for `coll[["wave1"]] <- value` where
  `value@groups` matches but `value@data` lacks the named column.
- **Invariant 3 (G1c) — malformed `@groups`:** direct construction
  with any of `groups = c("a", NA_character_)`, `groups = c("a", "")`,
  or `groups = c("a", "a")` errors
  `surveycore_error_collection_groups_malformed`. A vector that
  violates multiple conditions (e.g., `c(NA_character_, "", "a", "a")`)
  reports all failing conditions in one error (each as a separate
  `"i"` bullet).

**Constructor — happy paths (Layer 3 — dual `class=` + snapshot where applicable)**
- `as_survey_collection(d1, d2, group = region)` sets `coll@groups ==
  "region"` and every member mirrors.
- `as_survey_collection(d1, d2, group = c(region, stratum))` sets both
  vars.
- `as_survey_collection(d1_grouped, d2_grouped)` adopts when identical.
- `as_survey_collection(d1, d2)` with ungrouped members yields
  `character(0)`.
- **Empty `group =` forms** (Issue 4A — all fall to adopt-from-members
  branch): `group = NULL`, `group = character(0)`, `group = c()`, and
  `group = all_of(character(0))` each behave identically to omitting
  `group`. One parametrized block covers all four.

**Constructor — override warning (Issue 3B)**
- Grouped members + `group =` supplied that differs from members'
  non-empty `@groups`: `expect_warning(class =
  "surveycore_warning_collection_group_overridden")`; final
  `coll@groups` equals the supplied `group`; every member's `@groups`
  equals `group`; pre-existing groups are discarded.
- Mixed members (one empty, one non-empty-divergent) + `group =`
  supplied: emits exactly one G8 warning (for the divergent member);
  the empty-groups member is silently propagated.

**Constructor — error paths**
- `as_survey_collection(d1_grouped_A, d2_grouped_B)` errors G2.
- `as_survey_collection(d1, d2, group = missing_col)` errors G3.
- Empty `...` still errors C1 (regression — Decision 8).

**`add_survey()` — Decision 2 matrix**
- Ungrouped + ungrouped → insert unchanged.
- Ungrouped collection + grouped new → errors G4.
- Grouped collection + ungrouped new → propagates (verify new member's
  `@groups`).
- Grouped collection + matching grouped new → insert unchanged.
- Grouped collection + divergent grouped new → errors G4.
- **Atomicity (Issue 19):** `add_survey(coll, a = d_ok, b = d_bad,
  c = d_ok2)` where `d_bad` triggers G4 errors with no member added.
  Assert `identical(result, coll)` is not applicable (call errored);
  instead assert via `tryCatch()` that `coll` in the caller's
  environment is unchanged (same `length()`, same `names()`, same
  member identities) and that neither `d_ok` nor `d_ok2` appears in
  `coll@surveys`.

**`[[<-` — Decision 3 + 9, Issues 7/9/10/12**
- **Replace by name** (Issue 7A): `coll[["wave1"]] <- new_matching` where
  `"wave1"` already exists — length unchanged, no warning, member
  replaced.
- **Append by name**: `coll[["wave3"]] <- new` where `"wave3"` is new —
  length grows by 1.
- **Append by name with collision repair**: assigning a name that
  matches an existing member after repair (constructed scenario) emits
  `surveycore_warning_collection_duplicate_name_repaired`.
- **Empty-string name** (Issue 7A): `coll[[""]] <- new` routes through
  the append path; the new member gets the default repaired name.
- **Replace path — empty `value@groups`** errors G5
  (`surveycore_error_collection_group_mismatch_on_replace`);
  empty-propagation does NOT apply.
- **Replace path — divergent `value@groups`** errors G5 (same class).
- **Append path — empty `value@groups`** (new name assignment onto a
  grouped collection) errors G5b
  (`surveycore_error_collection_group_mismatch_on_append`). Hint
  directs user to `add_survey()`.
- **Append path — divergent `value@groups`** errors G5b.
- **Replace path — same-set-different-order (Issue 21):** with
  `x@groups = c("region", "stratum")` and `value@groups =
  c("stratum", "region")`, `coll[["wave1"]] <- value` errors G5.
  Confirms order sensitivity at the `[[<-` site matches the §III
  validator invariant.
- Replace with non-`survey_base` errors G6.
- **NULL assignment** (Issue 9A): `coll[[i]] <- NULL` errors G6 for
  both character and numeric `i`.
- **`survey_collection` as value**: `coll[["x"]] <- other_collection`
  errors G6 (confirms `survey_collection` does not inherit
  `survey_base`, per `R/core-classes.R:641–644`).
- Numeric `i == length + 1L` appends; new member auto-named
  `paste0("..", i)` and name-repaired against existing names.
- Numeric `i %in% seq_len(length)` replaces; invariant preserved.
- **Out-of-range (G7)**: numeric `i == length + 2L`, `i == 0L`.
- **Bad type (G7b, Issue 12A / Issue 10)**: `i` of length > 1,
  `i = NA_character_`, `i = TRUE`, `i = factor("wave1")`,
  `i = 1.5`, `i = -1L`, `i = integer(0)`, `i = NULL`.

**`remove_survey()` — Decision 10**
- Removing a non-last survey from a grouped collection preserves
  `coll@groups` and remaining members' mirrored `@groups`.
- Removing the last remaining member errors C1
  (`surveycore_error_collection_empty`).

**Dispatch regressions — Decisions 1 + 5**
- `get_means(grouped_coll, y)` returns a single result; group columns
  populated for every row; no per-survey divergence in shape.
- `get_means(coll_by_region, y, group = party)` stacks: result is
  grouped by `region × party`. Assert **column order explicitly** (per
  `.resolve_groups()` at `R/analysis-helpers.R:441`, which concatenates
  `unique(c(from_groups_prop, from_arg))`):
  `c(".survey", "region", "party", <x vars>, <estimate cols…>)`.
  `coll@groups` columns come **before** call-site `group =` columns.

**Print snapshot**
- Ungrouped collection print — unchanged snapshot.
- Grouped collection print — new snapshot including the `Groups:` line.

### Coverage target

98% line coverage for the new code paths (new validator branch, new
`group =` path in constructor, new propagation in `add_survey()`, new
`[[<-` method). `covr::package_coverage()` must not drop package-wide
coverage below the 95% PR gate.

---

## XI. Quality Gates

A pull request implementing this spec is complete when:

- [ ] All tests in `test-collection-groups.R` pass.
- [ ] All existing collection tests (`test-survey-collection.R`,
  `test-survey-collection-dispatch.R`, print snapshot tests) still pass
  without snapshot updates beyond the new grouped-print block.
- [ ] `devtools::check()` passes with 0 errors, 0 warnings, ≤ 2 notes
  (per `r-package-conventions.md`).
- [ ] `covr::package_coverage()` shows ≥ 98% coverage on
  `R/core-classes.R`, `R/core-constructors.R`, `R/survey-collection.R`;
  package-wide coverage ≥ 95%.
- [ ] Every new error class in §VIII has an `expect_error(class = ...)`
  test and, where Layer 3 applies, a matching `expect_snapshot(error =
  TRUE)`.
- [ ] `plans/error-messages.md` contains rows G1, G1b, G1c, G2, G3, G4, G5, G5b, G6, G7, G7b, G8.
- [ ] `plans/decisions-collection-uniform-groups.md` exists and captures
  every Stage 3 review resolution (populated in Stage 4).
- [ ] `NEWS.md` entry under the current `.9000` header lists: new
  `@groups` property, new `group =` argument, new `[[<-` method,
  **breaking change** that construction from divergent-grouped members
  now errors.
- [ ] The squash-merge conventional commit is `feat(classes)!:` to flag
  the breaking change.
- [ ] Manual smoke: build a grouped collection, call `get_means()` with
  and without a call-site `group =`, verify single clean result.

---

## Next steps per spec-workflow

This is a first draft. I expect there are gaps. Next steps:

- This spec does not contain variance estimation, estimators, or
  statistical inference, so **Stage 2 (methodology review) is N/A.**
  Per `stage-1-draft.md`, Stage 2 self-assesses — but see `.claude/skills/
  spec-workflow/references/stage-2-methods-review.md` to confirm before
  proceeding.
- Otherwise: run **Stage 3 (code/architecture review)** in a new session.
- Do not resolve anything until the review is complete.
