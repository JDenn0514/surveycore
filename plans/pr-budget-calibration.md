# PR budget calibration ledger

One row per merged pull request. `pipeline-ship` appends a row at Step 3, after
the merge, when the real diff is knowable. Schema:
`.claude/skills/pipeline-shared/references/artifact-schemas.md`
§PR budget calibration ledger.

Additions count the hand-written surface only — `R` and `tests`, excluding
`tests/testthat/_snaps`. `Follow-up fixes` cannot be known at merge time, so it
starts as `—` and is backfilled before the bound is re-derived. Count only a
later pull request that changed behaviour, not one that changed bookkeeping.

The bound under test is 12 test-spec rows per pull request, derived from seven
pull requests of one feature. Re-derive it once this ledger holds 20 rows.

| Merged | PR | Rows | Additions | Adds/row | Tester BLOCKs | Reviewer BLOCKs | Follow-up fixes |
|---|---|---|---|---|---|---|---|
| 2026-09-08 | #239 | 10 | 349 | 34.9 | 0 | 0 | — |
| 2026-09-08 | #241 | 15 | 514 | 34.3 | 0 | 0 | — |
| 2026-09-08 | #247 | 10 | 333 | 33.3 | 0 | 0 | — |
| 2026-09-08 | #249 | 11 | 273 | 24.8 | 0 | 0 | — |
| 2026-09-08 | #250 | 12 | 479 | 39.9 | 1 | 1 | — |

## Notes on individual rows

- **#239** — svydesign-replicate-bridge PR 1 of 5. The row count comes from the
  implementation plan's own allocation (rows I-3 to I-11 and I-21). The pull
  request was drafted before the row bound existed, so it is evidence for
  re-deriving the bound, not a pull request the bound governed. Both BLOCK
  counts are 0: the tester passed on its first audit and the reviewer passed on
  its first review. Test-spec row identities were deliberately stripped from
  the builder's task list for this run (`decisions.md` D11), so the stated row
  count is the plan's allocation rather than a count of row-named test blocks
  in the merged file.

- **#241** — svydesign-replicate-bridge PR 2 of 5. 15 stated rows, three above
  the bound of 12 that arrived mid-run in `c21f9a5`; the plan was frozen at
  PLAN_READY before that bound existed, so this row is evidence for
  re-deriving it rather than a breach of it. Both BLOCK counts are 0. The
  additions figure excludes `man/from_svydesign.Rd`, per the schema's `R` and
  `tests` scope; the full diff was 539 insertions across three files.

- **#247** — svydesign-replicate-bridge PR 3 of 5. Inside the bound of 12 at
  10 rows. Both BLOCK counts are 0. The additions figure excludes the 36 lines
  added to `plans/error-messages.md` and the 41 in
  `tests/testthat/_snaps/conversion.md`, per the schema's `R` and `tests` scope
  with `_snaps` excluded; the full diff was 410 insertions across four files.
  This pull request added four condition classes and created the snapshot file,
  so its additions are weighted toward tests rather than source: 216 of the 333
  are test blocks.

- **#249** — svydesign-replicate-bridge PR 4 of 5, the first on the export
  route. Inside the bound at 11 rows. Both BLOCK counts are 0. Additions
  exclude the 11 lines in `plans/error-messages.md` and the 21 in
  `tests/testthat/_snaps/conversion.md`; the full diff was 301 insertions and
  10 deletions across four files. This is the only row so far with deletions —
  the `fpc` and `fpctype` arguments and the unused local `fpctype` value were
  removed from the export call.

- **#250** — svydesign-replicate-bridge PR 5 of 5, the only one to take a
  BLOCK. One from the tester, for a duplicate `test_invariants()` call, and one
  from the reviewer, for a test-spec row that had no committed block on the
  last pull request of the change. Both fixes were test-only. Additions exclude
  `plans/error-messages.md` and the `_snaps` file; the full diff was 440
  insertions and 4 deletions across four files, over three commits squashed
  into one.

  The reviewer's BLOCK is partly an artifact of this run's own process: the
  leader relayed the tester's non-blocking gap to the builder as a behavioural
  description instead of a row id (D11) and described the wrong behaviour, so
  the first fix guarded a different case. That is a cost of stripping row ids,
  not a builder error, and it is the one place in five pull requests where the
  D11 barrier produced a defect rather than preventing one.

## Reading the five rows

Additions per stated row sit between 24.8 and 39.9 across all five, which is a
narrow band. Nothing here supports or refutes the bound of 12 on its own: four
of the five were inside it and the one that was not (#241, at 15 rows) drew no
BLOCK. The two BLOCKs both landed on the LAST pull request, which is where the
"a row is uncovered and there is no later pull request to carry it" failure
mode lives — a position effect, not a size effect.
