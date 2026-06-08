# Spec — calibrate-survey-taylor

**Status**: DRAFT (post-spec-review 3r)
**Target version**: X.Y.Z.9000
**PR range**: PR 1–2

---

## Scope

### In
- Add `@calibration` property to `survey_taylor` (currently has `properties = list()`)
- Add `@calibration` property to `survey_replicate` (currently has `properties = list()`)
- `survey_nonprob` already has `@calibration` (line 986 of `R/core-classes.R`) — no change needed
- Export `as_caldata(base_weights, g_weights, model_matrix)` — constructor for a single caldata element; surveywts calls this after computing new weights to build the value to store in `@calibration`
- Internal helper `.apply_caldata_projection(u, caldata)` that applies the QR projection to a linearization vector
- Calibration-aware variance: `.taylor_mean()`, `.taylor_mean_cell()`, and `.taylor_total()` apply `.apply_caldata_projection()` when `design@calibration` is non-NULL and non-empty
- Degrees-of-freedom adjustment in calibrated designs (see §Degrees-of-freedom adjustment)
- New rows in `plans/error-messages.md` as needed (see error table below)

### Out
- Any g-weight computation in surveycore — `calibrate()`, `rake()`, and `poststratify()` live in `surveywts`, which calls `as_caldata()` and populates `@calibration` on the returned object
- Calibration-adjusted variance for `survey_replicate` and `survey_nonprob` — for replicate designs, each replicate is independently calibrated by surveywts, so replication already captures calibration variance; `@calibration` is stored on these classes for provenance and printing only, not consumed by any variance path in surveycore
- Calibration-adjusted variance for `survey_glm()` / `survey_glm_fit` (deferred to a follow-on spec). Per Rao, Yung & Hidiroglou (2002) equation (2.10), the GLM case requires the calibration residual of the score function `e_k*(θ̂) = u_k(θ̂) − B̂ᵀ(θ̂)z_k` scaled by `Ĵ⁻¹`, not the simpler outcome residual used for means/totals. A user who uses a calibrated `survey_taylor` with `survey_glm()` will receive **correct but unadjusted (conservative) SEs** — valid for inference, but not the efficient GREG estimator. This must be documented on `as_caldata()`.
- Within-PSU calibration (`stage > 0`) — not supported in v1; `.apply_caldata_projection()` errors with a typed class if any stored caldata entry has `stage != 0L`
- Logit calibration family (surveywts concern)
- Trim argument for g-weight clipping (surveywts concern)
- `survey_twophase` calibration
- Two-phase GREG variance

---

## Architecture

**Files touched:**
- `R/core-classes.R` — add `@calibration` property to `survey_taylor` and `survey_replicate`
- `R/calibration.R` — new file; `as_caldata()`, `.apply_caldata_projection()`, `.maybe_apply_calibration()`, and `.get_calibration_df_reduction()` live here
- `R/variance-taylor.R` — modify `.taylor_mean()` and `.taylor_total()` to call `.maybe_apply_calibration()` and `.get_calibration_df_reduction()`
- `R/analysis-means-helpers.R` — modify `.taylor_mean_cell()` to call `.maybe_apply_calibration()` and `.get_calibration_df_reduction()` (covers domain/group estimation)
- `R/update-design.R` — add warning when weight column changes on a calibrated design
- `NAMESPACE` — export `as_caldata`
- `plans/error-messages.md` — add new error classes (see below)

**Functions added:**
- `as_caldata(base_weights, g_weights, model_matrix)` — exported constructor; returns a single caldata list element
- `.apply_caldata_projection(u, caldata)` — internal QR projection for calibration-adjusted variance
- `.maybe_apply_calibration(linearized, design)` — internal; applies `.apply_caldata_projection()` if `design@calibration` is non-NULL and non-empty; returns `linearized` unchanged otherwise
- `.get_calibration_df_reduction(design)` — internal; returns `sum(vapply(design@calibration, function(cd) cd$qr$rank, integer(1)))` when calibration is active, `0L` otherwise

**Functions modified:**
- `.taylor_mean()` in `R/variance-taylor.R`
- `.taylor_total()` in `R/variance-taylor.R`
- `.taylor_mean_cell()` in `R/analysis-means-helpers.R` — covers all domain/group estimation paths
- `update_design()` in `R/update-design.R` — warn when weight column changes on a design with `@calibration` non-NULL

**Class changes:**
- `survey_taylor`: add `@calibration` property (`S7::new_property(default = NULL)`)
- `survey_replicate`: add `@calibration` property (`S7::new_property(default = NULL)`)
- `survey_nonprob`: no change — `@calibration` already present

**New error classes** (add to `plans/error-messages.md`):

| Class | Trigger |
|-------|---------|
| `surveycore_error_caldata_weights_nonpositive` | `base_weights` contains non-positive values |
| `surveycore_error_caldata_weights_missing` | `base_weights` contains `NA`, `NaN`, or `Inf` |
| `surveycore_error_caldata_gweights_nonpositive` | `g_weights` contains non-positive values |
| `surveycore_error_caldata_gweights_missing` | `g_weights` contains `NA`, `NaN`, or `Inf` |
| `surveycore_error_caldata_gweights_length_mismatch` | `length(g_weights) != length(base_weights)` |
| `surveycore_error_caldata_weights_near_zero` | `g_weights * sqrt(base_weights)` contains near-zero values (< `.Machine$double.eps^0.5`) |
| `surveycore_error_caldata_dimension_mismatch` | `nrow(model_matrix) != length(base_weights)` |
| `surveycore_error_caldata_empty_model_matrix` | `model_matrix` has 0 columns |
| `surveycore_error_caldata_model_matrix_invalid` | `model_matrix` contains `NA`, `NaN`, or `Inf` |
| `surveycore_error_caldata_within_stage_unsupported` | Any caldata element has `stage != 0L` |
| `surveycore_error_caldata_projection_dimension_mismatch` | `nrow(u) != length(cd$w)` in `.apply_caldata_projection()` |
| `surveycore_error_caldata_invalid_element` | A `NULL` element found in `design@calibration` list |
| `surveycore_warning_weight_change_invalidates_calibration` | `update_design()` changes weight column on a design with `@calibration` non-NULL |
| `surveycore_warning_zero_df_after_calibration` | Calibration df reduction `>=` design df; `df_final` clamped to `max(1L, df_final)` |

---

## `@calibration` property

Shared across `survey_taylor`, `survey_replicate`, and `survey_nonprob`.

**Type**: `NULL` | non-empty `list`

**Default**: `NULL` (uncalibrated design)

**Structure when non-NULL**: A list of one or more caldata elements, one per calibration call (accumulated). Each caldata element is a named list:

```
list(
  qr    = <QR decomposition>,   # qr() result of sqrt(base_w) * model_matrix; class "qr"
  w     = <numeric vector>,     # g_weights * sqrt(base_weights); length nrow(@data)
  stage = 0L,                   # always 0L (population-level calibration)
  index = NULL                  # NULL = all units in scope (v1 only)
                                 # Future: logical index vector for within-stratum calibration
)
```

The `qr` and `w` slots implement `v(a_k(s) · e_k)` from Rao, Yung & Hidiroglou (2002) §2.3 equation (2.5), which is preferred over `v(e_k)` because it better tracks conditional variance. Specifically, `w = g_weights * sqrt(base_weights)` is the `a_k(s)` scaling factor in the `v(a_k e_k)` form; `qr = qr(sqrt(base_weights) * model_matrix)` is the auxiliary column space for the residual projection. This matches the `survey` package's `calibrate.survey.design2()` implementation.

**Append semantics**: surveywts appends a new caldata element each time a calibration operation is applied (e.g., once for `calibrate()`, K times for `rake()` with K margins). Variance functions loop over all stored elements in order.

**Sequential projection for raking**: See §Raking and sequential projection for the mathematical justification and literature citations.

**g-weight assumption**: The `g_weights` argument to `as_caldata()` must be population-level calibration adjustment factors. All units in the design receive their g-weight simultaneously. Stratum-specific calibration is not supported in v1.

**Consumer by class:**
- `survey_taylor`: caldata is consumed by `.apply_caldata_projection()` in `.taylor_mean()` / `.taylor_mean_cell()` / `.taylor_total()`
- `survey_replicate`: stored for provenance only; NOT consumed by any variance path. For replicate designs, each replicate must be independently calibrated by surveywts. If the base design is calibrated but replicates are not, the stored `@calibration` will NOT be reflected in SEs (which will be conservative). Ensure your surveywts pipeline calibrates each replicate independently.
- `survey_nonprob`: stored for provenance only; not consumed by any variance path

**S7 validator**: Accepts `NULL` or any `list`. Deep structural validation is the responsibility of `as_caldata()`, not the S7 validator.

---

## Function contracts

### `as_caldata(base_weights, g_weights, model_matrix)`

**Signature**:
```r
as_caldata <- function(base_weights, g_weights, model_matrix)
```

**Arguments**:

- `base_weights` — Positive numeric vector of length n. The survey weights before calibration was applied (i.e., `design@data[[design@variables$weights]]` before surveywts modified them). Must be strictly positive; must not contain `NA`, `NaN`, or `Inf`; both validated.

- `g_weights` — Positive numeric vector of length n. The per-unit calibration adjustment factors such that `calibrated_weight_i = base_weight_i * g_i`. Must be population-level (not stratum-specific). Must be positive; must not contain `NA`, `NaN`, or `Inf`; length must equal `length(base_weights)`; all validated. Additionally, `g_weights * sqrt(base_weights)` must not contain near-zero values (threshold: `.Machine$double.eps^0.5`). Near-zero values would cause numerical instability in `.apply_caldata_projection()` via `u / cd$w` division.

- `model_matrix` — Numeric matrix with n rows and p ≥ 1 columns. The calibration auxiliary matrix, i.e., `model.matrix(formula, data)` or the equivalent dummy-coded matrix constructed by surveywts from its `variables` argument. Must not contain `NA`, `NaN`, or `Inf` values.

**Returns**: A named list with four elements:
```r
list(
  qr = qr(sqrt(base_weights) * model_matrix),
  w = g_weights * sqrt(base_weights),
  stage = 0L,
  index = NULL # NULL = all units in scope; future extension for within-stratum calibration
)
```

The `w` slot is `a_k(s) = g_i * sqrt(w_i)` from RYH (2002) eq (2.5) — the g-weight scaling factor for the `v(a_k e_k)` variance form. The `qr` slot is the QR decomposition of `sqrt(W) * X` from Deville & Sarndal (1992) equation (3).

**Note on GLM**: See §Scope Out for the GLM limitation. Builders must add a `@details` warning to `as_caldata()` roxygen docs pointing users to the GLM scope-out note.

**Errors**:

| Condition | Class |
|-----------|-------|
| `base_weights` contains `NA`, `NaN`, or `Inf` | `surveycore_error_caldata_weights_missing` |
| `base_weights` contains non-positive values | `surveycore_error_caldata_weights_nonpositive` |
| `g_weights` contains `NA`, `NaN`, or `Inf` | `surveycore_error_caldata_gweights_missing` |
| `g_weights` contains non-positive values | `surveycore_error_caldata_gweights_nonpositive` |
| `length(g_weights) != length(base_weights)` | `surveycore_error_caldata_gweights_length_mismatch` |
| `g_weights * sqrt(base_weights)` contains values < `.Machine$double.eps^0.5` | `surveycore_error_caldata_weights_near_zero` |
| `nrow(model_matrix) != length(base_weights)` | `surveycore_error_caldata_dimension_mismatch` |
| `model_matrix` has 0 columns | `surveycore_error_caldata_empty_model_matrix` |
| `model_matrix` contains `NA`, `NaN`, or `Inf` | `surveycore_error_caldata_model_matrix_invalid` |
| `length(base_weights) == 0` | `surveycore_error_caldata_weights_nonpositive` (empty vector has no positive values) |

**Warnings**: None.

**Roxygen2 tags** (required per surveycore conventions):
- `@export`
- `@family constructors`
- `@return` A named list with elements `qr` (class `"qr"`), `w` (numeric vector of length n), `stage` (`0L`), and `index` (`NULL`; all rows in scope).
- `@examples` A minimal working example showing `as_caldata()` with 3–5 rows of synthetic data, then assigning the result to `design@calibration`.
- `@details` Note the GLM limitation (see §Scope Out): using a calibrated `survey_taylor` with `survey_glm()` produces correct but conservative SEs until GREG-GLM variance is implemented.

**Edge cases**:
- Single-column model matrix (`~1`, intercept only): valid. `qr()` on an n×1 matrix is well-defined.
- `g_weights` all equal to 1.0: valid. Returns caldata with an identity-like projection; `.apply_caldata_projection()` will produce residuals identical to the uncalibrated path (no SE reduction).
- `model_matrix` columns that are perfectly collinear: the QR decomposition stores the rank-deficient structure without error; `qr.resid()` handles this correctly via the rank stored in `$rank`. No additional check needed here; rank deficiency is the responsibility of surveywts before calling `as_caldata()`. Note: any DoF adjustment must use `cd$qr$rank`, not `ncol(model_matrix)`.
- `length(base_weights) == 0` (empty design): treated as an error — a non-positive check on an empty numeric vector has 0 positive values, which fires `surveycore_error_caldata_weights_nonpositive`. Spec does not need to define a special "valid empty QR" path.

---

### `.apply_caldata_projection(u, caldata)`

**Not exported.** Applies the QR projection from Rao, Yung & Hidiroglou (2002) equation (2.5) to a linearization vector.

**Inputs**:
- `u` — Numeric matrix, the pre-projection linearization vector (n × k). For means: `(y_i − ȳ_w) * w_i / Σw_j`. For totals: `y_i * w_i`.
- `caldata` — A non-empty list of caldata elements (the full `design@calibration` list, pre-filtered to ensure `length > 0`).

**Returns**: Numeric matrix, same dimensions as `u`. Each stored calibration's column space is projected out in order:
```r
for (cd in caldata) {
  u <- qr.resid(cd$qr, u / cd$w) * cd$w
}
```
This implements `v(a_k(s) · e_k)` — the variance of g-weighted calibration residuals — NOT the alternative `v(e_k)` form. Per RYH (2002) §2.3, `v(a_k e_k)` tracks conditional variance better and is the preferred estimator.

For multi-margin calibration (raking), see §Raking and sequential projection for why sequential projection is equivalent to the joint GREG variance.

**Guards**:

0. **Empty list pass-through**: If `length(caldata) == 0L`, return `u` unchanged immediately: `if (length(caldata) == 0L) return(u)`. This makes the function safe to call directly (e.g., in tests) even though callers pre-filter with `length > 0`.

1. **All-NA pass-through**: If all entries of `u` are NA, return `u` unchanged immediately (`if (all(is.na(u))) return(u)`). This preserves existing NA propagation behavior for all-missing outcomes.

1b. **NULL element guard**: Before entering the loop, validate that no element of `caldata` is `NULL`:
   ```r
   bad_idx <- which(vapply(caldata, is.null, logical(1)))
   if (length(bad_idx) > 0L) {
     cli::cli_abort(
       c(
         "x" = "caldata element(s) {bad_idx} are NULL.",
         "i" = "All @calibration list elements must be constructed via as_caldata().",
         "v" = "Inspect design@calibration for NULL entries."
       ),
       class = "surveycore_error_caldata_invalid_element"
     )
   }
   ```

2. **Stage guard**: Before entering the loop, validate that all caldata entries have `stage == 0L`:
   ```r
   if (any(vapply(caldata, function(cd) cd$stage != 0L, logical(1)))) {
     cli::cli_abort(
       c(
         "x" = "Within-PSU calibration (stage != 0) is not supported in v1.",
         "i" = "Found {sum(...)} caldata element(s) with stage != 0L.",
         "v" = "Use population-level calibration only."
       ),
       class = "surveycore_error_caldata_within_stage_unsupported"
     )
   }
   ```

3. **Dimension guard**: Inside the loop, before each projection, validate `nrow(u) == length(cd$w)`:
   ```r
   if (nrow(u) != length(cd$w)) {
     cli::cli_abort(
       c(
         "x" = "Calibration projection dimension mismatch.",
         "i" = "Linearization vector has {nrow(u)} rows; caldata `w` has length {length(cd$w)}."
       ),
       class = "surveycore_error_caldata_projection_dimension_mismatch"
     )
   }
   ```

**Called by**: calibration-aware code path in `.taylor_mean()`, `.taylor_mean_cell()`, and `.taylor_total()` when the projection condition is met (see §Calibration-aware modifications).

---

### Calibration-aware modifications

The projection condition `!is.null(design@calibration) && length(design@calibration) > 0L` and the DoF reduction computation `sum(vapply(design@calibration, function(cd) cd$qr$rank, integer(1)))` are extracted into the two shared helpers defined in §Architecture:

- `.maybe_apply_calibration(linearized, design)` — returns `.apply_caldata_projection(linearized, design@calibration)` when calibration is active; returns `linearized` unchanged otherwise
- `.get_calibration_df_reduction(design)` — returns the total rank sum when calibration is active; returns `0L` otherwise

**In `.taylor_mean()`**, after computing `linearized = (y - mean_w) * w / sum_w` and before `.svy_recvar()`:
```r
linearized <- .maybe_apply_calibration(linearized, design)
cal_df_reduction <- .get_calibration_df_reduction(design)
```

**In `.taylor_mean_cell()`** (in `R/analysis-means-helpers.R`), after computing the influence matrix and before `.svy_recvar()`: same two calls. This ensures domain/group estimates respect calibration.

**In `.taylor_total()`**, same two calls with `linearized = y * w`.

No other callers of `.svy_recvar()` are modified in this spec. Ratio, correlation, quantile, and GLM variance paths remain uncalibrated in v1.

---

## Degrees-of-freedom adjustment

Calibration reduces the degrees of freedom available for variance estimation. The standard GREG theory adjustment (Sarndal, Swensson & Wretman 1992 Ch. 6; RYH 2002 §2.3) subtracts the rank of the calibration model matrix from the design df.

**Adjustment rule**: For each caldata element in `design@calibration`, subtract `cd$qr$rank` (not `ncol(cd$qr$qr)`, to handle rank-deficient cases correctly) from the design df.

**Implementation**: `.maybe_apply_calibration()` and `.get_calibration_df_reduction()` are called together. `cal_df_reduction` (returned by `.get_calibration_df_reduction()`) is then used:
```r
df_final <- df_design - cal_df_reduction
```

**Negative df guard** (R-7): After computing `df_final`, if `df_final <= 0L`, emit `surveycore_warning_zero_df_after_calibration` and clamp:
```r
if (df_final <= 0L) {
  cli::cli_warn(
    c(
      "!" = "Calibration reduces design df ({df_design}) to {df_final}.",
      "i" = "CIs and p-values may be invalid.",
      "v" = "Reduce the number of calibration columns or use a larger design."
    ),
    class = "surveycore_warning_zero_df_after_calibration"
  )
  df_final <- max(1L, df_final)
}
```

**Multi-margin raking**: For K caldata entries, the total df reduction is `sum(cd_1$qr$rank + ... + cd_K$qr$rank)`. See §Raking and sequential projection.

**Reporting**: The `df` column in the output tibble from `get_means()` and `get_totals()` must reflect the calibration-adjusted df. No separate `df_adjusted` column is added in v1.

---

## Quality gates

1. A freshly constructed `survey_taylor` has `@calibration == NULL`.
2. A freshly constructed `survey_replicate` has `@calibration == NULL`.
3. `as_caldata()` returns a list with names `c("qr", "w", "stage", "index")`.
4. `as_caldata()` returns `stage = 0L` and `index = NULL` always.
5. After assigning `design@calibration <- list(as_caldata(...))`, `length(design@calibration) == 1L`.
6. `.taylor_mean()` and `.taylor_total()` produce identical results to the uncalibrated path when `design@calibration` is `NULL` (regression safety).
7. Post-calibration SE from `get_means()` on a `survey_taylor` whose `@calibration` was populated by `as_caldata()` matches `survey::svymean()` on the same calibrated design within tolerance `1e-8`.
8. Post-calibration SE is ≤ uncalibrated SE when the calibration auxiliary variable correlates with the outcome.
9. The S7 validators of `survey_taylor` and `survey_replicate` pass when `@calibration` is `NULL` and when it is a non-empty list.
10. **Raking quality gate**: When `design@calibration` contains K caldata entries from a multi-margin calibration (raking), SE from `get_means()` matches `survey::rake()` output within tolerance `1e-8`.
11. `get_means()` on a `survey_replicate` with `@calibration` set returns the same SE as on the same design without `@calibration` (calibration is stored for provenance only; replicate variance is unaffected).
12. `update_design()` emits `surveycore_warning_weight_change_invalidates_calibration` when changing the weight column on a design with `@calibration` non-NULL.
13. `.apply_caldata_projection()` returns `u` unchanged when called with an empty caldata list (`list()`).
14. `.apply_caldata_projection()` errors with `surveycore_error_caldata_invalid_element` when the caldata list contains a `NULL` element.

---

## update_design() calibration guard

When `update_design()` changes the weight column (`@variables$weights`) on a design whose `@calibration` is non-NULL, emit `surveycore_warning_weight_change_invalidates_calibration`:

```r
cli::cli_warn(
  c(
    "!" = "Weight column changed on a calibrated design.",
    "i" = "{.field @calibration} was built from the previous weight column.",
    "v" = "Re-run calibration or set {.code design@calibration <- NULL} before analysing."
  ),
  class = "surveycore_warning_weight_change_invalidates_calibration"
)
```

This guard lives in `R/update-design.R`, not in the calibration files. The `@calibration` value is **not** automatically cleared — the user must clear it explicitly if they wish.

---

## Raking and sequential projection

This section is the single canonical statement of the mathematical justification. All other sections (§`@calibration` property, §`.apply_caldata_projection()` Returns, §Degrees-of-freedom adjustment) reference this section rather than repeating the argument.

**Result**: For K-margin raking, applying the QR projection sequentially over K caldata entries is mathematically equivalent to joint GREG variance.

**Justification**:
1. Deville & Sarndal (1992) cases 1 (linear calibration) and 2 (raking) establish that both calibration estimators share the same asymptotic variance formula, which reduces to the GREG variance.
2. Kolenikov (2014) §1.5 applies this to iterative proportional fitting: after IPF convergence, raking's asymptotic variance equals the joint GREG variance (citing Deville & Sarndal 1992 case 2).
3. RYH (2002) §2.3 eq (2.5) gives the implementation formula `v(a_k(s) · e_k)`. Sequential loop over K caldata entries faithfully replays the IPF calibration history.
4. Because each margin's caldata QR encodes part of the joint column space, the cumulative df reduction is the rank of the combined column space — which sequential projection achieves automatically.

---

## Pipeline split

**Recommended** — PR 1: class changes (`@calibration` on `survey_taylor` + `survey_replicate`) and `as_caldata()`. PR 2: variance integration (`.apply_caldata_projection()` + `.taylor_mean()`/`.taylor_mean_cell()`/`.taylor_total()` modification, DoF adjustment, and numerical validation tests).

---

## References

- Deville, J.C. & Sarndal, C.E. (1992). Calibration estimators in survey sampling. JASA 87(418) — equations (3), (7); cases 1 (linear) and 2 (raking).
- Kolenikov, S. (2014). Calibrating survey data using iterative proportional fitting (raking). Stata Journal 14(1). §1.5 establishes raking asymptotic variance = joint GREG variance (via Deville & Sarndal 1992 case 2).
- Rao, J.N.K., Yung, W. & Hidiroglou, M.A. (2002). Estimating equations for the analysis of survey data using poststratification information. Sankhya 64-A §2.3 eq (2.5) — the `v(a_k e_k)` form; eq (2.10) — GLM exclusion.
- Sarndal, C.E., Swensson, B. & Wretman, J.H. (1992). Model Assisted Survey Sampling. Ch. 6 — GREG estimator; DoF adjustment.
- Lumley, T. (2010). Complex Surveys: A Guide to Analysis Using R. Ch. 5 — conceptual overview.
- survey::grake.R `calibrate.survey.design2()` — reference implementation for caldata structure.
- survey::multistage.R `svyrecvar()` — reference implementation for sequential QR projection.
