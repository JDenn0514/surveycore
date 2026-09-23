# Test-spec — replicate-oracle-tests

**Date**: 2026-09-16
**Under test**: the delivered `tests/testthat/test-variance-replicate.R` and the
delivered `.claude/rules/testing-surveycore.md`.

## Errata applied after SPEC_READY

This document froze at SPEC_READY. Plan review pass 1 found seven places where
`spec.md` states a requirement and this document carried no row for it, or
carried a row weaker than the requirement. The user approved each amendment.
`spec.md` is the source of truth and is unchanged.

| # | Location | Amendment | Authority | What the gap would have cost |
|---|---|---|---|---|
| 1 | §6 second table, new row 6.18 | Added: the section carries the oracle-rule heading, after the both-modes rule section and before the S7 error testing layers section. | `spec.md` §III.1 | The section could have landed in the wrong place, or under a different heading, and every §6 row would still pass. |
| 2 | §6 first table, new row 6.19 | Added: the rule says never assert one side's stored scale against the other side's, and assert each against a literal. | `spec.md` §III.2, the first of the three further constraints | The shipped prose could have dropped the bullet. The code-behaviour version is row 2.6; the rule text version had no row. |
| 3 | §6 first table, new row 6.20 | Added: the rule carries rule 4's confidence-bound precondition, including the clause that binds a later PR which moves to design-based degrees of freedom. | `spec.md` §III.2, the precondition paragraph | A later PR could move the degrees of freedom, turn every bound assertion red at once, and leave a reader with no note saying why. |
| 4 | §2, new row 2.24 | Added: no block hard-codes a replicate count; every block reads `R` from the selected replicate columns. | `test-spec.md` §1's own prose, which carried no row | §1 calls a hard-coded count a defect. With no row, a tester reading only the numbered rows had no place to record it. |
| 5 | §2, new row 2.25 | Added: the JK1 block body computes no `(n_rep - 1L) / n_rep` and restates surveycore's default scale formula nowhere. | `spec.md` §V.2, the first of the three removals | The block could have kept the two lines that make it a round trip, while passing rows 2.2 and 2.5. |
| 6 | §2, row 2.18 corrected | The comment must carry all three elements `spec.md` names, not two. The third is that the comment names the standard-error and variance tolerance row. | `spec.md` §IV.3, the stored-scale comment | A later editor with no tolerance note in the comment could widen `1e-8` and leave the assertion in place. |
| 7 | §2, row 2.23 corrected | The JKn and bootstrap titles must also name issue #253. The Fay title names the refusal only; issue #243 sits in its comment. | `spec.md` §V.4 and §V.5; `spec.md` §V.9 for the Fay carve-out | A JKn or bootstrap title with no issue number passed the row. A reader meeting a pinned block had no pointer to the work that unpins it. |

Row 2.25 goes beyond the six rows the review named. It has the same shape as the
other five — a `spec.md` requirement with no row — so the user's decision covers
it. `decisions.md` records that the count went from six amendments to seven.

Three counts moved with these amendments: §6's first table now holds fifteen
points, its second table five, and §10's verdict rule cites both figures.

## What this run validates

The deliverable is test code. So the thing to judge is not "do the tests pass".
It is "would these tests fail if surveycore were wrong". A replicate oracle
block can pass for the wrong reason: if the block hands `survey::svrepdesign()`
the same scale surveycore computed, the two sides agree by construction and a
wrong surveycore default stays green. That is the defect this work removes, and
it is what §4 and §5 below measure.

Judge in this order:

1. §2 — the structural checks. Cheap, and they catch the round trip directly.
2. §3 — the behaviour checks. Run the file.
3. §4 — the sensitivity probe. Does a wrong scale move the compared number?
4. §5 — the end-to-end power proof. Does a wrong default turn a block red?
5. §6 — the rule text.
6. §8 — the profile gates.

---

## 1. Reference oracle, environment and datasets

### Oracle

| Item | Value |
|---|---|
| Oracle package | `survey` (>= 4.0 declared; 4.5 measured) |
| Design builder | `survey::svrepdesign()` |
| Estimators | `survey::svymean()`, `survey::svytotal()` |
| Uncertainty | `survey::SE()`, `stats::confint()` |
| R | 4.6.1 measured |
| testthat | 3.3.2 measured, edition 3 |

### Datasets

| Dataset | Purpose |
|---|---|
| The package's synthetic generator, `make_survey_data()` | Every block. No real dataset is needed or expected. |

Replicate-count facts the checks below rely on. The generator returns
`n_psu / 2` replicate columns for the `brr` and `fay` modes, and `n_psu`
columns for `jk1`, `jk2`, `jkn` and `bootstrap`. On the common fixture of 200
rows, 20 primary sampling units and 4 strata:

| Generator mode | Replicate columns |
|---|---|
| `brr`, `fay` | 10 |
| `jk1`, `jk2`, `jkn`, `bootstrap` | 20 |

A block that hard-codes a replicate count is a defect. Every block must read the
count from the selected columns.

---

## 2. Structural checks

Run these against the delivered `tests/testthat/test-variance-replicate.R`. Each
row is pass or fail on its own.

| Row | Check | Expected |
|---|---|---|
| 2.1 | All nine replicate types have at least one oracle block: BRR, JK1, JK2, JKn, bootstrap, ACS, successive-difference, other, Fay. | 9 of 9 |
| 2.2 | No `survey::svrepdesign()` call in the file receives a `scale` argument. | 0 hits |
| 2.3 | Exactly one `survey::svrepdesign()` call receives an `rscales` argument, in the JKn block. | 1 hit |
| 2.4 | The JKn block passes the identical literal `rscales` to both sides, written out twice. Neither copy is read off a design. | pass |
| 2.5 | `suppressWarnings(` does not appear anywhere in the file. | 0 hits |
| 2.6 | No block passes a value read off one design into the other, and no block asserts one side's stored scale against the other side's stored scale. | pass |
| 2.7 | Every block that builds a `survey` design asserts a condition: a message fragment where `survey` raises one, or the absence of a warning where it does not. | pass |
| 2.8 | The skip guard for `survey` sits inside each block that calls `survey`, never at file level. Grep `skip_if_not_installed("survey")`: every hit sits inside a `test_that()` body, and the hit count equals the count of blocks that call `survey`. | pass |
| 2.9 | The JKn and bootstrap blocks each carry exactly three `testthat::expect_failure()` wrappers, each holding exactly one assertion. | 3 and 3 |
| 2.10 | The point-estimate assertion in the JKn and bootstrap blocks sits outside every wrapper. | pass |
| 2.11 | The design-building call and its condition assertion in the JKn and bootstrap blocks sit outside every wrapper. | pass |
| 2.12 | The Fay block carries a comment naming issue #243, and that comment says the refusal half guards `survey`'s behaviour and that a failure there most likely means `survey` changed. | pass |
| 2.13 | `git diff --name-only` against the merge base lists exactly two files: `tests/testthat/test-variance-replicate.R` and `.claude/rules/testing-surveycore.md`. | 2 files |
| 2.14 | Both files pass `air format --check`. | pass |
| 2.15 | The JKn and bootstrap blocks each carry one **unwrapped** assertion comparing the two standard errors as a ratio against the literal `sqrt((R - 1) / R)`. See §3.6. | 1 and 1 |
| 2.16 | The comment in each pinned block names issue #253 and states that PR 3 deletes **four** lines: the three wrappers and the ratio assertion. A comment that says three is a defect. | pass |
| 2.17 | The three blocks that match a warning message — JK1, JK2, `other` — each also assert that the design-building call raises exactly one warning. | 3 of 3 |
| 2.18 | Every assertion of `survey`'s stored scale carries a one-line comment above it, and that comment says all three things: the assertion guards `survey`'s own default; a failure there means `survey` changed and not that surveycore regressed; and the tolerance is the standard-error and variance row, so a later editor does not widen it. One comment per numerical block. A comment carrying two of the three is a defect. | 13 of 13, each with all three elements |
| 2.19 | `test_invariants(` appears exactly once in the file, inside the block titled `get_means() replicate SE matches survey::svymean() — BRR design`. | 1 hit |
| 2.20 | No shared helper builds both sides. Each block builds its own fixture, its own surveycore design and its own `survey` design, in its own body. A new file-level or `helper-*.R` function that returns both designs is a defect. | pass |
| 2.21 | The four new blocks sit under one new `# Block 24:` section header at the end of the file, in the order JKn, bootstrap, `other`, Fay. No existing `# Block N:` header is renumbered. | pass |
| 2.22 | The four new blocks estimate the mean of `y1`: `get_means()` on the surveycore side, `survey::svymean(~y1, ...)` on the `survey` side. | 4 of 4 |
| 2.23 | The titles of the JKn, bootstrap and Fay blocks claim no match with `survey`. Each names the disagreement or the refusal. The JKn title and the bootstrap title also name issue #253. The Fay title names the refusal; issue #243 sits in the Fay comment and the row asks for no issue number in that title. A title of the form "X matches Y" on any of the three is a defect — it asserts the opposite of what the block proves. | 3 of 3 claim no match; 2 of 2 name #253 |
| 2.24 | No block hard-codes a replicate count. Every block reads `R` from the replicate columns it selected. §1 gives the counts each generator mode returns, and a mode change moves them. | pass |
| 2.25 | The JK1 block body contains no line that computes `(n_rep - 1L) / n_rep`, and no other restatement of surveycore's own default scale formula. The formula stays allowed inside the stored-scale assertion, which reads `(R - 1) / R` against `survey`'s value. See row 6.16: the same formula is banned as an argument and required as an assertion literal. | 0 lines that compute the scale; the assertion literal is not a hit |

Two notes on row 2.2. Search inside each `test_that()` block that calls
`svrepdesign()`. Two pre-existing `scale =` hits elsewhere in the file belong to
blocks that call an internal variance routine directly and build no `survey`
design at all. Those two are outside the rule and must stay.

One note on row 2.3. One other `rscales =` hit in the file belongs to a block
that compares two surveycore constructors and uses no oracle. It must stay
unchanged.

---

## 3. Behaviour checks — per block

Run the file. Every row below states what the block must assert and what the
measured answer is.

### 3.1 The per-type table

`R` is the replicate count the block reads from its selected columns.

| Row | Type | Fixture mode | `R` | `rscales` supplied | `survey` condition the block must assert | `survey` stored scale | Point, SE, CI agree? |
|---|---|---|--:|---|---|---|---|
| 3.1.1 | BRR | `brr` | 10, and 5 in the `mse = FALSE` block, which builds on 10 primary sampling units | no | none — the block asserts no warning fires | `1 / R` | yes |
| 3.1.2 | JK1 | `jk1` | 20 | no | a warning containing `guessing n=number of replicates` | `(R - 1) / R` | yes |
| 3.1.3 | JK2 | `jk1` | 20 | no | a warning containing `with type JK2 scale= and rscales= are not needed` | `1` | yes |
| 3.1.4 | JKn | `jkn` | 20 | **yes**, one per replicate, all `1`, to both sides | none — the block asserts no warning fires | `1` | **no** — pinned |
| 3.1.5 | bootstrap | `bootstrap` | 20 | no | none — the block asserts no warning fires | `1 / (R - 1)` | **no** — pinned |
| 3.1.6 | ACS | `brr` | 10 | no | none — the block asserts no warning fires | `4 / R` | yes |
| 3.1.7 | successive-difference | `brr` | 10 | no | none — the block asserts no warning fires | `4 / R` | yes |
| 3.1.8 | other | `jk1` | 20 | no | a warning containing `scale or rscales not specified, set to 1` | `1` | yes |
| 3.1.9 | Fay | `fay` | 10 | no | an error containing `With type='Fay' you must supply the correct rho` | not applicable | no comparison — see 3.3 |

### 3.2 What each numerical block asserts

**The table in §3.1 is one row per type, not one row per block.** Four types
carry more than one block. The 13 numerical oracle blocks are:

| Type | Blocks | Which |
|---|--:|---|
| BRR | 4 | three at `mse = TRUE`, one at `mse = FALSE` |
| JK1 | 1 | rewritten |
| JK2 | 1 | rewritten |
| JKn | 1 | new, pinned |
| bootstrap | 1 | new, pinned |
| ACS | 2 | one mean, one total |
| successive-difference | 2 | one mean, one total |
| other | 1 | new |

Fay is the fourteenth block and is not numerical — see §3.3. Ten of the 13
assert that no warning fires: the four BRR, the two ACS, the two
successive-difference, JKn and bootstrap. Three match a message fragment: JK1,
JK2 and `other`.

Rows 3.1.1 to 3.1.8 each assert five quantities:

1. the point estimate against `survey`'s coefficient;
2. the standard error against `survey`'s standard error;
3. the lower confidence bound against `survey`'s;
4. the upper confidence bound against `survey`'s;
5. `survey`'s stored scale against the literal in the table, written as a
   formula in `R`, never against the surveycore design's stored scale.

A block missing any of the five is a defect. A block that asserts only the point
estimate is the worst case: the scale enters the variance only, so the point
estimate agrees exactly even when the scale is wrong. That is measured — see
§4.

**Assertion 5 takes the standard-error and variance tolerance**, `1e-8`. The
stored scale multiplies the variance, so it belongs to that row and not to the
point-estimate row. A block using `1e-10` there is a defect.

**Assertion 5 carries a comment.** One line above it, saying that the assertion
guards `survey`'s own default and that a failure there means `survey` changed,
not that surveycore regressed. Row 2.18 counts the comments. The reason: the
assertion answers a different question from the other four. The other four fail
when surveycore is wrong. This one fails when the oracle moved.

**Warning counts.** Rows 3.1.2, 3.1.3 and 3.1.8 match a message fragment. Each
of those three blocks must also assert that the design-building call raises
exactly one warning. A fragment match alone passes when the expected warning
fires alongside a second, unexpected one — including "Data do not look like
combined weights", which means the fixture moved. The ten blocks that assert no
warning already carry that guard, because zero is a count. Row 2.17 checks the
three.

### 3.3 The Fay block

It compares nothing. `survey` refuses `type = "Fay"` without a `rho` before it
builds anything, and surveycore has no `rho` argument today. The block asserts
two things:

- `survey::svrepdesign()` with `type = "Fay"` and no `rho` raises an error whose
  message contains `With type='Fay' you must supply the correct rho`;
- the surveycore constructor accepts the same columns with `type = "Fay"` and
  nothing else supplied, and stores `scale = 1 / R`. At `R = 10` that is `0.1`.

### 3.4 The two pinned blocks

JKn and bootstrap disagree with `survey` today. Both disagree by the same
factor, `sqrt((R-1)/R)`, because both differ from `survey` by a pure scale
ratio. Measured on the fixture at `R = 20`:

| Type | surveycore SE | `survey` SE | ratio | relative gap |
|---|--:|--:|--:|--:|
| JKn | `0.240186788963527` | `0.2464264459334` | `0.974679434480991` | `-2.532057%` |
| bootstrap | `0.0551026284560812` | `0.0565341039389252` | `0.974679434480991` | `-2.532057%` |

The gap is 2.53%. The standard error tolerance is `1e-8`, so the gap is about
six orders of magnitude above it and the wrapped assertions fail reliably.

The wrapper mechanics, measured on testthat 3.3.2 at edition 3. Check the
delivered blocks against all four:

| Mechanic | Measured |
|---|---|
| One wrapper holding one failing assertion | passes |
| One wrapper holding three failing assertions | **fails** |
| Three separate wrappers, one failing assertion each | passes |
| One wrapper holding zero assertions | **fails** |

So each pinned block needs three wrappers, one each round the standard error,
the lower bound and the upper bound. The point estimate agrees exactly, so a
wrapper round it would itself fail — it stays bare. An R warning raised inside a
wrapper escapes it, so the design-building call and its condition assertion stay
outside. A tolerance composes inside a wrapper, so the wrapped assertions carry
the same tolerances as everything else.

### 3.5 Run result

| Row | Check | Expected |
|---|---|---|
| 3.5.1 | The file runs with `survey` installed. | 0 failures, 0 skips |
| 3.5.2 | Block count in the file. | 28 (24 before, plus the four new blocks). A different count needs a stated reason. |
| 3.5.3 | Oracle blocks, one or more per type, nine types covered. | 9 of 9 |
| 3.5.4 | The file runs with `survey` absent. | every block that calls `survey` skips; nothing fails |
| 3.5.5 | New warnings in the file's own run. | none. One block, the correlation block for a domain with fewer than two paired observations, carries one warning. It is pre-existing and touches no oracle block. Do not BLOCK on it. |
| 3.5.6 | A no-warning assertion fails in a block that passes on the base branch. | Should not happen. If it does, the fixture moved, not the assertion. `survey` warns "Data do not look like combined weights" when the replicate weights are not combined weights. Measured at one seed, the two conditions of that check fail by a wide margin: the mean replicate weight is about 11.9 against a threshold of 5, and the weight ratio is about 0.99 against a threshold of 5. Report the seed and the warning text in full. |

---

### 3.6 The ratio assertion in each pinned block — required

**A wrapper cannot say why it failed.** `expect_failure()` passes on exactly one
failure and zero successes, and it never reads the failure. So three wrappers
prove only "the two sides differ". A builder who compares the wrong pair of
values, or misnames a column, produces a failing assertion, a passing wrapper
and a green suite. A different regression landing before the defect is fixed
does the same. Nothing in the wrapper shape ties the failure to the known scale
defect.

Each pinned block therefore carries one further assertion, **outside every
wrapper**:

| Item | Value |
|---|---|
| What it compares | the ratio of the two standard errors, surveycore's over `survey`'s |
| Against | the literal `sqrt((R - 1) / R)`, with `R` read from the selected columns |
| Wrapped? | **no** — it passes today and must stay bare |
| Tolerance | the standard-error and variance row, `1e-8` |
| Measured at `R = 20` | `0.974679434480991` against `sqrt(19/20) = 0.974679434480896` |

The two figures agree to thirteen significant figures, far inside `1e-8`, so the
assertion passes today. It turns red the moment the surveycore default changes,
which is what makes it the attributability guard.

Check each pinned block against all four rows:

| Row | Check | Expected |
|---|---|---|
| 3.6.1 | The ratio assertion is present in the JKn block and in the bootstrap block. | 1 and 1 |
| 3.6.2 | Neither sits inside an `expect_failure()` wrapper. | pass |
| 3.6.3 | Each compares against the literal `sqrt((R - 1) / R)`, not against a value read off either design. | pass |
| 3.6.4 | Each uses the standard-error and variance tolerance, `1e-8`. | pass |

**Three wrappers and no ratio assertion is a BLOCK.** The wrappers alone leave
the block unattributable, which is the defect this row exists to catch.

### 3.7 The pinned-block comment

Each pinned block carries a comment that:

- names issue #253;
- states that PR 3 of the arc deletes **four** lines — the three wrapper lines
  and the ratio assertion.

A comment that says three lines is a defect. A later builder who deletes three
and leaves the ratio assertion behind ships a block that fails against the
corrected default.

## 4. Sensitivity probe — does a wrong scale move the number?

This probe needs no change to the package. Run it in a scratch script.

For each of the eight numerical types, build the surveycore design the way the
block does, then overwrite the design's stored scale with a value that is wrong
by a factor of two, then recompute the mean with its standard error.

| Row | Quantity | Expected |
|---|---|---|
| 4.1 | The point estimate before and after the overwrite | identical — the difference is `0` |
| 4.2 | The standard error before and after | differs by a factor of `sqrt(2)`, far above `1e-8` |
| 4.3 | Both confidence bounds before and after | differ, far above `1e-6` |

All eight types must behave this way. If the point estimate moves, the probe was
built wrong. If a standard error does not move, that type's block cannot detect
a wrong default and the delivery is a BLOCK.

The point of the probe: it is the arithmetic reason §2.2 matters. The point
estimate is blind to the scale. Only the standard error and the bounds see it.

---

## 5. End-to-end power proof — does a wrong default turn a block red?

One check, on one type, run once. It is the only step that proves the delivered
file does what it exists to do.

1. Record the clean state: `git status` reports no modified file.
2. In the package source, find the value the replicate constructor stores as the
   default scale for `type = "JK1"`. It is `(R-1)/R` today. Change it to `1`.
3. Run `tests/testthat/test-variance-replicate.R` only.
4. Revert the change. Confirm `git status` reports no modified source file.
5. Run the file again.

| Row | Check | Expected |
|---|---|---|
| 5.1 | The JK1 block after step 2 | fails, on the standard error and on both confidence bounds |
| 5.2 | The JK1 block's point-estimate assertion after step 2 | still passes — it is blind to the scale |
| 5.3 | Every other block after step 2 | unchanged |
| 5.4 | The JK1 block after step 4 | passes again |
| 5.5 | The working tree after step 4 | no modified source file |

If step 3 leaves the JK1 block green, the block is still a round trip and the
delivery is a BLOCK. Say so in the audit, and name the line in the block that
feeds the constructor's own number back into `survey`.

Do not run this on JKn or bootstrap. Those two are pinned at a wrong value on
purpose, so the sign of the check inverts there and reading it is a trap.

---

## 6. The rule text

The delivered `.claude/rules/testing-surveycore.md` carries one new section on
oracle tests. §6 checks it in two tables, twenty rows in total. The first table
holds the **fifteen points the rule must state**. The second holds **five
further checks** on the section: its heading and position, the Quick Reference
row, the per-type table, what the section must not record, and the conversion
file it must leave alone.

Check that the section states each of the fifteen points in the first table, and
that it passes each of the five checks in the second. The wording is the
author's; the content is not.

| Row | The rule must say |
|---|---|
| 6.1 | Both sides are built from the same data, the same weight column, the same replicate columns, the same type and the same `mse`, with `mse` passed explicitly. |
| 6.2 | No block passes `scale` to either side, because `survey` honours a supplied scale for four types and the comparison then cannot disagree. |
| 6.3 | `rscales` goes to JKn only, as the same literal on both sides, never read off the surveycore design. |
| 6.4 | Assert the standard error, not the point estimate alone, because the scale enters the variance only. |
| 6.5 | Assert the condition `survey` raises; do not silence it. |
| 6.6 | Match `survey`'s conditions by message text, because every condition it raises is untyped. The missing `class =` is a property of `survey` and breaches neither of the two house rules that could be read to require one: the code-style rule governs surveycore's own `cli_abort()` and `cli_warn()` calls, and the testing-standards Assertions row governs surveycore's own typed conditions. Both must be named. |
| 6.7 | The rule covers the replicate constructor. It does not cover the non-probability constructor, because `survey` has no non-probability design class. |
| 6.11 | **Which rules reach which design.** Three of the five rules — same inputs, assert the standard error, assert the condition — hold for every oracle test against `survey`, whatever the design class. The `scale` rule, the `rscales` rule and the per-type table name `svrepdesign()` arguments, so they reach replicate designs only. An author writing a Taylor or two-phase oracle must be able to read the rule and know which parts bind. |
| 6.12 | **The conversion carve-out.** The rule governs tests that prove surveycore's variance correct by an independent comparison. It does not govern a round-trip test, which asks whether `as_svydesign()` carried the design's own scale across. The rule names the two such blocks in `tests/testthat/test-conversion.R` — `as_svydesign(survey_replicate) gives svymean matching survey::svrepdesign [numerical]` and `from_svydesign() + as_svydesign() replicate round-trip agrees [numerical]` — and says both are correct and stay. Without this, a maintainer enforcing the `scale` rule has grounds to break two working tests. |
| 6.13 | **The per-type table is a snapshot of `survey` 4.5.** Before writing a new block, build a probe design on the installed version and read back what it does with a supplied `scale` and `rscales`. |
| 6.14 | **Check the `survey` version before calling a red block a surveycore regression.** A changed default on the oracle side produces the same red as a surveycore defect. |
| 6.15 | **The two sanctioned exceptions**, named with the issues that close them: the JKn and bootstrap blocks that wrap failing assertions (issue #253), and the Fay block that compares nothing (issue #243). A maintainer must be able to tell a sanctioned exception from a violation. |
| 6.16 | **A formula forbidden as an argument is still allowed as an assertion literal.** Passing `(R-1)/R` into `svrepdesign()` sets the number the other side computes with; writing it in an assertion states what the block claims. JK1 is the worked case. |
| 6.19 | **Never assert one side's stored scale against the other side's.** Assert each against a literal. An assertion that compares the two sides to each other is the same round trip in a different shape. Row 2.6 checks the blocks for this behaviour; this row checks that the rule text says it. |
| 6.20 | **Rule 4's confidence-bound clause carries a precondition.** Both sides must build the interval from the same distribution and the same degrees of freedom. Both use the normal approximation today: `survey`'s `confint()` methods for `svrepstat` and `svystat` default to `df = Inf`, and surveycore's replicate path uses infinite degrees of freedom unconditionally. A later PR that moves the replicate path to design-based degrees of freedom must revisit `tests/testthat/test-variance-replicate.R` in the same PR, because every confidence-bound assertion fails at once when it lands, and the failure reads as a scale defect unless the reader knows this clause. |

| Row | Check | Expected |
|---|---|---|
| 6.8 | The file's Quick Reference table carries a row for the oracle rule, and that row says the `scale` and `rscales` rules apply to `svrepdesign()` only. | present |
| 6.9 | The section carries the per-type table of what `survey` does with a supplied `scale` and `rscales`. | present, and it matches the table in §7 below |
| 6.10 | The section records no exact expectation total and no run time. | none — the file forbids them, per issue #215 |
| 6.17 | The two conversion blocks row 6.12 names are unchanged on disk. `git diff` lists no change to `tests/testthat/test-conversion.R`. | 0 changes |
| 6.18 | The section is headed "The oracle rule — never hand `survey` a number surveycore computed", and it sits after the both-modes rule section and before the S7 error testing layers section. | present, in that position |

---

## 7. Reference table — `survey` 4.5, measured

Use this to judge §3.1 and §6.9. Every figure was measured by building a probe
design at `R = 20` and reading the stored values back.

| Type | Default scale | A supplied `scale` | A supplied `rscales` | Condition on a bare call |
|---|---|---|---|---|
| BRR | `1/R` | warn, discard | honoured | none |
| Fay | `1/(R * (1 - rho)^2)` | discard, no warning | honoured | refuses without `rho` |
| JK1 | `(R-1)/R`, guessed | honoured | honoured | warns that it guessed |
| JK2 | `1` | warn, discard | warn, discard | warns, unconditionally |
| JKn | `1` | honoured | required, honoured | refuses without `rscales` |
| bootstrap | `1/(R-1)` | honoured | honoured | none |
| ACS | `4/R` | warn, discard | warn, discard | none when `mse` is explicit |
| successive-difference | `4/R` | warn, discard | warn, discard | none |
| other | `1` | honoured | honoured | warns that both are unset |

Three cautions when you read a message.

- **No condition carries a useful class.** Twelve warning branches and two
  refusals were measured. Every warning came back `simpleWarning`, every refusal
  `simpleError`. A class assertion would also match the "Data do not look like
  combined weights" warning, which means the fixture is broken rather than that
  the comparison held. Do not BLOCK a block for asserting the text in place of a
  class; the text is the only thing that names the branch.
- **The JK1 warning text contains `(n-1)/n`.** Those parentheses read as a
  regular-expression group. A block that matches the full text may match nothing
  at all. The fragment in §3.1 carries no metacharacter.
- **`survey` hard-codes the name JK1 in one warning.** A `rho` supplied for JK2,
  JKn, ACS or successive-difference raises `rho not relevant to JK1 design:
  ignored.`. No block supplies a `rho`, so the branch is unreachable today, but a
  fragment keyed on the string `JK1` alone would match four non-JK1 types.

---

## 8. Tolerances

| Quantity | Tolerance |
|---|---|
| Point estimates (mean, total, proportion) | `1e-10` |
| Standard error and variance | `1e-8` |
| Confidence bounds | `1e-6` |

These are the package's standing tolerances. Check that every assertion in every
oracle block uses the value for its quantity, including the three wrapped
assertions in each pinned block.

Two assertions are not point estimates, standard errors or bounds. Both take the
standard-error and variance row, `1e-8`, because both are about the variance:

| Assertion | Row | Value |
|---|---|---|
| `survey`'s stored scale against a literal (§3.2 item 5) | standard error and variance | `1e-8` |
| The standard-error ratio against `sqrt((R - 1) / R)` (§3.6) | standard error and variance | `1e-8` |

A block that puts either on the point-estimate row is a defect. The stored scale
multiplies the variance and never touches the point estimate.

**Deviations allowed: none.** A block that widens a tolerance is a BLOCK, and
so is a block that omits one. Two measured margins say no deviation is needed:

- the six agreeing types sit at a relative difference near `1e-13`, five orders
  below the standard error tolerance;
- the two pinned types sit at 2.53%, six orders above it.

### The confidence-bound tolerance has a premise

The `1e-6` bound tolerance holds only while both packages build the interval from
the same distribution and the same degrees of freedom. Both use the normal
approximation today. `survey`'s `confint()` methods for `svrepstat` and
`svystat` default to `df = Inf`, and the critical value comes from `qt()` at that
df, which equals the normal one. surveycore's replicate path uses infinite
degrees of freedom too, unconditionally.

**Read a bound failure against this premise before you read it as a scale
defect.** The two failures look alike and have different causes:

| What you see | What it means |
|---|---|
| The standard error fails and both bounds fail | A scale defect. The bounds inherit the error. |
| The standard error passes and both bounds fail | The degrees-of-freedom premise broke. The scale is intact. |

Measured on a JK1 design at `R = 20`: switching the bound to the design-based
degrees of freedom, 19, moves each bound by `0.032`. Against a `1e-6` tolerance
that is about four orders of magnitude, and the standard error does not move at
all. If you see that shape, report it as a premise break and name the change that
moved the degrees of freedom. Do not widen the tolerance.

---

## 9. Profile gates

- [ ] `devtools::document()` clean
- [ ] `devtools::test()` all pass
- [ ] `devtools::run_examples()` all pass
- [ ] `R CMD check --as-cran` (0 err, 0 warn, notes reviewed)
- [ ] `pkgdown::build_site()` clean
- [ ] `covr::package_coverage()` >= 95% (target 98%)
- [ ] CRAN cookbook scan clean

Gate notes. State each in the audit rather than blocking on it.

1. **Nothing under `R/` changes**, and no roxygen changes. So `document()`,
   `run_examples()` and `pkgdown` are expected to produce no diff and no new
   error. A diff from any of the three means the write surface leaked.
2. **Coverage is expected flat or slightly up.** This PR adds test code and no
   source lines. Measure with `NOT_CRAN=true`; `covr` does not set the variable,
   and without it eleven files skip and the figure reads several points low. The
   95% floor is the number that matters.
3. **"0 warnings" reads as "no new warning".** The suite carries 256
   pre-existing unasserted small-cell warnings on a clean base branch. That is
   issue #167 and it is not this PR's work.
4. **Two check notes are pre-approved**: `no visible binding for global variable`
   and `checking CRAN incoming feasibility`. Any other note blocks.
5. **Use the full test run before the PR.** `devtools::test()` runs everything.
   The fast local run, `NOT_CRAN=false Rscript -e "testthat::test_local()"`,
   skips eleven files and is for the edit loop only.
6. **`air` is a command-line tool here, not an R package.** Several files
   repo-wide are already not clean, so the gate reads as "the two files this PR
   touches pass `air format --check`".

---

## 10. Verdict rules

BLOCK on any of these:

- any row of §2 fails;
- any block asserts fewer than the five quantities of §3.2;
- §4 shows a type whose standard error does not move when the stored scale
  moves;
- §5 leaves the JK1 block green with a wrong default in place;
- §5 leaves a modified source file behind;
- a tolerance is widened or omitted;
- the rule section is missing any of the fifteen points in §6's first table, or
  it fails any of the five checks in §6's second table;
- a third file appears in the diff;
- a pinned block carries three wrappers and no ratio assertion (§3.6), or the
  ratio assertion sits inside a wrapper;
- a pinned block's comment says PR 3 deletes three lines rather than four
  (§3.7);
- a block that matches a warning fragment does not also assert the warning count
  (§3.2);
- `test_invariants(` appears zero times, or more than once, in the file (row
  2.19);
- either conversion block named in row 6.12 was edited.

Do not BLOCK on:

- the pre-existing warning in the correlation block (§3.5.5);
- the 256 pre-existing small-cell warnings elsewhere in the suite;
- the two pre-approved check notes;
- the absence of `class =` on any assertion about a `survey` condition (§7);
- the JKn and bootstrap blocks failing their inner assertions. That is the
  point: the wrappers pin two known-wrong numbers, and the blocks pass as long
  as each wrapper holds exactly one failing assertion.
