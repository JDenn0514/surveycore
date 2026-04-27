# Spec — polychoric-corr

**Status**: DRAFT
**Target version**: 0.6.x.9000 → 0.7.0
**PR range**: PR 1–3 (see `implementation-plan.md`)

---

## Scope

### In

1. Extend the exported `get_corr()` function with a `method = "pearson"` argument (matched inside the function via `match.arg(method, c("pearson", "polychoric", "polyserial"))`; passing a non-matching value is a user error via the standard `match.arg` signal) that selects the estimator used for each pair.
2. Weighted **polychoric** correlation for two ordinal variables under a bivariate-normal latent model (Olsson 1979; Mannan 2025 §5.2, §6.1).
3. Weighted **polyserial** correlation for one ordinal + one continuous variable (Cox 1974; Mannan 2025 §5.1, §7.1).
4. Variance estimation for `method ∈ {"polychoric", "polyserial"}`:
   - `survey_taylor` — pseudo-Taylor linearization on the Fisher-z scale using a numerical influence-function (perturbation) approximation, then back-transformed to the ρ scale via the delta method. Plugs into the existing `survey_taylor` influence-function variance path.
   - `survey_replicate` — re-estimate both thresholds and ρ per replicate, variance from the design's stored replicate weights and scale factors (JK, BRR, Fay, bootstrap — whatever `@variables$replicate_type` declares).
5. CI construction on the Fisher-z scale, back-transformed and truncated to `[-1, 1]` (Mannan 2025 §8.1–8.2).
6. Auto-detection of the ordinal / continuous side for polyserial based on column type (no new user argument).
7. New internal helpers in a new file plus one modification to `R/analysis-corr.R` to dispatch `method`.
8. New imports: `pbivnorm` for the bivariate-normal CDF.
9. One exported argument added; no new exported functions; no class changes.
10. Performance note: for `method ∈ {"polychoric", "polyserial"}` on a
    `survey_taylor` design, the variance path performs O(n) re-optimizations per
    variable pair (perturbation-based influence function). For large n and many
    pairs, passing a `survey_replicate` design is faster.

### Out

1. **Generating** Rao–Wu or any other resampling weights. `survey_replicate` consumes stored replicate columns only; the spec adds nothing here.
2. Support for `method ∈ {"polychoric", "polyserial"}` on `survey_twophase` or `survey_nonprob` designs — errors with `surveycore_error_polychoric_design_unsupported` in v1. Pearson on those designs is unchanged.
3. Support for `method ∈ {"polychoric", "polyserial"}` on a `survey_collection` input — dispatch over the collection still fires for the Pearson branch; the per-survey call raises `surveycore_error_polychoric_design_unsupported` when the underlying survey is twophase/nonprob. Collections of `survey_taylor` / `survey_replicate` designs work by transitively calling the per-survey path via the existing `.dispatch_over_collection()` machinery.
4. Exposing optimizer tolerance as a user argument.
5. A user-visible `variance = "taylor" | "replicate"` override that decouples variance from design class. Dispatch stays tied to design class, as it does today.
6. Diagnostic tests of the bivariate-normality assumption — documented as an unverified assumption, not a runtime check.

---

## Architecture

- **Files touched**:
  - `R/analysis-corr.R` — modified: `get_corr()` gains `method` argument, dispatches to the new branch when `method != "pearson"`, passes through new validations, stores `method` in result `meta()`.
  - `R/analysis-corr-helpers.R` — unchanged except possibly a conditional early-exit in `.corr_vcov_pair()` dispatch (not required by this spec; branching happens in `get_corr()` before pair-level vcov dispatch).
  - `R/analysis-corr-latent.R` — **new**: all polychoric / polyserial estimator, variance, and helper code.
  - `NAMESPACE` — regenerated; no new exports, but `get_corr` signature changes.
  - `DESCRIPTION` — `Imports: pbivnorm (>= 0.6.0)` added.
  - `NEWS.md` — user-facing bullet describing the new `method =` values.
  - `man/get_corr.Rd` — regenerated from roxygen.
  - `plans/error-messages.md` — already updated with PC-1 through PC-14.

- **Functions added** (all internal, not exported):
  - `.corr_latent_pair(design, x_col, y_col, method, active_domain, na.rm, ...)` — top-level dispatcher: estimates ρ̂, computes variance by design class, returns a list compatible with the structure consumed by the long/wide assembly steps of `get_corr()`.
  - `.corr_detect_ordinal(col, integer_cardinality_cutoff = 10L)` — classify a column as `"ordered"`, `"factor"` (unordered), `"integer_ordinal"`, `"continuous"`, or `"ambiguous"`.
  - `.corr_canonicalize_polyserial(x_col, y_col, data)` — return `list(ordinal_col = ..., continuous_col = ...)` or error with `surveycore_error_polyserial_requires_mixed_types` / `surveycore_error_polyserial_canonicalization_ambiguous`.
  - `.corr_estimate_thresholds(ordinal_vec, weights, active_domain)` — returns `list(thresholds = numeric, levels = character|integer, dropped_levels = ...)`; handles zero-weight levels, warns with `surveycore_warning_polychoric_zero_count_level`.
  - `.corr_weighted_standardize(continuous_vec, weights, active_domain)` — returns `list(z = numeric, mean_w, sd_w)` using population (not sample) SD per Cox (1974).
  - `.corr_polychoric_loglik(rho, cell_weights, thresholds_x, thresholds_y)` — scalar weighted log-likelihood; applies numerical floor to cell probabilities and tracks whether any floor was active.
  - `.corr_polyserial_loglik(rho, z, ordinal_level, thresholds, weights)` — scalar weighted log-likelihood.
  - `.corr_polychoric_mle(ordinal_x, ordinal_y, weights, active_domain, eps = 1e-6)` — runs threshold estimation then `stats::optimize()` over `(-1 + eps, 1 - eps)`. Returns `list(rho, converged, thresholds_x, thresholds_y, n_cells_obs, n_sparse, cell_counts, levels_x, levels_y)` or signals `surveycore_error_polychoric_optim_failed`.
  - `.corr_polyserial_mle(ordinal, continuous, weights, active_domain, eps = 1e-6)` — parallel structure to polychoric.
  - `.corr_numerical_influence(design, method, vec_a, vec_b, active_domain, rho_hat_full, eps_pert = 1e-4)` — computes the perturbation-based influence function `IF_i ≈ (ρ̂(w_i → w_i(1+ε)) - ρ̂) / ε` on the Fisher-z scale for each respondent in the active domain. Returns an `n`-length numeric vector. Relies on a batched re-optimization strategy where the expensive threshold step is cached and only the 1-D MLE is rerun per respondent.
  - `.corr_taylor_variance_latent(design, if_z, active_domain)` — plugs the z-scale influence function into the existing `survey_taylor` infrastructure (the same variance machinery used by the Pearson `.vcov_pair_taylor()` path), returning `var_z`.
  - `.corr_replicate_variance_latent(design, method, vec_a, vec_b, active_domain, rho_hat_full)` — iterates replicate weight columns; per replicate, re-estimates thresholds and ρ; computes `Var(ζ̂)` using the design's scale and rscales; returns `list(var_z, n_failed, n_ok, rhos_by_replicate)`; surfaces `surveycore_warning_polychoric_replicate_convergence` or `surveycore_error_replicate_convergence_failure` as appropriate.
  - `.corr_fisher_ci(rho_hat, se_z, conf_level)` — the polychoric / polyserial CI construction uses the existing `.corr_fisher_ci(rho_hat, se_z, conf_level)` helper in `R/analysis-corr-helpers.R` (no duplicate implementation is permitted). Same Fisher-z → tanh back-transform → truncate-to-[−1, 1] pipeline used by the Pearson branch.
  - `.corr_detect_boundary_rho(rho_hat, eps = 1e-4)` — returns `logical(1)` TRUE if `abs(rho_hat) > 1 - eps`. Used at both the PC-9 emission site (always, for either design class) and the PC-14 emission site (Taylor path only). Contract: no side effects; deterministic; single-scalar input/output.
    - **Amended 2026-04-24 (decisions.md D1)**: default `eps` is `1e-4`, not the originally-drafted `1e-6`. The optimizer in `.corr_polychoric_mle()` is clamped to `(-1 + 1e-6, 1 - 1e-6)` and `stats::optimize()` uses tolerance `.Machine$double.eps^0.25 ≈ 1.22e-4`, so the MLE stops ~4.2e-5 short of ±1. A detector at `1e-6` would never fire; a detector at `1e-4` fires on optimizations that genuinely land at the rail.

- **Functions modified**:
  - `get_corr(design, x, group = NULL, format = ..., redundant = ..., diagonal = ..., variance = ..., conf_level = ..., n_weighted = ..., decimals = ..., min_cell_n = ..., na.rm = ..., label_values = ..., label_vars = ..., name_style = ..., method = "pearson", ..., .id = ".survey", .on_missing = "error")` — adds `method` as the last optional scalar argument before `...`. Default `"pearson"`; matched internally via `match.arg(method, c("pearson", "polychoric", "polyserial"))`. Passing a non-matching value is a user error (standard `match.arg` signal).

- **Class changes**: none.

- **Pipeline split**: `recommended` (methods-heavy; new estimator semantics; new dependency; new variance path).

---

## Function contracts

### `get_corr()` — modified contract

- **Signature**:

  ```
  get_corr(
    design,
    x,
    group = NULL,
    format = c("long", "wide"),
    redundant = FALSE,
    diagonal = FALSE,
    variance = "ci",
    conf_level = 0.95,
    n_weighted = FALSE,
    decimals = NULL,
    min_cell_n = 30L,
    na.rm = TRUE,
    label_values = TRUE,
    label_vars = TRUE,
    name_style = "surveycore",
    method = "pearson",
    ...,
    .id = ".survey",
    .on_missing = "error"
  )
  ```

- **Arguments** (only the new argument and changed semantics; other arguments are unchanged from current behavior):
  - `method` — character(1). Scalar character (not NSE). Matched via `match.arg(method, c("pearson", "polychoric", "polyserial"))`. Selects the estimator applied to every pair derived from `x`. One of `"pearson"` (default, existing behavior), `"polychoric"` (both variables in each pair must be ordinal), or `"polyserial"` (each pair must contain exactly one ordinal and one continuous variable). The same `method` applies to every pair; cannot be vectorised. Note: when one ordinal variable has exactly two levels, polychoric reduces to tetrachoric and polyserial reduces to biserial. Both reductions are produced automatically by the same MLE; no separate method value is needed.
  - `x` — semantics unchanged in shape (tidy-select of columns). The non-numeric-drop behavior changes depending on `method`:
    - When `method = "pearson"`: unchanged (non-numeric columns dropped with `surveycore_warning_corr_non_numeric`).
    - When `method = "polychoric"`: columns classified as `"ordered"`, `"factor"`, or `"integer_ordinal"` (via `.corr_detect_ordinal()`) are retained; other columns raise `surveycore_error_polychoric_requires_ordinal`. No silent drop.
    - When `method = "polyserial"`: all selected columns are retained; each pair is canonicalized by type. If a pair fails canonicalization, `surveycore_error_polyserial_requires_mixed_types` or `surveycore_error_polyserial_canonicalization_ambiguous` fires for that pair (hard error, not warning).
  - `variance` — semantics unchanged; all requested variance-derived columns (`"se"`, `"var"`, `"cv"`, `"ci"`, `"moe"`, `"deff"`) for `method ∈ {"polychoric", "polyserial"}` are derived as follows. Variance is computed on the Fisher-z scale: SE(ζ̂) is obtained from the design-based variance of atanh(ρ̂). SE(ρ̂) is the delta-method back-transform SE(ρ̂) = (1 − ρ̂²) · SE(ζ̂). CIs are built on the z scale: (ζ̂ − z_{α/2} SE(ζ̂), ζ̂ + z_{α/2} SE(ζ̂)), then back-transformed via tanh and truncated to [−1, 1]. `deff` is `var_z / var_z_srs`, where var_z is the design-based variance of ζ̂ from the Taylor (or replicate) path, and var_z_srs is the Taylor variance computed on the same z-scale IF vector with design weights replaced by w_i ← 1 (unit weights), holding the thresholds and ρ̂ from the design-weighted fit. Do NOT re-fit the MLE under unit weights.
  - `n_weighted`, `min_cell_n`, `diagonal`, `redundant`, `decimals`, `label_values`, `label_vars`, `name_style`, `format`, `.id`, `.on_missing` — unchanged.

- **Returns**: a `survey_corr` tibble with the same column structure as the Pearson case. `meta(result)$method` is `"polychoric"`, `"polyserial"`, or `"pearson"`. When `method ∈ {"polychoric", "polyserial"}`:
  - Long format: includes `r`, any requested variance columns, `p_value`, `statistic`, `df`, `n`, and optionally `n_weighted`. `p_value` tests H₀: ρ = 0 using the z-scale Wald statistic `ζ̂ / SE(ζ̂)` referred to a standard normal distribution. `statistic` is the z-scale Wald statistic (not the Pearson t-statistic). For `method = "pearson"`, `df = n − 2` (small-sample t-reference). For `method ∈ {"polychoric", "polyserial"}`, `df = NA_integer_` because the MLE is asymptotic and p-values/CIs use the standard-normal z-reference. The discontinuity is intentional. Column labels (e.g., `attr(result$statistic, "label")`) are method-neutral strings (`"statistic"`, not `"t-statistic"` or `"z-statistic"`). Consumers should check `meta(result)$method` to interpret `statistic`, `df`, and `p_value` semantics.
  - Wide format: unchanged from Pearson (only `r` cells); identical column layout.
  - For replicate-path results where some replicates failed but ≤ 20 %, the tibble carries `meta(result)$n_failed_replicates_total` (scalar integer). No per-row attribute is attached; per-pair granularity is not exposed on the result tibble in v1.
  - `meta(result)$bivariate_normal_cdf` is `"pbivnorm"` (the implementation used). Reserved for a future switch if the implementation changes.

- **Errors** (one row per named class):

  | Error class | Condition |
  |---|---|
  | `surveycore_error_polychoric_requires_ordinal` (PC-1) | `method = "polychoric"` and any selected variable is not classifiable as ordinal. |
  | `surveycore_error_polyserial_requires_mixed_types` (PC-2) | `method = "polyserial"` and any pair does not consist of one ordinal + one continuous column. |
  | `surveycore_error_polyserial_canonicalization_ambiguous` (PC-3) | `method = "polyserial"` and a selected column is integer with more than `integer_cardinality_cutoff` (default 10) distinct non-NA values. |
  | `surveycore_error_polychoric_single_level_ordinal` (PC-4) | Any ordinal variable has < 2 observed levels in the active domain. |
  | `surveycore_error_polychoric_insufficient_cells` (PC-5) | `method = "polychoric"` and a pair has fewer than 4 non-empty bivariate cells. Note: the 4-cell minimum is a surveycore stability guardrail (avoids degenerate 1×K / 2×2 tables). Mannan (2025) does not mandate this threshold; it is a surveycore policy. |
  | `surveycore_error_polychoric_optim_failed` (PC-6) | Full-sample MLE did not converge. |
  | `surveycore_error_polychoric_design_unsupported` (PC-7) | `design` is `survey_twophase` or `survey_nonprob` and `method != "pearson"`. |
  | `surveycore_error_replicate_convergence_failure` (PC-8) | Replicate path: > 20 % of replicates failed, or zero succeeded, for any pair. |
  | Pre-existing error classes (`surveycore_error_insufficient_variables`, `surveycore_error_invalid_variance_arg`, etc.) | Unchanged — fire as they do today. |

- **Warnings**:

  | Warning class | Condition |
  |---|---|
  | `surveycore_warning_polychoric_boundary_rho` (PC-9) | ρ̂ for any pair lies within ε = 1e-4 of ±1 (amended 2026-04-24; see D1 disposition). |
  | `surveycore_warning_polychoric_zero_count_level` (PC-10) | An interior ordinal level has zero weight in the active domain and is dropped before threshold estimation. |
  | `surveycore_warning_polychoric_sparse_cell` (PC-11) | Any observed cell has modeled probability < 1e-12 at the MLE; the log-likelihood floor was active at the optimum. |
  | `surveycore_warning_polychoric_replicate_convergence` (PC-12) | Some replicates failed but ≤ 20 %. |
  | `surveycore_warning_polychoric_unordered_factor` (PC-13) | A selected variable is an unordered `factor` (not `ordered`); `levels()` order is used. |
  | `surveycore_warning_polychoric_taylor_boundary_wide_ci` (PC-14) | `survey_taylor` path and ρ̂ within ε = 1e-4 of ±1 (amended 2026-04-24; see D1 disposition) (same tolerance as PC-9) — the numerical-IF CI is structurally wide. |
  | Pre-existing warning classes (`surveycore_warning_small_cell`, `surveycore_warning_cv_undefined`, `surveycore_warning_single_level`) | Unchanged. |

- **Edge cases**:
  - **All-NA focal variable**: pairwise deletion applies the same way as Pearson; if a pair has zero pairwise-complete rows the result row has `r = NA_real_`, variance columns `NA_real_`, `n = 0`; no abort.
  - **Single-row active domain**: pair result has `n = 1`, `r = NA_real_`; threshold estimation cannot fire (only one level observed) → `surveycore_error_polychoric_single_level_ordinal`.
  - **Single-level ordinal variable** (global): per-pair error `surveycore_error_polychoric_single_level_ordinal` for every pair that references the offending variable.
  - **Zero-weight rows in the active domain**: contribute zero to all weighted sums; the likelihood term is identically 0 by the convention `w_i · log p_i ≡ 0` when `w_i = 0`, regardless of `log p_i` (implementation must guard against `log(0)` when `w_i > 0`).
  - **Degenerate stratum** (single PSU per stratum, replicate path): no special handling; inherits whatever the design's replicate weights already encode.
  - **Zero-count interior ordinal level**: dropped before threshold estimation; remaining levels are renumbered to {1, …, K} (K = retained levels); thresholds are estimated on the K retained levels. Warning PC-10 fires with the dropped level indices.
  - **Observed cell with ρ̂-dependent zero modeled probability**: likelihood is floored at 1e-300; warning PC-11 fires if any floor was active at the optimum.
  - **ρ̂ at boundary**: clamped to `(-1 + eps, 1 - eps)` with `eps = 1e-6`; warning PC-9 fires and for `survey_taylor` an additional PC-14 fires.
  - **Unordered factor**: accepted but warned (PC-13); `levels()` order used.
  - **Character vector in `x` for `method = "polychoric"`**: rejected by `.corr_detect_ordinal()` — character is "ambiguous" for the polychoric branch → PC-1 (not classifiable as ordinal; asks user to coerce to `factor`/`ordered`).
  - **Logical / character column in `x`**: rejected as ambiguous → PC-3 for polyserial, PC-1 for polychoric. Applies uniformly (no silent coercion to integer 0/1 for logicals).
  - **Integer vector with >10 distinct values under `method = "polyserial"`**: PC-3 if it is the candidate ordinal side.
  - **Large `t` × `t'`**: no abort; paper's cost is `O(t × t')` bivariate-normal evaluations per likelihood call. Documented in the function's roxygen, not enforced numerically.
  - **Replicate non-convergence**:
    - Zero successful replicates or > 20 % failed → PC-8 (error).
    - 0 < failed ≤ 20 % → PC-12 (warning), variance computed over the successful replicates, `n_failed_replicates` attribute populated.
  - **Domain via `filter()` or `.apply_domain()`**: polychoric/polyserial estimation uses the existing `active_domain` numeric 0/1 mask. Out-of-domain rows contribute zero weight. Threshold and likelihood code must never index `design@data` with physical row-drops for the latent methods.
  - **`survey_collection`**: dispatch inherits the existing `.dispatch_over_collection()` path. Per-survey errors (including PC-7 when a survey is twophase/nonprob) surface through the collection's usual `.on_missing`/error-wrapping behavior.
  - **Pearson path unchanged**: when `method = "pearson"`, all existing behavior — including the silent drop of non-numeric columns with `surveycore_warning_corr_non_numeric` — is preserved exactly.

---

### `.corr_detect_ordinal(col, integer_cardinality_cutoff = 10L)` (internal)

- **Arguments**:
  - `col` — a column vector from `design@data`.
  - `integer_cardinality_cutoff` — integer(1), default `10L`. Integer vectors with `≤ cutoff` distinct non-NA values are classified as ordinal (`"integer_ordinal"`); vectors with more distinct values are `"ambiguous"`. Rationale: standard Likert scales have ≤ 7 levels; the `10L` default leaves headroom for scales up to 10 without exposing a user-facing argument. Users with larger-cardinality ordinals should coerce to `ordered` before calling `get_corr()`.
- **Returns**: `character(1)` — one of `"ordered"`, `"factor"`, `"integer_ordinal"`, `"continuous"`, `"ambiguous"`.
  - `"ordered"`: `inherits(col, "ordered")`.
  - `"factor"`: `is.factor(col) && !is.ordered(col)`.
  - `"integer_ordinal"`: `is.integer(col) && length(unique(col[!is.na(col)])) ≤ integer_cardinality_cutoff`.
  - `"continuous"`: `is.double(col)` and (either not integer-valued or >`integer_cardinality_cutoff` distinct values).
  - `"ambiguous"`: `is.integer(col)` with more than `integer_cardinality_cutoff` distinct values — could be either.
- **Errors / warnings**: none directly; callers interpret the return.
- **Edge cases**: character vectors and logical vectors both classify as `"ambiguous"` (explicitly — neither ordinal nor continuous). Callers will error with PC-1 for polychoric or PC-3 for polyserial.

### `.corr_canonicalize_polyserial(x_col_name, y_col_name, data, integer_cardinality_cutoff = 10L)` (internal)

- **Arguments**:
  - `x_col_name`, `y_col_name` — character column names referencing columns in `data`.
  - `data` — the data frame whose columns are being classified (typically `design@data`).
  - `integer_cardinality_cutoff` — integer(1), default `10L`. Forwarded to `.corr_detect_ordinal()` (see R5 justification).
- **Behavior**: calls `.corr_detect_ordinal()` internally to classify each side; the caller does not need to pre-classify.
- **Returns**: `list(ordinal_name = chr, continuous_name = chr)`.
- **Errors**:
  - `surveycore_error_polyserial_requires_mixed_types` — both sides classify as ordinal or both as continuous.
  - `surveycore_error_polyserial_canonicalization_ambiguous` — at least one side classifies as `"ambiguous"` (from `.corr_detect_ordinal()`), including logical and character vectors and high-cardinality integer vectors. If BOTH sides classify as `"ambiguous"`, PC-3 fires naming both columns; message recommends coercing one to `ordered` (for ordinal) or `double` (for continuous).
- **Edge cases**: tie-breaking deterministic; column names placed into the returned list in classification order (not necessarily supply order). Logical / character inputs always route here via PC-3 (never silently accepted).

### `.corr_estimate_thresholds(ordinal_vec, weights, active_domain)` (internal)

- **Returns**: `list(thresholds = numeric, levels = ..., dropped_levels = character|integer, levels_used = character|integer)`.
  - `thresholds`: numeric vector of length `K - 1` (finite interior cut-points), where `K` is the number of retained levels. Computed as `qnorm(cumsum(w_k) / sum(w_k))` for k = 1…K-1 with `w_k = Σ_{i: level_i = level k, w_i > 0, active} w_i`.
  - Paper notation map: surveycore's K = paper's t; surveycore's θ_{k+1} for
    k = 1, …, K−1 corresponds to Mannan (2025) §6.1.2's θ_{k+1} = Φ⁻¹(F_k / Σw).
    θ_1 ≡ −∞ and θ_{K+1} ≡ +∞ are implicit sentinels (never stored).
  - `levels_used`, `dropped_levels`: bookkeeping.
- **Errors**:
  - `surveycore_error_polychoric_single_level_ordinal` — if fewer than 2 levels have positive weight after dropping.
- **Warnings**:
  - `surveycore_warning_polychoric_zero_count_level` — raised by caller once all zero-weight levels are known; helper returns the list so the caller can raise the warning at the appropriate aggregation level.
  - `surveycore_warning_polychoric_unordered_factor` — raised by caller if `!is.ordered(ordinal_vec) && is.factor(ordinal_vec)`.
- **Edge cases**: `active_domain` is a 0/1 numeric mask; rows with domain = 0 are treated as weight = 0.

### `.corr_weighted_standardize(continuous_vec, weights, active_domain)` (internal)

- **Returns**: `list(z = numeric, mean_w = numeric(1), sd_w = numeric(1))`. `z` is the same length as the input (NA for non-domain or NA-weight rows); standardization is `(x - mean_w) / sd_w` with `mean_w = Σ w_i x_i / Σ w_i` and `sd_w² = Σ w_i (x_i - mean_w)² / Σ w_i` (population SD; Cox 1974).
- **Errors**: none directly; degenerate `sd_w = 0` produces `NaN` z values and propagates to the MLE which will fail with PC-6.
- **Edge cases**: zero-weight row → `z[i] = NA_real_`.

### `.corr_polychoric_loglik(rho, cell_weights, thresholds_x, thresholds_y, cell_prob_floor = 1e-300)` (internal)

- **Returns**: `list(ll = numeric(1), any_floor_active = logical(1))`. `ll` is the weighted log-likelihood.
- **Cell probability** (Mannan 2025 §5.2, Olsson 1979): for observed pair `(m, p)`,
  π_{m,p}(ρ) = Φ_2(θ_{m+2}, θ'_{p+2}; ρ)
              − Φ_2(θ_{m+1}, θ'_{p+2}; ρ)
              − Φ_2(θ_{m+2}, θ'_{p+1}; ρ)
              + Φ_2(θ_{m+1}, θ'_{p+1}; ρ)
  where Φ_2 is the bivariate standard-normal CDF `pbivnorm::pbivnorm(u, v, rho)`
  (4 scalar calls per cell). Conventions: θ_1 ≡ −∞, θ_{K+1} ≡ +∞, with
  Φ_2(+∞, b; ρ) = Φ(b) and Φ_2(a, −∞; ρ) = 0.
- **Edge cases**: any cell probability below `cell_prob_floor` is floored to `cell_prob_floor`; `any_floor_active` is recorded.

### `.corr_polyserial_loglik(rho, z, ordinal_level_int, thresholds, weights, cell_prob_floor = 1e-300)` (internal)

- **Returns**: `list(ll = numeric(1), any_floor_active = logical(1))`.
- **Optimization objective**: the constant `φ(z_i)` (standard-normal PDF) factor
  from the full likelihood (Mannan 2025 §5.1) is ρ-independent and dropped from
  the objective; only the `[Φ(u_{m+2}) − Φ(u_{m+1})]` bracket (with
  u_k = (θ_k − ρ z_i) / √(1 − ρ²)) is optimized.
- **Edge cases**: leftmost category uses `Φ((θ₁ - ρ z)/√(1-ρ²)) - 0`; rightmost uses `1 - Φ((θ_{K-1} - ρ z)/√(1-ρ²))`; `√(1 - ρ²)` in the denominator is guarded by the optimizer's clamped bounds.

### `.corr_polychoric_mle(ord_x_vec, ord_y_vec, weights, active_domain, eps = 1e-6)` (internal)

- **Returns**: `list(rho = numeric(1), converged = logical(1), thresholds_x = numeric, thresholds_y = numeric, levels_x, levels_y, cell_counts = matrix, n_cells_obs = integer(1), n_sparse_cells = integer(1), log_lik = numeric(1))`.
- **Errors**:
  - `surveycore_error_polychoric_single_level_ordinal` — propagated from threshold helper.
  - `surveycore_error_polychoric_insufficient_cells` — when `n_cells_obs < 4`.
  - `surveycore_error_polychoric_optim_failed` — when `stats::optimize()` returns a boundary-hitting result after retry, or when the objective is not finite at any tested point.
- **Optimizer**: `stats::optimize(..., lower = -1 + eps, upper = 1 - eps, tol = .Machine$double.eps^0.25, maximum = TRUE)`.

### `.corr_polyserial_mle(ordinal_vec, continuous_vec, weights, active_domain, eps = 1e-6)` (internal)

- **Returns**: analogous to `.corr_polychoric_mle` with one threshold vector and one standardized continuous vector.
- **Errors**:
  - `surveycore_error_polychoric_single_level_ordinal` (reused) — ordinal side has < 2 levels.
  - `surveycore_error_polychoric_optim_failed` (reused).

### `.corr_numerical_influence(design, method, vec_a, vec_b, active_domain, rho_hat_full, eps_pert = 1e-4)` (internal)

- **Arguments**:
  - `design` — the `survey_taylor` design whose stratum/PSU/FPC structure is propagated through `.corr_taylor_variance_latent()`.
  - `method` — scalar character, one of `"polychoric"` or `"polyserial"` (pre-matched; not NSE).
  - `vec_a`, `vec_b` — the two variables for the pair. For `method = "polychoric"`, both are ordinal (integer codes after level-renumber). For `method = "polyserial"`, `vec_a` is the ordinal side and `vec_b` is the continuous variable (not pre-standardized; standardized inside the helper per perturbation since thresholds / mean_w / sd_w change under the perturbed weight vector).
  - `active_domain` — 0/1 numeric mask aligned to `design@data` rows.
  - `rho_hat_full` — the full-sample point estimate ρ̂ on the ρ scale.
  - `eps_pert` — scalar numeric, default `1e-4`.
- **Returns**: `numeric` of length `sum(active_domain)` — the Fisher-z influence function values for each active respondent.
- **Method**: perturbation-based. For each active respondent `i`, replace `w_i` with `w_i(1 + eps_pert)`, re-run the MLE (caching the per-variable weighted cumulative threshold step where possible), compute `IF_i = (atanh(ρ̂_pert_i) - atanh(ρ̂_full)) / eps_pert`. Threshold re-estimation per-respondent is required because perturbing a respondent's weight perturbs the weighted marginal.
- **Errors**: none raised directly; if any inner MLE fails to converge, the helper signals `surveycore_error_polychoric_optim_failed` with context pointing at the full sample (not the perturbed sample — a single failed perturbation is a bug in the outer estimate's stability, not an end-user error mode).
- **Edge cases**: extremely small active domains (< 10 rows) → IF is still computed but the Taylor SE will be unstable; caller may additionally emit PC-14.
- **Note on cost**: this is O(n) re-optimizations per pair. Alternative implementations (score/Hessian finite-difference) are permitted as long as the contract inputs/outputs match.
- **Scale equivalence**: the shorthand `(atanh(ρ̂_pert) − atanh(ρ̂_full)) / ε`
  is equivalent to the two-step comprehension form (compute IF on ρ scale,
  then transform: `IF_ρ_i / (1 − ρ̂²)`) to first order in ε. The atanh-of-ρ̂
  formulation is preferred because it avoids an extra division near |ρ̂|→1.

### `.corr_taylor_variance_latent(design, if_z, active_domain)` (internal)

- **Returns**: `list(var_z = numeric(1), var_z_srs = numeric(1))`. `var_z` is the design-based variance of `atanh(ρ̂)`; `var_z_srs` is the Taylor variance computed on the same z-scale IF vector with design weights replaced by w_i ← 1 (unit weights), holding the thresholds and ρ̂ from the design-weighted fit (used only for `deff`). Do NOT re-fit the MLE under unit weights.
- **Implementation**: treats `if_z` as an influence function of a total estimator and passes it through the same HT / Hájek machinery `.vcov_pair_taylor()` uses today.
- **Reuse**: internally calls the existing `.vcov_pair_taylor()` inner HT / Hájek machinery (or its refactored variance-of-a-total path) in `R/analysis-corr-helpers.R`. Do not re-implement FPC, stratum, or PSU handling.
- **FPC**: inherited from the design's stratum/PSU/FPC structure via the
  existing HT / Hájek machinery. No additional FPC correction is applied
  inside this helper.

### `.corr_replicate_variance_latent(design, method, vec_a, vec_b, active_domain, rho_hat_full)` (internal)

- **Arguments**:
  - `design` — the `survey_replicate` design whose `@variables$repweights`, `@variables$scale`, and `@variables$rscales` drive the variance aggregation.
  - `method` — scalar character, one of `"polychoric"` or `"polyserial"` (pre-matched; not NSE).
  - `vec_a`, `vec_b` — the two variables for the pair. For `method = "polychoric"`, both are ordinal (integer codes after level-renumber). For `method = "polyserial"`, `vec_a` is the ordinal side and `vec_b` is the continuous variable (not pre-standardized; standardized inside per replicate since thresholds / mean_w / sd_w change under replicate weights).
  - `active_domain` — 0/1 numeric mask aligned to `design@data` rows.
  - `rho_hat_full` — the full-sample point estimate ρ̂.
- **Returns**: `list(var_z = numeric(1), var_z_srs = numeric(1), n_ok = integer(1), n_failed = integer(1))`. `var_z_srs` here is the Taylor variance computed on the same z-scale IF vector with design weights replaced by w_i ← 1 (unit weights), holding the thresholds and ρ̂ from the design-weighted fit (used only for `deff`). Do NOT re-fit the MLE under unit weights. (A9: no per-replicate `rhos_by_replicate` vector is returned; only the `n_ok` / `n_failed` scalars are retained.)
- **Behavior**: iterates `design@variables$repweights` (by column or index — whatever the design exposes). For each replicate `r`:
  1. Re-run `.corr_estimate_thresholds()` with replicate weights.
  2. Re-run `.corr_polychoric_mle()` or `.corr_polyserial_mle()` with replicate weights and replicate thresholds.
  3. Record `ρ̂^{(r)}`, `ζ̂^{(r)} = atanh(ρ̂^{(r)})`, or a NA sentinel for non-convergence.
  Aggregate: `var_z = Σ_r c_r · (ζ̂^{(r)} - ζ̂)²` using the design's `scale` and `rscales`, over successful replicates.
- **Errors**:
  - `surveycore_error_replicate_convergence_failure` — if `n_failed / R > 0.20` or `n_ok == 0`.
- **Warnings**:
  - `surveycore_warning_polychoric_replicate_convergence` — if `0 < n_failed ≤ 0.20 R`.
- **Replicate-type caveat**: Mannan (2025) validates the replicate variance
  formula for JK (jackknife) and bootstrap replicates only. BRR / Fay are
  admitted mechanically via the stored `@variables$scale` / `@variables$rscales`
  coefficients, but the paper does not verify their behavior for this nonlinear
  pseudo-likelihood estimator. No separate warning; documented as a known
  scope limitation in the roxygen `@details`.

### `.corr_latent_pair(design, x_col, y_col, method, active_domain, na.rm = TRUE, conf_level = 0.95)` (internal dispatcher)

- **Signature**: `.corr_latent_pair(design, x_col, y_col, method, active_domain, na.rm = TRUE, conf_level = 0.95)`. Internal (not exported). `na.rm` default `TRUE` (pairwise-complete-case); `conf_level` default `0.95` (standard surveycore default; overridden by the caller when the user passes a different `conf_level` to `get_corr()`).
- **Arguments**:
  - `design` — the parent survey design (`survey_taylor` or `survey_replicate`; other classes route to PC-7).
  - `x_col` — character scalar column name from `design@data` (one side of the pair).
  - `y_col` — character scalar column name from `design@data` (other side of the pair).
  - `method` — scalar character, one of `"polychoric"` or `"polyserial"` (pre-matched by `get_corr()`; not NSE).
  - `active_domain` — 0/1 numeric mask aligned to `design@data` rows.
  - `na.rm` — logical(1), default `TRUE`. Pairwise-complete-case drop: rows where either `x_col` or `y_col` is NA are masked out within this pair only.
  - `conf_level` — numeric(1) in (0, 1), default `0.95`.
- **Returns**: `list(r, se_r, se_srs, n, n_weighted, ci_low, ci_high, rho_z, se_z, method)` — the shape consumed by `get_corr()`'s long-format assembly. Analogous to the Pearson `.corr_pair_result()` output, but with Fisher-z SE and CI computed on the z scale.
- **Behavior**:
  1. Dispatch to `survey_twophase` / `survey_nonprob` → PC-7.
  2. Canonicalize (polyserial only).
  3. Run MLE on the active domain.
  4. Compute variance by design class (`survey_taylor` → Taylor IF helper; `survey_replicate` → replicate helper).
  5. Emit boundary/sparse/convergence warnings as applicable.
  6. Transform to CI via the existing `.corr_fisher_ci()` helper: CI low / high on ρ scale by `tanh(ζ̂ ± z_{α/2} · SE(ζ̂))`, truncated to `[-1, 1]`.
- **Errors** (raised directly at this dispatcher layer):
  - `surveycore_error_polychoric_design_unsupported` (PC-7) — at step 1, before any MLE work, when `design` is `survey_twophase` or `survey_nonprob`.
  - `surveycore_error_polychoric_requires_ordinal` (PC-1) — raised at canonicalization when `method = "polychoric"` and either side is not ordinal.
  - `surveycore_error_polyserial_requires_mixed_types` (PC-2) — raised at canonicalization when `method = "polyserial"` and the pair is not one ordinal + one continuous.
  - `surveycore_error_polyserial_canonicalization_ambiguous` (PC-3) — raised at canonicalization for logical / character / high-cardinality integer inputs under `method = "polyserial"`.
  - Propagated from MLE helpers (`surveycore_error_polychoric_single_level_ordinal` (PC-4), `surveycore_error_polychoric_insufficient_cells` (PC-5), `surveycore_error_polychoric_optim_failed` (PC-6)).
  - Propagated from replicate helper (`surveycore_error_replicate_convergence_failure` (PC-8)).
- **Warnings** (emitted at this dispatcher layer after child helpers return):
  - `surveycore_warning_polychoric_boundary_rho` (PC-9) — after MLE, based on `.corr_detect_boundary_rho(rho_hat, eps = 1e-6)`.
  - `surveycore_warning_polychoric_zero_count_level` (PC-10) — surfaced from threshold helper.
  - `surveycore_warning_polychoric_sparse_cell` (PC-11) — surfaced from MLE helper.
  - `surveycore_warning_polychoric_replicate_convergence` (PC-12) — surfaced from replicate helper.
  - `surveycore_warning_polychoric_unordered_factor` (PC-13) — emitted when any side is an unordered factor.
  - `surveycore_warning_polychoric_taylor_boundary_wide_ci` (PC-14) — emitted on `survey_taylor` path only, using the same `.corr_detect_boundary_rho()` check as PC-9.
- **Edge cases**:
  - All-NA pair: after pairwise-complete filtering there are 0 rows → return `r = NA_real_`, `n = 0`, variance columns `NA_real_`; do not abort.
  - Empty active domain (`sum(active_domain) == 0`): treated as all-NA; no abort in isolation, but threshold estimation will raise PC-4.
  - Single-row active domain: threshold estimation can only observe one level → PC-4.

---

## Quality gates / invariants

1. **ρ̂ ∈ [−1 + ε, 1 − ε]** for all converged MLEs (by optimizer bounds).
2. **CI endpoints ∈ [−1, 1]** after truncation.
3. **When `method = "pearson"`, behavior is bit-identical to the current implementation.** `method` has a default and its `"pearson"` branch is the existing dispatch.
4. **When all weights equal** (unweighted), ρ̂_polychoric matches `polycor::polychor()` within optimizer tolerance. ρ̂_polyserial matches `polycor::polyserial()` within optimizer tolerance.
5. **Domain membership is honored**: out-of-domain rows contribute zero weight; threshold estimation sees only in-domain rows via the `active_domain` mask.
6. **`meta(result)$n_failed_replicates_total` invariant**: scalar integer; present only when replicate path is used and `n_failed > 0`; absent otherwise. No per-row attribute (per A9).
7. **`meta(result)$method` matches the argument**: `"pearson"`, `"polychoric"`, or `"polyserial"`.
8. **No new column types**: `r`, `se`, `var`, `cv`, `ci_low`, `ci_high`, `moe`, `deff`, `p_value`, `statistic`, `n_weighted` are all `numeric`; `df`, `n` are `integer`. For `method != "pearson"`, `df` is `NA_integer_` (Wald reference is standard normal).

---

## Pipeline split

`recommended`. Justification:

- New estimator class (MLE with numerical optimization) — not a behavioral refinement.
- New dependency (`pbivnorm`).
- Two new variance paths (pseudo-Taylor via numerical IF; replicate loop with per-replicate MLE).
- Multiple new error and warning classes.
- Methods-heavy (derived from Mannan 2025 and peer-reviewed antecedents).
- User-facing API change on an exported function signature.

---

## Open questions resolved (defaults from pipeline-spec brief)

1. **Bivariate-normal CDF**: `pbivnorm::pbivnorm` (added to `Imports`). Fast, focused, used by `polycor` for the same purpose. If it becomes unavailable on CRAN during builder stage, fall back to `mvtnorm::pmvnorm` and update `DESCRIPTION` accordingly.
2. **1-D optimizer**: `stats::optimize()` over `(-1 + 1e-6, 1 - 1e-6)` with default `tol = .Machine$double.eps^0.25`. Single-dimension; Brent is implicit.
3. **Polyserial canonicalization**: auto-detect via `.corr_detect_ordinal()`. No new user argument in v1. Ambiguous cases error with PC-3.
4. **`survey_twophase` / `survey_nonprob`** + non-Pearson: error with PC-7 in v1.
5. **Replicate convergence failures**: warn + skip if ≤ 20 % fail (PC-12); error if > 20 % or all fail (PC-8).
6. **Optimizer tolerance exposure**: hardcoded at `stats::optimize()` default; not a user argument in v1.

None of these resolved defaults introduce new user-facing knobs beyond `method`.
