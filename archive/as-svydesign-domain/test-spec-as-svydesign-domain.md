# Test-spec — as-svydesign-domain

## Reference oracle

| Route | Oracle | Claim |
|---|---|---|
| Taylor, replicate, non-probability with replicate weights, non-probability without | `survey::svymean()` (`survey` 4.5) on the converted object, against `get_means()` on the filtered design | The two agree on the point estimate and on the standard error |
| Two-phase | Two claims, both measurable, neither comparing the route to `get_means()` | 1. The converted object of a filtered design equals the object a caller gets by restricting the converted object of the same unfiltered design by hand. 2. The gap between `survey::svymean()` and `get_means()` on the **unfiltered** two-phase design does not move |

The two-phase route gets its own oracle because the obvious one is unmeetable
and this change is not the reason. surveycore's two-phase estimator weights by
the phase-1 weight column and `survey`'s two-phase object weights by the
combined two-phase probability. Measured on the fixture: 58.45753 against
58.06658 on a filtered design, and 48.9 against 49.203 on the same design
unfiltered, where no domain exists at all. The gap is pre-existing and
independent of the domain, and it is filed separately as issue #261.

All rows that touch the oracle carry `skip_if_not_installed("survey")`, at block
level, per `.claude/rules/testing-standards.md`.

## Datasets

| Data | Purpose |
|---|---|
| The existing fixtures of `tests/testthat/test-conversion.R` — the Taylor, replicate, two-phase and non-probability builders already defined at the top of that file and in its non-probability section | Every structural and every parity row. The file's existing parity rows all use these, so a new row reads next to its neighbours. |
| `make_survey_data()` directly, per `.claude/rules/testing-surveycore.md` | Any row whose fixture needs a shape the existing builders do not produce — a two-phase design that names a phase-2 cluster identifier, and the non-probability shapes |
| `nhanes_2017` | One row: numerical validation of the Taylor route against `survey` on real data, which the data policy in `.claude/rules/testing-surveycore.md` asks for |
| Inline constructions | The atypical marker columns: all-`FALSE`, single-`TRUE`, `NA`-bearing, all-`NA`, integer, character, factor with `FALSE`/`TRUE` levels, and factor with unrelated levels. Built in the test block and never added as a fixture parameter. |

### How a test marks a domain

Two producers, and both belong in the file.

- **By hand.** Assign a vector to the design's data under
  `SURVEYCORE_DOMAIN_COL`, the exported constant. Logical for most rows, and a
  deliberately non-logical vector for the marker-type rows. This is the
  established pattern in `test-analysis-means.R`, `test-analysis-totals.R`,
  `test-analysis-ratios.R` and `test-analysis-quantiles.R`, and the last of
  those writes an integer marker at line 460. It needs no extra package, it is
  deterministic, and it is the only way to build the atypical marker columns.
- **Through the real producer.** One row uses `surveytidy::filter()` with
  `skip_if_not_installed("surveytidy")`, so the chain from the real caller's
  verb to the converted object is proved end to end and not only from the
  marker inwards.

## Per-function test plan

### `as_svydesign()` — a filtered design, the four routes with the standard oracle

| Row | Scenario | Assertion | Tolerance |
|---|---|---|---|
| A-1 | Taylor design, marker set on a predicate over an outcome column | `survey::svymean()` on the converted object equals `get_means()` on the filtered design, point and SE | point 1e-10, SE 1e-8 |
| A-2 | Replicate design (BRR), same marker | Same, **plus the two marker assertions below** | point 1e-10, SE 1e-8 |
| A-3 | Non-probability design that names replicate weights, same marker | Same, **plus the two marker assertions below** | point 1e-10, SE 1e-8 |
| A-4 | Non-probability design that names no replicate weights, same marker | Same, **plus the two marker assertions below**. The block captures the pre-existing warning class `surveycore_warning_nonprob_srs_conversion` with `expect_warning(sv <- ..., class = ...)` and reads the result off the return value | point 1e-10, SE 1e-8 |
| A-5 | Taylor design, marker produced by `surveytidy::filter()` rather than by hand | Same as A-1. `skip_if_not_installed("surveytidy")` | point 1e-10, SE 1e-8 |
| A-6 | Taylor design built on `nhanes_2017`, marker set on an age predicate | Same as A-1, on real data | point 1e-10, SE 1e-8 |

The preflight measured agreement to every printed digit on all four of these
routes, so no deviation from the default tolerances is needed.

**The two marker assertions.** Rows A-2, A-3 and A-4 each add the two
assertions D-7 already makes on the Taylor route:

1. `SURVEYCORE_DOMAIN_COL` is a name of the converted object's variables.
2. Every value in that column is `TRUE`.

The guarantee is stated for every route, and without these three rows it would
be tested on two of five. Use `expect_true()` for the presence and
`expect_identical()` against a same-length `TRUE` vector for the values.

### `as_svydesign()` — the two-phase route and its own oracle

| Row | Scenario | Assertion | Tolerance |
|---|---|---|---|
| B-1 | Two-phase design that names a phase-2 cluster identifier, marker set by hand | `survey::svymean()` on the converted object of the filtered design equals `survey::svymean()` on the converted object of the same unfiltered design after the caller indexes it by the marker column read from its own phase-1 sample variables, with `NA` treated as `FALSE`. Point and SE | point 1e-10, SE 1e-8 |
| B-2 | The same two-phase design, unfiltered | The gap's mechanism, so the row fails if the gap moves. `get_means()` equals the weighted mean of the outcome computed by hand from the phase-1 weight column over the phase-2 rows. `survey::svymean()` on the converted object equals the weighted mean computed by hand from the reciprocal of the converted object's own probability vector over the same rows. The two answers differ | point 1e-10 on each hand computation |
| B-3 | Two-phase design, filtered | The count of finite probabilities in the converted object equals the count of marked phase-2 rows. Assert with `expect_identical()` on `sum(is.finite(...))` against `sum(...)` of the marker. **Do not assert the row count.** Measured, the two-phase route applies the domain by setting each excluded row's probability to `Inf` and keeps every row: with 12 of 29 phase-2 rows marked, the restricted object has 29 rows and 17 infinite probabilities, and the estimate is correct. `subset()` gives the same 29 rows, so this belongs to the two-phase design and not to the operator. A row-count assertion would read 29 against 12 and fail | — |
| B-4 | Two-phase design in the shape the file's existing builder produces, which names no phase-2 cluster identifier, filtered | The conversion returns a two-phase object and raises no error. This row exists because the preflight measured the route on a design that names a phase-2 identifier, and the file's own builder does not. If it fails, report the failure; do not change the fixture to route around it | — |

The two-phase conversion already emits an untyped condition from the `survey`
package on this fixture, which every existing two-phase block in the file wraps
in `suppressWarnings()`. The B rows keep that treatment, and assert separately
that no typed surveycore condition appears — the assertion for the two-phase
route is **G-1c**, which gives the technique. Do not use
`expect_no_condition()` anywhere on this route.

A second untyped `survey` condition is reachable on this route and the fixture
does not trigger it. `[.twophase` counts PSUs per stratum over the finite
probabilities and calls
`warning(sum(tt == 1), " strata have only one PSU in this subset.")`. A domain
that thins a stratum to one PSU fires it. It carries no class of any kind, so
`suppressWarnings()` is the only way to tolerate it, and no row should assert
its absence.

### `as_svydesign()` — an unfiltered design, all five shapes

Each row asserts three things: the converted object has one row per design row,
the marker column is not a name of the converted object's data, and the call
raises no condition beyond the one the shape already raises.

| Row | Shape | Pre-existing condition the row tolerates |
|---|---|---|
| C-1 | Taylor | none |
| C-2 | Replicate carrying no FPC | none |
| C-3 | Two-phase | the untyped condition from `survey` |
| C-4 | Non-probability, replicate weights | none |
| C-5 | Non-probability, no replicate weights | `surveycore_warning_nonprob_srs_conversion` |

An unfiltered design carries no marker column at all — measured, the constant
is not a name of the design's data — so C-1 to C-5 also prove that "restrict
when the column is present" is the whole guard, and that nothing manufactures
an all-`TRUE` column.

### `as_svydesign()` — edge cases

Every row names its route. The outcome of an empty domain genuinely differs by
route, so a row written against an implicit Taylor default would leave the
suite silent about the divergence.

| Row | Route | Marker column | Assertion |
|---|---|---|---|
| D-1 | Taylor | Every value `TRUE` | The converted object has one row per design row, and `survey::svymean()` on it equals `get_means()` on the design to the A-row tolerances. A full domain and no domain reach the same answer by different paths |
| D-2a | Taylor | Every value `FALSE` | The converted object has zero rows. The conversion raises no condition. `survey::svymean()` on the result answers an estimate of 0 with a standard error of 0. This row pins the chosen behaviour, so a later editor cannot read the silence as an oversight |
| D-2b | Replicate (BRR) | Every value `FALSE` | The converted object has zero rows and the conversion raises no condition. Estimation then **fails inside `survey`**: `survey::svymean()` errors with the message `All replicates contained NAs`. Assert the error with `expect_error()` matching that message. The condition is `survey`'s and carries no class, so no `class =` argument and no snapshot |
| D-2c | Two-phase | Every value `FALSE` | The conversion raises no surveycore condition. The row count is **unchanged** and no probability in the converted object is finite. `survey::svymean()` on the result answers `NaN`. Assert the `NaN` with `expect_true(is.nan(...))`, not with an equality comparison |
| D-2d | Both non-probability shapes | Every value `FALSE` | The conversion raises no condition beyond `surveycore_warning_nonprob_srs_conversion` on the shape that names no replicate weights, and the converted object has zero rows. For the estimation outcome, the shape follows the helper it routes into: the shape naming no replicate weights follows D-2a, and the shape naming replicate weights follows D-2b |
| D-3 | Taylor | Exactly one value `TRUE` | The converted object has one row. The conversion raises no condition |
| D-4 | Taylor | Logical with `NA` in some rows | The converted object has one row per `TRUE`, and the `NA` rows are absent. Compare the row count with `expect_identical()` against the count of `TRUE` values |
| D-5a | Taylor | Every value `NA` | Equivalent to D-2a: zero rows, no condition from the conversion |
| D-5b | Two-phase | Every value `NA` | Equivalent to D-2c: unchanged row count, no finite probability, no surveycore condition from the conversion |
| D-6 | Taylor | Integer `0` and `1` rather than logical | The converted object has one row per `1`. The row exists because the repo's own analysis tests write an integer marker column, and because a numeric vector would otherwise read as row positions |
| D-6a | Taylor | Character `"TRUE"` and `"FALSE"` | The converted object has one row per `"TRUE"`, and the conversion raises **no condition**. Measured, a character column is a reachable state that used to raise an unclassed base error out of the conversion: `operations are possible only for numeric, logical or complex types`. Use `expect_no_condition()` for the conversion and `expect_identical()` for the row count |
| D-6b | Taylor | Factor with levels `FALSE` and `TRUE` | The converted object has one row per row whose factor value is `TRUE`, and the conversion raises **no condition**. This is the row that guards the worst measured failure: without coercion, a factor marker produced a warning, an all-`NA` mask, an object keeping every row with a probability vector that was neither finite nor infinite, and then an unclassed error three frames inside `survey`. So the row asserts the row count **and** that every probability in the converted object is finite |
| D-6c | Taylor | Factor with unrelated levels, say `"yes"` and `"no"` | The converted object has zero rows and the conversion raises no condition. An unconvertible marker reads as an empty domain, which is safe and inspectable. The row records that as the chosen outcome rather than an accident |
| D-7 | Taylor and two-phase | Marker set | The marker column is still a name of the converted object's data. On the Taylor route every value in it is `TRUE`. On the two-phase route assert only the presence, in the phase-1 sample variables — that route removes no row, so the column still holds `FALSE` for the zero-weighted rows. The column is kept on purpose |
| D-8 | Taylor | Marker set | The input design is unchanged by the call: its row count and its marker column are identical before and after. A second call on the same design returns the same row count |

Rows D-6, D-6a, D-6b and D-6c are one group: the marker column's type must not
change which rows the conversion selects, and must not change whether it raises
anything. D-6 keeps its original id and its original assertion.

A zero-row design is not a reachable input: every constructor requires at least
one row, so no row tests it. An all-`NA` outcome column is out of scope with
reason: the conversion reads the design variables and the marker, never an
outcome column, so an all-`NA` outcome changes nothing the conversion does.

No row combines a domain with labelled columns, and that is a decision rather
than an oversight. The file already carries labelled round-trip rows on
unfiltered designs, and row-indexing a labelled column preserves its
attributes, so the risk that a domain restriction drops a label is low. If a
labelled round-trip row ever fails on a filtered design, that is a finding to
report and a new row to add.

Every empty-domain outcome the D-2 rows assert is measured, including both
non-probability shapes. The shape that names replicate weights converts to a
replicate-class object and its estimation errors; the shape that names none
converts to a Taylor-class object and answers zero with a zero standard error.
The rows state outcomes, not inferences from routing.

### `as_tbl_svy()`

| Row | Scenario | Assertion |
|---|---|---|
| E-1 | Filtered Taylor design | The returned object is a `tbl_svy` whose variables carry one row per marked row. The function is a wrapper, so this row proves the restriction propagates and nothing in the wrapper undoes it |
| E-2 | Filtered non-probability design that names no replicate weights | The returned object is a `tbl_svy` with the domain row count, and the block captures `surveycore_warning_nonprob_srs_conversion`. No second snapshot of that message: the file already holds its golden copy |

**Why this section carries no numerical-oracle row, written down so the absence
does not read as an oversight.** The oracle category is covered by proxy.
`as_tbl_svy()`'s body is unmodified by this change: it converts with
`as_svydesign()` and wraps the result, so every number it can return is a
number `as_svydesign()` produced. The oracle rows on `as_svydesign()` cover all
five underlying shapes — A-1 through A-4 and A-6 for the four standard-oracle
shapes, B-1 and B-2 for the two-phase shape. E-1 and E-2 then prove the
delegation: the restriction reaches the wrapper's output and the wrapper undoes
nothing. An oracle row here would re-measure `as_svydesign()` through one extra
function call. Adding one is welcome and is not required.

### The round trip

| Row | Scenario | Assertion | Tolerance |
|---|---|---|---|
| F-1 | Filtered Taylor design, converted then converted back | The rebuilt design's `@variables` names the identical values for `ids`, `strata` and `weights` as the round trip on the same design unfiltered. Use `expect_identical()`. **This is the guard against a later editor reaching for `subset()`**: measured, that path loses `ids` and `strata` with no error raised, which is why the row asserts the names and not only that the round trip runs | — |
| F-2 | Filtered Taylor design | The converted object's stored call deparses identically to the stored call of the converted object of the same design unfiltered. The restriction must not rewrite the call | — |
| F-3 | Unfiltered Taylor design, converted then converted back | The rebuilt design's `@variables` names `ids`, `strata` and `weights`. The baseline F-1 compares against, asserted separately so a joint failure is readable | — |
| F-4 | Filtered Taylor design, converted then converted back | `get_means()` on the rebuilt design and `survey::svymean()` on the converted object agree on the point estimate, the standard error and both confidence bounds. The confidence bounds are the assertion that matters: measured, a round trip through the wrong operator keeps the point estimate and shifts the interval, from 56.8-59.6 to 56.9-59.5, because the clustering and the stratification were lost | point 1e-10, SE 1e-8, CI 1e-6 |
| F-5 | Filtered Taylor design, converted then converted back | The rebuilt design carries the marker column in its data with every value `TRUE`, and its printed output carries the `Domain: n of n rows` line. The reverse direction recovers no domain; it carries the all-`TRUE` column back as data. The row records that, so nobody later reads the line as a bug | — |
| F-6 | Filtered two-phase design, converted, restricted, then converted back | The rebuilt design carries the marker column with the same mixed values it had before, not an all-`TRUE` column, and its row count is the full phase-1 frame rather than the domain. Assert the marker's `TRUE` count and the row count with `expect_identical()`. This route removes no row, so its round trip recovers the domain where the other four lose it — the row exists so the difference is pinned rather than discovered | — |

### Error paths

The change adds no error class and no warning class, so there is no new dual
`expect_error(class = ...)` plus `expect_snapshot(error = TRUE)` pair to write
and no new snapshot file entry.

The three existing refusals of `as_svydesign()` keep their existing blocks
unchanged: the non-survey-object refusal, the empty-replicate-columns refusal,
and the two Fay shrinkage-factor refusals. Each fires before any object exists
to restrict, so no row needs a filtered variant of them.

| Row | Route | Assertion |
|---|---|---|
| G-1a | Taylor | `as_svydesign()` on a filtered Taylor design raises no condition at all — `expect_no_condition()` |
| G-1b | Replicate, and non-probability naming replicate weights | The same `expect_no_condition()` on a filtered replicate design carrying no FPC, and on a filtered non-probability design that names replicate weights |
| G-1c | Two-phase | **Not** `expect_no_condition()`. Assert instead that no condition whose class matches `^surveycore_` fires. The technique: capture every condition the call signals, take each condition's `class` vector, and assert that no element of any of them matches `^surveycore_`. This tolerates the untyped `survey` warnings by construction, because they carry no surveycore class |
| G-2 | Non-probability naming no replicate weights | `surveycore_warning_nonprob_srs_conversion` fires exactly once, and no other condition fires. Filtering must not double the warning or suppress it |
| G-3 | Replicate, carrying an FPC column | `surveycore_warning_replicate_fpc_dropped` fires exactly once on a **filtered** design, and no other condition fires. The row pairs with G-1b, which uses a replicate design carrying no FPC so that `expect_no_condition()` can be used at all, and therefore never reaches this warning. Capture with `expect_warning(sv <- ..., class = "surveycore_warning_replicate_fpc_dropped")` and read the result off the return value. Add no snapshot: the file already holds the golden copy of that message |

G-3 covers the one warning the arc's changed code path would otherwise never
raise in a filtered test. The restriction enters `.as_svydesign_replicate()`,
which is the function that fires
`surveycore_warning_replicate_fpc_dropped`; measured, the warning fires at
`R/methods-conversion.R:347-368` and `survey::svrepdesign()` — the call whose
value the restriction wraps — is the last expression of the function at line
370, so the warning precedes the restriction structurally. The row pins that
ordering rather than discovering it. It mirrors G-2, which makes the same
"exactly once, and nothing else" claim for the other warning on the arc.

G-1c is the row the two-phase B rows point at. It exists because
`expect_no_condition()` cannot be used on that route at all: the conversion
already emits one untyped `survey` condition today, and a domain that thins a
stratum to one PSU emits a second one. Both are `simpleWarning` objects with no
class of their own, so a class-pattern assertion separates surveycore's silence
from `survey`'s noise without depending on which of the two fires.

The `.claude/rules/testing-standards.md` rule against hand-rolled condition
handlers covers capturing an **expected** warning, which `expect_warning()`
already does. G-1c asserts the absence of a whole family of classes, and no
`expect_*()` helper expresses that. Prefer an `expect_*()` composition if one
asserts it. Either way the row's claim is the one stated above.

### Invariants

`tests/testthat/test-conversion.R` already calls `test_invariants()` for three
of the four constructors, per the once-per-constructor-per-file rule in
`.claude/rules/testing-surveycore.md`: for `as_survey()` at two places near the
top of the file, for `as_survey_replicate()` in the replicate FPC section, and
for `as_survey_nonprob()` in the first block of the non-probability section,
whose comment states it is the file's only call for that constructor.

- Add **no** `test_invariants()` call for `as_survey()`, `as_survey_replicate()`
  or `as_survey_nonprob()`. Those are covered and a fourth call would duplicate.
- Add **one** call for `as_survey_twophase()`, in the first new two-phase block
  (B-1). The file exercises that constructor and carries no invariant call for
  it, so this closes the gap at the cost of one call and creates no duplicate.
  Do not add a second one in B-2, B-3 or B-4.

### Input modes

The both-modes rule does not apply. `as_svydesign()` and `as_tbl_svy()` accept a
survey design object and nothing else, so no row has a second mode to run.

## Coverage of the measured findings

Every measured finding gets a row or a reason.

| Finding | Where it lands |
|---|---|
| F1 — the restriction operator must preserve the stored call | F-1, F-2, F-3, F-4. F-1 is the named guard |
| F2 — the two-phase marker vector comes off the converted object, not the design's data | B-1 and B-3. A route that read the wrong vector raises an unclassed subscript error, so both rows fail loudly rather than quietly |
| F3 — the issue's two-phase criterion is unmeetable, and this change is not why | B-1 and B-2, which replace it. Out of scope by decision: any row comparing the two-phase route to `get_means()`. Issue #261 carries the underlying gap |
| F4 — an unfiltered design carries no marker column | C-1 to C-5, each asserting the column's absence from the converted object |
| F5 — an all-`FALSE` marker returns zeros rather than an error, on the Taylor route | D-2a, and D-5a for the all-`NA` equivalent |
| F6 — the chosen operator does not resolve `NA` and the replaced one did | D-4, D-5a and D-5b |
| F7 — `as_tbl_svy()` inherits the defect today | E-1 and E-2 |
| F8 — the two-phase route does not remove rows; it sets excluded probabilities to infinity | B-3, which asserts the count of finite probabilities and not the row count. D-2c and D-5b carry the same shape for an empty domain |
| F9 — an empty domain gives 0 with a zero SE only on the Taylor route | D-2a, D-2b, D-2c and D-2d, one per route group. The replicate route errors inside `survey`; the two-phase route answers `NaN` |
| F10 — a factor marker column built a corrupt object before coercion | D-6a, D-6b and D-6c, alongside the integer row D-6. D-6b is the one that guards the corrupt-object path, by asserting every probability is finite |
| F11 — `[.twophase` can warn about single-PSU strata, untyped | G-1c, which asserts the absence of surveycore classes rather than the absence of conditions. No row asserts that warning's absence, and no row triggers it on purpose |

## Existing rows whose assertions change

**None.** Measured on this branch: no block in
`tests/testthat/test-conversion.R` builds a filtered design. The file contains
no occurrence of `filter`, of the marker column name, or of `surveytidy`.
Every existing block that asserts a converted object's row count or its
variables does so on an unfiltered design, whose behaviour this change leaves
alone:

- the row-count row and the column-preservation row in the data-preserved
  section, both on the unfiltered Taylor fixture;
- the `as_tbl_svy()` row-count row, on the same fixture;
- the replicate-column row in the non-probability section, which counts
  analysis weight columns on an unfiltered design.

The two other test files that call these functions also pass unfiltered
designs: the dataset-metadata file builds its designs from a metadata fixture,
and the compat file's conversion row compares the converted object's dimensions
against an unfiltered design's stored frame.

So no existing assertion loosens and no existing assertion changes. Every new
assertion arrives in a new block. If the tester finds a failing pre-existing
block, that is a finding to report and not an assertion to relax.

## Tolerances

- Point estimates: 1e-10
- SE / variance: 1e-8
- CI bounds: 1e-6
- Deviations: none. The preflight measured agreement to every printed digit on
  the four routes with the standard oracle, and the two-phase rows compare a
  restricted object against a hand-restricted one, which is the same
  computation on the same rows.

Use `expect_equal()` with the tolerance for every numeric comparison, and
`expect_identical()` for row counts, column names and `@variables` values, per
`.claude/rules/testing-standards.md`.

## Profile gates

- [ ] devtools::document() clean
- [ ] devtools::test() all pass
- [ ] devtools::run_examples() all pass
- [ ] R CMD check --as-cran (0 err, 0 warn, notes reviewed)
- [ ] pkgdown::build_site() clean
- [ ] covr::package_coverage() ≥ 95% (target 98%)
- [ ] CRAN cookbook scan clean (see r-package-profile.md)

Measure coverage with `NOT_CRAN=true`, per
`.claude/rules/testing-surveycore.md`. Run the full suite before any push.
