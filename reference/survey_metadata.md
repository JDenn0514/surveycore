# Survey Metadata Container

Stores variable labels, value labels, question prefaces, notes, and
transformation history for variables in a survey design object.
Automatically populated from haven-style attributes when
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
or related constructors are called.

## Usage

``` r
survey_metadata(
  variable_labels = list(),
  value_labels = list(),
  question_prefaces = list(),
  notes = list(),
  var_extra = list(),
  universe = list(),
  missing_codes = list(),
  sata = list(),
  higher_is = list(),
  reverse_coded = list(),
  transformations = list(),
  weighting_history = list(),
  dataset_metadata = list()
)
```

## Arguments

- variable_labels:

  A named list mapping variable names to character labels (e.g.,
  `list(age = "Age in years")`).

- value_labels:

  A named list mapping variable names to named vectors of value labels
  (e.g., `list(sex = c(Male = 1L, Female = 2L))`).

- question_prefaces:

  A named list mapping variable names to shared question battery preface
  text.

- notes:

  A named list mapping variable names to analyst notes.

- var_extra:

  A named list mapping variable names to a pass-through extension
  payload — itself a named list, or `NULL`. surveycore never inspects,
  type-checks, or acts on the payload's values; it stores and returns
  them as-is. Use
  [`set_var_extra()`](https://jdenn0514.github.io/surveycore/reference/set_var_extra.md)
  and
  [`extract_var_extra()`](https://jdenn0514.github.io/surveycore/reference/extract_var_extra.md)
  to access this property. Default
  [`list()`](https://rdrr.io/r/base/list.html).

- universe:

  A named list mapping variable names to universe descriptions (e.g.,
  `list(age = "Adults 18+")`). Describes the population to which a
  variable applies.

- missing_codes:

  A named list mapping variable names to atomic vectors of missing-value
  codes (e.g., `list(age = c(Refused = 99L, DK = 98L))`).

- sata:

  A named list mapping variable names to `TRUE` for variables that are
  select-all-that-apply (SATA). Only variables explicitly marked as SATA
  appear in this list — absence means the variable is not SATA.

- higher_is:

  A named list mapping variable names to `"better"` or `"worse"`,
  indicating the direction of improvement for that variable. Absent keys
  mean the direction is unset. Use
  [`set_higher_is()`](https://jdenn0514.github.io/surveycore/reference/set_higher_is.md)
  and
  [`extract_higher_is()`](https://jdenn0514.github.io/surveycore/reference/extract_higher_is.md)
  to access this property.

- reverse_coded:

  A named list mapping variable names to `TRUE` for variables that are
  reverse-coded. Absent keys mean the variable is not reverse-coded. Use
  [`set_reverse_coded()`](https://jdenn0514.github.io/surveycore/reference/set_reverse_coded.md)
  and
  [`extract_reverse_coded()`](https://jdenn0514.github.io/surveycore/reference/extract_reverse_coded.md)
  to access this property.

- transformations:

  A named list tracking variable transformation history (populated
  automatically during operations).

- weighting_history:

  A list recording weighting operations applied to the survey object
  (e.g., raking, trimming). Each entry is written by a surveywts
  function and contains the operation name, parameters, effective sample
  size before/after, and design effect. Always
  [`list()`](https://rdrr.io/r/base/list.html) until a surveywts
  weighting function is applied. Reserved for Phase 2.5.

- dataset_metadata:

  A named list of whole-dataset facts. The key vocabulary is **closed**
  — exactly six keys are valid, each with a declared type:

  - `survey_name` — `character(1)`, the full formal survey name.

  - `data_name` — `character(1)`, the display label for this dataset.

  - `vendor` — `character(1)`, the fielding vendor.

  - `field_start` — `Date` of length 1, the first day in the field.

  - `field_end` — `Date` of length 1, the last day in the field.

  - `field_period` — `character(1)`, the prose field period.

  No value may be `NA` and no element may be `NULL`. Any other key is
  rejected. `survey_name` and `data_name` are independent: no function
  derives one from the other. Use
  [`set_dataset_metadata()`](https://jdenn0514.github.io/surveycore/reference/set_dataset_metadata.md)
  to write keys and
  [`extract_dataset_metadata()`](https://jdenn0514.github.io/surveycore/reference/extract_dataset_metadata.md)
  to read them; the default is
  [`list()`](https://rdrr.io/r/base/list.html). Each key also has a
  convenience pair:
  [`set_survey_name()`](https://jdenn0514.github.io/surveycore/reference/set_survey_name.md),
  [`set_data_name()`](https://jdenn0514.github.io/surveycore/reference/set_data_name.md),
  [`set_vendor()`](https://jdenn0514.github.io/surveycore/reference/set_vendor.md),
  [`set_field_dates()`](https://jdenn0514.github.io/surveycore/reference/set_field_dates.md),
  [`set_field_period()`](https://jdenn0514.github.io/surveycore/reference/set_field_period.md),
  and the matching
  [`extract_survey_name()`](https://jdenn0514.github.io/surveycore/reference/extract_survey_name.md),
  [`extract_data_name()`](https://jdenn0514.github.io/surveycore/reference/extract_data_name.md),
  [`extract_vendor()`](https://jdenn0514.github.io/surveycore/reference/extract_vendor.md),
  [`extract_field_dates()`](https://jdenn0514.github.io/surveycore/reference/extract_field_dates.md),
  [`extract_field_period()`](https://jdenn0514.github.io/surveycore/reference/extract_field_period.md).

## Value

A `survey_metadata` object.

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
[`survey_weighting_history()`](https://jdenn0514.github.io/surveycore/reference/survey_weighting_history.md)

## Examples

``` r
# Empty metadata (default)
m <- survey_metadata()
m@variable_labels
#> list()

# Pre-populated metadata
m <- survey_metadata(
  variable_labels = list(age = "Respondent age", income = "Annual income"),
  value_labels = list(sex = c(Male = 1L, Female = 2L))
)
m@variable_labels$age
#> [1] "Respondent age"
m@value_labels$sex
#>   Male Female 
#>      1      2 

# Dataset-level metadata (closed six-key vocabulary)
m <- survey_metadata(dataset_metadata = list(vendor = "Ipsos"))
m@dataset_metadata$vendor
#> [1] "Ipsos"
```
