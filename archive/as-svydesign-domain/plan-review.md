# Plan review — as-svydesign-domain

**Pass**: 1 of at most 3 (full panel, five lenses)
**Verdict**: NEEDS-DECISION
**Date**: 2026-09-10

One blocking finding, three required, six suggestions. The blocking finding
cannot be resolved inside the plan: it needs a row that `test-spec.md` does not
hold, and `test-spec.md` froze at SPEC_READY.

| Lens | Verdict | Blocking | Required | Suggestions |
|---|---|---|---|---|
| 1 — PR budget | PASS | 0 | 0 | 1 |
| 2 — Dependency ordering | PASS with finding | 0 | 1 | 0 |
| 3 — Acceptance criteria | PASS with finding | 0 | 1 | 3 |
| 4 — Spec coverage | NEEDS-DECISION | 1 | 1 | 2 |
| 5 — File completeness | PASS | 0 | 0 | 0 |

---

## Blocking

### B-1 — no row puts a filtered FPC-bearing replicate design through the new call site

**Lens 4.** `spec.md` §`as_svydesign(x)` → Warnings claims
`surveycore_warning_replicate_fpc_dropped` is "Unchanged in every respect" on
the replicate route. PR 3 inserts the restriction into
`.as_svydesign_replicate()`, which is the function that fires that warning.
Every PR-3 criterion that reaches the replicate route names a design carrying
no FPC: criterion 1 (A-2, A-3) sets no FPC, and criterion 4 names "replicate
carrying no FPC" (C-2). `test-spec.md` chose that shape deliberately — G-1b
needs `expect_no_condition()`, which an FPC-bearing design would break.

So the pair *filtered* and *FPC-bearing* is untested on the one route this arc
edits. The other warning on the arc,
`surveycore_warning_nonprob_srs_conversion`, does get such a row: G-2 asserts
it "fires exactly once, and no other condition fires" on a filtered design.
The asymmetry is the finding.

**Verified against source, and it lowers the severity.** In
`R/methods-conversion.R` the FPC warning fires at lines 347-368 and
`survey::svrepdesign()` — the call that builds the object — is the last
expression of the function at line 370. The restriction wraps that return
value, so it provably runs after the warning. No mechanism doubles or
suppresses it.

**Why it still stands as blocking.** The claim is in the spec's contract, on
the route the PR edits, and the plan schedules nothing that checks it. The
resolution costs one test block, but it needs a `test-spec.md` row, and that
artifact is frozen. This is the user's call — see §Decision required.

---

## Required

### R-1 — PR 1 changes a second route it does not test

**Lens 2.** `as_svydesign()` dispatches a `survey_nonprob` design that names no
replicate weights into `.as_svydesign_taylor()` (`R/methods-conversion.R:169`;
`spec.md` §Route matrix, row 5). PR 1 edits that function. So merging PR 1
changes production behaviour on two routes, and PR 1's rows (A-1, A-5, A-6,
C-1, D-1, D-8, F-1, F-2, F-3, G-1a) exercise only the Taylor one. The rows for
the second route — A-4, C-5, D-2d, E-2, G-2 — all sit in PR 3, two merge cycles
later. `develop` therefore carries an untested behaviour change across the whole
of PR 2.

PR 3 has no such asymmetry: it edits `.as_svydesign_replicate()`, which serves
both the replicate route (A-2) and the non-probability shape naming replicate
weights (A-3), and it tests both.

**Resolution applied.** Move row A-4 from PR 3 to PR 1, and disclose the second
route in PR 1's scope line. A-4 is the parity row for the shape in question, and
it captures the SRS warning off the call, so PR 1 then asserts both the estimate
and the warning on every route its code touches. The stricter G-2 — "exactly
once, and nothing else" — stays with the non-probability PR, where the rest of
that shape's rows live.

### R-2 — the structural quality gate has no acceptance criterion

**Lens 4.** `spec.md` §Quality gates: "One restriction helper exists, it takes
one argument, and each of the three routes calls it once. No route contains its
own copy of the mask expression, of the column-presence check, or of the
frame-selection branch."

The plan carries this only as task prose (PR 4, task 4) and as a row of its own
gate table. No numbered acceptance criterion states it, so nothing forces a
check at accept time. The claim is observable — the counts are greppable.

**Resolution applied.** PR 5 gains it as criterion 8, replacing the padded
criterion the next finding names. PR 5 is where the final state of
`R/methods-conversion.R` exists.

### R-3 — PR 5 criterion 8 restates three of its own criteria

**Lens 3.** PR 5's criterion 8 reads "All seven profile gates pass". Its own
criterion 3 already asserts the `devtools::document()` gate, criterion 6 asserts
`devtools::run_examples()` and `pkgdown::build_site()`, and criterion 7 asserts
`R CMD check`. Three of the seven are asserted twice inside one entry, which
pads the count. No other PR splits a gate out and then re-asserts it.

**Resolution applied.** Criterion 8 becomes the structural criterion of R-2. The
profile gates reach PR 5 through the standing §Profile gates list, which already
applies to every PR, and through criteria 3, 6 and 7.

---

## Suggestions

| # | Lens | Finding | Disposition |
|---|---|---|---|
| S-1 | 1 | PR 2 and PR 3 each sit at 11 rows, one under the bound. A row folded in during ship breaches it. | Recorded as a standing note in the plan. |
| S-2 | 3 | PR 3 criterion 3 cites A-2, A-3, A-4 after criteria 1 and 2 cite the same rows. Intentional — test-spec §A says those rows each add two marker assertions — but it reads as padding. | Wording fix: name the parity claim and the marker claim apart. |
| S-3 | 3 | PR 4 criterion 7 bundles G-1c with the `test_invariants()` count, and the invariants half maps to test-spec §Invariants rather than to a lettered row. | Wording fix: say so, so the row ledger is not misread. |
| S-4 | 3 | PR 5's criteria map to no row by design. | No change. The budget line already says so and gives the reason. |
| S-5 | 4 | "Every value `TRUE`" (D-1) and "exactly one value `TRUE`" (D-3) are tested on the Taylor route only, though the spec's edge-case preamble scopes them to three routes. | Accept. The mask is route-independent for these two; the empty-domain case, where the observable does differ by route, is the one the test-spec fans out (D-2a/b/c/d). Recorded. |
| S-6 | 4 | The three unchanged error classes get no criterion. | Accept. `test-spec.md` §Error paths argues it: each fires before an object exists to restrict. The `devtools::test()` gate protects the existing blocks. |

---

## Clean lenses

**Lens 1 — PR budget.** Recomputed both figures for all five entries against
`test-spec.md`. Every stated figure matches. All 42 rows claimed, each exactly
once, none invented. Row counts 10, 11, 11, 10, 0 against a bound of 12;
criteria 8, 8, 8, 8, 8 against a bound of 8. No entry over budget, no
one-task-one-row entry to merge.

**Lens 5 — File completeness.** The union of write surfaces is exactly the four
files of `spec.md` §Files touched. `man/as_svydesign.Rd` appears only in PR 5,
regenerated and never hand-edited. `changelog/` exists and its recent entries
use the flat `type-scope.md` [no such file] format (a filename pattern, not a document) the plan names. `NAMESPACE`, `NEWS.md` and
`plans/error-messages.md` appear in no write surface, only as byte-identical
checks. All three cited line numbers in `R/methods-conversion.R` hold the named
content: the internal-helpers heading at 12, the `@section` block at 88-100, the
`@return` block at 43-50.

**Lens 2, points 1-4.** PR 2's eleven rows all run on the Taylor route PR 1
ships, `as_tbl_svy()` included, so the tests-only PR needs no later code. PR 4's
frame branch is class-conditional and leaves PR 1's expression untouched. PR 3
adds a call site rather than editing PR 1's. The helper lands with a call site.
The documentation PR lands last.

---

## Decision required

B-1 is the only open item. Both answers are defensible and the plan advances
either way.

---

# Pass 2 — delta

**Verdict**: PASS
**Date**: 2026-09-10
**Scope**: two agents, changed sections only, per the review-loop budget.

The user chose to close B-1 by adding a row. `test-spec.md` gains G-3 in both
copies, PR 3 carries it, and `decisions.md` records D13 and D14.

| Pass 1 finding | Status | Evidence |
|---|---|---|
| B-1 — FPC warning untested on a filtered design | CLOSED | G-3 in both test-spec copies, byte-identical. PR 3 carries it in its budget, task 10 and criterion 7. G-3 names an FPC-bearing fixture and G-1b names one carrying none, so the two do not collide. D14 records the choice. |
| R-1 — PR 1 changes a second route it does not test | CLOSED | A-4 sits in PR 1's budget, task 8 and criterion 1, and is gone from all three places in PR 3. PR 1's scope note discloses the second route. Verified in source: `R/methods-conversion.R:136-170` fires the SRS warning at line 167 and calls `.as_svydesign_taylor(x)` at line 169. D13 records it. |
| R-2 — structural gate has no criterion | CLOSED | PR 5 criterion 8, with PR 5 task 7 performing the count. |
| R-3 — PR 5 criterion 8 restated three gates | CLOSED | The restatement is gone. The gates reach PR 5 through the standing §Profile gates section and criteria 3, 6 and 7. |

**Arithmetic re-verified.** 43 rows in `test-spec.md`. Budgets 11, 11, 11, 10,
0 — sum 43, every row claimed exactly once, none over the bound of 12. Criteria
8 on every entry, numbered consecutively. The row ledger agrees with every
budget line. No stale `42` anywhere.

**One new finding, fixed in the pass.** The standing §Profile gates section
claimed "the last criterion of each PR entry is this list", which stopped being
true of PR 5 when its criterion 8 became the structural gate. The sentence now
names the exception and says which three gates reach PR 5 through the standing
section alone. Suggestion severity; no budget figure moved.

No blocking and no required findings remain. The loop ends at pass 2 of 3.
