# Review — PR 2 — test/domain-marker-accept-path

**Verdict**: PASS
**Date**: 2026-09-14
**Tree**: `3776b432feb49876de146a0069b74b8d737ac4cb`
**Commit**: `fe3c75c` on `test/domain-marker-accept-path`, base `5b05a8c`

Scope reviewed: `test-spec.md` §2 rows 2.1, 2.2, 2.3 and 2.9. Rows 2.4–2.8
belong to PR 3; §1, §3–§6 and §Existing blocks belong to other PRs. None of
them is reported missing here.

## Convergence checks

- Spec coverage: **y**. The four rows carry every accept-path edge case
  `spec.md` §Function contracts §Edge cases assigns to them — "a logical
  column with some `NA`", "all `NA`", and "a `haven_labelled` column over a
  logical base", plus the plain logical case. The remaining edge-case rows in
  that table are claimed by PR 1 and PR 3 in the plan's row ledger.
- Test coverage of spec: **y**. Each of the four spec edge cases has a
  test-spec row, and each row has a named block in the file.
- Tolerance integrity: **y**. `test-spec.md` §Tolerances puts sections 1 and
  2 outside the tolerance table — they assert classes and structure. Every
  assertion in the four blocks is `expect_no_error(class = )`,
  `expect_identical()`, `expect_true()` or `expect_false()`. No tolerance was
  invented, applied or relaxed. `expect_identical()` on a character class
  vector and on an integer `NA` count follows `testing-standards.md`.
- Scope discipline: **y**. `git diff --name-only 5b05a8c HEAD` returns one
  path, `tests/testthat/test-s7-classes.R`, +55/-0. That equals the plan's
  PR 2 §Files touched exactly. No path under `R/`, `man/`, no `NAMESPACE`
  change, no `_snaps/` entry, and no production behaviour.
- Regression safety: **y**. FAIL 0, WARN 256 (flat), SKIP 4 (flat), PASS
  11795 → 11805. No test outside this PR's scope changed state.

## Findings

**1. The four rows are not vacuous, though not for the reason the plan
gives.** The plan's task 2 concedes that an accept row passes with or without
the validator, and that is true of the `expect_no_error()` line alone. Two
things carry real weight anyway.

- The assertion form is capable of failing. `testthat:::expect_no_` calls
  `fail()` whenever `cnd_matcher("error", class)` matches a caught condition,
  so a validator that rejected a legal logical column would fail all four
  blocks and name the class. `implementation.md` §Notes for tester records
  the control run that demonstrates this with an integer column.
- Three of the four blocks assert a second, always-live observable. Rows
  2.1–2.3 read the stored column back and assert its content (identity with
  `mask`, one surviving `NA`, all `NA`). Row 2.9 asserts the `@data` setter
  stripped the `haven_labelled` class. Those assertions hold or fail
  independently of whether the validator exists.

Together with PR 1's rows 1.1–1.4, which prove the check fires, the four rows
pin the boundary of the check rather than its existence. That is the accept
half of the contract `spec.md` §Class and design support states.

**2. The assertion form is correct — confirmed independently.** I read the
installed testthat 3.3.2 source rather than taking the tester's word.
`cnd_matcher(base_class, class)` returns `FALSE` unless the condition
inherits **both** `"error"` and the named class. `expect_no_`'s calling
handler returns early for any condition the matcher rejects: it neither
muffles it nor records it in `first_match`. So the suite's 256 pre-existing
AAPOR warnings cannot fail these blocks, and an unrelated error would
propagate as an uncaught error in its own right — it cannot turn into a
silent pass. This is exactly what `test-spec.md` §2 asks for: "no condition
of class X", not the absence of every condition. A bare
`expect_no_condition()` would have been wrong.

**3. The PR 3 seam is clean and findable.** Row 2.3's block closes at line
1868. Line 1870 reads
`# PR 3 inserts rows 2.4-2.8 here, between row 2.3 above and row 2.9 below.`
Row 2.9 runs 1872–1889 and is the last block in the file (the file is 1889
lines). §2 therefore reads 2.1, 2.2, 2.3, then the seam, then 2.9 — the
ascending order the plan's §"Why PR 2 runs before PR 3" promised, with the
insertion point named for PR 3's builder.

**4. Row 2.9 asserts both observables, and it ran.** The block wraps the
write in `expect_no_error(..., class = "surveycore_error_domain_not_logical")`
and then asserts `is.logical(stored)`, `identical(class(stored), "logical")`
and `!inherits(stored, "haven_labelled")`. The expectation delta corroborates
that it executed: 2+2+2+4 = 10, which matches the observed +10. Had the
`skip_if_not_installed("haven")` fired, the full suite would read +6 PASS and
SKIP 5; it read +10 and SKIP 4. The targeted run's SKIP 0 agrees.

**5. The helper is untouched.** `helper-test-data.R` appears in no diff.
`set_domain_marker()`'s `"logical"` branch is `logical = mask`, which writes
the column as given, so row 2.9's inline `structure()` column reaches the
write with its class intact and needs no seventh type. That matches D19 and
`testing-standards.md` on edge-case data built in the block. PR 3 reads the
same helper unchanged.

**6. The `test_invariants()` count did not move.** `grep -c` returns 7 on both
`5b05a8c` and `fe3c75c` — six calls plus one test description string. Plan
criterion 4 holds. The pre-existing replicate/two-phase gap `test-spec.md`
§Invariants records was correctly left alone.

## Cross-consistency notes

`implementation.md` and `audit.md` agree on every fact I can check against the
tree: the write surface, the block line numbers (1839, 1849, 1860, 1872–1889),
the assertion form, the seam comment, the untouched helper, and the invariant
count. No disagreement.

Two caveats the audit records, both correct and neither a gap:

- Coverage held flat at 96.14% against a 96.14% baseline, above the 95% floor.
  This PR changes zero lines under `R/`, so there are no new lines whose
  coverage could drop. The coverage log's "changed R/ files: 1" column is the
  stale local `develop` ref of [[D22]]; `origin/develop...HEAD` gives zero R/
  files. [[D21]] explains why validator-closure lines read uncovered at all.
- The two `R CMD check` NOTEs are `CRAN incoming feasibility` (pre-approved,
  `r-package-conventions.md`) and the pre-existing `.git` hidden-files note.
  No new NOTE pattern.

One minor observation, not blocking and identical to PR 1's: `audit.md`
§Profile gates carries no row for gate 12 (`air format --check`). Gate 12 is
not one of the profile's seven gates, and `implementation.md` §Measurements
records exit 0 on the one touched file.

## Decision

All four in-scope rows are present, each in its own block, each asserting the
form `test-spec.md` §2 requires, and all four pass. The load-bearing claim of
this PR — that `expect_no_error(class = )` suppresses only the named error
class — holds against the testthat 3.3.2 source. The write surface equals the
plan's single file, no production code or helper moved, and the seam for
PR 3's rows 2.4–2.8 is marked in place. The seven profile gates each carry a
result, the CRAN cookbook scan is clean, and the expectation and coverage
deltas are both explained. **PASS.**
