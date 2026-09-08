# Test-spec — design-dim (issue #203)

**Status**: DRAFT
**Date**: 2026-09-04

## What is under test

Five base-R size functions, on five surveycore classes.

`dim()`, `nrow()`, `ncol()`, `NROW()` and `NCOL()` must report the size of a
survey design object. On the four design classes — `survey_taylor`,
`survey_replicate`, `survey_twophase`, `survey_nonprob` — they must return
the row count and the column count of the data frame the design stores. On
`survey_collection` all five must raise
`surveycore_error_collection_no_dim`.

Only `dim()` is a generic. `nrow()` and `ncol()` are not: base R defines them
as `dim(x)[1L]` and `dim(x)[2L]`. `NROW()` and `NCOL()` read `dim()` too, and
fall back to `length(x)` only when `dim(x)` is `NULL`. **Testing `dim()`
alone would leave four of the five functions unverified, and those four are
the ones a user actually calls.** Every behavioural row below therefore runs
all five function names, not one.

Before this change, on a design, `dim()`, `nrow()` and `ncol()` returned
`NULL`, and `NROW()` and `NCOL()` returned `1L`. On a collection, `dim()`,
`nrow()` and `ncol()` returned `NULL`, `NROW()` returned the member count and
`NCOL()` returned `1L`.

## Reference oracle

There is no external oracle. Nothing is estimated and nothing is
approximated, so the `survey` package plays no part here.

The oracle is surveycore's own exported data accessor. For any design `d`
built from a frame `df`:

| Quantity | Oracle |
|---|---|
| Expected `dim(d)` | `dim(survey_data(d))` |
| Expected `nrow(d)` and `NROW(d)` | `nrow(survey_data(d))` |
| Expected `ncol(d)` and `NCOL(d)` | `ncol(survey_data(d))` |

Assert against the accessor rather than against a hardcoded number wherever a
constructor may add or reshape a column. Where the constructor is known to
pass the frame through unchanged, also assert against `dim(df)` — two
independent oracles agreeing is worth the extra line.

## Datasets

| Data | Purpose |
|---|---|
| `make_survey_data(seed = N)` | Every behavioural row. Vary the seed per block. |
| `make_survey_data(design = "replicate", ...)` | The replicate-design rows. |
| `make_survey_data(design = "twophase", ...)` | The two-phase rows. |
| Inline frames built in the test block | The edge-case rows that need a specific atypical shape: the two-row design, the rejected one-row frame, the equal-weight design with no strata and no ids, the frame with no weight column at all, the one-member collection, the grouped collection. Build these inline; never add a parameter to the generator. |
| A design reshaped after construction | The one-row row and the hidden-column row. Build with `make_survey_data()` or an inline frame, then assign to the design's `data` property or its visible-variable entry inside the block. Neither state is reachable through a constructor. |

No real dataset is needed. `nhanes_2017` and `acs_pums_wy` exist for
numerical validation against a reference implementation, and there is no
numerical estimate here to validate.

## Test file

All rows go in `tests/testthat/test-methods-compat.R`, which already holds
the blocks for the column-name method. Extend it; do not create a new file.

The error rows create `tests/testthat/_snaps/methods-compat.md`. That file
must be written and committed with LF line endings. `.gitattributes` already
enforces this for `tests/testthat/_snaps/*.md`; confirm the new file did not
land with CRLF, because every later test run would then report the whole
snapshot directory as modified with no content change.

## Input modes

The both-modes rule does not apply to any row in this document. These
functions accept a survey object or a collection; they do not have a
plain-data-frame mode. Every row runs once.

---

## Per-function test plan

### `dim()`, `nrow()`, `ncol()`, `NROW()`, `NCOL()` — the four design classes

**Happy path.** One block per class. Each block builds one design and asserts
all five function names against the accessor oracle.

| # | Class | Constructor | Asserts |
|--:|---|---|---|
| A1 | `survey_taylor` | `as_survey()` with ids, weights, strata | `dim()` identical to `dim(survey_data(d))`; `nrow()` and `NROW()` identical to `nrow(survey_data(d))`; `ncol()` and `NCOL()` identical to `ncol(survey_data(d))` |
| A2 | `survey_replicate` | `as_survey_replicate()` with BRR replicate weights | the same five |
| A3 | `survey_twophase` | `as_survey_twophase()` over a first-phase design | the same five |
| A4 | `survey_nonprob` | `as_survey_nonprob()` with a calibrated weight column | the same five |

Use `expect_identical()` throughout. Every value here is an integer count or
a length-2 integer vector; nothing is floating point.

**Return type and shape.** In the `survey_taylor` block, add:

| # | Asserts |
|--:|---|
| A5 | `dim(d)` has length 2 |
| A6 | `dim(d)` is an integer vector — assert the type, not just the values |
| A7 | `dim(d)` is not `NULL`. State this row explicitly. `NULL` is the exact defect under repair, and an `expect_identical()` against a correct value would also pass if the whole comparison were mis-typed; a direct non-`NULL` assertion cannot. |

**Second oracle.** In the `survey_taylor` block, where the constructor passes
the frame through unchanged, also assert `dim(d)` identical to `dim(df)` for
the frame the design was built from.

**Error paths.** None. These methods raise no condition on any design class.
Do not write a row that expects one.

**Invariants.** The file must carry exactly one `test_invariants(design)`
call per constructor it exercises — four calls in total, for `as_survey()`,
`as_survey_replicate()`, `as_survey_twophase()` and `as_survey_nonprob()` —
each in the first block in the file that builds with that constructor. Do not
repeat the call in later blocks that use the same constructor. The file
currently exercises three of the four constructors in its existing blocks, so
three calls belong in existing blocks and one belongs in a new block.
`survey_collection` is not one of the four constructors and gets no
invariants call.

### `dim()`, `nrow()`, `ncol()`, `NROW()`, `NCOL()` — `survey_collection`

`surveycore_error_collection_no_dim` is a user-facing error raised by a
`cli::cli_abort()` call, which makes it a Layer 3 condition under
`testing-surveycore.md §S7 error testing layers`. It therefore gets the
**dual pattern**: a class assertion and a snapshot. Both, not either.

**Error paths — class assertions.** One block, five expectations, on a
two-member collection:

| # | Call | Asserts |
|--:|---|---|
| B1 | `dim(cl)` | `expect_error(class = "surveycore_error_collection_no_dim")` |
| B2 | `nrow(cl)` | the same class |
| B3 | `ncol(cl)` | the same class |
| B4 | `NROW(cl)` | the same class |
| B5 | `NCOL(cl)` | the same class |

B4 and B5 are not redundant with B1. Before this change `NROW()` on a
two-member collection returned `2L` and `NCOL()` returned `1L`, because both
fall back to `length()`. They are the two calls in this change that move from
a working value to an error, so they carry the highest chance of a wiring
mistake and the highest value as a regression guard.

**Error paths — snapshots.**

| # | Scenario | Asserts |
|--:|---|---|
| B6 | `dim()` on a two-member collection | `expect_snapshot(error = TRUE, ...)`. Fixes the full rendered message: the three bullets, the member count, the plural noun, and the member name in the third bullet. |
| B7 | `dim()` on a one-member collection | `expect_snapshot(error = TRUE, ...)`. The count bullet must read the singular noun — `1 survey`, never `1 surveys`. This is the whole reason the row exists; a plural-only implementation passes B6 and fails here. |
| B8 | `nrow()` on a two-member collection | `expect_snapshot(error = TRUE, ...)`. Confirms the message a user sees when they call the function they actually reach for, and confirms the non-generic wrapper does not reword or re-wrap it. |

**The third bullet must not name the caller's variable.** The fix-it bullet
tells the user to ask one member for its size. It must do so without
guessing what the user called their object; a message that shows a snippet
built around a variable named `x` is wrong for every user whose object is
named something else.

| # | Asserts |
|--:|---|
| B9 | Capture the raised condition from a collection whose members are named distinctively, then assert its message contains the first member's name. Assign that name to a local first, and assert against the local — never against a hardcoded literal repeated from the message. |
| B10 | Assert the captured message does not contain the substring `x[[`. An earlier draft of this message showed a code snippet built around an object named `x`; this row makes a revert to that form fail a test, rather than pass through a re-accepted snapshot. Write it as a plain fixed-string check on the message, not a regular expression. |

Build the collection for B9 and B10 with member names that could not appear
by accident — not `wave1` and `wave2`, which also appear in prose. Use names
the block itself defines.

**Happy path.** None for a collection. There is no input for which these five
functions return a value.

**Neighbour behaviour that must stay intact.** In the collection block:

| # | Asserts |
|--:|---|
| B11 | `length(cl)` returns the member count, unchanged |
| B12 | `names(cl)` returns the member names, unchanged |

`length()` is settled out of scope for this change, and these two rows are
what proves it stayed out. A `dim()` method that accidentally routed through
the container's length would break one of them.

---

## Edge cases

One row per edge case named in the behavioural contract.

| # | Case | How to build it | Asserts |
|--:|---|---|---|
| E1 | The smallest design a constructor will build | An inline two-row frame with a weight column. Two rows is the constructor floor: a one-row frame is rejected. | `dim()` returns `c(2L, k)` for the frame's column count `k`; `nrow()` returns `2L`; all five functions agree with the accessor |
| E1b | The constructor floor is enforced | An inline **one-row** frame passed to `as_survey()`. | The constructor raises, with `expect_error(class = "surveycore_error_single_row")`. Class assertion only — no snapshot. This error is not new in this change and its message is already snapshotted where the constructor is tested; a second snapshot of the same message would drift independently. This row is not about `dim()`: it fixes the premise E1c depends on, so a later relaxation of the floor cannot silently turn E1c into a duplicate of E1. |
| E1c | A design holding exactly one row | Build a fresh two-row design the same way as E1 — each row is its own block, so nothing carries over — then assign a one-row frame to its `data` property: `d@data <- d@data[1, , drop = FALSE]`. The assignment is accepted, because no class validator checks the row count. No suggested package is needed. | `dim()` returns `c(1L, k)`; `nrow()` and `NROW()` return `1L`; `ncol()` and `NCOL()` return `k`; all five agree with the accessor. One row is not special-cased anywhere, and this row proves it. |
| E2 | A design that gained a domain-membership column | Apply the tidy-verb domain filter to a design. Guard the block with `skip_if_not_installed()` for the tidy-verb package, which is a suggested dependency; requiring it also registers its methods. | The column count rises by the number of columns the filter adds, and the **row count does not change**. See E3 for why that is the point. |
| E3 | Domain semantics — the stored row count, not the in-domain count | The same filtered design as E2, using a condition that selects a strict subset of rows. | `nrow()` on the filtered design is identical to `nrow()` on the unfiltered design, and identical to `nrow(survey_data())` of the filtered design. **This is the expected result, not a bug.** A domain filter marks membership and keeps every row. Write the assertion so the expected value is the full sample size and add a comment in the block saying that a future change making this row fail is a change in domain semantics, not a fix. |
| E4 | A design after column selection dropped columns | Apply the tidy-verb column selection to a design, keeping the design columns. Same suggested-package guard as E2. | `ncol()` and `NCOL()` return the reduced column count and agree with the accessor; `nrow()` is unchanged |
| E5 | A design after a column was **added** | Apply the tidy-verb column-adding operation (`mutate()`) to a design. Same suggested-package guard as E2. Do not use `update_design()`: it takes design arguments only (`x`, `ids`, `weights`, `strata`, `fpc`, `repweights`, `validate`), it cannot add a data column, and passing a data-column argument raises `unused argument`. | `ncol()` and `NCOL()` rise by one and agree with the accessor; `nrow()` unchanged |
| E6 | An equal-weight design with no strata, no ids and no `fpc` | An inline frame with a constant weight column, **passed to the constructor as `weights`**. | All five functions report the frame's size. The method reads the stored frame, not the design variables. **No warning is expected and none may be captured.** The constructor's simple-random-sample fallback fires only when neither a probability column nor a weight column is supplied; this row supplies a weight column, so that branch is never entered. Do not wrap the constructor in `expect_warning()`. |
| E6b | The simple-random-sample fallback, which injects a weight column | An inline frame with no weight column and no probability column. Capture the constructor's warning with `expect_warning(d <- ..., class = "surveycore_warning_srs_no_weights")`. | `ncol()` and `NCOL()` agree with the accessor, **asserted through the accessor and not against a literal count**, because this branch adds a weight column that the input frame did not have. `nrow()` is the input frame's row count. Assert the warning class only, not its text: the message wording differs according to whether the call supplied cluster ids, while the class is the same in both branches. |
| E7 | A design with an all-`NA` column | An inline frame with one column that is entirely `NA`. | The column is counted. `dim()` does not inspect values. |
| E8 | A design with zero-weight rows among positive ones | An inline frame with some weights at zero. | All five functions report the full stored size. Zero weights do not reduce the count. |
| E9 | A one-member collection | An inline collection built from one design. | Covered for the message by B7. Also assert here that all five functions raise the typed class on a one-member collection, so the count in the message is not the only thing verified at n = 1. |
| E10 | A collection whose members hold identical shapes | Two designs built from the same frame. | Still raises the typed class. The method does not inspect member shapes, so agreement between members changes nothing. |
| E11 | A **grouped** collection | An inline collection built from two designs with a grouping column, e.g. `as_survey_collection(site_a = d1, site_b = d2, group = "cohort")`. Give each member frame a distinct value in that column. **The group column name must not be a substring of any member name, and no member name may be a substring of it.** The message embeds the first member's name, so a group column named `wave` beside members named `wave1` and `wave2` makes the absence check below fail against a correct implementation — `wave1` contains `wave`. This is the same discipline the note under B9 and B10 states, applied here. | Raises the typed class on all five functions. Also assert the rendered message does **not** contain the group column name: capture the condition, assign the group column name to a local, and assert the message does not contain that local. The grouping is not part of the shape question, so it must not leak into the message. Write it as a plain fixed-string check, not a regular expression. |
| E12 | A design whose printed columns are fewer than its stored columns | Build a design, then set its visible-variable entry to a two-element character vector of column names: `d@variables[["visible_vars"]] <- c("y1", "y2")`. This is the state the ecosystem's column-selection verb leaves behind when it keeps a design variable that variance estimation needs but the user did not select. Setting the entry directly needs no suggested package. | `ncol()` and `NCOL()` return the **full stored** column count, not `2L`, and agree with the accessor; `dim()` and `nrow()` are unchanged by the assignment. **This is the expected result, not a bug** — the same reasoning as E3, one axis over. The stored frame is what variance estimation reads, so a count that followed the print filter would under-report the data the design holds. Add a comment in the block saying a future change making this row fail is a change in print semantics, not a fix. **Assert the size functions only. Do not call `print()` on this design and do not assert its output**: the print path that honours the visible-variable entry is marked as excluded from coverage, and covering it would raise a question about that marker in a file this change does not touch. |

**A one-row design is testable, and E1c is the row that tests it.** Two
routes exist and only one works. Passing a one-row frame to a constructor
raises (E1b). Assigning a one-row frame to a built design's `data` property
succeeds, because no class validator checks the row count, and the size
functions then report one row. That route needs no suggested-package
dependency and no operation the package does not export. Prefer it over any
attempt to reach one row through a row-dropping verb.

---

## Regression rows

These assert the things the pre-implementation probe found unchanged. Each
one is here because a reader would reasonably suspect it might have moved.
Every value below was measured on both the unpatched and the patched tree and
was identical.

| # | Asserts | Why a reader suspects it |
|--:|---|---|
| R1 | `is.matrix()` and `is.vector()` return `FALSE` on all four design classes | A non-`NULL` `dim()` is the usual signal that an object is array-like. It is not enough here: these predicates are internal and read the object's real `dim` attribute, which the object does not have. This row is the guard on that distinction. `is.vector()` sits here rather than in its own row because it shares the mechanism and was measured at the same value. |
| R2 | `is.array()` and `inherits(x, "matrix")` return `FALSE` on all four design classes | Same mechanism as R1. `inherits()` reads the class attribute, which this change does not touch; folded in here for the same reason. |
| R3 | `is.data.frame()` and `is.list()` return `FALSE` on a design | A size-answering object invites the guess that it became a frame |
| R4 | `print()` output on all four design classes is unchanged | Snapshot rows for the design print output already exist elsewhere in the suite. Do not duplicate them here. Instead verify, as a gate rather than a test row, that no existing snapshot file was rewritten by this change. |
| R5 | `summary()` output on all four design classes is unchanged | Same handling as R4 |
| R6 | `print()` on a collection renders without raising | The collection print path reads each member's stored row count, not the collection's, so it never calls the raising method. Had it read the collection's, this change would break printing on every collection. Assert the call returns invisibly and emits output; the row is a smoke test, not a snapshot. |
| R7 | `length()` on a design returns `1L` | Settled out of scope. This row proves it stayed there. |
| R8 | `dimnames()` on a design returns `NULL` | No `dimnames` method was added, and a caller might expect one to follow `dim()` |
| R9 | `dim()` on the result of an analysis function returns the result's own shape | The analysis results are tibbles, not designs. A method registered too broadly would change these. Pick two analysis functions and assert their result shapes. |
| R10 | `dim()` on the result of an analysis function over a collection returns the combined result's shape | Same reason, on the dispatch path |
| R11 | The conversion route to the `survey` package still produces an object of the expected class and shape | Guard with `skip_if_not_installed("survey")`. The conversion reads the stored frame; a mis-registered method could reach it. |

R1 to R3 and R7 to R8 are cheap and go in the same block as A1, on the
Taylor design, with one additional block covering the other three classes if
that reads better than four repetitions.

### Two probes deliberately left untested

Both were measured and both moved. Neither gets a row, and the reason is
recorded here so their absence reads as a decision.

- **`apply()` on a design.** N/A. It errors both before and after — first at
  its own dimension guard, then one line later while coercing the object to a
  vector. Both are base-R errors raised inside `apply()` with no condition
  class attached, so the dual pattern has nothing to assert against, and a
  snapshot of a base-R message would break on any R release that rewords it.
  No user function ever runs in either state.
- **`rownames(x, do.NULL = FALSE)` on a design.** Untested. At the default
  `do.NULL = TRUE` it returns `NULL` before and after, which R8 already
  covers. At `do.NULL = FALSE` base R builds one name per row, so the count
  of generated names rises with this change — in the correct direction. It is
  untested because nothing in the package, its tests, its vignettes or its
  documentation passes `do.NULL = FALSE`, so a test here would pin base R's
  name-generation format rather than any behaviour this change owns.

---

## Tolerances

| Estimand | Tolerance |
|---|---|
| Point estimates | 1e-10 |
| SE / variance | 1e-8 |
| CI bounds | 1e-6 |

**Deviation, with justification: no numerical tolerance applies to any row in
this document.** Every asserted value is an integer count, a length-2 integer
vector, a logical, a character vector of names, or a condition class. Use
`expect_identical()` for all of them, per `testing-standards.md §Assertions`.
A row that reaches for `expect_equal()` with a tolerance is asserting the
wrong thing: `2` and `2L` must not compare equal here, because the contract
says these functions return integers. The table above is reproduced so the
default is on the record and the deviation is visible as a deviation.

---

## Profile gates

- [ ] devtools::document() clean
- [ ] devtools::test() all pass
- [ ] devtools::run_examples() all pass
- [ ] R CMD check --as-cran (0 err, 0 warn, notes reviewed)
- [ ] pkgdown::build_site() clean
- [ ] covr::package_coverage() ≥ 95% (target 98%)
- [ ] CRAN cookbook scan clean (see r-package-profile.md)

### Gate notes specific to this change

- **`devtools::document()` must produce no diff.** The source file under
  change carries plain `#` comments, not roxygen, and the methods attach to a
  base generic that the package registers at load time. A `NAMESPACE` or
  `man/` diff after `document()` means something outside the intended write
  surface changed.
- **No existing snapshot may be rewritten.** After a full suite run, the only
  new or modified snapshot content is the one new file the collection error
  rows create. Verify with a status check on the snapshot directory, not by
  eye. This is the strongest single regression signal available for this
  change: the pre-implementation probe ran the full suite on the unpatched
  tree and on both patched variants and got the same result on all four
  counters, with no snapshot drift.
- **FAIL 0 on the full suite is the bar, and it was already met before
  implementation.** Any failure outside the new blocks is introduced by the
  implementation, not inherited.
- **`R CMD check` is expected at 0 errors, 0 warnings, 1 note.** The single
  note reports a hidden `.git` entry at the package root, which is an
  artifact of running the check inside a git worktree. It appears on the
  clean tree too. A second note blocks.
- **Run the full suite, not the fast one, before reporting.** The fast local
  run skips eleven files. The full suite is the regression instrument for
  this change. Measure coverage with `NOT_CRAN=true`, or the skipped files
  drag the reading several points below the true figure.
