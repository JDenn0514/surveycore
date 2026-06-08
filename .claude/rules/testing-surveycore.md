# surveycore Testing: Package-Specific Standards

**Version:** 1.0
**Created:** February 2025
**Status:** Decided — do not re-litigate without updating this document

Extends [testing-standards.md](testing-standards.md). Read that document
first; this file covers only what is specific to surveycore.

---

## Quick Reference

| Decision | Choice |
|----------|--------|
| Invariant checks | `test_invariants(design)` required as **first** assertion in every constructor test block |
| Layer 1 errors (S7 validators) | `class=` only — no snapshot |
| Layer 3 errors (constructors) | Dual: `expect_error(class=)` + `expect_snapshot(error=TRUE)` |
| Variance numerical tolerance | Point: 1e-10, SE/variance: 1e-8, CI bounds: 1e-6 |
| Synthetic data | `make_survey_data(seed = N)` in `helper-test-data.R` |
| Real data | `nhanes_2017`, `acs_pums_wy` for numerical validation only |

---

## File mapping

Core source-to-test mapping. Analysis files (`R/analysis-*.R`) follow the same
one-to-one convention — `R/analysis-means.R` → `tests/testthat/test-analysis-means.R`, etc.

| Source file | Test file |
|-------------|-----------|
| `R/core-classes.R` | `tests/testthat/test-s7-classes.R` |
| `R/core-metadata.R` | `tests/testthat/test-metadata-system.R` |
| `R/core-validators.R` | `tests/testthat/test-validators.R` |
| `R/core-constructors.R` | `tests/testthat/test-constructors.R` |
| `R/methods-print.R` | `tests/testthat/test-methods-print.R` |
| `R/methods-conversion.R` | `tests/testthat/test-conversion.R` |
| `R/variance-taylor.R` | `tests/testthat/test-variance-taylor.R` |
| `R/variance-replicate.R` | `tests/testthat/test-variance-replicate.R` |
| `R/variance-twophase.R` | `tests/testthat/test-variance-twophase.R` |
| `R/utils.R` | `tests/testthat/test-utils.R` |
| `R/update-design.R` | `tests/testthat/test-update-design.R` |

---

## `test_invariants()` — required in every constructor test

Every `test_that()` block that creates a survey object via `as_survey()`,
`as_survey_rep()`, or `as_survey_twophase()` must call `test_invariants(design)`
as its **first** assertion.

```r
test_that("as_survey() creates a survey_taylor object for stratified design", {
  d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtmec2yr, strata = sdmvstra)
  test_invariants(d)   # always first
  expect_true(S7::inherits(d, survey_taylor))
  expect_equal(d@variables$strata, "sdmvstra")
})
```

`test_invariants()` is defined in `tests/testthat/helper-test-data.R` and
asserts all five formal Phase 0 invariants:

```r
test_invariants <- function(design) {
  # Invariant 1: @data is a data.frame
  expect_true(is.data.frame(design@data))

  # Invariant 2: @data has >= 1 row
  expect_gte(nrow(design@data), 1L)

  # Invariant 3: all @variables keys present (never absent, may be NULL)
  expected_keys <- c("ids", "weights", "strata", "fpc", "nest", "probs_provided")
  expect_true(all(expected_keys %in% names(design@variables)))

  # Invariant 4: named design columns exist in @data
  design_cols <- c(
    design@variables$ids,
    design@variables$weights,
    design@variables$strata,
    design@variables$fpc
  )
  present <- design_cols[!is.null(design_cols)]
  expect_true(all(present %in% names(design@data)))

  # Invariant 5: @metadata is a survey_metadata object
  expect_true(S7::inherits(design@metadata, survey_metadata))
}
```

---

## S7 error testing layers

surveycore has two validation layers with different testing requirements:

**Layer 1 — S7 class validators** (`R/00-s7-classes.R`): structural invariants
enforced by the S7 system. Messages are not CLI-formatted. Test with `class=`
only — no snapshot.

```r
test_that("survey_taylor validator rejects missing weights column in @variables", {
  expect_error(
    survey_taylor(data = data.frame(x = 1), variables = list(weights = NULL)),
    class = "surveycore_error_weights_column_absent"
  )
})
```

**Layer 3 — Constructor input validation** (`R/03-constructors.R`): user-facing
errors from `cli::cli_abort()`. Test with the dual pattern.

```r
test_that("as_survey() rejects weight column with zero values", {
  df <- data.frame(x = 1:5, w = c(1, 0, 1, 1, 1))

  expect_error(
    as_survey(df, weights = w),
    class = "surveycore_error_weights_nonpositive"
  )
  expect_snapshot(error = TRUE, as_survey(df, weights = w))
})
```

---

## `make_survey_data()` — synthetic data generator

Defined in `tests/testthat/helper-test-data.R`. Use for all unit tests that
need a survey design object.

```r
make_survey_data <- function(
  n           = 500,    # total rows
  n_psu       = 50,     # number of PSUs
  n_strata    = 5,      # number of strata
  design      = c("taylor", "replicate", "twophase"),
  type        = "BRR",  # replicate type when design = "replicate"
  with_labels = FALSE,  # attach haven-style label attributes
  seed        = 42
) { ... }
```

Data properties: PSU sizes vary (Poisson), weights vary (lognormal), strata
sizes imbalanced. Returns a plain `data.frame` with columns `psu`, `strata`,
`fpc`, `wt`, `y1`, `y2`, `y3`; replicate designs add `repwt_1`...`repwt_R`.

```r
df <- make_survey_data(n = 200, n_psu = 20, n_strata = 4, seed = 123)
d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
test_invariants(d)
```

**Data policy:**

| Test type | Data source |
|-----------|-------------|
| Unit tests (class, properties, error conditions) | `make_survey_data()` |
| Numerical accuracy vs. `survey` package | `nhanes_2017`, `acs_pums_wy` |
| Label/metadata roundtrip tests | `make_survey_data(with_labels = TRUE)` |

---

## Variance estimation numerical tolerances

Tests in `test-variance-estimation.R` compare surveycore estimates against
the `survey` package.

| Estimand | Tolerance |
|----------|-----------|
| Point estimates (mean, total, proportion) | `1e-10` |
| SE / variance | `1e-8` |
| CI bounds | `1e-6` |

```r
test_that("Taylor variance matches survey::svymean for NHANES [numerical]", {
  skip_if_not_installed("survey")
  d_sc <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtmec2yr, strata = sdmvstra)
  d_sv <- survey::svydesign(
    ids = ~sdmvpsu, weights = ~wtmec2yr, strata = ~sdmvstra,
    data = nhanes_2017, nest = TRUE
  )
  sc_est <- get_means(d_sc, bpxsy1)
  sv_est <- survey::svymean(~bpxsy1, d_sv, na.rm = TRUE)
  expect_equal(sc_est$mean, coef(sv_est)[["bpxsy1"]], tolerance = 1e-10)
  expect_equal(sc_est$se,   SE(sv_est)[["bpxsy1"]],   tolerance = 1e-8)
})
```

Packages requiring `skip_if_not_installed()`:
- `survey` — numerical comparison tests in `test-variance-estimation.R`
- `srvyr` — conversion roundtrip tests in `test-conversion.R`
- `haven` — metadata roundtrip tests (prefer `with_labels = TRUE` when possible)

---

## Test file section templates

### `test-constructors.R`
```
# 1. Happy paths (one block per design type per constructor)
# 2. Error paths (one block per error-messages.md row)
# 3. Edge cases (1-row data, NAs in outcomes, single stratum, etc.)
# 4. Tidy-select interface (bare names, c(), everything(), etc.)
# 5. Roundtrip (as_survey() |> update_design() returns valid object)
```

### `test-validators.R`
```
# 1. Happy paths (validators return invisible(TRUE) on valid input)
# 2. Error paths (Layer 2 validators; each error class covered)
# 3. Direct tests for branches unreachable via constructors
```

### `test-variance-estimation.R`
```
# Block 1: Taylor series — nhanes_2017
#   skip_if_not_installed("survey")
#   One test per estimand: mean, total, proportion
#   Tolerance: 1e-10 (point), 1e-8 (SE)

# Block 2: BRR replicates — acs_pums_wy
#   skip_if_not_installed("survey")
#   One test per estimand

# Block 3: Two-phase — synthetic (make_survey_data(design = "twophase"))
#   skip_if_not_installed("survey")
#   One test per estimand
```
