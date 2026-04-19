# Decisions Log — surveycore get-anova

This file records planning decisions made during get-anova.
Each entry corresponds to one planning session.

---

## 2026-04-18 — PR C plan resolution (Stage 3 of implementation-workflow)

### Context

Worked through 18 issues from `plan-review-get-anova.md` (Pass 1): 1
BLOCKING, 8 REQUIRED, 9 SUGGESTION. Goal was to unblock PR C handoff to
`/r-implement` or `/auto-ship`.

### Questions & Decisions

**Q: Cross-design smoke tests reference `make_survey_data()`, which only
supports 3 of 5 design classes (BLOCKING).**
- Options considered:
  - **Use `make_all_designs()`:** purpose-built, returns all 5 designs.
  - **Inline per-design construction:** verbose, duplicates the helper.
- **Decision:** Use `make_all_designs()`; the `calibrated` slot is the
  `survey_nonprob` fixture.
- **Rationale:** DRY; `make_all_designs()` is the canonical cross-design
  iteration fixture already used by other verb tests.

**Q: `.validate_shared_args()` signature is incompatible with `get_anova()`
(no `variance` / `conf_level` on the surface).**
- Options considered:
  - **Factor a smaller helper** `.validate_decimals_namestyle()` out of
    `.validate_shared_args()`, reuse from both.
  - **Inline the validations** in `get_anova()` directly.
- **Decision:** Factor the helper (new work added to Task 1.2).
- **Rationale:** DRY is engineering preference #1; the focused helper
  will be reused by future analysis functions without a variance surface.

**Q: A-19 (replicate nonconvergence) trigger recipe is hand-wavy; is
there a `survey` oracle?**
- Options considered:
  - **Pin a deterministic `make_replicate_nonconverger()` fixture.**
  - **`skip_on_cran()` + accept flakiness.**
- **Decision:** Pin the deterministic fixture.
- **Rationale:** Inspection of `survey:::svyglm.svyrep.design` confirmed
  `survey` emits no typed warning for per-replicate nonconvergence
  (untyped `glm.fit: did not converge` at best). A-19 is original
  surveycore behavior with no oracle; flakiness across BLAS libs and R
  releases is unacceptable.

**Q: A-20 (domain mismatch) trigger requires mutating a nested S7 slot.**
- Options considered:
  - **Add `.testhelper_clobber_domain(fit, value)` helper** using
    `S7::set_props()`.
  - **Inline `S7::set_props()` chain in the test.**
- **Decision:** Add the helper.
- **Rationale:** Reusable for future negative tests that perturb
  `@design@data`; documents the supported mutation pattern.

**Q: Fay-BRR oracle recipe references `as_survey_repweights(..., rho =)`,
which doesn't exist in the surveycore API.**
- Options considered:
  - **Pin spec §VII recipe verbatim** (with caveat).
  - **Extend `make_survey_data()` with a `rho` argument.**
- **Decision:** Pin the recipe but flag the API gap — the real
  constructor is `as_survey_replicate()` with no `rho` argument. Route
  back to spec review before implementing this oracle block if
  `make_survey_data(type = "fay")` doesn't already encode ρ = 0.3.
- **Rationale:** Spec inaccuracy; don't silently paper over the
  nonexistent constructor. Extending the helper is out of scope.

### Minor fixes

- Added Task 1.0 precondition check verifying PR A/B outputs are on `develop`.
- Corrected "19 new rows" → "18 new rows" throughout.
- Added commit-boundary warning to Task 1.3 (`.onLoad()` depends on
  Task 3.2 symbol).
- Pinned label-attachment-before-`apply_name_style()` ordering in
  Task 3.1 step 4.
- Added explicit `expect_warning(class = "surveycore_warning_nonprob_inference")`
  wrappers for `survey_nonprob` cross-design blocks in Tasks 2.1 and 4.1.
- Pinned `withr::local_options()` for the non-default-contrasts edge case.
- Reworded `.reg_term_test()` n-invariance bullet to clarify it's the
  defensive `stopifnot()`, not the primary A-12 rownames check.
- Struck contradictory "should still fail" sentence in Task 3.4.
- Split A-5 into two `test_that()` blocks: firing vs. not-firing.
- Pinned `survey::twophase()` call shape for the two-phase oracle.
- Dropped `MEMORY.md` quality-gate line (in-repo `CLAUDE.md` already
  listed).
- Added `getS3method("anova", "surveycore::survey_glm_fit")` smoke check
  to Task 7.3.

### Outcome

`plans/impl-get-anova.md` is approved for handoff to `/r-implement` or
`/auto-ship`, with one open caveat: the Fay-BRR oracle in Task 6.1 may
need to return to spec review if `make_survey_data(type = "fay")` does
not already encode Fay's ρ = 0.3 internally.

---

## 2026-04-18 — PR C Pass 2 resolution (Stage 3, second session)

### Context

Pass 2 review surfaced 5 new issues (1 BLOCKING, 1 REQUIRED, 3 SUGGESTION).
Goal: close all before handoff per HARD-GATE.

### Questions & Decisions

**Q: Fay-BRR oracle left an unresolved "may need spec review" caveat —
does `make_survey_data(type = "fay")` encode ρ = 0.3? (BLOCKING)**
- Inspection of `helper-test-data.R:181-201` confirmed: the Fay branch is
  a lognormal-perturbed BRR clone, no ρ scaling.
- Options considered:
  - **Defer Fay-BRR oracle** to a follow-up PR; strike + FIXME.
  - **Compute Fay weights inline** via Hadamard matrix `H ∈ {-1, +1}`,
    formula `w_rep[, r] = w_0 * (1 - ρ + ρ * h[, r])`, feed pre-computed
    matrix to both surveycore (`as_survey_replicate(type = "BRR",
    scale = ρ^-2)`) and `survey::svrepdesign(type = "Fay", rho = 0.3)`;
    compare at `1e-6`/`1e-8`.
  - **Extend `make_survey_data()` with `rho`** — out of scope.
- **Decision:** Compute Fay weights inline in the test.
- **Rationale:** Keeps PR C's Fay coverage (regression for Pass 3
  Issue 64); `scale = ρ^-2` reproduces Fay's scale factor on a BRR
  replicate set; test spells out the recipe end-to-end and includes an
  escalate-to-spec-review rule if the workaround fails tolerance.

**Q: `.validate_shared_args()` refactor has high blast radius — when to
verify no regression? (REQUIRED)**
- Options considered:
  - **Post-refactor regression gate** before Task 1.3:
    `devtools::test(filter = "get-")`.
  - **Fold into Task 7.2** final check.
- **Decision:** Add the regression gate inline in Task 1.2.
- **Rationale:** Fail fast; breakage in a load-bearing shared helper
  should not ride through Cycle A masquerading as ANOVA-specific
  failures.

**Q: A-8 (saddlepoint) and A-13 (singular V₀) triggers — deterministic
or accept flakiness?**
- Options considered:
  - **Pin recipes:** A-13 via singleton-cell interaction; A-8 via direct
    unit test on `.pchisqsum_sad()` with eigenvalues `c(1, 1e-16)`.
  - **`skip_on_cran()` + accept flakiness.**
- **Decision:** Pin both recipes. A-8 tested at the helper layer
  (deterministic) and at the integration layer (snapshot).
- **Rationale:** Engineering-preference #4 (handle more edge cases);
  both triggers are cheap to pin deterministically. Separating the
  helper test from the integration test avoids funneling a pathological
  fit through the full pipeline.

### Minor fixes

- A-12 comparison-mode trigger now references
  `.testhelper_clobber_domain()` (defined in Task 2.1) to prevent
  parallel reinvention of the `S7::set_props()` chain.
- Added explicit label-preservation assertion for `name_style = "broom"`:
  `attr(result$p.value, "label") == "P-Value"` and
  `attr(result$df_residual, "label") == "Denom df"`. Regression guard
  against future `.apply_name_style()` refactors.

### Outcome

All Pass 2 issues resolved. Plan is handoff-ready to `/r-implement` or
`/auto-ship`. Previous Pass 1 caveat (Fay-BRR spec-review) closed by
the inline-recipe workaround.

---
