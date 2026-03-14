# Handoff: PR 6 — `feature/glm-numerical-tests`

**Date:** 2026-03-09
**Branch:** `feature/glm-numerical-tests` (already created from `develop`)
**Session status:** Source bugs fixed, test file NOT yet written

---

## Decisions Made

1. **Use `gss_2024` for Taylor oracle tests** (user directive). The spec says
   `nhanes_2017`; this session overrides that for examples/oracle tests.
   Variables: `vpsu` (PSU), `vstrat` (strata), `wtssps` (weights). Good
   formula: `age ~ educ + sex`. degf = 67.

2. **Relaxed criterion for twophase oracle.** A pre-existing variance bug
   (separate from PR 6) causes surveycore twophase SEs to be ~`sqrt(2)x` too
   small. Write the twophase oracle test as: "fits without error, SEs are
   positive and finite" — same weaker criterion the plan already uses for
   calibrated. Do NOT attempt an exact SE match for twophase in PR 6.

3. **Separate investigation required for twophase variance.** Do not fold into
   PR 6. See "Separate Investigation" section below.

4. **PR 6 is no longer test-only.** Three source bugs in `R/glm.R` were found
   and fixed during oracle development. Changelog must document these.

---

## Changes Made This Session

All changes are in `R/glm.R` on branch `feature/glm-numerical-tests`.
All 591 existing tests pass after these fixes.

### Bug 1 — `.glm_replicate_vcov()`: `wr` not found in replicate refits

**Root cause:** `stats::glm(weights = wr)` passed `wr` as a symbol. Inside
`tryCatch(suppressWarnings(...))`, `parent.frame()` couldn't reach the loop's
local scope where `wr` was defined, causing all 80 replicate refits to silently
return `NULL`. All replicate SEs were zero.

**Fix:** Changed to `do.call(stats::glm, list(..., weights = wr, ...))` so `wr`
is evaluated before being passed.

```r
# Before (buggy):
fit_r <- tryCatch(suppressWarnings(stats::glm(... weights = wr ...)), ...)

# After (fixed):
fit_r <- tryCatch(suppressWarnings(do.call(stats::glm, list(... weights = wr ...))), ...)
```

### Bug 2 — `.glm_srs_vcov()`: wrong sandwich formula

**Root cause:** Two errors in the meat computation:
1. Formula `N² * (1-f)/n * var(u_i)` was wrong because `u_i = w_i * x_i * r_i`
   already contains `w_i`. Correct formula for pre-weighted scores is
   `(1-f) * n * var(u_i)` (wrong by factor `(N/n)²`).
2. When no FPC column is specified, `f` was computed as `n/N` (sampling
   fraction from weights) instead of `0`. Survey uses `f = 0` when no FPC is
   given.

**Fix:**
```r
# Before:
f    <- n_fit / N_approx   # when no FPC (wrong)
meat <- N_approx^2 * (1 - f) / n_fit * stats::var(score_used)

# After:
f    <- 0                  # no FPC → infinite population assumption
meat <- (1 - f) * n_fit * stats::var(score_used)
```

Also removed now-unused `N_approx` / `w_full` computation; cleaned up the
duplicate `!is.null(fpc_var) && !is.null(fpc_var)` condition to single check.

### Bug 3 — `survey_glm()` + `.glm_score()`: twophase crash

**Root cause:** `design@variables$weights` is `NULL` for `survey_twophase`
(weights are nested at `design@variables$phase1$weights`). Two crash sites:
- `survey_glm()` Step 3: `design@data[[NULL]]` → "attempt to select less than
  one element"
- `.glm_score()`: same `design@data[[design@variables$weights]]` pattern
- `survey_glm()` Step 2: domain_mask was not intersected with phase-2 subset,
  so the GLM was incorrectly fit on all rows (including phase-1-only rows)

**Fix:** Added helper `.get_glm_weights(design)` (placed after `.glm_score()`):
- For `survey_twophase`: returns calibrated weights `w_ph1 / pi2`, with 0 for
  non-phase-2 rows (not NA, to avoid `0 * NA = NA` in score matrix)
- For all other designs: returns `design@data[[design@variables$weights]]`

Updated `.glm_score()` to call `.get_glm_weights(design)` instead of direct
column access.

Updated `survey_glm()`:
- Step 2: intersect `domain_mask` with `subset_mask` for twophase
- Step 3: use `.get_glm_weights(design)`; handle `wt_var = NULL` for twophase
  in error messages

---

## Oracle Verification Results

| Design | Coef diff | SE diff | Status |
|--------|-----------|---------|--------|
| Taylor (`gss_2024`, gaussian) | 7e-15 | 1.5e-14 | ✓ within tolerance |
| SRS (synthetic, no FPC) | 1.4e-14 | 6.7e-16 | ✓ within tolerance |
| Replicate (synthetic BRR, `mse=FALSE`) | 1.4e-14 | 5e-15 | ✓ within tolerance |
| Twophase (synthetic) | 1.4e-14 | ~0.61 | ✗ pre-existing variance bug |
| Calibrated | not yet tested | — | — |

**Replicate oracle note:** Must use `mse = FALSE` in `as_survey_repweights()` to match
`survey::svrepdesign()` default. The oracle test must explicitly pass `mse =
FALSE` on the surveycore side.

---

## Remaining Work for PR 6

### 1. Write `tests/testthat/test-glm-numerical.R`

Full test file to write. All blocks use `skip_if_not_installed("survey")`.
Do NOT add domain oracle (already in `test-glm.R` item 11).

**Gaussian oracle — all 5 design classes:**

```r
# Taylor (gss_2024)
d_sc <- as_survey(gss_2024, ids = vpsu, weights = wtssps, strata = vstrat, nest = TRUE)
d_sv <- survey::svydesign(ids = ~vpsu, weights = ~wtssps, strata = ~vstrat,
                           data = gss_2024, nest = TRUE)
fit_sc <- survey_glm(d_sc, age ~ educ + sex)
fit_sv <- survey::svyglm(age ~ educ + sex, design = d_sv)
# tolerances: coef 1e-10, SE 1e-8

# Replicate (synthetic BRR — mse=FALSE on BOTH sides)
df_rep <- make_survey_data(design = "replicate", type = "BRR", seed = 42)
repwt_cols <- grep("^repwt_", names(df_rep), value = TRUE)
d_sc <- as_survey_repweights(df_rep, weights = wt, repweights = all_of(repwt_cols),
                       type = "BRR", mse = FALSE)
d_sv <- survey::svrepdesign(data = df_rep, weights = ~wt,
                              repweights = df_rep[, repwt_cols], type = "BRR")
# NOTE: survey::svrepdesign() defaults to mse=FALSE, matching our d_sc

# SRS (synthetic, no FPC — matches survey::svydesign(fpc=NULL))
df <- make_survey_data(seed = 42)
d_sc <- as_survey_srs(df, weights = wt)
d_sv <- survey::svydesign(ids = ~1, weights = ~wt, data = df)

# Twophase (RELAXED — no exact SE match; pre-existing variance bug)
# Just: survey_glm() runs without error AND SEs are positive finite
df_p <- make_survey_data(design = "twophase", seed = 42)
ph1  <- as_survey(df_p, ids = psu, weights = wt, strata = strata, fpc = fpc, nest = TRUE)
d_sc <- as_survey_twophase(ph1, subset = subset, method = "approx")
fit_sc <- survey_glm(d_sc, y1 ~ y2 + y3)
# expect: no error, coef names correct, all SEs positive finite
# NOTE: SE oracle skipped — known twophase variance underestimation (~sqrt(2)x)
#       tracked in plans/investigation-twophase-variance.md

# Calibrated (RELAXED — same as twophase, no exact SE match)
# Build via survey::calibrate() + from_svydesign()
```

**Family oracle — Taylor design only (`gss_2024`):**

| Family | surveycore call | survey call | Response |
|--------|----------------|-------------|----------|
| `gaussian(identity)` | same | same | `age` |
| `binomial(logit)` | `binomial()` | `quasibinomial()` | `I(happy == 1)` |
| `Gamma(inverse)` | same | same | `age` |
| `inverse.gaussian("1/mu^2")` | same | same | `age` |
| `quasi(identity, constant)` | same | same | `age` |
| `quasibinomial(logit)` | same | same | `I(happy == 1)` |
| `poisson(log)` | same | same | `y_count` (synthetic) |
| `quasipoisson(log)` | same | same | `y_count` (synthetic) |

For Poisson: `df <- make_survey_data(n=300, seed=42); set.seed(42); df$y_count <- rpois(nrow(df), lambda=exp(0.3*df$y1+0.5))`.

**Programmatic interface identity:**
```r
d_sc <- as_survey(gss_2024, ids = vpsu, weights = wtssps, strata = vstrat, nest = TRUE)
fit_formula      <- survey_glm(d_sc, age ~ educ + sex)
fit_programmatic <- survey_glm(d_sc, response = "age", predictors = c("educ", "sex"))
# coef within 1e-15, vcov within 1e-15
```

**SRS full meat matrix (multi-predictor):**
Covered by the SRS Gaussian oracle above (`y1 ~ y2 + y3`), which is already a
multiple-predictor model.

**`.degf()` oracle — all 5 design classes:**
```r
expect_equal(.degf(d_sc_taylor),     survey::degf(d_sv_taylor),     tolerance = 1e-10)
expect_equal(.degf(d_sc_replicate),  survey::degf(d_sv_replicate),  tolerance = 1e-10)
expect_equal(.degf(d_sc_srs),        survey::degf(d_sv_srs),        tolerance = 1e-10)
expect_equal(.degf(d_sc_twophase),   survey::degf(d_sv_twophase),   tolerance = 1e-10)
expect_equal(.degf(d_sc_calibrated), survey::degf(d_sv_calibrated), tolerance = 1e-10)
```

**PSD check:** `all(eigen(vcov(fit))$values >= -1e-10)` for all oracle fits
where SE oracle passes (Taylor, SRS, Replicate).

**CI oracle:** `confint(fit_sc)` vs `confint(fit_sv)` within 1e-6 for Taylor
design.

### 2. Write `changelog/phase-2/feature-glm-numerical-tests.md`

Note that this PR is NOT purely test-only — three source bugs were fixed.

### 3. Run checks

```r
devtools::test()    # all pass
devtools::check()   # 0 errors, 0 warnings, ≤2 notes
```

### 4. Mark `plans/impl-phase-2.md` PR 6 complete

Change `- [ ] PR 6` to `- [x] PR 6`.

---

## Separate Investigation Required: Twophase Variance Bug

**File to create:** `plans/investigation-twophase-variance.md`

**Symptom:** For `survey_twophase` designs, surveycore computes approximately
**half** the correct variance for all estimands:
- `get_means()` SE: surveycore 0.577, survey 0.810 — ratio 0.71 ≈ 1/sqrt(2)
- Variance ratio: 0.333/0.657 ≈ 0.507 ≈ 1/2

**Scope:** Affects ALL Phase 1 analysis functions:
`get_means()`, `get_totals()`, `get_freqs()`, `get_corr()`, `get_quantiles()`,
`get_ratios()`, and `survey_glm()` (twophase path).

**Suspected location:** `.twophase_phase1_var()` in `R/variance-twophase.R`
(lines 80–186). Hypothesis: the formula may be missing a `nPSUfull_s / nPSU_s`
factor per stratum. The survey package's `onestrat.phase1()` contains a
`nPSUfull * (nPSUfull/(nPSUfull-1)) / nPSU` scaling that surveycore's formula
may be missing. However the `nPSUfull/nPSU` ratio ≈ 1.04 for the synthetic
test data (not 2), so the factor-of-2 may be elsewhere.

**Oracle construction for investigation:**
```r
# surveycore
df_p <- make_survey_data(design = "twophase", seed = 42)
ph1  <- as_survey(df_p, ids = psu, weights = wt, strata = strata, fpc = fpc, nest = TRUE)
d_sc <- as_survey_twophase(ph1, subset = subset, method = "approx")

# survey equivalent (via as_svydesign — confirmed gives SE ≈ 0.810)
d_sv <- as_svydesign(d_sc)

# Compare
get_means(d_sc, y1, variance = "se")$se   # 0.577 — wrong
survey::SE(survey::svymean(~y1, d_sv))    # 0.810 — correct
```

**NOT introduced in this session** — pre-existing from Phase 0.75. Phase 0.75
tests do not include a numerical oracle comparison against `survey`.

---

## Key Files

| File | Status |
|------|--------|
| `R/glm.R` | ✅ Three bugs fixed; all 591 tests pass |
| `tests/testthat/test-glm-numerical.R` | ❌ Not yet written |
| `changelog/phase-2/feature-glm-numerical-tests.md` | ❌ Not yet written |
| `plans/impl-phase-2.md` | ❌ PR 6 not yet marked `[x]` |
| `plans/investigation-twophase-variance.md` | ❌ Not yet written |
