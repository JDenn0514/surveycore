# surveycore Phase 1 — Formal Specification

**Version:** 1.0
**Date:** February 2026
**Status:** Approved for Implementation

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
`R/06-variance-estimation.R` are **replaced** by full implementations in new
files. The stub code is removed once the new implementations are merged.

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
├── 09-analysis-helpers.R     # Shared internal helpers (Section 2.2)
├── 10-analysis-freqs.R       # get_freqs()
├── 11-analysis-means.R       # get_means(), get_totals()
├── 12-analysis-corr.R        # get_corr()
├── 13-analysis-quantiles.R   # get_quantiles(), get_ratios()
└── (06-variance-estimation.R stubs removed)

tests/testthat/
├── test-analysis-helpers.R   # .build_meta(), meta(), .make_result_tibble(), .apply_name_style()
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

| Function | Required keys in `meta_args` |
|---|---|
| `get_freqs()` single-var | `mode = "single"`, `variable`, `variable_label`, `question_preface`, `value_labels` |
| `get_freqs()` multi-var | `mode = "multi"`, `variables`, `variable_labels`, `question_prefaces`, `value_labels` |
| `get_means()` | `variable`, `variable_label`, `question_preface`, `value_labels` |
| `get_totals()` | `variable`, `variable_label`, `question_preface`, `value_labels` |
| `get_corr()` | `variables`, `variable_labels`, `question_prefaces`, `method` |
| `get_quantiles()` | `variable`, `variable_label`, `question_preface`, `value_labels`, `probs` |
| `get_ratios()` | `numerator`, `numerator_label`, `denominator`, `denominator_label`, `question_prefaces` |

`value_labels` is always a **named list** — one key per variable, value is a
named vector of label → raw value mappings, or `NULL` for numeric/unlabelled
variables. Single-variable functions supply `list(var_name = c(...))` or
`list(var_name = NULL)`.

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

### 2.3 The `meta()` Generic (R/09-analysis-helpers.R)

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
| `design_type` | `character(1)` | `"taylor"` \| `"replicate"` \| `"twophase"` |
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

The `survey_result` class owns `print()` and `format()` — subclasses do not
need their own print methods unless their output requires special rendering
(only `survey_corr` has a non-default print due to hidden columns; see
Section VII).

### 2.6 Cross-Cutting Arguments

These arguments appear on every `get_*()` function with identical semantics:

| Argument | Type | Description |
|---|---|---|
| `group` | tidy-select | Additional grouping variables; ANDed with `@groups` |
| `variance` | character or NULL | Which uncertainty measure to include in output columns |
| `conf_level` | numeric (0,1) | Confidence level for CIs and MOE; default `0.95` |
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

#### The `variance` argument

Controls which uncertainty columns appear in the output tibble.

| Value | Columns added |
|---|---|
| `NULL` | None — no uncertainty columns |
| `"se"` | `se` |
| `"ci"` | `ci_low`, `ci_high` |
| `"moe"` | `moe` (margin of error = half CI width = `qt(...) * se`) |
| `"both"` | `se`, `ci_low`, `ci_high` (get_corr() only) |

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
  variance     = NULL,            # NULL | "se" | "ci" | "moe"
  conf_level   = 0.95,
  n_weighted   = FALSE,           # add weighted population count column
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
[variable_name]   pct    n    [se]    [ci_low  ci_high]    [moe]    [n_weighted]
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
[group_names...]   [names_to]   [values_to]   pct    n    [variance cols]
```

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

### 3.5 Statistical Details

- Proportions are computed as `svymean()` applied to a binary (0/1) indicator
  per level, or equivalently via the Taylor/replicate variance machinery in
  `R/06-variance-estimation.R`.
- `pct = proportion × 100`. All variance quantities (se, ci, moe) are on the
  percentage scale as well (i.e., `se` is SE of the percentage, not the
  proportion).
- With `na.rm = TRUE` (default), NA values in the variable are excluded from
  all counts and proportions. NA does not appear as a level.
- The n column counts non-NA respondents when `na.rm = TRUE`.

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
[group_names...]   mean   [se]   [ci_low  ci_high]   [moe]   n
```

- `mean`: weighted mean estimate.
- `n`: unweighted count of non-NA observations used in the estimate.

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

### 4.3 Statistical Details

- Uses `.taylor_mean()` / `.replicate_mean()` from `R/06-variance-estimation.R`.
- Throws `surveycore_error_unsupported_class` for `survey_twophase` (Phase 1
  scope; twophase estimation is Phase 3).
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
[group_names...]   total   [se]   [ci_low  ci_high]   [moe]   n
```

- `total`: the weighted sum estimate.
- `n`: unweighted count of non-NA observations (omitted for no-variable mode).

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

### 5.3 Statistical Details

- Uses `.taylor_total()` / `.replicate_total()` from `R/06-variance-estimation.R`.
- No-variable mode: equivalent to `svytotal(~1, design)`.
- Variable mode: equivalent to `svytotal(~x, design)`.
- Throws `surveycore_error_non_numeric_variable` if a non-numeric variable is
  supplied.
- Throws `surveycore_error_unsupported_class` for `survey_twophase`.

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
  variance     = "ci",            # NULL | "se" | "ci" | "both"
  conf_level   = 0.95,
  na.rm        = TRUE,
  label_values = TRUE,
  label_vars   = TRUE,            # use variable labels in var1/var2 columns
  name_style   = "surveycore"
)
```

### 6.2 Output Structure — Long Format (default)

**Default visible columns:**
```
var1   var2   r   ci_low   ci_high   p_value   n
```

**Always computed and present in the underlying tibble** (accessible via
`$`, `select()`, `glimpse()`) **but hidden by the print method:**
```
statistic   df
```

To expose them in the printed output, call `print(result, details = TRUE)`.

- `var1`, `var2`: variable names (character). When `label_vars = TRUE`
  (default) and variable labels are set in metadata, these cells show labels
  instead of raw names. Falls back to raw names if unset or
  `label_vars = FALSE`.
- `r`: correlation coefficient.
- `ci_low`, `ci_high`: confidence interval bounds.
- `p_value`: two-tailed p-value.
- `n`: **pairwise** sample size. With `na.rm = TRUE`, different pairs may have
  different `n` due to variable-specific missing data.
- `statistic`: t-statistic (hidden by default).
- `df`: degrees of freedom for the t-test (hidden by default).
- `method`: stored in `meta(result)$method`, not a column.

**`redundant = FALSE` (default):** each pair appears once (lower triangle).
For a 3-variable input `c(a, b, c)`, rows are: `(a,b)`, `(a,c)`, `(b,c)`.
`(b,a)`, `(c,a)`, `(c,b)` are excluded.

**`variance = "both"`:** includes `se`, `ci_low`, and `ci_high` columns.

**Examples:**
```r
get_corr(d, x = c(income, bmi, age))
  var1    var2     r    ci_low  ci_high  p_value     n
1 income  bmi    0.24    0.15    0.33    <0.001    500
2 income  age    0.31    0.23    0.39    <0.001    500
3 bmi     age    0.08   -0.01    0.17     0.077    498

# n differs for bmi-age (2 missing bmi values, na.rm = TRUE)

print(result, details = TRUE)
  var1    var2     r    ci_low  ci_high  p_value  statistic    df     n
1 income  bmi    0.24    0.15    0.33    <0.001     5.12      498   500

get_corr(d, x = c(income, bmi), variance = "se")
  var1    var2     r      se   p_value     n
1 income  bmi    0.24   0.046   <0.001   500

get_corr(d, x = c(income, bmi, age), redundant = TRUE)
  var1    var2     r     ...
1 income  bmi    0.24   ...
2 income  age    0.31   ...
3 bmi     income  0.24  ...   # mirrored
4 bmi     age    0.08   ...
5 age     income  0.31  ...   # mirrored
6 age     bmi    0.08   ...   # mirrored
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
- No uncertainty columns in wide format.

### 6.4 Statistical Details

- **Phase 1 scope: Pearson correlation only.** Spearman and Kendall are
  deferred to Phase 2. The `method` argument is not exposed in Phase 1;
  `meta(result)$method` is always `"pearson"`.
- SE computed via the Fisher Z transform delta method:
  `se_r = sqrt(1 / (n - 3))` in the Z space, back-transformed.
- CI: Fisher Z CI back-transformed to correlation scale.
- p-value: two-tailed from `t = r * sqrt(n-2) / sqrt(1 - r^2)` with `df = n - 2`.
- For `survey_taylor` and `survey_replicate`, variance uses the design's
  linearization or replicate machinery rather than the simple 1/(n-3) formula.
- Throws `surveycore_error_insufficient_variables` if fewer than 2 variables
  are supplied.
- Throws `surveycore_error_unsupported_class` for `survey_twophase`.

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
[group_names...]   quantile   estimate   [ci_low   ci_high]   [se]   [moe]   n
```

- `quantile`: label string — `"p25"`, `"p50"`, `"p75"`, etc. (derived from
  `probs`: 0.25 → `"p25"`, 0.5 → `"p50"`, 0.333 → `"p33"`).
- `estimate`: quantile estimate.
- `n`: unweighted count of non-NA observations.

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

### 7.3 Statistical Details

- Uses `survey::svyquantile()` linearization internally (via vendored or
  equivalent logic).
- CIs via the `survey` package's default method for quantile CIs
  (interpolation-based).
- Throws `surveycore_error_unsupported_class` for `survey_twophase`.

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
[group_names...]   ratio   [se]   [ci_low  ci_high]   [moe]   n
```

- `ratio`: estimated ratio = weighted total of numerator / weighted total of denominator.
- `n`: unweighted count of rows where both numerator and denominator are non-NA.
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

### 8.3 Statistical Details

- Equivalent to `survey::svyratio()`.
- Variance via the delta method for ratios: linearized as
  `y_i - R * x_i` where R is the full-sample ratio estimate.
- Throws `surveycore_error_unsupported_class` for `survey_twophase`.
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
| `surveycore_error_invalid_name_style` | Unknown value for `name_style` argument | Error |
| `surveycore_error_invalid_probs` | `probs` outside (0,1) or length 0 | Error |
| `surveycore_error_ratio_zero_denominator` | All denominator values are zero | Error |
| `surveycore_warning_small_cell` | Any cell has unweighted `n < 5` | Warning |
| `surveycore_warning_single_level` | A grouping variable has only one observed level | Warning |
| `surveycore_warning_corr_non_numeric` | Non-numeric variable in `x` silently dropped | Warning |
| `surveycore_warning_mixed_prefaces` | Variables passed to `get_freqs()` multi-var have different non-NULL question prefaces | Warning |
| `surveycore_error_all_na` | Focal variable is all `NA` with `na.rm = FALSE` (applies to all numeric `get_*()` functions) | Error |

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

**`get_corr()` two-tier oracle:**

1. **Numerical tier** — simple SRS-equivalent synthetic design
   (`make_survey_data()` with no PSU clustering, equal weights). `r` matches
   `survey::svycor()` within `1e-10`; SE matches within `1e-8`. This works
   because `survey::svycor()` is fully applicable to simple designs.

2. **Structural tier** — NHANES Taylor design and a replicate design. Checks
   that: `r` is in (-1, 1); CI is narrower than ±1; `p_value` is consistent
   with `t = r * sqrt(n-2) / sqrt(1 - r^2)` within numerical precision. No
   numerical oracle — `survey::svycor()` has limited support for complex
   designs.

### 11.2 Test Categories Per Function

Infrastructure tests for shared helpers (`.build_meta()`, `meta()`,
`.make_result_tibble()`, `.apply_name_style()`) live in
`test-analysis-helpers.R` and run independently of any single function.
Per-function test files call these helpers via the public `get_*()` API.

Every function's test file covers:

1. **Happy path** — basic call, correct class, correct columns, `test_invariants()` does not apply (result is not a survey object) but result is a valid tibble with the right class.
2. **Numerical oracle** — point estimates and SEs match `survey::` within tolerance for both Taylor and replicate designs.
3. **Grouped analysis** — `group =` argument; `@groups` via `group_by()`; both ANDed.
4. **Domain estimation** — `filter()` then analysis; verify `n` counts in-domain non-NA rows only; verify SE uses the full design (not the filtered subset) by comparing against physical subsetting; confirm `surveycore_warning_physical_subset` fires on physical subset; `surveycore_warning_small_cell` fires when the domain produces cells with n < 5.
5. **`variance` argument** — each value (`NULL`, `"se"`, `"ci"`, `"moe"`); correct columns present/absent.
6. **`label_values`** — correct label conversion when labels set on focal variable and on group variables; fallback to raw when unset.
7. **`label_vars`** — variable labels appear in `names_to` column (`get_freqs()` multi-var) and `var1`/`var2` columns (`get_corr()`) when labels set; raw names when unset or `label_vars = FALSE`; argument accepted without error on the 4 no-op functions.
8. **`meta()` contract** — all fields present and correctly populated (`design_type`, `conf_level`, `call`, `group_names`, `group_labels`, `variable`/`variables`, `variable_label`/`variable_labels`, `question_preface`/`question_prefaces`, `value_labels`); `NULL` behavior correct for unlabeled metadata; `value_labels` populated regardless of `label_values`.
9. **`name_style = "broom"`** — correct column renames.
10. **Error paths** — every row in the error table (Section X) covered.
11. **Edge cases** — single group level, all-NA column, n=1 group, zero-weight rows, very small design.
12. **Multi-variable** (`get_freqs()` only) — `names_to` uses variable labels; fallback; stacking; `surveycore_warning_mixed_prefaces` fires when prefaces differ.

### 11.3 Edge Cases Requiring Explicit Tests

- `get_freqs()`: variable with a single level → 1 row, 100%
- `get_freqs()`: all NA variable with `na.rm = TRUE` → 0 rows result, warning
- All numeric functions (`get_means()`, `get_totals()`, `get_corr()`,
  `get_quantiles()`, `get_ratios()`): focal variable all NA with
  `na.rm = FALSE` → `surveycore_error_all_na`
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
- All functions: grouped call where one group has n=1 → `surveycore_warning_small_cell`

---

## XII. Quality Gates

Phase 1 is complete when all of the following pass:

- [ ] `devtools::check()` returns 0 errors, 0 warnings, ≤ 2 notes
- [ ] All numerical oracle tests pass (point: 1e-10, SE: 1e-8)
- [ ] Test coverage ≥ 98% line coverage for all new Phase 1 files
- [ ] All 6 functions work correctly with `survey_taylor` and `survey_replicate`
- [ ] All 6 functions throw `surveycore_error_unsupported_class` for `survey_twophase`
- [ ] `get_freqs()` multi-variable mode works with and without variable labels
- [ ] `name_style = "broom"` produces columns matching broom conventions
- [ ] `variance` argument works for all 6 functions
- [ ] Groups from `@groups` and `group =` are correctly ANDed
- [ ] Domain estimation (via `filter()`) produces correct SEs vs. physical subsetting
- [ ] `label_vars = TRUE` shows variable labels in `names_to` (`get_freqs()` multi-var) and `var1`/`var2` (`get_corr()`)
- [ ] `label_vars = FALSE` shows raw variable names in all cases
- [ ] `meta()` returns a correctly structured list for all 6 functions
- [ ] `meta()$value_labels` populated regardless of `label_values` argument
- [ ] `meta()$question_preface` / `question_prefaces` populated when set; `NULL` when unset
- [ ] `surveycore_warning_mixed_prefaces` fires when `get_freqs()` multi-var variables have different non-NULL prefaces
- [ ] Phase 0 stubs (`get_means()`, `get_totals()` in R/06) removed and replaced
- [ ] `plans/error-messages.md` updated with all Phase 1 error/warning classes

---

## XIII. Dependencies on Phase 0.5 (surveytidy)

Phase 1 functions **read** two things set by surveytidy:

1. **`design@groups`** (set by `group_by()`) — read by `.resolve_groups()`
2. **`SURVEYCORE_DOMAIN_COL` column** (set by `filter()`) — read by `.apply_domain()`

Phase 1 does not **require** surveytidy to be installed or loaded. If neither
of these is set, the functions operate ungrouped and without domain
restriction — all Phase 1 functions work correctly without surveytidy present.

This means Phase 1 can be developed and tested independently of Phase 0.5
completion status. The integration is purely contractual: Phase 1 reads
slots that Phase 0.5 populates, but falls back gracefully when they are absent.

---

*End of Phase 1 Formal Specification*
