# Claude Decisions Log — surveycore Phase 1

This file captures planning questions and decisions made during Phase 1
(analysis functions: `get_freqs()`, `get_means()`, `get_totals()`,
`get_corr()`, `get_quantiles()`, `get_ratios()`) of the surveycore package.

A new entry is appended at the end of each planning session, before
implementation begins. See `../survey-standards/.claude/rules/changelog-workflow.md`
for format details.

---

<!-- New entries go below this line -->



## 2026-02-22 — Phase 1 Architecture + Code Quality Review (Session 1)

### Context

Pre-implementation review of `plans/phase-1-formal-specification.md` v1.1.
The goal was to surface spec gaps, design ambiguities, and class taxonomy
questions before writing any Phase 1 code. Review covered Architecture and
Code Quality sections (Test review is pending in a follow-up session).

---

### Questions & Decisions

**Q: `surveycore_error_invalid_conf_level` is introduced in the spec code
(Section 2.2) but is absent from `plans/error-messages.md` rows 43–53 and
from the coverage map.**

- Options considered:
  - **Fix now:** Add the missing row and coverage map entry to
    `error-messages.md` before implementation starts.
  - **Defer to implementation:** Leave a "when implementing, add this" note;
    the implementor handles it.
- **Decision:** Fix `error-messages.md` now.
- **Rationale:** The error table is described as authoritative. Leaving a
  class out of it before implementation starts is the exact pattern that
  creates undocumented errors. Five-minute fix with no downside.

---

**Q: Section 6.4 of the spec describes the SE formula for `get_corr()` as
`se_r = sqrt(1/(n-3))` via Fisher Z, then immediately says "For
`survey_taylor` and `survey_replicate`, variance uses the design's
linearization or replicate machinery." These two paragraphs describe
different methods for the same function.**

- Options considered:
  - **Clarify spec:** State explicitly that the simple formula is
    educational context only; the actual implementation always uses the
    design-based variance machinery from `R/06-variance-estimation.R`. The
    SRS numerical oracle validates that the two approaches agree for simple
    designs.
  - **Add numerical oracle for complex designs:** Invest in testing
    `survey::svycor()` behavior for NHANES-style complex designs. Limited
    by `survey::svycor()`'s incomplete complex-design support.
- **Decision:** Clarify the spec — the SRS formula is documentation context
  only; implementation always uses design-based variance.
- **Rationale:** An implementor reading the spec could reasonably use the
  SRS formula universally. That would produce silently wrong SEs for complex
  designs and pass all tests. Removing the ambiguity before implementation
  starts eliminates this risk entirely.

---

**Q: The Phase 1 spec defers `survey_twophase` support for all 6 analysis
functions to Phase 3, throwing `surveycore_error_unsupported_class`. But
the design intent is for all 6 functions to support all survey classes. The
two-phase variance code has not been vendored into `R/06-variance-estimation.R`.**

- Options considered:
  - **Phase 0.75 pre-work plan:** Vendor the two-phase variance code as a
    separate tracked effort before Phase 1 analysis functions are
    implemented. Phase 1 PRs then dispatch on `survey_twophase` from day
    one.
  - **Front-load into Phase 1:** Vendor two-phase variance in the first
    Phase 1 PR. Larger initial PR but no separate phase plan.
- **Decision:** Create a Phase 0.75 pre-work plan to vendor two-phase
  variance code as a distinct tracked effort before Phase 1 begins.
- **Rationale:** Keeps Phase 1 PRs modular and reviewable. The variance
  engine upgrade is its own unit of work — separating it makes both the
  upgrade and the analysis functions easier to review and test.

---

**Q: The 5-class survey object taxonomy — should `as_survey(df)` with no
design args return a `survey_taylor`, a new `survey_srs` class, or
something else? The current spec returns `survey_taylor`, which is
semantically confusing for a plain equal-probability sample.**

- Options considered:
  - **Add `survey_srs` class:** A new subclass of `survey_base` for
    equal-probability simple random samples. `as_survey(df)` creates it.
    Print clearly states "Simple Random Sample Design". ~20 lines of new
    code. All 6 Phase 1 functions dispatch on it.
  - **Keep `survey_taylor`:** Fix the print method to say "SRS design" when
    no PSUs/strata are present. Zero new code; class name stays semantically
    muddled.
- **Decision:** Add `survey_srs` as a Phase 0 gap fix.
- **Rationale:** Each class should represent a distinct statistical frame
  with clear semantics. `survey_taylor` implies a known complex probability
  design; `survey_srs` makes the equal-probability assumption explicit. The
  implementation cost is small; the communication benefit is real.

**Confirmed 5-class taxonomy:**

| Class | Represents | Weights | Variance method |
|---|---|---|---|
| `survey_srs` | Equal-probability random sample | Uniform (or user-supplied inverse-prob) | Standard SRS: `s²/n × (1-f)` |
| `survey_taylor` | Complex probability sample with known design | Design weights | Taylor linearization |
| `survey_replicate` | Complex sample with pre-computed replicate weights | Base + replicate weights | Replicate formula |
| `survey_twophase` | Two-phase probability sample | Phase 1 + 2 probabilities | Two-phase linearization (requires Phase 0.75) |
| `survey_calibrated` | Non-probability or post-hoc calibrated sample | Calibrated weights (raking, matching, propensity) | Weighted SRS approximation (conservative) |

**Constructor paths confirmed:**

| Call | Creates |
|---|---|
| `as_survey(df)` | `survey_srs` |
| `as_survey(df, weights = w)` | `survey_taylor` |
| `as_survey(df, ids = psu, weights = w, strata = s)` | `survey_taylor` |
| `as_survey_rep(df, weights = w, repweights = rw)` | `survey_replicate` |
| `as_survey_twophase(phase1, subset = s2)` | `survey_twophase` |
| `as_survey_calibrated(df, weights = w)` | `survey_calibrated` |

---

**Q: Should `survey_calibrated` be supported by Phase 1 analysis functions?
The MEMORY.md notes "Variance: SRS-based until Phase 2.5 (bootstrap
re-calibration deferred)." `survey_calibrated` does not store the original
sampling design structure (no PSUs, strata, FPC in `@variables`).**

- Options considered:
  - **Support with weighted SRS approximation:** Use the weighted SRS
    variance formula (`Σwᵢ²(yᵢ-ȳ)² / (Σwᵢ)²`). Conservative (overstates
    variance slightly) but usable. Standard practice for externally
    calibrated weights (e.g., `anesrake` output). Document the conservatism
    explicitly.
  - **Defer to Phase 2.5:** Keep throwing `surveycore_error_unsupported_class`
    until proper calibration variance (bootstrap re-calibration) is
    implemented.
- **Decision:** Support `survey_calibrated` in Phase 1 with weighted SRS
  approximation. Document that SEs are conservative until Phase 2.5.
- **Rationale:** Users with externally calibrated weights (post-stratified
  online panels, anesrake-weighted data, etc.) should be able to use Phase 1
  functions. The conservative SEs are the industry standard for this
  situation. Deferring until Phase 2.5 would block common use cases
  unnecessarily.

---

**Q: The spec uses `vctrs::vec_rbind()` in `.make_result_tibble()` to
assemble rows. Neither `vctrs` nor `dplyr` are in `DESCRIPTION Imports`.**

- Options considered:
  - **Column-by-column accumulation with `tibble` only:** Accumulate results
    as named vectors per column in the per-group loop; build the tibble at
    the end with `tibble::tibble()`. No `vctrs` dependency. Type-safe for
    scalar columns, which is all Phase 1 results contain.
  - **Add `vctrs` to Imports:** `vctrs` is MIT licensed, Posit-maintained,
    no external dependencies. `vec_rbind()` handles edge cases automatically.
  - **Port `vctrs::vec_rbind()`:** Risky — internals use C; pure R wrapper
    without the C loses correctness guarantees.
- **Decision:** Column-by-column accumulation with `tibble` only; update
  spec to describe this pattern.
- **Rationale:** Survey result assembly involves scalar-valued columns of
  known types. The column-by-column pattern is simpler, has fewer edge cases,
  and eliminates the dependency question. `vctrs` is more secure for complex
  mixed-type row binding but that complexity doesn't apply here. Speed
  difference at survey result scale (tens to hundreds of rows) is negligible.
  Update `phase-1-formal-specification.md` Section 2.2 to reflect this.

---

### Code Quality Decisions

**Q: The `variance` argument is currently a scalar (`NULL | "se" | "ci" |
"moe"`) with a `"both"` exception added only for `get_corr()` to get SE +
CI simultaneously. Should `variance` be redesigned? srvyr offers
`vartype = c("se", "ci", "var", "cv")` as a character vector.**

- Options considered:
  - **Character vector, full set:** `variance` accepts `NULL` or any
    combination of `c("se", "ci", "var", "cv", "moe")`. Eliminates the
    `"both"` exception entirely. Multiple uncertainty types in one call.
    Aligns with srvyr mental model. `"cv"` returns `NA` with
    `surveycore_warning_cv_undefined` when estimate is 0 or negative.
  - **Scalar, drop "both":** Keep scalar but restrict to `NULL | "se" |
    "ci" | "moe"` consistently. `get_corr()` users who want both SE and CI
    must restructure. Simpler implementation.
  - **Scalar matching srvyr exactly:** `NULL | "se" | "ci" | "var" | "cv"`.
    Drop `"moe"` (not in srvyr). Familiarity benefit; loses MOE which is
    common in polling/public reporting.
- **Decision:** Character vector with values from `c("se", "ci", "var",
  "cv", "moe")` — any combination allowed. `"cv"` fires
  `surveycore_warning_cv_undefined` when estimate is 0 or negative.
- **Rationale:** Eliminates the `"both"` exception and the associated
  error-class inconsistency. More flexible and explicit — users get exactly
  the columns they ask for. Aligns with srvyr users' expectations. Column
  ordering when multiple requested: `se`, `var`, `cv`, `ci_low`, `ci_high`,
  `moe`. Defaults by function remain unchanged (`"ci"` for most; `NULL` for
  `get_freqs()`).
- **Spec updates required:** Revise Section 2.6 `variance` argument table;
  update `.validate_shared_args()` signature and validation logic; update
  all per-function output column specs; add `surveycore_warning_cv_undefined`
  to `plans/error-messages.md`.

---

**Q: `get_freqs()` all-NA variable + `na.rm = TRUE` returns 0 rows but no
warning class is defined in Section X or `error-messages.md`. Project
convention requires `class=` on every `cli_warn()` call.**

- Options considered:
  - **Add `surveycore_warning_all_na_freqs`:** New row in `error-messages.md`.
    Typed, testable with `expect_warning(class=)`. Coverage map updated.
  - **Return 0 rows silently:** No warning, no class. Empty result is
    confusing without explanation.
- **Decision:** Add `surveycore_warning_all_na_freqs` to
  `plans/error-messages.md` with message template:
  `"All values of {.field {var}} are {.code NA} with {.arg na.rm = TRUE}. Returning 0 rows."`
- **Rationale:** An empty tibble returned silently is a user experience bug.
  Typed warning matches project convention and is testable.

---

**Q: `get_totals()` column spec in Section 5.2 shows `n` without brackets
(implying always present) but the spec text says `n` is omitted for
no-variable mode (`get_totals(d)`). The rows_list contract table already
correctly shows "`n` only when variable supplied."**

- **Decision:** Fix the column spec notation — change `n` to `[n]` in
  Section 5.2.
- **Rationale:** One-character fix that aligns the column spec with both
  the spec text and the rows_list contract table. Eliminates an
  implementation trap.

---

**Q: `meta_args` required keys are defined in three locations (spec table
in Section 2.2, each function's `meta_args <- list(...)` call, and the
`stopifnot()` check in `.make_result_tibble()`). Adding a new meta field
requires updates in all three places — DRY risk.**

- Options considered:
  - **Named key constants:** Define `FREQS_SINGLE_META_KEYS`,
    `MEANS_META_KEYS`, etc. as named constants at the top of
    `R/09-analysis-helpers.R`. `.make_result_tibble()` accepts
    `required_meta_keys` and validates against the constant. One place to
    update when fields change.
  - **Leave as-is:** Rely on `stopifnot()` and `meta()` contract tests to
    catch drift. `stopifnot()` messages are unhelpful; spec and code can
    silently diverge.
- **Decision:** Add named key constants as single source of truth
  (`FREQS_SINGLE_META_KEYS`, `FREQS_MULTI_META_KEYS`, `MEANS_META_KEYS`,
  `TOTALS_META_KEYS`, `CORR_META_KEYS`, `QUANTILES_META_KEYS`,
  `RATIOS_META_KEYS`).
- **Rationale:** Directly addresses DRY preference. ~8 lines of constants
  creates a single update point for meta contract changes. The `stopifnot()`
  validation becomes `stopifnot(all(required_meta_keys %in% names(meta_args)))`
  — readable and auditable.

---

### Outcome

Before Phase 1 implementation begins, the following spec and infrastructure
changes are required:

**Architecture:**
1. Add `surveycore_error_invalid_conf_level` to `plans/error-messages.md`
   (new row in Phase 1 section, coverage map entry).
2. Update `plans/phase-1-formal-specification.md` Section 6.4 to clarify
   that the Fisher Z formula is educational context; implementation uses
   design-based variance machinery.
3. Create `plans/phase-0.75-twophase-variance.md` — pre-work plan for
   vendoring two-phase variance code and adding `survey_twophase` support
   before Phase 1 analysis functions.
4. Update `plans/phase-1-formal-specification.md` to add `survey_srs` and
   `survey_calibrated` to the supported class list for all 6 functions.
5. Create `survey_srs` S7 class as a Phase 0 gap fix (new subclass of
   `survey_base`; `as_survey(df)` with no design args creates it).
6. Update `plans/phase-1-formal-specification.md` Section 2.2 to replace
   `vctrs::vec_rbind()` with the column-by-column accumulation pattern.
7. Update the confirmed 5-class taxonomy and constructor mapping table in
   relevant spec and documentation files.

**Code Quality:**
8. Redesign `variance` argument as a character vector accepting any
   combination of `c("se", "ci", "var", "cv", "moe")`. Update Section 2.6,
   `.validate_shared_args()`, all per-function column specs, and
   `error-messages.md` (add `surveycore_warning_cv_undefined`). Remove
   `"both"` from `get_corr()` spec entirely.
9. Add `surveycore_warning_all_na_freqs` to `plans/error-messages.md`
   (new row, coverage map entry for `test-analysis-freqs.R`).
10. Fix `get_totals()` Section 5.2 column spec: change `n` to `[n]`.
11. Add seven named meta-key constants to `R/09-analysis-helpers.R`
    (`FREQS_SINGLE_META_KEYS`, `FREQS_MULTI_META_KEYS`, `MEANS_META_KEYS`,
    `TOTALS_META_KEYS`, `CORR_META_KEYS`, `QUANTILES_META_KEYS`,
    `RATIOS_META_KEYS`). Update `.make_result_tibble()` to validate against
    the constant passed in. Update spec Section 2.2.

**Tests:**
12. Add a 3-way combination test block to test category 4 of every function's
    test file: `group_by()` + `filter()` both active simultaneously. Verifies
    correct number of rows, `n` counts only in-domain non-NA rows, and SE is
    strictly greater than physical subsetting SE. Requires
    `skip_if_not_installed("surveytidy")`.
13. Replace `get_corr()` self-consistency oracle with `survey::svyvar()` as
    the numerical oracle for complex designs. `r` validated within `1e-10`,
    SE within `1e-8`. This also fixes the implementation path: `get_corr()`
    must use the variance-covariance approach (vendored from `svyvar`
    linearization), not Fisher Z. Update Section 6.4 of the spec accordingly.
14. Strengthen `test_result_invariants()` in `helper-test-data.R`: add
    `expect_type(m$value_labels, "list")`, `expect_gt(length(m$value_labels), 0L)`,
    and `expect_false(is.null(names(m$value_labels)))`.
15. Define NA-in-group-var behavior in spec and all 6 function `@param group`
    docs: NA values in the grouping variable exclude that row from all groups
    (consistent with `dplyr::group_by()` semantics). Add one edge case test
    per function verifying this. Update Section 2.6 of the spec.

---

### Test Review Decisions

**Q: The spec requires testing grouped analysis (category 3) and domain
estimation (category 4) separately, but does not require testing both
simultaneously (grouped + filtered design).**

- Options considered:
  - **Add 3-way test:** One test block per function with both `@groups` and
    domain column active. Verifies rows, `n` counts, and SE correctness.
  - **Treat as implicitly covered:** Individual group and domain tests
    together cover the combination.
- **Decision:** Add the 3-way combination test to each function's test
  category 4.
- **Rationale:** The interaction path through `.resolve_groups()` and
  `.apply_domain()` in the same call is not exercised by either test
  individually. This is a realistic workflow pattern and a real failure mode.

---

**Q: `get_corr()` has no numerical oracle for complex designs. The original
proposal (10A) was a self-consistency check using the design's variance
machinery. The user asked whether `survey::svyvar()` would be better.**

- Options considered:
  - **Self-consistency oracle:** Compare `get_corr()` output to a manual
    computation using the same `.svy_recvar()` code it calls internally.
    Not a genuine external oracle.
  - **`survey::svyvar()` oracle:** `svyvar` computes the full design-based
    variance-covariance matrix for complex designs. Correlation derived as
    `r = Cov(X,Y) / sqrt(Var(X) * Var(Y))`. SE from delta method applied to
    `vcov(svyvar_result)`. This is exactly how srvyr implements correlation.
    Genuine external oracle; supports Taylor and replicate designs; tolerance
    1e-10 (point), 1e-8 (SE).
- **Decision:** Use `survey::svyvar()` as the oracle.
- **Rationale:** `svyvar` is a genuine independent reference implementation
  with full complex-design support, unlike `svycor`. This also clarifies
  the implementation path: `get_corr()` should use the variance-covariance
  approach internally (vendoring `svyvar`-style linearization), not Fisher Z.
  Update Section 6.4 to reflect this. The Fisher Z description remains only
  as historical context for the SRS-equivalent case, consistent with the
  fix already decided for Issue 2.

---

**Q: `test_result_invariants()` checks that `value_labels` key is present in
`meta()` output, but does not verify that it is a non-empty named list.**

- **Decision:** Add three assertions: `expect_type(m$value_labels, "list")`,
  `expect_gt(length(m$value_labels), 0L)`, `expect_false(is.null(names(m$value_labels)))`.
- **Rationale:** The invariant's job is to catch structural violations at the
  "something is badly wrong" level. Four lines prevents a class of bugs
  where a function sets `value_labels = list()` or `NULL` while technically
  keeping the key present.

---

**Q: NA values in grouping variables are not handled in the spec or tested.
Behavior is currently implementation-dependent.**

- **Decision:** Define explicitly: NA in a grouping variable excludes that
  row from all groups (matches `dplyr::group_by()` semantics). Document in
  `@param group` for all 6 functions. Add one edge case test per function.
  Update Section 2.6 of the spec.
- **Rationale:** Aligning with dplyr semantics is the least-surprise choice
  and prevents implementation-dependent behavior that could differ between
  Taylor and replicate designs.

---

## 2026-02-23 — Phase 0.75 Scope and survey_srs Documentation (Session 2)

### Context

Pre-implementation review raised two documentation gaps: (1) `survey_srs` is
a Phase 0 class that was never added to the Phase 0 spec docs, and (2) Phase
0.75 has no formal behavioral specification — only an implementation plan
(`phase-0.75-twophase-variance.md`). The question was how to document both
before implementation begins.

---

### Questions & Decisions

**Q: `survey_srs` is a Phase 0 gap (a missing S7 class that should have
shipped alongside `survey_taylor`, `survey_replicate`, `survey_twophase`, and
`survey_calibrated`). Should it be added to the Phase 0 spec docs or treated
as a Phase 0.75 item?**

- Options considered:
  - **Option A — Update Phase 0 docs:** Add `survey_srs` to
    `plans/surveycore-phase0-formal-specification.md` and
    `plans/phase-0-implementation-plan-v2.md` with an explicit note that it
    was added post-v0.1.0. Phase 0 spec becomes accurate; `survey_srs` is
    logically Phase 0 content (S7 class + constructor change).
  - **Option B — Phase 0.75 covers everything:** `survey_srs` lives in Phase
    0.75 alongside two-phase variance. Phase 0 stays frozen as the historical
    record of v0.1.0.
- **Decision:** Option A — add `survey_srs` to the Phase 0 spec documents
  with a clear post-v0.1.0 note.
- **Rationale:** `survey_srs` is a class-definition gap, not new
  infrastructure. It belongs with the other S7 classes in Phase 0 docs.
  Including it in Phase 0.75 alongside the variance vendoring would mix two
  unrelated concerns. The post-v0.1.0 note preserves the historical record
  without creating an artificial new phase for a single missing class.

---

**Q: Phase 0.75 currently has no formal behavioral specification — only
`plans/phase-0.75-twophase-variance.md`, which reads more like an
implementation plan. Should a proper formal spec be created?**

- Options considered:
  - **Create `plans/phase-0.75-formal-specification.md`:** A formal spec
    parallel in structure to the Phase 0 and Phase 1 specs. Covers two-phase
    variance formulas, behavioral contracts, and quality gates.
    `phase-0.75-twophase-variance.md` becomes the implementation plan.
  - **Leave as-is:** Rely on the existing implementation-notes document and
    the Phase 0 spec's `survey_twophase` class definition.
- **Decision:** Create `plans/phase-0.75-formal-specification.md` as a proper
  formal spec.
- **Rationale:** Two-phase variance involves non-trivial statistical formulas
  (full, approx, and simple methods), degrees-of-freedom rules, and oracle
  test tolerances. These warrant formal behavioral contracts, not just
  implementation notes. Consistent structure with Phase 0 and Phase 1 specs
  makes the planning documents easier to navigate.

---

### Outcome

Two documentation tasks to complete before Phase 0.75 implementation begins:

1. Update `plans/surveycore-phase0-formal-specification.md` and
   `plans/phase-0-implementation-plan-v2.md` to add `survey_srs` — with a
   Change Log entry noting it was added post-v0.1.0 as a gap fix.
2. Create `plans/phase-0.75-formal-specification.md` — formal behavioral spec
   for two-phase variance estimation, covering all three methods (full,
   approx, simple), variance formulas, degrees of freedom, oracle tolerances,
   and quality gates. `plans/phase-0.75-twophase-variance.md` remains as the
   implementation plan.

---
