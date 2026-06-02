# Comprehension — nonprob-jackknife

## Problem

`as_survey_nonprob()` currently hard-rejects any `type` other than `"bootstrap"` (line 1287–1301 of `core-constructors.R`, error class `surveycore_error_type_invalid`). The goal is to lift that restriction so that users who hold jackknife replicate weights — each column being a set of calibrated weights re-estimated on a leave-one-unit-out or leave-one-cluster-out draw — can register them in a `survey_nonprob` object and obtain jackknife variance estimates through the existing `_replicate_*` estimation path. Elliott and Valliant (2017) §3 explicitly sanction the jackknife for nonprobability quasi-randomization inference: *"for the jackknife, clusters within strata should be dropped, with standard weighting up by the number of clusters divided by the number of clusters retained to maintain the stratum size"* and *"for each bootstrap or jackknife iteration, the pseudo-weights should be recomputed as well as the point estimator using the dropped-out or resampled data."* The variance engine `(.svy_rep_var())` already handles both methods identically — the only difference lies in the `scale` and `rscales` constants that encode the method-specific formula.

## Formulas

### General replicate-weight variance formula (as implemented in `.svy_rep_var()`)

```
V = scale * sum_{r=1}^{R} ( rscales[r] * (theta_r - theta_center)^2 )
```

where:
- `scale` — a single numeric scalar stored in `design@variables$scale`
- `rscales` — a numeric vector of length `R` stored in `design@variables$rscales`
- `theta_r` — the statistic computed on the r-th replicate weight column
- `theta_center` — if `mse = TRUE`: the full-sample estimate `theta` (MSE form); if `mse = FALSE`: the mean of `theta_r` over replicates with `rscales > 0`
- `R` — number of replicate weight columns (`length(design@variables$repweights)`)

### JK1 jackknife (leave-one-unit-out, no clustering, no stratification)

The standard JK1 variance estimator is:

```
V_JK1 = ((n - 1) / n) * sum_{i=1}^{n} (theta_{(-i)} - theta)^2
```

where `theta_{(-i)}` is the estimate with unit `i` removed and weights rescaled to maintain the weighted total.

Mapping to the formula above:
- `R = n` (one replicate per unit)
- `scale = (R - 1) / R = (n - 1) / n`
- `rscales = rep(1, R)` (each replicate is weighted equally)
- `mse = TRUE` (compare each replicate to the full-sample estimate)

This matches what `as_survey_replicate()` sets for `type = "JK1"` at line 713:
`scale = (n_rep - 1L) / n_rep`.

### JK2 / JKn jackknife (clustered, stratified — Elliott and Valliant 2017 prescription)

For clustered nonprobability samples where replication units are clusters within strata:

```
V_JK = sum_{h=1}^{H} * ((n_h - 1) / n_h) * sum_{i=1}^{n_h} (theta_{(-hi)} - theta)^2
```

where `h` indexes strata, `n_h` is the number of clusters in stratum `h`, and `theta_{(-hi)}` is the estimate with cluster `i` of stratum `h` dropped and the remaining clusters in that stratum upweighted by `n_h / (n_h - 1)`.

In the flat replicate-weight representation:
- `R = sum_h n_h` total replicates
- `scale = 1` (the stratum-level scaling is folded into `rscales`)
- `rscales[r] = (n_h(r) - 1) / n_h(r)` where `h(r)` is the stratum of replicate `r`
- `mse = TRUE`

However, for a user supplying pre-computed jackknife replicate weights (the common case — weights were produced externally by a tool like `surveywts`), the `scale` and `rscales` encoding the JK formula are either supplied explicitly by the user or derived from the replicate weight columns. The `as_survey_replicate()` JKn convention stores `scale = (n_rep - 1) / n_rep` with `rscales = rep(1, n_rep)`, which gives the symmetric JK1 formula. For non-symmetric JKn weights, users supply explicit `rscales`.

### Scale defaults by type

**`as_survey_replicate()` defaults** (symmetric convention):

| Type | `scale` default | `rscales` default |
|------|----------------|-------------------|
| `"JK1"` | `(R-1)/R` | `rep(1, R)` |
| `"JK2"` | `(R-1)/R` | `rep(1, R)` |
| `"JKn"` | `(R-1)/R` | `rep(1, R)` |
| `"bootstrap"` | `1/R` | `rep(1, R)` |

**`as_survey_nonprob()` defaults** (intentionally different for JK2/JKn):

| Type | `scale` default | `rscales` default |
|------|----------------|-------------------|
| `"JK1"` / `"jackknife"` | `(R-1)/R` | `rep(1, R)` |
| `"JK2"` | `1` | **required** (NULL errors) |
| `"JKn"` | `1` | **required** (NULL errors) |
| `"bootstrap"` | `1/R` | `rep(1, R)` |

For `as_survey_nonprob()`, JK2/JKn use `scale = 1` with user-supplied
stratum-specific `rscales[r] = (n_h(r)-1)/n_h(r)` — the Elliott-Valliant
asymmetric encoding. This differs from `as_survey_replicate()`, which uses the
symmetric `(R-1)/R` for all JK types. The `surveycore_error_stratified_jk_rscales_unset`
error enforces that users supply explicit `rscales` for JK2/JKn; the default
`rep(1, R)` would be statistically incorrect for stratified jackknife.

## Gotchas

- **`n = 1` (single replicate column)** — The variance formula degenerates; `(1-1)/1 = 0` gives `V = 0` exactly. This is caught by the existing `repweights_single` check (error class `surveycore_error_repweights_single`), but that error message currently says "Bootstrap variance requires >= 2 replicates." The message must be generalized to cover jackknife too.

- **All `theta_r` identical to `theta`** — `.svy_rep_var()` returns exactly `0.0`; no error is thrown. This is valid behavior (all replicates agree with the full-sample estimate), not a bug. Callers get `se = 0`.

- **All replicates NA in a domain cell** — `.svy_rep_var()` already handles this: it drops NA replicates and errors if none remain (`surveycore_error_all_replicates_na`). The existing `surveycore_warning_domain_replicates_na` warning in `.nonprob_rep_na_warn()` still fires when >5% of replicates are NA.

- **`mse = FALSE` with jackknife** — Valid but unusual. The centered form uses `mean(theta_r)` as the reference instead of `theta`. For JK1 the MSE and centered forms are numerically identical when `rscales` are equal, but this identity breaks for JKn with non-uniform `rscales`. Users who set `mse = FALSE` should understand they are getting the centered form.

- **Provenance check for jackknife** — The existing provenance checks test `calibration$bootstrap == TRUE`. This check must be bypassed or generalized when `type` is a jackknife variant; `calibration$bootstrap` is a bootstrap-specific field and does not apply to jackknife provenance. The relevant error class is `surveycore_error_provenance_not_bootstrap`, which fires only when `calibration` is non-NULL. If users pass a `calibration` object that has `calibration$bootstrap = FALSE` with `type = "JK1"`, the current code would incorrectly reject a valid jackknife setup. The fix: skip the `calibration$bootstrap` check when `type %in% c("JK1", "JK2", "JKn")`.

- **`calibration$R` mismatch for jackknife** — The `calibration$R` field counts the number of replicates. This check remains valid regardless of type and should be retained.

- **Downstream type-checking in `analysis-totals-helpers.R`** — `.total_cell()` dispatches `survey_nonprob` with repweights to `.replicate_total_cell()`. That function reads `design@variables$scale`, `design@variables$rscales`, and `design@variables$mse` — all of which are set correctly for JK types using the same defaults as `as_survey_replicate()`. No changes required in the analysis layer.

- **The `repweights_single` error message** — Currently says "Bootstrap variance requires >= 2 replicates." This is wrong when `type` is jackknife. Must be updated to say replicate-weight variance requires >= 2 replicates, regardless of type. The message is evaluated before `type` is validated, so the fix is to make the message type-agnostic.

- **`calibration$type` field** — No such field exists in the current `surveywts` calibration provenance schema. There is no ground-truth `type` field to cross-check. The constructor cannot validate that the supplied `type` matches what was used to produce the replicate weights; that responsibility rests with the user.

- **`visible_vars` propagation** — The `@variables` list for `survey_nonprob` includes `visible_vars = NULL`. This key is not JK-specific and needs no change.

## Reference mapping

- Elliott and Valliant (2017) §3 (Quasi-randomization, variance estimation paragraph) → Design decision: jackknife is a valid variance estimator for nonprobability samples when pseudo-weights are recomputed within each leave-one-out iteration. This is the explicit bibliographic justification for allowing `type %in% c("JK1", "JK2", "JKn")` in `as_survey_nonprob()`.

- Elliott and Valliant (2017) §3 ("for the jackknife, clusters within strata should be dropped, with standard weighting up…") → Design decision: the user is responsible for computing jackknife replicate weights that implement this prescription. `as_survey_nonprob()` accepts pre-computed weights without re-verifying the within-replicate computation.

- Elliott and Valliant (2017) §3 ("for each bootstrap or jackknife iteration, the pseudo-weights should be recomputed as well as the point estimator") → Design decision: the documentation for `as_survey_nonprob(repweights = ...)` must state that each jackknife replicate column must contain calibrated weights re-estimated on the leave-out sample, not merely the base weights with one unit zeroed out.

- `as_survey_replicate()` JK1 default (line 713: `scale = (n_rep - 1L) / n_rep`) → Design decision: `as_survey_nonprob()` applies the same default scale logic for JK1/JK2/JKn, imported from the `as_survey_replicate()` switch statement. No separate formula needed.

- `.svy_rep_var()` (variance-replicate.R, lines 26–47) → Design decision: no changes needed in the variance engine. The formula `scale * sum(rscales * (theta_r - theta)^2)` is type-agnostic; jackknife and bootstrap differ only in what `scale` and `rscales` are set to.

- `surveycore_error_type_invalid` (error-messages.md row NB-1) → Design decision: this error class is **renamed** to `surveycore_error_type_unsupported_for_nonprob` in this PR. The new name distinguishes types that are valid in `as_survey_replicate()` but unsupported for `survey_nonprob` (BRR, Fay, ACS) from a generic invalid-type error. The error message changes from "must be `'bootstrap'`" to listing the now-valid set: `c("bootstrap", "JK1", "JK2", "JKn", "jackknife")`.

## Assumptions

- **Pseudo-weights are recomputed per replicate** — The package cannot verify this; it trusts the user. If a user passes jackknife replicate columns that were not re-calibrated within each leave-out draw, the variance estimate will be model-inconsistent (underestimating calibration uncertainty). This assumption is identical to the existing bootstrap assumption and must be documented in the roxygen `@param repweights` block.

- **`type` is a user-supplied string** — `as_survey_nonprob()` does not use `match.arg()` for `type` (unlike `as_survey_replicate()`). The current code validates type by exact-match comparison `identical(type, "bootstrap")`. The fix must replace this with a membership check against the allowed set. The allowed set for nonprob is `c("bootstrap", "JK1", "JK2", "JKn")` — not all types from `as_survey_replicate()`, because types like `"BRR"`, `"Fay"`, `"ACS"`, `"successive-difference"` have no standard application to nonprobability variance.

- **`survey_nonprob` class documentation lists only `"bootstrap"` as a valid type** — The roxygen for `survey_nonprob` in `core-classes.R` (line ~927) says `type: Replicate type ("bootstrap"), or NULL`. This string must be updated to `"bootstrap"`, `"JK1"`, `"JK2"`, or `"JKn"`.

- **JK types do not require `R >= 2` in a manner different from bootstrap** — The `repweights_single` guard (error class `surveycore_error_repweights_single`) still fires for JK designs with exactly 1 replicate. The error message is currently bootstrap-specific; it should be generalized. However, the error class name stays the same.

- **No `calibration$jackknife` field check is needed** — The provenance object schema from `surveywts` does not define a `jackknife` boolean analogous to `calibration$bootstrap`. Therefore when `calibration` is non-NULL and `type %in% c("JK1", "JK2", "JKn")`, only the `calibration$R` count-match check is run; the `calibration$bootstrap` truthiness check is skipped.

- **`mse = TRUE` remains the correct default for all replicate types in nonprob** — For jackknife on nonprobability samples, the MSE form (comparing each replicate estimate to the full-sample estimate) is analytically appropriate and matches the Elliott-Valliant prescription. The `mse` default does not change.
