# Testing Standards — Worked Examples and Templates

Detail moved out of `.claude/rules/testing-standards.md` and
`.claude/rules/testing-surveycore.md`. The rules live there; this file shows
how to apply them. Read this when writing new test files and the correct
pattern is not obvious from the rule tables.

---

## Test structure examples

### `test_that()` descriptions

```r
# Correct — specific, present-tense assertion
test_that("my_fn() rejects data frames with 0 rows", { ... })
test_that("my_fn() assigns a default weight when none is given", { ... })

# Wrong — vague category
test_that("my_fn() validates input", { ... })
test_that("weights work", { ... })
```

### No `describe()` blocks

```r
# Correct
test_that("my_class stores the x property", { ... })
test_that("my_class stores the y property", { ... })

# Wrong
describe("my_class properties", {
  test_that("stores x", { ... })
})
```

### `# nocov` marking

```r
# nocov start
# Defensive: this branch is unreachable via any public function.
# Tested implicitly by all constructor tests.
if (is.null(x@data)) {
  cli::cli_abort("Internal error: @data is NULL", class = "mypkg_error_internal")
}
# nocov end
```

---

## The three mandatory test categories

**1. Happy path** — normal inputs, expected behavior:

```r
test_that("my_fn() creates the right class for standard input", {
  result <- my_fn(data, weights = w)
  expect_true(inherits(result, "my_class"))
})
```

**2. Error paths** — every typed error class from the package's error table:

```r
test_that("my_fn() rejects non-data-frame input", {
  expect_snapshot(error = TRUE, my_fn(list(x = 1)))
  expect_error(my_fn(list(x = 1)), class = "mypkg_error_not_data_frame")
})
```

**3. Edge cases** — boundary conditions, NAs, empty inputs, single-row inputs:

```r
test_that("my_fn() warns for single-row data", {
  single_row <- data.frame(x = 1, w = 1)
  expect_warning(
    my_fn(single_row, weights = w),
    class = "mypkg_warning_single_row"
  )
})
```

---

## Private function testing

```r
# Indirect (preferred) — .validate_weights() tested via the public API
test_that("my_fn() rejects non-positive weights", {
  df <- data.frame(x = 1:5, w = c(1, 0, 1, 1, 1))
  expect_error(my_fn(df, weights = w), class = "mypkg_error_weights_nonpositive")
})

# Direct (only when necessary)
test_that(".validate_fpc() rejects NA in fpc column [direct]", {
  df <- data.frame(y = 1, fpc = NA_real_)
  expect_error(.validate_fpc(df, "fpc"), class = "mypkg_error_fpc_na")
})
```

---

## Dual pattern for constructor errors

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

Layer 1 (S7 class validators, `R/00-s7-classes.R`) uses `class=` only — no
snapshot — because those messages are not CLI-formatted:

```r
test_that("survey_taylor validator rejects missing weights column in @variables", {
  expect_error(
    survey_taylor(data = data.frame(x = 1), variables = list(weights = NULL)),
    class = "surveycore_error_weights_column_absent"
  )
})
```

---

## Warning capture pattern

```r
test_that("my_fn() warns and still returns an object for single-row data", {
  d1 <- data.frame(x = 1, w = 1)

  expect_warning(
    result <- my_fn(d1, weights = w),
    class = "mypkg_warning_single_row"
  )

  expect_true(inherits(result, "my_class"))
})
```

Do **not** use `withCallingHandlers()` or `tryCatch()` in tests.

---

## Test data examples

### Generator usage

```r
df <- make_survey_data(n = 200, n_psu = 20, n_strata = 4, seed = 123)
d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
test_invariants(d)
```

### Edge case data: inline, never via generator parameters

```r
# Correct — inline, self-documenting
test_that("my_fn() rejects data with 0 rows", {
  empty_df <- data.frame(x = numeric(0), w = numeric(0))
  expect_error(my_fn(empty_df, weights = w), class = "mypkg_error_empty_data")
})

# Wrong
df <- make_pkg_data(edge = "empty", seed = 1)  # don't do this
```

### `skip_if_not_installed()` — block-level

```r
# Correct — block-level
test_that("estimates match reference package [numerical]", {
  skip_if_not_installed("ref_pkg")
  # ...
})

test_that("constructor creates correct class", {
  # runs even without ref_pkg installed
  d <- my_fn(data, weights = w)
  expect_true(inherits(d, "my_class"))
})

# Wrong — skips the entire file
skip_if_not_installed("ref_pkg")  # at top of file
```

---

## surveycore numerical validation example

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

Constructor test with invariants first:

```r
test_that("as_survey() creates a survey_taylor object for stratified design", {
  d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtmec2yr, strata = sdmvstra)
  test_invariants(d)   # always first
  expect_true(S7::inherits(d, survey_taylor))
  expect_equal(d@variables$strata, "sdmvstra")
})
```

---

## surveycore test file section templates

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

### Snapshot updating

To update snapshots after an intentional message change:

```r
testthat::snapshot_review()  # review and approve each diff individually
```

Never run `testthat::snapshot_accept()` blindly. Each snapshot change must
be reviewed. Snapshots live in `tests/testthat/_snaps/` and are committed.
