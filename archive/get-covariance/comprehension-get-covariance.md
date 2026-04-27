# Comprehension — get-covariance

## Problem

`get_covariance()` is a design-based pairwise finite-population covariance
estimator for the surveycore `get_*()` family. For `method = "pearson"`
(default), it must reproduce the off-diagonal entries of `survey::svyvar()`
numerically across `survey_taylor`, `survey_replicate`, `survey_twophase`,
and `survey_nonprob` designs — including the Kish `n/(n - 1)` finite-sample
correction. The API mirrors `get_corr()`: tidy-select input of ≥ 2 numeric
variables, a long-format one-row-per-ordered-pair output with opt-in
uncertainty columns, `redundant`/`diagonal` flags, and `survey_collection`
dispatch. Because covariance is unbounded, confidence intervals use the
normal-Wald approximation (matching `get_variance()`) instead of the Fisher
Z used in `get_corr()`. The `method` argument also accepts `"polychoric"`
for ordinal × ordinal pairs via `polycor::polychor()` (Suggests); the exact
semantics (standardized-latent vs rescaled) are flagged below as a
resolution needed before spec drafting.

## Formulas

Let `D` = active domain (after `.apply_domain()`, group-combo masking, and
pairwise complete-case deletion for `(x, y)` when `na.rm = TRUE`). Let
`n = |D|` (unweighted), `w_i` = weight, `W = Σ_{i ∈ D} w_i`,
`x̄ = (Σ w_i x_i)/W`, `ȳ = (Σ w_i y_i)/W`.

### Pearson covariance (match `svyvar()` off-diagonal)

```
b_plug = Σ_{i∈D} w_i (x_i − x̄)(y_i − ȳ) / W           # plug-in
kish   = n / (n − 1)
cov̂(x, y) = kish · b_plug                             # point estimate
```

The existing `.vcov_pair_*()` engines already compute `b_plug` as field
`b` and return a 3×3 meta-vcov `sigma` with column/row ordering
`(Var(X), Cov(X,Y), Var(Y))` — but crucially they compute the **plug-in**
influence functions, **without** multiplying by `kish`. Verification
(reading the four engine files):

- `R/variance-taylor.R:372–404` — `a, b, c` are `sum(w * ...)/W_d`
  (plug-in); `infl_*` do not include the `n/(n-1)` factor. No Kish.
- `R/variance-replicate.R:188–239` — same plug-in form for the full sample
  and per-replicate `a, b, c`. No Kish.
- `R/variance-twophase.R:575–611` — same plug-in form; `sigma` assembled
  from `.twophasevar()` on `infl_a, infl_b, infl_c`. No Kish.
- `R/analysis-corr-helpers.R:85–106` (`.vcov_pair_calibrated()` for
  nonprob) — `a, b, c` plug-in; `sigma = (n/(n-1)) * crossprod(infl_mat)`.
  **Here the `n/(n-1)` factor is in the meta-vcov scaling only**, not in
  the point estimate.

In contrast, `.score_variance()` + `.taylor_variance_cell()` +
`.replicate_variance_cell()` + `.twophase_variance_cell()` +
`.nonprob_variance_cell()` (in `R/analysis-variance-helpers.R`) all
multiply the score `z_i = w_i · a_i · (y_i − ȳ)^2 · kish` by `kish`
before computing the point estimate and influence functions — which is
exactly why `get_variance()` matches `svyvar()` diagonals.

**Implication for `get_covariance()`.** The `.vcov_pair_*()` engines as
written are **not** directly reusable for the svyvar-matching covariance.
The family has two plausible routes:

1. **Post-scale route** — call the existing engine, then multiply `b` by
   `kish`, multiply `sigma[2, 2]` by `kish^2`, and fix the nonprob meta-vcov
   so its embedded `n/(n-1)` factor is not double-counted. For Taylor /
   replicate / twophase this is clean because their `sigma` is the variance
   of the plug-in `b` and the influence functions do not include `kish`. For
   nonprob the engine already folds `n/(n-1)` into `sigma`; post-scaling
   `sigma[2,2]` by another `kish^2` over-corrects, so nonprob needs a
   different branch (scale by `kish` for variance-of-kish-scaled-b from a
   `sigma` that already has one `kish`: just multiply by `kish`, not
   `kish^2`). This asymmetry is error-prone.
2. **Parallel engine route** — write `.cov_pair_*()` helpers mirroring
   `.score_variance()`/`.variance_cell()`: score `z_i = kish · (x_i − x̄)(y_i − ȳ)`,
   influence of the weighted mean of `z` run through the same
   `.svy_recvar()` / `.svy_rep_var()` / `.twophasevar()` / HT-linearization
   machinery used by `get_variance()`. This is the structurally identical
   pattern used for `get_variance()` and avoids the nonprob asymmetry.

**Recommendation for spec**: adopt Route 2 (parallel engine). It is
uniform across designs, uses the same machinery as the already-correct
`get_variance()`, and does not rely on `.vcov_pair_*()` internals that
exist for a different purpose (delta-method correlation, where `kish`
cancels). Flag the deviation from the request's implicit "reuse
`.corr_vcov_pair()`" framing as a HOLD for the user.

### SE of Pearson covariance

Under Route 2, SE falls out of the existing weighted-mean-of-score
machinery. Let `z_i = kish · (x_i − x̄)(y_i − ȳ)` on the active pair
domain, 0 elsewhere. Then `cov̂ = (Σ w_i z_i) / W` and
`SE(cov̂) = SE(weighted mean of z)` computed by Taylor linearization
(`.svy_recvar()` on `u_i = w_i · (z_i − cov̂)/W`), per-replicate recomputation
(recompute `cov̂^{(r)}` with replicate weights `w^{(r)}`, then `.svy_rep_var()`),
per Phase-2 Taylor (`.twophasevar()` on the linearized influence), or HT
Taylor for nonprob (`n/(n-1) · Σ w_i^2 (z_i − cov̂)^2 / W^2`). No delta
method is needed — covariance is a linear combination of moments, not a
ratio like correlation.

### Confidence intervals

Normal-Wald on the SE of `cov̂`:

```
z_crit  = qnorm((1 + conf_level) / 2)           # degf = Inf
ci_low  = cov̂ − z_crit · SE(cov̂)
ci_high = cov̂ + z_crit · SE(cov̂)
```

No clamping. Matches `get_variance()`. The `t_crit` in `.add_variance_cols()`
with `degf = Inf` reduces to `z_crit`, so `.add_variance_cols()` can be
reused directly.

### Polychoric (method = "polychoric")

The polychoric correlation ρ is the Pearson correlation between two
latent standard normal variables X*, Y* assumed to generate the observed
ordinal pair via threshold cuts. Under the classical model, X* and Y*
have unit variance by construction, so the latent covariance
`Cov(X*, Y*) = ρ` equals the polychoric correlation numerically. Two
coherent returns for `method = "polychoric"`:

1. **Standardized-latent** (recommended default): return
   `cov̂_polychoric = ρ̂_polychoric` — the covariance of the latent
   standardized variables. This is what `svyvar()`'s polychoric analogue
   would mean if it existed. It agrees with `get_corr(method = "polychoric")`
   (future) on the same input. Implementation: compute the survey-weighted
   2D contingency table for each pair and pass `weights` into
   `polycor::polychor()`'s internal ML via a weighted bivariate pseudo-
   sample, or use the weighted frequency table directly if
   `polychor()` accepts it.
2. **Rescaled**: return `ρ̂_polychoric · ŝ_x · ŝ_y` where
   `ŝ_x = √Var̂(x)`, `ŝ_y = √Var̂(y)` are the survey-weighted sample
   standard deviations of the observed ordinal scores. This puts the
   estimate on the observed (integer-coded) scale and is more directly
   comparable to the Pearson covariance. It is non-standard and has no
   canonical reference implementation.

Both are defensible; they carry different downstream semantics. HOLD.

### Polychoric SE under complex survey designs

Survey-weighted polychoric is not standard practice. Three options:

(a) **Design-ignoring ML SE**: call `polycor::polychor(..., std.err = TRUE)`
    on the weighted 2D table and return the ML `std.err` as-is. Fast;
    wrong for clustered / stratified designs; matches no reference
    implementation exactly. Effectively treats the weighted frequencies
    as if they came from an SRS of size `n_eff`.
(b) **Replicate-resample**: for `survey_replicate`, fit `polychor` on each
    replicate's weighted table and apply `.svy_rep_var()`. Exact under the
    replicate-design assumption but expensive (one ML fit per replicate,
    possibly hundreds). No equivalent for Taylor/twophase/nonprob unless
    we add a bootstrap.
(c) **NA-with-warning for non-replicate designs**: compute the point
    estimate (a or b above) but return `se = NA_real_` with a warning for
    designs where (b) does not apply, and optionally support (b) for
    `survey_replicate`. This is the honest option; downstream users can
    still use the point estimate for reporting.

Recommendation: pair (a) with a warning, OR ship polychoric with a
point estimate only (SE = NA, `variance = NULL` coerced) and defer SE
work. HOLD.

### Diagonal semantics

Unlike `get_corr()`, where `diagonal = TRUE` emits `r = 1, se = 0`, the
covariance diagonal is the **variance** of `x` (i.e., `a` from the
vcov-pair machinery, or equivalently `get_variance(x)`). Specifically
`diagonal = TRUE` pairs emit:

```
var1 = var2 = x
covariance = kish · a_plug = Var̂(x)
se         = √sigma[1, 1]  (Route-1) or via variance-of-variance machinery (Route-2)
n          = unweighted non-NA count for x alone (not pairwise)
```

This must be documented explicitly in the function docs because the
semantic differs from `get_corr()`.

## Gotchas

- **Kish `n/(n-1)` correction is not in `.vcov_pair_*()` engines.** The
  engines were written for correlation, where `kish` cancels in
  `r = b/√(a·c)`. Reusing them naively for covariance under-estimates
  by a factor of `kish` at small n. Discovered by reading
  `variance-taylor.R:372–404` and companions; confirmed by contrast with
  `analysis-variance-helpers.R:.score_variance()`.
- **`.vcov_pair_calibrated()` for nonprob already folds `n/(n-1)` into
  `sigma`.** Asymmetry with the other three engines; Route-1 post-scaling
  must handle this branch differently. Route-2 (parallel engine)
  sidesteps.
- **Unbounded covariance — no Fisher-Z CI.** Use Wald directly. Bounds
  can have any sign; do not clamp. Matches `get_variance()`.
- **Degenerate (constant) variable.** `b_plug = 0`, `sigma[2, 2] = 0`,
  `cov̂ = 0`, `se = 0`. Emit no warning (matches `get_variance()`'s
  treatment via the floating-point snap in `.score_variance()`).
- **All-NA pair.** `n = 0`, `NaN` point and SE, warn (new class
  `surveycore_warning_covariance_all_na` mirroring
  `surveycore_warning_variance_all_na`).
- **Fewer than 2 non-NA pairwise observations.** `n < 2`, `NaN` point and
  SE, warn (`surveycore_warning_covariance_insufficient_n`).
- **Single-PSU-per-stratum.** Propagated via `getOption("survey.lonely.psu")`
  from `.svy_recvar()` / `.twophasevar()` — same behaviour as
  `get_variance()`.
- **Replicate DoF.** `.svy_rep_var()` handles rscales and scale; no
  special-case needed in the analysis layer beyond passing `mse = isTRUE(vars$mse)`.
- **Twophase variance propagation.** Use `.twophasevar()` on the
  influence of the weighted mean of the score. Phase-1-only rows
  contribute 0 influence. Identical pattern to
  `.twophase_variance_cell()`.
- **`diagonal = TRUE` n is per-variable, not pairwise.** Diagonal rows
  have `n = sum(active_mask & !is.na(x))`, not the pairwise n. Document.
- **`deff` under covariance.** The SRS-equivalent SE of a covariance
  under true SRS of size n is
  `SE_SRS(cov̂) = √((Var̂(x) · Var̂(y) + cov̂^2) / (n − 1))` (Goodnight /
  Mood & Graybill). This is well-defined whenever `Var̂(x) > 0` and
  `Var̂(y) > 0`. It is NOT simply the Fisher-Z shortcut used by
  `get_corr()`. Unclear whether `deff` is in scope; the request allows
  it via `variance = "deff"`. Propose: compute it using the
  Goodnight/M-G formula OR drop `"deff"` from the allowed set for
  `get_covariance()`. HOLD.
- **Polychoric ordinal coercion.** `polycor::polychor()` accepts integer
  vectors; ordered factors are converted internally. Unordered factors
  are wrong inputs. Policy: require `is.ordered(col)` OR
  `is.integer(col)` — reject others with a typed error. Matches
  `polycor` conventions.
- **Polychoric zero-count cells.** ML can fail on near-zero 2D cell
  counts. Wrap the call in `tryCatch()`; on failure emit a warning and
  return `NaN` for that pair.
- **Polychoric on replicate designs is expensive.** If we adopt
  replicate-resample SE, each replicate fits its own polychor ML. With
  hundreds of replicates this is slow. Explicitly note the perf
  implication in the spec.
- **Redundant/diagonal flags preserve lower-triangle supply order.**
  Re-use the expansion logic verbatim from `get_corr()` Step 14.
- **Wide format is out of scope** per the request. Confirm.
- **Survey-weighted polychoric SE has no canonical reference.** Parity
  target for `"polychoric"` must be defined against a specific reference
  call (e.g., `polycor::polychor(x, y, std.err = TRUE)` on the weighted
  table with design ignored), or loosened. HOLD.
- **Point-estimate column naming.** Per request, the point column is
  `covariance`; `name_style = "broom"` remaps to `estimate`. Matches
  `get_variance()`.

## Reference mapping

- `R/analysis-corr.R` → API skeleton: arg order, tidy-select input
  requirement of ≥ 2 variables, grouping loop, `redundant`/`diagonal`
  pair expansion, `.apply_domain()`, display-name mechanics, factor
  levels on `var1`/`var2`, `survey_collection` dispatch via
  `.dispatch_over_collection()`.
- `R/analysis-corr-helpers.R:.vcov_pair_calibrated()` → nonprob
  HT-linearization template (note the embedded `n/(n-1)` factor —
  different placement from the other engines).
- `R/variance-taylor.R:.vcov_pair_taylor()` → Taylor influence-function
  template; confirms plug-in `b` and no Kish on `sigma`.
- `R/variance-replicate.R:.vcov_pair_replicate()` → replicate template;
  confirms plug-in `b` in both full-sample and per-replicate `a, b, c`.
- `R/variance-twophase.R:.vcov_pair_twophase()` → twophase template;
  polarization identity for off-diagonal covariances.
- `R/analysis-variance.R` → Wald-CI construction via
  `.add_variance_cols()` with `degf = Inf`; column labeling via
  `.attach_variance_labels()` (adapt to `covariance`-specific label map);
  `surveycore_warning_variance_all_na` /
  `surveycore_warning_variance_insufficient_n` as templates for the
  covariance equivalents.
- `R/analysis-variance-helpers.R:.score_variance()` and the four
  `*_variance_cell()` helpers → **primary template** for Route-2
  parallel engine. The score-based weighted-mean-influence pattern is
  exactly what Pearson covariance needs.
- `plans/error-messages.md` → reuse `surveycore_error_insufficient_variables`
  (row 44), `surveycore_error_non_numeric_variable` (row 43),
  `surveycore_error_unsupported_class` (row 64), `surveycore_warning_small_cell`
  (row 49), `surveycore_warning_single_level` (row 50),
  `surveycore_warning_cv_undefined` (row 54). New classes likely needed:
  - `surveycore_warning_covariance_all_na`
  - `surveycore_warning_covariance_insufficient_n`
  - `surveycore_warning_covariance_non_numeric` (drop with warning,
    analog of row 51 `surveycore_warning_corr_non_numeric`)
  - `surveycore_error_polycor_missing` (optional Suggests dependency)
  - `surveycore_error_polychoric_bad_type` (non-ordered, non-integer)
  - `surveycore_warning_polychoric_fit_failed` (zero-cell / non-convergence)
- `survey::svyvar()` — implements
  `sum(w * (x - xbar) * (y - ybar)) / sum(w) * n/(n-1)` for off-diagonal;
  variance via influence of the vectorized `(y - ybar)(y - ybar)ᵀ`
  outer product. This is the numerical-parity target.
- `polycor::polychor(x, y, std.err = TRUE, ML = TRUE)` — returns a list
  with `$rho`, `$var` (ML variance of rho), `$n`, `$chisq`, `$df`. If we
  adopt design-ignoring ML SE, this is what we call. Signature and
  return structure pinned from the polycor reference manual, not
  verified against an installed copy (polycor is not in the current
  package environment).
- `project_analysis_meta_structure.md` → nested `group` / `x` meta
  shape; add `method` to top-level for `CORR_META_KEYS`-style
  `COVARIANCE_META_KEYS`.
- `project_column_labels.md` → set `attr(col, "label")` on every output
  column via a `.attach_covariance_labels()` helper.

## Assumptions

1. **`.vcov_pair_*()` engines are NOT reused directly** for
   `get_covariance()`; Route-2 parallel engine (`.covariance_pair_*()`)
   is adopted. Deviation from the request's implicit framing is flagged
   as a HOLD. The existing engines remain dedicated to
   `.corr_vcov_pair()` for correlation.
2. **Pairwise deletion** matches `svyvar()`. svyvar's default is
   listwise (any NA in any requested variable drops the row from every
   pair), but because `get_covariance()` emits one pair at a time with
   the `.apply_domain()` + per-pair mask, pairwise is natural and
   matches `get_corr()`. Numerical parity against `svyvar()` requires
   single-pair calls or listwise-filtered inputs; this should be called
   out in the test plan.
3. **Kish correction** is applied to the point estimate and folded into
   the score before SE computation (as in `.score_variance()`).
4. **`degf = Inf`** for the Wald CI, matching `get_variance()` and
   `svyvar()` defaults.
5. **Polychoric** is in scope for this PR, not deferred. (HOLD: may
   defer.)
6. **Polychoric point-estimate convention** is "standardized-latent"
   (return `ρ`). (HOLD.)
7. **Polychoric SE** is design-ignoring ML from
   `polycor::polychor(std.err = TRUE)`, emitted with a warning. (HOLD.)
8. **`deff`** is supported via the Goodnight / Mood-Graybill SRS
   covariance-variance formula. (HOLD: may drop.)
9. **Wide format is out of scope.** (HOLD: confirm with user.)
10. **`survey_collection` dispatch** reuses `.dispatch_over_collection()`;
    no new plumbing.

## Proposed HOLD signals for the user

1. **Polychoric point-estimate interpretation** (standardized-latent vs
   rescaled by observed sd product). The request explicitly flags this.
   The two conventions give numerically different outputs; the choice
   affects downstream regression semantics and `gt` rendering. Default
   recommendation: standardized-latent (matches the identity in the
   acceptance criteria: `cov_polychoric == cor_polychoric`).
2. **Polychoric SE strategy**: (a) design-ignoring ML from
   `polycor::polychor(std.err = TRUE)`, (b) replicate-resample
   (replicate designs only), (c) NA-with-warning. Each has a different
   honesty/performance tradeoff.
3. **Whether to ship polychoric in this PR or defer it.** Polychoric
   adds a Suggests dependency, two new error classes, a non-standard SE
   methodology, and expensive replicate-resample paths. Splitting would
   let Pearson land quickly with tight numerical parity, then revisit
   polychoric with a dedicated methods review.
4. **`deff` behavior under covariance.** Options: (a) use Goodnight /
   Mood-Graybill `(Var(x)·Var(y) + cov̂²)/(n−1)` as the SRS reference,
   (b) drop `"deff"` from `variance` for `get_covariance()` and warn
   or error if supplied. The request is silent; `get_corr()` computes
   a Fisher-Z-style `deff` that does not generalize here.
5. **Parallel engine vs post-scaled reuse of `.corr_vcov_pair()`**:
   confirm Route-2 is acceptable. The request's "most infrastructure is
   reusable" framing implied reuse of `.corr_vcov_pair()`; deep reading
   of the engines shows that path leads to a nonprob-asymmetric,
   Kish-correction-dependent branch structure that is error-prone and
   under-tested. Route-2 is cleaner but adds ~200 lines of helper code
   (five `.covariance_pair_*()` functions mirroring
   `.variance_cell()`'s structure).
6. **Wide format out of scope.** Confirm with user; the request lists
   it as out of scope but the acceptance criteria implicitly reference
   a `survey_covariance` result class that elsewhere in the family
   supports both long and wide.
7. **Pairwise vs listwise NA handling.** Confirm pairwise (matches
   `get_corr()`); `get_variance()` offers both. If listwise is desired,
   add `na_handling` arg matching `get_variance()`.
