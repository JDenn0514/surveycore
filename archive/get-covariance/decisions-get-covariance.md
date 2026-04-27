# Decisions — get-covariance

## 2026-04-23 — Stage 0 HOLD resolutions

### HOLD 1: Polychoric scope
**Resolution**: Defer polychoric to a follow-up PR.
**Rationale**: Non-standard survey-weighted polychoric SE methodology needs its own methods review. Shipping Pearson-only yields tight `svyvar()` parity without new Suggests dependency, fewer error classes, and no replicate-resample perf concerns.
**Consequence**: `method` argument omitted from this PR. `get_covariance()` is Pearson-only; add `method = "polychoric"` in a later PR.

### HOLD 2: Architecture
**Resolution**: Route 2 — parallel engine (`.covariance_pair_*()` mirroring `.score_variance()` / `.variance_cell()`).
**Rationale**: Uniform across `survey_taylor`, `survey_replicate`, `survey_twophase`, `survey_nonprob`. Reuses the already-correct `get_variance()` machinery. Avoids the nonprob Kish-asymmetry in `.vcov_pair_calibrated()`.
**Consequence**: ~200 lines of helper code in new file `R/analysis-covariance-helpers.R`. The `.vcov_pair_*()` engines stay dedicated to `.corr_vcov_pair()` for correlation.

### HOLD 3: deff under covariance
**Resolution**: Support `"deff"` via the Goodnight / Mood-Graybill SRS covariance-variance formula.
**Rationale**: Matches `get_corr()` and `get_variance()`'s `deff` support. Formula is well-defined whenever `Var(x) > 0` and `Var(y) > 0`.
**Formula**: `SE_SRS(cov) = sqrt((Var(x) * Var(y) + cov^2) / (n - 1))`.
**Consequence**: `.covariance_pair_result()` must also surface per-pair `Var(x)`, `Var(y)` to enable deff computation in the analysis layer.

### HOLD 4: NA handling
**Resolution**: Pairwise only (no `na_handling` argument).
**Rationale**: Matches `get_corr()` precedent and aligns with `svyvar()` off-diagonal semantics when called pair-at-a-time. Listwise rarely needed for covariance in practice.
**Consequence**: `na.rm = TRUE` means pairwise deletion. Document explicitly in `@param na.rm`.

### Confirmed (no HOLD needed)
- **Wide format**: out of scope. Long only. Per original request.
- **Polychoric-related new error classes**: deferred with polychoric itself.
