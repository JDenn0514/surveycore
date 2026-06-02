#!/usr/bin/env Rscript
# format-extras.R — Air formatting for roxygen @examples and .md R chunks
# Usage: Rscript tools/format-extras.R [file1 file2 ...]

AIR <- "/opt/homebrew/bin/air"
skipped <- list()

# ── Roxygen @examples formatter ───────────────────────────────────────────────

format_r_file <- function(path) {
  lines <- readLines(path, warn = FALSE)
  out <- list()
  i <- 1L
  changed <- FALSE

  while (i <= length(lines)) {
    if (grepl("^#' @examples\\s*$", lines[[i]])) {
      out[[length(out) + 1L]] <- lines[[i]]  # keep @examples line
      i <- i + 1L

      block <- character(0L)
      block_start <- i
      while (i <= length(lines) &&
             grepl("^#'", lines[[i]]) &&
             !grepl("^#' @\\w", lines[[i]])) {
        block <- c(block, lines[[i]])
        i <- i + 1L
      }

      if (length(block) == 0L) next

      code <- sub("^#' ?", "", block)
      if (!any(nzchar(trimws(code)))) {
        out[[length(out) + 1L]] <- block
        next
      }

      tmp <- tempfile(fileext = ".R")
      writeLines(code, tmp)
      ret <- system2(AIR, c("format", tmp), stdout = FALSE, stderr = FALSE)

      if (ret == 0L) {
        fmt <- readLines(tmp, warn = FALSE)
        new_block <- ifelse(nzchar(fmt), paste0("#' ", fmt), "#'")
        if (!identical(new_block, block)) changed <- TRUE
        out[[length(out) + 1L]] <- new_block
      } else {
        out[[length(out) + 1L]] <- block
        skipped[[length(skipped) + 1L]] <<- list(
          file = path,
          range = paste0(
            block_start, "–",
            block_start + length(block) - 1L
          )
        )
      }
      unlink(tmp)
    } else {
      out[[length(out) + 1L]] <- lines[[i]]
      i <- i + 1L
    }
  }

  if (changed) writeLines(unlist(out), path)
  invisible(changed)
}

# ── .md fenced block formatter ────────────────────────────────────────────────

format_md_file <- function(path) {
  lines <- readLines(path, warn = FALSE)
  out <- list()
  i <- 1L
  changed <- FALSE

  while (i <= length(lines)) {
    if (grepl("^(\\s*)```r\\s*$", lines[[i]], perl = TRUE)) {
      prefix <- regmatches(lines[[i]], regexpr("^\\s*", lines[[i]]))
      out[[length(out) + 1L]] <- lines[[i]]  # opening fence
      i <- i + 1L

      block <- character(0L)
      block_start <- i
      while (i <= length(lines) && !grepl("^\\s*```\\s*$", lines[[i]])) {
        block <- c(block, lines[[i]])
        i <- i + 1L
      }

      # i points at closing fence or EOF
      if (length(block) == 0L || i > length(lines)) {
        out[[length(out) + 1L]] <- block
        if (i <= length(lines)) {
          out[[length(out) + 1L]] <- lines[[i]]
          i <- i + 1L
        }
        next
      }

      code <- if (nzchar(prefix)) sub(paste0("^", prefix), "", block) else block
      if (!any(nzchar(trimws(code)))) {
        out[[length(out) + 1L]] <- block
        out[[length(out) + 1L]] <- lines[[i]]
        i <- i + 1L
        next
      }

      tmp <- tempfile(fileext = ".R")
      writeLines(code, tmp)
      ret <- system2(AIR, c("format", tmp), stdout = FALSE, stderr = FALSE)

      if (ret == 0L) {
        fmt <- readLines(tmp, warn = FALSE)
        new_block <- if (nzchar(prefix)) paste0(prefix, fmt) else fmt
        if (!identical(new_block, block)) changed <- TRUE
        out[[length(out) + 1L]] <- new_block
      } else {
        out[[length(out) + 1L]] <- block
        skipped[[length(skipped) + 1L]] <<- list(
          file = path,
          range = paste0(
            block_start, "–",
            block_start + length(block) - 1L
          )
        )
      }
      unlink(tmp)

      out[[length(out) + 1L]] <- lines[[i]]  # closing fence
      i <- i + 1L
    } else {
      out[[length(out) + 1L]] <- lines[[i]]
      i <- i + 1L
    }
  }

  if (changed) writeLines(unlist(out), path)
  invisible(changed)
}

# ── Dispatch ──────────────────────────────────────────────────────────────────

args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0L) quit(status = 0L)

for (f in args) {
  if (!file.exists(f)) next
  ext <- tolower(tools::file_ext(f))
  if (ext == "r")  format_r_file(f)
  if (ext == "md") format_md_file(f)
}

# ── Warnings summary ──────────────────────────────────────────────────────────

if (length(skipped) > 0L) {
  n <- length(skipped)
  message(sprintf(
    "⚠  %d code block%s skipped (Air could not parse):",
    n, if (n == 1L) "" else "s"
  ))
  for (s in skipped) {
    message(sprintf("   %s  lines %s", s$file, s$range))
  }
  message("")
  message("   The block was left unformatted. To inspect the parse error:")
  message("     air format --check <your-temp-file.R>")
  message("   To bypass the hook entirely next time:")
  message("     git commit --no-verify")
}
