# Plan Review: get-diffs

## Plan Review: get-diffs — Pass 1 (2026-03-17)

### New Issues

#### Section: PR Map

No issues found.

---

#### Section: PR 1 — Diffs Infrastructure

**Issue 1: `print.survey_diffs()` registration inconsistent with existing pattern**
Severity: REQUIRED
Violates consistency principle from `code-style.md` and existing precedent in `analysis-meta.R`.

Task 6.4 registers `print.survey_diffs` via `registerS3method()` in `R/zzz.R`. But
`survey_diffs` is a plain S3 class (class vector `c("survey_diffs", "survey_result",
"tbl_df", "tbl", "data.frame")`) — NOT an S7 class. The existing `print.survey_result()`
in `R/analysis-meta.R` uses roxygen `@method print survey_result` + `@export`, which
generates `S3method(print, survey_result)` in NAMESPACE. Standard S3 dispatch works.

The `registerS3method()` in `zzz.R` is only needed for S7 namespaced classes (e.g.,
`"surveycore::survey_glm_fit"`) because their class strings contain `::`, making
NAMESPACE `S3method()` directives impossible.

Options:
- **[A]** Use `@method print survey_diffs` + `@export` in roxygen block above the function in `R/analysis-meta.R`, matching the `print.survey_result` pattern. Remove the `zzz.R` registration task (6.4). — Effort: low, Risk: low, Impact: consistency with existing codebase
- **[B]** Keep `registerS3method()` in `zzz.R` as the plan specifies — it works but is unnecessary for S3 classes. — Effort: none, Risk: low, Impact: inconsistent but functional
- **[C] Do nothing** — plan works as-is, but creates a precedent of registering plain S3 methods in `zzz.R`

**Recommendation: [A]** — Matches the existing `print.survey_result()` pattern exactly. `zzz.R` should only contain S7 namespaced registrations.

---

**Issue 2: Dead display name in `print.survey_diffs()` design type map**
Severity: SUGGESTION
Spec coverage: Section VIII.

Task 6.3 lists `"nonprob" → "Non-probability"` in the design type display names. But
`.build_meta()` in `R/analysis-helpers.R` (line 351) maps `survey_nonprob` to
`design_type = "calibrated"`, never `"nonprob"`. The `"nonprob"` entry is dead code.

Options:
- **[A]** Remove `"nonprob"` from the map; keep only `"calibrated" → "Calibrated"`. — Effort: low, Risk: low, Impact: no dead code
- **[B]** Keep both as a defensive measure in case `.build_meta()` changes later. — Effort: none, Risk: low, Impact: dead code stays
- **[C] Do nothing** — harmless dead code but violates over-engineering principle

**Recommendation: [A]** — The map should match what `.build_meta()` actually produces. If the mapping changes later, update the print method at the same time.

---

**Issue 3: 98%+ line coverage missing from PR 1 acceptance criteria**
Severity: REQUIRED
Violates `testing-standards.md` coverage target and spec Quality Gates (Section X).

PR 1 acceptance criteria list specific test assertions but not the overall coverage
requirement. The spec Quality Gates explicitly require "98%+ line coverage on
`analysis-diffs.R` and `analysis-diffs-helpers.R`." PR 1 introduces
`analysis-diffs-helpers.R` — its coverage should be verified.

Options:
- **[A]** Add "98%+ line coverage on `R/analysis-diffs-helpers.R`" to PR 1 acceptance criteria. — Effort: low, Risk: low, Impact: matches project standards
- **[B] Do nothing** — coverage checked at PR 2 when all tests exist. Risk: under-tested helper ships in PR 1.

**Recommendation: [A]** — PR 1 introduces a new source file; its coverage should be verified before merge.

---

#### Section: PR 2 — `get_diffs()` Function

**Issue 4: Tasks B.18 and C.9 are mega-tasks (14+ implementation steps bundled)**
Severity: BLOCKING
Violates implementation-workflow task granularity: "Each task in the plan should be one action (2–5 minutes)."

Task B.18 says: "Implement the clean path in `R/analysis-diffs.R` (spec Sections 3.8, 3.10–3.12, VII Steps 9–22)." That is 14 distinct implementation steps bundled into a single task. `/r-implement` processes tasks one at a time and needs clear "done" criteria for each. Similarly, C.9 bundles the entire marginaleffects path implementation.

This is the most critical issue in the plan. An implementer hitting B.18 would have to implement the entire estimation pipeline, output assembly, rounding, name styling, meta attachment, column labels, and class assignment in one shot — with no checkpoints.

Options:
- **[A]** Split B.18 into ~8 sub-tasks (one per logical step group):
  - B.18a: Call `survey_glm()` and extract estimates via `clean()` (Steps 9–11)
  - B.18b: Compute domain-aware `n` per treatment level (Step 12)
  - B.18c: Apply `pval_adj` for no-group case (Step 13)
  - B.18d: Check link-scale suppression + compute `pct_change` (Steps 14–15)
  - B.18e: Assign stars + assemble output tibble in column order (Steps 16–17)
  - B.18f: Apply `label_values`, decimals rounding, name_style (Steps 17a–19)
  - B.18g: Attach `.meta` via `.make_result_tibble()` (Step 20)
  - B.18h: Attach column-level labels + set S3 class + return (Steps 21–22)
  Split C.9 similarly into ~4 sub-tasks.
  — Effort: medium, Risk: low, Impact: implementable in granular steps
- **[B]** Keep as-is but add inline sub-step comments. — Effort: low, Risk: medium (implementer still has no checkpoints), Impact: slightly clearer
- **[C] Do nothing** — `/r-implement` will struggle with a 14-step task

**Recommendation: [A]** — This matches the workflow's 2–5 minute task granularity. Each sub-task has a clear "done" state (e.g., "survey_glm() called and estimates extracted" vs. "column labels attached").

---

**Issue 5: Three numerical oracle tests from spec missing in plan**
Severity: REQUIRED
Spec coverage gap: Section IX numerical tests.

The spec lists 7 numerical tests; the plan (Phase F) implements only 4. Missing:

1. **Poisson AME vs `survey::svyglm` + `marginaleffects`** — spec row "Poisson AME vs survey::svyglm + marginaleffects"; plan Phase F has no Poisson test.
2. **SRS full covariance matrix verification** — spec row "SRS full covariance matrix verification"; plan has no off-diagonal vcov test.
3. **Replicate domain convergence** — spec row "Replicate domain convergence"; plan has no tight-domain replicate stress test.

Options:
- **[A]** Add F.6 (Poisson AME), F.7 (SRS vcov off-diagonal), F.8 (replicate domain convergence) to Phase F. — Effort: low, Risk: low, Impact: full spec coverage
- **[B]** Defer 2 and 3 (SRS vcov, replicate convergence) since they test Phase 2 infrastructure, not `get_diffs()` itself. Add only Poisson AME. — Effort: low, Risk: low, Impact: most value per effort
- **[C] Do nothing** — 3 spec-required tests are missing

**Recommendation: [A]** — The spec explicitly lists them. Add all three.

---

**Issue 6: Missing test for `pct_change` rounding at `decimals + 2`**
Severity: REQUIRED
Spec coverage gap: Section 3.12.

The spec says: "`pct_change`: round to `decimals + 2` (more precision for proportions)."
No test in the plan verifies this behavior. B.3 tests `show_pct_change = TRUE` but not
with `decimals`. B.8 tests `decimals` but not with `show_pct_change`. The combination is
untested, and the `decimals + 2` rule is a non-obvious implementation detail that needs
explicit coverage.

Options:
- **[A]** Add a test (B.8a or extend B.8): `get_diffs(d, dv, treats, show_pct_change = TRUE, decimals = 2)` — assert `pct_change` is rounded to 4 places, not 2. — Effort: low, Risk: low, Impact: covers a spec requirement that's easy to get wrong
- **[B] Do nothing** — `pct_change` rounding correctness is not verified

**Recommendation: [A]** — The `decimals + 2` rule is non-obvious and needs a test.

---

**Issue 7: 98%+ line coverage missing from PR 2 acceptance criteria**
Severity: REQUIRED
Same as Issue 3 but for PR 2. The spec Quality Gates require "98%+ line coverage on
`analysis-diffs.R`" — PR 2's acceptance criteria don't list this.

Options:
- **[A]** Add "98%+ line coverage on `R/analysis-diffs.R`" to PR 2 acceptance criteria. — Effort: low, Risk: low, Impact: matches project standards
- **[B] Do nothing** — coverage checked implicitly via `devtools::check()` and existing CI

**Recommendation: [A]** — Explicit acceptance criteria prevent ambiguity.

---

**Issue 8: D.3 assertion is vague ("matches nonprob pattern")**
Severity: REQUIRED
Unverifiable acceptance criterion (Lens 3).

Task D.3 says: "Assert: `.meta$design_type` matches nonprob pattern." But `.build_meta()`
maps `survey_nonprob` to `design_type = "calibrated"`, not `"nonprob"`. The assertion
should say: `.meta$design_type == "calibrated"`.

Options:
- **[A]** Change D.3 assertion to: `expect_identical(meta(result)$design_type, "calibrated")`. — Effort: low, Risk: low, Impact: verifiable assertion
- **[B] Do nothing** — implementer will figure it out, but the acceptance criterion is ambiguous

**Recommendation: [A]** — Acceptance criteria must be objectively verifiable.

---

**Issue 9: C.5 (`scale = "link" + non-gaussian`) placed under Phase C but uses clean path**
Severity: SUGGESTION
Task ordering / clarity concern.

Per the routing logic (spec Section 7.2), `scale = "link"` + non-gaussian + no covariates
+ no group uses the **clean path** (not marginaleffects). But C.5 is listed under "Phase C:
Marginaleffects path", which could mislead the implementer into thinking it tests the
marginaleffects code.

C.5 is really testing link-scale suppression behavior (Section 3.2) on the clean path. The
test should verify `.meta$estimate_method == "coefficient"` (clean path), not
`"avg_slopes"`.

Options:
- **[A]** Move C.5 to Phase B (after B.16) and rename to "link-scale suppression on clean path". Add `.meta$estimate_method == "coefficient"` assertion. — Effort: low, Risk: low, Impact: clearer phase organization
- **[B]** Keep in Phase C but add a note that this test exercises the clean path despite being in the marginaleffects section. Add `.meta$estimate_method == "coefficient"` assertion. — Effort: low, Risk: low, Impact: less misleading
- **[C] Do nothing** — implementer may misunderstand which path is tested

**Recommendation: [B]** — Moving across phases is more disruptive than a clarifying note. But the `.meta` assertion must be added regardless.

---

**Issue 10: `match.arg(scale)` not mentioned in any implementation task**
Severity: SUGGESTION
Completeness concern.

The spec (Section 7.2) shows `scale <- match.arg(scale)` but no task in the plan
explicitly mentions this call. It would naturally happen in B.18 (Step 10) but since
the plan describes Steps 9–22 as a single task, the detail is lost.

Options:
- **[A]** If B.18 is split (per Issue 4), include `match.arg(scale)` in the sub-task for Step 10. — Effort: free (comes with the split), Risk: low
- **[B] Do nothing** — `match.arg()` is idiomatic R; the implementer will know to add it

**Recommendation: [A]** — Addressed naturally if Issue 4 is resolved.

---

**Issue 11: `skip_if_not_installed("marginaleffects")` becomes no-op after Imports move**
Severity: SUGGESTION

Phase H moves `marginaleffects` from Suggests to Imports. After this, it's always
installed in `devtools::check()` environments. Tests gated with
`skip_if_not_installed("marginaleffects")` will never skip — they're effectively ungated.
This is harmless but misleading.

Options:
- **[A]** After H.1, remove `skip_if_not_installed("marginaleffects")` from all new test files. Keep `skip_if_not_installed("survey")` (still in Suggests). — Effort: low, Risk: low, Impact: honest test gating
- **[B]** Keep the skips as defensive code. — Effort: none, Risk: low, Impact: misleading but harmless
- **[C] Do nothing** — no functional impact

**Recommendation: [A]** — Test skips should reflect reality. A skip that never fires is confusing.

---

**Issue 12: No explicit test for `@groups` integration**
Severity: SUGGESTION
Spec coverage: Section 3.15.

The spec says `design@groups` (from `group_by()`) are combined with the `group` argument
via `.resolve_groups()`. No test verifies this for `get_diffs()` specifically. The Phase 1
functions have `@groups` tests, and `.resolve_groups()` is tested, but a direct test
provides confidence that the wiring works end-to-end.

Options:
- **[A]** Add a test in Phase D (D.5 or similar), gated with `skip_if_not_installed("surveytidy")`: `group_by(design, group_var) |> get_diffs(dv, treats)`. Assert group column appears in output. — Effort: low, Risk: low, Impact: explicit coverage
- **[B]** Rely on Phase 1 tests + `.resolve_groups()` unit tests. — Effort: none, Risk: low (indirect coverage)
- **[C] Do nothing** — `@groups` integration is indirectly tested

**Recommendation: [A]** — End-to-end integration test is cheap and valuable.

---

**Issue 13: Plan uses `clean(fit, n = TRUE)` but computes `n` separately**
Severity: SUGGESTION
Efficiency / clarity concern.

The plan's Step 11 calls `clean(fit, ..., n = TRUE)` to get `n_obs` per factor level.
Step 12 then separately computes domain-aware `n` per treatment level. If `n_obs` from
`clean()` is not used (because domain-aware counting is needed in all cases), passing
`n = TRUE` wastes computation.

For the clean path without domain estimation, `clean()`'s `n_obs` equals the domain-aware
count (no domain means all rows are in-domain). But the plan should be explicit about which
source of `n` to use in which case.

Options:
- **[A]** Always compute `n` separately (Step 12). Call `clean(fit, n = FALSE)`. Simplifies logic — one `n` computation path for all cases. — Effort: low, Risk: low, Impact: clearer, no wasted computation
- **[B]** Use `clean()`'s `n_obs` for non-domain cases; compute separately only when `..surveycore_domain..` exists. — Effort: low, Risk: low, Impact: matches spec Section 3.8 step 4
- **[C] Do nothing** — minor efficiency issue; implementation will sort it out

**Recommendation: [A]** — One path is simpler than conditional logic. Always computing `n` from `design@data` is the DRY approach.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 5 |
| SUGGESTION | 6 |

**Total issues:** 12

**Overall assessment:** The plan is well-structured with good TDD discipline and correct PR boundaries. The single blocking issue (mega-tasks B.18 and C.9) must be resolved before implementation — `/r-implement` cannot process a 14-step task as one action. The required issues are straightforward fixes: missing numerical tests, a missing rounding test, vague assertion text, and coverage criteria. Once the blocking issue is split and the required issues addressed, the plan is ready to implement.
