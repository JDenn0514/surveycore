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

