# R Package Conventions — Worked Examples and Templates

Detail moved out of `.claude/rules/r-package-conventions.md` and
`.claude/rules/surveycore-conventions.md`. The rules live there; this file
shows how to apply them. Read this when writing roxygen docs, DESCRIPTION
fields, or package-level documentation.

---

## `@param` verbosity examples

**Terse** (one sentence) for simple, self-evident arguments:

```r
#' @param data A data.frame.
#' @param label A character string.
#' @param ... Additional arguments (currently unused).
```

**Fuller** for arguments with non-obvious behavior, constraints, or
interactions:

```r
#' @param weights <[`tidy-select`][tidyselect::language]> Column(s) for
#'   survey weights. If multiple columns, they are combined. Cannot contain
#'   `NA`. Default `NULL` (uniform weights).
```

## `@return` examples

```r
#' @return A survey design object.
#' @return A data.frame of results.
#' @return A character string, or `NULL` if not set.
#' @return The modified object, invisibly.
```

For survey objects:

```r
#' @return A `survey_taylor` object — a complete survey design specification
#'   ready for variance estimation via Taylor series linearization.
#'   See [survey_taylor] for structure.
```

## `@examples` — runnable, small

If an example is slow, use a smaller inline dataset instead of `\dontrun{}`:

```r
#' @examples
#' # Small inline example (preferred)
#' df <- data.frame(id = 1:10, y = rnorm(10))
#' result <- my_function(df)
```

## Internal function documentation

```r
# One-liner — no roxygen needed
.get_col <- function(x, col) x[[col]]

# Complex helper — document but suppress .Rd
#' Validate survey design structure
#'
#' @param x A survey design object.
#' @return Invisibly, `TRUE` on success (errors otherwise).
#' @keywords internal
#' @noRd
.validate_design <- function(x) { ... }
```

## Import style examples

```r
# Correct
result <- rlang::enquo(x)
cli::cli_abort("message", class = "error_class")

# Wrong
result <- enquo(x)           # requires @importFrom rlang enquo
cli_abort("message")         # requires @importFrom cli cli_abort

# Wrong — no re-exports; don't do this
#' @importFrom magrittr %>%
#' @export
`%>%` <- magrittr::`%>%`
```

## Version pinning example

```r
Imports:
    cli (>= 3.6.0),        # cli_abort() with class= argument
    rlang (>= 1.1.0),      # rlang::check_required()
    S7 (>= 0.1.0)          # S7 class system
Suggests:
    testthat (>= 3.0.0)
```

Set the bound to the oldest version where the required feature exists. Do
NOT use exact version pins (`==`) — rejected by CRAN and too fragile.

## `devtools::document()` cadence example

```r
# Before committing changes to R/03-functions.R
devtools::document()
git add NAMESPACE man/my_function.Rd
git commit -m "docs(functions): update roxygen"
```

---

## DESCRIPTION template (all surveyverse packages)

```
Package: surveyXXX
Title: [Descriptive title matching the package role]
Version: 0.0.0.9000
Authors@R: person("Jacob", "Dennen", role = c("aut", "cre"), email = "...")
Description: [1-2 sentence description of what the package does]
License: GPL-3
Encoding: UTF-8
Roxygen: list(markdown = TRUE)
RoxygenNote: 7.x.x
```

## Package documentation template (surveypkg-package.R)

```r
#' surveytidy: dplyr/tidyr verbs for survey objects
#'
#' @description
#' surveytidy provides dplyr and tidyr verbs that work with survey design objects
#' from surveycore, allowing...
#'
#' @section Key Functions:
#' - [filter()] — domain-aware filtering
#' - [select()] — column selection
#' - [mutate()] — add/modify variables
#'
#' @section Documentation:
#' For ecosystem architecture, see [the ecosystem guide](../survey-standards/ECOSYSTEM.md).
#'
#' @keywords internal
#' "_PACKAGE"
```

---

## surveycore documentation examples

Survey-specific arguments like `nest`, `fpc`, and `type` need fuller
documentation because they have non-obvious behavior:

```r
#' Create a Taylor series survey design
#'
#' @param data A data.frame containing survey data.
#'
#' @param ids <[`tidy-select`][tidyselect::language]> Primary sampling unit IDs.
#'   Use bare column names (e.g., `psu`, or `c(psu1, psu2)` for multiple levels).
#'   Default `NULL` (assumed SRS within strata).
#'
#' @param weights <[`tidy-select`][tidyselect::language]> Column(s) for survey
#'   weights. If multiple columns specified, they are multiplied together.
#'   Cannot contain `NA` or non-positive values. Default `NULL` (uniform weights).
#'
#' @param strata <[`tidy-select`][tidyselect::language]> Stratum IDs.
#'   Use bare column names (e.g., `strata`). Default `NULL` (no stratification).
#'
#' @param fpc <[`tidy-select`][tidyselect::language]> Finite population
#'   correction column. Supply either:
#'   - An integer column with population size (e.g., stratum population)
#'   - A numeric column (0-1) with sampling fraction
#'   Cannot contain `NA`. If `NULL`, design assumes sampling from infinite
#'   population. Default `NULL`.
#'
#' @param nest Logical. If `TRUE`, PSU IDs are treated as nested within strata —
#'   i.e., the same PSU ID value in two different strata refers to two distinct
#'   PSUs. Set `nest = TRUE` when PSU IDs are not globally unique (e.g., NHANES
#'   uses IDs 1–30 within each stratum). Requires `strata` to be specified.
#'   Default `FALSE`.
#'
#' @examples
#' # Stratified cluster design with FPC (NHANES)
#' d <- as_survey(
#'   nhanes_2017,
#'   ids = sdmvpsu,
#'   weights = wtmec2yr,
#'   strata = sdmvstra,
#'   fpc = NULL,  # Assume infinite population
#'   nest = TRUE  # PSU IDs are nested within strata
#' )
#'
#' # Simple random sample with custom weights
#' df <- data.frame(id = 1:100, y = rnorm(100), w = runif(100, 0.5, 2))
#' d <- as_survey(df, weights = w)
#'
#' # Two-level cluster design (schools -> students)
#' d <- as_survey(
#'   schools_data,
#'   ids = c(school_id, student_id),
#'   weights = sampling_weight
#' )
```

### `@seealso` — constructors only

Only the three constructors (`as_survey()`, `as_survey_rep()`,
`as_survey_twophase()`) carry `@seealso`:

```r
#' @seealso
#'   [as_survey_rep()] for replicate-weight designs,
#'   [as_survey_twophase()] for two-phase designs,
#'   [update_design()] to modify an existing design,
#'   [extract_var_label()] to retrieve variable labels
```

Getters, setters, validators, and other functions do **not** carry
`@seealso`.

### Documentation checklist (before committing roxygen changes)

- [ ] `devtools::document()` has been run
- [ ] `NAMESPACE` file has been updated
- [ ] All exported functions have `@return`
- [ ] All `@examples` are runnable
- [ ] Internal helpers have `@keywords internal` + `@noRd` if needed
- [ ] `@family` tags are correct
- [ ] Constructor functions have `@seealso`
- [ ] No `@importFrom` tags anywhere
- [ ] All external calls use `::`
- [ ] `R CMD check` passes with 0 errors, 0 warnings, ≤2 notes
