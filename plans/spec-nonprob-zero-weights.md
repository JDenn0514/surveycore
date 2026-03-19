# Spec: Allow Zero Weights in `survey_nonprob`

**Version:** 0.3
**Date:** 2026-03-18
**Status:** Approved
**Branch identifier:** `nonprob-zero-weights`
**Related files:** `plans/spec-review-nonprob-zero-weights.md` (after review),
`plans/decisions-nonprob-zero-weights.md` (after resolve)

---

## Document Purpose

This document is the single source of truth for relaxing the `survey_nonprob`
S7 validator to allow zero weights. This is a prerequisite for surveywts
Change 2 (`adjust_nonresponse()` zero-weight nonrespondents). The surveywts
spec lives at `../surveywts/plans/spec-phase-0-fixes.md` §III.

This spec does NOT repeat rules defined in:
- `code-style.md` — formatting, pipe, error structure, S7 patterns
- `testing-standards.md` — `test_that()` scope, coverage targets, assertion patterns
- `testing-surveycore.md` — `test_invariants()`, layer 1 error testing

Those rules apply by reference.

---

## I. Scope

### Deliverables

| # | Change | Severity |
|---|--------|----------|
| 1 | Relax `survey_nonprob` validator condition 4: allow zero weights | High |
| 2 | Update `test_invariants()` for zero-weight `survey_nonprob` objects | Medium |
| 3 | Add new error class `surveycore_error_weights_negative` | Medium |

### Non-Deliverables

| Item | Reason |
|------|--------|
| `survey_taylor` validator changes | `survey_taylor` retains strict positivity (> 0) — zero weights are not meaningful for probability designs |
| `survey_replicate` validator changes | Same — replicate designs require positive weights |
| `as_survey_nonprob()` constructor changes | Constructor still requires positive weights at creation time; zeros only arise from post-construction operations (e.g., nonresponse adjustment) |
| Zero-weight filtering in analysis functions | Analysis functions already handle zero weights via the survey package delegation; no surveycore changes needed |

### Why This Change

S7 re-triggers the class validator on every property assignment via `@<-`.
When surveywts's `adjust_nonresponse()` sets nonrespondent weights to 0 on a
`survey_nonprob` object (`design@data[[wt_col]] <- new_weights`), the current
validator rejects the update because it enforces strict positivity. Relaxing
this validator is the minimal change that unblocks the surveywts workflow.

---

## II. Architecture

### Files Modified

| File | Change |
|------|--------|
| `R/core-classes.R` | Split `survey_nonprob` validator condition 4 into two checks |
| `tests/testthat/helper-test-data.R` | Update `test_invariants()` weight check for `survey_nonprob` |
| `tests/testthat/test-s7-classes.R` | Update/add validator tests for `survey_nonprob` |
| `plans/error-messages.md` | Add `surveycore_error_weights_negative` |

No new files. No deleted files.

---

## III. Change 1 — Relax `survey_nonprob` Validator Condition 4

### Current Behavior (`R/core-classes.R` lines 700–710)

Condition 4 rejects all non-NA weights that are zero **or** negative:

```r
n_bad <- sum(non_na <= 0)
if (n_bad > 0L) {
  cli::cli_abort(
    c(
      "x" = "Weight column {.field {weights_var}} has {n_bad} non-positive value(s).",
      "i" = "All non-NA weights must be strictly greater than 0.",
      "v" = "Remove or replace rows where {.field {weights_var}} is 0 or negative."
    ),
    class = "surveycore_error_weights_nonpositive"
  )
}
```

### New Behavior

Split condition 4 into two checks — 4a and 4b:

**Condition 4a — No negative weights:**

```r
n_neg <- sum(non_na < 0)
if (n_neg > 0L) {
  cli::cli_abort(
    c(
      "x" = "Weight column {.field {weights_var}} has {n_neg} negative value(s).",
      "i" = "All non-NA weights must be non-negative (>= 0).",
      "v" = "Remove or replace rows where {.field {weights_var}} is negative."
    ),
    class = "surveycore_error_weights_negative"
  )
}
```

**Condition 4b — At least one positive weight:**

```r
if (!any(non_na > 0)) {
  cli::cli_abort(
    c(
      "x" = "Weight column {.field {weights_var}} has no positive values.",
      "i" = "At least one non-NA weight must be greater than 0.",
      "v" = "Check that {.field {weights_var}} contains valid survey weights."
    ),
    class = "surveycore_error_weights_all_zero"
  )
}
```

### Rationale for Two Separate Checks

- **4a (negative)** uses a new class `surveycore_error_weights_negative` because
  the existing `surveycore_error_weights_nonpositive` name implies zero is also
  rejected. A distinct class name makes the relaxed semantics explicit and
  avoids confusion with `survey_taylor`'s validator, which retains the original
  `surveycore_error_weights_nonpositive` behavior.

- **4b (all zero)** reuses the existing `surveycore_error_weights_all_zero` class.
  Condition 3 handles the "all NA" case and uses the same class — but conditions
  3 and 4b are mutually exclusive (if condition 3 fires, condition 4b is never
  reached), so the shared class is unambiguous. **Note:** the message text
  intentionally differs between the three call sites that use this class:
  condition 3 says `"has no non-NA values"`, condition 4b says `"has no positive
  values"`, and `.validate_weights()` says `"are zero or missing"`. The class
  semantics are identical for programmatic `tryCatch(class=)` usage; only the
  human-readable text varies by context.

### What Does NOT Change

- **`survey_taylor` validator** (`R/core-classes.R` lines ~420–470): retains
  `surveycore_error_weights_nonpositive` with the `<= 0` check. Zero weights
  are not meaningful for probability survey designs.

- **`survey_replicate` validator**: retains strict positivity.

- **`as_survey_nonprob()` constructor** (`R/core-constructors.R`): the constructor
  calls `.validate_weights()` (`R/core-validators.R`, line ~135, `<= 0` check)
  which enforces strict positivity. **Do not modify `.validate_weights()`** —
  it is correct as-is. You should not create a `survey_nonprob` with zero
  weights. Zeros only arise from post-construction operations like nonresponse
  adjustment, which bypass the constructor and trigger only the S7 validator.

- **Conditions 1–3** of the `survey_nonprob` validator: unchanged.

---

## IV. Change 2 — Update `test_invariants()`

**Scope:** Update only the `survey_nonprob` branch of `test_invariants()`
(~line 287 in `helper-test-data.R`). The main branch (~line 359, used by
`survey_taylor`, `survey_replicate`, `survey_twophase`) retains strict `> 0`.
The two branches are separated by an early `return(invisible(design))` on
~line 301.

### Current Behavior (`tests/testthat/helper-test-data.R` line ~287, `survey_nonprob` branch only)

```r
testthat::expect_true(
  all(wt_col[!is.na(wt_col)] > 0),
  label = "weight column has all positive non-NA values"
)
```

### New Behavior

```r
testthat::expect_true(
  all(wt_col[!is.na(wt_col)] >= 0),
  label = "weight column has all non-negative non-NA values"
)
testthat::expect_true(
  any(wt_col[!is.na(wt_col)] > 0),
  label = "weight column has at least one positive non-NA value"
)
```

This mirrors the relaxed validator: non-negative (>= 0) with at least one
positive. Post-nonresponse test blocks will now pass the invariant check
while still catching invalid states (all-zero, negative).

---

## V. Error Table Changes

### New Error Class

| Class | Thrown by | Condition | Message Template |
|-------|-----------|-----------|------------------|
| `surveycore_error_weights_negative` | `survey_nonprob` validator (condition 4a) | Any non-NA weight is negative (< 0) | `"x" = "Weight column {.field {weights_var}} has {n_neg} negative value(s)."`, `"i" = "All non-NA weights must be non-negative (>= 0)."`, `"v" = "Remove or replace rows where {.field {weights_var}} is negative."` |

### Existing Class Reused

| Class | New usage |
|-------|-----------|
| `surveycore_error_weights_all_zero` | `survey_nonprob` validator condition 4b — all non-NA weights are zero (no positive values). Already used by condition 3 (all NA); conditions are mutually exclusive. |

### Existing Class Narrowed

| Class | Change |
|-------|--------|
| `surveycore_error_weights_nonpositive` | No longer thrown by `survey_nonprob` validator. Still thrown by `survey_taylor` and `survey_replicate` validators (unchanged). |

### Exact `plans/error-messages.md` Edits

1. **Row 33** (`surveycore_error_weights_nonpositive`): Update Function column from
   `S7 validator (survey_taylor)` to `S7 validator (survey_taylor, survey_replicate)`.
   Add note: "No longer thrown by `survey_nonprob` validator (see row 101,
   `surveycore_error_weights_negative`)."

2. **Row 10** (`surveycore_error_weights_all_zero`): Add note that this class is also
   thrown by the `survey_nonprob` validator condition 4b (all non-NA weights are zero,
   no positive values).

3. **Row 101** (new): Add `surveycore_error_weights_negative` — thrown by
   `survey_nonprob` validator (condition 4a), condition: any non-NA weight is negative
   (< 0), with full message template from §V above.

---

## VI. Testing

### Workflow path — post-construction weight assignment (in `test-s7-classes.R`)

This is the primary use case: `as_survey_nonprob()` creates a valid object with
positive weights, then `@data<-` assignment introduces zeros (simulating
surveywts `adjust_nonresponse()`). S7 re-triggers the validator on `@data<-`.

```r
test_that("survey_nonprob allows zero weights after post-construction assignment", {
  df <- data.frame(x = 1:5, w = c(1, 2, 3, 4, 5))
  obj <- as_survey_nonprob(df, weights = w)

  # Simulate surveywts adjust_nonresponse() setting zeros
  new_data <- obj@data
  new_data$w <- c(1, 0, 0, 4, 0)
  obj@data <- new_data  # This triggers S7 re-validation

  test_invariants(obj)
  expect_equal(sum(obj@data$w == 0), 3L)
})
```

### Validator tests — Layer 1 (raw constructor, in `test-s7-classes.R`)

These test the S7 validator directly. Use the raw `survey_nonprob()` constructor
with the **full `variables` list** (all keys present, per `code-style.md §2`).
Layer 1 tests use `class=` only — no snapshot (per `testing-surveycore.md`).

**Happy path — zero weights accepted:**

```r
test_that("survey_nonprob validator accepts zero weights with at least one positive", {
  df <- data.frame(x = 1:5, w = c(1, 0, 0, 2, 0))
  obj <- survey_nonprob(
    data = df,
    variables = list(
      weights        = "w",
      probs_provided = FALSE,
      ids            = NULL,
      strata         = NULL,
      fpc            = NULL,
      nest           = FALSE,
      visible_vars   = NULL
    )
  )
  test_invariants(obj)
  expect_s3_class(obj@data, "data.frame")
  expect_equal(sum(obj@data$w == 0), 3L)
})
```

**Error path — negative weights rejected (condition 4a):**

```r
test_that("survey_nonprob validator rejects negative weights", {
  df <- data.frame(x = 1:3, w = c(1, -0.5, 2))
  expect_error(
    survey_nonprob(
      data = df,
      variables = list(
        weights        = "w",
        probs_provided = FALSE,
        ids            = NULL,
        strata         = NULL,
        fpc            = NULL,
        nest           = FALSE,
        visible_vars   = NULL
      )
    ),
    class = "surveycore_error_weights_negative"
  )
})
```

**Error path — all-zero weights rejected (condition 4b):**

```r
test_that("survey_nonprob validator rejects all-zero weights", {
  df <- data.frame(x = 1:3, w = c(0, 0, 0))
  expect_error(
    survey_nonprob(
      data = df,
      variables = list(
        weights        = "w",
        probs_provided = FALSE,
        ids            = NULL,
        strata         = NULL,
        fpc            = NULL,
        nest           = FALSE,
        visible_vars   = NULL
      )
    ),
    class = "surveycore_error_weights_all_zero"
  )
})
```

**Edge cases:**

```r
test_that("survey_nonprob validator accepts single positive weight among zeros", {
  df <- data.frame(x = 1:5, w = c(0, 0, 0, 0, 0.001))
  obj <- survey_nonprob(
    data = df,
    variables = list(
      weights        = "w",
      probs_provided = FALSE,
      ids            = NULL,
      strata         = NULL,
      fpc            = NULL,
      nest           = FALSE,
      visible_vars   = NULL
    )
  )
  test_invariants(obj)
})

test_that("survey_nonprob validator accepts mix of zeros and NAs with one positive", {
  df <- data.frame(x = 1:4, w = c(0, NA, 1, 0))
  obj <- survey_nonprob(
    data = df,
    variables = list(
      weights        = "w",
      probs_provided = FALSE,
      ids            = NULL,
      strata         = NULL,
      fpc            = NULL,
      nest           = FALSE,
      visible_vars   = NULL
    )
  )
  test_invariants(obj)
})

test_that("survey_nonprob validator rejects mix of zeros and negatives", {
  df <- data.frame(x = 1:3, w = c(0, -1, 0))
  expect_error(
    survey_nonprob(
      data = df,
      variables = list(
        weights        = "w",
        probs_provided = FALSE,
        ids            = NULL,
        strata         = NULL,
        fpc            = NULL,
        nest           = FALSE,
        visible_vars   = NULL
      )
    ),
    class = "surveycore_error_weights_negative"
  )
})

test_that("survey_nonprob validator rejects all-zero weights with NAs", {
  df <- data.frame(x = 1:3, w = c(0, NA, 0))
  expect_error(
    survey_nonprob(
      data = df,
      variables = list(
        weights        = "w",
        probs_provided = FALSE,
        ids            = NULL,
        strata         = NULL,
        fpc            = NULL,
        nest           = FALSE,
        visible_vars   = NULL
      )
    ),
    class = "surveycore_error_weights_all_zero"
  )
})
```

### Existing Tests — Action Table

The following table lists all existing `survey_nonprob` weight validation tests
and the required action for each. Layer 1 = S7 validator (raw `survey_nonprob()`),
Layer 3 = constructor (`as_survey_nonprob()`).

| Line | File | Test Name | Layer | Current Class | Action |
|------|------|-----------|-------|---------------|--------|
| 748 | `test-s7-classes.R` | `survey_nonprob validator rejects non-numeric weight column` | 1 | `weights_not_numeric` | **Unchanged** |
| 1797 | `test-constructors.R` | `survey_nonprob validator rejects non-numeric weight column` | 1 | `weights_not_numeric` | **Delete** (duplicate of line 748) |
| 1816 | `test-constructors.R` | `survey_nonprob validator rejects all-NA weight column` | 1 | `weights_all_zero` | **Unchanged** |
| 1835 | `test-constructors.R` | `survey_nonprob validator rejects non-positive weight column` | 1 | `weights_nonpositive` | **Change class to `weights_negative`; rename test to `"survey_nonprob validator rejects negative weights"`** (input has negatives, not zeros; "non-positive" is no longer accurate) |
| 1672 | `test-constructors.R` | `as_survey_nonprob() rejects non-positive weights` | 3 | `weights_nonpositive` | **Unchanged** (`.validate_weights()` still rejects zeros; dual pattern retained) |
| 1936 | `test-constructors.R` | `as_survey_nonprob() rejects non-numeric weight column` | 3 | `weights_not_numeric` | **Unchanged** |

Key points:
- `survey_taylor` tests with `surveycore_error_weights_nonpositive` are **unchanged**
- Layer 3 constructor tests are **unchanged** — the constructor still rejects zeros
- Only one existing test changes class; one is deleted as a duplicate

### Snapshot Updates

No existing snapshots are affected by this change. The S7 validator tests
(Layer 1) use `class=` only — no snapshot. The Layer 3 constructor test at
line 1672 is unchanged (`.validate_weights()` still rejects zeros with the
same message). New validator tests also use `class=` only per Layer 1
convention.

### `test_invariants()` Verification

Add a test that `test_invariants()` itself works correctly with zero-weight
`survey_nonprob` objects. Uses the workflow path (create via constructor, then
mutate weights):

```r
test_that("test_invariants() passes for survey_nonprob with zero weights", {
  df <- data.frame(x = 1:5, w = c(1, 2, 3, 4, 5))
  obj <- as_survey_nonprob(df, weights = w)

  # Introduce zeros via @data<- (triggers S7 re-validation)
  new_data <- obj@data
  new_data$w <- c(1, 0, 0, 2, 0)
  obj@data <- new_data

  expect_no_error(test_invariants(obj))
})
```

---

## VII. Quality Gates

All of the following must be true before this spec is considered complete:

- [ ] `survey_nonprob` validator condition 4 split into 4a (negative) and 4b (all-zero)
- [ ] Zero weights accepted by `survey_nonprob` validator when at least one positive weight exists
- [ ] Negative weights rejected with `surveycore_error_weights_negative`
- [ ] All-zero weights (no positive) rejected with `surveycore_error_weights_all_zero`
- [ ] `survey_taylor` and `survey_replicate` validators unchanged (strict > 0)
- [ ] `test_invariants()` updated: `>= 0` with `any > 0` for `survey_nonprob` path
- [ ] `plans/error-messages.md` updated with `surveycore_error_weights_negative`
- [ ] All existing `survey_nonprob` weight tests updated for new error classes
- [ ] New happy-path and edge-case tests for zero-weight `survey_nonprob` objects
- [ ] `R CMD check`: 0 errors, 0 warnings, <=2 notes
- [ ] 98%+ line coverage maintained
- [ ] All snapshot files reviewed and approved

---

## VIII. Integration: surveycore <-> surveywts

### Dependency

surveywts `adjust_nonresponse()` (Change 2 in `../surveywts/plans/spec-phase-0-fixes.md`)
depends on this change. Specifically:

1. `adjust_nonresponse()` sets nonrespondent weights to 0 on `survey_nonprob` objects
2. S7 re-triggers the `survey_nonprob` validator on `@data<-` assignment
3. Without this relaxation, the validator rejects the zero weights

### Release Order

1. This surveycore change must land on `develop` first
2. surveywts pins `surveycore (>= current_version)` in DESCRIPTION
3. During development, surveywts uses `Remotes:` to point to surveycore's dev branch

### No Impact on Other surveycore Consumers

- `survey_taylor` and `survey_replicate` validators are untouched
- `as_survey_nonprob()` constructor still requires positive weights at creation time
- Analysis functions (`get_means()`, etc.) are unaffected — they delegate to
  the survey package which handles zero weights correctly
