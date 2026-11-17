# Measurements — analysis-cell-performance

Measured 2026-11-05 on `develop` at `0c0a987`, R on Windows 11 with R's
reference BLAS. `bench` is not installed; timings are medians of
`system.time()` over 3 to 10 runs, so they read in 10 ms steps. Code loaded
with `devtools::load_all()`; about 13% of each profile is JIT compilation
that an installed package does not pay.

Scripts: `evidence/freqs/` and `evidence/means/` in this run directory.

## Designs

- `gss_2024` Taylor: `ids = vpsu, strata = vstrat, weights = wtssps,
  nest = TRUE`.
- Synthetic frame: 50,000 rows, 50 strata, 200 PSUs; categorical variables
  with 3, 5, 7 and 10 levels; numeric variables; groups `g4` (4 levels) and
  `g20` (20 levels).
- Replicate: the same frame, 80 bootstrap replicates.
- `get_means()` also: a calibrated GSS design, and 12 edge designs (two-stage
  with FPC, SRS, strata only, each under `lonely.psu` = remove, adjust,
  average, certainty).

## `get_freqs()` — seconds per call

P2 = fixes 1 and 2 (Taylor). P4 = fix 3 (replicate).

| Scenario | Rows | Before | P2 | P4 |
|---|---|---|---|---|
| gss, 1 var | 8 | 0.25 | 0.03 | |
| gss, `group = race` | 24 | 0.81 | 0.08 | |
| gss, 4 vars | 22 | 0.67 | 0.06 | |
| syn Taylor, 1 var | 10 | 0.53 | 0.06 | |
| syn Taylor, `group = g4` | 40 | 1.96 | 0.22 | |
| syn Taylor, 4 vars | 25 | 1.30 | 0.14 | |
| syn rep80, 1 var | 10 | 0.39 | | 0.11 |
| syn rep80, `group = g4` | 40 | 1.69 | | 0.25 |
| syn rep80, 4 vars | 25 | 0.97 | | 0.30 |

Fix 1 alone: 2.1x to 2.7x. `identical()` TRUE on the whole result, including
`.vcov`, also with `variance = c("se","ci","var","cv","moe","deff")`.

## `get_means()` — seconds per call

After = fixes 1, 2 and 4 (Taylor) or fix 3 (replicate).

| Scenario | Before | After |
|---|---|---|
| GSS Taylor, no group | 0.080 | 0.035 |
| GSS, `group = degree` | 0.230 | 0.045 |
| GSS, `group = c(sex, race)` | 0.260 | 0.060 |
| GSS calibrated, `group = degree` | 0.225 | 0.070 |
| 50k Taylor, no group | 0.110 | 0.050 |
| 50k Taylor, `group = g20` | 1.18 | 0.22 |
| 50k Taylor, 20x3 groups (60 cells) | 3.59 | 0.71 |
| 50k replicate, no group | 0.040 | 0.040 |
| 50k replicate, `group = g20` | 0.95 | 0.47 |

`identical()` TRUE on all 10 scenarios and the 12 edge designs, including the
calibrated design's `df` column.

## Hotspots (Rprof, line profiling)

Taylor path:
- `.build_cluster_matrices()` per cell: `R/analysis-freqs-helpers.R:52`
  (49–53%), `R/analysis-means-helpers.R:80` (36%; 44–52% on GSS). Rebuilt
  again in `.joint_vcov()` at `R/analysis-helpers.R:1229`. Inside it:
  `interaction()` at `R/utils.R:1129` (calls `as.character()` on numeric IDs)
  and `tapply()` at `R/utils.R:1166`.
- `.svy_recvar()` per cell: freqs 34–41%, means 27%. Then run again on all
  cells by `.joint_vcov()`; that matrix's diagonal equals each cell's
  variance (comment at `R/analysis-helpers.R:1208`).
- `get_means()` only: `.degf_taylor(data[domain > 0, , drop = FALSE], vars)`
  at `R/analysis-means-helpers.R:99` copies every column per cell (8% on 50k,
  about 30% of GSS after fix 1). Used only for calibrated designs
  (`R/analysis-means.R:272-275`).

Replicate path:
- `as.matrix(data[, vars$repweights])` per cell:
  `R/analysis-freqs-helpers.R:117` (45%), `R/analysis-means-helpers.R:172`
  (47%).
- Two n x R matrix-vector products per cell (41–48%). In `get_freqs()` the
  denominator product is the same for every level in a group.

Under 5% each, not worth changing: validation, tidyselect, metadata and label
lookups, `.build_group_combos()`, `.match_group_combo()`,
`.apply_group_labels()`, `.level_display()`, `.make_result_tibble()`,
`.build_coef_names()`, growing `acc_*` vectors with `c()`.

## Fixes prototyped

1. Build the cluster matrices once per call; pass them to the cells and to
   `.joint_vcov()`. Very low risk.
2. Cells return only their influence column; one `.svy_recvar()` per call;
   SE = `sqrt(pmax(0, diag(v)))` for non-NA cells; the same matrix is attached
   as `.vcov`. `.svy_onestrat()` handles each column separately, which is why
   the diagonal matches. An optimized BLAS may differ in the last bit.
3. Convert the replicate columns once per call. freqs: sum only the cell's
   rows (`rep(1, n_cell) %*% rep_mat[idx, ]`) and compute each group's
   denominator once. means: one `crossprod(rep_mat, cbind(domain,
   y_safe * domain))` in place of two products. Do not use `colSums()`: it
   adds in long double and is not bit-identical.
4. `get_means()`: compute `.degf_taylor()` only when `design@calibration` is
   set, and subset only the ID and strata columns.

## Other files with the same pattern (not measured)

- `.build_cluster_matrices()` per cell: `R/analysis-totals-helpers.R:60`,
  `R/analysis-variance-helpers.R:158`, `R/analysis-covariance-helpers.R:227`.
- `as.matrix(data[, vars$repweights])` per cell:
  `R/analysis-totals-helpers.R:138`, `R/analysis-variance-helpers.R:238`,
  `R/analysis-covariance-helpers.R:303`, `R/analysis-ratios-helpers.R:57`.

## Not run

Two-phase and `survey_nonprob` designs; domain-filtered designs (`filter()`
is in surveytidy, which is not installed).
