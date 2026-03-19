# Spec Review: get-diffs

## Pass 1 (2026-03-16)

### New Issues

#### Section: I. Scope

No new issues found.

---

#### Section: II. Architecture

**Issue 1: Test file naming convention inconsistent with Phase 1**
Severity: SUGGESTION
Violates Phase 1 naming convention in `testing-surveycore.md`

The spec defines test files as:
```
test-diffs.R
test-diffs-numerical.R
test-diffs-marginaleffects.R
```

Phase 1 analysis test files follow the `test-analysis-{function}.R` convention (e.g.,
`test-analysis-means.R`, `test-analysis-freqs.R`). This inconsistency could confuse
contributors navigating the test directory.

Options:
- **[A]** Rename to `test-analysis-diffs.R`, `test-analysis-diffs-numerical.R`,
  `test-analysis-diffs-marginaleffects.R` — Effort: low, Risk: low, Impact: consistency,
  Maintenance: none
- **[C] Do nothing** — Files work regardless of naming.

**Recommendation: [A]** — Consistency costs nothing and helps discoverability.

---

**Issue 2: `.build_diffs_meta()` should delegate to `.build_meta()` for common fields**
Severity: REQUIRED
Violates `engineering-preferences.md` §1 (DRY)

Section 2.2 defines `.build_diffs_meta()` as constructing the full `.meta` list. But
`.build_meta()` in `analysis-helpers.R` already derives `design_type` and `n_respondents`
from the design object and merges with function-specific `meta_args`. The spec does not
reference `.build_meta()` or explain why a separate helper is needed.

If `.build_diffs_meta()` duplicates the design-type derivation logic
(`S7::S7_inherits(design, survey_taylor)` → `"taylor"`, etc.), any future change to
design type mapping must be updated in two places.

Options:
- **[A]** Specify that `.build_diffs_meta()` calls `.build_meta(design, meta_args)`
  internally, passing diffs-specific fields via `meta_args`. The helper's role is
  assembling the `meta_args` list, not deriving `design_type`. — Effort: low, Risk: low,
  Impact: DRY, Maintenance: none
- **[B]** Remove `.build_diffs_meta()` entirely; build `meta_args` inline in
  `get_diffs()` and pass to `.build_meta()` directly (matching the Phase 1 pattern in
  `get_means()`). — Effort: low, Risk: low, Impact: simpler, Maintenance: none
- **[C] Do nothing** — Duplicate logic.

**Recommendation: [B]** — Phase 1 functions build `meta_args` inline and pass to
`.build_meta()`. A separate helper is unnecessary abstraction for a single call site.

---

**Issue 3: `DIFFS_META_KEYS` constant not defined**
Severity: REQUIRED
Violates Phase 1 pattern in `analysis-helpers.R`

Phase 1 defines `*_META_KEYS` constants for each `get_*()` function (e.g.,
`MEANS_META_KEYS`, `FREQS_META_KEYS`). These are the single source of truth for each
function's meta contract and are passed to `.make_result_tibble()` for validation. The
spec does not define a `DIFFS_META_KEYS` constant or discuss how it integrates with
`.make_result_tibble()`.

The `get_diffs()` `.meta` contract (Section IV) has keys: `group`, `x`, `treats`,
`covariates`, `family`, `link`, `pval_adj`, `estimate_method`, `mean_method`,
`estimate_scale`. The constant should include all function-specific keys.

Options:
- **[A]** Add to Section 2.2 or IV: define `DIFFS_META_KEYS` as
  `c("group", "x", "treats", "covariates", "family", "link", "pval_adj",
  "estimate_method", "mean_method", "estimate_scale")` in `analysis-helpers.R`. —
  Effort: low, Risk: low, Impact: consistency with Phase 1 pattern, Maintenance: none
- **[C] Do nothing** — Miss the validation.

**Recommendation: [A]** — Follow the established pattern.

---

#### Section: III. Function Specification

**Issue 4: Error class names diverge from existing codebase conventions**
Severity: REQUIRED
Violates `engineering-preferences.md` §1 (DRY) and `error-messages.md` as single source
of truth

The spec introduces error classes that duplicate the function of existing classes:

| Spec error class | Existing codebase class | Used in |
|---|---|---|
| `surveycore_error_not_survey_object` | `surveycore_error_unsupported_class` | `.check_unsupported_class()` (row 64) |
| `surveycore_error_x_not_numeric` | `surveycore_error_non_numeric_variable` | `get_means()`, `get_totals()` etc. (row 43) |
| `surveycore_error_x_single` | `surveycore_error_wrong_variable_count` | `get_means()` validation |

Creating different class names for identical checks means:
1. Users catching errors by class must know two names for the same condition
2. Tests are harder to grep/audit
3. `plans/error-messages.md` grows with synonyms

Options:
- **[A]** Reuse existing class names. Replace `surveycore_error_not_survey_object` with
  `surveycore_error_unsupported_class` (and reuse `.check_unsupported_class()`). Replace
  `surveycore_error_x_not_numeric` with `surveycore_error_non_numeric_variable`. Replace
  `surveycore_error_x_single` with `surveycore_error_wrong_variable_count`. Keep
  `surveycore_error_treats_single` as new (no existing equivalent). — Effort: low,
  Risk: low, Impact: consistency, Maintenance: none
- **[C] Do nothing** — New synonyms accumulate.

**Recommendation: [A]** — Reuse the existing classes. Only add genuinely new classes to
`error-messages.md`.

---

**Issue 5: Missing `name_style` argument breaks API uniformity with Phase 1**
Severity: REQUIRED
Violates `engineering-preferences.md` §5 (explicit over clever) and API coherence lens

Every Phase 1 `get_*()` function accepts `name_style = "surveycore"` (default) or
`"broom"`. The `get_diffs()` spec omits this argument entirely. Users who build pipelines
like `get_means(d, x, name_style = "broom") |> bind_rows(get_diffs(d, x, treats))` would
find inconsistent column naming.

The `get_diffs()` output has columns that map directly to broom conventions: `estimate`
(already broom-named), `se` → `std.error`, `ci_low` → `conf.low`, `ci_high` →
`conf.high`, `p_value` → `p.value`. The existing `.apply_name_style()` handles this
mapping.

Options:
- **[A]** Add `name_style = "surveycore"` to the signature (between `na.rm` and `...`).
  Apply `.apply_name_style()` as the last step before return. Also enables reuse of
  `.validate_shared_args()` for `conf_level`, `decimals`, `na.rm`, and `name_style`
  validation. — Effort: low, Risk: low, Impact: API consistency, Maintenance: none
- **[C] Do nothing** — API inconsistency.

**Recommendation: [A]** — Add the argument and reuse the shared validator.

---

**Issue 6: `na.rm` validation not specified**
Severity: REQUIRED
Violates Phase 1 validation contract

Section 3.12 translates `na.rm` to `na.action` for `survey_glm()`, but does not specify
validation when `na.rm` is not `TRUE` or `FALSE` (e.g., `na.rm = NA`, `na.rm = "yes"`,
`na.rm = 42`). In Phase 1, `.validate_shared_args()` validates `na.rm` with
`surveycore_error_na_rm_not_logical` (error-messages.md row 81).

If `get_diffs()` passes an invalid `na.rm` value to `survey_glm()` without validation,
the `na.action` translation (`ifelse(na.rm, na.omit, na.fail)`) produces unexpected
results.

Options:
- **[A]** Add `na.rm` to the validation step. If `name_style` is added (Issue 5), reuse
  `.validate_shared_args()` which already validates `na.rm`. Otherwise, add inline
  validation with `surveycore_error_na_rm_not_logical`. — Effort: low, Risk: low,
  Impact: defensive, Maintenance: none
- **[C] Do nothing** — Invalid `na.rm` produces cryptic downstream errors.

**Recommendation: [A]** — Validate before use.

---

**Issue 7: `res_df` should use `fit@degf` instead of `.degf(design)`**
Severity: REQUIRED
Violates correctness

Section 3.8.1 computes residual df as:
```r
res_df <- degf(design) - (length(coef(fit)) - 1L)
```

Two problems:

1. **Function name:** The internal function is `.degf(design)` (dot-prefixed), but the
   spec writes `degf(design)` (no dot). The implementer must know to call `.degf()`.

2. **Source of truth:** The fitted `survey_glm_fit` object already stores `@degf` (raw
   design df, computed at fit time, clamped ≥ 1). Using `.degf(design)` recomputes from
   the design object, which may differ from `fit@degf` in edge cases (e.g., when
   `na.action` drops rows that eliminate entire PSUs or strata).

3. **Missing clamping:** The spec's formula doesn't clamp the result. If
   `.degf(design) - (p - 1) ≤ 0`, `qt()` receives a non-positive df and returns `NaN`.
   The `survey_glm()` constructor already warns when df ≤ 0 (row 77) and clamps
   `@df_residual` to 1. But `@df_residual` is classical (n - p), not design-based.

Options:
- **[A]** Replace `degf(design) - (length(coef(fit)) - 1L)` with
  `max(1, fit@degf - (length(coef(fit)) - 1L))`. Use `fit@degf` as the authoritative
  source and add the same clamping that `survey_glm()` uses. — Effort: low, Risk: low,
  Impact: correctness, Maintenance: none
- **[B]** Create a helper `.residual_df(fit)` that returns
  `max(1, fit@degf - (length(fit@coefficients) - 1L))` to avoid repeating the formula.
  — Effort: low, Risk: low, Impact: DRY, Maintenance: none
- **[C] Do nothing** — Potential NaN from qt() in edge cases.

**Recommendation: [A]** — Use `fit@degf` and add clamping.

---

**Issue 8: `scale = "link"` with non-gaussian family via clean path — `mean` column semantics unclear**
Severity: REQUIRED
Violates API coherence lens (Lens 6)

Section 7.2 routing logic:
```r
use_marginaleffects <- has_covariates ||
  has_group ||
  (family_name != "gaussian" && scale == "ame")
```

When `scale = "link"` + non-gaussian family + no covariates + no group, the clean path
is used. The clean path computes `mean = reference_mean + estimate` where
`reference_mean` is the intercept and `estimate` is the coefficient — both on the link
scale.

For logistic regression, this means:
- `mean` = log-odds (not probability)
- `pct_change = estimate / reference_mean` = change in log-odds / baseline log-odds

A user seeing `mean = -0.847` would not understand this is log-odds without explicit
documentation. The column label says `"Mean"` (Section 5.5), which implies the response
scale.

Options:
- **[A]** Document in the `mean` column description (Section 5.2): "When `scale =
  'link'`, `mean` is on the link scale (e.g., log-odds for logistic)." Also update the
  column label to `"Mean (link scale)"` when `scale = "link"` and family is
  non-gaussian. Suppress `pct_change` (or make it NA) when `scale = "link"` because the
  ratio of link-scale values is not meaningful. — Effort: low, Risk: low, Impact:
  prevents misinterpretation, Maintenance: none
- **[B]** Force the marginaleffects path for all non-gaussian models regardless of
  `scale`, then extract coefficients from `clean()` only when the user explicitly wants
  `scale = "link"`. — Effort: medium, Risk: low, Impact: cleaner, Maintenance: none
- **[C] Do nothing** — Users misinterpret link-scale means.

**Recommendation: [A]** — Document and adjust labels. The clean path is correct for
link-scale coefficients; the issue is labeling.

---

**Issue 9: `pct_change` rounding incompatible with `.apply_decimals()`**
Severity: SUGGESTION
Deviates from Phase 1 shared helper

Section 3.11 specifies `pct_change` rounds to `decimals + 2`, while all other numeric
columns round to `decimals`. The existing `.apply_decimals()` rounds all double columns
to the same number of decimals.

Options:
- **[A]** Round `pct_change` separately before calling `.apply_decimals()`, or round
  all columns manually without `.apply_decimals()`. Document the deviation. — Effort:
  low, Risk: low, Impact: correct rounding, Maintenance: none
- **[B]** Round `pct_change` to `decimals` like everything else (simpler, still uses
  `.apply_decimals()`). — Effort: low, Risk: low, Impact: API simplicity, Maintenance:
  none
- **[C] Do nothing** — Implementer figures it out.

**Recommendation: [A]** — The spec's differential rounding is intentional; document the
implementation approach.

---

#### Section: IV. `.meta` Contract

No new issues beyond Issue 3 (DIFFS_META_KEYS).

---

#### Section: V. Output Contract

**Issue 10: Missing `label_values`/`label_vars`/`min_cell_n`/`n_weighted` arguments**
Severity: SUGGESTION
API coherence (Lens 6)

Phase 1 `get_*()` functions all accept:
- `label_values` — accepted for API uniformity (no-op in `get_means()`)
- `label_vars` — accepted for API uniformity
- `min_cell_n = 30L` — configurable small-cell threshold
- `n_weighted` — optional weighted count column

`get_diffs()` omits all four. The `min_cell_n` is hardcoded to 30 in
`surveycore_warning_small_cell` (Section 6.2). A user who customizes `min_cell_n` in
`get_means()` would expect the same control in `get_diffs()`.

Options:
- **[A]** Add `min_cell_n = 30L` and keep `label_values`/`label_vars`/`n_weighted`
  omitted (they don't map to `get_diffs()` semantics). — Effort: low, Risk: low,
  Impact: partial consistency, Maintenance: none
- **[B]** Add all four for full API uniformity. `label_values` and `label_vars` are
  no-ops; `n_weighted` adds a weighted count column. — Effort: medium, Risk: low,
  Impact: full consistency, Maintenance: low
- **[C] Do nothing** — Acceptable deviation.

**Recommendation: [A]** — `min_cell_n` is the most impactful. The others are less
critical for treatment effect tables.

---

#### Section: VI. Error & Warning Conditions

Covered by Issue 4 (error class naming) and Issue 6 (`na.rm` validation).

---

#### Section: VII. Execution Flow

No new issues.

---

#### Section: VIII. Print Method

**Issue 11: Print method test not specified in test plan**
Severity: REQUIRED
Violates `testing-standards.md` Test Completeness category 13 (print snapshot)

Section VIII defines a custom `print.survey_diffs()` method with 4 header lines and
exact console output. Section IX does not include a print snapshot test.

Phase 1 result classes use the shared `print.survey_result()` method and have snapshot
tests verifying the header format.

Options:
- **[A]** Add to Section 9.1 (Happy Path Tests): a snapshot test verifying the full
  print output matches the Section VIII example, including all 4 header lines. —
  Effort: low, Risk: low, Impact: catches regressions, Maintenance: one snapshot
- **[C] Do nothing** — Print format untested.

**Recommendation: [A]** — Snapshot tests are the standard for print methods.

---

#### Section: IX. Testing Requirements

**Issue 12: Domain estimation test missing from test plan**
Severity: REQUIRED
Violates Test Completeness category 4 (domain estimation)

Section 9.1 has no test for:
```r
d |> filter(condition) |> get_diffs(x, treats)
```

Domain estimation changes the effective sample and affects `n` counts (Issue 16 from
methodology review, resolved as "in-domain counts only"). Without a test, the domain
count logic is unverified.

Options:
- **[A]** Add to Section 9.1 (Happy Path Tests): "Domain estimation — `filter(design,
  condition) |> get_diffs(...)` produces in-domain `n` counts and correct estimates."
  — Effort: low, Risk: low, Impact: covers a critical path, Maintenance: one test
- **[C] Do nothing** — Domain logic untested at the `get_diffs()` level.

**Recommendation: [A]** — Domain estimation is a first-class feature of surveycore.

---

**Issue 13: `clean()` output filtering not specified precisely**
Severity: REQUIRED
Missing implementation detail in Section 3.7

Section 3.7 Step 3 says: "Extract reference row (intercept): the row where
`term == '(Intercept)'`." Step 4 says: "Extract treatment rows: all non-intercept,
non-reference rows."

With `clean(fit, include_reference = TRUE)`, the output contains:
1. `(Intercept)` row (term = "(Intercept)", reference_row = FALSE)
2. Reference level row (e.g., term = "treatsControl", reference_row = TRUE, estimate = NA)
3. Treatment rows (reference_row = FALSE, term != "(Intercept)")

The spec must explicitly filter out the `reference_row == TRUE` row from clean() output
(it has `estimate = NA` and is not used). The phrase "non-reference rows" is ambiguous —
it could mean "not the reference level" or "reference_row == FALSE".

Options:
- **[A]** Replace Step 4 with: "Extract treatment rows: all rows where
  `reference_row == FALSE` and `term != '(Intercept)'`." — Effort: low, Risk: low,
  Impact: unambiguous, Maintenance: none
- **[C] Do nothing** — Implementer infers from clean() contract.

**Recommendation: [A]** — Precision prevents implementation bugs.

---

**Issue 14: `scale = "ame"` vs `"link"` identity for Gaussian not tested**
Severity: SUGGESTION
Missing edge case coverage

For Gaussian/identity models, `scale = "ame"` and `scale = "link"` should produce
identical output (both are on the response scale). The routing logic (Section 7.2)
correctly sends both to the clean path when no covariates/groups are present. But when
covariates ARE present, `scale = "ame"` goes through marginaleffects while
`scale = "link"` would use... the clean path with covariates? No — Section 7.2 shows
`has_covariates` forces marginaleffects regardless of scale.

Actually, for Gaussian + covariates: both scales go through marginaleffects. The AME of
a linear model = the coefficient. So results should be identical.

A test verifying `scale = "ame"` == `scale = "link"` for Gaussian family would
guard the routing logic against regressions.

Options:
- **[A]** Add edge case test: Gaussian model with both `scale = "ame"` and
  `scale = "link"` produces identical estimates. — Effort: low, Risk: low, Impact:
  guards routing, Maintenance: one test
- **[C] Do nothing** — Implicit in other tests.

**Recommendation: [A]** — Explicit is better.

---

#### Section: Cross-Cutting (Lens 2 — Test Completeness Matrix)

For completeness, here is the 13-category assessment:

| # | Category | Status | Notes |
|---|---|---|---|
| 1 | Happy path | ✅ Covered | Section 9.1 has extensive happy path list |
| 2 | Numerical oracle | ✅ Covered | Added in methodology review; tolerances specified |
| 3 | Grouped analysis | ✅ Covered | `DV ~ treats * group` with taylor design |
| 4 | Domain estimation | ❌ **Missing** | See Issue 12 |
| 5 | Variance argument | ✅ Covered | `"se"`, `c("se", "ci")`, `NULL` tested |
| 6 | label_values | N/A | `get_diffs()` uses column-level labels instead |
| 7 | label_vars | N/A | Same as above |
| 8 | meta() contract | ✅ Covered | Section 9.2 requires meta verification |
| 9 | name_style = "broom" | ❌ **Missing** | See Issue 5 — argument not in spec |
| 10 | Error paths | ✅ Covered | Dual pattern specified |
| 11 | Edge cases | ✅ Covered | Section 9.1 has 8 edge cases |
| 12 | Multi-variable | N/A | Single DV by design |
| 13 | Print snapshot | ❌ **Missing** | See Issue 11 |

Mechanical rules:
- `test_invariants()` — N/A (analysis function, not constructor). ✓
- Dual pattern (class= + snapshot) for Layer 3 errors — specified. ✓
- `class=` on every error and warning — all present in Sections 6.1 and 6.2. ✓

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 9 |
| SUGGESTION | 5 |

**Total issues:** 14

| # | Title | Lens | Severity |
|---|---|---|---|
| 1 | Test file naming convention | 2 | SUGGESTION |
| 2 | `.build_diffs_meta()` should delegate to `.build_meta()` | 1 | REQUIRED |
| 3 | `DIFFS_META_KEYS` constant not defined | 3 | REQUIRED |
| 4 | Error class names diverge from existing codebase | 1 | REQUIRED |
| 5 | Missing `name_style` argument | 6 | REQUIRED |
| 6 | `na.rm` validation not specified | 3 | REQUIRED |
| 7 | `res_df` should use `fit@degf` | 3 | REQUIRED |
| 8 | `scale = "link"` mean column semantics | 6 | REQUIRED |
| 9 | `pct_change` rounding incompatible with `.apply_decimals()` | 5 | SUGGESTION |
| 10 | Missing `min_cell_n`/`label_values` etc. arguments | 6 | SUGGESTION |
| 11 | Print method test not specified | 2 | REQUIRED |
| 12 | Domain estimation test missing | 2 | REQUIRED |
| 13 | `clean()` output filtering not precise | 3 | REQUIRED |
| 14 | `scale = "ame"` = `"link"` for Gaussian test | 4 | SUGGESTION |

**Overall assessment:** The spec is well-structured and methodology-locked with all 24
methodology review issues resolved. No blocking issues remain. The 9 required issues are:
DRY violations in error class naming and meta construction (easily fixed by reusing
existing infrastructure), missing API consistency with Phase 1 (`name_style`, validation),
a correctness issue with df computation (use `fit@degf` instead of recomputing), and
gaps in the test plan (domain estimation, print snapshot). All are addressable without
architectural changes. The spec is near-implementable after this pass.

---

## Pass 2 (2026-03-17)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | Test file naming convention | ✅ Resolved — Section 2.1 now uses `test-analysis-diffs.R` naming |
| 2 | `.build_diffs_meta()` should delegate to `.build_meta()` | ✅ Resolved — Section 2.2 specifies inline `meta_args` + `.build_meta()` (no separate helper) |
| 3 | `DIFFS_META_KEYS` constant not defined | ✅ Resolved — Section 2.2 defines `DIFFS_META_KEYS` with all 10 keys |
| 4 | Error class names diverge from codebase | ✅ Resolved — Section 6.1 reuses `surveycore_error_unsupported_class`, `surveycore_error_non_numeric_variable`, `surveycore_error_wrong_variable_count` |
| 5 | Missing `name_style` argument | ✅ Resolved — Added to signature (Section 3.1) with `.apply_name_style()` in execution flow |
| 6 | `na.rm` validation not specified | ✅ Resolved — Section 3.12 specifies `.validate_shared_args()` as first step |
| 7 | `res_df` should use `fit@degf` | ✅ Resolved — Section 3.8.1 now uses `max(1, fit@degf - (length(coef(fit)) - 1L))` |
| 8 | `scale = "link"` mean column semantics | ✅ Resolved — Decided option [D]: suppress `mean` and `pct_change` when link + non-gaussian |
| 9 | `pct_change` rounding incompatible with `.apply_decimals()` | ✅ Resolved — Section 3.11 documents separate rounding after `.apply_decimals()` |
| 10 | Missing `min_cell_n`/`label_values` etc. arguments | ✅ Resolved — All four added to signature |
| 11 | Print method test not specified | ✅ Resolved — Print snapshot test added to Section 9.1 |
| 12 | Domain estimation test missing | ✅ Resolved — Domain estimation test added to Section 9.1 |
| 13 | `clean()` output filtering not precise | ✅ Resolved — Section 3.7 Step 4 now says `reference_row == FALSE` and `term != "(Intercept)"` |
| 14 | `scale = "ame"` = `"link"` for Gaussian test | ✅ Resolved — Edge case test added to Section 9.1 |

All 14 Pass 1 issues resolved.

### New Issues

#### Section: I. Scope

**Issue 15: `survey_srs` listed as supported but removed from codebase**
Severity: BLOCKING
Violates contract completeness — spec references a class that no longer exists

Section I lists `survey_srs` as a supported design class:
```
| survey_srs | Yes |
```

The `refactor/remove-survey-srs` branch removes the `survey_srs` class, `as_survey_srs()`,
and `R/variance-srs.R`. After this refactor, SRS designs are created via `as_survey()` with
no `ids` or `strata`, producing a `survey_taylor` object. The `survey_srs` class will not
exist at implementation time.

Additionally, Section IV lists `"srs"` as a valid `design_type` in `.meta`:
```
design_type: "taylor", "replicate", "twophase", "srs", or "calibrated"
```

`.build_meta()` in `analysis-helpers.R` has no branch for `survey_srs` — it checks
`survey_taylor`, `survey_replicate`, `survey_twophase`, `survey_nonprob` only. SRS designs
via `survey_taylor` would produce `design_type = "taylor"`.

The print method example (Section VIII) shows `Design: Taylor series`, which is already
correct for the post-removal world.

Options:
- **[A]** Remove `survey_srs` from Section I supported classes table. Remove `"srs"` from
  Section IV `design_type` values. Update any test descriptions that reference `survey_srs`
  specifically. SRS designs are tested via `survey_taylor` with no ids/strata. — Effort:
  low, Risk: low, Impact: spec matches codebase, Maintenance: none
- **[C] Do nothing** — Implementer cannot find `survey_srs` class.

**Recommendation: [A]** — Spec must match the codebase.

---

#### Section: II. Architecture

No new issues found.

---

#### Section: III. Function Specification

**Issue 16: `name_style = "broom"` creates duplicate `estimate` columns**
Severity: BLOCKING
Violates correctness — `.apply_name_style()` produces a malformed tibble

The `get_diffs()` output contains both `estimate` (treatment effect) and `mean`
(treatment level mean) columns simultaneously when `show_means = TRUE`. The existing
`.apply_name_style()` maps:
```r
broom_map <- c(
  mean     = "estimate",
  estimate = "estimate",
  ...
)
```

When both columns are present and `name_style = "broom"`, the function renames both to
`"estimate"`, creating a tibble with duplicate column names. This silently corrupts the
output.

The spec's Section 3.2 description correctly lists only 4 renames (`se → std.error`,
`ci_low → conf.low`, `ci_high → conf.high`, `p_value → p.value`) and does NOT mention
renaming `mean` or `estimate`. But the execution flow (Section 7.1 Step 19) calls
`.apply_name_style()`, which applies the full broom map including the conflicting
`mean → estimate` mapping.

In Phase 1, `get_means()` has `mean` but no `estimate`; `get_totals()` has `total` but
no `estimate`. The broom map works because only one "point estimate" column exists per
function. `get_diffs()` breaks this assumption by having both.

Options:
- **[A]** Exclude `mean` from broom renaming in `get_diffs()`. Before calling
  `.apply_name_style()`, temporarily remove `mean` from the result, apply the rename,
  then re-insert `mean`. Or: don't use `.apply_name_style()` — do the 4 renames manually
  in `get_diffs()`. — Effort: low, Risk: low, Impact: correctness, Maintenance: low
- **[B]** Rename the `mean` column to `fitted_mean` or `group_mean` in the surveycore
  output to avoid the broom namespace collision entirely. Then `.apply_name_style()` would
  skip it (no mapping for `fitted_mean`). — Effort: low, Risk: medium (API change),
  Impact: avoids the problem structurally, Maintenance: none
- **[C] Do nothing** — Duplicate columns in broom output.

**Recommendation: [A]** — Exclude `mean` from broom renaming. The `mean` column in
`get_diffs()` is contextual (not the point estimate), so it should keep its name in
broom mode. Document in Section 3.2: "The `mean` column is not renamed under
`name_style = 'broom'` because `estimate` already holds the point estimate."

---

**Issue 17: `treats` column labeling mechanism unspecified**
Severity: REQUIRED
Violates contract completeness (Lens 3) and `engineering-preferences.md` §5 (explicit)

Section 3.2 says `label_values = TRUE` displays value labels ("Control", "Message A")
instead of raw codes (1, 2) for `treats` and `group` columns. But the spec does not
specify:

1. **When labels are applied:** The `treats` column is built from factor levels after
   `as.factor()` + `relevel()` (Section 3.6). If the source column has haven-style
   numeric codes (1, 2, 3), `as.factor()` creates levels `"1"`, `"2"`, `"3"` — not
   label strings. Labels must be applied later.

2. **How labels are applied:** Phase 1 group columns use `.apply_group_labels()` from
   `analysis-helpers.R`. Should `get_diffs()` use the same helper for the `treats` column?
   This would require treating `treats` as a "group-like" column for labeling purposes.

3. **Output type:** Section 5.2 says the `treats` column type is `character`. But
   `.apply_group_labels()` returns `factor` for labeled columns (matching Phase 1 group
   column behavior). The output type should be consistent.

Options:
- **[A]** Specify: after assembling the output tibble, apply `.apply_group_labels()` to
  both `treats` and `group` columns (treating `treats` identically to group columns for
  labeling). Update Section 5.2 to say `treats` type is `factor` when labels are applied,
  `character` otherwise (matching group column behavior). — Effort: low, Risk: low,
  Impact: reuses existing infrastructure, Maintenance: none
- **[B]** Apply labels during factor construction in Section 3.6 (before GLM fit). Use
  metadata value labels to build factor levels with label strings instead of raw codes.
  — Effort: low, Risk: medium (factor level strings affect model term names in `clean()`
  output, requiring careful term parsing), Maintenance: ongoing
- **[C] Do nothing** — Implementer must reverse-engineer the labeling approach.

**Recommendation: [A]** — Reuse `.apply_group_labels()` post-assembly, matching the
Phase 1 pattern exactly. Applying labels before the GLM fit (option B) would change
model term names and complicate `clean()` parsing.

---

**Issue 18: `n_weighted` for reference row not specified**
Severity: REQUIRED
Violates contract completeness (Lens 3)

Section 5.4 (Reference Row Contract) specifies values for all columns in the reference
row: `estimate = 0`, `se = NA`, `p_value = NA`, etc. But it does not include
`n_weighted`. When `n_weighted = TRUE`, the reference row must have a value for this
column — logically the sum of weights for the reference level.

Options:
- **[A]** Add `n_weighted` to Section 5.4: `n_weighted = sum of weights for the
  reference level (within group if applicable)`. — Effort: low, Risk: low, Impact:
  complete contract, Maintenance: none
- **[C] Do nothing** — Implementer guesses.

**Recommendation: [A]** — Complete the reference row contract.

---

#### Section: IV. `.meta` Contract

Covered by Issue 15 (`"srs"` in `design_type`).

---

#### Section: V. Output Contract

No new issues beyond Issues 16–18.

---

#### Section: VI. Error & Warning Conditions

No new issues found.

---

#### Section: VII. Execution Flow

No new issues found.

---

#### Section: VIII. Print Method

No new issues found.

---

#### Section: IX. Testing Requirements

**Issue 19: `label_vars` test missing from test plan**
Severity: REQUIRED
Violates Test Completeness category 7 (label_vars)

Section 9.1 includes tests for `label_values = TRUE` and `label_values = FALSE` but
has no explicit test for `label_vars`. The `label_vars` argument controls whether
column-level `label` attributes on `treats` and `group` columns use variable labels
from metadata vs raw variable names.

Pass 1 Test Completeness Matrix (row 7) marked `label_vars` as N/A with "uses
column-level labels instead." But the v1.2 spec adds `label_vars` as an argument with
real behavior — it's no longer N/A.

Options:
- **[A]** Add to Section 9.1: "`label_vars = FALSE` — column-level `label` attributes
  on `treats` and `group` columns use raw variable names instead of metadata labels." —
  Effort: low, Risk: low, Impact: test coverage, Maintenance: one test
- **[C] Do nothing** — `label_vars` behavior untested.

**Recommendation: [A]** — Now that the argument has real behavior, it needs a test.

---

#### Section: Cross-Cutting (Lens 2 — Test Completeness Matrix)

Updated 13-category assessment for v1.2:

| # | Category | Status | Notes |
|---|---|---|---|
| 1 | Happy path | ✅ Covered | Extensive list in Section 9.1 |
| 2 | Numerical oracle | ✅ Covered | Tolerances specified; logistic + Poisson included |
| 3 | Grouped analysis | ✅ Covered | `DV ~ treats * group` with taylor design |
| 4 | Domain estimation | ✅ Covered | Added in v1.2 |
| 5 | Variance argument | ✅ Covered | `"se"`, `c("se", "ci")`, `NULL` tested |
| 6 | label_values | ✅ Covered | `label_values = TRUE/FALSE` tests added in v1.2 |
| 7 | label_vars | ❌ **Missing** | See Issue 19 |
| 8 | meta() contract | ✅ Covered | Section 9.2 |
| 9 | name_style = "broom" | ✅ Covered | Added in v1.2 |
| 10 | Error paths | ✅ Covered | Dual pattern specified |
| 11 | Edge cases | ✅ Covered | 10 edge cases in Section 9.1 |
| 12 | Multi-variable | N/A | Single DV by design |
| 13 | Print snapshot | ✅ Covered | Added in v1.2 |

Mechanical rules — all pass:
- `test_invariants()` — N/A (analysis function). ✓
- Dual pattern for Layer 3 errors — specified. ✓
- `class=` on every error and warning — all present. ✓

---

#### Section: Cross-Cutting (Lens 6 — API Coherence)

**Issue 20: Unused factor levels in `treats` — behavior unspecified**
Severity: SUGGESTION
Violates `engineering-preferences.md` §4 (handle more edge cases)

If the `treats` column is a factor with levels that have 0 observations in the data
(or 0 in-domain observations after `filter()`), the GLM model matrix will have no
coefficients for those levels. The clean path (`clean()`) and marginaleffects path
(`avg_slopes()`) will silently omit those levels from the output.

This is arguably correct behavior — you can't estimate a treatment effect for a level
with no data. But the spec does not state this explicitly, and a user with a pre-defined
factor might expect all levels in the output (with `NA` estimates for empty levels).

Options:
- **[A]** Add to Section 3.6 after Step 5: "Unused factor levels (levels with 0
  observations after `na.action`) are silently dropped from the output. They do not
  appear as rows." — Effort: low, Risk: low, Impact: explicit, Maintenance: none
- **[B]** Add a warning when unused levels are detected:
  `surveycore_warning_unused_treats_levels`. — Effort: low, Risk: low, Impact:
  transparent, Maintenance: one warning class
- **[C] Do nothing** — Behavior is implicit from GLM mechanics.

**Recommendation: [A]** — One sentence of documentation prevents confusion.

---

**Issue 21: `group` with 1 unique value produces singular model matrix**
Severity: SUGGESTION
Missing edge case documentation

Section 9.1 edge cases include "`group` with only 1 unique value — Degenerates to
no-group case (verify)." But when `group` has 1 level, the formula
`x ~ treats * group` creates interaction terms with a single-level factor. The model
matrix becomes singular (the interaction columns are perfectly collinear with the main
effect). `survey_glm()` would throw `surveycore_error_singular_model_matrix`.

The edge case test description says "Degenerates to no-group case (verify)" — but it
doesn't degenerate; it errors. The test should verify the error propagation, not expect
a successful result.

Options:
- **[A]** Update the edge case description to: "`group` with only 1 unique value —
  `survey_glm()` throws `surveycore_error_singular_model_matrix` due to collinear
  interaction terms. Verify error propagation." — Effort: low, Risk: low, Impact:
  correct test expectation, Maintenance: none
- **[B]** Detect single-level groups before formula construction and drop the interaction
  term, effectively falling back to the no-group case with a warning. — Effort: medium,
  Risk: low, Impact: more graceful, Maintenance: low
- **[C] Do nothing** — Implementer discovers the error empirically.

**Recommendation: [A]** — At minimum, fix the test expectation. Option [B] is a nice
enhancement but adds complexity; it can be a follow-up.

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 2 |
| REQUIRED | 3 |
| SUGGESTION | 2 |

**Total new issues:** 7

| # | Title | Lens | Severity |
|---|---|---|---|
| 15 | `survey_srs` removed but still in spec | 3, 6 | BLOCKING |
| 16 | `name_style = "broom"` duplicate `estimate` columns | 1, 6 | BLOCKING |
| 17 | `treats` column labeling mechanism unspecified | 3 | REQUIRED |
| 18 | `n_weighted` for reference row not specified | 3 | REQUIRED |
| 19 | `label_vars` test missing from test plan | 2 | REQUIRED |
| 20 | Unused factor levels in `treats` unspecified | 4, 6 | SUGGESTION |
| 21 | `group` with 1 level — singular matrix, not degenerate | 4, 6 | SUGGESTION |

**Overall assessment:** All 14 Pass 1 issues are resolved — the v1.2 spec is substantially
improved. Two new blocking issues emerged: (1) the `survey_srs` class removal invalidates
the supported design classes table and `.meta` contract, and (2) `.apply_name_style()`
creates duplicate `estimate` columns when `show_means = TRUE` and `name_style = "broom"`.
The 3 required issues are contract gaps: unspecified `treats` labeling mechanism, missing
`n_weighted` in the reference row contract, and missing `label_vars` test. All 7 issues
are addressable without architectural changes. After resolving the 2 blocking issues, the
spec is implementable.

---

## Pass 3 (2026-03-17)

### Prior Issues (Pass 2)

| # | Title | Status |
|---|---|---|
| 15 | `survey_srs` removed but still in spec | ✅ Resolved — Section I now lists 4 classes (taylor, replicate, twophase, nonprob); "srs" removed from Section IV `design_type` |
| 16 | `name_style = "broom"` duplicate `estimate` columns | ✅ Resolved — Section 3.2 documents `mean` excluded from broom rename; Section 7.1 Step 19 specifies exclusion approach |
| 17 | `treats` column labeling mechanism unspecified | ✅ Resolved — Section 3.2 (`label_values`) and Section 7.1 Step 17a specify `.apply_group_labels()` post-assembly for both `treats` and `group` columns |
| 18 | `n_weighted` for reference row not specified | ✅ Resolved — Section 5.4 now includes `n_weighted` in reference row contract |
| 19 | `label_vars` test missing from test plan | ✅ Resolved — Section 9.1 now has `label_vars = TRUE`, `label_vars = FALSE`, and `label_vars = TRUE` fallback tests |
| 20 | Unused factor levels in `treats` unspecified | ✅ Resolved — Section 3.6 documents silent omission of unused levels from output |
| 21 | `group` with 1 level — singular matrix, not degenerate | ✅ Resolved — Section 9.1 edge case updated to expect `surveycore_error_singular_model_matrix` |

All 7 Pass 2 issues resolved.

### New Issues

#### Section: III. Function Specification

**Issue 22: `avg_slopes()` missing `type = "link"` when `scale = "link"` on marginaleffects path**
Severity: BLOCKING
Violates correctness — produces response-scale AMEs labeled as link-scale coefficients

Section 7.2 routing logic:
```r
use_marginaleffects <- has_covariates ||
  has_group ||
  (family_name != "gaussian" && scale == "ame")
```

When `scale = "link"` + non-gaussian + (covariates OR group), `use_marginaleffects = TRUE`.
The marginaleffects path (Section 3.8.1) calls:
```r
slopes <- marginaleffects::avg_slopes(
  fit,
  variables = treats_name,
  wts = TRUE,
  df = res_df
)
```

The default for `avg_slopes()` is `type = "response"`, which returns AMEs on the response
scale (e.g., probability differences for logistic). But the user requested `scale = "link"`
— they want link-scale coefficients (e.g., log-odds ratios).

**Concrete example:** For `logit(P(y=1)) = β0 + β1*treatment + β2*age`:
- With `type = "response"` (current spec): `avg_slopes()` returns ~0.05 (5pp probability
  difference). This is the AME, NOT the coefficient.
- With `type = "link"`: `avg_slopes()` returns β1 (~0.50 log-odds ratio). This is what
  the user expects when `scale = "link"`.

The `.meta$estimate_scale` would record `"coefficient"` (per Section IV: "With
`scale = 'link'`, always `'coefficient'`"), but the actual value would be an AME. Silent
mislabeling.

The clean path (no covariates, no group) handles `scale = "link"` correctly because it
extracts coefficients directly. The gap is only when covariates or groups force the
marginaleffects path.

Options:
- **[A]** Add `type` argument to all `avg_slopes()` and `avg_predictions()` calls:
  `type = if (scale == "link") "link" else "response"`. For `avg_predictions()`, this
  only matters if means are not suppressed (they are suppressed for link + non-gaussian,
  so `avg_predictions()` can be skipped entirely in that case). — Effort: low, Risk: low,
  Impact: correctness, Maintenance: none
- **[B]** Disallow `scale = "link"` when covariates or groups are present for
  non-gaussian families. Error with a typed class. — Effort: low, Risk: low, Impact:
  simplicity at cost of functionality, Maintenance: none
- **[C] Do nothing** — Response-scale AMEs mislabeled as link-scale coefficients.

**Recommendation: [A]** — Pass `type = "link"` when `scale = "link"`. This is a one-line
fix in the spec's code blocks and maintains full functionality. `marginaleffects`
supports the `type` argument in both `avg_slopes()` and `avg_predictions()`.

---

**Issue 23: `variance` argument accepts only `"se"` and `"ci"` but `.validate_shared_args()` accepts full set**
Severity: REQUIRED
Violates `engineering-preferences.md` §4 (handle more edge cases) and API coherence

Section 3.2 defines:
> `variance`: One or more of: `"se"`, `"ci"`. `NULL` = no uncertainty columns.

But `.validate_shared_args()` defaults to `valid_variance = c("se", "ci", "var", "cv",
"moe", "deff")`. If `get_diffs()` calls `.validate_shared_args()` without overriding
`valid_variance`, a user passing `variance = "deff"` would:
1. Pass validation (no error)
2. Get no `deff` column in the output (silently missing)

Phase 1 functions compute `"var"`, `"cv"`, `"moe"`, `"deff"` via `.add_variance_cols()`.
`get_diffs()` does not call `.add_variance_cols()` — SEs and CIs come from `clean()` or
`marginaleffects`. Computing `deff` or `cv` would require additional work not specified
in the spec.

Options:
- **[A]** Specify that `get_diffs()` passes `valid_variance = c("se", "ci")` to
  `.validate_shared_args()`. Users requesting unsupported variance types get
  `surveycore_error_invalid_variance_arg` with the restricted set shown. — Effort: low,
  Risk: low, Impact: prevents silent gap, Maintenance: none
- **[B]** Expand variance support to include `"var"`, `"cv"`, `"moe"` by computing them
  from the SE column (variance = SE², cv = SE/estimate, moe = t_crit * SE). `"deff"` is
  not feasible without an SRS baseline. — Effort: medium, Risk: low, Impact: richer API,
  Maintenance: low
- **[C] Do nothing** — Silent gap when user passes unsupported type.

**Recommendation: [A]** — Restrict the valid set. Option [B] is a nice follow-up but adds
scope; the clean path and marginaleffects path both provide SEs, which is sufficient for
`"se"` and `"ci"`.

---

#### Section: VII. Execution Flow

**Issue 24: Step 7 omits forcing treatment contrasts — critical methodology fix invisible in summary**
Severity: REQUIRED
Violates `engineering-preferences.md` §5 (explicit over clever) — critical step hidden

Section 7.1 execution flow Step 7:
```
Step 7:  Coerce treats to factor, relevel if needed
```

But Section 3.6 Step 5 specifies a critical step resolved from a BLOCKING methodology
review issue (Issue 1, contrast validation):
> **Force treatment contrasts:** After coercion and releveling, explicitly set
> `contrasts(design@data[[treats_name]]) <- stats::contr.treatment(...)`.

The forced contrasts step is the fix for a blocking correctness issue (non-treatment
contrasts silently produce wrong reference means). An implementer following the execution
flow as a checklist would miss it.

Options:
- **[A]** Expand Step 7 to: "Coerce treats to factor, relevel if needed, force treatment
  contrasts (Section 3.6 Step 5)." — Effort: low, Risk: low, Impact: critical step visible
  in summary, Maintenance: none
- **[C] Do nothing** — Section 3.6 is authoritative; execution flow is a summary.

**Recommendation: [A]** — The execution flow is the implementer's primary checklist.
Critical steps should not be hidden in section cross-references.

---

**Issue 25: Execution flow missing validation of `covariates` and `pval_adj`**
Severity: REQUIRED
Violates contract completeness — error table entries have no corresponding execution step

Section 6.1 defines two error classes with no corresponding step in the execution flow
(Section 7.1):
- `surveycore_error_covariates_not_character` — triggers when `covariates` is not a
  character vector
- `surveycore_error_invalid_pval_adj` — triggers when `pval_adj` is not a valid
  `stats::p.adjust()` method

The execution flow goes directly from "Step 4: Validate x is numeric, treats has ≥ 2
levels" to "Step 5: Handle ref_level". Neither `covariates` type-checking nor `pval_adj`
method validation appears in any step.

Options:
- **[A]** Add a validation sub-step to Step 4 (or a new Step 4a): "Validate `covariates`
  is character or NULL; validate `pval_adj` is a valid `stats::p.adjust()` method or NULL."
  — Effort: low, Risk: low, Impact: complete flow, Maintenance: none
- **[C] Do nothing** — Implementer discovers from error table.

**Recommendation: [A]** — The execution flow should be implementable as-is without
requiring the implementer to scan the error table for missing steps.

---

#### Section: IX. Testing Requirements

**Issue 26: `label_vars = TRUE` fallback test (no metadata label) missing**
Severity: SUGGESTION
Test completeness gap — fallback behavior untested

Section 9.1 now includes:
- `label_vars = TRUE` — column labels use variable labels from metadata
- `label_vars = FALSE` — column labels use raw variable names

But there is no test for the fallback case: when `label_vars = TRUE` (default) but the
`treats` or `group` variable has **no metadata label** (neither in `@metadata` nor as a
haven attribute). In this case, the column-level `label` attribute should fall back to the
raw variable name. This fallback is implied but never explicitly tested.

Options:
- **[A]** Add to Section 9.1: "`label_vars = TRUE` fallback — when no metadata label
  exists, column-level `label` attributes fall back to raw variable names." — Effort: low,
  Risk: low, Impact: guards fallback path, Maintenance: one test
- **[C] Do nothing** — Fallback behavior is implicit.

**Recommendation: [A]** — Explicit test for the fallback prevents a missing-label scenario
from silently producing `NULL` or `NA` as a column label.

---

#### Section: X. Quality Gates

**Issue 27: Quality Gates stale "5 design classes" count**
Severity: REQUIRED
Violates contract completeness — count doesn't match spec

Section X states:
> All 5 design classes have at least one happy-path test

But the spec now lists 4 supported design classes (taylor, replicate, twophase, nonprob)
after `survey_srs` was removed in Pass 2 Issue 15 resolution. The quality gate count
is stale.

Options:
- **[A]** Change to "All 4 design classes have at least one happy-path test." — Effort:
  negligible, Risk: none, Impact: correctness, Maintenance: none
- **[C] Do nothing** — Misleads implementer into searching for a 5th class.

**Recommendation: [A]** — One-word fix.

---

#### Section: Cross-Cutting (Lens 1 — DRY)

**Issue 28: `.meta$treats` structure inconsistent with `.extract_var_meta()` pattern**
Severity: SUGGESTION
Violates `engineering-preferences.md` §1 (DRY) — different structure for same concept

Section IV defines `.meta$treats` as:
> `list(name, variable_label, value_labels, ref_level)`

Phase 1 `.meta$group` entries use `.extract_var_meta()`, which returns:
> `list(variable_label, question_preface, value_labels)`

The `treats` entry diverges by:
1. Adding `name` (the variable name) — in group meta, the variable name is the list key
2. Adding `ref_level` — unique to `get_diffs()`
3. Omitting `question_preface` — present in group meta via `.extract_var_meta()`

This means `.meta$treats` cannot be built by calling `.extract_var_meta()` and appending
fields. Instead, it requires a custom construction path.

Options:
- **[A]** Build `.meta$treats` by calling `.extract_var_meta(design, treats_name)` and
  then appending `name = treats_name` and `ref_level = ref_level` to the result. This
  includes `question_preface` for consistency. — Effort: low, Risk: low, Impact: DRY,
  Maintenance: none
- **[C] Do nothing** — Custom construction.

**Recommendation: [A]** — Reuse `.extract_var_meta()` and extend with diffs-specific
fields. This keeps the pattern consistent and includes `question_preface` for free.

---

#### Section: Cross-Cutting (Lens 2 — Test Completeness Matrix)

Updated 13-category assessment for v1.3:

| # | Category | Status | Notes |
|---|---|---|---|
| 1 | Happy path | ✅ Covered | Extensive list in Section 9.1 |
| 2 | Numerical oracle | ✅ Covered | Bivariate OLS, multivariate OLS, logistic AME, Poisson AME, SRS vcov, replicate df |
| 3 | Grouped analysis | ✅ Covered | `DV ~ treats * group` with taylor design |
| 4 | Domain estimation | ✅ Covered | `filter(design, condition) \|> get_diffs(...)` |
| 5 | Variance argument | ✅ Covered | `"se"`, `c("se", "ci")`, `NULL` tested |
| 6 | label_values | ✅ Covered | `label_values = TRUE/FALSE` tests |
| 7 | label_vars | ✅ Covered | `label_vars = TRUE/FALSE` tests; fallback missing (Issue 26) |
| 8 | meta() contract | ✅ Covered | Section 9.2 |
| 9 | name_style = "broom" | ✅ Covered | Test specified including `mean` exclusion |
| 10 | Error paths | ✅ Covered | Dual pattern specified |
| 11 | Edge cases | ✅ Covered | 10+ edge cases including singular group, unused levels |
| 12 | Multi-variable | N/A | Single DV by design |
| 13 | Print snapshot | ✅ Covered | `expect_snapshot(print(result))` specified |

Mechanical rules — all pass:
- `test_invariants()` — N/A (analysis function). ✓
- Dual pattern for Layer 3 errors — specified. ✓
- `class=` on every error and warning — all present. ✓

---

#### Section: Cross-Cutting (Lens 6 — API Coherence)

Traced realistic workflow: `get_diffs(d, dv, treatment, covariates = c("age", "gender"), scale = "link", family = quasibinomial())`. With this configuration:
- `scale = "link"` + non-gaussian + covariates → marginaleffects path
- `avg_slopes()` returns response-scale AMEs (default `type = "response"`)
- User expects log-odds ratios, gets probability differences
- `.meta$estimate_scale = "coefficient"` but actual values are AMEs

This is Issue 22 — the most critical finding in this pass.

No other API coherence issues identified. The `treats` labeling via `.apply_group_labels()`,
the `name_style = "broom"` exclusion of `mean`, and the Phase 1 API uniformity additions
all work correctly in realistic workflows.

---

## Summary (Pass 3)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 4 |
| SUGGESTION | 2 |

**Total new issues:** 7

| # | Title | Lens | Severity |
|---|---|---|---|
| 22 | `avg_slopes()` missing `type = "link"` for `scale = "link"` | 3, 6 | BLOCKING |
| 23 | `variance` valid set not restricted in `.validate_shared_args()` call | 3 | REQUIRED |
| 24 | Execution flow Step 7 omits forcing treatment contrasts | 3 | REQUIRED |
| 25 | Execution flow missing covariates and pval_adj validation | 3 | REQUIRED |
| 26 | `label_vars = TRUE` fallback test missing | 2 | SUGGESTION |
| 27 | Quality Gates stale "5 design classes" count | 3 | REQUIRED |
| 28 | `.meta$treats` structure inconsistent with `.extract_var_meta()` | 1 | SUGGESTION |

**Overall assessment:** All 7 Pass 2 issues are resolved — the v1.3 spec is substantially
improved. One new blocking issue emerged: `avg_slopes()` does not pass `type = "link"` when
`scale = "link"` is active on the marginaleffects path, causing response-scale AMEs to be
silently mislabeled as link-scale coefficients. This affects non-gaussian models with
covariates or groups when `scale = "link"`. The 4 required issues are: restrictng the
`variance` valid set, two execution flow completeness gaps (forced contrasts and
covariates/pval_adj validation), and a stale design class count in Quality Gates. The 2
suggestions are a missing fallback test and a minor structural inconsistency in
`.meta$treats`. After resolving the blocking issue, the spec is implementable.
