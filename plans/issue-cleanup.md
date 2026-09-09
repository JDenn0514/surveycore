# Issue cleanup plan

**Date:** 2026-09-09
**Base:** `develop` at `dbff0d9`; executed against `a0f2a7a`
**Open issues at start:** 24
**Open issues at end:** 20, each stating what it does and when to do it

> **Executed 2026-09-09.** Seven labels created; #254, #244, #183 and #184
> closed; #260 created; twenty issues rewritten.
>
> **Two PRs merged during the run**, which changes three rows below:
>
> - **PR #258 merged** (`d354af6`), closing #242. Its wrong `@param scale`
>   sentence went in unamended, and a second copy of the same claim sits in a
>   source comment at `R/core-constructors.R:798-800`. #260 now covers both
>   sites and is live work rather than a pre-merge amendment. PR 2 of the arc
>   is therefore done except for #260.
> - **PR #259 merged** (`6c31492`), landing #237's work. #237 itself is still
>   open — decide whether it closes. #245, #246 and #248 Part 1 are unblocked,
>   and `make_nonprob_zero_wt()` is on `develop` at
>   `tests/testthat/test-conversion.R:2946`, so #248 Part 2's dependency is now
>   real rather than prospective.
>
> **#184's verification ran:** `covr::package_coverage()` completes on
> `develop`, 96.2397%, exit code 0. Closed.

This plan removes the duplication and the conflicts between the open issues. It
does two things:

1. It locks the decisions that several issues each left open. Locked decisions
   live in this file, section "Decisions". An issue cites the decision number
   instead of re-arguing it.
2. It gives one instruction per issue: close it, or rewrite it. Every rewrite
   names the sentences to delete and the sentences to add.

Work through "Per-issue instructions" in order. Nothing in it depends on
anything below it.

---

## The rule

`survey` is the oracle for `as_survey_replicate()`. Where the two disagree,
surveycore changes. This covers the default scale, the default `rscales`, what
happens to a supplied `scale` or `rscales`, and which types accept which
arguments.

`as_survey_nonprob()` is out of scope. `survey` has no non-probability design
class, so it cannot be an oracle for one. That constructor keeps its cited
defaults and documents each divergence (D1).

---

## Evidence

Every fact below is read from `survey:::svrepdesign.default` under survey 4.5,
R 4.6.1, Windows, on 2026-09-09. Line numbers are `deparse()` positions in that
function, so a reader can reproduce them:

```r
src <- deparse(survey:::svrepdesign.default)
cat(paste0(seq_along(src), ": ", src), sep = "\n")
```

Three of the nine issue bodies in the replicate cluster quote this function from
memory of a session. This plan quotes the line numbers instead, and every
decision below carries one.

---

## Decisions

### D1 — Oracle scope: `as_survey_replicate()` only

`survey` is the oracle for `as_survey_replicate()`. `as_survey_nonprob()` keeps
`bootstrap = 1/R` (Wu 2022) and keeps refusing JK2 and JKn when `rscales` is
`NULL`. Both divergences get one sentence in the roxygen naming `survey`'s value
and the reason surveycore differs. Neither is a defect and neither gets an
issue.

### D2 — The target table

Nine types, nothing supplied by the caller:

| Type | `scale` | `rscales` | survey line |
|---|---|---|--:|
| JK1 | `(R-1)/R` | `rep(1, R)` | 96-106 |
| JK2 | `1` | forced `rep(1, R)` | 118-121 |
| JKn | `1` | **required from the caller** | 107-112, 148 |
| BRR | `1/R` | `rep(1, R)` | 79-84 |
| Fay | `1/(R * (1 - rho)^2)` | `rep(1, R)` | 86-87 |
| bootstrap | `1/(R-1)` | `rep(1, R)` | 88-95 |
| ACS | `4/R` | forced `rep(1, R)` | 114-116 |
| successive-difference | `4/R` | forced `rep(1, R)` | 114-116 |
| other | `1` | `rep(1, R)` | 123-128 |

Three cells change: JK2's scale, JKn's scale, bootstrap's scale. One cell adds
an argument: Fay's `rho`.

### D3 — JK2 does not use `rscales`

`survey` forces `rscales <- rep(1, ncol(repweights))` and `scale <- 1` for JK2
(lines 118-121). The per-stratum factors are built into the half-sample weights,
not carried in `rscales`.

This corrects the rationale, not the value. PR #258's new `@param scale` text
says JK2's "per-stratum factors belong in `rscales`". That sentence is wrong and
must not merge. The value it ships, `scale = 1`, is right.

### D4 — JKn requires `rscales`; JK2 does not

`survey` line 107-112: for JKn with `rscales = NULL`, it guesses only when
`combined.weights = FALSE`, and otherwise raises
`stop("Must provide rscales for combined JKn weights")`. `combined.weights`
defaults to `TRUE`, and surveycore stores combined weights, so the refusal is
the branch that applies.

So `as_survey_replicate()` refuses JKn with no `rscales`, and accepts JK2 with
no `rscales`. `.is_stratified_jk()` covers both types and cannot be reused as
it stands.

### D5 — bootstrap default becomes `1/(R-1)`

`survey` line 88-95: `scale <- bootstrap.average/(ncol(repweights) - 1)`.
`as_survey_replicate()` moves to `1/(R-1)`. `as_survey_nonprob()` stays at `1/R`
per D1.

`bootstrap.average` has no surveycore equivalent. Out of scope: it is a feature,
not a divergence, and no issue asks for it. Record it in the `@param scale`
roxygen as a known gap in `as_svydesign()` round trips.

### D6 — Fay gets a required `rho`

`survey` lines 10-11 raise `stop("With type='Fay' you must supply the correct
rho")`. Line 86-87 then sets `scale <- 1/(ncol(repweights) * (1 - rho)^2)`,
overriding any supplied `scale` with no warning.

`as_survey_replicate()` gains `rho = NULL`, validated `0 <= rho < 1`, required
when `type = "Fay"` and refused for every other type. This closes #243 in favour
of its option 1.

### D7 — What happens to a supplied `scale`, `rscales` or `rho`

Read off the source, per type:

| Type | supplied `scale` | supplied `rscales` | supplied `rho` | survey line |
|---|---|---|---|--:|
| BRR | warn, discard | honoured | warn, discard | 79-84 |
| Fay | discard, no warning | honoured | used | 86-87 |
| JK2 | warn, discard | warn, discard | warn, discard | 118-121 |
| ACS | warn, discard | warn, discard | warn, discard | 75-77, 114-116 |
| successive-difference | warn, discard | warn, discard | warn, discard | 75-77, 114-116 |
| JK1 | honoured | honoured | warn, discard | 12-14, 96 |
| JKn | honoured | honoured (required) | warn, discard | 12-14, 107 |
| bootstrap | honoured | honoured | — | 88-95 |
| other | honoured | honoured | warn, discard | 15-16, 123 |

This closes #255 in favour of its option 1, ignore and warn. It rules out option
2, refuse.

Two reasons option 2 loses. It cannot reproduce `survey` for an input `survey`
accepts, which the rule forbids. And it makes PR #250's Fay work unreachable:
that code recovers `rho` by inverting a non-default recorded scale, and refusing
an explicit scale for Fay means no design ever carries one.

#255's stated objection to option 1 — that an argument inert for some values of
another argument "has no precedent" in the register — is stale.
`surveycore_warning_replicate_fpc_dropped` shipped in PR #249 and is that
precedent.

### D8 — One deliberate divergence: do not warn when the caller supplied nothing

`survey`'s JK2 branch warns unconditionally. Line 118-119 sits outside any
`is.null()` test, so `svrepdesign(type = "JK2")` with no `scale` and no
`rscales` still warns that both "are not needed and will be ignored".

surveycore warns only when the caller actually supplied one of them. Reason:
#167 is open because 256 unasserted warnings already mask new ones, and a
warning that fires when the user passed nothing tells the user nothing. Record
it in the `@param scale` roxygen as a deliberate divergence, with this
reasoning.

### D9 — JK1: the numbers agree, the warnings do not

`survey` has no JK1 default. Lines 96-106 guess and warn, twice over: from the
weights when `combined.weights = FALSE`, and as `(probably.n - 1)/probably.n`
otherwise, where `probably.n` is the replicate count.

With combined weights the guess equals `(R-1)/R`, which is surveycore's
documented default. So the value agrees and the warning does not. surveycore
keeps its default and raises nothing, because a documented default is not a
guess. No code change. #256's JK1 oracle block must expect `survey`'s warning
and let it stand.

### D10 — The export route stops round-tripping the scale

`as_svydesign()` passes `x@variables$scale` into `svrepdesign()` at
`R/methods-conversion.R:166` for every type but BRR and Fay. Under D7 `survey`
discards it for JK2, ACS and successive-difference, so the exported object stops
reproducing surveycore's own number whenever the recorded scale is not the value
`survey` computes.

The route stops passing `scale` for the five types `survey` overrides, and
passes `rho` for Fay from the new `@variables$rho` rather than inverting the
recorded scale.

Two consequences to carry into the work:

- PR #250's inversion at `R/methods-conversion.R:171-235` retires.
- `surveycore_error_fay_rho_unrecoverable`, register row CB-4, becomes
  unreachable. Remove the row, or restate it for the one case that survives: a
  design whose `rho` is absent because it predates D6.

### D11 — `type = "other"`

`survey` warns when `scale` or `rscales` is unset for `type = "other"` and sets
both to 1 (lines 123-128). surveycore's default of `1` agrees. Keep the value,
raise nothing, same reasoning as D9. No code change and no issue.

### D12 — Locked: `as_survey_replicate()` refuses an `fpc`

This one inverts an issue, so it is spelled out rather than folded in.

**The facts.** `as_survey_replicate(fpc = )` is a tidy-select column, one value
per row (`R/core-constructors.R:202-249`). `survey`'s replicate `fpc` is a
numeric vector of length `R`, one value per replicate; it multiplies `rscales`
(line 146); it is refused for BRR, Fay, JK2, ACS, successive-difference and
bootstrap (lines 136-139); and `fpctype` is mandatory whenever it is given
(lines 133-134).

surveycore's replicate FPC is inert for all nine types. #251 measured that and
proposed documenting it.

**So #251 inverts.** Under the rule, "the FPC changes no standard error" is not
a fact to document. It is the divergence. `survey` applies an FPC for JK1, JKn
and `other`, and refuses it for the rest. surveycore does neither.

**The decision: refuse it.** `as_survey_replicate(fpc = )` and its `fpctype`
raise a typed error naming `as_survey()` for a Taylor design. No caller's
number changes, because the argument has never affected a replicate standard
error in any released version.

Two options lost. Implementing it — a length-`R` vector, refused for six types,
`fpctype` required, multiplying `rscales` — is the only full match, but it is a
new estimator path with no caller asking for it and a breaking change to an
argument's type. Keeping it inert and documenting it is what #251 says today,
and the rule forbids it.

Your own source already makes the case. `R/methods-conversion.R:240-253`,
shipped in PR #249, records the shape mismatch and ends: "Reshaping the column
to length R would give the right shape and the wrong quantity." An argument that
cannot be given the right quantity is better removed than described.

**Five consequences to carry into #251's PR.**

1. `surveycore_warning_replicate_fpc_dropped` becomes unreachable. No replicate
   design can carry an FPC, so the export route never drops one. Remove the
   warning, the register row and `R/methods-conversion.R:255-278`, the same
   category as CB-4 in D10.
2. The two `survey_replicate` FPC print branches become dead, not
   mis-labelled. `R/methods-print.R:409` and `:830` render
   `FPC: <col> (<fpctype>)` for a class that can no longer hold one. #251 asks
   to mark them "not used in variance estimation". Delete them instead.
3. Thirteen test call sites pass `fpc =` to `as_survey_replicate()` and each
   becomes an expected error: `test-constructors.R` (8), `test-conversion.R`
   (2), `test-effective-n.R` (1), `test-labelled-storage.R` (1),
   `test-methods-print.R` (1).
4. `from_svydesign()` needs a pass. The Taylor route at
   `R/methods-conversion.R:557-560` reads an `fpc` from the survey call and is
   unaffected. Confirm the replicate import route cannot hand one to the
   constructor, and give it the same refusal if it can.
5. One new register row for the refusal, added to `plans/error-messages.md`
   before the code, per `.claude/rules/code-style.md`.

If a user later asks for a working replicate FPC, file it then as a feature with
`survey`'s rules from lines 132-147 as the spec. Do not pre-build it.

---

## The header every issue gets

Every rewritten issue opens with exactly these four lines, before any prose. The
point is that the title plus this block answers "what is this and when do I do
it" with no scrolling.

```markdown
**Does:** <one sentence, active voice>
**When:** <PR n of the replicate-scale arc | after #NNN merges | backlog, no trigger>
**Decision:** <locked, D-n in plans/issue-cleanup.md | needed before start: ...>
**Write surface:** <files>
```

Then keep the issue's existing measurements. They are the reason these issues
are worth having, and no instruction below deletes a measurement. What gets
deleted is re-argued options, stale blockers and duplicated rationale.

---

## Labels to create

```bash
gh label create "arc:replicate-scale" --color 1d76db --description "Matches as_survey_replicate() to survey::svrepdesign()"
gh label create "arc:conversion"      --color 1d76db --description "as_svydesign() / from_svydesign() bridge"
gh label create "arc:validators"      --color 1d76db --description "S7 validators and post-construction assignment"
gh label create "tier:blocker"        --color b60205 --description "An exported function returns a wrong number, silently"
gh label create "tier:pre-submission" --color fbca04 --description "Fix before the next CRAN submission; no wrong number"
gh label create "tier:backlog"        --color 0e8a16 --description "No trigger; pick up when the trigger in the issue fires"
gh label create "decision-needed"     --color d876e3 --description "Blocked on a decision, not on work"
```

---

## Summary of actions

| Issue | Action | Result |
|---|---|---|
| #257 | Rewrite | The one tracker. Holds the PR map, cites D1-D12. |
| #256 | Rewrite | PR 1. Oracle rule and nine blocks. |
| #242 | Rewrite + amend PR #258 | PR 2. Fix the D3 rationale before merge. |
| #260 | **Created 2026-09-09** | The D3 rationale, tracked so it survives #242 closing. |
| #253 | Rewrite, absorbs #254 | PR 3. JKn and bootstrap defaults, one migration note. |
| #254 | **Close** | Into #253. D5 decides it. |
| #255 | Rewrite, absorbs #244 | PR 4. Argument handling per D7, D8. |
| #244 | **Close** | Into #255. D4 narrows it to JKn. |
| #243 | Rewrite | PR 5. Add `rho` per D6; retire PR #250's inversion per D10. |
| #251 | Rewrite — it inverts | PR 6. Blocked on D12. |
| #237 | Leave open, add one comment | PR #259 is open. Comment the #248 coupling. |
| #245 | Rewrite | After #259. Tier 1, the only wrong point estimate. |
| #248 | Rewrite — split in two | The row-count omission, and the weight-sign decision. |
| #234 | Rewrite | Depends on #248's decision. |
| #246 | Rewrite — widen to three families | The single duplicated-guard issue. |
| #199 | Rewrite — hand one section to #246 | Factor totals, plus the register row 43 fix. |
| #200 | Rewrite | Blocked on #199. |
| #235 | Rewrite — lock option 2 | Return the column count. |
| #218 | Rewrite — lock options 1 and 3 | Widen the wrapper, record the bound. |
| #180 | Rewrite — drop the frozen counts | They conflict with #167 and with the rule. |
| #167 | Rewrite | Add the #180 ordering constraint. |
| #182 | Rewrite | Backlog. Note that it obsoleted #183. |
| #183 | **Close** | Superseded by #182, per its own text. |
| #184 | **Close after one run** | Verify `covr` on `develop` first. |
| #165 | Rewrite | Pipeline tooling chore. |

Four closes. Twenty rewrites. One new issue, #260.

#260 earns its place for one reason: the sentence it corrects lives in PR #258,
and #242 closes the moment that PR merges. Tracking the correction inside #242
means the tracking dies with the issue if the PR merges unamended. Every other
candidate for a new issue fit inside one that already exists.

---

## Per-issue instructions

### Closes

**#254 — close.**

```bash
gh issue close 254 --comment "Decided by D5 in plans/issue-cleanup.md: as_survey_replicate() moves to 1/(R-1), matching survey::svrepdesign() line 92. as_survey_nonprob() keeps 1/R on Wu 2022 per D1. The work and the measurement move to #253, which ships both changed defaults under one migration note. Nothing here is lost: #253 carries the bootstrap.average gap and the mse pairing."
```

**#244 — close.**

```bash
gh issue close 244 --comment "Narrowed and absorbed by #255. D4 in plans/issue-cleanup.md: survey refuses JKn with no rscales (line 112) and forces rscales = rep(1, R) for JK2 (line 120). So the refusal is right for JKn and wrong for JK2, and this issue proposed both. The JKn half moves to #255, which owns per-type argument handling. Note for whoever picks it up: .is_stratified_jk() covers both types and cannot be reused as it stands."
```

**#183 — close.**

```bash
gh issue close 183 --comment "Superseded by #182, as this issue's own 'Check #182 first' section anticipated. The measurement survives in archive/polychoric-performance/implementation-plan-polychoric-performance.md, Steps 0.5 and 5: 42 distinct keys on the wt = 1 fixture with a within-key spread of exactly 0, and 300 of 300 on lognormal weights, so the dedup is inert on real calibrated weights. Reopen only if #182 is abandoned."
```

**#184 — close, after one verification run.**

Run this first. Do not close on the argument alone:

```bash
NOT_CRAN=true Rscript -e "covr::package_coverage()"
```

If it completes, close with the figure. If it segfaults, keep it open, relabel
`tier:pre-submission`, and replace the body's "Suggested next steps" with the
bisection step that was never finished.

```bash
gh issue close 184 --comment "Stale. The branch merged as PR #185, and covr::package_coverage() completes on develop at dbff0d9 (<FIGURE>%). The CI test-coverage job has run green on every push since. Reopen if it recurs, with the branch name."
```

### The replicate-scale arc

**#257 — rewrite as the only tracker.**

Header:

```markdown
**Does:** Tracks the arc that makes as_survey_replicate() match survey::svrepdesign().
**When:** Open until every row of the table below reads "agree" and a test pins it.
**Decision:** Locked, D1-D11 in plans/issue-cleanup.md. D12 is open.
**Write surface:** None. This issue ships no code.
```

Edits:

1. Replace the "Verdicts against the literature" section with a pointer to D1-D12.
   The literature argument is settled and re-reading it costs a reader four
   screens.
2. Replace the "Work" checklist with the PR map at the end of this plan, PR
   numbers and all.
3. Delete `[x] #242`. #242 is open and PR #258 is unmerged; the checkbox says
   otherwise.
4. Delete the closed issues from the list: #254 and #244.
5. Keep "How it happened" and "Why the tests did not catch the rest" as they
   are. They are the only account of the root cause and they belong here.
6. Keep the audit table. Add a `survey` line-number column, so the next reader
   verifies it without a session.
7. Keep "Not in scope" and add D8, D9 and D11 to it — three divergences that
   are now deliberate, so the next audit does not re-report them.

**#256 — rewrite. PR 1.**

Header:

```markdown
**Does:** Rewrites the nine replicate oracle tests so a wrong default fails.
**When:** PR 1 of the replicate-scale arc. Ship before every value fix, so the rest land as red going green.
**Decision:** Locked, D2 and D7-D9.
**Write surface:** tests/testthat/test-variance-replicate.R, .claude/rules/testing-surveycore.md
```

Edits:

1. Keep the mechanism section, the coverage table and the proposed rule. They
   are the whole point of the issue.
2. Correct the rule's `rscales` clause. It says supply `rscales` "only where
   `survey` refuses without it". Per D4 that is JKn alone, and per D7 `survey`
   discards `rscales` for JK2, ACS and successive-difference, so a block that
   supplies it there provokes a warning rather than a comparison.
3. Add the expected warnings per D7 and D9, so a block asserts the warning
   instead of silencing it. JK1 warns that it guessed. JK2, ACS and
   successive-difference warn only when the block supplies something.
4. Add: the Fay block needs D6's `rho` and cannot be written before #243. The
   bootstrap block is decided by D5 and can be written now. That corrects the
   current "two of the nine need a decision" note, which listed both as blocked.
5. Add the `survey` line numbers from D2 to the per-type expectations.

**#242 — rewrite, and amend PR #258 before it merges. PR 2.**

Header:

```markdown
**Does:** Defaults JK2's scale to 1 rather than (R-1)/R.
**When:** PR 2 of the replicate-scale arc. PR #258 is open and carries the work.
**Decision:** Locked, D2 and D3.
**Write surface:** R/core-constructors.R, man/as_survey_replicate.Rd, tests/testthat/test-constructors.R, tests/testthat/test-variance-replicate.R, NEWS.md, changelog/
```

Two amendments to PR #258, both in `@param scale` and its regenerated `man/`
page. The value it ships is right; the reason it gives is not.

1. Delete: "`\"JK2\"` is the paired jackknife, so its per-stratum factors belong
   in `rscales` and the overall scale stays at `1`."
2. Add, per D3: JK2 builds the per-stratum factors into the half-sample weights.
   `rscales` stays at `rep(1, R)` and the overall scale stays at `1`.
   `survey::svrepdesign()` forces both.
3. The test comment in `test-variance-replicate.R` already states this
   correctly — "fixes scale = 1 and rscales = rep(1, R) for JK2 and warns that
   it ignores both arguments". The roxygen and the test comment currently
   contradict each other across two files. Make the roxygen match the test.

Settle the `NEWS.md` question on the way through. The branch edits `NEWS.md`,
which `.claude/agents/builder.md:138` and `.claude/agents/shipper.md:195` both
forbid, and five recent PRs already contradict those two lines. Keep the entry
and correct the two contracts: the person who measured the change writes a
better migration note than the release step reconstructs.

**#253 — rewrite to absorb #254. PR 3.**

Header:

```markdown
**Does:** Defaults JKn's scale to 1 and bootstrap's to 1/(R-1), finishing the default-scale table.
**When:** PR 3 of the replicate-scale arc, after #242.
**Decision:** Locked, D1, D2 and D5.
**Write surface:** R/core-constructors.R, man/as_survey_replicate.Rd, tests/testthat/test-constructors.R, tests/testthat/test-variance-replicate.R, NEWS.md, changelog/
```

Edits:

1. Retitle: `as_survey_replicate()` defaults for JKn and bootstrap do not match
   `survey`.
2. Keep the JKn measurement and root cause as they are.
3. Add #254's bootstrap measurement, its two-convention section and its
   `bootstrap.average` note. Cite D5 for the outcome, and D1 for why
   `as_survey_nonprob()` stays at `1/R`.
4. Delete the "Interaction with #244" section. D4 dissolves it: JKn keeps the
   `rscales` requirement, so the pairing argument is now internal to #255.
5. Add the migration note, covering both changed defaults and #242's. Three
   changed defaults, one release, one note. Every JK2 and JKn design built at
   the default rises by `1/sqrt((R-1)/R)`; every bootstrap design rises by the
   same factor.
6. Add: `as_survey_nonprob()`'s roxygen gains the D1 sentence in this PR, so the
   two constructors' divergence is documented the moment it widens.

**#255 — rewrite to absorb #244. PR 4.**

Header:

```markdown
**Does:** Makes as_survey_replicate() handle a supplied scale, rscales and rho the way survey::svrepdesign() does.
**When:** PR 5 of the replicate-scale arc, after #243. It handles every argument, so it ships once every argument exists.
**Decision:** Locked, D4, D7 and D8.
**Write surface:** R/core-constructors.R, R/methods-conversion.R, plans/error-messages.md, man/, tests/
```

Edits:

1. Delete the "What to decide" section, all three options. D7 chose option 1,
   ignore and warn. Replace it with D7's table and one sentence on why option 2
   lost: it cannot reproduce `survey` for an input `survey` accepts, and it makes
   PR #250's Fay work unreachable.
2. Delete the sentence claiming an inert argument "has no precedent" in the
   register. `surveycore_warning_replicate_fpc_dropped` shipped in PR #249.
3. Keep the measured five-type table and the explicit-scale measurement.
4. Add #244's JKn half per D4: refuse JKn when `rscales` is `NULL`, reusing
   `surveycore_error_stratified_jk_rscales_unset`. Add explicitly that JK2 must
   **not** be refused, and that `.is_stratified_jk()` therefore cannot be reused
   unchanged.
5. Add the `rho` column from D7. A `rho` supplied for a non-Fay type warns and
   is discarded. #243 adds the argument as PR 4, so this PR handles all three
   arguments in one validation block rather than splitting the rules across two
   releases.
6. Add D8 as a stated divergence: warn only when the caller supplied something.
7. Add D10's export-route change as the second half of the PR: stop passing
   `x@variables$scale` for the five overridden types at
   `R/methods-conversion.R:166`.
8. New register rows needed: one warning class per discarded argument. Name them
   in the issue and add the rows to `plans/error-messages.md` before the code, per
   `.claude/rules/code-style.md`.

**#243 — rewrite. PR 5.**

Header:

```markdown
**Does:** Adds a required rho argument for type = "Fay", which currently computes BRR.
**When:** PR 4 of the replicate-scale arc, after #253.
**Decision:** Locked, D6 and D10.
**Write surface:** R/core-constructors.R, R/variance-replicate.R, R/methods-conversion.R, plans/error-messages.md, man/, tests/
```

Edits:

1. Delete the "Scope" section's two options. D6 chose option 1, add `rho`.
2. Delete the stale sentence: "The same design cannot cross `as_svydesign()`
   either: the bridge passes no `rho`, so `survey::svrepdesign()` raises its bare
   `stop`". PR #250 fixed that route, and `R/methods-conversion.R:171-235`
   recovers `rho` by inverting the recorded scale.
3. Add the D10 reconciliation, which the issue does not mention at all:
   - `.as_svydesign_replicate()` passes `@variables$rho` and stops inverting the
     scale.
   - PR #250's inversion retires.
   - `surveycore_error_fay_rho_unrecoverable`, row CB-4, becomes unreachable.
     Remove the row, or restate it for a design whose `rho` is absent because it
     predates this change.
4. Add, per D7: `survey` overrides a supplied Fay scale silently, with no
   warning. So Fay is the one type of the five where surveycore discards `scale`
   and raises nothing.
5. Add: DESCRIPTION advertises "replicate weights (BRR, Fay, jackknife,
   bootstrap)". The Fay claim is not true today and CRAN reviewers read that
   field. This PR makes it true.
6. Keep the Fay measurement and the `survey` source quotation.

**#251 — rewrite. It inverts. PR 6.**

Header:

```markdown
**Does:** Refuses an fpc on as_survey_replicate(). The argument has never affected a replicate standard error, and survey's equivalent is a different quantity.
**When:** PR 6 of the replicate-scale arc.
**Decision:** Locked, D12 in plans/issue-cleanup.md. Refuse.
**Write surface:** R/core-constructors.R, R/methods-conversion.R, R/methods-print.R, plans/error-messages.md, man/, tests/ (5 files)
```

This is the largest rewrite in the plan. The issue as filed proposes documenting
that the FPC changes no standard error. Under the rule, that is the divergence
rather than a fact to document.

Edits:

1. Retitle: `as_survey_replicate()` accepts an `fpc` that does nothing; refuse
   it.
2. Keep the measurement. It is the proof the field is inert:
   `R/variance-replicate.R` holds zero occurrences of `fpc`, and the standard
   error is `identical()` with and without it.
3. Delete the "Why this is filed separately" section entirely. It says the fix
   "cannot ship before" the export-route warning and names an unshipped branch.
   `surveycore_warning_replicate_fpc_dropped` is on `develop` at
   `R/methods-conversion.R:277`. This issue is unblocked.
4. Replace the "Suggested fix" list, all four items, with D12's decision and its
   five consequences. The old list described the field; the new one removes it.
5. Add `survey`'s rules from lines 132-147 as the reason the argument cannot be
   translated: length `R`, one multiplier per replicate, multiplies `rscales`,
   refused for six of the nine types, `fpctype` mandatory. Cite
   `R/methods-conversion.R:240-253`, which records the same finding.
6. Keep the two `survey_taylor` sites in the "must not change" list. An FPC is
   active on that class and this issue must not reach it.
7. Rewrite the "Verification" section. The old one searches the regenerated
   `man/` page for two phrasings that must not survive. Under the refusal the
   `@param fpc` and `@param fpctype` blocks go away, so the checks become: the
   help page documents no `fpc` argument for this constructor; the typed error
   fires on `fpc` and on `fpctype`; `print(d, full = TRUE)` and `summary(d)` on a
   replicate design render no FPC line; and the two `survey_taylor` sites are
   unchanged, confirmed by a line-level diff.
8. Add: this is a breaking change. An accepted argument becomes an error. It
   needs a NEWS entry and a changelog fragment, and it rides the same migration
   note as PRs 2 to 5 if it ships in that release.

### The conversion arc

**#237 — leave open. Add one comment.**

PR #259 carries the work. Do not edit the body. Add the coupling that neither
the issue nor #248 records:

```bash
gh issue comment 237 --body "Coupling with #248, for whoever merges this. This PR's fixture make_nonprob_zero_wt() writes a zero weight into @data because the survey_nonprob validator permits one, and test B-11 depends on that design building. #248 proposes settling the weight-sign question by aligning .validate_weights() with the class validator. If the alignment makes the validator strict, this fixture stops building. #248's rewrite records the dependency; merge this first."
```

**#245 — rewrite.**

Header:

```markdown
**Does:** Applies a filtered design's domain restriction to the object as_svydesign() returns. Today the converted object answers for the whole sample.
**When:** After #259 merges. Both write R/methods-conversion.R.
**Decision:** Locked. Subset on SURVEYCORE_DOMAIN_COL in each route.
**Write surface:** R/methods-conversion.R, tests/testthat/test-conversion.R
```

Edits:

1. Keep everything. This issue is well formed, measured, and the only one on the
   list where a point estimate is wrong.
2. Add the `tier:blocker` label and say so in the header: the point estimate is
   wrong, not only the standard error.
3. Keep both deferred questions as they are. Neither blocks the fix.

**#246 — rewrite, widened to all three duplicated-guard families.**

Header:

```markdown
**Does:** Extracts three families of duplicated guard into shared helpers.
**When:** After #259 merges, which adds the eighth site of family 1.
**Decision:** Locked. Extract all three; no behaviour changes.
**Write surface:** R/utils.R and the call sites listed per family
```

Edits:

1. Keep family 1, the seven nonprob repweights routing sites plus #237's eighth,
   and the table naming them.
2. Promote the "Not this issue" note to family 2: the four
   `surveycore_error_not_survey_object` sites at `R/methods-conversion.R:83-89`,
   `:266-272`, `R/utils.R:258-264` and `:322-328`.
3. Add family 3, currently buried in #199's suggested fix: seven copies of the
   non-numeric guard at `analysis-means.R:157`, `analysis-quantiles.R:191`,
   `analysis-ratios.R:186` and `:196`, `analysis-t-test.R:167`,
   `analysis-totals.R:156`, `analysis-variance.R:182`.
4. Correct the verification step. It requires "the warning's first bullet appears
   once in `R/`". PR #259 raises a new class,
   `surveycore_warning_nonprob_srs_conversion`, whose first bullet is worded
   differently. So family 1 is seven identical bullets plus one variant. Decide
   in the issue whether the variant folds into the shared source or stays
   separate, and state which.
5. Add: family 3 interacts with #199, which relaxes one of its seven copies for
   `get_totals()`. Extract before #199, or #199 extracts as it goes. Say which
   in whichever ships first.

### The validators arc

**#248 — rewrite, split into an omission and a decision.**

Header:

```markdown
**Does:** Adds the constructors' row-count check to all four S7 validators, so @data assignment cannot install a 0-row or 1-row design.
**When:** After #259 merges. Its fixture depends on the current permissiveness.
**Decision:** Part 1 locked. Part 2 needed before start: the weight-sign rule.
**Write surface:** R/core-classes.R, tests/
```

Edits:

1. Keep both measurement tables and the root cause. `grep -c "nrow|NROW"
   R/core-classes.R` returning 0 is the whole finding.
2. Split the body under two headings, so the actionable half is not gated on the
   undecided one:
   - **Part 1, the omission.** Add the row-count check to each of the four
     validators, reusing `R/core-validators.R:77-80` and `:100-109`. No decision
     needed. Do this.
   - **Part 2, the decision.** Whether `survey_nonprob` keeps its deliberate
     permissiveness on a single zero weight, recorded at
     `plans/error-messages.md` row 33, or whether `.validate_weights()` stops
     being stricter than the class it validates. Label `decision-needed`.
3. Add the PR #259 conflict, which the issue does not record: PR #259's fixture
   `make_nonprob_zero_wt()` needs a zero weight to pass the nonprob validator.
   Part 2 must not be answered "align strictly" without a plan for that fixture.
4. Add: this issue's row-count question and #234's `visible_vars` question are the
   same underlying question — is post-construction property assignment a
   supported route? Answer it here, once, and #234 follows.

**#234 — rewrite.**

Header:

```markdown
**Does:** Removes two nocov markers on the visible_vars print path, whose stated reason is wrong, and tests the path.
**When:** After #248 Part 2 answers whether direct @variables assignment is supported.
**Decision:** Needed before start: see #248.
**Write surface:** R/methods-print.R, tests/testthat/test-methods-print.R
```

Edits:

1. Keep the measurement and the printed output. They are the trigger the rule
   asks for.
2. Replace the "One question to settle first" section with a pointer to #248
   Part 2. Both issues currently pose the same question independently, and #234's
   fix depends on the answer: if the property should reject a key it does not
   own, the path becomes unreachable again and the markers were right.

### The backlog

**#199 — rewrite.**

Header:

```markdown
**Does:** Accepts a factor in get_totals(), expanding it to one indicator per level.
**When:** Backlog. Trigger: a user asks for factor totals, or #200 starts.
**Decision:** Locked on the approach. Three sub-decisions listed in the body.
**Write surface:** R/analysis-totals.R, plans/error-messages.md, man/, tests/
```

Edits:

1. Keep everything measured: the `svytotal()` target output, the two
   already-working routes, and the proof that `get_freqs()` is not a workaround
   at 22% too small.
2. Delete the sentence listing the "seven independent copies of the same guard".
   It moves to #246 as family 3. Replace it with: relax the inline check at
   `R/analysis-totals.R:153-156`; see #246 family 3 for the duplication.
3. Keep the three open sub-decisions — level naming, zero rows for unused levels,
   `NA` handling — as a list. They are implementation detail, not blockers.
4. Keep the "Secondary" register row 43 correction. It is measured and cheap.

**#200 — rewrite.**

Header:

```markdown
**Does:** Produces a k x k covariance matrix that surveywts::calibrate_to_estimate() accepts.
**When:** Backlog, blocked on #199. Trigger: surveywts needs it without the survey-package workaround.
**Decision:** Needed before start: shape A or shape B.
**Write surface:** 3 to 4 files, 6 to 8 functions. Named in the body.
```

Edits:

1. Keep it all. The issue is well argued, the workaround is documented, and the
   proof that the estimator math already ships at k = 3 is the reason it is
   bounded.
2. Make the #199 block explicit in the header, as above. It is currently one
   sentence in the middle of the "Two possible shapes" section.

**#235 — rewrite, decision locked.**

Header:

```markdown
**Does:** Makes length() on a design return the column count, so it agrees with names(), ncol() and data.frame.
**When:** Backlog. Parallel-safe with anything; touches one file.
**Decision:** Locked. Option 2, return the column count.
**Write surface:** R/methods-compat.R, tests/
```

Edits:

1. Delete options 1, 3 and 4. Keep one sentence of option 2's reasoning: it is
   the only option that removes an inconsistency rather than restating a
   preference, and it matches `data.frame`, `names()` and the survey package.
2. Keep both comparison tables. They are the argument.

**#218 — rewrite, decision locked.**

Header:

```markdown
**Does:** Widens .ls_without_haven() to clear haven's base-generic methods too, and records what the helper does and does not simulate.
**When:** Backlog, before the next CRAN submission. CRAN has a no-Suggests flavour.
**Decision:** Locked. Options 1 and 3, as the issue's author leaned.
**Write surface:** tests/testthat/test-labelled-storage.R, .claude/rules/testing-surveycore.md
```

Edits:

1. Delete option 2, the separate library. Keep one sentence: it is the only
   honest measurement, and a whole CI job for one premise costs more than the
   risk, now that the strip removes the class before any dispatch.
2. Keep the helper source, the misled row from §4.11a and the general rule it
   states. That rule is the deliverable of option 3.
3. Keep both checkboxes. Change the first from "Pick an option" to the locked
   pair.

**#180 — rewrite. Drop the frozen counts.**

Header:

```markdown
**Does:** Splits test-dataset-metadata.R into three files, each with one section-numbering scheme.
**When:** Backlog. Must not run concurrently with #167.
**Decision:** Locked. The three-way split in the body.
**Write surface:** tests/testthat/, .claude/rules/testing-surveycore.md
```

Edits:

1. Keep the two-numbering-scheme finding, the header finding and the proposed
   three-way split. The colliding schemes are the actual defect and the split
   table is ready to execute.
2. Delete the frozen gate numbers: "must still end FAIL 0, SKIP 4, PASS 9,847"
   and "coverage must still read 96.0938%". Three reasons. #167 reports `PASS
   16691` for the same suite, so one of the two open issues is already stale.
   `.claude/rules/testing-surveycore.md` forbids recording exact expectation
   totals because they go stale within a few merges, citing #215. And #184 leaves
   the coverage figure unverifiable until `covr` is confirmed working.
3. Replace them with the gates that hold: the `test_that()` block count is
   unchanged before and after, coverage does not fall, and `_snaps/` moves with
   the blocks under `snapshot_review()` rather than blind acceptance.
4. Add the ordering constraint against #167, which changes the counts this issue
   must not freeze.

**#167 — rewrite.**

Header:

```markdown
**Does:** Asserts or removes the 256 unasserted small-cell warnings, so the warning count works as a regression signal again.
**When:** Backlog. Must not run concurrently with #180 or #237.
**Decision:** Locked. Per call site, by what the test is about.
**Write surface:** tests/testthat/, incrementally per file
```

Edits:

1. Keep the whole issue. The reasoning is sound and the two-option fix per call
   site is right.
2. Add the ordering constraints: it reaches `test-conversion.R`, which PR #259
   rewrites, and it moves the counts #180 gates on.
3. Add: `archive/svydesign-replicate-bridge/decisions-svydesign-replicate-bridge.md`
   D12 records that gate 2's "0 warnings" is unmeetable because of these 256, so
   the pipeline gates read as "no new warning" until this issue closes. That is
   the concrete cost of leaving it open, and it is currently recorded only in an
   archived document.

**#182 — rewrite.**

Header:

```markdown
**Does:** Replaces the n-refit numerical influence function for polychoric and polyserial variance with an analytic one.
**When:** Backlog, no trigger. Pick up when a user hits the O(n)-refit cost on real data.
**Decision:** Needed before start: a spec, per the issue's own Tier 1 note.
**Write surface:** R/analysis-corr-latent.R, plus a spec
```

Edits:

1. Keep everything. The derivation shape, the validation plan and the references
   are the value.
2. Add one line: it obsoleted #183, closed 2026-09-09.

**#165 — rewrite.**

Header:

```markdown
**Does:** Makes pipeline-ship dispatch one PR at a time, keeping topology analysis for ordering only.
**When:** Backlog. Trigger: the next multi-PR pipeline-ship run.
**Decision:** Locked. The four suggested edits in the body.
**Write surface:** .claude/skills/pipeline-ship/
```

Edits:

1. Keep the four numbered arguments and the four suggested edits. Both are
   specific and ready.
2. Add: the replicate-scale arc below is six sequential PRs on one switch, so it
   is the run that will test this.

---

## The PR order

The replicate-scale arc, in order. Each PR is one issue.

| PR | Issue | What lands | Breaking? |
|--:|---|---|---|
| 1 | #256 | The oracle rule and nine oracle blocks. Four go red. | no |
| 2 | ~~#242~~, #260 | JK2 scale 1 — **merged** in `d354af6`. #260 still owes the corrected rationale, at two sites. | yes |
| 3 | #253 | JKn scale 1, bootstrap 1/(R-1). | yes |
| 4 | #243 | Fay gets a required rho. PR #250's inversion retires. | yes |
| 5 | #255 | Per-type handling of a supplied scale, rscales, rho. JKn requires rscales. | yes |
| 6 | #251 | `as_survey_replicate()` refuses an fpc, per D12. | yes |

Then close #257.

PR 1 first is deliberate: it turns four open bug reports into four failing
tests, which is the state the "tested against `survey`" claim should have been in
all along. PR 2 is already written, so if PR #258 merges first, PR 1 keeps its
JK2 block and loses nothing.

PRs 2 to 5 each move published numbers. Ship them in one release with one
migration note, not four.

Everything else, in order:

1. ~~PR #259 merges (#237)~~ — merged in `6c31492`. Close #237 if the work is
   complete.
2. #245 — the wrong point estimate. Tier 1.
3. #248 Part 1, then Part 2's decision, then #234.
4. #246, all three families.
5. Backlog, by the trigger in each issue: #199, #200, #235, #218, #180, #167,
   #182, #165.

Parallel-safe with the replicate arc, because they share no file: #245 (after
#259), #235, #218, #234. Avoid #167 while PR #259 is open, and avoid appending to
`plans/error-messages.md` from two branches at once — PRs 4, 5 and 6 all write
it, as do #199 and #246.

---

## What this changes in `plans/cran-resubmission-triage.md`

That file stays. It answers "what blocks CRAN", which this file does not. Four
corrections:

1. Its #242 section says the fix is "never pushed, no PR". PR #258 is open.
2. Its #237 section says "in flight on `JDenn0514/as_svydesign-fix`". The work is
   on `fix/as-svydesign-bridge`, as PR #259.
3. Its #243 section offers the `rho` decision as open. D6 locks it.
4. Its #251 section calls the issue "the documentation half of the fix that
   shipped in PR #249". Per D12 the argument is inert and gets refused, so the
   issue is a breaking API change rather than a doc pass. It stays tier 2 — no
   number moves — but its scope grows to five files, and PR #249's warning and
   two print branches come out with it.
