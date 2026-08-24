# extract_var_label() still rejects fill = NA (sibling regression)

    Code
      extract_var_label(d, fill = NA)
    Condition
      Error:
      x `extract_var_label()` does not accept `fill = NA`.
      i Valid values for `extract_var_label()`: "NULL" (omit) or `NA_character_` (include with NA).

