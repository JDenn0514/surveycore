# Implementation Plan: Refactor `analysis-diffs.R`

**ID:** `refactor-diffs`
**Spec:** `plans/spec-refactor-diffs.md` (v0.3, approved 2026-04-01)
**Decisions:** `plans/decisions-refactor-diffs.md`

---

## Overview

This plan delivers the internal restructuring of `get_diffs()` described in
the spec. Three internal helpers are extracted from inline code —
`.extract_clean_estimates()`, `.extract_me_estimates()`, and
`.build_diffs_output()` — eliminating ~600 lines of near-identical duplication
and reducing `R/analysis-diffs.R` from ~1265 lines to ≤500. The public API
and all output structures are unchanged. A deliberate behavioral fix is
included: the `show_means = FALSE` + grouped ME + `show_pct_change = TRUE`
combination will now compute `pct_change` correctly instead of returning `NA`.

---

## PR Map

- [ ] PR 1: `refactor/analysis-diffs-helpers` — Extract `.extract_clean_estimates()`, `.extract_me_estimates()`, `.build_diffs_output()` into `analysis-diffs-helpers.R` and replace inline branches in `get_diffs()`.

---

## PR 1: Refactor `analysis-diffs.R` helpers

**Branch:** `refactor/analysis-diffs-helpers`
**Depends on:** none

### Files (in TDD order — tests first):

- `tests/testthat/test-analysis-diffs-helpers.R` — Add tests for the three new helpers (`.extract_clean_estimates()`, `.extract_me_estimates()`, `.build_diffs_output()`), including happy paths, error paths, and all edge cases from spec §5.2. **Existing content is unchanged** (`.stars_pval()`, `.apply_name_style()`, `print.survey_diffs()`, `DIFFS_META_KEYS` — do not overwrite or delete.)
- `R/analysis-diffs-helpers.R` — Add three new helpers below `.stars_pval()`
- `R/analysis-diffs.R` — Replace Steps 11–17 inline branches with calls to the three new helpers; remove the `.build_output_rows()` inline closure

### Tasks (TDD order)

**Phase A — Baseline (before writing any new code)**

- [ ] A1: Run `devtools::test(filter = "diffs")` and record pass/fail counts. All tests must pass before refactor begins.
- [ ] A2: Confirm no existing test exercises `show_means = FALSE` + grouped design + `show_pct_change = TRUE` (pre-implementation audit per spec §VI exception note).

**Phase B — `.extract_clean_estimates()` (TDD)**

- [ ] B1: Write failing tests for `.extract_clean_estimates()` in `test-analysis-diffs-helpers.R`:
  - Happy path: returns all 10 expected keys for a 3-level treatment design
  - Level name parsing: strips variable prefix from `term` column
  - `result_means` equals `reference_mean + result_estimates`
  - `result_groups` is `NULL`, `preds_df` is `NULL`
  - Error: missing intercept — `expect_error(class = "surveycore_error_reference_row_not_found")` on direct helper call
  - Snapshot on direct helper call: `expect_snapshot(error = TRUE, .extract_clean_estimates(...))`
  - Snapshot on public API: `expect_snapshot(error = TRUE, get_diffs(...))` exercising the same code path
- [ ] B2: Run `devtools::test(filter = "diffs-helpers")` — confirm new tests are red.
- [ ] B3: Implement `.extract_clean_estimates()` in `R/analysis-diffs-helpers.R` per spec §3.1.
- [ ] B4: Run `devtools::test(filter = "diffs-helpers")` — confirm `.extract_clean_estimates()` tests are green.

**Phase C — `.extract_me_estimates()` (TDD)**

- [ ] C1: Write failing tests for `.extract_me_estimates()` in `test-analysis-diffs-helpers.R`:
  - Happy path (no groups): `result_groups = NULL`, `reference_mean = NULL`
  - Happy path (with groups): `result_groups` is a data.frame with correct group columns
  - `suppress_mean = TRUE`: `preds_df` is `NULL`, `result_means` is `NULL`
  - Contrast parsing: level names parsed correctly from `"X - ref"` format
  - `scale = "link"`: `me_type = "link"` passed to `avg_slopes()`
- [ ] C2: Run `devtools::test(filter = "diffs-helpers")` — confirm new tests are red.
- [ ] C3: Implement `.extract_me_estimates()` in `R/analysis-diffs-helpers.R` per spec §3.2.
- [ ] C4: Run `devtools::test(filter = "diffs-helpers")` — confirm `.extract_me_estimates()` tests are green.

**Phase D — `.build_diffs_output()` (TDD)**

- [ ] D1: Write failing tests for `.build_diffs_output()` in `test-analysis-diffs-helpers.R`:
  - No-group, clean path: `col_vecs` structure matches current implementation
  - No-group, ME path: same
  - Grouped path: `groups_df` has correct columns and row count
  - Small-cell warning: `expect_warning(class = "surveycore_warning_small_cell")` — `expect_warning()` only, no snapshot
  - No warning when `n == 0`: zero-count reference level does not warn
  - P-value adjustment, no groups: adjusts non-reference rows globally
  - P-value adjustment, with groups: adjusts independently within each group
  - `pct_change` computation: correct value for each treatment row
  - `pct_change` with `show_means = FALSE`: `ref_mean` from fallback; correct on both clean and ME paths
  - `pct_change` with `show_means = FALSE` + grouped ME + `show_pct_change = TRUE`: `pct_change` is computed (regression lock-in per spec §5.2 and §VI exception)
  - `pct_change` zero-ref warning: `expect_warning(class = "surveycore_warning_pct_change_zero_ref")` — `expect_warning()` only, no snapshot
  - `suppress_mean`: `mean` and `pct_change` columns absent
  - Conditional columns: spot-check combinations of `variance`, `n_weighted`, `show_means`
- [ ] D2: Run `devtools::test(filter = "diffs-helpers")` — confirm new tests are red.
- [ ] D3: Implement `.build_diffs_output()` in `R/analysis-diffs-helpers.R` per spec §3.3.
- [ ] D4: Run `devtools::test(filter = "diffs-helpers")` — confirm `.build_diffs_output()` tests are green.

**Phase E — Wire `get_diffs()` to new helpers**

- [ ] E1: In `R/analysis-diffs.R`, replace Steps 11–17 with the skeleton from spec §IV:
  - `if (!use_marginaleffects)` branch: set `estimate_method`, `mean_method`, `estimate_scale`; call `.extract_clean_estimates()`
  - `else` branch: set `estimate_method`, `mean_method`, `estimate_scale`; call `.extract_me_estimates()`
  - Call `.build_diffs_output()` using the return value of whichever extract helper ran
  - Unpack `out$col_vecs` and `out$groups_df`
  - Remove the inline `.build_output_rows()` closure
  - Remove the old non-group and grouped branches (Steps 12–17 original code)
- [ ] E2: Run `devtools::test(filter = "diffs")` — all existing tests (all four test files) must pass.
- [ ] E3: Confirm all existing snapshots pass unchanged (zero snapshot failures; any failure for the `show_means = FALSE` + grouped + `show_pct_change = TRUE` combination is expected and should be updated to reflect corrected `pct_change` values).

**Phase F — Quality gates**

- [ ] F1: Verify `R/analysis-diffs.R` is ≤500 lines (`wc -l R/analysis-diffs.R`). (Spec target is ~400 lines; ≤500 is the hard gate.)
- [ ] F2: Run `covr::file_coverage("R/analysis-diffs-helpers.R")` — verify 100% line coverage on new helpers.
- [ ] F3: Run `devtools::document()` — verify no NAMESPACE or `.Rd` changes (refactor is internal-only).
- [ ] F4: Run `devtools::check()` — 0 errors, 0 warnings, ≤2 pre-approved notes.
- [ ] F5: Write `changelog/refactor-analysis-diffs.md` entry (standard format, on this branch).

### Acceptance Criteria

- [ ] All new tests confirmed failing (red) before implementation began (Phases B2, C2, D2)
- [ ] `devtools::test(filter = "diffs")` — 0 failures, 0 skips across all four diffs test files
- [ ] All existing `get_diffs()` snapshots pass unchanged (exception: `show_means = FALSE` + grouped + `show_pct_change = TRUE` combination updated to corrected values)
- [ ] `R/analysis-diffs.R` ≤500 lines (spec target ~400)
- [ ] `R/analysis-diffs-helpers.R` contains `.stars_pval()` + three new helpers
- [ ] 100% line coverage on `R/analysis-diffs-helpers.R`
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ unchanged
- [ ] Changelog entry written and committed on this branch

### Notes

- The spec §VI has a quality-gate exception: `show_means = FALSE` + grouped ME + `show_pct_change = TRUE` will produce correct `pct_change` values instead of `NA`. No existing test is expected to cover this combination (confirmed at step A2). If one is found, update it to the corrected value rather than reverting the fix.
- The defensive `!use_marginaleffects && has_group` branch (lines 808–813 of current `analysis-diffs.R`, labeled "Should not happen") is intentionally removed. The invariant is enforced by Step 10 of `get_diffs()`.
- `domain_mask` is computed in `get_diffs()` before the `.build_diffs_output()` call and passed as a parameter — `.apply_domain()` does NOT move inside the helper.
- For `.build_diffs_output()` unit tests: construct mock `result` lists inline for edge cases; call `.extract_clean_estimates()` or `.extract_me_estimates()` first for happy-path behavioral comparison.
- The `avg_slopes()` / `avg_predictions()` calls use an explicit `if`/`else` structure to keep `by` genuinely absent (not `NULL`) in the no-group case — matching the current two-branch pattern.
- `groups_df` in the no-group case is `data.frame()` (0×0), not an N×0 data frame. Downstream code checks only `ncol(groups_df) > 0L`.
