# Implementation — PR 3 — replicate-scale-frame-and-type-tests

## Write surface

- `tests/testthat/test-constructors.R` — modified (+260 lines, 6 new blocks)

Nothing else changed. `git status --porcelain` reports one entry. The `R`
subtree hash is `164f0348ba796fb5af5192b8b8cd6a3d260f0099` at both the base
`e727001` and the head of this branch.

## Summary

- Six blocks were added. Five sit with PR 2's scale blocks, after the
  `rscales = NULL` block: the two-row frame, the five refusals, the nine-type
  table, the all-`NA` outcome frame, and the mixed zero-weight frame. The sixth
  sits after `as_survey_twophase() accepts survey_replicate phase-1`, so that
  block keeps the file's single `test_invariants()` call for that constructor.
- The two-row block builds the smallest frame the constructor accepts, with 20
  replicate columns, and asserts that it stores the same two values as the
  200-row, 20-column frame above it: `1` for JKn and `1/19` for the bootstrap.
  The frame is built inline.
- The nine-type block builds one design per `type` on one 20-replicate frame
  with no `scale` and asserts nine stored values against the nine literals in
  `spec.md` §Default scale table, After column. Every assertion sits on its own
  line, so a mutation names exactly one of them.
- The refusals block asserts five classes, each by `class =` and with no
  snapshot. The all-`NA` frame and the mixed zero-weight frame are built inline,
  as are the five refusal frames. Frame content is the thing under test in each.
- The two-phase block asserts `@variables$phase1$scale` for both changed types,
  each against its own literal at `tolerance = 1e-8`, never one against the
  other. It adds no `test_invariants()` call; the file's count stays at 4.

## Task checklist

- [x] 1. Cut the branch. The worktree opened on `main` at `d4d1db2`; it was
  reset to `e727001`, tree `b8b26ae`, before any work began. Baseline
  `[ FAIL 0 | WARN 256 | SKIP 4 | PASS 12028 ]` was taken from the dispatch.
- [x] 2. Row 1.6. The frame block and five refusals are written and pass. The
  frame carries two rows and not one — see §Erratum E-7 below.
- [x] 3. Row 1.7. The nine values were transcribed from `spec.md` §Default
  scale table, After column. `test-spec.md` was not read.
- [x] 4. Mutation-check row 1.7. Results below.
- [x] 5. Row 1.8. Both frames written inline, both blocks pass.
- [x] 6. Row 1.9. Written, passes, adds no `test_invariants()` call.
- [x] 7. Mutation-check row 1.9. Results below.
- [x] 8. `git status` shows no change under `R/` and none under
  `tests/testthat/_snaps/`.
- [x] 9. Full suite run. The heavy gates belong to the orchestrating skill.

## Erratum E-7 — the single-row frame, and how row 1.6 resolves it

Acceptance criterion 1 and `spec.md` §Edge cases E7 both call for a one-row
frame that builds. The constructor refuses one:

```
Error: `data` has only 1 row. A survey design requires at least 2
observations.
class: surveycore_error_single_row
```

The guard is `.validate_data()` Error 4 at `R/core-validators.R:100-112`. It is
not new and not a defect of this arc: it carries row 4 of
`plans/error-messages.md`, it has shipped since `6c8896b` (PR #76), and it is
already pinned for this constructor at
`tests/testthat/test-constructors.R:1135`, in a block whose comment reads
"matches survey package behavior". E7's claim that a single-row frame "reach[es]
the same stored `scale` as any other frame" is false, and §Errors and warnings
omits the class from its list of five.

This was raised as HOLD-1 and the coordinator resolved it as erratum E-7, with
both corrections applied rather than one.

**Correction 1 — row 1.6's frame carries two rows.** The property the row
exists to test is that the stored default depends only on `type` and `R` and on
nothing in the data. A two-row frame tests that exactly as well as a one-row
frame would, and unlike a one-row frame it can be constructed. Criterion 1
keeps its claim intact: at R = 20 the smallest buildable frame stores `1` and
`1/19`, which are the two values the 20-column frame stores. Both were
measured.

**Correction 2 — the single-row refusal joins the refusals block as a fifth
class.** It belongs in that group and the spec's table should have carried it.
It is asserted by `class = "surveycore_error_single_row"` with no snapshot, and
it uses `type = "bootstrap"` rather than the `"JK1"` of the block at line 1135,
so the two are not duplicates. A comment records why: `.validate_data()` raises
Error 4 ahead of the switch, so the refusal is type-independent and the two
blocks reach one guard from two types.

## Mutation results

Each switch line in `R/core-constructors.R` was set back to its pre-#253 value
with the `Edit` tool, the file was run, and the line was reverted with
`git checkout --`. `sed` was not used, so no CRLF rewrite occurred. The run
below is the second one, taken after the E-7 blocks landed; line numbers are
those of the final file.

**Mutation A — `JKn = 1,` (line 851) set to `JKn = (n_rep - 1L) / n_rep,`.**
11 assertions reddened.

| Line | Block | Assertion |
|---|---|---|
| 727, 730, 733, 736 | PR 2, defaults rise by R/(R-1) | pre-existing |
| 767 | PR 2, non-uniform rscales | pre-existing |
| 809 | PR 2, one and two replicate columns | pre-existing |
| 861 | PR 2, `rscales = NULL` | pre-existing |
| **899** | **two-row frame** | **`d_jkn@variables$scale`** |
| **999** | **nine-type table** | **`stored("JKn")` — one of nine** |
| 1042 | all-`NA` outcome frame | `d_jkn@variables$scale` |
| **1649** | **two-phase** | **`tp_jkn@variables$phase1$scale`** |

**Mutation B — `bootstrap = 1 / (n_rep - 1L),` (line 861) set to
`bootstrap = 1 / n_rep,`.** 12 assertions reddened.

| Line | Block | Assertion |
|---|---|---|
| 691, 728, 731, 734, 741 | PR 2 blocks | pre-existing |
| 790, 800, 801 | PR 2, one and two replicate columns | pre-existing |
| **900** | **two-row frame** | **`d_boot@variables$scale`** |
| **1002** | **nine-type table** | **`stored("bootstrap")` — one of nine** |
| 1043 | all-`NA` outcome frame | `d_boot@variables$scale` |
| **1650** | **two-phase** | **`tp_boot@variables$phase1$scale`** |

Every required property holds.

- Row 1.7: exactly one of the nine assertions reddened under each mutation, and
  the two are different assertions (999 against 1002). The other seven types
  stayed green under both, so no assertion in the block is load-bearing for
  more than its own type.
- Row 1.6: the two-row block's two scale assertions reddened one per mutation
  and did not overlap (899 against 900), so neither is vacuous. The block
  therefore tests the stored default on the smallest buildable frame and not
  merely that the frame builds.
- Row 1.9: the matching two-phase assertion reddened under each mutation, and
  only the matching one. This is the evidence that
  `variables$phase1 <- phase1@variables` at `R/core-constructors.R:1199` carries
  the value across rather than recomputing it — a recomputing copy would have
  stayed green.
- The refusals block and the mixed zero-weight block stayed green under both
  mutations, which is correct: every refusal fires before the switch.
- The PR 2 counts reproduce that commit's own record, 7 red under the JKn
  mutation and 8 under the bootstrap mutation, with no overlap.

## Verification

- `devtools::test(filter = "constructors")`, unmutated:
  `[ FAIL 0 | WARN 16 | SKIP 0 | PASS 756 ]`.
- Full suite: `[ FAIL 0 | WARN 256 | SKIP 4 | PASS 12065 ]`. The warning count
  is unchanged from the `e727001` baseline, so the PR adds no warning. Passes
  rise by 37.
- `test_invariants(` appears 4 times in the file, unchanged.
- No file under `tests/testthat/_snaps/` changed. `git status --porcelain`
  lists one entry, the test file. The full run marks about 30 snapshot files
  modified through the known CRLF artifact;
  `git diff --ignore-cr-at-eol` reported zero content lines and all of them
  were reverted. The six new blocks contain no `expect_snapshot()` call.
- `git status --porcelain R/` is empty and the `R` subtree hash equals the
  base's.
- `.test-full.log` was deleted before the commit.

## Signals raised

- **HOLD-1 — resolved by the coordinator as erratum E-7.** Both corrections
  were applied; see §Erratum E-7 above. No signal is open.

## Notes for tester

- The nine-type block calls a local `stored()` closure so the nine assertions
  each occupy one line and a mutation can name one. The closure captures the
  frame; it is not a shared helper and does not leave the block.
- `make_survey_data(type = "jkn", n_psu = 20L)` yields R = 20. The block pins
  that with `expect_identical(n_rep, 20L)` before using it, so a change to the
  generator turns up as a named failure and not as nine wrong literals. The
  two-row block builds its 20 columns inline and pins `nrow()` for the same
  reason.
- `air format --check` fails on `tests/testthat/test-constructors.R`, and it
  failed the same way at `e727001`. Formatting the file to a copy and diffing
  gives 28 hunks; the first starts at line 1596 and the rest past 2683. None
  falls inside the ranges this PR added, 865-1055 and 1613-1658. The hunk at
  1596 is the pre-existing
  `as_survey_twophase() accepts survey_replicate phase-1` block, which is base
  line 1381 before this PR's insertions above it.
- The two-phase block sets `in_phase2` with `rep(c(TRUE, FALSE), ...)` rather
  than a random draw, so it needs no seed of its own beyond the frame's.
- The five-refusal block orders its assertions in validator order:
  `empty_data`, `single_row`, `repweights_empty`, `weights_all_zero`,
  `rscales_length`. A reader comparing it against
  `R/core-validators.R` will find the same sequence.
