# get_totals() errors for non-numeric variable

    Code
      get_totals(d, y)
    Condition
      Error in `get_totals()`:
      x `x` must be numeric, not <character>.
      i Column y cannot be used with `get_totals()`.

# get_totals() errors for invalid variance value

    Code
      get_totals(d, y, variance = "bad_val")
    Condition
      Error in `get_totals()`:
      x `variance` values must be from "se", "ci", "var", "cv", "moe", or "deff".
      i Unknown value: "bad_val".

