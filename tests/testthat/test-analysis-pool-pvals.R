# tests/testthat/test-analysis-pool-pvals.R
#
# Tests for pool_pvals(), print.survey_pooled_pvals(), and the three
# private helpers in R/analysis-helpers.R that support them
# (.is_plain_list, .validate_pval_adjustment_method,
# .validate_list_columns).

# ── Phase 2: Private helpers ──────────────────────────────────────────────────

test_that(".is_plain_list() distinguishes plain lists from data frames", {
  expect_true(.is_plain_list(list()))
  expect_true(.is_plain_list(list(a = 1, b = 2)))
  expect_false(.is_plain_list(tibble::tibble()))
  expect_false(.is_plain_list(data.frame(a = 1)))
  expect_false(.is_plain_list(c(1, 2)))
  expect_false(.is_plain_list(NULL))
  expect_false(.is_plain_list("a"))
})


# ── Phase 3: Validation precedence — error and warning paths ──────────────────

test_that("pool_pvals() rejects NULL with not_list class", {
  expect_error(
    pool_pvals(NULL),
    class = "surveycore_error_pool_pvals_not_list"
  )
  expect_snapshot(error = TRUE, pool_pvals(NULL))
})

test_that("pool_pvals() rejects a bare tibble with not_list class", {
  expect_error(
    pool_pvals(tibble::tibble(p_value = 0.05)),
    class = "surveycore_error_pool_pvals_not_list"
  )
  expect_snapshot(
    error = TRUE,
    pool_pvals(tibble::tibble(p_value = 0.05))
  )
})

test_that("pool_pvals() rejects an atomic vector with not_list class", {
  expect_error(
    pool_pvals(c(0.01, 0.05)),
    class = "surveycore_error_pool_pvals_not_list"
  )
  expect_snapshot(error = TRUE, pool_pvals(c(0.01, 0.05)))
})

test_that("pool_pvals() rejects empty list with empty class", {
  expect_error(
    pool_pvals(list()),
    class = "surveycore_error_pool_pvals_empty"
  )
  expect_snapshot(error = TRUE, pool_pvals(list()))
})

test_that("pool_pvals() rejects invalid method (string) with invalid_method", {
  res <- list(tibble::tibble(p_value = 0.5))
  expect_error(
    pool_pvals(res, method = "fancy"),
    class = "surveycore_error_pool_pvals_invalid_method"
  )
  expect_snapshot(error = TRUE, pool_pvals(res, method = "fancy"))
})

test_that("pool_pvals() rejects invalid method (length > 1) with invalid_method", {
  res <- list(tibble::tibble(p_value = 0.5))
  expect_error(
    pool_pvals(res, method = c("BH", "holm")),
    class = "surveycore_error_pool_pvals_invalid_method"
  )
  expect_snapshot(
    error = TRUE,
    pool_pvals(res, method = c("BH", "holm"))
  )
})

test_that("pool_pvals() reports element missing p_col with missing_pcol class", {
  res <- list(
    a = tibble::tibble(p_value = c(0.01, 0.04)),
    b = tibble::tibble(other = c(0.02, 0.05))
  )
  expect_error(
    pool_pvals(res),
    class = "surveycore_error_pool_pvals_missing_pcol"
  )
  expect_snapshot(error = TRUE, pool_pvals(res))
})

test_that("pool_pvals() reports id_col collision with id_col_collision class", {
  res <- list(
    tibble::tibble(p_value = c(0.01, 0.04), source = "a"),
    tibble::tibble(p_value = c(0.02, 0.05))
  )
  expect_error(
    pool_pvals(res),
    class = "surveycore_error_pool_pvals_id_col_collision"
  )
  expect_snapshot(error = TRUE, pool_pvals(res))
})

test_that(
  "pool_pvals() warns and renames pre-existing new_col when strip_within_adj = FALSE",
  {
    res <- list(
      a = tibble::tibble(
        p_value = c(0.01, 0.04),
        p_value_adj = c(0.02, 0.04)
      ),
      b = tibble::tibble(p_value = c(0.02, 0.05))
    )
    expect_warning(
      out <- pool_pvals(res),
      class = "surveycore_warning_pool_pvals_input_pre_adjusted"
    )
    expect_true("p_value_adj" %in% names(out))
    expect_true("p_value_adj_within" %in% names(out))
    # NA padding for the second element which lacked the column
    expect_true(all(is.na(out$p_value_adj_within[out$source == "b"])))
    # First element retained the prior values
    expect_equal(
      out$p_value_adj_within[out$source == "a"],
      c(0.02, 0.04)
    )
  }
)

test_that(
  "pool_pvals() silently drops pre-existing new_col when strip_within_adj = TRUE",
  {
    res <- list(
      a = tibble::tibble(
        p_value = c(0.01, 0.04),
        p_value_adj = c(0.02, 0.04)
      ),
      b = tibble::tibble(p_value = c(0.02, 0.05))
    )
    expect_no_warning(
      out <- pool_pvals(res, strip_within_adj = TRUE)
    )
    expect_true("p_value_adj" %in% names(out))
    expect_false("p_value_adj_within" %in% names(out))
    # The retained p_value_adj is the pooled-adjusted one
    expect_equal(
      out$p_value_adj,
      stats::p.adjust(c(0.01, 0.04, 0.02, 0.05), "BH")
    )
  }
)


# ── Phase 4: Happy-path return shape ──────────────────────────────────────────

test_that("pool_pvals() returns a tibble with row sum and column union", {
  res <- list(
    a = tibble::tibble(term = c("x", "y"), p_value = c(0.01, 0.04)),
    b = tibble::tibble(term = "z", p_value = 0.5)
  )
  out <- pool_pvals(res)
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 3L)
  expect_true(all(c("term", "source", "p_value", "p_value_adj") %in% names(out)))
})

test_that("pool_pvals() reports out-of-range pooled p-values with invalid_pvalues", {
  res <- list(
    tibble::tibble(p_value = c(0.5, 1.5)),
    tibble::tibble(p_value = c(0.1, 0.2))
  )
  expect_error(
    pool_pvals(res),
    class = "surveycore_error_pool_pvals_invalid_pvalues"
  )
  expect_snapshot(error = TRUE, pool_pvals(res))
})

test_that("pool_pvals() pooled p_value_adj equals stats::p.adjust(pooled, BH)", {
  res <- list(
    tibble::tibble(p_value = c(0.001, 0.04, 0.5)),
    tibble::tibble(p_value = c(0.01, 0.2))
  )
  out <- pool_pvals(res)
  expect_equal(
    out$p_value_adj,
    stats::p.adjust(c(0.001, 0.04, 0.5, 0.01, 0.2), "BH"),
    tolerance = 1e-12
  )
})

test_that(
  "pool_pvals() warns and returns when all pooled p-values are NA",
  {
    res <- list(
      tibble::tibble(p_value = c(NA_real_, NA_real_)),
      tibble::tibble(p_value = NA_real_)
    )
    expect_warning(
      out <- pool_pvals(res),
      class = "surveycore_warning_pool_pvals_no_pvalues_available"
    )
    expect_true(all(is.na(out$p_value_adj)))
    expect_equal(nrow(out), 3L)
  }
)

test_that("pool_pvals() column ordering: union, then id_col, new_col, within", {
  res <- list(
    a = tibble::tibble(
      term = c("x", "y"),
      p_value = c(0.01, 0.04),
      p_value_adj = c(0.02, 0.05)
    ),
    b = tibble::tibble(term = "z", p_value = 0.5)
  )
  suppressWarnings(out <- pool_pvals(res))
  nm <- names(out)
  # Last three columns: source, p_value_adj, p_value_adj_within
  expect_equal(tail(nm, 3L), c("source", "p_value_adj", "p_value_adj_within"))
  # Prefix is the union of input columns (term, p_value) in input-union order
  expect_equal(head(nm, 2L), c("term", "p_value"))
})

test_that("pool_pvals() result has expected S3 class hierarchy", {
  res <- list(tibble::tibble(p_value = c(0.01, 0.05)))
  out <- pool_pvals(res)
  expect_identical(
    class(out),
    c("survey_pooled_pvals", "tbl_df", "tbl", "data.frame")
  )
})

test_that("pool_pvals() attaches a .meta attribute with the eight required keys", {
  res <- list(
    a = tibble::tibble(p_value = c(0.001, 0.04, NA_real_)),
    b = tibble::tibble(p_value = c(0.01, 0.2))
  )
  out <- pool_pvals(res)
  meta <- attr(out, ".meta")
  expect_true(is.list(meta))
  expect_setequal(
    names(meta),
    c(
      "method",
      "family_size",
      "n_total",
      "n_na",
      "n_significant_05",
      "id_col",
      "p_col",
      "new_col"
    )
  )
  expect_identical(meta$method, "BH")
  expect_identical(meta$family_size, 4L)
  expect_identical(meta$n_total, 5L)
  expect_identical(meta$n_na, 1L)
  expect_identical(meta$id_col, "source")
  expect_identical(meta$p_col, "p_value")
  expect_identical(meta$new_col, "p_value_adj")
  expect_true(is.integer(meta$n_significant_05))
})


# ── Phase 5: print.survey_pooled_pvals() ──────────────────────────────────────

test_that("print.survey_pooled_pvals() snapshot for a representative input", {
  res <- list(
    a = tibble::tibble(term = c("x", "y"), p_value = c(0.001, 0.04)),
    b = tibble::tibble(term = "z", p_value = 0.5),
    c = tibble::tibble(term = "w", p_value = NA_real_)
  )
  out <- pool_pvals(res)
  expect_snapshot(print(out))
})

test_that(
  "print.survey_pooled_pvals() prints NA footer only when n_na > 0",
  {
    res_no_na <- list(
      a = tibble::tibble(p_value = c(0.01, 0.04)),
      b = tibble::tibble(p_value = 0.5)
    )
    out_no_na <- pool_pvals(res_no_na)
    expect_snapshot(print(out_no_na))

    res_with_na <- list(
      a = tibble::tibble(p_value = c(0.01, NA_real_)),
      b = tibble::tibble(p_value = c(NA_real_, 0.5))
    )
    out_with_na <- pool_pvals(res_with_na)
    expect_snapshot(print(out_with_na))
  }
)

test_that("print.survey_pooled_pvals() returns invisible(x)", {
  out <- pool_pvals(list(tibble::tibble(p_value = c(0.01, 0.05))))
  expect_invisible(print(out))
})


# ── Phase 7: Edge cases and parametrized oracle tests ─────────────────────────

test_that("pool_pvals() round-trip oracle holds for every p.adjust method", {
  res <- list(
    a = tibble::tibble(p_value = c(0, 0.001, 0.5)),
    b = tibble::tibble(p_value = c(0.01, NA_real_, 1)),
    c = tibble::tibble(p_value = c(0.04, 0.2, 0.99))
  )
  pooled_raw <- c(0, 0.001, 0.5, 0.01, NA_real_, 1, 0.04, 0.2, 0.99)
  for (m in stats::p.adjust.methods) {
    out <- pool_pvals(res, method = m)
    expect_equal(
      out$p_value_adj,
      stats::p.adjust(pooled_raw, method = m),
      tolerance = 1e-12,
      info = paste0("method = ", m)
    )
  }
})

test_that("pool_pvals() m = 1 identity holds for every p.adjust method", {
  res <- list(tibble::tibble(p_value = 0.04))
  for (m in stats::p.adjust.methods) {
    expect_no_warning(out <- pool_pvals(res, method = m))
    expect_equal(out$p_value_adj, 0.04, info = paste0("method = ", m))
  }
})

test_that("pool_pvals() handles a zero-row tibble in input", {
  res <- list(
    tibble::tibble(p_value = numeric(0)),
    tibble::tibble(p_value = c(0.01, 0.05))
  )
  out <- pool_pvals(res)
  expect_equal(nrow(out), 2L)
  expect_equal(out$source, c("2", "2"))
})

test_that("pool_pvals() preserves NA positions in pooled p_col", {
  res <- list(
    tibble::tibble(p_value = c(0.01, NA_real_, 0.05)),
    tibble::tibble(p_value = c(NA_real_, 0.5))
  )
  out <- pool_pvals(res)
  expect_true(is.na(out$p_value_adj[2]))
  expect_true(is.na(out$p_value_adj[4]))
  expect_false(is.na(out$p_value_adj[1]))
})

test_that("pool_pvals() NA-fills heterogeneous columns across elements", {
  res <- list(
    tibble::tibble(term = c("x", "y"), p_value = c(0.01, 0.04)),
    tibble::tibble(group = c("g1", "g2"), p_value = c(0.5, 0.2))
  )
  out <- pool_pvals(res)
  expect_true(all(c("term", "group") %in% names(out)))
  expect_true(all(is.na(out$group[1:2])))
  expect_true(all(is.na(out$term[3:4])))
})

test_that("pool_pvals() coerces heterogeneous p_col types via bind_rows", {
  res <- list(
    tibble::tibble(p_value = c(0L, 1L)),
    tibble::tibble(p_value = c(0.5, 0.25))
  )
  out <- pool_pvals(res)
  expect_true(is.numeric(out$p_value))
})

test_that("pool_pvals() does NOT preserve column attributes across bind", {
  x <- tibble::tibble(p_value = c(0.01, 0.04))
  attr(x$p_value, "variable_label") <- "Outcome 1"
  y <- tibble::tibble(p_value = c(0.5, 0.2))
  out <- pool_pvals(list(x, y))
  expect_null(attr(out$p_value, "variable_label"))
})

test_that(
  "pool_pvals() collision pattern works with custom new_col name",
  {
    res <- list(
      a = tibble::tibble(p_value = c(0.01, 0.04), fdr_q = c(0.02, 0.04)),
      b = tibble::tibble(p_value = c(0.5, 0.2))
    )
    expect_warning(
      out <- pool_pvals(res, new_col = "fdr_q"),
      class = "surveycore_warning_pool_pvals_input_pre_adjusted"
    )
    expect_true(all(c("fdr_q", "fdr_q_within") %in% names(out)))
  }
)

test_that("pool_pvals() with method = 'none' returns raw p-values", {
  res <- list(
    tibble::tibble(p_value = c(0.01, 0.04, 0.5))
  )
  out <- pool_pvals(res, method = "none")
  expect_equal(out$p_value_adj, c(0.01, 0.04, 0.5), tolerance = 1e-12)
})

test_that("pool_pvals() sequential calls with different methods are independent", {
  res <- list(tibble::tibble(p_value = c(0.001, 0.04, 0.5)))
  out_bh <- pool_pvals(res, method = "BH")
  out_bonf <- pool_pvals(res, method = "bonferroni")
  expect_false(identical(out_bh$p_value_adj, out_bonf$p_value_adj))
  # And re-pooling with BH after bonf returns the BH result unchanged
  out_bh_again <- pool_pvals(res, method = "BH")
  expect_equal(out_bh$p_value_adj, out_bh_again$p_value_adj)
})

test_that(
  "pool_pvals() pools heterogeneous-shape get_diffs() and get_pairwise() rows",
  {
    diffs_shape <- tibble::tibble(
      term = c("a", "b"),
      estimate = c(0.5, -0.2),
      p_value = c(0.04, 0.2)
    )
    pairwise_shape <- tibble::tibble(
      level_a = c("g1", "g1"),
      level_b = c("g2", "g3"),
      estimate = c(0.1, 0.3),
      p_value = c(0.01, 0.5)
    )
    out <- pool_pvals(list(diffs = diffs_shape, pair = pairwise_shape))
    nm <- names(out)
    expect_true(all(
      c("term", "level_a", "level_b", "estimate", "p_value") %in% nm
    ))
    expect_equal(tail(nm, 2L), c("source", "p_value_adj"))
    expect_true(all(is.na(out$level_a[1:2])))
    expect_true(all(is.na(out$term[3:4])))
  }
)

test_that("pool_pvals() unnamed list yields character indices in source", {
  res <- list(
    tibble::tibble(p_value = c(0.01, 0.04)),
    tibble::tibble(p_value = 0.5),
    tibble::tibble(p_value = c(0.1, 0.2))
  )
  out <- pool_pvals(res)
  expect_identical(out$source, c("1", "1", "2", "3", "3"))
})

test_that("pool_pvals() mixed-named list interleaves names and indices", {
  res <- list(
    a = tibble::tibble(p_value = c(0.01, 0.04)),
    tibble::tibble(p_value = 0.5)
  )
  out <- pool_pvals(res)
  expect_identical(out$source, c("a", "a", "2"))
})

test_that("pool_pvals() honors custom p_col, new_col, and id_col", {
  res <- list(
    tibble::tibble(pval = c(0.01, 0.04)),
    tibble::tibble(pval = c(0.5, 0.2))
  )
  out <- pool_pvals(
    res,
    p_col = "pval",
    new_col = "pval_adj",
    id_col = ".source"
  )
  expect_true(all(c("pval", "pval_adj", ".source") %in% names(out)))
  expect_equal(
    out$pval_adj,
    stats::p.adjust(c(0.01, 0.04, 0.5, 0.2), "BH"),
    tolerance = 1e-12
  )
})


# ── Phase 8: Integration test with gss_2024 ───────────────────────────────────

test_that(
  "pool_pvals() integrates with two get_diffs() results on gss_2024",
  {
    skip_on_cran()

    d <- suppressWarnings(
      as_survey(gss_2024, weights = wtssps, ids = vpsu, strata = vstrat, nest = TRUE)
    )
    r1 <- get_diffs(d, age, sex, pval_adj = NULL)
    r2 <- get_diffs(d, hrs1, sex, pval_adj = NULL)

    out <- pool_pvals(list(age = r1, hrs1 = r2))
    expect_s3_class(out, "survey_pooled_pvals")
    expect_true(all(c("source", "p_value_adj") %in% names(out)))
    expected <- stats::p.adjust(c(r1$p_value, r2$p_value), method = "BH")
    expect_equal(out$p_value_adj, expected, tolerance = 1e-12)
  }
)
