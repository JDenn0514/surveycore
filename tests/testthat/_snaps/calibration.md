# as_caldata() errors on empty base_weights (n = 0, R-6)

    Code
      as_caldata(numeric(0), numeric(0), matrix(0, 0, 1))
    Condition
      Error in `as_caldata()`:
      x `base_weights` must be strictly positive.
      i All values must be > 0. Got 0 non-positive values.
      v Ensure all sampling weights are positive before calibration.

# as_caldata() rejects non-positive base_weights

    Code
      as_caldata(bw_bad, g, mm)
    Condition
      Error in `as_caldata()`:
      x `base_weights` must be strictly positive.
      i All values must be > 0. Got 1 non-positive value.
      v Ensure all sampling weights are positive before calibration.

# as_caldata() rejects NA in base_weights (B-4)

    Code
      as_caldata(bw_na, g, mm)
    Condition
      Error in `as_caldata()`:
      x `base_weights` contains non-finite values (1 value).
      i `base_weights` must be a fully finite numeric vector. Check for `NA`, `NaN`, or `Inf` values.
      v Remove or impute non-finite values before calling `as_caldata()`.

# as_caldata() rejects Inf in base_weights (B-4)

    Code
      as_caldata(bw_inf, g, mm)
    Condition
      Error in `as_caldata()`:
      x `base_weights` contains non-finite values (1 value).
      i `base_weights` must be a fully finite numeric vector. Check for `NA`, `NaN`, or `Inf` values.
      v Remove or impute non-finite values before calling `as_caldata()`.

# as_caldata() rejects non-positive g_weights

    Code
      as_caldata(base_w, g_bad, mm)
    Condition
      Error in `as_caldata()`:
      x `g_weights` must be strictly positive.
      i All g-factors must be > 0. Got 1 non-positive value.
      v Ensure all g-factors are positive. A g-factor of 1.0 means no adjustment.

# as_caldata() rejects NA in g_weights (B-4)

    Code
      as_caldata(base_w, g_na, mm)
    Condition
      Error in `as_caldata()`:
      x `g_weights` contains non-finite values.
      i `g_weights` must be a fully finite numeric vector. Check for `NA`, `NaN`, or `Inf` values.
      v Remove or impute non-finite values before calling `as_caldata()`.

# as_caldata() rejects g_weights of wrong length (B-3)

    Code
      as_caldata(base_w, g_short, mm)
    Condition
      Error in `as_caldata()`:
      x `g_weights` length (5) must equal `base_weights` length (10).
      i Each observation must have exactly one base weight and one g-factor. Supply vectors of equal length.

# as_caldata() rejects near-zero g_weights * sqrt(base_weights)

    Code
      as_caldata(base_w, g_tiny, mm)
    Condition
      Error in `as_caldata()`:
      x `g_weights` * sqrt(`base_weights`) contains near-zero values (10 values).
      i The product `g_weights` * sqrt(`base_weights`) must be above `.Machine$double.eps^0.5` for all observations.
      v Review g-factors; values near 0 indicate near-zero calibrated weights.

# as_caldata() rejects model_matrix with wrong number of rows

    Code
      as_caldata(base_w, g, mm_wrong)
    Condition
      Error in `as_caldata()`:
      x `model_matrix` has 5 rows but `base_weights` has length 10.
      i The number of rows in `model_matrix` must equal the number of observations (length of `base_weights`).

# as_caldata() rejects model_matrix with 0 columns

    Code
      as_caldata(base_w, g, mm_empty)
    Condition
      Error in `as_caldata()`:
      x `model_matrix` must have at least 1 column.
      i A calibration model requires at least one covariate column. An intercept-only model uses a column of all 1s.
      v Use `matrix(1, nrow = n, ncol = 1)` for an intercept-only calibration model.

# as_caldata() rejects model_matrix with NA values

    Code
      as_caldata(base_w, g, mm_na)
    Condition
      Error in `as_caldata()`:
      x `model_matrix` contains non-finite values.
      i `model_matrix` must contain only finite numeric values. Check for `NA`, `NaN`, or `Inf` in the matrix.
      v Impute or remove non-finite entries before calling `as_caldata()`.

# as_caldata() rejects model_matrix with Inf values

    Code
      as_caldata(base_w, g, mm_inf)
    Condition
      Error in `as_caldata()`:
      x `model_matrix` contains non-finite values.
      i `model_matrix` must contain only finite numeric values. Check for `NA`, `NaN`, or `Inf` in the matrix.
      v Impute or remove non-finite entries before calling `as_caldata()`.

