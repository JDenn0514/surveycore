# feat(analysis): polymorphic `object` arg for get_anova()

**Date**: 2026-04-21
**Branch**: feature/get-anova-polymorphic
**Plan**: `plans/impl-get-anova-polymorphic.md`

## Changes

### Breaking

- `get_anova()`'s first argument is now `object` and dispatches on class.
  The former `model2` parameter has been removed. `get_anova(fit1, fit2)`
  must now be written `get_anova(list(fit1, fit2))`. S3
  `anova(fit1, fit2)` continues to work — the delegator in `R/zzz.R`
  was updated to wrap its trailing fits in `list(...)` before forwarding.

### New dispatch branches

- `get_anova(<survey_glm_fit>)` — unchanged (sequential anova).
- `get_anova(<list<survey_glm_fit>>)` — chained pairwise comparison,
  returning `length(object) - 1` rows. Mirrors
  `stats::anova(fit1, fit2, fit3)` semantics (k=1 unwraps to a single
  sequential anova; k=2 reduces to a one-pair comparison; k≥3 loops
  over consecutive pairs, `rbind`s the results, and rebuilds a combined
  `.meta` with `$terms` unioned across pairs and a new `$models` list
  enumerating each fit's formula/family summary).
- `get_anova(<survey_base>, formula = ...)` — fits the model internally
  via `survey_glm()`, then runs sequential anova on the fit. Extra
  `...` are forwarded to `survey_glm()` (e.g., `family`, `quiet`). The
  `response` / `predictors` character-arg interface is also supported,
  matching `survey_glm()`'s variadic fit contract.

### Internal refactor

- The anova numerical kernel in `R/glm-anova.R` was renamed from the
  old public `get_anova()` to internal `.get_anova_single(model, model2,
  ..., call = NULL)`. All `cli::cli_abort()` sites in the helper now
  receive `call = cl` so user-visible error headers continue to read
  `Error in \`get_anova()\`:`.
- New file `R/glm-anova-dispatch.R` holds the public `get_anova()`
  dispatcher plus the two private branch helpers
  `.anova_dispatch_list()` and `.anova_dispatch_design()`.
- `...` is emptiness-checked via `rlang::check_dots_empty()` for fit and
  list inputs; forwarded to `survey_glm()` for design inputs. Fit/list
  callers get fuzzy typo detection for misspelled control args.

### Error / warning classes (new)

Five new rows added to `plans/error-messages.md` (A-21..A-25):

- `surveycore_error_anova_object_invalid` (A-21) — `object` is not a
  fit, a list of fits, or a design; also covers mixed-class lists
  (reports bad indices and classes).
- `surveycore_error_anova_empty_model_list` (A-22) — `list()` passed.
- `surveycore_error_anova_formula_missing` (A-23) — design input
  without any of `formula` / `response` / `predictors`.
- `surveycore_error_anova_formula_unexpected` (A-24) — formula args
  supplied alongside a fit or list input.
- `surveycore_warning_anova_null_ignored` (A-25) — `null` passed with
  a list input; dropped with warning (type validation on `null` still
  fires first, preserving the existing `surveycore_error_null_length_mismatch`
  contract).

## Tests

- New file `tests/testthat/test-glm-anova-dispatch.R` (46 tests):
  list-dispatch (k=1 unwrap, k=2, k=3 chained, k=4), design+formula
  paths, `response`/`predictors` character args, missing-formula error,
  `check_dots_empty` on fit/list, formula-unexpected error,
  character/numeric invalid-`object` errors, `null`-warning for list
  mode with type-error precedence, design+null forwarding, S3
  `anova(fit1, fit2)` delegator regression, and Layer 3 dual-pattern
  snapshot tests for A-21..A-25.
- `tests/testthat/test-glm-anova.R`: ~25 positional `get_anova(fit1, fit2)`
  call sites migrated to `get_anova(list(fit1, fit2))`. One test
  (A-1 → A-23) updated to use the new `object`-invalid class.
- `tests/testthat/test-glm-anova-numerical.R`: two call sites migrated
  (lines 221, 258).
- Snapshot file `tests/testthat/_snaps/glm-anova.md` regenerated.

## R CMD check

0 errors, 0 warnings, 2 pre-approved notes.
