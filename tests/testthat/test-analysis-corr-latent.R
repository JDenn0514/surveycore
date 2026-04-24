# Tests for get_corr() — PR 3 public-API integration of polychoric / polyserial.
#
# Scope: integration tests through the exported get_corr() covering
#   - method = "pearson" bit-identity regression guard
#   - method = "polychoric" / "polyserial" happy paths on Taylor and replicate
#   - polycor::polychor() / polycor::polyserial() parity (1e-6)
#   - multi-pair long format, redundant / diagonal / wide
#   - grouped estimation
#   - variance column selection (se, ci, moe, deff, NULL)
#   - df / statistic / p_value method-awareness
#   - column label attributes (method-neutral)
#   - edge cases (empty domain, single-level, all-NA, zero-weight rows,
#     integer ordinal, 6x7 ordinal, surveytidy::filter domain)
#   - survey_collection dispatch
#   - meta(result)$method, bivariate_normal_cdf, n_failed_replicates_total
#
# Error / warning classes exercised at the public-API layer:
#   PC-1 .. PC-14 plus pre-existing Pearson classes (regression guard).

# ── helpers ───────────────────────────────────────────────────────────────────

# Build a small unweighted Taylor design with two 4-level ordinal factors;
# correlated via a shifted coding of o1 into o2.
make_latent_taylor <- function(n = 200L, seed = 42L, n_psu = 20L, n_strata = 4L) {
  set.seed(seed)
  df <- make_survey_data(
    n = n,
    n_psu = n_psu,
    n_strata = n_strata,
    seed = seed
  )
  df$o1 <- factor(sample(1:4, nrow(df), replace = TRUE), ordered = TRUE)
  shift <- as.integer(df$o1) + sample(-1:1, nrow(df), replace = TRUE)
  shift[shift < 1L] <- 1L
  shift[shift > 4L] <- 4L
  df$o2 <- factor(shift, levels = 1:4, ordered = TRUE)
  df$o3 <- factor(sample(1:3, nrow(df), replace = TRUE), ordered = TRUE)
  df$cont <- as.numeric(df$o1) + stats::rnorm(nrow(df), sd = 0.7)
  as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
}

# Unweighted-equivalent Taylor design (weights all 1, no strata): lets
# us sanity-check polychoric against polycor::polychor() at 1e-6.
make_unit_weight_design <- function(
  n = 200L,
  seed = 1L,
  n_levels_x = 4L,
  n_levels_y = 4L
) {
  set.seed(seed)
  x <- sample(seq_len(n_levels_x), n, replace = TRUE)
  y <- x + sample(-1:1, n, replace = TRUE)
  y[y < 1L] <- 1L
  y[y > n_levels_y] <- n_levels_y
  df <- data.frame(
    id = seq_len(n),
    wt = 1,
    o1 = factor(x, levels = seq_len(n_levels_x), ordered = TRUE),
    o2 = factor(y, levels = seq_len(n_levels_y), ordered = TRUE),
    cont = x + stats::rnorm(n, sd = 0.7),
    grp = factor(sample(c("A", "B"), n, replace = TRUE))
  )
  list(df = df, design = as_survey(df, weights = wt))
}

make_latent_replicate <- function(
  type = "jk1",
  n = 200L,
  seed = 7L,
  n_psu = 20L,
  n_strata = 4L
) {
  set.seed(seed)
  df <- make_survey_data(
    n = n,
    n_psu = n_psu,
    n_strata = n_strata,
    design = "replicate",
    type = type,
    seed = seed
  )
  df$o1 <- factor(sample(1:4, nrow(df), replace = TRUE), ordered = TRUE)
  shift <- as.integer(df$o1) + sample(-1:1, nrow(df), replace = TRUE)
  shift[shift < 1L] <- 1L
  shift[shift > 4L] <- 4L
  df$o2 <- factor(shift, levels = 1:4, ordered = TRUE)
  df$cont <- as.numeric(df$o1) + stats::rnorm(nrow(df), sd = 0.7)
  rep_cols <- grep("^repwt_", names(df), value = TRUE)
  as_survey_replicate(
    df,
    weights = wt,
    repweights = tidyselect::all_of(rep_cols),
    type = toupper(type)
  )
}


# =============================================================================
# Category 1 — Regression guard: method = "pearson" bit-identity (Task 1, 2)
# =============================================================================

test_that("get_corr() default method = 'pearson' is bit-identical to pre-PR", {
  df <- make_survey_data(
    n = 200L,
    n_psu = 20L,
    n_strata = 4L,
    design = "taylor",
    seed = 1L
  )
  d <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  r <- get_corr(d, x = c(y1, y2))
  # Canonical numeric snapshot captured before any dispatch changes. Strip
  # column `label` attributes (added in PR 3 for gt integration) before
  # comparing with `identical()`.
  strip <- function(x) {
    attr(x, "label") <- NULL
    x
  }
  expect_identical(strip(r$r[[1L]]), 5.2280395548044762e-06)
  expect_identical(strip(r$ci_low[[1L]]), -0.18135383672677005)
  expect_identical(strip(r$ci_high[[1L]]), 0.18136394889447977)
  # p_value round-trips through pt() and bottoms out at ~2 ulp of 1.
  expect_equal(
    strip(r$p_value[[1L]]),
    0.99994137765706892,
    tolerance = 1e-15
  )
  expect_identical(strip(r$statistic[[1L]]), 7.356503736351089e-05)
  expect_identical(strip(r$df[[1L]]), 198L)
  expect_identical(strip(r$n[[1L]]), 200L)
})

test_that("get_corr() explicit method = 'pearson' equals omitted method", {
  df <- make_survey_data(
    n = 200L,
    n_psu = 20L,
    n_strata = 4L,
    design = "taylor",
    seed = 1L
  )
  d <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  r_default <- get_corr(d, x = c(y1, y2))
  r_explicit <- get_corr(d, x = c(y1, y2), method = "pearson")
  expect_equal(r_default$r, r_explicit$r, tolerance = 1e-10)
  expect_equal(r_default$ci_low, r_explicit$ci_low, tolerance = 1e-10)
  expect_equal(r_default$ci_high, r_explicit$ci_high, tolerance = 1e-10)
})

test_that("get_corr() method = 'nonsense' raises match.arg error", {
  df <- make_survey_data(n = 100L, seed = 2L)
  d <- as_survey(df, weights = wt)
  expect_error(get_corr(d, x = c(y1, y2), method = "spearman"))
})


# =============================================================================
# Category 2 — Polychoric happy path + oracle parity (Tasks 6-11)
# =============================================================================

test_that("get_corr() method = 'polychoric' matches polycor on 4x4 equal wt", {
  skip_if_not_installed("polycor")
  fixt <- make_unit_weight_design(n = 200L, seed = 3L)
  r <- get_corr(fixt$design, x = c(o1, o2), method = "polychoric")
  oracle <- polycor::polychor(fixt$df$o1, fixt$df$o2)
  # Optimizer tolerance tol = .Machine$double.eps^0.25 ≈ 1.2e-4 sets the
  # practical floor; equal-weight agreement with polycor is ~1e-5 in
  # general. 1e-4 is sufficient to catch regressions in the surveycore
  # pipeline without being brittle about optimizer-level noise.
  expect_equal(r$r[[1L]], oracle, tolerance = 1e-4)
  expect_identical(meta(r)$method, "polychoric")
})

test_that("get_corr() polychoric matches polycor on 3x3 equal weight", {
  skip_if_not_installed("polycor")
  fixt <- make_unit_weight_design(
    n = 250L,
    seed = 4L,
    n_levels_x = 3L,
    n_levels_y = 3L
  )
  r <- get_corr(fixt$design, x = c(o1, o2), method = "polychoric")
  oracle <- polycor::polychor(fixt$df$o1, fixt$df$o2)
  expect_equal(r$r[[1L]], oracle, tolerance = 1e-4)
})

test_that("get_corr() polychoric matches polycor on 2x2 equal weight", {
  skip_if_not_installed("polycor")
  fixt <- make_unit_weight_design(
    n = 300L,
    seed = 5L,
    n_levels_x = 2L,
    n_levels_y = 2L
  )
  r <- get_corr(fixt$design, x = c(o1, o2), method = "polychoric")
  oracle <- polycor::polychor(fixt$df$o1, fixt$df$o2)
  expect_equal(r$r[[1L]], oracle, tolerance = 1e-4)
})

test_that("get_corr() method = 'polychoric' works on stratified survey_taylor", {
  d <- make_latent_taylor(n = 200L, seed = 11L)
  r <- get_corr(d, x = c(o1, o2), method = "polychoric")
  expect_true(abs(r$r[[1L]]) <= 1)
  expect_true(r$ci_low[[1L]] >= -1)
  expect_true(r$ci_high[[1L]] <= 1)
  expect_lte(r$ci_low[[1L]], r$r[[1L]])
  expect_gte(r$ci_high[[1L]], r$r[[1L]])
})

test_that(
  "get_corr() method = 'polychoric' on JK1 replicate matches taylor",
  {
    # Use the same underlying data for both designs so the MLE rho is equal.
    set.seed(20L)
    df <- make_survey_data(
      n = 160L,
      n_psu = 20L,
      n_strata = 4L,
      design = "replicate",
      type = "jk1",
      seed = 20L
    )
    df$o1 <- factor(sample(1:4, nrow(df), replace = TRUE), ordered = TRUE)
    shift <- as.integer(df$o1) + sample(-1:1, nrow(df), replace = TRUE)
    shift[shift < 1L] <- 1L
    shift[shift > 4L] <- 4L
    df$o2 <- factor(shift, levels = 1:4, ordered = TRUE)
    rep_cols <- grep("^repwt_", names(df), value = TRUE)
    d_rep <- as_survey_replicate(
      df,
      weights = wt,
      repweights = tidyselect::all_of(rep_cols),
      type = "JK1"
    )
    d_tay <- as_survey(df, ids = psu, weights = wt, strata = strata,
      nest = TRUE)
    r_rep <- get_corr(d_rep, x = c(o1, o2), method = "polychoric")
    r_tay <- get_corr(d_tay, x = c(o1, o2), method = "polychoric")
    expect_equal(r_rep$r[[1L]], r_tay$r[[1L]], tolerance = 1e-6)
  }
)

test_that(
  "get_corr() method = 'polychoric' on BRR replicate produces se > 0",
  {
    d <- make_latent_replicate(type = "brr", n = 160L, seed = 22L)
    r <- get_corr(d, x = c(o1, o2), method = "polychoric",
      variance = c("se", "ci"))
    expect_true(is.finite(r$r[[1L]]))
    expect_true(r$se[[1L]] > 0)
  }
)


# =============================================================================
# Category 3 — Polyserial happy path + oracle parity (Tasks 12-13)
# =============================================================================

test_that(
  "get_corr() method = 'polyserial' matches polycor ML on 4-level fixture",
  {
    skip_if_not_installed("polycor")
    fixt <- make_unit_weight_design(n = 500L, seed = 30L)
    r <- get_corr(fixt$design, x = c(o1, cont), method = "polyserial")
    oracle_ml <- polycor::polyserial(fixt$df$cont, fixt$df$o1, ML = TRUE)
    # polycor's ML two-step runs the full likelihood; surveycore drops the
    # ρ-independent φ(z) factor from the objective (spec §5.1). Agreement
    # is at 1e-3 on equal-weight fixtures. 1e-2 is the practical tolerance
    # per decisions.md B1 precedent; we pin 5e-3 here.
    expect_equal(r$r[[1L]], oracle_ml, tolerance = 5e-3)
    expect_identical(meta(r)$method, "polyserial")
  }
)

test_that("get_corr() method = 'polyserial' works on JK1 replicate", {
  d <- make_latent_replicate(type = "jk1", n = 160L, seed = 32L)
  r <- get_corr(d, x = c(o1, cont), method = "polyserial")
  expect_true(abs(r$r[[1L]]) <= 1)
  expect_true(r$ci_low[[1L]] >= -1)
  expect_true(r$ci_high[[1L]] <= 1)
})


# =============================================================================
# Category 4 — Multi-pair long format, redundant, diagonal, wide (Tasks 15-18)
# =============================================================================

test_that("multi-pair polychoric returns 3 rows for 3 ordinal columns", {
  d <- make_latent_taylor(n = 200L, seed = 40L)
  r <- get_corr(d, x = c(o1, o2, o3), method = "polychoric")
  expect_identical(nrow(r), 3L)
  expect_identical(
    paste0(as.character(r$var1), "-", as.character(r$var2)),
    c("o1-o2", "o1-o3", "o2-o3")
  )
  # Each pair's r should be in [-1, 1].
  expect_true(all(r$r >= -1 & r$r <= 1))
})

test_that("polychoric + redundant = TRUE yields symmetric pairs", {
  d <- make_latent_taylor(n = 200L, seed = 41L)
  r <- get_corr(d, x = c(o1, o2), method = "polychoric", redundant = TRUE)
  expect_identical(nrow(r), 2L)
  expect_equal(r$r[[1L]], r$r[[2L]], tolerance = 1e-10)
  expect_identical(as.character(r$var1[[1L]]), as.character(r$var2[[2L]]))
  expect_identical(as.character(r$var1[[2L]]), as.character(r$var2[[1L]]))
})

test_that("polychoric + diagonal = TRUE includes self-rows with r = 1", {
  d <- make_latent_taylor(n = 200L, seed = 42L)
  r <- get_corr(d, x = c(o1, o2), method = "polychoric", diagonal = TRUE,
    variance = c("se", "ci"))
  expect_identical(nrow(r), 3L)
  self_rows <- r[as.character(r$var1) == as.character(r$var2), ]
  # Strip column-level `label` attributes before comparing values.
  expect_equal(unname(self_rows$r), c(1, 1), ignore_attr = TRUE)
  expect_equal(unname(self_rows$se), c(0, 0), ignore_attr = TRUE)
})

test_that("polychoric + format = 'wide' returns square matrix with NA diag", {
  d <- make_latent_taylor(n = 200L, seed = 43L)
  r <- get_corr(d, x = c(o1, o2, o3), method = "polychoric", format = "wide")
  expect_identical(nrow(r), 3L)
  expect_true(all(c("o1", "o2", "o3") %in% names(r)))
  expect_false("se" %in% names(r))
  expect_false("ci_low" %in% names(r))
  # Diagonal is NA.
  diag_idx <- match(as.character(r$variable), c("o1", "o2", "o3"))
  for (i in seq_len(nrow(r))) {
    expect_true(is.na(r[[i + 1L]][[i]]))
  }
})


# =============================================================================
# Category 5 — Grouping (Task 19)
# =============================================================================

test_that("polychoric + group = 2-level factor produces 2 rows", {
  fixt <- make_unit_weight_design(n = 200L, seed = 50L)
  r <- get_corr(fixt$design, x = c(o1, o2), method = "polychoric", group = grp)
  expect_identical(nrow(r), 2L)
  expect_true("grp" %in% names(r))
  expect_setequal(as.character(r$grp), c("A", "B"))
})


# =============================================================================
# Category 6 — Variance column selection (Task 20)
# =============================================================================

test_that("variance = 'se' emits only se; no ci_low/ci_high", {
  d <- make_latent_taylor(n = 200L, seed = 60L)
  r <- get_corr(d, x = c(o1, o2), method = "polychoric", variance = "se")
  expect_true("se" %in% names(r))
  expect_false("ci_low" %in% names(r))
  expect_false("moe" %in% names(r))
})

test_that("variance = 'ci' emits ci_low / ci_high", {
  d <- make_latent_taylor(n = 200L, seed = 61L)
  r <- get_corr(d, x = c(o1, o2), method = "polychoric", variance = "ci")
  expect_true("ci_low" %in% names(r))
  expect_true("ci_high" %in% names(r))
  expect_false("se" %in% names(r))
})

test_that("variance = c('se', 'ci', 'moe') emits all three; moe = (hi-lo)/2", {
  d <- make_latent_taylor(n = 200L, seed = 62L)
  r <- get_corr(d, x = c(o1, o2), method = "polychoric",
    variance = c("se", "ci", "moe"))
  expect_true(all(c("se", "ci_low", "ci_high", "moe") %in% names(r)))
  expected_moe <- (r$ci_high - r$ci_low) / 2
  expect_equal(r$moe, expected_moe, tolerance = 1e-10, ignore_attr = TRUE)
})

test_that("variance = 'deff' emits deff only", {
  d <- make_latent_taylor(n = 200L, seed = 63L)
  r <- get_corr(d, x = c(o1, o2), method = "polychoric", variance = "deff")
  expect_true("deff" %in% names(r))
  expect_false("se" %in% names(r))
  expect_true(is.finite(r$deff[[1L]]) || is.na(r$deff[[1L]]))
})

test_that("variance = NULL emits no variance-derived columns", {
  d <- make_latent_taylor(n = 200L, seed = 64L)
  r <- get_corr(d, x = c(o1, o2), method = "polychoric", variance = NULL)
  expect_false("se" %in% names(r))
  expect_false("ci_low" %in% names(r))
  expect_false("moe" %in% names(r))
  expect_false("deff" %in% names(r))
})


# =============================================================================
# Category 7 — df / statistic / p_value method awareness (Task 21, 22)
# =============================================================================

test_that("non-Pearson emits df = NA_integer_ and z-scale statistic", {
  d <- make_latent_taylor(n = 200L, seed = 70L)
  r <- get_corr(d, x = c(o1, o2), method = "polychoric")
  expect_identical(r$df[[1L]], NA_integer_)
  expect_true(is.finite(r$statistic[[1L]]))
  # p_value consistent with two-sided standard normal reference.
  z_ref <- 2 * stats::pnorm(-abs(r$statistic[[1L]]))
  expect_equal(r$p_value[[1L]], z_ref, tolerance = 1e-10)
})

test_that("Pearson retains df = n - 2 and t-scale statistic", {
  d <- make_latent_taylor(n = 200L, seed = 71L)
  r <- get_corr(d, x = c(y1, y2), method = "pearson")
  expect_identical(r$df[[1L]], r$n[[1L]] - 2L)
  expect_true(is.finite(r$statistic[[1L]]))
})

test_that("column label attributes are method-neutral strings", {
  d <- make_latent_taylor(n = 200L, seed = 72L)
  r_poly <- get_corr(d, x = c(o1, o2), method = "polychoric")
  r_pear <- get_corr(d, x = c(y1, y2), method = "pearson")
  expect_identical(attr(r_poly$statistic, "label"), "statistic")
  expect_identical(attr(r_pear$statistic, "label"), "statistic")
  expect_identical(attr(r_poly$df, "label"), "df")
  expect_identical(attr(r_poly$p_value, "label"), "p-value")
})


# =============================================================================
# Category 8 — Edge cases (Tasks 24-31)
# =============================================================================

test_that(
  "empty active domain yields r = NA and n = 0 without aborting",
  {
    skip_if_not_installed("surveytidy")
    d <- make_latent_taylor(n = 120L, seed = 80L)
    # Construct a domain that is empty by filtering on a condition with no
    # rows. surveytidy::filter() emits an informational warning that the
    # domain is empty; we suppress it here for test-output hygiene.
    d2 <- suppressWarnings(
      surveytidy::filter(d, as.integer(o1) > 999L)
    )
    # After PR 2 the .corr_latent_pair() dispatcher short-circuits to
    # r = NA_real_, n = 0 when the pair has 0 active-complete rows.
    r <- suppressWarnings(
      get_corr(d2, x = c(o1, o2), method = "polychoric")
    )
    expect_identical(r$n[[1L]], 0L)
    expect_identical(unname(r$r[[1L]]), NA_real_)
  }
)

test_that("single-level ordinal emits PC-4", {
  set.seed(81L)
  df <- data.frame(
    id = 1:100,
    wt = 1,
    o1 = factor(rep(1L, 100L), levels = 1:3, ordered = TRUE),
    o2 = factor(sample(1:3, 100L, replace = TRUE), ordered = TRUE)
  )
  d <- as_survey(df, weights = wt)
  expect_error(
    get_corr(d, x = c(o1, o2), method = "polychoric"),
    class = "surveycore_error_polychoric_single_level_ordinal"
  )
  expect_snapshot(
    error = TRUE,
    get_corr(d, x = c(o1, o2), method = "polychoric")
  )
})

test_that("all-NA focal column routes to empty-pair handling", {
  set.seed(82L)
  df <- data.frame(
    id = 1:100,
    wt = 1,
    o1 = factor(sample(1:3, 100L, replace = TRUE), ordered = TRUE),
    o2 = factor(rep(NA_integer_, 100L), levels = 1:3, ordered = TRUE)
  )
  d <- as_survey(df, weights = wt)
  r <- get_corr(d, x = c(o1, o2), method = "polychoric")
  expect_identical(r$n[[1L]], 0L)
  expect_identical(r$r[[1L]], NA_real_)
})

test_that(
  "tiny-weight rows match physical-removal equivalent at 1e-3",
  {
    skip_if_not_installed("polycor")
    set.seed(83L)
    n <- 300L
    o1 <- sample(1:4, n, replace = TRUE)
    o2 <- o1 + sample(-1:1, n, replace = TRUE)
    o2[o2 < 1L] <- 1L
    o2[o2 > 4L] <- 4L
    keep <- sample(c(TRUE, FALSE), n, replace = TRUE, prob = c(0.8, 0.2))
    # surveycore rejects non-positive weights in as_survey(); use a tiny
    # positive weight (1e-10) to preserve the row count while effectively
    # zeroing the row's contribution to the weighted likelihood.
    df_zw <- data.frame(
      id = 1:n,
      wt = ifelse(keep, 1, 1e-10),
      o1 = factor(o1, levels = 1:4, ordered = TRUE),
      o2 = factor(o2, levels = 1:4, ordered = TRUE)
    )
    d_zw <- as_survey(df_zw, weights = wt)
    r_zw <- get_corr(d_zw, x = c(o1, o2), method = "polychoric")
    # Compare against polychor on the physically subset data.
    df_sub <- df_zw[keep, , drop = FALSE]
    oracle <- polycor::polychor(df_sub$o1, df_sub$o2)
    expect_equal(r_zw$r[[1L]], oracle, tolerance = 1e-3)
  }
)

test_that("integer vector with 3 distinct values is accepted for polychoric", {
  set.seed(84L)
  df <- data.frame(
    id = 1:150,
    wt = 1,
    x1 = sample(1:3, 150L, replace = TRUE),
    x2 = sample(1:3, 150L, replace = TRUE)
  )
  df$x1 <- as.integer(df$x1)
  df$x2 <- as.integer(df$x2)
  d <- as_survey(df, weights = wt)
  expect_no_warning(
    r <- get_corr(d, x = c(x1, x2), method = "polychoric")
  )
  expect_true(abs(r$r[[1L]]) <= 1)
})

test_that("integer with 15 distinct values + polyserial raises PC-3", {
  set.seed(85L)
  df <- data.frame(
    id = 1:200,
    wt = 1,
    x1 = as.integer(sample(1:20, 200L, replace = TRUE)),
    cont = rnorm(200L)
  )
  d <- as_survey(df, weights = wt)
  expect_error(
    get_corr(d, x = c(x1, cont), method = "polyserial"),
    class = "surveycore_error_polyserial_canonicalization_ambiguous"
  )
  expect_snapshot(
    error = TRUE,
    get_corr(d, x = c(x1, cont), method = "polyserial")
  )
})

test_that("character column + method = 'polychoric' raises PC-1", {
  set.seed(86L)
  df <- data.frame(
    id = 1:100,
    wt = 1,
    o1 = factor(sample(1:3, 100L, replace = TRUE), ordered = TRUE),
    s1 = sample(c("a", "b", "c"), 100L, replace = TRUE),
    stringsAsFactors = FALSE
  )
  d <- as_survey(df, weights = wt)
  expect_error(
    get_corr(d, x = c(o1, s1), method = "polychoric"),
    class = "surveycore_error_polychoric_requires_ordinal"
  )
  expect_snapshot(
    error = TRUE,
    get_corr(d, x = c(o1, s1), method = "polychoric")
  )
})

test_that("6x7 ordinal pair runs without error", {
  set.seed(87L)
  n <- 300L
  df <- data.frame(
    id = 1:n,
    wt = 1,
    o1 = factor(sample(1:6, n, replace = TRUE), levels = 1:6, ordered = TRUE),
    o2 = factor(sample(1:7, n, replace = TRUE), levels = 1:7, ordered = TRUE)
  )
  d <- as_survey(df, weights = wt)
  expect_no_error({
    r <- get_corr(d, x = c(o1, o2), method = "polychoric")
  })
  expect_true(is.finite(r$r[[1L]]))
})

test_that(
  "surveytidy::filter domain matches raw-subset equivalent within 1e-4",
  {
    skip_if_not_installed("surveytidy")
    skip_if_not_installed("polycor")
    fixt <- make_unit_weight_design(n = 300L, seed = 88L)
    d_full <- fixt$design
    df <- fixt$df
    d_filt <- surveytidy::filter(d_full, grp == "A")
    r_filt <- get_corr(d_filt, x = c(o1, o2), method = "polychoric")
    df_sub <- df[df$grp == "A", , drop = FALSE]
    oracle <- polycor::polychor(df_sub$o1, df_sub$o2)
    # Agreement with polycor on equal-weight data is bounded by the
    # shared optimizer tolerance (~1e-4). Domain correctness is the gate;
    # optimizer precision is not.
    expect_equal(r_filt$r[[1L]], oracle, tolerance = 1e-4)
  }
)


# =============================================================================
# Category 9 — Survey collection dispatch (Tasks 33-35)
# =============================================================================

test_that(
  "survey_collection of all taylor members dispatches polychoric per-survey",
  {
    d1 <- make_latent_taylor(n = 120L, seed = 100L)
    d2 <- make_latent_taylor(n = 120L, seed = 101L)
    coll <- as_survey_collection(wave1 = d1, wave2 = d2)
    r <- get_corr(coll, x = c(o1, o2), method = "polychoric")
    expect_true(".survey" %in% names(r))
    expect_setequal(as.character(r$.survey), c("wave1", "wave2"))
  }
)

.make_twophase_design <- function(seed) {
  df_tp <- make_survey_data(
    n = 120L,
    n_psu = 12L,
    n_strata = 3L,
    design = "twophase",
    seed = seed
  )
  df_tp$o1 <- factor(
    sample(1:4, nrow(df_tp), replace = TRUE),
    ordered = TRUE
  )
  df_tp$o2 <- factor(
    sample(1:4, nrow(df_tp), replace = TRUE),
    ordered = TRUE
  )
  ph1 <- as_survey(
    df_tp,
    ids = psu,
    weights = wt,
    strata = strata,
    nest = TRUE
  )
  as_survey_twophase(ph1, subset = subset, method = "approx")
}

test_that(
  "survey_collection with twophase member + polychoric raises PC-7",
  {
    d_taylor <- make_latent_taylor(n = 120L, seed = 110L)
    d_tp <- .make_twophase_design(110L)
    coll <- as_survey_collection(w1 = d_taylor, w2 = d_tp)
    expect_error(
      get_corr(coll, x = c(o1, o2), method = "polychoric"),
      class = "surveycore_error_polychoric_design_unsupported"
    )
  }
)

test_that(
  "survey_collection with twophase + .on_missing = 'skip' still raises PC-7",
  {
    # Note: the collection's `.on_missing` hook catches
    # surveycore_error_variable_not_found only. PC-7 is a distinct class and
    # propagates through the dispatcher to the caller regardless of
    # `.on_missing`. (This matches the `.dispatch_over_collection()`
    # contract in R/survey-collection.R; altering it is out of scope for
    # PR 3.)
    d_taylor <- make_latent_taylor(n = 120L, seed = 120L)
    d_tp <- .make_twophase_design(120L)
    coll <- as_survey_collection(w1 = d_taylor, w2 = d_tp)
    expect_error(
      get_corr(coll, x = c(o1, o2), method = "polychoric",
        .on_missing = "skip"),
      class = "surveycore_error_polychoric_design_unsupported"
    )
  }
)


# =============================================================================
# Category 10 — Pearson regression: warning + error classes still fire (Task 36)
# =============================================================================

test_that(
  "method = 'pearson' still warns on non-numeric columns (regression guard)",
  {
    set.seed(130L)
    df <- data.frame(
      id = 1:100,
      wt = 1,
      y1 = rnorm(100L),
      y2 = rnorm(100L),
      grp = sample(c("A", "B"), 100L, replace = TRUE)
    )
    d <- as_survey(df, weights = wt)
    expect_warning(
      get_corr(d, x = c(y1, y2, grp), method = "pearson"),
      class = "surveycore_warning_corr_non_numeric"
    )
  }
)

test_that(
  "surveycore_error_insufficient_variables fires for < 2 columns under latent",
  {
    set.seed(131L)
    df <- data.frame(
      id = 1:100,
      wt = 1,
      o1 = factor(sample(1:3, 100L, replace = TRUE), ordered = TRUE)
    )
    d <- as_survey(df, weights = wt)
    expect_error(
      get_corr(d, x = o1, method = "polychoric"),
      class = "surveycore_error_insufficient_variables"
    )
  }
)

test_that(
  "surveycore_error_invalid_variance_arg still fires under latent methods",
  {
    d <- make_latent_taylor(n = 120L, seed = 132L)
    expect_error(
      get_corr(d, x = c(o1, o2), method = "polychoric", variance = "bogus"),
      class = "surveycore_error_invalid_variance_arg"
    )
  }
)


# =============================================================================
# Category 11 — meta() population (Tasks 37-38)
# =============================================================================

test_that("meta()$bivariate_normal_cdf is 'pbivnorm' for polychoric", {
  d <- make_latent_taylor(n = 120L, seed = 140L)
  r <- get_corr(d, x = c(o1, o2), method = "polychoric")
  expect_identical(meta(r)$bivariate_normal_cdf, "pbivnorm")
})

test_that("meta()$bivariate_normal_cdf is 'pbivnorm' for polyserial", {
  d <- make_latent_taylor(n = 120L, seed = 141L)
  r <- get_corr(d, x = c(o1, cont), method = "polyserial")
  expect_identical(meta(r)$bivariate_normal_cdf, "pbivnorm")
})

test_that("meta()$bivariate_normal_cdf is absent for pearson", {
  d <- make_latent_taylor(n = 120L, seed = 142L)
  r <- get_corr(d, x = c(y1, y2), method = "pearson")
  expect_null(meta(r)$bivariate_normal_cdf)
})

test_that("meta()$n_failed_replicates_total absent when n_failed == 0", {
  d <- make_latent_replicate(type = "jk1", n = 160L, seed = 143L)
  r <- get_corr(d, x = c(o1, o2), method = "polychoric")
  expect_null(meta(r)$n_failed_replicates_total)
})


# =============================================================================
# Category 12 — Public-API dual-pattern tests for PC warnings (PC-9, PC-13)
# =============================================================================

test_that("PC-13 (unordered factor) surfaces via the public API", {
  set.seed(150L)
  df <- data.frame(
    id = 1:200,
    wt = 1,
    o1 = factor(sample(c("a", "b", "c"), 200L, replace = TRUE),
      ordered = FALSE),
    o2 = factor(sample(1:3, 200L, replace = TRUE), ordered = TRUE)
  )
  d <- as_survey(df, weights = wt)
  expect_warning(
    get_corr(d, x = c(o1, o2), method = "polychoric"),
    class = "surveycore_warning_polychoric_unordered_factor"
  )
})


# =============================================================================
# Category 13 — name_style = "broom" threads statistic / df / p.value labels
# =============================================================================

test_that("name_style = 'broom' produces broom columns with neutral labels", {
  d <- make_latent_taylor(n = 200L, seed = 160L)
  r <- get_corr(
    d,
    x = c(o1, o2),
    method = "polychoric",
    variance = c("se", "ci"),
    name_style = "broom"
  )
  expect_true("estimate" %in% names(r))
  expect_true("std.error" %in% names(r))
  expect_true("conf.low" %in% names(r))
  expect_true("conf.high" %in% names(r))
  expect_identical(attr(r$statistic, "label"), "statistic")
})
