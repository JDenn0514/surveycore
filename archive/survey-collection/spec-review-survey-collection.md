# Spec Review: survey-collection — Pass 1 (2026-04-20)

Applied all six Stage 3 lenses to `plans/spec-survey-collection.md` v0.1.
Stage 2 (methodology) was correctly determined N/A — this spec defines a
container + structural dispatch layer only. The risk surface is therefore
entirely API shape, error taxonomy, attribute carry-over, and test coverage.

---

## New Issues

### Section: IV. Dispatch Over Collections — §4.1 `.dispatch_over_collection()`

**Issue 1: `surveycore_error_variable_not_found` does not exist — `.on_missing` mechanism is broken as written**
Severity: BLOCKING
Violates `engineering-preferences.md §5 (Explicit over clever)` and the contract-completeness lens.

The dispatch helper's `tryCatch` handler is classed on
`surveycore_error_variable_not_found`:

```r
surveycore_error_variable_not_found = function(cnd) { ... }
```

No such class exists in `plans/error-messages.md`. I verified experimentally:
a `get_*()` call with a nonexistent variable raises a tidyselect error:

```
class: vctrs_error_subscript_oob vctrs_error_subscript rlang_error error condition
msg: Can't select columns that don't exist.
```

`tryCatch` matches class names; this handler will never fire. The result:
`.on_missing = "skip"` is a no-op (users still see the raw vctrs error) and
`.on_missing = "error"` never produces the spec's wrapped
`surveycore_error_collection_missing_var` message. Only rows C5 and C6 in the
spec's new error table depend on this handler, so both are effectively dead.
Separately, `get_freqs()` emits `surveycore_error_all_na` (row 53) for
all-NA focal vars — another "this survey lacks valid data" condition that the
current handler does not catch at all.

Options:
- **A** Catch `vctrs_error_subscript_oob` (the actual class tidyselect raises) in
  the `tryCatch` handler. — Effort: low, Risk: low-medium (couples surveycore
  to a vctrs error class — but that class is stable and part of vctrs' public
  contract), Impact: the spec's `.on_missing` behavior works as described.
- **B** Add a new surveycore-owned error class `surveycore_error_variable_not_found`
  and refactor every `get_*()` tidy-select resolution to pre-check names and
  raise this class on miss, wrapping the underlying vctrs error. — Effort:
  medium (touches every `get_*()`), Risk: low, Impact: clean contract; gives
  other collection-like consumers the same hook. Maintenance: one extra layer
  in each `get_*()` — small.
- **C** Do both: catch `vctrs_error_subscript_oob` AND relevant surveycore
  classes (e.g., `surveycore_error_var_not_found` in setters,
  `surveycore_error_all_na` if we want "survey has no usable data for this var"
  to also qualify as "missing"). — Effort: medium, Risk: low-medium, Impact:
  broader `.on_missing` semantics.

**Recommendation: B.** The `.on_missing` contract is user-facing. Users will
write `.on_missing = "skip"` and expect it to work deterministically, not
depend on vctrs' internal error classes. A surveycore-owned class is the
explicit, stable hook. Update the §IV.1 code and the §VI error table to match,
and add rows to `plans/error-messages.md` for the new classes on each
`get_*()` function (or a single shared class used across all `get_*()`).

---

**Issue 2: `.id`-column collision check runs after the overwrite — the check is dead code**
Severity: BLOCKING
Violates contract-completeness and `engineering-preferences.md §5`.

Spec §4.1 code:

```r
for (nm in nms) {
  r <- tryCatch(...)
  if (!is.null(r)) {
    r[[.id]] <- nm         # <-- assignment happens here
    results[[nm]] <- r
  }
}
...
# .id collision check — happens AFTER the assignment
first_cols <- names(results[[1]])
if (.id %in% setdiff(first_cols, .id)) {
  cli::cli_abort(..., class = "surveycore_error_collection_id_collision")
}
```

By the time the check runs, `results[[1]]` already has the column named `.id`
assigned by `r[[.id]] <- nm`. Any analysis-function column that previously had
the same name has been silently overwritten. `setdiff(first_cols, .id)` strips
`.id` back out, so the `if` condition is structurally `if (FALSE)`. The
collision error class `surveycore_error_collection_id_collision` (row C7) can
never fire.

Concrete scenario: user calls `get_means(coll, ..., .id = "estimate")`. The
`estimate` column from each survey is overwritten by the survey name. The
result has wrong numbers and no error or warning. This is a correctness bug
in the dispatch contract, not just a test-plan gap.

Options:
- **A** Move the collision check before the first per-survey assignment:
  run `fn(collection@surveys[[nms[1]]], ...)` once (or inspect result colnames
  on the first iteration, before the `r[[.id]] <- nm` line), and abort if
  `.id %in% names(first_result)`. — Effort: low, Risk: low, Impact: the
  documented error actually fires.
- **B** Use `tibble::add_column(r, !!.id := nm, .before = 1)` and let
  `add_column()` refuse to create a duplicate. — Effort: low, Risk: low
  (shifts the "where collision is caught" to tibble's error, which would
  need wrapping to raise the spec's class).
- **C** Do nothing — accept silent overwrite. — Leaves a correctness bug in
  the documented contract.

**Recommendation: A.** Check before assignment; spec §4.1 code needs to move
the check above the loop (or into the first iteration) and the §V Edge Case 8
/ §VI C7 rows can stand as-written once the check is real.

---

**Issue 3: `.meta` carry-over from first survey only — silent data loss for value labels, question prefaces, etc.**
Severity: REQUIRED
Violates Lens 6 (API coherence / user expectations) and
`engineering-preferences.md §4` (handle edge cases, not fewer).

Spec §4.1:
> `.meta` carry-over: the collection result inherits the first survey's `.meta`
> nested shape.

Per `project_analysis_meta_structure.md` memory and the actual implementation
in `R/analysis-helpers.R:545`, `.meta` carries per-variable `value_labels`,
`variable_label`, `question_preface`, `value_labels` at nested `group.*` / `x.*`
keys. If the 2017-18 survey uses `"M"` / `"F"` codes and the 2019-20 survey
uses `1` / `2` with value labels `"Male"` / `"Female"`, only the first's
labels land on the collection result. Downstream consumers reading `.meta`
(e.g., `gt()` helpers, `clean()`) will mislabel or drop rows for surveys 2+.

The spec is silent on this beyond one sentence. There is no test plan entry
for it, no error/warning when per-survey `.meta` disagrees, and no documented
retrieval path for per-survey metadata on the collection result.

Options:
- **A** Store per-survey `.meta` as `attr(out, ".meta")$per_survey` — a named
  list keyed by `.id` — alongside the first-survey carry-over for backward-
  compat. Add a helper `meta(result, survey = "2017-18")`. — Effort: medium,
  Risk: low, Impact: no silent loss; downstream consumers can introspect.
- **B** Warn when value_labels / question_preface disagree across surveys for
  the same variable. Keep the first-only carry-over. — Effort: low, Risk: low
  (noisy on legitimately heterogeneous collections), Impact: users are at
  least informed.
- **C** Require homogeneous `.meta` across surveys for a given variable; error
  if they diverge. — Effort: low, Risk: high (too strict; defeats the purpose
  of the container for real-world longitudinal survey data where labels often
  evolve between waves).
- **D** Do nothing, document the limitation, defer a richer solution. —
  Effort: none, Risk: medium (surprising for downstream consumers).

**Recommendation: A + B.** Store per-survey meta under
`.meta$per_survey[[name]]` so no information is lost, and warn when the
first-survey carry-over disagrees with other surveys (users who don't
introspect at least see the warning). The per-survey list also gives clean/gt
a principled escape hatch for "use the right labels per row".

---

### Section: IV.2 — Per-Function Dispatch Branch

**Issue 4: Spec's illustrative code uses `x` as the first-argument name, but actual `get_*()` functions use `design`**
Severity: REQUIRED
Violates contract-completeness.

Spec §4.2:
```r
get_freqs <- function(x, ..., .id = ".survey", .on_missing = "error") {
  if (S7::S7_inherits(x, survey_collection)) {
```

Actual signature (`R/analysis-freqs.R:8`):
```r
get_freqs(design, x, ..., group, names_to, values_to, variance, ...)
```

`design` is the design-or-collection argument; `x` is the focal variable.
The spec's branch as written would silently rename the first argument and
break every existing caller. Reading charitably, "x" in the branch is meant
as a placeholder for "the object" — but a literal implementer would copy-paste
it. Also affects §IV.1 where `.dispatch_over_collection(fn, collection, ...)`
receives a "collection" argument and then calls `fn(collection@surveys[[nm]], ...)`
with the survey object as first arg — this must line up with each function's
first-arg name.

Options:
- **A** Rewrite §4.2 example using `design` as the first-arg name to match the
  implementation. Clarify that the dispatch branch goes at the top of each
  function body using whatever name that function already uses for the design
  argument. — Effort: low.
- **B** Rename all `get_*()` first args to `x` for consistency before adding
  dispatch. — Effort: medium-high (breaking change to the entire analysis
  API; would require a full deprecation pass).
- **C** Leave the spec example as a pseudocode sketch with a note saying
  "substitute the design arg name as appropriate". — Effort: none, Risk: low,
  but weakens the spec.

**Recommendation: A.** Fix the example to match reality; no reason to
introduce a rename.

---

**Issue 5: `get_diffs()` inclusion flagged "verify at impl time"**
Severity: REQUIRED
Violates `engineering-preferences.md §5`; spec must not defer decisions
the implementer needs.

Spec §4.2:
> `get_diffs()` (if it takes a single design — verify at impl time)

`get_diffs()` takes a single design (error-messages.md rows 92-100). The
"verify at impl time" wording forces the implementer to re-derive this.
Decide in the spec: in or out.

Options:
- **A** Include `get_diffs()` in the dispatch set — test plan §7.1.4 adds a
  row for it. — Effort: low.
- **B** Defer `get_diffs()` explicitly in §I "What This Does NOT Deliver",
  with a one-sentence reason (e.g., internally calls `survey_glm()` which is
  deferred). — Effort: low.

**Recommendation: A**, unless §I's `survey_glm()` deferral is load-bearing
for `get_diffs()` internals — in which case **B** and state the reason.

---

**Issue 6: Unspecified behavior for `.id` / `.on_missing` when the input is a single `survey_base`**
Severity: SUGGESTION
Lens 6 (API coherence).

Spec §4.3:
> When the function is called on a single `survey_base`, both are unused (no-ops).

"Unused" is ambiguous — the function still has the arguments in its signature.
Options to pin down:

- If a user passes `.id = "wave"` to `get_freqs(single_design, ..., .id = "wave")`,
  is that silently ignored? A warning? An error?
- Should `.id` optionally add a constant-valued column even for a single design
  (so the result shape matches whether or not someone later wraps the call in
  a collection)?

Options:
- **A** Silently ignore `.id` / `.on_missing` for single-design calls (current
  spec behavior, just make it explicit). — Effort: trivial.
- **B** Emit a `surveycore_message_id_ignored_for_single_design` message when
  a non-default value is passed to a single-design call. — Effort: low.
- **C** Apply `.id` as a literal constant column even for single designs so
  result shapes compose cleanly. — Effort: low-medium; changes the non-
  collection return shape, which is a breaking change for existing callers.

**Recommendation: A**, documented explicitly in each `@param .id` block as
"Only used when `x` is a `survey_collection`; ignored otherwise."

---

### Section: III — `survey_collection` S7 Class

**Issue 7: Validator does not enumerate the `add_survey()` duplicate path as Layer 1**
Severity: SUGGESTION

§3.7 says `add_survey()` "Errors `surveycore_error_collection_duplicate_name`
if any new name collides with an existing one." §VI row C2 lists this class
as thrown by both the S7 validator AND `add_survey()`. This is fine, but the
spec should say whether `add_survey()` does an early pre-check (cleaner
error path, preserves caller context) or relies on the validator to catch
it (simpler but less informative). Testing-surveycore.md §Layer-1 says
validator errors use `class=` only, no snapshot; if `add_survey()` raises
the same class with a prettier message, that message should get its own row
and a snapshot test.

Options:
- **A** `add_survey()` pre-checks names and raises the error directly with a
  fuller CLI message (dual-pattern Layer 3 test). Validator still catches it
  as backstop (Layer 1 test with `class=` only). — Effort: low.
- **B** Single validator catch, no pre-check. One test. — Effort: trivial,
  less informative error when called via `add_survey()`.

**Recommendation: A** — `add_survey()` knows the user context (they just tried
to append), so it can give a better error than the validator's generic
"duplicates: ...".

---

**Issue 8: Validator missing explicit success return**
Severity: SUGGESTION

§3.1 validator's final branch (all checks passed) falls off the end returning
`NULL` implicitly. S7 validators accept `NULL` for success, so this works, but
other validators in `R/core-classes.R` end with an explicit `NULL` for clarity.
Match the convention.

Options:
- **A** Add explicit `NULL` at end. — Effort: trivial.
- **B** Keep as-is. — Effort: none.

**Recommendation: A.**

---

**Issue 9: `survey_collection` inheriting from `survey_base` not explicitly stated as FALSE**
Severity: SUGGESTION

§3.1 shows the class definition without `parent = ...`. Invariant 4 (§3.2)
relies on the fact that `survey_collection` does not inherit `survey_base`,
but the spec never states this explicitly. Adding a sentence ("Note:
`survey_collection` deliberately does not inherit from `survey_base` — this
is what makes the nested-collection case fall out of invariant 3
automatically.") prevents a well-meaning future refactor from breaking
invariant 4.

Options:
- **A** Add one-sentence note. — Effort: trivial.

**Recommendation: A.**

---

**Issue 10: Print method formatting details unspecified**
Severity: SUGGESTION

§3.5 shows `"2017-18": survey_taylor, 9,254 rows, 48 variables` — thousands
separator, count of underlying class. The spec does not say whether to use
`format(..., big.mark = ",")`, whether to abbreviate long survey names, or
the exact string for `S7::class_name()` output. Open question in §IX asks
about abbreviation for >20 surveys — lock this here rather than deferring.

Options:
- **A** Specify `format(nrow, big.mark = ",")`, full class name via
  `S7::class_name(s)[1]`, no truncation for <= 20 surveys; for >20 show first
  10, last 3, and `... and N more`. — Effort: low.
- **B** Defer exact format to implementation + snapshot. — Effort: trivial,
  but the snapshot then *becomes* the spec.

**Recommendation: A.** Lock it now; the snapshot test in
`test-methods-print.R` then enforces it.

---

### Section: VI — Error Message Table

**Issue 11: C2 row ambiguity — single class, two very different call sites**
Severity: SUGGESTION

Row C2 lists `surveycore_error_collection_duplicate_name` as fired by both
the S7 validator and `add_survey()`. Per testing-surveycore.md these are
different layers with different test patterns (Layer 1: `class=` only;
Layer 3: dual pattern). Either:

- Split into C2a (validator, Layer 1) and C2b (`add_survey()`, Layer 3), or
- Keep one row and add a note that the message template differs between the
  two call sites (validator uses terse text per §3.1; `add_survey()` uses a
  full CLI bullet structure).

**Recommendation:** Split into C2a / C2b with distinct message templates.
Links to Issue 7 above.

---

**Issue 12: Error class for `survey_glm()` / `get_anova()` on a `survey_collection` unspecified**
Severity: REQUIRED

§I defers `survey_glm()` and `get_anova()` on collections, but the spec
does not say what happens when a user calls one. The current implementation
uses `.check_unsupported_class()` which raises `surveycore_error_unsupported_class`
(row 64) with a generic message.

Options:
- **A** Add an explicit early check in both `survey_glm()` and `get_anova()`
  for `S7_inherits(x, survey_collection)` → raise a dedicated
  `surveycore_error_collection_not_supported_by_fn` with a message pointing
  users to the deferral. — Effort: low, Risk: low.
- **B** Rely on `surveycore_error_unsupported_class`. — Effort: none; users
  get a generic "survey design object" error that doesn't hint at the
  deferral.

**Recommendation: A.** Specific, actionable error > generic one.

---

### Section: VII — Test Plan

**Issue 13: No numerical-oracle test for dispatch identity**
Severity: REQUIRED
Violates test-completeness Lens (category 2, "Numerical oracle") adapted to
the dispatch context.

The spec's correctness guarantee is "running `get_*(coll, ...)` produces
row-bound output identical to separately running `get_*()` on each
constituent survey." No test in §7.1 verifies this. A straightforward
guard test:

```r
test_that("get_means() dispatch equals manual per-survey + bind_rows()", {
  s1 <- make_survey_data(seed = 1) |> as_survey(weights = wt)
  s2 <- make_survey_data(seed = 2) |> as_survey(weights = wt)
  coll <- as_survey_collection(s1 = s1, s2 = s2)

  direct <- get_means(coll, y1)
  manual <- dplyr::bind_rows(
    s1 = get_means(s1, y1),
    s2 = get_means(s2, y1),
    .id = ".survey"
  )
  expect_equal(direct$mean, manual$mean, tolerance = 1e-12)
  expect_equal(direct$se,   manual$se,   tolerance = 1e-12)
})
```

**Recommendation:** Add this test category for at least `get_means()`,
`get_totals()`, `get_freqs()` — one oracle per function family where
numerics are the point.

---

**Issue 14: Missing edge-case test — single-survey collection**
Severity: SUGGESTION

§7.1 covers 3-survey collections heavily. The degenerate case — collection
of length 1 — is a natural edge case:

- Does `.dispatch_over_collection()` still wrap single-survey output
  correctly?
- Does `.id` column get added?
- Does `length(results) == 0` path work if the single survey is skipped?

Add: `test_that("dispatch works on a collection of length 1", { ... })`.

**Recommendation:** Add.

---

**Issue 15: No test for `.meta` per-survey divergence / carry-over**
Severity: REQUIRED
Paired with Issue 3.

§7.1.4 says `.meta$collection$surveys` populated, but nothing tests what
happens when surveys have disagreeing value labels or question prefaces.
Whichever resolution Issue 3 takes, the test plan needs a block for it.

**Recommendation:** Add an explicit "heterogeneous `.meta`" test section.

---

**Issue 16: No test for `.id` column collision detection after fix**
Severity: REQUIRED

§7.1.5 mentions `.id` collision but as written (see Issue 2), the collision
check is dead. Once Issue 2 is fixed, §7.1.5 needs a concrete test:

```r
test_that("get_means() errors when .id collides with 'mean' column", {
  expect_error(
    get_means(coll, y1, .id = "mean"),
    class = "surveycore_error_collection_id_collision"
  )
  expect_snapshot(error = TRUE, get_means(coll, y1, .id = "mean"))
})
```

**Recommendation:** Add; dual pattern per testing-standards.md.

---

**Issue 17: `test_invariants()` not called in constructor tests for `survey_collection`**
Severity: SUGGESTION

testing-surveycore.md §`test_invariants()` says every test block that creates
a survey object via `as_survey()` / `as_survey_rep()` / `as_survey_twophase()`
must call it first. `survey_collection` is a new survey-adjacent object
type — should it have its own `test_collection_invariants()` that checks
the five invariants in §3.2? Not strictly required by the rule as written,
but consistent with the existing pattern.

Options:
- **A** Define `test_collection_invariants(coll)` in `helper-test-data.R`
  and call it first in every §7.1 block that builds a collection. — Effort:
  low.
- **B** Skip; rely on §7.1.2 validator tests to exercise the invariants. —
  Effort: none.

**Recommendation: A.** Small addition, catches regression the moment a
future constructor accidentally produces a malformed collection.

---

### Section: V — Edge Cases

**Issue 18: Edge case 9 (heterogeneous value labels) — behavior specified as "no warning" is a silent-wrong risk**
Severity: REQUIRED
Lens 6 (API coherence), paired with Issue 3.

> # 9 | Heterogeneous value labels for the same variable across surveys |
> `bind_rows()` union, missing rows get `NA`. No warning — this is the
> caller's responsibility to interpret.

In practice, `get_freqs(coll, gender)` where survey 1 labels `1 = "Male"` and
survey 2 labels `1 = "Man"` produces a result with the same value code across
rows and no indication that the semantic meaning differs. "Caller's
responsibility to interpret" only works if the caller knows the divergence
happened. Today they do not.

Options:
- **A** Warn when value_labels diverge across surveys for the focal variable.
  — Effort: low-medium (requires per-survey meta introspection; ties to
  Issue 3 Option A).
- **B** Keep silent, but document in §VIII.2 the recommended pre-call check
  (`extract_val_labels()` per survey, compare). — Effort: trivial, weakest.
- **C** Error instead of warn. — Effort: low, Risk: high (too strict).

**Recommendation: A.**

---

### Section: IX — Implementation Order (Open Questions)

**Issue 19: Three "open questions remaining for spec review" must be closed before Stage 4 handoff**
Severity: REQUIRED

§IX lists:
1. Should `add_survey()` accept a `survey_collection` for concatenation?
2. Should `.meta$collection` record the class of each underlying survey?
3. Should `print()` abbreviate when `length(x) > 20`?

Stage 4 resolves issues to decisions — these three are exactly that. Answer
each in the spec before calling Stage 4. (Defaults suggested in §IX:
respectively no / yes / yes; I agree with all three. Lock them.)

**Recommendation:** Decide in-line, remove the "open questions" block.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 2 |
| REQUIRED | 9 |
| SUGGESTION | 8 |

**Total issues:** 19

**Overall assessment:** The spec's high-level shape is sound — a thin S7
container + one dispatch helper + one three-line branch per `get_*()` —
but two implementation-level bugs in the §IV.1 reference code (the wrong
error class in the `tryCatch`, and the collision check running after the
overwrite) make the `.on_missing` and `.id`-collision contracts
non-functional as written. Both are small code fixes but must be resolved
in the spec before implementation begins so the error-class additions in
§VI and the test blocks in §VII are correctly scoped. Beyond that, the
`.meta` carry-over policy is under-specified (Issue 3) and deserves an
explicit per-survey preservation layer — without it, heterogeneous
longitudinal collections silently lose labeling information. The rest of
the issues are contract tightening, test-plan completeness, and locking
the three "open questions" the spec itself flags.

---

## Spec Review: survey-collection — Pass 2 (2026-04-20)

Re-reviewed `plans/spec-survey-collection.md` v1.0 ("approved") against all
six Stage 3 lenses. Stage 2 remains N/A (container + dispatch only, no
estimators). The spec has absorbed the Pass 1 feedback essentially wholesale;
the bugs in §4.1 are fixed, the `.meta` policy is now explicit, and the three
§IX open questions are closed. A handful of smaller contract and consistency
issues remain, plus one correctness issue in §3.6.

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | `surveycore_error_variable_not_found` does not exist | ✅ Resolved (added as C10; §III.4 requires per-function pre-check wrapping `vctrs_error_subscript_oob` as `parent`) |
| 2 | `.id` collision check runs after the overwrite | ✅ Resolved (§4.1 now collects raw results first, runs collision check, then assigns `.id`) |
| 3 | `.meta` carry-over from first survey only | ✅ Resolved (per_survey preservation + `.warn_on_meta_divergence()` in §4.1/§4.1.1) |
| 4 | §4.2 uses `x` but actual `get_*()` use `design` | ✅ Resolved (§4.2 example now uses `design`) |
| 5 | `get_diffs()` "verify at impl time" | ✅ Resolved (listed in §4.2) |
| 6 | Unspecified `.id`/`.on_missing` on single survey | ✅ Resolved (§4.3 "silently ignored"; test in §7.1.4) |
| 7 | `add_survey()` duplicate path not enumerated | ✅ Resolved (duplicate-repair algorithm in §3.3.1; validator is backstop) |
| 8 | Validator missing explicit success return | ✅ Resolved (explicit `NULL` in §3.1) |
| 9 | `survey_collection` non-inheritance from `survey_base` not stated | ✅ Resolved (explicit note in §3.1) |
| 10 | Print method formatting details unspecified | ✅ Resolved (§3.5 locks all formatting) |
| 11 | C2 ambiguity across validator / constructor | ✅ Resolved (C2 = validator backstop; C2a = constructor warning) |
| 12 | Error class for `survey_glm()` / `get_anova()` on collection | ✅ Resolved (C12 added, dedicated class) |
| 13 | No numerical-oracle test for dispatch identity | ✅ Resolved (§7.1.4 "Dispatch-identity oracle tests" for means/totals/freqs) |
| 14 | Missing length-1 collection test | ✅ Resolved (§7.1.6a) |
| 15 | No test for `.meta` divergence | ✅ Resolved (§7.1.7a) |
| 16 | No test for `.id` collision | ✅ Resolved (§7.1.5 dual-pattern test on `.id = "mean"`) |
| 17 | `test_invariants()` for `survey_collection` | ✅ Resolved (`test_collection_invariants()` in §7.2.1) |
| 18 | Edge case 9 "no warning" is silent-wrong | ✅ Resolved (now emits `surveycore_warning_collection_meta_divergence`) |
| 19 | Three §IX open questions | ✅ Resolved (all three locked as decisions) |

All 19 Pass 1 issues are resolved. The two BLOCKING bugs in the §4.1 reference
code are now correct as written.

### New Issues

#### Section: III — `survey_collection` S7 Class

**Issue 20: `[[` method spec is wrong about integer-out-of-bounds behavior**
Severity: REQUIRED
Violates contract-completeness (Lens 3).

§3.6:
> `[[` accepts character or integer `i`. Out-of-bounds integer indexing returns
> `NULL` (base R list semantics); unknown character names return `NULL` (same).

Base R list semantics actually differ by subscript type:

```r
> list(a=1,b=2)[[3]]
Error in list(a = 1, b = 2)[[3]] : subscript out of bounds
> list(a=1,b=2)[["c"]]
NULL
```

Integer out-of-bounds **errors** — it does not return `NULL`. Character
out-of-bounds returns `NULL`. The spec conflates the two. With the shown
method body `function(x, i) x@surveys[[i]]`, integer out-of-bounds will
propagate the base R error, so the runtime behavior is fine — but the spec
sentence is false, and an implementer following the spec literally might
wrap the method to force `NULL` on integer OOB (which would be a regression
vs. list semantics).

Options:
- **A** Correct the sentence: "Out-of-bounds integer indexing errors per base
  R list semantics; unknown character names return `NULL`." Add a test in §7.1.1
  covering both: `expect_null(coll[["nonexistent"]])` and
  `expect_error(coll[[99L]])`. — Effort: trivial.
- **B** Override to always return `NULL` (uniform behavior). — Effort: low,
  Risk: diverges from base list semantics; surprising.
- **C** Keep the spec wrong. — Effort: none; misleads implementer/reader.

**Recommendation: A.** Match base list semantics exactly; this is what the
method body already does.

---

#### Section: IV — Dispatch Over Collections

**Issue 21: §4.2 dispatch branch omits per-function NSE arguments beyond `x`**
Severity: REQUIRED
Violates contract-completeness (Lens 3) and API coherence (Lens 6).

§4.2 example:

```r
get_freqs <- function(design, x, ..., .id = ".survey", .on_missing = "error") {
  if (S7::S7_inherits(design, survey_collection)) {
    return(.dispatch_over_collection(
      get_freqs, design, x = {{ x }}, ...,
      .id = .id, .on_missing = .on_missing
    ))
  }
  ...
}
```

Every real `get_*()` in the dispatch set has additional NSE arguments beyond
`x`:

| Function | NSE args needing `{{ }}` forwarding |
|---|---|
| `get_freqs(design, x, ..., group, ...)` | `x`, `group` |
| `get_means(design, x, group = NULL, ...)` | `x`, `group` |
| `get_totals(design, x = NULL, group = NULL, ...)` | `x`, `group` |
| `get_quantiles(design, x, probs, group, ...)` | `x`, `group` |
| `get_ratios(design, numerator, denominator, group, ...)` | `numerator`, `denominator`, `group` |
| `get_corr(design, x, group, ...)` | `x`, `group` |
| `get_diffs(design, x, treats, group, covariates, ...)` | `x`, `treats`, `group`, `covariates` |
| `get_t_test(design, x, by, group, ...)` | `x`, `by`, `group` |
| `get_pairwise(design, x, by, group, ...)` | `x`, `by`, `group` |

A positional call like `get_means(coll, age, sex)` binds `group = sex` inside
`get_means`. The dispatch branch's `x = {{ x }}, ...` captures `x` and any
`...` args — but `group` is NOT in `...` (it's a named formal parameter),
so `group` is silently dropped. Every per-survey call then runs with
`group = NULL`, producing wrong results with no error. Same issue for every
function row above.

§4.4's "New `get_*()` functions opt in with three lines" assumes a
one-size-fits-all snippet, but each function needs its own NSE-forwarding
list. The spec must either:

1. Show the template expanded with all NSE args for at least one function
   beyond `get_freqs()` (e.g., `get_means`), and state that every `get_*()`
   must forward **every** NSE arg it declares; OR
2. Require each `get_*()`'s NSE args to be declared via `...` only and
   captured with `rlang::enquos(...)` — but this is a breaking API change.

Options:
- **A** Revise §4.2 to: (a) expand the `get_freqs()` template to include
  `group = {{ group }}`; (b) add a second example for `get_ratios()` showing
  `numerator = {{ numerator }}, denominator = {{ denominator }}, group = {{ group }}`;
  (c) add a paragraph stating "Every named NSE argument the function declares
  must be forwarded via `{{ arg }}` in the dispatch call — it is not enough
  to rely on `...`"; (d) adjust §4.4 "three lines" to "three lines plus one
  `{{ }}` forwarding per NSE arg." — Effort: low (spec text only).
- **B** Move all NSE args of every `get_*()` into `...` in a pre-req refactor,
  then the dispatch branch truly is a uniform 3-line snippet. — Effort: high;
  breaking change; out of spec scope.
- **C** Add a per-function appendix showing the complete branch for each of
  the 9 functions. — Effort: medium, Risk: low, Impact: zero ambiguity for
  the implementer.

**Recommendation: A** with tests in §7.1.4 that specifically call each
function with its NSE args set (e.g., `get_means(coll, y1, group = grp)`) so a
dropped-`group` regression would fail the "same result as bind_rows of
per-survey calls" oracle test. The oracle tests in §7.1.4 are the strongest
safety net here — if the template is wrong, the oracle comparison will fail.

---

**Issue 22: `.id` / `.on_missing` argument position contradicts code-style.md §4**
Severity: REQUIRED
Violates `code-style.md §4` argument-order rule.

`code-style.md §4` (quoted in Pass 1 context):
> Optional scalar control arguments (`nest = FALSE`, `mse = TRUE`,
> `validate = TRUE`) ... `...` [last]

And spec §4.3 itself says:
> Argument order per `code-style.md §4`: they are format/control scalars and
> go at the end, just before `...` if present, otherwise last.

But the example in §4.2 puts them **after** `...`:

```r
get_freqs <- function(design, x, ..., .id = ".survey", .on_missing = "error") {
```

This is internally contradictory. There are two defensible resolutions, but
the spec needs to pick one:

- **Pre-`...`** (as §4.3 says): `get_freqs(design, x, .id = ".survey", .on_missing = "error", ...)`.
  Matches `code-style.md` but breaks any existing caller passing positional
  args after `x`.
- **Post-`...`** (as §4.2 shows): `get_freqs(design, x, ..., .id = ".survey", .on_missing = "error")`.
  Forces `.id` / `.on_missing` to be named-only (the tidyverse convention for
  "must-name" args) and preserves positional compatibility. But conflicts with
  `code-style.md §4`'s stated rule and with §4.3's own text.

Real `get_*()` signatures in the package already place some named arguments
after `...` (e.g., `get_freqs(design, x, ..., group, names_to, ...)`), which
suggests the project has already accepted the post-`...` convention for
named-only controls — if so, `code-style.md §4` should be updated, or its
rule should explicitly carve out the "must-name" exception.

Options:
- **A** Place `.id` / `.on_missing` after `...` (matches §4.2 example and
  matches the existing package pattern). Fix §4.3's wording to
  "just after `...` if present, otherwise last — this is the tidyverse
  named-only convention." Also update `code-style.md §4` to reflect the
  carve-out. — Effort: low (spec + rule text).
- **B** Place them before `...` (strict read of `code-style.md §4`). Fix the
  §4.2 example. But this is inconsistent with `get_freqs`'s existing real
  signature (`..., group, names_to, ...`). — Effort: low text, but creates a
  per-function inconsistency in the dispatch set.
- **C** Leave the contradiction. — Guarantees the implementer will have to
  guess.

**Recommendation: A.** The post-`...` convention is already live in the
package and is the tidyverse idiom for forcing named calls; align the spec
text and the style rule to reality.

---

**Issue 23: "Requested variable" scope in `.on_missing` / variable_not_found pre-check is ambiguous**
Severity: SUGGESTION
Violates contract-completeness (Lens 3).

§III.4:
> Every `get_*()` function in §4.2 must pre-check the tidy-select resolution
> against `names(design@data)` and raise `surveycore_error_variable_not_found`
> with a wrapped message when a requested variable is absent.

Every `get_*()` accepts multiple variable-referring args: `x` (focal), `group`,
`numerator`/`denominator` (ratios), `by` (t-test/pairwise), `treats`,
`covariates` (diffs). The spec does not say which of these participate in the
pre-check, nor whether all of them do.

Concrete scenarios the spec should answer:

1. `get_means(coll, age, group = region)` where `region` is in survey 1 but
   absent in survey 2. Does `.on_missing = "skip"` skip survey 2?
2. `get_ratios(coll, num, denom)` where survey 2 is missing `denom` only.
   Does this trigger `.on_missing`?
3. `get_diffs(coll, y, treats, covariates = c(age, sex))` where survey 2 is
   missing `sex`. Does this trigger `.on_missing`, or only if the focal `y`
   is missing?

Options:
- **A** Define "requested variable" = any column referenced by any NSE argument
  of the `get_*()` function. Survey skipped if ANY requested var is absent. —
  Effort: low (spec text + test row). Principle: a survey that lacks any input
  the function needs cannot produce a comparable row, so skip it whole.
- **B** Only `x` (the focal variable). — Effort: low; but surprising when
  users pass `group` or `covariates` that surveys disagree on.
- **C** Per-function decision table, listed in §4.2. — Effort: medium; most
  explicit.

**Recommendation: A** with a one-sentence clarification in §III.4 and one
illustrative test in §7.1.5 (`get_means(coll, y1, group = missing_in_s2)` with
`.on_missing = "skip"`).

---

**Issue 24: `.warn_on_meta_divergence()` comparison policy — absence vs. divergence undefined**
Severity: SUGGESTION
Violates contract-completeness (Lens 3); paired with Issue 23.

§4.1.1 lists comparison keys:

> $group$<var>$value_labels, $group$<var>$variable_label,
> $group$<var>$question_preface, $x$<var>$value_labels, ...

And says divergence is compared with `identical()`. Unspecified:

1. If survey A has `$x$age$value_labels` populated and survey B has no
   `$x$age` entry at all (variable unlabelled in B), is that divergence?
   `identical(labels, NULL)` is `FALSE`, so yes — but is that the intended
   behavior? If so, this warning will fire loudly on any heterogeneous
   longitudinal collection where one wave adds labels the other doesn't have.
2. Should the warning distinguish "value_labels diverge" (dangerous, different
   codes mean different things) from "question_preface diverges" (annoying
   but not correctness-critical)?
3. What about `$x$age$variable_note` or other user-added keys? The spec lists
   three fields; the real `.meta` structure may grow.

Options:
- **A** State the policy explicitly: "Absence in one survey and presence in
  another counts as divergence; compare with `identical()`." And enumerate the
  closed set of fields checked. If new fields are added to `.meta`, this
  helper must be updated. — Effort: low; locks behavior.
- **B** Treat absence as non-divergent (only warn when both surveys have the
  key and they differ). — Effort: low; quieter but misses the "labels added
  in wave 2" case.
- **C** Make the comparison field-aware: warn for `value_labels` divergence
  (correctness-critical), info-message for others. — Effort: medium.

**Recommendation: A.** It's the most conservative and matches the "strict
`identical()`" already in the spec; document the field list as the full
checked set.

---

**Issue 25: §IX Step 1 says "add 9 rows to error-messages.md" but §VI lists 13 entries**
Severity: SUGGESTION

§IX:
> 1. Error classes — add all 9 rows to `plans/error-messages.md`.

§VI actually lists 13 rows: C1, C2, C2a, C3, C4, C5, C6, C7, C8, C9, C10, C11, C12.
The "9 rows" count is stale from an earlier draft. Fix the count.

**Recommendation:** Update §IX to "all 13 rows" (or rewrite as "every row in
§VI").

---

**Issue 26: §VII §7.1 outline has a duplicate Section 6 ("6" and "6a")**
Severity: SUGGESTION

§7.1 numbering:
```
5. Dispatch errors ...
6. Dispatch messages ...
6a. Length-1 collection (edge)
7. Heterogeneous schemas
7a. .meta carry-over and divergence
8. add_survey / remove_survey ...
9. Print
```

The "6a" and "7a" sub-sections are substantive (length-1 edge, `.meta`) but
the letter-suffix numbering implies they're footnotes to 6 and 7, which they
aren't. Either renumber as 7, 8, ... (bumping everything) or promote to
top-level numbers. Minor but worth fixing for implementer readability.

**Recommendation:** Renumber to a clean 1–11 list.

---

**Issue 27: `.meta` top-level carry-over from first contributing survey is load-bearing but under-motivated**
Severity: SUGGESTION
Lens 6 (API coherence).

§4.1 policy:
> First-survey `.meta` is copied to the top-level of `attr(out, ".meta")` for
> backward compatibility with existing downstream consumers.

Who are those consumers, exactly? `clean()`, `gt()` helpers, and
`extract_val_labels()` off a result? The spec references "downstream consumers
reading `.meta`" but doesn't enumerate them. If a consumer reads the top-level
`value_labels` for a variable and the first contributing survey happens to
not have labels for it (while surveys 2+ do), the consumer will behave as if
the variable is unlabelled — quieter but wrong.

Given that `$per_survey` already exists, a more defensible policy is:

- If all contributing surveys agree, promote to top-level.
- If they disagree, emit the existing `surveycore_warning_collection_meta_divergence`
  AND leave top-level `.meta` empty (or set sentinel `NULL`) so consumers
  naturally fall back to `$per_survey`.

This is a REQUIRED conversation for Stage 4 if downstream `clean()` / `gt()`
helpers actually consume top-level `.meta`. Otherwise it's a SUGGESTION.

Options:
- **A** Promote to top-level only when all contributing surveys agree for
  each `group$<var>` / `x$<var>` field; otherwise leave that field empty at
  top-level. — Effort: low (refinement to §4.1).
- **B** Keep first-survey carry-over but document explicitly which consumers
  depend on it. — Effort: low; research required first.
- **C** Leave as-is. — Risk: divergent-meta collections silently
  mis-labelled by helpers that only read top-level.

**Recommendation: A**, contingent on reviewing the current consumers (`clean()`,
`gt()` helpers) to confirm they will handle empty top-level fields gracefully.

---

#### Section: VI — Error Message Table

**Issue 28: C7 CLI template interpolates `{.id}` which collides with the argument name in scope**
Severity: SUGGESTION
Minor correctness concern.

Row C7 template:
```
"{.arg .id} value {.val {.id}} conflicts with a column produced by the analysis function."
```

The first `{.arg .id}` is the literal cli inline class `.arg` rendering the
string `.id`. The second `{.val {.id}}` is `.val` applied to the value of the
in-scope R variable `.id` (which is the `.on_missing` function argument — wait,
no, `.id` is the arg for the id column name). In the helper `.id` is the
function parameter holding e.g. `"mean"`, so `{.val {.id}}` interpolates to
`{.val "mean"}` → renders as `"mean"`. That's what we want.

So the template is correct, just visually confusing. Consider renaming the
interpolation to a local variable to make the intent obvious:

```r
id_name <- .id
cli::cli_abort(
  c(
    "x" = "{.arg .id} value {.val {id_name}} conflicts with ..."
  ),
  ...
)
```

**Recommendation:** Cosmetic; non-blocking.

---

#### Section: IX — Implementation Order

**Issue 29: Step 7 bundles "one PR or one commit per `get_*()`" — spec doesn't state preference**
Severity: SUGGESTION

§IX step 7:
> Per-function branches — one PR or one commit per `get_*()` function

Nine branches × three lines each = 27 lines of code. Splitting across nine
PRs is heavy process overhead for a mechanical change that's either correct
or not. A single PR is easier to review (the reviewer sees the template once
and scans for consistency across all nine applications).

Options:
- **A** One PR covering all nine functions, plus the shared helper and tests. —
  Lighter review; all-or-nothing merge.
- **B** Per-function PRs. — Heavier process; slower to ship.
- **C** Split by function family (tibble-returning vs. t-test-family). — No
  obvious natural boundary.

**Recommendation: A**, documented in §IX so Stage 5 implementation doesn't
re-litigate.

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 4 |
| SUGGESTION | 6 |

**Total issues:** 10 (prior 19 all ✅ resolved)

**Overall assessment:** The spec is materially ready for implementation.
All Pass 1 BLOCKING/REQUIRED issues are resolved and the v1.0 revision
substantially tightened the contract. What remains is a small cluster of
contract-consistency issues — Issues 20, 21, 22, 23 together determine
whether an implementer following the spec literally will produce correct
dispatch behavior, particularly around NSE-argument forwarding (21) and
the arg-position contradiction between §4.2 and §4.3 (22). Issue 20 is a
documentation correction about `[[` semantics with a trivial fix. The six
SUGGESTIONs are quality polish — divergence semantics, error-table count,
outline numbering, and PR granularity — none of them blocks Stage 4 from
closing. With Issues 20–23 resolved, this spec should proceed to
`/implementation-workflow`.
