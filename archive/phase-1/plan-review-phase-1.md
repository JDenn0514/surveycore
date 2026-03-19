# Plan Review: Phase 1 (v1.1) — Second Adversarial Pass

**Reviewer:** Claude — adversarial review pass
**Date:** 2026-02-25
**Plan file:** `plans/phase-1-implementation-plan.md` (v1.1)
**Spec file:** `plans/phase-1-formal-specification.md` (v1.2)
**Context:** This is the **second** adversarial review of the Phase 1 plan.
The first review (11 issues) was resolved and incorporated into the v1.1 plan
(see decisions log entry "2026-02-25 — Plan Review Resolution").
This review applies all five lenses to the updated plan.

---

## Pre-Review Verification

Before writing any issue, confirmed:

- `survey_nonprob` S7 class and `as_survey_nonprob()` constructor:
  **already implemented** (`R/00-s7-classes.R:768`, `R/03-constructors.R:1084`).
  NOT a blocker.
- `.resolve_tidy_select()`: **already implemented** in `R/07-utils.R:77`.
  NOT a blocker.

---

## Section: PR Map

No issues found. The four-PR dependency diagram is correctly structured:
PR 1 → PRs 2–5 (parallelizable after PR 1 merges). Dependency labels are accurate.

---

## Section: PR 1 — `feature/phase1-meta-helpers`

**Issue 1: `surveycore_error_unsupported_class` absent from `plans/error-messages.md` and from PR 1 file table**
Severity: REQUIRED
Violates `code-style.md §3`: "`class=` is **required on every `cli_abort()` call** — no exceptions"; and the per-PR quality gate: "`plans/error-messages.md` updated if any new error/warning classes added."

The plan defines two functions that throw `surveycore_error_unsupported_class`:

1. `.check_unsupported_class()` (plan §PR1 item 8):
   ```r
   class = "surveycore_error_unsupported_class"
   ```
2. `.build_meta()` fallback (plan §PR1 item 5):
   ```r
   class = "surveycore_error_unsupported_class"
   ```

Neither instance of `surveycore_error_unsupported_class` appears anywhere in
`plans/error-messages.md`. The coverage map entry for `test-analysis-helpers.R`
(rows 45, 45a, 46) does not include this class. PR 1's file table lists no
update to `plans/error-messages.md`.

Consequences if unresolved:
- The per-PR quality gate "error-messages.md updated" fails for PR 1
- An implementor writing `expect_error(class = "surveycore_error_unsupported_class")`
  has no authoritative class name to verify against
- The Phase 1 complete quality gate
  "`.build_meta()` fallback throws `surveycore_error_unsupported_class`, not `"unknown"`"
  tests a class not in the canonical table

Options:
- **[A]** Add `surveycore_error_unsupported_class` as row 64 in `plans/error-messages.md`
  (two rows: one for `.check_unsupported_class()`, one for `.build_meta()` fallback),
  add `plans/error-messages.md | Update` to PR 1 file table, and add the class to
  the `test-analysis-helpers.R` coverage map row.
  Effort: low, Risk: low, Impact: closes quality gate gap.
- **[B]** Argue that the class is implicitly defined by the plan and the
  error-messages.md update can happen in PR 2 (first function PR).
  Effort: none, Risk: high (PR 1 CI passes but first PR after merge fails
  the quality gate check).
- **[C] Do nothing** — Quality gate for PR 1 fails; implementor makes an
  ad-hoc decision on class name.

**Recommendation: A** — Five-minute fix; prevents a quality gate violation on the
very first Phase 1 PR.

---

**Issue 2: `.check_unsupported_class()` not explicitly in PR 1 test categories**
Severity: REQUIRED
Violates `testing-standards.md §2.2`: "Every error class gets a test"; `engineering-preferences.md §2`: "more tests is better."

PR 1 test category 5 (`test-analysis-helpers.R`) covers `.build_meta()` fallback
("fallback to `cli_abort()` for unrecognized class") but does NOT include a test
for `.check_unsupported_class()` as a separate unit. The test categories listed are:

> 1. `.validate_shared_args()` — all three errors
> 5. `.build_meta()` — all five design types; fallback to cli_abort
> (no category for `.check_unsupported_class()`)

`.check_unsupported_class()` has its own `cli_abort()` call with a distinct
message template. Since it throws `surveycore_error_unsupported_class` from a
different code path than `.build_meta()`, it requires its own test block.
The per-function test files cover this error via category 10 ("every row in the
error table"), but only after PR 1 ships the helper. The PR 1 test file is the
correct place for a direct unit test of this helper.

Options:
- **[A]** Add a category 9 to PR 1's `test-analysis-helpers.R` list:
  "`.check_unsupported_class()` — throws `surveycore_error_unsupported_class`
  when passed a non-`survey_base` object (e.g., a plain data frame); returns
  invisibly (no error) for all five supported design classes."
  Effort: low, Risk: low, Impact: direct coverage of the helper.
- **[B]** Rely on per-function tests (PRs 2–5) to cover this via category 10.
  Effort: none, Risk: medium (if PR 1 ships a bug in the helper, it is caught
  only after 4 more PRs depend on it).
- **[C] Do nothing** — Low-priority gap; CI coverage requirement catches it.

**Recommendation: A** — Shared helpers that ship in their own PR should have
inline tests. Category 10 in per-function PRs is too indirect for a helper used
by every single analysis function.

---

**Issue 3: Test category 8 (`meta()` contract) omits function-specific fields `mode`, `method`, `probs`**
Severity: REQUIRED
Violates spec §2.4 (the `meta()` contract) and `testing-standards.md §2.2`
("every behavior in the spec gets a test").

The plan's test category 8 says "all fields present and correctly populated"
and enumerates:

> `design_type`, `conf_level`, `call`, `group_names`, `group_labels`,
> `variable`/`variables`, `variable_label`/`variable_labels`,
> `question_preface`/`question_prefaces`, `value_labels`

Three spec-defined meta fields are absent from this list:

| Field | Function | Spec reference | Expected value |
|---|---|---|---|
| `mode` | `get_freqs()` | Spec §2.4 | `"single"` (1-var) or `"multi"` (2+ vars) |
| `method` | `get_corr()` | Spec §2.4, §6.5 | Always `"pearson"` in Phase 1 |
| `probs` | `get_quantiles()` | Spec §2.4, §7.2 | The input `probs` numeric vector |

An implementor reading only the plan's test category description would not write
tests for these three fields. Per `engineering-preferences.md §2`: "Every edge
case in the spec gets a test."

Options:
- **[A]** Add function-specific addenda to category 8 in the per-function test
  sections (PR 2 for `mode`, PR 4 for `method`, PR 5 for `probs`). Enumerate
  each field and its expected value explicitly.
  Effort: low, Risk: low, Impact: closes the spec-to-test gap.
- **[B]** Leave category 8 as vague ("all fields") and rely on the
  implementor to read spec §2.4 in full.
  Effort: none, Risk: medium (implementors may not cross-reference; these
  fields are absent from the plan's invariant description).
- **[C] Do nothing** — "All fields" language is technically sufficient.

**Recommendation: A** — The plan's test category descriptions are the implementor's
primary reference during implementation. Vague wording with an incomplete list
creates an implementation trap.

---

## Section: PR 2 — `feature/phase1-freqs`

No issues found. All 12 spec test categories are addressed. `na.rm` edge cases,
`min_cell_n`, NA-in-group, `deff`, and `n_weighted` are all explicitly called out.

---

## Section: PR 3 — `feature/phase1-means-totals`

No issues found. The stub removal atomicity requirement is clearly stated. The
oracle expansion for `ci_low`/`ci_high` with correct tolerances is specified.
The `survey::SE()` matrix return note is a useful implementation warning.

---

## Section: PR 4 — `feature/phase1-corr`

No issues found. Fisher Z bypass mechanism is correctly specified. The `.vcov_mean()`
vendoring note and VENDORED.md update requirement are both present. The oracle
computation against `survey::svyvar()` is fully specified with tolerances.

---

## Section: PR 5 — `feature/phase1-quantiles-ratios`

**Issue 4: `R/13-analysis-quantiles.R` contains `get_ratios()` — file name is misleading**
Severity: SUGGESTION
The file name `13-analysis-quantiles.R` does not reflect that it also contains
`get_ratios()`. A developer looking for `get_ratios()` will not find it by
scanning file names.

Ratios use the delta method; quantiles use Woodruff's linearization. These are
statistically distinct methods with no shared internal helpers. The co-location
in the spec appears to be incidental rather than motivated by shared machinery.

Options:
- **[A]** Split into `R/13-analysis-quantiles.R` and `R/14-analysis-ratios.R`,
  with PR 5 split into PR 5a (quantiles) and PR 5b (ratios). One PR per function,
  consistent with `github-strategy.md` "one PR per logical unit of work."
  Effort: low (spec change required), Risk: low, Impact: clearer layout.
- **[B]** Keep co-location but rename the file to `R/13-analysis-quantiles-ratios.R`
  everywhere it appears in spec, plan, and file organization summary.
  Effort: minimal, Risk: low, Impact: reduces future confusion.
- **[C] Do nothing** — Follow spec as written; both functions live in
  `R/13-analysis-quantiles.R`.

**Recommendation: B** — Minimal change, immediate clarity improvement, no PR
restructuring required.

---

## Section: Cross-Cutting Implementation Details

**Issue 5: `.degf()` has no fallback `else` clause — silently returns `NULL` for unrecognized classes**
Severity: REQUIRED
Violates `engineering-preferences.md §4`: "Handle more edge cases, not fewer";
`engineering-preferences.md §5`: "Explicit over clever."

The plan's `.degf()` implementation has five `if/else if` branches (taylor,
replicate, twophase, srs, calibrated) and no final `else`:

```r
.degf <- function(design) {
  if (S7::S7_inherits(design, survey_taylor)) {
    ...
  } else if (S7::S7_inherits(design, survey_replicate)) {
    ...
  } else if (S7::S7_inherits(design, survey_srs)) {
    ...
  } else if (S7::S7_inherits(design, survey_nonprob)) {
    nrow(design@data) - 1L
  }
  # ← No else clause: returns NULL silently for any other class
}
```

If a design class reaches `.degf()` that matches none of the branches, the
function returns `NULL`. This propagates silently into:
```r
qt((1 + conf_level) / 2, df = NULL)  # → Inf (normal approximation)
```
producing CI bounds that are systematically too narrow without any warning.

`.check_unsupported_class()` catches non-`survey_base` objects at the entry of
each `get_*()` function. But a class that *inherits from* `survey_base` but isn't
one of the five supported classes (e.g., a future `survey_doubly_robust` subclass)
would pass `.check_unsupported_class()` and reach `.degf()` undetected.

This is inconsistent with `.build_meta()`'s fallback, which explicitly throws
`surveycore_error_unsupported_class` for unrecognized classes.

Options:
- **[A]** Add a final `else` clause to `.degf()` throwing `surveycore_error_unsupported_class`:
  ```r
  } else {
    cli::cli_abort(
      c("x" = "Cannot compute degrees of freedom for {.cls {class(design)[1]}}."),
      class = "surveycore_error_unsupported_class"
    )
  }
  ```
  Also add a test in `test-analysis-helpers.R` category 8: "`.degf()` — unrecognized
  class throws `surveycore_error_unsupported_class`."
  Effort: low, Risk: low, Impact: fail-fast instead of silent wrong CI output.
- **[B]** Document that `.degf()` returns `NULL` for unknown classes and require
  callers to check. Risk: high — callers would need NULL handling everywhere.
- **[C] Do nothing** — Risk: silently incorrect CI bounds for any novel survey
  subclass added in a later phase.

**Recommendation: A** — Three-line fix. Fail-fast is always better than silent
wrong output. `.build_meta()` already sets this precedent.

---

## Section: Quality Gates

No issues found. The per-PR gate list is comprehensive. The Phase 1 complete
checklist correctly includes all decisions from the 2026-02-25 Stage 3 resolution.
Numerical tolerances are stated. Coverage threshold (98%/95%) is explicit.

---

## Section: File Organization Summary

**Issue 6: `tibble (>= 1.3.0)` version floor is too conservative**
Severity: SUGGESTION

The plan specifies adding `tibble (>= 1.3.0)` to `DESCRIPTION Imports`. Version
1.3.0 is from May 2017. The plan's `.make_result_tibble()` uses:

```r
tibble::as_tibble(c(as.list(groups_df), col_vecs))
```

The `as_tibble(c(as.list(df), list))` pattern requires tibble ≥ 3.0.0 (released
2021), which introduced the column-from-named-list constructor. Setting the floor
to `1.3.0` allows a broken installation on old tibble versions that `devtools::check()`
would not catch at build time.

Options:
- **[A]** Set `tibble (>= 3.0.0)`. All currently supported R versions (≥ 4.1.0)
  ship tibble ≥ 3.x via the tidyverse dependency chain. Effort: minimal.
- **[B]** Set `tibble (>= 2.0.0)` — released 2019. Probably sufficient but
  a less principled floor.
- **[C] Do nothing** — `1.3.0` is wrong but unlikely to bite in practice.

**Recommendation: A** — Correct the floor to `3.0.0`.

---

**Issue 7: Fisher Z `se_z = se_r` comment is misleading; test for CI accuracy at extreme correlations is absent**
Severity: SUGGESTION

The plan's Fisher Z CI formula (PR 4):

```r
z_se    <- se_r   # SE of r on the Fisher Z scale ≈ SE of r (approx)
```

The comment `≈ SE of r (approx)` implies this is a rough approximation. In fact,
`se_z = se_r` IS the conventional Fisher Z formula (from the asymptotic distribution
of `atanh(r)` under normality, where `Var(atanh(r)) ≈ 1/(n-3)` in the SRS case;
in the complex-design case, it comes from the delta method propagated through
the survey variance-covariance approach). Using the exact delta method for `atanh`
would give `se_z = se_r / (1 - r²)`, which diverges from `se_r` as `|r| → 1`.

The Phase 1 complete quality gate says: "Fisher Z CI bounds bounded to (−1, 1)
for extreme correlations (|r| > 0.9)" — but this test only checks bounding, not
whether CI *width* is correct at extreme values. If `se_r` is used as `se_z`, CI
widths for `|r| > 0.9` will be too narrow compared to the oracle.

Options:
- **[A]** Use the exact delta method: `se_z = se_r / (1 - r²)`. Update comment.
  Add a test asserting CI width at `|r| > 0.9` matches `survey::svyvar()` oracle
  within `1e-6`. Effort: low, Risk: low, Impact: statistically correct CIs.
- **[B]** Keep `se_z = se_r` (the standard Fisher Z convention, matching `cor.test()`
  behavior). Replace comment with: `# Fisher Z variance: asymptotic SE of atanh(r);
  matches cor.test() and standard survey software.` Add a note that CI accuracy
  for |r| > 0.9 is approximate. Effort: minimal.
- **[C] Do nothing** — Matches `cor.test()` convention; most users won't notice
  for practical correlation ranges.

**Recommendation: B** — Clarify the comment so the implementor understands this is
a deliberate choice (matching `cor.test()`), not a sloppy approximation. Whether A
or B is chosen, add the CI-width test for extreme correlations.

---

## Summary

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 3 |
| SUGGESTION | 4 |

**Total issues:** 7

**Overall assessment:** The plan is nearly implementation-ready. The required issues
are all small: a missing error-class table entry (Issue 1), a missing test
specification for `.check_unsupported_class()` (Issue 2), three missing meta-field
test requirements (Issue 3), and a missing `else` clause in `.degf()` (Issue 5).
None requires significant architectural change. The suggestions (Issues 4, 6, 7)
are polish items worth addressing before implementation starts. After resolving the
three required issues, this plan is approved.
