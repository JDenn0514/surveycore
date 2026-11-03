# Access the Data Component of a Survey Design Object

Returns the underlying data frame stored in a survey design object. This
is a thin accessor for `x@data` that provides a stable public name
independent of the S7 property structure.

## Usage

``` r
survey_data(x, haven_class = FALSE)
```

## Arguments

- x:

  A `survey_taylor`, `survey_replicate`, `survey_twophase`, or
  `survey_nonprob` object.

- haven_class:

  Rebuild the `haven_labelled` class on every column that has value
  labels. The design's metadata is read first, and the column's `labels`
  attribute is the fallback, so labels set by
  [`set_val_labels()`](https://jdenn0514.github.io/surveycore/reference/set_val_labels.md)
  on the design reach the returned column. The variable label follows
  the same order, so
  [`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md)
  on the design reaches the returned column's `label` attribute. Value
  labels are the whole class test, not a record of which columns arrived
  as `haven_labelled`: a column that never carried the class is promoted
  too, so a column labelled by `sjlabelled` comes back with the class on
  it. A column that carries a class of its own is left alone: a `factor`
  keeps its levels and a `Date` keeps its calendar, whatever attributes
  they hold. `FALSE`, the default, returns base types, which is what
  every arithmetic and modelling operation needs. `TRUE` returns columns
  that `haven` and `labelled` recognise, so that
  [`haven::as_factor()`](https://forcats.tidyverse.org/reference/as_factor.html)
  and
  [`labelled::to_factor()`](https://larmarange.github.io/labelled/reference/to_factor.html)
  give the label strings instead of the codes, and so that
  [`haven::write_sav()`](https://haven.tidyverse.org/reference/read_spss.html)
  writes the labels the design holds. `haven` does not need to be
  installed for either value. Two known limits:
  [`haven::write_sav()`](https://haven.tidyverse.org/reference/read_spss.html)
  raises on a column holding a tagged `NA` — that is a `.sav` format
  limit inside `haven`, and a column built by `haven` itself fails the
  same way. And `set_val_labels(x, v = NULL)` clears the metadata entry
  without touching the column, so the fallback rebuilds the class from
  the column's own attribute.

## Value

A `data.frame` with all variables, including design variables. It is a
tibble when the design stores a tibble.

With `haven_class = FALSE`, the default, no column carries the
`haven_labelled` or `haven_labelled_spss` class. A survey design object
stores base types. Every attribute the import set — the `label` string,
the `labels` value-label vector, and the SPSS `na_values` and `na_range`
vectors — stays on the column, and the value labels are also available
through
[`extract_val_labels()`](https://jdenn0514.github.io/surveycore/reference/extract_val_labels.md).
In a printed tibble a previously labelled column shows the type token
for its own type — `<dbl>`, `<int>` or `<chr>` — in place of the
labelled token.

With `haven_class = TRUE`, every column that has value labels and no
class of its own is returned with its `haven_labelled` class rebuilt,
and a column that also carries `na_values` or `na_range` is returned as
`haven_labelled_spss`. A `factor`, a `Date`, and any other classed
column keep the class they have. The `labels` and `label` attributes on
the returned column hold what the design's metadata holds, which is what
[`extract_val_labels()`](https://jdenn0514.github.io/surveycore/reference/extract_val_labels.md)
and
[`extract_var_label()`](https://jdenn0514.github.io/surveycore/reference/extract_var_label.md)
report. Values are unchanged, and the printed type token reads as the
labelled token again — `<dbl+lbl>` for a double-backed column when the
`haven` namespace is loaded, since `haven` supplies the method that
renders it.

## Details

[`nrow()`](https://rdrr.io/r/base/nrow.html) and
[`dim()`](https://rdrr.io/r/base/dim.html) report the stored row count,
not the in-domain count. A domain filter keeps every row of the design
and marks membership in a flag column, so the two counts differ after a
filter. Printing a filtered design shows both, on the
`Domain: n of N rows` line.

To get the in-domain count, call
[`get_effective_n()`](https://jdenn0514.github.io/surveycore/reference/get_effective_n.md)
and read its `n` column. That function honours the domain flag, takes a
`group` argument, and accepts a `survey_collection`.

[`ncol()`](https://rdrr.io/r/base/nrow.html) counts the full stored
width. The count includes the weight column, the cluster and stratum
ids, `fpc`, the domain flag when present, and every replicate-weight
column. It is not a count of analysis variables, and it is not
comparable across design classes.

[`nrow()`](https://rdrr.io/r/base/nrow.html) is the unweighted count of
sample rows. It is not a population estimate.

## Examples

``` r
d <- as_survey(
  nhanes_2017,
  ids = sdmvpsu,
  weights = wtint2yr,
  strata = sdmvstra,
  nest = TRUE
)
head(survey_data(d))
#>    seqn sdmvpsu sdmvstra  wtmec2yr  wtint2yr ridstatr riagendr ridageyr
#> 1 93703       2      145  8539.731  9246.492        2        2        2
#> 2 93704       1      143 42566.615 37338.768        2        1        2
#> 3 93705       2      145  8338.420  8614.571        2        2       66
#> 4 93706       2      134  8723.440  8548.633        2        1       18
#> 5 93707       1      138  7064.610  6769.345        2        1       13
#> 6 93708       2      138 14372.489 13329.451        2        2       66
#>   ridreth3 indfmpir dmdeduc2 bpxsy1 bpxdi1 bpxpls
#> 1        6     5.00       NA     NA     NA     NA
#> 2        3     5.00       NA     NA     NA     NA
#> 3        4     0.82        2     NA     NA     52
#> 4        6       NA       NA    112     74     82
#> 5        7     1.88       NA    128     38    100
#> 6        6     1.63        1     NA     NA     68

# Read the data back with the labelled class rebuilt. gss_2024 carries
# value labels, so the class comes back on the columns that had one.
g <- as_survey(gss_2024, ids = vpsu, weights = wtssps, strata = vstrat)
#> Warning: ! Some PSUs appear in more than one stratum: "1" and "2". If PSUs are nested
#>   within strata, set `nest = TRUE`.
class(survey_data(g)$happy)
#> [1] "numeric"
class(survey_data(g, haven_class = TRUE)$happy)
#> [1] "haven_labelled" "vctrs_vctr"     "double"        

# Value labels set on the design reach the rebuilt column, so an export
# carries the labels the analyst set rather than the labels the file had.
g <- set_val_labels(g, happy = c(Happy = 1, `So-so` = 2, Unhappy = 3))
#> Warning: ! Some PSUs appear in more than one stratum: "1" and "2". If PSUs are nested
#>   within strata, set `nest = TRUE`.
attr(survey_data(g, haven_class = TRUE)$happy, "labels")
#>   Happy   So-so Unhappy 
#>       1       2       3 
```
