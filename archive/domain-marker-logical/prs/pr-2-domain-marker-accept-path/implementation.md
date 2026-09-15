# implementation.md — PR 2: `test/domain-marker-accept-path`

**Branch**: `test/domain-marker-accept-path`
**Base**: `5b05a8c` (develop tip, contains PR 1)
**Commit**: `fe3c75c`

## Write surface

Modified:

- `tests/testthat/test-s7-classes.R` (+55 lines, no deletions)

Created: none. Deleted: none.

`git diff --stat 5b05a8c` lists that one path. No file under `R/` or `man/`
changed, and `NAMESPACE` is unchanged.

## Summary

- Added four accept-path blocks to `tests/testthat/test-s7-classes.R`, below
  PR 1's four reject blocks, under the new section comment
  `Accept path: a logical marker column passes, whatever its NA content`.
  Each builds a Taylor design with `make_all_designs(seed = 7L)$taylor` and
  writes the marker through `set_domain_marker(design, "logical", mask = ...)`.
- Rows 2.1–2.3 cover a logical mask with no `NA`, a mask holding one `NA`, and
  an all-`NA` mask. Each also asserts the stored column reads back with the
  content it was written with, so the block fails if the write silently drops.
- Row 2.9 builds the `haven_labelled` column inside the block with
  `structure(mask, labels = c(...), class = "haven_labelled")` and hands it to
  the helper as `mask` with `type = "logical"`. It asserts the stored column is
  logical, that `class()` is exactly `"logical"`, and that it does not inherit
  `haven_labelled` — the `@data` setter strips the class before the validator
  runs.
- Every block asserts with `expect_no_error(expr, class =
  "surveycore_error_domain_not_logical")`. The `class` argument scopes the
  check to that one class, so an unrelated warning does not fail a block.
- `set_domain_marker()` in `helper-test-data.R` is unchanged: no new type, no
  new argument. The `test_invariants()` call count in the file is unchanged —
  `grep -c` still returns 7 lines, of which six are calls and one is a test
  description string.

## Task checklist

- [x] 1. Accept-path blocks for rows 2.1–2.3, one each, below PR 1's reject
      blocks, each writing through `set_domain_marker()` and asserting the
      absence of `surveycore_error_domain_not_logical` only.
- [x] 2. Ran them. All pass.
- [x] 3. Row 2.9's block after 2.3, `skip_if_not_installed("haven")` on its
      first line, the column built in the block, handed over as `mask` with
      `type` `"logical"`. Helper untouched.
- [x] 4. Row 2.9 asserts both things: no
      `surveycore_error_domain_not_logical` on the write, and a plain logical
      column with no `haven_labelled` class on read-back.
- [x] 5. No new `test_invariants()` call.
- [x] 6. §2 sits in ascending order — 2.1, 2.2, 2.3, then 2.9 — with the seam
      marked by the comment
      `# PR 3 inserts rows 2.4-2.8 here, between row 2.3 above and row 2.9 below.`

## Measurements

| Check | Command | Result |
|---|---|---|
| Test file | `Rscript -e 'devtools::test(filter = "s7-classes")'` | `FAIL 0 \| WARN 0 \| SKIP 0 \| PASS 294` |
| Formatting | `air format --check tests/testthat/test-s7-classes.R` | exit 0 |
| Write surface | `git diff --stat 5b05a8c` | one path, `tests/testthat/test-s7-classes.R` |
| Invariant calls | `grep -c "test_invariants(" tests/testthat/test-s7-classes.R` | 7 lines, six of them calls — unchanged |

No full-suite run, no `R CMD check`, no `covr`, per the dispatch's gate
discipline. No roxygen changed, so `devtools::document()` did not run.

## HOLDs

None.

## Notes for tester

- The installed `surveycore` in this environment is stale: it predates PR 1 and
  carries no `survey_base` validator. A check run with `library(surveycore)`
  instead of `pkgload::load_all()` sees no abort at all. `devtools::test()` and
  `testthat::test_local()` both load the source, so the suite is unaffected.
  This bit once while confirming the assertion form is not vacuous.
- That confirmation ran outside the suite and is not committed: with the source
  loaded, `expect_no_error(set_domain_marker(d, "integer"), class =
  "surveycore_error_domain_not_logical")` fails and names the class, so the
  four accept blocks would catch an over-firing validator.
- `make_all_designs(seed = 7L)$taylor` carries 100 rows, so every mask in these
  blocks has length 100.
