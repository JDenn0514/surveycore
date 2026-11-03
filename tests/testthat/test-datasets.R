test_that("datasets load and have expected dimensions", {
  expect_equal(nrow(nhanes_2017), 9254)
  expect_equal(ncol(nhanes_2017), 14)

  expect_equal(nrow(acs_pums_wy), 5962)
  expect_equal(ncol(acs_pums_wy), 96)

  expect_equal(nrow(anes_2024), 5521)
  expect_equal(ncol(anes_2024), 19)

  expect_equal(nrow(gss_2024), 3309)
  expect_equal(ncol(gss_2024), 27)

  expect_equal(nrow(pew_npors_2025), 5022)

  expect_equal(nrow(pew_jewish_2020), 5881)
  expect_equal(ncol(pew_jewish_2020), 130)
})

test_that("every column of nhanes_2017 carries a variable label", {
  has_label <- vapply(
    nhanes_2017,
    function(x) is.character(attr(x, "label", exact = TRUE)),
    logical(1)
  )
  expect_true(all(has_label))
  expect_equal(attr(nhanes_2017$riagendr, "label", exact = TRUE), "Gender")
})

test_that("no column of nhanes_2017 carries value labels", {
  # NHANES publishes SAS XPORT files. That format stores a label for each
  # variable, but no labels for the codes inside a variable. ?nhanes_2017
  # documents the code meanings in its Format section instead (issue #214).
  has_labels <- vapply(
    nhanes_2017,
    function(x) !is.null(attr(x, "labels", exact = TRUE)),
    logical(1)
  )
  expect_false(any(has_labels))
})

test_that("every attribute the dataset docs tell the reader to read exists", {
  # One row per attr() call shown in R/data.R, in @details or in @examples. A
  # documented call that returns NULL runs clean and passes R CMD check,
  # because NULL is a legal result, so nothing else catches it (issue #214).
  documented <- list(
    c("nhanes_2017", "riagendr", "label"),
    c("nhanes_2017", "ridreth3", "label"),
    c("anes_2024", "v241177", "label"),
    c("anes_2024", "v241177", "labels"),
    c("anes_2024", "v241550", "label"),
    c("anes_2024", "v241550", "labels"),
    c("gss_2024", "happy", "label"),
    c("gss_2024", "happy", "labels"),
    c("pew_npors_2025", "smuse_fb", "label"),
    c("pew_npors_2025", "smuse_fb", "labels"),
    c("pew_npors_2025", "smuse_fb", "question_preface"),
    c("pew_jewish_2020", "relconsider_a", "label"),
    c("pew_jewish_2020", "relconsider_a", "labels"),
    c("pew_jewish_2020", "discrim_a", "label"),
    c("pew_jewish_2020", "discrim_a", "labels"),
    c("pew_jewish_2020", "discrim_a", "question_preface"),
    c("ns_wave1", "group_favorability_blacks", "label"),
    c("ns_wave1", "group_favorability_blacks", "question_preface"),
    c("ns_wave1", "news_sources_cnn", "labels"),
    c("ca_api_2000", "api00", "label"),
    c("ca_api_2000", "stype", "labels")
  )

  for (row in documented) {
    dataset <- get(row[1], envir = asNamespace("surveycore"))
    value <- attr(dataset[[row[2]]], row[3], exact = TRUE)
    expect_false(
      is.null(value),
      label = paste0("attr(", row[1], "$", row[2], ', "', row[3], '")')
    )
  }
})

test_that("acs_pums_wy has 80 replicate weights", {
  n_rep <- sum(grepl("^pwgtp[0-9]", names(acs_pums_wy)))
  expect_equal(n_rep, 80)
})

test_that("pew_jewish_2020 has 100 replicate weights", {
  n_rep <- sum(grepl("^extweight[0-9]", names(pew_jewish_2020)))
  expect_equal(n_rep, 100)
})

test_that("pew_npors_2025 smuse_* variables carry question_preface", {
  qp <- attr(pew_npors_2025$smuse_fb, "question_preface")
  expect_false(is.null(qp))
  expect_true(nchar(qp) > 0)
})

test_that("pew_jewish_2020 battery variables carry question_preface", {
  qp <- attr(pew_jewish_2020$discrim_a, "question_preface")
  expect_false(is.null(qp))
  expect_true(nchar(qp) > 0)
})
