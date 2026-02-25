# surveycore Phase 1 — Implementation Plan

**Version:** 1.1
**Date:** February 2026
**Status:** Ready for implementation
**Formal Specification:** `plans/phase-1-formal-specification.md` (v1.2, updated per 2026-02-25 review)
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

Phase 1 adds six analysis functions to surveycore. Both prerequisite PRs have
been completed. Phase 1 proper is seven PRs.

**Total PRs: 7** (Prereq PR 1 and Prereq PR 2 are both COMPLETE)

### Supported Classes (All Six Functions)

All six Phase 1 functions dispatch on these five design classes:

| Class | Variance method |
|---|---|
| `survey_srs` | Standard SRS: `s²/n × (1-f)` |
| `survey_taylor` | Taylor series linearization |
| `survey_replicate` | Replicate weights formula |
| `survey_calibrated` | Weighted SRS approximation (conservative) |
| `survey_twophase` | Two-phase linearization (Phase 0.75 complete — fully supported) |

---

## Prerequisites

### Prereq PR 1 — `feature/survey-srs` ✅ COMPLETE

`survey_srs` class, `as_survey_srs()` constructor, SRS variance engine,
print/summary, and `as_survey()` dispatch to `survey_srs` when no design
args are supplied — all implemented and on `main`. `test_invariants()` in
`helper-test-data.R` has the `survey_srs` branch. `make_all_designs()`
includes `srs`.

### Prereq PR 2 — `feature/variance-twophase` (Phase 0.75) ✅ COMPLETE

Two-phase variance code vendored from the survey package into
`R/06-variance-twophase.R`. Dispatch wired in `R/06-variance-dispatch.R`.
Merged as PR #11. `VENDORED.md` updated.

**Implication for Phase 1:** All six analysis functions dispatch on
`survey_twophase` from day one — there is no "throw unsupported_class" phase.
`.check_unsupported_class()` checks only that `design` inherits from
`survey_base`; it does NOT block `survey_twophase`.

---

## Phase 1 PR Sequence

```
Phase 1 PR 1: meta generic + shared helpers
         │
         ├── Phase 1 PR 2: get_freqs()
         ├── Phase 1 PR 3: get_means() + get_totals() (+ stub removal)
         ├── Phase 1 PR 4: get_corr()
         ├── Phase 1 PR 5a: get_quantiles()
         └── Phase 1 PR 5b: get_ratios()
```

PRs 2–5 can be developed in parallel once PR 1 is merged.

---

### Phase 1 PR 1 — `feature/phase1-meta-helpers` ✅ COMPLETE

#### Files

| File | Action |
|---|---|
| `R/09-meta.R` | Create |
| `R/09-analysis-helpers.R` | Create |
| `tests/testthat/helper-test-data.R` | Extend (add `test_result_invariants()`) |
| `tests/testthat/test-analysis-helpers.R` | Create |
| `plans/error-messages.md` | Update (add row 64: `surveycore_error_unsupported_class`) |
| `DESCRIPTION` | Add `tibble (>= 3.0.0)` to Imports if not already present |
| `changelog/phase-1/feature-phase1-meta-helpers.md` | Create |

#### `R/09-meta.R`

```r
#' Extract metadata from a survey result
#' @export
meta <- function(x, ...) UseMethod("meta")

#' @method meta survey_result
#' @export
meta.survey_result <- function(x, ...) attr(x, ".meta")

#' @method print survey_result
#' @export
print.survey_result <- function(x, ...) {
  cls  <- class(x)[1]
  dims <- paste(nrow(x), "\u00d7", ncol(x))
  cat(sprintf("# A <%s> [%s]\n", cls, dims))
  NextMethod()
  invisible(x)
}
```

`meta()` is the **only** supported way to access result metadata. Direct
`attr()` access is not part of the public API. `print.survey_result` is an
S3 method — use standard S3 roxygen (`@method print survey_result @export`),
not `S7::method()`.

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
  "variables", "variable_labels", "question_prefaces", "value_labels", "method"
)
QUANTILES_META_KEYS <- c(
  "variable", "variable_label", "question_preface", "value_labels", "probs"
)
RATIOS_META_KEYS <- c(
  "numerator", "numerator_label", "denominator", "denominator_label",
  "question_prefaces", "value_labels"
)
```

Note: `CORR_META_KEYS` and `RATIOS_META_KEYS` include `"value_labels"` even
though these functions operate on numeric variables. For numeric variables,
the value in the `value_labels` list is `NULL` (e.g.,
`list(income = NULL, bmi = NULL)`). This allows downstream consumers to
detect variable directionality and coding from metadata.

**2. `.resolve_groups(design, group_expr)`** — as specified in Phase 1 spec
Section 2.2.

**3. `.apply_domain(design)`** — as specified in Section 2.2. Returns logical
vector; if no domain column present, returns `rep(TRUE, nrow(design@data))`.

**4. `.make_result_tibble(col_vecs, groups_df, class_name, design, meta_args, required_meta_keys)`**

Column-by-column accumulation pattern. `col_vecs` is a named list of
already-assembled vectors (one per output column). Validates
`meta_args` keys against `required_meta_keys` with `stopifnot()`.
`required_meta_keys` has **no default** and must always be provided — pass
the function's `*_META_KEYS` constant. Assembles via `tibble::tibble()`.
Attaches `.meta` attribute and sets class.

```r
.make_result_tibble <- function(
  col_vecs,           # named list of vectors; one per result column
  groups_df,          # data.frame of group columns (may have 0 rows when no groups)
  class_name,         # e.g. "survey_means"
  design,
  meta_args,
  required_meta_keys  # no default; always pass the *_META_KEYS constant
) {
  stopifnot(all(required_meta_keys %in% names(meta_args)))
  result <- tibble::as_tibble(c(as.list(groups_df), col_vecs))
  attr(result, ".meta") <- .build_meta(design, meta_args)
  class(result) <- c(class_name, "survey_result", "tbl_df", "tbl", "data.frame")
  result
}
```

**5. `.build_meta(design, meta_args)`** — as specified in Section 2.2.
Determines `design_type` from class membership. Falls back to
`cli_abort()` (not a silent `"unknown"` string) for unrecognized classes:

```r
design_type <- if (S7::S7_inherits(design, survey_taylor))    "taylor"
          else if (S7::S7_inherits(design, survey_replicate)) "replicate"
          else if (S7::S7_inherits(design, survey_twophase))  "twophase"
          else if (S7::S7_inherits(design, survey_srs))       "srs"
          else if (S7::S7_inherits(design, survey_calibrated)) "calibrated"
          else cli::cli_abort(
            c("x" = "Unrecognized design class {.cls {class(design)[1]}}."),
            class = "surveycore_error_unsupported_class"
          )
```

`.build_meta()` also derives `n_respondents` automatically:

```r
n_respondents = as.integer(nrow(design@data))
```

`n_respondents` is a **scalar integer** equal to the total number of rows in
`design@data` — the full sample size the design was constructed from,
independent of groups or domain status.

**6. `.validate_shared_args(variance, conf_level, name_style, valid_variance, call)`**

`variance` is a character vector. Valid values: `c("se", "ci", "var", "cv", "moe", "deff")`.

```r
.validate_shared_args <- function(
  variance,
  conf_level,
  name_style,
  valid_variance = c("se", "ci", "var", "cv", "moe", "deff"),
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
`name_style = "broom"`. Full mapping in spec Section 2.2. Only rename
columns that are present (since `variance` is a vector, any subset of
`se`, `var`, `cv`, `ci_low`, `ci_high`, `moe`, `deff` may be present).

**8. `.check_unsupported_class(design, fn_name)`** — internal helper to
throw `surveycore_error_unsupported_class` for non-survey-base objects.
Since Phase 0.75 is complete, this does **NOT** block `survey_twophase`:

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
}
```

**9. `.add_variance_cols(se_vec, estimate_vec, conf_level, degf, variance)`**

Shared helper that, given a vector of SEs and the `variance` argument,
computes and returns the requested uncertainty column vectors (as a named
list). Called by each `get_*()` function after computing the point estimate
and SE.

```r
# Returns a named list of vectors (only the requested ones)
# se_vec       : numeric vector of standard errors
# estimate_vec : numeric vector of point estimates (for cv, deff)
# se_srs_vec   : numeric vector of SRS-equivalent SEs (for deff; NULL if not needed)
# conf_level   : numeric scalar
# degf         : degrees of freedom (scalar or vector)
# variance     : character vector e.g. c("se", "ci", "deff")
```

Computation order:
1. Always compute SE first (needed for all derived quantities)
2. `var` = `se²`
3. `cv` = `se / estimate * 100`; `NA` + `surveycore_warning_cv_undefined` when
   estimate is 0 or negative
4. `ci_low`, `ci_high` = `estimate ± qt((1+conf_level)/2, degf) × se`
5. `moe` = `(ci_high - ci_low) / 2`
6. `deff` = `(se_complex / se_srs)²` using the design's SRS-equivalent SE.
   For `survey_srs`, always `1.0`. For other designs, compute an SRS SE
   using the actual `n` and sample variance of the estimand — pass in
   `se_srs_vec` computed by the calling function.

Column ordering when multiple present: `se`, `var`, `cv`, `ci_low`, `ci_high`, `moe`, `deff`.

**10. `.degf(design)`** — returns design degrees of freedom as a scalar:

```r
.degf <- function(design) {
  if (S7::S7_inherits(design, survey_taylor)) {
    # sum(PSUs per stratum) - number of strata
    # computed from design@data using ids and strata variables
    ...
  } else if (S7::S7_inherits(design, survey_replicate)) {
    length(design@variables$repweights) - 1L
  } else if (S7::S7_inherits(design, survey_twophase)) {
    # degf from phase 1 design (Taylor or replicate)
    .degf(design@variables$phase1)
  } else if (S7::S7_inherits(design, survey_srs)) {
    nrow(design@data) - 1L   # n - 1 for SRS
  } else if (S7::S7_inherits(design, survey_calibrated)) {
    nrow(design@data) - 1L   # n - 1 (conservative)
  } else {
    cli::cli_abort(
      c("x" = "Cannot compute degrees of freedom for {.cls {class(design)[1]}}."),
      class = "surveycore_error_unsupported_class"
    )
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
  # n_respondents: always present and a positive integer
  testthat::expect_true("n_respondents" %in% names(m))
  testthat::expect_type(m$n_respondents, "integer")
  testthat::expect_gt(m$n_respondents, 0L)
  invisible(result)
}
```

#### `test-analysis-helpers.R` test categories

1. `.validate_shared_args()` — all three errors (`invalid_variance_arg`,
   `invalid_conf_level`, `invalid_name_style`); `variance` as vector accepted;
   unknown values rejected; `"deff"` accepted as valid
2. `.resolve_groups()` — `@groups` only; `group=` only; both combined (AND);
   deduplication; empty result
3. `.apply_domain()` — domain column present; absent (all TRUE)
4. `.make_result_tibble()` — correct class hierarchy; `.meta` attached;
   `stopifnot()` fires on missing required keys; `n_respondents` in meta
5. `.build_meta()` — all five design types; all `design_type` values correct;
   `n_respondents` equals `nrow(design@data)`; fallback to `cli_abort()` for
   unrecognized class
6. `.add_variance_cols()` — each variance option including `"deff"`;
   `"cv"` NA + warning for zero estimates; column ordering (se, var, cv,
   ci_low, ci_high, moe, deff)
7. `.apply_name_style()` — broom rename for each column that exists;
   no-op for surveycore
8. `.degf()` — correct df for taylor, replicate, twophase, srs, calibrated;
   unrecognized class (inherits from `survey_base` but not a supported subclass)
   throws `surveycore_error_unsupported_class`
9. `.check_unsupported_class()` — throws `surveycore_error_unsupported_class`
   when passed a non-`survey_base` object (e.g., a plain data frame); returns
   invisibly (no error) for all five supported design classes (survey_taylor,
   survey_replicate, survey_twophase, survey_srs, survey_calibrated)

---

### Phase 1 PR 2 — `feature/phase1-freqs` ✅ COMPLETE

#### Files

| File | Action |
|---|---|
| `R/10-analysis-freqs.R` | Create |
| `tests/testthat/test-analysis-freqs.R` | Create |
| `changelog/phase-1/feature-phase1-freqs.md` | Create |

#### Signature

```r
get_freqs(
  design,
  x,
  ...,
  group        = NULL,
  names_to     = "name",
  values_to    = "value",
  variance     = NULL,           # NULL or character vector: "se","ci","var","cv","moe","deff"
  conf_level   = 0.95,
  n_weighted   = FALSE,
  min_cell_n   = 30L,            # warning threshold (AAPOR default)
  na.rm        = TRUE,
  label_values = TRUE,
  label_vars   = TRUE,
  name_style   = "surveycore"
)
```

#### Key implementation notes

**Dispatch order** (check at the start of the function):

```r
.check_unsupported_class(design, "get_freqs")  # throws for non-survey-base objects
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

**Proportion computation:** Use the Taylor/replicate/SRS/calibrated/twophase
variance machinery from `R/06-variance-dispatch.R`. For each level of the
variable, compute `svymean()` on a 0/1 indicator. `pct = proportion × 100`; all
variance quantities are on the percentage scale.

**NA in group variable:** Rows where the group variable is `NA` are excluded
from all groups before computing. Do not add an NA group row.

**Small-cell warning:** `surveycore_warning_small_cell` fires when any cell
has unweighted `n < min_cell_n` (default 30L). Check after computing all
results, before returning.

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

**AAPOR-compliant call:**
```r
get_freqs(d, x,
  variance   = c("ci", "moe"),
  n_weighted = TRUE
)
```

#### Test categories (see spec Section 11.2 for full list)

All 12 categories from the spec, plus:
- `surveycore_warning_all_na_freqs` fires for all-NA + `na.rm = TRUE`
- NA in group variable edge case (those rows excluded)
- `min_cell_n` respected (warning fires at correct threshold)
- 3-way combination test: `filter()` + `group_by()` simultaneously
  (`skip_if_not_installed("surveytidy")`)
- All five supported classes (including `survey_twophase`)
- `"deff"` column produced when requested
- `n_weighted` column produced when requested
- Category 8 addendum: `meta(result)$mode` is `"single"` for 1-variable
  calls and `"multi"` for 2+-variable calls

---

### Phase 1 PR 3 — `feature/phase1-means-totals`

**This PR atomically removes the Phase 0 stubs.** CI must be green before
merging. Do not remove stubs in one commit and fix tests in a follow-up.

#### Files

| File | Action |
|---|---|
| `R/11-analysis-means.R` | Create |
| `R/06-variance-dispatch.R` | Remove stubs for `get_means()` / `get_totals()` |
| `tests/testthat/test-analysis-means.R` | Create |
| `tests/testthat/test-analysis-totals.R` | Create |
| `tests/testthat/test-variance-estimation.R` | Expand (oracle tests updated to Phase 1 output structure) |
| `changelog/phase-1/feature-phase1-means-totals.md` | Create |

#### `get_means()` notes

**Signature:**
```r
get_means(
  design,
  x,
  group        = NULL,
  variance     = "ci",
  conf_level   = 0.95,
  n_weighted   = FALSE,
  min_cell_n   = 30L,
  na.rm        = TRUE,
  label_values = TRUE,
  label_vars   = TRUE,
  name_style   = "surveycore"
)
```

**`x` must resolve to a single numeric column.** Throw
`surveycore_error_non_numeric_variable` if not numeric.

**Class dispatch:**
```r
if      (S7::S7_inherits(design, survey_taylor))     .taylor_mean(design, ...)
else if (S7::S7_inherits(design, survey_replicate))  .replicate_mean(design, ...)
else if (S7::S7_inherits(design, survey_twophase))   .twophase_mean(design, ...)
else if (S7::S7_inherits(design, survey_srs))        .srs_mean(design, ...)
else if (S7::S7_inherits(design, survey_calibrated)) .calibrated_mean(design, ...)
```

All five per-class helpers (`.taylor_mean()`, `.replicate_mean()`, `.twophase_mean()`,
`.srs_mean()`, `.calibrated_mean()`, and their `_total()` counterparts) are defined
inline at the top of `R/11-analysis-means.R`. They are not added to the variance
engine files.

**SRS variance:** `.srs_mean()` — uses `(1 - f) * s²/n` where
`f = n/N` from FPC column if present, else `f = 0`. Engine in
`R/06-variance-srs.R`.

**Calibrated variance:** `.calibrated_mean()` — weighted SRS:
`Var(ȳ_w) = Σwᵢ²(yᵢ - ȳ_w)² / (Σwᵢ)²`. Engine in `R/06-variance-srs.R`.

**Two-phase variance:** `.twophase_mean()` — calls the vendored two-phase
variance machinery in `R/06-variance-twophase.R`.

**Output:** Variable name NOT a column — in `meta(result)$variable` only.

**Output columns:**
```
[group_names...]   mean   [se]   [var]   [cv]   [ci_low]   [ci_high]   [moe]   [deff]   n   [n_weighted]
```

**`meta_args`:** Use `MEANS_META_KEYS`.

**AAPOR-compliant call:**
```r
get_means(d, income,
  variance   = c("ci", "moe"),
  n_weighted = TRUE
)
```

#### `get_totals()` notes

**Signature:**
```r
get_totals(
  design,
  x            = NULL,
  group        = NULL,
  variance     = "ci",
  conf_level   = 0.95,
  n_weighted   = FALSE,
  min_cell_n   = 30L,
  na.rm        = TRUE,
  label_values = TRUE,
  label_vars   = TRUE,
  name_style   = "surveycore"
)
```

**Two modes:**
- `x = NULL` → population size (`Σwᵢ`); `n` column omitted from output
- `x = var` → weighted sum (`Σwᵢ × varᵢ`); `n` present

`n` is bracketed (`[n]`) — conditional on whether `x` is provided. For
`get_totals(d)` (no variable), `n_weighted` equals `total` — included for
API uniformity.

**Output columns:**
```
[group_names...]   total   [se]   [var]   [cv]   [ci_low]   [ci_high]   [moe]   [deff]   [n]   [n_weighted]
```

**Class dispatch:** same pattern as `get_means()`, dispatching to
`.taylor_total()`, `.replicate_total()`, `.twophase_total()`,
`.srs_total()`, `.calibrated_total()`.

**SRS variance:** For no-variable mode, `Var(N̂) = N² × (1-f) × s²/n` where
`s²` is the variance of the weights. For variable mode, uses SRS total
variance formula.

**`meta_args`:** Use `TOTALS_META_KEYS`.

**AAPOR-compliant call:**
```r
get_totals(d, income,
  variance   = c("ci", "moe"),
  n_weighted = TRUE
)
```

#### Stub migration in `R/06-variance-dispatch.R`

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
the new default). Add oracle tests for `survey_twophase` now that Phase 0.75
is complete. The point estimate and SE checks remain with the same
tolerances. Example pattern:

```r
expect_equal(sc_est$mean,    coef(sv_est),    tolerance = 1e-10)
expect_equal(sc_est$se,      as.numeric(survey::SE(sv_est)), tolerance = 1e-8)
expect_equal(sc_est$ci_low,  confint(sv_est)[1], tolerance = 1e-6)
expect_equal(sc_est$ci_high, confint(sv_est)[2], tolerance = 1e-6)
```

Note: `survey::SE()` returns a 1×1 matrix in survey ≥ 4.4 — use
`as.numeric(survey::SE(x))` not `survey::SE(x)[["varname"]]`.

#### Test categories

All 12 per-function categories from spec Section 11.2, plus the function-specific
edge cases in Section 11.3. Additional items:
- All five supported classes (including `survey_twophase`)
- `"deff"` column produced when requested
- `n_weighted` column produced when requested
- 3-way combination: `filter()` + `group_by()` simultaneously (`skip_if_not_installed("surveytidy")`)
- Both `get_means()` and `get_totals()` test the two-mode behavior (x = NULL vs. x = var)
- Oracle checks for `ci_low`/`ci_high` using `confint()` at tolerance `1e-6`

---

### Phase 1 PR 4 — `feature/phase1-corr`

#### Files

| File | Action |
|---|---|
| `R/12-analysis-corr.R` | Create |
| `R/06-variance-taylor.R` | Add `.vcov_mean()` for Taylor linearization |
| `R/06-variance-replicate.R` | Add `.vcov_mean()` for replicate weights |
| `R/06-variance-srs.R` | Add `.vcov_mean()` for SRS and calibrated |
| `R/06-variance-twophase.R` | Add `.vcov_mean()` for two-phase |
| `tests/testthat/test-analysis-corr.R` | Create |
| `VENDORED.md` | Update (add `.vcov_mean()` provenance from `survey/R/surveysummary.R`) |
| `changelog/phase-1/feature-phase1-corr.md` | Create |

#### Signature

```r
get_corr(
  design,
  x,
  format       = c("long", "wide"),
  redundant    = FALSE,
  diagonal     = FALSE,
  variance     = "ci",
  conf_level   = 0.95,
  n_weighted   = FALSE,
  min_cell_n   = 30L,
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

This requires adding `.vcov_mean()` to each variance engine file —
a function that returns the full variance-covariance matrix for a set of
variable means, using the same vendored `.svy_recvar()` / replicate
machinery already present. The Taylor engine implementation in
`R/06-variance-taylor.R` is the primary one; replicate and SRS follow
the same pattern using their respective engines.

For `survey_srs` and `survey_calibrated`, the covariance uses the weighted
SRS covariance formula. For `survey_twophase`, use the two-phase
linearization from `R/06-variance-twophase.R`.

**Before implementing**, study how `survey::svyvar()` computes the
variance-covariance matrix. The relevant functions in the survey package
source are in `survey/R/surveysummary.R`. Vendor what is needed.

#### CI bounds: Fisher Z (not `.add_variance_cols()`)

`get_corr()` does **not** use `.add_variance_cols()` for CI columns. Instead,
it computes Fisher Z CIs directly before assembling the result, then calls
`.add_variance_cols()` for any other requested variance columns (se, var, cv,
moe, deff):

```r
# Fisher Z transform and back-transform
z       <- atanh(r)
z_se    <- se_r        # Fisher Z variance: SE of atanh(r); matches cor.test() convention
z_crit  <- qnorm((1 + conf_level) / 2)
ci_low  <- tanh(z - z_crit * se_r)
ci_high <- tanh(z + z_crit * se_r)
```

This ensures CI bounds are always in (−1, 1), which t-distribution CIs cannot
guarantee for extreme correlations. The `se_r` used here is the delta method SE
from the vcov approach (see Oracle section below), not a Fisher Z–based SE.

#### Oracle: `survey::svyvar()`

```r
sv       <- survey::svyvar(~ c(x, y), d_sv)
r_oracle <- sv[1, 2] / sqrt(sv[1, 1] * sv[2, 2])

# Delta method SE: gradient of r = b/sqrt(a*c) w.r.t. (a, b, c)
sigma    <- vcov(sv)   # 3×3 vcov of (Var(X), Cov(X,Y), Var(Y))
a        <- sv[1, 1]; b <- sv[1, 2]; c <- sv[2, 2]
g        <- c(-r_oracle / (2 * a), 1 / sqrt(a * c), -r_oracle / (2 * c))
se_oracle <- sqrt(as.numeric(t(g) %*% sigma %*% g))
```

Oracle tolerance: `r` within `1e-10`, SE within `1e-8`. Works for Taylor,
replicate, and SRS (and twophase via `survey::twophase()`).

#### `get_corr()` specific behavior

- Non-numeric variables in `x` → drop silently, fire
  `surveycore_warning_corr_non_numeric` per dropped variable
- After dropping: if fewer than 2 remain → throw
  `surveycore_error_insufficient_variables`
- `redundant = FALSE` (default): lower triangle only (i < j pairs)
- `diagonal = FALSE` (default): self-correlations excluded
- Wide format: `r` values only; no variance columns in wide format
- `label_vars = TRUE`: `var1`/`var2` cells (long) and `variable` column
  (wide) use variable labels when set
- Pairwise `n`: may differ across pairs when `na.rm = TRUE`
- `statistic` and `df` always present in long format (not optional)
- Small-cell warning threshold applies to pairwise `n` per variable pair

**`meta_args`:** Use `CORR_META_KEYS` (includes `value_labels`; for numeric
variables the per-variable entry is `NULL`).

**AAPOR-compliant call:**
```r
get_corr(d, x = c(income, bmi),
  variance   = c("ci", "moe"),
  n_weighted = TRUE
)
```

#### `"cv"` for correlations

CV = `se_r / r * 100`. When `r ≈ 0`, CV is extremely large or undefined.
`surveycore_warning_cv_undefined` fires; affected cells get `cv = NA`.

#### Test categories

All 12 per-function categories from spec Section 11.2, plus the function-specific
edge cases in Section 11.3. Additional items:
- All five supported classes (including `survey_twophase`)
- `"deff"` column produced when requested
- `n_weighted` column produced when requested
- Oracle against `survey::svyvar()` for Taylor, replicate, and SRS (`skip_if_not_installed("survey")`)
- Fisher Z CI bounds bounded to (−1, 1) for extreme correlations (|r| > 0.9)
- Fisher Z CI width at `|r| > 0.9` matches `survey::svyvar()` oracle within `1e-6`
  (`skip_if_not_installed("survey")`)
- `redundant = TRUE` / `FALSE` and `diagonal = TRUE` / `FALSE` combinations
- Wide format produces no variance columns
- Pairwise `n` differs across pairs when `na.rm = TRUE` and NAs are staggered
- Category 8 addendum: `meta(result)$method` is `"pearson"`

---

### Phase 1 PR 5a — `feature/phase1-quantiles`

#### Files

| File | Action |
|---|---|
| `R/13-analysis-quantiles.R` | Create (`get_quantiles()` only) |
| `tests/testthat/test-analysis-quantiles.R` | Create |
| `VENDORED.md` | Update (add Woodruff quantile helpers from `survey/R/svyquantile.R`) |
| `changelog/phase-1/feature-phase1-quantiles.md` | Create |

Note: Woodruff variance helpers are vendored directly into
`R/13-analysis-quantiles.R` (with GPL attribution), not into
`R/06-variance-*.R`.

#### `get_quantiles()` notes

**Signature:**
```r
get_quantiles(
  design,
  x,
  probs        = c(0.25, 0.5, 0.75),
  group        = NULL,
  variance     = "ci",
  conf_level   = 0.95,
  n_weighted   = FALSE,
  min_cell_n   = 30L,
  na.rm        = TRUE,
  label_values = TRUE,
  label_vars   = TRUE,
  name_style   = "surveycore"
)
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

For `survey_twophase`, dispatch to Woodruff using the two-phase design
structure from `R/06-variance-twophase.R`.

**Output columns:**
```
[group_names...]   quantile   estimate   [se]   [var]   [cv]   [ci_low]   [ci_high]   [moe]   [deff]   n   [n_weighted]
```

**`meta_args`:** Use `QUANTILES_META_KEYS` (includes `probs`).

**AAPOR-compliant call:**
```r
get_quantiles(d, income,
  variance   = c("ci", "moe"),
  n_weighted = TRUE
)
```

#### Test categories

All 12 per-function categories from spec Section 11.2, plus the function-specific
edge cases in Section 11.3. Additional items:
- All five supported classes (including `survey_twophase`)
- `"deff"` column produced when requested
- `n_weighted` column produced when requested
- Oracle against `survey::svyquantile()` (`skip_if_not_installed("survey")`)
- Multiple `probs` values in one call; `quantile` column labels match `paste0("p", round(probs * 100))`
- `surveycore_error_invalid_probs` fires for out-of-range and zero-length `probs`
- Category 8 addendum: `meta(result)$probs` equals the input `probs` numeric vector

---

### Phase 1 PR 5b — `feature/phase1-ratios`

#### Files

| File | Action |
|---|---|
| `R/14-analysis-ratios.R` | Create (`get_ratios()`) |
| `tests/testthat/test-analysis-ratios.R` | Create |
| `changelog/phase-1/feature-phase1-ratios.md` | Create |

Note: The delta method for ratios is internal to `R/14-analysis-ratios.R`
— it does not require additions to the variance engine files.

#### `get_ratios()` notes

**Signature:**
```r
get_ratios(
  design,
  numerator,
  denominator,
  group        = NULL,
  variance     = "ci",
  conf_level   = 0.95,
  n_weighted   = FALSE,
  min_cell_n   = 30L,
  na.rm        = TRUE,
  label_values = TRUE,
  label_vars   = TRUE,
  name_style   = "surveycore"
)
```

**Validate denominator:** All denominator values zero → throw
`surveycore_error_ratio_zero_denominator`.

**Variance — delta method:**
```
ratio = Σ(wᵢ × yᵢ) / Σ(wᵢ × xᵢ)
```
Linearized as `yᵢ - ratio × xᵢ`. SE is then the SE of the mean of this
linearized variable, using the design's variance machinery via
`R/06-variance-dispatch.R`.

This is equivalent to `survey::svyratio()`. Oracle tolerance: ratio within
`1e-10`, SE within `1e-8`.

`n`: count of rows where both numerator AND denominator are non-NA.

Numerator and denominator variable names stored in `meta(result)$numerator`
and `meta(result)$denominator` — not output columns.

**Output columns:**
```
[group_names...]   ratio   [se]   [var]   [cv]   [ci_low]   [ci_high]   [moe]   [deff]   n   [n_weighted]
```

**`meta_args`:** Use `RATIOS_META_KEYS` (includes `value_labels`; for numeric
variables the per-variable entry is `NULL`).

**AAPOR-compliant call:**
```r
get_ratios(d, numerator = hospital_visits, denominator = person_years,
  variance   = c("ci", "moe"),
  n_weighted = TRUE
)
```

#### Test categories

All 12 per-function categories from spec Section 11.2, plus the function-specific
edge cases in Section 11.3. Additional items:
- All five supported classes (including `survey_twophase`)
- `"deff"` column produced when requested
- `n_weighted` column produced when requested
- Oracle against `survey::svyratio()` (`skip_if_not_installed("survey")`)
- `surveycore_error_ratio_zero_denominator` fires when all denominator values are zero
- `n` equals count of rows where both numerator AND denominator are non-NA

---

## Cross-Cutting Implementation Details

These decisions apply to every `get_*()` function. Implement them
consistently — do not vary behavior between functions.

### 1. `variance` argument (character vector)

Every `get_*()` function accepts `variance` as `NULL` or a character
vector of any subset of `c("se", "ci", "var", "cv", "moe", "deff")`.

```r
# Valid calls:
get_means(d, x)                                     # uses default "ci"
get_means(d, x, variance = NULL)                   # no uncertainty columns
get_means(d, x, variance = "se")                   # only se
get_means(d, x, variance = c("se", "ci"))          # se, ci_low, ci_high
get_means(d, x, variance = c("se", "ci", "moe"))   # se, ci, moe
get_means(d, x, variance = c("ci", "deff"))        # ci + design effect
```

Computation order in `.add_variance_cols()`:
1. Always compute SE first (needed for all derived quantities)
2. `var` = `se²`
3. `cv` = `se / estimate * 100`; `NA` + warning when estimate ≤ 0
4. `ci_low`, `ci_high` = `estimate ± qt((1+conf_level)/2, degf) × se`
5. `moe` = `(ci_high - ci_low) / 2`
6. `deff` = `(se_complex / se_srs)²` (see §9 above for per-class behavior)

Column ordering in output (only add columns that are requested):
`se`, `var`, `cv`, `ci_low`, `ci_high`, `moe`, `deff`

### 2. Class dispatch pattern

Every `get_*()` function dispatches to class-specific variance functions.
Use `S7::S7_inherits()` for all checks. Pattern (all five classes — no
blocking for `survey_twophase`):

```r
if      (S7::S7_inherits(design, survey_taylor))     .taylor_*(design, ...)
else if (S7::S7_inherits(design, survey_replicate))  .replicate_*(design, ...)
else if (S7::S7_inherits(design, survey_twophase))   .twophase_*(design, ...)
else if (S7::S7_inherits(design, survey_srs))        .srs_*(design, ...)
else if (S7::S7_inherits(design, survey_calibrated)) .calibrated_*(design, ...)
```

Call `.check_unsupported_class(design, fn_name)` at the very start of each
`get_*()` function (before any tidy-select resolution or validation). This
throws only for non-survey-base objects.

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
are restricted to in-domain rows.

When both domain AND groups are active, apply BOTH masks: the estimation
loop iterates over group combinations AND restricts to in-domain rows within
each group.

### 5. Small-cell warning

`surveycore_warning_small_cell` fires when any cell has unweighted
`n < min_cell_n` (default 30L, AAPOR public-reporting guidance). Check after
computing all results, before returning. This applies to all six functions.
For `get_corr()`, "cell" means a variable pair; the threshold applies to
pairwise `n`.

Users at stricter agencies can set `min_cell_n = 50` without changing any
other arguments.

### 6. Single-level group warning

`surveycore_warning_single_level` fires when a grouping variable has only
one observed level (after NA exclusion). Check during group resolution.

---

## File Organization Summary

```
R/
├── 00-s7-classes.R           # survey_srs defined (Prereq PR 1 complete)
├── 03-constructors.R         # as_survey_srs() + as_survey() dispatch (Prereq PR 1 complete)
├── 06-variance-dispatch.R    # Remove get_means()/get_totals() stubs (PR 3);
│                             # add .vcov_mean() is NOT here — see per-engine files (PR 4)
├── 06-variance-taylor.R      # Add .vcov_mean() (PR 4)
├── 06-variance-replicate.R   # Add .vcov_mean() (PR 4)
├── 06-variance-srs.R         # Add .vcov_mean() (PR 4)
├── 06-variance-twophase.R    # Add .vcov_mean() (PR 4; Phase 0.75 complete)
├── 09-meta.R                 # meta() generic + print.survey_result (PR 1)
├── 09-analysis-helpers.R     # Shared helpers (PR 1)
├── 10-analysis-freqs.R       # get_freqs() (PR 2)
├── 11-analysis-means.R       # get_means(), get_totals() (PR 3)
├── 12-analysis-corr.R        # get_corr() (PR 4)
├── 13-analysis-quantiles.R   # get_quantiles() (PR 5a)
└── 14-analysis-ratios.R      # get_ratios() (PR 5b)

tests/testthat/
├── helper-test-data.R        # Add test_result_invariants() (PR 1)
├── test-variance-estimation.R # Add twophase oracle (PR 3); update for Phase 1 output
├── test-analysis-helpers.R   # New (PR 1)
├── test-analysis-freqs.R     # New (PR 2)
├── test-analysis-means.R     # New (PR 3)
├── test-analysis-totals.R    # New (PR 3)
├── test-analysis-corr.R      # New (PR 4)
├── test-analysis-quantiles.R # New (PR 5a)
└── test-analysis-ratios.R    # New (PR 5b)
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
- Test coverage ≥ 98% line coverage for new files in this PR (CI blocks below 95%)
- `plans/error-messages.md` updated if any new error/warning classes added
- `VENDORED.md` updated if any new code is vendored (PR 4, PR 5)
- Changelog entry committed on this branch

### Phase 1 Complete

All items from spec Section XII must pass, plus:
- [ ] All six functions dispatch on all five design classes (including `survey_twophase`)
- [ ] `variance` argument accepts character vector including `"deff"` on all 6 functions
- [ ] `n_weighted = FALSE` argument on all 6 functions
- [ ] `min_cell_n = 30L` argument on all 6 functions (AAPOR default, configurable)
- [ ] `surveycore_warning_small_cell` fires at `n < min_cell_n` (not hard-coded n < 5)
- [ ] `surveycore_warning_cv_undefined` fires when cv requested + estimate ≤ 0
- [ ] `surveycore_warning_all_na_freqs` fires for all-NA + na.rm=TRUE in `get_freqs()`
- [ ] NA in group variable excludes those rows (tested in all 6 functions)
- [ ] 3-way domain + groups combination test passes for all 6 functions
- [ ] `get_corr()` uses variance-covariance approach (not Fisher Z);
      oracle against `survey::svyvar()` passes for Taylor, replicate, and twophase
- [ ] `test_result_invariants()` includes `n_respondents` check (positive integer)
- [ ] `.build_meta()` includes `n_respondents = nrow(design@data)` (as integer)
- [ ] `.build_meta()` fallback throws `surveycore_error_unsupported_class`, not `"unknown"`
- [ ] Meta-key constants in `R/09-analysis-helpers.R`; `CORR_META_KEYS` and
      `RATIOS_META_KEYS` include `"value_labels"`
- [ ] `.make_result_tibble()` validates against `required_meta_keys` (no default)
- [ ] `print.survey_result` S3 method in `R/09-meta.R`
- [ ] `plans/error-messages.md` complete (all Phase 1 classes)
- [ ] Phase 0 stubs removed from `R/06-variance-dispatch.R` and `test-variance-estimation.R`
      updated atomically; CI green before merge
- [ ] `tibble` in `DESCRIPTION Imports` if not already present
- [ ] Oracle tests for `survey_twophase` added to `test-variance-estimation.R`
      and all per-function test files (`skip_if_not_installed("survey")`)
