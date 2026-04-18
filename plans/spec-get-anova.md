# Spec: `get_anova()` and `anova.survey_glm_fit()`

**Version:** 0.6 (methodology-locked + code-review-resolved Pass 2)
**Date:** 2026-04-17
**Status:** Approved — Stage 3/4 Pass 2 complete; ready for `/implementation-workflow`

---

## Document Purpose

This document is the authoritative specification for `get_anova()` and the S3
method `anova.survey_glm_fit()`. It is modeled on `survey::anova.svyglm()`
(see `R/anova.svyglm.R` in the survey source tree) and the helper
`survey::regTermTest()` (`R/regtest.R`), but uses surveycore style: typed
errors, result tibbles, `.meta`, and surveycore's own variance machinery
(`survey_glm()` / `survey_glm_fit@vcov`).

`get_anova()` is the primary user-facing API and follows the `get_*()`
analysis-function convention. `anova.survey_glm_fit()` is a thin S3 wrapper
registered dynamically (following the pattern in `R/glm-methods.R`) so that
`anova(fit)` and `anova(fit1, fit2)` route to `get_anova()`.

---

## I. Scope

### What This Delivers

| Component | Description |
|---|---|
| `get_anova()` | Exported: design-based ANOVA for `survey_glm_fit` objects |
| `anova.survey_glm_fit()` | S3 method; delegates to `get_anova()` |
| `survey_anova` S3 result class | Tibble with column-level labels and `.meta` |
| `print.survey_anova()` | Custom `cat()` header + `print(x, ...)` body dispatch (surveycore idiom; not `NextMethod()` — see §3.9) |
| `.reg_term_test()` | Internal: analog of `survey::regTermTest()` for one term |
| `.anova_sequential()` | Internal: loop over terms (right-to-left drop) |
| `.anova_compare()` | Internal: compare two fits (symbolically-nested path) |
| `.pchisqsum_sad()` / `.pFsum_sad()` | Saddlepoint CDFs for weighted χ² sums |
| `ANOVA_META_KEYS` | Meta-key constant for `.make_result_tibble()` |

### What This Does NOT Deliver

- **Non-symbolically-nested model comparison** — `survey::anova.svyglm()`
  supports this via an explicit QR projection + refit path (see `anova.svyglm.R`
  lines ~90–155). It is used when neither model's terms are a superset of the
  other but the model matrices are still nested in column space. v1 **defers**
  this path: when two models are supplied that are not symbolically nested,
  `get_anova()` errors with `surveycore_error_models_not_nested`. The `force =
  TRUE` argument from survey's API is not exposed in v1.
- **Type III / type I partial sums of squares** — sequential mode tests terms
  by right-to-left drop (equivalent to survey's `oneanova.svyglm`), which is
  the only mode `survey::anova.svyglm()` supports. No `type = "I" / "II" / "III"`
  argument in v1.
- **Multi-model sequential comparison** — `anova(fit1, fit2, fit3)` with more
  than two fits. survey does not support this for `svyglm` either.
- **ANOVA for non-`survey_glm_fit` models** — e.g., `svycoxph`, `svyolr`
  analogs. Out of scope; surveycore does not yet provide those model classes.
- **Contrast-level p-values for individual coefficients** — use
  `coef(summary(fit))` / `confint(fit)` for per-coefficient inference. ANOVA
  tests composite hypotheses on whole terms.

### Supported Design Classes

All design classes supported by `survey_glm()` are supported here:

| Class | Supported |
|---|---|
| `survey_taylor` | Yes |
| `survey_replicate` | Yes |
| `survey_twophase` | Yes |
| `survey_nonprob` | Yes |
| `survey_srs` | Yes |

The design class is encoded in `fit@design`; `get_anova()` does not re-dispatch
on design class — the design-based variance is already in `fit@vcov`.

### Relationship to Other Functions

| Function | When to use |
|---|---|
| `get_anova(fit)` | Sequential test — drop each term in the model |
| `get_anova(fit1, fit2)` | Compare two symbolically-nested models |
| `confint(fit)` / `coef(summary(fit))` | Per-coefficient Wald inference |
| `get_t_test()` / `get_pairwise()` | Two-group or all-pairs mean differences |
| `clean(fit)` | Tidy the whole model into a result tibble |

---

## II. File Organization

```
R/
├── glm-anova.R                     # get_anova(), anova.survey_glm_fit(),
│                                   #   .reg_term_test(), .anova_sequential(),
│                                   #   .anova_compare(), print.survey_anova()
├── variance-vendored-saddlepoint.R # .pchisqsum_sad(), .pFsum_sad() — vendored
│                                   #   from survey/R/pchisqsum.R (GPL-3)

tests/testthat/
├── test-glm-anova.R                # happy paths, error paths, edge cases, print
├── test-glm-anova-numerical.R      # oracle tests vs survey::anova.svyglm
└── test-variance-vendored-saddlepoint.R  # parity vs survey::pchisqsum / pFsum
```

`ANOVA_META_KEYS` is added to `R/analysis-helpers.R` alongside the other
meta-key constants.

`anova.survey_glm_fit` is **registered dynamically** in `R/zzz.R`'s `.onLoad()`
via `registerS3method("anova", "surveycore::survey_glm_fit",
anova.survey_glm_fit, envir = asNamespace("stats"))` — the same pattern used
for the other `*.survey_glm_fit()` methods. See `R/glm-methods.R` preamble.

---

## III. `get_anova()` Specification

### 3.1 Signature

```r
get_anova <- function(
  model,
  model2       = NULL,
  method       = c("LRT", "Wald"),
  test         = c("F", "Chisq"),
  null         = NULL,
  tolerance    = sqrt(.Machine$double.eps),
  decimals     = NULL,
  label_vars   = TRUE,
  name_style   = "surveycore"
)
```

### 3.2 Arguments

| Argument | Type | Description |
|---|---|---|
| `model` | `survey_glm_fit` | The (bigger) model. Required. Must be a `survey_glm_fit` S7 object. |
| `model2` | `survey_glm_fit` or `NULL` | Optional second model. If `NULL` (default), run in **sequential mode** (§3.4). If supplied, run in **nested comparison mode** (§3.5). |
| `method` | character(1) | Test statistic family. `"LRT"` (default) = Rao-Scott working LRT (eigenvalue-adjusted deviance difference). `"Wald"` = Rao-Scott Wald statistic (β' V⁻¹ β). See §3.3. |
| `test` | character(1) | Reference distribution. `"F"` (default) uses an F / weighted F-sum distribution with design-based `ddf = fit@degf`. `"Chisq"` uses the asymptotic χ² / weighted χ²-sum (`ddf = Inf`). For very large designs the two converge. |
| `null` | numeric or `NULL` | Hypothesized value for the tested coefficients (Wald only). `NULL` (default) tests against zero. Passed through to `.reg_term_test()`. Ignored in LRT mode (errors if non-`NULL`). |
| `tolerance` | numeric(1) | Reciprocal-condition-number threshold for the V₀ near-singular gate in the Rao-Scott LRT (§3.3.2). When `rcond(V₀) < tolerance`, the eigenvalue decomposition switches from `solve(V0) %*% V` to `MASS::ginv(V0) %*% V` and `surveycore_warning_singular_v0` fires. Default `sqrt(.Machine$double.eps)` (≈ `1.5e-8`) — chosen to match the common R numerical-stability idiom (the same threshold is used by `base::solve()` when deciding whether to warn on ill-conditioning) and to err on the side of emitting the warning rather than silently producing an eigenvalue vector from a poorly-conditioned inverse. Users who want a stricter (less-triggered) gate can pass a smaller value, e.g. `tolerance = 1e-10`. Ignored in Wald mode (no V₀ inversion). (Pass 2 Issue 38 — kept sqrt(eps) with rationale.) |
| `decimals` | integer(1) or `NULL` | Round double output columns to this many decimal places. `NULL` = no rounding. |
| `label_vars` | logical(1) | Whether to attach term-label column attributes from `design@metadata$variable_labels` to the `term` column. Default `TRUE`. Composition rules: (1) Plain terms (`"age"`) receive the variable's stored label (e.g., `"Age in years"`). (2) Interaction terms (`"age:sex"`) receive a composed label joining component labels with the Unicode multiplication sign — e.g., `"Age in years × Sex"`. Components are extracted via `strsplit(term, ":", fixed = TRUE)[[1]]` and looked up in that order; the resulting labels are joined with ` × ` (single spaces around the Unicode multiplication sign). This matches the order R's formula parser emits in `attr(terms(formula), "term.labels")`, so a user who writes `y ~ b:a` gets `"<label-of-b> × <label-of-a>"` — the formula parser's term label preserves operand order, and so does the composed label. Higher-order interactions (`"a:b:c"`) are composed by joining all three labels with the same separator (`"Age × Sex × Race"`); the rule is identical for any `k`-way interaction. (Pass 2 code-review Issue 20.) (3) If any component of a plain or interaction term has no entry in `design@metadata$variable_labels`, the whole term falls back to its raw string (`"age:sex"`) and no `attr(col, "label")` is set for that cell. Comparison-mode `term` strings (e.g., `"educ + race | age + sex"`) are never composed — the raw diff label is used unchanged. (Pass 3 Issue 6.) |
| `name_style` | character(1) | Output column naming style. `"surveycore"` (default) or `"broom"` (§3.7). |

**Argument order** follows `code-style.md §4`: object first (`model`), required
NSE (none), required scalar (none — `model2` is optional), optional scalars
(`method`, `test`, `null`, `tolerance`), format scalars (`decimals`,
`label_vars`, `name_style`).

### 3.3 Statistical Model

`get_anova()` implements the same four test × method combinations as
`survey::anova.svyglm()`. This is a deliberate methodological commitment to
the Rao-Scott framework (Rao & Scott 1984, 1987; Lumley & Scott 2014).
Alternative corrections (Fay 1985, Pfeffermann 1993) are not exposed in v1;
users needing those can call the `survey` package directly.

| `method` | `test` | Statistic | Reference distribution |
|---|---|---|---|
| `"Wald"` | `"F"` | F = β̂ᵀ V⁻¹ β̂ / q | F(q, ddf) |
| `"Wald"` | `"Chisq"` | χ² = β̂ᵀ V⁻¹ β̂ | χ²(q) |
| `"LRT"` | `"F"` | Working-LRT deviance difference | Weighted F-sum with ddf (saddlepoint) |
| `"LRT"` | `"Chisq"` | Working-LRT deviance difference | Weighted χ²-sum (saddlepoint) |

Notation: `q` = number of coefficients being tested. `β̂` = subvector of
`model@coefficients[idx]` for the tested terms. `V` = `model@vcov[idx, idx]`.
`ddf` = design residual df = `model@degf - (p - 1)` where `p` =
`length(model@coefficients)`. (If `ddf < 1`, `get_anova()` errors before
any computation — see §3.3.3 and §VI A-9. The computation never sees a
clamped value.) `V₀` = "naive" (model-based) covariance =
`summary(model@fit_)$cov.unscaled[idx, idx]` — the q×q block restricted to
the tested coefficients.

#### 3.3.1 Wald statistic

Wald uses only `@coefficients`, `@vcov`, and `@term_assign`; the
**sequential** (single-model) Wald path is **serialization-safe** —
`model@fit_` may be `NULL` (e.g. after `saveRDS()` stripped it) and the
computation still runs. The `@term_assign` property carries the
`"assign"` attribute from `model.matrix()` captured at fit time (see
§IX) so the term→column map survives serialization. (Pass 3 Issue 2.)

**Comparison-mode caveat.** Comparison Wald is *not* serialization-safe
in v1 because the row-identity invariance check (§3.5 step 5) reaches
into `rownames(model.frame(@fit_))` on both fits regardless of method.
A-11 (§VI) therefore also fires in comparison mode, any method, when
either `@fit_` is `NULL` — turning a cryptic `model.frame(NULL)` crash
into a typed error. Full comparison-mode serialization-safety is
restored once the deferred `@model_rows` property lands on
`survey_glm_fit` (§IX follow-up). (Pass 2 code-review Issue 16.)

**Reference distribution under non-Gaussian families.** `F(q, ddf)` is exact
under Gaussian + homoscedasticity. For binomial, Poisson, quasi, and other
GLM families it is an asymptotic small-sample adjustment of `χ²(q)/q` and
is the recommended reference under design-based inference (Lumley 2010,
*Complex Surveys*, §8). The `"Chisq"` variant is equivalent asymptotically
and is preferred for very large designs where the F and χ² references
converge.

```r
beta   <- model@coefficients[idx]
V      <- model@vcov[idx, idx]
if (!is.null(null)) beta <- beta - null
chisq  <- as.numeric(t(beta) %*% solve(V, beta))

if (test == "F") {
  Fstat <- chisq / q
  p_value <- stats::pf(Fstat, df1 = q, df2 = ddf, lower.tail = FALSE)
} else {
  p_value <- stats::pchisq(chisq, df = q, lower.tail = FALSE)
}
```

#### 3.3.2 Rao-Scott working LRT (saddlepoint)

Follows `survey::regTermTest()` lines 60–110 and
`survey::anova.svyglm()` lines 150–180. The "working LRT" terminology
and the eigenvalue-weighted reference distribution are described in
Lumley (2010) *Complex Surveys*, §6.3.

LRT requires `model@fit_` (for the naive `summary(fit_)$cov.unscaled`) and
is therefore **not serialization-safe**. If `method = "LRT"` and
`is.null(model@fit_)`, `get_anova()` errors with
`surveycore_error_lrt_requires_fit_object` (§VI row A-11) before any refit
is attempted. Users who need inference after serialization should pass
`method = "Wald"`.

**Null-hypothesis argument.** `null` is rejected when `method = "LRT"`
(see §3.6 step 4 and §VI row A-4); the guard fires before the LRT
pseudocode below executes.

**V₀ is restricted to the tested q×q block.** The "naive" covariance V₀
that enters the Rao-Scott eigenvalue decomposition is the model-based
covariance of the **tested coefficients only** — i.e.
`summary(model@fit_)$cov.unscaled[idx, idx]`, a q×q matrix, not the full
p×p information inverse. This matches `survey::regTermTest()` and the
Rao-Scott working-LRT theory: the misspecification eigenvalues
`eigen(solve(V0) %*% V)` describe the mismatch between design-based and
model-based variance **on the hypothesis subspace being tested**, not
across the whole coefficient vector. Implementers reading only the
pseudocode might be tempted to compute a p×p V₀ and then subset; doing
so would yield different (and incorrect) eigenvalues. The block-first,
invert-second order is load-bearing. (Pass 2 Issue 37.)

```r
# Fit the reduced model by dropping the tested terms.
# (Sequential mode: .anova_sequential() drops the right-most term at each
#  step; nested mode: the smaller of model / model2 is the reduced model.)
reduced <- .refit_reduced(model, tested_terms)

# Working LRT χ² = deviance(reduced) - deviance(model).
#
# Deviance-weighting convention: surveycore passes raw (un-normalized) survey
# weights directly to stats::glm() (R/glm.R:1034), so model@deviance is
# sum(w_i * dev_resids(y_i, mu_i)^2) using the raw survey weights — i.e. the
# survey-weighted deviance at the full-sample scale.
#
# The rescale factor (mean(model@weights) / mean(reduced@weights)) that
# appears in survey::regTermTest() is identically 1 in this codepath because
# .refit_drop_terms() reuses the same design@data and the n-invariance check
# (§3.4 step 3d / §3.5 step 5; A-12) errors out if the row vectors differ.
# The rescale term is therefore omitted for clarity. An additional defensive
# assertion in .reg_term_test() (§V.1 step 5) enforces the row-count
# invariant at runtime.
chisq <- reduced@deviance - model@deviance
# Roundoff tolerance (Pass 3 Issue 60). Two regimes of negative
# deviance-diff exist: (a) true negatives from reduced-fit
# non-convergence (magnitude ≳ 1e-4), and (b) floating-point roundoff
# when the reduced model is a genuine submodel with near-identical
# deviance (magnitude ~ 1e-12). Treating case (b) as "convergence
# failure" and warning is alarmist; treating case (a) silently is
# wrong. The guard is `chisq < -sqrt(.Machine$double.eps) *
# abs(model@deviance)` — negatives inside the roundoff band are
# clamped to 0 without warning; negatives outside fire
# surveycore_warning_negative_deviance_diff and still clamp. This
# matches survey::regTermTest()'s implicit handling (it passes raw
# chisq to pchisqsum(), which silently truncates at 0).
neg_tol <- sqrt(.Machine$double.eps) * abs(model@deviance)
if (chisq < -neg_tol) {
  cli::cli_warn(
    c("!" = "Deviance difference is negative for term {.field {term}} ({.val {signif(chisq, 3)}}); the reduced fit may not have converged.",
      "i" = "Treating as 0 to keep the LRT well-defined.",
      "v" = "Inspect reduced-model convergence via {.fn summary} on a manual refit."),
    class = "surveycore_warning_negative_deviance_diff"
  )
}
chisq <- max(chisq, 0)

# Misspecification eigenvalues: spectrum of V₀⁻¹ V on the tested q×q
# subspace. V₀ is restricted to the tested coefficients only — i.e. the
# q×q block of summary(fit_)$cov.unscaled, not the full p×p information
# inverse — consistent with survey::regTermTest() and the Rao-Scott
# working-LRT theory.
#
# Use a Moore-Penrose pseudoinverse so near-singular V₀ (common with
# many-level-factor interactions) degrades gracefully. rcond(V0) is
# checked against the user-tunable `tolerance` argument (default
# sqrt(.Machine$double.eps) ≈ 1.5e-8); if V0 is below that threshold,
# ginv() is used and `surveycore_warning_singular_v0` (§VI row A-13)
# fires. (rcond is the *reciprocal* condition number: small rcond means
# V0 is ill-conditioned, large rcond means well-conditioned. The guard
# triggers the ginv() branch when V0 is numerically singular — i.e.
# rcond is *below* the tolerance threshold. Readers coming from `qr()`
# or `chol()` may expect the opposite sign. Pass 3 Issue 66.) Both
# branches use the same operand order (`{solve|ginv}(V0) %*% V`) so the
# eigenvalue formula reads identically regardless of conditioning. If the pseudoinverse itself fails or
# eigen() errors, .pchisqsum_sad() / .pFsum_sad() fall back to the χ²(q)
# reference and emit `surveycore_warning_saddlepoint_fallback`.
V0 <- summary(model@fit_)$cov.unscaled[idx, idx]
V  <- model@vcov[idx, idx]
lambda <- tryCatch({
  if (rcond(V0) < tolerance) {
    cli::cli_warn(
      c("!" = "Naive covariance V₀ is near-singular for term {.field {term}}; using pseudoinverse.",
        "i" = "Reciprocal condition number: {.val {signif(rcond(V0), 3)}} (threshold: {.val {signif(tolerance, 3)}}).",
        "v" = "Inspect the model for collinearity in the tested coefficients."),
      class = "surveycore_warning_singular_v0"
    )
    eigen(MASS::ginv(V0) %*% V, only.values = TRUE)$values
  } else {
    eigen(solve(V0) %*% V, only.values = TRUE)$values
  }
}, error = function(e) {
  # Let caller catch and fall back to χ²(q) with saddlepoint_fallback warning
  stop(e)
})
mean_lambda <- mean(lambda)

# Both reference distributions use the same raw statistic `chisq`; only the
# CDF differs (Chisq → weighted-χ²-sum; F → weighted-F-sum on ddf). For the
# F variant the statistic is pre-divided by mean(lambda) and the same mean
# is passed as `mean.deff`, matching survey::pFsum()'s contract; see §V.5.
if (test == "Chisq") {
  p_value <- .pchisqsum_sad(chisq, rep(1, q), lambda,      # saddlepoint
                             lower.tail = FALSE)
} else {
  p_value <- .pFsum_sad(
    chisq / mean_lambda,
    rep(1, q),
    lambda,
    ddf       = ddf,
    mean.deff = mean_lambda,
    lower.tail = FALSE
  )
}
```

**Replicate-design note.** The Rao-Scott decomposition `lambda <- eigen(solve(V0)
%*% V)` was derived for Taylor-type score sandwiches. When `model@vcov` is the
replicate sandwich `Σ c_r (β̂_r - β̂)(β̂_r - β̂)ᵀ`, `lambda` is consistent under
standard regularity conditions (Binder 1983; Lumley 2010 §2.4.2) but numerically
distinct — the replicate vcov is not a smooth function of β, and for bootstrap
replicate designs the consistency result also requires the number of replicates
B → ∞. (Pass 3 Issue 74 — replaces earlier "asymptotically equivalent" phrasing,
which was over-broad for small-B bootstrap.) This spec commits to matching
`survey::anova.svyglm()` within `1e-6` on the p-value and `1e-8` on the statistic
for replicate designs; the BRR oracle test in §VII is the ratification of that
contract.

**Fay-BRR ρ handling.** For `survey_replicate` designs of type Fay (where a
fractional coefficient ρ scales the replicate deviations by `1 / (1 - ρ)²`),
the ρ adjustment is applied **upstream** when `model@vcov` is assembled by
`survey_glm()` / `.glm_replicate_vcov()` — consistent with `survey::svyglm()`'s
internal handling. `get_anova()` reads `V <- model@vcov[idx, idx]` directly
and therefore inherits the ρ scaling without re-computing it from raw
replicate deviations. The Rao-Scott eigenvalues `eigen(solve(V0) %*% V)` are
consequently correct for Fay-BRR. See §VII for the Fay oracle test. (Pass 3
Issue 64; Judkins 1990; Fay 1989; Lumley 2010 §2.5.1.)

Two-phase and nonprob designs inherit the same treatment via
`.glm_vcov_dispatch()`.

**Saddlepoint source (GAP M-1 closed — 2026-04-16, Stage 2 Resolve, Issue 15).**
`.pchisqsum_sad()` and `.pFsum_sad()` are **vendored** from `survey::pchisqsum.R`
and `survey::pFsum` (GPL-3, compatible with surveycore's GPL-3 license) into
`R/variance-vendored-saddlepoint.R`. This matches the precedent of the Taylor,
replicate, and two-phase variance code, and avoids a runtime dependency on the
package surveycore is built to replace.

**Reference-version audit (Pass 3 Issue 63, 2026-04-17).** Source verification
against `survey` 4.4-8 showed that the earlier-spec "`x ≤ 1.05 * sum(lambda)`
threshold for an auto-switch to Satterthwaite" does **not** exist in
`survey::pchisqsum()` or `survey::pFsum()`. Upstream both helpers take an
explicit `method = c(...)` argument with `"saddlepoint"` as the default for
`pFsum()` and fall back to Satterthwaite **only when the saddlepoint
root-finder returns `NA`** (`pchisqsum.R`: `if (!is.na(sad)) guess <- sad`
pattern). `get_anova()` matches upstream: always saddlepoint first,
Satterthwaite only on numerical failure. No `method="auto"` / `"integration"`
is exposed (the CompQuadForm dependency is not introduced), and no invented
threshold gates the branch. See §V.5.

#### 3.3.3 Degrees of freedom

`get_anova()` always uses **design-based residual df**, consistent with
`get_t_test()` and `svyglm()`'s own `df.residual = degf(design) + 1 - p`:

```r
p   <- length(model@coefficients)
ddf <- model@degf - (p - 1L)              # design df minus rank of full model
```

`model@degf` is numeric (replicate designs can have fractional df — e.g. a
BRR design may have `degf = 31.5`), so `ddf` is numeric as well. Do **not**
truncate or coerce to integer.

**Insufficient df.** If `ddf < 1` (i.e. `model@degf < p`), surveycore
errors with `surveycore_error_insufficient_df_for_anova` (§VI row A-9).
The error is reference-distribution-agnostic — both `test = "F"` and
`test = "Chisq"` raise it, because a degenerate residual-df budget signals
that the test is not well-supported by the data regardless of the
reference distribution. (`survey::regTermTest()` silently passes the raw
value through and yields `NaN`; surveycore errors instead.) The error
fires once at the top of `get_anova()` — before sequential refits begin —
so the user gets actionable feedback before any time is spent refitting.

Testing `q > model@degf` is permitted so long as `p ≤ model@degf` (so that
`ddf ≥ 1`). The test has low power and the F reference distribution has
heavy tails; inspect the resulting `ddf` column to calibrate expectations.

When `test = "Chisq"`, `ddf = NA_real_` is stored in the result (the χ² /
χ²-sum reference distribution ignores `ddf`). Column is always present —
see §3.7.

**Per-class @degf semantics and recommended reference distribution.**

| Design class | `model@degf` source | Recommended `test` |
|---|---|---|
| `survey_taylor` | `nPSU - nStrata` (via `survey::degf()`) | `"F"` (default) |
| `survey_replicate` | Replicate-method-specific (e.g., BRR `nrep`; can be fractional) | `"F"` (default) |
| `survey_twophase` | Phase-1 PSU/stratum count via `survey::degf()` semantics | `"F"` (default) |
| `survey_srs` | `n - 1` | `"F"` (default) |
| `survey_nonprob` | `n - 1` (model-based fallback) | `"F"` (default); see note below |

The default `test = "F"` is appropriate for all design classes above. Use
`test = "Chisq"` when the design is very large (so the F and χ² references
converge) or when a chi-square reference is needed for downstream
comparison with reference implementations.

For `survey_nonprob` the variance returned by `.glm_calibrated_vcov()` is a
model-based sandwich rather than a design-based estimator, so the ddf column
is more nominal than calibrated. The `surveycore_warning_nonprob_inference`
warning defined in §3.3.1 surfaces this whenever `get_anova()` is called on
a nonprob fit; the `n - 1` value is chosen to match `survey_srs` and keep
the ddf path unconditional.

### 3.4 Sequential Mode (single model)

Triggered when `model2 = NULL`. Mirrors `survey::oneanova.svyglm()`
(`anova.svyglm.R` lines 1–18).

1. Let `tt <- attr(terms(model@formula), "term.labels")` — names of the
   non-intercept terms in the order they appear in the formula.
2. Let `nt <- length(tt)`. If `nt < 1` — i.e., the model is
   intercept-only (`y ~ 1`) — error with
   `surveycore_error_no_terms_to_test` (§VI, A-17). Consistent with the
   explicit-error posture chosen for A-9 (insufficient df) and A-16
   (identical term sets). (Survey's `oneanova.svyglm()` returns `NULL`
   here; surveycore diverges by erroring so the typed-error contract is
   uniform across degenerate-input paths.) A single-term model
   (`y ~ x`, `nt = 1`) is a valid input and produces one result row —
   the term is tested by dropping it vs. the intercept-only reduced
   fit. (Pass 3 Issue 7.)
3. **Loop from `i = nt` down to `1`:**
   a. Let `this_term <- tt[i]`.
   b. Call `.reg_term_test(current_model, this_term, method, test, null, ddf)`
      to produce one result row.
   c. Refit `current_model` with `this_term` dropped — implementation detail:
      use `stats::update.formula(current_model@formula, . ~ . - <this_term>)`
      and call `survey_glm()` on the same design. (See §V.3 for the helper.)
   d. **n-invariance check.** The Rao-Scott LRT requires the reduced
      fit to cover exactly the same rows as the full fit. Compare
      **row identifiers**, not just row counts:
      `identical(rownames(stats::model.frame(reduced@fit_)), rownames(stats::model.frame(current_model@fit_)))`.
      Comparing on row names catches the subtle failure mode where a
      dropped covariate was the only source of NAs in some rows (so
      the reduced fit has more rows than the full fit, invalidating
      nesting) as well as the converse. `@fit_` is guaranteed to be
      present in LRT mode by A-11. Error with
      `surveycore_error_n_mismatch` (§VI row A-12). In Wald mode no
      refit occurs so no check is needed.
      (Pass 3 Issue 59 — on-demand row-name derivation from
      `model.frame(@fit_)`; `@model_rows` as a persistent property on
      `survey_glm_fit` is deferred to a follow-up PR — see §IX TODO.)
4. Stack rows in **original term order** (reverse the accumulation order so
   the output reads top-to-bottom as `tt[1], tt[2], ..., tt[nt]`, matching
   `survey::anova.svyglm()` output).

**Sequential semantics:** Each row tests "add `this_term` last, given all
prior terms." This is type-I-like testing; interaction terms are tested at
the point they appear in the formula. Users who need type-II or type-III can
refit with term ordering adjusted, or use two-model comparison mode.

**Domain / weights invariance:** Every refit inherits the same design
object, `na.action`, and domain filter as `model`. The refits happen on
`model@design`, not `model@fit_`'s restricted data — this is important
for variance estimation to stay design-based. Concretely, the
`..surveycore_domain..` indicator column attached by
`update_design()` / `filter()` (when present) travels with `model@design`
into the refit unchanged, so domain membership is identical between the
full and reduced fits. The n-invariance check (step 3d) catches any drift
that would invalidate this assumption.

**Contrasts.** Sequential ANOVA assumes treatment-style contrasts (R's default
`contr.treatment`). Non-default contrasts (`contr.sum`, `contr.helmert`,
custom matrices) preserve the column-subspace nesting for purely additive
terms but can produce unexpected term breakdowns for interactions. A
regression test with `contr.sum` pins the behavior; users who need a
different parameterization should re-fit with the adjusted formula and use
comparison mode.

**Replicate designs:** `.refit_drop_terms()` delegates to `survey_glm()`,
which internally handles per-replicate convergence failures by contributing
zero deviation to the replicate variance sum and emitting
`surveycore_warning_glm_convergence` (`R/glm.R:474–487`). `get_anova()`
inherits this behavior without additional code; users will see the
warning once per failing replicate.

**Two-phase designs:** `.refit_drop_terms()` calls `survey_glm()` on the
original `survey_twophase` design; `survey_glm()` re-applies the phase-2
subset automatically (`R/glm.R:904–910`), so both the phase-1 design and
the phase-2 mask are preserved in the refit.

### 3.5 Nested Comparison Mode (two models)

Triggered when `model2` is supplied. Mirrors `survey::anova.svyglm()` lines
30–60 (symbolically-nested branch).

1. Let `t1 <- attr(terms(model@formula), "term.labels")`,
   `t2 <- attr(terms(model2@formula), "term.labels")`.
2. **Symbolic nesting check:** First, if `setequal(t1, t2)` — i.e., the
   two models have identical term sets — error with
   `surveycore_error_identical_term_sets` (§VI, A-16). This catches the
   `get_anova(fit, fit)` misuse and prevents the downstream
   `reformulate(character(0))` error. Otherwise: if `all(t1 %in% t2)` →
   `model2` is the bigger model. If `all(t2 %in% t1)` → `model` is the
   bigger model. Else:

   ```r
   cli::cli_abort(
     c("x" = "Models are not symbolically nested.",
       "i" = paste0("Neither model's term set is a subset of the other. ",
                    "Non-symbolic nesting (same column space, different ",
                    "parameterization) is not supported in v1.")),
     class = "surveycore_error_models_not_nested"
   )
   ```

3. **Response invariance check:** `identical(model@formula[[2L]],
   model2@formula[[2L]])` — LHS must match. Error:
   `surveycore_error_response_mismatch`.
4. **Design invariance check (Pass 3 Issue 71 — softened from strict
   `identical()`):** compare on the semantically load-bearing slots
   only —
   `identical(model@design@data, model2@design@data) && identical(model@design@variables, model2@design@variables)`.
   `@metadata@transformations`, `@call`, and any other slot whose
   value can legitimately drift between two independent
   `as_survey()` calls on the same underlying table are **not**
   compared. Error: `surveycore_error_design_mismatch`. This accepts
   the common user workflow of building two designs via separate
   `as_survey()` pipelines (which produces different
   `@metadata@transformations` histories) while still rejecting
   comparisons across genuinely different data or design
   specifications. Because the `@data` slots are identical, the
   `..surveycore_domain..` indicator column (if present) is by
   construction the same across the two fits; no separate
   domain-propagation step is required. (Pass 1 Issue 26 B's strict
   `identical()` is replaced by this content-based comparison; see
   the 2026-04-17 decision-log entry for the rationale.)
5. **n invariance check (Pass 3 Issue 59).** The row-identifier
   comparison requires `@fit_` on **both** models. Before comparing,
   guard serialization: if either `is.null(model@fit_)` or
   `is.null(model2@fit_)`, error with
   `surveycore_error_lrt_requires_fit_object` (§VI, A-11). The guard
   fires in comparison mode **regardless of `method`** — comparison
   Wald also reaches into `@fit_` here, so the serialization
   invariant is the same as LRT. (Pass 2 code-review Issue 16:
   without this guard, Wald + one serialized fit crashes in
   `model.frame(NULL)` before surveycore can emit a typed error.)
   Then compare identifiers:
   `identical(rownames(stats::model.frame(model@fit_)), rownames(stats::model.frame(model2@fit_)))`.
   Error: `surveycore_error_n_mismatch` (§VI row A-12). Comparing on
   row names catches the case where the two fits cover the same row
   count but different row subsets (which length-only comparison
   would miss). (Follow-up: `@model_rows` as a persistent property on
   `survey_glm_fit` would eliminate this guard altogether and restore
   the Wald comparison-mode serialization-safety claim — deferred to
   a post-ANOVA PR, see §IX TODO.)
6. Identify `bigger` and `reduced`. Let `termdiff <- setdiff(bigger_terms,
   reduced_terms)`. Let `test.formula <- reformulate(termdiff)[[2L]]`.
7. **ddf source (design-equality corollary).** Because both fits
   reference the identical design object (step 4) and cover the
   identical row set (step 5), `bigger@degf` and `reduced@degf` must
   be equal — design df is a function of the design, not the model.
   The spec uses `bigger@degf` as the authoritative source and
   enforces the equality invariant at runtime with
   `stopifnot(isTRUE(all.equal(bigger@degf, reduced@degf)))` before
   computing `ddf <- bigger@degf - (length(bigger@coefficients) - 1L)`.
   A violation (i.e. the two fits report different design df despite
   sharing a design) indicates a surveycore bug, not a user error;
   the stopifnot() will fail loudly so Stage 3 / QA catches it.
   (Pass 2 Issue 40.)
8. Delegate to `.reg_term_test(bigger, test.formula, method, test,
   null, ddf = ddf, reduced = reduced, tolerance = tolerance)`.
   Returns one result row.

**v1 does NOT implement** the non-symbolic-nesting projection path from
`survey::anova.svyglm()` (lines 60–200) — see §I "What This Does NOT
Deliver." The error class `surveycore_error_models_not_nested` is the v1
escape hatch.

### 3.6 Execution Flow

1. Validate `model` is a `survey_glm_fit` via `S7::S7_inherits(model,
   survey_glm_fit)`. Error: `surveycore_error_not_glm_fit` (reused from
   `clean()`, row 75).
2. If `model2` is non-`NULL`, validate same class.
3. Validate `method %in% c("LRT", "Wald")`, `test %in% c("F", "Chisq")` via
   `match.arg()`.
4. Validate `null`: either `NULL` or a numeric vector. Error in LRT mode
   if `!is.null(null)`: `surveycore_error_null_with_lrt` (§VI, A-4).
   Length check against `q` happens inside `.reg_term_test()` once `q` is
   known — see §V.1 and §VI row A-10.
5. **LRT serialization guard.** If `method == "LRT"` and
   `is.null(model@fit_)`, error with
   `surveycore_error_lrt_requires_fit_object` (§VI, A-11). Wald is
   serialization-safe and skips this check.
6. **Insufficient-df guard.** Compute `p <- length(model@coefficients)` and
   `ddf_raw <- model@degf - (p - 1L)`; if `ddf_raw < 1`, error with
   `surveycore_error_insufficient_df_for_anova` (§VI, A-9). This fires
   before any refit, so the user sees the issue immediately.

   **No separate empty-domain guard (Pass 1 Issue 27, reaffirmed Pass
   3 Issue 69 — 2026-04-17).** `get_anova()` does **not** add a
   dedicated empty-domain check at entry. Rationale: (1) if
   `model@design` had an empty domain, `survey_glm()`'s own pre-fit
   guard would have errored before `model` was ever constructed, so
   the `survey_glm_fit` argument couldn't exist in that state; (2)
   sequential refits reuse the same `@design` without further
   domain narrowing (`.refit_drop_terms()` does not touch the
   `..surveycore_domain..` column — in fact A-20 / §V.3 defensively
   asserts the column is unchanged), so no downstream refit can
   shrink to empty; (3) the insufficient-df guard above handles the
   related "too few rows for the model's coefficient count" regime
   with a more informative error. A re-survey of the flow confirms
   Pass 1 Issue 27's reasoning is still valid; no A-21 is added.
6a. **Nonprob inference notice.** If `S7::S7_inherits(model@design,
    survey_nonprob)`, fire `surveycore_warning_nonprob_inference` (§VI,
    A-14) once per call. Warning-level so `suppressWarnings()` lets users
    who understand the caveat proceed silently.
6b. **Domain / na.action order (Pass 3 Issue 70).** When the refit
    builds its model frame, domain masking is applied **before**
    `na.omit` / `na.action`: rows with
    `..surveycore_domain.. == FALSE` are dropped from the model frame
    first, then NA handling is applied to the remaining in-domain
    rows. This matches `survey::svyglm()`'s handling of its `subset=`
    argument (subset filters the data before
    `na.action=na.omit` runs on the formula's variables). Specifying
    the order explicitly avoids ambiguity about which step "owned" a
    row that was both out-of-domain and had an NA covariate; the
    resulting row count is identical either way, but the order is
    stipulated for reproducibility and to guarantee the n-invariance
    assertion in step 3d / A-12 is evaluated on the same subset of
    rows on both fits.
7. Validate `decimals`, `label_vars`, `name_style` via
   `.validate_shared_args()` (reuse the existing helper signature; subset
   needed here is just `decimals`, `name_style`).
7a. **Validate `tolerance`.** Must satisfy
    `is.numeric(tolerance) && length(tolerance) == 1L && is.finite(tolerance) && tolerance >= 0`.
    Otherwise error with `surveycore_error_invalid_tolerance` (§VI, A-18).
    Done at the boundary rather than relying on R's `rcond() < tolerance`
    coercion, which silently accepts character input, silently disables
    the gate for negative input, and errors cryptically on `NA_real_`.
8. **Mode dispatch:**
   - `is.null(model2)` → `.anova_sequential(model, method, test, null)`.
   - else → `.anova_compare(model, model2, method, test, null, tolerance)`.
9. Apply `decimals` rounding via `.apply_decimals()`.
10. Apply `name_style` renaming via `.apply_name_style(result, name_style)`.
11. Attach column-level labels (§3.7).
12. Assemble `.meta`; construct `survey_anova` tibble via
    `.make_result_tibble()` with `ANOVA_META_KEYS`.

### 3.7 Output Contract

**S3 class:** `c("survey_anova", "survey_result", "tbl_df", "tbl",
"data.frame")`

**Column order (surveycore style):**

All columns are always present. Cells that don't apply to the selected
`method` / `test` combination are `NA_real_` (not missing from the table);
this mirrors the pattern used by `get_means()`, `get_t_test()`, etc. and
keeps downstream `map_dbl(results, "ddf")`-style code safe.

| Column | Type | Always present? | Notes |
|---|---|---|---|
| `term` | character | Yes | Term label (sequential) or diff label (comparison). See 3.7.1 |
| `statistic` | double | Yes | The test statistic value. §3.7.2 for semantics by mode. |
| `df` | double | Yes | Numerator df = number of coefficients tested (q) |
| `ddf` | double | Yes (`NA_real_` when `test = "Chisq"`) | Denominator df = design residual df |
| `deff` | double | Yes (`NA_real_` when `method = "Wald"`) | Mean misspecification eigenvalue `mean(lambda)` — design effect for this term. Matches survey's `DEff` column. |
| `p_value` | double | Yes | Two-sided p-value |
| `stars` | character | Yes | Significance stars via `.stars_pval()` |

#### 3.7.1 `term` column semantics

- **Sequential mode:** the bare term label from `terms()` (e.g., `"age"`,
  `"sex"`, `"age:sex"`).
- **Comparison mode:** `"<added_terms> | <base>"` where `<added_terms>` is
  `paste(setdiff(bigger_terms, reduced_terms), collapse = " + ")` —
  e.g., `"educ + race | age + sex"`. This is more informative than
  survey's `c("-", ...)` tuple. The `|` separator reads as "added to a
  model containing" — i.e., the LHS terms are tested after
  conditioning on the RHS. This is not strict conditional-probability
  notation; it's a compact label for "the terms being added, and the
  base they're added to."
- **Round-trip caveat (Pass 3 Issue 62):** when the added terms
  include interactions (e.g., `x3:x4`), the printed `" + "` separator
  collides with formula syntax and the string cannot be parsed back
  into the original term set unambiguously. Programmatic callers
  should use `meta(result)$terms[[i]]$added_terms` (a character
  vector carrying `setdiff(bigger_terms, reduced_terms)` verbatim)
  rather than splitting the printed `term` string. The printed form
  is for display; `.meta$added_terms` is for code.

#### 3.7.2 `statistic` column semantics

| `method` | `test` | `statistic` column holds |
|---|---|---|
| `"Wald"` | `"F"` | F value = β'V⁻¹β / q |
| `"Wald"` | `"Chisq"` | χ² value = β'V⁻¹β |
| `"LRT"` | either | Raw deviance difference `reduced@deviance - model@deviance` (numerical agreement with `survey::regTermTest()$chisq` within the oracle-test tolerances in §VII — survey stores and prints the un-rescaled value; the Rao-Scott eigenvalue correction is absorbed into the reference distribution via `mean.deff` inside `.pFsum_sad()`; Pass 3 Issue 75) |

For Wald+F the pre-division χ² (β'V⁻¹β) is stored in `.meta$terms[[i]]$raw_chisq`
so users can still access it. For LRT rows `statistic` *is* the raw chisq, so
`raw_chisq` in `.meta` carries the same value for symmetry. The eigenvalues
`lambda` and their mean are also in `.meta$terms[[i]]` — see §3.8.

#### 3.7.3 Column-level labels

| Column | Label |
|---|---|
| `term` | `"Term"` |
| `statistic` | One of `"Wald-F"`, `"Wald-χ²"`, `"LRT-F"`, `"LRT-χ²"`, picked from `(method, test)`. Disambiguates between the Wald χ² statistic (β'V⁻¹β) and the LRT working chi-square (raw deviance difference), which would otherwise both render as "Chi²". For LRT rows the printed value is the raw deviance difference, matching survey's output. |
| `df` | `"df"` |
| `ddf` | `"Denom df"` |
| `deff` | `"DEff"` |
| `p_value` | `"P-Value"` |
| `stars` | `""` |

Labels are set via `attr(col, "label") <- ...` for `gt::gt()` auto-detection,
same pattern as the rest of the `get_*()` family.

#### 3.7.4 `name_style = "broom"` renames

| surveycore | broom |
|---|---|
| `statistic` | `statistic` (unchanged) |
| `df` | `df` (unchanged — already broom-conventional) |
| `ddf` | `df_residual` |
| `deff` | `deff` (unchanged; no broom convention) |
| `p_value` | `p.value` |

### 3.8 `.meta` Contract

`ANOVA_META_KEYS <- c("model", "method", "test", "terms")`

| Key | Type | Value |
|---|---|---|
| `design_type` | char(1) | `.glm_design_type_string(model@design)` |
| `replicate_type` | char(1) | `model@design@variables$type %||% NA_character_` when `design_type == "replicate"`; `NA_character_` otherwise. Populated at `.meta` build time so the print method can render `Replicate weights (<type>)` without reaching back into the design object. |
| `n_respondents` | integer(1) | `nrow(model@design@data)` |
| `call` | language | `match.call()` |
| `model` | named list | `list(formula = model@formula, family = model@family$family, link = model@family$link, n_obs = length(model@fitted_values), coefficients = names(model@coefficients))` |
| `model2` | named list or `NULL` | Same shape as `model`, only when `model2` is supplied |
| `method` | char(1) | As supplied |
| `test` | char(1) | As supplied |
| `terms` | list | One sub-list per result row. Keys: `raw_chisq`, `lambda`, `ddf_used`, `test_terms` (character vector of the terms tested in this row). In comparison mode the single row also carries `added_terms` (character vector = `setdiff(bigger_terms, reduced_terms)`, verbatim — for round-trippable programmatic access, Pass 3 Issue 62). `mean(lambda)` is the LRT design effect and is available both on the result tibble (`deff` column) and by computing `mean(lambda)` from `.meta` — not stored redundantly. |

### 3.9 Print Method

`print.survey_anova()` follows the standard surveycore analysis idiom: a
three-line `cat()` header followed by explicit dispatch to tibble's
`print()` method (via class stripping + `print(x, ...)` — not
`NextMethod()`; see the Wald-branch comment in the pseudocode below for
why) to render the tabular body. No `printCoefmat()` — the
tibble's `stars` column (populated at build time via `.stars_pval()`, the
same helper used by `get_diffs()` / `get_t_test()` / `get_pairwise()`)
provides the significance annotation, and raw p-values render as
tibble-default `<dbl>` columns. `decimals` is applied at build time via
`.apply_decimals()`, matching every other `get_*()` function.

Example (Taylor, LRT/F, `decimals = 3`):

```
# A survey_anova result (Rao-Scott LRT, F reference)
# Model: y ~ age + sex + age:sex
# Design: Taylor series | N: 5,000 | Design df: 31

# A tibble: 3 × 7
  term    statistic    df   ddf  deff p_value stars
  <chr>       <dbl> <dbl> <dbl> <dbl>   <dbl> <chr>
1 age        12.340     1    30  1.08   0.001 "***"
2 sex         4.210     1    30  1.02   0.048 "*"
3 age:sex     0.880     1    30  1.15   0.353 ""
```

Pseudocode:

```r
print.survey_anova <- function(x, ...) {
  m <- attr(x, ".meta")

  method_label <- switch(m$method,
    LRT  = "Rao-Scott LRT",
    Wald = "Design-based Wald"
  )
  test_label <- switch(m$test,
    F     = "F reference",
    Chisq = "Chi-sq reference"
  )
  cat(sprintf("# A survey_anova result (%s, %s)\n",
              method_label, test_label))
  cat(sprintf("# Model: %s\n", deparse1(m$model$formula)))

  design_label <- .anova_design_label(m$design_type, m$replicate_type)
  n_fmt <- format(m$n_respondents, big.mark = ",")
  ddf_str <- .anova_design_df_string(x)
  cat(sprintf("# Design: %s | N: %s | Design df: %s\n",
              design_label, n_fmt, ddf_str))

  # Suppress deff in the printed body when all NA (Wald mode);
  # data column is retained in the returned tibble for programmatic access.
  if (identical(m$method, "Wald")) {
    keep <- setdiff(names(x), "deff")
    x_print <- x[, keep, drop = FALSE]
    attr(x_print, ".meta") <- attr(x, ".meta")
    class(x_print) <- class(x)
    x <- x_print
  }

  # Explicit dispatch — NOT NextMethod(). NextMethod() ignores local
  # rebinding of `x` and would print the original (unmodified) tibble,
  # silently defeating the Wald deff suppression above. Stripping the
  # surveycore classes and calling print() routes to the tbl_df method
  # with the rebound local `x`. (Pass 2 code-review Issue 18.)
  class(x) <- setdiff(class(x), c("survey_anova", "survey_result"))
  print(x, ...)
  invisible(x)
}
```

#### 3.9.1 Design-label rendering

Internal helper `.anova_design_label(design_type, replicate_type)` returns
the header string shown after `# Design:`. All five surveycore design
classes are supported. Both arguments are drawn from `.meta` — the helper
does not reach into the `survey_glm_fit` or `survey_*` design object,
preserving serialization safety for the print path.

| `design_type` | Header rendering | Source |
|---|---|---|
| `taylor` | `Taylor series` | literal |
| `replicate` | `Replicate weights (<type>)` when `replicate_type` is non-NA; `Replicate weights` otherwise | `<type>` from `.meta$replicate_type` (e.g. `BRR`, `JK1`, `bootstrap`) |
| `twophase` | `Two-phase` | literal |
| `nonprob` | `Non-probability` | literal |
| `srs` | `Simple random sample` | literal |

For `twophase`, the `N` shown in the header is the phase-2 sample size
(`nrow(model@design@data)`), which is what `n_respondents` in `.meta`
already records. Phase-1 N is not repeated in the ANOVA header — it is
available from `print(design)` if needed.

#### 3.9.2 Design-df rendering

Internal helper `.anova_design_df_string(x)` returns the string shown
after `# Design df:`. Always the scalar degrees of freedom used by the
F-reference (or `NA` for `test = "Chisq"`). Formatted via
`format(x, big.mark = ",")` for readability at large N.

#### 3.9.3 `deff` column suppression

When `method = "Wald"`, every `deff` cell is `NA_real_` by the §3.7.1
contract. The print method drops the column from the rendered body only;
the underlying tibble still carries `deff` for programmatic access
(`result$deff`, `meta()`-based pipelines). LRT prints keep `deff`
regardless of whether all cells happen to be `NA`.

#### 3.9.4 Snapshot tests

Snapshot coverage:

- Taylor + LRT/F + `decimals = 3` with two predictors and their interaction
  (NHANES-based fit) — the canonical example above.
- BRR replicate + LRT/F — exercises the `Replicate weights (<type>)`
  rendering.
- Taylor + Wald — exercises the `deff` suppression branch.

---

## IV. `anova.survey_glm_fit()` S3 Method

### 4.1 Signature

```r
anova.survey_glm_fit <- function(object, ..., method = "LRT",
                                  test = "F", null = NULL) {
  others <- list(...)
  if (length(others) == 0L) {
    get_anova(object, model2 = NULL,
              method = method, test = test, null = null)
  } else if (length(others) == 1L &&
             S7::S7_inherits(others[[1L]], survey_glm_fit)) {
    get_anova(object, model2 = others[[1L]],
              method = method, test = test, null = null)
  } else {
    cli::cli_abort(
      c("x" = paste0("anova() on survey_glm_fit accepts at most one ",
                     "additional survey_glm_fit model."),
        "i" = "Got {length(others)} extra argument(s)."),
      class = "surveycore_error_anova_bad_dots"
    )
  }
}
```

### 4.2 Behavior notes

- `anova(fit)` → sequential mode. Identical output to `get_anova(fit)`.
- `anova(fit1, fit2)` → comparison mode. Identical output to
  `get_anova(fit1, fit2)`.
- `decimals`, `label_vars`, `name_style`, and `tolerance` default to
  `NULL`/`TRUE`/`"surveycore"`/`sqrt(.Machine$double.eps)` respectively
  and are not exposed on the `anova()` method for minimal base-R
  compatibility. Users who want formatted output or a non-default V₀
  singularity gate call `get_anova()` directly. (Pass 3 Issue 4.)
- Registration: dynamic via `registerS3method("anova", "surveycore::survey_glm_fit",
  anova.survey_glm_fit, envir = asNamespace("stats"))` in `R/zzz.R::.onLoad()`.

---

## V. Internal Helpers

### V.1 `.reg_term_test()`

Corresponds to `survey::regTermTest()` (`regtest.R` lines 21–130). Takes a
single `survey_glm_fit` and a specification of the terms being tested; returns
a one-row data.frame of the test result + raw pieces for `.meta$terms`.

```r
.reg_term_test <- function(model, test.terms, method, test, null = NULL,
                            ddf = NULL, reduced = NULL,
                            tolerance = sqrt(.Machine$double.eps)) {
  # 1. Resolve `test.terms` to a column index vector `idx` in coef(model).
  #    The term-to-column map is read from `model@term_assign` — the
  #    `"assign"` attribute captured from `model.matrix()` at fit time
  #    and persisted on the `survey_glm_fit` object (see §IX). Using
  #    the stored property instead of `attr(model.matrix(model@fit_),
  #    "assign")` keeps this path serialization-safe: when a user
  #    strips `@fit_` via `saveRDS()` and re-loads, `@term_assign`
  #    survives and both Wald and LRT can still resolve `idx`.
  #    (LRT still errors via A-11 when `@fit_` is NULL because V₀
  #    requires `summary(fit_)$cov.unscaled`; Wald proceeds.)
  #    Two input forms are accepted:
  #      - Scalar character (sequential mode, .anova_sequential): treated
  #        as a single term label; find the matching columns by
  #        looking up `attr(terms(model@formula), "term.labels")` and
  #        selecting columns whose `@term_assign` entry points at that
  #        label's position.
  #      - Formula RHS (comparison mode, .anova_compare): extract term
  #        labels via attr(terms(test.terms), "term.labels"), resolve
  #        each per the scalar path, and take the union of the resulting
  #        column indices.
  #    Both paths apply the same canonicalOrder() logic as
  #    survey::regTermTest() (strip whitespace, sort interaction
  #    operands) so `a:b` and `b:a` match. Let q <- length(idx).
  #
  #    canonicalOrder() definition (Pass 3 Issue 58). The authoritative
  #    term ordering is `attr(terms(model@formula), "term.labels")` — the
  #    order the formula parser canonicalizes terms into, which is also
  #    what `attr(model.matrix(fit), "assign")` indexes. Sequential mode
  #    iterates this vector from right to left; comparison mode uses it
  #    to resolve setdiff(bigger, reduced). Three orderings were
  #    considered — (a) formula RHS appearance order, (b)
  #    terms()$term.labels order, (c) user-supplied `...` order — and
  #    (b) is the one that round-trips through model.matrix() / refit.
  #    For scalar (single-label) inputs in sequential mode, `idx`
  #    resolves to every column j such that
  #    `@term_assign[j] == match(label, attr(terms(f), "term.labels"))`;
  #    scalar inputs are never reinterpreted as a set of
  #    sequential-complement tests. (Pass 3 Issue 58 / Pass 2 Issue 46.)
  #
  #    @term_assign encoding (Pass 3 Issue 61). The property stores the
  #    integer vector `attr(model.matrix(fit), "assign")` verbatim —
  #    one entry per model-matrix column, with 0 for the intercept and
  #    k for the k-th non-intercept term in `attr(terms(f),
  #    "term.labels")`. Term labels themselves come from
  #    `attr(terms(model@formula), "term.labels")[unique(assign)[-1]]`
  #    (dropping 0). Non-default contrast codings (contr.sum,
  #    contr.helmert, custom matrices) shift coefficient *labels* but
  #    leave the column-to-term map identical to contr.treatment — so
  #    get_anova() reports formula-level term labels and deliberately
  #    ignores contrast-level labels. The contr.sum regression test in
  #    §VII ratifies this behavior.
  # 2. ddf handling: if `ddf` supplied use it; else
  #    ddf <- model@degf - (p - 1L). (The `ddf < 1` error is raised at the
  #    top of get_anova() — §3.3.3 / §VI A-9 — so this helper may assume
  #    ddf >= 1.) When test == "Chisq", return ddf as NA_real_ in the
  #    result row (the χ²/χ²-sum CDFs don't use it).
  # 3. Pre-check `null`:
  #      if (!is.null(null) && length(null) != q) {
  #        cli::cli_abort(
  #          c("x" = "{.arg null} has length {length(null)} but {q}
  #                   coefficient(s) are tested for term {.field {term}}.",
  #            "v" = "Supply one value per tested coefficient, or
  #                   {.code null = NULL}."),
  #          class = "surveycore_error_null_length_mismatch"
  #        )
  #      }
  #    (§VI row A-10.)
  # 4. Extract beta = coef(model)[idx], V = model@vcov[idx, idx].
  #    Subtract null if supplied.
  # 5. Defensive: the Rao-Scott working LRT assumes the reduced refit
  #    spans the same rows as the full fit — this is what makes the
  #    rescale factor `mean(model@weights) / mean(reduced@weights)` in
  #    §3.3.2 identically 1. The n-invariance check (§3.4 step 3d /
  #    §3.5 step 5, error A-12) compares
  #    `rownames(model.frame(model@fit_))` against the reduced fit's
  #    model-frame row names — identifier-level, not just count (Pass
  #    3 Issue 59). If the rownames are identical a belt-and-suspenders
  #    `stopifnot(length(model@weights) == length(reduced@weights))`
  #    runs here before `chisq` is computed.
  # 6. Branch on method:
  #      - "Wald": compute χ² / F per §3.3.1. The `reduced` and
  #               `tolerance` arguments are ignored — Wald uses neither
  #               a reduced fit nor V₀.
  #      - "LRT": resolve the reduced model. If `reduced` is supplied
  #               (comparison mode — §V.4), use it directly; else
  #               (sequential mode) call
  #               .refit_drop_terms(model, test.terms) to fit it.
  #               Compute chisq = reduced@deviance - model@deviance per
  #               §3.3.2; if chisq < -sqrt(.Machine$double.eps) *
  #               abs(model@deviance) fire
  #               surveycore_warning_negative_deviance_diff (§VI A-15);
  #               in every case clamp to max(chisq, 0) before proceeding
  #               (Pass 3 Issue 60 — negatives inside the roundoff band
  #               are silent). Compute lambda —
  #               if rcond(V0) < tolerance use MASS::ginv(V0) %*% V and
  #               fire surveycore_warning_singular_v0 (§VI A-13); else
  #               use solve(V0) %*% V. Both branches use the same
  #               operand order so the eigenvalue formula is identical
  #               regardless of conditioning. Then pre-divide chisq by
  #               mean(lambda) when test == "F" and pass
  #               `mean.deff = mean(lambda)` to .pFsum_sad() per §3.3.2 /
  #               §V.5. Saddlepoint failures fall back to χ²(q) with
  #               surveycore_warning_saddlepoint_fallback (§VI A-8).
  # 7. Return list(
  #      term         = <label>,
  #      statistic    = switch on (method, test):
  #                       Wald + F     -> chisq / q          # F = beta'V^-1 beta / q
  #                       Wald + Chisq -> chisq              # raw beta'V^-1 beta
  #                       LRT  + F     -> chisq              # raw deviance diff; pFsum_sad
  #                                                          #   handles Rao-Scott rescaling
  #                                                          #   via `mean.deff = mean(lambda)`
  #                       LRT  + Chisq -> chisq              # raw deviance diff; weighted-chisq-
  #                                                          #   sum CDF reference via pchisqsum_sad
  #      df           = q,
  #      ddf          = if (test == "Chisq") NA_real_ else ddf,
  #      deff         = if (method == "LRT") mean(lambda) else NA_real_,
  #      p_value      = ...,
  #      raw_chisq    = chisq,        # always the pre-F-division chi-square
  #      lambda       = lambda,       # NULL in Wald mode
  #      ddf_used     = ddf,
  #      test_terms   = <char vec of the terms tested in this row>
  #    )
}
```

### V.2 `.anova_sequential()`

Loops over `terms.labels(model@formula)`, refitting with one term dropped at
each step and calling `.reg_term_test()`.

### V.3 `.refit_drop_terms(model, drop_terms)`

Drops `drop_terms` from `model@formula` and calls `survey_glm()` on the
original design.

**Arguments**

- `model` — a `survey_glm_fit`. Must have a non-`NULL` `@fit_` only when
  the caller subsequently needs `rownames(model.frame(@fit_))` for the
  n-invariance check (§3.4 step 3d); `.refit_drop_terms()` itself does
  not touch `@fit_` on the input.
- `drop_terms` — a character vector, length ≥ 1. Each entry must be a
  term label present in `attr(terms(model@formula), "term.labels")`.
  The caller (sequential mode: `.anova_sequential()` step 3c;
  comparison mode: not called — `.anova_compare()` uses the supplied
  reduced fit directly) is responsible for ensuring this invariant;
  `.refit_drop_terms()` does not re-validate.

**Return**

A `survey_glm_fit` satisfying:

- `reduced@formula` is `update.formula(model@formula, . ~ . - <drop_terms>)`.
- `reduced@design` is `identical()` to `model@design` (the refit reuses
  the same design object verbatim; no re-narrowing, no new domain
  indicator, no change to `@variables`).
- `reduced@fit_` is **non-`NULL`** — downstream LRT code reads
  `reduced@deviance` (which depends on the fitted model object) and
  `rownames(model.frame(reduced@fit_))` (n-invariance check). Callers
  may rely on `@fit_` being present; `survey_glm()` never returns a
  fit with `@fit_ == NULL`.

**Invariants**

- The `..surveycore_domain..` indicator column (when present on
  `model@design@data`) is identical between the full fit's design and
  `reduced@design@data`. Enforced defensively by the A-20 guard at the
  tail of the function body (Pass 3 Issue 68).
- Factor parameterizations are inherited via `model@design@data` and
  `options("contrasts")`; `.refit_drop_terms()` does not forward a
  `contrasts` argument (Pass 1 Issue 4 / Pass 3 Issue 1).
- `na.action` is threaded from `model@call$na.action` so the reduced
  refit resolves NAs identically to the full fit (Issue 46).

**Failure modes**

- `surveycore_error_domain_mismatch` (§VI A-20) — raised by the
  defensive domain-propagation check. Should be unreachable under
  specified control flow; indicates external mutation of
  `model@design@data` between the full fit and the ANOVA call.
- Convergence warnings from `survey_glm()` propagate unchanged
  (`surveycore_warning_glm_convergence`; also `surveycore_warning_replicate_nonconvergence`
  §VI A-19 for replicate designs). Errors raised by `survey_glm()`
  (e.g. singular design matrix on the reduced formula) propagate
  unchanged; `.refit_drop_terms()` adds no typed errors of its own
  beyond A-20.
- `quiet = TRUE` scope: see inline comment in the pseudocode. Suppresses
  per-refit chatter only; typed warnings/errors remain visible.

Pseudocode:

```r
.refit_drop_terms <- function(model, drop_terms) {
  # Standard base-R idiom for term dropping: update.formula() with a
  # right-hand-side-only update formula built from a "- term" string.
  # Prefer this over reformulate(c(".", paste0("- ", drop_terms))), which
  # relies on the formula parser's leniency toward negation-prefixed
  # term labels.
  drop_rhs <- paste(drop_terms, collapse = " - ")
  new_formula <- stats::update.formula(
    model@formula,
    stats::as.formula(paste(". ~ . -", drop_rhs))
  )
  # @family is stored as as.list(fam) at fit time (R/glm.R:1147), not a
  # family object. Reconstruct before passing to survey_glm(). (See helper
  # .reconstruct_family() — either inlined here or promoted to
  # R/analysis-helpers.R if a second call site appears.)
  family_obj <- if (inherits(model@family, "family")) {
    model@family
  } else {
    do.call(
      stats::family,
      list(model@family$family, link = model@family$link)
    )
  }
  # na.action inheritance (Issue 46). Thread the original fit's
  # `na.action` so the reduced refit resolves NAs identically to the
  # full fit — otherwise a dropped term that was the sole source of
  # NAs in some rows would cause the refit to span more rows,
  # spuriously tripping the n-invariance check (§3.4 step 3d / A-12).
  na_action <- model@call$na.action %||% getOption("na.action")
  # Contrasts inheritance (Pass 1 Issue 4, re-affirmed in Pass 3 Issue 1).
  # `survey_glm()` does not expose a `contrasts` argument; factor
  # parameterizations (contr.treatment, contr.sum, contr.helmert, custom
  # matrices) are inherited via the design's `@data` frame and R's
  # global `options("contrasts")` — the same mechanism `survey_glm()`
  # uses for the original fit. The `contr.sum` regression test in §VII
  # is the ratification of this contract.
  # Replicate designs: survey_glm() internally handles per-replicate
  # convergence failures by contributing zero deviation and emitting
  # `surveycore_warning_glm_convergence` (R/glm.R:474-487). get_anova()
  # inherits that behavior without additional code.
  #
  # `quiet = TRUE` is scoped to this refit call only — it suppresses
  # the per-refit convergence chatter from survey_glm(). It does NOT
  # (and MUST NOT) wrap `.reg_term_test()`, the n-invariance check
  # (§3.4 step 3d), or any other call site in a
  # `suppressWarnings()` / `suppressMessages()` block. Typed errors
  # like `surveycore_error_n_mismatch` (§VI A-12) and typed warnings
  # like `surveycore_warning_singular_v0` (§VI A-13) must remain
  # visible to callers. Silencing them at the iteration level is a
  # correctness bug (Issue 45, BLOCKING).
  reduced <- survey_glm(
    design    = model@design,
    formula   = new_formula,
    family    = family_obj,
    na.action = na_action,
    quiet     = TRUE
  )
  # Domain-propagation defensive check (Pass 3 Issue 68 / A-20). The
  # reduced refit reuses `model@design` verbatim, so the
  # `..surveycore_domain..` indicator column (if present) is by
  # construction identical. If the user mutated `@design@data` between
  # fitting the full model and calling get_anova() (e.g., re-assigning
  # a filtered design back into the original variable), this check
  # catches it.
  dom_col <- "..surveycore_domain.."
  if (dom_col %in% names(model@design@data)) {
    if (!identical(model@design@data[[dom_col]],
                   reduced@design@data[[dom_col]])) {
      cli::cli_abort(
        c("x" = "Domain indicator differs between full and reduced fits for term {.field {drop_terms}}.",
          "i" = "This usually means {.code model@design@data} was mutated between the two fits.",
          "v" = "Do not modify the design between fits."),
        class = "surveycore_error_domain_mismatch"
      )
    }
  }
  reduced
}
```

GAP M-2 is closed: family reconstruction is now specified above.

### V.4 `.anova_compare()`

Runs the nested-comparison path described in §3.5. Inputs: `model`,
`model2`, `method`, `test`, `null`, `tolerance`. Output: a one-row
data.frame in the same shape returned by `.reg_term_test()`, so
`.anova_sequential()` and `.anova_compare()` stack identically
downstream.

```r
.anova_compare <- function(model, model2, method, test, null, tolerance) {
  # 1. Symbolic nesting: identify `bigger` / `reduced` via term-label
  #    set inclusion (§3.5 step 2). Error with
  #    surveycore_error_models_not_nested (§VI A-2) if neither
  #    direction holds.
  # 2. Response invariance: identical(model@formula[[2L]],
  #    model2@formula[[2L]]). Error: A-3.
  # 3. Design invariance (Pass 3 Issue 71): compare only on
  #    @design@data and @design@variables (content-based) rather
  #    than full-object identical(). Permits users to have built
  #    the two designs via independent as_survey() pipelines.
  #    Error: A-5. Because the @data slots are identical, the
  #    `..surveycore_domain..` indicator column (if present) is
  #    by construction identical across the two fits; no separate
  #    propagation step is needed.
  # 4. n-invariance: length(model@fitted_values) ==
  #    length(model2@fitted_values). Error: A-12.
  # 5. ddf for the comparison: use `bigger@degf - (p_bigger - 1L)`.
  #    `bigger@degf` equals `reduced@degf` by step 3; the spec
  #    enforces this equality at runtime with
  #    `stopifnot(isTRUE(all.equal(bigger@degf, reduced@degf)))`
  #    before computing ddf, so ddf is unambiguous (Issue 40).
  # 6. Build `test.formula <- reformulate(setdiff(bigger_terms,
  #    reduced_terms))[[2L]]` — the formula RHS representing the
  #    terms added by `bigger` on top of `reduced`.
  # 7. Delegate to .reg_term_test(bigger, test.formula, method,
  #    test, null, ddf = ddf, reduced = reduced, tolerance =
  #    tolerance). The optional `reduced` argument is the
  #    already-fit smaller model; in comparison mode no refit is
  #    needed (the user supplied both fits), so `.reg_term_test()`
  #    uses `reduced` directly for its `reduced@deviance` term and
  #    skips `.refit_drop_terms()`. The Wald branch ignores
  #    `reduced`.
}
```

### V.5 `.pchisqsum_sad()` / `.pFsum_sad()`

Both vendored into `R/variance-vendored-saddlepoint.R` from
`survey/R/pchisqsum.R` (GPL-3; precedent matches `R/variance-taylor.R`,
`R/variance-replicate.R`, `R/variance-twophase.R`). `.pchisqsum_sad()` is
a direct port of `survey::pchisqsum()`'s saddlepoint branch.
`.pFsum_sad()` is **derived from — not a byte-for-byte port of —**
`survey::pFsum()`: it adds a `mean.deff` scalar argument that is
pre-applied to `x` at the call site (matching `survey::pFsum()`'s
internal contract), rather than being computed inside the helper from
`mean(a)`. Callers in §3.3.2 pass `chisq / mean(lambda)` as `x` and
`mean(lambda)` as `mean.deff`, which is equivalent to `survey::pFsum()`
under its default but makes the Rao-Scott rescaling step visible at
the call site. (Pass 3 Issue 65.) Both are internal (no `@export`).

**`.pchisqsum_sad(x, df, a, lower.tail = FALSE)`** — approximates
`Pr(Σ a_i · χ²(df_i) > x)` via the Barndorff-Nielsen / Kuonen (1999)
saddlepoint approximation. Primary reference: Kuonen, D. (1999).
"Saddlepoint approximations for distributions of quadratic forms in
normal variables." *Biometrika* 86:929–935.
Arguments:
- `x` numeric scalar — the observed test statistic
- `df` integer vector — degrees of freedom for each chi-sq component
- `a` numeric vector — coefficients (eigenvalues `lambda`); same length as `df`
- `lower.tail` logical — `FALSE` returns the upper tail (standard for p-values)

**`.pFsum_sad(x, df, a, ddf, mean.deff = mean(a), lower.tail = FALSE)`** —
approximates the design-adjusted F reference. Expects `x` to be pre-divided by
`mean.deff` (matching `survey::pFsum()`'s contract; see §3.3.2 pseudocode).
Arguments:
- `x` numeric scalar — the observed statistic, **already divided by `mean.deff`**
- `df` integer vector — per-component df (`rep(1, q)` in our calls)
- `a` numeric vector — eigenvalues `lambda`
- `ddf` numeric scalar — denominator (design residual) df
- `mean.deff` numeric scalar — `mean(lambda)`; defaults to `mean(a)`
- `lower.tail` as above

**Hybrid behavior (verified against `survey` 4.4-8; Pass 3 Issue 63).**
Both functions compute the saddlepoint value via the vendored `saddle()`
helper; if `saddle()` returns `NA` (root-finder failure in the underlying
`uniroot` call), the Satterthwaite approximation (moment-matched
`pf()` / `pchisq()` on a scaled reference distribution) is used instead.
This `if (!is.na(sad)) use_sad else use_satt` pattern is exactly the
upstream behavior (`survey/R/pchisqsum.R` lines ~54–60 in 4.4-8) and is
preserved byte-for-byte. Earlier versions of this spec described a
"threshold-based `x ≤ 1.05 * sum(a)` auto-switch" — that was
inventing a threshold not present in `survey`; the v0.5 spec drops it.
The Satterthwaite branch is the fallback path, not a designed hybrid —
callers can inspect whether it fired via
`surveycore_warning_saddlepoint_fallback` (§VI A-8).

**Failure mode (Pass 3 Issue 63).** Two tiers of fallback:

1. *Saddlepoint returns `NA`* — the vendored `saddle()` helper's
   `uniroot()` call failed to converge within its iteration budget.
   `.pchisqsum_sad()` / `.pFsum_sad()` fall through to the
   Satterthwaite (moment-matched) approximation and **do** fire
   `surveycore_warning_saddlepoint_fallback` (§VI A-8). This is the
   upstream `survey` behavior preserved byte-for-byte, with the
   addition of the typed warning (upstream silently substitutes).
2. *Satterthwaite itself returns a non-finite value* — the moment
   computation overflowed or the reference CDF returned `NaN`. In
   that (rare) case the helper falls further through to the plain
   `χ²(q)` or `F(q, ddf)` reference and emits
   `surveycore_warning_saddlepoint_fallback` with a distinct message
   indicating double-fallback.

Callers can distinguish the two tiers by inspecting the warning
message but both share the single A-8 class for simplicity.

---

## VI. Error & Warning Conditions

New classes to add to `plans/error-messages.md`:

| # | Function | Condition | Level | Class | Message Template |
|---|---|---|---|---|---|
| A-1 | `get_anova()` | `model` not a `survey_glm_fit` | ERROR | `surveycore_error_not_glm_fit` (reuse row 75) | `"{.arg model} must be a {.cls survey_glm_fit} object, not {.cls {class(model)[1]}}."` |
| A-2 | `get_anova()` | Models not symbolically nested | ERROR | `surveycore_error_models_not_nested` | `"x" = "Models are not symbolically nested.", "i" = "Neither model's term set is a subset of the other.", "v" = "Refit one model so its terms are a superset of the other's."` |
| A-3 | `get_anova()` | `model` / `model2` have different responses | ERROR | `surveycore_error_response_mismatch` | `"x" = "Models have different response variables.", "i" = "{.field {lhs1}} vs. {.field {lhs2}}."` |
| A-4 | `get_anova()` | `null` supplied with `method = "LRT"` | ERROR | `surveycore_error_null_with_lrt` | `"x" = "{.arg null} is only valid with {.code method = \"Wald\"}.", "v" = "Set {.code method = \"Wald\"} to test a non-zero null hypothesis."` |
| A-5 | `get_anova()` | `model` / `model2` fit on designs whose `@data` or `@variables` slots differ. Comparison is content-based \u2014 `@metadata@transformations` / `@call` are ignored so users may build the two designs via independent `as_survey()` pipelines (Pass 3 Issue 71). | ERROR | `surveycore_error_design_mismatch` | `"x" = "Models were fit on designs with different {.field @data} or {.field @variables} slots.", "i" = "Comparison mode requires both fits to reference semantically-identical designs (same rows, same design variables).", "v" = "Confirm the two designs wrap the same data frame and use the same {.code ids} / {.code weights} / {.code strata} / {.code fpc} columns; typically this means fitting both models against one stored design object."` |
| A-6 | *(retired — see A-17)* | Previously: intercept-only sequential returned a 0-row tibble. Replaced by A-17 typed error per Pass 3 Issue 7. | — | — | — |
| A-7 | `anova.survey_glm_fit()` | More than one extra argument in `...`, or the extra is not a `survey_glm_fit` | ERROR | `surveycore_error_anova_bad_dots` | `"x" = "anova() on {.cls survey_glm_fit} accepts at most one additional {.cls survey_glm_fit} model.", "i" = "Got {length(others)} extra argument(s)."` |
| A-8 | `get_anova()` | `method = "LRT"` and the saddlepoint solver fails (numerical) | WARN | `surveycore_warning_saddlepoint_fallback` | `"!" = "Saddlepoint p-value failed for term {.field {term}}; falling back to the χ²(q) reference.", "i" = "The χ²(q) reference is only exact when all misspecification eigenvalues are equal. If eigenvalues are heterogeneous (large design effect), the fallback p-value may be inaccurate in either direction.", "v" = "Inspect {.code meta(result)$terms[[i]]$lambda} and consider refitting or using {.code test = \"Chisq\"} with a large sample."` |
| A-9 | `get_anova()` | `model@degf - (p - 1) < 1` (insufficient residual df) | ERROR | `surveycore_error_insufficient_df_for_anova` | `"x" = "Design has {.val {round(ddf_raw, 2)}} residual degree{?s} of freedom for a model with {p} coefficient{?s}; at least 1 is required.", "i" = "The reference distribution cannot be calibrated at this ddf and the p-value is not well-defined for either {.val F} or {.val Chisq} tests.", "v" = "Fit a simpler model (fewer coefficients) or use a design with more primary sampling units."` |
| A-10 | `get_anova()` (via `.reg_term_test()`) | `length(null) != q` for the tested term | ERROR | `surveycore_error_null_length_mismatch` | `"x" = "{.arg null} has length {length(null)} but {q} coefficient(s) are tested for term {.field {term}}.", "v" = "Supply one value per tested coefficient, or {.code null = NULL}."` |
| A-11 | `get_anova()` | Either of two triggers: (a) sequential mode with `method = \"LRT\"` and `model@fit_` is `NULL` (post-serialization); (b) **comparison mode, any method**, and either `model@fit_` or `model2@fit_` is `NULL`. Comparison mode's n-invariance check (§3.5 step 5) reaches into `@fit_` on both models regardless of method, so the serialization guard must fire for Wald comparisons too. (Pass 2 code-review Issue 16.) | ERROR | `surveycore_error_lrt_requires_fit_object` | `"x" = "Variance / n-invariance checks require the underlying GLM fit object(s), which are not persisted after serialization.", "i" = "Sequential LRT needs {.field model@fit_}. Comparison mode (both LRT and Wald) needs {.field model@fit_} and {.field model2@fit_} for the row-identity check.", "v" = "Re-fit the model(s) in the current R session. Sequential Wald is unaffected and remains serialization-safe."` |
| A-12 | `get_anova()` | Row identifiers differ between full and reduced fits (sequential n-mismatch) or between `model` and `model2` (comparison mode). Compared on `rownames(model.frame(@fit_))`, not just `length(@fitted_values)` \u2014 catches both different counts and same count / different subsets. (Pass 3 Issue 59.) | ERROR | `surveycore_error_n_mismatch` | `"x" = "Full model was fit on {n_full} row(s); reduced fit has {n_reduced}.", "i" = "LRT requires the two fits to cover the same rows \u2014 usually this means a dropped term was the only source of NAs in some rows, or the comparison-mode fits were fit on different subsets.", "v" = "Filter the design to rows complete on all predictors, then re-fit both models."` |
| A-13 | `get_anova()` | Naive covariance V₀ is near-singular (`rcond(V0) < tolerance`, user-tunable via the `tolerance` argument; default `sqrt(.Machine$double.eps)`) in the Rao-Scott eigenvalue decomposition | WARN | `surveycore_warning_singular_v0` | `"!" = "Naive covariance V₀ is near-singular for term {.field {term}}; using pseudoinverse.", "i" = "Reciprocal condition number: {.val {signif(rcond(V0), 3)}} (threshold: {.val {signif(tolerance, 3)}}).", "v" = "Inspect the model for collinearity in the tested coefficients."` |
| A-14 | `get_anova()` | `model@design` is a `survey_nonprob` object (fires once per call, at top of `get_anova()`) | WARN | `surveycore_warning_nonprob_inference` | `"!" = "Variance for nonprob designs is model-based; inference assumes the fitted model is correctly specified.", "i" = "ANOVA p-values do not account for selection bias.", "v" = "Treat results as model-based inference; for design-based ANOVA use a probability-sample design."` |
| A-15 | `get_anova()` | `reduced@deviance - model@deviance < 0` (negative LRT deviance difference, usually a reduced-fit convergence issue) | WARN | `surveycore_warning_negative_deviance_diff` | `"!" = "Deviance difference is negative for term {.field {term}} ({.val {signif(chisq, 3)}}); the reduced fit may not have converged.", "i" = "Treating as 0 to keep the LRT well-defined.", "v" = "Inspect reduced-model convergence via {.fn summary} on a manual refit."` |
| A-16 | `get_anova()` | Comparison mode called with two models that have identical term sets (`setequal(t1, t2)` is TRUE) | ERROR | `surveycore_error_identical_term_sets` | `"x" = "Both models have identical term sets; there are no terms to test.", "i" = "Comparison mode requires one model's terms to be a strict superset of the other's.", "v" = "Use {.code get_anova(model)} for sequential term tests, or fit one of the models with additional terms."` |
| A-17 | `get_anova()` | Sequential mode called on an intercept-only model (`nt < 1`) | ERROR | `surveycore_error_no_terms_to_test` | `"x" = "Model is intercept-only; there are no terms to test.", "i" = "Sequential ANOVA requires at least one non-intercept term in the formula.", "v" = "Fit a model with at least one predictor, e.g. {.code y ~ x}."` |
| A-18 | `get_anova()` | `tolerance` fails boundary validation (non-numeric, length ≠ 1, non-finite, or negative) | ERROR | `surveycore_error_invalid_tolerance` | `"x" = "{.arg tolerance} must be a single finite non-negative numeric value.", "i" = "Got {.cls {class(tolerance)[1]}} of length {length(tolerance)}: {.val {tolerance}}.", "v" = "Use the default {.code sqrt(.Machine$double.eps)}, or supply any {.val 0}-or-positive numeric scalar."` |
| A-19 | `get_anova()` (via `.refit_drop_terms()`) | Replicate refit: one or more replicate fits inside the refitted reduced model failed to converge. Surfaced from `survey_glm()`'s internal loop (`R/glm.R:474-487`) and re-raised at the ANOVA level so the user sees it once per affected refit rather than 500+ times. | WARN | `surveycore_warning_replicate_nonconvergence` | `"!" = "{k} of {K} replicate fit(s) did not converge for the reduced model in term {.field {term}}; variance may be biased.", "i" = "Inspect {.code fit@rep_failures} (on the reduced refit) for which replicates failed.", "v" = "Consider a coarser replicate structure or re-fit with stricter convergence controls."` |
| A-20 | `get_anova()` (via `.refit_drop_terms()`) | The `..surveycore_domain..` indicator column differs between the full fit's design and the reduced refit's design. Should be impossible in practice because `.refit_drop_terms()` reuses `model@design` verbatim; the runtime check is a defensive assertion against external mutation of `@design@data` between full and reduced fits. (Pass 3 Issue 68.) | ERROR | `surveycore_error_domain_mismatch` | `"x" = "Domain indicator differs between full and reduced fits for term {.field {term}}.", "i" = "This usually means {.code model@design@data} was mutated (e.g., via {.fn filter} on a stored reference) between fitting the full model and calling {.fn get_anova}.", "v" = "Do not modify the design between fits; pass the same design object to both {.fn survey_glm} calls."` |

Reused classes (no new rows needed):

| Class | Reused from |
|---|---|
| `surveycore_error_invalid_decimals` | row 45b |
| `surveycore_error_invalid_name_style` | row 46 |

Note: `surveycore_warning_insufficient_df` (row 77 of
`plans/error-messages.md`) is **not** reused here. The clamping-plus-warning
path from `survey_glm()` is replaced with a hard error at the ANOVA entry
point (A-9 above); see §3.3.3.

---

## VII. Testing Requirements

### Happy Path — sequential mode

- [ ] `get_anova(fit)` returns a `survey_anova` tibble with one row per
      model term
- [ ] Term order in output matches formula order (leftmost term first)
- [ ] All four `method` × `test` combinations return the same seven
      columns: `term`, `statistic`, `df`, `ddf`, `deff`, `p_value`, `stars`
- [ ] `method = "LRT"`, `test = "F"` (default): `ddf` is finite;
      `deff` is finite
- [ ] `method = "LRT"`, `test = "Chisq"`: `ddf` is `NA_real_`;
      `deff` is finite
- [ ] `method = "Wald"`, `test = "F"`: `ddf` is finite;
      `deff` is `NA_real_`
- [ ] `method = "Wald"`, `test = "Chisq"`: both `ddf` and `deff` are
      `NA_real_`
- [ ] All five design classes: `taylor`, `replicate`, `twophase`,
      `nonprob`, `srs` (one smoke test each via `make_survey_data()`)
- [ ] Print snapshot (Taylor + LRT/F, `decimals = 3`): three-line header
      is present, tibble body renders via explicit `print(x, ...)`
      dispatch (tbl_df method), `stars` column renders once (no
      duplication)
- [ ] Print snapshot (Wald/F, Taylor): `deff` column is **absent** from
      the printed tibble body (but `"deff" %in% names(result)` is still
      `TRUE`), proving §3.9.3 suppression works. Regression test for
      Pass 2 code-review Issue 18 (the `NextMethod()` rebinding bug).
- [ ] Print snapshot (BRR replicate + LRT/F): `# Design:` line reads
      `Replicate weights (BRR)` (exercises §3.9.1 design-label table)
- [ ] Print snapshot (Taylor + Wald): `deff` column is omitted from the
      printed body; `result$deff` still exists on the returned tibble
      (exercises §3.9.3 suppression branch)
- [ ] `name_style = "broom"` renames `p_value` → `p.value`, `ddf` →
      `df_residual`; `statistic` and `df` unchanged
- [ ] `decimals = 2` rounds all double columns
- [ ] Intercept-only model (`y ~ 1`) errors with `surveycore_error_no_terms_to_test` (§VI A-17)
- [ ] `label_vars = TRUE` — plain term with a variable label: `attr(result$term, "label")[i]` equals the stored variable label (e.g., `"Age in years"`)
- [ ] `label_vars = TRUE` — plain term with no variable label in metadata: that cell's `attr(col, "label")` falls back to the raw term string and no composition is attempted
- [ ] `label_vars = TRUE` — interaction term where all components have labels: composed label uses ` × ` separator (e.g., `"Age in years × Sex"`)
- [ ] `label_vars = TRUE` — interaction term where at least one component has no label: that cell falls back to the raw `"age:sex"` string
- [ ] `label_vars = TRUE` — **three-way interaction** (`y ~ age * sex * race`) with labels on all three components: the composed label for the `"age:sex:race"` row is exactly `"Age in years × Sex × Race"` in that component order. Verifies `strsplit(term, ":", fixed = TRUE)[[1]]` traversal order and the `k`-way composition rule. (Pass 2 code-review Issue 20.)

### Happy Path — comparison mode

- [ ] `get_anova(fit_small, fit_big)` and `get_anova(fit_big, fit_small)`
      produce identical result rows (bigger model is detected regardless of
      argument order)
- [ ] Comparison-mode `term` column reads `"added_terms | base_terms"`
- [ ] One result row per comparison call (not one per added term)
- [ ] Symbolic-nested check: all-overlap-either-direction passes;
      non-overlapping terms errors with `surveycore_error_models_not_nested`
- [ ] `anova(fit1, fit2)` S3 method produces the same result as
      `get_anova(fit1, fit2)`
- [ ] All five design classes: `taylor`, `replicate`, `twophase`,
      `nonprob`, `srs` — smoke test `get_anova(fit_small, fit_big)` on
      each (one-row `survey_anova` tibble returned; no numerical
      assertion). Exercises `.anova_compare()` across every design class,
      matching the sequential-mode cross-design coverage above.

### Error Paths

One `expect_error(class = ...)` + `expect_snapshot(error = TRUE)` block for
each new class (A-2, A-3, A-4, A-5, A-7, A-10, A-16, A-17, A-18, A-20)
plus the reused `surveycore_error_not_glm_fit` (A-1) triggered via
`get_anova("not a fit")`. A-10 is triggered via
`get_anova(fit, method = "Wald", null = c(0, 0))` on a fit whose
right-most term has a single coefficient. A-16 is triggered via
`get_anova(fit, fit)` (identical term sets). A-17 is triggered via
`get_anova(fit)` on an intercept-only fit (`y ~ 1`). A-18 has four
separate triggers (one per failure mode): `tolerance = "1e-5"` (non-numeric),
`tolerance = c(1e-5, 1e-6)` (length ≠ 1), `tolerance = NA_real_` (non-finite),
and `tolerance = -1` (negative). A-20
(`surveycore_error_domain_mismatch`) is triggered by mutating the
design between full and reduced fits — e.g., fit the full model,
flip `model@design@data$..surveycore_domain..[1] <- FALSE` via a
test-only accessor (or rebuild `@design@data` with one row removed),
then call `get_anova(model)`; the assertion inside
`.refit_drop_terms()` fires the typed error. Also covers the comparison-mode
branch of A-11: call `get_anova(fit_stripped, fit_live, method = "Wald")`
where `fit_stripped@fit_` has been set to `NULL`, and assert
`surveycore_error_lrt_requires_fit_object` (Pass 2 code-review Issue 16).

### Edge Cases

- [ ] Single-term model (`y ~ x`) — sequential mode returns 1 row
- [ ] Interaction term in formula (`y ~ a * b`) — produces 3 rows:
      `a`, `b`, `a:b`, in that order
- [ ] Binomial family fit — all four method/test combos work without error
- [ ] `fit@degf = 2` with a 5-coefficient model — errors with
      `surveycore_error_insufficient_df_for_anova` at the top of
      `get_anova()`; no refit is attempted
- [ ] Domain-filtered design — sequential refits inherit the domain; no
      NAs leak into the refit
- [ ] Non-default contrasts (`contr.sum`) — sequential refit produces a
      coherent ANOVA table; no error or warning fires (regression test for
      Issue 4 resolution)
- [ ] `model@fit_` is `NULL` (post-serialization) with `method = "LRT"` —
      error: `surveycore_error_lrt_requires_fit_object` (§VI A-11)
- [ ] Near-singular V₀ (collinear factor interaction) — warning:
      `surveycore_warning_singular_v0` (§VI A-13); lambda is still
      finite and p-value is still computed
- [ ] `survey_nonprob` design — warning:
      `surveycore_warning_nonprob_inference` (§VI A-14) fires once per
      call; result tibble is still produced
- [ ] **Negative deviance diff, roundoff band (A-15).** Construct a
      reduced-fit scenario where `reduced@deviance - model@deviance` is
      a tiny negative value within the documented roundoff tolerance
      band (Pass 3 Issue 60) — the computation proceeds silently with
      the deviance clipped to 0 and **no warning fires**. Then construct
      a case where the negative diff exceeds the tolerance band (inject
      divergent reduced-fit start values) — assert
      `surveycore_warning_negative_deviance_diff` (§VI A-15). Both sides
      of the band must be exercised.
- [ ] **Replicate nonconvergence surfaced at ANOVA level (A-19).**
      Build a `survey_replicate` design with a pathological replicate
      (e.g., a JK1 replicate that drops all observations for one level
      of a factor) and call `get_anova(fit)` — assert
      `surveycore_warning_replicate_nonconvergence` (§VI A-19) fires
      once per failing refit (not once per replicate; see A-19
      description). Inspect the reduced refit's `@rep_failures` to
      confirm the count matches the warning's `k` value.
- [ ] **Comparison-mode serialization guard (A-11 broadened).** Fit two
      nested models on the same design, then set `fit_small@fit_ <- NULL`
      (simulating `saveRDS()` round-trip). Call
      `get_anova(fit_small, fit_big, method = "Wald")` — assert
      `surveycore_error_lrt_requires_fit_object` (§VI A-11). Repeat
      with `fit_big@fit_ <- NULL` and `method = "LRT"`. Both
      method/side combinations must produce the typed error, not a
      `model.frame(NULL)` crash. (Pass 2 code-review Issue 16.)

### Numerical Tests (`test-glm-anova-numerical.R`)

Compare against `survey::anova.svyglm()` using `nhanes_2017`. All four
method × test combinations for sequential mode; LRT+F and Wald+Chisq for
comparison mode.

```r
skip_if_not_installed("survey")

d_sc <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtmec2yr,
                   strata = sdmvstra, nest = TRUE)
d_sv <- survey::svydesign(ids = ~sdmvpsu, weights = ~wtmec2yr,
                          strata = ~sdmvstra, nest = TRUE,
                          data = nhanes_2017)

fit_sc <- survey_glm(d_sc, bpxsy1 ~ ridageyr + riagendr)
fit_sv <- survey::svyglm(bpxsy1 ~ ridageyr + riagendr, design = d_sv)

a_sc <- get_anova(fit_sc, method = "LRT", test = "F")
a_sv <- anova(fit_sv, method = "LRT", test = "F")

expect_equal(a_sc$statistic[[1L]], a_sv[[1L]]$chisq, tolerance = 1e-8)
expect_equal(a_sc$p_value[[1L]],   a_sv[[1L]]$p,    tolerance = 1e-6)
```

Tolerances follow the project standard in
`.claude/rules/testing-surveycore.md` §"Variance estimation numerical
tolerances": 1e-10 (point estimates), 1e-8 (test statistics, since
saddlepoint is iterative), 1e-6 (p-values). The p-value tolerance is
held at 1e-6 rather than 1e-10 because saddlepoint root-finding and
`pchisq()` implementations can differ by ~1e-8 between R versions and
between the vendored port and `survey`'s current copy; holding
p-values to 1e-10 produces spurious test churn on every saddlepoint
iteration-count change. (Pass 3 Issue 72 — previous versions of this
spec had the statistic and p-value tolerances inverted.)

**Replicate-design oracle (BRR).** The Rao-Scott derivation of the
eigenvalue-based LRT was written for Taylor-type sandwiches; the
replicate sandwich is consistent under standard regularity conditions
(Binder 1983; Lumley 2010 §2.4.2) but numerically distinct, and for
bootstrap replicate designs the consistency result requires B → ∞.
Add a parallel oracle test on `acs_pums_wy` (or another BRR replicate
design) verifying parity with `survey::anova.svyglm()` at tolerance
1e-6 on the p-value and 1e-8 on the statistic.

**Tolerance semantics (Pass 3 Issue 76).** `expect_equal()` in
testthat 3.x interprets `tolerance=` as relative when both `target`
and `actual` are non-zero and bounded away from zero, and as absolute
when either is near zero. For p-values in the interior of the unit
interval (roughly `(1e-4, 1 - 1e-4)`), the default relative
interpretation is appropriate and `tolerance = 1e-6` means "within 1
ppm of the oracle p-value". For p-values near 0 or 1 (e.g., strongly
significant terms) the relative comparison can be over-strict
(1e-6 of 1e-10 is tighter than float precision); the oracle tests
that exercise those regimes pass a comment at the call site directing
future readers to use `expect_equal(..., tolerance = 1e-6,
scale = 1)` to force absolute tolerance, or to assert on
`log10(p_value)` bounds instead.

**Fay-BRR oracle (Pass 3 Issue 64).** The replicate variance sandwich
for a Fay-coefficient-BRR design includes the `1 / (1 - ρ)²` scaling
upstream (in `.glm_replicate_vcov()`); `get_anova()` reads
`V <- model@vcov[idx, idx]` directly and never recomputes from
raw replicate deviations. Add a targeted oracle test on a Fay-BRR
design (construct via `as_survey_repweights(..., type = "Fay",
rho = 0.3)` using synthetic data) verifying parity with
`survey::anova.svyglm()` at the same 1e-6 / 1e-8 tolerances — this is
the regression test for Fay-BRR-specific ρ handling, distinct from
the plain BRR oracle above.

**Two-phase oracle.** `.glm_vcov_dispatch()` delegates to
`.twophase_var_score_matrix()` (`R/glm.R:332`), which returns the phase-1
/ phase-2 decomposition. Add a numerical oracle test on a canonical
two-phase design (e.g. one of `make_survey_data(design = "twophase")` or
the `survey` package's `pbc` two-phase example):

```r
test_that("get_anova() matches survey::anova.svyglm() on a two-phase design [numerical]", {
  skip_if_not_installed("survey")
  # setup two-phase design; fit via survey_glm() and survey::svyglm()
  # assert statistic within 1e-8, p-value within 1e-6
})
```

The refit for LRT sequential / comparison modes inherits both the phase-1
design AND the phase-2 subset mask, because `survey_glm()` re-applies them
automatically from `design@variables` — see §3.4 "Two-phase designs."

**Vendored saddlepoint parity** (`test-variance-vendored-saddlepoint.R`).
§V.5 commits `.pchisqsum_sad()` and `.pFsum_sad()` to "preserved
byte-for-byte" vs `survey` 4.4-8. Pin the contract with a standalone
parity test file (separate from the ANOVA-level numerical oracle,
since these helpers are testable on their own without a fit):

- `.pchisqsum_sad(x, df, a)` vs `survey::pchisqsum(x, df, a, method = "saddlepoint")`.
- `.pFsum_sad(x, df, a, ddf)` vs `survey::pFsum(x, df, a, ddf, method = "saddlepoint")`.

**Tolerance.** `1e-10` absolute on the returned p-value. Byte-for-byte
parity is stricter than the ANOVA-level `1e-6` p-value tolerance
because this test compares the vendored function's output directly to
the upstream source — there is no intermediate floating-point
accumulation (no eigenvalue decomposition, no refit, no `rcond`
branching). Any drift at this level is either a copy bug or a genuine
divergence in the vendored source from upstream, both of which the
test should surface.

**Input grid.** Minimum coverage:

| Regime | `x` | `df` | `a` (lambda) | `ddf` (pFsum only) |
|---|---|---|---|---|
| Upper tail | `qchisq(c(1 - 1e-6, 1 - 1e-3, 1 - 1e-2), df = 3)` for `.pchisqsum_sad`; correspondingly high F-quantiles for `.pFsum_sad` | 3 | `c(1, 1, 1)` (equal-λ → reduces to `χ²(3)`); `c(3, 1, 0.5)` (heterogeneous) | 30 |
| Mid-range | `qchisq(c(0.25, 0.5, 0.75), df = 3)` | 3 | `c(1, 1, 1)`; `c(3, 1, 0.5)` | 30 |
| Near zero | `0.01 * sum(a)` (lower tail boundary; saddlepoint hardest here) | 3 | `c(1, 1, 1)` | 30 |
| Scalar `a` (single-λ edge case) | `qchisq(0.95, df = 1) * 2` | 1 | `2` | 30 |
| Large `df` | `qchisq(c(0.5, 0.99), df = 20)` | 20 | `rep(1, 20)` | 30 |

**Fallback path.** The "saddlepoint → Satterthwaite → χ²/F reference"
two-tier fallback (§V.5, per Pass 3 Issue 63) is triggered when the
saddlepoint root-finder returns `NA`. The parity test grid does not
need to hit this path (it's tested inside the `get_anova()` flow via
the A-8 `saddlepoint_fallback` warning trigger), but the parity test
*does* need to confirm that `.pchisqsum_sad()` returns `NA` in the
exact same input regimes where `survey::pchisqsum(method = "saddlepoint")`
returns `NA` — otherwise the upstream-matching fallback logic in the
ANOVA layer will diverge silently.

All cells in the grid assert `expect_equal(ours, theirs, tolerance = 1e-10)`.
The entire block is guarded by `skip_if_not_installed("survey")` at the
top of each `test_that()` (block-level, per
`.claude/rules/testing.md`). (Pass 2 code-review Issue 21.)

### Meta Contract

- [ ] `meta(result)` contains all `ANOVA_META_KEYS` plus `design_type`,
      `replicate_type`, `n_respondents`, `call`
- [ ] `meta(result)$replicate_type` is `NA_character_` for non-replicate
      designs and a length-1 string (e.g. `"BRR"`) for replicate designs
- [ ] `meta(result)$terms` is a list of length `nrow(result)`; each element
      has keys `raw_chisq`, `lambda`, `ddf_used`,
      `test_terms`
- [ ] `meta(result)$model$formula` is the stored formula object

---

## VIII. Quality Gates

- [ ] `devtools::check()` — 0 errors, 0 warnings, ≤ 2 notes
- [ ] 98%+ line coverage on `R/glm-anova.R`
- [ ] All new error/warning classes (A-2 through A-20) have typed tests
      and snapshots
- [ ] All five design classes have ≥ 1 sequential-mode happy-path test
- [ ] Numerical oracle tests pass vs. `survey::anova.svyglm()` for all
      four method × test combinations on a Taylor design, plus a BRR
      replicate oracle and a two-phase oracle at 1e-6 (p-value) / 1e-8
      (statistic) tolerances
- [ ] `plans/error-messages.md` updated with A-2 through A-20
- [ ] `MEMORY.md` updated to reflect `get_anova()` as planned / shipped
- [x] GAP M-1 (saddlepoint implementation) — resolved in Stage 2 (Issue 15);
      vendored into `R/variance-vendored-saddlepoint.R` per §V.5
- [x] GAP M-2 (family reconstruction in refit) — resolved in Stage 2;
      specified in §V.3

---

## IX. Integration / Dependencies

- **`survey_glm()` / `survey_glm_fit`**: authoritative source for
  `@coefficients`, `@vcov`, `@degf`, `@formula`, `@family`, `@fit_`. Must
  already be on `develop` (✅ Phase 2 complete per `MEMORY.md`).
- **New `survey_glm_fit` property `@term_assign`** (Pass 3 Issue 2):
  an integer vector carrying `attr(model.matrix(fit), "assign")` captured
  at fit time. Required for serialization-safe Wald (§3.3.1) and for
  `idx` resolution in `.reg_term_test()` (§V.1 step 1) when `@fit_` has
  been stripped by `saveRDS()`. Adding the property touches three files:
  (1) the `survey_glm_fit` class definition in `R/core-classes.R` (new
  property with default `integer(0)`), (2) the `survey_glm()` constructor
  in `R/glm.R` (store `attr(model.matrix(fit_), "assign")` into the new
  slot at fit time), (3) the S7 validator (no new invariants beyond
  "integer vector"). This is a pre-requisite PR for `get_anova()`;
  `get_anova()` must not be merged until `@term_assign` is on `develop`.
  Sequencing: PR A (add `@term_assign` to `survey_glm_fit`) → PR B
  (`get_anova()`, depends on PR A).
- **Phase 1 infrastructure**: `.make_result_tibble()`, `ANOVA_META_KEYS`
  validation, `.build_meta()`, `.apply_decimals()`, `.apply_name_style()`,
  `.stars_pval()` — all already shipped.
- **MASS** is relied upon as a **recommended R package** (no explicit
  `Imports` declaration). `MASS::ginv()` is called unconditionally on the
  near-singular V₀ branch of §3.3.2. MASS ships with base R on all
  supported platforms (it is one of the "recommended" packages installed
  alongside R itself), so this adds no third-party-dependency weight and
  does not require a DESCRIPTION Imports entry. (Pass 2 Issue 32.)
- **No other new package imports.** GAP M-1 (saddlepoint) is closed by
  vendoring from `survey` into `R/variance-vendored-saddlepoint.R`; no
  runtime dependency on `survey` is introduced.

Open GAPs summary (for Stage 2 methodology review):

- ~~**GAP M-1** — saddlepoint CDF implementation (§3.3.2)~~
  — closed 2026-04-16 (Stage 2 Resolve, Issue 15): vendor from `survey`.
- ~~**GAP M-2** — family reconstruction during refit (§V.3)~~
  — closed 2026-04-16 (Stage 2 Resolve, Issue 6).

No open GAPs at the code/API level after Stage 2 Resolve; Stage 3 may
identify more.

**Deferred follow-up — `@model_rows` property on `survey_glm_fit`**
(Pass 3 Issue 59). The n-invariance check (§3.4 step 3d, §3.5 step
5, §V.1 step 5) derives row identifiers on demand from
`rownames(model.frame(@fit_))` rather than from a persistent
`@model_rows` property. This keeps the ANOVA PR's surface area
minimal and avoids enlarging PR A. A follow-up PR should add
`@model_rows` (integer vector, length `nobs(fit_)`, default
`integer(0)`) to `survey_glm_fit`, populate it in the `survey_glm()`
constructor at fit time, and switch `get_anova()`'s invariance check
to read from the property instead of `model.frame(@fit_)`. Benefit:
the check survives serialization (currently LRT requires `@fit_`
anyway via A-11, so the practical impact is minor, but it would
make Wald-mode comparisons able to assert n-invariance post-reload
if that ever becomes desirable). No action needed for the v1
`get_anova()` release.

---

## X. References

Methodological references cited in this spec. DOIs given where known;
surveyverse convention is to cite by DOI rather than by journal
volume/page to remain robust to republication and to make targeted
lookup easier. (Pass 3 Issues 73, 77, 78.)

- **Binder, D. A.** (1983). "On the variances of asymptotically normal
  estimators from complex surveys." *International Statistical
  Review* 51(3):279–292. DOI 10.2307/1402588. — Establishes
  consistency of sandwich variance estimators under design-based
  inference; cited in §3.3.2 for the replicate-design eigenvalue
  claim.
- **Fay, R. E.** (1989). "Theory and application of replicate weighting
  for variance calculations." *Proceedings of the Section on Survey
  Research Methods, American Statistical Association*, 212–217. —
  Foundational reference for the Fay-coefficient BRR modification;
  cited in §3.3.2 for ρ handling.
- **Judkins, D. R.** (1990). "Fay's method for variance estimation."
  *Journal of Official Statistics* 6(3):223–239. — Practical
  description of Fay-BRR with worked examples; cited in §3.3.2.
- **Kuonen, D.** (1999). "Saddlepoint approximations for distributions
  of quadratic forms in normal variables." *Biometrika*
  86(4):929–935. DOI 10.1093/biomet/86.4.929. — Primary reference for
  the saddlepoint CDF used in `.pchisqsum_sad()` / `.pFsum_sad()` (§V.5).
- **Lumley, T.** (2010). *Complex Surveys: A Guide to Analysis Using R.*
  Wiley, Hoboken, NJ. ISBN 978-0-470-28430-8. — General reference
  for design-based inference in R. Specific sections cited: §2.4.2
  (sandwich-variance consistency under design-based inference, §3.3.2),
  §2.5.1 (replicate-weight variance, including BRR and Fay, §3.3.2),
  §6.3 (the Rao-Scott working-LRT eigenvalue-weighted reference
  distribution, §3.3.2), §8 (GLMs under design-based inference — the
  "recommended reference under design-based inference" citation in
  §3.3.1).
- **Lumley, T., and Scott, A. J.** (2014). "Tests for regression models
  fitted to survey data." *Australian & New Zealand Journal of
  Statistics* 56(1):1–14. DOI 10.1111/anzs.12065. — Presentation of
  the Rao-Scott framework for regression models specifically, as
  implemented in `survey::anova.svyglm()`; cited in §3.3 as the
  methodological commitment this spec follows.
- **Rao, J. N. K., and Scott, A. J.** (1984). "On chi-squared tests for
  multiway contingency tables with cell proportions estimated from
  survey data." *Annals of Statistics* 12(1):46–60.
  DOI 10.1214/aos/1176346391. — Original eigenvalue-based correction
  for design-based χ² statistics.
- **Rao, J. N. K., and Scott, A. J.** (1987). "On simple adjustments to
  chi-square tests with sample survey data." *Annals of Statistics*
  15(1):385–397. DOI 10.1214/aos/1176350273. — First- and
  second-order adjustments; the first-order adjustment (division by
  `mean(lambda)`) is what `.pFsum_sad()` implements via `mean.deff`.
- **Satterthwaite, F. E.** (1946). "An approximate distribution of
  estimates of variance components." *Biometrics Bulletin* 2(6):110–114.
  DOI 10.2307/3002019. — Primary reference for the Satterthwaite
  approximation used as the saddlepoint fallback in §V.5 (Pass 3
  Issue 73).
- **survey package.** `R/anova.svyglm.R`, `R/regtest.R`, and
  `R/pchisqsum.R` in the `survey` R package (GPL-2 | GPL-3; Thomas
  Lumley, maintainer). The source trees referenced in §II and §V.5
  are the code `get_anova()` is modeled on; the saddlepoint helpers
  (`.pchisqsum_sad()`, `.pFsum_sad()`) are vendored from
  `pchisqsum.R`.
