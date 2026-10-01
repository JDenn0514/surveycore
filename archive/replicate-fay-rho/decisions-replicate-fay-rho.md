# Decisions — replicate-fay-rho

Settled by the user on 2026-09-30, before Stage 0.

## S1 — `rho` on a non-Fay type warns and is discarded

`plans/issue-cleanup.md` D6 said "refused for every other type". D7, the later
decision, and the issue's Verification list say "warn, discard". The user chose
D7. A new typed warning fires only when the caller supplied `rho` (D8).

## S2 — Fay only; the rest of #255 stays with #255

This work sets Fay's argument handling in full: `rho` required, a supplied Fay
`scale` discarded with no warning (D7), `rho` on other types per S1. The
`scale` and `rscales` rules for BRR, JK2, ACS and successive-difference stay
with issue #255.

## S3 — A Fay design with no stored `rho` is refused on export

The scale inversion in `R/methods-conversion.R` (PR #250) is deleted. A Fay
design whose `@variables$rho` is absent or `NULL`, because it was built before
this change, raises `surveycore_error_fay_rho_unrecoverable`. Register row CB-4
is restated for that case, and its fix bullet names
`as_survey_replicate(rho = )`.

---

Settled by the orchestrator on 2026-09-30, after Stage 0, on the open
questions in `comprehension.md`.

## S4 — `rho` is a key of every `survey_replicate` design

`rho` joins the replicate `@variables` list for every type: the number for
Fay, `NULL` for every other type. This follows the code-style rule that all
keys are always present. A replicate key check in `test_invariants()` is out
of scope.

## S5 — print and summary show `rho` for a Fay design

Every print site that shows replicate settings shows `rho` for a Fay design.
Output for every other type is unchanged, so no existing snapshot moves.

## S6 — documentation in scope

- `vignettes/creating-survey-objects.Rmd` lines 299 and 874 (`fay_rho`).
- The Judkins citation in `R/core-constructors.R` and `R/core-classes.R`,
  corrected to *Journal of Official Statistics* 6(3), 223-239 (1990).
- `CLAUDE.md` line 89.
- `DESCRIPTION`'s Fay claim stays; it becomes true.
- `NEWS.md`: rewrite the unreleased PR #250 entry in place; add the moved-SE
  note (new SE = old SE / (1 - rho)) and the new missing-`rho` error.

## S7 — legacy Fay objects in analysis are out of scope

A saved Fay design with no `rho` key keeps its stored `1/R` scale in the
analysis functions, with no condition. `NEWS.md` tells users to rebuild Fay
designs.

## S8 — `from_svydesign()` reads `x$rho` for Fay only

For any other type it stores `NULL`, even when the `survey` object carries
`$rho = 0` (`as.svrepdesign()` BRR, measured M7).

---

Planner choices, 2026-09-30, made while drafting `spec.md`. None needs the
user; each is open to the methods and spec reviews.

## S9 — `as_survey_twophase()` refuses a `survey_replicate` phase 1

Settled by the user on 2026-09-30 after Stage 2 methods review, Lens 2.

The phase-1 variance code (`R/variance-twophase.R:92-185`) reads only
`strata`, `ids` and `fpc`. A replicate phase 1 has none of these keys, so it
treats every row as its own PSU and never uses the replicate scale. This is
true for every replicate type. `survey` has no such design:
`survey::twophase()` takes both phases as formulas on a data frame, and given a
`svyrep.design` it stops with "cannot coerce class '"svyrep.design"' to a
data.frame" (measured, survey 4.5, R 4.6.1). So the user chose to refuse it for
now, with a new typed error and a register row.

This reverses PR #74 (commit `0b7f9d9`, 2026-03-16). Existing blocks that build
the design break and become expected-error tests. Known today:
`tests/testthat/test-constructors.R:1704` ("accepts survey_replicate phase-1"),
the next block ("carries the phase-1 scale of both changed types", issue #253),
and `tests/testthat/test-variance-twophase.R` about line 503. None of them
asserts a correct SE. The spec must enumerate every site. A `survey_nonprob`
phase 1 is not affected.

## S10 — `update_design()` stale scale goes to its own issue

Settled by the user on 2026-09-30. `update_design(repweights = )` can change
the replicate count and keeps the stored scale, for every type. Out of scope
here; the spec's Out entry cites the new issue.

## S11 — `rho` goes after `type`, before `scale`

Settled by the user on 2026-09-30 after spec review Lens 6. The order matches
`survey::svrepdesign()`. P1 below is withdrawn. A call that passes `scale`,
`rscales`, `fpc`, `fpctype`, `mse` or `calibration` by position shifts by one;
NEWS records it as a breaking change.

## P1 — WITHDRAWN by S11 — `rho` is the last formal argument of `as_survey_replicate()`

It goes after `calibration`. A caller who passes `scale`, `rscales`, `fpc`,
`fpctype`, `mse` or `calibration` by position keeps working.

## P2 — `rho` is checked for Fay only

For any other type a supplied `rho` warns and is discarded whatever its
value. A value that is thrown away cannot change a result, so a second
condition for it would tell the user nothing more.

## P3 — the export refusal also covers an unusable stored `rho`

CB-4 fires when a Fay design's stored `rho` is absent, `NULL`, or fails the
constructor's rule. S3 names the first two. The third is reachable only
through the exported `survey_replicate()` constructor or a hand edit, and
`survey` would accept such a value with no check (M6).

## P4 — `from_svydesign()` copies survey's Fay `rho` unchanged

The import route copies survey's scale unchanged today, so its analysis
numbers match survey's. It does the same for `rho` and applies no range
check. A survey Fay object with an unusable `rho` imports, and its export is
then refused by CB-4.

## P5 — a Fay design with `rho = 0` keeps `type = "Fay"`

`survey::as.svrepdesign()` relabels `fay.rho = 0` as `"BRR"`. The
constructor stores the type the caller passed.

## D-1 — PR 1 makes holding edits to four existing Fay blocks (plan)

When Fay requires `rho`, four existing blocks fail, and neither artifact
names who fixes them: `make_rep_type()`, the "recovers rho = 0" block and
the all-types block in `test-conversion.R`, and the Fay block in
`test-variance-replicate.R`. PR 1 task 12 passes `rho` in each. It deletes
the "scale yields no rho" block and its snapshot, because that state can no
longer be built. PRs 5 and 7 later replace the edited blocks.

## D-2 — the two-phase refusal (spec §IX) ships as PR 8, after PR 1 (plan)

Spec §I item 9 says §IX does not depend on `rho`. Its refusal test must
cover every replicate type, Fay included, and a Fay design needs `rho`. So
PR 8 follows PR 1. It also shares files with PRs 1, 2, 3 and 5, so it
follows them too.

## D-3 — two spec errata the plan works round (plan)

- Spec §II names a quick-reference row in `.claude/rules/testing-surveycore.md`
  that "names" the sanctioned-exceptions section. No such row exists, and
  §VIII.4 says nothing else in the file changes. PR 9 edits the section
  only.
- `.is_valid_rho()` goes into `R/utils.R` in PR 1 with one caller. The
  second caller arrives in PR 5 or PR 6. The spec's placement wins over the
  code-style rule that promotes a helper at its second call site.

## HOLD — PR 1 reviewer STOP (tolerance-integrity) — 2026-09-30

- **Stage:** pipeline-ship, PR 1 review (review.md).
- **Finding:** `tests/testthat/test-constructors.R:1005`, the Fay line of the
  nine-type default block (rows 1.1, 1.2), calls `expect_equal()` with no
  `tolerance`, so testthat 3e uses about 1.49e-8. The plan fixes stored-scale
  tolerance at 1e-8. audit.md recorded row 1.2 at 1e-8 and row 1.1's `rho` at
  1e-10, and neither line sets a tolerance.
- **Context:** the other eight lines of the same block, unchanged since
  PR #297, also use the default tolerance.
- **Options:** (a) builder adds `tolerance = 1e-8` (and the stated tolerance
  on the row 1.1 `rho` assertion), tester re-runs the filtered file and
  corrects audit rows 1.1 and 1.2; (b) user override.
- **Resolution:** pending user decision.
- **Resolution (user, 2026-09-30):** option (a). Builder adds explicit
  tolerances to the row 1.1 and 1.2 assertions only; the eight pre-existing
  lines stay as they are.
- **Fix made by the orchestrator, inline:** the PR 1 builder could not be
  resumed (its worktree was removed). The edit was two argument additions,
  shorter than a builder brief, so the orchestrator made it: `tolerance =
  1e-8` on the nine-type block's Fay line and `tolerance = 1e-10` on the row
  1.1 `rho` assertion. Filtered constructors run: FAIL 0, PASS 799.

## Gate note — PR 4 R CMD check killed (2026-09-30)

PR 4's first gate run (tree dd70f9e) lost `R CMD check` at its test phase:
`gate-5-check.log` stops at `Running 'testthat.R'` with no `Status:` line, and
no `00check.log` was copied. run-gates.sh reports such a run as PASS with
"Status line missing", so the orchestrator does not accept it. Gate 5 is
re-run alone as a detached process on the same tree; gates 1-4, 6, 7 stand.
- **Re-run result:** `R CMD check --as-cran --no-manual` on tree dd70f9e, detached: Status: 2 NOTEs (CRAN incoming feasibility; hidden .git). Log: prs/pr-4-fay-rho-import/gates/gate-5b-check.log.

## Deferred — stale X-13 comment in test-conversion.R (PR 5 review, 2026-09-30)

The PR 5 reviewer found comment X-13 at `tests/testthat/test-conversion.R`
line 2683 still saying "recovered shrinkage factor". It sits outside PR 5
task 7's list, so the reviewer did not block. No later PR in this plan writes
that file (PRs 6-9 touch other files), so the comment stays stale unless the
user picks a home for it. Spec quality gate 7 does not reach `tests/`.
Raised with the user at arc close.

## Archive note (2026-09-30)

- **Arc result:** nine PRs, #301 to #309, all merged to `develop`. Suite
  12100 → 12353 passing, warnings held at 256, coverage 96.15% → 96.17%,
  2 pre-approved NOTEs at every gate run. One reviewer STOP (PR 1,
  tolerance); zero tester BLOCKs.
- **Issue #243 is still open.** PR #309 carries `Closes #243`, but GitHub
  acts on closing keywords only for merges into the default branch (`main`).
  It closes when `develop` merges to `main`.
- **The register planning copy is not archived.** `error-messages-planning-
  copy.md` was the uncommitted state of `plans/error-messages.md` at
  PLAN_READY. Its FR-1 to FR-3 and TP-1 rows now sit in
  `plans/error-messages.md` verbatim; the PR 1 and PR 8 reviewers confirmed
  the match byte for byte. The copy duplicated the whole register, so it
  was dropped from the archive.
- **Shipper records exist but are partial.** Each `shipper.md` records the
  PR number and pushed sha only. The orchestrator watched CI and merged,
  because a subagent cannot wait on CI.
- **run-gates.sh defect.** When `R CMD check` dies with no `Status:` line,
  the script reports gate 5 as PASS ("Status line missing"). PR 4 hit this;
  the orchestrator re-ran the check alone. The script should fail the gate.
- **Deferred:** the stale X-13 comment in `tests/testthat/test-conversion.R`
  (see the PR 5 entry above); issue #300, `update_design()` and a changed
  replicate count.
