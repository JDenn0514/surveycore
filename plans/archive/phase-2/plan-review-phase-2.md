## Plan Review: phase-2 — Pass 1 (2026-03-08)

### New Issues

#### Section: PR Map

No issues found.

---

#### Section: PR 1 — Error table + test helper infrastructure

No issues found in this section alone, but see Issue 1 (cross-cutting count inconsistency).

---

#### Section: PR 2 — `survey_glm_fit` S7 class + `survey_glm()` + variance engine

**Issue 1: Error class count inconsistency within the plan (PR 1 vs. Quality Gates)**
Severity: BLOCKING
Violates engineering-preferences.md §5 (Explicit over clever) and testing-standards.md (every error class gets a test)

PR 1's acceptance criterion states: "All **20** Phase 2 error/warning classes from spec Section X (P2-1 through P2-20)". The Quality Gates section states: "All **16** Phase 2 error/warning classes tested". These are two different numbers in the same document. The implementer cannot reconcile them without re-reading the full spec and counting themselves. Counting unique class names in spec §X yields 20 (18 new + 2 Phase 1 reuses); the spec §XI gate says 16 — which is likely a stale number from an earlier draft. Neither "16" nor "20" is derived explicitly in the plan.

Options:
- **[A]** Resolve to the actual unique class count from spec §X (20 class names, 18 new to `error-messages.md`), update both the PR 1 criterion and the Quality Gates to match, and add a brief note explaining reused classes. — Effort: low, Risk: low, Impact: eliminates ambiguity before any code is written.
- **[B]** Defer to the spec's §XI number (16) and document what's excluded. — Effort: low, Risk: medium, Impact: leaves gap if the 16 is wrong (see Issue 3).
- **[C] Do nothing** — implementer will pick a number, and coverage for 4 error classes will be undetermined.

**Recommendation: [A]** — The cost of counting is minutes; the cost of a missed error class is a failing CI after PR 6.

---

**Issue 2: PR 2 acceptance criterion says "14 error/warning classes from spec §4.7" — §4.7 has 15 rows**
Severity: REQUIRED
Violates testing-standards.md §2 (every error class gets a test)

The criterion states: "All **14** error/warning classes from spec §4.7 are tested". Counting spec §4.7 rows: 1, 2, 2a, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 = **15 rows**. Row 14 is `surveycore_error_cbind_response_unsupported` (P2-20 in Section X). If the implementer stops at 14, this error class has no test — it would pass "All 14" while missing the cbind guard.

Options:
- **[A]** Change "14" to "15" and add an explicit acceptance criterion bullet for `surveycore_error_cbind_response_unsupported`: trigger by calling `survey_glm(d, cbind(y1, y2) ~ x)`. — Effort: low, Risk: low, Impact: ensures cbind guard is tested.
- **[B]** Keep "14" but enumerate all 15 class names explicitly in the acceptance criteria so the count is unambiguous. — Effort: low, Risk: low, Impact: same.
- **[C] Do nothing** — `surveycore_error_cbind_response_unsupported` goes untested; any regression in that guard is invisible.

**Recommendation: [A]** — One extra bullet, one guaranteed test.

---

**Issue 3: `surveycore_warning_insufficient_df` (P2-15) has no test plan in any PR**
Severity: REQUIRED
Violates testing-standards.md §2 (every error class gets a test)

`surveycore_warning_insufficient_df` fires from `survey_glm()` when `degf(design) - (p - 1) ≤ 0` (spec §8.5). It is listed in Section X (P2-15) and therefore counted in the "20" or "16" total, but no PR's acceptance criteria specify:
- how to construct a design where this fires (e.g., a Taylor design with 2 PSUs and a model with 3+ coefficients)
- that the warning fires AND the fit is still returned (df clamped to 1)
- that the clamped df produces finite, non-NaN CI bounds

This is a testable condition, not an impossible one — and the spec is explicit that the clamp produces conservative but valid inference.

Options:
- **[A]** Add a `test_that()` block in PR 2's `test-glm.R` acceptance criteria: construct a `survey_taylor` design with 3 PSUs across 2 strata (giving `degf = 1`) and a model with 3 predictors (needing `degf - 2 = -1`, clamped to 1). Assert `surveycore_warning_insufficient_df` fires and the returned fit passes `test_glm_fit_invariants()`. — Effort: low, Risk: low, Impact: covers a real edge case that appears in small-sample survey data.
- **[B]** Add to Quality Gates only (post-implementation verification). — Effort: low, Risk: medium, Impact: test added after code written; may not be TDD.
- **[C] Do nothing** — df clamping code has no test; incorrect clamping (e.g., returning `NaN` bounds) is invisible.

**Recommendation: [A]** — Add the test block to PR 2 criteria. This is exactly the kind of edge case §2 engineering preferences says to handle explicitly.

---

**Issue 4: `na.action = na.fail` edge case has no test in any PR**
Severity: REQUIRED
Violates testing-standards.md §2 and testing-surveycore.md (edge cases in spec get tests)

Spec §9.4 states: "`survey_glm()` with `na.action = na.fail` and a response or predictor containing `NA` — errors. The error is from base R `na.fail()`, not a typed surveycore error class. Document in the roxygen `@param na.action` that `na.fail` errors propagate from base R without surveycore wrapping."

This is an explicitly called-out edge case. No PR has an acceptance criterion for it. The test is: `expect_error(survey_glm(d_with_na, y ~ x, na.action = na.fail))` (no `class=` since base R fires). Without this test, a regression where surveycore silently swallows the `na.fail` error would be invisible.

Options:
- **[A]** Add a `test_that()` block to PR 2 acceptance criteria: "na.action = na.fail with NA in response — base R error propagates (expect_error() without class=)". Also add roxygen `@param na.action` documentation bullet to PR 2 criteria. — Effort: low, Risk: low, Impact: covers a documented edge case.
- **[B]** Add only the documentation requirement, skip the test. — Effort: low, Risk: medium, Impact: behavior untested.
- **[C] Do nothing** — behavior undocumented and untested.

**Recommendation: [A]** — Both the test and the documentation are called out by the spec.

---

**Issue 5: `R/utils.R` missing from PR 2's Files section**
Severity: REQUIRED
Violates github-strategy.md (file list in plan must be complete)

PR 2's cross-cutting notes explicitly state `.glm_confint()` goes in `R/utils.R` (used in `glm-methods.R` and `glm-clean.R` — two source files, per `code-style.md §4`). But `R/utils.R` does not appear in PR 2's **Files** section. An implementer following TDD on PR 2 would: (1) write tests for `survey_glm()`, (2) look at the Files list to know what to create, and (3) not create/modify `R/utils.R` because it isn't listed. The helper would then be defined in `R/glm.R` and later need to be moved — breaking the TDD sequence for PR 3 and PR 4.

Options:
- **[A]** Add `R/utils.R` to PR 2's Files section with a note: "add `.glm_confint()` internal helper". — Effort: trivial, Risk: none, Impact: implementer knows to add the helper in the right file during PR 2.
- **[B]** Move `.glm_confint()` to `R/glm.R` with a comment that it's called cross-file (acceptable per `code-style.md` only if kept in one file — but it IS used across 2 files, so the rule requires `utils.R`). — Effort: low, Risk: medium, Impact: violates code-style rule explicitly.
- **[C] Do nothing** — implementer puts it in `glm.R`, must move it during PR 3 or PR 4, causing unexpected PR scope expansion.

**Recommendation: [A]** — One line addition to the Files section.

---

#### Section: PR 3 — S3 methods on `survey_glm_fit`

**Issue 6: `predict()` with missing predictor columns edge case missing from PR 3**
Severity: REQUIRED
Violates testing-standards.md §2 (edge cases in spec get tests)

Spec §9.4 states: "predict.survey_glm_fit(): `newdata` with missing predictor columns — should error via standard `stats::predict()` error". This is an explicitly listed edge case. PR 3's acceptance criteria cover 36 numbered test items but do not include this edge case (there is no item for it in spec §9.2 — it only appears in §9.4). Without a test, a regression where `predict()` silently returns wrong-length output for malformed `newdata` is invisible.

Options:
- **[A]** Add an acceptance criterion to PR 3: "`predict(fit, new_data = df_missing_col)` — errors via `stats::predict.glm()`; use `expect_error()` without a `class=` argument since this is a base R error." — Effort: low, Risk: low, Impact: covers the documented edge case.
- **[B]** Move this test to PR 4 or PR 6. — Effort: low, Risk: medium, Impact: delays coverage for a method defined in PR 3.
- **[C] Do nothing** — edge case untested.

**Recommendation: [A]** — Add to PR 3 since that's where `predict.survey_glm_fit()` is implemented.

---

#### Section: PR 4 — `clean()` + `broom::tidy()` shim

No new issues beyond those above.

---

#### Section: PR 5 — marginaleffects extension interface

**Issue 7: PR 6 does not depend on PR 5 — final `devtools::check()` may miss marginaleffects tests**
Severity: SUGGESTION
Violates github-strategy.md (dependency ordering must be accurate)

PR 6 is described as the final quality gate ("all Phase 2 R source complete") but lists `Depends on: PR 4` only. `test-glm-marginaleffects.R` is added in PR 5. If PR 5 and PR 6 are worked on concurrently or PR 5 is merged after PR 6, `devtools::check()` in PR 6 will not include the marginaleffects test file. The Quality Gates require all marginaleffects extension methods to be functional — but PR 6 won't verify this if the file isn't present.

Options:
- **[A]** Change PR 6's dependency to "Depends on: PR 4 and PR 5". Add a note that PRs 5 and 6 may be worked on in parallel but PR 5 must be merged before PR 6's branch is cut from `develop`. — Effort: trivial, Risk: none, Impact: ensures all tests run together in the final check.
- **[B]** Keep current ordering; require merge sequence to be PR 4 → PR 5 → PR 6 without formalizing this in the plan. — Effort: trivial, Risk: medium (easily forgotten), Impact: marginaleffects gate runs ad hoc.
- **[C] Do nothing** — marginaleffects quality gate may not be verified by `devtools::check()` in PR 6.

**Recommendation: [A]** — Trivial fix; removes ambiguity.

---

#### Section: PR 6 — Numerical oracle tests

**Issue 8: Poisson oracle template uses `weights = weight` but `make_survey_data()` generates `wt`**
Severity: REQUIRED
Violates testing-surveycore.md (test data generators must match column naming)

The plan's PR 6 oracle template (inherited from spec §9.1) uses:
```r
d_sc <- as_survey(df, ids = psu, weights = weight, strata = strata)
```
But `make_survey_data()` — as documented in `testing-surveycore.md` — generates columns `psu`, `strata`, `fpc`, `wt`, `y1`, `y2`, `y3`. The column is named `wt`, not `weight`. Running this template as written will error with `surveycore_error_weights_not_found` before a single oracle comparison is made. The same mismatch affects the quasipoisson template.

Options:
- **[A]** Correct both Poisson templates (and the quasipoisson template, which follows the same structure) to use `weights = wt` to match `make_survey_data()` output. — Effort: trivial, Risk: none, Impact: templates run as written.
- **[B]** Change `make_survey_data()` to generate a `weight` column (breaking change). — Effort: medium, Risk: high, Impact: touches 2600+ existing tests.
- **[C] Do nothing** — implementer hits a runtime error, debugs, fixes ad hoc.

**Recommendation: [A]** — Correct the templates in the plan now.

---

#### Section: Cross-Cutting Notes

**Issue 9: Domain oracle test placement conflicts between spec §9.1 and spec §9.2**
Severity: SUGGESTION
Violates DRY (engineering-preferences.md §1) if both specs are followed

Spec §9.1 says: "test-glm-numerical.R includes an oracle comparison of `survey_glm()` on a `surveytidy::filter()` domain..." Spec §9.2 (item 11) says: "**test-glm.R**: Domain estimation oracle — `surveytidy::filter()` domain produces coefficients and SEs matching `survey::svyglm()`..."

The plan resolves this by putting the domain oracle in `test-glm.R` (PR 2 scope). This is a reasonable resolution, but it means `test-glm-numerical.R` (PR 6) does NOT include the domain oracle per spec §9.1. If the implementer follows spec §9.1 literally, they will add a duplicate domain oracle test in PR 6. The plan should explicitly state which file owns the domain oracle test and that it is NOT duplicated in PR 6.

Options:
- **[A]** Add a one-line note to PR 6's Notes section: "Domain estimation oracle lives in `test-glm.R` (added in PR 2, item 11) — do NOT add a duplicate in `test-glm-numerical.R`. This departs from spec §9.1's file assignment but avoids duplication." — Effort: trivial, Risk: none, Impact: prevents accidental duplication.
- **[B]** Move domain oracle from PR 2 to PR 6 to match spec §9.1. Adjust PR 2's item 11 scope accordingly. — Effort: low, Risk: low, Impact: aligns plan with spec §9.1 at the cost of deferring domain oracle coverage to the last PR.
- **[C] Do nothing** — implementer may duplicate the test.

**Recommendation: [A]** — Clarifying note is sufficient; domain oracle in PR 2 is the right call since it tests `survey_glm()` behavior directly.

---

#### Section: Quality Gates

**Issue 10: "Section X" reference in PR 1 is ambiguous**
Severity: SUGGESTION

PR 1's acceptance criterion states: "spec Section X (P2-1 through P2-20)". The spec's section is titled "X. Error Message Table" (Roman numeral X). Using "X" as a plain letter is ambiguous — a reader unfamiliar with the spec might wonder if this refers to the 10th section by count or a section named literally "X". Should read: "spec §X (Error Message Table)" consistently.

Options:
- **[A]** Change "spec Section X" → "spec §X (Error Message Table)" throughout the plan. — Effort: trivial, Risk: none.
- **[C] Do nothing** — minor; unlikely to cause real confusion given the spec is readable.

**Recommendation: [A]** — Trivial.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 5 |
| SUGGESTION | 3 |

**Total issues:** 9

**Overall assessment:** The plan is structurally sound — PR granularity is appropriate, the dependency sequence is correct, and the cross-cutting notes are thorough. Three issues are pre-flight blockers before implementation begins: the internal count inconsistency (BLOCKING) will force the implementer to stop and recount; two missing test requirements (insufficient_df warning and na.action = na.fail) will leave real edge cases uncovered; and the Poisson template column name bug will cause an immediate runtime failure. Resolve Issues 1–8 in Stage 3 before handing off to `/r-implement`.
