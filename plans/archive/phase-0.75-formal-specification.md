# surveycore Phase 0.75 — Two-Phase Variance Engine: Formal Specification

**Version:** 1.0
**Date:** February 2026
**Status:** Draft — pending implementation review
**Branch:** `feature/variance-twophase`

---

## Decisions Summary

| Question | Decision |
|----------|----------|
| File organization | Extend into new `R/06-variance-twophase.R`; also split `R/06-variance-estimation.R` into engine-specific files (Q1, Q19) |
| Vendoring approach | Faithful port following existing attribution pattern (Q2) |
| Statistical formula precision | Full mathematical notation for all three methods (Q3) |
| method="full" + no phase2 info | Error at estimation time: `surveycore_error_full_requires_phase2`; Warning 25 (`surveycore_warning_full_no_phase2`) removed from constructor (Q4) |
| Test data | Synthetic `make_survey_data(design = "twophase")` for unit/edge tests; `survival::pbc` and `survival::nwtco` for oracle blocks (Q5) |
| Internal return contract | `list(mean/total, var, se)` — matches existing engines (Q6) |
| NA in subset column | Tighten constructor to error (not warn); remove Warning 23b (Q7, Q18) |
| PR structure | Single PR (Q8) |
| New error classes | `surveycore_error_subset_na`, `surveycore_error_full_requires_phase2` (Q9) |
| `make_survey_data()` | Extend with `design = "twophase"` branch (Q10) |
| Degrees of freedom | Phase 1 df for all three methods (Q11) |
| `survey.lonely.psu` | Respected for both phase 1 and phase 2 variance components (Q12) |
| Method resolution | Always from `@variables$method`; no override at estimation time (Q13) |
| Roxygen updates | Update `get_means()` and `get_totals()` to document `survey_twophase` support (Q14) |
| Phase 1 scope | All Phase 1 functions use the general engine; linearization per-estimand in Phase 1 PRs (Q15, Q16) |
| Quantile variance | Deferred to Phase 1's `get_quantiles()` PR (Q17) |
| Linearization helpers | Live in `R/06-variance-twophase.R` alongside the engine (Q19) |
| `update_design()` | Not modified; users reconstruct with `as_survey_twophase()` to change method (Q20) |
| Two-phase generator | Simple structure: SRS phase 2 within phase 1 (Q21) |
| Oracle test structure | One block per dataset per estimand (Q22) |
| Lonely PSU scope | Phase 1 and phase 2 components both respect the option (Q23) |
| Phase 0.75 scope statement | General engine + all functions except quantiles (Q24) |
| Error class for NA subset | `surveycore_error_subset_na` (single class, constructor only) (Q25) |
| Proportion linearization | Not specified here; deferred to Phase 1 `get_freqs()` PR (Q26) |
| VENDORED.md attribution | Function-level entries (Q27) |

---

## Section I — Scope

### 1.1 What Phase 0.75 Delivers

1. **File structure cleanup** — Split `R/06-variance-estimation.R` into five purpose-specific files
   with corresponding test files.

2. **Two-phase variance engine** — `.twophasevar(influence, design)` in `R/06-variance-twophase.R`,
   vendored from `survey:::twophasevar` and helpers. Supports all three methods: `"full"`,
   `"approx"`, `"simple"`.

3. **Two-phase input builder** — `.twophase_build_inputs(design, y_col, na.rm)` and the
   estimand-specific adapters `.twophase_mean()` and `.twophase_total()`.

4. **Constructor tightening** — `as_survey_twophase()` now **errors** (not warns) when the
   `subset` column contains NA values. Warning 23b (`surveycore_warning_subset_na`) is removed
   from the codebase and from `plans/error-messages.md`.

5. **Updated public dispatch** — `get_means()` and `get_totals()` dispatch on `survey_twophase`.
   `.validate_estimation_input()` no longer rejects `survey_twophase`.

6. **Updated roxygen** — `get_means()` and `get_totals()` document `survey_twophase` support
   with a new `@section Variance estimation` entry for the two-phase methods.

7. **Extended test generator** — `make_survey_data(design = "twophase", seed = N)` in
   `tests/testthat/helper-test-data.R` generates a valid two-phase dataset.

8. **Oracle tests** — Numerical validation against `survey::` using `survival::pbc` and
   `survival::nwtco` (genuine two-phase designs).

9. **VENDORED.md** updated with function-level attribution for all two-phase engine functions.

10. **`plans/error-messages.md`** updated: Warning 23b removed; new error classes added.

### 1.2 What Phase 0.75 Does NOT Deliver

- The Phase 1 analysis functions (`get_freqs()`, `get_corr()`, `get_quantiles()`,
  `get_ratios()`) — those are Phase 1.
- Estimand-specific linearized influence functions beyond means and totals — each Phase 1 PR
  provides its own.
- Two-phase quantile variance (Woodruff's method for two-phase) — deferred to Phase 1's
  `get_quantiles()` PR, which specifies and implements it alongside the function itself.
- `survey_calibrated` two-phase variance — deferred to Phase 2.5.
- Changes to `update_design()` — users change `method` by reconstructing with
  `as_survey_twophase(..., method = "approx")`.

### 1.3 Relationship to Phase 1

Phase 0.75 provides the variance engine and defines the interface contract. Each Phase 1 PR
provides the estimand-specific linearized influence function for one analysis function and
calls `.twophasevar(influence, design)` to obtain the variance. Phase 1's `get_quantiles()`
PR additionally vendors the Woodruff two-phase extension.

---

## Section II — File Structure

### 2.1 Current State (Before Phase 0.75)

`R/06-variance-estimation.R` is a single file containing four variance engines and public
dispatch (~740 lines):

- Section 1: Vendored Taylor linearization helpers
- Section 2: `.taylor_build_inputs()`
- Section 3a: `.taylor_mean()`, `.taylor_total()`
- Section 3b: `.svy_rep_var()`, `.replicate_estimate()`, `.replicate_mean()`, `.replicate_total()`
- Section 3b (mislabeled): `.srs_mean()`, `.srs_total()`
- Section 4: `.validate_estimation_input()`, `get_means()`, `get_totals()`

Corresponding test file: `tests/testthat/test-variance-estimation.R`

### 2.2 After Phase 0.75 — Source Files

| File | Contents | Status |
|------|----------|--------|
| `R/06-variance-taylor.R` | `.svy_onestrat()`, `.svy_onestage()`, `.svy_multistage()`, `.svy_recvar()`, `.taylor_build_inputs()`, `.taylor_mean()`, `.taylor_total()` | Extracted from `06-variance-estimation.R` |
| `R/06-variance-replicate.R` | `.svy_rep_var()`, `.replicate_estimate()`, `.replicate_mean()`, `.replicate_total()` | Extracted from `06-variance-estimation.R` |
| `R/06-variance-srs.R` | `.srs_mean()`, `.srs_total()` | Extracted from `06-variance-estimation.R` |
| `R/06-variance-twophase.R` | `.twophase_build_inputs()`, `.twophasevar()`, `.twophase_phase1_var()`, `.twophase_phase2_var()`, `.compute_phase2_probs()`, `.twophase_mean()`, `.twophase_total()` | **New in Phase 0.75** |
| `R/06-variance-dispatch.R` | `.validate_estimation_input()`, `get_means()`, `get_totals()` | Extracted from `06-variance-estimation.R`; updated with two-phase dispatch |

`R/06-variance-estimation.R` is deleted in this PR.

### 2.3 After Phase 0.75 — Test Files

| Test File | Covers | Status |
|-----------|--------|--------|
| `tests/testthat/test-variance-taylor.R` | Taylor engine unit tests + NHANES oracle | Renamed/refactored from `test-variance-estimation.R` |
| `tests/testthat/test-variance-replicate.R` | Replicate engine unit tests + ACS PUMS oracle | Extracted from `test-variance-estimation.R` |
| `tests/testthat/test-variance-srs.R` | SRS engine unit tests + synthetic oracle | Extracted from `test-variance-estimation.R` |
| `tests/testthat/test-variance-twophase.R` | Two-phase engine unit tests + `pbc`/`nwtco` oracle | **New in Phase 0.75** |
| `tests/testthat/test-variance-dispatch.R` | `.validate_estimation_input()`, `get_means()`, `get_totals()` public API | Extracted from `test-variance-estimation.R` |

### 2.4 File Structure Rationale

At ~740 lines before Phase 0.75, `R/06-variance-estimation.R` already mixes four conceptually
distinct engines plus public dispatch. Adding two-phase would push it past 1,000 lines. Splitting
now, while the file is being touched anyway:

- Gives each vendored engine its own GPL attribution header (clear ownership)
- Makes Phase 1 file additions clean — analysis functions land in `R/09–14-analysis-*.R`
  without competing for space in a monolithic variance file
- Matches the "one file, one responsibility" principle already applied to classes, constructors,
  print methods, and conversion

The split happens in the same PR as the two-phase addition, since the file is already open.

---

## Section III — Constructor Change: Subset NA Handling

### 3.1 Current Behavior (Warning 23b)

`as_survey_twophase()` fires `surveycore_warning_subset_na` when the `subset` column contains
`NA` values and creates the design object. The object exists but cannot be used for estimation
(the estimation stub currently rejects `survey_twophase` entirely).

### 3.2 New Behavior

`as_survey_twophase()` throws `surveycore_error_subset_na` immediately when the `subset` column
contains any `NA` values. The design object is NOT created.

This matches `survey` package behavior: `survey::twophase()` calls
`stop("missing values in 'subset'")` at construction time.

### 3.3 Error Class and Message

```r
cli::cli_abort(
  c(
    "x" = "{.arg subset} column {.field {subset_var}} contains {n_na} NA value(s).",
    "i" = "The phase 2 membership indicator must be fully observed for all phase 1 units.",
    "v" = "Remove rows with missing {.arg subset} values before calling {.fn as_survey_twophase}."
  ),
  class = "surveycore_error_subset_na"
)
```

where `n_na <- sum(is.na(subset_col))` is computed once and stored before the `cli_abort()` call.

### 3.4 Affected Files

| File | Change |
|------|--------|
| `R/03-constructors.R` | Replace `cli_warn(..., class = "surveycore_warning_subset_na")` + object creation with `cli_abort(..., class = "surveycore_error_subset_na")`. Also remove `cli_warn(..., class = "surveycore_warning_full_no_phase2")` — estimation-time `surveycore_error_full_requires_phase2` is the sole check for this condition. |
| `tests/testthat/test-constructors.R` | Convert all `expect_warning(class = "surveycore_warning_subset_na")` blocks to `expect_error(class = "surveycore_error_subset_na")` + `expect_snapshot(error = TRUE, ...)`. Delete the `expect_warning(class = "surveycore_warning_full_no_phase2")` test block. |
| `tests/testthat/_snaps/constructors.md` | Delete the snapshot entry for the test named `'as_survey_twophase() warns for NA in subset column'` from `tests/testthat/_snaps/constructors.md`. New error snapshots are generated on first test run. |
| `plans/error-messages.md` | Remove row for `surveycore_warning_subset_na` (Warning 23b); remove row for `surveycore_warning_full_no_phase2` (Warning 25); add rows for `surveycore_error_subset_na` and `surveycore_error_full_requires_phase2` |
| `tests/testthat/helper-test-data.R` | In `make_all_designs()`, update the `twophase` creation line: `suppressWarnings(as_survey_twophase(phase1, subset = phase2_ind))` → `as_survey_twophase(phase1, subset = subset, method = "approx")`. Remove `suppressWarnings()` (Warning 25 is eliminated) and update the column reference from `phase2_ind` to `subset`. |

### 3.5 Note on `.validate_estimation_input()`

Because the constructor now errors on NA subset values, by the time any estimation function
receives a `survey_twophase` object, the subset column is guaranteed to be fully observed.
No additional NA check is needed at estimation time. The constructor invariant is sufficient.

---

## Section IV — Architecture: The Two-Phase Variance Engine

### 4.1 Design Principles

The two-phase engine mirrors the structural pattern of the Taylor engine:

```
Taylor engine:
  .svy_recvar()                   ← general variance function
  .taylor_build_inputs()          ← prepares inputs for standard estimands
  .taylor_mean(), .taylor_total() ← estimand adapters

Two-phase engine:
  .twophasevar()                  ← general variance function (NEW)
  .twophase_build_inputs()        ← prepares inputs for standard estimands (NEW)
  .twophase_mean(), .twophase_total() ← estimand adapters (NEW)
```

Phase 1 analysis functions call `.twophasevar()` directly with their own influence vectors.
They do NOT go through `.twophase_build_inputs()`. This keeps the engine general while
the adapters handle the two simplest estimands (mean and total) for Phase 0.75.

### 4.2 `.twophasevar(influence, design)` — The General Engine

**Purpose:** Compute the variance of any linearized statistic for a two-phase design.

**Signature:**
```r
.twophasevar <- function(influence, design, lonely.psu = getOption("survey.lonely.psu", "remove"))
```

**Arguments:**

| Argument | Type | Description |
|----------|------|-------------|
| `influence` | numeric vector, length `nrow(design@data)` | Linearized influence function. For Phase 2 rows (`subset == TRUE`): estimand-specific value. For Phase 1-only rows (`subset == FALSE`): `0`. Must not contain `NA` unless `na.rm = FALSE` — when `na.rm = FALSE` and `y` has NA values, the caller sets influence to `NA` for those rows, which propagates through `.svy_recvar()` to produce `NA` variance (and `NA` SE). This matches `survey` package behavior. |
| `design` | `survey_twophase` | A fully constructed two-phase design. Subset column is guaranteed NA-free by the constructor. |
| `lonely.psu` | character | Option from `getOption("survey.lonely.psu", "remove")`. Applied to both the phase 1 and phase 2 variance components. |

**Returns:** Numeric scalar. The estimated variance of the statistic. Both `.twophase_phase1_var()` and `.twophase_phase2_var()` return scalars (via `[1L, 1L]` extraction from the `.svy_recvar()` matrix return), so `v1 + v2` is scalar-scalar arithmetic.

**Internal structure (pseudocode):**
```r
.twophasevar <- function(influence, design, lonely.psu = getOption("survey.lonely.psu", "remove")) {
  vars   <- design@variables
  method <- vars$method
  subset <- design@data[[vars$subset]]  # logical vector, length = nrow(data)

  # Check: method = "full" requires phase 2 design information
  if (identical(method, "full")) {
    has_phase2_info <- !is.null(vars$phase2$ids) ||
                       !is.null(vars$phase2$strata) ||
                       !is.null(vars$phase2$probs)
    if (!has_phase2_info) {
      cli::cli_abort(
        c(
          "x" = "Two-phase variance method {.val full} requires phase 2 design structure.",
          "i" = "No {.arg ids2}, {.arg strata2}, or {.arg probs2} were specified in {.fn as_survey_twophase}.",
          "v" = 'Reconstruct with {.arg method = "approx"} or supply phase 2 design variables.'
        ),
        class = "surveycore_error_full_requires_phase2"
      )
    }
  }

  # Phase 2 conditional inclusion probabilities (π₂|₁)
  pi2 <- .compute_phase2_probs(design, subset)

  # Phase 1 variance contribution
  v1 <- .twophase_phase1_var(influence, design, pi2, method, lonely.psu)

  if (identical(method, "simple")) {
    return(v1)
  }

  # Phase 2 variance contribution (full and approx only)
  v2 <- .twophase_phase2_var(influence, design, subset, lonely.psu)

  v1 + v2
}
```

**Attribution block (top of `R/06-variance-twophase.R`):**
```r
# ---------------------------------------------------------------------------
# R/06-variance-twophase.R
# ---------------------------------------------------------------------------
# Two-phase sampling variance estimation for survey_twophase designs.
#
# ATTRIBUTION — VENDORED CODE:
# The functions .twophasevar(), .twophase_phase1_var(), .twophase_phase2_var(),
# and .compute_phase2_probs() are adapted from the survey package by Thomas Lumley
# (https://cran.r-project.org/package=survey), licensed under GPL-2 | GPL-3.
# Modifications: integrated with S7 classes; three-method dispatch made
# explicit; RCPP path removed; error messages converted to cli format;
# data access via @variables instead of survey's internal list structure.
# ---------------------------------------------------------------------------
```

### 4.3 `.twophase_phase1_var(influence, design, pi2, method, lonely.psu)`

Computes the phase 1 variance contribution for a given method.

**Adapted from:** `survey:::svyrecvar.phase1`

For each method, the score passed to `.svy_recvar()` (the existing Taylor engine) differs:

| Method | Phase 1 score for row `i` |
|--------|--------------------------|
| `"full"` | `influence[i] / pi2[i]` for `i` in Phase 2; `0` for Phase 1-only |
| `"approx"` | `influence[i] / pi2[i]` for `i` in Phase 2; `0` for Phase 1-only |
| `"simple"` | `influence[i]` for `i` in Phase 2; `0` for Phase 1-only |

In all cases, `.svy_recvar()` is called on the full Phase 1 sample (all rows) using the
Phase 1 design structure stored in `design@variables$phase1`.

**Matrix construction (Phase 1 design matrices):**

`.twophase_phase1_var()` must build the `clusters`, `stratas`, and `fpcs` argument matrices
required by `.svy_recvar()` from `design@variables$phase1`. The logic is analogous to the
matrix-building steps in `.taylor_build_inputs()`, with `na.rm` handling removed (influence
is already precomputed with 0 for Phase 1-only rows):

- `clusters_mat`: one-column integer matrix from `ph1_data[[ph1_vars$ids[[1L]]]]`. If
  `ph1_vars$nest == TRUE` and strata are present, apply
  `as.integer(interaction(strata_col, cluster_col, drop = TRUE))` to make PSU IDs globally
  unique before forming the matrix. If `ph1_vars$ids` is `NULL`, use `seq_len(nrow(ph1_data))`.
- `strata_mat`: one-column matrix from `ph1_data[[ph1_vars$strata]]`. If `ph1_vars$strata`
  is `NULL`, use `rep(1L, nrow(ph1_data))`.
- `fpcs`: a list with `sampsize` and `popsize` matrices built from `ph1_vars$fpc`, following
  the same FPC extraction logic used in `.taylor_build_inputs()`. If `ph1_vars$fpc` is `NULL`,
  pass `NULL` for `fpcs`.

**Returns:** Numeric scalar. `.svy_recvar()` returns a `p×p` matrix; `.twophase_phase1_var()`
extracts `[1L, 1L]` before returning.

**Tech debt note:** The matrix-building logic above duplicates the corresponding steps in
`.taylor_build_inputs()`. This duplication is acknowledged and accepted for Phase 0.75.
A refactor extracting a shared `.build_taylor_matrices()` helper is deferred to Phase 1.

### 4.4 `.twophase_phase2_var(influence, design, subset, lonely.psu)`

Computes the phase 2 variance contribution (used by `"full"` and `"approx"` methods only).

**Adapted from:** the phase 2 component of `survey:::twophasevar`

The phase 2 score for row `i` (where `subset[i] == TRUE`) is:

| Method | Phase 2 score |
|--------|--------------|
| `"full"` | `influence[i] * sqrt(phase1_prob[i])` where `phase1_prob[i] = 1 / w1[i]` |
| `"approx"` | `influence[i] * sqrt(phase1_prob[i])` |

`.svy_recvar()` is called on Phase 2 rows only, using the Phase 2 design structure
(`@variables$phase2$ids`, `@variables$phase2$strata`, `@variables$phase2$fpc`). If phase 2
has no clustering (`@variables$phase2$ids` is `NULL`), each Phase 2 row is its own PSU.

**Phase 2 FPC matrix construction (matching `survey` behavior):**

The `fpcs` argument to `.svy_recvar()` for the Phase 2 component must be a list with
`sampsize` (PSUs in sample per stratum) and `popsize` (population size per stratum)
matrices. If no Phase 2 strata or PSU IDs are specified (`@variables$phase2$ids` is
`NULL` and `@variables$phase2$strata` is `NULL`), pass `fpcs = NULL` (no FPC
correction). Otherwise, build the matrices as follows:

**`sampsize` matrix:** Count the unique Phase 2 PSU IDs per Phase 2 stratum among rows
where `subset == TRUE`. If `@variables$phase2$ids` is `NULL`, each Phase 2 row is its
own PSU; `sampsize[s]` equals the number of Phase 2 rows in stratum `s`. If
`@variables$phase2$strata` is `NULL`, all Phase 2 rows are in one implicit stratum and
`sampsize` is a 1×1 matrix. Result: one-column integer matrix with one row per stratum.

**`popsize` matrix:**

- **If `@variables$phase2$fpc` is specified:** use those column values directly as the
  Phase 2 population PSU count per stratum, forming a one-column integer matrix in the
  same stratum order as `sampsize`. The FPC correction factor applied by `.svy_recvar()`
  is `(N − n) / N` in each stratum.
- **If `@variables$phase2$fpc` is NULL:** auto-compute `popsize` by counting unique
  Phase 2 PSU IDs per stratum across **all Phase 1 units** (not just Phase 2 rows).
  This mirrors `survey:::twophase2()` which calls
  `ave(!duplicated(cluster), stratum, FUN = sum)` over the full Phase 1 data frame
  and uses those counts as the Phase 2 population sizes.

This means: unlike `π₂|₁` (which is estimated from sampling fractions in Section 4.5),
the Phase 2 FPC correction uses **PSU counts**, not rates. The two quantities are
distinct and serve different roles in the formula.

**Returns:** Numeric scalar. `.svy_recvar()` returns a `p×p` matrix; `.twophase_phase2_var()`
extracts `[1L, 1L]` before returning.

### 4.5 `.compute_phase2_probs(design, subset)`

Derives conditional Phase 2 inclusion probabilities (π₂|₁,ᵢ) for all phase 2 rows.

**Adapted from:** internal probability computation in `survey:::twophase()`

Priority order:
1. If `@variables$phase2$probs` is specified: use those column values directly.
2. If `@variables$phase2$strata` is specified but no explicit probs: compute within-stratum
   sampling fraction as `n₂_stratum / n₁_stratum` (treating phase 2 as SRS within strata).
3. If neither probs nor strata are specified: compute overall sampling fraction
   `n₂ / n₁` (treating phase 2 as unstratified SRS within phase 1).

Returns a numeric vector of length `nrow(design@data)`, with `1` for Phase 1-only rows
(they are not subsampled; π₂|₁ = 1 is a placeholder that cancels in the formula).

### 4.6 `.twophase_build_inputs(design, y_col, na.rm)`

**Purpose:** Extract and prepare all inputs for the standard mean and total estimands.
Not intended for Phase 1 analysis functions; they compute their own influence vectors.

**Returns:** A named list:
```r
list(
  y           = numeric,  # response, Phase 2 rows only, after na.rm
  w           = numeric,  # survey weights, Phase 2 rows only, after na.rm
  influence_mean  = numeric,  # length nrow(design@data); 0 for Phase 1-only rows
  influence_total = numeric,  # length nrow(design@data); 0 for Phase 1-only rows
  ybar_w      = numeric,  # weighted mean (scalar)
  total_w     = numeric,  # weighted total (scalar)
  n_phase2    = integer   # number of Phase 2 observations (after na.rm)
)
```

**NA handling:**
- If `na.rm = TRUE`: rows where `y` is `NA` are excluded from Phase 2 before computing
  the weighted mean/total and influence vectors. Their influence values are set to `0`.
- If `na.rm = FALSE`: NA values in `y` propagate to `ybar_w` and `total_w` (both `NA`).
  The influence values for those rows are also `NA`. These `NA` influence values then
  propagate through `.svy_recvar()` to produce `NA` variance and `NA` SE. No error or
  warning is raised — silent NA propagation matches `survey` package behavior
  (`survey::svymean()` with `na.rm = FALSE` returns `NA` for both `coef` and `SE`).

### 4.7 `.twophase_mean(design, y_col, na.rm)` and `.twophase_total(design, y_col, na.rm)`

Thin adapters over `.twophasevar()`. Compute the appropriate influence function and delegate.

**Return contract (matching `.taylor_mean()` and `.replicate_mean()`):**
```r
list(mean  = numeric_scalar,   # weighted mean estimate
     var   = numeric_scalar,   # variance estimate
     se    = numeric_scalar)   # standard error = sqrt(var)

list(total = numeric_scalar,   # weighted total estimate
     var   = numeric_scalar,
     se    = numeric_scalar)
```

---

## Section V — Statistical Formulas

### 5.1 Notation

| Symbol | Meaning |
|--------|---------|
| S₁ | Phase 1 sample (n₁ observations) |
| S₂ | Phase 2 sample (n₂ observations, S₂ ⊆ S₁) |
| N | Phase 1 population size (may be ∞) |
| πᵢ | Phase 1 inclusion probability for unit i |
| π₂\|₁,ᵢ | Conditional Phase 2 probability given Phase 1 selection |
| wᵢ = 1/πᵢ | Phase 1 survey weight |
| eᵢ | Linearized influence function for unit i |
| gᵢ | Phase-1-level score: `eᵢ / π₂\|₁,ᵢ` for i ∈ S₂; `0` for i ∈ S₁ \ S₂ |
| V_P1(·) | Variance computed using Phase 1 design (via `.svy_recvar()`) |
| V_P2(·) | Variance computed using Phase 2 design (via `.svy_recvar()` on S₂ only) |

### 5.2 Linearized Influence Functions for Standard Estimands

**Mean:** θ̂ = ȳ_w = Σᵢ∈S₂(wᵢ yᵢ) / Σᵢ∈S₂(wᵢ)

For i ∈ S₂:
```
eᵢ = wᵢ × (yᵢ − ȳ_w) / N̂    where N̂ = Σᵢ∈S₂(wᵢ)
```
For i ∈ S₁ \ S₂: `eᵢ = 0`

**Total:** T̂ = Σᵢ∈S₂(wᵢ yᵢ)

For i ∈ S₂:
```
eᵢ = wᵢ × yᵢ
```
For i ∈ S₁ \ S₂: `eᵢ = 0`

### 5.3 Full Method

Applies joint Phase 1 + Phase 2 linearization. Requires explicit Phase 2 design
information (`ids2`, `strata2`, or `probs2`). Errors if none are specified.

```
V_full(θ̂) = V_P1(gᵢ) + V_P2(eᵢ × √(πᵢ))
```

where:
- V_P1(gᵢ) is computed by `.svy_recvar()` using the Phase 1 cluster/strata/FPC structure
  applied to all n₁ Phase 1 units, with score gᵢ = eᵢ / π₂|₁,ᵢ (or 0 for Phase 1-only units)
- V_P2(eᵢ × √(πᵢ)) is computed by `.svy_recvar()` using the Phase 2 cluster/strata/FPC
  structure applied to the n₂ Phase 2 units only, with score eᵢ × √(1/wᵢ)

**Valid when:** Phase 2 design structure is fully specified.
**Most accurate of the three methods.**

### 5.4 Approx Method

Approximates the Phase 1 contribution using marginal Phase 2 probabilities. Does not require
the full joint design information; uses the simpler within-stratum sampling fraction as π₂|₁,ᵢ.

```
V_approx(θ̂) = V_P1(eᵢ / π₂|₁,ᵢ) + V_P2(eᵢ × √(πᵢ))
```

Computationally identical to `"full"` but with π₂|₁,ᵢ derived from sampling fractions
(Section 4.5 priority rules) rather than explicit design variables. The Phase 2 component
uses the same formula.

**Valid when:** Phase 2 sampling is close to SRS within Phase 1 strata. Accurate for most
two-phase designs where Phase 2 does not subsample within Phase 1 PSUs.

### 5.5 Simple Method

Uses only the Phase 1 variance component. Ignores the Phase 2 contribution entirely.

```
V_simple(θ̂) = V_P1(eᵢ)
```

Note: for the `"simple"` method, the Phase 1 score is just `eᵢ` (not `eᵢ / π₂|₁,ᵢ`),
so no Phase 2 probability information is needed.

**Valid when:**
- Phase 2 is a census of Phase 1 (n₂ = n₁; correction term is 0)
- Phase 2 sampling fraction is very high (Phase 2 contribution negligible)
- Phase 1 variance dominates (valid conservative approximation)

**Warning at construction:** `surveycore_warning_simple_clustered` (Warning 24) is fired by
`as_survey_twophase()` when `method = "simple"` is used with a clustered Phase 1 design.
Estimation proceeds without re-warning.

### 5.6 Degrees of Freedom

All three methods use Phase 1 degrees of freedom for confidence interval computation:

```
df = Σₛ nₛ − S
```

where:
- nₛ = number of distinct PSUs in Phase 1 stratum s
- S = number of distinct strata in the Phase 1 design

**Unstratified Phase 1 design:** `df = n_PSU − 1` where `n_PSU` is the number of distinct
Phase 1 primary sampling units.

**No Phase 1 clustering:** `df = n₁ − 1` where each row is its own PSU.

This is the same formula applied to `survey_taylor` designs and is consistent with the
`survey` package's treatment of two-phase designs. The `df` value is returned in the
internal engine output and consumed by Phase 1 analysis functions for CI computation.
`.twophase_df()` returns an `integer` (via `as.integer()` cast — `tapply` + `sum`
returns numeric, so the cast is explicit).

**Implementation:**
```r
.twophase_df <- function(design) {
  ph1_vars   <- design@variables$phase1
  ph1_data   <- design@data  # all rows are Phase 1

  strata_col <- if (!is.null(ph1_vars$strata)) ph1_data[[ph1_vars$strata]] else rep(1L, nrow(ph1_data))
  psu_col    <- if (!is.null(ph1_vars$ids))    ph1_data[[ph1_vars$ids[[1L]]]] else seq_len(nrow(ph1_data))

  if (isTRUE(ph1_vars$nest) && !is.null(ph1_vars$strata)) {
    psu_col <- as.integer(interaction(strata_col, psu_col, drop = TRUE))
  }

  psu_per_stratum <- tapply(psu_col, strata_col, function(p) length(unique(p)))
  as.integer(sum(psu_per_stratum) - length(psu_per_stratum))
}
```

### 5.7 Lonely PSU Handling

`getOption("survey.lonely.psu", "remove")` is read **once** at the start of `.twophasevar()`
and passed to **both** `.twophase_phase1_var()` and `.twophase_phase2_var()`. Consistent
behavior is enforced regardless of which phase contains a lonely PSU.

---

## Section VI — Public Dispatch Updates

### 6.1 `.validate_estimation_input()` Changes

The current block that rejects `survey_twophase`:

```r
# REMOVE THIS BLOCK IN PHASE 0.75:
if (S7::S7_inherits(design, survey_twophase)) {
  cli::cli_abort(
    c(
      "x" = "Two-phase designs are not yet supported in estimation functions.",
      "i" = "Support for {.cls survey_twophase} will be added in Phase 1."
    ),
    class = "surveycore_error_unsupported_class"
  )
}
```

Is deleted. No replacement check is needed: `survey_twophase` is now a supported class,
and the NA-in-subset invariant is guaranteed by the constructor.

The remaining validation (design is a `survey_base` subclass; variable exists; variable is
numeric) applies unchanged to `survey_twophase` inputs.

### 6.2 `get_means()` Dispatch — Updated

```r
get_means <- function(design, var, na.rm = TRUE) {
  var_name <- rlang::as_name(rlang::ensym(var))
  .validate_estimation_input(design, var_name)

  result <- if (S7::S7_inherits(design, survey_replicate)) {
    .replicate_mean(design, var_name, na.rm = na.rm)
  } else if (S7::S7_inherits(design, survey_srs)) {
    .srs_mean(design, var_name, na.rm = na.rm)
  } else if (S7::S7_inherits(design, survey_twophase)) {     # NEW
    .twophase_mean(design, var_name, na.rm = na.rm)          # NEW
  } else {
    .taylor_mean(design, var_name, na.rm = na.rm)
  }
  list(variable = var_name, mean = result$mean, se = result$se)
}
```

The `survey_twophase` branch must precede the `survey_taylor` fallthrough: `survey_twophase`
does not inherit from `survey_taylor`, but confirming this ordering makes the dispatch
chain unambiguous.

### 6.3 `get_totals()` Dispatch — Updated

Identical pattern to `get_means()` above, using `.twophase_total()`.

### 6.4 Roxygen Updates

Both `get_means()` and `get_totals()` require updates in two places:

**`@param design` — remove the "not yet supported" sentence:**
```r
#' @param design A survey design object. Supported classes: [survey_taylor]
#'   (created by [as_survey()]), [survey_replicate] (created by
#'   [as_survey_rep()]), [survey_srs] (created by [as_survey_srs()] or
#'   [as_survey()]), [survey_twophase] (created by [as_survey_twophase()]),
#'   and [survey_calibrated] (created by [as_survey_calibrated()]).
```

**`@section Variance estimation by design type:` — add `survey_twophase` entry:**
```r
#'   \item{`survey_twophase`}{Two-phase linearization (Saei and Roberts 1999;
#'     Lumley 2010 §9.2). Three methods are supported, set at construction
#'     time via [as_survey_twophase()]:
#'     \itemize{
#'       \item `"full"` — joint phase 1 + phase 2 linearization. Most
#'         accurate. Requires `ids2`, `strata2`, or `probs2` to be specified
#'         in [as_survey_twophase()].
#'       \item `"approx"` — phase 1 variance with phase 2 correction, using
#'         within-stratum sampling fractions as phase 2 probabilities. Valid
#'         for most two-phase designs.
#'       \item `"simple"` — phase 1 variance only. Conservative; valid when
#'         phase 2 sampling fraction is high or phase 1 variance dominates.
#'     }
#'   }
```

---

## Section VII — Phase 1 Integration Contract

### 7.1 Engine Interface for Phase 1 Analysis Functions

Phase 1 analysis functions call `.twophasevar()` directly. Each function is responsible
for computing the estimand-specific linearized influence vector.

**Interface:**
```r
variance <- .twophasevar(influence = my_influence_vec, design = design)
se       <- sqrt(variance)
df       <- .twophase_df(design)
```

**Influence vector requirements:**
- Type: numeric vector
- Length: `nrow(design@data)` (all Phase 1 rows, including Phase 2 rows)
- Phase 2 rows (`design@data[[design@variables$subset]] == TRUE`): estimand-specific value
- Phase 1-only rows (`... == FALSE`): exactly `0` (not `NA`)

### 7.2 Per-Estimand Linearized Influence Functions

The table below documents the influence function for each Phase 1 estimand. The entries
for means and totals are implemented in Phase 0.75 (`.twophase_mean()`, `.twophase_total()`).
Entries for other estimands are the responsibility of their respective Phase 1 PRs.

| Estimand | Influence function eᵢ (for i ∈ S₂) | Phase |
|----------|--------------------------------------|-------|
| Mean | `wᵢ × (yᵢ − ȳ_w) / N̂` where `N̂ = Σwᵢ` | 0.75 |
| Total | `wᵢ × yᵢ` | 0.75 |
| Proportion (level k) | `wᵢ × (𝟙(yᵢ = k) − p̂ₖ) / N̂` | Phase 1 `get_freqs()` PR |
| Ratio Y/Z | Delta method: `(yᵢ − r̂ zᵢ) × wᵢ / T̂_Z` | Phase 1 `get_ratios()` PR |
| Correlation | Bivariate delta method | Phase 1 `get_corr()` PR |
| Quantile | Woodruff indicator linearization (two-phase extension) | Phase 1 `get_quantiles()` PR |

### 7.3 Two-Phase Quantile Support (Deferred to Phase 1)

`get_quantiles()` with `survey_twophase` requires Woodruff's method adapted for two-phase
designs. This is a separate algorithmic path (not a simple influence vector substitution)
and is specified and implemented in Phase 1's `get_quantiles()` PR alongside the function
itself.

Until that PR merges, `get_quantiles()` throws `surveycore_error_unsupported_class` for
`survey_twophase` inputs with a message explicitly naming `get_means()` and `get_totals()`
as the currently supported functions.

---

## Section VIII — Error and Warning Classes

### 8.1 Removed

| Class | Row in error-messages.md | Replaced by |
|-------|--------------------------|-------------|
| `surveycore_warning_subset_na` | Warning 23b | `surveycore_error_subset_na` |
| `surveycore_warning_full_no_phase2` | Warning 25 | `surveycore_error_full_requires_phase2` (fires at estimation time) |

### 8.2 New Error Classes

| Class | Function | Condition |
|-------|----------|-----------|
| `surveycore_error_subset_na` | `as_survey_twophase()` | `subset` column contains any `NA` values |
| `surveycore_error_full_requires_phase2` | `.twophasevar()` (called via `.twophase_mean()` / `.twophase_total()`) | `method = "full"` but `@variables$phase2` has no `ids`, `strata`, or `probs` specified |

### 8.3 Message Templates

**`surveycore_error_subset_na`:**
```r
cli::cli_abort(
  c(
    "x" = "{.arg subset} column {.field {subset_var}} contains {n_na} NA value(s).",
    "i" = "The phase 2 membership indicator must be fully observed for all phase 1 units.",
    "v" = "Remove rows with missing {.arg subset} values before calling {.fn as_survey_twophase}."
  ),
  class = "surveycore_error_subset_na"
)
```

**`surveycore_error_full_requires_phase2`:**
```r
cli::cli_abort(
  c(
    "x" = "Two-phase variance method {.val full} requires phase 2 design structure.",
    "i" = "No {.arg ids2}, {.arg strata2}, or {.arg probs2} were specified in {.fn as_survey_twophase}.",
    "v" = 'Reconstruct with {.arg method = "approx"} or supply phase 2 design variables.'
  ),
  class = "surveycore_error_full_requires_phase2"
)
```

### 8.4 `plans/error-messages.md` Updates

- **Remove** row for `surveycore_warning_subset_na` (Warning 23b)
- **Remove** row for `surveycore_warning_full_no_phase2` (Warning 25) — estimation-time error is the sole check for this condition
- **Add** row for `surveycore_error_subset_na` (construction-time, `as_survey_twophase()`)
- **Add** row for `surveycore_error_full_requires_phase2` (estimation-time, `.twophasevar()`)

---

## Section IX — Test Strategy

### 9.1 File Mapping

| New source file | Test file | Notes |
|-----------------|-----------|-------|
| `R/06-variance-taylor.R` | `tests/testthat/test-variance-taylor.R` | Refactored from `test-variance-estimation.R` |
| `R/06-variance-replicate.R` | `tests/testthat/test-variance-replicate.R` | Extracted from `test-variance-estimation.R` |
| `R/06-variance-srs.R` | `tests/testthat/test-variance-srs.R` | Extracted from `test-variance-estimation.R` |
| `R/06-variance-twophase.R` | `tests/testthat/test-variance-twophase.R` | **New in Phase 0.75** |
| `R/06-variance-dispatch.R` | `tests/testthat/test-variance-dispatch.R` | Extracted from `test-variance-estimation.R` |

### 9.1a `test-variance-dispatch.R` — New Blocks for Phase 0.75

The existing `test-variance-dispatch.R` tests cover `.validate_estimation_input()`,
`get_means()`, and `get_totals()` for Taylor, replicate, and SRS inputs. Two new blocks
are required to verify the `survey_twophase` dispatch path added in Section 6.2–6.3:

```r
test_that("get_means() dispatches to .twophase_mean() for survey_twophase input", {
  df  <- make_survey_data(design = "twophase", seed = 1)
  ph1 <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
  d   <- as_survey_twophase(ph1, subset = subset, method = "approx")
  result <- get_means(d, y1)
  expect_true(is.list(result))
  expect_named(result, c("variable", "mean", "se"))
  expect_true(is.numeric(result$mean))
  expect_true(is.numeric(result$se) && result$se >= 0)
})

test_that("get_totals() dispatches to .twophase_total() for survey_twophase input", {
  df  <- make_survey_data(design = "twophase", seed = 1)
  ph1 <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
  d   <- as_survey_twophase(ph1, subset = subset, method = "approx")
  result <- get_totals(d, y1)
  expect_true(is.list(result))
  expect_named(result, c("variable", "total", "se"))
  expect_true(is.numeric(result$total))
  expect_true(is.numeric(result$se) && result$se >= 0)
})
```

These blocks do not require `skip_if_not_installed()` — they use synthetic data and
verify the dispatch path in isolation (no numerical comparison against an oracle).

### 9.2 `make_survey_data(design = "twophase")` Extension

**Generator contract:**

```r
make_survey_data(
  n           = 500,
  n_psu       = 50,
  n_strata    = 5,
  design      = "twophase",    # NEW branch
  phase2_frac = 0.4,           # fraction of Phase 1 selected into Phase 2
  with_labels = FALSE,
  seed        = 42
)
```

**Phase 2 structure:** Bernoulli sampling at rate `phase2_frac` — each row independently
has a `phase2_frac` probability of Phase 2 selection (`runif(n) < phase2_frac`), applied
uniformly without within-stratum stratification. This is simpler than exact stratified
SRS; the difference does not affect oracle test accuracy because oracle tests use real
datasets (`pbc`, `nwtco`), not the synthetic generator.

**Full column schema:**

| Column | Type | Description |
|--------|------|-------------|
| `psu` | integer | PSU identifier (same as Taylor variant) |
| `strata` | integer | Stratum identifier (same as Taylor variant) |
| `fpc` | integer | Population size per stratum (same as Taylor variant) |
| `wt` | numeric | Phase 1 survey weight (same as Taylor variant) |
| `y1` | numeric | Response variable 1 (same as Taylor variant) |
| `y2` | numeric | Response variable 2 (same as Taylor variant) |
| `y3` | numeric | Response variable 3 (same as Taylor variant) |
| `subset` | logical | Phase 2 membership indicator. `TRUE` = selected into Phase 2. No NAs. |
| `phase1_prob` | numeric | Phase 1 inclusion probability (`= n_psu_stratum / pop_stratum`). Range: `(0, 1]`. |
| `phase2_prob` | numeric | Conditional Phase 2 inclusion probability (`= phase2_frac`). Range: `(0, 1]`. |

The two-phase generator produces all columns from the Taylor variant plus the three Phase 2
columns. The `wt` column in Phase 1 is derived from `1 / phase1_prob`.

**Usage pattern:**
```r
df  <- make_survey_data(design = "twophase", seed = 42)
ph1 <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
d   <- as_survey_twophase(ph1, subset = subset, method = "approx")
test_invariants(d)
```

### 9.2b `test_invariants()` and `survey_twophase`

`test_invariants()` in `tests/testthat/helper-test-data.R` **already handles
`survey_twophase`** — no changes are required in Phase 0.75. The existing implementation
dispatches on `S7::S7_inherits(design, survey_twophase)` and checks:

- All named Phase 1 and Phase 2 design columns (`phase1$ids`, `phase1$weights`,
  `phase1$strata`, `phase1$fpc`, `phase2$ids`, `phase2$strata`, `phase2$probs`,
  `phase2$fpc`, `subset`) exist in `@data` and are atomic
- Phase 1 weight column is numeric and strictly positive
- `subset` column is logical (no NAs — guaranteed by the constructor)
- `@metadata` is a `survey_metadata` object; all labelled vars are present in `@data`

**Testing convention for Phase 0.75:**

- **Constructor test blocks** in `test-constructors.R` that create a `survey_twophase`
  object must call `test_invariants(d)` as their first assertion (same rule as all other
  constructor tests).
- **Oracle test blocks** in `test-variance-twophase.R` do **not** call
  `test_invariants()` — following the established pattern in the existing Taylor engine
  oracle tests (which also omit `test_invariants()`). Oracle tests are numerical
  validation tests, not constructor correctness tests.

### 9.3 `test-variance-twophase.R` — Section Structure

```r
# ── Section 1: Engine unit tests (synthetic data) ────────────────────────────

test_that(".twophasevar() returns a finite non-negative scalar for valid input (approx)", { })
test_that(".twophasevar() phase 1 variance component is nonzero for clustered phase 1", { })
test_that(".twophasevar() full variance > phase 1 variance alone (phase 2 adds uncertainty)", { })
test_that('.twophasevar() with method = "simple" equals phase 1 component only', { })
test_that(".twophase_mean() returns list with mean, var, se of correct types", { })
test_that(".twophase_total() returns list with total, var, se of correct types", { })
test_that(".twophase_df() returns a nonnegative integer (class integer)", { })
test_that(".twophase_df() returns correct df for nest = TRUE Phase 1 design", {
  # PSU IDs 1–5 reused within each stratum; nest = TRUE makes them globally unique.
  # 2 strata × 5 PSUs each = 10 distinct PSUs; df = 10 - 2 = 8.
  df_nest <- data.frame(
    psu    = c(rep(1:5, each = 2), rep(1:5, each = 2)),
    strata = c(rep(1L, 10), rep(2L, 10)),
    weight = rep(1, 20),
    y1     = rnorm(20),
    subset = rep(c(TRUE, FALSE), 10)
  )
  ph1 <- as_survey(df_nest, ids = psu, weights = weight, strata = strata, nest = TRUE)
  d   <- as_survey_twophase(ph1, subset = subset, method = "approx")
  expect_equal(.twophase_df(d), 8L)
})

# ── Section 2: Error paths ────────────────────────────────────────────────────

test_that('.twophase_mean() errors for method = "full" with no phase 2 design info', {
  # expect_error(class = "surveycore_error_full_requires_phase2")
  # expect_snapshot(error = TRUE, ...)
})

# ── Section 3: Oracle — survival::pbc ────────────────────────────────────────

test_that('two-phase mean (full method) matches survey::svymean on pbc [oracle]', {
  skip_if_not_installed("survival")
  skip_if_not_installed("survey")
  # ... (see Section 9.4 for construction)
  # expect_equal(sc_est$mean, sv_mean, tolerance = 1e-10)
  # expect_equal(sc_est$se,   sv_se,   tolerance = 1e-8)
})
test_that('two-phase mean (approx method) matches survey::svymean on pbc [oracle]', { })
test_that('two-phase total (full method) matches survey::svytotal on pbc [oracle]', { })
test_that('two-phase total (approx method) matches survey::svytotal on pbc [oracle]', { })

# ── Section 4: Oracle — survival::nwtco ──────────────────────────────────────

test_that('two-phase mean (full method) matches survey::svymean on nwtco [oracle]', {
  skip_if_not_installed("survival")
  skip_if_not_installed("survey")
})
test_that('two-phase mean (approx method) matches survey::svymean on nwtco [oracle]', { })
test_that('two-phase total (full method) matches survey::svytotal on nwtco [oracle]', { })
test_that('two-phase total (approx method) matches survey::svytotal on nwtco [oracle]', { })

# ── Section 5: Edge cases ─────────────────────────────────────────────────────

test_that('.twophase_mean() returns NA estimate when all Phase 2 y values are NA and na.rm = TRUE', { })
test_that('.twophase_mean() propagates NA when na.rm = FALSE and y has NA', { })
test_that('.twophase_mean() returns NA se when Phase 2 has only one observation', { })
test_that('.twophase_mean() works when all rows are Phase 2 (phase2_frac = 1)', { })
```

### 9.4 Oracle Test Construction: `survival::pbc`

The `pbc` dataset from the `survival` package is a natural two-phase design:
- **Phase 1:** All 312 randomized patients (`!is.na(trt)`)
- **Phase 2:** The subset with serum cholesterol measured (`!is.na(chol)`, a subset of Phase 1)

```r
data("pbc", package = "survival")
pbc_ph1 <- subset(pbc, !is.na(trt))      # Phase 1: n = 312 randomized patients
pbc_ph1$in_ph2 <- !is.na(pbc_ph1$chol)  # Phase 2 indicator (no NAs in ph1 data)

# surveycore:
# pbc has equal-probability sampling within the trial — use SRS-equivalent weights
pbc_ph1$wt <- 1
ph1_sc <- as_survey(pbc_ph1, weights = wt)
d_sc   <- as_survey_twophase(ph1_sc, subset = in_ph2, method = "full")

# survey oracle:
d_sv <- survey::twophase(
  id     = list(~1, ~1),
  data   = pbc_ph1,
  subset = ~in_ph2
)

sc_est <- get_means(d_sc, chol)
sv_est <- survey::svymean(~chol, d_sv, na.rm = TRUE)

expect_equal(sc_est$mean, coef(sv_est)[["chol"]], tolerance = 1e-10)
expect_equal(sc_est$se,   SE(sv_est)[["chol"]],   tolerance = 1e-8)
```

The `approx` oracle uses the same data with `method = "approx"` in `as_survey_twophase()`
and `method = "approx"` in `survey::twophase()`.

### 9.5 Oracle Test Construction: `survival::nwtco`

The `nwtco` dataset is a case-cohort design (all cases + random sample of controls):
- **Phase 1:** All 4,028 children in the study
- **Phase 2:** All 571 cases (relapse = 1) + random subcohort of ~620 controls

```r
data("nwtco", package = "survival")
nwtco$in_ph2 <- nwtco$rel == 1 | nwtco$in.subcohort == 1

# surveycore (ids = seqno in Phase 1; Phase 2 stratified by rel):
nwtco$wt <- 1
ph1_sc <- as_survey(nwtco, ids = seqno, weights = wt)
d_sc   <- as_survey_twophase(ph1_sc, strata2 = rel, subset = in_ph2, method = "full")

# survey oracle (structurally identical design):
d_sv <- survey::twophase(
  id     = list(~seqno, ~seqno),
  strata = list(NULL, ~rel),
  data   = nwtco,
  subset = ~in_ph2
)

sc_est <- get_means(d_sc, edrel)
sv_est <- survey::svymean(~edrel, d_sv, na.rm = TRUE)

expect_equal(sc_est$mean, coef(sv_est)[["edrel"]], tolerance = 1e-10)
expect_equal(sc_est$se,   SE(sv_est)[["edrel"]],   tolerance = 1e-8)
```

**Note:** `nwtco` has stratified Phase 2 sampling (cases vs. controls). Both the surveycore
and survey oracle designs use `seqno` as Phase 1 PSU and `rel` as Phase 2 strata.
The `"approx"` oracle uses the same design construction but with `method = "approx"` in
both `as_survey_twophase()` and `survey::twophase()`. With `strata2 = rel` specified,
`.compute_phase2_probs()` uses Section 4.5 rule 2 (within-stratum sampling fractions),
which matches survey's `"approx"` calculation.

### 9.6 Updated Constructor Tests

All Warning 23b test blocks in `tests/testthat/test-constructors.R` are updated:

```r
# BEFORE (Warning 23b pattern):
test_that("as_survey_twophase() warns for NA in subset column", {
  expect_warning(
    result <- as_survey_twophase(ph1, subset = has_na_col, method = "approx"),
    class = "surveycore_warning_subset_na"
  )
  test_invariants(result)
})

# AFTER (error pattern):
test_that("as_survey_twophase() errors for NA in subset column", {
  expect_error(
    as_survey_twophase(ph1, subset = has_na_col, method = "approx"),
    class = "surveycore_error_subset_na"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_twophase(ph1, subset = has_na_col, method = "approx")
  )
})
```

The snapshot for Warning 23b is deleted from `_snaps/constructors.md`. The error snapshot
is generated on first test run and committed.

### 9.7 Numerical Tolerances

| Estimand | Tolerance |
|----------|-----------|
| Point estimates (mean, total) | `1e-10` |
| SE / variance | `1e-8` |

These are the established surveycore tolerances from Phase 0 and Phase 1. Two-phase
oracle tests use identical thresholds.

---

## Section X — VENDORED.md Updates

New entries to add to the existing `VENDORED.md` table, following established format:

| surveycore function | Adapted from | survey version | Modified? | Modification notes |
|--------------------|-------------|----------------|-----------|-------------------|
| `.twophasevar()` | `survey:::twophasevar` | 4.4.x | Yes | S7 data access via `@variables`; three-method dispatch made explicit; `attr(rval, "phases")` output removed; cli error format |
| `.twophase_phase1_var()` | `survey:::svyrecvar.phase1` | 4.4.x | Yes | S7 class integration; RCPP path removed; delegates to existing `.svy_recvar()` |
| `.twophase_phase2_var()` | Phase 2 component of `survey:::twophasevar` | 4.4.x | Yes | Extracted as standalone function; delegates to existing `.svy_recvar()` |
| `.compute_phase2_probs()` | Internal probability logic in `survey/R/twophase.R` | 4.4.x | Yes | Simplified three-priority rule; S7 `@variables$phase2` data access |

---

## Section XI — Quality Gates

Phase 0.75 is complete when **all** of the following pass:

**R CMD check:**
- [ ] `devtools::check()` passes: 0 errors, 0 warnings, ≤ 2 pre-approved notes

**File structure refactor:**
- [ ] `R/06-variance-estimation.R` is deleted; its contents live in five new files
- [ ] All tests previously in `test-variance-estimation.R` pass in their new files
  (`test-variance-taylor.R`, `test-variance-replicate.R`, `test-variance-srs.R`,
  `test-variance-dispatch.R`)
- [ ] No remaining references to `06-variance-estimation.R` in `NAMESPACE`, roxygen,
  or test files

**Constructor tightening:**
- [ ] `as_survey_twophase()` throws `surveycore_error_subset_na` (not a warning) for
  NA-containing subset columns
- [ ] All Warning 23b tests in `test-constructors.R` have been converted to error tests
  with `expect_error(class = "surveycore_error_subset_na")` + `expect_snapshot(error = TRUE)`
- [ ] No remaining reference to `surveycore_warning_subset_na` anywhere in the codebase
- [ ] Warning 25 (`surveycore_warning_full_no_phase2`) removed from `as_survey_twophase()`; no remaining reference to `surveycore_warning_full_no_phase2` anywhere in the codebase

**Two-phase engine:**
- [ ] `get_means()` and `get_totals()` dispatch to `.twophase_mean()` / `.twophase_total()`
  for `survey_twophase` inputs — verified by `test-variance-dispatch.R`
- [ ] `.twophasevar()` with `method = "full"` + no Phase 2 design info throws
  `surveycore_error_full_requires_phase2` — tested with `expect_error(class=)` +
  `expect_snapshot(error = TRUE)`
- [ ] All three methods (`"full"`, `"approx"`, `"simple"`) return finite, non-negative
  variance estimates for valid synthetic inputs

**Oracle tests:**
- [ ] `pbc` oracle: `get_means()` (full + approx) and `get_totals()` (full + approx) all
  pass at tolerance `1e-10` (point) and `1e-8` (SE)
- [ ] `nwtco` oracle: same four combinations pass at same tolerances

**Documentation:**
- [ ] `get_means()` and `get_totals()` roxygen no longer say two-phase is unsupported
- [ ] `@section Variance estimation` includes `survey_twophase` entry with all three methods
- [ ] `plans/error-messages.md` updated: Warning 23b removed; two new error rows added
- [ ] `VENDORED.md` updated: four new function-level attribution entries

**Test generator:**
- [ ] `make_survey_data(design = "twophase", seed = N)` produces a valid data frame
  usable with `as_survey_twophase()` (no NAs in `subset` column; `phase1_prob` and
  `phase2_prob` in range (0, 1])

**Coverage:**
- [ ] `R/06-variance-twophase.R` line coverage ≥ 98%
- [ ] Total package line coverage ≥ 98%
- [ ] No new `# nocov` annotations except for genuinely unreachable defensive branches,
  each with an explanatory comment

**Phase 1 readiness:**
- [ ] Architecture review confirms Phase 1's `get_freqs()` PR can call
  `.twophasevar(influence, design)` with a proportion influence vector and obtain a
  numerically correct variance (informal check — no running Phase 1 code required)

---

## References

- Lumley, T. (2010). *Complex Surveys: A Guide to Analysis Using R*. Wiley. §9.2.
- Saei, A., & Roberts, G. (1999). Design-based methods for two-phase sampling.
  *Survey Methodology*, 25(2), 161–176.
- Lumley, T. (2004). Analysis of complex survey samples. *Journal of Statistical Software*,
  9(1), 1–19.
- `survival` package: Therneau, T. M. & Grambsch, P. M. (2000). *Modeling Survival Data.*
  Springer.
