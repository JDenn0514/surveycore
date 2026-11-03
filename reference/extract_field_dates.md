# Extract the Field Dates

Returns the `field_start` and `field_end` dataset-level metadata keys
from a survey design object or a data frame.

## Usage

``` r
extract_field_dates(x)
```

## Arguments

- x:

  A survey design object or `data.frame`.

## Value

A named list of length 2, `field_start` then `field_end`, each a `Date`
of length 1. An unset key is `as.Date(NA)`.

## Details

Returns the two structured dates only. The prose field period has its
own extractor,
[`extract_field_period()`](https://jdenn0514.github.io/surveycore/reference/extract_field_period.md),
and this function never derives one from the other. An unset key is a
normal state, reported as `as.Date(NA)`; this function never warns. A
design object restored from a file written by surveycore 1.1.0 or
earlier reports both entries as `as.Date(NA)` rather than failing.

## See also

Other metadata:
[`classify_question_type()`](https://jdenn0514.github.io/surveycore/reference/classify_question_type.md),
[`extract_data_name()`](https://jdenn0514.github.io/surveycore/reference/extract_data_name.md),
[`extract_dataset_metadata()`](https://jdenn0514.github.io/surveycore/reference/extract_dataset_metadata.md),
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
extract_field_dates(df)
#> $field_start
#> [1] NA
#> 
#> $field_end
#> [1] NA
#> 

df <- set_field_dates(df, "2026-02-10", "2026-03-04")
extract_field_dates(df)
#> $field_start
#> [1] "2026-02-10"
#> 
#> $field_end
#> [1] "2026-03-04"
#> 
```
