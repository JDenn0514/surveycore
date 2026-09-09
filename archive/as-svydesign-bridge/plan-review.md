# Plan Review — as-svydesign-bridge — Pass 1 (2026-09-09)

Five lenses ran in parallel against `implementation-plan.md` revision 2.0.

The orchestrator verified every finding before accepting it, and found two of
its own.

## Verdict

**FAIL — 0 BLOCKING, 8 REQUIRED, 4 SUGGESTION.**

Nothing here is a methodology problem. Every finding is a gap between what the
spec asks for and what the plan schedules, or a claim wider than its evidence.
No settled decision D-1 to D-9 is disturbed.

Two lenses returned clean: the PR budget lens recomputed both figures exactly
(18 rows, 6 criteria) and resolved all 18 rows to exactly one criterion each;
the dependency ordering lens walked all 22 tasks and found no boundary where a
later task forces rework of an earlier one.

## REQUIRED

### PR-1 — AC-1 claims more than row E-4 tests (Lens 3)

AC-1 says "neither shape raises `surveycore_error_not_survey_object`". Row E-4
tests the replicate shape only. The plain shape's absence follows from B-3
succeeding, which is a real argument and not a tested outcome.

**Resolution.** Narrow AC-1 to what E-4 proves. State the plain-shape inference
separately if it is worth stating at all.

### PR-2 — AC-3 mixes a diff check into a test-mapped criterion (Lens 3)

"The body of `as_tbl_svy()` is unchanged" is verified by a diff, not by C-1 or
C-2. Both cited rows are behavioural and would pass a stray body edit that
preserved behaviour on those two fixtures.

**Resolution.** Move the clause out of AC-3 and into the gate list, where the
diff belongs. See PR-6, which schedules that diff.

### PR-3 — AC-5 mixes a file-state check into a test-mapped criterion (Lens 3)

The register-file clause reads the state of `plans/error-messages.md`, which no
test-spec row reads.

**Resolution.** Drop the clause from AC-5. Task 2 already specifies the rows,
and the gate list already checks them. AC-5 stays behavioural on E-1 to E-3.

### PR-4 — The three dispatch helpers are not verified, and one is never named (Lens 4)

`spec.md` §Quality gates asks for a line-level diff on
`.as_svydesign_taylor()`, `.as_svydesign_replicate()` and
`.as_svydesign_twophase()`. The plan instructs the builder not to edit the
first two and never mentions the third.

This is the worst-placed of the gaps. Branch 4 inserts immediately after the
`survey_twophase` branch, so that is where an accidental edit is most likely,
and no row in sections B to E exercises a twophase design.

**Resolution.** Schedule the diff on all three, in the gate task.

### PR-5 — `as_tbl_svy()`'s body and the five reverse-direction functions are asserted unchanged, not verified (Lens 4)

Same shape as PR-4. `spec.md` gates `as_tbl_svy()`'s body, `from_svydesign()`,
`from_tbl_svy()` and the three `.from_svydesign_*()` helpers as unchanged. No
task diffs any of them.

**Resolution.** One diff step covering all six, in the same gate task as PR-4.

### PR-6 — `NEWS.md` has a task and no criterion (Lens 4)

Every other file in the write surface is cited by at least one criterion.
`NEWS.md` is not, so nothing in the acceptance layer would catch a missing
bullet, a duplicate, or one under the wrong heading. It appends at
`## Bug fixes`, which the neighbouring arc has just written to.

**Resolution.** Add the clause to AC-5.

### PR-7 — AC-6 claims all of §Profile gates and enumerates six of seven (Lens 4)

The CRAN cookbook scan is in `test-spec.md` §Profile gates and in neither AC-6's
text nor task 22's command list. `air::format_package()` is run by task 22 and
cited by no criterion.

**Resolution.** Add both to AC-6 and to the gate task.

### PR-8 — No changelog fragment in the write surface (Lens 5, and the orchestrator)

The repo keeps one fragment per arc in `changelog/`, **alongside** the
`NEWS.md` entry and not instead of it. The evidence is at this base:

- `40700e3`, the base commit itself, is
  `docs(changelog): backfill fragments for #232 and #238`.
- The neighbouring arc wrote `changelog/fix-svydesign-replicate-bridge.md` for
  its five PRs, through this same pipeline.
- `changelog/fix-design-dim.md` is the same shape for a single-PR fix, which is
  this plan's shape.

Nothing in the 22 tasks, in `pipeline-ship`'s per-PR cycle, or in
`archive-plans.md` produces one. `archive-plans.md` moves `plans/*-{slug}.md`
into `archive/{slug}/` and touches `changelog/` not at all.

**Resolution.** Add `changelog/fix-as-svydesign-bridge.md` as the ninth file,
with a task that writes it before the commit.

**Two corrections to the convention, both verified.**
`.claude/skills/changelog-workflow.md` says the path is
`changelog/phase-{X}/{branch-name}.md`. The last three arcs wrote flat files at
`changelog/{slug}.md`, and the phase directories are older. The document also
gives a thinner format than the neighbouring arc actually used. **Follow the
neighbouring arc's file, not the document**: a header naming branches, status,
date, PRs and issues, then Summary, Changes, Files Modified and Verification.

Lens 5's own recommendation is worth recording: the real fix is to make
`archive-plans.md` write the fragment for every arc, so no future plan has to
re-derive this. That is pipeline infrastructure and out of scope here.

## SUGGESTION

### PR-9 — The builder's own contract forbids the `NEWS.md` edit the plan assigns it (Lens 5)

Verified. `.claude/agents/builder.md:138` lists "Modify `NEWS.md` (orchestrating
skill's job at ship time)" under what the builder must not do, and
`.claude/agents/shipper.md:195` forbids editing it inside a PR. A builder
reading its own contract could halt on task 21.

Against that: the user instructed the `NEWS.md` entry explicitly, and the live
file carries per-PR bullets citing #239, #241, #247, #249 and #250, so the
practice is settled whatever the contracts say.

**Resolution.** Assign `NEWS.md` to the orchestrating skill, not the builder.
That satisfies `builder.md`'s own wording, the user's instruction and the
observed practice at once. Say so in the plan, so nobody halts.

### PR-10 — Coverage rows are written after the implementation they assert (Lens 2)

Twelve rows assert behaviour that exists only because of task 7, and are
written after it. The feature itself was driven by a genuine red-green cycle on
B-1 and B-3.

**Resolution.** Accept. Lens 2 recommends the same. One atomic branch, one
cycle; per-row cycles would add churn and no safety.

### PR-11 — AC-2 does not restate B-11's class assertion (Lens 3)

**Resolution.** Accept as is. The row citation carries the full row. Lens 3
recommends the same.

### PR-12 — The two "no issue number" checks are instructed, not scheduled (Lens 4)

`spec.md` supplies the exact grep. Tasks 20 and 21 instruct it in prose.

**Resolution.** Add the grep to the gate task, with PR-4, PR-5 and PR-7.

## Verified and closed with no finding

- Both budget figures recompute exactly: 18 rows against a bound of 12, and 6
  criteria against a bound of 8. Every row exists, in the section the plan
  says, and each is claimed by exactly one criterion. B-8, C-3 and sections A
  and F are correctly never cited (Lens 1).
- The overage is stated openly, with the bound and with D-8 and D-9 as the
  reason (Lens 1).
- Task order holds at every boundary: register before code, one red-green cycle
  driving the single implementation edit, snapshots after the code that
  produces them, `snapshot_review()` rather than a blind accept, one
  `test_invariants()` call, `document()` after the final roxygen and before the
  commit (Lens 2).
- AC-2's numeric clauses carry tolerances, and no criterion states a bare
  measured figure (Lens 3).
- AC-6 is checkable and not a placeholder. Every clause is a command exit
  state, a percentage against a bound, or a diff emptiness (Lens 3).
- No scope creep. No task edits `.as_svydesign_replicate()`,
  `R/core-constructors.R`, `R/methods-print.R`, or anything belonging to #242
  to #251. The write surface matched the spec exactly before PR-8 (Lens 4,
  Lens 5).
- `NAMESPACE` and `DESCRIPTION` are correctly absent: both functions are
  already exported, no new dependency, no version bump due mid-development
  (Lens 5).
- `plans/pr-budget-calibration.md` is correctly excluded. The plan states
  `pipeline-ship` appends it after the merge, which matches
  `artifact-schemas.md` (Lens 5).
- Every line number, quoted "before" text and insertion point in the plan
  checked out against the working tree at base `40700e3` (Lens 5).

## Rule documents that lag the code — running list

Three now, none blocking, all reported for the user:

- `.claude/rules/code-style.md` names `R/07-utils.R`, `04-methods-print.R`,
  `00-s7-classes.R` and `05-methods-conversion.R`. None exists. Its
  inline-markup table also omits `{.pkg}`, which the code uses.
  `.claude/rules/testing-surveycore.md` repeats two of the stale names.
- `.claude/skills/changelog-workflow.md` gives a path and a format that the
  last three arcs did not use.
- `.claude/agents/builder.md` and `.claude/agents/shipper.md` forbid the
  `NEWS.md` edit that five recent PRs made.

---

# Pass 2 — delta (2026-09-09)

Two agents. One read the plan's changed sections against the twelve pass-1
resolutions. One checked the three artifacts against each other, because the
edits had been applied by hand across several passes including one reversal.

## Verdict

**PASS, after six corrections applied by the orchestrator.**

All twelve pass-1 findings landed. Pass 2 found six defects the editing itself
introduced. Every one was mechanical, every one is fixed, and each was verified
by reading the file back.

## What pass 2 found in the plan

1. **REQUIRED — the revision note credited the review with adding the wrong
   file.** It said `NEWS.md` was the ninth file the review added. Backwards:
   the review added the changelog fragment, which stayed, and `NEWS.md` was
   already in the surface before the review, and D-10 removed it. Fixed by
   naming both edits and their directions.
2. **REQUIRED — a stale "two files" cross-reference.** §Files touched pointed
   at §Risk and rollback for "the two files a conflict could reach", and that
   section now says one file, because D-10 took `NEWS.md` out of the shared
   surface. Fixed, with the history kept in one clause.
3. **REQUIRED — AC-5 pointed at a gate that did not look.** Its prose
   disclaimed two checks on the grounds that "the gate task confirms it", and
   task 25 checked neither the register rows nor the changelog fragment's
   substance. This is the one finding of the six that would have shipped a real
   hole: a criterion deferring to a gate, and a gate that never made the check.
   Task 25 now verifies the register subsection, the fragment's shape, and that
   `NEWS.md` shows no diff.

## What pass 2 found across the artifacts

4. **REQUIRED — `spec.md` contradicted itself on a line number.** Its CN-1
   site table gave `R/methods-conversion.R:266-272` for `as_tbl_svy()`'s guard,
   while its own correction table two sections later recorded that site moving
   from 271 to 402. The table was written before the fast-forward and missed
   when the rest of the document was corrected.

   Fixed by the policy the document already adopted for the two reverse
   `@return` lines after four base moves: **identify the sites by function and
   guard, not by line.** The table now carries no ranges, and gives the grep
   that finds all four. The current line numbers appear once, below the table,
   as a note rather than as the anchor.
5. **REQUIRED — only the plan warned against the stale changelog document.**
   `spec.md`'s changelog row described the right shape and never said that
   `.claude/skills/changelog-workflow.md` is wrong on both the path and the
   format. A reader of `spec.md` alone had no signal. Fixed, and its
   §Validation rules are kept as a floor since those four checks still hold.
6. **SUGGESTION, applied — two counts still cited the superseded base.** The
   seven-site count and the `CN` prefix check both said "verified at base
   `1f15d35`". Both re-verified at `40700e3` and both still hold: seven files
   raise `surveycore_warning_nonprob_srs_fallback`, and no row starts `| CN-`.

## What pass 2 confirmed

- Both artifacts name the identical eight files, and every heading matches its
  own table.
- Tasks run 1 to 25, no gap, no repeat, and no prose cross-reference points at
  a superseded number.
- All 18 test-spec rows are cited exactly once across AC-1 to AC-5, and AC-6
  cites none. The criterion edits dropped nothing.
- The two-artifact rule holds in both directions: no test case or tolerance in
  `spec.md`, no `R/` path in `test-spec.md`, and neither names the other.
- `NEWS.md` survives only as something explicitly not written, as a gate
  expecting no diff, and inside one `git log` path list.
- The headline base-dependent figures agree across all three artifacts: the
  reverse `@return` lines at 495 and 881, `as_tbl_svy()`'s `@param x` at 348
  and 349, and the snapshot file at 84 lines in 8 blocks.

## Why no pass 3

The budget allows three. Pass 2's six corrections each had one right answer,
were applied by the orchestrator rather than by a resolver agent, and were each
read back. A third panel would re-read text whose only changes are those six.

The orchestrator ran two whole-document checks instead: the task numbering, by
extracting every numbered line and confirming 1 to 25 unbroken; and the base,
by fetching and confirming `origin/develop` is still `40700e3`, so no citation
went stale during the review itself.
