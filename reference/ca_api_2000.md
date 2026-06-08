# California Academic Performance Index 2000: Simple Random Sample

A simple random sample from the 2000 California Academic Performance
Index (API) study. 200 schools were randomly sampled. This is the same
underlying data as `apisrs` in the `survey` package, reformatted to
surveycore conventions.

## Usage

``` r
ca_api_2000
```

## Format

A data frame with 200 rows and 38 variables:

- pw:

  Sampling weight (inverse probability of selection).

- fpc:

  FPC (number of schools in the California API system).

- cds:

  County/district/school code (character, 14-digit).

- snum:

  School number (integer).

- dnum:

  District number (integer).

- name:

  Short school name (character).

- sname:

  Full school name (character).

- dname:

  District name (character).

- cname:

  County name (character).

- cnum:

  County number (integer).

- api00:

  API score 2000 (integer).

- api99:

  API score 1999 (integer).

- target:

  API growth target (integer).

- growth:

  API score change, `api00 - api99` (integer).

- pcttest:

  Percent of students tested (integer).

- sch_wide:

  Met school-wide growth target (integer, 0 = No, 1 = Yes).

- comp_imp:

  Met comparable improvement target (integer, 0 = No, 1 = Yes).

- both:

  Met both targets (integer, 0 = No, 1 = Yes).

- awards:

  Eligible for awards program (integer, 0 = No, 1 = Yes).

- stype:

  School type (integer): 1 = Elementary, 2 = High, 3 = Middle.

- yr_rnd:

  Year-round school (integer, 0 = No, 1 = Yes).

- meals:

  Percent of students receiving free meals (integer).

- ell:

  Number of English language learners (integer).

- mobility:

  Percent of students in first year at school (integer).

- enroll:

  Total number of students (integer).

- api_stu:

  Number of students included in API 2000 (integer).

- acs_k3:

  Average class size, grades K–3 (integer; `NA` for high and middle
  schools).

- acs_46:

  Average class size, grades 4–6 (integer; `NA` for high schools and
  some others).

- acs_core:

  Average class size, core academic courses (integer; `NA` for most
  elementary schools).

- not_hsg:

  Percent of parents who did not complete high school (integer).

- hsg:

  Percent of parents who are high school graduates (integer).

- some_col:

  Percent of parents with some college (integer).

- col_grad:

  Percent of parents who are college graduates (integer).

- grad_sch:

  Percent of parents with graduate school education (integer).

- avg_ed:

  Average parent education level (numeric).

- pct_resp:

  Percent of parents who responded to the survey (integer).

- full:

  Percent of teachers fully credentialed (integer).

- emer:

  Percent of teachers on emergency credentials (integer).

## Source

Lumley T (2004). *Analysis of complex survey samples.* Journal of
Statistical Software, 9(1):1–19. Data distributed with the `survey` R
package.

California Department of Education, Academic Performance Index 2000.

## Details

**Survey design:** Simple random sample. Use
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
with `weights = pw` and `fpc = fpc`:

    svy <- as_survey(
      ca_api_2000,
      weights = pw,
      fpc = fpc
    )

**Missing values:** Several columns have `NA` for schools where the
value is inapplicable: `acs_k3` (grades K–3) is `NA` for high schools
and middle schools, where those grade spans do not exist; `acs_46`
(grades 4–6) is `NA` for all high schools and some elementary and middle
schools; `acs_core` is `NA` for most elementary schools.

**Metadata:** All 38 columns carry `"label"` attributes (human-readable
variable descriptions). The six categorical columns (`stype`,
`sch_wide`, `comp_imp`, `both`, `awards`, `yr_rnd`) additionally carry
`"labels"` attributes mapping integer codes to category names,
compatible with surveycore's metadata system.

**Relationship to `apisrs`:** This dataset contains the same
observations as
[`survey::apisrs`](https://rdrr.io/pkg/survey/man/api.html), with three
differences: (1) the all-`NA` `flag` column is dropped; (2) factor
columns are stored as plain integers with `labels` attributes; (3)
column names are in snake_case.

## Examples

``` r
head(ca_api_2000[, c("pw", "fpc", "api00", "enroll")])
#>         pw  fpc api00 enroll
#> 1039 30.97 6194   462    477
#> 1124 30.97 6194   878    478
#> 2868 30.97 6194   734   1410
#> 1273 30.97 6194   772    342
#> 4926 30.97 6194   739    217
#> 2463 30.97 6194   835    258

# Create an SRS design
svy <- as_survey(ca_api_2000, weights = pw, fpc = fpc)
svy
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 200
#> 
#> # A tibble: 200 × 38
#>    cds       stype name  sname  snum dname  dnum cname  cnum pcttest api00 api99
#>    <chr>     <int> <chr> <chr> <dbl> <chr> <int> <chr> <int>   <int> <int> <int>
#>  1 15739081…     2 "McF… McFa…  1039 McFa…   432 Kern     14      98   462   448
#>  2 19642126…     1 "Sto… Stow…  1124 ABC …     1 Los …    18     100   878   831
#>  3 30664493…     2 "Bre… Brea…  2868 Brea…    79 Oran…    29      98   734   742
#>  4 19644516…     1 "Ala… Alam…  1273 Down…   187 Los …    18      99   772   657
#>  5 40688096…     1 "Sun… Sunn…  4926 San …   640 San …    39      99   739   719
#>  6 19734456…     1 "Los… Los …  2463 Haci…   284 Los …    18      93   835   822
#>  7 19647336…     3 "Nor… Nort…  2031 Los …   401 Los …    18      98   456   472
#>  8 19647336…     1 "Gla… Glas…  1736 Los …   401 Los …    18      99   506   474
#>  9 19648166…     1 "Max… Maxs…  2142 Moun…   470 Los …    18     100   543   458
#> 10 38684786…     1 "Tre… Trea…  4754 San …   632 San …    37      90   649   604
#> # ℹ 190 more rows
#> # ℹ 26 more variables: target <int>, growth <int>, sch_wide <int>,
#> #   comp_imp <int>, both <int>, awards <int>, meals <int>, ell <int>,
#> #   yr_rnd <int>, mobility <int>, acs_k3 <int>, acs_46 <int>, acs_core <int>,
#> #   pct_resp <int>, not_hsg <int>, hsg <int>, some_col <int>, col_grad <int>,
#> #   grad_sch <int>, avg_ed <dbl>, full <int>, emer <int>, enroll <int>,
#> #   api_stu <int>, pw <dbl>, fpc <dbl>

# Inspect variable label
attr(ca_api_2000$api00, "label")
#> [1] "API score 2000"

# Inspect value labels for school type
attr(ca_api_2000$stype, "labels")
#> Elementary       High     Middle 
#>          1          2          3 
```
