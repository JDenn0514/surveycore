# Set a Question Preface

Sets the question preface string for a single variable in a survey
design object. Question prefaces are the shared introductory text for a
battery of related questions.

## Usage

``` r
set_question_preface(x, var, preface)
```

## Arguments

- x:

  A survey design object.

- var:

  \<[`data-masked`](https://rlang.r-lib.org/reference/args_data_masking.html)\>
  Variable name (bare, unquoted).

- preface:

  A character string. The question preface text.

## Value

The modified survey object, invisibly.

## See also

[`set_question_prefaces()`](https://jdenn0514.github.io/surveycore/reference/set_question_prefaces.md)
for setting prefaces for multiple variables,
[`extract_question_preface()`](https://jdenn0514.github.io/surveycore/reference/extract_question_preface.md)
to retrieve a preface

Other metadata:
[`extract_question_preface()`](https://jdenn0514.github.io/surveycore/reference/extract_question_preface.md),
[`extract_val_labels()`](https://jdenn0514.github.io/surveycore/reference/extract_val_labels.md),
[`extract_var_label()`](https://jdenn0514.github.io/surveycore/reference/extract_var_label.md),
[`extract_var_note()`](https://jdenn0514.github.io/surveycore/reference/extract_var_note.md),
[`set_question_prefaces()`](https://jdenn0514.github.io/surveycore/reference/set_question_prefaces.md),
[`set_val_labels()`](https://jdenn0514.github.io/surveycore/reference/set_val_labels.md),
[`set_value_labels()`](https://jdenn0514.github.io/surveycore/reference/set_value_labels.md),
[`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md),
[`set_var_note()`](https://jdenn0514.github.io/surveycore/reference/set_var_note.md),
[`set_variable_labels()`](https://jdenn0514.github.io/surveycore/reference/set_variable_labels.md),
[`set_variable_notes()`](https://jdenn0514.github.io/surveycore/reference/set_variable_notes.md),
[`survey_metadata()`](https://jdenn0514.github.io/surveycore/reference/survey_metadata.md)
