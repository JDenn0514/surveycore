## Plan Review: metadata-update — Pass 1 (2026-03-11)

### New Issues

---

#### Section: PR Map / Cross-PR Dependencies

---

**Issue 1: Round-trip tests written in PR 3 depend on PR 4's updated extractor API — they cannot pass at PR 3 merge time**
Severity: BLOCKING
Violates github-strategy.md: all PRs must pass CI (which requires all tests to pass) before merging to develop.

PR 3 Step 3.2 lists six round-trip test blocks:
```
test_that("round-trip: set_var_label() on df -> as_survey() -> extract_var_label() matches")
... (one per field)
```
These tests call `extract_var_label(svy, age)` and compare against the new return type
(`c(age = "Age in years")` — a named vector). But the updated extractor is implemented
only in PR 4. At PR 3 merge time, the OLD `extract_var_label()` returns `"Age in years"`
(a plain scalar). The assertion `expect_equal(extract_var_label(svy, age), c(age = "Age in years"))`
fails because `identical(c(age = "Age in years"), "Age in years")` is `FALSE`.

PR 4's Notes confirm this: "these round-trip tests were already added in PR 3 step 3.2.
The extractors in PR 4 are needed for them to pass." But PR 3's Step 3.16 says
"Run `devtools::test()` (full suite) → no regressions" — a quality gate that is
impossible to satisfy if the round-trip tests are failing.

Options:
- **[A]** Move the six round-trip test blocks from PR 3 Step 3.2 to PR 4 Step 4.1. They belong in the same PR as the extractor implementation they depend on. PR 3 retains all setter-only tests; PR 4 gets all extractor tests including the round-trip verification. — Effort: low, Risk: low, Impact: PRs are independently mergeable
- **[B]** Keep round-trip tests in PR 3 but write them against the OLD extractor API (returning a plain scalar). Then update them in PR 4 to match the new named-vector return. — Effort: medium, Risk: medium (two-pass test rewrite is error-prone and confusing)
- **[C] Do nothing** — PR 3 cannot pass CI; implementer is blocked and must guess.

**Recommendation: [A]** — the round-trip guarantee requires both the setter (PR 3) and the
extractor (PR 4) to be implemented; the test belongs in the PR that completes the pair.

---

#### Section: All PRs — File Completeness

---

**Issue 2: Changelog entries and NEWS.md breaking changes missing from all four PR file lists and acceptance criteria**
Severity: REQUIRED
Violates stage-2-review.md: "Changelog entry written and committed on this branch" is a required standard acceptance criterion for every PR. Violates spec Section 8.3: "NEWS.md entry: The following breaking changes must be documented in a `### Breaking Changes` section of NEWS.md."

No PR's file list includes a `changelog/*/feature-*.md` file. No PR's acceptance criteria
includes "changelog entry written and committed." The "Quality Gates (All PRs)" footer
mentions `devtools::check()`, `air::format_package()`, and snapshot review — but not
changelog or NEWS.md.

Spec Section 8.3 explicitly requires a NEWS.md `### Breaking Changes` entry covering:
1. Old positional setter form `set_var_label(svy, age, "label")` removed.
2. `extract_var_label()` and scalar extractors now return named vector, not scalar.
3. `extract_val_labels()` now returns named list, not bare named vector.

The quality gates (Section XI) also list "NEWS.md includes a `### Breaking Changes` entry"
but this does not appear in any individual PR's acceptance criteria.

Options:
- **[A]** Add `changelog/metadata-update/feature-{branch-name}.md` to each PR's Files
  section. Add "changelog entry written and committed on this branch" to each PR's
  acceptance criteria. Add a step to PR 4 (the final PR) to update NEWS.md with the
  breaking changes from spec Section 8.3. — Effort: low, Risk: none
- **[C] Do nothing** — breaking changes silently undocumented; CI may pass but release
  notes are missing.

**Recommendation: [A]**

---

#### Section: PR 2 — Internal Helper Infrastructure

---

**Issue 3: `.resolve_vars()` has no direct tests in PR 2 — the helper will be untested at PR 2 merge time**
Severity: REQUIRED
Violates testing-standards.md §2: "When unsure whether an edge case needs a test, write the test." Violates engineering-preferences.md §2: "more tests is better."

PR 2 Steps 2.1 and 2.2 write direct unit tests for two of the seven new helpers:
`.check_is_survey_or_df()` and `.parse_setter_input()`. The other five — `.get_data_cols()`,
`.get_metadata()`, `.resolve_vars()`, `.format_scalar_result()`, `.format_list_result()` —
have no direct tests in PR 2. They are tested only indirectly when PR 4's extractor tests
run.

`.resolve_vars()` is particularly complex and high-impact:
- Empty `var_exprs` → returns all column names (default behavior for all extractors)
- Missing variable name → issues `surveycore_warning_var_not_found` and skips
- Mixed bare names + character vectors → resolves to correct string vector

These behaviors drive the behavior of all six extractors. A bug in `.resolve_vars()`
will manifest as broken extractors in PR 4, but there will be no PR 2 test to pinpoint
the root cause.

Options:
- **[A]** Add a `# ── .resolve_vars() ────` section in PR 2 Step 2.2 with direct test
  blocks:
  ```
  test_that(".resolve_vars() with empty var_exprs returns all column names")
  test_that(".resolve_vars() with specified names returns just those names")
  test_that(".resolve_vars() warns with surveycore_warning_var_not_found for missing var")
  test_that(".resolve_vars() returns only valid names after warning")
  test_that("snapshot: .resolve_vars() surveycore_warning_var_not_found message")
  ```
  Update PR 2 acceptance criteria to include "`.resolve_vars()` test blocks pass."
  — Effort: low, Risk: none
- **[B]** Move `.resolve_vars()` tests entirely to PR 4's Step 4.1, accepting the gap in
  PR 2. — Effort: trivial, Risk: medium (helpers untested at PR 2 merge; bug discovery
  deferred to PR 4 implementation)
- **[C] Do nothing** — `.resolve_vars()` is tested only indirectly; a PR 2 bug in default-
  all-variables behavior could go undetected until PR 4's test failures are investigated.

**Recommendation: [A]** — `.resolve_vars()` is the backbone of all extractor behavior;
its behavioral contracts must be verified at the PR where it is introduced.

---

**Issue 4: `lifecycle` in Imports stated as an assumption, not a verification step — if wrong, error surfaces only at PR 3**
Severity: REQUIRED
Violates contract completeness; the spec (Section 8.4) says "lifecycle must be added to
`Imports` in `DESCRIPTION` if not already present."

PR 1 Notes say: "lifecycle is already in Imports — no DESCRIPTION change needed." This
is stated as a fact. No step in PR 1 verifies this (e.g., no `grep lifecycle DESCRIPTION`
step). The deprecated functions using `lifecycle::deprecate_soft()` are first added in
PR 3 Steps 3.13. If lifecycle is not in Imports, `devtools::check()` at PR 3 Step 3.17
will fail with "package 'lifecycle' is required but not imported" — with no guidance in
the plan about what to fix or where.

Options:
- **[A]** Change PR 1 Step 1.1 or PR 1 Notes to: "Verify lifecycle is in Imports:
  `grep 'lifecycle' DESCRIPTION`. If missing, add `lifecycle (>= 1.0.0)` to `Imports`
  in `DESCRIPTION` and update the DESCRIPTION Files entry for this PR." Add
  `DESCRIPTION` (conditional) to PR 1 Files section. — Effort: trivial, Risk: none
- **[C] Do nothing** — implementer hits an opaque check failure at PR 3; no hint in
  the plan about the root cause.

**Recommendation: [A]**

---

**Issue 5: 98%+ line coverage criterion absent from PR 1, PR 2, and PR 3 acceptance criteria**
Severity: REQUIRED
Violates testing-standards.md §2: "PRs that drop coverage below 95% are blocked by CI."
The plan specifies coverage only in PR 4's acceptance criteria (`covr::package_coverage() ≥ 98%`).

Each PR that adds new code can drop coverage if its tests don't cover all paths. PRs 1-3
introduce new code paths (S7 properties, seven internal helpers, six setters + deprecations)
without coverage gates. An uncovered branch in PR 2's `.parse_setter_input()` will not
be caught until PR 4's coverage check — by which point the gap is harder to trace.

Options:
- **[A]** Add `covr::package_coverage() ≥ 98%` to the acceptance criteria of PRs 1, 2,
  and 3 (same criterion already in PR 4). — Effort: trivial, Risk: none
- **[B]** Add only PR 3 (the largest PR with the most new code paths). — Effort: trivial,
  Risk: low (small PRs 1 and 2 are less likely to introduce coverage gaps)
- **[C] Do nothing** — coverage gaps can accumulate across PRs 1-3 and only surface at
  the end of PR 4.

**Recommendation: [A]** — coverage is a per-PR gate, not a final-PR gate.

---

**Issue 6: `devtools::document()` missing from PR 2 and PR 3 acceptance criteria**
Severity: REQUIRED
Violates r-package-conventions.md: "Run `devtools::document()` before committing any
file that changes roxygen2 content." Violates the stage-2-review.md required standard
criterion: "`devtools::document()` run; NAMESPACE and man/ in sync."

PR 1 acceptance criteria correctly includes "`devtools::document()` run; NAMESPACE and
`man/survey_metadata.Rd` in sync." But:

- PR 2 acceptance criteria: no `devtools::document()` criterion. (PR 2 adds only
  internal helpers with `@keywords internal @noRd` — no NAMESPACE or .Rd changes.
  The step mentions it but the acceptance criterion does not.)
- PR 3 acceptance criteria: no `devtools::document()` criterion. PR 3 adds or updates
  six exported functions (`set_var_label`, `set_val_labels`, `set_question_preface`,
  `set_var_note`, `set_universe`, `set_missing_codes`) with full roxygen2 blocks.
  NAMESPACE and six .Rd files change. This is the most critical PR for documentation
  and the criterion is missing.
- PR 4 acceptance criteria: no `devtools::document()` criterion. PR 4 adds
  `extract_universe()`, `extract_missing_codes()`, `extract_metadata()` (all exported).

Options:
- **[A]** Add "`devtools::document()` run; NAMESPACE and `man/` files in sync" to PR 2,
  PR 3, and PR 4 acceptance criteria. For PR 2, note that no .Rd changes are expected.
  — Effort: trivial, Risk: none
- **[C] Do nothing** — PR 3 ships with stale NAMESPACE or man/ files; CI may pass but
  the published package is wrong.

**Recommendation: [A]**

---

#### Section: Suggestions

---

**Issue 7: `air::format_package()` absent from individual PR acceptance criteria**
Severity: SUGGESTION
Violates code-style.md §5: "Run `air::format_package()` before opening a PR."

The "Quality Gates (All PRs)" footer at the end of the plan mentions `air::format_package()
— no diffs`. However, it does not appear in any individual PR's acceptance criteria.
Under time pressure an implementer who reads only the per-PR section might skip formatting.

Options:
- **[A]** Add "`air::format_package()` — no diffs" to each PR's acceptance criteria.
  — Effort: trivial
- **[C] Do nothing** — formatter is mentioned in the global quality gates; risk is low
  but nonzero.

**Recommendation: [A]**

---

**Issue 8: PR 3 bundles function replacements, new functions, deprecations, and helper cleanup — the scope is very large**
Severity: SUGGESTION
Violates github-strategy.md PR granularity guidance: "The right PR is the smallest
coherent unit of work."

PR 3 contains:
- Replacement of 4 existing setters (`set_var_label`, `set_val_labels`,
  `set_question_preface`, `set_var_note`) — breaking API changes
- 2 brand-new setters (`set_universe`, `set_missing_codes`) — new functionality
- 4 deprecated-function wrappers
- `.extract_haven_metadata()` update
- `.check_is_survey()` removal
- Adding `make_labeled_design()` test helper
- 100+ new test blocks

`set_universe()` and `set_missing_codes()` are genuinely new functions (no replacement
involved). They could form a separate `feature/metadata-new-setters` PR after PR 3's
replacements are merged, reducing the review surface of the largest PR in the plan.

Options:
- **[A]** Split PR 3 into PR 3a (replacements of 4 existing setters + deprecations +
  helper cleanup) and PR 3b (new `set_universe()` + `set_missing_codes()` functions).
  PR 4 depends on both 3a and 3b. — Effort: low, Risk: low, Impact: smaller, reviewable
  PRs; .extract_haven_metadata() update goes in 3b (it only adds universe/missing_codes)
- **[C] Do nothing** — large but not technically wrong; implementation is sequential
  so scope can be managed with the step-by-step task list.

**Recommendation: [C] acceptable** — the step-by-step tasks in PR 3 are well-sequenced
and the shared `.parse_setter_input()` infrastructure makes per-function splitting
awkward. This is a quality-of-life suggestion only.

---

**Issue 9: No direct tests for `.format_scalar_result()` and `.format_list_result()` in PR 2**
Severity: SUGGESTION

PR 2 writes direct tests for `.check_is_survey_or_df()` and `.parse_setter_input()` but
not for `.format_scalar_result()` or `.format_list_result()`. Both helpers contain
non-trivial logic:
- `.format_scalar_result()`: three output format branches, `fill` filtering logic
- `.format_list_result()`: two output format branches, `surveycore_error_format_invalid`
  error path

These are tested only indirectly through PR 4's extractor tests. If a format
branch in either helper has a bug, it won't have a direct test to isolate it.

Options:
- **[A]** Add a small `# ── .format_scalar_result() ────` section in PR 2 Step 2.2
  with 3-4 direct unit tests (one per format, one for empty result). Similarly for
  `.format_list_result()`. — Effort: low
- **[C] Do nothing** — indirectly tested via PR 4 extractors; risk is low since the
  helpers are simple wrappers.

**Recommendation: [A]** — direct tests make debugging faster if an extractor test fails.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 5 |
| SUGGESTION | 3 |

**Total issues:** 9

**Overall assessment:** The plan is well-structured with clear TDD task ordering, correct
dependency sequencing, and comprehensive test coverage in PRs 3 and 4. One blocking issue
must be resolved before implementation: the six round-trip tests in PR 3 depend on PR 4's
updated extractor API signatures and cannot pass at PR 3 merge time — moving them to PR 4
is the fix. Five required issues address missing acceptance criteria (coverage gates,
document criterion, changelog/NEWS.md) and one verification gap (lifecycle in Imports).
Resolving these leaves the plan fully implementable.

---

## Plan Review: metadata-update — Pass 2 (2026-03-11)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | Round-trip tests in PR 3 depend on PR 4's extractor API — cannot pass at PR 3 CI | ✅ Resolved |
| 2 | Changelog entries and NEWS.md missing from all four PRs | ✅ Resolved |
| 3 | `.resolve_vars()` has no direct tests in PR 2 | ✅ Resolved |
| 4 | `lifecycle` in Imports not verified, only assumed | ✅ Resolved |
| 5 | 98%+ coverage criterion absent from PRs 1–3 | ✅ Resolved |
| 6 | `devtools::document()` missing from PR 2 and PR 3 acceptance criteria | ✅ Resolved |
| 7 | `air::format_package()` absent from per-PR acceptance criteria | ✅ Resolved |
| 8 | PR 3 scope very large — split suggestion | ⚠️ Still open ([C] was recommendation; unchanged) |
| 9 | No direct tests for `.format_scalar_result()` and `.format_list_result()` in PR 2 | ✅ Resolved |

### New Issues

---

#### Section: PR 1 — S7 Class Properties + Error Catalog

No new issues found.

---

#### Section: PR 2 — Internal Helper Infrastructure

No new issues found.

---

#### Section: PR 3 — Unified Setters + Deprecations

---

**Issue 10: `lifecycle::deprecate_soft()` template in Step 3.13 passes `...` as fourth argument — this will throw an error for any non-trivial call**
Severity: REQUIRED
Violates code correctness: the code template in the plan produces broken deprecated functions.

PR 3 Step 3.13 provides this code template:
```r
set_variable_labels <- function(x, ...) {
  lifecycle::deprecate_soft("0.5.0", "set_variable_labels()", "set_var_label()", ...)
  set_var_label(x, ...)
}
```

`lifecycle::deprecate_soft()` has this signature:
```r
deprecate_soft(when, what, with = NULL, details = NULL, id = NULL, env = caller_env(), user_env = caller_env(1))
```

The `...` from the outer function is forwarded as a fourth positional argument, which
maps to `details`. When a caller passes named arguments (e.g.,
`set_variable_labels(svy, age = "Age in years")`), `rlang::list2(age = "Age in years")`
enters the fourth slot. Since `details` is not named `age`, R throws
`Error: unused argument (age = "Age in years")`. This means every deprecated function
that receives variable-setting arguments will error instead of emitting a deprecation
warning and delegating.

The correct template is:
```r
set_variable_labels <- function(x, ...) {
  lifecycle::deprecate_soft("0.5.0", "set_variable_labels()", "set_var_label()")
  set_var_label(x, ...)
}
```
The `...` is passed only to `set_var_label()`, not to `lifecycle::deprecate_soft()`.

Options:
- **[A]** Fix the code template in Step 3.13 to remove `...` from the
  `lifecycle::deprecate_soft()` call for all four deprecated wrappers. Update
  the deprecation test blocks in Step 3.2 to call the deprecated functions WITH
  arguments (e.g., `set_variable_labels(svy, age = "Age in years")`) to catch
  this class of bug in CI. — Effort: trivial, Risk: none
- **[C] Do nothing** — all four deprecated functions throw errors when used with
  any arguments; deprecation tests that call them without arguments would pass
  while real-world usage silently fails.

**Recommendation: [A]** — fix the template; the bug is concrete and the fix is one word.

---

**Issue 11: PR 3 Step 3.15 removes `.check_is_survey()` unconditionally — spec requires removal to be conditional on grep result**
Severity: REQUIRED
Violates spec Section 3.2: "If call sites exist elsewhere (e.g., `infer_question_prefaces()` or other functions not updated by this spec), leave `.check_is_survey()` in place and do not remove it."

Step 3.15 reads:
> "Remove `.check_is_survey()` from `R/core-metadata.R` (zero callers remaining after
> all setter replacements). Verify with `grep -r ".check_is_survey(" R/`."

The phrasing states "zero callers" as a fact and presents the `grep` as post-hoc
verification. The spec requires a conditional: remove ONLY IF grep returns zero results
across all R/ files. If `infer_question_prefaces()` or any other function in the codebase
calls `.check_is_survey()`, removing it breaks that function silently (no compilation
error, but a runtime "could not find function" error).

Options:
- **[A]** Rewrite Step 3.15 as two explicit sub-steps:
  1. Run `grep -r ".check_is_survey(" R/` to find all call sites.
  2. If the ONLY result is inside `core-metadata.R` (i.e., zero external callers):
     remove `.check_is_survey()`. Otherwise: leave it in place and do not remove it.
  — Effort: trivial, Risk: none
- **[C] Do nothing** — if an external caller exists, the implementer removes the function
  anyway, breaking that caller; CI would catch it only if the caller has tests.

**Recommendation: [A]** — grep is a one-line check that prevents a hard-to-debug silent failure.

---

#### Section: All PRs — Quality Gates

---

**Issue 12: `lintr::lint_package()` missing from Quality Gates footer and all four PR acceptance criteria**
Severity: REQUIRED
Violates spec Section XI: "`lintr::lint_package()` produces 0 lints (80-char line length,
native pipe, snake_case, `<-` assignment)" is explicitly required.

The Quality Gates footer at the bottom of the plan lists:
- `devtools::document()` ✅
- `air::format_package()` ✅
- `devtools::check()` ✅
- Snapshot review ✅

`lintr::lint_package()` is absent from the footer and from all four individual PR
acceptance criteria. `air` handles code formatting (indentation, line wrapping) but
`lintr` checks style rules that `air` does not enforce: native pipe consistency
(`pipe_consistency_linter("native")`), object naming (`object_name_linter("snake_case")`),
and assignment operator (`assignment_linter()`). Code with `%>%` pipes or `=` assignments
would pass `air::format_package()` cleanly but fail `lintr::lint_package()`.

Options:
- **[A]** Add `lintr::lint_package() — 0 lints` to the Quality Gates footer and to
  each PR's acceptance criteria (same position as `air::format_package()`).
  — Effort: trivial, Risk: none
- **[C] Do nothing** — style violations that `air` doesn't catch could enter the codebase;
  only detected if CI is configured to run lintr (which is not confirmed in the plan).

**Recommendation: [A]**

---

**Issue 13: Lifecycle DESCRIPTION update in PR 1 may produce a non-pre-approved R CMD check NOTE if lifecycle is not already used in the package**
Severity: REQUIRED
Violates the ≤2 pre-approved notes constraint: adding a package to `Imports` without
any `::` usage in current source produces an "Imported but not used" NOTE.

PR 1 Notes now correctly include: "Verify `lifecycle` is in `Imports`: run
`grep 'lifecycle' DESCRIPTION`. If missing, add `lifecycle (>= 1.0.0)` to `Imports`."

If lifecycle is NOT already in Imports AND NOT already used via `lifecycle::` calls in
any existing R/ file, adding it to DESCRIPTION in PR 1 creates an Imports entry with
zero corresponding `lifecycle::` calls in the codebase. R CMD check scans source files
for `::` usage and produces a NOTE for packages listed in Imports that are not referenced:
"package 'lifecycle' listed in Imports, but is not used in package source." This is NOT
one of the two pre-approved notes, so PR 1's acceptance criterion `devtools::check()
0/0/≤2` would be violated.

The `lifecycle::deprecate_soft()` calls are only introduced in PR 3. The correct
placement for the DESCRIPTION update (if lifecycle is absent) is PR 3, where it first
has a call site.

Options:
- **[A]** Change PR 1 Notes to: "Verify `lifecycle` is in `Imports`. If missing, **note
  that DESCRIPTION will be updated in PR 3** when `lifecycle::deprecate_soft()` is first
  called. Do not add it in PR 1." Move the conditional DESCRIPTION update step to PR 3
  (e.g., between Steps 3.12 and 3.13). — Effort: trivial, Risk: none
- **[B]** Keep the check in PR 1 but only add lifecycle to Imports in PR 3 regardless
  of where the check is performed. — Effort: trivial, effectively same as [A]
- **[C] Do nothing** — if lifecycle is not yet in Imports, PR 1's `devtools::check()`
  produces a new non-pre-approved NOTE that fails the acceptance criterion.

**Recommendation: [A]** — DESCRIPTION changes belong in the PR where the dependency
is first used.

---

#### Section: Suggestions

---

**Issue 14: Snapshot test review criterion absent from PR 2 and PR 3 acceptance criteria**
Severity: SUGGESTION

PR 4 acceptance criteria include "All snapshot tests match (`testthat::snapshot_review()`
before merge)." The Quality Gates footer includes "Snapshot tests reviewed with
`testthat::snapshot_review()` (not auto-accepted)."

PRs 2 and 3 also create new snapshots:
- PR 2: `.check_is_survey_or_df()` error snapshot, four `.parse_setter_input()` error
  snapshots, one `.resolve_vars()` warning snapshot, one `.format_list_result()` error
  snapshot — at least 7 new snapshots
- PR 3: all setter error and warning snapshots — 20+ new snapshots

When `expect_snapshot(error = TRUE, ...)` runs for the first time in a test suite,
testthat auto-creates the snapshot file and the test passes. Without a `snapshot_review()`
step, the implementer may commit snapshots containing incorrect or unreviewed error text.

Options:
- **[A]** Add "Run `testthat::snapshot_review()` — approve all new snapshots before merge"
  to PR 2 and PR 3 acceptance criteria. — Effort: trivial
- **[C] Do nothing** — the global quality gates mention it; risk is that per-PR
  review is skipped in practice.

**Recommendation: [A]**

---

**Issue 15: PR 3 Step 3.2 writes tests for all 6 setters in one step — exceeds the 2–5 minute task granularity guideline**
Severity: SUGGESTION
Violates implementation-workflow skill: "Each task in the plan should be one action
(2–5 minutes). TDD sub-steps must be explicit steps."

Step 3.2 is a single step that asks the implementer to write ALL test blocks for ALL
six setters before any implementation — at minimum 60–80 test blocks covering
conventions 1/2/3, return values, pipe chains, NULL deletion, data frame attributes,
all error classes, all warning classes, and snapshots. Executing this in one step takes
significantly longer than 5 minutes and creates a large unstaged file with no
intermediate checkpoint.

Steps 3.4–3.12 correctly implement one setter per step. The test-writing phase should
mirror this granularity.

Options:
- **[A]** Split Step 3.2 into six sub-steps, one per setter:
  - Step 3.2a: Write `set_var_label()` test blocks
  - Step 3.2b: Write `set_val_labels()` test blocks
  - Steps 3.2c–f: Write test blocks for the remaining four setters
  Each sub-step is immediately followed by its implementation step in the TDD cycle.
  (e.g., 3.2a → 3.3 confirm failure → 3.4 implement `set_var_label()` → 3.5 confirm pass
  → 3.2b → confirm failure → 3.6 implement `set_val_labels()` → 3.7 confirm pass → ...)
  — Effort: low reorganization, Risk: none
- **[C] Do nothing** — large single step is inconvenient but the implementer can
  work through it sequentially; `r-implement` handles granular execution.

**Recommendation: [A]** — aligning test-writing steps with implementation steps makes
TDD failures immediately diagnosable and keeps each checkpoint small.

---

**Issue 16: Step 4.12 NEWS.md item 2 incorrectly lists `extract_universe()` as a breaking return-type change**
Severity: SUGGESTION

PR 4 Step 4.12 item 2 reads:
> "`extract_var_label()`, `extract_question_preface()`, `extract_var_note()`,
> `extract_universe()` now return a named character vector (not a plain scalar)
> for single-variable calls."

`extract_universe()` is a NEW function introduced by this spec. It has no prior API
and therefore no prior return type to break. Including it in the "Breaking Changes"
section is technically inaccurate and may confuse users who understand a breaking
change as a change to an existing function's behavior.

Options:
- **[A]** Remove `extract_universe()` from item 2. The correct list is:
  "`extract_var_label()`, `extract_question_preface()`, and `extract_var_note()`
  now return a named character vector (not a plain scalar)." List
  `extract_universe()` and `extract_missing_codes()` in a separate `### New
  Functions` or `### New Features` section if one exists. — Effort: trivial
- **[C] Do nothing** — technically inaccurate but harmless; users will understand
  the intent.

**Recommendation: [A]** — accurate NEWS.md entries matter; the fix is one line.

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 4 |
| SUGGESTION | 3 |

**Total new issues:** 7

**Overall assessment:** The plan is substantially improved from Pass 1 — all eight
resolvable prior issues are addressed and the blocking issue is gone. Four required
fixes remain before implementation: Issue 10 (the `lifecycle::deprecate_soft()` template
bug) is the highest priority, as it would silently ship broken deprecated functions that
error on any real-world call; Issues 11–13 are straightforward clarifications. Three
suggestions address test step granularity, snapshot review placement, and NEWS.md
accuracy. Resolving the four required issues leaves the plan fully ready for
`/r-implement`.
