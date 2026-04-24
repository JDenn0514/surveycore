# Implementation Plan: `survey_collection` Uniform Grouping

**ID:** collection-uniform-groups
**Status:** Implemented (2026-04-23) — `[[<-` deferred due to R CMD check
`checkReplaceFuns` interaction with S7 method registration; see
`plans/decisions-collection-uniform-groups.md` (2026-04-23, "defer `[[<-`")
and `plans/spec-collection-uniform-groups.md` v0.4 amendment log.
**Depends on:** `survey_collection` (shipped, PR #97 / #98)

---

## Overview

`survey_collection` currently allows its member surveys to carry arbitrary,
divergent `@groups`. `.dispatch_over_collection()` runs `fn(survey, ...)` on
each member, so a single mixed-grouping collection produces a per-survey
patchwork of grouped and ungrouped rows stitched together by `bind_rows()`.
This violates the "pseudo-data.frame" mental model that `survey_collection`
is supposed to present — calling an analysis function on a collection should
return a single result consistent with the collection as a whole, not a
concatenation of differently-shaped per-survey results.

This plan introduces a **uniform-grouping invariant**: the collection owns
a single grouping vector, and every member survey's `@groups` mirrors it.
All paths that mutate the collection (constructor, `add_survey()`, new
`[[<-` setter) enforce the invariant. Analysis dispatch is unchanged —
per-survey `.resolve_groups()` already reads `design@groups`, and with the
invariant in place that value is the same for every member.

`group_by.survey_collection()` / `ungroup.survey_collection()` live in
**surveytidy** and are out of scope here — this PR adds the surveycore-side
invariant they must preserve. A follow-up surveytidy PR will wire them up.

---

## Invariant

For any `coll <- survey_collection(...)`:

```
identical(coll@groups, coll@surveys[[i]]@groups)   # for every i
```

Every construction or mutation path must preserve this. The class validator
(`R/core-classes.R`) enforces it as a structural check — it is the final
backstop if an internal code path forgets.

---

## PR Map

Single PR. The invariant must land atomically with the validator; splitting
would leave a window where member surveys can diverge from the collection's
stated grouping. This is an atomically-scoped single PR touching ~3 R
source files plus two internal helpers and ~2 test files (the new
`test-collection-groups.R` and the updated `test-methods-print.R`
snapshot) — reviewers should expect a larger diff than typical for
this repo.

- **PR 1** — `feature/collection-uniform-groups`
  - Add `@groups` property + validator rule
  - Accept `group =` in `as_survey_collection()` (propagates to members)
  - Enforce invariant in `add_survey()`
  - Add `[[<-` method with validation
  - Update `.dispatch_over_collection()` docs (no behavior change)
  - Error-message table rows
  - Full test suite

Surveytidy follow-up (`group_by.survey_collection()` / `ungroup`) tracked
separately in that repo.

---

## Files

### Modified

- `R/core-classes.R` — add `groups` property to `survey_collection`;
  extend validator with the uniform-groups check.
- `R/core-constructors.R` — add `group` argument to `as_survey_collection()`;
  propagate to each member; error if any input already carries a different
  `@groups`.
- `R/survey-collection.R` — extend `add_survey()` to propagate collection
  groups onto new members (or error on mismatch — see §Decision 2);
  update `remove_survey()` to pass `groups = x@groups` through the
  reconstructed `survey_collection()` call (spec §VII); add internal
  helpers `.check_groups_match()` and `.propagate_or_match()` (spec §II).
- `R/methods-print.R` — surface `@groups` in the `print.survey_collection`
  output when non-empty (update snapshot); add
  `S7::method("[[<-", survey_collection)` adjacent to the existing
  accessor block at `R/methods-print.R:796–798` (`[[`, `length`,
  `names`), per `code-style.md §2` methods-grouped-by-type and
  `decisions-...md` Q-Issue-15.
- `plans/error-messages.md` — append new rows (see §Error Classes).
- `NAMESPACE` — regenerated via `devtools::document()`.
- `tests/testthat/helper-test-data.R` — add the
  `test_collection_groups_invariant()` helper (spec §X / task §8).
- `tests/testthat/_snaps/methods-print.md` — new snapshot block for
  the grouped-collection print output (task §6 / §8).
- `NEWS.md` — four bullets under the current `.9000` header, including
  the **breaking change** flag (task §9).

### Created

- `tests/testthat/test-collection-groups.R` — all new test blocks for
  the invariant, constructor `group =`, `add_survey()` propagation, and
  `[[<-` validation.

No new R source file. `[[<-` lives in `R/methods-print.R` adjacent to
the existing `[[`, `length`, and `names` methods for `survey_collection`
(`R/methods-print.R:796–798`), per `code-style.md §2`
methods-grouped-by-type and `decisions-...md` Q-Issue-15. The file name
is a historical artifact — it already houses non-print methods.

---

## Design Decisions

### Decision 1 — Collection owns groups; members mirror

The collection's `@groups` is the authoritative value. Every member's
`@groups` is kept identical by construction. Dispatch (`.resolve_groups()`
inside each `get_*()` call) reads per-survey `@groups` and therefore sees
the collection-level value without any change to the dispatch helper.

**Rejected alternative:** collection owns `@groups`; members stay
ungrouped; dispatch injects `group = coll@groups` into each `fn()` call.
Less state to sync, but requires every `get_*()` dispatch branch to know
about collection grouping explicitly. Mirroring is a smaller change: one
invariant check at mutation sites, zero changes to dispatch.

### Decision 2 — `add_survey()` propagates empty, errors on mismatch (full 5-row matrix)

For each new survey `new` passed to `add_survey(coll, new)`:

| `coll@groups` | `new@groups` | Action | Class |
|---|---|---|---|
| `character(0)` (empty) | `character(0)` (empty) | Insert unchanged. | — |
| `character(0)` (empty) | non-empty | **Error** — collection is ungrouped; caller must ungroup `new` or group the collection first. | `surveycore_error_collection_group_conflict` (G4) |
| non-empty | `character(0)` (empty) | **Propagate** — `new@groups <- coll@groups`; insert. (Common case: user built a fresh survey for an existing grouped collection.) | — |
| non-empty | `identical(coll@groups)` | Insert unchanged. | — |
| non-empty | non-empty and differs | **Error** — silent override of a user-specified grouping is the footgun we rejected for `[[<-`. | `surveycore_error_collection_group_conflict` (G4) |

**Rationale:** propagating an absent grouping is clearly a helper;
silently replacing a user-specified grouping is not. This matches what
we decided for `[[<-` (Decision 3): validate, don't coerce.
`.propagate_or_match()` from task §0 encapsulates the non-empty-coll
branches; the empty-coll + non-empty-new case is handled inline in
task §3 step 1 because `.propagate_or_match()` does not know about the
ungrouped-coll posture.

### Decision 3 — `[[<-`: validate, don't coerce

`coll[["wave3"]] <- new_survey` errors if `new_survey@groups` differs from
`coll@groups` (regardless of whether it's empty or just mismatched). The
`add_survey()` empty-propagation convenience does NOT apply here —
`[[<-` is the precise tool; use `add_survey()` for the convenience path.

(Decided in chat; captured here for durability.)

### Decision 4 — `group =` in `as_survey_collection()`: override-with-warning when supplied

When `group =` is **supplied** (and resolves to a non-empty vector),
resolve via tidy-select against each member's `@data` — every named
column must exist in every member (else G3). Then, for each member:

- `member@groups` is `character(0)` (empty): silent propagation — set
  `member@groups <- target`.
- `member@groups` is identical to `target`: no-op.
- `member@groups` is non-empty and differs from `target`: propagate
  `target` anyway AND emit
  `surveycore_warning_collection_group_overridden` (G8), naming the
  member, the dropped groups, and the new target. **One G8 per
  divergent member** (not one aggregated warning).

When `group =` is **missing / empty-resolved** (see Decision 4b), consult
the members:

- All members identically grouped → adopt that grouping as `coll@groups`.
- Any member differs (including mix of empty / non-empty) → error
  (`surveycore_error_collection_group_divergent`, G2).
- No member grouped → collection is ungrouped (`@groups = character(0)`).

**Rationale:** override-with-warning on supplied `group =` treats the
argument as declarative ("I want the collection grouped this way") and
surfaces silent data loss through a typed warning. `[[<-` keeps its
stricter validate-don't-coerce posture (Decision 3) — the constructor
is the single site that bends the rule. See
`decisions-collection-uniform-groups.md` Q-Issue-3 (2026-04-22) for the
full rationale.

### Decision 5 — Call-site `group =` stacks with `coll@groups`

When a grouped collection is passed to an analysis function with its own
`group =`, the two stack. `get_means(coll_by_region, y, group = party)`
returns means by `region × party`. No code change: `.resolve_groups()`
(`R/analysis-helpers.R`) already combines `design@groups` with the call-site
`group` quosure, and the uniform-groups invariant (Decision 1) guarantees
every member enters dispatch with the same `@groups`. The regression test
in §8 (Dispatch) exercises this explicitly.

**Rejected alternative:** override semantics (call-site `group` replaces
`coll@groups` for that call). Would require a collection-aware branch in
`.resolve_groups()` or `.dispatch_over_collection()` and diverges from
how a single design behaves today. Keeping the behavior uniform across
single-design and collection inputs is worth more than the override
convenience.

### Decision 6 — `group =` sits before `.id` / `.on_missing` in the signature

New constructor signature:

```
as_survey_collection(..., group, .id = ".survey", .on_missing = "error")
```

All three are named-only (after `...`, per code-style.md §4 carve-out).
`group` precedes `.id` / `.on_missing` so the ordering reads as
"grouping decision first, then collection-dispatch controls."

### Decision 7 — Ungrouping routes only through surveytidy

There is no surveycore-side path to ungroup a collection. To go from
grouped → ungrouped, the user calls `surveytidy::ungroup(coll)`, which
in the follow-up surveytidy PR must zero out `coll@groups` and every
member's `@groups` atomically. `[[<-` never accepts a replacement whose
`@groups` differs from the collection's (including empty-vs-non-empty
— Decision 3). `as_survey_collection(..., group = NULL)` is not a
supported ungroup-in-constructor path either; build an ungrouped
collection from ungrouped members.

### Decision 8 — Empty collection always errors (already enforced)

The S7 validator already rejects an empty `survey_collection` via row C1
(`surveycore_error_collection_empty`). `remove_survey()` delegates to the
constructor, so removal down to zero members also errors through that
same path. No new class, no new code. Add a regression test for the
removal-to-zero case to guard the path against future refactors that
bypass the constructor.

### Decision 9 — `[[<-` allows appending at `length + 1`

Numeric `i` must satisfy `i %in% seq_len(length(x@surveys) + 1L)`.
`i == length + 1L` appends; the new element is auto-named (`paste0("..",
i)`) if it has no name. Out-of-range numeric `i` errors
`surveycore_error_collection_index_out_of_range` (new class). Character
`i`: any new name is allowed; it runs through `.repair_collection_names()`
alongside existing names and emits the existing duplicate-repair warning
if repaired. Group validation (Decision 3) applies regardless of whether
`[[<-` is replacing or appending.

### Decision 10 — `remove_survey()` needs one load-bearing line change

Uniform-groups invariant is preserved trivially after removal (remaining
members still mirror `coll@groups`), and removal to zero members errors
via the existing C1 validator path (Decision 8). **But** `remove_survey()`
currently reconstructs via `survey_collection(surveys = new_list)` with
no `groups` argument, which defaults `@groups` to `character(0)` and
silently de-groups on every removal. Spec §VII requires the one-line
fix: pass `groups = x@groups` through to the reconstructed
`survey_collection()` call. See task §3.5 below for the placement.

---

## Step-by-Step Tasks

### 0. Internal helpers (`R/survey-collection.R`)

Implement the two helpers described in spec §II. Both are
`@keywords internal` + `@noRd`; neither is exported. Place them at the
top of `R/survey-collection.R` before `add_survey()` /
`remove_survey()` so their callers in subsequent tasks can reference
them by name.

1. `.check_groups_match(candidate_groups, target_groups, error_class,
   context = NULL)` — equality-only check.
   `identical(candidate_groups, target_groups)` returns
   `invisible(TRUE)`; otherwise `cli::cli_abort()` with the supplied
   `error_class`. `context` is an optional character(1) for message
   text only (e.g., member name or call site). **Note: this is a
   deliberate deviation from spec §II's three-arg signature.** The spec
   documents "errors with the caller-appropriate class" without naming
   how the class is selected. Passing `error_class` explicitly
   (a) matches the sibling `.propagate_or_match()` signature, (b) keeps
   control flow in the caller, and (c) avoids a hidden context → class
   lookup inside the helper. Callers:
   - Validator → `error_class = "surveycore_error_collection_groups_invariant"` (G1)
   - `[[<-` replace path → `error_class = "surveycore_error_collection_group_mismatch_on_replace"` (G5)
   - `[[<-` append path → `error_class = "surveycore_error_collection_group_mismatch_on_append"` (G5b)
2. `.propagate_or_match(candidate_groups, target_groups, name,
   error_class)` — returns groups to assign: `target_groups` when
   `candidate_groups` is empty (`character(0)`); `candidate_groups`
   when already identical; errors `error_class` on non-empty mismatch.
   Used by `add_survey()` (G4) and `as_survey_collection()`'s
   adopt-from-members branch.
3. Neither helper is used by the constructor's `group =` supplied
   branch — that site inlines because it needs override-with-warning
   semantics (G8) neither helper provides. See spec §II call-site
   table for the full mapping.

Spec §II lines 94–160 is the signature reference; copy the roxygen
stubs verbatim. `decisions-...md` Q-Issue-1 is the rationale for the
two-helper split over a tagged-action single helper.

### 1. Class definition (`R/core-classes.R`)

1. Add `groups = S7::class_character` property with default `character(0)`
   to `survey_collection`.
2. Extend the validator with **three** invariants that run after the
   existing C1–C4 checks (spec §III, lines 174–246). Call
   `.check_groups_match()` from task §0 where applicable; the other
   two invariants are structural and inlined.
   - **Invariant 1 — Equality across members (G1).** Iterate
     `seq_along(self@surveys)` and call
     `.check_groups_match(self@surveys[[i]]@groups, self@groups,
     error_class = "surveycore_error_collection_groups_invariant",
     context = names(self@surveys)[[i]])` per member, exiting on first
     mismatch. Order is part of the invariant (`identical()` is
     order-sensitive). The error names the **first divergent member
     by name** (not index).
   - **Invariant 2 — Resolvability in each member's `@data` (G1b).**
     For each member, assert
     `all(self@groups %in% names(self@surveys[[i]]@data))`. On
     failure, error `surveycore_error_collection_group_not_in_member_data`
     naming the first failing member and the first missing column.
   - **Invariant 3 — Well-formed `@groups` (G1c).** Assert
     `!any(is.na(self@groups))`, `!any(self@groups == "")`, and
     `!anyDuplicated(self@groups)`. On failure, error
     `surveycore_error_collection_groups_malformed` with one `"i"`
     bullet per failing condition — a vector violating multiple
     conditions (e.g., `c(NA_character_, "", "a", "a")`) must report
     all failing conditions in one error pass.
3. Update roxygen `@section Properties` to document `groups`.

### 2. Constructor (`R/core-constructors.R`)

1. Add `group` parameter to `as_survey_collection()` signature. Position:
   after `...`, named-only (matches code-style.md §4 carve-out). Use
   `group = rlang::missing_arg()` as the default; detect absence with
   `rlang::quo_is_missing(rlang::enquo(group))` (spec §IV signature /
   `decisions-...md` Q-Issue-5). Bare base-R `missing(group)` is
   explicitly rejected — it does not compose with downstream tidyselect
   quosure threading.
2. After name resolution and survey evaluation, compute the collection's
   target groups. An empty tidy-select resolution (`group = NULL`,
   `group = character(0)`, `group = c()`, `group = all_of(character(0))`)
   collapses to the adopt-from-members branch — identical to
   `missing(group)` (spec §IV.arguments / `decisions-...md` Q-Issue-4).
   - If `group` is supplied AND resolves to a **non-empty** character
     vector: validate every member has all named columns in its
     `@data` (else G3). Then for each member apply the three sub-cases
     from Decision 4 above:
     - `member@groups` empty → silent propagate.
     - `member@groups` identical to target → no-op.
     - `member@groups` non-empty and divergent → propagate AND emit
       one `surveycore_warning_collection_group_overridden` (G8)
       naming the member, dropped groups, and new target.
   - Else (`group` missing or empty-resolved): call
     `.propagate_or_match()` semantics across members by scanning
     their `@groups`. If all identical (including all empty), adopt
     that value as `coll@groups`. If divergent (including a mix of
     empty and non-empty), error
     `surveycore_error_collection_group_divergent` (G2).
3. **Construct the collection (spec §IV.behavior.3).** Call
   `survey_collection(surveys = propagated_members, groups = target)`
   — passing `groups = target` is load-bearing. Omitting it defaults
   `@groups` to `character(0)` and silently de-groups the collection
   (the same footgun closed for `remove_survey()` in task §3.5 / Pass 1
   Issue 15). The class validator re-asserts G1 / G1b / G1c on
   construction as a backstop.
4. Roxygen: document `group`, add example, update `@details`.

### 3. `add_survey()` (`R/survey-collection.R`)

1. After name repair and before constructing the new collection, enforce
   Decision 2:
   - **Ungrouped-coll branch (inline):** If `.collection@groups` is
     empty and any new survey has non-empty `@groups`: error G4
     (`surveycore_error_collection_group_conflict`). This case is
     inlined because `.propagate_or_match()` does not know about the
     ungrouped-coll posture (Decision 2 / task §0 comment).
   - **Grouped-coll branch (helper):** If `.collection@groups` is
     non-empty: for each new survey, call
     `.propagate_or_match(new@groups, .collection@groups,
     name = <member name>,
     error_class = "surveycore_error_collection_group_conflict")` and
     replace `new@groups` with the return value (the propagated or
     already-matching groups).
2. Construct the final collection with `groups = .collection@groups` and
   the propagated members.
3. **Atomicity (spec §V / `decisions-...md` Q-Issue-19):** build the
   full validated member list first; call `survey_collection()` once at
   the end. Any error raised during per-survey processing aborts before
   the final construction, so `coll` in the caller's environment is
   unchanged. Verified by the atomicity regression test in §8.

### 3.5. `remove_survey()` (`R/survey-collection.R`)

Pass `groups = x@groups` through to the reconstructed
`survey_collection(surveys = new_list, groups = x@groups)` call (spec
§VII / Decision 10). One-line change. Without it, every removal
silently de-groups the collection. Regression test in §8 (`remove_survey`
block) covers this.

### 4. `[[<-` setter (`R/methods-print.R`, adjacent to existing `[[` / `length` / `names` at lines 796–798)

1. Register `S7::method("[[<-", survey_collection)` with signature
   `function(x, i, ..., value)`.
2. **Validate `value` kind (G6).** `value` must inherit `survey_base`.
   In particular, `coll[[i]] <- NULL` errors G6
   (`surveycore_error_not_survey_base`) — `[[<-` does not delete;
   direct callers must use `remove_survey()` (Decision 9 /
   `decisions-...md` Q-Issue-9).
3. **Validate `i` shape (G7b).** `i` must be a length-1 atomic vector
   of class `character` or integerish `numeric` (non-negative,
   non-`NA`). Anything else (multi-length, `NA`, logical, factor,
   zero-length, `NULL`, non-integer double, negative) errors
   `surveycore_error_collection_index_bad_type` (spec §VI step 2 /
   `decisions-...md` Q-Issue-12).
4. **Classify path before the `@groups` check** (spec §VI step 3 /
   `decisions-...md` Q-Issue-7 / Q-Issue-17). Each path has a
   different user remedy, which determines the error class raised in
   step 5:
   - **Character, length 1:**
     - `i %in% names(x@surveys)` → **replace**: overwrite at name;
       length unchanged; no name repair; no warning. (Base-R `[[<-`
       list semantics.)
     - Else → **append with name repair**: run new name through
       `.repair_collection_names()` alongside existing names; emit
       `surveycore_warning_collection_duplicate_name_repaired`
       (existing class) if repaired. Length grows by 1.
     - `i == ""` routes through the append path; repaired name is
       assigned (`..<length+1>` default).
   - **Numeric, length 1:** must satisfy
     `i %in% seq_len(length(x@surveys) + 1L)`.
     - `i %in% seq_len(length)` → **replace**.
     - `i == length + 1L` → **append**; auto-name `paste0("..", i)`,
       run through `.repair_collection_names()` to resolve collisions.
     - Out-of-range → error
       `surveycore_error_collection_index_out_of_range` (G7).
5. **Validate `@groups` with path-specific error class** (spec §VI
   step 4 / `decisions-...md` Q-Issue-17). Call
   `.check_groups_match(value@groups, x@groups, error_class = ...,
   context = ...)` from task §0, passing:
   - Replace path → `error_class =
     "surveycore_error_collection_group_mismatch_on_replace"` (G5).
     Hint: "Set `value@groups <- x@groups` (and ensure grouping
     columns are in `value@data`) before assignment."
   - Append path → `error_class =
     "surveycore_error_collection_group_mismatch_on_append"` (G5b).
     Hint: "Use `add_survey()` if you want empty groups propagated
     automatically, or set `value@groups` manually first."

   Empty-propagation convenience from `add_survey()` does **not**
   apply here (Decision 3 / `decisions-...md` Q-Issue-17). Order is
   part of the check: `c("stratum","region")` against
   `c("region","stratum")` errors even though the two name the same
   set (spec §III Invariant 1 / `decisions-...md` Q-Issue-21).
6. **Assign + re-validate via constructor.** Build the new `@surveys`
   list with `value` at position `i`, then call
   `survey_collection(surveys = ..., groups = x@groups)` so the class
   validator (G1 / G1b / G1c backstop) fires on construction.
7. Add roxygen stub pointing at `add_survey()` for the convenience
   path.

### 5. Dispatch (`R/survey-collection.R`)

No code change. Add a one-paragraph comment at the top of
`.dispatch_over_collection()` explaining that per-survey `@groups` is
guaranteed uniform by the class invariant, and therefore
`.resolve_groups()` inside each `get_*()` call sees the collection-level
grouping automatically.

Read `R/analysis-helpers.R:441` (`unique(c(from_groups_prop, from_arg))`)
to confirm the contract before writing the comment — that line is the
actual dispatch contract the invariant relies on. The dispatch
regression tests in §8 exercise both the single-group case and the
call-site-stacks-with-coll-groups case with explicit column-order
assertions.

### 6. Print method (`R/methods-print.R`)

1. When `length(x@groups) > 0`, print a `Groups: <var1, var2, ...>`
   line under the collection header (insert immediately after the
   header line at `R/methods-print.R:772` and before the
   `.fmt_collection_line()` output at `R/methods-print.R:760–767`,
   per spec §III Print method).
2. Update `test-methods-print.R` snapshot to cover the grouped-collection
   branch.

### 7. Error-message table (`plans/error-messages.md`)

Add the twelve rows below. See spec §VIII for the full cli_abort /
cli_warn message templates (inline markup, `"x"` / `"i"` / `"v"`
bullets). Each row's full text is copied into `plans/error-messages.md`
as part of this task.

| # | Function | Condition | Severity | Class |
|---|----------|-----------|----------|-------|
| G1 | `survey_collection` validator | Member `@groups` differs from `coll@groups` (order-sensitive) | ERROR | `surveycore_error_collection_groups_invariant` |
| G1b | `survey_collection` validator | Member `@groups` names a column not in that member's `@data` | ERROR | `surveycore_error_collection_group_not_in_member_data` |
| G1c | `survey_collection` validator | `coll@groups` contains `NA`, empty string, or duplicates (one `"i"` bullet per failing condition) | ERROR | `surveycore_error_collection_groups_malformed` |
| G2 | `as_survey_collection()` | Members have divergent `@groups` and `group =` missing / empty-resolved | ERROR | `surveycore_error_collection_group_divergent` |
| G3 | `as_survey_collection()` | `group =` names a column missing from a member | ERROR | `surveycore_error_collection_group_var_not_found` |
| G4 | `add_survey()` | New survey `@groups` mismatches collection | ERROR | `surveycore_error_collection_group_conflict` |
| G5 | `[[<-` (replace path) | Assigned survey `@groups` mismatches collection | ERROR | `surveycore_error_collection_group_mismatch_on_replace` |
| G5b | `[[<-` (append path) | Assigned survey `@groups` mismatches collection | ERROR | `surveycore_error_collection_group_mismatch_on_append` |
| G6 | `[[<-` | `value` is not a `survey_base` (includes `NULL` and `survey_collection`) | ERROR | `surveycore_error_not_survey_base` |
| G7 | `[[<-` | Numeric `i` in valid shape but not in `1:(length+1)` | ERROR | `surveycore_error_collection_index_out_of_range` |
| G7b | `[[<-` | `i` wrong shape / type (multi-length, `NA`, logical, factor, non-integer, zero-length, `NULL`, negative) | ERROR | `surveycore_error_collection_index_bad_type` |
| G8 | `as_survey_collection()` | `group =` supplied; a member's non-empty `@groups` differs from target and is being overridden | WARNING | `surveycore_warning_collection_group_overridden` |

Existing classes reused without modification:
- `surveycore_error_collection_empty` (C1) — empty construction path.
- `surveycore_warning_collection_duplicate_name_repaired` — name repair
  in `[[<-` append path.

### 8. Tests (`tests/testthat/test-collection-groups.R`)

Full block list per spec §X. Every constructor block opens with
`test_invariants(coll)` (existing helper) then
`test_collection_groups_invariant(coll)` (new helper below). Use
assertion patterns from the spec §X per-class table: Layer 1 (G1, G1b,
G1c) = `class=`-only; Layer 3 (G2, G3, G4, G5, G5b, G6, G7, G7b) =
dual `expect_error(class =) + expect_snapshot(error = TRUE)`; G8
warning = `expect_warning(class =) + expect_snapshot()`.

**Helper addition (`tests/testthat/helper-test-data.R`)**
- Define `test_collection_groups_invariant(coll)` per spec §X: loops
  over `names(coll@surveys)` asserting
  `expect_identical(coll@surveys[[nm]]@groups, coll@groups)`.

**Class invariant (Layer 1 — `class=` only)**
- Direct construction `survey_collection(surveys = list(a = d_grouped),
  groups = character(0))` errors G1.
- Direct construction with mismatched member `@groups` and non-empty
  `coll@groups` errors G1 and names the first divergent member.
- **Order sensitivity (G1):** `coll@groups = c("a","b")` with member
  `@groups = c("b","a")` errors G1.
- **G1b — column not in member `@data`:** direct construction where
  `member@groups` matches `coll@groups` but member's `@data` lacks
  the named column errors G1b, naming offending member + missing
  column.
- **G1b fires through propagation paths:** `add_survey(coll, wave2 =
  d_no_region)` onto a `region`-grouped collection (member's `@data`
  lacks `region`) errors G1b; same for `coll[["wave1"]] <- value`
  where `value@groups` matches but `value@data` lacks the column.
- **G1c — malformed `@groups`:** direct construction with any of
  `groups = c("a", NA_character_)`, `groups = c("a", "")`,
  `groups = c("a", "a")` errors G1c. A multi-violation vector
  (`c(NA_character_, "", "a", "a")`) reports all failing conditions as
  separate `"i"` bullets in one error.

**Constructor — happy paths**
- `as_survey_collection(d1, d2, group = region)` sets `coll@groups ==
  "region"` and every member mirrors.
- `as_survey_collection(d1, d2, group = c(region, stratum))` sets both.
- `as_survey_collection(d1_grouped, d2_grouped)` adopts when identical.
- `as_survey_collection(d1, d2)` with ungrouped members yields
  `character(0)`.
- **Empty `group =` forms** — parametrized block covering `group = NULL`,
  `group = character(0)`, `group = c()`, `group = all_of(character(0))`
  — each behaves identically to omitting `group`.

**Constructor — G8 override warning**
- Grouped members + `group =` supplied that differs from members'
  non-empty `@groups`: `expect_warning(class =
  "surveycore_warning_collection_group_overridden")`; final
  `coll@groups` equals supplied `group`; every member mirrors; prior
  groups discarded.
- Mixed members (one empty, one non-empty-divergent) + `group =`
  supplied: emits exactly one G8 warning (for the divergent member);
  empty-groups member propagated silently.

**Constructor — error paths**
- `as_survey_collection(d1_grouped_A, d2_grouped_B)` errors G2.
- `as_survey_collection(d1, d2, group = missing_col)` errors G3.
- Empty `...` still errors C1 (regression — Decision 8).

**`add_survey()` — Decision 2 matrix**
- Ungrouped collection + ungrouped new → insert unchanged.
- Ungrouped collection + grouped new → errors G4.
- Grouped collection + ungrouped new → propagates (verify new member's
  `@groups`).
- Grouped collection + matching grouped new → insert unchanged.
- Grouped collection + divergent grouped new → errors G4.
- **Atomicity:** `add_survey(coll, a = d_ok, b = d_bad, c = d_ok2)`
  where `d_bad` triggers G4 — assert via `tryCatch()` that `coll` in
  the caller's environment is unchanged (same `length()`, same
  `names()`, same member identities) and that neither `d_ok` nor
  `d_ok2` appears in `coll@surveys`.

**`[[<-` — Decision 3 + 9**
- **Replace by name:** `coll[["wave1"]] <- new_matching` where
  `"wave1"` already exists — length unchanged, no warning, member
  replaced.
- **Append by name:** `coll[["wave3"]] <- new` where `"wave3"` is new —
  length grows by 1.
- **Append by name with collision repair:** assignment whose name
  collides after repair emits
  `surveycore_warning_collection_duplicate_name_repaired`.
- **Empty-string name:** `coll[[""]] <- new` routes through append
  path; new member gets default repaired name.
- **Replace path — empty `value@groups`** errors G5 (empty-propagation
  does NOT apply).
- **Replace path — divergent `value@groups`** errors G5.
- **Replace path — same-set-different-order:** `x@groups =
  c("region","stratum")` vs `value@groups = c("stratum","region")`
  → G5.
- **Append path — empty `value@groups`** (new-name assignment onto a
  grouped collection) errors G5b. Hint directs to `add_survey()`.
- **Append path — divergent `value@groups`** errors G5b.
- **Replace with non-`survey_base`** errors G6.
- **NULL assignment:** `coll[[i]] <- NULL` errors G6 for both
  character and numeric `i`.
- **`survey_collection` as value:** `coll[["x"]] <- other_collection`
  errors G6 (confirms `survey_collection` does not inherit
  `survey_base`).
- Numeric `i == length + 1L` appends; auto-named `paste0("..", i)` and
  name-repaired.
- Numeric `i %in% seq_len(length)` replaces; invariant preserved.
- **Out-of-range (G7):** `i == length + 2L`, `i == 0L`.
- **Bad type (G7b):** `i` of length > 1, `i = NA_character_`,
  `i = TRUE`, `i = factor("wave1")`, `i = 1.5`, `i = -1L`,
  `i = integer(0)`, `i = NULL`.

**`remove_survey()`**
- Removing a non-last survey from a grouped collection preserves
  `coll@groups` and remaining members' mirrored `@groups`.
- Removing the last remaining member errors C1.

**Dispatch regressions — Decisions 1 + 5**
- `get_means(grouped_coll, y)` returns a single result; group columns
  populated for every row; no per-survey divergence in shape.
- `get_means(coll_by_region, y, group = party)` stacks — assert
  **column order explicitly** per `.resolve_groups()` at
  `R/analysis-helpers.R:441` (`unique(c(from_groups_prop, from_arg))`):
  `c(".survey", "region", "party", <x vars>, <estimate cols...>)`.
  `coll@groups` columns come **before** call-site `group =` columns.

**Print snapshot**
- Ungrouped collection print — unchanged snapshot.
- Grouped collection print — new snapshot including the `Groups:` line
  between header and member listing.

### 9. Docs / NEWS

1. `NEWS.md` bullets under the current `.9000` header:
   - `survey_collection` gains a `@groups` property (uniform across
     members).
   - `as_survey_collection()` gains a `group =` argument.
   - `[[<-` setter added for `survey_collection` with group validation.
   - **Breaking change:** constructing a `survey_collection` from
     members with divergent `@groups` now errors (previously produced
     a mixed-output patchwork via dispatch). See spec §I Scope for the
     full delta.
2. Roxygen updates on `survey_collection`, `as_survey_collection()`,
   `add_survey()`, and `[[<-` (the last gets a new `@name
   sub-assign.survey_collection` block).
3. Run `devtools::document()` before commit.

### 10. Verification

Spec §XI is the authoritative quality-gate checklist; this section
lists the local commands the implementer runs before opening the PR.

- `devtools::test()` — full suite green.
- `devtools::check()` — 0E / 0W / ≤ 2N.
- `covr::package_coverage()` — ≥ 98% coverage on `R/core-classes.R`,
  `R/core-constructors.R`, `R/survey-collection.R`, `R/methods-print.R`
  (new code paths); package-wide coverage ≥ 95% (PR gate).
- All existing collection tests (`test-survey-collection.R`,
  `test-survey-collection-dispatch.R`, print snapshots) still pass with
  **no** snapshot updates beyond the new grouped-print block.
- `plans/error-messages.md` contains rows G1, G1b, G1c, G2, G3, G4, G5,
  G5b, G6, G7, G7b, G8.
- Every new error class has `expect_error(class = ...)`; every Layer 3
  class additionally has `expect_snapshot(error = TRUE)`; G8 has
  `expect_warning(class =) + expect_snapshot()`.
- `plans/decisions-collection-uniform-groups.md` is present and records
  every Stage 3 plan-review resolution.
- Manual smoke: build a grouped collection, call `get_means()` with and
  without a call-site `group =`, verify single clean result.
- Squash-merge commit uses `feat(classes)!:` prefix (per spec §XI) to
  flag the breaking change.

---

## Out of Scope

- `group_by.survey_collection()` / `ungroup.survey_collection()` — live
  in surveytidy. Filed as a follow-up issue on that repo; must preserve
  the invariant by propagating through every member.
- Changing `.dispatch_over_collection()` behavior or the
  `.warn_on_meta_divergence()` scope.
- `.id` / `.on_missing` semantics — unchanged.

---

## Risk & Rollback

Low risk. New property with a safe default (`character(0)`) — existing
collections with no members carrying `@groups` continue to construct
identically. The only user-visible behavior change is that constructing a
collection from members with divergent `@groups` now errors instead of
silently producing mixed output — which is the bug we're fixing.

Rollback: revert the feature branch; no migration needed since
`@groups` defaults to `character(0)`.
