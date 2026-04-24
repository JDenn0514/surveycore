# single-level ordinal emits PC-4

    Code
      get_corr(d, x = c(o1, o2), method = "polychoric")
    Condition
      Error in `.corr_estimate_thresholds()`:
      x Ordinal variable o1 has only 1 observed level in the active domain.
      i Threshold estimation requires at least 2 distinct levels.
      v Filter to a domain with more than one level of o1.

# integer with 15 distinct values + polyserial raises PC-3

    Code
      get_corr(d, x = c(x1, cont), method = "polyserial")
    Condition
      Error in `.corr_canonicalize_polyserial()`:
      x Cannot determine whether x1 is ordinal or continuous.
      i Integer vectors with more than 10 distinct values, and logical / character vectors, are ambiguous.
      v Coerce to <ordered> for ordinal or <double> for continuous before calling `get_corr()`.

# character column + method = 'polychoric' raises PC-1

    Code
      get_corr(d, x = c(o1, s1), method = "polychoric")
    Condition
      Error in `.corr_latent_pair()`:
      x `method = "polychoric"` requires ordinal variables. Non-ordinal column: s1 (<character>).
      v Coerce to <factor> or <ordered>, or use `method = "pearson"`.

