# fix(pipeline): gate 1 compares man/ before and after document()

**Date**: 2026-09-09
**Branch**: JDenn0514/run-gates.sh-gate-1-reports-document-drift-for-a
**Issue**: #233
**Phase**: Tooling (no package code)

## Changes

- Gate 1 in `.claude/scripts/run-gates.sh` hashed nothing. It ran
  `devtools::document()` and then asked `git diff --quiet -- NAMESPACE man/`,
  which compares the working tree against `HEAD`.
- The gate asks one question: did the builder forget `document()`? The
  evidence is whether `document()` writes a file during the run. A diff
  against `HEAD` answers a different question, and the two agree only on a
  committed tree. Every pipeline run measures the gates before the shipper
  commits, so a builder who regenerated an `.Rd` correctly left it
  uncommitted and the gate failed. PR #232 hit this: one roxygen line and
  its man page, gate 1 FAIL, every other gate PASS.
- Gate 1 now hashes `NAMESPACE` and `man/` before and after the
  `document()` call and compares the two snapshots. Hashing the file list,
  not only the contents, also catches an added or a deleted `.Rd`. On a
  mismatch the log names the files that changed.
- `r-package-profile.md` row 1 now states the test as "byte-identical
  before and after the run", so the table cannot be read as a diff against
  `HEAD` again.

Measured on this branch. A roxygen edit with its regenerated `.Rd`, both
uncommitted, passes and the runner exits 0; the old test failed the same
tree. The same roxygen edit with a stale `.Rd` fails, and a deleted `.Rd`
fails.

## Files Modified

- `.claude/scripts/run-gates.sh` — gate 1 snapshot comparison
- `.claude/skills/pipeline-shared/references/r-package-profile.md` — gate 1 row
