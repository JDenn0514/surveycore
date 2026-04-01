# refactor/analysis-diffs-helpers — Extract helpers from `get_diffs()`

**Branch:** `refactor/analysis-diffs-helpers`
**Date:** 2026-04-01
**Plan:** `plans/impl-refactor-diffs.md` — PR 1

## Summary

Refactors the internals of `get_diffs()` by extracting three large inline
code blocks (~600 lines of near-identical duplication) into dedicated helpers
in `R/analysis-diffs-helpers.R`. The public API is unchanged and all existing
tests pass without modification. As a side effect, a pre-existing bug is fixed:
`show_means = FALSE` + grouped marginal effects + `show_pct_change = TRUE` now
correctly computes `pct_change` instead of returning `NA`.

## Changes

### `R/analysis-diffs-helpers.R`
- Added `.extract_clean_estimates(fit, treats_name, conf_level)`: encapsulates
  the clean-path coefficient extraction (previously inline in `get_diffs()`
  Steps 11 clean branch). Calls `clean()`, identifies the intercept row,
  strips the variable prefix from level names, computes `result_means` as
  `reference_mean + estimates`. Returns a named 10-key list. Aborts with
  `surveycore_error_reference_row_not_found` when the intercept row is absent
  or duplicated.
- Added `.extract_me_estimates(fit, treats_name, group_names, ref_level, scale, suppress_mean)`:
  encapsulates the marginaleffects-path estimate extraction (previously inline
  Steps 11 ME branch). Calls `avg_slopes()` and (conditionally) `avg_predictions()`
  using a genuine `if`/`else` structure that keeps `by` absent (not `NULL`) in
  the no-group case. Handles both grouped and non-grouped cases. Returns the
  same 10-key list as `.extract_clean_estimates()`.
- Added `.build_diffs_output(result, design, ...)`: unified replacement for
  the duplicated non-group and grouped output-building branches (previously
  inline Steps 12–17, ~600 lines). A single group-combo loop handles both
  cases, eliminating the separate branches. Implements small-cell warnings,
  p-value adjustment (globally for no-groups, per-combo for groups), stars,
  and `pct_change` with the fallback `ref_mean` for `show_means = FALSE`.
  Returns `list(col_vecs, groups_df)`.
- Added `# nocov` annotation on one defensive branch that is unreachable via
  the public API (ME path, `show_means = TRUE`, `suppress_mean = FALSE`, but
  `preds_df = NULL`).

### `R/analysis-diffs.R`
- Reduced from ~1265 lines to 499 lines.
- Steps 11–17 replaced with calls to the three new helpers.
- The inline `.build_output_rows()` closure is removed.
- The defensive `!use_marginaleffects && has_group` branch (lines 808–813,
  labeled "Should not happen") is removed; the invariant is enforced by Step 10.
- Minor inline comment reduction to meet the ≤500-line hard gate.

### `tests/testthat/test-analysis-diffs-helpers.R`
- Added 56 new tests across three new test categories:
  - Category 5: `.extract_clean_estimates()` — happy paths, key structure,
    level name parsing, `result_means` formula, error path (missing intercept
    with class and snapshot checks).
  - Category 6: `.extract_me_estimates()` — no-group and grouped happy paths,
    `suppress_mean = TRUE`, contrast parsing, `scale = "link"` structure check.
  - Category 7: `.build_diffs_output()` — no-group clean and ME paths, grouped
    path, small-cell warnings, no-warning for `n == 0`, p-value adjustment
    (global and per-group), `pct_change` computation, `show_means = FALSE`
    fallback on both paths, regression lock-in for the grouped ME bug fix,
    zero-ref warning, `suppress_mean`, conditional columns (`variance`,
    `n_weighted`, `show_means`).

### `tests/testthat/_snaps/analysis-diffs-helpers.md`
- Updated snapshot for `surveycore_error_reference_row_not_found` (previously
  showed "could not find function" before implementation; now shows the correct
  CLI error message).

## Coverage
- `R/analysis-diffs-helpers.R`: 100% line coverage (1 defensive branch marked
  `# nocov`).
- All existing `get_diffs()` tests pass unchanged (279 tests, 0 failures).

## Quality gates
- `devtools::test(filter = "diffs")`: 279 tests, 0 failures, 0 skips
- `devtools::check()`: 0 errors, 0 warnings, 1 pre-approved note
- `R/analysis-diffs.R`: 499 lines (≤500 hard gate)
- `devtools::document()`: NAMESPACE unchanged, no new `.Rd` files
