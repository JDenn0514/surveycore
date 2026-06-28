# Decisions Log — surveycore coef-vcov-methods

This file records planning decisions made during coef-vcov-methods.
Each entry corresponds to one planning session.

---

## 2026-06-22 — Methodology lock: coef/vcov/SE/confint S3 methods

### Context

19 issues emerged from the Stage 2 methodology review. 12 were UNAMBIGUOUS
(applied in batch without user decisions). 7 were JUDGMENT CALLS requiring
explicit decisions. All 7 judgment calls are resolved below.

### Questions & Decisions

**Q3: Cross-group vcov zeros for domain estimation — warn or not?**
- Options considered:
  - **Option A:** Document limitation + emit `cli::cli_warn()` when vcov() called on grouped result. Matches `survey::vcov.svyby()` convention.
  - **Option B:** Implement correct cross-group covariance (out of scope, very high effort).
  - **Option C:** Do nothing — silent structural zeros.
- **Decision:** Option A — add `surveycore_warning_vcov_cross_group`.
- **Rationale:** The underlying issue (cross-group zeros are exact only for non-overlapping strata) is correct to flag, and `survey` itself warns. We want to match `survey::vcov.svyby()` behavior, not diverge silently.

**Q4: df storage policy — actual `degf(design)` vs Inf?**
- Options considered:
  - **Option A:** Store `Inf` for non-calibrated designs (matches existing `degf = Inf` in `ci_low`/`ci_high` columns and `survey::confint.svystat()` default).
  - **Option B:** Store actual df; document divergence between `confint()` and stored CI columns.
  - **Option C:** Do nothing.
- **Decision:** Option A — store `Inf` for non-calibrated Taylor, replicate, and nonprob; store actual per-cell df for calibrated Taylor.
- **Rationale:** Consistency between `confint()` and the pre-computed `ci_low`/`ci_high` tibble columns is more important than automatic t-distribution use. The existing `survey::confint.svystat()` defaults to `df = Inf` for the same reason.

**Q5 (Issue 5 — auto-resolved): Woodruff quantile SE round-trip**
- With Q4 resolved to df = Inf, the Woodruff confint round-trip works algebraically: `confint lower = qhat - qnorm(0.975) * [(ci_high - ci_low) / (2 * qnorm(0.975))] = Woodruff lower`. No separate decision needed. The §I/§VI contradiction (Issue 8) is resolved in favor of §VI (diagonal se^2, not NA-filled).

**Q7: Within-group cross-variable zeros for future multi-column estimate classes**
- Options considered:
  - **Option A:** Document as limitation; differ from survey intentionally. Label multi-column block as DEFERRED.
  - **Option B:** Match survey — implement joint vcov for multi-variable blocks when a multi-column class is added.
- **Decision:** Option B — spec commits to joint influence-function estimation for multi-estimate-column classes, matching `survey::vcov.svystat()`. Labeled DEFERRED in §III.6 since all current classes have `length(estimate_cols) == 1`.
- **Rationale:** Structural zeros for cross-variable covariances would be a silent statistical error when a multi-column class is added. The spec commitment now prevents that.

**Q9: Per-cell df for calibrated Taylor designs**
- Options considered:
  - **Option A:** Store per-row df vector `numeric(p)`. `confint()` uses `df[i]` per parameter.
  - **Option B:** Store scalar `min(per-cell df)` — conservative.
  - **Option C:** Keep scalar `.degf(design)`, document limitation.
- **Decision:** Option A — per-row df vector.
- **Rationale:** The only option where `confint()` exactly matches the per-cell `ci_low`/`ci_high` columns already stored in calibrated Taylor results. Options B and C both produce a mismatch for non-minimum-df cells. Surveycore's calibrated Taylor already computes per-cell df in `get_*()` functions — threading it through adds minimal cost.

**Q16: get_diffs() row ordering requirement**
- Options considered:
  - **Option A:** Add row-ordering requirement to §VI: rows must be in group-major order before attribute attachment.
  - **Option A2:** Make `coef()` sort to group-major order at read time.
  - **Option C:** Do nothing.
- **Decision:** Option A — add ordering requirement to §VI.
- **Rationale:** One sentence in §VI is the minimal fix. The ordering contract must be explicitly stated so builder doesn't produce a misaligned vcov block-diagonal.

**Q19: Extend vcov warning to multi-row ungrouped results**
- Options considered:
  - **Yes:** Extend `surveycore_warning_vcov_cross_group` to fire when p > 1, grouped OR ungrouped.
  - **No:** Keep warning scoped to grouped results only.
- **Decision:** Yes — extend to all results with p > 1.
- **Rationale:** `survey::vcov.svyby()` always warns. For multi-row ungrouped results (quantiles, freq levels, diffs contrasts), off-diagonal zeros are equally structural. Consistent behavior across result types.

### Unambiguous fixes applied (12 total)

1. `survey_freqs` vcov: full cross-level covariance via joint influence-function estimation (multinomial constraint)
2. `survey_corr` vcov: `NA_real_` off-diagonal with `surveycore_warning_vcov_incomplete`
3. `vcov()` caching: removed (`<<-` was broken; `se^2` is O(p) and recomputed fresh)
4. df type coercion: `as.numeric()` in `.build_survey_result_attr()`
5. `confint()` df ≤ 0 guard: new `surveycore_error_invalid_df`
6. `survey_diffs` coef() naming: `"Treatment_A - Control"` format
7. Zero-row dimnames: `character(0)` not `NULL`
8. coef() ordering: variable-major (matching `survey::svyby`)
9. confint() column label: removed false `stats::confint` conformance claim at extreme levels
10. df prose example: corrected tail probability (`level/2` → `1-(1-level)/2`)
11. `SE.default()` `...` forwarding: matches `survey::SE.default()`
12. §I/§VI quantile contradiction: resolved (§VI is correct; diagonal se^2)

### Outcome

Spec is at version 1.1. `.survey_result` attribute `$df` is now a numeric
vector of length p (per-row df). `.build_survey_result_attr()` accepts
`cell_df` instead of `design`. `vcov()` emits warnings for structural zeros.
`survey_freqs` vcov requires joint estimation. `survey_diffs` names encode
the reference level.

---

## 2026-06-22 — Stage 3r: unambiguous batch applied

### Context

58 issues from the Stage 3 spec review. 53 had unambiguous solutions applied
in batch. 5 judgment-call issues remain for user decision (Issues 1, 6, 19,
20, 21).

### Unambiguous fixes applied (53 total)

Key changes: §III.0 shared preconditions added; `$var` slot removed from attribute; NaN→NA_real_ coercion in vcov(); `format(..., trim=TRUE)` for confint column labels; df guard extended to NA_real_; `group_cols` source corrected for get_diffs(); df sourcing corrected to `fit@degf`; DEFERRED bullet labeled DO NOT IMPLEMENT; Templates 3+4 added to SCR-1; SCR-3, SCR-W1–W4 added to error-messages.md; test-spec extended with §7.6–7.10 error paths, §14 oracles, §15–19 new test blocks.

### Open issues (judgment calls for user)

- **Issue 1** (BLOCKING): survey_freqs vcov — Option A reverses Stage 2 joint estimation decision
- **Issue 6** (BLOCKING): Oracle scope — all 5 classes vs top 3
- **Issue 19** (REQUIRED): SE masking — document vs implement thin passthrough methods
- **Issue 20** (REQUIRED): Separator for corr/covariance names — `var1:var2` vs `var1.var2`
- **Issue 21** (REQUIRED): Warning class rename + trigger condition change

### Outcome

Spec at version 1.2. Test-spec at version 1.1. 5 judgment-call issues pending.

---

## 2026-06-22 — Stage 3r: judgment-call issues resolved

### Context

5 judgment-call issues from the Stage 3 spec review. All 5 resolved by user.

### Decisions

**Issue 1: `survey_freqs` vcov — joint estimation vs. NA_real_ off-diagonal**
- Options presented: A (NA_real_ + warn), B (joint estimation — keep Stage 2 decision), C (document as unsupported, return NA_real_, no warn).
- **Decision:** Option A — downgrade to diagonal `se^2` + `NA_real_` off-diagonal + emit `surveycore_warning_vcov_diagonal_only`.
- **Rationale:** Joint estimation at vcov() call time requires re-running the design's variance estimator with a joint influence matrix — the design object is not available from stored per-row data. The Stage 2 decision was based on a misread of what data is available at vcov() call time. Option A is honest, consistent with `survey_corr` behavior, and avoids a blocked implementation.
- **Cascading:** Issues 17 (survey_freqs exception in cross-group warning) and 29 (survey_freqs exception in §III.6 ungrouped step 4) auto-resolved: survey_freqs now follows the same path as all other classes.

**Issue 6: Oracle scope — 5 classes or top 3**
- Options presented: A (all 5 classes), B (top 3 only — means, freqs, corr).
- **Decision:** Option A — keep §14 with oracles for all 5 classes (ratios, quantiles, covariance, diffs, corr + replicate vcov).
- **Rationale:** Surveycore's engineering preference is more tests, not fewer. All 5 oracle blocks use `skip_if_not_installed("survey")` so they are optional in CI without `survey` installed.

**Issue 19: SE masking — document limitation vs. thin passthrough methods**
- Options presented: A (document limitation; SE.svyby/SE.svrepstat gap acknowledged but not filled), B (add thin passthrough methods).
- **Decision:** Option A — document limitation in §III.4; do not add passthrough methods in this phase.
- **Rationale:** The passthrough methods would need to replicate `survey::SE.svyby` semantics (coercing `survey_result` to `svyby` — complex and out of scope). A clear documentation note is the honest minimal fix.

**Issue 20: Separator for corr/covariance names — `:` vs. `.`**
- Options presented: A (change to `.` — `var1.var2`), B (keep `:` but document ambiguity).
- **Decision:** Option A — use `.` separator (`var1.var2`).
- **Rationale:** The `:` separator creates 3-token ambiguity in grouped names (`group:var1:var2`). The `.` separator is already established for intra-row identifiers (`variable.level`, `variable.p25`), making `var1.var2` fully consistent. Grouped: `"Northeast:age.income"` — unambiguously parsed.

**Issue 21: Warning class rename + trigger condition**
- Options presented: A (trigger = p>1 only; rename to `vcov_diagonal_only`), B (keep trigger = grouped OR p>1; rename to `vcov_structural_zeros`), C (keep current trigger + name `vcov_cross_group`).
- **Decision:** Option A — trigger = `length(coef(object)) > 1`; rename to `surveycore_warning_vcov_diagonal_only`.
- **Rationale:** "p>1" is simpler, equivalent (grouped results always have p>1), and fires correctly for the single-group-with-multiple-levels case. The new name `vcov_diagonal_only` describes what the matrix IS (diagonal only) rather than what it's missing (cross-group), making it accurate for both grouped and ungrouped multi-parameter cases.

### Changes applied

- `plans/spec-coef-vcov-methods.md` — §I.3 support matrix, §III.5 naming note, §III.6 survey_freqs bullet + ungrouped step 4 + off-diagonal warning section, §V SCR-W2 row, §VIII quality gates (×2): all updated
- `plans/error-messages.md` — SCR-W2 row: trigger + class name updated
- `plans/test-spec-coef-vcov-methods.md` — §3.6/§3.7 headers + assertions (`:` → `.`), §16 test_that descriptions + class names (×2): all updated

### Outcome

All 58 issues from Stage 3 resolved. Spec advanced to version 1.3, status SPEC_READY.

---

## 2026-06-22 — Stage 3r Pass 2: all 9 new issues resolved

### Context

Pass 2 of the Stage 3 spec review found 0 BLOCKING, 6 REQUIRED, and 3 SUGGESTION issues (Issues 59–67). All were resolved in this session.

### Questions & Decisions

**Issues 59–62, 65–66: Unambiguous — applied without judgment calls**
- Issue 59: Removed stale `"var"` from test-spec §1.1 attribute names assertion.
- Issue 61: Updated §I scope table from "Four" to "Six" new error entries (SCR-W3, SCR-W4 were missing).
- Issue 62: Added NULL `.meta$x` path to §III.5 `survey_totals` naming row — when `.meta$x` is `NULL`, name is `"N"`.
- Issue 65: Added var1/var2 derivation to §III.5 corr/covariance rows — from `as.character(object[["var1"]])` / `object[["var2"]]` tibble columns.
- Issue 66: Added a note to §III.1 that `cell_df` length validation requires `p` as an explicit parameter; left to a future revision.

**Issue 60: SCR-W3 and SCR-W4 tests — Option A**
- Added §6.10 (parm with NA → SCR-W3), §6.11 (partial mismatch → SCR-W4), §6.12 (all-unmatched → SCR-W4 + 0×2 matrix). Added 3 warning snapshot entries to §11.
- Rationale: 98% line coverage gate is not achievable without these branches.

**Issue 63: SE() cascading warning — Option A (suppressWarnings)**
- `SE.survey_result()` wraps internal `vcov()` call in `suppressWarnings()`.
- Added warning suppression prose to §III.7 with roxygen `@note` directive.
- Rationale: Direct precedent in `R/glm.R`. User called `SE()`, not `vcov()` — the off-diagonal warning is irrelevant noise in that context.

**Issue 64: test_invariants() missing — Option A (all 17 blocks)**
- Added `test_invariants(d_sc)` / `test_invariants(d)` to all 17 affected code blocks: §4.5, §4.6, §5.3, §6.5, §7.1, §7.2, §7.3, §7.6, §7.7, §7.8, §12, §13, §14.1, §14.2, §14.3, §14.5, §14.6.
- Rationale: Project rule, no exceptions.

**Issue 67: get_diffs() reference level field — Option A (exact path)**
- Replaced `meta(result)$reference_level` (or equivalent) with exact path `meta(result)$treats$ref_level` confirmed by reading `R/analysis-diffs.R`.

### Outcome

All 9 Pass 2 issues resolved. Spec advanced to version 1.4. Test-spec advanced to version 1.3. Both remain SPEC_READY.

---

## 2026-06-22 — Plan review Stage 3: all 7 HOLDs resolved

### Context

Plan review (plan-review-coef-vcov-methods.md) returned HOLD with 7 HOLD-level
findings and 12 NOTE-level findings. All 7 HOLDs resolved and 4 NOTEs addressed.

### Decisions

**G1: PR 2 write surface (12 files) — keep as-is**
- Decision: Accept 12-file PR 2 without splitting.
- Rationale: All 8 `get_*()` wiring tasks (Tasks 2–9) are structurally identical
  (add `estimate_cols`/`statistic`/`cell_df` args to one function's
  `.make_result_tibble()` calls). A single review pass is efficient. Splitting
  into two PRs would require two branch cuts, two PRs, two CI runs, and an
  intermediate merge to `develop` with no behavioral milestone — overhead without
  benefit. Task 9 (`get_diffs()`) is more complex and is now flagged at 8 min.

**D2: document() sequencing in PR 3**
- Decision: Add explicit re-run of `devtools::document()` at the start of
  Task 12, before `devtools::check()`.
- Rationale: Tasks 9–10 add tests only (no new exports), so a second `document()`
  call is technically unnecessary, but the explicit step removes ambiguity and
  has zero cost.

**S1: .build_survey_result_attr() file location**
- Decision: Keep in `R/analysis-helpers.R` (as planned); add explicit
  architectural note in PR 1 acknowledging the divergence from spec §II.
- Rationale: The helper is consumed by all `get_*()` functions in PR 2. Moving
  it to `analysis-methods-coef-vcov.R` (spec §II position) would require
  PR 2 to depend on PR 3's write surface — reversing the dependency order.
  `analysis-helpers.R` is the correct home for helpers shared across `get_*()`
  functions.

### HOLDs applied as plan edits (no judgment required)

- **F1**: PR 1 Task 1 changed from "verify Coverage Map entry is present" to
  "write Coverage Map entry" — the entry is absent and must be created.
- **A1**: PR 2 Task 1 extended with test subtasks for ratios/quantiles/covariance/diffs.
  PR 2 ACs extended with `get_ratios`, `get_quantiles`, `get_covariance` attribute
  assertions.
- **A2**: PR 2 `get_diffs` AC extended to verify `$estimate_cols == c("estimate")`
  and `$statistic == "diffs"` in addition to the existing `$df` field check.
- **A6**: PR 3 AC added: `coef()` on wide-format `survey_corr` throws
  `surveycore_error_result_method_unsupported`.
- **F3**: PR 2 write surface extended to 8 test files (added test-analysis-ratios.R,
  test-analysis-quantiles.R, test-analysis-covariance.R, test-analysis-diffs.R).

### NOTEs addressed

- **G2**: `get_diffs()` task time updated from 5→8 min.
- **D3**: PR 2 Task 10 verification filter broadened to include all 8 wired functions.
- **A4**: PR 3 AC added verifying `SE()` suppresses `vcov_diagonal_only` warning.
- **F2**: `NEWS.md` added to PR 3 write surface.

### Outcome

Implementation plan advanced to version 3.0. Status: PLAN_READY.

---

## 2026-06-23 — Coverage-floor override: pre-existing gap accepted

### Context

Reviewer issued STOP on PR 2 because `covr::package_coverage()` = 93.05%, below
the 95% absolute floor in `testing-standards.md`. All new code in PRs 1 and 2
is covered; coverage improved by +0.04% vs the pre-feature baseline of 93.016%.

### Decision

**Override accepted.** The coverage gap is pre-existing (package was at 93.0%
before this feature branch began). The pipeline tester and reviewer should treat
93%+ coverage as acceptable for PRs 2 and 3 in this sequence, provided no new
uncovered lines are introduced. A dedicated coverage-improvement task will be
tracked separately.

### Scope

Applies to: `feature/coef-vcov-wire-getstar` (PR 2) and
`feature/coef-vcov-methods` (PR 3) only.
