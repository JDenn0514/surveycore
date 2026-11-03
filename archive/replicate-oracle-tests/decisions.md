# Decisions — replicate-oracle-tests

Append-only. Each entry records a HOLD raised in Stage 0 and how the user
resolved it. The measured facts each decision rests on are in
`comprehension.md` §Open questions and in `measurements.md`.

## HOLD — planner — 2026-09-16 (O2) — RESOLVED

**Where**: Stage 0, every new oracle block in
`tests/testthat/test-variance-replicate.R`
**What**: Issue #256 says each block must assert the `survey` warning "by class".
Measured: every condition in `survey:::svrepdesign.default` is a bare
`warning()` or `stop()`, so the only class available is `simpleWarning` or
`simpleError`. Twelve warning branches and two stops all came back the same.
**Why I can't decide**: The issue's own rule cannot be followed as written, and
choosing what replaces it changes what the test proves.
**Options**: assert the message text; assert `class = "simpleWarning"`; assert
both.

**RESOLUTION — user, 2026-09-16: assert the message text.**

Each block uses `expect_warning(regexp = )` with a literal fragment of the
`survey` message. The text names which branch of `svrepdesign()` fired;
`simpleWarning` does not, because it also matches the
`"Data do not look like combined weights"` warning that signals a broken fixture.

Two constraints carry into the spec:

1. The test-spec records that no typed class exists, so a later reader does not
   file the missing `class =` as a defect against `.claude/rules/code-style.md`.
   That rule governs surveycore's own conditions, not another package's.
2. The regexp must not key on the string `JK1` alone. Measured (G4b): a supplied
   `rho` on JK2, JKn, ACS or successive-difference raises
   `rho not relevant to JK1 design: ignored.`, because `survey` hard-codes the
   name for five types. Blocks supply no `rho`, so the branch stays unreached,
   but a future edit could reach it.

## HOLD — planner — 2026-09-16 (O3) — RESOLVED

**Where**: Stage 0, the JKn and bootstrap blocks
**What**: Both types disagree with `survey` today, by 2.53% on the SE. The
user's earlier decision wraps the failing assertion in
`testthat::expect_failure()` to keep CI green. Measured: one wrapper round three
failing expectations fails, because `expect_failure()` passes on exactly one
failure and zero successes.
**Why I can't decide**: The acceptance criterion asks for four quantities per
block, and the wrapper mechanics forbid the obvious shape.
**Options**: three separate wrappers; point estimate plus one wrapped SE, CI
deferred; skip the two blocks.

**RESOLUTION — user, 2026-09-16: three separate wrappers.**

Each of the two blocks carries:

- a bare `expect_equal()` on the point estimate, outside any wrapper — measured,
  the means agree exactly, so a wrapped point estimate would itself fail;
- `expect_failure()` round the SE assertion;
- `expect_failure()` round the `ci_low` assertion;
- `expect_failure()` round the `ci_high` assertion;
- a comment naming issue #253 and stating that PR 3 of the arc deletes the three
  wrapper lines.

Measured constraints the builder must respect:

- A wrapper round zero expectations fails, so no wrapper may be left empty.
- An R warning raised inside a wrapper escapes it. The `svrepdesign()` call and
  its `expect_warning()` stay outside every wrapper.
- `expect_warning(expect_failure(...))` passes; `expect_failure(expect_warning(...))`
  fails, because `expect_warning()` adds an expectation of its own.
- `expect_equal(tolerance = )` composes inside a wrapper.

## HOLD — planner — 2026-09-16 (O5) — RESOLVED

**Where**: Stage 0, the Fay block
**What**: `survey` refuses `type = "Fay"` without `rho`, which issue #243 adds
as PR 4 of the arc. PR 1 cannot write a Fay oracle block.
**Why I can't decide**: Whether the file ships eight blocks or nine changes what
the suite records about the gap.
**Options**: eight blocks and a comment; a ninth block asserting the refusal.

**RESOLUTION — user, 2026-09-16: a ninth block asserting the refusal.**

The block asserts that `survey::svrepdesign(type = "Fay")` with no `rho` raises
an error matching `With type='Fay' you must supply the correct rho`, and that
surveycore accepts the same call and stores `scale = 1/R`. That pins both halves
of the gap #243 closes. The block names #243 in a comment. PR 4 rewrites it into
a real oracle block.

## Decision — leader — 2026-09-16 (O4)

**Where**: Stage 0, the `other` block

`make_survey_data()` has no `other` mode, so the block builds `type = "other"`
on top of the `jk1` replicate columns, the way the current JK2 block builds on
`jk1` columns. Measured (M1, M2): both sides then carry `scale = 1` and
`rscales = rep(1, R)`, and `survey` warns
`scale or rscales not specified, set to 1`.

The block supplies neither `scale` nor `rscales`. Measured: supplying both
silences that warning and makes `survey` honour the supplied values, which
restores the round trip this issue exists to remove.

Routine call, taken by the leader rather than the user. `comprehension.md` §O4
calls it cheap and names no competing option.

## Decision — user, before Stage 0 — 2026-09-16

The JKn and bootstrap blocks keep CI green with `testthat::expect_failure()`
rather than landing genuinely red, as issue #256 proposes. Branch protection
makes a red PR 1 unmergeable, and every later PR in the arc would need an
override until #253 lands. O3 above settles the shape.

## HOLD — spec review — 2026-09-16 (U1) — RESOLVED

**Where**: Stage 3, `spec.md` §IV.3 item 5, all eight numerical blocks
**What**: The spec adds a fifth assertion — assert `survey`'s stored scale
against a literal. Lens 5 called it scope creep and recommended dropping it: it
detects a change in `survey`'s defaults, not a wrong surveycore default, which is
a different question from the one issue #256 asks.
**Why I can't decide**: The lens argues against the spec author's own deliberate
addition, and the arc is carefully scoped PR by PR.
**Options**: keep; drop; drop and file separately.

**RESOLUTION — user, 2026-09-16: keep it, with two additions.**

The assertion pins the oracle side. Without it, a future `survey` release that
changes a default moves the target surveycore is measured against, silently.

Two things it must carry:

1. A named tolerance. §IV.3 tells the builder not to invent one, and the tolerance
   table has no row for a stored scale. Name the row it uses.
2. A comment saying it guards `survey`'s default, so a failure is not read as a
   surveycore regression.

## HOLD — spec review — 2026-09-16 (U2) — RESOLVED

**Where**: Stage 3, `spec.md` §IV.4
**What**: `.claude/rules/testing-surveycore.md` requires one `test_invariants()`
call per constructor per file. `test-variance-replicate.R` calls it zero times.
§IV.4 says adding one "is permitted" — a ceiling with no floor — and no quality
gate checks it. Lenses 2, 3 and 5 each raised it.
**Why I can't decide**: Closing pre-existing debt inside a scoped PR is the
user's call, not the reviewer's.
**Options**: add one call now; defer with an issue; leave the wording.

**RESOLUTION — user, 2026-09-16: add one call in this PR.**

One `test_invariants()` call, in the first block that builds a design, plus a
quality gate so it is checkable. The file is already open, and the call is
measured elsewhere to move coverage 0.0000 points, so it costs one line.

§IV.4 changes from a permission to a requirement, and names the block.

## Decision — leader — 2026-09-16 (block titles, R5)

The three blocks that do not agree get titles that say so. The file's convention
is "X matches Y", which would assert the opposite of what the JKn, bootstrap and
Fay blocks prove. Those three titles name the disagreement or the refusal. The
house rule already requires a title to be a present-tense assertion of one
observable behaviour, so a title claiming a match the block does not make is a
breach of it.

Routine call, taken by the leader.

---

# Stage 3 resolve — plan review pass 1

Plan review pass 1 returned FAIL with 11 findings. Six of them needed a row in
`test-spec.md` that did not exist, and the document had frozen at SPEC_READY.
The user approved amending it and logging each amendment as an erratum. The
records below cover the seven amendments, the budget calls the fixes forced, and
two things left alone on purpose.

`spec.md` is unchanged. Where it disagreed with `test-spec.md`, `spec.md` won.

## Decision — user, 2026-09-16 (E1) — amend the frozen `test-spec.md`

The alternative was to carry the six requirements in `implementation-plan.md`
only. The tester reads the test-spec and the criteria, not `spec.md`, so that
choice would leave six `spec.md` requirements unverifiable by the agent whose
job is to verify them.

Precedent: `archive/svydesign-replicate-bridge/` D17 corrected a frozen
`spec.md` erratum at archive time and recorded it in a table with a Location, a
Correction and an Authority column. `test-spec.md` §Errata applied after
SPEC_READY follows that shape.

## Decision — planner, 2026-09-16 (E2) — new row 6.18, the heading and its place

**Authority**: `spec.md` §III.1.

§III.1 fixes both the heading and the position: after §The both-modes rule and
before §S7 error testing layers. §6's preamble said "Check that the section
states each of the thirteen points below", so every §6 row read content and none
read placement. The section could have landed anywhere in the file, under any
heading, and passed §6 whole.

Row 6.18 goes in §6's second table, which holds checks on the section rather
than points the rule states. Allocated to PR 1, which writes the heading.

## Decision — planner, 2026-09-16 (E3) — new row 6.19, the stored-scale bullet

**Authority**: `spec.md` §III.2, the first of the three further constraints.

The rule text ships the bullet "Never assert one side's stored scale against the
other side's. Assert each against a literal." The code-behaviour version of the
same rule already had a row — 2.6, allocated to PR 8 — but the shipped prose had
none, and `spec.md` §VIII gate 10 does not list it either. PR 1's criteria named
the other two further constraints and skipped this one.

Row 6.19 goes in §6's first table, after 6.16. Allocated to PR 1.

## Decision — planner, 2026-09-16 (E4) — new row 6.20, the bound precondition

**Authority**: `spec.md` §III.2, the paragraph that follows rule 4.

Three things the paragraph fixes: both sides build the interval from the same
distribution and the same degrees of freedom; both use the normal approximation
today; and a later PR that moves the replicate path to design-based degrees of
freedom must revisit `tests/testthat/test-variance-replicate.R` in the same PR.

PR 1 task 3 wrote the paragraph and no criterion checked it. The plan's
allocation table stretched row 6.4 to cover "Rule 4 and its precondition", but
6.4's own text is only "Assert the standard error, not the point estimate
alone". That over-reach is corrected: 6.4 now reads "Rule 4" and 6.20 carries
the precondition.

The cost of the gap is specific. When the degrees of freedom move, every
confidence-bound assertion in the block set fails at once, and the failure has
the same shape as a scale defect. `test-spec.md` §8 already explains how to tell
the two apart. Without the clause in the shipped rule, a later reader has to
find that explanation in a dead spec.

Row 6.20 goes in §6's first table, after 6.19. Allocated to PR 1.

## Decision — planner, 2026-09-16 (E5) — new row 2.24, the replicate count

**Authority**: `test-spec.md` §1's own prose, and `spec.md` §IV.1.2.

§1 says "A block that hard-codes a replicate count is a defect. Every block must
read the count from the selected columns", and carried no numbered row. The
requirement is real: the generator returns `n_psu / 2` columns for the `brr` and
`fay` modes and `n_psu` for the rest, so a hard-coded count breaks on a mode
change.

Row 2.24 goes in §2, after 2.23. Allocated to PR 3, the first PR that writes a
replicate-count expression into the file. PR 4 to PR 8 repeat the check over the
blocks they write; the plan carries it as standing gate 8.

The plan's table of unnumbered sections omitted §1. That is corrected in the
same edit: §1 is now listed, with a note that row 2.24 carries its one
checkable requirement.

## Decision — planner, 2026-09-16 (E6) — new row 2.25, JK1's third removal

**Authority**: `spec.md` §V.2, the first of the three removals.

**This row goes beyond the six the review named, and the user was not asked
about it directly.** I added it because finding S3 has the same shape as the
other five — a `spec.md` requirement with no row — and the user's answer covers
the direction. The amendment count went from six to seven. A later reader should
know which one I added on that reading.

§V.2 names three things that come out of the JK1 block and do not come back: the
two lines that compute `(n_rep - 1L) / n_rep` in the block body, the `scale =`
argument, and the `suppressWarnings()` call. Rows 2.2 and 2.5 covered the second
and third. The first is the reason the block was a round trip, and it had no
row: a block keeping the two computed lines could pass 2.2 and 2.5 and still
restate surveycore's own default formula.

Row 2.25 carries the carve-out row 6.16 states, so the two do not conflict. The
formula is banned as an argument and required inside the stored-scale assertion,
in the same block. The row's Expected reads "0 lines that compute the scale; the
assertion literal is not a hit".

Row 2.25 goes in §2, after 2.24. Allocated to PR 4, which rewrites the block.

## Decision — planner, 2026-09-16 (E7) — row 2.18 corrected

**Authority**: `spec.md` §IV.3, the stored-scale comment.

§IV.3 requires the comment to say three things: it guards `survey`'s own
default; a failure means `survey` changed and not that surveycore regressed; and
it names the standard-error and variance tolerance row, so a later editor does
not widen it. Row 2.18 counted the comments, 13 of 13, and asked for the first
two elements only.

The third element is the one with a cost. With no tolerance note in the comment,
a later editor meeting a red stored-scale assertion can widen `1e-8` and leave
the assertion in place. The block then passes and pins nothing.

Row 2.18 now requires all three, and its Expected reads "13 of 13, each with all
three elements". Five plan entries — PR 3, PR 4, PR 5, PR 6, PR 7 — required the
first two elements and not the third. All five are tightened in place. None
gained a criterion: all five sit at or near the criteria bound of 8.

## Decision — planner, 2026-09-16 (E8) — row 2.23 corrected

**Authority**: `spec.md` §V.4 at line 590 and §V.5 at line 617; `spec.md` §V.9
for the Fay carve-out.

§V.4 says "Name the disagreement and name issue #253". §V.5 says "the title
names the disagreement and issue #253". Row 2.23 asked only that the three
titles claim no match, so a JKn or bootstrap title with no issue number passed a
tester who reads only the test-spec.

The review's own lens finding was inverted here. It reported PR 6's criterion as
wrong for requiring the issue number. PR 6 is correct and PR 5 is the incomplete
one. The lens reads only the test-spec, and the test-spec was the document with
the defect.

Row 2.23 now requires the issue number on the JKn and bootstrap titles, at "2 of
2", and keeps "3 of 3" for the no-match check. **The Fay title gains no issue
requirement.** §V.9 asks only that the title name the refusal, and #243 sits in
the Fay comment, which row 2.12 already checks. Inventing a title requirement
`spec.md` does not state would be a second defect.

Two plan entries changed: PR 5's criterion 7 gains the issue number for the JKn
title, and PR 8's criterion 7 gains the "2 of 2" count, because PR 8 is where
row 2.23 counts. PR 6's criterion 7 was already correct and is untouched.

## Decision — planner, 2026-09-16 (E9) — the §6 counts restated

`test-spec.md` §6's preamble said "each of the thirteen points below" and §10's
verdict rule said "missing any of the thirteen points in §6". Thirteen was the
first table's row count, not §6's, which was seventeen. The two figures had
already drifted apart before this pass.

Rather than replace one bare count with another, the preamble now names both
tables and both counts: fifteen points the rule must state, five further checks
on the section. §10 cites both. That removes the ambiguity that let the drift
happen.

## Decision — planner, 2026-09-16 (E10) — PR 1 consolidates two criteria

**The figure that forced it.** Rows 6.18, 6.19 and 6.20 all belong to PR 1,
which writes §III.2's core text. PR 1 went from 9 rows to 12, which is at the
row bound and inside it. Its criteria stood at 7. Findings S1 and S2 each needed
coverage, and 7 plus 2 is 9, over the criteria bound of 8.

**The consolidation holds.** PR 1's criteria 4 and 5 covered two of §III.2's
three further constraints separately: the message-text constraint at row 6.6 and
the argument-versus-literal bullet at row 6.16. Those two and the new 6.19 are
now one criterion covering all three further constraints, citing 6.6, 6.16 and
6.19. That is 7 minus 2 plus 1, which is 6. The freed slot becomes criterion 5,
the precondition paragraph at row 6.20. Row 6.18 folds into criterion 1, which
already stated the heading and the placement and now cites the row.

PR 1 reads **12 rows and 7 criteria**. Both inside the bounds. No split was
needed, so the PR map keeps nine entries and no renumbering happened.

The consolidated criterion states "A section carrying two of the three fails
this criterion", so merging three checks into one criterion loses no rigour.

## Decision — planner, 2026-09-16 (E11) — D1, ordering constraint 1 restated

**Restated, not dropped.**

The constraint read "PR 4 ships before PR 9" and cited row 6.15 for it. Row 6.15
names the two sanctioned exceptions — the JKn and bootstrap wrappers and the Fay
block — which PR 5, PR 6 and PR 8 create. PR 4 touches none of them. The
citation was wrong.

Constraint 1 now states two dependencies apart:

1. PRs 5, 6 and 8 ship before PR 9, because row 6.15 names the blocks they
   create.
2. PR 4 ships before PR 9 for its own reason: row 3.5.1 reads the finished file,
   and the JK1 and JK2 rewrites must be in it.

I restated rather than dropped, although constraint 5 ("PR 9 ships last")
subsumes both under the stated order. The reason: the list claims to enumerate
the hard constraints, and a reader who reorders the PRs needs to know which
dependency each one rests on. The wrong pairing also survives in the review
record, so the plan says plainly which pairing was wrong.

## Decision — planner, 2026-09-16 (E12) — D2, PR 7 before PR 8 added

The hard-constraints list had four entries and omitted PR 7 before PR 8.
`spec.md` §II fixes the order of the four new blocks under one `# Block 24:`
header as JKn, bootstrap, `other`, Fay, and forbids interleaving. PR 7 writes
the `other` block and PR 8 writes the Fay block, so the file order forces the PR
order.

The stated sequence already satisfies it, so no defect reached the shipped
order. The list was incomplete by its own claim. It now has five entries, and
"PR 9 ships last" renumbered from 4 to 5.

## Decision — planner, 2026-09-16 (E13) — A2, PR 2's criterion 2 reworded

The criterion read "A probe on the installed `survey` reproduces all nine rows
of that table". That states what the builder does. A tester cannot check it by
reading either delivered file.

The probe stays as PR 2 task 1 and task 2. The criterion now reads as an
artifact outcome: every row of the delivered table is identical to the
corresponding row of `spec.md` §III.3, and no cell was edited to match a moved
oracle. The disagreement rule moved to where it belongs — on a disagreement the
PR description reports the row, the installed `survey` version and the measured
value, and the delivered table still carries the spec's row.

PR 2 keeps 6 rows and 7 criteria.

## Decision — planner, 2026-09-16 (E14) — A4, PR 3's tail clause dropped

PR 3's criterion 1 ended "and the file runs with 0 failures". That reads the file
mid-arc, at 26 blocks, and no row covers that state. Row 3.5.1 reads the
finished 28-block file and is allocated to PR 9. Standing gate 3 already runs
the full suite on every PR.

The clause is dropped and nothing replaces it. PR 3 keeps 8 criteria.

## Decision — planner, 2026-09-16 (E15) — what was left alone on purpose

**`spec.md` §VIII gate 10 stays as written.** Gate 10 enumerates what the rule
section must carry, and it omits two things §III.2 ships: the "never assert one
side's stored scale against the other side's" bullet and rule 4's
confidence-bound precondition. The user chose not to amend `spec.md`.

The omission is known and it costs nothing. `spec.md` §IV says §III.2 governs
and that §IV dies with the spec, so §III.2 is the authority on what the section
carries. The builder ships §III.2's text with formatting changes only, per PR 1
task 2 and task 3, so both items land whatever gate 10 lists. New rows 6.19 and
6.20 close the checking gap, and both land at PR 1.

`implementation-plan.md` §Spec quality gates against the PR map now records this
under the gate table, so a reviewer comparing gate 10 against the delivered
section does not read the two extra items as scope creep.

## Decision — planner, 2026-09-16 (E16) — the row allocation re-derived

The row total rose from 67 to 72. I re-derived the allocation from scratch rather
than patching the old one.

| Section | Rows | Claimed |
|---|--:|---|
| §2 2.1 to 2.25 | 25 | each once |
| §3.1 3.1.1 to 3.1.9 | 9 | each once |
| §3.5 3.5.1 to 3.5.6 | 6 | each once |
| §3.6 3.6.1 to 3.6.4 | 4 | each once |
| §4 4.1 to 4.3 | 3 | each once |
| §5 5.1 to 5.5 | 5 | each once |
| §6 6.1 to 6.20 | 20 | each once |
| **Total** | **72** | |

Per PR: 12, 6, 7, 10, 3, 10, 6, 10, 8. That sums to 72, which matches the
section total. No row is claimed twice and none is unclaimed. Every entry sits
inside both bounds. PR 1 sits at the row bound of 12; seven entries sit at the
criteria bound of 8.

---

# Decisions recorded during the build

## Decision — leader, 2026-09-22 (S1) — the R gates carry forward on the three rules-only PRs

PRs 1, 2 and 9 write `.claude/rules/testing-surveycore.md` and nothing else.
On those three the seven R gates are not re-run. The baseline figures stand as
the PR's figures. This is a measurement, not an assumption, and it rests on two
facts:

1. `.Rbuildignore` carries the line `^\.claude$`, so `R CMD build` excludes the
   whole directory. Gates 4, 5 and 6 cannot see the change.
2. No test opens the file at run time. `grep -rn "\.claude" tests/ R/` returns
   five hits and every one is a comment citing a rule.

The reviewer of PR 1 re-measured this independently and reported the `R`,
`tests` and `man` subtree hashes identical from base to head — `3146b739`,
`1d03c325`, `f82e32a6`. Identical subtrees mean gates 1, 2, 3 and 7 would run
identical code over identical inputs, so a re-run measures machine noise.

The cost this avoids is not small. A full gate pass is about 20 minutes, and
the machine holds ~1.8 GB free against a watchdog that has killed `covr` and
`R CMD check` mid-run on earlier arcs. Three avoided passes is an hour of gate
time and three chances to corrupt a log set.

The six test-file PRs — 3 to 8 — get a full gate pass each. They write
`tests/testthat/test-variance-replicate.R`, which is inside the package and
inside the suite.

Recorded so a later reader does not read the missing gate logs on PRs 1, 2 and
9 as a skipped step.

## Decision — leader, 2026-09-22 (S2) — the rules file's `Version:` header bumps once, at PR 9

`.claude/rules/testing-surveycore.md` opens with `**Version:** 1.2` and
`**Status:** Decided — do not re-litigate without updating this document`. Three
PRs in this arc add content to that file. The PR 1 builder left the header at
`1.2` and asked to be overruled if that was wrong.

It was not wrong for PR 1. The reviewer grepped `spec.md`, `test-spec.md` and
`implementation-plan.md` and found no bump required by any of the three, and no
§6 row that checks it. The `**Target version:** 1.1.0.9000` line in `spec.md`
is the `DESCRIPTION` field, which is a different thing and which this arc does
not move.

The header should still end the arc accurate. A reader who sees `1.2` after
three PRs added a major section cannot tell the file changed. So the bump to
`1.3` happens once, at PR 9, as the arc's last edit to the file.

PR 9's plan entry does not mention a bump, and its builder will not invent one.
PR 9 also sits at the criteria bound of 8, so a ninth criterion would put the
entry over budget. The bump therefore folds into PR 9's existing criterion 2 as
an added clause rather than becoming a criterion of its own — the same shape the
plan used at PR 4, where row 2.25 folded into criterion 1 for the same reason.

This is the leader's call and it widens PR 9 by one line. Anyone who wants the
header left at `1.2` should say so before PR 9 is dispatched.

## Decision — reviewer and leader, 2026-09-22 (S3) — the per-type table's fifth column is a planner erratum

`test-spec.md` row 6.9 points at a §7 table of **five** columns. `spec.md`
§III.3 holds **four**. The fifth is `Condition on a bare call`, and the rule
file `.claude/rules/testing-surveycore.md` does not carry it.

The PR 2 builder shipped the spec's four columns, which is what §III.2's "Use
this text ... Adjust nothing but formatting" required of it. The PR 2 tester
passed row 6.9 but escalated the gap, because settling it needs `spec.md` and a
tester may not read it. The reviewer settled it: **erratum in the test-spec, not
a defect in the PR.**

Two reasons the resolution goes this way and not the other:

1. `test-spec.md` §7 opens "Use this to judge §3.1 and §6.9". The column exists
   so a tester can judge a block's condition assertion. It was never a column
   the rule file was asked to carry.
2. The conditions material that PRs 3 to 8 need lives in `spec.md` §V.1 to §V.9
   and in `test-spec.md` §3.1. Both are documents a block author reads. The rule
   file is not one of them, so nothing downstream looks for the column here.

Read row 6.9 as "the delivered table matches §7 on the three supplied-argument
columns". All 27 cells inside that scope are character-identical to §7.

Adding the fifth column to the rule would need a `spec.md` §III.3 amendment,
which is PR 9's business at the earliest and is not required by any row. It is
not scheduled.

## Finding — reviewer, 2026-09-22 (F2) — the per-type table's `other` row reads as silent

Carried from PR 2's review, for PR 9's reader. Not a defect and not scheduled
work.

Four rows of the §III.3 table write "warn, discard" in the supplied-`scale`
column. The `other` row writes "honoured". A reader can infer from the contrast
that `other` is silent when a `scale` is supplied. It is not. The PR 2 probe
measured `other` storing a supplied `scale` **and** still raising
`scale or rscales not specified, set to 1`.

The table is not wrong. Its column asks what `survey` does with a supplied
value, and `other` honours it. The asymmetry is in `spec.md`'s wording, not in
the builder's transcription.

Three things already stop a block author acting on the wrong inference: rule 5
requires asserting whatever condition fires; the snapshot paragraph tells the
author to re-probe the installed version before writing a block; and the fact
is recorded in `comprehension.md` §G4 and asserted at `test-spec.md` row 3.1.8,
which PR 7 satisfies when it writes the `other` block.

PR 7's dispatch should state the fact directly, because PR 7 is told to supply
neither `scale` nor `rscales` and its block asserts exactly one warning.

## Decision — reviewer and leader, 2026-09-22 (S4) — the stored-scale comment breaks the 80-column rule, and the arc accepts it

The comment above every stored-scale assertion is 99 characters:

```r
    # Guards survey's default; a failure means survey changed, not surveycore; SE/variance row, 1e-8.
```

`.claude/rules/code-style.md` sets the line length at 80, and `.lintr` encodes
it with `line_length_linter(80)`, excluding only `data-raw`. So `tests/` is in
scope and this is a real rule, not a preference.

**The 80-column limit and row 2.18's three elements cannot both be met.** The
leader challenged the builder's "pick one" framing and offered a 75-character
counter-example. The reviewer measured it and the challenge failed: counting
the two-space indent, and keeping the canonical wording — a verb on element 1,
"changed, not surveycore", "SE row" — the shortest plain-prose form carrying
all three elements is **82 characters**. Every form at 80 or under drops the
verb, or "changed", or "SE row", or gives up plain prose for `=`. The leader's
draft dropped the verb and used `=`.

So the choice is not "which rule yields" but "which element of the comment
yields", and the answer is none. Decision E7 raised row 2.18 to three elements
deliberately, and PR 7 must count 13 of 13 comments each carrying all three. A
weakened element costs more than the lint breach.

Two further reasons the breach is tolerable here:

- `air format --check` is the formatting authority the plan chose — row 2.14
  names it — and it passes, because `air` does not rewrap comments.
- `lintr` is in none of the seven profile gates and none of the seven CI
  checks, so nothing automated reads the limit.

The comment stays at 99 and is **not** shortened to 82. Seventeen characters
buys nothing when neither form complies, and re-opening a reviewed PR to get
there would cost a builder cycle and a full gate pass.

**Every later PR uses this exact text, character for character.** Row 2.18
counts 13 comments at PR 7 and asks that each carry all three elements; 13
identical comments make that checkable by `grep -c`, and 13 paraphrases do not.
PRs 4, 5, 6, 7 and 8 each get the literal string in their dispatch.

## Finding — reviewer, 2026-09-22 (N1) — the two oldest BRR blocks pass `mse` to one side only

Not a defect in PR 3, and not repaired by it.

The BRR blocks at lines 12 and 55 pass `mse` to `survey::svrepdesign()` but not
to `as_survey_replicate()`, which defaults it to `TRUE`
(`R/core-constructors.R:734`). The two sides agree today only because the
default happens to match what the block passes to `survey`.

`spec.md` §IV.2 requires `mse` "always, explicitly" on both sides, so these
blocks sit outside the contract. PR 3 was right to leave them: §V.1 says
"change nothing else", and no row this arc allocates covers the gap.

**The consequence is for PRs 4, 5, 7 and 8**, which write their blocks whole
rather than editing in place. Each must pass `mse` explicitly to **both**
sides — the surveycore constructor as well as `survey::svrepdesign()` — and not
copy the two old blocks' shape. Their dispatches say so.

A later arc may want to close the gap in the two old blocks. It is not this
arc's work and carries no issue number yet.

## Record — leader, 2026-09-22 (P1) — the power proof was re-run independently

`spec.md` §X argues the arc needs an independent tester because "a test that
passes for the wrong reason is exactly the defect this work removes". The same
argument reaches the power proof itself: a proof that is *reported* rather than
*verified* carries the same failure mode one level up.

So rows 5.1 to 5.3 were settled twice, by two agents, from two directions.

The **builder** broke `R/core-constructors.R:799` from
`JK1 = (n_rep - 1L) / n_rep,` to `JK1 = 1,`, ran the single file, and reverted
with `git restore`. It measured `FAIL 0 | WARN 1 | PASS 143` before and
`FAIL 3 | WARN 1 | PASS 140` after, with the three failures at lines 145, 146
and 147 — the standard error and both confidence bounds — and the
point-estimate assertion at line 144 still passing.

The **tester** could not check any of that. Re-running needs an edit under
`R/`, and a full gate pass was in flight, so it was barred from starting any R
process. It verified rows 5.4 and 5.5 directly — the `R/core-constructors.R`
blob and the `R`, `man`, `NAMESPACE` and `DESCRIPTION` subtrees identical base
to head — and marked 5.1 to 5.3 "not independently verifiable by the tester;
evidence is the builder's, for the reviewer to check". That was correct. It
neither passed them on the builder's word nor failed them for being
unverifiable.

The **reviewer** re-ran the experiment from scratch, with R free. It reproduced
`FAIL 3 | WARN 1 | PASS 140`, the same three line numbers, and the same values
to the digit — `0.2464`, `49.954`, `50.920` — with line 144 absent from the
failure list. It then restored, confirmed `git status --porcelain -- R/` empty,
the blob back at `066389be` and the tree back at `77ba0ec4`.

It also checked the arithmetic before running anything: all three failing
quantities move by exactly `1 / sqrt(19 / 20)`, which is what a scale changing
from `(R-1)/R` to `1` at `R = 20` must produce. The record was sound on its
face, and then sound in fact.

**Why this is worth recording.** The proof is the arc's only evidence that
these blocks can fail at all. Every other measurement shows them passing, and
a block that passes proves nothing about whether it *would* catch a wrong
default — that is the exact defect issue #242 survived 22 releases behind. Two
independent reproductions, agreeing to the digit, is the standard this one step
had to meet.

## Finding — reviewer, 2026-09-22 (N2) — line 174 carries no explicit tolerance

`expect_equal(sc@variables$scale, 1)` in the JK2 block asserts **surveycore's**
stored scale against a literal. It carries no `tolerance` argument, where the
neighbouring assertion of `survey`'s stored scale at line 196 carries
`tolerance = 1e-8`.

Not a defect and not PR 4's business. `spec.md` §IV.3 item 5 and gate 7 both
govern assertions of **`survey`'s** stored scale, and this asserts surveycore's.
The line is unchanged from the base, and §V.3 told the builder to keep the
block's existing assertion as it stood.

No numerical risk either: the value is the literal `1` from a `switch()` arm,
not a computed quantity, so the default tolerance cannot bite.

It should carry `tolerance = 1e-8` for symmetry with line 196. A later sweep
may add it. **Do not reopen PR 4 for it**, and do not let a PR 5 to 8 builder
"fix" it in passing — the file's write surface is allocated per PR and this
line belongs to none of them.

**Corrected at the arc's final review: N2 is three lines, not one.** The PR 9
reviewer measured the finished file and found `sc@variables$scale` asserted
against a literal with no `tolerance` at **lines 174, 379 and 400**. All three
are unchanged from the pre-arc baseline `7800ea9`, where they sat at lines 148,
330 and 351. None carries numerical risk — each expected value is a literal
from a `switch()` arm, not a computed quantity — and none is among the 13
assertions of **`survey`'s** stored scale that row 2.18 governs.

## Decision — reviewer and leader, 2026-09-23 (S7) — N1 and N2 get one GitHub issue between them

Both findings are out of this arc's scope and neither has an issue number. The
PR 9 reviewer recommends **one** issue, N1 as the body and N2's three lines as
a second bullet, and the reasoning is the part worth keeping:

> `decisions.md` gets archived, and a finding that lives only there is as
> invisible as no finding.

That is true of this repository's own history. `archive/haven-labelled/`
records seven SETTLED decisions citing nine documents the pipeline never
archived, and issue #217 exists because of it. A finding recorded only in a
run directory is one `git mv` away from being unreachable.

**N1 is the one that earns the issue.** The two oldest BRR blocks pass `mse` to
`survey::svrepdesign()` but not to `as_survey_replicate()`, so the two sides
agree only because the constructor's default happens to match what the block
passes to `survey`. **That is the exact shape this arc exists to remove** — a
block that is green because of a default nobody asserted. It is milder than
issue #242's round trip, since no number crosses between the sides, but it is
the same family: agreement resting on an unstated assumption rather than on two
independent computations.

N2 rides along as a second bullet. Three untoleranced assertions of
surveycore's own stored scale, no numerical risk today, worth fixing for
symmetry with the 13 that do carry a tolerance.

**Opened as issue #290** on 2026-09-23, on the user's explicit authorisation at
closeout: <https://github.com/JDenn0514/surveycore/issues/290>. N1 is the body,
N2 rides as a second section. The issue records the line numbers as of
`73879a0`, states that neither is a numerical defect today, and explains why
neither was repairable inside the arc — the file's write surface was allocated
per PR across nine PRs and these lines belong to none of them.

## Record — leader, 2026-09-23 (S8) — the PR 9 shipper was blocked, and the work was not routed around

After merging #289 the PR 9 shipper was denied four consecutive writes by the
auto-mode classifier, reason `[Merge Without Review]`. It had merged
successfully; the classifier appears to have latched onto the merge context,
because read-only commands kept working. Denied, in order: an `Edit` on both
plan copies, a second `Edit` on the run copy alone, a Bash fallback that staged
the edited file in a scratchpad for `diff` before moving it, and the first
`cat >>` chunk of `shipper.md`.

**It stopped after the fourth denial rather than look for a fifth route, and
left nothing half-written.** That was the right call and is worth recording as
the behaviour to expect from a blocked agent.

It then asked the leader to complete the writes. **The leader declined to do so
silently.** An agent blocked by a permission check asking another agent to
perform the same action is the shape of permission laundering, whether or not
the blocker was a decision of the user's — and here it plainly was not, since
the leader had written `decisions.md`, the budget ledger, `baseline.md`,
`RESUME.md` and nine `gates.md` files through the same session with no denial.

The leader surfaced the block to the user with the state of both items, and the
user authorised completing them. Both were then written by the leader:

- line 738 of both plan copies now reads `[x]`, verified byte-identical with
  `cmp`, 9 marked and 0 unmarked;
- `prs/pr-9-exceptions/shipper.md` exists and records the merge, the tree
  comparison, the arc's end state and this deviation.

The general point for a later run: **a permission boundary is a reason to ask,
not a reason to re-route.** The cost of asking was one round trip. The cost of
quietly completing a blocked agent's denied action is that the block stops
meaning anything.

## Decision — reviewer and leader, 2026-09-22 (S5) — S4 extends to the pinned blocks' titles

Decision S4 settled that the stored-scale comment stays at 99 characters,
because its three required elements do not fit in 80. The bootstrap block
raised the same conflict in a second place, and it resolves the same way.

The two pinned blocks' titles are:

```
get_means() JKn SE disagrees with survey::svymean() — issue #253
get_means() bootstrap SE disagrees with survey::svymean() — issue #253
```

The bootstrap one runs to 85 characters with its `test_that(` wrapper. The PR 6
builder first wrote it in `air`'s multi-line form; **`air` rejected that and
collapsed it back to one line**, because the overflow sits inside a string
literal and a string cannot be broken across lines. So the 80-column limit is
not reachable by reformatting — only by rewording.

A compliant rewording exists. Dropping the word "issue" gives 79 characters.
The reviewer ruled against it, and the reason is the stronger half of this
decision: **the two titles are word-for-word symmetric, and that symmetry is
load-bearing.** Nine of PR 6's ten rows read the two blocks as a pair. The
future PR under issue #253 deletes four lines from each. PR 9's row 6.15 names
both blocks as the sanctioned exceptions. Breaking the symmetry to save six
characters costs more than the lint breach.

Same authorities as S4: `air format --check` is the formatting authority the
plan chose — row 2.14 names it — and it exits 0. `lintr` encodes the 80-column
limit but is in none of the seven profile gates and none of the seven CI
checks.

The file now carries 24 lines over 80 columns, 12 of them the S4 comment. A
later arc that wants the repo lint-clean must change row 2.18's three-element
requirement first, then both titles and all 13 comments together. Doing it
piecemeal would break the exact-match counts that PR 7 relies on.

## Record — leader, 2026-09-22 (P2) — the sensitivity probe, verified twice

Rows 4.1 to 4.3 are the measured evidence for the arc's whole design. They
answer the question §IV.3 rests on: **what does a wrong stored scale actually
move?**

The experiment: for each of the eight numerical replicate types, build the
surveycore design the way its block does, double the design's stored scale, and
recompute the mean, the standard error and both confidence bounds.

Eight types out of eight, no departure:

| Measure | Result |
|---|---|
| Δ point estimate | `0`, with `identical(Δ, 0)` TRUE — bit for bit, not merely inside `1e-10` |
| SE ratio against `sqrt(2)` | largest departure `2.22044604925031e-16`, one machine epsilon |
| Smallest Δ SE | `0.0228242560289145` — 2.28 × 10⁶ times the `1e-8` tolerance |
| Smallest Δ bound | `0.0447347197905898` — 4.47 × 10⁴ times the `1e-6` tolerance |

`sqrt(2)` is the right predicted factor, and the reason matters: the stored
scale multiplies the **variance**, so the standard error carries its square
root. Doubling the scale must move the SE by exactly `sqrt(2)` and must not
move the point estimate at all.

**This is why the arc asserts the standard error and not the point estimate
alone.** A block asserting only the point estimate is bit-for-bit blind to any
scale defect, however large. The same block asserting the SE catches a doubled
scale six orders of magnitude outside tolerance. That is the mechanism by which
issue #242 stayed green for 22 releases, stated as a measurement rather than an
argument.

### Verified twice, and checked for circularity

The **builder** ran the probe in a scratch script outside the package and
reported the eight-by-three table.

The **tester** could not check it — the script is deliberately not in the repo,
and a gate pass was in flight so it could start no R process. It marked the
three rows "not independently verifiable by the tester; evidence is the
builder's, for the reviewer to check", which was correct on both counts. It
still stated what it could: that the delivered `other` block asserts all four
quantities plus the stored scale, which is what makes a block sensitive at all.

The **reviewer** re-ran the probe from scratch with R free. All 16 numeric cells
reproduced digit for digit.

The leader raised one specific risk: a table **back-computed from `sqrt(2)`**
would agree with `sqrt(2)` trivially and prove nothing. The reviewer answered it
with two internal relations a formula-filled table would not show:

1. `Δbound = 1.959964 × ΔSE` on every row — the normal critical value at 95%,
   linking bound movement to SE movement through a constant the formula does not
   contain.
2. The rows whose design stores `0.95` stand against the rows storing `1.0` in
   the ratio `sqrt(20/19)` — a relation between *different types'* measurements,
   which a per-row formula could not produce.

Two flagged readings are correct rather than defects, and the builder flagged
both rather than smoothing them: `R = 10` instead of 20 for BRR, ACS and
successive-difference, because `helper-test-data.R:512` returns `n_psu %/% 2L`
columns in `brr` and `fay` modes; and JKn's stored scale reading `0.95`, which
is the issue #253 defect the pinned block already records — the probe doubles
whatever is stored, so the defect does not disturb it.

## Decision — tester and leader, 2026-09-22 (S6) — row 2.22's "4 of 4" is a test-spec erratum; it reads 3 of 3

`test-spec.md` row 2.22 asks that **each of the four** new blocks estimate the
mean of `y1` with `get_means()` on the surveycore side and
`survey::svymean(~y1, ...)` on the other. The delivered file has three such
blocks — JKn, bootstrap and `other`. The Fay block calls neither function.

**The row cannot be met as written, and the same document says so.**
`test-spec.md` §3.3 states that the Fay block compares nothing and lists its two
assertions: the refusal on `survey`'s side and the stored scale on
surveycore's. Neither is an estimate. A `survey::svymean()` call in that block
would need an `sv` design object, and §3.3 is the statement that `survey`
refuses to build one without a `rho`. So no file consistent with §3.3 can
satisfy a count of four, and `spec.md` §V.9 agrees with §3.3.

§3.3 is the specific statement and governs. **Row 2.22 reads: the clause is met
by every block that can meet it — three of three.** It becomes literally
satisfiable only after issue #243 adds the `rho` argument and rewrites the Fay
block into a real comparison.

The PR 8 builder found the same tension from the other side — `spec.md` §IV.1's
estimator sentence names Fay among the four new blocks, against §V.9 — and
followed §V.9 without bending the block. It reported the conflict rather than
silently satisfying one reading. The tester reached the resolution
independently, holding only `test-spec.md`. Two agents, two documents, one
answer.

**Corrected at review, and the correction narrows the erratum.** `spec.md` is
**not** self-contradictory. §IV's own preamble reads "Block 9 is a refusal block
and follows §V.9 instead", which already scopes the whole of §IV — including
§IV.1's estimator sentence and §IV.2's `mse` row — to blocks 1 to 8. So §IV.1
never reached Fay, and §V.9 and `test-spec.md` §3.3 agree with each other word
for word: compares nothing, the same refusal message, stored scale `1 / R`.

The erratum is therefore **only** `test-spec.md` row 2.22's count of four. The
builder read §IV.1 as conflicting with §V.9 and resolved it by specificity,
which reached the right block by a longer route than necessary. A reader of
§IV should start with its preamble.

The reviewer also confirmed no estimator call consistent with §V.9 was
available: the `survey` half is impossible because the constructor raises
before it returns, and a one-sided `get_means()` would satisfy neither row 2.22
(which asks for both sides) nor §3.3 (which fixes the block at two assertions).

This is the third planner erratum the arc has found, and all three have the
same shape: a closed count stated in one artifact that the other artifact's
prose makes unreachable. S3 was the per-type table's fifth column, D23 in the
`domain-marker-logical` arc was a list of six analysis functions named only in
the test-spec, and this is a count of four where the specific rule says three.
**A count and the prose that governs it should live in the same artifact**, or
the count should be derived rather than stated.

## Finding — tester, 2026-09-22 (N3) — row 2.23's title filter catches a pre-existing block

Row 2.23 counts the titles that claim no match with `survey`. A plain word
filter returns four rather than three, because it also catches

```
get_means() BRR scale formula 1/n_rep is correct for n_rep != 4
```

at line 309. That block does **not** belong in the count. It claims
surveycore's own scale formula is correct; it makes no claim that the two sides
disagree, it agrees with `survey` on all five quantities, and it carries no
`expect_failure()` wrapper. PR 8 does not touch it.

Row 2.23 reads three of three — JKn, bootstrap, Fay — and two of two on the
blocks naming issue #253.

Recorded because the false positive is a property of the filter, not of the
file, and the next reader running a word filter over these titles will see four
and wonder. The discriminator is not the wording of the title but whether the
block wraps a failing comparison or asserts a refusal.

---

# Archive note — what the `[no such file]` markers mean

Added at closeout, 2026-09-23. **Every document marked `[no such file]` in
this archive is present in this archive.** Nothing was lost. The marker says
the *path in the citation* no longer resolves, not that the document is gone.

Twenty citation lines across eleven files carry it. They name seven
documents, and all seven are here:

| Cited as | Actually at |
|---|---|
| a run-directory path ending `baseline.md` | `baseline.md`, beside this file |
| a run-directory path ending `implementation-plan.md` | `implementation-plan.md`, beside this file |
| a run-directory path ending `measurements.md` | `measurements.md`, beside this file |
| a run-directory path ending `test-spec.md` | `test-spec.md`, beside this file |
| a run-directory path ending `gates.md` | `prs/pr-1-oracle-rule-core/gates.md` |
| a `plans/` path for the implementation plan | `implementation-plan-replicate-oracle-tests.md`, beside this file |
| the shorthand `pr-9/audit.md` [no such file] | `prs/pr-9-exceptions/audit.md` |

Two causes, one shape. The run-directory paths pointed into
`.surveycore-workspace/`, which is gitignored and does not survive closeout.
The `plans/` path pointed at a freeze copy that the archive step moved here.
Both were correct when written and stale the moment the archive was built.

**Why the marker says something the table contradicts.** The checker,
`check-citations.sh`, accepts exactly two literals — `[not archived]` for a
document the pipeline lost, and `[no such file]` for a citation naming a
document to say it is absent. Neither says "archived under a different
path", which is the actual case for all seven. Precedent in
`archive/svydesign-replicate-bridge/` and `archive/as-svydesign-domain/` used
`[no such file]` with a note like this one, and this archive follows it.

A reader who treats a marked citation as a dead end is being misled by the
tooling, not by the record. Look for the bare filename in this directory
first.

**For whoever maintains the pipeline.** A third marker would remove the need
for this note. Something like `[moved to archive]` would let the checker pass
while the citation stays true, and it would cost one `grep -vF` line in
`check-citations.sh` beside the two already there. The alternative — rewriting
each citation to its archive-relative path — makes the citations correct but
diverges the archived copy from what the agent actually wrote, which is the
thing the archive exists to preserve.
