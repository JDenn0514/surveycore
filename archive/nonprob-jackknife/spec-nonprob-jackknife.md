# Spec — nonprob-jackknife

**Status**: SPEC_READY
**Target version**: 0.9.0.9000
**PR range**: PR 1 (single PR)

---

## Scope

### In

- Lift the hard `type == "bootstrap"` restriction in `as_survey_nonprob()` to
  accept `"JK1"`, `"JK2"`, `"JKn"`, and `"jackknife"` (alias for `"JK1"`).
- Normalize `type = "jackknife"` to `"JK1"` before storing in `@variables$type`.
- Apply type-specific default `scale` when `type` is a jackknife variant:
  `(R - 1) / R` for JK1/jackknife, `1` for JK2/JKn.
- Update the bootstrap-specific calibration provenance check
  (`calibration$bootstrap`) so it is skipped for jackknife types.
- Update `print.survey_nonprob` to display the replicate type name (not
  hard-coded `"BOOTSTRAP"`) in the header line.
- Update `summary.survey_nonprob` to surface the replicate type.
- Update the `survey_nonprob` class roxygen `@section Design variables` to
  list all four valid `type` values.
- Update the `as_survey_nonprob()` roxygen `@param type` description.
- Update the `surveycore_error_repweights_single` message (row NB-3) to be
  type-agnostic (remove the phrase "Bootstrap variance requires >= 2
  replicates" and replace with "Replicate variance requires >= 2 replicates").
- Add new error class `surveycore_error_type_unsupported_for_nonprob` for
  types that are valid in `as_survey_replicate()` but not allowed for
  `survey_nonprob` (BRR, Fay, ACS, successive-difference).
- Add new error class `surveycore_error_stratified_jk_rscales_unset` for when
  `type = "JK2"` or `type = "JKn"` is supplied without explicit `rscales`
  (see Edge cases).
- Update `.nonprob_rep_na_warn()` in `R/analysis-helpers.R` to say
  "replicates" instead of "bootstrap replicates" in the domain-NA warning
  message (class `surveycore_warning_domain_replicates_na`).
- Update `plans/error-messages.md` to replace row NB-1 and add new rows.

### Out

- No changes to variance engine (`variance-replicate.R`, `.svy_rep_var()`).
- No changes to any analysis function (`get_means()`, `get_totals()`, etc.).
- No changes to `as_survey_replicate()`.
- No changes to `survey_taylor`, `survey_replicate`, or `survey_twophase`.
- Jackknife replicate weight generation is not in scope. Users are responsible
  for supplying pre-computed jackknife pseudo-weights.
- BRR, Fay, ACS, and successive-difference replicate types remain unsupported
  for `survey_nonprob`.

---

## Architecture

- **Files touched**:
  - `R/core-constructors.R` — `as_survey_nonprob()` body
  - `R/core-classes.R` — `survey_nonprob` class roxygen documentation only
    (no validator changes)
  - `R/methods-print.R` — `print.survey_nonprob` and `summary.survey_nonprob`
    methods
  - `R/analysis-helpers.R` — `.nonprob_rep_na_warn()` warning message
    (remove hard-coded word "bootstrap"; use type-agnostic "replicates")
  - `R/utils.R` — new internal helper `.compute_nonprob_scale(type, R)`
  - `plans/error-messages.md` — updated NB-1, NB-3; new NB-9
  - `man/as_survey_nonprob.Rd` — regenerated via `devtools::document()`
  - `man/survey_nonprob.Rd` — regenerated via `devtools::document()`

- **Functions modified**:
  - `as_survey_nonprob(data, weights, repweights, type, scale, rscales, mse, reference_sample, calibration)`
  - `print.survey_nonprob` (via `S7::method(print, survey_nonprob)`)
  - `summary.survey_nonprob` (via `S7::method(summary, survey_nonprob)`)
  - `.nonprob_rep_na_warn()` in `R/analysis-helpers.R` — message text only;
    update the `"!"` bullet from
    `"Bootstrap replicates..."` to `"Replicates..."` (remove the word
    `"Bootstrap"` or `"bootstrap"`; the exact replacement is
    `"Replicates"` or `"Replicate"` — maintain existing sentence structure).
    Class `surveycore_warning_domain_replicates_na` is unchanged.

- **Explicit line-level changes** (to prevent the builder from missing them):
  - `R/core-constructors.R` line ~1277: the `"i"` bullet in the
    `surveycore_error_repweights_single` block currently reads
    `"Bootstrap variance requires >= 2 replicates. Got {.val 1}."`. Change
    to `"Replicate variance requires >= 2 replicates. Got {.val 1}."`. Error
    class unchanged.
  - `R/core-constructors.R` line ~1299: the existing `if (!identical(type,
    "bootstrap"))` block (which raises `surveycore_error_type_invalid`) is
    replaced entirely by the new type validation block described in the
    decision tree (steps 8–9).

- **Internal helpers added**:
  - `.compute_nonprob_scale(type, R)` — computes the type-specific default
    `scale` for `survey_nonprob` objects. Lives in `R/utils.R`. Not exported.
    ```r
    .compute_nonprob_scale <- function(type, R) {
      switch(type,
        bootstrap = 1 / R,
        JK1       = (R - 1) / R,
        JK2       = 1,
        JKn       = 1
      )
    }
    ```
    This replaces the hardcoded `scale <- if (is.null(scale)) 1 / R else scale`
    at line 1304 of `R/core-constructors.R`. The builder must call this helper
    as `scale <- .compute_nonprob_scale(type, R)` when `is.null(scale)`.

- `.is_stratified_jk(type)` — returns `type %in% c("JK2", "JKn")`. Used in
  the rscales NULL check (step 10 of decision tree) only. Lives inline in
  `R/core-constructors.R` (single file per code style rule). Not exported.

  The calibration conditional structure (no `.is_any_jk()` helper needed;
  direct comparison is clearer):
  ```r
  if (!is.null(calibration)) {
    if (type == "bootstrap") {
      if (!isTRUE(calibration$bootstrap)) {
        cli::cli_abort(..., class = "surveycore_error_provenance_not_bootstrap")
      }
    }
    if (!is.null(calibration$R) && calibration$R != R) {
      cli::cli_abort(..., class = "surveycore_error_provenance_R_mismatch")
    }
  }
  ```

    **Why not shared with `as_survey_replicate()`**: `as_survey_replicate()`
    uses `JK2 = (n_rep - 1) / n_rep` (treating all replicates as delete-one
    from a single stratum). For `survey_nonprob`, JK2/JKn default to `scale =
    1` because the stratum-specific scaling is carried by `rscales` instead
    (Elliott and Valliant 2017 §3). The two constructors have different
    JK2/JKn defaults and cannot share a single helper.

- **Class changes**: none (no S7 property or validator changes)

- **Roxygen `@param type` replacement text** (for `as_survey_nonprob()`):
  ```r
  #' @param type Character scalar. Replicate variance type. When
  #'   \code{repweights = NULL}, this argument is ignored. Case-sensitive.
  #'   Valid values:
  #'   \describe{
  #'     \item{\code{"bootstrap"}}{Bootstrap variance. Default scale: \code{1/R}.
  #'       Default value for \code{type}.}
  #'     \item{\code{"JK1"}}{Delete-one jackknife for unclustered nonprob designs.
  #'       Default scale: \code{(R-1)/R}. Appropriate when each unit is its own
  #'       replication unit. For clustered designs, use \code{"JK2"} or
  #'       \code{"JKn"} with explicit \code{rscales}.}
  #'     \item{\code{"jackknife"}}{Alias for \code{"JK1"}. Normalized to
  #'       \code{"JK1"} before storage — the stored value is always
  #'       \code{"JK1"}, never \code{"jackknife"}.}
  #'     \item{\code{"JK2"}}{Stratified jackknife. Default scale: \code{1}.
  #'       Requires explicit \code{rscales} (stratum-specific scale factors of
  #'       the form \code{(n_h - 1) / n_h}).}
  #'     \item{\code{"JKn"}}{Equivalent to \code{"JK2"} for stratified nonprob
  #'       designs. Default scale: \code{1}. Requires explicit \code{rscales}.}
  #'   }
  ```

- **Degrees of freedom**: `survey_nonprob` objects use **normal approximation**
  (Inf DoF, z-critical values) for all confidence intervals regardless of
  replicate type (`"bootstrap"`, `"JK1"`, `"JK2"`, `"JKn"`). This reflects the
  user-supplied nature of replicate weights and the difficulty of validating
  replication structure. By contrast, `survey_replicate(type = "JK1")` uses
  t-distribution with df = R − 1. No code changes are needed for this
  behavior — it is already implemented in `.degf()` and is unchanged by
  this PR.

---

## Function contracts

### `as_survey_nonprob(data, weights, repweights, type, scale, rscales, mse, reference_sample, calibration)`

**Signature**:
```r
as_survey_nonprob(
  data,
  weights,
  repweights  = NULL,
  type        = "bootstrap",
  scale       = NULL,
  rscales     = NULL,
  mse         = TRUE,
  reference_sample = NULL,
  calibration = NULL
)
```

**Arguments**:

- `data`: A `data.frame`. Must have >= 1 row and unique column names. Required.
- `weights`: `<tidy-select>` A single column of calibration weights. All
  non-NA values must be >= 0 (negative rejected; zero-only rejected). Required.
- `repweights`: `<tidy-select>` Replicate weight columns. NULL (default) = SRS
  variance approximation. When non-NULL, must resolve to >= 2 columns.
  Exactly 1 column resolved is an error. When `type` is a jackknife variant
  (`"JK1"`, `"JK2"`, `"JKn"`), each replicate column must contain calibrated
  weights **re-estimated on the leave-out sample** (Elliott and Valliant 2017
  §3). Supplying columns where only base weights are zeroed out (without
  recalibration) will underestimate variance.
- `type`: Character scalar. Replicate variance type. When `repweights = NULL`,
  `type` is ignored entirely (no error, no warning). `type` must be a character
  scalar (`length(type) == 1L`); non-character values (e.g., `type = 1`,
  `type = TRUE`) and vector-valued inputs (e.g., `type = c("JK1", "JK2")`) are
  treated as unsupported types and raise
  `surveycore_error_type_unsupported_for_nonprob` via the membership check.
  `type = NA_character_` is also treated as unsupported (the error message
  displays `{.val NA}`). Case-sensitive: `"jk1"`, `"jkn"`, and `"Bootstrap"`
  are not valid. When `repweights` is non-NULL, valid values are:
  - `"bootstrap"` — bootstrap variance. Default scale: `1 / R`.
  - `"JK1"` — delete-one jackknife. Default scale: `(R - 1) / R`. Appropriate
    for **unclustered** nonprob designs where each unit is its own replicate
    unit. For clustered nonprob designs (replication units are clusters within
    strata), use `"JK2"` or `"JKn"` with explicit stratum-specific `rscales`
    per Elliott and Valliant (2017) §3.
  - `"jackknife"` — alias for `"JK1"`. Normalized to `"JK1"` before storage.
  - `"JK2"` — delete-one jackknife with stratified rscales. Default scale: `1`.
    When `rscales = NULL` and `type = "JK2"`, emits
    `surveycore_error_stratified_jk_rscales_unset` (see Edge cases).
  - `"JKn"` — same behavior as `"JK2"`. Alias used by some software for
    stratified jackknife. Default scale: `1`. Same `rscales = NULL` behavior.
  - Any other value (including `"BRR"`, `"Fay"`, `"ACS"`, `"jk1"`, `"jkn"`)
    raises `surveycore_error_type_unsupported_for_nonprob`. Case-sensitivity is
    consistent with `as_survey_replicate()`, which uses exact-match validation.
  - Default `"bootstrap"`.
- `scale`: Numeric scalar >= 0. Scaling factor for the replicate variance
  formula `V = scale * sum(rscales * (theta_r - theta)^2)`. NULL (default)
  activates the type-specific default:
  - `"bootstrap"`: `1 / R`
  - `"JK1"` / `"jackknife"`: `(R - 1) / R`
  - `"JK2"` / `"JKn"`: `1`
  When `repweights = NULL`, `scale` is ignored.
- `rscales`: Numeric vector of length `R`. Per-replicate scale factors. All
  values must be >= 0 and non-NA. A value of `0` in `rscales` causes that
  replicate to contribute zero variance (it is excluded from the variance sum);
  this is valid and accepted without error. NULL (default) = `rep(1, R)` for
  `"bootstrap"` and `"JK1"`. For `"JK2"` and `"JKn"`, `rscales = NULL` raises
  `surveycore_error_stratified_jk_rscales_unset` — these types require explicit
  stratum-specific scale factors (see Edge cases). When `repweights = NULL`,
  `rscales` is ignored.
- `mse`: Logical scalar. `TRUE` (default) = mean-squared-error form of
  variance estimator. `FALSE` = centered form. Applies to all replicate types.
  When `repweights = NULL`, `mse` is ignored. Non-logical or NA values (e.g.,
  `mse = 1`, `mse = NA`) are silently treated as `FALSE` via `isTRUE()` — this
  is pre-existing behavior, not validated by this PR.
- `reference_sample`: A `survey_taylor` object or NULL. Optional. Type-checked
  regardless of whether `repweights` is supplied.
- `calibration`: A list or NULL. Calibration provenance from `surveywts`.
  When non-NULL and `repweights` is non-NULL:
  - For `type = "bootstrap"`: requires `calibration$bootstrap == TRUE` and
    `calibration$R` (if non-NULL) must equal the number of replicate columns.
  - For jackknife types (`"JK1"`, `"JK2"`, `"JKn"`, `"jackknife"`): the
    `calibration$bootstrap` check is skipped. Only the `calibration$R`
    count-match check is applied (if `calibration$R` is non-NULL).

  The new conditional structure in the constructor body (replaces the
  existing unconditional `if (!isTRUE(calibration$bootstrap))` at line
  1332):
  ```r
  if (!is.null(calibration)) {
    if (type == "bootstrap") {
      if (!isTRUE(calibration$bootstrap)) {
        cli::cli_abort(..., class = "surveycore_error_provenance_not_bootstrap")
      }
    }
    if (!is.null(calibration$R) && calibration$R != R) {
      cli::cli_abort(..., class = "surveycore_error_provenance_R_mismatch")
    }
  }
  ```
  The `calibration$bootstrap` check is now wrapped in `if (type ==
  "bootstrap")`. The R-count check runs for all types when `calibration$R`
  is non-NULL.

**Constructor execution order** (pseudocode decision tree — builder must
follow this exact sequence in `as_survey_nonprob()`):

```
1.  Validate data is a data.frame and has >= 1 row.
2.  Resolve weights column (tidy-select); validate exactly 1, non-NA, >= 0.
3.  Resolve repweights columns (tidy-select).
4.  If repweights resolves to NULL → store all rep-related variables as NULL
    and go directly to step 16 (skip steps 5–15).
5.  If repweights resolves to exactly 0 columns → raise
    surveycore_error_repweights_empty.
6.  If repweights resolves to exactly 1 column → raise
    surveycore_error_repweights_single.
7.  Compute R = number of resolved repweight columns.
8.  Normalize type alias: if (type == "jackknife") type <- "JK1".
9.  Validate type in c("bootstrap", "JK1", "JK2", "JKn"); if not →
    raise surveycore_error_type_unsupported_for_nonprob.
10. If type %in% c("JK2", "JKn") and rscales is NULL → raise
    surveycore_error_stratified_jk_rscales_unset.
11. If scale is NULL → scale <- .compute_nonprob_scale(type, R).
    Else if scale < 0 → raise surveycore_error_scale_negative.
    (`.compute_nonprob_scale()` always returns a positive value, so the
    negative check only fires when the caller supplied an explicit negative
    scale. Zero is accepted: `scale = 0` produces zero variance, which may
    be intentional for diagnostic purposes.)
12. If rscales is NULL → rscales <- rep(1, R).
13. Validate rscales (length == R, all >= 0, no NA) via
    .validate_rscales().
14. Validate reference_sample (if non-NULL, must be survey_taylor).
15. Validate calibration provenance (if non-NULL, using conditional
    structure above: bootstrap check only for type = "bootstrap"; R-count
    check for all types).
16. Construct and return survey_nonprob object.
```

**Returns**: A `survey_nonprob` object with `@variables` populated as follows:
  - `weights`: character scalar — the resolved weight column name
  - `repweights`: character vector of resolved replicate column names, or NULL
  - `type`: `"bootstrap"`, `"JK1"`, `"JK2"`, or `"JKn"` (never `"jackknife"`)
    when `repweights` is non-NULL; NULL when `repweights` is NULL
  - `scale`: numeric scalar when `repweights` non-NULL; NULL otherwise
  - `rscales`: numeric vector length R when `repweights` non-NULL; NULL
    otherwise
  - `mse`: logical scalar when `repweights` non-NULL; NULL otherwise
  - `probs_provided`: always `FALSE`
  - `ids`, `strata`, `fpc`, `nest`: NULL, NULL, NULL, FALSE (unchanged)
  - `visible_vars`: NULL (unchanged)

The `@variables` list for `survey_nonprob` always contains exactly these keys;
no others are added or removed by this constructor.

**Errors**:

| Error class | Condition |
|-------------|-----------|
| `surveycore_error_weights_missing` | `weights` argument not supplied |
| `surveycore_error_weights_not_found` | `weights` selects 0 columns |
| `surveycore_error_weights_multiple` | `weights` selects > 1 column |
| `surveycore_error_not_data_frame` | `data` is not a data.frame |
| `surveycore_error_empty_data` | `data` has 0 rows |
| `surveycore_error_repweights_empty` | `repweights` resolves to 0 columns |
| `surveycore_error_repweights_single` | `repweights` resolves to exactly 1 column |
| `surveycore_error_type_unsupported_for_nonprob` | `type` is not in the valid set for `survey_nonprob` (e.g., `"BRR"`, `"Fay"`, `"ACS"`) |
| `surveycore_error_stratified_jk_rscales_unset` | `type` is `"JK2"` or `"JKn"` and `rscales = NULL` |
| `surveycore_error_scale_negative` | user-supplied `scale` is < 0 (after checking NULL; zero is accepted) |
| `surveycore_error_rscales_length` | `rscales` length != R |
| `surveycore_error_rscales_na` | `rscales` contains NA or negative values |
| `surveycore_error_reference_sample_nonprob` | `reference_sample` is non-NULL and not a `survey_taylor` |
| `surveycore_error_provenance_not_bootstrap` | `calibration$bootstrap` is not TRUE when `type = "bootstrap"` and `calibration` is non-NULL |
| `surveycore_error_provenance_R_mismatch` | `calibration$R` is non-NULL and mismatches count of resolved repweight columns |

**Warnings**: none emitted by `as_survey_nonprob()` itself.

**Edge cases**:

- `repweights = NULL`: `type`, `scale`, `rscales`, `mse` are all ignored
  without error. Object is created in SRS-approximation mode.
- `type = "jackknife"` (string alias): normalizes to `"JK1"` before being
  stored in `@variables$type`. The caller-supplied string `"jackknife"` never
  appears in the stored object.
- `type = "JK2"` or `"JKn"` with `rscales = NULL`: raises
  `surveycore_error_stratified_jk_rscales_unset`. JK2/JKn require stratum-specific scale
  factors in `rscales`; the default `rep(1, R)` is statistically incorrect for
  stratified-jackknife designs. The user must supply explicit `rscales`.
  Rationale: silently using `rep(1, R)` for JK2/JKn would produce incorrect
  variance estimates with no indication. An error forces an explicit choice.
- `type = "JK2"` or `"JKn"` with explicit `rscales` (non-NULL): accepted
  without error. `rscales` must still pass the non-negative, non-NA, correct-
  length checks via `.validate_rscales()`.
- `scale = 0`: accepted. Zero scale produces zero variance, which may be
  intentional for diagnostic purposes.
- `scale < 0` (explicit, user-supplied): raises `surveycore_error_scale_negative`.
  Negative variance is nonsensical and caught early. This only fires when the
  caller explicitly supplies a negative value; the `.compute_nonprob_scale()`
  default is always positive.
- `calibration = list(R = 50)` with jackknife type: the `calibration$bootstrap`
  check is bypassed. The `calibration$R` count-match check runs normally.
- `calibration = list(bootstrap = FALSE)` with jackknife type: no error.
  The `bootstrap` field is only checked for `type = "bootstrap"`.
- `repweights` resolving to exactly 1 column: `surveycore_error_repweights_single`
  with type-agnostic message "Replicate variance requires >= 2 replicates."
  (regardless of `type`).
- `calibration = list()` (empty, non-NULL): `calibration$bootstrap` is NULL,
  which causes `isTRUE(NULL) = FALSE`. For `type = "bootstrap"`, this raises
  `surveycore_error_provenance_not_bootstrap`. For JK types, the bootstrap check
  is skipped, so the empty list is accepted without error. Users who want to
  supply provenance without a bootstrap flag should use `calibration = NULL`
  instead.
- All-zero `repweights` column(s): not validated by `as_survey_nonprob()`.
  The S7 validator on `survey_nonprob` checks the main weight column only.

---

### `print.survey_nonprob` (via `S7::method(print, survey_nonprob)`)

**Signature**:
```r
S7::method(print, survey_nonprob) <- function(
  x,
  n            = 10L,
  design_info  = FALSE,
  weights_info = FALSE,
  metadata_info = FALSE,
  full         = FALSE,
  ...
)
```

**Change**: The header line, which currently hard-codes `"BOOTSTRAP"`, must
display the actual `type` value stored in `@variables$type`.

**Specific behavior**:

- When `!is.null(x@variables$repweights)`:
  - Header reads: `<survey_nonprob> (non-probability, {TYPE}, {R} replicates) [experimental]`
  - Where `{TYPE}` = `toupper(x@variables$type)` so that `"JK1"` displays as
    `"JK1"`, `"bootstrap"` displays as `"BOOTSTRAP"`, `"JK2"` as `"JK2"`,
    `"JKn"` as `"JKN"`.
  - The `design_info` section already prints `x@variables$type` via the `Type:`
    bullet; this requires no change.
- When `is.null(x@variables$repweights)`: unchanged — displays
  `<survey_nonprob> (non-probability) [experimental]`.

**Returns**: `x`, invisibly.

**Errors**: none.

**Warnings**: none.

**Edge cases**:
- `type = "JK1"`: header shows `"JK1"`.
- `type = "JK2"`: header shows `"JK2"`.
- `type = "JKn"`: header shows `"JKN"`.
- `type = "bootstrap"`: header shows `"BOOTSTRAP"` (unchanged from existing
  behavior).
- Invariant: `is.null(x@variables$type) == is.null(x@variables$repweights)`.
  The constructor enforces this, so the `repweights` branch in
  `print.survey_nonprob` can access `x@variables$type` without a nil-guard.
  No defensive `if (!is.null(x@variables$type))` is needed inside the
  `repweights` display block.

---

### `summary.survey_nonprob` (via `S7::method(summary, survey_nonprob)`)

**Signature**:
```r
S7::method(summary, survey_nonprob) <- function(object, ...)
```

**Change**: When `@variables$type` is non-NULL, include it in the type
description line. Currently the summary always prints `"Type: non-probability
[experimental]"`. After the change:

- When `repweights` is non-NULL:
  `"Type: non-probability, {toupper(x@variables$type)} replicates [experimental]"`
- When `repweights` is NULL:
  `"Type: non-probability [experimental]"` (unchanged)

The type value is uppercased via `toupper()` for consistency with
`survey_replicate`'s `summary()`. Examples:
- `type = "JK1"` → `"Type: non-probability, JK1 replicates [experimental]"`
- `type = "JKn"` → `"Type: non-probability, JKN replicates [experimental]"`
- `type = "bootstrap"` → `"Type: non-probability, BOOTSTRAP replicates [experimental]"`

The invariant `is.null(x@variables$type) == is.null(x@variables$repweights)`
is enforced by the constructor. No nil-guard for `type` is needed when the
`repweights` branch is taken in `summary.survey_nonprob`.

**Returns**: `object`, invisibly.

**Errors**: none.

**Warnings**: none.

---

## Error message table updates (`plans/error-messages.md`)

### Row NB-1 — replace

Old trigger: `type` is not `"bootstrap"`.
New trigger: `type` is not in the valid set for `survey_nonprob` (i.e., not
`"bootstrap"`, `"JK1"`, `"JK2"`, `"JKn"`, or `"jackknife"`).
New class: `surveycore_error_type_unsupported_for_nonprob` (replaces
`surveycore_error_type_invalid` for this specific condition).

**Rationale for new class vs reusing `surveycore_error_type_invalid`**:
`surveycore_error_type_invalid` (row 18, used by `as_survey_replicate()`) fires
when `type` is unrecognized in *any* replicate constructor context. For
`survey_nonprob`, the situation is different: types like `"BRR"` and `"Fay"`
are valid for `as_survey_replicate()` but unsupported for nonprob designs.
Using a distinct class:
1. Allows a more specific message that says "not supported for nonprob
   designs" rather than "not a valid type."
2. Allows callers to distinguish `surveycore_error_type_unsupported_for_nonprob`
   (user passed a valid-elsewhere type to the wrong constructor) from
   `surveycore_error_type_invalid` (completely unrecognized type string).
3. Does not retire `surveycore_error_type_invalid` — that class remains in use
   by `as_survey_replicate()` and is not affected by this PR.

The existing code at line 1299 of `R/core-constructors.R` uses
`surveycore_error_type_invalid` inside `as_survey_nonprob()`. This line is
replaced by the new validation block that uses
`surveycore_error_type_unsupported_for_nonprob`.

| # | Function | Condition | Level | Error Class | cli Message Template |
|---|----------|-----------|-------|-------------|----------------------|
| NB-1 | `as_survey_nonprob()` | `type` is not in `c("bootstrap", "JK1", "JK2", "JKn", "jackknife")` | ERROR | `surveycore_error_type_unsupported_for_nonprob` | `"x" = "{.arg type} must be one of {.val bootstrap}, {.val JK1}, {.val JK2}, {.val JKn}, or {.val jackknife} for {.cls survey_nonprob} objects.", "i" = "Got {.val {type}}."` |

### Row NB-3 — update message text

Old `"i"` bullet: `"Bootstrap variance requires >= 2 replicates. Got {.val 1}."`
New `"i"` bullet: `"Replicate variance requires >= 2 replicates. Got {.val 1}."`
Error class unchanged: `surveycore_error_repweights_single`.

### New row NB-9

**NB-9 `{type}` variable binding**: The `{type}` in the NB-9 message template
refers to the type value at the time of the error. The NB-9 error fires at
step 10 of the decision tree — *after* alias normalization (step 8) but `"JK2"`
and `"JKn"` are never aliased, so `{type}` at this point is always the
user-supplied string (which is `"JK2"` or `"JKn"` for NB-9 to fire). The
builder need not capture the pre-normalization value; `{type}` is always
unambiguous here.

Class name: `surveycore_error_stratified_jk_rscales_unset` (covers JK2 and JKn;
the name `_rscales_unset` precisely names the missing argument, and `stratified_jk`
covers both `"JK2"` and `"JKn"`).

| # | Function | Condition | Level | Error Class | cli Message Template |
|---|----------|-----------|-------|-------------|----------------------|
| NB-9 | `as_survey_nonprob()` | `type` is `"JK2"` or `"JKn"` and `rscales = NULL` | ERROR | `surveycore_error_stratified_jk_rscales_unset` | `"x" = "{.arg type} = {.val {type}} requires explicit {.arg rscales}.", "i" = "Stratified jackknife rscales are stratum-specific: {.code (n_h - 1) / n_h}. Supplying {.code NULL} would silently use {.code rep(1, R)}, which is statistically incorrect for JK2/JKn.", "v" = "Compute {.code rscales} as {.code (n_h - 1) / n_h} where {.code n_h} is the number of units in stratum {.code h}, indexed to replicate order."` |

### New row NB-10

| # | Function | Condition | Level | Error Class | cli Message Template |
|---|----------|-----------|-------|-------------|----------------------|
| NB-10 | `as_survey_nonprob()` | user-supplied `scale` is `< 0` (zero is accepted) | ERROR | `surveycore_error_scale_negative` | `"x" = "{.arg scale} must be >= 0. Got {.val {scale}}.", "i" = "A negative scale factor produces negative variance, which is nonsensical.", "v" = "Use {.code scale = 0} to exclude a replicate's contribution, or omit {.arg scale} to use the type-specific default."` |

---

## Quality gates

**Pre-implementation gate** (must be the first commit in the PR, before any
`.R` source changes):
- [ ] `plans/error-messages.md` updated: NB-1 replaced with
  `surveycore_error_type_unsupported_for_nonprob`, NB-3 message text updated,
  NB-9 (`surveycore_error_stratified_jk_rscales_unset`) added, NB-10
  (`surveycore_error_scale_negative`) added.

**Post-implementation gates**:
- `S7::S7_inherits(result, survey_nonprob)` holds for all valid inputs.
- `result@variables$type` is always `NULL`, `"bootstrap"`, `"JK1"`, `"JK2"`,
  or `"JKn"` — never `"jackknife"` (alias must be normalized before storage).
- When `repweights = NULL`, `result@variables$type` is `NULL`.
- When `type = "jackknife"` is supplied, `result@variables$type == "JK1"`.
- For bootstrap: `result@variables$scale == 1 / length(result@variables$repweights)`.
- For JK1: `result@variables$scale == (R - 1) / R` where
  `R = length(result@variables$repweights)`.
- For JK2 and JKn: `result@variables$scale == 1` (when `scale = NULL`
  default), and these types require explicit `rscales` (cannot reach this
  state from valid constructor call without explicit rscales).
- `result@variables$rscales` is a numeric vector of length R when repweights
  is non-NULL.
- Bootstrap behavior is unchanged: existing test suite must pass without
  modification.
- `devtools::check()` produces 0 errors, 0 warnings.

---

## Pipeline split

`recommended` — new exported-function–adjacent behavior (new type enum values,
new error classes, print changes), two function bodies modified, and error-
messages.md must be updated. Warrants a full PR with spec review.
