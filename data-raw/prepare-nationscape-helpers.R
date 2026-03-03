## Nationscape data preparation — shared helpers
##
## Sourced by prepare-nationscape-phase{1,2,3}.R.
## Do not run this file directly.

## ---- Strip haven class, preserve label/labels/question_preface ----

as_plain <- function(df) {
  df[] <- lapply(df, function(x) {
    if (!inherits(x, "haven_labelled")) return(x)
    raw <- as.vector(x)
    for (attr_nm in c("label", "labels", "question_preface")) {
      a <- attr(x, attr_nm, exact = TRUE)
      if (!is.null(a)) attr(raw, attr_nm) <- a
    }
    raw
  })
  df
}

## ---- Sentence case conversion, preserving acronyms ----
##
## Uses str_to_sentence() then restores ALL-CAPS sequences (CNN, NPR, etc.).
## Proper nouns (candidate names, party names) should be set explicitly in
## each phase's battery tables rather than relying on this function.

to_sentence_case <- function(x) {
  if (is.null(x) || !nzchar(x)) return(x)
  result <- stringr::str_to_sentence(x)
  caps <- regmatches(x, gregexpr("\\b[A-Z]{2,}\\b", x))[[1]]
  for (cap in caps) {
    result <- gsub(
      paste0("\\b", stringr::str_to_sentence(cap), "\\b"),
      cap,
      result,
      ignore.case = TRUE
    )
  }
  result
}

## ---- Proper noun whitelist for value labels ----
##
## Labels in this vector are returned unchanged by fix_value_label_names().
## Candidate names, party names, geographic entities, and institution names.

PROPER_NOUN_LABELS <- c(
  ## Candidates / political figures
  "Joe Biden", "Bernie Sanders", "Elizabeth Warren", "Kamala Harris",
  "Pete Buttigieg", "Cory Booker", "Julian Castro", "Tulsi Gabbard",
  "Kirsten Gillibrand", "Beto O'Rourke", "Mike Pence", "Donald Trump",
  "Barack Obama", "Alexandria Ocasio Cortez", "Hillary Clinton",
  "Gary Johnson", "Jill Stein", "Amy Klobuchar", "Stacey Abrams",
  "Michael Bloomberg",
  ## Judicial figures
  "John Roberts", "Sandra Day O'Connor", "William Rehnquist",
  "Paul Ryan", "Elena Kagan",
  ## Party / ideology labels
  "Democrat", "Republican", "Democrats", "Republicans",
  "Strong Democrat", "Weak Democrat", "Lean Democrat",
  "Lean Republican", "Weak Republican", "Strong Republican",
  "The Democratic Primary/Caucus", "The Republican Primary/Caucus",
  "The Democratic candidate", "The Republican candidate",
  ## Geographic / group
  "The United States", "Puerto Rican",
  "Black, or African American",
  "American Indian or Alaska Native",
  "Pacific Islander (Native Hawaiian)", "Pacific Islander (Guamanian)",
  "Pacific Islander (Samoan)", "Pacific Islander (Other)",
  "Asian (Asian Indian)", "Asian (Chinese)", "Asian (Filipino)",
  "Asian (Japanese)", "Asian (Korean)", "Asian (Vietnamese)",
  "Asian (Other)",
  ## Education labels (contain proper abbreviations)
  "Middle School - Grades 4 - 8", "Associate Degree",
  "College Degree (such as B.A., B.S.)"
)

## ---- Fix sentence case on value label names ----
##
## Applies to_sentence_case() to value label names, with protection for
## labels in PROPER_NOUN_LABELS (returned unchanged).

fix_value_label_names <- function(lbl_vec) {
  if (is.null(lbl_vec) || is.null(names(lbl_vec))) return(lbl_vec)
  new_names <- vapply(names(lbl_vec), function(nm) {
    if (nm %in% PROPER_NOUN_LABELS) nm else to_sentence_case(nm)
  }, character(1L))
  names(lbl_vec) <- new_names
  lbl_vec
}

## ---- Apply battery prefaces and item labels to a data frame ----
##
## `batteries` is a list of entries, each with:
##   preface: character scalar — the shared question preface
##   vars:    named character vector — var_name → item label

apply_batteries <- function(df, batteries) {
  for (bat in batteries) {
    for (var_nm in names(bat$vars)) {
      if (!var_nm %in% names(df)) next
      attr(df[[var_nm]], "label")            <- bat$vars[[var_nm]]
      attr(df[[var_nm]], "question_preface") <- bat$preface
    }
  }
  df
}

## ---- Process one wave data frame ----
##
## `batteries` is a phase-specific list of battery definitions.

process_wave <- function(df, wave_id, batteries) {
  ## 1. Strip haven class, preserve label/labels attributes
  df <- as_plain(df)

  ## 2. Apply sentence case to variable labels
  for (nm in names(df)) {
    lbl <- attr(df[[nm]], "label", exact = TRUE)
    if (!is.null(lbl) && is.character(lbl)) {
      attr(df[[nm]], "label") <- to_sentence_case(lbl)
    }
  }

  ## 3. Fix sentence case on value label names
  for (nm in names(df)) {
    lbls <- attr(df[[nm]], "labels", exact = TRUE)
    if (!is.null(lbls)) {
      attr(df[[nm]], "labels") <- fix_value_label_names(lbls)
    }
  }

  ## 4. Apply battery prefaces and item labels
  df <- apply_batteries(df, batteries)

  ## 5. Run infer_question_prefaces() to catch any remaining battery patterns
  df <- infer_question_prefaces(df, verbose = FALSE)

  ## 6. Add wave identifier
  df$wave_id <- wave_id

  df
}

## ---- Load and process all waves in a phase directory ----

load_phase_waves <- function(phase_dir, batteries, phase_label) {
  wave_dirs <- sort(list.dirs(phase_dir, full.names = TRUE, recursive = FALSE))
  wave_dirs <- wave_dirs[grepl("^ns[0-9]", basename(wave_dirs))]

  result <- vector("list", length(wave_dirs))
  names(result) <- basename(wave_dirs)

  for (i in seq_along(wave_dirs)) {
    wave_id  <- basename(wave_dirs[[i]])
    sav_file <- file.path(wave_dirs[[i]], paste0(wave_id, ".sav"))

    if (!file.exists(sav_file)) {
      message("  Skipping ", wave_id, ": .sav file not found")
      next
    }

    message(
      "Processing ", wave_id,
      " (", i, "/", length(wave_dirs), " — ", phase_label, ")..."
    )
    raw <- haven::read_sav(sav_file)
    result[[wave_id]] <- process_wave(raw, wave_id, batteries)
  }

  n_ok <- sum(!vapply(result, is.null, logical(1L)))
  message("\n", phase_label, " complete: ", n_ok, " waves loaded.\n")
  result
}
