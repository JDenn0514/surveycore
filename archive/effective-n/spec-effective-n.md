# Spec — effective-n

**Version:** 0.3
**Date:** 2026-05-04
**Status:** DRAFT
**Target version:** 0.9.x.9000

---

## Document Purpose

This is the source of truth for `get_effective_n()`, a new exported analysis
function that computes the effective sample size (and weight-based or full
design effect) for a survey design — overall or within subgroups. Nothing in
the implementation may contradict this document without a recorded decision.

---

## I. Scope

### In

- A new exported function `get_effective_n()` that computes:
  - **Kish method** (`method = "kish"`): Kish (1965) effective N from weights
    alone — `n_eff = (Σw)² / Σw²`. No reference variable required. This is a
    weight-only approximation; for clustered designs with equal weights it
    gives `n_eff = n` (deff_kish = 1.0) even when the true design effect is
    substantially greater. Use `method = "deff"` to capture the full design
    effect for a specific variable. The roxygen `@details` should include this
    limitation.
  - **DEFF method** (`method = "deff"`): design-effect-based effective N for a
    specified numeric variable — `n_eff = n / DEFF`, where
    `DEFF = Var_design / Var_SRS`. Requires `x`.
- Subgroup support via the standard `group` argument (same semantics as the
  rest of the `get_*()` family).
- Dispatch across all currently supported survey design classes:
  `survey_taylor`, `survey_replicate`, `survey_twophase`, `survey_nonprob`,
  and `survey_collection` (via `.id` / `.if_missing_var`).
- A consistent output tibble for both methods — columns `n` and `n_eff` are
  always present; `deff_kish` is present for `method = "kish"` and `deff` for
  `method = "deff"`, allowing downstream code to distinguish the two
  quantities by column name.
- A `decimals` argument for numeric rounding, matching the rest of the family.
- A `min_cell_n` warning for small unweighted cell counts.
- A new `survey_effective_n` S3 result class (inheriting `survey_result`),
  with a corresponding print method.

### Out

- Confidence intervals, standard errors, or any uncertainty quantification for
  `n_eff` itself. Effective N is a design-diagnostic, not an estimate with a
  sampling distribution in the normal sense.
- Support for multi-variable `x` with `method = "deff"`. DEFF is
  variable-specific; callers compute per-variable effective N by iterating.
- A `get_deff()` alias or wrapper. If needed, add as a trivial wrapper later.
- A `name_style = "broom"` column rename. No broom tidy/glance adapter for
  this function (it is a diagnostic, not a model output).
- `label_values` / `label_vars` arguments. The output contains no categorical
  values or variable-name cells that need labelling beyond what `group` already
  handles.

---

## II. Architecture

### Files

```
R/
  analysis-effective-n.R          — new; houses get_effective_n()
                                    + any single-use internal helpers
  analysis-meta.R                 — modified; register survey_effective_n
                                    meta constructor and FAMILY_META_KEYS entry
  methods-print.R                 — modified; add survey_effective_n print method
NAMESPACE                         — regenerated
man/get_effective_n.Rd            — generated
DESCRIPTION                       — version bump
NEWS.md                           — add entry
plans/error-messages.md           — new rows EN-1 through EN-4
```

### Shared helpers reused without modification

All of the following existing helpers in `R/analysis-helpers.R` are reused
as-is:

- `.resolve_groups()` — combine `@groups` + `group=` arg
- `.apply_domain()` — extract domain membership mask
- `.build_meta()` — assemble `.meta` list
- `.make_result_tibble()` — assemble result tibble + attach metadata
- `.validate_shared_args()` — validate `decimals`, `min_cell_n` (subset of
  full validation; see §III behavior rules)
- `.apply_decimals()` — round numeric output columns
- `.check_unsupported_class()` — throw for non-survey-base objects
- `.dispatch_over_collection()` — survey_collection dispatch
- `.build_group_meta()` — metadata lookup for group variables
- `.apply_group_labels()` — convert coded group columns to labelled factors

### New internal helpers

```r
# In R/analysis-effective-n.R (single use, stays in same file)
.kish_effective_n(weights)
# Computes (sum(weights))^2 / sum(weights^2) for a numeric weight vector.
# Returns NA_real_ when length(weights) == 0L.
```

The `method = "deff"` path introduces no new computation helper. The DEFF
branch inlines a call to `get_means(design, x, group = group,
variance = "deff", na.rm = na.rm, min_cell_n = min_cell_n, ...)` and
extracts the `n` and `deff` columns, then derives `n_eff = n / deff`.
DEFF computation is already validated and tested in `get_means()`; a
single-call-site wrapper would violate code-style.md §4 (inline helpers
when used in exactly one place).

---

## III. Function Spec — `get_effective_n()`

### Signature

```r
get_effective_n(
  design,
  x        = NULL,
  group    = NULL,
  method   = c("kish", "deff"),
  na.rm    = TRUE,
  decimals = NULL,
  min_cell_n = 30L,
  ...,
  .id             = NULL,
  .if_missing_var = NULL
)
```

### Argument table

| Argument | Type | Default | Description |
|---|---|---|---|
| `design` | survey design or `survey_collection` | — | A `survey_taylor`, `survey_replicate`, `survey_twophase`, `survey_nonprob`, or `survey_collection` object. |
| `x` | tidy-select | `NULL` | A single unquoted numeric variable name. Required when `method = "deff"`; ignored (with a message) when `method = "kish"`. Must resolve to exactly one column. |
| `group` | tidy-select | `NULL` | Optional grouping variable(s). Combined with any grouping set by `group_by()`. |
| `method` | character(1) | `"kish"` | Effective-N formula. `"kish"` uses the Kish (1965) weight-only approximation; `"deff"` uses the full design effect for variable `x`. |
| `na.rm` | logical(1) | `TRUE` | For `method = "kish"`: exclude observations with `NA` in any group variable before computing weight sums. For `method = "deff"`: passed to `get_means()` to control NA handling for `x`. |
| `decimals` | integer or `NULL` | `NULL` | If an integer, rounds `n_eff` and `deff` to this many decimal places. `n` is always an integer and is never rounded. |
| `min_cell_n` | integer | `30L` | Minimum unweighted cell count before `surveycore_warning_small_cell` fires. |
| `...` | | | Unused. Reserved so that `.id` and `.if_missing_var` remain named-only when a `survey_collection` is passed. |
| `.id` | character(1) or `NULL` | `NULL` | Column name used to identify each survey when `design` is a `survey_collection`. `NULL` resolves to the collection's stored `@id` property. Ignored for single designs. |
| `.if_missing_var` | `"error"`, `"skip"`, or `NULL` | `NULL` | How to handle surveys in a collection that lack `x` (for `method = "deff"`). `NULL` resolves to the collection's stored `@if_missing_var` property. Ignored for single designs and for `method = "kish"`. |

Argument order follows `code-style.md`: `design` first → NSE (`x`) →
optional NSE (`group`) → optional scalars (`method`, `na.rm`, `decimals`,
`min_cell_n`) → `...` → named-only control args.

### Output contract

`get_effective_n()` returns a `survey_effective_n` tibble (also inheriting
`survey_result`). Columns, in order:

| Column | Type | Present when | Description |
|---|---|---|---|
| `[.id]` | character | `design` is a `survey_collection` | Identifies each constituent survey. Column name is controlled by the `.id` argument (defaults to the collection's stored `@id` property). Follows the same convention as all other `get_*()` functions. |
| `[group_cols...]` | varies | grouping is active | One column per group variable, in the order they appear in `group`. |
| `n` | integer | always | Unweighted count of observations used in the computation. |
| `n_eff` | numeric | always | Effective sample size. |
| `deff_kish` | numeric | `method = "kish"` only | Weight-based design effect: `n / n_eff`. Captures only weight variation; ignores clustering and stratification. |
| `deff` | numeric | `method = "deff"` only | Full design effect: `Var_design / Var_SRS`. Captures clustering, stratification, and weights for variable `x`. |

The two `deff_*` columns are mutually exclusive — only one is present in any
given result, depending on `method`. The method used and, for `method = "deff"`,
the variable name, are stored in `meta(result)`, not as columns.

#### `.meta` structure

```r
list(
  group   = <group meta from .build_group_meta()>,   # NULL if no grouping
  x       = <variable meta from .extract_var_meta()>, # NULL if method = "kish"
  method  = "kish" or "deff",
  design_type = "taylor" | "replicate" | "twophase" | "nonprob" | "collection"
)
```

#### Print output

`print.survey_effective_n` follows the existing family template. Example
(method = "kish", no grouping):

```
# A <survey_effective_n> [1 × 3]  method: kish
      n n_eff deff_kish
  <int> <dbl>     <dbl>
1  5000  2834      1.76
```

Example (method = "deff", grouped by `race_eth`):

```
# A <survey_effective_n> [4 × 4]  method: deff  x: ridageyr
  race_eth      n n_eff  deff
  <fct>     <int> <dbl> <dbl>
1 Hispanic   1200   682  1.76
2 NH White   2100  1354  1.55
3 NH Black    900   469  1.92
4 Other       800   548  1.46
```

The header line always shows `method:`. When `method = "deff"`, it also shows
`x: <variable_name>`.

### Behavior rules

#### Kish method

1. For each domain (group combination), select the weight vector for
   observations in that domain where neither the weight nor any group variable
   is `NA` (when `na.rm = TRUE`). The weight vector used is the full-design
   weights for domain members; weights are not renormalized. This estimates
   the weight-based effective N within the domain and does not account for
   clustering or stratification within the domain. For a design-aware domain
   effective N, use `method = "deff"` with `x` specified.
2. Compute `n_eff = (sum(w))^2 / sum(w^2)` via `.kish_effective_n(w)`.
3. `n` = length of the active weight vector (after NA exclusion).
4. `deff_kish` = `n / n_eff`.
5. When all weights in a domain are equal, `n_eff == n` and `deff_kish == 1.0`.
6. When a domain has `n == 0` (after `na.rm`), return `n = 0L`,
   `n_eff = NA_real_`, `deff_kish = NA_real_` for that row.
   Note: `n_eff` is always finite and positive when `n > 0` and weights are
   finite, so `deff_kish` cannot be 0 and no special zero-guard is needed.
7. When `na.rm = FALSE`: NA weights are NOT excluded from the weight
   vector. If any weight in a domain is `NA`, `sum(w)` returns `NA`,
   so `n_eff = NA_real_` and `deff_kish = NA_real_` for that domain.
   NA group values are treated as a distinct group level, following
   `.apply_domain()` semantics (consistent with the rest of the
   `get_*()` family).

#### DEFF method

1. Validate that `x` is not `NULL` — error EN-2 otherwise.
2. Validate that `x` resolves to exactly one column — error EN-3 otherwise.
3. Internally call the mean estimation pipeline (equivalent to
   `get_means(design, x, group = group, variance = "deff", na.rm = na.rm,
   min_cell_n = min_cell_n, ...)`) and extract `n` and `deff` from the result.
   Each `group` combination produces one row. If a group level has zero
   in-domain observations after NA removal, `get_means()` handles it
   identically to the Kish rule 6 convention: `n = 0L`, `deff = NA_real_`,
   `n_eff = NA_real_`. Domain estimation semantics are inherited from
   `get_means(variance = "deff")` and do not diverge for any supported design
   type. The `deff` column returned by `get_means()` is defined as
   `(SE_design / SE_SRS)^2 = Var_design / Var_SRS` — verify this equivalence
   holds for all supported design types before implementing the extraction step.
   SE_SRS is computed under SRS of the domain-restricted sample of size `n_d`
   (standard `survey`-package convention), not under SRS of the full sample.
   When the design includes FPC, it is incorporated in SE_design via the mean
   estimation pipeline; SE_SRS does not include FPC, consistent with the SRS
   reference model.
4. Derive `n_eff = n / deff`.
5. When `deff` is non-finite — i.e., `!is.finite(deff)`, which covers
   `deff <= 0`, `Inf` (arises when `Var_SRS = 0`), `NaN` (arises when
   both variances are 0), and `NA_real_` (empty domain) — return
   `n_eff = NA_real_` for that row. Use `is.finite(deff)` as the guard
   in implementation.
6. For `survey_nonprob` designs, DEFF is computed mechanically using the same
   formula as probability designs. The result does not carry a design-based
   inference interpretation; treat it as a weight-efficiency diagnostic only.
7. DEFF is estimated from the design-based variance of the mean, which depends
   on degrees of freedom derived from the cluster/strata structure. When design
   df is small (e.g., few clusters per stratum), DEFF — and therefore `n_eff` —
   may be unstable. Users should inspect the underlying `get_means()` output in
   such cases.

#### Shared behavior

- `method` is matched via `match.arg()`, so `method = "k"` resolves to
  `"kish"`.
- When `method = "kish"` and `x` is not `NULL`, a message is issued:
  `"x" is ignored when method = "kish"`. This is an `rlang::inform()`, not
  a warning, since the call is still valid — `x` was just unnecessary.
- For `survey_replicate` designs, `.kish_effective_n()` operates on the main
  (analysis) weights only; replicate weights are not used in the Kish
  computation.
- For `survey_twophase` designs, `.kish_effective_n()` operates on the full
  combined analysis weights (equivalent to `weights(design)`), not
  phase-specific weights.
- Group resolution, domain application, and `survey_collection` dispatch
  follow the same semantics as all other `get_*()` functions. See the shared
  helper docs for details.
- `decimals` applies to `n_eff` and `deff` only. `n` is always integer.
- `min_cell_n` fires `surveycore_warning_small_cell` for any domain where
  `n < min_cell_n`, matching the family-wide convention. For
  `method = "deff"`, the warning is fired by `get_means()` internally
  and is not re-fired by `get_effective_n()`. For `method = "kish"`,
  `get_effective_n()` fires it directly after computing the weight sums.
  Zero-row domains (`n == 0`) return `NA` values silently; users can
  inspect the `n` column to detect empty cells. No separate empty-domain
  warning is issued — the `min_cell_n` mechanism (default 30) covers
  this case.

### Error table

Add the following rows to `plans/error-messages.md`:

| # | Function | Condition | Level | Error Class | cli Message Template |
|---|---|---|---|---|---|
| EN-1 | `get_effective_n()` | `design` is not a `survey_base` or `survey_collection` | ERROR | `surveycore_error_not_survey_object` | `"x" = "{.arg design} must be a survey design object.", "i" = "Got {.cls {class(design)[[1L]]}}."`  |
| EN-2 | `get_effective_n()` | `method = "deff"` and `x = NULL` | ERROR | `surveycore_error_effective_n_deff_requires_x` | `"x" = "{.arg x} is required when {.arg method} = {.val \"deff\"}.", "i" = "Supply a numeric variable name, or switch to {.code method = \"kish\"} which needs no variable."` |
| EN-3 | `get_effective_n()` | `x` resolves to more than one column | ERROR | `surveycore_error_effective_n_x_multi_col` | `"x" = "{.arg x} must select exactly one variable, not {length(selected)}.", "i" = "Selected: {.field {selected}}.", "v" = "Pass one variable at a time, or loop over variables."` |
| EN-4 | `get_effective_n()` | `method` is not `"kish"` or `"deff"` (after match.arg) | ERROR | (thrown by `match.arg()`; no custom class needed — `match.arg` gives a clear base error) | — |

> ⚠️ GAP: EN-1 reuses `surveycore_error_not_survey_object`. Verify this class
> is already in `plans/error-messages.md` and that the message template here
> matches what `.check_unsupported_class()` already throws. If the existing
> message diverges, either reuse the existing class with its existing message
> or add a new row. Do not have two classes for the same condition.

---

## IV. Testing

### File mapping

`R/analysis-effective-n.R` → `tests/testthat/test-effective-n.R`

### Test sections

```
# 1. Kish — happy paths
#    a. survey_taylor, no grouping (verify formula: (sum(w))^2 / sum(w^2))
#    b. survey_taylor, with grouping (one row per group level)
#    c. survey_replicate, no grouping
#    d. survey_twophase, no grouping
#    e. survey_nonprob, no grouping
#    f. SRS design (uniform weights → n_eff == n, deff == 1.0)

# 2. DEFF — happy paths
#    a. survey_taylor, no grouping
#    b. survey_taylor, with grouping
#    c. survey_replicate, no grouping
#    d. survey_twophase, no grouping
#    e. survey_nonprob, no grouping
#    f. survey_collection, no grouping
#    g. Numerical check: deff column from get_effective_n() matches deff
#       column from get_means() with variance = "deff" [tolerance 1e-10]
#    (Parametrized: all five design types return finite deff for method = "deff")

# 3. Error paths (one block per error class)
#    Each block uses the dual pattern: expect_error(class=) +
#    expect_snapshot(error=TRUE). See testing-standards.md §3.
#    EN-1: non-survey object input
#    EN-2: method = "deff", x = NULL
#    EN-3: method = "deff", x resolves to 2+ columns

# 4. Edge cases
#    a. n == 0 domain after na.rm → n_eff = NA, deff = NA
#    b. deff == 0 (degenerate, method = "deff") → n_eff = NA
#       deff < 0 (unstable, method = "deff") → n_eff = NA
#    c. uniform weights (kish) → n_eff == n exactly, deff_kish == 1.0
#    d. method = "kish", x supplied → rlang::inform() fires, result unaffected
#    e. decimals applied to n_eff and deff but not n
#    f. na.rm = FALSE for Kish: NA weight → n_eff = NA, deff_kish = NA;
#       NA group value treated as a distinct group level per .apply_domain()
#       semantics

# 5. survey_collection dispatch
#    a. method = "kish": each survey's effective N is computed independently
#    b. method = "deff": collection dispatches with .if_missing_var = "skip"

# 6. Result class and structure
#    a. inherits c("survey_effective_n", "survey_result", "tbl_df", "tbl", "data.frame")
#    b. meta(result)$method is "kish" or "deff"
#    c. meta(result)$x is NULL for kish, variable meta for deff
#    d. print output snapshot (both methods, with and without grouping)
```

### Numerical validation

Two numerical validation blocks, each guarded by `skip_if_not_installed("survey")`:

```r
test_that("get_effective_n() kish matches manual Kish formula [numerical]", {
  skip_if_not_installed("survey")
  d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtmec2yr,
                 strata = sdmvstra, nest = TRUE)
  result <- get_effective_n(d)
  w <- weights(d)
  expected_n_eff <- sum(w)^2 / sum(w^2)
  expect_equal(result$n_eff, expected_n_eff, tolerance = 1e-10)
})

test_that("get_effective_n() deff matches survey::svymean(deff=TRUE) [numerical]", {
  skip_if_not_installed("survey")
  d_sc <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtmec2yr,
                    strata = sdmvstra, nest = TRUE)
  d_sv <- survey::svydesign(
    ids = ~sdmvpsu, weights = ~wtmec2yr, strata = ~sdmvstra,
    data = nhanes_2017, nest = TRUE
  )
  result <- get_effective_n(d_sc, ridageyr, method = "deff")
  sv_est <- survey::svymean(~ridageyr, d_sv, deff = TRUE, na.rm = TRUE)
  expect_equal(result$deff, survey::deff(sv_est)[["ridageyr"]], tolerance = 1e-10)
})
```

---

## V. Quality Gates

"Done" means all of the following are objectively true:

- [ ] `get_effective_n()` is exported and documented (`man/get_effective_n.Rd`
  exists and is current)
- [ ] Both `method = "kish"` and `method = "deff"` produce correct output
  for `survey_taylor`, `survey_replicate`, `survey_twophase`, `survey_nonprob`
- [ ] Grouping produces one row per group combination
- [ ] `survey_collection` dispatch works for both methods
- [ ] All four error classes in §III fire with the correct `class=`
- [ ] Numerical validation: Kish matches manual formula (tolerance 1e-10);
  DEFF matches `get_means(variance = "deff")` (tolerance 1e-10); DEFF matches
  `survey::svymean(deff=TRUE)` (tolerance 1e-10)
- [ ] `print.survey_effective_n` produces correct header (method and x shown)
- [ ] `plans/error-messages.md` updated with rows EN-1 through EN-3
- [ ] `devtools::check()` passes with 0 errors, 0 warnings, ≤2 notes
- [ ] Line coverage on `R/analysis-effective-n.R` ≥ 98%

---

## VI. Integration

`get_effective_n()` is a standalone diagnostic function. It has no contracts
with `surveytidy`, `surveyglm`, or any other package beyond the standard
`survey_result` inheritance that all `get_*()` outputs carry.

The `method = "deff"` path internally delegates to the mean estimation
pipeline. This is an implementation detail and is not part of the public
contract — callers should not depend on it.
