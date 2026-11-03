# tests/testthat/test-labelled-fixtures.R
#
# Pins the three haven-shaped column fixture builders in
# `helper-test-data.R` against real `haven` output.
#
# The builders use base R only, because `haven` is in Suggests. That buys the
# rest of the feature's tests the ability to construct a `haven_labelled`
# column without `haven` installed, and it costs this file: nothing else proves
# the hand-built class vectors and the tagged-`NA` byte pattern are the shapes
# `haven` actually produces. F-3, F-5 and F-6 are that proof, so each carries a
# block-level `skip_if_not_installed("haven")`. F-1, F-2 and F-4 assert base-R
# properties of the builder output and need no guard.
#
# This file builds no survey design, so it makes no `test_invariants()` call.

# ------------------------------------------------------------------------------
# make_tagged_na() — base-R properties (F-1, F-2, F-4)
# ------------------------------------------------------------------------------

# F-1
test_that("make_tagged_na() returns a value that base R reads as NA", {
  expect_true(is.na(make_tagged_na("a")))
})

# F-2
test_that("make_tagged_na() returns a length-1 double", {
  result <- make_tagged_na("a")

  expect_identical(typeof(result), "double")
  expect_identical(length(result), 1L)
})

# F-4
test_that("make_tagged_na() gives different tags different byte patterns", {
  # `identical()` folds every NaN payload together under its default
  # `single.NA = TRUE`, so two differently tagged NAs compare equal there.
  # `single.NA = FALSE` is the setting that looks at the payload.
  expect_false(
    identical(make_tagged_na("a"), make_tagged_na("b"), single.NA = FALSE)
  )
  expect_identical(
    writeBin(make_tagged_na("a"), raw(), endian = "little")[5L],
    charToRaw("a")
  )
  expect_identical(
    writeBin(make_tagged_na("b"), raw(), endian = "little")[5L],
    charToRaw("b")
  )
})

# ------------------------------------------------------------------------------
# make_tagged_na() — pinned against haven (F-3)
# ------------------------------------------------------------------------------

# F-3
test_that("make_tagged_na() output is identical to haven::tagged_na() output", {
  skip_if_not_installed("haven")

  expect_identical(haven::na_tag(make_tagged_na("a")), "a")
  expect_identical(haven::na_tag(make_tagged_na("z")), "z")

  # `expect_identical()` cannot see a NaN payload (see F-4), so compare the
  # eight bytes directly. That is the check that pins the builder to `haven`.
  expect_identical(
    writeBin(make_tagged_na("a"), raw(), endian = "little"),
    writeBin(haven::tagged_na("a"), raw(), endian = "little")
  )
  expect_identical(
    writeBin(make_tagged_na("z"), raw(), endian = "little"),
    writeBin(haven::tagged_na("z"), raw(), endian = "little")
  )
})

# ------------------------------------------------------------------------------
# make_labelled() — pinned against haven (F-5)
# ------------------------------------------------------------------------------

# F-5
test_that("make_labelled() output is identical to haven::labelled() output", {
  skip_if_not_installed("haven")

  expect_identical(
    make_labelled(
      c(1, 2, 3),
      labels = c(Low = 1, High = 3),
      label = "Agreement"
    ),
    haven::labelled(
      c(1, 2, 3),
      labels = c(Low = 1, High = 3),
      label = "Agreement"
    )
  )

  expect_identical(
    make_labelled(c(1L, 2L, 3L), labels = c(Low = 1L, High = 3L)),
    haven::labelled(c(1L, 2L, 3L), labels = c(Low = 1L, High = 3L))
  )

  expect_identical(
    make_labelled(c("a", "b"), labels = c(Alpha = "a"), label = "Letter"),
    haven::labelled(c("a", "b"), labels = c(Alpha = "a"), label = "Letter")
  )

  expect_identical(
    make_labelled(c(1, 2), labels = c(One = 1)),
    haven::labelled(c(1, 2), labels = c(One = 1))
  )
})

# ------------------------------------------------------------------------------
# make_labelled_spss() — pinned against haven (F-6)
# ------------------------------------------------------------------------------

# F-6
test_that("make_labelled_spss() matches haven::labelled_spss() output", {
  skip_if_not_installed("haven")

  expect_identical(
    make_labelled_spss(
      c(1, 2, 99),
      labels = c(Low = 1, High = 2, Refused = 99),
      na_values = 99,
      label = "Agreement"
    ),
    haven::labelled_spss(
      c(1, 2, 99),
      labels = c(Low = 1, High = 2, Refused = 99),
      na_values = 99,
      label = "Agreement"
    )
  )

  expect_identical(
    make_labelled_spss(
      c(1, 2, 98),
      labels = c(Low = 1, High = 2),
      na_range = c(90, 99),
      label = "Agreement"
    ),
    haven::labelled_spss(
      c(1, 2, 98),
      labels = c(Low = 1, High = 2),
      na_range = c(90, 99),
      label = "Agreement"
    )
  )

  expect_identical(
    make_labelled_spss(
      c(1, 98, 99),
      labels = c(Low = 1),
      na_values = 99,
      na_range = c(90, 98),
      label = "Agreement"
    ),
    haven::labelled_spss(
      c(1, 98, 99),
      labels = c(Low = 1),
      na_values = 99,
      na_range = c(90, 98),
      label = "Agreement"
    )
  )
})
