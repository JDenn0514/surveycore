# extract_var_label() still rejects fill = NA (sibling regression)

    Code
      extract_var_label(d, fill = NA)
    Condition
      Error:
      x `extract_var_label()` does not accept `fill = NA`.
      i Valid values for `extract_var_label()`: "NULL" (omit) or `NA_character_` (include with NA).

# extract_dataset_metadata() rejects a non-survey, non-frame x

    Code
      extract_dataset_metadata(1L)
    Condition
      Error:
      x `x` must be a survey design object or a data frame, not <integer>.
      v Create a survey object with `as_survey()`, `as_survey_replicate()`, or `as_survey_twophase()`.

# extract_dataset_metadata() rejects both ... and key together

    Code
      extract_dataset_metadata(d, vendor, key = "vendor")
    Condition
      Error:
      x Provide key names via `...` or via `key`, not both.
      i Use named `...` args, a named list in `...`, or the `key` argument — not a mix.

# extract_dataset_metadata() rejects a tidyselect helper in ...

    Code
      extract_dataset_metadata(d, all_of("vendor"))
    Condition
      Error:
      x `...` must contain bare key names or strings.
      i Tidy-select helpers do not apply here: a dataset metadata key is not a column.
      v Use bare names (`vendor`), strings ("vendor"), or the `key` argument.

# extract_dataset_metadata() rejects an unknown requested key

    Code
      extract_dataset_metadata(d, mode)
    Condition
      Error:
      x "mode" is not a dataset metadata key.
      i Valid keys: "survey_name", "data_name", "vendor", "field_start", "field_end", and "field_period".

# extract_dataset_metadata() rejects an invalid format

    Code
      extract_dataset_metadata(d, format = "named_vector")
    Condition
      Error:
      x `extract_dataset_metadata()` received an invalid `format` value "named_vector".
      i `format` must be one of "list" and "data_frame".

# extract_dataset_metadata() rejects an invalid fill

    Code
      extract_dataset_metadata(d, fill = "none")
    Condition
      Error:
      x `extract_dataset_metadata()` does not accept `fill = "none"`.
      i Valid values for `extract_dataset_metadata()`: "NULL" (omit), `NA`, or `NA_character_` (include with NA).

# set_var_label() keeps the default setter_ambiguous wording

    Code
      set_var_label(d, y1 = "A", variable = "y2")
    Condition
      Error:
      x Provide variable names via `...` or via `variable`, not both.
      i Use named `...` args, a named vector in `...`, or `variable` + `label` — not a mix.

# set_var_label() keeps the default setter_empty wording

    Code
      set_var_label(d)
    Condition
      Error:
      x `set_var_label()` requires at least one variable-label pair.
      v Use named `...` args: `set_var_label(x, age = 'Age in years')`.

# set_var_label() keeps the default empty_variables wording

    Code
      set_var_label(d, variable = character(0))
    Condition
      Warning:
      ! `set_var_label()` was called with `variable` of length 0.
      i No metadata was set. Did you accidentally filter all variable names out?

# set_var_label() keeps the default mismatched_lengths wording

    Code
      set_var_label(d, variable = c("y1", "y2"), label = "A")
    Condition
      Error:
      x `variable` has 2 elements but `label` has 1 element.
      i They must be the same length (one content value per variable name).

# set_var_label() keeps the default mixed_dots wording

    Code
      set_var_label(d, "y1", "y2", "y3")
    Condition
      Error:
      x All `...` arguments must be named when using Convention 1.
      i Got 0 named and 3 unnamed elements.
      v Use `set_var_label(x, age = 'Age', income = 'Annual income')` or a fully named vector.

# set_dataset_metadata() rejects both ... and key on a design

    Code
      set_dataset_metadata(d, vendor = "Ipsos", key = "vendor")
    Condition
      Error:
      x Provide key names via `...` or via `key`, not both.
      i Use named `...` args, a named list in `...`, or `key` + `value` — not a mix.

# set_dataset_metadata() rejects a call with no key at all

    Code
      set_dataset_metadata(d)
    Condition
      Error:
      x `set_dataset_metadata()` requires at least one key-value pair.
      v Use named `...` args: `set_dataset_metadata(x, vendor = 'Ipsos')`.

# set_dataset_metadata() warns and no-ops for a length-0 key

    Code
      set_dataset_metadata(d, key = character(0))
    Condition
      Warning:
      ! `set_dataset_metadata()` was called with `key` of length 0.
      i No metadata was set. Did you accidentally filter all key names out?

# set_dataset_metadata() rejects mismatched key and value lengths

    Code
      set_dataset_metadata(d, key = c("vendor", "data_name"), value = list("Ipsos"))
    Condition
      Error:
      x `key` has 2 elements but `value` has 1 element.
      i They must be the same length (one content value per key name).

# set_dataset_metadata() rejects unnamed ... elements

    Code
      set_dataset_metadata(d, "vendor", "data_name")
    Condition
      Error:
      x All `...` arguments must be named when using Convention 1.
      i Got 0 named and 2 unnamed elements.
      v Use `set_dataset_metadata(x, vendor = 'Ipsos', data_name = 'AAA Ipsos (February-March 2026)')` or a fully named list.

# set_dataset_metadata() rejects a blank key name on a design

    Code
      set_dataset_metadata(d, key = c(""))
    Condition
      Error:
      x All dataset metadata keys must have a non-empty name.
      i Found 1 unnamed or blank-named entry.

# set_dataset_metadata() counts every blank key name

    Code
      set_dataset_metadata(d, key = c("", "vendor", ""))
    Condition
      Error:
      x All dataset metadata keys must have a non-empty name.
      i Found 2 unnamed or blank-named entries.

# set_dataset_metadata() rejects a duplicated named ... key

    Code
      set_dataset_metadata(d, vendor = "Ipsos", vendor = "Cint")
    Condition
      Error:
      x Duplicate dataset metadata key: "vendor".
      i Each key must appear exactly once.

# set_dataset_metadata() rejects a duplicated Convention 3 key

    Code
      set_dataset_metadata(d, key = c("vendor", "vendor"), value = list("Ipsos",
        "Cint"))
    Condition
      Error:
      x Duplicate dataset metadata key: "vendor".
      i Each key must appear exactly once.

# the dates alias resolves before the duplicate check

    Code
      set_dataset_metadata(d, dates = NULL, field_period = "Feb 2026")
    Condition
      Error:
      x Duplicate dataset metadata key: "field_period".
      i Each key must appear exactly once.

# set_dataset_metadata() rejects an unknown key on a design

    Code
      set_dataset_metadata(d, mode = "web")
    Condition
      Error:
      x "mode" is not a dataset metadata key.
      i Valid keys: "survey_name", "data_name", "vendor", "field_start", "field_end", and "field_period".

# an unknown key with the wrong case shows the did-you-mean hint

    Code
      set_dataset_metadata(d, Vendor = "Ipsos")
    Condition
      Error:
      x "Vendor" is not a dataset metadata key.
      i Valid keys: "survey_name", "data_name", "vendor", "field_start", "field_end", and "field_period".
      i Did you mean "vendor"?

# a misspelled unknown key shows the did-you-mean hint

    Code
      set_dataset_metadata(d, vender = "Ipsos")
    Condition
      Error:
      x "vender" is not a dataset metadata key.
      i Valid keys: "survey_name", "data_name", "vendor", "field_start", "field_end", and "field_period".
      i Did you mean "vendor"?

# the did-you-mean hint also fires on a frame

    Code
      set_dataset_metadata(df, vender = "Ipsos")
    Condition
      Error:
      x "vender" is not a dataset metadata key.
      i Valid keys: "survey_name", "data_name", "vendor", "field_start", "field_end", and "field_period".
      i Did you mean "vendor"?

# a non-NULL dates value is an unknown key naming field_period

    Code
      set_dataset_metadata(d, dates = "February-March 2026")
    Condition
      Error:
      x "dates" is not a dataset metadata key.
      i Valid keys: "survey_name", "data_name", "vendor", "field_start", "field_end", and "field_period".
      i The legacy "dates" attribute maps to "field_period".
      v Use `set_field_period()`, or `dates = NULL` to delete.

# a non-character key is coerced and then fails as unknown

    Code
      set_dataset_metadata(d, key = 1L, value = list("Ipsos"))
    Condition
      Error:
      x "1" is not a dataset metadata key.
      i Valid keys: "survey_name", "data_name", "vendor", "field_start", "field_end", and "field_period".

# the extractor renders the completed unknown-key hint on a design

    Code
      extract_dataset_metadata(d, vender)
    Condition
      Error:
      x "vender" is not a dataset metadata key.
      i Valid keys: "survey_name", "data_name", "vendor", "field_start", "field_end", and "field_period".
      i Did you mean "vendor"?

# the extractor renders the completed unknown-key hint on a frame

    Code
      extract_dataset_metadata(df, vender)
    Condition
      Error:
      x "vender" is not a dataset metadata key.
      i Valid keys: "survey_name", "data_name", "vendor", "field_start", "field_end", and "field_period".
      i Did you mean "vendor"?

