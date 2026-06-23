# Design: `coef()` and `vcov()` Methods for Analysis Results

**Date:** 2026-06-22
**Status:** Complete — all decisions resolved

## What we're building

surveycore's `get_*()` functions (`get_means()`, `get_totals()`, `get_freqs()`, etc.) return S3-on-tibble result objects. We want to add `coef()` and `vcov()` methods so that downstream tools — `confint()`, `marginaleffects`, custom contrast code — can treat these results as standard model-like objects. This requires agreeing on how estimates are named, how the variance-covariance matrix is stored, and what supporting infrastructure (`SE()`, `confint()`, `as.data.frame()`) ships alongside.

---

## Questions and Decisions

### Q1: Naming convention for `coef()` output

What names should the returned vector carry across all result shapes?

**Decision:** Use `group_label:variable_name` (colon separator) for grouped results; bare variable name for ungrouped. Order is group-major (all variables for group A, then all for group B). Matches survey's `svyby` convention.

---

### Q2: Structural metadata attribute on result objects

`coef()` needs to know which positions/columns are estimates vs. SE vs. group labels. In the survey package this is `attr(x, "svyby")` containing `$margins`, `$nstats`, `$vars`, etc.

What attribute (name and structure) should surveycore attach to result objects to encode this?

**Decision:** Attach `attr(x, ".survey_result")` as a list with three fields: `estimate_cols` (character vector of estimate column names), `group_cols` (character vector of grouping column names, `character(0)` if none), and `statistic` (string naming the statistic, e.g. `"mean"`). `coef()` uses `estimate_cols` and `group_cols` to extract and name the coefficient vector without index arithmetic.

---

### Q3: Degrees of freedom storage

`confint()` needs the design degrees of freedom to use the t-distribution rather than normal quantiles.

#### How survey handles it (subagent investigation)

| Design type | Stored on result? | How |
|---|---|---|
| Taylor (`svymean` only) | Yes | `attr(result, "df")` — scalar at survey.R:564 |
| Taylor `svytotal` | No | arithmetic `m * N` strips attributes |
| Replicate | No | never assigned on `svrepstat` objects |
| Two-phase | No | never assigned even though class is `svystat` |
| `svyby` grouped | No | per-group df computed per subset but discarded by `unwrap()` |

Critically: `confint()` in survey **does not read `attr(object,"df")`** — it defaults to `df=Inf`
(normal approximation) unless the caller passes `df=` explicitly (confint.R:6-8). The stored
scalar df on Taylor svymean results is effectively unused by confint.

#### Decision for surveycore

Match survey exactly: store a **scalar** design-level df inside `.survey_result`:

```r
attr(result, ".survey_result") <- list(
  estimate_cols = c("age"),
  group_cols = character(0),
  statistic = "mean",
  df = .degf(design) # scalar; Inf for replicate/nonprob
)
```

- Taylor designs: `.degf(design)` (finite, PSUs minus strata)
- Replicate / nonprob designs: `Inf` (matching survey's implicit behaviour of never storing df on `svrepstat`)
- Grouped results: single design-level df, not per-group — matches survey discarding per-group df in `svyby`
- `confint()` reads `.survey_result$df` directly; no caller effort required (improvement over survey where the stored df is unused by confint)

**Decision:** Store scalar df in `.survey_result$df`, following survey's scalar convention. Per-row df for calibrated Taylor designs remains in the `df` tibble column for display but is not used programmatically by `coef()`/`vcov()`.

---

### Q4: Variance matrix storage and dimnames

Where should the full variance-covariance matrix live on the result object, and how should its rows/columns be named?

**Decision:** Store as `$var` inside `.survey_result`. Dimnames (both `rownames` and `colnames`) follow the Q1 naming convention exactly — identical to `names(coef(result))`. `vcov()` returns the matrix with those names already set.

---

### Q5: Grouped covariance — block-diagonal vs. joint

For grouped results (e.g., `get_means()` with `group = region`), group estimates are computed independently, so the true off-diagonal covariance between groups is zero. Two options:

- **Block-diagonal:** Assemble from per-group variances. Simple, always available.
- **Joint (via influence functions):** Carry influence functions through `get_*()` and assemble the full matrix. Required only if users want to test contrasts *across* groups (e.g., difference of means between regions).

**Decision:** Block-diagonal. Assemble the `$var` matrix from per-group vcov blocks; off-diagonal covariances between groups are set to zero. Matches `survey::svyby` default. Cross-group contrasts will have conservatively estimated SEs; within-group contrasts are exact. Joint influence-function approach deferred to a future phase.

---

### Q6: `SE()` generic

Should surveycore define its own `SE()` generic and method, or rely on the survey package's?

**Decision:** Define surveycore's own `SE()` S3 generic and methods. `survey` is Suggests-only so importing from it is unsafe. The masking conflict when both packages are loaded is acceptable standard R practice. Default method body: `sqrt(diag(vcov(object)))`.

---

### Q7: `confint()` method

After `coef()`/`vcov()` exist, users will immediately want confidence intervals. Should this ship in the same PR, and should it use the t-distribution with stored df?

**Decision:** Ship `confint()` in the same PR as `coef()`/`vcov()`. Implementation reads `.survey_result$df` and calls `qt()` — degrades to `qnorm()` automatically when df is `Inf` (replicate/nonprob). No new design choices beyond Q3.

---

### Q8: `as.data.frame()` method

The survey package's `as.data.frame.svystat` builds from `coef()` and `SE()`. Should surveycore add an equivalent, or is the tibble output from `get_*()` sufficient?

**Decision:** Skip. `get_*()` already returns a tibble; `as.data.frame()` works via tibble's own method. The coef/SE/vcov trio is the interop surface — a parallel two-column representation adds complexity without value. Users who need that layout can do `data.frame(coef = coef(result), SE = SE(result))` explicitly.
