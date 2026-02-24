# Claude Decisions Log — surveycore Phase 0.75

This file records planning decisions made during implementation of Phase 0.75.
Each entry corresponds to one planning session.

---

## 2026-02-24 — Spec Review Resolution (Issues 1–15)

### Context

Resolved all 15 issues from the adversarial spec review (`plans/spec-review-phase-0.75.md`)
against `plans/phase-0.75-formal-specification.md`. Six issues were BLOCKING, six REQUIRED,
and three SUGGESTIONs. All were resolved in a single session.

### Questions & Decisions

**Q: Issue 1 — Which row number is `surveycore_warning_subset_na` in `error-messages.md`?**
- Options considered:
  - **Warning 26:** what the spec said throughout
  - **Warning 23b:** the actual row in `plans/error-messages.md`
- **Decision:** Warning 23b. All 7 occurrences of "Warning 26" in the spec replaced globally.
- **Rationale:** Confirmed by reading `error-messages.md` directly. An implementer following
  the old numbering would delete the wrong row.

**Q: Issue 2 — What happens to Warning 25 (`surveycore_warning_full_no_phase2`) after Phase 0.75?**
- Options considered:
  - **Remove it:** estimation-time error is sufficient; the warning creates a design object
    the user cannot use (confusing UX)
  - **Retain it:** "advance notice" at construction + error at estimation
- **Decision:** Remove Warning 25 from the constructor. The estimation-time error
  `surveycore_error_full_requires_phase2` is the sole check.
- **Rationale:** Silent construction followed by an unusable object is a poor pattern.
  Aligns with engineering-preferences.md §5 (explicit over clever).

**Q: Issue 3 — How should `.twophase_phase1_var()` build design matrices for `.svy_recvar()`?**
- Options considered:
  - **[A] Extract shared helper** `.build_taylor_matrices()` reused by both Taylor and two-phase — eliminates duplication permanently
  - **[B] Acknowledge duplication, document steps, defer refactor to Phase 1**
- **Decision:** B. Duplication accepted for Phase 0.75; matrix-building steps documented
  explicitly in Section 4.3; tech debt note added.
- **Rationale:** Option A adds scope. The spec now describes the steps so an implementer
  can build it correctly; the duplication risk is low with only one new call site.

**Q: Issue 4 — Where should `[1L, 1L]` matrix extraction happen?**
- Options considered:
  - **[A] In `.twophase_phase1_var()` and `.twophase_phase2_var()`** (each returns scalar)
  - **[B] In `.twophasevar()` itself** before returning
- **Decision:** A. Phase variance helpers return scalars; `v1 + v2` is scalar arithmetic.
- **Rationale:** Cleaner contract — callers of the sub-functions always get a scalar.

**Q: Issue 5 — When `na.rm = FALSE` and y has NAs, does influence contain NA or 0?**
- Options considered:
  - **[A] Influence is NA → NA propagates to NA variance** (matches survey behavior)
  - **[B] Influence is 0 → excluded contribution** (effectively same as na.rm = TRUE)
- **Decision:** A, confirmed by inspecting `survey` package source. `survey::svymean()` with
  `na.rm = FALSE` returns NA for both coef and SE via NA propagation through `twophasevar`.
- **Rationale:** Defer to the survey package's established behavior; simplest to implement.

**Q: Issue 6 — Is `@variables$phase2$fpc` used in Phase 0.75 variance computation?**
- Options considered:
  - **[A] Explicitly ignore it** (reserved for future)
  - **[B] Specify how it enters `.svy_recvar()` for Phase 2**
- **Decision:** B. The survey package passes `phase2$fpc` directly to `svyrecvar`. When
  `fpc2=NULL`, survey auto-computes Phase 2 population sizes by counting unique Phase 2 PSU
  IDs per stratum across all Phase 1 units (`ave(!duplicated(cluster), stratum, FUN = sum)`).
  The FPC correction factor is `(N - n) / N` in `onestrat()`.
- **Rationale:** If the constructor stores it, it should be used. Confirmed by reading
  survey package source.

**Q: Issue 7 — Should `nest = TRUE` df path be tested?**
- Options considered:
  - **[A] Add inline test** (2 strata × 5 PSUs, expected df = 8)
  - **[B] Note as out of scope**
- **Decision:** A. Added inline test to Section 9.3.
- **Rationale:** One test, low cost, prevents a subtle df bug. Will fail coverage gate if omitted.

**Q: Issue 9 — Does `test_invariants()` need to be extended for `survey_twophase`?**
- Options considered:
  - **[A] Extend with a dispatch branch**
  - **[B] Define a separate helper**
- **Decision:** Neither — `test_invariants()` already handles `survey_twophase` in
  `helper-test-data.R` (lines 253–319), dispatching on `S7::S7_inherits(design,
  survey_twophase)` and checking nested `phase1`/`phase2` variables, weight positivity,
  logical subset column, and metadata. No changes needed in Phase 0.75.
- **Rationale:** The review was written against an older version; the codebase is ahead.

**Q: Issue 10 — Which nwtco oracle construction is correct?**
- Options considered:
  - **[A] Update `d_sc` to use `ids = seqno` and `strata2 = rel`** — matches survey oracle
  - **[B] Simplify both designs to no-PSU/no-strata**
- **Decision:** A. The `d_sc` construction updated to use `ids = seqno` in Phase 1 and
  `strata2 = rel` in Phase 2. The survey oracle already used `seqno` and `rel`.
- **Rationale:** Oracle should test a realistic design. Simpler construction would fail
  to validate stratified Phase 2 sampling.

**Q: Issue 13 — Should oracle tests call `test_invariants()`?**
- Options considered:
  - **[A] Add `test_invariants(d_sc)` to oracle setup blocks**
  - **[B] Exempt oracle tests (following Taylor pattern)**
- **Decision:** B. The existing Taylor oracle tests in `test-variance-estimation.R` never
  call `test_invariants()`. Phase 0.75 oracle tests follow the same pattern.
- **Rationale:** Oracle tests validate numerical accuracy, not constructor correctness.
  The rule applies to tests whose primary purpose is constructor verification.

**Q: Issue 14 — Return type of `.twophase_df()`: integer or numeric?**
- Options considered:
  - **[A] Cast to integer** via `as.integer()`
  - **[B] Specify as numeric**
- **Decision:** A. `as.integer()` cast added to the Section 5.6 implementation.
  Test description updated to "nonnegative integer (class integer)".
- **Rationale:** Matches how df values are used in the survey package. Explicit is better
  than relying on duck-typing.

**Issues resolved with the recommended option without discussion:**
- Issue 8: Already resolved as side effect of Issue 2
- Issue 11 (A): Full column schema table added to Section 9.2
- Issue 12: Already resolved as part of Issue 2's Section 3.4 edits
- Issue 15 (B): `.compute_phase2_probs()` called unconditionally — inefficiency accepted

### Outcome

All 15 review issues resolved. The spec is ready for implementation. Next step:
`/implementation-workflow` to produce the Phase 0.75 implementation plan.

---

## 2026-02-24 — Spec Review Resolution (Issues 16–21, Round 2)

### Context

Resolved 6 new issues from Round 2 of the adversarial spec review against the updated
`plans/phase-0.75-formal-specification.md`. One BLOCKING, four REQUIRED, one SUGGESTION.

### Questions & Decisions

**Q: Issue 16 — Column naming conflict: spec schema used `weight` but generator uses `wt`.**
- Options considered:
  - **[A] Keep `wt`, fix the schema and usage example** — no existing tests broken
  - **[B] Rename `wt` → `weight` globally** — consistent but high blast radius
- **Decision:** A. Schema table, usage example, and description updated to `wt`.
  Only `phase2_ind` → `subset` rename applied to the two-phase branch.
- **Rationale:** Renaming `wt` globally would require updating all existing tests. The
  schema entry was a documentation error, not a design intent.

**Q: Issue 17 — `make_all_designs()` in `helper-test-data.R` not in Section 3.4 affected-files.**
- Options considered:
  - **[A] Add it explicitly** with the specific one-line change
  - **[B] Leave it for the implementer to discover**
- **Decision:** A. `helper-test-data.R` added to Section 3.4 table with the exact
  change: `suppressWarnings(as_survey_twophase(phase1, subset = phase2_ind))` →
  `as_survey_twophase(phase1, subset = subset, method = "approx")`.
- **Rationale:** Engineering-preferences.md §5 — explicit over clever. Low effort, prevents
  a confusing test failure.

**Q: Issue 18 — Phase 2 sampling in generator: Bernoulli vs. stratified SRS.**
- Options considered:
  - **[A] Specify stratified SRS, replace Bernoulli**
  - **[B] Keep Bernoulli, document it explicitly**
- **Decision:** B. Spec now states Bernoulli sampling is used and notes oracle tests
  use real datasets, so the distinction is immaterial for test accuracy.
- **Rationale:** Bernoulli is simpler and the generator is not used in oracle tests.

**Q: Issue 19 — `sampsize` matrix for Phase 2 FPC never specified.**
- Options considered:
  - **[A] Add explicit `sampsize` construction to Section 4.4**
  - **[B] Reference the Taylor code for sampsize logic**
- **Decision:** A. Section 4.4 now explicitly specifies `sampsize` matrix construction
  (unique Phase 2 PSU IDs per stratum among `subset == TRUE` rows) and replaces the
  vague "via `as.fpc()` equivalent" with concrete per-case prose.
- **Rationale:** Phase 2 FPC construction is already complex; `sampsize` ambiguity
  would likely produce an implementation error.

**Q: Issue 20 — No `test-variance-dispatch.R` test blocks for `survey_twophase` dispatch.**
- Options considered:
  - **[A] Add two test block descriptions** (one for `get_means()`, one for `get_totals()`)
  - **[B] Rely on oracle tests as double-duty coverage**
- **Decision:** A. Section 9.1a added with two dispatch test block descriptions using
  synthetic data; no `skip_if_not_installed()` required.
- **Rationale:** The quality gate in Section 11 explicitly cites `test-variance-dispatch.R`
  for the dispatch path. Oracle tests validate numerics; dispatch should be tested separately.

**Q: Issue 21 — Phase 1 weight extraction path unstated in `.twophase_phase2_var()`.**
- Decision: No change. The extraction is obvious from the S7 design structure. Adding
  it would be documentation noise.

### Outcome

All 6 Round 2 issues resolved. Spec is finalized. Next step: `/implementation-workflow`
to produce the Phase 0.75 implementation plan.

---
