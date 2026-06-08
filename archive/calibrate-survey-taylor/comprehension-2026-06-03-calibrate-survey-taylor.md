# Comprehension — calibrate-survey-taylor

## Problem

Survey calibration (also called the GREG estimator — Generalized Regression Estimator) adjusts the base sampling weights so that the weighted sample totals for a set of auxiliary variables match known population totals. Each observation's weight is multiplied by a unit-specific g-weight computed from a Newton-Raphson or iterative proportional fitting algorithm. The calibrated estimator for a mean or total is identical to the Horvitz-Thompson estimator applied to the g-adjusted weights; point estimates therefore change whenever the calibration variables are correlated with the outcome. More importantly for this feature, the variance of a calibration estimator is strictly smaller than the unadjusted Taylor variance whenever the outcome is linearly predictable from the calibration variables: the GREG variance uses calibration residuals (the part of the outcome not explained by the auxiliary model) as the linearization input rather than the raw centered outcomes. To realize this variance reduction in surveycore, the calibration model must be stored on the design object so that `.svy_recvar()` can project out the calibrated column space from the influence function before accumulating variance over strata and clusters. Without storing this, post-calibration SEs would be identical to pre-calibration SEs — correct in coverage (conservative) but not the efficient estimator.

Raking (iterative proportional fitting, IPF) is a special case of calibration where each margin in a multi-way table is calibrated independently, one at a time, cycling until convergence. It is equivalent to calibrating with a product of one-way margin formulas rather than a full cross-tabulation, and the variance correction uses the same QR-projection mechanism.

## Formulas

### Notation

| Symbol | Bound to |
|--------|----------|
| n | `nrow(design@data)` — sample size |
| w_i | `design@data[[design@variables$weights]][i]` — base weight for unit i |
| g_i | computed g-weight scalar for unit i (output of Newton-Raphson / IPF) |
| w_i* = g_i * w_i | calibrated weight stored in updated weight column |
| X_i | row vector from `model.matrix(formula, design@data)[i, ]` — calibration auxiliary row for unit i |
| T_x | `population` argument — known population total vector for the calibration columns, length p |
| η | Lagrange multiplier vector of length p (Newton-Raphson iterate) |
| F(·) | calibration function, family-specific: linear, raking (exponential), logit |
| y_i | outcome column for a particular analysis function call |
| ê_i | calibration residual for unit i: y_i − X_i β̂_cal |

### G-weight computation (Newton-Raphson)

The calibration constraint requires:

    ∑_i w_i * g_i * X_i = T_x                   (1)

For the linear family, F(X_i η) = X_i η so g_i = 1 + X_i η. The closed-form solution is:

    η = (X' W X)^{-1} (T_x − X' W 1)             (2)

where W = diag(w_1, ..., w_n). In practice a QR decomposition of (√W · X) is used for numerical stability:

    tqr = qr(√W · X)                              (3)

For the raking family (exponential F), and logit family (bounded logistic F), Newton-Raphson iterates:

    Tmat = (X · √W/σ · F'(Xη))' (X/σ)            (4)
    misfit_t = T_x − ∑_i w_i g_i X_i at iteration t
    Δη = ginv(Tmat) · misfit_t                    (5)
    η_{t+1} = η_t + Δη

until |misfit_t| / (1 + |T_x|) < ε. Then:

    g_i = F(X_i η*)                               (6)
    w_i* = g_i · w_i                              (7)

The g-weight vector g = (g_1, ..., g_n) is what gets multiplied into the design weight column and stored.

### GREG variance estimator via Taylor linearization

For a weighted mean estimator t̂ = Σ_i w_i* y_i / Σ_i w_i*, the calibration-adjusted influence function for unit i is:

    u_i = w_i* (y_i − X_i β̂) / Σ_j w_j*        (8)

where β̂ = (X' W* X)^{-1} X' W* y is the weighted calibration regression of y on X using calibrated weights W* = diag(w_1*, ..., w_n*).

Equivalently, the calibration residual ê_i = y_i − X_i β̂ replaces (y_i − ȳ_w) as the linearization input. This is achieved via QR projection:

    u = qr.resid(tqr, u_raw / whalf) * whalf      (9)

where:
- u_raw = w_i* · (y_i − ȳ_w) / Σ w_j* is the uncalibrated influence function (full-length vector),
- whalf = √(w_i) · g_i = √(w_i*) · √(g_i) (the `w` slot of the stored caldata),
- tqr is the QR decomposition from equation (3) stored in `@calibration`.

After this projection, `.svy_recvar()` proceeds normally over strata and clusters with u in place of u_raw. The projection enforces that the variance estimator accounts for the information in X.

For a total estimator t̂_total = Σ_i w_i* y_i, the influence function is u_i = w_i* · ê_i (without the denominator normalization).

### Raking convergence criterion

For multi-margin raking with K margins:

    convergence at cycle t iff max_k |Σ_i w_i(t) X_{ki} − T_{xk}| / (1 + |T_{xk}|) < ε   (10)

Each cycle calibrates margin k using the current iterate w_i(t), then advances t. The final design stores the accumulated caldata list from all K one-margin calibrations.

## Gotchas

- **Singular auxiliary matrix** — When `model.matrix(formula, data)` has rank < p (perfect collinearity among calibration variables), `qr()` will succeed but back-substitution in equation (2) is numerically unstable. The `survey` package silently drops aliased columns via `alias()`; surveycore must detect this via `qr()$rank < ncol(mm)` and either error or warn. Failing to handle this produces g-weights of ±Inf.

- **Perfect collinearity between calibration variables and intercept** — Including an intercept in `formula` when the calibration variables already sum to the population size creates perfect collinearity. The `survey` package removes the intercept automatically; surveycore should do the same or warn the user.

- **Non-convergence of Newton-Raphson** — For raking/logit families, the Newton-Raphson loop (equations 4–5) may fail to converge within `maxit` iterations if the calibration targets are inconsistent with the sample (e.g., a cell total larger than the sum of all weights). Must error with a typed class explaining which constraint is failing and the residual misfit.

- **Infeasible bounds for logit family** — The logit calibration family restricts g to [L, U] via the logistic function. If population targets require g outside [L, U] for any unit, the algorithm stalls. `force = TRUE` accepts non-convergence; `force = FALSE` (default) should error.

- **Zero-weight rows** — Rows with w_i = 0 (which surveycore currently rejects at construction time via `surveycore_error_weights_nonpositive`) are therefore not present in practice. However, after calibration, g_i · w_i could theoretically be very close to zero if bounds = c(-Inf, Inf) and g_i → 0. The variance code divides by whalf; near-zero whalf values produce numerically large residuals. Add a safeguard or warn when any calibrated weight is below a threshold.

- **Single-PSU stratum post-calibration** — Calibration does not change the cluster/strata structure. Single-PSU strata (lonely.psu handling) remain problematic after calibration, exactly as they are in uncalibrated designs. No new behavior is needed here, but comprehension note: the QR projection in equation (9) operates on the full-length influence vector including single-PSU contributions; it does not require >1 PSU.

- **Inconsistent population totals across margins (raking)** — If the K margins in `population.margins` are mutually inconsistent (e.g., margin totals for age do not sum to the same grand total as margin totals for sex), IPF will oscillate and not converge. Must detect this and emit a convergence failure error, not silently return partially-raked weights.

- **Near-zero denominators in g-weight computation** — The Fisher information matrix Tmat (equation 4) can be near-singular if auxiliary variables are nearly collinear or if sample weights are highly heterogeneous. The `survey` package uses `ginv` (Moore-Penrose pseudoinverse); surveycore must do the same or use `qr.solve` with a tolerance.

- **Calibration of already-calibrated design** — If `calibrate()` is called on a design that already has `@calibration` set, the new calibration appends to the stored list (as in `survey`'s `postStrata` append semantics). This must be explicit in the spec. The variance function must loop over all stored calibration steps.

- **`rake()` with non-converging margins** — IPF convergence depends on the Sinkhorn-Knopp theorem: the algorithm converges iff the bipartite graph of margins is connected. If some margin combination is structurally zero in the sample, `rake()` will not converge. Error handling must be distinct from the general non-convergence error to explain what "inconsistent margins" means.

- **`formula` with only an intercept** — `~1` as the formula means calibrate to the total sample weight = population size. This is valid (post-stratification to known N) but the design matrix has rank 1, producing a scalar g-weight. Ensure the QR path handles this correctly (1-column model matrix).

- **`population` as a named vector vs. a list** — The `survey` package accepts both a named numeric vector (for a single calibration) and a list of vectors (for raking-style multi-margin calibration passed to `calibrate()`). The surveycore spec must decide whether to support both forms or only named vectors, with list form reserved for `rake()`.

## Reference mapping

- **Deville & Sarndal (1992)** "Calibration Estimators in Survey Sampling," JASA 87(418), §2 (equations for g-weights) and §3 (variance of the calibration estimator) → calibration constraint equation (1), GREG variance equation (8).

- **Deville & Sarndal (1992)** §4 (iterative algorithm for non-linear calibration functions) → Newton-Raphson loop equations (4–5), convergence criterion.

- **Sarndal, Swensson & Wretman (1992)** "Model Assisted Survey Sampling," Chapter 6 (GREG estimator) → the residual interpretation ê_i = y_i − X_i β̂, and the key result that GREG variance equals the variance of the residuals linearized over the design.

- **survey::grake.R** `grake()` function → equations (4–6): the Newton-Raphson loop, Tmat computation, step-halving, convergence test.

- **survey::grake.R** `calibrate.survey.design2()` → equations (3) and (7): tqr = qr(√W · X), storage in `caldata = list(qr = tqr, w = g * whalf, stage = 0, index = NULL)`, class `"greg_calibration"`, append to `design$postStrata`.

- **survey::multistage.R** `svyrecvar()`, lines ~570+ → equation (9): `x <- as.matrix(qr.resid(psvar$qr, x / psvar$w) * psvar$w)`. This is the exact operation that surveycore must implement (or adapt into `.svy_recvar()` via a `caldata` argument) to get calibration-adjusted variances. The `stage == 0` branch applies at population level (all units simultaneously).

- **survey::surveyrep.R** `rake()` function pattern → IPF convergence criterion equation (10): cycle until max-normalized-misfit across all margins < ε, then store all accumulated caldata objects.

- **Rao, Yung & Hidiroglou (2002)** "Estimating Equations for the Analysis of Survey Data Using Poststratification Information," Sankhya 64-A, §2.3 equation (2.5) → the correct linearization variance form is `v(a_k(s) · e_k)` (g-weighted residuals), NOT `v(e_k)` (plain residuals); equation (2.10) → the general EE form `v[a_k(s) · ẽ_k(θ̂)]` covering regression, GLM, and income inequality estimators; Example 2.2 and equation (2.14) → the stratified multistage case (exactly what `survey_taylor` handles) shows g-weights `a_{hik}(s)` apply at the population level; equation (3.7) → jackknife linearization = Taylor linearization when calibration residuals are used, validating the caldata approach.

- **Lumley (2010)** "Complex Surveys: A Guide to Analysis Using R," Chapter 5 → conceptual overview of calibration and GREG variance reduction, useful for framing the `@calibration` property description.

## Assumptions

- **Linear family is the primary case** — The request and `survey` package make all three families (linear, raking, logit) available, but linear calibration is the common default and the only one with a closed-form solution. The comprehension assumes linear is the first required family; raking and logit are extensions. This was NOT stated in the request, which says "calibrate() and rake()" without specifying which calibration families `calibrate()` must support. This is a design decision that belongs in `spec.md`.

- **Only `survey_taylor` is in scope** — The request explicitly limits to `survey_taylor` objects. The `survey` package also calibrates replicate designs (each replicate independently), but `survey_replicate` support is listed as out-of-scope in request.md. The `@calibration` property is therefore added only to `survey_taylor`, not to `survey_base` (which would imply universal support).

- **`@calibration` stores the full caldata list** — The request says "stores the calibration model (auxiliary matrix, population totals, calibration method)." In the `survey` implementation, what is stored is the QR decomposition of √W · X and the vector g · √w (sufficient to apply equation (9)). Storing the raw model matrix is redundant and expensive; storing the QR decomposition is sufficient. This design decision — QR + w vs. raw matrix + population — is implicit in the `survey` implementation and should be made explicit in `spec.md`.

- **Weights column is modified in-place** — Calibration updates `design@data[[design@variables$weights]]` by multiplying by g-weights. This is the survey-package convention and the intent expressed in the request. An alternative (storing g-weights separately) is more conservative but breaks all downstream analysis that reads the weight column directly. The in-place approach is assumed but should be flagged to the user via the existing `surveycore_warning_weight_modified` warning class (row 41).

- **`rake()` is a standalone function, not a special case of `calibrate()`** — The request lists both as separate exported functions. The `survey` package's `rake()` is indeed implemented separately (using the same `calibrate()` machinery internally but with a different interface: `sample.margins` and `population.margins` as formula-list/table-list pairs). Surveycore must either replicate this interface or simplify it. The request does not specify the exact `rake()` interface — this is a design decision for `spec.md`.

- **Two-phase designs are not in scope** — The `survey` package has `calibrate.twophase()` and `calibrate.survey.design2()` dispatches separately. The request says `survey_taylor` only.

- **No `trim` argument in v1** — The `survey` package's `calibrate()` has a `trim` argument that clips extreme g-weights. The request does not mention it. Trimming is a separate operation that surveycore's `surveywts` package likely handles. Assuming trim is not in scope for v1.

- **`population` must be a fully named numeric vector** — The `survey` package accepts list format for multi-margin calibration via `calibrate()`. For clarity and simplicity in surveycore's `calibrate()`, the population argument should be a named numeric vector. The list format (multi-margin) belongs to `rake()`. This is an implicit assumption in the request that should be made explicit.

- **The `@calibration` property validation** — The S7 validator for `survey_taylor` will need to either accept any value in `@calibration` (leaving correctness to the `calibrate()` function) or validate the caldata structure. Given that the property can be `NULL` (uncalibrated) or a list of caldata objects, and since caldata is an internal structure, the validator should accept `NULL | list()` with minimal structural checking. Deep validation belongs in `calibrate()`.
