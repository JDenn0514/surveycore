## Spec Review: group-na-rows — Pass 1 (2026-03-02)

### New Issues

---

#### Section: II — Architecture / `.build_group_combos()`

**Issue 1: `rev(names(combos))` produces wrong primary sort key — contradicts §III example**
Severity: BLOCKING
Violates engineering-preferences.md §5 (explicit over clever); spec is internally inconsistent.

The helper code uses:
```r
sort_args <- lapply(rev(names(combos)), function(v) combos[[v]])
```

For `group = c(region, gender)`, `names(combos)` = `c("region", "gender")`, so
`rev(names(combos))` = `c("gender", "region")`, and `do.call(order, ...)` sorts
**primarily by `gender`**. The §III example table shows the opposite — sorted
**primarily by `region`**:

```
East | F   ← region is the primary key
East | M
West | F
West | M
NA   | F
NA   | M
```

A `rev()`-based sort would produce `East F, West F, NA F, East M, West M, NA M`.
The existing Pattern A code (confirmed in `analysis-freqs.R` lines 205–208) does
NOT use `rev()`:
```r
ord <- do.call(order, lapply(group_vars, function(gv) group_combos[[gv]]))
```
This is the correct form. The `rev()` in the spec is a copy-paste error that
inverts the primary sort key for multi-group combos.

Options:
- **[A]** Remove `rev()` from the helper: `lapply(names(combos), function(v) combos[[v]])` — Effort: low, Risk: low, Impact: fixes sort order to match §III example and existing behavior
- **[B]** Keep `rev()` and update the §III example table to show gender-first sort — Effort: low, Risk: low, Impact: documents a different sort order than current behavior
- **[C] Do nothing** — implementer copies the spec code and produces wrong sort order silently

**Recommendation: A** — The example is almost certainly the intended behavior;
`rev()` is a transcription error.

> **Resolution (2026-03-02): A** — `rev()` removed. Sort now uses `lapply(names(combos), ...)`. Leftmost group variable is primary sort key, matching §III example and existing Pattern A behavior.

---

**Issue 2: `order()` stability not guaranteed — spec says "stable within each group"**
Severity: REQUIRED
Violates engineering-preferences.md §5 (explicit over clever).

The spec comment reads "Sort: non-NA combos first, NA combos last; stable within
each group." R's `do.call(order, ...)` with the default `method = "auto"` is NOT
guaranteed to be stable. Two rows with the same group-variable values will appear
in arbitrary relative order between R versions. In practice this matters when
duplicate group combinations exist (unusual but possible with factor variables).

Options:
- **[A]** Replace `do.call(order, sort_args)` with a stable sort by adding `method = "radix"` (stable in R ≥ 4.0) — Effort: low, Risk: low, Impact: guarantees stability
- **[B]** Drop the "stable" language from the spec comment and document that within-tie order is unspecified — Effort: low, Risk: low, Impact: honest contract
- **[C] Do nothing** — stability is implied but not guaranteed; tests may be flaky on duplicate combos

**Recommendation: B** — `unique()` before `order()` already eliminates true
duplicates; "stable" language is unnecessary and misleading. Drop the word.

> **Resolution (2026-03-02): B** — "stable within each group" comment removed. Comment updated to state "Leftmost group variable is the primary sort key."

---

#### Section: II — Architecture / `.match_group_combo()`

**Issue 3: Scope of `.match_group_combo()` replacement unverified — spec says "all 6 functions"**
Severity: REQUIRED
Violates engineering-preferences.md §1 (DRY — flag repetition aggressively).

The spec states `.match_group_combo()` "replaces the inline `!is.na(gv_col) & (gv_col == cv)` loop
in **all 6 functions**" and the §VII QA gate requires "All 6 analysis functions use `.match_group_combo()`."
Inspection of the actual code confirms this loop in `analysis-freqs.R` (lines 287–296) and
`analysis-corr.R` (lines 247–255), but does NOT confirm its presence in `analysis-means.R`,
`analysis-totals.R`, `analysis-quantiles.R`, or `analysis-ratios.R`. If those four functions
use a different matching mechanism (e.g., vectorized masking without an explicit `for` loop),
the QA gate requires adding `.match_group_combo()` to code that never had the problematic
pattern — which may change behavior unexpectedly.

Options:
- **[A]** Audit all 6 functions before implementation; update the spec to list exactly which functions have the inline loop and which need the helper added fresh — Effort: low, Risk: low, Impact: prevents implementer from guessing
- **[B]** Leave the QA gate as written; let the implementer audit at implementation time — Effort: none, Risk: medium, Impact: implementer may miss the distinction
- **[C] Do nothing** — QA gate is wrong or right; no way to know from the spec alone

**Recommendation: A** — Auditing costs 30 minutes; discovering the error during implementation is more expensive.

> **Resolution (2026-03-02): A** — Audited all 6 functions. All 6 (`get_freqs()`, `get_means()`, `get_totals()`, `get_corr()`, `get_quantiles()`, `get_ratios()`) have the identical inline loop. QA gate confirmed accurate. Spec updated to state this explicitly.

---

**Issue 4: `data_cols` construction for `.match_group_combo()` never shown at call sites**
Severity: REQUIRED
Violates engineering-preferences.md §5 (explicit over clever).

The spec defines `.match_group_combo(data_cols, combo_row)` where `data_cols` is "named list;
one element per group var; each a vector of equal length equal to `nrow(design@data)`." But the
spec never shows HOW any of the 6 functions build and pass `data_cols`. Two plausible
interpretations:

1. `as.list(design@data[group_vars])` — slices full `@data` to group vars as a list
2. `as.list(design@data[domain_mask, group_vars, drop = FALSE])` — domain-filtered subset

These produce vectors of different lengths (`nrow(design@data)` vs `sum(domain_mask)`). The
current inline loop in `analysis-freqs.R` uses `design@data[[gv]]` (full length), then
applies `domain_mask & group_match` together. If callers pre-filter before building `data_cols`,
the mask is applied twice.

Options:
- **[A]** Add a call-site example in §II showing exactly how one function (e.g., `get_means()`) calls `.match_group_combo()`, including how `data_cols` is constructed — Effort: low, Risk: low, Impact: eliminates ambiguity
- **[B]** Update the `@param data_cols` description to specify "unfiltered, full-design length — callers apply `domain_mask` in the returned logical vector afterwards" — Effort: low, Risk: low, Impact: partial clarity
- **[C] Do nothing** — implementer makes a choice; 50% chance it's wrong

**Recommendation: A** — one concrete call-site example removes all ambiguity.

> **Resolution (2026-03-02): A** — Call-site example added to §II. `data_cols = as.list(design@data[group_vars])` (full-design-length); `active_mask <- domain_mask & group_match`. `@param data_cols` description updated to specify "NOT domain-filtered."

---

#### Section: III — Behavioral Contract

**Issue 5: Domain estimation + NA group rows — interaction unspecified (BLOCKING)**
Severity: BLOCKING
Violates engineering-preferences.md §4 (handle edge cases explicitly).

When domain estimation (via `filter()` or a `domain` argument) excludes rows where the group
variable is `NA`, what does `na.rm = FALSE` produce? Two valid interpretations:

- **(A) Domain first:** `domain_mask` is applied before collecting group combos. NA group rows
  are derived from domain-eligible rows only. If all `group = NA` rows are outside the domain,
  no NA row appears in the output.
- **(B) Full design first:** NA group rows are identified from the full design, then intersected
  with the domain. This could produce an NA-group row with zero effective weight.

§III never addresses this. The spec does say `.build_group_combos(domain_data, ...)` where
`domain_data` is "already filtered to the active domain rows" — which implies interpretation A.
But this is buried in a helper description, not stated as the behavioral contract.

Options:
- **[A]** Add a sentence to §III: "When domain estimation is active, the NA group row (if any)
  is derived from domain-eligible rows only. If no domain-eligible row has `group = NA`, no NA
  group row appears in the output." — Effort: low, Risk: low, Impact: eliminates the ambiguity
- **[B]** Add a test block for domain + NA group interaction — Effort: medium, Risk: low
- **[C] Do nothing** — implementers may disagree on behavior; cross-function inconsistency risk

**Recommendation: A** — one sentence; high leverage.

> **Resolution (2026-03-02): A** — Sentence added to §III after the `na.rm = FALSE` behavioral paragraph: "When domain estimation is active, the NA group row (if any) is derived from domain-eligible rows only. If no domain-eligible row has a group variable equal to `NA`, no NA group row appears in the output."

---

**Issue 6: All-NA group variable triggers `surveycore_warning_single_group_level` — Test Block 6 missing `expect_warning()`**
Severity: REQUIRED
Behavioral contract gap; §VI Test Block 6 will fail as written.

§III states: "The warning that fires when a group variable has only one non-NA unique value checks
`unique(gv_vals[!is.na(gv_vals)])`. This check is unchanged."

When ALL group values are `NA`:
- `gv_vals[!is.na(gv_vals)]` → `character(0)`, length 0
- 0 < 2 non-NA unique values → **warning fires**

Test Block 6 calls `get_X(design_all_na_group, x, group = grp, na.rm = FALSE)` without
`expect_warning()` or `suppressWarnings()`. As written, the test will fail because the
warning is signaled but not expected.

Options:
- **[A]** Update Test Block 6 to use `expect_warning(..., class = "surveycore_warning_single_group_level")` wrapping the call — Effort: low, Risk: low, Impact: test passes, contract documented
- **[B]** Suppress the warning when `na.rm = FALSE` and all values are NA (new behavior) — Effort: medium, Risk: medium, Impact: cleaner UX but contradicts §III "unchanged" statement
- **[C] Do nothing** — test fails at implementation time; implementer must guess the intended behavior

**Recommendation: A** — least disruption; documents the correct expectation explicitly.

> **Resolution (2026-03-02): A** — Test Block 6 wrapped in `expect_warning(class = "surveycore_warning_single_group_level")`. Explanatory note added above the block explaining why the warning fires (0 non-NA unique values < 2).

---

**Issue 7: `(NA, NA)` multi-group combination not explicitly addressed**
Severity: SUGGESTION
Gap in §III behavioral contract.

§III shows a multi-group example where only `region` has `NA` values, leaving `gender` always
defined. The spec does not state what happens when BOTH group variables have `NA` for the same
row. The (NA, NA) combination would appear naturally via `unique()` in `.build_group_combos()`,
but this is not stated. A reader wondering about this must infer it.

Options:
- **[A]** Add one sentence to the multi-variable group section: "When multiple group variables
  have `NA` values simultaneously, the (NA, NA, ...) combination appears as a single row." — Effort: low
- **[B]** Add a multi-(NA, NA) case to Test Block 5 — Effort: low
- **[C] Do nothing** — behavior is implied by the helper code; skip the clarification

**Recommendation: A** — adds one sentence, closes a common reader question.

> **Resolution (2026-03-02): A** — Sentence added to §III after the multi-variable group example table: "When multiple group variables have `NA` values simultaneously for the same row, the `(NA, NA, ...)` combination appears as a single row in the output (not one row per variable)."

---

#### Section: IV — Updated `@param na.rm`

**Issue 8: `@param na.rm` doc text imprecise for `get_freqs()` focal-variable NA semantics**
Severity: SUGGESTION
User-facing documentation gap.

The unified `@param na.rm` text (§IV) says: "If `FALSE`, `NA` observations in the analysis
variable are **included in calculations**." For `get_freqs()`, existing `na.rm = FALSE` behavior
is NOT simply "included in calculations" — NA values in the focal variable appear as their own
frequency row (a different behavioral mode). The new doc text could mislead `get_freqs()` users
into thinking NAs are merely counted rather than surfaced as a distinct row.

Options:
- **[A]** Add a `get_freqs()`-specific `@param na.rm` note: "For `get_freqs()`, when
  `na.rm = FALSE`, `NA` values in the focal variable appear as a dedicated frequency row." — Effort: low
- **[B]** Accept that per-function nuance belongs in the function description body, not `@param` — Effort: none
- **[C] Do nothing** — existing behavior is documented elsewhere; doc is not wrong, just incomplete

**Recommendation: B** — the `@param` is a summary; the function description body is the right place for per-function nuance. Flag as documentation debt for the vignette.

> **Resolution (2026-03-02): A (user preference over recommendation)** — §IV now provides two templates: a unified one for the 5 non-freqs functions, and a `get_freqs()`-specific version that explicitly states NA focal-variable values appear as a dedicated frequency row.

---

#### Section: VI — Testing

**Issue 9: Numerical oracle tests use unresolved `<estimate_col>` placeholder**
Severity: REQUIRED
Violates testing-standards.md §2 (numerical oracle tests required per function).

The "Numerical accuracy" block at the end of §VI uses `<estimate_col>` as a placeholder:
```r
expect_equal(na_row$<estimate_col>, expected$<estimate_col>, tolerance = 1e-10)
```
This placeholder is not filled in. Each of the 6 functions has a different estimate column name:

| Function | Estimate column(s) |
|---|---|
| `get_freqs()` | `prop` (or `n`) |
| `get_means()` | `mean` |
| `get_totals()` | `total` |
| `get_corr()` | `correlation` |
| `get_quantiles()` | `quantile` |
| `get_ratios()` | `ratio` |

Test files written from this template will not compile. Also, Test Block 4 ("NA group row has finite
estimates") has the same `$<estimate_col>` gap.

Options:
- **[A]** Replace `<estimate_col>` with the actual column name per function in both the numerical oracle block and Test Block 4 — Effort: low, Risk: low, Impact: test code becomes copy-pasteable
- **[B]** Add a table of estimate column names per function immediately before §VI as a reference — Effort: low
- **[C] Do nothing** — implementers fill in from knowledge of each function's output schema

**Recommendation: A** — takes 10 minutes, prevents copy-paste bugs across 12 test blocks.

> **Resolution (2026-03-02): A** — Per-function column names added inline to both Test Block 4 and the numerical oracle block as per-function `expect_true`/`expect_equal` lines. Reference table (function → estimate column + SE column) added before §VI test blocks.

---

**Issue 10: NA group rows not tested across all 4 design classes**
Severity: REQUIRED
Violates testing-surveycore.md (variance tests must cover all design classes).

All six test block templates (§VI) imply a single design type. The support matrix (§I) says all
4 design classes are supported. There is no requirement to verify that NA group rows appear
correctly for `survey_replicate`, `survey_twophase`, or `survey_srs` designs. If the domain-mask
accumulation path differs by class (it does — each variance class has its own cell computation),
a bug in one class's NA-group handling would go undetected.

Options:
- **[A]** Add a 7th required test block: "NA group row appears and is correct for each design class (replicate, twophase, srs)" — one test file per function or a shared helper — Effort: medium
- **[B]** Add a blanket statement: "Tests 1–6 should be run once per design class" — Effort: low, Impact: high (36 tests become 36×4 = 144, too many without automation)
- **[C]** Require that the numerical oracle test (§VI "Numerical accuracy") is run for each design class — Effort: medium, Risk: low, Impact: targeted, practical

**Recommendation: C** — numerical oracle test run across all 4 classes covers the essential behavior without multiplying all 6 blocks by 4.

> **Resolution (2026-03-02): C** — Numerical oracle section updated to require the oracle test for all 5 design classes (`survey_taylor`, `survey_replicate`, `survey_twophase`, `survey_srs`, `survey_nonprob`). Note: class count updated to 5 per Issue 14 resolution. Added to Quality Gates.

---

**Issue 11: `label_values = TRUE` with NA group rows — behavioral contract stated but not tested**
Severity: REQUIRED
§III states a testable behavioral contract with no corresponding test.

§III says: "When `label_values = TRUE` converts a group column to a factor, `NA` values remain
`NA` in the factor (not a new level)." This is a clear, falsifiable contract. §VI has no test
block that:
1. Sets group variable labels
2. Calls with `label_values = TRUE` and `na.rm = FALSE`
3. Asserts the NA group row's group column is `NA` (not a factor level `"NA"` or similar)

Options:
- **[A]** Add a 7th required test block: "NA group row group column is NA (not a factor level) when `label_values = TRUE`" — Effort: low, Risk: low
- **[B]** Fold this into Test Block 2 with an additional assertion — Effort: low
- **[C] Do nothing** — behavior is implied; test at review time

**Recommendation: A** — this is a non-obvious behavior (`NA` in a factor vs. a new `"NA"` level); it merits its own block.

> **Resolution (2026-03-02): Extended A (user-directed scope extension)** — Two test blocks added (7a and 7b), and §III "Output column types" extended with a new behavioral contract. User identified that haven-labeled NAs (tagged NAs with associated value labels, e.g., "Refused") should be converted to factor levels under `label_values = TRUE`, not remain as `NA`. §III now distinguishes: regular `NA` (no label) → remains `NA` in factor; haven-labeled `NA` (has label) → converted to factor level. Test Block 7a covers regular NA; Test Block 7b covers haven-labeled NA.

---

**Issue 12: Shared test fixture for NA-group designs not specified — DRY concern**
Severity: REQUIRED
Violates testing-standards.md §4 (repeated test setup → move to `helper-*.R`).

6 functions × 6 test blocks = 36 blocks that all need a survey design with a group variable
containing `NA` values. Test Block 5 also needs a second group variable for multi-group testing.
Test Block 6 needs an all-NA group design.

`make_survey_data()` (per `testing-surveycore.md`) has no parameters for injecting NA group
values. Each test file will construct its own fixture independently — a DRY violation that creates
maintenance risk when the fixture needs to change.

Options:
- **[A]** Specify a shared helper in `tests/testthat/helper-test-data.R`: `make_na_group_design(n = 200, na_frac = 0.2, seed = 42)` that returns a survey design with one group variable having `na_frac` of values set to `NA` — Effort: low, Risk: low
- **[B]** Add inline fixture instructions to §VI showing the 5-line setup that each test file should replicate — Effort: low, but still duplicated
- **[C] Do nothing** — leave fixture construction to each implementer

**Recommendation: A** — one helper definition in the spec prevents 6 divergent implementations.

> **Resolution (2026-03-02): A** — Two shared helpers specified in §VI and added to Quality Gates: `make_na_group_design(n, na_frac, seed)` (standard NA-group design with `grp` and `grp2` columns) and `make_all_na_group_design(n, seed)` (all-NA group design for Test Block 6). Both defined in `tests/testthat/helper-test-data.R`.

---

**Issue 13: No test block for `group_by()` path with `na.rm = FALSE`**
Severity: REQUIRED
§VIII contract stated; §VI tests omit it.

§VIII says: "Groups set via `group_by()` obey the same `na.rm` contract as groups set via
`group =` directly — no separate handling needed." This is a behavioral assertion about the
`design@groups` code path in `.resolve_groups()`, which differs from the `group =` argument path.
§VI has no test block exercising `group_by()` + `na.rm = FALSE`. If the code path diverges (e.g.,
`@groups` is resolved before or after domain masking, or without calling `.build_group_combos()`),
the untested path would silently exclude NA group rows.

Options:
- **[A]** Add a required test block: "NA group rows appear when groups set via `group_by()` and `na.rm = FALSE`" — Effort: low, Risk: low, Impact: closes the integration gap
- **[B]** Remove §VIII and state that `group_by()` groups are resolved into the `group =` argument before any processing (making the code path identical) — Effort: medium
- **[C] Do nothing** — implementers may catch this during integration testing

**Recommendation: A** — one block, one `group_by()` call, one `expect_true(anyNA(result$grp))`.

> **Resolution (2026-03-02): A** — Test Block 8 added: calls `surveytidy::group_by(make_na_group_design(), grp) |> get_X(x, na.rm = FALSE)` and asserts `anyNA(result$grp)`.

---

**Issue 14: `survey_nonprob` class absent from support matrix**
Severity: REQUIRED
Spec says "All 6 analysis functions support all 4 design classes" but omits an implemented class.

The support matrix (§I) lists `survey_taylor`, `survey_replicate`, `survey_twophase`, `survey_srs`.
Code inspection confirms `survey_nonprob` is already implemented and dispatched in
`analysis-helpers.R` (`.build_meta()` line 245, `.degf()` line 586). The spec's 4-class matrix
is incomplete. If the implementation plan treats only 4 classes as in-scope, a reviewer would
reasonably accept code that breaks `survey_nonprob` NA group rows.

Options:
- **[A]** Add `survey_nonprob` as a 5th column in the support matrix — Effort: low, Risk: low, Impact: accurate scope
- **[B]** Explicitly state that `survey_nonprob` is out of scope for this feature with a rationale — Effort: low
- **[C] Do nothing** — ambiguity about whether `survey_nonprob` is in scope

**Recommendation: A** — if the class exists and is dispatched, it belongs in the matrix.

> **Resolution (2026-03-02): A** — `survey_nonprob` added as 5th column to §I support matrix. §I intro updated from "all 4 design classes" to "all 5 design classes." Quality Gates oracle test requirement updated accordingly.

---

**Issue 15: Test Block 6 fixture `design_all_na_group` not shown**
Severity: SUGGESTION
Per testing-standards.md §4 (edge case data should be inline and self-documenting).

Test Block 6 references `design_all_na_group` without showing how to construct it. This is an
unusual edge case (all group values are NA) that implementers cannot derive from `make_survey_data()`.
The fixture should be shown inline in the spec so the test is self-documenting.

Options:
- **[A]** Add 4–5 lines showing the fixture construction before Test Block 6:
  ```r
  df_all_na <- make_survey_data(n = 100, seed = 1)
  df_all_na$grp <- NA_character_
  design_all_na_group <- as_survey(df_all_na, ids = psu, weights = weight, strata = strata)
  ```
  — Effort: low
- **[B]** Add to the shared helper from Issue 12 as a parameter: `make_na_group_design(all_na = TRUE)` — Effort: low
- **[C] Do nothing** — implementer constructs the fixture ad hoc

**Recommendation: A or B** — inline in spec for self-documentation; share with helper if Issue 12 is adopted.

> **Resolution (2026-03-02): A (via Issue 12's helper)** — Test Block 6 updated to call `make_all_na_group_design(n = 100, seed = 1)` directly. The helper is defined in §VI shared fixtures section (from Issue 12). Test is now self-contained.

---

**Issue 16: Helper placement cites wrong section of `code-style.md`**
Severity: SUGGESTION
Minor documentation inaccuracy.

The spec states: "Internal helpers follow `code-style.md §4`: used in 2+ source files → live in
`R/analysis-helpers.R`." `code-style.md §4` says helpers used in 2+ files go to `07-utils.R`
(the file has since been renamed `utils.R`). The spec's destination (`analysis-helpers.R`) is
correct per established package structure (Phase 1 helpers live there), but the rule citation
is wrong. An implementer who reads `code-style.md §4` literally would put the helpers in `utils.R`.

Options:
- **[A]** Change the citation: "Consistent with the existing analysis helper pattern established in Phase 1, new helpers that are used across 2+ analysis source files live in `R/analysis-helpers.R`." — Effort: low
- **[B]** Update `code-style.md §4` to mention `analysis-helpers.R` as the analysis-specific destination — Effort: low, broader fix
- **[C] Do nothing** — implementers familiar with the codebase will use `analysis-helpers.R` regardless

**Recommendation: A** — correct the citation in the spec; leave `code-style.md` for a separate update.

> **Resolution (2026-03-02): A** — Citation replaced with explicit prose: "Consistent with the existing analysis helper pattern established in Phase 1, new helpers used across 2+ analysis source files live in `R/analysis-helpers.R` (not `utils.R`, which is for package-wide utilities)."

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 2 |
| REQUIRED | 10 |
| SUGGESTION | 4 |

**Total issues:** 16

**Overall assessment:** The spec is nearly implementable — the helper API is well-defined,
the architecture is sound, and the behavioral contract covers the common cases. Two blocking
issues must be resolved before coding begins: the `rev()` sort bug in `.build_group_combos()`
will silently produce wrong multi-column sort order, and the domain + NA group interaction is
ambiguous. The bulk of the REQUIRED issues are test coverage gaps (missing design class
coverage, missing `label_values` test, unresolved `<estimate_col>` placeholders) that would
produce incomplete test suites rather than wrong behavior. Address all BLOCKING and REQUIRED
issues in Stage 3 before moving to the implementation plan.

---

## Resolution Summary (Stage 3 — 2026-03-02)

All 16 issues resolved. Spec updated at `plans/spec-group-na-rows.md`. Decisions logged at `plans/decisions-group-na-rows.md`.

| Issue | Severity | Option chosen | Notes |
|---|---|---|---|
| 1 | BLOCKING | A | `rev()` removed from `.build_group_combos()` |
| 2 | REQUIRED | B | "stable within each group" comment dropped |
| 3 | REQUIRED | A | Audit confirmed: all 6 functions have identical inline loop |
| 4 | REQUIRED | A | Call-site example added to §II |
| 5 | BLOCKING | A | Domain-first sentence added to §III |
| 6 | REQUIRED | A | Test Block 6 wrapped in `expect_warning()` |
| 7 | SUGGESTION | A | `(NA, NA, ...)` sentence added to §III |
| 8 | SUGGESTION | A* | `get_freqs()`-specific `@param na.rm` text added (*user overrode recommendation of B) |
| 9 | REQUIRED | A | Per-function column names added to Test Block 4 and oracle block; reference table added |
| 10 | REQUIRED | C | Oracle test required for all 5 design classes |
| 11 | REQUIRED | Extended A* | Two test blocks added (7a, 7b); §III extended with haven-labeled NA contract (*user-directed scope extension beyond original option A) |
| 12 | REQUIRED | A | `make_na_group_design()` and `make_all_na_group_design()` specified in §VI |
| 13 | REQUIRED | A | Test Block 8 added for `group_by()` integration path |
| 14 | REQUIRED | A | `survey_nonprob` added as 5th column to §I support matrix |
| 15 | SUGGESTION | A | Test Block 6 wired to `make_all_na_group_design()` |
| 16 | SUGGESTION | A | Wrong `code-style.md §4` citation corrected |

---

## Spec Review: group-na-rows — Pass 2 (2026-03-02)

### Context

Full re-review of the spec and implementation plan after Stage 3 resolution.
Covers Architecture, Code Quality, Tests, and Edge Cases sections.
All 16 issues resolved in the same session (see decisions log entry
"Pass 2 Review: Architecture, Code Quality, Tests, Edge Cases").

### New Issues

---

#### Section: II — Architecture / `.build_group_combos()`

**Issue 5 (Code Quality): `rownames(combos) <- NULL` placed before subsetting**
Severity: REQUIRED
Violates: correctness — returns data.frame with non-sequential rownames

`rownames(combos) <- NULL` was set before `combos[ord, , drop = FALSE]`. R's `[`
operator with integer indices creates new rownames from the original row positions,
so the returned object has non-sequential rownames (e.g., "3", "1", "2") rather
than "1", "2", "3". The fix: assign the sorted result to `combos` first, then
reset rownames.

Resolution: Fixed — `combos <- combos[ord, , drop = FALSE]` then
`rownames(combos) <- NULL` then `combos`.

---

**Issue 7 (Code Quality): `do.call(order, sort_args)` name collision with `order()` formals**
Severity: SUGGESTION
Violates: engineering-preferences.md §4 (handle edge cases)

`lapply(names(combos), ...)` creates a named list. If a group variable is named
`decreasing`, `method`, or `na.last` (all formal parameters of `order()`),
`do.call(order, sort_args)` silently misroutes that vector to the named parameter
rather than `...`, causing a cryptic runtime error.

Resolution: Fixed — changed to `unname(lapply(...))` + `c(sort_vecs, list(na.last = TRUE))`.

---

#### Section: III — Behavioral Contract

**Issue 14 (Edge Case): Zero-eligible combo behavior unspecified**
Severity: REQUIRED
Violates: spec-coverage; engineering-preferences.md §4 (handle edge cases)

When `active_mask` selects zero rows for a group combo (e.g., domain estimation
excludes all NA-group rows), the output behavior was unspecified. The combo could
silently produce `NaN`, `Inf`, or an error in the variance engine.

Resolution: Added sentence: "More generally, if `active_mask` selects zero rows
for any group combo (NA or non-NA), that combo is silently dropped from the output."
Also clarified that domain estimation is via `surveytidy::filter()`, not a
`domain =` argument.

---

#### Section: VI — Testing

**Issue 9 (Tests): Oracle tests only verify point estimate, not SE**
Severity: REQUIRED
Violates: testing-standards.md §2 (98%+ coverage of observable behavior)

All oracle `expect_equal` blocks compared only the estimate column. SE uses a
separate variance engine code path; a bug producing correct estimates but wrong
SEs would be entirely invisible.

Resolution: Added `expect_equal(na_row$se, expected$se, tolerance = 1e-8)` to
all oracle blocks (single-group and multi-group).

---

**Issue 10 (Tests): Multi-group oracle missing for 4 of 5 design classes**
Severity: REQUIRED
Violates: spec §VI numerical accuracy requirement; per-class variance testing

Multi-group oracle was not specified at all (no oracle for the two-column NA
path). `.match_group_combo()` for multi-column NA inputs was unvalidated.

Resolution: Added multi-group oracle section for all 5 design classes per
function (30 additional oracle blocks total).

---

**Issue 11 (Tests): Test Block 6 (all-NA group) never verifies estimate value**
Severity: REQUIRED
Violates: testing-standards.md §3 (edge case data correctness)

Test Block 6 only verified `nrow == 1L` and `is.na(result$grp[[1L]])`. A bug
producing `NA_real_` or `NaN` in the estimate would pass all assertions.

Resolution: Added `is.finite(result$<estimate_col>[[1L]])` + ungrouped oracle
comparison to Block 6.

---

**Issue 12 (Tests): Test Block 8 (`group_by()` path) missing `na.rm = TRUE` regression guard**
Severity: REQUIRED
Violates: testing-standards.md §2 (one behavior per block; all behaviors tested)

Test Block 8 only verified `na.rm = FALSE` for the `group_by()` path. The default
`na.rm = TRUE` behavior through `.resolve_groups()` was untested.

Resolution: Added Test Block 8b.

---

**Issue 13 (Edge Cases): Domain estimation + NA group interaction has no test**
Severity: REQUIRED
Violates: spec §III (domain estimation contract); engineering-preferences.md §4

The `active_mask <- domain_mask & group_match` interaction was entirely unexercised.
Clarification needed: domain estimation uses `surveytidy::filter()` not a `domain =`
argument (confirmed from `analysis-means.R:119`).

Resolution: Added Test Block 9 using `surveytidy::filter()` to set domain.

---

**Issue 15 (Edge Cases): `get_freqs()` focal-NA × group-NA combination untested**
Severity: REQUIRED
Violates: spec §III (the cross-product of both NA behaviors); testing coverage

When both the focal variable and group variable have NAs under `na.rm = FALSE`,
the output should contain focal-variable NA rows within the NA-group row. This
unique `get_freqs()` path was never exercised.

Resolution: Added Test Block 10 (`get_freqs()` only).

---

#### Section: VI — Shared Test Infrastructure

**Issue 8 (Code Quality): `na_row` extraction pattern repeated ~48 times without shared helper**
Severity: SUGGESTION
Violates: engineering-preferences.md §1 (DRY)

`result[is.na(result$grp), ]` appears inline in Test Blocks 3, 4, 6, oracle
tests — approximately 48 occurrences across 6 test files.

Resolution: Added `get_na_group_rows(result, group_col)` helper to
`helper-test-data.R`; substituted throughout test block templates.

---

#### Section: VII — Quality Gates

**Issue 3 (Architecture): Warning condition widening (`== 1L` → `< 2L`) not gated**
Severity: SUGGESTION
Violates: quality gate completeness

The `< 2L` widening was specified per-PR but had no final gate. A reviewer could
mark acceptance criteria green without actually widening all 6 functions.

Resolution: Added grep gate to §VII: "`grep 'uniq_lvls == 1L' R/analysis-*.R` returns 0".

---

### Resolution Summary

| Issue | Section | Severity | Resolution |
|---|---|---|---|
| 5 | §II code block | REQUIRED | Fix `rownames` ordering: assign then reset |
| 7 | §II code block | SUGGESTION | `unname()` + positional `c()` for `order()` |
| 8 | §VI helpers | SUGGESTION | `get_na_group_rows()` helper added |
| 9 | §VI oracle | REQUIRED | SE comparison added to all oracle blocks |
| 10 | §VI oracle | REQUIRED | Multi-group oracle added for all 5 classes |
| 11 | §VI Block 6 | REQUIRED | `is.finite()` + ungrouped oracle |
| 12 | §VI | REQUIRED | Test Block 8b added |
| 13 | §VI | REQUIRED | Test Block 9 (domain via `filter()`) added |
| 14 | §III | REQUIRED | Zero-eligible combo behavior specified |
| 15 | §VI | REQUIRED | Test Block 10 (`get_freqs()` focal×group NA) |
| 3 | §VII | SUGGESTION | `< 2L` grep gate added |

**Overall assessment:** Pass 1 issues were all blocking or required and correctly
resolved. Pass 2 found 11 additional issues (1 code correctness bug, 7 test
coverage gaps, 2 behavioral spec gaps, 1 DRY violation). All resolved in-session.
The spec and plan are now ready for implementation.

---

## Spec Review: group-na-rows — Pass 3 (2026-03-02)

### Context

After the structured 4-section × 4-issue review in Pass 2, 6 additional issues
were raised that the cap had prevented. All 6 resolved in the same session.

### New Issues

---

**Issue 17: Twophase oracle construction underspecified in §VI**
Severity: REQUIRED
Violates: spec-coverage; engineering-preferences.md §4 (handle edge cases)

The §VI "Numerical accuracy" section said "Repeat for design_twophase" without
showing the two-step construction. `as_survey_twophase()` requires a `phase1`
design first — unlike all other classes which accept a data frame directly.
An implementer following "pre-filter the data frame then construct the oracle
design" for twophase would write code that fails at runtime.

Resolution: Added explicit two-step twophase oracle construction block to
§VI, showing both the full design and oracle design constructions.

---

**Issue 18: `na.rm = NA` unspecified — passes silently into subsetting logic**
Severity: REQUIRED
Violates: error contract; engineering-preferences.md §4 (handle edge cases)

`na.rm = NA` is not `TRUE` or `FALSE`. `isTRUE(NA)` returns `FALSE`, so
`.validate_shared_args()` would accept it without error. `NA` would then
propagate into `stats::complete.cases()` or `domain_data[NA, ]`, producing
wrong output or a cryptic error deep in the variance engine.

Resolution: Added `surveycore_error_na_rm_not_logical` to §V with validation
code in `.validate_shared_args()`. Test Block 8c added.

---

**Issue 19: Reverse multi-group NA case untested**
Severity: REQUIRED
Violates: spec-coverage; engineering-preferences.md §2 (more tests is better)

Block 5 only tested NA in the first group variable (`grp`). The
`for (gv in names(combo_row))` iteration in `.match_group_combo()` has
different branching when the NA is in the second column rather than the first.
A name-ordering bug in the multi-group matching path would be invisible.

Resolution: Block 5 split into 5a (NA in `grp`) and 5b (NA in `grp2`) with
an inline fixture for 5b.

---

**Issue 20: Spec and impl plan duplicate all code blocks without sync annotation**
Severity: SUGGESTION
Violates: engineering-preferences.md §1 (DRY — flag repetition aggressively)

Both documents contain identical code for `.build_group_combos()`,
`.match_group_combo()`, `make_na_group_design()`, and the validation snippet.
Future maintainers face silent divergence if only one document is updated.

Resolution: Spec updated as authoritative source (spec `make_na_group_design()`
now has `set.seed(seed + 1L)` for consistency). Impl plan blocks annotated with
"Sync note: spec §II/§V/§VI is authoritative."

---

**Issue 21: Test Blocks 7a/7b call sites shown only for `get_freqs()`**
Severity: REQUIRED
Violates: spec-coverage (Blocks 7a/7b required for all 6 functions)

The spec's Block 7a/7b templates used generic `get_X()` notation. For PRs 3–5,
the impl plan said "same fixture construction as PR 2" without showing call
sites. `get_corr()` takes `c(y1, y2)` as its `x` argument; `get_quantiles()`
requires a `probs` argument; `get_ratios()` takes separate `y1`, `y2` arguments.
Implementers copying from PR 2 would get wrong call signatures.

Resolution: Explicit call sites added to PR 3, PR 4, and PR 5 implementation
notes in the impl plan.

---

**Issue 22: `n` column on NA group rows never verified in oracle tests**
Severity: REQUIRED
Violates: spec-coverage; testing-standards.md §2 (observable behavior must
be tested)

The `n` column (unweighted row count) is computed by a separate path from the
point estimate and SE. A bug producing correct estimates but a wrong `n`
(e.g., returning the total design row count instead of the NA-group-only count)
would be invisible.

Resolution: Added `expect_equal(na_row$n, expected$n)` to all oracle blocks in
spec §VI (single-group and multi-group), and to PR 2, PR 4, PR 5 oracle code
examples in the impl plan.

---

### Resolution Summary

| Issue | Section | Severity | Resolution |
|---|---|---|---|
| 17 | §VI oracle | REQUIRED | Twophase two-step oracle construction added |
| 18 | §V errors | REQUIRED | `na.rm = NA` error class + Block 8c added |
| 19 | §VI Block 5 | REQUIRED | Block 5 split into 5a/5b |
| 20 | §VI fixtures | SUGGESTION | `set.seed(seed + 1L)` added to spec fixture; impl plan blocks annotated |
| 21 | §VI test blocks | REQUIRED | Call sites added to impl plan PR 3–5 notes |
| 22 | §VI oracle | REQUIRED | `n` column added to all oracle blocks |

**Overall assessment:** Pass 3 found 5 required issues and 1 suggestion that
were missed due to the structured review's section cap. The most critical were
the twophase oracle construction (would cause silent runtime failures) and
`na.rm = NA` (passes silently into wrong code path). All resolved. The spec
and plan are now ready for implementation.
