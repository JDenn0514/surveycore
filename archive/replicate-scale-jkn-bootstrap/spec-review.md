# Spec Review: replicate-scale-jkn-bootstrap — Pass 1 (2026-09-28)

Protocol: `.claude/skills/spec-workflow/references/stage-3-review.md`. Six
lenses, one Explore agent each, run in parallel on sonnet. Both artifacts went
to every lens, for the reason recorded in `methods-review.md` Pass 1.

Every lens was told not to re-raise the 21 findings the methods review closed.
None did.

---

## Verdict: NEEDS-DECISION

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 16 |
| SUGGESTION | 9 |

Twenty-six findings. One BLOCKING, and it is not from a lens — it is a
measurement the orchestrator took after lens 6 flagged a claim as unverified.

| Lens | BLOCKING | REQUIRED | SUGGESTION |
|---|---|---|---|
| 1 — DRY | 0 | 2 | 2 (both "no action" by the lens's own recommendation) |
| 2 — Test completeness | 0 | 2 | 1 (no action) |
| 3 — Contract completeness | 0 | 2 | 0 |
| 4 — Edge cases | 0 | 3 | 1 |
| 5 — Engineering level | 0 | 3 | 3 (two no action) |
| 6 — API coherence | 0 | 4 | 2 (both no action) |
| Orchestrator measurement | 1 | 0 | 0 |

**Nine of the 26 are SUGGESTION, and six of those carry the raising lens's own
recommendation to take no action.** The real load is one BLOCKING, 16 REQUIRED
and three actionable SUGGESTIONs.

---

## BLOCKING

### B-1 — F-5 requires a false statement on a public help page

Measured, `measurements.md` M4. Lens 6 raised the claim as unverified; the
measurement settled it as wrong.

F-5 requires the help page to state that `as_svydesign()` "cannot round-trip a
`survey` design built with `bootstrap.average != 1`". It can.

| `bootstrap.average` | `survey` scale | surveycore stored | exported | SE identical |
|--:|--:|--:|--:|---|
| 1 | 0.1428571429 | 0.1428571429 | 0.1428571429 | yes |
| 3 | 0.4285714286 | 0.4285714286 | 0.4285714286 | yes |

`from_svydesign()` stores `scale = x$scale` (`R/methods-conversion.R:1016`),
which already has `bootstrap.average` folded in; `as_svydesign()` passes it
back out (`:372-375`, `:494`) and `survey` honours a supplied bootstrap scale.
Standard errors agree bit for bit at `tolerance = 0`.

**The error is upstream of the spec.** Issue #253's body says
`bootstrap.average` "is the numerator of `survey`'s scale, so `as_svydesign()`
cannot round-trip a design built with `bootstrap.average != 1`". The first
clause is true; the inference is false, because the numerator is already
inside the stored scale. D5 turned that into an instruction and the planner
followed it.

**Fix.** F-5 states what is true: surveycore has no `bootstrap.average`
argument, so a caller cannot build a design with one and the default is always
`1/(R-1)`; an imported `survey` design keeps its effective scale exactly in
both directions. The missing thing is a constructor argument, not a number.
Issue #253's body should be corrected too, so the next reader does not
reintroduce it.

---

## REQUIRED

Grouped by what they touch.

### The spec claims something the tests do not check

**R-1 (lens 2).** Spec E7 promises that an all-NA outcome column, a
zero-weight row among positive rows and a single-level grouping variable all
reach the same stored `scale`. The test-spec's closed set of seven edge
behaviours covers none of the three — `grep` returns no match for any of
them. Either test them in one combined row, or drop the clause from E7 and say
why it needs no test. The lens recommends testing.

**R-2 (lens 2).** The §Error-path pattern says all four classes in row 1.6
"already carry snapshots", so the row asserts the class only. True for three.
`_snaps/constructors.md` carries no snapshot for `as_survey_replicate()`
raising `surveycore_error_weights_all_zero`; a repo-wide search finds that
class only in class-only assertions. Following the test-spec literally leaves
it permanently un-snapshotted on a false premise. Either add the snapshot or
name it as a fifth piece of pre-existing register drift.

### The spec states a fact without stating the mechanism

**R-3 (lens 3).** §Class changes says the validator is unchanged but never
says the `survey_replicate` validator performs no check on `scale` at all. It
does not — verified, its body never mentions `scale` — so `Inf` passes on
every construction path, including a direct `survey_replicate()` call and both
conversion routes. A builder could read "unchanged" as "enforces something"
and add a defensive check the spec forbids.

**R-4 (lens 3).** "No new property" is an S7 property statement and does not
assert that the `@variables` key set is unchanged, which is a separate named
rule in `code-style.md`. State it.

### Edge boundaries the spec does not name

**R-5 (lens 4).** The ordinary zero-variance case is missing. At any finite
scale — any `R > 1`, or `R = 1` JKn — all-zero deviations give `SE = 0`
exactly. The spec documents only the pathological `R = 1` bootstrap
`Inf * 0 = NaN`, and never contrasts the two, so a reader can conflate
degenerate variance with `NaN`.

**R-6 (lens 4).** `as_survey_nonprob()` raises
`surveycore_error_scale_negative` for a negative `scale`; `as_survey_replicate()`
stores it verbatim, because its scale block has no `else` branch. Verified in
source. A caller passing `scale = -1` gets a negative variance multiplier
silently. Pre-existing and out of scope, but §Out catalogues seven other
deferred items with owners and omits this one.

**R-7 (lens 4).** `as_survey_twophase()` accepts a `survey_replicate` as
`phase1`, so any two-phase design over a JKn or bootstrap phase-1 inherits the
new default the moment this lands. Structurally safe — two-phase reads the
stored scale and never recomputes it — but the spec's cross-design discussion
covers only the two replicate constructors and never mentions Taylor or
two-phase.

### Duplication inside one document

**R-8 (lens 1).** `test-spec.md` row 1.7 says "the value in the table at the
head of this document" and then transcribes all nine values anyway. Two
independently maintained copies in one file.

**R-9 (lens 1).** `spec.md`'s NEWS section restates the `sqrt((R-1)/R)` factor
and its percentage twice with no pointer to behaviour rule 6 — while the D1
note two sections up models the right pattern explicitly. The methods review
already caught one transposition in this exact number.

**R-10 (lens 5).** The stratified jackknife derivation is written out in full
three times: the spec's justification section, the `@param scale` roxygen, and
the mandated internal comment at the switch lines. Nothing but style ties them
together. The lens recommends reducing the code comment to a pointer plus the
one line the code needs.

### Test load

**R-11 (lens 5).** Row 2.3 tests unchanged code. A wrong default is already
caught by row 1.1 against the old literal and rows 2.1/2.2 against the oracle.
What 2.3 adds is proof that `scale` is a linear multiplier that never touches
the point estimate — a property of `R/variance-replicate.R`, which the spec
places outside the write surface. Dropping it removes four design
constructions and moves the row count toward budget.

**R-12 (lens 5).** Row 4.4 asks the tester to establish a whole-suite
negative — that no block anywhere asserts either old value — with no stated
method. The only practical check is a textual scan, and the same document
warns scans are unreliable in that file because it discusses its own
constructs in comments and titles. The spec already knows the one block that
held the old value, so a diff-scoped check is well defined.

### API surfaces

**R-13 (lens 6).** The upgrade moves published standard errors with no runtime
signal at all, and the spec never weighs a transition message. §Errors and
warnings says the work adds no warning class; E1 and E5 both say no condition
is raised. NEWS is read only by someone who goes looking. **The locked
decisions settle the values, not whether the transition is silent.** Either add
a one-time session-scoped message or record that one was considered and
rejected.

**R-14 (lens 6).** The two constructors' bootstrap divergence is documented
only in two separate help pages, and a user meets it as an unexplained 2.5%
gap. Nothing surfaces it at the point of use — no message, no note in the
printed design, no attribute. An analyst sanity-checking one constructor
against the other would reasonably conclude one is broken.

**R-15 (lens 6).** `@param fpc` says nothing about being inert for replicate
designs, and the without-replacement correction lives two arguments away under
`@param scale`. `fpc` is in the printed signature and is the first place an
analyst looks for a finite-population correction. They get no error, no
warning and no effect.

**R-16 (lens 6).** Same as B-1 from the API side: F-5's claim, now measured
false.

---

## SUGGESTION

Three carry a recommendation to act.

**S-1 (lens 4).** Note that `R = 2` is the smallest count at which the two
changed defaults coincide at `1`, and that the coincidence is arithmetic only,
so a later reader does not read a relationship into it.

**S-2 (lens 5).** `surveycore_error_stratified_jk_rscales_unset` ships with
snapshots and has no register row. The spec records it in prose with no issue
number and no "not filed" marker, unlike every other deferred item. Give it a
home outside this run's spec.

**S-3 (lens 5).** Row 2.4 bundles six to eight assertions under one row
number, so "19 rows" understates the true test load. Numbering only — flagged
so Stage 4 does not take the row count as the measure of the work.

Six more were raised and closed by their own lens: RS-1's wording overlap with
F-3 (lens 1, no action — the four statements serve four readers); the
duplicated wrapper-deletion prose (lens 1, no action — a closing summary
already cross-checks it); the four copies of the 2.5%/2.6% figure (lens 5, no
action — each audience needs the concrete number); guidance for a
still-failing unwrapped assertion (lens 2, no action — standard suite
behaviour); an in-session signal for the `R = 1` asymmetry (lens 6, no action
— reopening D-1); and an interim message for the JKn `rscales = NULL` window
(lens 6, no action — #255 lands too soon to be worth the churn).

---

## What the review confirmed

- **The 13-category table is honest.** Lens 2 marked seven categories N/A with
  a mechanism for each, and verified each against source rather than asserting
  it. Category 2, the numerical oracle, cannot be N/A and is covered by four
  rows.
- **Both of the orchestrator's unreviewed row 2.4 edits are correct.** Lens 2
  verified `variance = c("se", "ci")` is necessary because
  `.add_variance_cols()` populates `se` only when asked, and `min_cell_n = 1L`
  is necessary and sufficient because a four-row frame trips `4 < 30`. This
  closes caveat 1 on the Stage 2 PASS.
- **No new argument and no new error class.** Lens 3 verified the signature is
  unchanged, the four pre-existing classes all exist under the names the spec
  uses, and the spec does not claim to own them.
- **Three roxygen targets, and a fourth explicitly closed off.** §Documentation
  states that `as_survey_nonprob()`'s `@param type` and `@param scale` stay
  true and need no edit.
- **Both known repo drifts are recorded rather than silently inherited.**
- **Cross-document duplication is isolation-forced, and neither side carries
  more than it must.** Lens 1 checked each shared fact and found the test-spec
  side consistently the more compact.
- **No scope creep and no gesture prose.** Lens 5 found no machinery built for
  `rho`, `bootstrap.average` or the `fpc` correction, and zero hits for
  "graceful", "reasonable", "appropriate", "as needed", "handle correctly" or
  "should work" across both documents.
- **The `R = 1` treatment is engineered at the right level** — documented,
  tested on both sub-cases against the oracle, with no invented guard.
- **Row 4.3 catches a partial wrapper deletion**, per block and independently,
  so three-gone-from-one-block is caught.

---

## Routing

Stage 3r in BIG mode. The judgment calls that change what ships are R-13 (the
silent transition), R-11 (dropping row 2.3), R-10 (trimming the code comment),
and whether to file GitHub issues for R-2, R-6 and S-2 and to correct issue
#253's body for B-1. The rest are unambiguous.

---

# Spec Review: replicate-scale-jkn-bootstrap — Pass 2 (2026-09-28)

Delta pass. Two Explore agents on opus, split by kind rather than by
document: one on mechanical integrity after row 2.3's deletion, one on the new
substantive content. Neither re-read a whole document.

Before dispatching them the orchestrator checked mechanically: no stale `2.4`
reference in either document, `F-1` to `F-8` with no gap and no `F-9`, the
three moved counts agreeing across both files, and isolation intact.

## Prior issues (Pass 1)

Twenty-six findings. One BLOCKING, sixteen REQUIRED, nine SUGGESTION.

| Group | Status |
|---|---|
| B-1 — F-5's false round-trip claim | Resolved. Corrected against M4, and issue #253's body corrected on GitHub. |
| R-1 to R-16 | All resolved. R-1 resolved differently than the review asked — see D-10. |
| S-1, S-2, S-3 | S-1 and S-2 applied; S-3 no action on numbering, per its own lens, with a prose note in place. |
| The six lens-closed SUGGESTIONs | No action, as each raising lens recommended. None reopened. |

**R-1's premise was false, and the resolver caught it.** The review asked for
a test row building a frame with a mixed zero-and-positive weight column, on
the strength of spec E7's claim that such a frame reaches the same stored
`scale`. `.validate_weights()` refuses it — `surveycore_error_weights_nonpositive`
at `R/core-validators.R:170-186`, called at `R/core-constructors.R:783`,
before the switch at 797. The row would have been red on arrival. E7 asserted
something the constructor forbids, no lens caught it, and the resolver hit it
while implementing. Recorded as D-10; the refusal inventory grew from four
classes to five.

## New issues — five, all mechanical, all applied by the orchestrator

**From the substantive half, one.**

- The new `### A runtime transition signal was weighed and declined` was a
  `###` sibling of `### In` and `### Out`, so two paragraphs that trailed the
  §Out table — on the sanctioned test exceptions and on the plan's PR-order
  contradiction — were nested under a heading about transition signals. Fixed
  by moving the two paragraphs above the heading, so §Out keeps its own notes
  and the new subsection holds only its own subject.

**From the mechanical half, four.**

- §Function contracts still said "the four existing classes" where §Errors and
  warnings now says five. A count incremented in one place only.
- The new class was inserted **fourth** in the spec's table while four ordinal
  claims in both documents call it the fifth, and the test-spec's row split
  puts it fifth. Moving the table row to last fixed all four claims at once.
- The dropped grouping clause carried its reason on the spec side only.
  `test-spec.md` never named grouping while declaring its seven-behaviour set
  closed, so a tester reading that document alone never learned grouping was
  weighed. One paragraph added to the edge-behaviour list.
- §Ordering constraint's closing enumeration claimed completeness and was
  short by six rows. Both changed defaults appear in eleven rows, not three.
  Replaced with the general rule plus the full list, and a note that a list
  goes stale on the next edit while the rule does not.

One further note the agent raised and the orchestrator applied: restated
oracle rule 3 said "the bootstrap row" in the singular, written when §2 held
one. §2 now holds two, both correctly `rscales`-free. Changed to "either
bootstrap row".

## What Pass 2 confirmed

The mechanical half:

- **All thirteen sites that referenced the old numbering read correctly**, and
  a search for the deleted row's signature phrases returns nothing in either
  document. The old exclusion sentence is fully gone rather than half-edited.
- **The new row 2.3 is genuinely an oracle row** under all five rules, and the
  rule-2 carve-out for its premise designs is sound under
  `.claude/rules/testing-surveycore.md` §What the rule covers — those designs
  are handed to no `survey` call, so no surveycore-computed number crosses.
- **Row 1.1's absorbed assertion is arithmetically right both ways.** JKn:
  `1 ÷ ((R-1)/R) = R/(R-1)`. Bootstrap: `(1/(R-1)) ÷ (1/R) = R/(R-1)`. Same
  ratio, and the direction holds for both.
- **The five classes match one-for-one across both documents**, and each
  exists in `plans/error-messages.md` under the name and register row the spec
  cites — rows 2, 16, 10, 17 and 33.
- **The existing snapshot is the same route.** `_snaps/labelled-storage.md`
  block "S-23f: as_survey_replicate() still raises on a zero weight" is an
  `as_survey_replicate(type = "bootstrap")` zero-weight abort, so a new
  snapshot would duplicate it.
- **§Tolerances survived losing one of its two deviations.** One deviation
  remains, the `expect_equal()`-not-`expect_identical()` reasoning retargeted
  cleanly rather than being orphaned, and all three exact assertions match
  their rows.
- **Neither document states an §Out row count**, and no absolute test-row
  count survives anywhere, so the S-3 concern is handled by prose rather than
  by a number that would go stale.

The substantive half:

- **Two-phase's mechanism verified independently.**
  `R/core-constructors.R:1151` is `phase1 = phase1@variables,` inside the
  `variables <- list(` at 1150, and nothing touches it before the
  `survey_twophase()` call at 1163. Behaviour rule 8's premise holds, and
  `as_survey()`'s own variables list carries no `scale` key, so the Taylor
  clause is true too.
- **The `@variables` key list is right for this constructor** — nine keys
  matching `R/core-constructors.R:822-832` element for element and in order.
  `code-style.md`'s six-key list is `as_survey()`'s, and `as_survey()`'s own
  list is a different seven, so citing the rule's list would have been wrong.
- **The validator checks nothing about `scale`.** `R/core-classes.R:669-753`
  has zero occurrences of the word, and the four checks the spec enumerates
  are exactly the four in the body.
- **F-8 carries no factor and no percentage**, so the 2.5% figure keeps one
  home, and the test-spec marks a rendered percentage there as a finding.
- **Row 4.4's diff-scoped instruction is executable**, and its "or a new
  block" branch correctly covers the legitimate new uses of `1 / n_rep` that
  rows 1.1 and 3.2 introduce.
- **R-13's subsection states both of D-6's reasons**, tells a later reader not
  to file a defect, closes the question, and carries no apology.

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 5 |
| SUGGESTION | 0 |

All five resolved.

---

# Stage 3 verdict: PASS

Thirty-one findings across two passes. All resolved except the ones closed by
decision.

| Pass | Raised | Resolved | Carried |
|---|---|---|---|
| 1 — six lenses | 26 | 20 | six SUGGESTIONs closed by their own lens with no action |
| 2 — delta, two agents | 5 | 5 | — |

**No finding challenged either target value.** `JKn = 1` and
`bootstrap = 1/(R-1)` stand as Stage 0 confirmed them and Stage 2 upheld them.

## One caveat, stated plainly

**The five Pass 2 fixes carry no independent review.** All five are mechanical
— a numeral, a table row's position, two added paragraphs and one plural — and
the orchestrator verified each by reading the result. No agent has read them.

Unlike Stage 2's equivalent caveat, this one has a downstream reader.
`pipeline-implement`'s plan review runs a Spec Coverage lens over `spec.md`,
and `pipeline-ship`'s reviewer is the one role that reads every artifact
together. Either may see these five.

## What the two Stage 3 passes changed

Stage 2 fixed what the spec *claimed*. Stage 3 fixed what it *shipped* and
what it *asked a tester to do*:

- F-5 no longer puts a false statement on a public help page, and the issue
  that originated the error is corrected.
- E7 no longer asserts a frame the constructor refuses, and the refusal is
  named.
- The silent transition is a recorded decision instead of an unexplained
  silence.
- `@param fpc` no longer leaves a caller to discover that the argument they
  reached for is inert.
- The two constructors' divergence is discoverable from either signature.
- Row 4.4 asks for a check a tester can actually run.
- One test row that proved a property of code this PR does not touch is gone,
  and the row count moved toward its budget.

Three GitHub actions came out of it: a correction on #253, issue #291 for the
register drifts, and a fourth item added to #291.
