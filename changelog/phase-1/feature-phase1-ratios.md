# Changelog — feature/phase1-ratios

## New functions

### `get_ratios()`

Survey-weighted ratio estimation (numerator total / denominator total) with
design-correct standard errors. Equivalent to `survey::svyratio()`.

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

**Variance method:**

- **Taylor / SRS / calibrated / twophase**: delta method — linearizes ratio as
  `z_i = y_i - ratio * x_i`, injects the linearized variable into `design@data`,
  and computes `SE(total(z)) / |total_x|` via the existing `.total_cell()`
  dispatch machinery.

- **Replicate designs**: direct per-replicate computation — computes
  `ratio_r = total_y_r / total_x_r` for each replicate weight set and passes
  to `.svy_rep_var()`. This matches `survey::svyratio()` exactly; the delta
  method approach produces different SE values for replicate designs because
  it approximates per-replicate ratios via linearization rather than computing
  them directly.

**Output class:** `survey_ratios` (inherits `survey_result`)

**New error class:** `surveycore_error_ratio_zero_denominator` — fires when all
denominator values in the active domain are zero.

**Oracle:** Validated against `survey::svyratio()` for Taylor (synthetic +
NHANES), BRR replicate, and SRS designs at 1e-10 (point), 1e-8 (SE),
1e-6 (CI) tolerances.
