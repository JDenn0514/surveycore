# Plan Review: coef(), vcov(), SE(), confint() for survey_result

**Plan version:** 2.0
**Review date:** 2026-06-22
**Verdict:** PASS (HOLDs resolved 2026-06-22, plan v3.0)

---

## Summary

The plan is structurally sound — three-PR linear sequence, clean cross-PR dependency order, and all primary source files covered. No BLOCK-level findings. Five HOLDs require resolution before implementation begins: two acceptance-criteria gaps in PR 2 (ratios/quantiles/covariance omitted; `get_diffs` AC incomplete), two AC gaps in PR 3 (wide-format `survey_corr` error; file location ambiguity), one Coverage Map write task underspecified in PR 1, and a `devtools::document()` sequencing defect in PR 3.

---

## Findings by Lens

### Lens 1 — PR Granularity

**ISSUE-G1** — HOLD
PR 2 touches 12 files (8 source + 4 test), exceeding the 5-file write-surface guideline. The 8 `get_*()` wiring changes are independent and could be split into two PRs (e.g., means/totals/freqs/corr vs. ratios/quantiles/covariance/diffs). Splitting would also make it easier to assign the more complex `get_diffs()` task its own review focus.

**ISSUE-G2** — NOTE
PR 2 Task 9 (`get_diffs()`) is substantially more complex than Tasks 2–8 (requires manual attribute attachment, df extraction from `fit@degf`, and `group_cols` extraction from `.meta`) but is assigned the same 3 min estimate. Should be flagged as a higher-complexity task in the plan.

**ISSUE-G3** — NOTE
PR 3 has 13 tasks covering a new generic, four S3 methods, 11+ oracle tests, 16+ snapshot tests, documentation, and coverage verification. Task count is at the upper bound; consider splitting if review bandwidth is limited.

**ISSUE-G4** — NOTE
PR 3 Task 2 generates 16 snapshots; Task 11 approves them via `snapshot_review()`. CI will fail on first push until committed snapshots are added. This is standard testthat snapshot workflow but worth noting explicitly in the plan.

---

### Lens 2 — Dependency Ordering

**ISSUE-D2** — HOLD
PR 3 Task 8 calls `devtools::document()` between implementation (Tasks 3–7) and oracle/consistency test writing (Tasks 9–10). If `document()` is only run in Task 8, the NAMESPACE state during `devtools::check()` (Task 12) depends on whether it is re-run after Tasks 9–10. Recommendation: move `document()` to after Task 7 (or add a second call after Task 10).

**ISSUE-D1** — NOTE
PR 3 Tasks 12 (`devtools::check()`) and 13 (`covr::package_coverage()`) are in reversed order relative to the standard gate sequence (check before coverage). Minor.

**ISSUE-D3** — NOTE
PR 2 Task 10 verification filter (`analysis-(means|totals|freqs|corr)`) omits four wired functions (`get_ratios`, `get_quantiles`, `get_covariance`, `get_diffs`). Wiring regressions in those four functions are only caught in the final `devtools::test()` (Task 11). The filter should be broadened or a second filter step added.

**ISSUE-D4** — NOTE
PR 3 Task 11 (`snapshot_review()`) is placed after Tasks 9–10 add oracle and consistency tests. Any snapshots from those tests would also need review but are not addressed by this task placement. Low risk.

---

### Lens 3 — Acceptance Criteria

**ISSUE-A1** — HOLD
PR 2 acceptance criteria assert `.survey_result` attribute only for `get_means`, `get_totals`, `get_freqs`, and `get_corr`. Tasks 5–8 wire the attribute into `get_ratios`, `get_quantiles`, `get_covariance`, and `get_diffs`, but none of these appear in the acceptance criteria. The test-spec (§1.1, §1.2) explicitly requires coverage for all eight `get_*()` functions.

**ISSUE-A2** — HOLD
PR 2's `get_diffs` acceptance criterion verifies only `$df == rep(as.numeric(fit@degf), p)`. It does not verify `$statistic == "diffs"` or `$estimate_cols == c("estimate")`, which the test-spec §1.2 requires. The AC is incomplete for the attribute fields specified.

**ISSUE-A6** — HOLD
PR 3 has no acceptance criterion for `coef()` on wide-format `survey_corr` throwing `surveycore_error_result_method_unsupported`. The test-spec §8.4 requires this. The task mentions writing the test (Task 1) and the implementation step includes it (Task 4), but it is absent from the PR 3 AC section — meaning it could be dropped without blocking the PR.

**ISSUE-A3** — NOTE
PR 3's coverage criterion ("≥ 98% line coverage") is a process gate, not a behavioral observable. Acceptable as a secondary gate but should not be the sole regression backstop.

**ISSUE-A4** — NOTE
PR 3 has no acceptance criterion asserting `SE.survey_result()` suppresses the `vcov_diagonal_only` warning (no spurious warnings propagate to the caller). The plan notes `suppressWarnings()` in the implementation but does not require it to be tested.

---

### Lens 4 — Spec Coverage

**ISSUE-S1** — HOLD
The spec (§II Architecture) places `.build_survey_result_attr()` in the new file `R/analysis-methods-coef-vcov.R`. The plan places it in `R/analysis-helpers.R` (PR 1, Task 4). This is a reasonable divergence (the helper is consumed by `get_*()` functions, not by the methods file), but the plan never acknowledges it and PR 3's write surface omits `R/analysis-helpers.R`. If a reviewer enforces the spec's architecture section literally, a conflict arises. The plan should explicitly note this architectural decision.

**ISSUE-S2** — NOTE
Spec §III.8 requires a length guard for logical `parm` in `confint()`: `length(parm) == length(coef(object))`. PR 3 Task 7 does not mention this guard and it is absent from the AC. The behavior is specified but unscheduled as a testable criterion.

**ISSUE-S3** — NOTE
Spec §III.5 requires `survey_totals` no-variable mode to use coefficient name `"N"`. This naming rule is referenced in PR 3 Task 4 but absent from any PR's acceptance criteria.

**ISSUE-S4** — NOTE
Spec §VII edge case: "Grouped result with 0 groups — treated as ungrouped; `coef()` uses bare variable names." Unscheduled in any PR task list or acceptance criteria.

**ISSUE-S5** — NOTE
Spec §VII edge case: "All estimates are `NA`" — `coef()` returns all-`NA_real_` named vector; `vcov()` returns all-`NA_real_` matrix. Unscheduled in any PR task or acceptance criterion.

---

### Lens 5 — File Completeness

**ISSUE-F1** — HOLD
`plans/error-messages.md` Coverage Map currently has no row for `test-analysis-methods-coef-vcov.R` covering SCR-1, SCR-3, SCR-W1–SCR-W4. PR 1 Task 1 says to "verify" the entry is present — but it is absent. The plan must change the task from a verification to a write task, and the write surface already lists this file, so the scope is already covered.

**ISSUE-F2** — NOTE
`NEWS.md` exists in the repo and is not in any PR's write surface. The new `SE()` generic and four S3 methods are public API exports that typically require a changelog entry. Should be confirmed and, if required, added to PR 3's write surface.

**ISSUE-F3** — NOTE
PR 2's write surface lists only four test files (`test-analysis-means.R`, `test-analysis-totals.R`, `test-analysis-freqs.R`, `test-analysis-corr.R`). Tasks 5–8 add attribute wiring to `get_ratios`, `get_quantiles`, `get_covariance`, and `get_diffs`, but the corresponding test files (`test-analysis-ratios.R`, `test-analysis-quantiles.R`, `test-analysis-covariance.R`, `test-analysis-diffs.R`) are absent from the write surface. Attribute tests for these four functions are unassigned.

---

## Issue Summary

| ID | Lens | Severity | Short description |
|----|------|----------|-------------------|
| G1 | Granularity | HOLD | PR 2 write surface (12 files) exceeds guideline |
| G2 | Granularity | NOTE | `get_diffs()` complexity understated at 3 min |
| G3 | Granularity | NOTE | PR 3 has 13 tasks — at upper bound |
| G4 | Granularity | NOTE | Snapshot CI fail on first push — note in plan |
| D2 | Dependency | HOLD | `devtools::document()` before oracle/consistency tests |
| D1 | Dependency | NOTE | check() before coverage() ordering inverted |
| D3 | Dependency | NOTE | PR 2 verification filter omits 4 wired functions |
| D4 | Dependency | NOTE | snapshot_review() placement ambiguous |
| A1 | Acceptance | HOLD | PR 2 ACs omit get_ratios/quantiles/covariance/diffs |
| A2 | Acceptance | HOLD | PR 2 get_diffs AC missing statistic/estimate_cols fields |
| A6 | Acceptance | HOLD | PR 3 no AC for coef() on wide-format survey_corr |
| A3 | Acceptance | NOTE | Coverage % is process gate, not behavioral observable |
| A4 | Acceptance | NOTE | No AC for SE() suppressing vcov_diagonal_only warning |
| S1 | Spec Coverage | HOLD | .build_survey_result_attr() file location diverges from spec §II |
| S2 | Spec Coverage | NOTE | confint() logical parm length guard unscheduled |
| S3 | Spec Coverage | NOTE | survey_totals "N" naming not in any AC |
| S4 | Spec Coverage | NOTE | 0-groups edge case unscheduled |
| S5 | Spec Coverage | NOTE | All-NA estimates edge case unscheduled |
| F1 | File Completeness | HOLD | Coverage Map row for test file missing — must be written |
| F2 | File Completeness | NOTE | NEWS.md not in any PR write surface |
| F3 | File Completeness | NOTE | PR 2 write surface omits 4 test files for wired functions |

**HOLD count: 7**
**NOTE count: 12**

---

## Required Resolutions Before PLAN_READY

1. **G1** — Decide: accept 12-file PR 2 as-is, or split into PR 2a/2b. Either choice is acceptable; the decision must be recorded.
2. **D2** — Move `devtools::document()` in PR 3 to after Task 7, or add a second `document()` call after Task 10.
3. **A1** — Add acceptance criteria to PR 2 for attribute presence on `get_ratios`, `get_quantiles`, `get_covariance`, and `get_diffs` (statistic + estimate_cols fields).
4. **A2** — Extend PR 2 `get_diffs` AC to verify `$statistic == "diffs"` and `$estimate_cols == c("estimate")`.
5. **A6** — Add PR 3 acceptance criterion: `coef(wide_format_corr_result)` throws `surveycore_error_result_method_unsupported`.
6. **S1** — Add an explicit architectural note in PR 1 or PR 3 confirming `.build_survey_result_attr()` lives in `analysis-helpers.R` (not `analysis-methods-coef-vcov.R` as spec §II implies).
7. **F1** — Change PR 1 Task 1 from "verify Coverage Map entry" to "add Coverage Map entry for `test-analysis-methods-coef-vcov.R` covering SCR-1, SCR-3, SCR-W1–SCR-W4."
8. **F3** — Add test file write surface entries to PR 2 for `test-analysis-ratios.R`, `test-analysis-quantiles.R`, `test-analysis-covariance.R`, `test-analysis-diffs.R`.

---

## Verdict: HOLD

No BLOCK-level findings. Seven HOLD-level findings require plan amendments before pipeline-ship can execute. The issues are concentrated in PR 2's acceptance-criteria section (items A1, A2, F3) and are straightforward additions. Resolve all 8 items above, update the plan, and re-review or advance directly to PLAN_READY at author's discretion.
