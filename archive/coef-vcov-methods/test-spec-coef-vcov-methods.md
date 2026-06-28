# Test Spec: coef(), vcov(), SE(), and confint() Methods for survey_result Objects

**Version:** 1.3
**Date:** 2026-06-22
**Status:** SPEC_READY

---

## Document Purpose

This is the validation source of truth for the `coef()`, `vcov()`, `SE()`,
and `confint()` methods on surveycore result objects. Tester implements from
this document only. No production file paths or internal helper names appear
here.

---

## Reference Oracle

| Oracle function | Usage |
|---|---|
| `survey::svymean()` | Reference for point estimate and SE in numerical comparison tests |
| `survey::svytotal()` | Reference for total estimates |
| `survey::svyby()` | Reference for grouped estimates and coef/vcov output shape |
| `survey::SE()` | Reference for SE extraction from survey objects |
| `survey::vcov.svystat()` | Reference for vcov on ungrouped survey statistics |
| `survey::vcov.svyby()` | Reference for vcov on grouped survey statistics (block-diagonal) |
| `survey::confint.svystat()` | Reference for CI computation with t-distribution |
| `stats::confint.lm()` | Reference for `confint()` output format (2-column matrix, column name convention) |

---

## Datasets

| Test type | Dataset |
|---|---|
| Unit tests — class, structure, error conditions | `make_survey_data()` from `helper-test-data.R` |
| Numerical oracle tests — Taylor designs | `nhanes_2017` |
| Numerical oracle tests — replicate designs | `acs_pums_wy` |
| Edge case data | Inline; never added to data generators |

---

## Tolerances

| Estimand | Tolerance |
|---|---|
| Point estimates | `1e-10` |
| SE / variance | `1e-8` |
| CI bounds | `1e-6` |

Any deviation from these tolerances requires written justification in the test
comment.

---

## Profile Gates

The following gates must pass before any PR in this feature is merged:

- [ ] `devtools::document()` — NAMESPACE and man/ files generated cleanly
- [ ] `devtools::test()` — all tests pass, zero failures, zero warnings
- [ ] `devtools::run_examples()` — all examples in new file run without error
- [ ] `R CMD check --as-cran` — 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `pkgcheck::pkgcheck()` — passes all automated checks
- [ ] `pkgdown::build_site()` — builds without error
- [ ] `covr::package_coverage()` — ≥ 98% line coverage on the new methods file

---

## Test File Map

New test file: `tests/testthat/test-analysis-methods-coef-vcov.R`

Existing files that need new test rows (one block each in the relevant test file):
- `tests/testthat/test-analysis-means.R` — one block confirming `.survey_result` attribute is attached
- `tests/testthat/test-analysis-totals.R` — one block confirming `.survey_result` attribute is attached
- `tests/testthat/test-analysis-freqs.R` — one block confirming `.survey_result` attribute is attached
- `tests/testthat/test-analysis-corr.R` — one block confirming long-format has attribute, wide does not

All main test work lives in `test-analysis-methods-coef-vcov.R`.

---

## Per-Function Test Plan

### 1. `.survey_result` attribute attachment

#### 1.1 Happy path — attribute present on supported result classes

One block per class confirming the attribute is attached after calling the
respective `get_*()` function. Each block:
1. Constructs a survey design with `make_survey_data()`.
2. Calls the `get_*()` function.
3. Asserts `!is.null(attr(result, ".survey_result"))`.
4. Asserts the attribute is a list.
5. Asserts the attribute has names `c("estimate_cols", "group_cols", "statistic", "df")`.
6. Asserts `attr(result, ".survey_result")$estimate_cols` matches the expected column name for that class (see table in test plan §1.2).
7. Asserts `attr(result, ".survey_result")$df` is a finite numeric scalar (Taylor) or `Inf` (replicate).

Classes to cover: `survey_means`, `survey_totals`, `survey_freqs`, `survey_ratios`,
`survey_quantiles`, `survey_corr` (long format), `survey_covariance`,
`survey_diffs`.

#### 1.2 estimate_cols correctness

| Result class | Expected `estimate_cols` | Expected `statistic` |
|---|---|---|
| `survey_means` | `c("mean")` | `"mean"` |
| `survey_totals` | `c("total")` | `"total"` |
| `survey_freqs` | `c("pct")` | `"freq"` |
| `survey_ratios` | `c("ratio")` | `"ratio"` |
| `survey_quantiles` | `c("estimate")` | `"quantile"` |
| `survey_corr` (long) | `c("r")` | `"corr"` |
| `survey_covariance` | `c("covariance")` | `"covariance"` |
| `survey_diffs` | `c("estimate")` | `"diffs"` |

#### 1.3 Wide-format corr does NOT get attribute

Construct a `survey_corr` in wide format. Assert `is.null(attr(result, ".survey_result"))`.

#### 1.4 df is Inf for replicate designs

```r
test_that(".survey_result$df is Inf for replicate designs", {
  df <- make_survey_data(design = "replicate", seed = 4)
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = tidyselect::starts_with("repwt_"),
    type = "BRR"
  )
  test_invariants(d)
  result <- get_means(d, y1)
  expect_true(all(is.infinite(attr(result, ".survey_result")$df)))
})
```

#### 1.5 df is finite for Taylor designs

```r
test_that(".survey_result$df is finite for Taylor designs", {
  df <- make_survey_data(design = "taylor", seed = 5)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  test_invariants(d)
  result <- get_means(d, y1)
  df_val <- attr(result, ".survey_result")$df
  expect_true(all(is.finite(df_val)))
  expect_true(all(df_val >= 1))
})
```

---

### 2. `SE()` generic

#### 2.1 SE generic exists and is exported

```r
test_that("SE() generic is exported and callable", {
  expect_true(existsMethod("SE") || is.function(surveycore::SE))
})
```

(Use whichever assertion form is natural — the point is that `surveycore::SE`
resolves without error.)

#### 2.2 SE.default delegates to sqrt(diag(vcov()))

Construct a simple linear model with `lm()`. Assert that
`surveycore::SE(mod)` equals `sqrt(diag(stats::vcov(mod)))` within `1e-15`.

This confirms `SE.default` works for non-survey objects.

#### 2.3 SE.survey_result returns named vector

Construct a Taylor design. Call `get_means()` with `variance = "se"`.
Assert:
1. `SE(result)` is a named numeric vector.
2. `names(SE(result))` equals `names(coef(result))`.
3. All values are non-negative (SE is a standard deviation).

#### 2.4 SE matches the `se` column (unit test)

The SE extracted via `SE(result)` must match `result$se` numerically.
Tolerance: `1e-10`.

```r
test_that("SE.survey_result() matches the se column", {
  df <- make_survey_data(seed = 7)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  result <- get_means(d, y1, variance = "se")
  expect_equal(unname(SE(result)), result$se, tolerance = 1e-10)
})
```

---

### 3. `coef.survey_result()`

#### 3.1 Ungrouped mean — name is variable name

```r
test_that("coef.survey_result() returns variable name for ungrouped mean", {
  df <- make_survey_data(seed = 1)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  test_invariants(d)
  result <- get_means(d, y1)
  cv <- coef(result)
  expect_true(is.numeric(cv))
  expect_equal(length(cv), 1L)
  expect_identical(names(cv), "y1")
})
```

#### 3.2 Grouped mean — group-major colon-separated names

Construct a grouped mean with 3 group levels. Assert:
1. `length(coef(result)) == 3`.
2. Each name is `"group_level:y1"`.
3. Order is group-major (A:y1, B:y1, C:y1 in factor level order).

#### 3.3 Freqs — names include level identifiers

Construct a `survey_freqs` result on a binary factor variable (2 levels).
Assert:
1. `length(coef(result)) == 2`.
2. Names are `"var.level1"` and `"var.level2"` (raw level values as strings).

#### 3.4 Quantiles — names include quantile labels

Construct `get_quantiles(d, y1, probs = c(0.25, 0.5, 0.75))`. Assert:
1. `length(coef(result)) == 3`.
2. Names are `"y1.p25"`, `"y1.p50"`, `"y1.p75"`.

#### 3.5 Grouped quantiles — group-major order

Construct grouped quantiles with 2 group levels and 3 probs. Assert:
1. `length(coef(result)) == 6`.
2. First 3 names: `"A:y1.p25"`, `"A:y1.p50"`, `"A:y1.p75"`.
3. Last 3 names: `"B:y1.p25"`, `"B:y1.p50"`, `"B:y1.p75"`.

#### 3.6 Corr (long format) — var1.var2 names

Construct `get_corr(d, c(y1, y2))`. Assert:
1. `length(coef(result)) == 1` (one pair by default in long format with default `redundant = FALSE, diagonal = FALSE`).
2. Name is `"y1.y2"`.

#### 3.7 Covariance — var1.var2 names

Construct `get_covariance(d, c(y1, y2))`. Assert:
1. Name is `"y1.y2"`.

#### 3.8 Diffs — treatment level names

Construct `get_diffs()` with a factor treatment having 3 levels. Assert:
1. `length(coef(result)) == 2` (two non-reference levels).
2. Names are the non-reference level labels.

#### 3.9 NA estimates propagate to coef

Construct a result with at least one `NA` estimate cell (use a domain filter
that produces `NA` for one group). Assert `NA_real_` is in the corresponding
position of `coef(result)`.

#### 3.10 Zero-row result

Construct a zero-row `survey_freqs` result (a variable that is all-NA with
`na.rm = TRUE`). Assert `length(coef(result)) == 0` and
`identical(names(coef(result)), character(0))`.

---

### 4. `vcov.survey_result()`

#### 4.1 Ungrouped vcov is a 1×1 matrix for single estimate

```r
test_that("vcov.survey_result() returns 1×1 matrix for ungrouped mean", {
  df <- make_survey_data(seed = 41)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  test_invariants(d)
  result <- get_means(d, y1, variance = "se")
  v <- vcov(result)
  expect_true(is.matrix(v))
  expect_equal(dim(v), c(1L, 1L))
  expect_identical(rownames(v), "y1")
  expect_identical(colnames(v), "y1")
  expect_equal(v[1, 1], result$se^2, tolerance = 1e-14)
})
```

#### 4.2 Grouped vcov is block-diagonal

Construct `get_means(d, y1, group = strata, variance = "se")`. Suppose there
are `k` strata groups. Assert:
1. `dim(vcov(result)) == c(k, k)`.
2. The diagonal equals `result$se^2` (within `1e-14`).
3. All off-diagonal elements are exactly `0`.

#### 4.3 dimnames match coef names exactly

Assert `identical(rownames(vcov(result)), names(coef(result)))` and
`identical(colnames(vcov(result)), names(coef(result)))`.
Test both grouped and ungrouped cases.

#### 4.4 vcov with no se column returns NA matrix

Construct `get_means(d, y1, variance = NULL)`. Assert:
1. `vcov(result)` is a matrix.
2. All elements are `NA_real_`.
3. Dimnames still correct.
4. No warning is emitted.

#### 4.5 vcov matches survey::vcov.svystat [numerical, Taylor]

```r
test_that("vcov.survey_result() matches survey::vcov.svystat for ungrouped mean [numerical]", {
  skip_if_not_installed("survey")
  d_sc <- as_survey(
    nhanes_2017,
    ids = sdmvpsu,
    weights = wtint2yr,
    strata = sdmvstra,
    nest = TRUE
  )
  test_invariants(d_sc)
  d_sv <- survey::svydesign(
    ids = ~sdmvpsu,
    weights = ~wtint2yr,
    strata = ~sdmvstra,
    data = nhanes_2017,
    nest = TRUE
  )
  sc_result <- get_means(d_sc, ridageyr, variance = "se")
  sv_stat <- survey::svymean(~ridageyr, d_sv, na.rm = TRUE)
  expect_equal(
    vcov(sc_result)[1, 1],
    as.numeric(survey::vcov(sv_stat)),
    tolerance = 1e-8
  )
})
```

#### 4.6 Grouped vcov matches survey::vcov.svyby [numerical, Taylor]

```r
test_that("vcov.survey_result() block-diagonal matches survey::vcov.svyby for grouped mean [numerical]", {
  skip_if_not_installed("survey")
  # Use nhanes_2017: group by riagendr (2 levels)
  d_sc <- as_survey(
    nhanes_2017,
    ids = sdmvpsu,
    weights = wtint2yr,
    strata = sdmvstra,
    nest = TRUE
  )
  test_invariants(d_sc)
  d_sv <- survey::svydesign(
    ids = ~sdmvpsu,
    weights = ~wtint2yr,
    strata = ~sdmvstra,
    data = nhanes_2017,
    nest = TRUE
  )
  sc_result <- get_means(d_sc, ridageyr, group = riagendr, variance = "se")
  sv_by <- survey::svyby(
    ~ridageyr,
    ~riagendr,
    d_sv,
    survey::svymean,
    na.rm = TRUE
  )
  sv_vcov <- survey::vcov(sv_by)
  sc_vcov <- vcov(sc_result)
  # Compare diagonal (per-group variances)
  expect_equal(diag(sc_vcov), diag(sv_vcov), tolerance = 1e-8)
  # Off-diagonal of surveycore is 0 (block-diagonal)
  expect_equal(sc_vcov[1, 2], 0)
  expect_equal(sc_vcov[2, 1], 0)
})
```

---

### 5. `SE.survey_result()`

#### 5.1 SE matches sqrt(diag(vcov())) [unit test]

Assert `identical(SE(result), sqrt(diag(vcov(result))))` for:
- Ungrouped `survey_means`
- Grouped `survey_means`
- `survey_totals`
- `survey_freqs`

#### 5.2 SE names match coef names

Assert `identical(names(SE(result)), names(coef(result)))`.

#### 5.3 SE matches survey::SE [numerical, Taylor]

```r
test_that("SE.survey_result() matches survey::SE for ungrouped mean [numerical]", {
  skip_if_not_installed("survey")
  d_sc <- as_survey(
    nhanes_2017,
    ids = sdmvpsu,
    weights = wtint2yr,
    strata = sdmvstra,
    nest = TRUE
  )
  test_invariants(d_sc)
  d_sv <- survey::svydesign(
    ids = ~sdmvpsu,
    weights = ~wtint2yr,
    strata = ~sdmvstra,
    data = nhanes_2017,
    nest = TRUE
  )
  sc_result <- get_means(d_sc, ridageyr, variance = "se")
  sv_stat <- survey::svymean(~ridageyr, d_sv, na.rm = TRUE)
  expect_equal(
    unname(SE(sc_result)),
    as.numeric(survey::SE(sv_stat)),
    tolerance = 1e-8
  )
})
```

#### 5.4 SE is NA when se column absent

Construct result with `variance = NULL`. Assert all `SE(result)` values are `NA_real_`.

---

### 6. `confint.survey_result()`

#### 6.1 Default call returns 2-column matrix

Construct `get_means(d, y1, variance = "se")`. Assert:
1. `confint(result)` is a matrix.
2. `ncol(confint(result)) == 2`.
3. `colnames(confint(result))` are `c("2.5 %", "97.5 %")`.
4. `rownames(confint(result))` equal `names(coef(result))`.

#### 6.2 CI column names reflect level argument

Assert `colnames(confint(result, level = 0.90))` are `c("5 %", "95 %")`.

#### 6.3 Taylor CI uses t-distribution (finite df)

For a Taylor design, `confint()` must use `qt()` with finite df. Verify:
1. `attr(result, ".survey_result")$df` is finite.
2. The CI width is wider than a normal-approximation CI for the same result.

Concretely: build the same result on a Taylor design (small number of PSUs)
and on a replicate design. Compare CI widths. Taylor CI (finite df) must be
wider when df is small.

#### 6.4 Replicate CI uses normal approximation (Inf df)

For a replicate design, `attr(result, ".survey_result")$df == Inf`. Assert that
`confint(result)` values match what you would get from `coef ± qnorm(0.975) * SE`
within `1e-10`.

#### 6.5 confint matches survey::confint.svystat [numerical, Taylor]

```r
test_that("confint.survey_result() matches survey::confint for ungrouped mean [numerical]", {
  skip_if_not_installed("survey")
  d_sc <- as_survey(
    nhanes_2017,
    ids = sdmvpsu,
    weights = wtint2yr,
    strata = sdmvstra,
    nest = TRUE
  )
  test_invariants(d_sc)
  d_sv <- survey::svydesign(
    ids = ~sdmvpsu,
    weights = ~wtint2yr,
    strata = ~sdmvstra,
    data = nhanes_2017,
    nest = TRUE
  )
  sc_result <- get_means(d_sc, ridageyr, variance = "se")
  sv_stat <- survey::svymean(~ridageyr, d_sv, na.rm = TRUE)
  sc_ci <- confint(sc_result, level = 0.95)
  sv_ci <- confint(sv_stat, level = 0.95)
  # surveycore uses finite df (Taylor); survey defaults to Inf — compare at Inf
  # Both should match when using normal approximation (survey default)
  expect_equal(unname(sc_ci[, 1]), unname(sv_ci[, 1]), tolerance = 1e-6)
  expect_equal(unname(sc_ci[, 2]), unname(sv_ci[, 2]), tolerance = 1e-6)
})
```

Note: `survey::confint.svystat` defaults to `df = Inf` (normal approximation)
unless `df` is passed explicitly. surveycore uses finite design df. These will
not match exactly for Taylor designs unless df is large. The test above uses
NHANES where df is large enough (≈14 strata × multiple PSUs) that the
t-quantile and normal quantile are indistinguishable at `1e-6`. If this
tolerance is too tight, relax to `1e-3` and add a comment explaining the df
difference.

#### 6.6 parm subsetting — by name

```r
test_that("confint.survey_result() respects parm subsetting by name", {
  df <- make_survey_data(n = 300, n_strata = 3, seed = 20)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  result <- get_means(d, y1, group = strata, variance = "se")
  # Only get CI for first group level
  first_name <- names(coef(result))[1]
  ci_sub <- confint(result, parm = first_name)
  expect_equal(nrow(ci_sub), 1L)
  expect_equal(rownames(ci_sub), first_name)
})
```

#### 6.7 parm subsetting — by integer index

Same setup as above. Assert `confint(result, parm = 1L)` returns a 1-row
matrix with rowname equal to `names(coef(result))[1]`.

#### 6.8 zero-row result — confint returns 0×2 matrix

Construct a zero-row freqs result. Assert:
1. `nrow(confint(result)) == 0`.
2. `ncol(confint(result)) == 2`.
3. No error is thrown.

#### 6.9 SE absent — confint returns NA

Construct result with `variance = NULL`. Assert all CI values are `NA_real_`.
No error, no warning.

#### 6.10 parm with NA elements — emits SCR-W3, drops NA

```r
test_that("confint.survey_result() emits surveycore_warning_parm_na and drops NA parm elements", {
  df <- make_survey_data(n = 300, n_strata = 3, seed = 610)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  result <- get_means(d, y1, group = strata, variance = "se")
  first_name <- names(coef(result))[1]
  expect_warning(
    ci <- confint(result, parm = c(first_name, NA_character_)),
    class = "surveycore_warning_parm_na"
  )
  expect_equal(nrow(ci), 1L)
  expect_equal(rownames(ci), first_name)
  expect_snapshot(
    warning = TRUE,
    confint(result, parm = c(first_name, NA_character_))
  )
})
```

#### 6.11 parm with some unmatched names — emits SCR-W4, drops unmatched

```r
test_that("confint.survey_result() emits surveycore_warning_parm_unmatched and drops unmatched names", {
  df <- make_survey_data(n = 300, n_strata = 3, seed = 611)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  result <- get_means(d, y1, group = strata, variance = "se")
  first_name <- names(coef(result))[1]
  expect_warning(
    ci <- confint(result, parm = c(first_name, "nonexistent_param")),
    class = "surveycore_warning_parm_unmatched"
  )
  expect_equal(nrow(ci), 1L)
  expect_equal(rownames(ci), first_name)
  expect_snapshot(
    warning = TRUE,
    confint(result, parm = c(first_name, "nonexistent_param"))
  )
})
```

#### 6.12 parm with ALL unmatched names — emits SCR-W4, returns 0×2 matrix

```r
test_that("confint.survey_result() returns 0x2 matrix when all parm names unmatched", {
  df <- make_survey_data(n = 300, n_strata = 3, seed = 612)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  result <- get_means(d, y1, group = strata, variance = "se")
  expect_warning(
    ci <- confint(result, parm = c("no_such_param", "also_missing")),
    class = "surveycore_warning_parm_unmatched"
  )
  expect_equal(nrow(ci), 0L)
  expect_equal(ncol(ci), 2L)
  expect_identical(colnames(ci), c("2.5 %", "97.5 %"))
  expect_identical(rownames(ci), character(0))
  expect_snapshot(
    warning = TRUE,
    confint(result, parm = c("no_such_param", "also_missing"))
  )
})
```

---

### 7. Error paths

#### 7.1 coef() on survey_t_test throws correct class

```r
test_that("coef.survey_result() throws surveycore_error_result_method_unsupported for survey_t_test", {
  gss_sub <- gss_2024[!is.na(gss_2024$age), ]
  gss_sub$sex <- factor(gss_sub$sex)
  d <- as_survey(
    gss_sub,
    ids = vpsu,
    weights = wtssps,
    strata = vstrat,
    nest = TRUE
  )
  test_invariants(d)
  result <- get_t_test(d, age, by = sex)
  expect_error(
    coef(result),
    class = "surveycore_error_result_method_unsupported"
  )
  expect_snapshot(error = TRUE, coef(result))
})
```

#### 7.2 coef() on survey_pairwise throws correct class

```r
test_that("coef.survey_result() throws surveycore_error_result_method_unsupported for survey_pairwise", {
  # construct survey_pairwise result
  # (reuse gss_sub from above setup, inline)
  d <- as_survey(
    gss_2024[!is.na(gss_2024$age), ],
    ids = vpsu,
    weights = wtssps,
    strata = vstrat,
    nest = TRUE
  )
  test_invariants(d)
  result <- get_pairwise(d, age, by = sex)
  expect_error(
    coef(result),
    class = "surveycore_error_result_method_unsupported"
  )
  expect_snapshot(error = TRUE, coef(result))
})
```

#### 7.3 vcov() on survey_t_test throws correct class

```r
test_that("vcov.survey_result() throws surveycore_error_result_method_unsupported for survey_t_test", {
  gss_sub <- gss_2024[!is.na(gss_2024$age), ]
  gss_sub$sex <- factor(gss_sub$sex)
  d <- as_survey(
    gss_sub,
    ids = vpsu,
    weights = wtssps,
    strata = vstrat,
    nest = TRUE
  )
  test_invariants(d)
  result <- get_t_test(d, age, by = sex)
  expect_error(
    vcov(result),
    class = "surveycore_error_result_method_unsupported"
  )
  expect_snapshot(error = TRUE, vcov(result))
})
```

#### 7.4 confint() invalid level

```r
test_that("confint.survey_result() rejects level outside (0, 1)", {
  df <- make_survey_data(seed = 3)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  test_invariants(d)
  result <- get_means(d, y1, variance = "se")
  expect_error(
    confint(result, level = 0),
    class = "surveycore_error_invalid_conf_level"
  )
  expect_snapshot(error = TRUE, confint(result, level = 0))
  expect_error(
    confint(result, level = 1),
    class = "surveycore_error_invalid_conf_level"
  )
  expect_snapshot(error = TRUE, confint(result, level = 1))
  expect_error(
    confint(result, level = 1.1),
    class = "surveycore_error_invalid_conf_level"
  )
  expect_snapshot(error = TRUE, confint(result, level = 1.1))
})
```

#### 7.5 coef() on result without .survey_result attribute throws correct class

```r
test_that("coef.survey_result() throws surveycore_error_result_method_unsupported when attribute absent", {
  df <- make_survey_data(seed = 5)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  test_invariants(d)
  result <- get_means(d, y1)
  attr(result, ".survey_result") <- NULL
  expect_error(
    coef(result),
    class = "surveycore_error_result_method_unsupported"
  )
  expect_snapshot(error = TRUE, coef(result))
})
```

#### 7.6 SE() on unsupported classes throws correct class

```r
test_that("SE.survey_result() throws surveycore_error_result_method_unsupported for survey_t_test", {
  gss_sub <- gss_2024[!is.na(gss_2024$age), ]
  gss_sub$sex <- factor(gss_sub$sex)
  d <- as_survey(
    gss_sub,
    ids = vpsu,
    weights = wtssps,
    strata = vstrat,
    nest = TRUE
  )
  test_invariants(d)
  result_t <- get_t_test(d, age, by = sex)
  expect_error(
    SE(result_t),
    class = "surveycore_error_result_method_unsupported"
  )
  expect_snapshot(error = TRUE, SE(result_t))
  result_p <- get_pairwise(d, age, by = sex)
  expect_error(
    SE(result_p),
    class = "surveycore_error_result_method_unsupported"
  )
})
```

#### 7.7 confint() on unsupported classes throws correct class

```r
test_that("confint.survey_result() throws surveycore_error_result_method_unsupported for survey_t_test", {
  gss_sub <- gss_2024[!is.na(gss_2024$age), ]
  gss_sub$sex <- factor(gss_sub$sex)
  d <- as_survey(
    gss_sub,
    ids = vpsu,
    weights = wtssps,
    strata = vstrat,
    nest = TRUE
  )
  test_invariants(d)
  result_t <- get_t_test(d, age, by = sex)
  expect_error(
    confint(result_t),
    class = "surveycore_error_result_method_unsupported"
  )
  expect_snapshot(error = TRUE, confint(result_t))
  result_p <- get_pairwise(d, age, by = sex)
  expect_error(
    confint(result_p),
    class = "surveycore_error_result_method_unsupported"
  )
})
```

#### 7.8 vcov() and SE() and confint() on survey_pairwise

```r
test_that("vcov/SE/confint throw for survey_pairwise", {
  d <- as_survey(
    gss_2024[!is.na(gss_2024$age), ],
    ids = vpsu,
    weights = wtssps,
    strata = vstrat,
    nest = TRUE
  )
  test_invariants(d)
  result <- get_pairwise(
    d,
    age,
    by = factor(gss_2024$sex[!is.na(gss_2024$age)])
  )
  expect_error(
    vcov(result),
    class = "surveycore_error_result_method_unsupported"
  )
  expect_error(SE(result), class = "surveycore_error_result_method_unsupported")
  expect_error(
    confint(result),
    class = "surveycore_error_result_method_unsupported"
  )
})
```

#### 7.9 vcov(), SE(), confint() with absent attribute

```r
test_that("vcov/SE/confint throw when .survey_result attribute absent", {
  df <- make_survey_data(seed = 79)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  test_invariants(d)
  result <- get_means(d, y1, variance = "se")
  attr(result, ".survey_result") <- NULL
  expect_error(
    vcov(result),
    class = "surveycore_error_result_method_unsupported"
  )
  expect_snapshot(error = TRUE, vcov(result))
  expect_error(SE(result), class = "surveycore_error_result_method_unsupported")
  expect_error(
    confint(result),
    class = "surveycore_error_result_method_unsupported"
  )
  expect_snapshot(error = TRUE, confint(result))
})
```

#### 7.10 confint() with invalid df (SCR-3)

```r
test_that("confint.survey_result() throws surveycore_error_invalid_df for df <= 0", {
  df <- make_survey_data(seed = 710)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  test_invariants(d)
  result <- get_means(d, y1, variance = "se")
  attr(result, ".survey_result")$df <- -1L
  expect_error(
    confint(result),
    class = "surveycore_error_invalid_df"
  )
  expect_snapshot(error = TRUE, confint(result))
})
```

---

### 8. Edge cases

#### 8.1 Single-group result (one group level)

Construct a design where the strata variable has only one level. Run
`get_means(d, y1, group = strata)` and suppress `surveycore_warning_single_level`.
Assert:
1. `coef(result)` has length 1.
2. `vcov(result)` is a 1×1 matrix.
3. `confint(result)` is a 1×2 matrix.
4. `expect_equal(length(SE(result)), 1L)`.

#### 8.2 All estimates NA

Construct a domain with all-NA `y1` values. Run `get_means()`. Assert:
1. `coef(result)` has a single element equal to `NA_real_`.
2. `vcov(result)` is a 1×1 NA matrix.
3. `confint(result)` is a 1×2 NA matrix.
4. No error is thrown.

#### 8.3 Totals with no variable (population size mode)

```r
test_that("coef.survey_result() uses 'N' as name for get_totals() no-variable mode", {
  df <- make_survey_data(seed = 8)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  result <- get_totals(d, variance = "se")
  cv <- coef(result)
  expect_identical(names(cv), "N")
})
```

#### 8.4 get_corr() wide format — coef throws error

Construct a wide-format corr result (pass `format = "wide"` or the equivalent).
Assert `coef(result)` throws `surveycore_error_result_method_unsupported`.

#### 8.5 df value propagates to confint for small designs

Construct a Taylor design with very few PSUs (e.g., 4 PSUs, 2 strata → df = 2).
Assert:
1. `attr(result, ".survey_result")$df == 2`.
2. `confint(result)` bounds differ from a normal-approximation CI (the t-critical
   value at df=2, alpha=0.025 is 4.303; for normal it is 1.96).

```r
test_that("confint.survey_result() uses finite design df for Taylor designs", {
  small_df <- data.frame(
    psu = c(1, 1, 2, 2, 3, 3, 4, 4),
    strata = c(1, 1, 1, 1, 2, 2, 2, 2),
    wt = rep(100, 8),
    y1 = c(10, 12, 9, 11, 8, 7, 6, 9)
  )
  d <- as_survey(small_df, ids = psu, weights = wt, strata = strata)
  test_invariants(d)
  result <- get_means(d, y1, variance = "se")
  df_stored <- attr(result, ".survey_result")$df
  expect_equal(df_stored, 2) # 4 PSUs - 2 strata = 2
  ci <- confint(result, level = 0.95)
  half_width <- ci[1, 2] - coef(result)[1]
  expected_half_width <- stats::qt(0.975, df = 2) * SE(result)[1]
  expect_equal(half_width, expected_half_width, tolerance = 1e-10)
})
```

#### 8.6 Replicate design — confint matches normal approximation

```r
test_that("confint.survey_result() matches normal approximation for replicate designs", {
  df <- make_survey_data(design = "replicate", seed = 11)
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = tidyselect::starts_with("repwt_"),
    type = "BRR"
  )
  test_invariants(d)
  result <- get_means(d, y1, variance = "se")
  expect_true(is.infinite(attr(result, ".survey_result")$df))
  ci <- confint(result, level = 0.95)
  expected_lower <- coef(result) - stats::qnorm(0.975) * SE(result)
  expected_upper <- coef(result) + stats::qnorm(0.975) * SE(result)
  expect_equal(unname(ci[, 1]), unname(expected_lower), tolerance = 1e-10)
  expect_equal(unname(ci[, 2]), unname(expected_upper), tolerance = 1e-10)
})
```

---

### 9. Cross-method consistency invariants

#### 9.1 SE(result) == sqrt(diag(vcov(result))) always

For each supported result class, assert:
```r
expect_equal(SE(result), sqrt(diag(vcov(result))), tolerance = 1e-14)
```
Test with and without grouping.

#### 9.2 confint midpoint equals coef

For any result where SE is non-NA:
```r
ci <- confint(result, level = 0.95)
midpoints <- (ci[, 1] + ci[, 2]) / 2
expect_equal(unname(midpoints), unname(coef(result)), tolerance = 1e-12)
```

#### 9.3 names(coef) == rownames(vcov) == colnames(vcov) == names(SE) == rownames(confint)

Assert all five are identical for grouped and ungrouped results.

---

### 10. get_*()-level attribute tests (in existing test files)

One block per `get_*()` function confirming that calling the function attaches
the attribute:

```r
test_that("get_means() attaches .survey_result attribute", {
  df <- make_survey_data(seed = 42)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  result <- get_means(d, y1)
  expect_false(is.null(attr(result, ".survey_result")))
  expect_identical(attr(result, ".survey_result")$estimate_cols, c("mean"))
  expect_identical(attr(result, ".survey_result")$statistic, "mean")
})
```

Write equivalent blocks in:
- `test-analysis-means.R` — confirms `estimate_cols = c("mean")`
- `test-analysis-totals.R` — confirms `estimate_cols = c("total")`
- `test-analysis-freqs.R` — confirms `estimate_cols = c("pct")` and attribute present
- `test-analysis-corr.R` — confirms long format has attribute with `estimate_cols = c("r")`; wide format does not

---

### 11. Snapshot coverage

The following `expect_snapshot(error = TRUE, ...)` calls must exist:
- `coef()` on `survey_t_test` (§7.1)
- `coef()` on `survey_pairwise` (§7.2)
- `vcov()` on `survey_t_test` (§7.3)
- `SE()` on `survey_t_test` (§7.6)
- `confint()` on `survey_t_test` (§7.7)
- `coef()` on result with stripped attribute (§7.5)
- `vcov()` on result with stripped attribute (§7.9)
- `confint()` on result with stripped attribute (§7.9)
- `confint()` with `level = 0` (§7.4)
- `confint()` with `level = 1` (§7.4)
- `confint()` with `level = 1.1` (§7.4)
- `confint()` with `df = -1` stored in attribute (§7.10)

The following `expect_snapshot(warning = TRUE, ...)` calls must also exist:
- `confint()` with `parm` containing `NA` element (§6.10) — `surveycore_warning_parm_na`
- `confint()` with `parm` containing a partially unmatched name (§6.11) — `surveycore_warning_parm_unmatched`
- `confint()` with `parm` containing all unmatched names (§6.12) — `surveycore_warning_parm_unmatched`

Every error snapshot test must be paired with an `expect_error(class = ...)` test
(dual pattern). Every warning snapshot test must be paired with an
`expect_warning(class = ...)` test. For `surveycore_error_invalid_conf_level`,
the class test uses the existing class name.

---

### 12. Numerical oracle: totals

```r
test_that("coef.survey_result() and SE.survey_result() match survey::svytotal for ungrouped total [numerical]", {
  skip_if_not_installed("survey")
  d_sc <- as_survey_replicate(
    acs_pums_wy,
    weights = pwgtp,
    repweights = tidyselect::num_range("pwgtp", 1:80),
    type = "successive-difference"
  )
  test_invariants(d_sc)
  d_sv <- survey::svrepdesign(
    data = acs_pums_wy,
    weights = ~pwgtp,
    repweights = "pwgtp[0-9]+",
    type = "successive-difference",
    combined.weights = TRUE
  )
  sc_result <- get_totals(d_sc, agep, variance = "se")
  sv_total <- survey::svytotal(~agep, d_sv, na.rm = TRUE)
  expect_equal(
    unname(coef(sc_result)),
    unname(coef(sv_total)),
    tolerance = 1e-10
  )
  expect_equal(
    unname(SE(sc_result)),
    as.numeric(survey::SE(sv_total)),
    tolerance = 1e-8
  )
})
```

---

### 13. Numerical oracle: freqs

```r
test_that("coef.survey_result() for survey_freqs matches survey::svymean for proportions [numerical]", {
  skip_if_not_installed("survey")
  nhanes_sub <- nhanes_2017[nhanes_2017$wtmec2yr > 0, ]
  d_sc <- as_survey(
    nhanes_sub,
    ids = sdmvpsu,
    weights = wtmec2yr,
    strata = sdmvstra,
    nest = TRUE
  )
  test_invariants(d_sc)
  d_sv <- survey::svydesign(
    ids = ~sdmvpsu,
    weights = ~wtmec2yr,
    strata = ~sdmvstra,
    data = nhanes_sub,
    nest = TRUE
  )
  sc_result <- get_freqs(d_sc, riagendr, variance = "se")
  sv_result <- survey::svymean(~ factor(riagendr), d_sv, na.rm = TRUE)
  # coef from freqs gives proportions per level
  expect_equal(
    unname(coef(sc_result)),
    unname(coef(sv_result)),
    tolerance = 1e-10
  )
})
```

---

### 14. Numerical oracles: additional classes

#### 14.1 Ratios — coef() and SE() vs survey::svyratio

```r
test_that("coef/SE for survey_ratios match survey::svyratio [numerical]", {
  skip_if_not_installed("survey")
  d_sc <- as_survey(
    nhanes_2017,
    ids = sdmvpsu,
    weights = wtmec2yr,
    strata = sdmvstra,
    nest = TRUE
  )
  test_invariants(d_sc)
  d_sv <- survey::svydesign(
    ids = ~sdmvpsu,
    weights = ~wtmec2yr,
    strata = ~sdmvstra,
    data = nhanes_2017,
    nest = TRUE
  )
  sc_result <- get_ratios(
    d_sc,
    numerator = bmxwt,
    denominator = bmxht,
    variance = "se"
  )
  sv_result <- survey::svyratio(~bmxwt, ~bmxht, d_sv, na.rm = TRUE)
  expect_equal(
    unname(coef(sc_result)),
    as.numeric(coef(sv_result)),
    tolerance = 1e-10
  )
  expect_equal(
    unname(SE(sc_result)),
    as.numeric(survey::SE(sv_result)),
    tolerance = 1e-8
  )
})
```

#### 14.2 Quantiles — coef() and confint() vs stored Woodruff CI bounds

```r
test_that("coef for survey_quantiles matches svyquantile; confint reproduced from stored Woodruff CIs [numerical]", {
  skip_if_not_installed("survey")
  d_sc <- as_survey(
    nhanes_2017,
    ids = sdmvpsu,
    weights = wtmec2yr,
    strata = sdmvstra,
    nest = TRUE
  )
  test_invariants(d_sc)
  d_sv <- survey::svydesign(
    ids = ~sdmvpsu,
    weights = ~wtmec2yr,
    strata = ~sdmvstra,
    data = nhanes_2017,
    nest = TRUE
  )
  sc_result <- get_quantiles(
    d_sc,
    ridageyr,
    probs = c(0.25, 0.5, 0.75),
    variance = "se"
  )
  sv_result <- survey::svyquantile(
    ~ridageyr,
    d_sv,
    quantiles = c(0.25, 0.5, 0.75),
    na.rm = TRUE
  )
  expect_equal(
    unname(coef(sc_result)),
    as.numeric(coef(sv_result)),
    tolerance = 1e-10
  )
  # confint() at df=Inf (nonprob/Taylor) algebraically reproduces Woodruff CIs
  ci <- confint(sc_result, level = 0.95)
  expect_equal(unname(ci[, 1]), sc_result$ci_low, tolerance = 1e-10)
  expect_equal(unname(ci[, 2]), sc_result$ci_high, tolerance = 1e-10)
})
```

#### 14.3 Covariance — coef() and SE() vs survey::svyvar

```r
test_that("coef/SE for survey_covariance match survey::svyvar [numerical]", {
  skip_if_not_installed("survey")
  d_sc <- as_survey(
    nhanes_2017,
    ids = sdmvpsu,
    weights = wtmec2yr,
    strata = sdmvstra,
    nest = TRUE
  )
  test_invariants(d_sc)
  d_sv <- survey::svydesign(
    ids = ~sdmvpsu,
    weights = ~wtmec2yr,
    strata = ~sdmvstra,
    data = nhanes_2017,
    nest = TRUE
  )
  sc_result <- get_covariance(d_sc, c(ridageyr, bmxwt), variance = "se")
  sv_result <- survey::svyvar(~ ridageyr + bmxwt, d_sv, na.rm = TRUE)
  # Compare the off-diagonal covariance
  sc_cov <- coef(sc_result)[
    grepl("ridageyr", names(coef(sc_result))) &
      grepl("bmxwt", names(coef(sc_result)))
  ]
  sv_cov <- as.numeric(sv_result[1, 2])
  expect_equal(unname(sc_cov), sv_cov, tolerance = 1e-10)
})
```

#### 14.4 Diffs — coef() names use "treatment - reference" format

```r
test_that("coef names for survey_diffs use treatment_level - reference_level format", {
  df <- make_survey_data(seed = 144)
  df$treatment <- factor(sample(
    c("Control", "A", "B"),
    nrow(df),
    replace = TRUE
  ))
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  test_invariants(d)
  result <- get_diffs(d, y1, by = treatment, reference = "Control")
  n <- names(coef(result))
  expect_true(all(grepl(" - Control$", n)))
})
```

#### 14.5 Corr (long format) — coef() matches survey::svycor

```r
test_that("coef for survey_corr (long) matches survey::svycor [numerical]", {
  skip_if_not_installed("survey")
  d_sc <- as_survey(
    nhanes_2017,
    ids = sdmvpsu,
    weights = wtmec2yr,
    strata = sdmvstra,
    nest = TRUE
  )
  test_invariants(d_sc)
  d_sv <- survey::svydesign(
    ids = ~sdmvpsu,
    weights = ~wtmec2yr,
    strata = ~sdmvstra,
    data = nhanes_2017,
    nest = TRUE
  )
  sc_result <- get_corr(
    d_sc,
    c(ridageyr, bmxwt),
    format = "long",
    variance = "se"
  )
  sv_result <- survey::svycor(~ ridageyr + bmxwt, d_sv, na.rm = TRUE)
  sv_r <- sv_result$cors["ridageyr", "bmxwt"]
  expect_equal(unname(coef(sc_result)), sv_r, tolerance = 1e-10)
})
```

#### 14.6 vcov() on replicate designs — diagonal matches stored se^2

```r
test_that("vcov.survey_result() diagonal matches se^2 for replicate designs [numerical]", {
  skip_if_not_installed("survey")
  d_sc <- as_survey_replicate(
    acs_pums_wy,
    weights = pwgtp,
    repweights = tidyselect::num_range("pwgtp", 1:80),
    type = "successive-difference"
  )
  test_invariants(d_sc)
  sc_result <- get_means(d_sc, agep, variance = "se")
  v <- suppressWarnings(vcov(sc_result))
  expect_equal(diag(v), sc_result$se^2, tolerance = 1e-8)
})
```

---

### 15. Zero-row result: vcov() and SE() assertions

```r
test_that("vcov/SE return correct 0-length structures for zero-row result", {
  # Construct a zero-row freqs result
  df <- make_survey_data(seed = 15)
  df$all_na <- NA_real_
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  test_invariants(d)
  result <- get_freqs(d, all_na, na.rm = TRUE)
  # vcov: 0×0 matrix with character(0) dimnames
  v <- vcov(result)
  expect_true(is.matrix(v))
  expect_equal(dim(v), c(0L, 0L))
  expect_identical(dimnames(v), list(character(0), character(0)))
  # SE: named numeric(0) with character(0) names
  s <- SE(result)
  expect_identical(names(s), character(0))
  expect_equal(length(s), 0L)
})
```

---

### 16. Warning tests: SCR-W1 and SCR-W2

```r
test_that("vcov.survey_result() emits surveycore_warning_vcov_incomplete for multi-pair corr", {
  df <- make_survey_data(seed = 161)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  test_invariants(d)
  result <- get_corr(d, c(y1, y2, y3), format = "long", variance = "se")
  # More than one pair row — should warn
  expect_warning(
    vcov(result),
    class = "surveycore_warning_vcov_incomplete"
  )
})

test_that("vcov.survey_result() emits surveycore_warning_vcov_diagonal_only for grouped means", {
  df <- make_survey_data(seed = 162)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  test_invariants(d)
  result <- get_means(d, y1, group = strata, variance = "se")
  expect_warning(
    vcov(result),
    class = "surveycore_warning_vcov_diagonal_only"
  )
})

test_that("vcov.survey_result() emits surveycore_warning_vcov_diagonal_only for ungrouped multi-quantile", {
  df <- make_survey_data(seed = 163)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  test_invariants(d)
  result <- get_quantiles(d, y1, probs = c(0.25, 0.5, 0.75), variance = "se")
  expect_warning(
    vcov(result),
    class = "surveycore_warning_vcov_diagonal_only"
  )
})
```

---

### 17. label_values stability for survey_freqs coef() names

```r
test_that("coef() names for survey_freqs use raw values even after label_values = TRUE", {
  skip_if_not_installed("haven")
  df <- make_survey_data(seed = 17, with_labels = TRUE)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  test_invariants(d)
  result_raw <- get_freqs(d, group_label, variance = "se")
  result_labels <- get_freqs(
    d,
    group_label,
    variance = "se",
    label_values = TRUE
  )
  expect_identical(names(coef(result_raw)), names(coef(result_labels)))
})
```

---

### 18. Meta immutability and survey_diffs naming

```r
test_that("meta(result) is unchanged after calling coef(), vcov(), SE(), confint()", {
  df <- make_survey_data(seed = 181)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  test_invariants(d)
  result <- get_means(d, y1, variance = "se")
  meta_before <- meta(result)
  invisible(coef(result))
  suppressWarnings(invisible(vcov(result)))
  invisible(SE(result))
  invisible(confint(result))
  expect_identical(meta(result), meta_before)
})

test_that("coef() names for survey_diffs include reference_level in contrast format", {
  df <- make_survey_data(seed = 182)
  df$trt <- factor(sample(c("Control", "A", "B"), nrow(df), replace = TRUE))
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  test_invariants(d)
  result <- get_diffs(d, y1, by = trt, reference = "Control")
  n <- names(coef(result))
  expect_true(all(grepl(" - Control$", n)))
})
```

---

### 19. name_style = "broom" error path

```r
test_that("coef() works before broom rename and throws after", {
  df <- make_survey_data(seed = 19)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  test_invariants(d)
  result <- get_means(d, y1, variance = "se")
  # Works before broom rename
  expect_no_error(coef(result))
  # Apply broom rename (name_style = "broom" renames "mean" to "estimate")
  result_broom <- result
  names(result_broom)[names(result_broom) == "mean"] <- "estimate"
  # coef() should throw SCR-1 with broom-specific message
  expect_error(
    coef(result_broom),
    class = "surveycore_error_result_method_unsupported"
  )
  expect_snapshot(error = TRUE, coef(result_broom))
})
