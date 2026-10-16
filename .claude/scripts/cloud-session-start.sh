#!/usr/bin/env bash
# SessionStart hook. In a cloud session, it installs any package that
# DESCRIPTION names and the cached environment lacks, then reports the R
# version. The output goes into Claude's context. On a local machine it exits
# at once.
#
# The environment itself is built by .claude/scripts/cloud-env-setup.sh, which
# goes in the "Setup script" field of the cloud environment settings.

[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0

if ! command -v Rscript > /dev/null 2>&1; then
  echo "R is not installed in this cloud environment."
  echo "Paste .claude/scripts/cloud-env-setup.sh into the environment's Setup script field."
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

Rscript - <<'EOF' || true
fields <- read.dcf("DESCRIPTION", c("Imports", "Suggests"))
pkgs <- unlist(strsplit(fields[!is.na(fields)], ","))
pkgs <- trimws(sub("\\(.*", "", pkgs))
pkgs <- c(pkgs, "devtools", "roxygen2", "rcmdcheck", "srr")
pkgs <- setdiff(pkgs, c("", rownames(installed.packages(priority = "base"))))
installed <- vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)
missing <- pkgs[!installed]

github <- c(surveytidy = "JDenn0514/surveytidy")
universe <- c(srr = "https://ropensci-review-tools.r-universe.dev")
for (pkg in missing) {
  tryCatch(
    if (pkg %in% names(universe)) {
      install.packages(pkg, repos = c(universe[[pkg]], getOption("repos")))
    } else if (pkg %in% names(github)) {
      pak::pkg_install(github[[pkg]], upgrade = FALSE, ask = FALSE)
    } else {
      pak::pkg_install(pkg, upgrade = FALSE, ask = FALSE)
    },
    error = function(e) NULL
  )
}

still_missing <- missing[!vapply(missing, requireNamespace, logical(1), quietly = TRUE)]
cat("Cloud session: R", as.character(getRversion()), "\n")
if (length(still_missing) > 0) {
  cat(
    "These packages are not installed:",
    paste(still_missing, collapse = ", "),
    "\nTests that need them skip. Report this limit with the results.\n"
  )
} else {
  cat("All DESCRIPTION packages and srr are installed.\n")
}
if (!nzchar(Sys.which("air"))) {
  cat("air is not installed, so `air format --check` cannot run here.\n")
}
EOF

exit 0
