# Implementation Plan: coef(), vcov(), SE(), and confint() for survey_result

**Version:** 3.0
**Date:** 2026-06-22
**Status:** Ready

**Plan-review HOLDs resolved (2026-06-22):** G1 (keep PR 2 as 12 files — builder
handles independent wiring tasks; splitting adds overhead without benefit), D2
(document() re-run guard added to Task 12), A1 (PR 2 ACs extended to all 8
get_*() functions), A2 (diffs AC extended with statistic + estimate_cols), A6 (PR
3 AC added for coef() on wide-format corr), S1 (architectural note added to PR 1),
F1 (PR 1 Task 1 changed from verify to write), F3 (PR 2 write surface extended to
8 test files). NOTEs addressed: G2 (diffs time 3→8 min), D3 (filter broadened),
A4 (SE() warning suppression AC), F2 (NEWS.md added to PR 3 write surface).

---

## PR 1: Error table + infrastructure [x]

**Branch:** `feature/coef-vcov-attr-infrastructure`
**Target:** `develop`
**Depends on:** none
**Shipped:** PR #148, squash merged 2026-06-23, SHA `758fc8c`

**Architectural note (vs. spec §II):** `.build_survey_result_attr()` is placed
in `R/analysis-helpers.R` rather than `R/analysis-methods-coef-vcov.R`. This is
intentional — the helper is consumed by all `get_*()` functions in PR 2, which
predates the methods file added in PR 3. Placing it in `analysis-helpers.R`
avoids the builder in PR 3 needing to edit PR 1's write surface. The spec §II
architecture section should be read as describing ownership of the *attribute
schema*, not the physical file location of the constructor helper.

### Tasks

1. (3 min) Add new error/warning rows to `plans/error-messages.md`. Insert them
   into the existing "coef-vcov-methods rows (2026-06-22)" section — confirm
   that SCR-1, SCR-3, SCR-W1, SCR-W2, SCR-W3, SCR-W4 are all present. (These
   were already written to that section in the current file; verify nothing is
   missing.) **Also write the Coverage Map entry for
   `test-analysis-methods-coef-vcov.R`** mapping SCR-1, SCR-3, SCR-W1, SCR-W2,
   SCR-W3, SCR-W4. This row is absent from the current file and must be added —
   do not skip this; the AC for PR 1 requires it.

2. (2 min) Read the current `.make_result_tibble()` signature in
   `R/analysis-helpers.R` to confirm existing parameters and defaults.

3. (4 min) Write failing tests in `tests/testthat/test-analysis-helpers.R`:
   - Assert that calling `.make_result_tibble()` with
     `estimate_cols = c("mean"), statistic = "mean", cell_df = NULL`
     attaches `attr(result, ".survey_result")` whose names are exactly
     `c("estimate_cols", "group_cols", "statistic", "df")` (no `$var` field).
   - Assert `attr(result, ".survey_result")$df` is `rep(Inf, 1)` when
     `cell_df = NULL` and the result has one row.
   - Assert the `stopifnot()` guard fires when `estimate_cols` is non-`NULL`
     but `statistic` is `NULL`.
   - Assert that calling `.make_result_tibble()` without any of the three new
     params produces identical output to current behavior (no attribute).

4. (4 min) Add `.build_survey_result_attr()` to `R/analysis-helpers.R`.
   Signature: `estimate_cols`, `group_cols`, `statistic`, `cell_df`.
   - No `design` argument (removed from old spec).
   - Programmer-error `stopifnot()` guards:
     `length(estimate_cols) >= 1L`, `length(statistic) == 1L`,
     `!is.na(statistic)`.
   - Returns `list(estimate_cols = estimate_cols, group_cols = group_cols,
     statistic = statistic, df = cell_df)`.
   - Does NOT validate `cell_df` length (caller's responsibility).

5. (4 min) Extend `.make_result_tibble()` with three new optional parameters
   at the end: `estimate_cols = NULL`, `statistic = NULL`, `cell_df = NULL`.
   - Add the named-condition `stopifnot()` guard:
     `"Both 'estimate_cols' and 'statistic' must be supplied together, or both
     must be NULL." = is.null(estimate_cols) == is.null(statistic)`.
   - When `estimate_cols` is non-`NULL` and `cell_df` is `NULL`, compute
     `p <- nrow(result) * length(estimate_cols)` and set
     `cell_df <- rep(Inf, p)`.
   - Call `.build_survey_result_attr(estimate_cols, group_cols, statistic,
     cell_df)` and attach the result as `attr(result, ".survey_result")`.
   - The attribute is attached after the existing `attr(result, ".meta")`
     assignment.

6. (2 min) Verify the failing tests now pass
   (`devtools::test(filter = "helpers")`).

7. (1 min) Confirm no existing tests break (`devtools::test()`).

### Files touched

- `R/analysis-helpers.R`
- `tests/testthat/test-analysis-helpers.R`
- `plans/error-messages.md` (add Coverage Map entry for `test-analysis-methods-coef-vcov.R`)

### Acceptance criteria

- `attr(result, ".survey_result")` returned by `.make_result_tibble()` when
  `estimate_cols = c("mean"), statistic = "mean"` is a list with names
  exactly `c("estimate_cols", "group_cols", "statistic", "df")` — no `$var`.
- `attr(result, ".survey_result")$df` is `rep(Inf, 1)` when `cell_df = NULL`
  and result has one row (non-calibrated default).
- Calling `.make_result_tibble()` without the three new params produces
  identical output to the current implementation.
- The `stopifnot()` guard fires when exactly one of `estimate_cols` /
  `statistic` is non-`NULL`.
- All existing tests pass.

---

## PR 2: Wire attribute into all get_*() functions [x]

**Branch:** `feature/coef-vcov-wire-getstar`
**Target:** `develop`
**Depends on:** PR 1 merged
**Shipped:** PR #149, squash merged 2026-06-23, SHA `61ce3fc`

### Tasks

1. (5 min) Write failing tests:
   - In `test-analysis-means.R`: assert `.survey_result` attribute is present
     with `estimate_cols = c("mean")` and `statistic = "mean"`.
   - In `test-analysis-totals.R`: assert `estimate_cols = c("total")`.
   - In `test-analysis-freqs.R`: assert `estimate_cols = c("pct")`.
   - In `test-analysis-corr.R`: assert long-format result has
     `estimate_cols = c("r")`; wide-format result has
     `is.null(attr(result, ".survey_result"))`.
   - In `test-analysis-ratios.R`: assert `estimate_cols = c("ratio")` and
     `statistic = "ratio"`.
   - In `test-analysis-quantiles.R`: assert `estimate_cols = c("estimate")` and
     `statistic = "quantile"`.
   - In `test-analysis-covariance.R`: assert `estimate_cols = c("covariance")`
     and `statistic = "covariance"`.
   - In `test-analysis-diffs.R`: assert attribute is non-`NULL`,
     `estimate_cols = c("estimate")`, and `statistic = "diffs"`.

2. (3 min) Update `get_means()` in `R/analysis-means.R`: add
   `estimate_cols = c("mean"), statistic = "mean"` to every
   `.make_result_tibble()` call. Non-calibrated designs pass `cell_df = NULL`.
   Calibrated Taylor designs pass the per-cell df vector already computed at
   lines ~238 and ~261 (where the CI df is computed), replacing any
   `NA_real_` entries with `Inf` before passing:
   `cell_df[is.na(cell_df)] <- Inf`.

3. (3 min) Update `get_totals()` in `R/analysis-totals.R` analogously:
   `estimate_cols = c("total"), statistic = "total"`. Same calibrated df
   threading rule.

4. (3 min) Update `get_freqs()` in `R/analysis-freqs.R`:
   `estimate_cols = c("pct"), statistic = "freq"`. Same calibrated df rule.

5. (3 min) Update `get_ratios()` in `R/analysis-ratios.R`:
   `estimate_cols = c("ratio"), statistic = "ratio"`. Same calibrated df rule.

6. (3 min) Update `get_quantiles()` in `R/analysis-quantiles.R`:
   `estimate_cols = c("estimate"), statistic = "quantile"`. Non-calibrated
   designs use `cell_df = NULL`.

7. (3 min) Update `get_corr()` in `R/analysis-corr.R`: the long-format
   `.make_result_tibble()` call gets `estimate_cols = c("r"), statistic =
   "corr"`. The wide-format call passes no `estimate_cols` (leaves `NULL`
   default). Confirm there are exactly two `.make_result_tibble()` call
   paths in this file and only the long-format path is modified.

8. (3 min) Update `get_covariance()` in `R/analysis-covariance.R`:
   `estimate_cols = c("covariance"), statistic = "covariance"`. Same
   calibrated df rule.

9. (8 min) Update `get_diffs()` in `R/analysis-diffs.R`. (Higher complexity than
   Tasks 2–8 — requires manual attribute attachment, df extraction from
   `fit@degf`, and `group_cols` extraction from `.meta`. Budget accordingly.)
   This function sets
   the class directly without going through `.make_result_tibble()`. The
   `.survey_result` attribute must be attached manually:
   a. While `fit` is still in scope, compute
      `df_val <- as.numeric(fit@degf)`.
   b. Determine `p` = number of non-reference contrast rows.
   c. Extract `group_cols` as `names(attr(result, ".meta")$group)` (empty
      character vector when no groups).
   d. Call `.build_survey_result_attr(estimate_cols = c("estimate"),
      group_cols = group_cols, statistic = "diffs",
      cell_df = rep(df_val, p))`.
   e. Attach: `attr(result, ".survey_result") <-
      .build_survey_result_attr(...)`.
   f. The attribute attachment must occur after the class is already set on
      the result tibble and after any row reordering (result rows must be
      in group-major order before attachment).

10. (2 min) Verify all new attribute tests pass:
    `devtools::test(filter = "analysis-(means|totals|freqs|corr|ratios|quantiles|covariance|diffs)")`.

11. (2 min) Confirm no existing tests break (`devtools::test()`).

### Files touched

- `R/analysis-means.R`
- `R/analysis-totals.R`
- `R/analysis-freqs.R`
- `R/analysis-ratios.R`
- `R/analysis-quantiles.R`
- `R/analysis-corr.R`
- `R/analysis-covariance.R`
- `R/analysis-diffs.R`
- `tests/testthat/test-analysis-means.R`
- `tests/testthat/test-analysis-totals.R`
- `tests/testthat/test-analysis-freqs.R`
- `tests/testthat/test-analysis-corr.R`
- `tests/testthat/test-analysis-ratios.R`
- `tests/testthat/test-analysis-quantiles.R`
- `tests/testthat/test-analysis-covariance.R`
- `tests/testthat/test-analysis-diffs.R`

### Acceptance criteria

- `attr(get_means(d, y1), ".survey_result")$estimate_cols` is `c("mean")`.
- `attr(get_totals(d, y1), ".survey_result")$estimate_cols` is `c("total")`.
- `attr(get_freqs(d, x), ".survey_result")$estimate_cols` is `c("pct")`.
- Long-format `get_corr(d, c(y1, y2))` result has
  `attr(result, ".survey_result")$estimate_cols == c("r")`.
- Wide-format `get_corr(d, c(y1, y2))` result has
  `is.null(attr(result, ".survey_result"))`.
- `attr(get_ratios(d, y1, y2), ".survey_result")$estimate_cols` is `c("ratio")`.
- `attr(get_quantiles(d, y1), ".survey_result")$estimate_cols` is `c("estimate")`.
- `attr(get_covariance(d, y1, y2), ".survey_result")$estimate_cols` is
  `c("covariance")`.
- `attr(get_diffs(d, y1, by = trt), ".survey_result")` is non-`NULL`; its
  `$estimate_cols` field is `c("estimate")`, its `$statistic` field is `"diffs"`,
  and its `$df` field is `rep(as.numeric(fit@degf), p)` (a numeric vector of
  length p, not a scalar).
- Calibrated Taylor `get_means()` result has `$df` storing the per-cell finite
  df vector; non-calibrated result has `$df == rep(Inf, p)`.
- All existing tests pass.

---

## PR 3: coef(), vcov(), SE(), confint() methods and SE() generic [x]

**Branch:** `feature/coef-vcov-methods`
**Target:** `develop`
**Depends on:** PR 2 merged
**Shipped:** bundled into PR #150, squash merged 2026-06-23, SHA `7c4373f`

### Tasks

1. (5 min) Write failing structural tests in
   `tests/testthat/test-analysis-methods-coef-vcov.R` covering:
   - `SE` generic is exported and callable as `surveycore::SE`.
   - `SE.default` delegates to `sqrt(diag(vcov()))` on an `lm` object.
   - `coef()` returns named numeric(1) with name `"y1"` for ungrouped mean.
   - `coef()` returns group-major colon-separated names for grouped mean.
   - `vcov()` returns a 1×1 matrix with dimname `"y1"` for ungrouped mean.
   - `vcov()` off-diagonal is exactly 0 for grouped means.
   - `SE(result)` equals `sqrt(diag(vcov(result)))` within `1e-14`.
   - `confint()` returns a 2-column matrix with column names `c("2.5 %",
     "97.5 %")`.
   - `confint(result, level = 0.90)` column names are `c("5 %", "95 %")`.
   - Zero-row result: `coef()` returns `named numeric(0)`;
     `vcov()` returns a `0×0` matrix with `dimnames` both `character(0)`.

2. (4 min) Write failing error/warning tests:
   - `coef()` on `survey_t_test` throws `surveycore_error_result_method_unsupported`
     + snapshot.
   - `coef()` on `survey_pairwise` throws same class + snapshot.
   - `vcov()` on `survey_t_test` throws same class + snapshot.
   - `SE()` on `survey_t_test` throws same class + snapshot.
   - `confint()` on `survey_t_test` throws same class + snapshot.
   - `coef()` on result with stripped attribute (`.survey_result` set to
     `NULL`) throws same class + snapshot.
   - `vcov()` and `confint()` on stripped-attribute result throw same class.
   - `confint(result, level = 0)` throws `surveycore_error_invalid_conf_level`
     + snapshot.
   - `confint(result, level = 1)` throws same + snapshot.
   - `confint(result, level = NA)` throws same + snapshot.
   - `confint(result)` with `attr(result, ".survey_result")$df <- -1L` stored
     throws `surveycore_error_invalid_df` + snapshot.
   - `vcov()` on grouped means emits `surveycore_warning_vcov_diagonal_only`.
   - `vcov()` on multi-pair corr result emits
     `surveycore_warning_vcov_incomplete`.
   - `confint()` with `parm` containing `NA` emits `surveycore_warning_parm_na`
     + snapshot.
   - `confint()` with partially unmatched `parm` emits
     `surveycore_warning_parm_unmatched` + snapshot.
   - `confint()` with all unmatched `parm` emits same class + snapshot +
     returns `0×2` matrix.

3. (5 min) Create `R/analysis-methods-coef-vcov.R`. Define and export:
   - `SE()` generic: `SE <- function(object, ...) UseMethod("SE")`. Roxygen
     `@export`.
   - `SE.default()`: `SE.default <- function(object, ...)
     sqrt(diag(vcov(object, ...)))`. Include roxygen `@note` about masking
     `survey::SE` and the `svyby` + `cvpct` limitation.

4. (6 min) Implement `coef.survey_result()`:
   - Apply §III.0 preconditions in order: unsupported-class check (survey_t_test
     / survey_pairwise), then absent-attribute check, then wide-format
     survey_corr check (Template 4), then broom-rename check (Template 3).
   - Phase guard: `if (length(attr(object, ".survey_result")$estimate_cols)
     > 1L) stop("multi-estimate-column coef() not yet supported")`.
   - Extract the estimate column and assemble names per the class-specific
     rules in spec §III.5 (variable-major order; colon separator for group;
     dot separator for intra-row qualifiers like level, quantile, pair).
   - NA estimates: included as `NA_real_` with name assigned.
   - Zero-row result: return `named numeric(0)` with `names(result) ==
     character(0)`.

5. (6 min) Implement `vcov.survey_result()`:
   - Apply §III.0 preconditions (delegate to `coef()` which applies them).
   - Phase guard for `length(estimate_cols) > 1L`.
   - If `se` column is absent, return `p×p` matrix of `NA_real_` (no warning).
   - Coerce `NaN` in `se` to `NA_real_` before squaring.
   - Build block-diagonal matrix: diagonal = `se^2`; off-diagonal = 0 (or
     `NA_real_` for `survey_corr` with `>1` pair row).
   - Emit `surveycore_warning_vcov_incomplete` when class is `survey_corr` and
     there is more than one pair row.
   - Emit `surveycore_warning_vcov_diagonal_only` when `p > 1`.
   - Dimnames: both rownames and colnames equal `names(coef(object))`.
   - Zero-row result: return `matrix(numeric(0), nrow = 0, ncol = 0,
     dimnames = list(character(0), character(0)))`.

6. (3 min) Implement `SE.survey_result()`:
   - Body: `sqrt(diag(suppressWarnings(vcov(object))))`.
   - Roxygen `@note` explaining why `suppressWarnings()` is used
     (`vcov_diagonal_only` warning is irrelevant in the SE context).

7. (5 min) Implement `confint.survey_result()`:
   - Signature: `confint.survey_result <- function(object, parm, level = 0.95,
     ...)`.
   - Validate `level` first: `is.na(level)` check, then `!is.numeric(level)
     || length(level) != 1 || level <= 0 || level >= 1` throws
     `surveycore_error_invalid_conf_level`.
   - Apply §III.0 preconditions (via `coef(object)` call).
   - Resolve `parm`:
     - `missing(parm)`: use `seq_along(coef(object))`.
     - Character: drop `NA` elements with `surveycore_warning_parm_na`;
       match remaining against `names(coef(object))` via `match()`; drop
       unmatched with `surveycore_warning_parm_unmatched`.
     - Integer/logical: use directly (logical length guard with `stop()`).
     - Empty (`character(0)` or `integer(0)`): return `matrix(numeric(0),
       nrow = 0, ncol = 2, dimnames = list(character(0),
       c("2.5 %", "97.5 %")))`.
   - Validate `df[i]` for each resolved `parm` position: if
     `is.na(df[i]) || (is.finite(df[i]) && df[i] <= 0)`, throw
     `surveycore_error_invalid_df`.
   - Compute column names via
     `paste0(format(100 * (1 - level) / 2, trim = TRUE), " %")` and
     `paste0(format(100 * (1 - (1 - level) / 2), trim = TRUE), " %")`.
   - For each parameter `i`: `lower[i] <- coef[i] - qt(1 - (1-level)/2,
     df[i]) * SE[i]`; `upper[i]` analogously.
   - NA SE propagates to NA bounds.
   - Return matrix with `dimnames = list(names(coef(object))[parm], col_nms)`.

8. (3 min) Add roxygen2 documentation for all five exported items
   (`SE`, `SE.default`, `coef.survey_result`, `vcov.survey_result`,
   `SE.survey_result`, `confint.survey_result`). Run `devtools::document()`.
   Confirm `NAMESPACE` entries are generated correctly.

9. (3 min) Write numerical oracle tests (inside
   `test-analysis-methods-coef-vcov.R`):
   - `vcov.survey_result()` diagonal matches `survey::vcov.svystat` for
     ungrouped NHANES mean (`tolerance = 1e-8`).
   - Block-diagonal matches `survey::vcov.svyby` diagonal for grouped mean.
   - `SE.survey_result()` matches `survey::SE` for ungrouped NHANES mean.
   - `confint()` matches `survey::confint.svystat` at `1e-6`.
   - `coef() + SE()` vs `survey::svytotal` on `acs_pums_wy`.
   - `coef()` for `survey_freqs` matches `survey::svymean` proportions.
   - `coef()` for quantiles; `confint()` reproduces Woodruff CI bounds.
   - `coef()` and `SE()` for ratios.
   - `coef()` for covariance.
   - `coef()` names for diffs use `" - reference"` format.
   - `coef()` for long-format corr.

10. (3 min) Write cross-method consistency tests:
    - `SE(result) == sqrt(diag(vcov(result)))` within `1e-14` for each
      supported class.
    - CI midpoint equals `coef()` within `1e-12`.
    - `names(coef) == rownames(vcov) == colnames(vcov) == names(SE) ==
      rownames(confint)` for grouped and ungrouped cases.

11. (2 min) Run `testthat::snapshot_review()` to approve error/warning message
    snapshots generated in task 2.

12. (3 min) Re-run `devtools::document()` to ensure NAMESPACE reflects all
    exported items added since Task 8. Then verify all failing tests now pass.
    Run `devtools::check()` and confirm 0 errors, 0 warnings, ≤2 pre-approved
    notes.

13. (2 min) Run `covr::package_coverage()` on
    `R/analysis-methods-coef-vcov.R`. Confirm ≥ 98% line coverage.

### Files touched

- `R/analysis-methods-coef-vcov.R` (new)
- `tests/testthat/test-analysis-methods-coef-vcov.R` (new)
- `NAMESPACE` (generated — `devtools::document()`)
- `man/*.Rd` (generated — `devtools::document()`)
- `NEWS.md` (add entry for `SE()` generic and `coef`/`vcov`/`SE`/`confint`
  methods for `survey_result`)

### Acceptance criteria

- `surveycore::SE` resolves as a function without error.
- `SE.default` applied to an `lm` object equals `sqrt(diag(stats::vcov(mod)))`.
- `coef(get_means(d, y1))` returns named numeric(1) with `names == "y1"`.
- `coef(get_means(d, y1, group = strata))` returns colon-separated
  group-major names (`"A:y1"`, `"B:y1"`, etc.).
- `vcov(get_means(d, y1, variance = "se"))` is a 1×1 matrix with dimname `"y1"`;
  diagonal equals `result$se^2` within `1e-14`.
- Off-diagonal of grouped `vcov()` is exactly 0.
- `SE(result)` equals `sqrt(diag(suppressWarnings(vcov(result))))` within
  `1e-14`.
- `confint(result, level = 0.90)` column names are `c("5 %", "95 %")`.
- CI midpoint equals `coef(result)` within `1e-12`.
- Replicate design: `confint()` bounds match
  `coef ± qnorm(0.975) * SE` within `1e-10` (Inf df → normal approximation).
- Taylor design with 2 df: `confint()` half-width equals
  `qt(0.975, df = 2) * SE` within `1e-10`.
- `coef()` on `survey_t_test` throws `surveycore_error_result_method_unsupported`;
  snapshot matches.
- `coef()` on wide-format `survey_corr` result throws
  `surveycore_error_result_method_unsupported`; snapshot matches.
- `coef()` on result with stripped `.survey_result` attribute throws same class;
  snapshot matches.
- `confint(result, level = 0)` throws `surveycore_error_invalid_conf_level`;
  snapshot matches.
- `confint(result)` with `attr(result, ".survey_result")$df <- -1L` throws
  `surveycore_error_invalid_df`; snapshot matches.
- `vcov()` on grouped means emits `surveycore_warning_vcov_diagonal_only`.
- `vcov()` on multi-pair corr emits `surveycore_warning_vcov_incomplete`.
- `SE(result)` on a grouped result does NOT emit `surveycore_warning_vcov_diagonal_only`
  (the warning is suppressed inside `SE.survey_result()` via `suppressWarnings()`).
- `confint()` with `parm` containing `NA` emits `surveycore_warning_parm_na`;
  snapshot matches.
- Zero-row result: `coef()` returns `named numeric(0)`;
  `vcov()` is a `0×0` matrix with `dimnames == list(character(0),
  character(0))`; `SE()` returns `named numeric(0)` with
  `names(SE(result)) == character(0)`.
- `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes.
- ≥ 98% line coverage on `R/analysis-methods-coef-vcov.R`.
- `plans/error-messages.md` Coverage Map includes
  `test-analysis-methods-coef-vcov.R` covering SCR-1, SCR-3, SCR-W1,
  SCR-W2, SCR-W3, SCR-W4.

---

## PR sequence summary

| PR | Branch | Depends on | Files (write surface) |
|---|---|---|---|
| 1 | `feature/coef-vcov-attr-infrastructure` | none | `R/analysis-helpers.R`, `tests/testthat/test-analysis-helpers.R`, `plans/error-messages.md` |
| 2 | `feature/coef-vcov-wire-getstar` | PR 1 | `R/analysis-means.R`, `R/analysis-totals.R`, `R/analysis-freqs.R`, `R/analysis-ratios.R`, `R/analysis-quantiles.R`, `R/analysis-corr.R`, `R/analysis-covariance.R`, `R/analysis-diffs.R`, `tests/testthat/test-analysis-means.R`, `tests/testthat/test-analysis-totals.R`, `tests/testthat/test-analysis-freqs.R`, `tests/testthat/test-analysis-corr.R`, `tests/testthat/test-analysis-ratios.R`, `tests/testthat/test-analysis-quantiles.R`, `tests/testthat/test-analysis-covariance.R`, `tests/testthat/test-analysis-diffs.R` |
| 3 | `feature/coef-vcov-methods` | PR 2 | `R/analysis-methods-coef-vcov.R` (new), `tests/testthat/test-analysis-methods-coef-vcov.R` (new), `NAMESPACE` (generated), `man/*.Rd` (generated), `NEWS.md` |

No two PRs share a write surface. The sequence is strictly linear — PR 2
requires the updated `.make_result_tibble()` and `.build_survey_result_attr()`
from PR 1; PR 3 requires the `.survey_result` attributes populated by PR 2.
