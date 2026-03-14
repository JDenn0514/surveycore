# Multi-Stage Sampling — Formal Specification

**Spec ID:** `multi-stage`
**Version:** 0.3 (approved)
**Date:** 2026-03-12
**Status:** Approved — ready for `/implementation-workflow`

---

## Document Purpose

This document is the authoritative specification for multi-stage sampling
support in surveycore. It governs all implementation decisions for the
`feature/multi-stage` branch. Any behavior not specified here defaults to the
rules in `code-style.md`, `r-package-conventions.md`, and
`testing-surveycore.md`.

---

## I. Scope

### What this phase delivers

| Component | Description |
|-----------|-------------|
| `.build_cluster_matrices()` shared helper | New internal helper in `R/utils.R` that replaces the duplicated matrix-building pattern across 5 direct call sites (`.taylor_build_inputs()`, `.vcov_pair_taylor()`, `.taylor_mean_cell()`, `.taylor_freq_cell()`, `.taylor_totals_cell()`) |
| Multi-stage variance for `survey_taylor` | Correct Taylor series variance for 2- and 3-stage designs |
| Per-stage FPC support | `fpc = c(fpc1, fpc2)` in `as_survey()` stores a character vector; each stage gets its own FPC column |
| Partial FPC warning | `cli_inform()` when user supplies fewer FPC columns than ID stages |
| `# nocov` removal | Remove `# nocov start / end` markers from `.svy_multistage()` once the builder correctly populates multi-column matrices |
| Oracle tests | Numerical comparison against `survey::svydesign(id = ~psu + ssu)` |
| `make_survey_data()` extension | Add `n_ssu` parameter to generate SSU-level clustering for tests |

### What this phase does NOT deliver

- Multi-stage support for `survey_replicate` (replicate designs are inherently stage-agnostic; the variance kernel does not use cluster matrices at all)
- Multi-stage support for `survey_twophase` (Phase 2 design already uses `ids2` separately; unaffected)
- Per-stage stratification — `@variables$strata` remains a single column; stage 2+ uses the parent cluster as implicit stratum
- Changes to `as_survey_replicate()`, `as_survey_srs()`, or `as_survey_twophase()` — `fpc` in those constructors remains single-column

### Design support matrix

| Design class | Single-stage | 2-stage | 3-stage |
|---|---|---|---|
| `survey_taylor` | ✅ (existing) | ✅ (this phase) | ✅ (this phase) |
| `survey_replicate` | ✅ (existing) | n/a | n/a |
| `survey_srs` | ✅ (existing) | n/a | n/a |
| `survey_twophase` | ✅ (existing) | n/a | n/a |

### Prerequisites

- Phase 0 complete (S7 classes, constructors, variance infrastructure)
- Phase 1 complete (all 6 analysis functions)
- Phase 2 complete or concurrently in-flight (GLM regression shares the
  `.build_cluster_matrices()` helper; `R/glm.R` must be updated in this phase
  to replace the inline FPC access — see §VIII.5)

---

## II. Architecture — File Changes

```
R/utils.R                           Add .build_cluster_matrices() helper
R/core-constructors.R               Change fpc resolution in as_survey()
                                    to multi-col tidy-select; add new validations
R/variance-taylor.R                 Update .taylor_build_inputs() and
                                    .vcov_pair_taylor() to use helper;
                                    remove # nocov from .svy_multistage()
R/analysis-means-helpers.R         Replace inline matrix building with helper
R/analysis-freqs-helpers.R          Same
R/analysis-totals-helpers.R         Same
                                    Note: analysis-corr-helpers.R,
                                    analysis-quantiles-helpers.R, and
                                    analysis-ratios-helpers.R have NO inline
                                    matrix-building block — they delegate to
                                    .vcov_pair_taylor(), .mean_cell(), and
                                    .total_cell() respectively and gain
                                    multi-stage support transitively
R/methods-print.R                   Update print.survey_taylor FPC bullet to
                                    show per-stage column names when
                                    length(fpc_var) > 1
R/variance-srs.R                    Replace inline FPC/matrix blocks in
                                    .vcov_pair_srs() (two call sites) with
                                    .build_cluster_matrices(); add regression oracle
R/glm.R                             Replace inline `data[[vars$fpc]]` with
                                    `.build_cluster_matrices()` (line ~262);
                                    add oracle tests for multi-stage GLM
tests/testthat/helper-test-data.R   Extend make_survey_data() with n_ssu parameter
tests/testthat/test-variance-taylor.R  Add multi-stage oracle + edge case tests
tests/testthat/test-glm.R           Add multi-stage GLM oracle tests
tests/testthat/test-methods-print.R Add snapshot test for per-stage FPC display
plans/error-messages.md             Add new warning and error rows
```

---

## III. `@variables$fpc` Schema Change

### Current storage (single-stage only)

`@variables$fpc` is either `NULL` (no FPC) or a single column name `"fpc_col"`
(character scalar, i.e. `character(1)`).

### New storage (multi-stage capable)

`@variables$fpc` is either `NULL` (no FPC) or a **character vector** of column
names, one per stage where FPC is provided. Length 1 = single FPC column
(backward compatible with all existing behavior); length k = k FPC columns.

```r
# Single-stage FPC (existing behavior, stored identically)
@variables$fpc = "fpc1"               # character(1) — same as before

# Two-stage FPC (new)
@variables$fpc = c("fpc1", "fpc2")    # character(2)
```

### Backward compatibility

All existing code that checks `!is.null(vars$fpc)` continues to work without
change. Code that reads `data[[vars$fpc]]` is replaced in this phase by
`.build_cluster_matrices()`, which handles both the single-column and
multi-column cases internally.

`@variables$fpc_type` is **not** stored by `as_survey()` — the population-size
vs. sampling-fraction distinction is detected at variance computation time
(per column, independently). This is the existing behavior; the spec does not
change it.

---

## IV. `as_survey()` Changes: Multi-Column FPC Resolution

### New fpc resolution logic

Replace the current `.resolve_single_col()` call for `fpc` with
`tidyselect::eval_select()` (the same pattern already used for `ids`):

```r
# Current (single-column enforced):
fpc_var <- .resolve_single_col(fpc_quo, data, "fpc", ...)

# New (multi-column allowed):
fpc_vars <- if (rlang::quo_is_null(fpc_quo)) {
  NULL
} else {
  fpc_cols <- tidyselect::eval_select(fpc_quo, data)
  if (length(fpc_cols) == 0L) {
    cli::cli_abort(
      c("x" = "{.arg fpc} matched no columns in {.arg data}."),
      class = "surveycore_error_fpc_not_found"
    )
  }
  names(fpc_cols)
}
```

### FPC validation per column

Each FPC column is validated independently (same rules as the current
single-column validation):

1. No `NA` values — error `surveycore_error_fpc_na`
2. All values > 0 — error `surveycore_error_fpc_nonpositive`
3. No column mixes values > 1 and values ≤ 1 — error `surveycore_error_fpc_mixed_type`
4. No population-size column has values smaller than the stage-j cluster count
   within each parent group — error `surveycore_error_fpc_smaller_than_n`.
   Formally: `data[[fpc_col_j]] >= sampsize_j_vec` must hold for every row,
   where `sampsize_j_vec` is the per-row count of sampled stage-j clusters
   within each stage-(j-1) parent (from §V Step 5). Using `nrow(data)` as "n"
   is **incorrect** for stage-j > 1 columns
5. FPC columns supplied as sampling fractions (values ≤ 1) must be constant
   within each stage-j parent group — error `surveycore_error_fpc_not_constant`.
   FPC is interpreted as a **cluster-level** sampling fraction (sampled clusters ÷
   population clusters in the parent), not a record-level fraction.

   **Intentional divergence from `survey`:** The `survey` package does not
   enforce this constraint — it accepts non-constant FPC fractions within a
   cluster and silently uses the per-row values. surveycore enforces constancy
   because a varying fraction within a cluster indicates malformed data (the
   fraction is a property of the sampling design at that stage, not of
   individual records). Designs that `survey` accepts with non-constant fractions
   will be rejected by `as_survey()` with a clear error message.

Each column is validated independently; it is valid for column 1 to use
population sizes and column 2 to use sampling fractions (or vice versa).

**Note:** FPC values of exactly `1.0` are treated as a 100% sampling fraction
(complete enumeration at that stage; no FPC correction applied). A population
size of exactly 1 cannot be represented as an integer FPC column — pass
`fpc = NULL` instead.

6. FPC columns supplied as **population sizes** (values > 1) that vary
   within each stage-j parent group — warning
   `surveycore_warning_fpc_popsize_varies_within_stratum`.
   Checked after the fraction→popsize conversion so it applies
   regardless of which FPC form the user supplied. Matches
   `survey::as.fpc()`, which issues
   `warning("'fpc' varies within strata")` for non-constant popsize
   at any stage. Unlike rule 5 (fraction non-constancy → error),
   this is a **warning only**: there are valid designs where
   population sizes are recorded per-PSU rather than per-stratum.
   The check uses the same parent grouping as rule 5:
   `strata_id` for stage 1, `clusters_mat[, j-1]` for stage j > 1.

### FPC vs. ID stage count validation

After resolving `fpc_vars` and `ids_vars`, validate the column counts:

```
n_id_stages  = if (is.null(ids_vars)) 1L else length(ids_vars)
n_fpc_stages = length(fpc_vars)  # 0 if NULL
```

| Condition | Action |
|-----------|--------|
| `n_fpc_stages == 0` | No FPC; `@variables$fpc = NULL`. No message. |
| `n_fpc_stages == n_id_stages` | Full per-stage FPC. No message. |
| `n_fpc_stages < n_id_stages` | Partial FPC. `cli_warn(class = "surveycore_warning_fpc_partial_stages")` (see §X). |
| `n_fpc_stages > n_id_stages` | Error `surveycore_error_fpc_too_many_stages`. |

### Error 13b removed for `as_survey()`

The existing error `surveycore_error_fpc_multiple` ("`fpc` selects > 1 column")
**no longer applies to `as_survey()`** — multiple FPC columns are now valid.
Error 13b is **retained for `as_survey_replicate()`**, `as_survey_srs()`, and
`as_survey_twophase()`, where `fpc` must remain single-column.

---

## V. `.build_cluster_matrices()` — New Shared Helper

### Location

`R/utils.R` (used in 8+ files; per `code-style.md §4` internal helper placement rule).

### Signature

```r
.build_cluster_matrices <- function(data, vars)
```

### Argument table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `data.frame` | — | The `@data` from the survey design object |
| `vars` | `list` | — | The `@variables` from the survey design object |

### Return value

A named list:

```r
list(
  clusters_mat = <integer matrix, n × k>,   # n = nrow(data); k = n_stages
  strata_mat   = <integer matrix, n × k>,
  fpcs         = list(
    sampsize = <integer matrix, n × k>,
    popsize  = <numeric matrix, n × k> or NULL
  )
)
```

Where `k = max(1L, length(vars$ids))`. For a design with no `ids` (SRS-like),
`k = 1` and every row is its own PSU.

### Algorithm

#### Step 1: Determine number of stages

```r
n <- nrow(data)
k <- max(1L, if (!is.null(vars$ids)) length(vars$ids) else 0L)
```

Using `max(1L, ...)` guards against `vars$ids = character(0)` (empty vector, not
`NULL`), which would otherwise yield `k = 0` and produce 0-column matrices.

#### Step 2: Build stage-1 stratum vector

```r
strata_id <- if (!is.null(vars$strata)) {
  data[[vars$strata]]
} else {
  rep(1L, n)
}
```

#### Step 3: Build clusters matrix (k columns)

**Column 1 — stage-1 PSU IDs (with nest adjustment):**

```r
psu_id <- if (!is.null(vars$ids)) {
  raw_ids <- data[[vars$ids[[1L]]]]
  if (isTRUE(vars$nest) && !is.null(vars$strata)) {
    as.integer(interaction(strata_id, raw_ids, drop = TRUE))
  } else {
    as.integer(interaction(raw_ids, drop = TRUE))
  }
} else {
  seq_len(n)  # each row is its own PSU
}
```

**Rationale for `interaction()` at stage 1:** `interaction(x, drop = TRUE)` on
a single vector is equivalent to `factor(x)` — it converts any atomic type
(character, numeric, factor) to an integer-coded factor. This matches the
`survey` package, which extracts `ids` via `model.frame()`, coercing character
IDs to factor before `as.fpc()` runs. Without this coercion, string IDs like
`"psu_01"` reach `as.numeric(clusters[,1])` in `.svy_multistage()` and produce
`NA`, silently collapsing all rows into one group and producing wrong variances.

**Columns 2..k — sub-unit IDs (globally unique via `interaction()`):**

For each stage `j` in `2:k` (only when `k > 1`):

```r
as.integer(interaction(clusters_mat[, j - 1L], data[[vars$ids[[j]]]], drop = TRUE))
```

This mirrors the `survey` package's pre-processing loop:
```r
for (i in 2:N) ids[, i] <- do.call("interaction", ids[, 1:i, drop = FALSE])
```
Each stage-j ID is interacted with the already-globally-unique stage-(j-1) ID,
making the stage-j IDs globally unique across the entire dataset. Nest
adjustment applies **only to stage 1**; stage 2+ clusters are globally
disambiguated by this interaction.

**Assemble:**

```r
extra_cols   <- if (k > 1L) {
  lapply(seq(2L, k), function(j) {
    as.integer(interaction(clusters_mat[, j - 1L], data[[vars$ids[[j]]]], drop = TRUE))
  })
} else {
  list()
}
clusters_mat <- matrix(
  data = c(psu_id, unlist(extra_cols)),
  nrow = n,
  ncol = k
)
```

**Note:** `2:k` must **not** be used directly — in R, `2:1` evaluates to
`c(2L, 1L)`, not an empty vector. The `if (k > 1L)` guard is mandatory.
All columns of `clusters_mat` are integer by construction; `as.numeric()` on
any column is safe regardless of the original ID type in the data.

#### Step 4: Build strata matrix (k columns)

- Column 1: `strata_id` (from Step 3)
- Column j (j = 2..k): `clusters_mat[, j-1L]` — the parent cluster ID serves
  as the "stratum" within which stage-j units are sampled

```r
extra_strata <- if (k > 1L) {
  lapply(seq(2L, k), function(j) clusters_mat[, j - 1L])
} else {
  list()
}
strata_mat <- matrix(
  data = c(strata_id, unlist(extra_strata)),
  nrow = n,
  ncol = k
)
```

**Rationale:** SSUs within a given PSU are treated as unstratified (they all
belong to the same "stratum" = that PSU). This matches `survey` package
behavior for `svydesign(id = ~psu + ssu, strata = ~stratum)`. This reflects
standard multi-stage sampling theory (Cochran 1977, §10.3; Kish 1965, §6.3):
stage-j units are sampled within their parent cluster, with no cross-cluster
stratification. Each PSU acts as its own implicit stratum for stage-2+
sampling.

#### Step 5: Build sampsize matrix (k columns)

For each stage `j` in `1:k`:
- The "parent" of stage-j units at stage 1 is `strata_mat[, 1L]` (the
  stage-1 stratum).
- The "parent" of stage-j units at stage j > 1 is `clusters_mat[, j-1L]`
  (the parent cluster at stage j-1).

```r
# Stage j parent vector:
parent_j <- if (j == 1L) strata_id else clusters_mat[, j - 1L]
cluster_j <- clusters_mat[, j]

units_per_parent <- tapply(cluster_j, parent_j,
                           function(ids) length(unique(ids)))
sampsize_j_vec   <- as.integer(units_per_parent[as.character(parent_j)])
```

`units_per_parent` is a named integer vector keyed by parent ID (one entry per
unique parent). The indexing `units_per_parent[as.character(parent_j)]`
broadcasts this back to a per-row vector of length `n`: every row is assigned
the count of sampled sub-clusters in its parent. `as.character()` is required
because `tapply` names are character regardless of the input type.

Assemble all k columns into `sampsize_mat`.

#### Step 6: Build popsize matrix (k columns or NULL)

If `vars$fpc` is `NULL`: `popsize_mat = NULL`.

Otherwise, let `n_fpc = length(vars$fpc)`. For each column index `j` in `1:k`:

- If `j <= n_fpc`: read `data[[vars$fpc[[j]]]]`; detect population-size
  vs. fraction (same logic as current code: values > 1 → population size;
  values in (0,1] → convert via `sampsize_j_vec / fpc_vals`).
- If `j > n_fpc`: fill with `Inf` (infinite sub-population at this stage —
  no FPC correction; see partial FPC semantics below).

```r
# Per-column FPC logic:
fpc_col_j <- if (j <= n_fpc) {
  fpc_vals <- data[[vars$fpc[[j]]]]
  if (any(fpc_vals > 1, na.rm = TRUE)) {
    as.numeric(fpc_vals)
  } else {
    as.numeric(sampsize_j_vec / fpc_vals)
  }
} else {
  rep(Inf, n)  # infinite population at this stage
}
```

**Note:** The variance kernel `.svy_onestrat()` already guards `fpc = Inf`
with `ifelse(fpc == Inf, 1, (fpc - nPSU)/fpc)`. This guard must be preserved;
direct arithmetic on `Inf` produces `NaN`.

Assemble into `popsize_mat` (k columns).

**Partial FPC semantics:** When `n_fpc < k` and `n_fpc >= 1`, `popsize_mat`
is non-NULL (the recursion in `.svy_multistage()` fires) but stages j > n_fpc
get `Inf` population size. This means:
- The stage-j FPC factor `f = (fpc - nPSU) / fpc` evaluates to `1.0` (no
  correction) when `fpc = Inf`.
- The within-PSU variance IS computed and included in the total variance
  (scaled by the stage-1 sampling fraction).
- The interpretation: stage-2+ sampling from an infinite sub-population;
  all within-PSU variance is retained without correction.

This matches the behavior of `survey::svydesign(id = ~psu + ssu, fpc = ~fpc1)`
(stage-1 FPC only). Oracle tests must verify this numerical equivalence. The
result is a **conservative** SE: including the full within-PSU variance without
correction inflates SE relative to a design where stage-2 FPC is known. The
`cli_warn()` level (`surveycore_warning_fpc_partial_stages`) matches
`survey::as.fpc()`'s `warning("stages without fpc were treated as with
replacement")`. (Reference: Lumley 2010, §2.2.)

**No FPC (`popmat = NULL`) semantics:** `.svy_multistage()` does not recurse
when `popmat = NULL`. Only stage-1 variance is computed. This is
mathematically correct: multi-stage variance is
`V = V_1 + (1 − f_1) * V_2 + ...`, where each stage-k contribution is scaled
by the product of stage-1 through stage-(k-1) sampling fractions. Without
stage-1 FPC, `f_1` is unknown and all within-PSU contributions are
indeterminate. The recursion does not fire and only `V_1` is returned. This
approximation is accurate when `f_1 ≪ 1` (small stage-1 sampling fraction).
Designs sampling > 20% of PSUs should supply stage-1 FPC. See Lumley (2010)
§2.1. This matches the behavior of `survey::svydesign(fpc = NULL)`.

### Internal consistency assertion

After all matrices are built, verify dimensions are consistent before
returning:

```r
# Assertion (internal):
stopifnot(
  NCOL(clusters_mat)  == k,
  NROW(clusters_mat)  == n,
  NCOL(strata_mat)    == k,
  NROW(strata_mat)    == n,
  NCOL(fpcs$sampsize) == k,
  NROW(fpcs$sampsize) == n,
  is.null(fpcs$popsize) ||
    (NCOL(fpcs$popsize) == k && NROW(fpcs$popsize) == n)
)
```

This guards against dimension mismatches that would produce cryptic errors
inside `.svy_multistage()` rather than at the builder.

---

## VI. `.taylor_build_inputs()` Update

### ⚠ Behavioral change: sampsize now computed from full dataset

**Before this refactor:** `.taylor_build_inputs()` computed PSU sampsize
*after* applying the `na.rm` row filter. PSUs whose contributing rows
were all removed by `na.rm` did not count toward sampsize.

**After this refactor:** `.build_cluster_matrices()` is called with the
full `design@data` before any outcome filtering. Sampsize reflects the
design structure regardless of which outcome rows have NAs.

This matches `survey` package behavior: `svydesign()` computes sampsize
at design-creation time, independent of later outcome filtering.

**Practical consequence for the implementation plan:** Existing oracle
tests in `test-variance-taylor.R` that use `na.rm = TRUE` on NHANES data
may produce numerically different SE values after the refactor. Capture
current oracle values from `develop` via `dput()` before any code is
changed, and record them as the regression test baseline. Add this as an
explicit step in the implementation plan.

Replace the inline matrix-building block (lines 196–254 in
`R/variance-taylor.R`) with a call to `.build_cluster_matrices()`.

### Current pattern (to be removed):

```r
strata_id <- ...
psu_id    <- ...
clusters_mat <- matrix(psu_id, ncol = 1L)
strata_mat   <- matrix(strata_id, ncol = 1L)
# ... sampsize and popsize computation
fpcs <- list(...)
```

### New pattern:

```r
keep_y <- if (na.rm) !is.na(y) else seq_along(y)
mats   <- .build_cluster_matrices(design@data, design@variables)
y      <- y[keep_y]
w      <- data[[vars$weights]][keep_y]
# Subset the pre-built matrices to matching rows for variance computation:
mats$clusters_mat  <- mats$clusters_mat[keep_y, , drop = FALSE]
mats$strata_mat    <- mats$strata_mat[keep_y, , drop = FALSE]
mats$fpcs$sampsize <- mats$fpcs$sampsize[keep_y, , drop = FALSE]
if (!is.null(mats$fpcs$popsize))
  mats$fpcs$popsize <- mats$fpcs$popsize[keep_y, , drop = FALSE]
```

### Return value (unchanged)

```r
list(
  y        = y,          # numeric, filtered or full
  w        = w,          # numeric, filtered or full
  clusters = mats$clusters_mat,
  stratas  = mats$strata_mat,
  fpcs     = mats$fpcs
)
```

---

## VII. Analysis Helper Updates (7 files)

The cluster matrices and FPC structures output by `.build_cluster_matrices()`
are estimand-agnostic: multi-stage variance applies to all non-linear estimands
(ratios, quantiles, correlations) through their existing influence functions
without further modification.

Three of the six analysis helper files contain an identical inline
matrix-building block that must be replaced with `.build_cluster_matrices(data, vars)`:

| File | Function | Change required |
|------|----------|----------------|
| `R/analysis-means-helpers.R` | `.taylor_mean_cell()` | Replace inline block |
| `R/analysis-freqs-helpers.R` | `.taylor_freq_cell()` | Replace inline block |
| `R/analysis-totals-helpers.R` | `.taylor_totals_cell()` | Replace inline block |

The remaining three files (`analysis-corr-helpers.R`, `analysis-quantiles-helpers.R`,
`analysis-ratios-helpers.R`) contain **no inline matrix-building block** — they
delegate to `.vcov_pair_taylor()`, `.mean_cell()`, and `.total_cell()` respectively
and gain multi-stage support automatically once those functions are refactored.
No direct changes to these three files are required.

All cell estimators use the **full dataset** (no row filtering — domain
estimation zeros out non-domain influence).

### Pattern for each cell estimator

Replace:

```r
strata_id <- if (!is.null(vars$strata)) data[[vars$strata]] else rep(1L, n)
psu_id    <- if (!is.null(vars$ids)) {
  raw_ids <- data[[vars$ids[[1L]]]]
  if (isTRUE(vars$nest) && !is.null(vars$strata)) {
    as.integer(interaction(strata_id, raw_ids, drop = TRUE))
  } else {
    raw_ids
  }
} else {
  seq_len(n)
}
clusters_mat <- matrix(psu_id, ncol = 1L)
strata_mat   <- matrix(strata_id, ncol = 1L)
psu_per_stratum  <- tapply(psu_id, strata_id, function(ps) length(unique(ps)))
sampsize_vec     <- as.integer(psu_per_stratum[as.character(strata_id)])
sampsize_mat     <- matrix(sampsize_vec, ncol = 1L)
fpc_col_full <- if (!is.null(vars$fpc)) data[[vars$fpc]] else NULL
popsize_mat  <- ...
fpcs <- list(sampsize = sampsize_mat, popsize = popsize_mat)
```

With:

```r
mats <- .build_cluster_matrices(data, vars)
```

Then replace `clusters_mat`, `strata_mat`, `fpcs` references with
`mats$clusters_mat`, `mats$strata_mat`, `mats$fpcs`.

---

## VIII. `.vcov_pair_taylor()` Update

Apply the same replacement as in §VII. The inline matrix-building block
starting at approximately line 391 of `R/variance-taylor.R` (`.vcov_pair_taylor()`
internal section) is replaced with:

```r
mats <- .build_cluster_matrices(data, vars)
```

Use `mats$clusters_mat`, `mats$strata_mat`, `mats$fpcs`.

---

## VIII.5. `survey_glm()` — `R/glm.R` FPC Update

`R/glm.R` (~line 262) contains an inline FPC access that uses `data[[vars$fpc]]`
directly. When `vars$fpc` is a character vector of length > 1 (multi-stage FPC),
`data[[c("fpc1", "fpc2")]]` performs recursive indexing and errors with
`subscript out of bounds`. This call site must be updated.

### Change required

Replace the inline block:

```r
popsize_mat <- if (!is.null(vars$fpc)) {
  fpc_vals <- data[[vars$fpc]]    # errors for multi-stage fpc
  ...
}
```

With:

```r
mats      <- .build_cluster_matrices(design@data, design@variables)
popsize_mat <- mats$fpcs$popsize
```

Use `mats$clusters_mat`, `mats$strata_mat`, `mats$fpcs` in place of the
inline single-stage equivalents throughout the affected block in `glm.R`.

### Oracle tests for multi-stage GLM

Add to `tests/testthat/test-glm.R`:

```r
test_that("survey_glm() matches survey::svyglm() for 2-stage design [oracle]", {
  skip_if_not_installed("survey")
  df <- make_survey_data(n = 500, n_psu = 50, n_ssu = 10, seed = 42)
  sc <- as_survey(df, ids = c(psu, ssu), weights = wt, strata = strata)
  sv <- survey::svydesign(id = ~psu + ssu, weights = ~wt, strata = ~strata,
                          data = df, nest = TRUE)
  sc_fit <- survey_glm(y1 ~ y2, design = sc)
  sv_fit <- survey::svyglm(y1 ~ y2, design = sv)
  expect_equal(coef(sc_fit), coef(sv_fit), tolerance = 1e-10)
  expect_equal(SE(sc_fit),   SE(sv_fit),   tolerance = 1e-8)
})
```

---

## IX. `.svy_multistage()` — Remove `# nocov`

Remove the `# nocov start` and `# nocov end` markers (lines 141 and 157 of
`R/variance-taylor.R`) once the matrix builders correctly populate
multi-column matrices.

**No changes to the kernel logic.** The `.svy_multistage()` function is
already correct. The only change is removing the coverage exclusion markers.

The recursive multi-stage path is reached when:
1. `!isTRUE(one.stage)` — not forcing single-stage
2. `!is.null(popmat)` — FPC is present (required to compute the stage-k
   sampling fraction scaling factor `nPSUs[idx, 1L] / popmat[idx, 1L] = f_j`)
3. `NCOL(clusters) > 1L` — multi-column cluster matrix was built

This means: designs without any FPC (`popmat = NULL`) still use only the
stage-1 variance path, which is mathematically correct (§V Step 7). This
matches `survey` package behavior: Lumley (2010) §2.1 states "When fpc is not
given, the only variance component is the between-PSU component."

**`one.stage` arithmetic note:** The vendored kernel passes `one.stage - 1L`
to recursive calls. When `one.stage = FALSE`, this yields `-1L`. Since
`!isTRUE(-1L) = TRUE`, recursion continues through all stages — termination is
governed by `NCOL(clusters) > 1L` (columns are removed with `[, -1L, drop=FALSE]`
at each recursive call), not by the `one.stage` decrement. Do not change this
behavior.

### Design degrees of freedom for multi-stage designs

Design df for a multi-stage design is `Σ_h (n_h − 1)`, where `n_h` is the
number of sampled stage-1 PSUs in stratum h. This is identical to the
single-stage formula; stage 2+ structure does not affect df.
`.degf_taylor()` requires no changes. (Reference: Rust & Rao 1996; Kish &
Frankel 1974.)

When `nest = TRUE`, PSU IDs are made globally unique by the `interaction()`
call in `.build_cluster_matrices()` Step 3 before the df count.

### Confidence interval approximation for Taylor series designs

Phase 1 analysis functions (`get_means()`, `get_totals()`, `get_freqs()`,
etc.) use **normal approximation** (t with df = Inf) for CIs. This matches
the default printed output of `survey::svymean()` but diverges from
`confint(svymean_result)`, which uses finite design df `Σ_h (n_h − 1)`.
The divergence is negligible for df ≥ 30 and grows for small designs.

`get_quantiles()` uses finite design df (via `.degf_woodruff()`) to match
`survey::svyquantile()`. No changes to either behaviour are required in this
phase.

Design-based df-adjusted CIs for the other Phase 1 functions are deferred to
a future phase.

---

## IX.5. `print.survey_taylor` — Per-Stage FPC Display

Update `R/methods-print.R` so that `print.survey_taylor` renders multi-column
FPC with one bullet per stage rather than a single space-separated string.

### Current behavior (single-stage)

```r
# fpc_var = "fpc1"
# Renders: • FPC: fpc1
```

### New behavior (multi-stage)

```r
fpc_var <- x@variables$fpc
if (!is.null(fpc_var)) {
  if (length(fpc_var) == 1L) {
    cli::cli_bullets(c("*" = "FPC: {.field {fpc_var}}"))
  } else {
    for (j in seq_along(fpc_var)) {
      cli::cli_bullets(c("*" = "FPC (stage {j}): {.field {fpc_var[[j]]}}"))
    }
  }
}
```

Renders for `fpc_var = c("fpc1", "fpc2")`:
```
• FPC (stage 1): fpc1
• FPC (stage 2): fpc2
```

### Snapshot test

Add a snapshot test to `tests/testthat/test-methods-print.R`:

```r
test_that("print.survey_taylor shows per-stage FPC for 2-stage design", {
  df <- make_survey_data(n = 200, n_psu = 20, n_ssu = 5, seed = 1)
  sc <- as_survey(df, ids = c(psu, ssu), weights = wt, strata = strata,
                  fpc = c(fpc, fpc2))
  expect_snapshot(print(sc))
})
```

---

## X. Error and Warning Table — New Rows

The following rows must be added to `plans/error-messages.md`. Existing rows
are not modified except as noted.

### New rows

| # | Function | Condition | Level | Error Class | CLI Message Template |
|---|----------|-----------|-------|-------------|----------------------|
| 88 | `as_survey()` | `fpc` selects more columns than ID stages | ERROR | `surveycore_error_fpc_too_many_stages` | `"{.arg fpc} has {n_fpc} column(s) but only {n_id} ID stage(s) are specified. Supply at most one FPC column per ID stage."` |
| 89 | `as_survey()` | `fpc` selects fewer columns than ID stages (partial FPC) | WARN | `surveycore_warning_fpc_partial_stages` | `"FPC provided for stage 1 only ({.field {fpc_vars[[1L]]}}). Stage {seq(2, n_ids)} treated as sampling from an infinite sub-population (no FPC correction)."` |
| 90 | `as_survey()` | FPC column (fraction) is not constant within stage-j parent group | ERROR | `surveycore_error_fpc_not_constant` | `"{.arg fpc} column {.field {fpc_col}} must have a constant value within each stage-{j} parent group. FPC is interpreted as a cluster-level sampling fraction."` |
| 91 | `as_survey()` | FPC column (population size) varies within stage-j parent group | WARN | `surveycore_warning_fpc_popsize_varies_within_stratum` | `"{.arg fpc} column {.field {fpc_col}} varies within stage-{j} parent groups. FPC population sizes should be constant within each parent group."` |

### Modified rows

Row 13b currently reads: "`as_survey()` / `as_survey_replicate()` — `fpc` selects > 1 column → ERROR".

**After this phase**, split row 13b into two:

| # | Function | Condition | Level | Error Class |
|---|----------|-----------|-------|-------------|
| 13b | `as_survey_replicate()` | `fpc` selects > 1 column | ERROR | `surveycore_error_fpc_multiple` (unchanged) |
| 88 | `as_survey()` | `fpc` selects more columns than ID stages | ERROR | `surveycore_error_fpc_too_many_stages` (new) |

---

## XI. Testing Requirements

### Oracle tests (required)

All oracle tests: `skip_if_not_installed("survey")`. File:
`tests/testthat/test-variance-taylor.R`.

Tolerance: per `testing-surveycore.md` — point estimates `1e-10`, SE `1e-8`.

#### 2-stage design, no FPC

**Rule:** Every oracle test block that calls `as_survey()` must call
`test_invariants(sc)` as its **first** assertion (per `testing-surveycore.md`).

```r
test_that("get_means() matches survey::svymean() for 2-stage design, no FPC [oracle]", {
  skip_if_not_installed("survey")
  df <- make_survey_data(n = 500, n_psu = 50, n_ssu = 10, seed = 42)
  sc <- as_survey(df, ids = c(psu, ssu), weights = wt, strata = strata)
  test_invariants(sc)   # always first
  sv <- survey::svydesign(id = ~psu + ssu, weights = ~wt, strata = ~strata,
                          data = df, nest = TRUE)
  sc_est <- get_means(sc, y1)
  sv_est <- survey::svymean(~y1, sv, na.rm = TRUE)
  expect_equal(sc_est$mean, coef(sv_est)[["y1"]], tolerance = 1e-10)
  expect_equal(sc_est$se,   SE(sv_est)[["y1"]],   tolerance = 1e-8)
})
```

Required oracle comparisons (all using `get_means()` unless noted):

| Test | Design | Function |
|------|--------|----------|
| 2-stage, no FPC | `ids = c(psu, ssu), fpc = NULL` | `get_means()` |
| 2-stage, FPC at stage 1 only | `ids = c(psu, ssu), fpc = fpc1` | `get_means()` |
| 2-stage, FPC at both stages | `ids = c(psu, ssu), fpc = c(fpc1, fpc2)` | `get_means()` |
| 2-stage, `get_freqs()` | `ids = c(psu, ssu), fpc = NULL` | `get_freqs()` |
| 2-stage, `get_totals()` | `ids = c(psu, ssu), fpc = NULL` | `get_totals()` |
| 2-stage, `get_corr()` | `ids = c(psu, ssu), fpc = NULL` | `get_corr()` vs `survey::svycor()` |
| 2-stage, `get_quantiles()` | `ids = c(psu, ssu), fpc = NULL` | `get_quantiles()` vs `survey::svyquantile()` |
| 2-stage, `get_ratios()` | `ids = c(psu, ssu), fpc = NULL` | `get_ratios()` vs `survey::svyratio()` |
| 3-stage, no FPC | `ids = c(psu, ssu, unit), fpc = NULL` | `get_means()` |
| 3-stage, FPC at stage 1 only | `ids = c(psu, ssu, unit), fpc = fpc1` | `get_means()` |
| 3-stage, FPC at all stages | `ids = c(psu, ssu, unit), fpc = c(fpc1, fpc2, fpc3)` | `get_means()` |

**Note on 3-stage, no FPC:** With `fpc = NULL`, `popmat = NULL` in the kernel,
so `.svy_multistage()` does **not** recurse (condition `!is.null(popmat)` is
false). This test verifies that the 3-column matrix is built without error and
that stage-1 variance matches `survey`, but it does **not** exercise the
recursive code path. The two 3-stage FPC tests above are the oracle tests that
validate the actual depth-3 recursion.

#### Reference for survey package call

```r
# 2-stage with stage-1-only FPC
sv <- survey::svydesign(
  id = ~psu + ssu, weights = ~wt, strata = ~strata,
  fpc = ~fpc1,
  data = df, nest = TRUE
)

# 2-stage with per-stage FPC
sv <- survey::svydesign(
  id = ~psu + ssu, weights = ~wt, strata = ~strata,
  fpc = ~fpc1 + fpc2,
  data = df, nest = TRUE
)

# 3-stage with stage-1-only FPC
sv <- survey::svydesign(
  id = ~psu + ssu + unit, weights = ~wt, strata = ~strata,
  fpc = ~fpc1,
  data = df, nest = TRUE
)

# 3-stage with full per-stage FPC
sv <- survey::svydesign(
  id = ~psu + ssu + unit, weights = ~wt, strata = ~strata,
  fpc = ~fpc1 + fpc2 + fpc3,
  data = df, nest = TRUE
)
```

### Regression tests (required)

Verify that refactoring does not change single-stage results. All existing
tests in `test-variance-taylor.R` must pass without numerical change. Add
explicit regression guard:

```r
test_that(".build_cluster_matrices() produces identical single-stage output [regression]", {
  df <- make_survey_data(n = 500, seed = 1)
  sc <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
  # Compare before/after: record current estimate, verify unchanged post-refactor
  est <- get_means(sc, y1)
  expect_equal(est$mean, <recorded_value>, tolerance = 1e-12)
  expect_equal(est$se,   <recorded_value>, tolerance = 1e-12)
})
```

> ⚠️ **GAP**: The "recorded values" above must be captured from the current
> `develop` branch before the refactor begins, using `dput()` in an interactive
> session, and hard-coded in the test. The implementation plan must include a
> step to capture these values.

### Edge case tests (required)

| Test | Description |
|------|-------------|
| 2-stage with `nest = TRUE` | PSU IDs re-used across strata; verify nest interaction applied only at stage 1 |
| 2-stage, single SSU per PSU | Lonely PSU at stage 2; the `survey.lonely.psu` option applies recursively at all stages — verify `getOption("survey.lonely.psu")` is respected at stage 2, not just stage 1; design df is unaffected |
| 2-stage with `na.rm = TRUE` | NA values in outcome variable scattered across PSUs; verify filtered data path and that SE matches `survey` oracle |
| 2-stage `na.rm = TRUE`, all-NA PSU | One entire PSU has all-NA outcomes: `df$y1[df$psu == df$psu[[1]]] <- NA`; `.build_cluster_matrices()` is built from full data so that PSU is still counted in sampsize; verify no error and SE matches `survey` oracle — this is an **intentional behavioral change** from the pre-refactor code (which built sampsize from filtered data) and matches the `survey` package's design-structure-first semantics |
| 2-stage with domain estimation | `filter()` applied before `get_means()`; verify correct SE |
| 2-stage with domain AND `na.rm = TRUE` | `filter()` applied before `get_means(..., na.rm = TRUE)` on a variable with NAs; verify SE wider than SRS (domain estimation) and matches `survey` oracle |
| Partial FPC: `fpc = fpc1` with 2-stage ids | `expect_warning(class = "surveycore_warning_fpc_partial_stages")` — `cli_warn()` emits a warning, matching `survey::as.fpc()`'s `warning()` |
| Too many FPC columns | `fpc = c(fpc1, fpc2, fpc3)` with 2-stage ids → error `surveycore_error_fpc_too_many_stages` |
| Non-constant FPC fraction within PSU | Stage-2 FPC column where values differ within the same PSU — dual-pattern test (class= + snapshot) for `surveycore_error_fpc_not_constant`:  `df$fpc2_bad <- runif(nrow(df), 0.1, 0.9)` (varies within PSU); `expect_error(as_survey(..., fpc = c(fpc, fpc2_bad)), class = "surveycore_error_fpc_not_constant")` + `expect_snapshot(error = TRUE, ...)` |
| Stage-2 FPC column has NA | `df$fpc2_bad <- fpc2; df$fpc2_bad[1] <- NA` → dual-pattern test for `surveycore_error_fpc_na` |
| Stage-2 FPC column has nonpositive | `df$fpc2_bad <- fpc2; df$fpc2_bad[1] <- 0` → dual-pattern test for `surveycore_error_fpc_nonpositive` |
| Stage-2 FPC column smaller than stage-2 n | `df$fpc2_bad <- 1L` (population smaller than sampled SSU count) → dual-pattern test for `surveycore_error_fpc_smaller_than_n` |
| 2-stage grouped estimate | `get_means(sc_2stage, y1, group = strata)` vs `survey::svyby(~y1, ~strata, sv_2stage, svymean)` — include `test_invariants(sc_2stage)` first |
| Single-stage unchanged | `ids = psu` with and without FPC; output must be byte-identical to pre-refactor |

### `make_survey_data()` extension

Add `n_ssu` and `n_unit` parameters to `make_survey_data()`:

```r
make_survey_data <- function(
  n           = 500L,
  n_psu       = 50L,
  n_ssu       = NULL,   # NEW: number of SSUs per PSU (NULL = no SSU column)
  n_unit      = NULL,   # NEW: number of units per SSU (NULL = no unit column; requires n_ssu)
  n_strata    = 5L,
  ...
)
```

When `n_ssu` is not `NULL`:
- Add a `ssu` column: character SSU IDs, unique within PSU (format: `"{psu}_s{j}"`)
- Add an `fpc2` column: integer within-SSU population size (constant per PSU: `n_ssu * 2L`)

When `n_unit` is not `NULL` (requires `n_ssu` to also be non-`NULL`):
- Add a `unit` column: character unit IDs, unique within SSU (format: `"{ssu}_u{j}"`)
- Add an `fpc3` column: integer population size at stage 3 (constant per SSU: `n_unit * 2L`)
- Error if `n_ssu = NULL` and `n_unit` is not `NULL`

When both are `NULL` (default): behavior is identical to current; no new columns.

**Policy:** Edge cases with specific SSU structures (e.g., single SSU per PSU)
are constructed inline in tests, per `testing-standards.md §4`.

---

## XII. Quality Gates

All gates must pass before the PR can be opened:

- [ ] `devtools::check()` passes with 0 errors, 0 warnings, ≤ 2 pre-approved notes
- [ ] `devtools::test()` passes: all existing tests green, new tests green
- [ ] Line coverage ≥ 98% (includes `.svy_multistage()` multi-stage path — no longer `# nocov`)
- [ ] `plans/error-messages.md` updated with rows 88–89 and revised row 13b
- [ ] Oracle tests pass for all 11 combinations in §XI (includes 3-stage WITH FPC)
- [ ] Regression tests confirm zero numerical change for all single-stage designs
- [ ] `air::format_package()` run; no formatting diffs in committed code
- [ ] All direct call sites refactored to use `.build_cluster_matrices()`; no inline matrix-building pattern remains (includes `R/variance-srs.R`)

---

## XIII. Integration Contracts

### surveytidy

surveytidy's `filter()` sets `..surveycore_domain..` on the data and passes a
`survey_taylor` object to analysis functions. The multi-stage changes are
transparent to surveytidy: the domain estimation cell functions already work
on the full dataset with domain indicators, and `.build_cluster_matrices()` is
called with the full `design@data`. No surveytidy changes required.

### Other surveyverse packages

None of the other packages (surveywts, surveyverse meta-package) interact
with the cluster matrix construction layer. No changes required.
