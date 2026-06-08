# Decisions Log — surveycore nonprob-bootstrap-variance

This file records planning decisions made during nonprob-bootstrap-variance.
Each entry corresponds to one planning session.

---

## 2026-05-18 — Methodology lock: bootstrap variance for survey_nonprob

### Context

Resolved 23 methodology issues from Stage 2 pass 1. Issues covered variance
scaling defaults, type restrictions, df policy for CI construction, domain
estimation, and documentation of deviations from the `survey` package. Five
judgment calls required user input; the rest were unambiguous fixes.

### Questions & Decisions

**Q: Should `as_survey_nonprob()` accept the full replicate type set (JK1, BRR, etc.) or restrict to `type = "bootstrap"` only?** *(Issues 1 + 3, linked)*
- Options considered:
  - **Type-dependent scale switch (keep full set):** Accept all types, use a shared `.default_rep_scale(type, n_rep)` helper for correct per-type scale defaults. Still requires documenting the `mse = TRUE` footgun for jackknife.
  - **Restrict to `"bootstrap"` only:** Block all other types with `surveycore_error_type_invalid`. Simplifies scale default to constant `1/R`. Eliminates the jackknife-mse footgun entirely.
- **Decision:** Restrict to `type = "bootstrap"` only.
- **Rationale:** Jackknife variance is statistically invalid for non-probability samples (Wu 2022). `mse = TRUE` is correct only for bootstrap centering. `surveywts` produces only bootstrap repweights for NPS inputs. The restriction eliminates two footguns and simplifies the scale default. If future NPS variance methods are added, `type` can be extended at that time.

**Q: What degrees-of-freedom value should `.degf()` return for repweight-equipped `survey_nonprob`?** *(Issue 9, BLOCKING)*
- Options considered:
  - **`degf = Inf` (normal approximation):** Does not falsely imply a known probability design structure. Matches existing `get_*()` behavior (all six analysis functions hardcode `degf <- Inf`). Matches the normal approximation that NPS literature supports.
  - **`degf = R - 1`:** Parallels `survey_replicate`. Methodologically questionable — implies NPS bootstrap replicates map onto a probability-sample design df, which the literature does not support.
- **Decision:** `degf = Inf` for repweight-equipped `survey_nonprob`.
- **Rationale:** `degf = Inf` is the intellectually honest position. Design-based df are not defined for non-probability samples (Wu 2022 §4.2). Using `R - 1` would falsely imply a known probability design structure. The normal approximation is consistent with all `get_*()` functions and is what NPS practitioners expect.

**Q: Should the quality gate tolerance for internal consistency (survey_nonprob vs survey_replicate) use `expect_identical()` or `1e-8`?** *(Issue 8)*
- Options considered:
  - **`expect_identical()` (bitwise):** Both paths call the same helper with the same inputs. Floating-point exact agreement is achievable and catches dispatch errors that tolerance-based checks miss.
  - **`1e-8` tolerance:** Consistent with the project's existing SE tolerance from `testing-surveycore.md`. Simpler.
- **Decision:** `expect_identical()` for the internal consistency gate; `1e-8` kept for comparisons against the external `survey` package.
- **Rationale:** The internal consistency test is checking that dispatch is correct (same helper, same inputs → same output), not numerical accuracy against an independent implementation. Bitwise identity is achievable and is a stronger correctness signal.

**Q: Should NA-dropped replicates in small NPS domains emit a warning or be silently accepted?** *(Issue 14)*
- Options considered:
  - **Threshold-based warning in replicate helpers (>5% of R):** Emit `surveycore_warning_domain_replicates_na` when called on a `survey_nonprob` object. Prevents silent wrong SEs on small NPS domains. Requires modifying the six replicate helpers (contradicts original "no modification needed" claim).
  - **Document the limitation only:** Add a note to the spec. Accept inherited behavior. No code change.
- **Decision:** Add the threshold-based warning to the six replicate helpers (Option A).
- **Rationale:** Small-domain NPS analysis is a primary use case. NA-dropped replicates produce understated SEs without any indication. The warning costs little and prevents a meaningful accuracy hazard. The "no modification needed" claim in the spec has been updated accordingly.

**Q: Should the spec document the full-sample vs. domain-restricted re-calibration distinction for domain estimation?** *(Issue 15)*
- Options considered:
  - **Add clarifying sentence:** "Replicate weights from `surveywts::create_bootstrap_weights()` are full-sample calibration replicates. Domain SEs reflect full-sample calibration uncertainty; domain-restricted re-calibration is out of scope."
  - **Do nothing:** Full-sample re-raking is standard; distinction is implicit.
- **Decision:** Add the clarifying sentence to Background.
- **Rationale:** Users analyzing small subgroups from calibration-heavy NPS designs may over-interpret subgroup SEs. One sentence removes this ambiguity at no cost.

### Outcome

Spec is methodology-locked at version 1.1. The bootstrap-only type restriction
is the most structurally significant change: it simplifies the constructor,
eliminates two footguns, and matches the actual `surveywts` workflow. The df
policy (`Inf` for all `survey_nonprob`) and the NA-drop warning for small
domains are the two other changes with implementation impact beyond pure
documentation. Twenty-three issues resolved: 13 unambiguous fixes, 5 judgment
calls (Issues 9, 1+3, 8, 14, 15). Spec is ready for Stage 3 code review.

---

## 2026-05-18 — Post-lock addition: reference_sample property and @calibration schema

### Context

After methodology lock, the question arose whether `survey_nonprob` should
store the reference probability sample used for propensity weighting. The
original spec removed `calibration = boot$provenance` from the workflow diagram
because `boot$provenance` doesn't exist on current `surveywts` return types.
The user confirmed surveywts should be updated to support both raking and
propensity bootstrap, making it worth defining the provenance contract now.

### Questions & Decisions

**Q: Should `survey_nonprob` store the reference probability sample?**
- Options considered:
  - **No:** Pass reference sample to `surveywts::create_bootstrap_weights()` explicitly each time. Keeps `survey_nonprob` lightweight.
  - **Yes, store in new `@reference_sample` property:** Makes `create_bootstrap_weights(design)` self-contained for both raking and propensity workflows. No extra argument needed at bootstrap time.
- **Decision:** Add `@reference_sample` S7 property and `reference_sample` constructor argument.
- **Rationale:** Propensity bootstrap requires re-fitting the propensity model on each draw, which requires the reference sample. Storing it in the object avoids requiring the user to carry two separate objects and pass the reference sample redundantly. For raking, the field is NULL (no overhead).

**Q: What schema should `@calibration` follow?**
- **Decision:** Define a required named-list schema with five keys: `method`, `R`, `repweight_prefix`, `bootstrap`, `surveywts_version`. `surveywts` writes this; surveycore reads it for validation and display.
- **Rationale:** The minimum surveycore needs is: (1) confirmation that repweights were produced by re-running the adjustment procedure (`bootstrap = TRUE`), (2) `R` to validate against `length(repweights)`, (3) `method` for the print method. The schema is surveycore-facing; surveywts can store additional fields as needed.

### Outcome

Spec bumped to version 1.2. Two new S7 properties added to `survey_nonprob`:
`@reference_sample` and a schema for the existing `@calibration`. Four new
error classes: `surveycore_error_reference_sample_nonprob`,
`surveycore_error_provenance_not_bootstrap`,
`surveycore_error_provenance_R_mismatch`. Workflow diagram now shows both
raking and propensity paths with `calibration = boot$provenance` restored.

---

## 2026-05-19 — Code review resolve: Stage 4 (spec v1.2 → v1.3)

### Context

Worked through 11 code review issues from the Stage 3 pass (spec-review-nonprob-bootstrap-variance.md). All recommended options were accepted. Key architectural additions: a shared internal helper for NA-drop warnings, unconditional `Inf` df for all `survey_nonprob`, and explicit `rscales` NA validation closing a gap in both constructors.

### Questions & Decisions

**Q: Should Goal 4 be removed or narrowed given that §3 requires targeted modifications to the six replicate helpers?** *(Issue 1)*
- Options considered:
  - **Narrow:** Update Goal 4 to say the variance *calculation* is unchanged but a `.nonprob_rep_na_warn()` call is added to each helper.
  - **Remove:** Delete Goal 4 entirely.
- **Decision:** Narrow Goal 4 (Option A).
- **Rationale:** Goal 4's design rationale (no change to variance computation path) is worth preserving; the contradiction arose because the NA-drop warning was added during methodology lock but Goal 4 wasn't updated. The narrowed text is now accurate.

**Q: Should the NA-drop warning + all-NA early return be inlined in each of the six replicate helpers, or extracted to a shared `.nonprob_rep_na_warn()` helper?** *(Issue 8, combined with Issue 7)*
- Options considered:
  - **Extract:** `.nonprob_rep_na_warn(design, na_frac, na_dropped, R, scale)` in `R/analysis-helpers.R`, returning `NULL` for normal flow or an early-return list for `na_frac == 1.0`.
  - **Copy-paste:** Inline the identical block in each of the six helpers.
- **Decision:** Extract to shared helper (Option A for both issues).
- **Rationale:** Six identical code blocks is a clear DRY violation per engineering-preferences.md §1. The `na_frac == 1.0` all-NA early return (Issue 7) is also included in the helper to avoid a second wave of 6-way duplication. The helper is NPS-gated — `survey_replicate` designs receiving all-NA replicates still reach `.svy_rep_var()` and error, preserving the existing semantics for probability samples.

**Q: Should `.degf()` return `Inf` only for repweight-equipped `survey_nonprob`, or for all `survey_nonprob` regardless of repweights?** *(Issue 9)*
- Options considered:
  - **All NPS:** `if (S7::S7_inherits(design, survey_nonprob)) return(Inf)` — unconditional.
  - **Repweights only:** Keep `n - 1` fallback for no-repweights NPS (as §4 originally specified).
- **Decision:** Return `Inf` for all `survey_nonprob` (Option A).
- **Rationale:** The Design Decisions section is correct: design-based df are not defined for non-probability samples regardless of whether bootstrap repweights are present. The `n - 1` fallback was inherited from the Phase 2.5 skeleton and was always a placeholder. One existing test (`test-glm-numerical.R:499–506`) must be updated to expect `Inf` — this is a fix to the test, not a regression in behavior.

**Q: Should `rscales` NA/non-numeric/negative validation be added to the spec, given the same gap exists in `as_survey_replicate()`?** *(Issue 5)*
- Options considered:
  - **Add validation:** Extend `.validate_rscales()` to check NA-free, numeric, and non-negative. New error class `surveycore_error_rscales_na`. Fixes both `as_survey_nonprob()` and `as_survey_replicate()`.
  - **Defer:** Note the gap and leave for a future hardening pass.
- **Decision:** Add validation (Option A).
- **Rationale:** The shared `.validate_rscales()` helper is the right fix point. Adding NA/numeric/non-negative checks there prevents silent wrong variance in both constructors with a single change. The new error class is straightforward.

### Outcome

Spec bumped to version 1.3 and marked Approved. Key changes: `.nonprob_rep_na_warn()` extracted to `R/analysis-helpers.R`; `.degf()` returns `Inf` unconditionally for all `survey_nonprob`; `surveycore_error_rscales_na` added to §6 and error paths; `na_frac`/`na_dropped` formulas and per-helper variable names documented in §3; dual-pattern snapshot tests required for all 8 constructor errors; happy-path routing tests added for `get_freqs()`, `get_totals()`, `get_corr()`, `get_covariance()`, `get_quantiles()`, `get_ratios()`.

---

## 2026-05-19 — Code review resolve: Stage 4 Pass 2 (spec v1.3 → v1.4)

### Context

Worked through 7 new code review issues from Pass 2 of the Stage 3 review (spec-review-nonprob-bootstrap-variance.md Issues 12–18). All recommended options were accepted. Key fixes: resolved a blocking self-contradiction in the `.nonprob_rep_na_warn()` return value, fixed a second df inconsistency (`.degf_woodruff()` for no-repweights NPS), and clarified constructor validation layer (all four provenance/reference_sample checks moved explicitly to Layer 3).

### Questions & Decisions

**Q: Should `.nonprob_rep_na_warn()` return a generic `list(estimate, se)` or a sentinel `TRUE` for the all-NA early exit?** *(Issue 12, BLOCKING)*
- Options considered:
  - **Sentinel `TRUE`:** Helper returns `TRUE` on `na_frac == 1.0`; each caller checks `isTRUE(...)` and returns its own correctly-shaped NA result. Helper owns the warning + gate logic; callers own return shape.
  - **Return generic list:** Helper returns `list(estimate = NA_real_, se = NA_real_)`; caller does `return(early_out)`. Produces wrong return shape for helpers like `.replicate_mean_cell()` that return `mean`, `n`, CI fields, etc.
- **Decision:** Sentinel `TRUE`.
- **Rationale:** A generic list is incompatible with the spec's own note that "each helper must return its own NA-filled result structure." The sentinel cleanly separates concerns.

**Q: Should `.degf_woodruff()` return `Inf` only for repweight-equipped `survey_nonprob`, or for all `survey_nonprob`?** *(Issue 13, REQUIRED)*
- Options considered:
  - **All NPS:** Unconditional `Inf` for any `survey_nonprob` in `.degf_woodruff()`. Consistent with Design Decisions and with §4 (`.degf()` already unconditional).
  - **Repweights-only:** Keep `n - 1` for no-repweights NPS in `.degf_woodruff()`. Documents inconsistency between `get_quantiles()` and all other `get_*()`.
- **Decision:** All NPS unconditionally.
- **Rationale:** `n - 1` has no statistical meaning for any NPS object; the inconsistency with `.degf()` was a spec oversight carried in from the initial "repweights-only" framing.

**Q: Should provenance and `reference_sample` checks live in the S7 validator (Layer 1) or the constructor (Layer 3)?** *(Issue 15, REQUIRED)*
- Options considered:
  - **Layer 3 (constructor):** Checks via `cli_abort()` in `as_survey_nonprob()`. Dual test pattern. Consistent with `as_survey_replicate()` handling of `surveycore_error_design_var_missing`.
  - **Layer 1 (S7 validator):** Checks in `validator = function(self) {...}`. `class=` only test pattern.
- **Decision:** Layer 3 (constructor).
- **Rationale:** All user-facing input validation in surveycore lives in constructors. The existing `surveycore_error_design_var_missing` reuse from `as_survey_replicate()` confirms the constructor is the right layer.

### Outcome

Spec bumped to version 1.4. Key changes: `.nonprob_rep_na_warn()` uses sentinel `TRUE` for all-NA early exit; `.degf_woodruff()` returns `Inf` for all `survey_nonprob` unconditionally; provenance and `reference_sample` checks explicitly placed in Layer 3; `@variables` no-repweights behavior (all five keys stored as `NULL`) made explicit; `rscales_na` test added to `as_survey_replicate()` path in `test-constructors.R`; manual numerical oracle test for bootstrap SE formula added to test plan; wording fix for argument insertion position.

---

## 2026-05-19 — Plan review resolve: Stage 3 (plan v1.0 → approved)

### Context

Worked through 7 plan review issues from the Stage 2 adversarial pass (plan-review-nonprob-bootstrap-variance.md). All recommended options were accepted. All decisions were unanimous with the recommended option.

### Questions & Decisions

**Q: Should PR 1 Step 1 also update the NB-2 (`surveycore_warning_nonprob_srs_fallback`) `"i"` bullet to match spec §6?** *(Issue 1, REQUIRED)*
- **Decision:** Yes — add the NB-2 text update to Step 1 explicitly.
- **Rationale:** The implementation follows the spec text; if `error-messages.md` holds different text, snapshot tests in PR 2 will fail with confusing output.

**Q: Should `helper-test-data.R` be added to PR 1's file list so that `test_invariants()` checks the 5 new `@variables` keys?** *(Issue 2, REQUIRED)*
- **Decision:** Yes — add `helper-test-data.R` to PR 1 file list; extend the `survey_nonprob` branch of `test_invariants()` to assert all 5 repweight keys present (values may be `NULL`).
- **Rationale:** Without this, `test_invariants(d)` passes even if the constructor writes repweight keys under wrong names or omits them entirely. The "all keys always present" invariant is load-bearing.

**Q: Should roxygen documentation requirements (4 spec-required sections) be added to PR 1 Step 7 and acceptance criteria?** *(Issue 3, REQUIRED)*
- **Decision:** Yes — add as an explicit sub-task in Step 7 and add an acceptance criterion listing the 4 required sections.
- **Rationale:** `devtools::document()` only verifies generation, not content. The spec has "must" language for all four; keeping them in the same PR as the implementation makes correctness easier to verify.

**Q: Should PR 2 Step 1 require an all-NA early-return test for `get_means()` to force concrete NA return-shape definition?** *(Issue 4, REQUIRED)*
- **Decision:** Yes — add the all-NA test requirement to Step 1 with a concrete description of the domain setup and assertion.
- **Rationale:** TDD forces the return shape to be specified before implementation. Without a test, the early-return path produces malformed output silently if the wrong NA structure is used.

### Outcome

Plan approved. Four required gaps and three suggestions resolved: NB-2 text sync (PR 1 Step 1), `test_invariants()` extension (PR 1 file list), roxygen documentation (PR 1 Step 7 + AC), all-NA return shape test (PR 2 Step 1), Note 6 wording clarification, 98%+ coverage bullet added to all three PRs, `error-messages.md` coverage map update added to PR 1 and PR 2 ACs.

---
