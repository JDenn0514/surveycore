# Plan Review: Phase 0.75

**Plan file:** `plans/implementation-plan-phase-0.75.md`
**Spec file:** `plans/phase-0.75-formal-specification.md`
**Date:** February 2026
**Reviewer:** Claude Code (Stage 2 adversarial review)

---

## Section: PR Map

**Issue 1: Plan contradicts spec Q8 and spec Section 2.4 on PR structure**
Severity: BLOCKING
Rule: Spec is the source of truth for architectural decisions; plan may not silently override spec decisions.

The spec Decisions Summary states `"| PR structure | Single PR (Q8) |"`. Spec Section 2.4 is
even more explicit: *"The split happens in the same PR as the two-phase addition, since the
file is already open."*

The implementation plan uses three PRs:
- PR 1: File structure refactor (`feature/variance-file-split`)
- PR 2: Constructor tightening (`feature/twophase-constructor-na`)
- PR 3: Engine + dispatch (`feature/variance-twophase`)

Only PR 3 uses the branch name stated in the spec header (`feature/variance-twophase`). An
implementer following both documents would encounter a direct conflict — the spec says "one
PR," the plan says "three."

The three-PR approach may be better engineering (each PR independently passes
`devtools::check()`), but that decision requires explicit acknowledgment that Q8 is being
overridden and why. There is no such note in the plan.

Options:
- **[A]** Add a `## Departure from Spec Q8` note near the top of the plan explaining that 3
  PRs replaces the spec's single-PR decision, with rationale (each PR independently shippable;
  reduces reviewer cognitive load; smaller diffs).
  — Effort: low, Risk: low, Impact: removes the conflict; implementer has clear authority
- **[B]** Collapse to a single PR matching the spec decision.
  — Effort: high (restructuring plan), Risk: medium (giant PR harder to review), Impact: spec
  compliance
- **[C] Do nothing** — implementer encounters a direct spec-vs-plan contradiction with no
  resolution guidance.

**Recommendation: [A]** — The 3-PR structure is objectively better practice; acknowledge the
departure explicitly rather than leaving a silent contradiction.

---

## Section: PR 2 — Constructor Tightening

**Issue 2: `phase2_ind` → `subset` rename scope is massively incomplete**
Severity: BLOCKING
Rule: "File completeness" lens — all affected files must be listed.

The plan says the `phase2_ind` → `subset` rename affects:
- `helper-test-data.R` (`make_survey_data()` and `make_all_designs()`)
- `test-variance-dispatch.R` (two blocks)

A codebase-wide search finds **64 references to `phase2_ind`** spanning **7 files not
mentioned in the plan**:

| File | References | Why affected |
|------|-----------|--------------|
| `tests/testthat/test-constructors.R` | ~29 | Calls `make_survey_data(design="twophase")` in every block; all then use `subset = phase2_ind` or `df$phase2_ind` |
| `tests/testthat/test-conversion.R` | 5 | `suppressWarnings(as_survey_twophase(phase1, subset = phase2_ind))` |
| `tests/testthat/test-utils.R` | 3 | `subset = phase2_ind` + `expect_true("phase2_ind" %in% flat)` (string assertion on column name) |
| `tests/testthat/test-methods-print.R` | 1 | `suppressWarnings(as_survey_twophase(phase1, subset = phase2_ind))` |
| `tests/testthat/test-update-design.R` | 1 | `suppressWarnings(as_survey_twophase(phase1, subset = phase2_ind))` |
| `tests/testthat/_snaps/constructors.md` | 7 | `phase2_ind` appears in Warning 24 snapshot, Warning 25 snapshot, Row 19 error snapshot, Row 21 error snapshot — all must be regenerated |
| `tests/testthat/_snaps/methods-print.md` | 4 | Column name `phase2_ind` appears in the data display output of print snapshots |

Specific examples of what breaks:
- `test-constructors.R:1085`: `df$phase2_int <- as.integer(df$phase2_ind)` — after rename,
  `df$phase2_ind` no longer exists; assignment silently creates an NA column.
- `test-constructors.R:1069–1078`: Test for Row 21 (subset selects >1 column) creates
  `df$phase2_ind2` as a second column and uses `starts_with("phase2_ind")` to select both.
  After rename, the generated column is `subset`, not `phase2_ind`, so `starts_with("phase2_ind")`
  only matches the one manually-added `phase2_ind2` column — the test stops testing what it
  claims to test.
- `_snaps/constructors.md:136–213`: Seven snapshot entries embed `phase2_ind` in both code
  and output lines. After the rename, regenerated snapshots will show `subset` instead; these
  entries must all be deleted and regenerated.
- `_snaps/methods-print.md:167–294`: Print snapshots show the data column header `phase2_ind`;
  after the rename this becomes `subset` and all print snapshots must be regenerated.
- `test-utils.R:176,286`: `expect_true("phase2_ind" %in% flat)` — string literal will fail
  after rename.

Without addressing all these files, PR 2 will fail `devtools::check()` and the plan's
acceptance criterion "No remaining reference to `phase2_ind`" (if added — it is currently
absent) cannot be verified.

Options:
- **[A]** Extend the PR 2 "Files" table and implementation notes to enumerate all 7 affected
  files plus the snapshot regeneration requirement. Add an acceptance criterion: "No remaining
  reference to `phase2_ind` anywhere in `tests/` (grep check)."
  — Effort: medium, Risk: low, Impact: makes the scope complete and checkable
- **[B]** Split into a sub-PR: first rename the generator column; then update all test files.
  — Effort: high, Risk: low, Impact: cleaner history but more PRs
- **[C] Do nothing** — PR 2 will break `devtools::check()` on first run.

**Recommendation: [A]** — enumerate the full file list and add the grep acceptance criterion.

---

**Issue 3: Plan's assumed BEFORE pattern for Warning 23b conversion is wrong**
Severity: REQUIRED
Rule: "File completeness" lens — implementation changes must describe the actual current state.

The plan shows this BEFORE pattern for the Warning 23b conversion:
```r
# BEFORE:
test_that("as_survey_twophase() warns for NA in subset column", {
  expect_warning(
    result <- as_survey_twophase(ph1, subset = has_na_col, method = "approx"),
    class = "surveycore_warning_subset_na"
  )
  test_invariants(result)
})
```

The actual code in `test-constructors.R:1120–1139` is:
```r
test_that("as_survey_twophase() warns when subset column has NA values [row 23b]", {
  df              <- make_survey_data(n = 100L, n_psu = 10L, n_strata = 2L,
                                      design = "twophase", seed = 30L)
  df$phase2_na    <- df$phase2_ind
  df$phase2_na[1] <- NA
  phase1 <- suppressWarnings(as_survey(df, weights = wt, strata = strata))
  got_na_warn <- FALSE
  suppressWarnings(
    withCallingHandlers(
      as_survey_twophase(phase1, subset = phase2_na),
      surveycore_warning_subset_na = function(w) {
        got_na_warn <<- TRUE
        invokeRestart("muffleWarning")
      }
    )
  )
  expect_true(got_na_warn, label = "surveycore_warning_subset_na was raised")
})
```

The test:
- Has a different name than the plan shows
- Uses `withCallingHandlers` instead of `expect_warning()`
- Uses `make_survey_data(design = "twophase")` (affected by Issue 2's rename)
- Has no `test_invariants(result)` call (cannot — the warning version creates the object, but
  the new error version does not)

An implementer following the plan's "find each block matching" instruction would search for
the `expect_warning(... class = "surveycore_warning_subset_na")` pattern and not find it.

Options:
- **[A]** Update the BEFORE pattern in the plan to show the actual `withCallingHandlers`
  structure, and update the block description to use the actual test name.
  — Effort: low, Risk: low, Impact: implementer can find and replace the right block
- **[B]** Change the instruction to "search for `surveycore_warning_subset_na`" (the string
  literal), which will find the block regardless of structure.
  — Effort: low, Risk: low, Impact: equivalent result
- **[C] Do nothing** — implementer must discover the mismatch by inspection.

**Recommendation: [A]** — show the actual BEFORE state; the plan is a precise contract.

---

**Issue 4: PR 2 acceptance criteria omit confirmation that `surveycore_error_unsupported_class` still fires between PR 2 and PR 3**
Severity: REQUIRED
Rule: Acceptance criteria must be objectively verifiable; partially complete PRs must gate on interim state.

After PR 2 merges and before PR 3 merges, `get_means()` and `get_totals()` still reject
`survey_twophase` inputs with `surveycore_error_unsupported_class`. The plan correctly notes
in the implementation notes: *"Keep the `expect_error(class = 'surveycore_error_unsupported_class')`
assertion — it remains valid until PR 3."*

But this invariant does not appear in PR 2's acceptance criteria. If the implementer
accidentally removes the unsupported-class rejection (e.g., when removing the `suppressWarnings`
wrapper), the CI gate would not catch it.

Options:
- **[A]** Add to PR 2 acceptance criteria: "The two 'not yet implemented' blocks in
  `test-variance-dispatch.R` still pass with `expect_error(class = 'surveycore_error_unsupported_class')`."
  — Effort: low, Risk: low, Impact: explicit CI gate on the interim state
- **[B]** Leave as an implementation note only.
  — Effort: none, Risk: low (the test still exists), Impact: weaker gating
- **[C] Do nothing** — acceptable given the existing test structure.

**Recommendation: [A]** — acceptance criteria are the contract; move the note into the list.

---

## Section: PR 1 — File Structure Refactor

**Issue 5: PR 1 and PR 2 missing `devtools::document()` criterion**
Severity: REQUIRED
Rule: Acceptance criteria lens — standard criteria must be present in every PR.

The standard acceptance criteria from stage-2-review.md include:
> `devtools::document()` run; NAMESPACE and man/ in sync

PR 3 lists this explicitly. PR 1 mentions it in the implementation notes as "Run to confirm no
diff." PR 2 is silent on it entirely.

For PR 1 this matters because the file rename (splitting `06-variance-estimation.R` into four
files) removes comments that might interact with roxygen parsing if any of the split code
contains `#'` lines near non-exported functions. For PR 2 this matters because the constructor
changes modify a function that has roxygen documentation.

Options:
- **[A]** Add to PR 1 and PR 2 acceptance criteria: "`devtools::document()` run; NAMESPACE
  and man/ produce no diff."
  — Effort: low, Risk: low, Impact: explicit standard gate
- **[B]** Accept the implementation note in PR 1 and silence in PR 2 as sufficient.
  — Effort: none, Risk: low
- **[C] Do nothing**

**Recommendation: [A]** — consistent gating across all PRs.

---

**Issue 6: PR 1 and PR 2 missing 98%+ line coverage criterion**
Severity: REQUIRED
Rule: Testing standards — coverage target must be stated.

PR 3 states: *"R/06-variance-twophase.R coverage ≥ 98%; Total package coverage ≥ 98%."*
PR 1 and PR 2 have no coverage criterion at all.

For PR 1 (pure cut-and-paste), coverage should be identical. But a missing line during the
mechanical split could silently drop below 98% — `devtools::check()` does not catch this.
For PR 2 (removes Warning 23b code path, adds new error path, removes Warning 25 code path),
coverage is a real concern: the old warning code is gone and the new error must be reachable.

Options:
- **[A]** Add to PR 1 acceptance criteria: "Total package coverage ≥ 98% (should be
  identical to pre-PR baseline)." Add to PR 2 acceptance criteria: "Total package coverage
  ≥ 98%."
  — Effort: low, Risk: low, Impact: coverage gates for all PRs
- **[B]** Accept that PR 3's coverage criterion implicitly covers the whole package.
  — Effort: none, Risk: low (PR 3 would catch a PR 1/2 drop)
- **[C] Do nothing**

**Recommendation: [A]** — coverage should gate every PR, not just the final one.

---

## Section: PR 2 and PR 3 — Cross-cutting

**Issue 7: `plans/error-messages.md` Coverage Map table update not in any acceptance criterion**
Severity: REQUIRED
Rule: File completeness lens — all file changes must be verifiable via acceptance criteria.

The plan says in PR 2: *"Update the Coverage Map table: remove the 23b reference from
test-constructors.R row; add the new error class reference."* In PR 3: *"Update the Coverage
Map table to add `test-variance-twophase.R` covering the new error classes."*

Neither update appears in any PR's acceptance criteria. These are functional changes to a
living reference document (`plans/error-messages.md`) — if forgotten, future test writers
will reference a stale Coverage Map.

Options:
- **[A]** Add to PR 2 acceptance criteria: "`plans/error-messages.md` Coverage Map updated:
  row 23b removed from test-constructors.R row; `surveycore_error_subset_na` added."
  Add to PR 3 acceptance criteria: "`plans/error-messages.md` Coverage Map updated:
  `test-variance-twophase.R` row added."
  — Effort: low, Risk: low, Impact: coverage map stays in sync
- **[B]** Leave as description prose only.
  — Effort: none, Risk: medium (map drifts from reality)
- **[C] Do nothing**

**Recommendation: [A]** — the Coverage Map is authoritative; its updates must be gated.

---

## Section: PR 3 — Two-Phase Variance Engine

No blocking or required issues found specific to PR 3's scope (beyond those already noted in
cross-cutting issues above). The file table, implementation notes, test structure, and oracle
construction are detailed and consistent with the spec.

**Issue 8: Warning 24 (`surveycore_warning_simple_clustered`) not mentioned in plan**
Severity: SUGGESTION
Rule: Spec coverage — all spec behaviors must have corresponding plan entries.

Spec Section 5.5 says: *"Warning at construction: `surveycore_warning_simple_clustered`
(Warning 24) is fired by `as_survey_twophase()` when `method = "simple"` is used with a
clustered Phase 1 design."* The plan does not mention Warning 24 anywhere.

The warning presumably already exists (it is in `plans/error-messages.md` row 24, and
`test-constructors.R:1013` has a snapshot test for it). PR 2 modifies the constructor around
the Warning 23b and Warning 25 blocks; Warning 24 is in a separate code path that is not
touched. However:
1. There is no acceptance criterion confirming Warning 24 still fires after PR 2's changes.
2. The test for Warning 24 at `test-constructors.R:1013–1021` calls
   `make_survey_data(design = "twophase")` and uses `subset = phase2_ind` — it is affected
   by Issue 2's rename and would break after PR 2.

This is a gap that Issue 2 already captures at the code level, but the plan should also note
Warning 24 explicitly so the implementer knows not to disturb it.

Options:
- **[A]** Add a note in PR 2's implementation notes: "Warning 24 (`surveycore_warning_simple_clustered`)
  is in a separate code path; do not remove it. Its test at line ~1013 requires the
  `phase2_ind` → `subset` rename (covered by Issue 2)."
  — Effort: low, Risk: low
- **[B]** Rely on Issue 2's coverage (rename audit will catch the broken test).
  — Effort: none, Risk: low
- **[C] Do nothing**

**Recommendation: [A]** — a one-line note prevents accidental removal during constructor edits.

---

**Issue 9: PR 3 file table lists `devtools::document()` as an action, not output files**
Severity: SUGGESTION
Rule: File completeness — the file table should list files, not actions.

The PR 3 file table has:
```
| Run | `devtools::document()` | Regenerate NAMESPACE + man/ for updated get_means / get_totals roxygen |
```

This is an action entry, not a file. The actual files that change are:
- `NAMESPACE` (if imports change — unlikely but should verify)
- `man/get_means.Rd`
- `man/get_totals.Rd`

If these are not listed, the PR author might forget to `git add` them before committing.

Options:
- **[A]** Replace the `devtools::document()` action row with three explicit file rows:
  `Modify | NAMESPACE | Regenerated`, `Modify | man/get_means.Rd | Updated roxygen`,
  `Modify | man/get_totals.Rd | Updated roxygen`.
  — Effort: low, Risk: low
- **[B]** Keep as-is; the acceptance criterion "`devtools::document()` run; NAMESPACE and
  man/ in sync" covers it.
  — Effort: none, Risk: low
- **[C] Do nothing**

**Recommendation: [A]** — file table should be a complete list of files touched.

---

**Issue 10: `make_all_designs()` change needs explicit audit note for callers**
Severity: SUGGESTION
Rule: DRY / completeness — changes to shared test fixtures need audits of all callers.

PR 2 changes `make_all_designs()` to produce `method = "approx"` for the twophase design.
`make_all_designs()` is a shared fixture used in multiple test files. If any test calls
`make_all_designs()$twophase` and then asserts behavior specific to `method = "full"` or
`method = "simple"`, those tests would break silently.

The plan does not include an audit step to verify all callers are compatible with
`method = "approx"`.

Options:
- **[A]** Add to PR 2 implementation notes: "Audit all `make_all_designs()` call sites for
  assumptions about the twophase method; confirm `method = 'approx'` is compatible with all
  uses."
  — Effort: low, Risk: low
- **[B]** Trust that the CI run catches any incompatible callers.
  — Effort: none, Risk: low (CI would catch)
- **[C] Do nothing**

**Recommendation: [B]** — CI will catch this; adding an audit note is optional.

---

## Summary

| Severity | Count |
|---|---|
| BLOCKING | 2 |
| REQUIRED | 5 |
| SUGGESTION | 3 |

**Total issues:** 10

**Overall assessment:** Two issues must be resolved before a single line of code is written.
Issue 2 (the `phase2_ind` rename scope) will cause PR 2 to fail `devtools::check()` as written
— 64 references across 7 files are unaccounted for, including snapshot files that embed the
column name in their stored output. Issue 1 (the spec-vs-plan PR count contradiction) must be
acknowledged explicitly to give the implementer clear authority to proceed with 3 PRs. Resolve
both, then close the five REQUIRED gaps (Issues 3–7), and the plan will be ready to implement.
