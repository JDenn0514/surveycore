# Infer Question Prefaces from Variable Labels

Scans variable labels in a survey design object or labelled data frame
for groups of variables sharing a common preface (via separator or
longest common prefix). Detected prefaces are written to
`question_preface` in the metadata and the shared text is trimmed from
each variable label, leaving only the unique suffix.

## Usage

``` r
infer_question_prefaces(
  x,
  sep = c(" - ", "- ", " – ", ": ", " | "),
  min_vars = 2L,
  lcp_min = 20L,
  overwrite = FALSE,
  verbose = TRUE
)
```

## Arguments

- x:

  A survey design object (`survey_taylor`, `survey_replicate`, etc.)
  **or** a data frame with haven-style `"label"` attributes.

- sep:

  Character vector of literal separator strings to try, in priority
  order. Default: `c(" - ", "- ", " \u2013 ", ": ", " | ")`.

- min_vars:

  Minimum number of variables that must share a candidate preface to
  trigger extraction. Default `2L`.

- lcp_min:

  Minimum character length (after trimming to a word boundary) for an
  LCP-derived preface to be accepted. Default `20L`.

- overwrite:

  If `FALSE` (default), variables that already have a `question_preface`
  are skipped and a warning is emitted. Set `TRUE` to replace existing
  prefaces without warning.

- verbose:

  If `TRUE` (default), emits a cli summary for each detected group.

## Value

The modified `x`, invisibly.

## Details

**Detection algorithm (two passes):**

1.  **Separator pass** — for each separator in `sep` (tried in order):

    - Variables whose label contains the separator are grouped by their
      candidate preface (text before the *first* occurrence of the
      separator, trimmed).

    - Any group with \\\geq\\ `min_vars` members is recorded; those
      variables are excluded from all subsequent passes.

2.  **LCP pass** — for remaining labelled variables (\\\geq\\ 2):

    - The character-level longest common prefix (LCP) of all remaining
      labels is computed and trimmed to the last word boundary.

    - If the trimmed LCP is \\\geq\\ `lcp_min` characters, the group is
      recorded.

**Apply step:**

- Variables with an existing `question_preface` are skipped when
  `overwrite = FALSE` (default); a warning is emitted listing the count
  of skipped variables.

- Variables whose unique suffix would be empty after trimming are always
  skipped with a per-variable warning.

**Data frame integration:** When called on a data frame, the detected
preface is written to `attr(col, "question_preface")`. Passing the
result to
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
automatically picks up both the trimmed label and the preface via the
internal haven metadata extraction step.

## See also

Other metadata:
[`classify_question_type()`](https://jdenn0514.github.io/surveycore/reference/classify_question_type.md),
[`extract_metadata()`](https://jdenn0514.github.io/surveycore/reference/extract_metadata.md),
[`extract_missing_codes()`](https://jdenn0514.github.io/surveycore/reference/extract_missing_codes.md),
[`extract_question_preface()`](https://jdenn0514.github.io/surveycore/reference/extract_question_preface.md),
[`extract_sata()`](https://jdenn0514.github.io/surveycore/reference/extract_sata.md),
[`extract_universe()`](https://jdenn0514.github.io/surveycore/reference/extract_universe.md),
[`extract_val_labels()`](https://jdenn0514.github.io/surveycore/reference/extract_val_labels.md),
[`extract_var_label()`](https://jdenn0514.github.io/surveycore/reference/extract_var_label.md),
[`extract_var_note()`](https://jdenn0514.github.io/surveycore/reference/extract_var_note.md),
[`set_missing_codes()`](https://jdenn0514.github.io/surveycore/reference/set_missing_codes.md),
[`set_question_preface()`](https://jdenn0514.github.io/surveycore/reference/set_question_preface.md),
[`set_sata()`](https://jdenn0514.github.io/surveycore/reference/set_sata.md),
[`set_universe()`](https://jdenn0514.github.io/surveycore/reference/set_universe.md),
[`set_val_labels()`](https://jdenn0514.github.io/surveycore/reference/set_val_labels.md),
[`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md),
[`set_var_note()`](https://jdenn0514.github.io/surveycore/reference/set_var_note.md),
[`survey_metadata()`](https://jdenn0514.github.io/surveycore/reference/survey_metadata.md),
[`survey_weighting_history()`](https://jdenn0514.github.io/surveycore/reference/survey_weighting_history.md)

## Examples

``` r
# Data frame with haven-style labels (Qualtrics / SPSS export pattern)
df <- data.frame(
  discrim_a = 1:5,
  discrim_b = 2:6,
  discrim_c = 3:7
)
attr(df$discrim_a, "label") <-
  "Please rate discrimination - Evangelical Christians"
attr(df$discrim_b, "label") <-
  "Please rate discrimination - Muslims"
attr(df$discrim_c, "label") <-
  "Please rate discrimination - Jews"

df <- infer_question_prefaces(df, verbose = FALSE)
attr(df$discrim_a, "label")            # "Evangelical Christians"
#> [1] "Evangelical Christians"
attr(df$discrim_a, "question_preface") # "Please rate discrimination"
#> [1] "Please rate discrimination"
```
