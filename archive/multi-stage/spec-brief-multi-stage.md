# Multi-Stage Sampling — Spec Brief

**Purpose:** This document is the input brief for `/spec-workflow` Stage 1. It describes
the problem, required behaviors, open design decisions, and scope of the multi-stage
sampling feature so the spec author can produce a complete formal specification.

---

## Problem Statement

surveycore accepts `ids = c(psu, ssu)` in `as_survey()` and stores `@variables$ids` as
a character vector (e.g., `c("psu", "ssu")`). However, every variance computation
silently discards all ID columns after the first:

```r
# R/variance-taylor.R:203 — only ever reads stage 1
raw_ids <- data[[vars$ids[[1L]]]]
clusters_mat <- matrix(psu_id, ncol = 1L)   # always single-column
```

The recursive multi-stage kernel (`.svy_multistage()`) is already implemented but is
dead code — the builders never pass multi-column matrices to it. The `# nocov` markers
on lines 141–157 of `variance-taylor.R` document this intentionally deferred state.

**Impact:** A user who specifies `ids = c(psu, ssu)` receives variance estimates computed
as a single-stage cluster design (PSU-only), with no warning that their SSU level was
dropped. This is a silent correctness bug.

---

## Scope of This Feature

### What this phase delivers
| Component | Description |
|-----------|-------------|
| Multi-stage variance for `survey_taylor` | Correct Taylor series variance for 2- and 3-stage designs |
| Shared matrix-builder helper | Extracted internal helper replaces duplicated logic in all analysis cell estimators |
| Explicit unsupported-case warning | `cli_warn()` when user passes 3+ stages without per-stage FPC (see Open Decisions) |
| Oracle tests | Numerical comparison against `survey::svydesign(id = ~psu + ssu)` |

### What this phase does NOT deliver
- Multi-stage support for `survey_replicate` (replicate designs are inherently agnostic to sampling stage; not needed)
- Multi-stage support for `survey_twophase` (Phase 2 design already uses `ids2` separately; unaffected)
- Per-stage FPC (see Open Decisions — may be deferred)
- Changes to `as_survey()` API (already correct)
- Changes to S7 class definitions or `@variables` structure (already correct)

### Prerequisites
- Phase 0 complete (all S7 classes, constructors, variance infrastructure)
- Phase 1 complete (all 6 analysis functions: `get_means`, `get_freqs`, `get_totals`, `get_corr`, `get_quantiles`, `get_ratios`)
- Phase 2 complete (GLM regression via `survey_glm_fit` / `survey_glm()`)

---

## Current Architecture (What Will Change)

### The duplicate matrix-building pattern (the core problem)
The following matrix-building block is **copy-pasted in 7 places**:

```r
# Pattern that appears in all 7 locations:
psu_id <- if (!is.null(vars$ids)) {
  raw_ids <- data[[vars$ids[[1L]]]]          # BUG: only ever reads stage 1
  if (isTRUE(vars$nest) && !is.null(vars$strata)) {
    as.integer(interaction(strata_id, raw_ids, drop = TRUE))
  } else {
    raw_ids
  }
} else {
  seq_len(nrow(data))
}
clusters_mat <- matrix(psu_id, ncol = 1L)   # BUG: always single-column
strata_mat   <- matrix(strata_id, ncol = 1L)
# ... sampsize_mat, popsize_mat similarly
```

**Locations:**
1. `R/variance-taylor.R` — `.taylor_build_inputs()` (lines 187–265)
2. `R/analysis-means-helpers.R` — `.taylor_mean_cell()` (lines ~49–138)
3. `R/analysis-freqs-helpers.R` — `.taylor_freq_cell()` (lines ~61–146)
4. `R/analysis-totals-helpers.R` — `.taylor_totals_cell()`
5. `R/analysis-corr-helpers.R` — `.taylor_corr_cell()`
6. `R/analysis-quantiles-helpers.R` — `.taylor_quantiles_cell()`
7. `R/analysis-ratios-helpers.R` — `.taylor_ratios_cell()`

**And also:**
8. `R/variance-taylor.R` — `.vcov_pair_taylor()` (lines ~397–413)

### The kernel (already correct, just unreachable)
`R/variance-taylor.R:127–161` — `.svy_multistage()`:
```r
# This recursive path exists but is never reached:
# nocov start — Phase 0 builder always passes single-column cluster/strata matrices
if (!isTRUE(one.stage) && !is.null(popmat) && NCOL(clusters) > 1L) {
  v.sub <- by(seq_len(n), list(as.numeric(clusters[, 1L])), function(index) {
    .svy_multistage(
      x[index, , drop = FALSE],
      clusters[index, -1L, drop = FALSE],
      stratas[index,  -1L, drop = FALSE],
      nPSUs[index,    -1L, drop = FALSE],
      popmat[index,   -1L, drop = FALSE],
      lonely.psu = lonely.psu,
      one.stage  = one.stage - 1L,
      stage      = stage + 1L
    ) * nPSUs[index[[1L]], 1L] / popmat[index[[1L]], 1L]
  })
  for (i in seq_along(v.sub)) v <- v + v.sub[[i]]
}
# nocov end
```

---

## Required Behaviors

### 1. Correct 2-stage variance
When `@variables$ids = c("psu", "ssu")`:
- Stage 1 variance: between-PSU variability (same as current single-stage)
- Stage 2 variance: within-PSU, between-SSU variability — **currently missing**
- Both stages are combined using the `survey` package's standard formula
- Must match `survey::svydesign(id = ~psu + ssu, ...)` output within tolerance 1e-8 (SE)

### 2. Correct 3-stage variance
When `@variables$ids = c("psu", "ssu", "unit")`:
- Same recursive logic extends to 3 levels
- Must match `survey` package output for 3-stage designs

### 3. Single-stage unchanged
When `@variables$ids = c("psu")` (current behavior):
- Results must be numerically identical to current output (no regression)
- Oracle tests verify this

### 4. Strata + nest semantics preserved
- `nest = TRUE` interaction logic (currently at stage 1 only) must apply to stage 1 clusters
- Stage 2+ clusters are **not** affected by `nest` — they are always nested within their
  stage-1 PSU by design

### 5. FPC behavior (see Open Decisions for full policy)
- Current single FPC column (`@variables$fpc`) applies to **stage 1** only
- Stage 2 variance uses no FPC (assumes infinite sub-population within each PSU) unless
  per-stage FPC is implemented

### 6. Warning for unsupported FPC configurations
If user passes `ids = c(psu, ssu)` with a `fpc` column, the spec must clarify whether:
- The FPC applies to stage 1 only (with a warning that stage 2 uses no FPC), OR
- Per-stage FPC is required before multi-stage FPC is possible (see Open Decisions)

---

## Required API Changes

### New shared internal helper
Extract duplicated matrix-building logic into one place:

```r
# Proposed signature (spec author should finalize):
.build_cluster_matrices <- function(data, vars, keep = NULL) {
  # Returns list(clusters_mat, strata_mat, sampsize_mat, popsize_mat, y_adj, w_adj)
  # na.rm filtering applied when keep is provided
}
```

**All 7+ call sites** replace their inline matrix-building with a call to this helper.

### No changes to public API
- `as_survey()` signature: no change
- `@variables` structure: no change — `ids` is already a character vector
- Analysis function signatures: no change

---

## Open Design Decisions (Spec Author Must Resolve)

### Decision 1: FPC at stage 2+
**Background:** The `survey` package supports per-stage FPC via multiple formula terms:
`svydesign(id = ~psu + ssu, fpc = ~fpc1 + fpc2)`. surveycore stores only one `fpc`
column in `@variables$fpc`.

**Options:**
- A) Stage 1 FPC only — the single `fpc` column applies to stage 1. Stage 2 and deeper
  are treated as sampling from an infinite population. Issue a `cli_inform()` so the
  user knows. This is correct practice when PSU populations are large (the common case).
- B) Defer multi-stage FPC entirely — if user passes `fpc` with multi-stage `ids`,
  issue a `cli_warn()` that FPC is only applied at stage 1 and stage 2 FPC is not
  yet supported.
- C) Extend `@variables` to support `fpc = c("fpc1", "fpc2")` (vector of column names).
  **Out of scope for this phase** — would require `as_survey()` API changes.

**Recommendation:** Option A — single FPC column applies to stage 1 only, with a clear
`cli_inform()`. This matches the most common real-world practice (NHANES, NHIS, etc.).

### Decision 2: Strata at stage 2
**Background:** `survey::svydesign()` supports `strata = ~strata1 + strata2` for
per-stage stratification. surveycore stores one `strata` column.

**Options:**
- A) Stage 1 strata only — current behavior, unchanged. Stage 2 clustering is unstratified.
- B) Extend `@variables$strata` to support a vector. **Out of scope for this phase.**

**Recommendation:** Option A. Per-stage stratification is rare and can be a separate feature.

### Decision 3: Warning threshold
**Should surveycore warn when multi-stage ids are detected (pre-fix) or remain silent?**

Until the full implementation is shipped, a `cli_warn()` in `as_survey()` when
`length(ids_vars) > 1` would prevent silent wrong answers. The spec should decide:
- Add the warning now in a separate small PR before the full multi-stage PR, OR
- The full multi-stage implementation ships together; no intermediate warning needed

---

## Testing Requirements

### Oracle tests (required)
All oracle tests use `skip_if_not_installed("survey")`.

```r
# Example: 2-stage design
df <- make_survey_data(n = 500, n_psu = 50, seed = 42)  # add ssu column to generator
# OR use NHANES-like data with both psu + ssu variables

sc_design <- as_survey(df, ids = c(psu, ssu), weights = wt, strata = strata)
sv_design <- survey::svydesign(id = ~psu + ssu, weights = ~wt, strata = ~strata, data = df)

# Mean
sc_est <- get_means(sc_design, y1)
sv_est <- survey::svymean(~y1, sv_design, na.rm = TRUE)
expect_equal(sc_est$mean, coef(sv_est)[["y1"]], tolerance = 1e-10)
expect_equal(sc_est$se,   SE(sv_est)[["y1"]],   tolerance = 1e-8)
```

### Regression tests (required)
- Single-stage designs must produce **identical** output before and after the refactor
- All existing `test-variance-taylor.R` tests must pass with no numerical change

### Edge case tests (required)
- 3-stage design
- 2-stage with `nest = TRUE` at stage 1
- 2-stage with FPC at stage 1 only
- Single PSU at stage 2 (lonely SSU) — verify lonely.psu behavior
- NA values in outcome variable (na.rm path)
- Domain estimation (filter applied) with 2-stage design

### Test data
The synthetic data generator (`make_survey_data()` in `tests/testthat/helper-test-data.R`)
needs a parameter to generate SSU-level clustering. The spec should define the extension
or specify using a separate inline data constructor for multi-stage tests.

---

## Files to Modify

| File | Change |
|------|--------|
| `R/utils.R` or new `R/variance-helpers.R` | Add `.build_cluster_matrices()` shared helper |
| `R/variance-taylor.R` | Update `.taylor_build_inputs()` to call new helper; remove `# nocov` from `.svy_multistage()` |
| `R/analysis-means-helpers.R` | Replace inline matrix-building with `.build_cluster_matrices()` |
| `R/analysis-freqs-helpers.R` | Same |
| `R/analysis-totals-helpers.R` | Same |
| `R/analysis-corr-helpers.R` | Same |
| `R/analysis-quantiles-helpers.R` | Same |
| `R/analysis-ratios-helpers.R` | Same |
| `R/variance-taylor.R` (`.vcov_pair_taylor()`) | Same |
| `tests/testthat/test-variance-taylor.R` | Add multi-stage oracle and edge case tests |
| `tests/testthat/helper-test-data.R` | Extend `make_survey_data()` for SSU-level data |

---

## Suggested Spec ID

`multi-stage` — files would be:
- `plans/spec-multi-stage.md` (the spec, output of Stage 1)
- `plans/spec-methods-review-multi-stage.md` (Stage 2 methodology review)
- `plans/decisions-multi-stage.md` (Stage 4 decisions log)
