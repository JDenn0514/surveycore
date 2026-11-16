# Coverage report for the pipeline's covr gate (gate 7).
#
# Two modes, chosen by the COVR_MODE environment variable:
#
#   COVR_MODE=full (the default, used by --baseline)
#     Runs covr::package_coverage() on the whole test suite and prints the
#     package total as COVERAGE_PCT.
#
#   COVR_MODE=scoped (used by the normal gate run)
#     Runs only the test files mapped to the changed R/ files. The package
#     total is not printed, because a part of the suite cannot measure it.
#     When a changed R/ file has no mapped test file, the script falls back
#     to the full mode and says so.
#
# Both modes then print, in this order:
#   CHANGED_FILE_PCT <file>=<pct>        one line per changed R/ file
#   UNCOVERED_LINE <file>:<line>         one line per zero-hit line in those files
#   UNCOVERED_COUNT=<n>
#
# The changed-file list arrives in CHANGED_R_FILES as a comma-separated string.
# When it is empty only the package total is printed (full mode only).
#
# Whole-file percentages answer "did this file regress"; the UNCOVERED_LINE list
# is what answers the plan's real question — whether any line this PR ADDED is
# untested. Cross-reference those line numbers against `git diff` to tell an
# added line from a pre-existing one.
#
# Run with NOT_CRAN=true. Eleven test files carry a file-level skip_on_cran();
# without it they skip and coverage is understated.

# --- Test-file mapping ---------------------------------------------------------
# A file in a family maps to the whole family's tests (see .map_test_files()).
# A file with no family siblings uses the exact mapping: R/foo.R maps to
# tests/testthat/test-foo.R plus any split test-foo-*.R. The
# exceptions come from .claude/rules/testing-surveycore.md §File mapping. A
# helper file R/foo-helpers.R with no test file of its own maps to the tests of
# R/foo.R, because the helpers are tested through the functions that call them.
test_name_exceptions <- c(
  "core-classes" = "s7-classes",
  "core-metadata" = "metadata-system",
  "core-validators" = "validators",
  "core-constructors" = "constructors",
  "methods-conversion" = "conversion"
)

.tests_for_stem <- function(stem, test_names) {
  test_names[test_names == stem | startsWith(test_names, paste0(stem, "-"))]
}

.map_exact <- function(stem, test_names) {
  if (stem %in% names(test_name_exceptions)) {
    stem <- test_name_exceptions[[stem]]
  }
  found <- .tests_for_stem(stem, test_names)
  if (length(found) == 0L && endsWith(stem, "-helpers")) {
    found <- .tests_for_stem(sub("-helpers$", "", stem), test_names)
  }
  found
}

# A family is the first hyphen segment of the file name: R/analysis-means.R
# is in the "analysis" family. A file whose family has other members in R/
# maps to every test-<family>-*.R file plus the exact mapping of every
# family member, so a line reached only through a sibling's tests still
# counts as covered. A file with no family siblings keeps the exact mapping.
.map_test_files <- function(r_file, test_names, r_stems) {
  stem <- sub("\\.[rR]$", "", basename(r_file))
  family <- sub("-.*$", "", stem)
  members <- if (grepl("-", stem, fixed = TRUE)) {
    r_stems[startsWith(r_stems, paste0(family, "-"))]
  } else {
    stem
  }
  if (length(members) <= 1L) {
    return(.map_exact(stem, test_names))
  }
  found <- c(
    test_names[startsWith(test_names, paste0(family, "-"))],
    unlist(lapply(members, .map_exact, test_names = test_names))
  )
  sort(unique(found))
}

# --- Read inputs ---------------------------------------------------------------
mode <- Sys.getenv("COVR_MODE", "full")
changed <- Sys.getenv("CHANGED_R_FILES")
files <- setdiff(trimws(strsplit(changed, ",", fixed = TRUE)[[1]]), "")

root <- normalizePath(".", winslash = "/")
pkg_name <- read.dcf(file.path(root, "DESCRIPTION"), fields = "Package")[[1]]
test_dir <- file.path(root, "tests", "testthat")

if (identical(mode, "scoped")) {
  if (length(files) == 0L) {
    stop("COVR_MODE=scoped needs at least one file in CHANGED_R_FILES.")
  }
  test_names <- sub(
    "^test-",
    "",
    sub("\\.[rR]$", "", list.files(test_dir, pattern = "^test-.*\\.[rR]$"))
  )
  r_stems <- sub(
    "\\.[rR]$",
    "",
    list.files(file.path(root, "R"), pattern = "\\.[rR]$")
  )
  mapped <- lapply(
    files,
    .map_test_files,
    test_names = test_names,
    r_stems = r_stems
  )
  names(mapped) <- files
  unmapped <- files[lengths(mapped) == 0L]
  if (length(unmapped) > 0L) {
    mode <- "full"
    cat("COVR_MODE=full\n")
    cat(sprintf(
      "FALLBACK no mapped test file for %s; running the full suite\n",
      paste(unmapped, collapse = ", ")
    ))
  }
}

# --- Run coverage --------------------------------------------------------------
if (identical(mode, "scoped")) {
  scoped_tests <- sort(unique(unlist(mapped, use.names = FALSE)))
  cat("COVR_MODE=scoped\n")
  for (f in files) {
    cat(sprintf(
      "MAPPED %s -> %s\n",
      f,
      paste0("test-", mapped[[f]], ".R", collapse = ", ")
    ))
  }
  cat(sprintf("SCOPED_TEST_FILE_COUNT=%d\n", length(scoped_tests)))
  cat(paste(
    "NOTE A scoped run can over-report uncovered lines: a line covered only",
    "by a test file outside the mapped set reads as uncovered here.\n"
  ))
  cat(paste(
    "NOTE The 95% package coverage floor is enforced by the CI",
    "test-coverage job only (.github/workflows/test-coverage.yaml).\n"
  ))

  # covr installs the instrumented package and runs `code` in a fresh
  # R CMD BATCH process that starts with library(<pkg>). test_dir() with
  # load_package = "installed" uses that instrumented install, sources
  # tests/testthat/helper-*.R and setup-*.R, and gives each test file the
  # package namespace, as R CMD check does. The child process writes its
  # failure count to a status file, because covr shows the child's output only
  # when the child errors.
  status_file <- tempfile("covr-scoped-status-", fileext = ".txt")
  filter <- paste0("^(", paste(scoped_tests, collapse = "|"), ")$")
  q <- function(x) encodeString(x, quote = "\"")
  code <- c(
    sprintf(
      paste(
        "res <- testthat::test_dir(%s, filter = %s, package = %s,",
        "load_package = \"installed\", reporter = \"silent\",",
        "stop_on_failure = FALSE)"
      ),
      q(test_dir),
      q(filter),
      q(pkg_name)
    ),
    "df <- as.data.frame(res)",
    "bad <- df$failed > 0 | df$error",
    sprintf(
      paste(
        "writeLines(c(sprintf(\"SCOPED_TEST_FAILURES=%%d\", sum(bad)),",
        "sprintf(\"SCOPED_TEST_BLOCKS=%%d\", nrow(df)),",
        "sprintf(\"FAILED_TEST %%s: %%s\", df$file[bad], df$test[bad])), %s)"
      ),
      q(status_file)
    )
  )
  cov <- covr::package_coverage(type = "none", code = code)
  if (file.exists(status_file)) {
    writeLines(readLines(status_file))
  } else {
    cat("SCOPED_TEST_FAILURES=NA (the status file was not written)\n")
  }
} else {
  cov <- covr::package_coverage()
  cat(sprintf("COVERAGE_PCT=%.2f\n", covr::percent_coverage(cov)))
}

# --- Per-file detail for the changed files -------------------------------------
if (length(files) == 0L) {
  quit(save = "no", status = 0)
}

fc <- covr::coverage_to_list(cov)$filecoverage
for (f in files) {
  pct <- if (f %in% names(fc)) sprintf("%.2f", fc[[f]]) else "NA"
  cat(sprintf("CHANGED_FILE_PCT %s=%s\n", f, pct))
}

df <- as.data.frame(cov)
# covr's data frame names the file column "filename" in current releases;
# fall back to whatever column holds the path if that ever changes.
fcol <- if ("filename" %in% names(df)) "filename" else names(df)[1]
lcol <- if ("first_line" %in% names(df)) "first_line" else "line"

hit <- df[[if ("value" %in% names(df)) "value" else "coverage"]]
sel <- df[[fcol]] %in% files & hit == 0
uncovered <- df[sel, c(fcol, lcol), drop = FALSE]

if (nrow(uncovered) > 0L) {
  uncovered <- uncovered[
    order(uncovered[[fcol]], uncovered[[lcol]]),
    ,
    drop = FALSE
  ]
  for (i in seq_len(nrow(uncovered))) {
    cat(sprintf(
      "UNCOVERED_LINE %s:%s\n",
      uncovered[[fcol]][i],
      uncovered[[lcol]][i]
    ))
  }
}
cat(sprintf("UNCOVERED_COUNT=%d\n", nrow(uncovered)))
