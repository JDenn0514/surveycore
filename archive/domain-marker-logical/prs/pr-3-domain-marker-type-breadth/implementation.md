# implementation.md — PR 3 `test/domain-marker-type-breadth`

**Branch**: `test/domain-marker-type-breadth`
**Base**: `a5b88c2` (develop tip, carries PRs 1 and 2 of this arc)
**Commit**: `a830880` — `test(classes): widen the domain marker type and shape coverage`

## Write surface

Created: none.
Deleted: none.
Modified:

- `tests/testthat/test-s7-classes.R` (+132 / -1)

`git diff --stat a5b88c2 HEAD` lists that one path and nothing else. No file
under `R/`, `man/`, or `NAMESPACE` differs.

## Summary

- Added seven reject blocks for the `survey_base` domain marker validator:
  a double, a character, a factor and a list column on a Taylor design
  (each through `set_domain_marker()`); a data frame already carrying an
  integer marker column passed to the Taylor constructor and to the
  non-probability constructor; and an `integer(0)` column on a zero-row
  frame. Each asserts
  `expect_error(class = "surveycore_error_domain_not_logical")` and writes
  no snapshot, per the Layer 1 rule.
- Added the rollback block: a failed `@data` assignment on the design object
  itself leaves the design without the marker column. The write goes through
  `design@data <- new_data` rather than the helper, so the failed write
  targets the object the assertion then reads.
- Added four accept blocks: an all-`NA` logical marker on a replicate
  design; a logical column carrying a `label` attribute, with the attribute
  read back after the write; a `logical(0)` column on a zero-row frame; and
  a two-phase write that leaves the design's own `subset` column identical.
- Built both zero-row frames inline in their blocks, as
  `design@data[0L, , drop = FALSE]`, and added no parameter to any generator.
  `set_domain_marker()` was not edited — its default mask is
  `rep(c(TRUE, FALSE), length.out = 0)` on a zero-row design, which already
  yields `logical(0)` and `integer(0)` for the two shapes.
- Placed the section 2 blocks at PR 2's marker comment, so the file reads
  2.1 to 2.9 in ascending order; the section 1 blocks sit with PR 1's.

## Task checklist

- [x] 1. Rows 1.5 (double), 1.6 (character), 1.7 (factor), 1.8 (list), each
      on a Taylor design through `set_domain_marker()`.
- [x] 2. Vacuity check over rows 1.5–1.8 — see below.
- [x] 3. Rows 1.9 (Taylor constructor) and 1.10 (non-probability
      constructor), each on a data frame already carrying an integer marker.
- [x] 4. Row 1.11 — the failed assignment leaves no marker column.
- [x] 5. Rows 2.4 (replicate, all `NA`), 2.5 (`label` attribute survives)
      and 2.8 (two-phase, one `NA`, subset column untouched), placed between
      row 2.3 and row 2.9.
- [x] 6. Rows 2.6 (`logical(0)`) and 2.7 (`integer(0)`), zero-row frames
      built inline, assertion on the named class only.
- [x] 7. Vacuity check re-run over rows 2.7, 1.9 and 1.10.
- [x] 8. Gates: the dispatch reserved every gate suite to the orchestrator
      under the memory limit. `devtools::test(filter = "s7-classes")` ran
      instead, plus `air format --check` on the one touched file. See
      Measurements.

## Vacuity check and the state of `R/`

Recorded before the first edit: `git rev-parse HEAD:R/core-classes.R` =
`dddb0b19b0902166d21807e343d3f0e978cf8753`.

The check disabled the validator's type test in `R/core-classes.R` by
replacing the condition `if (!is.logical(self@data[[SURVEYCORE_DOMAIN_COL]]))`
with `if (FALSE)`, then ran the file with `testthat::set_max_fails(Inf)`.

Result: `[ FAIL 13 | WARN 0 | SKIP 0 | PASS 301 ]`. All ten section 1 reject
blocks failed (PR 1's rows 1.1–1.4 and this PR's 1.5–1.10), row 1.11 failed
twice — once on its `expect_error()` and once on its `expect_false()` — and
row 2.7 failed at line 1983. Every reject block this PR adds therefore
depends on the check, and none of them is vacuous. The first run of the
check hit testthat's default failure cap at ten, which is why the second run
lifted the cap.

Restored with `git checkout -- R/core-classes.R`, not by hand. After
restoration and again immediately before writing this file:

- `git rev-parse HEAD:R/core-classes.R` = `dddb0b19b0902166d21807e343d3f0e978cf8753`, unchanged.
- `git status --porcelain R/` prints nothing.
- `git diff --stat HEAD -- R/` prints nothing.

Nothing was staged or committed while the file was modified. The commit
staged one explicit path, `tests/testthat/test-s7-classes.R`.

## Measurements

| Run | Result |
|---|---|
| `devtools::test(filter = "s7-classes")`, validator intact | `[ FAIL 0 \| WARN 0 \| SKIP 0 \| PASS 314 ]` |
| Same, validator's type test disabled | `[ FAIL 13 \| WARN 0 \| SKIP 0 \| PASS 301 ]` |
| `air format --check tests/testthat/test-s7-classes.R` | exit 0 |
| `git status --porcelain` after the commit | empty |
| `grep -c "test_invariants(" tests/testthat/test-s7-classes.R` | 7 — six calls plus one description string, unchanged |

`tests/testthat/_snaps/` gained no entry: `git status --porcelain` is empty
and the commit touches one file.

## HOLDs

None.

## Notes for tester

- Rows 2.6 and 2.7 reach a zero-row design by assigning
  `design@data[0L, , drop = FALSE]` back onto a Taylor design. That
  assignment is legal today: no validator in `R/core-classes.R` tests the
  row count. The "`@data` has at least one row" invariant lives in
  `test_invariants()` in `tests/testthat/helper-test-data.R`, which these two
  blocks do not call. A constructor route to a zero-row design was not used,
  because the Layer 3 constructor checks reject an empty data frame.
- Row 2.5 reads the `label` attribute back with
  `attr(stored, "label", exact = TRUE)`. The `@data` setter's
  `.strip_labelled_columns()` removes the `haven_labelled` class and leaves
  the `label` attribute in place — the same behaviour an existing block at
  the top of this section already asserts for a plain numeric column.
- Row 2.8 reads the two-phase subset column's name from
  `design@variables$subset` rather than hard-coding `"subset"`, so the block
  does not depend on `make_survey_data()`'s column naming.
