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

# snapshot: .check_is_survey_or_df() surveycore_error_not_survey_or_df for list input

    Code
      surveycore:::.check_is_survey_or_df(list(x = 1))
    Condition
      Error:
      x `x` must be a survey design object or a data frame, not <list>.
      v Create a survey object with `as_survey()`, `as_survey_replicate()`, or `as_survey_twophase()`.

# snapshot: surveycore_error_setter_mismatched_lengths message

    Code
      surveycore:::.parse_setter_input(dots = list(), variable = c("age", "income"),
      content = c("Age in years"), content_arg_name = "label", content_type = "scalar",
      fn_name = "set_var_label")
    Condition
      Error:
      x `variable` has 2 elements but `label` has 1 element.
      i They must be the same length (one content value per variable name).

# snapshot: surveycore_error_setter_ambiguous message

    Code
      surveycore:::.parse_setter_input(dots = list(age = "Age"), variable = "income",
      content = "Annual income", content_arg_name = "label", content_type = "scalar",
      fn_name = "set_var_label")
    Condition
      Error:
      x Provide variable names via `...` or via `variable`, not both.
      i Use named `...` args, a named vector in `...`, or `variable` + `label` — not a mix.

# snapshot: surveycore_error_setter_empty message

    Code
      surveycore:::.parse_setter_input(dots = list(), variable = NULL, content = NULL,
      content_arg_name = "label", content_type = "scalar", fn_name = "set_var_label")
    Condition
      Error:
      x `set_var_label()` requires at least one variable-label pair.
      v Use named `...` args: `set_var_label(x, age = 'Age in years')`.

# snapshot: surveycore_error_setter_mixed_dots message

    Code
      surveycore:::.parse_setter_input(dots = dots, variable = NULL, content = NULL,
        content_arg_name = "label", content_type = "scalar", fn_name = "set_var_label")
    Condition
      Error:
      x All `...` arguments must be named when using Convention 1.
      i Got 0 named and 1 unnamed element.
      v Use `set_var_label(x, age = 'Age', income = 'Annual income')` or a fully named vector.

# snapshot: .resolve_vars() surveycore_warning_var_not_found message

    Code
      surveycore:::.resolve_vars(d, var_exprs = var_exprs)
    Condition
      Warning:
      ! 1 variable not found in `x` and was skipped: zzz_missing.
    Output
      character(0)

# snapshot: .format_list_result() surveycore_error_format_invalid message

    Code
      surveycore:::.format_list_result(result_list, format = "named_vector", fn_name = "extract_val_labels")
    Condition
      Error in `surveycore:::.format_list_result()`:
      x `extract_val_labels()` received an invalid `format` value "named_vector".
      i `format` must be one of "list" and "data_frame".

