# Vendored Code Tracking

This file documents all code vendored from external packages into surveycore.
It exists to support GPL-3 license compliance and to make upstream sync auditable.

## License Context

surveycore is licensed under GPL-3. Variance estimation code is vendored from the
`survey` package by Thomas Lumley, licensed under GPL-2 | GPL-3. Vendoring
GPL-2/GPL-3 code into a GPL-3 package is compliant with both licenses.

## Attribution Header (required in R/06-variance-estimation.R)

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

> **Status:** Not yet vendored. This table will be populated when Phase 0 Step 9
> (Variance Estimation) begins.

| Function name | Source file in `survey` | survey version | Approx. lines | Modified? | Notes |
|---------------|------------------------|----------------|---------------|-----------|-------|
| *(to be filled)* | *(to be filled)* | *(to be filled)* | *(to be filled)* | *(to be filled)* | *(to be filled)* |

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

- Phase 2 variance component (method = "full", "approx", "simple")
- Phase 1 + Phase 2 variance combination

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
