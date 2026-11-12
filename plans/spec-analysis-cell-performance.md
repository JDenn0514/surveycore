# Spec — analysis-cell-performance

**Status**: DRAFT
**Spec version**: 1.3 (Stage 3r: `spec-review.md` pass 1 resolved, with D12
and D13; delta-review fixes applied)
**Target version**: 1.2.0.9000
**PR range**: set by the implementation plan, inside the constraints of
§II.6
**Date**: 2026-11-10
**Base commit**: `develop` at `0c0a987`. Every line reference below is in
that tree. If the first branch of this work is cut from a later `develop`
commit, that commit is the base commit, and the line numbers may shift.

---

## Document purpose

This document is the source of truth for the change. It states what six
analysis functions must do after the change, what must not move, and what
"done" means. A decision from `decisions.md` is cited by its number (D1 to
D13). D1 to D7, D9, D10, D12 and D13 are settled. Items marked
**[D8 default]**, and D11, were not put to the user, and the user may reopen
them.

---

## I. Scope

### I.1 Terms

| Term | Meaning |
|---|---|
| Cell | One level, one group, or one level-by-group pair. One cell gives one result row. |
| Taylor route | The design is a `survey_taylor`. |
| Calibrated Taylor design | A `survey_taylor` whose `@calibration` holds at least one element. |
| Replicate route | The design is a `survey_replicate`, or a `survey_nonprob` with replicate weights (`!is.null(design@variables$repweights)`). |
| Nonprob SRS route | A `survey_nonprob` without replicate weights. Its cells warn `surveycore_warning_nonprob_srs_fallback` and use the HT cell functions (`.calibrated_*_cell()`). |
| Two-phase route | The design is a `survey_twophase`. |
| Influence column | The length-`n` vector a Taylor cell passes to `.svy_recvar()`, after `.maybe_apply_calibration()` where the function applies it (not `get_variance()` or `get_covariance()`). `n` is `nrow(design@data)`. §I.1a lists the column per function. |
| Live cell | A Taylor cell that reaches `.svy_recvar()` on the base commit. Per function, §IV to §IX define it. |
| Stacked call | One `.svy_recvar()` call on a matrix whose columns are the influence columns of several live cells. |
| Block | A run of at most `TAYLOR_SE_BLOCK` consecutive live columns that one stacked call takes (D10, D12). |
| Finite check | `all(is.finite(vals))` on the live influence columns. Once per call in `get_freqs()`, `get_means()` and `get_totals()` (D7); once per block in `get_ratios()` (D10), `get_variance()` and `get_covariance()` (D12). |
| Call context | The list `.cell_context()` returns once per call (§II.2). |

### I.1a Influence column per function (unchanged)

From `comprehension.md` §Influence column per function. This change does
not alter any of these columns.

| Function | Column passed to `.svy_recvar()` | Calibration projection | Source |
|---|---|---|---|
| `get_freqs()` | `w_i (num_i - p denom_i) / N_d` | yes | `R/analysis-freqs-helpers.R:49, 55-56` |
| `get_means()` | `w_i d_i (y_i - ybar) / N_d` | yes | `R/analysis-means-helpers.R:77, 83-84` |
| `get_totals()` | `w_i d_i y_i` | yes | `R/analysis-totals-helpers.R:57, 64-65` |
| `get_ratios()` | the total column of `z_i = d_i (y_i - R x_i)`; SE divided by `abs(total_x)` | yes (inside the total cell) | `R/analysis-ratios-helpers.R:123-129` |
| `get_variance()` | `w_i a_i (z_i - v_hat) / W`, `z_i = kish (y_i - ybar)^2` | no | `R/analysis-variance-helpers.R:156, 161` |
| `get_covariance()` | `w_i a_i (z_i - c_hat) / W`, `z_i = kish dx_i dy_i` | no | `R/analysis-covariance-helpers.R:225, 230` |

Skipping a cell's own variance call does not change the influence column or
any other cell field. It only skips that one `.svy_recvar()` call and sets
`se = NA_real_`.

### I.2 In

Six exported functions do the work that is the same for every cell once
per call, not once per cell (D1). The method does not change. No number in
any result changes beyond D3's last-bit allowance.

| Function | Taylor route | Replicate route |
|---|---|---|
| `get_freqs()` | Build the cluster, strata and FPC matrices once per call. One stacked call gives every live cell's SE and the `.vcov` matrix. | Convert the replicate columns once per call. Compute the replicate denominator totals once per variable and group combination. Use subset sums only when every replicate weight is finite (D4). |
| `get_means()` | Matrices once. One stacked call gives the SEs and `.vcov`. Compute `.degf_taylor()` only for a calibrated Taylor design, on two columns. | Convert once. One `crossprod()` per cell replaces the two matrix products. |
| `get_totals()` | Matrices once. One stacked call gives the SEs and `.vcov`. | Convert once. |
| `get_variance()` | Matrices once. One stacked call per block, run inside the cell loop, gives the SEs (D12). No `.vcov` is stored. | Convert once. |
| `get_covariance()` | As `get_variance()`. | Convert once. |
| `get_ratios()` | Matrices once, shared by all three per-cell calls and the joint step. Stacked calls on the unscaled columns, in blocks, give the SEs; one stacked call on the scaled columns gives `.vcov` (D5, D10). | Convert once, shared by all three per-cell calls. |

### I.3 Out

- The single `rowsum()` pass that computes every replicate cell at once
  (D2). It needs its own spec.
- Any hoist on the two-phase route **[D8 default]**. Each needs new
  arguments in `R/variance-twophase.R`, and the route was not profiled.
  Two-phase results must not change.
- The nonprob SRS route. Its dispatchers still warn once per cell call.
- Removal of the SE work in `get_ratios()` calls 1 and 2 **[D8 default]**.
  §IX states why.
- A fix to the stored `.vcov` diagonal where it differs from `se^2` (D3,
  D7). §X.2 keeps it.
- Three existing defects found during comprehension **[D8 default]**: an `NA`
  base weight inside a cell of `get_variance()` / `get_covariance()`, an
  `NA` base weight outside every cell, and an `Inf` base weight. §X.3 keeps
  today's behaviour for each.
- Any edit to `R/variance-taylor.R`, `R/variance-replicate.R`,
  `R/variance-twophase.R`, `R/calibration.R`, `R/utils.R`, or the
  `get_quantiles()` files. `.build_cluster_matrices()` also has a caller in
  `R/analysis-corr-latent.R:1385`, which this change leaves alone.
- Degrees of freedom and the interval method. They do not change. Every
  result uses `df = Inf`, except a calibrated Taylor `get_means()` result,
  which uses the per-cell `df` of §V (its df table).
- New exported functions, arguments, classes, or condition classes. There
  are none.

### I.4 Design class support matrix

| Class or route | What changes | What must hold |
|---|---|---|
| `survey_taylor`, uncalibrated | Matrices once; stacked SE; `get_means()` skips `.degf_taylor()` | Every output equal to the base commit |
| `survey_taylor`, calibrated | Matrices once; stacked SE on the projected columns; `get_means()` narrows the `.degf_taylor()` columns | Every output equal, the `df` column included |
| `survey_replicate` | Replicate matrix once; `get_freqs()` shared denominator and guarded subset sums; `get_means()` one `crossprod()` | Every output equal; `surveycore_error_all_replicates_na` raised in the same calls |
| `survey_nonprob` with replicate weights | Same as `survey_replicate` | Every output equal; `surveycore_warning_domain_replicates_na` raised the same number of times |
| `survey_nonprob` without replicate weights | Nothing. The dispatchers take the new arguments and do not pass them on. | Every output equal; `surveycore_warning_nonprob_srs_fallback` raised the same number of times |
| `survey_twophase` | Nothing. As above. | Every output equal |
| Any class above with the domain marker column set | As for the class | Every output equal |

### I.5 Decisions carried

| Decision | Where it lands |
|---|---|
| D1 — six functions | §I.2, §IV to §IX |
| D2 — single `rowsum()` pass deferred | §I.3 |
| D3 — results checked against the old path; `identical()` is evidence only | §XI gate 1, §XV |
| D4 — `get_freqs()` replicate subset sums only when `all(is.finite(rep_mat))`, checked once per call | §III.5, §IV |
| D5 — `get_ratios()` Taylor uses stacked calls for the SEs and one for `.vcov` | §IX |
| D6 — the lonely-PSU abort may move after the cell loop | §III.4, §X.1 |
| D7 — one finite check per call, or one per block where D10 and D12 apply; on failure each SE comes from its own call; the stacked call still gives `.vcov` | §III.3 |
| D8 — calls 1 and 2 keep their SE work; two-phase out; existing defects kept | §I.3, §IX, §X.3 |
| D9 — D6 also covers any condition a later cell raises, errors included | §III.4, §X.1 |
| D10 — Taylor SE calls run in blocks for `get_variance()`, `get_covariance()` and the `get_ratios()` SE step | §II.2, §III.3, §IX |
| D11 — how domain-restricted designs are built for validation (planner default; the user may reopen) | No production rule; §XIV notes the marker contract it relies on |
| D12 — `get_variance()` and `get_covariance()` run the SE step per block inside the cell loop, with a finite check per block; the block size is measured | §II.2, §III.3, §III.4, §VII, §VIII, §XI gate 13, §XII.4, §XII.5 |
| D13 — the validation baseline captured on the base commit stays after the PR series | No production rule; §XIII states the lifecycle line for the changelog |

---

## II. Architecture

### II.1 Write surface

These files change. No other production file changes. Test, fixture and
`data-raw/` files are set by the test plan.

- `R/analysis-helpers.R`
- `R/analysis-freqs.R`
- `R/analysis-freqs-helpers.R`
- `R/analysis-means.R`
- `R/analysis-means-helpers.R`
- `R/analysis-totals.R`
- `R/analysis-totals-helpers.R`
- `R/analysis-variance.R`
- `R/analysis-variance-helpers.R`
- `R/analysis-covariance.R`
- `R/analysis-covariance-helpers.R`
- `R/analysis-ratios.R`
- `R/analysis-ratios-helpers.R`
- `NEWS.md`
- One file under `changelog/`, named after the branch that carries the
  `NEWS.md` entry.

No roxygen block of an exported function changes, so `man/` and
`NAMESPACE` do not change.

### II.2 Added

In `R/analysis-helpers.R`:

```r
TAYLOR_SE_BLOCK <- 64L

.cell_context <- function(design, check_rep_finite = FALSE)

.taylor_cell_se <- function(
  vals,
  mats,
  lonely.psu = getOption("survey.lonely.psu", "remove"),
  v = NULL
)
```

`TAYLOR_SE_BLOCK` is internal and not exported. Its starting value is 64
(D10). The §XII.5 measurement fixes the final value at 16, 32 or 64 (D12).
The same constant serves `get_variance()`, `get_covariance()` and the
`get_ratios()` SE step.

`.cell_context()` contract (§II.5 step 2 calls it once per call):

| Element | Value |
|---|---|
| `taylor` | `S7::S7_inherits(design, survey_taylor)` |
| `replicate` | `S7::S7_inherits(design, survey_replicate) \|\| (S7::S7_inherits(design, survey_nonprob) && !is.null(design@variables$repweights))` |
| `mats` | `.build_cluster_matrices(design@data, design@variables)` when `taylor`, else `NULL` |
| `rep_mat` | `as.matrix(design@data[, design@variables$repweights, drop = FALSE])` when `replicate`, else `NULL` |
| `rep_finite` | `all(is.finite(rep_mat))` when `replicate` and `check_rep_finite`, else `FALSE` |
| `lonely.psu` | `getOption("survey.lonely.psu", "remove")` |

Only `get_freqs()` passes `check_rep_finite = TRUE`. The other functions do
not use `rep_finite`, so they skip its pass over `rep_mat`.

§III.3 gives the contract of `.taylor_cell_se()`. It runs on the Taylor
route only.

Why `R/analysis-helpers.R`: it is the shared file of the analysis family and
already holds `.joint_vcov()` and `.attach_joint_vcov()`, which the new
helpers work beside. `code-style.md` puts a helper used by two or more files
in a shared file. Both new helpers are used by all six function files.

### II.3 Modified (internal signatures)

Two rules govern defaults:

- **Cell functions with more than one caller keep defaults** that give the
  base-commit behaviour: `.mean_cell()` (callers: `get_means()`,
  `get_quantiles()`), `.total_cell()` (callers: `get_totals()`,
  `get_ratios()`), and the cell functions under them. A caller that passes
  none of the new arguments gets the base-commit result.
- **Cell functions with one caller get required arguments**, with no
  default. The one caller always passes the call context, so a default
  would be a branch no call can reach. The cell no longer builds `mats` or
  `rep_mat` itself.

```r
.joint_vcov(design, joint, mats = NULL)
.attach_joint_vcov(result, design, joint, v = NULL)

# One caller each: required arguments
.taylor_freq_cell(design, num, denom, mats)
.replicate_freq_cell(design, num, denom, rep_mat, rep_finite, rep_N_d)
.freq_cell(design, num, denom, ctx, rep_N_d)

.taylor_variance_cell(design, y_col, domain, mats)
.replicate_variance_cell(design, y_col, domain, rep_mat)
.variance_cell(design, y_col, domain, ctx)

.covariance_pair_taylor(design, x_col, y_col, domain, na.rm, mats)
.covariance_pair_replicate(design, x_col, y_col, domain, na.rm, rep_mat)
.covariance_pair_result(design, x_col, y_col, domain, na.rm, ctx)

.replicate_ratio_cell(
  design, y_vec, x_vec, domain, ratio_est, total_x,
  rep_mat
)
.delta_ratio_cell(
  design, y_vec, x_vec, domain, ratio_est, total_x, tmp_col,
  mats, compute_se
)

# More than one caller: defaults keep base-commit behaviour
.taylor_mean_cell(design, y_col, domain, mats = NULL, compute_se = TRUE)
.replicate_mean_cell(design, y_col, domain, rep_mat = NULL)
.mean_cell(
  design, y_col, domain,
  mats = NULL, compute_se = TRUE, rep_mat = NULL
)

.taylor_total_cell(design, y_col, domain, mats = NULL, compute_se = TRUE)
.replicate_total_cell(design, y_col, domain, rep_mat = NULL)
.total_cell(
  design, y_col, domain,
  mats = NULL, compute_se = TRUE, rep_mat = NULL
)
```

In each signature, every argument before the new ones keeps its current
name and position. Two-phase and nonprob SRS cell functions do not change.

The one-caller Taylor cells (`.taylor_freq_cell()`,
`.taylor_variance_cell()`, `.covariance_pair_taylor()`) always skip their
own `.svy_recvar()` call, because their caller always takes the SE from the
SE step. They have no `compute_se` argument. `.delta_ratio_cell()` keeps
`compute_se`, with no default: `get_ratios()` passes `FALSE` on the Taylor
route and `TRUE` on the nonprob SRS and two-phase routes, where the SE stays
per cell.

Argument rules:

| Argument | Rule |
|---|---|
| `mats` | A list: the value `.build_cluster_matrices(design@data, design@variables)` returns, from the call context. On a function with a `NULL` default, `NULL` builds the matrices inside the cell, as today. |
| `compute_se` | `TRUE` runs the cell's own `.svy_recvar()` call, as today. `FALSE` skips that call and returns `se = NA_real_` and the influence column. Everything else in the cell still runs. |
| `rep_mat` | A matrix: `ctx$rep_mat`. On a function with a `NULL` default, `NULL` converts the replicate columns inside the cell, as today. |
| `rep_finite` | `ctx$rep_finite`. `FALSE` uses the full products, as today. `TRUE` uses subset sums (§III.5). |
| `rep_N_d` | The replicate denominator totals of §III.5, computed once per variable and group combination. `NULL` on routes other than the replicate route. |
| `ctx` | The call context of §II.2. |

Consistency of the `get_freqs()` replicate arguments: `rep_finite = TRUE` is
valid only with the `rep_mat` it was computed from, and `rep_N_d` must use
the same form (subset sum or full product) as the numerator. All three come
from one call context and the one combination step of §III.5, so the cell
adds no check of its own.

Dispatcher rules (`.freq_cell()`, `.mean_cell()`, `.total_cell()`,
`.variance_cell()`, `.covariance_pair_result()`):

- `mats` (or `ctx$mats`) and `compute_se` go to the Taylor cell only.
- `rep_mat`, `rep_finite` and `rep_N_d` (or the `ctx` fields) go to the
  replicate cell only, on both replicate classes.
- The nonprob SRS cell and the two-phase cell receive none of them. The
  nonprob SRS warning stays where it is and fires once per dispatcher call.

Returned fields:

| Cell | New field when it skips its own variance call |
|---|---|
| `.taylor_freq_cell()`, `.taylor_mean_cell()`, `.taylor_total_cell()` | None. The influence column is already `joint$value` (`.joint_infl()`, `R/analysis-helpers.R:1192-1194`). |
| `.taylor_variance_cell()`, `.covariance_pair_taylor()` | `infl`: the influence column, an unnamed numeric vector of length `n`. A cell that returns early has no `infl`. |
| `.delta_ratio_cell()` (Taylor, `compute_se = FALSE`) | `infl`: the unscaled `z` influence column, after projection, unnamed. `joint` keeps its kind and its scaled `est`, as today, but its `value` is `NULL`. The SE step of `get_ratios()` fills `value` (§III.3). |

Where `infl` lives:

- `get_variance()` and `get_covariance()`: the caller moves `infl` into the
  flush buffer of §III.3 at once, and removes it from the cell result
  (`cell$infl <- NULL`) before it stores the result. The stores are the
  `acc_*` vectors of `get_variance()`, and `pair_results_this` and
  `all_pair_results` of `get_covariance()`. So no store ever holds an
  influence column, and the two functions never hold more than one block
  of columns, as §III.3 requires.
- `get_ratios()`: `infl` stays in the stored cell result until the SE step,
  which replaces it with the scaled `joint$value` (§III.3). At no time does
  a cell hold both columns.

### II.4 Class changes

None.

### II.5 Step order inside each of the six functions

1. Collection dispatch, argument checks, group resolution, the
   single-level warning, group combinations, metadata. Unchanged, same
   order.
2. **Call context.** `ctx <- .cell_context(design, check_rep_finite =
   <TRUE in get_freqs(), FALSE elsewhere>)`, immediately before the first
   cell loop. For `get_totals()` with a categorical `x`, it runs after the
   indicator columns are written.
3. **The cell loop.** Taylor cells get `ctx$mats` and skip their own
   variance call (in `get_ratios()`, call 3 only). Replicate cells get
   `ctx$rep_mat`. In `get_variance()` and `get_covariance()` the Taylor SE
   step also runs here, once per full block (§III.3).
4. **Taylor route only. Immediately after the cell loop, before any
   post-loop condition**, the SE step of §III.3 runs (in `get_variance()`
   and `get_covariance()`, the flush of the last partial block). Post-loop
   conditions are the small-cell warning, the per-variable warnings of
   `get_variance()`, and the per-pair warnings of `get_covariance()`. On the
   replicate, two-phase and nonprob SRS routes step 4 does not run: each SE
   is the one the cell computed, as today (on the replicate route,
   `.svy_rep_var()` per cell).
5. Post-loop warnings, variance columns, result assembly.
   - Taylor route: `.vcov` is attached from the matrix computed in step 4,
     with `.attach_joint_vcov(result, design, acc_joint, v = v_all)`. No
     second joint computation runs.
   - Replicate route: `.vcov` is attached as today, with
     `.attach_joint_vcov(result, design, acc_joint)` and `v = NULL`, so
     `.svy_rep_vcov()` gives it.
   - Two-phase and nonprob SRS routes: nothing changes; no `.vcov` is
     stored, as today.

`.build_cluster_matrices()` raises no condition, so building it in step 2
raises nothing new, also in a call that ends with zero cells.

Zero cells (for example every group value `NA` with `na.rm = TRUE`): step 4
does not run, because there is no live cell. `.attach_joint_vcov()` keeps
its early return for a zero-row result (`R/analysis-helpers.R:1270-1272`),
and that return comes before any read of `v`.

### II.6 PR constraints

The implementation plan sets the PR split. Any split must keep this order:

1. The first PR changes no file under `R/`. It captures the base-commit
   outputs that every later PR is checked against (gate 1).
2. `.cell_context()`, `.taylor_cell_se()`, `TAYLOR_SE_BLOCK` and the new
   arguments of `.joint_vcov()` and `.attach_joint_vcov()` land in the same
   PR as their first user, or earlier.
3. The §XII.5 block-size measurement runs after all three functions that
   use the blocks (`get_variance()`, `get_covariance()` and `get_ratios()`)
   use them. Its result is committed before the §XII.1 to §XII.4 speed run.
4. `NEWS.md`, the changelog file and the §XII table land last, in one PR,
   because the `NEWS.md` wording depends on the §XII table (§XIII).
5. No two open PRs change the same file of §II.1.

### II.7 Call sites of the modified helpers

| Helper | Call sites |
|---|---|
| `.joint_vcov()` | `.attach_joint_vcov()` (`R/analysis-helpers.R:1273`); the new SE step in `get_freqs()`, `get_means()`, `get_totals()`, `get_ratios()` |
| `.attach_joint_vcov()` | `R/analysis-freqs.R:498`, `R/analysis-means.R:348`, `R/analysis-totals.R:438`, `R/analysis-ratios.R:443` |
| `.freq_cell()` | `R/analysis-freqs.R:358` |
| `.mean_cell()` | `R/analysis-means.R:235`, `R/analysis-quantiles-helpers.R:154` (unchanged call) |
| `.total_cell()` | `R/analysis-totals.R:317`; `R/analysis-ratios.R:296` (call 1), `:331` (call 2); `R/analysis-ratios-helpers.R:126` (inside call 3) |
| `.variance_cell()` | `R/analysis-variance.R:291` |
| `.covariance_pair_result()` | `R/analysis-covariance.R:386` |
| `.replicate_ratio_cell()` | `R/analysis-ratios.R:338` |
| `.delta_ratio_cell()` | `R/analysis-ratios.R:347` |
| Route cells (`.taylor_*_cell()`, `.replicate_*_cell()`, `.covariance_pair_taylor()`, `.covariance_pair_replicate()`) | Their dispatcher only |

---

## III. Shared behaviour rules

### III.1 Cluster matrices once per call

On the Taylor route each function builds the cluster matrices exactly once
per call, through `.cell_context()`. It passes `ctx$mats` to every cell and
to `.joint_vcov()`. This includes `get_ratios()`, which today builds the
matrices up to three times per cell through `.total_cell()`, plus once in
`.joint_vcov()`.

The weight column comes from `design@variables$weights` and may be the
internal `"..surveycore_wt.."`. The matrices are built on all rows of
`design@data`, not on the domain, as the cells do today.

### III.2 Replicate matrix once per call

On the replicate route each function converts the replicate columns
exactly once per call, through `.cell_context()`, and passes `ctx$rep_mat`
to every cell. In `get_ratios()` the one matrix serves calls 1, 2 and 3.

The per-cell arithmetic stays as it is, except where this section and
§III.5 say otherwise:

- `get_totals()`: one product per cell, `(y_safe * domain) %*% rep_mat`.
- `get_variance()`, `get_covariance()`: `rep_mat[active, , drop = FALSE]`
  and the `colSums()` calls stay per cell.
- `get_ratios()`: the two products in `.replicate_ratio_cell()` stay.
- `get_means()`: the two products become one
  `crossprod(rep_mat, cbind(domain, y_safe * domain))`. Column 1 is
  `rep_N_d`, column 2 is `rep_Y`. Why the outputs do not change:
  - R's default `matprod` checks both operands for `NaN` and `Inf`. When it
    finds one, it runs the whole product in its internal long-double loop
    instead of BLAS.
  - With a finite `rep_mat` and a finite `y_safe * domain`, both forms run
    on BLAS, and the prototype measured them `identical()` (§XV).
  - With an `NA` or `Inf` in `rep_mat`, both old products and the merged
    product take the internal loop, which adds each column in the same row
    order. The same `NA` replicate results as today.
  - With an `NA` or `Inf` in `y_safe * domain` (an `NA` in `y` under
    `na.rm = FALSE`, or an `Inf` in `y`) and a finite `rep_mat`, today's
    `domain %*% rep_mat` stays on BLAS, but the merged call takes the
    internal loop. The last bit of `rep_N_d` can then change. The outputs do
    not: `rep_Y` is non-finite for every replicate, so every replicate
    estimate is `NA`, `NaN` or `Inf` whatever `rep_N_d` holds. `rep_N_d` is
    not returned.
  §XV has no measurement for this last input; it is reasoned from the
  matprod rule.

Never replace a BLAS product (`%*%`, `crossprod()`) with `colSums()` or
`sum()`, or the reverse. `colSums()` and `sum()` add in long double; the BLAS
products add in double. The swap moves the last bit.

### III.3 Taylor SE from stacked calls (D7, D10, D12)

This section applies to the Taylor route only. The replicate route keeps
its per-cell `.svy_rep_var()` SE: the `.svy_rep_vcov()` diagonal equals it
in exact arithmetic only, because `sum()` and `%*%` round differently
(`R/variance-replicate.R:26-74`; `comprehension.md` §The joint matrix and
its diagonal, condition 4). The two-phase and nonprob SRS routes have no
joint form and do not change (condition 5).

#### `.taylor_cell_se(vals, mats, lonely.psu, v)` contract

| Argument | Meaning |
|---|---|
| `vals` | Numeric matrix, `n` rows, `k >= 1` columns. Column `j` is the influence column of live cell `j`, in result row order, after any calibration projection. Build it without column names (`unname()` it if needed). |
| `mats` | `ctx$mats`. |
| `lonely.psu` | `ctx$lonely.psu`. |
| `v` | `NULL`, or the `k x k` matrix `.svy_recvar(vals, mats$clusters_mat, mats$strata_mat, mats$fpcs, lonely.psu = lonely.psu)` that the caller already computed for `.vcov`. |

Returns an unnamed numeric vector of length `k`: the SE of each column. The
return carries no names in every rule below. `diag(v)` keeps names when the
row and column names match, and `.svy_multistage()` sets `dimnames(v)` from
`colnames(x)` (`R/variance-taylor.R:192`). Today each cell returns an
unnamed `sqrt(max(0, v[1L, 1L]))`, so a named SE would change the result.
Strip names (`unname()`) before returning if `vals` or `v` carries any.

Rules, in order:

1. Do the finite check once per call of the helper: `ok <-
   all(is.finite(vals))`.
2. `ok` and `v` not `NULL`: return `sqrt(pmax(0, diag(v)))`.
3. `ok` and `v` `NULL`: split the columns into consecutive blocks of at most
   `TAYLOR_SE_BLOCK` columns, in order. Run one `.svy_recvar()` per block.
   The SE of a column is `sqrt(pmax(0, diag(block_v)))` at its position.
4. Not `ok`: for each column `j`, return `sqrt(max(0, .svy_recvar(vals[, j,
   drop = FALSE], mats$clusters_mat, mats$strata_mat, mats$fpcs, lonely.psu =
   lonely.psu)[1L, 1L]))`. `v` is not used. This is "the per-cell form"
   that §IV to §IX refer to.

The helper applies no calibration projection. It raises only what
`.svy_recvar()` raises.

#### Why the finite check is needed

For finite columns, entry `[j, j]` of a stacked call equals the one-column
result bit for bit on R's reference BLAS. Every step of the vendored engine
treats each column on its own (`R/variance-taylor.R:35-61, 71, 106-110`),
and the lonely-stratum handling depends on the design only (`:58-88`). R
fact 4 in `verification-comprehension.md` measured it. With a non-finite
column it does not hold (`comprehension.md` condition 1). `.svy_onestage()`
counts a stratum as usable only when its whole `k x k` block has no `NA`
(`R/variance-taylor.R:133-143`), so one non-finite column drops that stratum
for every column. A clean column's diagonal is then rescaled by
`(H - L) / H_ok_stack`, or is `Inf` or `NaN` when no stratum is left. With an
FPC and more than one cluster column, each first-stage cluster's sub-call
counts its own strata (`R/variance-taylor.R:172-190`), and a clean column
can become `Inf` or `NaN` even when stage 1 keeps strata
(`verification-comprehension.md` V8, V9).

#### Why the blocks (D10, D12)

`get_variance()`, `get_covariance()` and `get_ratios()` need only the
diagonal. A single stacked call builds one `k x k` matrix per stratum
(`R/variance-taylor.R:115-127`) and then sums every entry across strata
(`:136-141`), so its memory grows with `k^2 * H` (`comprehension.md`
§Gotchas, "Stack cost grows with `k^2`"). Blocks keep that memory small and
are exact for finite columns, for the same reason as above.

`get_variance()` and `get_covariance()` hold one column at a time today.
Holding every live column until after the loop would need an `n x k`
matrix: about 2.9 GB at 1,000,000 rows and 360 cells. So these two run the
SE step inside the loop, once per full block (D12). `get_ratios()` already
holds `n x k` today for `.vcov`, so its SE step runs once after the loop, one
block at a time.

`get_ratios()` holds one copy of each column, not two. Today the cell forms
the scaled column as `cell_z$joint$value / total_x`
(`R/analysis-ratios-helpers.R:133`), where `cell_z$joint$value` is the
unscaled `z` influence column after projection. That is the column the cell
now returns as `infl`. So the SE step keeps only the unscaled column per
cell, and derives the scaled one after the block's SE is computed:
`acc_joint[[j]]$value <- acc_infl[[j]] / total_x[[j]]`. This is bit-identical
to today: it is the same IEEE division, on the same two operands, in the
same order, and IEEE division is correctly rounded, so the result does not
depend on where or when it runs.

`get_freqs()`, `get_means()` and `get_totals()` already pay the full
`k x k` cost today for `.vcov` (`.joint_vcov()`,
`R/analysis-helpers.R:1215-1254`), so they pass `v` and use rule 2.

#### The SE step per function

| Function | SE step | `.vcov` |
|---|---|---|
| `get_freqs()`, `get_means()`, `get_totals()` | After the loop: `v_all <- .joint_vcov(design, acc_joint, mats = ctx$mats)`. `live <- kinds == "infl"`. `vals <- do.call(cbind, lapply(acc_joint[live], function(j) j$value))`. `acc_se[live] <- .taylor_cell_se(vals, ctx$mats, ctx$lonely.psu, v = v_all[live, live, drop = FALSE])`. | `.attach_joint_vcov(result, design, acc_joint, v = v_all)` |
| `get_ratios()` | After the loop. `live` is the cells that reached call 3; the loop keeps each one's `infl` in `acc_infl` and its `total_x` in a numeric vector. Split `live` into consecutive blocks of at most `TAYLOR_SE_BLOCK` cells. Per block: `vals <- do.call(cbind, acc_infl[blk])`; `acc_se[blk] <- .taylor_cell_se(vals, ctx$mats, ctx$lonely.psu) / abs(total_x[blk])`; then for each `j` in `blk`, `acc_joint[[j]]$value <- acc_infl[[j]] / total_x[[j]]` and `acc_infl[j] <- list(NULL)`. `acc_infl` is indexed by cell position; `acc_infl[[j]] <- NULL` would delete the element and shift every later position, so it must not be used. | After the last block, once: `v_all <- .joint_vcov(design, acc_joint, mats = ctx$mats)` on the scaled columns, attached as above |
| `get_variance()`, `get_covariance()` | Inside the loop, through the flush buffer below. After the loop (step 4), flush the last partial buffer. Each flush does its own finite check (D12). | None. Do not attach a matrix. |

The flush buffer of `get_variance()` and `get_covariance()`:

- It holds at most `TAYLOR_SE_BLOCK` entries. Each entry is one influence
  column and the locator of the result it belongs to:
  - `get_variance()`: the row position of the cell in the `acc_*` vectors.
  - `get_covariance()`: the group combination index `ci_idx` and the pair
    key. The flush writes to `pair_results_this[[key]]` when `ci_idx` is the
    current combination, and to `all_pair_results[[ci_idx]][[key]]`
    otherwise.
  - A flag that is `TRUE` when the `na.rm = FALSE` override applies to that
    cell (§VII, §VIII).
- When a live cell returns, its `infl` goes into the buffer and is removed
  from the cell result before the result is stored (§II.3).
- When the buffer is full, the flush binds its columns,
  `vals <- do.call(cbind, columns)`, calls `.taylor_cell_se(vals, ctx$mats,
  ctx$lonely.psu)`, writes each SE to its locator (or `NaN` where the
  override flag is `TRUE`), and empties the buffer.
- With finite columns, the SE of a column does not depend on the other
  columns in its block (§III.3, why the finite check is needed), so the
  locators, not the block layout, decide the result.

Invariant used by the first row: on the Taylor route every cell of
`get_freqs()`, `get_means()` and `get_totals()` returns a non-`NULL` `joint`
(kind `"infl"` or `"na"`). So `.joint_vcov()` returns a matrix there, never
`NULL`, and the SE step adds no branch for `NULL`. Each `joint$value` is
`infl_mat[, 1L]`, which has no names.

With no live cell, no variance call runs, as today. `.joint_vcov()` keeps
its guard that returns the all-`NA` matrix without a variance call. In
`get_variance()` and `get_covariance()` an empty buffer is not flushed.

Cells of kind `"na"`, and variance and covariance cells that return early,
stay out of the stack, and their SE stays as the cell set it. The SE step
writes only to live cells.

`.joint_vcov()` with `mats` supplied uses it and does not rebuild.
`.attach_joint_vcov()` with `v` supplied attaches `v` (after it sets the
coefficient names) and does not call `.joint_vcov()`. With `v = NULL` it
behaves as today. Only the Taylor route passes `v`; the replicate route
passes neither `mats` nor `v`.

### III.4 Where the lonely-PSU aborts fire (D6, D9, D12)

Under `options(survey.lonely.psu = "fail")`, a design with a single-PSU
stratum aborts with `surveycore_error_lonely_psu`. A `survey.lonely.psu`
value that the engine does not know raises
`surveycore_error_lonely_psu_unknown_option`, also only on a stratum with one
PSU (`R/variance-taylor.R:74-88`). Both depend on the design only (the PSU
count per stratum and the FPC), so a stacked call and a one-column call
raise the same class with the same message.

Today both fire in the first live cell. After the change:

| Function | Where the abort fires |
|---|---|
| `get_freqs()`, `get_means()`, `get_totals()` | In the SE step, after the loop |
| `get_variance()`, `get_covariance()` | At the first flush: when the `TAYLOR_SE_BLOCK`-th live cell joins the buffer, or after the loop when the call has fewer live cells (D12) |
| `get_ratios()` | Unchanged: in call 1 of the first cell, before the zero-denominator check, because call 1 still runs its own `.svy_recvar()` (§IX) |

§X.1 records the accepted change in condition order.

### III.5 `get_freqs()` replicate sums (D4)

Per call, in step 2: `ctx$rep_finite` from `.cell_context(design,
check_rep_finite = TRUE)`.

Per variable and group combination, before the level loop, compute the
replicate denominator totals once:

- `ctx$rep_finite` is `TRUE`: `di <- which(denom > 0)`, then
  `rep_N_d <- as.numeric(rep(1, length(di)) %*% rep_mat[di, , drop = FALSE])`.
- `ctx$rep_finite` is `FALSE`: `rep_N_d <- as.numeric(denom %*% rep_mat)`.

Pass `rep_N_d` to every level of that combination. Per level, the
numerator totals use the same form:

- `TRUE`: `ni <- which(num > 0)`, then
  `rep_Y <- as.numeric(rep(1, length(ni)) %*% rep_mat[ni, , drop = FALSE])`.
- `FALSE`: `rep_Y <- as.numeric(num %*% rep_mat)`.

Use these exact forms. Do not use `colSums()`.

Why the guard: the subset sum equals the full product only when the dropped
terms are exact zeros. With an `NA` or `Inf` replicate weight on a row
outside the cell, the full product gives `NA` or `NaN` for that replicate in
every cell, and `.svy_rep_var()` drops it. A subset sum would keep it, which
moves the SE and can remove `surveycore_error_all_replicates_na` or
`surveycore_warning_domain_replicates_na`. The class accepts `NA` and `Inf`
replicate weights: the `survey_replicate` validator checks `is.numeric()`
only, and `as_survey_nonprob()` does not call `.validate_repweights()`.

The base-weight `N_d` and `n_g` are one length-`n` sum each and may stay in
the cell.

### III.6 Option reads

`getOption("survey.lonely.psu", "remove")` is read once per call, into
`ctx$lonely.psu`, for the SE step. `.joint_vcov()` keeps its own read. A
Taylor cell that runs its own variance call (`.mean_cell()` and
`.total_cell()` with `compute_se = TRUE`) still reads it, as today. Nothing
in a call sets the option, so one read gives the same value as one read per
cell.

### III.7 Stale comments to correct

In the files of §II.1:

- `R/analysis-means-helpers.R:44-45` and `R/analysis-totals-helpers.R:19-20`:
  the nonprob SRS route goes to the calibrated cell, not the Taylor cell.
- `R/analysis-totals-helpers.R:12-13`: `.quantile_woodruff_cell()` uses
  `.mean_cell()`, not `.total_cell()`.
- `R/analysis-helpers.R:1208-1210`: the Taylor diagonal equals each cell's
  `se^2` only when every live column is finite; the replicate diagonal
  equals it in exact arithmetic only.

---

## Common argument table (the six functions)

No argument is added, removed, renamed, reordered, or given a new default.
`formals()` of each function is identical to the base commit. Every
argument keeps its current meaning:

| Argument | Type | Default | Meaning |
|---|---|---|---|
| `design` | survey design or `survey_collection` | required | The design. A collection dispatches per member, as today. |
| `x` | tidy-select | required (`get_totals()`: `NULL`) | The focal variable or variables. |
| `group` | tidy-select | `NULL` | Grouping variables. Combined with `design@groups`. |
| `variance` | character | `"ci"` (`get_freqs()`: `NULL`) | Any subset of `c("se", "ci", "var", "cv", "moe", "deff")`. Every option gives the same values as on the base commit. |
| `conf_level` | numeric(1) | `0.95` | Interval level. |
| `n_weighted` | logical(1) | `FALSE` | Adds the `n_weighted` column. |
| `decimals` | integer or `NULL` | `NULL` | Rounding of the output. |
| `min_cell_n` | integer(1) | `30L` | Small-cell warning threshold. The warning fires once per call, as today. |
| `na.rm` | logical(1) | `TRUE` | Missing-value handling. |
| `label_values`, `label_vars` | logical(1) | `TRUE` | Label display. |
| `name_style` | character(1) | `"surveycore"` | Column naming. |
| `...` | — | — | Unused passthrough, as today. |
| `.id`, `.if_missing_var` | — | `NULL` | Collection controls, as today. |

Function-specific arguments, unchanged: `get_freqs()` `names_to`,
`values_to`; `get_variance()` `na_handling`; `get_covariance()`
`redundant`, `diagonal`; `get_ratios()` `numerator`, `denominator` in place
of `x`.

## Common return contract

Each function returns the same object as on the base commit: the same S3
class vector (`survey_freqs`, `survey_means`, `survey_totals`,
`survey_variance`, `survey_covariance`, `survey_ratios`, each followed by
`"survey_result"`, `"tbl_df"`, `"tbl"`, `"data.frame"`), the same columns in
the same order with the same types, and the same attributes:

- `.vcov`: present and equal for `get_freqs()`, `get_means()`,
  `get_totals()` and `get_ratios()` on the Taylor and replicate routes;
  absent wherever it is absent today (two-phase, nonprob SRS,
  `get_variance()`, `get_covariance()`, a zero-row result).
- `.survey_result`: equal, including the per-cell `df` of a calibrated
  `get_means()` result.
- `.meta`: equal.

No result class is added or changed. The `print()` and `format()` methods
are untouched, so the console output is the same as on the base commit.

## Common conditions

These conditions are shared. A function's own section lists only what is
specific to it. "Moves" means the place where the condition fires changes
(§III.4); every other entry fires where, and as often as, it does today.

| Class | Functions | Trigger | Change |
|---|---|---|---|
| `surveycore_error_lonely_psu` | all six | Single-PSU stratum, `survey.lonely.psu = "fail"`, Taylor route | Moves in five functions; unchanged in `get_ratios()` |
| `surveycore_error_lonely_psu_unknown_option` | all six | Single-PSU stratum, unknown `survey.lonely.psu` value, Taylor route | As the row above |
| `surveycore_error_all_replicates_na` | all six | `survey_replicate`, every replicate estimate of a cell `NA` | None. Raised in the same calls, including when the non-finite replicate weight sits outside the cell (§III.5) |
| `surveycore_warning_nonprob_srs_fallback` | all six | Nonprob SRS route | None. Once per dispatcher call (in `get_ratios()`, once per `.total_cell()` call) |
| `surveycore_warning_domain_replicates_na` | all six | `survey_nonprob` with replicates, more than 5% `NA` replicates in a cell | None. Once per such cell |
| `surveycore_warning_small_cell` | all six | A cell below `min_cell_n` | None. Once per call, after the SE step |
| `surveycore_warning_single_level` | all six | A grouping variable with fewer than two observed levels | None. Before the loop |

Common edge cases, the same for all six functions:

| Case | Behaviour |
|---|---|
| Empty input (0 rows) | The constructors refuse it; no call reaches these functions. |
| Single-row input | The constructors refuse it (`surveycore_error_single_row`). |
| Single-level group | `surveycore_warning_single_level`, one combination. As today. |
| Zero group combinations | Zero cells. Step 2 still builds the context. No variance call. As today otherwise (§II.5). |
| Zero-weight rows | `as_survey()` refuses a zero base weight. A zero replicate weight is finite. |
| Degenerate strata (single PSU) | Each `lonely.psu` option gives today's numbers; `"fail"` and an unknown value abort per §III.4. |
| Empty domain (marker all `FALSE`) | As today. |
| A live column that is not finite | The per-cell form, §III.3 rule 4. `.vcov`, where stored, comes from the stacked call and keeps today's diagonal (§X.2). |

---

## IV. `get_freqs()`

**Signature** (unchanged):

```r
get_freqs(
  design, x, ...,
  group = NULL, names_to = "name", values_to = "value",
  variance = NULL, conf_level = 0.95, n_weighted = FALSE,
  decimals = NULL, min_cell_n = 30L, na.rm = TRUE,
  label_values = TRUE, label_vars = TRUE, name_style = "surveycore",
  .id = NULL, .if_missing_var = NULL
)
```

**Arguments**: the common table.

**Returns**: the common return contract. Cells: three nested loops
(variable, group combination, level).

**Live cell**: a Taylor cell with `n_g > 0` and `N_d > 0`; its joint kind is
`"infl"`.

**Rules**:

- Taylor: §III.1, §III.3 (row 1 of the SE-step table), §III.4.
- Replicate: §III.2 and §III.5. Each SE stays the cell's own
  `.svy_rep_var()` result; `.vcov` is attached as today (§II.5 step 5).
- No known input fails the finite check in this function. `num` and
  `denom` come from logical comparisons with `is.na()` guards, and an `NA`
  or `Inf` base weight aborts every cell first (§X.3). The check still runs
  inside the shared helper.

**Own conditions**: `surveycore_error_all_na` (all-`NA` `x`, `na.rm =
FALSE`) and `surveycore_warning_all_na_freqs` (all-`NA` `x`, `na.rm =
TRUE`). Both unchanged, raised inside the loop (§X.1).

**Own edge cases**:

| Case | Behaviour |
|---|---|
| All-NA `x`, `na.rm = TRUE` | `surveycore_warning_all_na_freqs`, zero rows, no `.vcov`. No variance call. As today. |
| All-NA `x`, `na.rm = FALSE` | `surveycore_error_all_na`. As today. |
| `NA` or `Inf` replicate weight | Full products (§III.5). |

---

## V. `get_means()`

**Signature** (unchanged):

```r
get_means(
  design, x,
  group = NULL, variance = "ci", conf_level = 0.95, n_weighted = FALSE,
  decimals = NULL, min_cell_n = 30L, na.rm = TRUE,
  label_values = TRUE, label_vars = TRUE, name_style = "surveycore",
  ...,
  .id = NULL, .if_missing_var = NULL
)
```

**Arguments**: the common table.

**Returns**: the common return contract. A calibrated Taylor design keeps
its `df` column and its per-cell `df` in `.survey_result`.

**Live cell**: a Taylor cell with `n_d > 0` and `N_d > 0`.

**Rules**:

- Taylor: §III.1, §III.3 (row 1), §III.4. `get_means()` calls
  `.mean_cell(design, x_name, domain, mats = ctx$mats, compute_se = FALSE,
  rep_mat = ctx$rep_mat)`.
- Replicate: §III.2, including the one `crossprod()` per cell.
- Cell degrees of freedom (issue #326). In `.taylor_mean_cell()`:
  - Calibrated Taylor design (the same predicate `get_means()` uses for
    `has_calibration`): compute
    `.degf_taylor(data[domain > 0, c(vars$ids[1L], vars$strata), drop =
    FALSE], vars)`. The rows stay `domain > 0`. Only the columns narrow, to
    the first `ids` column and the `strata` column. With no `ids` and no
    `strata` the column vector is `NULL`, and `.degf_taylor()` returns
    `nrow - 1`, as today. The calibration df reduction and the zero-df
    warning stay per cell.
  - Uncalibrated Taylor design: do not call `.degf_taylor()`. The cell
    omits `df` from its returned list. `get_means()` turns a missing `df`
    into `Inf` (`R/analysis-means.R:247`) and does not read it for such a
    design (`:272-275, 290-292, 329-335`). `get_quantiles()` reads only
    `mean` and `se` from the cell (`R/analysis-quantiles-helpers.R:
    154-158`). The zero-df warning cannot fire there today (the reduction
    is 0, `R/calibration.R:467-473`, and the design df is at least 1), so
    skipping the call removes no condition.
  - The column narrowing is exact because `.degf_taylor()` reads only
    `vars$ids[[1L]]`, `vars$strata` and `vars$nest`
    (`R/analysis-helpers.R:349-380`). Add a comment at `.degf_taylor()`
    that names the columns it reads and says a caller may pass a frame
    holding only those columns.

  Cell `df` by route:

  | Route | Cell `df` |
  |---|---|
  | Uncalibrated Taylor, replicate, nonprob (either route), two-phase | `Inf` (the cell returns no `df`; `get_means()` stores `Inf`) |
  | Calibrated Taylor | `max(1, .degf_taylor(cell rows)) - sum(QR ranks of @calibration)`; when that is 0 or less, `surveycore_warning_zero_df_after_calibration` and the value is clamped to 1 |
  | Any cell of kind `"na"` | `Inf` |
- `get_quantiles()` calls `.mean_cell()` with the base-commit arguments and
  reads `mean` and `se` only. It must get today's values.

**Own conditions**: `surveycore_warning_zero_df_after_calibration`, once per
calibrated cell whose df falls to 0 or below, inside the loop, as today.
`surveycore_error_all_replicates_na` is reached by an `NA` in `x` with
`na.rm = FALSE` on a `survey_replicate`.

**Own edge cases**:

| Case | Behaviour |
|---|---|
| `NA` in `x`, `na.rm = FALSE`, Taylor | The cell's influence column is `NA` on every row (`R/analysis-means-helpers.R:72-77`). Calibrated or not: guard 1 of the projection passes an all-`NA` column through (`R/calibration.R:386-388`). See the common edge case for non-finite columns. |
| `Inf` in `x`, any `na.rm`, uncalibrated Taylor | Non-finite column (`comprehension.md` condition 1, round 2 case b2). |
| `Inf` in `x`, calibrated Taylor | The projection aborts with base R's error in `qr.resid()` (`R/calibration.R:434`), as today. |
| All-NA `x` with `na.rm = TRUE` | The cell has kind `"na"`; no variance call. |

---

## VI. `get_totals()`

**Signature** (unchanged):

```r
get_totals(
  design, x = NULL,
  group = NULL, variance = "ci", conf_level = 0.95, n_weighted = FALSE,
  decimals = NULL, min_cell_n = 30L, na.rm = TRUE,
  label_values = TRUE, label_vars = TRUE, name_style = "surveycore",
  ...,
  .id = NULL, .if_missing_var = NULL
)
```

**Arguments**: the common table. `x = NULL` gives population size.

**Returns**: the common return contract.

**Live cell**: a Taylor cell with `n_d > 0` and `N_d > 0`. A categorical `x`
gives one cell per level per combination, on its indicator columns.

**Rules**: Taylor §III.1, §III.3 (row 1), §III.4; `get_totals()` calls
`.total_cell()` with `mats = ctx$mats, compute_se = FALSE, rep_mat =
ctx$rep_mat`. Replicate §III.2. The indicator columns written for a
categorical `x` are not design columns, so the step-2 matrices are the same
before or after they are written.

**Own conditions**: `surveycore_warning_all_na_totals` and
`surveycore_error_all_na` (categorical `x`), unchanged. Base R's projection
error on a calibrated design with an `NA` or `Inf` in `x` is unchanged:
guard 1 passes only an all-`NA` column (`R/calibration.R:386-388`), so a
partly `NA` or an `Inf` column reaches `qr.resid()` and aborts (`:434`;
`verification-comprehension.md` V11).

**Own edge cases**:

| Case | Behaviour |
|---|---|
| `NA` in numeric `x`, `na.rm = FALSE`, uncalibrated Taylor | The influence column is `NA` on the `NA` rows: a non-finite column. One-stage and multistage. |
| `Inf` in numeric `x`, uncalibrated Taylor | A non-finite column. |
| Population size (`x = NULL`) | As today. |

---

## VII. `get_variance()`

**Signature** (unchanged):

```r
get_variance(
  design, x,
  group = NULL, variance = "ci", conf_level = 0.95, n_weighted = FALSE,
  decimals = NULL, min_cell_n = 30L, na.rm = TRUE,
  na_handling = c("pairwise", "listwise"),
  label_values = TRUE, label_vars = TRUE, name_style = "surveycore",
  ...,
  .id = NULL, .if_missing_var = NULL
)
```

**Arguments**: the common table.

**Returns**: the common return contract. No `.vcov` attribute.
`vcov()` on the result keeps today's fallback: `se^2` on the diagonal, `NA`
off it, and `surveycore_warning_vcov_incomplete` when there is more than one
row (`vcov.survey_result()`, `R/analysis-methods-coef-vcov.R:452-480`).

**Live cell**: a Taylor cell that reaches its variance step: `n_d >= 2`, `W`
finite and positive. A cell that returns early keeps its `NaN` SE and does
not join the buffer.

**Rules**:

- Taylor: §III.1, §III.3 (row 3 and the flush buffer, D12), §III.4.
  `.taylor_variance_cell()` returns its influence column in the field
  `infl`, next to `se = NA_real_`. The loop moves `infl` into the flush
  buffer with the cell's row position in the `acc_*` vectors, and removes
  it from the cell result before it appends the result to `acc_*`. The
  function never holds more than one block of influence columns.
- No calibration projection is applied, today or after. Do not add one.
- The `na.rm = FALSE` override sets `variance`, `se` and `se_srs` to `NaN`
  for a cell with an `NA` in the active domain. The cell still joins the
  buffer, with its override flag `TRUE`, and its flush writes `NaN` to its
  `se`. So the override wins, as in the base-commit order (today the cell
  computes its SE, then the override replaces it). The cell must still join
  the buffer: under `survey.lonely.psu = "fail"` its variance call is the
  one that aborts when it is the only live cell. The `variance`, `se_srs`
  and `n` parts stay in the loop. The influence column of such a cell is
  finite, because `.score_variance()` leaves `NA` rows out of `active`
  (`R/analysis-variance-helpers.R:40`), so it does not force its block into
  the per-cell form.
- Replicate: §III.2 only.

**Own conditions**: `surveycore_warning_variance_all_na` and
`surveycore_warning_variance_insufficient_n`, after the loop, as today. Base
R's error for an `NA` base weight inside a cell is kept (§X.3).

**Own edge cases**:

| Case | Behaviour |
|---|---|
| `Inf` in `x` | `Inf` is not `NA`, so the row stays active (`R/analysis-variance-helpers.R:40`). The weighted mean is then `Inf`, the squared deviations hold `NaN`, and the estimate `v_hat` is `NaN` (`:67, 84-93`). The influence column `w * a * (score - v_hat) / W` is then `NaN` on every row (`:156`). Its block takes the per-cell form; clean cells keep today's values. |
| `NA` base weight on a row outside every cell | Every live column is `NA` on that row, so every block takes the per-cell form and gives today's values (§X.3). |
| A cell that returns early between live cells | It does not join the buffer; the block holds the live cells on either side of it. |
| Many cells | More than one block; the SEs are the same. |

---

## VIII. `get_covariance()`

**Signature** (unchanged):

```r
get_covariance(
  design, x,
  group = NULL, redundant = FALSE, diagonal = FALSE,
  variance = "ci", conf_level = 0.95, n_weighted = FALSE,
  decimals = NULL, min_cell_n = 30L, na.rm = TRUE,
  label_values = TRUE, label_vars = TRUE, name_style = "surveycore",
  ...,
  .id = NULL, .if_missing_var = NULL
)
```

**Arguments**: the common table.

**Returns**: the common return contract. No `.vcov` attribute.

**Live cell**: one needed unordered pair (key `"i-j"`) in one group
combination that reaches its variance step. The buffer takes the pairs in
loop order, across combinations. Each SE is written back to its pair result
at its flush, before the fill loop that builds the redundant and mirrored
rows.

**Rules**: as for `get_variance()`, with `.covariance_pair_taylor()`
returning `infl`. The pair loop moves `infl` into the flush buffer with the
locator `(ci_idx, key)`, and removes it from the pair result before it
stores the result in `pair_results_this[[key]]`. So neither
`pair_results_this` nor `all_pair_results` holds an influence column. A
block can span two group combinations; the flush writes each SE through its
locator (§III.3). The `na.rm = FALSE` override in the pair loop wins through
the override flag, as in §VII.

**Own conditions**: `surveycore_warning_covariance_all_na` and
`surveycore_warning_covariance_insufficient_n`, after the loop, as today.

**Own edge cases**: as for `get_variance()`.

---

## IX. `get_ratios()`

**Signature** (unchanged):

```r
get_ratios(
  design, numerator, denominator,
  group = NULL, variance = "ci", conf_level = 0.95, n_weighted = FALSE,
  decimals = NULL, min_cell_n = 30L, na.rm = TRUE,
  label_values = TRUE, label_vars = TRUE, name_style = "surveycore",
  ...,
  .id = NULL, .if_missing_var = NULL
)
```

**Arguments**: the common table.

**Returns**: the common return contract.

**Per-cell calls**: call 1 is `.total_cell()` on the denominator, call 2 is
`.total_cell()` on the numerator, call 3 is the SE call
(`.replicate_ratio_cell()` or `.delta_ratio_cell()`).

**Live cell**: a cell that reaches call 3 (not stored as `"na"`).

**Rules**:

- Calls 1 and 2 get `mats = ctx$mats` (Taylor) or `rep_mat = ctx$rep_mat`
  (replicate) and keep `compute_se = TRUE` **[D8 default]**. They keep their
  own SE work for three reasons:
  - On the nonprob SRS route each call warns
    `surveycore_warning_nonprob_srs_fallback`. Removing a call changes the
    warning count and moves the suite's warning baseline.
  - On the Taylor route, call 1 is where the lonely-PSU aborts fire, before
    the zero-denominator check. Keeping it keeps that order.
  - On the replicate route, calls 1 and 2 raise
    `surveycore_error_all_replicates_na` or warn
    `surveycore_warning_domain_replicates_na` for an `NA` in a cell.
- Call 3, Taylor route: `.delta_ratio_cell(..., mats = ctx$mats, compute_se =
  FALSE)`. It returns `infl` (the unscaled `z` column, after projection) and
  the joint element with its scaled `est` and `value = NULL` (§II.3). The
  loop stores `infl` in `acc_infl` and the cell's `total_x` in a numeric
  vector. After the loop (D5, D10), per block of §III.3:
  - SE: `.taylor_cell_se()` on the block's unscaled columns, divided by
    `abs(total_x)` per cell. This gives `sqrt(max(0, V_z)) / abs(total_x)`
    exactly, as today.
  - The scaled column `infl / total_x` is written to `joint$value` and the
    unscaled column is dropped. This is bit-identical to today's
    `cell_z$joint$value / total_x` (§III.3, why the blocks). Each cell holds
    one column at a time, so the change adds no `n x k` copy.
  - `.vcov`: `.joint_vcov(design, acc_joint, mats = ctx$mats)` on the scaled
    columns, after the last block, as today.
  - The finite check runs on the unscaled columns, once per block (D7 as
    D10 applies it). A block that fails takes the per-cell form; a clean
    block keeps the stacked diagonal. Both give the one-column result for a
    finite column, so a check per block gives the same SEs as a check per
    call. The scaled columns can be finite only when the unscaled columns
    are, so a check on the unscaled columns is safe.
- Call 3, replicate route: `.replicate_ratio_cell(..., rep_mat =
  ctx$rep_mat)`.
- Call 3, nonprob SRS and two-phase routes: `.delta_ratio_cell(..., mats =
  NULL, compute_se = TRUE)`, unchanged in effect.
- So on the Taylor route the call runs `.svy_recvar()` once per non-empty
  total cell in each of calls 1 and 2, plus `ceiling(k / TAYLOR_SE_BLOCK)`
  calls for the SEs, plus one for `.vcov`. The request's "once per call"
  does not hold here, for the reasons above and D5.
- `.delta_ratio_cell()` still writes `z` into its local copy of
  `design@data`. That write is not a design column and does not touch the
  call context.

`total_x == 0` for a live cell. A finite `z` with `total_x == 0` cannot
reach call 3:

- With `n_cell > 0`, a zero `total_x` raises
  `surveycore_error_ratio_zero_denominator` first
  (`R/analysis-ratios.R:300`).
- With `na.rm = TRUE`, `n_cell == 0` means the domain vector is empty, so
  `total_x` is `NA` and the cell is stored as `"na"`.
- With `na.rm = FALSE`, `n_cell == 0` and a `total_x` that is not `NA` mean
  the denominator has no `NA` in the cell, so every in-cell row has an `NA`
  numerator. Then `total_y`, the ratio and `z` are `NA`.

So the only live cell with `total_x == 0` has a non-finite `z` and takes the
per-cell form, as the edge-case table states.

**Own conditions**: `surveycore_error_ratio_zero_denominator`, unchanged.
`surveycore_warning_nonprob_srs_fallback` counts: three per cell that
reaches call 3, one per cell that stops after call 1.

**Own edge cases**:

| Case | Behaviour |
|---|---|
| `NA` in the numerator only, `na.rm = FALSE`, uncalibrated Taylor | The ratio is `NA` and the `z` column is `NA` on every in-domain row: a non-finite column. |
| `NA` in the denominator, `na.rm = FALSE` | The cell is stored as `"na"` after call 1, as today. |
| `na.rm = FALSE`, a cell whose numerator is all `NA` and whose denominator is all zero | `n_cell` is 0, so the zero-denominator abort does not fire, and `total_x` is 0. The cell reaches call 3 with an `NA` `z` column: a non-finite column. |
| Calibrated Taylor with an `NA` in either variable | The projection aborts in call 2 (numerator) or call 1 (denominator), as today. |

---

## X. Accepted changes and kept behaviour

### X.1 Condition order of the moved aborts (D6, D9, accepted)

§III.4 states where the two lonely-PSU aborts now fire. Each keeps its class
and its message.

The rule (D9, general form): any condition that a cell raises inside the
loop before the moved abort fires now comes before the abort. A warning
prints first and the abort follows. An error replaces the abort; the call
still aborts. Under `options(warn = 2)` such a warning is itself an error,
so it also replaces the abort. Known cases:

| Function | Condition from a later cell | Kind |
|---|---|---|
| `get_freqs()` | `surveycore_warning_all_na_freqs` for a later variable, `na.rm = TRUE` | warning |
| `get_freqs()` | `surveycore_error_all_na` for a later all-`NA` variable, `na.rm = FALSE` | error |
| `get_means()` | `surveycore_warning_zero_df_after_calibration` for a later calibrated cell | warning |
| `get_means()` | a base R error from a later cell (for example the `Inf` base-weight error of §X.3, or the projection error of a calibrated design with `Inf` in `x`) | error |
| `get_totals()` | base R's calibration-projection error for a later cell with `NA` or `Inf` in `x` (`R/calibration.R:386-388, 434`) | error |
| `get_variance()`, `get_covariance()` | base R's error for an `NA` base weight inside a later cell (§X.3), before the first flush | error |

The list is not closed. The rule covers every condition of this kind.

The final SE step runs before the post-loop warnings, so the small-cell
warning and the per-variable and per-pair warnings still do not fire when an
abort fires. The option not taken is a design-level lonely-PSU check before
the cell loop (D9).

### X.2 Kept: the stored `.vcov` diagonal can differ from `se^2` (D3, D7)

When the finite check fails, the SE of each cell comes from its own call and
`.vcov` comes from the stacked call, as today. The stored diagonal for a
clean cell then differs from its `se^2`, and can be `Inf` or `NaN`. Measured
on the base commit: an uncalibrated grouped `get_totals()` with an `NA` in
`x`, clean cell `se^2` 31.14489 against a `.vcov` diagonal of 41.52652; a
calibrated grouped `get_means()` with an `NA` in `x`, `se^2` 0.03740842
against `Inf`. This change keeps both values.

This is `survey`'s behaviour too, so do not "fix" it. `survey:::onestage`
drops a stratum when any entry of its `p x p` block is `NA`, so
`survey::svyby(covmat = TRUE)` returns the same contaminated diagonal. The
`se` column follows `survey`'s one-statistic call; `.vcov` follows
`survey`'s multi-column call.

### X.3 Kept: three existing defects [D8 default]

| Defect | Today | After |
|---|---|---|
| `NA` base weight on a row inside a cell of `get_variance()` / `get_covariance()` | Base R error "missing value where TRUE/FALSE needed" | The same |
| `NA` base weight on a row outside every cell of `get_variance()` / `get_covariance()` | The per-cell SE drops that row's stratum and rescales by `H / H_ok` | The same values, through the per-cell form of §III.3 rule 4 |
| `Inf` base weight | Accepted by the class. `get_freqs()` and grouped `get_means()`, `get_totals()`, `get_ratios()` give base R errors; ungrouped calls run | The same |

Whether to file issues for these is the user's call.

---

## XI. Quality gates

Each gate is checked on the final branch. Gates 1 to 8 are also checked on
each PR.

1. **Results.** For every design class and route of §I.4, every `variance =`
   option, grouped and ungrouped, with and without a domain marker, every
   output of the six functions equals the base commit's output within D3's
   last-bit allowance. "Output" is every column, `.vcov`, `.survey_result`
   and `.meta`. The one exemption is `.meta$call`: it stores `match.call()`,
   which records the caller's expression text, not a computed value. The
   gate passes when the comparison against the outputs captured on the base
   commit (§II.6 step 1) passes. `identical()` is recorded as evidence (§XII.4)
   and is not required. The same holds for `get_quantiles()` and
   `get_effective_n(method = "deff")`, which reach the changed cells.
2. **Conditions.** Every condition keeps its class, message and count per
   call. The order changes only as §X.1 states.
3. **Signatures.** `formals()` of the six functions is identical to the base
   commit.
4. **Warning baseline.** A full `devtools::test()` run raises 369 warnings,
   the `develop` baseline in `CLAUDE.md`.
5. **R CMD check** as `r-package-conventions.md` §Package check hygiene
   requires.
6. **Coverage** at the floor of `testing-standards.md`, with no new
   `# nocov`. Every rule branch of `.taylor_cell_se()` (rule 2, rule 3 with
   more than one block, rule 4), a partial final flush and a full in-loop
   flush in `get_variance()` and `get_covariance()`, and both sum forms of
   §III.5 are reached.
7. **Format** as `code-style.md` requires (`air format --check` on the
   changed files).
8. **Documentation.** `devtools::document()` leaves no diff.
9. **Speed.** The protocol of §XII is run and its table is recorded. A
   scenario is flagged when its before time is at least 0.1 s and its after
   time exceeds its before time by more than 10% **and** by more than
   0.02 s. Both conditions must hold. A flagged scenario is run once more,
   both libraries. If it is still flagged, it is a HOLD for the user. A HOLD
   is not a reason to change any result.
10. **Call counts.** The counts of §XII.4 are recorded for every scenario.
    On the Taylor route `.build_cluster_matrices()` runs once per call.
11. **NEWS.md and changelog** carry the entries of §XIII, with no
    placeholder left: every `{...}` field is filled from the §XII table and
    the issue or PR number.
12. **Stale comments** of §III.7 are corrected.
13. **Block size.** The measurement of §XII.5 is run and recorded, and
    `TAYLOR_SE_BLOCK` holds the size it selects (D12).

---

## XII. Speed measurement protocol

### XII.1 Setup

1. Make two package libraries. Install the base commit into one
   (`git worktree add <dir> <base-sha>`, then
   `R CMD INSTALL --library=<lib_before> <dir>`). Install the final branch
   head into the other.
2. Use one script for both. It takes the library path and an output path as
   arguments, attaches `surveycore` from that library with
   `library(surveycore, lib.loc = lib)`, builds the designs of §XII.2, and
   runs the scenarios of §XII.3.
3. Run the two libraries one after the other, in the foreground, on the
   same machine, with no other R process running. Record the R version, the
   BLAS (`extSoftVersion()[["BLAS"]]`), the LAPACK (`La_library()`) and
   `getOption("matprod")`.

Installed packages are timed, not `devtools::load_all()`. About 13% of each
load_all profile in `measurements.md` was JIT compilation that an installed
package does not pay.

### XII.2 Designs

GSS Taylor, as in `measurements.md`:

```r
gss_d <- as_survey(
  gss_2024,
  ids = vpsu,
  strata = vstrat,
  weights = wtssps,
  nest = TRUE
)
```

GSS calibrated Taylor:

```r
gss_x <- cbind(1, as.numeric(!is.na(gss_2024$age) & gss_2024$age > 50))
gss_cal <- as_survey(
  gss_2024,
  ids = vpsu,
  strata = vstrat,
  weights = wtssps,
  nest = TRUE,
  calibration = list(
    as_caldata(gss_2024$wtssps, rep(1.01, nrow(gss_2024)), gss_x)
  )
)
```

Frame A (the `get_freqs()` frame of `measurements.md`), 50,000 rows:

```r
set.seed(1)
n <- 50000L
st <- sample.int(50L, n, replace = TRUE)
psu <- sample.int(4L, n, replace = TRUE)
frame_a <- data.frame(
  st = st,
  psu = psu,
  wt = exp(rnorm(n, 0, 0.5)) * 100,
  v3 = factor(sample(c("a", "b", "c"), n, TRUE, prob = c(0.5, 0.3, 0.2))),
  v5 = sample.int(5L, n, TRUE),
  v7 = sample(letters[1:7], n, TRUE),
  v10 = sample.int(10L, n, TRUE),
  g4 = sample(c("NE", "MW", "S", "W"), n, TRUE)
)
frame_a$v5[sample.int(n, 500L)] <- NA
a_tay <- as_survey(frame_a, ids = psu, strata = st, weights = wt, nest = TRUE)

psu_key <- interaction(frame_a$st, frame_a$psu, drop = TRUE)
mult <- matrix(rpois(nlevels(psu_key) * 80L, 1), ncol = 80L)
rep_a <- frame_a$wt * mult[as.integer(psu_key), ]
colnames(rep_a) <- paste0("rw", seq_len(80L))
a_rep <- as_survey_replicate(
  cbind(frame_a, as.data.frame(rep_a)),
  weights = wt,
  repweights = rw1:rw80,
  type = "bootstrap"
)
```

Frame B (the `get_means()` frame of `measurements.md`), 50,000 rows:

```r
set.seed(1)
n <- 50000L
strat <- sample(seq_len(40L), n, replace = TRUE)
psu_within <- sample(1:15, n, replace = TRUE)
frame_b <- data.frame(
  strat = strat,
  psu = psu_within,
  wt = exp(rnorm(n, 0, 0.5)) * 100,
  y1 = rnorm(n, 50, 10),
  y2 = rpois(n, 3) + 0,
  y3 = ifelse(runif(n) < 0.05, NA, rnorm(n)),
  g10 = factor(sample(letters[1:10], n, replace = TRUE)),
  g20 = sample(1:20, n, replace = TRUE),
  g3 = sample(c("x", "y", "z"), n, replace = TRUE)
)
b_tay <- as_survey(
  frame_b,
  ids = psu,
  strata = strat,
  weights = wt,
  nest = TRUE
)

rep_b <- matrix(frame_b$wt * rexp(n * 80L), nrow = n)
colnames(rep_b) <- paste0("rw", seq_len(80L))
b_rep <- as_survey_replicate(
  cbind(frame_b, as.data.frame(rep_b)),
  weights = wt,
  repweights = rw1:rw80,
  type = "bootstrap"
)
```

The timing script wraps each scenario in `suppressWarnings()`. It is a
measurement script, not part of the package.

### XII.3 Scenarios

All scenarios stay: request acceptance criteria 1 to 3 and 7 need them.

From `measurements.md` (`get_freqs()`):

| Id | Call |
|---|---|
| F1 | `get_freqs(gss_d, partyid)` |
| F2 | `get_freqs(gss_d, partyid, group = race)` |
| F3 | `get_freqs(gss_d, c(partyid, polviews, happy, health))` |
| F4 | `get_freqs(a_tay, v10)` |
| F5 | `get_freqs(a_tay, v10, group = g4)` |
| F6 | `get_freqs(a_tay, c(v3, v5, v7, v10))` |
| F7 | `get_freqs(a_rep, v10)` |
| F8 | `get_freqs(a_rep, v10, group = g4)` |
| F9 | `get_freqs(a_rep, c(v3, v5, v7, v10))` |

From `measurements.md` (`get_means()`):

| Id | Call |
|---|---|
| M1 | `get_means(gss_d, age)` |
| M2 | `get_means(gss_d, age, group = degree)` |
| M3 | `get_means(gss_d, age, group = c(sex, race))` |
| M4 | `get_means(gss_cal, age, group = degree)` |
| M5 | `get_means(b_tay, y1)` |
| M6 | `get_means(b_tay, y1, group = g20)` |
| M7 | `get_means(b_tay, y1, group = c(g20, g3))` |
| M8 | `get_means(b_rep, y1)` |
| M9 | `get_means(b_rep, y1, group = g20)` |

New, for the four functions that were not profiled:

| Id | Call | Live Taylor cells |
|---|---|---|
| T1 | `get_totals(gss_d, age, group = degree)` | |
| T2 | `get_totals(b_tay, y1, group = g20)` | 20 |
| T3 | `get_totals(b_rep, y1, group = g20)` | |
| V1 | `get_variance(b_tay, c(y1, y2), group = g20)` | 40 |
| V2 | `get_variance(b_rep, y1, group = g20)` | |
| V3 | `get_variance(b_tay, c(y1, y2, y3), group = c(g20, g3))` | 180 |
| C1 | `get_covariance(b_tay, c(y1, y2), group = g20)` | 20 |
| C2 | `get_covariance(b_tay, c(y1, y2, y3), group = c(g20, g3), diagonal = TRUE)` | 360 |
| C3 | `get_covariance(b_rep, c(y1, y2), group = g20)` | |
| R1 | `get_ratios(gss_d, educ, age, group = degree)` | |
| R2 | `get_ratios(b_tay, y1, y2, group = g20)` | 20 |
| R3 | `get_ratios(b_rep, y1, y2, group = g20)` | |
| R4 | `get_ratios(b_tay, y1, y2, group = c(g20, g3))` | 60 |

C2 and V3 are the large-`k` cases that the blocks exist for, and the ones
most likely to be flagged by gate 9.

### XII.4 What to record

For each scenario and each library:

- **Time.** One warm-up call, then the median of `system.time(...)[[
  "elapsed"]]` over 5 runs (3 runs when the warm-up takes more than 1 s).
- **Rows** of the result.
- **Call counts.** In a separate pass, one call per scenario, count the
  calls to `.build_cluster_matrices()` and `.svy_recvar()` with
  `trace(..., where = asNamespace("surveycore"), print = FALSE)` and a
  counter tracer. Remove the traces before the timing pass.
- **Equality.** Save each result with `saveRDS()`. After both runs, report
  `identical(before, after)` per scenario.

Expected after-counts on the Taylor route, when every live column is
finite. `k` is the number of live cells and `B` is `TAYLOR_SE_BLOCK`.

| Function | `.build_cluster_matrices()` | `.svy_recvar()` |
|---|---|---|
| `get_freqs()`, `get_means()`, `get_totals()` | 1 | 1 when `k >= 1`; 0 when `k = 0` |
| `get_variance()`, `get_covariance()` | 1 | `ceiling(k / B)` |
| `get_ratios()` | 1 | one per non-empty call-1 total cell, plus one per non-empty call-2 total cell, plus `ceiling(k / B)`, plus 1 for `.vcov` when `k >= 1`. A cell that stops after call 1 adds its call-1 count only. With `k = 0` the last two terms are 0. |

A non-empty total cell is one with `n_d > 0` and `N_d > 0`; an empty one
returns before its variance call. A block that fails its finite check adds
one call per column in place of one per block.

On the replicate route both counts are 0.

Record one table: scenario, rows, before (s), after (s), after/before,
counts before and after, `identical()`. Put it in the changelog file of
§XIII and in the description of the PR that carries the `NEWS.md` entry.

### XII.5 Block-size measurement (D12)

Run on the branch head, before the §XII.4 run, with the library and script
of §XII.1.

1. Scenarios: V3, C2 and R4, the largest live-cell counts of each function
   that uses the blocks.
2. For each `B` in 16, 32 and 64, set the constant in the measurement
   session with `utils::assignInNamespace("TAYLOR_SE_BLOCK", B,
   "surveycore")`, then time each scenario as §XII.4 states (one warm-up,
   median of 5 runs, or 3 when the warm-up takes more than 1 s).
3. At each `B`, save each scenario's result with `saveRDS()`. Compare it
   with the base commit's result for the same scenario, built with the
   §XII.1 base library. Record `identical()` and, when that is `FALSE`,
   whether the two are equal within D3's last-bit allowance.
4. For each `B`, add the three medians.
5. Select the smallest `B` whose sum is within 5% of the smallest sum.
6. Set `TAYLOR_SE_BLOCK` to that value in `R/analysis-helpers.R` and
   commit it with the table: `B`, the three medians, the sum, and the
   equality result of each scenario.

Equality is checked at all three sizes, not only at the one selected. For
finite columns every block size gives the same SEs (§III.3), so a size at
which a result differs is a defect, and it blocks the selection until it is
explained.

---

## XIII. `NEWS.md` and changelog

`NEWS.md` gains a development-version section above `# surveycore 1.2.0`, if
there is none yet, with this entry. Fill every `{...}` field from the §XII
table before merge:

```
# surveycore (development version)

## Performance

* {functions} are faster on grouped and multi-level calls. Work that is the
  same for every cell, building the cluster and strata matrices and
  converting the replicate weight columns, now runs once per call, and the
  Taylor standard errors of many cells come from a few shared variance
  calls. Results do not change beyond floating-point rounding; an optimized
  BLAS can differ in the last bit. For example, a grouped `get_means()` on
  50,000 rows with 60 cells took {M7 before} s and now takes {M7 after} s.
  ({ref})

* With `options(survey.lonely.psu = "fail")`, or with a value the variance
  engine does not know, a stratum with one PSU still raises the same error.
  In `get_freqs()`, `get_means()`, `get_totals()`, `get_variance()` and
  `get_covariance()` the error now comes later in the call, after more
  cells are computed. A warning from one of those cells can print before
  it, and an error from one of them replaces it. ({ref})
```

Field rules:

- `{functions}`: the functions, from the six, that have at least one §XII
  scenario with a before time of at least 0.1 s and an after/before ratio
  of 0.9 or less. List them in the order of §I.2. Name no other function.
- `{M7 before}`, `{M7 after}`: scenario M7 of the §XII table, two decimal
  places. If `get_means()` does not qualify for `{functions}`, replace the
  example sentence with the qualifying scenario that has the largest
  before time, and describe that scenario in the same words. If no
  scenario qualifies, drop the example sentence.
- If no function qualifies for `{functions}`, drop the speed sentence and
  the example sentence. The first bullet then starts: "The analysis
  functions `get_freqs()`, `get_means()`, `get_totals()`,
  `get_variance()`, `get_covariance()` and `get_ratios()` were restructured
  internally. The restructuring gives no measured speed change on the
  benchmark calls recorded in the changelog." It keeps the sentence about
  results and rounding.
- `{ref}`: `#` and the GitHub issue number the work closes, or the PR
  number of the PR that carries the entry if no issue exists.

The changelog file follows the house shape (`changelog/*.md`): branch,
status, date, summary, files modified, changes. It carries:

- the §XII table and the §XII.5 block-size table;
- the `identical()` evidence of §XV;
- this sentence: "Under `survey.lonely.psu = "fail"`, a call that fails now
  computes every cell first (in `get_variance()` and `get_covariance()`,
  every cell up to the first full block) and then raises the error.";
- this sentence: "Under `options(warn = 2)`, a warning from one of those
  cells becomes an error and replaces the lonely-PSU error.";
- the lifecycle line of D13: "The base-commit outputs captured for this
  work stay as a permanent check. When a later change moves one of these
  results on purpose, regenerate them with the generator in `data-raw/`."

---

## XIV. Integration

- **surveytidy.** `filter()` writes the logical domain marker column
  (`SURVEYCORE_DOMAIN_COL`) and `@variables$domain`. surveycore reads only
  the column. `group_by()` writes `@groups`. Neither contract changes.
- **`vcov()`, `confint()`, `coef()`** read `.vcov` and `.survey_result`.
  Both stay equal, so these methods return the same values. For
  `get_variance()` and `get_covariance()` `vcov()` keeps its fallback.
- **`get_quantiles()`** reaches `.mean_cell()` with the base-commit
  arguments. **`get_effective_n(method = "deff")`** calls `get_means()`.
  **`get_diffs()`** and other callers that read these results get equal
  inputs.
- **`survey_collection`** dispatch calls each function per member. No
  change.
- **`survey` package.** The existing oracle comparisons hold, because no
  value moves.

---

## XV. Evidence (not a check)

Measured on `develop` at `0c0a987`, R 4.6.1 ucrt on Windows 11, reference
BLAS, `getOption("matprod")` = `"default"` (`measurements.md`,
`verification-comprehension.md`).

| Prototype | Result |
|---|---|
| `get_freqs()` fixes 1 and 2 (Taylor) | `identical()` TRUE on the whole result, `.vcov` included, also with `variance = c("se", "ci", "var", "cv", "moe", "deff")` |
| `get_means()` fixes 1, 2, 4 (Taylor) and 3 (replicate) | `identical()` TRUE on 10 scenarios and 12 edge designs (two-stage with FPC, SRS, strata only, each under `remove`, `adjust`, `average`, `certainty`), the calibrated `df` column included |
| `get_means()` one `crossprod()` against two products | `identical()` TRUE on `rep_N_d`, `rep_Y` and the ratios |
| Stacked diagonal against one-column calls, every column finite | `identical()` TRUE under `remove`, `adjust`, `average`, `certainty`, one-stage and two-stage with FPC, with a lonely stratum |
| `crossprod()` with a `NaN` or `Inf` column | The finite block does not move (200 seeds, 0 mismatches) |
| `sqrt(max(0, x))` against `sqrt(pmax(0, x))` for `NaN` and `NA` | `identical()` TRUE |
| `nrow(df[rows, NULL, drop = FALSE])` against `sum(rows)` | Equal for a logical `rows` with no `NA`, all-`FALSE` included |

Measured speed-ups before this spec (load_all, `system.time()` medians):
`get_freqs()` GSS `group = race` 0.81 s to 0.08 s; 50,000-row Taylor
`group = g4` 1.96 s to 0.22 s; 80-replicate `group = g4` 1.69 s to 0.25 s.
`get_means()` 50,000-row Taylor, 60 cells, 3.59 s to 0.71 s; 80-replicate
`group = g20` 0.95 s to 0.47 s. `get_totals()`, `get_variance()`,
`get_covariance()` and `get_ratios()` were not profiled. No block size was
measured before D12.

---

## Pipeline tier

recommended — the change touches 15 files, changes how six exported
functions compute their variance, and changes the condition order under
`survey.lonely.psu = "fail"`.
