# Implementation Plan: `get_anova()` Polymorphic Input

**ID:** get-anova-polymorphic
**Spec:** none (Tier 2 — behavior resolved in conversation 2026-04-21)
**Status:** Ready for implementation — **all open questions resolved**

---

## Overview

Extend `get_anova()` so its first argument accepts:

1. A `survey_glm_fit` (current behavior).
2. A `list` of `survey_glm_fit` objects (replaces `model2` for model comparison).
3. A `survey_base` subclass (design) + a formula interface (`formula`,
   `response` / `predictors`), in which case `get_anova()` internally fits a
   `survey_glm()` and runs anova on the result.

The first arg is renamed `object` (matching `stats::anova()` convention).
`model2` is deprecated. `...` is added and forwarded to `survey_glm()` when
`object` is a design; it errors otherwise. Control args (`method`, `test`,
`null`, `tolerance`, `decimals`, `label_vars`, `name_style`) move after `...`
per `code-style.md §4` (named-only).

Side-effect: once this ships, the `survey_collection` spec §I deferral for
`get_anova()` collapses — a three-line dispatch branch on `survey_collection`
can be added in the same PR or a follow-up, since `get_anova(coll, y ~ x)`
now has a well-defined meaning (fit on each survey, anova each, row-bind).

---

## Target Signature

```r
get_anova(
  object,
  formula = NULL,
  response = NULL,
  predictors = NULL,
  ...,
  method = c("LRT", "Wald"),
  test = c("F", "Chisq"),
  null = NULL,
  tolerance = sqrt(.Machine$double.eps),
  decimals = NULL,
  label_vars = TRUE,
  name_style = "surveycore"
)
```

Dispatch (resolved by first matching branch):

| `object` class | Behavior |
|---|---|
| `survey_collection` | Pre-check: error with `surveycore_error_collection_not_supported_by_fn`. Collection dispatch is deferred to the follow-up PR per Q10; this pre-check preserves the cross-spec contract with `survey_collection` spec §I during the deferral window. When the follow-up lands, this branch is replaced (not supplemented) with the fit-each-survey dispatch. |
| `survey_glm_fit` | Single-model anova. Current behavior. |
| `list` of `survey_glm_fit` | Multi-model comparison. Length 2 ≡ current `model2` path; length ≥ 3 is new. |
| `survey_base` (any subclass) | Fit via `survey_glm()` using formula interface + `...`, then run single-model anova on the result. |
| anything else | Error `surveycore_error_anova_object_invalid`. |

---

## OPEN QUESTIONS

Resolve these before locking the plan. Each question has a proposed default
in brackets that the plan below currently assumes.

### Q1. `model2` deprecation path — soft or hard? [RESOLVED]

**Resolved: hard break.** Remove `model2` entirely. No deprecation warning,
no shim.

Callers using `get_anova(fit1, fit2)` will error: `fit2` is matched
positionally to the new `formula` parameter, and the fit branch carries
an explicit guard that errors when `formula`, `response`, or `predictors`
is non-`NULL`. Error class: `surveycore_error_anova_formula_unexpected`.
(The same guard covers `get_anova(list(fit1, fit2), predictors = c(x1, x2))`
and similar misnamed calls — see Issue 2 / Issue 7 in the plan review.)

Rationale: package is pre-1.0 (`X.Y.Z.9000`) and not on CRAN yet, so a clean
break is permissible.

Message template:
> `x` = `{.arg formula}` / `{.arg response}` / `{.arg predictors}` must be `NULL` when `{.arg object}` is a `{.cls survey_glm_fit}` or a list of fits.
> `i` = These arguments only apply when `{.arg object}` is a survey design.
> `v` = Drop the formula argument, or pass a design as `{.arg object}` instead.

---

### Q2. Empty list — error class? [RESOLVED]

`get_anova(list())` — no models to compare.

**Resolved:** class = `surveycore_error_anova_empty_model_list`. Message
template as written.

Message template:
> `{.arg object} is a zero-length list. Supply at least one {.cls survey_glm_fit}.`

---

### Q3. Length-1 list — treat as single-model or error? [RESOLVED]

`get_anova(list(fit1))` — one fit wrapped in a list.

**Resolved:** unwrap silently, no warning. `get_anova(list(fit1))` is treated
as `get_anova(fit1)`.

Rationale: list-form arises naturally from programmatic construction
(`do.call(list, fits)`) and may degenerate to length 1; a warning would be
noise.

---

### Q4. Mixed-class list — partial validation? [RESOLVED]

`get_anova(list(fit1, not_a_fit, fit3))` — one element isn't a
`survey_glm_fit`.

**Resolved:** reuse `surveycore_error_anova_object_invalid`; report indices.
Message template as written.

Message template:
> `x` = All elements of `object` must inherit `<survey_glm_fit>`.
> `i` = Bad elements at position(s) `{.val {bad_idx}}`: `{.cls {bad_classes}}`.

---

### Q5. Design without formula — error class & precedence? [RESOLVED]

`get_anova(design)` — design input but no `formula`, `response`, or
`predictors`. And: what if the user supplies **both** `formula` and
`response`/`predictors`?

**Resolved (two parts):**

- **Part A — Missing formula:** pre-check in `get_anova()`. Error class =
  `surveycore_error_anova_formula_missing`. Triggers when `object` is a
  `survey_base` and all of `formula`, `response`, `predictors` are `NULL`.
  This is an anova-scoped contract violation, so the error originates in
  `get_anova()` rather than deeper in `survey_glm()`.

- **Part B — Conflicting `formula` + `response`/`predictors`:** forward to
  `survey_glm()` and let its existing validator error. Rationale: DRY
  (don't duplicate `survey_glm()`'s validation), and the conflict is
  genuinely about fitting-contract semantics, not anova semantics. The
  forwarding behavior is documented in the `@param formula` /
  `@param response` / `@param predictors` roxygen so users know where the
  error originates.

---

### Q6. Fit / list input + non-empty `...` — error? [RESOLVED]

`get_anova(fit, family = gaussian())` — `...` is meaningless when `object`
is already a fit.

**Resolved: use `rlang::check_dots_empty()`** when `object` is a
`survey_glm_fit` or a `list`. No custom surveycore error class.

Rationale:
- Standard tidyverse idiom (dplyr, ggplot2, etc.).
- Automatic fuzzy typo detection — catches `methd = "Wald"` with a "Did
  you mean `method`?" suggestion for free.
- Plain-language user-friendly message.
- Avoids duplicating typo-detection logic in our own class.

The error class will be rlang's own (`rlib_error_dots_nonempty` or
whatever rlang's current default is). We accept rlang's class rather than
wrapping it in a surveycore-branded class.

When `object` is a `survey_base` (design input), `...` is forwarded to
`survey_glm()` and is NOT checked by `check_dots_empty()`.

---

### Q7. `null` argument + multi-model list — error? [RESOLVED]

`null` is only meaningful in single-model mode (it parameterizes the
hypothesized value for the tested term). `get_anova(list(fit1, fit2), null = 0)`
has no sensible meaning.

**Resolved:** warn. Warning class =
`surveycore_warning_anova_null_ignored`. The warning informs the user that
`null` has no effect in multi-model comparison mode; the value is then
ignored and computation proceeds as if `null` had not been supplied.

Rationale: the user made a mistake but it's recoverable — silent ignore
hides it; error is too harsh for a recoverable situation.

**Validation order (resolved in Issue 12 of the plan review):** type-check
`null` **first**. If `!is.null(null) && !is.numeric(null)`, throw the
existing `null`-type error regardless of whether `object` is a fit or a
list. Only when `null` is numeric AND `object` is a list does the
`surveycore_warning_anova_null_ignored` warning fire. Rationale: a typoed
`null = "foo"` is a contract violation, not a recoverable mistake — a
user passing the wrong type should see the type error, not a
silently-dropped warning.

Message template:
> `!` = `{.arg null}` has no effect when `{.arg object}` is a list of fits.
> `i` = `{.arg null}` only applies to single-model anova.
> `i` = Dropping `{.arg null}` and continuing with model comparison.

---

### Q8. `null` argument + design input — error? [RESOLVED]

`get_anova(design, y ~ x1, null = 0)` — design + formula + null. This
reduces to single-model mode internally (fit then anova), so `null` could
reasonably apply. But the user hasn't seen the intermediate fit.

**Resolved:** allow. `null` forwards to the internal single-model anova path
after fitting.

Rationale: design + formula reduces to single-model mode internally, so
`null` has a well-defined meaning there; no reason to block it.

---

### Q9. Dispatch order — what if an object matches multiple branches? [RESOLVED]

**Resolved:** dispatch order `survey_collection` (pre-check, errors) →
`survey_glm_fit` → `list` → `survey_base` → error.
Cross-inheritance confirmed impossible: `survey_glm_fit` (defined at
`R/glm.R:152`) does not inherit `survey_base`, and this is a permanent
semantic invariant. List check uses
`is.list(object) && !S7::S7_inherits(object)`. The `survey_collection`
branch sits first because it must fire before the `survey_base`-catch
branch that would otherwise match; see Issue 4 resolution in
`plans/plan-review-get-anova-polymorphic.md`.

---

### Q10. Does this PR also add `survey_collection` dispatch to `get_anova()`? [RESOLVED]

The `survey_collection` spec §I defers `get_anova()` collection support. But
once the design+formula path works, the three-line dispatch branch on
`survey_collection` becomes trivial — fit each survey, anova each, row-bind
with `.id`.

**Resolved:** follow-up PR (Option B). `survey_collection` dispatch deferred
to a separate PR after this one merges; `survey_collection` spec §I deferral
row stays until that follow-up lands.

Rationale: this PR is already large enough (new args, new errors). Collection
dispatch is a clean ~20-line follow-up.

---

### Q11. `...` validation placement — before or after formula resolution? [RESOLVED]

When `object` is a design, `...` forwards to `survey_glm()`. Invalid `...`
names (typos, wrong args) won't surface until `survey_glm()` runs.

**Resolved:** forward `...` raw to `survey_glm()`; let `survey_glm()` error
on invalid names. Document the forwarding behavior in `@param ...` roxygen.
No tryCatch/relabel.

---

## Files

Modified:
- `R/glm-anova.R` — keep the existing single-fit anova kernel. Rename the
  current top-level `get_anova()` body to an internal `.get_anova_single()`
  so the new dispatch file can call it. Also update `anova.survey_glm_fit()`
  S3 delegator (currently at `R/glm-anova.R:1040–1076`): the delegator calls
  `get_anova(object, model2 = others[[1L]], ...)`; `model2` is removed, so
  rewrite the delegation to pass `list(object, others)` (which handles
  `length(others) == 1L` as the two-fit chained case and `length(others) >= 2L`
  as the k-fit chained case per Issue 5). Preserves the S3 entry point.

New:
- `R/glm-anova-dispatch.R` — houses the new top-level `get_anova()` body
  (rewritten signature + dispatch routing) and the three new internal
  helpers, to keep `R/glm-anova.R` from growing past the kernel it already
  contains (Issue 9 resolution: split dispatch from kernel):
  - `.anova_dispatch_object()` — classifies `object` and routes.
  - `.anova_fit_from_design()` — wraps `survey_glm(design, formula, ..., response, predictors)`.
  - `.anova_compare_list()` — iterates a `list<survey_glm_fit>`, computes
    **chained** (consecutive-pair) comparison per the existing two-fit
    kernel (delegates to `.get_anova_single()` + the two-fit comparison
    kernel in `R/glm-anova.R`), row-binds into a `survey_anova` tibble.
    For a length-k list produces k-1 rows: (fit[1] vs fit[2]),
    (fit[2] vs fit[3]), …, (fit[k-1] vs fit[k]). Mirrors
    `stats::anova(fit1, fit2, fit3, …)`. Resolved in Issue 5 of the
    plan review.
- `tests/testthat/test-glm-anova-dispatch.R` — new test file for the
  dispatch / polymorphic branches (one-to-one source-to-test mapping per
  testing-surveycore.md). The existing `test-glm-anova.R` retains tests
  for the kernel (single-fit happy path, existing error paths) as
  regression guards.
- `plans/error-messages.md` — add rows for every new error/warning class
  from Q2, Q4, Q5, Q7 — including `surveycore_warning_anova_null_ignored`
  (Q7). (Q1 resolved as hard break — no deprecation warning class needed;
  Q6 resolved to use rlang's `check_dots_empty()` — no surveycore class
  needed.)
- `tests/testthat/test-glm-anova.R` — keep kernel regression tests as-is
  (single-fit happy path, existing error paths). New dispatch tests go in
  `tests/testthat/test-glm-anova-dispatch.R` per the new-file block above.
- `NEWS.md` — one bullet announcing polymorphism + `model2` deprecation.
- Man pages — regenerated via `devtools::document()`.

Unmodified but worth scanning:
- `R/glm.R` — no changes expected; `survey_glm()` is already the fit path.
- Every call site of `get_anova()` in tests / vignettes — audit to confirm
  soft-deprecation (Q1) doesn't silently break anything.

---

## Step-by-Step Tasks

Tasks assume Q1–Q11 are resolved. Task counts shift slightly depending on
answers (e.g., Q10 = bundle adds one task block for collection dispatch).

#### Infrastructure

Precondition (already confirmed, no task): feature branch
`feature/get-anova-polymorphic` is cut from `develop`; `survey_glm_fit`
is defined at `R/glm.R:152` and does not inherit `survey_base`.

- [x] **Task 1.1** — Append new error/warning rows to
  `plans/error-messages.md`. Enumerated list (one row per class):
  - `surveycore_error_anova_object_invalid` (Q1, Q4, Q9; catch-all for
    unsupported `object` class and mixed-class list elements)
  - `surveycore_error_anova_empty_model_list` (Q2)
  - `surveycore_error_anova_formula_missing` (Q5 Part A)
  - `surveycore_error_anova_formula_unexpected` (Q1 clarification, Issues
    2 & 7 in the plan review; fires when `formula`/`response`/`predictors`
    is non-`NULL` and `object` is a fit or list of fits)
  - `surveycore_warning_anova_null_ignored` (Q7)

  Also reference `surveycore_error_collection_not_supported_by_fn` (already
  defined in error-messages.md per the `survey_collection` spec) — no new
  row, just confirm the existing row covers `get_anova()`.

  Commit alone, reviewable in isolation.

#### TDD Cycle A — argument renaming + list-of-fits path

- [x] **Task 2.1** — Add RED tests for:
  - `get_anova(list(fit1, fit2))` produces the same tibble as the current
    `get_anova(fit1, fit2)` (oracle test, `tolerance = 1e-10` on point
    estimates and `1e-8` on SE/variance per testing-surveycore.md).
  - `get_anova(list(fit1, fit2, fit3))` produces a 2-row **chained**
    comparison tibble (fit1 vs fit2, then fit2 vs fit3) — mirrors
    `stats::anova(fit1, fit2, fit3)` semantics. Resolved in Issue 5 of
    the plan review.
  - `get_anova(list(fit1, fit2, fit3, fit4))` produces a 3-row chained
    tibble (covers k ≥ 4 so the loop is not just a length-3 special case).
  - Empty list errors (Q2 class).
  - Length-1 list unwraps silently — `get_anova(list(fit1))` returns the
    same tibble as `get_anova(fit1)` (oracle test).
  - Mixed-class list errors (Q4 class).

- [x] **Task 2.2** — Confirm tests fail RED. Record count.

- [x] **Task 3.1** — Implement `.anova_compare_list()` and rewire the
  single-fit path to call through it when `object` is a list. Keep the
  current two-fit comparison code as the kernel; the list wrapper is a
  thin loop.

- [x] **Task 3.2** — Confirm Task 2.1 tests pass GREEN.

- [x] **Task 3.3** — Update `anova.survey_glm_fit()` S3 delegator (currently
  `R/glm-anova.R:1040–1076`) to stop passing the removed `model2` arg and
  instead delegate via `get_anova(list(object, others[[1L]]), ...)` when
  `length(others) == 1L`. Rerun the existing `anova(fit1, fit2)` regression
  tests in `test-glm-anova.R`; they must pass without modification.

#### TDD Cycle B — design + formula path

- [x] **Task 4.1** — Add RED tests for:
  - `get_anova(design, y ~ x1 + x2)` produces a tibble equal to
    `get_anova(survey_glm(design, y ~ x1 + x2))` (oracle test).
  - `get_anova(design, response = y, predictors = c(x1, x2))` same.
  - Design + no formula → Q5 error class.
  - Design + `...` args forwarded (e.g., `family = binomial()`) produce
    the same tibble as fitting manually with that family.
  - Fit + non-empty `...` → rlang `check_dots_empty()` error (assert
    `expect_error(..., class = "rlib_error_dots_nonempty")` or current
    rlang equivalent — Q6).

- [x] **Task 4.2** — Confirm RED.

- [x] **Task 5.1** — Implement `.anova_fit_from_design()` and the design
  dispatch branch.

- [x] **Task 5.2** — Confirm GREEN.

#### TDD Cycle C — edge cases & error classes

- [x] **Task 7.1** — Add dual-pattern tests (`class=` + snapshot) for each
  new error class (Q2, Q4, Q5, Q6, Q7). Layer 3 errors (user-facing
  validation) per `testing-surveycore.md`.

- [x] **Task 7.2** — Confirm all Layer 3 error tests pass GREEN with
  stable snapshots (`testthat::snapshot_review()` to approve).

#### Docs

- [x] **Task 8.1** — Update `get_anova()` roxygen:
  - Rewrite `@param object` describing the three accepted input types.
  - Replace `@param model` / `@param model2` with the new `object`
    description. If Q1 = soft, add a `@param model2` marked
    `r lifecycle::badge("deprecated")`.
  - Add `@param formula`, `@param response`, `@param predictors`. Note
    explicitly that when `object` is a design these args are forwarded to
    `survey_glm()`, and that supplying both `formula` and
    `response`/`predictors` will error from `survey_glm()`'s validator
    (Q5 Part B forwarding behavior).
  - Add `@param ...` explaining forwarding to `survey_glm()` and the
    fit-input restriction (Q6). Document that `...` is forwarded to
    `survey_glm()` when `object` is a design; errors from invalid `...`
    names originate in `survey_glm()` (Q11).
  - Extend `@param null` with a sentence: "Only used when `object` is a
    single `survey_glm_fit` or a design. Ignored with a warning
    (`surveycore_warning_anova_null_ignored`) when `object` is a list of
    fits." (Q7.)
  - Expand `@examples` with one example per input type.

- [x] **Task 8.2** — `devtools::document()`. Verify `NAMESPACE` unchanged
  (no new exports).

- [x] **Task 8.3** — `NEWS.md` bullet under the current `X.Y.Z.9000`
  heading:
  > `get_anova()` now accepts a survey design (fits internally via
  > `survey_glm()`) or a list of `survey_glm_fit` objects. The `model2`
  > argument has been **removed**; pass `list(fit1, fit2)` instead. This
  > is a hard break with no shim — see `?get_anova` for the migration path.

#### Acceptance Criteria

Before the PR is eligible to merge, ALL of the following gates must pass.
Each is a hard requirement; none may be skipped.

1. **Coverage.** Line coverage on `R/glm-anova.R` remains ≥ 98% (per
   testing-surveycore.md). PR is blocked by CI if package-wide coverage
   drops below 95%.
2. **Numerical oracle tolerances** for list-of-fits equivalence tests
   (Task 2.1): `1e-10` on point estimates, `1e-8` on SE/variance, `1e-6`
   on CI bounds — per testing-surveycore.md variance tolerance table. Do
   NOT use `1e-12`; justify any tighter-than-standard tolerance in a
   comment in the test.
3. **Dual-pattern Layer 3 error tests** (Task 7.1). Each new error class
   below must have BOTH `expect_error(..., class = "...")` AND
   `expect_snapshot(error = TRUE, ...)`:
   - `surveycore_error_anova_object_invalid`
   - `surveycore_error_anova_empty_model_list`
   - `surveycore_error_anova_formula_missing`
   - `surveycore_error_anova_formula_unexpected`
   Plus for the warning class: `expect_warning(..., class = "...")` +
   snapshot via `expect_snapshot(warning = TRUE, ...)`:
   - `surveycore_warning_anova_null_ignored`
   The `...`-empty check (Q6) uses rlang's class and only needs the
   `expect_error(..., class = "rlib_error_dots_nonempty")` half (rlang
   owns the message; snapshotting it makes us brittle to rlang updates).
4. **`plans/error-messages.md` updated.** All five new classes have rows
   before the feature commit. Run the `error-class-auditor` agent on the
   branch before opening the PR — it must report zero drift.
5. **`devtools::document()` run.** `NAMESPACE` unchanged (no new exports
   expected; confirmed in Task 8.2). Commit any `man/*.Rd` diffs.
6. **Call-site audit.** Every `get_anova()` call in `tests/`, `vignettes/`,
   and `R/` source — none rely on positional `method`/`test` matching or
   the removed `model2` arg. Includes `anova.survey_glm_fit()` delegator
   (Task 3.3) and its regression tests (Task 9.3).
7. **`devtools::check()`** — 0 errors, 0 warnings, ≤ 2 pre-approved notes.
8. **Changelog entry.** `changelog/get-anova-polymorphic/pr-1.md` written
   per Task 9.4 (written last).

#### Final checks

- [x] **Task 9.1** — `devtools::test()` — all pass, coverage unchanged or
  improved.
- [x] **Task 9.2** — `devtools::check()` — 0 errors, 0 warnings, ≤2 pre-approved notes.
- [x] **Task 9.3** — Audit every `get_anova()` call in `tests/` and
  vignettes — none should rely on positional `method` / `test` matching
  (they're now named-only per `code-style.md §4`). Also audit every
  `anova(fit, fit2, ...)` call (S3 entry) through the updated
  `anova.survey_glm_fit()` delegator — confirm the list-form delegation
  produces identical output to the prior `model2` path.
- [x] **Task 9.4** — `changelog/get-anova-polymorphic/pr-1.md` — written
  last.

---

## Test Plan Delta

New test blocks in `tests/testthat/test-glm-anova.R`:

1. **List-of-fits happy path** (replaces existing `model2` tests; keep the
   old blocks if Q1 = soft, they now exercise the deprecation warning).
2. **List-of-fits error paths** — empty, length-1 (if Q3 = error),
   mixed-class.
3. **Design + formula happy path** — 3 variations (`formula`, `response` +
   `predictors`, formula + `family` in `...`).
4. **Design error paths** — missing formula, conflicting formula +
   response.
5. **Invalid `object`** — character, numeric, data.frame, etc.
6. **`null` argument interactions** — Q7, Q8 outcomes. For Q7:
   `get_anova(list(fit1, fit2), null = 0)` must
   `expect_warning(..., class = "surveycore_warning_anova_null_ignored")`,
   and the returned tibble must equal `get_anova(list(fit1, fit2))` (i.e.,
   `null` is dropped, not applied). For Q8:
   `get_anova(design, y ~ x1, null = value)` must produce a tibble
   identical to fitting manually (`fit <- survey_glm(design, y ~ x1)`)
   and calling `get_anova(fit, null = value)` — oracle test confirming
   `null` forwards cleanly through the design + formula path.
7. **`...` restriction** — Q6. Assert `expect_error(..., class = "rlib_error_dots_nonempty")` (rlang's class from `check_dots_empty()`), not a surveycore class.
8. **Snapshot** — one snapshot per new error class (Layer 3 dual pattern).

No changes to the existing single-fit happy-path tests — those remain as
regression guards on the kernel logic.

---

## Backward Compatibility Summary

| Old call | New behavior |
|---|---|
| `get_anova(fit)` | Unchanged. |
| `get_anova(fit1, fit2)` | **Breaks** — second arg now matches `formula`; the fit branch guards non-`NULL` formula args and errors with `surveycore_error_anova_formula_unexpected`. Migrate to `get_anova(list(fit1, fit2))`. |
| `get_anova(fit, method = "Wald")` | Unchanged (named). |
| `get_anova(fit, "Wald")` | **Breaks** — `method` is now named-only (post-`...`). Flag in NEWS. |
| `get_anova(design, y ~ x)` | New path. |

---

## Out of Scope

- Collection dispatch (`get_anova(coll, y ~ x)`) — follow-up PR (Q10 resolved).
- `broom::tidy()` / `broom::glance()` method updates — existing methods
  already work on the returned `survey_anova` tibble; no changes needed.
- (Nothing further — `anova.survey_glm_fit()` was originally marked out of
  scope but is now in scope; its delegator must be updated in this PR
  because `model2` is being removed.)
