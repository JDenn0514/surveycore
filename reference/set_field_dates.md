# Set the Field Dates

Sets the `field_start` and `field_end` dataset-level metadata keys — the
first and last day in the field — on a survey design object or a data
frame.

## Usage

``` r
set_field_dates(x, field_start, field_end)
```

## Arguments

- x:

  A survey design object or `data.frame`.

- field_start:

  `Date(1)`, an ISO 8601 `character(1)`, or `NULL` to delete the key.
  Omit the argument to leave the stored value unchanged.

- field_end:

  `Date(1)`, an ISO 8601 `character(1)`, or `NULL` to delete the key.
  Omit the argument to leave the stored value unchanged.

## Value

The modified object, invisibly.

## Details

A convenience wrapper for
[`set_dataset_metadata()`](https://jdenn0514.github.io/surveycore/reference/set_dataset_metadata.md)
that forwards **only the arguments the call supplies**. The three states
of each argument are distinct:

- not supplied:

  The stored key is left unchanged.

- `NULL`:

  The stored key is deleted.

- a value:

  The key is set, after validation and coercion.

A value is either a `Date` scalar or an ISO 8601 string
(`"YYYY-MM-DD"`), which is stored as a `Date`. A looser string such as
`"2026/02/10"` or `"2026-2-1"` is rejected, and the error names this
function's own argument.

`field_start` must not be after `field_end`. The comparison uses the
*effective* value of each key: the new value when the call supplies one,
no value when the call supplies `NULL`, and the stored value when the
call does not mention the key. So one call can repair a reversed stored
pair by deleting one date and setting the other, and deleting both
always succeeds.

This function never touches `field_period` — the prose period has its
own setter,
[`set_field_period()`](https://jdenn0514.github.io/surveycore/reference/set_field_period.md).

## See also

Other metadata:
[`classify_question_type()`](https://jdenn0514.github.io/surveycore/reference/classify_question_type.md),
[`extract_data_name()`](https://jdenn0514.github.io/surveycore/reference/extract_data_name.md),
[`extract_dataset_metadata()`](https://jdenn0514.github.io/surveycore/reference/extract_dataset_metadata.md),
[`extract_field_dates()`](https://jdenn0514.github.io/surveycore/reference/extract_field_dates.md),
[`extract_field_period()`](https://jdenn0514.github.io/surveycore/reference/extract_field_period.md),
[`extract_higher_is()`](https://jdenn0514.github.io/surveycore/reference/extract_higher_is.md),
[`extract_metadata()`](https://jdenn0514.github.io/surveycore/reference/extract_metadata.md),
[`extract_missing_codes()`](https://jdenn0514.github.io/surveycore/reference/extract_missing_codes.md),
[`extract_question_preface()`](https://jdenn0514.github.io/surveycore/reference/extract_question_preface.md),
[`extract_reverse_coded()`](https://jdenn0514.github.io/surveycore/reference/extract_reverse_coded.md),
[`extract_sata()`](https://jdenn0514.github.io/surveycore/reference/extract_sata.md),
[`extract_survey_name()`](https://jdenn0514.github.io/surveycore/reference/extract_survey_name.md),
[`extract_universe()`](https://jdenn0514.github.io/surveycore/reference/extract_universe.md),
[`extract_val_labels()`](https://jdenn0514.github.io/surveycore/reference/extract_val_labels.md),
[`extract_var_extra()`](https://jdenn0514.github.io/surveycore/reference/extract_var_extra.md),
[`extract_var_label()`](https://jdenn0514.github.io/surveycore/reference/extract_var_label.md),
[`extract_var_note()`](https://jdenn0514.github.io/surveycore/reference/extract_var_note.md),
[`extract_vendor()`](https://jdenn0514.github.io/surveycore/reference/extract_vendor.md),
[`infer_question_prefaces()`](https://jdenn0514.github.io/surveycore/reference/infer_question_prefaces.md),
[`set_data_name()`](https://jdenn0514.github.io/surveycore/reference/set_data_name.md),
[`set_dataset_metadata()`](https://jdenn0514.github.io/surveycore/reference/set_dataset_metadata.md),
[`set_field_period()`](https://jdenn0514.github.io/surveycore/reference/set_field_period.md),
[`set_higher_is()`](https://jdenn0514.github.io/surveycore/reference/set_higher_is.md),
[`set_missing_codes()`](https://jdenn0514.github.io/surveycore/reference/set_missing_codes.md),
[`set_question_preface()`](https://jdenn0514.github.io/surveycore/reference/set_question_preface.md),
[`set_reverse_coded()`](https://jdenn0514.github.io/surveycore/reference/set_reverse_coded.md),
[`set_sata()`](https://jdenn0514.github.io/surveycore/reference/set_sata.md),
[`set_survey_name()`](https://jdenn0514.github.io/surveycore/reference/set_survey_name.md),
[`set_universe()`](https://jdenn0514.github.io/surveycore/reference/set_universe.md),
[`set_val_labels()`](https://jdenn0514.github.io/surveycore/reference/set_val_labels.md),
[`set_var_extra()`](https://jdenn0514.github.io/surveycore/reference/set_var_extra.md),
[`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md),
[`set_var_note()`](https://jdenn0514.github.io/surveycore/reference/set_var_note.md),
[`set_vendor()`](https://jdenn0514.github.io/surveycore/reference/set_vendor.md),
[`survey_metadata()`](https://jdenn0514.github.io/surveycore/reference/survey_metadata.md),
[`survey_weighting_history()`](https://jdenn0514.github.io/surveycore/reference/survey_weighting_history.md)

## Examples

``` r
df <- data.frame(id = 1:5, y = c(2, 4, 3, 5, 1), w = rep(1, 5))
df <- set_field_dates(df, "2026-02-10", "2026-03-04")
extract_field_dates(df)
#> $field_start
#> [1] "2026-02-10"
#> 
#> $field_end
#> [1] "2026-03-04"
#> 

# Supplying one argument leaves the other key unchanged.
df <- set_field_dates(df, field_end = "2026-03-10")
extract_field_dates(df)
#> $field_start
#> [1] "2026-02-10"
#> 
#> $field_end
#> [1] "2026-03-10"
#> 

# NULL deletes a key.
df <- set_field_dates(df, field_start = NULL)
extract_field_dates(df)
#> $field_start
#> [1] NA
#> 
#> $field_end
#> [1] "2026-03-10"
#> 

d <- as_survey(df, weights = w)
d <- set_field_dates(d, field_start = as.Date("2026-02-11"))
extract_field_dates(d)
#> $field_start
#> [1] "2026-02-11"
#> 
#> $field_end
#> [1] "2026-03-10"
#> 
```
