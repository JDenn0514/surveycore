# Decisions Log — surveycore get-diffs

This file records planning decisions made during get-diffs.
Each entry corresponds to one planning session.

---

## 2026-03-16 — Methodology lock: get_diffs() estimation paths, inference, and output

### Context

Resolved 7 judgment calls from the methodology review (24 issues total).
Decisions covered: p-value distribution consistency, column label strategy,
domain filtering counts, AME scale choice, p-value adjustment scope,
domain+groups interaction, and unweighted n documentation.

### Questions & Decisions

**Q: Issue 9 — Should p-values use t-distribution (clean path) or
Z-distribution (marginaleffects path)?**
- Options considered:
  - **[A] Document inconsistency:** Add `.meta$pvalue_distribution` key, warn on marginaleffects path.
  - **[B] Force design-based df on marginaleffects:** Pass `df` argument to `avg_slopes()` / `avg_predictions()`.
  - **[C] Do nothing:** Silent inconsistency.
- **Decision:** [B] — Force design-based df on all marginaleffects calls.
- **Rationale:** Full t-distribution consistency across both paths. `marginaleffects` supports the `df` argument (v0.18.0+). Users get identical inference regardless of which internal path is triggered.

**Q: Issue 11 — Should column labels differentiate by estimation path
(coefficient vs AME)?**
- Options considered:
  - **[A] Dynamic labels:** "Difference relative to {ref}" vs "Avg. Marginal Effect vs {ref}".
  - **[B] Metadata only:** Generic labels + `.meta$estimate_scale`.
  - **[C] Do nothing.**
- **Decision:** Hybrid — generic label ("Difference relative to {ref}") for all paths + `.meta$estimate_scale` key.
- **Rationale:** "Avg. Marginal Effect" is jargon that non-researchers won't understand. "Difference" is accurate for both paths. `.meta$estimate_scale` serves programmatic consumers.

**Q: Issue 16 — Should `n` count in-domain rows only or all rows when domain
filtering is active?**
- Options considered:
  - **[A] In-domain only:** Count rows where `..surveycore_domain.. == TRUE`.
  - **[B] Both counts:** Total n + `.meta$n_domain`.
  - **[C] Do nothing.**
- **Decision:** [A] — In-domain counts only.
- **Rationale:** `n` should reflect the observations actually used for inference. Consistent with SE and p-value computation.

**Q: Issue 19 — Should non-gaussian families report AMEs (response scale) or
coefficients (link scale)?**
- Options considered:
  - **[A] Document AME as default:** Explain rationale in docs.
  - **[B] Add `scale` argument:** `"ame"` (default) or `"link"`.
  - **[C] Do nothing.**
- **Decision:** Both [A] and [B] — add `scale = c("ame", "link")` argument with AME as default, document the rationale and the deviation from `survey` package convention.
- **Rationale:** AMEs are more interpretable for non-technical audiences (Gomila 2021). `scale = "link"` available for academic reporting needs. `exponentiate` argument deferred as a separate future enhancement.

**Q: Issue 20 — When `group` is active, should p-value adjustment apply
within each group or globally?**
- Options considered:
  - **[A] Within-group:** Each group's comparisons adjusted independently.
  - **[B] Global:** All comparison rows pooled across groups.
  - **[C] Do nothing.**
- **Decision:** [A] — Within-group adjustment.
- **Rationale:** Standard for exploratory subgroup analysis in survey research (Alosh et al. 2014). Each subgroup is a separate research question. Documented that users wanting global adjustment can apply `p.adjust()` manually.

**Q: Issue 18 — Should spec clarify domain + @groups interaction?**
- Options considered:
  - **[A] Add clarification.**
  - **[C] Do nothing.**
- **Decision:** [A] — Added clarifying sentence.
- **Rationale:** Low cost, prevents ambiguity about uniform domain filter application across group strata.

**Q: Issue 24 — Should spec document that `n` is unweighted and for QA?**
- Options considered:
  - **[A] Document only.**
  - **[B] Add `n_eff` column.**
  - **[C] Do nothing.**
- **Decision:** [A] — Document that `n` is unweighted for QA/small-cell detection; inference uses weighted data.
- **Rationale:** `n_eff` adds a column most users won't need. Documentation prevents misinterpretation without adding output complexity.

### Outcome

Spec updated to v1.1. All 24 methodology review issues resolved (17
unambiguous fixes applied, 7 judgment calls decided). Methodology locked.

---

## 2026-03-17 — Code review resolution: API consistency, DRY, and link-scale semantics

### Context

Resolved 14 issues from the Stage 3 code/architecture review (0 blocking,
9 required, 5 suggestions). Decisions covered: Phase 1 API uniformity
(name_style, label_values, label_vars, min_cell_n, n_weighted), DRY
violations (error classes, meta construction), correctness (df computation),
link-scale output semantics, and test plan gaps.

### Questions & Decisions

**Q: Issue 8 — What should `mean` and `pct_change` show when
`scale = "link"` + non-gaussian family?**
- Options considered:
  - **[A] Conditional labels:** Show link-scale means with label "Mean (link scale)"; suppress `pct_change`.
  - **[B] Force marginaleffects:** Route all non-gaussian through marginaleffects regardless of scale.
  - **[D] Suppress both columns:** Omit `mean` and `pct_change` entirely when link + non-gaussian.
- **Decision:** [D] — Suppress `mean` and `pct_change` when `scale = "link"` and family is non-gaussian. Reference row still appears with `estimate = 0`.
- **Rationale:** The `mean` column exists to provide contextual understanding ("agreement went from 40% to 55%"). Link-scale means (e.g., log-odds of -0.85) do not serve this purpose. Users choosing `scale = "link"` are technical users who want raw coefficients and do not need the contextual scaffolding. `pct_change` as a ratio of link-scale values is statistically meaningless.

**Q: Issue 10 — Should `label_values` and `label_vars` be included?**
- Options considered:
  - **[A] Add min_cell_n only:** Other three omitted as no-ops.
  - **[B] Add all four:** Full API uniformity.
- **Decision:** [B] — Add all four (`min_cell_n`, `n_weighted`, `label_values`, `label_vars`).
- **Rationale:** `label_values` is NOT a no-op for `get_diffs()` — the `treats` and `group` columns contain categorical values with metadata labels. `label_values = TRUE` (default) shows "Control", "Message A"; `label_values = FALSE` shows raw codes. This is meaningful behavior, not a uniformity shim.

### Outcome

Spec updated to v1.2. All 14 code review issues resolved (all accepted
recommended option or a new option D for Issue 8). Spec is approved for
implementation.

---

## 2026-03-17 — Code review Pass 2 resolution: survey_srs removal, broom collision, labeling, edge cases

### Context

Resolved 7 issues from the Stage 3 Pass 2 code review (2 blocking, 3 required,
2 suggestions). Issues arose from the `survey_srs` class removal, a broom
naming collision unique to `get_diffs()`, unspecified labeling mechanisms, and
edge case documentation gaps.

### Questions & Decisions

**Q: Issue 15 — `survey_srs` listed as supported but removed from codebase?**
- Options considered:
  - **[A] Remove references:** Remove `survey_srs` from Section I table and `"srs"` from Section IV `design_type`.
  - **[C] Do nothing.**
- **Decision:** [A] — Remove all `survey_srs` references.
- **Rationale:** Spec must match the codebase. SRS designs are now `survey_taylor` objects.

**Q: Issue 16 — `name_style = "broom"` creates duplicate `estimate` columns?**
- Options considered:
  - **[A] Exclude `mean` from broom rename:** Skip `mean` in `.apply_name_style()` when `estimate` already present.
  - **[B] Rename `mean` to `fitted_mean`:** Structural API change.
  - **[C] Do nothing.**
- **Decision:** [A] — Exclude `mean` from broom renaming.
- **Rationale:** The `mean` column in `get_diffs()` is contextual (treatment-level mean), not the point estimate. `estimate` already holds the point estimate in broom convention. Phase 1 functions never have both columns simultaneously, so `.apply_name_style()` was never designed for this case. The fix is isolated and non-breaking.

**Q: Issue 17 — `treats` column labeling mechanism unspecified?**
- Options considered:
  - **[A] Apply `.apply_group_labels()` post-assembly:** Treat `treats` like group columns for labeling.
  - **[B] Apply labels before GLM fit:** Changes model term names.
  - **[C] Do nothing.**
- **Decision:** [A] — Apply `.apply_group_labels()` post-assembly.
- **Rationale:** Reuses existing Phase 1 infrastructure. Applying labels before GLM fit would change model term names and complicate `clean()` parsing.

**Q: Issue 18 — `n_weighted` for reference row not specified?**
- Options considered:
  - **[A] Add to reference row contract:** Sum of weights for reference level.
  - **[C] Do nothing.**
- **Decision:** [A] — Add `n_weighted` to Reference Row Contract.
- **Rationale:** Completes the contract. Consistent with Phase 1/Phase 2 patterns for observation counts on reference rows.

**Q: Issue 21 — `group` with 1 unique value — singular matrix or degenerate?**
- Options considered:
  - **[A] Fix test expectation:** Update edge case to expect `surveycore_error_singular_model_matrix`.
  - **[B] Detect and drop interaction:** Fall back to no-group case with warning.
  - **[C] Do nothing.**
- **Decision:** [A] — Fix the test expectation.
- **Rationale:** The error already exists in `survey_glm()`. Option B is a nice enhancement but adds complexity; can be a follow-up.

### Outcome

Spec updated to v1.3. All 7 Pass 2 issues resolved (2 blocking, 3 required,
2 suggestions). Spec is approved for implementation.

---

## 2026-03-17 — Code review Pass 3 resolution: marginaleffects type arg, variance restriction, execution flow

### Context

Resolved 7 issues from the Stage 3 Pass 3 code review (1 blocking, 4 required,
2 suggestions). Primary finding: `avg_slopes()` missing `type = "link"` when
`scale = "link"` on the marginaleffects path, causing response-scale AMEs to be
silently mislabeled as link-scale coefficients.

### Questions & Decisions

**Q: Issue 22 — `avg_slopes()` returns response-scale AMEs when user requests
`scale = "link"` via marginaleffects path?**
- Options considered:
  - **[A] Add `type` argument:** Pass `type = "link"` or `"response"` based on `scale`.
  - **[B] Disallow `scale = "link"` with covariates/groups:** Simpler but reduces functionality.
  - **[C] Do nothing.**
- **Decision:** [A] — Add `type` argument to all `avg_slopes()` and `avg_predictions()` calls.
- **Rationale:** Maintains full functionality. Technical users who chose `scale = "link"` (per Issue 19 decision) should get link-scale coefficients regardless of whether covariates/groups force the marginaleffects path. One-line change per call site.

**Q: Issue 23 — `.validate_shared_args()` accepts all 6 variance types but
`get_diffs()` only supports `"se"` and `"ci"`?**
- Options considered:
  - **[A] Restrict valid set:** Pass `valid_variance = c("se", "ci")`.
  - **[B] Expand support:** Compute var/cv/moe from SE.
  - **[C] Do nothing.**
- **Decision:** [A] — Restrict the valid set.
- **Rationale:** SEs and CIs come from `clean()` or marginaleffects — the Phase 1 variance types are not computed. Expansion can be a follow-up if needed.

### Outcome

Spec updated to v1.4. All 7 Pass 3 issues resolved (1 blocking, 4 required,
2 suggestions — 1 suggestion already resolved in prior pass). Spec is approved
for implementation.

---

## 2026-03-17 — Implementation plan review resolution: task granularity, test coverage, registration pattern

### Context

Resolved 13 issues from the adversarial plan review (1 blocking, 5 required,
6 suggestions, 1 already resolved). Issues covered: S3 method registration
pattern, dead code in print method, coverage criteria, mega-task splitting,
missing numerical tests, pct_change rounding test, vague assertions, test
phase organization, skip guard hygiene, @groups integration, and n computation
source.

### Questions & Decisions

**Q: Issue 1 — Should `print.survey_diffs()` use `registerS3method()` in
zzz.R or roxygen `@method` + `@export`?**
- Options considered:
  - **[A]** Roxygen `@method print survey_diffs` + `@export` (matching `print.survey_result()` pattern).
  - **[B]** `registerS3method()` in `zzz.R`.
- **Decision:** [A] — Use roxygen registration.
- **Rationale:** `survey_diffs` is a plain S3 class, not S7. `zzz.R` dynamic registration is only needed for S7 namespaced classes (e.g., `"surveycore::survey_glm_fit"`). Consistency with existing `print.survey_result()`.

**Q: Issue 2 — Should the print method map include `"nonprob"` as a display
name?**
- Options considered:
  - **[A]** Remove — `.build_meta()` never produces `"nonprob"`.
  - **[B]** Keep as defensive code.
- **Decision:** [A] — Remove dead entry. Future `.build_meta()` rename tracked in `plans/future/rename-nonprob-design-type.md`.
- **Rationale:** Map should match what `.build_meta()` actually produces. If the mapping changes, update both at the same time.

**Q: Issue 13 — Should `clean()` be called with `n = TRUE`, or should `n`
always be computed separately from `design@data`?**
- Options considered:
  - **[A]** Always compute `n` from `design@data` (one path).
  - **[B]** Use `clean()`'s `n_obs` for non-domain, separate for domain.
- **Decision:** [A] — One `n` computation path.
- **Rationale:** DRY. Avoids conditional logic. Domain-aware counting from `design@data` is correct in all cases.

### Outcome

Implementation plan updated with all 13 fixes. Plan is approved for
implementation starting with PR 1 (`feature/diffs-infrastructure`).

---
