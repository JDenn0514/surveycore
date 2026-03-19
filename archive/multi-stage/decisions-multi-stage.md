# Decisions Log — surveycore multi-stage

This file records planning decisions made during multi-stage.
Each entry corresponds to one planning session.

---

## 2026-03-12 — Methodology lock: multi-stage variance + FPC semantics

### Context

Resolved 14 methodology review issues from `plans/spec-methods-review-multi-stage.md`.
12 were unambiguous fixes; 2 required judgment calls. One judgment call (Issue 12 —
CI approximation) was resolved by investigating the existing code and documenting
the status quo rather than choosing between undocumented options.

### Questions & Decisions

**Q: Issue 7 — Should the `cli_inform()` for partial FPC be upgraded to `cli_warn()`?**
- Options considered:
  - **Option A — Document + verify:** Add citation that behavior matches `survey` oracle,
    note SE inflation is conservative, confirm inform level is appropriate.
  - **Option B — Upgrade to `cli_warn()`:** More visible alert; new warning class needed.
- **Decision:** Option A — document and verify; keep `cli_inform()`.
- **Rationale:** The partial FPC consequence is conservative SE inflation (not bias toward
  zero), so users are not misled about the direction of the approximation error. Inform
  is the correct level; a warning would imply something is wrong, when the behavior is
  actually a reasonable and documented approximation. Oracle tests must verify numerical
  equivalence with `survey::svydesign(fpc = ~fpc1)`.

**Q: Issue 12 — How do surveycore Taylor CIs compare to the `survey` package?**
- Options considered:
  - **Option A — Document status quo:** Note normal approx (Inf df) for Phase 1 functions;
    note quantiles use finite df; defer df-adjusted Phase 1 CIs to future phase.
  - **Option C — Do nothing:** Leave undocumented.
- **Decision:** Investigated code (`analysis-helpers.R:690`, `.degf_woodruff()`); documented
  the status quo accurately. Phase 1 functions use Inf df (matches `survey::svymean()`
  default printout, diverges from `confint()` which uses finite df). Quantiles already use
  finite df via `.degf_woodruff()`.
- **Rationale:** User requested investigation before documenting. Code comments confirm the
  behavior is intentional and the normal approximation matches survey defaults. Finite-df
  CIs for Phase 1 are deferred to a future phase.

### Outcome

Spec is at version 0.2 (methodology-locked). All 14 methodology review issues resolved.
The blocking issue (Issue 1: `keep` parameter biasing multi-stage sampsize) is fixed in §VI.
Spec ready for Stage 3 code/architecture review.

---

## 2026-03-12 — Stage 4 code review resolve: 12 issues

### Context

Resolved all 12 issues from `plans/spec-review-multi-stage.md` Pass 1.
Two issues involved genuine trade-offs (Issues 4 and 12); the rest were
unambiguous fixes.

### Questions & Decisions

**Q: Issue 4 — Should `glm.R` FPC access be replaced with `.build_cluster_matrices()` (Option A) or guarded with an unsupported error (Option B)?**
- Options considered:
  - **Option A — Full refactor:** Add `R/glm.R` to §II inventory; replace inline `data[[vars$fpc]]` with `.build_cluster_matrices()`. GLM gains multi-stage support. Requires adding oracle tests for multi-stage GLM.
  - **Option B — Explicit unsupported error:** Add `surveycore_error_multistage_glm_unsupported` guard when `length(vars$ids) > 1`. Scope out multi-stage GLM with a clear error. Recommended by the reviewer as safer.
- **Decision:** Option A — full refactor.
- **Rationale:** User chose to include `glm.R` in the refactor rather than scope it out. §VIII.5 added with the replacement pattern and oracle tests.

**Q: Issue 12 — Should the `print()` FPC display be deferred (Option A) or updated in this phase (Option B)?**
- Options considered:
  - **Option A — Document deferral:** Add a note to §II that `FPC: fpc1 fpc2` is acceptable for now; per-stage display deferred.
  - **Option B — Update methods-print.R:** Per-stage FPC bullets: `FPC (stage 1): fpc1 / FPC (stage 2): fpc2`. ~30 min, moderate risk.
- **Decision:** Option B — update print method in this phase.
- **Rationale:** User chose to implement the per-stage display now. §IX.5 added with the implementation pattern and snapshot test requirement.

### Outcome

Spec is at version 0.3 (approved). All 12 code review issues resolved (2 blocking,
7 required, 3 suggestions). Spec ready for `/implementation-workflow`.

---

## 2026-03-13 — Plan review resolve: 9 issues

### Context

Resolved all 9 issues from `plans/plan-review-multi-stage.md` Pass 1 (1 blocking,
5 required, 3 suggestions). One issue (7) involved a meaningful design choice about
the regression test strategy.

### Questions & Decisions

**Q: Issue 7 — Should the PR 4 regression test compare against pre-captured surveycore
values or against `survey::svymean()` directly?**
- Options considered:
  - **Option A — Pre-capture approach (original plan):** Capture NHANES BPXSY1 values
    from current `develop`; write test with those values; if SE changes post-refactor,
    capture new value and verify against survey oracle before updating.
  - **Option X — Oracle-direct (recommended):** Write the regression test using
    `survey::svymean()` as oracle directly. If post-refactor values diverge from the
    oracle, that's a bug. No pre-implementation capture step needed.
- **Decision:** Option X — oracle-direct.
- **Rationale:** The refactor intends to match `survey` package semantics; if it
  produces different values than `survey::svymean()`, something is wrong. The
  pre-capture approach only guards against "values changed from before" — it doesn't
  distinguish between a correct change and a bug. Oracle-direct is always meaningful.
  Aligns with how all other oracle tests in the plan are written (PR 5 pattern).

### Outcome

Plan is approved. All issues from `plans/plan-review-multi-stage.md` resolved.
Ready for `/r-implement` — start with PR 1 in the PR map.

---
