# Changelog: docs/haven-labelled-gates-13-16-17-18

**Branch:** `JDenn0514/spec.md-section-xi-gates-13-16-17-and-18-are-rec`
**Status:** Complete
**Date:** 2026-09-03

## Summary

Closes #216. `archive/haven-labelled/spec-haven-labelled.md` §XI lists 18
quality gates. The close-out (#202) reworded gates 2 and 7 as never met and
recorded the rest as satisfied. Four were not verified as written. No code
change is needed for any of them; the fix is to make the record true.

Documentation only. Every file changed sits under `archive/`, which
`.Rbuildignore:18` excludes from the build, so no gate figure can move.

### Gate 16 — `DESCRIPTION` did change

§XI.16 read "`DESCRIPTION` is unchanged. `NAMESPACE` is unchanged." §II
repeated it, the plan called it "checked in every PR", and PR 8's criterion
required an empty diff.

#194 added `labelled (>= 2.12.0)` under `Suggests`. The change is correct:
test row D-19 (`tests/testthat/test-utils.R:1004-1009`) calls
`labelled::to_factor()` under `skip_if_not_installed("labelled")`, and an
undeclared suggested package is an `R CMD check` note waiting to happen. The
gate was wrong, not the diff, so the gate now allows that one `Suggests`
entry and names it.

### Gate 13 — the count named a base that predates two unrelated merges

PR 8 task 3 ran `git diff cf6f153 -- plans/error-messages.md` and expected a
net **+1** row. `cf6f153` is the commit the spec was drafted on, and #185
merged after it, adding rows M-16 and M-17. The count could not pass there.

Measured against the feature's own range instead — `0be2f3a`, the base of the
first feature PR, to `14a2999`, the archive commit — **both halves of gate 13
pass exactly as specified**: one row added (row 102, the D6 row), PC-1 to
PC-3 reworded, none removed. The `NAMESPACE` half of gate 16 also passes
against that range. Only the base was defective.

Both ends of the range have to stay pinned: #220 added row PC-15 after the
archive commit.

### Gates 17 and 18 — no record existed

Both gates are recorded measurements rather than pass-or-fail checks, and the
plan assigned both to PR 3a's `implementation.md`. PR 3a wrote none. Its
directory under `.surveycore-workspace/` is empty, and
`.surveycore-workspace/` is untracked in any case. PRs 5 and 7 wrote notes;
PRs 1, 2, 3a, 3b, 4, 6 and 8 wrote none.

Gate 17 asks for the figure §III.6 names: the before-and-after ratio on one
grouped `get_quantiles()` call with three probabilities on the widest bundled
dataset. Measured 2026-09-03 on `ns_wave1` (171 columns, 6,422 rows), a
design from `as_survey_nonprob()`, 30 calls per block, three alternating
blocks, minimum taken:

| Run | Per call |
|---|---|
| With the strip live | 244 ms |
| With `.strip_labelled_columns()` replaced by a passthrough | 249 ms |
| Ratio | 0.98 |

The ratio is below 1.00 and inside the run-to-run spread of about 5%, against
the 1.05 figure §III.6 said should stop the work. Two supporting figures on a
500-column, 200-row frame with no column carrying the class: 0.45 ms per
`.strip_labelled_columns()` call, and 1.0 to 1.25 ms per `des@data <- df`
assignment.

Gate 18: confirmed against **S7 0.2.2** on R 4.6.1. One `des@data <- df`
assignment enters `.strip_labelled_columns()` exactly once, traced on the
helper, so the setter does not re-enter itself and the comment at
`R/core-classes.R:319-320` holds on this version.

Both figures now live inline at `spec.md` §XI.17 and §XI.18. Whether
`implementation.md` should be archived with a feature stays open in #217,
which owns the wider question of archiving the documents a spec or a decision
cites; this change points at #217 rather than settling it.

## Files Modified

- `archive/haven-labelled/spec-haven-labelled.md` — §XI intro records which
  gates were reworded against measurement after the feature shipped; gate 13
  states the commit range and why `cf6f153` cannot serve; gate 16 allows the
  one `Suggests` entry and marks the "unchanged" form as never held; gates 17
  and 18 carry the measurements and the missing-notes explanation; §II adds
  `DESCRIPTION` to the write surface and splits the `NAMESPACE` sentence from
  the `DESCRIPTION` one; §IX.1a's twin of the row count names the range
- `archive/haven-labelled/implementation-plan-haven-labelled.md` — header
  target-version note; PR 3a tasks 7 and 9 marked not done with a pointer to
  where each figure now lives; PR 3a's `implementation.md` criterion marked
  not met; PR 4's `DESCRIPTION` criterion and file list; PR 8 tasks 3 and 4
  rebased on `0be2f3a`; PR 8's gate 13 and gate 16 bullets, and its
  "`implementation.md` records every figure" bullet; the base-commit note now
  distinguishes the two bases and says what each is for; the file map and the
  quality-gate assignment table rows 13, 16, 17 and 18
- `archive/haven-labelled/decisions-haven-labelled.md` — the D7 paragraph on
  PR 8's diff base names `0be2f3a` for the file diffs and keeps `cf6f153` for
  the red-run list
- `changelog/docs-haven-labelled-gates-13-16-17-18.md` — this entry

## Changes

- Reword gate 16 to allow one `Suggests` addition, and record `labelled
  (>= 2.12.0)` as the feature's single `DESCRIPTION` change with the test row
  that needs it
- Rebase gate 13's count on `0be2f3a`..`14a2999`, the feature's own commit
  range, where both halves pass as specified; record why the drafting commit
  cannot serve as the base and why both ends must stay pinned
- Record the §III.6 timing ratio (0.98) and the S7 version (0.2.2) inline at
  §XI.17 and §XI.18, with the dataset, the method and the iteration counts
- Say at all five sites that PR 3a's `implementation.md` was never written,
  and point the archiving-policy question at #217
- Reach every twin of the four corrected claims across the three documents,
  including the instructions that assume them: PR 3a's tasks 7 and 9, PR 8's
  tasks 3 and 4, and §IX.1a's restatement of the row count
