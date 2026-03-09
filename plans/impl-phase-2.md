# surveycore Phase 2 Implementation Plan — Survey GLM: Weighted Regression

**Status:** Approved — Stage 3 complete (2026-03-08)
**Spec:** `plans/spec-phase-2.md` (v1.0, methodology-locked)
**Decisions:** `plans/decisions-phase-2.md`
**Methodology review:** `plans/spec-methods-review-phase-2.md` (all 20 issues resolved)

---

## Overview

This plan delivers Phase 2 of surveycore: survey-weighted GLM via `survey_glm()`,
the `survey_glm_fit` S7 class with 20 S3 methods, the `clean()` tidy output
function, and a marginaleffects extension interface. The implementation reuses the
Phase 0 variance machinery (`.svy_recvar()` and replicate scale infrastructure)
rather than introducing new vendored code. All five design classes are supported.

The plan follows standard ordering: shared infrastructure first, then core class
and constructor, then methods, then output, then optional extensions, then oracle
tests.

---

## PR Map

- [x] PR 1: `chore/glm-pre-implementation` — error table + test helper infrastructure
- [x] PR 2: `feature/glm-core` — `survey_glm_fit` S7 class + `survey_glm()` + variance engine
- [x] PR 3: `feature/glm-methods` — 20 S3 methods + `survey_glm_summary`
- [ ] PR 4: `feature/glm-clean` — `clean()` + `broom::tidy()` shim
- [ ] PR 5: `feature/glm-marginaleffects` — marginaleffects extension interface
- [ ] PR 6: `feature/glm-numerical-tests` — oracle tests vs `survey::svyglm()` (depends on PR 4 + PR 5)

---

## PR 1: Error table + test helper infrastructure

**Branch:** `chore/glm-pre-implementation`
**Depends on:** none

**Files (in TDD order — tests first):**
- `plans/error-messages.md` — add all 21 Phase 2 error/warning classes from spec §X (Error Message Table)
- `tests/testthat/helper-test-data.R` — add `test_glm_fit_invariants()` (spec §9.3a) and `test_glm_tidy_invariants()` (spec §9.3)
- `changelog/phase-2/chore-glm-pre-implementation.md` — created last, before opening PR

**Acceptance criteria:**
- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] `plans/error-messages.md` contains all 21 classes from spec §X (Error Message Table) (P2-1 through P2-21): 19 new entries + 2 reused from Phase 1 (`surveycore_error_invalid_conf_level`, `surveycore_error_not_survey_object`)
- [ ] `test_glm_fit_invariants(fit)` asserts: S7 class, `p > 0` coefficients, `vcov` is `p × p`, `degf > 0`, `converged` is logical, `formula` inherits `"formula"`
- [ ] `test_glm_tidy_invariants(result)` asserts: class hierarchy, required columns (10), `reference_row` logical no-NA, `label` character no-NA, `meta()` non-NULL with all 15 required keys, `group_names` is `character(0)`, `n_observations` positive integer, `n_weighted` positive numeric, `degf` positive numeric, `$variables` named list with all 7 sub-keys per entry
- [ ] Changelog entry written and committed on this branch

**Notes:**
- The spec requires `plans/error-messages.md` to be updated before implementation
  begins (spec §X). This PR satisfies that requirement.
- Helper functions are defined in `helper-test-data.R` (not a new file) alongside
  the existing `test_invariants()` and `make_survey_data()` definitions.
- No R source files changed in this PR; `devtools::check()` still required.

---

## PR 2: `survey_glm_fit` S7 class + `survey_glm()` + variance engine

**Branch:** `feature/glm-core`
**Depends on:** PR 1

**Files (in TDD order — tests first):**
- `tests/testthat/test-glm.R` — `survey_glm()` test items 1, 7, 7b, 8, 9, 10, 11, 12 from spec §9.2; S7 validator error tests (§9.2 item 12, all 7 conditions); Section 9.4 edge cases for `survey_glm()` only (not `clean()` — those come in PR 4)
- `R/glm.R` — `survey_glm_fit` S7 class + validator, `survey_glm()` constructor (Steps 1–6), all internal helpers (`.glm_score`, `.glm_sandwich_vcov`, `.glm_degrees_of_freedom`, `.taylor_var_score_matrix`, variance dispatch for all 5 design classes)
- `R/utils.R` — add `.glm_confint()` internal helper (called from `glm-methods.R` and `glm-clean.R`; 2+ files → `utils.R` per `code-style.md §4`)
- `R/zzz.R` — update `.onLoad()` to include `S7::methods_register()` call if not already present; no S3 registrations yet
- `changelog/phase-2/feature-glm-core.md` — created last, before opening PR

**Acceptance criteria:**
- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] `test_glm_fit_invariants(fit)` passes for a basic `survey_glm(d, y ~ x)` call
- [ ] `survey_glm()` formula interface: basic Gaussian fit produces valid `survey_glm_fit`
- [ ] `survey_glm()` programmatic interface: `response = "y", predictors = c("x1")` produces identical `@coefficients` and `@vcov` to formula interface (within 1e-15)
- [ ] `survey_glm()` programmatic interface: `response = "y"` alone produces intercept-only model (`y ~ 1`); `predictors` without `response` errors with `surveycore_error_formula_missing`
- [ ] `lapply()` state leakage: iterating over outcome variables produces independent `survey_glm_fit` objects with the correct `@formula` each time
- [ ] All 15 error/warning classes from spec §4.7 are tested: user-facing constructor errors use dual pattern (`class=` + `expect_snapshot(error = TRUE)`); S7 validator errors use `class=` only (no snapshot)
- [ ] `surveycore_error_cbind_response_unsupported` (P2-20, spec §4.7 row 14): trigger by calling `survey_glm(d, cbind(y1, y2) ~ x)` — dual pattern (`class=` + snapshot)
- [ ] `surveycore_warning_glm_convergence` fires on forced non-convergence; fit is still returned
- [ ] `surveycore_warning_groups_ignored_in_glm` fires when design has `@groups` set
- [ ] `surveycore_error_empty_domain` fires when active domain has zero in-domain rows
- [ ] All 7 S7 validator conditions error with the correct class
- [ ] Section 9.4 edge cases: intercept-only formula, factor predictor, interaction terms, `NA` in response with `na.action = na.omit` (rows silently dropped)
- [ ] `surveycore_error_na_in_data` (P2-21): `na.action = na.fail` with NA in response/predictor — dual pattern (`class=` + snapshot); message must list offending column(s) and NA count(s)
- [ ] `surveycore_warning_insufficient_df` (P2-15): construct a `survey_taylor` design with 3 PSUs across 2 strata (`degf = 1`) and fit a model with 3 predictors (requires `degf - 2 = -1`, clamped to 1); assert warning fires (`expect_warning(class = "surveycore_warning_insufficient_df")`), fit is still returned, and `test_glm_fit_invariants(fit)` passes (CI bounds finite)
- [ ] Internal helpers `.glm_confint()` and `.glm_score()` covered by `survey_glm()` tests (indirect testing)
- [ ] Changelog entry written and committed on this branch

**Notes:**
- `R/glm.R` contains the class definition, constructor, and all internal variance
  helpers. This is one file matching the spec's `14-glm.R` layout (semantic naming
  without the numeric prefix, per Phase 1 convention).
- Variance dispatch: use `if/else` chain with `S7::S7_inherits()` — see spec §8.1.
  No S7 method dispatch; no switch statement.
- Taylor variance: call the existing `.svy_recvar()` in `R/variance-taylor.R` via
  `.taylor_var_score_matrix()`. This reuses Phase 0 machinery — do not copy the
  function.
- Replicate variance: refit `stats::glm()` per replicate, compute `Σ c_r d_r d_r'`.
  Replicate scale factors come from `design@variables`. If a replicate refit fails to
  converge, warn `surveycore_warning_glm_convergence` and use `d_r = 0` (zero
  deviation), per spec §4.5.
- SRS variance: score-based sandwich using full `p × p` sample covariance matrix
  (`var(score_matrix)`) — **not** diagonal-only. Off-diagonal covariance terms are
  required. See spec §8.4.
- `survey_calibrated` uses the SRS sandwich path (conservative approximation).
  N is approximated as `sum(design@variables$weights)` — the calibrated weights,
  per spec §8.4.
- `.glm_confint()` is the shared CI helper called by both `confint.survey_glm_fit()`
  (PR 3) and `clean()` (PR 4). Define it in `R/glm.R` (used in 2+ files, so belongs
  at the top of the file or in `utils.R` — since all callers are within the `glm`
  file family, keep in `R/glm.R` and call from the method files via `::` or directly
  since they are in the same package). Actually per `code-style.md §4`, helpers used
  in 2+ files go in `R/utils.R`. `.glm_confint()` is called from both `glm-methods.R`
  and `glm-clean.R`, so it must live in `R/utils.R` (or `R/glm.R` with a comment
  noting the cross-file use — but the rule is explicit: 2+ files → `utils.R`). Add
  `.glm_confint()` to `R/utils.R` in this PR.
- `binomial()`/`quasibinomial()` GLM calls must be wrapped with `suppressWarnings()`
  to suppress the "non-integer #successes" warning, per spec §4.4 Step 4.
- `test-glm.R` in this PR covers `survey_glm()` only. The `clean()` test items
  (2–6 and Section 9.4 edge cases for `clean()`) are added in PR 4.
- `confint.survey_glm_fit()` is a method registered in PR 3; the underlying
  `.glm_confint()` helper is tested indirectly via `confint()` in PR 3.

---

## PR 3: S3 methods on `survey_glm_fit`

**Branch:** `feature/glm-methods`
**Depends on:** PR 2

**Files (in TDD order — tests first):**
- `tests/testthat/test-glm-methods.R` — items 1–16, 18–36 from spec §9.2 (item 17, the `print(clean(fit))` snapshot, deferred to PR 4 since `clean()` does not yet exist)
- `R/glm-methods.R` — all 20 S3 methods (`print`, `summary`, `coef`, `vcov`, `predict`, `fitted`, `residuals`, `confint`, `formula`, `terms`, `model.matrix`, `model.frame`, `deviance`, `df.residual`, `nobs`, `hatvalues`, `logLik`, `AIC`, `BIC`, `update`) + `getCall.survey_glm_fit` + `survey_glm_summary` S3 class + `print.survey_glm_summary()`
- `R/zzz.R` — `registerS3method` for all 20 methods + `getCall.survey_glm_fit` in `stats`
- `changelog/phase-2/feature-glm-methods.md` — created last, before opening PR

**Acceptance criteria:**
- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] `print()` returns `invisible(x)`; snapshot of output matches spec §5.1 format
- [ ] `summary()` returns `survey_glm_summary` S3 class; `print.survey_glm_summary()` returns `invisible(x)`; snapshot matches spec §5.2.2 format (Call block, Deviance Residuals, Coefficients table, dispersion, null/residual deviance, AIC, Design df)
- [ ] `summary()` deviance residuals use `fivenum(residuals(object@fit_, type = "deviance"))` — NOT `fivenum(object@residuals)` (working residuals)
- [ ] `summary()` with `fit_` = NULL: errors with `surveycore_error_predict_no_fit` (dual pattern: `class=` + snapshot)
- [ ] `coef()` returns `object@coefficients` (named); `vcov()` returns `object@vcov` (named matrix); row/col names match `names(coefficients)`
- [ ] `predict(type = "response")` returns fitted values; `predict(type = "link")` returns link-scale values (different from response for binomial/Poisson); `predict(type = "terms")` returns matrix
- [ ] `predict()` with NULL `fit_`: errors with `surveycore_error_predict_no_fit` (dual pattern)
- [ ] `fitted()` returns same as `predict(newdata = NULL)`
- [ ] `residuals(type = "response")`: returns `y - fitted_values` via `model.response(model.frame(object@fit_))`; correct for binomial family (values in `[-1, 1]`)
- [ ] `residuals(type = "working")`: returns `object@residuals`
- [ ] `residuals(type = "pearson"/"deviance"/"partial")`: delegates to `object@fit_`; Pearson/deviance values differ from working residuals for binomial
- [ ] All four `residuals()` `fit_`-NULL paths error with `surveycore_error_predict_no_fit` (dual pattern)
- [ ] `confint()`: returns two-column matrix with names `"2.5 %"` and `"97.5 %"` (at default 0.95); bounds match manual calculation using `.glm_confint()`; `parm` subsetting by name and index; invalid `level` errors with `surveycore_error_invalid_conf_level` (dual pattern)
- [ ] `formula()` returns `object@formula`; `terms()` and `model.matrix()` and `model.frame()` delegate to `object@fit_`; each has `fit_`-NULL error path (dual pattern)
- [ ] `deviance()` returns `object@deviance`; `df.residual()` returns `object@df_residual` (classical `n - p`, NOT design-based); `nobs()` returns `length(object@fitted_values)`
- [ ] `hatvalues()` / `logLik()` / `AIC()` / `BIC()` delegate to `object@fit_`; each has `fit_`-NULL error path (dual pattern)
- [ ] `update()` via `getCall.survey_glm_fit`: `update(fit, family = poisson())` returns a new `survey_glm_fit` with Poisson family
- [ ] `predict(fit, newdata = df_missing_col)`: `expect_error()` without `class=` (base R `stats::predict.glm()` error is already informative — "variable 'x2' was used in fitting but is not available in 'newdata'"); document in `@param newdata` that missing columns error via `stats::predict.glm()`
- [ ] Changelog entry written and committed on this branch

**Notes:**
- S3 dispatch for S7 objects requires `registerS3method()` in `.onLoad()`, identical
  to surveytidy's dplyr verb registration pattern. Do NOT use `UseMethod()`. Do NOT
  add `@export` to method functions — they are registered dynamically and use `@noRd`.
- `survey_glm_summary` is a plain named S3 list (not an S7 class). Fields:
  `coefficients` (p×4 matrix), `deviance`, `null_deviance`, `df_residual`,
  `df_null`, `dispersion`, `family`, `call`, `design_type`, `degf` — per spec §5.2.1.
- `confint.survey_glm_fit()` calls `.glm_confint()` (from `R/utils.R`, defined in PR 2).
  CI column names: `paste0(100 * c((1 - level)/2, (1 + level)/2), " %")`.
- `getCall.survey_glm_fit` must be registered in the `stats` namespace
  (not `surveycore`): `registerS3method("getCall", "survey_glm_fit", ..., envir = asNamespace("stats"))`.
- Item 17 (`print(clean(fit))` snapshot) will be added to this test file in PR 4.
  The test file is started here and extended in PR 4 — this is fine since PR 4
  squash-merges to develop separately.
- Significance stars in `print.survey_glm_summary()` follow standard R convention.

---

## PR 4: `clean()` + `broom::tidy()` shim

**Branch:** `feature/glm-clean`
**Depends on:** PR 3

**Files (in TDD order — tests first):**
- `tests/testthat/test-glm.R` — add `clean()` test items 2–6, 5a–5d from spec §9.2; add Section 9.4 edge cases for `clean()` (reference levels, label propagation, factor value labels, `n_obs`, `statistic`, `exponentiate`, broom compat)
- `tests/testthat/test-glm-methods.R` — add item 17: snapshot of `print(clean(fit))` output; verify class hierarchy; `test_glm_tidy_invariants()` passes
- `R/glm-clean.R` — `clean()`, `.build_glm_meta()`, `tidy.survey_glm_fit()` broom shim (not exported; registered conditionally)
- `R/zzz.R` — add conditional broom shim registration: `if (requireNamespace("broom", quietly = TRUE)) { registerS3method("tidy", ...) }`
- `DESCRIPTION` — add `broom` to `Suggests` (if not already present)
- `changelog/phase-2/feature-glm-clean.md` — created last, before opening PR

**Acceptance criteria:**
- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] `clean()` returns object with S3 class `c("survey_glm_tidy", "survey_result", "tbl_df", "tbl", "data.frame")`; `test_glm_tidy_invariants()` passes
- [ ] Output columns: `term`, `variable`, `var_label`, `label`, `reference_row`, `estimate`, `std_error`, `p_value`, `conf_low`, `conf_high` — always present; `statistic` present when `statistic = TRUE` (default); `n_obs` present when `n = TRUE`
- [ ] `reference_row`: `TRUE` for reference level rows when `include_reference = TRUE`; never `NA`; always `FALSE` when `include_reference = FALSE`; factor reference level detected via `setdiff(levels(col), colnames(contrasts(col)))` — NOT string prefix removal
- [ ] `label`: for factor levels, uses value labels from `design@metadata` if set, otherwise the level name recovered from `levels(model_frame[[var_name]])` by matching `paste0(var_name, l) == coef_name` — never `NA`
- [ ] `term` column for reference rows: bare factor-level term (e.g. `"sexFemale"`); no `[ref]` suffix (per spec §6.3 — the decisions log Issue 18 was reversed in v0.8)
- [ ] CIs computed via `.glm_confint()` using `model@degf - (p - 1)` df — numerically identical to `confint.survey_glm_fit()` output for the same `conf_level`
- [ ] `exponentiate = TRUE`: `estimate`, `conf_low`, `conf_high` are exponentiated; `std_error` is unchanged (log scale, per broom convention); fires `surveycore_warning_exponentiate_nonlog` when link is not log-based
- [ ] `interaction_sep` argument: interaction term `label` uses the supplied separator to join component labels
- [ ] `.meta` attribute: all 15 required top-level keys present; `$variables` has one entry per predictor (not `(Intercept)`, not interaction/transformation terms); each entry has all 7 sub-keys; `var_label` falls back to variable name when no label is set
- [ ] `meta(clean(fit))$n_observations`: equals `nrow(model.matrix(fit_))` (post-NA count); `n_weighted` = sum of weights for in-model observations
- [ ] `broom::tidy(fit)` returns same object as `clean(fit)` — `skip_if_not_installed("broom")`
- [ ] `clean()` error: `model` not `survey_glm_fit` → `surveycore_error_not_glm_fit` (dual pattern); invalid `conf_level` → `surveycore_error_invalid_conf_level` (dual pattern)
- [ ] `print(clean(fit))` uses `print.survey_result()` from Phase 1 automatically (no new print method needed); snapshot of output matches spec §6.6 format
- [ ] Changelog entry written and committed on this branch

**Notes:**
- `.build_glm_meta()` constructs the `.meta` list. Family and link: use
  `model@family$family` and `model@family$link` (strings) — NOT `class(model@family)`
  (returns `"function"`) and NOT `model@family$family()` (a function call). See spec §2.2.
- `design_type` mapping: `survey_taylor` → `"taylor"`, `survey_replicate` →
  `"replicate"`, `survey_srs` → `"srs"`, `survey_twophase` → `"twophase"`,
  `survey_calibrated` → `"calibrated"` — same mapping used by Phase 1 `.build_meta()`.
- Reference level detection: `setdiff(levels(model_frame[[var]]), colnames(contrasts(model_frame[[var]])))`.
  Do NOT use `sub()` string prefix removal — it is fragile when the variable name
  is a prefix of a level name (per spec §6.3).
- `$variables` entries: one per predictor variable referenced in the model formula.
  Excludes `(Intercept)`, interaction terms (e.g. `age:sex`), and in-formula
  transformations (e.g. `log(x)`, `poly(x, 2)`) — see spec §6.3.
- No Phase 2 `print.survey_glm_tidy()` method: inherits `print.survey_result()`
  from Phase 1 (`R/analysis-meta.R`) automatically via S3 class dispatch. A
  snapshot test of `print(clean(fit))` is still required to verify the inherited
  method works correctly.
- `broom` goes in `Suggests` (not `Imports`). Add to `DESCRIPTION` only if not
  already listed there.

---

## PR 5: marginaleffects extension interface

**Branch:** `feature/glm-marginaleffects`
**Depends on:** PR 3

**Files (in TDD order — tests first):**
- `tests/testthat/test-glm-marginaleffects.R` — all 10 test items from spec §7.7; all blocks gated with `skip_if_not_installed("marginaleffects")`
- `R/glm-marginaleffects.R` — `get_coef.survey_glm_fit`, `set_coef.survey_glm_fit`, `get_vcov.survey_glm_fit`, `get_predict.survey_glm_fit`; not exported; registered conditionally
- `R/zzz.R` — add conditional marginaleffects registration block (see spec §7.2)
- `DESCRIPTION` — add `marginaleffects` to `Suggests` (if not already present)
- `changelog/phase-2/feature-glm-marginaleffects.md` — created last, before opening PR

**Acceptance criteria:**
- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] `get_coef(fit)` returns `fit@coefficients` (`expect_identical`, not just `expect_equal`)
- [ ] `get_vcov(fit)` returns `fit@vcov` (`expect_identical`)
- [ ] `set_coef(fit, new_coefs)`: returned object has modified `@coefficients`; `fit_$coefficients` is also patched (required for `predict()` during delta method gradient computation); original `fit` is unmodified (copy-on-modify semantics)
- [ ] `get_predict(fit, newdata)`: returns data frame with `rowid` (integer) and `estimate` (numeric) columns; `nrow(result) == nrow(newdata)`
- [ ] `get_predict()` with `fit_` = NULL: errors with `surveycore_error_predict_no_fit`
- [ ] `marginaleffects::avg_slopes(fit)` for Gaussian identity: AME for continuous predictor matches OLS coefficient within `1e-6`
- [ ] `marginaleffects::avg_slopes(fit)` for binomial: result on probability scale (values in `(-1, 1)`); differs from log-odds coefficient
- [ ] `marginaleffects::avg_predictions(fit)` for binomial: `estimate` values in `[0, 1]`
- [ ] Package works correctly with `marginaleffects` not installed (all 4 extension methods simply not registered; no errors)
- [ ] Changelog entry written and committed on this branch

**Notes:**
- All four methods are registered conditionally in `.onLoad()` using
  `requireNamespace("marginaleffects", quietly = TRUE)` — same pattern as broom shim.
- `set_coef.survey_glm_fit` must patch **both** `model@coefficients` (S7 property)
  AND `model@fit_$coefficients` (raw `glm` object). Without the `fit_` patch,
  `stats::predict.glm()` reads stale coefficients and marginaleffects' numerical
  gradient is silently wrong (all AMEs would be zero).
- `get_predict` always uses `type = "response"` — marginaleffects operates on the
  response scale.
- PR 5 depends on PR 3 (not PR 4) since it only needs `predict.survey_glm_fit()`
  (defined in PR 3), not `clean()`.

---

## PR 6: Numerical oracle tests vs `survey::svyglm()`

**Branch:** `feature/glm-numerical-tests`
**Depends on:** PR 4 and PR 5 (all Phase 2 R source complete; PR 5 must be merged before cutting this branch so `test-glm-marginaleffects.R` is present in `devtools::check()`)

**Files (in TDD order — tests first):**
- `tests/testthat/test-glm-numerical.R` — all oracle tests from spec §9.1: all 5 design classes × all 8 GLM families (where applicable), degf validation, programmatic interface identity check, SRS full meat matrix check (multi-predictor), domain estimation oracle; all blocks gated with `skip_if_not_installed("survey")`, domain test also `skip_if_not_installed("surveytidy")`
- `changelog/phase-2/feature-glm-numerical-tests.md` — created last, before opening PR

**Acceptance criteria:**
- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] Coefficient oracle: all 5 design classes, Gaussian family — `coef(fit_sc)` matches `coef(fit_sv)` within `1e-10`
- [ ] SE oracle: all 5 design classes, Gaussian family — `sqrt(diag(vcov(fit_sc)))` matches `SE(fit_sv)` within `1e-8`
- [ ] CI oracle: all 5 design classes — CI bounds match within `1e-6`
- [ ] PSD check: `all(eigen(vcov(fit))$values >= -1e-10)` for all oracle fits (all 5 design classes)
- [ ] Family oracle for Taylor design, all 8 families: `gaussian(identity)`, `binomial(logit)`, `Gamma(inverse)`, `inverse.gaussian(1/mu^2)`, `quasi(identity, constant)`, `quasibinomial(logit)`, `poisson(log)`, `quasipoisson(log)` — coefficients within `1e-10`, SEs within `1e-8`. Binomial oracle uses `quasibinomial()` on the `survey::svyglm()` side to suppress "non-integer successes" warning.
- [ ] Programmatic interface identity: `survey_glm(d, response = "y", predictors = c("x1", "x2"))` vs `survey_glm(d, y ~ x1 + x2)` — coefficients within `1e-15`, vcov within `1e-15`
- [ ] SRS full meat matrix: `y ~ x1 + x2` on SRS design — SEs match within `1e-8` (validates off-diagonal covariance terms from spec §8.4 and Issue 17 fix)
- [ ] `.degf()` oracle: matches `survey::degf()` for all 5 design classes within `1e-10`
- [ ] Domain estimation oracle: `surveytidy::filter()` domain coefficients and SEs match `survey::svyglm(..., subset = domain_indicator)` within standard tolerances
- [ ] Changelog entry written and committed on this branch

**Notes:**
- All oracle tests use `skip_if_not_installed("survey")` at the block level (not
  file level), per `testing-surveycore.md §skip_if_not_installed`.
- Binomial oracle: surveycore calls `binomial(link = "logit")`; `survey::svyglm()`
  is called with `quasibinomial(link = "logit")` to suppress the "non-integer
  #successes" warning. Coefficients and SEs are identical — the Binder sandwich
  does not depend on the dispersion parameter.
- Poisson oracle requires integer count response. Use `make_survey_data(seed = 42)`
  with `rpois(n, lambda = exp(0.3 * y1 + 0.5))` for the response, per spec §9.1
  Poisson template.
- `survey_calibrated` oracle: build using `make_survey_data(seed = 42)` +
  `survey::calibrate()` + `from_svydesign()`. Conservative SRS sandwich is used —
  exact match to `survey::svyglm()` is not expected; verify the design is accepted
  without error and that SEs are positive finite.
- The domain estimation oracle requires `surveytidy` installed. Gate with
  `skip_if_not_installed("surveytidy")` in addition to `skip_if_not_installed("survey")`.
- This PR is test-only (no R source files changed). `devtools::check()` is still
  required to confirm no regressions.
- Note: spec §9.1 references `.degf()` test as "Issue 26 test plan" — this refers
  to an internal spec drafting note; the actual item is the degf oracle test described
  in the last paragraph of §9.1.
- **Domain oracle placement:** The domain estimation oracle lives in `test-glm.R` (added in PR 2, item 11) — do NOT add a duplicate in `test-glm-numerical.R`. This departs from spec §9.1's file assignment but avoids DRY violation.

---

## Cross-cutting implementation notes

### `R/zzz.R` evolution across PRs

`R/zzz.R` is updated in PRs 2, 3, 4, and 5. Each PR adds to `.onLoad()`. Final
`.onLoad()` in PR 5 will contain all of:

```r
.onLoad <- function(libname, pkgname) {
  S7::methods_register()  # Phase 0 — must remain

  # Phase 2: survey_glm_fit S3 methods
  registerS3method("print",       "survey_glm_fit", print.survey_glm_fit,       envir = asNamespace("base"))
  registerS3method("summary",     "survey_glm_fit", summary.survey_glm_fit,     envir = asNamespace("base"))
  registerS3method("coef",        "survey_glm_fit", coef.survey_glm_fit,        envir = asNamespace("stats"))
  registerS3method("vcov",        "survey_glm_fit", vcov.survey_glm_fit,        envir = asNamespace("stats"))
  registerS3method("predict",     "survey_glm_fit", predict.survey_glm_fit,     envir = asNamespace("stats"))
  registerS3method("fitted",      "survey_glm_fit", fitted.survey_glm_fit,      envir = asNamespace("stats"))
  registerS3method("residuals",   "survey_glm_fit", residuals.survey_glm_fit,   envir = asNamespace("stats"))
  registerS3method("confint",     "survey_glm_fit", confint.survey_glm_fit,     envir = asNamespace("stats"))
  registerS3method("formula",     "survey_glm_fit", formula.survey_glm_fit,     envir = asNamespace("stats"))
  registerS3method("terms",       "survey_glm_fit", terms.survey_glm_fit,       envir = asNamespace("stats"))
  registerS3method("model.matrix","survey_glm_fit", model.matrix.survey_glm_fit,envir = asNamespace("stats"))
  registerS3method("model.frame", "survey_glm_fit", model.frame.survey_glm_fit, envir = asNamespace("stats"))
  registerS3method("deviance",    "survey_glm_fit", deviance.survey_glm_fit,    envir = asNamespace("stats"))
  registerS3method("df.residual", "survey_glm_fit", df.residual.survey_glm_fit, envir = asNamespace("stats"))
  registerS3method("nobs",        "survey_glm_fit", nobs.survey_glm_fit,        envir = asNamespace("stats"))
  registerS3method("hatvalues",   "survey_glm_fit", hatvalues.survey_glm_fit,   envir = asNamespace("stats"))
  registerS3method("logLik",      "survey_glm_fit", logLik.survey_glm_fit,      envir = asNamespace("stats"))
  registerS3method("AIC",         "survey_glm_fit", AIC.survey_glm_fit,         envir = asNamespace("stats"))
  registerS3method("BIC",         "survey_glm_fit", BIC.survey_glm_fit,         envir = asNamespace("stats"))
  registerS3method("update",      "survey_glm_fit", update.survey_glm_fit,      envir = asNamespace("stats"))
  registerS3method("getCall",     "survey_glm_fit", getCall.survey_glm_fit,     envir = asNamespace("stats"))

  # Phase 2: broom compatibility (conditional)
  if (requireNamespace("broom", quietly = TRUE)) {
    registerS3method("tidy", "survey_glm_fit", tidy.survey_glm_fit,
                     envir = asNamespace("broom"))
  }

  # Phase 2: marginaleffects extension (conditional)
  if (requireNamespace("marginaleffects", quietly = TRUE)) {
    registerS3method("get_coef",    "survey_glm_fit", get_coef.survey_glm_fit,
                     envir = asNamespace("marginaleffects"))
    registerS3method("set_coef",    "survey_glm_fit", set_coef.survey_glm_fit,
                     envir = asNamespace("marginaleffects"))
    registerS3method("get_vcov",    "survey_glm_fit", get_vcov.survey_glm_fit,
                     envir = asNamespace("marginaleffects"))
    registerS3method("get_predict", "survey_glm_fit", get_predict.survey_glm_fit,
                     envir = asNamespace("marginaleffects"))
  }
}
```

### Internal helper placement

Per `code-style.md §4`: helpers used in 2+ source files go in `R/utils.R`.

| Helper | Used in | Placement |
|---|---|---|
| `.glm_score()` | `R/glm.R` only (variance dispatch lives there) | Top of `R/glm.R` |
| `.glm_sandwich_vcov()` | `R/glm.R` only | Top of `R/glm.R` |
| `.glm_confint()` | `R/glm-methods.R` (confint) + `R/glm-clean.R` (clean) | `R/utils.R` |
| `.glm_degrees_of_freedom()` | `R/glm.R` only | Top of `R/glm.R` |
| `.taylor_var_score_matrix()` | `R/glm.R` only | Top of `R/glm.R` |
| `.build_glm_meta()` | `R/glm-clean.R` only | Top of `R/glm-clean.R` |

### Quality gates (from spec §XI)

All must pass before Phase 2 is marked complete:
- `devtools::check()` 0 errors, 0 warnings, ≤2 notes
- Coefficient oracle tests for all 5 design classes within tolerances (1e-10 point, 1e-8 SE)
- Family oracle tests for all 8 GLM families (Taylor design) within tolerances
- `@vcov` PSD for all oracle fits: `all(eigen(vcov(fit))$values >= -1e-10)`
- `clean()` correct columns, class, `.meta` for all design types
- All 20 S3 methods functional
- All 21 Phase 2 error/warning classes tested (19 new + 2 reused from Phase 1; P2-1 through P2-21 from spec §X)
- Test coverage ≥ 98% for all new Phase 2 files
- `plans/error-messages.md` updated (PR 1)
- All 4 marginaleffects extension methods registered and functional

---

*Plan drafted from spec v1.0 and decisions log 2026-03-08.*
*Stage 2 adversarial review complete (2026-03-08). Stage 3 issues resolved (2026-03-08). Ready for `/r-implement`.*
