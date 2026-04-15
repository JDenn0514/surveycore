## Plan Review: get-t-test-pairwise — Pass 1 (2026-04-14)

### New Issues

#### Section: PR 1 — Step-by-Step Tasks / Infrastructure

**Issue 1: Group-stratum domain masking mechanism not specified in Task 3.1**
Severity: BLOCKING
Violates engineering-preferences.md §5 (Explicit over clever); violates spec §3.5 domain-preservation requirement.

Task 3.1 lists "Per-stratum: `active_mask`, empty-cell error (before small-cell warning), `survey_glm()` call" but never explains HOW `active_mask` is applied to the design object before passing to `survey_glm()`. The Notes for the Implementor describe domain-column mutation only for `get_pairwise()` pair-subsetting — there is no equivalent note for `get_t_test()` group-stratum masking. An implementer following the plan literally would likely physically subset `design@data` rows, which breaks variance estimation (PSU and strata structure is no longer complete). The correct mechanism — mutating `design_g@data[[SURVEYCORE_DOMAIN_COL]]` — is the load-bearing domain-preservation requirement from §3.5, but the plan never states it for this function.

Options:
- **[A]** Add a note to Task 3.1 and the Notes section: "For each group stratum `g`, create `design_g <- design` then set `design_g@data[[SURVEYCORE_DOMAIN_COL]] <- active_mask`, where `active_mask` is the logical vector combining group membership and non-NA `x`/`by`. Pass `design_g` to `survey_glm()`. Do NOT physically subset rows." — Effort: low, Risk: low, Impact: prevents silently wrong variance estimates.
- **[B]** Reference an existing `get_*()` function that uses the same pattern. — Effort: low, Risk: medium (reader must find the pattern themselves).
- **[C] Do nothing** — Implementer may physically subset rows; variance estimates would be incorrect but tests might still pass if numerical oracle tests don't catch the difference at the available tolerance.

**Recommendation: A** — The domain-column mutation is the only correct mechanism; the plan must state it explicitly.

---

**Issue 2: Plan Notes on `na.rm` contradict the Pass 2 decisions log**
Severity: BLOCKING
Violates decisions-get-t-test-pairwise.md (2026-04-14 Pass 2 session).

Plan Notes for the Implementor state:
> "`na.rm` governs group-NA handling only in the `.build_group_combos()` call."

But the Pass 2 decisions log (2026-04-14) explicitly decided:
> "Remove the implied feature. `na.rm` only governs `x`/`by` NA handling."
> "NA `group` rows excluded from all strata regardless of `na.rm`."

These are directly contradictory. An implementer reading the plan's Notes would implement `na.rm = FALSE` as affecting group-NA stratum inclusion — the deleted feature — and `.build_group_combos()` would need to support it. The plan's edge case tests (testing x-level NAs only) are correct per the Pass 2 decision, but the Notes actively mislead in the opposite direction.

A secondary consequence: spec §3.2's argument table still says "When `na.rm = FALSE`, rows where a `group` variable is NA are included as their own stratum" — which contradicts §3.5 ("excluded from all strata regardless of `na.rm`"). The plan inherits this inconsistency without flagging it or directing the implementer to the authoritative section.

Options:
- **[A]** Replace the Notes sentence with: "`na.rm` does NOT govern group-NA handling. NA `group` rows are excluded from all strata regardless of `na.rm`; `na.rm` only affects how `.build_group_combos()` handles missing values in `x` and `by` columns. §3.5 is authoritative; the §3.2 argument table description is stale." — Effort: low, Risk: low, Impact: prevents implementing a deleted feature.
- **[B]** Point implementer to the decisions log only. — Effort: low, Risk: medium (plan remains ambiguous).
- **[C] Do nothing** — Implementer implements the wrong behavior; `na.rm` tests pass because they only test x-level NAs, masking the regression.

**Recommendation: A** — The Note is actively wrong and must be corrected. Also note which spec section is authoritative.

---

#### Section: PR 1 — Step-by-Step Tasks / TDD Cycle A

**Issue 3: `.validate_shared_args()` and separate variance check create an ambiguous two-step**
Severity: REQUIRED
Violates `.validate_shared_args()` docstring ("single canonical source — never duplicate the checks inside individual `get_*()` functions").

The spec §3.6 steps 2–3 list them separately:
- Step 2: "Validate via `.validate_shared_args(variance, conf_level, name_style, decimals, na.rm)`"
- Step 3: "Validate `variance`: must be a subset of `c("se", "ci")`"

But `.validate_shared_args()` already validates `variance` via its `valid_variance` parameter (default: all 6 types). The correct implementation is to pass `valid_variance = c("se", "ci")` to the single `.validate_shared_args()` call — not add a second check. The plan reproduces this two-step without telling the implementer which approach to use. Two failure modes:

1. Implementer calls `.validate_shared_args()` with defaults → accepts `"var"`, `"cv"`, `"moe"`, `"deff"` → t-test silently ignores unsupported variance types at column-building time.
2. Implementer adds a redundant secondary check → duplicates validation logic, violating the helper's contract.

Options:
- **[A]** Add to Task 3.1: "Call `.validate_shared_args(variance, conf_level, name_style, decimals, na.rm, valid_variance = c('se', 'ci'))`. This single call covers both spec steps 2 and 3; do not add a separate variance check." — Effort: low, Risk: low, Impact: correct validation, no duplication.
- **[B]** Leave as-is and trust the implementer to infer this from the helper's signature. — Effort: none, Risk: high (failure mode 1 is silent and dangerous).
- **[C] Do nothing** — Silent acceptance of unsupported variance values; column-building failure at runtime rather than clean error.

**Recommendation: A** — Prevents duplication and silent acceptance of unsupported variance values.

---

**Issue 4: T-2 warning test pattern is unspecified**
Severity: REQUIRED
Violates testing-standards.md §3 (Warning capture pattern).

Task 2.1 opens with: "all `expect_error(class = ...)` blocks use the dual pattern: typed class check + `expect_snapshot(error = TRUE)`."

`surveycore_warning_by_coerced` (T-2) is a WARNING — `cli_warn()` — not an error. The dual-error-pattern parenthetical does not cover it. Yet T-2 is grouped under "Error paths" in Task 2.1 without any indication of which test pattern to use. The testing-standards.md warning pattern (`expect_warning(class = ...)` wrapping the call; result captured separately; `expect_snapshot(warn = TRUE)` for message text) is different from the error dual-pattern.

An implementer who doesn't notice this will write `expect_error(class = "surveycore_warning_by_coerced")` for T-2, which will always fail.

Options:
- **[A]** Add a parenthetical in Task 2.1 under T-2: "`surveycore_warning_by_coerced` (T-2) is a WARNING. Use `expect_warning(class = 'surveycore_warning_by_coerced', ...)` wrapping the call; capture result separately. Add `expect_snapshot(warn = TRUE, ...)` for message text. One block per coercion type (character, integer, logical)." — Effort: low, Risk: low, Impact: prevents always-failing tests.
- **[B]** Move T-2 to a separate "Warning paths" subsection in Task 2.1. — Effort: low, Risk: low, same impact.
- **[C] Do nothing** — Implementer writes wrong test pattern; test fails; wasted debugging time.

**Recommendation: A or B** — Either approach clarifies the distinction. Prefer A for minimal diff.

---

**Issue 5: `MEMORY.md` update missing from acceptance criteria**
Severity: REQUIRED
Violates spec §VII Quality Gates.

Spec §VII explicitly lists as a quality gate:
> "[ ] `MEMORY.md` updated to reflect these functions as planned"

The plan's acceptance criteria checklist does not include this gate, and Task 7.3 (Quality Gates) does not list it either. The Task 7.4 scope covers changelog only. This acceptance criterion will be permanently unchecked unless added.

Options:
- **[A]** Add to the acceptance criteria checklist: "`MEMORY.md` updated to reflect `get_t_test()` and `get_pairwise()` as planned." Add a corresponding step to Task 7.4 (or create Task 7.4b). — Effort: low, Risk: low, Impact: complete acceptance criteria.
- **[B]** Do nothing — the implementer will run `/r-implement`, check the spec quality gates separately, and catch it there. — Effort: none, Risk: medium (gate may be missed on final review).
- **[C]** Remove the gate from the spec and plan. — Not appropriate; the spec was approved with this gate.

**Recommendation: A** — One-line addition closes a gap between spec §VII and the plan's acceptance criteria.

---

#### Section: PR 1 — Acceptance Criteria / Spec Coverage

**Issue 6: `by` coercion warning must fire for ordered factors too — spec ambiguity not flagged**
Severity: REQUIRED
Violates engineering-preferences.md §4 (Handle more edge cases, not fewer).

Spec §3.4 step 2 says: "character, integer, and logical columns all trigger `surveycore_warning_by_coerced` when coerced. Ordered factors are accepted as-is (no warning)."

The plan's test list (Task 2.1 Edge Cases) says: "Character `by` coerces to factor; warning issued; result still valid. Integer `by` coerces to factor; warning issued. Logical `by` coerces to factor; warning issued."

Missing: a test that an ordered factor `by` does NOT trigger the warning. Without this test, the coercion path has no coverage for the `!is.factor(by)` branch boundary, and an implementer who checks `!is.ordered(by)` instead of `is.factor(by)` would produce a false warning for ordered factors — with no failing test to catch it.

Options:
- **[A]** Add to Task 2.1 Edge Cases: "Ordered factor `by` is accepted as-is (no coercion warning issued)." — Effort: low, Risk: low, Impact: closes branch-coverage gap.
- **[B]** Mark as SUGGESTION since ordered factors are rare. — Effort: none, Risk: low (but spec explicitly called it out, so it should be tested).
- **[C] Do nothing** — Branch boundary uncovered; wrong coercion behavior for ordered factors would pass all tests.

**Recommendation: A** — Spec specifically mentioned ordered factors; the plan should test the boundary it defined.

---

#### Section: PR 1 — Notes for the Implementor

**Issue 7: Print snapshots use `nhanes_design`; CLAUDE.md prefers GSS for tests**
Severity: SUGGESTION
CLAUDE.md: "Use the GSS dataset (not NHANES or gss_2024) for examples and tests unless told otherwise."

The plan mandates `nhanes_design` for all print snapshot tests (Tasks 2.1, 4.1) and this is spec-driven (§3.9 and §4.8 name the fixture). The numerical oracle tests must use NHANES because `survey::svyttest()` examples in the spec reference NHANES. However, print snapshot tests could use a GSS-based design instead. The plan inherits the NHANES fixture from the spec without acknowledging or addressing the CLAUDE.md deviation.

Options:
- **[A]** Change print snapshot fixtures to use a GSS-based design in Tasks 2.1 and 4.1; keep NHANES only for Task 6.1 (numerical oracle). Requires updating the spec's §3.9 and §4.8 fixture specification — which would require a spec amendment. — Effort: medium, Risk: low.
- **[B]** Add a note to Task 2.1: "Note: these snapshot tests use `nhanes_design` per spec §3.9 and §4.8 — this is an approved deviation from CLAUDE.md's GSS preference; numerical oracle tests require NHANES." — Effort: low, Risk: low, Impact: documents the deviation.
- **[C] Do nothing** — The spec is approved; NHANES fixtures are inherited. Future reviewers may ask about it.

**Recommendation: B** — Adding a one-line note documents the intentional deviation without requiring a spec amendment.

---

**Issue 8: `level_a`/`level_b` label conversion pattern is implicit in Task 3.1**
Severity: SUGGESTION
Violates engineering-preferences.md §5 (Explicit over clever).

Task 3.1 says "`.apply_group_labels()` for group columns and `level_a`/`level_b`" — but `level_a` and `level_b` are NOT group columns; they are output columns holding factor level names. The correct pattern (from spec §3.4 step 5 and decisions log) is to wrap the two level values in a temporary one-column data frame named `by_name`, pass it through `.apply_group_labels()`, then extract the results. Without this note, an implementer might call `.apply_group_labels()` incorrectly (passing the full output tibble) or try to write a new helper.

Options:
- **[A]** Add a note like the `get_pairwise()` domain-mutation note: "Label conversion for `level_a`/`level_b`: build `tmp <- data.frame(col = c(level_a_val, level_b_val)); names(tmp) <- by_name; result_row$level_a <- .apply_group_labels(tmp, by_name, design, label_values)[[1L]][[1L]]`; same for `level_b`." Or reference `get_diffs()` for the exact pattern. — Effort: low, Risk: low, Impact: prevents a likely implementation error.
- **[B]** Leave as-is and trust the implementer to find the pattern in `get_diffs()`. — Effort: none, Risk: medium (pattern is non-obvious).
- **[C] Do nothing** — Implementer may produce a new single-use helper or misuse the existing one.

**Recommendation: A** — The `get_pairwise()` notes set the precedent for this level of detail; `get_t_test()` should have the same.

---

### Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 2 |
| REQUIRED | 4 |
| SUGGESTION | 2 |

**Total issues:** 8

**Overall assessment:** The plan has a well-structured TDD sequence and strong Notes for `get_pairwise()`, but two blocking gaps — the group-stratum domain masking mechanism and the contradictory `na.rm` Note — would lead to incorrect implementations that might pass all unit tests while producing silently wrong variance estimates or implementing a deleted feature. The four REQUIRED issues are mostly one-line fixes. The plan should not be handed to `/r-implement` until the two blocking issues are resolved.

---

## Plan Review: get-t-test-pairwise — Pass 2 (2026-04-15)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | Group-stratum domain masking mechanism not specified in Task 3.1 | ✅ Resolved |
| 2 | Plan Notes on `na.rm` contradict the Pass 2 decisions log | ✅ Resolved |
| 3 | `.validate_shared_args()` and separate variance check create an ambiguous two-step | ✅ Resolved |
| 4 | T-2 warning test pattern is unspecified | ✅ Resolved |
| 5 | `MEMORY.md` update missing from acceptance criteria | ✅ Resolved |
| 6 | `by` coercion warning must fire for ordered factors too — spec ambiguity not flagged | ✅ Resolved |
| 7 | Print snapshots use `nhanes_design`; CLAUDE.md prefers GSS for tests | ✅ Resolved (exceeded — fixture changed to `gss_design`) |
| 8 | `level_a`/`level_b` label conversion pattern is implicit in Task 3.1 | ✅ Resolved |

All 8 Pass 1 issues resolved.

### New Issues

#### Section: PR 1 — TDD Cycle A / Edge Cases

**Issue 9: Domain estimation equivalence test missing**
Severity: REQUIRED
Violates spec §VI Testing Requirements (Edge Cases).

Task 2.1 edge cases include: "`by` with 2 active levels in domain-filtered design (multi-level factor, filtered to 2 active): no error." This is only a "no error" check. Spec §VI explicitly requires a quantitative equivalence test: "design pre-filtered via `surveytidy::filter()` produces the same `estimate`, `se`, and `p_value` as running on the physically subsetted data (with `survey_taylor` design)." Concretely: `filter(design, condition) |> get_t_test(x, by)` should produce the same estimate as `get_t_test(as_survey(design@data[condition, ], ...), x, by)` within tolerance.

Without this test, the correctness of the `active_mask` + `SURVEYCORE_DOMAIN_COL` mutation pattern is only partially verified — the GLM may run without error but produce wrong variance estimates if domain masking is implemented incorrectly. The same gap exists for `get_pairwise()` (spec §VI: "Domain estimation (`get_pairwise()`): same equivalence holds").

Options:
- **[A]** Replace the "no error" edge case in Task 2.1 with a quantitative equivalence block: create a domain-filtered design via `surveytidy::filter()`, verify `estimate`, `se`, and `p_value` match `get_t_test()` on a physically pre-filtered design, tolerance `1e-10`/`1e-8`/`1e-6`. Add a parallel block in Task 4.1 for `get_pairwise()`. — Effort: low, Risk: low, Impact: verifies load-bearing domain-masking correctness.
- **[B]** Keep the "no error" check and add a separate equivalence block. — Effort: low, Risk: low, same impact.
- **[C] Do nothing** — Numerical oracle tests against `svyttest()` catch domain-masking bugs for the specific NHANES case but not for domain-filtered designs in general.

**Recommendation: A** — Replace the weaker test with what the spec requires. One block each for `get_t_test()` and `get_pairwise()`.

---

**Issue 10: Column-level `label` attribute tests not listed in the plan**
Severity: REQUIRED
Violates spec §3.7 Output Contract; established precedent: `test-analysis-diffs.R:373` has `test_that("get_diffs() sets column-level labels on all columns", ...)`.

Spec §3.7 explicitly defines `attr(col, "label")` for all 14 output columns (e.g., `level_a` → `"{by_label} (A)"`, `p_value` → `"P-Value"`, `stars` → `""`). Spec §4.6 adds a `p_value` label override for `get_pairwise()`: `"P-Value ({pval_adj})"`. These attributes enable `gt()` auto-detection (MEMORY.md: "Column labels for gt"). Task 3.1 mentions "Column-level `label` attributes per §3.7" as an implementation step and Task 5.1 mentions the `p_value` override — but no test in Task 2.1 or Task 4.1 verifies these attributes.

`get_diffs()` sets this precedent explicitly. The `by_label`-derived `"(A)"/"(B)"` convention in `level_a`/`level_b` labels is novel to `get_t_test()` and especially likely to be implemented incorrectly without a test.

Options:
- **[A]** Add to Task 2.1 happy path: "Column-level `label` attributes match §3.7: `attr(result$level_a, 'label') == '{by_label} (A)'`, no column has a `NULL` label attribute." Add to Task 4.1: "`p_value` label is `'P-Value (holm)'` for `pval_adj = 'holm'`." — Effort: low, Risk: low, Impact: closes output-contract coverage gap.
- **[B]** Rely on the print snapshot to implicitly surface wrong labels. — Effort: none, Risk: medium — print method may not use `attr(col, "label")`; snapshot doesn't verify attribute values.
- **[C] Do nothing** — Column-level labels only matter at `gt()` display time; statistical correctness unaffected. Risk: wrong column headers in `gt` tables with no failing test.

**Recommendation: A** — Two test blocks (one per function) following the `get_diffs()` precedent. Low effort, closes the output-contract gap.

---

**Issue 11: `label_values` not tested for `get_pairwise()` — only `label_vars` tested**
Severity: REQUIRED
Violates testing-standards.md §2 (happy path must cover the function's own behavior; three mandatory test categories).

Task 4.1 happy path lists "`label_vars = TRUE` / `FALSE` both accepted without error." This tests `label_vars` (a no-op in both functions) — but `label_values` is not tested at all for `get_pairwise()`. This is not a duplication of `get_t_test()`'s `label_values` tests: `get_pairwise()` deliberately passes `label_values = FALSE` to inner `get_t_test()` calls and applies label conversion itself at step 11 post-stacking. That post-stacking label path is distinct and must be tested separately.

If the step-11 label conversion is silently omitted, skipped, or applied to the wrong column, the "accepted without error" test will still pass.

Options:
- **[A]** Add to Task 4.1 happy path: "`label_values = TRUE` converts `level_a`/`level_b` codes to label strings in the final `get_pairwise()` output (post-stacking, not double-converted). Use a design with value labels on `by`." — Effort: low, Risk: low, Impact: covers the post-stacking label application path.
- **[B]** Argue `get_pairwise()` delegates label conversion to `get_t_test()`. — Effort: none, Risk: high — `get_pairwise()` explicitly passes `label_values = FALSE` to inner calls; delegation does NOT cover the post-stacking step.
- **[C] Do nothing** — Label conversion regression in `get_pairwise()` step 11 passes tests silently.

**Recommendation: A** — One additional happy-path block for `get_pairwise()` label conversion. Mandatory given the deliberate architectural separation of the label step.

---

#### Section: PR 1 — Notes for the Implementor

**Issue 12: `gss_2024` fixture usage — consistent with decisions log but CLAUDE.md says "not gss_2024"**
Severity: SUGGESTION
CLAUDE.md: "Use the GSS dataset (not NHANES or gss_2024) for examples and tests unless told otherwise."

The decisions log (2026-04-15) records: "User explicitly requested GSS per CLAUDE.md preference. No technical reason to use NHANES for snapshot tests." The plan uses `gss_2024` as the snapshot fixture. However, CLAUDE.md's exact phrasing says "not gss_2024" — suggesting there may be a different GSS dataset (e.g., `gss`) that is preferred. If CLAUDE.md means to exclude `gss_2024` specifically, the fixture should be revisited. If CLAUDE.md's intent is "prefer GSS over NHANES" and `gss_2024` is the package's GSS dataset, the current plan is correct.

Options:
- **[A]** Clarify in the plan note: "Uses `gss_2024` — the surveycore package's GSS dataset; CLAUDE.md 'not gss_2024' refers to avoiding bare raw data without a constructed survey design (approved deviation, see decisions log)." — Effort: trivial.
- **[B]** Leave as-is; the decisions log records the approval. — Effort: none, Risk: low.
- **[C] Do nothing** — No material impact; implementer will use what the plan says.

**Recommendation: B** — Decisions log is the authoritative record. The plan's Note already calls it an approved deviation.

---

### Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 3 |
| SUGGESTION | 1 |

**Total issues:** 4

**Overall assessment:** All 8 Pass 1 issues are resolved cleanly — the plan is substantially improved with correct domain masking, na.rm semantics, validate_shared_args call, T-2 warning pattern, and ordered-factor edge case. The three remaining REQUIRED issues are missing test coverage for behaviors explicitly defined in the spec: domain estimation correctness (§VI), column-level label attributes (§3.7/§4.6), and `label_values` in `get_pairwise()` post-stacking step. None of these block the implementation approach — the logic is fully specified. Resolve them in Stage 3 and the plan will be ready for `/r-implement`.
