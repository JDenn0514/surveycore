# Test spec: the svydesign replicate bridge (#197, #198)

**Version:** 1.1
**Date:** 2026-09-04
**Status:** Draft — Stage 3r resolution applied

---

## 1. What this document validates

Two exported functions carry a replicate weights design between surveycore and
the `survey` package:

- `from_svydesign()` takes a `survey::svrepdesign` object (class
  `svyrep.design`) and returns a `survey_replicate` object.
- `as_svydesign()` takes a `survey_replicate` object and returns a
  `survey::svrepdesign` object.

Three defects are under test.

1. `from_svydesign()` returns a design that carries no replicate weights. The
   loss is silent at conversion time. It surfaces later, during analysis, as
   `surveycore_error_all_replicates_na`.
2. `from_svydesign()` stores replication factors as if they were finished
   weights — weights already on the population scale. The point estimate stays
   correct and the standard error moves. Nothing warns.

   **The size and the direction of that move both depend on the design.**
   Measured across five designs: 35% too small on one bootstrap design, 8% too
   small on a 40-row JKn design, 4% too large on a 32-row JKn design, 10% too
   large on a 32-row BRR design, and 0.1% too large on an unclustered JK1
   design. Same replicate type, different draw, opposite direction. A weighted
   mean is invariant to a constant rescaling of its weights, so the defect is
   not a shrinkage: it depends on how the replication-factor pattern correlates
   with the base weights.

   **No row in this document may assert a direction, a ratio, or a percentage.**
   A row that asserts the standard error is "too small", or that the buggy and
   correct values differ by some factor, encodes a property of one design and
   will fail on another. The only sound assertion is parity against the oracle
   at the stated tolerance.
3. `as_svydesign()` on a replicate design that records a finite population
   correction (FPC) fails with `survey`'s own `fpc is wrong length`.

Defect 2 is the one that matters most: a wrong standard error with no warning.
The oracle rows in §6 are the regression test for it. A test that only checks
that conversion runs without error will pass on the broken code.

Five further behaviours are also under test. Each one replaces a state that
either passed silently or failed with an untyped error from `survey`.

4. `as_svydesign()` on a `Fay` design fails today with `survey`'s own
   `With type='Fay' you must supply the correct rho`. After the change it
   returns a working design that reports the shrinkage factor the source
   design was built with.
5. `from_svydesign()` accepts a replicate type surveycore does not support and
   the failure lands later, on export, as `survey`'s bare
   `'arg' should be one of ...`. After the change the conversion refuses such a
   design with a typed error.
6. `from_svydesign()` on a design with no rows returns an empty object and
   raises nothing. `as_svydesign()` on a design that names no replicate column
   fails with `survey`'s bare `missing value where TRUE/FALSE needed`. After
   the change both raise a typed error.
7. `from_svydesign()` writes every replicate column into the design data on
   every conversion. A replicate column name that also names a column of
   unrelated values no longer leaves the unrelated values in place.
8. The values that pass through unchanged stay unchanged: zeros, `NA` in a
   replicate column, `NA` in the base weights, and a negative replicate
   weight.

All work lands in `tests/testthat/test-conversion.R` and
`tests/testthat/_snaps/conversion.md`. Add new blocks in new sections at the
end of the file; extend the existing header comment index to match.

---

## 2. Reference oracle

| Estimand | Oracle |
|---|---|
| Point estimate | `survey::svymean(~y1, sv)` on the `survey` design, read with `coef()` |
| Standard error | `survey::svymean(~y1, sv)`, read with `survey::SE()` |
| Confidence bounds | `survey::svymean(~y1, sv)`, read with `confint()` |

The surveycore side of every comparison is `get_means(d, y1)`, whose result
columns are `mean`, `se`, `ci_low` and `ci_high`.

The core assertion is **round-trip parity**. Two directions and one full loop:

| Direction | Assertion |
|---|---|
| Import | `get_means()` on `from_svydesign(sv)` reproduces `survey::svymean(~y1, sv)` on that same `sv` |
| Export | `survey::svymean(~y1, as_svydesign(d))` reproduces `get_means(d, y1)` on that same `d` |
| Full loop | `survey::svymean()` on `as_svydesign(from_svydesign(sv))` reproduces `survey::svymean(~y1, sv)` |

`skip_if_not_installed("survey")` goes inside each `test_that()` block that
uses `survey`. Never at file level.

---

## 3. Datasets and fixtures

`survey` is the oracle, so these are unit tests against a reference
implementation on synthetic data. Use `make_survey_data()` from
`tests/testthat/helper-test-data.R`. Do not use `nhanes_2017` or
`acs_pums_wy`: no row here needs a real dataset, and the real datasets are
reserved for numerical validation of the variance code itself.

Define the fixtures once, in a new fixture block near the existing fixture
section at the top of the file.

### 3.1 A stratified Taylor design in `survey`

```r
rep_bridge_taylor <- function(seed = 91L) {
  df <- make_survey_data(n = 60L, n_psu = 12L, n_strata = 3L, seed = seed)
  list(
    df = df,
    sv = survey::svydesign(
      ids = ~psu,
      weights = ~wt,
      strata = ~strata,
      data = df,
      nest = TRUE
    )
  )
}
```

### 3.2 An unstratified Taylor design in `survey`

```r
rep_bridge_taylor_flat <- function(seed = 92L) {
  df <- make_survey_data(n = 60L, n_psu = 12L, n_strata = 1L, seed = seed)
  list(
    df = df,
    sv = survey::svydesign(ids = ~psu, weights = ~wt, data = df)
  )
}
```

### 3.3 A surveycore replicate design

```r
rep_bridge_sc <- function(fpc_col = NULL, type = "BRR", seed = 93L) {
  df <- make_survey_data(
    n = 60L,
    n_psu = 12L,
    n_strata = 3L,
    design = "replicate",
    type = "brr",
    seed = seed
  )
  cols <- grep("^repwt_", names(df), value = TRUE)
  if (is.null(fpc_col)) {
    as_survey_replicate(
      df,
      weights = wt,
      repweights = tidyselect::all_of(cols),
      type = type
    )
  } else {
    as_survey_replicate(
      df,
      weights = wt,
      repweights = tidyselect::all_of(cols),
      type = type,
      fpc = tidyselect::all_of(fpc_col)
    )
  }
}
```

### 3.4 A hand-built design that declares finished weights

`survey::as.svrepdesign()` always reports the factor form, so the finished-weight
form needs a hand-built design. Copy `scale` and `rscales` from an
`as.svrepdesign()` object and pass `type = "other"`, so no type-specific rule
in `survey` interferes.

```r
rep_bridge_combined <- function(seed = 94L, named = FALSE) {
  fx <- rep_bridge_taylor(seed)
  src <- survey::as.svrepdesign(fx$sv, type = "JKn", compress = FALSE)

  # unclass() is required. survey puts the class "repweights" on the stored
  # object and as.matrix() keeps it, so without unclass() the product is a
  # classed matrix and as.data.frame() collapses it to a single column.
  finished <- unclass(as.matrix(src$repweights)) * src$pweights
  n_rep <- ncol(finished)

  if (named) {
    # The named recipe. compressWeights() needs the replicate columns to be a
    # data frame of columns that are also columns of `data`.
    cols <- paste0("rw", seq_len(n_rep))
    rep_df <- as.data.frame(finished)
    names(rep_df) <- cols
    dat <- cbind(fx$df, rep_df)
    sv <- survey::svrepdesign(
      weights = ~wt,
      repweights = dat[, cols],
      type = "other",
      scale = src$scale,
      rscales = src$rscales,
      combined.weights = TRUE,
      mse = TRUE,
      data = dat
    )
    return(list(df = dat, sv = sv, cols = cols))
  }

  # The unnamed recipe. A bare matrix leaves the columns unnamed, so this cell
  # also exercises name generation.
  dimnames(finished) <- NULL
  list(
    df = fx$df,
    sv = survey::svrepdesign(
      weights = fx$df$wt,
      repweights = finished,
      type = "other",
      scale = src$scale,
      rscales = src$rscales,
      combined.weights = TRUE,
      mse = TRUE,
      data = fx$df
    ),
    cols = NULL
  )
}
```

`named = FALSE` builds cell D. `named = TRUE`, then
`survey::compressWeights()`, builds cell C.

**The oracle for these two cells is the cell's own design, never `src`.** The
fixture copies `scale` and `rscales` from `src` but passes `type = "other"` and
`mse = TRUE`, so it is a different design from the `JKn` object it was derived
from, and the two report standard errors that differ in the fifth decimal
place — measured as 0.1567883 against 0.1567864. Comparing a cell against
`src` would fail at the 1e-8 tolerance for a reason that has nothing to do with
the conversion.

### 3.5 A balanced design for BRR and Fay

`survey` needs an even number of PSUs in every stratum to build a BRR or a Fay
replicate design. An odd count fails with
`Can't split with odd numbers of PSUs in a stratum` — measured.

**This fixture is for isolation, not to repair an imbalance.** The §3.1
fixture already satisfies the constraint: `make_survey_data()` allocates PSUs
to strata by integer division with no random part, so `n_psu = 12` over
`n_strata = 3` gives 4 PSUs in every stratum, and both Fay and BRR build on it
with no error and no warning — measured. The rows below use their own fixture
so a BRR or Fay test does not depend on §3.1's `n_psu` and `n_strata` values
continuing to divide evenly. The explicit `strata` and `psu` assignment states
the layout the rows rely on instead of inheriting it.

```r
rep_bridge_even <- function(seed = 95L) {
  df <- make_survey_data(n = 32L, n_psu = 16L, n_strata = 4L, seed = seed)
  df$strata <- rep(1:4, each = 8L)
  df$psu <- rep(1:16, each = 2L)
  list(
    df = df,
    sv = survey::svydesign(
      ids = ~psu,
      weights = ~wt,
      strata = ~strata,
      data = df,
      nest = TRUE
    )
  )
}
```

Rows R-5, E-9 and E-10 use this fixture. So do the three rows that build a
design of an unsupported type: `survey::as.svrepdesign()` builds a
`subbootstrap` and an `mrbbootstrap` design from any stratified Taylor design,
and one fixture keeps those blocks short.

`survey::as.svrepdesign(type = "mrbbootstrap")` emits its own warning at
construction — `Design is sampled with replacement: only first stage used`.
That warning belongs to the fixture, not to the behaviour under test. Build
that design inside `suppressWarnings()`, so the block asserts only
surveycore's own condition.

### 3.6 A design with no rows

```r
rep_bridge_zero_row <- function() {
  df <- make_survey_data(n = 40L, n_psu = 10L, n_strata = 2L, seed = 96L)
  empty <- df[0L, , drop = FALSE]
  sv <- survey::svydesign(ids = ~psu, weights = ~wt, data = empty)
  survey::as.svrepdesign(sv, type = "JK1")
}
```

Measured: this builds, and the object reports 0 rows, a 0-by-0 replicate
matrix and a zero-length base weight vector. It raises nothing on the way.
Rows C-13 and C-14 use it.

### 3.7 A design that names no replicate column

`as_survey_replicate()` refuses a selection of zero replicate columns at
construction, and the import route now refuses a design with no rows, so
neither builds this state. Use the exported `survey_replicate` class
constructor and pass `repweights = character(0)` in the `variables` list. Give
every `variables` key a value: unspecified keys take `NULL`.

Rows C-15 and C-16 use it. Keep the construction inside those two blocks — no
other row needs it.

---

## 4. Tolerances

From `.claude/rules/testing-surveycore.md`. No row uses a weaker tolerance.

| Estimand | Tolerance | Assertion |
|---|---|---|
| Point estimate | `1e-10` | `expect_equal(sc$mean, coef(sv_m)[["y1"]], tolerance = 1e-10)` |
| Standard error | `1e-8` | `expect_equal(sc$se, as.numeric(survey::SE(sv_m)), tolerance = 1e-8)` |
| Confidence bounds | `1e-6` | `expect_equal(sc$ci_low, confint(sv_m)[1], tolerance = 1e-6)` |

Structural assertions use `expect_identical()`: column names, the contents of
`@variables$repweights`, `NULL` values. Calculated numbers use
`expect_equal()`.

The fold-in check in row I-2 compares two numeric matrices. Use
`expect_equal()` with `tolerance = 1e-12`: both sides are one floating-point
multiplication away from the same inputs, so the difference is at rounding
level, well inside the `1e-10` point tolerance.

Rows E-9 and E-10 compare a recovered shrinkage factor and a replicate scale.
Use `tolerance = 1e-10`, the point-estimate tolerance. The recovery inverts an
exact algebraic identity, and the measured round trip returns 0.3 for a source
value of 0.3, so the tolerance is not doing work here. It is the strictest
value in the table that no rounding step can breach.

---

## 5. Coverage matrix — storage form crossed with weight form

Two properties of the source design decide which code path runs. Both must be
crossed. `compress` decides whether the replicate weights arrive as a matrix or
as a compressed object that needs expansion. `combined.weights` decides whether
they arrive as finished weights or as replication factors that still need the
base weight folded in.

`survey::as.svrepdesign()` compresses by default and always reports the factor
form, so it reaches cells A and B only. Cells C and D need the hand-built
design from §3.4.

| Cell | `compress` | `combined.weights` | Column names | How to build the source design | Row |
|---|---|---|---|---|---|
| A | `TRUE` | `FALSE` | unnamed | `survey::as.svrepdesign(fx$sv, type = "JKn", compress = TRUE)` | I-1 |
| B | `FALSE` | `FALSE` | unnamed | `survey::as.svrepdesign(fx$sv, type = "JKn", compress = FALSE)` | I-2 |
| C | `TRUE` | `TRUE` | named | `rep_bridge_combined(named = TRUE)`, then `survey::compressWeights()` | I-3 |
| D | `FALSE` | `TRUE` | unnamed | `rep_bridge_combined()` as it stands | I-4 |

The **Column names** column is measured, not chosen. A compressed design that
declares finished weights can only be built from named columns — see §3.4 — so
cell C is named and cell D is unnamed. That does not weaken the matrix: the
matrix exists to cross the storage form with the weight form, and both crossings
hold. Name generation is exercised by cells A, B and D and by rows I-8, I-9,
I-17 and I-18.

**Every cell asserts its own preconditions before it asserts anything else.**
Without that, a change in `survey` could quietly move a block into a different
cell and the matrix would report coverage it does not have.

| Precondition | Assertion |
|---|---|
| The cell is compressed | `expect_s3_class(sv$repweights, "repweights_compressed")` |
| The cell is not compressed | `expect_true(is.matrix(as.matrix(sv$repweights)) && !inherits(sv$repweights, "repweights_compressed"))` |
| The cell holds factors | `expect_false(isTRUE(sv$combined.weights))` |
| The cell holds finished weights | `expect_true(isTRUE(sv$combined.weights))` |
| The columns are unnamed — cells A, B, D | `expect_length(colnames(sv$repweights), 0L)` |
| The columns are named — cell C | `expect_length(colnames(sv$repweights), n_rep)` |

Cell C needs a compressed object that declares finished weights.
`survey::compressWeights()` is the only route. `survey::svrepdesign()` has no
`compress` argument — measured against survey 4.5 — so do not look for one.

`compressWeights()` constrains how the design underneath it is built. It works
when `repweights` was passed as a data frame of columns that are also columns of
`data`. It raises `subscript too long` when `repweights` was passed as a bare
matrix, whether that matrix carried column names or not. This is why cell C is
named: an unnamed design cannot be compressed by this route. §3.4 gives both
recipes.

Keep the compressed precondition assertion in the block. If the installed
`survey` does not compress, the precondition fails and the cell reports the
truth instead of passing on an uncompressed design.

### 5.1 Behaviour coverage

The four cells above cross the two properties of the source design that decide
which weight path runs. Every other behaviour under test gets its own row or
rows. This table is the checklist: no behaviour may reach the end of it
without a row.

| Behaviour | Rows |
|---|---|
| Replicate column names generated when the source names none | I-8, I-9, I-17, I-18 |
| Replicate column names kept when the source names them | I-5, I-12, I-14, I-23 |
| Every replicate column written, on every conversion | I-6, I-23, I-24 |
| The base weight folded in when the source reports factors | I-2, I-13 |
| The base weight column identified, and not confused with a replicate | I-10, I-21 |
| Metadata unaffected by the written columns | I-22 |
| Values passed through: zeros, `NA`, negative | I-15, I-16, I-19, I-26 |
| No usable name per replicate column — refused | C-1, C-2, C-3 |
| A generated name already in the data — refused | C-4, C-5 |
| An unsupported replicate type — refused | C-10, C-11, C-12 |
| A source design with no rows — refused | C-13, C-14 |
| A design naming no replicate column — refused | C-15, C-16 |
| The FPC dropped and named on export | E-3, E-4, E-5, E-6, E-7, C-6, C-7, R-4 |
| Fay's shrinkage factor recovered on export | E-9, E-10, R-5 |
| Fay with a scale that yields no shrinkage factor — refused | C-8, C-9 |
| Fay with no recorded scale — refused | C-17, C-18 |
| Round-trip parity | R-1, R-2, R-3, R-5 |

---

## 6. Import direction — `from_svydesign()`

### 6.1 Oracle rows

| Row | Block asserts | Setup | Assertions |
|---|---|---|---|
| I-1 | `from_svydesign()` on a compressed factor-form design reproduces survey's standard error | Cell A | Cell A preconditions; then point (1e-10), SE (1e-8) and both CI bounds (1e-6) against `survey::svymean(~y1, sv)` |
| I-2 | `from_svydesign()` on an uncompressed factor-form design reproduces survey's standard error | Cell B | Cell B preconditions; point (1e-10) and SE (1e-8); plus the fold-in check below |
| I-3 | `from_svydesign()` on a compressed finished-weight design reproduces survey's standard error | Cell C | Cell C preconditions; point (1e-10) and SE (1e-8) |
| I-4 | `from_svydesign()` on an uncompressed finished-weight design reproduces survey's standard error | Cell D | Cell D preconditions; point (1e-10) and SE (1e-8) |

Row I-1 carries the CI comparison for the whole matrix. The other three cells
compare the point estimate and the standard error. A CI difference would come
from the degrees of freedom that each package uses for the quantile, not from
the conversion, and the standard error is the quantity the defect moves.

Row I-2 also asserts the fold-in directly. Cell B keeps the replicate weights
as a plain matrix, so the expected values are available without expansion:

```r
stored <- as.matrix(survey_data(d)[, d@variables$repweights, drop = FALSE])
expected <- as.matrix(sv$repweights) * sv$pweights
expect_equal(unname(stored), unname(expected), tolerance = 1e-12)
```

### 6.2 Structure rows

| Row | Block asserts | Assertions |
|---|---|---|
| I-5 | `from_svydesign()` keeps one replicate column name per replicate | `expect_length(d@variables$repweights, ncol(as.matrix(sv$repweights)))` on a cell A design |
| I-6 | `from_svydesign()` writes every named replicate column into the design data | `expect_true(all(d@variables$repweights %in% names(survey_data(d))))` |
| I-7 | `get_means()` on a converted design runs without raising the all-replicates-NA error | `expect_no_error(get_means(from_svydesign(sv), y1))` on a cell A design. This is the direct regression guard for the silent-loss defect |
| I-8 | `from_svydesign()` generates zero-padded replicate names | Build with `survey::as.svrepdesign(fx$sv, type = "bootstrap", replicates = 20L)`; `expect_identical(d@variables$repweights, paste0("..surveycore_repwt_", sprintf("%02d", 1:20), ".."))` |
| I-9 | `from_svydesign()` generates unpadded names for fewer than ten replicates | Build a `type = "other"` design with 4 unnamed replicate columns; `expect_identical(d@variables$repweights, paste0("..surveycore_repwt_", 1:4, ".."))` |
| I-10 | `from_svydesign()` leaves the base weight column name alone | `expect_identical(d@variables$weights, "wt")` on a cell A design, because `pweights` still matches the `wt` column |
| I-11 | `from_svydesign()` records no FPC for a replicate design | `expect_null(d@variables$fpc)` and `expect_identical(d@variables$fpctype, "fraction")` |
| I-22 | `from_svydesign()` keeps the variable labels on the base columns and adds no metadata entry for the written replicate columns | Build the source data with `make_survey_data(with_labels = TRUE)`, then a cell A design on it. Assert two things. First, `extract_var_label(d, y1)` returns the label the source column carried, and the same for one more labelled column. Second, `expect_false(any(d@variables$repweights %in% names(d@metadata@variable_labels)))` — the written columns contribute no entry. Read the labels as `d@metadata@variable_labels`. Do not call `survey_metadata(d)`: that is the S7 class constructor, not an accessor, and it aborts with `@variable_labels must be <list>` when handed a design. A `survey_metadata` object also has no `@variables` property. Do **not** assert that metadata holds an entry per replicate column: the written columns are plain doubles with no label attribute, so they contribute none, and that assertion fails |

### 6.3 Named-column rows

| Row | Block asserts | Setup | Assertions |
|---|---|---|---|
| I-12 | `from_svydesign()` keeps replicate column names that the survey design already carries | `survey::svrepdesign(weights = df$wt, repweights = df[, cols], type = "BRR", mse = TRUE, data = df)` — a named, uncompressed, finished-weight design | `expect_identical(d@variables$repweights, cols)`; `expect_equal(survey_data(d)[[cols[1]]], df[[cols[1]]], tolerance = 1e-12)`. The values are unchanged. Compare by value, not with `expect_identical()`: the conversion rewrites every replicate column as a double, so a source column of another numeric type comes back as a double with the same values |
| I-13 | `from_svydesign()` rewrites named replicate columns when the design reports the factor form | The same construction with `combined.weights = FALSE`. `survey` emits its own heuristic warning here — `Data look like combined weights` — because the columns hold finished weights but the design declares factors. That warning belongs to the fixture, not to the behaviour under test: build the design inside `suppressWarnings()` so the block asserts only surveycore's own conditions | `expect_identical(d@variables$repweights, cols)`; the stored column equals `df[[cols[1]]] * df$wt` at 1e-12; SE parity at 1e-8 |
| I-14 | `from_svydesign()` produces a usable design from a compressed source whose columns were named | The I-12 construction, then `survey::compressWeights()` | `expect_length(d@variables$repweights, length(cols))`; `expect_true(all(d@variables$repweights %in% names(survey_data(d))))`; SE parity at 1e-8. Measured on survey 4.5, compression keeps the column names, so the route takes the pass-through branch and not the generation branch. Assert the count, the data columns and the standard error. Do not assert the exact names: which naming scheme survives compression is survey's decision, and either outcome is correct as long as those three hold |
| I-23 | `from_svydesign()` writes replicate columns whose names the `survey` design carries but the data does not | Build a design with a named replicate matrix whose names are not columns of `data`: set `cols <- paste0("rw", 1:4)`, put those names on the matrix, pass the matrix as `repweights`, and pass a `data` frame that holds no such columns. Use `type = "other"` with a `scale` and `rscales`, and `combined.weights = TRUE`. Verified constructible: the design builds and keeps its `colnames` | `expect_identical(d@variables$repweights, cols)`; `expect_true(all(cols %in% names(survey_data(d))))`; the first stored column equals the first column of the source matrix at 1e-12; point parity at 1e-10 and SE parity at 1e-8 |
| I-24 | `from_svydesign()` stores the replicate weight, not the unrelated column that shares its name | Build a design where a replicate column name also names a column of `data` holding different values. `survey::svrepdesign()` takes `variables` and `repweights` as independent arguments and cross-checks neither, so this builds: name the matrix `rw1` to `rw4`, put columns `rw1` to `rw4` of unrelated values into `data`, pass the matrix as `repweights`, and pass `combined.weights = TRUE` | `expect_identical(d@variables$repweights, cols)`; the stored `rw1` column equals the first column of the source matrix at 1e-12; `expect_false(isTRUE(all.equal(survey_data(d)$rw1, df$rw1)))` — the unrelated values are gone; SE parity at 1e-8. This row guards the always-write rule. Without it the design can record column names that point at values the variance must never read |

### 6.4 Edge case rows

| Row | Block asserts | Setup | Assertions |
|---|---|---|---|
| I-15 | `from_svydesign()` keeps the genuine zeros in a JK1 design | `survey::as.svrepdesign(flat$sv, type = "JK1")` on the unstratified fixture. JK1 deletes one PSU per replicate, so the deleted rows carry weight 0 in that replicate | `expect_true(any(stored == 0))` on the stored replicate block; point (1e-10) and SE (1e-8) parity |
| I-16 | `from_svydesign()` keeps the genuine zeros in a JKn design | `survey::as.svrepdesign(fx$sv, type = "JKn")` on the stratified fixture | Same two assertions as I-15 |
| I-17 | `from_svydesign()` converts a single-replicate design | A `type = "other"` design with one unnamed replicate column, `scale = 1`, `rscales = 1` | `expect_identical(d@variables$repweights, "..surveycore_repwt_1..")`; point parity at 1e-10; SE parity at 1e-8 |
| I-18 | `from_svydesign()` converts a two-replicate design | A `type = "other"` design with two unnamed replicate columns, `scale = 0.5`, `rscales = c(1, 1)` | `expect_identical(d@variables$repweights, c("..surveycore_repwt_1..", "..surveycore_repwt_2.."))`; point and SE parity |
| I-19 | `from_svydesign()` keeps `NA` in a replicate column | Build a `type = "other"` design whose replicate matrix has one `NA` | `expect_true(anyNA(stored))`. The conversion does not drop, impute, or reject the value |
| I-20 | `from_svydesign()` rejects a design whose base weight column holds a zero | Set one `wt` value to 0 before building the survey design | `expect_error(from_svydesign(sv), class = "surveycore_error_weights_nonpositive")`. Existing behaviour of the class validator, recorded here so the fold-in change does not alter it. Class assertion only — no snapshot, this is a class validator message |
| I-21 | `from_svydesign()` does not mistake a replicate column for the base weight column | Build a `type = "other"` design whose data frame holds **no** weight column, whose base weights are `df$wt`, and whose first replicate column equals those base weights exactly (a replicate that deletes nothing). Pass `weights` as a bare vector and drop `wt` from `data` | `expect_identical(d@variables$weights, "..surveycore_wt..")`; `expect_false(d@variables$weights %in% d@variables$repweights)`; point and SE parity at 1e-10 and 1e-8. Without the correct ordering inside the conversion, the base weight search can land on the replicate column and the design records the wrong weight column |
| I-25 | **Write no row.** An `NA` base weight cannot reach the conversion, so there is nothing to assert | `survey::svydesign()` drops every row whose weight is `NA`, on all three `na_weights` settings: its source reads `if (any(is.na(pre_weights))) { data <- data[!is.na(pre_weights), ] }`, and only `"fail"` stops before that line. Measured — a 10-row frame with one `NA` weight gives a 9-row design and no `NA` in the base weights. Handing such a matrix straight to `survey::svrepdesign()` fails inside its own `combined.weights` heuristic. The `na_weights` argument permits an `NA` weight in the input, not in the design. Recorded so a later reader does not read the absence as an oversight |
| I-26 | `from_svydesign()` keeps a negative replicate weight | Build a `type = "other"` finished-weight design whose replicate matrix holds one negative value | The design converts and raises nothing. The stored block holds that value unchanged: `expect_true(any(stored < 0))`, and the cell equals the source value at 1e-12. The validator checks each replicate column for numeric only, and the positivity check covers the base weight column alone. Some calibrated replicate files carry negative replicate weights |

### 6.5 Covered without a row of its own

`survey` sits in `Suggests`, so the conversion loads its namespace rather than
attaching the package. Expanding a compressed replicate object depends on a
method that namespace registers. Cells A and C are the guard: if the expansion
does not dispatch, both cells fail. No separate row is needed, and none is
added.

---

## 7. Export direction — `as_svydesign()`

| Row | Block asserts | Setup | Assertions |
|---|---|---|---|
| E-1 | `as_svydesign()` on a replicate design with no FPC raises no warning | `rep_bridge_sc()` | `expect_no_warning(sv <- as_svydesign(d))`; `expect_s3_class(sv, "svyrep.design")` |
| E-2 | `as_svydesign()` on a replicate design with no FPC reproduces surveycore's standard error | `rep_bridge_sc()` | `survey::svymean(~y1, as_svydesign(d))` against `get_means(d, y1)`: point 1e-10, SE 1e-8 |
| E-3 | `as_svydesign()` warns and drops the FPC on a BRR design | `rep_bridge_sc(fpc_col = "fpc", type = "BRR")`. `survey` rejects an FPC outright for BRR | `expect_warning(sv <- as_svydesign(d), class = "surveycore_warning_replicate_fpc_dropped")`; `expect_s3_class(sv, "svyrep.design")`; point and SE parity with `get_means(d, y1)` |
| E-4 | `as_svydesign()` warns and drops the FPC on a bootstrap design | `rep_bridge_sc(fpc_col = "fpc", type = "bootstrap")` | Same three assertions as E-3. See §11: the warning, not an error, is the recorded decision |
| E-5 | `as_svydesign()` warns and drops the FPC on a JKn design | `rep_bridge_sc(fpc_col = "fpc", type = "JKn")`. `survey` accepts an FPC for JKn, and the route drops it anyway | Same three assertions as E-3 |
| E-6 | `as_svydesign()` leaves the FPC recorded on the surveycore design | `rep_bridge_sc(fpc_col = "fpc")`; capture `survey_data(d)` and `d@variables` before the call | After the warned call: `expect_identical(d@variables$fpc, "fpc")`; `expect_identical(d@variables$fpctype, "fraction")`; `expect_identical(survey_data(d), before_data)`; `expect_identical(d@variables, before_vars)` |
| E-7 | `as_svydesign()` warns on every call, not only the first | Call it twice on the same design | Two `expect_warning()` calls, both with the class |
| E-8 | `as_svydesign()` converts a replicate design whose columns hold zeros | Build a surveycore replicate design inline whose replicate block has a zero column entry | `expect_no_warning()`; point and SE parity |
| E-9 | `as_svydesign()` on a Fay design passes the shrinkage factor the source design was built with | `survey::as.svrepdesign(even$sv, type = "Fay", fay.rho = 0.3)` on the §3.5 fixture, then `d <- from_svydesign(src)`, then `sv <- as_svydesign(d)` | `expect_no_error()`; `expect_equal(sv$rho, 0.3, tolerance = 1e-10)`; `expect_equal(sv$scale, src$scale, tolerance = 1e-10)`; SE parity with `get_means(d, y1)` at 1e-8. Before the change this call fails with `survey`'s own `With type='Fay' you must supply the correct rho`, so the block is the regression guard for that stop |
| E-10 | `as_svydesign()` on a Fay design built without a scale converts | `rep_bridge_sc(type = "Fay")` — the §3.3 fixture passes no `scale` | `expect_no_error(sv <- as_svydesign(d))`; `expect_equal(sv$rho, 0, tolerance = 1e-10)`; SE parity with `get_means(d, y1)` at 1e-8. The constructor's own default scale recovers a shrinkage factor of 0, which is legal — a Fay design with `rho = 0` is the BRR case. This row is the boundary partner of C-8 |

---

## 8. Full round trip

| Row | Block asserts | Setup | Assertions |
|---|---|---|---|
| R-1 | The full round trip through surveycore preserves the estimate and its standard error | Cell A; `sv_rt <- as_svydesign(from_svydesign(sv))` | `survey::svymean(~y1, sv_rt)` against `survey::svymean(~y1, sv)`: point 1e-10, SE 1e-8, both CI bounds 1e-6 |
| R-2 | The full round trip preserves the estimate for a finished-weight source | Cell D | Point 1e-10 and SE 1e-8 |
| R-3 | The full round trip preserves the replicate count | Cell A | `expect_identical(ncol(as.matrix(sv_rt$repweights)), ncol(as.matrix(sv$repweights)))` |
| R-4 | The full round trip on an FPC-bearing surveycore design returns to a working design | `rep_bridge_sc(fpc_col = "fpc")` | `expect_warning(sv <- as_svydesign(d), class = "surveycore_warning_replicate_fpc_dropped")`; then `d2 <- from_svydesign(sv)`; `get_means(d2, y1)` matches `get_means(d, y1)`: point 1e-10, SE 1e-8. surveycore's replicate variance does not read the FPC, so the drop moves no number |
| R-5 | The full round trip preserves a Fay design's standard error | `src <- survey::as.svrepdesign(even$sv, type = "Fay", fay.rho = 0.3)` on the §3.5 fixture; `sv_rt <- as_svydesign(from_svydesign(src))` | `survey::svymean(~y1, sv_rt)` against `survey::svymean(~y1, src)`: point 1e-10 and SE 1e-8. This is the parity row for the recovered shrinkage factor. Use the §3.5 fixture for isolation, not because §3.1 fails: §3.1 builds a Fay design without error, and §3.5 states its own even PSU layout rather than inheriting one |

---

## 9. Condition tests

Five condition classes are new. Two more are classes surveycore already uses,
raised here on a new trigger. All seven come from an exported conversion
function and reach the user directly, so all seven take the **dual pattern**:
`expect_error()` or `expect_warning()` with `class =`, plus a snapshot. Put the
class assertion and the snapshot in separate `test_that()` blocks.

The dual pattern applies to the two reused classes as well. They arrive from a
conversion route, with a CLI message written for that route, so a snapshot is
the only check on the text.

Each class carries at least one class assertion and one snapshot. A second
trigger for a class that already has both — C-3 and C-12 — carries the class
assertion alone. The message is the same and one snapshot of it is enough.

| Row | Class | Level | How to trigger it | Assertions |
|---|---|---|---|---|
| C-1 | `surveycore_error_repweights_names_lost` | ERROR | Build a `survey::svrepdesign()` whose replicate matrix carries a partly filled `colnames()` — for four columns, `colnames(m) <- c("a", "", "c", "")`. An empty string cannot name a column | `expect_error(from_svydesign(sv), class = "surveycore_error_repweights_names_lost")` |
| C-2 | `surveycore_error_repweights_names_lost` | ERROR | The same construction | `expect_snapshot(error = TRUE, from_svydesign(sv))` |
| C-3 | `surveycore_error_repweights_names_lost` | ERROR | Build a design whose replicate matrix repeats a column name — `colnames(m) <- c("a", "a", "b", "c")`. Writing it would collapse two replicates into one column | `expect_error(..., class = "surveycore_error_repweights_names_lost")` |
| C-4 | `surveycore_error_repwt_name_collision` | ERROR | Add a decoy column to the data before building the survey design: `df[["..surveycore_repwt_2.."]] <- 1`. Then build a four-column unnamed replicate design on that data, so the route generates `..surveycore_repwt_1..` to `..surveycore_repwt_4..` and hits the decoy | `expect_error(from_svydesign(sv), class = "surveycore_error_repwt_name_collision")` |
| C-5 | `surveycore_error_repwt_name_collision` | ERROR | The same construction | `expect_snapshot(error = TRUE, from_svydesign(sv))` |
| C-6 | `surveycore_warning_replicate_fpc_dropped` | WARN | `rep_bridge_sc(fpc_col = "fpc")` | `expect_warning(result <- as_svydesign(d), class = "surveycore_warning_replicate_fpc_dropped")` — capture the result from the return value, never with `tryCatch()` or `withCallingHandlers()` |
| C-7 | `surveycore_warning_replicate_fpc_dropped` | WARN | The same design | `expect_snapshot(as_svydesign(d))`. The snapshot must show the dropped column name |
| C-8 | `surveycore_error_fay_rho_unrecoverable` | ERROR | `as_survey_replicate()` with `type = "Fay"` and a `scale` whose product with the replicate count is below 1. Build the data inline with four replicate weight columns and pass `scale = 0.1`: the product is 0.4, and the shrinkage factor it implies is below 0. No validator checks the value of `scale`, so the design builds | `expect_error(as_svydesign(d), class = "surveycore_error_fay_rho_unrecoverable")` |
| C-9 | `surveycore_error_fay_rho_unrecoverable` | ERROR | The same design | `expect_snapshot(error = TRUE, as_svydesign(d))`. The snapshot must show the recorded scale |
| C-10 | `surveycore_error_replicate_type_unsupported` | ERROR | `survey::as.svrepdesign(even$sv, type = "subbootstrap")` on the §3.5 fixture. `survey` accepts this type and stores the literal string; surveycore does not accept it | `expect_error(from_svydesign(src), class = "surveycore_error_replicate_type_unsupported")` |
| C-11 | `surveycore_error_replicate_type_unsupported` | ERROR | The same design | `expect_snapshot(error = TRUE, from_svydesign(src))`. The snapshot must name the offending type and the accepted set |
| C-12 | `surveycore_error_replicate_type_unsupported` | ERROR | `survey::as.svrepdesign(even$sv, type = "mrbbootstrap")`. Build it inside `suppressWarnings()`: `survey` emits `Design is sampled with replacement: only first stage used` at construction, and that warning belongs to the fixture | `expect_error(from_svydesign(src), class = "surveycore_error_replicate_type_unsupported")`. No snapshot — C-11 covers the message, and this row covers the second reachable type |
| C-13 | `surveycore_error_empty_data` | ERROR | `rep_bridge_zero_row()` from §3.6 | `expect_error(from_svydesign(src), class = "surveycore_error_empty_data")`. Before the change this call returns an empty design and raises nothing |
| C-14 | `surveycore_error_empty_data` | ERROR | The same design | `expect_snapshot(error = TRUE, from_svydesign(src))` |
| C-15 | `surveycore_error_repweights_empty` | ERROR | The §3.7 design: the exported `survey_replicate` class constructor with `repweights = character(0)` in the `variables` list | `expect_error(as_svydesign(d), class = "surveycore_error_repweights_empty")`. Before the change the call reaches `survey` and fails with `missing value where TRUE/FALSE needed` |
| C-16 | `surveycore_error_repweights_empty` | ERROR | The same design | `expect_snapshot(error = TRUE, as_svydesign(d))` |
| C-17 | `surveycore_error_fay_rho_unrecoverable` | ERROR | A Fay design that records **no** scale. Build it with the exported `survey_replicate` class constructor, passing a `variables` list with `type = "Fay"` and no `scale` key — the same construction issue #198's reproduction uses. That constructor's validator checks neither `scale` nor `type`, so the design builds with `@variables$scale` `NULL` — measured | `expect_error(as_svydesign(d), class = "surveycore_error_fay_rho_unrecoverable")` |
| C-18 | `surveycore_error_fay_rho_unrecoverable` | ERROR | The same design | `expect_snapshot(error = TRUE, as_svydesign(d))`. The snapshot must show that no scale was recorded |

The decoy name in C-4 must match the padding width the route uses. Four
replicate columns give width 1, so the decoy is `..surveycore_repwt_2..`. A
twenty-column design would need `..surveycore_repwt_02..`. Keep the replicate
count under ten in that block so the name stays unpadded.

**Both arms of the Fay condition are reachable, by different routes.** Measured
on this worktree:

| Route | Recorded scale | Shrinkage factor | Row |
|---|---|---|---|
| `survey_replicate()` class constructor, no `scale` key | `NULL` | none | C-17, C-18 |
| `as_survey_replicate(type = "Fay")`, no `scale` argument | `1 / n_rep` | `0`, legal | E-10 |
| `as_survey_replicate(type = "Fay", scale = 0.05)`, 8 replicates | `0.05` | `-0.581` | C-8, C-9 |

`as_survey_replicate()` fills a default scale for every type, and the Fay
default recovers a legal shrinkage factor of 0 — row E-10 asserts that
outcome. The missing-scale state comes from the exported `survey_replicate`
class constructor instead: its `variables` argument is an untyped list and its
validator checks neither `scale` nor `type`. Neither arm may carry a coverage
exemption.

Snapshots live in `tests/testthat/_snaps/conversion.md` and are committed.
Review every diff with `testthat::snapshot_review()`. Never run a blind
`snapshot_accept()`. Do not reformat the existing file or change its line
endings when the new snapshots are appended.

---

## 10. Invariants and the both-modes rule

### 10.1 `test_invariants()`

`test_invariants(design)` runs once per constructor per test FILE, in the first
block that builds with that constructor
(`.claude/rules/testing-surveycore.md`). `tests/testthat/test-conversion.R`
already calls it for `as_survey()`. Add exactly two calls and no more:

| Construction route | Where the one call goes |
|---|---|
| `as_survey_replicate()` | The first new block that builds a surveycore replicate design with it — row E-1 |
| `from_svydesign()` | The first new block that converts a `svyrep.design` — row I-1 |

`from_svydesign()` earns its own call. The helper exists to catch a malformed
object returned through a construction route the class validators do not see,
and `from_svydesign()` is exactly such a route. It is also the route under
test.

Add no `test_invariants()` call to any other block. Repeating it moves package
coverage by 0.0000 points (issue #169).

The §3.7 construction takes no call either. The rule names the four public
constructors, the class constructor is not one of them, and that object exists
only to reach a refusal in rows C-15 and C-16.

### 10.2 The both-modes rule does not apply here

The both-modes rule covers the functions that accept either a survey design
object or a plain data frame: `extract_dataset_metadata()`,
`set_dataset_metadata()` and the ten dataset-metadata wrappers. That is the
whole current set.

`from_svydesign()` accepts a `survey` design object. `as_svydesign()` accepts a
surveycore design object. Neither takes two input modes, so no row in this
document runs twice. Do not fan any row out.

---

## 11. Recorded divergence — do not read this as missing coverage

Issue #198 asks that `type = "bootstrap"` with an FPC produce a surveycore
error, rather than `survey`'s `Separate fpc not needed for bootstrap`. The
decision recorded for this change is different: bootstrap with an FPC produces
the drop warning and a working design.

Row E-4 therefore expects a warning, not an error. That holds for every
replicate type, bootstrap included. No row in this document expects
`as_svydesign()` to fail on a replicate design that records an FPC.

One more expectation reads oddly and is correct. `subbootstrap` and
`mrbbootstrap` are replicate types `survey` builds and surveycore refuses.
Rows C-10 to C-12 expect `from_svydesign()` to raise, not to convert. The
refusal is deliberate: surveycore stores nine replicate types, and a type
outside that set would be recorded as something it is not.

---

## 12. Profile gates

Run all six before the pull request opens.

| Gate | Command | Pass condition |
|---|---|---|
| document | `devtools::document()` | No change to `NAMESPACE`; the only changed file under `man/` is the page for `from_svydesign()` |
| test | `Rscript -e "devtools::test()"` | 0 failures and 0 warnings |
| run_examples | `devtools::run_examples()` | Every example runs |
| R CMD check --as-cran | `R CMD check --as-cran --no-manual` | 0 errors, 0 warnings, at most the two pre-approved notes |
| pkgdown | `pkgdown::build_site()` | Builds with no error |
| covr | `NOT_CRAN=true Rscript -e "covr::package_coverage()"` | Package coverage at or above 95%; every new line in the conversion source reached |

For the edit-and-run loop use the fast path:
`NOT_CRAN=false Rscript -e "testthat::test_local()"`. It skips the 11 slow
files. `devtools::test()` cannot reach that speed — it sets `NOT_CRAN=true`
unconditionally. Always measure coverage with `NOT_CRAN=true`, or the 11 files
skip and coverage reads several points low (issue #159).

---

## 13. Row count summary

| Group | Rows | IDs |
|---|---|---|
| Import — oracle (§6.1) | 4 | I-1 to I-4 |
| Import — structure (§6.2) | 8 | I-5 to I-11, I-22 |
| Import — named columns (§6.3) | 5 | I-12 to I-14, I-23, I-24 |
| Import — edge cases (§6.4) | 8 | I-15 to I-21, I-26 |
| Export (§7) | 10 | E-1 to E-10 |
| Full round trip (§8) | 5 | R-1 to R-5 |
| Conditions (§9) | 18 | C-1 to C-18 |
| Total | 58 | |

The I-25 entry in §6.4 is not a row. It records a state that cannot be
reached and says why, so a later reader does not read the absence as an
oversight. It carries no `test_that()` block.

Every row is one `test_that()` block with one described behaviour. Every
condition class carries a class assertion and a snapshot. C-3 and C-12 carry
the class assertion alone, because each is a second trigger for a class whose
message another row already snapshots. Every cell of the §5 matrix has an
oracle row that asserts its own preconditions, and every line of the §5.1
behaviour table names the rows that cover it.
