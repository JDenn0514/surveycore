# Convert a surveycore Design Object to a survey Package Design

Converts a `survey_taylor`, `survey_replicate`, `survey_twophase`, or
`survey_nonprob` object to the corresponding `survey` package object:
`svydesign`, `svrepdesign`, or `twophase`. Useful for accessing `survey`
package estimation functions or for round-trip testing.

## Usage

``` r
as_svydesign(x)
```

## Arguments

- x:

  A `survey_taylor`, `survey_replicate`, `survey_twophase`, or
  `survey_nonprob` object.

## Value

A [`survey::svydesign`](https://rdrr.io/pkg/survey/man/svydesign.html),
[`survey::svrepdesign`](https://rdrr.io/pkg/survey/man/svrepdesign.html),
or [`survey::twophase`](https://rdrr.io/pkg/survey/man/twophase.html)
object. The returned class follows the input class, and for a
`survey_nonprob` design it follows the design's shape: a design that
names replicate weights returns a `svrepdesign`, and a design that names
none returns a `svydesign`. A filtered input returns an object
restricted to the active domain; the `A filtered design's domain`
section below states what that means on each route. Value labels are not
carried into the returned object — the `survey` package has no metadata
system. To read the data back with `haven`-style classes rebuilt, use
`survey_data(x, haven_class = TRUE)` on the surveycore design instead.

## Details

Metadata (variable labels, value labels) is NOT carried over — the
`survey` package has no metadata system.

## A non-probability design

A `survey_nonprob` design converts on the shape of its weights. A design
that names replicate weights becomes a `svrepdesign` and keeps every
replicate column, so the converted object computes the replicate
variance surveycore computes. A design that names none becomes a
`svydesign` with `ids = ~1`, and the call warns: the standard errors
then use a simple random sample approximation that charges nothing for
calibration uncertainty, and the returned object records nothing about
it. See
[`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md)
for the two variance modes.

The conversion drops the design's calibration provenance and its
reference sample, and the round trip does not return a non-probability
design.
[`from_svydesign()`](https://jdenn0514.github.io/surveycore/reference/from_svydesign.md)
on a converted design returns a `survey_taylor` or a `survey_replicate`
object, because a `survey` object records nothing that marks a sample as
non-probability. The rebuilt design reports design-based standard errors
and no longer warns, on data that has not changed. Keep the original
object when you need any of that.

## Degrees of freedom on a converted design

surveycore reports `Inf` degrees of freedom for a `survey_nonprob`
design, and the `survey` package computes a finite number from the
converted object. A 40-row design with no replicate weights converts to
39, and the same design with 8 replicate weight columns converts to 7.
Both counts carry a qualifier. Without replicate weights the `survey`
package counts the rows whose weight is not zero and subtracts 1, so the
same design with one zero-weight row converts to 38. With replicate
weights it takes the numerical rank of the matrix of replicate weights
and subtracts 1, so the figure is `R - 1` at full column rank and lower
otherwise.

The difference reaches a result only when the caller asks for it. A
default [`confint()`](https://rdrr.io/r/stats/confint.html) call on a
`svystat` or a `svrepstat` uses `df = Inf`, so the default interval from
[`survey::svymean()`](https://rdrr.io/pkg/survey/man/surveysummary.html)
matches surveycore's. The gap appears when the caller passes
`degf(design)`, or calls a `survey` function that reads `degf()` itself,
such as `svyglm()` or `svyttest()`. See
[`vignette("surveycore-vs-survey")`](https://jdenn0514.github.io/surveycore/articles/surveycore-vs-survey.md)
for the two counting rules in the source.

## A filtered design's domain

The converted object represents the active domain and not the full
stored sample.
[`survey::svymean()`](https://rdrr.io/pkg/survey/man/surveysummary.html)
on it answers the domain estimate.

A domain arrives from [`filter()`](https://rdrr.io/r/stats/filter.html)
in surveytidy. That verb keeps every row and marks domain membership in
a logical column named by `SURVEYCORE_DOMAIN_COL`, which holds
`"..surveycore_domain.."`. The restriction applies whenever that column
is present. A design that was never filtered carries no such column and
converts with no restriction.

The marker column stays in the converted object's data. It is an
internal marker and not survey data. On the routes that remove rows,
every value left in it is `TRUE`. On the two-phase route, which removes
no row, the column arrives unchanged and still marks the zero-weighted
rows `FALSE`. A row whose marker is `NA` counts as outside the domain.

A filter that matches no row still converts, and the conversion raises
no surveycore condition on any route. What `survey` reports afterwards
depends on the route:

- Taylor, and a non-probability design that names no replicate weights:
  an estimate of 0 with a standard error of 0.

- Replicate, and a non-probability design that names replicate weights:
  an error from `survey` at estimation time.

- Two-phase: `NaN`.

The two-phase route applies the domain by weighting the excluded rows
out rather than by removing them. Each excluded row takes an infinite
probability, so the converted object's row count does not change while
its estimates answer for the domain.

A two-phase design with `method = "full"` converts to a `twophase2`
object.
[`survey::twophase()`](https://rdrr.io/pkg/survey/man/twophase.html)
refuses a `weights` argument for that method, so the phase-1 weights are
passed as inclusion probabilities, `probs = ~I(1 / w)`. A phase 1 with
no weights, strata or `fpc` passes none, and `survey` then treats it as
an iid sample, as surveycore does.

A round trip through
[`from_svydesign()`](https://jdenn0514.github.io/surveycore/reference/from_svydesign.md)
recovers the restricted rows and not the original sample. On the four
routes that remove rows, the rebuilt design's row count is its new
total. The original row count is unrecoverable from the object, because
a `survey` object records a subset and not a marker. The all-`TRUE`
marker column travels back, so the rebuilt design prints
`Domain: n of n rows`, which looks identical to a design that was never
filtered. Printing a filtered design shows the domain count and the
stored count; after a round trip the two counts are the same number
twice. Keep the original design when you need the original row count.
The two-phase route is the exception: it removes no row, so its round
trip recovers the marker at both levels and the rebuilt design prints
two different counts.

[`as_tbl_svy()`](https://jdenn0514.github.io/surveycore/reference/as_tbl_svy.md)
hands a `tbl_svy` that is already restricted to `srvyr`. `srvyr`'s own
[`filter()`](https://rdrr.io/r/stats/filter.html) removes rows where
surveycore's [`filter()`](https://rdrr.io/r/stats/filter.html) marks a
domain. The two verbs share a name and differ in semantics, so a caller
who chains surveycore's
[`filter()`](https://rdrr.io/r/stats/filter.html) into
[`srvyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html)
filters an object that is already restricted.

## See also

[`from_svydesign()`](https://jdenn0514.github.io/surveycore/reference/from_svydesign.md)
to convert back from a `survey` design

Other conversion:
[`as_tbl_svy()`](https://jdenn0514.github.io/surveycore/reference/as_tbl_svy.md),
[`from_svydesign()`](https://jdenn0514.github.io/surveycore/reference/from_svydesign.md),
[`from_tbl_svy()`](https://jdenn0514.github.io/surveycore/reference/from_tbl_svy.md)

## Examples

``` r
d <- as_survey(
  nhanes_2017,
  ids = sdmvpsu,
  weights = wtint2yr,
  strata = sdmvstra,
  nest = TRUE
)
if (requireNamespace("survey", quietly = TRUE)) {
  sv <- as_svydesign(d)
  survey::svymean(~ridageyr, sv, na.rm = TRUE)
}
#>            mean     SE
#> ridageyr 38.424 0.5244
```
