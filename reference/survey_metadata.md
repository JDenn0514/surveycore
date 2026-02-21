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
  transformations = list(),
  weighting_history = list()
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

- transformations:

  A named list tracking variable transformation history (populated
  automatically during operations).

- weighting_history:

  A list recording weighting operations applied to the survey object
  (e.g., raking, trimming). Each entry is written by a surveyweights
  function and contains the operation name, parameters, effective sample
  size before/after, and design effect. Always
  [`list()`](https://rdrr.io/r/base/list.html) until a surveyweights
  weighting function is applied. Reserved for Phase 2.5.

## Value

A `survey_metadata` object.

## See also

Other metadata:
[`extract_question_preface()`](https://jdenn0514.github.io/surveycore/reference/extract_question_preface.md),
[`extract_val_labels()`](https://jdenn0514.github.io/surveycore/reference/extract_val_labels.md),
[`extract_var_label()`](https://jdenn0514.github.io/surveycore/reference/extract_var_label.md),
[`extract_var_note()`](https://jdenn0514.github.io/surveycore/reference/extract_var_note.md),
[`set_question_preface()`](https://jdenn0514.github.io/surveycore/reference/set_question_preface.md),
[`set_question_prefaces()`](https://jdenn0514.github.io/surveycore/reference/set_question_prefaces.md),
[`set_val_labels()`](https://jdenn0514.github.io/surveycore/reference/set_val_labels.md),
[`set_value_labels()`](https://jdenn0514.github.io/surveycore/reference/set_value_labels.md),
[`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md),
[`set_var_note()`](https://jdenn0514.github.io/surveycore/reference/set_var_note.md),
[`set_variable_labels()`](https://jdenn0514.github.io/surveycore/reference/set_variable_labels.md),
[`set_variable_notes()`](https://jdenn0514.github.io/surveycore/reference/set_variable_notes.md)
