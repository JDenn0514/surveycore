# Spec — replicate-oracle-tests

**Status**: SPEC_READY
**Target version**: 1.1.0.9000 (no version bump — no source file changes)
**PR range**: PR 1 (PR 1 of the replicate-scale arc, issue #257)
**Date**: 2026-09-16

## Document purpose

This document is the source of truth for the work. It states the contract each
oracle block must satisfy and the wording of the new oracle rule. The
deliverable is test code and one rule section. Nothing under `R/` changes.

A note on shape. This spec fixes what each block builds, which arguments it may
pass, which quantities it compares and which condition it expects. It does not
fix assertion function names or tolerance values. Tolerances come from
`.claude/rules/testing-surveycore.md` §Variance estimation numerical tolerances;
this spec names the row that applies and never the number. One exception is
marked in §IV.3: the decision log names `testthat::expect_failure()` by name, so
this spec names it too.

Block titles are the builder's, with one constraint. Three blocks prove a
disagreement or a refusal, so their titles must not claim a match. §V.4, §V.5
and §V.9 state it for each.

---

## I. Scope

### In

| Item | Detail |
|---|---|
| Nine oracle blocks | One per replicate type in `tests/testthat/test-variance-replicate.R` |
| Rule compliance | Every `survey::svrepdesign()` call in that file obeys the oracle rule |
| The oracle rule | One new section in `.claude/rules/testing-surveycore.md` |

### Out

- No change to any file under `R/`. This PR fixes no default value.
- No change to `man/`, `NAMESPACE`, `DESCRIPTION`, `NEWS.md`, `changelog/`.
- No change to `plans/error-messages.md`. This PR adds no condition class.
- No change to any other test file.

### Out of scope, recorded for later PRs

| Item | Owner |
|---|---|
| JKn default scale `1`, bootstrap default `1/(R-1)` | issue #253, PR 3 |
| A required `rho` for `type = "Fay"` | issue #243, PR 4 |
| Per-type handling of a supplied `scale`, `rscales`, `rho` | issue #255, PR 5 |
| The replicate `fpc` refusal | issue #251, PR 6 |
| The export route that passes the stored scale into `svrepdesign()` | issue #255, PR 5. `plans/issue-cleanup.md` D10 cites line 166 of the conversion source; the site has moved to line 494. Correct D10 in that PR, not this one. |

### Design support matrix

`survey::svrepdesign()` accepts nine replicate types. All nine get a block.
`as_survey_nonprob()` is out of oracle scope: `survey` has no non-probability
design class, so it cannot be an oracle for one (`plans/issue-cleanup.md` D1).
The existing block that compares the two surveycore constructors uses no oracle,
so the rule does not reach it and it stays unchanged.

---

## II. Architecture

### Files touched

| File | Action |
|---|---|
| `tests/testthat/test-variance-replicate.R` | modified |
| `.claude/rules/testing-surveycore.md` | modified |

No other file. If the work reaches a third file, stop and report it.

### Functions added or modified

None. No exported function, no internal helper, no class.

### The write surface inside the test file

| Site | Action |
|---|---|
| The four BRR oracle blocks | Add the no-warning assertion and the stored-scale assertion of §IV.3 |
| The JK1 oracle block | Rewrite whole (§V.2) |
| The JK2 oracle block | Rewrite whole (§V.3) |
| The two successive-difference oracle blocks | Add the no-warning assertion and the stored-scale assertion of §IV.3 |
| The two ACS oracle blocks | Add the no-warning assertion and the stored-scale assertion of §IV.3 |
| The first block in the file that builds a design | Add one `test_invariants()` call (§IV.4) |
| New JKn block | Add (§V.4) |
| New bootstrap block | Add (§V.5) |
| New `other` block | Add (§V.8) |
| New Fay block | Add (§V.9) |
| Every other block in the file | Unchanged |

**Where the four new blocks go.** The file marks its sections with
`# Block N:` comment headers. Add one new header at the end of the file, after
the last existing block, reading `# Block 24: Oracle blocks for the remaining
replicate types`. Put all four new blocks under it, in this order: JKn,
bootstrap, `other`, Fay. Do not interleave them with the existing sections and
do not renumber an existing header.

---

## III. The oracle rule

### III.1 Where it goes

One new section in `.claude/rules/testing-surveycore.md`, placed after
§The both-modes rule and before §S7 error testing layers. Add one row to the
Quick Reference table at the top of that file:

| Decision | Choice |
|---|---|
| Oracle tests against `survey` | Never hand `survey` a number surveycore computed; assert the SE. Rules 2 and 3 and the per-type table apply to `svrepdesign()` only |

### III.2 The wording

Use this text. Keep the heading and the five numbered rules. Adjust nothing but
formatting.

> ## The oracle rule — never hand `survey` a number surveycore computed
>
> An oracle test compares a surveycore result against `survey`. It proves
> something only when the two sides reach their numbers independently. Five
> rules follow.
>
> **Which rules reach which design.** Rules 1, 4 and 5 hold for every oracle
> test against `survey`, whatever the design class. Rules 2 and 3 and the
> per-type table below name arguments of `survey::svrepdesign()`, so they reach
> replicate designs only. An author writing a Taylor or two-phase oracle applies
> rules 1, 4 and 5 and reads rules 2 and 3 as the principle behind them: pass
> the other side no number this side computed.
>
> 1. **Build both sides from the same inputs.** Same data frame, same weight
>    column, same replicate columns, same `type`, same `mse`. Pass `mse`
>    explicitly to both sides.
> 2. **Pass `scale` to neither side.** `survey::svrepdesign()` honours a
>    supplied `scale` for JK1, JKn, bootstrap and `other`, so a block that
>    passes surveycore's default in gets the same number back out. The
>    comparison then cannot disagree, and a wrong default stays green. This is
>    how issue #242 survived 22 releases. Read this rule with the scope
>    paragraph at the end: a round-trip test is not an oracle test, and rule 2
>    does not reach it.
> 3. **Pass `rscales` to JKn only.** `survey` refuses JKn with combined weights
>    and no `rscales`. Pass the same literal to both sides. Never read `rscales`
>    off the surveycore design. `survey` discards a supplied `rscales` for JK2,
>    ACS and successive-difference, so a block that supplies it there gets a
>    warning in place of a comparison.
> 4. **Assert the standard error, not the point estimate alone.** The scale
>    enters the variance only. A design with a wrong scale returns the same
>    point estimate, so a block that asserts the point estimate alone reports
>    green on a wrong default. Assert the confidence bounds too; they inherit
>    the error.
> 5. **Assert the condition `survey` raises. Do not silence it.** A warning from
>    `svrepdesign()` is the test telling you `survey` computed the value itself.
>    `suppressWarnings()` round an oracle call hides that.
>
> Three further constraints follow from the first five.
>
> - **Never assert one side's stored scale against the other side's.** Assert
>   each against a literal. An assertion that compares the two sides to each
>   other is the same round trip in a different shape.
> - **A formula forbidden as an argument is still allowed as an assertion
>   literal.** The two acts differ. Passing `(R-1)/R` into `svrepdesign()` sets
>   the number the other side computes with, which is the round trip. Writing
>   `(R-1)/R` in an `expect_equal()` states what the block claims the number is,
>   and the block turns red when the number moves. So the same formula may be
>   banned from a constructor call and required in an assertion in the same
>   block. JK1 is the worked case.
> - **Match `survey`'s conditions by message text, not by class.** Every
>   condition in `svrepdesign()` is a bare `warning()` or `stop()`, so the only
>   class is `simpleWarning` or `simpleError`. That class also matches the
>   "Data do not look like combined weights" warning, which means the fixture is
>   broken rather than that the comparison held. The message text names the
>   branch; the class does not. The missing `class =` here is a property of
>   `survey`, and it breaches neither house rule that could be read to require
>   one. `.claude/rules/code-style.md` governs surveycore's own
>   `cli::cli_abort()` and `cli::cli_warn()` calls; an oracle block writes none.
>   `.claude/rules/testing-standards.md` §Assertions requires `class =` on every
>   `expect_warning()`; it governs surveycore's own typed conditions, and
>   `survey` supplies no class to name.
>
> Rule 4's confidence-bound clause carries one precondition. **Both sides must
> build the interval from the same distribution and the same degrees of
> freedom.** They do today, and both use the normal approximation.
> `survey`'s `confint()` methods for `svrepstat` and `svystat` default to
> `df = Inf`, and `survey:::tconfint` takes its critical value from `qt()` at
> that df, which returns the normal one. surveycore assigns `degf <- Inf`
> unconditionally in each Phase 1 analysis file, and the replicate path reaches
> `.degf()` through none of them. Assert the bounds only while both statements
> hold. A change to degrees of freedom on either side moves every bound and
> leaves the point estimate and the standard error intact — the same shape a
> wrong scale produces, from a different cause.
>
> **The per-type table is a snapshot.** It records `survey` 4.5. Before you
> write a new block, build a probe design on your installed version and read
> back what it does with a supplied `scale` and `rscales` for your type. A later
> `survey` release can change a default or a message without changing its
> interface.
>
> **Read a failure against the `survey` version first.** When an oracle block
> turns red, check the installed `survey` version against the one the table
> records before you treat the failure as a surveycore regression. A changed
> default on the oracle side moves the target and produces the same red.
>
> ### What the rule covers
>
> The rule covers tests that prove surveycore's variance correct by an
> independent comparison against `survey`. Both sides compute their own number,
> and the test claims they agree.
>
> It does not cover a round-trip test. A round-trip test builds one design,
> converts it, and asks whether the conversion carried the design's own values
> across. `as_svydesign()` passes surveycore's stored scale into
> `svrepdesign()` by design, and that is the behaviour under test, not a defect.
> Two blocks in `tests/testthat/test-conversion.R` work this way:
>
> - `as_svydesign(survey_replicate) gives svymean matching survey::svrepdesign
>   [numerical]` — it compares a converted design against a directly built
>   `survey` design on the same fixture;
> - `from_svydesign() + as_svydesign() replicate round-trip agrees [numerical]`
>   — it starts from a `survey` design, converts it out and back, and compares
>   the two `survey` designs.
>
> Both are correct and both stay. They prove conversion fidelity. They make no
> claim about which default is right, so rule 2 does not reach them. Tell the
> two apart by the question the block asks: an oracle test asks "is surveycore's
> number right", a round-trip test asks "did the conversion carry the number
> across".
>
> It does not cover `as_survey_nonprob()`: `survey` has no non-probability
> design class, so it cannot be an oracle for one (`plans/issue-cleanup.md` D1).
>
> ### Sanctioned exceptions in `test-variance-replicate.R`
>
> Two blocks in that file break the rule's normal shape on purpose. Both close
> with a named issue. Anything else that breaks the shape is a violation.
>
> - **The JKn and bootstrap blocks wrap three failing assertions in
>   `testthat::expect_failure()`.** surveycore's stored default disagrees with
>   `survey` today, and branch protection needs a green suite. Issue #253
>   changes the two defaults and deletes the wrappers.
> - **The Fay block compares nothing.** `survey` refuses `type = "Fay"` without
>   a `rho`, and surveycore has no `rho` argument, so the block asserts the
>   refusal on one side and the stored scale on the other. Issue #243 adds the
>   argument and rewrites the block into a real comparison.

**The precondition is measured.** `measurements.md` §M7 in this run directory
records it: the two `confint()` signatures, the `tconfint` body, the identity of
`qt()` at infinite df with `qnorm()`, the six unconditional `degf <- Inf` sites
in `R/`, and a JK1 design on which `confint(m)` equals `confint(m, df = Inf)` and
differs from `confint(m, df = survey::degf(sv))`. `comprehension.md` §G12 states
the same fact.

A later PR that moves surveycore's replicate path to design-based degrees of
freedom must revisit `tests/testthat/test-variance-replicate.R` in the same PR.
Every confidence-bound assertion in the block set fails at once when it lands,
and the failure reads as a scale defect unless the reader knows this clause.

### III.3 What `survey` does with a supplied argument

Add this table under the rule. It is the evidence for rules 2 and 3, measured on
`survey` 4.5 under R 4.6.1.

| Type | Default scale | A supplied `scale` | A supplied `rscales` |
|---|---|---|---|
| BRR | `1/R` | warn, discard | honoured |
| Fay | `1/(R * (1 - rho)^2)` | discard, no warning | honoured |
| JK1 | `(R-1)/R`, guessed | honoured | honoured |
| JK2 | `1` | warn, discard | warn, discard |
| JKn | `1` | honoured | required, honoured |
| bootstrap | `1/(R-1)` | honoured | honoured |
| ACS | `4/R` | warn, discard | warn, discard |
| successive-difference | `4/R` | warn, discard | warn, discard |
| other | `1` | honoured | honoured |

---

## IV. The common block contract

**§III.2 governs; this section applies it.** The rule text in §III.2 ships into
`.claude/rules/testing-surveycore.md` and outlives this spec. §IV restates it as
a checklist for this PR's blocks and dies with this spec. Where the two
disagree, §III.2 wins, and the disagreement is a defect in §IV. A later PR that
changes the rule edits §III.2's shipped text, not this section.

Blocks 1 to 8 of §V are numerical oracle blocks. Each one satisfies every item
below. Block 9 is a refusal block and follows §V.9 instead.

**Write every block inline.** Each block builds its own fixture, its own
surveycore design and its own `survey` design, in its own body. Do not extract a
shared helper that builds both sides. The file's 24 existing blocks are already
inline, and a helper that builds both sides from one set of inputs invites the
round trip this PR removes. This is the one place where the DRY preference in
`.claude/rules/engineering-preferences.md` yields to the flat-block house style
in `.claude/rules/testing-standards.md`.

### IV.1 What the block builds

1. One fixture, from the package's synthetic generator, with the arguments the
   §V row gives. Every argument is a literal in the block.
2. The replicate column names, selected from the fixture by their common prefix.
   Read the replicate count from the selected names. Never hard-code the count:
   the generator returns `n_psu / 2` columns for the BRR and Fay modes and
   `n_psu` for the rest, so a hard-coded count breaks when the mode changes.
3. The surveycore design, from those columns, with the type string from the §V
   row and the block's `mse` value. `mse` is fixed per block: `TRUE`, unless the
   §V subsection for that block says otherwise. §V.1 does, for one of the four
   BRR blocks. Whatever the value, it is a literal in the block and it is the
   same on both sides.
4. The `survey` design, from the same weight column, the same replicate columns,
   the same type string, the same `mse` value and the fixture as `data`.

**The estimator in the four new blocks.** Each new block — JKn (§V.4),
bootstrap (§V.5), `other` (§V.8) and Fay (§V.9) — estimates the mean of `y1`.
The surveycore side calls `get_means()`, the `survey` side calls
`survey::svymean(~y1, ...)`. This follows the file's precedent: every existing
oracle block uses `y1`. The existing blocks keep whichever estimator they
already use; three of them compare totals, and this PR does not change that.

### IV.2 Which arguments the block may pass

| Argument | To surveycore | To `survey` |
|---|---|---|
| `scale` | never | never |
| `rscales` | JKn block only, one literal | JKn block only, the same literal |
| `rho` | never | never |
| `combined.weights` | not applicable | never — the default `TRUE` is the mode surveycore uses |
| `mse` | always, explicitly | always, explicitly, the same value |

The block passes no value it read off either design into the other. It reads no
property of the surveycore design and passes it to `survey`.

### IV.3 What the block asserts

Every numerical block asserts all five:

1. The point estimate, against `survey`'s coefficient.
2. The standard error, against `survey`'s standard error.
3. The lower confidence bound, against `survey`'s.
4. The upper confidence bound, against `survey`'s.
5. `survey`'s stored scale, against the literal in the §V row. This pins the
   oracle side, so a later `survey` release that changes a default turns the
   block red instead of moving the target. Write the literal as the formula the
   §V row gives, in terms of the replicate count read at step IV.1.2. Do not
   assert it against the surveycore design's stored scale.

**The stored-scale assertion takes the standard-error and variance tolerance
row.** The stored scale multiplies the variance, so it belongs to that row and
not to the point-estimate row. Read the value from
`.claude/rules/testing-surveycore.md` §Variance estimation numerical tolerances.

**The stored-scale assertion carries a comment.** One line, above the
assertion, saying that it guards `survey`'s own default and that a failure here
means `survey` changed, not that surveycore regressed. Without the comment a
reader meets a red line in a surveycore test file and reads it as a surveycore
defect. The comment also names the standard-error and variance tolerance row, so
a later editor does not widen it.

Tolerances come from `.claude/rules/testing-surveycore.md` §Variance estimation
numerical tolerances. Point estimates, standard errors and confidence bounds
each take the value listed there. Do not invent a tolerance.

**The condition.** Each block asserts the condition `survey` raises when the
design is built, by a fragment of the message text. The §V row gives the
fragment. Where the §V row says the call is silent, the block asserts that the
call raises no warning. That assertion is not decoration: `survey` warns "Data
do not look like combined weights" when the fixture's replicate weights are not
combined weights, and only an explicit no-warning assertion catches that.

**A block that expects a warning also asserts the warning count.** Three blocks
match a message fragment: JK1 (§V.2), JK2 (§V.3) and `other` (§V.8). A fragment
match passes when the expected warning fires alongside a second, unexpected one
— including the "Data do not look like combined weights" warning that means the
fixture moved. So each of the three asserts that the design-building call raises
exactly one warning, as well as matching the fragment. The ten silent blocks
already carry that guard, because "no warning" is a count of zero.

**The missing `class =` breaches no house rule.** Two rule files could be read
as requiring one. `.claude/rules/code-style.md` requires `class =` on every
`cli::cli_abort()` and `cli::cli_warn()` surveycore writes; these conditions are
`survey`'s. `.claude/rules/testing-standards.md` §Assertions requires
`class =` on every `expect_warning()`; that row governs surveycore's own typed
conditions, and `survey` supplies none to match. Both are reconciled in §VI. A
reviewer who files the missing `class =` as a defect should read §VI first.

**The pinned blocks.** Two types disagree with `survey` today, by 2.53% on the
standard error, and the confidence bounds inherit the gap. Those blocks pin the
wrong numbers with `testthat::expect_failure()` so branch protection can still
merge the PR. Four measured mechanics constrain the shape:

1. One wrapper passes on exactly one failing assertion and zero passing ones. A
   wrapper holding three failing assertions fails. A wrapper holding none fails.
   So the standard error, the lower bound and the upper bound each get their own
   wrapper — three wrappers, one assertion each.
2. The point estimate agrees exactly, so it stays outside every wrapper.
3. An R warning raised inside a wrapper escapes it. The design-building call and
   its condition assertion stay outside every wrapper.
4. A tolerance composes inside a wrapper, so the wrapped assertions carry the
   same tolerances as the rest.

**Each pinned block also carries one unwrapped ratio assertion.** It compares
the two standard errors as a ratio, surveycore's over `survey`'s, against the
literal `sqrt((R - 1) / R)`, with `R` the replicate count read at step IV.1.2.
It sits outside every wrapper. It uses the standard-error and variance tolerance
row.

The ratio assertion exists because a wrapper cannot say why it failed.
`testthat::expect_failure()` passes on exactly one failure and zero successes,
and it does not read the failure. A builder who compares the wrong pair of
values, or misnames a column, produces a failing assertion, a passing wrapper
and a green suite. A different regression landing before PR 3 does the same. The
ratio assertion ties the wrapped failure to the known scale defect: it names the
exact factor by which the two sides differ, so the block proves "wrong by this
amount" and not merely "different".

The ratio is measured, not derived. surveycore stores a scale that differs from
`survey`'s by the factor `(R-1)/R` on both types, and the standard error carries
the square root of it. Measured at `R = 20`, the ratio is
`0.974679434480991` against `sqrt(19/20) = 0.974679434480896` — the two agree to
thirteen significant figures, far inside the standard-error and variance
tolerance. The assertion passes today and turns red the moment PR 3 changes
either default.

Each pinned block carries a comment naming issue #253 and stating that PR 3 of
the arc deletes **four** lines: the three wrapper lines and this ratio
assertion. The comment states the count, so a later builder does not delete
three and leave the fourth behind, where it would fail against the corrected
default.

### IV.4 Block hygiene

- The `survey` skip guard sits inside each block that calls `survey`, never at
  file level (`.claude/rules/testing-standards.md`). Quality gate 14 checks it.
- One observable behaviour per block. A block compares one estimator on one
  type.

**The invariant call is required, not permitted.** The file exercises one
constructor, `as_survey_replicate()`, and calls `test_invariants()` zero times.
`.claude/rules/testing-surveycore.md` requires one call per constructor per
file, so the file stands in breach today. This PR closes it.

Add exactly one `test_invariants(design)` call, on the surveycore design built
in the block titled
`get_means() replicate SE matches survey::svymean() — BRR design`. That is the
first block in the file and the first that builds a design. Add no second call
anywhere in the file: the house rule is one per constructor per file, and the
file exercises one constructor.

Quality gate 15 checks the count is exactly one.

---

## V. The nine blocks

Common fixture arguments, unless the row says otherwise: 200 rows, 20 primary
sampling units, 4 strata, the replicate design mode.

`R` below is the replicate count read at step IV.1.2.

### V.1 BRR — keep, add the condition assertion

| Field | Value |
|---|---|
| Origin | The existing BRR blocks. Four of them call `survey::svrepdesign()`. |
| Fixture mode / seed | Unchanged from each existing block |
| Expected `R` | 10 in three blocks; 5 in the `mse = FALSE` block, which builds on 10 primary sampling units. Read it from the columns, as §IV.1.2 says. |
| `rscales` | none |
| `survey` condition | none — assert no warning |
| `survey` stored scale | `1 / R` |
| Outcome today | The two sides agree |

Edit each of the four blocks in place: add the no-warning assertion of §IV.3 and
the stored-scale assertion of §IV.3 item 5. Change nothing else. These blocks
already pass no scale and already assert all four quantities. The first of the
four also gains the single `test_invariants()` call of §IV.4.

**One of the four keeps `mse = FALSE`.** The block titled
`get_means() replicate: mse=FALSE matches survey with mse=FALSE` builds both
sides with `mse = FALSE`. It is the only block in the file that reaches the
centred branch of the shared replicate variance expression, the branch that
subtracts the mean of the positive-scale replicate estimates. Leave its `mse`
value alone, on both sides. Flipping it to `TRUE` deletes the branch's only
test, and the flipped block still passes, because BRR's scale agrees on both
sides whatever the centring. The other three BRR blocks stay at `mse = TRUE`.

### V.2 JK1 — rewrite whole

| Field | Value |
|---|---|
| Origin | The existing JK1 block. Rewrite it; do not add a second one. |
| Fixture mode / seed | `jk1` / 15 |
| Expected `R` | 20 |
| `rscales` | none |
| `survey` condition | a warning whose message contains `guessing n=number of replicates` |
| `survey` stored scale | `(R - 1) / R` |
| Outcome today | The two sides agree, to 13 significant figures |

Three things come out and do not come back:

1. The two lines that compute `(n_rep - 1L) / n_rep` in the block body. That
   expression is surveycore's own default formula, restated.
2. The `scale =` argument on the `survey` call.
3. The `suppressWarnings()` round the `survey` call.

`survey` has no JK1 default. With combined weights it guesses `(R-1)/R`, which
is surveycore's documented default, and warns that it guessed. So the two agree
on the value and differ on the warning, and the block expects that
(`plans/issue-cleanup.md` D9). surveycore raises no warning of its own here: a
documented default is not a guess.

Do not match on the string `JK1` alone. A supplied `rho` on four other types
raises `rho not relevant to JK1 design: ignored.`, because `survey` hard-codes
the name. No block supplies a `rho`, so that branch stays unreached, but a
fragment keyed on `JK1` would match it if a later edit reached it.

Do not use the full warning text as the match. It contains `(n-1)/n`, and the
parentheses read as a regular-expression group. The fragment in the table above
carries no metacharacter.

### V.3 JK2 — rewrite whole

| Field | Value |
|---|---|
| Origin | The existing JK2 block. Rewrite it. |
| Fixture mode / seed | `jk1` / 15 |
| Expected `R` | 20 |
| `rscales` | none |
| `survey` condition | a warning whose message contains `with type JK2 scale= and rscales= are not needed` |
| `survey` stored scale | `1` |
| Outcome today | The two sides agree. Issue #242 shipped in PR #258. |

One thing comes out: the `suppressWarnings()` round the `survey` call. The
warning it hid is unconditional — `survey` warns for JK2 even when the caller
supplied nothing — so the block asserts it.

The block keeps its assertion that the surveycore design stores `scale = 1`.
That assertion compares against a literal, not against `survey`'s value, so it
is inside the rule.

The block's existing comment explains the JK2 scale correctly. Keep it. Do not
write that JK2's per-stratum factors belong in `rscales`. They are built into the
half-sample weights, and `survey` forces `rscales` to one per replicate
(`plans/issue-cleanup.md` D3). This is hygiene, not a pointer to open work: the
wrong wording is gone from the package. Issue #260 closed on 2026-09-16 with PR
#280, commit `7800ea9`, which corrected the roxygen at
`R/core-constructors.R:602-611`, and the wrong wording now survives nowhere in
`R/`, `man/` or `tests/`. The instruction stands so this block does not
reintroduce it.

The block asserts `survey`'s warning and asserts nothing about a warning from
surveycore. surveycore is silent here by design, and `plans/issue-cleanup.md` D8
is the decision that says so.

### V.4 JKn — new block, pinned

| Field | Value |
|---|---|
| Origin | New. No JKn oracle block exists. |
| Fixture mode / seed | `jkn` / 15 |
| Expected `R` | 20 |
| `rscales` | one per replicate, all `1`, as a literal, to both sides |
| `survey` condition | none — assert no warning |
| `survey` stored scale | `1` |
| Outcome today | The two sides disagree. surveycore is low by 2.53%. |

`survey` refuses JKn with combined weights and no `rscales`, so this is the one
block that supplies the argument. Write the literal twice, once per side. Do not
write it once and reuse a value read off either design.

surveycore stores `(R-1)/R` where `survey` stores `1`, so the standard error
ratio is `sqrt((R-1)/R)`. Measured at `R = 20`: `0.240186788963527` against
`0.2464264459334`. The gap is about six orders of magnitude above the standard
error tolerance, so the wrapped assertions fail reliably.

surveycore does not refuse a JKn design with no `rscales` today, and this PR
does not add the refusal. Issue #255 does, as PR 5.

Shape: one bare point-estimate assertion, one bare stored-scale assertion, one
bare ratio assertion, three wrappers, one comment naming issue #253 and the four
lines PR 3 deletes. See §IV.3.

The ratio assertion compares surveycore's standard error over `survey`'s against
`sqrt((R - 1) / R)`, on the standard-error and variance tolerance row. Measured
at `R = 20`: `0.974679434480991` against `0.974679434480896`.

**Title.** The block disagrees with `survey`, so the title says so. The file's
usual shape, "X matches Y", would assert the opposite of what the block proves.
Name the disagreement and name issue #253.

### V.5 bootstrap — new block, pinned

| Field | Value |
|---|---|
| Origin | New. `survey::svrepdesign(type = "bootstrap")` appears nowhere in `tests/`. |
| Fixture mode / seed | `bootstrap` / 15 |
| Expected `R` | 20 |
| `rscales` | none |
| `survey` condition | none — assert no warning |
| `survey` stored scale | `1 / (R - 1)` |
| Outcome today | The two sides disagree. surveycore is low by 2.53%. |

surveycore stores `1/R` where `survey` stores `1/(R-1)`, so the ratio is again
`sqrt((R-1)/R)`. Measured at `R = 20`: `0.0551026284560812` against
`0.0565341039389252`.

`survey`'s `bootstrap.average` argument has no surveycore equivalent. The block
does not pass it. That gap is recorded in `plans/issue-cleanup.md` D5 and is not
this PR's work.

Shape: as §V.4, including the bare ratio assertion against
`sqrt((R - 1) / R)` on the standard-error and variance tolerance row. Measured
at `R = 20`, the ratio is the same `0.974679434480991`, because both types
differ from `survey` by the same scale factor.

**Title.** As §V.4. The block disagrees, so the title names the disagreement and
issue #253. It does not claim a match.

### V.6 ACS — keep, add the condition assertion

| Field | Value |
|---|---|
| Origin | The existing ACS blocks. Two of them call `survey::svrepdesign()`. |
| Fixture mode / seed | Unchanged from each existing block |
| Expected `R` | 10 |
| `rscales` | none |
| `survey` condition | none — assert no warning |
| `survey` stored scale | `4 / R` |
| Outcome today | The two sides agree |

Edit both blocks in place: add the no-warning assertion of §IV.3 and the
stored-scale assertion of §IV.3 item 5. Change nothing else. Both blocks already
pass no scale and already assert all four quantities. This is the same pair of
additions §V.1 makes to the four BRR blocks.

Keep passing `mse` explicitly to both sides. `survey` emits a message,
`mse=TRUE assumed for type="ACS"`, only when `mse` is omitted. An explicit `mse`
silences it. The blocks are already on the silent path; keep them there. The
condition assertion covers warnings, not messages, so the message could not
reach it either way.

### V.7 successive-difference — keep, add the condition assertion

| Field | Value |
|---|---|
| Origin | The existing successive-difference blocks. Two call `survey::svrepdesign()`. |
| Fixture mode / seed | Unchanged from each existing block |
| Expected `R` | 10 |
| `rscales` | none |
| `survey` condition | none — assert no warning |
| `survey` stored scale | `4 / R` |
| Outcome today | The two sides agree |

Edit both blocks in place: add the no-warning assertion of §IV.3 and the
stored-scale assertion of §IV.3 item 5. Change nothing else. Both blocks already
pass no scale and already assert all four quantities. This is the same pair of
additions §V.1 makes to the four BRR blocks.

### V.8 other — new block

| Field | Value |
|---|---|
| Origin | New |
| Fixture mode / seed | `jk1` / 15 |
| Expected `R` | 20 |
| `rscales` | none |
| `survey` condition | a warning whose message contains `scale or rscales not specified, set to 1` |
| `survey` stored scale | `1` |
| Outcome today | The two sides agree |

The generator has no `other` mode, so the block builds `type = "other"` on the
`jk1` replicate columns, the way the JK2 block builds on them.

The block supplies neither `scale` nor `rscales`. Supplying both silences the
warning and makes `survey` honour the supplied values, which restores the round
trip this work exists to remove. Supplying one of the two leaves the warning in
place and still feeds `survey` a number. Supply neither.

The agreement is measured, not inferred. `measurements.md` §M8 in this run
directory builds both sides on this fixture at this seed and compares all four
quantities. The point estimate matches exactly. The standard error differs by
`2.4e-14`, and each bound by `5.0e-14`, every one of them orders of magnitude
inside the tolerance for its quantity. Both sides store `scale = 1`, `survey`
fills `rscales` with `1`, and the warning text is the fragment in the table
above. So this is a plain oracle block with no `expect_failure()` wrapper.

### V.9 Fay — new block, refusal only

| Field | Value |
|---|---|
| Origin | New |
| Fixture mode / seed | `fay` / 15 |
| Expected `R` | 10 |
| Shape | Not an oracle comparison |

This block compares nothing. `survey` refuses `type = "Fay"` without a `rho`
before it builds anything, and surveycore has no `rho` argument today, so no
comparison is possible. The block pins both halves of the gap:

1. `survey::svrepdesign()` on the fixture, with `type = "Fay"` and no `rho`,
   raises an error whose message contains
   `With type='Fay' you must supply the correct rho`. The error is a bare
   `stop()`, so it carries no class but `simpleError`. Match the message text.
2. `as_survey_replicate()` on the same columns, with `type = "Fay"` and nothing
   else supplied, returns a design and stores `scale = 1 / R`. That is the BRR
   scale, because surveycore has no `rho` to shrink by.

The block carries a comment. It states three things:

1. Issue #243 owns the gap, and PR 4 of the arc adds the `rho` argument and
   rewrites this block into a real oracle comparison.
2. Half of the block asserts what another package refuses to do. That half is a
   guard on `survey`'s behaviour, not on surveycore's.
3. A failure on the refusal half most likely means `survey` changed its message
   or dropped the requirement. Read it that way before reading it as a
   surveycore regression.

**Title.** The block compares nothing, so the title claims no match. It names
the refusal. The house rule already requires a title to be a present-tense
assertion of one observable behaviour, and "matches `survey`" would be false
here.

---

## VI. Errors and warnings

This PR adds no condition class, changes no condition class and does not write
`plans/error-messages.md`.

Every condition the blocks assert belongs to `survey`. `survey` raises bare
`warning()` and `stop()` calls, so those conditions carry only `simpleWarning`
or `simpleError`. Twelve warning branches and two refusals were measured; none
carried a typed class. Each block therefore matches the message text.

This is worth recording here so a later reviewer does not file the missing
`class =` as a breach of a house rule. Two rules could be read that way, and
neither is breached.

- `.claude/rules/code-style.md` requires `class =` on every `cli::cli_abort()`
  and `cli::cli_warn()` call surveycore writes. These blocks write none. They
  match conditions another package raises.
- `.claude/rules/testing-standards.md` §Assertions requires
  `expect_warning(result <- fn(...), class = ...)`. That row is the one which
  governs the shape a builder writes here. It governs surveycore's own typed
  conditions, and `survey` supplies no class to name. The row's own example
  assumes a typed condition exists.

There is nothing to match on but the text. Decision O2 in `decisions.md` locks
that choice and records why the class `simpleWarning` is worse than the text: it
also matches the "Data do not look like combined weights" warning, which means
the fixture is broken rather than that the comparison held.

---

## VII. Edge cases

| Case | Required behaviour |
|---|---|
| A type `survey` refuses to build | Assert the refusal, compare nothing. Fay only (§V.9). |
| A type `survey` refuses without one argument | Supply the argument as a literal to both sides. JKn only (§V.4). |
| The replicate count differs by mode | Read the count from the selected columns in every block. The BRR and Fay modes give half as many columns as the rest on the same fixture. |
| The two sides disagree today | Pin each disagreeing assertion in its own wrapper, name the issue, leave the point estimate bare. JKn and bootstrap only. |
| `survey` is not installed | The block skips. The skip guard sits inside the block. |
| The fixture stops looking like combined weights | The no-warning assertion in the ten blocks where `survey` raises no warning turns red. |
| A second, unexpected warning fires alongside the expected one | The warning-count assertion in the three message-matching blocks turns red. |
| `mse` omitted on an ACS call | Cannot arise: every block passes `mse` explicitly to both sides. |
| A supplied `rho` | Cannot arise: no block passes one. |
| A zero-weight row | Cannot arise: the generator multiplies a positive stratum ratio by a lognormal factor, so every weight is positive. |
| An all-NA outcome column | Cannot arise: the generator draws `y1` from a normal distribution and writes no NA into it. |
| A single-primary-sampling-unit fixture | Cannot arise: every block fixes the primary-sampling-unit count as a literal, at 10 or 20. |

The last three rows exist so a reader does not re-derive them. They are real
survey-data edge cases and `.claude/rules/engineering-preferences.md` asks for
them. None reaches this PR, because every block builds from the fixed generator
with literal arguments and this PR adds no code path under `R/`.

**The ten blocks where `survey` raises no warning** are the four BRR blocks, the
two ACS blocks, the two successive-difference blocks, the new JKn block and the
new bootstrap block. Count blocks, not types: JK1, JK2 and `other` each raise a
warning, and Fay refuses before it builds.

---

## VIII. Quality gates

Objectively checkable. Each one holds before the PR opens.

1. All nine replicate types have at least one oracle block in
   `tests/testthat/test-variance-replicate.R`: BRR, JK1, JK2, JKn, bootstrap,
   ACS, successive-difference, other, Fay.
2. No `survey::svrepdesign()` call anywhere in that file receives a `scale`
   argument.
3. Exactly one `survey::svrepdesign()` call in that file receives an `rscales`
   argument: the JKn block. The same literal reaches the surveycore side of that
   block.
4. `suppressWarnings()` does not appear anywhere in that file.
5. No block passes a value read off one design into the other, and no block
   asserts one side's stored scale against the other side's.
6. Every block that builds a `survey` design asserts a condition: a message
   fragment where `survey` raises one, or the absence of a warning where it does
   not. The three blocks that match a fragment — JK1, JK2, `other` — also assert
   that the call raises exactly one warning.
7. Every numerical oracle block asserts the point estimate, the standard error,
   both confidence bounds and `survey`'s stored scale. Each stored-scale
   assertion carries the comment §IV.3 requires.
8. The JKn and bootstrap blocks each carry exactly three
   `testthat::expect_failure()` wrappers, one assertion in each; one unwrapped
   ratio assertion of `sc_se / sv_se` against `sqrt((R - 1) / R)`; and a comment
   naming issue #253 and the four lines PR 3 deletes. A block with three
   wrappers and no ratio assertion fails this gate.
9. The Fay block carries a comment naming issue #243 and stating that the
   refusal half guards `survey`'s behaviour.
10. `.claude/rules/testing-surveycore.md` carries the §III.2 rule section and the
    §III.3 table, plus the Quick Reference row. The rule section carries all of:
    the split between the general rules and the `svrepdesign()`-specific ones;
    the conversion carve-out naming the two `tests/testthat/test-conversion.R`
    blocks; the snapshot sentence about the installed `survey` version; the
    sentence telling a maintainer to check that version before reading a red
    block as a surveycore regression; the two sanctioned exceptions with issues
    #253 and #243; and the argument-versus-literal bullet.
11. The full test suite passes. No new failure, no new skip.
12. `git diff --name-only` against the merge base lists exactly two files.
13. Both files pass `air format --check`.
14. `skip_if_not_installed("survey")` appears inside every block that calls
    `survey`, and never at file level. Grep the file: the count of that call
    equals the count of blocks that call `survey`, and no such call sits outside
    a `test_that()` body.
15. `test_invariants(` appears exactly once in the file, inside the block
    §IV.4 names.
16. The file holds 28 `test_that()` blocks: the 24 it holds today, plus the four
    §V.4, §V.5, §V.8 and §V.9 add. A different count means a block was dropped
    or duplicated.
17. The titles of the JKn, bootstrap and Fay blocks claim no match with
    `survey`. Each names the disagreement or the refusal.
18. `tests/testthat/test-conversion.R` is unchanged. The carve-out in the rule
    names two of its blocks and this PR edits neither.

---

## IX. Errata against issue #256

Issue #256 is the source of the work. Seven of its statements are stale or
cannot be followed as written. The measured evidence is in `comprehension.md`
and `measurements.md` in this run directory, sections M0 to M8.

| # | What #256 says | What the measurement shows | This spec |
|---|---|---|---|
| 1 | Four blocks go red: JK2, JKn, bootstrap, Fay. | JK2 agrees. PR #258 shipped `JK2 = 1`. The scale ratio is `1.0000000000001` (M3), and the file ran 24 blocks with 0 failures (M5). | Only JKn and bootstrap are pinned. JK2 is a plain oracle block. |
| 2 | "Several blocks" pass surveycore's own scale into `svrepdesign()`. | Exactly one does — the JK1 block. Two other `scale =` hits in the file are direct calls to the internal variance helper and reach no `svrepdesign()`. | One block loses its `scale` argument. |
| 3 | Assert each warning "by class". | No typed class exists. Every condition in `svrepdesign()` is a bare `warning()` or `stop()` (M1). | Assert the message text. §VI records why. Locked by decision O2. |
| 4 | ACS emits "a message, that it assumed `mse = TRUE`". | It does, and only when `mse` is omitted (M2). Every block passes `mse` explicitly, which silences it. | No block asserts the ACS message. §V.6. |
| 5 | Eight blocks can be written; Fay cannot. | Correct on the comparison. `survey` refuses Fay without a `rho` (M1). | A ninth block asserts the refusal, so the file keeps the nine-row shape and pins the reason. Locked by decision O5. |
| 6 | Each block asserts the point estimate, the SE and both CI bounds. | Correct in coverage, wrong in shape for the two pinned blocks. One wrapper holding three failing assertions fails (M4). | Three separate wrappers per pinned block. Locked by decision O3. |
| 7 | The export route passes the stored scale at line 166 of the conversion source. | The site is line 494 (M6). | Out of scope. Correct the line number in PR 5. |

Four additions this spec makes that #256 does not ask for, all cheap and all
inside the two-file surface:

- **The no-warning assertion** in the ten blocks where `survey` raises no
  warning — the four BRR blocks, the two ACS blocks, the two
  successive-difference blocks, the new JKn block and the new bootstrap block.
  `survey` warns when the replicate weights do not look like combined weights.
  Measured at one seed on four replicate modes (M2), the two conditions of that
  heuristic fail by a wide margin: the mean replicate weight is about 11.9
  against a threshold of 5, and the weight ratio is about 0.99 against a
  threshold of 5. So the warning does not fire today. Nothing enforces that, and
  a class-based assertion would not catch it if the generator changed. An
  explicit no-warning assertion does. If the assertion fires on a block that
  passes today, report the seed and the warning text: the fixture, not the
  assertion, is the thing that moved.
- **The stored-scale assertion** against a literal, in every numerical block. It
  pins the oracle side, so a `survey` release that changes a default turns the
  block red rather than moving the target. Each one carries a comment saying so,
  because otherwise a red line in a surveycore test file reads as a surveycore
  defect.
- **The ratio assertion** in the two pinned blocks. `testthat::expect_failure()`
  passes on any one failure and does not read it, so the wrappers alone prove
  only "the two sides differ". The ratio assertion names the factor, so the
  blocks prove "wrong by this amount" and PR 3 turns them red when it lands.
  §IV.3 holds the mechanics.
- **The `test_invariants()` call**, one, in the first block. The file exercises
  `as_survey_replicate()` and calls the helper zero times, which breaches
  `.claude/rules/testing-surveycore.md`. The file is open; the fix is one line.

---

## X. Pipeline tier

**recommended.**

The letter of the optional test is met: no new exported function, no numerical
method change, no contract change, two files. The recommendation is still
`recommended`, for one reason. The deliverable is the oracle itself. A test that
passes for the wrong reason is exactly the defect this work removes, and a
builder who mis-reads one row of the per-type table produces a block that is
green and worthless — which is the state the file has been in since the first
release. An independent tester run is the only step that proves each block goes
red when it should. Dropping that step to save a stage would reproduce the
failure the work exists to fix.
