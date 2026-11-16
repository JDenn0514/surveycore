# Test and coverage report for the pipeline's gate 2.
#
# One covr run that also runs the whole test suite. covr::package_coverage()
# installs the instrumented package and runs `code` in a fresh process. The
# code runs every file in tests/testthat with testthat::test_dir(), so the
# test results and the coverage come from the same run.
#
# The script prints, in this order:
#   TEST_FAILURES=<n> TEST_WARNINGS=<n> TEST_SKIPS=<n> TEST_PASSES=<n>
#   [ FAIL n | WARN n | SKIP n | PASS n ]  the same shape as testthat's summary
#   FAILED_TEST <file>: <test>            one line per failing test block
#   COVERAGE_PCT=<pct>                    the package total
#   CHANGED_FILE_PCT <file>=<pct>         one line per changed R/ file
#   UNCOVERED_LINE <file>:<line>          one line per zero-hit line in those files
#   UNCOVERED_COUNT=<n>
#
# When the child process does not write its status file, the first line reads
# TEST_STATUS=missing and no counts are printed.
#
# The changed-file list arrives in CHANGED_R_FILES as a comma-separated string.
# When it is empty the per-file lines and UNCOVERED_COUNT are not printed.
#
# Whole-file percentages answer "did this file regress"; the UNCOVERED_LINE list
# is what answers the plan's real question — whether any line this PR ADDED is
# untested. Cross-reference those line numbers against `git diff` to tell an
# added line from a pre-existing one.
#
# Run with NOT_CRAN=true. Eleven test files carry a file-level skip_on_cran();
# without it they skip and coverage is understated.

# --- Read inputs ---------------------------------------------------------------
changed <- Sys.getenv("CHANGED_R_FILES")
files <- setdiff(trimws(strsplit(changed, ",", fixed = TRUE)[[1]]), "")

root <- normalizePath(".", winslash = "/")
pkg_name <- read.dcf(file.path(root, "DESCRIPTION"), fields = "Package")[[1]]
test_dir <- file.path(root, "tests", "testthat")

# --- Run the tests under covr --------------------------------------------------
# covr installs the instrumented package and runs `code` in a fresh
# R CMD BATCH process that starts with library(<pkg>). test_dir() with
# load_package = "installed" uses that instrumented install, sources
# tests/testthat/helper-*.R and setup-*.R, and gives each test file the
# package namespace, as R CMD check does. The child process writes its
# counts to a status file, because covr shows the child's output only when
# the child errors.
#
# The counts follow testthat's summary line. as.data.frame() puts a block's
# error in `error`, not in `failed`, so FAIL is failed expectations plus
# blocks that ended in an error. A block stops at its first skip, so SKIP is
# the number of skipped blocks.
status_file <- tempfile("covr-test-status-", fileext = ".txt")
q <- function(x) encodeString(x, quote = "\"")
code <- c(
  sprintf(
    paste(
      "res <- testthat::test_dir(%s, package = %s,",
      "load_package = \"installed\", reporter = \"silent\",",
      "stop_on_failure = FALSE, stop_on_warning = FALSE)"
    ),
    q(test_dir),
    q(pkg_name)
  ),
  "df <- as.data.frame(res)",
  "bad <- df$failed > 0 | df$error",
  "n <- c(sum(df$failed) + sum(df$error), sum(df$warning),",
  "  sum(df$skipped), sum(df$passed))",
  sprintf(
    paste(
      "writeLines(c(",
      "sprintf(\"TEST_FAILURES=%%d TEST_WARNINGS=%%d TEST_SKIPS=%%d",
      "TEST_PASSES=%%d\", n[1], n[2], n[3], n[4]),",
      "sprintf(\"[ FAIL %%d | WARN %%d | SKIP %%d | PASS %%d ]\",",
      "n[1], n[2], n[3], n[4]),",
      "sprintf(\"FAILED_TEST %%s: %%s\", df$file[bad], df$test[bad])), %s)"
    ),
    q(status_file)
  )
)
cov <- covr::package_coverage(type = "none", code = code)
if (file.exists(status_file)) {
  writeLines(readLines(status_file))
} else {
  cat("TEST_STATUS=missing (the status file was not written)\n")
}
cat(sprintf("COVERAGE_PCT=%.2f\n", covr::percent_coverage(cov)))

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
