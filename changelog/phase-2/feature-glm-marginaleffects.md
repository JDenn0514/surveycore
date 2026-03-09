# Changelog: feature/glm-marginaleffects

**PR 5 of Phase 2 — marginaleffects extension interface**
**Branch:** `feature/glm-marginaleffects`
**Depends on:** PR 3 (`feature/glm-methods`)

## Summary

Implements the four S3 generics from the marginaleffects extension interface,
enabling `marginaleffects::avg_slopes()`, `marginaleffects::avg_predictions()`,
and the full marginaleffects API on `survey_glm_fit` objects.

## New Files

- `R/glm-marginaleffects.R` — `get_coef.survey_glm_fit`, `set_coef.survey_glm_fit`,
  `get_vcov.survey_glm_fit`, `get_predict.survey_glm_fit`; none exported; all
  registered dynamically in `.onLoad()`
- `tests/testthat/test-glm-marginaleffects.R` — 10 test items from spec §7.7; all
  blocks gated with `skip_if_not_installed("marginaleffects")`

## Modified Files

- `R/zzz.R` — conditional marginaleffects method registration block added to
  `.onLoad()`; also sets `options(marginaleffects_model_classes)` to register the
  class string required by marginaleffects ≥ 0.25 `sanity_model_supported_class`
  check
- `DESCRIPTION` — added `marginaleffects (>= 0.18.0)` to `Suggests`

## Key Implementation Notes

- `set_coef.survey_glm_fit` patches both `@coefficients` (S7 property) and
  `@fit_$coefficients` (internal `stats::glm` object). Without patching `fit_`,
  `stats::predict.glm()` reads stale coefficients and all AMEs silently equal zero.
- `get_predict.survey_glm_fit` uses argument name `newdata` (marginaleffects
  contract) while forwarding to `stats::predict(model, new_data = newdata)` to
  match `predict.survey_glm_fit`'s `new_data =` argument name.
- marginaleffects ≥ 0.25 requires `options(marginaleffects_model_classes)` to
  include the class string `"surveycore::survey_glm_fit"` in addition to the
  extension interface methods. This is set in `.onLoad()` alongside the
  `registerS3method()` calls.
- All four methods are registered conditionally: when marginaleffects is not
  installed, none are registered and all core `survey_glm_fit` functionality
  remains fully usable.

## Test Results

- `devtools::test()`: 6547 expectations pass, 0 failures
- `devtools::check()`: 0 errors, 0 warnings, 3 pre-existing notes
