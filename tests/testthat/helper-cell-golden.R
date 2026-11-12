# Golden harness for tests/testthat/test-analysis-cell-equivalence.R and
# data-raw/analysis-cell-golden.R.
#
# This file defines functions and constants only. Nothing runs when it is
# sourced. testthat sources it before helper-test-data.R, so its functions
# call make_survey_data() and the other helpers only when they run.

# ------------------------------------------------------------------------------
# Frame builder
# ------------------------------------------------------------------------------

# Adds the scenario columns to a frame from make_survey_data(). a1 is the
# first row of group "A" and b1 the first row of group "B".
cell_golden_cols <- function(df) {
  n <- nrow(df)
  a1 <- which(df$group == "A")[[1L]]
  b1 <- which(df$group == "B")[[1L]]
  in_c <- df$group == "C"

  withr::with_seed(201L, {
    df$f5 <- sample(letters[1:5], n, replace = TRUE)
    na_rows <- sample.int(n, 25L)
  })
  df$f5_na <- df$f5
  df$f5_na[na_rows] <- NA

  df$y1_na <- df$y1
  df$y1_na[[b1]] <- NA
  df$y1_inf <- df$y1
  df$y1_inf[[b1]] <- Inf
  df$y3_na <- df$y3
  df$y3_na[[b1]] <- NA
  df$y1_c_na <- df$y1
  df$y1_c_na[in_c] <- NA
  df$y3_c_na <- df$y3
  df$y3_c_na[in_c] <- NA
  df$y1_c_zero <- df$y1
  df$y1_c_zero[in_c] <- 0
  df$y_allna <- rep(NA_real_, n)
  df$y2_a_na <- df$y2
  df$y2_a_na[[a1]] <- NA

  df$wt_na_out <- df$wt
  df$wt_na_out[[a1]] <- NA
  df$wt_na_in <- df$wt
  df$wt_na_in[[b1]] <- NA
  df$wt_inf <- df$wt
  df$wt_inf[[b1]] <- Inf
  df$cal_wt <- df$wt * 1.01
  df$p <- 1 / df$wt

  df$single <- rep("only", n)
  df$group_na <- df$group
  df$group_na[c(a1, b1)] <- NA
  df$g_one <- c("Z", rep("Y", n - 1L))
  df$g_two <- c("Z", "Z", rep("Y", n - 2L))
  for (m in c(16L, 17L, 32L, 33L, 64L, 65L)) {
    df[[paste0("g", m)]] <- rep_len(seq_len(m), n)
  }

  df$y1_inf65 <- df$y1
  df$y1_inf65[[65L]] <- Inf
  df$y3_na65 <- df$y3
  df$y3_na65[[65L]] <- NA
  df$y1_gap <- df$y1
  df$y1_gap[df$g65 == 33L & seq_len(n) != 33L] <- NA

  df
}

# ------------------------------------------------------------------------------
# Design builder
# ------------------------------------------------------------------------------

.cg_frame <- function(kind) {
  switch(
    kind,
    tay = make_survey_data(seed = 101L),
    tay_lab = make_survey_data(seed = 101L, with_labels = TRUE),
    multi = make_survey_data(
      n = 600L,
      n_psu = 30L,
      n_ssu = 3L,
      n_strata = 5L,
      seed = 102L
    ),
    rep = make_survey_data(
      n = 500L,
      n_psu = 50L,
      design = "replicate",
      type = "brr",
      seed = 103L
    ),
    rep10 = make_survey_data(
      n = 300L,
      n_psu = 20L,
      design = "replicate",
      type = "brr",
      seed = 104L
    ),
    tph = make_survey_data(
      n = 500L,
      n_psu = 50L,
      design = "twophase",
      seed = 105L
    )
  ) |>
    cell_golden_cols()
}

.cg_taylor <- function(df, weights = "wt", use_fpc = TRUE) {
  if (use_fpc) {
    as_survey(
      df,
      ids = psu,
      strata = strata,
      fpc = fpc,
      weights = tidyselect::all_of(weights),
      nest = TRUE
    )
  } else {
    as_survey(
      df,
      ids = psu,
      strata = strata,
      weights = tidyselect::all_of(weights),
      nest = TRUE
    )
  }
}

.cg_caldata <- function(df) {
  as_caldata(df$wt, rep(1.01, nrow(df)), stats::model.matrix(~y2, df))
}

.cg_replicate <- function(df) {
  as_survey_replicate(
    df,
    weights = wt,
    repweights = tidyselect::starts_with("repwt_"),
    type = "BRR"
  )
}

.cg_np_replicate <- function(df) {
  as_survey_nonprob(
    df,
    weights = wt,
    repweights = tidyselect::starts_with("repwt_")
  )
}

.cg_first_row <- function(df, g) {
  which(df$group == g)[[1L]]
}

.cg_gss <- function() {
  gss <- gss_2024
  for (v in c("age", "educ", "degree", "race", "sex", "partyid", "happy")) {
    x <- as.numeric(unclass(gss[[v]]))
    x[!is.na(x) & x < 0] <- NA
    gss[[v]] <- x
  }
  as_survey(gss, ids = vpsu, strata = vstrat, weights = wtssps, nest = TRUE)
}

# The six designs that take the standard domain marker (y2 > -0.5).
.cg_dom_designs <- c(
  "tay_dom",
  "rep_dom",
  "cal_dom",
  "np_rep_dom",
  "np_srs_dom",
  "tph_dom"
)

# Builds one design by name. The generator and the tests both build every
# design through this function, so the two sides see identical designs.
cell_golden_design <- function(name) {
  if (name %in% .cg_dom_designs) {
    base <- sub("_dom$", "", name)
    d <- cell_golden_design(base)
    df <- .cg_frame(switch(base, tph = "tph", rep = , np_rep = "rep", "tay"))
    keep <- df$y2 > -0.5
    if (base == "tph") {
      keep[which(!df$subset)[[1L]]] <- TRUE
    }
    return(.testhelper_mark_domain(d, keep))
  }

  switch(
    name,
    tay = .cg_taylor(.cg_frame("tay")),
    tay_lab = .cg_taylor(.cg_frame("tay_lab")),
    tay_nofpc = .cg_taylor(.cg_frame("tay"), use_fpc = FALSE),
    tay_probs = as_survey(
      .cg_frame("tay"),
      ids = psu,
      strata = strata,
      probs = p,
      nest = TRUE
    ),
    srs = as_survey(.cg_frame("tay"), weights = wt),
    strat = as_survey(.cg_frame("tay"), strata = strata, weights = wt),
    multi = as_survey(
      .cg_frame("multi"),
      ids = c(psu, ssu),
      strata = strata,
      fpc = c(fpc, fpc2),
      weights = wt,
      nest = TRUE
    ),
    lonely = {
      df <- .cg_frame("tay")
      df$strata[df$psu == "psu_1"] <- "stratum_lonely"
      as_survey(df, ids = psu, strata = strata, weights = wt, nest = TRUE)
    },
    cal = {
      df <- .cg_frame("tay")
      as_survey(
        df,
        ids = psu,
        strata = strata,
        weights = cal_wt,
        nest = TRUE,
        calibration = list(.cg_caldata(df))
      )
    },
    cal_srs = {
      df <- .cg_frame("tay")
      as_survey(df, weights = cal_wt, calibration = list(.cg_caldata(df)))
    },
    cal_strat = {
      df <- .cg_frame("tay")
      as_survey(
        df,
        strata = strata,
        weights = cal_wt,
        calibration = list(.cg_caldata(df))
      )
    },
    cal_ids = {
      df <- .cg_frame("tay")
      as_survey(
        df,
        ids = psu,
        weights = cal_wt,
        calibration = list(.cg_caldata(df))
      )
    },
    cal_multi = {
      df <- .cg_frame("multi")
      as_survey(
        df,
        ids = c(psu, ssu),
        strata = strata,
        fpc = c(fpc, fpc2),
        weights = cal_wt,
        nest = TRUE,
        calibration = list(.cg_caldata(df))
      )
    },
    rep = .cg_replicate(.cg_frame("rep")),
    rep_na = {
      df <- .cg_frame("rep")
      df$repwt_3[[.cg_first_row(df, "B")]] <- NA
      .cg_replicate(df)
    },
    rep_inf = {
      df <- .cg_frame("rep")
      df$repwt_3[[.cg_first_row(df, "B")]] <- Inf
      .cg_replicate(df)
    },
    rep_zero = {
      df <- .cg_frame("rep")
      df$repwt_3[df$group == "B"] <- 0
      .cg_replicate(df)
    },
    rep_allna = {
      df <- .cg_frame("rep")
      b1 <- .cg_first_row(df, "B")
      for (col in grep("^repwt_", names(df), value = TRUE)) {
        df[[col]][[b1]] <- NA
      }
      .cg_replicate(df)
    },
    rep_allna_dom = {
      df <- .cg_frame("rep")
      a1 <- .cg_first_row(df, "A")
      for (col in grep("^repwt_", names(df), value = TRUE)) {
        df[[col]][[a1]] <- NA
      }
      .testhelper_mark_domain(.cg_replicate(df), seq_len(nrow(df)) != a1)
    },
    np_rep = .cg_np_replicate(.cg_frame("rep")),
    np_rep_na = {
      df <- .cg_frame("rep")
      df$repwt_3[[.cg_first_row(df, "B")]] <- NA
      .cg_np_replicate(df)
    },
    np_rep10_na = {
      df <- .cg_frame("rep10")
      df$repwt_3[[.cg_first_row(df, "A")]] <- NA
      .cg_np_replicate(df)
    },
    np_rep10_na_dom = {
      df <- .cg_frame("rep10")
      a1 <- .cg_first_row(df, "A")
      df$repwt_3[[a1]] <- NA
      .testhelper_mark_domain(.cg_np_replicate(df), seq_len(nrow(df)) != a1)
    },
    np_srs = as_survey_nonprob(.cg_frame("tay"), weights = wt),
    tph = as_survey_twophase(
      .cg_taylor(.cg_frame("tph")),
      subset = subset,
      method = "approx"
    ),
    tay_empty_dom = {
      df <- .cg_frame("tay")
      .testhelper_mark_domain(.cg_taylor(df), rep(FALSE, nrow(df)))
    },
    nawt_out = .cg_taylor(.cg_frame("tay"), weights = "wt_na_out"),
    nawt_in = .cg_taylor(.cg_frame("tay"), weights = "wt_na_in"),
    infwt = .cg_taylor(.cg_frame("tay"), weights = "wt_inf"),
    gss = .cg_gss(),
    allna_grp = make_all_na_group_design(),
    stop("Unknown golden design: ", name, call. = FALSE)
  )
}

# ------------------------------------------------------------------------------
# Comparison and warning helpers
# ------------------------------------------------------------------------------

cell_golden_fixture <- function() {
  path <- testthat::test_path("fixtures", "analysis-cell-golden.rds")
  if (!file.exists(path)) {
    stop("The golden fixture is missing: ", path, call. = FALSE)
  }
  readRDS(path)
}

# Removes the stored call from a result's .meta. The call holds the caller's
# text, not a computed value, and differs between the generator and the
# tests. Nothing else is removed.
cell_golden_strip <- function(x) {
  meta <- attr(x, ".meta", exact = TRUE)
  if (is.null(meta) || !("call" %in% names(meta))) {
    return(x)
  }
  meta$call <- NULL
  attr(x, ".meta") <- meta
  x
}

expect_matches_golden <- function(object, expected, label) {
  object <- cell_golden_strip(object)
  expect_equal(object, expected, tolerance = 1e-12, label = label)
  # The tolerance comparison treats NaN and NA as equal; these keep them
  # apart. The interval columns are left out: each one is arithmetic on the
  # estimate and the SE, and when one is NA and the other NaN, R returns
  # either, by platform (?NA). The fixture was captured on Windows, and
  # Linux and macOS return the other one. The tolerance comparison still
  # asserts that these columns are missing in the same cells.
  derived <- c("ci_low", "ci_high", "moe")
  for (nm in setdiff(names(expected), derived)) {
    if (is.double(expected[[nm]])) {
      expect_identical(
        is.nan(object[[nm]]),
        is.nan(expected[[nm]]),
        label = paste0(label, ": is.nan(", nm, ")")
      )
    }
  }
  expect_identical(
    is.nan(attr(object, ".vcov", exact = TRUE)),
    is.nan(attr(expected, ".vcov", exact = TRUE)),
    label = paste0(label, ": is.nan(.vcov)")
  )
}

# Asserts that expr raises exactly n warnings, one of each class in class,
# and returns the value of expr.
expect_warning_count <- function(expr, class, n) {
  class <- rep_len(class, n)
  value <- NULL
  nest <- function(i) {
    if (i > n) {
      value <<- expr
      return(invisible(NULL))
    }
    expect_warning(nest(i + 1L), class = class[[i]])
  }
  expect_no_warning(nest(1L))
  invisible(value)
}

# ------------------------------------------------------------------------------
# Core calls and the domain cross-check
# ------------------------------------------------------------------------------

.cg_variance <- c("se", "ci", "var", "cv", "moe", "deff")

cell_core_calls <- function(d, freqs_x = "f5", min_cell_n = 0L) {
  list(
    freqs = function() {
      get_freqs(
        d,
        tidyselect::all_of(freqs_x),
        group = group,
        variance = .cg_variance,
        n_weighted = TRUE,
        min_cell_n = min_cell_n
      )
    },
    means = function() {
      get_means(
        d,
        y1,
        group = group,
        variance = .cg_variance,
        n_weighted = TRUE,
        min_cell_n = min_cell_n
      )
    },
    totals = function() {
      get_totals(
        d,
        y1,
        group = group,
        variance = .cg_variance,
        n_weighted = TRUE,
        min_cell_n = min_cell_n
      )
    },
    variance = function() {
      get_variance(
        d,
        c(y1, y2),
        group = group,
        variance = .cg_variance,
        n_weighted = TRUE,
        min_cell_n = min_cell_n
      )
    },
    covariance = function() {
      get_covariance(
        d,
        c(y1, y2, y3),
        group = group,
        variance = .cg_variance,
        n_weighted = TRUE,
        min_cell_n = min_cell_n
      )
    },
    ratios = function() {
      get_ratios(
        d,
        y3,
        y1,
        group = group,
        variance = .cg_variance,
        n_weighted = TRUE,
        min_cell_n = min_cell_n
      )
    }
  )
}

# Asserts that the rows of grouped scenario `id` for each group in `groups`
# equal an ungrouped call on `design` restricted to that group.
# `ungrouped` is a function of one design; `estimate` names the estimate
# column.
expect_groups_match_domain <- function(
  id,
  design,
  ungrouped,
  estimate,
  groups = c("A", "C")
) {
  grouped <- cell_golden_scenarios()[[id]]()
  for (g in groups) {
    d <- cell_golden_design(design)
    marked <- .testhelper_mark_domain(d, survey_data(d)$group == g)
    single <- ungrouped(marked)
    rows <- !is.na(grouped$group) & grouped$group == g
    expect_equal(
      as.vector(grouped[[estimate]][rows]),
      as.vector(single[[estimate]]),
      tolerance = 1e-12,
      label = paste0(id, " group ", g, ": ", estimate)
    )
    expect_equal(
      as.vector(grouped$se[rows]),
      as.vector(single$se),
      tolerance = 1e-12,
      label = paste0(id, " group ", g, ": se")
    )
  }
}

# ------------------------------------------------------------------------------
# Scenario catalogue (261 scenarios)
# ------------------------------------------------------------------------------

# Runs fn on the named design with the standard options.
.cg_std <- function(fn, design, ...) {
  fn(
    cell_golden_design(design),
    ...,
    variance = .cg_variance,
    n_weighted = TRUE,
    min_cell_n = 0L
  )
}

# Runs fn on the named design with only the arguments given.
.cg_raw <- function(fn, design, ...) {
  fn(cell_golden_design(design), ...)
}

.cg_core_designs <- c(
  "tay",
  "tay_nofpc",
  "tay_probs",
  "srs",
  "strat",
  "multi",
  "lonely_remove",
  "lonely_adjust",
  "lonely_average",
  "lonely_certainty",
  "cal",
  "rep",
  "np_rep",
  "tph",
  "tay_dom",
  "rep_dom",
  "cal_dom",
  "np_rep_dom",
  "tph_dom",
  "tay_fail"
)

.cg_core_functions <- c(
  "freqs",
  "means",
  "totals",
  "variance",
  "covariance",
  "ratios"
)

.cg_core_scenario <- function(fn, design) {
  force(fn)
  force(design)
  function() {
    if (startsWith(design, "lonely_")) {
      withr::local_options(survey.lonely.psu = sub("^lonely_", "", design))
      d <- cell_golden_design("lonely")
    } else if (design == "tay_fail") {
      withr::local_options(survey.lonely.psu = "fail")
      d <- cell_golden_design("tay")
    } else {
      d <- cell_golden_design(design)
    }
    cell_core_calls(d)[[fn]]()
  }
}

# A named list of zero-argument functions, one per scenario id. Each builds
# its design and returns the result.
cell_golden_scenarios <- function() {
  core <- list()
  for (fn in .cg_core_functions) {
    for (design in .cg_core_designs) {
      core[[paste0(fn, "/", design)]] <- .cg_core_scenario(fn, design)
    }
  }
  c(
    core,
    .cg_extra_freqs(),
    .cg_extra_means(),
    .cg_extra_totals(),
    .cg_extra_variance(),
    .cg_extra_covariance(),
    .cg_extra_ratios(),
    .cg_extra_second()
  )
}

.cg_extra_freqs <- function() {
  list(
    "freqs/tay_ungrouped" = function() .cg_std(get_freqs, "tay", f5),
    "freqs/tay_multi_na" = function() {
      .cg_std(get_freqs, "tay", c(y3, f5_na), na.rm = FALSE)
    },
    "freqs/tay_two_groups" = function() {
      .cg_std(get_freqs, "tay", y3, group = c(group, f5))
    },
    "freqs/tay_default_variance" = function() {
      .cg_raw(get_freqs, "tay", f5, group = group, min_cell_n = 0L)
    },
    "freqs/cal_srs" = function() {
      .cg_std(get_freqs, "cal_srs", f5, group = group)
    },
    "freqs/gss" = function() .cg_std(get_freqs, "gss", partyid, group = race),
    "freqs/gss_multi" = function() {
      .cg_std(get_freqs, "gss", c(partyid, happy))
    },
    "freqs/rep_na" = function() .cg_std(get_freqs, "rep_na", f5, group = group),
    "freqs/rep_inf" = function() {
      .cg_std(get_freqs, "rep_inf", f5, group = group)
    },
    "freqs/rep_zero" = function() {
      .cg_std(get_freqs, "rep_zero", f5, group = group)
    },
    "freqs/np_rep_na" = function() {
      .cg_std(get_freqs, "np_rep_na", f5, group = group)
    },
    "freqs/lab_broom" = function() {
      .cg_std(
        get_freqs,
        "tay_lab",
        y3,
        group = group,
        label_values = TRUE,
        label_vars = TRUE,
        name_style = "broom"
      )
    },
    # The plan lists these as noisy; cell_golden_noisy records which warn.
    "freqs/np_srs" = function() .cg_std(get_freqs, "np_srs", y3),
    "freqs/single" = function() .cg_std(get_freqs, "tay", f5, group = single),
    "freqs/np_rep10_na_dom" = function() {
      .cg_std(get_freqs, "np_rep10_na_dom", y3)
    },
    "freqs/tay_empty_dom" = function() .cg_std(get_freqs, "tay_empty_dom", f5)
  )
}

.cg_extra_means <- function() {
  list(
    "means/tay_ungrouped" = function() .cg_std(get_means, "tay", y1),
    "means/tay_two_groups" = function() {
      .cg_std(get_means, "tay", y1, group = c(group, f5))
    },
    "means/tay_default_variance" = function() {
      .cg_raw(get_means, "tay", y1, group = group, min_cell_n = 0L)
    },
    "means/cal_srs" = function() {
      .cg_std(get_means, "cal_srs", y1, group = group)
    },
    "means/cal_strat" = function() {
      .cg_std(get_means, "cal_strat", y1, group = group)
    },
    "means/cal_ids" = function() {
      .cg_std(get_means, "cal_ids", y1, group = group)
    },
    "means/cal_multi" = function() {
      .cg_std(get_means, "cal_multi", y1, group = group)
    },
    "means/gss" = function() .cg_std(get_means, "gss", age, group = degree),
    "means/gss_two_groups" = function() {
      .cg_std(get_means, "gss", age, group = c(sex, race))
    },
    "means/tay_y1_na" = function() {
      .cg_std(get_means, "tay", y1_na, group = group, na.rm = FALSE)
    },
    "means/cal_y1_na" = function() {
      .cg_std(get_means, "cal", y1_na, group = group, na.rm = FALSE)
    },
    "means/multi_y1_na" = function() {
      .cg_std(get_means, "multi", y1_na, group = group, na.rm = FALSE)
    },
    "means/tay_y1_inf" = function() {
      .cg_std(get_means, "tay", y1_inf, group = group)
    },
    "means/tay_c_na" = function() {
      .cg_std(get_means, "tay", y1_c_na, group = group)
    },
    "means/tay_allna" = function() .cg_std(get_means, "tay", y_allna),
    "means/tay_empty_dom" = function() .cg_std(get_means, "tay_empty_dom", y1),
    "means/tay_group_na" = function() {
      .cg_std(get_means, "tay", y1, group = group_na, na.rm = FALSE)
    },
    "means/rep_na" = function() .cg_std(get_means, "rep_na", y1, group = group),
    "means/rep_inf" = function() {
      .cg_std(get_means, "rep_inf", y1, group = group)
    },
    "means/rep_y1_inf" = function() {
      .cg_std(get_means, "rep", y1_inf, group = group)
    },
    "means/np_rep_y1_inf" = function() {
      .cg_std(get_means, "np_rep", y1_inf, group = group)
    },
    "means/infwt" = function() .cg_std(get_means, "infwt", y1),
    "means/lab_broom" = function() {
      .cg_std(
        get_means,
        "tay_lab",
        y1,
        group = group,
        label_values = TRUE,
        label_vars = TRUE,
        name_style = "broom"
      )
    },
    # The plan lists these as noisy; cell_golden_noisy records which warn.
    "means/np_srs" = function() .cg_std(get_means, "np_srs", y1, group = group),
    "means/single" = function() .cg_std(get_means, "tay", y1, group = single),
    "means/zero_combos" = function() {
      .cg_std(get_means, "allna_grp", y1, group = grp)
    },
    "means/small_cell" = function() {
      .cg_raw(
        get_means,
        "tay",
        y1,
        group = c(group, f5),
        variance = .cg_variance,
        n_weighted = TRUE,
        min_cell_n = 1000L
      )
    },
    "means/np_rep_y1_na" = function() {
      .cg_std(get_means, "np_rep", y1_na, group = group, na.rm = FALSE)
    },
    "means/np_srs_dom" = function() {
      .cg_std(get_means, "np_srs_dom", y1, group = group)
    },
    "means/cal_srs_two" = function() {
      .cg_std(get_means, "cal_srs", y1, group = g_two)
    }
  )
}

.cg_extra_totals <- function() {
  list(
    "totals/tay_ungrouped" = function() .cg_std(get_totals, "tay", y1),
    "totals/tay_categorical" = function() {
      .cg_std(get_totals, "tay", f5, group = group)
    },
    "totals/tay_popsize" = function() .cg_std(get_totals, "tay", group = group),
    "totals/gss" = function() .cg_std(get_totals, "gss", age, group = degree),
    "totals/tay_y1_na" = function() {
      .cg_std(get_totals, "tay", y1_na, group = group, na.rm = FALSE)
    },
    "totals/multi_y1_na" = function() {
      .cg_std(get_totals, "multi", y1_na, group = group, na.rm = FALSE)
    },
    "totals/tay_y1_inf" = function() {
      .cg_std(get_totals, "tay", y1_inf, group = group)
    },
    "totals/tay_c_na" = function() {
      .cg_std(get_totals, "tay", y1_c_na, group = group)
    },
    "totals/tay_empty_dom" = function() {
      .cg_std(get_totals, "tay_empty_dom", y1)
    },
    "totals/rep_na" = function() {
      .cg_std(get_totals, "rep_na", y1, group = group)
    },
    "totals/rep_inf" = function() {
      .cg_std(get_totals, "rep_inf", y1, group = group)
    },
    "totals/infwt" = function() .cg_std(get_totals, "infwt", y1),
    # The plan lists these as noisy; cell_golden_noisy records which warn.
    "totals/np_srs" = function() {
      .cg_std(get_totals, "np_srs", y1, group = group)
    },
    "totals/single" = function() .cg_std(get_totals, "tay", y1, group = single),
    "totals/zero_combos" = function() {
      .cg_std(get_totals, "allna_grp", y1, group = grp)
    },
    "totals/small_cell" = function() {
      .cg_raw(
        get_totals,
        "tay",
        y1,
        group = group,
        variance = .cg_variance,
        n_weighted = TRUE,
        min_cell_n = 1000L
      )
    },
    "totals/tay_allna" = function() .cg_std(get_totals, "tay", y_allna),
    "totals/np_rep10_na_dom" = function() {
      .cg_std(get_totals, "np_rep10_na_dom", y1)
    }
  )
}

.cg_extra_variance <- function() {
  list(
    "variance/blk16" = function() .cg_std(get_variance, "tay", y1, group = g16),
    "variance/blk17" = function() .cg_std(get_variance, "tay", y1, group = g17),
    "variance/blk32" = function() .cg_std(get_variance, "tay", y1, group = g32),
    "variance/blk33" = function() .cg_std(get_variance, "tay", y1, group = g33),
    "variance/blk64" = function() .cg_std(get_variance, "tay", y1, group = g64),
    "variance/blk65" = function() .cg_std(get_variance, "tay", y1, group = g65),
    "variance/tay_one_cell" = function() .cg_std(get_variance, "tay", y1),
    "variance/tay_ungrouped" = function() {
      .cg_std(get_variance, "tay", c(y1, y2))
    },
    "variance/tay_listwise" = function() {
      .cg_std(
        get_variance,
        "tay",
        c(y1, y1_na),
        group = group,
        na_handling = "listwise"
      )
    },
    "variance/tay_narm_false" = function() {
      .cg_std(get_variance, "tay", c(y1, y1_na), group = group, na.rm = FALSE)
    },
    "variance/tay_many" = function() {
      .cg_std(
        get_variance,
        "tay",
        c(y1, y2, y3, y1_na, y2_a_na),
        group = c(group, f5)
      )
    },
    "variance/tay_c_na" = function() {
      .cg_std(get_variance, "tay", c(y1, y1_c_na, y2), group = group)
    },
    "variance/tay_empty_dom" = function() {
      .cg_std(get_variance, "tay_empty_dom", c(y1, y2))
    },
    "variance/gss" = function() {
      .cg_std(get_variance, "gss", age, group = degree)
    },
    "variance/tay_y1_inf" = function() {
      .cg_std(get_variance, "tay", y1_inf, group = group)
    },
    "variance/nawt_out" = function() {
      .cg_std(get_variance, "nawt_out", y2_a_na, group = group)
    },
    "variance/rep_na" = function() {
      .cg_std(get_variance, "rep_na", c(y1, y2), group = group)
    },
    "variance/blk65_inf" = function() {
      .cg_std(get_variance, "tay", y1_inf65, group = g65)
    },
    # The plan lists these as noisy; cell_golden_noisy records which warn.
    "variance/np_srs" = function() .cg_std(get_variance, "np_srs", y1),
    "variance/single" = function() {
      .cg_std(get_variance, "tay", y1, group = single)
    },
    "variance/zero_combos" = function() {
      .cg_std(get_variance, "allna_grp", c(y1, y2), group = grp)
    },
    "variance/small_cell" = function() {
      .cg_raw(
        get_variance,
        "tay",
        y1,
        group = group,
        variance = .cg_variance,
        n_weighted = TRUE,
        min_cell_n = 1000L
      )
    },
    "variance/tay_allna" = function() .cg_std(get_variance, "tay", y_allna),
    "variance/tay_one" = function() {
      .cg_std(get_variance, "tay", y1, group = g_one)
    },
    "variance/np_rep10_na" = function() {
      .cg_std(get_variance, "np_rep10_na", y1, group = group)
    },
    "variance/blk65_gap" = function() {
      .cg_std(get_variance, "tay", y1_gap, group = g65)
    }
  )
}

.cg_extra_covariance <- function() {
  list(
    "covariance/tay_pair" = function() {
      .cg_std(get_covariance, "tay", c(y1, y2))
    },
    "covariance/tay_ungrouped" = function() {
      .cg_std(get_covariance, "tay", c(y1, y2, y3))
    },
    "covariance/tay_full" = function() {
      .cg_std(
        get_covariance,
        "tay",
        c(y1, y2, y3),
        group = group,
        redundant = TRUE,
        diagonal = TRUE
      )
    },
    "covariance/tay_narm_false" = function() {
      .cg_std(
        get_covariance,
        "tay",
        c(y1, y1_na, y2),
        group = group,
        na.rm = FALSE
      )
    },
    "covariance/tay_many" = function() {
      .cg_std(
        get_covariance,
        "tay",
        c(y1, y2, y3),
        group = c(group, f5),
        diagonal = TRUE
      )
    },
    "covariance/tay_c_na" = function() {
      .cg_std(get_covariance, "tay", c(y1, y1_c_na, y2), group = group)
    },
    "covariance/tay_empty_dom" = function() {
      .cg_std(get_covariance, "tay_empty_dom", c(y1, y2))
    },
    "covariance/gss" = function() {
      .cg_std(get_covariance, "gss", c(age, educ), group = degree)
    },
    "covariance/tay_y1_inf" = function() {
      .cg_std(get_covariance, "tay", c(y1_inf, y2), group = group)
    },
    "covariance/nawt_out" = function() {
      .cg_std(get_covariance, "nawt_out", c(y2_a_na, y1), group = group)
    },
    "covariance/rep_na" = function() {
      .cg_std(get_covariance, "rep_na", c(y1, y2), group = group)
    },
    "covariance/blk16" = function() {
      .cg_std(get_covariance, "tay", c(y1, y2), group = g16)
    },
    "covariance/blk17" = function() {
      .cg_std(get_covariance, "tay", c(y1, y2), group = g17)
    },
    "covariance/blk32" = function() {
      .cg_std(get_covariance, "tay", c(y1, y2), group = g32)
    },
    "covariance/blk33" = function() {
      .cg_std(get_covariance, "tay", c(y1, y2), group = g33)
    },
    "covariance/blk64" = function() {
      .cg_std(get_covariance, "tay", c(y1, y2), group = g64)
    },
    "covariance/blk65" = function() {
      .cg_std(get_covariance, "tay", c(y1, y2), group = g65)
    },
    "covariance/blk65_inf" = function() {
      .cg_std(get_covariance, "tay", c(y1_inf65, y2), group = g65)
    },
    # The plan lists these as noisy; cell_golden_noisy records which warn.
    "covariance/np_srs" = function() {
      .cg_std(get_covariance, "np_srs", c(y1, y2))
    },
    "covariance/single" = function() {
      .cg_std(get_covariance, "tay", c(y1, y2), group = single)
    },
    "covariance/zero_combos" = function() {
      .cg_std(get_covariance, "allna_grp", c(y1, y2), group = grp)
    },
    "covariance/small_cell" = function() {
      .cg_raw(
        get_covariance,
        "tay",
        c(y1, y2),
        group = group,
        variance = .cg_variance,
        n_weighted = TRUE,
        min_cell_n = 1000L
      )
    },
    "covariance/tay_allna" = function() {
      .cg_std(get_covariance, "tay", c(y_allna, y1))
    },
    "covariance/tay_one" = function() {
      .cg_std(get_covariance, "tay", c(y1, y2), group = g_one)
    },
    "covariance/np_rep10_na" = function() {
      .cg_std(get_covariance, "np_rep10_na", c(y1, y2), group = group)
    }
  )
}

.cg_extra_ratios <- function() {
  list(
    "ratios/tay_ungrouped" = function() .cg_std(get_ratios, "tay", y3, y1),
    "ratios/gss" = function() {
      .cg_std(get_ratios, "gss", educ, age, group = degree)
    },
    "ratios/tay_num_na" = function() {
      .cg_std(get_ratios, "tay", y3_na, y1, group = group, na.rm = FALSE)
    },
    "ratios/tay_den_na" = function() {
      .cg_std(get_ratios, "tay", y3, y1_na, group = group, na.rm = FALSE)
    },
    "ratios/multi_num_na" = function() {
      .cg_std(get_ratios, "multi", y3_na, y1, group = group, na.rm = FALSE)
    },
    "ratios/tay_c_zero_den" = function() {
      .cg_std(
        get_ratios,
        "tay",
        y3_c_na,
        y1_c_zero,
        group = group,
        na.rm = FALSE
      )
    },
    "ratios/tay_c_na" = function() {
      .cg_std(get_ratios, "tay", y3_c_na, y1, group = group)
    },
    "ratios/tay_empty_dom" = function() {
      .cg_std(get_ratios, "tay_empty_dom", y3, y1)
    },
    "ratios/tay_allna" = function() .cg_std(get_ratios, "tay", y_allna, y1),
    "ratios/rep_na" = function() {
      .cg_std(get_ratios, "rep_na", y3, y1, group = group)
    },
    "ratios/blk16" = function() .cg_std(get_ratios, "tay", y3, y1, group = g16),
    "ratios/blk17" = function() .cg_std(get_ratios, "tay", y3, y1, group = g17),
    "ratios/blk32" = function() .cg_std(get_ratios, "tay", y3, y1, group = g32),
    "ratios/blk33" = function() .cg_std(get_ratios, "tay", y3, y1, group = g33),
    "ratios/blk64" = function() .cg_std(get_ratios, "tay", y3, y1, group = g64),
    "ratios/blk65" = function() .cg_std(get_ratios, "tay", y3, y1, group = g65),
    "ratios/blk65_na" = function() {
      .cg_std(get_ratios, "tay", y3_na65, y1, group = g65, na.rm = FALSE)
    },
    # The plan lists these as noisy; cell_golden_noisy records which warn.
    "ratios/np_srs" = function() .cg_std(get_ratios, "np_srs", y3, y1),
    "ratios/single" = function() {
      .cg_std(get_ratios, "tay", y3, y1, group = single)
    },
    "ratios/zero_combos" = function() {
      .cg_std(get_ratios, "allna_grp", y3, y1, group = grp)
    },
    "ratios/small_cell" = function() {
      .cg_raw(
        get_ratios,
        "tay",
        y3,
        y1,
        group = group,
        variance = .cg_variance,
        n_weighted = TRUE,
        min_cell_n = 1000L
      )
    },
    "ratios/np_rep10_na_dom" = function() {
      .cg_std(get_ratios, "np_rep10_na_dom", y3, y1)
    }
  )
}

.cg_quantiles <- function(design) {
  force(design)
  function() {
    .cg_raw(
      get_quantiles,
      design,
      y1,
      group = group,
      variance = c("se", "ci"),
      min_cell_n = 0L
    )
  }
}

.cg_extra_second <- function() {
  list(
    "quantiles/tay" = .cg_quantiles("tay"),
    "quantiles/rep" = .cg_quantiles("rep"),
    "quantiles/cal" = .cg_quantiles("cal"),
    "effn/tay" = function() {
      .cg_raw(
        get_effective_n,
        "tay",
        y1,
        group = group,
        method = "deff",
        min_cell_n = 0L
      )
    }
  )
}

# ------------------------------------------------------------------------------
# Noisy scenarios and the warnings each raises on the base commit
# ------------------------------------------------------------------------------

# Each entry lists the class of every warning the scenario raises, one
# element per warning, as the fixture records them. The fixture was
# generated on the base commit, and its recorded warnings win over the
# plan's reasoned counts.
cell_golden_noisy <- list(
  "covariance/tay" = c("surveycore_warning_cv_undefined"),
  "covariance/tay_nofpc" = c("surveycore_warning_cv_undefined"),
  "covariance/tay_probs" = c("surveycore_warning_cv_undefined"),
  "covariance/srs" = c("surveycore_warning_cv_undefined"),
  "covariance/strat" = c("surveycore_warning_cv_undefined"),
  "covariance/multi" = c("surveycore_warning_cv_undefined"),
  "covariance/lonely_remove" = c("surveycore_warning_cv_undefined"),
  "covariance/lonely_adjust" = c("surveycore_warning_cv_undefined"),
  "covariance/lonely_average" = c("surveycore_warning_cv_undefined"),
  "covariance/lonely_certainty" = c("surveycore_warning_cv_undefined"),
  "covariance/cal" = c("surveycore_warning_cv_undefined"),
  "covariance/rep" = c("surveycore_warning_cv_undefined"),
  "covariance/np_rep" = c("surveycore_warning_cv_undefined"),
  "covariance/tph" = c("surveycore_warning_cv_undefined"),
  "covariance/tay_dom" = c("surveycore_warning_cv_undefined"),
  "covariance/rep_dom" = c("surveycore_warning_cv_undefined"),
  "covariance/cal_dom" = c("surveycore_warning_cv_undefined"),
  "covariance/np_rep_dom" = c("surveycore_warning_cv_undefined"),
  "covariance/tph_dom" = c("surveycore_warning_cv_undefined"),
  "covariance/tay_fail" = c("surveycore_warning_cv_undefined"),
  "freqs/np_srs" = c(
    "surveycore_warning_nonprob_srs_fallback",
    "surveycore_warning_nonprob_srs_fallback"
  ),
  "freqs/single" = c("surveycore_warning_single_level"),
  "freqs/np_rep10_na_dom" = c(
    "surveycore_warning_domain_replicates_na",
    "surveycore_warning_domain_replicates_na"
  ),
  "freqs/tay_empty_dom" = c("surveycore_warning_all_na_freqs"),
  "means/np_srs" = c(
    "surveycore_warning_nonprob_srs_fallback",
    "surveycore_warning_nonprob_srs_fallback",
    "surveycore_warning_nonprob_srs_fallback"
  ),
  "means/single" = c("surveycore_warning_single_level"),
  "means/zero_combos" = c("surveycore_warning_single_level"),
  "means/small_cell" = c("surveycore_warning_small_cell"),
  "means/np_rep_y1_na" = c("surveycore_warning_domain_replicates_na"),
  "means/np_srs_dom" = c(
    "surveycore_warning_nonprob_srs_fallback",
    "surveycore_warning_nonprob_srs_fallback",
    "surveycore_warning_nonprob_srs_fallback"
  ),
  "means/cal_srs_two" = c("surveycore_warning_zero_df_after_calibration"),
  "totals/np_srs" = c(
    "surveycore_warning_nonprob_srs_fallback",
    "surveycore_warning_nonprob_srs_fallback",
    "surveycore_warning_nonprob_srs_fallback"
  ),
  "totals/single" = c("surveycore_warning_single_level"),
  "totals/zero_combos" = c("surveycore_warning_single_level"),
  "totals/small_cell" = c("surveycore_warning_small_cell"),
  "totals/np_rep10_na_dom" = c("surveycore_warning_domain_replicates_na"),
  "variance/tay_c_na" = c("surveycore_warning_variance_all_na"),
  "variance/np_srs" = c("surveycore_warning_nonprob_srs_fallback"),
  "variance/single" = c("surveycore_warning_single_level"),
  "variance/zero_combos" = c("surveycore_warning_single_level"),
  "variance/small_cell" = c("surveycore_warning_small_cell"),
  "variance/tay_allna" = c("surveycore_warning_variance_all_na"),
  "variance/tay_one" = c("surveycore_warning_variance_insufficient_n"),
  "variance/np_rep10_na" = c("surveycore_warning_domain_replicates_na"),
  "variance/blk65_gap" = c("surveycore_warning_variance_insufficient_n"),
  "covariance/tay_ungrouped" = c("surveycore_warning_cv_undefined"),
  "covariance/tay_full" = c("surveycore_warning_cv_undefined"),
  "covariance/tay_narm_false" = c("surveycore_warning_cv_undefined"),
  "covariance/tay_many" = c("surveycore_warning_cv_undefined"),
  "covariance/tay_c_na" = c(
    "surveycore_warning_covariance_all_na",
    "surveycore_warning_covariance_all_na",
    "surveycore_warning_cv_undefined"
  ),
  "covariance/gss" = c("surveycore_warning_cv_undefined"),
  "covariance/tay_y1_inf" = c("surveycore_warning_cv_undefined"),
  "covariance/nawt_out" = c("surveycore_warning_cv_undefined"),
  "covariance/rep_na" = c("surveycore_warning_cv_undefined"),
  "covariance/blk16" = c("surveycore_warning_cv_undefined"),
  "covariance/blk17" = c("surveycore_warning_cv_undefined"),
  "covariance/blk32" = c("surveycore_warning_cv_undefined"),
  "covariance/blk33" = c("surveycore_warning_cv_undefined"),
  "covariance/blk64" = c("surveycore_warning_cv_undefined"),
  "covariance/blk65" = c("surveycore_warning_cv_undefined"),
  "covariance/blk65_inf" = c("surveycore_warning_cv_undefined"),
  "covariance/np_srs" = c("surveycore_warning_nonprob_srs_fallback"),
  "covariance/single" = c("surveycore_warning_single_level"),
  "covariance/zero_combos" = c("surveycore_warning_single_level"),
  "covariance/small_cell" = c(
    "surveycore_warning_small_cell",
    "surveycore_warning_cv_undefined"
  ),
  "covariance/tay_allna" = c("surveycore_warning_covariance_all_na"),
  "covariance/tay_one" = c("surveycore_warning_covariance_insufficient_n"),
  "covariance/np_rep10_na" = c(
    "surveycore_warning_domain_replicates_na",
    "surveycore_warning_cv_undefined"
  ),
  "ratios/blk64" = c("surveycore_warning_cv_undefined"),
  "ratios/blk65" = c("surveycore_warning_cv_undefined"),
  "ratios/blk65_na" = c("surveycore_warning_cv_undefined"),
  "ratios/np_srs" = c(
    "surveycore_warning_nonprob_srs_fallback",
    "surveycore_warning_nonprob_srs_fallback",
    "surveycore_warning_nonprob_srs_fallback"
  ),
  "ratios/single" = c("surveycore_warning_single_level"),
  "ratios/zero_combos" = c("surveycore_warning_single_level"),
  "ratios/small_cell" = c("surveycore_warning_small_cell"),
  "ratios/np_rep10_na_dom" = c(
    "surveycore_warning_domain_replicates_na",
    "surveycore_warning_domain_replicates_na"
  )
)
