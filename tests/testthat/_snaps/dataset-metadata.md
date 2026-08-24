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

