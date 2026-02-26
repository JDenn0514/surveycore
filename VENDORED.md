# Vendored Code Tracking

This file documents all code vendored from external packages into surveycore.
It exists to support GPL-3 license compliance and to make upstream sync auditable.

## License Context

surveycore is licensed under GPL-3. Variance estimation code is vendored from the
`survey` package by Thomas Lumley, licensed under GPL-2 | GPL-3. Vendoring
GPL-2/GPL-3 code into a GPL-3 package is compliant with both licenses.

## Attribution Headers

### R/06-variance-taylor.R (Taylor and replicate variance)

```r
# =============================================================================
# Vendored from the survey package by Thomas Lumley
# CRAN: https://cran.r-project.org/package=survey
# License: GPL-2 | GPL-3
# survey version: [VERSION — update when vendoring]
# Vendored: [DATE — update when vendoring]
#
# Modifications made to integrate with S7 classes while maintaining numerical
# equivalence with the original implementation.
#
# Per GPL-3: source code is available in this repository; original copyright
# notice and license are reproduced here.
#
# Original copyright:
#   Copyright (C) Thomas Lumley and contributors
# =============================================================================
```

## Vendored Functions

### Taylor / Replicate (R/06-variance-taylor.R)

| surveycore name | Adapted from | survey version | Modified? | Notes |
|-----------------|-------------|----------------|-----------|-------|
| `.svy_onestrat()` | `survey:::onestrat` | 4.4.8 | Yes | cli errors; `getOption("survey.adjust.domain.lonely")` removed |
| `.svy_onestage()` | `survey:::onestage` | 4.4.8 | Yes | `vapply` instead of `sapply`; cli error format |
| `.svy_multistage()` | `survey:::multistage` | 4.4.8 | Yes | RCPP path removed; renamed `fpcs` param to `popmat` for clarity |
| `.svy_recvar()` | `survey:::svyrecvar` | 4.4.8 | Yes | RCPP dispatch and post-strata handling removed (Phase 0 scope) |

### Two-Phase (R/06-variance-twophase.R)

| surveycore name | Adapted from | survey version | Modified? | Notes |
|-----------------|-------------|----------------|-----------|-------|
| `.twophasevar()` | `survey:::twophasevar` | 4.4.8 | Yes | S7 class access; three-method dispatch made explicit; cli errors |
| `.twophase_phase1_var()` | `survey:::svyrecvar.phase1` | 4.4.8 | Yes | S7 `@variables` access; FPC matrix built inline; cli errors |
| `.twophase_phase2_var()` | Phase 2 component of `survey:::twophasevar` | 4.4.8 | Yes | S7 access; auto-popsize computation; RCPP path removed |
| `.compute_phase2_probs()` | Internal prob computation in `survey/R/twophase.R` | 4.4.8 | Yes | S7 `@variables` access; three-priority rule made explicit |

### Correlation Variance (R/06-variance-taylor.R, R/06-variance-replicate.R, R/06-variance-srs.R, R/06-variance-twophase.R)

| surveycore name | Adapted from | survey version | Modified? | Notes |
|-----------------|-------------|----------------|-----------|-------|
| `.vcov_pair_taylor()` | `survey:::svyvar` linearization in `survey/R/surveysummary.R` | 4.4.8 | Yes | Bivariate domain-estimation; 3-column influence matrix; S7 `@variables` access |
| `.vcov_pair_replicate()` | Replicate variance of `survey:::svyvar` | 4.4.8 | Yes | Per-replicate (Var(X), Cov(X,Y), Var(Y)) computation; 3×3 meta-vcov via matrix replicate formula |
| `.vcov_pair_srs()` | Taylor linearization of `survey:::svyvar` applied to `svydesign(ids=~1)` | 4.4.8 | Yes | SRS structure (each obs = own PSU); delegates to `.svy_recvar()` |
| `.vcov_pair_calibrated()` | HT linearization of `survey:::svyvar` | 4.4.8 | Yes | HT variance formula for calibrated designs; in-domain rows only |
| `.vcov_pair_twophase()` | Two-phase linearization of `survey:::svyvar` | 4.4.8 | Yes | Polarization identity applied to `.twophasevar()` scalar calls |

## Functions to Vendor (Phase 0 Scope)

The following `survey` functions are needed for Phase 0 design types. Each must
be vendored with a per-function attribution comment:

```r
# Vendored from survey v[X.Y.Z]: survey/R/[source_file].R, function [name]()
```

### Taylor Series Linearization (survey_taylor)

- `svyCprod()` — core Taylor-series covariance of cluster totals
- Taylor-series variance for totals (`svytotal` internals)
- Taylor-series variance for means (`svymean` internals)
- FPC correction application
- Degrees-of-freedom calculation for complex designs

### Replicate Weights (survey_replicate)

- Replicate variance estimation core (BRR, JK1, JK2, JKn, bootstrap)
- Scale factor application per type
- Fay's modification for BRR
- `mse` vs. centered-replicates toggle

### Two-Phase Designs (survey_twophase)

*Vendored in Phase 0.75 — see "Two-Phase" table above.*

### Domain / Subpopulation Estimation

- Domain indicator application to linearized totals
- Domain variance from full-sample replicates

## Sync Strategy

When the `survey` package releases a new version:

1. Compare vendored functions against new source using `diff`
2. If statistical changes: update vendored code + re-run numerical validation
   tests (`test-variance-estimation.R`) to confirm equivalence within tolerance
3. Update the "survey version" column in the table above
4. Add a note to `NEWS.md` if the sync changes any numerical output

## Explicitly NOT Vendored

- `survey::svydesign()`, `survey::svrepdesign()` — surveycore defines its own S7 classes
- Any S3 method dispatch infrastructure from survey
- Any survey-specific print/summary methods
- Estimation functions (`svymean`, `svytotal`, etc.) — surveycore will implement
  its own estimation layer on top of vendored variance internals
