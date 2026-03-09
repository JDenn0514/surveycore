# Get design variable column names

Returns a flat character vector of all design-variable column names
(ids, weights, strata, fpc) for any survey design class. `NULL` entries
are dropped; names are unique. Exported for use by extension packages
(e.g., `surveytidy`); not intended for end users.

## Usage

``` r
.get_design_vars_flat(design)
```

## Arguments

- design:

  A survey design object (`survey_base` subclass).

## Value

A character vector of column names.
