# Spec Review — nonprob-jackknife

**Verdict**: BLOCK
**Date**: 2026-05-29
**Lenses run**: DRY, Test Completeness, Contract Completeness, Edge Cases, Engineering Level, API Coherence

---

## Verdict summary

Two BLOCKING findings (error class name conflict spanning three documents; missing
error-messages.md entry) must be resolved before any builder reads these artifacts.
Seven REQUIRED-UNAMBIGUOUS findings cover spec accuracy, test-spec gaps, and
undocumented edge cases. Six REQUIRED-JUDGMENT_CALL findings need either a clear
decision or a note in the spec. The design itself is sound; all issues are
specification and test-coverage gaps, not architectural problems.

---

## BLOCKING findings

### B-1 — NB-9 error class name conflict across three documents
**Lens**: Contract Completeness, API Coherence  
**Type**: UNAMBIGUOUS

`plans/error-messages.md` (line 316) and `plans/comprehension-nonprob-jackknife.md`
(line 82) both use the older name `surveycore_error_jk2_scale_unset`. The spec
uses `surveycore_error_stratified_jk_rscales_unset` throughout (lines 32, 355, 519,
523). A builder reading all three documents gets three different class names for the
same condition.

**Fix**: Update `error-messages.md` row NB-9 and `comprehension.md` line 82 to
`surveycore_error_stratified_jk_rscales_unset`. The spec's name is correct — it
covers both JK2 and JKn and names the missing argument precisely. All test-spec
references already use the spec's class name and require no changes.

---

### B-2 — NB-10 (`surveycore_error_scale_negative`) absent from `error-messages.md`
**Lens**: Contract Completeness, API Coherence  
**Type**: UNAMBIGUOUS

The spec defines NB-10 in the error message table (lines 525–530) and the function
contract Errors table (line 339). It does not appear in `plans/error-messages.md`
at all. The pre-implementation gate (line 537) requires this table to be updated
first; without the entry the gate is broken.

**Fix**: Add NB-10 row to `error-messages.md` exactly as specified at lines
525–530 of the spec.

---

## REQUIRED — UNAMBIGUOUS

### RU-1 — Spec incorrectly claims `.is_stratified_jk()` is used in calibration logic
**Lens**: DRY  

Spec lines 107–109 say `.is_stratified_jk(type)` is "Used in the rscales NULL
check (step 10 of decision tree) **and the calibration bootstrap-skip logic**."
The calibration code block (lines 118–127) only references `.is_any_jk(type)`.
`.is_stratified_jk()` is used only at step 10.

**Fix**: Change lines 107–109 to:
> "Used in the rscales NULL check (step 10 of decision tree) only."

---

### RU-2 — Zero-valued `rscales` entries not tested for JK types
**Lens**: Edge Cases, Test Completeness  

The spec (line 239–240) states that a `0` in `rscales` is valid for all types.
The test-spec covers this semantics in the Arguments section but has no test case
exercising a JK1/JK2/JKn design with `rscales = c(1, 0, 1, 1)`.

**Fix**: Add one edge-case test to test-spec:
```r
# "JK1 with one zero-valued rscale entry"
rsc <- c(1, 0, 1, 1)
d <- as_survey_nonprob(df, weights = wt, repweights = starts_with("jk"),
                       type = "JK1", rscales = rsc)
test_invariants(d)
expect_equal(d@variables$rscales, rsc)
```

---

### RU-3 — `calibration = list()` (empty, non-NULL) behavior not documented
**Lens**: Edge Cases  

When `calibration = list()`:
- `calibration$bootstrap` evaluates to `NULL`
- `isTRUE(NULL)` is `FALSE` → for `type = "bootstrap"`, this silently raises
  `surveycore_error_provenance_not_bootstrap`

This is a realistic user mistake ("I have provenance but no specific constraints").
The current behavior is: an empty list triggers the bootstrap provenance error for
`type = "bootstrap"`, but is silently accepted for JK types.

**Fix**: Add an edge case to the spec's Edge cases section:
> "`calibration = list()` (empty, non-NULL): `calibration$bootstrap` is NULL, which
> causes `isTRUE(NULL) = FALSE`. For `type = "bootstrap"`, this raises
> `surveycore_error_provenance_not_bootstrap`. For JK types, the bootstrap check is
> skipped, so the empty list is accepted without error. Users who want to supply
> provenance without a bootstrap flag should use `calibration = NULL` instead."

Add a test case in test-spec under edge cases:
- `calibration = list()` with `type = "bootstrap"` → `surveycore_error_provenance_not_bootstrap`
- `calibration = list()` with `type = "JK1"` → no error

---

### RU-4 — Non-character `type` (e.g., `type = 1`) not documented or validated
**Lens**: Edge Cases  

The spec says `type` must be a character scalar (line 221) but does not document
behavior when a user passes `type = 1`, `type = TRUE`, or `type = c("JK1", "JK2")`.
The membership check `type %in% c(...)` will return FALSE for numeric/logical
inputs, raising `surveycore_error_type_unsupported_for_nonprob`, which is
misleading (the error says "must be one of…" not "must be character").

The vector-valued case is partially documented (lines 222–224) but only mentions
that it raises the same error — not that the root cause is non-scalar type.

**Fix**: Add one sentence to the Arguments `type` section:
> "`type` must be a character scalar. Non-character values (e.g., `type = 1`,
> `type = TRUE`) and vector-valued inputs (e.g., `type = c("JK1", "JK2")`) are
> treated as unsupported types and raise
> `surveycore_error_type_unsupported_for_nonprob` via the membership check."

Add one test case in test-spec:
```r
# "type = 1 (numeric) raises type_unsupported_for_nonprob"
expect_error(as_survey_nonprob(df, weights = wt, repweights = starts_with("jk"),
             type = 1), class = "surveycore_error_type_unsupported_for_nonprob")
```

---

### RU-5 — Returns section does not state `@variables` key list is exhaustive
**Lens**: Contract Completeness  

The Returns section (lines 313–325) lists the `@variables` keys but does not
state whether the list is exhaustive. A builder reading this could omit a key or
add an extra one without realizing the list is complete.

**Fix**: Add the sentence: "The `@variables` list for `survey_nonprob` always
contains exactly these keys; no others are added or removed by this constructor."

---

### RU-6 — Missing test categories: zero-row data and single-row data
**Lens**: Test Completeness  

The test-spec has no test for:
- Category 4: `as_survey_nonprob(data.frame(), ...)` → `surveycore_error_empty_data`
- Category 5: a 1-row data frame → should produce a valid object (the validator
  allows 1 row)

Both are required by the 13-category framework.

**Fix**: Add to test-spec Constructor section under Error paths / Edge cases:
```r
# zero-row (dual pattern)
empty_df <- data.frame(wt = numeric(0))
expect_error(as_survey_nonprob(empty_df, weights = wt),
             class = "surveycore_error_empty_data")
expect_snapshot(error = TRUE, as_survey_nonprob(empty_df, weights = wt))

# single-row
single_df <- data.frame(y = 1, wt = 1, j1 = 0.5, j2 = 0.5)
d1 <- as_survey_nonprob(single_df, weights = wt,
                        repweights = starts_with("j"), type = "JK1")
test_invariants(d1)
expect_equal(nrow(d1@data), 1L)
```

---

## REQUIRED — JUDGMENT CALL

### RJ-1 — Missing test categories: all-NA outcome, single-level group, zero-weight domain
**Lens**: Test Completeness  

Categories 6 (all-NA outcome), 7 (single-level grouping), and 8 (zero-weight
domain) are missing from the analysis-function section of the test-spec. The
question is whether this PR should add these tests for JK nonprob designs or
whether they are covered by existing tests for bootstrap nonprob designs
(since the variance engine is unchanged).

**Decision options**:
A. Add minimal "no error" dispatch tests for all three categories with JK1 designs
   (3 new test blocks, straightforward).
B. Treat as out-of-scope: variance engine unchanged; existing bootstrap tests cover
   the same code paths; add a comment in test-spec citing this rationale.

**Recommendation**: Option A. These are standard 13-category requirements and the
test blocks are short. JK1 designs use a different `scale`/`rscales` path than
bootstrap, so dedicated tests add real coverage.

---

### RJ-2 — `mse` non-logical values silently coerced — document or validate?
**Lens**: Edge Cases  

The existing constructor uses `isTRUE(mse)` at line 1376, so `mse = NA`,
`mse = 1`, `mse = "TRUE"` all silently produce `mse = FALSE` behavior.
This is existing code not changed by this PR, but the spec is silent about it.

**Decision options**:
A. Add explicit validation: `if (!is.logical(mse) || length(mse) != 1L || is.na(mse))`
   → new error class `surveycore_error_mse_invalid`. This is a separate, small
   change but requires a new error class and test.
B. Document the coercion in the spec's Arguments section for `mse`:
   > "Non-logical or NA values are silently treated as `FALSE` via `isTRUE()`."
   No code change.
C. Out-of-scope: pre-existing behavior; this PR does not change `mse` handling;
   leave for a future cleanup PR.

**Recommendation**: Option B (document the coercion). Adding a new error class
is over-engineering for this PR; the coercion is an existing behavior that the
spec should simply acknowledge rather than change.

---

### RJ-3 — Calibration conditional notation inconsistency
**Lens**: Contract Completeness, DRY  

The Architecture section (lines 116–128) shows the calibration conditional using
`.is_any_jk(type)`:
```r
if (!.is_any_jk(type)) {   # i.e., type == "bootstrap"
```

The Function contract section (lines 263–272) shows the same block using direct
comparison:
```r
if (type == "bootstrap") {
```

Both are functionally identical (type is already normalized by step 8), but they
read differently and the builder must pick one form.

**Decision options**:
A. Standardize to `type == "bootstrap"` in both places. Simpler, avoids `.is_any_jk()`
   which is a negation-of-negation pattern.
B. Standardize to `!.is_any_jk(type)` in both places. Keeps the helper used
   consistently.

**Recommendation**: Option A (`type == "bootstrap"`). The comment `# i.e., type == "bootstrap"` in the Architecture section already acknowledges this equivalence; the direct form is clearer and removes the negated helper from the calibration path. `.is_any_jk()` can still be defined for future use, but the calibration block should not require it.

---

### RJ-4 — `type` vector/NA constraints appear only in Edge cases, not Arguments
**Lens**: Contract Completeness  

Spec lines 222–226 (inside the `type` Arguments bullet) state scalar/NA/vector
behavior. These read as qualifications on the argument's constraints and logically
belong at the start of the `type` argument description rather than embedded mid-way
through a long bullet.

**Decision options**:
A. Move the scalar/NA/vector sentences to the top of the `type` Arguments
   description, before the valid-value list. No change to content.
B. Leave as-is; the placement is non-standard but not incorrect.

**Recommendation**: Option A (minor reorganization for readability, no spec
content change).

---

### RJ-5 — Summary does not uppercase type; creates asymmetry with `survey_replicate`
**Lens**: API Coherence  

`survey_replicate`'s `summary()` uppercases the type (line 678 of methods-print.R:
`{toupper(x@variables$type)}`). The spec says `summary.survey_nonprob` displays
type as stored (lowercase for `"bootstrap"`, mixed for `"JK1"`, `"JKn"`).

**Decision options**:
A. Keep lowercase-as-stored for summary (as spec says). Deliberate asymmetry:
   print uppercases (aligned with survey_replicate); summary is more literal.
B. Apply `toupper()` in summary too, for full consistency with `survey_replicate`.

**Recommendation**: Document whichever is chosen explicitly in the spec. Either
choice is defensible; the asymmetry should be intentional and documented, not
accidental.

---

### RJ-6 — SRS vs stratified contrast test missing
**Lens**: Test Completeness  

Category 10 (SRS vs stratified contrast) is absent. The question is whether a
JK1 vs JK2 constructor test constitutes this contrast (different `scale`/`rscales`
storage) or whether a full analysis-level comparison is needed.

**Decision options**:
A. Treat the existing JK1 happy-path test (unclustered, `rscales = rep(1, R)`,
   `scale = (R-1)/R`) and JK2 happy-path test (stratified, explicit `rscales`,
   `scale = 1`) as a sufficient SRS-vs-stratified contrast at the constructor level.
   Add a comment in test-spec noting this.
B. Add an explicit analysis-level test showing JK1 and JK2 produce different SEs
   for the same data.

**Recommendation**: Option A for now. The constructor-level difference is clear and
tested. Analysis-level divergence testing is more appropriate when stratified
jackknife designs are validated numerically in a future PR.

---

## ADVISORY

### A-1 — `.is_any_jk()` used only once; could be inlined
**Lens**: DRY, Engineering Level  

`.is_any_jk(type)` appears in exactly one location (calibration check). A one-liner
used once doesn't need a named helper per the code-style "Internal helper placement"
rule (helpers in 2+ files → utils.R; helpers in 1 file → inline at top of file).
However the helper is named to be discoverable and its inline definition is fine.

**Recommendation**: If RJ-3 resolves to Option A (direct `type == "bootstrap"`),
`.is_any_jk()` can be removed entirely. If the helper stays, it's acceptable as-is.

---

### A-2 — Additional print/summary snapshots for JK2 and JKn
**Lens**: Test Completeness  

Only JK1 and bootstrap snapshots are specified. JK2 and JKn use the same print
path but differ in type string. Short `expect_snapshot()` calls for JK2 and JKn
would prevent undetected regressions in the header formatting.

**Recommendation**: Add `expect_snapshot(print(jk2_design))` and
`expect_snapshot(print(jkn_design))`. Low effort, clear value.

---

### A-3 — `alias + explicit rscales` path not explicitly tested
**Lens**: Edge Cases  

`type = "jackknife"` with non-uniform explicit `rscales` is not in the test-spec
happy paths. The code path is correct (alias normalized before rscales check)
but no test confirms it.

**Recommendation**: Add one happy-path test: `type = "jackknife"` + `rscales = c(1, 1, 0.5, 1)`.
Assert `design@variables$type == "JK1"` and `design@variables$rscales` matches.

---

### A-4 — Case-sensitivity rationale absent
**Lens**: Edge Cases  

The spec states case-sensitivity (line 227) without explaining why. A one-line
note ("consistent with `as_survey_replicate()` which uses exact-match validation")
would pre-empt builder questions.

---

## Findings summary

| ID | Lens | Severity | Type | Status |
|----|------|----------|------|--------|
| B-1 | Contract, API | BLOCKING | UNAMBIGUOUS | NB-9 class name conflict across 3 docs |
| B-2 | Contract, API | BLOCKING | UNAMBIGUOUS | NB-10 missing from error-messages.md |
| RU-1 | DRY | REQUIRED | UNAMBIGUOUS | `.is_stratified_jk()` claim wrong |
| RU-2 | Edge, Test | REQUIRED | UNAMBIGUOUS | Zero rscale entry not tested for JK |
| RU-3 | Edge | REQUIRED | UNAMBIGUOUS | `calibration = list()` behavior undocumented |
| RU-4 | Edge | REQUIRED | UNAMBIGUOUS | Non-character `type` not documented |
| RU-5 | Contract | REQUIRED | UNAMBIGUOUS | Returns `@variables` exhaustiveness not stated |
| RU-6 | Test | REQUIRED | UNAMBIGUOUS | Missing zero-row and single-row test categories |
| RJ-1 | Test | REQUIRED | JUDGMENT_CALL | Missing categories 6/7/8 (analysis edge cases) |
| RJ-2 | Edge | REQUIRED | JUDGMENT_CALL | `mse` non-logical — document or validate? |
| RJ-3 | Contract, DRY | REQUIRED | JUDGMENT_CALL | Calibration notation inconsistency |
| RJ-4 | Contract | REQUIRED | JUDGMENT_CALL | `type` constraints placement |
| RJ-5 | API | REQUIRED | JUDGMENT_CALL | Summary casing asymmetry |
| RJ-6 | Test | REQUIRED | JUDGMENT_CALL | SRS vs stratified contrast test |
| A-1 | DRY, Eng | ADVISORY | — | `.is_any_jk()` single-use helper |
| A-2 | Test | ADVISORY | — | More JK2/JKn snapshots |
| A-3 | Edge | ADVISORY | — | alias + rscales path not tested |
| A-4 | Edge | ADVISORY | — | Case-sensitivity rationale absent |

---

## Spec Review: nonprob-jackknife — Pass 2 (2026-05-29)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| B-1 | NB-9 error class name conflict across 3 docs | ✅ Resolved |
| B-2 | NB-10 missing from error-messages.md | ✅ Resolved |
| RU-1 | `.is_stratified_jk()` claim wrong | ✅ Resolved |
| RU-2 | Zero rscale entry not tested for JK | ✅ Resolved |
| RU-3 | `calibration = list()` behavior undocumented | ✅ Resolved |
| RU-4 | Non-character `type` not documented | ✅ Resolved |
| RU-5 | Returns `@variables` exhaustiveness not stated | ✅ Resolved |
| RU-6 | Missing zero-row and single-row test categories | ✅ Resolved |
| RJ-1 | Missing categories 6/7/8 (analysis edge cases) | ✅ Resolved — Option A, dedicated edge-case blocks added |
| RJ-2 | `mse` non-logical — document or validate? | ✅ Resolved — Option B, coercion documented |
| RJ-3 | Calibration notation inconsistency | ✅ Resolved — Option A, both sections use `type == "bootstrap"` directly |
| RJ-4 | `type` constraints placement | ✅ Resolved — scalar/NA/vector constraints moved to top of `type` argument |
| RJ-5 | Summary casing asymmetry | ✅ Resolved — `toupper()` documented with explicit examples |
| RJ-6 | SRS vs stratified contrast test | ✅ Resolved — Option A, constructor-level contrast documented with rationale |
| A-1 | `.is_any_jk()` single-use helper | ✅ Resolved — helper removed; spec uses `type == "bootstrap"` directly |
| A-2 | More JK2/JKn snapshots | ✅ Resolved — `expect_snapshot(print(jk2_design))` and JKn added |
| A-3 | alias + rscales path not tested | ✅ Resolved — "jackknife alias with explicit non-uniform rscales" test added |
| A-4 | Case-sensitivity rationale absent | ✅ Resolved — "consistent with `as_survey_replicate()`" note added |

### New Issues

#### REQUIRED

**Issue 1: Decision tree step 4 sends builder to wrong step (step 11 instead of step 16)**
Severity: REQUIRED
Section: Function contracts — Constructor execution order
Violates engineering-preferences.md §5 (Explicit over clever): the decision tree must not require implicit reasoning about undefined variables.

Step 4 of the decision tree reads:

> "If repweights resolves to NULL → store all rep-related variables as NULL and go directly to step 11 (skip steps 4–10)."

Step 11 reads:

> "If scale is NULL → scale <- .compute_nonprob_scale(type, R). Else if scale < 0 → raise surveycore_error_scale_negative."

Step 12 reads:

> "If rscales is NULL → rscales <- rep(1, R)."

When step 4 fires (repweights = NULL), `R` was never computed (step 7 is skipped). A builder following the pseudocode literally arrives at step 11 with `type = NULL` and `R = NULL`:

- `.compute_nonprob_scale(NULL, NULL)` → `switch(NULL, ...)` → returns NULL. Scale is set to NULL ✓ (accidental correctness).
- Step 12: `rep(1, NULL)` → `integer(0)` (not NULL). `rscales` is silently corrupted. ✗
- Step 13: `.validate_rscales(integer(0), NULL)` → `length(integer(0)) == NULL` → `logical(0)` → `if (logical(0))` → R error: "argument is of length zero". ✗

So a literal implementation crashes with an opaque R error on any `repweights = NULL` call. The spec's stated behavior ("When `repweights = NULL`, all rep-related variables are stored as NULL") requires skipping steps 5–15 entirely and constructing at step 16 directly.

The test "repweights = NULL ignores type" would catch this (expects no error, gets R error from step 13).

Options:
- **[A]** Change "go directly to step 11" to "go directly to step 16 (construct and return)" in step 4. — Effort: low, Risk: low, Impact: correct; no code ambiguity, Maintenance: none.
- **[B]** Add an explicit NULL-guard at the top of step 11: "If repweights is NULL, skip to step 16." — Effort: low, Risk: low, Impact: correct but more verbose, Maintenance: none.
- **[C] Do nothing** — builder must infer the correct step from context; opaque R error in tests reveals the bug.

**Recommendation: [A]** — Change "step 11" to "step 16" in step 4. One-word fix, zero ambiguity.

---

#### SUGGESTION

**Issue 2: Test-spec has duplicate `print.survey_nonprob` JK2 and JKn test bullets**
Severity: SUGGESTION
Section: Per-function test plan — `print.survey_nonprob` → Happy paths
Violates engineering-preferences.md §1 (DRY).

Lines 261–265 and lines 274–278 of the test-spec are identical:

```
- **JK2 header text**: construct a JK2 nonprob design. Assert output contains "JK2".
- **JKn header text**: construct a JKn nonprob design. Assert output contains "JKN" (uppercased).
```

Both appear once inside the "happy paths" block and once again lower in the same block. The builder would write two identical test blocks.

Options:
- **[A]** Remove lines 274–278 (the duplicate bullets). The snapshot tests for JK2 and JKn that follow (lines 282–286) already cover these cases. — Effort: low, Risk: none.
- **[B]** Keep both; builder deduplicates by combining `expect_output()` + `expect_snapshot()` in a single block.
- **[C] Do nothing** — builder writes two redundant test blocks.

**Recommendation: [A]** — Remove the duplicate bullets. The JK2/JKn snapshot tests already provide coverage; the `expect_output()` assertions are redundant.

---

**Issue 3: No test asserts `@variables$rscales == NULL` for the `repweights = NULL` case**
Severity: SUGGESTION
Section: Per-function test plan — `as_survey_nonprob()` → Edge cases
Applies testing-standards.md §2 (test the contract, not just the happy path).

The edge case "repweights = NULL ignores type" (test-spec line 91) asserts `design@variables$type == NULL` but does not assert `design@variables$rscales == NULL`, `design@variables$scale == NULL`, or `design@variables$mse == NULL`. The Returns section of the spec explicitly states all four must be NULL when repweights is NULL.

If Issue 1 above is fixed incorrectly (e.g., step 12 still runs with `R = NULL`), rscales could silently end up as `integer(0)` — a value that would not break analysis dispatch (since the SRS path is taken) but violates the documented `@variables` contract.

Options:
- **[A]** Expand the existing edge case assertion to cover all four NULL values:
  ```r
  expect_null(design@variables$type)
  expect_null(design@variables$scale)
  expect_null(design@variables$rscales)
  expect_null(design@variables$mse)
  ```
- **[B]** Leave as-is; Issue 1's fix should prevent the bug, and analysis dispatch tests catch regressions indirectly.
- **[C] Do nothing**.

**Recommendation: [A]** — These four assertions take five lines and pin the complete @variables contract for the NULL repweights case. Low effort, clear value.

---

**Issue 4: No snapshot for `summary.survey_nonprob` with JK2 or JKn designs**
Severity: SUGGESTION
Section: Per-function test plan — `summary.survey_nonprob` → Happy paths

The test-spec has `expect_snapshot(summary(jk1_design))` but no corresponding snapshot for JK2 or JKn summary output. The header line for JK2 summary contains "JK2" (via `toupper("JK2") = "JK2"`) and for JKn contains "JKN" (via `toupper("JKn") = "JKN"`) — visually different from JK1, and a regression there would be silent without a snapshot.

Options:
- **[A]** Add `expect_snapshot(summary(jk2_design))` and `expect_snapshot(summary(jkn_design))`. — Effort: two lines.
- **[B]** Leave as-is; JK2/JKn differ only in the type string, and the assert-output tests for JK2 and JKn already check the string is present.
- **[C] Do nothing**.

**Recommendation: [A]** — Consistent with the snapshot policy used for print (which does snapshot JK2 and JKn). Two lines.

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 1 |
| SUGGESTION | 3 |

**Total issues:** 4

**Overall assessment:** All Pass 1 findings are fully resolved and the spec is substantially ready for implementation. One REQUIRED fix remains: a step-number typo in the decision tree (step 4 routes to step 11 instead of step 16) that would cause a runtime R error on any `repweights = NULL` call. The three suggestions are low-effort polish items; none blocks implementation.
