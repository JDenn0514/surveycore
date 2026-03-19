# surveycore Phase 1 — Formal Specification

**Version:** 1.1
**Date:** February 2026
**Status:** Updated per architecture review (2026-02-21)

---

## Document Purpose

This document is the authoritative specification for Phase 1 of the surveycore
package. Every API contract, behavioral rule, output structure, and design
decision is explicitly defined here. Implementation must follow these rules
exactly.

---

## I. Scope

### What Phase 1 Delivers

Six analysis functions added to the `surveycore` package:

| Function | Description |
|---|---|
| `get_freqs()` | Weighted frequency tables for categorical variables |
| `get_means()` | Weighted means with uncertainty for numeric variables |
| `get_totals()` | Weighted population totals for numeric variables |
| `get_corr()` | Survey-weighted correlations between numeric variables |
| `get_quantiles()` | Weighted quantiles (including median) |
| `get_ratios()` | Survey-weighted ratio estimation |

The Phase 0 stubs for `get_means()` and `get_totals()` in
`R/06-variance-dispatch.R` are **replaced** by full implementations in new
files.

### Supported Design Classes

All six `get_*()` functions support these design classes:

| Class | Variance method | Notes |
|---|---|---|
| `survey_taylor` | Taylor series linearization | Full design-based variance |
| `survey_replicate` | Replicate weights formula | Full design-based variance |
| `survey_srs` | Standard SRS: `s²/n × (1-f)` | Equal-probability samples; `f = 0` when FPC unknown |
| `survey_nonprob` | Weighted SRS approximation | Conservative; see Section 2.7 |
| `survey_twophase` | Two-phase linearization (Phase 0.75 complete) | Full design-based variance via `R/06-variance-twophase.R` |

`survey_srs` is the class returned by `as_survey(df)` with no design arguments.
`survey_nonprob` is the class returned by `as_survey_nonprob(df, weights = w)`.

### Stub Migration (atomic)

The stub removal and the new implementations ship in a **single PR**. That PR
must also update `tests/testthat/test-variance-estimation.R` to use the Phase
1 output structure. The Phase 0 stub signatures differ from Phase 1:

| | Phase 0 stub | Phase 1 full |
|---|---|---|
| Signature | `get_means(design, var)` | `get_means(design, x, group=NULL, variance="ci", ...)` |
| Output columns | `mean`, `se`, `n` | `mean`, `[se]`, `[ci_low, ci_high]`, `[moe]`, `n` + `.meta` attr |
| Output class | plain tibble | `c("survey_means", "survey_result", "tbl_df", ...)` |

The oracle tests in `test-variance-estimation.R` must be **expanded** (not
just migrated) — `sc_est$mean` and `sc_est$se` column checks remain; add
`sc_est$ci_low` etc. for the full variance output.

CI must be green before the stub-removal PR is merged. Do not remove stubs in
one commit and fix tests in a follow-up — this deliberately breaks CI and
violates the 0-errors-before-PR rule.

### What Phase 1 Does NOT Deliver

- `get_diffs()` — deferred to Phase 2 (requires `survey_glm()`; see
  Section IX for the deferred design)
- `get_crosstab()` — Phase 2 scope
- Regression — Phase 2 scope
- Covariate-adjusted means — Phase 3 scope

---

## II. Architecture

### 2.1 File Organization

```
R/
├── 09-meta.R                 # meta() generic + survey_result base class (Section 2.3)
├── 09-analysis-helpers.R     # Shared internal helpers (Section 2.2)
├── 10-analysis-freqs.R       # get_freqs()
├── 11-analysis-means.R       # get_means(), get_totals()
├── 12-analysis-corr.R        # get_corr()
├── 13-analysis-quantiles.R   # get_quantiles(), get_ratios()
└── (06-variance-dispatch.R stubs removed atomically with test-variance-estimation.R update)

tests/testthat/
├── test-analysis-helpers.R   # .build_meta(), .make_result_tibble(), .apply_name_style(),
│                             #   .validate_shared_args(), .resolve_groups(), .apply_domain()
├── test-analysis-freqs.R
├── test-analysis-means.R
├── test-analysis-totals.R
├── test-analysis-corr.R
├── test-analysis-quantiles.R
└── test-analysis-ratios.R
```

### 2.2 Shared Internal Helpers (R/09-analysis-helpers.R)

Every analysis function calls these helpers in sequence before doing any
estimation. They are **not exported**.

#### `.resolve_groups(design, group_expr)`

Resolves the final set of grouping variable names by combining `@groups`
(set by `group_by()`) with the `group =` argument. The two sources are
**ANDed** — both apply simultaneously.

```r
.resolve_groups <- function(design, group_expr) {
  # group_expr is an unevaluated tidy-select expression from enquo()
  # Returns: character vector of all group variable names, or character(0)
  from_groups_prop <- design@groups                        # from group_by()
  from_arg         <- .resolve_tidy_select(group_expr,     # from group= arg
                                           design@data)
  unique(c(from_groups_prop, from_arg))                    # AND them
}
```

**Behavior:**
- If `@groups = c("region")` and `group = sex`: groups by both region and sex
- If `@groups = character(0)` and `group = NULL`: no grouping
- Duplicate names silently deduplicated

#### `.apply_domain(design)`

Returns a logical vector indicating which rows belong to the active domain.
If no domain column exists, all rows are in-domain.

```r
.apply_domain <- function(design) {
  if (SURVEYCORE_DOMAIN_COL %in% names(design@data)) {
    design@data[[SURVEYCORE_DOMAIN_COL]]
  } else {
    rep(TRUE, nrow(design@data))
  }
}
```

Domain rows are **not physically removed**. Variance estimation uses the full
design for correct standard errors; only the estimation sum is restricted to
in-domain rows. This is the domain estimation contract from Phase 0.5.

#### `.make_result_tibble(rows_list, groups_df, class_name, design, meta_args, ...)`

Assembles a result tibble from a list of per-group estimate rows, builds the
structured metadata object via `.build_meta()`, attaches it as
`attr(result, ".meta")`, and applies the S3 class hierarchy.

**Accumulation pattern:** Each `get_*()` function accumulates results using
**column-by-column vectors**, not a list of row-lists. In the per-group loop,
each estimate is appended to a named vector (one vector per output column).
After the loop, `.make_result_tibble()` receives these parallel vectors and
assembles the tibble via `tibble::tibble()`. This approach uses only `tibble`
(already in `Imports`) and eliminates any dependency on `vctrs` or `dplyr`
for result assembly.

`.make_result_tibble()` validates required keys before building the tibble.

Required keys by function:

| Function | Required keys in each `rows_list` element |
|---|---|
| `get_freqs()` | `pct`, `n` (+ `se`/`ci_low`/`ci_high`/`moe` per `variance`; + `n_weighted` if requested) |
| `get_means()` | `mean`, `n` (+ variance cols) |
| `get_totals()` | `total` (+ variance cols; `n` only when variable supplied) |
| `get_corr()` | `r`, `p_value`, `n`, `statistic`, `df` (+ variance cols) |
| `get_quantiles()` | `quantile`, `estimate`, `n` (+ variance cols) |
| `get_ratios()` | `ratio`, `n` (+ variance cols) |

`.make_result_tibble()` must call `stopifnot()` on required keys before
binding — failure here is a programmer error, not a user error, so `stopifnot()`
(not `cli_abort()`) is correct. This surfaces implementation inconsistencies
at test time rather than silently producing wrong output.

The assembled object always has classes:
```r
c(class_name, "survey_result", "tbl_df", "tbl", "data.frame")
```

The single metadata attribute on every result:
```r
attr(result, ".meta")   # structured list; access via meta(result)
```

Individual `attr()` calls are **not** used. All metadata is consolidated in
`.meta`.

#### `.build_meta(design, meta_args)`

Constructs the structured `.meta` list from design properties and
function-supplied `meta_args`. Every key is always present; unset values are
`NULL`, never absent.

**`meta_args` contract:** each `get_*()` function builds and passes a named
list. `.build_meta()` merges it with design-level fields it derives
automatically (`design_type`, `conf_level`, `call`, `group_names`,
`group_labels`). Functions must supply exactly the keys shown below — no
extras, no omissions:

**`design_type` mapping** — derived using `S7::S7_inherits()` per
`code-style.md §2` (class objects, never strings):

```r
# In .build_meta() — canonical mapping; do not use class(design)[1] string manipulation
design_type <- if (S7::S7_inherits(design, survey_taylor))    "taylor"
          else if (S7::S7_inherits(design, survey_replicate)) "replicate"
          else if (S7::S7_inherits(design, survey_twophase))  "twophase"
          else if (S7::S7_inherits(design, survey_srs))       "srs"
          else if (S7::S7_inherits(design, survey_nonprob)) "calibrated"
          else cli::cli_abort(
            c("x" = "Unrecognized design class {.cls {class(design)[1]}}."),
            class = "surveycore_error_unsupported_class"
          )
```

Valid string values: `"taylor"`, `"replicate"`, `"twophase"`, `"srs"`, `"calibrated"`.
Downstream code (surveytidy and future packages) branches on these exact strings.

| Function | Required keys in `meta_args` |
|---|---|
| `get_freqs()` single-var | `mode = "single"`, `variable`, `variable_label`, `question_preface`, `value_labels` |
| `get_freqs()` multi-var | `mode = "multi"`, `variables`, `variable_labels`, `question_prefaces`, `value_labels` |
| `get_means()` | `variable`, `variable_label`, `question_preface`, `value_labels` |
| `get_totals()` | `variable`, `variable_label`, `question_preface`, `value_labels` |
| `get_corr()` | `variables`, `variable_labels`, `question_prefaces`, `value_labels`, `method` |
| `get_quantiles()` | `variable`, `variable_label`, `question_preface`, `value_labels`, `probs` |
| `get_ratios()` | `numerator`, `numerator_label`, `denominator`, `denominator_label`, `question_prefaces`, `value_labels` |

`value_labels` is always a **named list** — one key per variable, value is a
named vector of label → raw value mappings, or `NULL` for numeric/unlabelled
variables. Single-variable functions supply `list(var_name = c(...))` or
`list(var_name = NULL)`.

`value_labels` is included for **all six functions** — including `get_corr()`
and `get_ratios()`, which operate on numeric variables. For numeric variables,
the value is `NULL` per variable (e.g., `list(income = NULL, bmi = NULL)`).
Including it for these functions allows downstream consumers to detect variable
directionality from metadata (e.g., whether a variable was reverse-coded), which
is relevant when interpreting the sign of correlation coefficients.

#### `.validate_shared_args(variance, conf_level, name_style, valid_variance, call)`

Validates the cross-cutting arguments that appear identically on all six
`get_*()` functions. **Every `get_*()` function must call this as its first
action**, before any estimation logic or tidy-select resolution.

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
        "x" = "{.arg name_style} must be {.val \"surveycore\"} or {.val \"broom\"}.",
        "i" = "Got {.val {name_style}}."
      ),
      class = "surveycore_error_invalid_name_style",
      call  = call
    )
  }
  invisible(TRUE)
}
```

This is the single canonical source for all three validation errors. Never
duplicate these checks inside individual `get_*()` functions.

`surveycore_error_invalid_conf_level` is defined in `plans/error-messages.md`
(Phase 1 row).

#### Meta-Key Constants

To prevent the `meta_args` contract from being defined in multiple places,
each function's required meta-keys are defined as named constants at the top
of `R/09-analysis-helpers.R`:

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

`.make_result_tibble()` accepts a `required_meta_keys` argument and validates
with `stopifnot(all(required_meta_keys %in% names(meta_args)))`. Each
`get_*()` function passes its constant. Adding a new meta field requires
updating only the constant — not the validation logic.

`required_meta_keys` has **no default** and must always be provided. Omitting
it or passing `NULL` is a programmer error — it would silently skip the
`meta_args` contract enforcement. Always pass the function's `*_META_KEYS`
constant.

#### `.apply_name_style(result, name_style)`

Renames columns at the very end of each `get_*()` function based on
`name_style`. Applied only when `name_style != "surveycore"` (the default).

Supported styles:

| `name_style` | Description |
|---|---|
| `"surveycore"` | Default snake_case names (see each function's spec) |
| `"broom"` | Renames to match `broom::tidy()` conventions |

**Broom rename mapping:**

| surveycore name | broom name |
|---|---|
| `se` | `std.error` |
| `ci_low` | `conf.low` |
| `ci_high` | `conf.high` |
| `p_value` | `p.value` |
| `mean` / `total` / `pct` / `r` / `ratio` / `estimate` | `estimate` |
| `statistic` | `statistic` |
| `df` | `parameter` |

---

### 2.3 The `meta()` Generic (R/09-meta.R)

```r
#' Extract metadata from a survey result
#'
#' @param x A `survey_result` object returned by any `get_*()` function.
#' @param ... Currently unused.
#' @return A named list. See the Phase 1 specification for the full contract.
#' @export
meta <- function(x, ...) UseMethod("meta")

#' @export
meta.survey_result <- function(x, ...) attr(x, ".meta")
```

`meta()` is the **only** supported way to access result metadata. Direct
`attr()` access is not part of the public API.

---

### 2.4 The `meta()` Contract

#### Common fields — present on every result

| Field | Type | Description |
|---|---|---|
| `design_type` | `character(1)` | `"taylor"` \| `"replicate"` \| `"twophase"` \| `"srs"` \| `"calibrated"` |
| `conf_level` | `numeric(1)` | Confidence level used; e.g. `0.95` |
| `call` | `language` | Matched call |
| `group_names` | `character` | Grouping variable names; `character(0)` if none |
| `group_labels` | named `list` | Group var → label; `NULL` values for unlabeled group vars |

#### Variable metadata fields — vary by function

| Field | Functions | Type | Description |
|---|---|---|---|
| `mode` | `get_freqs()` | `character(1)` | `"single"` when `x` resolves to 1 variable; `"multi"` when `x` resolves to 2+ variables |
| `variable` | all single-var functions | `character(1)` or `NULL` | Focal variable name; `NULL` for no-variable `get_totals()` |
| `variable_label` | all single-var functions | `character(1)` or `NULL` | Variable label; `NULL` if unset |
| `question_preface` | all single-var functions | `character(1)` or `NULL` | Question preface; `NULL` if unset; omitted from display when `NULL` |
| `value_labels` | all functions | named `list` | Always a named list: one key per variable, value is named vector or `NULL`. Single-var: `list(var = c(...))` or `list(var = NULL)`. Multi-var: one key per focal variable. Always populated from metadata regardless of `label_values` argument. |
| `variables` | `get_freqs()` multi-var, `get_corr()` | `character` | All focal variable names |
| `variable_labels` | `get_freqs()` multi-var, `get_corr()` | named `list` | Var → label; `NULL` values for unlabeled variables |
| `question_prefaces` | `get_freqs()` multi-var, `get_corr()`, `get_ratios()` | named `list` | Var → preface; `NULL` values for variables without a preface |
| `numerator` | `get_ratios()` | `character(1)` | Numerator variable name |
| `numerator_label` | `get_ratios()` | `character(1)` or `NULL` | Numerator variable label; `NULL` if unset |
| `denominator` | `get_ratios()` | `character(1)` | Denominator variable name |
| `denominator_label` | `get_ratios()` | `character(1)` or `NULL` | Denominator variable label; `NULL` if unset |

#### Function-specific fields

| Field | Function | Type | Description |
|---|---|---|---|
| `method` | `get_corr()` | `character(1)` | Always `"pearson"` in Phase 1 (Spearman/Kendall deferred to Phase 2) |
| `probs` | `get_quantiles()` | `numeric` | Quantile probabilities used; e.g. `c(0.25, 0.5, 0.75)` |

#### `n_respondents` — always a scalar

`n_respondents` is a **scalar `integer`** equal to `nrow(design@data)` — the
total number of rows in the design regardless of groups, domain status, or
weight. It is not a per-group breakdown; it represents the full sample size the
design was constructed from. For per-group unweighted counts, use the `n`
column in the result tibble.

#### NULL behavior by field type

| Field | When `NULL` | Display fallback |
|---|---|---|
| `variable_label` | Label not set | Raw variable name |
| `value_labels` | No labels set or numeric variable | Raw values |
| `question_preface` / `question_prefaces` | Preface not set | Omit — no fallback; output is fully interpretable without it |
| `group_labels` values | Group var has no label | Raw group variable name used as column header |

The distinction: `variable_label` and `value_labels` are **replacements** —
something always occupies that slot in the output, so a fallback is required.
`question_preface` is **additive** — there is no slot to fill; its absence is
not a gap.

#### Example: `meta()` output for `get_freqs()` multi-var

```r
result <- get_freqs(d, x = c(q1, q2, q3), names_to = "item",
                    values_to = "response", group = region)
meta(result)
# $design_type
# [1] "taylor"
#
# $conf_level
# [1] 0.95
#
# $call
# get_freqs(d, x = c(q1, q2, q3), ...)
#
# $group_names
# [1] "region"
#
# $group_labels
# $group_labels$region
# [1] "Census region"
#
# $variables
# [1] "q1" "q2" "q3"
#
# $variable_labels
# $variable_labels$q1
# [1] "Satisfaction with service"
# $variable_labels$q2
# [1] "Satisfaction with staff"
# $variable_labels$q3
# NULL                          # no label set; display falls back to "q3"
#
# $question_prefaces
# $question_prefaces$q1
# [1] "For each of the following, please rate your experience:"
# $question_prefaces$q2
# [1] "For each of the following, please rate your experience:"
# $question_prefaces$q3
# NULL                          # no preface set; omitted from display
#
# $value_labels
# $value_labels$q1
# c(Agree = 1, Neutral = 2, Disagree = 3)
# $value_labels$q2
# c(Agree = 1, Neutral = 2, Disagree = 3)
# $value_labels$q3
# NULL
```

`value_labels` is always populated from design metadata regardless of the
`label_values` argument. `label_values` controls whether labels are applied
to the *rows* of the result tibble; `meta()$value_labels` always carries the
mapping for downstream consumers.

#### `surveycore_warning_mixed_prefaces`

Fired by `get_freqs()` multi-var when the supplied variables have **different
non-NULL prefaces** — a signal that the variables may not belong together in
one call.

```r
cli::cli_warn(
  c(
    "!" = "{length(unique_prefaces)} different question prefaces found across {length(vars)} variables.",
    "i" = "Variables with different prefaces may not belong in the same {.fn get_freqs} call.",
    "i" = "Prefaces are stored in {.code meta(result)$question_prefaces}.",
    "v" = "Consider splitting into separate {.fn get_freqs} calls, one per preface."
  ),
  class = "surveycore_warning_mixed_prefaces"
)
```

The function still runs and returns a result. The warning is advisory.

---

### 2.5 Output Class Hierarchy

All analysis functions return a tibble with a two-level S3 class:

```
survey_result          ← base class: shared print/format method
├── survey_freqs       ← get_freqs()
├── survey_means       ← get_means()
├── survey_totals      ← get_totals()
├── survey_corr        ← get_corr()
├── survey_quantiles   ← get_quantiles()
└── survey_ratios      ← get_ratios()
```

The `survey_result` class owns `print()` and `format()` — no subclass print
methods are needed for Phase 1. All six result types print as ordinary tibbles.
`statistic` and `df` in `get_corr()` output are always-visible columns (see
Section VI).

`survey_result` is an S3 class (built on tibble), so the print method uses
standard S3 syntax — **not** `S7::method() <-`. Register with roxygen2:

```r
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

### 2.6 Cross-Cutting Arguments

These arguments appear on every `get_*()` function with identical semantics:

| Argument | Type | Description |
|---|---|---|
| `group` | tidy-select | Additional grouping variables; ANDed with `@groups` |
| `variance` | character or NULL | Which uncertainty measure to include in output columns |
| `conf_level` | numeric (0,1) | Confidence level for CIs and MOE; default `0.95` |
| `n_weighted` | logical | Add a `n_weighted` column: the sum of weights for observations contributing to each cell estimate; default `FALSE`. For `get_corr()`, pairwise weighted n per variable pair. For `get_totals(d)` (no variable), equals the `total` column and is included for API uniformity. |
| `min_cell_n` | integer | Minimum unweighted cell count before `surveycore_warning_small_cell` fires; default `30L` (AAPOR public-reporting guidance). Federal agencies requiring stricter suppression may set `min_cell_n = 50`. For `get_corr()`, threshold applies to pairwise n per variable pair. |
| `na.rm` | logical | Exclude NA values; default `TRUE` |
| `label_values` | logical | Apply value labels to **all** categorical values in the output — including the focal variable's level column and any group column values; default `TRUE` |
| `label_vars` | logical | Apply variable labels where variable names appear as row values (`names_to` column in `get_freqs()` multi-var; `var1`/`var2` columns in `get_corr()`); default `TRUE` |
| `name_style` | character | Output column naming style; default `"surveycore"` |

`label_vars` does not affect column *headers* (those always use raw variable
names). It only affects cells where a variable name appears as a *value* —
the `names_to` column in `get_freqs()` multi-var and the `var1`/`var2`
columns in `get_corr()`.

**`label_vars` is accepted but has no visible effect on `get_means()`,
`get_totals()`, `get_quantiles()`, and `get_ratios()`** — their outputs
contain no cells where a variable name appears as a value. The argument is
present on all six functions for API uniformity.

#### NA values in grouping variables

When a grouping variable (from `group =` or `@groups`) contains `NA` values,
rows with `NA` in that grouping variable are **excluded from all groups**.
They do not appear in the output and are not counted in `n`. This matches
`dplyr::group_by()` semantics and is documented in the `@param group` entry
for each function. Add one edge case test per function verifying this behavior.

#### The `variance` argument

Controls which uncertainty columns appear in the output tibble. `variance`
accepts `NULL` or a **character vector** of one or more values from
`c("se", "ci", "var", "cv", "moe")`. Multiple values are combined.

| Value | Columns added | Notes |
|---|---|---|
| `NULL` | None | No uncertainty columns |
| `"se"` | `se` | Standard error |
| `"ci"` | `ci_low`, `ci_high` | Confidence interval bounds |
| `"var"` | `var` | Variance (`se²`) |
| `"cv"` | `cv` | Coefficient of variation (`se / estimate × 100`); fires `surveycore_warning_cv_undefined` when estimate = 0 or negative |
| `"moe"` | `moe` | Margin of error = `qt((1 + conf_level)/2, df) × se` |
| `"deff"` | `deff` | Design effect = `(se_complex / se_srs)²`. For `survey_srs`, always `1.0`. For `survey_twophase`, computes design effect using the two-phase linearization SE (Phase 0.75 complete). Requires computing an SRS-equivalent SE internally for comparison. |

When multiple values are supplied (e.g., `variance = c("se", "ci")`), all
corresponding columns are added. Column order when multiple present:
`se`, `var`, `cv`, `ci_low`, `ci_high`, `moe`, `deff`.

`"cv"` is accepted by all six functions. For functions where the estimate can
be 0 or negative (e.g., `get_corr()` when `r ≈ 0`), `cv` is `NA` for those
cells and `surveycore_warning_cv_undefined` fires.

**Default by function:**

| Function | Default `variance` |
|---|---|
| `get_freqs()` | `NULL` |
| `get_means()` | `"ci"` |
| `get_totals()` | `"ci"` |
| `get_quantiles()` | `"ci"` |
| `get_ratios()` | `"ci"` |
| `get_corr()` | `"ci"` |

#### Degrees of freedom for confidence intervals

All CI and MOE calculations use the **t-distribution** with design degrees of
freedom:

- `survey_taylor`: `degf = sum(PSUs per stratum) - number of strata`
- `survey_replicate`: `degf = number of replicates - 1`
- `survey_twophase`: `degf` from phase 1 design
- `survey_srs`: `degf = n - 1`
- `survey_nonprob`: `degf = n - 1` (conservative)

The critical value is `qt((1 + conf_level) / 2, df = degf)`.

This matches the `survey` package default and produces wider, more honest CIs
than the normal approximation for small designs.

---

## III. `get_freqs()`

### 3.1 Signature

```r
get_freqs(
  design,
  x,                              # tidy-select; 1+ variables
  ...,                            # passed to tidy-select (future-proof)
  group        = NULL,            # tidy-select; additional grouping
  names_to     = "name",          # column name when stacking multi-variable
  values_to    = "value",         # column name for response values
  variance     = NULL,            # NULL | "se" | "ci" | "var" | "cv" | "moe" | "deff"
  conf_level   = 0.95,
  n_weighted   = FALSE,           # add weighted population count column
  min_cell_n   = 30L,             # warning threshold for small cells (AAPOR default)
  na.rm        = TRUE,
  label_values = TRUE,
  label_vars   = TRUE,            # use variable labels in names_to column (multi-var)
  name_style   = "surveycore"
)
```

### 3.2 Single-Variable Mode

When `x` resolves to exactly one variable.

**Output columns:**
```
[variable_name]   pct   [se]   [var]   [cv]   [ci_low]   [ci_high]   [moe]   [deff]   n   [n_weighted]
```

- `[variable_name]`: the variable name itself becomes the column name, matching
  `dplyr::count()` convention. Values are the distinct levels of the variable.
  If `label_values = TRUE` and value labels exist in metadata (or haven
  attributes), values are converted to character using those labels. Falls back
  to raw values silently if no labels exist.
- `pct`: weighted proportion, expressed as a percentage (0–100).
- `n`: **unweighted** sample count (number of respondents in each cell).
  This is intentionally unweighted — it represents the sample basis of each
  estimate and is the conventional `n` in published survey frequency tables.
- `n_weighted`: **weighted** population count (sum of weights for each cell).
  Only present when `n_weighted = TRUE`. Represents the estimated number of
  population members in each cell.
- Uncertainty columns controlled by `variance` argument.

**Row ordering:** follows the order of levels if the variable is a factor;
otherwise sorted by the variable values ascending.

**Example:**
```r
get_freqs(d, sex)
# A <survey_freqs> [2 × 3]
  sex       pct      n
  <chr>   <dbl>  <int>
1 Male     48.3    241
2 Female   51.7    259

get_freqs(d, sex, variance = "ci")
  sex       pct   ci_low  ci_high     n
1 Male     48.3    45.6    51.0     241
2 Female   51.7    49.0    54.4     259

get_freqs(d, sex, n_weighted = TRUE)
  sex       pct      n   n_weighted
1 Male     48.3    241    6,241,823
2 Female   51.7    259    6,758,177
```

### 3.3 Grouped Mode

When groups are active (via `group =` or `@groups`), group columns appear
first.

**Output columns:**
```
[group_names...]   [variable_name]   pct    n    [variance cols]
```

**Example:**
```r
get_freqs(d, sex, group = region)
  region  sex       pct      n
1 East    Male     46.1     58
2 East    Female   53.9     64
3 North   Male     49.3     68
...

# @groups AND group= are ANDed:
d |> group_by(region) |> get_freqs(sex, group = age_grp)
  region  age_grp  sex       pct      n
1 East    18-34    Male     44.1     18
...
```

### 3.4 Multi-Variable Mode

When `x` resolves to 2+ variables, the output is stacked (long format).

**Behavior:**
- Each variable becomes a block of rows.
- The `names_to` column contains the variable label from metadata when
  `label_vars = TRUE` (default). Falls back to the raw variable name if no
  label is set or `label_vars = FALSE`.
- The `values_to` column contains the response values (subject to
  `label_values`).

**Output columns:**
```
[group_names...]   [names_to]   [values_to]   pct   [se]   [var]   [cv]   [ci_low]   [ci_high]   [moe]   n   [n_weighted]
```

Column ordering is consistent with single-variable mode (Section 3.2):
variance columns appear before `n`, and `[n_weighted]` is the last column
when requested.

**Example:**
```r
# d has: var_label(q1) = "Satisfaction with service"
#         var_label(q2) = "Satisfaction with staff"
#         q3 has no label set

get_freqs(d, x = c(q1, q2, q3), names_to = "item", values_to = "response")
  item                        response    pct      n
1 Satisfaction with service   Agree      45.2    226
2 Satisfaction with service   Neutral    32.1    161
3 Satisfaction with service   Disagree   22.7    113
4 Satisfaction with staff     Agree      38.4    192
...
7 q3                          Agree      ...        # raw name fallback

# With groups:
get_freqs(d, x = c(q1, q2), names_to = "item", values_to = "response",
          group = sex)
  sex     item                        response    pct      n
1 Male    Satisfaction with service   Agree      43.2    109
...
```

### 3.5 AAPOR-Compliant Call

```r
get_freqs(d, x,
  variance   = c("ci", "moe"),
  n_weighted = TRUE
)
```

Produces confidence intervals, margin of error, and weighted population count.
Small-cell warnings fire automatically at `n < min_cell_n` (default 30).

### 3.6 Statistical Details

- Proportions are computed as `svymean()` applied to a binary (0/1) indicator
  per level, or equivalently via the Taylor/replicate variance machinery in
  `R/06-variance-dispatch.R` (dispatching to `R/06-variance-taylor.R`,
  `R/06-variance-replicate.R`, or `R/06-variance-srs.R` by design class).
- `pct = proportion × 100`. All variance quantities (se, ci, moe) are on the
  percentage scale as well (i.e., `se` is SE of the percentage, not the
  proportion).
- With `na.rm = TRUE` (default), NA values in the variable are excluded from
  all counts and proportions. NA does not appear as a level. The `n` column
  counts non-NA respondents.
- With `na.rm = FALSE`, NA values appear as their own level in the output — one
  additional row with the variable value equal to `NA`. The denominator for all
  proportions (including the non-NA levels) **includes** the NA count, so the
  column sums to 100% across all rows including the NA row. This matches
  `table(x, useNA = "always")` semantics. NA appears as the last row regardless
  of factor ordering.
- If the entire focal variable is NA and `na.rm = FALSE`, the function errors
  with `surveycore_error_all_na`.
- With `na.rm = TRUE` and all values `NA`, the function returns a 0-row
  tibble and fires `surveycore_warning_all_na_freqs`.
- For `survey_twophase`, uses two-phase linearization via `R/06-variance-twophase.R`
  (Phase 0.75 complete).
- For `survey_srs`, proportions use the standard SRS variance formula.
- For `survey_nonprob`, standard errors use the weighted SRS approximation
  (conservative; SEs may be slightly overstated compared to proper calibration
  variance, which requires Phase 2.5).

---

## IV. `get_means()`

### 4.1 Signature

```r
get_means(
  design,
  x,                              # tidy-select; single numeric variable
  group        = NULL,
  variance     = "ci",
  conf_level   = 0.95,
  n_weighted   = FALSE,           # add weighted population count column
  min_cell_n   = 30L,             # warning threshold for small cells (AAPOR default)
  na.rm        = TRUE,
  label_values = TRUE,
  label_vars   = TRUE,
  name_style   = "surveycore"
)
```

### 4.2 Output Structure

The variable name is **not** a column. It is stored in `meta(result)$variable`.
Group columns (if any) appear first.

**Output columns:**
```
[group_names...]   mean   [se]   [var]   [cv]   [ci_low]   [ci_high]   [moe]   [deff]   n   [n_weighted]
```

Column order for variance columns follows the Section 2.6 canonical ordering:
`se`, `var`, `cv`, `ci_low`, `ci_high`, `moe`, `deff`. `n` and `[n_weighted]`
are always last.

- `mean`: weighted mean estimate.
- `n`: unweighted count of non-NA observations used in the estimate.
- `n_weighted`: sum of weights for non-NA observations in the group. Only
  present when `n_weighted = TRUE`.

**Examples:**
```r
get_means(d, income)
# attr: variable = "income", variable_label = "Annual household income ($000s)"
  mean      n
  52.3    500

get_means(d, income, variance = "ci")
  mean   ci_low  ci_high     n
  52.3    50.7    53.9     500

get_means(d, income, group = region, variance = "ci")
  region   mean   ci_low  ci_high    n
1 East     54.1    51.7    56.5    122
2 North    48.3    45.5    51.1    140
3 South    53.7    51.4    56.0    120
4 West     53.1    50.4    55.8    118

get_means(d, income, variance = "se", name_style = "broom")
  estimate   std.error     n
    52.3        0.83     500
```

### 4.3 AAPOR-Compliant Call

```r
get_means(d, income,
  variance   = c("ci", "moe"),
  n_weighted = TRUE
)
```

### 4.4 Statistical Details

- Uses `.taylor_mean()` / `.replicate_mean()` / `.srs_mean()` /
  `.calibrated_mean()` dispatched by design class via `R/06-variance-dispatch.R`;
  engine implementations live in `R/06-variance-taylor.R`,
  `R/06-variance-replicate.R`, and `R/06-variance-srs.R` respectively.
- `survey_srs`: uses standard SRS variance formula (`s²/n × (1-f)`; `f = 0`
  when FPC unknown).
- `survey_nonprob`: uses weighted SRS approximation (conservative).
- `survey_twophase`: uses two-phase linearization via `R/06-variance-twophase.R`
  (Phase 0.75 complete).
- `x` must resolve to a single numeric column. Throws
  `surveycore_error_non_numeric_variable` if the column is not numeric.

---

## V. `get_totals()`

### 5.1 Signature

```r
get_totals(
  design,
  x            = NULL,            # tidy-select; single numeric variable OR NULL
  group        = NULL,
  variance     = "ci",
  conf_level   = 0.95,
  n_weighted   = FALSE,           # add weighted population count column
  min_cell_n   = 30L,             # warning threshold for small cells (AAPOR default)
  na.rm        = TRUE,
  label_values = TRUE,
  label_vars   = TRUE,
  name_style   = "surveycore"
)
```

### 5.2 Behavior

`get_totals()` computes an **estimated population sum** — the weighted total
of a numeric variable across the entire population the design represents.

**Two modes:**

| Call | What is estimated | Statistic |
|---|---|---|
| `get_totals(d)` | Population size | `Σ w_i` |
| `get_totals(d, income)` | Total income in population | `Σ w_i × income_i` |

`get_totals()` only accepts **numeric** variables. For population counts broken
down by a categorical variable, use `get_totals(d, group = sex)` — sex as a
grouping variable, not the summed variable.

The variable name is stored in `meta(result)$variable` (`NULL` for the
no-variable case). Group columns appear first.

**Output columns:**
```
[group_names...]   total   [se]   [var]   [cv]   [ci_low]   [ci_high]   [moe]   [deff]   [n]   [n_weighted]
```

- `total`: the weighted sum estimate.
- `n`: unweighted count of non-NA observations (omitted for no-variable mode).
- `n_weighted`: sum of weights for non-NA observations in the group. For
  `get_totals(d)` (no variable), equals `total` — included for API uniformity.
  Only present when `n_weighted = TRUE`.

**Examples:**
```r
# Population size
get_totals(d)
# attr: variable = NULL
  total          ci_low       ci_high
  13,000,000   12,757,000   13,243,000

# Population by group
get_totals(d, group = region, variance = "ci")
  region   total        ci_low      ci_high
1 East     3,380,000   3,247,000   3,513,000
2 North    3,640,000   3,481,000   3,799,000
3 South    3,120,000   2,971,000   3,269,000
4 West     2,860,000   2,721,000   2,999,000

# Total of a numeric variable
get_totals(d, income, variance = "ci")
# attr: variable = "income"
  total          ci_low       ci_high     n
  623,491,000  607,176,000  639,806,000  500

# Total by group
get_totals(d, income, group = region, variance = "ci")
  region   total         ci_low       ci_high    n
1 East     171,822,000   165,470,000  178,174,000  122
```

### 5.3 AAPOR-Compliant Call

```r
get_totals(d, income,
  variance   = c("ci", "moe"),
  n_weighted = TRUE
)
```

### 5.4 Statistical Details

- Uses `.taylor_total()` / `.replicate_total()` / `.srs_total()` /
  `.calibrated_total()` dispatched by design class via `R/06-variance-dispatch.R`;
  engine implementations live in `R/06-variance-taylor.R`,
  `R/06-variance-replicate.R`, and `R/06-variance-srs.R` respectively.
- No-variable mode: equivalent to `svytotal(~1, design)`.
- Variable mode: equivalent to `svytotal(~x, design)`.
- `survey_srs`: uses standard SRS variance formula.
- `survey_nonprob`: uses weighted SRS approximation (conservative).
- `survey_twophase`: uses two-phase linearization via `R/06-variance-twophase.R`
  (Phase 0.75 complete).
- Throws `surveycore_error_non_numeric_variable` if a non-numeric variable is
  supplied.

---

## VI. `get_corr()`

### 6.1 Signature

```r
get_corr(
  design,
  x,                              # tidy-select; 2+ numeric variables required
  format       = c("long", "wide"),
  redundant    = FALSE,           # if FALSE: lower triangle only (no A-B and B-A)
  diagonal     = FALSE,           # if FALSE: exclude self-correlations
  variance     = "ci",            # NULL or character vector: "se","ci","var","cv","moe","deff"
  conf_level   = 0.95,
  n_weighted   = FALSE,           # add pairwise weighted n column
  min_cell_n   = 30L,             # warning threshold for small pairwise n (AAPOR default)
  na.rm        = TRUE,
  label_values = TRUE,
  label_vars   = TRUE,            # use variable labels in var1/var2 columns
  name_style   = "surveycore"
)
```

### 6.2 Output Structure — Long Format (default)

**Output columns:**
```
var1   var2   r   [se]   [var]   [cv]   [ci_low]   [ci_high]   [moe]   [deff]   p_value   statistic   df   n   [n_weighted]
```

Always-present columns: `var1`, `var2`, `r`, `p_value`, `statistic`, `df`, `n`.
Variance columns (bracketed) are conditional on the `variance` argument, following
the Section 2.6 canonical ordering: `se`, `var`, `cv`, `ci_low`, `ci_high`, `moe`,
`deff`. `[n_weighted]` is last when present.

- `var1`, `var2`: variable names (character). When `label_vars = TRUE`
  (default) and variable labels are set in metadata, these cells show labels
  instead of raw names. Falls back to raw names if unset or
  `label_vars = FALSE`.
- `r`: correlation coefficient.
- `p_value`: two-tailed p-value. Always present.
- `statistic`: t-statistic. Always present and visible.
- `df`: degrees of freedom for the t-test. Always present and visible.
- `n`: **pairwise** unweighted sample size. With `na.rm = TRUE`, different
  pairs may have different `n` due to variable-specific missing data. Always present.
- `n_weighted`: pairwise weighted n — sum of weights for rows where both
  variables in the pair are non-NA. Only present when `n_weighted = TRUE`.
- `method`: stored in `meta(result)$method`, not a column.

**`redundant = FALSE` (default):** each pair appears once (lower triangle).
For a 3-variable input `c(a, b, c)`, rows are: `(a,b)`, `(a,c)`, `(b,c)`.
`(b,a)`, `(c,a)`, `(c,b)` are excluded.

**Examples:**
```r
get_corr(d, x = c(income, bmi, age))
  var1    var2     r    ci_low  ci_high  p_value  statistic    df     n
1 income  bmi    0.24    0.15    0.33    <0.001     5.12      498   500
2 income  age    0.31    0.23    0.39    <0.001     7.35      498   500
3 bmi     age    0.08   -0.01    0.17     0.077     1.78      496   498

# n differs for bmi-age (2 missing bmi values, na.rm = TRUE)

get_corr(d, x = c(income, bmi), variance = "se")
  var1    var2     r      se   p_value  statistic    df     n
1 income  bmi    0.24   0.046   <0.001     5.12      498   500

get_corr(d, x = c(income, bmi, age), redundant = TRUE)
  var1    var2        r     ...
1 income  bmi       0.24   ...
2 income  age       0.31   ...
3 bmi     income    0.24   ...   # mirrored
4 bmi     age       0.08   ...
5 age     income    0.31   ...   # mirrored
6 age     bmi       0.08   ...   # mirrored
```

### 6.3 Output Structure — Wide Format

```r
get_corr(d, x = c(income, bmi, age), format = "wide")
  variable   income   bmi      age
1 income        NA    0.24    0.31
2 bmi          0.24    NA     0.08
3 age          0.31   0.08     NA
```

- First column: `variable` (the row variable names). Respects `label_vars` —
  when `label_vars = TRUE` and variable labels are set in metadata, labels
  are used instead of raw names; falls back to raw names if unset or
  `label_vars = FALSE`.
- Cell values: `r` (correlation). Redundant cells (upper triangle when
  `redundant = FALSE`) are `NA`.
- Diagonal: `NA` when `diagonal = FALSE` (default).
- **Wide format contains only the correlation matrix (`r` values).** All other
  columns — `p_value`, `statistic`, `df`, `n`, and any variance columns (`se`,
  `var`, `cv`, `ci_low`, `ci_high`, `moe`) — are excluded. Use
  `format = "long"` to access inference statistics alongside correlation
  coefficients.

### 6.4 AAPOR-Compliant Call

```r
get_corr(d, x = c(income, bmi),
  variance   = c("ci", "moe"),
  n_weighted = TRUE
)
```

Pairwise weighted n appears in `n_weighted`; small-cell warnings fire when
pairwise `n < min_cell_n` (default 30).

### 6.5 Statistical Details

- **Phase 1 scope: Pearson correlation only.** Spearman and Kendall are
  deferred to Phase 2. The `method` argument is not exposed in Phase 1;
  `meta(result)$method` is always `"pearson"`.
- **Implementation — variance-covariance approach:** Pearson correlation is
  computed via the design-based variance-covariance matrix:
  `r(X, Y) = Cov(X, Y) / sqrt(Var(X) × Var(Y))`. The SE of `r` is derived
  using the delta method applied to the variance of `(Var(X), Cov(X,Y),
  Var(Y))` from the survey design's linearization or replicate machinery.
  This is consistent with srvyr's implementation via `survey::svyvar()`.
- **Educational context only (SRS case):** For a simple random sample,
  `se_r ≈ sqrt(1/(n-3))` via the Fisher Z transform, back-transformed to the
  r scale. The actual implementation always uses the design-based
  variance-covariance approach above, which reduces to this formula for
  SRS-equivalent designs.
- **CI:** Fisher Z CI back-transformed to the correlation scale.
- **p-value:** Two-tailed from `t = r × sqrt(n-2) / sqrt(1 - r²)` with
  `df = n - 2`.
- **Numerical oracle:** `survey::svyvar()` is the oracle for both the
  correlation estimate (`r`, tolerance `1e-10`) and the SE (tolerance `1e-8`)
  for all design types — Taylor, replicate, and SRS. This replaces the
  structural-only oracle previously specified for complex designs.
- `survey_srs`: uses SRS variance formula for the covariance.
- `survey_nonprob`: uses weighted SRS approximation.
- `survey_twophase`: uses two-phase linearization via `R/06-variance-twophase.R`
  (Phase 0.75 complete).
- **`surveycore_warning_small_cell` for `get_corr()`:** fires when any
  variable pair's pairwise `n < 30` (AAPOR public-reporting guidance). The
  pairwise `n` is the count of rows where both variables in the pair are
  non-NA. Different pairs may have different `n` due to variable-specific
  missing data.
- **Variable dropping and insufficient-variable check ordering:** Non-numeric
  variables in `x` are silently dropped first (with
  `surveycore_warning_corr_non_numeric` fired per dropped variable). The
  insufficient-variable check occurs *after* dropping. If fewer than 2 numeric
  variables remain, `surveycore_error_insufficient_variables` is thrown — in
  addition to any `surveycore_warning_corr_non_numeric` warnings already fired.
  Example: `get_corr(d, x = c(income, sex, region))` where `sex` and `region`
  are character → both warnings fire, then the error fires (1 numeric variable
  remaining).

---

## VII. `get_quantiles()`

### 7.1 Signature

```r
get_quantiles(
  design,
  x,                              # tidy-select; single numeric variable
  probs        = c(0.25, 0.5, 0.75),
  group        = NULL,
  variance     = "ci",
  conf_level   = 0.95,
  n_weighted   = FALSE,           # add weighted population count column
  min_cell_n   = 30L,             # warning threshold for small cells (AAPOR default)
  na.rm        = TRUE,
  label_values = TRUE,
  label_vars   = TRUE,
  name_style   = "surveycore"
)
```

### 7.2 Output Structure

Variable name stored in `meta(result)$variable`.

**Output columns:**
```
[group_names...]   quantile   estimate   [se]   [var]   [cv]   [ci_low]   [ci_high]   [moe]   [deff]   n   [n_weighted]
```

- `quantile`: label string — `"p25"`, `"p50"`, `"p75"`, etc. (derived from
  `probs`: 0.25 → `"p25"`, 0.5 → `"p50"`, 0.333 → `"p33"`).
- `estimate`: quantile estimate.
- `n`: unweighted count of non-NA observations.
- `n_weighted`: sum of weights for non-NA observations in the group. Only
  present when `n_weighted = TRUE`.
- Column order for variance columns follows the Section 2.6 canonical ordering:
  `se`, `var`, `cv`, `ci_low`, `ci_high`, `moe`, `deff`.

**Examples:**
```r
get_quantiles(d, income, probs = c(0.25, 0.5, 0.75))
# attr: variable = "income"
  quantile  estimate  ci_low  ci_high     n
1 p25         38.2    35.1    41.3      500
2 p50         51.4    48.7    54.1      500
3 p75         66.8    63.2    70.4      500

get_quantiles(d, income, probs = 0.5, group = region)
  region  quantile  estimate  ci_low  ci_high    n
1 East    p50         54.1    49.2    59.0     122
2 North   p50         47.3    42.1    52.5     140
3 South   p50         52.8    47.5    58.1     120
4 West    p50         51.2    46.0    56.4     118
```

### 7.3 AAPOR-Compliant Call

```r
get_quantiles(d, income,
  variance   = c("ci", "moe"),
  n_weighted = TRUE
)
```

### 7.4 Statistical Details

- Quantile variance estimation uses Woodruff's method (linearization of the
  CDF), implemented via **vendored internal functions** extracted from
  `survey::svyquantile()` — consistent with the independence principle in
  `CLAUDE.md` ("no runtime dependency on survey or srvyr packages"). Add GPL
  attribution in `R/13-analysis-quantiles.R` as with all vendored code. The
  vendored quantile helpers are separate from the existing variance engines in
  `R/06-variance-taylor.R` / `R/06-variance-replicate.R` / `R/06-variance-srs.R`
  and live in `R/13-analysis-quantiles.R` directly.
  Before implementing, read the survey package source to scope the vendoring;
  the relevant internals are `svyquantile()`, `oldsvyquantile()`, and their
  helper `wtd.quantile()`.
- CIs use the survey package's default interpolation-based method for quantile
  CIs (same method as `survey::svyquantile(ci = TRUE)`).
- `survey_srs`: uses SRS Woodruff variance.
- `survey_nonprob`: uses weighted SRS approximation.
- `survey_twophase`: uses Woodruff variance with the two-phase design structure
  from `R/06-variance-twophase.R` (Phase 0.75 complete).

---

## VIII. `get_ratios()`

### 8.1 Signature

```r
get_ratios(
  design,
  numerator,                      # tidy-select; single numeric variable
  denominator,                    # tidy-select; single numeric variable
  group        = NULL,
  variance     = "ci",
  conf_level   = 0.95,
  n_weighted   = FALSE,           # add weighted population count column
  min_cell_n   = 30L,             # warning threshold for small cells (AAPOR default)
  na.rm        = TRUE,
  label_values = TRUE,
  label_vars   = TRUE,
  name_style   = "surveycore"
)
```

### 8.2 Output Structure

Both variable names stored in `meta(result)$numerator` and
`meta(result)$denominator`.

**Output columns:**
```
[group_names...]   ratio   [se]   [var]   [cv]   [ci_low]   [ci_high]   [moe]   [deff]   n   [n_weighted]
```

Column order for variance columns follows the Section 2.6 canonical ordering:
`se`, `var`, `cv`, `ci_low`, `ci_high`, `moe`, `deff`. `n` and `[n_weighted]`
are always last.

- `ratio`: estimated ratio = weighted total of numerator / weighted total of denominator.
- `n`: unweighted count of rows where both numerator and denominator are non-NA.
- `n_weighted`: sum of weights for rows where both numerator and denominator
  are non-NA. Only present when `n_weighted = TRUE`.
- Numerator and denominator variable names are stored in `meta(result)$numerator`
  and `meta(result)$denominator` — they are not output columns.

**Example:**
```r
get_ratios(d, numerator = hospital_visits, denominator = person_years)
# meta(result)$numerator   = "hospital_visits"
# meta(result)$denominator = "person_years"
  ratio     se    ci_low  ci_high     n
  0.143   0.012    0.119   0.167    500

get_ratios(d, hospital_visits, person_years, group = region)
  region   ratio     se    ci_low  ci_high    n
1 East     0.161   0.021    0.120   0.202   122
```

### 8.3 AAPOR-Compliant Call

```r
get_ratios(d, numerator = hospital_visits, denominator = person_years,
  variance   = c("ci", "moe"),
  n_weighted = TRUE
)
```

### 8.4 Statistical Details

- Equivalent to `survey::svyratio()`.
- Variance via the delta method for ratios: linearized as
  `y_i - R * x_i` where R is the full-sample ratio estimate.
- `survey_srs`: uses delta method with SRS variance.
- `survey_nonprob`: uses weighted SRS approximation.
- `survey_twophase`: uses delta method with two-phase linearization via
  `R/06-variance-twophase.R` (Phase 0.75 complete).
- Throws `surveycore_error_non_numeric_variable` if either variable is
  non-numeric.

---

## IX. `get_diffs()` — Deferred to Phase 2

`get_diffs()` is **out of Phase 1 scope**. It is deferred to Phase 2 alongside
`survey_glm()` because its correct implementation requires bivariate regression
for statistically valid standard errors.

**Why not implement via `get_means()` subtraction:**
Subtracting two `get_means()` estimates produces incorrect standard errors
because it ignores the covariance between the two estimates. This covariance
is negative in stratified designs, meaning the naive SE is too large, p-values
too conservative, and CIs too wide. The correct SE requires the variance of
the contrast vector from `survey_glm()`.

**Phase 2 design (reserved):**

```r
# Phase 2 signature
get_diffs(
  design,
  x,                              # outcome variable (numeric)
  treats,                         # grouping variable (factor/character)
  covariates  = NULL,             # RESERVED: tidy-select, deferred to Phase 3
  ref_level   = NULL,             # reference level; default = first level
  pval_adj    = c("none", "holm", "BH", "bonferroni"),
  show_means  = TRUE,             # show unadjusted group means alongside diffs
  conf_level  = 0.95,
  group       = NULL,
  na.rm       = TRUE,
  name_style  = "surveycore"
)
```

When `covariates = NULL` (Phase 2): runs `survey_glm(x ~ factor(treats))` and
extracts contrasts relative to `ref_level`. The `show_means = TRUE` column
shows **unadjusted** weighted group means from `get_means()`.

When `covariates` are specified (Phase 3+): runs
`survey_glm(x ~ factor(treats) + covariates)`. The unadjusted means are still
shown unless covariate-adjusted means (average marginal effects via
`marginaleffects`) are explicitly requested — a Phase 3/4 decision.

---

## X. Error and Warning Classes

All new errors and warnings follow the convention in `plans/error-messages.md`.
The following classes are introduced in Phase 1:

| Class | Trigger | Type |
|---|---|---|
| `surveycore_error_non_numeric_variable` | Non-numeric column passed to `get_means()`, `get_totals()`, `get_corr()`, `get_ratios()` | Error |
| `surveycore_error_insufficient_variables` | Fewer than 2 variables passed to `get_corr()` | Error |
| `surveycore_error_invalid_variance_arg` | Unknown value for `variance` argument | Error |
| `surveycore_error_invalid_conf_level` | `conf_level` not a single number in (0, 1) | Error |
| `surveycore_error_invalid_name_style` | Unknown value for `name_style` argument | Error |
| `surveycore_error_invalid_probs` | `probs` outside (0,1) or length 0 | Error |
| `surveycore_error_ratio_zero_denominator` | All denominator values are zero | Error |
| `surveycore_warning_small_cell` | Any cell has unweighted `n < min_cell_n` (default `30L`, AAPOR public-reporting guidance; set `min_cell_n = 50` for stricter federal agency standards). For `get_corr()`, "cell" means a variable pair; the threshold applies to pairwise `n`. | Warning |
| `surveycore_warning_single_level` | A grouping variable has only one observed level | Warning |
| `surveycore_warning_corr_non_numeric` | Non-numeric variable in `x` silently dropped | Warning |
| `surveycore_warning_mixed_prefaces` | Variables passed to `get_freqs()` multi-var have different non-NULL question prefaces | Warning |
| `surveycore_error_all_na` | Focal variable is all `NA` with `na.rm = FALSE` in `get_freqs()`. For categorical variables, every value being NA means there are no levels to tabulate — no fallback exists. Numeric functions (`get_means()`, etc.) do not throw this error; with `na.rm = FALSE` and NAs present, survey machinery propagates `NA` to the result naturally. | Error |
| `surveycore_error_invalid_conf_level` | `conf_level` is not a single number strictly between 0 and 1 | Error |
| `surveycore_warning_cv_undefined` | `variance = "cv"` requested but estimate is 0 or negative (applies to all `get_*()` functions) | Warning |
| `surveycore_warning_all_na_freqs` | All values of focal variable are `NA` with `na.rm = TRUE` in `get_freqs()`; returns 0 rows | Warning |

---

## XI. Test Strategy

### 11.1 Numerical Validation (Oracle Tests)

Every function except `get_corr()` is validated against `survey::` with
strict tolerances. These tests live in `test-analysis-*.R` and always call
`skip_if_not_installed("survey")`.

| Function | Oracle | Datasets |
|---|---|---|
| `get_means()` | `survey::svymean()` | nhanes_2017, synthetic (make_survey_data) |
| `get_totals()` | `survey::svytotal()` | nhanes_2017, synthetic |
| `get_freqs()` | `survey::svymean()` on indicator | nhanes_2017, synthetic |
| `get_quantiles()` | `survey::svyquantile()` | nhanes_2017, synthetic |
| `get_ratios()` | `survey::svyratio()` | nhanes_2017, synthetic |
| `get_corr()` | Two-tier (see below) | synthetic (numerical), nhanes_2017 + replicate (structural) |

**Numerical tolerances (from Phase 0 testing standards):**

| Estimand | Tolerance |
|---|---|
| Point estimates (mean, total, pct, ratio, quantile) | `1e-10` |
| Standard errors | `1e-8` |
| CI bounds | `1e-6` |

**`get_corr()` oracle — `survey::svyvar()`:**

`survey::svyvar()` is the oracle for all design types (Taylor, replicate,
SRS). The correlation is derived as
`r = vcov[1,2] / sqrt(vcov[1,1] * vcov[2,2])` where `vcov` is the
design-based variance-covariance matrix from `survey::svyvar(~c(x,y), design)`.
SE is derived from `vcov(svyvar_result)` via the delta method.

```r
sv       <- survey::svyvar(~ c(x, y), d_sv)
r_oracle <- sv[1, 2] / sqrt(sv[1, 1] * sv[2, 2])

# Delta method SE: gradient of r = b/sqrt(a*c) w.r.t. (a, b, c)
sigma     <- vcov(sv)   # 3×3 vcov of (Var(X), Cov(X,Y), Var(Y))
a         <- sv[1, 1]; b <- sv[1, 2]; c <- sv[2, 2]
g         <- c(-r_oracle / (2 * a), 1 / sqrt(a * c), -r_oracle / (2 * c))
se_oracle <- sqrt(as.numeric(t(g) %*% sigma %*% g))

expect_equal(get_corr(d_sc, c(x, y))$r,                  r_oracle,  tolerance = 1e-10)
expect_equal(get_corr(d_sc, c(x, y), variance = "se")$se, se_oracle, tolerance = 1e-8)
```

This oracle works for both Taylor and replicate designs, unlike
`survey::svycor()` which has limited complex-design support.

### 11.2 Test Categories Per Function

Infrastructure tests for shared helpers (`.build_meta()`, `.make_result_tibble()`,
`.apply_name_style()`, `.validate_shared_args()`, `.resolve_groups()`,
`.apply_domain()`) live in `test-analysis-helpers.R` and run independently of
any single function. Per-function test files call these helpers via the public
`get_*()` API.

#### `test_result_invariants(result, expected_class)`

Defined in `tests/testthat/helper-test-data.R`. Called as the **first
assertion** in every happy-path test block that creates a result object — the
direct parallel to `test_invariants()` for design objects.

```r
test_result_invariants <- function(result, expected_class) {
  # 1. Correct S3 class hierarchy
  expect_true(inherits(result, expected_class))
  expect_true(inherits(result, "survey_result"))
  expect_true(tibble::is_tibble(result))
  # 2. meta() returns non-NULL list
  m <- meta(result)
  expect_false(is.null(m))
  expect_type(m, "list")
  # 3. Required meta keys always present (never absent)
  expect_true(all(
    c("design_type", "conf_level", "call", "group_names", "group_labels")
    %in% names(m)
  ))
  # 4. group_names is always character vector (never NULL)
  expect_type(m$group_names, "character")
  # 5. value_labels always populated and is a non-empty named list
  expect_true("value_labels" %in% names(m))
  expect_type(m$value_labels, "list")
  expect_gt(length(m$value_labels), 0L)
  expect_false(is.null(names(m$value_labels)))
  # 6. n_respondents always present and is a positive integer
  expect_true("n_respondents" %in% names(m))
  expect_type(m$n_respondents, "integer")
  expect_gt(m$n_respondents, 0L)
}
```

Add this function to `helper-test-data.R` before writing any test file.

#### Per-function test categories

Every function's test file covers:

1. **Happy path** — basic call, correct class, correct columns; call
   `test_result_invariants(result, "survey_*")` as the first assertion.
2. **Numerical oracle** — point estimates and SEs match `survey::` within
   tolerance for both Taylor and replicate designs (`skip_if_not_installed("survey")`).
3. **Grouped analysis** — `group =` argument; `@groups` via `group_by()`;
   both ANDed (`skip_if_not_installed("surveytidy")`); deduplication when the
   same variable appears in both.
4. **Domain estimation** — three-way oracle (`skip_if_not_installed("survey")`
   and `skip_if_not_installed("surveytidy")`):
   - Point estimate matches `survey::` domain estimation (e.g.
     `survey::svymean(~y, subset(sv_design, condition))`) within `1e-10`
   - SE matches `survey::` domain SE within `1e-8`
   - SE is **strictly greater than** the SE from physical subsetting (proves
     domain estimation is not silently implemented as physical subsetting)
   Also verify: `n` counts in-domain non-NA rows only; `surveycore_warning_small_cell`
   fires when the domain produces cells with n < 30.

   **3-way combination test** (domain + groups simultaneously): add one block
   per function using both `surveytidy::filter()` (domain) AND
   `surveytidy::group_by()` (groups) on the same design object. Verify:
   - Result has correct number of rows (`n_groups × n_in_domain_levels`)
   - `n` counts only in-domain, non-NA-group rows
   - SE > SE from physical subsetting
   - `skip_if_not_installed("surveytidy")`
5. **`variance` argument** — each value (`NULL`, `"se"`, `"ci"`, `"moe"`);
   correct columns present/absent.
6. **`label_values`** — correct label conversion when labels set on focal
   variable and on group variables; fallback to raw when unset.
7. **`label_vars`** — variable labels appear in `names_to` column
   (`get_freqs()` multi-var) and `var1`/`var2` columns (`get_corr()`) when
   labels set; raw names when unset or `label_vars = FALSE`; argument accepted
   without error on the 4 no-op functions.
8. **`meta()` contract** — all fields present and correctly populated
   (`design_type`, `conf_level`, `call`, `group_names`, `group_labels`,
   `variable`/`variables`, `variable_label`/`variable_labels`,
   `question_preface`/`question_prefaces`, `value_labels`); `NULL` behavior
   correct for unlabeled metadata; **`value_labels` populated regardless of
   `label_values`** — explicitly call with `label_values = FALSE` and assert
   `meta(result)$value_labels` is still populated.
9. **`name_style = "broom"`** — correct column renames.
10. **Error paths** — every row in the error table (Section X) covered.
11. **Edge cases** — single group level, all-NA column, n=1 group, zero-weight
    rows, very small design.
12. **Multi-variable** (`get_freqs()` only) — `names_to` uses variable labels;
    fallback; stacking; `surveycore_warning_mixed_prefaces` fires when prefaces
    differ.

### 11.3 Edge Cases Requiring Explicit Tests

- `get_freqs()`: variable with a single level → 1 row, 100%
- `get_freqs()`: all NA variable with `na.rm = TRUE` → 0 rows result, warning
- `get_freqs()`: focal variable all NA with `na.rm = FALSE` →
  `surveycore_error_all_na`. (Numeric functions do not throw this error —
  with `na.rm = FALSE`, NAs propagate to the result naturally.)
- `get_totals()`: no variable (`get_totals(d)`) → population size equals sum of weights
- `get_corr()`: exactly 2 variables → 1 row output
- `get_corr()`: `redundant = TRUE` → symmetric pairs present
- `get_corr()`: pairwise n differs across pairs
- `get_quantiles()`: single prob → 1 row per group
- `get_ratios()`: denominator near zero → `surveycore_error_ratio_zero_denominator`
- `get_freqs()` multi-variable: variable with label vs without label in same call
- `get_freqs()` multi-variable: variables with different non-NULL prefaces → `surveycore_warning_mixed_prefaces`
- `get_freqs()` multi-variable: all variables share the same preface → no warning
- `get_corr()`: `label_vars = TRUE` with labels set → labels in `var1`/`var2`; `label_vars = FALSE` → raw names
- All functions: `meta()$value_labels` is `NULL` for numeric variables; named vector for labelled categorical
- All functions: grouped call where one group has n < 30 → `surveycore_warning_small_cell`
- All functions: same variable in both `@groups` and `group=` → silently
  deduplicated by `.resolve_groups()`; result has one column for that variable,
  not two; no warning fired
- All functions: `NA` values in the grouping variable → those rows excluded
  from all groups; they do not appear in the output and are not counted in
  `n`; no warning fired (consistent with `dplyr::group_by()` semantics)

---

## XI.5 AAPOR Compliance

The following argument combination produces AAPOR-compliant output for all six
`get_*()` functions:

```r
# AAPOR-compliant call pattern (applies to all six functions)
get_means(d, income,
  variance   = c("ci", "moe"),  # confidence interval + margin of error
  n_weighted = TRUE,            # weighted population count alongside unweighted n
  min_cell_n = 30L              # default; set to 50 for stricter federal standards
)
```

| Element | Argument | AAPOR requirement |
|---|---|---|
| Confidence interval | `variance = "ci"` | Required for publishable estimates |
| Margin of error | `variance = "moe"` | Required for many published tables |
| Weighted N | `n_weighted = TRUE` | Weighted population count for table context |
| Unweighted N | `n` column (always present) | Base count for reliability assessment |
| Small-cell warning | fires at `n < min_cell_n` (default 30) | Flag unreliable cells |

`meta(result)$n_respondents` carries the total sample size for the table
header (e.g., "Total N = 1,234"). This is a scalar reflecting the full design,
independent of grouping.

Each function section includes an **AAPOR-compliant call** example. Do not
add an `aapor_format` argument — encoding AAPOR conventions as a flag creates
a maintenance burden as standards evolve.

---

## XII. Quality Gates

Phase 1 is complete when all of the following pass:

- [ ] `devtools::check()` returns 0 errors, 0 warnings, ≤ 2 notes
- [ ] All numerical oracle tests pass (point: 1e-10, SE: 1e-8)
- [ ] Test coverage ≥ 98% line coverage for all new Phase 1 files
- [ ] All 6 functions work correctly with `survey_taylor` and `survey_replicate`
- [ ] All 6 functions dispatch on `survey_twophase` (Phase 0.75 complete)
- [ ] `get_freqs()` multi-variable mode works with and without variable labels
- [ ] `name_style = "broom"` produces columns matching broom conventions
- [ ] `variance` argument works for all 6 functions
- [ ] Groups from `@groups` and `group =` are correctly ANDed
- [ ] Domain estimation (via `filter()`) three-way oracle passes: point ≈ `survey::` on domain, SE ≈ `survey::` domain SE, SE > physical-subsetting SE
- [ ] `label_vars = TRUE` shows variable labels in `names_to` (`get_freqs()` multi-var) and `var1`/`var2` (`get_corr()`)
- [ ] `label_vars = FALSE` shows raw variable names in all cases
- [ ] `meta()` returns a correctly structured list for all 6 functions
- [ ] `meta()$value_labels` populated regardless of `label_values` argument (tested explicitly with `label_values = FALSE`)
- [ ] `meta()$question_preface` / `question_prefaces` populated when set; `NULL` when unset
- [ ] `surveycore_warning_mixed_prefaces` fires when `get_freqs()` multi-var variables have different non-NULL prefaces
- [ ] Phase 0 stubs (`get_means()`, `get_totals()` in R/06) removed and `test-variance-estimation.R` updated in one atomic PR; CI green before merge
- [ ] `plans/error-messages.md` updated with all Phase 1 error/warning classes (including `surveycore_error_invalid_conf_level`)
- [ ] `tests/testthat/helper-test-data.R` extended with `test_result_invariants()`

---

## XIII. Integration with surveytidy (Phase 0.5)

**Phase 0.5 is complete.** The `surveytidy` package (`../surveytidy`) ships
`group_by()`, `ungroup()`, and `filter()` for survey design objects.

Phase 1 functions read two things set by surveytidy:

1. **`design@groups`** — set by `surveytidy::group_by()`; character vector of
   column names. Always `character(0)` when `group_by()` has not been called.
2. **`SURVEYCORE_DOMAIN_COL` column** (`"..surveycore_domain.."`) — set by
   `surveytidy::filter()`; logical vector (`TRUE` = in-domain). Absent from
   `@data` when `filter()` has not been called.

Phase 1 does not **require** surveytidy to be installed. Graceful fallbacks:
- `@groups = character(0)` → ungrouped
- No domain column → all rows in-domain

#### surveytidy contract details (for Phase 1 implementors)

- `filter()` stores the domain mask as a **logical vector** (not 0/1 integer).
  Multiple `filter()` calls AND their conditions together — the column is
  updated in-place.
- `group_by()` stores resolved column names in `@groups`. The underlying
  `@data` is **not** a `grouped_df` — there is no `dplyr::group_vars()` to call
  on `@data`. Read `@groups` directly.
- `group_by(.add = TRUE)` appends to existing `@groups`; `ungroup()` clears it.

#### Integration testing

Tests that use surveytidy features (grouped analysis, domain estimation) must
add `skip_if_not_installed("surveytidy")` at the block level. Use real
surveytidy calls — `surveytidy::group_by()`, `surveytidy::filter()` — rather
than manually setting `@groups` or adding the domain column directly.

```r
test_that("get_means() respects @groups from group_by()", {
  skip_if_not_installed("surveytidy")
  d_grouped <- surveytidy::group_by(d, region)
  result    <- get_means(d_grouped, income)
  test_result_invariants(result, "survey_means")
  expect_equal(nrow(result), length(unique(d@data$region)))
})
```

---

*End of Phase 1 Formal Specification*
