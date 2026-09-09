# Decisions — as-svydesign-bridge

**One path rewritten at archive time.** The D-9 entry cited the measurements
document by its old plans-directory path, which the archive move retired. It
now names `measurements-as-svydesign-bridge.md`, beside this file in
`archive/as-svydesign-bridge/`. No document was lost and no other text
changed.

Every decision below is SETTLED. The user chose each one on 2026-09-08, after
the measurements in `measurements.md` §"Measured run — 2026-09-08". Do not
re-open one without new measurement.

---

## D-1 — A replicate FPC is dropped on the bridge, with a warning

**Status:** SETTLED. Issue #198's open design decision.

**Decision.** `.as_svydesign_replicate()` passes no `fpc` and no `fpctype` to
`survey::svrepdesign()`. When `@variables$fpc` names a column, the bridge
raises a surveycore warning that names `fpc` and states the field has no
effect on this route. All nine replicate types then convert.

**Why.** Three measured facts (R1, R2):

1. surveycore's own replicate estimator does not read the field. The SE is
   `identical()` with and without it: 0.029046583425 both.
2. surveycore's SE already equals survey's no-FPC SE, to -6.245e-17. Dropping
   the field makes the bridge agree with the package by construction.
3. Passing a derived FPC would make every converted SE `sqrt(1 - f)` times
   surveycore's own, measured at ratio 0.974679434481 for f = 0.05. The bridge
   would become the only place in surveycore where the field changes an answer.

**Rejected — option A, derive the per-replicate vector.** It buys the FPC's
effect and pays for it with a fixed disagreement against the package's own
estimate. It also needs: a gate refusing the six types survey rejects (R2), a
constancy check, and a `[0, 1]` range check that would refuse every
population-size FPC column `as_survey()` documents as valid.

**Rejected — option C, refuse the conversion.** Same end state as option B for
the user, and more work: they would have to call `update_design()` to clear the
key before converting.

**How to apply.** No type gate. No range check. No reshape. One warning, raised
before the `svrepdesign()` call, on the single condition
`!is.null(x@variables$fpc)`. survey's own `fpc` block is then never reached, so
`stop("fpc is wrong length")`, `stop("Separate fpc not needed for bootstrap")`
and `stop("fpc not available for this type")` become unreachable through the
bridge.

---

## D-2 — The plain nonprob shape warns with a new conversion-specific class

**Status:** SETTLED. Issue #237 offered either this or re-emitting the existing
class.

**Decision.** A new warning class, raised on the plain-shape nonprob path in
`as_svydesign()`. It carries the same caution as
`surveycore_warning_nonprob_srs_fallback` — the SEs use an SRS approximation
that understates calibration uncertainty, and
`surveywts::create_bootstrap_weights()` is the fix — and adds the one thing
only conversion introduces: the returned `survey` object carries no marker of
the approximation, so nothing warns again downstream.

**Why.** The existing class's bullets describe `get_*()` behaviour on a
surveycore design. The conversion's caution is about an object leaving
surveycore's hands. A distinct class lets a caller handle the two cases apart,
and lets the message say what the converted object cannot say for itself.

**Rejected — re-emit `surveycore_warning_nonprob_srs_fallback`.** Simpler, and
consistent for anyone already suppressing that class. It cannot state what
conversion adds without changing the message at one of its eight sites.

**How to apply.** The class name goes in `plans/error-messages.md` before any
code uses it, per `.claude/rules/code-style.md`. Dual test pattern: `class=`
plus a snapshot.

---

## D-3 — The `degf` difference is stated in the documentation only

**Status:** SETTLED.

**Decision.** One passage in `as_svydesign()`'s roxygen records that surveycore
uses `degf = Inf` for a nonprob design and `survey` computes a finite df from
the converted object. It states both measured values and what they are:
`n - 1` for the plain shape, `R - 1` for the replicate shape. It does not go in
the warning.

**Why.** Measured (R3): the plain shape converts to df 39, the replicate shape
to df 7, against `Inf` on both surveycore designs. The t/z ratio is 1.032004
and 1.206463. The larger gap belongs to the replicate shape, and the replicate
shape does not warn — it is the accurate path. A warning would therefore state
the smaller half of the difference and miss the larger. The documentation
covers both shapes.

A default `confint()` on a `svystat` uses `df = Inf`, so the difference reaches
a result only when the caller passes `degf(design)` or calls a survey function
that reads it. The passage should say that too, so a reader can size it.

---

## D-4 — `as_survey_replicate()`'s `@param fpc` is corrected in this PR

**Status:** SETTLED.

**Decision.** `R/core-constructors.R:610-612` currently tells the user the
replicate `fpc` column is "Used by some replicate methods to adjust the
variance estimator". Measured: no surveycore code applies it (R1). The line is
corrected in this PR to say surveycore stores the field and its replicate
estimator does not apply it, and that `as_svydesign()` drops it.

**Why.** D-1 introduces a warning saying the field has no effect. Leaving a
`@param` line in the same package that says the opposite would ship a
contradiction.

**How to apply.** `impact.md` listed six files. This adds `R/core-constructors.R`
and its `man/` page, for eight. The correction is documentation only: no
behaviour in `as_survey_replicate()` changes.

---

## Facts corrected during Stage 0

- **Line 535 is not the `from_tbl_svy()` `@return`.** Issue #237 names lines
  344 and 535 as the two that must not change. Line 344 is correct. PR #239
  shifted the `from_tbl_svy()` `@return` to line 588; line 535 is now
  `subset_var <- .find_col_by_value(...)`. Both reverse-direction `@return`
  lines — 344 and 588 — stay unchanged.
- **The Taylor helper does not delete a replicate-shaped design's replicate
  columns.** Issue #237 says it "silently drops all 8 replicate columns".
  Measured (R3): the columns stay in the frame as ordinary variables, and the
  returned `survey.design2` gives them no part in the variance. The
  consequence issue #237 draws is unchanged.

---

## D-5 — The three broken replicate types are corrected in claims only, and filed as three issues

**Status:** SETTLED. Taken during the methods review, 2026-09-08.

**Decision.** This PR does not change any replicate scale default. It corrects
every claim that overstates what converts, removes the CN-2 warning's promise
of standard-error equality, and adds test rows that record what actually
happens. Three issues are filed against `as_survey_replicate()`.

**Why.** The methods review measured that three of nine types are broken on the
bridge, and traced the cause to `as_survey_replicate()` and not to
`as_svydesign()`:

| `type` | Measured | Cause |
|---|---|---|
| JK2 | converts, SE high by `sqrt(R/(R-1))` = 1.069045 | `as_survey_replicate()` defaults `scale` to `(R-1)/R`; `as_survey_nonprob()` defaults it to 1; `survey::svrepdesign()` hardcodes 1 and discards what it is passed |
| Fay | does not convert | surveycore has no `rho` anywhere in its design code, and sets Fay's scale to `1/R`, which is BRR's. surveycore's Fay standard error is `identical()` to its BRR standard error |
| JKn at default `rscales` | does not convert | the estimator defaults `rscales` to `rep(1, R)`, so JKn with no `rscales` is `identical()` to JK1. `as_survey_nonprob()` already refuses to guess |

The two constructors disagree with each other, and on JK2 the nonprob one is
the one that matches survey. A gate in the bridge would hide a constructor
defect, so each fix belongs where the defect lives.

Measured three ways, all in `measurements.md`:

| Source | JK2 scale | SE of mean `y` |
|---|--:|--:|
| `as_survey_nonprob()` | 1 | 0.021698888900 |
| `survey::svrepdesign()` | 1 | 0.021698888900 |
| `as_survey_replicate()` | 0.875 | 0.020297451984 |

No test compares any of the three types against survey numerically. The test
named "JK2 default scale = 1 exactly" asserts the stored value on the nonprob
constructor, so it never saw the replicate constructor's 0.875.

**Rejected — fix JK2 and JKn here.** Both are one-line changes with a clear
right answer, and both move published numbers: JK2 by 6.9%, and JKn from an
accepted call to an error. Each needs its own NEWS entry, its own snapshot
review, and a pass over every existing JK2 and JKn test.

**Rejected — add `rho` as well.** A new exported argument, new validation and
new documentation, folded into a two-issue PR.

**How to apply.** Correct `spec.md` at the four "all nine" sites, at the CN-2
warning body and at the CN-2 register row. Add the test rows named in
`methods-review.md` R-4. File three issues before the PR opens, and cite each
issue number in the corrected text so a reader can follow it.

---

## D-6 — The dropped domain restriction is documented and filed, not fixed

**Status:** SETTLED. Taken during the methods review, 2026-09-08.

**Decision.** One roxygen passage in `as_svydesign()` states that the converted
object represents the full stored sample and not the active domain, and that a
caller has to subset the returned object themselves. `spec.md` gains the
edge-case row. No code changes, and no test that would lock in the present
behaviour. The fix is filed as its own issue.

**Why.** Measured on two independent fixtures: a design filtered to `y1 > 50`
gives mean 58.176655 in surveycore and mean 50.761561 through
`survey::svymean()` on the converted object. Subsetting the converted object on
the domain column recovers 58.176655 exactly. The point estimate is wrong, not
only the standard error.

The defect is pre-existing and reaches all four routes. Fixing it means editing
`.as_svydesign_taylor()` and `.as_svydesign_twophase()`, which `spec.md`
declares out of scope, and it needs its own test rows per route. Shipping it
silent a second time is the one option that was refused.

**How to apply.** The passage goes in the `as_svydesign()` roxygen block beside
the three sections D-1 to D-3 add. Name the domain column, so a reader can act
on the advice.

---

## D-7 — Print and summary mark the replicate FPC as unused

**Status:** SETTLED. Taken during the Stage 3 spec review, 2026-09-08, by
applying D-4's own accepted rationale.

**Decision.** `print(x, full = TRUE)` and `summary(x)` for a `survey_replicate`
design mark the FPC line as not used in variance estimation.
`R/methods-print.R:406-413` and `:828-831` are the two sites. The
`survey_taylor` sites, `:279` and `:781`, do not change: an FPC is active on
that class.

**Why.** D-4's rationale, which the user accepted, is that a warning saying the
field has no effect must not ship beside package documentation saying the
opposite. The print and summary output is the same contradiction in a different
surface, and it is the surface a user reads first. Today both render
`FPC: {col} ({fpctype})` beside `Scale:` and `MSE:`, which do drive the
variance, with nothing to separate the inert field from the active ones.

**Cost.** Two string edits and three snapshot lines in
`tests/testthat/_snaps/methods-print.md`. Adds `R/methods-print.R` and that
snapshot file to the write surface.

**How to apply.** Change only the two `survey_replicate` branches. Read the
neighbouring `survey_taylor` branches first and leave them alone.

---

## D-8 — One PR, over the row budget, not split

**Status:** SETTLED by the user's own instruction, given at the request, and
restated when the orchestrator raised the overage.

**Decision.** The whole change ships as one PR on `fix/as-svydesign-bridge`,
targeting `develop`, as two commits: issue #198 first, then issue #237. The
plan does not split it.

**The conflict this overrides.** `artifact-schemas.md` §PR budget bounds one PR
at 12 test-spec rows and 8 acceptance criteria. This work carries 31 rows. By
the budget rule alone the plan would split into three.

**The user's reason.** Both issues rewrite the same dispatch chain in the same
function. Two concurrent PRs would share `R/methods-conversion.R` and conflict
on every hunk.

**What the orchestrator raised, and what the user decided.** The orchestrator
put the overage to the user with the calibration behind the bound: row count
ranks PR size at Spearman rho 0.964 against hand-written additions, and PRs
past about 12 rows ran 700 to 1200 additions each. It offered a stacked pair,
`fix/as-svydesign-fpc` then `fix/as-svydesign-nonprob` branched off it, which
avoids the conflict because the second branch contains the first. The user did
not take it. One PR stands.

**How to apply.**

- The plan states one PR, both budget figures, and this decision as the reason
  the figures stand.
- The PR budget lens will compute the overage. That is correct behaviour, and
  the finding resolves by citing this decision, not by splitting.
- The two commits carry the split the branches do not: commit 1 is #198 and its
  rows, commit 2 is #237 and its rows. Each commit is a Conventional Commit.
- The budget ledger, `plans/pr-budget-calibration.md`, records the real diff
  after the merge. This PR is a data point against the bound, not an exception
  to be hidden: record 31 rows and whatever the diff turns out to be.

**What this costs.** A reviewer reads 13 files in one pass. If the reviewer
BLOCKs, the whole change waits on one fix rather than a third of it. The user
accepted that.

---

## Event — the branch was fast-forwarded onto develop mid-plan, 2026-09-08

Not a decision. A record, because it moved citations the spec depends on.

The original brief warned that issue #197 was in progress in another worktree,
in the same file, and that whichever branch landed second would rebase. It
landed first. `origin/develop` moved from `a7a52c0` to `1f15d35` while this
spec was under review, across two PRs, both issue #197:

- `4c79a5b fix(conversion): fold the base weight into factor-form replicate weights (#197) (#241)`
- `1f15d35 fix(conversion): refuse four unusable replicate sources on import (#197) (#247)`

`fix/as-svydesign-bridge` held no unique commits, so the update was a
fast-forward and not a rebase. No conflict, and the five frozen artifacts in
`plans/` are untracked and untouched.

What the two PRs changed, and what it cost this spec:

| File | Change on develop | Effect here |
|---|---|---|
| `R/methods-conversion.R` | +168 lines, all in the reverse direction | The two reverse `@return` lines moved: 344 to 364, and 588 to 750. **Every forward-direction citation holds**, verified line by line after the update |
| `tests/testthat/test-conversion.R` | +689 lines, appended | `make_rep` at 78, `test_invariants` at 121, 754, 1157 and the first `make_rep()` use at 141 all hold |
| `tests/testthat/_snaps/conversion.md` | **created**, 41 lines | The spec said this file did not exist and that the first snapshot row would create it. Now it exists and the new rows append |
| `plans/error-messages.md` | +36 lines, a new subsection `### svydesign-replicate-bridge rows (2026-09-04)` | The new subsection goes after that one, not after `var-extension-slot`. The `CB` prefix is now in use; `CN` is still free, verified at zero rows |
| `man/from_svydesign.Rd` | regenerated | Not a file this change touches |

Five corrections were applied to `spec.md` and `test-spec.md`. The
must-not-change lines are now identified by their text and their enclosing
function rather than by a number, because that pair has moved three times: 344
and 535 as issue #237 wrote them, 344 and 588 at base `a7a52c0`, and 364 and
750 now.

**Read before building.** Confirm the base is `1f15d35` or later. If develop has
moved again, re-verify the forward-direction citations first: the ones that
matter are `as_svydesign()` at 63, `.as_svydesign_replicate()` at 131, its
comment at 141-142, its `fpc` argument at 156, and the two
`surveycore_error_not_survey_object` sites at 88 and 271.

---

## D-9 — This work narrows to issue #237. The FPC half is handed to the other arc

**Status:** SETTLED by the user, 2026-09-09, on measured evidence of a
collision.

**Decision.** This PR ships issue #237 only: the `survey_nonprob` branch of
`as_svydesign()`. Issue #198, the replicate FPC drop, is dropped from this work
and ships as PR 4 of the `svydesign-replicate-bridge` arc, on branch
`fix/svydesign-replicate-fpc`.

**What the collision was.** That arc is at SHIPPING with three of five PRs
merged: #239, #241 and #247. Its PR 4 is titled "the FPC drop, the
empty-replicate guard" and reads "`as_svydesign()` drops the FPC out loud and
refuses a design that names no replicate column". That is issue #198's fix, in
the same function, on the same argument.

Two facts settled it:

- **The two arcs picked the same class name independently.** Their reserved
  row CB-3 is `surveycore_warning_replicate_fpc_dropped`, which is the name
  this spec's CN-2 proposed. Both reached drop-and-warn from the same
  measurement.
- **`plans/error-messages.md` already reserves the rows.** The
  `svydesign-replicate-bridge` subsection skips CB-2 to CB-5 and says "Rows
  CB-3 and CB-4 are the export-route conditions. They land with the export
  route, in the two pull requests that follow this one." The bindings block
  already defines `{fpc_var}` as "the name of the dropped FPC column".

Their CB-3 message is better than this spec's CN-2 on one point: its `"v"`
bullet sends the user to `survey::svrepdesign()` with `fpc`, which is the real
remedy for a per-replicate correction. CN-2 offered a rebuild with no `fpc`,
which silences the warning without giving the user the correction.

**What this work keeps.** The `survey_nonprob` branch. Their plan mentions
`survey_nonprob` zero times, so the nonprob route is unique to this work.

**What moves out, and where.**

| Item | Where it goes |
|---|---|
| D-1, the FPC drop and its warning | Their PR 4, as CB-3 |
| Issue #243, Fay's missing `rho` | Their PR 5, which recovers `rho` from the recorded scale and refuses a scale that yields none. That is a better answer than either option #243 offered. #243 is annotated |
| D-4, the `@param fpc` correction in `as_survey_replicate()` | Filed as its own issue. It states the field adjusts the variance, which is false, and their CB-3 does not touch it |
| D-7, the print and summary caveat | The same issue. Their CB-3 does not touch it either |
| Test-spec section A, section F, and row C-3 | Out of this work with D-1 |

D-4 and D-7 leave this PR for an ordering reason, not a scope one. Both describe
a warning that their PR 4 introduces. Shipping either before that PR would put
a claim in the package that the code does not yet support.

**What this work still carries, unchanged.** Issues #242, #244, #245, #246 and
#248 are all unique to this measurement and none is covered by their arc.
Verified: their spec and plan cover neither `JK2`'s scale default nor `JKn`'s
`rscales` default.

**Rejected — keep #198 here and stand their PR 4 down.** This spec measured the
FPC question further, and R1 to R13 hold findings their arc has not recorded.
But that arc owns the export route, is already shipping, holds the reserved
rows, and wrote the better remedy bullet. The measurements survive in
`measurements-as-svydesign-bridge.md` either way.

**Rejected — ship both and let the second rebase.** One function, one argument,
one class name, two register rows for one condition.

**How to apply.** Narrow `spec.md` and `test-spec.md` to the nonprob branch.
Row counts, file lists, budget figures, commit structure and quality gates all
re-derive. The branch stays `fix/as-svydesign-bridge` and the target stays
`develop`. One commit now, not two.

---

## Event — the base moved twice more, and issue #198 shipped without us, 2026-09-09

Not a decision. A record, and a vindication of D-9.

`origin/develop` went from `1f15d35` to `40700e3`. Four commits, and the
neighbouring arc finished:

- `8c99271 fix(conversion): drop the FPC on the replicate export route (#198) (#249)`
- `4440de1 fix(conversion): recover Fay's shrinkage factor on the export route (#250)`
- `079fb94 chore(plans): archive svydesign-replicate-bridge planning docs`
- `40700e3 docs(changelog): backfill fragments for #232 and #238`

**Issue #198 is CLOSED.** It shipped as PR #249, one day after D-9 handed that
half over. Had this work kept it, the two PRs would have collided in
`.as_svydesign_replicate()` on the same argument with the same class name.

`CLAUDE.md` now documents the arc under
`archive/svydesign-replicate-bridge/`, which is worth reading before any
further work on either conversion route. It records nineteen decisions, and it
names three gates that cannot be met as written.

The branch fast-forwarded again. It held no unique commits, so no conflict.

## What survived, and what moved

Re-measured as R14. Every figure the narrowed spec cites is unchanged: the
replicate shape converts to a `svyrep.design` with all eight columns, the
standard errors still agree exactly at 0.0200827192 and 0.5630671378, and
`survey::degf()` still gives 39 and 7.

Two substantive changes, both applied to the artifacts:

1. **The plain shape's failure through the replicate helper is now typed.** PR
   #249 added a guard, so it raises `surveycore_error_repweights_empty` instead
   of the bare `missing value where TRUE/FALSE needed` that R3 recorded. The
   two-routes conclusion is unchanged; only its evidence is newer.
2. **Row B-7 is no longer vacuous.**
   `surveycore_warning_replicate_fpc_dropped` exists now. The row asserted an
   absence that could not fail before, and it can fail now. It passes.

Citations updated: `as_tbl_svy()`'s `@param x` from 217-218 to 348-349, its
error class from 271 to 402, the two reverse `@return` lines from 364 and 750
to 495 and 881, and the snapshot file from 41 lines to 84.

## The standing instruction this produces

**Do not trust a line number in these artifacts.** The pair of reverse
`@return` lines has moved four times across five PRs. The spec now tells the
builder to find both by their text and their enclosing function, and to
re-verify the forward-direction anchors before starting. Those are
`as_svydesign()` at 63, the `else` branch's error class at 88,
`.as_svydesign_taylor()` at 96 and `.as_svydesign_replicate()` at 131, all
unmoved across four base changes.

---

## D-10 — No `NEWS.md` entry. The changelog fragment is the whole record

**Status:** SETTLED by the user, 2026-09-09.

**Decision.** This work writes `changelog/fix-as-svydesign-bridge.md` and no
`NEWS.md` entry. `NEWS.md` leaves the write surface, which returns to eight
files.

**What this supersedes.** The original request asked for a `NEWS.md` entry, and
said the last four shipped fixes were missing theirs. The user withdrew that on
2026-09-09: "I actually don't want you to add a news.md update. instead, just
include the changelog like normal."

**What it also settles.** The plan review found a contradiction the plan had to
work around. `.claude/agents/builder.md:138` lists "Modify `NEWS.md`
(orchestrating skill's job at ship time)" among the things a builder must not
do, and `.claude/agents/shipper.md:195` forbids editing it inside a PR. Five
recent PRs did it anyway: #239, #241, #247, #249 and #250 all carry bullets
under the development version's `## Bug fixes` heading.

An earlier revision of this plan resolved that by assigning the file to the
orchestrating skill. D-10 removes the need: the work writes nothing there, so
neither agent contract is strained and the question does not arise.

**What replaces it.** The changelog fragment, which the repo keeps one of per
arc. Base `40700e3` is itself `docs(changelog): backfill fragments for #232 and
#238`, and the neighbouring arc wrote
`changelog/fix-svydesign-replicate-bridge.md` for its five PRs. Neither agent
contract forbids that file.

**Two corrections to the changelog convention, both verified.**
`.claude/skills/changelog-workflow.md` gives the path as
`changelog/phase-{X}/{branch-name}.md` and a four-heading format. The last
three arcs wrote flat files at `changelog/{slug}.md` with a richer shape: a
header naming branches, status, date, PRs and issues, then Summary, Changes,
Files Modified and Verification. Follow
`changelog/fix-svydesign-replicate-bridge.md`, not the document.

**How to apply.** The quality gate is now that `NEWS.md` shows no diff at all.
The issue numbers this work cites live in the changelog fragment and in the
planning documents, and in no roxygen line and no vignette line.

---

## Baseline capture, 2026-09-09 — coverage not measured

**Classification**: recorded limit, not a HOLD. `pipeline-ship` §Step 0 holds
the pipeline for `dirty-baseline` when tests or `R CMD check` fail. Both
passed.

Measured on the branch tip `40700e3`, which equals `origin/develop`:

| Gate | Result |
|---|---|
| `devtools::test()` | PASS. FAIL 0, WARN 256, SKIP 4, PASS 11538. 8m28s. |
| `R CMD check --no-manual` | 0 errors, 0 warnings, 1 note. 11m53s. |
| `covr::package_coverage()` | **not measured.** Killed twice for low memory. |

The one check note is `checking for hidden files and directories ... NOTE`,
naming `.git`. It is an artifact of running the check inside a git worktree
and not a package defect. It is not one of the two pre-approved notes in
`.claude/rules/r-package-conventions.md`, so a tester reading that rule against
a worktree run will see three notes where the rule allows two. Read the note
text before treating it as a regression.

**Why coverage has no Before figure.** The machine held 2.06 GB free of
14.67 GB at capture time. `.claude/scripts/run-gates.sh` gate 7 and a bare
`covr::package_coverage()` were both killed by the low-memory watchdog. The
memory note `pipeline-ship-operational-facts` records the same failure at
3.3 GB free, so 2.06 GB is below a threshold already known to kill this gate.

**Consequence for the audit.** The Before column of this PR's coverage
comparison carries no measured figure. The last measured package figure is
96.0938% on `develop` at `e7493f0`, recorded in
`.claude/rules/testing-surveycore.md`; it predates four commits and is a
reference, not a baseline. The gate that decides the PR is the 95% floor in
`.claude/rules/testing-standards.md`, measured After. If the After measurement
is killed for the same reason, the floor is unmeasured and the pipeline holds
rather than assuming it.
