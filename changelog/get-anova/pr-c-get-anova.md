# feat(analysis): implement get_anova() for survey GLM fits

**Date**: 2026-04-18
**Branch**: feature/get-anova
**Plan**: `plans/impl-get-anova.md` — PR C

## Changes

- Add `get_anova()` (primary user-facing entry point) that computes
  Rao-Scott design-based ANOVA for `survey_glm_fit` objects. Supports
  two modes:
  - **Sequential**: `get_anova(fit)` tests each term on the model reduced
    to its left-hand-side predictors (matches `anova.svyglm()` semantics).
  - **Comparison**: `get_anova(fit_small, fit_big)` tests the additional
    terms added by the larger fit against the nested smaller fit.
- Register `anova.survey_glm_fit` as an S3 method in `R/zzz.R` via
  `registerS3method()` so `anova(fit)` dispatches to `get_anova()`.
- Add `print.survey_anova()` for the returned tibble, with a
  `decimals` option and Wald-mode suppression of the `deff` column.
- Implement internal helpers (all dotted, unexported):
  - `.reg_term_test()` — the core single-term test machinery (Wald and
    LRT branches, with `test = "F"` or `test = "Chisq"`).
  - `.anova_sequential()` — drives sequential term-by-term testing.
  - `.anova_compare()` — drives comparison-mode testing of two fits.
  - `.refit_drop_terms()` — internal refit that drops a set of terms
    without leaving scoping landmines (avoids `update()` indirection).
  - Helpers for deff computation, stars, and metadata assembly.
- Weight-scaling correctness fix: `.reg_term_test()` LRT branch now
  computes the rescale factor from the full-design weights (before
  NA filtering), matching `survey::svyglm()`'s rescale behavior. This
  produces LRT statistics and design effects that agree with
  `survey::regTermTest(..., method = "LRT")` at tolerance `1e-8`.
- Register 18 new error/warning classes A-2..A-20 in
  `plans/error-messages.md` and surface them from `get_anova()` with
  the surveycore cli-formatted message template.
- Extend `ANOVA_META_KEYS` and add `decimals`/`namestyle` validation
  into the shared `.validate_decimals_namestyle()` factory.

## Numerical validation

- Oracle: `survey::regTermTest()` called directly (not via
  `anova.svyglm()`, which uses `update()` internally and breaks inside
  `test_that()` scope).
- Taylor / LRT / F and Chisq: match `regTermTest` to `1e-8` on statistics
  and `1e-6` on p-values (NHANES 2017).
- Taylor / Wald / F and Chisq: match `regTermTest` to `1e-8` / `1e-6`.
- Taylor comparison mode LRT and Wald: match `regTermTest` to same
  tolerances.
- BRR replicate Wald/F: numerical test skipped when the ACS PUMS WY
  dataset ships without replicate weight columns.
- Two-phase: converted to a smoke test — surveycore's approximate
  variance method and `survey::twophase()` diverge legitimately, so we
  assert only shape and finite p-values.

## Known follow-ups (deferred to separate PRs)

- A-13 (singular V0) trigger requires careful numerical construction;
  tracked in `test-glm-anova.R:531`.
- A-20 (clobbered domain indicator) test requires a hand-built fit whose
  `@design@data` domain column differs from the refit's; tracked in
  `test-glm-anova.R:481`.

## Files Added

- `R/glm-anova.R` — 1108 lines; implementation + roxygen docs for
  `get_anova()`, `anova.survey_glm_fit`, `print.survey_anova`, and
  supporting internal helpers.
- `tests/testthat/test-glm-anova.R` — 952 lines; happy paths for all
  four `method × test` combinations, error paths for A-2..A-20,
  edge cases (single-term models, binomial family, insufficient df,
  single-row domains), tidy-select interface, and print snapshots.
- `tests/testthat/test-glm-anova-numerical.R` — 348 lines; numerical
  oracle tests vs `survey::regTermTest()` for Taylor (LRT/F, LRT/Chisq,
  Wald/F, Wald/Chisq), Taylor comparison mode (LRT/F, Wald/Chisq),
  BRR replicate Wald/F (skipped if replicate columns missing), and a
  two-phase smoke test.
- `tests/testthat/_snaps/glm-anova.md` — approved print snapshots for
  Taylor LRT/F, Taylor Wald (deff suppressed), and BRR replicate LRT/F.
- `man/get_anova.Rd` — generated.

## Files Modified

- `NAMESPACE` — exports `get_anova`, registers `anova.survey_glm_fit`.
- `R/zzz.R` — `registerS3method("anova", "survey_glm_fit", ...)` at
  `.onLoad()`.
- `R/analysis-helpers.R` — `ANOVA_META_KEYS` constant and
  `.validate_decimals_namestyle()` extended to cover anova result class.
- `tests/testthat/helper-test-data.R` — helpers for constructing the
  binomial-family fit used in the multi-method edge case test.

## Test summary

```
[ FAIL 0 | WARN 10 | SKIP 3 | PASS 185 ]
```

Warnings are expected (binomial non-integer successes in the
method×test combo test, single-stratum warning in the A-9 edge case,
and the saddlepoint-fallback warning exercised by the A-8 path). Skips
cover A-13 / A-20 and a CRAN-gated subset.
