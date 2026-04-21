# Plan Review: survey-collection

## Plan Review: survey-collection — Pass 1 (2026-04-20)

### New Issues

#### Section: Files (PR 1 and PR 2)

**Issue 1: Source-file paths use nonexistent numbered-prefix filenames**
Severity: BLOCKING
Violates Lens 5 (File Completeness) and Lens 2 (Dependency Ordering — implementer must know where to edit).

Plan names these paths:
- `R/00-s7-classes.R`
- `R/03-constructors.R`
- `R/04-methods-print.R`

The actual repo layout is:
- `R/core-classes.R`
- `R/core-constructors.R`
- `R/methods-print.R`

No `R/` file in the current tree uses a numeric prefix (see `ls R/`). The spec itself (§II) carries the same stale paths. An implementer following the plan verbatim will either hit "file not found" or create new numbered files that duplicate existing ones.

Also: Task 3.2 ("Other surveycore S7 validators (e.g., `survey_taylor` in `R/00-s7-classes.R`) already follow this pattern") and Task 7.1 ("`R/04-methods-print.R`") both embed the wrong path in narrative guidance, not only in the Files list.

Options:
- **[A]** Rewrite every path reference in PR 1 and PR 2 to the actual filenames (`core-classes.R`, `core-constructors.R`, `methods-print.R`). Effort: low, Risk: low, Impact: plan becomes executable as written.
- **[B]** Rename the actual files to match the numbered convention. Effort: medium, Risk: medium (touches every test/source cross-reference), Impact: pointless churn — the package abandoned the numbered convention.
- **[C] Do nothing** — implementer guesses each time they hit a path.

**Recommendation: A** — Cheap, matches the codebase, and retroactively correcting the spec's §II paths in the same edit avoids future confusion.

---

**Issue 2: `get_pairwise()` file path is wrong**
Severity: BLOCKING
Violates Lens 5 (File Completeness).

PR 2 Files Modified list names `R/analysis-pairwise.R`. That file does not exist — `get_pairwise()` lives in `R/analysis-t-test.R` (confirmed via Grep at line 557). Task 12.0 is supposed to re-verify via `Glob("R/analysis-*.R")` "if a file has a different exact path," but the primary list still tells an implementer to edit a nonexistent file.

Additionally, editing `get_pairwise()` and `get_t_test()` in the same file means the "commit after every two functions" rule (Task 14.2) may produce a single commit that edits two functions in one file, which is fine — but the Files list should reflect reality.

Options:
- **[A]** Remove `R/analysis-pairwise.R` from the list; add a note that `get_pairwise()` co-lives with `get_t_test()` in `R/analysis-t-test.R`. Effort: low, Risk: low.
- **[B] Do nothing** — rely on Task 12.0 to catch it. Risk: Task 12.0 only says "verify via Glob" — if the implementer follows the file list first, they will have already tried to open the missing file.

**Recommendation: A**.

---

#### Section: PR 2 / Task 14.3 (C12 guards)

**Issue 3: C12 guard in `survey_glm()` / `get_anova()` is unreachable as specified**
Severity: BLOCKING
Violates Lens 3 (Acceptance Criteria — the C12 test would never fire).

Task 14.3 says to insert the C12 `survey_collection` guard "immediately after type validation." But "type validation" in both `survey_glm()` (R/glm.R:746) and `get_anova()` is `.check_unsupported_class(design, ...)`, which raises `surveycore_error_unsupported_class` when `design` does not inherit `survey_base`. `survey_collection` deliberately does **not** inherit `survey_base` (spec §3.1 non-inheritance note). Therefore the current first-line `.check_unsupported_class()` call will fire before any "after type validation" guard, and the C12 class will never be raised.

The §VI C12 error class and the Task 14.5 dual-pattern test for `survey_glm(coll, ...)` and `get_anova(coll)` both assume the guard fires. They will fail RED and never turn GREEN unless the guard runs **before** `.check_unsupported_class()`.

Options:
- **[A]** Rewrite Task 14.3 to insert the C12 guard as the **first line** of each function body, above `.check_unsupported_class()`. Effort: low, Risk: low.
- **[B]** Modify `.check_unsupported_class()` to special-case `survey_collection` and raise C12 from there. Effort: low, Risk: medium (every analysis function inherits the behavior, so the deferral message also gets emitted for `get_freqs(coll, ...)` etc. before their own dispatch branch runs — wrong for the nine dispatching functions).
- **[C] Do nothing** — C12 class and test are dead code.

**Recommendation: A**. Option B couples the generic type-check to a per-function deferral decision that varies across the API (dispatches for nine functions, defers for two). Placing the guard literally first in `survey_glm()` and `get_anova()` keeps the contract local.

---

**Issue 4: Dispatch branch in every `get_*()` is unreachable as described if placed "after `.check_unsupported_class()`"**
Severity: BLOCKING
Violates Lens 2 (Dependency Ordering) and Lens 3.

Task 14.1 step 2 says "Insert the dispatch branch at the top of the function body (before any existing validation)." That is correct in spirit, but every current `get_*()` begins with `.check_unsupported_class(design, "get_X")` — which is "existing validation." The Implementor Notes at the bottom of PR 2 do say "Dispatch branch placement — Insert before any existing validation, including tidy-select resolution," but the actual Task 14.1 body does not mention `.check_unsupported_class()` by name, and the spec §4.2 template shows the branch inserted at entry without context.

If an implementer reads "after shared validation" or misinterprets "top of function body" as "after the existing Step 1 comment header," the branch lands below `.check_unsupported_class()` and collection dispatch silently errors as `surveycore_error_unsupported_class` before reaching the branch.

Options:
- **[A]** Rewrite Task 14.1 step 2 to say explicitly: "Insert the dispatch branch as the literal first line of the function body — above `.check_unsupported_class()`." Effort: trivial, Risk: low.
- **[B] Do nothing** — rely on the Implementor Notes. Risk: the notes are at the bottom of the PR and easy to skip.

**Recommendation: A**.

---

#### Section: PR 2 / Signatures — `.id` / `.on_missing` placement

**Issue 5: Most target functions currently have no `...` formal, so "after `...`" placement is ambiguous**
Severity: REQUIRED
Violates Lens 3 (Acceptance Criteria — signature change is not specified concretely).

Spec §4.3 and Task 14.1 step 1 say `.id` and `.on_missing` go "after `...`". Current signatures:

| Function | Has `...` in current signature? |
|---|---|
| `get_freqs()` | Yes (after `x`, before post-`...` control args) |
| `get_means()` | **No** |
| `get_totals()` | **No** |
| `get_quantiles()` | **No** |
| `get_ratios()` | **No** |
| `get_corr()` | **No** |
| `get_diffs()` | Yes (at the **end** of the signature) |
| `get_t_test()` | **No** |
| `get_pairwise()` | **No** |

Seven of the nine target functions have no `...` today. The plan does not say whether PR 2:
- (a) adds `...` to each of those seven signatures (then appends `.id` / `.on_missing`),
- (b) drops the post-`...` rule for functions without `...`,
- (c) inserts `.id` / `.on_missing` at the end of the current signature (which, for a function without `...`, means they are positional and violate the named-only intent),
- (d) moves existing control args like `group`, `variance`, `conf_level` to post-`...` positions as part of this PR.

Choice (a) is the most faithful to the spec but adds `...` to seven public exports — a larger API surface change than the plan's "mechanical template applied nine times" framing suggests.
Choice (d) is a broader signature refactor that should be its own PR if done at all.

For `get_diffs()`, `...` is at the end, so inserting `.id` / `.on_missing` between existing args and `...` moves them pre-`...` — also a signature break relative to the spec rule.

Options:
- **[A]** Add an explicit Task 14.0b: "For each function without `...`, add `...` immediately before the current post-position control args; for `get_diffs()`, move `...` to the correct position relative to `.id` / `.on_missing`." Document each target signature in the plan. Effort: medium, Risk: medium (touches public signatures; must verify no positional caller exists in tests/vignettes).
- **[B]** Re-open the §4.3 decision: allow `.id` / `.on_missing` to go in whatever position best matches each function's current layout, giving up cross-function placement consistency. Effort: low, Risk: low (named-only enforcement lost for functions without `...`; relying on convention instead).
- **[C] Do nothing** — implementer chooses. High risk of inconsistent placement across the nine functions.

**Recommendation: A**. The named-only enforcement is the load-bearing contract (§4.3). If the plan is the first application of the "post-`...` for named-only args" rule, each target's current signature needs to be documented explicitly and adjusted in the same PR. This also surfaces the broader question of whether `group` should migrate to post-`...` for consistency with `get_freqs()` — likely out of scope, but worth an explicit "no" rather than silence.

---

#### Section: PR 2 / Task 11.3 — pre-check helper

**Issue 6: `.precheck_vars_present()` is called with only `x` and `group` for each function, but spec §III.4 requires every declared NSE arg**
Severity: REQUIRED
Violates Lens 4 (Spec Coverage).

Task 14.1 step 3: "gather the resolved names for `x` and `group` (if supplied), call `.precheck_vars_present(design, resolved_names)`." Task 14.2: "Repeat Task 14.1 structure for each of the other eight functions, forwarding the NSE args from the §4.2 table." Ambiguous: "forwarding" in Task 14.2 is written in the same paragraph as the dispatch-branch rule. It is not explicit that the pre-check resolved-name vector must include every NSE arg (e.g., for `get_diffs()`: `x`, `treats`, `group`, `covariates`; for `get_ratios()`: `numerator`, `denominator`, `group`; for `get_t_test()` / `get_pairwise()`: `x`, `by`, `group`).

Spec §III.4 is explicit: "the pre-check covers **every named NSE argument the function declares** — not only the focal `x`." Spec §7.1.5 requires a test for `get_means(coll, y1, group = grp_missing_in_s2, .on_missing = "skip")` and a `get_diffs(...)` covariate variant. If the pre-check only resolves `x` and `group`, the covariates/treats/numerator/denominator/by paths won't raise `surveycore_error_variable_not_found` and `.on_missing = "skip"` won't fire correctly.

Options:
- **[A]** Rewrite Task 14.1 step 3 and Task 14.2 to enumerate, per function, which NSE arg names flow into `.precheck_vars_present()`. Effort: low, Risk: low.
- **[B]** Add a table in the plan mirroring spec §4.2's NSE-arg table, but labelled "pre-check inputs," making the per-function pre-check explicit. Effort: low, Risk: low.
- **[C] Do nothing** — Task 14.2's "forwarding" shorthand is probably understood by a careful implementer. Risk: Stage 2 just flagged this as ambiguous; it will be rediscovered during implementation.

**Recommendation: B** — a single table at Task 14.1/14.2 avoids restating per function.

---

#### Section: PR 2 / Task 13.3 — expected test state

**Issue 7: Task 13.3 claims NSE-forwarding oracle tests pass GREEN before per-function branches exist**
Severity: REQUIRED
Violates Lens 2 (Dependency Ordering).

Task 13.3 says: "Happy paths + NSE forwarding should pass GREEN. **Do not** add the per-function dispatch branches yet — those are Task 14.1+."

But every happy-path and NSE-forwarding oracle test calls `get_means(coll, ...)` (or similar) with a `survey_collection` as the first argument. Without the per-function dispatch branch in `get_means()`, the call falls through to `.check_unsupported_class()` and errors immediately with `surveycore_error_unsupported_class`. The dispatch helper is unreachable.

The actual RED→GREEN transition for these tests happens at Task 14.6, after the per-function branches land.

Options:
- **[A]** Rewrite Task 13.3 to say: "Run tests; happy-path and NSE-forwarding tests remain RED (dispatch helper exists but isn't wired). Proceed to Task 14.1." Mark them GREEN in Task 14.6 instead. Effort: trivial, Risk: low.
- **[B]** Restructure Tasks 12–14 so the helper + first per-function branch ship in one cycle, letting Task 13.3 exercise at least one function. Effort: low, Risk: low (keeps a true RED→GREEN gate).
- **[C] Do nothing** — implementer discovers the mismatch, gets blocked, debugs an already-resolved plan gap.

**Recommendation: A**. Option B is also defensible but reshuffles the task list more than needed.

---

#### Section: PR 1 / Error classes

**Issue 8: Task 3.2 contradicts the spec validator pseudocode**
Severity: REQUIRED
Violates Lens 4 (Spec Coverage — implementor must know the source of truth).

Spec §3.1 shows the validator with `return("Collection must contain at least one survey.")` etc. Task 3.1 says to emit "the four `return(<string>)` validator paths: empty, unnamed, duplicate, non-`survey_base`." Task 3.2 then says to rewrite the validator body to call `cli::cli_abort()` directly in each branch, citing C1/C2/C4's `class=` requirement.

Two problems:
1. Task 3.1 asks the implementer to write `return("...")` code that Task 3.2 immediately tells them to rewrite. Wasted work and a misleading RED test state between 3.1 and 3.2.
2. The spec §3.1 pseudocode itself stays in `return("...")` form. Without updating the spec, future readers will not see that `cli_abort()` inside the validator is the real pattern. The plan flags this in "Notes for the Implementor (PR 1)" but the spec stays stale.

Also: it is worth confirming whether `survey_taylor`/`survey_replicate` validators in the actual codebase use `cli_abort()` inside the validator function body, or use `return("...")` with an outer wrapper. Task 3.2 asserts "Other surveycore S7 validators ... already follow this pattern" but the claim should be verified (`R/core-classes.R`, not `R/00-s7-classes.R`).

Options:
- **[A]** Collapse Tasks 3.1 and 3.2 into a single task that writes the validator with `cli::cli_abort()` in each branch directly. Add a note to update spec §3.1 pseudocode (or explicitly defer that to a spec v1.2). Effort: low, Risk: low.
- **[B]** Verify the claim about existing validators before Stage 3 resolution by reading `R/core-classes.R`. Effort: trivial.
- **[C] Do nothing** — implementer rewrites their own code.

**Recommendation: A + B**.

---

#### Section: PR 2 / Task 11.3 — parent-cause wrapping

**Issue 9: Task 11.3 flags an unresolved decision to Stage 2 rather than resolving it**
Severity: REQUIRED
Violates Lens 3 (Acceptance Criteria must be objectively verifiable).

Task 11.3 contains: "Flag for Stage 2 review: the spec's §III.4 / §VI row C10 assumes the vctrs error is always caught-and-wrapped; the pre-check design short-circuits that. Surface in Stage 2 whether spec needs a clarification edit or the implementation should preserve the parent-wrap path."

This is the adversarial review (Stage 2). The flag must be resolved here:

- Spec §VI row C10 message template ends "(wraps the underlying `vctrs_error_subscript_oob` as `parent`)."
- The pre-check (Task 11.3's implementation) runs before tidyselect raises the vctrs error — so the vctrs condition never materializes.
- Task 11.3's own language says: "Resolution: the `parent = NULL` pre-check path is correct; the spec's `parent` language applies only when a call site has already caught a tidyselect error."

If that is the resolution, the spec §VI C10 row is misleading (no call site does catch-and-wrap, so `parent` is always NULL). The row should be updated in Stage 3 or a follow-up spec edit.

Options:
- **[A]** Resolve now: "`parent = NULL` is the only path; spec §VI row C10 will be updated to remove the `parent` language when PR 2 lands." Add an explicit PR 2 deliverable to edit the row. Effort: trivial, Risk: low.
- **[B]** Preserve the parent-wrap path: have each `get_*()` pre-check wrap the tidyselect call in `tryCatch(vctrs_error_subscript_oob = ...)` so a real `parent` condition exists. Effort: medium, Risk: low (adds work without changing user-visible behavior).
- **[C] Do nothing** — flag remains open into implementation.

**Recommendation: A**. Option B adds machinery for a contract no one depends on.

---

#### Section: PR 2 / DRY — name-capture-and-repair logic

**Issue 10: Name-capture logic is duplicated between `as_survey_collection()` and `add_survey()`**
Severity: REQUIRED
Violates engineering-preferences.md §1 (DRY) — Lens 5-adjacent.

Task 5.1 (constructor) step 2 defines the caller-name/bare-symbol/error logic (use caller name if non-empty, else `quo_is_symbol` → `as_name`, else raise `surveycore_error_collection_unnamed_expr`). Task 9.1 (`add_survey()`) step 2 says "compute new names the same way `as_survey_collection()` does" — same logic, second site. Without an extracted helper, one site can drift from the other (message wording, error class choice, position-index formatting).

Options:
- **[A]** Add Task 5.2b: extract `.resolve_caller_names(quosures)` into `R/survey-collection.R` alongside `.repair_collection_names()`. Both constructors call it. Effort: low, Risk: low.
- **[B] Do nothing** — two copies of the same logic ship; DRY violation documented in review.

**Recommendation: A**.

---

#### Section: PR 2 / Meta structure

**Issue 11: `.meta` top-level first-survey carry-over is specified in Implementor Notes but not in Task 13.1 steps**
Severity: SUGGESTION

Task 13.1 step 8 says "Build `new_meta` with `per_survey` + `collection$surveys` + `collection$survey_classes`; call `.warn_on_meta_divergence()`." It does not mention preserving the first survey's top-level `.meta` keys (`design_type`, `n_respondents`, etc.). The Implementor Notes at the bottom of PR 2 do cover this under "`.meta` structure preservation" — but they're far from the task that does the work.

Options:
- **[A]** Amend step 8 to say: "Build `new_meta` by concatenating the first survey's `.meta` with `list(per_survey = ..., collection = ...)`." Effort: trivial.
- **[B] Do nothing** — Implementor Notes are sufficient.

**Recommendation: A**.

---

#### Section: PR 2 / Task 14.2 — commit cadence and test state

**Issue 12: "Commit after every two functions" leaves intermediate commits with failing tests**
Severity: SUGGESTION

Task 14.2 says "Commit after every two functions so each commit can be reverted cleanly." But the test file exercises all nine functions; after the first two commits, tests for the remaining seven `get_*()` still error via `.check_unsupported_class()`. CI on each intermediate push will be RED.

Options:
- **[A]** Stage the tests by function-family so each commit closes the loop for the functions it adds. Effort: low, Risk: low.
- **[B]** Drop the commit-per-two rule; single commit for the nine branch insertions. Effort: trivial, Risk: low (single-revert granularity).
- **[C] Accept transient RED CI** — explicitly document that intermediate pushes on this branch fail until the final commit.

**Recommendation: A or C**. Either is fine; what's not fine is silently accepting RED CI without noting it.

---

#### Section: PR 1 / Coverage criterion

**Issue 13: `covr::file_coverage()` target includes the dispatch-helper lines that PR 1 does not implement**
Severity: SUGGESTION

Task 10.3: "Verify coverage on `R/survey-collection.R` via `covr::file_coverage(...)`. Target 98%+ for PR 1 scope (dispatch helpers are stubbed out in PR 2 so they will show 0%)."

PR 1 does not create the dispatch helpers at all — they are added in PR 2. There's nothing to "stub out" in PR 1. The wording is fine once you parse it ("stubbed out in PR 2" meaning "still to come"), but the phrase is confusing. Also: `covr::file_coverage()` runs the file in isolation; 98% is easy on a file with only three short functions (`.repair_collection_names`, `add_survey`, `remove_survey`), but the criterion should be stated directly.

Options:
- **[A]** Rewrite Task 10.3: "`covr::file_coverage('R/survey-collection.R', ...)` on a file containing only the three container helpers added by PR 1 should hit 98%+." Effort: trivial.
- **[B] Do nothing** — criterion works, wording is awkward.

**Recommendation: A**.

---

#### Section: PR 1 / Validator test location

**Issue 14: Validator tests are placed in `test-survey-collection.R`, but spec §II places them in `test-s7-classes.R`**
Severity: SUGGESTION

Plan Task 2.1 creates `tests/testthat/test-survey-collection.R` and writes the S7 validator test blocks there. Spec §II says "`test-s7-classes.R` + survey_collection validator tests". Per `testing-surveycore.md` §File-mapping, `R/core-classes.R` maps to `tests/testthat/test-s7-classes.R`.

Both choices are defensible — validator tests belong where the class lives (s7-classes) or where the feature lives (survey-collection). The plan should say which it's doing and why, rather than silently diverging from spec §II.

Options:
- **[A]** Keep validator tests in `test-survey-collection.R` as the plan says; update spec §II file-listing to match; note that collection tests are feature-grouped. Effort: trivial.
- **[B]** Move validator tests to `test-s7-classes.R` per spec §II; split the test plan accordingly. Effort: low.

**Recommendation: A**. Feature-grouped tests are easier for an implementer to locate (all collection tests in one file).

---

#### Section: PR 1 / Task 1.0

**Issue 15: "Precondition check — verify `survey_base` is defined" references wrong file path**
Severity: SUGGESTION

Task 1.0: "Verify on the `develop` branch, and that `survey_base` is defined in `R/00-s7-classes.R` (used by validator invariant 3)."

`R/00-s7-classes.R` does not exist. The precondition is legitimate (`survey_base` must exist before `survey_collection`'s validator can reference it), but the file path is stale — see Issue 1.

Options:
- **[A]** Rewrite: "Verify `survey_base` is defined in `R/core-classes.R`." Covered by the Issue 1 path sweep.
- **[B] Do nothing** — Issue 1 will catch it.

**Recommendation: A** — just include in the Issue 1 sweep.

---

#### Section: PR 2 / Scope creep

**Issue 16: Task 11.2 modifies `.claude/rules/code-style.md` — arguably a rule change belongs in its own PR**
Severity: SUGGESTION

Task 11.2 adds a "named-only control args go after `...`" carve-out to `code-style.md §4`. The plan says "Commit this rule change separately (chore: docs) so the rule change is reviewable in isolation from implementation." That's good. But it's still mixed into PR 2, which bundles:
- One internal helper (`.precheck_vars_present()`)
- One dispatch helper (`.dispatch_over_collection()`)
- One divergence helper (`.warn_on_meta_divergence()`)
- Nine per-function edits
- Two `survey_glm` / `get_anova` guards
- Seven new error classes
- A project-wide code-style rule change

Even as separate commits on the same branch, that's a lot. A code-style rule change arguably deserves its own PR against `.claude/rules/` so the precedent is set before any code that cites it lands.

Options:
- **[A]** Split `.claude/rules/code-style.md` update into its own tiny PR (`chore(rules): document named-only control-args convention`) that merges before PR 2. Effort: trivial, Risk: low (clean separation of "rule change" vs "first use of the rule").
- **[B] Do nothing** — the commit-separately instruction is enough.

**Recommendation: A**. Rule changes propagate across the codebase; landing the rule first lets PR 2 cite a merged precedent.

---

#### Section: PR Map

No other issues found.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 4 |
| REQUIRED | 6 |
| SUGGESTION | 6 |

**Total issues:** 16

**Overall assessment:** The plan is substantively sound — PR split is right, acceptance criteria are mostly verifiable, and the dispatch architecture tracks the spec faithfully. But four blocking issues (stale file paths, wrong `get_pairwise()` location, unreachable C12 guard, and the `.check_unsupported_class()` / dispatch-branch ordering) will stop the implementer cold, and two of the required issues (signature layout for seven functions without `...`, and the pre-check NSE-arg scope) will propagate quietly into wrong results if not resolved. Stage 3 should prioritize the blocking four and the signature issue (#5).

---

## Plan Review: survey-collection — Pass 2 (2026-04-20)

### Prior Issues (Pass 1)

None of the Pass 1 items appear to have been addressed in the plan file yet. All sixteen remain open.

| # | Title | Status |
|---|---|---|
| 1 | Source-file paths use nonexistent numbered-prefix filenames | ⚠️ Still open |
| 2 | `get_pairwise()` file path is wrong | ⚠️ Still open |
| 3 | C12 guard in `survey_glm()` / `get_anova()` is unreachable as specified | ⚠️ Still open |
| 4 | Dispatch branch in every `get_*()` is unreachable as described | ⚠️ Still open |
| 5 | Most target functions currently have no `...`; "after `...`" placement ambiguous | ⚠️ Still open |
| 6 | `.precheck_vars_present()` called with only `x` and `group` vs every NSE arg | ⚠️ Still open |
| 7 | Task 13.3 claims NSE-forwarding oracle tests pass GREEN before branches exist | ⚠️ Still open |
| 8 | Task 3.2 contradicts the spec validator pseudocode | ⚠️ Still open |
| 9 | Task 11.3 flags an unresolved decision to Stage 2 rather than resolving it | ⚠️ Still open |
| 10 | Name-capture logic duplicated between `as_survey_collection()` and `add_survey()` | ⚠️ Still open |
| 11 | `.meta` top-level first-survey carry-over mentioned only in Implementor Notes | ⚠️ Still open |
| 12 | "Commit after every two functions" leaves intermediate commits with failing tests | ⚠️ Still open |
| 13 | `covr::file_coverage()` target wording is confusing | ⚠️ Still open |
| 14 | Validator tests placed in `test-survey-collection.R`, diverging from spec §II | ⚠️ Still open |
| 15 | Task 1.0 references wrong `R/00-s7-classes.R` path | ⚠️ Still open |
| 16 | Task 11.2 rule-change bundled into PR 2 | ⚠️ Still open |

### New Issues

#### Section: PR 2 / Task 13.1 — `.id` validation

**Issue 17: `.id` parameter is not validated for being a single non-empty character string**
Severity: REQUIRED
Violates Lens 3 (Acceptance Criteria — missing boundary validation).

Task 13.1 step 1 calls `rlang::arg_match(.on_missing)`, which validates `.on_missing`. But `.id` is accepted as-is and passed straight into `results[[nm]][[.id]] <- nm` and the column-reorder step `out[, c(.id, setdiff(names(out), .id))]`. Callers supplying `.id = NULL`, `.id = ""`, `.id = NA_character_`, `.id = c("a", "b")`, or `.id = 1` will produce confusing downstream errors (or, for `.id = NULL`, silently drop the `.id` column and lose the survey identity). The spec §IV does not specify this either, but the plan is the appropriate place to lock the input contract.

Cases to cover:
- `.id = NULL` — list indexing `results[[nm]][[NULL]]` drops the assignment silently
- `.id = NA_character_` — column named `"NA"` appears
- `.id = c("a", "b")` — vectorized assignment to two columns, breaks collision check
- `.id = 1L` (integer) — positional indexing on the tibble; silently wrong
- `.id = ""` — empty-string column name; `setdiff(names(out), "")` is everything

Options:
- **[A]** Add a `.validate_id()` helper called as the first step in `.dispatch_over_collection()` — asserts `is.character(.id) && length(.id) == 1L && !is.na(.id) && nchar(.id) > 0L`, raises a typed class (e.g., `surveycore_error_collection_invalid_id` — new row in §VI). Effort: low, Risk: low, Impact: sealed input contract.
- **[B]** Rely on R's native type errors. Effort: none, Risk: inconsistent error messages across call sites.
- **[C] Do nothing** — silent misbehavior on edge inputs.

**Recommendation: A**. The dispatch helper is the single enforcement point; one validator lives here; a new C13 row in §VI locks the error class. Surfacing this in Pass 2 rather than implementation keeps the §VI table complete before error-messages.md is written.

---

#### Section: PR 2 / Task 13.1 — `bind_rows()` type handling

**Issue 18: Cross-survey column type mismatches under `bind_rows()` are unspecified**
Severity: REQUIRED
Violates Lens 4 (Spec Coverage) and Lens 3 (Acceptance Criteria).

Spec §III.4 and §7.1.8 cover heterogeneous **schemas** (different column sets), resolved by `bind_rows()` NA-filling. Neither spec nor plan addresses heterogeneous **types** for the same column across surveys. Realistic triggers:

- One survey has `age` as numeric; another has `age` as integer. `bind_rows()` coerces silently — probably fine.
- One survey has a labelled factor with different levels across surveys. `bind_rows()` coerces levels or errors depending on factor class.
- One survey produces a `value` column as a dichotomous `character` (from a factor) and another as numeric (already continuous) — `bind_rows()` errors with `"Can't combine ... <double> and ... <character>"`.
- `get_freqs()` with different `names_to` factor levels across surveys produces a cross-coerced `name` column; ordering may shift.

This matters for the dispatch-identity oracle (§7.1.4, Task 12.1): the oracle uses `dplyr::bind_rows(lapply(..., get_fn(coll[[nm]], ...)), .id = ".survey")` — the same function will fail the same way, so the oracle still holds. But a type mismatch surfaces as a `bind_rows()` error from deep inside the helper rather than a surveycore-owned class.

Options:
- **[A]** Add a Stage 3 decision: wrap `dplyr::bind_rows()` in `tryCatch` so cross-survey type mismatches raise `surveycore_error_collection_bind_type_mismatch` (new §VI row) with a message listing the offending column(s). Effort: low, Risk: low.
- **[B]** Document in the spec that type mismatches propagate as `vctrs` conditions; add a test asserting the `vctrs` class. Effort: trivial, Risk: ties us to vctrs internals.
- **[C] Do nothing** — implementer discovers during usage.

**Recommendation: A**. Consistent with the §III.4 philosophy of surveycore-owned classes wrapping underlying vctrs conditions (the same pattern applied to `surveycore_error_variable_not_found`).

---

#### Section: PR 2 / Task 11.3 — multi-missing reporting

**Issue 19: `.precheck_vars_present()` pseudocode reports only the first missing variable**
Severity: SUGGESTION

Task 11.3 pseudocode:

```r
missing <- var_names[!var_names %in% names(design@data)]
...
nm <- missing[1]
cli::cli_abort(
  c(
    "x" = "Variable {.val {nm}} not found in survey data.",
    ...
  ),
  class = "surveycore_error_variable_not_found"
)
```

If the implementer calls `.precheck_vars_present(design, c("treats", "sex"))` with both absent (see Issue 6 — broadened NSE scope), only `"treats"` is named in the error. Under `.on_missing = "skip"` over a collection this is harmless (survey is skipped regardless), but under `.on_missing = "error"` the user has to fix-and-retry for each missing variable.

Options:
- **[A]** Report every missing variable with cli pluralisation: `"Variable{?s} {.val {missing}} not found..."`. Effort: trivial.
- **[B]** Leave as-is (first-only).

**Recommendation: A**.

---

#### Section: PR 2 / Task 13.1 — step 8 precision

**Issue 20: `collection_meta$surveys` field scope is ambiguous in Task 13.1**
Severity: SUGGESTION

Task 13.1 step 8: "Build `new_meta` with `per_survey` + `collection$surveys` + `collection$survey_classes`." The spec §4.1 comment block says `$surveys` is "character vector of survey names **contributing rows**" — i.e., `names(results)`, not `names(collection@surveys)`. The plan doesn't echo this distinction; an implementer may use `names(collection@surveys)` (which *includes* skipped surveys).

The acceptance criterion at line 826 says `collection$surveys` is test-covered, but the `.on_missing = "skip"` test (Task 14.5) doesn't explicitly assert that a skipped survey is **absent** from `collection$surveys` (only that skipping happened).

Options:
- **[A]** Amend Task 13.1 step 8 to say: "`collection$surveys <- names(results)` (contributing surveys only, excludes skipped)." Add a Task 14.5 assertion: `.on_missing = "skip"` with one skip → `attr(out, ".meta")$collection$surveys` excludes the skipped survey. Effort: trivial.
- **[B]** Leave as-is; spec §4.1 comment is sufficient.

**Recommendation: A**.

---

#### Section: PR 1 / Task 9.1 — `add_survey()` with zero additions

**Issue 21: `add_survey(coll)` with no `...` args is unspecified**
Severity: SUGGESTION

Spec §3.7 says "takes a collection `x` and **one or more** new surveys passed via `...`." Plan Task 9.1 doesn't handle the no-arg case explicitly. `rlang::enquos()` on an empty `...` returns `list()`, the name-resolution loop no-ops, `.repair_collection_names(names(x@surveys))` returns unchanged, the combined list equals the original list, `survey_collection()` validator passes → returns a copy. Silent no-op.

Options:
- **[A]** Error on empty `...` with a dedicated class (new §VI row) or reuse an existing one. Effort: low.
- **[B]** Keep as silent no-op; document as such in roxygen. Effort: trivial.
- **[C]** Silently return `x` unchanged. Already the behavior; just document it.

**Recommendation: B or C**. Erroring doesn't help much — the no-op is harmless. Documenting the behavior in `@details` is sufficient.

---

#### Section: PR 2 / Scope

No further issues.

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 2 |
| SUGGESTION | 3 |

**Total new issues:** 5
**Total open issues (including Pass 1 carryovers):** 21

**Overall assessment:** No new blocking issues in Pass 2 — all four Stage-3-critical items are still the Pass 1 blockers. Pass 2 surfaces two REQUIRED additions (`.id` validation, `bind_rows()` type-mismatch behavior) that lock the helper's input/output contract before implementation, plus three suggestions on error-message precision and metadata scope. Stage 3 priority remains: Pass 1 Issues 1–4 first (unblock implementation), Pass 1 Issues 5–10 next (correctness), then Pass 2 Issues 17–18 (contract sealing), then the remaining suggestions.

---

## Resolution Status — 2026-04-20 (Stage 3)

All 21 issues resolved. See `plans/decisions-survey-collection.md` for the
session decisions log.

| # | Title | Status |
|---|---|---|
| 1 | Source-file paths use nonexistent numbered-prefix filenames | ✅ Resolved (Option A) |
| 2 | `get_pairwise()` file path is wrong | ✅ Resolved (Option A) |
| 3 | C12 guard in `survey_glm()` / `get_anova()` is unreachable | ✅ Resolved (Option A) |
| 4 | Dispatch branch unreachable as described | ✅ Resolved (Option A) |
| 5 | Most target functions have no `...`; placement ambiguous | ✅ Resolved (Option A) |
| 6 | `.precheck_vars_present()` scope — every NSE arg | ✅ Resolved (Option B — table) |
| 7 | Task 13.3 wrong RED/GREEN expectation | ✅ Resolved (Option A) |
| 8 | Task 3.2 contradicts spec validator pseudocode | ✅ Resolved (Option A — collapsed) |
| 9 | Task 11.3 flags unresolved decision to Stage 2 | ✅ Resolved (Option A — `parent=NULL`) |
| 10 | Name-capture logic duplicated | ✅ Resolved (Option A — shared helper) |
| 11 | `.meta` carry-over only in Notes, not Task 13.1 | ✅ Resolved (Option A) |
| 12 | Commit-per-two leaves RED intermediate CI | ✅ Resolved (Option B — single commit) |
| 13 | `covr::file_coverage()` wording confusing | ✅ Resolved (Option A) |
| 14 | Validator tests location diverges from spec §II | ✅ Resolved (Option A; spec §II updated) |
| 15 | Task 1.0 wrong path | ✅ Resolved via Issue 1 sweep |
| 16 | Code-style rule bundled into PR 2 | ✅ Resolved (Option A — PR 2a split) |
| 17 | `.id` input not validated | ✅ Resolved (Option A — new C13) |
| 18 | `bind_rows()` type-mismatch unspecified | ✅ Resolved (Option A — new C14) |
| 19 | `.precheck_vars_present()` reports only first missing | ✅ Resolved (Option A — pluralisation) |
| 20 | `$collection$surveys` scope ambiguous | ✅ Resolved (Option A — names(results)) |
| 21 | `add_survey(coll)` with no `...` unspecified | ✅ Resolved (Option B — document no-op) |
