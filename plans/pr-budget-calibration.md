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
| 2026-09-09 | #259 | 18 | 441 | 24.5 | 0 | 0 | — |
| 2026-09-10 | #263 | — | 162 | — | 0 | 0 | — |
| 2026-09-10 | #266 | 11 | 384 | 34.9 | 1 | 0 | — |
| 2026-09-10 | #267 | 11 | 119 | 10.8 | 0 | 0 | — |
| 2026-09-11 | #268 | 11 | 272 | 24.7 | 0 | 0 | — |
| 2026-09-11 | #269 | 10 | 336 | 33.6 | 1 | 0 | — |
| 2026-09-11 | #270 | — | 58 | — | 0 | 0 | — |

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

## The sixth row — the first over-bound PR to draw no BLOCK

**#259** — as-svydesign-bridge, the whole feature in one PR. 18 stated rows
against the bound of 12, 441 additions, 24.5 additions per row, no tester
BLOCK and no reviewer BLOCK.

Three things this row settles or fails to settle.

**The row overage was real and it cost nothing.** The user instructed one PR
twice, and decision D-8's original reason — two issues rewriting one dispatch
chain — was gone by the time the plan was written, because D-9 moved the second
issue to another arc. So the PR carried 18 rows for reasons of instruction
rather than coupling, and it still passed the tester and the reviewer on the
first pass. #241 was the only earlier over-bound row, at 15, and it also drew
no BLOCK. Two over-bound PRs, zero BLOCKs between them. The bound of 12 has now
been exceeded twice with no measured penalty.

**Additions per row fell below the band.** The five earlier rows sit between
24.8 and 39.9. This one reads 24.5, just under the floor. The full merge diff
was 733 insertions across eight files; the 441 figure is the hand-written
surface the ledger metric defines — `R` and `tests` with `_snaps` excluded —
so `changelog/fix-as-svydesign-bridge.md` at 145 lines, the two `man/` pages at
71, `plans/error-messages.md` at 26, the vignette at 31 and the snapshot file
at 19 are all outside it. A documentation-heavy PR therefore reads leaner per
row than it is. Six rows is still too few to redefine the band.

**Six rows of twenty.** The schema's re-derivation threshold is 20. This is
row 6, and all six come from two features by one author on one machine, so the
bound still rests on the haven-labelled calibration rather than on this ledger.

`Follow-up fixes` starts as `—` and is not knowable at merge time. Four issues
this feature deliberately deferred are the places a follow-up would land:
**#245** the dropped domain restriction, **#246** the consolidation of the
eighth copy of the nonprob routing predicate, **#248** the class-validator
row-count loophole, and **#251** two documentation corrections that had to wait
for the warning they describe. None is a fix to #259; each was recorded as
out of scope before the build. Read them as scope decisions, not as debt this
row created.

- **#263** — not a PR of any implementation plan, so it has no test-spec row
  count and no additions-per-row figure. It exists because PR 1 of the
  `as-svydesign-domain` arc raised a HOLD: test-spec row A-4 required SE parity
  with `survey` on a `survey_nonprob` design, and a pre-existing defect in
  `.calibrated_mean_cell()` made that parity impossible. The user chose to fix
  the defect, and it shipped ahead of PR 1 so that row A-4 became true as
  written and no frozen artifact had to be amended. Both BLOCK counts are 0:
  the gates passed on the first run and the reviewer passed on its first
  review. Two HOLDs sit behind the row and neither was a BLOCK — the PR 1 HOLD
  that created this PR, and a builder HOLD on a one-row domain, deferred as
  D17 and filed as #265. The row is excluded from any re-derivation of the row
  bound, since a PR with no stated row count cannot inform a per-row figure.

- **#266** — as-svydesign-domain PR 1 of 5. 11 stated rows, inside the bound of
  12, and 384 additions. One tester BLOCK: the unfiltered-Taylor row asserted
  two of the three things the test-spec's section C preamble requires, missing
  "the call raises no condition", so a warning there would have passed
  undetected. The requirement sits in the section preamble rather than in the
  row's own table cell, which is why a row-by-row reading missed it and a
  reader working only from the test-spec caught it. Fixed in one commit and
  re-audited to 11 of 11. Zero reviewer BLOCKs. The PR also carries four
  marker-column blocks the plan had allocated to PR 2; the reviewer ruled that
  benign, because PR 2's write surface is the same test file and can extend
  them, unlike the issue #165 case where the later PR was locked out of the
  file. PR 1 depended on #263, which had to land first for row A-4's standard
  error parity to be satisfiable at all.

- **#267** — as-svydesign-domain PR 2 of 5, tests only. 11 stated rows and 119
  additions, the lowest additions-per-row figure in the ledger at 10.8. That
  figure is misleading as evidence for the bound: five of the eleven rows were
  already satisfied by blocks that shipped inside #266, whose builder wrote
  them without being able to see the row ledger. Counting only the rows this
  pull request actually implemented — six, including finishing one that #266
  left half covered — gives about 20 additions per row, in line with the rest
  of the ledger. Both BLOCK counts are 0. The half-covered row is the one worth
  remembering: #266's marker-type loop asserted the selected row count and that
  no condition fires, and both of those pass on a converted object whose
  probability vector is corrupt, so the row guarded nothing until #267 added
  the finite-probability assertion.
- **#268** — as-svydesign-domain PR 3 of 5. 11 stated rows and 272 additions,
  24.7 per row, inside the bound of 12. The production diff is four lines: one
  call site in the replicate route. The other 268 additions are 13 test blocks
  and two fixtures. Both BLOCK counts are 0 and both stages passed on the first
  pass. Two of the eleven rows cover input shapes that reach an existing call
  site with no new code (the two `survey_nonprob` shapes), so the row count
  overstates the production surface and the additions-per-row figure is a test
  figure. The reviewer counted 13 blocks where implementation.md said 14; the
  file holds 13.
- **#269** — as-svydesign-domain PR 4 of 5, the two-phase route. 10 stated
  rows and 336 additions, 33.6 per row, inside the bound of 12. Tester BLOCKs
  1, reviewer BLOCKs 0. The BLOCK was a contract miss on three edge-case
  blocks: they wrapped the conversion in `suppressWarnings()` and asserted
  nothing about conditions where the rows require "no surveycore condition".
  The fix added one collector helper and 17 net lines. The production diff is
  21 lines: a frame branch inside the helper, one call site, one comment
  paragraph. This is the arc's judgment-heavy PR — the route removes no row
  and applies the domain by infinite probability, and one block pins the
  pre-existing estimator gap (issue #261) so the row fails if it moves — and
  it drew the arc's only tester BLOCK after PR 1's. The row count predicted
  the size well; the BLOCK came from an assertion left implicit, not from
  scope.
- **#270** — as-svydesign-domain PR 5 of 5, documentation only. No test-spec
  row by design, so `Rows` and `Adds/row` are `—`, as for #263. 58 additions,
  all roxygen in one `R/` file; the regenerated `man/` page and the changelog
  entry sit outside the counted surface. Both BLOCK counts are 0. The arc's
  five PRs together: 43 stated rows, 1169 counted additions, one tester BLOCK
  (#269) and no reviewer BLOCK.
