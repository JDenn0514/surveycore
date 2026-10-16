#!/usr/bin/env bash
# Setup script for a Claude Code cloud environment (claude.ai/code).
#
# This file is not run from the repository. Paste its content into the
# "Setup script" field of the environment settings. The script runs as root on
# Ubuntu 24.04 before the first session. When it finishes in about 5 minutes,
# the filesystem is cached and later sessions skip it. The cache expires after
# about 7 days, or when the script or the network settings change.
#
# The environment must use the "Custom" network access level, with the box
# "Also include default list of common package managers" checked, and these
# hosts added (one per line):
#
#   cloud.r-project.org
#   p3m.dev
#   packagemanager.posit.co
#   rspm-sync.rstudio.com
#   *.r-universe.dev
#   r-universe.dev
#   archive.ubuntu.com
#   security.ubuntu.com
#
# The default "Trusted" list has no R hosts. That is why an earlier session
# fell back to R 4.4 from conda-forge and could not install srr.
#
# .claude/scripts/cloud-session-start.sh runs at each session start and
# installs any package that DESCRIPTION gained after this cache was built.

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

. /etc/os-release
codename="${VERSION_CODENAME}"

# 1. R release from the CRAN apt repository, the same R that CI uses.
apt-get update -qq
apt-get install -y -qq --no-install-recommends ca-certificates wget gnupg
wget -qO /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc \
  https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc
echo "deb https://cloud.r-project.org/bin/linux/ubuntu ${codename}-cran40/" \
  > /etc/apt/sources.list.d/cran.list
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
  r-base r-base-dev pandoc qpdf libcurl4-openssl-dev libssl-dev libxml2-dev

# 2. Binary packages from Posit Package Manager. A binary install takes
#    seconds. A source install of the same set takes much longer than the
#    5-minute cache limit.
cat >> "$(R RHOME)/etc/Rprofile.site" <<EOF
local({
  options(
    repos = c(CRAN = "https://p3m.dev/cran/__linux__/${codename}/latest"),
    HTTPUserAgent = sprintf(
      "R/%s R (%s)",
      getRversion(),
      paste(getRversion(), R.version["platform"], R.version["arch"], R.version["os"])
    ),
    Ncpus = parallel::detectCores()
  )
})
EOF

# 3. R packages: Imports, Suggests and the development tools. pak installs
#    the system libraries that each package needs.
#    p3m.dev sends each binary download on to rspm-sync.rstudio.com. When that
#    host is not on the network list, the download fails here.
Rscript -e 'install.packages("pak")'
if ! Rscript -e 'quit(status = !requireNamespace("pak", quietly = TRUE))'; then
  echo "pak was not installed. Check that rspm-sync.rstudio.com is on the network list."
  exit 1
fi
Rscript - <<'EOF'
pkgs <- c(
  # Imports
  "S7", "rlang", "tidyselect", "cli", "tibble", "dplyr", "marginaleffects",
  "pbivnorm",
  # Suggests (surveytidy is installed below)
  "testthat", "withr", "survey", "survival", "srvyr", "haven", "lifecycle",
  "broom", "polycor", "jtools", "labelled", "covr", "knitr", "rmarkdown",
  # Development tools
  "devtools", "roxygen2", "rcmdcheck", "lintr"
)
pak::pkg_install(pkgs, upgrade = FALSE, ask = FALSE)

# srr is the roxygen roclet that DESCRIPTION names. It is not on CRAN.
install.packages(
  "srr",
  repos = c("https://ropensci-review-tools.r-universe.dev", getOption("repos"))
)

# surveytidy comes from GitHub (DESCRIPTION Remotes). The cloud GitHub proxy
# serves only the repositories attached to the session, so this install can
# fail. The tests that use surveytidy skip when it is absent.
tryCatch(
  pak::pkg_install("JDenn0514/surveytidy", upgrade = FALSE, ask = FALSE),
  error = function(e) {
    message("surveytidy was not installed: ", conditionMessage(e))
  }
)
EOF

# 4. The air formatter. It downloads from a GitHub release, which the GitHub
#    proxy can refuse, so a failure here does not stop the setup.
if curl -LsSf https://github.com/posit-dev/air/releases/latest/download/air-installer.sh | sh; then
  for dir in "$HOME/.local/bin" "$HOME/.cargo/bin"; do
    if [ -x "$dir/air" ]; then
      cp "$dir/air" /usr/local/bin/air
    fi
  done
else
  echo "air was not installed. The formatting gate cannot run in this environment."
fi

Rscript -e 'cat("R", as.character(getRversion()), "is ready.\n")'
