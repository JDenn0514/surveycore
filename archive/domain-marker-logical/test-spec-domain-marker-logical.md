# Test-spec — domain-marker-logical

**Status**: DRAFT
**Date**: 2026-09-12
**Source**: GitHub issue #262

---

## Reference oracle

**None.** This change adds a type check and removes an `NA` from a row mask.
It changes no estimator and no formula. There is no external package whose
output is the ground truth here, and no oracle row belongs in this plan. Do
not invent one.

Two kinds of row carry the burden instead:

- A typed-condition row. The named error class is raised, or it is not.
- A self-comparison row. Two designs that differ only in `NA` against `FALSE`
  on one marker row must return the same numbers.

The `survey` package still appears, but only as the target of the conversion
rows. It is not an oracle there either — those rows assert a row count and a
domain restriction, not a numerical agreement.

---

## Datasets

| Data | Purpose |
|---|---|
| `make_survey_data(seed = N)` from `tests/testthat/helper-test-data.R` | Every row in this plan. Columns `psu`, `strata`, `fpc`, `wt`, `y1`, `y2`, `y3`, `group`. |
| `make_all_designs(seed = N)` from the same file | The four-class rows. It returns one design per concrete class, plus an SRS design. |
| Inline edge data | The zero-row frame, the attribute-carrying column and the `haven_labelled` column. Build them in the block, per `.claude/rules/testing-standards.md`. |

No real dataset is needed. `nhanes_2017` and `acs_pums_wy` exist for
numerical validation against a reference implementation, and this plan has no
such row.

---

## Fixture helpers

Two fixture builds repeat across about thirty blocks. Write each one once, as
a named helper. Do not inline either build.

The house rule has two cases. A helper that one test file uses is defined at
the top of that test file. A helper that two or more test files use goes in
`tests/testthat/helper-test-data.R`.

The second case applies to both helpers here, so both go in
`tests/testthat/helper-test-data.R`, beside `make_survey_data()` and
`make_all_designs()`. `set_domain_marker()` serves section 1, section 2 and
row E.4, which sit in two files. `make_domain_pair()` serves sections 3, 4 and
5, which sit in three files.

**`set_domain_marker(design, type, mask = NULL)`** — returns the design with a
domain marker column written to its data.

- `design` — any design object.
- `type` — one of `"logical"`, `"integer"`, `"double"`, `"character"`,
  `"factor"` or `"list"`. The helper builds a column of that storage type from
  `mask` and writes it.
- `mask` — the logical mask to start from. When `NULL`, the helper builds one
  from `y1` above its median, which gives both `TRUE` and `FALSE` values.
- When `type` is `"logical"` the helper writes `mask` as given, attributes and
  all. Every other `type` is a conversion, so attributes do not survive.
- That `"logical"` path also carries row 2.5's label attribute and row 2.9's
  `haven_labelled` class. Both columns are built in their own block and handed
  to the helper as `mask`. Add no type and no argument to the helper for
  either: edge-case data is built in the block
  (`.claude/rules/testing-standards.md`).
- The write itself is the act under test in sections 1 and 2. When the write
  aborts, the helper aborts. `expect_error()` around the helper call is the
  intended shape.

Added by the PR that carries section 1.

**`make_domain_pair(class = "taylor", seed = 42)`** — returns a list with
three elements.

- `a` — a design whose marker column holds `NA` in one place that would
  otherwise be `TRUE`.
- `b` — the same design, with `FALSE` in that same place.
- `mask` — the resolved logical mask: `NA`-free, `TRUE` for an in-domain row.
  `sum(mask)` is the in-domain row count both designs must agree on.

`class` names the design class to build: `"taylor"`, `"replicate"`,
`"twophase"` or `"nonprob"`.

`a` and `b` differ in exactly one element of the marker column, and in nothing
else.

Added by the PR that carries section 3. The PR that carries sections 4 to 6
reads it and does not change it.

---

## Conditions layer

The new error comes from an S7 class validator. That is Layer 1 in
`.claude/rules/testing-surveycore.md`. **Test it with
`expect_error(class = ...)` only. Write no snapshot for it.** Layer 1
messages are not held to the CLI snapshot contract.

---

## Which PR carries which section

The work ships as three PRs. Each section below belongs to exactly one of
them. A PR's tests land with that PR and with no other.

| PR | Sections | Rows |
|---|---|---|
| 1 | §1, §2, and the four existing blocks in §Existing blocks that change | 24 |
| 2 | §3 | 9 |
| 3 | §4, §5, §6 | 13 |

The numbers in this table are the spec's three PRs. The implementation plan
splits the same sections six ways and keeps its own map. Read the plan for the
six-way split; this table stays on the spec's numbering.

PR 1 runs first, PR 2 second, PR 3 third. PR 3's §4 asserts that the printed
domain count agrees with the count the analysis functions use, and PR 2
changes that count, so §4 cannot run before PR 2 lands.

**Two PRs sit over the 12-row bound: PR 1 at 24 rows and PR 3 at 13.** The
count is recorded, not hidden. Read §Row count per PR at the end of this
document for what each PR holds.

---

## Per-function test plan

### 1. The type check on the domain marker column — PR 1

Every row here asserts the class `surveycore_error_domain_not_logical`, with
`expect_error(class = ...)` and nothing else.

The write under test is an assignment of a data frame to a design's data. Use
`set_domain_marker(design, type)` for that write — the helper reads the data
out, puts a marker column of the named type on it, and assigns it back. The
assignment is the line that must abort, so the helper call is what
`expect_error()` wraps. Do not inline the three steps in any block.

| # | Marker column type | Design | Assert |
|---|---|---|---|
| 1.1 | `integer` (0 and 1) | Taylor | raises `surveycore_error_domain_not_logical` |
| 1.2 | `integer` (0 and 1) | Replicate | raises the class |
| 1.3 | `integer` (0 and 1) | Two-phase | raises the class |
| 1.4 | `integer` (0 and 1) | Non-probability | raises the class |
| 1.5 | `double` (0 and 1) | Taylor | raises the class |
| 1.6 | `character` (`"TRUE"` / `"FALSE"`) | Taylor | raises the class |
| 1.7 | `factor` (levels `"yes"` and `"no"`) | Taylor | raises the class |
| 1.8 | `list` column | Taylor | raises the class |

Rows 1.1 to 1.4 prove the check reaches all four concrete classes from one
place. Rows 1.5 to 1.8 prove it is a type check and not a value check: a
double `0`/`1` column and a character `"TRUE"` column both look convertible
and both are rejected.

| # | Scenario | Assert |
|---|---|---|
| 1.9 | A data frame that already carries an integer marker column, passed to the Taylor constructor | the constructor raises `surveycore_error_domain_not_logical` |
| 1.10 | The same data frame passed to the non-probability constructor | raises the class |
| 1.11 | After a failed assignment of a bad marker column, read the design's data back | the design is unchanged: its data holds no marker column |

Row 1.11 pins that a rejected write leaves nothing behind.

### 2. The type check accepts a legal column — PR 1

Every row here asserts that no condition of class
`surveycore_error_domain_not_logical` is raised. Assert that, and not the
absence of every condition — another validator on the same object may speak
for its own reasons.

Use `set_domain_marker()` for the write in every row.

Two per-block requirements apply here. Rows 2.6 and 2.7 build their zero-row
frame inline. Row 2.9 calls `skip_if_not_installed("haven")` inside its block,
because `haven` is in Suggests
(`.claude/rules/testing-surveycore.md`).

| # | Marker column | Design | Assert |
|---|---|---|---|
| 2.1 | logical, no `NA` | Taylor | no `surveycore_error_domain_not_logical` |
| 2.2 | logical, one `NA` | Taylor | no `surveycore_error_domain_not_logical` |
| 2.3 | logical, all `NA` | Taylor | no `surveycore_error_domain_not_logical` |
| 2.4 | logical, all `NA` | Replicate | no `surveycore_error_domain_not_logical` |
| 2.5 | logical carrying a `label` attribute | Taylor | no `surveycore_error_domain_not_logical`; the attribute survives the write |
| 2.6 | `logical(0)`, on a zero-row data frame | Taylor | no `surveycore_error_domain_not_logical` |
| 2.7 | `integer(0)`, on a zero-row data frame | Taylor | raises `surveycore_error_domain_not_logical` |
| 2.8 | logical, one `NA` | Two-phase | no `surveycore_error_domain_not_logical`; the design's own subset column is untouched |
| 2.9 | logical carrying the `haven_labelled` class, built inline | Taylor | no `surveycore_error_domain_not_logical`; the stored column reads back as a plain logical vector, with the class gone |

Row 2.9 is an accept row with a second observable. The write strips the
`haven_labelled` class before the type check reads the column, so a column that
arrives with the class stored reads back plain. Build the column in the block:
take a logical mask and attach the class and its labels attribute to it. Hand
that column to `set_domain_marker()` as `mask`, with `type` `"logical"` — that
path writes `mask` as given, so the helper needs no new type and no new
argument. Assert two things: the write raises no
`surveycore_error_domain_not_logical`, and the column read back out of the
design is logical and carries no class attribute.

Rows 2.6 and 2.7 are a pair. They prove the check reads the type and not the
length. Build the zero-row frame by taking a design's data and keeping no
row. Assert on the named class only — a zero-row design may draw other
conditions and those are not what these two rows test.

Row 2.5 also pins that the write keeps the attribute. A logical column that
carries a label is still a logical column.

Row 2.8 is the two-phase accept path. The two-phase class carries its own
logical check on a different column, so this row also proves the two checks do
not collide. The non-probability class sees the reject path in rows 1.4 and
1.10 and no accept-path row. One accept row per branch of the check is the
bar here: the check reads no class-specific state, so a second class proves
what a third would repeat.

### 3. An `NA` marker row and a `FALSE` marker row give the same answer — PR 2

One fixture serves every row in this section but 3.9. Call
`make_domain_pair()` for it. Row 3.9 builds its own zero-row design in the
block, because no pair of designs is needed to read a mask of length zero.
Design A holds `NA` in one marker element that would otherwise be `TRUE`;
design B holds `FALSE` in that same element. The two differ in nothing else.
Every function below must return the same numbers on both.

Assert **column by column**, with `expect_identical()`. Do not compare the
two result objects whole: each one stores the call that produced it, and the
two calls differ.

| # | Function | Call shape | Assert |
|---|---|---|---|
| 3.1 | `get_means()` | grouped by `group` | every column identical between A and B |
| 3.2 | `get_quantiles()` | grouped by `group` | every column identical |
| 3.3 | `get_diffs()` | `y1` by `group` | every column identical |
| 3.4 | `get_t_test()` | `y1` by a two-level column built inline | every column identical |
| 3.5 | `get_pairwise()` | `y1` by `group` | every column identical |
| 3.6 | `survey_glm()` | `y1 ~ y2` | the coefficient table is identical |

Each row is its own `test_that()` block, and each description names one
function and one observable, per `.claude/rules/testing-standards.md`.

Row 3.6 compares the cleaned coefficient table, not the fit object. The fit
object holds the call and the design.

| # | Scenario | Assert |
|---|---|---|
| 3.7 | Grouped `get_means()` on design A | the returned group values are all real levels of `group`; no row carries an `NA` group value that no in-domain row supports |
| 3.8 | All-`NA` marker column, ungrouped `get_means()` | the result is the empty-domain result, the same one the design gives when the marker is all `FALSE` |
| 3.9 | A design whose data holds no row, carrying a `logical(0)` marker column | the resolved domain mask is `logical(0)`: a logical vector of length zero, not `NULL` and not `TRUE` |

Row 3.7 names the defect from issue #262 directly: a phantom row. An `NA`
element in the mask used to produce an all-`NA` row, and a grouped call used
to report that row as a group.

Row 3.9 asserts the mask itself. Rows 2.6 and 2.7 build a zero-row frame too,
and they assert what the **write** does — whether the type check fires on the
column. Row 3.9 starts after a write that passed and asserts what the **mask
helper returns** from the stored column. Two different acts, two different
functions, one shared fixture shape.

Two notes for the block:

- Build the zero-row design inline, the same way rows 2.6 and 2.7 build their
  frame: take a design's data and keep no row.
- Call `.apply_domain()` on the design and assert on its return value. This is
  the one row in the section that reads the mask directly; rows 3.1 to 3.8
  reach it through a public analysis function. An analysis call on a zero-row
  design can raise for reasons of its own, and those reasons are not what this
  row tests.

#### Six functions, not thirteen

An earlier draft ran this check over thirteen functions. Seven are cut:
`get_totals()`, `get_freqs()`, `get_ratios()`, `get_corr()`,
`get_covariance()`, `get_variance()` and `get_effective_n()`. All seven read
the row mask through the same one-line call as `get_means()`, and none of them
holds any `NA`-sensitive logic of its own before it indexes. The six kept rows
reach every code path the seven would have reached.

What the cut stops catching: a caller-specific regression, where one of those
seven functions stops calling the shared helper and reads the raw marker
column instead. No test row covers that regression once the seven rows go.

A source sweep catches it instead, and it is a gate on the package source, not
a test row. It counts the source files that name the marker column at all, and
it fails when a new one appears. The sweep belongs to the quality gates and not
to the tester, in the same way as the source-side sweep named under
§Test-suite sweep.

The gate this relies on did not exist when the rows were cut. It was added in
the same pass. Read the quality gates and confirm the sweep is there before you
treat this paragraph as settled.

`get_anova()` gets no row for the same reason. It builds its statistics from
repeated `survey_glm()` fits, and row 3.6 covers `survey_glm()`. Its refit
guard compares one stored marker column against another for identity; it
consumes no mask.

The five kept function rows beyond `get_means()` each earn their place:

- `get_quantiles()` — the existing-block repairs already touch this area, so
  it earns extra scrutiny.
- `get_diffs()` — it passes the mask on to a second helper that builds the
  output table, rather than indexing with it in place.
- `get_t_test()` and `get_pairwise()` — both build bespoke mask combinations
  rather than reading the shared mask as-is.
- `survey_glm()` — the base case every model-fitting function rests on.

### 4. The printed domain line agrees with the analysis count — PR 3

Call `make_domain_pair()` for the fixture. Design A is the `NA` design and
design B is the `FALSE` design.

| # | Scenario | Assert |
|---|---|---|
| 4.1 | Taylor design A; print it | the printed line reads `Domain: n of N`, where `n` is the count of `TRUE` elements and `N` is the row count |
| 4.2 | The same design | the `n` reported by the printed line equals the `n` column of an ungrouped `get_means()` on `y1` for that design |
| 4.3 | Taylor design B; print it | the printed line is identical to the line from row 4.1 |
| 4.4 | Two-phase design A, whose phase-2 subset excludes some rows; print it | the printed line counts phase-2 rows only: `n` is the count of `TRUE` marker elements among the phase-2 rows, and `N` is the phase-2 row count. Printing two-phase design B gives the identical line. |

Row 4.4 covers a second route through the print line. A two-phase design
counts the marker column over its phase-2 rows alone, and the other three
classes count it over every row. Build the fixture so that at least one
in-domain row sits outside phase 2, or the two routes give the same number and
the row proves nothing.

Capture the printed output. Assert on the numbers in the line, not on a
snapshot of the whole print method — the print method carries many other
lines and this plan does not own them.

### 5. Conversion to a `survey` package design — PR 3

Every block in this section calls `skip_if_not_installed("survey")` inside
the block, per `.claude/rules/testing-standards.md`.

Rows 5.2 to 5.4 take their `NA` design from `make_domain_pair()`, one class
per row. `sum(mask)` from the same call gives the expected count.

| # | Scenario | Assert |
|---|---|---|
| 5.1 | Taylor design with a logical marker, converted with `as_svydesign()` | the converted object holds only the in-domain rows |
| 5.2 | Taylor design whose marker holds one `NA` row, converted | the `NA` row is not in the converted object; the row count equals the count of `TRUE` elements |
| 5.3 | Two-phase design whose marker holds one `NA` row, converted | the row count does not change; the count of finite probabilities equals the count of `TRUE` elements |
| 5.4 | Replicate design whose marker holds one `NA` row, converted | the `NA` row is not in the converted object |
| 5.5 | A design with no marker column, converted | every row survives; the conversion raises nothing |

Rows 5.2 to 5.4 restate a behaviour that already holds. They are regression
rows: the coercion that used to sit in front of this mask is gone, and these
rows prove its removal changed nothing about how an `NA` marker is read.

### 6. A design with no marker column is unchanged — PR 3

| # | Scenario | Assert |
|---|---|---|
| 6.1 | Taylor design straight from the constructor, ungrouped `get_means()` | the result matches the result from before this change: every row is in the estimate |
| 6.2 | The same design, grouped `get_means()` | one row per level of `group` |
| 6.3 | The same design, printed | the output holds no `Domain:` line |
| 6.4 | Assign a data frame with no marker column to the design's data | no condition is raised |

Row 6.4 is the common path. Most designs never carry the column, and the
check must cost them nothing and say nothing.

---

## Existing blocks that change — PR 1

Four existing blocks write a non-logical marker column. All four fail the
moment the check lands. All four change in PR 1, with the validator.

| # | File | Block | Change |
|---|---|---|---|
| E.1 | `tests/testthat/test-analysis-quantiles.R` | `get_quantiles() respects domain filter` | It wraps the mask in `as.integer()`. Drop the wrapper and write the logical mask. Its assertion — the domain estimate differs from the full-sample estimate — must still hold. |
| E.2 | `tests/testthat/test-analysis-quantiles.R` | `get_quantiles() empty domain (n = 0) returns NA estimate` | It wraps an all-`FALSE` mask in `as.integer()`. Drop the wrapper. Its two assertions — an `NA` estimate and `n = 0` — must still hold. |
| E.3 | `tests/testthat/test-conversion.R` | `as_svydesign() reads an unconvertible marker as an empty domain` | It writes a factor with levels `"yes"` and `"no"`, then converts and expects an empty domain. Under the check, the assignment aborts before the conversion runs. Rewrite the block so it asserts `surveycore_error_domain_not_logical` on the assignment, and rename it for what it now asserts. Its old premise is gone: a factor marker no longer reaches the conversion at all. |
| E.4 | `tests/testthat/test-conversion.R` | `as_svydesign() selects the same rows for every marker column type` | It loops a five-element list of markers — logical, integer, double, character, factor — and for each one writes the column, converts, and expects no condition. Four of the five iterations now abort at the write. Rewrite as described below, and rename the block for what it now asserts. |

**E.4, in detail.** Keep the loop and keep the five types.

- The logical iteration keeps both of its current assertions: the converted
  object holds `sum(mask)` rows, and its probability vector is numeric with a
  finite value for every retained row.
- Each of the four non-logical iterations asserts
  `surveycore_error_domain_not_logical` at the write, and asserts nothing
  about a converted object. No conversion runs on those four.
- The block's name says what it now asserts: one legal marker type converts,
  and four illegal ones abort at the write.
- The comment above the block states the premise this work removes — that
  nothing guarantees the column is logical and no validator checks its type.
  Replace it.

Two neighbouring blocks in `tests/testthat/test-conversion.R` write an `NA`
marker. Both are already logical. Neither changes.

> **Measured, 2026-09-12, corrected.** These **four** are the only
> non-logical writers among the fourteen test files that touch the marker
> column. An earlier count said three and missed E.4. The sweep was
> `grep -rn "SURVEYCORE_DOMAIN_COL\]\] <-" tests/testthat/`, and E.4's write
> assigns a variable, so its type is not visible in the grep output. Do not
> re-run the sweep to decide what to change; do run it at the end, as the
> test-suite sweep below.

---

## File placement

No new test file is created.

| Rows | File | PR |
|---|---|---|
| 1.x, 2.x | `tests/testthat/test-s7-classes.R` | 1 |
| E.1, E.2 | `tests/testthat/test-analysis-quantiles.R` | 1 |
| E.3, E.4 | `tests/testthat/test-conversion.R` | 1 |
| `set_domain_marker()` | `tests/testthat/helper-test-data.R` | 1 |
| 3.x | `tests/testthat/test-analysis-helpers.R` | 2 |
| `make_domain_pair()` | `tests/testthat/helper-test-data.R` | 2 |
| 4.x | `tests/testthat/test-methods-print.R` | 3 |
| 5.x | `tests/testthat/test-conversion.R` | 3 |
| 6.x | `tests/testthat/test-analysis-helpers.R` | 3 |

Section 3 holds six functions and one shared behaviour. The behaviour under
test is the row mask all six share, not each function's own contract, so the
rows sit together in one file rather than one row per analysis test file. Each
row is still its own block.

`tests/testthat/test-conversion.R` and `tests/testthat/test-analysis-helpers.R`
each take rows from two PRs. The three PRs run in order, so no two of them
write the same file at the same time.

---

## Invariants

`test_invariants(design)` runs **once per constructor per test file**, in the
first block that builds with that constructor
(`.claude/rules/testing-surveycore.md`).

No file in this plan is new, and every file listed above already calls the
helper at least once. **Add no new `test_invariants()` call.** Adding one to a
later block in a file that already has one is the pattern issue #169 removed.

**One file carries a pre-existing gap, measured 2026-09-12.**
`tests/testthat/test-s7-classes.R` calls `test_invariants()` six times, for
the Taylor constructor and the non-probability constructor only. It never
calls the helper for a replicate design or a two-phase design, though it
builds both repeatedly. New rows 1.2, 1.3, 2.4 and 2.8 build exactly those two
classes, so the earlier claim — that every file already calls the helper for
the constructors it uses — was false for this file.

**Do not close the gap here.** It predates this work, and the two missing
calls sit outside the stated write surface. Record it and move on.

---

## Input modes

The both-modes rule does not reach this plan. It applies to the functions
that accept either a design object or a plain data frame — the
dataset-metadata set. Every function in this plan takes a design object only.
Every row runs in one mode. Name no mode.

---

## Tolerances

| Quantity | Tolerance |
|---|---|
| Point estimates | 1e-10 |
| SE / variance | 1e-8 |
| CI bounds | 1e-6 |

**Deviation, section 3: use `expect_identical()`, not a tolerance.**
Justification: design A and design B resolve to the same row mask, element
for element. The two calls then run the same code over the same rows with the
same weights, so every number is bit-identical. A tolerance would let a real
difference through. This is the one section that departs from the table
above, and it departs by tightening.

Sections 1, 2, 5 and 6 assert classes, row counts and structure. No tolerance
applies to them.

Section 4 asserts integer counts. Compare them with `expect_identical()`.

---

## Row count per PR

Counted after the section-3 cut, the two rows added in the Pass 1 review, and
the two rows added in the plan review — 2.9 and 3.9. The bound is 12 rows per
PR. The PR numbers are the spec's three; the implementation plan carries the
six-way split that brings every entry inside the bound.

| PR | Sections | Rows | Count | Inside the bound |
|---|---|---|---|---|
| 1 | §1 | 1.1 to 1.11 | 11 | |
| 1 | §2 | 2.1 to 2.9 | 9 | |
| 1 | §Existing blocks | E.1 to E.4 | 4 | |
| **1 total** | | | **24** | **No — 12 over** |
| 2 | §3 | 3.1 to 3.9 | 9 | |
| **2 total** | | | **9** | **Yes** |
| 3 | §4 | 4.1 to 4.4 | 4 | |
| 3 | §5 | 5.1 to 5.5 | 5 | |
| 3 | §6 | 6.1 to 6.4 | 4 | |
| **3 total** | | | **13** | **No — 1 over** |

Total: 46 rows. The earlier draft held 48 in one PR.

Two facts about PR 1's 24 rows, for whoever sizes the work next:

1. Eighteen of the 24 are one-line typed-condition rows over one shared
   fixture helper. Rows 1.1 to 1.8 differ only in the marker type and the
   design class.
2. The four existing blocks cannot move to another PR. They fail on the line
   that adds the validator.

PR 3's 13 rows sit one over the bound. Sections 5 and 6 both restate
behaviour that already holds, as regression cover for the removed coercion.

---

## Profile gates

Every PR runs all seven.

- [ ] devtools::document() clean
- [ ] devtools::test() all pass
- [ ] devtools::run_examples() all pass
- [ ] R CMD check --as-cran (0 err, 0 warn, notes reviewed)
- [ ] pkgdown::build_site() clean
- [ ] covr::package_coverage() ≥ 95% (target 98%)
- [ ] CRAN cookbook scan clean (see r-package-profile.md)

Two notes on running them.

1. Measure coverage with `NOT_CRAN=true`. `covr` does not set the variable,
   and without it eleven files skip and the figure reads several points low
   (issue #159).
2. Read gate 4's "0 warnings" as "no new warning". Clean `develop` already
   emits pre-existing AAPOR small-cell warnings during the test run.

### Test-suite sweep

Run this at the end of PR 1, after the four existing blocks are repaired:

```
grep -rn "SURVEYCORE_DOMAIN_COL\]\] <-" tests/testthat/
```

Every hit must write a logical vector. Four hits write a non-logical column
before the repair. A hit that assigns a variable hides its type, so read the
block rather than the grep line.

The equivalent sweep over the package source is a quality gate on the source,
not a test row. It does not belong to the tester.
