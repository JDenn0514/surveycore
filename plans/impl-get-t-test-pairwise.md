# Implementation Plan: `get_t_test()` + `get_pairwise()`

**ID:** get-t-test-pairwise
**Spec:** `plans/spec-get-t-test-pairwise.md` (v0.4, Approved)
**Decisions:** `plans/decisions-get-t-test-pairwise.md`
**Status:** Draft

---

## Overview

This plan delivers two exported analysis functions — `get_t_test()` for
design-based two-sample t-tests and `get_pairwise()` for all-vs-all pairwise
comparisons — along with their `print` methods, result S3 classes
(`survey_t_test`, `survey_pairwise`), and meta-key constants. Both functions
live in a single new file `R/analysis-t-test.R`. Neither function depends on
the `survey` package; both delegate variance estimation to `survey_glm()`.
`get_pairwise()` delegates pair-level computations to `get_t_test()` via
domain-column mutation (the `..surveycore_domain..` pattern).

---

## PR Map

- [ ] PR 1: `feature/get-t-test-pairwise` — implement `get_t_test()`, `get_pairwise()`, print methods, tests, and error-messages update

---

## PR 1: Design-Based T-Test and Pairwise Functions

**Branch:** `feature/get-t-test-pairwise`
**Depends on:** none

**Files (TDD order — tests before implementation):**

- `plans/error-messages.md` — add rows T-1, T-2, T-3, T-3g, P-1
- `R/analysis-helpers.R` — add `T_TEST_META_KEYS` and `PAIRWISE_META_KEYS` constants
- `tests/testthat/test-analysis-t-test.R` — all unit tests (happy paths, error paths, edge cases, print snapshots, meta contract)
- `R/analysis-t-test.R` — `get_t_test()`, `get_pairwise()`, `print.survey_t_test()`, `print.survey_pairwise()`, `.enumerate_pairs()`
- `tests/testthat/test-analysis-t-test-numerical.R` — oracle tests vs `survey::svyttest()`
- `changelog/feature-get-t-test-pairwise.md` — written last, before opening PR

---

### Step-by-Step Tasks

#### Infrastructure (no new R functions yet)

- [ ] **Task 1.1** — Open `plans/error-messages.md`. Add five new rows for the
  new classes: T-1 (`surveycore_error_by_not_two_levels`), T-2
  (`surveycore_warning_by_coerced`), T-3 / T-3g
  (`surveycore_error_by_empty_cell`, two message templates sharing one class
  name), and P-1 (`surveycore_error_by_one_level`). Use the message templates
  from §V of the spec verbatim. Commit this file change alone on the branch.

- [ ] **Task 1.2** — Open `R/analysis-helpers.R`. After the existing
  `DIFFS_META_KEYS` block (around line 106), add:
  ```r
  T_TEST_META_KEYS  <- c("group", "x", "by")
  PAIRWISE_META_KEYS <- c("group", "x", "by", "pval_adj")
  ```
  No other changes to this file in this task.

---

#### TDD Cycle A — `get_t_test()`

- [ ] **Task 2.1** — Create `tests/testthat/test-analysis-t-test.R`. Write the
  following test blocks (all `expect_error(class = ...)` blocks use the dual
  pattern: typed class check + `expect_snapshot(error = TRUE)`):

  **Happy path — `get_t_test()`:**
  - `get_t_test()` returns `survey_t_test` S3 class with correct column names
    and types (no `group`)
  - One row per stratum when `group` is active
  - `estimate == mean_b - mean_a` (manual calculation against raw formula)
  - `mean_a`, `mean_b` match weighted group means from `get_means()`
  - `t_stat == estimate / se`
  - `p_value == 2 * pt(-abs(t_stat), df = df)`
  - CI bounds use `qt((1 + conf_level)/2, df) * se` formula
  - `variance = "se"` omits `ci_low`, `ci_high`; `variance = c("se", "ci")`
    includes both
  - `label_values = TRUE` converts `level_a`/`level_b` codes to label strings
  - `label_values = FALSE` keeps raw codes
  - `label_vars = TRUE` and `label_vars = FALSE` accepted without error;
    output column names unchanged
  - `name_style = "broom"`: `se`→`std.error`, `ci_low`→`conf.low`,
    `ci_high`→`conf.high`, `p_value`→`p.value`, `df`→`parameter`;
    `t_stat` remains `t_stat`
  - `decimals = 2` rounds all double columns to 2 decimal places
  - Column-level `label` attributes match §3.7: `attr(result$level_a, "label")`
    equals `"{by_label} (A)"`, `attr(result$level_b, "label")` equals
    `"{by_label} (B)"`, `attr(result$p_value, "label")` equals `"P-Value"`,
    `attr(result$stars, "label")` equals `""`, and no output column has a
    `NULL` label attribute (use a design where `by` has a variable label so
    `by_label` is non-empty)
  - All four design classes: `survey_taylor`, `survey_replicate`,
    `survey_twophase`, `survey_nonprob` (one happy-path block each)
  - Print snapshot: `gss_design` (see Note below for fixture construction),
    `x = age`, `by = sex`, `decimals = 2` — full `print()` output including
    tibble body

  **Error paths — `get_t_test()`:**
  - `surveycore_error_by_not_two_levels` (T-1): `by` factor with 3 active levels
  - `surveycore_warning_by_coerced` (T-2): character `by`; integer `by`; logical
    `by` — **WARNING, not error**: use `expect_warning(class =
    "surveycore_warning_by_coerced", ...)` wrapping the call; capture result
    separately; add `expect_snapshot(warn = TRUE, ...)` for message text. One
    block per coercion type (character, integer, logical).
  - `surveycore_error_by_empty_cell` (T-3): 2-level `by` with one level having
    0 rows after NA removal (no group)
  - `surveycore_error_by_empty_cell` (T-3g): group stratum where one `by` level
    is empty; message must include stratum info
  - `surveycore_error_non_numeric_variable`: non-numeric `x`
  - `surveycore_error_wrong_variable_count`: expression that resolves to >1
    column
  - `surveycore_error_invalid_conf_level`: `conf_level = 1.5`
  - `surveycore_error_invalid_variance_arg`: `variance = "sd"`
  - `surveycore_error_na_rm_not_logical`: `na.rm = "yes"`
  - `surveycore_error_unsupported_class`: plain `data.frame` passed as design

  **Edge cases — `get_t_test()`:**
  - Character `by` coerces to factor; warning issued; result still valid
  - Integer `by` coerces to factor; warning issued
  - Logical `by` coerces to factor; warning issued
  - Ordered factor `by` is accepted as-is; no coercion warning issued
  - Domain estimation equivalence (SRS): construct a plain SRS design (no PSUs
    or strata) with a 3-level `by` factor; filter data to 2 levels and build a
    second SRS design; `get_t_test()` on both designs must agree on `estimate`,
    `se`, and `p_value` within tolerance `1e-10`/`1e-8`/`1e-6`. (For SRS,
    domain estimation and physical subsetting are numerically identical — this
    verifies the `active_mask`/`SURVEYCORE_DOMAIN_COL` path without requiring
    `surveytidy`.)
  - Empty-cell error before small-cell warning (ordering)
  - `min_cell_n = 0L` suppresses small-cell warning
  - `na.rm = FALSE` when `x` has no NAs: identical result to `na.rm = TRUE`
  - `na.rm = FALSE` when `x` has NAs: estimates match `na.rm = TRUE`; `n_a`/`n_b`
    exclude NA rows
  - `conf_level = 0.99`: CI bounds wider than at 0.95
  - `group` with multiple group vars: one row per unique group combination

  **Meta contract — `get_t_test()`:**
  - `meta(result)` contains keys: `design_type`, `n_respondents`, `conf_level`,
    `call`, `group`, `x`, `by`
  - `meta(result)$by` contains a `levels` sub-key with two active factor levels
    in reference-first order

- [ ] **Task 2.2** — Run `devtools::test(filter = "test-analysis-t-test")` on
  the new file. Confirm all blocks fail with "could not find function
  'get_t_test'" (or similar). Document the failure count before proceeding.

---

- [ ] **Task 3.1** — Create `R/analysis-t-test.R`. Implement `.enumerate_pairs()`
  per §4.3 of the spec. Implement `get_t_test()` per §3.6 execution flow,
  including:
  - `.validate_shared_args(variance, conf_level, name_style, decimals, na.rm,
    valid_variance = c("se", "ci"))` — this single call covers both spec steps
    2 and 3; do NOT add a separate `variance` subset check
  - `rlang::ensym()` capture for `x` and `by`
  - `by` coercion to factor with `surveycore_warning_by_coerced` warning
  - `.resolve_groups()` for `group`
  - `.build_group_combos()` for strata loop
  - Per-stratum: compute `active_mask` (logical vector: group membership AND
    non-NA `x`/`by`); create `design_g <- design` then set
    `design_g@data[[SURVEYCORE_DOMAIN_COL]] <- active_mask` — do NOT
    physically subset rows (that would break PSU/strata variance structure);
    pass `design_g` to `survey_glm()`; empty-cell error check (before
    small-cell warning); `length(coef(fit)) == 2L` check; extraction of
    `beta`, `V`, `t_stat`, `df`, `p_value`, CI, `mean_a`, `mean_b`, `n_a`,
    `n_b`, stars
  - `.apply_group_labels()` for group columns and `level_a`/`level_b`
  - `.apply_decimals()`, `.apply_name_style()`
  - Column-level `label` attributes per §3.7
  - `.make_result_tibble()` with `T_TEST_META_KEYS`; `meta_args` includes
    `by` key with appended `levels` sub-key
  Implement `print.survey_t_test()` per §3.9 header format.
  Add roxygen2 block for `get_t_test()`: `@export`, `@family analysis`,
  `@param` for all arguments, `@return`, `@examples` using `gss_2024`
  per package convention (filter to valid sex codes and coerce to factor
  as in the snapshot fixture).

- [ ] **Task 3.2** — Run `devtools::test(filter = "test-analysis-t-test")`.
  Confirm all `get_t_test()` test blocks pass GREEN. Note and fix any
  `get_t_test()`-related failures before proceeding. `get_pairwise()` tests
  should still fail.

---

#### TDD Cycle B — `get_pairwise()`

- [ ] **Task 4.1** — Add `get_pairwise()` tests to
  `tests/testthat/test-analysis-t-test.R`:

  **Happy path — `get_pairwise()`:**
  - Returns `survey_pairwise` S3 class with correct column names and types
  - One row per pair (no group)
  - One row per pair per group stratum (with group)
  - Pairs in lexicographic factor-level order (use a 3-level `by` to verify
    all 3 pairs)
  - `pval_adj = "holm"` applies Holm correction
  - `pval_adj = "none"` returns unadjusted p-values unchanged
  - `stars` computed from adjusted p-values (not raw)
  - With group: adjustment applied separately per stratum
  - `label_values = TRUE` converts `level_a`/`level_b` codes to label strings
    in the final `get_pairwise()` output (post-stacking; use a design where `by`
    has value labels — verify that conversion is applied once and not
    double-converted)
  - `label_values = FALSE` keeps raw codes in `level_a`/`level_b`
  - `label_vars = TRUE` / `FALSE` both accepted without error
  - `name_style = "broom"` renames correctly (same convention as `get_t_test()`)
  - All four design classes
  - Print snapshot: `gss_design` (see Note below for fixture construction),
    `x = age`, `by = sex` (2 levels, 1 pair), `pval_adj = "holm"`,
    `decimals = 2`
  - `get_pairwise()` on 2-level `by` matches `get_t_test()` estimate, SE,
    and unadjusted p-value (Quality Gate: cross-function consistency check)
  - Column-level `label` attribute for `p_value` is `"P-Value (holm)"` when
    `pval_adj = "holm"` and `"P-Value (none)"` when `pval_adj = "none"` (per
    §4.6 override; verifies the label reflects the applied method)

  **Error paths — `get_pairwise()`:**
  - `surveycore_error_by_one_level` (P-1): `by` with only 1 active level
  - `surveycore_error_invalid_pval_adj`: `pval_adj = "invalid_method"`

  **Edge cases — `get_pairwise()`:**
  - `by` with exactly 2 levels: produces exactly 1 pair
  - `by` with 4 levels: produces exactly 6 pairs
  - Domain estimation equivalence (SRS): construct a plain SRS design with a
    4-level `by` factor; filter data to 3 levels and build a second SRS design;
    `get_pairwise()` on both designs must produce the same 3 pairs with matching
    `estimate`, `se`, and unadjusted `p_value` within tolerance `1e-10`/`1e-8`/
    `1e-6`. (Verifies the per-pair domain-column mutation path without
    `surveytidy`.)

  **Meta contract — `get_pairwise()`:**
  - `meta(result)$pval_adj` matches the method passed
  - All `T_TEST_META_KEYS` keys present plus `pval_adj`

- [ ] **Task 4.2** — Run `devtools::test(filter = "test-analysis-t-test")`.
  Confirm new `get_pairwise()` blocks fail RED.

---

- [ ] **Task 5.1** — Add `get_pairwise()` and `print.survey_pairwise()` to
  `R/analysis-t-test.R` per §4.5 execution flow, including:
  - `.validate_shared_args()` + `pval_adj` validation
  - `rlang::ensym()` for `x` and `by`; `rlang::enquo(group)` for forwarding
  - `.apply_domain(design)` called once before the pair loop
  - Active-level computation: `levels(by_col)[tabulate(by_col[domain_mask]) > 0]`
  - `surveycore_error_by_one_level` when < 2 active levels
  - `.enumerate_pairs()` for pair list
  - Per-pair: domain-column mutation
    (`design_ab@data[[SURVEYCORE_DOMAIN_COL]] <- by_col %in% c(a, b) & domain_mask`),
    `by` re-leveling, `rlang::inject(get_t_test(...))` call
  - Stack results, apply p-value adjustment per group stratum via
    `stats::p.adjust()`, recompute `stars` from adjusted p-values
  - `.apply_decimals()`, `.apply_name_style()`
  - Column-level labels per §4.6 (override `p_value` label to include method)
  - `.make_result_tibble()` with `PAIRWISE_META_KEYS`; `meta_args` includes
    `pval_adj` key
  Add roxygen2 block for `get_pairwise()`: `@export`, `@family analysis`,
  `@param` for all arguments, `@return`, `@examples`.

- [ ] **Task 5.2** — Run `devtools::test(filter = "test-analysis-t-test")`.
  Confirm all tests pass GREEN (both `get_t_test()` and `get_pairwise()`
  blocks). Fix any failures before proceeding.

---

#### Numerical Oracle Tests

- [ ] **Task 6.1** — Create `tests/testthat/test-analysis-t-test-numerical.R`.
  Write oracle tests vs `survey::svyttest()` per §VI of the spec. All blocks
  guarded with `skip_if_not_installed("survey")`. Tests:
  - `get_t_test(nhanes_design, bpxsy1, by = riagendr)$estimate` matches
    `svyttest()` coefficient, tolerance `1e-10`
  - `t_stat` matches `sv$statistic[["t"]]`, tolerance `1e-10`
  - `df` matches `sv$parameter[["df"]]`, tolerance `1e-10`
  - `p_value` matches `sv$p.value`, tolerance `1e-10`
  - SE matches `sqrt(vcov(sv_fit)[2,2])` (if extractable), tolerance `1e-8`
  - CI bounds, tolerance `1e-6`
  - `get_pairwise()` on 2-level `by`: estimate, SE, unadjusted p-value match
    `get_t_test()` results (consistency check, not oracle)

- [ ] **Task 6.2** — Run `devtools::test(filter = "test-analysis-t-test-numerical")`.
  Confirm numerical tests pass. `skip_if_not_installed("survey")` guards will
  skip cleanly in environments without `survey` installed.

---

#### Final Checks

- [ ] **Task 7.1** — Run `devtools::document()`. Verify `NAMESPACE` exports
  `get_t_test` and `get_pairwise`. Verify `man/get_t_test.Rd` and
  `man/get_pairwise.Rd` are generated. Verify no new `@importFrom` was
  introduced (all external calls use `::`).

- [ ] **Task 7.2** — Run `devtools::check()`. Must pass with 0 errors, 0
  warnings, ≤ 2 pre-approved notes. Fix any issues before proceeding. If
  examples fail, ensure all example code uses `library(surveycore)` only and
  references exported functions with valid inline data.

- [ ] **Task 7.3** — Verify Quality Gates from §VII of the spec:
  - [ ] 98%+ line coverage on `R/analysis-t-test.R` (run
    `covr::file_coverage("R/analysis-t-test.R", ...)` or check test output)
  - [ ] All five new error/warning classes have typed `expect_error(class = ...)`
    / `expect_warning(class = ...)` tests
  - [ ] All four design classes have ≥ 1 `get_t_test()` happy-path test
  - [ ] Numerical oracle tests pass vs `survey::svyttest()`
  - [ ] `get_pairwise()` on 2-level `by` matches `get_t_test()` results
  - [ ] `MEMORY.md` updated to reflect `get_t_test()` and `get_pairwise()` as
    implemented (add to the Implementation Status and key planning files sections)

- [ ] **Task 7.4** — Write `changelog/feature-get-t-test-pairwise.md`. Include:
  new functions `get_t_test()` and `get_pairwise()`, result S3 classes
  `survey_t_test` and `survey_pairwise`, print methods, and the five new
  error/warning classes. Do not commit yet.

---

### Acceptance Criteria

- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] Happy-path tests pass for all four design classes
- [ ] Numerical oracle tolerance: point 1e-10, SE 1e-8, CI 1e-6
- [ ] `get_pairwise()` on 2-level `by` matches `get_t_test()` estimate, SE,
  unadjusted p-value
- [ ] 98%+ line coverage on `R/analysis-t-test.R`
- [ ] All five new error/warning classes have typed tests
- [ ] `plans/error-messages.md` updated with T-1, T-2, T-3, T-3g, P-1
- [ ] `MEMORY.md` updated to reflect `get_t_test()` and `get_pairwise()` as
  implemented
- [ ] Changelog entry written and committed on this branch

---

### Notes for the Implementor

**Group-stratum domain masking in `get_t_test()`:** For each group stratum `g`,
create `design_g <- design` then set
`design_g@data[[SURVEYCORE_DOMAIN_COL]] <- active_mask`, where `active_mask`
is the logical vector combining group membership and non-NA `x`/`by`. Pass
`design_g` to `survey_glm()`. Do NOT physically subset rows — physical
subsetting removes PSU/strata rows from the data frame and breaks Taylor
variance estimation. `SURVEYCORE_DOMAIN_COL` (`"..surveycore_domain.."`) is
defined in `R/utils.R`.

**`survey_glm_fit@degf` is the raw design df:** The spec formula
`df = max(1, fit@degf - 1)` is correct. `fit@degf` holds the raw design
degrees of freedom (PSUs minus strata); subtract 1 for the 2-group residual.

**`length(coef(fit)) == 2L` check:** Run this check *after* `survey_glm()`
returns. `coef()` reads `fit@coefficients` in O(1). Do not use
`ncol(model.matrix(fit))` which re-evaluates the design matrix in O(n).

**Domain-column mutation in `get_pairwise()`:** The pattern is:
```r
domain_mask <- .apply_domain(design)  # called once before loop
# inside loop, for pair (a, b):
design_ab <- design
design_ab@data[[SURVEYCORE_DOMAIN_COL]] <-
  by_col %in% c(a, b) & domain_mask
```
This does NOT call `surveytidy::filter()` (circular dependency). The
`SURVEYCORE_DOMAIN_COL` constant (`"..surveycore_domain.."`) is defined in
`R/utils.R`. This mutation does not trigger S7 validators because `@data` is
the data frame slot — column modifications inside it are not validated.

**`by` re-leveling in `get_pairwise()` step 8b:**
```r
design_ab@data[[by_name]] <- factor(
  design_ab@data[[by_name]],
  levels = c(a, b)
)
```
This overwrites the factor levels so that `a` is the reference (column 2 of
model matrix = 0). Same mutation pattern — does not touch `@variables`.

**NSE forwarding in `get_pairwise()`:** Capture once with `rlang::ensym()`,
forward with `rlang::inject()`:
```r
x_name  <- rlang::as_name(rlang::ensym(x))
by_name <- rlang::as_name(rlang::ensym(by))
group_q <- rlang::enquo(group)
# inside loop:
rlang::inject(get_t_test(
  design_ab,
  x     = !!rlang::sym(x_name),
  by    = !!rlang::sym(by_name),
  group = !!group_q,
  conf_level   = conf_level,
  variance     = variance,
  na.rm        = na.rm,
  min_cell_n   = min_cell_n,
  decimals     = NULL,   # apply decimals at get_pairwise() level after stacking
  label_values = label_values,
  label_vars   = label_vars,
  name_style   = "surveycore"  # rename at get_pairwise() level
))
```
Note: pass `decimals = NULL` and `name_style = "surveycore"` to the inner
`get_t_test()` call; apply both transformations at the `get_pairwise()` level
after stacking, so they apply to the final assembled result, not to each
intermediate row.

**P-value adjustment with `group`:** After stacking all pair results, group
rows by group-stratum identity and apply `stats::p.adjust()` within each
stratum. Unadjusted p-values are overwritten; they are not retained in the
output.

**`level_a`/`level_b` overwrite in `get_pairwise()` step 8e:** After
`get_t_test()` returns for each pair, overwrite `result$level_a <- a` and
`result$level_b <- b` explicitly. `get_t_test()` may produce label-converted
values if `label_values = TRUE`; `get_pairwise()` will apply its own label
conversion at step 11 after stacking, so pass `label_values = FALSE` to the
inner `get_t_test()` call to avoid double-conversion.

**`label_vars` is accepted but unused:** Both functions accept `label_vars`
for API uniformity with other `get_*()` functions. Column names in the output
are fixed (`level_a`, `level_b`, `estimate`, etc.) and are not affected by
`label_vars`. No code branch needed; just include the argument in the
signature and do not act on it.

**`na.rm` semantics:** `na.rm` does NOT govern group-NA handling. NA rows in
`group` variables are ALWAYS excluded from all strata regardless of `na.rm`
(§3.5 is authoritative; §3.2's description of NA group rows forming their own
stratum was removed and is stale — ignore it). NA rows in `x` or `by` are
ALSO always excluded from `active_mask` — the GLM requires complete cases
regardless of `na.rm`. In practice, `na.rm` does not change behavior in
`get_t_test()`: `n_a`/`n_b` always reflect only complete-case rows, and
estimates are identical with `na.rm = TRUE` or `FALSE`. The argument is
accepted for API uniformity with other `get_*()` functions only.

**Error ordering in step 9.b:** Empty-cell check BEFORE small-cell warning.
Guard the warning with `0 < n < min_cell_n` (not just `n < min_cell_n`) to
avoid a "small cell" warning on a cell with 0 rows immediately before an
"empty cell" error.

**`level_a`/`level_b` label conversion in `get_t_test()`:** `level_a` and
`level_b` are NOT group columns — they hold factor level values for the `by`
variable. Reuse `.apply_group_labels()` via a temporary one-column data frame,
the same pattern `get_diffs()` uses for `treats`:
```r
tmp <- data.frame(val = c(level_a_val, level_b_val))
names(tmp) <- by_name
converted <- .apply_group_labels(tmp, by_name, design, label_values)[[1L]]
result_row$level_a <- converted[[1L]]
result_row$level_b <- converted[[2L]]
```
Do NOT write a new helper for this — `.apply_group_labels()` is the established
function.

**Print snapshot fixture — `gss_design`:** Print snapshot tests use
`gss_design` per CLAUDE.md's GSS preference (approved deviation from spec
§3.9/§4.8 which named `nhanes_design`; spec should be amended accordingly).
Construct the fixture as:
```r
gss_sub <- gss_2024[gss_2024$sex %in% c(1L, 2L) & !is.na(gss_2024$age), ]
gss_sub$sex <- factor(gss_sub$sex, levels = c(1, 2), labels = c("Male", "Female"))
gss_design  <- as_survey(gss_sub,
  ids = vpsu, weights = wtssps, strata = vstrat, nest = TRUE)
```
Use `x = age`, `by = sex`, `decimals = 2`.

**Numerical oracle tests use NHANES:** Task 6.1 oracle tests must use
`nhanes_2017` (they compare against `survey::svyttest()` on NHANES data).
This is the only remaining plan reference to NHANES.
