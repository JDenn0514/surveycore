# get_variance() errors when every replicate weight is NA on a row inside a cell

    Code
      get_variance(d, y1, group = group, variance = .cg_variance, n_weighted = TRUE,
        min_cell_n = 0L)
    Condition
      Error in `.svy_rep_var()`:
      x All replicates produced NA estimates.

# get_variance() errors on a single-PSU stratum when lonely.psu is fail

    Code
      calls$variance()
    Condition
      Error in `.svy_onestrat()`:
      x Stratum 6 has only one PSU at stage 1.

# get_variance() errors on a single-PSU stratum when lonely.psu is an unknown value

    Code
      calls$variance()
    Condition
      Error in `.svy_onestrat()`:
      x Unknown `lonely.psu` value: "unknown_value".

# get_variance() errors on a single-PSU stratum under fail when the call has 65 cells

    Code
      get_variance(d, y1, group = g65, variance = .cg_variance, n_weighted = TRUE,
        min_cell_n = 0L)
    Condition
      Error in `.svy_onestrat()`:
      x Stratum 6 has only one PSU at stage 1.

# get_variance() errors on a single-PSU stratum under fail when its only cell has an NA and na.rm = FALSE

    Code
      get_variance(d, y1_na, na.rm = FALSE, variance = .cg_variance, n_weighted = TRUE,
        min_cell_n = 0L)
    Condition
      Error in `.svy_onestrat()`:
      x Stratum 6 has only one PSU at stage 1.

# get_freqs() errors when every replicate weight is NA on a row outside the domain

    Code
      get_freqs(d, f5, variance = .cg_variance, n_weighted = TRUE, min_cell_n = 0L)
    Condition
      Error in `.svy_rep_var()`:
      x All replicates produced NA estimates.

# get_freqs() errors on a single-PSU stratum when lonely.psu is fail

    Code
      calls$freqs()
    Condition
      Error in `.svy_onestrat()`:
      x Stratum 6 has only one PSU at stage 1.

# get_freqs() errors on a single-PSU stratum when lonely.psu is an unknown value

    Code
      calls$freqs()
    Condition
      Error in `.svy_onestrat()`:
      x Unknown `lonely.psu` value: "unknown_value".

# get_freqs() errors on an all-NA variable when na.rm is FALSE

    Code
      get_freqs(d, y_allna, na.rm = FALSE, variance = .cg_variance, n_weighted = TRUE,
        min_cell_n = 0L)
    Condition
      Error in `get_freqs()`:
      x All values of y_allna are `NA`.
      i Cannot compute estimate with `na.rm = FALSE`. Set `na.rm = TRUE` to exclude `NA` values.

# get_covariance() errors when every replicate weight is NA on a row inside a cell

    Code
      get_covariance(d, c(y1, y2), group = group, variance = .cg_variance,
      n_weighted = TRUE, min_cell_n = 0L)
    Condition
      Error in `.svy_rep_var()`:
      x All replicates produced NA estimates.

# get_covariance() errors on a single-PSU stratum when lonely.psu is fail

    Code
      calls$covariance()
    Condition
      Error in `.svy_onestrat()`:
      x Stratum 6 has only one PSU at stage 1.

# get_covariance() errors on a single-PSU stratum when lonely.psu is an unknown value

    Code
      calls$covariance()
    Condition
      Error in `.svy_onestrat()`:
      x Unknown `lonely.psu` value: "unknown_value".

# get_covariance() errors on a single-PSU stratum under fail when the call has 65 cells

    Code
      get_covariance(d, c(y1, y2), group = g65, variance = .cg_variance, n_weighted = TRUE,
      min_cell_n = 0L)
    Condition
      Error in `.svy_onestrat()`:
      x Stratum 6 has only one PSU at stage 1.

# get_covariance() errors on a single-PSU stratum under fail when its only pair has an NA and na.rm = FALSE

    Code
      get_covariance(d, c(y1_na, y2), na.rm = FALSE, variance = .cg_variance,
      n_weighted = TRUE, min_cell_n = 0L)
    Condition
      Error in `.svy_onestrat()`:
      x Stratum 6 has only one PSU at stage 1.

# get_means() errors when x is NA in a cell with na.rm = FALSE on a replicate design

    Code
      get_means(d, y1_na, group = group, na.rm = FALSE, variance = .cg_variance,
        n_weighted = TRUE, min_cell_n = 0L)
    Condition
      Error in `.svy_rep_var()`:
      x All replicates produced NA estimates.

# get_means() errors on a single-PSU stratum when lonely.psu is fail

    Code
      calls$means()
    Condition
      Error in `.svy_onestrat()`:
      x Stratum 6 has only one PSU at stage 1.

# get_means() errors on a single-PSU stratum when lonely.psu is an unknown value

    Code
      calls$means()
    Condition
      Error in `.svy_onestrat()`:
      x Unknown `lonely.psu` value: "unknown_value".

