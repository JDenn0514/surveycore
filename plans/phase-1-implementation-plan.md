# surveycore Phase 1 — Implementation Plan

**Version:** 1.0
**Date:** February 2026
**Status:** Ready for implementation
**Formal Specification:** `plans/phase-1-formal-specification.md` (v1.1, updated per 2026-02-22 review)
**Decisions Log:** `plans/claude-decisions-phase-1.md`

---

## How to Use This Document

The **formal specification** is authoritative for *what* to build and how it
behaves. This plan is authoritative for *how to organize the code*, the build
order, and the exact implementation decisions that go beyond the spec.

**Read before writing any code:**
1. `plans/phase-1-formal-specification.md` — behavioral contracts, API, output structure
2. `plans/claude-decisions-phase-1.md` — review decisions not yet incorporated into the spec
3. This file — file organization, PR sequence, constructor changes, and implementation notes

---

## Overview

Phase 1 adds six analysis functions to surveycore. Before any Phase 1 code is
written, two prerequisite PRs must be merged: a Phase 0 gap fix (the
`survey_srs` class) and the Phase 0.75 two-phase variance pre-work. Phase 1
proper is then seven PRs.

**Total PRs: 9** (2 prerequisites + 7 Phase 1)

### Supported Classes (All Six Functions)

All six Phase 1 functions dispatch on these five design classes:

| Class | Variance method |
|---|---|
| `survey_srs` | Standard SRS: `s²/n × (1-f)` |
| `survey_taylor` | Taylor series linearization |
| `survey_replicate` | Replicate weights formula |
| `survey_calibrated` | Weighted SRS approximation (conservative) |
| `survey_twophase` | Two-phase linearization (requires Phase 0.75 first) |

---

## Prerequisites

### Prereq PR 1 — `fix/survey-srs-class`

**Must merge before any Phase 1 PR.**

#### What it delivers

A new `survey_srs` S7 class for equal-probability simple random samples, and
an update to `as_survey()` so that calling it with no design arguments creates
a `survey_srs` instead of a `survey_taylor`.

#### Class definition (`R/00-s7-classes.R`)

Add `survey_srs` as a subclass of `survey_base` before `survey_calibrated`.
Include in the file header comment. Update the `survey_base` roxygen to list
all five subclasses.

`@variables` keys for `survey_srs`:

| Key | Type | Description |
|---|---|---|
| `weights` | `character(1)` or `NULL` | Weight column name; `NULL` means auto-uniform |
| `probs_provided` | `logical(1)` | Always `FALSE` for SRS (equal probability) |
| `fpc` | `character(1)` or `NULL` | FPC column name; `NULL` = infinite population |

No `ids`, `strata`, `nest` keys — not applicable to simple random samples.

Validator checks (Layer 1):
- Weight column exists in `@data` if specified
- Weight column is numeric if present
- All non-NA weights are positive
- FPC column exists in `@data` if specified

#### Constructor change (`R/03-constructors.R`)

The `as_survey()` dispatch rule after all validation:

```r
# Class selection rule (after all Layer 3 validation passes):
no_design_structure <- is.null(ids_var) &&
                       is.null(weights_var) &&
                       is.null(probs_var) &&
                       is.null(strata_var)

if (no_design_structure) {
  # Equal-probability SRS — fpc may still be specified
  survey_srs(data = data, metadata = metadata, variables = variables, call = call)
} else {
  survey_taylor(data = data, metadata = metadata, variables = variables, call = call)
}
```

The `variables` list for `survey_srs` omits `ids`, `strata`, and `nest`. Use
only `weights`, `probs_provided`, and `fpc`. The auto-weight column
(`..surveycore_wt..`) is still generated when `weights = NULL` and warning 7
still fires.

`@variables` all-keys-present rule: for `survey_srs`, the required keys are
`weights`, `probs_provided`, `fpc` — these must always be present (never
absent), with `NULL` for unspecified values.

#### Constructor path summary

| Call | Creates | Notes |
|---|---|---|
| `as_survey(df)` | `survey_srs` | Auto-weights (`..surveycore_wt..`), warning 7 fires |
| `as_survey(df, fpc = N)` | `survey_srs` | SRS with finite population correction |
| `as_survey(df, weights = w)` | `survey_taylor` | Unequal-prob weights, no design structure |
| `as_survey(df, ids = p, weights = w, strata = s)` | `survey_taylor` | Full complex design |

#### Test infrastructure (`tests/testthat/helper-test-data.R`)

Add a `survey_srs` branch to `test_invariants()`. The existing code checks
`survey_calibrated` first (early return), then runs general logic that reads
`@variables$ids`, `@variables$strata`, etc. `survey_srs` also lacks those
keys, so it needs its own branch:

```r
if (S7::S7_inherits(design, survey_srs)) {
  # srs-specific invariants: weights, fpc (no ids/strata/nest)
  testthat::expect_true(is.data.frame(design@data))
  testthat::expect_gte(nrow(design@data), 1L)
  testthat::expect_true(
    all(c("weights", "probs_provided", "fpc") %in% names(design@variables))
  )
  wt_var <- design@variables$weights
  if (!is.null(wt_var)) {
    testthat::expect_true(wt_var %in% names(design@data))
    wt_col <- design@data[[wt_var]]
    testthat::expect_true(is.numeric(wt_col))
    testthat::expect_true(all(wt_col[!is.na(wt_col)] > 0))
  }
  testthat::expect_true(S7::S7_inherits(design@metadata, survey_metadata))
  return(invisible(design))
}
```

Add `survey_srs` to `make_all_designs()`:

```r
df_s <- make_survey_data(n = 100L, n_psu = 10L, n_strata = 2L,
                          design = "taylor", seed = seed)
srs  <- as_survey(df_s)   # creates survey_srs via no-args path
```

Return list becomes: `list(srs = srs, taylor = taylor, replicate = replicate, twophase = twophase, calibrated = calibrated)`.

#### Tests

- `test-s7-classes.R`: add happy-path + validator tests for `survey_srs`
- `test-constructors.R`:
  - `as_survey(df)` creates `survey_srs` (not `survey_taylor`)
  - `as_survey(df, weights = w)` still creates `survey_taylor`
  - `as_survey(df, fpc = N)` creates `survey_srs`
  - SRS warning (warning 7) still fires
  - `test_invariants()` passes on a `survey_srs` object

#### Acceptance criteria

- `devtools::check()` 0/0/0
- All existing tests still pass (no regressions)
- `as_survey(df)` creates `survey_srs`
- `test_invariants()` handles `survey_srs` correctly

---

### Prereq PR 2 — `feature/variance-twophase` (Phase 0.75)

**Must merge before Phase 1 functions dispatch on `survey_twophase`.**
See `plans/phase-0.75-twophase-variance.md` for the full plan.

**Summary:** Vendor two-phase variance functions from the survey package into
`R/06-variance-estimation.R`. Update the Phase 0 `get_means()` and
`get_totals()` stubs to dispatch on `survey_twophase`. Add oracle tests.
Update `VENDORED.md`.

---

## Phase 1 PR Sequence

All Phase 1 PRs depend on Prereq PR 1 and Prereq PR 2 being merged. PRs 2–5
can be developed in parallel once PR 1 is merged.

```
Prereq PR 1 (survey_srs)
Prereq PR 2 (two-phase variance)
     │
     └── Phase 1 PR 1: meta generic + shared helpers
              │
              ├── Phase 1 PR 2: get_freqs()
              ├── Phase 1 PR 3: get_means() + get_totals() (+ stub removal)
              ├── Phase 1 PR 4: get_corr()
              └── Phase 1 PR 5: get_quantiles() + get_ratios()
```

---

### Phase 1 PR 1 — `feature/phase1-meta-helpers`

#### Files

| File | Action |
|---|---|
| `R/09-meta.R` | Create |
| `R/09-analysis-helpers.R` | Create |
| `tests/testthat/helper-test-data.R` | Extend (add `test_result_invariants()`) |
| `tests/testthat/test-analysis-helpers.R` | Create |

#### `R/09-meta.R`

```r
#' Extract metadata from a survey result
#' @export
meta <- function(x, ...) UseMethod("meta")

#' @export
meta.survey_result <- function(x, ...) attr(x, ".meta")
```

`meta()` is the only public way to access result metadata. Direct `attr()`
access is not part of the public API.

#### `R/09-analysis-helpers.R` contents

**1. Meta-key constants** (at the top of the file, not exported):

```r
FREQS_SINGLE_META_KEYS <- c(
  "mode", "variable", "variable_label", "question_preface", "value_labels"
)
FREQS_MULTI_META_KEYS <- c(
  "mode", "variables", "variable_labels", "question_prefaces", "value_labels"
)
MEANS_META_KEYS <- c(
  "variable", "variable_label", "question_preface", "value_labels"
)
TOTALS_META_KEYS <- c(
  "variable", "variable_label", "question_preface", "value_labels"
)
CORR_META_KEYS <- c(
  "variables", "variable_labels", "question_prefaces", "method"
)
QUANTILES_META_KEYS <- c(
  "variable", "variable_label", "question_preface", "value_labels", "probs"
)
RATIOS_META_KEYS <- c(
  "numerator", "numerator_label", "denominator", "denominator_label",
  "question_prefaces"
)
```

**2. `.resolve_groups(design, group_expr)`** — as specified in Phase 1 spec
Section 2.2.

**3. `.apply_domain(design)`** — as specified in Section 2.2. Returns logical
vector; if no domain column present, returns `rep(TRUE, nrow(design@data))`.

**4. `.make_result_tibble(col_vecs, groups_df, class_name, design, meta_args, required_meta_keys)`**

Column-by-column accumulation pattern. `col_vecs` is a named list of
already-assembled vectors (one per output column). Validates
`meta_args` keys against `required_meta_keys` with `stopifnot()`. Assembles
via `tibble::tibble()`. Attaches `.meta` attribute and sets class.

```r
.make_result_tibble <- function(
  col_vecs,          # named list of vectors; one per result column
  groups_df,         # data.frame of group columns (may have 0 rows when no groups)
  class_name,        # e.g. "survey_means"
  design,
  meta_args,
  required_meta_keys
) {
  stopifnot(all(required_meta_keys %in% names(meta_args)))
  result <- tibble::as_tibble(c(as.list(groups_df), col_vecs))
  attr(result, ".meta") <- .build_meta(design, meta_args)
  class(result) <- c(class_name, "survey_result", "tbl_df", "tbl", "data.frame")
  result
}
```

**5. `.build_meta(design, meta_args)`** — as specified in Section 2.2.
Determines `design_type` from class membership:

```r
design_type <- if (S7::S7_inherits(design, survey_taylor))    "taylor"
          else if (S7::S7_inherits(design, survey_replicate))  "replicate"
          else if (S7::S7_inherits(design, survey_twophase))   "twophase"
          else if (S7::S7_inherits(design, survey_srs))        "srs"
          else if (S7::S7_inherits(design, survey_calibrated)) "calibrated"
          else "unknown"
```

**6. `.validate_shared_args(variance, conf_level, name_style, valid_variance, call)`**

`variance` is now a character vector. Validation:

```r
.validate_shared_args <- function(
  variance,
  conf_level,
  name_style,
  valid_variance = c("se", "ci", "var", "cv", "moe"),
  call = rlang::caller_env()
) {
  if (!is.null(variance)) {
    bad_vals <- setdiff(variance, valid_variance)
    if (length(bad_vals) > 0L) {
      cli::cli_abort(
        c(
          "x" = "{.arg variance} values must be from {.or {.val {valid_variance}}}.",
          "i" = "Unknown value{?s}: {.val {bad_vals}}."
        ),
        class = "surveycore_error_invalid_variance_arg",
        call  = call
      )
    }
  }
  if (!is.numeric(conf_level) || length(conf_level) != 1L ||
      conf_level <= 0 || conf_level >= 1) {
    cli::cli_abort(
      c(
        "x" = "{.arg conf_level} must be a single number strictly between 0 and 1.",
        "i" = "Got {.val {conf_level}}."
      ),
      class = "surveycore_error_invalid_conf_level",
      call  = call
    )
  }
  if (!name_style %in% c("surveycore", "broom")) {
    cli::cli_abort(
      c(
        "x" = '{.arg name_style} must be {.val "surveycore"} or {.val "broom"}.',
        "i" = "Got {.val {name_style}}."
      ),
      class = "surveycore_error_invalid_name_style",
      call  = call
    )
  }
  invisible(TRUE)
}
```

**7. `.apply_name_style(result, name_style)`** — renames columns for
`name_style = "broom"`. Full mapping in spec Section 2.2. Since `variance`
is now a vector and result may have any subset of `se`, `var`, `cv`,
`ci_low`, `ci_high`, `moe`, only rename columns that are present.

**8. `.check_unsupported_class(design, fn_name)`** — internal helper to
throw `surveycore_error_unsupported_class` consistently:

```r
.check_unsupported_class <- function(design, fn_name) {
  if (!S7::S7_inherits(design, survey_base)) {
    cli::cli_abort(
      c(
        "x" = "{.fn {fn_name}} requires a survey design object.",
        "i" = "Got {.cls {class(design)[[1]]}}."
      ),
      class = "surveycore_error_unsupported_class"
    )
  }
  # survey_twophase support requires Phase 0.75
  if (S7::S7_inherits(design, survey_twophase)) {
    cli::cli_abort(
      c(
        "x" = "{.fn {fn_name}} does not yet support {.cls survey_twophase}.",
        "i" = "Two-phase variance estimation requires Phase 0.75 to be complete."
      ),
      class = "surveycore_error_unsupported_class"
    )
  }
}
```

**9. `.add_variance_cols(result_vecs, se_vec, estimate_vec, conf_level, degf, variance)`**

Shared helper that, given a vector of SEs and the `variance` argument,
computes and returns the requested uncertainty column vectors. Called by
each `get_*()` function after computing the point estimate and SE.

```r
# Returns a named list of vectors (only the requested ones)
# se_vec       : numeric vector of standard errors
# estimate_vec : numeric vector of point estimates (for cv)
# conf_level   : numeric scalar
# degf         : degrees of freedom (scalar or vector)
# variance     : character vector e.g. c("se", "ci")
```

For `"cv"`: `cv = se / estimate * 100`. When `estimate` is 0 or negative,
set `cv = NA` for that cell and fire `surveycore_warning_cv_undefined` if
any cells are affected.

Column ordering when multiple present: `se`, `var`, `cv`, `ci_low`, `ci_high`, `moe`.

**10. `.degf(design)`** — returns design degrees of freedom as a scalar:

```r
.degf <- function(design) {
  if (S7::S7_inherits(design, survey_taylor)) {
    # sum(PSUs per stratum) - number of strata
    # computed from design@data using ids and strata variables
    ...
  } else if (S7::S7_inherits(design, survey_replicate)) {
    length(design@variables$repweights) - 1L
  } else if (S7::S7_inherits(design, survey_srs)) {
    nrow(design@data) - 1L   # n - 1 for SRS
  } else if (S7::S7_inherits(design, survey_calibrated)) {
    nrow(design@data) - 1L   # n - 1 (conservative)
  }
}
```

#### `test_result_invariants()` in `helper-test-data.R`

```r
test_result_invariants <- function(result, expected_class) {
  testthat::expect_true(inherits(result, expected_class))
  testthat::expect_true(inherits(result, "survey_result"))
  testthat::expect_true(tibble::is_tibble(result))
  m <- meta(result)
  testthat::expect_false(is.null(m))
  testthat::expect_type(m, "list")
  testthat::expect_true(all(
    c("design_type", "conf_level", "call", "group_names", "group_labels")
    %in% names(m)
  ))
  testthat::expect_type(m$group_names, "character")
  testthat::expect_true("value_labels" %in% names(m))
  testthat::expect_type(m$value_labels, "list")
  testthat::expect_gt(length(m$value_labels), 0L)
  testthat::expect_false(is.null(names(m$value_labels)))
  invisible(result)
}
```

#### `test-analysis-helpers.R` test categories

1. `.validate_shared_args()` — all three errors (`invalid_variance_arg`,
   `invalid_conf_level`, `invalid_name_style`); `variance` as vector accepted;
   unknown values rejected
2. `.resolve_groups()` — `@groups` only; `group=` only; both combined (AND);
   deduplication; empty result
3. `.apply_domain()` — domain column present; absent (all TRUE)
4. `.make_result_tibble()` — correct class hierarchy; `.meta` attached;
   `stopifnot()` fires on missing required keys
5. `.build_meta()` — all five design types; all `design_type` values correct
6. `.add_variance_cols()` — each variance option; `"cv"` NA + warning for
   zero estimates; column ordering
7. `.apply_name_style()` — broom rename for each column that exists;
   no-op for surveycore
8. `.degf()` — correct df for taylor, replicate, srs, calibrated

---

### Phase 1 PR 2 — `feature/phase1-freqs`

#### Files

| File | Action |
|---|---|
| `R/10-analysis-freqs.R` | Create |
| `tests/testthat/test-analysis-freqs.R` | Create |

#### Signature

```r
get_freqs(
  design,
  x,
  ...,
  group        = NULL,
  names_to     = "name",
  values_to    = "value",
  variance     = NULL,           # NULL or character vector: "se","ci","var","cv","moe"
  conf_level   = 0.95,
  n_weighted   = FALSE,
  na.rm        = TRUE,
  label_values = TRUE,
  label_vars   = TRUE,
  name_style   = "surveycore"
)
```

#### Key implementation notes

**Dispatch order** (check at the start of the function):

```r
.check_unsupported_class(design, "get_freqs")  # throws for non-survey or twophase
```

**Single vs. multi-var mode:** Resolve `x` with `.resolve_tidy_select()`.
If length 1 → single-var mode. If length ≥ 2 → multi-var mode.

**NA handling:**
- `na.rm = TRUE` (default): exclude NA rows; `n` counts non-NA rows
- `na.rm = FALSE`: NA appears as its own level, last row; denominator includes
  NA count so column sums to 100%
- All NA + `na.rm = TRUE` → return 0-row tibble, fire
  `surveycore_warning_all_na_freqs`
- All NA + `na.rm = FALSE` → throw `surveycore_error_all_na`

**Proportion computation:** Use the Taylor/replicate/SRS/calibrated variance
machinery from `R/06-variance-estimation.R`. For each level of the variable,
compute `svymean()` on a 0/1 indicator. `pct = proportion × 100`; all
variance quantities are on the percentage scale.

**NA in group variable:** Rows where the group variable is `NA` are excluded
from all groups before computing. Do not add an NA group row.

**`label_values`:** Apply value labels from `design@metadata@value_labels`
to the focal variable's level column. Fall back to raw values if no labels.
For group columns: also apply group variable labels if present.

**`label_vars`:** In multi-var mode, the `names_to` column shows variable
labels when `label_vars = TRUE`. Fall back to raw variable name if no label.

**`surveycore_warning_mixed_prefaces`:** In multi-var mode, check whether
the focal variables have different non-NULL question prefaces. If so, fire
the warning (function still returns a result).

**`meta_args`:** Use `FREQS_SINGLE_META_KEYS` or `FREQS_MULTI_META_KEYS`
depending on mode.

**`survey_srs`** — uses SRS variance for proportions (exact formula).
**`survey_calibrated`** — uses weighted SRS approximation.

#### Test categories (see spec Section 11.2 for full list)

All 12 categories from the spec, plus:
- `surveycore_warning_all_na_freqs` fires for all-NA + `na.rm = TRUE`
- NA in group variable edge case (those rows excluded)
- 3-way combination test: `filter()` + `group_by()` simultaneously
  (`skip_if_not_installed("surveytidy")`)
- All five supported classes
- `survey_twophase` throws `surveycore_error_unsupported_class`

---

### Phase 1 PR 3 — `feature/phase1-means-totals`

**This PR atomically removes the Phase 0 stubs.** CI must be green before
merging. Do not remove stubs in one commit and fix tests in a follow-up.

#### Files

| File | Action |
|---|---|
| `R/11-analysis-means.R` | Create |
| `R/06-variance-estimation.R` | Remove stubs for `get_means()` / `get_totals()` |
| `tests/testthat/test-analysis-means.R` | Create |
| `tests/testthat/test-analysis-totals.R` | Create |
| `tests/testthat/test-variance-estimation.R` | Expand (oracle tests updated to Phase 1 output structure) |

#### `get_means()` notes

**Signature:**
```r
get_means(design, x, group = NULL, variance = "ci", conf_level = 0.95,
          na.rm = TRUE, label_values = TRUE, label_vars = TRUE,
          name_style = "surveycore")
```

**`x` must resolve to a single numeric column.** Throw
`surveycore_error_non_numeric_variable` if not numeric.

**SRS variance:** `.srs_mean()` — uses `(1 - f) * s²/n` where
`f = n/N` from FPC column if present, else `f = 0`.

**Calibrated variance:** `.calibrated_mean()` — weighted SRS:
`Var(ȳ_w) = Σwᵢ²(yᵢ - ȳ_w)² / (Σwᵢ)²`.

**Output:** Variable name NOT a column — in `meta(result)$variable` only.

**`meta_args`:** Use `MEANS_META_KEYS`.

#### `get_totals()` notes

**Signature:**
```r
get_totals(design, x = NULL, group = NULL, variance = "ci", conf_level = 0.95,
           na.rm = TRUE, label_values = TRUE, label_vars = TRUE,
           name_style = "surveycore")
```

**Two modes:**
- `x = NULL` → population size (`Σwᵢ`); `n` column omitted from output
- `x = var` → weighted sum (`Σwᵢ × varᵢ`); `n` present

`n` is bracketed (`[n]`) — conditional on whether `x` is provided.

**SRS variance:** For no-variable mode, `Var(N̂) = N² × (1-f) × s²/n` where
`s²` is the variance of the weights. For variable mode, uses SRS total
variance formula.

**`meta_args`:** Use `TOTALS_META_KEYS`.

#### Stub migration in `R/06-variance-estimation.R`

The current Phase 0 stubs:
```r
get_means <- function(design, var) { ... }
get_totals <- function(design, var) { ... }
```

Remove both completely. The Phase 1 implementations live in
`R/11-analysis-means.R` and are exported there.

#### Oracle test update in `test-variance-estimation.R`

The existing oracle tests use `sc_est$mean` and `sc_est$se`. Expand to
also check `sc_est$ci_low`, `sc_est$ci_high` (since `variance = "ci"` is
the new default). The point estimate and SE checks remain with the same
tolerances. Example pattern:

```r
expect_equal(sc_est$mean,    coef(sv_est),    tolerance = 1e-10)
expect_equal(sc_est$se,      SE(sv_est),      tolerance = 1e-8)
expect_equal(sc_est$ci_low,  confint(sv_est)[1], tolerance = 1e-6)
expect_equal(sc_est$ci_high, confint(sv_est)[2], tolerance = 1e-6)
```

Note: `survey::SE()` returns a 1×1 matrix in survey ≥ 4.4 — use
`as.numeric(survey::SE(x))` not `survey::SE(x)[["varname"]]`.

---

### Phase 1 PR 4 — `feature/phase1-corr`

#### Files

| File | Action |
|---|---|
| `R/12-analysis-corr.R` | Create |
| `R/06-variance-estimation.R` | Add variance-covariance machinery |
| `tests/testthat/test-analysis-corr.R` | Create |

#### Signature

```r
get_corr(
  design,
  x,
  format       = c("long", "wide"),
  redundant    = FALSE,
  diagonal     = FALSE,
  variance     = "ci",   # NULL or character vector: "se","ci","var","cv","moe"
  conf_level   = 0.95,
  na.rm        = TRUE,
  label_values = TRUE,
  label_vars   = TRUE,
  name_style   = "surveycore"
)
```

Note: `"both"` has been removed. Use `variance = c("se", "ci")` to get both.

#### Implementation — variance-covariance approach

**DO NOT use the Fisher Z SRS formula for variance.** That formula is
educational context only. The actual implementation uses the design-based
variance-covariance approach:

```
r(X, Y) = Cov(X, Y) / sqrt(Var(X) × Var(Y))
```

The SE of `r` is derived using the delta method applied to the joint variance
of `(Var(X), Cov(X,Y), Var(Y))` from the survey design's linearization or
replicate machinery.

This requires adding `.vcov_mean()` (or equivalent) to
`R/06-variance-estimation.R` — a function that returns the full variance-
covariance matrix for a set of variable means, using the same vendored
`.svy_recvar()` / replicate machinery already present.

For `survey_srs` and `survey_calibrated`, the covariance uses the weighted
SRS covariance formula.

**Before implementing**, study how `survey::svyvar()` computes the
variance-covariance matrix. The relevant functions in the survey package
source are in `survey/R/surveysummary.R`. Vendor what is needed.

#### Oracle: `survey::svyvar()`

```r
sv   <- survey::svyvar(~ c(x, y), d_sv)
r_oracle <- sv[1, 2] / sqrt(sv[1, 1] * sv[2, 2])
```

SE from delta method applied to `vcov(sv)`. Oracle tolerance: `r` within
`1e-10`, SE within `1e-8`. Works for Taylor and replicate designs.

#### `get_corr()` specific behavior

- Non-numeric variables in `x` → drop silently, fire
  `surveycore_warning_corr_non_numeric`
- After dropping: if fewer than 2 remain → throw
  `surveycore_error_insufficient_variables`
- `redundant = FALSE` (default): lower triangle only (i < j pairs)
- `diagonal = FALSE` (default): self-correlations excluded
- Wide format: `r` values only; no variance columns in wide format
- `label_vars = TRUE`: `var1`/`var2` cells (long) and `variable` column
  (wide) use variable labels when set
- Pairwise `n`: may differ across pairs when `na.rm = TRUE` (variable-
  specific missing data)
- `statistic` and `df` always present in long format (not optional)

**`meta_args`:** Use `CORR_META_KEYS`.

#### `"cv"` for correlations

CV = `se_r / r * 100`. When `r ≈ 0`, CV is extremely large or undefined.
`surveycore_warning_cv_undefined` fires; affected cells get `cv = NA`.

---

### Phase 1 PR 5 — `feature/phase1-quantiles-ratios`

#### Files

| File | Action |
|---|---|
| `R/13-analysis-quantiles.R` | Create (`get_quantiles()` + `get_ratios()`) |
| `R/06-variance-estimation.R` | Add Woodruff quantile variance |
| `tests/testthat/test-analysis-quantiles.R` | Create |
| `tests/testthat/test-analysis-ratios.R` | Create |

#### `get_quantiles()` notes

**Signature:**
```r
get_quantiles(design, x, probs = c(0.25, 0.5, 0.75), group = NULL,
              variance = "ci", conf_level = 0.95, na.rm = TRUE,
              label_values = TRUE, label_vars = TRUE, name_style = "surveycore")
```

**Validate `probs`:** All values must be in (0, 1), length ≥ 1. Throw
`surveycore_error_invalid_probs` otherwise.

**Quantile labels:** 0.25 → `"p25"`, 0.5 → `"p50"`, 0.333 → `"p33"`.
Formula: `paste0("p", round(probs * 100))`.

**Variance — Woodruff's method:** Vendor the relevant internals from
`survey::svyquantile()`. Before implementing, read
`survey/R/svyquantile.R` and identify `wtd.quantile()` and the CDF
linearization helpers. Add GPL attribution as with existing vendored code.

Add `.srs_quantile()` for `survey_srs` — uses the unweighted sample
quantile with SRS variance (Woodruff adapted for SRS).

**`meta_args`:** Use `QUANTILES_META_KEYS` (includes `probs`).

#### `get_ratios()` notes

**Signature:**
```r
get_ratios(design, numerator, denominator, group = NULL, variance = "ci",
           conf_level = 0.95, na.rm = TRUE, label_values = TRUE,
           label_vars = TRUE, name_style = "surveycore")
```

**Validate denominator:** All denominator values zero → throw
`surveycore_error_ratio_zero_denominator`.

**Variance — delta method:**
```
ratio = Σ(wᵢ × yᵢ) / Σ(wᵢ × xᵢ)
```
Linearized as `yᵢ - ratio × xᵢ`. SE is then the SE of the mean of this
linearized variable, using the design's variance machinery.

This is equivalent to `survey::svyratio()`. Oracle tolerance: ratio within
`1e-10`, SE within `1e-8`.

`n`: count of rows where both numerator AND denominator are non-NA.

Numerator and denominator variable names stored in `meta(result)$numerator`
and `meta(result)$denominator` — not output columns.

**`meta_args`:** Use `RATIOS_META_KEYS`.

---

## Cross-Cutting Implementation Details

These decisions apply to every `get_*()` function. Implement them
consistently — do not vary behavior between functions.

### 1. `variance` argument (character vector)

Every `get_*()` function accepts `variance` as `NULL` or a character
vector of any subset of `c("se", "ci", "var", "cv", "moe")`.

```r
# Valid calls:
get_means(d, x)                               # uses default "ci"
get_means(d, x, variance = NULL)              # no uncertainty columns
get_means(d, x, variance = "se")             # only se
get_means(d, x, variance = c("se", "ci"))    # se, ci_low, ci_high
get_means(d, x, variance = c("se", "ci", "moe"))  # all three
```

Computation order in `.add_variance_cols()`:
1. Always compute SE first (needed for all derived quantities)
2. `var` = `se²`
3. `cv` = `se / estimate * 100`; `NA` + warning when estimate ≤ 0
4. `ci_low`, `ci_high` = `estimate ± qt((1+conf_level)/2, degf) × se`
5. `moe` = `(ci_high - ci_low) / 2`

Column ordering in output (only add columns that are requested):
`se`, `var`, `cv`, `ci_low`, `ci_high`, `moe`

### 2. Class dispatch pattern

Every `get_*()` function dispatches to class-specific variance functions.
Use `S7::S7_inherits()` for all checks. Pattern:

```r
if      (S7::S7_inherits(design, survey_taylor))     .taylor_*(design, ...)
else if (S7::S7_inherits(design, survey_replicate))  .replicate_*(design, ...)
else if (S7::S7_inherits(design, survey_twophase))   .twophase_*(design, ...)
else if (S7::S7_inherits(design, survey_srs))        .srs_*(design, ...)
else if (S7::S7_inherits(design, survey_calibrated)) .calibrated_*(design, ...)
```

Call `.check_unsupported_class(design, fn_name)` at the very start of each
`get_*()` function (before any tidy-select resolution or validation). This
throws immediately for non-survey objects. The `survey_twophase` check is
also inside `.check_unsupported_class()` so the error is consistent.

### 3. NA in group variables

NA values in grouping variables (from `group =` or `@groups`) are excluded
from all groups before computing. They do not appear in the output and are
not counted in `n`. This is the same behavior as `dplyr::group_by()`.

Implementation: after resolving groups, use
`complete.cases(design@data[, group_vars, drop = FALSE])` to build a logical
mask; apply it together with the domain mask before splitting by groups.

Document in every `@param group`:
> Rows where the grouping variable is `NA` are excluded from all groups and
> do not appear in the output. This matches `dplyr::group_by()` semantics.

### 4. Domain estimation

`.apply_domain(design)` returns the domain mask. Domain rows are NOT removed
— the full design is used for variance estimation. Only the estimation sums
are restricted to in-domain rows. This is the contract from Phase 0.5.

When both domain AND groups are active, apply BOTH masks: the estimation
loop iterates over group combinations AND restricts to in-domain rows within
each group.

### 5. Small-cell warning

`surveycore_warning_small_cell` fires when any cell has unweighted `n < 5`.
Check after computing all results, before returning. This applies to all
six functions.

### 6. Single-level group warning

`surveycore_warning_single_level` fires when a grouping variable has only
one observed level (after NA exclusion). Check during group resolution.

---

## File Organization Summary

```
R/
├── 00-s7-classes.R           # Add survey_srs (Prereq PR 1)
├── 03-constructors.R         # Update as_survey() dispatch (Prereq PR 1)
├── 06-variance-estimation.R  # Add twophase (Prereq PR 2); remove stubs (PR 3);
│                             # add vcov machinery (PR 4); add Woodruff (PR 5)
├── 09-meta.R                 # meta() generic (PR 1)
├── 09-analysis-helpers.R     # Shared helpers (PR 1)
├── 10-analysis-freqs.R       # get_freqs() (PR 2)
├── 11-analysis-means.R       # get_means(), get_totals() (PR 3)
├── 12-analysis-corr.R        # get_corr() (PR 4)
└── 13-analysis-quantiles.R   # get_quantiles(), get_ratios() (PR 5)

tests/testthat/
├── helper-test-data.R        # Add survey_srs branch to test_invariants(),
│                             # add test_result_invariants(), update make_all_designs()
├── test-s7-classes.R         # Add survey_srs tests (Prereq PR 1)
├── test-constructors.R       # Update for survey_srs path (Prereq PR 1)
├── test-variance-estimation.R # Add twophase oracle (PR 2); update for Phase 1 output (PR 3)
├── test-analysis-helpers.R   # New (PR 1)
├── test-analysis-freqs.R     # New (PR 2)
├── test-analysis-means.R     # New (PR 3)
├── test-analysis-totals.R    # New (PR 3)
├── test-analysis-corr.R      # New (PR 4)
├── test-analysis-quantiles.R # New (PR 5)
└── test-analysis-ratios.R    # New (PR 5)
```

---

## Dependency Notes

### `tibble` in Imports

`tibble` must be in `DESCRIPTION Imports`. Used by:
- `.make_result_tibble()` — `tibble::tibble()`, `tibble::as_tibble()`
- `test_result_invariants()` — `tibble::is_tibble()`
- All result objects inherit from `tbl_df`

### No `vctrs` or `dplyr` required

The column-by-column accumulation pattern eliminates any dependency on
`vctrs::vec_rbind()` or `dplyr::bind_rows()`.

### `survey` in Suggests

`survey` remains in `Suggests` for oracle tests only. All oracle tests call
`skip_if_not_installed("survey")`.

### `surveytidy` in Suggests

Tests for domain estimation (`.apply_domain()`) and `@groups` use
`surveytidy::filter()` and `surveytidy::group_by()`. All such tests call
`skip_if_not_installed("surveytidy")`.

---

## Quality Gates

### Per-PR

Every PR must pass before its PR title is squash-merged:
- `devtools::check()` 0 errors, 0 warnings, ≤ 2 notes
- All tests pass (`devtools::test()`)
- `devtools::document()` run; `NAMESPACE` and `man/` in sync
- `plans/error-messages.md` updated if any new error/warning classes added
- `VENDORED.md` updated if any new code is vendored (PR 2, PR 4, PR 5)

### Phase 1 Complete

All items from spec Section XII must pass, plus:
- [ ] `survey_srs` class in `R/00-s7-classes.R` with passing tests
- [ ] `as_survey(df)` with no args creates `survey_srs`
- [ ] `survey_calibrated` supported in all 6 functions (weighted SRS approx)
- [ ] `survey_twophase` supported in all 6 functions (Phase 0.75 merged)
- [ ] `variance` argument accepts character vector on all 6 functions
- [ ] `surveycore_warning_cv_undefined` fires when cv requested + estimate ≤ 0
- [ ] `surveycore_warning_all_na_freqs` fires for all-NA + na.rm=TRUE
- [ ] NA in group variable excludes those rows (tested in all 6 functions)
- [ ] 3-way domain + groups combination test passes for all 6 functions
- [ ] `get_corr()` uses variance-covariance approach (not Fisher Z);
      oracle against `survey::svyvar()` passes
- [ ] `test_result_invariants()` in `helper-test-data.R` with strengthened
      `value_labels` assertions
- [ ] Meta-key constants in `R/09-analysis-helpers.R`; `.make_result_tibble()`
      validates against them
- [ ] `plans/error-messages.md` complete (all Phase 1 classes including
      `surveycore_error_invalid_conf_level`, `surveycore_warning_cv_undefined`,
      `surveycore_warning_all_na_freqs`)
- [ ] Phase 0 stubs removed and `test-variance-estimation.R` updated atomically
- [ ] `tibble` added to `DESCRIPTION Imports` if not already present
