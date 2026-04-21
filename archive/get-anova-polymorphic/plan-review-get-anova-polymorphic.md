# Plan Review: get-anova-polymorphic

## Plan Review: get-anova-polymorphic — Pass 1 (2026-04-21)

### New Issues

#### Section: Out of Scope (line 423) + Files (line 259)

**Issue 1: `anova.survey_glm_fit()` S3 method breaks under the planned signature change**
Severity: BLOCKING
Violates code-style.md §4 (argument order) coupled with internal call-site invariants.

The plan declares `anova.survey_glm_fit()` "out of scope" (line 423) but the method at
`R/glm-anova.R:1040–1076` is a thin delegator that calls:

```r
get_anova(object, model2 = others[[1L]], method = method, test = test, null = null)
```

Under the planned changes, `model2` is removed (Q1 hard break) and the first arg is
renamed `object`. The named argument `model2 = ...` will error; the call must become
`get_anova(object, list(object, others[[1L]]), ...)` or similar. Leaving `anova.survey_glm_fit()`
unchanged will cause every `anova(fit, fit2)` call through the S3 generic to blow up,
and the existing test block `test-glm-anova.R` exercises `anova(fit1, fit2)` through
this path.

Options:
- **[A]** Bring `anova.survey_glm_fit()` into scope: update its delegation to pass a
  `list(object, others[[1L]])` when `length(others) == 1L`, update R/zzz.R registration
  if the formals changed, and add its test block to the regression audit — Effort: low,
  Risk: low, Impact: closes a hard break in a documented entry point.
- **[B]** Forbid the scope expansion and split into two PRs: PR #1 = everything except
  the `model2` removal; PR #2 = `model2` removal + `anova.survey_glm_fit()` delegation
  update.
- **[C] Do nothing** — `anova(fit1, fit2)` breaks silently for all users who rely on
  the S3 generic.

**Recommendation: A** — The delegator is eight lines; bringing it into scope is trivial
and avoids a broken public entry point.

---

#### Section: Backward Compatibility Summary (line 411)

**Issue 2: Claimed error behavior for `get_anova(fit1, fit2)` does not match the described dispatch**
Severity: BLOCKING
Violates engineering-preferences.md §5 (explicit over clever) — the plan asserts a
runtime behavior that the implementation described elsewhere cannot produce.

Line 411: "`get_anova(fit1, fit2)` | **Breaks** — second arg now matches `formula`;
errors with `surveycore_error_anova_object_invalid`."

But:
1. `object = fit1` dispatches to the `survey_glm_fit` branch (Q9 ordering).
2. In that branch, `formula` / `response` / `predictors` are not forwarded to
   `survey_glm()` (Q6, line 162: `check_dots_empty()` runs instead).
3. `formula` is a named parameter, **not part of `...`** — `check_dots_empty()` will
   not see it.
4. Therefore `fit2` (matched as `formula`) is silently ignored, and `get_anova()`
   returns a single-model anova of `fit1`. No error is thrown.

Q1's resolution rationale ("Callers using `get_anova(fit1, fit2)` will get an error
when `fit2` is matched to the new `formula` arg") is not mechanically correct as
written.

Options:
- **[A]** Add an explicit guard in the `survey_glm_fit` branch: if `formula`,
  `response`, or `predictors` is non-NULL, error with
  `surveycore_error_anova_formula_unexpected` (new class). Update Task 1.1 and the
  backward-compat table to reference it. — Effort: low, Risk: low, Impact: restores
  the promised fast-fail behavior and makes positional migration errors loud.
- **[B]** Accept silent ignore and change the backward-compat table to "`get_anova(fit1,
  fit2)` silently ignores `fit2` and returns single-model anova of `fit1`." Flag in
  NEWS with a strong warning. — Effort: trivial, Risk: high (silent behavior change),
  Impact: users lose work without knowing.
- **[C] Do nothing** — ambiguity remains until implementation time.

**Recommendation: A** — A hard break must actually break. The new error class costs
one row in error-messages.md and three lines of code.

---

#### Section: Files (line 253) + Step-by-Step Tasks — Task 1.1 (line 277)

**Issue 3: Task 1.1 scope omits `surveycore_error_anova_object_invalid`**
Severity: REQUIRED
Violates code-style.md §3 (class= required on every cli_abort) — if the row is not
added, the implementation will either skip the class or invent one inconsistent with
error-messages.md.

Line 253: "add rows for every new error/warning class from **Q2, Q4, Q5, Q7**"
Line 277: Task 1.1 says the same ("one row per resolved error class from Q2–Q7").

But `surveycore_error_anova_object_invalid` is referenced in Q1 (line 71), Q4 (line
110), Q9 (line 208), and the backward-compat table (line 411). It is a brand-new
class, and is nowhere currently in `plans/error-messages.md` (scanned: the file
contains A-1 through A-20 for get_anova, none named `*_object_invalid`).

Options:
- **[A]** Amend Task 1.1 to "Q1, Q2, Q4, Q5, Q7, Q9." Enumerate the four/five new
  classes explicitly in a bullet list inside the plan so the r-implement task cannot
  lose them. — Effort: trivial, Impact: prevents drift.
- **[B] Do nothing** — implementation adds the class ad-hoc, error-messages.md falls
  out of sync with source; error-class-auditor agent will flag it on PR.

**Recommendation: A**.

---

#### Section: OPEN QUESTIONS — Q10 vs. survey_collection spec

**Issue 4: `survey_collection` collides with the Q9 "anything else" error**
Severity: REQUIRED
Violates the `survey_collection` spec (line 741 of `plans/spec-survey-collection.md`)
which defines the existing contract `surveycore_error_collection_not_supported_by_fn`
for `get_anova()` + collection.

Plan Q9 (line 208): "dispatch order `survey_glm_fit` → `list` → `survey_base` → error."
A `survey_collection` is an S7 class that **does not** inherit `survey_base`
(verified: spec §III line 159 "deliberately does not inherit"). Under the planned
dispatch, a `survey_collection` lands in the catch-all and throws
`surveycore_error_anova_object_invalid`.

But the survey_collection spec promises
`surveycore_error_collection_not_supported_by_fn` with a distinct message explaining
the deferral.

Options:
- **[A]** Insert an explicit `survey_collection` pre-check at the top of `get_anova()`
  that throws `surveycore_error_collection_not_supported_by_fn` — mirrors the pattern
  used in `survey_glm()` per the collection spec §I. One new branch, no new class. —
  Effort: trivial, Impact: preserves documented cross-spec contract.
- **[B]** Skip the check and update the survey_collection spec deferral row to note
  that until the follow-up PR lands, `get_anova()` returns `*_anova_object_invalid`
  instead. — Effort: trivial, Impact: silent spec drift.
- **[C] Do nothing** — two specs contradict each other.

**Recommendation: A** — one line of dispatch, explicit behavior, matches the existing
pattern in `survey_glm()`.

---

#### Section: Step-by-Step Tasks — Task 2.1 (line 288)

**Issue 5: Length-3 list behavior (chained vs pairwise) is an unresolved sub-question**
Severity: REQUIRED
Violates the plan's own status banner (line 5: "all open questions resolved").

Task 2.1 (line 287–289): "`get_anova(list(fit1, fit2, fit3))` produces a 2-row
comparison tibble (fit1 vs fit2, fit2 vs fit3) — **confirm this is the intended
chained behavior**, or adjust to pairwise all-vs-all. *(Sub-open-question; flag
during review.)*"

This is flagged for Stage 2, so: flagging. Implementation cannot proceed until the
semantics are nailed down. Chained vs pairwise has large implications — pairwise
is O(k²) fits, chained is O(k). The nested-vs-pairwise semantics also affect the
Rao-Scott LRT setup (each pair requires its own reference distribution).

Options:
- **[A]** Chained (k-1 rows, consecutive pairs). Aligns with `stats::anova(fit1,
  fit2, fit3, ...)` which is the most common reference implementation. —
  Effort: matches current kernel.
- **[B]** All pairwise (k*(k-1)/2 rows). More expensive, arguably more useful for
  non-nested model comparison — but then the existing A-16 "identical term sets"
  and nesting checks need rethinking for non-consecutive pairs.
- **[C]** Only allow length-2 lists; error on length ≥ 3 with a new class
  `surveycore_error_anova_list_too_many`. Defer multi-model comparison to a later
  PR. — Simplest; minimal scope creep.
- **[D] Do nothing** — implementation picks ad-hoc.

**Recommendation: A** — mirrors `stats::anova(...)` semantics users already know,
reuses the existing `.anova_compare()` kernel in a straightforward loop, and avoids
re-deriving the nesting/separation invariants for non-consecutive pairs.

---

#### Section: Step-by-Step Tasks — Task 8.3 (line 358)

**Issue 6: NEWS.md bullet contradicts Q1 (hard break, not deprecation)**
Severity: REQUIRED
Violates the Q1 resolution (line 69: "hard break. Remove `model2` entirely. No
deprecation warning, no shim").

Task 8.3 bullet as drafted: "`model2` is **deprecated**; pass `list(fit1, fit2)`
instead."

A hard-break removal is not a deprecation. The NEWS bullet will mislead users into
thinking `model2` still works with a warning.

Options:
- **[A]** Replace "deprecated" with "removed": "`model2` has been **removed**; pass
  `list(fit1, fit2)` instead. This is a hard break with no shim — see
  `?get_anova` for the migration path." — Effort: trivial.
- **[B]** Walk back Q1 to a soft deprecation via `lifecycle::deprecate_warn()`. —
  Effort: medium, Impact: reopens Q1.

**Recommendation: A**.

---

#### Section: Target Signature (line 34) + OPEN QUESTIONS — Q6

**Issue 7: `check_dots_empty()` doesn't guard `formula` / `response` / `predictors` when `object` is a fit**
Severity: REQUIRED
Violates engineering-preferences.md §5 — behavior at the fit/non-NULL-formula
boundary is not specified.

Q6 resolution (line 162): `rlang::check_dots_empty()` guards unintended args when
`object` is a fit or list. But `formula`, `response`, `predictors` are **named
parameters**, not in `...` — `check_dots_empty()` does not see them.

Scenarios not covered by the plan:
- `get_anova(fit, formula = y ~ x)` — ignored silently under current plan
- `get_anova(fit, response = y)` — same
- `get_anova(list(fit1, fit2), predictors = c(x1, x2))` — same

This overlaps with Issue 2 but deserves its own entry because the fix (explicit
guard) must be specified in the plan, not left as an implementation choice.

Options:
- **[A]** Add an explicit "formula args unexpected" guard in the fit/list branches
  (resolves this + Issue 2 via one error class). — Effort: low.
- **[B] Do nothing** — silent-ignore behavior for misnamed calls; see Issue 2.

**Recommendation: A** — coordinate with Issue 2 so one class covers both.

---

#### Section: Step-by-Step Tasks — Final Checks (line 363)

**Issue 8: No concrete acceptance-criteria section; Final checks skip standard gates**
Severity: REQUIRED
Violates surveycore testing-surveycore.md (coverage threshold, dual-pattern for user-facing
errors) and github-strategy.md (changelog/NEWS/doc verification).

Task 9.1–9.4 list some gates but miss:
- Coverage threshold (98%+; PR blocked below 95% per testing-standards.md §2)
- Explicit oracle tolerance for "list-of-fits length-2 ≡ current model2 path"
  (Task 2.1 says `tolerance = 1e-12`; should be raised to the standard 1e-10 /
  1e-8 per testing-surveycore.md — or justify why tighter is safe here)
- Dual-pattern `expect_error(class=) + expect_snapshot(error=TRUE)` on every new
  Layer 3 error class (Task 7.1 says "dual-pattern" but doesn't call out the
  specific class IDs)
- `plans/error-messages.md` updated AND `error-class-auditor` agent run
- `devtools::document()` run; NAMESPACE unchanged (Task 8.2 covers this, good)
- Audit of vignettes (not just tests) for `model2` / positional `method`,`test`
  (Task 9.3 says "tests / vignettes" — good, but verify vignettes is in scope)

Options:
- **[A]** Add a "Acceptance Criteria" section before "Final checks" that enumerates
  every gate. — Effort: low.
- **[B] Do nothing** — rely on project-wide defaults.

**Recommendation: A** — the project has standardized gates; copying them into the
plan prevents the r-implement agent from skipping any.

---

#### Section: Files (line 240)

**Issue 9: File split may be warranted — `R/glm-anova.R` is 1,126 lines pre-change**
Severity: SUGGESTION

Current `R/glm-anova.R` is 1,126 lines. Plan adds `.anova_dispatch_object()`,
`.anova_fit_from_design()`, `.anova_compare_list()`, plus new `get_anova()` body
with expanded docs. Likely grows by 200+ lines. No package-wide rule enforces a
file size cap, but code-style.md §3 "Internal helper placement" suggests promotion
to `07-utils.R`-style shared files is the idiom when a helper has multiple call
sites — here the helpers are all anova-internal, so the idiom doesn't apply.

Options:
- **[A]** Keep as-is in `R/glm-anova.R`. — Consistent with current layout.
- **[B]** Split dispatch into `R/glm-anova-dispatch.R` with the three new helpers +
  the top-level `get_anova()` body, keep existing kernel in `R/glm-anova.R`. —
  Effort: medium, Impact: marginally easier review.

**Recommendation: A** — the split would scatter a single conceptual unit across two
files for cosmetic gain.

---

#### Section: Step-by-Step Tasks — Task 1.0 (line 273)

**Issue 10: Task 1.0 is a no-op**
Severity: SUGGESTION

Task 1.0: "Precondition check. Confirm branch `feature/get-anova-polymorphic` is cut
from `develop`. Already confirmed (`R/glm.R:152`); no runtime check needed."

The task body says the check is already done and no action is needed. Leaving the
task in place creates ambiguous "what does done mean" for r-implement.

**Recommendation:** Delete Task 1.0 entirely. The prerequisite can live in the plan
preamble if needed.

---

#### Section: Step-by-Step Tasks — cycle naming (line 280, 304, 323)

**Issue 11: "TDD Cycle A → B → D" skips C**
Severity: SUGGESTION

The TDD cycles are labeled A, B, D. Either the plan originally had a C that was
merged away, or it's a typo. Relabel A → B → C, or keep labels but add a one-line
comment for the missing C.

**Recommendation:** Relabel to A → B → C. Trivial.

---

#### Section: OPEN QUESTIONS — Q7 (line 167)

**Issue 12: `null` validation vs. `null`-ignored-warning ordering not specified**
Severity: SUGGESTION

Q7 says warn + drop `null` when `object` is a list. But the existing `null` validation
(current code, R/glm-anova.R:727) checks `!is.numeric(null)`, which is a type
contract. If a user passes `null = "foo"` with a list, should they get the type
error or the warning?

Options:
- **[A]** Type-check `null` first (fail hard on non-numeric), then warn on the
  list-+-numeric-null case. — Consistent with defensive programming.
- **[B]** Warn-and-drop first, never type-check in list mode. — Surprises users who
  mistyped.

**Recommendation: A** — specify explicitly in the Q7 resolution.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 2 |
| REQUIRED | 6 |
| SUGGESTION | 4 |

**Total issues:** 12

**Overall assessment:** The plan's resolved-open-questions section is thorough but
two load-bearing pieces of behavior — the `anova.survey_glm_fit()` S3 delegator
and the fit-branch guard against misnamed formula args — are either out of scope
or under-specified and will cause runtime failures or silent behavior changes.
A length-3 list semantics sub-question is also tagged as "flag during review" and
remains genuinely open. Resolve issues 1–7 before coding starts; issues 8–12 can
be rolled into Stage 3 discussion but should not be skipped.
