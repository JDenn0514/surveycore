# R/methods-conversion.R
#
# Conversion functions between surveycore S7 objects and the survey/srvyr
# package design objects.
#
# Step 11 (feature/conversion-to-survey):   as_svydesign(), as_tbl_svy()
# Step 12 (feature/conversion-from-survey): from_svydesign(), from_tbl_svy()
#
# Both directions require the external package to be installed.
# Errors use surveycore_error_pkg_not_installed when the package is absent.

# ── Internal helpers ──────────────────────────────────────────────────────────

# Build a one-sided formula from a character vector of column names.
# Returns NULL when vars is NULL or length-0.
# Examples:
#   c("psu", "ssu") → ~ psu + ssu
#   "strata"        → ~ strata
#   NULL            → NULL
#' @noRd
.to_formula <- function(vars) {
  if (is.null(vars) || length(vars) == 0L) {
    return(NULL)
  }
  stats::reformulate(vars)
}


# ── as_svydesign ──────────────────────────────────────────────────────────────

#' Convert a surveycore Design Object to a survey Package Design
#'
#' Converts a `survey_taylor`, `survey_replicate`, `survey_twophase`, or
#' `survey_nonprob` object to the corresponding `survey` package object:
#' `svydesign`, `svrepdesign`, or `twophase`. Useful for accessing `survey`
#' package estimation functions or for round-trip testing.
#'
#' Metadata (variable labels, value labels) is NOT carried over — the `survey`
#' package has no metadata system.
#'
#' @param x A `survey_taylor`, `survey_replicate`, `survey_twophase`, or
#'   `survey_nonprob` object.
#' @return A `survey::svydesign`, `survey::svrepdesign`, or `survey::twophase`
#'   object. The returned class follows the input class, and for a
#'   `survey_nonprob` design it follows the design's shape: a design that names
#'   replicate weights returns a `svrepdesign`, and a design that names none
#'   returns a `svydesign`. Value labels are not carried into the returned
#'   object — the `survey` package has no metadata system. To read the data
#'   back with `haven`-style classes rebuilt, use
#'   `survey_data(x, haven_class = TRUE)` on the surveycore design instead.
#'
#' @section A non-probability design:
#' A `survey_nonprob` design converts on the shape of its weights. A design
#' that names replicate weights becomes a `svrepdesign` and keeps every
#' replicate column, so the converted object computes the replicate variance
#' surveycore computes. A design that names none becomes a `svydesign` with
#' `ids = ~1`, and the call warns: the standard errors then use a simple random
#' sample approximation that charges nothing for calibration uncertainty, and
#' the returned object records nothing about it. See [as_survey_nonprob()] for
#' the two variance modes.
#'
#' The conversion drops the design's calibration provenance and its reference
#' sample, and the round trip does not return a non-probability design.
#' `from_svydesign()` on a converted design returns a `survey_taylor` or a
#' `survey_replicate` object, because a `survey` object records nothing that
#' marks a sample as non-probability. The rebuilt design reports design-based
#' standard errors and no longer warns, on data that has not changed. Keep the
#' original object when you need any of that.
#'
#' @section Degrees of freedom on a converted design:
#' surveycore reports `Inf` degrees of freedom for a `survey_nonprob` design,
#' and the `survey` package computes a finite number from the converted object.
#' A 40-row design with no replicate weights converts to 39, and the same
#' design with 8 replicate weight columns converts to 7. Both counts carry a
#' qualifier. Without replicate weights the `survey` package counts the rows
#' whose weight is not zero and subtracts 1, so the same design with one
#' zero-weight row converts to 38. With replicate weights it takes the
#' numerical rank of the matrix of replicate weights and subtracts 1, so the
#' figure is `R - 1` at full column rank and lower otherwise.
#'
#' The difference reaches a result only when the caller asks for it. A default
#' `confint()` call on a `svystat` or a `svrepstat` uses `df = Inf`, so the
#' default interval from `survey::svymean()` matches surveycore's. The gap
#' appears when the caller passes `degf(design)`, or calls a `survey` function
#' that reads `degf()` itself, such as `svyglm()` or `svyttest()`. See
#' `vignette("surveycore-vs-survey")` for the two counting rules in the source.
#'
#' @section A filtered design's domain:
#' The converted object represents the full stored sample and not the active
#' domain. `filter()` from surveytidy keeps every row and marks domain
#' membership in a logical column named by `SURVEYCORE_DOMAIN_COL`, which holds
#' `"..surveycore_domain.."`. `as_svydesign()` passes that column through as
#' ordinary data and never installs it as the converted object's restriction,
#' so `survey::svymean()` on the result answers for every row. The point
#' estimate differs from the domain estimate, not the standard error alone.
#'
#' A caller who wants the domain has to subset the returned object on that
#' column: `subset(converted, ..surveycore_domain..)` does it, and reproduces
#' `get_means()` on the filtered design exactly. Calling `get_means()` on the
#' filtered design needs no subset at all.
#'
#' @examples
#' d <- as_survey(
#'   nhanes_2017,
#'   ids = sdmvpsu,
#'   weights = wtint2yr,
#'   strata = sdmvstra,
#'   nest = TRUE
#' )
#' if (requireNamespace("survey", quietly = TRUE)) {
#'   sv <- as_svydesign(d)
#'   survey::svymean(~ridageyr, sv, na.rm = TRUE)
#' }
#' @seealso [from_svydesign()] to convert back from a `survey` design
#' @family conversion
#' @export
as_svydesign <- function(x) {
  if (!requireNamespace("survey", quietly = TRUE)) {
    # nocov start
    cli::cli_abort(
      c(
        "x" = "{.pkg survey} must be installed to use {.fn as_svydesign}.",
        "v" = "Install it with {.code install.packages(\"survey\")}."
      ),
      class = "surveycore_error_pkg_not_installed"
    )
    # nocov end
  }

  if (S7::S7_inherits(x, survey_taylor)) {
    .as_svydesign_taylor(x)
  } else if (S7::S7_inherits(x, survey_replicate)) {
    .as_svydesign_replicate(x)
  } else if (S7::S7_inherits(x, survey_twophase)) {
    .as_svydesign_twophase(x)
  } else if (S7::S7_inherits(x, survey_nonprob)) {
    # Route on the shape of the weights, not on the class. This is the key
    # .mean_cell() uses in R/analysis-means-helpers.R to pick the estimator
    # for a survey_nonprob design, so the converted object carries the
    # estimator surveycore itself uses. Sending the replicate shape down the
    # Taylor route answers a standard error 28 times too large on a measured
    # design.
    #
    # The predicate and the first bullet below are each written out in full
    # here, and each is the eighth in-place copy in R/. Issue #246 carries the
    # consolidation of all eight; extracting a helper for one site while seven
    # keep the inline form would read as consolidation without being it.
    if (!is.null(x@variables$repweights)) {
      .as_svydesign_replicate(x)
    } else {
      cli::cli_warn(
        c(
          "!" = paste0(
            "{.cls survey_nonprob} object has no bootstrap replicate ",
            "weights. Standard errors use an SRS approximation that ",
            "underestimates calibration uncertainty."
          ),
          "i" = paste0(
            "The returned {.pkg survey} object records nothing about the ",
            "approximation, so no later call warns again."
          ),
          "v" = paste0(
            "Run {.fn surveywts::create_bootstrap_weights} on this design, ",
            "then convert the design it returns."
          )
        ),
        class = "surveycore_warning_nonprob_srs_conversion"
      )
      .as_svydesign_taylor(x)
    }
  } else {
    cli::cli_abort(
      c(
        "x" = "{.arg x} must be a survey design object.",
        "i" = "Got {.cls {class(x)[[1L]]}}."
      ),
      class = "surveycore_error_not_survey_object"
    )
  }
}


# survey_taylor → survey::svydesign
#' @noRd
.as_svydesign_taylor <- function(x) {
  ids_var <- x@variables$ids
  strata_var <- x@variables$strata
  weights_var <- x@variables$weights
  fpc_var <- x@variables$fpc

  ids_formula <- if (!is.null(ids_var) && length(ids_var) > 0L) {
    .to_formula(ids_var)
  } else {
    ~1
  }

  # Inline the formulas into the call rather than passing the variables that
  # hold them. survey::svydesign() stores its own call, and R records the
  # unevaluated argument expressions there. Passing `ids = ids_formula` records
  # the symbol `ids_formula`, and passing `strata = .to_formula(strata_var)`
  # records that call. from_svydesign() reads those back with all.vars(), which
  # then yields "ids_formula" and "strata_var" instead of the column names, and
  # the design fails to rebuild. bquote() substitutes the formula objects
  # themselves, so the stored call names real columns and the round trip works.
  # `data` is left as an expression on purpose: it is not read back, and
  # inlining a whole data frame into a stored call is wasteful.
  eval(bquote(survey::svydesign(
    ids = .(ids_formula),
    strata = .(.to_formula(strata_var)),
    weights = .(.to_formula(weights_var)),
    fpc = .(.to_formula(fpc_var)),
    data = x@data,
    nest = .(isTRUE(x@variables$nest))
  )))
}


# survey_replicate → survey::svrepdesign
#' @noRd
.as_svydesign_replicate <- function(x) {
  wts_var <- x@variables$weights
  rep_vars <- x@variables$repweights
  fpc_var <- x@variables$fpc

  # Refuse a design that names no replicate column, before any other work.
  # survey::svrepdesign() with a zero-column replicate matrix fails with
  # 'missing value where TRUE/FALSE needed' from inside its own
  # combined.weights heuristic — a bare error with no class. The state is
  # reachable: .validate_data_frame() runs only in as_survey_replicate(), and
  # the exported survey_replicate() constructor takes an untyped variables
  # list. An empty replicate design supports no estimate and no variance, so
  # the route refuses it here.
  if (length(rep_vars) == 0L) {
    cli::cli_abort(
      c(
        "x" = "The design names no replicate weight column.",
        "i" = paste0(
          "{.fn survey::svrepdesign} needs at least one replicate weight ",
          "column, and fails with an untyped error without one."
        ),
        "v" = paste0(
          "Rebuild the design with {.fn as_survey_replicate} and name its ",
          "replicate weight columns."
        )
      ),
      class = "surveycore_error_repweights_empty"
    )
  }

  # BRR and Fay do not use a separate scale factor — survey::svrepdesign()
  # warns if scale is passed for those types.
  scale_arg <- if (isTRUE(x@variables$type %in% c("BRR", "Fay"))) {
    NULL
  } else {
    x@variables$scale
  }

  # Recover Fay's shrinkage factor from the recorded scale. This is required,
  # not an improvement: svrepdesign.default() holds
  #   if (type == "Fay" && is.null(rho))
  #     stop("With type='Fay' you must supply the correct rho")
  # so without rho the export route fails outright for a Fay design.
  #
  # The recovery inverts survey's own formula. survey computes a Fay design's
  # scale as 1 / (n_rep * (1 - rho)^2), and the import route stores that
  # value in @variables$scale, so solving for rho returns the shrinkage
  # factor the replicates were built with. Measured: a design built with
  # fay.rho = 0.3 recovers 0.3 exactly and rebuilds with the source's own
  # scale.
  #
  # The scale argument above stays NULL for "Fay". survey recomputes the
  # scale from this rho, and this rho came from the stored scale, so the
  # rebuilt scale equals the stored one. Passing rho alone reproduces it.
  rho_arg <- NULL
  if (isTRUE(x@variables$type == "Fay")) {
    fay_scale <- x@variables$scale

    # The binding is a character string on every branch, including the NULL
    # branch, so the message renders without a special case.
    scale_txt <- if (is.null(fay_scale)) {
      "none"
    } else {
      paste(format(fay_scale), collapse = ", ")
    }

    scale_usable <- length(fay_scale) == 1L &&
      is.numeric(fay_scale) &&
      is.finite(fay_scale) &&
      fay_scale > 0
    rho_arg <- if (scale_usable) {
      1 - sqrt(1 / (fay_scale * length(rep_vars)))
    } else {
      NA_real_
    }

    # Both arms are reachable. A scale whose product with the replicate count
    # is below 1 puts the recovered rho below 0, and as_survey_replicate()
    # accepts any numeric scale. A missing scale comes from the exported
    # survey_replicate() constructor, whose variables list is untyped and
    # whose validator checks neither scale nor type;
    # as_survey_replicate(type = "Fay") fills 1 / n_rep, which recovers
    # rho = 0 — legal, and the BRR case.
    if (!scale_usable || is.na(rho_arg) || rho_arg < 0 || rho_arg >= 1) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.fn as_svydesign} cannot recover the {.val Fay} shrinkage ",
            "factor for this design."
          ),
          "i" = paste0(
            "{.fn survey::svrepdesign} requires {.arg rho} for ",
            "{.code type = \"Fay\"}, and surveycore derives it from the ",
            "recorded scale."
          ),
          "i" = paste0(
            "The recorded scale is {.val {scale_txt}} and yields no value ",
            "in {.code [0, 1)}."
          ),
          "v" = paste0(
            "Rebuild the design with {.fn as_survey_replicate} and pass the ",
            "{.arg scale} the {.val Fay} replicates were built with."
          )
        ),
        class = "surveycore_error_fay_rho_unrecoverable"
      )
    }
  }

  # Drop the finite population correction, and say so. surveycore records the
  # FPC as a column of @data, one value per row; survey::svrepdesign() reads
  # it as one multiplier per replicate and checks length(fpc) against
  # length(rscales), which is R. The two lengths agree only when n equals R,
  # so passing the column fails with survey's own 'fpc is wrong length' for
  # every other design, and as_svydesign(x) takes only x, so the caller has
  # no way around it. Reshaping the column to length R would give the right
  # shape and the wrong quantity.
  #
  # surveycore's replicate variance never reads the FPC — R/variance-
  # replicate.R holds no reference to it — so the drop changes no surveycore
  # number, while a translated FPC would scale every replicate scale and
  # return standard errors surveycore itself does not produce. survey's own
  # as.svrepdesign() warns and drops for the same reason.
  #
  # The FPC stays on x: @variables$fpc, @variables$fpctype and the column in
  # @data are all untouched, and a second call warns again.
  if (!is.null(fpc_var)) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "{.fn as_svydesign} dropped the finite population correction ",
          "column {.field {fpc_var}}."
        ),
        "i" = paste0(
          "{.fn survey::svrepdesign} takes one FPC value per replicate, and ",
          "a {.cls survey_replicate} design records one value per row."
        ),
        "i" = paste0(
          "surveycore's replicate variance does not read the FPC, so the ",
          "returned design reproduces surveycore's own standard errors."
        ),
        "v" = paste0(
          "Call {.fn survey::svrepdesign} directly with {.arg fpc} to apply ",
          "a per-replicate correction."
        )
      ),
      class = "surveycore_warning_replicate_fpc_dropped"
    )
  }

  survey::svrepdesign(
    weights = x@data[[wts_var]],
    repweights = x@data[, rep_vars, drop = FALSE],
    type = x@variables$type,
    scale = scale_arg,
    rho = rho_arg,
    rscales = x@variables$rscales,
    mse = isTRUE(x@variables$mse),
    data = x@data
  )
}


# survey_twophase → survey::twophase
#' @noRd
.as_svydesign_twophase <- function(x) {
  p1 <- x@variables$phase1
  p2 <- x@variables$phase2
  subset_var <- x@variables$subset
  method <- if (!is.null(x@variables$method)) x@variables$method else "full"

  # Phase 1 formulas
  p1_id <- if (!is.null(p1$ids) && length(p1$ids) > 0L) {
    .to_formula(p1$ids)
  } else {
    ~1
  }
  p1_strata <- .to_formula(p1$strata)
  p1_weights <- .to_formula(p1$weights)
  p1_fpc <- .to_formula(p1$fpc)

  # Phase 2 formulas (usually NULL or ~1 for simple cases)
  p2_id <- if (!is.null(p2) && !is.null(p2$ids) && length(p2$ids) > 0L) {
    .to_formula(p2$ids)
  } else {
    ~1
  }
  p2_strata <- if (!is.null(p2)) .to_formula(p2$strata) else NULL
  p2_fpc <- if (!is.null(p2)) .to_formula(p2$fpc) else NULL

  # method="full" derives phase 2 weights from the phase 1 design and rejects
  # an explicit weights argument.  For "simple" and "approx" we pass phase 1
  # weights so survey can compute the probability-weighted estimates.
  weights_arg <- if (method == "full") NULL else list(p1_weights, NULL)

  survey::twophase(
    id = list(p1_id, p2_id),
    strata = list(p1_strata, p2_strata),
    weights = weights_arg,
    fpc = list(p1_fpc, p2_fpc),
    data = x@data,
    subset = .to_formula(subset_var),
    method = method
  )
}


# ── as_tbl_svy ────────────────────────────────────────────────────────────────

#' Convert a surveycore Design Object to an srvyr tbl_svy
#'
#' Converts a surveycore design object to an `srvyr` `tbl_svy` by first
#' converting to a `survey` design via [as_svydesign()] and then wrapping
#' with `srvyr::as_survey()`. Requires both `survey` and `srvyr`.
#'
#' Metadata (variable labels, value labels) is NOT carried over.
#'
#' @param x A `survey_taylor`, `survey_replicate`, `survey_twophase`, or
#'   `survey_nonprob` object.
#' @return A `srvyr::tbl_svy` object. Value labels are not carried into the
#'   returned object — the `survey` package has no metadata system. To read the
#'   data back with `haven`-style classes rebuilt, use
#'   `survey_data(x, haven_class = TRUE)` on the surveycore design instead.
#'
#' @examples
#' d <- as_survey(
#'   nhanes_2017,
#'   ids = sdmvpsu,
#'   weights = wtint2yr,
#'   strata = sdmvstra,
#'   nest = TRUE
#' )
#' if (
#'   requireNamespace("survey", quietly = TRUE) &&
#'     requireNamespace("srvyr", quietly = TRUE)
#' ) {
#'   ts <- as_tbl_svy(d)
#' }
#' @seealso [from_tbl_svy()] to convert back from a `tbl_svy` object
#' @family conversion
#' @export
as_tbl_svy <- function(x) {
  if (!requireNamespace("survey", quietly = TRUE)) {
    # nocov start
    cli::cli_abort(
      c(
        "x" = "{.pkg survey} must be installed to use {.fn as_tbl_svy}.",
        "v" = "Install it with {.code install.packages(\"survey\")}."
      ),
      class = "surveycore_error_pkg_not_installed"
    )
    # nocov end
  }
  if (!requireNamespace("srvyr", quietly = TRUE)) {
    # nocov start
    cli::cli_abort(
      c(
        "x" = "{.pkg srvyr} must be installed to use {.fn as_tbl_svy}.",
        "v" = "Install it with {.code install.packages(\"srvyr\")}."
      ),
      class = "surveycore_error_pkg_not_installed"
    )
    # nocov end
  }

  if (!S7::S7_inherits(x, survey_base)) {
    cli::cli_abort(
      c(
        "x" = "{.arg x} must be a survey design object.",
        "i" = "Got {.cls {class(x)[[1L]]}}."
      ),
      class = "surveycore_error_not_survey_object"
    )
  }

  srvyr::as_survey(as_svydesign(x))
}


# ── Internal helpers for from_svydesign ───────────────────────────────────────

# Extract variable names from a formula or call expression.
# Returns NULL when f is NULL, when f is ~1 (no variables), or on error.
# Examples:
#   ~wt          → "wt"
#   ~psu + ssu   → c("psu", "ssu")
#   ~1           → NULL
#   NULL         → NULL
#' @noRd
.vars_from_formula <- function(f) {
  if (is.null(f)) {
    return(NULL)
  }
  vars <- tryCatch(all.vars(f), error = function(e) character(0L))
  if (length(vars) == 0L) NULL else vars
}


# Find the first column in data whose numeric values exactly match vals.
# Returns the column name, or NULL if no matching column exists.
# Used to recover weight/subset column names from stored vectors in survey
# design objects that do not preserve the original column name.
#' @noRd
.find_col_by_value <- function(data, vals) {
  if (is.null(vals) || length(vals) == 0L) {
    return(NULL)
  } # nocov — callers always pass non-NULL
  for (nm in names(data)) {
    col <- data[[nm]]
    if (
      (is.numeric(col) || is.logical(col)) &&
        length(col) == length(vals) &&
        isTRUE(all.equal(
          as.numeric(col),
          as.numeric(vals),
          check.attributes = FALSE
        ))
    ) {
      return(nm)
    }
  }
  NULL
}


# ── from_svydesign ────────────────────────────────────────────────────────────

#' Convert a survey Package Design to a surveycore Design Object
#'
#' Converts a `survey` package design object (`svydesign`, `svrepdesign`, or
#' `twophase`) to the corresponding surveycore S7 object. The data and the
#' design variables are preserved; metadata (variable labels, value labels) is
#' not — the `survey` package has no metadata system.
#'
#' Weight column names are recovered from the design call when available. When
#' the call does not contain a formula (e.g., weights were passed as a vector),
#' the weight column is identified by matching the stored weight values against
#' columns in the data. If no match is found, a `..surveycore_wt..` column is
#' added.
#'
#' @section Replicate weights:
#'
#' A `svrepdesign` object stores either finished replicate weights or
#' replication factors, and reports which through its `combined.weights`
#' field. On a design that reports replication factors the conversion
#' transforms the replicate weights rather than preserving them: it multiplies
#' each replicate column by the base weight, so the returned design always
#' carries finished weights.
#'
#' When the source design does not name its replicate columns — the case for
#' every design that [survey::as.svrepdesign()] builds — the conversion writes
#' a generated block into the data, one column per replicate, named on the
#' same `..surveycore_wt..` pattern as the manufactured weight column above:
#' `..surveycore_repwt_1..`, `..surveycore_repwt_2..`, and so on, with the
#' index zero-padded to the width of the replicate count. When the source does
#' name its replicate columns, those names pass through unchanged.
#'
#' Either way, the `repweights` design variable of the returned object names
#' those columns, in replicate order.
#'
#' @param x A `survey::svydesign`, `survey::svrepdesign`, `survey::twophase`,
#'   `survey::twophase2`, or `srvyr::tbl_svy` object. Both `"twophase"` and
#'   `"twophase2"` classes from the `survey` package are dispatched to the
#'   two-phase conversion path.
#' @return A `survey_taylor`, `survey_replicate`, or `survey_twophase` object.
#'
#' @examples
#' if (requireNamespace("survey", quietly = TRUE)) {
#'   sv <- survey::svydesign(
#'     ids = ~sdmvpsu,
#'     weights = ~wtint2yr,
#'     strata = ~sdmvstra,
#'     data = nhanes_2017,
#'     nest = TRUE
#'   )
#'   d <- from_svydesign(sv)
#'   survey_data(d)
#' }
#' @seealso [as_svydesign()] to convert in the other direction
#' @family conversion
#' @export
from_svydesign <- function(x) {
  if (!requireNamespace("survey", quietly = TRUE)) {
    # nocov start
    cli::cli_abort(
      c(
        "x" = "{.pkg survey} must be installed to use {.fn from_svydesign}.",
        "v" = "Install it with {.code install.packages(\"survey\")}."
      ),
      class = "surveycore_error_pkg_not_installed"
    )
    # nocov end
  }

  if (inherits(x, "twophase2") || inherits(x, "twophase")) {
    .from_svydesign_twophase(x)
  } else if (inherits(x, "svyrep.design")) {
    .from_svydesign_replicate(x)
  } else if (inherits(x, "survey.design")) {
    .from_svydesign_taylor(x)
  } else {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg x} must be a {.pkg survey} design object ",
          "({.cls svydesign}, {.cls svyrep.design}, or {.cls twophase})."
        ),
        "i" = "Got {.cls {class(x)[[1L]]}}."
      ),
      class = "surveycore_error_not_survey_design"
    )
  }
}


# svydesign / tbl_svy → survey_taylor
#' @noRd
.from_svydesign_taylor <- function(x) {
  data <- .strip_labelled_columns(as.data.frame(x$variables))

  # tbl_svy stores its call as srvyr's quoteless_text (not a language object).
  # Use tryCatch so atomic / non-language calls degrade to NULL gracefully.
  .call_vars <- function(nm) {
    tryCatch(.vars_from_formula(x$call[[nm]]), error = function(e) NULL)
  }

  ids_var <- .call_vars("ids")
  strata_var <- .call_vars("strata")
  fpc_raw <- .call_vars("fpc")
  fpc_var <- if (!is.null(fpc_raw)) fpc_raw[[1L]] else NULL
  nest <- tryCatch(isTRUE(x$call$nest), error = function(e) FALSE)

  # Weight column: try the call formula first, then value-matching.
  weights_var <- .call_vars("weights")
  if (is.null(weights_var)) {
    weights_var <- .find_col_by_value(data, 1 / x$prob)
  }
  if (is.null(weights_var)) {
    weights_var <- "..surveycore_wt.."
    data[[weights_var]] <- 1 / x$prob
  }

  variables <- list(
    ids = ids_var,
    weights = weights_var,
    strata = strata_var,
    fpc = fpc_var,
    nest = nest,
    probs_provided = FALSE,
    visible_vars = NULL
  )

  survey_taylor(
    data = data,
    variables = variables,
    metadata = .extract_haven_metadata(data)
  )
}


# Build the generated names for a block of replicate weight columns.
# Zero-pads the index to the width of n_rep so the names sort in replicate
# order. Follows the ..surveycore_wt.. convention: a manufactured column must
# not collide with a user column.
#   .repwt_col_names(3L)  → "..surveycore_repwt_1..", ..., "..surveycore_repwt_3.."
#   .repwt_col_names(20L) → "..surveycore_repwt_01..", ..., "..surveycore_repwt_20.."
#' @noRd
.repwt_col_names <- function(n_rep) {
  idx <- formatC(
    seq_len(n_rep),
    width = nchar(as.character(n_rep)),
    flag = "0"
  )
  paste0("..surveycore_repwt_", idx, "..")
}


# svyrep.design → survey_replicate
#' @noRd
.from_svydesign_replicate <- function(x) {
  # Check the replicate type first, before any column work. There is no
  # point expanding a matrix for a design the route refuses.
  # survey::as.svrepdesign() accepts "subbootstrap" and "mrbbootstrap" and
  # stores the literal string, and the survey_replicate validator does not
  # check type, so without this step the route stores such a value and the
  # export route then fails with survey's own bare
  # 'arg' should be one of "BRR", "Fay", ... .
  accepted <- c(
    "JK1",
    "JK2",
    "JKn",
    "BRR",
    "Fay",
    "bootstrap",
    "ACS",
    "successive-difference",
    "other"
  )
  rep_type <- x$type
  if (!isTRUE(rep_type %in% accepted)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "The {.pkg survey} design records replicate type {.val {rep_type}}, ",
          "which surveycore does not accept."
        ),
        "i" = "surveycore accepts {.val {accepted}}.",
        "v" = paste0(
          "Rebuild the design with {.fn survey::as.svrepdesign} and an ",
          "accepted type, then convert it again."
        )
      ),
      class = "surveycore_error_replicate_type_unsupported"
    )
  }

  data <- .strip_labelled_columns(as.data.frame(x$variables))

  # A zero-row svyrep.design is reachable: a zero-row survey.design through
  # survey::as.svrepdesign(type = "JK1") builds and reports nrow(variables)
  # 0, a 0 x 0 replicate matrix and length(pweights) 0. The row-count check
  # in .validate_data_frame() runs only in as_survey_replicate(), and this
  # route does not call it. An empty replicate design supports no estimate
  # and no variance, so the route refuses it here.
  if (nrow(data) == 0L) {
    cli::cli_abort(
      c(
        "x" = "The {.pkg survey} design has no rows.",
        "i" = paste0(
          "{.fn from_svydesign} needs at least one row to build a ",
          "{.cls survey_replicate} design."
        ),
        "v" = "Convert a design built on data with at least one row."
      ),
      class = "surveycore_error_empty_data"
    )
  }

  # Expand the replicate weights to a full n x R matrix. as.matrix() handles
  # both storage forms: a plain matrix, and the repweights_compressed list
  # that survey's default compress = TRUE produces. No survey:: prefix — the
  # method is unexported, and the requireNamespace() guard in
  # from_svydesign() loads survey's namespace, which registers it for
  # dispatch.
  #
  # The unclass() is load-bearing, not decoration. survey::svrepdesign() puts
  # the class "repweights" on the object it stores and as.matrix() keeps it.
  # With that class in place, as.data.frame() collapses the whole matrix into
  # one column, and arithmetic propagates the class.
  rep_mat <- unclass(as.matrix(x$repweights))
  n_rep <- ncol(rep_mat)

  # Resolve the replicate column names. survey::as.svrepdesign() names no
  # column of the matrix it builds, for any replicate type and either
  # compress value, so generate a block on that branch. Otherwise survey's
  # own names pass through unchanged.
  rep_cols <- colnames(x$repweights)
  names_generated <- length(rep_cols) == 0L
  if (names_generated) {
    rep_cols <- .repwt_col_names(n_rep)
  }

  # Check the names. A usable name set has exactly n_rep entries, and every
  # entry is non-NA, non-empty and distinct. Exactly two states reach this
  # check: a partly named matrix, where colnames() holds one or more empty
  # strings, and a matrix with a repeated name, which would collapse two
  # replicates into one column. A zero-length colnames() does not reach it —
  # the branch above generates n_rep distinct non-empty names.
  usable <- rep_cols[!is.na(rep_cols) & nzchar(rep_cols)]
  n_names <- length(unique(usable))
  if (n_names != n_rep) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "The {.pkg survey} design has {n_rep} replicate weight column{?s} ",
          "but {n_names} usable column name{?s}."
        ),
        "i" = paste0(
          "{.fn from_svydesign} needs one name per replicate column to store ",
          "the weights in the design data."
        ),
        "v" = paste0(
          "Rebuild the design with {.fn survey::svrepdesign} and pass ",
          "{.arg repweights} as a data frame with one named column per ",
          "replicate."
        )
      ),
      class = "surveycore_error_repweights_names_lost"
    )
  }

  # Check for a collision, on the generated branch only. Survey's own names
  # are meant to name existing columns, and step 11 overwrites them. A
  # generated name that already names a column is different: the route would
  # overwrite a user column whose values it never reads.
  if (names_generated) {
    collisions <- rep_cols[rep_cols %in% names(data)]
    n_collisions <- length(collisions)
    if (n_collisions > 0L) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.fn from_svydesign} cannot store the replicate weights under ",
            "generated names."
          ),
          "i" = paste0(
            "The design data already {cli::qty(n_collisions)}",
            "{?has a column/has columns} named {.field {collisions}}."
          ),
          "i" = paste0(
            "A generated name reaches the data when an earlier conversion ",
            "left its replicate columns there."
          ),
          "v" = paste0(
            "Rename the conflicting {cli::qty(n_collisions)} column{?s} in the ",
            "design data, then convert again."
          )
        ),
        class = "surveycore_error_repwt_name_collision"
      )
    }
  }

  # Fold the base weight in. When the source declares combined.weights FALSE
  # the matrix holds replication factors, not finished weights: every type
  # defines a replicate weight as p[i] * R[i, r] on that branch, and survey
  # performs the same multiplication itself, on demand, in the analysis
  # branch of weights.svyrep.design. Doing it once here is correct for all
  # nine replicate types, because combined.weights is a design-level flag
  # and not a per-type one.
  #
  # The product is row-wise: x$pweights has length n and recycles down each
  # column, so element [i, r] becomes R[i, r] * p[i]. Zeros, negatives and
  # NA all pass through it untouched.
  #
  # scale, rscales, mse and type need no compensating change. They are
  # structural constants of the variance formula and depend on the replicate
  # count and the design type, not on the units of the weight column.
  #
  # Neither branch raises a condition. Both weight forms describe the same
  # design and the product is exact, so nothing is lost and the caller has
  # nothing to act on. survey::as.svrepdesign() reports the factor form for
  # every replicate type, so a condition here would fire on nearly every
  # real conversion.
  if (!isTRUE(x$combined.weights)) {
    rep_mat <- rep_mat * x$pweights
  }

  # Weight column: find by matching pweights to data columns. This search
  # runs before the replicate block is written. It takes the first numeric
  # column whose values equal x$pweights, and a replicate that deletes
  # nothing and scales nothing holds exactly those values.
  weights_var <- .find_col_by_value(data, x$pweights)
  if (is.null(weights_var)) {
    weights_var <- "..surveycore_wt.."
    data[[weights_var]] <- x$pweights
  }

  # Write one column per replicate, on every conversion, with no branch.
  # survey::svrepdesign() cross-checks `variables` against `repweights` for
  # neither name nor value, so a name in colnames(x$repweights) can also name
  # a column of x$variables that holds unrelated numbers. The replicate
  # matrix is the source of truth, and the write is what makes
  # @variables$repweights true.
  for (j in seq_len(n_rep)) {
    data[[rep_cols[j]]] <- as.numeric(rep_mat[, j])
  }

  variables <- list(
    weights = weights_var,
    repweights = rep_cols,
    type = x$type,
    scale = x$scale,
    rscales = x$rscales,
    mse = isTRUE(x$mse),
    fpc = NULL,
    fpctype = "fraction",
    probs_provided = FALSE,
    visible_vars = NULL
  )

  survey_replicate(
    data = data,
    variables = variables,
    metadata = .extract_haven_metadata(data)
  )
}


# twophase / twophase2 → survey_twophase
#' @noRd
.from_svydesign_twophase <- function(x) {
  # Convert the phase 1 full design to survey_taylor.
  phase1_sc <- .from_svydesign_taylor(x$phase1$full)
  phase1_data <- phase1_sc@data

  # Locate the subset column by matching x$subset to logical columns in data.
  subset_var <- .find_col_by_value(phase1_data, as.numeric(x$subset))
  if (is.null(subset_var)) {
    subset_var <- "..surveycore_subset.."
    phase1_data[[subset_var]] <- x$subset
  }

  # Derive method: check x$method first, fall back to class-based inference.
  # survey::twophase() never stores x$method — the branch below is defensive
  # for survey-compatible packages that may set it explicitly. # nocov start
  method <- if (
    !is.null(x$method) && x$method %in% c("full", "approx", "simple")
  ) {
    x$method # nocov end
  } else if (inherits(x, "twophase2")) {
    "full"
  } else {
    cli::cli_warn(
      c(
        "!" = paste0(
          "Could not determine two-phase variance method ",
          "from the survey object."
        ),
        "i" = 'Defaulting to {.val "approx"}.'
      ),
      class = "surveycore_warning_twophase_method_unknown"
    )
    "approx"
  }

  variables <- list(
    phase1 = phase1_sc@variables,
    phase2 = list(ids = NULL, strata = NULL, probs = NULL, fpc = NULL),
    subset = subset_var,
    method = method
  )

  survey_twophase(
    data = phase1_data,
    variables = variables,
    metadata = phase1_sc@metadata
  )
}


# ── from_tbl_svy ──────────────────────────────────────────────────────────────

#' Convert an srvyr tbl_svy to a surveycore Design Object
#'
#' Converts an `srvyr` `tbl_svy` to a surveycore design object by delegating
#' to [from_svydesign()]. A `tbl_svy` IS a `survey.design`, so the conversion
#' is structurally identical. Requires both `survey` and `srvyr`.
#'
#' @param x A `srvyr::tbl_svy` object.
#' @return A `survey_taylor`, `survey_replicate`, or `survey_twophase` object.
#'
#' @examples
#' if (
#'   requireNamespace("survey", quietly = TRUE) &&
#'     requireNamespace("srvyr", quietly = TRUE)
#' ) {
#'   ts <- srvyr::as_survey(
#'     survey::svydesign(
#'       ids = ~sdmvpsu,
#'       weights = ~wtint2yr,
#'       strata = ~sdmvstra,
#'       data = nhanes_2017,
#'       nest = TRUE
#'     )
#'   )
#'   d <- from_tbl_svy(ts)
#' }
#' @seealso [as_tbl_svy()] to convert in the other direction
#' @family conversion
#' @export
from_tbl_svy <- function(x) {
  if (!requireNamespace("survey", quietly = TRUE)) {
    # nocov start
    cli::cli_abort(
      c(
        "x" = "{.pkg survey} must be installed to use {.fn from_tbl_svy}.",
        "v" = "Install it with {.code install.packages(\"survey\")}."
      ),
      class = "surveycore_error_pkg_not_installed"
    )
    # nocov end
  }
  if (!requireNamespace("srvyr", quietly = TRUE)) {
    # nocov start
    cli::cli_abort(
      c(
        "x" = "{.pkg srvyr} must be installed to use {.fn from_tbl_svy}.",
        "v" = "Install it with {.code install.packages(\"srvyr\")}."
      ),
      class = "surveycore_error_pkg_not_installed"
    )
    # nocov end
  }

  if (!inherits(x, "tbl_svy")) {
    cli::cli_abort(
      c(
        "x" = "{.arg x} must be a {.cls tbl_svy} object.",
        "i" = "Got {.cls {class(x)[[1L]]}}."
      ),
      class = "surveycore_error_not_tbl_svy"
    )
  }

  # tbl_svy inherits from survey.design — delegate directly.
  from_svydesign(x)
}
