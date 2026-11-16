#!/usr/bin/env bash
# Run all surveycore validation gates in order, log full output per gate,
# and print one compact summary. Built for the tester agent: ONE background
# call, one summary read, zero polling turns.
#
# Usage:
#   bash .claude/scripts/run-gates.sh <log-dir> [--skip-pkgdown] [--baseline]
#
#   --skip-pkgdown  Skip gate 6. Allowed ONLY under the skip conditions in
#                   r-package-profile.md (never when NAMESPACE changes).
#   --baseline      Run only gates 2 (tests) and 7 (full coverage with the
#                   95% floor). For the orchestrator's Before-column capture
#                   on a clean tree.
#
# Gates: 1 document(), 2 test(), 4 R CMD build, 5 R CMD check (no tests),
# 6 check_pkgdown(), 7 covr (skipped or scoped to the changed R/ files).
# Gate 3 (run_examples()) is removed: R CMD check runs the examples.
#
# Exit code 0 = all gates PASS. The summary names the log file of any FAIL.
# Gate definitions live in r-package-profile.md §Validation commands.

set -u
LOGDIR="${1:?usage: run-gates.sh <log-dir> [--skip-pkgdown] [--baseline]}"
shift || true
SKIP_PKGDOWN=0
BASELINE=0
for a in "$@"; do
  case "$a" in
    --skip-pkgdown) SKIP_PKGDOWN=1 ;;
    --baseline)     BASELINE=1 ;;
  esac
done
mkdir -p "$LOGDIR"

SUMMARY=""
OVERALL=0

row() { SUMMARY="${SUMMARY}${1}\n"; }

fail_gate() { # name logfile note
  row "| $1 | FAIL | $3 — read $2 |"
  OVERALL=1
}

pass_gate() { # name note
  row "| $1 | PASS | $2 |"
}

# --- Gate 2: devtools::test() ------------------------------------------
gate_test() {
  local log="$LOGDIR/gate-2-test.log"
  NOT_CRAN=true Rscript -e 'devtools::test()' > "$log" 2>&1
  local line
  line=$(grep -E '\[ FAIL [0-9]+' "$log" | tail -1)
  local nfail
  nfail=$(printf '%s' "$line" | sed -E 's/.*FAIL ([0-9]+).*/\1/')
  if [ -n "$line" ] && [ "$nfail" = "0" ]; then
    pass_gate "devtools::test()" "$line"
  else
    fail_gate "devtools::test()" "$log" "${line:-no result line found}"
  fi
}

# --- Gate 7: coverage ----------------------------------------------------
# NOT_CRAN=true matches gate 2. Eleven test files carry a file-level
# skip_on_cran(); without the variable they skip and coverage reads low.
#
# --baseline: full covr::package_coverage() and the package total, checked
# against the 95% floor. Unchanged from the old gate.
gate_covr_baseline() {
  local log="$LOGDIR/gate-7-covr.log"
  local changed
  changed=$(git diff --name-only develop...HEAD -- 'R/*.R' 2>/dev/null | tr '\n' ',')
  NOT_CRAN=true COVR_MODE=full CHANGED_R_FILES="$changed" \
    Rscript .claude/scripts/covr-report.R > "$log" 2>&1
  local pct
  pct=$(grep -oE 'COVERAGE_PCT=[0-9.]+' "$log" | tail -1 | cut -d= -f2)
  local nunc
  nunc=$(grep -oE 'UNCOVERED_COUNT=[0-9]+' "$log" | tail -1 | cut -d= -f2)
  local detail="${pct}%"
  if [ -n "$nunc" ]; then
    detail="${detail}; changed R/ files: $(grep -c '^CHANGED_FILE_PCT' "$log"), uncovered lines in them: ${nunc}"
  fi
  if [ -z "$pct" ]; then
    fail_gate "covr" "$log" "coverage did not run"
  elif awk "BEGIN{exit !($pct >= 95)}"; then
    pass_gate "covr" "$detail"
  else
    fail_gate "covr" "$log" "coverage ${pct}% is below the 95% floor"
  fi
}

# Normal mode: answer "are this PR's changed lines tested". The gates run
# before the shipper commits, so the changed-file list takes committed,
# uncommitted and untracked R/ files, measured from the merge base with
# develop. A deleted file has nothing to cover and drops out.
# - No changed R/ file: covr is skipped.
# - Otherwise covr-report.R runs only the test files mapped to the changed
#   files, or the full suite when a changed file has no mapped test file.
# The gate fails only when covr did not run or a test failed. The 95%
# package floor is enforced by the CI test-coverage job only.
# The base is the newer of the merge bases with develop and origin/develop,
# so a stale local develop does not count develop's own commits as changes.
changed_r_files() {
  local base b2
  base=$(git merge-base develop HEAD 2>/dev/null)
  b2=$(git merge-base origin/develop HEAD 2>/dev/null)
  if [ -z "$base" ]; then
    base=${b2:-develop}
  elif [ -n "$b2" ] && git merge-base --is-ancestor "$base" "$b2"; then
    base=$b2
  fi
  {
    git diff --name-only "$base" -- 'R/*.R'
    git ls-files --others --exclude-standard -- 'R/*.R'
  } 2>/dev/null | sort -u | while read -r f; do
    [ -f "$f" ] && printf '%s,' "$f"
  done
}

gate_covr() {
  local log="$LOGDIR/gate-7-covr.log"
  local changed
  changed=$(changed_r_files)
  if [ -z "$changed" ]; then
    echo "COVR_MODE=skipped (no R/ file changed vs develop)" > "$log"
    row "| covr | SKIPPED | no R/ file changed vs develop |"
    return
  fi
  NOT_CRAN=true COVR_MODE=scoped CHANGED_R_FILES="$changed" \
    Rscript .claude/scripts/covr-report.R > "$log" 2>&1
  local mode nfiles nunc nfail
  mode=$(grep -oE '^COVR_MODE=[a-z]+' "$log" | tail -1 | cut -d= -f2)
  nfiles=$(grep -c '^CHANGED_FILE_PCT' "$log")
  nunc=$(grep -oE 'UNCOVERED_COUNT=[0-9]+' "$log" | tail -1 | cut -d= -f2)
  nfail=$(grep -oE '^SCOPED_TEST_FAILURES=[0-9]+' "$log" | tail -1 | cut -d= -f2)
  local detail="changed R/ files: ${nfiles}, uncovered lines in them: ${nunc}; package floor: CI only"
  if [ "$mode" = "scoped" ]; then
    detail="scoped, $(grep -oE 'SCOPED_TEST_FILE_COUNT=[0-9]+' "$log" | cut -d= -f2) test files; ${detail}"
  else
    detail="full suite (no mapped test file); ${detail}"
  fi
  if [ -z "$nunc" ]; then
    fail_gate "covr" "$log" "coverage did not run"
  elif [ "$mode" = "scoped" ] && [ "${nfail:-x}" != "0" ]; then
    fail_gate "covr" "$log" "scoped test run: ${nfail:-unknown} failing test blocks"
  else
    pass_gate "covr" "$detail"
  fi
}

if [ "$BASELINE" = "1" ]; then
  gate_test
  gate_covr_baseline
else
  # --- Gate 1: document() + drift check --------------------------------
  # Hash NAMESPACE and man/ before and after document(), then compare the two
  # snapshots. The gate asks "did document() write anything", not "does man/
  # differ from HEAD". Those two agree only on a committed tree, and every
  # pipeline run measures the gates before the shipper commits, so a builder
  # who regenerates an .Rd correctly leaves it uncommitted and the old
  # `git diff -- NAMESPACE man/` test failed every correct roxygen change
  # (issue #233). Hashing the file list, not only the contents, also catches
  # an added or a deleted .Rd.
  log="$LOGDIR/gate-1-document.log"
  # sort by path (field 2), so a rewritten file shows as one adjacent pair
  # in the diff below rather than two entries a hash-order apart.
  snapshot_docs() { find NAMESPACE man -type f -exec md5sum {} + 2>/dev/null | sort -k 2; }
  before=$(snapshot_docs)
  Rscript -e 'devtools::document()' > "$log" 2>&1
  after=$(snapshot_docs)
  if [ "$before" = "$after" ]; then
    pass_gate "devtools::document()" "document() wrote nothing"
  else
    {
      echo
      echo "--- files document() added, removed or rewrote ---"
      diff <(echo "$before") <(echo "$after")
    } >> "$log" 2>&1
    fail_gate "devtools::document()" "$log" "document() rewrote NAMESPACE/man (builder forgot document())"
  fi

  gate_test

  # --- Gate 3: removed -------------------------------------------------
  # Gate 3 ran devtools::run_examples(). R CMD check (gate 5) runs every
  # example too, so the gate was a second run of the same code. The other
  # gate numbers and log names stay as they were.

  # --- Gate 4: R CMD build ----------------------------------------------
  log="$LOGDIR/gate-4-build.log"
  rm -f ./*.tar.gz
  if R CMD build . > "$log" 2>&1 && ls ./*.tar.gz >/dev/null 2>&1; then
    TARBALL=$(ls -t ./*.tar.gz | head -1)
    pass_gate "R CMD build" "$TARBALL"
  else
    TARBALL=""
    fail_gate "R CMD build" "$log" "no tarball produced"
  fi

  # --- Gate 5: R CMD check --as-cran ------------------------------------
  log="$LOGDIR/gate-5-check.log"
  if [ -n "$TARBALL" ]; then
    # --no-manual mirrors CI (.github/workflows/R-CMD-check.yaml passes
    # c("--as-cran", "--no-manual")). Without it the PDF-manual step needs a
    # LaTeX toolchain; where none is installed it raises 1 ERROR + 1 WARNING
    # and leaves surveycore-manual.tex behind as a third NOTE — none of which
    # CI ever sees, and none of which a builder can fix.
    # --no-tests: gate 2 already ran the full test suite, and CI runs the
    # check with tests on four operating systems. Inside the check the
    # suite took 534 of 810 seconds on PR 6. The check still runs the
    # examples, which replaces the old gate 3.
    R CMD check --as-cran --no-manual --no-tests "$TARBALL" > "$log" 2>&1
    CHECKDIR=$(ls -dt ./*.Rcheck 2>/dev/null | head -1)
    [ -n "$CHECKDIR" ] && cp "$CHECKDIR/00check.log" "$LOGDIR/gate-5-00check.log" 2>/dev/null
    status_line=$(grep -E '^Status:' "$log" | tail -1)
    if printf '%s' "$status_line" | grep -qE 'ERROR|WARNING'; then
      fail_gate "R CMD check --as-cran" "$LOGDIR/gate-5-00check.log" "$status_line"
    else
      pass_gate "R CMD check --as-cran" "${status_line:-Status line missing — verify log} (NOTEs need review per pre-approved list)"
    fi
    [ -n "$CHECKDIR" ] && rm -rf "$CHECKDIR"
    rm -f "$TARBALL"
  else
    fail_gate "R CMD check --as-cran" "$LOGDIR/gate-4-build.log" "skipped — build failed"
  fi

  # --- Gate 6: pkgdown ----------------------------------------------------
  if [ "$SKIP_PKGDOWN" = "1" ]; then
    row "| pkgdown | SKIPPED | scope (log skip reason in audit.md) |"
  else
    log="$LOGDIR/gate-6-pkgdown.log"
    # check_pkgdown() checks _pkgdown.yml without building the site: every
    # exported topic must be in the reference index. That is the failure
    # that once broke the pkgdown CI job. It takes seconds; build_site()
    # took 6 minutes on PR 6. CI still builds the full site.
    if Rscript -e 'pkgdown::check_pkgdown()' > "$log" 2>&1; then
      pass_gate "pkgdown::check_pkgdown()" "_pkgdown.yml is complete"
    else
      fail_gate "pkgdown::check_pkgdown()" "$log" "_pkgdown.yml check error"
    fi
  fi

  gate_covr
fi

echo ""
echo "## Gate summary"
echo "| Gate | Result | Notes |"
echo "|---|---|---|"
printf "%b" "$SUMMARY"
echo ""
echo "Tree: $(git rev-parse 'HEAD^{tree}')"
echo "Logs: $LOGDIR"
[ "$OVERALL" = "0" ] && echo "ALL GATES PASS" || echo "GATE FAILURE(S) — read only the named log(s)"
exit $OVERALL
