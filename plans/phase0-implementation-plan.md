# Phase 0 Implementation Plan: surveycore Package

**Version:** 1.0  
**Created:** February 17, 2025  
**Status:** Ready for Implementation

---

## Executive Summary

This plan provides detailed specifications for building Phase 0 of the surveycore package. Phase 0 establishes the foundation: S7 class system, metadata infrastructure, object creation functions, and conversion utilities. All code should be production-ready with comprehensive tests and documentation.

### Success Criteria
- ✅ Can create all three survey design types (Taylor, replicate, two-phase)
- ✅ S7 validation catches errors appropriately
- ✅ Metadata system preserves and propagates labels correctly
- ✅ Full bidirectional conversion to/from survey/srvyr packages
- ✅ 100% test coverage for implemented code
- ✅ Complete roxygen2 documentation with examples
- ✅ CI/CD pipeline operational

---

## Development Approach

### Testing Strategy
**Test-alongside:** Implement and test together
- Write test file structure first
- Implement each component with corresponding tests
- Run tests continuously during development
- Target 100% code coverage

### Priority Ranking
1. **Extensive test coverage** - Every function thoroughly tested
2. **Code quality and maintainability** - Clean, well-structured code
3. **Comprehensive documentation** - Full roxygen2 docs with examples
4. **Get working code quickly** - Functional but polished implementation

### Validation Philosophy
**Balanced approach:**
- **Strict (fail fast)** for: Invalid design specifications, missing required variables, incompatible design types, data integrity violations
- **Permissive (warn)** for: Missing metadata, unusual but valid designs, potential performance issues, deprecated patterns

---

## Project Structure

### Repository Setup

```
surveycore/
├── .github/
│   └── workflows/
│       ├── R-CMD-check.yaml
│       ├── test-coverage.yaml
│       └── pkgdown.yaml
├── R/
│   ├── 00-s7-classes.R
│   ├── 01-metadata-system.R
│   ├── 02-validators.R
│   ├── 03-constructors.R
│   ├── 04-methods-print.R
│   ├── 05-methods-conversion.R
│   ├── 06-variance-estimation.R
│   ├── 07-utils.R
│   └── surveycore-package.R
├── tests/
│   ├── testthat.R
│   └── testthat/
│       ├── test-s7-classes.R
│       ├── test-metadata-system.R
│       ├── test-validators.R
│       ├── test-constructors.R
│       ├── test-methods-print.R
│       ├── test-conversion.R
│       ├── test-variance-estimation.R
│       └── helper-test-data.R
├── man/
├── vignettes/
│   └── (defer to Phase 2)
├── data-raw/
│   └── (for internal use only)
├── DESCRIPTION
├── NAMESPACE
├── LICENSE
├── README.md
├── NEWS.md
└── .Rbuildignore
```

### Package Infrastructure Files

#### DESCRIPTION
```
Package: surveycore
Title: Core Survey Analysis Infrastructure
Version: 0.0.0.9000
Authors@R: 
    person("Your", "Name", , "your.email@example.com", role = c("aut", "cre"),
           comment = c(ORCID = "YOUR-ORCID-ID"))
Description: Provides S7-based infrastructure for survey analysis including
    design objects, metadata preservation, and variance estimation. Forms the
    foundation of the surveyverse ecosystem.
License: MIT + file LICENSE
Encoding: UTF-8
Roxygen: list(markdown = TRUE)
RoxygenNote: 7.3.1
Depends:
    R (>= 4.3.0)
Imports:
    S7 (>= 0.1.0),
    stats,
    methods
Suggests:
    testthat (>= 3.0.0),
    survey,
    srvyr,
    haven,
    dplyr,
    covr,
    knitr,
    rmarkdown
Config/testthat/edition: 3
URL: https://github.com/yourusername/surveycore
BugReports: https://github.com/yourusername/surveycore/issues
```

#### .Rbuildignore
```
^.*\.Rproj$
^\.Rproj\.user$
^README\.Rmd$
^LICENSE\.md$
^\.github$
^data-raw$
^_pkgdown\.yml$
^docs$
^pkgdown$
```

#### GitHub Actions workflows provided separately (see CI/CD section)

---

## Component 1: S7 Class System

### File: `R/00-s7-classes.R`

This file defines all S7 classes using the S7 package. Each class should be well-documented with roxygen2.

#### 1.1 survey_metadata Class

```r
#' Survey Metadata Container
#'
#' S7 class for storing variable labels, value labels, question prefaces,
#' transformation history, and user notes.
#'
#' @slot variable_labels Named list mapping variable names to labels
#' @slot value_labels Named list mapping variable names to named vectors
#' @slot question_prefaces Named list mapping variable names to question text
#' @slot transformations Named list tracking variable transformations
#' @slot notes Named list for user-defined notes
#'
#' @export
survey_metadata <- S7::new_class(
  "survey_metadata",
  properties = list(
    variable_labels = S7::class_list,
    value_labels = S7::class_list,
    question_prefaces = S7::class_list,
    transformations = S7::class_list,
    notes = S7::class_list
  ),
  validator = function(self) {
    # All properties must be named lists
    # Add validation logic
  }
)
```

**Implementation Notes:**
- All properties default to empty named lists
- Validator ensures list names are valid R variable names
- Metadata should be easily serializable (no complex objects)

#### 1.2 survey_base Class (Abstract)

```r
#' Abstract Base Class for Survey Designs
#'
#' Base class for all survey design objects. Not directly instantiated.
#'
#' @slot data Data frame containing survey data
#' @slot metadata survey_metadata object
#' @slot variables Named list of design variables (ids, strata, fpc, etc.)
#' @slot call Language object storing creation call
#'
#' @export
survey_base <- S7::new_class(
  "survey_base",
  properties = list(
    data = S7::class_data.frame,
    metadata = survey_metadata,
    variables = S7::class_list,
    call = S7::class_language | S7::class_NULL
  ),
  abstract = TRUE
)
```

#### 1.3 survey_taylor Class

```r
#' Taylor Series Linearization Survey Design
#'
#' Survey design using Taylor series linearization for variance estimation.
#'
#' @slot data Data frame containing survey data
#' @slot metadata survey_metadata object
#' @slot variables Named list with: ids, probs, strata, fpc, weights, nest
#' @slot call Language object storing creation call
#'
#' @examples
#' # See as_survey() for creation examples
#'
#' @export
survey_taylor <- S7::new_class(
  "survey_taylor",
  parent = survey_base,
  properties = list(
    # Inherits from survey_base
  ),
  validator = function(self) {
    # Validate required variables exist in data
    # Validate ids structure (list of formulas or character vectors)
    # Validate weights are numeric and positive
    # Validate strata if present
    # Validate fpc if present
  }
)
```

**Key Validation Rules:**
- `ids` required (can be NULL for simple random sample)
- If `ids` provided, must match number of rows in data
- `weights` must be positive numeric
- `strata` if present must be factor or coercible to factor
- `fpc` if present must be numeric and logical (pop sizes or sampling fractions)
- `nest` must be TRUE or FALSE

#### 1.4 survey_replicate Class

```r
#' Replicate Weights Survey Design
#'
#' Survey design using replicate weights for variance estimation.
#'
#' @slot data Data frame containing survey data
#' @slot metadata survey_metadata object
#' @slot variables Named list with: weights, repweights, type, scale, rscales, etc.
#' @slot call Language object storing creation call
#'
#' @examples
#' # See as_survey_rep() for creation examples
#'
#' @export
survey_replicate <- S7::new_class(
  "survey_replicate",
  parent = survey_base,
  properties = list(
    # Inherits from survey_base
  ),
  validator = function(self) {
    # Validate weights column exists
    # Validate repweights exist and are numeric matrix or data frame
    # Validate type is valid: "JK1", "JK2", "JKn", "BRR", "Fay", "bootstrap", etc.
    # Validate scale is numeric
    # Validate rscales matches number of replicates if provided
  }
)
```

**Key Validation Rules:**
- `weights` required
- `repweights` required (matrix or data frame of replicate weights)
- `type` must be one of: "JK1", "JK2", "JKn", "BRR", "Fay", "bootstrap", "ACS", "successive-difference", "other"
- `scale` defaults based on type if not provided
- `rscales` optional, must match number of replicates if provided

#### 1.5 survey_twophase Class

```r
#' Two-Phase Survey Design
#'
#' Survey design for two-phase sampling (e.g., stratified then cluster sample).
#'
#' @slot data Data frame containing survey data
#' @slot metadata survey_metadata object
#' @slot variables Named list with phase 1 and phase 2 design specifications
#' @slot call Language object storing creation call
#'
#' @examples
#' # See as_survey_twophase() for creation examples
#'
#' @export
survey_twophase <- S7::new_class(
  "survey_twophase",
  parent = survey_base,
  properties = list(
    # Inherits from survey_base
  ),
  validator = function(self) {
    # Validate phase 1 design variables
    # Validate phase 2 design variables
    # Validate subset specification
    # Validate method ("full", "approx", "simple")
  }
)
```

**Key Validation Rules:**
- Must have phase 1 and phase 2 specifications
- `subset` indicates which observations are in phase 2
- `method` must be "full", "approx", or "simple"
- Phase 1 and phase 2 design variables must be compatible

### Test File: `tests/testthat/test-s7-classes.R`

```r
# Test S7 class creation and validation

test_that("survey_metadata creates correctly", {
  meta <- survey_metadata()
  expect_s7_class(meta, "survey_metadata")
  expect_equal(length(meta@variable_labels), 0)
  expect_equal(length(meta@value_labels), 0)
})

test_that("survey_metadata validates correctly", {
  # Test valid metadata
  # Test invalid metadata (non-list properties, etc.)
})

test_that("survey_taylor validates correctly", {
  # Test valid Taylor design
  # Test missing required variables
  # Test invalid weights (negative, non-numeric)
  # Test invalid strata
  # Test invalid fpc
})

test_that("survey_replicate validates correctly", {
  # Test valid replicate design
  # Test missing repweights
  # Test invalid type
  # Test mismatched rscales
})

test_that("survey_twophase validates correctly", {
  # Test valid two-phase design
  # Test invalid phase specifications
  # Test invalid method
})
```

---

## Component 2: Metadata System

### File: `R/01-metadata-system.R`

This file implements functions for working with metadata: getting, setting, and propagating labels.

#### 2.1 Metadata Accessors

```r
#' Get Variable Label
#'
#' Retrieve the label for a variable from a survey object.
#'
#' @param x Survey object or metadata object
#' @param var Character string naming the variable
#'
#' @return Character string with label, or NULL if no label exists
#'
#' @examples
#' var_label(my_survey, "age")
#'
#' @export
var_label <- function(x, var) {
  UseMethod("var_label")
}

#' @export
var_label.survey_base <- function(x, var) {
  x@metadata@variable_labels[[var]]
}

#' Set Variable Label
#'
#' Set or update the label for a variable in a survey object.
#'
#' @param x Survey object
#' @param var Character string naming the variable
#' @param value Character string with new label
#'
#' @return Modified survey object
#'
#' @examples
#' my_survey <- var_label(my_survey, "age", "Age in years")
#'
#' @export
`var_label<-` <- function(x, var, value) {
  UseMethod("var_label<-")
}

#' @export
`var_label<-.survey_base` <- function(x, var, value) {
  x@metadata@variable_labels[[var]] <- value
  x
}
```

**Similar functions needed:**
- `val_labels()` / `val_labels<-()` - Get/set value labels
- `question_preface()` / `question_preface<-()` - Get/set question prefaces
- `var_note()` / `var_note<-()` - Get/set user notes

#### 2.2 Metadata Extraction from Haven

```r
#' Extract Metadata from Haven-Labeled Data
#'
#' Extracts variable labels, value labels, and other attributes from
#' data imported with the haven package.
#'
#' @param data Data frame, possibly with haven attributes
#'
#' @return survey_metadata object
#'
#' @examples
#' library(haven)
#' spss_data <- read_spss("data.sav")
#' metadata <- extract_haven_metadata(spss_data)
#'
#' @export
extract_haven_metadata <- function(data) {
  # Extract variable labels from attributes
  # Extract value labels from haven_labelled class
  # Build survey_metadata object
}
```

#### 2.3 Metadata Propagation

```r
#' Copy Metadata Between Survey Objects
#'
#' Internal function to copy metadata when creating new survey objects.
#'
#' @param from Source survey object
#' @param to Target survey object
#' @param vars Optional character vector of variables to copy metadata for
#'
#' @return Target object with copied metadata
#'
#' @keywords internal
copy_metadata <- function(from, to, vars = NULL) {
  # Copy variable labels
  # Copy value labels
  # Copy question prefaces
  # Copy notes
  # Handle transformation history
}
```

### Test File: `tests/testthat/test-metadata-system.R`

```r
test_that("var_label works correctly", {
  # Test getting labels
  # Test setting labels
  # Test getting non-existent label returns NULL
})

test_that("val_labels works correctly", {
  # Test getting value labels
  # Test setting value labels
  # Test named vector structure
})

test_that("extract_haven_metadata works", {
  # Create haven-labeled data
  # Extract metadata
  # Verify labels extracted correctly
})

test_that("metadata propagates correctly", {
  # Create object with metadata
  # Copy to new object
  # Verify metadata preserved
})
```

---

## Component 3: Validators

### File: `R/02-validators.R`

Helper functions for validating design specifications.

```r
#' Validate Survey Design Variables
#'
#' Internal validation functions for checking design specifications.
#'
#' @name validators
#' @keywords internal
NULL

#' @describeIn validators Validate ID specification
validate_ids <- function(ids, data, nest = FALSE) {
  # Check ids is formula, character vector, or NULL
  # Check ids columns exist in data
  # Check for duplicate combinations if nest = FALSE
}

#' @describeIn validators Validate weights
validate_weights <- function(weights, data) {
  # Check weights column exists
  # Check weights are numeric
  # Check weights are positive
  # Warn if weights have extreme values
}

#' @describeIn validators Validate strata
validate_strata <- function(strata, data) {
  # Check strata column exists
  # Coerce to factor if needed
  # Check for empty strata (warn)
}

#' @describeIn validators Validate finite population correction
validate_fpc <- function(fpc, data, ids) {
  # Check fpc column exists
  # Check fpc values are valid (pop size or sampling fraction)
  # Check consistency with design
}

#' @describeIn validators Validate replicate weights
validate_repweights <- function(repweights, data, type) {
  # Check repweights exist in data
  # Check all are numeric
  # Check for NA values (error or warn based on type)
  # Validate structure matches type
}
```

**Validation Philosophy:**
- **Error** for: Missing required columns, invalid data types, mathematically impossible values
- **Warning** for: Unusual but valid designs, potential issues, performance concerns
- **Message** for: Informational only, automatic corrections made

### Test File: `tests/testthat/test-validators.R`

```r
test_that("validate_ids catches errors", {
  # Test invalid ids specification
  # Test missing columns
  # Test duplicate combinations
})

test_that("validate_weights catches errors", {
  # Test missing weights
  # Test negative weights
  # Test non-numeric weights
})

test_that("validate_weights warns appropriately", {
  # Test extreme weight values
  # Test zero weights
})

# Similar tests for other validators
```

---

## Component 4: Object Constructors

### File: `R/03-constructors.R`

Functions to create survey objects.

#### 4.1 as_survey() - Taylor Series Design

```r
#' Create Taylor Series Survey Design
#'
#' Create a survey design object using Taylor series linearization for
#' variance estimation.
#'
#' @param data Data frame containing survey data
#' @param ids Formula or character vector specifying cluster IDs. Use ~1 for
#'   simple random sample. For multistage designs, use ~id1+id2.
#' @param probs Formula or character vector specifying sampling probabilities
#' @param strata Formula or character vector specifying strata
#' @param fpc Formula or character vector specifying finite population
#'   correction (population sizes or sampling fractions)
#' @param weights Formula or character vector specifying sampling weights
#' @param nest Logical. If TRUE, cluster IDs are nested within strata
#' @param check.strata Logical. If TRUE, check for empty strata
#'
#' @return Object of class survey_taylor
#'
#' @examples
#' library(surveycore)
#' 
#' # Simple random sample
#' simple <- as_survey(my_data, ids = ~1, weights = ~wt)
#' 
#' # Stratified sample
#' strat <- as_survey(my_data, ids = ~1, strata = ~region, weights = ~wt)
#' 
#' # Cluster sample
#' clus <- as_survey(my_data, ids = ~school_id, weights = ~wt)
#' 
#' # Two-stage cluster sample
#' two_stage <- as_survey(my_data, ids = ~psu+ssu, weights = ~wt)
#' 
#' # With finite population correction
#' fpc_design <- as_survey(my_data, ids = ~1, fpc = ~N, weights = ~wt)
#'
#' @export
as_survey <- function(data, 
                      ids = ~1,
                      probs = NULL,
                      strata = NULL, 
                      fpc = NULL,
                      weights = NULL,
                      nest = FALSE,
                      check.strata = !nest) {
  
  # Capture call
  call <- match.call()
  
  # Convert formulas to character vectors (internal)
  # Extract metadata from data if haven-labeled
  # Validate all inputs
  # Build variables list
  # Create survey_taylor object
  
  # Return object
}
```

#### 4.2 as_survey_rep() - Replicate Weights Design

```r
#' Create Replicate Weights Survey Design
#'
#' Create a survey design object using replicate weights for variance estimation.
#'
#' @param data Data frame containing survey data
#' @param weights Formula or character vector specifying sampling weights
#' @param repweights Formula, character vector, or data frame specifying
#'   replicate weights. If formula/character, should specify column names.
#' @param type Character string specifying replicate weight type. One of:
#'   "JK1", "JK2", "JKn", "BRR", "Fay", "bootstrap", "ACS", 
#'   "successive-difference", "other"
#' @param scale Numeric. Scaling factor for variance estimation. If NULL,
#'   determined from type
#' @param rscales Numeric vector of replicate-specific scaling factors
#' @param fpc Finite population correction (for some bootstrap types)
#' @param fpctype Character. "fraction" or "correction"
#' @param mse Logical. Use MSE estimates?
#'
#' @return Object of class survey_replicate
#'
#' @examples
#' library(surveycore)
#' 
#' # Jackknife replicate weights
#' jk_design <- as_survey_rep(
#'   my_data,
#'   weights = ~wt,
#'   repweights = ~repwt1+repwt2+repwt3,
#'   type = "JK1"
#' )
#' 
#' # Bootstrap replicate weights
#' boot_design <- as_survey_rep(
#'   my_data,
#'   weights = ~wt,
#'   repweights = boot_weights_df,  # data frame of replicate weights
#'   type = "bootstrap"
#' )
#'
#' @export
as_survey_rep <- function(data,
                          weights,
                          repweights,
                          type = c("JK1", "JK2", "JKn", "BRR", "Fay", 
                                   "bootstrap", "ACS", "successive-difference",
                                   "other"),
                          scale = NULL,
                          rscales = NULL,
                          fpc = NULL,
                          fpctype = c("fraction", "correction"),
                          mse = TRUE) {
  
  # Match arguments
  # Capture call
  # Extract metadata
  # Validate inputs
  # Set default scale based on type if not provided
  # Build variables list
  # Create survey_replicate object
}
```

#### 4.3 as_survey_twophase() - Two-Phase Design

```r
#' Create Two-Phase Survey Design
#'
#' Create a survey design object for two-phase sampling.
#'
#' @param data Data frame containing survey data
#' @param id List of two formulas specifying cluster IDs for phase 1 and 2
#' @param strata List of two formulas specifying strata for phase 1 and 2
#' @param probs List of two formulas specifying sampling probabilities
#' @param fpc List of two formulas or values for finite population corrections
#' @param subset Formula or expression defining phase 2 sample
#' @param method Character. Variance estimation method: "full", "approx", "simple"
#'
#' @return Object of class survey_twophase
#'
#' @examples
#' # Two-phase stratified sample
#' twophase <- as_survey_twophase(
#'   my_data,
#'   id = list(~1, ~cluster),
#'   strata = list(~phase1_stratum, ~phase2_stratum),
#'   subset = ~in_phase2 == 1,
#'   method = "full"
#' )
#'
#' @export
as_survey_twophase <- function(data,
                               id,
                               strata = NULL,
                               probs = NULL,
                               fpc = NULL,
                               subset,
                               method = c("full", "approx", "simple")) {
  
  # Validate two-element lists
  # Capture call
  # Extract metadata
  # Validate each phase design
  # Validate subset
  # Build variables list
  # Create survey_twophase object
}
```

### Test File: `tests/testthat/test-constructors.R`

```r
# Helper data creation in tests/testthat/helper-test-data.R

test_that("as_survey creates simple random sample", {
  # Create simple design
  # Verify class
  # Verify structure
  # Verify metadata extracted
})

test_that("as_survey creates stratified sample", {
  # Create stratified design
  # Verify strata handling
})

test_that("as_survey creates cluster sample", {
  # Create cluster design
  # Verify ids handling
})

test_that("as_survey validates inputs", {
  # Test error messages for invalid inputs
})

test_that("as_survey_rep creates correctly", {
  # Create replicate design
  # Verify repweights handling
  # Verify type-specific defaults
})

test_that("as_survey_twophase creates correctly", {
  # Create two-phase design
  # Verify phase 1 and 2 specs
})
```

---

## Component 5: Print and Summary Methods

### File: `R/04-methods-print.R`

S3-compatible print and summary methods for survey objects.

```r
#' Print Survey Design
#'
#' @param x Survey design object
#' @param ... Additional arguments (currently unused)
#'
#' @return x invisibly
#'
#' @export
print.survey_taylor <- function(x, ...) {
  cat("Survey Design (Taylor Series Linearization)\n")
  cat("-------------------------------------------\n\n")
  
  # Print call
  cat("Call:\n")
  print(x@call)
  cat("\n")
  
  # Print sample size
  cat("Sample size:", nrow(x@data), "\n")
  
  # Print design info
  if (!is.null(x@variables$strata)) {
    cat("Strata:", length(unique(x@data[[x@variables$strata]])), "\n")
  }
  
  # Print cluster info if applicable
  # Print FPC info if applicable
  # Print weights summary
  
  invisible(x)
}

#' @export
print.survey_replicate <- function(x, ...) {
  cat("Survey Design (Replicate Weights)\n")
  cat("----------------------------------\n\n")
  
  # Print call
  # Print sample size
  # Print replicate type and count
  # Print scale information
  
  invisible(x)
}

#' @export
print.survey_twophase <- function(x, ...) {
  cat("Two-Phase Survey Design\n")
  cat("-----------------------\n\n")
  
  # Print call
  # Print phase 1 info
  # Print phase 2 info
  # Print subset info
  
  invisible(x)
}

#' Summary of Survey Design
#'
#' @param object Survey design object
#' @param ... Additional arguments
#'
#' @return Summary object (S3 class)
#'
#' @export
summary.survey_taylor <- function(object, ...) {
  # Compute summary statistics
  # Design effect estimates
  # Weight distribution
  # Effective sample size
  
  structure(
    list(
      call = object@call,
      nobs = nrow(object@data),
      design_info = list(...),
      # ... more summary info
    ),
    class = "summary.survey_taylor"
  )
}

#' @export
print.summary.survey_taylor <- function(x, ...) {
  # Print formatted summary
}

# Similar for other design types
```

### Test File: `tests/testthat/test-methods-print.R`

```r
test_that("print.survey_taylor displays correctly", {
  design <- as_survey(test_data, ids = ~1, weights = ~wt)
  
  # Capture output
  output <- capture.output(print(design))
  
  # Check for expected content
  expect_true(any(grepl("Taylor Series", output)))
  expect_true(any(grepl("Sample size", output)))
})

test_that("summary.survey_taylor computes correctly", {
  design <- as_survey(test_data, ids = ~1, weights = ~wt)
  summ <- summary(design)
  
  expect_s3_class(summ, "summary.survey_taylor")
  expect_equal(summ$nobs, nrow(test_data))
})

# Similar for other design types
```

---

## Component 6: Conversion Utilities

### File: `R/05-methods-conversion.R`

Bidirectional conversion between surveycore and survey/srvyr packages.

#### 6.1 surveycore → survey

```r
#' Convert to survey Package Design
#'
#' Convert a surveycore design object to a survey package design object.
#'
#' @param x Survey design object (survey_taylor, survey_replicate, or survey_twophase)
#' @param ... Additional arguments
#'
#' @return Object of class svydesign, svyrep.design, or twophase
#'
#' @examples
#' library(surveycore)
#' library(survey)
#' 
#' my_design <- as_survey(data, ids = ~psu, weights = ~wt)
#' survey_design <- as_svydesign(my_design)
#'
#' @export
as_svydesign <- function(x, ...) {
  UseMethod("as_svydesign")
}

#' @export
as_svydesign.survey_taylor <- function(x, ...) {
  # Extract design variables from x@variables
  # Call survey::svydesign() with appropriate arguments
  # Transfer any additional metadata as attributes
  
  if (!requireNamespace("survey", quietly = TRUE)) {
    stop("Package 'survey' is required for this conversion")
  }
  
  # Build svydesign call
  survey::svydesign(
    ids = ...,
    probs = ...,
    strata = ...,
    fpc = ...,
    weights = ...,
    data = x@data,
    nest = x@variables$nest
  )
}

#' @export
as_svydesign.survey_replicate <- function(x, ...) {
  if (!requireNamespace("survey", quietly = TRUE)) {
    stop("Package 'survey' is required for this conversion")
  }
  
  # Extract replicate weights
  # Call survey::svrepdesign()
  
  survey::svrepdesign(
    data = x@data,
    weights = ...,
    repweights = ...,
    type = x@variables$type,
    scale = x@variables$scale,
    rscales = x@variables$rscales,
    # ... other arguments
  )
}

#' @export
as_svydesign.survey_twophase <- function(x, ...) {
  if (!requireNamespace("survey", quietly = TRUE)) {
    stop("Package 'survey' is required for this conversion")
  }
  
  # Extract phase 1 and phase 2 designs
  # Call survey::twophase()
}
```

#### 6.2 survey → surveycore

```r
#' Convert from survey Package Design
#'
#' Convert a survey package design object to a surveycore design object.
#'
#' @param x Object of class svydesign, svyrep.design, or twophase
#' @param ... Additional arguments
#'
#' @return survey_taylor, survey_replicate, or survey_twophase object
#'
#' @examples
#' library(survey)
#' library(surveycore)
#' 
#' survey_design <- svydesign(ids = ~psu, weights = ~wt, data = data)
#' my_design <- from_svydesign(survey_design)
#'
#' @export
from_svydesign <- function(x, ...) {
  UseMethod("from_svydesign")
}

#' @export
from_svydesign.survey.design2 <- function(x, ...) {
  # Extract design components from survey object
  # Extract data
  # Build surveycore object using as_survey()
}

#' @export
from_svydesign.svyrep.design <- function(x, ...) {
  # Extract design components
  # Build survey_replicate object
}

#' @export  
from_svydesign.twophase <- function(x, ...) {
  # Extract phase 1 and 2 specs
  # Build survey_twophase object
}
```

#### 6.3 surveycore → srvyr

```r
#' Convert to srvyr Package Design
#'
#' Convert a surveycore design to a srvyr tbl_svy object.
#'
#' @param x Survey design object
#' @param ... Additional arguments
#'
#' @return tbl_svy object
#'
#' @examples
#' library(surveycore)
#' library(srvyr)
#' 
#' my_design <- as_survey(data, ids = ~psu, weights = ~wt)
#' srvyr_design <- as_tbl_svy(my_design)
#'
#' @export
as_tbl_svy <- function(x, ...) {
  if (!requireNamespace("srvyr", quietly = TRUE)) {
    stop("Package 'srvyr' is required for this conversion")
  }
  
  # Convert to survey package first
  survey_obj <- as_svydesign(x)
  
  # Then convert to srvyr
  srvyr::as_survey(survey_obj)
}
```

#### 6.4 srvyr → surveycore

```r
#' Convert from srvyr Package Design
#'
#' Convert a srvyr tbl_svy object to a surveycore design.
#'
#' @param x tbl_svy object
#' @param ... Additional arguments
#'
#' @return survey_taylor, survey_replicate, or survey_twophase object
#'
#' @export
from_tbl_svy <- function(x, ...) {
  if (!requireNamespace("srvyr", quietly = TRUE)) {
    stop("Package 'srvyr' is required for this conversion")
  }
  
  # Extract underlying survey design from srvyr object
  survey_obj <- attr(x, "survey")  # or however srvyr stores it
  
  # Convert from survey to surveycore
  from_svydesign(survey_obj)
}
```

### Test File: `tests/testthat/test-conversion.R`

```r
test_that("conversion to survey package works", {
  skip_if_not_installed("survey")
  
  # Create surveycore design
  my_design <- as_survey(test_data, ids = ~cluster, weights = ~wt)
  
  # Convert to survey
  survey_design <- as_svydesign(my_design)
  
  # Check class
  expect_s3_class(survey_design, "survey.design")
  
  # Check data preserved
  expect_equal(nrow(survey_design$variables), nrow(test_data))
})

test_that("conversion from survey package works", {
  skip_if_not_installed("survey")
  
  # Create survey design
  survey_design <- survey::svydesign(
    ids = ~cluster,
    weights = ~wt,
    data = test_data
  )
  
  # Convert to surveycore
  my_design <- from_svydesign(survey_design)
  
  # Check class
  expect_s7_class(my_design, "survey_taylor")
  
  # Check data preserved
  expect_equal(nrow(my_design@data), nrow(test_data))
})

test_that("round-trip conversion preserves data", {
  skip_if_not_installed("survey")
  
  # Start with surveycore
  design1 <- as_survey(test_data, ids = ~cluster, weights = ~wt)
  
  # Convert to survey and back
  survey_obj <- as_svydesign(design1)
  design2 <- from_svydesign(survey_obj)
  
  # Should be equivalent
  expect_equal(design1@data, design2@data)
  expect_equal(design1@variables, design2@variables)
})

# Similar tests for srvyr conversion
```

---

## Component 7: Variance Estimation (Vendored Code)

### File: `R/06-variance-estimation.R`

This component vendors variance estimation code from the survey package.

**Critical Requirements:**
1. **Attribution:** Clearly document that code is from survey package
2. **License compliance:** survey is GPL-2/GPL-3, surveycore will use compatible license
3. **Minimal refactoring:** Only refactor if necessary, maintain numerical equivalence
4. **Testing:** Extensive numerical comparison with survey package results

```r
#' Variance Estimation Functions
#'
#' Functions for variance estimation vendored from the survey package.
#' 
#' The variance estimation code in this file is adapted from the survey package
#' by Thomas Lumley, licensed under GPL-2 | GPL-3. The original code can be
#' found at https://cran.r-project.org/package=survey
#' 
#' Modifications have been made to integrate with the S7 class system while
#' maintaining numerical equivalence with the original implementation.
#'
#' @references
#' Lumley T (2024). survey: analysis of complex survey samples. R package
#' version 4.4-2, https://cran.r-project.org/package=survey
#'
#' @name variance-estimation
#' @keywords internal
NULL

#' @describeIn variance-estimation Taylor series variance for totals
variance_taylor_total <- function(x, design) {
  # Vendored from survey::svytotal
  # Core variance calculation logic
}

#' @describeIn variance-estimation Taylor series variance for means
variance_taylor_mean <- function(x, design) {
  # Vendored from survey::svymean
}

#' @describeIn variance-estimation Replicate variance estimation
variance_replicate <- function(theta, theta_reps, design) {
  # Vendored from survey::svrVar or similar
  # Generic replicate variance formula
}

# Additional low-level variance functions as needed
```

**Implementation Strategy:**
1. Start with most essential functions (mean, total variances)
2. Copy code from survey package
3. Adapt to work with S7 classes
4. Add extensive tests comparing with survey package
5. Document any changes made

### Test File: `tests/testthat/test-variance-estimation.R`

```r
test_that("variance estimation matches survey package", {
  skip_if_not_installed("survey")
  
  # Create identical designs in both packages
  surveycore_design <- as_survey(test_data, ids = ~cluster, weights = ~wt)
  survey_design <- survey::svydesign(ids = ~cluster, weights = ~wt, data = test_data)
  
  # Compute variance using both methods
  # (This will be fleshed out in Phase 1, but set up infrastructure now)
  
  # Compare results with tight tolerance
  # expect_equal(var_surveycore, var_survey, tolerance = 1e-10)
})

# Note: Full variance testing happens in Phase 1
# Phase 0 focus is on having the vendored code in place and validated
```

---

## Component 8: Utilities

### File: `R/07-utils.R`

Helper functions used throughout the package.

```r
#' Utility Functions
#'
#' Internal utility functions for surveycore.
#'
#' @name utils
#' @keywords internal
NULL

#' @describeIn utils Convert formula to character vector
formula_to_char <- function(formula) {
  if (is.null(formula)) return(NULL)
  if (inherits(formula, "formula")) {
    all.vars(formula)
  } else if (is.character(formula)) {
    formula
  } else {
    stop("Must provide formula or character vector")
  }
}

#' @describeIn utils Check if variable exists in data
check_var_exists <- function(var, data, arg_name = "variable") {
  if (!var %in% names(data)) {
    stop(sprintf("%s '%s' not found in data", arg_name, var))
  }
  TRUE
}

#' @describeIn utils Extract specific columns from data
extract_design_vars <- function(data, vars_list) {
  # Safely extract design variables
  # Handle formulas, character vectors, NULL values
}

#' @describeIn utils Compute effective sample size
effective_sample_size <- function(weights) {
  # n_eff = (sum w)^2 / sum(w^2)
  sum_w <- sum(weights, na.rm = TRUE)
  sum_w2 <- sum(weights^2, na.rm = TRUE)
  sum_w^2 / sum_w2
}

#' @describeIn utils Get variable label with fallback
get_var_label_safe <- function(metadata, var) {
  label <- metadata@variable_labels[[var]]
  if (is.null(label)) var else label
}
```

### Test File: Tests covered in component-specific test files

---

## Component 9: Package Documentation

### File: `R/surveycore-package.R`

```r
#' surveycore: Core Survey Analysis Infrastructure
#'
#' Provides S7-based infrastructure for survey analysis including design
#' objects, metadata preservation, and variance estimation. Forms the
#' foundation of the surveyverse ecosystem.
#'
#' @details
#' ## Main Functions
#'
#' ### Object Creation
#' - [as_survey()] - Create Taylor series design
#' - [as_survey_rep()] - Create replicate weights design
#' - [as_survey_twophase()] - Create two-phase design
#'
#' ### Metadata
#' - [var_label()] - Get/set variable labels
#' - [val_labels()] - Get/set value labels
#' - [question_preface()] - Get/set question prefaces
#'
#' ### Conversion
#' - [as_svydesign()] - Convert to survey package
#' - [from_svydesign()] - Convert from survey package
#' - [as_tbl_svy()] - Convert to srvyr package
#' - [from_tbl_svy()] - Convert from srvyr package
#'
#' @references
#' For variance estimation methodology:
#' 
#' Lumley T (2024). survey: analysis of complex survey samples. R package
#' version 4.4-2, \url{https://cran.r-project.org/package=survey}
#'
#' @keywords internal
"_PACKAGE"

# The following block is used by usethis to automatically manage
# roxygen namespace tags. Modify with care!
## usethis namespace: start
## usethis namespace: end
NULL
```

---

## Testing Infrastructure

### File: `tests/testthat.R`

```r
library(testthat)
library(surveycore)

test_check("surveycore")
```

### File: `tests/testthat/helper-test-data.R`

```r
# Create reusable test datasets

# Simple random sample data
test_data_srs <- data.frame(
  id = 1:100,
  x = rnorm(100),
  y = rnorm(100),
  wt = runif(100, 0.5, 2)
)

# Stratified sample data
test_data_strat <- data.frame(
  id = 1:200,
  stratum = rep(c("A", "B", "C", "D"), each = 50),
  x = rnorm(200),
  y = rnorm(200),
  wt = runif(200, 0.5, 2)
)

# Cluster sample data
test_data_cluster <- data.frame(
  id = 1:300,
  cluster = rep(1:30, each = 10),
  x = rnorm(300),
  y = rnorm(300),
  wt = rep(runif(30, 5, 15), each = 10)
)

# Two-stage cluster data
test_data_twostage <- data.frame(
  id = 1:400,
  psu = rep(1:40, each = 10),
  ssu = 1:400,
  x = rnorm(400),
  y = rnorm(400),
  wt = runif(400, 0.5, 2)
)

# Data with haven-style labels
if (requireNamespace("haven", quietly = TRUE)) {
  test_data_labeled <- test_data_srs
  attr(test_data_labeled$x, "label") <- "Variable X"
  attr(test_data_labeled$y, "label") <- "Variable Y"
  
  test_data_labeled$x <- haven::labelled(
    test_data_labeled$x,
    labels = c("Low" = -1, "High" = 1)
  )
}

# Replicate weights data
test_data_repweights <- cbind(
  test_data_srs,
  as.data.frame(matrix(
    runif(100 * 20, 0.5, 2),
    ncol = 20,
    dimnames = list(NULL, paste0("repwt", 1:20))
  ))
)
```

### Coverage Target

**Goal:** 100% test coverage for Phase 0

**Strategy:**
- Every exported function has tests
- Every validation path tested
- Edge cases explicitly tested
- Error messages verified
- S3 methods tested

**Coverage Measurement:**
- Use covr package
- Generate coverage reports in CI
- Block merges if coverage drops below 95%

---

## CI/CD Configuration

### File: `.github/workflows/R-CMD-check.yaml`

```yaml
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

name: R-CMD-check

jobs:
  R-CMD-check:
    runs-on: ${{ matrix.config.os }}

    name: ${{ matrix.config.os }} (${{ matrix.config.r }})

    strategy:
      fail-fast: false
      matrix:
        config:
          - {os: macos-latest,   r: 'release'}
          - {os: windows-latest, r: 'release'}
          - {os: ubuntu-latest,   r: 'devel', http-user-agent: 'release'}
          - {os: ubuntu-latest,   r: 'release'}
          - {os: ubuntu-latest,   r: 'oldrel-1'}

    env:
      GITHUB_PAT: ${{ secrets.GITHUB_TOKEN }}
      R_KEEP_PKG_SOURCE: yes

    steps:
      - uses: actions/checkout@v4

      - uses: r-lib/actions/setup-pandoc@v2

      - uses: r-lib/actions/setup-r@v2
        with:
          r-version: ${{ matrix.config.r }}
          http-user-agent: ${{ matrix.config.http-user-agent }}
          use-public-rspm: true

      - uses: r-lib/actions/setup-r-dependencies@v2
        with:
          extra-packages: any::rcmdcheck
          needs: check

      - uses: r-lib/actions/check-r-package@v2
        with:
          upload-snapshots: true
```

### File: `.github/workflows/test-coverage.yaml`

```yaml
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

name: test-coverage

jobs:
  test-coverage:
    runs-on: ubuntu-latest
    env:
      GITHUB_PAT: ${{ secrets.GITHUB_TOKEN }}

    steps:
      - uses: actions/checkout@v4

      - uses: r-lib/actions/setup-r@v2
        with:
          use-public-rspm: true

      - uses: r-lib/actions/setup-r-dependencies@v2
        with:
          extra-packages: any::covr
          needs: coverage

      - name: Test coverage
        run: |
          covr::codecov(
            quiet = FALSE,
            clean = FALSE,
            install_path = file.path(normalizePath(Sys.getenv("RUNNER_TEMP"), winslash = "/"), "package")
          )
        shell: Rscript {0}

      - name: Show testthat output
        if: always()
        run: |
          ## --------------------------------------------------------------------
          find ${{ runner.temp }}/package -name 'testthat.Rout*' -exec cat '{}' \; || true
        shell: bash

      - name: Upload test results
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: coverage-test-failures
          path: ${{ runner.temp }}/package
```

### File: `.github/workflows/pkgdown.yaml`

```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  release:
    types: [published]
  workflow_dispatch:

name: pkgdown

jobs:
  pkgdown:
    runs-on: ubuntu-latest
    env:
      GITHUB_PAT: ${{ secrets.GITHUB_TOKEN }}
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4

      - uses: r-lib/actions/setup-pandoc@v2

      - uses: r-lib/actions/setup-r@v2
        with:
          use-public-rspm: true

      - uses: r-lib/actions/setup-r-dependencies@v2
        with:
          extra-packages: any::pkgdown, local::.
          needs: website

      - name: Build site
        run: pkgdown::build_site_github_pages(new_process = FALSE, install = FALSE)
        shell: Rscript {0}

      - name: Deploy to GitHub pages 🚀
        if: github.event_name != 'pull_request'
        uses: JamesIves/github-pages-deploy-action@v4.5.0
        with:
          clean: false
          branch: gh-pages
          folder: docs
```

---

## Development Workflow

### Step-by-Step Implementation Order

1. **Setup (Day 1)**
   - Create GitHub repository
   - Initialize R package structure
   - Set up CI/CD workflows
   - Create initial DESCRIPTION, NAMESPACE, README

2. **S7 Classes (Days 2-3)**
   - Implement survey_metadata class
   - Implement survey_base abstract class
   - Implement survey_taylor class
   - Implement survey_replicate class
   - Implement survey_twophase class
   - Write comprehensive tests

3. **Metadata System (Days 3-4)**
   - Implement metadata accessors (var_label, val_labels, etc.)
   - Implement haven metadata extraction
   - Implement metadata propagation
   - Write comprehensive tests

4. **Validators (Day 4)**
   - Implement all validation functions
   - Test error and warning conditions
   - Verify helpful error messages

5. **Constructors (Days 5-7)**
   - Implement as_survey()
   - Implement as_survey_rep()
   - Implement as_survey_twophase()
   - Integrate metadata extraction
   - Write comprehensive tests
   - Test with various data structures

6. **Print/Summary Methods (Day 8)**
   - Implement print methods for all types
   - Implement summary methods
   - Test output formatting

7. **Conversion Utilities (Days 9-10)**
   - Implement as_svydesign() for all types
   - Implement from_svydesign() for all types
   - Implement srvyr conversion
   - Test round-trip conversions
   - Verify data preservation

8. **Variance Estimation (Days 11-12)**
   - Vendor core variance functions from survey
   - Adapt to S7 classes
   - Write numerical comparison tests
   - Document attribution

9. **Documentation (Days 13-14)**
   - Complete all roxygen2 documentation
   - Add examples to all functions
   - Write package-level documentation
   - Create README with usage examples
   - Ensure pkgdown site builds

10. **Testing & Refinement (Days 14-15)**
    - Achieve 100% test coverage
    - Run R CMD check on all platforms
    - Fix any issues identified
    - Polish documentation
    - Create NEWS.md entry

### Quality Gates

Before considering Phase 0 complete:

- [ ] All exported functions documented with roxygen2
- [ ] All functions have working examples
- [ ] 100% test coverage achieved
- [ ] R CMD check passes on all platforms (Mac, Windows, Linux)
- [ ] R CMD check with R-devel passes
- [ ] CI/CD all green
- [ ] Round-trip conversions preserve data exactly
- [ ] Numerical validation against survey package passes
- [ ] All S7 validators working correctly
- [ ] README has clear installation and usage instructions
- [ ] NEWS.md documents Phase 0 features

---

## Documentation Standards

### Roxygen2 Template

Every exported function should follow this template:

```r
#' Function Title (Active Voice, Imperative)
#'
#' Detailed description of what the function does. Include:
#' - When to use this function
#' - What it returns
#' - Any important caveats
#'
#' @param param1 Description including type, constraints, defaults
#' @param param2 Description
#'
#' @return Description of return value including class and structure
#'
#' @examples
#' # Example 1: Basic usage
#' result1 <- my_function(data, param1 = "value")
#'
#' # Example 2: Advanced usage
#' result2 <- my_function(data, param1 = "value", param2 = TRUE)
#'
#' @seealso [related_function()], [other_related()]
#'
#' @export
```

### README Structure

```markdown
# surveycore

<!-- badges: start -->
[![R-CMD-check](badge-url)](action-url)
[![Codecov](badge-url)](coverage-url)
<!-- badges: end -->

## Overview

surveycore provides S7-based infrastructure for survey analysis...

## Installation

```r
# Install development version from GitHub
# install.packages("devtools")
devtools::install_github("yourusername/surveycore")
```

## Usage

```r
library(surveycore)

# Create a survey design
my_survey <- as_survey(
  data = my_data,
  ids = ~cluster_id,
  weights = ~weight,
  strata = ~stratum
)

# Print design
print(my_survey)

# Access metadata
var_label(my_survey, "age")
```

## Features

- S7 class system with validation
- Automatic metadata preservation
- Bidirectional conversion with survey/srvyr
- ...

## Roadmap

Phase 0 (current): Foundation - COMPLETE
Phase 1: Analysis functions
Phase 2: Regression and crosstabs
...

## License

MIT License


---

## Risk Mitigation

### Technical Risks

**Risk 1: S7 Integration Issues**
- *Probability:* Low-Medium
- *Impact:* High
- *Mitigation:* Early testing, extensive validation, fallback to S3 if needed
- *Detection:* Comprehensive test suite, CI on multiple R versions

**Risk 2: Numerical Differences from survey Package**
- *Probability:* Medium
- *Impact:* High
- *Mitigation:* Minimal refactoring of vendored code, extensive numerical testing
- *Detection:* Comparison tests with tolerance < 1e-10

**Risk 3: Conversion Utilities Lose Information**
- *Probability:* Low
- *Impact:* Medium
- *Mitigation:* Round-trip testing, careful mapping of design parameters
- *Detection:* Comprehensive conversion test suite

### Timeline Risks

**Risk 4: Scope Creep**
- *Probability:* Medium
- *Impact:* Medium
- *Mitigation:* Strict adherence to Phase 0 scope, defer enhancements
- *Detection:* Regular progress review against plan

**Risk 5: Longer Than Estimated**
- *Probability:* Medium
- *Impact:* Low
- *Mitigation:* Build in buffer time, prioritize core functionality
- *Detection:* Daily progress tracking

---

## Success Metrics

### Code Quality
- ✅ R CMD check: 0 errors, 0 warnings, 0 notes
- ✅ Test coverage: 100%
- ✅ Cyclomatic complexity: <15 for all functions
- ✅ Code style: Consistent (tidyverse style guide)

### Documentation Quality
- ✅ All exported functions documented
- ✅ All examples run successfully
- ✅ README complete with installation and usage
- ✅ pkgdown site builds and deploys

### Functionality
- ✅ Can create all three design types
- ✅ Metadata preservation works
- ✅ Conversion preserves data exactly
- ✅ Validation catches errors appropriately
- ✅ Print methods informative and readable

### Integration
- ✅ Works on Windows, Mac, Linux
- ✅ Works with R >= 4.3.0
- ✅ Compatible with survey package >= 4.0
- ✅ Compatible with srvyr package >= 1.0

---

## Next Steps After Phase 0

Once Phase 0 is complete and all success criteria are met:

1. **Phase 0.5 Planning:** Create detailed implementation plan for surveytidy package
2. **Phase 1 Planning:** Create detailed implementation plan for analysis functions
3. **Feedback Collection:** Share Phase 0 with potential users for feedback
4. **Performance Baseline:** Establish performance benchmarks vs survey package

---

## Appendix A: Key Design Decisions

### Why S7?
- Modern object system with validation
- Better than S3 for complex class hierarchies
- Posit-supported and actively developed
- Easier to maintain than S4

### Why Vendor survey Code?
- Ensures numerical equivalence
- Avoids dependency issues
- Allows targeted optimization
- Full control over codebase

### Why Separate Metadata?
- Clean separation of concerns
- Easy to access and modify
- Doesn't interfere with dplyr operations
- Scales to large datasets

### Why Three Packages?
- Clear separation of responsibilities
- Optional components (can use just core)
- Easier to maintain
- Follows tidyverse model

---

## Appendix B: Testing Strategy Details

### Unit Tests
- Test each function in isolation
- Mock dependencies where appropriate
- Test edge cases and error conditions
- Verify error messages

### Integration Tests
- Test workflows across multiple functions
- Test conversion round-trips
- Test metadata preservation through operations

### Comparison Tests
- Compare numerical output with survey package
- Tolerance: 1e-10 for estimates, 1e-8 for variances
- Test on variety of design types and data structures

### Platform Tests
- CI runs on Windows, Mac, Linux
- Test with R release, devel, oldrel
- Test with various R versions

---

## Appendix C: Code Style Guidelines

Follow the tidyverse style guide with these specific additions:

**Naming:**
- Classes: `snake_case` (survey_taylor)
- Functions: `snake_case` (as_survey, get_freqs)
- Internal functions: Prefix with `.` (.validate_ids)
- Constants: `SCREAMING_SNAKE_CASE`

**Documentation:**
- Always use markdown in roxygen2
- Include examples for all exported functions
- Link related functions with `[function_name()]`
- Use active voice in descriptions

**Error Messages:**
- Be specific about what's wrong
- Suggest how to fix it
- Use sprintf() for dynamic content
- Use stop(), warning(), message() appropriately

**Testing:**
- Descriptive test names: "function_name does expected_behavior"
- Group related tests with describe() when using BDD style
- Use expect_error() with regex to test error messages
- Always clean up after tests (no side effects)

---

**END OF IMPLEMENTATION PLAN**

This plan is ready to be provided to Claude Code for implementation. All components are specified in detail with clear expectations for quality, testing, and documentation.