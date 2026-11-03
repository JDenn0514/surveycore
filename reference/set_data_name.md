# Set the Dataset Display Name

Sets the `data_name` dataset-level metadata key — the display label for
this particular dataset — on a survey design object or a data frame.

## Usage

``` r
set_data_name(x, name)
```

## Arguments

- x:

  A survey design object or `data.frame`.

- name:

  `character(1)`, non-`NA`, or `NULL` to delete the key. Omitting it is
  an error, not a deletion.

## Value

The modified object, invisibly.

## Details

A convenience wrapper for `set_dataset_metadata(x, data_name = name)`.

`data_name` is usually a short name plus the field period, for example
`"AAA Ipsos (February-March 2026)"`. It is independent of `survey_name`:
this function writes `data_name` and nothing else, and it never reads,
fills, or checks `survey_name`. Use
[`set_survey_name()`](https://jdenn0514.github.io/surveycore/reference/set_survey_name.md)
for the formal name.

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
[`set_dataset_metadata()`](https://jdenn0514.github.io/surveycore/reference/set_dataset_metadata.md),
[`set_field_dates()`](https://jdenn0514.github.io/surveycore/reference/set_field_dates.md),
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
df <- set_data_name(df, "Example (February-March 2026)")
extract_data_name(df)
#> [1] "Example (February-March 2026)"

# The formal survey name is a separate key and stays unset.
extract_survey_name(df)
#> [1] NA

d <- as_survey(df, weights = w)
d <- set_data_name(d, "Example (March 2026)")
extract_data_name(d)
#> [1] "Example (March 2026)"
```
