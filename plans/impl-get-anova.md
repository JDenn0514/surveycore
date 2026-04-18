# Implementation Plan: `get_anova()` + `anova.survey_glm_fit()`

**ID:** get-anova
**Spec:** `plans/spec-get-anova.md` (v0.6, Approved)
**Status:** PR A and PR B merged to `develop`; PR C in progress

---

## Overview

This plan delivers the design-based ANOVA family for `survey_glm_fit` objects:
`get_anova()` (primary user-facing API), `anova.survey_glm_fit()` (thin S3
wrapper registered dynamically in `.onLoad()`), a `survey_anova` S3 result
class with its print method, and all internal helpers. The work is decomposed
into three PRs to keep diffs reviewable and to isolate dependency-bearing
changes (`@term_assign`, vendored saddlepoint) from the ANOVA surface itself.

---

## PR Map

- [x] **PR A** — `feature/survey-glm-fit-term-assign` (merged #94): add
  `@term_assign` integer-vector property to `survey_glm_fit`; populate from
  `attr(model.matrix(fit), "assign")` at construction. Pre-requisite for
  serialization-safe Wald and for `idx` resolution in `.reg_term_test()`.
- [x] **PR B** — `feature/variance-vendored-saddlepoint` (merged #93): vendor
  `.saddle()`, `.pchisqsum_sad()`, `.pFsum_sad()` from
  `survey/R/pchisqsum.R` @ 4.4-8 into `R/variance-vendored-saddlepoint.R`;
  parity tests vs `survey::pchisqsum()` / `survey::pFsum()` at `1e-10`.
- [ ] **PR C** — `feature/get-anova`: implement `get_anova()`,
  `anova.survey_glm_fit()`, `print.survey_anova()`, internal helpers
  (`.reg_term_test()`, `.anova_sequential()`, `.refit_drop_terms()`,
  `.anova_compare()`, `.anova_design_label()`, `.anova_design_df_string()`),
  full test suite, numerical oracles, error-table rows A-2 through A-20.

PR C is the subject of the task list below.

---

## PR C: `get_anova()` Implementation

**Branch:** `feature/get-anova`
**Depends on:** PR A (shipped), PR B (shipped)

### Files

Created:
- `R/glm-anova.R` — `get_anova()`, `anova.survey_glm_fit()`,
  `print.survey_anova()`, `.reg_term_test()`, `.anova_sequential()`,
  `.refit_drop_terms()`, `.anova_compare()`, `.anova_design_label()`,
  `.anova_design_df_string()`.
- `tests/testthat/test-glm-anova.R` — happy paths, error paths, edge cases,
  print snapshots, meta contract.
- `tests/testthat/test-glm-anova-numerical.R` — oracle tests vs
  `survey::anova.svyglm()`.
- `changelog/get-anova/pr-c-get-anova.md` — written last, before opening PR.

Modified:
- `plans/error-messages.md` — add rows A-2, A-3, A-4, A-5, A-7, A-8, A-9,
  A-10, A-11, A-12, A-13, A-14, A-15, A-16, A-17, A-18, A-19, A-20.
  (A-1 is reused from row 75; A-6 is retired and gets no row.)
- `R/analysis-helpers.R` — add `ANOVA_META_KEYS` constant.
- `R/zzz.R` — register `anova.survey_glm_fit` via `registerS3method()` in
  `.onLoad()`, following the existing `*.survey_glm_fit` pattern.
- `CLAUDE.md` — update Implementation Status table to add `get_anova()`.

---

### Step-by-Step Tasks

#### Infrastructure

- [ ] **Task 1.0** — Precondition check. Verify on the `develop` branch:
  (1) `survey_glm_fit@term_assign` property exists (PR A, #94 merged); and
  (2) `R/variance-vendored-saddlepoint.R` defines `.pchisqsum_sad()` and
  `.pFsum_sad()` (PR B, #93 merged). If either is missing, stop — PR C
  depends on both.

- [ ] **Task 1.1** — Append 18 new rows to `plans/error-messages.md` for the
  new error/warning classes A-2 through A-20 using the message templates
  from §VI of the spec verbatim. Retire A-6 per the spec's note (no row
  added). Reused `surveycore_error_not_glm_fit` (A-1), `invalid_decimals`,
  and `invalid_name_style` get no new rows. Commit this file change alone
  on the branch.

- [ ] **Task 1.2** — In `R/analysis-helpers.R`:
  1. Alongside the existing meta-key constants (after `PAIRWISE_META_KEYS`),
     add:
     ```r
     ANOVA_META_KEYS <- c("model", "method", "test", "terms")
     ```
  2. Factor the `decimals` and `name_style` validation branches out of
     `.validate_shared_args()` into a new internal helper
     `.validate_decimals_namestyle(decimals, name_style)`; have
     `.validate_shared_args()` delegate to it. `get_anova()` will call the
     smaller helper directly (it has no `variance` / `conf_level` surface).
     Keep the existing `surveycore_error_invalid_decimals` /
     `surveycore_error_invalid_name_style` classes.
  3. **Regression gate (BLOCKING before Task 1.3):** after the refactor,
     run `devtools::test(filter = "get-")` (covers all existing `get_*()`
     tests — `get-freqs`, `get-means`, `get-totals`, `get-corr`,
     `get-quantiles`, `get-ratios`, `get-t-test`, `get-pairwise`, etc.).
     All must pass GREEN. If any red, the refactor changed behavior of a
     load-bearing shared helper; fix before proceeding. This gate catches
     subtle breakage (error-class order, `call = rlang::caller_env()`
     capture, which arg triggers which class in mixed-bad-input
     scenarios) before it masks ANOVA-specific failures in Cycle A.

- [ ] **Task 1.3** — In `R/zzz.R`, add a `registerS3method("anova",
  "surveycore::survey_glm_fit", anova.survey_glm_fit, envir =
  asNamespace("stats"))` call inside `.onLoad()`, placed next to the other
  `*.survey_glm_fit` registrations. (The function itself is defined in
  the next task; the registration block references it by name.)
  **Do not commit this change separately from Task 3.2** —
  `devtools::load_all()` / `.onLoad()` will fail with
  `object 'anova.survey_glm_fit' not found` until Task 3.2 defines it.

---

#### TDD Cycle A — `.reg_term_test()` + sequential mode

- [ ] **Task 2.1** — Create `tests/testthat/test-glm-anova.R`. Write the
  sequential-mode test blocks. Error-class blocks use the dual pattern
  (`expect_error(class = ...)` + `expect_snapshot(error = TRUE)`).

  **Happy path — sequential mode:**
  - `get_anova(fit)` returns a tibble with S3 class
    `c("survey_anova", "survey_result", "tbl_df", "tbl", "data.frame")`
  - Column order: `term`, `statistic`, `df`, `ddf`, `deff`, `p_value`,
    `stars` — all present regardless of `method`/`test` combination
  - Term order in output matches formula term-label order (leftmost first)
  - Matrix of method × test (four combos), verifying the NA pattern from
    §3.7 Output Contract:
    - `LRT`+`F` (default): `ddf` finite, `deff` finite
    - `LRT`+`Chisq`: `ddf == NA_real_`, `deff` finite
    - `Wald`+`F`: `ddf` finite, `deff == NA_real_`
    - `Wald`+`Chisq`: both `ddf` and `deff` are `NA_real_`
  - Single-term model (`y ~ x`): one result row
  - Interaction model (`y ~ a * b`): exactly 3 rows in order `a`, `b`, `a:b`
  - Binomial family fit: all four method × test combos run without error
  - `name_style = "broom"` renames: `p_value` → `p.value`,
    `ddf` → `df_residual`; `statistic` and `df` unchanged
  - `name_style = "broom"` label preservation: `attr(result$p.value,
    "label")` equals `"P-Value"` and `attr(result$df_residual, "label")`
    equals `"Denom df"`. Proves labels attached under surveycore column
    names survive `.apply_name_style()` rename — regression guard in case
    `.apply_name_style()` is ever refactored in a way that drops
    attributes.
  - `decimals = 2` rounds all double columns
  - Column-level `label` attributes: `term` → `"Term"`,
    `statistic` → one of `"Wald-F"`/`"Wald-χ²"`/`"LRT-F"`/`"LRT-χ²"` based
    on `(method, test)`, `df` → `"df"`, `ddf` → `"Denom df"`,
    `deff` → `"DEff"`, `p_value` → `"P-Value"`, `stars` → `""`
  - `label_vars = TRUE` — plain term with variable label in metadata:
    that cell's `attr(col, "label")` equals the stored label
  - `label_vars = TRUE` — plain term missing from metadata: falls back to
    raw term string; no `label` attribute set on that cell
  - `label_vars = TRUE` — two-way interaction with both component labels:
    composed label uses ` × ` separator (e.g., `"Age in years × Sex"`)
  - `label_vars = TRUE` — two-way interaction with a missing component
    label: falls back to raw `"a:b"` string
  - `label_vars = TRUE` — three-way interaction (`y ~ age * sex * race`)
    with all three labels: composed label is `"Age × Sex × Race"` in
    formula component order (Pass 2 Issue 20 regression)
  - Cross-design smoke tests: one sequential happy-path block for each of
    `survey_taylor`, `survey_replicate`, `survey_twophase`, `survey_nonprob`,
    `survey_srs`, constructed via `make_all_designs()` (see
    `tests/testthat/helper-test-data.R:472`). The returned list has elements
    `taylor / replicate / twophase / calibrated / srs` — `calibrated` is the
    `survey_nonprob` fixture. Iterate with a for-loop or one explicit block
    per design. **The `survey_nonprob` block must wrap the `get_anova()`
    call in `expect_warning(result <- get_anova(...), class = "surveycore_warning_nonprob_inference")`**
    (§3.6 step 6a fires A-14 once per call).

  **Error paths — sequential mode:**
  - A-1 (`surveycore_error_not_glm_fit`, reused): `get_anova("not a fit")`
  - A-4 (`surveycore_error_null_with_lrt`): `method = "LRT"` with non-NULL
    `null`
  - A-9 (`surveycore_error_insufficient_df_for_anova`): `fit@degf = 2` with
    5 coefficients (construct via `make_survey_data()` and truncated design)
  - A-10 (`surveycore_error_null_length_mismatch`): `method = "Wald"`,
    `null = c(0, 0)` on a term whose `q == 1`
  - A-11 (`surveycore_error_lrt_requires_fit_object`): sequential LRT with
    `fit@fit_` set to `NULL`
  - A-17 (`surveycore_error_no_terms_to_test`): intercept-only model
    (`y ~ 1`)
  - A-18 (`surveycore_error_invalid_tolerance`): four separate triggers —
    `tolerance = "1e-5"` (non-numeric), `tolerance = c(1e-5, 1e-6)` (length
    ≠ 1), `tolerance = NA_real_` (non-finite), `tolerance = -1` (negative)
  - A-20 (`surveycore_error_domain_mismatch`): fit the full model, then
    overwrite `fit@design@data$..surveycore_domain..` on the stored fit
    via a new test-only helper `.testhelper_clobber_domain(fit, value)` in
    `helper-test-data.R` that uses
    `S7::set_props(fit, design = S7::set_props(fit@design, data = df2))`
    to replace the design's `@data` slot. Call `get_anova(fit)` and assert
    the typed error from `.refit_drop_terms()`.
  - Invalid `decimals` (reused `surveycore_error_invalid_decimals`)
  - Invalid `name_style` (reused `surveycore_error_invalid_name_style`)

  **Warnings — sequential mode:**
  - A-8 (`surveycore_warning_saddlepoint_fallback`): tested at two layers:
    (a) **direct unit test** on the vendored saddlepoint helper — call
    `.pchisqsum_sad(x = 0.5, lambda = c(1, 1e-16), df = c(1, 1), ...)`;
    the extreme eigenvalue spread drives `.saddle()` past its iteration
    cap and returns `NA`, which `.pchisqsum_sad()` handles via the
    Satterthwaite fallback. This is a deterministic trigger for the
    helper itself. (b) **integration test** via `get_anova()` on a fit
    whose `V0[idx, idx]` has eigenvalues spanning ≥ 14 orders of
    magnitude, constructed by a collinear-but-not-singular interaction
    (see inline recipe in the test file). Assert warning class via
    `expect_warning(class = ...)` and `expect_snapshot(warn = TRUE)` on
    the integration layer only (direct helper test does not snapshot).
  - A-13 (`surveycore_warning_singular_v0`): construct deterministically
    via a factor interaction with a combination containing exactly one
    observation in the design — e.g., `df$rare <- c(rep("A", 49),
    "B")`; `y ~ rare * group`. The `rare:group` interaction has a cell
    with `n = 1`, guaranteeing `V0[idx, idx]` is exactly singular (zero
    eigenvalue). Assert the warning fires and that `lambda` is still
    finite (confirms `MASS::ginv()` fallback path).
  - A-14 (`surveycore_warning_nonprob_inference`): fits on a
    `survey_nonprob` design; fires exactly once per `get_anova()` call
  - A-15 (`surveycore_warning_negative_deviance_diff`): both sides of the
    roundoff band — (a) tiny negative diff within
    `sqrt(.Machine$double.eps) * abs(model@deviance)`: no warning, clamps
    silently; (b) negative diff outside tolerance: warning fires and
    clamps to 0
  - A-19 (`surveycore_warning_replicate_nonconvergence`): constructed via
    a new fixture `make_replicate_nonconverger()` in
    `tests/testthat/helper-test-data.R`. Recipe: 50-row dataset with a
    binary factor where the rare level appears in exactly one PSU; JK1
    design with `n_strata = n_psu` so the rare-level PSU is dropped in one
    replicate; `binomial(logit)` GLM where the rare level is the only
    positive case — guaranteed quasi-separation on the dropped replicate,
    deterministic across BLAS libraries. Note: `survey::svyglm.svyrep.design`
    does not emit a typed warning for this case, so A-19 is original
    surveycore behavior (no oracle available). Assert: warning fires once
    per affected refit (not once per replicate)

  **Edge cases — sequential mode:**
  - Domain-filtered design: sequential refits inherit the
    `..surveycore_domain..` column; no NAs leak; `.refit_drop_terms()`'s
    A-20 assertion passes
  - Non-default contrasts: use
    `withr::local_options(contrasts = c("contr.sum", "contr.poly"))` to
    scope the change to the test block. Sequential refit produces a
    coherent ANOVA table; no error or warning fires; term-to-column
    mapping via `@term_assign` is stable (Issue 4 regression)
  - `test = "Chisq"`: `ddf` column is `NA_real_` on every row
  - `method = "Wald"`: `deff` column is `NA_real_` on every row
  - `null` vector of the correct length runs clean in Wald mode

  **Meta contract — sequential mode:**
  - `meta(result)` contains: `design_type`, `replicate_type`, `n_respondents`,
    `call`, `model`, `method`, `test`, `terms`
  - `meta(result)$replicate_type` is `NA_character_` for non-replicate,
    length-1 string (e.g., `"BRR"`) for replicate
  - `meta(result)$terms` is a list of length `nrow(result)`; each sub-list
    has keys `raw_chisq`, `lambda`, `ddf_used`, `test_terms`
  - `meta(result)$model$formula` is the stored formula object
  - `meta(result)$model$family`, `$link`, `$n_obs`, `$coefficients` match
    the fit

  **Print snapshots — sequential mode:**
  - Taylor + `LRT`/`F` + `decimals = 3` (canonical example from §3.9):
    three-line header, tibble body, `stars` column rendered once
  - Taylor + `Wald`: `deff` column is **absent** from the printed body;
    `"deff" %in% names(result)` still `TRUE` (Pass 2 Issue 18 regression
    for the `NextMethod()` rebinding bug)
  - BRR replicate + `LRT`/`F`: `# Design:` line reads
    `Replicate weights (BRR)` (§3.9.1 rendering table)

- [ ] **Task 2.2** — Run `devtools::test(filter = "test-glm-anova")`. Confirm
  all blocks fail with "could not find function 'get_anova'" or similar.
  Document the failure count before proceeding.

- [ ] **Task 3.1** — Create `R/glm-anova.R`. Implement in this order:
  1. `.reg_term_test(model, test.terms, method, test, null, ddf, reduced,
     tolerance)` per §V.1. Both scalar-character and formula-RHS input
     forms; `idx` resolution via `@term_assign`; canonical-order term
     matching; n-invariance defensive
     `stopifnot(length(model@weights) == length(reduced@weights))` per §V.1
     step 5 (the primary rownames-identity A-12 check lives in
     `.anova_sequential()` and `.anova_compare()`, not here); roundoff-
     band negative-deviance handling (§3.3.2); `rcond(V0) < tolerance`
     branching with `MASS::ginv()` fallback and A-13 warning; saddlepoint
     failure returns `NA` → χ²(q) fallback + A-8 warning; returns a list
     with `term`, `statistic`, `df`, `ddf`, `deff`, `p_value`, `raw_chisq`,
     `lambda`, `ddf_used`, `test_terms`.
  2. `.refit_drop_terms(model, drop_terms)` per §V.3. `update.formula()`
     + `as.formula(". ~ . -", paste(drop_terms, collapse = " - "))`;
     family reconstruction via `do.call(stats::family, ...)` for the
     `as.list(family)` stored-form case; `na.action` threading from
     `model@call$na.action`; `quiet = TRUE` scoped to the `survey_glm()`
     call only; A-20 defensive check comparing `..surveycore_domain..`
     between `model@design@data` and `reduced@design@data`.
  3. `.anova_sequential(model, method, test, null, tolerance, ddf_raw)` per
     §3.4. Right-to-left loop over `attr(terms(model@formula), "term.labels")`;
     per-step refit via `.refit_drop_terms()`; n-invariance check via
     `identical(rownames(model.frame(reduced@fit_)),
     rownames(model.frame(current_model@fit_)))` → A-12 on mismatch;
     stack rows and reverse to restore formula order.
  4. `get_anova()` per §3.6 execution flow. Entry-point validation (type
     check, `method`/`test` `match.arg()`, `null` type check, A-4 LRT+null
     guard, A-11 serialization guard, A-9 insufficient-df guard, A-14
     nonprob warning, A-18 `tolerance` validation,
     `.validate_decimals_namestyle()` for `decimals`/`name_style`). Mode dispatch via `is.null(model2)`.
     Post-dispatch ordering: `.apply_decimals()` → attach column labels per
     §3.7.3 (using surveycore column names: `term`, `statistic`, `df`,
     `ddf`, `deff`, `p_value`, `stars`; `statistic` label picked by
     `(method, test)`) → `.apply_name_style()` (preserves
     `attr(col, "label")`) → `.build_meta()` → `.make_result_tibble()` with
     `ANOVA_META_KEYS`. Labels must be attached **before** `.apply_name_style()`
     so the label loop keys on surveycore column names; this matches the
     idiom used by other `get_*()` functions.
  5. `print.survey_anova()` per §3.9 pseudocode. Three-line header with
     `method_label`/`test_label` `switch()`, `deparse1(m$model$formula)`,
     `.anova_design_label()`, `.anova_design_df_string()`, `N` formatted
     via `format(..., big.mark = ",")`. Wald-branch `deff` suppression via
     local rebinding + `class(x) <- setdiff(class(x), c("survey_anova",
     "survey_result"))` + explicit `print(x, ...)` — **not** `NextMethod()`
     (Pass 2 Issue 18).
  6. `.anova_design_label(design_type, replicate_type)` per §3.9.1 table.
  7. `.anova_design_df_string(x)` per §3.9.2.

  Add roxygen2 blocks for `get_anova()` (`@export`, `@family analysis`,
  `@param` for all arguments, `@return`, `@examples` using `gss_2024` per
  CLAUDE.md convention; wrap `survey_glm()` calls appropriately). Mark
  internals `@keywords internal` + `@noRd`.

- [ ] **Task 3.2** — Implement `anova.survey_glm_fit()` per §IV.1. Signature
  matches `anova()`: `function(object, ..., method = "LRT", test = "F",
  null = NULL)`. Dispatches to `get_anova()`; A-7
  (`surveycore_error_anova_bad_dots`) fires when `length(others) > 1` or
  when the extra argument is not a `survey_glm_fit`.

- [ ] **Task 3.3** — Run `devtools::document()`. Verify `NAMESPACE` exports
  `get_anova` (but **not** `anova.survey_glm_fit` — it is registered
  dynamically in `.onLoad()`, matching the `R/glm-methods.R` pattern).
  Verify `man/get_anova.Rd` is generated and renders the `@examples`
  block.

- [ ] **Task 3.4** — Run `devtools::test(filter = "test-glm-anova")`. Confirm
  all sequential-mode blocks pass GREEN. Fix any failures before
  proceeding.

---

#### TDD Cycle B — `.anova_compare()` + comparison mode

- [ ] **Task 4.1** — Append comparison-mode tests to
  `tests/testthat/test-glm-anova.R`.

  **Happy path — comparison mode:**
  - `get_anova(fit_small, fit_big)` returns a `survey_anova` tibble with
    exactly 1 row
  - Argument-order invariance: `get_anova(fit_small, fit_big)` and
    `get_anova(fit_big, fit_small)` produce identical rows (bigger model
    detected regardless of order)
  - `term` column reads `"added_terms | base_terms"` (e.g.,
    `"educ + race | age + sex"`)
  - `anova(fit1, fit2)` S3 method produces the same result as
    `get_anova(fit1, fit2)`
  - Cross-design smoke tests: one comparison-mode happy-path block for
    each of `survey_taylor`, `survey_replicate`, `survey_twophase`,
    `survey_nonprob`, `survey_srs`, constructed via `make_all_designs()`
    (`calibrated` slot is the `survey_nonprob` fixture). **The
    `survey_nonprob` block must wrap the `get_anova()` call in
    `expect_warning(... , class = "surveycore_warning_nonprob_inference")`.**

  **Error paths — comparison mode:**
  - A-2 (`surveycore_error_models_not_nested`): two fits with
    non-overlapping term sets
  - A-3 (`surveycore_error_response_mismatch`): two fits with different
    LHS
  - A-5 (`surveycore_error_design_mismatch`), **two separate test_that()
    blocks**:
    (a) "fires when `@data` differs": two fits on designs with different
        `@data` or `@variables` slots (but same shape); assert the typed
        error fires.
    (b) "does NOT fire when only `@metadata@transformations` differ"
        (Pass 3 Issue 71 regression): construct two `as_survey()` calls
        that produce the same `@data`/`@variables` but distinct
        transformation histories; the comparison must succeed with no
        error.
  - A-7 (`surveycore_error_anova_bad_dots`): `anova(fit, fit2, fit3)` and
    `anova(fit, "not a fit")`
  - A-11 (`surveycore_error_lrt_requires_fit_object`), **comparison
    branch**: `get_anova(fit_stripped, fit_live, method = "Wald")` where
    `fit_stripped@fit_` has been set to `NULL`; same with `method =
    "LRT"`. Both side/method combinations (Pass 2 Issue 16 regression)
  - A-12 (`surveycore_error_n_mismatch`): two fits on the same design but
    different row subsets. Construct by calling `.testhelper_clobber_domain()`
    (defined in Task 2.1) on one of the two fits to produce a mismatched
    row-count slice; do not reinvent the `S7::set_props()` chain.
  - A-16 (`surveycore_error_identical_term_sets`): `get_anova(fit, fit)`

  **Meta contract — comparison mode:**
  - `meta(result)$terms[[1]]$added_terms` is the character vector
    `setdiff(bigger_terms, reduced_terms)` verbatim (Pass 3 Issue 62 —
    round-trippable programmatic access; spaces + colons not split)
  - `meta(result)$model2` is present with the same shape as `meta$model`

- [ ] **Task 4.2** — Run `devtools::test(filter = "test-glm-anova")`. Confirm
  new comparison-mode blocks fail RED.

- [ ] **Task 5.1** — Add `.anova_compare(model, model2, method, test, null,
  tolerance)` to `R/glm-anova.R` per §V.4. Symbolic-nesting detection,
  A-16 identical-term-set guard, A-3 response check, A-5 design check
  (content-based: compare `@data` and `@variables` only), A-11
  comparison-mode serialization guard (fires for both LRT and Wald when
  either `@fit_` is NULL — Pass 2 Issue 16), A-12 row-identifier check,
  `stopifnot(all.equal(bigger@degf, reduced@degf))` (Issue 40),
  `reformulate(termdiff)[[2L]]` construction, delegate to
  `.reg_term_test(bigger, test.formula, method, test, null, ddf = ddf,
  reduced = reduced, tolerance = tolerance)`. The comparison-mode row
  carries `added_terms` in its `.meta$terms[[1]]` sub-list.

  Wire `get_anova()`'s mode-dispatch step (§3.6 step 8) to call
  `.anova_compare()` when `model2` is non-NULL.

- [ ] **Task 5.2** — Run `devtools::test(filter = "test-glm-anova")`. Confirm
  all tests pass GREEN (sequential + comparison). Fix any failures.

---

#### Numerical Oracle Tests

- [ ] **Task 6.1** — Create `tests/testthat/test-glm-anova-numerical.R`. All
  blocks guarded by `skip_if_not_installed("survey")`. Tolerances per
  `.claude/rules/testing-surveycore.md` and spec §VII: `1e-8` on
  statistic, `1e-6` on p-value.

  Tests (one `test_that()` per cell):

  **Taylor sequential:**
  - `nhanes_2017`, `bpxsy1 ~ ridageyr + riagendr`, `method = "LRT"`,
    `test = "F"` (default): `statistic` and `p_value` match
    `survey::anova.svyglm(fit_sv, method = "LRT", test = "F")` on every row
  - Same fit, `method = "LRT"`, `test = "Chisq"`
  - Same fit, `method = "Wald"`, `test = "F"`
  - Same fit, `method = "Wald"`, `test = "Chisq"`

  **Taylor comparison:**
  - Nested comparison on `nhanes_2017`, `method = "LRT"`, `test = "F"`:
    the `statistic` and `p_value` for the single comparison row match
    `survey::anova.svyglm(fit_big_sv, fit_small_sv, method = "LRT",
    test = "F")`
  - Same comparison, `method = "Wald"`, `test = "Chisq"`

  **BRR replicate oracle:** on `acs_pums_wy` (or an equivalent BRR design),
  `method = "LRT"`, `test = "F"`: parity with `survey::anova.svyglm()` at
  `1e-6`/`1e-8`.

  **Fay-BRR oracle:** `make_survey_data(type = "fay")` does NOT encode
  ρ = 0.3 (its Fay branch is a lognormal-perturbed BRR clone — verified
  against `helper-test-data.R:181-201`). So the oracle must construct
  Fay-adjusted replicate weights inline, feed them to surveycore as a
  pre-computed replicate-weight matrix, and compare against
  `survey::svrepdesign(..., type = "Fay", rho = 0.3)`.

  Recipe (inline in the test block, ρ = 0.3):
  1. Build a base stratified-BRR Hadamard matrix `H` of ±1 values over
     strata via `survey:::hadamard.test()` or an equivalent constructor;
     dimensions `n × R` where `R = n_psu %/% 2`.
  2. Compute Fay-adjusted replicate weights:
     `w_rep[, r] = w_0 * (1 - ρ + ρ * h[, r])` where `h ∈ {-1, +1}`.
     (Matches the Fay formula in `survey:::brrweights()` source.)
  3. Build the surveycore design: `as_survey_replicate(df, weights = wt,
     repweights = all_of(paste0("repwt_", 1:R)), type = "BRR",
     scale = ρ^-2, rscales = rep(1, R))`. The `scale = ρ^-2` reproduces
     Fay's scale factor on an otherwise-BRR design; this is the
     surveycore-side equivalent of survey's `type = "Fay", rho = ρ`
     (until a native `rho` argument lands).
  4. Build the survey-side oracle: `survey::svrepdesign(..., type = "Fay",
     rho = 0.3, repweights = w_rep, weights = ~wt, data = df)`.
  5. Fit the same GLM on both; call `get_anova()` and
     `survey::anova.svyglm()`; assert parity at `1e-6` (p-value) /
     `1e-8` (statistic).

  This oracle is the regression for Pass 3 Issue 64 (ρ handling through
  `@vcov`). If step 3's `scale = ρ^-2` trick fails to match survey's
  numerics within tolerance, escalate to spec review — do NOT silently
  loosen the tolerance.

  **Two-phase oracle:** on `make_survey_data(design = "twophase")`,
  `method = "LRT"`, `test = "F"`: parity with `survey::anova.svyglm()`
  after the refit re-applies the phase-2 subset. Construct the matching
  `survey` design via
  `survey::twophase(id = list(~psu, ~psu), strata = list(~strata, ~strata), subset = ~subset, data = df)`
  (see `?survey::twophase`, `pbc` example).

- [ ] **Task 6.2** — Run `devtools::test(filter = "test-glm-anova-numerical")`.
  Confirm numerical tests pass. `skip_if_not_installed("survey")` should
  cleanly skip in environments without `survey`.

---

#### Final Checks

- [ ] **Task 7.1** — Run `devtools::document()`. Verify `NAMESPACE` exports
  `get_anova` (and only `get_anova` from this PR — `anova.survey_glm_fit`
  is registered dynamically, not exported). Verify no new `@importFrom`
  tags were introduced (all external calls use `::`).

- [ ] **Task 7.2** — Run `devtools::check()`. Must pass with 0 errors, 0
  warnings, ≤ 2 pre-approved notes.

- [ ] **Task 7.3** — Verify Quality Gates from §VIII of the spec:
  - [ ] 98%+ line coverage on `R/glm-anova.R` (run
    `covr::file_coverage("R/glm-anova.R", ...)`)
  - [ ] All new error/warning classes (A-2 through A-20) have typed tests
    and snapshots
  - [ ] All five design classes have ≥ 1 sequential-mode happy-path test
  - [ ] All five design classes have ≥ 1 comparison-mode happy-path test
  - [ ] Numerical oracle tests pass vs `survey::anova.svyglm()` for all
    four method × test combinations on Taylor, plus BRR, Fay-BRR, and
    two-phase oracles at 1e-6 / 1e-8 tolerances
  - [ ] `plans/error-messages.md` updated with A-2 through A-20
  - [ ] `CLAUDE.md` Implementation Status table updated to mark
    `get_anova()` as shipped / in review
  - [ ] `getS3method("anova", "surveycore::survey_glm_fit")` returns a
    function (verifies dynamic S3 registration in `R/zzz.R::.onLoad()`)

- [ ] **Task 7.4** — Write `changelog/get-anova/pr-c-get-anova.md`. Sections:
  **Date**, **Branch**, **Plan** (this file), **Changes** (bulleted list of
  what shipped — new exported function, S3 method, result class, print
  method, internal helpers, 18 new error/warning classes, `ANOVA_META_KEYS`
  constant), **Files Modified**. Do not commit until tasks 7.1-7.3 pass.

---

### Acceptance Criteria

- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤ 2 pre-approved notes
- [ ] `devtools::document()` run; `NAMESPACE` and `man/` in sync
- [ ] Happy-path tests pass for all five design classes in both sequential
  and comparison modes
- [ ] Numerical oracle tolerance: statistic 1e-8, p-value 1e-6
- [ ] All 18 new error/warning classes have typed `expect_error(class = ...)`
  / `expect_warning(class = ...)` tests plus snapshots
- [ ] `plans/error-messages.md` updated with A-2 through A-20
- [ ] `CLAUDE.md` Implementation Status table and `MEMORY.md` updated
- [ ] Changelog entry written and committed

---

### Notes for the Implementor

**`@term_assign` is the authoritative term-to-column map.** The spec's
`idx` resolution inside `.reg_term_test()` reads `model@term_assign` (PR A
shipped). Do **not** re-derive the map from `attr(model.matrix(fit),
"assign")` at ANOVA time — that re-evaluates the model matrix in O(n) and
breaks serialization safety for Wald. The stored property is
`integer(0)`-defaulted; callers should treat an empty vector as
"intercept-only, no non-intercept terms to test" and the A-17 guard will
catch that case at `get_anova()` entry.

**Canonical term ordering.** `attr(terms(model@formula), "term.labels")` is
the authoritative term ordering for the whole ANOVA surface (sequential
loop direction, `idx` resolution, comparison-mode `setdiff()`,
interaction-label composition). Pass 3 Issue 58 explicitly rejects RHS
appearance order and user-supplied `...` order.

**V₀ is the q×q block, not the p×p block.** §3.3.2 / Pass 2 Issue 37 is
load-bearing: compute `V0 <- summary(model@fit_)$cov.unscaled[idx, idx]`
*before* inverting. Subsetting after `solve()` yields different (and
incorrect) eigenvalues. The `.reg_term_test()` implementation must
subset-first-then-invert.

**Negative-deviance roundoff band.** `chisq < -sqrt(.Machine$double.eps) *
abs(model@deviance)` is the signal boundary (Pass 3 Issue 60). Inside the
band: clamp silently to 0. Outside: fire A-15 *then* clamp. Both test
blocks in Cycle A exercise both sides of the band.

**`rcond(V0) < tolerance` vs pseudoinverse.** `rcond()` is the *reciprocal*
condition number (small rcond = ill-conditioned). The A-13 warning fires
when `rcond(V0) < tolerance` — i.e., V₀ is singular *below* the threshold.
Pass 3 Issue 66 flags this sign convention; readers coming from `qr()` or
`chol()` may expect the opposite. Both branches use `{solve|ginv}(V0) %*%
V` as the operand order (not `V %*% {solve|ginv}(V0)`) so the eigenvalue
formula reads identically.

**Explicit `print(x, ...)` dispatch, not `NextMethod()`.** §3.9 pseudocode
rebinds `x` locally inside `print.survey_anova()` to suppress the `deff`
column in Wald mode. `NextMethod()` ignores the local rebinding and would
print the original tibble, silently defeating the suppression (Pass 2
Issue 18). Strip surveycore classes and call `print(x, ...)` explicitly.
The Wald print-snapshot test is the regression for this bug.

**`@fit_` dependencies at a glance:**
- Sequential Wald — does NOT need `@fit_` (serialization-safe)
- Sequential LRT — needs `@fit_` for `summary(fit_)$cov.unscaled` and for
  `rownames(model.frame(@fit_))`; A-11 fires if NULL
- Comparison, any method — needs `@fit_` on *both* models for the
  n-invariance check's `rownames(model.frame(...))` call; A-11 fires if
  either is NULL (Pass 2 Issue 16)

**Saddlepoint fallback chain (§V.5).** `.pchisqsum_sad()` /
`.pFsum_sad()` already vendor the `if (is.na(sad)) use_satterthwaite`
pattern from survey 4.4-8 (PR B shipped). When the fallback fires,
`.reg_term_test()` must emit `surveycore_warning_saddlepoint_fallback`
(A-8). Distinguishing tier 1 (saddlepoint → Satterthwaite) from tier 2
(Satterthwaite → `χ²(q)`/`F(q,ddf)`) is done inside the helper message
text; both share the single A-8 class.

**Family reconstruction in `.refit_drop_terms()`.** `survey_glm_fit@family`
is stored as `as.list(fam)` at fit time (R/glm.R:1147), not a `family`
object. Before passing to `survey_glm()`, detect via
`inherits(model@family, "family")` and reconstruct with
`do.call(stats::family, list(family = model@family$family, link =
model@family$link))` when it is the stored-list form. Inline in
`.refit_drop_terms()` for now; promote to `R/analysis-helpers.R` when a
second call site appears.

**`na.action` threading.** `.refit_drop_terms()` must pass `na.action =
model@call$na.action %||% getOption("na.action")` to `survey_glm()`. If a
dropped covariate was the only source of NAs in some rows, the reduced
refit would otherwise span more rows than the full fit and spuriously
trip A-12 (Issue 46).

**`quiet = TRUE` scope.** Pass `quiet = TRUE` only to the `survey_glm()`
call inside `.refit_drop_terms()`. Do NOT wrap `.reg_term_test()`, the
n-invariance check, or any typed-error call site in `suppressWarnings()`
or `suppressMessages()`. A-12, A-13, A-19 must remain visible (Issue 45,
BLOCKING).

**Comparison-mode domain propagation.** Because A-5 compares `@data` and
`@variables` content, the `..surveycore_domain..` indicator column (if
present on `@data`) is by construction identical across the two fits. No
separate domain-propagation step is needed in `.anova_compare()` — step
3 of §3.5 guarantees equality.

**Design df equality invariant.** `.anova_compare()` uses
`stopifnot(isTRUE(all.equal(bigger@degf, reduced@degf)))` before computing
`ddf`. A violation indicates a surveycore bug (two fits on the same
design reporting different design df), not a user error. The stopifnot()
is a defensive trip-wire for CI (Pass 2 Issue 40).

**Label composition.** §3.7.1 and Pass 2 Issue 20: split term on `:` via
`strsplit(term, ":", fixed = TRUE)[[1]]`; look up each component in
`design@metadata$variable_labels`; if all components have labels, join
with ` × ` (U+00D7, with single spaces); otherwise fall back to the raw
term string and set no `label` attribute. The three-way interaction test
in Cycle A is the k-way regression.

**Snapshot fixtures.** Use `gss_2024` for happy-path print snapshots per
CLAUDE.md's GSS preference. Numerical oracle tests use `nhanes_2017` (the
only remaining NHANES reference in the ANOVA plan) because
`survey::anova.svyglm()` oracle comparisons need the canonical survey
example data. BRR oracle uses `acs_pums_wy`; two-phase and Fay-BRR
oracles use `make_survey_data()` with the appropriate `design =` /
`type =` arguments.

**Dynamic S3 registration.** `anova.survey_glm_fit()` is **not** exported
via `@export`. It is registered in `.onLoad()` via `registerS3method()`
targeting the namespaced S7 class `"surveycore::survey_glm_fit"`, matching
the pattern already established in `R/zzz.R` for the other
`*.survey_glm_fit` methods. Roxygen block on the function uses
`@keywords internal` + `@noRd` (no `.Rd` file for S3 methods that
dispatch through `anova()`). The function itself is defined in
`R/glm-anova.R` alongside `get_anova()`.
