# Decisions Log — surveycore get-t-test-pairwise

This file records planning decisions made during get-t-test-pairwise.
Each entry corresponds to one planning session.

---

## 2026-04-13 — Methodology lock: get_t_test() + get_pairwise()

### Context

Stage 2 Resolve resolved 7 methodology issues (4 REQUIRED, 3 ADVISORY) from the
Pass 1 review. Three issues required judgment calls: domain-preservation
mechanism (Issue 5), p-value adjustment conservatism documentation (Issue 6),
and pair-subsetting rationale documentation (Issue 7).

### Questions & Decisions

**Q: Issue 5 — Domain-preservation claim: how accurately should §3.5 and §4.3
describe the variance-estimation mechanism for Taylor and replicate designs?**

- Options considered:
  - **Option A (corrected):** Replace the unqualified "full design structure
    preserved" claim with verified mechanism: domain-indicator score zeroing for
    Taylor (confirmed in `R/glm.R` `.glm_score()` lines 246–252); unit-level
    replicate weights for replicate path (correct regardless of PSU nesting).
    Add requirement that `get_pairwise()` use `surveytidy::filter()` domain
    approach, not physical row removal, for pair subsetting.
  - **Option B:** Defer to `survey_glm()` spec with a reference.
  - **Do nothing:** Keep unqualified claim.
- **Decision:** Option A (corrected). The review's concern about replicate
  designs was a false positive — replicate weights are unit-level and correct
  regardless of PSU nesting. The real requirement is that `get_pairwise()` must
  use domain-indicator subsetting (not physical row removal) so `survey_glm()`
  receives the full design with a domain column.
- **Rationale:** The claim is load-bearing in both §3.5 and §4.3. Making it
  accurate and implementable is more valuable than deferring to another spec.

**Q: Issue 6 — p-value adjustment conservatism: should §4.4 document that
Bonferroni/Holm are conservative for correlated design-based test statistics?**

- Options considered:
  - **Option A:** Add a conservatism note — standard adjustment methods are
    conservative due to PSU/strata correlation among test statistics; no
    design-based correction is implemented.
  - **Do nothing:** Conservatism is expected; users will understand.
- **Decision:** Option A. Transparency is preferable; no code change required.
- **Rationale:** Users from a classical (iid) background may not recognize
  that design-based pairwise t-statistics are correlated. A single paragraph
  prevents confusion without adding complexity.

**Q: Issue 7 — pair-subsetting rationale: should §4.3 justify the choice of
k(k−1)/2 separate 2-level GLMs over a single k-level GLM + svycontrast()?**

- Options considered:
  - **Option A:** Add a methodological note explaining the trade-off.
  - **Do nothing:** The implementation choice is implicit.
- **Decision:** Option A. One paragraph removes reviewer ambiguity.
- **Rationale:** Both approaches are statistically valid; the pair-subsetting
  approach was chosen for simplicity. Documenting this prevents future
  reviewers from asking why `svycontrast()` was not used.

### Outcome

Spec is now at version 0.2, methodology-locked. All 7 issues resolved:
4 unambiguous fixes applied directly; 3 judgment calls decided and applied.
Key additions: `surveycore_error_by_empty_cell` error class (T-3/T-3g),
`max(1, fit@degf - 1)` df clamping, design-based df explanation, verified
domain-preservation mechanism, domain-indicator requirement in `get_pairwise()`,
p-value conservatism note, and pair-subsetting rationale.

---

## 2026-04-13 — Stage 4 Resolve: Issues 1–8

### Context

Resolving the first 8 issues from the Stage 3 code review of
`plans/spec-get-t-test-pairwise.md`. One BLOCKING issue (circular package
dependency) and seven REQUIRED gaps spanning domain masking, NSE forwarding,
API uniformity, and error specification.

### Questions & Decisions

**Q: How should `get_pairwise()` subset the design to a pair of `by` levels?**
- Options considered:
  - **`surveytidy::filter()`:** Would introduce a circular dependency
    (surveycore → surveytidy → surveycore). Uninstallable.
  - **`..surveycore_domain..` column mutation:** Write a logical vector into
    `design_ab@data[[SURVEYCORE_DOMAIN_COL]]` — the established internal domain
    pattern used by `survey_glm()`.
- **Decision:** Use the domain-column mutation pattern.
- **Rationale:** Only option that avoids the circular dependency. Consistent
  with how `survey_glm()` already handles domains internally.

**Q: How should `get_pairwise()` forward NSE arguments to `get_t_test()`?**
- Options considered:
  - **`{{ }}` tidy evaluation:** Doesn't work for forwarding already-captured
    NSE names that also need to be used as strings internally.
  - **`rlang::inject()` + `rlang::sym()`:** Resolve to string via `ensym()` for
    internal use, then re-inject as bare symbols for forwarding.
- **Decision:** Capture with `rlang::as_name(rlang::ensym())`, forward with
  `rlang::inject(get_t_test(..., x = !!rlang::sym(x_name), ...))`.
- **Rationale:** `ensym()` enforces bare symbols (rejects arbitrary expressions);
  `inject()` correctly re-injects resolved names as bare symbols for
  `get_t_test()`'s NSE capture.

**Q: Should `get_t_test()` and `get_pairwise()` include `name_style` and `label_vars`?**
- Options considered:
  - **Omit:** Column names are fixed; these arguments are less applicable.
  - **Include for API uniformity:** All other `get_*()` functions accept both.
    Omitting breaks iteration over the `get_*()` family and causes a runtime
    error in `.validate_shared_args()` when `name_style` is absent.
- **Decision:** Add both to both signatures. `name_style` is functional.
  `label_vars = TRUE` is accepted-but-unused.
- **Rationale:** API uniformity. Matches `get_means()` precedent for
  accepted-but-unused `label_vars`.

**Q: Should `surveycore_error_empty_domain` appear in the reused-classes table?**
- Options considered:
  - **Omit:** Error fires from `survey_glm()`, not directly from `get_t_test()`.
  - **Include:** Reachable when a domain-filtered design + `group` stratum
    produces 0 in-domain rows even if per-level counts pass.
- **Decision:** Include with a note explaining when it fires.
- **Rationale:** Reused classes must be documented for test coverage.

**Q: How should `level_a`/`level_b` label conversion be implemented?**
- Options considered:
  - **New helper `.level_to_label()`:** Explicit named helper.
  - **`.apply_group_labels()` via temp data frame:** Same pattern `get_diffs()`
    uses for `treats`.
- **Decision:** `.apply_group_labels()` via temp data frame.
- **Rationale:** DRY. Reuses established helper; no new function needed.

**Q: How should the model-matrix binary constraint be verified after `survey_glm()`?**
- Options considered:
  - **`length(coef(fit)) == 2L`:** O(1) coefficient count check.
  - **`ncol(model.matrix(fit@fit_))`:** Re-evaluates design matrix (O(n));
    fragile `@fit_` slot dependency.
- **Decision:** `length(coef(fit)) == 2L`.
- **Rationale:** O(1), no internal slot dependency. Binary constraint guaranteed
  by factor coercion upstream.

### Outcome

Spec updated with domain-column mutation for pair-subsetting, `inject()` for
NSE forwarding, `name_style` + `label_vars` in both signatures, `empty_domain`
error documented, label conversion mechanism named, and model-matrix check
specified.

---

## 2026-04-14 — Stage 4 Resolve: Issues 9–15

### Context

Resolving the remaining 7 issues from the Stage 3 code review: three REQUIRED
gaps (edge case behavior, NA `by` semantics, check ordering) plus a REQUIRED
test plan gap and four SUGGESTIONS (test annotations, NSE normalization,
snapshot fixtures).

### Questions & Decisions

**Q: What should `get_pairwise()` do when `get_t_test()` errors on a group stratum?**
- Options considered:
  - **[A] Propagate:** Let errors bubble up; document the behavior.
  - **[B] Skip and warn:** Catch the error, emit NA rows + new warning class.
- **Decision:** Option A — propagate.
- **Rationale:** No existing `get_*()` function catches inner-loop errors.
  Option B would introduce NA-row emission and a new `tryCatch()` pattern with
  no codebase precedent. Users should filter the design before calling.

**Q: Are NA `by` values ever treated as an active level when `na.rm = FALSE`?**
- Options considered:
  - **Never:** NA `by` values excluded from active-level count regardless of
    `na.rm`. `na.rm` only governs NA rows in the outcome `x`.
  - **Sometimes:** NA `by` rows treated as a valid level.
- **Decision:** Never. Added explicit clarifying sentence to §4.5 step 5.
- **Rationale:** Consistent with `get_diffs()`, `get_means()`, and `get_freqs()`.

**Q: Should the empty-cell error check come before or after the small-cell warning?**
- Options considered:
  - **[A] Reorder:** Error on empty cell first; then warn on small non-empty cells.
  - **[B] Guard the warning:** Keep order; warn only when `0 < n < min_cell_n`.
- **Decision:** Option A — reorder.
- **Rationale:** Existence check before size check is semantically cleaner.
  Issuing a "small cell" warning before an "empty cell" error is misleading.

**Q: Should both `x` and `by` in `get_t_test()` use `ensym()` consistently?**
- Options considered:
  - **[A] `ensym()` for both:** Aligns with `get_diffs()` and the already-updated
    `get_pairwise()` spec.
  - **[B] Tidy-select for both:** Consistent with `get_means()`.
  - **[C] Do nothing:** Mixed mechanisms; functional.
- **Decision:** Option A — `ensym()` for both.
- **Rationale:** `get_diffs()` uses `ensym()` for both `x` and `treats`.
  `get_pairwise()` was already updated to `ensym()`. Normalizing `get_t_test()`
  eliminates mixed NSE within the same function pair.

**Q: Which fixture should print snapshot tests use?**
- Options considered:
  - **Specify:** `nhanes_design`, `x = bpxsy1`, `by = riagendr`, `decimals = 2`.
  - **Leave to implementer.**
- **Decision:** Specify fixture in §3.9 and §4.8.
- **Rationale:** Concrete fixtures prevent snapshot drift between team members.
  Note: the gender column in `nhanes_2017` is `riagendr`, not `gender`.

### Outcome

All 15 code-review issues resolved. Spec at version 0.3 is approved. Ready for
`/implementation-workflow`.

---

## 2026-04-14 — Stage 4 Resolve: Pass 2 Issues 16–23

### Context

Resolving 8 new issues from the Pass 2 Stage 3 code review: 6 REQUIRED gaps
spanning broom-mode contracts, `na.rm` semantics, `by` coercion warnings,
execution-flow omissions, and test coverage — plus 2 SUGGESTIONS.

### Questions & Decisions

**Q: Should `t_stat` be renamed to `statistic` in broom mode?**
- Options considered:
  - **Document as-is:** `df`→`parameter` via existing map; `t_stat` stays (not in broom map).
  - **Add `t_stat`→`statistic`:** Full broom compatibility; requires shared-helper change.
- **Decision:** Document as-is. `t_stat` intentionally stays in both modes.
- **Rationale:** The existing `.apply_name_style()` map already decides the outcome.
  Adding `t_stat`→`statistic` is a separate decision that should be made explicitly if wanted.

**Q: Does `na.rm = FALSE` include NA rows in `x`/`by` in `active_mask`?**
- Options considered:
  - **`na.rm` governs `group` NAs only:** NA `x`/`by` always excluded; counts consistent with GLM.
  - **`na.rm = FALSE` passes NAs to GLM:** GLM drops them; `n_a`/`n_b` inflate from mask.
- **Decision:** `na.rm` governs `group` NA rows only. NA `x`/`by` always excluded.
- **Rationale:** Consistent with all other `get_*()` functions. GLM requires complete cases
  for outcome and grouping variable; documenting this prevents the over-count bug.

**Q: Should integer and logical `by` columns trigger `surveycore_warning_by_coerced`?**
- Options considered:
  - **Warn on all non-factor coercions:** character, integer, logical all trigger T-2.
  - **Character-only:** integer/logical coerce silently.
- **Decision:** Warn on all three.
- **Rationale:** A user accidentally passing a numeric scale variable as `by` gets feedback
  regardless of its class. Silent coercion hides mistakes.

**Q: Should NA `group` rows ever form their own stratum (`na.rm = FALSE`)?**
- Options considered:
  - **Remove the implied feature:** NA `group` rows excluded from all strata regardless of `na.rm`.
  - **Implement NA group strata:** High effort; no precedent in other `get_*()` functions.
- **Decision:** Remove the implied feature. `na.rm` only governs `x`/`by` NA handling.
- **Rationale:** The §3.5 "NA strata last" sentence had no test coverage, no error class,
  and no execution-flow support. Removing it simplifies the spec; the feature can be added
  separately if wanted.

**Q: Should `min_cell_n` be validated?**
- Options considered:
  - **Validate:** Coerce to integer; error on fractional or negative.
  - **Document non-validation:** Note that negatives silently suppress; use `0L` to suppress.
- **Decision:** Document non-validation.
- **Rationale:** Adding a new error class for a SUGGESTION-level issue adds maintenance
  overhead with minimal user benefit. Documenting the intentional behavior is sufficient.

### Outcome

All 8 Pass 2 code-review issues resolved. Spec at version 0.4 is approved. Ready for
`/implementation-workflow`.

---

## 2026-04-15 — Implementation Plan Review: Pass 1 Issues 1–8

### Context

Stage 3 resolve of `plans/plan-review-get-t-test-pairwise.md` Pass 1. 8 issues
(2 BLOCKING, 4 REQUIRED, 2 SUGGESTIONS) identified in the implementation plan.

### Questions & Decisions

**Q: How should the group-stratum domain masking mechanism be documented in Task 3.1?**
- Options considered:
  - **Add explicit note:** State the `SURVEYCORE_DOMAIN_COL` mutation pattern and the
    "do not physically subset" requirement directly in Task 3.1 and Notes.
  - **Reference existing pattern:** Point to `get_diffs()` or another `get_*()` function.
- **Decision:** Add explicit note (Option A).
- **Rationale:** Physical row subsetting would produce silently incorrect variance estimates
  that might still pass unit tests. The mechanism is load-bearing and must be stated explicitly.

**Q: What are the correct `na.rm` semantics for `get_t_test()`?**
- Options considered:
  - **Govern group NAs:** `na.rm` controls group-NA stratum inclusion (removed feature from §3.2).
  - **Govern x/by NAs:** `na.rm` controls whether x/by NAs are excluded from active_mask.
  - **No-op:** NA group rows always excluded; NA x/by rows always excluded (GLM requires
    complete cases); `na.rm` is accepted for API uniformity only.
- **Decision:** `na.rm` is a no-op in `get_t_test()`. NA group rows always excluded (§3.5
  authoritative); NA x/by rows always excluded regardless of `na.rm` (GLM requires complete
  cases). The §3.2 group-NA stratum feature was removed in the Pass 2 spec review.
- **Rationale:** Consistent with what the edge case tests actually verify (identical results
  with `na.rm = TRUE` and `FALSE`).

**Q: Should print snapshot fixtures change from nhanes to gss?**
- Options considered:
  - **Keep nhanes:** Consistent with spec §3.9/§4.8; numerical oracle tests already use nhanes.
  - **Change to gss_2024:** Follows CLAUDE.md GSS preference; requires plan update and
    spec amendment (§3.9, §4.8).
  - **Add a note documenting the deviation.**
- **Decision:** Change snapshot fixtures to `gss_2024` (`x = age`, `by = sex`, pre-filtered
  to valid sex codes 1/2 and coerced to factor). Spec §3.9 and §4.8 should be amended to
  match. Numerical oracle tests (Task 6.1) remain on NHANES.
- **Rationale:** User explicitly requested GSS per CLAUDE.md preference. No technical reason
  to use NHANES for snapshot tests.

### Outcome

All 8 plan-review issues resolved. Plan is now approved. NHANES snapshot references changed
to `gss_2024`; domain masking, na.rm semantics, validate_shared_args call, T-2 warning test
pattern, ordered-factor edge case, and MEMORY.md gate all added. Ready for `/r-implement`.

---

## 2026-04-15 — Implementation Plan Review: Pass 2 Issues 9–12

### Context

Stage 3 resolve of `plans/plan-review-get-t-test-pairwise.md` Pass 2. 4 issues
(0 BLOCKING, 3 REQUIRED, 1 SUGGESTION) remaining after all Pass 1 issues resolved.
All three REQUIRED issues were missing test coverage for behaviors explicitly
defined in the spec.

### Questions & Decisions

**Q: How should the domain estimation equivalence test be structured, given that
`surveytidy` is not on CRAN?**
- Options considered:
  - **`surveytidy::filter()`-based test:** Matches spec §VI description verbatim
    but introduces a dependency on a non-CRAN package; would always skip in CI.
  - **SRS-based equivalence test:** Use a plain SRS design (no PSUs/strata) where
    physical subsetting and domain estimation are numerically identical. No external
    dependency.
  - **Keep "no error" check only:** Numerical oracle tests against `svyttest()`
    provide NHANES-specific coverage; domain-filtered designs are unverified.
- **Decision:** SRS-based equivalence test (no `surveytidy` dependency).
- **Rationale:** For SRS designs, domain estimation and physical subsetting produce
  identical estimates and SEs. This verifies the `active_mask`/`SURVEYCORE_DOMAIN_COL`
  path without requiring a non-CRAN package. Added parallel blocks to Task 2.1
  (3-level `by`, filter to 2 active levels) and Task 4.1 (4-level `by`, filter to 3).

**Q: Issue 12 — Should the plan Note clarify that `gss_2024` is the intended GSS fixture?**
- Options considered:
  - **Add clarifying sentence.**
  - **Leave as-is:** Decisions log already records the approval; plan Note already
    calls it an approved deviation.
- **Decision:** Leave as-is.
- **Rationale:** Decisions log is authoritative; no material impact.

### Outcome

All 4 Pass 2 issues resolved. Column-level `label` attribute tests added to Task 2.1
and Task 4.1. `label_values` coverage added to Task 4.1 happy path for `get_pairwise()`
post-stacking step. Domain equivalence tests added using SRS approach (no `surveytidy`).
Plan is fully approved and ready for `/r-implement`.

---
