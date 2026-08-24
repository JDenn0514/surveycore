# tests/testthat/test-dataset-metadata.R
#
# Dataset-level metadata: the read path.
#
# Covers extract_dataset_metadata() and the internal read machinery it drives:
# the guarded property reader, the seven-name whole-frame attribute reader, the
# strict-ISO date coercion, and the value checker's warn-and-skip mode.
#
# Sections:
#   1. Fixtures
#   2. extract_dataset_metadata() — key resolution and list format
#   3. extract_dataset_metadata() — fill semantics
#   4. extract_dataset_metadata() — data_frame format
#   5. Data-frame mode read path (attribute reader)
#   6. Error paths
#   7. Stale (pre-1.2.0) objects

# ── 1. Fixtures ───────────────────────────────────────────────────────────────

test_that("make_dataset_df() attaches the six canonical keys as attributes", {
  df <- make_dataset_df()

  expect_true(is.data.frame(df))
  for (key in names(full_keys)) {
    expect_identical(attr(df, key, exact = TRUE), full_keys[[key]])
  }
})

test_that("make_dataset_df() attaches only the keys it is given", {
  df <- make_dataset_df(keys = list(vendor = "Ipsos"))

  expect_identical(attr(df, "vendor", exact = TRUE), "Ipsos")
  expect_null(attr(df, "survey_name", exact = TRUE))
})

test_that("make_stale_metadata_design() strips the property on all 4 classes", {
  for (cls in c("taylor", "replicate", "twophase", "nonprob")) {
    d <- make_stale_metadata_design(cls)
    test_invariants(d)

    expect_false("dataset_metadata" %in% S7::prop_names(d@metadata))
    expect_error(d@metadata@dataset_metadata, regexp = "find property")
  }
})

# ── 2. Key resolution and list format ─────────────────────────────────────────

test_that("extract_dataset_metadata() returns all present keys on a design", {
  df <- make_survey_data(n = 40L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)
  d@metadata@dataset_metadata <- full_keys

  expect_identical(extract_dataset_metadata(d), full_keys)
})

test_that("extract_dataset_metadata() returns all present keys on a frame", {
  df <- make_dataset_df()

  expect_identical(extract_dataset_metadata(df), full_keys)
})

test_that("extract_dataset_metadata() returns visibly on a design", {
  df <- make_survey_data(n = 40L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)
  d@metadata@dataset_metadata <- full_keys

  # The sibling SETTERS return invisibly; this extractor must not. withVisible()
  # is the only assertion that separates the two.
  seen <- withVisible(extract_dataset_metadata(d))

  expect_true(seen$visible)
  expect_identical(seen$value, full_keys)
})

test_that("extract_dataset_metadata() returns visibly on a frame", {
  df <- make_dataset_df()

  seen <- withVisible(extract_dataset_metadata(df))

  expect_true(seen$visible)
  expect_identical(seen$value, full_keys)
})

test_that("extract_dataset_metadata() returns list() when nothing is set", {
  df <- make_survey_data(n = 40L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)

  expect_identical(extract_dataset_metadata(d), list())
})

test_that("extract_dataset_metadata() returns list() for a bare frame", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)

  expect_identical(extract_dataset_metadata(df), list())
})

test_that("extract_dataset_metadata() orders present keys canonically", {
  df <- make_survey_data(n = 40L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)
  d@metadata@dataset_metadata <- list(
    field_period = "February-March 2026",
    vendor = "Ipsos",
    survey_name = "AAA 2026"
  )

  expect_identical(
    names(extract_dataset_metadata(d)),
    c("survey_name", "vendor", "field_period")
  )
})

test_that("extract_dataset_metadata() orders frame keys canonically", {
  df <- make_dataset_df(
    keys = list(
      field_period = "February-March 2026",
      vendor = "Ipsos",
      survey_name = "AAA 2026"
    )
  )

  expect_identical(
    names(extract_dataset_metadata(df)),
    c("survey_name", "vendor", "field_period")
  )
})

test_that("extract_dataset_metadata() accepts bare key names in ...", {
  df <- make_survey_data(n = 40L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)
  d@metadata@dataset_metadata <- full_keys

  expect_identical(
    extract_dataset_metadata(d, vendor, survey_name),
    list(vendor = full_keys$vendor, survey_name = full_keys$survey_name)
  )
})

test_that("extract_dataset_metadata() accepts bare names on a frame", {
  df <- make_dataset_df()

  expect_identical(
    extract_dataset_metadata(df, vendor),
    list(vendor = full_keys$vendor)
  )
})

test_that("extract_dataset_metadata() accepts quoted key names in ...", {
  df <- make_survey_data(n = 40L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)
  d@metadata@dataset_metadata <- full_keys

  expect_identical(
    extract_dataset_metadata(d, "vendor"),
    list(vendor = full_keys$vendor)
  )
})

test_that("extract_dataset_metadata() accepts quoted names on a frame", {
  df <- make_dataset_df()

  expect_identical(
    extract_dataset_metadata(df, "vendor"),
    list(vendor = full_keys$vendor)
  )
})

test_that("extract_dataset_metadata() supports !!! splicing of names", {
  df <- make_survey_data(n = 40L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)
  d@metadata@dataset_metadata <- full_keys
  wanted <- c("vendor", "field_period")

  expect_identical(
    extract_dataset_metadata(d, !!!wanted),
    list(vendor = full_keys$vendor, field_period = full_keys$field_period)
  )
})

test_that("extract_dataset_metadata() supports !!! splicing on a frame", {
  df <- make_dataset_df()
  wanted <- c("vendor", "field_period")

  expect_identical(
    extract_dataset_metadata(df, !!!wanted),
    list(vendor = full_keys$vendor, field_period = full_keys$field_period)
  )
})

test_that("extract_dataset_metadata() preserves request order, not canonical", {
  df <- make_survey_data(n = 40L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)
  d@metadata@dataset_metadata <- full_keys

  expect_identical(
    names(extract_dataset_metadata(d, field_period, survey_name, vendor)),
    c("field_period", "survey_name", "vendor")
  )
})

test_that("extract_dataset_metadata() preserves request order on a frame", {
  df <- make_dataset_df()

  expect_identical(
    names(extract_dataset_metadata(df, field_period, survey_name, vendor)),
    c("field_period", "survey_name", "vendor")
  )
})

test_that("extract_dataset_metadata() dedups a repeated request, first pos", {
  df <- make_survey_data(n = 40L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)
  d@metadata@dataset_metadata <- full_keys

  expect_identical(
    names(extract_dataset_metadata(d, vendor, survey_name, vendor)),
    c("vendor", "survey_name")
  )
})

test_that("extract_dataset_metadata() dedups a repeated request on a frame", {
  df <- make_dataset_df()

  expect_identical(
    names(extract_dataset_metadata(df, vendor, survey_name, vendor)),
    c("vendor", "survey_name")
  )
})

test_that("extract_dataset_metadata() reads keys from the `key` argument", {
  df <- make_survey_data(n = 40L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)
  d@metadata@dataset_metadata <- full_keys

  expect_identical(
    extract_dataset_metadata(d, key = c("vendor", "field_start")),
    list(vendor = full_keys$vendor, field_start = full_keys$field_start)
  )
})

test_that("extract_dataset_metadata() reads the `key` argument on a frame", {
  df <- make_dataset_df()

  expect_identical(
    extract_dataset_metadata(df, key = c("vendor", "field_start")),
    list(vendor = full_keys$vendor, field_start = full_keys$field_start)
  )
})

test_that("extract_dataset_metadata() omits an unset requested key by default", {
  df <- make_survey_data(n = 40L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)
  d@metadata@dataset_metadata <- list(vendor = "Ipsos")

  expect_identical(
    extract_dataset_metadata(d, vendor, survey_name),
    list(vendor = "Ipsos")
  )
})

test_that("extract_dataset_metadata() omits an unset key on a frame", {
  df <- make_dataset_df(keys = list(vendor = "Ipsos"))

  expect_identical(
    extract_dataset_metadata(df, vendor, survey_name),
    list(vendor = "Ipsos")
  )
})

test_that("extract_dataset_metadata() never warns about an unset valid key", {
  df <- make_survey_data(n = 40L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)

  expect_no_warning(extract_dataset_metadata(d, vendor))
})

test_that("extract_dataset_metadata() never warns about an unset key on a frame", {
  df <- make_dataset_df(keys = list(vendor = "Ipsos"))

  expect_no_warning(extract_dataset_metadata(df, survey_name))
})

test_that("extract_dataset_metadata() returns list() for a zero-length key", {
  df <- make_survey_data(n = 40L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)
  d@metadata@dataset_metadata <- full_keys

  expect_identical(
    extract_dataset_metadata(d, key = character(0)),
    list()
  )
})

# ── 3. Fill semantics ─────────────────────────────────────────────────────────

test_that("extract_var_label() still rejects fill = NA (sibling regression)", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)

  expect_error(
    extract_var_label(d, fill = NA),
    class = "surveycore_error_fill_invalid"
  )
  expect_snapshot(error = TRUE, extract_var_label(d, fill = NA))
})

test_that("extract_dataset_metadata() type-matches fill = NA on a design", {
  df <- make_survey_data(n = 40L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)
  d@metadata@dataset_metadata <- list(vendor = "Ipsos")

  expect_identical(
    extract_dataset_metadata(d, vendor, survey_name, field_start, fill = NA),
    list(
      vendor = "Ipsos",
      survey_name = NA_character_,
      field_start = as.Date(NA)
    )
  )
})

test_that("extract_dataset_metadata() type-matches fill = NA on a frame", {
  df <- make_dataset_df(keys = list(vendor = "Ipsos"))

  expect_identical(
    extract_dataset_metadata(df, vendor, survey_name, field_start, fill = NA),
    list(
      vendor = "Ipsos",
      survey_name = NA_character_,
      field_start = as.Date(NA)
    )
  )
})

test_that("extract_dataset_metadata() accepts fill = NA_character_", {
  df <- make_survey_data(n = 40L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)

  expect_identical(
    extract_dataset_metadata(d, survey_name, fill = NA_character_),
    list(survey_name = NA_character_)
  )
})

test_that("extract_dataset_metadata() accepts fill = NA_character_ on a frame", {
  df <- make_dataset_df(keys = list())

  expect_identical(
    extract_dataset_metadata(df, survey_name, fill = NA_character_),
    list(survey_name = NA_character_)
  )
})

test_that("an empty request with fill = NA returns the full six-key schema", {
  df <- make_survey_data(n = 40L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)
  d@metadata@dataset_metadata <- list(vendor = "Ipsos")

  expect_identical(
    extract_dataset_metadata(d, fill = NA),
    list(
      survey_name = NA_character_,
      data_name = NA_character_,
      vendor = "Ipsos",
      field_start = as.Date(NA),
      field_end = as.Date(NA),
      field_period = NA_character_
    )
  )
})

test_that("an empty request with fill = NA returns the schema on a frame", {
  df <- make_dataset_df(keys = list(vendor = "Ipsos"))

  expect_identical(
    names(extract_dataset_metadata(df, fill = NA)),
    names(full_keys)
  )
})

test_that("an empty request with no metadata and fill = NA fills all six", {
  df <- make_survey_data(n = 40L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)

  result <- extract_dataset_metadata(d, fill = NA)

  expect_identical(names(result), names(full_keys))
  expect_true(all(vapply(result, function(v) is.na(v), logical(1L))))
})

# ── 4. data_frame format ──────────────────────────────────────────────────────

test_that("extract_dataset_metadata() renders a two-column tibble", {
  df <- make_survey_data(n = 40L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)
  d@metadata@dataset_metadata <- full_keys

  result <- extract_dataset_metadata(d, format = "data_frame")

  expect_s3_class(result, "tbl_df")
  expect_identical(names(result), c("key", "value"))
  expect_identical(result$key, names(full_keys))
  expect_true(is.character(result$value))
})

test_that("extract_dataset_metadata() renders a tibble from a frame", {
  df <- make_dataset_df()

  result <- extract_dataset_metadata(df, format = "data_frame")

  expect_identical(names(result), c("key", "value"))
  expect_identical(result$key, names(full_keys))
})

test_that("data_frame format renders a Date through format()", {
  df <- make_dataset_df()

  result <- extract_dataset_metadata(df, field_start, format = "data_frame")

  expect_identical(result$value, "2026-02-10")
})

test_that("data_frame format renders a design Date through format()", {
  df <- make_survey_data(n = 40L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)
  d@metadata@dataset_metadata <- list(
    field_start = as.Date("2026-02-10"),
    field_end = as.Date("2026-03-04")
  )

  result <- extract_dataset_metadata(
    d,
    field_start,
    field_end,
    format = "data_frame"
  )

  expect_identical(result$key, c("field_start", "field_end"))
  expect_identical(result$value, c("2026-02-10", "2026-03-04"))
})

test_that("data_frame format returns a 0-row tibble for an empty result", {
  df <- make_survey_data(n = 40L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)

  result <- extract_dataset_metadata(d, format = "data_frame")

  expect_identical(nrow(result), 0L)
  expect_identical(names(result), c("key", "value"))
  expect_true(is.character(result$key))
  expect_true(is.character(result$value))
})

test_that("data_frame format returns a 0-row tibble for a bare frame", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)

  result <- extract_dataset_metadata(df, format = "data_frame")

  expect_identical(nrow(result), 0L)
  expect_identical(names(result), c("key", "value"))
})

test_that("data_frame format fills an absent date key with NA_character_", {
  df <- make_survey_data(n = 40L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)

  result <- extract_dataset_metadata(
    d,
    field_start,
    survey_name,
    format = "data_frame",
    fill = NA
  )

  expect_identical(result$key, c("field_start", "survey_name"))
  expect_identical(result$value, c(NA_character_, NA_character_))
})

test_that("data_frame format fills an absent key with NA_character_ on a frame", {
  df <- make_dataset_df(keys = list())

  result <- extract_dataset_metadata(
    df,
    field_start,
    format = "data_frame",
    fill = NA
  )

  expect_identical(result$value, NA_character_)
})

test_that("data_frame format dedups a repeated request", {
  df <- make_dataset_df()

  result <- extract_dataset_metadata(
    df,
    vendor,
    vendor,
    format = "data_frame"
  )

  expect_identical(result$key, "vendor")
})

# ── 5. Data-frame mode read path ──────────────────────────────────────────────

test_that("the frame reader ignores attributes outside the seven names", {
  df <- make_dataset_df(keys = list(vendor = "Ipsos"))
  attr(df, "mode") <- "web"
  attr(df, "anything_else") <- 1:3

  expect_identical(extract_dataset_metadata(df), list(vendor = "Ipsos"))
})

test_that("the frame reader does not partial-match an attribute name", {
  # Every §V.2 read is attr(..., exact = TRUE). Base R partial matching runs
  # both ways round, so both directions are pinned here:
  #   - a TRUNCATED name ("vend") is not a recognized key, so it is ignored;
  #   - a name that EXTENDS a canonical one ("vendor_extra") is what a read
  #     without exact = TRUE would wrongly resolve to, so it must be ignored
  #     as well.
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)
  attr(df, "vend") <- "Ipsos"
  attr(df, "field_st") <- "2026-02-10"
  attr(df, "vendor_extra") <- "Gallup"
  attr(df, "field_start_raw") <- "2026-02-11"

  expect_identical(extract_dataset_metadata(df), list())
  expect_identical(extract_dataset_metadata(df, vendor, field_start), list())
})

test_that("the frame reader never consults a same-named data column", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)
  df$vendor <- rep("column value", nrow(df))

  expect_identical(extract_dataset_metadata(df), list())
})

test_that("the frame reader reads attributes off a 0-row data frame", {
  df <- data.frame(y1 = numeric(0))
  attr(df, "vendor") <- "Ipsos"

  expect_identical(extract_dataset_metadata(df), list(vendor = "Ipsos"))
})

test_that("the frame reader coerces a strict-ISO date string to Date", {
  df <- make_dataset_df(keys = list(field_start = "2026-02-10"))

  expect_identical(
    extract_dataset_metadata(df, field_start),
    list(field_start = as.Date("2026-02-10"))
  )
})

test_that("the frame reader drops a wrong-typed value silently", {
  df <- make_dataset_df(keys = list(vendor = 1L, survey_name = "AAA 2026"))

  expect_no_warning(result <- extract_dataset_metadata(df))
  expect_identical(result, list(survey_name = "AAA 2026"))
})

test_that("the frame reader drops a zero-length value silently", {
  df <- make_dataset_df(
    keys = list(vendor = character(0), survey_name = "AAA 2026")
  )

  expect_no_warning(result <- extract_dataset_metadata(df))
  expect_identical(result, list(survey_name = "AAA 2026"))
})

test_that("the frame reader drops a length-2 value silently", {
  df <- make_dataset_df(keys = list(vendor = c("Ipsos", "Cint")))

  expect_no_warning(result <- extract_dataset_metadata(df))
  expect_identical(result, list())
})

test_that("the frame reader drops an NA value silently", {
  df <- make_dataset_df(keys = list(vendor = NA_character_))

  expect_no_warning(result <- extract_dataset_metadata(df))
  expect_identical(result, list())
})

test_that("the frame reader drops a non-strict-ISO date string silently", {
  df <- make_dataset_df(keys = list(field_start = "2026/02/10"))

  expect_no_warning(result <- extract_dataset_metadata(df))
  expect_identical(result, list())
})

test_that("the frame reader drops a date string that does not round-trip", {
  df <- make_dataset_df(keys = list(field_start = "2026-2-1"))

  expect_no_warning(result <- extract_dataset_metadata(df))
  expect_identical(result, list())
})

test_that("the frame reader drops an impossible calendar date silently", {
  df <- make_dataset_df(keys = list(field_start = "2026-02-30"))

  expect_no_warning(result <- extract_dataset_metadata(df))
  expect_identical(result, list())
})

test_that("the frame reader surfaces no base condition for a bad date", {
  df <- make_dataset_df(keys = list(field_start = "not a date at all"))

  expect_no_condition(result <- extract_dataset_metadata(df))
  expect_identical(result, list())
})

test_that("the frame reader promotes legacy `dates` to field_period", {
  df <- make_dataset_df(keys = list(dates = "February-March 2026"))

  expect_identical(
    extract_dataset_metadata(df),
    list(field_period = "February-March 2026")
  )
})

test_that("a present field_period attribute blocks the legacy `dates` alias", {
  df <- make_dataset_df(
    keys = list(field_period = "Feb 2026", dates = "March 2026")
  )

  expect_identical(
    extract_dataset_metadata(df),
    list(field_period = "Feb 2026")
  )
})

test_that("a present-but-invalid field_period is not repaired from `dates`", {
  df <- make_dataset_df(keys = list(field_period = 1L, dates = "March 2026"))

  expect_no_warning(result <- extract_dataset_metadata(df))
  expect_identical(result, list())
})

test_that("an invalid legacy `dates` value is dropped silently", {
  df <- make_dataset_df(keys = list(dates = 1L))

  expect_no_warning(result <- extract_dataset_metadata(df))
  expect_identical(result, list())
})

test_that("a zero-length legacy `dates` value is dropped silently", {
  df <- make_dataset_df(keys = list(dates = character(0)))

  expect_no_warning(result <- extract_dataset_metadata(df))
  expect_identical(result, list())
})

test_that("the frame reader drops both dates when the pair is reversed", {
  df <- make_dataset_df(
    keys = list(
      vendor = "Ipsos",
      field_start = as.Date("2026-03-04"),
      field_end = as.Date("2026-02-10")
    )
  )

  expect_no_warning(result <- extract_dataset_metadata(df))
  expect_identical(result, list(vendor = "Ipsos"))
})

test_that("the frame reader keeps an equal date pair", {
  df <- make_dataset_df(
    keys = list(
      field_start = as.Date("2026-02-10"),
      field_end = as.Date("2026-02-10")
    )
  )

  expect_identical(
    extract_dataset_metadata(df),
    list(
      field_start = as.Date("2026-02-10"),
      field_end = as.Date("2026-02-10")
    )
  )
})

test_that("the frame reader keeps one date when the other is absent", {
  df <- make_dataset_df(keys = list(field_start = as.Date("2026-02-10")))

  expect_identical(
    extract_dataset_metadata(df),
    list(field_start = as.Date("2026-02-10"))
  )
})

test_that("a reversed pair is judged after coercion, not before", {
  df <- make_dataset_df(
    keys = list(field_start = "2026-03-04", field_end = "2026-02-10")
  )

  expect_no_warning(result <- extract_dataset_metadata(df))
  expect_identical(result, list())
})

test_that("a dropped field_end leaves field_start in place", {
  df <- make_dataset_df(
    keys = list(field_start = as.Date("2026-02-10"), field_end = "bad")
  )

  expect_identical(
    extract_dataset_metadata(df),
    list(field_start = as.Date("2026-02-10"))
  )
})

# ── 6. Error paths ────────────────────────────────────────────────────────────

test_that("extract_dataset_metadata() rejects a non-survey, non-frame x", {
  expect_error(
    extract_dataset_metadata(1L),
    class = "surveycore_error_not_survey_or_df"
  )
  expect_error(
    extract_dataset_metadata("a"),
    class = "surveycore_error_not_survey_or_df"
  )
  expect_snapshot(error = TRUE, extract_dataset_metadata(1L))
})

test_that("extract_dataset_metadata() rejects a survey_collection", {
  df <- make_survey_data(n = 40L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)
  coll <- survey_collection(list(a = d, b = d))

  expect_error(
    extract_dataset_metadata(coll),
    class = "surveycore_error_not_survey_or_df"
  )
})

test_that("extract_dataset_metadata() rejects both ... and key together", {
  df <- make_survey_data(n = 40L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)

  expect_error(
    extract_dataset_metadata(d, vendor, key = "vendor"),
    class = "surveycore_error_setter_ambiguous"
  )
  expect_snapshot(
    error = TRUE,
    extract_dataset_metadata(d, vendor, key = "vendor")
  )
})

test_that("extract_dataset_metadata() rejects ... and key on a frame", {
  df <- make_dataset_df()

  expect_error(
    extract_dataset_metadata(df, vendor, key = "vendor"),
    class = "surveycore_error_setter_ambiguous"
  )
})

test_that("extract_dataset_metadata() rejects a tidyselect helper in ...", {
  df <- make_survey_data(n = 40L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)

  expect_error(
    extract_dataset_metadata(d, all_of("vendor")),
    class = "surveycore_error_dataset_key_not_name"
  )
  expect_snapshot(error = TRUE, extract_dataset_metadata(d, all_of("vendor")))
})

test_that("extract_dataset_metadata() rejects any call in ... on a frame", {
  df <- make_dataset_df()

  expect_error(
    extract_dataset_metadata(df, c("vendor", "survey_name")),
    class = "surveycore_error_dataset_key_not_name"
  )
})

test_that("extract_dataset_metadata() rejects an unknown requested key", {
  df <- make_survey_data(n = 40L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)

  expect_error(
    extract_dataset_metadata(d, mode),
    class = "surveycore_error_dataset_key_unknown"
  )
  expect_snapshot(error = TRUE, extract_dataset_metadata(d, mode))
})

test_that("extract_dataset_metadata() rejects an unknown key on a frame", {
  df <- make_dataset_df()

  expect_error(
    extract_dataset_metadata(df, key = "mode"),
    class = "surveycore_error_dataset_key_unknown"
  )
})

test_that("extract_dataset_metadata() rejects the legacy `dates` as a key", {
  df <- make_dataset_df()

  expect_error(
    extract_dataset_metadata(df, dates),
    class = "surveycore_error_dataset_key_unknown"
  )
})

test_that("extract_dataset_metadata() rejects an invalid format", {
  df <- make_survey_data(n = 40L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)

  expect_error(
    extract_dataset_metadata(d, format = "named_vector"),
    class = "surveycore_error_format_invalid"
  )
  expect_snapshot(
    error = TRUE,
    extract_dataset_metadata(d, format = "named_vector")
  )
})

test_that("extract_dataset_metadata() rejects an invalid format on a frame", {
  df <- make_dataset_df()

  expect_error(
    extract_dataset_metadata(df, format = "bogus"),
    class = "surveycore_error_format_invalid"
  )
})

test_that("extract_dataset_metadata() rejects an invalid fill", {
  df <- make_survey_data(n = 40L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)

  expect_error(
    extract_dataset_metadata(d, fill = "none"),
    class = "surveycore_error_fill_invalid"
  )
  expect_snapshot(error = TRUE, extract_dataset_metadata(d, fill = "none"))
})

test_that("extract_dataset_metadata() rejects an invalid fill on a frame", {
  df <- make_dataset_df()

  expect_error(
    extract_dataset_metadata(df, fill = 0L),
    class = "surveycore_error_fill_invalid"
  )
})

# ── 7. Stale (pre-1.2.0) objects ──────────────────────────────────────────────

test_that("extract_dataset_metadata() returns list() on a stale design", {
  for (cls in c("taylor", "replicate", "twophase", "nonprob")) {
    d <- make_stale_metadata_design(cls)
    test_invariants(d)

    expect_identical(extract_dataset_metadata(d), list())
  }
})

test_that("a stale design fills the full schema when fill = NA", {
  d <- make_stale_metadata_design("taylor")
  test_invariants(d)

  expect_identical(
    names(extract_dataset_metadata(d, fill = NA)),
    names(full_keys)
  )
})

# ── 8. Sibling setter regression guard ────────────────────────────────────────
#
# .parse_setter_input() is shared with seven per-variable setters.
# set_dataset_metadata() parameterizes its five convention messages, so these
# blocks pin the DEFAULT rendering — the `variable` / "variable-label pair" /
# "vector" wording — through one sibling setter. They were written and confirmed
# green BEFORE the parameters were added, and their snapshots must stay
# byte-identical afterwards.

test_that("set_var_label() keeps the default setter_ambiguous wording", {
  df <- make_survey_data(n = 40L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)

  expect_error(
    set_var_label(d, y1 = "A", variable = "y2"),
    class = "surveycore_error_setter_ambiguous"
  )
  expect_snapshot(error = TRUE, set_var_label(d, y1 = "A", variable = "y2"))
})

test_that("set_var_label() keeps the default setter_empty wording", {
  df <- make_survey_data(n = 40L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)

  expect_error(set_var_label(d), class = "surveycore_error_setter_empty")
  expect_snapshot(error = TRUE, set_var_label(d))
})

test_that("set_var_label() keeps the default empty_variables wording", {
  df <- make_survey_data(n = 40L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)

  expect_warning(
    set_var_label(d, variable = character(0)),
    class = "surveycore_warning_setter_empty_variables"
  )
  expect_snapshot(set_var_label(d, variable = character(0)))
})

test_that("set_var_label() keeps the default mismatched_lengths wording", {
  df <- make_survey_data(n = 40L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)

  expect_error(
    set_var_label(d, variable = c("y1", "y2"), label = "A"),
    class = "surveycore_error_setter_mismatched_lengths"
  )
  expect_snapshot(
    error = TRUE,
    set_var_label(d, variable = c("y1", "y2"), label = "A")
  )
})

test_that("set_var_label() keeps the default mixed_dots wording", {
  df <- make_survey_data(n = 40L, n_psu = 6L, n_strata = 2L)
  d <- as_survey(df, weights = wt)
  test_invariants(d)

  expect_error(
    set_var_label(d, "y1", "y2", "y3"),
    class = "surveycore_error_setter_mixed_dots"
  )
  expect_snapshot(error = TRUE, set_var_label(d, "y1", "y2", "y3"))
})

# ── 9. set_dataset_metadata() — class guard and conventions ───────────────────

test_that("set_dataset_metadata() rejects a non-survey, non-frame x", {
  expect_error(
    set_dataset_metadata(1L, vendor = "Ipsos"),
    class = "surveycore_error_not_survey_or_df"
  )
  expect_error(
    set_dataset_metadata("a", vendor = "Ipsos"),
    class = "surveycore_error_not_survey_or_df"
  )
})

test_that("set_dataset_metadata() rejects a survey_collection", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)
  coll <- survey_collection(list(a = d, b = d))

  expect_error(
    set_dataset_metadata(coll, vendor = "Ipsos"),
    class = "surveycore_error_not_survey_or_df"
  )
})

test_that("set_dataset_metadata() rejects both ... and key on a design", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  expect_error(
    set_dataset_metadata(d, vendor = "Ipsos", key = "vendor"),
    class = "surveycore_error_setter_ambiguous"
  )
  expect_snapshot(
    error = TRUE,
    set_dataset_metadata(d, vendor = "Ipsos", key = "vendor")
  )
})

test_that("set_dataset_metadata() rejects both ... and key on a frame", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)

  expect_error(
    set_dataset_metadata(df, vendor = "Ipsos", key = "vendor"),
    class = "surveycore_error_setter_ambiguous"
  )
})

test_that("set_dataset_metadata() rejects a call with no key at all", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  expect_error(
    set_dataset_metadata(d),
    class = "surveycore_error_setter_empty"
  )
  expect_snapshot(error = TRUE, set_dataset_metadata(d))
})

test_that("set_dataset_metadata() rejects an empty call on a frame", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)

  expect_error(
    set_dataset_metadata(df),
    class = "surveycore_error_setter_empty"
  )
})

test_that("set_dataset_metadata() warns and no-ops for a length-0 key", {
  d <- make_dataset_design("taylor", "full")
  test_invariants(d)

  expect_warning(
    result <- set_dataset_metadata(d, key = character(0)),
    class = "surveycore_warning_setter_empty_variables"
  )
  expect_identical(extract_dataset_metadata(result), full_keys)
  expect_snapshot(set_dataset_metadata(d, key = character(0)))
})

test_that("a length-0 key on a frame warns and leaves attributes alone", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)
  df <- set_dataset_metadata(df, vendor = "Ipsos")

  expect_warning(
    result <- set_dataset_metadata(df, key = character(0)),
    class = "surveycore_warning_setter_empty_variables"
  )
  expect_identical(extract_dataset_metadata(result), list(vendor = "Ipsos"))
})

test_that("set_dataset_metadata() rejects mismatched key and value lengths", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  expect_error(
    set_dataset_metadata(
      d,
      key = c("vendor", "data_name"),
      value = list("Ipsos")
    ),
    class = "surveycore_error_setter_mismatched_lengths"
  )
  expect_snapshot(
    error = TRUE,
    set_dataset_metadata(
      d,
      key = c("vendor", "data_name"),
      value = list("Ipsos")
    )
  )
})

test_that("mismatched key and value lengths are rejected on a frame", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)

  expect_error(
    set_dataset_metadata(
      df,
      key = c("vendor", "data_name"),
      value = list("Ipsos")
    ),
    class = "surveycore_error_setter_mismatched_lengths"
  )
})

test_that("set_dataset_metadata() rejects unnamed ... elements", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  expect_error(
    set_dataset_metadata(d, "vendor", "data_name"),
    class = "surveycore_error_setter_mixed_dots"
  )
  expect_snapshot(
    error = TRUE,
    set_dataset_metadata(d, "vendor", "data_name")
  )
})

test_that("unnamed ... elements are rejected on a frame", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)

  expect_error(
    set_dataset_metadata(df, "vendor", "data_name"),
    class = "surveycore_error_setter_mixed_dots"
  )
})

# ── 10. set_dataset_metadata() — the minimal write ────────────────────────────

test_that("Convention 1 writes one key on a design", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  d <- set_dataset_metadata(d, vendor = "Ipsos KnowledgePanel Omnibus")

  expect_identical(
    extract_dataset_metadata(d),
    list(vendor = "Ipsos KnowledgePanel Omnibus")
  )
})

test_that("Convention 1 writes one key on a frame", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)

  df <- set_dataset_metadata(df, vendor = "Ipsos KnowledgePanel Omnibus")

  expect_identical(
    extract_dataset_metadata(df),
    list(vendor = "Ipsos KnowledgePanel Omnibus")
  )
  expect_identical(
    attr(df, "vendor", exact = TRUE),
    "Ipsos KnowledgePanel Omnibus"
  )
})

test_that("Convention 1 writes several keys at once on a design", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  d <- set_dataset_metadata(d, vendor = "Ipsos", data_name = "AAA (Feb 2026)")

  expect_identical(
    extract_dataset_metadata(d),
    list(data_name = "AAA (Feb 2026)", vendor = "Ipsos")
  )
})

test_that("Convention 1 writes several keys at once on a frame", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)

  df <- set_dataset_metadata(df, vendor = "Ipsos", data_name = "AAA (Feb 2026)")

  expect_identical(
    extract_dataset_metadata(df),
    list(data_name = "AAA (Feb 2026)", vendor = "Ipsos")
  )
})

test_that("Convention 2 accepts one named list in ... on a design", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  d <- set_dataset_metadata(d, list(vendor = "Ipsos", survey_name = "AAA 2026"))

  expect_identical(
    extract_dataset_metadata(d),
    list(survey_name = "AAA 2026", vendor = "Ipsos")
  )
})

test_that("Convention 2 accepts one named list in ... on a frame", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)

  df <- set_dataset_metadata(
    df,
    list(vendor = "Ipsos", survey_name = "AAA 2026")
  )

  expect_identical(
    extract_dataset_metadata(df),
    list(survey_name = "AAA 2026", vendor = "Ipsos")
  )
})

test_that("Convention 2 accepts a spliced list on a design", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  d <- set_dataset_metadata(d, !!!list(vendor = "Ipsos"))

  expect_identical(extract_dataset_metadata(d), list(vendor = "Ipsos"))
})

test_that("Convention 3 writes key and value pairs on a design", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  d <- set_dataset_metadata(
    d,
    key = c("vendor", "survey_name"),
    value = list("Ipsos", "AAA 2026")
  )

  expect_identical(
    extract_dataset_metadata(d),
    list(survey_name = "AAA 2026", vendor = "Ipsos")
  )
})

test_that("Convention 3 writes key and value pairs on a frame", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)

  df <- set_dataset_metadata(
    df,
    key = c("vendor", "survey_name"),
    value = list("Ipsos", "AAA 2026")
  )

  expect_identical(
    extract_dataset_metadata(df),
    list(survey_name = "AAA 2026", vendor = "Ipsos")
  )
})

test_that("Convention 3 coerces an atomic value with as.list()", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  d <- set_dataset_metadata(
    d,
    key = c("vendor", "survey_name"),
    value = c("Ipsos", "AAA 2026")
  )

  expect_identical(
    extract_dataset_metadata(d),
    list(survey_name = "AAA 2026", vendor = "Ipsos")
  )
})

test_that("Convention 3 coerces an atomic value on a frame", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)

  df <- set_dataset_metadata(df, key = "vendor", value = "Ipsos")

  expect_identical(extract_dataset_metadata(df), list(vendor = "Ipsos"))
})

test_that("Convention 3 ignores names on value; key wins", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  d <- set_dataset_metadata(
    d,
    key = "vendor",
    value = list(survey_name = "Ipsos")
  )

  expect_identical(extract_dataset_metadata(d), list(vendor = "Ipsos"))
})

test_that("set_dataset_metadata() returns the design invisibly", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  # The sibling extractors return visibly; the setters must not.
  seen <- withVisible(set_dataset_metadata(d, vendor = "Ipsos"))

  expect_false(seen$visible)
  expect_identical(extract_dataset_metadata(seen$value), list(vendor = "Ipsos"))
})

test_that("set_dataset_metadata() returns the frame invisibly", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)

  seen <- withVisible(set_dataset_metadata(df, vendor = "Ipsos"))

  expect_false(seen$visible)
  expect_identical(extract_dataset_metadata(seen$value), list(vendor = "Ipsos"))
})

# ── 11. set_dataset_metadata() — structural key rules ─────────────────────────
#
# A blank or missing name in Conventions 1-2 fails earlier, inside the parser,
# as surveycore_error_setter_mixed_dots. Convention 3 is the only route that
# reaches the blank-name rule, because `key` carries the names directly.

test_that("set_dataset_metadata() rejects a blank key name on a design", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  expect_error(
    set_dataset_metadata(d, key = c("")),
    class = "surveycore_error_dataset_metadata_unnamed"
  )
  expect_snapshot(error = TRUE, set_dataset_metadata(d, key = c("")))
})

test_that("set_dataset_metadata() rejects a blank key name on a frame", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)

  expect_error(
    set_dataset_metadata(df, key = c("")),
    class = "surveycore_error_dataset_metadata_unnamed"
  )
})

test_that("set_dataset_metadata() rejects an NA key name", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  expect_error(
    set_dataset_metadata(d, key = NA_character_),
    class = "surveycore_error_dataset_metadata_unnamed"
  )
})

test_that("set_dataset_metadata() counts every blank key name", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  expect_snapshot(
    error = TRUE,
    set_dataset_metadata(d, key = c("", "vendor", ""))
  )
})

test_that("set_dataset_metadata() rejects a duplicated named ... key", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  expect_error(
    set_dataset_metadata(d, vendor = "Ipsos", vendor = "Cint"),
    class = "surveycore_error_dataset_metadata_duplicate_key"
  )
  expect_snapshot(
    error = TRUE,
    set_dataset_metadata(d, vendor = "Ipsos", vendor = "Cint")
  )
})

test_that("a duplicated named ... key is rejected on a frame", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)

  expect_error(
    set_dataset_metadata(df, vendor = "Ipsos", vendor = "Cint"),
    class = "surveycore_error_dataset_metadata_duplicate_key"
  )
})

test_that("set_dataset_metadata() rejects a duplicated Convention 3 key", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  expect_error(
    set_dataset_metadata(
      d,
      key = c("vendor", "vendor"),
      value = list("Ipsos", "Cint")
    ),
    class = "surveycore_error_dataset_metadata_duplicate_key"
  )
  expect_snapshot(
    error = TRUE,
    set_dataset_metadata(
      d,
      key = c("vendor", "vendor"),
      value = list("Ipsos", "Cint")
    )
  )
})

test_that("a duplicated Convention 3 key is rejected on a frame", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)

  expect_error(
    set_dataset_metadata(df, key = c("vendor", "vendor"), value = NULL),
    class = "surveycore_error_dataset_metadata_duplicate_key"
  )
})

test_that("a duplicated key in a Convention 2 list is rejected", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  expect_error(
    set_dataset_metadata(d, list(vendor = "Ipsos", vendor = "Cint")),
    class = "surveycore_error_dataset_metadata_duplicate_key"
  )
})

test_that("the dates alias resolves before the duplicate check", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  # `dates` and `field_period` are two spellings of one key, so naming both in
  # one call names that key twice.
  expect_error(
    set_dataset_metadata(d, dates = NULL, field_period = "Feb 2026"),
    class = "surveycore_error_dataset_metadata_duplicate_key"
  )
  expect_snapshot(
    error = TRUE,
    set_dataset_metadata(d, dates = NULL, field_period = "Feb 2026")
  )
})

test_that("the dates alias resolves before the duplicate check on a frame", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)

  expect_error(
    set_dataset_metadata(df, dates = NULL, field_period = "Feb 2026"),
    class = "surveycore_error_dataset_metadata_duplicate_key"
  )
})

# ── 12. set_dataset_metadata() — unknown keys ─────────────────────────────────

test_that("set_dataset_metadata() rejects an unknown key on a design", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  expect_error(
    set_dataset_metadata(d, mode = "web"),
    class = "surveycore_error_dataset_key_unknown"
  )
  expect_snapshot(error = TRUE, set_dataset_metadata(d, mode = "web"))
})

test_that("set_dataset_metadata() rejects an unknown key on a frame", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)

  expect_error(
    set_dataset_metadata(df, mode = "web"),
    class = "surveycore_error_dataset_key_unknown"
  )
})

test_that("an unknown key with the wrong case shows the did-you-mean hint", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  expect_error(
    set_dataset_metadata(d, Vendor = "Ipsos"),
    class = "surveycore_error_dataset_key_unknown"
  )
  expect_snapshot(error = TRUE, set_dataset_metadata(d, Vendor = "Ipsos"))
})

test_that("a misspelled unknown key shows the did-you-mean hint", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  expect_error(
    set_dataset_metadata(d, vender = "Ipsos"),
    class = "surveycore_error_dataset_key_unknown"
  )
  expect_snapshot(error = TRUE, set_dataset_metadata(d, vender = "Ipsos"))
})

test_that("the did-you-mean hint also fires on a frame", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)

  expect_snapshot(error = TRUE, set_dataset_metadata(df, vender = "Ipsos"))
})

test_that("a non-NULL dates value is an unknown key naming field_period", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  expect_error(
    set_dataset_metadata(d, dates = "February-March 2026"),
    class = "surveycore_error_dataset_key_unknown"
  )
  expect_snapshot(
    error = TRUE,
    set_dataset_metadata(d, dates = "February-March 2026")
  )
})

test_that("a non-NULL dates value is an unknown key on a frame", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)

  expect_error(
    set_dataset_metadata(df, dates = "February-March 2026"),
    class = "surveycore_error_dataset_key_unknown"
  )
})

test_that("an unknown key equal to a data column leaves the column alone", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)
  before <- df$y1

  expect_error(
    set_dataset_metadata(df, y1 = "not a key"),
    class = "surveycore_error_dataset_key_unknown"
  )
  expect_identical(df$y1, before)
  expect_null(attr(df, "y1", exact = TRUE))
})

test_that("a non-character key is coerced and then fails as unknown", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  # A non-character `key` passes through as.character() and then fails the
  # closed-vocabulary check, matching the extractor's convention.
  expect_error(
    set_dataset_metadata(d, key = 1L, value = list("Ipsos")),
    class = "surveycore_error_dataset_key_unknown"
  )
  expect_snapshot(
    error = TRUE,
    set_dataset_metadata(d, key = 1L, value = list("Ipsos"))
  )
})

test_that("a non-character key is coerced and fails as unknown on a frame", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)

  expect_error(
    set_dataset_metadata(df, key = 1L, value = list("Ipsos")),
    class = "surveycore_error_dataset_key_unknown"
  )
})

test_that("the extractor renders the completed unknown-key hint on a design", {
  d <- make_dataset_design("taylor", "full")
  test_invariants(d)

  expect_error(
    extract_dataset_metadata(d, vender),
    class = "surveycore_error_dataset_key_unknown"
  )
  expect_snapshot(error = TRUE, extract_dataset_metadata(d, vender))
})

test_that("the extractor renders the completed unknown-key hint on a frame", {
  df <- make_dataset_df()

  expect_error(
    extract_dataset_metadata(df, vender),
    class = "surveycore_error_dataset_key_unknown"
  )
  expect_snapshot(error = TRUE, extract_dataset_metadata(df, vender))
})

# ── 13. set_dataset_metadata() — per-key value rules ──────────────────────────

test_that("a non-character value for a character key is rejected", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  expect_error(
    set_dataset_metadata(d, vendor = 1L),
    class = "surveycore_error_dataset_metadata_bad_type"
  )
  expect_snapshot(error = TRUE, set_dataset_metadata(d, vendor = 1L))
})

test_that("a non-character value for a character key is rejected on a frame", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)

  expect_error(
    set_dataset_metadata(df, vendor = 1L),
    class = "surveycore_error_dataset_metadata_bad_type"
  )
})

test_that("a length-2 value for a character key is rejected", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  expect_error(
    set_dataset_metadata(d, vendor = c("Ipsos", "Cint")),
    class = "surveycore_error_dataset_metadata_bad_type"
  )
})

test_that("a length-2 value for a character key is rejected on a frame", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)

  expect_error(
    set_dataset_metadata(df, vendor = c("Ipsos", "Cint")),
    class = "surveycore_error_dataset_metadata_bad_type"
  )
})

test_that("an NA value for a character key is rejected", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  expect_error(
    set_dataset_metadata(d, vendor = NA_character_),
    class = "surveycore_error_dataset_metadata_bad_type"
  )
})

test_that("a zero-length value is rejected rather than treated as deletion", {
  d <- make_dataset_design("taylor", "full")
  test_invariants(d)

  # character(0) is not a deletion. Only NULL deletes.
  expect_error(
    set_dataset_metadata(d, vendor = character(0)),
    class = "surveycore_error_dataset_metadata_bad_type"
  )
  expect_identical(extract_dataset_metadata(d), full_keys)
})

test_that("a zero-length value is rejected on a frame", {
  df <- make_dataset_df()

  expect_error(
    set_dataset_metadata(df, vendor = character(0)),
    class = "surveycore_error_dataset_metadata_bad_type"
  )
})

test_that("a zero-length value is rejected for character keys on a design", {
  d <- make_dataset_design("taylor", "full")
  test_invariants(d)

  # character(0) is not a deletion for any of the three remaining character
  # keys either. Only NULL deletes.
  expect_error(
    set_dataset_metadata(d, survey_name = character(0)),
    class = "surveycore_error_dataset_metadata_bad_type"
  )
  expect_error(
    set_dataset_metadata(d, data_name = character(0)),
    class = "surveycore_error_dataset_metadata_bad_type"
  )
  expect_error(
    set_dataset_metadata(d, field_period = character(0)),
    class = "surveycore_error_dataset_metadata_bad_type"
  )
  # Atomic: none of the rejected calls wrote anything.
  expect_identical(extract_dataset_metadata(d), full_keys)
})

test_that("a zero-length value is rejected for character keys on a frame", {
  df <- make_dataset_df()

  expect_error(
    set_dataset_metadata(df, survey_name = character(0)),
    class = "surveycore_error_dataset_metadata_bad_type"
  )
  expect_error(
    set_dataset_metadata(df, data_name = character(0)),
    class = "surveycore_error_dataset_metadata_bad_type"
  )
  expect_error(
    set_dataset_metadata(df, field_period = character(0)),
    class = "surveycore_error_dataset_metadata_bad_type"
  )
  expect_identical(extract_dataset_metadata(df), full_keys)
})

test_that("a zero-length value is rejected for date keys on a design", {
  d <- make_dataset_design("taylor", "full")
  test_invariants(d)

  # The date keys carry their own class, so a zero-length Date is rejected as
  # an invalid field date rather than as a bad type.
  expect_error(
    set_dataset_metadata(d, field_start = as.Date(character(0))),
    class = "surveycore_error_field_date_invalid"
  )
  expect_error(
    set_dataset_metadata(d, field_end = as.Date(character(0))),
    class = "surveycore_error_field_date_invalid"
  )
  expect_identical(extract_dataset_metadata(d), full_keys)
})

test_that("a zero-length value is rejected for date keys on a frame", {
  df <- make_dataset_df()

  expect_error(
    set_dataset_metadata(df, field_start = as.Date(character(0))),
    class = "surveycore_error_field_date_invalid"
  )
  expect_error(
    set_dataset_metadata(df, field_end = as.Date(character(0))),
    class = "surveycore_error_field_date_invalid"
  )
  expect_identical(extract_dataset_metadata(df), full_keys)
})

test_that("a bare number for a date key is rejected", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  expect_error(
    set_dataset_metadata(d, field_start = 20260210),
    class = "surveycore_error_field_date_invalid"
  )
  expect_snapshot(error = TRUE, set_dataset_metadata(d, field_start = 20260210))
})

test_that("a bare number for a date key is rejected on a frame", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)

  expect_error(
    set_dataset_metadata(df, field_start = 20260210),
    class = "surveycore_error_field_date_invalid"
  )
})

test_that("an NA value for a date key is rejected with the NA bullet", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  expect_error(
    set_dataset_metadata(d, field_start = NA),
    class = "surveycore_error_field_date_invalid"
  )
  expect_snapshot(error = TRUE, set_dataset_metadata(d, field_start = NA))
})

test_that("an NA value for a date key is rejected on a frame", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)

  expect_error(
    set_dataset_metadata(df, field_start = NA),
    class = "surveycore_error_field_date_invalid"
  )
})

test_that("a Date value for a date key is stored as given on a design", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  d <- set_dataset_metadata(d, field_start = as.Date("2026-02-10"))

  expect_identical(
    extract_dataset_metadata(d),
    list(field_start = as.Date("2026-02-10"))
  )
})

test_that("an ISO string for a date key is stored as a Date on a design", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  d <- set_dataset_metadata(d, field_start = "2026-02-10")

  stored <- extract_dataset_metadata(d)
  expect_s3_class(stored$field_start, "Date")
  expect_identical(stored$field_start, as.Date("2026-02-10"))
})

test_that("an ISO string for a date key is stored as a Date on a frame", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)

  df <- set_dataset_metadata(df, field_start = "2026-02-10")

  expect_identical(attr(df, "field_start", exact = TRUE), as.Date("2026-02-10"))
  expect_identical(
    extract_dataset_metadata(df),
    list(field_start = as.Date("2026-02-10"))
  )
})

test_that("a non-strict slash date is rejected on a design", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  expect_error(
    set_dataset_metadata(d, field_start = "2026/02/10"),
    class = "surveycore_error_field_date_invalid"
  )
})

test_that("a non-strict slash date is rejected on a frame", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)

  expect_error(
    set_dataset_metadata(df, field_start = "2026/02/10"),
    class = "surveycore_error_field_date_invalid"
  )
})

test_that("an unpadded date string fails the round trip on a design", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  # as.Date() parses "2026-2-1", but it does not round-trip through format(),
  # so the strict ISO rule rejects it.
  expect_error(
    set_dataset_metadata(d, field_start = "2026-2-1"),
    class = "surveycore_error_field_date_invalid"
  )
})

test_that("an unpadded date string fails the round trip on a frame", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)

  expect_error(
    set_dataset_metadata(df, field_start = "2026-2-1"),
    class = "surveycore_error_field_date_invalid"
  )
})

test_that("an impossible calendar date is rejected on a design", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  expect_error(
    set_dataset_metadata(d, field_start = "2026-02-30"),
    class = "surveycore_error_field_date_invalid"
  )
})

test_that("no base as.Date() condition escapes an invalid date value", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  # The only condition raised is surveycore's own.
  expect_error(
    set_dataset_metadata(d, field_start = "not a date"),
    class = "surveycore_error_field_date_invalid"
  )
  expect_no_warning(
    try(set_dataset_metadata(d, field_start = "not a date"), silent = TRUE)
  )
})

# ── 14. set_dataset_metadata() — merge, deletion, and the date pair ───────────

test_that("a second call merges into the stored keys on a design", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  d <- set_dataset_metadata(d, vendor = "Ipsos")
  d <- set_dataset_metadata(d, survey_name = "AAA 2026")

  expect_identical(
    extract_dataset_metadata(d),
    list(survey_name = "AAA 2026", vendor = "Ipsos")
  )
})

test_that("a second call merges into the stored keys on a frame", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)

  df <- set_dataset_metadata(df, vendor = "Ipsos")
  df <- set_dataset_metadata(df, survey_name = "AAA 2026")

  expect_identical(
    extract_dataset_metadata(df),
    list(survey_name = "AAA 2026", vendor = "Ipsos")
  )
})

test_that("overwriting a key keeps its canonical position on a design", {
  d <- make_dataset_design("taylor", "full")
  test_invariants(d)

  d <- set_dataset_metadata(d, vendor = "Cint")

  expect_identical(names(extract_dataset_metadata(d)), names(full_keys))
  expect_identical(extract_dataset_metadata(d)$vendor, "Cint")
})

test_that("overwriting a key keeps its canonical position on a frame", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)
  df <- set_dataset_metadata(df, !!!full_keys)

  df <- set_dataset_metadata(df, vendor = "Cint")

  expect_identical(names(extract_dataset_metadata(df)), names(full_keys))
  expect_identical(extract_dataset_metadata(df)$vendor, "Cint")
})

test_that("keys written out of order are stored canonically on a design", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  d <- set_dataset_metadata(
    d,
    field_period = "February-March 2026",
    vendor = "Ipsos",
    survey_name = "AAA 2026"
  )

  expect_identical(
    names(extract_dataset_metadata(d)),
    c("survey_name", "vendor", "field_period")
  )
})

test_that("keys written out of order are read canonically on a frame", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)

  df <- set_dataset_metadata(
    df,
    field_period = "February-March 2026",
    vendor = "Ipsos",
    survey_name = "AAA 2026"
  )

  expect_identical(
    names(extract_dataset_metadata(df)),
    c("survey_name", "vendor", "field_period")
  )
})

test_that("a NULL value deletes a stored key on a design", {
  d <- make_dataset_design("taylor", "full")
  test_invariants(d)

  d <- set_dataset_metadata(d, vendor = NULL)

  expect_false("vendor" %in% names(extract_dataset_metadata(d)))
  expect_identical(
    names(extract_dataset_metadata(d)),
    setdiff(names(full_keys), "vendor")
  )
})

test_that("a NULL value deletes a stored key on a frame", {
  df <- make_dataset_df()

  df <- set_dataset_metadata(df, vendor = NULL)

  expect_null(attr(df, "vendor", exact = TRUE))
  expect_false("vendor" %in% names(extract_dataset_metadata(df)))
})

test_that("deleting an unset key is a silent no-op on a design", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  expect_no_condition(result <- set_dataset_metadata(d, vendor = NULL))
  expect_identical(extract_dataset_metadata(result), list())
})

test_that("deleting an unset key is a silent no-op on a frame", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)

  expect_no_condition(result <- set_dataset_metadata(df, vendor = NULL))
  expect_identical(extract_dataset_metadata(result), list())
})

test_that("one call can set one key and delete another on a design", {
  d <- make_dataset_design("taylor", "full")
  test_invariants(d)

  d <- set_dataset_metadata(d, vendor = "Cint", data_name = NULL)

  stored <- extract_dataset_metadata(d)
  expect_identical(stored$vendor, "Cint")
  expect_false("data_name" %in% names(stored))
})

test_that("one call can set one key and delete another on a frame", {
  df <- make_dataset_df()

  df <- set_dataset_metadata(df, vendor = "Cint", data_name = NULL)

  stored <- extract_dataset_metadata(df)
  expect_identical(stored$vendor, "Cint")
  expect_false("data_name" %in% names(stored))
})

test_that("bulk deletion via key and a NULL value works on a design", {
  d <- make_dataset_design("taylor", "full")
  test_invariants(d)

  d <- set_dataset_metadata(d, key = c("vendor", "data_name"), value = NULL)

  expect_identical(
    names(extract_dataset_metadata(d)),
    setdiff(names(full_keys), c("vendor", "data_name"))
  )
})

test_that("bulk deletion tolerates an absent key among the names", {
  d <- make_dataset_design("taylor", "survey_name")
  test_invariants(d)

  d <- set_dataset_metadata(d, key = c("vendor", "data_name"), value = NULL)

  expect_identical(extract_dataset_metadata(d), full_keys["survey_name"])
})

test_that("bulk deletion via key and a NULL value works on a frame", {
  df <- make_dataset_df()

  df <- set_dataset_metadata(df, key = c("vendor", "data_name"), value = NULL)

  expect_identical(
    names(extract_dataset_metadata(df)),
    setdiff(names(full_keys), c("vendor", "data_name"))
  )
})

test_that("bulk deletion mixes a present and an absent key on a design", {
  d <- make_dataset_design("taylor", "partial")
  test_invariants(d)

  # The "partial" state sets `vendor` but not `survey_name`, so this one call
  # covers both halves of the rule: the set key is deleted, and the absent key
  # is a silent no-op rather than an error.
  expect_no_condition(
    result <- set_dataset_metadata(
      d,
      key = c("survey_name", "vendor"),
      value = NULL
    )
  )

  expect_identical(
    extract_dataset_metadata(result),
    full_keys[c("data_name", "field_start", "field_period")]
  )
})

test_that("bulk deletion mixes a present and an absent key on a frame", {
  df <- make_dataset_df(
    keys = full_keys[c("data_name", "vendor", "field_start", "field_period")]
  )

  expect_no_condition(
    result <- set_dataset_metadata(
      df,
      key = c("survey_name", "vendor"),
      value = NULL
    )
  )

  expect_identical(
    extract_dataset_metadata(result),
    full_keys[c("data_name", "field_start", "field_period")]
  )
})

test_that("a NULL element inside a value list deletes that key", {
  d <- make_dataset_design("taylor", "full")
  test_invariants(d)

  d <- set_dataset_metadata(
    d,
    key = c("vendor", "data_name"),
    value = list("Cint", NULL)
  )

  stored <- extract_dataset_metadata(d)
  expect_identical(stored$vendor, "Cint")
  expect_false("data_name" %in% names(stored))
})

test_that("a NULL element inside a value list deletes that key on a frame", {
  df <- make_dataset_df()

  df <- set_dataset_metadata(
    df,
    key = c("vendor", "data_name"),
    value = list("Cint", NULL)
  )

  stored <- extract_dataset_metadata(df)
  expect_identical(stored$vendor, "Cint")
  expect_false("data_name" %in% names(stored))
})

test_that("a reversed date pair in one call is rejected on a design", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  expect_error(
    set_dataset_metadata(
      d,
      field_start = "2026-03-04",
      field_end = "2026-02-10"
    ),
    class = "surveycore_error_field_dates_reversed"
  )
  expect_snapshot(
    error = TRUE,
    set_dataset_metadata(
      d,
      field_start = "2026-03-04",
      field_end = "2026-02-10"
    )
  )
})

test_that("a reversed date pair in one call is rejected on a frame", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)

  expect_error(
    set_dataset_metadata(
      df,
      field_start = "2026-03-04",
      field_end = "2026-02-10"
    ),
    class = "surveycore_error_field_dates_reversed"
  )
})

test_that("a new start after the stored end is rejected on a design", {
  d <- make_dataset_design("taylor", "full")
  test_invariants(d)

  expect_error(
    set_dataset_metadata(d, field_start = "2026-06-01"),
    class = "surveycore_error_field_dates_reversed"
  )
  # Atomic: the rejected call wrote nothing.
  expect_identical(extract_dataset_metadata(d), full_keys)
})

test_that("a new start after the stored end is rejected on a frame", {
  df <- make_dataset_df()

  expect_error(
    set_dataset_metadata(df, field_start = "2026-06-01"),
    class = "surveycore_error_field_dates_reversed"
  )
  expect_identical(extract_dataset_metadata(df), full_keys)
})

test_that("deleting the end date frees a later start on a design", {
  d <- make_dataset_design("taylor", "full")
  test_invariants(d)

  # The deleted date is absent from the effective pair, so no comparison runs.
  d <- set_dataset_metadata(
    d,
    field_end = NULL,
    field_start = as.Date("2026-06-01")
  )

  stored <- extract_dataset_metadata(d)
  expect_identical(stored$field_start, as.Date("2026-06-01"))
  expect_false("field_end" %in% names(stored))
})

test_that("deleting the end date frees a later start on a frame", {
  df <- make_dataset_df()

  df <- set_dataset_metadata(
    df,
    field_end = NULL,
    field_start = as.Date("2026-06-01")
  )

  stored <- extract_dataset_metadata(df)
  expect_identical(stored$field_start, as.Date("2026-06-01"))
  expect_false("field_end" %in% names(stored))
})

test_that("deleting the start date frees an earlier end on a design", {
  d <- make_dataset_design("taylor", "full")
  test_invariants(d)

  # The mirror of the delete-end case. The stored start is 2026-02-10, so
  # 2026-01-05 would reverse the pair; the deletion removes the start from the
  # effective pair, so no comparison runs.
  d <- set_dataset_metadata(
    d,
    field_start = NULL,
    field_end = as.Date("2026-01-05")
  )

  stored <- extract_dataset_metadata(d)
  expect_identical(stored$field_end, as.Date("2026-01-05"))
  expect_false("field_start" %in% names(stored))
})

test_that("deleting the start date frees an earlier end on a frame", {
  df <- make_dataset_df()

  df <- set_dataset_metadata(
    df,
    field_start = NULL,
    field_end = as.Date("2026-01-05")
  )

  stored <- extract_dataset_metadata(df)
  expect_identical(stored$field_end, as.Date("2026-01-05"))
  expect_false("field_start" %in% names(stored))
})

test_that("deleting both dates always succeeds on a design", {
  d <- make_dataset_design("taylor", "full")
  test_invariants(d)

  d <- set_dataset_metadata(d, field_start = NULL, field_end = NULL)

  stored <- extract_dataset_metadata(d)
  expect_false(any(c("field_start", "field_end") %in% names(stored)))
})

test_that("an equal start and end pair is accepted on a design", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  d <- set_dataset_metadata(
    d,
    field_start = "2026-02-10",
    field_end = "2026-02-10"
  )

  expect_identical(
    extract_dataset_metadata(d),
    list(
      field_start = as.Date("2026-02-10"),
      field_end = as.Date("2026-02-10")
    )
  )
})

test_that("one date alone never triggers the pair check on a design", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  d <- set_dataset_metadata(d, field_end = "2026-02-10")

  expect_identical(
    extract_dataset_metadata(d),
    list(field_end = as.Date("2026-02-10"))
  )
})

test_that("a rejected value in a multi-key call writes nothing on a design", {
  d <- make_dataset_design("taylor", "survey_name")
  test_invariants(d)

  expect_error(
    set_dataset_metadata(d, vendor = "Ipsos", data_name = 1L),
    class = "surveycore_error_dataset_metadata_bad_type"
  )
  expect_identical(extract_dataset_metadata(d), full_keys["survey_name"])
})

test_that("a rejected value in a multi-key call writes nothing on a frame", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)
  df <- set_dataset_metadata(df, survey_name = full_keys$survey_name)

  expect_error(
    set_dataset_metadata(df, vendor = "Ipsos", data_name = 1L),
    class = "surveycore_error_dataset_metadata_bad_type"
  )
  expect_identical(extract_dataset_metadata(df), full_keys["survey_name"])
  expect_null(attr(df, "vendor", exact = TRUE))
})

test_that("a rejected unknown key in a multi-key call writes nothing", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)

  expect_error(
    set_dataset_metadata(df, vendor = "Ipsos", mode = "web"),
    class = "surveycore_error_dataset_key_unknown"
  )
  expect_identical(extract_dataset_metadata(df), list())
  expect_null(attr(df, "vendor", exact = TRUE))
})

# ── 15. set_dataset_metadata() — survey write-path guarantees ─────────────────

test_that("the write leaves the other metadata properties alone", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)
  d <- set_var_label(d, y1 = "Outcome one")
  d <- set_val_labels(d, y3 = c(No = 0L, Yes = 1L))
  before_labels <- d@metadata@variable_labels
  before_vals <- d@metadata@value_labels
  before_hist <- d@metadata@weighting_history

  d <- set_dataset_metadata(d, !!!full_keys)

  expect_identical(d@metadata@variable_labels, before_labels)
  expect_identical(d@metadata@value_labels, before_vals)
  expect_identical(d@metadata@weighting_history, before_hist)
})

test_that("the write leaves @data and @variables alone", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)
  before_data <- d@data
  before_vars <- d@variables

  d <- set_dataset_metadata(d, !!!full_keys)

  expect_identical(d@data, before_data)
  expect_identical(d@variables, before_vars)
})

test_that("the write never touches whole-frame attributes on @data", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  d <- set_dataset_metadata(d, vendor = "Ipsos")

  # The stored property is the single source of truth on a survey object.
  expect_null(attr(d@data, "vendor", exact = TRUE))
  expect_identical(extract_dataset_metadata(d), list(vendor = "Ipsos"))
})

test_that("all six keys round-trip on a taylor design", {
  d <- make_dataset_design("taylor", "none")
  test_invariants(d)

  d <- set_dataset_metadata(d, !!!full_keys)

  expect_identical(extract_dataset_metadata(d), full_keys)
})

test_that("all six keys round-trip on a replicate design", {
  d <- make_dataset_design("replicate", "none")
  test_invariants(d)

  d <- set_dataset_metadata(d, !!!full_keys)

  expect_identical(extract_dataset_metadata(d), full_keys)
})

test_that("all six keys round-trip on a twophase design", {
  d <- make_dataset_design("twophase", "none")
  test_invariants(d)

  d <- set_dataset_metadata(d, !!!full_keys)

  expect_identical(extract_dataset_metadata(d), full_keys)
})

test_that("all six keys round-trip on a nonprob design", {
  d <- make_dataset_design("nonprob", "none")
  test_invariants(d)

  d <- set_dataset_metadata(d, !!!full_keys)

  expect_identical(extract_dataset_metadata(d), full_keys)
})

test_that("all six keys round-trip on a nonprob design with repweights", {
  d <- make_dataset_design("nonprob_rep", "none")
  test_invariants(d)

  d <- set_dataset_metadata(d, !!!full_keys)

  expect_identical(extract_dataset_metadata(d), full_keys)
})

test_that("make_dataset_design() applies each state through the setter", {
  d_none <- make_dataset_design("taylor", "none")
  test_invariants(d_none)
  d_full <- make_dataset_design("taylor", "full")
  d_name <- make_dataset_design("taylor", "survey_name")
  d_data <- make_dataset_design("taylor", "data_name")
  d_part <- make_dataset_design("taylor", "partial")

  expect_identical(extract_dataset_metadata(d_none), list())
  expect_identical(extract_dataset_metadata(d_full), full_keys)
  expect_identical(
    extract_dataset_metadata(d_name),
    full_keys["survey_name"]
  )
  # The two single-key states are independent: neither sets the other's key.
  expect_identical(
    extract_dataset_metadata(d_data),
    full_keys["data_name"]
  )
  expect_identical(
    names(extract_dataset_metadata(d_part)),
    c("data_name", "vendor", "field_start", "field_period")
  )
})

test_that("make_dataset_design() applies a state on a nonprob_rep design", {
  d <- make_dataset_design("nonprob_rep", "data_name")
  test_invariants(d)

  expect_identical(extract_dataset_metadata(d), full_keys["data_name"])
})

# ── 16. set_dataset_metadata() — data-frame write-path guarantees ─────────────

test_that("deleting field_period also removes the legacy dates attribute", {
  df <- make_dataset_df(keys = list(dates = "February-March 2026"))

  df <- set_dataset_metadata(df, field_period = NULL)

  expect_null(attr(df, "field_period", exact = TRUE))
  expect_null(attr(df, "dates", exact = TRUE))
  expect_identical(extract_dataset_metadata(df), list())
})

test_that("deleting field_period is idempotent", {
  df <- make_dataset_df(
    keys = list(field_period = "Feb 2026", dates = "February-March 2026")
  )

  df <- set_dataset_metadata(df, field_period = NULL)
  df <- set_dataset_metadata(df, field_period = NULL)

  expect_null(attr(df, "field_period", exact = TRUE))
  expect_null(attr(df, "dates", exact = TRUE))
  expect_identical(extract_dataset_metadata(df), list())
})

test_that("dates = NULL is an alias that removes both spellings", {
  df <- make_dataset_df(
    keys = list(field_period = "Feb 2026", dates = "February-March 2026")
  )

  df <- set_dataset_metadata(df, dates = NULL)

  expect_null(attr(df, "field_period", exact = TRUE))
  expect_null(attr(df, "dates", exact = TRUE))
  expect_identical(extract_dataset_metadata(df), list())
})

test_that("dates = NULL on a design deletes field_period", {
  d <- make_dataset_design("taylor", "full")
  test_invariants(d)

  d <- set_dataset_metadata(d, dates = NULL)

  expect_false("field_period" %in% names(extract_dataset_metadata(d)))
})

test_that("setting field_period leaves an existing dates attribute alone", {
  df <- make_dataset_df(keys = list(dates = "February-March 2026"))

  df <- set_dataset_metadata(df, field_period = "Feb-Mar 2026")

  # Only a deletion cleans up the legacy name; a write does not.
  expect_identical(attr(df, "dates", exact = TRUE), "February-March 2026")
  expect_identical(
    extract_dataset_metadata(df),
    list(field_period = "Feb-Mar 2026")
  )
})

test_that("the write leaves per-column attributes alone", {
  df <- make_survey_data(
    n = 20L,
    n_psu = 6L,
    n_strata = 2L,
    with_labels = TRUE
  )
  before <- lapply(df, attributes)

  df <- set_dataset_metadata(df, !!!full_keys)

  expect_identical(lapply(df, attributes), before)
})

test_that("the write leaves names, row.names, and class alone", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)
  before_names <- names(df)
  before_rows <- .row_names_info(df, type = 0L)
  before_class <- class(df)

  df <- set_dataset_metadata(df, !!!full_keys)

  expect_identical(names(df), before_names)
  expect_identical(.row_names_info(df, type = 0L), before_rows)
  expect_identical(class(df), before_class)
})

test_that("the write leaves the column values alone", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)
  # lapply() over the columns, not as.list(), because as.list() on a data frame
  # carries the whole-frame attributes this setter is expected to change.
  before <- lapply(names(df), function(nm) df[[nm]])

  df <- set_dataset_metadata(df, !!!full_keys)

  expect_identical(lapply(names(df), function(nm) df[[nm]]), before)
})

test_that("a valid key equal to a column name writes only the attribute", {
  df <- make_survey_data(n = 20L, n_psu = 6L, n_strata = 2L)
  df$vendor <- rep("column value", nrow(df))
  before <- df$vendor

  df <- set_dataset_metadata(df, vendor = "Ipsos")

  # The attribute namespace and the column namespace are distinct.
  expect_identical(df$vendor, before)
  expect_identical(attr(df, "vendor", exact = TRUE), "Ipsos")
  expect_identical(extract_dataset_metadata(df), list(vendor = "Ipsos"))
})

test_that("a 0-row data frame accepts dataset metadata", {
  df <- data.frame(
    y = numeric(0L),
    w = numeric(0L),
    stringsAsFactors = FALSE
  )

  df <- set_dataset_metadata(df, !!!full_keys)

  expect_identical(nrow(df), 0L)
  expect_identical(extract_dataset_metadata(df), full_keys)
})

test_that("a single-row data frame accepts dataset metadata", {
  df <- data.frame(y = 1, w = 1, stringsAsFactors = FALSE)

  df <- set_dataset_metadata(df, vendor = "Ipsos")

  expect_identical(extract_dataset_metadata(df), list(vendor = "Ipsos"))
})

test_that("a tibble keeps its class through the write", {
  df <- tibble::tibble(y = 1:3, w = c(1, 1, 1))

  df <- set_dataset_metadata(df, vendor = "Ipsos")

  expect_s3_class(df, "tbl_df")
  expect_identical(extract_dataset_metadata(df), list(vendor = "Ipsos"))
})

# ── 17. set_dataset_metadata() — stale (pre-1.2.0) objects ────────────────────

test_that("a write on a stale design raises the unavailable error", {
  d <- make_stale_metadata_design("taylor")
  test_invariants(d)

  expect_error(
    set_dataset_metadata(d, vendor = "Ipsos"),
    class = "surveycore_error_dataset_metadata_unavailable"
  )
  expect_snapshot(error = TRUE, set_dataset_metadata(d, vendor = "Ipsos"))
})

test_that("a write on a stale design of any class raises the same error", {
  for (cls in c("taylor", "replicate", "twophase", "nonprob")) {
    d <- make_stale_metadata_design(cls)
    test_invariants(d)

    expect_error(
      set_dataset_metadata(d, vendor = "Ipsos"),
      class = "surveycore_error_dataset_metadata_unavailable"
    )
  }
})

test_that("the stale guard runs ahead of the convention rules", {
  d <- make_stale_metadata_design("taylor")
  test_invariants(d)

  # An empty call and an ambiguous call both report the stale object, because
  # the property guard runs before any input parsing.
  expect_error(
    set_dataset_metadata(d),
    class = "surveycore_error_dataset_metadata_unavailable"
  )
  expect_error(
    set_dataset_metadata(d, vendor = "Ipsos", key = "vendor"),
    class = "surveycore_error_dataset_metadata_unavailable"
  )
})

test_that("the stale guard runs ahead of the unknown-key rule", {
  d <- make_stale_metadata_design("taylor")
  test_invariants(d)

  expect_error(
    set_dataset_metadata(d, mode = "web"),
    class = "surveycore_error_dataset_metadata_unavailable"
  )
})

test_that("the stale guard runs after the x class check", {
  # A wrong class is reported as a wrong class, not as a stale object.
  expect_error(
    set_dataset_metadata(1L, vendor = "Ipsos"),
    class = "surveycore_error_not_survey_or_df"
  )
})

test_that("a deletion on a stale design raises the unavailable error", {
  d <- make_stale_metadata_design("taylor")
  test_invariants(d)

  expect_error(
    set_dataset_metadata(d, vendor = NULL),
    class = "surveycore_error_dataset_metadata_unavailable"
  )
})
