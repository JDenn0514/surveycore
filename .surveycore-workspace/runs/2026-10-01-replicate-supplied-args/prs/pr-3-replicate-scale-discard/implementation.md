# Implementation — PR 3 — replicate-scale-discard

Branch base: e759983d91c853021ea0d74dd1a762c5d0185de1, tree
5545501283b376e66e7b86b7fd6f4c9f13240e42 (both verified before work began).
Commit: 56caab0 `fix(constructors): discard a supplied scale for BRR, JK2, ACS and SD`.

## Write surface
- `R/core-constructors.R` — modified (36 lines added inside `as_survey_replicate()`, one hunk at line 963; no other function touched)
- `tests/testthat/test-constructors.R` — modified (11 new blocks under the header "Discarded scale (issue #255)", inserted after the block "as_survey_replicate() raises the rscales-length error before the missing-rho error")
- `tests/testthat/_snaps/constructors.md` — modified (one new entry, "as_survey_replicate() discard warning names scale alone"; no existing entry changed)

## Summary
- `as_survey_replicate()` gains spec §III step 9, the `"scale"` half only. It sits after the Fay/`rho` step and before the default-scale `switch()`.
- `as_survey_replicate()` now calls `.replicate_ignores_scale()` (from `R/utils.R`, PR 1). The condition is `.replicate_ignores_scale(type) && !identical(type, "Fay") && !is.null(scale)`, so the warning set is `"BRR"`, `"JK2"`, `"ACS"`, `"successive-difference"`.
- When `ignored` has length 1 or more, one `cli::cli_warn()` with class `surveycore_warning_replicate_arg_ignored` raises the three-bullet template of spec §III "Warnings" word for word, plural markers included, with `n_ignored <- length(ignored)`. Then `scale` is set to `NULL` when `"scale"` is in `ignored`, and the `switch()` stores the type's own value.
- The `"rscales"` condition is not added; PR 4 adds it to the `ignored` list. The `rho` warning is unchanged (still one class).

## Task checklist
- [x] 1. Block "as_survey_replicate() discards a supplied scale for BRR, JK2, ACS and successive-difference"
- [x] 2. Block "as_survey_replicate() warns for a supplied BRR scale equal to the default"
- [x] 3. Block "as_survey_replicate() discards a non-numeric scale without checking it"
- [x] 4. Snapshot block "as_survey_replicate() discard warning names scale alone"; entry read before acceptance, text matches spec §III
- [x] 5. Block "as_survey_replicate() never checks a discarded scale" (five values, four warning types plus Fay)
- [x] 6. Block "as_survey_replicate() discards a supplied scale at one replicate column"
- [x] 7. Block "as_survey_replicate() discards a supplied scale on an all-NA outcome frame"
- [x] 8. Four keep-passing blocks: keeps scale for JK1/JKn/bootstrap/other; no warning on any type when nothing supplied; explicit NULL treated as not supplied; JKn with rscales stores scale 1
- [x] 9. Step 9 implemented in `as_survey_replicate()`
- [x] 10. Existing block "as_survey_replicate() discards a supplied scale for Fay with no warning" unchanged
- [x] 11. New snapshot entry reviewed; local checks below

Local checks run by the builder (not gate results):
- `air format --check R/core-constructors.R` passes. An air-formatted copy of `tests/testthat/test-constructors.R` differs only at lines 3853 and later (pre-existing); the added lines 1650–1985 are air-clean.
- No added test code line contains `suppressWarnings(` or `expect_failure(`.
- `as_survey_nonprob()` is not in the diff (gate 10).
- No roxygen change, so `devtools::document()` has nothing to regenerate.

## Signals raised
- None.

## Notes for tester
- In the "never checks a discarded scale" block, the `rep(0.6, 20)` value is a length-20 vector; it reaches neither `.validate_rscales()` nor any scale check, because step 9 sets `scale` to `NULL` before the `switch()`.
- The F1 frame (`type = "jk1"`, `n_psu = 20`) gives 20 replicate columns, as the plan states.
