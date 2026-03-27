#' srr_stats
#'
#' Standards addressed or explicitly deferred in this file. Tags may be moved
#' to any source file; those placed here apply package-wide.
#'
#' @srrstatsVerbose TRUE
#'
#' @srrstats {G1.4} Software uses roxygen2 throughout; RoxygenNote is set in
#'   DESCRIPTION and all exported functions carry roxygen2 documentation.
#'
#' @srrstats {G1.6} Numerical correctness tests compare surveycore estimates
#'   against the survey package for means, totals, proportions, and quantiles
#'   using NHANES and ACS PUMS datasets (see test-variance-taylor.R,
#'   test-variance-replicate.R).
#'
#' @srrstats {G2.0} Constructors assert that named design columns (ids,
#'   weights, strata, fpc) are present in the supplied data frame and that each
#'   resolves to a valid column via tidyselect before object construction.
#'
#' @srrstats {G2.0a} All @param entries for column-selecting arguments
#'   explicitly state whether a single column or multiple columns are expected.
#'
#' @srrstats {G2.1} Type assertions are implemented in R/core-validators.R:
#'   weights must be numeric and positive; FPC must be numeric and
#'   non-missing; strata and ids must refer to columns that exist in @data.
#'
#' @srrstats {G2.1a} @param documentation for all constructor arguments states
#'   accepted data types (e.g. numeric for weights, character or factor for
#'   strata).
#'
#' @srrstats {G2.2} Parameters expected to be univariate (type, fpctype, mse,
#'   nest) are validated via match.arg() or logical coercion, preventing
#'   multi-valued submission.
#'
#' @srrstats {G2.3} Univariate character parameters (type, fpctype, method)
#'   use match.arg(), ensuring only permitted values are accepted.
#'
#' @srrstats {G2.3a} match.arg() is used for all character-valued control
#'   parameters in constructors and analysis functions (e.g. type in
#'   as_survey_replicate(), method in get_corr()).
#'
#' @srrstats {G2.4} Surveycore validates input types at construction time and
#'   errors with informative cli_abort() messages when types are incompatible,
#'   rather than silently coercing. Explicit factor conversion is applied
#'   where appropriate (see G2.4d).
#'
#' @srrstats {G2.4d} Analysis functions convert grouped output columns to
#'   factor when the grouping variable carries value labels and
#'   label_values = TRUE, using explicit as.factor() conversion.
#'
#' @srrstats {G2.6} Constructor pre-processing via tidyselect handles
#'   one-dimensional column inputs (bare names, c(), starts_with(), etc.)
#'   consistently regardless of how they are specified.
#'
#' @srrstats {G2.7} Constructors accept any data.frame-like tabular input
#'   including data.frame, tibble, and data.table objects, as these all
#'   satisfy the S7::class_data.frame property constraint.
#'
#' @srrstats {G2.8} The S7 class system provides dispatch and type
#'   enforcement: all analysis functions check S7::S7_inherits(x, survey_base)
#'   before proceeding, ensuring a single defined class is propagated through
#'   sub-functions.
#'
#' @srrstats {G2.10} Column extraction throughout the package uses [[
#'   consistently, never [, ensuring single-column extraction returns a
#'   vector regardless of the underlying tabular class.
#'
#' @srrstats {G2.13} Pre-processing in R/core-validators.R checks for missing
#'   values in design variables: NA weights cause an error
#'   (surveycore_error_weights_na); NA FPC values cause an error
#'   (surveycore_error_fpc_na).
#'
#' @srrstats {G2.14} Analysis functions provide an na.rm parameter (default
#'   TRUE) giving users explicit control over missing-value handling in
#'   analytic computations.
#'
#' @srrstats {G2.14a} Validators error on missing values in design variables
#'   (weights, FPC) that must be fully observed for variance estimation.
#'
#' @srrstats {G2.14b} Analysis functions default to na.rm = TRUE, excluding
#'   missing outcome values from computations; behaviour is documented in
#'   @param na.rm.
#'
#' @srrstats {G2.15} No function in the package passes data to base routines
#'   with a default na.rm = FALSE. All calls to mean(), sum(), var(), and
#'   similar functions use explicit na.rm = TRUE or receive pre-filtered data.
#'
#' @srrstats {G5.0} Standard datasets with known properties (nhanes_2017 and
#'   acs_pums_wy) are used in numerical correctness tests.
#'
#' @srrstats {G5.1} Both nhanes_2017 and acs_pums_wy are exported datasets,
#'   making them available for users to independently reproduce test results.
#'
#' @srrstats {G5.2} Appropriate error and warning behaviour is explicitly
#'   demonstrated in tests: every cli_abort() / cli_warn() call has a
#'   corresponding expect_error(class = ...) / expect_warning(class = ...)
#'   test, plus snapshot tests for message text.
#'
#' @srrstats {G5.2a} Every error and warning is assigned a unique class=
#'   argument (convention: surveycore_error_* / surveycore_warning_*),
#'   ensuring uniqueness of all generated messages.
#'
#' @srrstats {G5.2b} Each error class documented in plans/error-messages.md
#'   has a corresponding test that triggers it and confirms the class string,
#'   along with a snapshot test for the rendered message text.
#'
#' @srrstats {G5.4} Correctness is tested by comparing surveycore point
#'   estimates and standard errors against the survey package on real survey
#'   datasets, using tolerances of 1e-10 (point estimates) and 1e-8 (SEs).
#'
#' @srrstats {G5.4b} All variance methods (Taylor series, replicate weights,
#'   two-phase) are tested against equivalent survey::svydesign() objects to
#'   confirm numerical equivalence with the existing reference implementation.
#'
#' @srrstats {G5.5} Correctness tests that use synthetic data call
#'   make_survey_data(seed = N) with a fixed seed, ensuring reproducibility.
#'
#' @srrstats {EA2.4} surveycore uses an explicit S7 class system
#'   (survey_taylor, survey_replicate, survey_twophase) that encodes the design
#'   type and all associated parameters.
#'
#' @srrstats {EA2.6} Routines process vector columns regardless of additional
#'   attributes: haven-style "label" and "labels" attributes are automatically
#'   detected and preserved in @metadata during construction, and restored in
#'   analysis output when requested.
#'
#' @srrstats {EA3.0} The get_*() family (get_freqs(), get_means(),
#'   get_totals(), get_corr(), get_quantiles(), get_ratios(), get_diffs())
#'   provides automated, reproducible extraction of survey statistics without
#'   requiring manual formula-writing or post-processing.
#'
#' @srrstats {EA3.1} All get_*() functions return tidy tibbles with consistent
#'   column naming conventions, enabling direct comparison of estimates across
#'   variables, groups, and designs.
#'
#' @srrstats {EA4.0} All get_*() functions return tibble-based objects;
#'   survey_glm() returns a survey_glm_fit S7 object. Return types do not vary
#'   by input class within the accepted input space.
#'
#' @srrstats {EA4.2} All survey design objects have a print method that
#'   provides a structured summary (design type, sample size, variable
#'   preview). survey_glm_fit has both print and summary methods.
#'
#' @srrstats {EA5.2} The print.survey_glm_fit() and print.survey_glm_summary()
#'   methods format numeric output via format(round(x, digits), nsmall =
#'   digits) rather than relying on default numeric printing.
#'
#' @srrstats {EA5.3} The tibble print method for get_*() output includes
#'   column type abbreviations (<dbl>, <int>, <fct>, etc.), indicating the
#'   class and storage mode of each column.
#'
#' @srrstats {EA6.0} Return values from all get_*() functions are tested for
#'   class, dimensions, column names, column types, and numeric values. See
#'   EA6.0a through EA6.0e.
#'
#' @srrstats {EA6.0a} Tests verify the class of all return objects: get_*()
#'   functions return tibbles; constructors return the correct S7 subclass.
#'
#' @srrstats {EA6.0b} Tests verify the dimensions (number of rows and columns)
#'   of all tabular return objects for representative inputs.
#'
#' @srrstats {EA6.0c} Tests verify that returned tibbles carry the expected
#'   column names (e.g. mean, se, ci_low, ci_high, n for get_means()).
#'
#' @srrstats {EA6.0d} Tests verify column classes within returned tibbles
#'   (e.g. numeric estimates, integer counts, factor group columns).
#'
#' @srrstats {EA6.0e} Numeric return values are tested with
#'   expect_equal(..., tolerance = 1e-10) or equivalent against reference
#'   values from the survey package.
#'
#' @srrstats {RE1.0} survey_glm() requires a formula interface: the first
#'   argument is a standard R formula (e.g. y ~ x1 + x2), and no alternative
#'   matrix interface is provided.
#'
#' @srrstats {RE2.1} survey_glm() accepts an na.action argument (forwarded to
#'   stats::glm()) controlling how missing values in predictor and response
#'   data are handled; default is na.omit.
#'
#' @srrstats {RE3.0} Convergence warnings from the underlying stats::glm() fit
#'   are propagated unchanged to the user, as surveycore does not suppress
#'   them.
#'
#' @srrstats {RE3.2} Convergence thresholds inherit stats::glm.control()
#'   defaults (epsilon = 1e-8, maxit = 25), which are well-established and
#'   documented in ?glm.control.
#'
#' @srrstats {RE3.3} Users may supply a control argument to survey_glm()
#'   (forwarded to stats::glm()), allowing explicit setting of epsilon and
#'   maxit via glm.control().
#'
#' @srrstats {RE4.0} survey_glm() returns a survey_glm_fit S7 object that
#'   stores coefficients, vcov, formula, design, and the underlying glm fit.
#'
#' @srrstats {RE4.2} coef.survey_glm_fit() is implemented and returns the
#'   survey-weighted coefficient vector.
#'
#' @srrstats {RE4.3} confint.survey_glm_fit() is implemented and returns Wald
#'   confidence intervals based on the sandwich variance-covariance matrix.
#'
#' @srrstats {RE4.4} formula.survey_glm_fit() is implemented and returns the
#'   model formula as specified by the user.
#'
#' @srrstats {RE4.5} nobs.survey_glm_fit() is implemented and returns the
#'   number of observations used in the fit.
#'
#' @srrstats {RE4.6} vcov.survey_glm_fit() is implemented and returns the
#'   sandwich variance-covariance matrix of the model parameters.
#'
#' @srrstats {RE4.7} Convergence statistics are available via
#'   summary.survey_glm_fit(), which reports the underlying glm deviance,
#'   degrees of freedom, and AIC.
#'
#' @srrstats {RE4.8} Response variable values are accessible via
#'   model.frame.survey_glm_fit(), which returns the model frame including the
#'   response column.
#'
#' @srrstats {RE4.9} Fitted (modelled) values of the response variable are
#'   returned by fitted.survey_glm_fit().
#'
#' @srrstats {RE4.10} Model residuals are returned by
#'   residuals.survey_glm_fit(), with support for types deviance, pearson,
#'   response, and working.
#'
#' @srrstats {RE4.11} Goodness-of-fit statistics are accessible via
#'   AIC.survey_glm_fit(), BIC.survey_glm_fit(), logLik.survey_glm_fit(), and
#'   deviance.survey_glm_fit().
#'
#' @srrstats {RE4.13} Predictor variable values and metadata are accessible
#'   via model.matrix.survey_glm_fit() and model.frame.survey_glm_fit().
#'
#' @srrstats {RE4.17} print.survey_glm_fit() provides an on-screen summary of
#'   the family/link, formula, design type, and coefficient table with
#'   configurable digit precision.
#'
#' @srrstats {RE4.18} summary.survey_glm_fit() returns a survey_glm_summary
#'   object with coefficient table, deviance residuals, dispersion, and AIC.
#'
#' @srrstats {RE7.3} tests/testthat/test-glm-methods.R demonstrates and tests
#'   the accessor methods coef(), vcov(), confint(), formula(), nobs(),
#'   fitted(), residuals(), AIC(), BIC(), logLik(), and deviance() for
#'   survey_glm_fit objects.
#'
#' @srrstatsTODO {G1.0} *Statistical Software should list at least one primary reference from published academic literature.*
#' @srrstatsTODO {G1.1} *Statistical Software should document whether the algorithm(s) it implements are: The first implementation of a novel algorithm; or The first implementation within R of an algorithm which has previously been implemented in other languages or contexts; or An improvement on other implementations of similar algorithms in R.*
#' @srrstatsTODO {G1.2} *Statistical Software should include a Life Cycle Statement describing current and anticipated future states of development.*
#' @srrstatsTODO {G1.3} *All statistical terminology should be clarified and unambiguously defined.*
#' @srrstatsTODO {G1.4a} *All internal (non-exported) functions should also be documented in standard roxygen2 format, along with a final @noRd tag.*
#' @srrstatsTODO {G2.3b} *Either: use tolower() or equivalent to ensure input of character parameters is not case dependent; or explicitly document that parameters are strictly case-sensitive.*
#' @srrstatsTODO {G2.9} *Software should issue diagnostic messages for type conversion in which information is lost (such as conversion of variables from factor to character; standardisation of variable names; or removal of meta-data).*
#' @srrstatsTODO {G2.11} *Software should ensure that data.frame-like tabular objects which have columns which do not themselves have standard class attributes (typically, vector) are appropriately processed, and do not error without reason.*
#' @srrstatsTODO {G2.12} *Software should ensure that data.frame-like tabular objects which have list columns should ensure that those columns are appropriately pre-processed.*
#' @srrstatsTODO {G2.16} *All functions should also provide options to handle undefined values (e.g., NaN, Inf and -Inf), including potentially ignoring or removing such values.*
#' @srrstatsTODO {G3.0} *Statistical software should never compare floating point numbers for equality. All numeric equality comparisons should either ensure that they are made between integers, or use appropriate tolerances for approximate equality.*
#' @srrstatsTODO {G5.3} *For functions which are expected to return objects containing no missing (NA) or undefined (NaN, Inf) values, the absence of any such values in return objects should be explicitly tested.*
#' @srrstatsTODO {G5.6} *Parameter recovery tests to test that the implementation produces expected results given data with known properties.*
#' @srrstatsTODO {G5.6a} *Parameter recovery tests should generally be expected to succeed within a defined tolerance rather than recovering exact values.*
#' @srrstatsTODO {G5.8} *Edge condition tests to test that these conditions produce expected behaviour.*
#' @srrstatsTODO {G5.8a} *Zero-length data*
#' @srrstatsTODO {G5.8b} *Data of unsupported types (e.g., character or complex numbers in for functions designed only for numeric data)*
#' @srrstatsTODO {G5.8c} *Data with all-NA fields or columns or all identical fields or columns*
#' @srrstatsTODO {G5.8d} *Data outside the scope of the algorithm (for example, data with more fields (columns) than observations (rows) for some regression algorithms)*
#' @srrstatsTODO {G5.9} *Noise susceptibility tests*
#' @srrstatsTODO {G5.9a} *Adding trivial noise (for example, at the scale of .Machine$double.eps) to data does not meaningfully change results*
#' @srrstatsTODO {G5.10} *Extended tests should be included and run under a common framework with other tests but be switched on by flags such as a SURVEYCORE_EXTENDED_TESTS="true" environment variable.*
#' @srrstatsTODO {G5.12} *Any conditions necessary to run extended tests should be described in developer documentation such as CONTRIBUTING.md or tests/README.md.*
#' @srrstatsTODO {EA1.0} *Identify one or more target audiences for whom the software is intended*
#' @srrstatsTODO {EA1.1} *Identify the kinds of data the software is capable of analysing.*
#' @srrstatsTODO {EA1.2} *Identify the kinds of questions the software is intended to help explore.*
#' @srrstatsTODO {EA1.3} *Identify the kinds of data each function is intended to accept as input*
#' @srrstatsTODO {EA4.1} *EDA Software should implement parameters to enable explicit control of numeric precision*
#' @srrstatsTODO {RE1.1} *Regression Software should document how formula interfaces are converted to matrix representations of input data.*
#' @srrstatsTODO {RE1.2} *Regression Software should document expected format (types or classes) for inputting predictor variables.*
#' @srrstatsTODO {RE1.3} *Regression Software which passes or otherwise transforms aspects of input data onto output structures should ensure that those output structures retain all relevant aspects of input data, notably including row and column names.*
#' @srrstatsTODO {RE1.3a} *Where otherwise relevant information is not transferred, this should be explicitly documented.*
#' @srrstatsTODO {RE1.4} *Regression Software should document any assumptions made with regard to input data.*
#' @srrstatsTODO {RE2.0} *Regression Software should document any transformations applied to input data, for example conversion of label-values to factor.*
#' @srrstatsTODO {RE2.2} *Regression Software should provide different options for processing missing values in predictor and response data.*
#' @srrstatsTODO {RE2.4} *Regression Software should implement pre-processing routines to identify whether aspects of input data are perfectly collinear.*
#' @srrstatsTODO {RE2.4a} *Perfect collinearity among predictor variables*
#' @srrstatsTODO {RE2.4b} *Perfect collinearity between independent and dependent variables*
#' @srrstatsTODO {RE3.1} *Enable convergence messages to be optionally suppressed, yet should ensure that the resultant model object nevertheless includes sufficient data to identify lack of convergence.*
#' @srrstatsTODO {RE5.0} *Scaling relationships between sizes of input data and speed of algorithm.*
#' @srrstatsTODO {RE6.0} *Model objects returned by Regression Software should have default plot methods.*
#' @srrstatsTODO {RE6.1} *Where the default plot method is NOT a generic plot method dispatched on the class of return objects, that method dispatch should nevertheless exist.*
#' @srrstatsTODO {RE6.2} *The default plot method should produce a plot of the fitted values of the model, with optional visualisation of confidence intervals or equivalent.*
#' @srrstatsTODO {RE7.0} *Tests with noiseless, exact relationships between predictor (independent) data.*
#' @srrstatsTODO {RE7.1} *Tests with noiseless, exact relationships between predictor (independent) and response (dependent) data.*
#' @srrstatsTODO {RE7.2} Demonstrate that output objects retain aspects of input data such as row or case names (see RE1.3).
#' @noRd
NULL

#' NA_standards
#'
#' Standards deemed not applicable to surveycore, with justifications.
#'
#' @srrstatsNA {G1.5} surveycore does not make quantitative performance claims
#'   in associated academic publications. Correctness is validated against the
#'   survey reference implementation (see G5.4b), not via benchmarks reported
#'   in papers.
#'
#' @srrstatsNA {G2.4a} surveycore does not perform explicit integer conversion.
#'   Where integer columns are required (e.g., PSU IDs), the package errors if
#'   the column is not numeric, rather than silently coercing.
#'
#' @srrstatsNA {G2.4b} Explicit numeric conversion is not applied. The package
#'   validates that weight and FPC columns are already numeric and errors
#'   otherwise.
#'
#' @srrstatsNA {G2.4c} Explicit character conversion is not applied. Column
#'   names are always character (enforced by tidyselect), and no other
#'   character conversions are performed.
#'
#' @srrstatsNA {G2.4e} Conversion from factor is not performed. Factors passed
#'   as outcome variables in analysis functions are accepted as-is; factors
#'   used as design variables are accepted via their underlying values.
#'
#' @srrstatsNA {G2.5} surveycore does not require factor-type inputs for any
#'   parameter. Ordered vs. unordered factor distinction is irrelevant for
#'   survey variance estimation.
#'
#' @srrstatsNA {G2.14c} Imputation of missing values is outside the scope of
#'   surveycore. Survey design objects represent observed sample data, and
#'   imputing design-level variables would invalidate the design specification.
#'
#' @srrstatsNA {G3.1} Survey variance estimation methods (Taylor series
#'   linearization, BRR, jackknife, bootstrap) are fixed by the survey design
#'   type chosen by the user. There is no user-selectable covariance algorithm
#'   within a given design type.
#'
#' @srrstatsNA {G3.1a} Follows from G3.1: there is no user-selectable
#'   covariance algorithm to document; the variance method is the design type
#'   itself.
#'
#' @srrstatsNA {G4.0} surveycore does not enable outputs to be written to
#'   local files. All output is returned as R objects.
#'
#' @srrstatsNA {G5.4a} surveycore does not implement novel statistical
#'   algorithms. It implements established survey variance estimation methods
#'   from the survey statistics literature, with a reference implementation
#'   available in the survey package.
#'
#' @srrstatsNA {G5.4c} The reference implementation (survey package by Lumley)
#'   is directly available in R and used in correctness tests. Published paper
#'   outputs are not needed as a substitute comparison source.
#'
#' @srrstatsNA {G5.6b} Survey variance algorithms are deterministic: no random
#'   component is introduced by surveycore's estimation routines. Multiple
#'   random seeds for parameter recovery tests are therefore not applicable.
#'
#' @srrstatsNA {G5.7} Algorithm performance (scaling) is inherited entirely
#'   from the vendored survey package variance routines. surveycore adds no
#'   novel algorithmic complexity beyond S7 class overhead.
#'
#' @srrstatsNA {G5.9b} Running under different random seeds does not apply:
#'   all variance estimation algorithms in surveycore are deterministic given
#'   the same design and data.
#'
#' @srrstatsNA {G5.11} Extended tests do not require downloads of large
#'   external datasets. The standard test datasets (nhanes_2017, acs_pums_wy)
#'   are bundled within the package.
#'
#' @srrstatsNA {G5.11a} Follows from G5.11: no external data downloads are
#'   required, so skip-on-download-failure logic is not needed.
#'
#' @srrstatsNA {EA2.0} surveycore does not implement or rely on an
#'   index-column system for table operations. Survey design objects use an S7
#'   class that stores the full data frame; row identity is tracked by
#'   position, consistent with how the survey package and base R modelling
#'   functions treat data frames.
#'
#' @srrstatsNA {EA2.1} Follows from EA2.0: no index columns are used.
#'
#' @srrstatsNA {EA2.2} Follows from EA2.0: no index columns are used.
#'
#' @srrstatsNA {EA2.2a} Follows from EA2.0: no index columns are used.
#'
#' @srrstatsNA {EA2.2b} Follows from EA2.0: no index columns are used.
#'
#' @srrstatsNA {EA2.3} surveycore does not perform table join operations. All
#'   analysis is performed on the single data frame stored in the survey design
#'   object.
#'
#' @srrstatsNA {EA2.5} Follows from EA2.0: no index columns are used.
#'
#' @srrstatsNA {EA5.0} surveycore produces no graphical output. All results are
#'   returned as tibbles or model objects.
#'
#' @srrstatsNA {EA5.0a} Follows from EA5.0: no graphical output.
#'
#' @srrstatsNA {EA5.0b} Follows from EA5.0: no graphical output.
#'
#' @srrstatsNA {EA5.1} Follows from EA5.0: no graphical output.
#'
#' @srrstatsNA {EA5.4} Follows from EA5.0: no graphical output.
#'
#' @srrstatsNA {EA5.5} Follows from EA5.0: no graphical output.
#'
#' @srrstatsNA {EA5.6} Follows from EA5.0: no graphical output and no bundled
#'   visualisation libraries.
#'
#' @srrstatsNA {EA6.1} Follows from EA5.0: no graphical output to test.
#'
#' @srrstatsNA {RE2.3} Centring and offsetting of predictors are not
#'   surveycore concerns. Offset terms may be specified in the formula via
#'   offset(). Automatic centring would alter the interpretation of
#'   survey-weighted regression coefficients and is not standard practice.
#'
#' @srrstatsNA {RE4.1} survey_glm() always fits the model immediately;
#'   generating a model specification without fitting is not supported.
#'   Lazy fitting would complicate the design-based variance calculation.
#'
#' @srrstatsNA {RE4.12} No explicit input transformation functions are applied
#'   beyond what the formula specifies. Link function transformations are
#'   handled by the family argument (via standard R family objects) and are not
#'   surveycore-owned functions requiring inverse transforms.
#'
#' @srrstatsNA {RE4.14} surveycore is not a forecasting package. Prediction
#'   generates fitted values for the observed design frame; out-of-sample
#'   extrapolation errors are not relevant.
#'
#' @srrstatsNA {RE4.15} Follows from RE4.14: no forecast horizons.
#'
#' @srrstatsNA {RE4.16} Survey regression estimates population parameters for
#'   the sampled population's group structure; submitting entirely new
#'   categorical groups not present in the design frame is outside the scope
#'   of design-based inference.
#'
#' @srrstatsNA {RE6.3} Follows from RE4.14: no forecast vs. modelled
#'   distinction exists in surveycore outputs.
#'
#' @srrstatsNA {RE7.0a} survey_glm() does not reject noiseless (perfectly
#'   collinear) input data as an error; such data is handled by stats::glm(),
#'   which drops aliased columns.
#'
#' @srrstatsNA {RE7.1a} Speed comparison between noiseless and noisy fits is
#'   not applicable: surveycore delegates all IRLS fitting to stats::glm(),
#'   adding only sandwich variance computation whose cost does not depend on
#'   data noisiness.
#'
#' @srrstatsNA {RE7.4} Follows from RE4.14: no forecast error tests.
#' @noRd
NULL
