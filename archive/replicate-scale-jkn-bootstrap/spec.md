# Spec — replicate-scale-jkn-bootstrap

**Status**: DRAFT
**Target version**: 1.1.0.9000
**PR range**: PR 1–1 (one PR expected; the implementation plan fixes the map)
**Date**: 2026-09-23

## Document purpose

This document is the source of truth for the change. It states the two
default values that move, the documentation that must state them, the test
files that hold the old values, and the behaviour at every edge of the input
space. A builder implements from this document alone.

`decisions.md` D-1 in this run directory is SETTLED by the user and binds
§Edge cases E1. Decisions D1, D2 and D5 in `plans/issue-cleanup.md` are
locked and settle the two target values. Do not re-argue any of the four.

---

## Scope

### In

| Item | Surface |
|---|---|
| JKn default `scale` moves to `1` | `R/core-constructors.R:807` |
| bootstrap default `scale` moves to `1 / (R - 1)` | `R/core-constructors.R:813` |
| `@param scale` records eight facts (§Documentation) | `R/core-constructors.R` roxygen |
| `@param rscales` gains one cross-reference clause (§Documentation) | `R/core-constructors.R` roxygen |
| `@param fpc` gains one clause on having no effect (§Documentation) | `R/core-constructors.R` roxygen |
| One divergence note on `as_survey_nonprob()` | `R/core-constructors.R` roxygen |
| Two regenerated help pages | `man/` |
| Stored-default assertions | `tests/testthat/test-constructors.R` |
| Eight deleted lines in two oracle blocks | `tests/testthat/test-variance-replicate.R` |
| One migration note and one changelog entry | `NEWS.md`, `changelog/` |

Two of the nine replicate types change. The other seven keep the value they
hold today. §Default scale table states all nine.

### Out

| Item | Why it is out | Owner |
|---|---|---|
| Refuse `type = "JKn"` with `rscales = NULL` | `survey` refuses this input and surveycore does not. Argument handling ships as one piece. | issue #255 |
| Refuse a single replicate column for any type | `decisions.md` D-1 chose to match `survey`, which accepts it. | a new issue, not yet filed |
| A `rho` argument for `type = "Fay"` | The Fay block compares nothing until the argument exists. | issue #243 |
| Refuse `fpc` on a replicate design | Locked as D12; an accepted argument becomes an error, which is its own breaking change. | issue #251 |
| A `bootstrap.average` argument | No surveycore equivalent exists; D5 keeps it out and asks only for the note. An imported `survey` design keeps its effective scale exactly, so what is missing is the argument and not the number — `measurements.md` M4. | not filed |
| `as_survey_nonprob()`'s own `scale` switch at `R/utils.R:1184` | D1: `survey` has no non-probability design class, so it is not an oracle for one. `bootstrap = 1 / R` stays. | — |
| Degrees of freedom on the replicate path | Every confidence bound on both sides rests on the normal approximation. Moving `degf` moves every bound. | not filed |
| The `mse` default | For the jackknife, both centrings sit in Wolter's set of four and share one second-order expectation, so the JKn default `scale` is decidable without settling `mse`. That citation reaches the jackknife only. §Why `1` is right for JKn records what it does not reach on the bootstrap. | — |
| A domain restriction that empties a stratum | A JKn design's per-stratum `rscales` can then stop matching the strata realised in the domain's replicate deviations. The behaviour is pre-existing and this work does not touch it: `rscales` storage, the variance engine, `filter()` and `subset()` are all outside the write surface. | not filed |
| A negative explicit `scale` on `as_survey_replicate()` | `as_survey_nonprob()` raises `surveycore_error_scale_negative` for a negative `scale`. `as_survey_replicate()` stores the value verbatim, because its scale block has one `if (is.null(scale))` branch and no `else`. A caller who passes `scale = -1` gets a negative variance multiplier and no condition. The asymmetry is pre-existing. This work edits two lines inside the `is.null(scale)` branch and adds no branch, so it neither creates nor widens the gap. | not filed |

`.claude/rules/testing-surveycore.md` §Sanctioned exceptions names two
exceptions. This work clears one of the two — the `expect_failure()`
wrappers in the JKn and bootstrap oracle blocks. The other is the Fay block,
which compares nothing, and issue #243 owns it. Do not claim this work
clears both.

`plans/issue-cleanup.md` contradicts itself about the arc's PR order: its
summary table calls #255 PR 4, and #255's own header says it ships after
#243. Cite the issue number and never a PR number for out-of-scope work.

### A runtime transition signal was weighed and declined

This work moves a published standard error and raises no condition while it
does so. The silence is a decision and not an oversight.

A one-time session-scoped message on the constructor was considered. It was
declined. The message would fire on every correct build of a JKn or bootstrap
design, including every build that never carried the old number, and it would
keep firing after every caller had read it. The cost falls on correct code,
and the message tells the caller nothing they can act on at the point it
fires.

The documented route is two pieces, and both ship in this work:

- the `NEWS.md` migration note, which states the two types, the two new
  values, the direction and the size of the move;
- the explicit-`scale` escape hatch of E4, which reproduces the old numbers
  exactly and which the migration note names.

A later reader who finds no condition here should read this section and not
file a defect. Reopening the question needs a new decision, not a new PR.

---

## Architecture

### Files touched

| File | Action |
|---|---|
| `R/core-constructors.R` | modified — two switch lines, two short comments, four roxygen edits |
| `man/as_survey_replicate.Rd` | regenerated by `devtools::document()` |
| `man/as_survey_nonprob.Rd` | regenerated by `devtools::document()` |
| `tests/testthat/test-constructors.R` | modified — stored-default assertions |
| `tests/testthat/test-variance-replicate.R` | modified — eight lines deleted, two titles corrected |
| `NEWS.md` | modified — one migration note |
| `changelog/fix-replicate-scale-jkn-bootstrap.md` | created |

No other file is in the write surface.

### Functions added

None.

### Functions modified

```r
as_survey_replicate(
  data,
  weights,
  repweights,
  type = c(
    "JK1", "JK2", "JKn", "BRR", "Fay", "bootstrap", "ACS",
    "successive-difference", "other"
  ),
  scale = NULL,
  rscales = NULL,
  fpc = NULL,
  fpctype = c("fraction", "correction"),
  mse = TRUE,
  calibration = NULL
)
```

The signature does not change. The value the body computes for `scale` when
the caller passes `scale = NULL` changes for two `type` values.

`as_survey_nonprob()` changes documentation only. Its signature, its body and
`.compute_nonprob_scale()` at `R/utils.R:1184` are unchanged.

### Class changes

None. `@variables$scale` keeps its type. No new property, no new validator, no
print or format change, no result class change.

**The `survey_replicate` validator performs no check on `scale`'s value on any
construction path.** Its body at `R/core-classes.R:669-753` never mentions
`scale`. It checks that the design columns exist in `@data`, that they are
atomic, that the weight column is numeric and positive, and that the replicate
weight columns are numeric. So `Inf`, a negative number and any other double
pass through untouched — through a direct `survey_replicate()` call, through
`as_survey_replicate()` and through both conversion routes. Read "the validator
is unchanged" as "the validator checks nothing here". Do not add a defensive
check: E1 requires `Inf` to reach storage.

**The `@variables` key set is unchanged.** `as_survey_replicate()` builds nine
keys at `R/core-constructors.R:822-832` — `weights`, `repweights`, `type`,
`scale`, `rscales`, `fpc`, `fpctype`, `mse` and `visible_vars`. All nine stay,
each holds what it holds today, and this work adds no key and removes none. It
changes the value of one key, `scale`, for two `type` values.

---

## Function contracts

### `as_survey_replicate()`

- **Signature**: as printed in §Functions modified. Unchanged.
- **Arguments**: unchanged. `scale = NULL` still means "compute the default
  from `type` and the replicate count". `R` below is the replicate count,
  `length(repweights_vars)`, held internally as `n_rep`.
- **Returns**: a `survey_replicate` object, unchanged in class and shape.
  `@variables$scale` holds the computed default when the caller passes
  `scale = NULL`.
- **Errors**: this work adds no error class. §Errors and warnings lists the
  five existing classes that fire before the default is computed.
- **Warnings**: this work adds no warning class. The constructor raises no
  condition at either new default, including the infinite one of E1.
- **Edge cases**: §Edge cases, E1 to E7.

#### Default scale table

All nine types. The switch runs only when the caller passes `scale = NULL`.

| `type` | Before | After | Changed |
|---|---|---|---|
| `"JK1"` | `(R - 1) / R` | `(R - 1) / R` | no |
| `"JK2"` | `1` | `1` | no |
| `"JKn"` | `(R - 1) / R` | `1` | **yes** |
| `"BRR"` | `1 / R` | `1 / R` | no |
| `"Fay"` | `1 / R` | `1 / R` | no — and still not `survey`'s value |
| `"bootstrap"` | `1 / R` | `1 / (R - 1)` | **yes** |
| `"ACS"` | `4 / R` | `4 / R` | no |
| `"successive-difference"` | `4 / R` | `4 / R` | no |
| `"other"` | `1` | `1` | no |

Two rows change. Seven do not.

One of the seven unchanged rows still diverges from `survey`. `survey`
computes `1 / (R * (1 - rho)^2)` for `"Fay"`, which equals surveycore's
`1 / R` only at `rho = 0`. surveycore has no `rho` argument, so it cannot
compute `survey`'s value. Issue #243 and decision D6 own that gap, and §Out
keeps it out of this work. The other six unchanged rows agree with `survey`
after the change.

#### The two switch lines

`R/core-constructors.R:807`

```r
JKn = 1,
```

`R/core-constructors.R:813`

```r
bootstrap = 1 / (n_rep - 1L),
```

`n_rep` is an integer, so `n_rep - 1L` is an integer and the division
returns a double. At `n_rep = 1L` the expression returns `Inf`. E1 governs
that input.

Each changed line carries a short comment in the style of the `JK2` comment at
`R/core-constructors.R:800-806`. **Each comment is a pointer and not a
derivation.** It keeps only what a reader of that line needs — which value the
line sets, and why the line is not the other candidate factor — and it sends
the reader to `@param scale` for the formula. The roxygen block is the one
shipped source of the formula.

The JKn comment states four things:

1. JKn is the stratified delete-one jackknife.
2. The per-stratum factor belongs in `rscales` and not in the overall scale.
3. `(R - 1) / R` is the factor of the *unstratified* jackknife and names
   `"JK1"` only.
4. `survey::svrepdesign()` fixes `1`, and `@param scale` carries the formula
   and its with-replacement condition.

It writes out neither `q_h` nor the without-replacement correction.

The bootstrap comment states three things:

1. `survey::svrepdesign()` computes `bootstrap.average / (R - 1)`.
2. surveycore has no `bootstrap.average` argument, so this line is always
   `1 / (R - 1)`.
3. `as_survey_nonprob()` keeps `1 / R` by decision D1, and `@param scale`
   carries the rest.

Keep every comment line inside 80 columns.

`decisions.md` D-2 asked for the with-replacement caveat in this comment as
well as on the help page. This document narrows the comment to the pointer
above. The caveat still ships, in full, as F-3 and F-7 on the help page, so
nothing a user reads is lost. One text is easier to keep right than two, and
the derivation stays in §Why `1` is right for JKn, which does not ship.

#### Why `1` is right for JKn

Wolter (2007) *Introduction to Variance Estimation*, 2nd ed., chapter 4,
gives the stratified delete-one jackknife as

```
v(theta_hat) = SUM_h (q_h / n_h)
               * SUM_i (theta_(hi) - centre)^2

q_h = (n_h - 1) * (1 - n_h / N_h)   sampling without replacement
q_h = (n_h - 1)                     sampling with replacement
```

at §4.5 eq. 4.5.3 to eq. 4.5.6. The factor `q_h / n_h` is inside the sum
over strata `h`. No form carries an overall multiplier. `n_h` is the number
of sample PSUs in stratum `h`, and `N_h` is the number of population PSUs in
stratum `h`. Both symbols count PSUs, so `n_h / N_h` is the sampling
fraction of PSUs in the stratum. The two symbols must count the same kind of
unit, because F-7 asks a caller to compute `1 - n_h / N_h` by hand. Wolter
writes `N_h` for the size of a stratum at §4.5, chapter line 1102, and
counts primary units in the population and the sample at §4.6, chapter line
1597. Read `N_h` here as the §4.6 quantity.

The simplified factor `(n_h - 1) / n_h` is `q_h / n_h` with the
finite-population term dropped. It holds for with-replacement PSU selection,
or when the sampling fraction `n_h / N_h` is negligible. Wolter states that
condition at chapter line 1416 and restates it at lines 1537 to 1551. He
writes the simplified form himself at §4.6 eq. 4.6.4a and in the worked
NLSY97 example at §4.7 Table 4.7.2, both of which treat the PSU selection as
with-replacement. Every form puts the factor inside the sum over strata,
simplified or not.

The unstratified factor `(k - 1) / k` of §4.2.1 eq. 4.2.3 and §4.3.1
eq. 4.3.5 is an overall multiplier and names `"JK1"`.

surveycore computes `V = scale * SUM_r rscales_r * (theta_r - c)^2`, so the
per-stratum factor reaches the variance through `rscales` and the overall
`scale` stays at `1`. Two facts bound the claim, and no document in this
work may state them more strongly:

1. surveycore reaches Wolter's `v_4` when `mse = TRUE` and his `v_2` when
   `mse = FALSE`. The verdict is confirmed with conditions, not confirmed. A
   correct `rscales` vector alone does not deliver either estimator. The
   replicate columns must also form a genuine
   one-replicate-per-deleted-PSU family that covers every PSU in every
   stratum, so that the double sum over strata and units and the single sum
   over replicates run over the same terms. The replicate weights must also
   carry the shape of eq. 4.6.7: inflated by `n_h / (n_h - 1)` inside the
   stratum of the deleted PSU, zero for the deleted PSU, and unchanged
   outside that stratum. Nothing in surveycore checks either condition, and
   E6 records the same limit for `rscales` itself. surveycore cannot reach
   Jones's `v_1` of eq. 4.5.3 at all, because `v_1` centres each replicate
   on the mean of its own stratum and a `survey_replicate` design records no
   map from a replicate column to a stratum. `survey` is in the same
   position.
2. The two factors coincide at one stratum and differ otherwise. The
   coincidence needs the same with-replacement condition as the simplified
   form. At `n_h = 2` and `R = 4` the two factors are 0.5 and 0.75. So the
   old default read as right on an unstratified frame, which is one reason
   it survived.

Chapter 4 of Wolter covers the jackknife only. It contains no bootstrap
estimator and no bootstrap divisor, and it supports no part of the bootstrap
change. The bootstrap target rests on D5: `survey` is the oracle for this
constructor, and `survey` computes `bootstrap.average / (R - 1)`.

The two changes do not have the same standing, and no document in this work
may present them as one kind of change. The old JKn default is the wrong
factor for every stratified design, as the paragraphs above show. The old
bootstrap default is a different legitimate divisor: `1 / R` is the
population form of the bootstrap variance divisor, and it is the value
`as_survey_nonprob()` keeps under decision D1, which cites Wu (2022) and
Chen et al. (2021). D5 picks `1 / (R - 1)` because `survey` is the oracle for
this constructor, and not because `1 / (R - 1)` is demonstrably more correct
than `1 / R`.

One objection to a single hard-coded bootstrap divisor is on the record.
A Rao-Wu rescaling bootstrap builds its replicate weights on the assumption
that the variance estimator divides by `R`, so a uniform `1 / (R - 1)`
introduces a small known bias for weights of that construction. Rao and Wu
(1988), *JASA* 83(401), 231-241 `[verify]` — no copy of the paper was
attached to this run. `survey` applies one divisor to every bootstrap
design, whatever the construction of its weights. This records the objection
and does not reopen D5.

One question about the bootstrap divisor stays open, and this work does not
settle it. `1 / (R - 1)` is the unbiased divisor of a sample variance taken
about the sample mean of the replicate estimates. surveycore defaults
`mse = TRUE`, which centres on the full-sample estimate instead, and
`survey` sets the bootstrap scale without consulting `mse`. So after this
change the `R - 1` divisor is paired with a centre that is not the replicate
mean the divisor was derived for. No source cited in this run establishes
that pairing as correct to second order, the way Wolter's Theorem 4.5.3 does
for the jackknife. The behaviour matches `survey`, so it is inherited and
not new. A bootstrap design at `mse = FALSE` gets the textbook-consistent
pairing and carries no open question.

#### Behaviour rules

1. The switch runs only when `scale` is `NULL`. An explicit `scale` is
   stored verbatim for every type, as today.
2. The stored JKn default does not depend on `R`.
3. The stored bootstrap default depends on `R` and is not finite at `R = 1`.
4. The constructor does not read, rescale or re-derive `rscales` when it
   computes the default, and it does not re-derive `scale` from `rscales`.
5. Neither change touches the variance engine. `R/variance-replicate.R` is
   outside the write surface.
6. Both changes move a published standard error upward by
   `1 / sqrt((R - 1) / R)`, because both multiply the variance by
   `R / (R - 1)`. At `R = 20` the standard error rises by 2.6%.
7. Domain estimation and grouping are unaffected. `scale` multiplies the
   variance after the domain restriction and after the grouping split, so a
   filtered design and a grouped call take the same factor as a whole-sample
   call.
8. A `survey_twophase` design over a replicate `phase1` inherits the new
   default unchanged. `as_survey_twophase()` copies `phase1@variables` into
   its own `phase1` entry at `R/core-constructors.R:1151` and recomputes no
   value in it, so a stored `scale` of `1` or `1 / (R - 1)` crosses into the
   two-phase design as it stands. A Taylor `phase1` carries no `scale` and is
   untouched. This rule records existing behaviour. The two-phase branch of
   `R/core-constructors.R` and `R/variance-twophase.R` are outside the write
   surface, and this work changes no line in either.

### `as_survey_nonprob()`

- **Signature**: unchanged.
- **Arguments**: unchanged.
- **Returns**: unchanged.
- **Errors**: unchanged. It keeps `surveycore_error_repweights_single` for a
  single replicate column and
  `surveycore_error_stratified_jk_rscales_unset` for `"JK2"` or `"JKn"` with
  `rscales = NULL`.
- **Warnings**: unchanged.
- **Edge cases**: unchanged.

Behaviour rule: `type = "bootstrap"` keeps `scale = 1 / R`. After this work
the same `type` string means a different divisor in the two constructors, by
decision D1. For `"JKn"` the two constructors converge on `1`, because
`.compute_nonprob_scale()` already returns `1`.

---

## Errors and warnings

This work adds no error class and no warning class. Every condition it
touches already has a row in `plans/error-messages.md`.

Five existing classes fire before the default `scale` is computed, so this
work cannot change which of them fires or what it says:

| Class | Trigger | Register row |
|---|---|---|
| `surveycore_error_empty_data` | `data` has 0 rows | 2 |
| `surveycore_error_repweights_empty` | `repweights` selects 0 columns | 16 |
| `surveycore_error_weights_all_zero` | every weight is zero or missing | 10 |
| `surveycore_error_rscales_length` | `length(rscales)` is not `R` | 17 |
| `surveycore_error_weights_nonpositive` | some weight is zero or negative, among positive ones | 33 |

The fifth row was added when resolving the spec review. E7 first said a
zero-weight row among positive rows reaches the stored default. It does not:
the constructor refuses that frame. The corrected fact is in E7.

If the builder concludes the work needs a new condition, stop and raise a
HOLD. Do not invent a class.

Three pieces of drift exist in the error register and its snapshots around
this work. All three are pre-existing, none is in the write surface, and none
belongs to any issue in this arc. One new issue, filed in this run, owns all
three: `#291`.

1. `plans/error-messages.md:307` writes NB-3's `"i"` bullet as "Bootstrap
   variance requires >= 2 replicates" where `R/core-constructors.R:1467` says
   "Replicate variance".
2. The class `surveycore_error_stratified_jk_rscales_unset`, which
   `as_survey_nonprob()` raises for `"JK2"` or `"JKn"` with `rscales = NULL`,
   has no row in `plans/error-messages.md` at all. It ships with snapshots.
3. No snapshot anywhere covers `as_survey_replicate()` raising
   `surveycore_error_weights_all_zero`.
   `tests/testthat/_snaps/constructors.md` carries none, and every assertion
   of that class against this constructor names the class only. The class is
   snapshotted for `as_survey()`, at
   `tests/testthat/_snaps/labelled-storage.md:11-19`, so the message text is
   on the record and only this constructor's route is missing. The
   neighbouring class `surveycore_error_weights_nonpositive` is snapshotted
   for this constructor at the same file, lines 39-48.

Record all three; fix none of them here. Item 3 would put
`tests/testthat/_snaps/` inside the write surface, and §Test-file write
surface names two files and no snapshot file.

---

## Edge cases

Seven edge cases, E1 to E7. Each states the behaviour the builder must
deliver.

**E1 — one replicate column with `type = "bootstrap"` stores `Inf`.**
`1 / (R - 1)` at `R = 1` is `1 / 0`, which R evaluates to `Inf`. The
constructor stores `Inf` and raises no condition. `survey::svrepdesign()`
stores `Inf` for the same input and signals nothing; measured on `survey`
4.5 under R 4.6.1. D5 makes `survey` the authority for this constructor, so
surveycore matches it. `decisions.md` D-1 holds the record and the rejected
alternatives. Do not add a refusal. A follow-up GitHub issue, not yet filed,
asks whether either package should refuse the input.

The infinite scale reaches the standard error, and the replicate deviation
decides what arrives there. With one replicate column the sum has one term.
Two outcomes are possible, and this work must deliver both:

- The one replicate estimate differs from the full-sample estimate. The
  deviation is not zero, so the standard error is `Inf` and both confidence
  bounds are infinite.
- The one replicate estimate equals the full-sample estimate. The deviation
  is exactly zero, so the product is `Inf * 0`, which IEEE 754 makes `NaN`.
  The standard error is `NaN` and both confidence bounds are `NaN`.

Neither outcome raises a condition. Each reaches `SE()`, the confidence
bounds and the print methods as it stands. The old default gave `1 / R = 1`
at `R = 1`, which is finite, so the infinite construction is new behaviour of
this work and not inherited. D-1 still governs the stored value: the
constructor stores `Inf` and raises nothing.

**The `NaN` comes from the infinite scale, not from the zero deviation.** The
ordinary zero-variance case is different, and this work does not change it. At
any finite scale — every `R > 1` for the bootstrap, and every `R` for JKn —
all-zero replicate deviations give `scale * 0`, which is `0`. The standard
error is then exactly `0`, and both confidence bounds equal the point
estimate. That is a degenerate design, and it is not an error state. `NaN`
arises only where an infinite scale meets a zero deviation, which is the
second outcome above and reaches one input only: one replicate column with
`type = "bootstrap"`. Do not read the two cases as one behaviour, and do not
guard either of them.

**E2 — two replicate columns with `type = "bootstrap"` store `1`.**
`1 / (2 - 1)` is `1`. The old default gave `0.5` for the same input.

At `R = 2` the new bootstrap default and the JKn default are both `1`, and
`R = 2` is the smallest replicate count at which the two changed defaults
coincide. **The coincidence is arithmetic only.** `1 / (R - 1)` equals `1` at
`R = 2`, and the JKn value is `1` at every `R` for a reason that has nothing
to do with the bootstrap. The two defaults have no relationship. No document
in this work may present the shared value as one.

**E3 — `type = "JKn"` stores `1` for every replicate count, `R = 1`
included.** The stored value does not depend on `R`, so no count is
degenerate for this type.

**E4 — an explicit `scale` is stored verbatim for both types.** The switch is
not reached. This is the route back to the pre-change numbers:
`scale = (R - 1) / R` for JKn and `scale = 1 / R` for bootstrap. The
migration note states it.

**E5 — `type = "JKn"` with `rscales = NULL` stores `scale = 1` and
`rscales = NULL`, and raises no condition.** The variance path substitutes
`rep(1L, R)` for a `NULL` `rscales`, so this input computes an unweighted sum
of squared deviations and no jackknife factor of any kind enters. Today the
same input at least carries `(R - 1) / R`, so this work makes that one input
worse. `survey` refuses the input outright, and issue #255 moves
`as_survey_replicate()` to the same refusal. State this window in the
changelog entry so a reviewer does not read it as a defect of this work.

**E6 — a non-uniform `rscales` with `type = "JKn"` is stored verbatim and
`scale` is still `1`.** The constructor neither normalises `rscales` nor
folds any part of it into `scale`. Nothing in surveycore can check that the
values look like `(n_h - 1) / n_h`; neither package stores the strata, so the
correctness of a JKn standard error rests on the caller.

**E7 — inputs that the constructor already refuses or already handles are
unchanged, because the switch runs after every validator.** A zero-row
frame, a `repweights` selection of zero columns, an all-zero weight column
and a wrong-length `rscales` each raise its class from §Errors and warnings,
exactly as today. Those are four of the five classes in that table; the fifth
is below. A single-row frame and an all-NA outcome column
each reach the same stored `scale` as any other frame, because the default
depends only on `type` and `R` and on nothing in the data. Those two frames
are ordinary inputs and not refusals: the constructor builds each one and
raises no condition.

**A zero weight among positive weights is a refusal and not an ordinary
frame.** `.validate_weights()` at `R/core-validators.R:169-186` refuses any
non-NA weight that is not strictly positive, and `as_survey_replicate()` calls
that helper at `R/core-constructors.R:783`, before the switch. The class is
`surveycore_error_weights_nonpositive`, register row 33, and it is the fifth
class in §Errors and warnings. `surveycore_error_weights_all_zero` covers a
column that is entirely zero or missing; a column that mixes zeros with
positive values takes this other class. Both are pre-existing and this work
changes neither.

A single-level grouping variable is not an input to this constructor.
`as_survey_replicate()` takes no grouping argument, so grouping cannot reach
the stored default on any path. Behaviour rule 7 states what grouping does to
the variance.

Two further properties of the existing engine are not changed here and are
recorded so no reader treats them as new. A replicate whose estimate is `NA`
is dropped together with its `rscales` entry, and `scale` is not re-derived
after the drop, so a bootstrap design with `R = 20` and five `NA` replicates
still divides by 19. A design with zero `rscales` entries and `mse = FALSE`
centres on the replicates with a positive entry only.

---

## Documentation

### `@param scale` on `as_survey_replicate()`

The block at `R/core-constructors.R:602-611` today lists JKn with JK1 at
`(R-1)/R` and bootstrap with BRR and Fay at `1/R`. Both lists are wrong after
the change. The rewritten block carries eight facts, F-1 to F-8, and every
one of them is required:

- **F-1** — the default for `"JKn"` is `1`.
- **F-2** — the default for `"bootstrap"` is `1 / (R - 1)`, which is the
  value `survey::svrepdesign()` computes at `bootstrap.average = 1`.
- **F-3** — for `"JKn"` the per-stratum factor belongs in `rscales`, and
  `rscales = NULL` means no jackknife factor enters the variance at all. The
  factor is `(n_h - 1) / n_h` for with-replacement PSU selection, or when
  the sampling fraction is negligible.
- **F-4** — a bootstrap design of one replicate column gives `scale = Inf`,
  and `survey::svrepdesign()` stores `Inf` for the same input.
- **F-5** — surveycore has no `bootstrap.average` argument, so a caller cannot
  build a design with one and this constructor's bootstrap default is always
  `1 / (R - 1)`. An imported `survey` design keeps its effective scale
  exactly, in both directions. F-5 carries two elements: the missing argument,
  and the preserved scale. Write it as a statement about the argument. What
  surveycore lacks is a way to name `bootstrap.average` separately, not a way
  to carry its effect.
- **F-6** — pass `scale` explicitly to reproduce the pre-change numbers.
- **F-7** — a caller who samples PSUs without replacement at a sampling
  fraction that is not negligible must fold `(1 - n_h / N_h)` into each
  `rscales` entry by hand, which makes the entry
  `(n_h - 1) * (1 - n_h / N_h) / n_h`. F-7 carries three elements, and all
  three ship on the help page:
  1. the corrected entry, as written above;
  2. a symbol key — `n_h` is the number of sample PSUs in stratum `h`, and
     `N_h` is the number of population PSUs in stratum `h`;
  3. one clause on provenance — the caller supplies `N_h` from their own
     frame, and `rscales` is the only route for the correction, because the
     `fpc` argument does not reach the factor for any replicate type.
- **F-8** — `as_survey_nonprob()` keeps `1 / R` for `"bootstrap"`, so the same
  `type` string means a different divisor in the two constructors. F-8 carries
  three elements: the other constructor's name, its value `1 / R`, and one
  clause saying the difference is a decision and not a defect, with a pointer
  to `as_survey_nonprob()`'s own help page for the reason and the size of the
  gap. F-8 carries no factor and no percentage of its own.

**Why F-5 reads this way.** The claim it replaces was measured false. An
imported `survey` bootstrap design keeps its effective scale bit for bit in
both directions, `bootstrap.average != 1` included, because
`from_svydesign()` stores `survey`'s own computed `scale` and
`as_svydesign()` passes that value back out. Neither route recomputes it.
`measurements.md` M4 holds the numbers and the source lines. Issue #253's
body states the wrong inference, and the correction to that issue is the
orchestrator's to post. Keep the source line numbers in this document. The
help page states the fact and cites no line.

**Why F-8 is a fact and not a `@seealso` link.** The divergence must be
discoverable from either signature. `as_survey_nonprob()` already names
`as_survey_replicate()` and its value, in the note below. F-8 is the other
half of that pair, so a reader who opens either page meets the divergence
once and learns which page holds the reason. Without F-8 the divergence
reaches only a reader who opens both pages and compares two `@param scale`
blocks. An analyst who checks one constructor against the other meets an
unexplained gap of about 2.5% and can reasonably conclude one of the two is
broken.

The symbol key is required because the roxygen block is the whole text the
reader gets. This document's justification section defines `n_h` and `N_h`,
and that section does not ship. A help page that prints the formula with no
key leaves both symbols undefined.

The provenance clause is required because surveycore stores no population
stratum size. Decision D12 refuses the `fpc` argument for replicate designs,
so the design object holds no route to `N_h` and cannot supply the number.
Keep every roxygen line of F-7 inside 80 columns, and write it as help-page
prose and not as a derivation.

F-3 and F-7 are two facts and not one. F-3 states what the factor is and
where it belongs. F-7 states what one class of caller must do about it.

The block keeps the JK2 sentences that PR #258 added. Nothing in it may claim
that surveycore estimates Jones's `v_1`, and nothing in it may cite Wolter
chapter 4 for the bootstrap divisor.

### `@param rscales` on `as_survey_replicate()`

The block at `R/core-constructors.R:612-614` states only what the argument
accepts and what length it must have. It gains one required edit:

- **RS-1** — one clause that points the reader at `@param scale` for the
  without-replacement correction. The clause names the `scale` argument and
  states that the text there gives the entry a caller must build when PSU
  selection is without replacement at a sampling fraction that is not
  negligible. The clause carries no formula and no symbol key of its own.

RS-1 is a cross-reference and not a second copy. `comprehension.md` G8 asks
for the correction itself in `@param rscales`. This document places the
correction in `@param scale` as F-7, so the builder's closed list of facts
stays in one block, and `@param rscales` carries RS-1's pointer to it. A
second copy of the formula would give the two blocks a value to drift apart
on.

### `@param fpc` on `as_survey_replicate()`

`fpc` is in the printed signature, and a finite-population correction is the
first thing an analyst looks for there. For a replicate design the argument
does nothing. The constructor accepts it, resolves it and stores the column
name in `@variables$fpc`, and no replicate variance formula reads that key.
The caller gets no error, no warning and no effect. The block gains one
required edit:

- **FP-1** — one clause stating that `fpc` has no effect for a replicate
  design, and that the without-replacement correction goes into `rscales`
  instead, with a pointer to `@param scale` for the entry a caller must
  build. The clause carries no formula and no symbol key of its own.

FP-1 changes no behaviour. Decision D12 refuses the argument for replicate
designs and issue #251 owns that refusal, which is a breaking change of its
own. This work leaves `fpc` accepted and inert, and says so on the help page.

FP-1 is the fourth roxygen edit of this work. The other three are F-1 to F-8
on `@param scale`, RS-1 on `@param rscales`, and D1's note on
`as_survey_nonprob()`.

### `as_survey_nonprob()` roxygen

The `@details` paragraph at `R/core-constructors.R:1306-1311` says the
bootstrap default `1 / R` follows Wu (2022) and Chen et al. (2021). That
citation is genuine and stays. Add D1's note. It carries four elements, and
all four are required:

- `survey`'s value for the bootstrap, `1 / (R - 1)`;
- `as_survey_replicate()` as the constructor that matches that value;
- the reason this constructor keeps `1 / R`: `survey` has no
  non-probability design class and is not an oracle for one;
- the size of the divergence. On the same frame, `as_survey_nonprob()`'s
  bootstrap standard error is smaller than `as_survey_replicate()`'s by
  `sqrt((R - 1) / R)`, which is 2.5% at `R = 20`.

Take the factor `sqrt((R - 1) / R)` from behaviour rule 6 and compute no new
factor. The percentage is direction-specific, and the two directions do not
share one number. `sqrt(19 / 20)` is 0.9746794, so the fall to the smaller
standard error is 2.5% and the rise to the larger one is 2.6%. This note
states the fall, so its figure is 2.5%. Behaviour rule 6 states the rise, so
its figure is 2.6%. Both are correct in their own direction.

Write the note as one sentence or as two. The four elements are the
requirement; the sentence count is not. The note lands in this work, so the
divergence is documented the moment it widens.

`@param type` and `@param scale` on `as_survey_nonprob()` stay true and need
no edit: nonprob's bootstrap default is still `1 / R` and its JKn default is
still `1`.

### Regenerated help pages

Run `devtools::document()`. Commit `man/as_survey_replicate.Rd` and
`man/as_survey_nonprob.Rd` in the same commit as the roxygen change. Do not
hand-edit either file.

---

## Test-file write surface

The builder edits two test files. Both edits are part of this work, and the
line numbers below are read from the current worktree.

### `tests/testthat/test-variance-replicate.R` — delete eight lines

Two blocks pin the wrong numbers on purpose. Each closes with issue #253, and
each carries a comment saying to delete four lines when this work lands. Both
comments are right. Delete four lines in each block, eight in total.

**Block 1 — the JKn oracle block, lines 806-884.** Its title says the
standard error "disagrees with" `survey::svymean()`.

- Delete the `testthat::expect_failure()` wrapper at line 865, at line 868
  and at line 871. The three assertions they hold — the standard error, the
  lower bound and the upper bound — stay and must pass unwrapped.
- Delete the closing ratio assertion at lines 879-883, together with the
  comment above it. It asserts the ratio of the two standard errors against
  `sqrt((n_rep - 1) / n_rep)`, and that ratio becomes `1` after the change.

**Block 2 — the bootstrap oracle block, lines 886-965.** Its title says the
same.

- Delete the `testthat::expect_failure()` wrapper at line 942, at line 949
  and at line 952. The same three assertions stay and must pass unwrapped.
- Delete the closing ratio assertion at lines 960-964, together with the
  comment above it.

That is the closed set: six wrapper deletions and two ratio-assertion
deletions, across the two blocks and nowhere else. Deleting only the wrappers
leaves a ratio assertion that fails against the corrected default. Deleting
anything else in either block removes a live assertion.

**The deletion and the two switch lines ship together.** An
`expect_failure()` wrapper turns red when the assertion inside it starts to
pass. So the two corrected defaults make the six wrappers fail, and the six
wrappers cannot be removed before the defaults move. Neither half of the pair
leaves the suite green on its own. Do not split them across two commits that
each have to pass on their own.

Correct each block's title and each block's opening comment in the same edit.
Both now describe a disagreement that no longer exists. A title that still
says "disagrees" after the change is a false statement about a passing block.
Do not use `grep -c` to count constructs in this file: it discusses its own
constructs in comments and titles, so a textual count reads high.

### `tests/testthat/test-constructors.R` — retarget one block

Exactly one block in the whole suite asserts a stored default that this
change breaks: the block at lines 676-692, titled
`as_survey_replicate() computes bootstrap default scale = 1/R`, which asserts
`d@variables$scale` equals `1 / n_rep`. Retarget the assertion and the title
to `1 / (n_rep - 1)`, in the same change as the switch lines and for the same
reason as the wrapper deletion: the block passes today and fails the moment
the default moves.

No block asserts the JKn default for `as_survey_replicate()` today, so the
JKn stored default needs a new block rather than an edit. The blocks at lines
3136-3147 and 3149 onward assert nonprob defaults and stay as they are.

The stored-default assertions this work needs cover both changed types, both
the old-value and the new-value side of each, the edge cases of §Edge cases,
and the cross-constructor properties of §Quality gates. Add them to this
file, beside the existing per-type blocks at lines 597-692.

`test_invariants()` already runs once for `as_survey()`, once for
`as_survey_replicate()`, once for `as_survey_twophase()` and once for
`as_survey_nonprob()` in this file, and once in
`tests/testthat/test-variance-replicate.R`. The rule is one call per
constructor per file. New blocks add no further call.

---

## NEWS and changelog

### The migration note

One note, not three. `plans/issue-cleanup.md` asks for one migration note
covering the changed defaults of the whole arc, because they ship in one
release. Three defaults have changed in the development version when this
work lands: JK2 in #242, and JKn and bootstrap here. All three rise by the
factor behaviour rule 6 gives.

`NEWS.md` already carries #242's own bug-fix entry at lines 135-146. Keep it.
Add the entry for this work under the same `## Bug fixes` heading, and write
it so a later PR appends to it rather than opening a second migration note.
The entry carries six elements:

- the two types and the two new values;
- that the change moves published numbers, with the direction and the size.
  Take the factor and the percentage from behaviour rule 6 and compute
  neither here. Behaviour rule 6 is this document's one source for both;
- that `scale = (R - 1) / R` for JKn and `scale = 1 / R` for bootstrap
  reproduce the old numbers;
- that `as_survey_nonprob()` keeps `1 / R` for the bootstrap, and why;
- the issue number, `(#253)`;
- one clause separating the two changes. The JKn move corrects a formula
  error, and it cites Wolter. The bootstrap move aligns surveycore with
  `survey`'s convention, and it does not mean an older `1 / R` number was
  wrong.

The entry stays under `## Bug fixes`. The heading is not in scope to change,
and the sixth element is what stops a user reading the bootstrap move as a
verdict on their published numbers.

Do not claim the note covers issue #243. #243 adds an argument that does not
exist yet, so no number it moves can be stated here. The note's shape must
let #243 and #251 extend it.

### The changelog entry

`changelog/fix-replicate-scale-jkn-bootstrap.md`, on the pattern of
`changelog/fix-jk2-default-scale.md`: branch, status, date, PRs, issues, a
summary with the measured before-and-after table, the changed files, and a
verification list. Record the E5 window there, and record that this work
clears one of the two sanctioned exceptions in
`.claude/rules/testing-surveycore.md` and not both.

---

## Quality gates

Observable and checkable at the end of the work.

1. `as_survey_replicate(type = "JKn")` with no `scale` stores `1`.
2. `as_survey_replicate(type = "bootstrap")` with no `scale` stores
   `1 / (R - 1)`.
3. The seven unchanged rows of §Default scale table still store the value the
   table gives.
4. A bootstrap design of one replicate column stores `Inf` and raises no
   condition. Its standard error is `Inf` when the replicate deviation is
   not zero, and `NaN` when the deviation is exactly zero.
5. `as_survey_replicate()` and `as_survey_nonprob()` store the same `scale`
   for `"JKn"` on the same frame, and return the same mean and the same
   standard error.
6. `as_survey_nonprob(type = "bootstrap")` still stores `1 / R`, so the two
   constructors diverge on the bootstrap by decision, and the divergence is
   documented on both help pages.
7. The rendered help page for `as_survey_replicate()` carries all eight facts
   F-1 to F-8. F-5 carries both of its elements, F-7 carries all three of
   its elements, and F-8 carries all three of its elements. The `rscales`
   argument on the same page carries RS-1's cross-reference to the `scale`
   argument, and the `fpc` argument on the same page carries FP-1's clause.
   Three of this work's four roxygen edits land on this page. Gate 8 covers
   the fourth.
8. The rendered help page for `as_survey_nonprob()` carries D1's note with
   all four of its elements.
9. Neither oracle block in `tests/testthat/test-variance-replicate.R` holds
   an `expect_failure()` wrapper or a ratio assertion, and both pass.
10. No new error class and no new warning class. `plans/error-messages.md` is
    outside the write surface and unchanged.
11. `devtools::document()` leaves no uncommitted change under `man/` or in
    `NAMESPACE`.
12. `R CMD check` gives 0 errors, 0 warnings and at most the pre-approved
    notes of `.claude/rules/r-package-conventions.md`.
13. Line coverage stays at or above the 95% floor of
    `.claude/rules/testing-standards.md`, measured with `NOT_CRAN=true`.
14. `air format --check` passes on the files this work touches.

---

## Pipeline tier

**recommended** — full pipeline. `impact.md` records `full-required` on four
failing smallness criteria: the write surface is 7 files against a bound of
3, `scale` multiplies the variance so numerical output moves, the user
attached Wolter chapter 4, and a default-scale correction is not a routine
pattern.
