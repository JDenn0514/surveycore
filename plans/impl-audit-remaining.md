# Implementation Plan — Audit Remediation PRs 4–7

**Plan ID:** `audit-remaining`
**Source:** `plans/audit-remediation-plan.md` (PRs 4, 5, 6, 7)
**Date:** 2026-03-16

---

## Overview

Four independent bug-fix PRs completing the post-Phase-2 audit remediation.
All multi-stage prerequisites are merged; these PRs share no files with each
other and can be implemented in any order. Each PR follows Tier 2–3 workflow:
branch from `develop`, TDD, oracle tests against the `survey` package.

---

## PR Map

- [ ] PR 4: `fix/srs-weighted-variance` — Delegate to Taylor engine when SRS weights are non-proportional
- [ ] PR 5: `fix/twophase-phase1-type-restriction` — Accept `survey_srs` and `survey_replicate` as phase-1 in `as_survey_twophase()`
- [ ] PR 6: `fix/nonprob-dispatch-consistency` — Route `survey_nonprob` through calibrated (HT) path in `get_freqs()`
- [x] PR 7: `fix/glm-weights-na-contiguous` — Fix `@weights` indexing for non-contiguous NA rows in `survey_glm()` (https://github.com/JDenn0514/surveycore/pull/72)

**Dependency graph:** None — all four are mutually independent.

---

## PR 4: Fix SRS weighted variance

**Branch:** `fix/srs-weighted-variance`
**Tier:** 2 (behavior change, approach decided below)

### Problem

`R/variance-srs.R` lines 79 and 147 use the unweighted sample variance:

```r
s2 <- sum((y - ybar)^2, na.rm = na.rm) / (n_used - 1L)
```

This is only correct when all weights are equal. With non-proportional weights
(e.g., from post-stratification adjustments on an SRS frame), the SE diverges
from the `survey` package by ~40%+ because the heterogeneity introduced by
unequal weights is ignored.

The `survey` package treats `svydesign(ids = ~1, weights = ~w)` as a Taylor
design where each row is its own PSU (no clustering). Variance is computed via
the Horvitz-Thompson linearization:

```
e_i = w_i * (y_i - ybar_w) / sum(w)
Var(ybar_w) = n/(n-1) * sum(e_i^2)
```

### Approach

**Option chosen: delegate to `.svy_recvar()` via `.build_cluster_matrices()`**
when weights are non-proportional.

`survey_srs` already stores `ids = NULL` and `strata = NULL`. The shared helper
`.build_cluster_matrices()` handles this case — it treats each row as its own
PSU in a single stratum (k = 1). This is exactly the HT linearization that the
`survey` package uses.

**Strategy for `.srs_mean()` and `.srs_total()`:** Replace the unweighted `s²`
formula with a call to `.build_cluster_matrices()` → `.svy_recvar()`. This
makes `survey_srs` variance consistent with `survey::svydesign(ids = ~1)` for
all weight structures, not just equal weights. The classical closed-form SRS
formula `(1-f) * s²/n` is a special case of the Taylor linearization when
weights are equal — the results are numerically identical — so existing tests
with equal weights will continue to pass.

**What about `.srs_freq_cell()`?** The proportion formula
`(1-f) * p*(1-p) / (n-1)` similarly assumes equal weights. Apply the same fix:
delegate to `.taylor_freq_cell()` (which uses `.build_cluster_matrices()`) when
weights are non-proportional. For equal weights the Taylor result matches the
closed-form, so existing tests pass.

**What about `.vcov_pair_srs()`?** Already uses `.build_cluster_matrices()` →
`.svy_recvar()`. No change needed.

### Files changed (TDD order)

1. `tests/testthat/test-variance-srs.R` — new oracle tests with non-proportional
   weights
2. `R/variance-srs.R` — rewrite `.srs_mean()` and `.srs_total()` to use
   `.build_cluster_matrices()` → `.svy_recvar()`
3. `tests/testthat/test-analysis-freqs.R` — new oracle test for SRS freqs with
   non-proportional weights
4. `R/analysis-freqs-helpers.R` — update `.srs_freq_cell()` to delegate to
   `.taylor_freq_cell()` (or inline the same `.svy_recvar()` approach)

### TDD steps

**Step 1: Write failing oracle tests** in `test-variance-srs.R`:

```r
test_that(".srs_mean() matches survey::svymean() with non-proportional weights [oracle]", {
  skip_if_not_installed("survey")
  set.seed(42)
  n <- 50
  df <- data.frame(y = rnorm(n, 50, 10), w = c(rep(1, 25), rep(5, 25)))
  sc <- as_survey_srs(df, weights = w)
  sv <- survey::svydesign(ids = ~1, weights = ~w, data = df)
  sc_est <- .srs_mean(sc, "y")
  sv_est <- survey::svymean(~y, sv)
  expect_equal(sc_est$mean, as.numeric(coef(sv_est)), tolerance = 1e-10)
  expect_equal(sc_est$se,   as.numeric(SE(sv_est)),   tolerance = 1e-8)
})

test_that(".srs_total() matches survey::svytotal() with non-proportional weights [oracle]", {
  skip_if_not_installed("survey")
  set.seed(42)
  n <- 50
  df <- data.frame(y = rnorm(n, 50, 10), w = c(rep(1, 25), rep(5, 25)))
  sc <- as_survey_srs(df, weights = w)
  sv <- survey::svydesign(ids = ~1, weights = ~w, data = df)
  sc_est <- .srs_total(sc, "y")
  sv_est <- survey::svytotal(~y, sv)
  expect_equal(sc_est$total, as.numeric(coef(sv_est)), tolerance = 1e-10)
  expect_equal(sc_est$se,    as.numeric(SE(sv_est)),   tolerance = 1e-8)
})
```

Add analogous tests for:
- Non-proportional weights + FPC (population type)
- Non-proportional weights + FPC (fraction type)
- Proportional (equal) weights still match (regression guard)
- `get_means()` and `get_totals()` integration tests with non-proportional SRS

**Step 2: Write failing oracle test** in `test-analysis-freqs.R`:

```r
test_that("get_freqs() on survey_srs with non-proportional weights matches survey [oracle]", {
  skip_if_not_installed("survey")
  set.seed(42)
  n <- 100
  df <- data.frame(
    x = sample(c("A", "B"), n, replace = TRUE),
    w = c(rep(1, 50), rep(5, 50))
  )
  sc <- as_survey_srs(df, weights = w)
  sv <- survey::svydesign(ids = ~1, weights = ~w, data = df)
  sc_est <- get_freqs(sc, x)
  sv_est <- survey::svymean(~x, sv)
  # Compare proportions and SEs for level "A"
  sc_a <- sc_est[sc_est$value == "A", ]
  expect_equal(sc_a$pct, as.numeric(coef(sv_est)["xA"]), tolerance = 1e-10)
  expect_equal(sc_a$se,  as.numeric(SE(sv_est)["xA"]),   tolerance = 1e-8)
})
```

**Step 3: Fix `.srs_mean()` and `.srs_total()`** — replace the unweighted `s²`
block with `.build_cluster_matrices()` → `.svy_recvar()`. Keep FPC handling
(it's already in `.build_cluster_matrices()`). Return structure unchanged.

**Step 4: Fix `.srs_freq_cell()`** — when the design is `survey_srs`, delegate
to `.taylor_freq_cell()` which already uses `.build_cluster_matrices()`. The
`survey_nonprob` class already does this. Alternatively, inline the
`.build_cluster_matrices()` + `.svy_recvar()` call directly.

**Step 5: Verify** all existing tests pass (equal-weight SRS tests are
regression guards).

### Acceptance criteria

- [ ] Oracle test: `.srs_mean()` with non-proportional weights matches
      `survey::svymean()` at 1e-10 (point), 1e-8 (SE)
- [ ] Oracle test: `.srs_total()` with non-proportional weights matches
      `survey::svytotal()` at 1e-10 (point), 1e-8 (SE)
- [ ] Oracle test: `get_freqs()` on SRS with non-proportional weights matches
      `survey::svymean()` at 1e-8 (SE)
- [ ] Existing equal-weight SRS tests unchanged
- [ ] Existing SRS + FPC tests unchanged
- [ ] `devtools::check()` 0/0/≤2

---

## PR 5: Fix two-phase phase-1 type restriction

**Branch:** `fix/twophase-phase1-type-restriction`
**Tier:** 3 (behavior change is clear, approach is clear)

### Problem

`R/core-constructors.R:1069` hard-rejects any phase-1 design that is not
`survey_taylor`:

```r
if (!S7::S7_inherits(phase1, survey_taylor)) {
  cli::cli_abort(..., class = "surveycore_error_phase1_class")
}
```

This prevents valid use cases: `survey_srs` phase-1 (SRS sampling of phase-1
units) and `survey_replicate` phase-1 (replicate-weight resampling of phase-1).
Lumley (2010) describes two-phase designs with SRS phase-1 frames.

### Research findings

The variance engine `.twophase_phase1_var()` in `R/variance-twophase.R` is
**already design-type agnostic** for the `"approx"` and `"full"` methods — it
reads column names from `@variables` and data from `@data` without dispatching
on class. For the `"simple"` method, it delegates to `.svy_recvar()` which
works correctly with any cluster/strata structure (including `ids = NULL` for
SRS/replicate).

**Two unsafe indexing locations** exist at lines ~92 and ~456 where
`ph1_vars$ids[[1L]]` is accessed inside a `!is.null(ph1_vars$ids)` guard.
For `survey_srs` (`ids = NULL`) these guards already protect correctly, but
for `survey_replicate` (`ids = NULL`) same protection applies. No code changes
needed inside the variance engine — the existing `NULL` guards handle it.

### Files changed (TDD order)

1. `tests/testthat/test-constructors.R` — update existing rejection tests;
   add acceptance tests for `survey_srs` and `survey_replicate` phase-1
2. `R/core-constructors.R` — relax the phase-1 type check from
   `survey_taylor` to `survey_base`
3. `plans/error-messages.md` — update error class description for row 19
4. `tests/testthat/test-variance-twophase.R` — add oracle tests for SRS and
   replicate phase-1 designs

### TDD steps

**Step 1: Update rejection test** in `test-constructors.R`:

The existing test at ~line 1186 expects `survey_replicate` phase-1 to throw
`surveycore_error_phase1_class`. Change this to verify acceptance instead.
Keep the test that rejects plain `data.frame` as phase-1.

**Step 2: Write failing acceptance tests** in `test-constructors.R`:

```r
test_that("as_survey_twophase() accepts survey_srs phase-1", {
  df <- make_survey_data(seed = 42)
  df$in_phase2 <- c(rep(TRUE, 250), rep(FALSE, 250))
  phase1 <- as_survey_srs(df, weights = wt)
  tp <- as_survey_twophase(phase1, subset = in_phase2)
  test_invariants(tp)
  expect_true(S7::S7_inherits(tp, survey_twophase))
})

test_that("as_survey_twophase() accepts survey_replicate phase-1", {
  df <- make_survey_data(design = "replicate", seed = 42)
  df$in_phase2 <- c(rep(TRUE, 250), rep(FALSE, 250))
  phase1 <- as_survey_replicate(df, weights = wt,
    repweights = tidyselect::starts_with("repwt_"), type = "JK1")
  tp <- as_survey_twophase(phase1, subset = in_phase2)
  test_invariants(tp)
  expect_true(S7::S7_inherits(tp, survey_twophase))
})
```

**Step 3: Write oracle tests** in `test-variance-twophase.R`:

```r
test_that("two-phase with survey_srs phase-1 matches survey [oracle]", {
  skip_if_not_installed("survey")
  # Build matching designs in both packages and compare get_means() SE
})
```

**Step 4: Relax the type check** in `R/core-constructors.R`:

```r
# Before:
if (!S7::S7_inherits(phase1, survey_taylor)) {

# After:
if (!S7::S7_inherits(phase1, survey_base)) {
```

Update the error message to say "must be a survey design object" instead of
"must be a survey_taylor object". Update the class name if desired (or keep
`surveycore_error_phase1_class`).

**Step 5: Handle `survey_replicate` phase-1 `@variables` mapping.** The
`as_survey_twophase()` constructor reads `phase1@variables` to build
`variables$phase1`. Verify that `survey_replicate` provides the keys the
variance engine needs (`ids`, `strata`, `weights`, `fpc`, `nest`). If any
key is missing, map it to `NULL`. Check:

- `survey_srs@variables` has: `ids = NULL`, `strata = NULL`, `weights`, `fpc`,
  `nest = FALSE`, `probs_provided`, `fpc_type`
- `survey_replicate@variables` has: `ids = NULL`, `strata = NULL`, `weights`,
  `fpc`, `nest = FALSE`, `probs_provided`, `repweights`, `type`, `scale`,
  `rscales`, `mse`, `fpctype`

Both have the keys the variance engine reads. No mapping needed.

**Step 6: Update `plans/error-messages.md`** — row 19 description: change
"phase1 is not a survey_taylor" to "phase1 is not a survey design object".

### Acceptance criteria

- [ ] `as_survey_twophase(phase1 = srs_design, ...)` no longer errors
- [ ] `as_survey_twophase(phase1 = replicate_design, ...)` no longer errors
- [ ] `as_survey_twophase(phase1 = data.frame(...))` still errors
- [ ] Oracle test: SRS phase-1 two-phase mean SE matches `survey` at 1e-8
- [ ] Existing Taylor phase-1 tests unchanged
- [ ] `devtools::check()` 0/0/≤2

---

## PR 6: Fix `survey_nonprob` dispatch consistency

**Branch:** `fix/nonprob-dispatch-consistency`
**Tier:** 3 (inconsistency is clear, fix is clear)

### Problem

`survey_nonprob` objects are routed differently by `get_freqs()` vs all other
analysis functions:

| Function | Route for `survey_nonprob` |
|----------|---------------------------|
| `get_freqs()` | `.taylor_freq_cell()` (Taylor linearization via `.svy_recvar()`) |
| `get_means()` | `.calibrated_mean_cell()` (HT formula: `n/(n-1) * Σ(w²(y-ȳ)²)/N²`) |
| `get_totals()` | `.calibrated_total_cell()` (HT formula) |
| `get_corr()` | `.vcov_pair_calibrated()` (HT formula) |
| `get_quantiles()` | Via `.mean_cell()` → `.calibrated_mean_cell()` (HT) |
| `get_ratios()` | Via `.total_cell()` → `.calibrated_total_cell()` (HT) |

Five of six analysis functions use the HT (calibrated) path. Only `get_freqs()`
uses the Taylor linearization path. The comment at `analysis-freqs-helpers.R:306`
says "survey_nonprob falls through to the Taylor path (conservative SEs)" —
this was a convenience choice, not a deliberate design decision.

### Approach

Create `.calibrated_freq_cell()` that parallels `.calibrated_mean_cell()` but
for proportions (binary indicator). Route `survey_nonprob` to it in
`.freq_cell()`.

The HT variance for a proportion `p = Y/N_d` where `Y = Σ(w_i * I_i)` is:

```
z_i = w_i * (I_i - p) / N_d
Var(p) = n/(n-1) * Σ(z_i²)
```

This is identical to `.calibrated_mean_cell()` applied to a 0/1 variable.
We can either:
- **(A)** Create a thin `.calibrated_freq_cell()` that delegates to
  `.calibrated_mean_cell()` internally (DRY), or
- **(B)** Implement the formula inline (explicit, self-contained).

**Choose (A)** — delegate to `.calibrated_mean_cell()`. The proportion is just
the mean of a 0/1 variable. Build the 0/1 column from `num` restricted to the
`denom` domain, call `.calibrated_mean_cell()`, and repackage the result with
freq-style names (`pct` instead of `mean`).

### Files changed (TDD order)

1. `tests/testthat/test-analysis-freqs.R` — add oracle tests comparing
   `get_freqs()` on `survey_nonprob` against the HT formula directly and
   against `get_means()` on the same indicator
2. `R/analysis-freqs-helpers.R` — add `.calibrated_freq_cell()` and update
   `.freq_cell()` dispatcher
3. `R/analysis-means-helpers.R` — no change (`.calibrated_mean_cell()` already
   works for 0/1 variables)

### TDD steps

**Step 1: Write failing consistency test** in `test-analysis-freqs.R`:

```r
test_that("get_freqs() and get_means() use same variance for survey_nonprob", {
  df <- data.frame(
    x = c(rep("A", 30), rep("B", 70)),
    w = runif(100, 0.5, 5)
  )
  d <- as_survey_nonprob(df, weights = w)

  freq_result <- get_freqs(d, x)
  # Manually compute the mean of indicator I(x == "A") via get_means
  df$ind_A <- as.numeric(df$x == "A")
  d2 <- as_survey_nonprob(df, weights = w)
  mean_result <- get_means(d2, ind_A)

  freq_A <- freq_result[freq_result$value == "A", ]
  expect_equal(freq_A$pct, mean_result$mean, tolerance = 1e-10)
  expect_equal(freq_A$se,  mean_result$se,   tolerance = 1e-10)
})
```

**Step 2: Write `.calibrated_freq_cell()`** in `R/analysis-freqs-helpers.R`:

```r
.calibrated_freq_cell <- function(design, num, denom) {
  data <- design@data
  vars <- design@variables
  w    <- data[[vars$weights]]

  n_g    <- as.integer(sum(denom))
  N_d    <- sum(w * denom)
  n_cell <- as.integer(sum(num))
  Y      <- sum(w * num)
  p      <- if (N_d > 0) Y / N_d else NA_real_

  if (n_g == 0L || N_d <= 0) {
    return(list(
      pct = NA_real_, se = NA_real_, se_srs = NA_real_,
      n = 0L, n_weighted = 0
    ))
  }

  if (n_g < 2L) {
    return(list(
      pct = p, se = NA_real_, se_srs = NA_real_,
      n = n_cell, n_weighted = Y
    ))
  }

  # HT variance: n/(n-1) * Σ(z_i²), z_i = w_i*(I_i - p)/N_d
  idx   <- denom > 0
  w_sub <- w[idx]
  I_sub <- (num / denom)[idx]  # 0/1 indicator within domain
  z     <- w_sub * (I_sub - p) / N_d
  var_p <- (n_g / (n_g - 1L)) * sum(z^2)
  se    <- sqrt(max(0, var_p))

  se_srs <- if (p > 0 && p < 1) sqrt(p * (1 - p) / n_g) else 0

  list(
    pct        = p,
    se         = se,
    se_srs     = se_srs,
    n          = n_cell,
    n_weighted = Y
  )
}
```

**Step 3: Update `.freq_cell()` dispatcher:**

```r
# Before:
if (
  S7::S7_inherits(design, survey_taylor) ||
    S7::S7_inherits(design, survey_nonprob)
) {
  .taylor_freq_cell(design, num, denom)

# After:
if (S7::S7_inherits(design, survey_taylor)) {
  .taylor_freq_cell(design, num, denom)
} else if (S7::S7_inherits(design, survey_nonprob)) {
  .calibrated_freq_cell(design, num, denom)
```

**Step 4: Verify** all existing `survey_nonprob` tests pass or are updated.
The SE values for `survey_nonprob` in `get_freqs()` will change — update any
hardcoded expectations.

### Acceptance criteria

- [ ] `get_freqs()` and `get_means()` produce identical SE for `survey_nonprob`
      when comparing proportion vs mean-of-indicator
- [ ] No existing `survey_taylor` freq tests affected
- [ ] No existing `survey_srs` freq tests affected
- [ ] `devtools::check()` 0/0/≤2

---

## PR 7: Fix GLM `@weights` non-contiguous NA indexing

**Branch:** `fix/glm-weights-na-contiguous`
**Tier:** 3 (bug is well-defined)

### Problem

`R/glm.R:957`:

```r
weights = as.numeric(wt_fit[seq_len(length(stats::fitted(fit)))]),
```

`seq_len(length(fitted(fit)))` always produces `1:n_complete`. When `na.action
= na.omit` drops non-contiguous rows (e.g., rows 3, 7, 15 of `fit_data`), this
takes the first `n_complete` elements of `wt_fit` instead of the elements
corresponding to the rows actually used in the fit.

### Root cause analysis

The weight vector `wt_fit` (line 774) is `wt_all[domain_idx]` — the weights
for all in-domain rows. When `stats::glm()` is called with `na.action =
na.omit`, it drops rows with NA in the response or predictors. The `na.action`
attribute on the model frame (`na_idx`, line 925) records which rows of
`fit_data` were dropped.

At line 929, `used_in_fit <- domain_idx[-na_idx]` correctly computes the
indices into `design@data` of the rows actually used. But at line 957,
`wt_fit[seq_len(...)]` ignores `na_idx` and just takes the first N weights.

### Fix

Replace `seq_len(length(fitted(fit)))` with proper indexing. Since `wt_fit`
is indexed into `domain_idx` and `na_idx` is relative to `fit_data` (which
equals `design@data[domain_idx, ]`), the correct weights are
`wt_fit[-na_idx]` when `na_idx` is non-NULL, or `wt_fit` when NULL:

```r
# Before (line 957):
weights = as.numeric(wt_fit[seq_len(length(stats::fitted(fit)))]),

# After:
weights = if (!is.null(na_idx)) as.numeric(wt_fit[-na_idx]) else as.numeric(wt_fit),
```

### Files changed (TDD order)

1. `tests/testthat/test-glm.R` — add test with non-contiguous NAs
2. `R/glm.R` — fix weight indexing at line 957

### TDD steps

**Step 1: Write failing test** in `test-glm.R`:

```r
test_that("survey_glm() @weights correct with non-contiguous NAs and na.omit", {
  df <- make_survey_data(seed = 42)
  # Inject NAs at non-contiguous positions in the response
  df$y1[c(3, 7, 15, 42, 100)] <- NA
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  fit <- survey_glm(d, y1 ~ y2, na.action = na.omit)

  # Number of weights must equal number of fitted values
  expect_equal(length(fit@weights), length(fit@fitted_values))

  # Weights should correspond to the non-NA rows
  na_rows_in_domain <- c(3, 7, 15, 42, 100)
  non_na_mask <- !seq_len(nrow(df)) %in% na_rows_in_domain
  expected_weights <- df$wt[non_na_mask]
  expect_equal(fit@weights, expected_weights, tolerance = 1e-10)
})
```

**Step 2: Write regression test** — fitting on manually-cleaned data produces
same coefficients:

```r
test_that("survey_glm() with na.omit matches clean-data fit", {
  df <- make_survey_data(seed = 42)
  df$y1[c(3, 7, 15, 42, 100)] <- NA
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  fit_na <- survey_glm(d, y1 ~ y2, na.action = na.omit)

  # Fit on manually cleaned data
  df_clean <- df[!is.na(df$y1), ]
  d_clean <- as_survey(df_clean, ids = psu, weights = wt, strata = strata)
  fit_clean <- survey_glm(d_clean, y1 ~ y2)

  expect_equal(fit_na@coefficients, fit_clean@coefficients, tolerance = 1e-10)
})
```

**Step 3: Fix the indexing** at `R/glm.R:957`.

**Step 4: Verify** all existing GLM tests pass unchanged.

### Acceptance criteria

- [ ] New test: non-contiguous NAs with `na.action = na.omit` produces
      correct `@weights` (length == n_complete, values from correct rows)
- [ ] New test: `survey_glm()` with NAs produces same coefficients as
      fitting on manually-cleaned data
- [ ] Existing GLM tests unchanged
- [ ] `devtools::check()` 0/0/≤2

---

## Implementation order summary

All four PRs are mutually independent. Suggested order by complexity
(simplest first):

```
PR 7 (GLM NA weights)     — 1 file change, 1 line fix
PR 6 (nonprob dispatch)   — 1 file change, new function + dispatcher update
PR 5 (twophase phase-1)   — 2 files changed, relax check + oracle tests
PR 4 (SRS weighted var)   — 2 files changed, rewrite variance engine + oracle tests
```
