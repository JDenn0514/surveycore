# Spec: coef(), vcov(), SE(), and confint() Methods for survey_result Objects

**Version:** 1.4
**Date:** 2026-06-22
**Status:** SPEC_READY

---

## Document Purpose

This is the behavioral source of truth for adding `coef()`, `vcov()`, `SE()`,
and `confint()` S3 methods to surveycore's `survey_result` family. It also
specifies the `.make_result_tibble()` signature change and the
`.build_survey_result_attr()` internal helper that populates the structural
metadata attribute that makes all four methods possible. Builder implements
from this document only.

---

## I. Scope

### What this phase delivers

| Deliverable | Notes |
|---|---|
| `SE()` S3 generic (new) | Defined in `R/analysis-methods-coef-vcov.R` |
| `coef.survey_result()` | Extracts named estimate vector |
| `vcov.survey_result()` | Returns named variance-covariance matrix |
| `SE.survey_result()` | Returns named SE vector via `sqrt(diag(vcov()))` |
| `confint.survey_result()` | Returns CI matrix using t-distribution + stored df |
| `.build_survey_result_attr()` | Internal helper; builds `.survey_result` attribute |
| `.make_result_tibble()` signature change | Accepts two new parameters: `estimate_cols` and `statistic` |
| New `plans/error-messages.md` rows | Six new error entries: `SCR-1`, `SCR-3`, `SCR-W1`, `SCR-W2`, `SCR-W3`, `SCR-W4` (`SCR-2` reuses `surveycore_error_invalid_conf_level`) |

### What this phase does NOT deliver

- `as.data.frame.survey_result()` — tibble's own method is sufficient
- Changes to any `get_*()` function's output columns or estimation logic
- An `SE()` method for `survey_glm_fit` — that class already has `vcov.survey_glm_fit()`
- Support for `survey_t_test` or `survey_pairwise` — excluded by design (see §I.3)
- `nobs()`, `df.residual()`, or other model-like generics
- Changes to `survey_collection` dispatch behavior

### Result class support matrix

All result subclasses that inherit `survey_result` receive these methods
through the base `coef.survey_result()`, `vcov.survey_result()`, `SE.survey_result()`,
and `confint.survey_result()` dispatch. However, the attribute must be attached
at construction time. The following table maps each class to its `estimate_cols`
and `statistic` values.

| Result class | `estimate_cols` | `statistic` | `coef()`/`vcov()` scope |
|---|---|---|---|
| `survey_means` | `c("mean")` | `"mean"` | In scope |
| `survey_totals` | `c("total")` | `"total"` | In scope |
| `survey_freqs` | `c("pct")` | `"freq"` | In scope; `vcov()` is diagonal: `se^2` on the diagonal, `NA_real_` off-diagonal with `surveycore_warning_vcov_diagonal_only` emitted. Full cross-level covariance requires joint estimation from the original design, which is not available from stored data. |
| `survey_ratios` | `c("ratio")` | `"ratio"` | In scope |
| `survey_quantiles` | `c("estimate")` | `"quantile"` | In scope; `vcov()` is diagonal: `se^2` on the diagonal when `variance = "se"` is requested (same assembly as other classes). With `df = Inf` (standard for non-calibrated designs), `confint()` exactly reproduces Woodruff CI bounds algebraically. |
| `survey_corr` (long) | `c("r")` | `"corr"` | In scope (long format only); `vcov()` diagonal = `se_r^2`; off-diagonal = `NA_real_` (cross-pair covariances not computable from stored per-pair data; `cli::cli_warn()` emitted) |
| `survey_covariance` | `c("covariance")` | `"covariance"` | In scope |
| `survey_diffs` | `c("estimate")` | `"diffs"` | In scope |
| `survey_t_test` | — | — | **Out of scope** — already has `estimate`, `se`, `t_stat`, `df`, `p_value`; adding a parallel `coef()` path would create two incompatible representations of the same result |
| `survey_pairwise` | — | — | **Out of scope** — same rationale as `survey_t_test` |
| `survey_effective_n` | — | — | **Excluded by design** — no `estimate_cols` passed; `coef()` throws `surveycore_error_result_method_unsupported` |
| `survey_variance` | — | — | **Excluded by design** — no `estimate_cols` passed; `coef()` throws `surveycore_error_result_method_unsupported` |

For `survey_t_test` and `survey_pairwise`, `coef.survey_result()`,
`vcov.survey_result()`, etc. will be dispatched (because both classes inherit
`survey_result`), but will throw `surveycore_error_result_method_unsupported`
with a clear message directing users to the existing columns. This is
preferable to letting the methods silently fail by returning a wrong result.

Note: `survey_corr` in wide format also inherits `survey_result` but the
estimate column structure does not map cleanly to a named coefficient vector.
`coef()` on a wide-format `survey_corr` object will throw
`surveycore_error_result_method_unsupported`. Wide format is detected by the
absence of `estimate_cols` from `attr(x, ".survey_result")` — wide-format
corr results are not modified to carry this attribute.

---

## II. Architecture

### New file

```
R/analysis-methods-coef-vcov.R
```

This file contains:
1. `SE()` generic definition
2. `SE.default()` method
3. `coef.survey_result()`
4. `vcov.survey_result()`
5. `SE.survey_result()`
6. `confint.survey_result()`
7. `.build_survey_result_attr()` internal helper

### Modified files

```
R/analysis-helpers.R
```

`.make_result_tibble()` gains two new optional parameters with defaults that
preserve backward compatibility. The function calls `.build_survey_result_attr()`
internally when `estimate_cols` is supplied.

```
R/analysis-means.R
R/analysis-totals.R
R/analysis-freqs.R
R/analysis-ratios.R
R/analysis-quantiles.R
R/analysis-corr.R          (long format path only)
R/analysis-covariance.R
R/analysis-diffs.R
```

Each `get_*()` function passes `estimate_cols` and `statistic` through to
`.make_result_tibble()`. The changes are additive — no existing return values,
column names, or behavior change.

### Attribute layout

```
attr(result, ".survey_result") <- list(
  estimate_cols = character vector, one or more column names
  group_cols    = character vector, column names of group variables
  statistic     = character(1), human-readable statistic name
  df            = numeric vector of length p (one value per coef() parameter)
)
```

`$df` is a numeric vector of length `p = length(coef(object))`. For
non-calibrated Taylor, replicate, and nonprob designs, all entries are `Inf`
(`rep(Inf, p)`). For calibrated Taylor designs, entries hold the per-cell
degrees of freedom already computed by the `get_*()` function. This allows
`confint()` to use the correct df per parameter.

Note: `$var` was removed. `vcov()` recomputes from `se^2` on each call (O(p),
negligible cost). There is no lazy caching — `<<-` inside `vcov()` does not
propagate to the caller because tibble attributes are copied-on-modify.

---

## III. Function Contracts

### III.0 Shared preconditions (all four methods)

All four methods (`coef.survey_result()`, `vcov.survey_result()`,
`SE.survey_result()`, `confint.survey_result()`) share the same two
precondition checks, applied in this order before any other logic:

1. **Unsupported class check:** If `S7::S7_inherits(object, survey_t_test) ||
   S7::S7_inherits(object, survey_pairwise)`, throw
   `surveycore_error_result_method_unsupported` with the unsupported-class
   message template from §V SCR-1. Both class objects must be in scope.

2. **Absent attribute check:** If `is.null(attr(object, ".survey_result"))`,
   throw `surveycore_error_result_method_unsupported` with the absent-attribute
   message template from §V SCR-1.

§III.5 through §III.8 reference these preconditions as "See §III.0
preconditions" and do not restate them.

---

### III.1 `.build_survey_result_attr()`

Internal helper. Called by `.make_result_tibble()`.

**Signature:**

```r
.build_survey_result_attr(
  estimate_cols,
  group_cols,
  statistic,
  cell_df
)
```

**Arguments:**

| Argument | Type | Description |
|---|---|---|
| `estimate_cols` | `character` | Column name(s) of the point estimate(s) in the result tibble. Length >= 1. |
| `group_cols` | `character` | Column names of the grouping variables. `character(0)` when no groups. |
| `statistic` | `character(1)` | Short label for the statistic (e.g., `"mean"`, `"total"`, `"freq"`). |
| `cell_df` | `numeric` | Per-parameter degrees of freedom vector of length `p`. For non-calibrated designs, pass `rep(Inf, p)`. For calibrated Taylor, pass the per-cell df vector already computed by the `get_*()` function. |

**Returns:** A named list with elements `estimate_cols`, `group_cols`,
`statistic`, `df`. `$df` is `cell_df` stored as-is (caller is responsible
for correct values and `as.numeric()` coercion). Length = `p` (number of
coefficients).

Note: the `design` argument is removed. Callers now compute df before calling
`.build_survey_result_attr()`:
- Non-calibrated designs: `rep(Inf, p)`
- Calibrated Taylor: per-cell df vector from the calibrated CI computation

**Programmer-error guards:** Because `get_diffs()` calls this helper directly
(bypassing `.make_result_tibble()`), the helper must protect itself:

```r
stopifnot(
  length(estimate_cols) >= 1L,
  length(statistic) == 1L,
  !is.na(statistic)
)
```

These fire only on programmer error, not user error, so `stopifnot()` (not
`cli_abort()`) is appropriate.

Note: `cell_df` length (`== p`) is not validated here because `p` is not an
explicit parameter of this helper — the caller is responsible for passing a
correctly-sized `cell_df` vector. A future revision may add `p` as an explicit
parameter to enable a length guard inside the helper.

---

### III.2 `.make_result_tibble()` — signature change

Current signature:

```r
.make_result_tibble(
  col_vecs,
  groups_df,
  class_name,
  design,
  meta_args,
  required_meta_keys
)
```

New signature (three new optional parameters added at the end):

```r
.make_result_tibble(
  col_vecs,
  groups_df,
  class_name,
  design,
  meta_args,
  required_meta_keys,
  estimate_cols = NULL,
  statistic = NULL,
  cell_df = NULL
)
```

**New parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `estimate_cols` | `character` or `NULL` | `NULL` | Column name(s) of the point estimate(s) in `col_vecs`. When non-`NULL`, `.build_survey_result_attr()` is called and the result is attached as `attr(result, ".survey_result")`. |
| `statistic` | `character(1)` or `NULL` | `NULL` | Short statistic label forwarded to `.build_survey_result_attr()`. Required when `estimate_cols` is non-`NULL`; programmer error if one is supplied without the other. |
| `cell_df` | `numeric` or `NULL` | `NULL` | Per-parameter df vector of length `p`. When `NULL` and `estimate_cols` is non-`NULL`, defaults to `rep(Inf, p)` (non-calibrated designs). For calibrated Taylor designs, pass the per-cell df vector. |

**Behavior change:** When `estimate_cols` is `NULL` (the default), behavior is
identical to the current implementation. When `estimate_cols` is non-`NULL`,
`attr(result, ".survey_result")` is attached after the existing
`attr(result, ".meta")` assignment. `cell_df = NULL` defaults to
`rep(Inf, nrow(result) * length(estimate_cols))`.

**Programmer-error guard:** If exactly one of `estimate_cols` / `statistic` is
non-`NULL` and the other is `NULL`, the function must call `stopifnot()` with a
message that says both must be supplied together. This is a programmer error,
not a user error, so `stopifnot()` (not `cli_abort()`) is appropriate. Use the
named-condition form:

```r
stopifnot(
  "Both 'estimate_cols' and 'statistic' must be supplied together, or both must be NULL." = is.null(
    estimate_cols
  ) ==
    is.null(statistic)
)
```

---

### III.3 `SE()` generic

**Signature:**

```r
SE <- function(object, ...)
```

**Arguments:**

| Argument | Type | Default | Description |
|---|---|---|---|
| `object` | any | — | Object to extract standard errors from. |
| `...` | — | — | Passed to methods. |

**Returns:** Depends on the method. For `SE.default()`, see below.

**Masking note:** When both `surveycore` and `survey` are loaded, `surveycore::SE`
masks `survey::SE`. This is expected behavior — the default method
`SE.default(object, ...) sqrt(diag(vcov(object)))` covers most cases from
both packages. Users who need `survey::SE` explicitly can qualify the call.
`@importFrom survey SE` must NOT be added; `survey` is Suggests-only.

**Export:** `SE` must be exported via `@export` in roxygen2.

---

### III.4 `SE.default()`

**Signature:**

```r
SE.default <- function(object, ...)
```

**Arguments:**

| Argument | Type | Default | Description |
|---|---|---|---|
| `object` | any | — | Object to extract standard errors from. |
| `...` | — | — | Forwarded to `vcov()`. |

**Implementation:**

```r
SE.default <- function(object, ...) sqrt(diag(vcov(object, ...)))
```

**Returns:** `sqrt(diag(vcov(object, ...)))`. The default method relies on
`stats::vcov()` dispatch and forwards `...` to `vcov()`, so it works for any
object with a `vcov()` method. Forwarding `...` matches `survey::SE.default()`
and prevents silently dropped arguments when `surveycore::SE` masks `survey::SE`.

**Limitation:** `SE.default` is equivalent to `survey::SE.svystat` but NOT to
`survey::SE.svyby` or `survey::SE.svrepstat`. When `surveycore::SE` masks
`survey::SE`, users calling `SE()` on a `svyby` object with `vartype = "cvpct"`
will get the `SE.default` path (via `vcov()`), which may return incorrect or
`NA` SEs. Users mixing surveycore and survey objects should qualify with
`survey::SE()` in this case. Document this in the `SE()` roxygen `@note`.

---

### III.5 `coef.survey_result()`

**Signature:**

```r
coef.survey_result <- function(object, ...)
```

**Arguments:**

| Argument | Type | Default | Description |
|---|---|---|---|
| `object` | `survey_result` | — | A result object from any `get_*()` function. |
| `...` | — | — | Unused. Reserved for future extensions. |

**Returns:** A named numeric vector. Length equals the number of rows in
`object` times the number of `estimate_cols` in `attr(object, ".survey_result")`.

**Naming convention (Q1):** Names are constructed as follows:
- **Ungrouped, single estimate column:** bare row identifier, derived from the
  variable name stored in `attr(object, ".meta")$x` plus any quantile/level
  qualifier. When the statistic has no natural row identifier (e.g., a single
  mean with no groups), the name is simply the variable name.
- **Grouped, single estimate column:** `group_label:variable_name` — the colon
  separator matches `survey::svyby` convention. For single-`estimate_cols`
  classes (all current supported classes), variable-major and group-major
  orderings are identical.
- **Multiple estimate columns** (e.g., future extensions): names are
  `variable_name.column_name` for ungrouped; `group_label:variable_name.column_name`
  for grouped.

**Pair separator (survey_corr, survey_covariance):** The pair identifier
`var1.var2` uses `.` (not `:`) to avoid 3-token ambiguity in grouped names.
Grouped: `"Northeast:age.income"` — unambiguously parsed as group `:` pair.
All other classes that have multi-token row identifiers use `.` as the
intra-row separator (freqs: `variable.level`, quantiles: `variable.p25`).

**Detailed naming rules by result class:**

| Result class | Row identifier | Example name (ungrouped) | Example name (grouped by `region`) |
|---|---|---|---|
| `survey_means` | variable name from `.meta$x` | `"bpxsy1"` | `"Northeast:bpxsy1"` |
| `survey_totals` | variable name from `.meta$x`; when `.meta$x` is `NULL` (no-variable / population-size mode), the name is `"N"` | `"bpxsy1"` (or `"N"` in no-variable mode) | `"Northeast:bpxsy1"` |
| `survey_freqs` | `variable_name.level` (one entry per level) | `"riagendr.1"`, `"riagendr.2"` | `"Northeast:riagendr.1"` |
| `survey_ratios` | `numerator/denominator` pattern from `.meta` | `"income/persons"` | `"Northeast:income/persons"` |
| `survey_quantiles` | `variable_name.quantile_label` | `"age.p25"`, `"age.p50"` | `"Northeast:age.p25"` |
| `survey_corr` (long) | `var1.var2` — derived from `as.character(object[["var1"]])` and `as.character(object[["var2"]])` (factor columns in the result tibble; contains label when `label_vars = TRUE`) | `"age.income"` | `"Northeast:age.income"` |
| `survey_covariance` | `var1.var2` — same derivation as `survey_corr` (long): from tibble factor columns `object[["var1"]]` and `object[["var2"]]` | `"age.income"` | `"Northeast:age.income"` |
| `survey_diffs` | `treatment_level - reference_level` (full contrast label) | `"Treatment_A - Control"` | `"region_A:Treatment_A - Control"` |

For `survey_freqs`, the level identifier is the raw data value (not the
label), coerced to character, to ensure stable names across environments.
If the result has been processed with `label_values = TRUE`, the raw values
are still used for `coef()` naming to guarantee stability.

**Order:** Variable-major, matching `survey::svyby()` / `coef.svyby()` convention.
For a grouped result with groups A, B, C and variables x, y: the order is
A:x, B:x, C:x, A:y, B:y, C:y. For all current supported classes
(`length(estimate_cols) == 1`), variable-major and group-major orderings are
identical — the distinction only matters when multiple estimate columns are
added in a future extension.

**NA handling:** If an estimate cell is `NA` or `NaN`, the corresponding
position in the returned vector is `NA_real_`. The name is still assigned.

**Phase guard:** If `length(attr(object, ".survey_result")$estimate_cols) > 1L`,
throw an internal error: `stop("multi-estimate-column coef() not yet supported")`.
All current classes have `length(estimate_cols) == 1L`.

**Zero-row results:** See §VII for the required `character(0)` dimnames
construction when the result has zero rows.

**Preconditions:** See §III.0 preconditions (unsupported class check + absent
attribute check).

---

### III.6 `vcov.survey_result()`

**Signature:**

```r
vcov.survey_result <- function(object, ...)
```

**Arguments:**

| Argument | Type | Default | Description |
|---|---|---|---|
| `object` | `survey_result` | — | A result object from any `get_*()` function. |
| `...` | — | — | Unused. |

**Returns:** A numeric matrix. Both `rownames` and `colnames` are identical to
`names(coef(object))`. Dimensions are `p × p` where `p = length(coef(object))`.

**Preconditions:** See §III.0 preconditions (unsupported class check + absent
attribute check).

**Phase guard:** If `length(attr(object, ".survey_result")$estimate_cols) > 1L`,
throw an internal error: `stop("multi-estimate-column vcov() not yet supported")`.
All current classes have `length(estimate_cols) == 1L`.

**Assembly from result tibble:** The variance-covariance matrix is assembled
from the `se` column (when present) and the block-diagonal structure (Q5).

Assembly logic:
1. Extract the `se` column from `object`. If absent, return a matrix of `NA_real_`
   with correct names (see §VII for the absent-`se` edge case).
2. Coerce `NaN` to `NA_real_` before squaring: `se[is.nan(se)] <- NA_real_`.
   Per-row variance = `se^2`. See §VII for `NaN` in `se` column edge case.
3. For grouped results: assemble as a block-diagonal matrix. Within each group
   block, behavior depends on the result class:
   - **`survey_freqs`:** Diagonal = `se^2` per level. Off-diagonal = `NA_real_`.
     Full cross-level covariance requires joint influence-function estimation from
     the original design object, which is not available from stored per-row data
     at `vcov()` call time. The general p > 1 warning (see Off-diagonal warning
     below) covers this case.
   - **`survey_corr` (long format):** Diagonal = `se_r^2` per pair. Off-diagonal
     = `NA_real_` for all cross-pair positions, with a `cli::cli_warn()` emitted
     (class `surveycore_warning_vcov_incomplete`). Cross-pair covariances are not
     recoverable from per-pair stored data at `vcov()` call time.
   - **All other classes:** The block is diagonal (per-variable variances on the
     diagonal, zeros for within-group off-diagonal elements). This is an
     approximation when multiple variables share PSUs — cross-variable
     covariances within a group are not estimated from per-row `se` values (see
     §VII limitation note).
   Across groups, all elements are 0 (structural zeros). See §VII for the
   limitation this implies for cross-domain inference.
4. For ungrouped results: the matrix is diagonal with `se^2` on the diagonal,
   with the `survey_corr` exception above applying.
5. **DEFERRED — multi-estimate-column cases (future extension). DO NOT IMPLEMENT
   in this phase.** If `length(estimate_cols) > 1` is encountered, the phase
   guard in step 0 fires before reaching this code. For the record: when a class
   with `length(estimate_cols) > 1` is added in a future phase, the vcov()
   assembly must use joint influence-function estimation (calling the design's
   variance estimator jointly across all estimate columns in a block), matching
   `survey::vcov.svystat()` behavior for multi-variable `svymean()`. Structural
   zeros for within-group cross-variable covariances are NOT acceptable for that
   case. The variable-major block ordering in `names(coef(object))` must be
   preserved.

**Dimnames:** Both `rownames` and `colnames` of the returned matrix are
identical to `names(coef(object))`. Zero-row results: see §VII for the
required `character(0)` dimnames construction.

**No caching:** The variance matrix is computed fresh on each call via `se^2`
squaring. The O(p) computation cost is negligible, and `<<-` inside `vcov()`
would write to the wrong environment (tibble attributes are copied-on-modify,
so `object` is a local copy and any attribute assignment does not propagate to
the caller).

**Absent `se` column:** See §III.6 Absent `se` column edge case. When the `se`
column is absent, `vcov.survey_result()` returns a `p × p` matrix of `NA_real_`
with correct names and emits no warning.

**Off-diagonal warning:** Emit `cli::cli_warn()` with class
`surveycore_warning_vcov_diagonal_only` when `p > 1` (i.e., the result has
more than one parameter — grouped or ungrouped). Condition:
`length(coef(object)) > 1`.

Off-diagonal elements are structural zeros that may not reflect the true
covariance structure. This matches `survey::vcov.svyby()` convention which
always warns "Only diagonal elements of vcov() available." The warning is
suppressible with `suppressWarnings()`. See §V SCR-W2.

---

### III.7 `SE.survey_result()`

**Signature:**

```r
SE.survey_result <- function(object, ...)
```

**Arguments:**

| Argument | Type | Default | Description |
|---|---|---|---|
| `object` | `survey_result` | — | A result object from any `get_*()` function. |
| `...` | — | — | Unused. |

**Returns:** A named numeric vector. Names identical to `names(coef(object))`.
Values are `sqrt(diag(vcov(object)))` — extracted directly from the diagonal
of the variance matrix. NA entries propagate.

**Design rationale:** `SE.survey_result()` does not read the `se` column
directly; it goes through `vcov()` to ensure consistency between `SE()` and
`vcov()`. This prevents any drift between the two if caching or assembly logic
changes.

**Warning suppression:** The internal `vcov(object)` call must be wrapped in
`suppressWarnings()`. `vcov.survey_result()` emits
`surveycore_warning_vcov_diagonal_only` when `p > 1`, but that warning is not
meaningful in the `SE()` context — the caller asked for standard errors, not a
covariance matrix, so the off-diagonal structure is irrelevant. Users who need
to observe this warning should call `vcov(result)` directly. Document this in
the `SE.survey_result()` roxygen `@note`.

**Preconditions:** Delegates to `vcov.survey_result()`, which applies §III.0
preconditions and throws the appropriate error.

---

### III.8 `confint.survey_result()`

**Signature:**

```r
confint.survey_result <- function(object, parm, level = 0.95, ...)
```

**Preconditions:** Delegates to `coef.survey_result()`, which applies §III.0
preconditions and throws the appropriate error.

**Arguments:**

| Argument | Type | Default | Description |
|---|---|---|---|
| `object` | `survey_result` | — | A result object from any `get_*()` function. |
| `parm` | `numeric`, `character`, or missing | all parameters (when absent) | Subset of parameters. Integer positions or names. Use `missing(parm)` to detect absence — do not assign a default value. `confint.default` uses `missing()` and surveycore must match. |
| `level` | `numeric(1)` | `0.95` | Confidence level, strictly between 0 and 1. |
| `...` | — | — | Unused. |

**Returns:** A numeric matrix with two columns. Exact percentage column names
use `paste0(format(100 * (1 - level) / 2, trim = TRUE), " %")` and
`paste0(format(100 * (1 - (1 - level) / 2), trim = TRUE), " %")` — using
`format(..., trim = TRUE)` to match `stats::confint.default()` behavior and
suppress floating-point artifacts (e.g., `"2.5000000000001 %"`) for non-standard
`level` values. Uses the same `paste0(format(..., trim = TRUE), " %")` formula as
`stats::confint.default()`, producing identical output for any `level` value.
Rownames are `names(coef(object))[parm]`. Dimensions: `length(parm) × 2`.

**Degrees of freedom:** Read from `attr(object, ".survey_result")$df`, which
is a numeric vector of length `p`. For parameter `i` in `parm`, use `df[i]`.
When `df[i]` is `Inf`, `stats::qt(1 - (1 - level)/2, df = Inf)` equals
`stats::qnorm(1 - (1 - level)/2)` — no special-casing needed.

**`df` validation:** Before computing critical values, for each `i` in `parm`,
check `is.na(df[i]) || (is.finite(df[i]) && df[i] <= 0)`. If any element
fails, throw `surveycore_error_invalid_df` (see §V SCR-3). `df[i] = Inf` is
valid and common — the guard fires only for `NA` or finite non-positive values.

**Formula:** For each parameter `i` in `parm`:
```
lower[i] = coef(object)[i] - qt(1 - (1 - level)/2, df[i]) * SE(object)[i]
upper[i] = coef(object)[i] + qt(1 - (1 - level)/2, df[i]) * SE(object)[i]
```

**`parm` resolution:**
- Missing (detected with `missing(parm)`): all parameters (`seq_along(coef(object))`)
- Character vector: matched against `names(coef(object))` via `match()`;
  `NA` elements in `parm` are dropped before matching with a warning of class
  `surveycore_warning_parm_na` (see §VII). Unmatched names produce a warning of
  class `surveycore_warning_parm_unmatched` and are silently dropped. When all
  names are unmatched, returns a `0×2` matrix (see §VII).
- Integer/logical vector: used as index into `coef(object)`. Logical `parm`
  must have `length(parm) == length(coef(object))`; if not, throw
  `stop("logical 'parm' must have the same length as coef(object)")`.
- Empty (`character(0)` or `integer(0)`): returns a `0×2` matrix with
  `dimnames = list(character(0), c("2.5 %", "97.5 %"))` (see §VII).

**`level` validation:** Must satisfy: not `NA`, single numeric value, strictly
between 0 and 1. Explicitly check `is.na(level)` before the range check. Throw
`surveycore_error_invalid_conf_level` (reusing existing class from
`plans/error-messages.md` row 45a, adapting `{.arg conf_level}` →
`{.arg level}` in the message template) when any condition is violated.

**SE is `NA`:** When `SE(object)[i]` is `NA_real_`, the corresponding row in
the output matrix is `c(NA_real_, NA_real_)`. No additional warning.

---

## IV. Print behavior

No new print methods are added. The existing `print.survey_result()` (via tibble
print) is unchanged. The `.survey_result` attribute is stored with a
dot-prefixed name and is hidden from `print.survey_result()` output. No verbatim
example is required because no new print method is introduced and the existing
output is unchanged by this phase.

---

## V. Error Table

New error classes added by this phase. Must be added to `plans/error-messages.md`
before implementation.

| # | Function | Condition | Level | Error Class | cli Message Template |
|---|---|---|---|---|---|
| SCR-1 | `coef.survey_result()`, `vcov.survey_result()`, `SE.survey_result()`, `confint.survey_result()` | Object is `survey_t_test` or `survey_pairwise`, OR `.survey_result` attribute is `NULL`, OR estimate column not found (broom rename), OR wide-format `survey_corr` | ERROR | `surveycore_error_result_method_unsupported` | **Template 1 (unsupported class):** `"x" = "{.fn {fn_name}} is not supported for {.cls {class(object)[1L]}} objects.", "i" = "These result types have dedicated columns ({.field estimate}, {.field se}, {.field t_stat}, {.field df}, {.field p_value}). Access them directly.", "v" = "Use {.code result$estimate}, {.code result$se}, etc."` / **Template 2 (absent attribute):** `"x" = "{.fn {fn_name}} requires a {.cls survey_result} built with {.fn get_means}, {.fn get_totals}, or another supported {.fn get_*} function.", "i" = "The {.code .survey_result} metadata attribute is absent."` / **Template 3 (broom rename):** `"x" = "{.fn {fn_name}} cannot find estimate column {.field {estimate_col}} in {.cls {class(object)[1L]}}.", "i" = "Column was renamed by {.code name_style = \"broom\"}. The original column name {.field {estimate_col}} is stored in {.code attr(x, '.survey_result')$estimate_cols}.", "v" = "Call {.fn coef} before applying {.code name_style = \"broom\"}, or access the estimate directly."` / **Template 4 (wide-format corr):** `"x" = "{.fn {fn_name}} is not supported for wide-format {.cls survey_corr} objects.", "i" = "Wide-format correlation results do not have an {.code estimate_cols} mapping.", "v" = "Use {.code format = \"long\"} in {.fn get_corr} before calling {.fn {fn_name}}."` Note: Template 4 is triggered by `inherits(object, "survey_corr") && is.null(attr(object, ".survey_result"))`, checked before Template 2. |
| SCR-2 | `confint.survey_result()` | `level` is not a single numeric value strictly between 0 and 1 (or is `NA`) | ERROR | `surveycore_error_invalid_conf_level` | Reuses existing class from row 45a — adapt message: substitute `{.arg level}` for `{.arg conf_level}` in the row 45a template. |
| SCR-3 | `confint.survey_result()` | `df` stored in `.survey_result` attribute is finite and ≤ 0 | ERROR | `surveycore_error_invalid_df` | `"x" = "Design degrees of freedom must be positive (got {.val {df}}).", "i" = "The {.code .survey_result} attribute was constructed with {.code df = {df}}.", "v" = "Ensure the survey design has at least one degree of freedom."` |
| SCR-W1 | `vcov.survey_result()` | Called on a `survey_corr` result with more than one pair row | WARNING | `surveycore_warning_vcov_incomplete` | `"!" = "Off-diagonal elements of {.fn vcov} are {.code NA_real_} for {.cls survey_corr} results.", "i" = "Cross-pair covariances require joint estimation and are not available from per-pair stored data.", "i" = "Use {.code diag(vcov(result))} for per-pair variances, or {.code result$se} directly."` |
| SCR-W2 | `vcov.survey_result()` | Result has p > 1 parameters (grouped or ungrouped; off-diagonal elements are structural zeros) | WARNING | `surveycore_warning_vcov_diagonal_only` | `"!" = "Off-diagonal elements of {.fn vcov} are structural zeros (only diagonal variances are estimated).", "i" = "This matches {.fn survey::vcov.svyby} behavior.", "i" = "For joint multi-parameter inference, see {.fn survey::svycontrast}."` |

| SCR-W3 | `confint.survey_result()` | `parm` character vector contains `NA` elements | WARNING | `surveycore_warning_parm_na` | `"!" = "{.arg parm} contains {.val {sum(is.na(parm))}} {.code NA} element(s).", "i" = "{.code NA} elements are dropped before parameter selection."` |
| SCR-W4 | `confint.survey_result()` | `parm` character vector contains names not found in `names(coef(object))` | WARNING | `surveycore_warning_parm_unmatched` | `"!" = "{.arg parm} contains {.val {sum(is.na(m))}} name(s) not found in {.fn coef} output.", "i" = "Unmatched names: {.val {parm[is.na(m)]}}.", "i" = "These parameters are dropped. Check {.code names(coef(result))} for valid names."` |

Note: SCR-2 reuses `surveycore_error_invalid_conf_level`. SCR-1, SCR-3,
SCR-W1, SCR-W2, SCR-W3, and SCR-W4 are new rows in `plans/error-messages.md`.

---

## VI. Scope per get_*() call

**`cell_df` threading rule (applies to all `get_*()` functions):**
- Non-calibrated Taylor, replicate, and nonprob designs: pass `cell_df = NULL`
  (`.make_result_tibble()` will default to `rep(Inf, p)`).
- Calibrated Taylor designs: pass `cell_df = <per-cell df vector>`. The per-cell
  df vector is **always computed regardless of the `variance` argument** (even
  if the user calls `get_means(design, x, variance = "se")` with no CI columns).
  The vector is **row-aligned**: `cell_df[i]` corresponds to result row `i`.
  `NA_real_` df values from empty calibrated domains must be replaced with
  `Inf` before passing: `cell_df[is.na(cell_df)] <- Inf`.
  Builder should locate this computation in `R/analysis-means.R` (lines 238, 261
  per the methods review) and thread it through. The same pattern applies to
  `get_totals()`, `get_freqs()`, `get_ratios()`, `get_corr()`, and
  `get_covariance()`.

### `get_means()` — `.make_result_tibble()` call change

```
estimate_cols = c("mean"),
statistic = "mean"
```

`group_cols` is derived from `names(groups_df)` inside `.make_result_tibble()`.

### `get_totals()` — `.make_result_tibble()` call change

```
estimate_cols = c("total"),
statistic = "total"
```

In no-variable mode (population size estimation), `.meta$x` is `NULL`. The
`coef()` name in this case is `"N"` (total population size). When
`.meta$x` is set, the name is the variable name.

### `get_freqs()` — `.make_result_tibble()` call change

```
estimate_cols = c("pct"),
statistic = "freq"
```

In multi-variable mode (stacked long format), the `coef()` naming uses the
value of the `names_to` column combined with the `values_to` column:
`paste0(names_to_value, ".", values_to_value)` for each row.

### `get_ratios()` — `.make_result_tibble()` call change

```
estimate_cols = c("ratio"),
statistic = "ratio"
```

### `get_quantiles()` — `.make_result_tibble()` call change

```
estimate_cols = c("estimate"),
statistic = "quantile"
```

For quantile results, the `quantile` column (e.g., `"p25"`, `"p50"`) serves
as the row identifier in `coef()` naming: `variable_name.quantile_label`.

`vcov()` is assembled in the same way as all other classes: diagonal with
`se^2` on the diagonal when `variance = "se"` is requested; a matrix of
`NA_real_` when `se` is absent. Off-diagonal elements are structural zeros
(different quantiles are estimated independently).

With `df = Inf` stored in the attribute (standard for non-calibrated designs),
`confint()` uses `qnorm(1 - (1-level)/2)` as the critical value — the same
critical value used in the Woodruff CI construction. This means `confint()`
exactly reproduces the Woodruff `ci_low`/`ci_high` columns algebraically.

The only peculiarity is that `deff` is always `NA` for quantiles, which
does not affect `vcov()` or `confint()`.

### `get_corr()` (long format only) — `.make_result_tibble()` call change

```
estimate_cols = c("r"),
statistic = "corr"
```

Wide-format `survey_corr` objects are NOT passed `estimate_cols` (they pass
`estimate_cols = NULL`), so they do not get the `.survey_result` attribute.
All four methods (`coef()`, `vcov()`, `SE()`, `confint()`) on a wide-format
`survey_corr` object throw `surveycore_error_result_method_unsupported` via
SCR-1 Template 4 (see §V). Template 4 is triggered by `inherits(object,
"survey_corr") && is.null(attr(object, ".survey_result"))`, checked before
the generic absent-attribute throw (Template 2).

### `get_covariance()` — `.make_result_tibble()` call change

```
estimate_cols = c("covariance"),
statistic = "covariance"
```

### `get_diffs()` — requires a different approach

`get_diffs()` constructs its result tibble without going through
`.make_result_tibble()` (it sets the class directly at the end of the function).
The `.survey_result` attribute must be attached manually after the class is set.
The `estimate_cols` is `c("estimate")` and `statistic = "diffs"`. `group_cols`
is extracted as `names(attr(result, ".meta")$group)` — the group variable names
are the keys of the `$group` named list stored in the `.meta` attribute.
The `df` value is computed inside `get_diffs()` while `fit` is still in scope:
`df_val <- as.numeric(fit@degf)`, then pass `cell_df = rep(df_val, p)` to
`.build_survey_result_attr()`. Do not attempt to read `df_residual` from
metadata — that field does not exist in the current meta schema.

The `coef()` naming for `survey_diffs` uses `"treatment_level - reference_level"`
format, e.g. `"Treatment_A - Control"`. The reference level comes from
`meta(result)$treats$ref_level`.

**Row ordering requirement:** The result tibble rows must be in group-major
order before the `.survey_result` attribute is attached (group A's contrasts,
then group B's contrasts, etc.). If `get_diffs()` currently produces a
different row order, reorder the tibble before calling
`.build_survey_result_attr()`. This ensures `vcov()`'s block-diagonal assembly
is aligned with `coef()` output order.

---

## VII. Edge Cases

| Case | Behavior |
|---|---|
| Result has no `se` column (variance = NULL or not "se") | `vcov()` returns a `p×p` matrix of `NA_real_` with correct names, no warning; `SE()` returns `NA_real_` vector; `confint()` returns `NA_real_` matrix. |
| `NaN` in `se` column | Coerced to `NA_real_` before `vcov()` squaring (`se[is.nan(se)] <- NA_real_`). Treated identically to `NA_real_`. |
| Single-row result (one group level, one estimate) | `coef()` returns a length-1 named vector; `vcov()` returns a 1×1 matrix; no off-diagonal warning fires (p == 1). |
| All estimates are `NA` | `coef()` returns all-`NA_real_` named vector; `vcov()` returns all-`NA_real_` matrix. |
| Zero-row result (all-NA freqs with na.rm = TRUE) | `coef()` returns `named numeric(0)`; `vcov()` returns a `0×0` matrix with `dimnames = list(character(0), character(0))` — constructed as `matrix(numeric(0), nrow=0, ncol=0, dimnames=list(character(0), character(0)))`; `SE()` returns a named numeric(0) with `names(SE(result)) == character(0)`; `confint()` returns a `0×2` matrix with `dimnames = list(character(0), c("2.5 %", "97.5 %"))` — constructed as `matrix(numeric(0), nrow=0, ncol=2, dimnames=list(character(0), c("2.5 %", "97.5 %")))`. Note: `character(0)` dimnames (not `NULL`) — see §III.5 and §III.6 for the required construction. |
| `.survey_result` attribute is missing | See §III.0 preconditions — throws `surveycore_error_result_method_unsupported`. |
| `survey_t_test` or `survey_pairwise` object | See §III.0 preconditions — throws `surveycore_error_result_method_unsupported` with column-guidance message. |
| Wide-format `survey_corr` | See §VI `get_corr()` — throws `surveycore_error_result_method_unsupported` (SCR-1 Template 4). |
| `confint(level = 0)`, `confint(level = 1)`, `confint(level = NA)` | Throws `surveycore_error_invalid_conf_level`. `is.na(level)` is checked first, before the range check. |
| `df` stored in `.survey_result` attribute is `NA` or finite and ≤ 0 | `confint()` throws `surveycore_error_invalid_df` (guard: `is.na(df[i]) || (is.finite(df[i]) && df[i] <= 0)`; `df[i] = Inf` is valid and common). |
| `df = Inf` (replicate/nonprob, standard Taylor) | See §III.8 — `qt(1 - (1 - level)/2, df = Inf)` = `qnorm(1 - (1 - level)/2)`; no special-casing needed. |
| Grouped result with 0 groups (empty group column) | Treated as ungrouped; `coef()` uses bare variable names. |
| `parm = character(0)` or `parm = integer(0)` | `confint()` returns a `0×2` matrix with `dimnames = list(character(0), c("2.5 %", "97.5 %"))`. Matches `stats::confint.default` behavior. |
| `parm` contains `NA` elements | `NA` elements are dropped before parameter selection with warning class `surveycore_warning_parm_na`. |
| All `parm` names unmatched | Returns a `0×2` matrix with `dimnames = list(character(0), c("2.5 %", "97.5 %"))` after emitting `surveycore_warning_parm_unmatched`. |
| Cross-group `vcov()` zeros (grouped results with complex designs) | Cross-group elements are structural zeros. This is exact only when groups define non-overlapping strata with no shared PSUs. For domain estimation over a general grouping variable, cross-group covariances are non-zero and are not estimated from stored data. Users performing cross-domain Wald tests should use `survey::svycontrast()` on the original design. |
| Within-group cross-variable covariances (non-freqs classes) | When multiple estimate columns are added in a future extension, within-group cross-variable covariances are structural zeros — computed independently per variable from per-row `se` values. Full cross-variable joint covariance requires `survey::svymean(cbind(...))` on the original design. |

---

## VIII. Quality Gates

Done means all of the following are true:

- [ ] `R/analysis-methods-coef-vcov.R` exists and exports `SE`, `coef.survey_result`, `vcov.survey_result`, `SE.survey_result`, `confint.survey_result`
- [ ] `SE.survey_result` and `SE.default` are registered as S3 methods in `NAMESPACE` via roxygen2
- [ ] `coef.survey_result`, `vcov.survey_result`, `confint.survey_result` are registered as S3 methods in `NAMESPACE` via roxygen2
- [ ] `.make_result_tibble()` accepts `estimate_cols` and `statistic` without breaking any existing call sites (all new parameters have `NULL` defaults)
- [ ] All nine `get_*()` functions listed in §VI pass `estimate_cols` and `statistic` to `.make_result_tibble()`
- [ ] `get_diffs()` attaches `attr(result, ".survey_result")` manually
- [ ] `coef(get_means(d, age))` returns a named numeric vector with name `"age"` (ungrouped)
- [ ] `coef(get_means(d, age, group = region))` returns a named numeric vector with names `"A:age"`, `"B:age"`, etc.
- [ ] `vcov(get_means(d, age))` returns a 1×1 matrix with dimname `"age"`
- [ ] `confint(get_means(d, age))` returns a 1×2 matrix with rowname `"age"`
- [ ] `coef()` on a `survey_t_test` throws `surveycore_error_result_method_unsupported`
- [ ] `vcov()` on a `survey_corr` result with >1 pair row emits `surveycore_warning_vcov_incomplete` and returns `NA_real_` off-diagonal
- [ ] `vcov()` on any result with p > 1 emits `surveycore_warning_vcov_diagonal_only`
- [ ] `coef()` and `vcov()` on a zero-row result return `named numeric(0)` and a `0×0` matrix with `character(0)` dimnames (not `NULL` dimnames); `SE()` returns `named numeric(0)` with `names == character(0)`
- [ ] `confint()` with `df ≤ 0` or `df = NA_real_` stored in attribute throws `surveycore_error_invalid_df`
- [ ] `confint()` uses per-parameter `df[i]` from the `$df` vector (length p), not a scalar
- [ ] `survey_diffs` `coef()` names use `"Treatment_A - Control"` format (full contrast label)
- [ ] `attr(result, ".survey_result")$df` is a numeric vector of length p (not a scalar)
- [ ] Non-calibrated Taylor/replicate/nonprob results store `rep(Inf, p)` in `$df`
- [ ] Calibrated Taylor results store per-cell df vector in `$df`
- [ ] `surveycore_error_result_method_unsupported`, `surveycore_error_invalid_df`, `surveycore_warning_vcov_incomplete`, `surveycore_warning_vcov_diagonal_only`, `surveycore_warning_parm_na`, `surveycore_warning_parm_unmatched` added to `plans/error-messages.md`
- [ ] DEFERRED multi-estimate-column path fires `stop()` when `length(estimate_cols) > 1L`
- [ ] `error-messages.md` Coverage Map updated to include `test-analysis-methods-coef-vcov.R`
- [ ] `devtools::document()` run; NAMESPACE updated
- [ ] `devtools::check()` passes with 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] 98%+ line coverage on `R/analysis-methods-coef-vcov.R`

---

## IX. Integration

### survey package (Suggests)

`survey::SE()` is masked when both packages are loaded. This is expected and
follows standard R practice. `SE.default()` covers the `survey` use case.
No `@importFrom survey SE` is used anywhere.

### stats package (base)

`coef()` and `vcov()` generics are from `stats`. Register methods as
`coef.survey_result` and `vcov.survey_result`. Use `stats::qt()` in `confint`.
Use `stats::coef()` / `stats::vcov()` in default method calls only.

### broom package

If `name_style = "broom"` was used on the result before calling `coef()`,
the estimate column may have been renamed (e.g., `"mean"` → `"estimate"`).
`estimate_cols` is stored at construction time (before name_style renaming),
so it reflects the original column names. `coef()` must look up the column
using the original `estimate_cols` names, not the renamed ones. This means
`coef()` should read from `attr(object, ".survey_result")$estimate_cols` and
then find those columns in `object`. If a broom-renamed result is passed,
the column may not be found — throw `surveycore_error_result_method_unsupported`
with an explanatory message about name_style.

---

## X. Write Surface

| File | Change type |
|---|---|
| `R/analysis-methods-coef-vcov.R` | New file |
| `R/analysis-helpers.R` | Modify `.make_result_tibble()` signature; add `.build_survey_result_attr()` |
| `R/analysis-means.R` | Add `estimate_cols`, `statistic` to `.make_result_tibble()` call |
| `R/analysis-totals.R` | Add `estimate_cols`, `statistic` to `.make_result_tibble()` call |
| `R/analysis-freqs.R` | Add `estimate_cols`, `statistic` to `.make_result_tibble()` call |
| `R/analysis-ratios.R` | Add `estimate_cols`, `statistic` to `.make_result_tibble()` call |
| `R/analysis-quantiles.R` | Add `estimate_cols`, `statistic` to `.make_result_tibble()` call |
| `R/analysis-corr.R` | Add `estimate_cols`, `statistic` to long-format `.make_result_tibble()` call only |
| `R/analysis-covariance.R` | Add `estimate_cols`, `statistic` to `.make_result_tibble()` call |
| `R/analysis-diffs.R` | Attach `.survey_result` attribute manually after class assignment |
| `plans/error-messages.md` | Add rows SCR-1, SCR-3, SCR-W1, SCR-W2, SCR-W3, SCR-W4; update Coverage Map |
| `man/*.Rd` (generated) | Updated by `devtools::document()` |
| `NAMESPACE` (generated) | Updated by `devtools::document()` |

**Pipeline split:** recommended — new exported functions (`SE` generic + four
S3 methods), new numerical contract (`coef`/`vcov`/`confint`), touches 10 source
files.
