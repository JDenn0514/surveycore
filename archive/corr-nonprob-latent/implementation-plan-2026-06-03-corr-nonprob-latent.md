# Implementation plan — corr-nonprob-latent

## PR map

- [x] PR 1: feature/corr-nonprob-latent — allow polychoric/polyserial on
  survey_nonprob with replicate weights

  - **Tasks** (TDD sub-steps explicit)

    1. Write failing test: `survey_nonprob` with `repweights` + `method =
       "polychoric"` should succeed — confirm it currently raises
       `surveycore_error_polychoric_design_unsupported`.
    2. Write failing test: `survey_nonprob` with `repweights` + `method =
       "polyserial"` should succeed.
    3. Write passing test (regression guard): `survey_nonprob` without
       `repweights` + latent method still raises
       `surveycore_error_polychoric_design_unsupported`. Use dual pattern:
       `expect_error(class = ...)` + `expect_snapshot(error = TRUE)` to
       verify both the error class and the "i" bullet message text
       ("Supply bootstrap replicate weights via {.arg repweights}...").
    4. Write passing test (regression guard): `survey_twophase` + latent method
       still raises `surveycore_error_polychoric_design_unsupported`.
    5. Write failing test: numerical agreement between `survey_nonprob` (with
       repweights) and an equivalent `survey_replicate` on identical data;
       assert `r` within 1e-10 and `ci_low` within 1e-6.
    6. Write edge-case tests per test-spec: PC-4 fires when ordinal variable
       has one level (all-NA or single-category); 0-row active domain raises
       PC-4 or PC-5 rather than PC-7; single-row design raises a construction
       or estimation error; `survey_nonprob` with repweights + `method =
       "pearson"` still works (PC-7 gate untouched for Pearson path).
    7. In `R/analysis-corr-latent.R`, relax the PC-7 gate: replace the current
       `survey_twophase || survey_nonprob` condition with
       `survey_twophase || (survey_nonprob && repweights is NULL)`. Specifically:
       - Keep `S7::S7_inherits(design, survey_twophase)` as an unconditional
         reject.
       - Add `S7::S7_inherits(design, survey_nonprob) &&
         is.null(design@variables$repweights)` as the second reject condition,
         with an `"i"` bullet pointing to the remedy.
       - `survey_nonprob` with non-`NULL` `repweights` passes through the gate.
    8. In `R/analysis-corr-latent.R`, add a `survey_nonprob` branch in the
       variance dispatch block (currently the `else if (survey_replicate)` block):
       when `S7::S7_inherits(design, survey_nonprob)` is `TRUE`, call
       `.corr_replicate_variance_latent()` with the same arguments as the
       `survey_replicate` branch. The `survey_nonprob` path always uses MSE
       form (`mse = TRUE`) regardless of the design object's stored `mse` field.
       Remove or narrow the `# nocov` guard on the defensive else block so that
       only the truly unreachable path retains `# nocov`.
    9. In `R/analysis-corr.R`, update the `@param design` roxygen2 tag to
       reflect that `survey_nonprob` with replicate weights is now supported for
       `method = "polychoric"` and `method = "polyserial"`.
    10. Verify all tasks 1–6 tests now pass. Verify all pre-existing
        `test-analysis-corr.R` tests still pass.
    11. Run `devtools::document()` to regenerate `man/get_corr.Rd`.
    12. Update `NEWS.md` with a bullet documenting the behavioral enhancement:
        `survey_nonprob` designs with replicate weights now support `method =
        "polychoric"` and `method = "polyserial"` in `get_corr()`.

  - **Acceptance criteria**
    - `get_corr(nonprob_with_repweights, x = c(ord1, ord2), method =
      "polychoric")` returns a `survey_corr` tibble with finite `r`,
      `ci_low`, `ci_high`; bounds in `[-1, 1]`; `ci_low < ci_high`.
    - `get_corr(nonprob_with_repweights, x = c(ord1, cont1), method =
      "polyserial")` returns the same structure.
    - `get_corr(nonprob_without_repweights, x = c(ord1, ord2), method =
      "polychoric")` raises `surveycore_error_polychoric_design_unsupported`
      with an `"i"` bullet containing the `repweights` remedy text (verified
      via snapshot).
    - `get_corr(twophase_design, x = c(ord1, ord2), method = "polychoric")`
      raises `surveycore_error_polychoric_design_unsupported`.
    - Numerical agreement: `r` for `survey_nonprob` with identical replicate
      weights matches `survey_replicate` within 1e-10; `ci_low` within 1e-6.
    - `get_corr(nonprob_with_repweights, method = "pearson")` still returns a
      valid `survey_corr` tibble (PC-7 gate untouched for the Pearson path).
    - All pre-existing `test-analysis-corr.R` tests pass.
    - `devtools::check()` passes with 0 errors, 0 warnings.

  - **Files touched**
    - `R/analysis-corr-latent.R` — PC-7 gate condition; variance dispatch
      branch; `mse = TRUE` forced for `survey_nonprob`; `# nocov` scope update
    - `R/analysis-corr.R` — `@param design` roxygen2 tag only
    - `tests/testthat/test-analysis-corr.R` — new tests for the nonprob latent
      path (happy path, error paths, edge cases per test-spec)
    - `man/get_corr.Rd` — auto-generated by `devtools::document()`
    - `NEWS.md` — behavioral enhancement entry

  - **Pipeline split**: recommended
