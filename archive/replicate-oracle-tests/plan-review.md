# Plan review — replicate-oracle-tests

**Pass**: 1 of a maximum 3 (full panel, five lenses)
**Date**: 2026-09-16
**Document under review**: `implementation-plan.md`, 836 lines, nine PR entries
**Verdict**: **FAIL** — 11 findings. One needs a user decision.

## Lens verdicts

| Lens | Verdict | Findings |
|---|---|--:|
| PR budget | PASS | 0 |
| Dependency ordering | PASS | 2 |
| Acceptance criteria | FAIL | 5 |
| Spec coverage | FAIL | 4 |
| File completeness | PASS | 0 |

Two lenses found nothing. The budget lens recomputed all nine entries
independently and every stated figure matched. The file lens confirmed the
union of the nine write surfaces is exactly the two files `spec.md` §II names.

## What the findings have in common

Nine of the 11 findings are one shape: the plan writes a requirement into a
builder task, and no acceptance criterion checks it. A tester reads only the
test-spec and the criteria, so such a requirement can go missing in silence.

Four of the nine trace one level further back. The requirement sits in
`spec.md`, and `test-spec.md` carries no numbered row for it. The plan
inherited the gap rather than creating it.

## Findings

### A — Acceptance criteria lens

**A1. PR 1 criterion 1 maps to no row.** The criterion fixes the section
heading text and its position between the both-modes rule and the S7 error
testing layers. `spec.md` §III.1 requires that placement. `test-spec.md` §6
checks the rule's content only — its preamble says "Check that the section
states each of the thirteen points below" — so no row reads placement.
Class: test-spec gap.

**A2. PR 2 criterion 2 states a process, not an outcome.** It reads: "A probe
on the installed `survey` reproduces all nine rows of that table." That
describes what the builder does, not what the delivered document contains. A
tester cannot check it by reading either file.
Class: plan defect.

**A3. PR 3 criterion 3 maps to no row.** The criterion forbids a hard-coded
replicate count. `test-spec.md` §1 states the requirement in prose — "A block
that hard-codes a replicate count is a defect" — and carries no numbered row
for it. §1 is also absent from the plan's own table of unnumbered sections
bound to a PR.
Class: test-spec gap, plus one omission in the plan's binds table.

**A4. PR 3 criterion 1 carries a tail clause with no row.** The clause "and the
file runs with 0 failures" reads the file mid-arc, at 26 blocks. The only
0-failures row is 3.5.1, which reads the finished 28-block file and is
allocated to PR 9. The clause also duplicates a standing gate.
Class: plan defect.

**A5. The lens finding is inverted; the underlying defect is real.** The lens
reported PR 6 criterion 7 as wrong for requiring the bootstrap block title to
name issue #253, on the grounds that row 2.23 asks only that the title claim no
match. The lens reads only the test-spec. `spec.md` requires the issue number
at both sites:

- `spec.md:590` (§V.4, JKn): "Name the disagreement and name issue #253."
- `spec.md:617` (§V.5, bootstrap): "the title names the disagreement and issue
  #253"

So PR 6's criterion is correct. **PR 5's criterion is the incomplete one** — it
drops the issue number from the JKn title requirement. And row 2.23
under-specifies against `spec.md` §V.4, so a JKn or bootstrap title missing
`#253` passes a tester who reads only the test-spec.
Class: plan defect at PR 5, plus a test-spec erratum at row 2.23.

### S — Spec coverage lens

**S1. The "never assert one side's stored scale against the other side's"
bullet is unchecked as rule text.** `spec.md` §III.2 ships it as one of three
further constraints. PR 1's criteria name the other two and skip this one. No
other PR names it. `test-spec.md` §6 carries no row for it, and `spec.md` §VIII
gate 10 does not list it either. The code-behaviour version of the same rule is
covered — PR 8 criterion 6, row 2.6 — but the shipped prose is not.
Class: test-spec gap, and a gap in spec gate 10.

**S2. Rule 4's confidence-bound precondition paragraph is unchecked.** The
paragraph on degrees of freedom, `qt()` at infinite df, and the binding on a
later PR that moves to design-based df. PR 1 task 3 writes it; no criterion
checks it. The plan's row-allocation table stretches row 6.4 to cover "Rule 4
and its precondition", but row 6.4's own text is only "Assert the standard
error, not the point estimate alone".
Class: test-spec gap, and one over-reach in the plan's allocation table.

**S3. One of JK1's three required removals is unchecked.** `spec.md` §V.2 names
three things that come out and do not come back. PR 4 criterion 1 and criterion
5 cover the `scale` argument and the `suppressWarnings()` call. Neither covers
the two lines that compute `(n_rep - 1L) / n_rep` in the block body — which are
surveycore's own default formula restated, and the reason the block was a round
trip. PR 4 task 3 names the removal.
Class: plan defect.

**S4. The stored-scale comment's third required element is unchecked.**
`spec.md` §IV.3 requires the comment to say three things: it guards `survey`'s
default; a failure means `survey` changed; and it names the standard-error and
variance tolerance row, so a later editor does not widen it. Every criterion
that touches the comment — PR 3, PR 4, PR 5, PR 6, PR 7 — requires the first
two and not the third.
Class: plan defect, repeated across five entries.

### D — Dependency ordering lens

The order itself is sound. Both findings are defects in how the plan explains
its own constraints.

**D1. Ordering constraint 1 pairs the wrong PR with the wrong row.** The plan
justifies "PR 4 ships before PR 9" by citing row 6.15. Row 6.15 names the
pinned and Fay blocks, which PRs 5, 6 and 8 create. The dependency row 6.15
creates is "PRs 5, 6 and 8 ship before PR 9". The stated constraint is true for
a different reason and is subsumed by constraint 4, "PR 9 ships last".

**D2. The list of four hard constraints omits PR 7 before PR 8.** `spec.md` §II
fixes the order of the four new blocks under one `# Block 24:` header as JKn,
bootstrap, `other`, Fay, and forbids interleaving. That forces PR 7 before
PR 8. The stated sequence satisfies it, so no defect reaches the shipped order,
but the list is incomplete by its own claim to enumerate the hard constraints.

## What the lenses confirmed

Recorded so a later pass does not re-derive it.

- All nine entries sit inside both bounds. Maximum 10 rows against a bound of
  12; seven entries sit at the criteria bound of 8.
- The 67-row allocation is exact: every row claimed once, none twice, none
  unclaimed. §6's rows run out of order across two tables and still cover 6.1
  to 6.17 with no gap.
- §5's power proof is self-contained in PR 4, which rewrites JK1 before running
  it. §4's probe sits at PR 7, the first point at which all eight numerical
  types exist. Row 2.18's "13 of 13" also lands at PR 7, because `other` is the
  thirteenth numerical block.
- No PR edits a site an earlier PR delivered and asserted. PRs 1, 2 and 9
  append to the rule file in `spec.md` §III.2's own document order and never
  rewrite each other.
- The union of write surfaces is the two files and nothing else. No
  `helper-*.R`, no `_snaps/`, no third file. `tests/testthat/test-conversion.R`
  appears in no write surface.
- Every PR carries the `air format --check` gate and a `git diff --name-only`
  check.
- PR 4's power proof edits an `R/` default and reverts it with a `git status`
  check. That is `test-spec.md` §5's own required procedure, not a shipped
  source change.

## The decision this pass cannot make

Six findings — A1, A3, A5, S1, S2, and the row behind S4 — need a row in
`test-spec.md` that does not exist. `test-spec.md` froze at SPEC_READY.

Two ways to close them:

1. **Amend `test-spec.md`.** Add rows for the section placement, the
   hard-coded count, the two uncovered rule-text items, and the comment's
   tolerance-row element; correct row 2.23 to carry the issue number that
   `spec.md` §V.4 and §V.5 require. Log each as an erratum. Precedent:
   `archive/svydesign-replicate-bridge/` D17 corrected a frozen `spec.md`
   erratum at archive time and recorded it.
2. **Carry the requirements in the plan only.** The criteria state them and
   cite `spec.md`. The tester, who reads only the test-spec, cannot check them.

Option 1 closes the gap where the tester will look. Option 2 leaves six
requirements unverifiable by the agent whose job is to verify them.

## Next

Stage 3 resolves A2, A4, S3, S4, D1 and D2 without a decision — each is a
wording fix inside the plan. The six that need a test-spec row wait on the
decision above.

One interaction constrains every fix: seven of the nine entries sit at the
criteria bound of 8. A new criterion pushes an entry over budget, so most fixes
must tighten existing criterion wording rather than add a criterion. Where a
new check is genuinely needed, consolidate two criteria or split the entry.

---

# Pass 2 — delta

**Date**: 2026-09-16
**Scope**: the sections the resolver changed, plus the eleven findings
**Agents**: two, inside the pass-2 budget
**Verdict**: **PASS**. No finding required a change to either artifact, so the
loop exits at pass 2 of a maximum 3.

## What ran

| Lens | Scope | Verdict | Findings |
|---|---|---|--:|
| PR budget, delta | Row count, PR map, row allocation, budget summary | PASS | 0 |
| Acceptance criteria and spec coverage, delta | The eleven findings, the five new rows | PASS | 0 |

D1 and D2 were verified in session, not delegated. Constraint 1 now states its
two dependencies apart with the right row behind each, and says which pairing
was wrong. PR 7 before PR 8 is in as constraint 4. "PR 9 ships last" renumbered
from 4 to 5, and a grep found no surviving reference to the old number.

## The budget after the amendments

72 rows, up from 67. Recomputed independently and matching the plan's own
figures at every entry.

| PR | Rows (bound 12) | Criteria (bound 8) |
|--:|--:|--:|
| 1 | 12 | 7 |
| 2 | 6 | 7 |
| 3 | 7 | 8 |
| 4 | 10 | 8 |
| 5 | 3 | 8 |
| 6 | 10 | 8 |
| 7 | 6 | 8 |
| 8 | 10 | 8 |
| 9 | 8 | 8 |
| Total | 72 | 70 |

PR 1 was the entry at risk. Three new rows put it at the row bound, and the
consolidation held its criteria at 7: one criterion now covers all three of
`spec.md` §III.2's further constraints, citing rows 6.6, 6.16 and 6.19, and it
closes with "A section carrying two of the three fails this criterion". No
split was needed and the map keeps nine entries.

## The one trap in the amendments, checked

Row 2.25 forbids a line that computes surveycore's own default scale formula in
the JK1 block body. `spec.md` §III.2 requires the same formula as an assertion
literal in that same block, and row 6.16 states that carve-out. A row written
as a bare search for the formula would have forbidden what the spec requires.

The delivered row distinguishes the two uses, cites row 6.16 by name, and its
Expected value reads "0 lines that compute the scale; the assertion literal is
not a hit". Verified in session against the file.

## Row 2.23, tighter than briefed

The correction requires issue #253 on the JKn and bootstrap titles only. It
states that the Fay title carries no issue number, because `spec.md` §V.9 puts
#243 in the Fay comment. Expected: "3 of 3 claim no match; 2 of 2 name #253".

## Amendment count

Seven, not six. Row 2.25 was added beyond the six the user was asked about,
because finding S3 has the same shape as the other five — a `spec.md`
requirement with no row to check it. `decisions.md` E6 records the extension.

## Left alone, deliberately

`spec.md` §VIII gate 10 lists what the rule section must carry and omits both
the stored-scale bullet and the confidence-bound precondition. The user chose
not to amend `spec.md`. The omission costs nothing: §IV says §III.2 governs,
and the builder ships §III.2's text with formatting changes only, so the
content lands. Rows 6.19 and 6.20 close the checking gap. `decisions.md` E15
records it, and a note under the plan's gate table stops a reviewer reading the
two extra items as scope creep.
