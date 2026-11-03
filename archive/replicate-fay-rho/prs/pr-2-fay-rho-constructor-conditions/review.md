# Review — PR 2: fay-rho-constructor-conditions

**Verdict: PASS**

Branch `test/fay-rho-constructor-conditions`, HEAD `46d58f1`, tree
`9afc8f1f50347474d6323afc95b6cccc71a97b5c`, base `6801065` (develop after #301).

The reviewer ran no gate. The evidence is `audit.md`, `gates/summary.txt`,
`gates/gate-5-00check.log`, `gates/gate-7-covr.log` and
`git diff 6801065..HEAD`.

## Checks

| # | Check | Result |
|---|---|---|
| 1 | Convergence | Clean |
| 2 | Tolerance integrity | Clean |
| 3 | Scope discipline | Clean |
| 4 | CRAN cookbook and profile gates | Clean |
| 5 | Coverage floor | Clean |
| 6 | Comprehension alignment | Clean |
| 7 | `audit.md` verdict | PASS |

## 1. Convergence

The plan assigns PR 2 ten rows: §1 1.3, 1.4, 1.4b, 1.6, 1.8, 1.9, 1.12,
1.13 and §6 6.2, 6.3. Each row has a scenario in `test-spec.md` and a row in
the `audit.md` per-test table. I read each new block in the diff against its
row:

- 1.3 and 1.4: one block loops the eight other types on FT. It asserts the
  `rho` key is present and `expect_identical(d@variables$rho, NULL)`. The
  Fay design with `rho = 0.3` asserts the key is present.
- 1.4b: `as_survey_replicate(df, wt, starts_with("repwt_"), "Fay", 0.3)`,
  as the plan writes it.
- 1.6: explicit `rho = NULL`, class only, no snapshot, as the row says.
- 1.8 and task 4: the class assertion and three snapshots in one block. The
  snapshot file shows `<character>: 0.5`, `a value of length 0`, and the
  first five of six values.
- 1.9: all 14 values, in the test-spec order. The block asserts the list
  length is `14L`, so a dropped value turns it red.
- 1.12: `expect_no_warning()` for each of the eight types.
- 1.13: BRR with `rho = "a"`. The block wraps `expect_warning(class =)` in
  `expect_no_error()` and asserts the stored `rho` is `NULL`.
  `expect_warning(class =)` lets a second, unmatched warning through as a
  suite warning. The gate-2 count stayed at 256, so the "only" clause holds.
- 6.2 and 6.3: the diff over both Rd files shows the JOS citation and the
  JASA citation removed. `man/survey_replicate.Rd` lists `rho` in
  `variables` and in the design-variables section.

No block title carries a row id. The diff adds no `test_invariants()` call,
as the test-spec §1 note requires.

## 2. Tolerance integrity

The new blocks hold two numeric `expect_equal()` calls, both in row 1.4b:

- `rho` against 0.3: `tolerance = 1e-10`. Test-spec §Tolerances names no
  row for a stored `rho`. The value is an input copied to storage, and 1e-10
  is the tightest tolerance in the list. It is not looser than any default.
- `scale` against `1 / (20 * (1 - 0.3)^2)`: `tolerance = 1e-8`. This equals
  the test-spec row "Stored scale against its literal: 1e-8".

No other `expect_equal()` is in the diff. The rest of the new assertions are
`expect_identical()`, `expect_true()`, `expect_null()`, class checks and
snapshots. No row uses a looser tolerance.

## 3. Scope discipline

`git diff --stat 6801065..HEAD` lists six files. The plan's PR 2 Files
touched lists the same six. `implementation.md` §Write surface lists the same
six.

- `R/core-constructors.R`: the `@references` roxygen only, three lines to two.
  Task 9 found no PR 1 defect, so the plan's roxygen-only condition holds.
- `R/core-classes.R`: roxygen only.
- `_snaps/constructors.md`: one new entry with three snapshots, and no other
  change. This matches G.8.

The suite shows 0 failures before and after. The pass count rose by 50 and
the warning count held at 256. No test outside this PR changed state.

## 4. CRAN cookbook and profile gates

`audit.md` reports no cookbook violation. The `R/` changes are roxygen
comments only.

All seven gates have a result, recorded on this tree. `gate-5-00check.log`
line 98 reads `Status: 2 NOTEs`. The notes are at line 14, CRAN incoming
feasibility, which is pre-approved, and line 37, the `.git` hidden-file note,
which is pre-existing and accepted by plan G.4. The plan documents the
AAPOR warning baseline (G.2) and the air scope (G.7). The tester's air check
compared formatted copies on develop and HEAD: 58 hunks on each, none in the
PR's lines 1177-1389. No gate was skipped.

## 5. Coverage

Package coverage is 96.16%, against 96.15% before. That is above the 95%
floor and is no drop. The PR's `R/` lines are roxygen only, so no new
executable line exists. `gate-7-covr.log` lists 12 uncovered lines in the
changed files. None is in the diff. PR 1's uncovered `rho_txt` branch, now
line 901, is covered by the new `numeric(0)` snapshot.

## 6. Comprehension alignment

The `comprehension.md` gotchas that reach PR 2 have tests here:

- the type of `rho` (`TRUE`, `NA_real_`, `Inf`, a length-2 vector): row 1.9;
- values out of range (`-0.1`, `1`): row 1.9;
- no warning when a non-Fay type gets no `rho` (D8): row 1.12;
- `rho` on a non-Fay type is warned about and not checked: row 1.13.

The PR 1 review found the run-wide mapping clean. This PR adds no new
assumption.

## Notes, not blocking

- Four new block titles are longer than 80 columns. Existing titles in the
  same file do the same, and `air` does not rewrap strings.
