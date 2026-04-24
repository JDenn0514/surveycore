# Spec Review: collection-uniform-groups

## Pass 1 (2026-04-22)

### New Issues

#### Section II — Architecture / Invariant helper

**Issue 1: `.check_groups_match()` helper cannot serve all three call sites**
Severity: REQUIRED
Violates `engineering-preferences.md §1` (DRY) and §3 (Explicit over clever).

§II describes a single internal helper "to keep validation logic DRY across the
constructor, `add_survey()`, and the `[[<-` setter." But the three sites have
three different acceptance rules:

- Constructor with `group =` supplied: propagate `group` onto every member,
  regardless of its prior `@groups` (§IV.2 bullet 1).
- `add_survey()`: propagate when `new@groups` is `character(0)`; error when
  non-empty and differing (Decision 2, §V matrix).
- `[[<-`: require `identical(value@groups, x@groups)` exactly; empty-propagation
  does not apply (Decision 3, §VI.2).

A `.check_groups_match(candidate_groups, target_groups, context)` helper that
only returns `invisible(TRUE)` or errors cannot express the
"propagate when empty" branch that the constructor and `add_survey()` both
need. Nor does the helper signature carry the member name required by G4
(`"… adding survey {.val {name}}"`) or G1 (`first_divergent_name`).

The spec should either (a) state that the helper is a pure equality checker
used only by `[[<-` and the S7 validator, with the propagation logic inlined
in the constructor and `add_survey()`, or (b) widen the helper to return a
tagged result `list(action = "ok"|"propagate"|"error", target = …)` and
specify the per-site dispatch rules.

Options:
- **[A]** Narrow the helper to equality-only (serves validator + `[[<-`); inline
  propagation logic with a second helper `.propagate_or_match(candidate, target, name)`
  that the constructor and `add_survey()` call. — Effort: low, Risk: low,
  Maintenance: low.
- **[B]** Keep one helper but return a tagged action list; every caller branches
  on it. — Effort: medium, Risk: medium (control flow by string label is
  opaque), Maintenance: medium.
- **[C] Do nothing** — implementer guesses; DRY is not actually achieved.

**Recommendation: [A]** — Two small, narrowly-scoped helpers are clearer than
one helper that does three jobs.

---

#### Section III — Class: `survey_collection`

**Issue 2: Print example in §III does not match the live print format**
Severity: REQUIRED
Violates `stage-3-review.md` Lens 3 (Contract Completeness — print format must
be shown verbatim).

§III shows the expected print output as:

```
# <survey_collection>  2 surveys: wave1, wave2
Groups: region, stratum
# ...
```

The live implementation at `R/methods-print.R:769–790` emits:

```
A <survey_collection> with 2 survey(s):
  "wave1": survey_taylor, N rows, M variables
  "wave2": survey_taylor, N rows, M variables
```

An implementer reading the spec cannot tell whether the header is being
redesigned (and where `Groups:` should be inserted relative to the member
lines) or whether the example is merely a loose sketch. The actual insertion
point (immediately after the header line, before the member list) should be
shown against the real header text, so that the printed test snapshot is
unambiguous.

Options:
- **[A]** Replace the §III example with a verbatim block showing the actual live
  header and the new `Groups:` line in its exact position, e.g.:
  ```
  A <survey_collection> with 2 survey(s):
  Groups: region, stratum
    "wave1": survey_taylor, 100 rows, 5 variables
    "wave2": survey_taylor, 100 rows, 5 variables
  ```
  Effort: low, Impact: high.
- **[B]** Redesign the header to match the §III sketch as part of this PR (new
  scope). — Effort: medium, Risk: medium (breaks existing print snapshot
  tests out of scope for this spec).
- **[C] Do nothing** — implementer must compare against `R/methods-print.R`.

**Recommendation: [A]** — Scope discipline; the spec's job is grouping, not
a print redesign.

---

#### Section IV — Function: `as_survey_collection()`

**Issue 3: Constructor `group =` silently overrides pre-existing member `@groups`**
Severity: REQUIRED
Violates `engineering-preferences.md §3` (Engineered enough — edge cases) and
Lens 6 (API Coherence).

§IV step 2 bullet 1: "If `group` is supplied: resolve via tidy-select against
each member's `@data`; every named column must exist in every member.
**Propagate the resolved character vector onto each member's `@groups`.**"

This propagation is unconditional. Consider:

```r
d1 <- as_survey(df, …) |> surveytidy::group_by(region)
d2 <- as_survey(df, …) |> surveytidy::group_by(region)
# User forgets they already grouped, and rewraps:
coll <- as_survey_collection(d1, d2, group = stratum)
```

Under §IV as written, `coll@groups == "stratum"`, `d1@groups == "stratum"`,
`d2@groups == "stratum"`. The `region` grouping is silently discarded. This
is the exact footgun Decision 3 rejects for `[[<-` ("validate, don't coerce")
but the constructor sits at a different end of the spectrum.

At minimum the behavior should be specified explicitly (silent override,
warn, or error). The existing text reads as "silent override" but that is
inconsistent with the spec's overall philosophy.

Options:
- **[A]** Spec that the constructor errors with
  `surveycore_error_collection_group_divergent` when `group =` is supplied
  AND any member has non-empty `@groups` that differs from the resolved
  `group`. Matches Decision 3 philosophy; user must `ungroup()` first.
  Effort: low, Risk: low, Impact: prevents silent data loss.
- **[B]** Silent override, as currently written. Warn via a new
  `surveycore_warning_collection_group_overridden` when the override drops
  non-empty pre-existing groups. Effort: low, Risk: low, Impact: user sees
  the discard happen.
- **[C] Do nothing** — silent override, no warning. Spec philosophy is
  inconsistent between constructor and `[[<-`.

**Recommendation: [A]** — Matches the project's "validate, don't coerce"
posture and makes the constructor symmetric with `[[<-`. If [B] is chosen
instead, add the warning class to §VIII.

---

**Issue 4: Constructor behavior for empty `group =` inputs is undefined**
Severity: REQUIRED
Violates Lens 4 (Edge Cases).

§IV does not specify what happens for any of these inputs:

- `group = character(0)` (explicit empty vector)
- `group = NULL`
- `group = all_of(character(0))` (tidy-select resolving to zero columns)
- `group = c()` (base R empty)

All four can plausibly mean either "no grouping" (i.e., equivalent to
`missing(group)`, adopt from members or leave ungrouped) or "ungroup the
collection" (which Decision 7 explicitly rejects as a surveycore-side path).
A user who builds a `group` variable programmatically will hit one of these.

Options:
- **[A]** Treat all four as equivalent to `missing(group)` — same dispatch as
  Decision 4's "no `group` given" branch. Effort: low, Risk: low.
- **[B]** Error on all four with a new
  `surveycore_error_collection_group_empty` class, directing users to
  `surveytidy::ungroup()` for an explicit ungroup. Effort: low, Risk: low.
- **[C] Do nothing** — implementer guesses; behavior is undefined.

**Recommendation: [A]** — Consistent with tidyselect conventions (empty
resolution is a no-op); avoids adding a class for a rare case.

---

**Issue 5: `group` argument has no default; `missing(group)` dispatch unstated**
Severity: SUGGESTION
Violates Lens 3 (Contract Completeness).

The §IV signature is:

```r
as_survey_collection(
  ...,
  group,
  .id         = ".survey",
  .on_missing = "error"
)
```

`group` has no default, so the constructor uses `missing(group)` or
`rlang::maybe_missing()` to detect absence. §IV uses the English phrase
"`missing` means 'adopt from members or leave ungrouped.'" — the actual
dispatch mechanism (`missing()`, `rlang::quo_is_missing()`, default
`group = rlang::missing_arg()`, etc.) is not stated. Because `group` needs
tidy-select evaluation when supplied, a trivial `group = NULL` default is
not suitable; the choice between `missing()` and `rlang::maybe_missing()`
matters for how downstream code threads the quosure.

Options:
- **[A]** Set `group` default via `group = rlang::missing_arg()` and detect with
  `rlang::quo_is_missing(rlang::enquo(group))`. Matches surveycore's other
  tidy-select args.
- **[B]** Use `missing(group)`; capture quosure only when `!missing(group)`.
  Simpler; no rlang dependency beyond what's already used.
- **[C] Do nothing** — implementer picks; behavior likely correct but spec is
  silent.

**Recommendation: [B]** — Smallest surface; aligns with how `add_survey()`
already handles its variadic input.

---

#### Section V — Function: `add_survey()`

**Issue 6: "Identical to `new@groups`" uses order-sensitive `identical()`**
Severity: REQUIRED
Violates Lens 3 (Contract Completeness) and Lens 4 (Edge Cases).

§V "non-empty, identical to `new@groups` → Insert unchanged" and §III
validator rule both rely on `identical()`, which is order-sensitive.
`c("a", "b")` and `c("b", "a")` are not `identical()` but produce the same
groups semantically (groupings are commutative in meaning, not vector order).

The spec should state either (a) order IS part of the invariant (so surveytidy
must canonicalize before assigning), or (b) equality is
`setequal()`-based. The validator message text should reflect the choice.

Options:
- **[A]** Order IS part of the invariant. Document that surveytidy's
  `group_by.survey_collection()` must set member `@groups` in the same order
  as `coll@groups`. Effort: low, Risk: low (existing `identical()` check
  already works this way).
- **[B]** Loosen to `setequal()` / use a sorted-equal helper. Effort: low, Risk:
  medium — changes the validator semantics and affects downstream
  `.resolve_groups()` call order.
- **[C] Do nothing** — order sensitivity is implicit; users will hit it once
  and file a bug.

**Recommendation: [A]** — Keep `identical()`; state it explicitly. Order
carries meaning (e.g., `group_by(region, stratum)` vs `group_by(stratum,
region)` can produce different downstream orderings).

---

#### Section VI — Method: `[[<-`

**Issue 7: Character `i` matching an existing name — replacement vs
append-with-repair is undefined and diverges from base R**
Severity: BLOCKING
Violates Lens 6 (API Coherence).

§VI.3 bullet 1: "Character, length 1: any name is allowed; resolve through
`.repair_collection_names()` against the existing-plus-new name set; emit the
existing duplicate-repair warning if repaired."

Consider `coll[["wave1"]] <- new`, where `"wave1"` is already a member name.
Two incompatible readings:

1. **Replace** (base R semantics): `new` overwrites the existing `wave1`.
   Length unchanged, no warning.
2. **Append-with-repair** (literal spec reading): `.repair_collection_names()`
   sees `"wave1"` already used, renames the new entry to `"wave1_1"`, and
   appends. Length grows by 1, warning fires.

The test plan in §X says "Replace with matching-group survey works; invariant
preserved" — which supports reading (1). But the spec body supports reading
(2). Base R users will assume (1); any other behavior is a footgun. An
implementer following the spec text as written will ship (2) and break the
test.

Options:
- **[A]** Explicitly specify: character `i` matching an existing name replaces;
  character `i` not in `names(x@surveys)` appends and runs through name
  repair. Split the §VI.3 bullet into two subcases. Effort: low, Risk: low.
- **[B]** Reject character `i` matching an existing name (force users to use
  `add_survey()` for appends and something else for replacement). — High
  friction, surprising.
- **[C] Do nothing** — implementer picks, and one of the reasonable test
  assertions fails.

**Recommendation: [A]** — Standard base-R semantics; symmetric with numeric
`i` (which replaces when `i <= length`, appends when `i == length + 1L`).

---

**Issue 8: `value@collection_name` refers to a property that does not exist**
Severity: BLOCKING
Violates Lens 3 (Contract Completeness).

§VI.3 bullet 2 (numeric `i`): "the appended element is auto-named
`paste0("..", i)` if `value` carries no `@collection_name` equivalent (names
come from the assignment `i`)."

`survey_base` and its subclasses have no `@collection_name` property. This
reads like a draft-editing artifact. The implementation plan at
`/Users/jacobdennen/surveycore/plans/impl-collection-uniform-groups.md`
Decision 9 says simply: "the new element is auto-named (`paste0("..", i)`)
if it has no name." That's coherent; the `@collection_name` clause is not.

Options:
- **[A]** Delete the `@collection_name` clause. State: "Numeric `i` append
  case — the new element is auto-named `paste0("..", i)`, then run through
  `.repair_collection_names()` alongside existing names to resolve any
  collision (e.g., existing member `'..3'` when appending at `i = 3`)."
  Effort: trivial.
- **[B]** Add a `@collection_name` property to `survey_base`. — Out of scope;
  rejected implicitly.
- **[C] Do nothing** — implementer guesses.

**Recommendation: [A]** — Clear typo-level fix; matches the impl plan.

---

**Issue 9: `coll[[i]] <- NULL` semantics are unspecified**
Severity: REQUIRED
Violates Lens 4 (Edge Cases) and Lens 6 (API Coherence).

Base R uses `x[[i]] <- NULL` to delete list elements. `coll[[i]] <- NULL`
on a `survey_collection` has three plausible behaviors:

1. Error (NULL is not a `survey_base`; G6 applies).
2. Delegate to `remove_survey()` (with the invariant preserved trivially).
3. Silently reduce the collection length by 1; error if that leaves zero
   members (C1).

§VI is silent. Users who know base R will expect behavior 2 or 3.

Options:
- **[A]** Error with G6 (`surveycore_error_not_survey_base`). Simple,
  consistent with the "strict typing" posture of the rest of the spec.
- **[B]** Delegate to `remove_survey(x, name)` when `i` is character, and to
  `remove_survey(x, names(x@surveys)[[i]])` when `i` is numeric. Preserves
  base R ergonomics.
- **[C] Do nothing** — implementer picks; behavior is surprising either way.

**Recommendation: [A]** — Consistent typing; users who want removal have an
explicit API (`remove_survey()`). Add a test case covering the NULL
assignment → G6 path.

---

**Issue 10: Catch-all "wrong shape of `i`" doesn't enumerate realistic inputs**
Severity: REQUIRED
Violates Lens 4 (Edge Cases).

§VI.3 says "Any other `i` (multi-length, NA, logical, etc.) errors
`surveycore_error_collection_index_out_of_range`." The "etc." leaves out:

- Negative numeric `i` (e.g., `coll[[-1]] <- …`)
- Non-integer numeric `i` (e.g., `coll[[1.5]] <- …`)
- Zero-length `i` (`coll[[integer(0)]] <- …`)
- Logical `i` of any length (base R has special semantics but the spec
  should just reject)
- `factor` and other atomic classes

Some of these are footguns users will encounter during programmatic use.
G7 can reasonably cover all of them, but the spec should enumerate which
inputs hit G7 and what the error message looks like for each.

Options:
- **[A]** Add an "Input class check" subsection to §VI.3: `i` must be a
  length-1 atomic vector of class `character` or `integerish` (non-NA,
  non-negative, ≥ 1, ≤ `length(x@surveys) + 1L`); everything else errors
  G7. State expected error messages.
- **[B]** Split G7 into multiple classes: one for wrong type, one for
  out-of-range. Better diagnostics; more error classes.
- **[C] Do nothing** — implementer ad-libs; test plan doesn't cover these.

**Recommendation: [A]** — Enumerate without multiplying error classes.

---

#### Section VIII — Error Table

**Issue 11: G1 validator "not CLI-formatted" note is misleading**
Severity: SUGGESTION
Violates Lens 3 (Contract Completeness).

G1's message shows cli markup (`{.val ...}`) but is marked "(validator text;
not CLI-formatted)." This is a miscommunication: Layer 1 S7 validators in
this codebase DO call `cli::cli_abort` with markup (see `core-classes.R`
lines 682–728 for C1/C2/C4). The "not CLI-formatted" tag really means
**"not dual-tested with a snapshot"** — that's the Layer 1 vs Layer 3 testing
rule from `testing-surveycore.md`, not a formatting rule.

Options:
- **[A]** Reword: "(Layer 1 — `class=`-only test; no snapshot)" and leave the
  message with markup intact. Effort: trivial.
- **[B] Do nothing** — wording is misleading but not a bug.

**Recommendation: [A]** — Tiny edit; prevents misimplementation.

---

**Issue 12: G7 conflates two distinct error conditions into one class**
Severity: SUGGESTION
Violates `engineering-preferences.md §5` (Explicit over clever).

G7 covers both "numeric `i` out of range" AND "`i` has wrong shape (NA,
multi-length, logical, etc.)". These are methodologically different: the
first means "you chose a valid kind of index but the wrong value"; the
second means "you chose an invalid index type." Separate classes would
give better error targeting for users writing programmatic code.

Options:
- **[A]** Split into `surveycore_error_collection_index_out_of_range` (numeric
  in wrong numeric range) and `surveycore_error_collection_index_bad_type`
  (wrong shape/type). Effort: low; 1 extra class + 1 extra row.
- **[B] Do nothing** — one class works, error message text distinguishes cases.

**Recommendation: [B]** — Single class keeps the error table smaller. The
cli message text can still distinguish the cases. Keep unless Stage 4
discovers a concrete downside.

---

#### Section X — Testing

**Issue 13: Test plan has gaps for the blocking / required cases above**
Severity: REQUIRED
Violates Lens 2 (Test Completeness).

Currently missing:

- `coll[["existing_name"]] <- new_grouped_survey` — replacement case (Issue 7).
- `coll[[i]] <- NULL` — whatever behavior is decided in Issue 9.
- Order-sensitivity test: `coll@groups = c("a","b")` with a member rebuilt
  to `@groups = c("b","a")` — verify validator fires G1.
- Constructor with `group = character(0)` and `group = all_of(character(0))`
  (Issue 4).
- Constructor with `group =` supplied AND members carry non-empty divergent
  groups (Issue 3) — whatever behavior is decided (error vs warn vs
  silent).
- Stacked dispatch: column order in `get_means(coll_by_region, y, group =
  party)` output — must assert `region`-before-`party` (per
  `.resolve_groups` `unique(c(from_groups_prop, from_arg))` at
  `R/analysis-helpers.R:441`).
- Validator test for character `i` = string with length 0 (e.g., `""`).
- Test for `coll[[i]] <- coll2` where `coll2` is another `survey_collection`
  (must hit G6 because `survey_collection` deliberately does not inherit
  `survey_base` per `R/core-classes.R:641–644`).

Options:
- **[A]** Add the above blocks to §X. Effort: low.
- **[B] Do nothing** — coverage gate may still pass numerically (98% lines)
  without these; behavioral gaps remain.

**Recommendation: [A]** — Spec test plan is the implementer's checklist;
completeness here prevents rework.

---

**Issue 14: Dispatch regression test defers to "existing contract" instead of
stating expected column order**
Severity: SUGGESTION
Violates Lens 3 (Contract Completeness).

§X ("Dispatch regressions") currently says: "Column names / order per the
analysis function's existing contract; this test guards that the collection
adds no surprise behavior relative to a single grouped design."

That's circular — the whole point of the regression test is to pin the
column order. Citing "the existing contract" leaves the implementer to
re-derive what it is. The `.resolve_groups()` implementation makes
`coll@groups` columns come first, then `group =` columns
(`unique(c(from_groups_prop, from_arg))`).

Options:
- **[A]** State the expected column order explicitly:
  `c(".survey", <coll@groups>, <call-site group>, <x vars>, <estimate cols>…)`.
  Include a concrete example in the spec. Effort: trivial.
- **[B] Do nothing** — test gets written loosely.

**Recommendation: [A]** — Pin the ordering; matches spec's "explicit over
clever" rule.

---

#### Section II — Architecture (revisited for file placement)

**Issue 15: `[[<-` file placement inconsistent with sibling accessors**
Severity: SUGGESTION
Violates `code-style.md §2` (S7 method file organization) loosely.

§II places `[[<-` in `R/survey-collection.R` next to `add_survey()` /
`remove_survey()` with the rationale "feature-group placement." But the
sibling S7 accessors — `[[`, `length`, `names` for `survey_collection` —
all live in `R/methods-print.R:796–798`. Colocating `[[<-` with `[[`,
`length`, `names` would keep the accessor family together and match the
"methods grouped by type in dedicated files" convention from
`code-style.md §2`.

Options:
- **[A]** Place `[[<-` in `R/methods-print.R` alongside `[[`, `length`,
  `names`. File name is misleading ("methods-print" houses non-print
  methods already) but consistency wins. Effort: trivial.
- **[B]** Place `[[<-` in `R/survey-collection.R` per the current spec (feature
  group). — Fragments the accessor family.
- **[C]** Rename `R/methods-print.R` → `R/methods-collection.R` or similar to
  reflect its actual content. — Out of scope.

**Recommendation: [A]** — Accessor colocation > feature-group colocation
when the feature is already small.

---

### Cross-section notes

Nothing new: Decision 8 (empty collection C1 path), §VII (`remove_survey()`
one-line pass-through), §IX (surveytidy integration contract), and §XI
(quality gates) are internally consistent and do not require spec changes
beyond what is captured above.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 2 |
| REQUIRED | 8 |
| SUGGESTION | 5 |

**Total issues:** 15

**Overall assessment:** The spec is architecturally sound and the core
invariant is well-motivated, but two blocking ambiguities in `[[<-` (the
replace-vs-append semantics for a character `i` that matches an existing
name, and the phantom `@collection_name` property) must be resolved before
the implementer can proceed. Beyond those, the most important fix is
specifying what the constructor does when `group =` is supplied and members
already carry non-empty groups — the current text reads as a silent override
that conflicts with Decision 3's explicit rejection of the same pattern for
`[[<-`. Once those and the edge-case gaps (NULL assignment, empty `group =`,
order sensitivity) are pinned, the spec is implementable.

---

## Pass 2 (2026-04-22)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | `.check_groups_match()` helper cannot serve all three call sites | ✅ Resolved — §II now specifies two helpers (`.check_groups_match`, `.propagate_or_match`) with call-site map |
| 2 | Print example in §III does not match the live print format | ✅ Resolved — §III shows verbatim output against actual header text |
| 3 | Constructor `group =` silently overrides pre-existing member `@groups` | ✅ Resolved — §IV.2 now warns-and-overrides via new G8 class |
| 4 | Constructor behavior for empty `group =` inputs is undefined | ✅ Resolved — §IV args table collapses `NULL`, `character(0)`, `c()`, `all_of(character(0))` to `missing` |
| 5 | `group` argument has no default; `missing(group)` dispatch unstated | ✅ Resolved — §IV specifies `rlang::missing_arg()` + `quo_is_missing()` |
| 6 | "Identical to `new@groups`" uses order-sensitive `identical()` | ✅ Resolved — §III explicitly states order is part of the invariant, with justification |
| 7 | Character `i` matching an existing name — replace vs append | ✅ Resolved — §VI.3 splits replace (existing name) vs append-with-repair (new name); also covers `i == ""` |
| 8 | `value@collection_name` refers to non-existent property | ✅ Resolved — §VI.3 numeric path uses `paste0("..", i)` + name repair |
| 9 | `coll[[i]] <- NULL` semantics unspecified | ✅ Resolved — §VI.1 errors G6 |
| 10 | Catch-all "wrong shape of `i`" doesn't enumerate realistic inputs | ✅ Resolved — §VI.3 enumerates; G7b added for bad type |
| 11 | G1 validator "not CLI-formatted" note is misleading | ✅ Resolved — reworded to "Layer 1 — `class=`-only test; no snapshot" |
| 12 | G7 conflates two distinct error conditions | ✅ Resolved — split into G7 (out_of_range) + G7b (bad_type) |
| 13 | Test plan has gaps for the blocking / required cases above | ✅ Resolved — §X blocks added for every new behavior |
| 14 | Dispatch regression test defers to "existing contract" | ✅ Resolved — §X pins column order `c(".survey", "region", "party", …)` |
| 15 | `[[<-` file placement inconsistent with sibling accessors | ✅ Resolved — §II places `[[<-` in `R/methods-print.R` |

All Pass 1 issues are resolved in v0.2. Pass 2 findings below are new, arising
from reading the v0.2 edits as an integrated whole.

### New Issues

#### Section V — `add_survey()` / Section VI — `[[<-`

**Issue 16: Propagation paths do not validate that the grouping column(s) exist in the incoming member's `@data`**
Severity: REQUIRED
Violates Lens 4 (Edge Cases) and `engineering-preferences.md §4`.

§IV.2 is explicit that when `group =` is supplied to the constructor, every
named column must exist in every member (G3:
`surveycore_error_collection_group_var_not_found`). But two other paths
inject a grouping vector onto a member without checking that the columns
actually exist in that member's `@data`:

1. **`add_survey()` propagation** (§V matrix, "non-empty / character(0) →
   Propagate"): `new@groups <- coll@groups` is assigned even if
   `coll@groups` names columns that are not in `names(new@data)`.
2. **`[[<-` replacement by name with matching groups** (§VI.3 character
   case): `value@groups` is compared to `x@groups` via `identical()`, but
   neither side verifies that those column names resolve in `value@data`.

Concrete reproduction:

```r
d1 <- as_survey(df1_with_region, …)   # has a `region` column
d2 <- as_survey(df2_no_region,  …)    # does NOT have `region`
coll <- as_survey_collection(d1, group = region)  # G3 would fire — good
coll <- as_survey_collection(d1, group = region)  # single-member grouped
add_survey(coll, wave2 = d2)          # silent propagation → invalid member
```

After the last line, `coll@surveys[["wave2"]]@groups == "region"` but
`"region" %in% names(coll@surveys[["wave2"]]@data)` is `FALSE`. The S7
validator still passes (all members mirror `coll@groups`), but the first
call to `get_means(coll, y)` will fail with a cryptic "column not found"
from `.resolve_groups()` / downstream dispatch. Same problem for
`coll[["wave1"]] <- modified_d_missing_region_col`.

§III's validator text promises an invariant but enforces only *equality
across members*, not *resolvability against each member's data*. The
contract is therefore incomplete.

Options:
- **[A]** Add a column-existence check to `.propagate_or_match()` (using
  `candidate@data` / caller-supplied `data`) that fires G3 in the
  `add_survey()` and `[[<-` paths. Optionally promote G3 to a shared class
  reused by all three sites, or split into a new
  `surveycore_error_collection_group_not_in_member_data` class that names
  the specific member. Effort: low, Risk: low.
- **[B]** Extend the S7 class validator to cross-check each member's
  `@groups` against `names(member@data)`. Effort: low, Risk: low;
  centralizes the check but lumps "divergence" and "unresolvable" into
  one validator pass.
- **[C] Do nothing** — invariant preserved structurally; user gets a
  cryptic error at analysis time.

**Recommendation: [B]** — A single validator extension catches every path
(direct S7 construction, `add_survey()`, `[[<-`, future surveytidy methods)
with one rule. Emit a distinct error class (e.g.,
`surveycore_error_collection_group_not_in_member_data`) to separate
"divergence" (G1) from "missing column" (new). This matches the spec's
"validator is the final backstop" posture already stated in §II.

---

#### Section VIII — Error table

**Issue 17: G5 hint is only actionable for the append path, not for the replace path introduced in Issue 7**
Severity: SUGGESTION
Violates Lens 6 (API Coherence).

G5's `"v"` bullet reads:

> `"v" = "Use {.fn add_survey} if you want empty groups propagated automatically."`

Before Pass 1 resolution, `[[<-` was effectively append-only; this hint
was unambiguous. After Issue 7 (Decision on §VI), `[[<-` also replaces by
existing name — and `add_survey()` cannot replace. A user who writes

```r
coll[["wave1"]] <- modified_wave1   # modified_wave1@groups == character(0)
```

hits G5 and follows the hint to `add_survey(coll, modified_wave1)`, which
*appends* a new member (possibly with a repaired name) rather than
replacing `wave1`. The hint therefore sends replace-intent users to a
different observable behavior than they intended.

Options:
- **[A]** Refine the G5 `"v"` bullet to cover both paths, e.g.:
  ```
  "v" = "To replace, set {.code value@groups <- x@groups} before assignment.
         To append an ungrouped survey, use {.fn add_survey}."
  ```
  Effort: trivial.
- **[B]** Split G5 into two error classes keyed on whether the `[[<-` call
  is a replace or an append, each with a tailored hint. Effort: low,
  Risk: low; adds one class and one row.
- **[C] Do nothing** — hint remains misleading for the replace path.

**Recommendation: [A]** — One bullet covers both cases; splitting the
class for message-text variation is over-engineering per
`engineering-preferences.md §3`.

---

#### Section III — `@groups` property

**Issue 18: `@groups` element-level content is unconstrained (NA, empty string, duplicates)**
Severity: SUGGESTION
Violates Lens 4 (Edge Cases).

The §III type declaration `S7::class_character` allows `NA_character_`,
`""`, and duplicated entries in `@groups`. The normal construction path
(`as_survey_collection(group = ...)` via tidyselect) naturally excludes
these, but direct S7 construction

```r
survey_collection(surveys = list(a = d), groups = c("region", NA_character_, "region"))
```

bypasses tidyselect. None of:
- `c("a", NA_character_)` — NA element
- `c("")` — empty-string column name
- `c("region", "region")` — duplicates

is rejected by the validator or any helper. The first two will produce
cryptic failures in `.resolve_groups()`; the third is semantically
redundant and may produce duplicate columns in downstream output.

Options:
- **[A]** Extend the §III validator (and thus the `.check_groups_match()`
  helper's caller expectations) to reject `@groups` containing any of:
  `NA`, `""`, or duplicates. Add a single error class
  (`surveycore_error_collection_groups_malformed`) with three separate
  `"i"` bullets per failing condition. Effort: low, Risk: low.
- **[B]** Trust that users won't directly construct collections and rely
  on tidyselect upstream to prevent these. — Leaves a gap for anyone
  using `survey_collection()` directly in tests or tooling.
- **[C] Do nothing** — same as [B].

**Recommendation: [A]** — Cheap validator extension; matches
`engineering-preferences.md §4` (handle more edge cases).

---

#### Section V — `add_survey()`

**Issue 19: Atomicity is unspecified when multiple new surveys are added and one errors**
Severity: SUGGESTION
Violates Lens 3 (Contract Completeness).

§V describes the behavior "for each new survey `new`" and then says "After
processing all new surveys, construct the final collection…". If a user
calls `add_survey(coll, a = d1, b = d2_bad, c = d3)` and `d2_bad` triggers
G4, the spec does not state whether:

- (a) the call errors atomically — no member added, `coll` unchanged, or
- (b) partial processing — `d1` inserted before the error, `d3` never
  attempted.

Reading the implementation convention ("construct the final collection
with `groups = coll@groups`" after the loop) implies (a) — the final
construction is the only mutation, so an error in the loop aborts before
any state change is observable. But the spec should say so.

Options:
- **[A]** Add one sentence to §V: "If any new survey errors, no member is
  added; `coll` is unchanged." Effort: trivial.
- **[B] Do nothing** — behavior follows naturally from the implementation
  pattern but isn't explicit.

**Recommendation: [A]** — Trivial clarification; prevents anyone
reordering the loop in a future refactor from silently changing
observable behavior.

---

#### Section X — Testing

**Issue 20: "Dual `class=` + snapshot where applicable" leaves the snapshot subset unspecified**
Severity: SUGGESTION
Violates Lens 2 (Test Completeness — mechanic rules).

§X header reads: "Constructor — happy paths (Layer 3 — dual `class=` +
snapshot where applicable)". The per-block listings for G2, G3, G4, G5,
G6, G7, G7b, and G8 do not individually state whether a snapshot is
required. `testing-surveycore.md` is explicit that Layer 3 constructor
errors are dual-tested; G1 is marked Layer 1 (class-only).

Per the rule, G2, G3, G4, G5, G6, G7, G7b all originate in
user-facing functions (constructor, `add_survey`, `[[<-`) and should
therefore be dual-tested. G8 is a warning — `testing-surveycore.md` is
silent on warning snapshots, but the shipped surveycore convention is to
snapshot warnings that a user would see (to lock down text). The spec
should state this to avoid the implementer deciding ad hoc.

Options:
- **[A]** Add a single sentence to §X: "Every error in §VIII except G1
  gets both `expect_error(class = ...)` and `expect_snapshot(error =
  TRUE)`. G8 gets `expect_warning(class = ...)` and
  `expect_snapshot()`. G1 gets `expect_error(class = ...)` only." Effort:
  trivial.
- **[B] Do nothing** — the testing rule file is authoritative; implementer
  applies it.

**Recommendation: [A]** — Enumerating in the spec avoids ambiguity at
review time and matches the existing convention elsewhere in the
surveycore specs to spell out which layer each error class lives at.

---

#### Section VI — `[[<-`

**Issue 21: Order-sensitive equality check is implied but not restated for `[[<-`**
Severity: SUGGESTION
Violates Lens 3 (Contract Completeness).

§III states explicitly that `identical()` (and thus order) is part of the
invariant for the S7 validator. §VI.2 restates "`identical(value@groups,
x@groups)` must hold" for `[[<-`. Both uses are consistent, but the order
sensitivity implication for `[[<-` is not drawn out — the user-level
consequence is that

```r
coll@groups == c("region", "stratum")
value@groups <- c("stratum", "region")
coll[["wave1"]] <- value        # errors G5
```

errors even though the two groupings are "the same set of variables." §X
tests order sensitivity at the validator layer but not at `[[<-`. Adding
one test block would cost nothing and closes the last spec/test gap.

Options:
- **[A]** Add one `[[<-` test block: "Replace with same-set-different-order
  `@groups` errors G5." Also add one sentence in §VI.2 noting the order
  sensitivity. Effort: trivial.
- **[B] Do nothing** — implied from §III; no behavior gap.

**Recommendation: [A]** — A 3-line test fills the only remaining gap in
the test matrix.

---

### Cross-section notes

Nothing else new. Helpers (§II), print format (§III), constructor
dispatch (§IV), `remove_survey()` (§VII), the error table (§VIII), the
surveytidy integration contract (§IX), and the quality gates (§XI) are
internally consistent after Pass 1 resolution.

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 1 |
| SUGGESTION | 5 |

**Total issues:** 6

**Overall assessment:** v0.2 cleanly resolves every Pass 1 issue and the
spec is nearly implementable. The one remaining REQUIRED item (Issue 16
— column existence in propagation paths) is a genuine gap introduced by
the new propagation semantics: the S7 validator enforces *equality* of
`@groups` across members but not *resolvability* of those column names
against each member's `@data`. Closing it with a validator extension is
cheap and buys coverage for every path at once. The five suggestions are
text clarifications (G5 hint, atomicity, test-layer enumeration, order
sensitivity for `[[<-`) and one validator tightening (malformed
`@groups`); none blocks implementation, but all are worth resolving in
Stage 4 before `/implementation-workflow`.
