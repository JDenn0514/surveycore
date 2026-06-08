# Decisions — nonprob-jackknife

**Date**: 2026-05-29
**Stage**: 3r (spec-review resolution)

---

## B-1 — NB-9 error class name conflict (UNAMBIGUOUS)

**Decision**: Rename `surveycore_error_jk2_scale_unset` →
`surveycore_error_stratified_jk_rscales_unset` in `error-messages.md` and
`comprehension.md`. Spec already used the correct name throughout.

---

## B-2 — NB-10 missing from error-messages.md (UNAMBIGUOUS)

**Decision**: Added NB-10 (`surveycore_error_scale_negative`) row to
`error-messages.md` as specified in the spec.

---

## RU-1 — `.is_stratified_jk()` claim in Architecture (UNAMBIGUOUS)

**Decision**: Corrected spec to say `.is_stratified_jk()` is used only in
the rscales NULL check (step 10), not in calibration logic.

---

## RU-2 — Zero-rscale JK test missing (UNAMBIGUOUS)

**Decision**: Added edge-case test to test-spec: JK1 with
`rscales = c(1, 0, 1, 1)`. Asserts `d@variables$rscales` matches.

---

## RU-3 — `calibration = list()` behavior undocumented (UNAMBIGUOUS)

**Decision**: Added edge case to spec and two test cases to test-spec:
`calibration = list()` with bootstrap → `provenance_not_bootstrap`; with
JK1 → no error.

---

## RU-4 — Non-character `type` undocumented (UNAMBIGUOUS)

**Decision**: Added sentence to `type` Arguments description (folded into
the RJ-4 reorganization). Added test case for `type = 1`.

---

## RU-5 — `@variables` exhaustiveness not stated (UNAMBIGUOUS)

**Decision**: Added sentence to Returns section: "The `@variables` list for
`survey_nonprob` always contains exactly these keys; no others are added or
removed by this constructor."

---

## RU-6 — Missing zero-row and single-row tests (UNAMBIGUOUS)

**Decision**: Added both test cases to test-spec Edge cases section.

---

## RJ-1 — Missing analysis edge-case test categories 6/7/8

**Decision**: Option A — add 3 test blocks (all-NA outcome, single-level
grouping, zero-weight domain) for JK1 designs. JK1 uses different
scale/rscales than bootstrap, so these add real coverage.

---

## RJ-2 — `mse` non-logical coercion

**Decision**: Option B — document the silent `isTRUE()` coercion in the `mse`
argument description. No code change. Pre-existing behavior the spec should
acknowledge rather than change.

---

## RJ-3 — Calibration notation inconsistency

**Decision**: Option A — standardize to `type == "bootstrap"` in both
Architecture and Function contract sections. Removed `.is_any_jk()` helper
from the spec entirely (per advisory A-1: single-use helper, no longer needed
when calibration uses direct comparison). `.is_stratified_jk()` remains for
step 10.

---

## RJ-4 — `type` constraints placement

**Decision**: Option A — moved scalar/NA/vector constraints and case-sensitivity
note to the top of the `type` argument description, before the valid-value list.
Also folded in the RU-4 non-character sentence to avoid duplication.

---

## RJ-5 — Summary type case

**Decision**: Apply `toupper()` in `summary.survey_nonprob` too, for full
consistency with `survey_replicate`. Updated spec and test-spec assertions:
`"bootstrap"` → `"BOOTSTRAP"`, `"JKn"` → `"JKN"`.

---

## RJ-6 — SRS vs stratified contrast test

**Decision**: Option A — JK1 + JK2 constructor happy-path tests constitute a
sufficient SRS-vs-stratified contrast. Added comment in test-spec explaining
the rationale. Analysis-level divergence testing deferred to future numerical
validation PR.

---

## Advisories applied

- **A-1**: `.is_any_jk()` removed entirely (resolved by RJ-3).
- **A-2**: Added `expect_snapshot(print(jk2_design))` and
  `expect_snapshot(print(jkn_design))` to test-spec.
- **A-3**: Added `type = "jackknife"` + explicit `rscales` happy-path test.
- **A-4**: Added case-sensitivity rationale sentence to `type` argument
  description ("consistent with `as_survey_replicate()` which uses exact-match
  validation").

---

## Pass 2 resolutions (2026-05-29)

### Issue 1 — Decision tree step 4 routes to step 11 (REQUIRED, UNAMBIGUOUS)

**Decision**: Option A — changed "go directly to step 11" to "go directly to
step 16" in step 4 of the decision tree. Also updated the parenthetical from
"(skip steps 4–10)" to "(skip steps 5–15)" for accuracy. When `repweights =
NULL`, `R` is never computed, so steps 5–15 (which reference `R`, `type`, etc.)
must all be skipped. Step 16 constructs and returns the object with all
rep-related variables set to NULL.

### Issue 2 — Duplicate JK2/JKn header text bullets in test-spec (SUGGESTION)

**Decision**: Option A — removed the duplicate JK2 and JKn `expect_output()`
bullets that appeared twice in the `print.survey_nonprob` happy paths section.
The snapshot tests for JK2 and JKn that follow already cover these cases.

### Issue 3 — `repweights = NULL` edge case misses scale/rscales/mse assertions (SUGGESTION)

**Decision**: Option A — expanded the "repweights = NULL ignores type" edge
case to assert all four rep-related variables are NULL: `type`, `scale`,
`rscales`, and `mse`. The spec's Returns section requires all four to be NULL
when `repweights = NULL`; the test should verify the complete contract.

### Issue 4 — Missing JK2/JKn summary snapshots (SUGGESTION)

**Decision**: Option A — added `expect_snapshot(summary(jk2_design))` and
`expect_snapshot(summary(jkn_design))` to the summary happy paths section.
Consistent with the snapshot policy applied to `print` (which already has JK2
and JKn snapshots). Prevents silent regressions in type-string uppercasing
("JK2", "JKN") within the summary header line.
