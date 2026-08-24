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
