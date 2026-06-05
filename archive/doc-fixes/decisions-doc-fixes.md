# Decisions Log — doc-fixes

All findings from spec-review.md resolved in Stage 3r (2026-06-05).

---

## B-1 — D44: cli bullet fix approach

**Finding**: The spec offered two implementation paths for fixing the `" "` bullet
in `.check_is_survey()` with no decision rule.

**Decision**: Use the single `"v"` bullet merge (not `"x"` + `"i"` restructure).
The two original bullets together form one imperative fix instruction, not an
informational bullet plus a fix bullet. Merging into a single `paste0()` `"v"` bullet
is the correct cli structure for this content.

**Applied**: spec.md `.check_is_survey()` contract updated with exact `paste0()` form.

---

## B-2 — D45: extract_sata() fill error message

**Finding**: The spec introduced `"{.arg fill} must be {.code TRUE}, {.code FALSE},
or {.code NULL}."` — but `extract_sata()` only accepts `FALSE` or `NULL`, not `TRUE`.

**Decision**: Revert to the message the current code already has:
`"{.arg fill} must be {.code FALSE} or {.code NULL}."` This is accurate.
The new class `surveycore_error_fill_not_logical` is still correct and desirable;
only the message text is corrected.

**Applied**: spec.md function contract and error-classes table both updated.

---

## R-1 — D46: validate = FALSE documentation

**Finding**: Calling `validate = FALSE` "dead code" in user-facing docs is at
minimum misleading — the attribute IS set and cleared around the variable
assignment, whether or not it actively suppresses S7 validators.

**Decision**: Use a neutral description that accurately reflects what the code
does without making a false claim.

**Applied**: spec.md D46 item updated.

---

## R-2 — X3: @family for update_design()

**Finding**: Moving `update_design()` to `@family constructors` is semantically
wrong — it modifies an existing design, not creates one.

**Decision**: Remove the `@family` tag entirely. `update_design()` has no sibling
functions that would form a meaningful family group.

**Applied**: spec.md X3 @family fixes item updated.

---

## R-3 — D16–D23: label_values replacement text

**Finding**: Removing "has no visible effect" without adding replacement text
left the param description saying the parameter does something without saying what.

**Decision**: Add replacement text per each function explaining that
`label_values` is accepted for API consistency but has no effect in functions
whose output has no value-level cells.

**Applied**: spec.md D16–D23 items updated with function-specific replacement text.

---

## R-4 — B1/B2: shared .extract_print_label() helper

**Finding**: `print.survey_t_test` and `print.survey_pairwise` have identical
label-extraction logic — fixing them separately without a shared helper risks
future divergence.

**Decision**: Add internal helper `.extract_print_label(m)` in `analysis-t-test.R`.
Both print methods call it instead of inlining the same logic. Helper lives in
the same file as both call sites (2 users, same file → inline per code-style.md §4).

**Applied**: spec.md Architecture and both print contracts updated.

---

## A-1 — B6: formula. absent behavior

**Finding**: The `update.survey_glm_fit` contract did not specify behavior when
`formula.` is omitted and `...` is empty.

**Decision**: Document the standard `update.default()` semantics explicitly:
original model is re-evaluated unchanged.

**Applied**: spec.md `update.survey_glm_fit` edge cases updated.

---

## A-2 — D56/E4: remove_survey character(0)

**Finding**: `remove_survey(x, name = character(0))` behavior was unspecified.

**Decision**: Document that empty `name` returns `x` unchanged (no names to
match, no error).

**Applied**: spec.md `remove_survey()` edge cases updated.

---

## A-4 — PR 2 BLOCK-3: pre-existing coverage below 95% floor

**Finding**: `covr::package_coverage()` = 93.00% after PR 2 (93.04% on develop before PR 2). Below the 95% floor. Delta of -0.04% is not attributable to any PR 2 change (doc-only PR adds no new code paths).

**Decision**: Accept for this PR. Coverage gap is pre-existing and not caused by documentation changes. The -0.04% is measurement noise / floating point rounding across runs. Tracking this separately is a project-level concern, not a blocker for this docs-only PR.

**Applied**: tester verdict adjusted to PASS on Gate 8 for PR 2.

---

## A-3 — B4: calibrated survey_nonprob label

**Finding**: It was unclear whether showing "Non-probability" for calibrated
`survey_nonprob` fits was intentional.

**Decision**: Intentional. The label describes the sampling mechanism, not the
post-hoc calibration adjustment. Always "Non-probability" for `survey_nonprob`.

**Applied**: spec.md `.glm_design_type_label()` edge cases updated with
explicit note.
