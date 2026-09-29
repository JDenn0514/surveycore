# Test-spec — replicate-scale-jkn-bootstrap

**Status**: DRAFT
**Target version**: 1.1.0.9000
**Date**: 2026-09-23

## What this work changes, stated for the tester

`as_survey_replicate()` chooses a default variance `scale` from the replicate
`type` when the caller passes no `scale`. Two of the nine types get a new
default value:

| `type` | Old default | New default |
|---|---|---|
| `"JKn"` | `(R - 1) / R` | `1` |
| `"bootstrap"` | `1 / R` | `1 / (R - 1)` |

`R` is the number of replicate weight columns. The other seven types keep the
value they have today: `(R - 1) / R` for `"JK1"`, `1` for `"JK2"` and
`"other"`, `1 / R` for `"BRR"` and `"Fay"`, and `4 / R` for `"ACS"` and
`"successive-difference"`. Two rows change, seven do not.

`"Fay"` is one of the seven unchanged types, and it still diverges from
`survey`. `survey` computes `1 / (R * (1 - rho)^2)` for Fay, which equals
surveycore's `1 / R` only at `rho = 0`. surveycore has no `rho` argument.
Issue #243 and decision D6 own that gap. So the row that walks the nine
types asserts surveycore's own `1 / R` for Fay, and no row here compares Fay
against `survey`. The other six unchanged types agree with `survey`.

`scale` multiplies the variance, so both moves raise a standard error by
`1 / sqrt((R - 1) / R)` and leave the point estimate bit-for-bit identical.
At `R = 20` the standard error rises by 2.6%. That figure is the rise. The
fall in the other direction is 2.5%, because the two directions do not share
one number. Row 4.2 states the fall and carries the arithmetic.

`as_survey_nonprob()` keeps `1 / R` for `"bootstrap"` and `1` for `"JKn"`. It
is a documentation change only. `survey` has no non-probability design class,
so it is not an oracle for one.

No new error class and no new warning class ships with this work.

---

## Reference oracle

- `survey` 4.5 under R 4.6.1, through `survey::svrepdesign()`,
  `survey::svymean()`, `survey::SE()` and `confint()`.
- `survey` stores `1` for JKn and `bootstrap.average / (R - 1)` for the
  bootstrap. surveycore has no `bootstrap.average` argument, so the two sides
  agree only at `survey`'s default of `1`.
- **Probe the installed version before writing a block.** The per-type
  `scale` and `rscales` table in `.claude/rules/testing-surveycore.md` is a
  snapshot of `survey` 4.5. Build a throwaway design on the installed version
  and read back what it does with a supplied `scale` and a supplied `rscales`
  for the type under test. A later `survey` release can change a default or a
  message without changing its interface.
- **Read a red oracle block against the `survey` version first.** A changed
  default on the oracle side moves the target and produces the same red as a
  surveycore regression.
- `skip_if_not_installed("survey")` goes inside each block that needs it,
  never at file level.

### The oracle rule, all five parts

From `.claude/rules/testing-surveycore.md` §The oracle rule. Rows 2.1, 2.2
and 2.3 are the three oracle rows, and each obeys all five. Row 2.3's premise
designs carry an explicit `scale` and are compared against no `survey`
design, so rule 2 does not reach them; the row's own oracle comparison passes
no `scale` to either side.

1. **Build both sides from the same inputs.** Same data frame, same weight
   column, same replicate columns, same `type`. Pass `mse` explicitly to both
   sides.
2. **Pass `scale` to neither side.** `survey` honours a supplied `scale` for
   JKn and for the bootstrap, so a block that passes surveycore's default in
   gets the same number back out, and a wrong default stays green.
3. **Pass `rscales` to JKn only.** `survey` refuses JKn with combined weights
   and no `rscales`. Write the same literal out twice, once per side. Never
   read `rscales` off a surveycore design. Pass no `rscales` in either
   bootstrap row: `survey` honours one there, and neither row needs it.
4. **Assert the standard error, not the point estimate alone.** The scale
   enters the variance only, so a design with a wrong scale returns the same
   point estimate. Assert both confidence bounds too; they inherit the error.
5. **Assert the condition `survey` raises. Do not silence it.** Keep
   `expect_no_warning()` around each `svrepdesign()` call. A warning means
   `survey` computed the value itself. `suppressWarnings()` hides that.

Three further constraints from the same section:

- Never assert one side's stored scale against the other side's. Assert each
  against a literal.
- A formula banned from a constructor call is still required in an assertion.
  `1` and `1 / (n_rep - 1)` are the literals the two blocks assert.
- Match `survey`'s conditions by message text, not by class. Every condition
  in `svrepdesign()` is a bare `warning()` or `stop()`, so the only class is
  `simpleWarning` or `simpleError`, and that class also matches the "Data do
  not look like combined weights" warning, which means the fixture is broken
  rather than that the comparison held.

Rule 4's confidence-bound clause holds only while both sides build the
interval from the normal approximation, which both do today at `df = Inf`.
This work moves neither side's degrees of freedom. If a later change does,
every bound in both blocks fails at once and the failure reads as a scale
defect.

### What the oracle rows prove, and what they do not

The synthetic fixture builds one replicate weight column per PSU for the
jackknives and the bootstrap, and each column is the base weight jittered
lognormally. No column drops a PSU, and no column is inflated by
`n_h / (n_h - 1)`. So the columns are not a real delete-one jackknife family.

An oracle row on this fixture proves that surveycore and `survey` put the
same numbers into the same formula, `scale * sum(rscales * (theta_r - c)^2)`,
and therefore that the two stored defaults agree. It does not prove that
either side estimates Wolter's stratified jackknife variance. No row in this
document may be reported as statistical validation of the estimator.

### Decision — the JKn oracle row keeps a uniform `rscales` literal

The request's first acceptance criterion writes
`rscales = <per-stratum>`. The JKn oracle row uses `rep(1, n_rep)` on both
sides instead, and this is deliberate.

The fixture's replicate weights carry no stratum structure, so a
per-stratum-shaped literal such as `(n_h - 1) / n_h` would not be the factor
for any stratum of that frame. It would change the numbers and prove nothing
further, while reading to a later reader as a per-stratum validation that no
row here performs.

The per-stratum shape is covered where it can be tested honestly: row 1.2
supplies a non-uniform `rscales` vector to the constructor and asserts that
the stored `scale` is still `1` and the vector is stored verbatim. That is
the property the criterion names — the overall scale does not absorb, rescale
or re-derive the caller's per-replicate factors.

---

## Datasets

| Dataset | Purpose |
|---|---|
| `make_survey_data(design = "replicate", type = "jkn", ...)` | the JKn rows in §1 and §2 |
| `make_survey_data(design = "replicate", type = "bootstrap", ...)` | the bootstrap rows in §1 and §2 |
| `make_survey_data(design = "replicate", ...)` | the unchanged-type row 1.7 and the cross-constructor rows in §3 |
| Inline data frames | the replicate-count boundary of row 1.3, the single-row frame of row 1.6, the four typed-error inputs of row 1.6, the all-NA outcome frame and the mixed zero-weight frame of row 1.8, the logical `subset` column row 1.9 adds to a replicate frame, and the two one-replicate frames of row 2.3 |

No real dataset is needed. `nhanes_2017` and `acs_pums_wy` are for numerical
validation against a reference implementation on real data; the two oracle
blocks this work touches already live on the synthetic fixture, and moving
them would change more than the defaults.

Edge-case data is constructed inline in the block that needs it. Do not add a
parameter to the data generator for any row here.

---

## Per-function test plan

### §1 — `as_survey_replicate()` stored defaults

File: `tests/testthat/test-constructors.R`.

Almost every row asserts `d@variables$scale` against a literal. The stored
scale is a variance multiplier, so the SE tolerance applies: `1e-8`. Rows 1.6
and 1.8 also assert refusals; a refused construction reaches no stored scale,
so those clauses assert a condition class and no number.

Rows 1.2 to 1.8, together with row 2.3, carry seven edge behaviours, and the
set is closed:

1. one replicate column with `type = "bootstrap"` stores `Inf`, and the
   infinite scale reaches the standard error — as `Inf`, or as `NaN` when
   the replicate deviation is exactly zero. The same zero deviation at a
   finite scale gives a standard error of exactly `0`, which is the ordinary
   degenerate case and not an error state (rows 1.3 and 2.3);
2. two replicate columns with `type = "bootstrap"` store `1` (row 1.3);
3. `type = "JKn"` stores `1` at every replicate count, one column included
   (row 1.3);
4. an explicit `scale` is stored verbatim for both types (row 1.4);
5. `type = "JKn"` with `rscales = NULL` stores `1` and raises nothing
   (row 1.5);
6. a non-uniform `rscales` is stored verbatim and `scale` is still `1`
   (row 1.2);
7. neither the shape nor the content of the frame reaches the default, and
   the five pre-existing refusals still fire — four in row 1.6, a fifth in
   row 1.8 (rows 1.6 and 1.8).

A single-level grouping variable was weighed as an eighth behaviour and needs
no row. The constructor under test takes no grouping argument, so grouping
cannot reach the stored default on any path. That is why the set above closes
at seven.

A domain restriction was weighed the same way and needs no row either.
`filter()` marks domain membership and writes no `@variables` key, so a
domain restriction cannot reach the stored default. The other claim of the
same behaviour rule — that the variance takes the same factor after the
restriction — is a claim about `R/variance-replicate.R`. No PR writes that
file, and it is outside the write surface. Grouping and the domain are the
two clauses of one rule, and both are excluded for a reason stated here.

Row 1.9 is not one of the seven edge behaviours. It reads a stored default
back out of a second constructor, so it sits in this section with the other
stored-default rows and leaves the closed set of seven untouched.

| Row | Scenario | Assert |
|---|---|---|
| 1.1 | 20 replicate columns, `type = "JKn"`, `rscales = rep(1, n_rep)`, no `scale`; and the same frame with `type = "bootstrap"`, no `rscales`, no `scale`. The row holds both values per type: the stored default, and the old value written out as a literal | JKn stores `1`; bootstrap stores `1 / (n_rep - 1)`. Each also asserted **not** equal to its old value — `expect_false(isTRUE(all.equal(...)))` against `(n_rep - 1) / n_rep` for JKn and against `1 / n_rep` for the bootstrap. Then the direction and the size of the move, for each type: the stored default is greater than the old value — `expect_gt()` — and the ratio of the stored default to the old value equals `n_rep / (n_rep - 1)` to `1e-8`. Both types take the same ratio, and the ratio is the row's statement of the documented magnitude: the variance rises by `R / (R - 1)`, so a standard error rises by `1 / sqrt((R - 1) / R)`. Neither construction raises a condition. |
| 1.2 | `type = "JKn"` with a non-uniform `rscales` vector of the right length, no `scale` | stored `scale` is `1`; the stored `rscales` equals the supplied vector element for element. The constructor neither normalises the vector nor folds any part of it into `scale`. |
| 1.3 | replicate-count boundary, three constructions: `type = "bootstrap"` with 2 columns; `type = "bootstrap"` with 1 column; `type = "JKn"` with 1 column | bootstrap at 2 columns stores `1`. Bootstrap at 1 column stores `Inf` — assert with `expect_true(is.infinite(...))` and `expect_equal(..., Inf)` — and the construction raises **no** condition. JKn at 1 column stores `1`. Assert each of the three against its own literal, never one against another. The bootstrap value at 2 columns and the JKn value are both `1`, and `R = 2` is the smallest replicate count at which the two changed defaults coincide. The coincidence is arithmetic: `1 / (R - 1)` equals `1` at `R = 2`, and the JKn value is `1` at every `R`. It carries no relationship between the two types. |
| 1.4 | an explicit `scale` for each changed type, e.g. `scale = 0.25` | the stored value is the supplied one for both types. The default is not computed when the caller supplies one. This is the route back to the pre-change numbers. |
| 1.5 | `type = "JKn"` with `rscales = NULL`, no `scale` | stored `scale` is `1`; stored `rscales` is `NULL`; the construction raises no condition. `survey` refuses this input and surveycore accepts it; that gap belongs to issue #255 and is not a defect of this work. |
| 1.6 | frame shape does not reach the default: a one-row frame with each changed type; then four refusals — a zero-row frame, a `repweights` selection of zero columns, an all-zero weight column, and an `rscales` of the wrong length | the one-row frame stores the same two values as row 1.1. The four refusals raise `surveycore_error_empty_data`, `surveycore_error_repweights_empty`, `surveycore_error_weights_all_zero` and `surveycore_error_rscales_length` respectively, by `class =`. See §Error-path pattern for why these carry no new snapshot. |
| 1.7 | the full nine-type default table: build one design per `type` on one frame with no `scale`, supplying `rscales` only where the constructor requires it | each stored `scale` equals the value §What this work changes gives for that `type` — the table there for the two changed types, the paragraph below it for the other seven. Read the nine values there and transcribe them into the block. This row states no value of its own: two copies of the same nine numbers in one document drift apart. Nine types, nine assertions, two of them the changed rows. |
| 1.8 | the content of the frame. Two inline frames, at least four rows each and at least three replicate weight columns each, so `1 / (n_rep - 1)` is neither `1` nor `Inf`. **Frame 1** holds an outcome column that is `NA` in every row, a strictly positive weight column and valid replicate weight columns. Build it with `type = "JKn"` and then with `type = "bootstrap"`, no `scale` either time. **Frame 2** holds a valid outcome column and a weight column that mixes zeros with positive values. Build it with each of the same two types | Frame 1: both designs build, and each stored `scale` equals the value row 1.1 asserts for that `type` — `1` for JKn, `1 / (n_rep - 1)` for the bootstrap. Neither construction raises a condition, and the stored `rscales` is the supplied vector, unchanged. The default reads `type` and the replicate count and reads nothing in the data, so an all-`NA` outcome column cannot move it. Frame 2: **both constructions are refused.** Each raises `surveycore_error_weights_nonpositive`, by `class =`. The refusal is pre-existing and fires before the default is computed, so no `scale` is reached on that frame and none may be asserted there. This is the fifth pre-existing refusal in this document; the other four are in row 1.6. See §Error-path pattern. |
| 1.9 | a `survey_twophase` design over a replicate `phase1`. Build one `survey_replicate` design with `type = "JKn"` and no `scale`, and one with `type = "bootstrap"` and no `scale`, on a frame that also carries a logical `subset` column. Then build a `survey_twophase` over each, passing the replicate design as `phase1` | the two-phase design's stored `phase1` scale equals the new default for that `type`: `1` for JKn, `1 / (n_rep - 1)` for the bootstrap. Assert each against its own literal at `1e-8`, never one against the other. The two-phase constructor copies `phase1@variables` and recomputes no value in it, so the stored default crosses the copy unchanged. Neither two-phase construction raises a condition. A Taylor `phase1` carries no `scale`, so this work leaves a Taylor two-phase design untouched; no assertion here covers that case. |

### §2 — Oracle rows against `survey`

File: `tests/testthat/test-variance-replicate.R`. Rows 2.1 and 2.2 are the
two blocks that hold the sanctioned exceptions today; see §4, row 4.3, for
the state they must end in.

| Row | Scenario | Assert |
|---|---|---|
| 2.1 | JKn. One frame, 20 replicate columns, `mse = TRUE` on both sides, `rscales = rep(1, n_rep)` written out once per side, no `scale` to either side | `survey`'s stored scale equals the literal `1` (tolerance `1e-8`) — this guards the oracle, and a failure here means `survey` changed. The point estimate agrees to `1e-10`. The standard error agrees to `1e-8`. Both confidence bounds agree to `1e-6`. `expect_no_warning()` around the `svrepdesign()` call. |
| 2.2 | bootstrap. One frame, 20 replicate columns, `mse = TRUE` on both sides, no `rscales` and no `scale` to either side | `survey`'s stored scale equals the literal `1 / (n_rep - 1)` (tolerance `1e-8`). The point estimate agrees to `1e-10`, the standard error to `1e-8`, both confidence bounds to `1e-6`. `expect_no_warning()` around the `svrepdesign()` call. |
| 2.3 | `R = 1` with `type = "bootstrap"`, two inline frames, and the mean of one numeric column computed on each — `get_means(variance = c("se", "ci"), min_cell_n = 1L)` on the surveycore side, `survey::svymean()` with `survey::SE()` and `confint()` on the `survey` side. Both arguments are required and neither is the default. `variance` defaults to `"ci"`, which returns the two bounds and no standard error, and this row asserts a standard error four times. `min_cell_n` defaults to `30L` and raises `surveycore_warning_small_cell` for any cell below it, so a four-row frame raises it on every call; `1L` silences it at the source rather than asserting it, because the small cell is a property of these fixtures and not of the behaviour under test. Both frames hold four rows of small exactly-representable values, so no rounding occurs on either accumulation route: the outcome column is `c(1, 2, 3, 4)` and the base weight column is `c(1, 1, 2, 2)`. Frame B sets the one replicate weight column equal to the base weight column, `c(1, 1, 2, 2)`, so the replicate weighted mean equals the full-sample weighted mean and the deviation is exactly zero. Frame A changes one element of that column and leaves the rest, `c(5, 1, 2, 2)`, so the weighted mean moves and the deviation is not zero. Frame A's difference must be non-proportional. A weighted mean does not change when the whole weight column is multiplied by a constant, so a replicate column such as `3 * w` differs at every element and still gives a deviation of exactly zero; a frame A built that way silently becomes frame B. `mse = TRUE` on both sides of both frames, no `scale` to either side | assert the premise before the conclusion in each frame. The premise is observable through one extra surveycore design per frame, built on the same frame with an explicit `scale = 1`. On frame B that design's standard error is exactly `0` — `expect_equal(..., 0, tolerance = 0)` — which proves the deviation is zero. On frame A the same design's standard error is finite and greater than zero, which proves the deviation is not zero. The premise design is compared against no `survey` design, so oracle rule 2 does not reach it. Then the default-scale designs: on frame B the standard error is `NaN` and both confidence bounds are `NaN`, because `Inf * 0` is `NaN`; on frame A the standard error is `Inf` and both confidence bounds are infinite. Assert with `expect_true(is.nan(...))` and `expect_true(is.infinite(...))`; these are exact assertions and carry no tolerance. The order is the point: a later change that introduces rounding on either accumulation route then turns the premise red, in place of turning the `NaN` conclusion red for a reason its message does not name. Neither construction and neither estimate raises a condition, which holds only with `min_cell_n = 1L` — at the default the small-cell warning fires on all four calls and this clause is false. `survey::svrepdesign()` on the same frames and the same arguments reaches the same two outcomes, asserted the same way, because D5 makes `survey` the authority for this input. `expect_no_warning()` around each `svrepdesign()` call. Assert each side against a literal and never against the other side. Probe the installed `survey` on both frames before writing the block. If `survey` raises a condition on either frame, match it by message text, assert it, and report the finding; do not silence it. |

**Row 2.3 carries far more assertions than any other row in this document.**
It holds two frames, four designs, a premise assertion per frame and a
standard error and two confidence bounds per frame per side — between six and
eight assertions in all. So the row count in this document is not the measure
of the test load, and §2's three rows are not three blocks of equal size.
Read the rows, not the count.

Row 2.3 is the only row that reaches the variance engine with an infinite
scale. Row 1.3 asserts the stored `Inf`; row 2.3 asserts what the engine
does with it.

### §3 — The two constructors against each other

File: `tests/testthat/test-constructors.R`.

| Row | Scenario | Assert |
|---|---|---|
| 3.1 | JKn on one frame, built once with `as_survey_replicate()` and once with `as_survey_nonprob()`, the same `rscales` literal to both | the two stored scales are equal and each equals `1`. `get_means()` on the two designs returns the same mean to `1e-10` and the same standard error to `1e-8`. |
| 3.2 | bootstrap on one frame, built once with each constructor | the replicate design stores `1 / (n_rep - 1)` and the nonprob design stores `1 / n_rep`, each against its literal at `1e-8`. The two values differ by decision, not by defect. The ratio of the nonprob standard error to the replicate standard error equals `sqrt((n_rep - 1) / n_rep)` to `1e-8`. |

`as_survey_nonprob()` refuses a single replicate column and refuses `"JKn"`
with no `rscales`, so both rows need at least two columns and row 3.1 needs
the literal.

### §4 — Documentation, deletions and regression

| Row | Scenario | Assert |
|---|---|---|
| 4.1 | the rendered help page for `as_survey_replicate()` | the `scale` argument's text carries eight facts: (1) the JKn default is `1`; (2) the bootstrap default is `1 / (R - 1)`; (3) for JKn the per-stratum factor belongs in `rscales`, `rscales = NULL` means no jackknife factor enters the variance, and the factor is `(n_h - 1) / n_h` for with-replacement PSU selection or a negligible sampling fraction; (4) a bootstrap design of one replicate column gives an infinite scale, and `survey` does the same; (5) surveycore has no `bootstrap.average` argument, so a caller cannot build a design with one and this constructor's bootstrap default is always `1 / (R - 1)`, and an imported `survey` design keeps its effective scale exactly, in both directions; (6) passing `scale` explicitly reproduces the pre-change numbers; (7) a caller who samples PSUs without replacement at a sampling fraction that is not negligible must fold `(1 - n_h / N_h)` into each `rscales` entry by hand, which makes the entry `(n_h - 1) * (1 - n_h / N_h) / n_h`, and `rscales` is the only route for that correction; (8) `as_survey_nonprob()` keeps `1 / R` for `"bootstrap"`, so the same `type` string means a different divisor in the two constructors, the difference is a decision and not a defect, and that other help page holds the reason and the size of the gap. Fact 5 carries two elements: the missing argument, and the preserved scale. A rendered fact 5 that says a `survey` design built with `bootstrap.average != 1` cannot round-trip is a defect to report — it was measured false. Fact 7 carries three elements of its own: the corrected entry; a symbol key; and one clause on where `N_h` comes from. The symbol key states that `n_h` is the number of sample PSUs in stratum `h` and that `N_h` is the number of population PSUs in stratum `h`. Both symbols count PSUs; a key that makes `N_h` a count of elements is wrong, because the caller computes `1 - n_h / N_h` by hand and the ratio is a sampling fraction only when the two counts are of the same kind of unit. The provenance clause states that the caller supplies `N_h` from their own frame. Fact 8 carries three elements: the other constructor's name, its value `1 / R`, and the decision clause with its pointer. Fact 8 carries no factor and no percentage; a rendered percentage there is a second copy and is a finding to report. Eight facts, all eight present. Fact 3 carries all three of its clauses, fact 5 both of its elements, fact 7 all three of its elements, and fact 8 all three of its elements. Two further observables on the same page, outside the eight: the `rscales` argument's own text points the reader at the `scale` argument for the without-replacement correction, naming the `scale` argument and carrying no formula of its own; and the `fpc` argument's own text states that `fpc` has no effect for a replicate design and that the without-replacement correction goes into `rscales` instead, again with a pointer to `scale` and no formula. So the page carries eight facts in the `scale` argument, one cross-reference in the `rscales` argument, and one clause in the `fpc` argument. Read the rendered page, not the source comment. |
| 4.2 | the rendered help page for `as_survey_nonprob()` | it carries four elements: `survey`'s bootstrap value, `1 / (R - 1)`; `as_survey_replicate()` as the constructor that matches it; the reason this constructor keeps `1 / R`, which is that `survey` has no non-probability design class; and the size of the divergence — on the same frame the `as_survey_nonprob()` bootstrap standard error is smaller than the `as_survey_replicate()` one by `sqrt((R - 1) / R)`, which is 2.5% at `R = 20`. The percentage is direction-specific, and the two directions do not share one number: `sqrt(19 / 20)` is 0.9746794, so the fall to the smaller standard error is 2.5% and the rise to the larger one is 2.6%. This note states the fall, so 2.5% is the figure that passes, and a rendered 2.6% here is a defect to report. All four elements present. Count the elements and not the sentences: the note may run to one sentence or two. The existing Wu (2022) and Chen et al. (2021) citation is still there. |
| 4.3 | the two blocks of rows 2.1 and 2.2, read as text | neither block contains a `testthat::expect_failure()` call. Neither block contains an assertion of a standard-error ratio against `sqrt((n_rep - 1) / n_rep)`. Each block lost four lines: three wrappers and one closing ratio assertion, eight lines across the two. The three assertions each wrapper held — the standard error and the two confidence bounds — are present and pass unwrapped. Neither block's title nor opening comment says the two sides disagree. |
| 4.4 | the old values, checked against the diff | exactly one pre-existing block asserted `1 / n_rep` as the stored default of `as_survey_replicate(type = "bootstrap")`, and it is retargeted to the new value. No block asserted the JKn old value. Check this against the diff and not against the suite: read the diff of `tests/testthat/`, list every changed line that holds the literal `1 / n_rep` or `(n_rep - 1) / n_rep`, and confirm that each one is either the retargeted block or a new block this work adds. Then confirm the diff touched no other line holding either literal. A whole-suite semantic scan is not the method here: `tests/testthat/` discusses `1 / n_rep` in nonprob blocks that are correct and stay, in comments and in block titles, so a textual count reads high and proves nothing. The diff has a closed size and a known expected content. |
| 4.5 | suite regression | every test file outside `tests/testthat/test-constructors.R` and `tests/testthat/test-variance-replicate.R` holds its state. No file under `tests/testthat/_snaps/` changes: no snapshot renders a stored replicate scale. If a snapshot does change, report it and do not accept it. |
| 4.6 | release notes | `NEWS.md` carries one entry for this work under the bug-fix heading, and the entry carries six elements: (1) both changed types with both new values; (2) the direction and the size of the move; (3) the explicit `scale` values that reproduce the old numbers; (4) the reason `as_survey_nonprob()` keeps `1 / R`; (5) the issue number `#253`; (6) one clause separating the two changes — the JKn move corrects a formula error and cites Wolter, while the bootstrap move aligns surveycore with `survey`'s convention and does not mean an older `1 / R` number was wrong. Six elements, all six present. One entry, not two, and it stays under the bug-fix heading. It does not claim to cover issue #243, whose argument does not exist yet. One file exists under `changelog/` for this work. |

Row 4.3 clears **one** of the two sanctioned exceptions in
`.claude/rules/testing-surveycore.md` §Sanctioned exceptions. The other is
the Fay block, which compares nothing and belongs to issue #243. A report
that says this work clears both is wrong.

Do not count constructs in `tests/testthat/test-variance-replicate.R` with
`grep -c`. That file discusses its own constructs in comments and in block
titles, so a textual count reads high — `expect_failure` has read 12
textually against 6 real calls. Read the two blocks and count the calls.

### Error-path pattern

This work adds no error class and no warning class, so the dual pattern has
nothing new to cover. `.claude/rules/testing-standards.md` requires
`expect_error(class = ...)` plus `expect_snapshot(error = TRUE, ...)` for a
user-facing constructor error.

This document names five pre-existing classes: four in row 1.6, and
`surveycore_error_weights_nonpositive` in row 1.8. **Every one of the five is
asserted by `class =` only, and no row adds a snapshot.** The reason differs
between four of them and one.

- **Four of the five already carry a snapshot** of the message a reader would
  see. A new snapshot of an unchanged message duplicates an existing one and
  gives a reviewer two files to keep in step.
- **One does not.** No snapshot anywhere covers `as_survey_replicate()`
  raising `surveycore_error_weights_all_zero`. The message text is on the
  record for `as_survey()`, so only this constructor's route is missing. The
  gap is pre-existing, this work neither creates nor widens it, and one issue
  filed in this run owns it: `#291`. Do not close the gap here. Adding the
  snapshot would change a file under `tests/testthat/_snaps/`, and row 4.5
  requires every file there to hold its state.

Both bullets are deliberate departures from the dual pattern, and this
document authorises no other. Name the second bullet in the report: a
reviewer who finds a class-only assertion with no snapshot anywhere behind it
should read `#291` and not file a defect.

If any block needs a condition class that does not appear in this document,
stop and report it. The work is expected to add none.

### Invariants

`test_invariants(design)` runs once per constructor per test FILE, in the
first block that builds with that constructor — not in every block that
builds one.

- `tests/testthat/test-constructors.R` already calls it four times, one per
  constructor.
- `tests/testthat/test-variance-replicate.R` already calls it once.

New blocks in either file add no further call. A new call in a later block of
either file is a rule breach, not extra safety.

### Input modes

No row here runs in two input modes. The both-modes rule reaches
`extract_dataset_metadata()`, `set_dataset_metadata()` and the ten
dataset-metadata wrappers, and no function in this work is one of them.
`as_survey_replicate()` takes a data frame only.

---

## Tolerances

| Estimand | Tolerance |
|---|---|
| Point estimates (mean, total, proportion) | `1e-10` |
| SE / variance | `1e-8` |
| CI bounds | `1e-6` |

Two mappings, neither a deviation:

- A **stored `scale`**, and a **ratio of two stored `scale` values**, is a
  multiplier on the variance, so each takes the SE row: `1e-8`. Both existing
  oracle blocks already assert `survey`'s stored scale at `1e-8`. Row 1.1
  asserts such a ratio.
- A **ratio of two standard errors** takes the SE row: `1e-8`. Row 3.2
  asserts such a ratio.

One deviation, with its justification.

**Row 2.3's premise on frame B asserts a standard error of `0` at
`tolerance = 0`.** That frame holds four rows of small
exactly-representable values, so no rounding occurs on either accumulation
route and the replicate deviation is exactly zero. The premise is the reason
the row's `NaN` conclusion holds. An approximate premise would let a later
rounding change turn the conclusion red while the premise stayed green. The
matching premise on frame A asserts a finite standard error greater than
zero — `expect_true(is.finite(...))` and `expect_gt(..., 0)` — which is a
question of sign and finiteness and not of tolerance.

The function there is `expect_equal()` and not `expect_identical()`.
`.claude/rules/testing-standards.md` §Assertions puts every calculated
numeric result and every estimate in the `expect_equal()` column, and a
standard error from `get_means()` is both. That table is categorical and
carves out no exact claim, so the exactness rides on `tolerance = 0` and the
function stays `expect_equal()`. `tests/testthat/test-conversion.R:837-838`
asserts a mean and a standard error the same way.

Three exact assertions, none of them a tolerance question:

- the infinite stored scale of row 1.3, asserted with
  `expect_true(is.infinite(...))` as well as against the literal `Inf`;
- the infinite standard error and bounds of row 2.3 frame A, asserted with
  `expect_true(is.infinite(...))`;
- the `NaN` standard error and bounds of row 2.3 frame B, asserted with
  `expect_true(is.nan(...))`.

No other deviation is authorised. A row that cannot meet its tolerance is a
finding to report, not a tolerance to relax.

---

## Ordering constraint

The two oracle blocks cannot be observed in their end state before the two
defaults move. An `expect_failure()` wrapper turns red when the assertion
inside it starts to pass, so the corrected defaults and the wrapper deletion
must be observed in the same run. Row 4.3 and rows 2.1 and 2.2 are therefore
not independently observable against the current defaults.

Row 2.3 is in the same position for a different reason. The current
bootstrap default at one replicate column is `1 / R`, which is `1` and
finite, so neither the infinite standard error nor the `NaN` one exists
before the default moves. The row is observable only after the move.

Every clause anywhere in this document that names a changed default is in the
same position, for the plainest reason: it asserts a new value against a
literal. Apply that rule and do not work from a list: rows 1.1, 1.2, 1.3,
1.5, 1.6, 1.8, 1.9, 2.1, 2.2, 2.3, 3.1 and 3.2 each assert at least one
changed default somewhere, as do the two changed types of row 1.7. A list
of the rows in this position goes stale on the next edit; the rule does not.
The clauses that name an unchanged default are observable before the move and
after it — the seven unchanged types of row 1.7 are the whole of that set.

---

## How to run

| Run | Command | Use for |
|---|---|---|
| Fast | `NOT_CRAN=false Rscript -e "testthat::test_local()"` | the edit-run loop; it skips 11 slow files |
| Full | `Rscript -e "devtools::test()"` | before any push or PR; it runs everything |

`devtools::test()` cannot reach the fast speed: it sets `NOT_CRAN = "true"`
unconditionally, so the shell variable never reaches the tests.

Measure coverage with `NOT_CRAN=true`. Without it, 11 files skip and coverage
reads several points low.

### How to read three gates

- **Warnings from the full test run.** Clean `develop` carries a large number
  of pre-existing small-cell warnings from the AAPOR checks. The gate reads
  as "no new warning", not "zero warnings".
- **Formatting.** `air` is a command-line tool here, not an R package, and
  files repo-wide are already not air-clean. The gate reads as "the files
  this work touches pass `air format --check`".
- **Coverage.** The floor is 95% and the target is 98%, package-wide, on the
  full run with `NOT_CRAN=true`. Report the figure and the change against the
  baseline. A baseline that cannot be measured is reported as such; judge the
  95% floor in that case.

---

## Profile gates

- [ ] devtools::document() clean
- [ ] devtools::test() all pass
- [ ] devtools::run_examples() all pass
- [ ] R CMD check --as-cran (0 err, 0 warn, notes reviewed)
- [ ] pkgdown::build_site() clean
- [ ] covr::package_coverage() ≥ 95% (target 98%)
- [ ] CRAN cookbook scan clean (see r-package-profile.md)
