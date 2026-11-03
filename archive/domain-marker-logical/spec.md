# Spec — domain-marker-logical

**Status**: DRAFT
**Target version**: 1.1.0.9000
**PR range**: PR 1–3
**Date**: 2026-09-12
**Source**: GitHub issue #262

---

## Document purpose

This document is the source of truth for the behaviour this change delivers.
The builder implements from it.

---

## PR map

Three PRs carry the change. Each one is reviewable on its own.

| PR | Production change | Behaviour it must prove |
|---|---|---|
| 1 | The `survey_base` validator, the new error class, the row in `plans/error-messages.md`, and the repair of the four existing test blocks that break | The write of a non-logical marker column aborts on all four concrete classes. The write of a logical marker column does not abort. |
| 2 | `.apply_domain()` resolves an `NA` marker to `FALSE` | A design whose marker holds one `NA` and a design whose marker holds `FALSE` in that place return the same numbers from every analysis function. |
| 3 | `.restrict_to_domain()` cleanup, the design note above it, and the printed domain line | The printed domain count agrees with the count the analysis functions use. The conversion routes still read an `NA` marker as outside the domain. |

Dependency chain, in order:

1. PR 1 ships first. The four existing test blocks write a non-logical marker
   column. They fail on the line that adds the validator, so the validator and
   their repair cannot land apart without leaving the suite red between them.
2. PR 2 depends on PR 1. `.apply_domain()` returns the stored column as it is
   today. It can take on one job — resolve `NA` to `FALSE` — and add no
   coercion only because the validator already guarantees the type.
3. PR 3 depends on PR 2. It asserts that the printed domain line agrees with
   the count the analysis functions use, and PR 2 changes that count.

No two of the three may run at the same time. PR 1 and PR 2 each add one
fixture helper to `tests/testthat/helper-test-data.R`, and PR 3 reads the
helper PR 2 adds.

---

## Scope

### In

| Item | Change | PR |
|---|---|---|
| `survey_base` class | Gains a validator. It rejects a domain marker column that is not logical. | 1 |
| `surveycore_error_domain_not_logical` | New typed error class. Layer 1 (S7 class validator). | 1 |
| `plans/error-messages.md` | New row. It lands before any code uses the class. | 1 |
| `survey_base` roxygen | One sentence on the `data` property records the new invariant. | 1 |
| The four existing test blocks that write a non-logical marker | Repaired. They fail on the line that adds the validator. | 1 |
| `.apply_domain()` | An `NA` marker resolves to `FALSE`. No coercion. | 2 |
| `.restrict_to_domain()` | The `as.logical()` coercion goes. The `& !is.na()` guard stays. | 3 |
| The design note above `.restrict_to_domain()` | Rewritten. It states the old premise. | 3 |
| `NEWS.md` | One entry under **Breaking changes**, one under **Bug fixes**. | 1, 2 |

### Out

**Coercion inside `.apply_domain()`.** The first draft of issue #262
(2026-09-09) coerced the column with `as.logical()`. The 2026-09-12 revision
replaced it with the validator. Three reasons, recorded in the issue:

- Coercion trades one silent wrong answer for another. `as.logical()` on a
  factor with levels `"yes"` and `"no"` returns all `NA`, and an all-`NA` mask
  reads as an empty domain. The caller gets a different wrong number, still
  with no condition raised.
- The only intended external producer of the column is
  `surveytidy::filter()`, and it writes a logical vector. A column of another
  type is a programming error, not a user data problem.
- The column has four readers and two internal writers. A validator covers
  every one of them at the write. Coercion in one reader covers one reader.

The four readers and the two writers, measured 2026-09-12:

| Site | Role |
|---|---|
| `R/analysis-helpers.R:483-484` | Reader. The analysis mask helper. |
| `R/methods-conversion.R:75-79` | Reader. The conversion helper. |
| `R/methods-print.R:171-183` | Reader. The printed domain line. |
| `R/glm-anova.R:61-67` | Reader. The refit guard. |
| `R/analysis-t-test.R:314` | Writer. It assigns `active_mask` to a copy of the design. |
| `R/analysis-t-test.R:810` | Writer. It assigns `by_col %in% c(a, b) & domain_mask` to a copy of the design. |

Both writers write a logical vector, so both pass the validator unchanged.
Neither is edited.

Do not implement coercion. Do not offer it as a fallback.

**The four `as.logical(active_domain)` calls in `R/analysis-corr-latent.R`.**
All four stay. Two different reasons hold, and the reasons must not be merged:

- Lines 1295, 1378 and 1441 sit in `.corr_numerical_influence()`,
  `.corr_taylor_variance_latent()` and `.corr_replicate_variance_latent()`.
  Every call site passes `pair_active`, which is already a logical vector, so
  all three calls are no-ops today and stay no-ops after this change.
- Line 1776 sits in `.corr_latent_pair()` and reads that function's own
  `active_domain` parameter. The caller at `R/analysis-corr.R:451` runs
  `active_domain <- as.numeric(active_mask)`, so the incoming value is
  numeric. **This call is a real conversion and stays needed.** Do not delete
  it as dead code.

None of the four reads the marker column, so the verification grep in
§Quality gates does not reach them. Editing an 1800-line file to delete three
no-ops buys nothing these PRs need.

**A check on the marker column's content.** The validator tests the type. It
does not test the length, the `NA` count, or whether any value is `TRUE`.

**Any change to the thirteen call sites that read the mask.** They are the
`.apply_domain(design)` calls in `R/analysis-corr.R`,
`R/analysis-covariance.R`, `R/analysis-diffs.R`, `R/analysis-effective-n.R`,
`R/analysis-freqs.R`, `R/analysis-means.R`, `R/analysis-quantiles.R`,
`R/analysis-ratios.R`, `R/analysis-t-test.R` (two), `R/analysis-totals.R`,
`R/analysis-variance.R` and `R/glm.R`, measured 2026-09-12. The validator and
the helper fix all thirteen at one place. No call site is edited.

**Any change to `as_svydesign()`'s user documentation.** The roxygen section
`A filtered design's domain` already says the column is logical and already
says an `NA` marker counts as outside the domain. Both statements stay true.

### What this change reverses

Issue #262 describes the reversal too narrowly. Its §Fix names one test block,
the factor block at `tests/testthat/test-conversion.R:3357`. The real reversal
is wider, and PR 1 must carry all of it.

`tests/testthat/test-conversion.R:3313` holds a block that writes a marker
column of five types in a loop — logical, integer, double, character and
factor — and asserts that each one converts and selects the same rows. That
block pins a cross-type coercion contract for four wrong types. This change
removes that contract. The comment above the block states the premise the
validator deletes: "Nothing in the package guarantees the column is logical,
no validator checks its type."

Four existing test blocks write a non-logical marker column, measured
2026-09-12:

| Site | What it writes |
|---|---|
| `tests/testthat/test-analysis-quantiles.R:460` | `as.integer()` around a logical mask. |
| `tests/testthat/test-analysis-quantiles.R:849` | `as.integer()` around an all-`FALSE` mask. |
| `tests/testthat/test-conversion.R:3328` | Four wrong types in a loop, one per iteration. |
| `tests/testthat/test-conversion.R:3357` | A factor with levels `"yes"` and `"no"`. |

All four change in PR 1.

### Class and design support

| Class | Validator fires | Reason |
|---|---|---|
| `survey_taylor` | Yes | Inherits `survey_base`. |
| `survey_replicate` | Yes | Inherits `survey_base`. |
| `survey_twophase` | Yes | Inherits `survey_base`. |
| `survey_nonprob` | Yes | Inherits `survey_base`. |
| `survey_collection` | No | It does not inherit `survey_base`. It stores designs, not a data frame. |

S7 runs a parent validator for every subclass. The four concrete classes each
already carry a validator of their own, and none of them needs an edit.
`survey_base` carries no validator today, so this change is the first test of
that mechanism in this package. The contract is the observable in the table:
the abort fires on all four classes. Should one body on `survey_base` fail to
deliver it, raise a HOLD. Do not copy the check into the four subclass
validators — that is the repetition `.claude/rules/engineering-preferences.md`
rules out.

---

## Architecture

### Files touched

No two PRs share a file at the same time. The three PRs run in order, so
`tests/testthat/helper-test-data.R` and `NEWS.md` may appear in more than one
list below.

**PR 1 — the validator.**

- `R/core-classes.R` — add a validator to `survey_base`; add one sentence to
  the `data` property in its roxygen block.
- `man/survey_base.Rd` — regenerated by `devtools::document()`.
- `plans/error-messages.md` — one new row.
- `NEWS.md` — one entry under **Breaking changes**.
- `tests/testthat/helper-test-data.R` — one new fixture helper that writes a
  marker column of a named type.
- `tests/testthat/test-s7-classes.R` — the reject path and the accept path.
- `tests/testthat/test-analysis-quantiles.R` — repair the two blocks at lines
  460 and 849.
- `tests/testthat/test-conversion.R` — repair the two blocks at lines 3313 and
  3353.

**PR 2 — the mask.**

- `R/analysis-helpers.R` — change the body of `.apply_domain()`; update its
  `@return` text.
- `tests/testthat/helper-test-data.R` — one new fixture helper that returns a
  pair of designs differing in one marker element.
- `tests/testthat/test-analysis-helpers.R` — the invariance blocks.
- `NEWS.md` — one entry under **Bug fixes**.

**PR 3 — the conversion helper and the printed line.**

- `R/methods-conversion.R` — remove the coercion in `.restrict_to_domain()`;
  rewrite the design note above the helper that explains the coercion.
- `tests/testthat/test-methods-print.R` — the printed domain line.
- `tests/testthat/test-conversion.R` — the conversion routes.
- `tests/testthat/test-analysis-helpers.R` — the no-marker design.

No file outside these lists is edited.

### Functions added

None.

### Functions modified

```r
.apply_domain(design)          # internal; unchanged signature
.restrict_to_domain(converted) # internal; unchanged signature
```

### Class changes

`survey_base` gains a `validator` argument. Its properties do not change.

---

## Function contracts

### `survey_base` validator — domain marker type check

**Ships in PR 1.**

- **Where**: the `validator` argument of the `survey_base` class definition.
  `survey_base` has no validator today; this change adds the first one.
- **When it runs**:
  - at construction of any concrete design object, through any constructor;
  - at every assignment to any property of a design object, including
    `@data`, `@variables`, `@metadata`, `@groups`, and `@call`. S7 validates
    the whole object after each property write.
- **What it reads**: the stored `@data` column named by
  `SURVEYCORE_DOMAIN_COL`. The existing `@data` setter runs first, so the
  validator sees the column after that setter has stripped any
  `haven_labelled` class.
- **Checks, in this order**:
  1. Is `SURVEYCORE_DOMAIN_COL` in `names(self@data)`? When it is not, the
     validator does no further work on this check.
  2. Is the stored column logical? When it is not, abort with
     `surveycore_error_domain_not_logical`.
- **What it does not check**: the column length, the `NA` count, the presence
  of a `TRUE` value, the column's attributes, and the column's position.
- **Returns**: nothing on success. The validator follows the shape of the
  existing `survey_twophase` subset check in the same file.
- **Cost**: one name lookup and one type test per validation. Neither
  allocates in proportion to the row count. Order the two checks as listed —
  the name lookup is the cheap one and it is the one that returns on the
  common path, where no design carries the column at all.
- **Independence**: the check does not read `@variables`. It therefore holds
  on all four concrete classes with one body.

#### Errors

| Error class | Trigger | Message |
|---|---|---|
| `surveycore_error_domain_not_logical` | `@data` holds a column named by `SURVEYCORE_DOMAIN_COL` whose type is not logical | `"x" = "Domain column {.field {SURVEYCORE_DOMAIN_COL}} must be logical, not {.cls {col_class}}."`, `"i" = "{.fn surveytidy::filter} writes this column as a logical mask; {.code TRUE} marks a row inside the active domain."` |

`col_class` is `class(self@data[[SURVEYCORE_DOMAIN_COL]])`.

Bullet register, per `.claude/rules/code-style.md`:

- The `"x"` bullet is declarative with the object as the subject.
- The `"i"` bullet earns its place. The reader of this error is the author of
  the code that wrote the column, not the person who supplied the data. The
  bullet names the one function that is supposed to write the column and
  states what a `TRUE` value means. That orients the reader to the producer.
- There is no `"v"` bullet. A repair instruction here would only restate the
  `"x"` bullet: the `"x"` already says the column must be logical, so "write
  it as a logical vector" adds no fact. Row 101 in `plans/error-messages.md`
  carries a `"v"` because a person can repair the data it names. No person
  repairs this column by hand. The model row for this check is **row 38**,
  the `survey_twophase` S7 validator, which carries an `"x"` alone and reads
  `"Subset column {.field {subset_var}} must be logical, not {.cls {col_class}}"`.
  Row 22 carries the same error class and is **not** the model. It is the
  `as_survey_twophase()` constructor's own pre-construction check, Layer 3.
  Its message opens with `{.arg subset}` because the caller passed a bad
  argument there, not a bad stored column.

#### Warnings

None.

#### Edge cases

| Case | Behaviour |
|---|---|
| No domain column in `@data` | The validator passes. Nothing changes for an unfiltered design. |
| A logical column with some `NA` | The validator passes. `NA` is a legal marker value. |
| A logical column that is all `NA` | The validator passes. Downstream this is an empty domain. |
| A zero-row data frame with a `logical(0)` domain column | The validator passes. The check tests the type, and `logical(0)` is logical. |
| A zero-row data frame with an `integer(0)` domain column | The validator aborts. The type is wrong whatever the length. |
| A logical column carrying attributes, for example a `label` attribute | The validator passes. `is.logical()` reads the type and ignores attributes. |
| A `haven_labelled` column over a logical base | The `@data` setter strips the class first, so the validator sees a logical column and passes. |
| A one-column logical matrix, or a logical vector carrying any other class attribute | The validator passes. **The check tests the storage type only.** It accepts any object for which `is.logical()` is `TRUE`, whatever its shape or its class attribute. Do not reject a matrix shape — that widens the contract, and no code in the package writes such a column. |
| An ordered factor | The validator aborts. `class()` returns `c("ordered", "factor")`, and `{.cls {col_class}}` renders that as `<ordered/factor>`. The check is generic, so a complex vector and a raw vector abort the same way. |
| A list column named by `SURVEYCORE_DOMAIN_COL` | The validator aborts. A list is not logical. |
| A data frame that already carries a non-logical marker, passed to a constructor | The constructor aborts with this class. No Layer 3 check covers this column, so the Layer 1 error is the one the caller sees. |
| An assignment that would introduce a bad column | The assignment aborts. The design object keeps its previous value, because the error propagates before the replacement completes. |

### `.apply_domain(design)`

**Ships in PR 2.**

- **Signature**: unchanged.
- **Returns**: a logical vector of length `nrow(design@data)` that holds no
  `NA`.
- **Behaviour**:
  - Column present: `TRUE` where the stored marker is `TRUE`; `FALSE` where
    the stored marker is `FALSE` or `NA`.
  - Column absent: every element `TRUE`. This branch does not change.
- **No coercion.** The validator guarantees the type, so the helper does one
  job: it resolves `NA` to `FALSE`.
- **Conditions**: none, in either branch.
- **Why the `NA` resolution matters**: thirteen call sites index
  `design@data` with the returned vector. An `NA` element produces a phantom
  all-`NA` row, and in a grouped call that phantom row becomes a group
  combination that no real row supports.

#### Edge cases

| Case | Behaviour |
|---|---|
| No domain column | All `TRUE`, length `nrow(design@data)`. |
| Domain column with no `NA` | Returned unchanged in value. |
| All-`NA` domain column | All `FALSE`. Each caller then follows its own empty-domain path. |
| Zero-row design data | `logical(0)`. |

#### `@return` documentation

The `@return` line states the post-change contract: a logical vector of
length `nrow(design@data)`, `TRUE` for in-domain rows, and `FALSE` for a row
whose stored marker is `FALSE` or `NA`.

### `.restrict_to_domain(converted)`

**Ships in PR 3.**

- **Signature**: unchanged.
- **Behaviour**: read the marker column from the converted object's frame
  with no coercion, then index the converted object with
  `r & !is.na(r)`.
- **Keep `& !is.na(r)`.** The validator forbids a non-logical column. It does
  not forbid `NA`. A logical marker can hold `NA`, and an `NA` in an index
  vector selects a phantom row. The guard is still load-bearing.
- **Why this helper does not call `.apply_domain()`**: it reads the frame of
  a `survey` package object, not a surveycore design. The two helpers read
  different structures, so sharing one body would not be a de-duplication.
- **Conditions**: none. The helper raises nothing on any route.

#### Design note

The comment block above the helper explains why the coercion is there. It
describes a package with no validator on the column. Rewrite it. The new note
records two facts: the class validator guarantees the type at the write, and
`!is.na(r)` still reads an `NA` marker as outside the domain.

### `plans/error-messages.md`

**Ships in PR 1.**

Add one row to the Error Case Table. It lands before any code uses the class,
per `.claude/rules/code-style.md`.

> **Correction to issue #262.** The issue names 102 as the next free number.
> Number 102 is taken. It belongs to `surveycore_error_haven_class_not_logical`
> on `survey_data()`. The next free plain number is **103**. No row numbered
> 103 or higher exists in the file.

The row:

| # | Function | Condition | Level | Error Class | cli Message Template |
|---|----------|-----------|-------|-------------|----------------------|
| 103 | S7 validator (`survey_base`) | `@data` holds a column named by `SURVEYCORE_DOMAIN_COL` whose type is not logical | ERROR | `surveycore_error_domain_not_logical` | `"x" = "Domain column {.field {SURVEYCORE_DOMAIN_COL}} must be logical, not {.cls {col_class}}."`, `"i" = "{.fn surveytidy::filter} writes this column as a logical mask; {.code TRUE} marks a row inside the active domain."` |

Place it after row 101 and 102, beside the other validator rows.

### `NEWS.md`

Two entries in the development version, one per PR that changes behaviour.

- **PR 1, under Breaking changes.** A design now rejects a domain marker
  column that is not logical. The entry names the error class and issue #262.
  Code that wrote an integer marker aborted nothing before this change and
  aborts now, which is why the entry is a breaking change and not a bug fix.
- **PR 2, under Bug fixes.** A grouped analysis of a filtered design no longer
  reports a group that no in-domain row supports. The entry names issue #262.

PR 3 changes no user-visible behaviour and writes no entry.

---

## Quality gates

Objectively verifiable. Each one either holds or does not.

Three gates bind one PR only. Gate 1 binds PR 3, because
`.restrict_to_domain()` holds the last such call until then. Gate 3 binds
PR 1, which repairs the four test blocks. Gate 4 binds PR 1, which adds the
row. Gates 2 and 5 to 12 bind every PR.

1. `grep -rn "as.logical(.*SURVEYCORE_DOMAIN_COL" R/` returns nothing.
2. `grep -rn "SURVEYCORE_DOMAIN_COL\]\] <-" R/` returns hits, and every hit
   writes a logical vector.
3. `grep -rn "SURVEYCORE_DOMAIN_COL\]\] <-" tests/testthat/` returns hits, and
   every hit writes a logical vector. **Four** hits write a non-logical column
   today: lines 460 and 849 in `tests/testthat/test-analysis-quantiles.R`, and
   lines 3328 and 3357 in `tests/testthat/test-conversion.R`. Line 3328 writes
   a variable, so its type is not visible in the grep output. Read the block
   before you judge it.
4. `plans/error-messages.md` holds row 103 with the class
   `surveycore_error_domain_not_logical`, and the row's message template
   matches the `cli::cli_abort()` call byte for byte.
5. Every `cli::cli_abort()` added carries a `class` argument.
6. `devtools::document()` runs clean and leaves `NAMESPACE` unchanged. No
   export is added or removed.
7. `devtools::test()` passes with no failure.
8. `devtools::run_examples()` passes.
9. `R CMD check --as-cran`: 0 errors, 0 warnings, and no note beyond the two
   pre-approved ones. Read "0 warnings" as "no new warning" — clean `develop`
   already emits pre-existing AAPOR small-cell warnings during the test run.
10. `pkgdown::build_site()` builds with no errored page.
11. `covr::package_coverage()` measured with `NOT_CRAN=true` is at or above
    95%, target 98%.
12. `air format --check` passes on the files the PR touches. Files the PR does
    not touch are out of the gate; some of them are already not air-clean.

13. `grep -rln "SURVEYCORE_DOMAIN_COL" R/analysis-*.R R/glm*.R` returns exactly
    three files: `R/analysis-helpers.R`, `R/analysis-t-test.R` and
    `R/glm-anova.R`. A fourth file in that list means an analysis function
    reads the marker column directly in place of the shared helper. Gate 2
    cannot catch that, because gate 2 matches an assignment to the column and
    a direct read is not an assignment. This gate runs on PR 2 and PR 3.

    Measured 2026-09-12 on this branch: the command returns those three files
    and no other. None of them holds a function the analysis path reads the
    mask for. `R/analysis-helpers.R` defines the helper,
    `R/analysis-t-test.R` writes the column, and `R/glm-anova.R` compares it
    against itself.

---

## Integration

`surveytidy::filter()` writes the marker column. It writes a logical vector
today, so this change asks nothing of it. A future verb that writes the
column must write a logical vector or the write aborts.

`SURVEYCORE_DOMAIN_COL` is exported. User code can therefore write the column
by hand and can therefore meet this error. The message's `"i"` bullet points
that reader at the intended producer.

---

## Pipeline tier

**recommended**, for all three PRs.

- PR 1 adds a new public error class, which is a contract change, and it adds
  a failure mode to every constructor and to every property write on every
  design object.
- PR 2 changes the numbers a grouped analysis returns on a filtered design.
- PR 3 depends on PR 2 and touches a conversion route the `survey` package
  reads.

None of the three meets the `optional` test: each changes a contract, a number
or both.
