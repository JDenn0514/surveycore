## Plan Review: nonprob-bootstrap-variance — Pass 1 (2026-05-19)

### New Issues

#### Section: PR 1 — Class, Constructor, Validator, Error Registry

---

**Issue 1: NB-2 message text mismatch between `error-messages.md` and spec**
Severity: REQUIRED
Violates: Snapshot test fidelity requirement (testing-standards.md §3 — snapshots block PRs)

The plan's Step 1 says to update NB-1 text but says nothing about NB-2. NB-2 (`surveycore_warning_nonprob_srs_fallback`) already exists in `error-messages.md` (row NB-2) but its `"i"` bullet differs from the spec:

- **error-messages.md (current):** `"Run {.fn surveywts::create_bootstrap_weights} and pass the result to {.arg repweights} in {.fn as_survey_nonprob} for correct SEs."`
- **spec §6:** `"Run {.fn surveywts::create_bootstrap_weights} on this design for correct SEs."`

The snapshot test in PR 2 (`test-nonprob-bootstrap-variance.R`) will capture the actual emitted message. If the implementation follows the spec and `error-messages.md` still holds the old text, the snapshot will disagree with both, causing a snapshot failure that blocks the PR.

Options:
- **[A]** Add "update NB-2 `"i"` bullet text to match spec §6" explicitly to PR 1 Step 1 (the error-messages.md update step). — Effort: low, Risk: low, Impact: prevents snapshot divergence
- **[B]** Accept NB-2 current text as authoritative and update the spec — but spec is approved; this re-opens a locked document.
- **[C] Do nothing** — snapshot test in PR 2 will fail until resolved during review, adding friction.

**Recommendation: [A]** — trivial fix to a step that already touches this file; prevents a confusing CI failure.

---

**Issue 2: `helper-test-data.R` not listed; `test_invariants()` does not check the 5 new `@variables` keys**
Severity: REQUIRED
Violates: code-style.md ("all `@variables` keys always present"); testing-standards.md (98%+ coverage, invariant checks as first assertion)

The PR 1 acceptance criterion states "`test_invariants(d)` passes for a `survey_nonprob` with repweights." However, reading `tests/testthat/helper-test-data.R` (lines 253–306), the `survey_nonprob` branch of `test_invariants()` only checks `weights` and `probs_provided` keys. It does **not** check for the 5 new keys (`repweights`, `type`, `scale`, `rscales`, `mse`).

This means `test_invariants()` will pass even if a constructor bug writes the repweight keys under wrong names or omits them entirely — the invariant is not enforced. The "all keys always present" rule from `code-style.md` will be tested only by the explicit constructor assertions, which can be inadvertently bypassed by testing the wrong object state.

`helper-test-data.R` is not listed as a file to update in PR 1.

Options:
- **[A]** Add `helper-test-data.R` to PR 1's file list. Extend the `survey_nonprob` branch of `test_invariants()` to assert all 5 repweight keys are present in `@variables` (values may be `NULL`, but keys must not be absent). — Effort: low, Risk: low, Impact: closes a real invariant enforcement gap
- **[B]** Add explicit `expect_true("repweights" %in% names(d@variables))` etc. in each constructor test block instead of updating `test_invariants()`. — Effort: medium (6+ repetitions), Risk: medium (DRY violation — engineering-preferences.md rule 1), Impact: same coverage as [A] with more duplication
- **[C] Do nothing** — invariant enforcement for the new keys is missing; bugs that drop a key from `@variables` will pass all tests.

**Recommendation: [A]** — minimal change to helper-test-data.R; closes the enforcement gap with one targeted addition.

---

**Issue 3: Roxygen documentation requirements from spec missing from PR 1 plan**
Severity: REQUIRED
Violates: Spec §Design Decisions (explicit "must" language); r-package-conventions.md (`@return` and `@examples` required on all exports)

The spec explicitly requires four documentation additions to `as_survey_nonprob()` that are absent from the plan:

1. `@param repweights` — must state the combined-weights assumption: "Columns must contain combined weights (full calibrated weight per unit), not fractional adjustment factors."
2. `@details` — must note that `scale = 1/R` (not `1/(R-1)` as in the `survey` package) and why.
3. `@details` — must note that `mse = TRUE` (not `mse = FALSE` as in the `survey` default) and why.
4. `@references` — must cite Wu (2022) and Chen et al. (2021).

None of these appear in PR 1's file list, TDD steps, or acceptance criteria. The acceptance criterion "`devtools::document()` run; NAMESPACE and man/ in sync" only verifies that documentation is generated, not that these required sections exist.

Options:
- **[A]** Add roxygen documentation work as an explicit task in PR 1 Step 7 (implement `R/core-constructors.R`), and add an acceptance criterion: "roxygen `@param repweights` states combined-weights assumption; `@details` notes scale and mse deviations from the `survey` package; `@references` includes Wu 2022 and Chen et al. 2021." — Effort: low, Risk: low, Impact: spec-complete
- **[B]** Create a separate PR 1.5 for documentation only — Effort: medium (extra PR overhead), Risk: low, Impact: documentation separated from implementation (harder to verify correctness)
- **[C] Do nothing** — `as_survey_nonprob()` ships without documented deviations from `survey`; users who compare SEs will be confused; fails spec compliance.

**Recommendation: [A]** — the documentation belongs in the same PR as the implementation; adding one task and one AC is minimal work.

---

#### Section: PR 2 — Analysis Dispatch and `.degf()` Fixes

---

**Issue 4: All-NA early-return shapes for 6 helpers not pre-identified**
Severity: REQUIRED
Violates: engineering-preferences.md (explicit over clever; handle edge cases correctly)

The plan says `.nonprob_rep_na_warn()` returns `TRUE` as a sentinel for all-NA early exit, and "Each caller must return its own NA-filled result structure matching that helper's normal return shape." However, the plan does not specify what that NA-filled structure is for any of the 6 helpers. For means and freqs the implementer can infer it from the helper's return type. For `.vcov_pair_replicate()` and `.covariance_pair_replicate()`, the return shape may be less obvious.

If the implementer uses the wrong NA shape (e.g., returning `list(estimate = NA_real_)` when the helper normally returns `list(cor = NA_real_, se = NA_real_, ...)`) the early-return path silently produces malformed output that passes all tests unless the tests explicitly validate the all-NA case.

Options:
- **[A]** Add a note to PR 2 Step 1 specifying that `test-nonprob-bootstrap-variance.R` must include an all-NA early-return test for at least `get_means()` (domain where all replicates are NA), which forces the implementer to define the return shape concretely before implementing it. — Effort: low, Risk: low, Impact: TDD forces correct NA shape by construction
- **[B]** Enumerate the expected NA return shape for all 6 helpers in the plan notes. — Effort: medium, Risk: low, Impact: complete specification but may go stale if helpers change
- **[C] Do nothing** — implementer reads each helper's non-NA return path and mirrors it; risk of inconsistency across helpers.

**Recommendation: [A]** — a test-first approach is already the PR 2 methodology; adding one all-NA test case forces correctness without adding plan maintenance burden.

---

#### Section: PR Map / General

---

**Issue 5: Note 6 wording creates ambiguity about which ratios file to edit**
Severity: SUGGESTION
The spec table (§3) says `R/analysis-ratios-helpers.R` for the `is_replicate` flag. The plan correctly identifies `R/analysis-ratios.R` (verified: `is_replicate` assignment is at line 210 of `R/analysis-ratios.R`). However, the final sentence of Note 6 reads: "No other changes needed in `analysis-ratios-helpers.R` or `analysis-ratios.R`." This is confusing — it says both files need no changes, yet the note just described a change to `analysis-ratios.R`. The intended meaning is "no changes needed to `analysis-ratios-helpers.R`, and no changes needed to any other part of `analysis-ratios.R` beyond the `is_replicate` assignment."

Options:
- **[A]** Rewrite the final sentence of Note 6 to: "No changes needed to `analysis-ratios-helpers.R`. The only change to `analysis-ratios.R` is the `is_replicate` assignment above." — Effort: trivial, Risk: none
- **[B] Do nothing** — implementer may be momentarily confused but can verify by reading the files.

**Recommendation: [A]** — one-sentence fix prevents a potential wrong-file edit.

---

**Issue 6: 98%+ coverage requirement absent from all three PRs' acceptance criteria**
Severity: SUGGESTION
Violates: testing-standards.md §2 (PRs blocked below 95%; project target 98%+)

None of PR 1, PR 2, or PR 3 acceptance criteria mention line coverage. The quality gates section at the bottom of the plan also omits this. This is a standard criterion per `testing-standards.md` and `stage-2-review.md`.

Options:
- **[A]** Add "Line coverage remains ≥ 98% (`covr::package_coverage()` target)" to each PR's acceptance criteria. — Effort: trivial
- **[B] Do nothing** — coverage drop would be caught by CI but not during plan review or manual PR-open checks.

**Recommendation: [A]** — single bullet per PR; makes the standard explicit.

---

**Issue 7: `plans/error-messages.md` coverage map update not listed as a PR-specific acceptance criterion**
Severity: SUGGESTION
The Quality Gates section says "plans/error-messages.md coverage map updated with new test file references," but the per-PR acceptance criteria don't mention it. PR 1 introduces 5 new error classes that need coverage map entries pointing to `test-constructors.R` and `test-validators.R`. PR 2 creates `test-nonprob-bootstrap-variance.R` which will cover NB-1, NB-2, and the domain-replicates-na warning.

Without a per-PR checkpoint, the coverage map update tends to be forgotten until the final quality gate sweep.

Options:
- **[A]** Add "Coverage map in `plans/error-messages.md` updated (new rows point to `test-constructors.R` / `test-validators.R`)" to PR 1 acceptance criteria; add row for `test-nonprob-bootstrap-variance.R` to PR 2 acceptance criteria. — Effort: trivial
- **[B] Do nothing** — caught at the Quality Gates step.

**Recommendation: [A]** — catches omissions before the final gate, not after.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 4 |
| SUGGESTION | 3 |

**Total issues:** 7

**Overall assessment:** The plan is well-structured and implementable, but has four required gaps that would produce snapshot failures (Issue 1), a silent invariant enforcement hole (Issue 2), spec-noncompliant documentation (Issue 3), and underspecified all-NA behavior that TDD should drive (Issue 4). Resolving these before coding starts is straightforward — three are single-sentence additions to existing steps or acceptance criteria, and one (Issue 2) requires adding `helper-test-data.R` to PR 1's file list.
