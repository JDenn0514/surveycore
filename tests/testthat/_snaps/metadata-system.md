# set_var_label() error snapshot [row 27]

    Code
      set_var_label(d, zzz_missing, "Label")
    Condition
      Error in `set_var_label()`:
      x Variable zzz_missing not found in `x`.
      i Available: age, sex, income, and wt

# set_val_labels() warning snapshot [row 30]

    Code
      set_val_labels(d, sex, c(Male = 1L))
    Condition
      Warning:
      ! Not all values of sex are labeled.
      i Unlabeled values: "2"

# set_val_labels() error snapshot for unnamed labels [row 29]

    Code
      set_val_labels(d, sex, c(1L, 2L))
    Condition
      Error in `set_val_labels()`:
      x `labels` must be a fully named vector.
      i All elements must have names.

# set_variable_labels() error snapshot [row 28]

    Code
      set_variable_labels(d, age = "Age", zzz_missing = "Gone")
    Condition
      Error in `set_variable_labels()`:
      x Variable(s) not found in `x`: zzz_missing

