# Plan review — svydesign-replicate-bridge (#197, #198)

**Verdict**: PASS — settled by pass 2, recorded at the end of this file
**Date**: 2026-09-08 15:52
**Passes run**: 2 of a permitted 3

Pass 1 returned NEEDS-DECISION. The user settled both judgment calls as D8,
D9 and D10 in `decisions.md`, Stage 3 applied every finding, and the pass 2
delta review found nothing. Each pass keeps its own verdict below.

---

## Pass 1 — full panel

**Verdict**: NEEDS-DECISION
**Date**: 2026-09-08 15:08
**Pass**: 1 of 3 (full panel, all five lenses, whole document)

Findings: 0 blocking, 4 required-unambiguous, 2 judgment calls, 4 suggestions.

Two lens findings were reclassified after the leader checked them against the
repository and the test spec. Both reclassifications are recorded with the
finding.

---

## Verdict basis

| Severity | Count | Effect |
|---|---|---|
| BLOCKING | 0 | — |
| REQUIRED-UNAMBIGUOUS | 4 | FAIL — resolve in Stage 3 |
| JUDGMENT_CALL | 2 | NEEDS-DECISION — user decides first |
| SUGGESTION | 4 | Optional |

`signals.md §Review verdicts` gives NEEDS-DECISION precedence: a judgment call
must be settled by the user before the resolve stage runs, because one of the
two changes the number of pull requests the plan contains.

---

## Required-unambiguous findings — apply in Stage 3

### R1 — PR 1 claims confidence-bound parity in every oracle row

**Lens**: Acceptance Criteria (F1)
**Location**: PR 1, acceptance criteria
**Finding**: The criterion reads "Point estimates agree at `1e-10`, standard
errors at `1e-8` and confidence bounds at `1e-6` in every oracle row."
`test-spec.md` §6.1 assigns the confidence-bound comparison to row I-1 alone.
Rows I-2, I-3 and I-4 assert the point estimate and the standard error only,
and §6.1 states why: a confidence-bound difference comes from the degrees of
freedom each package picks for the quantile, not from the conversion. Taken
literally the criterion tells the builder to add assertions that can fail for
a reason this change does not touch.
**Fix**: Reword to "Point and standard-error parity in every oracle row, I-1
to I-4; confidence-bound parity at `1e-6` in row I-1 only."

### R2 — Two profile gates appear in no acceptance-criteria list

**Lens**: Acceptance Criteria (F2)
**Location**: PR 1 and PR 2, acceptance criteria
**Finding**: The plan's own Profile gates section commits both pull requests
to all six gates in `test-spec.md` §12. The per-PR acceptance criteria list
only four of them as standalone pass/fail bullets: document, test, R CMD check
and covr. `devtools::run_examples()` and `pkgdown::build_site()` appear only
inside a task line. A gate that is not an acceptance criterion is not a merge
gate.
**Fix**: Add two bullets to each pull request's acceptance criteria:
`devtools::run_examples()` runs every example with no error, and
`pkgdown::build_site()` builds with no error.

### R3 — `plans/error-messages.md` has no cross-PR no-reformat criterion

**Lens**: Dependency Ordering (F1)
**Location**: PR 2, task 1 and acceptance criteria
**Finding**: `tests/testthat/_snaps/conversion.md` gets an explicit protection
in both acceptance-criteria lists, because PR 2 edits a file PR 1 already
merged. `plans/error-messages.md` takes the same shape — PR 1 creates the
dated section with rows CB-1, CB-2 and CB-5; PR 2 inserts CB-3 and CB-4 into
the middle of that merged table and edits the row 16 note — and gets no such
protection.
**Fix**: Add an acceptance criterion to PR 2: `plans/error-messages.md` shows
no diff outside the two inserted rows and the row 16 trigger note.

### R4 — Task 10 verifies the helper at the console instead of against test rows

**Lens**: Spec Coverage (F1), reclassified fix
**Location**: PR 1, task 10
**Finding**: Every other implementation task states its verify clause against
a numbered test row. Task 10 reads "Verify at the console that 3 gives
unpadded names and 20 gives names zero-padded to width 2." A console check
leaves no regression test behind.

The lens proposed a direct unit test for `.repwt_col_names()`. The leader
checked the test spec and the repository convention and did not adopt that
fix. `testing-standards.md` tests private helpers indirectly through the
public interface by default, and direct tests only when coverage cannot be
reached indirectly. Coverage can be reached indirectly here: `test-spec.md`
already carries a row for each of the four width cases the spec's §III.6
requires.

| Width case | Test-spec row | What it asserts |
|---|---|---|
| `n_rep` = 1, unpadded | I-17 | The generated name is `..surveycore_repwt_1..` |
| `n_rep` = 2, unpadded | I-18 | Both generated names, unpadded |
| `n_rep` = 4, unpadded | I-9 | Four generated names, unpadded |
| `n_rep` = 20, padded to width 2 | I-8 | Twenty names, `sprintf("%02d", 1:20)` |

**Fix**: Replace task 10's console check with "Verify rows I-8 and I-9 reach
the generated-name assertion" and note that rows I-17 and I-18 in task 31
close the one- and two-replicate widths. Add no direct helper test.

---

## Judgment calls — user decides before Stage 3

### J1 — Does PR 1 split into a correctness fix and a guards pull request?

**Lens**: PR Granularity (F1)
**Location**: PR 1, the whole entry; the plan's "why not three" paragraph

PR 1's own title names three behaviours: carries the weights across intact,
puts them on the population scale, and refuses the states it cannot carry.
`spec.md` §I.1 rows 1 to 6 form one coherent fix for the two defects §III.1
describes — rows 4 and 5's name guards act on the same generated-name state
rows 1 and 2 produce, so they are coupled. Rows 7 and 8 are different: they
come from decisions D5 and D6, they run as independent early-exit checks at
§III.2 steps 1 and 3 "before any column work", and they share no state with
the naming and scale fix.

The plan considers this split and rejects it on rebase cost and code
proximity — "the guards are the first two steps of the same function body".
The lens reads 37 tasks, 8 spec rows and 4 new error classes in one pull
request as past the plan's own size signal.

**Options**

- Keep two pull requests, and strengthen the "why not three" paragraph with a
  reviewability argument rather than a cost one.
- Split PR 1 into PR 1a (rows 1 to 6 and 12 — the fix and its coupled name
  guards) and PR 1b (rows 7 and 8 — the two independent guards), sequential in
  the same way PR 1 and PR 2 already are. Three pull requests total.

### J2 — How does the plan evidence property 8 on the export route?

**Lens**: Spec Coverage (F2)
**Location**: The plan's §VI scheduling table, property 8

`spec.md` §VI property 8 says all nine accepted replicate types cross both
routes. The plan cites E-9, E-10 and R-5 as the export-side evidence, and all
three are Fay-specific.

The leader read `test-spec.md` §7 to establish what the export rows cover.
Five types reach the export route: BRR at E-3, bootstrap at E-4, JKn at E-5,
Fay at E-9 and E-10, and the `rep_bridge_sc()` default at E-1 and E-2. Four
accepted types reach it in no row: JK2, ACS, successive-difference and
`"other"`.

The export route branches on type in exactly two places. §IV.2 step 3 passes
`scale = NULL` for `"BRR"` and `"Fay"`; step 4 passes `rho` for `"Fay"`. Every
other type takes the same path. E-3 covers the BRR arm, E-9 and E-10 cover the
Fay arm, and E-4 and E-5 cover the arm the remaining seven types share. So
every branch has a row, and the four unexercised types run lines that other
rows already reach.

**Options**

- Re-cite property 8's export half to the rows that exercise the branches —
  E-3, E-4, E-5, E-9, E-10 — and record in the plan that the route has two
  type-dependent branches and each has a row. Plan edit only; the test spec
  does not change.
- Add an export row parametrized over all nine accepted types. This edits
  `test-spec.md`, which froze at SPEC_READY, so the request returns to
  `pipeline-spec` before the plan can advance.

---

## Suggestions — optional

### S1 — `tests/testthat/_snaps/conversion.md` does not exist yet

**Lens**: File Completeness (F1). Verified by the leader: the file is absent,
and `tests/testthat/test-conversion.R` contains no `expect_snapshot()` call.

The shared write-surface table calls the file's treatment "Append only; change
no line ending", and both acceptance-criteria lists say it "keeps its existing
line endings and shows no reformatting of the blocks that were already there."
Nothing existing is there to keep. PR 1 creates the file, and the no-reformat
criterion first bites in PR 2.

**Fix**: Note in PR 1 task 20 and in the write-surface table that PR 1 creates
the file for the first time through `snapshot_review()`.

### S2 — Commit per lettered task group

**Lens**: PR Granularity (F2). The plan's Group A to H and Group A to D labels
already mark reviewable slices, and nothing tells the builder to keep them as
separate commits. If J1 resolves to two pull requests, per-group commits
recover most of what the split would have given a reviewer.

### S3 — Note the transient CB row gap in the file itself

**Lens**: Dependency Ordering (F2). Between the two merges, the new section of
`plans/error-messages.md` shows CB-1, CB-2 and CB-5 with a gap. The gate map
acknowledges it; the file does not. One line in PR 1's new section — CB-3 and
CB-4 land in the paired export pull request — makes the gap self-explanatory.

### S4 — Mark which criteria come from the gate map

**Lens**: Acceptance Criteria (F4). Some criteria trace to `spec.md` §VII
rather than to a test-spec row — the verbatim class-name check, the `fpc =`
absence check, the `git diff --name-only` checks. Annotating them "(§VII gate
N)" stops a reviewer hunting for a test row that was never meant to exist.

---

## Reclassified, and why

### Not a judgment call — the documentation criterion

The Acceptance Criteria lens raised PR 1's criterion "`man/from_svydesign.Rd`
contains no sentence saying the replicate weights are preserved, and does
describe the written replicate column block" as a judgment call, on the ground
that the second half names nothing a reader can check.

The observation is right and the fix is not a choice. Task 32 of the same pull
request already lists the three facts `spec.md` §II.3 requires the block to
state. Restating those three facts in the criterion makes it checkable and
adds no decision. Folded into Stage 3 as part of R1's neighbourhood; recorded
here so the lens finding is not lost.

**Fix**: Replace "does describe the written replicate column block" with the
three facts task 32 names — the conversion transforms rather than preserves
the weights on a factor-form source, the generated block and its naming
pattern, and that `@variables$repweights` names those columns in replicate
order.

### Not a defect — the reordered guards in both pull requests

The Dependency Ordering lens checked whether implementing a guard out of its
final in-function position can make a red test fail for the wrong reason. It
does not, in either pull request: PR 1's type guard lands in Group D after
Groups A to C, and PR 2's FPC drop lands in Group B before the Fay recovery in
Group C, which reverses `spec.md` §IV.2 steps 4 and 5. Both are safe because
the fixtures are disjoint — E-3, E-4 and E-5 use BRR, bootstrap and JKn and
never Fay; E-9 and E-10 carry no FPC — so no block exercises two of the
reordered conditions at once. Recorded so a later pass does not re-raise it.

---

## What each lens confirmed

| Lens | Confirmed |
|---|---|
| PR Granularity | The import/export boundary is real. No condition spans both routes. Nothing sits on the wrong side. Round-trip rows R-1 to R-5 correctly wait for PR 2; `man/from_svydesign.Rd` is correctly PR 1 only, per gate 8 |
| Dependency Ordering | PR 1 merges first; PR 2 branches from `develop` after it, with "do not open this pull request while PR 1 is open" stated. No red test fails for want of scaffolding. No acceptance criterion crosses the boundary — properties 8 and 11 sit in the informational table, not in PR 1's criteria |
| Acceptance Criteria | Four of six profile gates and 11 of 13 quality gates appear as observable bullets. The class-name, `fpc =` and `git diff` checks are observable |
| Spec Coverage | All 12 §I.1 rows scheduled. All 13 §III.2 steps, all 7 §IV.2 steps, all 7 conditions, both halves of §V.7, all three §II.3 doc facts, and all 12 §VI properties carry a citation. No scope creep: every task traces to a spec row, step, condition or property. Every §I.2 exclusion holds — `NEWS.md`, the Taylor, two-phase and nonprob routes, `R/core-classes.R`, `R/core-constructors.R`, `R/variance-replicate.R` and a `combined_weights` key are untouched |
| File Completeness | The union of both write surfaces equals gate 6's five-file list exactly. No pull request claims a file the spec does not authorise. `NAMESPACE`, `DESCRIPTION`, `NEWS.md` and every other `man/` page stay out. The source-to-test mapping matches `testing-surveycore.md` |

---

## Routing

1. User settles J1 and J2.
2. Stage 3 applies R1 to R4, the reclassified documentation fix, and whichever
   suggestions the user takes.
3. Pass 2 is a delta pass: at most two lens agents, reading only the sections
   the resolver changed.

---

# Pass 2 — delta pass

**Verdict**: PASS
**Date**: 2026-09-08 15:52
**Scope**: Two lens agents, reading only the sections the Stage 3 resolver
changed. No full-panel re-read, per the review-loop budget.

The resolver rewrote the document to version 2.0: five pull requests in place
of two, cut along the task groups the draft already defined. Changed headings
were Shape of the plan, the whole PR map, Ordering and the shared write
surface, the gate map, the profile gates, both scheduling-coverage tables and
the test row allocation.

## Findings

None, from either lens. The pass required no change to the artifact, so the
loop ends here.

## Lens 1 — Dependency Ordering

No findings. Confirmed:

| Check | Result |
|---|---|
| Green per pull request | All 58 test rows land in exactly one pull request. Block counts sum 10 + 15 + 10 + 11 + 12 = 58 and snapshot counts sum 4 + 2 + 2 = 8, both matching `test-spec.md` §13. Row I-25 stays excluded as unreachable |
| The I-1 seam (D10) | I-1 and I-2 are cells A and B, the factor form, and wait for PR 2. I-3 and I-4 are cells C and D, finished weights, and stay in PR 1. I-13, I-15, I-16, I-19, I-22 and I-26 sit in PR 2 |
| `test_invariants()` | No call for `from_svydesign()` or `as_survey_replicate()` exists in `tests/testthat/test-conversion.R` today — the file holds two calls, both on `as_survey()` designs. PR 1's placement in I-3 and PR 2's move to I-1 match §10.1's first-new-block carve-out. Exactly one call at every merge point, and no simpler placement satisfies both the per-PR green rule and the final location the test spec names |
| Sequencing | All five entries state a branch point and the do-not-open rule. PR 1 states it has no predecessor |
| `plans/error-messages.md` | CB order and the section anchor check out against the live file. The insert order CB-3 then CB-4 is explicit, and PRs 4 and 5 both carry the no-reformat criterion |
| `tests/testthat/_snaps/conversion.md` | PR 3 is named as its creator. The no-reformat criterion starts at PR 4 |
| Reordered guards | E-3, E-4 and E-5 never use Fay; E-9 and E-10 never carry an FPC. No block exercises both reordered steps at once |

## Lens 2 — Acceptance criteria, spec coverage, file completeness

No findings. All five fixes applied.

| Fix | Status |
|---|---|
| R1 — confidence-bound parity scoped to row I-1 | Applied |
| R2 — all six profile gates as bullets on all five pull requests | Applied |
| R3 — no-reformat criteria on PRs 4 and 5 | Applied |
| R4 — the helper verified against rows I-8 and I-9, no direct test | Applied |
| The documentation criterion names §II.3's three facts | Applied |

Coverage survived the restructure: all 12 §I.1 rows map to exactly one pull
request; all 12 §VI properties carry a citation, and the property 8 subsection
carries the branch table from D9; all 13 §VII gates map to a pull request,
with gate 5 stated as completing only at PR 5. The write-surface union equals
gate 6's five-file list exactly. `man/from_svydesign.Rd` belongs to PR 2
alone. `plans/error-messages.md` and `tests/testthat/_snaps/conversion.md` are
absent from PR 1 and PR 2. `NEWS.md`, `NAMESPACE` and `DESCRIPTION` appear in
no write surface.

## Correction to pass 1

Suggestion S1 recorded that PR 1 creates
`tests/testthat/_snaps/conversion.md`. Under the five-way split PR 3 is the
first pull request to add a snapshot, so PR 3 creates the file. The resolver
applied it that way and lens 1 verified it.

## Loop cost

Two passes. Pass 1 was the full panel of five lenses; pass 2 was two delta
lenses. The budget allows three passes.
