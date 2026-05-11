## Spec Review: variable-direction — Pass 1 (2026-05-06)

### New Issues

#### Section: V. PR 3 — `get_diffs()` extensions

---

**Issue 1: Console output example contradicts the favorability logic table**
Severity: BLOCKING
Violates engineering-preferences.md §5 (explicit over clever); internal spec inconsistency.

The favorability logic table (Section V) and the console output example directly contradict each other for rows 1 and 4.

Logic table rules (for `higher_is = "worse"`):
- Positive estimate + significant → `favorable = FALSE`, `backlash = TRUE`
- Negative estimate + significant → `favorable = TRUE`, `backlash = FALSE`

The example (annotated as `x = anxiety, higher_is = "worse"`):

| Row | estimate | p_value | favorable (example) | backlash (example) | Per table |
|-----|----------|---------|---------------------|--------------------|-----------|
| 1   | +0.300   | 0.003   | TRUE                | FALSE              | favorable=FALSE, backlash=TRUE ❌ |
| 2   | -0.200   | 0.048   | TRUE                | FALSE              | favorable=TRUE, backlash=FALSE ✅ |
| 3   | +0.100   | 0.340   | FALSE               | FALSE              | ✅ |
| 4   | -0.100   | 0.021   | FALSE               | TRUE               | favorable=TRUE, backlash=FALSE ❌ |

Rows 1 and 4 have their `favorable` and `backlash` columns transposed in the example. An implementer following the example would produce the opposite classification from the one described in the table. The table is internally consistent with the footnote ("negative diff on a 'worse' variable is favorable"); the example is wrong.

Options:
- **[A]** Fix the example to match the table: row 1 → `FALSE TRUE`; row 4 → `TRUE FALSE`. — Effort: low, Risk: low, Impact: removes blocking ambiguity, Maintenance: none
- **[B]** Fix the table to match the example — Effort: low, Risk: high (the table logic is correct; this would reverse the intended semantics), Impact: wrong output
- **[C] Do nothing** — implementer guesses; 50% chance of incorrect output

**Recommendation: A** — The logic table is correct and consistent with the footnote. Correct the example.

---

**Issue 2: `direction` parameter name collision across the PR series**
Severity: REQUIRED
Violates API Coherence (Lens 6) — same parameter name, opposite semantics in sister functions.

The spec introduces `direction` with two unrelated meanings:

- `set_higher_is(x, ..., variable = NULL, direction = NULL)` — `direction` is a character value: `"better"` or `"worse"`. It represents the semantic direction of a variable.
- `get_diffs(..., direction = FALSE)` — `direction` is a boolean switch: `TRUE` means "add `favorable`/`backlash` columns." It is not a direction value.

A user who reads `set_higher_is()` first will expect `direction` in `get_diffs()` to mean a direction value (e.g., `direction = "worse"`), or to override the stored `higher_is` attribute. Instead, `direction = TRUE` means "enable the direction-based classification feature." This is the kind of API confusion that survives all tests but causes workflow errors.

The `get_diffs()` argument would be clearer as `show_direction`, `add_direction`, `classify`, or `favorability`.

Options:
- **[A]** Rename the `get_diffs()` argument. Candidates: `favorability = FALSE` (most self-documenting), `show_direction = FALSE` (mirrors column-name intent), `classify = FALSE` (compact). — Effort: low (spec edit only), Risk: low, Impact: eliminates naming collision before any code ships, Maintenance: none
- **[B]** Keep the name but add a usage note in both functions' docs warning about the overloading — Effort: low, Risk: medium (users still see two `direction` params), Impact: partial mitigation
- **[C] Do nothing** — collision ships; confusing at best, silent errors possible in workflows that use both

**Recommendation: A** — `favorability = FALSE` is the clearest choice: it names the output concept (favorability classification) rather than the mechanism.

---

#### Section: III. PR 1 — `set_higher_is()` / `extract_higher_is()`

---

**Issue 3: `extract_higher_is()` error table missing ambiguous-input error class**
Severity: REQUIRED
Violates testing-standards.md §2 (every error table entry covered by a test).

Behavior rule 2 for `extract_higher_is()` states: "Cannot supply both `...` and `variable`." This is enforced behavior, but no error class is listed in the error table for the extractor. The setter (`set_higher_is()`) defines `surveycore_error_higher_is_ambiguous_input` for this case, but the extractor's error table only lists:
- `surveycore_error_not_survey_or_df`
- `surveycore_warning_var_not_found`

An error class is needed for the extractor's ambiguous-input case, and a corresponding test in the PR 1 test plan. The same gap exists for `extract_reverse_coded()` (Section IV, Issue 7 below).

Options:
- **[A]** Add `surveycore_error_higher_is_ambiguous_input` (same class as the setter) to the `extract_higher_is()` error table, and add a test block. — Effort: low, Risk: low, Impact: complete error coverage
- **[B]** Define a separate extractor-specific class `surveycore_error_higher_is_extract_ambiguous_input` — Effort: low, Risk: low, Impact: finer-grained distinction, more classes to maintain
- **[C] Do nothing** — behavior rule is stated but untestable; error message has no class=, violating code-style.md §3

**Recommendation: A** — Reuse the setter's class for the same ambiguous-input condition; fewer classes, consistent semantics.

---

**Issue 4: Convention 3 — vector length mismatch between `variable` and `direction` is unspecified**
Severity: REQUIRED
Violates contract completeness (Lens 3) and engineering-preferences.md §4 (handle edge cases).

The spec shows Convention 3 with vectorized usage:
```r
set_higher_is(x, variable = c("anxiety", "worry"), direction = c("worse", "worse"))
```

But it does not specify what happens when lengths differ:
```r
set_higher_is(x, variable = c("anxiety", "worry"), direction = "worse")
# recycle? error? silently apply to first only?

set_higher_is(x, variable = c("anxiety", "worry"), direction = c("worse", "better", "worse"))
# error? truncate?
```

R's default recycling would silently use `"worse"` for both — which may be convenient — but no explicit decision is documented. Implementers and callers need to know whether recycling is intentional or an error.

Options:
- **[A]** State that scalar `direction` is recycled to match `variable` length; `direction` length > 1 and != `length(variable)` is `surveycore_error_direction_invalid` (or a new length-mismatch class). — Effort: low, Risk: low, Impact: natural behavior with explicit boundary
- **[B]** Require `direction` length to exactly match `variable` length or be scalar; length mismatch → error — Effort: low, Risk: low
- **[C] Do nothing** — recycling is implicit; a user passing `direction = c("worse", "better")` with three variables gets surprising silent behavior

**Recommendation: A** — Scalar recycling is the most useful behavior and matches R conventions; explicit error for non-scalar, non-matching length.

---

**Issue 5: Missing test — `extract_higher_is()` and `extract_reverse_coded()` with `surveycore_error_not_survey_or_df`**
Severity: REQUIRED
Violates testing-standards.md §2 — every row in the error table covered by a test.

Both extractor error tables list `surveycore_error_not_survey_or_df`, but neither function's test plan in Section VI includes a test block for this error. The setter test plans do include this case. The extractor test plans for PR 1 only list:
- `direction_invalid` (setter)
- `higher_is_ambiguous_input` (setter)
- `higher_is_no_vars` (setter)
- `var_not_found` (setter + extractor)

No extractor-specific error path tests are listed for `not_survey_or_df`.

Options:
- **[A]** Add two test blocks to PR 1 test plan: `extract_higher_is(list(), anxiety)` → `surveycore_error_not_survey_or_df` with snapshot; `extract_reverse_coded(list(), anxiety)` → same. — Effort: low, Risk: none, Impact: completes error coverage
- **[B] Do nothing** — missing tests; error class is implemented but untested

**Recommendation: A** — required for test completeness.

---

#### Section: IV. PR 2 — `reverse_coded` attribute

---

**Issue 6: `extract_reverse_coded()` error table missing ambiguous-input error class (mirrors Issue 3)**
Severity: REQUIRED

Same gap as Issue 3. Behavior rule 2 for `extract_reverse_coded()` states "Cannot supply both `...` and `variable`," but the error table has no class for this case. `set_reverse_coded()` defines `surveycore_error_reverse_coded_ambiguous_input`, but the extractor's error table only lists `not_survey_or_df` and `var_not_found`.

Options:
- **[A]** Add `surveycore_error_reverse_coded_ambiguous_input` to `extract_reverse_coded()` error table and a test block. — Effort: low
- **[B]** Separate extractor-specific class — see Issue 3 discussion
- **[C] Do nothing** — same consequence as Issue 3

**Recommendation: A**

---

#### Section: V. PR 3 — `get_diffs()` extensions (continued)

---

**Issue 7: `name_style = "broom"` behavior for `favorable`/`backlash` columns is unspecified**
Severity: REQUIRED
Violates contract completeness (Lens 3).

`get_diffs()` supports `name_style = "broom"` which renames output columns (`p_value` → `p.value`, `ci_low` → `conf.low`, etc.). The spec introduces `favorable` and `backlash` as new output columns but does not specify their names under `name_style = "broom"`.

Options:
- **[A]** Declare that `favorable` and `backlash` are unaffected by `name_style` (they have no broom equivalents); document this explicitly. — Effort: low, Risk: low
- **[B]** Define broom equivalents (e.g., same names — `favorable`, `backlash` — since these are already lower-case snake-case). — Effort: low
- **[C] Do nothing** — implementer decides; inconsistent behavior possible

**Recommendation: A** — The simplest correct answer: these are surveycore-native columns with no broom analogue; names are invariant across `name_style`.

---

**Issue 8: Missing test — `direction = TRUE` with `name_style = "broom"` (p.value column)**
Severity: REQUIRED
Violates testing-standards.md §2 (error paths / variant coverage).

The spec states: "The p-value column used is `p_value` (surveycore name style) or `p.value` (broom name style) — whichever is present after `name_style` is applied." This is a conditional code path (check for `p_value` first, fall back to `p.value`). No test in the PR 3 test plan exercises the `name_style = "broom"` code path for favorability classification. Without this test, the broom branch is untested and could be broken silently.

Options:
- **[A]** Add a test: `get_diffs(d, x, treats, direction = TRUE, name_style = "broom")` — verify `favorable`/`backlash` columns are present and correctly classified using `p.value`. — Effort: low, Risk: none
- **[B] Do nothing** — broom code path untested; regression risk high

**Recommendation: A**

---

#### Section: VI. Testing

---

**Issue 9: Missing test — `extract_higher_is()` and `extract_reverse_coded()` returning `character(0)` / `logical(0)` when `variable` argument names don't match any column**
Severity: REQUIRED
Violates contract completeness (the zero-length return case is specified but not tested).

The spec states: "If no variables match, returns a zero-length named `character(0)`" for `extract_higher_is()`. This case occurs when `variable = "nonexistent"` is passed and the warning fires (skipping), leaving an empty result. The test plan tests the warning but not the structure of the return value in that case. An implementer could return `NULL` or an unnamed vector and no test would catch it.

Options:
- **[A]** Add assertion to the `var_not_found` warning test: after the warning fires, verify the return value is `character(0)` (named, length 0) for `extract_higher_is()` and `logical(0)` (named) for `extract_reverse_coded()`. — Effort: low
- **[B] Do nothing** — return value shape for zero-match case is untested

**Recommendation: A**

---

#### Cross-cutting

---

**Issue 10: No shared variable-name resolution helper specified (DRY gap across all four functions)**
Severity: SUGGESTION
Violates engineering-preferences.md §1 (DRY — flag repetition aggressively).

All four functions (`set_higher_is()`, `extract_higher_is()`, `set_reverse_coded()`, `extract_reverse_coded()`) must parse variable names from either tidy-select `...` or `variable = character`. This is the same logic in each. The spec does not mention a shared helper for this resolution — implementers will write it four times, or extract it informally.

The existing metadata system likely already has `.resolve_tidy_select()` or a similar helper for the `extract_var_label()` / `set_var_label()` family. If so, that helper should be referenced. If not, a new shared helper should be specified.

Options:
- **[A]** Reference the existing resolution helper (name it in the spec) or declare a new internal helper (e.g., `.resolve_var_names(x, dots, variable)`) and specify that all four functions use it. — Effort: low, Risk: low, Impact: DRY-compliant, consistent behavior
- **[B]** Leave as-is, trusting the implementer to extract naturally — Effort: none for spec, Risk: medium (four separate implementations that may diverge)
- **[C] Do nothing**

**Recommendation: A** — At minimum, name the existing helper if one exists; if not, add a shared-helper specification.

---

**Issue 11: Convention 2 for `set_higher_is()` — parsing complexity not specified**
Severity: SUGGESTION
Violates contract completeness (Lens 3) for an unusual code path.

Convention 2 for `set_higher_is()` passes a named list as the sole argument to `...`:
```r
set_higher_is(x, list(anxiety = "worse", agreement = "better"))
```
This requires the function to detect: `...` length == 1 AND the element is an unnamed list with named entries. The spec does not describe this detection logic, what happens if the list is unnamed (`list("worse", "better")`), or whether this path reuses an existing helper from `set_variable_labels()`.

`set_reverse_coded()` explicitly does NOT support Convention 2 (it follows `set_sata()`). The asymmetry is not called out.

Options:
- **[A]** Add a sentence specifying the Convention 2 detection rule (e.g., "if `...` contains exactly one unnamed list with named elements, treat as named pairs"), note the asymmetry with `set_reverse_coded()`, and reference any existing helper. — Effort: low
- **[B]** Remove Convention 2 from the spec for `set_higher_is()` — Conventions 1 and 3 already cover all use cases — Effort: low, simplifies implementation
- **[C] Do nothing** — implementer infers parsing logic

**Recommendation: A** — Convention 2 is a valid convenience; just specify the detection rule so it's unambiguous.

---

**Issue 12: Missing test — `direction = TRUE` with `group` argument in `get_diffs()`**
Severity: SUGGESTION
Applies testing-standards.md Lens 2 category 3 (grouped analysis).

The PR 3 test plan does not include a test for `direction = TRUE` combined with `group`. Since `favorable`/`backlash` are appended row-by-row from the p-value column, they should work transparently with grouping — but this is unverified. Group output multiplies rows, and the column-append logic should apply identically. A test would confirm no off-by-one or row-alignment bug.

Options:
- **[A]** Add one happy-path test: `get_diffs(d, x, treats, group = g, direction = TRUE)` — verify `favorable`/`backlash` columns appear and rows align correctly per group. — Effort: low
- **[B] Do nothing** — grouped behavior is probably correct but unconfirmed

**Recommendation: A** — Low effort, closes an obvious gap.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 8 |
| SUGGESTION | 3 |

**Total issues:** 12

**Overall assessment:** The spec is close to implementable — the architecture is sound and the metadata property design is solid — but a factual error in the PR 3 console example (rows 1 and 4 have transposed `favorable`/`backlash` values) must be fixed before any code is written. Seven of the eight REQUIRED issues are small test-plan or contract gaps that can be resolved in Stage 4 with minimal spec edits.

---

## Spec Review: variable-direction — Pass 2 (2026-05-07)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | Console output example contradicts the favorability logic table | ✅ Resolved |
| 2 | `direction` parameter name collision across the PR series | ✅ Resolved — renamed to `show_favorability` |
| 3 | `extract_higher_is()` error table missing ambiguous-input error class | ✅ Resolved |
| 4 | Convention 3 — vector length mismatch between `variable` and `direction` is unspecified | ✅ Resolved |
| 5 | Missing test — `extract_higher_is()` and `extract_reverse_coded()` with `surveycore_error_not_survey_or_df` | ✅ Resolved |
| 6 | `extract_reverse_coded()` error table missing ambiguous-input error class | ✅ Resolved |
| 7 | `name_style = "broom"` behavior for `favorable`/`backlash` columns is unspecified | ✅ Resolved |
| 8 | Missing test — `direction = TRUE` with `name_style = "broom"` | ✅ Resolved |
| 9 | Missing test — `extract_higher_is()` and `extract_reverse_coded()` returning `character(0)` / `logical(0)` | ✅ Resolved |
| 10 | No shared variable-name resolution helper specified (DRY gap across all four functions) | ✅ Resolved |
| 11 | Convention 2 for `set_higher_is()` — parsing complexity not specified | ✅ Resolved |
| 12 | Missing test — `direction = TRUE` with `group` argument in `get_diffs()` | ✅ Resolved |

### New Issues

#### Section: VI. Testing — PR 1 test plan

**Issue 1: Convention 2 has no test in the PR 1 test plan**
Severity: REQUIRED
Violates testing-standards.md §2 — every supported calling convention must be exercised.

The spec explicitly declares Convention 2 as a supported calling convention for `set_higher_is()`:
```r
set_higher_is(x, c(anxiety = "worse", agreement = "better"))
```
And specifies a distinct detection rule (handled by `.parse_setter_input()`: exactly one unnamed element that is a named character vector). This is a real, documented code path. The PR 1 happy-path test plan covers Convention 1 and Convention 3 but contains no test for Convention 2. An implementer who misdetects Convention 2 inputs would have no failing test to catch the bug.

Options:
- **[A]** Add one happy-path test for Convention 2: `set_higher_is(x, c(anxiety = "worse", agreement = "better"))` stores both values correctly. — Effort: low, Risk: none, Impact: closes untested code path, Maintenance: none
- **[B]** Remove Convention 2 from the spec entirely (Conventions 1 and 3 already cover all use cases) — Effort: low, Risk: low (breaks a documented feature before it ships), Impact: simpler API
- **[C] Do nothing** — Convention 2 ships untested; detection bugs are undetectable

**Recommendation: A** — Convention 2 is already spec'd; one test line closes the gap.

---

#### Section: VI. Testing — PR 3 test plan

**Issue 2: Column `label` attributes on `favorable`/`backlash` not tested**
Severity: REQUIRED
Violates testing-standards.md §2 — all specified output properties must be covered by a test.

The spec explicitly specifies in the output contract:
```
attr(result$favorable, "label") <- "Favorable"
attr(result$backlash, "label") <- "Backlash"
```
The PR 3 test plan has no assertion verifying these attribute values. If an implementer forgets to set them (or sets wrong strings), no test would catch it. Every other `get_*()` column label attribute is tested via the existing test suite; `favorable` and `backlash` should be no different.

Options:
- **[A]** Add an assertion in the `show_favorability = TRUE` happy-path test: `expect_identical(attr(result$favorable, "label"), "Favorable")` and `expect_identical(attr(result$backlash, "label"), "Backlash")`. — Effort: low, Risk: none, Impact: closes specified-but-untested output contract
- **[B] Do nothing** — label attributes are specified but untested; regression risk present

**Recommendation: A** — The spec explicitly defines these attributes; one assertion per column closes the gap.

---

**Issue 3: `alpha = NA` and `alpha = Inf` explicitly named as invalid but absent from the test plan**
Severity: REQUIRED
Violates testing-standards.md §2 — every row in the error table covered by a test; behavior-rule-1 names specific invalid values.

Behavior rule 1 explicitly lists the invalid values for `alpha`: `NA`, `Inf`, `0`, `1`, and non-numeric. The test plan covers three of them (`alpha = 1.5`, `alpha = 0`, `alpha = "0.05"`) but omits:
- `alpha = NA` — explicitly listed in rule 1; `is.finite(NA)` is `FALSE` so this must be caught, but whether the error class fires correctly on `NA` input to `cli_abort()` formatting (specifically `{.val {alpha}}` with an NA value) needs testing
- `alpha = Inf` — explicitly listed in rule 1; `is.finite(Inf)` is `FALSE`, so the same validation path handles it — but it's named in the spec and absent from the test plan
- `alpha = c(0.05, 0.1)` — implied by "single" in "single numeric value"; non-scalar input is a realistic mistake and the `{.val {alpha}}` formatting with a vector should be verified

Options:
- **[A]** Add three test blocks (or expand the existing `alpha_invalid` block): `alpha = NA`, `alpha = Inf`, `alpha = c(0.05, 0.1)`. — Effort: low, Risk: none, Impact: closes three named invalid cases; confirms `cli_abort()` message renders correctly for each
- **[B]** Add only `alpha = NA` and `alpha = Inf` (the two explicitly named); treat non-scalar as implied by "single" — Effort: low, Risk: low
- **[C] Do nothing** — three named invalid inputs are untested; the message-rendering behavior for NA/vector is unverified

**Recommendation: A** — All three are realistic user mistakes; the cost is three lines.

---

#### Section: VI. Testing — PR 3, `.meta` contract

**Issue 4: `.meta$higher_is` test says "is populated" rather than asserting the actual value**
Severity: SUGGESTION
Violates engineering-preferences.md §5 (explicit over clever).

The PR 3 happy-path test says:
> `show_favorability = FALSE` (default): no `favorable`/`backlash` columns in result; `.meta$x[[x_name]]$higher_is` is populated

"Is populated" is ambiguous — an implementer could write `expect_true(!is.null(...))` and pass. The test should assert the actual value, e.g.:
```r
expect_identical(attr(result, ".meta")$x[[x_name]]$higher_is, "worse")
```
This confirms the value flows through `.extract_var_meta()` correctly, not just that the key exists.

Options:
- **[A]** Change the test description to assert the actual value: `...higher_is` equals `"worse"` (using the "worse" variable from the test setup). — Effort: low
- **[B]** Keep "is populated" — a non-NULL check is the intent — Effort: none, Risk: low
- **[C] Do nothing** — current language is ambiguous but functional

**Recommendation: A** — One word change to the test spec; forces a stronger assertion without any implementation cost.

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 3 |
| SUGGESTION | 1 |

**Total new issues:** 4

**Overall assessment:** All 12 Pass 1 issues are resolved — the spec is substantially improved. The remaining gaps are confined to the test plan: Convention 2 is untested, column label attributes are unverified, and three explicitly-named invalid `alpha` values are absent from the error-path tests. None are blockers; all require only small additions to the Section VI test plan. The spec is ready to implement after resolving these three REQUIRED items.

---

## Spec Review: variable-direction — Pass 3 (2026-05-07)

### Prior Issues (Pass 2)

| # | Title | Status |
|---|---|---|
| 1 | Convention 2 has no test in the PR 1 test plan | ✅ Resolved |
| 2 | Column `label` attributes on `favorable`/`backlash` not tested | ✅ Resolved |
| 3 | `alpha = NA` and `alpha = Inf` explicitly named as invalid but absent from the test plan | ✅ Resolved |
| 4 | `.meta$higher_is` test says "is populated" rather than asserting the actual value | ✅ Resolved |

### New Issues

#### Section: I. Scope

**Issue 1: §I scope table lists `direction` instead of `show_favorability` for PR 3**
Severity: REQUIRED
Internal spec inconsistency; originally surfaced in plan-review Pass 1 Issue 6 but not yet fixed in the spec.

The scope table row for PR 3 reads:
> `| 3 | \`get_diffs()\` extensions | \`alpha\`, \`direction\` arguments; \`favorable\`/\`backlash\` columns; \`.meta\` enrichment |`

The argument was renamed to `show_favorability` when Pass 1 Issue 2 (spec-review) was resolved. The spec body (§V argument table, §VI test plan, §VII quality gates) consistently uses `show_favorability`. The scope table alone carries the stale name.

Options:
- **[A]** Change the scope table entry: `\`alpha\`, \`show_favorability\` arguments; ...` — Effort: trivial, Risk: none, Impact: scope table matches the body, Maintenance: none
- **[B] Do nothing** — Spec body is correct; the table is vestigial and implementers reading the body won't be misled

**Recommendation: A** — A reviewer scanning only the scope table would see the wrong argument name.

---

### Summary (Pass 3)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 1 |
| SUGGESTION | 0 |

**Total new issues:** 1

**Overall assessment:** The spec is in excellent shape. All four Pass 2 issues are resolved. One vestigial `direction` in the §I scope table is the only remaining fix. The outstanding work (coverage criterion, Convention 3 test gaps, favorability block placement) lives in the implementation plan, not the spec. After correcting the scope table entry, the spec is fully ready for `/r-implement`.

---

## Spec Review: variable-direction — Pass 4 (2026-05-07)

### Prior Issues (Pass 3)

| # | Title | Status |
|---|---|---|
| 1 | §I scope table lists `direction` instead of `show_favorability` | ⚠️ Still open — spec line 32 unchanged |

### New Issues

#### Section: III. PR 1 — `set_higher_is()`

**Issue 1: `surveycore_error_setter_mixed_dots` referenced in Convention 2 description but absent from the error table**
Severity: REQUIRED
Violates contract completeness (Lens 3) and testing-standards.md §2 — every reachable error class must be in the table and tested.

The spec states in the Convention 2 detection note:
> "An unnamed list or a mixed named/unnamed `...` is not Convention 2 — it errors with `surveycore_error_setter_mixed_dots`."

This error class is reachable via `set_higher_is()` but does not appear anywhere in its error table. The table lists five classes; `setter_mixed_dots` is not among them. It is also absent from every test block in the PR 1 test plan. An implementer reading the test plan has no guidance that this error path must be exercised.

Whether this is an existing class (from `.parse_setter_input()`) or a new one, two changes are needed: (1) add it to the error table with "(existing class)" if it pre-exists, and (2) add a test block — e.g., `set_higher_is(x, list(anxiety = "worse"))` errors with `surveycore_error_setter_mixed_dots`.

Options:
- **[A]** Add `surveycore_error_setter_mixed_dots` to the `set_higher_is()` error table (mark existing if it is), and add a test block: `set_higher_is(x, list(anxiety = "worse"))` errors with that class. — Effort: low, Risk: none, Impact: complete error coverage, Maintenance: none
- **[B]** Document that this class is delegated to `.parse_setter_input()` and therefore outside the `set_higher_is()` error contract — explicitly state no test is needed — Effort: low, Risk: low (but leaves an untested reachable error path)
- **[C] Do nothing** — error fires in production with no test; class is not in the table

**Recommendation: A** — The class is reachable via a documented input; it belongs in the table and must be tested.

---

#### Section: VI. Testing — PR 3 test plan

**Issue 2: Print snapshot missing for `survey_diffs` with `show_favorability = TRUE`**
Severity: REQUIRED
Violates testing-standards.md Lens 2 category 13 — print snapshot required for every result class with a `print()` method.

The spec's §V console output example shows a 9-column `survey_diffs` output:
```
# A <survey_diffs> [4 × 9]
  treatment  estimate    se  ci_low ci_high p_value stars favorable backlash
```
This confirms `survey_diffs` has a print method and that `show_favorability = TRUE` produces a distinct column layout. The PR 3 test plan does not include a snapshot test for this output. The existing `test-analysis-diffs.R` snapshots test the baseline (without `favorable`/`backlash` columns); the new layout is tested only via column-presence and value assertions, not a print snapshot. Formatting bugs — wrong column width, missing `<lgl>` type header, alignment issues — would not be caught.

Options:
- **[A]** Add a `expect_snapshot(print(result))` call to the `show_favorability = TRUE` happy-path test block, using the design from the §V example. — Effort: low, Risk: none, Impact: closes the only unsnapshotted `survey_diffs` output variant, Maintenance: update snapshot intentionally if print format changes
- **[B]** Rely on the existing column-value assertions; treat print format as implicit — Effort: none, Risk: medium (formatting regressions undetected)
- **[C] Do nothing** — new print layout ships without a snapshot test

**Recommendation: A** — Category 13 is non-negotiable per testing-standards.md; the example in §V already defines the expected output.

---

#### Section: VI. Testing — PR 1 test plan

**Issue 3: `direction = NA` not tested for `set_higher_is()` direction_invalid error**
Severity: SUGGESTION
Consistent with Pass 2 Issue 3 (`alpha = NA` was REQUIRED there; same pattern here).

Behavior rule 2 states `direction` must be `"better"`, `"worse"`, or `NULL` — "any other value is an error." The test plan exercises only `direction = "neutral"` for the `direction_invalid` class. `NA` is a realistic mistake (`direction = NA_character_` is easy to produce accidentally from a lookup that returns NA) and hits the same validation path. No test currently verifies that `surveycore_error_direction_invalid` fires — and that the `{.val {direction}}` CLI formatting renders correctly — for an NA input.

Options:
- **[A]** Add `set_higher_is(x, anxiety = NA_character_)` to the `direction_invalid` test block (or a separate block). — Effort: low, Risk: none, Impact: confirms NA renders correctly in the error message
- **[B]** Accept the `"neutral"` test as sufficient; NA is the same code path — Effort: none, Risk: low (NA CLI rendering is slightly different than character)
- **[C] Do nothing** — NA case untested; CLI formatting with NA unverified

**Recommendation: A** — The `alpha = NA` precedent in Pass 2 was REQUIRED; direction NA is the same issue, just in a different argument. One test line.

---

## Summary (Pass 4)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 2 |
| SUGGESTION | 1 |

**Total new issues:** 3

**Overall assessment:** The spec remains in excellent shape after 3 passes — all prior blocking and most required issues are resolved. The three new issues are confined to one contract gap (Convention 2 error class absent from the error table) and two test-plan gaps (print snapshot for the new column layout, NA direction input). Pass 3 Issue 1 (scope table stale name) is still unresolved. Resolve these four items and the spec is implementation-ready.
