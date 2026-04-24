# Comprehension: weighted polychoric and polyserial correlation

**Stage:** 0 — Deep Comprehension
**Run:** 2026-04-23-polychoric-corr
**Primary source:** Mannan, H. (2025). *SAS programs for estimation of weighted
polychoric and weighted polyserial correlations in a complex survey.* Preprint,
SSRN 6580480. Not peer reviewed.
**Foundational peer-reviewed sources:** Olsson (1979) for unweighted polychoric
MLE; Cox (1974) for unweighted polyserial MLE.

---

## Problem

Pearson correlation measures linear association between two continuous variables,
but much survey data is ordinal (Likert items, categorical severity grades). The
polychoric correlation estimates the Pearson correlation between two *latent*
bivariate-normal continuous variables that are assumed to underlie two observed
ordinal variables; the polyserial correlation estimates the Pearson correlation
between one latent bivariate-normal pair where one side is observed continuously
and the other is observed as an ordinal discretization of its latent
counterpart. Both estimators are maximum-likelihood with bounded support
(ρ ∈ (−1, 1)) and a nonlinear objective — no closed-form derivatives exist,
so the estimator relies on numerical optimization. Under a complex survey
design the likelihood becomes a weighted pseudo-likelihood, summing
`w_i · log Pr(case_i | ρ, θ)` across respondents. Because the estimator is
bounded and nonlinear, Mannan (2025) recommends resampling-based inference
(jackknife, bootstrap) as the primary variance method, with pseudo-Taylor
linearization computed on the Fisher-z scale provided as a comparator. Analytic
Taylor linearization is described as "intractable" for these estimators under
two-stage clustered designs; only a numerical influence-function approximation
is feasible.

---

## Formulas

Symbols are bound to `get_corr()` arguments / survey-design slots as follows:

| Paper symbol | surveycore binding |
|---|---|
| `w_i` | `design@data[[design@variables$weights]]` (Taylor) or replicate column (replicate) |
| `x_i`, `y_i` | columns selected by `x = c(var1, var2)` in `get_corr()` |
| `M`, `P` | the two ordinal variables (polychoric); for polyserial `M` is the single ordinal side |
| `θ_2 … θ_{t+1}` | interior thresholds for ordinal `M` (`θ_1 = −∞`, `θ_{t+2} = +∞`) |
| `θ'_2 … θ'_{t'+1}` | interior thresholds for ordinal `P` (polychoric only) |
| `t`, `t'` (or `k1`, `k2`) | number of distinct observed ordinal levels for `M` and `P` |
| `ρ` / `r` | the scalar estimand returned as `r` in the long-format `survey_corr` tibble |
| `ζ` | Fisher z = `atanh(ρ)`, used for CI back-transform and linearization |
| `Φ`, `φ` | `stats::pnorm`, `stats::dnorm` |
| `Φ_2(·,·;ρ)` | bivariate standard-normal CDF (implementation candidate: `pbivnorm::pbivnorm` or `mvtnorm::pmvnorm`; deferred to spec) |

### 1. Threshold estimation (common to both methods)

For each ordinal variable with observed levels `1, …, t` and weighted
cumulative frequencies `F_k`, the paper (§6.1.2, §7.1.1) fixes the thresholds
from the weighted marginal distribution via the normal quantile function:

```
θ_{k+1} = Φ⁻¹( F_k / Σ_i w_i ),   k = 1, …, t−1
θ_1 ≡ −∞,  θ_{t+1} ≡ +∞
```

(SAS code uses `quantile("Normal", Cum_Percent/100)` in PROC IML to compute the
`t−1` finite cutpoints. Here `F_k = Σ_{i : m_i ≤ k} w_i`.)

Thresholds for `P` (polychoric) are estimated identically on its own marginal.

For the **polyserial** continuous variable `X`, Cox (1974) shows the weighted
MLE of `μ_X` and `σ_X` are the weighted mean and (population) standard
deviation of `X` (conditional on this two-step approach), so the standardized
score is:

```
z_i = (x_i − x̄_w) / σ̂_w
 x̄_w = Σ w_i x_i / Σ w_i
 σ̂_w² = Σ w_i (x_i − x̄_w)² / Σ w_i         # population SD, NOT sample SD
```

### 2. Polychoric cell probability

For each observed ordinal pair `(m, p)` the cell probability under
bivariate-normal latent `(Y, X)` with correlation `ρ` is the rectangle
integral (§5.2, §6.1):

```
π_{m,p}(ρ) = Pr(M = m, P = p | ρ, θ, θ')
           = ∫_{θ'_{p+1}}^{θ'_{p+2}} ∫_{θ_{m+1}}^{θ_{m+2}} φ_2(x, y; ρ) dx dy
           = Φ_2(θ_{m+2}, θ'_{p+2}; ρ)
           − Φ_2(θ_{m+1}, θ'_{p+2}; ρ)
           − Φ_2(θ_{m+2}, θ'_{p+1}; ρ)
           + Φ_2(θ_{m+1}, θ'_{p+1}; ρ)
```

with the convention that any term involving an infinite threshold reduces via
`Φ_2(+∞, b; ρ) = Φ(b)` and `Φ_2(a, −∞; ρ) = 0`.

### 3. Polychoric weighted log-likelihood and MLE

Let `n_{m,p}^w = Σ_{i : M_i=m, P_i=p} w_i` be the weighted cell count. Then
(§5.2):

```
ℓ_PC(ρ) = Σ_{m=1}^{t} Σ_{p=1}^{t'} n_{m,p}^w · log π_{m,p}(ρ)

ρ̂_PC = argmax_{ρ ∈ (−1, 1)} ℓ_PC(ρ)
```

With thresholds fixed, this is a one-dimensional optimization. The unweighted
case reduces to Olsson (1979) when all `w_i = 1`.

### 4. Polyserial probability and weighted log-likelihood

For standardized continuous `z_i` and observed ordinal level `m_i` (§5.1,
§7.1.2):

```
Pr(Z = z_i, M = m_i | ρ) = φ(z_i) ·
    [ Φ( (θ_{m_i+2} − ρ z_i) / √(1 − ρ²) )
    − Φ( (θ_{m_i+1} − ρ z_i) / √(1 − ρ²) ) ]

ℓ_PS(ρ) = Σ_{i=1}^{n} w_i · log Pr(Z = z_i, M = m_i | ρ)

ρ̂_PS = argmax_{ρ ∈ (−1, 1)} ℓ_PS(ρ)
```

The `φ(z_i)` factor does not depend on `ρ`, so it can be dropped from the
objective (it enters the score as an additive constant on the log scale). The
paper's SAS `ProbPolyserial` function (p.11) implements the bracket form
exactly, with branches for missing endpoints (leftmost, rightmost categories).
Unweighted case reduces to Cox (1974) when `w_i = 1`.

### 5. Fisher z transform and back-transform

For both estimators:

```
ζ̂ = atanh(ρ̂)
Var(ζ̂) ≈ Var(ρ̂) / (1 − ρ̂²)²        # delta method

CI on ζ scale:  (ζ̂ − z_{α/2} · SE(ζ̂),  ζ̂ + z_{α/2} · SE(ζ̂))
CI on ρ scale:  (tanh(·), tanh(·))
```

The paper (§6.1 preamble, Discussion p.14) emphasises that linearization and
normal-approx-bootstrap intervals **must** be built on the z scale because the
finite-sample distribution of ρ̂ is asymmetric and bounded; normal intervals on
the ρ scale can exceed ±1 and mis-cover near the boundary. Existing
`get_corr()` Pearson path already implements the Fisher-z CI machinery
(`R/analysis-corr-helpers.R`), so the polychoric/polyserial path should reuse
it by feeding in `(ρ̂, SE(ρ̂))`.

### 6. Pseudo-Taylor linearization (survey_taylor path)

Mannan (2025, §6.1, §7.1) acknowledges that the closed-form Taylor influence
function is intractable and falls back to a **numerical influence-function
approximation**. The construction (reconstructed from the paper's narrative
and standard pseudo-ML linearization, e.g. Lumley 2010 ch.6):

1. Compute ρ̂ on full sample (or ζ̂ = atanh(ρ̂)).
2. For each respondent `i`, approximate the influence function numerically:
   either (a) score-based — evaluate
   `u_i(ρ̂) = ∂ log Pr(case_i | ρ, θ) / ∂ρ` by finite difference at ρ̂ and
   divide by `−A(ρ̂) = −Σ w_i ∂u_i/∂ρ`, or (b) perturbation-based — recompute
   ρ̂ with `w_i` replaced by `w_i(1 + ε)` and use
   `IF_i ≈ (ρ̂_pert − ρ̂) / ε`.
3. Map to the z scale: `IF_i^{ζ} = IF_i / (1 − ρ̂²)`.
4. Plug `IF_i^{ζ}` into the Horvitz–Thompson / Hájek variance estimator for a
   total, accounting for stratification and PSU clustering — this is exactly
   what `survey_taylor` objects already support via the influence-function
   pattern in `R/06-variance-estimation.R`.
5. SE(ζ̂) on z scale → CI on z scale → back-transform CI to ρ scale; SE on ρ
   scale is reported via delta method: `SE(ρ̂) = (1 − ρ̂²) · SE(ζ̂)`.

The paper is explicit that this pseudo-Taylor path tends to produce *wider*
CIs than resampling because linear approximations degrade near the ρ boundary
(their polychoric example: SE_Taylor = 0.255 vs SE_bootstrap = 0.063 at
ρ̂ = −0.87). This is a known structural limitation, not an implementation bug.

### 7. Replicate-weight variance (survey_replicate path)

For replicate designs with stored replicate-weight columns (JK*, BRR, Fay,
bootstrap, subbootstrap):

```
ρ̂^{(r)} = argmax ℓ(ρ; w^{(r)}, θ^{(r)})   for each replicate r = 1, …, R
ζ̂^{(r)} = atanh(ρ̂^{(r)})

Var(ζ̂) = Σ_r c_r · (ζ̂^{(r)} − ζ̂)²        # c_r from design: JK, BRR scales, etc.
SE(ρ̂)  = (1 − ρ̂²) · √Var(ζ̂)              # via delta method
```

Thresholds should be re-estimated per replicate (`θ^{(r)}` uses replicate
weights in the weighted marginal cumulative) because threshold uncertainty
and ρ uncertainty share replicate-induced variation; the paper's jackknife
procedure (§6.1) re-runs the full two-step MLE inside each replicate deletion.
This is computationally O(R × optimization_cost).

### 8. Rao–Wu bootstrap

The paper's primary recommended variance method for `survey_replicate`
objects of *bootstrap* type is Rao–Wu (1988) with `b_r` resampled PSUs per
stratum with replacement, rescaled weights. Implementation-wise this is just
the replicate-weight path above applied to bootstrap replicate weights. **Key
scope note**: surveycore `survey_replicate` designs consume *stored*
replicate-weight columns only; they do not generate bootstrap replicates
on-the-fly. Whether the user supplied JK or bootstrap replicates is already
encoded in `@variables$replicate_type`. No new variance machinery is needed
beyond the replicate loop.

---

## Gotchas

1. **ρ̂ near ±1 (boundary of parameter space)** — log-likelihood surface
   becomes flat (polychoric) or infinite at ±1 (polyserial denominator
   `√(1−ρ²)` → 0). Must clamp optimizer bounds to
   `(−1 + ε, 1 − ε)` with `ε ≈ 1e-6` and warn when ρ̂ lands within `ε` of the
   boundary (Fisher z SE explodes there; delta method is unreliable).

2. **Unobserved ordinal level(s)** — if an interior category has zero weighted
   frequency, its cumulative proportion ties with the previous level, collapsing
   two adjacent thresholds to the same value and producing cells with
   `π_{m,p} = 0`. The likelihood is `−∞` there. SAS code implicitly drops
   zero-count rows via `where Y1 ne .`; we need an explicit policy — drop the
   level, renumber, warn.

3. **Sparse bivariate cells** — a single observed cell with
   `n_{m,p}^w > 0` but `π_{m,p}(ρ) = 0` at the MLE blows up the likelihood.
   Typical with small `n` and many levels (e.g., 7×7 Likert × Likert with
   n=100). Need numerical floor on `π_{m,p}` (e.g., `max(π, 1e-300)`) and a
   warning when any observed cell's modeled probability is below a tolerance.

4. **Single-level ordinal variable** — if an ordinal variable has only one
   observed level (after NA removal / domain filtering), the threshold vector
   is empty and the estimator is undefined. Must error hard with a clear class.

5. **NA in either variable (listwise vs domain vs physical)** — Mannan's SAS
   code uses `where Y ne .` which is listwise deletion on the subset. For
   surveycore: (a) if the survey object is domain-subsetted via `filter()`,
   non-domain rows have zero effective weight and contribute 0 to the
   likelihood — do NOT physically drop them (breaks variance paths); (b) rows
   with NA in either involved variable should be excluded pairwise (existing
   `get_corr()` convention with `na.rm = TRUE`). Rows with NA in the weight
   are already excluded by the survey constructor.

6. **Degenerate weighted sample** — need guard: `n_distinct_cells ≥ t × t'` is
   not required (paper says cells can be empty), but `n_effective_rows` must
   exceed some minimum or the optimizer returns a boundary point trivially.

7. **Replicate designs with BRR / Fay type** — jackknife-style PSU deletion
   is not what BRR does. But the replicate variance formula in §7 above is
   general: any replicate design with stored weights and a known variance
   coefficient `c_r` works. The paper only demonstrates JK and bootstrap, but
   BRR/Fay are mathematically valid — they just use the design's own scale
   factor. Caveat: paper does not endorse BRR specifically for this nonlinear
   estimator; user should be aware. No new warning unless convergence fails in
   some replicates.

8. **Optimizer non-convergence** — `optim(method = "L-BFGS-B")` or
   `optimize()` may fail to converge when the objective is nearly flat, when
   weights are extremely skewed, or at boundary. Must detect and either
   (a) error with a clear class, or (b) fall back to a coarser grid search +
   refinement. For *replicate* loops, if a small fraction of replicates fail,
   policy should be: warn, and either skip failed replicates (reducing
   effective R) or propagate NA — defer to spec.

9. **Polyserial canonicalization** — `get_corr()` currently treats `x = c(a, b)`
   symmetrically (Pearson correlation is symmetric). Polyserial needs to know
   which side is ordinal. Policy candidates, all deferrable to spec:
   (a) auto-detect from column type (factor/ordered → ordinal, numeric →
   continuous; error if ambiguous); (b) require the user to pass factors as
   factors for ordinal; (c) add an explicit argument naming the ordinal side.
   Current implementation detail: `get_corr()` drops non-numeric columns with
   a warning — that exact behavior will need to change when `method !=
   "pearson"`.

10. **Factor-level ordering** — thresholds require an *ordered* sequence. For
    a `factor` (unordered), levels() defines an order that may be
    lexicographic and meaningless. Policy: accept `ordered` unconditionally;
    accept `factor` with a warning that levels() order is used; reject
    `character`. Integer vectors are accepted in their natural order.

11. **Large `t` (many ordinal levels)** — cost of polychoric likelihood is
    `O(t × t')` bivariate-normal CDF evaluations per optimization step, × O(R)
    for replicate variance. For a 7×7 Likert pair and R = 200 jackknife
    replicates, that is ~10⁴ bivariate-normal evaluations per pair. With
    10 variables (45 pairs) the user pays ~5×10⁵ evaluations. Not prohibitive
    but should be documented; can cache the threshold-estimation step per
    variable per replicate.

12. **FPC interaction with bootstrap** — Rao–Wu bootstrap rescales weights;
    if FPC is set, the rescaling formula must account for it. Since surveycore
    consumes *stored* replicate weights, FPC correction is already baked into
    the supplied replicate columns — not our concern. Flag for spec only:
    ensure we do not double-correct.

13. **Domain estimation with zero-weight rows** — `filter()` marks domain
    membership without removing rows. Zero-weight rows should contribute
    `0 · log(…) = 0` to the likelihood — but `log(0)` is `−∞`. Implementation
    must guard: `sum(w_i * log_p_i)` where the term is identically 0 whenever
    `w_i = 0`, regardless of `log_p_i`. Use `w_i * ifelse(w_i > 0, log(p_i), 0)`
    or similar, not `w_i * log(p_i)` directly.

14. **Fisher-z at ρ̂ exactly 0** — `atanh(0) = 0`; `Var(ζ̂) = Var(ρ̂)` at ρ=0;
    no pathology, but note that the existing Pearson Fisher-z path should
    behave identically — no special case needed.

15. **Polychoric degenerate cell marginalization (paper's implicit behavior)**
    — the SAS cross-tabulation drops cells with `Y1 ne . and Y2 ne .`.
    That is pairwise listwise deletion, already standard for `get_corr()`.

---

## Reference mapping

| Citation | Where | Informs which design decision |
|---|---|---|
| Mannan (2025) §3.1–3.2 | Definition of polychoric / polyserial as latent bivariate-normal MLE | The `method = c("pearson", "polychoric", "polyserial")` argument structure; single entry point |
| Mannan (2025) §5.1, eq. `Pr(ρ, Θ, Z, M)` | Polyserial conditional probability with `√(1−ρ²)` denominator | Polyserial likelihood implementation; boundary clamp `|ρ| < 1 − ε` |
| Mannan (2025) §5.2, double-integral `Pr(ρ, Θ, Θ', P, M)` | Polychoric cell probability over rectangle | Polychoric likelihood implementation; requires bivariate-normal CDF |
| Mannan (2025) §6.1 (two-step procedure) | Fix thresholds from weighted marginals, then 1-D optim over ρ | Two-stage estimation pattern (threshold step + MLE step), re-run both inside each replicate |
| Mannan (2025) §6.1 pseudo-Taylor paragraph | Linearization on Fisher z scale via numerical influence function | Taylor variance path wiring — reuses existing `survey_taylor` influence-function infrastructure; SE reported on ρ scale via delta-method |
| Mannan (2025) §6.1 jackknife paragraph + §7 | PSU-level replicate re-estimation for nonlinear estimator | Replicate variance path; re-estimate both thresholds and ρ per replicate |
| Mannan (2025) Discussion p.14 ("Taylor yields overly wide CIs…") | Pseudo-Taylor CIs are structurally wide near boundary | Documentation note; warning class `surveycore_warning_polychoric_taylor_boundary` (TBD in spec) |
| Mannan (2025) §8.1–8.2 truncation note ("confidence limits were truncated to the admissible range of −1 to 1") | Clamp back-transformed CI endpoints to [−1, 1] | CI assembly in both paths |
| **Olsson (1979), Psychometrika 44(4):443–460** *(peer-reviewed)* | Unweighted polychoric MLE — the `w_i = 1` base case | Oracle for numerical tests (cross-check against `polycor::polychor` with equal weights) |
| **Cox (1974), Biometrics 50(March):171–187** *(peer-reviewed)* | Unweighted polyserial MLE — derivation that weighted `x̄`, `σ̂` are MLEs | Justifies standardizing the continuous variable using weighted moments before MLE over ρ; validates the two-step approach |
| Rao & Wu (1988) JASA 83:231–241 | Bootstrap rescaling for multistage samples | Cited as background; no direct code implication since surveycore consumes pre-built replicate weights |
| Lumley (2010) ch.6 | Influence-function variance for complex designs | Theoretical and implementation basis for the numerical influence-function pseudo-Taylor variance used by surveycore's Pearson path, reused here |
| Korn & Graubard (1999), *Analysis of Health Surveys* | Ch. 2, design-based inference for smooth functionals | Cited by Mannan (2025) for the general framework of design-based inference under stratification and clustering |

**Provenance caveat**: Mannan (2025) is a preprint with a visible "Preprint, not peer reviewed" watermark on every page. The core MLE derivations (unweighted) are Olsson (1979) and Cox (1974), both peer-reviewed. The preprint's novel content is (a) applying weighted pseudo-likelihood, which is a standard pseudo-ML substitution well established in survey statistics, and (b) the specific SAS implementation and example tables. Conceptually there is no new methodology being invoked; the extension from unweighted MLE to weighted pseudo-MLE is mechanical. Treat the paper as an implementation guide / citation anchor, not as a primary methodological source.

---

## Assumptions (implicit in the method, not stated in the user request)

1. **Bivariate normality of latent variables.** The entire polychoric/polyserial framework assumes `(Y_latent, X_latent) ~ N_2(0, Σ)`. There is no diagnostic test for this in the paper or in surveycore. Document the assumption; do not attempt to test it.

2. **Thresholds are treated as known once estimated.** The two-step procedure (thresholds from marginals, then ρ via MLE holding thresholds fixed) ignores the uncertainty in threshold estimation when computing SE(ρ̂) via the Taylor path. The *replicate* path implicitly accounts for threshold uncertainty by re-estimating thresholds inside each replicate. This discrepancy is intentional in the paper (§6.1 and §7.1 both re-run thresholds inside the replicate loop) and must be preserved.

3. **Weighted continuous MLE is weighted mean and population (not sample) SD.** Per Cox (1974), the MLE standardization uses `σ̂² = Σw(x−x̄)²/Σw` with no degrees-of-freedom correction. This differs from `stats::weighted.mean()` paired with a sample-SD-style weighted variance.

4. **Factor-level ordering is taken as given.** Surveycore cannot infer correct ordering. The user is responsible for supplying `ordered` factors or integer codes that respect the intended scale direction. Reverse-coded items will produce sign-flipped estimates.

5. **Design variables (strata, PSU, weights) are already validated.** The survey-design constructor enforces positivity, non-NA, column existence. The estimator trusts the design object and does not re-validate.

6. **Numerical-optimization tolerance is a user-invisible default.** The paper does not specify a tolerance. surveycore should pick a default (e.g., `optim(reltol = 1e-8)`) and not expose it as an argument in v1; expose only if user demand appears.

7. **Listwise (pairwise) deletion on NA is the implicit policy.** The SAS code uses `where Y ne .` everywhere. For `get_corr(method = …)`, use pairwise-complete-cases (same as existing Pearson path, `na.rm = TRUE` default). Do NOT attempt to re-weight for missingness within the estimator.

8. **"Stratified cluster sample" in the paper means surveycore's `survey_taylor` with strata + ids.** The paper assumes strata + PSU throughout. SRS-without-design (no strata, no ids — the surveycore default with only weights) is mentioned only in §discussion as a "less complex design" deferred to code-on-request. surveycore must support it: thresholds and ρ̂ are unchanged; variance degenerates to an IID-style calculation via the existing `survey_taylor` Taylor machinery. No special-casing needed in the estimator.

9. **`survey_twophase` and `survey_nonprob` handling.** User request locks variance dispatch to "match existing `get_corr()`". Existing Pearson path handles `survey_twophase` via phase-2 subset and `survey_nonprob` via its own variance machinery. Whether the pseudo-Taylor influence-function approach extends correctly to two-phase / nonprob for polychoric/polyserial is not addressed in Mannan (2025). This is a **potential spec-time question** — in the interest of not raising HOLD prematurely, the safe default is: implement for `survey_taylor` and `survey_replicate` (the two designs the paper actually covers), and explicitly error for `survey_twophase` and `survey_nonprob` with `method != "pearson"` in v1. If user objects at spec review, expand scope then.

10. **Bivariate-normal CDF implementation is unspecified by the paper.** SAS uses the built-in `PROBBNRM`. R candidates: `pbivnorm::pbivnorm` (fast, accurate, Imports a small C package), `mvtnorm::pmvnorm` (slower but bundles many features surveycore likely already has access to). Defer to spec.

---

## Open questions (for spec stage, not HOLD)

- Which bivariate-normal CDF library to Import (`pbivnorm` vs `mvtnorm`)?
- Which 1-D optimizer (`stats::optimize` for pure 1-D vs `stats::optim(method = "Brent")` vs `optim(method = "L-BFGS-B")` with bounds)?
- Polyserial canonicalization mechanism (auto-detect from column type, explicit argument, or user-prepared factors)?
- Behavior on `survey_twophase` and `survey_nonprob` with `method != "pearson"`: error, or extend variance path?
- Default for replicate convergence failures: skip failed replicates with warning, or hard error?
- Whether to expose optimizer tolerance as a user argument or keep it hardcoded at the default.

None of these require user input before the spec can be drafted; the spec author can propose defaults and the reviewer can accept/revise.

---

## Ready-state

Comprehension coherent. Methodology is well-grounded in two peer-reviewed sources (Olsson 1979, Cox 1974); the preprint contributes only the weighted-pseudo-likelihood substitution (a standard pseudo-ML technique) and SAS-specific implementation. All major gotchas enumerated. Reference-to-design mapping complete. Assumptions surfaced. No methodological ambiguity that requires user input before spec can be drafted.
