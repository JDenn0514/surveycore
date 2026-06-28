# Extract standard errors from a model or result object

A generic function that extracts standard errors. For `survey_result`
objects (produced by
[`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md),
[`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md),
and other `get_*()` functions), returns a named numeric vector matching
`names(coef(object))`.

## Usage

``` r
SE(object, ...)
```

## Arguments

- object:

  A model or result object.

- ...:

  Additional arguments passed to methods.

## Value

A named numeric vector of standard errors. The exact structure depends
on the method.

## Note

When both `surveycore` and `survey` are loaded, `surveycore::SE` masks
[`survey::SE`](https://rdrr.io/pkg/survey/man/SE.html). The
[`SE.default()`](https://jdenn0514.github.io/surveycore/reference/SE.default.md)
method handles most `survey` package objects (`svystat`, `svyby`) via
`sqrt(diag(vcov(object, ...)))`. Exception: `SE.default` is NOT
equivalent to
[`survey::SE.svyby`](https://rdrr.io/pkg/survey/man/svyby.html) when
`vartype = "cvpct"` was requested — in that case, qualify the call with
[`survey::SE()`](https://rdrr.io/pkg/survey/man/SE.html).

## See also

Other analysis:
[`clean()`](https://jdenn0514.github.io/surveycore/reference/clean.md),
[`get_anova()`](https://jdenn0514.github.io/surveycore/reference/get_anova.md),
[`get_corr()`](https://jdenn0514.github.io/surveycore/reference/get_corr.md),
[`get_covariance()`](https://jdenn0514.github.io/surveycore/reference/get_covariance.md),
[`get_diffs()`](https://jdenn0514.github.io/surveycore/reference/get_diffs.md),
[`get_effective_n()`](https://jdenn0514.github.io/surveycore/reference/get_effective_n.md),
[`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md),
[`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md),
[`get_pairwise()`](https://jdenn0514.github.io/surveycore/reference/get_pairwise.md),
[`get_quantiles()`](https://jdenn0514.github.io/surveycore/reference/get_quantiles.md),
[`get_ratios()`](https://jdenn0514.github.io/surveycore/reference/get_ratios.md),
[`get_t_test()`](https://jdenn0514.github.io/surveycore/reference/get_t_test.md),
[`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md),
[`get_variance()`](https://jdenn0514.github.io/surveycore/reference/get_variance.md),
[`meta()`](https://jdenn0514.github.io/surveycore/reference/meta.md)
