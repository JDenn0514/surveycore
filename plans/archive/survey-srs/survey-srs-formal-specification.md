# surveycore — `survey_srs` Formal Specification

**Version:** 1.0
**Date:** February 2026
**Status:** Authoritative — implementation must follow this document exactly.
**Branch:** `feature/survey-srs`

---

## Document Purpose

This document is the authoritative specification for the `survey_srs` class and
its supporting infrastructure: the `as_survey_srs()` constructor, `as_survey()`
dispatch updates, SRS variance estimation, and the `survey_srs` print method.
Every API contract, behavioral rule, and error condition is explicitly defined
here. No implementation decisions are left to judgment.

---

## I. Scope

### What this PR delivers

| Component | File | Status |
|---|---|---|
| `survey_srs` S7 class definition | `R/00-s7-classes.R` | Class body written; validator needs review |
| `as_survey_srs()` constructor | `R/03-constructors.R` | Not yet written |
| `as_survey()` dispatch to `survey_srs` | `R/03-constructors.R` | Not yet written |
| `survey_srs` print method | `R/04-methods-print.R` | Not yet written |
| `survey_srs` summary method | `R/04-methods-print.R` | Not yet written |
| `.srs_mean()` internal estimator | `R/06-variance-estimation.R` | Not yet written |
| `.srs_total()` internal estimator | `R/06-variance-estimation.R` | Not yet written |
| Dispatch in `get_means()`, `get_totals()` | `R/06-variance-estimation.R` | Not yet written |
| Tests: class + validator | `tests/testthat/test-s7-classes.R` | Not yet written |
| Tests: constructor | `tests/testthat/test-constructors.R` | Not yet written |
| Tests: print | `tests/testthat/test-methods-print.R` | Not yet written |
| Tests: variance estimation (oracle) | `tests/testthat/test-variance-estimation.R` | Not yet written |

### What this PR does NOT deliver

- Conversion methods (`as_svydesign()` / `from_svydesign()` for `survey_srs`) — deferred.
  The existing conversion code handles `survey_taylor` only; `survey_srs` conversion is
  complex because `survey::svydesign()` for SRS uses `ids = ~1` with no weights. Deferred
  to a follow-up chore PR before CRAN.
- `update_design()` for `survey_srs` — inherits from `survey_base`; works as-is.
- `get_freqs()`, `get_corr()`, `get_quantiles()`, `get_ratios()` for `survey_srs` — these
  are Phase 1. This PR only adds `get_means()` / `get_totals()` dispatch (the Phase 0 stubs).

---

## II. Design Rationale

`survey_srs` represents designs where every unit had an **equal probability** of
selection. The variance formula is the classical result:

```
var(ȳ) = (1 - f) × s² / n
```

where `s²` is the unweighted sample variance, `n` is the sample size, and
`f = n/N` is the sampling fraction (0 when population size is unknown).

This is conceptually and computationally distinct from `survey_taylor` (which
requires PSU/stratum structure) and `survey_calibrated` (which represents
non-probability or post-hoc-adjusted weights). Giving SRS its own class:

1. Makes the design declaration explicit and self-documenting
2. Avoids the performance overhead of the Taylor linearization code path
   for the common equal-probability case
3. Produces correct degrees of freedom (`n - 1` for SRS vs. `PSUs - strata`
   for clustered designs)
4. Enables informative error messages when users accidentally use SRS-specific
   functions on clustered designs or vice versa

---

## III. `survey_srs` S7 Class

### Class definition

```r
survey_srs <- S7::new_class(
  "survey_srs",
  parent     = survey_base,
  properties = list(),
  validator  = function(self) { ... }
)
```

`survey_srs` has no additional properties beyond those inherited from
`survey_base` (`@data`, `@metadata`, `@variables`, `@groups`, `@call`).

### `@variables` structure

All five standard keys must always be present. `survey_srs`-specific invariants:

| Key | Type | Value |
|---|---|---|
| `weights` | character or NULL | Name of the weight column, or `NULL` if auto-generated |
| `fpc` | character or NULL | Name of the FPC column, or `NULL` |
| `fpc_type` | character or NULL | `"population"`, `"fraction"`, or `NULL` when `fpc = NULL` |
| `probs_provided` | logical | `TRUE` if the user supplied probabilities; `FALSE` otherwise |
| `ids` | NULL | Always `NULL` — SRS has no cluster structure |
| `strata` | NULL | Always `NULL` — SRS has no stratification |
| `nest` | logical | Always `FALSE` |

`fpc_type` is set at construction time by inspecting the FPC column values:
- All values > 1 → `"population"` (column contains population sizes N)
- All values in (0, 1] → `"fraction"` (column contains sampling fractions f)
- Mixed → error (see Section VII, row 57)

### Layer 1 validator rules

The S7 class validator checks structural invariants only. These use `class =`
only (no snapshot) in tests.

| Condition | Error class |
|---|---|
| `weights` not `NULL` and column absent from `@data` | `surveycore_error_design_var_missing` |
| `weights` column not numeric | `surveycore_error_weights_not_numeric` |
| `weights` column has non-positive non-NA values | `surveycore_error_weights_nonpositive` |
| `fpc` not `NULL` and column absent from `@data` | `surveycore_error_design_var_missing` |

The validator does NOT check FPC value ranges (positive, below-sample) — those
are Layer 3 constructor checks in `as_survey_srs()`.

---

## IV. `as_survey_srs()` Constructor

### Signature

```r
as_survey_srs <- function(
  data,
  weights = NULL,
  probs   = NULL,
  fpc     = NULL
)
```

No `ids`, `strata`, or `nest` arguments — SRS is definitionally equal-probability.
`probs` is accepted as an alternative to `weights`; they are mutually exclusive.

### Layer 3 input validation (in order)

All existing data-level checks from `as_survey()` apply unchanged (rows 1–4 in
error table: not_data_frame, empty_data, duplicate_names, single_row_warning).

These checks must be implemented via the existing `.validate_weights()`,
`.validate_fpc()`, and `.resolve_single_col()` helpers — not reimplemented inline.

**`weights`/`probs` mutual exclusion:** If both `weights` and `probs` are non-NULL,
abort with `surveycore_error_weights_probs_both`. This check fires before any
column resolution.

**`probs` → `weights` conversion:** If `probs` is non-NULL and `weights` is NULL,
resolve `probs` via tidy-select, compute `weights_col = 1 / probs_col`, store in
`data[["..surveycore_wt.."]]`, and set `probs_provided = TRUE`. Then proceed
through the weight validation checks below using the converted column.

Weight-specific checks:

| Check | Fires when | Error/Warning class |
|---|---|---|
| `weights` matches 0 columns | tidy-select resolves to nothing | `surveycore_error_weights_not_found` |
| `weights` matches > 1 column | tidy-select resolves to multiple | `surveycore_error_weights_multiple` |
| All weights are zero | entire column is 0 or NA | `surveycore_error_weights_all_zero` |
| No `weights` provided | `weights = NULL` | `surveycore_warning_srs_no_weights` (row 60) |

When `weights = NULL`, auto-assign uniform weights: `data[["..surveycore_wt.."]] <- rep(1L, nrow(data))`. The `surveycore_warning_srs_no_weights` warning fires with the message from row 60.

**Partial NA weights:** A weight column with some NA rows and the rest positive passes all checks. This is intentional and consistent with `survey_taylor` behavior. Variance computation uses `na.rm = TRUE`, so only non-NA rows contribute to estimates. The `weights_all_zero` check (entire column 0 or NA) is the only NA-related weight check.

FPC-specific checks (only when `fpc` is not `NULL`):

| Check | Fires when | Error/Warning class |
|---|---|---|
| `fpc` matches 0 columns | tidy-select resolves to nothing | `surveycore_error_fpc_not_found` |
| `fpc` matches > 1 column | tidy-select resolves to multiple | `surveycore_error_fpc_multiple` |
| `fpc` column contains `NA` | any NA in FPC column | `surveycore_error_fpc_na` |
| `fpc` column has non-positive values | any value ≤ 0 | `surveycore_error_fpc_nonpositive` (NEW — row 56) |
| `fpc` column mixes >1 and ≤1 values | both ranges present | `surveycore_error_fpc_ambiguous` (NEW — row 57) |
| `fpc` column is population size AND any value < n | any individual FPC value < n_used | `surveycore_error_fpc_below_sample` (NEW — row 58) |

The `fpc_below_sample` check is **per-row**: it fires when any individual FPC value is less than `n_used`. FPC values varying across rows is itself a misuse of `survey_srs` (heterogeneous population sizes imply stratification; use `survey_taylor`), so the per-row check catches the most common practical error. The message template's `{n_bad}` is the count of rows where `fpc_val < n_used`.

Run FPC checks in this order: (1) NA check, (2) nonpositive, (3) ambiguous, (4) below_sample. This ordering catches obviously invalid values before statistically nuanced checks and ensures consistent snapshot output when multiple conditions fire on the same column.

### `fpc_type` detection

After validation, detect `fpc_type`:

```r
fpc_type <- if (is.null(fpc_var)) {
  NULL
} else {
  fpc_vals <- data[[fpc_var]]
  if (all(fpc_vals > 1)) "population" else "fraction"
}
```

(Values exactly equal to 1 are a sampling fraction of 1.0, meaning the entire
population was sampled — `fpc_type = "fraction"`, `f = 1`, variance = 0.)

### `@variables` construction

```r
variables <- list(
  weights        = weights_var,       # character column name, or "..surveycore_wt.."
  fpc            = fpc_var,           # character column name, or NULL
  fpc_type       = fpc_type,          # "population", "fraction", or NULL
  probs_provided = probs_provided,    # TRUE if caller supplied probs; FALSE otherwise
  ids            = NULL,
  strata         = NULL,
  nest           = FALSE
)
```

`probs_provided` is `TRUE` when `probs` was non-NULL (after conversion);
`FALSE` when `weights` was supplied directly or uniform weights were auto-assigned.

### Constructor call

```r
survey_srs(data = data, variables = variables, call = match.call())
```

`call = match.call()` captures the user's call expression, consistent with `as_survey()` and `as_survey_rep()`.

### Return value

A `survey_srs` object. Visible (not wrapped in `invisible()`).

### Documentation

Roxygen2 tags required for `as_survey_srs()` (consistent with `as_survey()` and
`as_survey_rep()`):

- `@family constructors`
- `@seealso [as_survey()]`
- `@return A \code{survey_srs} object.`
- `@examples` — one minimal runnable example: `as_survey_srs(data.frame(y = 1:5))`
- `@param data`, `@param weights`, `@param fpc` — follow the fuller treatment
  for survey-specific arguments per `surveycore-conventions.md` §1

---

## V. `as_survey()` Dispatch Update

### Dispatch rule

`as_survey()` dispatches to `survey_srs` when **both** of the following hold:

1. `ids` resolves to `NULL` (no PSU columns specified)
2. `strata` resolves to `NULL` (no stratification column specified)

Otherwise, `as_survey()` proceeds as before, creating a `survey_taylor` object.

### Warning when dispatching to SRS

When `as_survey()` dispatches to `survey_srs`, it fires:

```r
cli::cli_warn(
  c(
    "!" = "No {.arg ids} or {.arg strata} specified.",
    "i" = "Creating a {.cls survey_srs} design (equal-probability SRS).",
    "v" = "Use {.fn as_survey_srs} to create SRS designs without this warning."
  ),
  class = "surveycore_warning_as_survey_srs_fallback"
)
```

This warning fires **in addition to** any `surveycore_warning_srs_no_weights`
warning if no weights were provided. The two warnings are separate and both
are suppressible independently via `suppressWarnings()` or `withCallingHandlers()`.
`surveycore_warning_as_survey_srs_fallback` fires inside `as_survey()`, before
the call to `as_survey_srs()`. `surveycore_warning_srs_no_weights` fires inside
`as_survey_srs()`.

### Required refactoring of `as_survey()`

The existing `as_survey()` resolves `weights`, `probs`, and the no-weights
fallback before any dispatch decision is possible. Implementing "all processing
in `as_survey_srs()`" requires restructuring `as_survey()` as follows:

1. **Dispatch check first.** Insert the ids/strata check (both NULL?) at the
   top of `as_survey()`, before any weight or probs resolution.

2. **SRS path: forward raw quosures and early-return.**
   ```r
   if (is_srs_dispatch) {
     cli::cli_warn(...)   # row 59 fallback warning
     return(as_survey_srs(data, weights = weights, probs = probs, fpc = fpc))
   }
   ```
   `weights`, `probs`, and `fpc` are forwarded as unresolved quosures. All
   column resolution, probs→weights conversion, and `@variables` construction
   happen inside `as_survey_srs()`. `as_survey()` returns immediately.

3. **Taylor path: unchanged.** The existing weight/probs resolution and
   no-weights warning code (row 7) remain in `as_survey()` for the Taylor path
   (when ids or strata are non-NULL). Row 7 never fires on the SRS path because
   `as_survey()` has already returned.

4. **Warning order.** `surveycore_warning_as_survey_srs_fallback` (row 59)
   fires inside `as_survey()` before the `as_survey_srs()` call.
   `surveycore_warning_srs_no_weights` (row 60) fires inside `as_survey_srs()`
   if no weights/probs were provided. When both fire, row 59 always precedes
   row 60 — snapshot tests depend on this order.

### `as_survey()` argument forwarding

`as_survey()` forwards to `as_survey_srs()`:
- `data` — unchanged
- `weights` — raw quosure, unresolved
- `probs` — raw quosure, unresolved
- `fpc` — raw quosure, unresolved

`nest`, `ids`, and `strata` are not forwarded (they are `NULL` by the dispatch
condition). No conversion, validation, or `@variables` construction is done in
`as_survey()` for the SRS path.

---

## VI. Print and Summary Methods

### `print.survey_srs`

Registered via `S7::method(print, survey_srs) <- ...`.

Default output (no flags):

```
── Survey Design ───────────────────────────────────────────────
<survey_srs> (simple random sample)
Sample size: 500
```

With `design_info = TRUE` or `full = TRUE`:

```
── Survey Design ───────────────────────────────────────────────
<survey_srs> (simple random sample)
Sample size: 500

── Design specification ────────────────────────────────────────
• Weights: <weight_column>             # or "uniform (auto-assigned)" if ..surveycore_wt..
• FPC: <fpc_column> (population sizes) # or "(sampling fractions)" or "not specified"
• Sampling fraction: 0.025             # only shown when FPC is specified; computed as mean(n/N) or mean(f)
```

With `weights_info = TRUE` or `full = TRUE`:

```
── Weight distribution ─────────────────────────────────────────
• Range: 1.2 – 4.8
• Mean: 2.3
• CV: 0.18
```

With `metadata_info = TRUE` or `full = TRUE`: identical to `survey_taylor`
metadata section.

### Signature

```r
S7::method(print, survey_srs) <- function(
  x,
  n             = 10L,
  design_info   = FALSE,
  weights_info  = FALSE,
  metadata_info = FALSE,
  full          = FALSE,
  ...
)
```

Note: `strata_info` and `cluster_info` are **not** arguments for `survey_srs`
(SRS has no clusters or strata). Including them would be misleading.

### `summary.survey_srs`

Returns a plain list (same pattern as `survey_taylor`):

```r
list(
  class          = "survey_srs",
  n              = nrow(x@data),
  weighted_n     = round(sum(x@data[[x@variables$weights]], na.rm = TRUE)),
  fpc_specified  = !is.null(x@variables$fpc),
  fpc_type       = x@variables$fpc_type,   # NULL, "population", or "fraction"
  n_var_labels   = length(x@metadata@variable_labels),
  n_val_labels   = length(x@metadata@value_labels)
)
```

`summary()` returns the list visibly. The result auto-prints as a plain list
when called interactively. (The `print` *method for `survey_srs`* — not
`summary` — returns `invisible(x)`.)

---

## VII. Error and Warning Classes

New rows to add to `plans/error-messages.md`:

| # | Function | Condition | Level | Error Class | cli Message Template |
|---|---|---|---|---|---|
| 55 | `as_survey_srs()` | Both `weights` and `probs` supplied | ERROR | `surveycore_error_weights_probs_both` | `"Supply {.arg weights} or {.arg probs}, not both."` |
| 56 | `as_survey_srs()` | `fpc` column has non-positive values | ERROR | `surveycore_error_fpc_nonpositive` | `"{.arg fpc} column {.field {fpc_var}} has {n_bad} non-positive value(s). FPC values must be > 0."` |
| 57 | `as_survey_srs()` | `fpc` column mixes values > 1 and ≤ 1 | ERROR | `surveycore_error_fpc_ambiguous` | `"{.arg fpc} column {.field {fpc_var}} mixes values > 1 (population sizes) and values ≤ 1 (sampling fractions). All FPC values must be consistently one type."` |
| 58 | `as_survey_srs()` | `fpc` population size < sample size | ERROR | `surveycore_error_fpc_below_sample` | `"{.arg fpc} column {.field {fpc_var}} has {n_bad} value(s) smaller than the sample size ({n}). Population size cannot be smaller than the number of sampled units."` |
| 59 | `as_survey()` | No `ids` or `strata` — dispatching to `survey_srs` | WARN | `surveycore_warning_as_survey_srs_fallback` | `c("!" = "No {.arg ids} or {.arg strata} specified.", "i" = "Creating a {.cls survey_srs} design (equal-probability SRS).", "v" = "Use {.fn as_survey_srs} to create SRS designs without this warning.")` |
| 60 | `as_survey_srs()` | No `weights` provided — auto-assigning uniform weights | WARN | `surveycore_warning_srs_no_weights` | `"No {.arg weights} provided to {.fn as_survey_srs}. Assigning uniform weights ({.code ..surveycore_wt.. = 1}). Population size unknown — total estimates will use {.code \u03a3w_i = n} as the estimated N."` |

---

## VIII. Variance Estimation

### Formula

Let `n_used` be the effective sample size: the count of non-NA observations in the outcome variable when `na.rm = TRUE`, or `nrow(data)` when `na.rm = FALSE`. For a `survey_srs` design with outcome `yᵢ` and weights `wᵢ`:

**Weighted mean:**

```
ȳ = Σ(wᵢ yᵢ) / Σ(wᵢ)
```

**Sampling fraction:**

```
f = n_used / N  if fpc_type == "population"  (N = mean of fpc column)
f = mean(fpc)   if fpc_type == "fraction"
f = 0           if fpc = NULL
```

For SRS, FPC values within a design are all equal (one value for the whole
sample). If they vary across rows, use the mean — and this is a misuse of
`survey_srs` (heterogeneous FPC implies stratification; use `survey_taylor`).

**Sample variance (unweighted):**

```
s² = Σ(yᵢ - ȳ)² / (n_used - 1)
```

SRS weights are proportional to the same constant (N/n), so the unweighted and
weighted sample variances are identical for a true SRS design. We use the
unweighted formula here for clarity and numerical stability.

> **Verification required before committing oracle tests:** `make_survey_data()`
> generates lognormal weights (non-uniform). Before writing the oracle test
> tolerances, run `survey::svymean()` against the formula on non-uniform-weight
> data to confirm they agree at `1e-10`. If they diverge, document the
> discrepancy and the correct tolerance in a comment at the top of the
> `.srs_mean()` implementation in `R/06-variance-estimation.R`.

**Variance of the mean:**

```
var(ȳ) = (1 - f) × s² / n_used
SE(ȳ) = √var(ȳ)
```

**Degrees of freedom:**

```
df = n_used - 1
```

CIs use a t-distribution with `df = n_used - 1` degrees of freedom.

**Total estimation:**

```
T̂ = Σ(wᵢ yᵢ)
var(T̂) = N² × (1 - f) × s² / n_used     if fpc_type == "population"
var(T̂) = (Σwᵢ)² × (1 - f) × s² / n_used  if fpc_type == "fraction"
var(T̂) = (Σwᵢ)² × s² / n_used            if fpc = NULL
SE(T̂)  = √var(T̂)
```

When `fpc = NULL`, `N` is estimated as `Σwᵢ` (the Horvitz-Thompson estimator
of population size), consistent with the `survey` package's behavior.

### Internal functions

Two new internal functions in `R/06-variance-estimation.R`:

```r
# @param design  A survey_srs object.
# @param var_name Character. Name of the variable column.
# @param na.rm   Logical. Default TRUE.
# @return Named list: list(mean = ..., se = ..., df = ...)
.srs_mean <- function(design, var_name, na.rm = TRUE) { ... }

# @param design  A survey_srs object.
# @param var_name Character. Name of the variable column.
# @param na.rm   Logical. Default TRUE.
# @return Named list: list(total = ..., se = ..., df = ...)
.srs_total <- function(design, var_name, na.rm = TRUE) { ... }
```

Both functions return `df` in their result list. The Phase 0 stubs don't use
`df`, but Phase 1 needs it for CI computation. Return it now to avoid a
breaking change later.

### Dispatch in `get_means()` and `get_totals()`

Add `survey_srs` as a first-class case in both stubs:

```r
result <- if (S7::S7_inherits(design, survey_replicate)) {
  .replicate_mean(design, var_name, na.rm = na.rm)
} else if (S7::S7_inherits(design, survey_srs)) {
  .srs_mean(design, var_name, na.rm = na.rm)
} else {
  .taylor_mean(design, var_name, na.rm = na.rm)
}
```

`survey_calibrated` continues to fall through to `.taylor_mean()` (the SRS-
approximation path for non-probability samples).

### Edge cases

| Condition | Behavior |
|---|---|
| All `yᵢ` are NA and `na.rm = TRUE` | Return `mean = NA_real_`, `se = NA_real_`, `df = 0L` (no error — consistent with `survey_taylor`) |
| All `yᵢ` are NA and `na.rm = FALSE` | Return `mean = NA_real_`, `se = NA_real_`, `df = nrow(data) - 1` (NA propagation; full `n` used for `df`) |
| Some `yᵢ` are NA and `na.rm = FALSE` | Return `mean = NA_real_`, `se = NA_real_`, `df = nrow(data) - 1` (standard R NA arithmetic propagates through `Σwᵢyᵢ`; all rows counted for `df`) |
| `n = 1` after NA removal | Return `mean = y₁`, `se = NA_real_`, `df = 0L` — variance undefined for n=1 |
| `fpc_type = "fraction"` with all fpc = 1 (census) | `f = 1`, `var(ȳ) = 0`, `se = 0` — correct |
| Weights all equal (uniform SRS) | Formula produces same result as unweighted formula |

**`df` rule:** `df` is always `n_used - 1` (per the definition above). When
`na.rm = FALSE`, `n_used = nrow(data)`, so `df = nrow(data) - 1`. This rule
applies to both `.srs_mean()` and `.srs_total()`.

---

## IX. `@variables` Key Compatibility

`survey_srs` must always have the same top-level key names as `survey_taylor`
so generic code that iterates `design@variables` doesn't break. The
`survey_srs`-only key (`fpc_type`) is an addition, not a replacement.

Code that checks `is.null(design@variables$ids)` will correctly find `NULL`
for `survey_srs` designs. Code that checks `is.null(design@variables$strata)`
will also correctly find `NULL`. No existing generic code needs to change.

---

## X. Test Requirements

### `helper-test-data.R` — update `test_invariants()`

Add a `survey_srs` branch to `test_invariants()` in `helper-test-data.R` that verifies the SRS-specific invariant:

```r
if (S7::S7_inherits(design, survey_srs)) {
  expect_true("fpc_type" %in% names(design@variables))
}
```

This branch fires in every constructor test block that calls `test_invariants(design)` on a `survey_srs` object, ensuring a constructor that omits `fpc_type` from `@variables` is caught immediately.

### `test-s7-classes.R` — new blocks for `survey_srs`

| # | Description | Pattern |
|---|---|---|
| 1 | Validator rejects weight column absent from `@data` | `class=` only |
| 2 | Validator rejects non-numeric weight column | `class=` only |
| 3 | Validator rejects non-positive values in weight column | `class=` only |
| 4 | Validator rejects FPC column absent from `@data` | `class=` only |
| 5 | All `@variables` keys present after construction | `keys <- c("weights", "fpc", "fpc_type", "probs_provided", "ids", "strata", "nest"); expect_true(all(keys %in% names(...)))` |
| 6 | `@variables$ids` is always NULL | `expect_null` |
| 7 | `@variables$strata` is always NULL | `expect_null` |

### `test-constructors.R` — new blocks for `as_survey_srs()`

**Happy path:**

| # | Description |
|---|---|
| 1 | Creates `survey_srs` with explicit weights — `test_invariants()` first |
| 2 | Creates `survey_srs` with FPC as population sizes |
| 3 | Creates `survey_srs` with FPC as sampling fractions |
| 4 | Creates `survey_srs` with no weights — uniform weights auto-assigned |
| 5 | Returns `survey_srs` class (not `survey_taylor`) |
| 6 | `@variables$fpc_type == "population"` when FPC > 1 |
| 7 | `@variables$fpc_type == "fraction"` when FPC ∈ (0, 1] |
| 8 | `@variables$fpc_type` is NULL when no FPC |
| 9 | `as_survey()` with no ids/strata creates `survey_srs` (fires `srs_fallback` warning) |
| 9b | Creates `survey_srs` with `probs` — `@variables$probs_provided == TRUE` and weights stored as `1 / probs` |

**Error paths** (dual pattern: `class=` + `expect_snapshot`):

| # | Condition tested | Error class |
|---|---|---|
| 10 | Both `weights` and `probs` supplied | `surveycore_error_weights_probs_both` |
| 11 | Non-data-frame `data` | `surveycore_error_not_data_frame` |
| 11 | Zero-row `data` | `surveycore_error_empty_data` |
| 12 | `weights` matches 0 columns | `surveycore_error_weights_not_found` |
| 13 | `weights` matches > 1 column | `surveycore_error_weights_multiple` |
| 14 | All weights zero | `surveycore_error_weights_all_zero` |
| 15 | `fpc` matches 0 columns | `surveycore_error_fpc_not_found` |
| 15b | `fpc` matches > 1 column | `surveycore_error_fpc_multiple` |
| 16 | `fpc` column has NAs | `surveycore_error_fpc_na` |
| 17 | `fpc` column has non-positive values | `surveycore_error_fpc_nonpositive` |
| 18 | `fpc` column mixes >1 and ≤1 values | `surveycore_error_fpc_ambiguous` |
| 19 | `fpc` population size < n | `surveycore_error_fpc_below_sample` |

**Warning paths:**

| # | Condition tested | Warning class |
|---|---|---|
| 20 | No weights provided | `surveycore_warning_srs_no_weights` |
| 21 | Single-row data | `surveycore_warning_single_row` |
| 22 | `as_survey()` with no ids/strata | `surveycore_warning_as_survey_srs_fallback` |

### `test-methods-print.R` — new snapshot blocks

| # | Description |
|---|---|
| 1 | `print(srs_design)` — default (header only) |
| 2 | `print(srs_design, design_info = TRUE)` — with weights and FPC |
| 3 | `print(srs_design, design_info = TRUE)` — FPC as fractions |
| 4 | `print(srs_design, full = TRUE)` — all sections |
| 5 | `print(srs_design)` — uniform weights (no FPC) |

### `summary.survey_srs` tests (in `test-methods-print.R`)

| # | Description | Pattern |
|---|---|---|
| 6 | `summary()` returns a list with all 7 keys present | `expect_identical(sort(names(s)), sort(c("class", "n", "weighted_n", "fpc_specified", "fpc_type", "n_var_labels", "n_val_labels")))` |
| 7 | `summary()$n == nrow(x@data)` | `expect_identical` |
| 8 | `summary()$fpc_specified` is `FALSE` when no FPC | `expect_false` |
| 9 | `summary()$fpc_specified` is `TRUE` when FPC given | `expect_true` |
| 10 | `summary()$fpc_type` is `NULL` when no FPC | `expect_null` |
| 11 | `summary()$fpc_type == "population"` when FPC > 1 | `expect_identical` |
| 12 | `summary()$fpc_type == "fraction"` when FPC ∈ (0, 1] | `expect_identical` |

### `test-variance-estimation.R` — oracle tests

All oracle tests use `skip_if_not_installed("survey")`.

Reference: `survey::svydesign(ids = ~1, weights = ~w, fpc = ~fpc_col, data = df)`.

| # | Estimand | Design | Tolerance |
|---|---|---|---|
| 1 | Mean | No FPC | point: `1e-10`, SE: `1e-8` |
| 2 | Total | No FPC | point: `1e-10`, SE: `1e-8` |
| 3 | Mean | FPC as population size | point: `1e-10`, SE: `1e-8` |
| 4 | Total | FPC as population size | point: `1e-10`, SE: `1e-8` |
| 5 | Mean | FPC as sampling fraction | point: `1e-10`, SE: `1e-8` |
| 6 | Mean | NA removal (`na.rm = TRUE`) | point: `1e-10`, SE: `1e-8` |
| 7 | Mean | Uniform weights (auto-assigned) | point: `1e-10`, SE: `1e-8` |
| 8 | Total | FPC as sampling fraction | point: `1e-10`, SE: `1e-8` |
| 9 | Total | NA removal (`na.rm = TRUE`) | point: `1e-10`, SE: `1e-8` |

**`.srs_mean()` and `.srs_total()` edge cases** (non-oracle, inline data):

`.srs_mean()`:
- All `yᵢ` NA, `na.rm = TRUE` → `mean = NA_real_`, `se = NA_real_`, `df = 0L`
- All `yᵢ` NA, `na.rm = FALSE` → `mean = NA_real_`, `se = NA_real_`, `df = nrow(data) - 1`
- **Some `yᵢ` NA, `na.rm = FALSE`** → `mean = NA_real_`, `se = NA_real_`, `df = nrow(data) - 1` (NA propagates via standard R arithmetic)
- `n = 1` after NA removal → `mean = y₁`, `se = NA_real_`, `df = 0L`

`.srs_total()`:
- All `yᵢ` NA, `na.rm = TRUE` → `total = NA_real_`, `se = NA_real_`, `df = 0L`
- **Some `yᵢ` NA, `na.rm = FALSE`** → `total = NA_real_`, `se = NA_real_`, `df = nrow(data) - 1`
- `n = 1` after NA removal → `total = w₁y₁`, `se = NA_real_`, `df = 0L`

Use `make_survey_data(n = 500, seed = 42)` as the data source, then drop
`ids`/`strata`/`fpc` columns when constructing the SRS oracle comparison.

---

## XI. Coverage Map Update

Add to `plans/error-messages.md` coverage table:

| Test file | Error rows covered |
|---|---|
| `test-constructors.R` | 1–26, **55–60** |
| `test-s7-classes.R` | 31–35, 37–39 *(no new rows for SRS validator — uses existing classes)* |

**Note:** Rows 7 and 60 share the same class name (`surveycore_warning_srs_no_weights`) but fire from different functions: row 7 fires from `as_survey()` on the Taylor path (no weights provided to a clustered design); row 60 fires from `as_survey_srs()` (no weights provided to an SRS constructor). The coverage table entry `55–60` for `test-constructors.R` covers row 60. Row 7 is covered by the existing `test-constructors.R` Taylor-path warning tests (rows 1–26).

---

## XII. Quality Gate

This PR is complete when:

- [ ] `devtools::check()` — 0 errors, 0 warnings, ≤ 2 notes
- [ ] `devtools::test()` — all tests pass, no failures
- [ ] Oracle tests pass for all 9 variance scenarios (tolerances in Section X)
- [ ] Formula verified against `survey::svymean()` on non-uniform weights; result documented in a comment in `R/06-variance-estimation.R`
- [ ] `plans/error-messages.md` updated with rows 55–60
- [ ] Coverage map in `plans/error-messages.md` updated (rows 55–60 → `test-constructors.R`)
- [ ] Print snapshots committed (`tests/testthat/_snaps/test-methods-print.md`)
- [ ] Constructor error snapshots committed (`tests/testthat/_snaps/test-constructors.md`)
- [ ] `R/04-methods-print.R` file header comment updated to include `survey_srs`
- [ ] `CLAUDE.md` phase status table updated: Prereq PR 1 → ✅ Complete

---

## XIII. Files Changed

| File | Change type |
|---|---|
| `R/00-s7-classes.R` | Add `fpc_type` key to validator; minor doc updates |
| `R/03-constructors.R` | Add `as_survey_srs()`; update `as_survey()` dispatch |
| `R/04-methods-print.R` | Add `print` and `summary` methods for `survey_srs` |
| `R/06-variance-estimation.R` | Add `.srs_mean()`, `.srs_total()`; update dispatch in stubs |
| `tests/testthat/test-s7-classes.R` | New blocks for `survey_srs` validator |
| `tests/testthat/test-constructors.R` | New blocks for `as_survey_srs()` |
| `tests/testthat/test-methods-print.R` | New snapshots for `survey_srs` print |
| `tests/testthat/test-variance-estimation.R` | New oracle blocks for SRS variance |
| `tests/testthat/helper-test-data.R` | (1) Update `make_all_designs()` to include `srs` via `as_survey_srs(df_s, weights = wt)` directly (not `as_survey()` — avoids spurious warnings); (2) Add `survey_srs` branch to `test_invariants()` that checks `"fpc_type" %in% names(design@variables)` |
| `plans/error-messages.md` | Add rows 56–59; update coverage map |
| `CLAUDE.md` | Update phase table; add spec reference |
