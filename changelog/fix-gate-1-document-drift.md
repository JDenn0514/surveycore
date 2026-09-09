# Changelog: fix/gate-1-document-drift

**Branch:** `JDenn0514/run-gates.sh-gate-1-reports-document-drift-for-a`
**Status:** Complete
**Date:** 2026-09-09
**PRs:** #252
**Issues:** #233

## Summary

Closes #233. Gate 1 in `.claude/scripts/run-gates.sh` ran
`devtools::document()` and then asked `git diff --quiet -- NAMESPACE man/`.
That compares the working tree against `HEAD`, so it reported every
uncommitted change under `man/` or to `NAMESPACE`, whoever made it. It never
asked whether `document()` wrote anything.

The gate asks one question: did the builder forget `document()`? The evidence
is whether `document()` writes a file during the run. A diff against `HEAD`
answers a different question, and the two agree only on a committed tree.
Every pipeline run measures the gates before the shipper commits, so a
builder who regenerated an `.Rd` correctly left it uncommitted and the gate
failed. PR #232 hit this: one roxygen line and its man page, gate 1 FAIL,
all six other gates PASS.

Gate 1 now hashes `NAMESPACE` and `man/` before and after the `document()`
call and compares the two snapshots. Hashing the file list, not only the
contents, also catches an added or a deleted `.Rd`. On a mismatch the log
names the files that changed.

## Files Modified

- `.claude/scripts/run-gates.sh` — gate 1 compares a before-and-after hash
  snapshot of `NAMESPACE` and `man/` in place of a diff against `HEAD`
- `.claude/skills/pipeline-shared/references/r-package-profile.md` — row 1
  states the test as byte-identical before and after the run, so the table
  cannot be read as a diff against `HEAD` again

## Changes

- Gate 1 measures whether `document()` wrote a file, rather than whether the
  working tree differs from `HEAD`
- A mismatch writes the list of added, removed or rewritten files to
  `gate-1-document.log`
- The snapshot sorts by path, so a rewritten file reads as one adjacent pair
  in the log diff

## Verification

Measured on the branch. Each row ran the real `document()` call.

| Tree | Gate 1 | Old test |
|---|---|---|
| Roxygen line edited, `.Rd` regenerated, both uncommitted | PASS, exit 0 | FAIL (`man/get_corr.Rd | 2 +-`) |
| Same roxygen edit, `.Rd` restored from `HEAD` | FAIL, exit 1 | — |
| `man/get_corr.Rd` deleted, roxygen unchanged | FAIL, exit 1 | — |
| Clean tree | PASS, exit 0 | PASS |

Rows 1 to 3 are the three acceptance criteria in issue #233. The test edits
to `R/analysis-corr.R` and `man/` were reverted before the commit.
