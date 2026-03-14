## Plan Review: multi-stage — Pass 1 (2026-03-12)

### New Issues

#### Section: PR Map / Overview

---

**Issue 1: Dependency graph contradicts prose**
Severity: REQUIRED
[Violates github-strategy.md dependency ordering; implementer would build in wrong sequence]

The ASCII art dependency graph is ambiguous and the prose description is wrong:

```
PR 1 → PR 2 → PR 3
              PR 4 → PR 5
              PR 6
PR 3 → PR 7
PR 4 → PR 5
```

The indentation implies PR 3 → PR 4 → PR 5, but PR 4 depends on PR 2, not PR 3.
The arrows `PR 2 → PR 4` and `PR 2 → PR 6` are absent from the graph.
`PR 4 → PR 5` appears twice (redundant).

The prose says: "PRs 3, 6, and 7 can run in parallel once PR 2 merges" — but PR 7
explicitly depends on PR 3 (needs multi-column `@variables$fpc` in the design object
to test the snapshot). PR 7 cannot run in parallel with PR 3.

The correct dependency graph is:

```
PR 1 → PR 2 → PR 3 → PR 7
       PR 2 → PR 4 → PR 5
       PR 2 → PR 6
```

Options:
- **[A]** Replace the ASCII art with a clean dot graph and fix the prose statement to
  "PRs 3, 4, and 6 can run in parallel once PR 2 merges; PR 7 must wait for PR 3." —
  Effort: low, Risk: low, Impact: eliminates implementer confusion about parallelism
- **[B] Do nothing** — An implementer who reads each PR's "Depends on:" header will
  get the correct answer, but the graph and prose contradict those headers, introducing
  doubt.

**Recommendation: A** — The graph is referenced in the overview and the Implementation
Notes section; both need to be consistent with the per-PR headers.

---

#### Section: PR 1 — Extend `make_survey_data()`

No issues found.

---

#### Section: PR 2 — Add `.build_cluster_matrices()`

---

**Issue 2: Missing `test_invariants()` in single-stage unit test**
Severity: REQUIRED
[Violates testing-surveycore.md invariant requirement: "`test_invariants(design)` required as **first** assertion in every constructor test block"]

The first unit test in PR 2 calls `as_survey()`:

```r
test_that(".build_cluster_matrices() returns n×1 matrices for single-stage design [unit]", {
  df <- make_survey_data(n = 100, n_psu = 10, seed = 1)
  sc <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
  mats <- .build_cluster_matrices(sc@data, sc@variables)
  ...
```

There is no `test_invariants(sc)` call before the matrix assertions. The other four
unit tests in PR 2 build `vars` as a plain `list` without calling `as_survey()`, so
they are not affected.

Options:
- **[A]** Add `test_invariants(sc)` as the first assertion inside the single-stage test
  block — Effort: low, Risk: none, Impact: satisfies invariant requirement
- **[B] Do nothing** — Violates the testing standard; would be flagged by the
  `test_invariants` discipline check.

**Recommendation: A**

---

#### Section: PR 3 — Update `as_survey()` Multi-Column FPC

---

**Issue 3: Partial FPC level and class — plan contradicts spec v0.3**
Severity: BLOCKING
[Spec is the authoritative document; the plan would implement the wrong diagnostic level and class name]

The plan's PR 3 test for partial FPC:

```r
test_that("as_survey() informs for partial FPC (stage-1 col with 2-stage ids)", {
  ...
  expect_message(
    as_survey(df, ids = c(psu, ssu), weights = wt, strata = strata, fpc = fpc),
    class = "surveycore_inform_fpc_partial_stages"
  )
})
```

The spec (approved v0.3) says:

- §IV table: `cli_warn(class = "surveycore_warning_fpc_partial_stages")`
- §X table: Level = **WARN**, class = `surveycore_warning_fpc_partial_stages`
- §XI edge cases: `expect_warning(class = "surveycore_warning_fpc_partial_stages")`

The plan uses `expect_message()` (catches `cli_inform()`) and `surveycore_inform_fpc_partial_stages`.
These are two incompatible naming / level choices. If the implementer follows the plan's test:
- They will implement `cli_inform()` (wrong level)
- They will use class `surveycore_inform_fpc_partial_stages` (wrong name convention)
- The `error-messages.md` row 89 (which spec §X requires at WARN level) will mismatch the code
- The spec §XI edge case test will fail

Note: the decisions log (methodology review) decided to "keep `cli_inform()`" — but this predates
the spec being finalized at v0.3. The spec v0.3 is the authoritative document and unambiguously
requires `cli_warn()`. The plan was written after the spec was approved and should have used the
spec's class name and level.

Options:
- **[A]** Update the PR 3 test to `expect_warning(class = "surveycore_warning_fpc_partial_stages")`,
  update the plan's implementation step to use `cli_warn()`, and update the `error-messages.md`
  row 89 accordingly — Effort: low, Risk: low, Impact: eliminates conflicting implementation
- **[B]** Revert the spec §IV/X/XI back to `cli_inform()` and `surveycore_inform_fpc_partial_stages`,
  matching the methodology decision — Effort: medium (spec edit + review), Risk: low
- **[C] Do nothing** — The implementer would encounter three contradictory instructions and
  make an arbitrary choice; the resulting code would fail either the spec-based tests or the
  plan-based tests.

**Recommendation: A** — The spec v0.3 is already approved; updating three lines in the plan
is lower effort than reopening the spec. The `warn` level is also more appropriate: the
`survey` package uses `warning()` for this condition (as noted in spec §V partial FPC
semantics), so matching that level improves interoperability expectations.

---

**Issue 4: `fpc_smaller_than_n` test uses a value that cannot trigger the error**
Severity: REQUIRED
[Test exercises the wrong code path; error class would never be thrown for the given input]

The PR 3 test for `surveycore_error_fpc_smaller_than_n`:

```r
test_that("as_survey() rejects stage-2 FPC column smaller than stage-2 cluster count [dual-pattern]", {
  df <- make_survey_data(n = 200, n_psu = 20, n_ssu = 5, seed = 1)
  df$fpc2_bad <- 1L  # 1 SSU in population; but each PSU has 5 sampled SSUs
  expect_error(
    as_survey(df, ids = c(psu, ssu), weights = wt, fpc = c(fpc, fpc2_bad)),
    class = "surveycore_error_fpc_smaller_than_n"
  )
```

The spec §IV FPC type detection rule is: "values > 1 → population size; values in (0, 1] →
sampling fraction." `1L` equals `1.0`, which is `≤ 1`, so it is treated as a **100% sampling
fraction**, not a population size of 1. The `fpc_smaller_than_n` check (rule 4) only applies
to population-size columns (values > 1). With all values = 1, rule 4 is never evaluated.
The test would pass vacuously (the error is never thrown; `expect_error()` on code that
doesn't error fails).

To trigger `surveycore_error_fpc_smaller_than_n`, the FPC column must have values > 1
(population-size interpretation) but smaller than the stage-j sampled cluster count. With
`n_ssu = 5`, each PSU samples 5 SSUs, so a valid trigger is `df$fpc2_bad <- 2L` (population
= 2 SSUs, but 5 SSUs were sampled).

Options:
- **[A]** Replace `df$fpc2_bad <- 1L` with `df$fpc2_bad <- 2L` (or any integer > 1 but < 5)
  and update the comment accordingly — Effort: trivial, Risk: none
- **[B] Do nothing** — The test will fail immediately in CI, wasting a PR cycle.

**Recommendation: A**

---

**Issue 5: `as_survey_replicate()` backward-compat test missing snapshot**
Severity: SUGGESTION
[Violates testing-standards.md dual-pattern requirement for Layer 3 constructor errors]

The PR 3 test:

```r
test_that("as_survey_replicate() still rejects multi-column fpc", {
  ...
  expect_error(
    as_survey_replicate(..., fpc = c(fpc, fpc)),
    class = "surveycore_error_fpc_multiple"
  )
})
```

Per `testing-surveycore.md`, Layer 3 constructor errors require the dual pattern:
`expect_error(class=)` + `expect_snapshot(error=TRUE)`. The snapshot is absent.

Also verify whether this test duplicates an existing one: `surveycore_error_fpc_multiple`
is an existing error class. If a test for it already exists in `test-constructors.R`,
adding a second test creates noise. Check before adding.

Options:
- **[A]** Add `expect_snapshot(error = TRUE, as_survey_replicate(...))` and verify no
  duplicate exists — Effort: low, Risk: none
- **[B]** If a snapshot for this error already exists, remove the duplicate — Effort: low
- **[C] Do nothing** — Single-assertion test doesn't verify message text doesn't regress.

**Recommendation: A** — apply dual pattern; check for duplicate first.

---

#### Section: PR 4 — Refactor `R/variance-taylor.R`

---

**Issue 6: Missing `test_invariants()` in PR 4 tests that call `as_survey()`**
Severity: REQUIRED
[Violates testing-surveycore.md invariant requirement]

Two tests in PR 4 call `as_survey()` without `test_invariants()` as first assertion:

**Regression test:**
```r
test_that(".build_cluster_matrices() produces identical single-stage output [regression]", {
  sc <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtmec2yr,
                  strata = sdmvstra, nest = TRUE)
  est <- get_means(sc, bpxsy1)
  # ← no test_invariants(sc) here
```

**Shape test:**
```r
test_that(".taylor_build_inputs() returns n×2 matrices for 2-stage design [shape]", {
  df <- make_survey_data(n = 300, n_psu = 30, n_ssu = 5, seed = 1)
  sc <- as_survey(df, ids = c(psu, ssu), weights = wt, strata = strata)
  inp <- .taylor_build_inputs(sc, "y1")
  # ← no test_invariants(sc) here
```

Options:
- **[A]** Add `test_invariants(sc)` as first assertion in each block — Effort: trivial
- **[B] Do nothing** — Violates the standard; would be caught by a coverage-gap-finder audit.

**Recommendation: A**

---

**Issue 7: Regression test baseline — pre-refactor vs post-refactor confusion**
Severity: SUGGESTION
[Plan text contradicts itself; an implementer following it literally will encounter confusion]

The Pre-Implementation Step captures NHANES BPXSY1 values from current `develop`
(pre-refactor). PR 4 Step 1 says to write a regression test with those values and
confirms it "should pass" before code changes. PR 4 Step 3 says "regression test...
passes" after the code changes.

But PR 4 Notes say: "SE values may differ from the current oracle" after the refactor
(because sampsize computation changes from post-filter to pre-filter rows). If SE
values change, the test written with pre-refactor values will **fail** in Step 3,
contradicting the plan's "all tests pass" claim.

The Notes also say "The regression test captures the new correct value" — but the
test was written with the old value. This is internally contradictory.

The actual workflow would be:
1. Capture pre-refactor values → write test → test passes (before any code change)
2. Implement refactor
3. If test fails (SE changed), note the new value → update test → confirm it passes

The plan doesn't describe step 3 of this cycle and implies it won't be needed. For
NHANES BPXSY1, the `na.rm` filter likely removes very few rows (BPXSY1 has <5% NA),
so the SE change may be negligible in practice. But the plan should acknowledge the
possibility rather than implying it won't happen.

Options:
- **[A]** Add a conditional note: "If the test fails after the refactor due to SE
  change, capture the new value with `dput()` and update `<recorded_se>`; the new
  value is correct post-refactor." — Effort: trivial
- **[B] Do nothing** — An experienced implementer will figure it out; the Notes section
  partially covers this already.

**Recommendation: A** — One sentence eliminates potential confusion for the implementer.

---

#### Section: PR 5 — Refactor Analysis Helpers + Full Oracle Suite

No new issues. The acceptance criteria reference spec §XI, which itself mandates
`test_invariants(sc)` as first assertion in every oracle block. The one complete
oracle example in the plan already shows `test_invariants(sc)`. Coverage is adequate.

---

#### Section: PR 6 — Refactor `R/glm.R`

---

**Issue 8: Missing `test_invariants(sc)` in GLM oracle test**
Severity: REQUIRED
[Violates testing-surveycore.md invariant requirement]

The PR 6 oracle test:

```r
test_that("survey_glm() matches survey::svyglm() for 2-stage design [oracle]", {
  skip_if_not_installed("survey")
  df <- make_survey_data(n = 500, n_psu = 50, n_ssu = 10, seed = 42)
  sc <- as_survey(df, ids = c(psu, ssu), weights = wt, strata = strata)
  test_glm_fit_invariants(survey_glm(y1 ~ y2, design = sc))  # ← wrong function
  ...
```

`test_glm_fit_invariants()` validates the GLM fit object, not the survey design object.
The testing standard requires `test_invariants(sc)` (the survey design invariant checker)
as the first assertion in every block that creates a survey object via `as_survey()`.
This is missing. Both functions should be called:
1. `test_invariants(sc)` first (design invariants)
2. `test_glm_fit_invariants(survey_glm(...))` second (GLM fit invariants)

Options:
- **[A]** Add `test_invariants(sc)` before the `test_glm_fit_invariants(...)` call —
  Effort: trivial
- **[B] Do nothing** — Violates standard; design invariants go unchecked.

**Recommendation: A**

---

#### Section: PR 7 — Update Print Method

No issues found.

---

#### Section: Quality Gates

---

**Issue 9: Changelog entry path format not specified**
Severity: SUGGESTION
[No rule violation, but creates ambiguity across 7 PRs]

Every PR's acceptance criteria include "Changelog entry written and committed on this
branch" but no PR specifies the path format. For Phase 1, the convention was
`changelog/phase-1/feature-<name>.md`. These multi-stage PRs span Phase 1 and Phase 2
development. Should they use `changelog/multi-stage/feature-<name>.md` or
`changelog/phase-2/feature-<name>.md`?

Options:
- **[A]** Add a single line to the Quality Gates section specifying the path:
  `changelog/multi-stage/feature-<branch-name>.md` — Effort: trivial
- **[B] Do nothing** — The implementer will either ask or infer from existing changelog
  structure.

**Recommendation: A** — One line; prevents 7 PRs from using inconsistent paths.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 5 |
| SUGGESTION | 3 |

**Total issues:** 9

**Overall assessment:** The plan is well-structured and the TDD steps are detailed. One
blocking issue (Issue 3: partial FPC level/class mismatch between plan and approved spec)
must be resolved before implementation begins, as it would cause the implementer to build
the wrong diagnostic behavior. Five required issues are straightforward fixes — mostly
missing `test_invariants()` calls (which the testing standard mandates) and one broken
test value. The dependency graph (Issue 1) contradicts the prose and needs clarification.
After resolving the blocking and required issues, the plan is ready for `/r-implement`.
