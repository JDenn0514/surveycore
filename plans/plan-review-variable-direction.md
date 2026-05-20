## Plan Review: variable-direction — Pass 1 (2026-05-07)

### New Issues

#### Section: PR Map

No issues found. Three PRs are well-scoped: one per new metadata attribute plus
one for the `get_diffs()` consumer. PR 3's hard gate on PR 1 is explicit and
correct.

---

#### Section: PR 1 — `higher_is` attribute

**Issue 1: 98%+ coverage criterion missing from all three PRs**
Severity: REQUIRED
Violates `testing-standards.md §2` ("98%+ line coverage is the project target;
PRs that drop coverage below 95% are blocked by CI")

None of the three PRs' acceptance criteria includes a line-coverage check. The
acceptance criteria for PRs 1, 2, and 3 each list `devtools::check()` and
snapshot review, but never state "98%+ line coverage on new code; overall
package coverage ≥ 95%."

Options:
- **[A]** Add a coverage criterion to each of the three PRs' acceptance criteria:
  `"98%+ line coverage on new code; overall package coverage ≥ 95% (verified
  with covr::package_coverage())"` — Effort: low, Risk: low, Impact: ensures CI
  gate is part of the PR definition of done
- **[B]** Add a single global note at the top of the plan referencing the standard
  — Effort: low, Risk: medium (easy to miss in the plan), Impact: same
- **[C] Do nothing** — Coverage check is implicitly expected from
  `testing-standards.md`, but the criterion is invisible in PR acceptance criteria
  and easy to skip under time pressure.

**Recommendation: A** — Each PR's acceptance criteria should be self-contained.
Adding one line per PR is negligible effort and prevents the check being
forgotten at ship time.

---

**Issue 2: Convention 3 `direction_invalid` path is untested**
Severity: REQUIRED
Violates `testing-standards.md §2` ("Every error class gets a test")

The only `direction_invalid` test in the plan is:
```
set_higher_is(d, anxiety = "neutral")   # Convention 1 — named dot
```
This exercises the per-pair validation in the loop (after `.parse_setter_input()`
returns). The pre-check block executed before `.parse_setter_input()` — which
fires for Convention 3 scalar when `direction` is not NULL — is never exercised:

```r
# pre-check (fires for Convention 3 scalar only)
if (!is.null(direction) && !direction %in% c("better", "worse")) { ... }
```

Without a test like `set_higher_is(d, variable = "anxiety", direction = "neutral")`,
this block has zero coverage. If a future refactor breaks it, no test will
catch the regression.

Options:
- **[A]** Add one happy-path/error-path test to Step 2: `set_higher_is(d,
  variable = "anxiety", direction = "neutral")` — `expect_error(class = ...) +
  expect_snapshot(error = TRUE)` — Effort: low, Risk: low, Impact: full coverage
  of the pre-check path
- **[B]** Remove the pre-check entirely and rely solely on the per-pair loop
  check, then document in a code comment that Convention 3 direction validation
  is handled in the loop — Effort: low, Risk: low, Impact: slightly simpler
  implementation; removes the coverage gap by removing the uncovered code
- **[C] Do nothing** — The correct error fires via the loop in all tested
  cases; the pre-check code path is a latent coverage gap.

**Recommendation: A** — Adding the Convention 3 test is the minimal-risk fix and
also validates the end-to-end Convention 3 path for `direction_invalid`.

---

**Issue 3: Acceptance criteria say "5 error classes" — ambiguous against 8 test blocks**
Severity: SUGGESTION
Clarity concern

PR 1 acceptance criteria: "Error paths: all 5 error classes produce
snapshot-matched messages."
PR 2 acceptance criteria: "Error paths: all 5 error classes produce
snapshot-matched messages."

Both PRs have 5 unique error classes but require 8 separate test blocks
(setter and extractor each need blocks for `not_survey_or_df` and
`ambiguous_input`). An implementer reading "5 error classes" might write only
5 blocks and miss the per-function variants.

Options:
- **[A]** Change the criterion to: "Error paths: all 8 error-path blocks written
  (5 unique classes; `not_survey_or_df` and `ambiguous_input` tested separately
  for setter and extractor)" — Effort: trivial, Risk: none, Impact: unambiguous
- **[B] Do nothing** — Step 2 lists all 8 blocks explicitly; the acceptance
  criterion count is a summary only.

**Recommendation: A** — The acceptance criteria are the PR-open gate. Clarity
there matters.

---

#### Section: PR 2 — `reverse_coded` attribute

**Issue 4: `set_reverse_coded()` Convention 3 setter happy path not tested**
Severity: SUGGESTION
Violates `testing-standards.md §2` (happy path coverage)

The PR 2 test plan for `set_reverse_coded()` covers:
- Convention 1: `set_reverse_coded(d, anxiety)` (single bare name) ✅
- Convention 1 multi: `set_reverse_coded(d, anxiety, worry)` ✅
- Convention 1 unset: `set_reverse_coded(d, anxiety, reverse_coded = FALSE)` ✅
- Data frame: ✅

But there is no happy-path test for:
```r
set_reverse_coded(d, variable = "anxiety")          # Convention 3 — scalar
set_reverse_coded(d, variable = c("anxiety", "worry"))  # Convention 3 — vector
```

The extractor test plan includes `extract_reverse_coded(d, variable = "anxiety")`
as a happy path. The setter has the same `variable` argument and should be
symmetrically tested. This is the code path that exercises the
`if (dots_used) { ... } else { ... }` branch when `dots_used = FALSE` and
`var_used = TRUE`.

Options:
- **[A]** Add one happy-path block to Step 2: `set_reverse_coded(d, variable =
  c("anxiety", "worry"))` — verifies both variables are flagged — Effort: low,
  Risk: none, Impact: exercises the `variable` branch in the setter
- **[B] Do nothing** — The ambiguous-input error test (setter, both `...` and
  `variable`) implicitly confirms `variable` is a known argument; full coverage
  of the `variable` branch is tested via the error path.

**Recommendation: A** — A happy-path test for Convention 3 is cheap and makes
the setter's coverage symmetric with the extractor.

---

#### Section: PR 3 — `get_diffs()` favorability extensions

**Issue 5: Favorability block insertion point is under-specified; silent correctness bug if placed before Step 20**
Severity: REQUIRED
Implementation ambiguity that produces a silent wrong-answer bug

The plan says:
> "Insert after `.apply_name_style()` and `.apply_decimals()` are called,
> before `return(result)`"

The actual `get_diffs()` function has this sequence:
- Step 18: `.apply_decimals()`
- Step 19: `.apply_name_style()`
- **Step 20:** `x_meta <- .extract_var_meta(design, x_name)` … `attr(result, ".meta") <- .build_meta(...)`
- Step 21: column-level labels
- Step 22: set class and return

The favorability block reads:
```r
higher_is_val <- attr(result, ".meta")$x[[x_name]]$higher_is
```

If the block is inserted **between Step 19 and Step 20**, `attr(result, ".meta")`
is `NULL`. In R, `NULL$x` = `NULL`, `NULL[[x_name]]` = `NULL`, so
`higher_is_val` silently becomes `NULL` — meaning the favorability block would
always produce all-`FALSE` results even when `higher_is` is set on the design.
There is no error; it just silently never works.

The save/restore pattern also captures the pre-Step-22 class
(`c("tbl_df", "tbl", "data.frame")`), which is fine since Step 22 overwrites
it. But the `.meta` issue is a silent correctness failure.

Fix options:
- **[A]** Change the plan to say "Insert after Step 20 (after
  `attr(result, '.meta') <- .build_meta(...)` is executed)" — Effort: trivial,
  Risk: none, Impact: removes ambiguity; implementer places block correctly
- **[B]** Change the block to read `x_meta$higher_is` directly (using the local
  variable set at Step 20 line 448) instead of `attr(result, ".meta")$x[[x_name]]$higher_is`
  — Effort: trivial, Risk: none, Impact: block can be inserted anywhere after
  Step 20's local variable is assigned; same value, no `.meta` dependency
- **[C] Do nothing** — An attentive implementer reading the full function will
  notice `.meta` isn't attached yet and adjust; an inattentive one ships a
  silently broken feature.

**Recommendation: B** — Using `x_meta$higher_is` is simpler and eliminates the
ordering dependency entirely. Update the note in §Notes accordingly.

---

#### Section: Cross-cutting / Out of Scope

**Issue 6: Spec §I scope table says "direction" where it should say "show_favorability"**
Severity: SUGGESTION
Spec inconsistency (plan itself is correct)

The spec §I scope table entry for PR 3 reads:
> "| 3 | `get_diffs()` extensions | `alpha`, `direction` arguments; … |"

But throughout the spec body, the second new argument is `show_favorability`.
There is no argument named `direction` added to `get_diffs()`. The plan
correctly implements `show_favorability`. The scope table contains a stale name.

This is a spec issue, not a plan issue, but if the spec is referenced by
others during review it may cause confusion.

Options:
- **[A]** Correct the spec §I scope table to read "alpha, show_favorability
  arguments" — Effort: trivial, Risk: none
- **[B] Do nothing** — The plan is correct; the spec body is correct; the table
  is vestigial.

**Recommendation: A** — Update the spec table entry to avoid confusion during
PR review.

---

**Issue 7: NEWS.md not mentioned in any PR's file list or acceptance criteria**
Severity: SUGGESTION
Release workflow gap

None of the three PRs lists `NEWS.md` as a file to update, and none of the
acceptance criteria include a changelog entry. PRs 1 and 2 each add two new
exported functions (`set_higher_is`, `extract_higher_is`, `set_reverse_coded`,
`extract_reverse_coded`). PR 3 adds two new arguments to an existing exported
function. All three warrant `NEWS.md` entries.

Options:
- **[A]** Add `NEWS.md` to each PR's file list and add a criterion:
  "NEWS.md entry written under the appropriate version heading" — Effort: low,
  Risk: none, Impact: each PR is self-contained at ship time
- **[B]** Add a single post-PR-3 checklist item to update NEWS.md once for
  all three PRs — Effort: low, Risk: medium (easy to defer and forget)
- **[C] Do nothing** — NEWS.md is updated during the release preparation
  (`/merge-main` workflow).

**Recommendation: A** — Each PR should be independently shippable; a reviewer
checking the PR branch should see the NEWS.md entry alongside the code.

---

### Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 3 |
| SUGGESTION | 4 |

**Total issues:** 7

**Overall assessment:** The plan is nearly implementation-ready. Issues 2 and 5
are the most important: Issue 2 is a test coverage gap that leaves a code path
unexercised, and Issue 5 is a silent wrong-answer bug if the favorability block
is placed at the wrong position within `get_diffs()`. Both are quick to fix
(one test block added, one line changed from `attr(result, ".meta")$x[[x_name]]$higher_is`
to `x_meta$higher_is`). Resolve the three REQUIRED issues and the plan is ready
to hand off to `/r-implement`.

---

## Plan Review: variable-direction — Pass 2 (2026-05-07)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | 98%+ coverage criterion missing from all three PRs | ⚠️ Still open |
| 2 | Convention 3 `direction_invalid` path is untested | ⚠️ Still open |
| 3 | Acceptance criteria say "5 error classes" — ambiguous against 8 test blocks | ⚠️ Still open |
| 4 | `set_reverse_coded()` Convention 3 setter happy path not tested | ⚠️ Still open |
| 5 | Favorability block insertion point under-specified; silent correctness bug if misplaced | ⚠️ Still open |
| 6 | Spec §I scope table says "direction" where it should say "show_favorability" | ⚠️ Still open |
| 7 | NEWS.md not mentioned in any PR's file list or acceptance criteria | ⚠️ Still open |

### New Issues

#### Section: PR 1 — `set_higher_is()` implementation

**Issue 8: Direction pre-check behavior is inconsistent for vector `direction` inputs**
Severity: SUGGESTION
Violates engineering-preferences.md §5 (explicit over clever).

The plan's concrete structure for `set_higher_is()` includes a pre-check before calling `.parse_setter_input()`:

```r
if (!is.null(direction) && !direction %in% c("better", "worse")) { ... }
```

`&&` in R uses only the **first element** of each operand. For vector `direction` inputs this produces inconsistent behavior:
- `direction = c("neutral", "worse")` → `TRUE && TRUE` → pre-check fires; error displays the whole vector as the bad value ✅
- `direction = c("worse", "neutral")` → `TRUE && FALSE` → pre-check silently passes; error fires later from the per-pair loop, displaying only the invalid element ✅

Both cases correctly raise `surveycore_error_direction_invalid`. However, the displayed invalid value differs based on which element is bad first — surprising for callers of Convention 3 with vector inputs.

The pre-check was designed for scalar `direction` (Convention 3 scalar); applying it to vectors is an unintended side-effect of not restricting the length check.

Options:
- **[A]** Restrict pre-check to scalar: `if (length(direction) == 1L && !is.null(direction) && !direction %in% c("better", "worse"))` — Effort: trivial, Risk: none, Impact: consistent behavior; scalars caught early, vectors always validated per-element in loop, Maintenance: none
- **[B]** Remove the pre-check entirely; rely solely on the per-pair loop check — Effort: trivial, Risk: none, Impact: fully consistent; slightly more code executed for scalar errors, Maintenance: none
- **[C] Do nothing** — Functional correctness preserved; inconsistent error message display for vector inputs

**Recommendation: A** — One-word addition scopes the pre-check to the case it was designed for without affecting any currently-tested behavior.

---

#### Section: PR 3 — Favorability block placement (Issue 5 follow-up)

Code confirmation: `get_diffs()` in `R/analysis-diffs.R` attaches `.meta` at **line 469** (`attr(result, ".meta") <- .build_meta(...)`) — which is **after** `.apply_name_style()` at line 445. `x_meta` (the local variable for the x-variable metadata) is assigned at line 448. The favorability block reads `attr(result, ".meta")$x[[x_name]]$higher_is`. If the block is placed between lines 445 and 469, `.meta` is `NULL`, `higher_is_val` is silently `NULL`, and all favorability results are `FALSE` regardless of what `higher_is` is set to — a silent wrong-answer bug with no error.

The plan's current specification ("Insert after `.apply_name_style()` and `.apply_decimals()` are called, before `return(result)`") spans this dangerous window. The simplest fix remains switching to `x_meta$higher_is` (line 448 local variable), which eliminates the ordering dependency.

---

### Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 0 new (Issues 1, 2, 5 from Pass 1 still unresolved) |
| SUGGESTION | 1 new (Issue 8) |

**Total new issues:** 1

**Open issues requiring resolution before implementation:** Issues 1, 2, and 5 (REQUIRED from Pass 1). Issues 3, 4, 6, 7 (SUGGESTION from Pass 1) and Issue 8 (SUGGESTION, new) can be resolved during implementation or in Stage 4 at the author's discretion.

---

## Plan Review: variable-direction — Pass 3 (2026-05-07)

### Prior Issues (Passes 1–2)

| # | Title | Status |
|---|---|---|
| 1 | 98%+ coverage criterion missing from all three PRs | ⚠️ Still open |
| 2 | Convention 3 `direction_invalid` path is untested | ⚠️ Still open |
| 3 | Acceptance criteria say "5 error classes" — ambiguous against 8 test blocks | ⚠️ Still open |
| 4 | `set_reverse_coded()` Convention 3 setter happy path not tested | ⚠️ Still open |
| 5 | Favorability block insertion point under-specified; silent correctness bug if misplaced | ⚠️ Still open |
| 6 | Spec §I scope table says "direction" where it should say "show_favorability" | ⚠️ Still open |
| 7 | NEWS.md not mentioned in any PR's file list or acceptance criteria | ⚠️ Still open |
| 8 | Direction pre-check inconsistent for vector `direction` inputs | ⚠️ Still open |

### Code Verification — Issue 5 (Authoritative)

Direct inspection of `R/analysis-diffs.R` confirms the exact execution order:

```
Line 438:  result <- .apply_decimals(result, decimals)
Line 445:  result <- .apply_name_style(result, name_style, ...)
Line 448:  x_meta <- .extract_var_meta(design, x_name)   ← x_meta local var set here
Line 469:  attr(result, ".meta") <- .build_meta(...)      ← .meta attached here
Line 472:  stopifnot(all(DIFFS_META_KEYS %in% names(meta_args)))
Lines 498–513:  column-label loop
Lines 515–522:  class(result) <- c("survey_diffs", ...)
Line 523:  result                                          ← implicit return
```

The plan says to insert the favorability block "after `.apply_name_style()` and `.apply_decimals()` are called, before `return(result)`" — which spans the range lines 445–522. The dangerous sub-range is **445–468**: `.meta` is `NULL` there, so `attr(result, ".meta")$x[[x_name]]$higher_is` silently returns `NULL` and all favorability results are `FALSE`. Safe range is **469–522**.

The fix from Pass 2 is confirmed correct: switching to `x_meta$higher_is` (available from line 448 onward) eliminates the ordering constraint entirely. The plan must adopt this fix before implementation.

Also verified: `.parse_setter_input()` (line 72 comment) explicitly documents "NULL values signal deletion" — confirming that Convention 1 unsetting (`set_higher_is(d, anxiety = NULL)`) flows correctly through `.parse_setter_input()` without needing special-case handling.

### New Issues

#### Section: All PRs

No new BLOCKING or REQUIRED issues found in Pass 3. All five lenses were re-applied:

- **Lens 1 (Granularity):** PR scope is clean. Three PRs, one coherent unit each. No bundling or splitting needed.
- **Lens 2 (Dependency ordering):** PR 1 independent, PR 2 recommended-sequential (merge conflict risk in `core-classes.R` if concurrent), PR 3 hard-gated on PR 1. All dependencies accurate.
- **Lens 3 (Acceptance criteria):** Issues 1, 3, 7 remain the open gaps (coverage, error-block count ambiguity, NEWS.md).
- **Lens 4 (Spec coverage):** Issue 2 remains the only coverage gap (Convention 3 `direction_invalid` test path). No scope creep found. No spec behaviors missing from the plan.
- **Lens 5 (File completeness):** All R source, test, and error-messages files listed correctly. Issue 7 (NEWS.md) remains the only missing file.

---

### Summary (Pass 3)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 0 new |
| SUGGESTION | 0 new |

**Total new issues:** 0

**Open issues requiring resolution before implementation:** Issues 1, 2, and 5 (REQUIRED from Pass 1). All three are quick fixes: add one coverage line to each PR's acceptance criteria (Issue 1), add one test block for Convention 3 `direction_invalid` (Issue 2), and change `attr(result, ".meta")$x[[x_name]]$higher_is` to `x_meta$higher_is` in PR 3 Step 5 (Issue 5). Issues 3, 4, 6, 7, 8 (SUGGESTION) may be resolved during implementation at the author's discretion.

**Overall assessment:** The plan is structurally sound with no new problems found after three adversarial passes. The three REQUIRED issues from Pass 1 are all trivial to fix (one line each). Resolve them and this plan is ready to hand off to `/r-implement`.
