# Generates tests/testthat/fixtures/analysis-cell-golden.rds, the golden
# fixture for tests/testthat/test-analysis-cell-equivalence.R.
#
# The fixture records what the six cell-building analysis functions return on
# a fixed source tree. Run it from the root of the working tree, against a
# separate worktree that holds that source tree:
#
#   git worktree add <dir> <base-sha>
#   Rscript data-raw/analysis-cell-golden.R <dir> <base-sha>
#
# The package code comes from <dir>. The scenario list comes from the current
# tree's tests/testthat/helper-cell-golden.R.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) {
  stop(
    "Usage: Rscript data-raw/analysis-cell-golden.R <dir> <base-sha>",
    call. = FALSE
  )
}
src_dir <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
base_sha <- args[[2L]]

git <- function(...) {
  out <- suppressWarnings(
    system2("git", c("-C", shQuote(src_dir), ...), stdout = TRUE, stderr = TRUE)
  )
  status <- attr(out, "status")
  if (is.null(status)) {
    status <- 0L
  }
  list(out = out, status = status)
}

# --- Guard: the source tree is the base commit, with R/ unchanged ----------

head_sha <- git("rev-parse", "HEAD")$out
want_sha <- git("rev-parse", base_sha)$out
if (!identical(head_sha, want_sha)) {
  stop(
    "Check `git rev-parse HEAD` failed: ",
    src_dir,
    " is at ",
    paste(head_sha, collapse = " "),
    ", not at ",
    paste(want_sha, collapse = " "),
    ". No fixture written.",
    call. = FALSE
  )
}

porcelain <- git("status", "--porcelain", "--", "R")
if (length(porcelain$out) > 0L || porcelain$status != 0L) {
  stop(
    "Check `git status --porcelain -- R` failed: ",
    src_dir,
    " has changes under R/:\n",
    paste(porcelain$out, collapse = "\n"),
    "\nNo fixture written.",
    call. = FALSE
  )
}

if (git("diff", "--quiet", base_sha, "--", "R")$status != 0L) {
  stop(
    "Check `git diff --quiet ",
    base_sha,
    " -- R` failed: R/ in ",
    src_dir,
    " differs from the base commit. No fixture written.",
    call. = FALSE
  )
}

# --- Load the base-commit package and the current helpers -------------------

pkgload::load_all(src_dir, helpers = FALSE, quiet = TRUE)
source("tests/testthat/helper-test-data.R", local = globalenv())
source("tests/testthat/helper-cell-golden.R", local = globalenv())

# --- Run every scenario ------------------------------------------------------

scenarios <- cell_golden_scenarios()
results <- list()
warnings <- list()

for (id in names(scenarios)) {
  seen <- character(0)
  value <- tryCatch(
    withCallingHandlers(
      scenarios[[id]](),
      warning = function(w) {
        seen <<- c(seen, class(w)[[1L]])
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) {
      stop(
        "Scenario ",
        id,
        " raised an error: ",
        conditionMessage(e),
        call. = FALSE
      )
    }
  )
  results[[id]] <- cell_golden_strip(value)
  warnings[[id]] <- seen
}

fixture <- list(
  provenance = list(
    base_sha = head_sha,
    r_version = R.version.string,
    blas = extSoftVersion()[["BLAS"]],
    lapack = La_library(),
    matprod = getOption("matprod"),
    created = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  ),
  formals = list(
    get_freqs = formals(get_freqs),
    get_means = formals(get_means),
    get_totals = formals(get_totals),
    get_variance = formals(get_variance),
    get_covariance = formals(get_covariance),
    get_ratios = formals(get_ratios)
  ),
  results = results,
  warnings = warnings
)

dir.create("tests/testthat/fixtures", showWarnings = FALSE)
saveRDS(
  fixture,
  "tests/testthat/fixtures/analysis-cell-golden.rds",
  compress = "xz"
)
message(
  "Wrote ",
  length(results),
  " scenarios from ",
  head_sha,
  " to tests/testthat/fixtures/analysis-cell-golden.rds"
)
