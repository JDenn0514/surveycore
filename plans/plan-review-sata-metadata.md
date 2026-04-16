## Plan Review: sata-metadata — Pass 1 (2026-04-16)

### New Issues

#### Section: PR Map

No issues found.

---

#### Section: PR 1 — `sata` Property + Shared Infrastructure

No issues found.

---

#### Section: PR 2 — Migrate `extract_*()` to tidyselect

**Issue 1: Missing 98%+ coverage acceptance criterion**
Severity: REQUIRED
Violates testing-standards.md §2 (98%+ coverage target) and testing-surveycore.md quick reference ("Coverage target: 98%+ line coverage").

The acceptance criteria for PR 2 does not include a line requiring coverage ≥ 98% for new and changed code. The same omission is present in PRs 1, 3, and 4. The testing-standards.md and the spec Quality Gates (Section X) both state this requirement. Without it as an explicit acceptance checkbox, the implementer has no gate to check before opening the PR.

Options:
- **[A]** Add `- [ ] Coverage ≥ 98% for all new/changed code` to each PR's acceptance criteria — Effort: low, Risk: low, Impact: ensures coverage gate is checked before PR is opened
- **[B]** Add only to PRs 3 and 4 where new functions are introduced — Effort: low, Risk: low, Impact: partial coverage
- **[C] Do nothing** — Coverage check is absent from all four PRs; implementer may miss it

**Recommendation: A** — The rule applies to every PR; add to all four.

---

#### Section: PR 3 — `set_sata()` and `extract_sata()`

**Issue 2: `extract_sata()` accepts `fill = TRUE` but implementation does not handle it**
Severity: BLOCKING
Violates engineering-preferences.md §4 (handle edge cases) and spec Section V ("fill must be TRUE, FALSE, or NULL").

The plan's `extract_sata()` implementation in Step 3.5 validates that `fill` is one of `TRUE`, `FALSE`, or `NULL` — accepting `fill = TRUE` as a valid input with no error. However, the result-building code builds all unmarked variables as `FALSE` (via `isTRUE(raw)`) and never flips them to `TRUE` when `fill = TRUE`. The comment in the code acknowledges this: `# fill = TRUE would flip non-SATA to TRUE` — but provides no code to do so. Step 3.2 does not include a test for `fill = TRUE`, and the acceptance criteria has no criterion for it.

An implementer following the plan exactly will ship code that silently returns wrong values: when called with `fill = TRUE`, it returns `FALSE` for unmarked variables instead of `TRUE`. There will be no test failure to surface this because the test is not written.

The spec is also ambiguous here: the argument table only documents `FALSE` and `NULL`, but validation accepts `TRUE`. Either `fill = TRUE` should be removed from the accepted set or its behavior must be specified, implemented, and tested.

Options:
- **[A]** Restrict fill to `FALSE` or `NULL` only — remove `TRUE` from the validation, error if `fill = TRUE` with `surveycore_error_sata_not_logical`, update spec note — Effort: low, Risk: low, Impact: removes an ambiguous edge case; simpler API
- **[B]** Specify, implement, and test `fill = TRUE` behavior (unmarked variables reported as TRUE): add logic `if (isTRUE(fill)) result[!result] <- TRUE` after the `fill = NULL` block; add one test `test_that("extract_sata() fill = TRUE returns TRUE for all vars")`; update acceptance criteria — Effort: low, Risk: low, Impact: completes the implementation
- **[C] Do nothing** — silently broken behavior ships; `fill = TRUE` accepted but returns wrong results

**Recommendation: A** — `fill = TRUE` has no meaningful "show me variables that are NOT SATA" use case that isn't already served by `fill = FALSE`. Restricting to `FALSE`/`NULL` simplifies validation, the argument table, and avoids an untested code path.

**Issue 3: Missing `surveycore_error_not_survey_or_df` tests for `set_sata()` and `extract_sata()`**
Severity: REQUIRED
Violates testing-standards.md §2 (three mandatory test categories, including all error paths).

Both `set_sata()` and `extract_sata()` call `.check_is_survey_or_df(x, call = call)` as their first validation step (per Steps 3.4 and 3.5). This raises `surveycore_error_not_survey_or_df` when `x` is neither a survey object nor a data frame. However, Step 3.2's error path test list includes no block for this error condition for either function. The spec's error tables (Sections IV and V) also omit this condition — it is a spec gap that carried into the plan.

Since the existing class reuses an established error (`surveycore_error_not_survey_or_df`) and `.check_is_survey_or_df()` is already in `R/core-metadata.R`, this is a one-block addition per function. The dual pattern (`expect_error(class=) + expect_snapshot(error=TRUE)`) applies.

Options:
- **[A]** Add two test blocks to Step 3.2 and two lines to the acceptance criteria:
  - `test_that("set_sata() errors when x is not a survey or data frame")`
  - `test_that("snapshot: set_sata() not-survey-or-df error message")`
  - `test_that("extract_sata() errors when x is not a survey or data frame")`
  - `test_that("snapshot: extract_sata() not-survey-or-df error message")`
  Effort: low, Risk: low, Impact: covers all error paths
- **[B]** Add tests only for `set_sata()` — Effort: very low, Risk: low, Impact: leaves `extract_sata()` path untested
- **[C] Do nothing** — `.check_is_survey_or_df()` is called but never tested for these functions; coverage gap

**Recommendation: A** — Both functions call the same guard; both need the same test.

---

#### Section: PR 4 — `classify_question_type()` + `.extract_var_meta()` update

**Issue 4: PR 4 will break an existing test in `test-analysis-helpers.R`**
Severity: REQUIRED
Violates github-strategy.md (PRs must not leave `main` in a broken state; all tests must pass).

`test-analysis-helpers.R` line 779 contains:
```r
expect_identical(
  names(result),
  c("variable_label", "question_preface", "value_labels")
)
```
After Step 4.4 adds `sata` to `.extract_var_meta()`'s return list, this `expect_identical()` will fail because `names(result)` will be `c("variable_label", "question_preface", "value_labels", "sata")`.

The cross-cutting notes mention this ("Scan for uses before marking PR 4 complete") but it is not in PR 4's acceptance criteria as a checkbox. Without an explicit criterion, the implementer may not scan the test file before opening the PR, and CI will fail.

Options:
- **[A]** Add to PR 4 acceptance criteria: `- [ ] `test-analysis-helpers.R` test at line 772 updated to include `sata` key in `names(result)` check` — Effort: very low, Risk: none, Impact: prevents CI failure
- **[B]** Move the cross-cutting note into a Step 4.4b explicitly: "Update `test-analysis-helpers.R` line 779 to include `sata` in the expected names vector" — Effort: low, Risk: none, Impact: even clearer guidance
- **[C] Do nothing** — CI will fail on PR 4; implementer must discover and fix it at PR time

**Recommendation: B** — Promote the note into an explicit step with a concrete line reference. Add the corresponding acceptance criterion checkbox.

**Issue 5: Warning snapshot tests in Step 4.2 are inconsistent with testing-standards.md**
Severity: SUGGESTION
May conflict with testing-standards.md §3 ("warnings use `expect_warning(class = ...)`" — no snapshot required for warnings).

Step 4.2 includes:
```
test_that("snapshot: classify_question_type() sata-no-preface warning")
test_that("snapshot: classify_question_type() mixed-group warning")
```
These are snapshot tests for warning messages. The testing-standards.md defines the dual pattern (`expect_error(class=) + expect_snapshot(error=TRUE)`) for errors only; for warnings, only `expect_warning(class = ...)` is required. These extra snapshot blocks are not harmful, but they add maintenance overhead (snapshot files that must be reviewed and committed).

Options:
- **[A]** Remove the two snapshot blocks; warnings are covered by `expect_warning(class = ...)` per the standard — Effort: very low, Risk: low, Impact: consistent with standards; no extra snapshot maintenance
- **[B]** Keep as-is — these are extra coverage and will catch message text regressions — Effort: none, Risk: snapshot drift is annoying but not blocking
- **[C] Do nothing** — inconsistency is cosmetic; does not affect correctness

**Recommendation: A** — Apply the standard consistently. If warning message text stability is desired, that can be added later as a deliberate extension of the standard rather than an ad-hoc exception here.

---

#### Section: Cross-Cutting Notes

**Issue 6: PR 4 dependency comment is misleading**
Severity: SUGGESTION
Not a rule violation, but will cause confusion during implementation.

PR 4's dependency reads: `Depends on: PR 3 (for sata property to read from)`. The `sata` property is added in PR 1, not PR 3. PR 4 depends on PR 3 because PR 3 provides `set_sata()` — needed in PR 4's tests to mark variables before calling `classify_question_type()`. The current phrasing implies the dependency is on the property itself, which would lead an implementer to incorrectly believe they could skip PR 3 and still build PR 4 (since the property they need is from PR 1).

Options:
- **[A]** Correct to: `Depends on: PR 3 (for set_sata(), needed in tests to mark variables)` — Effort: trivial, Risk: none, Impact: eliminates implementer confusion
- **[B]** Expand to: `Depends on: PR 1 (sata property) and PR 3 (set_sata(), needed in tests)` — Effort: trivial, Risk: none
- **[C] Do nothing** — Technically the ordering still works; developer just needs to understand transitive dependencies

**Recommendation: A** — One clear, accurate sentence.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 3 |
| SUGGESTION | 2 |

**Total issues:** 6

**Overall assessment:** The plan is mostly solid — TDD step-by-step structure is clear, PR granularity is appropriate, and all spec functions have matching PRs. One blocking implementation bug (`fill = TRUE` accepted but not handled) and three required gaps (coverage criterion, missing `not_survey_or_df` tests, and a guaranteed CI failure from the `.extract_var_meta()` names check) must be resolved before implementation begins.
