# Decisions Log — surveycore effective-n

This file records planning decisions made during effective-n development.
Each entry corresponds to one planning session.

---

## 2026-05-04 — Methodology lock: get_effective_n()

### Context

Resolved 17 issues from the Stage 2 methodology review (Pass 1). The review
covered both the Kish (1965) weight-based estimator and the DEFF-based
estimator that delegates to `get_means()`. Key questions involved output
column naming, subdomain semantics, degenerate-DEFF handling, and external
validation requirements.

### Questions & Decisions

**Q: Should the `deff` output column use the same name for both the Kish weight ratio and the full design-effect ratio?**
- Options considered:
  - **Option A — Rename Kish column to `deff_kish`:** Output columns are `n, n_eff, deff_kish` for method = "kish" and `n, n_eff, deff` for method = "deff". Column name itself signals which formula was used.
  - **Option B — Keep `deff` for both; add `meta$deff_type`:** Programmatic disambiguation possible but not forced; downstream code can still silently misuse.
  - **Option C — Do nothing:** Rely on print header and documentation.
- **Decision:** Option A — rename Kish column to `deff_kish`.
- **Rationale:** The spec is in DRAFT. The two quantities are mathematically different (weight-only heuristic vs. full design effect); naming them identically sets up silent misinterpretation. Column rename cost is zero at this stage.

**Q: DEFF dependency on `get_means()` deff formula: add cross-reference or rely on test gate?**
- Options considered:
  - **Option A — Add cross-reference sentence in §III:** Explicitly document that `get_means()` returns `(SE_design/SE_SRS)^2 = Var_design/Var_SRS`.
  - **Option B — Rely on test 2d (internal parity):** Implicit validation via transitivity.
  - **Option C — Do nothing.**
- **Decision:** Option A — add cross-reference.
- **Rationale:** The spec should be self-documenting. A silent factor-of-DEFF error would be difficult to diagnose; one sentence eliminates that risk.

**Q: Small design df instability in DEFF: documentation note or runtime warning?**
- Options considered:
  - **Option A — Documentation note in §III DEFF rules.**
  - **Option B — Runtime warning if degf(design) < threshold.** Threshold selection uncertain from literature.
  - **Option C — Do nothing.**
- **Decision:** Option A — documentation note.
- **Rationale:** The df-instability note informs users at zero implementation cost. A warning threshold would require justification from the survey literature and risks being either too noisy or too permissive.

**Q: Kish subdomain semantics: clarify weight-only interpretation or switch to renormalized weights?**
- Options considered:
  - **Option A — Add clarifying note to Kish rule 1:** Weights are not renormalized; this is a within-domain weight-based effective N, not a design-aware domain effective N.
  - **Option B — Switch to domain-renormalized weights.** Changes numerical results; higher risk.
  - **Option C — Do nothing.**
- **Decision:** Option A — add clarifying note.
- **Rationale:** The weight-only semantics are correct for the Kish heuristic; the clarification guides users to `method = "deff"` when they need design-aware domain effective N.

**Q: Degenerate DEFF: handle only `deff == 0` or extend to `deff <= 0`?**
- Options considered:
  - **Option A — Extend rule 5 to `deff <= 0`.** Covers negative DEFF from numerically unstable variance; adds one test case.
  - **Option B — Add a `surveycore_warning_effective_n_negative_deff` warning.** Medium effort.
  - **Option C — Do nothing.**
- **Decision:** Option A — extend to `deff <= 0`.
- **Rationale:** Negative DEFF produces nonsensical negative n_eff. The fix is one word change in the spec and one additional test case.

**Q: Empty domain handling: new `surveycore_warning_empty_domain` or document reliance on `min_cell_n`?**
- Options considered:
  - **Option A — Add `surveycore_warning_empty_domain` warning class.** Medium effort (new class in error-messages.md).
  - **Option B — Document that zero-row domains produce NA; users inspect the `n` column.**
  - **Option C — Do nothing.**
- **Decision:** Option B — document reliance on `min_cell_n`.
- **Rationale:** `min_cell_n` already fires for `n < 30` (default). Zero-row domains are a degenerate subcase; the `n` column makes them visible without a separate warning class.

**Q: External validation against `survey::svymean(deff=TRUE)`: add test or rely on internal parity?**
- **Decision (unambiguous):** Add external validation test.
- **Rationale:** `get_means()` has its own tests against `survey`, but `get_effective_n()` is a new exported function. Transitivity through `get_means()` alone is insufficient; a direct parity test against the canonical reference implementation is required.

### Outcome

Spec bumped to version 0.2. The Kish method now outputs `deff_kish` (not
`deff`); the DEFF method outputs `deff`. All 17 methodology review issues
resolved (4 unambiguous fixes, 12 judgment calls, 1 do-nothing). Spec is
methodology-locked.

---

## 2026-05-04 — Stage 4 code review resolve: get_effective_n()

### Context

Resolved 10 issues from the Stage 3 code/architecture review (Pass 1). All
issues involved either clarifying ambiguous prose, closing edge-case gaps, or
making the output contract and test plan explicit enough for a builder to follow
without guessing.

### Questions & Decisions

**Q: Should `.deff_effective_n()` be defined as a named helper or inlined?**
- Options considered:
  - **Option A — Remove helper, inline `get_means()` call directly in the DEFF branch:** No new single-call-site wrapper; cleaner.
  - **Option B — Keep helper, fix prose to match.**
- **Decision:** Option A — inline the `get_means()` call; no named helper.
- **Rationale:** code-style.md §4 says inline helpers when used in exactly one place. A helper with one call site violates that rule and adds indirection for no gain.

**Q: Should the `.id` column for `survey_collection` dispatch be listed in the output contract?**
- Options considered:
  - **Option A — Add explicit `[.id]` row to the output column table.**
  - **Option B — Prose note only.**
  - **Option C — Do nothing (infer from helper behavior).**
- **Decision:** Option A — add `.id` row to the table.
- **Rationale:** The output contract must be self-contained. All other `get_*()` functions include `.id` in their output tables; consistency requires the same here.

**Q: How should non-finite DEFF values (`Inf`, `NaN`, `NA`) be handled in rule 5?**
- Options considered:
  - **Option A — Use `is.finite(deff)` as the guard, covering all non-finite cases.**
  - **Option B — Document only practical cases.**
- **Decision:** Option A — `is.finite(deff)`.
- **Rationale:** `Var_SRS = 0` (constant variable) can produce `Inf`; both variances = 0 produces `NaN`. One-line guard eliminates all degenerate cases.

**Q: What is `na.rm = FALSE` behavior for the Kish method?**
- Options considered:
  - **Option A — Specify: NA weights produce `n_eff = NA`; NA group values treated as distinct group level.**
  - **Option B — Kish always excludes NAs; `na.rm` passes to DEFF only.**
- **Decision:** Option A — specify `na.rm = FALSE` behavior explicitly.
- **Rationale:** `na.rm` is a single shared argument for both methods. Giving it different semantics by method would surprise users. NA propagation is sensible and natural for Kish.

**Q: Which weight vector should the Kish numerical validation test use?**
- Options considered:
  - **Option A — `weights(d_sc)` (design-level analysis weights).**
  - **Option B — `nhanes_2017$wtmec2yr[!is.na(...)]` (NA-filtered raw column).**
- **Decision:** Option A — `weights(d_sc)`.
- **Rationale:** The function uses the design's analysis weights, not the raw column. Using the raw column creates a silent mismatch if the design performs any internal weight transformation.

### Outcome

Spec bumped to version 0.3. All 10 code review issues resolved (2 blocking,
8 required). The spec is fully approved for implementation.

---

## 2026-05-05 — Stage 3 plan review resolve: get_effective_n()

### Context

Resolved 6 issues from the Stage 2 plan review (Pass 1). Issues covered a
blocking guard bug, one unresolved open question about NSE forwarding, missing
test coverage for EN-4, and minor completeness gaps.

### Questions & Decisions

**Q: What guard should protect the `n_eff = n / deff` computation?**
- Options considered:
  - **Option A — `ifelse(is.finite(deff) & deff > 0, n / deff, NA_real_)`:**
    Explicit two-condition guard; self-documenting; covers Inf, NaN, NA, 0,
    and negative deff.
  - **Option B — `ifelse(deff > 0, n / deff, NA_real_)`:** Simpler; `NA > 0`
    is `NA` (falsy in `ifelse`) so NA propagates correctly.
- **Decision:** Option A — explicit two-condition guard.
- **Rationale:** `is.finite(0)` is `TRUE` in R, so the single `deff > 0` guard
  silently allows `deff = 0` to become `Inf`. Option A makes the intent
  unambiguous and matches the spec's language about "non-finite" conditions.

**Q: How should an already-resolved NSE `x` be forwarded into `get_means()` in the DEFF branch?**
- Options considered:
  - **Option A — `rlang::inject(get_means(design, !!rlang::sym(x_name), ...))`:**
    Uses the established codebase pattern (see `analysis-t-test.R:756–769`).
  - **Option B — Pass `x_name` character string directly via a formula interface.**
- **Decision:** Option A — `rlang::inject()` + `!!rlang::sym(x_name)`.
- **Rationale:** Direct match to `get_pairwise()` → `get_t_test()` forwarding
  at `analysis-t-test.R:756`. Consistent with codebase; no formula-interface
  workaround needed.

**Q: Does `min_cell_n` need explicit type validation?**
- **Decision:** No explicit validation — follows the convention of all other
  `get_*()` functions, which use `min_cell_n` directly in comparisons; unexpected
  types produce informative R errors naturally.

**Q: Does `.apply_decimals()` skip integer columns automatically?**
- **Decision:** Yes — confirmed via codebase inspection (`analysis-helpers.R:718`).
  `.apply_decimals()` guards with `is.double(result[[i]])`, so integer `n`
  columns are untouched. No special handling required.

### Outcome

All 6 plan-review issues resolved (1 blocking, 4 required, 1 suggestion).
Implementation plan approved. Ready for `/r-implement` on `feature/effective-n`.

---
