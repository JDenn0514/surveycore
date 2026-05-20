# Spec: Bootstrap Variance for `survey_nonprob`

**Status:** Draft  
**Phase:** 2.5  
**Created:** 2026-05-18

---

## Background

`survey_nonprob` is currently a Phase 2.5 skeleton. It accepts pre-computed
calibration weights and estimates variance using an HT Taylor linearization
under an SRS assumption — a known approximation that ignores calibration
estimation uncertainty and produces standard errors that are too small.

The correct variance for a calibrated or IPW-weighted non-probability sample
requires re-running the adjustment step (raking, calibration, or propensity
estimation) on each bootstrap replicate. This re-running step belongs in
`surveywts`, which already produces bootstrap replicate weight columns via
`create_bootstrap_weights()`. This spec covers only the `surveycore` side:
accepting those replicate weight columns and computing variance from their
spread.

### Workflow

```
surveywts::rake(data, benchmarks)
  └── surveywts::create_bootstrap_weights(result, R = 200)
        └── as_survey_nonprob(data, weights = cal_wt,
                              repweights = starts_with("repwt_"),
                              calibration = boot$provenance)
              └── get_means() / get_freqs() / etc.
                    → SE from replicate spread (correct)
```

Without `repweights`, the existing SRS Taylor fallback is preserved with a
warning so existing code does not break.

---

## Goals

1. `as_survey_nonprob()` accepts bootstrap replicate weight columns produced
   by `surveywts::create_bootstrap_weights()`.
2. When repweights are present, all analysis functions compute SE from the
   replicate spread — identical machinery to `survey_replicate`.
3. When repweights are absent, the existing SRS Taylor approximation is
   preserved and a warning is emitted at estimation time (not construction
   time).
4. No new internal helpers are needed — the existing `.replicate_mean_cell()`
   and `.replicate_variance_cell()` helpers work without modification once
   `survey_nonprob`'s `@variables` carries the required keys.
5. `survey_nonprob` retains its class identity and `@calibration` provenance
   field — it is not replaced by `survey_replicate`.

---

## Out of Scope

- Propensity score estimation, outcome regression, or doubly-robust
  estimation — these belong in `surveywts`.
- Analytical (sandwich / linearization) variance for NPS — requires the
  propensity model Hessian and belongs in `surveywts` alongside the model.
- Mass imputation estimators.
- Any change to `surveywts` itself.

---

## Design

### 1. Class: `survey_nonprob` (`R/core-classes.R`)

No new S7 properties. All replicate metadata is carried in `@variables`,
consistent with `survey_replicate`.

**New optional keys added to `@variables`:**

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `repweights` | `character` or `NULL` | `NULL` | Column names of bootstrap replicate weight columns in `@data`. |
| `type` | `character` | `"bootstrap"` | Replicate weight method. One of the same values accepted by `as_survey_replicate()`. |
| `scale` | `numeric` | `1/R` | Variance scaling factor. Defaults to `1/R` where R = number of repweight columns. |
| `rscales` | `numeric` or `NULL` | `rep(1, R)` | Per-replicate scaling factors. |
| `mse` | `logical` | `TRUE` | Whether to use MSE-type variance estimates. |

All existing `@variables` keys (`weights`, `probs_provided`, `ids`, `strata`,
`fpc`, `nest`, `visible_vars`) are unchanged.

**Validator addition:** When `@variables$repweights` is non-NULL, verify all
named columns exist in `@data`. Reuse the same error class
(`surveycore_error_design_var_missing`) used by `survey_replicate`'s
validator.

### 2. Constructor: `as_survey_nonprob()` (`R/core-constructors.R`)

Five new optional arguments added after `calibration`:

```r
as_survey_nonprob <- function(
  data,
  weights,
  repweights  = NULL,
  type        = "bootstrap",
  scale       = NULL,
  rscales     = NULL,
  mse         = TRUE,
  calibration = NULL
)
```

**`repweights`** uses the same tidy-select resolution as `as_survey_replicate()`:
bare names, `starts_with()`, `matches()`, etc. Resolves to a character vector
of column names. When `NULL`, the object is created without replicate weights
and is backward-compatible with all existing code.

**`scale` default:** When `repweights` is provided but `scale` is not, default
to `1 / length(repweights_vars)` — the standard bootstrap scaling factor.

**`rscales` default:** When `repweights` is provided but `rscales` is not,
default to `rep(1, length(repweights_vars))`.

**`@variables` construction:** The five new keys are always written to
`@variables` (with their defaults) when `repweights` is non-NULL. When
`repweights` is NULL, the keys are not added (preserving the existing
`@variables` structure for backward compatibility).

### 3. Variance dispatch (`R/analysis-means-helpers.R`,
`R/analysis-variance-helpers.R`, and all other `R/analysis-*-helpers.R`
files with a `survey_nonprob` branch)

Each dispatch function that currently routes `survey_nonprob` to a dedicated
helper gets a two-line repweights check inserted before the fallback:

```r
} else if (S7::S7_inherits(design, survey_nonprob)) {
  if (!is.null(design@variables$repweights)) {
    .replicate_mean_cell(design, y_col, domain)   # unchanged existing helper
  } else {
    cli::cli_warn(
      c(
        "!" = paste0(
          "{.cls survey_nonprob} object has no bootstrap replicate weights. ",
          "Standard errors use an SRS approximation that underestimates ",
          "calibration uncertainty."
        ),
        "i" = paste0(
          "Run {.fn surveywts::create_bootstrap_weights} and pass the result ",
          "to {.arg repweights} in {.fn as_survey_nonprob} for correct SEs."
        )
      ),
      class = "surveycore_warning_nonprob_srs_fallback"
    )
    .calibrated_mean_cell(design, y_col, domain)  # existing SRS approximation
  }
}
```

The warning fires **at estimation time**, not at construction time. This
prevents the warning from appearing every time the object is printed or
inspected.

**Why the existing replicate helpers work without modification:** Both
`.replicate_mean_cell()` and `.replicate_variance_cell()` access only
`design@data`, `design@variables$weights`, `design@variables$repweights`,
`design@variables$scale`, `design@variables$rscales`, and
`design@variables$mse`. Once `survey_nonprob`'s `@variables` carries those
keys, the helpers are fully reusable. No shared helper extraction is needed.

**Files to update** (all files in `R/` with a confirmed `survey_nonprob` dispatch branch):

- `R/analysis-means-helpers.R` — `.mean_cell()`
- `R/analysis-variance-helpers.R` — `.variance_cell()`
- `R/analysis-freqs-helpers.R` — `.freq_cell()`
- `R/analysis-totals-helpers.R` — `.total_cell()`
- `R/analysis-corr-helpers.R` — correlation dispatch
- `R/analysis-covariance-helpers.R` — covariance dispatch

### 4. Print method (`R/methods-print.R`)

The `survey_nonprob` print method gets two new output branches:

- **With repweights:** Show replicate count (R), type, and scale alongside
  the weight summary. Example: `Bootstrap replicate weights: 200 replicates
  (type = "bootstrap", scale = 0.005)`.
- **Without repweights:** Append a one-line note: `Variance: SRS
  approximation (no bootstrap replicate weights)`.

### 5. New error/warning class

Add to `plans/error-messages.md`:

| Class | Type | Trigger |
|-------|------|---------|
| `surveycore_warning_nonprob_srs_fallback` | warning | `get_*()` called on a `survey_nonprob` without repweights |

---

## Backward Compatibility

All existing calls to `as_survey_nonprob(data, weights = cal_wt)` continue to
work without modification. The only behavioral change for existing code is a
new warning emitted the first time an analysis function is called on such an
object.

---

## Testing

### Happy path
- `as_survey_nonprob()` with `repweights` creates correct `@variables`
- `get_means()` on a repweight-equipped object returns SE from replicate
  spread (matches manual computation)
- SE agrees with `survey_replicate` when given identical weights and replicates
- `scale` and `rscales` defaults computed correctly from R

### Warning path
- `get_means()` on a no-repweights `survey_nonprob` emits
  `surveycore_warning_nonprob_srs_fallback`
- Warning fires at estimation time, not at construction time (snapshot test)

### Error paths
- `repweights` columns not found in data → `surveycore_error_design_var_missing`
- `repweights` resolves to zero columns → clear error
- `scale` / `rscales` length mismatch with R → clear error

### Backward compatibility
- Existing `as_survey_nonprob(data, weights = cal_wt)` creates a valid object
- `@variables` keys for repweights are absent (not NULL-valued keys) when
  no repweights provided

### Print
- Snapshot test for print output with repweights
- Snapshot test for print output without repweights (SRS note visible)

---

## Open Questions

- Should `surveycore_warning_nonprob_srs_fallback` be suppressible at the
  object level (e.g., a `quiet = TRUE` arg to `as_survey_nonprob()`) or only
  via `suppressWarnings()`? The simpler approach is `suppressWarnings()` only.
- Should `type` be validated against the same set of valid values as
  `as_survey_replicate()`? Yes — reuse the same validation.
