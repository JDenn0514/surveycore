# tests/testthat/test-s7-classes.R
#
# Tests for S7 class definitions in R/00-s7-classes.R.
#
# Coverage: error-messages.md rows 31–35 (S7 Layer 1 validator errors).
# Per testing-standards.md: validator errors use expect_error(class=) only
# — no expect_snapshot(), because S7 validator messages are not CLI-formatted
# the same way as Layer 3 constructor errors.

# ── Helpers ────────────────────────────────────────────────────────────────────

# Build a minimal variables list for survey_taylor with all keys present.
.taylor_vars <- function(
  weights = "wt",
  ids = NULL,
  strata = NULL,
  fpc = NULL,
  nest = FALSE,
  probs_provided = FALSE
) {
  list(
    ids = ids,
    weights = weights,
    strata = strata,
    fpc = fpc,
    nest = nest,
    probs_provided = probs_provided,
    visible_vars = NULL
  )
}

# Build a minimal variables list for survey_replicate with all keys present.
.rep_vars <- function(
  weights = "wt",
  repweights = c("rw1", "rw2"),
  type = "BRR",
  scale = 1,
  rscales = NULL,
  fpc = NULL,
  fpctype = "fraction",
  mse = TRUE
) {
  list(
    weights = weights,
    repweights = repweights,
    type = type,
    scale = scale,
    rscales = rscales,
    fpc = fpc,
    fpctype = fpctype,
    mse = mse,
    visible_vars = NULL
  )
}

# A small valid data frame for survey_taylor tests.
.df10 <- function(seed = 42L) {
  set.seed(seed)
  data.frame(
    psu = paste0("psu_", rep(1:5, 2)),
    strata = paste0("s", rep(1:2, each = 5)),
    fpc = rep(c(500L, 600L), each = 5),
    wt = runif(10, 0.5, 2),
    y = rnorm(10),
    stringsAsFactors = FALSE
  )
}

# A small valid data frame for survey_replicate tests.
.df_rep <- function(R = 4L, seed = 42L) {
  set.seed(seed)
  df <- data.frame(
    wt = runif(20, 0.5, 2),
    y = rnorm(20),
    stringsAsFactors = FALSE
  )
  for (i in seq_len(R)) {
    df[[paste0("rw", i)]] <- runif(20, 0.3, 3)
  }
  df
}


# ── survey_metadata ────────────────────────────────────────────────────────────

test_that("survey_metadata() creates object with empty default lists", {
  m <- survey_metadata()
  expect_true(S7::S7_inherits(m, survey_metadata))
  expect_identical(m@variable_labels, list())
  expect_identical(m@value_labels, list())
  expect_identical(m@question_prefaces, list())
  expect_identical(m@notes, list())
  expect_identical(m@transformations, list())
})

test_that("survey_metadata() stores variable labels correctly", {
  m <- survey_metadata(
    variable_labels = list(age = "Age in years", income = "Annual income")
  )
  expect_identical(m@variable_labels$age, "Age in years")
  expect_identical(m@variable_labels$income, "Annual income")
})

test_that("survey_metadata() stores value labels correctly", {
  m <- survey_metadata(
    value_labels = list(sex = c(Male = 1L, Female = 2L))
  )
  expect_identical(m@value_labels$sex, c(Male = 1L, Female = 2L))
})

test_that("survey_metadata() stores universe as empty list by default", {
  m <- survey_metadata()
  expect_identical(m@universe, list())
})

test_that("survey_metadata() stores missing_codes as empty list by default", {
  m <- survey_metadata()
  expect_identical(m@missing_codes, list())
})

test_that("survey_metadata(universe = list(...)) stores value correctly", {
  m <- survey_metadata(
    universe = list(age = "Adults 18+", income = "All respondents")
  )
  expect_identical(m@universe$age, "Adults 18+")
  expect_identical(m@universe$income, "All respondents")
})

test_that("survey_metadata(missing_codes = list(...)) stores value correctly", {
  m <- survey_metadata(missing_codes = list(age = c(Refused = 99L, DK = 98L)))
  expect_identical(m@missing_codes$age, c(Refused = 99L, DK = 98L))
})

test_that("universe @ assignment round-trips on survey_metadata object", {
  m <- survey_metadata()
  m@universe <- list(income = "Employed adults")
  expect_identical(m@universe$income, "Employed adults")
})

test_that("missing_codes @ assignment round-trips on survey_metadata object", {
  m <- survey_metadata()
  m@missing_codes <- list(age = c(-1L, -2L))
  expect_identical(m@missing_codes$age, c(-1L, -2L))
})

test_that("survey_metadata() defaults @var_extra to an empty list", {
  m <- survey_metadata()
  expect_identical(m@var_extra, list())
})

test_that("survey_metadata(var_extra = list(...)) stores the value unchanged", {
  payload <- list(age = list(role = "demographic"))
  m <- survey_metadata(var_extra = payload)
  expect_identical(m@var_extra, payload)
})


# ── survey_base ────────────────────────────────────────────────────────────────

test_that("survey_base cannot be instantiated directly (abstract class)", {
  df <- data.frame(x = 1)
  expect_error(
    survey_base(data = df),
    regexp = "abstract"
  )
})


# ── survey_taylor — happy paths ────────────────────────────────────────────────

test_that("survey_taylor() creates valid object for simple random sample", {
  df <- data.frame(y = rnorm(20), wt = runif(20, 0.5, 2))
  d <- survey_taylor(
    data = df,
    variables = .taylor_vars(weights = "wt")
  )
  test_invariants(d)
  expect_true(S7::S7_inherits(d, survey_taylor))
  expect_identical(d@variables$weights, "wt")
  expect_identical(d@variables$ids, NULL)
  expect_identical(d@variables$strata, NULL)
  expect_identical(d@variables$fpc, NULL)
  expect_false(d@variables$nest)
  expect_false(d@variables$probs_provided)
})

test_that("survey_taylor() creates valid object for stratified cluster design", {
  set.seed(42)
  df <- .df10()
  d <- survey_taylor(
    data = df,
    variables = .taylor_vars(
      weights = "wt",
      ids = "psu",
      strata = "strata",
      fpc = "fpc",
      nest = TRUE
    )
  )
  expect_true(S7::S7_inherits(d, survey_taylor))
  expect_identical(d@variables$ids, "psu")
  expect_identical(d@variables$strata, "strata")
  expect_identical(d@variables$fpc, "fpc")
  expect_true(d@variables$nest)
})

test_that("survey_taylor() creates valid object for two-stage cluster design", {
  df <- data.frame(
    psu = paste0("p", rep(1:5, 4)),
    ssu = paste0("s", rep(1:4, 5)),
    wt = runif(20, 1, 3),
    y = rnorm(20),
    stringsAsFactors = FALSE
  )
  d <- survey_taylor(
    data = df,
    variables = .taylor_vars(
      weights = "wt",
      ids = c("psu", "ssu")
    )
  )
  expect_identical(d@variables$ids, c("psu", "ssu"))
})

test_that("survey_taylor() allows NA weights (non-NA must be positive)", {
  df <- data.frame(
    wt = c(1.0, NA_real_, 2.0, 0.5),
    y = 1:4
  )
  d <- survey_taylor(
    data = df,
    variables = .taylor_vars(weights = "wt")
  )
  expect_true(is.na(d@data$wt[2]))
})

test_that("survey_taylor() has @groups = character(0) in Phase 0", {
  df <- data.frame(y = 1:5, wt = rep(1, 5))
  d <- survey_taylor(
    data = df,
    variables = .taylor_vars(weights = "wt")
  )
  expect_identical(d@groups, character(0))
})

test_that("survey_taylor() inherits from survey_base", {
  df <- data.frame(y = 1:5, wt = rep(1, 5))
  d <- survey_taylor(
    data = df,
    variables = .taylor_vars(weights = "wt")
  )
  expect_true(S7::S7_inherits(d, survey_base))
})

test_that("survey_taylor() stores empty survey_metadata by default", {
  df <- data.frame(y = 1:5, wt = rep(1, 5))
  d <- survey_taylor(
    data = df,
    variables = .taylor_vars(weights = "wt")
  )
  expect_true(S7::S7_inherits(d@metadata, survey_metadata))
  expect_identical(d@metadata@variable_labels, list())
})


# ── survey_taylor — validator error paths (errors 31–35) ──────────────────────

test_that("survey_taylor validator: error 31 — design var not in data", {
  df <- data.frame(y = 1:5, wt = rep(1, 5))
  expect_error(
    survey_taylor(
      data = df,
      variables = .taylor_vars(weights = "wt", ids = "nonexistent")
    ),
    class = "surveycore_error_design_var_missing"
  )
})

test_that("survey_taylor validator: error 31 — weight col not in data", {
  df <- data.frame(y = 1:5)
  expect_error(
    survey_taylor(
      data = df,
      variables = .taylor_vars(weights = "missing_wt")
    ),
    class = "surveycore_error_design_var_missing"
  )
})

test_that("survey_taylor validator: error 34 — ids is a list-column", {
  df <- data.frame(wt = rep(1, 3), y = 1:3, stringsAsFactors = FALSE)
  df$lc <- list(1, 2, 3) # list-column
  expect_error(
    survey_taylor(
      data = df,
      variables = .taylor_vars(weights = "wt", ids = "lc")
    ),
    class = "surveycore_error_design_var_list"
  )
})

test_that("survey_taylor validator: error 32 — non-numeric weight column", {
  df <- data.frame(
    wt = c("a", "b", "c"),
    y = 1:3,
    stringsAsFactors = FALSE
  )
  expect_error(
    survey_taylor(
      data = df,
      variables = .taylor_vars(weights = "wt")
    ),
    class = "surveycore_error_weights_not_numeric"
  )
})

test_that("survey_taylor validator: error 33 — weight of zero", {
  df <- data.frame(wt = c(1, 0, 1), y = 1:3)
  expect_error(
    survey_taylor(
      data = df,
      variables = .taylor_vars(weights = "wt")
    ),
    class = "surveycore_error_weights_nonpositive"
  )
})

test_that("survey_taylor validator: error 33 — negative weight", {
  df <- data.frame(wt = c(1, -0.5, 1), y = 1:3)
  expect_error(
    survey_taylor(
      data = df,
      variables = .taylor_vars(weights = "wt")
    ),
    class = "surveycore_error_weights_nonpositive"
  )
})

test_that("survey_taylor validator: warning 35 — PSU crossing strata", {
  # psu_1 appears in both strata s1 and s2
  df <- data.frame(
    wt = rep(1, 4),
    psu = c("psu_1", "psu_1", "psu_2", "psu_2"),
    strata = c("s1", "s2", "s1", "s2"),
    y = 1:4,
    stringsAsFactors = FALSE
  )
  expect_warning(
    survey_taylor(
      data = df,
      variables = .taylor_vars(weights = "wt", ids = "psu", strata = "strata")
    ),
    class = "surveycore_warning_psu_multi_strata"
  )
})

test_that("survey_taylor validator: no PSU warning when nest = TRUE", {
  df <- data.frame(
    wt = rep(1, 4),
    psu = c("psu_1", "psu_1", "psu_2", "psu_2"),
    strata = c("s1", "s2", "s1", "s2"),
    y = 1:4,
    stringsAsFactors = FALSE
  )
  # Should NOT warn when nest = TRUE
  expect_no_warning(
    survey_taylor(
      data = df,
      variables = .taylor_vars(
        weights = "wt",
        ids = "psu",
        strata = "strata",
        nest = TRUE
      )
    )
  )
})


# ── survey_replicate — happy paths ─────────────────────────────────────────────

test_that("survey_replicate() creates valid BRR design", {
  set.seed(1)
  df <- .df_rep(R = 4L)
  d <- survey_replicate(
    data = df,
    variables = .rep_vars(
      weights = "wt",
      repweights = paste0("rw", 1:4),
      type = "BRR"
    )
  )
  expect_true(S7::S7_inherits(d, survey_replicate))
  expect_identical(d@variables$weights, "wt")
  expect_identical(d@variables$repweights, paste0("rw", 1:4))
  expect_identical(d@variables$type, "BRR")
})

test_that("survey_replicate() creates valid JK1 design", {
  set.seed(2)
  df <- .df_rep(R = 10L)
  d <- survey_replicate(
    data = df,
    variables = .rep_vars(
      weights = "wt",
      repweights = paste0("rw", 1:10),
      type = "JK1"
    )
  )
  expect_identical(d@variables$type, "JK1")
})

test_that("survey_replicate() inherits from survey_base", {
  df <- .df_rep(R = 2L)
  d <- survey_replicate(
    data = df,
    variables = .rep_vars(
      weights = "wt",
      repweights = c("rw1", "rw2"),
      type = "bootstrap"
    )
  )
  expect_true(S7::S7_inherits(d, survey_base))
})


# ── survey_replicate — validator error paths ───────────────────────────────────

test_that("survey_replicate validator: missing weight column", {
  df <- data.frame(rw1 = 1:3, rw2 = 1:3, y = 1:3)
  expect_error(
    survey_replicate(
      data = df,
      variables = .rep_vars(
        weights = "wt",
        repweights = c("rw1", "rw2")
      )
    ),
    class = "surveycore_error_design_var_missing"
  )
})

test_that("survey_replicate validator: missing repweight column", {
  df <- data.frame(wt = rep(1, 3), rw1 = 1:3, y = 1:3)
  expect_error(
    survey_replicate(
      data = df,
      variables = .rep_vars(
        weights = "wt",
        repweights = c("rw1", "rw_missing")
      )
    ),
    class = "surveycore_error_design_var_missing"
  )
})

test_that("survey_replicate validator: non-positive weight", {
  df <- data.frame(wt = c(1, 0, 1), rw1 = c(1, 1, 1), y = 1:3)
  expect_error(
    survey_replicate(
      data = df,
      variables = .rep_vars(
        weights = "wt",
        repweights = "rw1"
      )
    ),
    class = "surveycore_error_weights_nonpositive"
  )
})

test_that("survey_replicate validator: non-numeric repweight column", {
  df <- data.frame(
    wt = rep(1, 3),
    rw1 = c("a", "b", "c"),
    y = 1:3,
    stringsAsFactors = FALSE
  )
  expect_error(
    survey_replicate(
      data = df,
      variables = .rep_vars(
        weights = "wt",
        repweights = "rw1"
      )
    ),
    class = "surveycore_error_repweights_not_numeric"
  )
})


# ── survey_twophase — happy paths ──────────────────────────────────────────────

test_that("survey_twophase() creates valid object with minimal spec", {
  df <- data.frame(
    wt = runif(20, 0.5, 2),
    psu = paste0("p", rep(1:5, 4)),
    ph2 = c(rep(TRUE, 10), rep(FALSE, 10)),
    y = rnorm(20),
    stringsAsFactors = FALSE
  )
  d <- survey_twophase(
    data = df,
    variables = list(
      phase1 = .taylor_vars(weights = "wt", ids = "psu"),
      phase2 = list(ids = NULL, strata = NULL, probs = NULL, fpc = NULL),
      subset = "ph2",
      method = "full",
      visible_vars = NULL
    )
  )
  expect_true(S7::S7_inherits(d, survey_twophase))
  expect_identical(d@variables$subset, "ph2")
  expect_identical(d@variables$method, "full")
})

test_that("survey_twophase() creates valid object with phase2 strata col", {
  df <- data.frame(
    wt = runif(20, 0.5, 2),
    ph2 = c(rep(TRUE, 10), rep(FALSE, 10)),
    ph2_str = c(rep(c("A", "B"), 5), rep(NA, 10)),
    y = rnorm(20),
    stringsAsFactors = FALSE
  )
  d <- survey_twophase(
    data = df,
    variables = list(
      phase1 = .taylor_vars(weights = "wt"),
      phase2 = list(
        ids = NULL,
        strata = "ph2_str",
        probs = NULL,
        fpc = NULL
      ),
      subset = "ph2",
      method = "approx",
      visible_vars = NULL
    )
  )
  expect_identical(d@variables$phase2$strata, "ph2_str")
})

test_that("survey_twophase() inherits from survey_base", {
  df <- data.frame(
    wt = rep(1, 10),
    ph2 = c(rep(TRUE, 5), rep(FALSE, 5)),
    y = rnorm(10)
  )
  d <- survey_twophase(
    data = df,
    variables = list(
      phase1 = .taylor_vars(weights = "wt"),
      phase2 = list(ids = NULL, strata = NULL, probs = NULL, fpc = NULL),
      subset = "ph2",
      method = "simple"
    )
  )
  expect_true(S7::S7_inherits(d, survey_base))
})


# ── survey_twophase — validator error paths ────────────────────────────────────

test_that("survey_twophase validator: subset column not in data", {
  df <- data.frame(wt = rep(1, 5), y = 1:5)
  expect_error(
    survey_twophase(
      data = df,
      variables = list(
        phase1 = .taylor_vars(weights = "wt"),
        phase2 = list(ids = NULL, strata = NULL, probs = NULL, fpc = NULL),
        subset = "ph2_missing",
        method = "full"
      )
    ),
    class = "surveycore_error_design_var_missing"
  )
})

test_that("survey_twophase validator: subset column not logical", {
  df <- data.frame(wt = rep(1, 5), ph2 = 1:5, y = 1:5)
  expect_error(
    survey_twophase(
      data = df,
      variables = list(
        phase1 = .taylor_vars(weights = "wt"),
        phase2 = list(ids = NULL, strata = NULL, probs = NULL, fpc = NULL),
        subset = "ph2",
        method = "full"
      )
    ),
    class = "surveycore_error_subset_not_logical"
  )
})

test_that("survey_twophase validator: phase2 design col not in data", {
  df <- data.frame(
    wt = rep(1, 10),
    ph2 = c(rep(TRUE, 5), rep(FALSE, 5)),
    y = 1:10
  )
  expect_error(
    survey_twophase(
      data = df,
      variables = list(
        phase1 = .taylor_vars(weights = "wt"),
        phase2 = list(
          ids = NULL,
          strata = "missing_strata_col",
          probs = NULL,
          fpc = NULL
        ),
        subset = "ph2",
        method = "full"
      )
    ),
    class = "surveycore_error_design_var_missing"
  )
})

test_that("survey_twophase validator: warning 26 — phase2 col all-NA in ph2", {
  df <- data.frame(
    wt = rep(1, 10),
    ph2 = c(rep(TRUE, 5), rep(FALSE, 5)),
    ph2_str = rep(NA_character_, 10), # all NA within phase 2 rows
    y = 1:10,
    stringsAsFactors = FALSE
  )
  expect_warning(
    survey_twophase(
      data = df,
      variables = list(
        phase1 = .taylor_vars(weights = "wt"),
        phase2 = list(
          ids = NULL,
          strata = "ph2_str",
          probs = NULL,
          fpc = NULL
        ),
        subset = "ph2",
        method = "full"
      )
    ),
    class = "surveycore_warning_phase2_all_na"
  )
})


# ── Cross-class structural tests ───────────────────────────────────────────────

test_that("survey_taylor and survey_replicate are different classes", {
  df_t <- data.frame(wt = rep(1, 5), y = 1:5)
  d_t <- survey_taylor(
    data = df_t,
    variables = .taylor_vars(weights = "wt")
  )
  df_r <- .df_rep(R = 2L)
  d_r <- survey_replicate(
    data = df_r,
    variables = .rep_vars(
      weights = "wt",
      repweights = c("rw1", "rw2")
    )
  )
  expect_false(S7::S7_inherits(d_t, survey_replicate))
  expect_false(S7::S7_inherits(d_r, survey_taylor))
})

test_that("all three concrete classes inherit from survey_base", {
  df_t <- data.frame(wt = rep(1, 5), y = 1:5)
  df_r <- .df_rep(R = 2L)
  df_tp <- data.frame(
    wt = rep(1, 10),
    ph2 = c(rep(TRUE, 5), rep(FALSE, 5)),
    y = 1:10
  )

  d_t <- survey_taylor(
    data = df_t,
    variables = .taylor_vars(weights = "wt")
  )
  d_r <- survey_replicate(
    data = df_r,
    variables = .rep_vars(weights = "wt", repweights = c("rw1", "rw2"))
  )
  d_tp <- survey_twophase(
    data = df_tp,
    variables = list(
      phase1 = .taylor_vars(weights = "wt"),
      phase2 = list(ids = NULL, strata = NULL, probs = NULL, fpc = NULL),
      subset = "ph2",
      method = "full"
    )
  )

  expect_true(S7::S7_inherits(d_t, survey_base))
  expect_true(S7::S7_inherits(d_r, survey_base))
  expect_true(S7::S7_inherits(d_tp, survey_base))
})

# ── survey_taylor validator: list-column design variable ──────────────────────

test_that("survey_taylor validator rejects list-column design variable", {
  df <- data.frame(
    wt = rep(1, 5),
    y = 1:5,
    stringsAsFactors = FALSE
  )
  # Add a list-column for the weights position
  df$psu <- vector("list", 5) # list-column
  for (i in seq_len(5)) {
    df$psu[[i]] <- i
  }

  expect_error(
    survey_taylor(
      data = df,
      variables = .taylor_vars(weights = "wt", ids = "psu")
    ),
    class = "surveycore_error_design_var_list"
  )
})

test_that("survey_taylor validator rejects non-numeric weight column", {
  df <- data.frame(
    wt = as.character(1:5), # character, not numeric
    y = 1:5,
    stringsAsFactors = FALSE
  )
  expect_error(
    survey_taylor(
      data = df,
      variables = .taylor_vars(weights = "wt")
    ),
    class = "surveycore_error_weights_not_numeric"
  )
})

# ── survey_replicate validator: list-column design variable ───────────────────

test_that("survey_replicate validator rejects list-column design variable", {
  df <- .df_rep(R = 2L)
  df$rw1 <- as.list(df$rw1) # make a repweight column a list-column

  expect_error(
    survey_replicate(
      data = df,
      variables = .rep_vars(weights = "wt", repweights = c("rw1", "rw2"))
    ),
    class = "surveycore_error_design_var_list"
  )
})

# ── survey_nonprob validator: non-numeric weight column ───────────────────

test_that("survey_nonprob validator rejects non-numeric weight column", {
  df <- data.frame(y = 1:5, wt = c("a", "b", "c", "d", "e"))

  expect_error(
    survey_nonprob(
      data = df,
      variables = list(
        weights = "wt",
        probs_provided = FALSE,
        ids = NULL,
        strata = NULL,
        fpc = NULL,
        nest = FALSE,
        visible_vars = NULL
      )
    ),
    class = "surveycore_error_weights_not_numeric"
  )
})

# ── survey_nonprob validator: zero weights ────────────────────────────────────

test_that("survey_nonprob allows zero weights after post-construction assignment", {
  df <- data.frame(x = 1:5, w = c(1, 2, 3, 4, 5))
  obj <- as_survey_nonprob(df, weights = w)
  new_data <- obj@data
  new_data$w <- c(1, 0, 0, 4, 0)
  obj@data <- new_data
  test_invariants(obj)
  expect_equal(sum(obj@data$w == 0), 3L)
})

test_that("survey_nonprob validator accepts zero weights with at least one positive", {
  df <- data.frame(x = 1:5, w = c(1, 0, 0, 2, 0))
  obj <- survey_nonprob(
    data = df,
    variables = list(
      weights = "w",
      repweights = NULL,
      type = NULL,
      scale = NULL,
      rscales = NULL,
      mse = NULL,
      probs_provided = FALSE,
      ids = NULL,
      strata = NULL,
      fpc = NULL,
      nest = FALSE,
      visible_vars = NULL
    )
  )
  expect_s3_class(obj@data, "data.frame")
  expect_equal(sum(obj@data$w == 0), 3L)
})

test_that("survey_nonprob validator rejects negative weights", {
  df <- data.frame(x = 1:3, w = c(1, -0.5, 2))
  expect_error(
    survey_nonprob(
      data = df,
      variables = list(
        weights = "w",
        probs_provided = FALSE,
        ids = NULL,
        strata = NULL,
        fpc = NULL,
        nest = FALSE,
        visible_vars = NULL
      )
    ),
    class = "surveycore_error_weights_negative"
  )
})

test_that("survey_nonprob validator rejects all-zero weights", {
  df <- data.frame(x = 1:3, w = c(0, 0, 0))
  expect_error(
    survey_nonprob(
      data = df,
      variables = list(
        weights = "w",
        probs_provided = FALSE,
        ids = NULL,
        strata = NULL,
        fpc = NULL,
        nest = FALSE,
        visible_vars = NULL
      )
    ),
    class = "surveycore_error_weights_all_zero"
  )
})

test_that("survey_nonprob validator accepts single positive weight among zeros", {
  df <- data.frame(x = 1:5, w = c(0, 0, 0, 0, 0.001))
  obj <- survey_nonprob(
    data = df,
    variables = list(
      weights = "w",
      repweights = NULL,
      type = NULL,
      scale = NULL,
      rscales = NULL,
      mse = NULL,
      probs_provided = FALSE,
      ids = NULL,
      strata = NULL,
      fpc = NULL,
      nest = FALSE,
      visible_vars = NULL
    )
  )
  test_invariants(obj)
})

test_that("survey_nonprob validator accepts mix of zeros and NAs with one positive", {
  df <- data.frame(x = 1:4, w = c(0, NA, 1, 0))
  obj <- survey_nonprob(
    data = df,
    variables = list(
      weights = "w",
      repweights = NULL,
      type = NULL,
      scale = NULL,
      rscales = NULL,
      mse = NULL,
      probs_provided = FALSE,
      ids = NULL,
      strata = NULL,
      fpc = NULL,
      nest = FALSE,
      visible_vars = NULL
    )
  )
  test_invariants(obj)
})

test_that("survey_nonprob validator rejects mix of zeros and negatives", {
  df <- data.frame(x = 1:3, w = c(0, -1, 0))
  expect_error(
    survey_nonprob(
      data = df,
      variables = list(
        weights = "w",
        probs_provided = FALSE,
        ids = NULL,
        strata = NULL,
        fpc = NULL,
        nest = FALSE,
        visible_vars = NULL
      )
    ),
    class = "surveycore_error_weights_negative"
  )
})

test_that("survey_nonprob validator rejects all-zero weights with NAs", {
  df <- data.frame(x = 1:3, w = c(0, NA, 0))
  expect_error(
    survey_nonprob(
      data = df,
      variables = list(
        weights = "w",
        probs_provided = FALSE,
        ids = NULL,
        strata = NULL,
        fpc = NULL,
        nest = FALSE,
        visible_vars = NULL
      )
    ),
    class = "surveycore_error_weights_all_zero"
  )
})

test_that("test_invariants() passes for survey_nonprob with zero weights", {
  df <- data.frame(x = 1:5, w = c(1, 2, 3, 4, 5))
  obj <- as_survey_nonprob(df, weights = w)
  new_data <- obj@data
  new_data$w <- c(1, 0, 0, 2, 0)
  obj@data <- new_data
  expect_no_error(test_invariants(obj))
})


# ── survey_metadata sata property ─────────────────────────────────────────────

test_that("survey_metadata has a sata property with list() default", {
  m <- survey_metadata()
  expect_true(S7::S7_inherits(m, survey_metadata))
  expect_identical(m@sata, list())
  expect_identical(length(m@sata), 0L)
})

test_that("survey_metadata sata accepts a named list", {
  m <- survey_metadata(sata = list(news_tv = TRUE, news_online = TRUE))
  expect_identical(m@sata$news_tv, TRUE)
})


# ── survey_taylor @calibration property ────────────────────────────────────────

test_that("survey_taylor has @calibration == NULL by default", {
  df <- make_survey_data(seed = 1)
  design <- as_survey(df, ids = psu, weights = wt, strata = strata)
  test_invariants(design)
  expect_null(design@calibration)
})

test_that("survey_taylor @calibration accepts a list", {
  df <- make_survey_data(seed = 1)
  design <- as_survey(df, ids = psu, weights = wt, strata = strata)
  cd <- as_caldata(df$wt, rep(1.05, nrow(df)), matrix(1, nrow(df), 1))
  design@calibration <- list(cd)
  expect_type(design@calibration, "list")
  expect_length(design@calibration, 1L)
})

test_that("survey_taylor S7 validator passes when @calibration is NULL", {
  df <- make_survey_data(seed = 1)
  design <- as_survey(df, ids = psu, weights = wt, strata = strata)
  expect_no_error(S7::check_is_S7(design))
})

test_that("survey_taylor S7 validator passes when @calibration is a non-empty list", {
  df <- make_survey_data(seed = 1)
  design <- as_survey(df, ids = psu, weights = wt, strata = strata)
  cd <- as_caldata(df$wt, rep(1.05, nrow(df)), matrix(1, nrow(df), 1))
  design@calibration <- list(cd)
  expect_no_error(S7::check_is_S7(design))
})


# ── survey_replicate @calibration property ─────────────────────────────────────

test_that("survey_replicate has @calibration == NULL by default", {
  df <- make_survey_data(design = "replicate", seed = 1)
  design <- as_survey_replicate(
    df,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "BRR"
  )
  expect_null(design@calibration)
})

test_that("survey_replicate @calibration accepts a list", {
  df <- make_survey_data(design = "replicate", seed = 1)
  design <- as_survey_replicate(
    df,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "BRR"
  )
  cd <- as_caldata(df$wt, rep(1.05, nrow(df)), matrix(1, nrow(df), 1))
  design@calibration <- list(cd)
  expect_type(design@calibration, "list")
  expect_length(design@calibration, 1L)
})

test_that("survey_replicate S7 validator passes when @calibration is NULL", {
  df <- make_survey_data(design = "replicate", seed = 1)
  design <- as_survey_replicate(
    df,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "BRR"
  )
  expect_no_error(S7::check_is_S7(design))
})

test_that("survey_replicate S7 validator passes when @calibration is a non-empty list", {
  df <- make_survey_data(design = "replicate", seed = 1)
  design <- as_survey_replicate(
    df,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "BRR"
  )
  cd <- as_caldata(df$wt, rep(1.05, nrow(df)), matrix(1, nrow(df), 1))
  design@calibration <- list(cd)
  expect_no_error(S7::check_is_S7(design))
})


# ── survey_metadata @dataset_metadata property ────────────────────────────────

test_that("survey_metadata() defaults @dataset_metadata to an empty list", {
  m <- survey_metadata()
  expect_identical(m@dataset_metadata, list())
})

test_that("survey_metadata() stores a single dataset metadata key", {
  m <- survey_metadata(dataset_metadata = list(vendor = "Ipsos"))
  expect_identical(m@dataset_metadata, list(vendor = "Ipsos"))
})

test_that("survey_metadata() accepts all six canonical dataset keys", {
  m <- survey_metadata(dataset_metadata = full_keys)
  expect_identical(m@dataset_metadata, full_keys)
  expect_identical(names(m@dataset_metadata), names(full_keys))
})

test_that("survey_metadata() accepts an unrelated survey_name / data_name pair", {
  m <- survey_metadata(
    dataset_metadata = list(
      survey_name = "Formal Survey Name 2026",
      data_name = "Something Completely Different"
    )
  )
  expect_identical(m@dataset_metadata$survey_name, "Formal Survey Name 2026")
  expect_identical(
    m@dataset_metadata$data_name,
    "Something Completely Different"
  )
})

test_that("survey_metadata() keeps other properties intact alongside @dataset_metadata", {
  m <- survey_metadata(
    variable_labels = list(age = "Age in years"),
    dataset_metadata = list(vendor = "Ipsos")
  )
  expect_identical(m@variable_labels, list(age = "Age in years"))
  expect_identical(m@dataset_metadata, list(vendor = "Ipsos"))
})

test_that("as_survey() designs start with an empty @dataset_metadata", {
  df <- make_survey_data(n = 60, n_psu = 12, n_strata = 3, seed = 11)
  design <- as_survey(df, ids = psu, weights = wt, strata = strata)
  expect_identical(design@metadata@dataset_metadata, list())
})


# ── survey_metadata validator: structural checks (spec III.3 checks 2-6) ──────

test_that("survey_metadata validator accepts an explicitly empty dataset list", {
  m <- survey_metadata()
  m@dataset_metadata <- list()
  expect_identical(m@dataset_metadata, list())
})

test_that("survey_metadata validator rejects an unnamed dataset metadata entry", {
  expect_error(
    survey_metadata(dataset_metadata = list("Ipsos")),
    class = "surveycore_error_dataset_metadata_unnamed"
  )
})

test_that("survey_metadata validator rejects a partially named dataset metadata list", {
  expect_error(
    survey_metadata(dataset_metadata = list(vendor = "Ipsos", "Cint")),
    class = "surveycore_error_dataset_metadata_unnamed"
  )
})

test_that("survey_metadata validator rejects an NA dataset metadata key name", {
  bad <- stats::setNames(list("Ipsos"), NA_character_)
  expect_error(
    survey_metadata(dataset_metadata = bad),
    class = "surveycore_error_dataset_metadata_unnamed"
  )
})

test_that("survey_metadata validator rejects an empty dataset metadata key name", {
  bad <- stats::setNames(list("Ipsos"), "")
  expect_error(
    survey_metadata(dataset_metadata = bad),
    class = "surveycore_error_dataset_metadata_unnamed"
  )
  expect_error(
    survey_metadata(dataset_metadata = bad),
    regexp = "All dataset metadata entries must have a non-empty name."
  )
})

test_that("survey_metadata validator rejects a duplicated dataset metadata key", {
  bad <- list(vendor = "Ipsos", vendor = "Cint")
  expect_error(
    survey_metadata(dataset_metadata = bad),
    class = "surveycore_error_dataset_metadata_duplicate_key"
  )
  expect_error(
    survey_metadata(dataset_metadata = bad),
    regexp = "Duplicate dataset metadata key\\(s\\): vendor."
  )
})

test_that("survey_metadata validator rejects a key outside the closed vocabulary", {
  expect_error(
    survey_metadata(dataset_metadata = list(mode = "web")),
    class = "surveycore_error_dataset_key_unknown"
  )
  expect_error(
    survey_metadata(dataset_metadata = list(mode = "web")),
    regexp = "Unknown dataset metadata key: mode."
  )
})

test_that("survey_metadata validator rejects the legacy dates key", {
  expect_error(
    survey_metadata(dataset_metadata = list(dates = "February-March 2026")),
    class = "surveycore_error_dataset_key_unknown"
  )
})

test_that("survey_metadata validator rejects a key that names a base attribute", {
  expect_error(
    survey_metadata(dataset_metadata = list(class = "tbl_df")),
    class = "surveycore_error_dataset_key_unknown"
  )
})

test_that("survey_metadata validator rejects a NULL dataset metadata element", {
  expect_error(
    survey_metadata(dataset_metadata = list(vendor = NULL)),
    class = "surveycore_error_dataset_metadata_bad_type"
  )
})

test_that("survey_metadata validator rejects a NULL element on a date key", {
  expect_error(
    survey_metadata(dataset_metadata = list(field_start = NULL)),
    class = "surveycore_error_dataset_metadata_bad_type"
  )
})


# ── survey_metadata validator: per-key value rules (spec III.3 check 7) ───────

# Each of the four character keys is violable three ways — non-character,
# length 2, and NA. All twelve cases carry the same class, and all twelve are
# asserted, because this suite is what guards the closed value contract on
# every later change.

test_that("survey_metadata validator rejects a non-character survey_name", {
  expect_error(
    survey_metadata(dataset_metadata = list(survey_name = 1L)),
    class = "surveycore_error_dataset_metadata_bad_type"
  )
  expect_error(
    survey_metadata(dataset_metadata = list(survey_name = 1L)),
    regexp = paste(
      "Dataset metadata key survey_name must be a single non-NA",
      "character string."
    )
  )
})

test_that("survey_metadata validator rejects a length-2 survey_name", {
  expect_error(
    survey_metadata(dataset_metadata = list(survey_name = c("a", "b"))),
    class = "surveycore_error_dataset_metadata_bad_type"
  )
})

test_that("survey_metadata validator rejects an NA survey_name", {
  expect_error(
    survey_metadata(dataset_metadata = list(survey_name = NA_character_)),
    class = "surveycore_error_dataset_metadata_bad_type"
  )
})

test_that("survey_metadata validator rejects a non-character data_name", {
  expect_error(
    survey_metadata(dataset_metadata = list(data_name = TRUE)),
    class = "surveycore_error_dataset_metadata_bad_type"
  )
})

test_that("survey_metadata validator rejects a length-2 data_name", {
  expect_error(
    survey_metadata(dataset_metadata = list(data_name = c("a", "b"))),
    class = "surveycore_error_dataset_metadata_bad_type"
  )
})

test_that("survey_metadata validator rejects an NA data_name", {
  expect_error(
    survey_metadata(dataset_metadata = list(data_name = NA_character_)),
    class = "surveycore_error_dataset_metadata_bad_type"
  )
})

test_that("survey_metadata validator rejects a non-character vendor", {
  expect_error(
    survey_metadata(dataset_metadata = list(vendor = 1L)),
    class = "surveycore_error_dataset_metadata_bad_type"
  )
  expect_error(
    survey_metadata(dataset_metadata = list(vendor = 1L)),
    regexp = paste(
      "Dataset metadata key vendor must be a single non-NA",
      "character string."
    )
  )
})

test_that("survey_metadata validator rejects a length-2 vendor", {
  expect_error(
    survey_metadata(dataset_metadata = list(vendor = c("Ipsos", "Cint"))),
    class = "surveycore_error_dataset_metadata_bad_type"
  )
})

test_that("survey_metadata validator rejects an NA vendor", {
  expect_error(
    survey_metadata(dataset_metadata = list(vendor = NA_character_)),
    class = "surveycore_error_dataset_metadata_bad_type"
  )
})

test_that("survey_metadata validator rejects a non-character field_period", {
  expect_error(
    survey_metadata(dataset_metadata = list(field_period = 2026)),
    class = "surveycore_error_dataset_metadata_bad_type"
  )
})

test_that("survey_metadata validator rejects a length-2 field_period", {
  bad <- list(field_period = c("February 2026", "March 2026"))
  expect_error(
    survey_metadata(dataset_metadata = bad),
    class = "surveycore_error_dataset_metadata_bad_type"
  )
})

test_that("survey_metadata validator rejects an NA field_period", {
  expect_error(
    survey_metadata(dataset_metadata = list(field_period = NA_character_)),
    class = "surveycore_error_dataset_metadata_bad_type"
  )
})

test_that("survey_metadata validator rejects a zero-length field_period", {
  expect_error(
    survey_metadata(dataset_metadata = list(field_period = character(0))),
    class = "surveycore_error_dataset_metadata_bad_type"
  )
})

test_that("survey_metadata validator rejects an ISO string on a date key", {
  expect_error(
    survey_metadata(dataset_metadata = list(field_start = "2026-02-10")),
    class = "surveycore_error_field_date_invalid"
  )
  expect_error(
    survey_metadata(dataset_metadata = list(field_start = "2026-02-10")),
    regexp = "Dataset metadata key field_start must be a Date scalar."
  )
})

test_that("survey_metadata validator rejects a numeric field_end", {
  expect_error(
    survey_metadata(dataset_metadata = list(field_end = 20000)),
    class = "surveycore_error_field_date_invalid"
  )
})

test_that("survey_metadata validator rejects an NA Date on a date key", {
  expect_error(
    survey_metadata(dataset_metadata = list(field_start = as.Date(NA))),
    class = "surveycore_error_field_date_invalid"
  )
})

test_that("survey_metadata validator rejects a length-2 Date on a date key", {
  two_dates <- as.Date(c("2026-02-10", "2026-02-11"))
  expect_error(
    survey_metadata(dataset_metadata = list(field_start = two_dates)),
    class = "surveycore_error_field_date_invalid"
  )
})

test_that("survey_metadata validator accepts field_start with field_end absent", {
  m <- survey_metadata(
    dataset_metadata = list(field_start = as.Date("2026-02-10"))
  )
  expect_identical(m@dataset_metadata$field_start, as.Date("2026-02-10"))
})

test_that("survey_metadata validator accepts field_end with field_start absent", {
  m <- survey_metadata(
    dataset_metadata = list(field_end = as.Date("2026-03-04"))
  )
  expect_identical(m@dataset_metadata$field_end, as.Date("2026-03-04"))
})


# ── survey_metadata validator: date pair (check 8) and re-validation ──────────

test_that("survey_metadata validator rejects a reversed field date pair", {
  reversed <- list(
    field_start = as.Date("2026-03-04"),
    field_end = as.Date("2026-02-10")
  )
  expect_error(
    survey_metadata(dataset_metadata = reversed),
    class = "surveycore_error_field_dates_reversed"
  )
  expect_error(
    survey_metadata(dataset_metadata = reversed),
    regexp = "field_start is after field_end."
  )
})

test_that("survey_metadata validator accepts field_start equal to field_end", {
  same_day <- list(
    field_start = as.Date("2026-02-10"),
    field_end = as.Date("2026-02-10")
  )
  m <- survey_metadata(dataset_metadata = same_day)
  expect_identical(m@dataset_metadata, same_day)
})

test_that("survey_metadata validator accepts field_start before field_end", {
  ordered_pair <- list(
    field_start = as.Date("2026-02-10"),
    field_end = as.Date("2026-03-04")
  )
  m <- survey_metadata(dataset_metadata = ordered_pair)
  expect_identical(m@dataset_metadata, ordered_pair)
})

test_that("survey_metadata re-validates @dataset_metadata on assignment", {
  m <- survey_metadata()
  expect_error(
    m@dataset_metadata <- list(mode = "web"),
    class = "surveycore_error_dataset_key_unknown"
  )
})

test_that("survey_metadata re-validates a bad value type on assignment", {
  m <- survey_metadata()
  expect_error(
    m@dataset_metadata <- list(vendor = 1L),
    class = "surveycore_error_dataset_metadata_bad_type"
  )
})

test_that("survey_metadata re-validates a reversed date pair on assignment", {
  m <- survey_metadata()
  expect_error(
    m@dataset_metadata <- list(
      field_start = as.Date("2026-03-04"),
      field_end = as.Date("2026-02-10")
    ),
    class = "surveycore_error_field_dates_reversed"
  )
})

test_that("survey_metadata assignment round-trips a valid dataset metadata list", {
  m <- survey_metadata()
  m@dataset_metadata <- full_keys
  expect_identical(m@dataset_metadata, full_keys)
})

test_that("a design's @metadata re-validates @dataset_metadata on assignment", {
  df <- make_survey_data(n = 60, n_psu = 12, n_strata = 3, seed = 12)
  design <- as_survey(df, ids = psu, weights = wt, strata = strata)
  expect_error(
    design@metadata@dataset_metadata <- list(vendor = NA_character_),
    class = "surveycore_error_dataset_metadata_bad_type"
  )
  design@metadata@dataset_metadata <- list(vendor = "Ipsos")
  expect_identical(design@metadata@dataset_metadata, list(vendor = "Ipsos"))
})


# ── survey_metadata @var_extra property across constructors ───────────────────

test_that("as_survey() designs start with an empty @var_extra", {
  df <- make_survey_data(n = 60, n_psu = 12, n_strata = 3, seed = 11)
  design <- as_survey(df, ids = psu, weights = wt, strata = strata)
  expect_identical(design@metadata@var_extra, list())
})

test_that("as_survey_replicate() designs start with an empty @var_extra", {
  df <- make_survey_data(design = "replicate", seed = 1)
  design <- as_survey_replicate(
    df,
    weights = wt,
    repweights = tidyselect::starts_with("repwt_"),
    type = "BRR"
  )
  expect_identical(design@metadata@var_extra, list())
})

test_that("as_survey_twophase() designs start with an empty @var_extra", {
  df <- make_survey_data(design = "twophase", seed = 1)
  phase1 <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
  design <- as_survey_twophase(phase1, subset = subset, method = "approx")
  expect_identical(design@metadata@var_extra, list())
})

test_that("as_survey_nonprob() designs start with an empty @var_extra", {
  df <- data.frame(y = 1:20, w = runif(20, 0.5, 2))
  design <- as_survey_nonprob(df, weights = w)
  expect_identical(design@metadata@var_extra, list())
})


# ── The haven labelled class never reaches @data (spec III.1, III.4) ──────────
#
# The `data` property of survey_base carries a setter that drops the
# haven_labelled class from every column on every write. These blocks exercise
# the routes that only the setter can reach: a direct call to each of the four
# exported class constructors, and a bare `d@data <-` assignment. No constructor
# entry point is involved, so nothing but the setter can normalise them.

# Labelled frames for the four class constructors. make_labelled() lives in
# helper-test-data.R.
.lab_taylor_df <- function(seed = 42L) {
  set.seed(seed)
  df <- data.frame(
    psu = rep(1:10, each = 4L),
    strata = rep(1:2, each = 20L),
    wt = runif(40, 0.5, 2),
    y = rnorm(40)
  )
  df$y <- make_labelled(df$y, NULL, "Outcome")
  df
}

.lab_rep_df <- function(R = 4L, seed = 42L) {
  set.seed(seed)
  df <- data.frame(
    wt = runif(20, 0.5, 2),
    y = rnorm(20)
  )
  df$y <- make_labelled(df$y, NULL, "Outcome")
  for (i in seq_len(R)) {
    df[[paste0("rw", i)]] <- runif(20, 0.3, 3)
  }
  df
}

.lab_nonprob_df <- function(seed = 42L) {
  set.seed(seed)
  df <- data.frame(
    w = runif(30, 0.5, 2),
    y = rnorm(30)
  )
  df$y <- make_labelled(df$y, NULL, "Outcome")
  df
}

.lab_twophase_df <- function(seed = 42L) {
  set.seed(seed)
  df <- data.frame(
    wt = runif(40, 0.5, 2),
    psu = rep(1:10, each = 4L),
    ph2 = rep(c(TRUE, FALSE), 20L),
    y = rnorm(40)
  )
  df$y <- make_labelled(df$y, NULL, "Outcome")
  df
}

.twophase_vars <- function() {
  list(
    phase1 = .taylor_vars(weights = "wt", ids = "psu"),
    phase2 = list(ids = NULL, strata = NULL, probs = NULL, fpc = NULL),
    subset = "ph2",
    method = "full",
    visible_vars = NULL
  )
}

.nonprob_vars <- function(weights = "w") {
  list(
    weights = weights,
    repweights = NULL,
    type = NULL,
    scale = NULL,
    rscales = NULL,
    mse = NULL,
    probs_provided = FALSE,
    visible_vars = NULL
  )
}

# Column names in @data that still inherit the haven labelled class.
.labelled_cols <- function(d) {
  names(d@data)[vapply(d@data, inherits, logical(1L), "haven_labelled")]
}

test_that("S-24: all four class constructors store no labelled column", {
  taylor <- survey_taylor(
    data = .lab_taylor_df(),
    variables = .taylor_vars(weights = "wt", ids = "psu", strata = "strata")
  )
  replicate <- survey_replicate(
    data = .lab_rep_df(),
    variables = .rep_vars(weights = "wt", repweights = paste0("rw", 1:4))
  )
  twophase <- survey_twophase(
    data = .lab_twophase_df(),
    variables = .twophase_vars()
  )
  nonprob <- survey_nonprob(
    data = .lab_nonprob_df(),
    variables = .nonprob_vars()
  )

  expect_identical(.labelled_cols(taylor), character(0))
  expect_identical(.labelled_cols(replicate), character(0))
  expect_identical(.labelled_cols(twophase), character(0))
  expect_identical(.labelled_cols(nonprob), character(0))

  # The whole class vector goes, not just the haven entries (spec III.3a).
  expect_identical(class(taylor@data$y), "numeric")
  expect_identical(class(replicate@data$y), "numeric")
  expect_identical(class(twophase@data$y), "numeric")
  expect_identical(class(nonprob@data$y), "numeric")
})

test_that("S-25: a bare @data assignment strips the labelled class", {
  taylor <- survey_taylor(
    data = .df10(),
    variables = .taylor_vars(weights = "wt")
  )
  taylor@data <- .lab_taylor_df()
  expect_identical(.labelled_cols(taylor), character(0))
  expect_identical(class(taylor@data$y), "numeric")

  # survey_twophase inherits the setter from survey_base — spec III.4 GAP.
  twophase <- survey_twophase(
    data = .lab_twophase_df(),
    variables = .twophase_vars()
  )
  twophase@data <- .lab_twophase_df()
  expect_identical(.labelled_cols(twophase), character(0))
  expect_identical(class(twophase@data$y), "numeric")
})

test_that("S-26: survey_twophase() strips the class at construction", {
  d <- survey_twophase(
    data = .lab_twophase_df(),
    variables = .twophase_vars()
  )
  expect_true(S7::S7_inherits(d, survey_twophase))
  expect_identical(.labelled_cols(d), character(0))
  expect_identical(class(d@data$y), "numeric")

  # Every other attribute the import set survives the strip.
  expect_identical(attr(d@data$y, "label", exact = TRUE), "Outcome")
})

test_that("S-27: an estimate after a bare @data assignment matches plain", {
  plain_df <- .lab_taylor_df()
  attr(plain_df$y, "class") <- NULL

  d <- survey_taylor(
    data = .df10(),
    variables = .taylor_vars(weights = "wt")
  )
  d@data <- .lab_taylor_df()
  labelled_result <- get_means(d, y)

  d <- survey_taylor(
    data = .df10(),
    variables = .taylor_vars(weights = "wt")
  )
  d@data <- plain_df
  plain_result <- get_means(d, y)

  expect_identical(labelled_result, plain_result)
})

test_that("S-28: grouped get_quantiles() after direct construction matches", {
  lab_df <- .lab_taylor_df()
  lab_df$g <- make_labelled(
    rep(c(1, 2), 20L),
    c(Alpha = 1, Beta = 2),
    "Cohort"
  )
  plain_df <- lab_df
  attr(plain_df$y, "class") <- NULL
  attr(plain_df$g, "class") <- NULL

  d <- survey_taylor(
    data = lab_df,
    variables = .taylor_vars(weights = "wt")
  )
  labelled_result <- get_quantiles(
    d,
    y,
    probs = c(0.25, 0.5, 0.75),
    group = g,
    min_cell_n = 0L
  )

  d <- survey_taylor(
    data = plain_df,
    variables = .taylor_vars(weights = "wt")
  )
  plain_result <- get_quantiles(
    d,
    y,
    probs = c(0.25, 0.5, 0.75),
    group = g,
    min_cell_n = 0L
  )

  expect_identical(labelled_result, plain_result)
})

# P1-1 anticipates Part 1 of spec III, which a later PR delivers. It passes
# here because as_survey() reaches the S7 constructor before anything compares
# the ids and strata columns, so the property setter alone is enough for this
# one route. The two routes Part 1 owns — a labelled `weights` column and a
# labelled `fpc` column — still abort on this branch with vctrs_error_ptype2,
# and the gate proving they stop aborting belongs to that PR, not this one.
test_that("P1-1: labelled ids and strata construct with nest = FALSE", {
  df <- .lab_taylor_df()
  df$psu <- make_labelled(df$psu, NULL, "PSU")
  df$strata <- make_labelled(df$strata, NULL, "Stratum")

  d <- as_survey(df, ids = psu, weights = wt, strata = strata)

  expect_true(S7::S7_inherits(d, survey_taylor))
  expect_identical(.labelled_cols(d), character(0))
  expect_identical(attr(d@data$psu, "label", exact = TRUE), "PSU")
  expect_identical(attr(d@data$strata, "label", exact = TRUE), "Stratum")
})


# ── Layer 1 validator errors stay reachable on labelled input ────────────────
#
# The setter runs before the class validator, so the validator sees plain values
# and raises its own typed error where an untyped vctrs error used to escape.
# Layer 1 errors: expect_error(class=) only, no snapshot.

test_that("S-35: labelled weights with a zero raise weights_nonpositive", {
  df <- .lab_taylor_df()
  wt <- df$wt
  wt[[1L]] <- 0
  df$wt <- make_labelled(wt, NULL, "Weight")

  expect_error(
    survey_taylor(data = df, variables = .taylor_vars(weights = "wt")),
    class = "surveycore_error_weights_nonpositive"
  )
})

test_that("X-17: character labelled weights raise weights_not_numeric", {
  df <- .lab_taylor_df()
  df$wt <- make_labelled(as.character(df$wt), NULL, "Weight")

  err <- expect_error(
    survey_taylor(data = df, variables = .taylor_vars(weights = "wt")),
    class = "surveycore_error_weights_not_numeric"
  )
  # The message interpolates the stored class, which no longer names haven.
  expect_false(grepl("haven_labelled", conditionMessage(err), fixed = TRUE))
})

test_that("S-37: labelled negative weights raise weights_negative", {
  df <- .lab_nonprob_df()
  w <- df$w
  w[[1L]] <- -1
  df$w <- make_labelled(w, NULL, "Weight")

  expect_error(
    survey_nonprob(data = df, variables = .nonprob_vars()),
    class = "surveycore_error_weights_negative"
  )
})


# ── X-16 — the stacked caller class on the setter routes (spec III.3a) ───────
#
# X-15 in test-utils.R covers the as_survey() route. This one covers the two
# routes only the property setter reaches: a direct S7 construction call and a
# bare `@data <-` assignment.

test_that("X-16: the setter drops a stacked caller class on both routes", {
  df <- .lab_taylor_df()
  attr(df$y, "class") <- c(
    "my_class",
    "haven_labelled",
    "vctrs_vctr",
    "double"
  )

  built <- survey_taylor(
    data = df,
    variables = .taylor_vars(weights = "wt")
  )
  expect_identical(class(built@data$y), "numeric")
  expect_false(inherits(built@data$y, "my_class"))
  expect_identical(attr(built@data$y, "label", exact = TRUE), "Outcome")

  assigned <- survey_taylor(
    data = .df10(),
    variables = .taylor_vars(weights = "wt")
  )
  assigned@data <- df
  expect_identical(class(assigned@data$y), "numeric")
  expect_false(inherits(assigned@data$y, "my_class"))
  expect_identical(attr(assigned@data$y, "label", exact = TRUE), "Outcome")
})
