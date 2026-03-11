# Spec Review: Phase 1 Formal Specification

**Reviewed:** `plans/phase-1-formal-specification.md` (v1.1, February 2026)
**Reviewer:** Claude Code (adversarial pass — second round)
**Date:** 2026-02-24
**Note:** Previous review was incorporated into spec v1.1. This is a fresh pass on the updated spec.

---

## Section I: Scope

No issues found.

---

## Section II: Architecture

**Issue 1: `value_labels` in meta contract says "all functions" but `CORR_META_KEYS` and `RATIOS_META_KEYS` omit it**
Severity: BLOCKING

Section 2.4 states under "Variable metadata fields": `value_labels | all functions | named list | Always a named list...`

But Section 2.2's required meta-key constants are:
```r
CORR_META_KEYS   <- c("variables", "variable_labels", "question_prefaces", "method")
RATIOS_META_KEYS <- c("numerator", "numerator_label", "denominator", "denominator_label", "question_prefaces")
```
Neither includes `value_labels`. Every other function's constant (`FREQS_SINGLE_META_KEYS`, `FREQS_MULTI_META_KEYS`, `MEANS_META_KEYS`, `TOTALS_META_KEYS`, `QUANTILES_META_KEYS`) does include it.

The spec also states: "Functions must supply exactly the keys shown below — no extras, no omissions." This creates a direct contradiction: Section 2.4 says `value_labels` is in "all functions," but the CORR and RATIOS constants omit it, meaning those functions must NOT supply it. An implementer following the constants contract will fail `test_result_invariants()` invariant #5. An implementer following the "all functions" claim will fail `stopifnot()` in `.make_result_tibble()` because the key is absent from the constant.

Options:
- **[A]** Add `value_labels` to `CORR_META_KEYS` and `RATIOS_META_KEYS`. Document the expected value: for numeric variables, `value_labels` is `list(var_name = NULL)` per the existing pattern. Add a note in Section 2.2 clarifying this. Effort: low, Risk: low, Impact: removes contradiction; consistent invariant behavior.
- **[B]** Remove `value_labels` from the "all functions" claim in Section 2.4. Scope it to functions that accept categorical variables: `get_freqs()`, `get_means()`, `get_totals()`, `get_quantiles()`. Update `test_result_invariants()` invariant #5 to be function-specific. Effort: medium, Risk: low, Impact: accurate scoping but more complex invariant.
- **[C] Do nothing** — implementer contradiction; `test_result_invariants()` and `stopifnot()` will fail for `get_corr()` and `get_ratios()`.

**Recommendation: [A]** — consistency is simplest; `list(var = NULL)` for numeric variables is the established pattern.

---

**Issue 2: `test_result_invariants()` invariant #5 will fail for `get_corr()` and `get_ratios()`**
Severity: REQUIRED

A direct consequence of Issue 1. The invariant code in Section 11.2:
```r
# 5. value_labels always populated and is a non-empty named list
expect_true("value_labels" %in% names(m))
expect_type(m$value_labels, "list")
expect_gt(length(m$value_labels), 0L)
expect_false(is.null(names(m$value_labels)))
```
If `CORR_META_KEYS` and `RATIOS_META_KEYS` don't include `value_labels`, `meta(result)$value_labels` will be absent for those functions. Invariant #5 fails. This must be resolved together with Issue 1.

Options:
- **[A]** Resolve Issue 1 first (add `value_labels` to CORR/RATIOS keys). The invariant then holds universally. Effort: coupled to Issue 1.
- **[B]** Guard invariant #5 per function class: only check for functions where `value_labels` is applicable. Effort: medium, Risk: medium (weakens the invariant).
- **[C] Do nothing** — `test_result_invariants()` will fail for any `get_corr()` or `get_ratios()` test block.

**Recommendation: [A]** — resolve Issue 1 and this issue disappears.

---

**Issue 3: `S3method(print, survey_result) <- function(x, ...)` is invalid R syntax**
Severity: REQUIRED

Section 2.5 shows:
```r
S3method(print, survey_result) <- function(x, ...) {
  cls  <- class(x)[1]
  dims <- paste(nrow(x), "\u00d7", ncol(x))
  cat(sprintf("# A <%s> [%s]\n", cls, dims))
  NextMethod()
  invisible(x)
}
```
`S3method(print, survey_result) <-` is invalid R. `S3method()` is a NAMESPACE directive recognized by `devtools::document()` — it is not assignable. If an implementer copies this code, they will get a parse-time error. `survey_result` is an S3 class (built on tibble), not an S7 class, so the `S7::method() <-` syntax from `code-style.md` does not apply.

The correct R syntax is:
```r
print.survey_result <- function(x, ...) {
  # body
}
```
Registered in NAMESPACE via `#' @export` or `#' @method print survey_result` in roxygen2.

Options:
- **[A]** Fix the code block to use `print.survey_result <- function(x, ...) {...}`. Add a roxygen2 comment showing how to register it (`@method print survey_result`). Effort: trivial, Risk: low.
- **[C] Do nothing** — implementers who copy the code block will get a parse error at `devtools::load_all()`.

**Recommendation: [A]**.

---

**Issue 4: `.build_meta()` `design_type` mapping from S7 class to string not specified**
Severity: REQUIRED

Section 2.2 says `.build_meta()` derives `design_type` "from the S7 class of `design`." Section 2.4 lists valid string values: `"taylor"`, `"replicate"`, `"twophase"`, `"srs"`, `"calibrated"`. But the mapping is not defined anywhere:

- `survey_taylor` → `"taylor"` ?
- `survey_replicate` → `"replicate"` ?
- `survey_twophase` → `"twophase"` ?
- `survey_srs` → `"srs"` ?
- `survey_nonprob` → `"calibrated"` ?

The mapping is obvious by inspection, but an implementer could produce `"survey_taylor"` via `class(design)[1]` string manipulation, or `"SurveyTaylor"`, or anything else. If downstream code (e.g., in surveytidy) branches on `meta(result)$design_type == "taylor"`, a different string breaks it silently.

Options:
- **[A]** Add a lookup table to Section 2.2 (or as a constant `DESIGN_TYPE_MAP` in `R/09-analysis-helpers.R`):
  ```r
  # design_type mapping used in .build_meta()
  # S7::S7_inherits() used per code-style.md §2
  design_type <- dplyr::case_when(
    S7::S7_inherits(design, survey_taylor)    ~ "taylor",
    S7::S7_inherits(design, survey_replicate) ~ "replicate",
    S7::S7_inherits(design, survey_twophase)  ~ "twophase",
    S7::S7_inherits(design, survey_srs)       ~ "srs",
    S7::S7_inherits(design, survey_nonprob)~ "calibrated"
  )
  ```
  Or equivalent if-else chain. Effort: low, Risk: low, Impact: canonical string values enforced.
- **[B]** Add the mapping table to the spec as prose without code. Effort: trivial.
- **[C] Do nothing** — implementers will use different strings; downstream consumers will break.

**Recommendation: [A]** — the canonical string values belong in the spec and implementation.

---

**Issue 5: `.make_result_tibble()` — `required_meta_keys` required vs. optional not specified**
Severity: REQUIRED

Section 2.2 says: "`.make_result_tibble()` validates `required_meta_keys` with `stopifnot(all(required_meta_keys %in% names(meta_args)))`. Each `get_*()` function passes its constant."

But the function signature is:
```r
.make_result_tibble(result_cols, groups_df, class_name, design, meta_args,
                    conf_level, call, group_names, required_meta_keys, ...)
```

The spec does not say whether `required_meta_keys` has a default (e.g., `NULL`, which would skip validation). If it is required (no default), the spec should state this. If it defaults to `NULL` (skip validation), the spec should state that too — otherwise the validation purpose is unclear. Given the DRY rationale, it should be required with no default.

Options:
- **[A]** Add to the `.make_result_tibble()` description: "`required_meta_keys` has no default and must always be provided; passing the function's `*_META_KEYS` constant is required." Effort: trivial, Risk: low.
- **[C] Do nothing** — implementers will default it to NULL and skip the validation.

**Recommendation: [A]**.

---

**Issue 6: `surveycore_error_all_na` scoped to `get_freqs()` in spec but "all `get_*()` functions" in `error-messages.md`**
Severity: REQUIRED

Section 2.6 and Section 3.5 both state `surveycore_error_all_na` is scoped to `get_freqs()` only:
> "If the entire focal variable is NA and `na.rm = FALSE`, the function errors with `surveycore_error_all_na`. This differs from numeric functions (`get_means()`, etc.) where any NA with `na.rm = FALSE` throws `surveycore_error_na_in_variable` — including the all-NA case."

But `error-messages.md` lists this error with "all `get_*()` functions" in the Function column. An implementer reading `error-messages.md` (the canonical error table) would incorrectly add `surveycore_error_all_na` handling to all six functions, creating a divergence from spec intent.

Options:
- **[A]** Update `error-messages.md` row for `surveycore_error_all_na` to scope it to `get_freqs()` only. Effort: trivial, Risk: low, Impact: canonical error table matches spec.
- **[C] Do nothing** — numeric functions will have dead or incorrect error paths.

**Recommendation: [A]**.

---

**Issue 7: `surveycore_warning_corr_non_numeric` — behavior after dropping leaves < 2 variables unspecified**
Severity: REQUIRED

Section X defines `surveycore_warning_corr_non_numeric` as firing when "Non-numeric variable in `x` silently dropped." Section 6.4 says `surveycore_error_insufficient_variables` fires when "fewer than 2 variables are supplied." But what if dropping non-numeric variables results in fewer than 2 remaining variables?

Example: `get_corr(d, x = c(income, sex, region))` where `sex` and `region` are character. Both are dropped with `surveycore_warning_corr_non_numeric`, leaving 1 variable. The spec is silent on whether `surveycore_error_insufficient_variables` then fires.

Options:
- **[A]** Add to Section 6.4: "Insufficient-variable checking occurs *after* non-numeric variables are silently dropped. If fewer than 2 numeric variables remain after dropping, `surveycore_error_insufficient_variables` is thrown (in addition to any `surveycore_warning_corr_non_numeric` warnings already fired)." Effort: low, Risk: low.
- **[B]** Check the variable count *before* dropping. If the user supplied < 2 numeric variables, throw the error immediately without warning. Effort: low, Risk: medium (changes interaction order).
- **[C] Do nothing** — implementations will differ; one will warn then silently proceed, another will error.

**Recommendation: [A]** — validation ordering should be explicit.

---

**Issue 8: `get_quantiles()` output column order contradicts Section 2.6; `[var]` and `[cv]` absent**
Severity: REQUIRED

Section 7.2 specifies:
```
[group_names...]   quantile   estimate   [ci_low   ci_high]   [se]   [moe]   n
```

Section 2.6 mandates the column order when multiple variance measures are present: `se`, `var`, `cv`, `ci_low`, `ci_high`, `moe`.

Section 7.2 puts `[ci_low ci_high]` before `[se]` — directly inverting the Section 2.6 order. Additionally, `[var]` and `[cv]` are entirely absent from the column spec.

The correct column spec for Section 7.2 should be:
```
[group_names...]   quantile   estimate   [se]   [var]   [cv]   [ci_low]   [ci_high]   [moe]   n
```

Options:
- **[A]** Fix Section 7.2 column spec to match Section 2.6 order and include `[var]` and `[cv]`. Effort: trivial, Risk: low.
- **[C] Do nothing** — `get_quantiles()` column order will contradict the cross-cutting contract.

**Recommendation: [A]**.

---

**Issue 9: `[var]` and `[cv]` absent from `get_means()` and `get_ratios()` column specs**
Severity: REQUIRED

Section 4.2 (`get_means()`) output spec:
```
[group_names...]   mean   [se]   [ci_low  ci_high]   [moe]   n
```

Section 8.2 (`get_ratios()`) output spec:
```
[group_names...]   ratio   [se]   [ci_low  ci_high]   [moe]   n
```

Both omit `[var]` and `[cv]`. Section 2.6 says `"var"` and `"cv"` are accepted by all six functions. Compare `get_totals()` Section 5.2 which correctly includes `[var]` and `[cv]`. The column order in Sections 4.2 and 8.2 should also be updated to match the Section 2.6 ordering (`se`, `var`, `cv`, `ci_low`, `ci_high`, `moe`).

Options:
- **[A]** Fix both sections to include `[var]` and `[cv]` and correct column ordering. Effort: trivial.
- **[C] Do nothing** — `get_means()` and `get_ratios()` will silently omit `var` and `cv` columns.

**Recommendation: [A]**.

---

**Issue 10: Stale `variance = "both"` reference in Section 6.2**
Severity: REQUIRED

Line 1107 of the spec reads:
> **`variance = "both"`:** includes `se`, `ci_low`, and `ci_high` columns.

`"both"` is not a valid `variance` value. Per Section 2.6, valid values are `c("se", "ci", "var", "cv", "moe")`. A `variance = "both"` call would correctly trigger `surveycore_error_invalid_variance_arg`. The `claude-decisions-phase-1.md` log confirms `"both"` was eliminated when `variance` was redesigned as a character vector. This stale text will cause an implementer to add `"both"` handling to `.validate_shared_args()`, introducing an undocumented argument value.

Options:
- **[A]** Remove the `variance = "both"` paragraph. Replace with `variance = c("se", "ci")` if an example of combining values is desired. Effort: trivial.
- **[C] Do nothing** — implementers add undocumented `"both"` logic that contradicts Section 2.6.

**Recommendation: [A]**.

---

**Issue 11: `get_corr()` Section 6.2 column spec and `variance = "se"` example are internally inconsistent**
Severity: REQUIRED

The column spec header in Section 6.2:
```
var1   var2   r   ci_low   ci_high   p_value   statistic   df   n
```
`ci_low` and `ci_high` appear without brackets — implying they are always present.

But the example immediately below:
```r
get_corr(d, x = c(income, bmi), variance = "se")
  var1    var2     r      se   p_value  statistic    df     n
```
shows `ci_low` and `ci_high` absent when `variance = "se"`. The header and example contradict each other.

The correct column spec should bracket them:
```
var1   var2   r   [se]   [var]   [cv]   [ci_low]   [ci_high]   [moe]   p_value   statistic   df   n
```
where `p_value`, `statistic`, `df`, and `n` are always-present.

Options:
- **[A]** Bracket all variance columns in the header. Separate the always-present columns explicitly. Effort: low, Risk: low.
- **[C] Do nothing** — implementers treat `ci_low/ci_high` as always-present; tests break when `variance = NULL`.

**Recommendation: [A]**.

---

**Issue 12: Section 6.3 "No uncertainty columns in wide format" does not address `p_value`, `statistic`, `df`, `n`**
Severity: REQUIRED

Section 6.3 says "No uncertainty columns in wide format." The wide format example shows only correlation coefficients. But "uncertainty columns" could mean only `se`/`var`/`cv`/`ci_low`/`ci_high`/`moe` — leaving `p_value`, `statistic`, `df`, and `n` potentially includable in wide format.

The example implies only `r` values are shown, but implication is not specification. An implementer could add a separate `p_value` matrix or `n` matrix in wide format; there is no text prohibiting it.

Options:
- **[A]** Add to Section 6.3: "Wide format contains only the correlation matrix (r values). All other columns (`p_value`, `statistic`, `df`, `n`, and any variance columns) are excluded from wide format. Use `format = \"long\"` to access inference statistics." Effort: low, Risk: low.
- **[C] Do nothing** — wide format scope is ambiguous; implementations differ.

**Recommendation: [A]**.

---

**Issue 13: `n_respondents` is "always populated" but `test_result_invariants()` does not check it**
Severity: REQUIRED

Section 2.4 declares: `n_respondents | all functions | integer | Raw respondent headcount including zero-weight rows; always populated.`

Section 2.6 reinforces: "This value is always populated and accessible via `meta()`."

The `test_result_invariants()` function in Section 11.2 checks five common meta keys (`design_type`, `conf_level`, `call`, `group_names`, `group_labels`) and `value_labels`. It does not check `n_respondents`. An implementer who omits `n_respondents` from the meta output would pass all invariant tests. Given the spec's explicit "always populated" guarantee, it belongs in the invariant checker.

Options:
- **[A]** Add to `test_result_invariants()`:
  ```r
  # 6. n_respondents always present and is a positive integer
  expect_true("n_respondents" %in% names(m))
  expect_type(m$n_respondents, "integer")
  expect_gt(m$n_respondents, 0L)
  ```
  Effort: low, Risk: low.
- **[C] Do nothing** — `n_respondents` is silently absent from many implementations.

**Recommendation: [A]**.

---

**Issue 14: Oracle test in Section 11.1 uses `get_corr(...)$se` without specifying `variance = "se"`**
Severity: REQUIRED

The oracle code in Section 11.1:
```r
expect_equal(get_corr(d_sc, c(x, y))$se, se_oracle, tolerance = 1e-8)
```

`get_corr()` has `variance = "ci"` as its default. The `se` column is only present when `variance` includes `"se"`. This oracle test as written will return `NULL` (not throw an error) because `tibble$absent_col` returns `NULL` — causing the tolerance comparison to fail with an opaque error rather than a clear test failure.

The oracle call should be `get_corr(d_sc, c(x, y), variance = "se")$se` or `get_corr(d_sc, c(x, y), variance = c("ci", "se"))$se`.

Options:
- **[A]** Fix the oracle code to include `variance = "se"` explicitly. Effort: trivial.
- **[C] Do nothing** — oracle test silently passes `NULL` to `expect_equal()` and fails with a confusing error.

**Recommendation: [A]**.

---

**Issue 15: Stale `R/06-variance-estimation.R` single-file references throughout spec**
Severity: SUGGESTION
Violates current codebase state (PR #9 split this file into four engine-specific files)

PR #9 (`refactor(variance): split variance-estimation.R into four engine-specific files`) replaced `R/06-variance-estimation.R` with:
- `R/06-variance-dispatch.R`
- `R/06-variance-replicate.R`
- `R/06-variance-srs.R`
- `R/06-variance-taylor.R`
- `R/06-variance-twophase.R`

The spec references the old single file in at least: Section I (Stub Migration paragraph), Section 2.2 (dispatch table note), Section 3.5, 4.3, 5.3, 7.3. An implementer looking for "stubs in `R/06-variance-estimation.R`" will not find that file.

Options:
- **[A]** Update all `R/06-variance-estimation.R` references to the correct split-file names. For the stub removal (Sections I and stub migration), note which file the stubs live in (`R/06-variance-dispatch.R`). For the dispatch table, reference the appropriate engine file per method. Effort: low.
- **[C] Do nothing** — implementers check the codebase to find the actual files; confusing but not blocking.

**Recommendation: [A]** — spec accuracy prevents needless confusion during implementation.

---

## Section III: `get_freqs()`

**Issue 16: `get_freqs()` multi-var column spec uses `[variance cols]` without ordering; `[n_weighted]` absent**
Severity: SUGGESTION

Section 3.4 multi-var output spec:
```
[group_names...]   [names_to]   [values_to]   pct    n    [variance cols]
```

Two problems:
1. `n` appears before `[variance cols]`, but Section 3.2 (single-var) specifies `pct [se] [var] [cv] [ci_low] [ci_high] [moe] n [n_weighted]` — `n` comes after variance columns. The two modes are inconsistent.
2. `[n_weighted]` is documented as a parameter that applies to multi-var calls but is absent from the multi-var column spec.

Options:
- **[A]** Make multi-var column ordering consistent with single-var:
  ```
  [group_names...]   [names_to]   [values_to]   pct   [se]   [var]   [cv]   [ci_low]   [ci_high]   [moe]   n   [n_weighted]
  ```
  Effort: trivial.
- **[C] Do nothing** — inconsistency between single-var and multi-var column ordering.

**Recommendation: [A]**.

---

## Section IV: `get_means()`

No issues found.

---

## Section V: `get_totals()`

No issues found.

---

## Section VI: `get_corr()`

Issues 7, 10, 11, 12 above cover this section. One additional suggestion:

**Issue 17: `ci_low`/`ci_high` shown without brackets implies always-present**
Severity: SUGGESTION

(Incorporated into Issue 11 above as a REQUIRED issue. No separate suggestion entry needed.)

**Issue 17: `surveycore_warning_small_cell` — "cell" undefined for `get_corr()`**
Severity: SUGGESTION

Section 2.6 and Section X define `surveycore_warning_small_cell` as firing when "any cell has unweighted `n < 5`." For tabular functions (`get_freqs()`, `get_means()`, etc.), "cell" is unambiguous: one row = one group-level combination. For `get_corr()`, each row represents a variable pair — a "cell" is not intuitive. Is the warning about pairwise `n`? Per-group-per-pair `n`?

Options:
- **[A]** Add to Section 6.2 or Section X: "For `get_corr()`, `surveycore_warning_small_cell` fires when any variable pair's pairwise `n < 5`." Effort: trivial.
- **[C] Do nothing** — implementers will use different thresholds for `get_corr()`.

**Recommendation: [A]**.

---

## Section VII: `get_quantiles()`

Issue 8 above covers this section.

---

## Section VIII: `get_ratios()`

Issue 9 above covers this section.

---

## Section IX: `get_diffs()` (Deferred)

No issues found.

---

## Section X: Error and Warning Classes

Issue 6 above covers `surveycore_error_all_na` scoping.

**Issue 18: `n_respondents` meta field — scalar vs. per-group not specified**
Severity: SUGGESTION

Section 2.4 declares `n_respondents` as `integer` type with description "Raw respondent headcount including zero-weight rows; always populated." For a grouped analysis (`get_means(d, income, group = region)` with 4 regions), is `n_respondents` the total N across all groups (scalar), or a named integer vector with one entry per group level?

The singular phrasing ("headcount") and `integer` type (not `integer vector`) suggest it is a scalar total-N. But this is not stated, and a per-group breakdown would be more informative.

Options:
- **[A]** Add to Section 2.4: "`n_respondents` is a scalar `integer` equal to `nrow(design@data)` — the total number of rows in the design regardless of groups, domain status, or weight." Effort: trivial.
- **[C] Do nothing** — implementations vary; some produce total-N, some per-group.

**Recommendation: [A]**.

---

## Section XI: Test Strategy

Issues 2, 13, 14 above cover this section.

---

## Section XII: Quality Gates

No issues found.

---

## Section XIII: Integration with surveytidy

No issues found.

---

## Section: AAPOR Compliance Gaps
*Source: `plans/aapor-compliance-review.md`. These issues were deferred from an
earlier session and are now formally incorporated into this review pass.*

**Issue 19: `n_weighted` present only on `get_freqs()` — spec silent on why other 5 functions omit it**
Severity: REQUIRED
Violates engineering-preferences.md §5 (explicit over clever) — intentional asymmetry requires a stated rationale.

The spec includes `n_weighted = FALSE` in `get_freqs()` signature (Section 3.1) and documents
the `n_weighted` column in Section 3.2. The other five functions (`get_means()`, `get_totals()`,
`get_corr()`, `get_quantiles()`, `get_ratios()`) expose only unweighted `n`. No rationale is given
for the asymmetry.

AAPOR recommends reporting both weighted and unweighted n in published tables. The compliance
review flags this as "⚠️ Partial." An implementer following the spec will implement five
functions without `n_weighted`, not knowing whether this is a deliberate product decision or an
oversight. If deliberate, the spec should state why (e.g., "weighted n is less conventionally
reported for continuous-variable summaries"). If an oversight, `n_weighted = FALSE` must be added
to all six signatures, the cross-cutting arguments table in Section 2.6 updated, `n_weighted`
columns added to all output specs, and test categories extended.

The test gap compounds the ambiguity: Section 11.2 specifies `n_weighted = TRUE` tests for
`get_freqs()` but the equivalent test category is absent from all other function test plans.

Options:
- **[A]** Add `n_weighted = FALSE` as a cross-cutting argument to all six functions (parallel to
  `get_freqs()`). Add to Section 2.6 cross-cutting arguments table, add the `[n_weighted]` column
  to all six output column specs, add test categories to each function's test file.
  Effort: medium, Risk: low, Impact: AAPOR-consistent; uniform API.
- **[B]** Explicitly document in Section 2.6 that `n_weighted` is `get_freqs()`-only with stated
  rationale (weighted n is most useful for frequency tables; for continuous summaries, users can
  compute it from `meta(result)$n_respondents` and group weights). Update the AAPOR compliance
  review accordingly. Effort: low, Risk: low, Impact: documents the intentional inconsistency.
- **[C] Do nothing** — spec is silent; implementations will be inconsistent across functions.

**Recommendation: [B] if intentional, [A] if an oversight** — resolution depends on product intent.
The decision must be stated in the spec either way.

---

**Issue 20: Design Effect (DEFF) absent from Phase 1 — deferral not documented in spec**
Severity: SUGGESTION
Source: `plans/aapor-compliance-review.md §1`.

DEFF = Var(complex design) / Var(SRS equivalent) is an AAPOR reporting recommendation. The
compliance review notes: "Effort: Low — both SE values are already computed. The division is
trivial." The spec does not mention DEFF anywhere — not in the `variance` argument table
(Section 2.6), not in `meta()` (Section 2.4), not in the quality gates (Section XII).

The implementation path would be adding `"deff"` as a valid `variance` value. This requires
calling `.srs_mean()` (or equivalent) to get the SRS SE for comparison against the complex-design
SE. For `survey_srs`, DEFF is identically 1.0 by definition. For `survey_twophase`, the SRS
equivalent degf is non-trivial.

The compliance review deferred DEFF to a post-Phase-1 session but did not record that decision
back into the spec. The spec should state explicitly whether DEFF is Phase 1 or later.

Options:
- **[A]** Add `"deff"` as a valid `variance` value in Section 2.6. Define the formula:
  `deff = (se_complex / se_srs)²`. Add `deff` column to all six output column specs. Update
  `.validate_shared_args()`. Effort: medium, Risk: medium (`survey_twophase` SRS reference
  requires design-specific degf logic), Impact: AAPOR-compliant output.
- **[B]** Add DEFF to `meta(result)` only — always computed silently, accessible via
  `meta(result)$deff`. Avoids `variance` argument complexity. Effort: medium, Risk: low.
- **[C]** Add one sentence to Section 2.6 or Section XII noting that DEFF computation is deferred
  to Phase 2 and document the rationale (SRS reference requires per-design-class handling).
  Effort: trivial, Risk: none.
- **[D] Do nothing** — DEFF absent with no explanation; users and downstream reviewers discover
  the AAPOR compliance gap without guidance.

**Recommendation: [C]** — explicitly note the deferral with a one-line forward reference. This
closes the documentation gap without expanding Phase 1 scope.

---

**Issue 21: `surveycore_warning_small_cell` threshold undocumented relative to AAPOR standards**
Severity: SUGGESTION
Source: `plans/aapor-compliance-review.md §3`.

The spec defines `surveycore_warning_small_cell` in Section X: "Any cell has unweighted `n < 5`."
The AAPOR compliance review notes this as "⚠️ Partial":

> "AAPOR guidance (and many institutional standards) recommend suppressing cells where unweighted
> n falls below a threshold. Common thresholds: n < 5 (surveycore warning threshold), n < 30
> (AAPOR common guidance for public reporting), n < 50 (some federal agencies)."

The spec's n < 5 threshold is a surveycore convention, not an AAPOR standard. Users applying
AAPOR reporting requirements at n < 30 must manually filter the output — there is no built-in
support. The spec does not acknowledge this mismatch, leaving users to discover it independently.

The spec also does not address suppression (replacing small-n cells with `NA`). Whether this is
intentionally deferred or out of scope is not stated.

Options:
- **[A]** Add a `min_cell_n` cross-cutting argument (default `5`) controlling the warning
  threshold. Cells with `n < min_cell_n` fire `surveycore_warning_small_cell`.
  Effort: medium, Risk: low, Impact: configurable threshold.
- **[B]** Add a `suppress_n = NULL` argument: cells with `n < suppress_n` are replaced with `NA`
  in numeric output columns and a warning fires. Effort: medium, Risk: medium (NA cells can change
  column types in tibble), Impact: suppression support.
- **[C]** Add to the `surveycore_warning_small_cell` definition in Section X: a note documenting
  that the n < 5 threshold is a surveycore convention that is more permissive than the AAPOR
  n < 30 public-reporting guideline, and that users should filter on `n` to apply stricter
  thresholds. Suppression and configurable thresholds deferred to Phase 2. Effort: trivial.
- **[D] Do nothing** — threshold choice and AAPOR divergence go unacknowledged.

**Recommendation: [C]** — document the convention difference. Suppression and configurable
thresholds expand Phase 1 scope and can be addressed in Phase 2.

---

**Issue 22: AAPOR-compliant argument combination not documented anywhere in spec**
Severity: SUGGESTION
Source: `plans/aapor-compliance-review.md §Proposed aapor_format Argument`.

The AAPOR compliance review proposes an `aapor_format = TRUE` convenience argument that would
enforce: `variance = c("ci", "moe")`, `n_weighted = TRUE`, and raise `surveycore_warning_small_cell`
at n < 30 instead of n < 5. The review correctly concludes against adding the argument:

> "Better to document which combination of arguments produces AAPOR-compliant output, rather
> than encoding it as a flag."

Neither the compliance doc's conclusion nor the argument combination itself appears anywhere in the
Phase 1 spec. There is no `@details` note, no vignette reference, no `@seealso`. A user trying
to produce AAPOR-compliant output has no guidance from the spec or documentation.

Options:
- **[A]** Add to Section XII quality gates or the spec's documentation scope: a `@details` or
  vignette section documenting the argument combination for AAPOR-compliant output
  (`variance = c("ci", "moe")`, `n_weighted = TRUE` for `get_freqs()`). Reference
  `plans/aapor-compliance-review.md` as background. Effort: low.
- **[B]** Add `aapor_format = FALSE` to all six function signatures. Effort: medium, Risk: medium
  (AAPOR standards evolve; hardcoding creates maintenance burden as identified in compliance review).
- **[C] Do nothing** — AAPOR-compliant configuration is undiscoverable from the spec or docs.

**Recommendation: [A]** — the compliance review's conclusion (document don't encode) is correct.
Add the argument combination to spec documentation scope. No new argument needed.

---

## Summary

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 14 |
| SUGGESTION | 7 |

**Total issues:** 22

**Issues by section:**

| Issue | Section | Severity |
|---|---|---|
| 1: `value_labels` in "all functions" vs. absent from CORR/RATIOS_META_KEYS | 2.2, 2.4 | BLOCKING |
| 2: `test_result_invariants()` invariant #5 fails for `get_corr()` / `get_ratios()` | 11.2 | REQUIRED |
| 3: `S3method(print, survey_result) <-` is invalid R syntax | 2.5 | REQUIRED |
| 4: `.build_meta()` `design_type` mapping not specified | 2.2 | REQUIRED |
| 5: `.make_result_tibble()` `required_meta_keys` — required or optional? | 2.2 | REQUIRED |
| 6: `surveycore_error_all_na` scoped wrong in `error-messages.md` | X, error-messages.md | REQUIRED |
| 7: `surveycore_warning_corr_non_numeric` drop + < 2 vars interaction unspecified | 6.4, X | REQUIRED |
| 8: `get_quantiles()` column order contradicts Section 2.6; `[var]`/`[cv]` absent | 7.2 | REQUIRED |
| 9: `[var]`/`[cv]` absent from `get_means()` and `get_ratios()` column specs | 4.2, 8.2 | REQUIRED |
| 10: Stale `variance = "both"` reference | 6.2 | REQUIRED |
| 11: `get_corr()` column header and `variance = "se"` example contradictory | 6.2 | REQUIRED |
| 12: Wide format scope — `p_value`/`statistic`/`df`/`n` not addressed | 6.3 | REQUIRED |
| 13: `n_respondents` "always populated" but absent from `test_result_invariants()` | 11.2, 2.4 | REQUIRED |
| 14: Oracle test `get_corr(...)$se` without `variance = "se"` | 11.1 | REQUIRED |
| 15: Stale `R/06-variance-estimation.R` single-file references | I, 2.2, 3.5, 4.3, 5.3, 7.3 | SUGGESTION |
| 16: `get_freqs()` multi-var column ordering inconsistent; `[n_weighted]` absent | 3.4 | SUGGESTION |
| 17: `surveycore_warning_small_cell` — "cell" undefined for `get_corr()` | 6.2, X | SUGGESTION |
| 18: `n_respondents` scalar vs. per-group not specified | 2.4 | SUGGESTION |
| 19: `n_weighted` present only on `get_freqs()` — omission from other 5 functions unexplained | 2.6, 3.1, 4.1, 5.1, 6.1, 7.1, 8.1 | REQUIRED |
| 20: DEFF absent from Phase 1 — deferral not documented in spec | 2.6, XII | SUGGESTION |
| 21: `surveycore_warning_small_cell` threshold undocumented relative to AAPOR standards | X | SUGGESTION |
| 22: AAPOR-compliant argument combination not documented anywhere | XII | SUGGESTION |

**Overall assessment:** The spec has been significantly improved from the first review pass — all 26 prior issues were addressed. This third pass (incorporating AAPOR compliance gaps from `plans/aapor-compliance-review.md`) brings the total to 22 issues: 1 blocking, 14 required, 7 suggestions. The 4 new AAPOR-derived issues add 1 required (Issue 19: the unexplained `n_weighted` asymmetry) and 3 suggestions (DEFF deferral documentation, cell suppression documentation, and AAPOR argument combination documentation). The blocking issue (Issue 1) and most required issues from the prior pass remain unresolved. The AAPOR issues do not change the implementability threshold — once Issues 1–14 are resolved, the spec is implementable — but Issue 19 requires a product decision (intentional or oversight?) before the first PR that touches a non-`get_freqs()` function.
