# Set Variable Extension Slot Payload(s)

Sets a per-variable extension-slot payload — a flat, pass-through named
list that surveycore stores and returns unchanged. surveycore never
reads, validates, or acts on the payload's *values*; it confirms only
that the top-level value is a list or `NULL`, and that a non-empty
list's top-level names are present, non-empty, and unique.

## Usage

``` r
set_var_extra(x, ..., variable = NULL, extra = NULL)
```

## Arguments

- x:

  A survey design object or a data frame.

- ...:

  Named arguments where the name is the variable and the value is the
  extension payload (a list, or `NULL` to clear it). Supports `!!!` list
  splicing.

- variable:

  A character vector of variable names. Use with `extra`.

- extra:

  A list of payloads, one element per entry of `variable`, in the same
  order. Each element must itself be a list or `NULL`.

## Value

The modified object, invisibly.

## Details

Supports Conventions 1, 2, and 3 — see
[`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md)
for details on the calling conventions. Unlike
[`set_missing_codes()`](https://jdenn0514.github.io/surveycore/reference/set_missing_codes.md),
there is no bare-payload shorthand for Convention 3 with a single
variable: a bare named list cannot be distinguished from a one-element
outer list, so the payload must be wrapped in an outer list
(`extra = list(list(role = "demographic"))`). Passing an un-wrapped
named list of length 1 raises
`surveycore_error_var_extra_ambiguous_wrap`.

## See also

[`extract_var_extra()`](https://jdenn0514.github.io/surveycore/reference/extract_var_extra.md)
to retrieve extension-slot payloads

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
[`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md),
[`set_var_note()`](https://jdenn0514.github.io/surveycore/reference/set_var_note.md),
[`set_vendor()`](https://jdenn0514.github.io/surveycore/reference/set_vendor.md),
[`survey_metadata()`](https://jdenn0514.github.io/surveycore/reference/survey_metadata.md),
[`survey_weighting_history()`](https://jdenn0514.github.io/surveycore/reference/survey_weighting_history.md)

## Examples

``` r
d <- as_survey(
  gss_2024,
  ids = vpsu,
  weights = wtssps,
  strata = vstrat,
  nest = TRUE
)
d <- set_var_extra(d, age = list(role = "demographic"))
extract_var_extra(d, age)
#> $age
#> $age$role
#> [1] "demographic"
#> 
#> 
```
