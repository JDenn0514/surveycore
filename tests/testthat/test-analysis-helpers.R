# tests/testthat/test-analysis-helpers.R
#
# Tests for shared internal helpers in R/09-analysis-helpers.R.
# All helpers are internal (unexported) but accessible during devtools::test()
# via the loaded package namespace.
#
# Test categories:
#   1. .validate_shared_args()
#   2. .resolve_groups()
#   3. .apply_domain()
#   4. .make_result_tibble()
#   5. .build_meta()
#   6. .add_variance_cols()
#   7. .apply_name_style()
#   8. .degf()
#   9. .check_unsupported_class()


# ── Category 1: .validate_shared_args() ──────────────────────────────────────

test_that(".validate_shared_args() returns invisible TRUE for valid args", {
  result <- .validate_shared_args(
    variance   = c("se", "ci"),
    conf_level = 0.95,
    name_style = "surveycore"
  )
  expect_identical(result, TRUE)
})

test_that(".validate_shared_args() accepts variance as a character vector", {
  expect_no_error(
    .validate_shared_args(
      variance   = c("se", "ci", "var", "cv", "moe", "deff"),
      conf_level = 0.95,
      name_style = "surveycore"
    )
  )
})

test_that(".validate_shared_args() accepts NULL variance", {
  expect_no_error(
    .validate_shared_args(
      variance   = NULL,
      conf_level = 0.95,
      name_style = "surveycore"
    )
  )
})

test_that('.validate_shared_args() accepts "deff" as a valid variance value', {
  expect_no_error(
    .validate_shared_args(
      variance   = "deff",
      conf_level = 0.95,
      name_style = "surveycore"
    )
  )
})

test_that(".validate_shared_args() rejects unknown variance values", {
  expect_error(
    .validate_shared_args("bogus", 0.95, "surveycore"),
    class = "surveycore_error_invalid_variance_arg"
  )
  expect_snapshot(
    error = TRUE,
    .validate_shared_args("bogus", 0.95, "surveycore")
  )
})

test_that(".validate_shared_args() rejects variance vector with one bad value", {
  expect_error(
    .validate_shared_args(c("se", "bogus"), 0.95, "surveycore"),
    class = "surveycore_error_invalid_variance_arg"
  )
})

test_that(".validate_shared_args() rejects non-numeric conf_level", {
  expect_error(
    .validate_shared_args(NULL, "high", "surveycore"),
    class = "surveycore_error_invalid_conf_level"
  )
  expect_snapshot(
    error = TRUE,
    .validate_shared_args(NULL, "high", "surveycore")
  )
})

test_that(".validate_shared_args() rejects conf_level outside (0, 1)", {
  expect_error(
    .validate_shared_args(NULL, 0, "surveycore"),
    class = "surveycore_error_invalid_conf_level"
  )
  expect_error(
    .validate_shared_args(NULL, 1, "surveycore"),
    class = "surveycore_error_invalid_conf_level"
  )
  expect_error(
    .validate_shared_args(NULL, 1.5, "surveycore"),
    class = "surveycore_error_invalid_conf_level"
  )
})

test_that(".validate_shared_args() rejects conf_level vector of length > 1", {
  expect_error(
    .validate_shared_args(NULL, c(0.9, 0.95), "surveycore"),
    class = "surveycore_error_invalid_conf_level"
  )
})

test_that(".validate_shared_args() rejects invalid name_style", {
  expect_error(
    .validate_shared_args(NULL, 0.95, "tidy"),
    class = "surveycore_error_invalid_name_style"
  )
  expect_snapshot(
    error = TRUE,
    .validate_shared_args(NULL, 0.95, "tidy")
  )
})

test_that(".validate_shared_args() accepts broom name_style", {
  expect_no_error(
    .validate_shared_args(NULL, 0.95, "broom")
  )
})


# ── Category 2: .resolve_groups() ────────────────────────────────────────────

test_that(".resolve_groups() returns @groups when group= is NULL", {
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 1L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  # Set @groups on the design (simulate group_by())
  d@groups <- c("group")
  result   <- .resolve_groups(d, rlang::quo(NULL))

  expect_identical(result, "group")
})

test_that(".resolve_groups() returns group= arg when @groups is empty", {
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 2L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- .resolve_groups(d, rlang::quo(group))
  expect_identical(result, "group")
})

test_that(".resolve_groups() ANDs @groups and group= together", {
  df <- make_survey_data(n = 100L, n_psu = 10L, n_strata = 2L, seed = 3L)
  df$region <- sample(c("North", "South"), nrow(df), replace = TRUE)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  d@groups <- c("region")

  result <- .resolve_groups(d, rlang::quo(group))
  expect_true("region" %in% result)
  expect_true("group" %in% result)
  expect_length(result, 2L)
})

test_that(".resolve_groups() deduplicates when @groups and group= overlap", {
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 4L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  d@groups <- c("group")

  result <- .resolve_groups(d, rlang::quo(group))
  expect_identical(result, "group")  # deduplicated to one entry
})

test_that(".resolve_groups() returns character(0) when neither source has groups", {
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 5L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- .resolve_groups(d, rlang::quo(NULL))
  expect_identical(result, character(0))
})


# ── Category 3: .apply_domain() ──────────────────────────────────────────────

test_that(".apply_domain() returns all TRUE when no domain column present", {
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 6L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  mask <- .apply_domain(d)
  expect_true(is.logical(mask))
  expect_length(mask, nrow(d@data))
  expect_true(all(mask))
})

test_that(".apply_domain() returns domain column values when present", {
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 7L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  # Manually inject a domain column
  domain_mask <- rep(c(TRUE, FALSE), length.out = nrow(d@data))
  d@data[[SURVEYCORE_DOMAIN_COL]] <- domain_mask

  result <- .apply_domain(d)
  expect_identical(result, domain_mask)
})


# ── Category 4: .make_result_tibble() ────────────────────────────────────────

test_that(".make_result_tibble() produces the correct S3 class hierarchy", {
  designs <- make_all_designs(seed = 42L)
  d       <- designs$taylor

  col_vecs   <- list(mean = c(10.0, 20.0), n = c(25L, 25L))
  groups_df  <- data.frame(group = c("A", "B"), stringsAsFactors = FALSE)
  meta_args  <- list(
    conf_level = 0.95,
    call       = quote(get_means(d, y1)),
    group      = list(group = list(variable_label = NULL,
                                   question_preface = NULL,
                                   value_labels = NULL)),
    x          = list(y1 = list(variable_label = NULL,
                                question_preface = NULL,
                                value_labels = NULL))
  )

  result <- .make_result_tibble(
    col_vecs           = col_vecs,
    groups_df          = groups_df,
    class_name         = "survey_means",
    design             = d,
    meta_args          = meta_args,
    required_meta_keys = MEANS_META_KEYS
  )

  expect_true(inherits(result, "survey_means"))
  expect_true(inherits(result, "survey_result"))
  expect_true(tibble::is_tibble(result))
  expect_true(inherits(result, "data.frame"))
})

test_that(".make_result_tibble() attaches .meta attribute", {
  designs <- make_all_designs(seed = 42L)
  d       <- designs$srs

  col_vecs   <- list(mean = 42.0, n = 50L)
  groups_df  <- data.frame()
  meta_args  <- list(
    conf_level = 0.95,
    call       = quote(get_means(d, y1)),
    group      = list(),
    x          = list(y1 = list(variable_label = NULL,
                                question_preface = NULL,
                                value_labels = NULL))
  )

  result <- .make_result_tibble(
    col_vecs           = col_vecs,
    groups_df          = groups_df,
    class_name         = "survey_means",
    design             = d,
    meta_args          = meta_args,
    required_meta_keys = MEANS_META_KEYS
  )

  m <- attr(result, ".meta")
  expect_false(is.null(m))
  expect_type(m, "list")
  expect_true("design_type" %in% names(m))
  expect_true("n_respondents" %in% names(m))
  expect_identical(m$n_respondents, as.integer(nrow(d@data)))
})

test_that(".make_result_tibble() stopifnot fires when required keys missing", {
  designs <- make_all_designs(seed = 42L)
  d       <- designs$taylor

  col_vecs  <- list(mean = 42.0)
  groups_df <- data.frame()
  # meta_args is missing "group" and "x" which are in MEANS_META_KEYS
  incomplete_meta <- list(
    conf_level = 0.95,
    call       = quote(get_means(d, y1))
    # deliberately missing "group" and "x"
  )

  expect_error(
    .make_result_tibble(
      col_vecs           = col_vecs,
      groups_df          = groups_df,
      class_name         = "survey_means",
      design             = d,
      meta_args          = incomplete_meta,
      required_meta_keys = MEANS_META_KEYS
    )
  )
})

test_that(".make_result_tibble() includes group columns before result columns", {
  designs <- make_all_designs(seed = 42L)
  d       <- designs$taylor

  col_vecs  <- list(mean = c(10.0, 20.0))
  groups_df <- data.frame(group = c("A", "B"), stringsAsFactors = FALSE)
  meta_args <- list(
    conf_level = 0.95,
    call       = quote(get_means(d, y1)),
    group      = list(group = list(variable_label = NULL,
                                   question_preface = NULL,
                                   value_labels = NULL)),
    x          = list(y1 = list(variable_label = NULL,
                                question_preface = NULL,
                                value_labels = NULL))
  )

  result <- .make_result_tibble(
    col_vecs           = col_vecs,
    groups_df          = groups_df,
    class_name         = "survey_means",
    design             = d,
    meta_args          = meta_args,
    required_meta_keys = MEANS_META_KEYS
  )

  expect_identical(names(result)[1L], "group")
  expect_identical(names(result)[2L], "mean")
})


# ── Category 5: .build_meta() ────────────────────────────────────────────────

test_that(".build_meta() returns design_type = 'taylor' for survey_taylor", {
  designs <- make_all_designs(seed = 42L)
  meta    <- .build_meta(designs$taylor, list(conf_level = 0.95))
  expect_identical(meta$design_type, "taylor")
})

test_that(".build_meta() returns design_type = 'replicate' for survey_replicate", {
  designs <- make_all_designs(seed = 42L)
  meta    <- .build_meta(designs$replicate, list(conf_level = 0.95))
  expect_identical(meta$design_type, "replicate")
})

test_that(".build_meta() returns design_type = 'twophase' for survey_twophase", {
  designs <- make_all_designs(seed = 42L)
  meta    <- .build_meta(designs$twophase, list(conf_level = 0.95))
  expect_identical(meta$design_type, "twophase")
})

test_that(".build_meta() returns design_type = 'srs' for survey_srs", {
  designs <- make_all_designs(seed = 42L)
  meta    <- .build_meta(designs$srs, list(conf_level = 0.95))
  expect_identical(meta$design_type, "srs")
})

test_that(".build_meta() returns design_type = 'calibrated' for survey_calibrated", {
  designs <- make_all_designs(seed = 42L)
  meta    <- .build_meta(designs$calibrated, list(conf_level = 0.95))
  expect_identical(meta$design_type, "calibrated")
})

test_that(".build_meta() returns n_respondents = nrow(design@data) as integer", {
  designs <- make_all_designs(seed = 42L)
  d       <- designs$taylor
  meta    <- .build_meta(d, list())
  expect_identical(meta$n_respondents, as.integer(nrow(d@data)))
  expect_type(meta$n_respondents, "integer")
})

test_that(".build_meta() merges meta_args into the returned list", {
  designs   <- make_all_designs(seed = 42L)
  meta_args <- list(
    conf_level   = 0.90,
    variable     = "y1",
    value_labels = list(y1 = NULL)
  )
  meta <- .build_meta(designs$taylor, meta_args)
  expect_identical(meta$conf_level, 0.90)
  expect_identical(meta$variable, "y1")
})

test_that(".build_meta() fallback throws surveycore_error_unsupported_class", {
  expect_error(
    .build_meta(list(data = data.frame(x = 1)), list()),
    class = "surveycore_error_unsupported_class"
  )
  expect_snapshot(
    error = TRUE,
    .build_meta(list(data = data.frame(x = 1)), list())
  )
})


# ── Category 6: .add_variance_cols() ─────────────────────────────────────────

test_that(".add_variance_cols() returns empty list when variance = NULL", {
  result <- .add_variance_cols(
    se_vec       = c(1.0, 2.0),
    estimate_vec = c(10.0, 20.0),
    conf_level   = 0.95,
    degf         = 100L,
    variance     = NULL
  )
  expect_identical(result, list())
})

test_that(".add_variance_cols() returns se column when requested", {
  result <- .add_variance_cols(
    se_vec       = c(1.0, 2.0),
    estimate_vec = c(10.0, 20.0),
    conf_level   = 0.95,
    degf         = 100L,
    variance     = "se"
  )
  expect_true("se" %in% names(result))
  expect_equal(result$se, c(1.0, 2.0))
})

test_that(".add_variance_cols() computes var = se^2", {
  result <- .add_variance_cols(
    se_vec       = c(2.0, 3.0),
    estimate_vec = c(10.0, 20.0),
    conf_level   = 0.95,
    degf         = 100L,
    variance     = "var"
  )
  expect_equal(result$var, c(4.0, 9.0))
})

test_that(".add_variance_cols() computes cv = se/estimate (ratio, not percentage)", {
  result <- .add_variance_cols(
    se_vec       = c(1.0, 2.0),
    estimate_vec = c(10.0, 20.0),
    conf_level   = 0.95,
    degf         = 100L,
    variance     = "cv"
  )
  # cv = se / estimate as a ratio: 1/10 = 0.1, 2/20 = 0.1
  expect_equal(result$cv, c(0.1, 0.1))
})

test_that(".add_variance_cols() sets cv = NA and warns for zero estimate", {
  expect_warning(
    result <- .add_variance_cols(
      se_vec       = c(1.0, 2.0),
      estimate_vec = c(0.0, 20.0),  # first estimate is zero
      conf_level   = 0.95,
      degf         = 100L,
      variance     = "cv"
    ),
    class = "surveycore_warning_cv_undefined"
  )
  expect_true(is.na(result$cv[1L]))
  expect_false(is.na(result$cv[2L]))
})

test_that(".add_variance_cols() sets cv = NA and warns for negative estimate", {
  expect_warning(
    result <- .add_variance_cols(
      se_vec       = c(1.0, 2.0),
      estimate_vec = c(-5.0, 20.0),
      conf_level   = 0.95,
      degf         = 100L,
      variance     = "cv"
    ),
    class = "surveycore_warning_cv_undefined"
  )
  expect_true(is.na(result$cv[1L]))
})

test_that(".add_variance_cols() computes ci_low and ci_high using t distribution", {
  se  <- 1.0
  est <- 10.0
  df  <- 49L
  result <- .add_variance_cols(
    se_vec       = se,
    estimate_vec = est,
    conf_level   = 0.95,
    degf         = df,
    variance     = "ci"
  )
  t_crit <- stats::qt(0.975, df = df)
  expect_equal(result$ci_low,  est - t_crit * se)
  expect_equal(result$ci_high, est + t_crit * se)
})

test_that(".add_variance_cols() computes moe = (ci_high - ci_low) / 2", {
  result <- .add_variance_cols(
    se_vec       = 1.0,
    estimate_vec = 10.0,
    conf_level   = 0.95,
    degf         = 49L,
    variance     = "moe"
  )
  expect_true("moe" %in% names(result))
  expect_false("ci_low" %in% names(result))
  expected_moe <- stats::qt(0.975, df = 49L) * 1.0
  expect_equal(result$moe, expected_moe)
})

test_that(".add_variance_cols() computes deff = (se / se_srs)^2", {
  result <- .add_variance_cols(
    se_vec       = 2.0,
    estimate_vec = 10.0,
    se_srs_vec   = 1.0,
    conf_level   = 0.95,
    degf         = 49L,
    variance     = "deff"
  )
  expect_equal(result$deff, 4.0)
})

test_that(".add_variance_cols() returns NA deff when se_srs_vec is NULL", {
  result <- .add_variance_cols(
    se_vec       = 2.0,
    estimate_vec = 10.0,
    se_srs_vec   = NULL,
    conf_level   = 0.95,
    degf         = 49L,
    variance     = "deff"
  )
  expect_true(is.na(result$deff))
})

test_that(".add_variance_cols() column ordering is se, var, cv, ci_low, ci_high, moe, deff", {
  result <- .add_variance_cols(
    se_vec       = 1.0,
    estimate_vec = 10.0,
    se_srs_vec   = 0.5,
    conf_level   = 0.95,
    degf         = 49L,
    variance     = c("se", "var", "cv", "ci", "moe", "deff")
  )
  expect_identical(
    names(result),
    c("se", "var", "cv", "ci_low", "ci_high", "moe", "deff")
  )
})

test_that(".add_variance_cols() can return any subset of columns", {
  result <- .add_variance_cols(
    se_vec       = 1.0,
    estimate_vec = 10.0,
    conf_level   = 0.95,
    degf         = 49L,
    variance     = c("ci", "moe")
  )
  expect_true("ci_low" %in% names(result))
  expect_true("ci_high" %in% names(result))
  expect_true("moe" %in% names(result))
  expect_false("se" %in% names(result))
  expect_false("var" %in% names(result))
})


# ── Category 7: .apply_name_style() ──────────────────────────────────────────

test_that('.apply_name_style() is a no-op for name_style = "surveycore"', {
  result <- structure(
    tibble::tibble(mean = 10.0, se = 1.0, ci_low = 8.0, ci_high = 12.0, n = 50L),
    .meta  = list(design_type = "srs"),
    class  = c("survey_means", "survey_result", "tbl_df", "tbl", "data.frame")
  )
  out <- .apply_name_style(result, "surveycore")
  expect_identical(names(out), names(result))
})

test_that('.apply_name_style() renames columns for name_style = "broom"', {
  result <- structure(
    tibble::tibble(mean = 10.0, se = 1.0, ci_low = 8.0, ci_high = 12.0, n = 50L),
    .meta  = list(design_type = "srs"),
    class  = c("survey_means", "survey_result", "tbl_df", "tbl", "data.frame")
  )
  out <- .apply_name_style(result, "broom")
  expect_true("estimate" %in% names(out))
  expect_true("std.error" %in% names(out))
  expect_true("conf.low" %in% names(out))
  expect_true("conf.high" %in% names(out))
  expect_false("mean" %in% names(out))
  expect_false("se" %in% names(out))
})

test_that(".apply_name_style() preserves .meta and class after rename", {
  result <- structure(
    tibble::tibble(mean = 10.0, se = 1.0),
    .meta  = list(design_type = "srs", n_respondents = 50L),
    class  = c("survey_means", "survey_result", "tbl_df", "tbl", "data.frame")
  )
  out <- .apply_name_style(result, "broom")
  expect_identical(attr(out, ".meta"), attr(result, ".meta"))
  expect_identical(class(out), class(result))
})

test_that(".apply_name_style() only renames columns that are present", {
  # result has 'mean' but not 'se'; 'se' should not be added
  result <- structure(
    tibble::tibble(mean = 10.0, n = 50L),
    .meta  = list(design_type = "srs"),
    class  = c("survey_means", "survey_result", "tbl_df", "tbl", "data.frame")
  )
  out <- .apply_name_style(result, "broom")
  expect_false("std.error" %in% names(out))
  expect_true("estimate" %in% names(out))
})

test_that('.apply_name_style() renames p_value to p.value for get_corr() output', {
  result <- structure(
    tibble::tibble(r = 0.5, p_value = 0.01, df = 48L),
    .meta  = list(design_type = "taylor"),
    class  = c("survey_corr", "survey_result", "tbl_df", "tbl", "data.frame")
  )
  out <- .apply_name_style(result, "broom")
  expect_true("p.value" %in% names(out))
  expect_true("parameter" %in% names(out))
  expect_true("estimate" %in% names(out))
})


# ── Category 8: .degf() ──────────────────────────────────────────────────────

test_that(".degf() returns Inf for survey_taylor (normal approximation CI)", {
  df <- make_survey_data(n = 100L, n_psu = 10L, n_strata = 2L, seed = 10L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  test_invariants(d)

  expect_equal(.degf(d), Inf)
})

test_that(".degf() returns Inf for survey_replicate (normal approximation CI)", {
  df <- make_survey_data(
    n = 100L, n_psu = 10L, n_strata = 2L,
    design = "replicate", type = "brr", seed = 11L
  )
  repwt_cols <- grep("^repwt_", names(df), value = TRUE)
  d          <- as_survey_rep(
    df,
    weights    = wt,
    repweights = tidyselect::all_of(repwt_cols),
    type       = "BRR"
  )
  test_invariants(d)

  expect_equal(.degf(d), Inf)
})

test_that(".degf() returns Inf for survey_twophase (normal approximation CI)", {
  df <- make_survey_data(
    n = 100L, n_psu = 10L, n_strata = 2L,
    design = "twophase", seed = 12L
  )
  phase1   <- as_survey(
    df, ids = psu, weights = wt, strata = strata, fpc = fpc, nest = TRUE
  )
  twophase <- as_survey_twophase(phase1, subset = subset, method = "approx")
  test_invariants(twophase)

  expect_equal(.degf(twophase), Inf)
  expect_equal(.degf(phase1),   Inf)
})

test_that(".degf() returns Inf for survey_srs (normal approximation CI)", {
  df <- make_survey_data(n = 50L, n_psu = 6L, n_strata = 1L, seed = 13L)
  d  <- as_survey_srs(df, weights = wt)
  test_invariants(d)

  expect_equal(.degf(d), Inf)
})

test_that(".degf() returns Inf for survey_calibrated (normal approximation CI)", {
  df <- make_survey_data(n = 50L, n_psu = 6L, n_strata = 1L, seed = 14L)
  d  <- as_survey_calibrated(df, weights = wt)
  test_invariants(d)

  expect_equal(.degf(d), Inf)
})

test_that(".degf() throws surveycore_error_unsupported_class for non-design object", {
  expect_error(
    .degf(data.frame(x = 1:5)),
    class = "surveycore_error_unsupported_class"
  )
})


# ── Category 9: .check_unsupported_class() ───────────────────────────────────

test_that(".check_unsupported_class() throws for a plain data frame", {
  expect_error(
    .check_unsupported_class(data.frame(x = 1), "get_means"),
    class = "surveycore_error_unsupported_class"
  )
  expect_snapshot(
    error = TRUE,
    .check_unsupported_class(data.frame(x = 1), "get_means")
  )
})

test_that(".check_unsupported_class() throws for a plain list", {
  expect_error(
    .check_unsupported_class(list(x = 1), "get_freqs"),
    class = "surveycore_error_unsupported_class"
  )
})

test_that(".check_unsupported_class() returns invisibly for all five supported classes", {
  designs <- make_all_designs(seed = 42L)
  for (nm in names(designs)) {
    expect_no_error(
      .check_unsupported_class(designs[[nm]], "get_means"),
      message = paste("Should not error for", nm)
    )
  }
})

test_that(".check_unsupported_class() returns NULL invisibly on success", {
  designs <- make_all_designs(seed = 42L)
  result  <- .check_unsupported_class(designs$taylor, "get_means")
  expect_null(result)
})


# ── Category 10: .extract_var_meta() ─────────────────────────────────────────

test_that(".extract_var_meta() returns all-NULL list for plain numeric column", {
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 20L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  # y1 has no metadata and no haven attrs in this data
  result <- .extract_var_meta(d, "y1")

  expect_type(result, "list")
  expect_identical(names(result), c("variable_label", "question_preface", "value_labels"))
  expect_null(result$variable_label)
  expect_null(result$question_preface)
  expect_null(result$value_labels)
})

test_that(".extract_var_meta() returns variable_label from @metadata@variable_labels", {
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 21L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  d  <- set_var_label(d, y1, "Annual household income")

  result <- .extract_var_meta(d, "y1")
  expect_identical(result$variable_label, "Annual household income")
})

test_that(".extract_var_meta() falls back to attr(col, 'label') when @metadata has no entry", {
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 22L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  # Manually attach a haven label attribute to a column (bypassing @metadata)
  attr(d@data[["y2"]], "label") <- "Manually attached label"

  result <- .extract_var_meta(d, "y2")
  expect_identical(result$variable_label, "Manually attached label")
})

test_that(".extract_var_meta() returns question_preface from @metadata@question_prefaces", {
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 23L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  d  <- set_question_preface(d, y1, "How would you rate...")

  result <- .extract_var_meta(d, "y1")
  expect_identical(result$question_preface, "How would you rate...")
})

test_that(".extract_var_meta() returns value_labels from @metadata@value_labels", {
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 24L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  lbs <- c("No" = 0L, "Yes" = 1L)
  d  <- set_val_labels(d, y3, lbs)

  result <- .extract_var_meta(d, "y3")
  expect_identical(result$value_labels, lbs)
})

test_that(".extract_var_meta() falls back to attr(col, 'labels') for haven-labelled column", {
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 25L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  # Manually attach haven-style labels to a column that has no @metadata entry
  haven_lbs <- c("Male" = 1L, "Female" = 2L)
  attr(d@data[["y3"]], "labels") <- haven_lbs

  result <- .extract_var_meta(d, "y3")
  expect_identical(result$value_labels, haven_lbs)
})

test_that(".extract_var_meta() returns value_labels as named integer for factor column", {
  df    <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 26L)
  df$gender <- factor(
    sample(c("Male", "Female"), nrow(df), replace = TRUE),
    levels = c("Male", "Female")
  )
  d <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- .extract_var_meta(d, "gender")
  expect_false(is.null(result$value_labels))
  expect_identical(names(result$value_labels), c("Male", "Female"))
  expect_identical(unname(result$value_labels), c(1L, 2L))
  expect_type(result$value_labels, "integer")
})

test_that(".extract_var_meta() @metadata takes precedence over haven column attrs", {
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 27L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  # Set label in @metadata
  d  <- set_var_label(d, y1, "Metadata label")
  # Also attach haven attr directly to the column
  attr(d@data[["y1"]], "label") <- "Haven attr label"

  result <- .extract_var_meta(d, "y1")
  expect_identical(result$variable_label, "Metadata label")
})

test_that(".extract_var_meta() @metadata value_labels take precedence over haven labels attr", {
  df  <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 28L)
  d   <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  meta_lbs <- c("No" = 0L, "Yes" = 1L)
  d   <- set_val_labels(d, y3, meta_lbs)
  # Also attach different haven attrs directly to the column
  attr(d@data[["y3"]], "labels") <- c("Nein" = 0L, "Ja" = 1L)

  result <- .extract_var_meta(d, "y3")
  expect_identical(result$value_labels, meta_lbs)
})


# ── Category 11: .build_group_meta() ─────────────────────────────────────────

test_that(".build_group_meta() returns list() for empty group_vars", {
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 30L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- .build_group_meta(d, character(0))
  expect_identical(result, list())
})

test_that(".build_group_meta() returns named list of length 1 for one group var", {
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 31L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- .build_group_meta(d, "group")
  expect_type(result, "list")
  expect_length(result, 1L)
  expect_identical(names(result), "group")
})

test_that(".build_group_meta() returns named list of length N for N group vars", {
  df      <- make_survey_data(n = 100L, n_psu = 10L, n_strata = 2L, seed = 32L)
  df$sex  <- factor(sample(c("Male", "Female"), nrow(df), replace = TRUE))
  d       <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- .build_group_meta(d, c("group", "sex"))
  expect_length(result, 2L)
  expect_identical(names(result), c("group", "sex"))
})

test_that(".build_group_meta() each entry has the three required sub-keys", {
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 33L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  d  <- set_var_label(d, group, "Survey group")

  result <- .build_group_meta(d, "group")
  entry  <- result[["group"]]

  expect_true("variable_label"   %in% names(entry))
  expect_true("question_preface" %in% names(entry))
  expect_true("value_labels"     %in% names(entry))
})

test_that(".build_group_meta() captures variable_label for labelled group var", {
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 34L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  d  <- set_var_label(d, group, "Demographic group")

  result <- .build_group_meta(d, "group")
  expect_identical(result$group$variable_label, "Demographic group")
})


# ── Category 12: .apply_group_labels() ───────────────────────────────────────

test_that(".apply_group_labels() leaves unlabelled integer columns unchanged", {
  df        <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 40L)
  df$gender_code <- sample(1L:2L, nrow(df), replace = TRUE)
  d         <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  combos    <- data.frame(gender_code = c(1L, 2L))

  result <- .apply_group_labels(combos, "gender_code", d, label_values = TRUE)
  expect_identical(result$gender_code, c(1L, 2L))
  expect_false(is.factor(result$gender_code))
})

test_that(".apply_group_labels() converts haven-labelled integer codes to factor", {
  df        <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 41L)
  df$gender <- sample(1L:2L, nrow(df), replace = TRUE)
  d         <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  d         <- set_val_labels(d, gender, c("Male" = 1L, "Female" = 2L))

  combos <- data.frame(gender = c(1L, 2L))
  result <- .apply_group_labels(combos, "gender", d, label_values = TRUE)

  expect_true(is.factor(result$gender))
  expect_identical(as.character(result$gender), c("Male", "Female"))
  expect_identical(levels(result$gender), c("Male", "Female"))
})

test_that(".apply_group_labels() factor levels ordered by code value for haven labels", {
  df        <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 42L)
  df$cat    <- sample(c(3L, 1L, 2L), nrow(df), replace = TRUE)
  d         <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  # labels declared in non-numeric order
  d         <- set_val_labels(d, cat, c("Low" = 1L, "Mid" = 2L, "High" = 3L))

  combos <- data.frame(cat = c(1L, 2L, 3L))
  result <- .apply_group_labels(combos, "cat", d, label_values = TRUE)

  expect_identical(levels(result$cat), c("Low", "Mid", "High"))
})

test_that(".apply_group_labels() converts plain R factor to factor preserving level order", {
  df        <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 43L)
  df$status <- factor(
    sample(c("Active", "Inactive"), nrow(df), replace = TRUE),
    levels = c("Inactive", "Active")   # non-alphabetical order
  )
  d <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  combos <- data.frame(
    status = c("Active", "Inactive"),
    stringsAsFactors = FALSE
  )
  result <- .apply_group_labels(combos, "status", d, label_values = TRUE)

  expect_true(is.factor(result$status))
  expect_identical(levels(result$status), c("Inactive", "Active"))
})

test_that(".apply_group_labels() with label_values = FALSE returns group_combos unchanged", {
  df        <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 44L)
  df$gender <- sample(1L:2L, nrow(df), replace = TRUE)
  d         <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  d         <- set_val_labels(d, gender, c("Male" = 1L, "Female" = 2L))

  combos   <- data.frame(gender = c(1L, 2L))
  result   <- .apply_group_labels(combos, "gender", d, label_values = FALSE)

  expect_identical(result$gender, c(1L, 2L))
  expect_false(is.factor(result$gender))
})

test_that(".apply_group_labels() only converts labelled columns in multi-group combos", {
  df        <- make_survey_data(n = 100L, n_psu = 10L, n_strata = 2L, seed = 45L)
  df$gender <- sample(1L:2L, nrow(df), replace = TRUE)
  df$region <- sample(1L:3L, nrow(df), replace = TRUE)  # no labels
  d         <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  d         <- set_val_labels(d, gender, c("Male" = 1L, "Female" = 2L))

  combos <- data.frame(gender = c(1L, 2L, 1L, 2L, 1L, 2L),
                       region = c(1L, 1L, 2L, 2L, 3L, 3L))
  result <- .apply_group_labels(combos, c("gender", "region"), d, label_values = TRUE)

  expect_true(is.factor(result$gender))
  expect_identical(as.character(result$gender[1L:2L]), c("Male", "Female"))
  expect_false(is.factor(result$region))
  expect_identical(result$region, c(1L, 1L, 2L, 2L, 3L, 3L))
})


# ── .apply_decimals() ─────────────────────────────────────────────────────────

test_that(".apply_decimals() rounds double columns to specified places", {
  df <- make_survey_data(n = 100L, n_psu = 10L, n_strata = 2L, seed = 51L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  r  <- get_means(d, y1, variance = "se")

  r_rounded <- .apply_decimals(r, 2L)

  expect_equal(r_rounded$mean, round(r$mean, 2L))
  expect_equal(r_rounded$se,   round(r$se,   2L))
})

test_that(".apply_decimals() leaves integer columns unchanged", {
  df <- make_survey_data(n = 100L, n_psu = 10L, n_strata = 2L, seed = 52L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  r  <- get_means(d, y1)

  r_rounded <- .apply_decimals(r, 0L)

  expect_identical(r_rounded$n, r$n)
  expect_identical(class(r_rounded$n)[[1L]], "integer")
})

test_that(".apply_decimals() preserves .meta attribute", {
  df <- make_survey_data(n = 100L, n_psu = 10L, n_strata = 2L, seed = 53L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  r  <- get_means(d, y1)
  m_before <- attr(r, ".meta")

  r_rounded <- .apply_decimals(r, 2L)

  expect_identical(attr(r_rounded, ".meta"), m_before)
})

test_that(".apply_decimals() preserves S3 class", {
  df <- make_survey_data(n = 100L, n_psu = 10L, n_strata = 2L, seed = 54L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  r  <- get_means(d, y1)
  cls_before <- class(r)

  r_rounded <- .apply_decimals(r, 2L)

  expect_identical(class(r_rounded), cls_before)
})

# ── .validate_shared_args() — decimals validation ─────────────────────────────

test_that(".validate_shared_args() accepts decimals = NULL", {
  expect_no_error(
    .validate_shared_args(NULL, 0.95, "surveycore", decimals = NULL)
  )
})

test_that(".validate_shared_args() accepts decimals = 0", {
  expect_no_error(
    .validate_shared_args(NULL, 0.95, "surveycore", decimals = 0L)
  )
})

test_that(".validate_shared_args() accepts decimals = 4", {
  expect_no_error(
    .validate_shared_args(NULL, 0.95, "surveycore", decimals = 4L)
  )
})

test_that(".validate_shared_args() rejects negative decimals", {
  expect_error(
    .validate_shared_args(NULL, 0.95, "surveycore", decimals = -1L),
    class = "surveycore_error_invalid_decimals"
  )
  expect_snapshot(
    error = TRUE,
    .validate_shared_args(NULL, 0.95, "surveycore", decimals = -1L)
  )
})

test_that(".validate_shared_args() rejects non-integer decimals", {
  expect_error(
    .validate_shared_args(NULL, 0.95, "surveycore", decimals = 1.5),
    class = "surveycore_error_invalid_decimals"
  )
})

test_that(".validate_shared_args() rejects non-numeric decimals", {
  expect_error(
    .validate_shared_args(NULL, 0.95, "surveycore", decimals = "2"),
    class = "surveycore_error_invalid_decimals"
  )
})
