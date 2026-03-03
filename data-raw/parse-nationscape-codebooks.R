## Nationscape — Parse all codebook PDFs into a master Excel codebook
##
## Produces one Excel file per phase (+ one for parallel waves):
##   data-raw/nationscape/codebook_phase1.xlsx
##   data-raw/nationscape/codebook_phase2.xlsx
##   data-raw/nationscape/codebook_phase3.xlsx
##   data-raw/nationscape/codebook_parallel.xlsx
##
## Each Excel file has two sheets:
##   "Variables"  — one row per unique variable:
##       variable        | variable name (snake_case)
##       question_text   | full question prompt from codebook
##       response_options| pipe-separated "value=label" pairs (excl. skipped)
##       first_wave      | earliest wave where this variable appears
##       last_wave       | latest wave where it appears
##       n_waves         | number of waves containing this variable
##       changed         | TRUE if question text changed across waves
##       waves_present   | comma-separated list of all wave IDs
##
##   "Changes"    — rows only for variables whose question text changed:
##       variable | wave_id | question_text
##
## Requirements: pdftools, writexl
##   install.packages(c("pdftools", "writexl"))
##
## Run from the package root: source("data-raw/parse-nationscape-codebooks.R")

library(pdftools)
library(writexl)

NS_DIR <- file.path(here::here(), "data-raw", "nationscape")

## ---- Parser: extract one page of a codebook PDF ----------------------------
##
## Each page follows a strict structure:
##   Line 1-2: Header (wave name + date/N)
##   Blank lines
##   variable_name   ← snake_case heading, alone on a line
##   Question Prompt: [text, possibly wrapping to next lines]
##   [blank]
##   Choice     Value   ← table header (optional — some vars have no responses)
##   [response rows]
##   [page number line at the bottom]
##
## Returns a named list: variable, question_text, response_options
## Returns NULL for non-variable pages (cover page, screening text, etc.)

parse_page <- function(page_text) {
  ## Split into lines; trim trailing whitespace but preserve leading
  ## (we need leading whitespace to detect page-number-only lines)
  lines <- strsplit(page_text, "\n")[[1]]
  lines <- gsub("\\s+$", "", lines)          # trim trailing only
  lines <- lines[nchar(trimws(lines)) > 0]   # drop blank lines

  ## Remove header lines (wave title, date/N line)
  ## Pattern: starts with "Nationscape" or contains "(N =" or is just digits
  ## Also catches two-column page-number artifacts like "  169   169" (leading
  ## whitespace + page number from each column — the leading \s* is required)
  is_header <- grepl(
    "^Nationscape Wave|\\(N\\s*=|^\\s*\\d+\\s*$|^\\s*\\d+\\s+\\d+\\s*$",
    lines
  )
  lines <- lines[!is_header]
  if (length(lines) == 0) return(NULL)

  ## Trim remaining lines for easier matching
  trimmed <- trimws(lines)

  ## Variable name: a line that is pure snake_case (letters, digits, underscores)
  ## Appears as the first non-blank non-header line after stripping the header.
  ## Allow names with double underscores (e.g. start__date in some waves).
  var_idx <- which(grepl("^[a-z][a-z0-9_]+$", trimmed))[1]
  if (is.na(var_idx)) return(NULL)
  variable <- trimmed[var_idx]

  ## Question prompt: starts with "Question Prompt:"
  ## May span multiple lines; ends at the "Choice    Value" table header or EOF.
  prompt_start <- which(grepl("^Question Prompt:", trimmed))[1]
  if (is.na(prompt_start)) return(NULL)

  table_start  <- which(grepl("^Choice\\s+Value", trimmed))[1]
  prompt_end   <- if (!is.na(table_start)) table_start - 1L else length(trimmed)

  ## Split annotation lines (Display Condition, Randomization, Note) out of the
  ## prompt range — these appear after the question text but before the table.
  ann_pat <- "^(Display Condition|Randomization|Note):"
  ann_pos <- which(grepl(ann_pat, trimmed[prompt_start:prompt_end])) +
    prompt_start - 1L

  ## Question text ends just before the first annotation line (or at prompt_end)
  q_end <- if (length(ann_pos) > 0) ann_pos[1] - 1L else prompt_end

  prompt_lines  <- trimmed[prompt_start:q_end]
  question_text <- paste(prompt_lines, collapse = " ")
  question_text <- trimws(sub("^Question Prompt:\\s*", "", question_text))

  ## Extract each annotation segment
  display_condition <- ""
  randomization     <- ""
  note              <- ""

  for (k in seq_along(ann_pos)) {
    seg_start <- ann_pos[k]
    seg_end   <- if (k < length(ann_pos)) ann_pos[k + 1L] - 1L else prompt_end
    seg_text  <- trimws(paste(trimmed[seg_start:seg_end], collapse = " "))

    if (grepl("^Display Condition:", seg_text)) {
      display_condition <- trimws(sub("^Display Condition:\\s*", "", seg_text))
    } else if (grepl("^Randomization:", seg_text)) {
      randomization <- trimws(sub("^Randomization:\\s*", "", seg_text))
    } else if (grepl("^Note:", seg_text)) {
      note <- trimws(sub("^Note:\\s*", "", seg_text))
    }
  }

  ## Response options: rows in the table that end with a numeric value or "."
  ## Exclude "Respondent Skipped" (system missing marker).
  response_parts <- character(0)
  if (!is.na(table_start)) {
    for (i in (table_start + 1L):length(trimmed)) {
      ln <- trimmed[i]
      ## Skip blank, header repeat, or page-number-only lines
      if (!nzchar(ln)) next
      if (grepl("^Choice\\s+Value", ln)) next
      if (grepl("Respondent Skipped", ln, ignore.case = TRUE)) next

      ## Detect rows that end with a bare integer or "."
      ## e.g. "Generally headed in the right direction   1"
      ##      "Not sure   999"
      m <- regexpr("(\\d+|\\.)\\s*$", ln)
      if (m == -1L) next

      value  <- trimws(regmatches(ln, m))
      choice <- trimws(substr(ln, 1L, m - 1L))
      if (nzchar(choice) && nzchar(value)) {
        response_parts <- c(response_parts, paste0(value, "=", choice))
      }
    }
  }

  list(
    variable          = variable,
    question_text     = question_text,
    response_options  = paste(response_parts, collapse = " | "),
    display_condition = display_condition,
    randomization     = randomization,
    note              = note
  )
}

## ---- Parser: extract all variables from one codebook PDF -------------------

parse_codebook <- function(pdf_path, wave_id) {
  pages <- tryCatch(pdf_text(pdf_path), error = function(e) NULL)
  if (is.null(pages)) {
    message("  WARNING: could not read ", basename(pdf_path))
    return(data.frame())
  }

  results <- lapply(pages, parse_page)
  results <- Filter(Negate(is.null), results)

  if (length(results) == 0) return(data.frame())

  df <- data.frame(
    wave_id           = wave_id,
    variable          = vapply(results, `[[`, character(1L), "variable"),
    question_text     = vapply(results, `[[`, character(1L), "question_text"),
    response_options  = vapply(results, `[[`, character(1L), "response_options"),
    display_condition = vapply(results, `[[`, character(1L), "display_condition"),
    randomization     = vapply(results, `[[`, character(1L), "randomization"),
    note              = vapply(results, `[[`, character(1L), "note"),
    stringsAsFactors  = FALSE
  )
  df
}

## ---- Collate: one phase directory → master variable table ------------------
##
## Strategy:
##   1. Parse every codebook in the phase.
##   2. For each variable, record:
##        - All waves where it appears
##        - The question text from the FIRST wave it appears
##        - A flag if question text differs across waves (worth reviewing)
##   3. Return two data frames: summary (one row/variable) + changes log.

collate_phase <- function(phase_dir, phase_label) {
  wave_dirs <- sort(list.dirs(phase_dir, full.names = TRUE, recursive = FALSE))
  wave_dirs <- wave_dirs[grepl("ns[0-9]", basename(wave_dirs))]

  all_rows <- vector("list", length(wave_dirs))

  for (i in seq_along(wave_dirs)) {
    wave_id  <- basename(wave_dirs[[i]])
    pdf_path <- file.path(wave_dirs[[i]], paste0("codebook_", wave_id, ".pdf"))

    if (!file.exists(pdf_path)) {
      message("  Skipping ", wave_id, ": codebook PDF not found")
      next
    }

    message("  Parsing ", wave_id, " (", i, "/", length(wave_dirs),
            " — ", phase_label, ")...")
    all_rows[[i]] <- parse_codebook(pdf_path, wave_id)
  }

  raw <- do.call(rbind, Filter(Negate(is.null), all_rows))
  if (nrow(raw) == 0) return(list(variables = data.frame(), changes = data.frame()))

  ## Build per-variable summary
  vars <- unique(raw$variable)
  summary_rows <- lapply(vars, function(v) {
    sub_df    <- raw[raw$variable == v, ]
    waves     <- sub_df$wave_id
    texts     <- sub_df$question_text
    responses <- sub_df$response_options

    ## Use the first wave's values as canonical
    canonical_text  <- texts[1]
    canonical_resp  <- responses[1]
    changed         <- any(texts != canonical_text)

    data.frame(
      variable          = v,
      question_text     = canonical_text,
      response_options  = canonical_resp,
      display_condition = sub_df$display_condition[1],
      randomization     = sub_df$randomization[1],
      note              = sub_df$note[1],
      first_wave        = waves[1],
      last_wave         = waves[length(waves)],
      n_waves           = length(waves),
      changed           = changed,
      waves_present     = paste(waves, collapse = ", "),
      stringsAsFactors  = FALSE
    )
  })

  summary_df <- do.call(rbind, summary_rows)

  ## Build changes log (only variables where text differed)
  changed_vars <- summary_df$variable[summary_df$changed]
  changes_rows <- lapply(changed_vars, function(v) {
    sub_df <- raw[raw$variable == v, ]
    sub_df[, c("wave_id", "variable", "question_text", "response_options")]
  })
  changes_df <- if (length(changes_rows) > 0) {
    do.call(rbind, changes_rows)
  } else {
    data.frame(
      wave_id = character(0), variable = character(0),
      question_text = character(0), response_options = character(0)
    )
  }

  list(variables = summary_df, changes = changes_df)
}

## ---- Main ------------------------------------------------------------------

phases <- list(
  list(
    dir    = file.path(NS_DIR, "phase_1_v20210301"),
    label  = "Phase 1",
    output = file.path(NS_DIR, "codebook_phase1.xlsx")
  ),
  list(
    dir    = file.path(NS_DIR, "phase_2_v20210301"),
    label  = "Phase 2",
    output = file.path(NS_DIR, "codebook_phase2.xlsx")
  ),
  list(
    dir    = file.path(NS_DIR, "phase_3_v20210301"),
    label  = "Phase 3",
    output = file.path(NS_DIR, "codebook_phase3.xlsx")
  ),
  list(
    dir    = file.path(NS_DIR, "phase_parallel_v20210301"),
    label  = "Parallel waves",
    output = file.path(NS_DIR, "codebook_parallel.xlsx")
  )
)

for (phase in phases) {
  if (!dir.exists(phase$dir)) {
    message("Skipping ", phase$label, ": directory not found")
    next
  }

  message("\n── ", phase$label, " ──────────────────────────────────────────")
  result <- collate_phase(phase$dir, phase$label)

  if (nrow(result$variables) == 0) {
    message("  No variables extracted — skipping Excel output")
    next
  }

  write_xlsx(
    list(
      Variables = result$variables,
      Changes   = result$changes
    ),
    path = phase$output
  )

  message(
    "  Written: ", basename(phase$output),
    "  (", nrow(result$variables), " unique variables",
    if (nrow(result$changes) > 0)
      paste0(", ", length(unique(result$changes$variable)),
             " with question text changes)")
    else ")"
  )
}

message("\nDone. Excel files saved to data-raw/nationscape/")
