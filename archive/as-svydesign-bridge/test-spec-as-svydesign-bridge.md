# Test-spec — as-svydesign-bridge

**Status**: DRAFT, methodology-locked
**Revision**: 1.3 — narrowed to issue #237, 2026-09-09.
**Date**: 2026-09-09
**Row count**: 18 numbered rows, plus 1 `test_invariants()` call.
Per section: B 10, C 2, D 2, E 4.

**The section letters keep their old values on purpose.** Sections A and F are
gone: A held the ten replicate finite-population-correction rows, and F held the
two print and summary rows. Row C-3 is gone with them. The remaining sections
keep the letters B, C, D and E, and every remaining row keeps its number, so no
row ID means anything new. Renumbering would move all eighteen IDs, and rows
B-9, B-10 and B-11 are cited by name from five other places in this document.
Two gaps stay as a record: the letters A and F, and the number B-8, which was
retired earlier and whose case is back as B-11.

Section B runs B-1 to B-7 and B-9 to B-11. Section C runs C-1 and C-2.

**Budget.** The PR budget in `artifact-schemas.md` §PR budget bounds one PR at
12 test-spec rows. This work carries **18 rows in one PR**. The original reason
for one PR is gone: it read that two issues rewrite the same dispatch chain, and
there is one issue now. The instruction stands on its own — the user instructed
one PR at the request and again when the overage was put to them. The total is
recorded here accurately and the PR is not split.

Every measured figure below carries its source, `measurements.md` R1 to R13.
Those are console runs from 2026-09-08 on this worktree.

**Two review requests for extra rows were declined.** One asked for a row on
the two-replicate-column minimum, and one for a row on the `R = 2` boundary of
the replicate route. Both reasons sit in the §Edge cases table, in the row for
a `survey_nonprob` design with exactly two replicate columns.

---

## Reference oracle

| Item | Value |
|---|---|
| Oracle package | `survey` 4.5 |
| Oracle calls | `survey::svymean()`, `survey::SE()`, `survey::weights()`, and `stats::confint()` on a `svystat` or a `svrepstat`, which dispatches to the oracle package's own method |
| R | 4.6.1 |
| srvyr | 1.3.1 |
| surveycore side | `get_means(d, y1, variance = "se")$se` |

The oracle for every numerical row is surveycore's own estimate on the source
design. That is the claim these rows buy: the converted object agrees with the
package it came from. No row needs a hand-built `survey` design, so build none.

---

## Datasets

### Unit rows

`make_survey_data(seed = N)` from `tests/testthat/helper-test-data.R`. Read the
helper for its current signature before you write a call. As of this draft it
takes `n`, `n_psu`, `n_ssu`, `n_unit`, `n_strata`, `design`, `type`,
`phase2_frac`, `with_labels` and `seed`. It generates three design shapes:
`"taylor"`, `"replicate"` and `"twophase"`.

**The helper generates no non-probability shape.** There is no
`design = "nonprob"` and no argument that produces one. Do not add one. A
non-probability design is edge-case data, so it is constructed inline in the
block that needs it, per `testing-standards.md` §Test data.

### Fixture 1 — the non-probability design, both shapes (sections B, C, D, E)

Inline. Reproduces the R3 design.

- 40 rows, seed 7.
- `cal_wt` drawn uniform on `[0.5, 2.5]`.
- Eight replicate columns `bw_1` to `bw_8`. Each `bw_i` is `cal_wt` times a
  uniform draw on `[0.9, 1.1]`.
- One outcome column `y1`.
- Replicate shape: `as_survey_nonprob(weights = cal_wt,
  repweights = all_of(bw_cols), type = "bootstrap")`.
- Plain shape: `as_survey_nonprob(weights = cal_wt)`. No `repweights`.
- Pass no `calibration` argument. Supplying one triggers the provenance checks,
  which are not what these rows test.

Both shapes carry no finite population correction. Measured (R3): the `fpc`
key is `NULL` on both, and neither shape carries an `fpctype` key at all.

This fixture was numbered Fixture 2 in revision 1.2. The two fixtures that were
numbered 1 and 4 held an FPC-bearing replicate design, and both left with the
rows that used them.

### Fixture 2 — the zero-weight non-probability design (section B)

Inline. Reinstated in revision 1.2, with a build route that works.

An earlier draft withdrew this fixture as unbuildable. That reading was wrong,
and R12 measured why: **a constructor refuses a zero weight, and a
`survey_nonprob` design accepts one written in after construction.** The
fixture is buildable. Only the earlier build route was not.

Build it in two steps:

1. Build Fixture 1's plain shape the normal way. All 40 weights are positive,
   so the constructor accepts it.
2. Read the frame back out, set one row's `cal_wt` to 0, and write the frame
   back into the design's `@data` property. The write re-runs the class
   validator, and the `survey_nonprob` validator accepts a single zero.

Why the second step works on this class and on no other:

| Class | Construct with a zero weight | Write a zero weight into `@data` |
|---|---|---|
| `survey_taylor` | blocked | blocked |
| `survey_replicate` | blocked | blocked |
| `survey_nonprob` | blocked | **accepted** |

Measured (R12) on a 40-row frame with one weight set to 0. The
`survey_nonprob` validator checks two weaker conditions than the other two: it
rejects a negative weight, and it rejects a column with no positive value at
all. A single zero passes both. The package's condition register records the
permissiveness as deliberate, so this is not a defect to route around.

Row B-11 is the only row that uses this fixture. Build the plain shape only.
R12 measured the replicate shape too, and both shapes convert with standard
errors that agree exactly, but the conversion reads no weight value on either
route, so a second row would exercise the same lines twice.

### Real datasets

None. No row here needs one. `nhanes_2017` and `acs_pums_wy` are reserved for
numerical validation against a reference implementation in a dedicated file,
and every numerical row here compares surveycore against itself on synthetic
data with a stated seed.

---

## Test files

One file. The split follows the one-to-one source-to-test mapping in
`.claude/rules/testing-surveycore.md`.

| Rows | Test file | Snapshot file |
|---|---|---|
| B, C, D, E | `tests/testthat/test-conversion.R` | `tests/testthat/_snaps/conversion.md` |

Everything below that says "the file" means
`tests/testthat/test-conversion.R`.

### `test_invariants()` — what `test-conversion.R` already covers

The rule is one call per constructor per test FILE, in the first block that
builds with that constructor. Read as it stands in
`tests/testthat/test-conversion.R`:

| Constructor | Called today in that file? |
|---|---|
| `as_survey()` | yes, at line 121, and again at lines 754 and 1157 |
| `as_survey_replicate()` | no |
| `as_survey_twophase()` | no |
| `as_survey_nonprob()` | no. The file has no non-probability block at all. |

**Add exactly one call, and no more.** It goes on the replicate-shaped nonprob
design, in the first new section B block, row B-1. This is the file's first
`as_survey_nonprob()` product — a search of the file for that constructor
returns nothing — so section B genuinely holds the first-block slot for it.

Do not repeat the call in a later block. Do not add a call for `as_survey()`,
which is covered. No surviving row builds through `as_survey_replicate()` or
`as_survey_twophase()`, so neither earns a call here.

`test_invariants()` handles a `survey_nonprob` design on its own branch. It is
defined in `tests/testthat/helper-test-data.R`; read it there.

### `skip_if_not_installed()` — what `test-conversion.R` does today

`tests/testthat/test-conversion.R` has **no** file-level `skip_on_cran()`. Its
header comment states the policy: "All blocks that exercise survey/srvyr use
`skip_if_not_installed()`."

Measured in the working tree:

- `skip_if_not_installed("survey")` appears in every `test_that()` block, as
  the first line of the block.
- `skip_if_not_installed("srvyr")` is added, on the line after, in the blocks
  that also need srvyr: the three `as_tbl_svy()` blocks, the two
  `from_tbl_svy()` blocks, and the labelled round-trip block.

Follow that. Every new block starts with `skip_if_not_installed("survey")`. The
two section C blocks add `skip_if_not_installed("srvyr")` on the next line.
Block level, inside the `test_that()` call. Never at file level.

### Snapshot files

`tests/testthat/_snaps/conversion.md` exists. It carries 84 lines in 8 blocks,
covering both conversion directions, all from the replicate-bridge work. Two
earlier revisions of this document were wrong about it: the first said the file
did not exist, the second said 41 lines. Both were true of an older base. Read
the file before writing, take the current figure from it rather than from here,
and expect it to have grown again. Rows B-4 and E-3 append and change no
existing block. Commit it.

### How to capture a warning

`expect_warning(result <- fn(...), class = "...")`, with the result taken from
the return value. Never `withCallingHandlers()`. Never `tryCatch()`.

### One warning to expect on the surveycore side

Rows B-6, B-10 and B-11 call `get_means()` on a plain-shaped nonprob design.
That call raises `surveycore_warning_nonprob_srs_fallback`, which is existing
behaviour and not the subject of any of the three rows. Capture it the same way:
`expect_warning(sc <- get_means(...), class = "surveycore_warning_nonprob_srs_fallback")`.

Rows C-2 and D-1 do not call `get_means()` and need no such capture. Row D-2
does call `get_means()`, on the rebuilt `survey_replicate` design, and the
absence of that warning is the whole row — so D-2 asserts the absence rather
than capturing the warning.

---

## Per-function test plan

### `as_svydesign()` — section B, a non-probability design

Issue #237. Fixture 1 for rows B-1 to B-10, and Fixture 2 for row B-11.

| Row | Assertion | Kind | Tolerance |
|---|---|---|---|
| **B-1** | The replicate shape returns an object inheriting `svyrep.design`, and the call raises no condition. Also holds the file's one `test_invariants()` call for `as_survey_nonprob()`. | happy path | — |
| **B-2** | The converted replicate shape keeps every replicate column. Assert `ncol(survey::weights(converted, "analysis"))` equals 8. Assert all eight names `bw_1` to `bw_8` are present in the converted design's variables. | happy path | — |
| **B-3** | The plain shape returns an object inheriting `survey.design2` and warns with class `surveycore_warning_nonprob_srs_conversion`. | warning path | — |
| **B-4** | Snapshot of the B-3 warning message. | snapshot | — |
| **B-5** | Replicate shape: `survey::SE(survey::svymean(~y1, converted))` equals `get_means(d, y1, variance = "se")$se` on the source design. Measured 0.0200827192 for both (`measurements.md` R3). | numerical | SE 1e-8 |
| **B-6** | Plain shape: the same equality. Measured 0.5630671378 for both (`measurements.md` R3). Capture the surveycore-side warning as described above. | numerical | SE 1e-8 |
| **B-7** | Neither nonprob shape raises a warning of class `surveycore_warning_replicate_fpc_dropped`. | edge case | — |
| **B-9** | Replicate shape: `confint(survey::svymean(~y1, converted))`, called with no `df` argument, matches the `ci_low` and `ci_high` of `get_means(d, y1, variance = "ci")` on the source design. Build B-5's fixture again in this block and convert it again. | numerical | CI 1e-6 |
| **B-10** | Plain shape: the same equality. Build B-6's fixture again in this block and convert it again. Capture the surveycore-side warning as described above. | numerical | CI 1e-6 |
| **B-11** | Fixture 2, the plain shape with one zero-weight row: `survey::SE(survey::svymean(~y1, converted))` equals `get_means(d, y1, variance = "se")$se` on the source design. Measured 0.5296146428 for both (`measurements.md` R12). Assert the returned object inherits `survey.design2`. Capture two warnings mechanically, and assert nothing else about either: the conversion raises `surveycore_warning_nonprob_srs_conversion`, and the surveycore-side `get_means()` call raises `surveycore_warning_nonprob_srs_fallback`. | numerical + edge case | SE 1e-8 |

**Rows B-9 and B-10 build their own setup.** Each one builds the fixture and
converts it inside its own `test_that()` block. Neither shares a block with
B-5 or B-6, and neither reads an object another block left behind. The rule is
the one section D states for D-1 and D-2, and the one every existing block in
`tests/testthat/test-conversion.R` follows: **a test block owns its own setup.**

**B-7 asserts an absence, and the class it names is not this work's.**
`surveycore_warning_replicate_fpc_dropped` belongs to the replicate route, and
it now exists: the change that added it has shipped. Write the row as
`expect_no_warning(result <- as_svydesign(d), class = "surveycore_warning_replicate_fpc_dropped")`,
once per shape.

The row can fail now, which it could not when it was written. Measured (R14) on
the current base: neither nonprob shape raises the warning, because a
non-probability design carries `fpc` `NULL` in both shapes. So the row passes,
and it passes for a reason rather than for want of a class to raise.
Issue #237 raises it as worth having, and it is the only row that pins the
interaction of the two changes: a later edit that moved an FPC check out of the
replicate route and into the dispatch chain could start firing the warning on a
nonprob design, and nothing else in the suite would catch it. One expectation
per shape. Do not assert the class exists.

**B-11 is the zero-weight case, and the number B-8 stays retired.** The case
was withdrawn in an earlier revision as unbuildable, on the reading that every
constructor refuses a non-positive weight. The reading was half right, and R12
measured the other half: a constructor refuses a zero weight on all three
classes, and the `survey_nonprob` class accepts one written into `@data` after
construction. So the fixture is buildable by assignment, and Fixture 2 is back
with that build route.

The row carries the number B-11 and not B-8. Renumbering would move B-9 and
B-10, which are cited from five other places in this document, and no reader
of an earlier draft should meet a B-8 that means something new. B-8 is retired
for good.

What B-11 buys. The conversion reads no weight value, so the zero costs it
nothing: both shapes convert and the standard errors agree exactly (R12). The
row pins that. It also guards the one place a zero weight does change an
answer — the oracle package drops a zero-weight row from its Taylor degrees of
freedom, 38 where `n - 1` is 39 — by proving the standard error is unaffected
by it.

Rows B-9 and B-10 back a documented claim: a default `confint()` on the
converted object matches surveycore's own interval, because
`confint.svystat` and `confint.svrepstat` both default to `df = Inf` and
surveycore uses `Inf` for a nonprob design. Verified true on both shapes to
machine precision. The tolerance is the CI bound from
`.claude/rules/testing-surveycore.md`, 1e-6, which is four orders wider than
the observed spread. These rows assert surveycore's own behaviour and not the
oracle package's arithmetic, which is why they exist where the two
degrees-of-freedom figures get no row.

Rows B-5 and B-6 together are the assertion that proves the routing choice
preserves the estimator. B-5 shows the replicate shape keeps the replicate
variance. B-6 shows the plain shape keeps the approximation surveycore itself
uses. Measured (R3): sending the replicate shape down the plain route answers
0.5630671378 against 0.0200827192, 28 times too large on this design. The
routing key is the only thing that separates those two numbers.

Invariants: `test_invariants(d)` once, in B-1. That is the whole file's one new
call.

Input modes: not applicable. `as_svydesign()` takes a survey design object
only; there is no data-frame mode, so the both-modes rule does not reach this
function or any row below.

### `as_tbl_svy()` — section C

Fixture 1. Both blocks need srvyr.

| Row | Assertion | Kind |
|---|---|---|
| **C-1** | The replicate shape returns an object inheriting `tbl_svy`, and the call raises no condition. | happy path |
| **C-2** | The plain shape returns an object inheriting `tbl_svy` and warns with class `surveycore_warning_nonprob_srs_conversion`. | warning path |

No snapshot in this section. C-2's message is the message B-4 snapshots. One
golden copy per message.

Row C-3 is gone. It tested the propagation of the replicate FPC warning through
`as_tbl_svy()`, and that warning is not this work's.

**No numerical row in this section, and the reason.** `as_tbl_svy()` adds no
numeric logic. It converts through the same call section B exercises and then
wraps the result, so its numbers are section B's. A numerical row here would
re-assert B-5 and B-6 through one more function call and could not fail on its
own. Rows C-1 and C-2 assert what the wrapper does own: the returned class, and
the warning that reaches a caller through it. This is a stated N/A, not a gap.

### The round trip — section D

Fixture 1, replicate shape.

| Row | Assertion | Kind |
|---|---|---|
| **D-1** | `from_svydesign()` on the converted replicate-shaped nonprob design returns a probability design. Assert the returned class is `survey_replicate`. Assert it is not `survey_nonprob`. | happy path |
| **D-2** | `get_means()` on D-1's rebuilt design raises no condition of class `surveycore_warning_nonprob_srs_fallback`. | edge case |

Assert the class; do not assume it. Measured (`measurements.md` R4): the call
returns `surveycore::survey_replicate`. Test the class with
`S7::S7_inherits(result, survey_replicate)` and the negative with
`expect_false(S7::S7_inherits(result, survey_nonprob))`.

D-2 backs a documented claim: the rebuilt design reports design-based standard
errors and no longer warns about the approximation, on data that has not
changed. D-1 asserts the class change only, which is the cause. D-2 asserts the
consequence a user meets. Assert the absence with
`expect_no_warning(result <- get_means(...), class = "surveycore_warning_nonprob_srs_fallback")`,
and take the result from the return value. D-1 already builds the rebuilt
design; D-2 rebuilds it the same way in its own block, because a test block
owns its own setup.

### The refusal register — section E

| Row | Assertion | Kind |
|---|---|---|
| **E-1** | `as_svydesign()` on a plain `data.frame` errors with class `surveycore_error_not_survey_object`. | error path |
| **E-2** | `as_svydesign()` on a character string errors with class `surveycore_error_not_survey_object`. | error path |
| **E-3** | Snapshot of the E-1 error message. | snapshot |
| **E-4** | `as_svydesign()` on the replicate-shaped nonprob design raises no condition of class `surveycore_error_not_survey_object`. | edge case |

E-1 already exists as a block in the file, testing by class only. Extend that
coverage to the dual pattern: keep the `expect_error(class = ...)` row and add
the snapshot as E-3. E-2 is new: a character string is a second non-design
input, and it exercises the same guard with a different reported class name.

The message text at the four `surveycore_error_not_survey_object` sites does
not change in this work, so E-3's snapshot records the current text.

E-4 is the row that pins the fix from the refusal side: the class that used to
be refused is not refused any more.

---

## Edge cases

Every edge case of the two conversion functions gets a row above or a note here
with the reason it has none.

| Edge case | Where covered |
|---|---|
| A nonprob design whose `fpctype` key is absent | Covered by B-1 and B-5. A non-probability design carries no `fpctype` key at all (measured, R3), so both rows run the path where the key is absent. |
| A `survey_nonprob` design with an FPC | Not constructible. Both branches of the constructor set the key to `NULL` unconditionally, so no test can build one. B-7 asserts the consequence. |
| A `survey_nonprob` design with exactly two replicate columns | Not covered, and out of scope. Two is the constructor's minimum, and no code path branches on the count: the conversion passes the whole block through. B-2 asserts the count is preserved at 8, which is the same assertion at a size that can fail visibly. A review asked for a row on the two-column minimum and a second on the `R = 2` boundary of the replicate route; both were declined for this reason. The numerical rows compute their expectations from the fixture's own `R`, so they hold at any `R`. |
| Zero-weight rows | **B-11**, on a plain-shaped non-probability design. Reachable on that class only, and reachable by writing the frame back into `@data` after construction. The two probability classes block the case at construction and on assignment alike. An earlier draft recorded the case as unreachable everywhere and withdrew its row; R12 measured the reachability and the row is back. See Fixture 2 and the section B note. |
| A `select()`-narrowed design | Not covered, and out of scope for this file. A narrowed design converts with every original column present, which is the same code path B-2 already exercises. The narrowing has one writer, `surveytidy`'s `select()`, and no block in this file loads `surveytidy`. A row would add a suggested-package skip and reach no new line. |
| A zero-length replicate weight vector | Not constructible. `as_survey_replicate()` refuses a zero-column selection with `surveycore_error_repweights_empty`. `as_survey_nonprob()` refuses zero columns with the same class and one column with `surveycore_error_repweights_single`, so its minimum is two. `update_design()` refuses a `survey_nonprob` design outright with `surveycore_error_unsupported_class`, so no later call can empty the key either. No test can build the case. |
| A non-probability design's calibration provenance and reference sample | Not covered, deliberately. Both fields are dropped on the way out, so a row would assert an absence in the converted object. The converted object is an oracle-package object with no field for either one, so the absence is a property of that package's structure and not of surveycore's behaviour. Row D-1 already asserts the surveycore-side consequence: the rebuilt design is a probability design. |
| A domain-marked (filtered) design | Not covered, deliberately. The converted object answers for the full stored sample and not for the active domain, so the point estimate differs from the domain estimate. Issue #245 carries the fix. A test written now would lock in the present behaviour and would then have to be rewritten by the fix, so write no row. |
| Empty input, zero rows | Not covered, and out of scope. Every constructor refuses a zero-row frame at construction, with the error class `surveycore_error_empty_data`. No class validator re-checks the row count, so a later write into `@data` runs no row-count check. Measured (R13): that write is accepted on `survey_taylor`, and on `survey_nonprob` it is blocked for an unrelated reason — a zero-row weight column holds no positive value, so the all-zero-weight condition fires. This change adds no guard. Issue #248 holds the root cause. See the note below this table. |
| Single-row input | Not covered, and out of scope. `as_survey()` refuses a one-row frame at construction, with the error class `surveycore_error_single_row`. Measured (R13): a one-row write into `@data` is accepted on `survey_taylor` and on `survey_nonprob` alike, and the resulting design then fails conversion with the oracle package's own bare message, `Design has only one primary sampling unit`, carrying no surveycore class. This change adds no guard. Issue #248 holds the root cause. |
| All-NA outcome column | Not covered, and out of scope. `as_svydesign()` reads no outcome column. It passes the data whole and writes no value. |
| Single-level grouping | Not covered, and out of scope. `as_svydesign()` has no grouping argument and reads no group state. |
| Degenerate strata, one PSU per stratum | Not reachable on the path this change touches. A nonprob design holds strata `NULL` in both shapes. |
| A `survey_collection` input | Not covered, and out of scope. It is refused today by the same guard E-1 and E-2 exercise, and this change does not alter that. |

**A note on the two "not constructible" rows above.** Both were written as
"not constructible" in an earlier revision. That wording is too strong, and
revision 1.2 softened it. R12 measured one instance of the reason: a class
validator can be weaker than the constructor that feeds it, and writing a frame
into `@data` after construction runs only the validator. Row B-11 exists
because that route is real for a zero weight.

Both cases are now measured, and they do not behave alike. R13 holds the table:

| Frame written into `@data` after construction | `survey_taylor` | `survey_nonprob` |
|---|---|---|
| one row | accepted | accepted |
| zero rows | accepted | blocked, for an unrelated reason |
| one zero weight | blocked | accepted |

No class validator on any class repeats the row-count guard, so the row count
is checked at construction only (measured, R13). The single block in the
zero-row nonprob cell is incidental: a zero-row weight column has no positive
value, so the all-zero condition fires there rather than a row-count check.

A one-row design that reaches the conversion fails with the oracle package's own
bare message. Nothing here asks for a guard in the conversion, because a design
in this state is malformed before the conversion sees it. Issue #248 carries the
fix, in the validators. Do not restore the "not constructible" wording for
either case.

## Out of scope for this test-spec

- **The replicate finite population correction.** Write no row for it. It ships
  in a separate change on the replicate route, with its own test rows and its
  own warning class. The ten rows of the old section A, the two rows of the old
  section F and the old row C-3 all left with it. B-7 is the one surviving row
  that names the class, and it asserts an absence; see the section B note.
- **`combined.weights`.** Write no row asserting its behaviour. Issue #198 puts
  it out of scope and assigns it to `JDenn0514/surveywts#101`. Recorded here as
  a future row, because it reaches the nonprob replicate route too: the
  conversion passes no `combined.weights`, so the oracle package defaults it to
  `TRUE`, and a producer that hands over replication factors rather than
  finished weights gets a standard error that measures 0.279983 against the
  correct 0.428678 (`measurements.md` M3). That belongs to the producer
  package's suite, not to this one.
- **The degrees-of-freedom values.** No row asserts 39, or 7, or the 6 that a
  design with one duplicated replicate column reads (R9), or the 38 that a
  design with one zero-weight row reads (R12). No code in this change reads or
  writes a `degf` value. All four figures are documentation, and a test would
  pin the oracle package's own arithmetic rather than surveycore's behaviour.
  Rows B-9 and B-10 do assert a confidence interval, and that is a different
  thing: a default `confint()` uses `df = Inf` on both sides, so those two rows
  never touch the oracle's `degf()`. Row B-11 asserts a standard error on the
  zero-weight fixture and not its degrees of freedom, for the same reason.
- **The reverse-direction functions**, beyond rows D-1 and D-2.
  `from_svydesign()` and `from_tbl_svy()` do not change.
- **The dropped domain restriction.** Write no row. Issue #245 carries the fix,
  and a row written now would assert the behaviour the fix removes.

---

## Tolerances

| Estimand | Tolerance |
|---|---|
| Point estimates | 1e-10 |
| SE and variance | 1e-8 |
| CI bounds | 1e-6 |

Deviations: none.

No deviation is needed. Rows B-5, B-6 and B-11 compare the same estimator on
both sides of the conversion, so both sides carry the same arithmetic. Measured
(R3): 0.0200827192 on the replicate shape and 0.5630671378 on the plain shape,
agreeing to every digit printed on both sides. R12's two figures for the
zero-weight fixture, 0.5296146428 and 0.2422736303, agree to every digit
printed as well. All of that sits well inside the 1e-8 bound.

Rows B-9 and B-10 assert confidence-interval bounds, so they take the CI
tolerance, 1e-6. The two intervals were verified equal to machine precision on
both nonprob shapes, which is far inside that bound. Both sides use the normal
quantile, because a default `confint()` on a `svystat` or a `svrepstat` uses
`df = Inf` and surveycore uses `Inf` for a nonprob design.

Use `expect_equal()` for every numeric assertion and `expect_identical()` for
class names, column names and counts.

---

## Profile gates

- [ ] devtools::document() clean
- [ ] devtools::test() all pass
- [ ] devtools::run_examples() all pass
- [ ] R CMD check --as-cran (0 err, 0 warn, notes reviewed)
- [ ] pkgdown::build_site() clean
- [ ] covr::package_coverage() ≥ 95% (target 98%)
- [ ] CRAN cookbook scan clean (see r-package-profile.md)

Measure coverage with `NOT_CRAN=true`. `covr` does not set the variable, and
without it 11 files skip and the figure reads several points below the true
one.

For the edit-and-run loop use
`NOT_CRAN=false Rscript -e "testthat::test_local()"`. It skips the 11 slow
files. Before any push, run the full suite with
`Rscript -e "devtools::test()"`. `devtools::test()` cannot reach the fast
speed: it sets `NOT_CRAN = "true"` unconditionally.
