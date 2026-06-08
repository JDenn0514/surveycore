# Test-spec — doc-fixes

---

## Reference oracle

- `survey` package (any CRAN version) — not needed for this pass; no
  numerical estimation behavior changes.
- No new numerical comparisons are introduced.

---

## Datasets

- `make_survey_data(seed = 42)` — synthetic data for design construction in
  error-path and edge-case tests.
- `nhanes_2017` — used only to verify that corrected examples run without
  error (examples pass in `devtools::run_examples()`).
- Inline tibbles / data frames — preferred for all targeted behavior tests
  where a full design is not needed.

---

## Per-function test plan

Tests are needed only for PR 1 (code bugs + new error classes). PR 2
(documentation-only) is verified by the profile gates only.

---

### `print.survey_t_test` (fix B1)

**Happy path — no label set:**
- Build a `survey_t_test` result via `get_t_test()` on a design where the
  `by` variable has no variable label in `@metadata@variable_labels`.
- Capture the printed header via `capture.output()` or
  `expect_output(print(result), ...)`.
- Assert: the header line contains the raw column name (e.g., `"sex"`) in the
  "By:" field, not an empty string or `NULL`.

**Happy path — label is set:**
- Same setup, but call `set_var_label(design, sex, "Sex of respondent")` first.
- Assert: the header "By:" field shows `"Sex of respondent"`.

**Invariants:** `test_invariants(design)` is the first assertion in every
block that constructs a survey design object.

---

### `print.survey_pairwise` (fix B2)

**Happy path — no label set:**
- Build a `survey_pairwise` result via `get_pairwise()` where the `by`
  variable has no label.
- Assert: "By:" field in the header shows the raw column name.

**Happy path — label is set:**
- Set a label, assert it appears in the "By:" header.

---

### `.glm_design_type_label()` (fix B4)

This internal helper is tested indirectly through `print.survey_glm_fit`.

**Happy path — survey_nonprob design:**
- Fit `survey_glm()` on a `survey_nonprob` design.
- Capture `print()` output.
- Assert: output contains `"Non-probability"`, not `"Calibrated"`.

**Happy path — survey_taylor design:**
- Fit on a `survey_taylor` design; assert output contains `"Taylor series"`.

---

### `confint.survey_glm_fit` (fix B5)

**Error path — bad `level` argument:**
```
expect_error(
  confint(fit, level = 1.5),
  class = "surveycore_error_invalid_conf_level"
)
expect_snapshot(error = TRUE, confint(fit, level = 1.5))
```
The snapshot must show `{.arg level}` (not `{.arg conf_level}`) in the error
message text.

Additional:
```
expect_error(confint(fit, level = 0),   class = "surveycore_error_invalid_conf_level")
expect_error(confint(fit, level = NA),  class = "surveycore_error_invalid_conf_level")
expect_error(confint(fit, level = "a"), class = "surveycore_error_invalid_conf_level")
```

---

### `update.survey_glm_fit` (fix B6)

**Error path — `@call` is NULL:**
Construct a `survey_glm_fit` object whose `@call` slot is `NULL` (simulate
a serialized fit). Verify the new error class is thrown.

```
expect_error(
  update(fit_no_call),
  class = "surveycore_error_update_no_call"
)
expect_snapshot(error = TRUE, update(fit_no_call))
```

The snapshot must NOT contain the string `"predict_no_fit"` — that class
belongs to the `fit_` slot, not the `@call` slot.

**Happy path:**
- Fit a model normally.
- `update(fit, . ~ . + age)` returns a new `survey_glm_fit` without error.

---

### `survey_collection` S7 validator — unnamed-surveys condition (fix D20 / E5)

**Error path — missing names:**
```
expect_error(
  survey_collection(surveys = list(design_a, design_b)),  # unnamed
  class = "surveycore_error_collection_unnamed"
)
```

**Error path — empty-string names:**
```
surv_list <- list("" = design_a, valid = design_b)
expect_error(
  survey_collection(surveys = surv_list),
  class = "surveycore_error_collection_unnamed"
)
```

**Error path — NA names:**
```
surv_list <- stats::setNames(list(design_a), NA_character_)
expect_error(
  survey_collection(surveys = surv_list),
  class = "surveycore_error_collection_unnamed"
)
```

**Regression — empty collection still uses old class:**
```
expect_error(
  survey_collection(surveys = list()),
  class = "surveycore_error_collection_empty"
)
```
The two conditions must use distinct classes after the fix.

Note: S7 validator errors are Layer 1 — `class=` check only, no snapshot.

---

### `remove_survey()` — invalid `name` type (fix D56 / E4)

**Error path — non-character `name`:**
```
expect_error(
  remove_survey(coll, name = 1L),
  class = "surveycore_error_invalid_name_type"
)
expect_snapshot(error = TRUE, remove_survey(coll, name = 1L))
```

Additional type checks:
```
expect_error(remove_survey(coll, name = TRUE),  class = "surveycore_error_invalid_name_type")
expect_error(remove_survey(coll, name = NULL),  class = "surveycore_error_invalid_name_type")
```

**Regression — non-survey_collection `x` still uses old class:**
```
expect_error(
  remove_survey(list(), name = "a"),
  class = "surveycore_error_not_survey_collection"
)
```

**Happy path:**
- `remove_survey(coll, name = "wave1")` returns a `survey_collection` with
  one fewer survey.

**Edge case — `name = NA_character_`:**
- Type check passes (it's character); name-lookup fails with
  `surveycore_error_collection_name_not_found`.

---

### `.svy_rep_var()` — all-replicates-NA (E2)

This function already raises `surveycore_error_all_replicates_na` in the
current code; only the error class registration in `plans/error-messages.md`
is missing. The existing test (if any) should be confirmed present. If
absent, add:

**Error path:**
```
expect_error(
  .svy_rep_var(
    thetas  = c(NA_real_, NA_real_, NA_real_),
    scale   = 1,
    rscales = c(1, 1, 1)
  ),
  class = "surveycore_error_all_replicates_na"
)
expect_snapshot(
  error = TRUE,
  .svy_rep_var(
    thetas  = c(NA_real_, NA_real_, NA_real_),
    scale   = 1,
    rscales = c(1, 1, 1)
  )
)
```

Note: `.svy_rep_var()` is internal. Test it directly if no indirect path
reaches the all-NA branch; otherwise test indirectly via `get_means()` on a
design where all replicates produce `NA`.

---

### `.vcov_pair_taylor()` — error class split (X6)

**Error path — `lonely.psu = "fail"`:**
```
expect_error(
  <call that triggers lonely PSU stratum with lonely.psu = "fail">,
  class = "surveycore_error_lonely_psu"
)
```

**Error path — unknown `lonely.psu` value:**
```
expect_error(
  <call with lonely.psu = "invalid_option">,
  class = "surveycore_error_lonely_psu_unknown_option"
)
expect_snapshot(
  error = TRUE,
  <call with lonely.psu = "invalid_option">
)
```

The two tests must use distinct classes — they must not both resolve to
`surveycore_error_lonely_psu`.

---

### `extract_sata()` — fill error class (D45)

**Error path — invalid `fill` for `extract_sata()`:**
```
expect_error(
  extract_sata(design, x, fill = "yes"),
  class = "surveycore_error_fill_not_logical"
)
expect_snapshot(error = TRUE, extract_sata(design, x, fill = "yes"))
```

```
expect_error(
  extract_sata(design, x, fill = 1L),
  class = "surveycore_error_fill_not_logical"
)
```

**Regression — `set_sata()` `sata` argument still uses old class:**
```
expect_error(
  set_sata(design, x, sata = "yes"),
  class = "surveycore_error_sata_not_logical"
)
```

The two error classes must remain distinct after the fix.

---

### Polychoric boundary warning threshold (fix B3)

**Boundary warning fires with correct threshold value:**
- Call `get_corr(design, c(ord_var1, ord_var2), method = "polychoric")` on a
  dataset where the estimated rho is close to +1 or -1 (within 1e-4).
- Capture the warning.
- Assert: the warning message text contains `"1e-4"` (or the numeric
  representation `0.0001`), not `"1e-6"`.

```
expect_warning(
  get_corr(design_with_boundary_pair, c(x, y), method = "polychoric"),
  class = "surveycore_warning_polychoric_boundary_rho"
)
```

Snapshot the warning message to lock in the `1e-4` text:
```
expect_snapshot(
  withCallingHandlers(
    get_corr(design_with_boundary_pair, c(x, y), method = "polychoric"),
    warning = function(w) {
      if (inherits(w, "surveycore_warning_polychoric_boundary_rho")) {
        cat(conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    }
  )
)
```

Note: constructing a design where rho is within 1e-4 of ±1 may require a
specifically crafted ordinal pair. Use a simple two-level factor pair with
near-perfect concordance.

---

## Test file placement

All PR 1 tests belong in the existing test files for the functions under test:

| Behavior | Test file |
|----------|-----------|
| B1 `print.survey_t_test` | `test-analysis-t-test.R` |
| B2 `print.survey_pairwise` | `test-analysis-t-test.R` |
| B3 boundary warning text | `test-analysis-corr-latent.R` or `test-analysis-corr.R` |
| B4 `.glm_design_type_label` | `test-glm-methods.R` |
| B5 `confint.survey_glm_fit` | `test-glm-methods.R` |
| B6 `update.survey_glm_fit` | `test-glm-methods.R` |
| D20/E5 collection unnamed | `test-survey-collection.R` |
| D56/E4 `remove_survey` type | `test-survey-collection.R` |
| E2 all-replicates-NA | `test-variance-replicate.R` |
| X6 `.vcov_pair_taylor` | `test-variance-taylor.R` |
| D45 `extract_sata` fill | `test-metadata-system.R` |

---

## Tolerances

No numerical estimation changes in this pass; standard tolerances apply if
any numerical test is incidentally run.

- Point estimates: 1e-10
- SE / variance: 1e-8
- CI bounds: 1e-6
- Deviations: none

---

## Profile gates

- [ ] devtools::document() clean (no tag warnings, NAMESPACE consistent)
- [ ] devtools::test() all pass
- [ ] devtools::run_examples() all pass (all NHANES examples use `wtmec2yr`;
      no `gss_2024` in examples; no `library(marginaleffects)` without use)
- [ ] R CMD check --as-cran (0 err, 0 warn, notes reviewed; at most 2
      pre-approved notes)
- [ ] pkgdown::build_site() clean
- [ ] covr::package_coverage() >= 95% (target 98%)
