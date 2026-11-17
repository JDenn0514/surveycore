# Comprehension — analysis-cell-performance

Read on `develop` at `0c0a987`. Every `file:line` below is in that tree.
"Fix 1" to "fix 4" are the four fixes in `measurements.md` §Fixes
prototyped. "Bit-identical" means `identical()` TRUE. D3 sets the test bar at
`expect_equal(tolerance = 1e-12)`. Revised after `verification-comprehension.md`
round 1 (V1 to V11). R facts marked "measured" come from that file: R 4.6.1
ucrt, reference BLAS, `getOption("matprod")` = "default".

## Problem

Six analysis functions compute one estimate per cell. A cell is one level,
one group, or one level-by-group pair. Each cell repeats work that is the same
for every cell: it rebuilds the cluster, strata and FPC matrices, runs the
Taylor variance engine on one column, and converts the replicate weight
columns to a matrix. Four functions then run the Taylor engine a second time,
on all cells at once, to build the joint covariance matrix (`.vcov`). The
goal is to do the shared work once per call. No number in the result may
change: not the estimate, the SE, the derived columns, the `df` column, nor
the `.vcov` attribute. The method itself does not change. The task is to
prove which reorderings are exact and to list the conditions where they are
not.

## Formulas

### Taylor variance of a set of influence columns

The engine is `.svy_recvar()` (`R/variance-taylor.R:199-218`). For an
`n x k` influence matrix `U`, stage 1 is:

```
V = (H / H_ok) * sum over strata h of V_h          # variance-taylor.R:136-143
V_h = crossprod( (T_h - c_h) * sqrt(s_h) )         # variance-taylor.R:70-72
T_h = rowsum(U[rows in h, ], cluster)              # variance-taylor.R:48
c_h = colMeans(T_h)                                # variance-taylor.R:58-60
s_h = f_h * n_h / (n_h - 1)                        # variance-taylor.R:41
f_h = (N_h - n_h) / N_h, or 1 with no FPC          # variance-taylor.R:35-39
```

`H` is the number of strata and `H_ok` the number of strata whose `k x k`
block `V_h` has no `NA` (`R/variance-taylor.R:133-134`). The stratum sum uses
`na.rm = TRUE` entry by entry (`:136-141`). Later stages recurse within each
first-stage cluster, and each recursive call counts its own `H` and `H_ok`
(`:172-190`). The recursion runs only when `popmat` is non-`NULL` (an FPC is
given) and there is more than one cluster column (`:172`). The SE of cell `j`
is `sqrt(max(0, V[j, j]))`.

| Symbol | Meaning | Bound to |
|---|---|---|
| `w_i` | weight | `design@data[[design@variables$weights]]`; may be `"..surveycore_wt.."` (`R/utils.R:353`) |
| `d_i` | 0/1 cell or domain indicator | `denom`, `domain`, `domain_vec` built in each `get_*()` loop |
| cluster, strata, `n_h`, `N_h` | design structure | `.build_cluster_matrices(design@data, design@variables)` (`R/utils.R:1110-1250`) |
| lonely option | `survey.lonely.psu` | `getOption("survey.lonely.psu", "remove")`, read in each cell |

### Influence column per function (Taylor route)

| Function | Column `u_i` passed to `.svy_recvar()` | Source |
|---|---|---|
| `get_freqs()` | `w_i (num_i - p denom_i) / N_d`, then calibration projection | `R/analysis-freqs-helpers.R:49,55-56` |
| `get_means()` | `w_i d_i (y_i - ybar) / N_d`, then calibration projection | `R/analysis-means-helpers.R:77,83-84` |
| `get_totals()` | `w_i d_i y_i`, then calibration projection | `R/analysis-totals-helpers.R:57,64-65` |
| `get_ratios()` | the total column of `z_i = d_i (y_i - R x_i)`; SE divided by `abs(total_x)` | `R/analysis-ratios-helpers.R:123-129` |
| `get_variance()` | `w_i a_i (z_i - v_hat) / W`, `z_i = kish (y_i - ybar)^2`; no calibration | `R/analysis-variance-helpers.R:156,161` |
| `get_covariance()` | `w_i a_i (z_i - c_hat) / W`, `z_i = kish dx_i dy_i`; no calibration | `R/analysis-covariance-helpers.R:225,230` |

`get_variance()` and `get_covariance()` use the same influence shape: the
influence of a weighted mean of a score. Only the score differs
(`.score_variance()` at `R/analysis-variance-helpers.R:38-103`,
`.score_covariance()` at `R/analysis-covariance-helpers.R:51-148`). Neither
applies `.maybe_apply_calibration()`. A refactor must not add it.

### Replicate variance

Per cell: `v = scale * sum(rscales * (theta_r - centre)^2)`
(`.svy_rep_var()`, `R/variance-replicate.R:26-47`; `sum()` at `:46`). For
the joint matrix: `t(D * rscales) %*% D * scale` (`.svy_rep_vcov()`,
`:60-74`; `%*%` at `:73`). The two are equal in exact arithmetic only.
`sum()` and `%*%` round differently, so the per-cell SE on the replicate
route must stay on `.svy_rep_var()`.

## Per-function call paths

All four design classes are siblings under `survey_base`
(`R/core-classes.R:454-456, 681-683, 874-876, 1308-1310`). The order of the
branches in a dispatcher therefore does not change which branch runs. In each
dispatcher, nonprob with replicates goes to the replicate cell, and nonprob
without replicates warns and goes to the calibrated cell.

### Cell functions by route

Helper line numbers are in `R/analysis-{fn}-helpers.R`.

| Function | Loop and cell call | Dispatcher | Taylor | Replicate | Nonprob, no replicates | Two-phase | Joint |
|---|---|---|---|---|---|---|---|
| `get_freqs()` | variables `R/analysis-freqs.R:278`, combos `:330`, levels `:350`; `.freq_cell()` `:358` | `:309-345` | `:24` | `:93` (nonprob `:313-314`) | warning `:316-329`; `:248` | `:177` | `.joint_infl()` `:78`, `.joint_rep()` `:161` |
| `get_means()` | combos `R/analysis-means.R:224`; `.mean_cell()` `:235` | `:365-407` | `:50` | `:147` (nonprob `:373-374`) | warning `:376-389`; `:302` | `:235` | `:133`, `:220` |
| `get_totals()` | combos `R/analysis-totals.R:299`, levels `:316`; `.total_cell()` `:317` | `:347-389` | `:25` | `:108` (nonprob `:355-356`) | warning `:358-371`; `:276` | `:199` | `:94`, `:186` |
| `get_variance()` | variables `R/analysis-variance.R:258`, combos `:270`; `.variance_cell()` `:291` | `:492-530` | `:120` | `:203` (`:495-501`) | warning `:503-516`; `:424` | `:330` | none |
| `get_covariance()` | combos `R/analysis-covariance.R:365`, pairs `:380`; `.covariance_pair_result()` `:386` | `:549-587` | `:184` | `:266` (`:552-558`) | warning `:560-573`; `:479` | `:394` | none |

`.vcov` is attached at `R/analysis-freqs.R:498`, `R/analysis-means.R:348`,
`R/analysis-totals.R:438` and `R/analysis-ratios.R:443`. `get_variance()`
and `get_covariance()` make no `.attach_joint_vcov()` call. Two-phase and
nonprob-without-replicates cells return no `joint`.

### Cell-independent work

| Function | Taylor | Replicate | Two-phase |
|---|---|---|---|
| `get_freqs()` | `.build_cluster_matrices()` `:52`, option `:53` | `as.matrix()` `:117`; `denom %*% rep_mat` `:118` | `.compute_phase2_probs()` and `cal_wt` `:183-184`, option `:214` |
| `get_means()` | `:80`, option `:81`, `.get_calibration_df_reduction()` `:85`; columns of `.degf_taylor()` `:99` | `as.matrix()` `:172` only | `:241`, option `:271` |
| `get_totals()` | `:60`, option `:61` | `as.matrix()` `:138` | `:205` |
| `get_variance()` | `:158`, option `:159` | `as.matrix()` `:238` | `:336` |
| `get_covariance()` | `:227`, option `:228` | `as.matrix()` `:303` | `:400` |

Each two-phase cell also rebuilds design-only structures in `.twophasevar()`
(§Reference mapping).

- `get_freqs()`: `denom %*% rep_mat` `:118`, `N_d` and `n_g` `:30-31,
  98-99` depend on `denom` only, which is fixed for one variable and one
  combo (`R/analysis-freqs.R:343-347`). Every level repeats them.
- `get_means()`: one cell per combo, `domain` rebuilt per combo
  (`R/analysis-means.R:234`), so cells share only design-only work. The
  replicate products at `:173` and `:175` depend on `domain` and stay per
  cell. Fix 3 merges them into one `crossprod(rep_mat, cbind(domain, y_safe
  * domain))` per cell, a per-cell rewrite (`identical()` TRUE in
  `measurements.md`).
- `get_means()`, `.degf_taylor(data[domain > 0, , drop = FALSE], vars)` `:99`
  copies every column. The rows are cell-specific (issue #326); the columns
  are not, because it reads only `vars$ids[[1L]]`, `vars$strata` and
  `vars$nest` (`R/analysis-helpers.R:349-380`). The result is used only on a
  calibrated Taylor design (`R/analysis-means.R:272-275, 290-292, 329-335`).
- `get_means()` second caller: `get_quantiles()` reads `cell$mean` and
  `cell$se` from `.mean_cell()`, never `cell$df`
  (`R/analysis-quantiles-helpers.R:154-158`). The per-cell mean and SE must
  stay the same when called with the current arguments.
- `get_totals()`: a categorical `x` adds its 0/1 level columns once, before
  the loop (`R/analysis-totals.R:270-280`); design columns do not change.
  The replicate cell has one product (`:139`), no shared denominator.
- `get_variance()`: `rep_mat[active, ]` `:244` and `colSums()` `:248-249`
  are cell-specific and stay.
- `get_covariance()`: one result per needed unordered pair, keyed `"i-j"`,
  per combo (`R/analysis-covariance.R:377-378, 411, 428`), reused for
  redundant and mirrored rows (`:506-520`).

### `get_ratios()`

Loop: combos `R/analysis-ratios.R:269`. A cell can make three calls that
reach the variance machinery:

1. `cell_x <- .total_cell(design, denom_name, domain_vec)` `:296`. Only
   `$total` and `$n_weighted` are used (`:297, :362`). An empty cell or an
   `NA` denominator total stops here: the cell is stored as `"na"` and the
   loop moves on (`:317-328`).
2. `cell_y <- .total_cell(design, num_name, domain_vec)` `:331`. Only
   `$total` is used (`:332`).
3. The SE call: `.replicate_ratio_cell()` `:338` when `is_replicate`
   (`:215-217`), else `.delta_ratio_cell()` `:347`.

| Route | SE path | Joint |
|---|---|---|
| Taylor | `.delta_ratio_cell()` `R/analysis-ratios-helpers.R:110` writes `z` to `design@data` `:125`, then `.total_cell()` `:126` → `.taylor_total_cell()` | total joint divided by `total_x` `:131-135` |
| Replicate, nonprob with replicates | `.replicate_ratio_cell()` `:23` | `.joint_rep()` `:86` |
| Nonprob, no replicates | `.delta_ratio_cell()` → `.calibrated_total_cell()` | none |
| Two-phase | `.delta_ratio_cell()` → `.twophase_total_cell()` | none |

`get_ratios()` has no `.build_cluster_matrices()` call of its own. It reaches
it through `.taylor_total_cell()` (`R/analysis-totals-helpers.R:60`) up to
three times per Taylor cell, plus once in `.joint_vcov()`. It runs
`.svy_recvar()` up to three times per Taylor cell, and the SEs of calls 1
and 2 are thrown away. On the replicate route it converts the replicate
columns up to three times per cell: twice in `.replicate_total_cell()`
(`R/analysis-totals-helpers.R:138`) and once in `.replicate_ratio_cell()`
(`R/analysis-ratios-helpers.R:57`).

## The joint matrix and its diagonal

`.joint_vcov()` (`R/analysis-helpers.R:1215-1254`) returns `NULL` when any
cell has no `joint` element (`:1217-1219`). It marks cells of kind `"na"` as
not live and leaves their rows `NA` (`:1221-1222, :1252`), and returns the
all-`NA` matrix with no variance call when no cell is live (`:1223-1225`).
It stacks the live columns with `cbind` (`:1227`). On Taylor it rebuilds the
cluster matrices (`:1229`) and runs one `.svy_recvar()` over the stack,
reading the option again (`:1230-1236`); on replicate it runs
`.svy_rep_vcov()` (`:1237-1251`).

Each Taylor joint value is `infl_mat[, 1L]` after the calibration
projection (`R/analysis-helpers.R:1192-1194`; freqs `:56, :78`; means
`:84, :133`; totals `:65, :94`). The per-cell `.svy_recvar()` call takes the
same `infl_mat`, so both sides see the projected column.

### Proof that column `j` of the stack gives the cell's own variance

Take the stacked matrix `U` with finite entries. Each step treats each
column on its own:

- `f`, `scale` and the zero return for `all(f < 1e-7)` depend on the design
  only (`R/variance-taylor.R:35-45`). `rowsum()`, `colMeans()` and `sweep()`
  work per column (`:48, :59, :61`). Under `"adjust"` the recentering
  `colSums(x) / n_psus_all` is per column, with a design-only divisor
  (`:106-110`).
- `crossprod(x * sqrt(scale))` (`:71`): entry `[j, j]` sums `x[, j]^2 *
  scale` over PSUs. On R's reference BLAS (`dsyrk`) the loop for one entry
  runs in the same order for any number of columns.
- A lonely stratum gives an all-`NA` block under `"average"` (`:79`) and a
  zero block under `"remove"` and `"certainty"` (`:58-61, :76-77`), whatever
  the columns. With finite columns `H_ok` (`:134`), and each later-stage
  sub-call's `H_ok` (`:172-189`), count the same strata for one column or
  many. The stratum sum is entry by entry; `H / H_ok` and the stage
  multipliers are design scalars (`:136-143, :184-185`).
- `"fail"`: a stacked call and a single call both abort with
  `surveycore_error_lonely_psu`, on `nPSU` alone (checker note).

So for finite columns, `V_stack[j, j]` equals the one-column `V[1, 1]`
bit-for-bit on the reference BLAS. `measurements.md` reports `identical()`
TRUE for freqs and means, including 12 `lonely.psu` edge designs. R fact 4
(measured) agrees under remove, adjust, average and certainty, one-stage and
two-stage with FPC, with a lonely stratum, when every column is finite.

### Conditions under which the diagonal does NOT equal the per-cell variance

1. **A live influence column is not finite. Then the stacked diagonal must
   not give the SE of any cell, clean cells included.** The test is one
   `all(is.finite(...))` on the stacked matrix as it enters `.svy_recvar()`,
   after any calibration projection. The damage comes from the stratum
   counts, not the entries: `crossprod()` with a `NaN` or `Inf` column
   leaves the finite block unchanged (measured, R fact 3: 200 seeds, 0
   mismatches). `H_ok` is counted on the whole `k x k` block
   (`R/variance-taylor.R:134`), so one non-finite column drops a stratum for
   every column. Two effects were observed:

   - **One-stage factor.** On its own, a clean column has
     `H_ok_single = H - L`, where `L` is the number of lonely strata under
     `"average"` and 0 under the other options (`:79, :134`). In the stack,
     `H_ok_stack` also loses each stratum that holds a non-finite row of any
     live column. The clean diagonal is scaled by `(H - L) / H_ok_stack`
     against the single result. Measured: 4/3 on a one-stage design; 4, not
     5, under `"average"` with one lonely stratum (V8, V10). When
     `H_ok_stack = 0` the factor is `x / 0`: `Inf` for a nonzero entry, and
     `NaN` for a zero entry, because `(0 * nstrat) / 0` is `NaN` (`:136-143`).
   - **Multistage Inf or NaN.** With an FPC and more than one cluster column,
     each first-stage cluster's sub-call counts its own `nstrat` and
     `nokstrat` (`:172-189`). A non-finite row drops each later-stage stratum
     that holds it. Where that is every stratum in the cluster, `nokstrat` is
     0 there, and every clean column gets `Inf`, or `NaN` where it is zero
     in that cluster. This holds even when stage 1 has `H_ok > 0`. Measured:
     two-stage, 4 strata x 3 PSUs, one `NA` in one row of PSU 1; stack
     diagonal `NaN` and `Inf`, single columns 24.97 and 29.65 (V8, V9).

   Reachable cases on an uncalibrated Taylor design, with `na.rm = FALSE`
   unless stated:
   - `get_means()`, an `NA` in `x` inside a cell. `y_safe` keeps the `NA`
     (`R/analysis-means-helpers.R:72`), `ybar` is `NA` (`:73`), and `u` is
     `NA` on every row, because `0 * NA` is `NA` (`:77`). Every stratum is
     touched, so `H_ok_stack = 0`. This is a supported input
     (`tests/testthat/test-analysis-means.R:255-270`).
   - `get_totals()`, numeric `x`, an `NA` inside a cell: `u` is `NA` on the
     `NA` rows only (`R/analysis-totals-helpers.R:37, :57`).
   - `get_ratios()`, an `NA` in the numerator only: the ratio is `NA`
     (`R/analysis-ratios.R:333`), `z` is `NA` on every row
     (`R/analysis-ratios-helpers.R:123`), and the Taylor total cell keeps it
     on the in-domain rows. An `NA` in the denominator makes the cell `"na"`
     (`R/analysis-ratios.R:317-328`).
   - `get_means()` and `get_totals()`, any `na.rm`: an `Inf` or `-Inf` in
     numeric `x`. `is.na()` does not catch it, so it stays in the cell.
     Measured, uncalibrated, `Inf` in one row of group B, `na.rm = TRUE`:
     clean cell A, means se^2 0.04872819 against `.vcov` diagonal `Inf`;
     totals 31.14489 against 41.52652 (round 2, case b2).

   Cases checked and found NOT to give a stack/single mismatch (round 2):
   - `get_variance()`, `get_covariance()`: an `NA` base weight. If the row
     is in any cell of the call, `.score_variance()` / `.score_covariance()`
     abort with the base R error "missing value where TRUE/FALSE needed"
     (`n_d` is `NA`; `R/analysis-variance-helpers.R:40-44`,
     `R/analysis-covariance-helpers.R:53-60`). If the row is outside every
     cell (NA `x` with `na.rm = TRUE`, NA group value, or outside the
     domain), every live column is `NA` on that row, so the stack diagonal is
     `identical()` to the single results (measured TRUE, cases a1/a2). This
     is an existing defect, not a stack effect: the per-cell SE drops that
     stratum and rescales by `H / H_ok` (SE 0.137 / 0.664 against 0.162 /
     0.610 with the row's weight zeroed).
   - An `Inf` base weight. The class accepts it (`R/core-classes.R:525`).
     `get_freqs()` always aborts with a base R error (`:66` ungrouped,
     `:33` grouped). Grouped `get_means()`, `get_totals()` and `get_ratios()`
     abort, because a cell without the `Inf` row has
     `N_d = sum(Inf * 0) = NaN`. Ungrouped calls run, and every column is
     non-finite on the same row, so stack and single agree (cases b, b2).

   On a calibrated Taylor design, `.apply_caldata_projection()` passes an
   all-`NA` `u` through unchanged (Guard 1, `R/calibration.R:386-388`). Only
   an all-`NA` `u` passes: Guard 1 tests `is.na()`, and `Inf` is not `NA`. A
   `u` with `NA` on some rows, or any `Inf`, reaches `qr.resid()` (`:434`),
   which errors with "NA/NaN/Inf in foreign function call (arg 5)" (V11). So
   on a calibrated design only the `get_means()` `NA` case reaches the
   stack. The `get_totals()` case, the `Inf`-in-`x` case and the
   `get_ratios()` numerator case abort in the projection (in `get_ratios()`,
   at call 2; a denominator `NA` aborts at call 1) before any variance call,
   today and after the change. Measured end to end (round 2, cases c, c2):
   calibrated `get_means(group = g, na.rm = FALSE)` with an `NA` in `x` gives
   clean cell A se^2 0.03740842 against `.vcov` diagonal `Inf`.

   `get_freqs()` has no `NA` source through `x`: `num` and `denom` come from
   logical tests with `is.na()` guards (`R/analysis-freqs.R:343-356`). An
   `NA` base weight aborts its cells (§Gotchas, NA and empty cells).

   Today the per-cell SE uses the one-column result and the `.vcov` uses the
   stack, so the stored `.vcov` diagonal already differs from `se^2` in these
   cases and can be `Inf` or `NaN` for a clean cell. D3 keeps that defect. A
   call whose stack fails the finite test must compute every cell's SE with
   its own one-column `.svy_recvar()` call; the `.vcov` stays as today.

2. **An optimized BLAS.** `dsyrk` in OpenBLAS or MKL may block a `k`-column
   product differently from a one-column one, in the last bit. D3 covers it.

3. **`get_ratios()` scaling.** The per-cell SE is
   `sqrt(max(0, V_z)) / abs(total_x)` (`R/analysis-ratios-helpers.R:128`).
   The joint column is `z / total_x` (`:133`). `sqrt(V(z / T))` and
   `sqrt(V(z)) / abs(T)` are equal in exact arithmetic only. Two exact
   options: stack the unscaled `z` columns for the SE and the scaled ones for
   `.vcov` (two calls per `get_ratios()` call), or accept a difference far
   inside 1e-12.

4. **Replicate route.** The `.svy_rep_vcov()` diagonal is not bit-identical
   to `.svy_rep_var()` (§Formulas). Fix 2 is for the Taylor route only.

5. **No joint form.** Two-phase and nonprob-without-replicates cells return
   no `joint` (`R/analysis-freqs-helpers.R:225-231, :290-296`; the same in
   means, totals and ratios), and `.twophasevar()` returns a scalar
   (`R/variance-twophase.R:25-75, :197, :287`). There is nothing to stack.

6. **`get_variance()` and `get_covariance()` store no `.vcov`.** A stacked
   call can give their SEs. Attaching the matrix would change `vcov()` on
   these results: today `vcov.survey_result()` returns `se^2` on the
   diagonal, `NA` off it, and `surveycore_warning_vcov_incomplete` when
   `p > 1` (`R/analysis-methods-coef-vcov.R:452-480`). The stack must not be
   attached. Their `na.rm = FALSE` override sets `se` to `NaN` after the
   cell returns (`R/analysis-variance.R:296-303`;
   `R/analysis-covariance.R:397-409`). That override must still win over a
   value taken from the stack.

7. **Empty cells.** Cells of kind `"na"` stay out of the stack; their SE is
   the cell's `NA_real_`. With no live cell, no variance call runs today
   (`R/analysis-helpers.R:1223-1225`). Fix 2 must keep that guard.

## Function-specific notes

- `get_freqs()`: three nested loops, so the most cells per call.
- `get_means()`: the only function with a cell-level `df` (issue #326).
  Fix 4 keeps `.degf_taylor()` for calibrated Taylor designs and narrows its
  column subset. For an uncalibrated design the cell `df` is never read
  (`R/analysis-means.R:275, :290`), and the zero-df warning cannot fire:
  `cal_df_reduction` is 0 (`R/calibration.R:467-473`) and `df_design >= 1`
  (`R/analysis-means-helpers.R:99-115`). Skipping the call there changes no
  output and no condition.
- `get_variance()`, `get_covariance()`: no calibration, no joint. The
  analogue of fix 2 gives the SE only, under the finite test of condition 1.
- `get_ratios()`: the analogue of fix 1 passes the cluster matrices through
  `.total_cell()` into `.taylor_total_cell()`, removing up to three builds
  per Taylor cell. Calls 1 and 2 can raise conditions, so they cannot simply
  be dropped:
  - replicate, `na.rm = FALSE`, an `NA` in `x` or `y` in a cell: the
    replicate totals are all `NA`; for a `survey_replicate`,
    `.nonprob_rep_na_warn()` returns `NULL` (`R/analysis-helpers.R:
    1297-1299`) and `.svy_rep_var()` aborts with
    `surveycore_error_all_replicates_na` (`R/variance-replicate.R:29-34`)
    inside call 1 or 2. Nonprob with replicates warns
    `surveycore_warning_domain_replicates_na` (`R/analysis-helpers.R:
    1303-1322`);
  - nonprob without replicates: each `.total_cell()` call warns
    `surveycore_warning_nonprob_srs_fallback` once
    (`R/analysis-totals-helpers.R:358-371`). A cell that reaches calls 2 and
    3 warns three times. An empty cell, or one with an `NA` denominator
    total, warns once, at call 1, and moves on (`R/analysis-ratios.R:327`);
  - Taylor, `lonely.psu = "fail"`, a lonely stratum: call 1 aborts with
    `surveycore_error_lonely_psu` before the zero-denominator check
    (`R/analysis-ratios.R:300-314`).
- `get_ratios()` Taylor route writes `z` into `design@data` once per cell
  (`R/analysis-ratios-helpers.R:125`). Its cost was not measured.

## Gotchas

- **Order of floating-point sums.** `colSums()` and `sum()` add in long
  double; `%*%` and `crossprod()` use BLAS in double. Do not swap one for the
  other. The replicate variance and covariance cells already use `colSums()`
  (`R/analysis-variance-helpers.R:248-249`;
  `R/analysis-covariance-helpers.R:311-313`). Those calls stay.
- **NA and Inf replicate weights are allowed (settled).** The class checks
  `is.numeric()` only (`R/core-classes.R:758-774`); `.validate_repweights()`
  (`R/core-validators.R:290-337`, called at `R/core-constructors.R:1153`)
  checks existence and type; `as_survey_nonprob()` (`:2095-2126`) does not
  call it; the "no NA" text at `:862` is about `rscales`
  (`verification-comprehension.md` §NA replicate weights). Today an `NA` in
  replicate column `r` makes replicate `r`'s total `NA` in every cell of
  `get_freqs()` and `get_means()`, because the products read every row and
  `0 * NA` is `NA` (`R/analysis-freqs-helpers.R:118-119`;
  `R/analysis-means-helpers.R:173, 175`). `.svy_rep_var()` drops that
  replicate, and aborts with `surveycore_error_all_replicates_na` only when
  every replicate is `NA` (`R/variance-replicate.R:27-38`). A
  `survey_nonprob` design warns `surveycore_warning_domain_replicates_na`
  above 5% `NA` replicates and returns an `NA` cell at 100%
  (`R/analysis-helpers.R:1303-1325`).
- **Fix 3 sums in `get_freqs()` are exact only with finite replicate
  weights.** The prototype sums only the cell's rows, for the numerator and
  the shared denominator (`evidence/freqs/proto.R:83, :87`).
  `rep(1, m) %*% rep_mat[idx, ]` equals `num %*% rep_mat` when the dropped
  terms are exact zeros, so when every replicate weight is finite. With an
  `NA` or `Inf` replicate weight outside the cell, the full product is `NA`
  or `NaN` and the subset sum is finite. The cell then keeps a replicate
  that today is dropped, and its SE and conditions change. What keeps fix 3
  exact: use the subset sums only when `all(is.finite(rep_mat))`, checked
  once per call on the hoisted matrix, else the full products (open
  question). The `get_means()` `crossprod()` reads every row, as the two
  current products do, so it gives the same `NA` replicate.
- **`lonely.psu = "fail"` and condition order.** With one stacked call after
  the loop, the abort moves from the first live cell to after the loop. A
  condition raised in the loop after the first live cell is then raised
  before the abort, for example `surveycore_warning_all_na_freqs` for a later
  variable (`R/analysis-freqs.R:305-315`) or
  `surveycore_error_ratio_zero_denominator` in a later cell. If the stacked
  call runs after the small-cell warning, as in
  `evidence/freqs/freqs_p2.R:398-420`, that warning also comes first. The
  abort class and message do not change: both calls abort on `nPSU` alone.
- **Option read per cell.** `getOption("survey.lonely.psu", "remove")` is
  read in every cell and again in `.joint_vcov()` (list under §Reference
  mapping). One read per call gives the same value, because nothing in the
  call sets the option.
- **Per-cell warnings on the nonprob-SRS route.** Five dispatchers in scope
  warn `surveycore_warning_nonprob_srs_fallback` once per cell call:
  `R/analysis-freqs-helpers.R:328`, `R/analysis-means-helpers.R:388`,
  `R/analysis-totals-helpers.R:370` (also reached by `get_ratios()`),
  `R/analysis-variance-helpers.R:515`, `R/analysis-covariance-helpers.R:572`.
  The class also comes from `R/analysis-corr-helpers.R:43` and
  `R/glm.R:341`, out of scope. The 104 warnings of this class in the
  369-warning baseline (`CLAUDE.md`) come from all seven sources. A change
  that calls a dispatcher a different number of times changes that count.
- **Cell-level df (issue #326).** The rows passed to `.degf_taylor()` must
  stay `domain > 0`. Only the columns may narrow, to `c(vars$ids[1L],
  vars$strata)`. With no `ids` and no `strata` that vector is `NULL`, and
  `.degf_taylor()` returns `nrow(data) - 1L` (`R/analysis-helpers.R:
  376-378`). `nrow(df[rows, NULL, drop = FALSE])` equals `sum(rows)` for a
  logical `rows` with no `NA`, all-`FALSE` included (measured, R fact 1);
  with an `NA` in `rows` it does not. A live Taylor mean cell has no `NA` in
  `domain`: an `NA` makes `n_d` `NA`, and the test at
  `R/analysis-means-helpers.R:60` errors first.
- **`sqrt(max(0, v))` against `sqrt(pmax(0, diag(V)))`.** The cells use
  `max()`; a stacked SE uses `pmax()`. `identical()` is TRUE for `NaN` and
  for `NA` (measured, R fact 2). This covers the all-lonely `"average"` case.
- **NA and empty cells.** An empty cell returns before any variance call on
  every route (for example `R/analysis-freqs-helpers.R:33-42`). The class
  allows an `NA` base weight (`R/core-classes.R:524-536`). By route:
  - Taylor and replicate freq, mean, total and ratio cells, the routes with
    a joint element: `N_d = sum(w * domain)` is `NA`, so
    `n_g == 0L || N_d <= 0` fails with a base R error when `n_g > 0`
    (`R/analysis-freqs-helpers.R:30-33`). No live cell carries the `NA`.
  - Calibrated freq cell: fails earlier, at `if (N_d > 0)` (`:257`).
  - Calibrated mean and total cells test only `n_d == 0L` and read in-cell
    weights (`R/analysis-means-helpers.R:309, 319-322`;
    `R/analysis-totals-helpers.R:283, 293-303`). An `NA` weight in the cell
    gives a live cell with an `NA` estimate, no error, and no joint element.
  - Variance and covariance cells: `active` excludes the row
    (`R/analysis-variance-helpers.R:40-44`), so an `NA` weight outside the
    cell leaves it live with an `NA` influence row (condition 1).
- **Single-level groups.** One combo, one warning before the loop
  (`R/analysis-freqs.R:184-213`). Zero combos (every group value `NA` with
  `na.rm = TRUE`) give zero cells, and `.attach_joint_vcov()` returns early
  (`R/analysis-helpers.R:1270-1272`). A build moved to the top of the call
  then runs where it did not before; it raises no condition.
- **Internal weight column.** The weight may be `"..surveycore_wt.."`
  (`R/utils.R:353`; `R/methods-conversion.R:866, :1084`). Hoisted code reads
  `design@variables$weights`. The `.degf_taylor()` subset needs no weight.
- **Domain-filtered designs.** The cells build the matrices on all rows of
  `design@data`, not on the domain (`R/analysis-freqs-helpers.R:25, :52`),
  so a once-per-call build on all rows is the same object. Domain designs
  were not profiled (`measurements.md` §Not run).
- **Second callers.** `.mean_cell()` serves `get_quantiles()`
  (`R/analysis-quantiles-helpers.R:154`). `.total_cell()` serves
  `get_ratios()`. New arguments need defaults that keep the old behaviour.
- **Stack cost grows with `k^2`.** The stratum sum runs `sum()` once per
  entry of a `k x k` matrix (`R/variance-taylor.R:136-141`). `.joint_vcov()`
  already pays this. For a large `k`, as in a grouped `get_covariance()`,
  measure before claiming a gain.
- **Stale comments.** `R/analysis-means-helpers.R:44-45` and
  `R/analysis-totals-helpers.R:19-20`: the nonprob SRS route goes to the
  calibrated cell, not the Taylor cell. `R/analysis-totals-helpers.R:12-13`:
  `.quantile_woodruff_cell()` uses `.mean_cell()`. `R/analysis-helpers.R:
  1208-1210`: the diagonal is not each `se^2` in condition 1, and on the
  replicate route it is equal in exact arithmetic only.

## Reference mapping

- `.svy_onestrat()` `R/variance-taylor.R:21-89`, `.svy_onestage()`
  `:93-144`, `.svy_multistage()` `:149-194` (vendored from `survey`) →
  column separability for finite columns, so the Taylor SE of fix 2 may come
  from the stack diagonal. Confirmed by R fact 4. No change to these
  functions is needed for fixes 1 to 4.
- `.svy_onestage()` `:133-143` (`H_ok`, `H / H_ok`) → the one-stage effect
  of condition 1. `.svy_multistage()` `:172-190` (per-cluster recursion,
  only with `popmat` and more than one cluster column) → the multistage
  effect.
- `crossprod()` with a non-finite column (R fact 3) → the finite entries do
  not move, so the stratum counts are the only mechanism of condition 1 on
  the reference BLAS.
- `.apply_caldata_projection()` `R/calibration.R:380-437` → Guard 1
  (`:386-388`) passes an all-`NA` `u`; `qr.resid()` (`:434`) aborts on a
  partial `NA`. This decides which condition 1 cases reach a calibrated
  stack.
- `.joint_vcov()` `R/analysis-helpers.R:1215-1254` → the stacked call fix 2
  reuses. Its rebuild at `:1229` is the second build fix 1 removes. Its
  `"na"` and `NULL` handling defines which cells enter the stack.
- `vcov.survey_result()` fallback `R/analysis-methods-coef-vcov.R:452-480`
  → why `get_variance()` and `get_covariance()` stay without `.vcov`.
- `.svy_rep_var()` / `.svy_rep_vcov()` `R/variance-replicate.R:26-74` →
  the replicate SE stays per cell; only the matrix conversion moves.
- `.build_cluster_matrices()` `R/utils.R:1110-1250` → a pure function of the
  design columns and `@variables`, so one build per call is exact.
- `.degf_taylor()` `R/analysis-helpers.R:349-380` → the column subset of
  fix 4.
- `.maybe_apply_calibration()` `R/calibration.R:449-455` → stays per cell.
  The joint value is the projected column, so the diagonal still matches.
- Two-phase engine `R/variance-twophase.R` → much of each cell's work
  depends only on the design and `subset`, so it is exact to hoist, but each
  hoist needs new engine arguments. In the cell: `.compute_phase2_probs()`
  (`:451-472`) and `cal_wt` (`R/analysis-freqs-helpers.R:183-184`).
  `.twophase_phase1_var()` (`:94-201`): `strata_all`, `psu_all`,
  `nPSUfull_by_strat`, `usu_ph2`. `.twophase_phase2_var()` (`:211-288`): the
  phase 2 matrices and `.twophase_same_scale()`. `.twophase_full_var()`
  (`:352-432`, `method = "full"`): `strata1`, `psu1`, `n1_h`, `units2`,
  `n2_h`, and a second `.compute_phase2_probs()` at `:377`.
- Option reads: §Cell-independent work, the two-phase cells (`:214`, `:271`,
  `:239`, `:381`, `:446`), and `R/analysis-helpers.R:1235`.
- `evidence/freqs/proto.R:24-51, :70-89` and
  `evidence/freqs/freqs_p2.R:362-420` → fixes 2 and 3 in freqs: cells keep
  the calibration step and return the influence column; one stacked call;
  SE set for live cells only; subset sums memoised per denominator.
- `evidence/means/patches.R:30-102` → fixes 1 to 4 in means: optional
  `mats` and `rep_mat` arguments, the one `crossprod()` call, and the
  calibrated-only `.degf_taylor()`.

## Assumptions

- No code in the call changes `survey.lonely.psu`. One read per call is
  then the same as one read per cell.
- `design@data` design columns do not change during the call. True today:
  the only writes add columns with internal names
  (`R/analysis-totals.R:280`; `R/analysis-ratios-helpers.R:125`).
- The tests run on R's reference BLAS. `identical()` held there; the 1e-12
  tolerance (D3) covers an optimized BLAS.
- "Results do not change" includes conditions (class, count and order) and
  designs with `NA` or `Inf` base or replicate weights. The request says
  neither. The 369-warning baseline in `CLAUDE.md` implies the first; the
  class allowing such weights makes the finite tests part of the contract.
- Two-phase and nonprob routes were not profiled. Leaving them as they are
  meets the request. The two-phase hoists are exact but have no measured
  gain.

## Open questions

- **Fix 2 fallback form.** Condition 1 settles that a stack failing the
  finite test gives no SE. Exact option: then compute each SE with its own
  `.svy_recvar()` call on the shared matrices, and keep the stacked call for
  `.vcov`. Whether to also fix the existing `.vcov` / `se^2` mismatch is a
  separate decision. D3 says to keep it.
- **Fix 3 in `get_freqs()` with a non-finite replicate weight.** (a) Subset
  sums only when `all(is.finite(rep_mat))`, checked once per call, else the
  full products; or (b) always the full products, keeping only the hoisted
  conversion and the shared denominator. Both are exact. (a) keeps the
  measured gain on clean designs; (b) is simpler.
- **`get_ratios()` fix 2.** Two stacked calls (exact) or one (last-bit SE
  differences inside 1e-12)? The request says "once per call"; the exact
  option needs two.
- **`lonely.psu = "fail"` order.** Accept the moved abort, or place the
  stacked call where the first per-cell call ran? Placing it before the
  small-cell warning keeps that order. It cannot keep the order of a
  condition raised in a later cell.
- **Calls 1 and 2 in `get_ratios()`.** Keep them (fix 1 and fix 3 only), or
  drop their SE work on the routes where they raise nothing? Not measured.
- **Two-phase hoists.** In scope or not? Exact, but each needs new arguments
  in `R/variance-twophase.R`, and the route was not profiled.
- **Existing defects found, outside this change.** Round 2 measured three
  (condition 1): an `NA` base weight in a cell gives a base R error in
  `get_variance()` / `get_covariance()`; an `NA` base weight outside every
  cell silently drops its stratum from the SE; an `Inf` base weight is
  accepted and then gives base R errors in most calls. The change must keep
  today's behaviour for each. Whether to file issues is the user's call.
- **Domain-filtered designs in tests.** `filter()` is in surveytidy, which
  is not installed. Tester needs a way to set the domain marker column
  (`R/analysis-helpers.R:424-432`) without it.

## Verdict

Fixes 1 to 4 are exact on the reference BLAS, with two guards. Fix 2 needs a
per-call finite test on the stack (condition 1). Fix 3's subset sums in
`get_freqs()` need a per-call finite test on the replicate matrix, or the
full products in their place.

| Function | Fix 1 (matrices once) | Fix 2 (one stacked Taylor call) | Fix 3 (replicate matrix once) | Fix 4 (df) |
|---|---|---|---|---|
| `get_freqs()` | yes: `:52` and `:1229` | yes, with the finite test (no measured case reaches it; an `Inf` weight aborts first); abort order changes under `"fail"` | yes `:117`; denominator once per variable and combo `:118`; subset sums only with finite replicate weights | n/a |
| `get_means()` | yes: `:80` and `:1229` | yes, with the finite test (`na.rm = FALSE`, calibrated or not) | conversion only `:172`; `:173, :175` stay per cell, merged into one `crossprod()` | yes `:99`; calibrated only, two columns |
| `get_totals()` | yes: `:60` and `:1229` | yes, with the finite test (reached on uncalibrated designs only) | yes `:138`; no shared denominator | n/a |
| `get_variance()` | yes `:158` | SE only, with the finite test (no measured mismatch case); no `.vcov`; override after | yes `:238` | n/a |
| `get_covariance()` | yes `:227` | SE only, with the finite test (no measured mismatch case); no `.vcov`; override after | yes `:303` | n/a |
| `get_ratios()` | yes, through `.total_cell()`; up to 3 builds per cell today | yes, with the finite test (reached on uncalibrated designs only); exact needs two stacked calls | yes; up to 3 conversions per cell today | n/a |
