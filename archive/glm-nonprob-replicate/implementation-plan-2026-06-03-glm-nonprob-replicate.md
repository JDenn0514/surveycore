# Implementation plan — glm-nonprob-replicate

## PR map

- [x] PR 1: feature/glm-nonprob-replicate — route `survey_nonprob` with replicate weights through `.glm_replicate_vcov()` in `.glm_vcov_dispatch()`
  - **Tasks** (2–5 min each, TDD sub-steps explicit)
    1. Write failing test: `survey_glm()` on a `survey_nonprob` with repweights produces `@vcov` matching the `survey_replicate` oracle at tolerance 1e-8 and `@coefficients` at tolerance 1e-10. Run; confirm failure (current code routes to `.glm_calibrated_vcov()`).
    2. Write failing test: `survey_glm()` on a `survey_nonprob` with repweights emits NO `surveycore_warning_nonprob_srs_fallback`. Run; confirm test correctly asserts warning absence and passes (or note if pre-green — if so mark and move on).
    3. Write failing test: `survey_glm()` on a `survey_nonprob` with NULL repweights emits `surveycore_warning_nonprob_srs_fallback` — assert `expect_warning(..., class = "surveycore_warning_nonprob_srs_fallback")`. Run; confirm failure (no warning emitted today on this path).
    4. Write failing snapshot test: `expect_snapshot(warning = TRUE, survey_glm(nonprob_no_rep, y1 ~ y2))` for the NULL-repweights path. Run; confirm failure or absence of snapshot entry.
    5. Implement the change in `R/glm.R`: in `.glm_vcov_dispatch()` (lines 387–414), replace the single-line `survey_nonprob` arm with the two-branch form — when `!is.null(design@variables$repweights)` call `.glm_replicate_vcov(fit, design, row_mask, domain_mask)`; otherwise emit `cli::cli_warn(c("!" = ..., "i" = ...), class = "surveycore_warning_nonprob_srs_fallback")` with the exact NB-2 message text and call `.glm_calibrated_vcov(fit, design, row_mask, domain_mask)`.
    6. Verify tests from tasks 1–4 now pass. Also verify all pre-existing `test-glm.R` tests still pass.
    7. Write and verify happy-path test: multiple predictors formula `y1 ~ y2 + y3` on `survey_nonprob` with repweights. Assert `test_glm_fit_invariants(fit)`. Assert `@vcov` is 3 × 3 with positive diagonal, matches oracle within 1e-8.
    8. Write and verify happy-path test: binomial family on `survey_nonprob` with repweights; binary outcome `y1 > median(y1)`. Assert `test_glm_fit_invariants(fit)`. Assert `@vcov` is finite and symmetric.
    9. Write and verify warning-count test: wrap `survey_glm(nonprob_no_rep, y1 ~ y2)` in `withCallingHandlers()`, count emissions of `surveycore_warning_nonprob_srs_fallback`, assert count equals 1L.
    10. Write and verify edge-case test: domain estimation with repweights — apply `surveytidy::filter()` to both `d_np` (with repweights) and `d_rep` oracle; call `survey_glm()` on both; assert `test_glm_fit_invariants(fit_np)` and `fit_np@vcov` equals oracle within 1e-8.
    11. Write and verify edge-case test: `mse = FALSE` with repweights — construct `survey_nonprob` with repweights and `mse = FALSE`; call `survey_glm()`; assert `test_glm_fit_invariants(fit)` and `@vcov` finite; assert no error thrown.
    12. Write and verify edge-case test: NULL repweights regression guard — suppress warning; assert `@vcov` diagonal positive; assert values match calibrated-fallback baseline within 1e-8 (no regression in the fallback path).
    13. Write and verify regression smoke test: `get_diffs()` on `survey_nonprob` with repweights — construct design; call `get_diffs(design, y = y1, group = y3_binary)`; assert `diff` and `se` columns are finite; assert no `surveycore_warning_nonprob_srs_fallback` emitted.
    14. Run `devtools::document()` — confirm 0 errors (no roxygen changes; guard step).
    15. Run `devtools::check()` — confirm 0 errors, 0 warnings, notes reviewed.
    16. Run `covr::package_coverage()` — confirm >= 95%.
  - **Acceptance criteria** — observable outcomes before merge
    - `test_that("survey_glm() nonprob with repweights: @vcov matches survey_replicate oracle", ...)` passes with `@coefficients` tolerance 1e-10 and `@vcov` tolerance 1e-8
    - `test_that("survey_glm() nonprob with repweights: no surveycore_warning_nonprob_srs_fallback emitted", ...)` passes
    - `test_that("survey_glm() nonprob with repweights: multiple predictors @vcov matches oracle", ...)` passes with 3 × 3 `@vcov` at tolerance 1e-8
    - `test_that("survey_glm() nonprob with repweights: binomial family invariants hold", ...)` passes with finite symmetric `@vcov`
    - `test_that("survey_glm() nonprob NULL repweights: emits surveycore_warning_nonprob_srs_fallback", ...)` passes — both `expect_warning(class = "surveycore_warning_nonprob_srs_fallback")` and `expect_snapshot(warning = TRUE, ...)` assertions approve
    - `test_that("survey_glm() nonprob NULL repweights: warning emitted exactly once", ...)` passes with count == 1L
    - `test_that("survey_glm() nonprob domain estimation with repweights: @vcov matches oracle", ...)` passes at tolerance 1e-8
    - `test_that("survey_glm() nonprob mse = FALSE with repweights: @vcov finite", ...)` passes
    - `test_that("survey_glm() nonprob NULL repweights regression guard: @vcov unchanged from calibrated baseline", ...)` passes at tolerance 1e-8
    - `test_that("get_diffs() on survey_nonprob with repweights: finite diff and se, no SRS fallback warning", ...)` passes
    - All pre-existing `tests/testthat/test-glm.R` tests pass without modification
    - `devtools::check()` 0 errors, 0 warnings, notes reviewed
    - `covr::package_coverage()` >= 95%
  - **Files touched** — exact write surface
    - `R/glm.R` — modify `.glm_vcov_dispatch()`: replace single-line `survey_nonprob` arm (lines 400–401) with two-branch repweights sub-branch
    - `tests/testthat/test-glm.R` — add 10 new `test_that()` blocks (tasks 1–4, 7–13)
    - `tests/testthat/_snaps/glm.md` — new snapshot entry for NB-2 warning on NULL-repweights path (generated on first accepted snapshot run)
  - **Pipeline split**: recommended
