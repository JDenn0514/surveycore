# Test spec — haven-labelled (issue #175)

**Version**: 1.0
**Date**: 2026-08-28
**Status**: Draft — Stage 1 output

## What is being validated

Two independent defects, plus four smaller items, all reachable from one
`haven::read_sav()` import.

1. **Storage.** A column read from SPSS, Stata or SAS carries the
   `haven_labelled` class. A survey design object must not store that class.
   It must store the base type, and it must keep every attribute the import
   set: the `label` string, the `labels` value-label vector, and the SPSS
   `na_values` and `na_range` vectors. Twelve of seventeen public entry
   points currently abort on such a column when the `haven` namespace is not
   loaded.
2. **Ordinality.** `get_corr(method = "polychoric")` currently refuses a
   numeric column whose values are whole numbers, even when it has few
   distinct values. It must accept one. This is not specific to labelled
   input: a plain `c(1, 2, 3)` double is refused in exactly the same way.
3. Construction must succeed when a **design** variable — the weight column,
   the FPC column, the cluster and stratum columns — carries the labelled
   class.
4. `set_val_labels()` must accept a labelled column, in both input modes.
5. Converting from a `survey` package design must populate the metadata
   system, not leave it empty.
6. The runtime check for the `haven` namespace must be reachable in both
   states from a test.

---

## 1. Reference oracles

| Item | Oracle | Why this oracle |
|---|---|---|
| Every estimate on a labelled column | **The same estimate on the same column with the class removed by hand.** Build two designs from one frame — one with the labelled class on the outcome, one without — and compare. | This is an identity oracle, not an approximation. After the fix both inputs are the same object, so any difference at all is a defect. It is stronger than an external oracle and needs no third package. |
| Every estimate on a design whose **weight** or **FPC** column is labelled | The same estimate from a design built from the same frame with a plain weight or FPC column | Same reasoning. FPC changes the standard error, so this row exercises a number that actually moves. |
| `get_corr(method = "polychoric")` on a whole-valued numeric column | The same call with that column converted to an ordered factor whose levels are its distinct values in ascending order | The estimator derives its category codes by sorting the distinct values ascending, so the two forms describe the same ordinal variable. |
| Existing variance and correlation numbers | `survey::svymean`, `survey::svytotal`, `survey::svyquantile`, `polycor::polychoric`, `polycor::polyserial`, already wired into the existing numerical test files | None of those files changes. They are a regression fence, not a new oracle. |

No new external dependency is needed. `survey`, `srvyr`, `polycor` and
`haven` all stay in `Suggests` and keep their existing
`skip_if_not_installed()` guards.

---

## 2. Datasets and fixtures

### 2.1 Base frame

`make_survey_data()` from `tests/testthat/helper-test-data.R` for every unit
test. Use `design = "replicate"` and `design = "twophase"` where the row
says so.

Do **not** reuse `make_survey_data(with_labels = TRUE)` as the labelled
fixture. It attaches the `label` and `labels` attributes to a plain vector
and never sets a class
(`tests/testthat/helper-test-data.R:538-550`). A plain double carrying a
`labels` attribute is not a labelled vector and never reaches the dispatch
that fails. That is one of the two reasons 8,863 passing tests never caught
this defect.

### 2.2 New fixture builders

Add to `tests/testthat/helper-test-data.R`. Three builders. None of them
may load `haven`.

```r
# Attach the haven labelled class to a vector, plus its label attributes.
make_labelled <- function(x, labels, label = NULL) {
  attr(x, "labels") <- labels
  if (!is.null(label)) {
    attr(x, "label") <- label
  }
  attr(x, "class") <- c("haven_labelled", "vctrs_vctr", typeof(x))
  x
}
```

```r
# The SPSS variant, which adds declared-missing metadata.
make_labelled_spss <- function(
  x,
  labels,
  label = NULL,
  na_values = NULL,
  na_range = NULL
) {
  x <- make_labelled(x, labels, label)
  if (!is.null(na_values)) {
    attr(x, "na_values") <- na_values
  }
  if (!is.null(na_range)) {
    attr(x, "na_range") <- na_range
  }
  attr(x, "class") <- c(
    "haven_labelled_spss",
    "haven_labelled",
    "vctrs_vctr",
    typeof(x)
  )
  x
}
```

```r
# A haven tagged NA, built with base R. The tag character occupies byte 5
# of the NA_real_ payload in little-endian order.
make_tagged_na <- function(tag) {
  r <- writeBin(NA_real_, raw(), endian = "little")
  r[[5L]] <- as.raw(utf8ToInt(tag))
  readBin(r, "double", endian = "little")
}
```

The class vectors above are the exact vectors `haven` builds. The tagged-`NA`
construction was verified byte-identical to `haven::tagged_na()` for the
tags `a`, `b` and `z`.

`make_tagged_na()` assumes an 8-byte double and little-endian byte order.
Give it its own guard block so a platform where that fails says so loudly
instead of producing a silent plain `NaN`:

| Row | Assertion |
|---|---|
| F-1 | `make_tagged_na("a")` is `NA` |
| F-2 | `make_tagged_na("a")` is a double |
| F-3 | With `haven` installed, `haven::na_tag(make_tagged_na("a"))` is `"a"`. Guard the block with `skip_if_not_installed("haven")`. |
| F-4 | `make_tagged_na("a")` and `make_tagged_na("b")` are not identical |
| F-5 | With `haven` installed, `make_labelled()` output is `identical()` to `haven::labelled()` output for the same values, labels and label. Guard with `skip_if_not_installed("haven")`. |
| F-6 | With `haven` installed, `make_labelled_spss()` output is `identical()` to `haven::labelled_spss()` output. Guard the same way. |

F-5 and F-6 are what make every other labelled row in this document
meaningful. If the fixture drifts from what `haven` actually produces, the
whole suite tests a shape no user will ever have. They are also the check
that catches an upstream change in `haven`'s class vector — the same risk the
rebuild carries, from the other direction.

### 2.3 Column shapes the fixtures must be able to produce

| Shape | Built as |
|---|---|
| labelled double, coded scale, every code labelled | `make_labelled(as.double(sample(1:4, n, TRUE)), c(a = 1, b = 2, c = 3, d = 4))` |
| labelled double with an unlabelled code present in the data | same, but omit one code from `labels` |
| labelled double, more than 10 distinct codes | 11 or 12 distinct whole values |
| labelled **integer** | `make_labelled(sample(1:4, n, TRUE), c(...))` — the control that shows the ordinality gap was never about storage class |
| labelled **nominal** column | 4 distinct codes with unordered category names |
| labelled SPSS column | `make_labelled_spss(..., na_values = 99, na_range = c(90, 99))` |
| labelled column containing a tagged `NA` | insert `make_tagged_na("r")` values and add a `labels` entry keyed to it |
| labelled **weight** column | `make_labelled(df$wt, c(...))` — values must stay strictly positive |
| labelled **FPC** column | `make_labelled(df$fpc, c(...))` |
| labelled cluster and stratum columns | `make_labelled(df$psu, ...)`, `make_labelled(df$strata, ...)` |
| labelled replicate weight columns | all `repwt_*` columns of a replicate frame |
| labelled **character** column | `make_labelled(sample(c("a", "b", "c"), n, TRUE), c(Apple = "a", Banana = "b", Cherry = "c"))` — the class chain ends in `"character"` |
| a column stacking a caller's own class above the labelled class | take a `make_labelled()` column and prepend one entry: `class(x) <- c("my_extra_class", class(x))` |
| a column carrying `labels` but **no** class | `structure(x, labels = c(...))` — this is what the existing `with_labels = TRUE` option produces, and it must be stored untouched |
| a whole-valued double with an `Inf` | `c(1, 2, 3, Inf)` repeated to length — for §4.10 |
| a whole-valued double with a fractional value | `c(1, 2, 3, 2.5)` repeated to length |
| a whole-valued double at the distinct-value boundary | exactly 10 distinct whole values, and separately exactly 11 |

### 2.4 Real datasets

`nhanes_2017` for one row only: proof that the change is a no-op on bundled
data. Every bundled dataset already stores plain columns carrying label
attributes, so the storage fix must not alter any of them.

Do not add real-dataset rows for anything else. The existing numerical files
own that ground.

---

## 3. The order-independent regression guard

This is the most important design decision in this document. Get it wrong and
the whole suite passes with the defect unfixed.

**Do not write `expect_false("haven" %in% loadedNamespaces())`.** It will
fail, and it will fail for a reason unrelated to the code under test. Seven
existing test files call `haven::tagged_na()`:

| File | Lines |
|---|---|
| `tests/testthat/test-analysis-corr.R` | 1184, 1188 |
| `tests/testthat/test-analysis-freqs.R` | 1457, 1461 |
| `tests/testthat/test-analysis-helpers.R` | 1344 |
| `tests/testthat/test-analysis-means.R` | 770, 774 |
| `tests/testthat/test-analysis-quantiles.R` | 1047, 1051 |
| `tests/testthat/test-analysis-ratios.R` | 999, 1003 |
| `tests/testthat/test-analysis-totals.R` | 582, 586 |

`haven::` loads the namespace. testthat runs all 44 files in one R session in
alphabetical order, and the earliest of those seven is the 4th file. So 40 of
44 files run with `haven` present, and any labelled-input test placed later
in the alphabet would pass even with the defect unfixed.

**Assert the stored state instead.** For every construction route:

```r
expect_false(inherits(survey_data(d)$q, "haven_labelled"))
```

This is deterministic, independent of namespace load order, independent of
file order, and it fails on the current `develop`. Pair it with an assertion
that the labels survived, so the test cannot pass by discarding information:

```r
expect_identical(attr(survey_data(d)$q, "labels", exact = TRUE), lbls)
expect_identical(extract_val_labels(d, q)$q, lbls)
```

Do not move or delete the seven existing tagged-`NA` blocks. They must keep
passing unchanged.

---

## 4. Per-item test plan

### 4.1 Storage — construction routes

New file: `tests/testthat/test-labelled-storage.R`.

Call `test_invariants(design)` once for each constructor exercised in this
file, in the first block that builds with it: once for `as_survey()`, once
for `as_survey_replicate()`, once for `as_survey_twophase()`, once for
`as_survey_nonprob()`. Not in every block.

| Row | Scenario | Assertion |
|---|---|---|
| S-1 | `as_survey()` on a frame with a labelled outcome column | no stored column inherits `haven_labelled`; `labels` attribute retained; `extract_val_labels()` returns the labels |
| S-2 | `as_survey_replicate()`, same frame | same three assertions |
| S-3 | `as_survey_nonprob()`, same frame | same three assertions |
| S-4 | `as_survey_twophase()` built on a labelled phase-1 design | same three assertions |
| S-5 | Every column of the frame labelled, not just one | no stored column inherits `haven_labelled` |
| S-6 | No column labelled | the stored frame is identical to the input frame |
| S-7 | `nhanes_2017` through `as_survey()` | the stored frame is identical to `nhanes_2017`; no column type changes |
| S-8 | A labelled **integer** column | not stored as labelled; still an integer after storage |
| S-9 | A labelled SPSS column | not stored as labelled; `labels`, `label`, `na_values` and `na_range` all readable from the stored column |
| S-10 | A labelled column holding tagged `NA` values | not stored as labelled; the tagged `NA` values are still `NA`; with `haven` installed, the tag still reads back — guard that one expectation with `skip_if_not_installed("haven")` |
| S-11 | A frame whose columns carry `label` and `labels` attributes but **no** class | stored unchanged; this proves the fix keys on the class and not on the attributes |
| S-12 | A column carrying the class `"labelled"` alone, with no `"vctrs_vctr"` in its class vector | stored **unchanged**, class retained. This legacy shape does not reach the failing dispatch and is deliberately left alone. |
| S-13 | A tibble input with a labelled column | still a tibble after storage; no column inherits `haven_labelled` |

### 4.2 Storage — design variables

These are the rows that isolate the construction-time half of the fix. All
four abort on the current `develop`; the first two abort even with the other
half of the fix in place. Give each one both a construction assertion and a
numerical assertion.

| Row | Scenario | Assertion |
|---|---|---|
| S-14 | `as_survey()` where the **weight** column is labelled | constructs without error; `get_means()` on a plain outcome returns the same estimate and the same standard error as the design built from the same frame with a plain weight column |
| S-15 | `as_survey()` where the **FPC** column is labelled | constructs without error; `get_totals()` returns the same estimate and standard error as the plain-FPC design. The FPC changes the standard error, so this row must compare the standard error and not only the point estimate. |
| S-16 | `as_survey()` where **both** the cluster and the stratum columns are labelled, with `nest = FALSE` | constructs without error; `get_means()` matches the plain-column design |
| S-17 | The same frame as S-16 with `nest = TRUE` | constructs without error; matches the plain-column design. This passes on the current `develop` by accident, because that path skips one check. Keep the row as a regression fence. |
| S-18 | Only the cluster column labelled; then only the stratum column labelled | both construct; both match |
| S-19 | `as_survey()` where the `probs` column is labelled and `weights` is absent | constructs; the derived weights equal `1 / probs` |
| S-20 | `as_survey_replicate()` where every replicate weight column is labelled | constructs; `get_means()` matches the plain-column design |
| S-21 | `as_survey()` where the weight column is labelled **and** contains a zero | still raises `surveycore_error_weights_nonpositive`. Dual pattern. The fix must not swallow a real validation failure. |
| S-22 | `as_survey()` where the weight column is labelled **and** every value is zero | still raises `surveycore_error_weights_all_zero`. Dual pattern. |
| S-23 | `as_survey()` where the FPC column is labelled and contains a non-positive value | still raises `surveycore_error_fpc_nonpositive`. Dual pattern. |
| S-23a | `as_survey()` where the FPC column is labelled and contains an `NA` | still raises `surveycore_error_fpc_na`. Dual pattern. |

Three more constructors reach the same weight validation, and only the
`as_survey()` route above was measured. Cover all three, so the fix is
confirmed rather than assumed:

| Row | Scenario | Assertion |
|---|---|---|
| S-23b | `as_survey_replicate()` where the **weight** column is labelled | constructs; `get_means()` matches the plain-weight design |
| S-23c | `as_survey_replicate()` where the **FPC** column is labelled | constructs; matches the plain-FPC design |
| S-23d | `as_survey_nonprob()` where the **weight** column is labelled | constructs; `get_means()` matches the plain-weight design |
| S-23e | `as_survey_nonprob()` where the **replicate weight** columns are labelled | constructs; matches the plain-column design |
| S-23f | `as_survey_replicate()` where the weight column is labelled and contains a zero | still raises `surveycore_error_weights_nonpositive`. Dual pattern. |
| S-23g | `as_survey_nonprob()` where the weight column is labelled and contains a zero | still raises the class that constructor uses for a non-positive weight. Dual pattern. |

Two-phase and SRS shapes, neither previously covered:

| Row | Scenario | Assertion |
|---|---|---|
| S-23h | `as_survey_twophase()` where the phase-2 `strata`, `probs` or `fpc` column is labelled | constructs; `get_means()` matches the plain-column design |
| S-30 | `as_survey_twophase()` where the **`subset`** column is labelled | **still raises `surveycore_error_subset_not_logical`.** A labelled column is never logical, so this must keep failing. Dual pattern. This row exists to stop an over-broad fix from making a genuinely invalid input construct. |
| S-31 | `as_survey(data, weights = wt)` with a labelled `wt`, no `ids` and no `strata` — the SRS shape | constructs; `get_means()` matches the plain-weight equivalent |
| S-32 | `as_survey()` with a labelled `probs` column and no `weights` | constructs; the derived weights equal one divided by the probabilities, matching the plain-`probs` design |
| S-33 | A labelled **weight** column containing a tagged `NA` | still raises whichever weight-validation class applies to a missing weight, or constructs and matches the plain equivalent — assert whichever the code does, and state it in the block description. A tagged `NA` is an `NA`, so the existing missing-weight handling governs. |
| S-34 | A labelled **FPC** column containing a tagged `NA` | still raises `surveycore_error_fpc_na`. The FPC must be fully observed, and a tagged `NA` is an `NA`. Dual pattern. |

Tolerance for the comparison rows: **exact**. Use `expect_identical()` on
the numeric result columns, or `expect_equal(tolerance = 0)`.

> Justification for departing from the default tolerances of 1e-10, 1e-8 and
> 1e-6: after the fix, the labelled input and the plain input are the same
> object by the time any arithmetic runs. The two calls execute identical
> code on identical bytes. A difference of any size is a defect, not
> floating-point noise. A loose tolerance here would hide exactly the class
> of bug the row exists to catch.

### 4.3 Storage — routes that no constructor sees

Put these in `tests/testthat/test-s7-classes.R`, beside the other
class-level tests.

| Row | Scenario | Assertion |
|---|---|---|
| S-24 | Construct `survey_taylor()` directly with a labelled frame. It is an exported class constructor, so this is a supported public call. Take its `variables` and `metadata` arguments from a design built the normal way with `as_survey()`. | no stored column inherits `haven_labelled` |
| S-25 | The same for `survey_replicate()`, `survey_twophase()` and `survey_nonprob()` | same. All four concrete design classes must be covered, because the behaviour comes from a shared parent and inheritance must be proven for each child. |
| S-26 | Assign a labelled frame straight onto an already-built design, with `d@data <- labelled_df` | no stored column inherits `haven_labelled` |
| S-27 | Assign a labelled frame, then read an estimate | `get_means()` succeeds and matches the plain-frame result |
| S-28 | Assign a frame with no labelled column | the stored frame is identical to the assigned frame |

S-26 is the only place in this document that reaches past the accessor
`survey_data()` and writes the stored frame directly. That is deliberate:
direct assignment is how the sibling packages modify a design, so it is the
route this row exists to cover. Every other row reads through the public
accessor.

Error paths on this route reach the class validators, not a constructor's
argument checks, so they take `expect_error(class = ...)` **only** — no
snapshot. Class-validator messages are plain text rather than the formatted
three-bullet style, so snapshotting them locks in text that was never
designed to be read that way.

| Row | Scenario | Assertion | Pattern |
|---|---|---|---|
| S-35 | Construct `survey_taylor()` directly with a labelled frame whose weight column holds a zero | raises `surveycore_error_weights_nonpositive` | `class=` only |
| S-36 | Assign a labelled frame that is missing a named design column | raises `surveycore_error_design_var_missing` | `class=` only |
| S-37 | Assign a labelled frame whose weight column is a labelled **character** column | raises `surveycore_error_weights_not_numeric`. The strip runs first, leaving a plain character column, which is still not numeric — so the validator still catches it. | `class=` only |

S-37 matters more than it looks: it confirms the strip did not make an
invalid input look valid. A labelled character weight column must stay
rejected.
| S-29 | Build a design, then run a grouped `get_quantiles()` with three probabilities | succeeds; the result matches the plain-column result. This exercises the repeated internal writes that happen inside a per-cell loop. |

### 4.4 The analysis sweep

New file: `tests/testthat/test-labelled-analysis.R`. One block per row.
Every row builds two designs from one frame — labelled outcome and plain
outcome — and asserts the results are identical.

Call `test_invariants(design)` once for each constructor this file exercises,
in the first block that builds with it: once for `as_survey()`, once for
`as_survey_replicate()`, once for `as_survey_twophase()`, once for
`as_survey_nonprob()`. Not in every block. The rule is per constructor per
FILE, so these calls are additional to the ones in §4.1 — a different file
needs its own.

Twelve of seventeen entry points fail today. Cover all seventeen, so the
five that pass stay passing.

| Row | Call | Notes |
|---|---|---|
| A-1 | `get_freqs(d, q)` | |
| A-2 | `get_freqs(d, q, group = g)` | `g` plain |
| A-3 | `get_freqs(d, q, group = g_lbl)` | grouping column labelled |
| A-4 | `get_freqs(d, q, group = c(g1, g2))` | two grouping columns, both labelled |
| A-5 | `get_freqs(d, q, label_values = FALSE)` | |
| A-6 | `get_freqs(d, q, na.rm = FALSE)` | labelled column containing `NA` |
| A-7 | `get_means(d, q)` | |
| A-8 | `get_means(d, q, group = g)` | |
| A-9 | `get_means(d, q, na.rm = TRUE)` | |
| A-10 | `get_means(d, q)` on a **replicate** design | |
| A-11 | `get_means(d, q)` on a **two-phase** design | |
| A-12 | `get_means(d, q)` on a **nonprob** design | |
| A-13 | `get_totals(d, q)` | passes today only by accident; keep as a fence |
| A-14 | `get_totals(d, q, group = g)` | |
| A-15 | `get_quantiles(d, q)` | |
| A-16 | `get_quantiles(d, q, group = g)` | |
| A-17 | `get_variance(d, q)` | |
| A-18 | `get_variance(d, q, group = g)` | |
| A-19 | `get_covariance(d, c(q1, q2))` | both labelled |
| A-20 | `get_ratios(d, q1, q2)` | both labelled |
| A-21 | `get_corr(d, c(q1, q2))` — default method | |
| A-22 | `get_t_test(d, q, g)` | |
| A-23 | `get_diffs(d, q, g)` | plain grouping |
| A-24 | `get_diffs(d, q, g_lbl)` | labelled grouping; this is the coercion-to-factor path |
| A-25 | `get_pairwise(d, q, g)` | |
| A-26 | `get_anova(d, q ~ g)` | |
| A-27 | `survey_glm(d, q ~ g)` | |
| A-28 | `get_anova()` on that fitted model | |
| A-29 | `clean()` on that fitted model | |
| A-30 | `get_effective_n(d, q)` | |
| A-31 | `meta()` on any result above | `method` and the design type are unchanged |

Every row: `expect_no_error()` **and** the identity comparison against the
plain-column design. An error-free run alone is not enough — a silent
numerical change would pass it.

Tolerance: exact, with the justification in §4.2.

### 4.5 Group labels and tagged `NA`

File: `tests/testthat/test-labelled-analysis.R`, the same file as §4.4.

| Row | Scenario | Assertion |
|---|---|---|
| G-1 | Grouping column labelled with the class; `label_values = TRUE` | the group column of the result is a factor whose levels are the label strings, ordered by ascending code |
| G-2 | Same, `label_values = FALSE` | the group column holds the raw codes |
| G-3 | Grouping column labelled with the class and containing a tagged `NA`, with a `labels` entry keyed to that tagged `NA`; `na.rm = FALSE`, `label_values = TRUE` | **A row appears for the tagged-`NA` level, under its label.** The label is among the factor levels of the group column and it carries a row. Corrected 2026-08-31 — see the note below. |
| G-3a | Same call, `na.rm = TRUE` | **No row appears for the tagged-`NA` level**, though its label stays among the factor levels. This is where the absence lives. |
| G-4 | Same as G-3 with the `haven` availability stubbed to `FALSE` | no error; the tagged-`NA` label is **not** among the factor levels, because resolving the tag is the one thing that needs `haven`. Every non-tagged label still resolves. See §4.9. |
| G-5 | Grouping column labelled but with a code present in the data that has no label | the code is **not dropped** — its rows are present and the counts still total the full sample — but how it renders depends on `label_values`. With `label_values = FALSE` the raw code appears. With `label_values = TRUE` the cell renders `NA`, because the code has no label to resolve to. Assert both. Corrected 2026-08-31. |
| G-6 | Grouping column is a plain factor | levels keep their declared order, unchanged behaviour |
| G-7 | Grouping column labelled, containing a tagged `NA`, and **also** a whole-valued double with few distinct values, under `get_corr(method = "polychoric")` | succeeds. This is the one combination where both new behaviours in this work meet: a tagged `NA` in a column that the new ordinality rule now accepts. The tagged `NA` is `NA` to the estimator, so it is excluded pairwise like any other missing value. |

**Note on G-3 and G-3a — corrected 2026-08-31.** This document has now said
three different things about the tagged-`NA` level. The measurement below is
the one to trust, because it was taken on a grouped call, which is what these
rows describe.

Measured on `develop` at `68f8992`, grouping column labelled with a `labels`
entry keyed to the tagged `NA`, `label_values = TRUE`:

| Call | Tagged-`NA` label among the factor levels | Row present for it |
|---|---|---|
| `na.rm = FALSE` | yes | **yes** |
| `na.rm = TRUE` | yes | no |

So the absence belongs to G-3a, not to G-3. The previous draft asserted the
absence for both, and the draft before that asserted presence for both.
Neither was right.

**How the earlier error happened**, so it is not repeated: the ungrouped form
behaves differently. Called as `get_freqs(d, g)` with `g` as the analysis
variable, `na.rm = FALSE` yields a third row keyed plain `NA` rather than a
row under the tagged-`NA` label. Measuring the ungrouped form and writing the
result into a grouped row is what produced the wrong assertion. These rows
describe a **grouping** column; measure them that way.

The rule stands: write these rows to assert what the code does, and put the
reason in the block description, so the next reader does not "fix" the test
to match an expectation. The behaviour is pre-existing and this work does not
change it. If it is judged a defect, it needs its own issue.

**Note on G-4.** The two rows G-3 and G-4 differ only in whether `haven` is
reachable, and they assert different level sets. That is the whole point of
the stub described in §4.9: without it, whichever of the two runs second
would depend on namespace load order.

### 4.6 Metadata

In `tests/testthat/test-metadata-system.R`.

The both-modes rule applies here. Run a row in both the survey-object mode
and the data-frame mode only when the mode changes what the row asserts.

| Row | Scenario | Modes | Why |
|---|---|---|---|
| M-1 | `set_val_labels()` on a labelled column | **both** | The two modes are fixed by different mechanisms and take different code paths: the survey mode is fixed because the class is gone from storage, the data-frame mode is fixed inside the validation itself. A data frame is never normalised, so the frame row cannot be inferred from the survey row. **Corrected 2026-09-01: this fails in the data-frame mode only.** The survey mode was fixed by the property setter that landed earlier in this feature, so by the time the frame fix is written the survey row is already green. Run both modes regardless — the Modes column governs which modes a row runs in, not which were red. |
| M-2 | `set_val_labels()` on a labelled column where a code in the data has no label | **both** | Must still raise `surveycore_warning_missing_labels`. This warning is newly reachable, because the validation no longer aborts before it. Use `expect_warning(result <- ..., class = ...)`. |
| M-3 | `extract_val_labels()` on a labelled column | **both** | The row asserts a value read back out of storage, and the two modes store it in different places. The same caution as M-1 applies: the survey mode may already be green when the frame fix is written. |
| M-4 | `set_var_label()` then `extract_var_label()` on a labelled column | survey only | Passes today in both modes and neither path is touched. One mode is enough. |
| M-5 | `extract_metadata()` on a labelled column | survey only | Same reasoning |
| M-6 | `extract_missing_codes()`, `extract_higher_is()`, `extract_question_preface()`, `extract_var_note()` on a labelled column | survey only | Same reasoning. One block may cover all four. |
| M-7 | `classify_question_type()` on labelled columns | survey only | Never reads a column value or class; its answer cannot change |
| M-8 | A labelled SPSS column: after construction, read `na_values` and `na_range` back from the stored column | survey only | The frame mode does not store anything |
| M-9 | `set_val_labels()` on a plain column | survey only | Regression fence: the fix must not change the plain path |

**Note on the M-row red runs, corrected 2026-09-01.** The M-1 note originally
said the row "currently fails in both modes". Measured on `develop` at
`b7f8b45`, it failed in the **data-frame mode only** — four errors, all
`vctrs_error_cast`. Three parties measured this independently and agreed: the
builder, the tester, and the reviewer, the last from source.

The reason is the same one that makes §4.11a's list unreliable. This document
was written against `cf6f153`, before the feature split into nine PRs. The
property setter on the design's `data` fixed the survey mode several merges
before the one-line validation fix closed the frame mode, so by the time the
M rows were written the survey mode was already green.

**This does not change which modes a row runs in.** The Modes column still
governs that, and the both-modes rule in
`.claude/rules/testing-surveycore.md` is why: the two modes are fixed by
different mechanisms on different code paths, and neither can be inferred
from the other. A row being already green is not a reason to drop its
variant.

### 4.7 Conversion round trips

In `tests/testthat/test-conversion.R`. Guard every block with
`skip_if_not_installed("survey")`, and additionally
`skip_if_not_installed("srvyr")` where the row names `srvyr`.

| Row | Scenario | Assertion |
|---|---|---|
| C-0 | `label_vars = TRUE` on a `get_means()` call over a design produced by `from_svydesign()` from a labelled source frame | the output shows the variable **label**, not the raw column name. **A fence, not evidence — corrected 2026-09-01.** It passes before the fix too: `.extract_var_meta()` at `R/analysis-helpers.R:160-162` falls back to `attr(col, "label")`, which the strip keeps, so the label resolved on both trees. The rows that catch the empty-metadata defect are C-3, C-5 and C-6. |
| C-1 | `as_svydesign()` on a design built from a labelled frame | succeeds; the variables frame it produces has no column inheriting `haven_labelled`; the `labels` attributes are still there |
| C-2 | `survey::svymean()` on that converted object | matches `get_means()` on the surveycore design, at the default point and standard-error tolerances |
| C-3 | `from_svydesign()` on a `survey::svydesign()` built from a labelled frame | succeeds; no stored column inherits `haven_labelled`; **`extract_val_labels()` returns the labels** |
| C-4 | `from_svydesign()` where the **weight** column of the source frame is labelled | succeeds. This currently aborts. |
| C-5 | `from_svydesign()` on a labelled `svrepdesign` | succeeds; labels reachable |
| C-6 | `from_svydesign()` on a labelled two-phase design | succeeds; labels reachable |
| C-7 | Full round trip: build with `as_survey()` from a labelled frame, out through `as_svydesign()`, back through `from_svydesign()` | the labels are reachable at both ends; no column inherits `haven_labelled` at either end |
| C-8 | `as_tbl_svy()` then `from_tbl_svy()` on a labelled design | same as C-7 |
| C-9 | `from_svydesign()` on a source frame with **no** labels | `extract_val_labels()` returns an empty result, not an error |

C-3, C-5 and C-6 are the rows that catch the empty-metadata defect. Assert
through `extract_val_labels()`, which is the observable face of it.

### 4.8 `survey_data()` contract

In `tests/testthat/test-utils.R`.

| Row | Scenario | Assertion |
|---|---|---|
| D-1 | `survey_data()` on a design built from a labelled frame | no column inherits `haven_labelled` or `haven_labelled_spss` |
| D-2 | Same | every previously labelled column is a plain double, or a plain integer where the input was a labelled integer, or a plain character where the input was a labelled character |
| D-3 | Same | the `label` and `labels` attributes are readable from the returned columns |
| D-4 | Same, built from a labelled SPSS frame | `na_values` and `na_range` are readable from the returned columns |
| D-5 | `survey_data()` on a design built from a plain frame | returns a frame identical to the input |
| D-6 | `survey_data()` on a design whose column stacked a caller's own class above the labelled class | the returned column is a bare base type: the caller's class is gone too. Accepted behaviour, pinned so the loss is recorded rather than discovered. |

#### The `haven_class` argument

Same file. None of these rows may call `library(haven)` or use
`skip_if_not_installed("haven")` for the rebuild itself — the rebuild does
not need `haven`. Only the rows that then hand the result to a `haven`
function need the guard.

| Row | Scenario | Assertion |
|---|---|---|
| D-7 | `survey_data(d)` on a labelled-source design | default is unchanged: no column carries the class. Confirms the default did not silently flip. |
| D-8 | `survey_data(d, haven_class = TRUE)` | every column that carried a `labels` attribute inherits `haven_labelled` |
| D-9 | Same | the class vector is **exactly** `c("haven_labelled", "vctrs_vctr", "double")` for a double-backed column. Assert the whole vector with `expect_identical()`, not `inherits()`. See the note below. |
| D-10 | Same, integer-backed column | class vector is exactly `c("haven_labelled", "vctrs_vctr", "integer")` |
| D-11 | Same, character-backed column | class vector is exactly `c("haven_labelled", "vctrs_vctr", "character")` |
| D-12 | Source column was SPSS-flavoured with `na_values` | class vector is exactly `c("haven_labelled_spss", "haven_labelled", "vctrs_vctr", "double")`, and `na_values` is intact |
| D-13 | Source column was SPSS-flavoured with `na_range` only | same class vector as D-12, and `na_range` is intact |
| D-14 | Round trip: strip at construction, then rebuild | values are identical to the original input column |
| D-15 | `haven_class = TRUE` on a design whose columns never carried labels | returns a frame identical to `haven_class = FALSE` |
| D-16 | `haven_class = TRUE` on a column holding a tagged `NA` | the tagged value is still `NA`; with `haven` installed, its tag still reads back. Guard only the tag assertion with `skip_if_not_installed("haven")`. |
| D-17 | `haven_class = TRUE`, then `haven::as_factor()` on the result | returns the label strings, not the codes. Guard with `skip_if_not_installed("haven")`. This is the user-visible reason the argument exists. |
| D-18 | `haven_class = FALSE`, then `haven::as_factor()` | returns the codes. The contrast with D-17 is the point. Guard the same way. |
| D-19 | `haven_class = TRUE`, then `labelled::to_factor()` | returns the label strings. Guard with `skip_if_not_installed("labelled")`. |
| D-20 | `haven_class = TRUE`, write with `haven::write_sav()` to a temp file, read back with `haven::read_sav()` | value labels are present. Use a column with **no** tagged `NA` — see D-21. Guard with `skip_if_not_installed("haven")`, and use `withr::local_tempfile()`. |
| D-21 | The same write on a column holding a tagged `NA` | raises. This is a `.sav` format limit inside `haven`, not a defect here: a column built straight from `haven`'s own constructor fails identically. Assert that it raises, and say why in the block description so nobody attributes it to this work. Guard with `skip_if_not_installed("haven")`. |
| D-22 | `haven_class` given a non-logical value, or a logical of length two | raises `surveycore_error_haven_class_not_logical` (D6). Dual pattern. Cover at least: a character scalar, `NA`, a length-two logical, and `NULL`. |
| D-23 | `survey_data(x)` where `x` is not a survey design object | still raises `surveycore_error_not_survey_object`. Dual pattern. Regression fence on the existing check. |

**Note on D-9 to D-13 — assert the whole class vector, not just membership.**
The rebuild writes the class chain out rather than obtaining it from `haven`.
That is a deliberate trade-off, and its stated mitigation is exactly this
check. `expect_true(inherits(x, "haven_labelled"))` would pass on a stale or
malformed chain; `expect_identical(class(x), c(...))` would not. If `haven`
ever changes its class vector, these five rows are what turns a silent
mismatch into a visible failure.

There is **no** row for "`haven` is not installed and `haven_class = TRUE`
raises". The rebuild uses base R, so no such error exists. If a row like that
appears, the implementation has taken the wrong route.

### 4.8a Printed output

In `tests/testthat/test-methods-print.R`.

The change in the printed column type is described elsewhere in this document
as the visible face of this work, so it needs a snapshot rather than a prose
claim.

| Row | Scenario | Assertion |
|---|---|---|
| T-1 | Build a design from a **tibble** whose columns are labelled — double-, integer- and character-backed — and snapshot `print(survey_data(d))` | the type tokens read `<dbl>`, `<int>` and `<chr>`. Before this work they read `<dbl+lbl>`, `<int+lbl>` and `<chr+lbl>`. Corrected 2026-08-31 — see the note below. |
| T-2 | Snapshot `print(survey_data(d, haven_class = TRUE))` on the same design | the type tokens read `<dbl+lbl>`, `<int+lbl>` and `<chr+lbl>` again. Corrected 2026-08-31. |
| T-3 | Snapshot `print(d)` — the design object itself | unchanged from the current snapshot. The design print method reports counts and design variables, not column types, so this row is a fence proving it did not move. |

**Note on the printed token, corrected 2026-08-31.** Earlier drafts of T-1 and
T-2 named the token `<hvn_lbl>`. No state of the package produces that string.
The token depends on whether the `haven` namespace is **loaded**, because
`haven` registers the `pillar` methods that produce it.

| `haven` loaded | Token |
|---|---|
| yes | `<dbl+lbl>`, `<int+lbl>` or `<chr+lbl>`, by backing type |
| no | `<hvn_lbll>` — `pillar` falls back to abbreviating the class name |

Neither is `<hvn_lbl>`. Measured on `develop` at `b7f8b45` with `haven`
2.5.5. A row that snapshots this token must pin the load state, or the
snapshot flips with test file order.

Assert the token the code produces. A row written against `<hvn_lbl>` cannot
pass, and rewriting the snapshot to match it would be wrong rather than
merely inconvenient.

T-1 and T-2 are the only place either token is locked. Use a tibble input
deliberately: a plain `data.frame` prints values rather than type tokens, so
it cannot show the change.

Keep the fixture small — a handful of rows — because the snapshot is read by
humans in review.

### 4.9 The `haven` availability branch

In `tests/testthat/test-analysis-helpers.R`.

The runtime check for the `haven` namespace now goes through a stubbable
binding, so the branch taken when `haven` is unavailable can be reached on
purpose with `testthat::local_mocked_bindings()` rather than by luck.

| Row | Scenario | Assertion |
|---|---|---|
| H-1 | Grouped call with a tagged-`NA` group column, availability stubbed to `TRUE`, `haven` installed | the tagged-`NA` label appears as a factor level. Guard with `skip_if_not_installed("haven")`. |
| H-2 | The same call, availability stubbed to `FALSE` | no error; the tagged-`NA` rows carry an `NA` group; every non-tagged label still resolves. Needs no `skip_if_not_installed()`, because the stub removes the dependency. |
| H-3 | A grouped call with no tagged `NA` at all, availability stubbed to `FALSE` | identical result to the same call with it stubbed to `TRUE` |

H-2 is the row that could not be written before. It must be present.

### 4.10 Ordinality — polychoric

In `tests/testthat/test-analysis-corr-latent.R`.

Express every row through `get_corr()`. The distinct-value limit for
treating a numeric column as an ordinal scale is **10**.

Method: pair the column under test with a known-ordinal partner — an ordered
factor with four levels — and observe whether the call succeeds or raises.

| Row | Column under test | Expected |
|---|---|---|
| P-1 | double, 3 distinct whole values | succeeds |
| P-2 | double, 7 distinct whole values | succeeds |
| P-3 | double, exactly **10** distinct whole values | succeeds — the inclusive boundary |
| P-4 | double, exactly **11** distinct whole values | raises `surveycore_error_polychoric_requires_ordinal` — the boundary just beyond |
| P-5 | double, 12 distinct whole values | raises the same |
| P-6 | double containing at least one fractional value | raises the same |
| P-7 | double, every value `NA` | raises the same |
| P-8 | character column | raises the same — unchanged behaviour |
| P-9 | logical column | raises the same — unchanged behaviour |
| P-10 | integer, 3 distinct values | succeeds — unchanged behaviour |
| P-11 | integer, 11 distinct values | raises the same — unchanged behaviour |
| P-12 | ordered factor | succeeds — unchanged behaviour |
| P-13 | unordered factor | succeeds **and** raises `surveycore_warning_polychoric_unordered_factor` — unchanged behaviour |
| P-14 | **labelled** double, 4 distinct whole values, every code labelled | succeeds. This is the reported defect. |
| P-15 | labelled **integer**, 4 distinct values | succeeds — passed before the change too; the control that shows the gap was about storage type and not about the label class |
| P-16 | double `c(1000, 2000, 3000)` repeated across rows | succeeds. **A documented false positive.** Three distinct whole values, so it is treated as a three-point scale even though it could be income in whole dollars. Accepted because this method is opt-in. The row exists to pin the behaviour, so a future reader sees it was chosen and not overlooked. |
| P-17 | double `c(0, 1)` — a binary indicator | succeeds. The tetrachoric case, and legitimate. |
| P-18 | double with a single distinct value across every row | raises `surveycore_error_polychoric_single_level_ordinal`, **not** the non-ordinal error. This is the intended path: the column is accepted as ordinal and then rejected by the level-count guard, which names the column and gives a remedy. A typed error is a better outcome than the previous untyped refusal. |
| **P-18a** | double with a few whole values **plus one `Inf`** | **raises `surveycore_error_polychoric_requires_ordinal`.** Highest-priority row in this section — see the note below. |
| **P-18b** | double with a few whole values **plus one `-Inf`** | raises the same |
| P-18c | double with a few whole values plus `NA` | **succeeds.** `NA` is filtered before the whole-value test, so a missing value does not make a scale continuous. |
| P-18d | double with a few whole values plus `NaN` | **succeeds**, for the same reason as P-18c. `NaN` is missing, not infinite. |
| P-18e | double with 10 distinct whole values plus `NA` and `NaN` | succeeds. The distinct-value count is taken over the non-missing values only, so the missing values do not push it past the limit. |
| P-18f | labelled double, few whole codes, plus one `Inf` | raises `surveycore_error_polychoric_requires_ordinal`. The class makes no difference to this. |

**Note on P-18a and P-18b — do not let these be dropped.** Without the
finiteness check, a column containing `Inf` classifies as an ordinal scale
and `Inf` becomes an ordinary top category. Measured on the drafted rule
before it was corrected: `get_corr(method = "polychoric")` **returned a
correlation of about -0.056** rather than raising. A fabricated number with
no error is worse than the refusal this whole section exists to remove, so
these two rows are the highest-value rows in §4.10.

P-18c to P-18e exist to stop an over-correction. `NA` and `NaN` must stay
acceptable; a fix that rejects them too would break every real scale column,
because real survey data has missing values.

Numerical rows, in the same file:

| Row | Scenario | Assertion | Tolerance |
|---|---|---|---|
| P-19 | Two whole-valued double columns, 4 distinct values each | the correlation equals the correlation from the same two columns converted to ordered factors with levels in ascending value order | point 1e-10 |
| P-20 | Same pair, one column labelled | the correlation equals the same pair with the class removed | **exact — corrected 2026-09-01.** §6 departure 1 governs: one input re-classed, same computation, so `expect_identical()`. Measured bit-identical on r, se and both CI bounds. The earlier 1e-10 / 1e-8 / 1e-6 figures would have let a tenth-decimal drift ship green. |
| P-21 | Same pair on a replicate design | as P-20 | **exact**, as P-20. The replicate variance path adds R refits and does not change that: both designs feed it the same numbers. |
| P-22 | Two whole-valued double columns with reversed codes on one side | the correlation is the negative of the unreversed pair | point 1e-10 |
| P-23 | A whole-valued double paired with a genuine continuous column, `method = "polychoric"` | raises `surveycore_error_polychoric_requires_ordinal`, naming the continuous column | — |

P-22 pins the sign convention, which matters because the code order sets the
threshold order and nothing in the package reads a reverse-coding marker.

### 4.11 Ordinality — polyserial

In `tests/testthat/test-analysis-corr-latent.R`.

| Row | Pair | Expected | Changed |
|---|---|---|---|
| Y-1 | whole-valued small double + genuine continuous column | succeeds | **yes — newly working.** Both sides were previously read as continuous, so this raised the mixed-types error. |
| Y-2 | whole-valued small double + whole-valued small double | raises `surveycore_error_polyserial_requires_mixed_types` | no in outcome; the classification named in the message text differs |
| Y-3 | whole-valued small double + ordered factor | raises `surveycore_error_polyserial_requires_mixed_types` | **yes — a breaking change.** This pair previously returned a number. Both sides are now ordinal. |
| Y-4 | whole-valued small double + small integer column | raises the same | **yes — the same breaking change**, a second shape of it |
| Y-5 | ordered factor + genuine continuous column | succeeds | no |
| Y-6 | two ordered factors | raises `surveycore_error_polyserial_requires_mixed_types` | no |
| Y-7 | high-cardinality integer + ordered factor | raises `surveycore_error_polyserial_canonicalization_ambiguous` | no |
| Y-8 | character column + ordered factor | raises the same | no |
| Y-9 | labelled double, 4 distinct codes, + genuine continuous column | succeeds; equals Y-1 with the class removed | **yes** |
| Y-10 | double containing `Inf` + ordered factor | **Corrected 2026-09-01.** The finiteness check keeps the `Inf` column continuous, so the pair does not cross the ordinal/continuous boundary and raises neither PC-2 nor PC-3. It does **not** "succeed" and does not "work today": on every tree in this series the weighted SD goes `NaN` and an untyped base error escapes. Assert the boundary, not a returned number. | no |

Y-3 and Y-4 are the rows that record the breaking change. Their block
descriptions must say so, so that a reader hitting the error later finds the
decision instead of guessing. Both need the dual pattern.

#### Numerical oracle for polyserial — required, not optional

Row Y-1 is a case that **used to raise and now returns a number**. Asserting
only that it succeeds is not enough: a wrong number passes that assertion.
Y-9 compares Y-1 against itself with the class removed, which checks the
strip and not the estimate.

| Row | Scenario | Assertion | Tolerance |
|---|---|---|---|
| Y-11 | Whole-valued small double + genuine continuous column | the correlation equals the correlation from the same pair with the ordinal side converted to an ordered factor, levels in ascending value order | point 1e-10 |
| Y-12 | The same pair | **Corrected 2026-09-01. Two oracles.** The strict one is `.hand_polyserial_twostep()` at **1e-6** — the Cox (1974) two-step MLE that `.corr_polyserial_mle()` implements; measured delta exactly 0. `polycor::polyserial(ML = TRUE)` is a **joint** MLE over thresholds and rho together, so it targets a different estimator: a sanity check on sign and magnitude at **5e-3**, not a strict oracle. Measured gap 1.988e-03 on the fixture. `decisions.md` B1 settled this; the row never caught up. Guard the `polycor` half with `skip_if_not_installed("polycor")`. | 1e-6 strict, 5e-3 sanity |
| Y-13 | The same pair on a replicate design | equals Y-11 | point 1e-10, standard error 1e-8 |
| Y-14 | Whole-valued small double + continuous column, ordinal side reverse-coded | the correlation is the negative of Y-11 | point 1e-10 |

Y-11 is the primary oracle. It is exact in principle, because the two forms
describe the same ordinal variable and the estimator derives its category
codes the same way from each.

Y-12 is the external cross-check. The 1e-6 tolerance is looser than the house
default of 1e-10 for point estimates, and the justification is that
`polycor::polyserial()` and surveycore target different estimators:
surveycore implements the two-step MLE under the survey-weighted
construction, and `polycor` offers either a joint MLE or Drasgow's two-step.
The existing correlation test files already treat `polycor` as a loose
reference for this reason. Y-12 catches a sign error or a gross
misclassification, which is what an external oracle is for here; Y-11 catches
everything finer.

### 4.11a Confirming the new tests fail before the fix

`request.md` requires a regression test that fails on `develop` at `cf6f153`
and passes after. That has to be demonstrated, not asserted, and the method
must be recorded because it cannot be reproduced from the merged branch
afterwards.

**Method.** Before the source changes land, run the new and amended test
files against the unmodified base commit and record the result:

1. Check out the base commit into a scratch worktree, or copy `R/`,
   `DESCRIPTION`, `NAMESPACE` and `inst/` from it into a scratch directory.
2. Copy the **new** test files and fixture builders into that scratch tree,
   leaving its `R/` untouched.
3. Load with `pkgload::load_all()` and run only the affected files.
4. Record, in the implementation notes: the count of failing tests, and the
   identifier of every row that failed.

**The list below is stated against `cf6f153`, the base for the whole
feature.** Under the nine-PR shape each PR has its own base, so a row that
fails at `cf6f153` can pass at a later PR's base because an earlier PR already
fixed it. Check a PR's red run against its own base, not against this list.

**Expected to fail on the base commit** — this is the list to check the run
against:

| Group | Rows |
|---|---|
| stored state | S-1 to S-5, S-8 to S-13 |
| design variables | S-14, S-15, S-16, S-19, S-23b to S-23e, S-31, S-32 |
| routes no constructor sees | S-24 to S-29 |
| the analysis sweep | most of A-1 to A-31 |
| metadata | M-1, M-2, M-3 |
| conversion | C-0, C-3 to C-8 |
| `survey_data()` | D-1 to D-4, D-6 |

### Corrections to this list, measured 2026-08-31

PR 3b measured every row above on a scratch tree differing from its own base
only by the change under test. The list mispredicted in both directions, for
**three** separate reasons. Read all three before trusting a prediction here.

**1. The base moved.** S-1 to S-13 are listed as expected to fail. They pass
from PR 3a onward, because PR 3a's property setter already covers those
routes. In PR 3b they are regression fences, not evidence. This is the
expected consequence of the nine-PR split, not a defect in the row.

**2. Two rows were misfiled, and two over-predicted.**

| Row | This list said | Measured at PR 3b's base |
|---|---|---|
| S-21, S-22 | not listed, so expected to pass | **fail** — without the strip the constructor aborts with `vctrs_error_ptype2` instead of the weight class the row names, so they are evidence |
| S-23c, S-23e | expected to fail | **pass** — fences |

**3. A row this list got right, which the counterfactual missed. S-16.**
Worth reading in full, because it is a trap in the test harness rather than in
the document.

`tests/testthat/test-labelled-storage.R` simulates `haven`'s absence with
`.ls_without_haven()`, which removes `haven`'s entries from the `vctrs` S3
method table. That covers a failure reached through a **vctrs** generic. It
does **not** cover one reached through a **base** generic: `haven`'s methods
for base generics live in a different table and stay registered.

`.validate_psu_strata()` calls `as.character()`, a base generic. Under the
wrapper, `as.character.haven_labelled` survives and the call succeeds, so
S-16 looks like a fence. With `haven` genuinely absent, dispatch falls through
to `as.character.vctrs_vctr` and raises `vctrs_error_cast` — the site
`spec.md` §III.5 records. So S-16 **is** evidence; the harness under-detected
it.

**The general rule.** `.ls_without_haven()` reproduces `haven` absence for
`vctrs` generics only. A row whose failure path runs through a base generic —
`as.character()`, `as.numeric()`, `[`, `c()` — will look like a fence under
the wrapper and is not one. Say which generic a row's failure path uses before
classifying it.
| the new argument | D-7 to D-23 — these fail with "unused argument" |
| ordinality | P-1 to P-3, P-14 to P-18f, P-19 to P-22 |
| polyserial | Y-1, Y-9, Y-11 to Y-14 |
| printed output | T-1, T-2 |

**Expected to pass on the base commit**, and therefore not evidence of
anything: S-6, S-7, S-17, S-18, S-21, S-22, D-5, P-4 to P-13, Y-2, Y-5 to
Y-8, T-3, and every row marked "unchanged behaviour" in this document. A row
in this group that **fails** on the base commit means the row is wrong, not
that the defect is wider.

Rows P-18a and P-18b are a special case, and this note contradicted itself
until it was **corrected on 2026-09-01**: it said they "fail on the base
commit" and then called the same outcome a pass.

They **pass** on the base commit. Both assert that
`get_corr(method = "polychoric")` raises
`surveycore_error_polychoric_requires_ordinal`, and the base raises exactly
that class — for the wrong reason. The base refuses every whole-valued
double, so it never reaches a finiteness test at all.

The pass is therefore **not** evidence that the finiteness guard exists.
Record that in the red run, so a green P-18a on the base is not read as one.

### 4.12 Existing correlation tests

The four existing correlation test files were run against the ordinality
change and reported 246 tests, 718 expectations — **that is the PRE-change
baseline, corrected 2026-09-01; the shipped figure is 290 tests, 825
expectations.** Either way 0 failures, 0 errors, 0
skips. Confirm that result rather than assume it. If any block does fail,
that is new information and must be reported, not patched over by relaxing
the block.

The two files with a file-level `skip_on_cran()` do not currently have
committed snapshot files, so their error snapshots will be written for the
first time. Review each new snapshot by hand with
`testthat::snapshot_review()`. Do not accept them blind.

---

## 5. Error and warning classes

Exactly one new error class —
`surveycore_error_haven_class_not_logical`, which validates the
`haven_class` flag (D6, `spec.md` §IX.1a). No new warning class. Every other
class below already exists; what changes is the condition that reaches some
of them.

Each named class gets the dual pattern — `expect_error(class = ...)` **and**
`expect_snapshot(error = TRUE, ...)` — because all of these are user-facing
messages raised from public functions, not structural class-validator
messages.

**The requirement is per class, not per row — clarified 2026-09-01.** The
Rows column below lists rows that may cover a class; the dual pattern is
satisfied when **any one** covering row carries both halves. A row listed
there may assert `class=` alone, provided another row in the same file
snapshots that class. Read per row, this table asks for snapshots that would
differ from one another only in an interpolated variable name.

| Class | Rows that must cover it | Pattern |
|---|---|---|
| `surveycore_error_polychoric_requires_ordinal` | P-4, P-6, P-7, P-8, P-23 | dual |
| `surveycore_error_polyserial_requires_mixed_types` | Y-2, Y-3, Y-6 | dual |
| `surveycore_error_polyserial_canonicalization_ambiguous` | Y-7, Y-8 | dual |
| `surveycore_error_polychoric_single_level_ordinal` | P-18 | dual |
| `surveycore_warning_polychoric_unordered_factor` | P-13 | `expect_warning(result <- ..., class = ...)` plus snapshot |
| `surveycore_warning_missing_labels` | M-2 | `expect_warning(result <- ..., class = ...)` **plus snapshot** — same treatment as the row above it. Both are user-facing warnings raised from public functions with fully formatted messages, so there is no reason to treat them differently. An earlier draft snapshotted one and not the other. |
| `surveycore_error_not_survey_object` | D-23 | dual |
| `surveycore_error_haven_class_not_logical` | D-22 | dual |
| `surveycore_error_subset_not_logical` | S-30 | dual |
| `surveycore_error_weights_nonpositive` | S-21 | dual |
| `surveycore_error_weights_all_zero` | S-22 | dual |
| `surveycore_error_fpc_nonpositive` | S-23 | dual |
| `surveycore_error_fpc_na` | S-23a | dual |

Note on the layer choice for S-21 to S-23a. Two of these class names are
also raised by the class validators, where messages are plain text and the
rule is `expect_error(class = ...)` only, with no snapshot. That is not the
path these rows take. A constructor validates its arguments before it builds
the object, so a constructor call raises the argument-validation version of
the message, which is fully formatted with the standard three-bullet
structure. The dual pattern is therefore correct for every row here. Do not
add snapshots for the class-validator versions of the same class names.

Message-text rows:

| Row | Scenario | Assertion |
|---|---|---|
| E-1 | The non-ordinal error raised for a labelled input column | the message names the column's class as a plain numeric type, not as a labelled type. The class name is interpolated into the message, so it changes once the class is no longer stored. Snapshot. |

Errors that become unreachable — `vctrs_error_ptype2`,
`vctrs_error_incompatible_op`, `vctrs_error_cast`,
`vctrs_error_subscript_oob` for labelled input — are classes from another
package. Do not write tests asserting they no longer fire. The positive rows
in §4.2 and §4.4 already cover that ground, and asserting the absence of a
foreign error class is brittle.

---

## 6. Tolerances

| Estimand | Tolerance |
|---|---|
| Point estimates — mean, total, proportion, quantile, ratio, correlation | 1e-10 |
| Standard errors and variances | 1e-8 |
| Confidence bounds | 1e-6 |

Two documented departures, both **tighter** than the defaults:

1. **Every "labelled input equals plain input" comparison** — §4.2, §4.4,
   P-20, P-21, Y-9. Use `expect_identical()` on the result columns, or
   `expect_equal(tolerance = 0)`. After the fix the two inputs are the same
   object before any arithmetic runs, so the two calls execute identical code
   on identical bytes. Any difference at all is a defect. A tolerance of
   1e-10 here would hide the exact class of bug the row exists to catch.
2. **`survey_data()` and stored-frame comparisons** — S-6, S-7, D-5. Use
   `expect_identical()`. These assert structure, not a computed number.

Use `expect_identical()` for class vectors, attribute values, column names
and list structure. Use `expect_equal()` with the tolerances above for any
computed number.

---

## 7. Coverage

- Target 98% line coverage. CI blocks below 95%. The figure on the current
  base is 96.09%.
- Measure with `NOT_CRAN=true`. `covr` does not set the variable, and
  without it eleven files with a file-level `skip_on_cran()` are skipped and
  the figure reads about 93.7% instead.
- The fast edit-run loop is
  `NOT_CRAN=false Rscript -e "testthat::test_local()"`. `devtools::test()`
  cannot reach the fast speed, because it forces `NOT_CRAN=true`.
- Run the full `Rscript -e "devtools::test()"` before any push.
- Any `# nocov` marker added by this work needs an explanatory comment on
  the preceding line. None is expected.

---

## 8. Profile gates

All six must pass, verbatim:

- `document`
- `test`
- `run_examples`
- `R CMD check --as-cran`
- `pkgdown`
- `covr`

---

## 9. Comprehension gotchas — disposition

Every risk raised during comprehension gets a row or an explicit note.

| Gotcha | Disposition |
|---|---|
| Every type predicate could change answer once the class is removed | Measured on the labelled column and on the plain column, with `haven` both absent and present. All four combinations agree on every predicate. No row needed. Covered indirectly by every row in §4.4. |
| Base `[` drops the `labels` attribute on a subset, where the labelled subscript operator kept it | No reader in the package reads a label attribute from a subset; every reader takes the full column. Covered by G-1, G-5 and M-3, which assert that labels still resolve after grouping and subsetting. |
| `get_freqs()` level display could switch from the code to the label for users who have `haven` loaded | Measured: the coercion returns the code in both states. Covered by A-1 and A-5 as identity comparisons. |
| The metadata harvest might run after the class is removed and find nothing | The removal keeps both label attributes, so the harvest is unaffected either way. Covered by S-1 to S-4, which assert `extract_val_labels()` returns the labels. |
| SPSS declared-missing metadata could be lost | Covered by S-9, M-8 and D-4. |
| A tagged `NA` could silently become a plain `NA` | Covered by S-10, G-3 and F-1 to F-4. |
| Reverse-coded ordinal columns get the wrong sign | The package stores a reverse-coding marker and no analysis code reads it. That predates this work and is out of scope. P-22 pins the sign convention so the behaviour is at least recorded. |
| Missing-reason codes such as 8 for "Don't know" become scale points under polychoric | The package stores missing codes and no analysis function reads them. Out of scope, and unchanged by this work. P-16 records the closest observable case. |
| The high-cardinality asymmetry — a large-cardinality integer is ambiguous, a large-cardinality whole double is continuous | Deliberately unchanged. P-11 and P-5 pin both sides so the asymmetry is visible rather than accidental. |
| A column labelled by the `labelled` package | That package re-exports the same constructors, so it produces the same class and is covered by every labelled row. The legacy class shape is covered by S-12. |
| A design variable carrying the class | Covered by S-14 to S-23. These are construction-time failures the original issue never mentioned, and they are the rows that isolate the construction-time half of the fix. |
| The cost of normalising on every stored-data write | Not a correctness row. S-29 exercises the path that pays it most often. Timing belongs to the implementation report, not here. |
| A non-finite value passing the whole-number test | The highest-value rows in this document: P-18a, P-18b, P-18f, Y-10. Measured to return a fabricated correlation without the guard. |
| An over-correction rejecting `NA` or `NaN` alongside `Inf` | P-18c, P-18d, P-18e. Real survey data always has missing values, so a fix that rejected them would break every genuine scale column. |
| `haven` and `labelled` losing their labels after the strip | D-17 to D-21 cover both directions. The argument in §4.8 exists for this. |
| `sjlabelled` losing its labels | Not affected — it reads the attribute, not the class, and the stripped column is identical to what it produces natively. No row needed. Recorded here so its absence is a decision rather than an omission. |
| The rebuilt class chain drifting from what `haven` produces | D-9 to D-13 pin the whole vector; F-5 and F-6 pin the fixture against `haven` itself. Two independent checks, deliberately, because the chain is written out rather than obtained from `haven`. |
| A caller's own class stacked above the labelled class | S-13's sibling row D-6, plus the fixture shape in §2.3. Accepted loss, pinned so it is recorded. |
| A labelled column that must stay rejected | S-30 for a non-logical two-phase subset column, S-37 for a character weight column, S-21 to S-23g for invalid weights and FPC values. The strip must not launder an invalid input. |
| A tagged `NA` meeting the new ordinality rule | G-7, and D-16 for the round trip. Both are new in this work, so their intersection needed a row. |
| A tagged `NA` in a weight or FPC column | S-33 and S-34. A tagged `NA` is an `NA`, so the existing missing-value handling governs, and these rows confirm it still does. |
