# Spec — haven-labelled (issue #175)

**Version**: 1.0
**Date**: 2026-08-28
**Status**: Draft — Stage 1 output, awaiting Stage 3 review
**Pipeline split**: recommended
**Base**: worktree `haven-labelled`, `develop` at `cf6f153`

## Document purpose

This document is the source of truth for what the implementation must do. It
carries the behavioural contract for two independent defects that a single
`haven::read_sav()` import hits on the first call, plus the four smaller
items the measurement pass uncovered. It contains no test cases, no
tolerances and no test data. Every claim about current behaviour cites a file
and a line.

Five decisions are already SETTLED and are not re-opened here: D1 (strip the
labelled class, keep the labels), D2 (the ordinal gap is in scope), D3 (the
ordinality rule), D4 as amended (the strip has two halves — a call on entry
to each constructor, plus an S7 property setter as the backstop), and D5
(`survey_data()` gains a `haven_class` argument that rebuilds the class on
request).

Where this document says "verified" or "measured", it refers to a result
obtained on a patched throwaway copy of the package or in an isolated R
process. Those results cover: the ordinality change against the existing
correlation test files; the property setter against every construction
route; the two routes the setter alone leaves broken; the non-finite defect
in §VI.3; the setter-recursion question in §III.4; and the downstream
toolchain behaviour in §VIII.1 and §XII.5.

---

## I. Scope

### What this delivers

| # | Item | Kind |
|---|---|---|
| 1 | Drop the `haven_labelled` class from every `@data` column, on every write, and from every caller data frame on entry to a constructor, keeping every other attribute | Storage contract |
| 2 | Capture haven-style metadata on the `survey` package conversion routes, which currently store an empty metadata object | Bug fix |
| 3 | Let `set_val_labels()` accept a column that carries the labelled class | Bug fix |
| 4 | Classify a whole-valued double with few distinct values as ordinal, so `method = "polychoric"` accepts it | Numerical behaviour |
| 5 | Route the runtime `haven` check through a named internal helper, so tests can stub it | Testability |
| 6 | Add a `haven_class` argument to `survey_data()` that rebuilds the labelled class on request, defaulting to the stripped form | New argument |
| 7 | Update the canonical error table rows whose stated condition changes | Documentation |

### What this does NOT deliver

- No new exported function, no new S7 class, no new S7 property. Exactly one
  new argument, on `survey_data()`, specified in §VIII.1.
- No change to `Imports`. `haven` stays in `Suggests`, per
  `.claude/rules/surveycore-conventions.md` §haven handling.
- No handling for the legacy `"labelled"` class. Measured: that class chain
  carries no `vctrs_vctr`, so `vctrs` never dispatches on it and every entry
  point already passes. It needs nothing.
- No harvest of the SPSS `na_values` and `na_range` attributes into
  `@metadata`. `archive/phase-0/surveycore-phase0-formal-specification.md:1152-1168`
  planned a `missing_values` property and it was never built. The strip
  preserves both attributes, so nothing is lost and nothing is gained. Out
  of scope.
- No change to the high-cardinality asymmetry in type classification. An
  integer with more than the cutoff of distinct values is "ambiguous"; a
  whole-valued double with more than the cutoff is "continuous". That
  difference predates this work and stays.
- No `vctrs`-wide strip. The predicate stays narrow so that genuine `vctrs`
  types from other packages pass through untouched.
- No `haven_class` argument on `as_svydesign()` or `as_tbl_svy()`. Those two
  convert to another package's object; a labelled-class flag on them is a
  separate concern. §XII.2 records the boundary and the supported route.
- No recoding of in-band SPSS sentinel codes. §VI.5 states the consequence.

### Class and design support matrix

| Class | Item 1 (strip) | Item 4 (ordinality) |
|---|---|---|
| `survey_taylor` | yes | yes |
| `survey_replicate` | yes | yes |
| `survey_twophase` | yes | not applicable — latent methods already raise `surveycore_error_polychoric_design_unsupported` (`R/analysis-corr-latent.R:1621-1635`) |
| `survey_nonprob` | yes | yes, when replicate weights are supplied; otherwise `surveycore_error_polychoric_design_unsupported` (`R/analysis-corr-latent.R:1636-1656`) |
| `survey_collection` | yes, through its members — it has no `data` property (`R/core-classes.R:932-934`) | through its members |

---

## II. Architecture

### Write surface

Exactly these files. No others.

```
R/
  utils.R                 # + .strip_labelled_class()
                          # + .strip_labelled_columns()
                          # + .restore_haven_class()
                          # survey_data(): new haven_class argument
  core-classes.R          # setter on the survey_base `data` property (Part 2)
  core-constructors.R     # strip on entry to all four constructors (Part 1)
  core-metadata.R         # .validate_val_labels(): local strip
  methods-conversion.R    # strip + metadata capture in the from_svydesign
                          #   helpers; @return boundary note on as_svydesign()
                          #   and as_tbl_svy()
  analysis-corr-latent.R  # .corr_detect_ordinal(): the double branch
                          #   + replace the comment that contradicts it
  analysis-helpers.R      # + .haven_available(); six call sites
  analysis-corr.R         # roxygen @param x wording
plans/
  error-messages.md       # PC-1, PC-2, PC-3 condition text
                          # + surveycore_error_haven_class_not_logical
NEWS.md                   # four user-visible entries
man/                      # regenerated by devtools::document()
```

`DESCRIPTION` and `NAMESPACE` do not change. `survey_data()` is already
exported (`NAMESPACE:106`) and gains an argument, not an export.

### Shared helpers

Three new internal helpers, `.`-prefixed, not exported. All three live in
`R/utils.R`, beside `survey_data()`, which is the exported function whose
contract they serve.

```r
# Remove the haven labelled class from one vector, keeping every other
# attribute. Returns x unchanged when x does not carry the class.
#' @noRd
.strip_labelled_class <- function(x) {
  if (inherits(x, "haven_labelled")) {
    attr(x, "class") <- NULL
  }
  x
}
```

```r
# Remove the haven labelled class from every column of a data frame.
# Returns data unchanged, with no copy, when no column carries the class.
#' @noRd
.strip_labelled_columns <- function(data) {
  hit <- which(vapply(data, inherits, logical(1L), "haven_labelled"))
  if (length(hit) == 0L) {
    return(data)
  }
  for (j in hit) {
    data[[j]] <- .strip_labelled_class(data[[j]])
  }
  data
}
```

The per-column body **must** be the call to `.strip_labelled_class()`, not a
second copy of its one-line body. Two reasons, and the first is the one that
matters: the predicate and the removal then exist in exactly one place, so a
later change to either — widening the predicate, or preserving part of the
class vector — cannot be applied to one helper and missed in the other.
Second, `.strip_labelled_class()` reaches two call sites this way, which is
what earns it a place in `R/utils.R` rather than inline in one file, per
`.claude/rules/code-style.md` §Function design. Its other call site is
§V.2.

The re-test of the predicate inside `.strip_labelled_class()` is redundant
for a column already selected by `hit`. Leave it. It costs one `inherits()`
call on a column already known to match, and removing it would mean
splitting the predicate out into a third helper to keep the single
definition — more machinery than the saving is worth.

Third helper, for the reverse direction. Used by `survey_data()` only, and
`survey_data()` is in `R/utils.R`, so it goes there.

Write the class back with **base R**. Do not call `haven::labelled()` or
`haven::labelled_spss()`.

```r
# Rebuild the haven labelled class on one vector, from the attributes the
# strip preserved. Returns x unchanged when x carries no `labels` attribute.
# Restores the SPSS variant when either SPSS missing-value attribute is
# present. Needs no haven at runtime.
#' @noRd
.restore_haven_class <- function(x) {
  labels <- attr(x, "labels", exact = TRUE)
  if (is.null(labels)) {
    return(x)
  }
  spss <- !is.null(attr(x, "na_values", exact = TRUE)) ||
    !is.null(attr(x, "na_range", exact = TRUE))
  attr(x, "class") <- if (spss) {
    c("haven_labelled_spss", "haven_labelled", "vctrs_vctr", typeof(x))
  } else {
    c("haven_labelled", "vctrs_vctr", typeof(x))
  }
  x
}
```

A `haven_labelled` vector is attributes plus a class vector. Nothing about
constructing one needs `haven`. Verified against `haven`'s own constructors
on six shapes — labelled double, integer, character, `haven_labelled_spss`
with `na_values`, the same with `na_range`, and a column holding a tagged
`NA`:

| Check | Result |
|---|---|
| `identical()` to `haven::labelled()` or `labelled_spss()` output | **TRUE, all six shapes** |
| class chain matches the original exactly | TRUE |
| attribute set matches | TRUE |
| `inherits(x, "haven_labelled")` | TRUE |
| `vctrs::vec_ptype()` accepts it | TRUE |
| `haven::as_factor()` and `labelled::to_factor()` labels | correct |

`typeof(x)` supplies the base-type marker, so integer- and
character-backed columns need **no** special case. That removes an edge case
rather than adding one: there is no type branch to get wrong.

The helper is idempotent on an already-classed column: `attr(x, "class") <-`
overwrites with the same value the column already has.

**Trade-off one — the class chain is hardcoded.** If `haven` ever changed
its class vector, this helper would produce a stale chain, where
`haven::labelled()` would track upstream. Accepted: the chain is de facto
public API that `vctrs` dispatch already depends on, and the strip in §III.2
depends on the same stability from the other direction. The mitigation is a
test that pins the expected chain, so an upstream change fails loudly instead
of silently.

**Trade-off two — no input validation.** `haven`'s constructors check that
`labels` is named and shares the type of `x`. This path skips those checks,
which is correct: it **restores** attributes that came off a valid labelled
column, rather than constructing from user input. A caller who hand-set a
malformed `labels` attribute before construction keeps it through the strip,
and the restore writes a class over it. Not worth validating for. The two
functions that do accept user-supplied labels — `set_val_labels()` and the
import — already own that check.

Fourth new helper. One call site, in one file, so it is defined at the top of
that file — not in `R/utils.R`. §VII explains why a one-line wrapper around
`requireNamespace()` is justified at all:

```r
# Is the haven namespace available? Wrapped in a helper so tests can stub it.
# Behaviour is identical to calling requireNamespace() inline.
#' @noRd
.haven_available <- function() {
  requireNamespace("haven", quietly = TRUE)
}
```

### Helper contracts — degenerate and unusual inputs

`.strip_labelled_columns()` must behave as follows. None of these rows
raises. The helper is not a validator; every input that reaches it has
already passed, or is about to pass, the checks that own that job.

| Input | Behaviour | Why |
|---|---|---|
| zero-column frame — `data.frame()` | returns the input unchanged | `vapply()` over an empty list returns `logical(0)`, and `which()` returns `integer(0)`, so the early return fires. This is the property default at `R/core-classes.R:307`, so it runs on every construction that omits `data`. |
| zero-row frame with columns | returns the input unchanged unless a column carries the class, in which case the class goes | the predicate reads the class attribute, which exists independently of length |
| list column | left alone | a list column cannot carry `haven_labelled`, and `inherits()` on it returns FALSE. Design variables are separately rejected as list columns at `R/core-classes.R:437` and `R/core-validators.R:218`. |
| matrix column | left alone | same reasoning. `inherits()` returns FALSE. |
| a frame with duplicate column names | operates on every column by position | `which()` returns positions, and `data[[j]]` with an integer index is position-based, so duplicate names cannot alias. Duplicate names are separately rejected at `R/core-validators.R:86-98`. |
| not a data frame at all | undefined; do not add a guard | every caller either has already run `.validate_data_frame()`, or is the S7 setter, where the `S7::class_data.frame` property type has already rejected a non-frame. A guard here would be dead code and would need a `# nocov` marker. |

`.strip_labelled_class()`: returns its argument unchanged for `NULL`, for a
zero-length vector, and for any object not inheriting `haven_labelled`.

`.restore_haven_class()`: returns its argument unchanged when the `labels`
attribute is absent. It is idempotent on a column that already carries the
class. It does not validate the `labels` attribute — a malformed one came
from the import or from `set_val_labels()`, both of which own that check.

**Correction, 2026-09-03 (issue #206).** One row was missing from this
contract, and its absence was a bug, not a gap in prose. `attr(x, "class") <-
...` replaces the whole class vector, so the rebuild wrote the haven chain
over any class the column already had: a `factor` carrying a `labels`
attribute came back as `haven_labelled` over its level codes, with the levels
gone, and a `Date` came back as its day count. `set_val_labels()` on a data
frame writes the attribute onto any column, so a user frame reached this with
no `haven` involved and nothing warned. The added row:

| Input | Behaviour | Why |
|---|---|---|
| a column carrying a class of its own — `factor`, `Date`, `POSIXct` | the two attributes are written; the class is left alone | there is no haven class to rebuild on it, and the write would destroy the class it has. The strip only ever removes `haven_labelled`, so a classed column reaching the helper never carried it. |

### Collation note

`DESCRIPTION` has no `Collate` field, so R collates `R/` alphabetically:
`core-classes.R` is parsed before `utils.R`. The setter body only
*references* `.strip_labelled_columns()`; it never calls it at parse time.
By the time any assignment happens the whole namespace is loaded. Do not add
a `Collate` field.

---

## III. The labelled-class strip

### III.0 Two parts, neither redundant

The strip has two halves. Each covers routes the other cannot reach. Both
are required.

| Part | Where | Covers |
|---|---|---|
| **Part 1** | one call on the incoming frame, on entry to each of the four constructors, before any validation | a labelled `weights` column and a labelled `fpc` column, which abort during validation on the **raw caller frame**, before anything reaches `@data` |
| **Part 2** | a `setter` on the `data` property of `survey_base` | a direct `survey_taylor(data = labelled_df, ...)` call, a bare `des@data <- labelled_df` assignment, every dplyr verb method in `surveytidy`, and the ten post-construction `@data` writes inside `R/` |

**Seven call sites in total**: four constructor entries (§III.5), the setter
(§III.4), and two in the conversion route (§IV.3), where the frame is read
by value-matching code before any S7 call. That is far short of the roughly
17 sites a per-analysis-function design needs, and far short of the 80
`design@data[[...]]` read sites a per-accessor design would need. The
conclusion that this is the smallest correct surface holds at seven as it did
at five.

Part 2 is **not** belt-and-braces for Part 1. Part 1 never sees a design
built by a direct S7 call or mutated by `surveytidy`. Part 1 is **not**
belt-and-braces for Part 2 either: measured, with Part 2 in place and Part 1
absent, two routes still abort.

| Route | Error | Aborts at | Called from |
|---|---|---|---|
| labelled `weights` | `vctrs_error_ptype2` | `all(non_na == 0)`, `R/core-validators.R:152` | `R/core-constructors.R:326` |
| labelled `fpc` | `vctrs_error_ptype2` | `sum(fpc_col_j <= 0, na.rm = TRUE)`, `R/core-constructors.R:380` | inline in `as_survey()` |

Both read the caller's frame, not `@data`, so the setter has not fired when
they run. This is from the traceback of a working spike, not from reasoning.

### III.1 Why a property setter for Part 2

Eleven routes write `@data`. Five of them accept a caller-supplied data
frame and reach an S7 constructor independently:

| Route | Entry | Constructs at |
|---|---|---|
| 1 | `as_survey()` | `R/core-constructors.R:557` |
| 2 | `as_survey_replicate()` | `R/core-constructors.R:816` |
| 3 | `as_survey_nonprob()` | `R/core-constructors.R:1625` |
| 4 | `from_svydesign()`, and `from_tbl_svy()` through it | `R/methods-conversion.R:416`, `:450`, `:502` |
| 5 | Direct S7 construction: the class objects are exported (`NAMESPACE:104-113`), so `survey_taylor(data = labelled_df, ...)` bypasses routes 1 to 4 | the class constructor itself |

`as_survey_twophase()` takes `data <- phase1@data`
(`R/core-constructors.R:955`) and requires `phase1` to be a `survey_base`
(`:937-953`), so it inherits whatever the other routes leave. Ten more
`@data` writes happen after construction inside `R/`
(`R/analysis-diffs.R:282`, `:360`, `:364`;
`R/analysis-t-test.R:210`, `:314`, `:315`, `:771`, `:810`, `:814`;
`R/analysis-quantiles-helpers.R:187`; `R/analysis-ratios-helpers.R:106`).
None of those can introduce a labelled column today, because every value
assigned is a factor, a logical mask or a computed numeric — but they are on
the covered path anyway.

`surveytidy` owns every dplyr verb for survey objects. No `mutate`,
`select`, `rename`, `filter` or `bind_rows` method exists in `R/`: the only
`S7::method()` registrations are `print`, `summary`, `names`, `length` and
`[[` (`R/methods-compat.R:23`, `R/methods-print.R:204-979`). So
`surveytidy::mutate()` can write a labelled column into `@data` and no
constructor edit can stop it.

The `data` property is declared **once**, on the abstract parent
`survey_base` (`R/core-classes.R:305-308`). The four concrete classes carry
`parent = survey_base` and add only their own properties
(`R/core-classes.R:407`, `:616`, `:765`, `:1178`). One setter on that one
property therefore covers the stored state for all five routes above, the
ten post-construction writes, and every external assignment including
`surveytidy`.

Verified by spike: routes 1, 2, 3, 5 and a bare `des@data <- labelled_df`
assignment all leave zero labelled columns in `@data`, and labelled `ids`
plus `strata` with `nest = FALSE` no longer aborts.

### III.2 The predicate

`inherits(x, "haven_labelled")`.

| Class chain | Predicate | Stripped |
|---|---|---|
| `haven_labelled`, `vctrs_vctr`, `double` | TRUE | yes |
| `haven_labelled`, `vctrs_vctr`, `integer` | TRUE | yes |
| `haven_labelled`, `vctrs_vctr`, `character` | TRUE | yes |
| `haven_labelled_spss`, `haven_labelled`, `vctrs_vctr`, `double` | TRUE | yes |
| `labelled` alone, no `vctrs_vctr` | FALSE | no — needs no handling |
| any other `vctrs_vctr` type | FALSE | no — deliberately left alone |

The predicate is indifferent to the underlying type. A character-backed
labelled column is as common in survey exports as a double-backed one, and
it is stripped the same way. Its consequence for printed output differs —
see §VIII.3.

`haven` uses the identical test for its own `is.labelled()`. The SPSS
variant lists `haven_labelled` second in its class vector, so one
`inherits()` call catches both failing shapes.

The strip removes the **whole** class attribute in one step, so
`haven_labelled_spss`, `haven_labelled`, `vctrs_vctr` and the base-type
marker all go together.

### III.3 What the strip must not do

Do **not** call `as.numeric()`, `as.double()`, `as.vector()`, `unclass()`
or `vctrs::vec_data()` on the column. Two reasons:

- `as.numeric()` on a labelled column goes through `vctrs` and aborts when
  `haven` is absent. That is the defect, not the fix.
- `as.vector()` drops **every** attribute, including `labels`, `label`,
  `na_values` and `na_range`. The bundled-data preparation scripts use that
  form and then re-attach two of the four
  (`data-raw/prepare-gss-2024.R:98-109`). The setter must not repeat that
  loss.

Removing the class attribute directly keeps every other **attribute** in
place. Measured: `labels`, `label`, `na_values` and `na_range` all survive,
and a haven tagged `NA` keeps its byte pattern and its readable tag.

### III.3a The whole class vector goes, including a foreign class above it

"Keeps every other attribute" is precise about attributes and says nothing
about the class vector, so state the class behaviour separately.

`attr(x, "class") <- NULL` removes the **entire** class vector, not the
`haven_labelled` and `vctrs_vctr` entries from it. A caller who has stacked
their own class on top loses it. Measured: a column classed
`c("my_extra_class", "haven_labelled", "vctrs_vctr", "double")` is stored as
bare `numeric`.

**Accepted, not fixed.** The reasoning:

- A class stacked above `haven_labelled` inherits `vctrs_vctr`, so it
  reaches the same `vctrs` dispatch that is the whole defect. Preserving the
  foreign entry while removing `vctrs_vctr` beneath it would leave a class
  vector whose parent is gone — a shape no package expects and none can
  dispatch on correctly.
- The alternative, `class(x) <- setdiff(class(x), c("haven_labelled",
  "vctrs_vctr"))`, produces exactly that broken shape, and it also leaves a
  `haven_labelled_spss` entry behind with nothing under it.
- No known package stacks a class above `haven_labelled`. `haven` itself
  puts `haven_labelled_spss` above, and that variant is removed
  deliberately and rebuilt on request by §VIII.1.

Record it in the `NEWS.md` entry so a caller who does this finds out from
the release notes rather than from a silent behaviour change.

### III.4 The setter

Replace `R/core-classes.R:305-308` with:

```r
    data = S7::new_property(
      S7::class_data.frame,
      default = quote(data.frame()),
      # Drops the haven labelled class from every column, on every write.
      # Value labels stay on the column and in @metadata@value_labels.
      # S7 does not re-enter a setter already running for the same
      # property, so the assignment below does not loop. Measured.
      setter = function(self, value) {
        self@data <- .strip_labelled_columns(value)
        self
      }
    ),
```

S7 fires the setter at construction and on `@data <-` assignment. Both were
measured.

`self@data <- ...` inside the `data` setter does **not** loop. Measured on
S7 0.2.2, counting setter entries across two successive assignments:

| Form | Setter calls for 2 assignments | Strip applied |
|---|---|---|
| `self@data <- .strip_labelled_columns(value)` | 2 — one per assignment | yes |
| `S7::prop(self, "data", check = FALSE) <- value` | 2 — identical | yes |

S7 does not re-enter a setter that is already running for the same property.
Both forms behave identically, so the plain `@` form is mandated on
readability grounds alone. Do not reach for
`S7::prop(self, "data", check = FALSE) <- value` or
`attr(self, "data") <- value`: neither is needed, and both cost a reader a
detour to work out why the obvious form was avoided.

This spec does not assert a mechanism inside S7 for why the re-entry does
not happen. The measurement above is what it relies on, and it is what a
future reader should re-run if an S7 upgrade changes the behaviour. Pin the
S7 version in the implementation notes so that re-run has a baseline.

The spike confirmed the inherited setter fires for `survey_taylor`,
`survey_replicate` and `survey_nonprob`, through their constructors, through
a direct `survey_taylor(data = ...)` call, and on a bare `des@data <-`
assignment. So inheritance from the abstract parent works.

> ⚠️ GAP: the spike did not exercise `survey_twophase`. The builder must
> demonstrate that the inherited setter fires for it too, at construction
> and on assignment. If it does not, redeclare the property with its setter
> on each of the four concrete classes and record that in the
> implementation notes.

### III.5 Part 1 — strip on entry, before validation

The strip must be in force before any code compares or coerces a design
column. Measured failures at construction today, with `haven` absent:

| Input | Result today | How established |
|---|---|---|
| labelled `weights`, via `as_survey()` | aborts, `vctrs_error_ptype2` | measured |
| labelled `fpc`, via `as_survey()` | aborts, `vctrs_error_ptype2` | measured |
| labelled `ids` **and** `strata`, `nest = FALSE` | aborts, `vctrs_error_cast` | measured |
| labelled `ids` **and** `strata`, `nest = TRUE` | passes | measured |
| labelled `ids` only, or `strata` only | passes | measured |
| labelled `weights`, via `as_survey_replicate()` or `as_survey_nonprob()` | expected to abort the same way | **inferred, not measured** — see below |

The sites that raise are:

| Site | Expression |
|---|---|
| `R/core-validators.R:152` | `all(non_na == 0)` |
| `R/core-validators.R:170` | `sum(non_na <= 0)` |
| `R/core-validators.R:346-347` | `as.character(data[[ids[[1L]]]])`, `as.character(data[[strata]])` |
| `R/core-classes.R:470` | `sum(!is.na(wt_col) & wt_col <= 0)` |
| `R/core-classes.R:496-497` | the same `as.character()` pair inside the S7 validator |
| `R/core-constructors.R:247`, `:273` | `1 / data[[probs_var]]` |
| `R/core-constructors.R:380` | `sum(fpc_col_j <= 0, na.rm = TRUE)`, inline in `as_survey()` |

**Evidence boundary, stated plainly.** `.validate_weights()` is called from
three places, verified by grep:

| Call site | Constructor | Labelled-weights failure |
|---|---|---|
| `R/core-constructors.R:326` | `as_survey()` | measured |
| `R/core-constructors.R:758` | `as_survey_replicate()` | inferred by analogy |
| `R/core-constructors.R:1382` | `as_survey_nonprob()` | inferred by analogy |

Only the `as_survey()` route was measured. The other two reach the identical
function with an identical argument shape, so the inference is strong, but it
is an inference. The remedy is the same line in all three, so this does not
change the work — it changes what the tests must confirm rather than assume.

The `nest = TRUE` pass is accidental: it skips `.validate_psu_strata()`, so
one logical argument decides whether the same design constructs. The fix
must remove that accident, not preserve it.

**Design variables not yet discussed anywhere.** Each of these is a column
the caller names, so each can carry the class, and none was measured. The
strip on entry covers all of them by construction, because it runs on the
whole frame before any of them is read. They are listed so the contract is
complete and so the tests know what to cover:

| Constructor | Columns |
|---|---|
| `as_survey()` | `ids` (any stage), `probs`, `weights`, `strata`, `fpc` (any stage) |
| `as_survey_replicate()` | `weights`, `repweights`, `fpc` |
| `as_survey_twophase()` | the phase-2 `ids`, `strata`, `probs` and `fpc` columns, plus the `subset` column |
| `as_survey_nonprob()` | `weights`, `repweights` |

One of those needs a note. The `subset` column of a two-phase design must be
logical (`R/core-constructors.R:997`). A labelled column is never logical, so
a labelled `subset` still raises
`surveycore_error_subset_not_logical` after the strip. That is correct
behaviour and must not change.

**SRS mode.** `as_survey(data, weights = wt)` with no `ids` and no `strata`
is a supported call: it warns `surveycore_warning_srs_no_weights` only when
`weights` is also absent (`R/core-constructors.R:275-289`). With a labelled
`weights` column and nothing else specified, the frame still reaches
`.validate_weights()`, so this mode fails today too and is fixed by the same
line.

Part 2 satisfies the ordering requirement for the two S7 validator sites
(`R/core-classes.R:470`, `:496-497`), because S7 runs the setter before the
validator. Measured: labelled `ids` plus `strata` with `nest = FALSE`
constructs cleanly with the setter alone.

Part 2 does **not** cover the Layer 3 sites in `R/core-validators.R` and
`R/core-constructors.R`. Those read the caller's `data` variable before any
S7 call, so the setter has not run. Measured: labelled `weights` and
labelled `fpc` still abort with the setter in place.

Therefore each of the four constructors must strip its frame as its first
action, before any validation:

| Function | Frame source | Insert immediately after |
|---|---|---|
| `as_survey()` | the `data` argument | `.validate_data_frame(data)` at `R/core-constructors.R:184` |
| `as_survey_replicate()` | the `data` argument | its `.validate_data_frame(data)` call |
| `as_survey_nonprob()` | the `data` argument | `.validate_data_frame(data)` at `R/core-constructors.R:1353` |
| `as_survey_twophase()` | `phase1@data` at `R/core-constructors.R:955` | that line |

The line is the same in all four:

```r
  data <- .strip_labelled_columns(data)
```

Everything downstream then sees stripped columns: `.validate_weights()`
(`R/core-constructors.R:326`), the inline FPC loop
(`R/core-constructors.R:372-513`), `.validate_design_vars()` (`:329`),
`.validate_psu_strata()`, the probs arithmetic at `:247` and `:273`, and
finally the `@data` write itself.

The `as_survey_twophase()` line is defence in depth rather than a fix for a
measured failure: `phase1` must be a `survey_base`
(`R/core-constructors.R:937-953`), so Part 2 has already stripped its
`@data`. Include it anyway. It costs one `inherits()` per column and it
removes the need for a future reader to reason about how `phase1` was built
before trusting the validation at `R/core-constructors.R:997`.

`from_svydesign()`'s three helpers need the line for a different reason —
`.find_col_by_value()`, covered in §IV.3. Apart from that call they build
`data` and construct immediately, with no validation in between
(`R/methods-conversion.R:382-420`, `:427-455`, `:462-507`).

### III.6 Cost of Part 2

The setter runs on **every** `@data` write. There is no cheaper correct
alternative: deciding whether to strip means testing every column, and that
test is the whole cost.

Two requirements follow, and both are binding:

1. **The helper must return early.** When no column carries the class,
   `.strip_labelled_columns()` returns the identical object — no copy, no
   allocation, no per-column write. The `if (length(hit) == 0L) return(data)`
   guard in §II is not a nicety; it is what keeps the common case free. The
   common case is every call on every dataset that has already been
   stripped, which after Part 1 is all of them.
2. **The per-column work must be one `inherits()` call and nothing else.**
   Do not call `class()`, do not build a character vector of classes, do not
   use `vapply(data, function(x) "haven_labelled" %in% class(x), ...)`.
   `inherits()` is a C-level check on the class attribute; the alternatives
   allocate.

Cost per assignment, when nothing matches: one `inherits()` call per column,
plus one `which()` over a logical vector of that length. On a 500-column
frame that is 500 attribute reads. On a 12-column frame it is 12.

This now runs inside **every** `surveytidy` dplyr verb method, so
`mutate()`, `select()`, `rename()` and `filter()` each pay it once per call.
It also runs on the ten post-construction `@data` writes inside `R/`, two of
which sit inside per-cell loops:

| Site | Calls per `get_*()` invocation |
|---|---|
| `R/analysis-quantiles-helpers.R:187` | one per variable × group combination × probability |
| `R/analysis-ratios-helpers.R:106` | one per pair × group combination |
| `R/analysis-diffs.R:282`, `:360`, `:364` | up to three per call |
| `R/analysis-t-test.R:210`, `:314`, `:315` | up to three per call |
| `R/analysis-t-test.R:771`, `:810`, `:814` | up to three per call |

**The timing requirement is a recorded measurement, not a merge gate.**

An earlier draft made this a quality gate reading "no measurable
regression". That is not falsifiable — it named no dataset, no iteration
count, no tolerance and no tool — so it could not have blocked anything, and
a gate that cannot fail is worse than no gate, because it implies a check
that never happened.

Two routes were available. Specify a concrete threshold, or demote it. This
spec demotes it, for three reasons:

- The operation is one attribute read per column. There is no plausible
  mechanism by which it dominates a variance computation, so a threshold
  would be theatre around a number nobody expects to move.
- A wall-time threshold on a shared CI runner is the least reliable gate in
  the suite. It fails on a noisy neighbour and passes on a real regression
  that happens to run on a quiet box.
- The correctness gates in §XI already forbid the two ways this could
  actually go wrong: dropping the early return, and replacing `inherits()`
  with an allocating alternative. Those are readable in the diff.

**What the builder must do instead**: record, in the implementation notes,
the timing of one grouped `get_quantiles()` call with three probabilities on
the widest bundled dataset, before and after, using `bench::mark()` or
`system.time()`, and state the observed ratio. If that ratio exceeds about
1.05, stop and report it rather than proceeding — not because 1.05 is a
principled threshold, but because anything above it contradicts the reasoning
above and means the reasoning is wrong.

**The risk this accepts**: a real regression on very wide frames ships
unnoticed. Bounded by the mechanism — one attribute read per column — and by
the recorded number, which makes the regression findable later rather than
invisible.

### III.7 Metadata capture order

`as_survey()`, `as_survey_replicate()` and `as_survey_nonprob()` each call
`.extract_haven_metadata(data)` on the local frame before the S7 constructor
(`R/core-constructors.R:547`, `:805`, `:1386`). That function reads
`attr(col, "label")` and `attr(col, "labels")` with base R
(`R/core-metadata.R:3732`, `:3744`) and stores them in
`@metadata@variable_labels` and `@metadata@value_labels`
(`:3739`, `:3751`).

The strip does not touch either attribute, so the harvest gives the same
result whether it runs before or after. The order is therefore free, and the
existing order stands: harvest first, then construct. Do not move it.

The guarantee that no label is lost rests on two independent stores:

1. `@metadata@value_labels`, populated by the harvest;
2. the `labels` attribute, still on the column after the strip.

`.extract_var_meta()` reads the first and falls back to the second
(`R/analysis-helpers.R:154-155`). `.apply_group_labels()` does the same
(`R/analysis-helpers.R:232-233`). Both read the **full** column
(`R/analysis-helpers.R:147`, `:230`), never a subset, which matters because
base `[` drops the `labels` attribute where `[.vctrs_vctr` kept it.

**Correction, 2026-09-02 (issue #205).** This section names the two stores
and says no label is lost. It never says which store wins when the two
disagree, and they do disagree: on a design, `set_val_labels()` writes the
metadata only and `set_var_label()` writes the metadata only, so a label
corrected or created on a design lives in one store and the import's label
lives in the other. The rule is now written down, and it is the one
`.extract_var_meta()` already followed: **the metadata store wins, and the
column attribute is the fallback.** `survey_data(haven_class = TRUE)` read
the attribute alone until #205, so it returned stale labels for a corrected
column and no labels at all for a column labelled on the design; §VIII.1
rule 2 carries the corrected wording.

---

## IV. Metadata capture on the conversion routes

### IV.1 The current gap

All three `from_svydesign()` helpers construct with an empty metadata
object:

| Helper | Constructs at | Metadata argument |
|---|---|---|
| `.from_svydesign_taylor()` | `R/methods-conversion.R:416-420` | `survey_metadata()` at `:419` |
| `.from_svydesign_replicate()` | `R/methods-conversion.R:450-454` | `survey_metadata()` at `:453` |
| `.from_svydesign_twophase()` | `R/methods-conversion.R:502-506` | `survey_metadata()` at `:505` |

None calls `.extract_haven_metadata()`. Measured: labels are still
reachable today through `extract_val_labels()`, but only because the class
survives and the column attribute survives with it, and the extractor falls
back to the attribute. `@metadata` is empty.

Once the setter strips the class on this route, the `labels` attribute is
still there, so the fallback still resolves. But leaving it that way puts
label capture on this route entirely on a fallback path, while the other
three routes populate `@metadata` properly. That is the kind of accidental
correctness this whole spec exists to remove.

### IV.2 Required change

`.from_svydesign_taylor()` and `.from_svydesign_replicate()` must each
replace `metadata = survey_metadata()` with a harvest of the frame they
already built:

```r
    metadata = .extract_haven_metadata(data)
```

`data` is `as.data.frame(x$variables)` in both
(`R/methods-conversion.R:382`, `:427`).

`.from_svydesign_twophase()` builds its data by calling
`.from_svydesign_taylor()` and taking `phase1_sc@data`
(`R/methods-conversion.R:462-463`). It must carry that object's metadata
forward rather than harvest a second time:

```r
    metadata = phase1_sc@metadata
```

`from_tbl_svy()` delegates to `from_svydesign()`
(`R/methods-conversion.R:575`), so it inherits the fix with no edit.

### IV.3 `.find_col_by_value()`

`.find_col_by_value()` runs `as.numeric(col)` at
`R/methods-conversion.R:298` while searching for the weight column by value.
`.from_svydesign_taylor()` reaches it at `:399` and
`.from_svydesign_replicate()` at `:431`. On a labelled column that
`as.numeric()` goes through `vctrs`, and measurement confirms
`from_svydesign()` aborts with `vctrs_error_ptype2` when the weight column
is labelled.

The helper receives `data` before any S7 construction, so the setter cannot
protect it. Strip in each of the two callers, immediately after the frame is
built:

```r
  data <- .strip_labelled_columns(as.data.frame(x$variables))
```

This replaces `R/methods-conversion.R:382` and `:427`. **These are call
sites 6 and 7** of the seven counted in §III.0. The metadata harvest in
§IV.2 then reads the stripped frame, which is fine — the strip keeps both
attributes the harvest looks for.

`.from_svydesign_twophase()` needs no third call: it takes its frame from
`.from_svydesign_taylor()` (`R/methods-conversion.R:462-463`), which has
already stripped it.

`.find_col_by_value()` itself needs no edit. Its `is.numeric(col)` guard at
`R/methods-conversion.R:294` already returns TRUE on a labelled double, so
its behaviour is unchanged either way.

---

## V. `set_val_labels()` on a labelled column

### V.1 The current failure

`set_val_labels()` validates the new labels against the stored column. It
reads the column at `R/core-metadata.R:2424-2428` — `x@data[[var_name]]` on
a survey object, `x[[var_name]]` on a data frame — and passes it to
`.validate_val_labels()` at `:2429`.

`.validate_val_labels()` runs, at `R/core-metadata.R:3672-3675`:

```r
  unique_vals <- unique(var[!is.na(var)])
  label_vals <- as.character(labels)
  missing <- setdiff(as.character(unique_vals), label_vals)
```

`var[!is.na(var)]` keeps the labelled class, `unique()` keeps it, and
`as.character()` then aborts with `vctrs_error_cast`. Measured: the call
fails. `set_var_label()` and `extract_val_labels()` both pass, so the defect
is confined to this one validation path.

For a **survey object** Part 2 of §III fixes this by itself: the stored
column is already plain, so `as.character()` succeeds. Verified by the
spike — `set_val_labels()` moves from fatal to working with the setter alone
and no edit here.

For a **data frame** it does not. Data frames are never stripped, and
`set_val_labels()` accepts both input modes
(`R/core-metadata.R:2424-2428`). So the one-line change below is what closes
the data-frame mode.

### V.2 Required change

Strip locally, in `.validate_val_labels()`:

```r
  unique_vals <- .strip_labelled_class(unique(var[!is.na(var)]))
```

One line, reusing the same helper. It changes nothing for a plain column,
because the helper returns its argument unchanged. It makes
`set_val_labels()` work in both input modes.

`.validate_val_labels()` has exactly one caller
(`R/core-metadata.R:2429`), so there is no other behaviour to consider.

---

## VI. Ordinality classification

### VI.1 What the defect actually is

`get_corr(method = "polychoric")` refuses a value-labelled scale. The cause
is not the labelled class. Measured classifications, before any change:

| Input | Classified as |
|---|---|
| labelled **double** `1:3` | continuous |
| plain **double** `1:3` | continuous |
| labelled **integer** `1:3` | integer ordinal |
| plain **integer** `1:3` | integer ordinal |

The gate branches on storage type and never inspects the class. So the
defect is **"integer-valued doubles are not seen as ordinal"**, it predates
labelled input, and it has affected every user since polychoric shipped.
`haven::read_sav()` produces doubles, which is why every SPSS-sourced file
hits it.

The gate is `.corr_detect_ordinal()` at `R/analysis-corr-latent.R:41-66`.
Its `is.double` branch, `R/analysis-corr-latent.R:55-63`, returns
`"continuous"` unconditionally.

### VI.2 This overturns a documented decision

`R/analysis-corr-latent.R:60-62` says:

```r
    # Integer-valued doubles with small cardinality are still continuous
    # under the spec's strict reading ("is.double" → "continuous").
```

The "spec" it names is `archive/polychoric-corr/spec-polychoric-corr.md:112`.
That decision was deliberate. This spec reverses it, with the user's
explicit sanction.

The comment above must be **replaced**, not left in place. A comment that
contradicts the code below it is worse than no comment. The replacement must
say what the branch now does and why the cutoff still applies.

### VI.3 Required change

Replace `R/analysis-corr-latent.R:55-63` with:

```r
  if (is.double(col)) {
    non_na <- col[!is.na(col)]
    if (length(non_na) == 0L) {
      return("continuous")
    }
    # A whole-valued double within the cardinality limit is an ordinal
    # scale. SPSS, Stata and SAS files store every coded scale as a double,
    # so the earlier "is.double means continuous" rule refused the exact
    # input polychoric correlation exists to serve. This branch mirrors the
    # is.integer branch above and shares its cutoff.
    # is.finite() is load-bearing: trunc(Inf) == Inf is TRUE, so without it
    # an infinite value passes as a whole number and becomes a category.
    if (all(is.finite(non_na)) && all(non_na == trunc(non_na))) {
      n_distinct <- length(unique(non_na))
      if (n_distinct <= integer_cardinality_cutoff) {
        return("integer_ordinal")
      }
    }
    return("continuous")
  }
```

**Why `all(is.finite(non_na))` is not optional.** Without it, a column
containing `Inf` classifies as an ordinal scale and `Inf` becomes an ordinary
top category. Measured end to end: `get_corr(method = "polychoric")` on a
column containing `Inf` **returns a correlation of about -0.056** instead of
raising. A fabricated number with no error is the worst available outcome,
and it is worse than the refusal this section exists to remove.

`NA` and `NaN` need no extra handling. Both are `is.na()`-true, so both are
already removed by the `non_na` line above the guard. Do not add a separate
`NaN` test; it would be dead code.

| Value present in the column | Reaches the guard | Classified |
|---|---|---|
| `NA` | no — filtered above | ignored |
| `NaN` | no — filtered above | ignored |
| `Inf`, `-Inf` | yes | continuous, because `is.finite()` is FALSE |

The guard order matters for cost as well as correctness: `is.finite()` runs
before `trunc()`, so a column of fractional values short-circuits on the
cheaper test in most real cases.

The header comment block at `R/analysis-corr-latent.R:33-40`, which lists
the return values, must be updated in the same edit: `"integer_ordinal"` is
no longer "`is.integer()` with <= cutoff distinct values" alone, and
`"continuous"` is no longer "`is.double()`".

Nothing downstream of the gate changes. Threshold estimation already
handles a plain numeric ordinal vector: `R/analysis-corr-latent.R:225-227`
runs `sort(unique(...))` and `match()`, which needs no whole numbers and
imposes no storage type. The existing degeneracy guards still fire —
`surveycore_error_polychoric_single_level_ordinal` when fewer than two
positive-weight levels remain (`R/analysis-corr-latent.R:248-264`), and
`surveycore_error_polychoric_insufficient_cells` for a sparse bivariate
table.

### VI.4 Resulting classification contract

With the cutoff at its existing value of `10L`
(`R/analysis-corr-latent.R:41`):

| Column shape | Classified as | Changed |
|---|---|---|
| ordered factor | ordered | no |
| unordered factor | factor | no |
| integer, at most 10 distinct | integer ordinal | no |
| integer, more than 10 distinct | ambiguous | no |
| double, all values whole and finite, at most 10 distinct | **integer ordinal** | **yes** |
| double, all values whole and finite, more than 10 distinct | continuous | no |
| double with any fractional value | continuous | no |
| double containing `Inf` or `-Inf` | continuous | no |
| double, all `NA` | continuous | no |
| double containing `NA` or `NaN` alongside whole finite values, at most 10 distinct among the rest | **integer ordinal** | **yes** |
| character, logical, complex, raw, list | ambiguous | no |

Two rows change, and they are the same rule seen twice: a whole-valued
finite double becomes ordinal, whether or not the column also carries missing
values. Every other row is unchanged.

**Correction, issue #209 (2026-09-02).** The table above has no row for an
all-`NA` integer, and the `is.integer` branch had no guard for it. Its
`n_distinct` was `0`, `0 <= 10` was `TRUE`, and the column classified
integer ordinal, while the identical all-`NA` double classified continuous.
The two paths then disagreed: `get_corr(method = "polychoric")` returned
`r = NA, n = 0` for the integer and raised
`surveycore_error_polychoric_requires_ordinal` for the double. The fix adds
the same zero-length guard to the `is.integer` branch, so the table now
carries these two rows in place of the single `double, all NA` row:

| Column shape | Classified as | Changed by #209 |
|---|---|---|
| integer, no non-`NA` value (all `NA`, or `integer(0)`) | continuous | **yes** |
| double, no non-`NA` value (all `NA`, or `numeric(0)`) | continuous | no |

The rule is that ordinality of a bare numeric column is read off its
observed values, and an empty column shows none. A factor or ordered column
declares its levels, so it stays ordinal with no data and keeps the
`r = NA, n = 0` route; only bare numerics lose ordinal status when empty.

Two `method = "polyserial"` outcomes move with it. An all-`NA` integer
paired with an ordered factor raised
`surveycore_error_polyserial_requires_mixed_types` and now returns
`r = NA, n = 0`; paired with a continuous column it returned `r = NA, n = 0`
and now raises that error. Both now match the all-`NA` double.

This change is pre-verified. The patch in §VI.3 was applied to a throwaway
copy of the package and the four existing correlation test files ran against
it: 246 tests, 718 expectations, 0 failures, 0 errors, 0 skips. **That is the
measurement taken before the change; the shipped suite reports 290 tests and
825 expectations, still 0 failures. Noted 2026-09-01.** Nothing that
passes today breaks. `get_corr(method = "polychoric")` on a pair of coded
scale columns, which aborted before, succeeds.

### VI.5 Accepted limitations, stated on purpose

Four shapes now classify as ordinal that a reader might question. All four
are accepted, and the reason is the same in each case: `method =
"polychoric"` is opt-in and `"pearson"` is the default
(`R/analysis-corr.R:105-111`), so no default behaviour changes anywhere. A
user reaches the new branch only by asking for polychoric on that column.

| Shape | Outcome | Why it is accepted |
|---|---|---|
| `c(1000, 2000, 3000)` — could be income in dollars | classified ordinal, polychoric runs and returns a number | **A known false positive.** Whole-valued, three distinct values, inside the cutoff. surveycore cannot tell dollars from a three-point scale from the data alone. The user asked for polychoric on a column with three distinct values. |
| `c(2, 2, 2)` — one distinct value | classified ordinal, then aborts with `surveycore_error_polychoric_single_level_ordinal` | This is the intended path. The gate no longer rejects it, and the downstream guard raises a typed error naming the column and the remedy. A typed error is a better outcome than the previous untyped refusal. |
| `c(0, 1, 1, 0)` — binary indicator | classified ordinal, polychoric runs | Legitimate. Polychoric correlation on a binary pair is the tetrachoric case. |
| A scale column that still carries its in-band SPSS sentinel codes — `c(1, 2, 3, 4, 8, 9)` where 8 is "Don't know" and 9 is "Refused" | classified ordinal, polychoric runs, and 8 and 9 become the top two categories of the scale | **A known false positive, and the most likely one in practice.** See below. |

**The in-band sentinel case, in full.** This is the one a real SPSS file hits
most often, and it deserves more than a table row.

An SPSS export commonly codes missing reasons in band: 8 for "Don't know",
9 for "Refused", or -99 for "Not asked". Those codes are whole numbers, they
are inside the cardinality limit, and they are usually value-labelled. So a
four-point scale carrying two sentinel codes classifies as a six-category
ordinal variable, and the estimated thresholds are shifted by two categories
that are not scale points at all.

This was inert before D3, because such a column classified continuous and
polychoric refused it outright. D3 makes it live. That is a real widening of
the failure surface and it must be recorded as such, not glossed.

It is accepted rather than fixed, for three reasons:

- The package already stores the information needed to detect it. A user can
  declare sentinel codes with `set_missing_codes()`
  (`R/core-metadata.R:2688`) and read them back with
  `extract_missing_codes()` (`R/core-metadata.R:841`). **No analysis
  function reads that metadata** — verified by grep across
  `R/analysis-*.R`. Making the ordinality rule the first consumer of it
  would set a precedent for every other analysis function, and that is a
  design decision about the metadata system, not about this defect.
- Excluding codes silently would be worse. A rule that drops 8 and 9 from a
  scale without saying so changes the estimate by an amount the user cannot
  see, and it would fire on any legitimate 8-point or 9-point scale.
- The remedy is already the documented workflow: recode sentinels to `NA`
  before analysis. `R/data.R:382` tells the user exactly this for the
  bundled GSS data — "Recode them to `NA` before analysis."

**Required documentation**, so this is discoverable at the point of use and
not only here: the `@param x` text for `get_corr()` must state that a
value-labelled numeric column is treated as a scale, and that in-band
missing codes must be recoded to `NA` first or they will be counted as scale
points. The `NEWS.md` entry must say the same. Rows one and four of the table
above both belong in that text.

> ⚠️ GAP: reading `extract_missing_codes()` in the ordinality rule is
> deliberately out of scope here, and it is the obvious follow-up. It should
> be filed as its own issue, because the right answer spans every analysis
> function and not just this one.

### VI.6 Polyserial — a behaviour change

`polyserial` shares the same gate. `.corr_canonicalize_polyserial()` calls
`.corr_detect_ordinal()` on both sides
(`R/analysis-corr-latent.R:85-92`), and the dispatcher reaches it at
`R/analysis-corr-latent.R:1666`. It requires exactly one ordinal side and
one continuous side, and raises
`surveycore_error_polyserial_requires_mixed_types` otherwise
(`R/analysis-corr-latent.R:134-153` for two ordinal sides,
`:154-173` for two continuous sides).

Because more columns now classify as ordinal, some pairs move across that
boundary in each direction:

| Pair | Before | After |
|---|---|---|
| whole-valued small double + genuine continuous double | both continuous → aborts | ordinal + continuous → **works** |
| whole-valued small double + whole-valued small double | both continuous → aborts | both ordinal → aborts, message text differs |
| whole-valued small double + ordered factor, or + small integer | ordinal + continuous → works | **both ordinal → aborts** |
| ordered factor + genuine continuous double | works | works |
| two ordered factors | aborts | aborts |
| double containing `Inf` + ordered factor | ordinal + continuous → unchanged | ordinal + continuous → unchanged, because `is.finite()` keeps the `Inf` column continuous |

The last row is the reason the `is.finite()` guard matters here too, not only
for polychoric. Without it, an `Inf`-carrying column would become ordinal and
the pair would start raising the mixed-types error.

**Corrected 2026-09-01.** An earlier wording said the guard "keeps that pair
working". It does not work, on any tree in this series: the weighted SD goes
`NaN` and an untyped base error escapes. What the guard preserves is the
pair's **classification** — ordinal plus continuous — so it raises neither
PC-2 nor PC-3. That is what the corresponding test row pins.

**Row 3 is a breaking change.** A caller who previously got a polyserial
number from a whole-valued double paired with an ordinal column now gets
`surveycore_error_polyserial_requires_mixed_types`. Measured end to end.

This outcome is accepted, for three reasons:

- It is a typed, documented error with a remedy bullet, not a crash.
- `"polychoric"` is the correct method for a pair of ordinal columns, and
  the existing message already points the user at it
  (`R/analysis-corr-latent.R:145-149`).
- The alternative — a classifier whose answer depends on which method asked
  — trades one surprise for a worse one.

It must be recorded in `NEWS.md` as a behaviour change under a
`## Breaking changes` style heading, naming the shape of the affected pair.

### VI.7 Documentation that must change

`get_corr()`'s `@param x` at `R/analysis-corr.R:49-57` currently reads, for
polychoric, "every selected column must classify as ordinal (ordered
factor, unordered factor, or integer with `<= 10` distinct values)". That
sentence is now wrong. The replacement must:

- add whole-valued doubles with at most 10 distinct values to the ordinal
  set;
- state the known false positive from §VI.5 in the user's terms — a numeric
  column with few distinct whole values is treated as a scale, so a coarse
  measurement in whole units is accepted as ordinal;
- keep the existing sentence about `polyserial` canonicalization and add
  that a pair of ordinal columns raises the mixed-types error.

`R/analysis-corr.R:35-36` describes polychoric as being "for two ordinal
variables" and polyserial as "one ordinal + one continuous variable". Both
sentences stay true and need no edit.

### VI.8 Canonical error table rows

`plans/error-messages.md` states the trigger condition for three rows in
terms of the old classification. The `class` names and the message templates
do **not** change. Only the Condition column does.

| Row | Line | Current condition text, in part | Must become |
|---|---|---|---|
| PC-1 | `plans/error-messages.md:193` | "not `factor`, `ordered`, or small-cardinality `integer`" | must also name whole-valued doubles within the cardinality limit as ordinal |
| PC-2 | `plans/error-messages.md:194` | "Pair does not have exactly one ordinal and one continuous variable after auto-detection" | unchanged in substance; add that a whole-valued double now counts as ordinal, so a pair of them raises this |
| PC-3 | `plans/error-messages.md:195` | "integer with many distinct values, logical, character, or both sides ambiguous" | unchanged — the double branch never returns ambiguous |

No new row. No new class.

---

## VII. The `haven` availability helper

### VII.1 Why

`R/analysis-helpers.R:243` calls
`requireNamespace("haven", quietly = TRUE)` inside
`.apply_group_labels()`. That call loads the namespace as a side effect, and
loading `haven` registers its `vctrs` methods for the rest of the session,
which repaired every later call in the same session. That side effect is
what made the original defect look intermittent.

After the strip, no labelled column remains for those methods to act on, so
the side effect stops mattering for correctness. The `haven` use itself is
legitimate and stays: it resolves haven tagged `NA` values to their labels.
It is used at six places —
`R/analysis-helpers.R:248`, `:252`, `:264`, `:266`, `:287`, `:290`.

The problem left over is testability. A bare `requireNamespace()` cannot be
stubbed: an attempt to shim it inside the surveycore namespace fails with
`cannot add bindings to a locked environment`. So the graceful-degradation
branch — the path taken when `haven` is genuinely unavailable — cannot be
reached on purpose.

### VII.2 Required change

Add `.haven_available()` at the top of `R/analysis-helpers.R`, with the body
given in §II, and replace `R/analysis-helpers.R:243` with:

```r
      haven_ok <- .haven_available()
```

The six use sites keep reading the local `haven_ok` and do not change.

This is a testability change with no behaviour change. A top-level function
in the package is a namespace binding, so it can be stubbed by test
tooling; `requireNamespace()` called inline cannot.

**The two-call-site rule, and why this is a deliberate exception to it.**
`.claude/rules/code-style.md` §Function design says an internal helper used
in one file is defined inline in that file, and moves to `R/utils.R` only
when a second call site appears. A one-line wrapper around a single
`requireNamespace()` call would normally fail the "engineered enough" test in
`.claude/rules/engineering-preferences.md` §3 outright.

It is justified here because principle 2 of that same file — well-tested,
missing coverage is always a problem — outranks principle 3, and because the
branch is otherwise unreachable by any test. An attempt to stub
`requireNamespace()` inside the package namespace fails with `cannot add
bindings to a locked environment`. Without the named binding, the
graceful-degradation path can be exercised only by uninstalling `haven`,
which no test can do. The helper is the cheapest thing that makes a real
branch testable.

It has exactly **one** production call site, and the placement rule is
knowingly waived for it. An earlier draft claimed
`survey_data(haven_class = TRUE)` would be a second call site. It is not:
§VIII.1 rebuilds the class with base R and needs no `haven` at runtime.
Define this helper at the top of `R/analysis-helpers.R`, the one file that
uses it. Do not promote it to `R/utils.R`.

`R/analysis-helpers.R:243` is the only `requireNamespace("haven")` call in
`R/`. The `requireNamespace()` calls for `survey` and `srvyr` in
`R/methods-conversion.R` are out of scope and must not be touched.

---

## VIII. Observable contract changes

### VIII.1 `survey_data()` — full contract

`survey_data()` currently returns `@data` unchanged
(`R/utils.R:70-81`). It gains one argument.

#### Signature

```r
survey_data(x, haven_class = FALSE)
```

`haven_class` is an optional scalar control argument, so it follows `x`, per
`.claude/rules/code-style.md` §Function design argument order.

#### Arguments

| Name | Type | Default | Description |
|---|---|---|---|
| `x` | `survey_base` subclass | — | The survey design object to read. |
| `haven_class` | `logical(1)` | `FALSE` | Rebuild the `haven_labelled` class on every column that has value labels, in `@metadata@value_labels` or in the column's `labels` attribute. `FALSE` returns base types, which is what every arithmetic and modelling operation needs. `TRUE` returns columns that `haven` and `labelled` recognise. Corrected 2026-09-02 by issue #207: the wording said "every column that carried it at import", which claims a provenance test the code never had. Corrected again 2026-09-02 by issue #205: the wording named the attribute as the only store the rebuild reads, and the rebuild now reads the metadata first. Corrected again 2026-09-03 by issue #206: the rebuild skips a column that carries a class of its own, so a labelled `factor` or `Date` comes back unchanged. |

#### Returns

A data frame — a tibble when the design stores a tibble, because the `data`
property is typed `S7::class_data.frame` (`R/core-classes.R:306`) and does
not coerce.

With `haven_class = FALSE`, the default:

> No column carries the `haven_labelled` or `haven_labelled_spss` class. A
> survey design object stores base types. Every attribute the import set —
> the `label` string, the `labels` value-label vector, and the SPSS
> `na_values` and `na_range` vectors — stays on the column. Value labels are
> also available through `extract_val_labels()`.

With `haven_class = TRUE`:

> Every column that has value labels is returned with its `haven_labelled`
> class rebuilt, so that `haven` and `labelled` functions recognise it. A
> column that also carries `na_values` or `na_range` is returned as
> `haven_labelled_spss`. The `labels` and `label` attributes on the returned
> column hold what `@metadata` holds, and the column's own attribute is the
> fallback for each. Values are unchanged. `haven` does not need to be
> installed. Arithmetic on the returned columns requires the `haven`
> namespace to be loaded, which is why `FALSE` is the default.

Corrected 2026-09-02 by issue #205: the paragraph named the `labels`
attribute as the trigger and the SPSS clause as a provenance test. It now
names the resolved value labels and the two SPSS attributes.

Corrected again 2026-09-03 by issue #206: "every column that has value
labels" included a `factor` and a `Date`, and the rebuild wrote the haven
class over theirs. Read it as "every column that has value labels and no
class of its own". §VIII.1 rule 8 carries the matching rule.

#### Errors

| Class | Trigger |
|---|---|
| `surveycore_error_not_survey_object` | `x` is not a survey design object. Existing behaviour, `R/utils.R:71-79`. |

**One new error class.** `surveycore_error_haven_class_not_logical`
validates the flag itself, per rule 7 below and D6. It names its own
argument, as all five scalar-flag classes already in the table do.

A second class was proposed and withdrawn: an error for "`haven` is not
installed", added by an earlier draft because the rebuild called
`haven::labelled()`. The rebuild uses base R instead (§II), so that
condition cannot arise and the class is not needed.

#### Behaviour rules

1. `haven_class = FALSE` returns `@data` unchanged, exactly as today. No
   copy, no coercion, no filtering.
2. `haven_class = TRUE` applies `.restore_haven_class()` to every column,
   passing that column's `@metadata@value_labels` and
   `@metadata@variable_labels` entries. The helper writes each one it is
   given onto the column and falls back to the column's own `labels` and
   `label` attributes, so a label corrected or created by `set_val_labels()`
   or `set_var_label()` on the design reaches the returned column. The
   helper returns a column unchanged when neither store holds value labels,
   so plain columns are untouched. Corrected 2026-09-02 by issue #205; the
   rule read the attribute only. One limit follows from D5: `set_val_labels(x,
   v = NULL)` clears the metadata entry without touching the column, so the
   fallback rebuilds the class from the column's own attribute.
3. The rebuild chooses the SPSS variant when the column carries either
   `na_values` or `na_range`, and the base class otherwise.
4. The rebuild does not branch on the underlying type. `typeof()` supplies
   the base-type marker. Verified for double-, integer- and
   character-backed columns.
5. `haven_class = TRUE` on a design whose columns never carried labels
   returns the same frame as `haven_class = FALSE`.
6. Neither value of `haven_class` requires `haven` to be installed or
   loaded.
7. `haven_class` must be a length-one logical. A non-logical or
   length-other-than-one value is a programming error. Validate it the way
   the package validates every other scalar flag: with a class that names
   this argument, `surveycore_error_haven_class_not_logical`. See D6.
8. The rebuild leaves a column that carries a class of its own alone. A
   `factor` keeps its levels, a `Date` keeps its calendar, and the helper
   assigns no class to it. The `label` and `labels` attributes still follow
   rule 2, the way they do for an unclassed column that gets no class. Added
   2026-09-03 by issue #206, and added at the end so that rules 1-7 keep the
   numbers the other artifacts cite; the rebuild wrote the haven chain over
   the whole class vector, so a labelled factor came back as its level codes
   and a `Date` as its day count.

#### Why this argument exists

`haven` and `labelled` dispatch on the **class**, not on the `labels`
attribute. Measured, on a stripped column:

| Call | Labelled column | Stripped column |
|---|---|---|
| `haven::as_factor()` | `Low/Mid/High` | `1/2/3` |
| `labelled::to_factor()` | `Low/Mid/High` | `1/2/3` |
| `haven::write_sav()` then `read_sav()` | labels preserved | labels are `NULL` |

None of those raises. Without this argument, an analyst who exports a design
back to `.sav` loses every value label silently.

The default stays stripped because `survey_data()` output is what
`surveyreports` and `surveytidy` consume, and rebuilding unconditionally
would push the original arithmetic defect into those packages. Measured
scale: **15 of 25** everyday operations break on a labelled column when
`haven` is absent, including `weighted.mean()` and `ifelse()`.

`survey_data()` has **zero internal callers** in `R/`, so this argument
changes nothing inside the package.

#### Why the rebuild uses base R

Three reasons, and the third is the one that matters most:

1. It needs no `haven` at runtime, so the argument adds no error class and
   no dependency.
2. It honours `.claude/rules/surveycore-conventions.md` §haven handling,
   which already requires label attributes to be **read** with base R. Writing
   the class back with base R is the same rule in the other direction.
3. **`haven_class = TRUE` works even when `haven` is not installed.** A user
   on a machine without `haven` can still produce a properly classed column
   to hand to a colleague who has it, or to write out later. Calling
   `haven::labelled()` would have made the argument fail on exactly the
   machines where surveycore's premise — that `haven` is optional — matters
   most.

#### Verified

Strip then rebuild restores the class chain identically, base-type marker
included, for all six shapes tested: `haven_labelled` double,
`haven_labelled_spss` with `na_values`, `haven_labelled_spss` with
`na_range`, a column holding a tagged `NA`, and integer- and
character-backed columns. Values unchanged in every case. A tagged `NA`
survives byte for byte, and its tag still reads back after the rebuild.

The base-R rebuild is `identical()` to the output of `haven`'s own
constructors on all six shapes.

The `write_sav()` round trip returns the labels for every one of those
shapes except a column holding a tagged `NA`.

#### One thing this does not fix

`haven::write_sav()` raises on a column holding a tagged `NA`:
`Failed to insert value ...: The file format does not support ...`. This is a
`.sav` format limitation inside `haven` and has nothing to do with this work.
A/B measured: a column built straight from `haven::labelled()`, with no strip
involved at any point, fails identically, and a column holding a plain `NA`
works both ways.

Do **not** list this as a behaviour change and do not claim to fix it. Give
it one sentence in the `@param haven_class` text, so a user who hits it does
not blame the new argument.

#### Printed output

For a previously labelled column, the type token in a printed tibble changes
from `<hvn_lbl>` to the token for its underlying type — `<dbl>` for a
double-backed column, `<int>` for integer-backed, `<chr>` for
character-backed. That is the visible face of this change. State it in the
`@return` text of `survey_data()` and of the four constructors.

#### Required `@return` text for the four constructors

Each of `as_survey()`, `as_survey_replicate()`, `as_survey_twophase()` and
`as_survey_nonprob()` must carry this sentence, adapted to name its own
return class:

> A `survey_taylor` object. Columns imported with `haven`-style value
> labels are stored as their underlying type: the `label` and `labels`
> attributes are kept, and the value labels are also recorded in the
> metadata system, but the `haven_labelled` class is not stored. Use
> `survey_data(x, haven_class = TRUE)` to read the data back with that class
> rebuilt.

Two sentences, no `@` property references, per
`.claude/rules/code-style.md` §S7 patterns.

### VIII.2 What does not change

| Surface | Verdict | Evidence |
|---|---|---|
| every `is.numeric()`, `is.double()`, `is.integer()`, `is.atomic()`, `is.factor()`, `is.ordered()`, `is.logical()`, `is.character()` gate in `R/` | unchanged | measured on the labelled column and on the stripped column, with `haven` both absent and present; every answer identical in all four combinations |
| `extract_val_labels()`, `extract_var_label()`, `extract_metadata()`, `extract_missing_codes()`, `extract_higher_is()` on a survey object | unchanged | all read `@metadata`, never a column attribute (`R/core-metadata.R:514-515`, `:578-579`, `:973-983`, `:858`, `:3191`) |
| the same five on a data frame | unchanged | data frames are not stripped |
| `get_freqs()` level display text | unchanged | `R/analysis-freqs.R:365` and `:371` call `as.character()` on a level value; with `haven` present that returns the code, not the label, so the string is the same before and after |
| `classify_question_type()` | unchanged | reads `question_prefaces` and `sata` only (`R/core-metadata.R:3544-3564`); never touches a column value or class |
| `.apply_group_labels()` output | unchanged | reads labels from `@metadata` with the column attribute as fallback (`R/analysis-helpers.R:232-233`), always from the full column (`:230`) |
| every bundled dataset | unchanged | all six `data-raw/` scripts already strip the class, so the strip is a no-op on them |
| every roxygen `@examples` block | unchanged | none builds a labelled column; the polychoric example uses ordered factors (`R/analysis-corr.R:228-236`) |
| every vignette | unchanged | the haven mentions in `vignettes/surveycore-vs-survey.Rmd` all concern `ns_wave1`, a bundled dataset |

### VIII.3 What does change

| Surface | Change |
|---|---|
| `survey_data()` | gains the `haven_class` argument; the default return is unchanged from the line above |
| `survey_data()` and every direct `@data` read | previously labelled columns are plain base types |
| a printed tibble holding a previously labelled column | the type token becomes the token for the underlying type: `<dbl>` for double-backed, `<int>` for integer-backed, **`<chr>` for character-backed**. An earlier draft said `<dbl>` unconditionally, which is wrong for the last two. |
| `as_svydesign()`, `as_tbl_svy()` | the `$variables` frame they hand to `survey` and `srvyr` carries plain columns (`R/methods-conversion.R:110`, `:145`, `:187`, `:259`) |
| `from_svydesign()`, `from_tbl_svy()` | `@metadata` is now populated instead of empty; the stored columns are plain |
| construction with a labelled `weights`, `fpc`, or `ids` + `strata` | now succeeds; previously aborted with an untyped `vctrs` error |
| a labelled column stacking a caller's own class above `haven_labelled` | the whole class vector goes, so the foreign entry goes too. Accepted — §III.3a. |
| `set_val_labels()` on a labelled column | now succeeds in both input modes |
| `get_corr(method = "polychoric")` | accepts a whole-valued, finite double column with at most 10 distinct values |
| `get_corr(method = "polyserial")` | see §VI.6 — one pair shape gains, two lose |
| error message text that interpolates a column's class | reads `<numeric>` where it read `<haven_labelled>`, at `R/analysis-corr-latent.R:1682`, `R/analysis-diffs.R:268`, `R/core-validators.R:316` |

### VIII.4 Coverage that this closes

Twelve of seventeen public entry points failed on a labelled column with
`haven` absent, across 26 call forms.

Verified against a post-hoc strip applied after construction: 22 of the 26
then passed. The two that did not were `get_corr(method = "polychoric")`,
which §VI fixes, and a second design built by `as_survey_replicate()` from
the same raw labelled frame, which the post-hoc strip had never touched.
That second failure is the direct evidence for putting the strip inside the
construction path rather than at the call site.

Verified again against the Part 2 spike, with `haven` absent: `get_freqs()`,
`get_means()`, `get_quantiles()`, `get_variance()`, grouped `get_freqs()`,
`get_t_test()`, `get_diffs()`, `get_anova()`, `survey_glm()` and
`get_corr(method = "polychoric")` all pass. `set_val_labels()` moves from
fatal to working. Two routes remained broken — labelled `weights` and
labelled `fpc` — and Part 1 is what closes them.

---

## IX. Error and warning surface

### IX.1 No new class

The strip is **silent**. No `cli_inform()`, no `cli_warn()`, no new class in
`plans/error-messages.md`.

The case for silence:

- Every SPSS, Stata and SAS import would trigger it. That is the normal path
  into the package, so a message there is noise, not signal.
- **No information is lost inside surveycore's storage and metadata
  system.** `.extract_haven_metadata()` harvests the labels at the same
  moment (`R/core-metadata.R:3744-3752`), and the strip keeps every
  attribute on the column as well. This claim is bounded and the bound
  matters: see the paragraph below.
- The precedent is silent. All six `data-raw/` scripts do the same strip with
  no message.
- The constructors already emit up to four conditions on a normal call —
  `surveycore_warning_srs_no_weights`,
  `surveycore_inform_probs_weights_consistent`,
  `surveycore_warning_single_stratum` (`R/core-constructors.R:521-529`) and
  `surveycore_warning_psu_multi_strata` (`R/core-validators.R:353-361`). A
  fifth on every import devalues all of them.

**Where the "nothing is lost" claim stops.** It is true inside surveycore. It
is **not** true for functions in other packages that dispatch on the class.
`haven::as_factor()` and `labelled::to_factor()` return the codes instead of
the labels, and `haven::write_sav()` writes a file whose value labels are
`NULL`. None of the three raises. Every label is still on the column and
still in the metadata system, so nothing is destroyed — but a reader of an
unqualified "no information is lost" would draw the wrong conclusion about
what still works downstream. §VIII.1 owns that boundary, and
`survey_data(x, haven_class = TRUE)` is the route across it.

The case against silence: `survey_data()` returns something structurally
different from what the caller passed in, and `CLAUDE.md` records that this
package warns when it changes what the user handed it.

**Decision**: silent at runtime, explicit in the documentation. The
`@return` text of `as_survey()`, `as_survey_replicate()`,
`as_survey_twophase()`, `as_survey_nonprob()` and `survey_data()` must state
the storage contract from §VIII.1, and `NEWS.md` must carry an entry. This
satisfies the explicitness requirement at no runtime cost.

### IX.1a One new class, and none removed

`plans/error-messages.md` gains exactly one row and loses none. The new row
validates the `haven_class` flag from §VIII.1 rule 7:

| New class | Trigger |
|---|---|
| `surveycore_error_haven_class_not_logical` | `survey_data()` receives a `haven_class` value that is not a length-one logical |

The class names its own argument, which is what all five scalar-flag classes
already in the table do: `surveycore_error_subset_not_logical`,
`surveycore_error_na_rm_not_logical`, `surveycore_error_sata_not_logical`,
`surveycore_error_fill_not_logical` and
`surveycore_error_reverse_coded_not_logical`. D6 records the decision and the
two rejected alternatives.

Two further additions were proposed in earlier drafts and both were
withdrawn:

| Withdrawn class | Why it is not needed |
|---|---|
| a warning fired when the strip runs | Silent by decision, above. |
| an error for "`haven` is not installed" under `haven_class = TRUE` | The rebuild uses base R (§II), so the condition cannot arise. |

So the edits to `plans/error-messages.md` are the one new row above plus the
three Condition-column corrections in §VI.8.

### IX.2 Errors and warnings that stay reachable

| Class | Trigger, after this work |
|---|---|
| `surveycore_error_polychoric_requires_ordinal` | `method = "polychoric"` and a selected column is a factor-free, non-whole double, a high-cardinality whole double, or a character / logical column |
| `surveycore_error_polyserial_requires_mixed_types` | `method = "polyserial"` and both sides classify ordinal, or both classify continuous |
| `surveycore_error_polyserial_canonicalization_ambiguous` | `method = "polyserial"` and a side is a high-cardinality integer, a logical, or a character column |
| `surveycore_error_polychoric_single_level_ordinal` | an ordinal side has fewer than two positive-weight levels in the active domain |
| `surveycore_warning_missing_labels` | `set_val_labels()` and a code observed in the column has no label — now reachable on a previously labelled column, because the validation no longer aborts before it |
| every existing constructor error and warning | unchanged |

### IX.3 Errors that become unreachable

`vctrs_error_ptype2`, `vctrs_error_incompatible_op`, `vctrs_error_cast` and
`vctrs_error_subscript_oob` stop appearing for labelled input on every route
that assigns `@data`. Those are `vctrs` classes, not surveycore classes, so
nothing in `plans/error-messages.md` is removed.

---

## X. Verifiable behaviour the implementation must expose

This section names the behaviour that must be demonstrable, not the
scenarios that demonstrate it.

Every changed unit needs coverage in all three standard categories from
`.claude/rules/testing-standards.md` §Coverage: happy path, every typed
error class, and edge cases. Five properties of this work make demonstration
harder than usual, and the implementation must not stand in the way of any of
them.

1. **Part 1 and Part 2 must be separately demonstrable.** Each covers routes
   the other cannot reach, so a demonstration that exercises only one of
   them proves nothing about the other. The routes that isolate Part 1 are a
   labelled `weights` column and a labelled `fpc` column: both abort during
   validation with Part 2 alone in place. The routes that isolate Part 2 are
   a direct S7 construction call and a bare `@data` assignment: Part 1 never
   sees either.
2. **The hardcoded class chain must be pinned.** §II rebuilds the class with
   base R, which means the chain is written out in surveycore rather than
   taken from `haven`. That is the accepted trade-off, and its mitigation is
   a check that compares the rebuilt chain against the expected one, so an
   upstream change in `haven` fails loudly rather than producing a stale
   chain in silence.
3. **The inherited setter must be demonstrable per class.** The `data`
   property lives on the abstract parent and reaches the four concrete
   classes by inheritance. The GAP in §III.4 stays open until each of the
   four is shown to normalise, at construction and on assignment.
4. **The `haven`-unavailable branch must be reachable on demand.** That is
   the whole reason `.haven_available()` exists as a named binding rather
   than an inline `requireNamespace()` call. Keep it a plain top-level
   function in the package namespace. Do not inline it, do not make it a
   local, do not wrap it in another call. If it stops being a namespace
   binding, the branch stops being reachable and item 5 of §I is not
   delivered.
5. **The stored state must be inspectable through the public API.** The
   guarantee this work adds is a property of what `@data` holds, and
   `survey_data()` is how anything outside the package sees that. It must
   keep returning the stored frame unchanged, per §VIII.1. Do not add
   copying, coercion or filtering to it.

---

## XI. Quality gates

Objectively verifiable. All must hold.

1. `devtools::document()` runs clean and `man/` is committed in sync with
   the roxygen source.
2. `devtools::test()` — 0 failures, 0 errors, and **no warning attributable
   to this feature**. Measured 2026-09-01: 256 warnings, unchanged from the
   baseline's 256. They are the AAPOR small-cell and `survey_nonprob`
   SRS-approximation notices, both raised by design; issue #167 tracks them.
   **The 0-warning form has never held**, on this tree or on the feature
   base — reworded 2026-09-01 rather than left recorded as met.
3. `devtools::run_examples()` — clean.
4. `R CMD check --as-cran` — 0 errors, 0 warnings, at most the two
   pre-approved notes from `.claude/rules/r-package-conventions.md`.
5. `pkgdown::build_site()` — clean.
6. `covr::package_coverage()` with `NOT_CRAN=true` — at or above 96.09%,
   the figure on `develop` at `cf6f153`. The floor is 95%.
7. `air format --check .` produces no diff **attributable to this feature** —
   no file this feature creates or rewrites appears in the flagged list.
   Measured 2026-09-01: 35 files flagged package-wide, **0 attributable**,
   confirmed by two independent methods (hunk-range intersection, and
   `git blame` on the flagged ranges, which traced the three intersecting
   files to #164, #110 and #185). The package-wide form has never held, on
   this tree or on the feature base `0be2f3a`; closing it means reformatting
   all 35, none of whose flagged lines come from this feature, which
   `.claude/rules/code-style.md` requires be its own commit. Reworded
   2026-09-01.
8. No column of `@data` inherits `haven_labelled` after any route in
   §III.1, demonstrated for all four concrete design classes, and after a
   bare `des@data <- labelled_df` assignment.
9. A design constructs, and estimates correctly, from a frame whose
   **weight** column carries the labelled class, and from a frame whose
   **fpc** column carries it. These are the two routes Part 2 alone leaves
   broken, so they are the gate on Part 1.
10. `@metadata@value_labels` is populated on every route that builds a
    design from a frame carrying a `labels` attribute, including
    `from_svydesign()`.
11. `survey_data(x, haven_class = TRUE)` returns columns whose class chain is
    exactly the chain the import produced, including the SPSS variant where
    the SPSS missing attributes are present, and it does so with `haven` not
    installed.
12. `get_corr(method = "polychoric")` **raises** on a column containing `Inf`
    or `-Inf`. This is the gate on §VI.3's `is.finite()` guard. Without it the
    call returns a fabricated correlation.
13. `plans/error-messages.md` rows PC-1, PC-2 and PC-3 describe the
    conditions the code now raises on. Exactly one row is added —
    `surveycore_error_haven_class_not_logical`, per D6 — and no row is
    removed.
14. No comment in `R/analysis-corr-latent.R` contradicts the code it
    documents.
15. `NEWS.md` carries five entries: the storage contract change, the new
    `haven_class` argument, the polychoric acceptance of whole-valued
    doubles, the polyserial breaking change from §VI.6, and the loss of a
    caller's own class stacked above `haven_labelled` from §III.3a.
16. `DESCRIPTION` is unchanged. `NAMESPACE` is unchanged — `survey_data()` is
    already exported and gains an argument, not an export.
17. The implementation notes record the timing ratio required by §III.6.
    That is a recorded measurement, not a pass-or-fail gate; §III.6 states
    the reasoning and the risk accepted.
18. The implementation notes record the S7 version the setter behaviour in
    §III.4 was confirmed against.

---

## XII. Integration contracts

### XII.1 `surveytidy`

`surveytidy` assigns `@data` from its dplyr verb methods. The property
setter means every such assignment is normalised, so `surveytidy` needs no
change and gains the guarantee for free. Two consequences to record in the
`NEWS.md` entry, because `surveytidy` may rely on either:

- A column that `surveytidy::mutate()` writes with the labelled class is
  stored without it. Value labels on that column are **not** harvested into
  `@metadata`, because the harvest runs in the constructors only. The
  attribute stays on the column, and the existing fallback in the analysis
  layer reads it.
- `surveycore` continues to expose `.get_design_vars_flat()`
  (`R/utils.R:251`), `.get_design_vars()` (`R/utils.R:294`),
  `SURVEYCORE_DOMAIN_COL` (`R/utils.R:123-124`) and
  `.delete_metadata_col()` (`R/core-validators.R:503`) unchanged.

### XII.2 `survey` and `srvyr`

`as_svydesign()` and `as_tbl_svy()` hand `@data` straight to the other
package (`R/methods-conversion.R:110`, `:145`, `:187`, `:259`). Those
packages receive plain columns instead of labelled ones. Neither reads label
attributes, so neither is affected.

**Boundary decision.** Neither function gains a `haven_class` argument. Both
convert to another package's object, and their documented contract is to
produce a `survey` or `srvyr` design; a labelled-class flag on them is a
separate concern with a separate audience. Record the boundary in the
`@return` text of both, and name the supported route:

> Value labels are not carried into the returned object — the `survey`
> package has no metadata system. To read the data back with `haven`-style
> classes rebuilt, use `survey_data(x, haven_class = TRUE)` on the surveycore
> design instead.

The first sentence of that text already exists at
`R/methods-conversion.R:38-39` and `:202`. Only the second is new.

### XII.3 `haven`

Stays in `Suggests`. It is required at runtime for exactly one purpose —
resolving a tagged `NA` to its label inside `.apply_group_labels()` — and
that path degrades gracefully when it is absent, as it does today.

`survey_data(haven_class = TRUE)` does **not** add a second runtime purpose.
It rebuilds the class with base R (§II), so it works with `haven` absent.

### XII.4 `labelled`

Affected in the same way as `haven`, and by the same mechanism: it dispatches
on the class. Measured — `labelled::to_factor()` returns the codes rather
than the labels on a stripped column. `survey_data(haven_class = TRUE)` is
the route back, and its output satisfies `labelled::to_factor()` correctly.

`labelled` re-exports `haven`'s constructors rather than defining its own
class, so nothing else about it needs separate handling.

### XII.5 `sjlabelled` — unaffected, and this bounds the blast radius

`sjlabelled` reads the **attribute**, not the class. Measured, with
`sjlabelled` installed to a scratch library: a stripped column is
`identical()` to what `sjlabelled` produces natively.
`sjlabelled::set_labels()` on a numeric vector returns class `numeric`
carrying `labels` and `label`, which is exactly what the strip leaves, down
to the type of the labels vector. All four readers tested —
`as_label()`, `get_labels()`, `get_label()` and `to_numeric()` — return the
same answer on the haven-class shape, the stripped shape and the
sjlabelled-native shape.

This is worth stating because it bounds the exposure. Two conventions exist
for value labels in R: read the class (`haven`, `labelled`) or read the
attribute (`sjlabelled`). The strip moves a column from the first convention
to the second. It does not move it outside both, and it does not invent a
third. So the set of affected packages is the set that dispatches on the
class, and §XII.3 and §XII.4 enumerate it.

**Correction, 2026-09-02 (issue #207).** The paragraph above is about the
strip, and it stays true of the strip. It does not describe
`survey_data(haven_class = TRUE)`. That argument tests the `labels`
attribute, not provenance, so it moves an sjlabelled-native column from the
second convention to the first. Issue #207 kept that behaviour and rewrote
the `@param` text to match. Two reasons: the attribute is the only thing
`.restore_haven_class()` can see, and a provenance record would need new
state on every write to the `data` property. The move is opt-in — a caller
gets it only by passing `haven_class = TRUE` — and it drops no data, so it
is outside the blast radius this section bounds.

### XII.6 `surveyreports`

The downstream consumer this work unblocks. Its requirement is that a design
built from `haven::read_sav()` output supports every `get_*()` function and
`get_corr(method = "polychoric")` on coded scale columns. Items 1 and 4 of
§I together satisfy it.

`surveyreports` consumes `survey_data()` output, so it must keep calling it
with the default. Nothing in this spec requires a change on its side.
