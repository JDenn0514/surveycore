# Plan review — replicate-scale-jkn-bootstrap

**Document under review**: `implementation-plan.md`, 5 PRs
**Passes**: 2 of the 3 the review-loop budget allows
**Final verdict**: **PASS** (Pass 1 NEEDS-DECISION → Pass 2 PASS)

---

# Pass 1 — full panel

**Date**: 2026-09-28
**Scope**: all five lenses, whole document
**Verdict**: **NEEDS-DECISION**

Two findings are JUDGMENT_CALL. Both ask whether a frozen SPEC_READY
artifact gains a line. The user decides, then Stage 3 resolves.

---

## Verdict arithmetic

| Class | Count | Findings |
|---|---|---|
| BLOCKING | 0 | — |
| JUDGMENT_CALL | 2 | SC-1, SC-2 |
| REQUIRED-UNAMBIGUOUS | 2 | DO-1, AC-1 |
| SUGGESTION | 2 | AC-2, AC-3 |

Two lenses returned clean: PR Budget and File Completeness.

---

## Lens results

| Lens | Verdict | Findings |
|---|---|---|
| PR Budget | clean | 0 |
| Dependency Ordering | 1 finding | DO-1 |
| Acceptance Criteria | 3 findings | AC-1, AC-2, AC-3 |
| Spec Coverage | 2 findings | SC-1, SC-2 |
| File Completeness | clean | 0 |

### PR Budget — clean

The lens recomputed both figures for every PR rather than reading the
stated ones. All ten figures match.

| PR | Rows (recomputed) | Bound 12 | Criteria (recomputed) | Bound 8 |
|---|---|---|---|---|
| 1 | 5 | inside | 7 | inside |
| 2 | 5 | inside | 7 | inside |
| 3 | 3 | inside | 7 | inside |
| 4 | 4 | inside | 7 | inside |
| 5 | 2 | inside | 5 | inside |

All 19 test-spec rows are claimed, each by exactly one PR. No cited row is
absent from `test-spec.md`. No PR is a one-task, one-row entry that should
merge into its neighbour.

### File Completeness — clean

The union of write surfaces is exactly the seven files `spec.md` §Files
touched names. No eighth file. `tests/testthat/_snaps/`,
`plans/error-messages.md` and `R/variance-replicate.R` appear in no surface.

`devtools::document()` runs in the same PR as each roxygen change it serves
— PR 1 for `man/as_survey_replicate.Rd`, PR 4 for
`man/as_survey_nonprob.Rd`. `NAMESPACE` is in no surface, which is correct
because the work exports nothing new, and both roxygen PRs carry a
criterion that `document()` leaves it clean.

`DESCRIPTION` needs no bump. `.claude/rules/github-strategy.md` reserves
the version bump for release prep as a direct commit to `develop`, and the
file already reads `1.1.0.9000`. The plan's silence is correct.

The plan states the PRs are strictly sequential and tells the builder to cut
each branch only after the one before it merges. The statement is
unambiguous, so the three files that recur across PRs are not concurrent
overlaps.

---

## Findings

### SC-1 — behaviour rule 8 reaches no PR and no row — JUDGMENT_CALL

`spec.md` §Function contracts behaviour rule 8 states that a
`survey_twophase` design over a replicate `phase1` inherits the new default
unchanged. `as_survey_twophase()` copies `phase1@variables` at
`R/core-constructors.R:1151` and recomputes nothing in it.

Nothing observes this. The Spec Coverage lens grepped `twophase` across
`implementation-plan.md` and `test-spec.md` and found zero hits outside
`spec.md` itself.

**Why the risk is low.** The two-phase branch of `R/core-constructors.R`
and `R/variance-twophase.R` are both outside the write surface, and no PR
writes either. A caller builds the `survey_replicate` first, so the scale is
already computed before the two-phase constructor sees it.

**Why it is still a finding.** This work moves a published standard error.
A two-phase user over a replicate `phase1` gets the moved number too, and no
assertion anywhere says so. The copy at line 1151 is a property copy, which
is the one operation in the chain that could drop or recompute a value. One
assertion closes it.

**The decision.** The fix touches `test-spec.md`, which froze at SPEC_READY
and has a copy in `plans/`. Three shapes are open, and they differ in what
ships:

1. Add a test-spec row asserting the inherited value, and give it to a PR.
2. Add the explicit "needs no row because X" rationale, on the pattern
   `test-spec.md` already uses for the grouping half of rule 7.
3. Accept the gap and record it in `decisions.md`.

### SC-2 — behaviour rule 7's domain half reaches no PR and no row — JUDGMENT_CALL

Rule 7 carries two clauses. The grouping clause has an explicit exclusion
rationale in `test-spec.md` — grouping cannot reach the stored default on
any path, so it needs no row. The domain clause has nothing: no row, no
rationale, no PR task.

The asymmetry is the finding. A later reader meets a documented exclusion
for one half of a rule and silence for the other, and cannot tell the
silence from an oversight.

**Why the risk is low.** `filter()` marks domain membership and writes no
`@variables` key, so the stored scale is untouched by construction. The
claim about the variance taking the same factor after the restriction is a
claim about `R/variance-replicate.R`, which no PR writes.

**The decision.** Same three shapes as SC-1. The symmetric fix is shape 2 —
give the domain half the same rationale the grouping half already has.

### DO-1 — the plan contradicts itself about PR 4's write surface — REQUIRED-UNAMBIGUOUS

The mutation-check section says `R/core-constructors.R` is not in the write
surface of PR 2, PR 3 **or PR 4**. Two other places in the same document say
otherwise, and they are right:

- the write-surface table lists `R/core-constructors.R` under PRs 1 and 4;
- PR 4's own task list edits that file for the `as_survey_nonprob()`
  `@details` roxygen, and its `git status` check is correctly scoped to "no
  change to the switch lines".

The suite stays green either way, so this is not a red-merge risk. It is a
clarity defect at the worst moment: a builder consults the mutation-check
section mid-execution, which is exactly when PR 4 is about to make the
file's one legitimate edit.

**Fix**: reword the blanket sentence to name the switch lines, not the file
— "the switch lines are not in the write surface of PR 2, PR 3 or PR 4",
matching PR 4's own wording.

### AC-1 — PR 5 criterion 2 claims test-spec traceability it does not have — REQUIRED-UNAMBIGUOUS

The criterion demands ten sub-elements of the changelog file: branch,
status, date, PR numbers, issue numbers, a summary with the measured
before-and-after table, the changed files, a verification list, the E5
window, and the clause that this work clears one of the two sanctioned
exceptions and not both.

`test-spec.md` row 4.6 asserts one thing about that file: it exists. The ten
sub-elements trace to `spec.md` §The changelog entry.

Every element is observable, so this is not an observability defect. It is a
mapping gap: a tester working from `test-spec.md` alone has no row telling
them to check any of the ten.

**Fix**: cite `spec.md` §The changelog entry explicitly in the criterion, so
the plan stops implying full test-spec traceability. Expanding row 4.6
instead would reopen a frozen artifact for no gain — the tester reads the
plan's criterion either way.

### AC-2 — PR 1 criterion 4 carries a verification method — SUGGESTION

The criterion closes with "Read the two blocks and count the calls;
`grep -c` reads high on this file." That is guidance on how to check, not a
fact to check. The plan already carries the same rule in its §Rules that
bind every PR section.

**Fix**: cut the trailing sentence from the criterion. The rule stays where
it already is.

### AC-3 — PR 4's two criteria disagree on a phrase row 2.3 gives both — SUGGESTION

`test-spec.md` row 2.3 says each side is asserted against its own literal,
never against the other side, and states it once for both frames. Criterion
2 (frame B) omitted the phrase.

**Correction, made at Pass 2.** This finding was first written as "criterion
2 drops a phrase criterion 1 carries". Criterion 1 did not carry it either —
a full-document grep for "other side" returned one hit, in criterion 2 after
the resolve round. Both criteria needed the phrase, not one.

**Fix**: add the phrase to both criteria.

---

## What the lenses confirmed, and it is worth recording

**The ordering trap is handled.** PR 1 carries both switch lines, all six
`expect_failure()` wrappers, both closing ratio assertions and the retargeted
bootstrap block in one commit. The Dependency Ordering lens verified the
current file state itself: the wrappers sit at lines 865, 868, 871, 942, 949
and 952, the ratio assertions at 879-883 and 960-964, and the retarget
target at 676-692. It also confirmed that the other occurrences of
`1 / n_rep` and `(n_rep - 1) / n_rep` in both test files belong to BRR, JK1,
JK2 and Fay — unchanged types — and that no PR touches them. That closes row
4.4's diff-scoping instruction.

**The mutation check is sound as written.** PRs 2, 3 and 4 add blocks for
behaviour PR 1 already shipped, so the blocks pass on first run and prove
nothing until shown able to fail. Each PR reverts the switch line its rows
depend on, observes red, reverts back and re-runs. The per-row scoping is
right: line 807 for JKn rows, 813 for bootstrap rows, both in turn for row
1.7. The edit reaches no commit, and every such PR carries a `git status`
step before commit.

**No implementation hints leaked into the acceptance criteria.** The
Acceptance Criteria lens checked this deliberately. Every statement of the
form "the switch uses `n_rep - 1L`" or "the comment is a pointer and not a
derivation" sits in a Tasks list. The mutation check is never restated as a
criterion; what the criteria assert is the observable post-merge outcome.

**No scope creep.** No PR schedules work `spec.md` §Out assigns to #255,
#243 or #251, and none adds an error or warning class. The only condition
classes the plan names are the five pre-existing ones.

---

## Routing

Verdict NEEDS-DECISION routes to a HOLD. The orchestrator puts SC-1 and SC-2
to the user. On the answer, Stage 3 resolves all six findings and a delta
pass re-reviews only the changed sections.

DO-1, AC-1, AC-2 and AC-3 need no decision and resolve in the same round.

---

# Pass 2 — delta

**Date**: 2026-09-28
**Scope**: the twelve section headings the resolver changed, and nothing
else. Two lenses, per the review-loop budget for a delta pass.
**Verdict**: **PASS**

## The user's decision on SC-1 and SC-2

A test-spec row for behaviour rule 8, and a rationale clause for behaviour
rule 7b. Recorded as `decisions.md` D-11.

The two rules took different shapes for a reason the entry records. Rule 8's
value crosses a property copy at `R/core-constructors.R:1151`, which is the
one operation in the chain that could drop or recompute it, and a two-phase
user's published standard error moves with this change. Rule 7b's value
crosses nothing reachable: `filter()` writes no `@variables` key.

## Results

| Fix | Result |
|---|---|
| SC-1 — test-spec row 1.9, assigned to PR 3 | landed |
| SC-2 — rationale for rule 7's domain clause | landed |
| DO-1 — the mutation-check contradiction | landed |
| AC-1 — PR 5 criterion 2's traceability claim | landed |
| AC-2 — the verification method in PR 1 criterion 4 | landed |
| AC-3 — the literal-assertion phrase in PR 4 | landed, then corrected |

### Budget and coverage, recomputed

| PR | Rows | Bound 12 | Criteria | Bound 8 |
|---|---|---|---|---|
| 1 | 5 | inside | 7 | inside |
| 2 | 5 | inside | 7 | inside |
| 3 | 4 | inside | 8 | inside |
| 4 | 4 | inside | 7 | inside |
| 5 | 2 | inside | 5 | inside |

Twenty rows now — §1 runs 1.1 to 1.9 — and each is claimed by exactly one
PR. The lens recounted every figure from the documents rather than reading
the stated ones, and swept both documents for a stale "19 rows" or a stale
PR 3 figure. It found none.

**PR 3 sits exactly at the criteria bound.** Eight is inside the bound of
eight. Any later finding that adds a criterion to PR 3 puts it over, so that
PR takes a split and not a ninth criterion.

### Row 1.9's fixture is a composite, and the row says so

`make_survey_data()` takes one `design` value through `match.arg()`, and its
`"replicate"` and `"twophase"` branches are mutually exclusive. A replicate
frame never carries a `subset` column, and a two-phase frame never carries
replicate columns. Verified at `tests/testthat/helper-test-data.R:511-537`.

Row 1.9 therefore states its own construction — a replicate frame with a
logical `subset` column added inline — and §Datasets records it. The row
does not assume a generator call that cannot produce that frame.

### The one defect Pass 2 found

AC-3's fix landed on criterion 2 and left criterion 1 without the phrase.
The Pass 1 finding was wrong about which criteria carried it: neither did.
Corrected in place above, and the phrase now sits in both criteria.

Severity SUGGESTION, so it does not hold the verdict. `test-spec.md` row 2.3
already states the requirement once for both frames, so a builder working
from the test-spec would have written it correctly either way.

### No collateral damage

PR 3's task numbering shifted — old tasks 6 and 7 became 8 and 9, old
criteria 6 and 7 became 7 and 8. The lens checked every internal
cross-reference in the document. Task 9 reads "criteria 7 and 8", which is
right. The two other "criteria 6 and 7" references belong to PR 2 and PR 4,
each correct for its own count. No leftover PR 3 reference survives.

The `plans/` copy of the test-spec matches the run-dir original byte for
byte, at 439 lines. The resolver copied it through Read and Write rather
than `cp`, so this was checked mechanically and not taken on report.

## Verdict arithmetic

| Class | Count |
|---|---|
| BLOCKING | 0 |
| JUDGMENT_CALL | 0 |
| REQUIRED-UNAMBIGUOUS | 0 |
| SUGGESTION | 1 (applied) |

PASS. Two passes used of the three the review-loop budget allows. Stage 4
may freeze.
