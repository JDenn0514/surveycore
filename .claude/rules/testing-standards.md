# surveycore Testing Standards

**Version:** 1.0
**Created:** February 2025
**Status:** Decided — do not re-litigate without updating this document

---

## Quick Reference

| Decision | Choice |
|----------|--------|
| Test file granularity | At least 1 file per source file; large source files may split |
| `test_that()` scope | One observable behavior per block |
| Nesting | Flat — no `describe()` blocks |
| Invariant checks | `test_invariants(design)` required in every block creating a survey object |
| Coverage target | 98%+ line coverage; PRs blocked below 95% |
| Test categories | Happy path + error paths (from error table) + edge cases |
| Private function testing | Default indirect; direct only when gap can't be closed via public API |
| Variance numerical tolerance | Point: 1e-10, SE/variance: 1e-8, CI bounds: 1e-6 (vs. `survey` package) |
| Constructor error testing | Dual: `expect_error(class=)` + `expect_snapshot(error=TRUE)` |
| S7 validator error testing | `class=` only (no snapshot — structural errors have no CLI message) |
| Snapshot failures | Block PRs; update via `snapshot_review()` before opening |
| Warning capture | `expect_warning()` wrapping call; result from return value |
| Structural assertions | `expect_identical()` |
| Numeric assertions | `expect_equal()` |
| Synthetic data | `make_survey_data(seed = N)` for unit tests |
| Real data use | nhanes_2017, acs_pums_wy for numerical validation only |
| Edge case data | Inline `data.frame()` |
| skip_if_not_installed | Block-level, inside affected `test_that()` blocks |

---

## 1. Test Structure

### Test file granularity
Every source file in `R/` has a corresponding test file in `tests/testthat/`. One-to-one is the floor, not the ceiling — large source files may split into multiple test files if it improves clarity.

| Source file | Test file(s) |
|-------------|--------------|
| `R/00-s7-classes.R` | `tests/testthat/test-s7-classes.R` |
| `R/01-metadata-system.R` | `tests/testthat/test-metadata-system.R` |
| `R/02-validators.R` | `tests/testthat/test-validators.R` |
| `R/03-constructors.R` | `tests/testthat/test-constructors.R` |
| `R/04-methods-print.R` | `tests/testthat/test-methods-print.R` |
| `R/05-methods-conversion.R` | `tests/testthat/test-conversion.R` |
| `R/06-variance-estimation.R` | `tests/testthat/test-variance-estimation.R` |
| `R/07-utils.R` | (covered inline by other test files) |
| `R/08-update-design.R` | `tests/testthat/test-update-design.R` |

### One behavior per `test_that()` block
Each `test_that()` description names one observable behavior. The description is a present-tense assertion, not a vague category.

```r
# Correct — specific, present-tense assertion
test_that("as_survey() rejects data frames with 0 rows", { ... })
test_that("as_survey() assigns ..surveycore_wt.. when no weights given", { ... })
test_that("as_survey() sets probs_provided = FALSE when weights given", { ... })

# Wrong — vague category (multiple behaviors inside one block)
test_that("as_survey() validates input", { ... })
test_that("weights work", { ... })
```

### No `describe()` blocks
Use flat `test_that()` throughout. Do not nest `test_that()` inside `describe()`. The test file name already provides the grouping context.

```r
# Correct — flat structure
test_that("survey_taylor stores weights column name", { ... })
test_that("survey_taylor stores strata column name", { ... })

# Wrong — nested describe
describe("survey_taylor properties", {
  test_that("stores weights column name", { ... })
})
```

### `test_invariants()` in every constructor test
Every `test_that()` block that creates a survey object via `as_survey()`, `as_survey_rep()`, or `as_survey_twophase()` must call `test_invariants(design)` as its first assertion.

```r
test_that("as_survey() creates a survey_taylor object for stratified design", {
  d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtmec2yr, strata = sdmvstra)
  test_invariants(d)   # <-- always first
  expect_true(S7::inherits(d, survey_taylor))
  expect_equal(d@variables$strata, "sdmvstra")
})
```

`test_invariants()` is defined in `tests/testthat/helper-test-data.R`. See Section 4 for its implementation.

---

## 2. What to Test

### Coverage target
**98%+ line coverage** is the project target. PRs that drop coverage below **95%** are blocked by CI.

Lines excluded from coverage are marked with `# nocov` and require an explanatory comment on the preceding line:

```r
# nocov start
# Defensive: this branch can only be reached by direct @-access, not
# via any public function. Tested implicitly by all constructor tests.
if (is.null(x@data)) {
  cli::cli_abort("Internal error: @data is NULL", class = "surveycore_error_internal")
}
# nocov end
```

Acceptable `# nocov` categories:
- Defensive branches for conditions impossible via public API
- Platform-specific paths (e.g., Windows-only file encoding)
- Explicit non-goals documented in the formal specification

Unacceptable `# nocov` use:
- Covering for missing tests (add the test instead)
- Error messages that "feel hard to trigger" (find the trigger and test it)

### Three mandatory test categories
Every source function must have tests in all three categories:

**1. Happy path** — normal inputs, expected behavior:
```r
test_that("as_survey() creates survey_taylor for NHANES stratified cluster design", {
  d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtmec2yr, strata = sdmvstra)
  test_invariants(d)
  expect_true(S7::inherits(d, survey_taylor))
})
```

**2. Error paths** — every row in `plans/error-messages.md` covered:
```r
test_that("as_survey() rejects non-data-frame input", {
  expect_snapshot(error = TRUE, as_survey(list(x = 1)))
  expect_error(as_survey(list(x = 1)), class = "surveycore_error_not_data_frame")
})
```

**3. Edge cases** — boundary conditions, NAs, empty inputs, single-row inputs:
```r
test_that("as_survey() warns for single-row data", {
  d1 <- data.frame(x = 1, w = 1)
  expect_warning(
    as_survey(d1, weights = w),
    class = "surveycore_warning_single_row"
  )
})
```

### Testing private functions
Default to **indirect testing** — exercise private helpers via the public functions that call them. Only write direct tests for a private function when coverage cannot be achieved indirectly AND the behavior is material.

```r
# Indirect (preferred) — .validate_weights() is tested via as_survey()
test_that("as_survey() rejects non-positive weights", {
  df <- data.frame(x = 1:5, w = c(1, 0, 1, 1, 1))
  expect_error(as_survey(df, weights = w), class = "surveycore_error_weights_nonpositive")
})

# Direct (only if necessary) — if a validator has a code path unreachable via any constructor
test_that(".validate_fpc() rejects NA in fpc column [direct]", {
  df <- data.frame(y = 1, fpc = NA_real_)
  expect_error(.validate_fpc(df, "fpc"), class = "surveycore_error_fpc_na")
})
```

### Variance estimation: numerical comparison
`test-variance-estimation.R` contains dedicated numerical validation comparing survey estimates against the `survey` package. Tolerances are strict and fixed.

| Estimand | Tolerance |
|----------|-----------|
| Point estimates (mean, total, proportion) | 1e-10 |
| SE / variance | 1e-8 |
| CI bounds | 1e-6 |

```r
test_that("svymean equivalent for NHANES systolic blood pressure [Taylor]", {
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

---

## 3. Assertions

### Constructor error testing: dual pattern
Layer 3 constructor errors (user input validation in `03-constructors.R`) require two assertions:

```r
test_that("as_survey() rejects weight column with zero values", {
  df <- data.frame(x = 1:5, w = c(1, 0, 1, 1, 1))

  # 1. Typed class check — verifies the right error class is thrown
  expect_error(
    as_survey(df, weights = w),
    class = "surveycore_error_weights_nonpositive"
  )

  # 2. Snapshot — verifies the CLI message text has not changed
  expect_snapshot(error = TRUE, as_survey(df, weights = w))
})
```

Layer 1 S7 validator errors (structural invariants in `00-s7-classes.R`) use `class=` only. No snapshot, because S7 validator messages are not CLI-formatted:

```r
test_that("survey_taylor validator rejects missing weights column in @variables", {
  # This can only be triggered via direct construction, not via as_survey()
  expect_error(
    survey_taylor(data = data.frame(x = 1), variables = list(weights = NULL)),
    class = "surveycore_error_weights_column_absent"
  )
})
```

### Snapshots: blocking and updating
Snapshot failures block PRs. They are not auto-updated — they represent deliberate decisions about error message text.

To update snapshots after an intentional message change:
```r
testthat::snapshot_review()  # review and approve each diff individually
```

Never run `testthat::snapshot_accept()` blindly. Each snapshot change must be reviewed.

Snapshots live in `tests/testthat/_snaps/`. They are committed to version control.

### Warning capture pattern
Use `expect_warning()` wrapping the call. Capture the return value from the function call separately if needed:

```r
test_that("as_survey() warns and returns object for single-row data", {
  d1 <- data.frame(x = 1, w = 1)

  # Capture warning
  expect_warning(
    result <- as_survey(d1, weights = w),
    class = "surveycore_warning_single_row"
  )

  # Assert on result separately
  test_invariants(result)
  expect_true(S7::inherits(result, survey_taylor))
})
```

Do **not** use `withCallingHandlers()` or `tryCatch()` in tests — `expect_warning()` is sufficient and produces cleaner test output.

### `expect_identical()` vs `expect_equal()`

| Use `expect_identical()` for... | Use `expect_equal()` for... |
|---------------------------------|------------------------------|
| Column names (`character` vectors) | Weighted means, totals, proportions |
| Class membership (`logical`) | Standard errors and variances |
| `NULL` and `NA` values | Confidence interval bounds |
| S7 property values that are exact (strings, integers) | Any floating-point output |
| List structure (keys present/absent) | Survey weights after normalization |

```r
# Structural — identical
expect_identical(d@variables$strata, "sdmvstra")
expect_identical(names(d@variables), c("ids", "weights", "strata", "fpc", "nest", "probs_provided"))
expect_identical(d@variables$fpc, NULL)

# Numeric — equal with tolerance
expect_equal(sc_est$mean, sv_est_mean, tolerance = 1e-10)
expect_equal(d@data[["..surveycore_wt.."]], rep(1, nrow(d@data)))  # uniform SRS weights
```

---

## 4. Test Data

### `make_survey_data()` — synthetic data generator
Defined in `tests/testthat/helper-test-data.R`. Used for all unit tests that need a survey object.

**Signature:**
```r
make_survey_data <- function(
  n        = 500,    # total rows
  n_psu    = 50,     # number of PSUs
  n_strata = 5,      # number of strata
  design   = c("taylor", "replicate", "twophase"),
  type     = "BRR",  # replicate type when design = "replicate"
  with_labels = FALSE,  # attach haven-style label attributes
  seed     = 42      # random seed for reproducibility
) { ... }
```

**Data properties:**
- PSU sizes vary (Poisson-distributed, not equal)
- Weights vary (lognormal, not uniform)
- Strata sizes are imbalanced
- Includes 3 numeric outcome variables (`y1`, `y2`, `y3`)
- Design columns: `psu`, `strata`, `fpc`, `weight`; replicate columns: `repwt_1` ... `repwt_R`
- Returns a plain `data.frame` (not a survey object)

```r
# Usage
df <- make_survey_data(n = 200, n_psu = 20, n_strata = 4, seed = 123)
d  <- as_survey(df, ids = psu, weights = weight, strata = strata, fpc = fpc)
test_invariants(d)
```

**Policy: synthetic data for unit tests; real data for numerical validation only**

| Test type | Data source |
|-----------|-------------|
| Unit tests (correct class, correct properties, error conditions) | `make_survey_data()` |
| Numerical accuracy vs. `survey` package | `nhanes_2017`, `acs_pums_wy` |
| Label/metadata roundtrip tests | `make_survey_data(with_labels = TRUE)` |

Never use `nhanes_2017` in a test that doesn't actually need its specific design variables or to compare numeric outputs. Synthetic data makes tests faster and removes internet/data dependency.

### `test_invariants()` — formal invariant checker
Also defined in `helper-test-data.R`. Asserts all 5 formal invariants from the Phase 0 specification.

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

### `skip_if_not_installed()` — block-level, not file-level
Place `skip_if_not_installed()` inside the `test_that()` block that actually requires the external package. Do not put a file-level skip at the top of a test file, because other blocks in the same file may not require it.

```r
# Correct — block-level
test_that("Taylor variance matches survey::svymean for NHANES [numerical]", {
  skip_if_not_installed("survey")
  # ...
})

test_that("as_survey() creates survey_taylor with correct class [no external dep]", {
  # This test runs even without survey installed
  d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtmec2yr, strata = sdmvstra)
  expect_true(S7::inherits(d, survey_taylor))
})

# Wrong — file-level (would skip the second test unnecessarily)
skip_if_not_installed("survey")  # at top of file
```

Packages that require `skip_if_not_installed()`:
- `survey` — numerical comparison tests in `test-variance-estimation.R`
- `srvyr` — conversion roundtrip tests in `test-conversion.R`
- `haven` — metadata roundtrip tests (haven writes `.xpt`; use `with_labels = TRUE` instead when possible)

### Edge case data: inline `data.frame()`
Edge cases requiring specific, atypical structure are constructed inline in the test. Do not extend `make_survey_data()` with edge case parameters.

```r
# Correct — inline, self-documenting
test_that("as_survey() rejects data with 0 rows", {
  empty_df <- data.frame(x = numeric(0), w = numeric(0))
  expect_error(as_survey(empty_df, weights = w), class = "surveycore_error_empty_data")
})

test_that("as_survey() warns when only 1 row", {
  single_row <- data.frame(x = 42, w = 1)
  expect_warning(
    as_survey(single_row, weights = w),
    class = "surveycore_warning_single_row"
  )
})

test_that("as_survey() rejects data where all weights are zero", {
  df <- data.frame(x = 1:3, w = c(0, 0, 0))
  expect_error(as_survey(df, weights = w), class = "surveycore_error_weights_all_zero")
})

# Wrong — adding special-case parameters to make_survey_data()
df <- make_survey_data(edge = "single_row", seed = 1)  # don't do this
```

The rule: if the edge case needs exact specific values to trigger, write those values directly. `make_survey_data()` generates typical survey data; edge cases are by definition atypical.

---

## 5. Test File Templates

### Error path coverage map
Each test file covers specific rows from `plans/error-messages.md`. The coverage map is maintained in `plans/error-messages.md` — not duplicated here.

### `test-constructors.R` structure
```
# 1. Happy paths (one block per design type per constructor)
# 2. Error paths (one block per error-messages.md row; see coverage map)
# 3. Edge cases (1-row data, NAs in outcomes, single stratum, etc.)
# 4. Tidy-select interface (bare names, c(), everything(), etc.)
# 5. Roundtrip (as_survey() |> update_design() returns valid object)
```

### `test-validators.R` structure
```
# 1. Happy paths (validators return invisible(TRUE) on valid input)
# 2. Error paths (Layer 2 validators; each error class covered)
# 3. Direct tests for branches unreachable via constructors
```

### `test-variance-estimation.R` structure
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
