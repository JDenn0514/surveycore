# Spec — as-svydesign-domain

**Status**: SPEC_READY — three review passes; 18 findings resolved (2026-09-09)
**Target version**: 1.1.0.9000
**PR range**: PR 1

## Document purpose

This document is the source of truth for the behaviour of `as_svydesign()` on a
filtered design. It defines what the converted object represents, which rows it
carries, which conditions it raises, and what the function's documentation
states. Issue #245 reports the defect. Decisions D1 to D11 in
`decisions.md` are settled and this spec implements them.

All seventeen Pass 1 spec-review findings are resolved in this revision. Five
of them changed a measured fact rather than only wording: the two-phase route
does not remove rows (D8), the row mask needs `as.logical()` (D9), an empty
domain does not give a zero estimate on every route (F9), `[.twophase` can warn
about single-PSU strata (F11), and the helper takes one argument (D11).

---

## Scope

### In

| Item | Delivery |
|---|---|
| Domain restriction on the Taylor route | The converted object carries only the rows the domain marks |
| Domain restriction on the replicate route | Same |
| Domain restriction on the two-phase route | The domain applies by zero-weighting, and the row count does not change. `[.twophase` sets each excluded row's probability to `Inf` and keeps every row, so the observable is the estimate and the count of finite probabilities, not the shape. Measured: 12 of 29 phase-2 rows marked gives 29 rows, 17 of them with an infinite probability, and the correct domain estimate 58.06658. `subset()` behaves identically, so this is a property of the two-phase design and not of the operator D1 chose (D8, F8) |
| Domain restriction on both `survey_nonprob` shapes | The converted object carries only the rows the domain marks, through the two routes the shape selects |
| One shared restriction helper | One internal function of one argument, three call sites, five routes |
| `as_tbl_svy()` inherits the restriction | No change to that function's body |
| `from_svydesign()` round trip keeps the design variables | Guaranteed by the choice of restriction operator |
| Documentation of the new behaviour | The `@section A filtered design's domain:` block is rewritten |

### Out

- No new exported function, no new S7 class, no new property.
- No new error class and no new warning class. `plans/error-messages.md` gains
  no row and loses none.
- No change to `from_svydesign()`, `from_tbl_svy()` or any `get_*()` function.
- No recovery of a domain in the reverse direction. A `survey` object records a
  subset and not a domain marker, so `from_svydesign()` on a restricted object
  returns a design over the restricted rows and marks nothing. Issue #245
  states this and this spec does not change it.
- No change to the two-phase weighting gap. surveycore's two-phase estimator
  weights by the phase-1 weight column, and `survey`'s two-phase object weights
  by the combined two-phase probability. The two answers differ by 58.458
  against 58.067 on the measured design, and the identical gap sits on the
  unfiltered design, 48.9 against 49.203. Issue #261 carries it. Nothing in
  this write surface closes it (D3).
- No consolidation of the eight in-place copies of the `survey_nonprob` routing
  predicate. Issue #246 carries that. This change adds no ninth copy: it reads
  no `repweights` key and adds no branch on the weight shape.
- No `vignette("surveycore-vs-survey")` edit. Section 5.1 of that vignette
  states only the degrees-of-freedom difference, and its function reference
  table row for `Domain filter` makes no claim about conversion. The vignette
  repeats no part of the limitation this change removes, so it stays out of the
  write surface.

---

## Architecture

### Files touched

| File | State | What changes |
|---|---|---|
| `R/methods-conversion.R` | modified | One new internal helper; three call sites; the `@section A filtered design's domain:` block rewritten |
| `tests/testthat/test-conversion.R` | modified | New test blocks |
| `man/as_svydesign.Rd` | regenerated | Output of `devtools::document()`; never hand-edited |
| `changelog/fix-as-svydesign-domain.md` | created | Release-note entry, in the flat format the directory uses. The entry must lead with the change to what the function returns — a filtered design now converts to the domain and not to the full sample. The conversion itself stays silent on every domain (D7), so this entry is the only place a user meets the change, and they meet it at upgrade time |

`NEWS.md` is not in the write surface. `/merge-main` drafts its release section
from the `changelog/` entries added since the last release tag, so a per-PR
edit of `NEWS.md` would be overwritten at release. This corrects
`impact.md`, which names `NEWS.md`. The file count stays at four.

No file outside this table changes.

### Functions added

```r
.restrict_to_domain <- function(converted)
```

Internal, not exported, `.`-prefixed, defined in `R/methods-conversion.R` under
the existing `# ── Internal helpers ──` heading. It has three call sites, all in
that one file, so it stays there per `code-style.md` §Internal helper
placement.

One argument, not two (D11). The helper derives the marker frame from
`converted` itself, branching internally on the two-phase class. The correct
frame is a deterministic function of the converted object's class in all three
cases, and `from_svydesign()` already proves the data is recoverable from the
object — it reads `x$variables` at `R/methods-conversion.R:638` and `:736` to
rebuild `@data`. A second argument would ask each call site to supply what the
object already carries, and D2 records the one time that went wrong: an
unclassed `logical subscript too long (60, should be 29)`. D8 settles that the
two-phase route needs class-specific handling regardless, so the branch has to
exist somewhere. Putting it inside the helper removes the argument that can be
passed wrongly instead of documenting how to pass it rightly.

### Functions modified

```r
.as_svydesign_taylor(x)      # unchanged signature; restricts before returning
.as_svydesign_replicate(x)   # unchanged signature; restricts before returning
.as_svydesign_twophase(x)    # unchanged signature; restricts before returning
```

`as_svydesign(x)` and `as_tbl_svy(x)` keep their signatures and their bodies.
The behaviour change reaches both through the three helpers.

### Class changes

None.

---

## Function contracts

### `.restrict_to_domain(converted)`

- **Signature**: `.restrict_to_domain(converted)`
- **Arguments**

  | Name | Type | Default | Semantics |
  |---|---|---|---|
  | `converted` | a `survey` package design object | none | The object a route has just built. Any class that `survey` gives a `[` method: `survey.design2`, `svyrep.design`, `twophase2`. The helper derives the marker frame from this object's class: for a two-phase object, `converted$phase1$sample$variables`; for every other class, `converted$variables` (D11). |

  The argument has no `NULL` behaviour. A caller with no converted object does
  not call the helper.

- **Returns**: a design object of the same class as `converted`.
  - When the derived frame has no column named by `SURVEYCORE_DOMAIN_COL`, the
    return value is `converted` itself, unchanged and un-indexed.
  - Otherwise the return value is `converted` indexed by the row mask below.
  - The returned object's stored call is identical to the input's, because the
    `[` operator never rewrites it. This is the guarantee D1 measured the loss
    of, and it is a term of this helper's own contract, not only the rationale
    for choosing `[`.
- **Row mask**: read `r <- as.logical(frame[[SURVEYCORE_DOMAIN_COL]])`, then
  index by `r & !is.na(r)` (D9, which supersedes D6's expression and keeps its
  meaning).
  - `as.logical()` does the coercion, and `&` alone does not. Nothing in the
    package guarantees the marker column is logical, no validator checks its
    type, and code in this repository already writes an integer one. Measured
    on the 200-row Taylor design of `findings-edge-cases.md` §F10, with 107
    rows marked, `&` alone gives:

    | Marker column type | Rows after the mask | Condition raised |
    |---|--:|---|
    | logical | 107 | none |
    | integer `0`/`1` | 107 | none |
    | double `0`/`1` | 107 | none |
    | character `"TRUE"`/`"FALSE"` | — | error: `operations are possible only for numeric, logical or complex types` |
    | factor | 200 | warning: `'&' not meaningful for factors` |

    The character column raises an unclassed base error out of
    `as_svydesign()`. The factor column is worse: `&` returns an all-`NA` mask,
    indexing with it yields a 200-row object whose probability vector is
    neither finite nor infinite, and estimating on that object dies three
    frames down inside `survey` with `invalid 'type' (list) of argument`.
  - With `as.logical()` first, all five types are correct. A character
    `"TRUE"`/`"FALSE"` column converts. A factor with levels `FALSE`/`TRUE`
    converts. A factor with unrelated levels such as `yes`/`no` becomes all
    `NA`, and therefore an empty domain, which is safe and inspectable rather
    than corrupt.
  - `!is.na(r)` resolves `NA` to "outside the domain" (D6), and also absorbs
    the `NA` that `as.logical()` returns for an unconvertible value.
- **Restriction operator**: the `[` operator, and never `subset()` (D1).
  `survey`'s three `subset()` methods all end with `x$call <- sys.call(-1)`,
  which overwrites the stored call. `.as_svydesign_taylor()` builds that call
  with `bquote()` so the formulas are inlined, and `from_svydesign()` reads
  `ids`, `strata`, `weights`, `fpc` and `nest` back out of it, each read wrapped
  in a `tryCatch` that returns `NULL` on failure. A round trip through
  `subset()` therefore loses `ids` and `strata` with no error raised. `[`
  preserves the stored call on every route.
- **Errors**: none. The helper raises no condition of its own. `as.logical()`
  is what makes this true: with `&` alone it was false for a character marker
  column, which raised an unclassed base error (D9).
- **Warnings**: none of its own. `[` on a two-phase object can raise an untyped
  warning from `survey`; see `as_svydesign(x)` → Warnings below.
- **Edge cases**

  The row counts below are those of the Taylor, replicate and non-probability
  routes. On the two-phase route the row count never changes; the excluded rows
  get an infinite probability instead (D8, F8). So on that route read "zero
  rows" as "no finite probability" and "one row" as "one finite probability".

  | Case | Behaviour |
  |---|---|
  | Column absent | Return `converted` unchanged. This is the unfiltered design, which carries no marker column at all — there is no all-`TRUE` column to detect, so "apply it when the column is present" is the whole guard. |
  | Every value `TRUE` | Index anyway. The row count does not change and the stored call survives. |
  | Every value `FALSE` | Index anyway. Raise nothing (D5). Taylor, replicate and non-probability routes return a zero-row object. The two-phase route returns an object of unchanged row count with no finite probability. |
  | Exactly one value `TRUE` | Index anyway. Raise nothing. Whatever `survey` raises when a caller later estimates on it belongs to `survey`. |
  | Any value `NA` | That row falls outside the domain. |
  | Every value `NA` | Equivalent to every value `FALSE`. |
  | Marker column is not logical | `as.logical()` converts integer, double, character and a `FALSE`/`TRUE` factor. A factor with unrelated levels converts to all `NA`, which the mask reads as an empty domain. |
  | Zero-row derived frame | Not reachable. Every surveycore constructor requires at least one row, and each conversion route builds `converted` from a constructed design. |

- **Relationship to the two existing readers of the marker column** (D10). The
  helper is the third reader, and it does not reuse either of the first two.
  `.apply_domain()` at `R/analysis-helpers.R:482-488` returns the column raw,
  with no `NA` resolution and no type coercion. `.print_domain_info()` at
  `R/methods-print.R:170-185` treats `NA` as outside the domain, through
  `na.rm = TRUE`. Neither is reused because this helper reads a bare frame off
  a `survey`-package object rather than off an S7 design, so it cannot call
  `.apply_domain(design)` as that function is typed. Consolidating all three
  would reach `R/analysis-helpers.R` and `R/methods-print.R`, both outside this
  write surface, and would change behaviour the analysis suite pins today. The
  divergence has an owner: **issue #262** records that `.apply_domain()`'s raw
  pass-through is a live defect — eleven call sites index a data frame with the
  raw mask, so five grouped `get_*()` functions report the wrong group on an
  integer column — and its suggested fix is the same `as.logical()` expression
  D9 adopts here.

### `as_svydesign(x)`

- **Signature**: unchanged — `as_svydesign(x)`.
- **Arguments**: unchanged. `x` is a `survey_taylor`, `survey_replicate`,
  `survey_twophase` or `survey_nonprob` object.
- **Returns**: a `survey::svydesign`, `survey::svrepdesign` or
  `survey::twophase` object, as today, restricted to the active domain.
  - The returned object represents the active domain and not the full stored
    sample. `survey::svymean()` on it answers the domain estimate.
  - On the Taylor, replicate and non-probability routes the returned object
    carries one row per marked row. On the two-phase route the row count is
    unchanged and each excluded row carries an infinite probability, which
    weights it out of every estimate (D8, F8).
  - The domain marker column stays in the returned object's data (D4). No route
    drops it. Nothing renames it. On the four routes that remove rows, every
    value left in the column is `TRUE`. On the two-phase route, which removes
    no row (D8), the column arrives unchanged and still marks the zero-weighted
    rows `FALSE`.
  - Every other column of `@data` reaches the returned object as before, over
    the restricted rows.
  - The stored call is the call the route built. Restriction does not rewrite
    it.
- **Errors**: unchanged. `surveycore_error_not_survey_object`,
  `surveycore_error_repweights_empty` and
  `surveycore_error_fay_rho_unrecoverable` all keep their triggers and their
  messages. Each fires before any object exists to restrict, so restriction
  cannot reach them and adds no error class.
- **Warnings**: unchanged, in both text and firing order.

  | Class | Trigger | Order against the restriction |
  |---|---|---|
  | `surveycore_warning_nonprob_srs_conversion` | A `survey_nonprob` design that names no replicate weights | Fires in `as_svydesign()` itself, before dispatch, so before the restriction. The restriction does not change whether it fires, how many times, or what it says. |
  | `surveycore_warning_replicate_fpc_dropped` | A design that records an FPC column, on the replicate route | Fires inside the replicate route before the object is built, so before the restriction. Unchanged in every respect. |

  The restriction adds no surveycore condition on any route and for any
  domain, ordinary or empty (D5, D7). It stays silent even when it returns
  fewer rows than the design it was called on. D7 argues that case on its own
  terms: the conversion is now doing the correct thing, a warning on correct
  behaviour teaches users to ignore the warning, and what a user needs is to
  learn once at upgrade time that the output changed. The
  `changelog/fix-as-svydesign-domain.md` entry carries that, and the
  documentation contract below carries the rest — D7 makes those three
  documentation sentences a condition of the decision and not an optional
  extra.

  Silence is not the same as raising nothing. On the two-phase route, `[` can
  raise a **pre-existing untyped condition from `survey`**:

  | Source | Trigger | Class |
  |---|---|---|
  | `[.twophase`, inside `survey` | A domain that thins a stratum to one PSU. The branch computes `index <- is.finite(x$prob)`, counts PSUs per stratum over that index, and calls `warning(sum(tt == 1), " strata have only one PSU in this subset.")` | untyped `simpleWarning`; no class of any kind |

  The measured design does not trigger it, and a narrower domain on a
  stratified two-phase design would (F11). It is `survey`'s condition. This
  change neither adds it, nor suppresses it, nor gives it a class, and the
  two-phase conversion already emits one other untyped `survey` condition
  today.

  So the claim scopes per route: the restriction raises no condition at all on
  the Taylor, replicate and non-probability routes, and on the two-phase route
  it raises no condition of surveycore's while `survey`'s own untyped warning
  may pass through.

#### Route matrix

Three call sites cover five shapes, because the `survey_nonprob` branches
dispatch into the Taylor and the replicate routes.

The helper takes one argument and derives the frame itself (D11), so this
matrix records which frame the helper derives per converted class, not which
frame a caller passes.

| Input shape | Route | Class of `converted` | Frame the helper derives | How the domain applies | Note |
|---|---|---|---|---|---|
| `survey_taylor` | Taylor | `survey.design2` | `converted$variables` | Rows removed | |
| `survey_replicate` | replicate | `svyrep.design` | `converted$variables` | Rows removed | |
| `survey_twophase` | two-phase | `twophase2` | `converted$phase1$sample$variables` | Row count unchanged; excluded rows get an infinite probability | D2, D8 |
| `survey_nonprob`, names replicate weights | replicate | `svyrep.design` | `converted$variables` | Rows removed | Reaches the replicate call site with no branch of its own |
| `survey_nonprob`, names none | Taylor | `survey.design2` | `converted$variables` | Rows removed | Reaches the Taylor call site after the SRS warning |

The two-phase route is the one exception on both counts, and both are forced.

**Which frame.** `@data` holds one row per phase-1 row — 60 on the measured
design — while the converted object's phase-1 sample holds only the phase-2
rows, 29. Indexing with the `@data`-side vector raises a bare
`logical subscript too long (60, should be 29)` with no class. The marker
column does reach `phase1$sample$variables`, so nothing extra has to be carried
across (D2).

That the marker column reaches the phase-1 sample variables is **structural,
not incidental**. The phase-1 sample variables are always a row-subset of the
same `data` argument the constructor received, verified across
`method = "full"`, `"simple"` and `"approx"`, so any column in `@data` survives
regardless of method. No defensive check for the column's arrival is needed on
that route beyond the presence check every route already makes.

**How the domain applies.** `[.twophase` keeps every row and sets each excluded
row's probability to `Inf`. Measured with 12 of 29 phase-2 rows marked: 29
rows, 17 with an infinite probability, `svymean()` answers 58.06658, which is
the correct domain estimate. `subset()` gives the same 29 rows, so this belongs
to the two-phase design and not to the operator (D8, F8).

Each route calls the helper once, on the object it has just built, immediately
before returning it. No route restricts the input design: `x` is untouched, and
a second call converts the same way.

### `as_tbl_svy(x)`

- **Signature**: unchanged — `as_tbl_svy(x)`.
- **Body**: unchanged. It calls `as_svydesign()` and wraps the result, so it
  inherits the restriction with no edit.
- **Returns**: a `srvyr::tbl_svy` over the domain rows.
- **Errors and warnings**: unchanged. It propagates whatever `as_svydesign()`
  raises, including `surveycore_warning_nonprob_srs_conversion`.

### `from_svydesign(x)` — behaviour on a restricted object

Not modified. Its contract is recorded here because the round trip is an
acceptance criterion of this change.

`from_svydesign()` dispatches on the two-phase class at
`R/methods-conversion.R:614`, so all five shapes make the round trip. The
behaviour splits in two, along the same line D8 draws: the four routes that
remove rows behave one way and the two-phase route, which removes none, behaves
another.

**On the four routes that remove rows.**

- It returns a design over the restricted rows. The rebuilt design's
  `@variables` names `ids`, `strata` and `weights` as it does on an
  unrestricted object, because the restriction preserves the stored call the
  reader parses.
- The all-`TRUE` marker column travels back into the rebuilt design's `@data`,
  where the domain reader sees it as all-`TRUE`. The rebuilt design's print
  output therefore carries a `Domain: n of n rows` line. This is the existing
  behaviour of a marked design whose marker selects everything, and no route
  suppresses it (D4).
- The rebuilt design's row count is its new total. The original N is
  unrecoverable from the object, so the `Domain: n of n rows` line looks
  identical to the line a design that was never filtered would print.
  `survey_data()`'s documentation at `R/utils.R:171` promises that printing a
  filtered design shows both counts; after a round trip the two counts are the
  same number twice. The documentation contract below states this.
- The reverse direction recovers no domain. It cannot: a `survey` object records
  a subset, not a marker.

**On the two-phase route.** The round trip recovers the domain, because the
restriction removed nothing for it to lose (F13). The rebuilt design is a marked
design over the full frame and not an unmarked design over the domain:

| Stage | Rows | Marker column |
|---|--:|---|
| after the restriction | 29 in the phase-1 sample | 12 `TRUE`, 17 `FALSE` |
| after `from_svydesign()` | 60 | 28 `TRUE` of 60 |

The rebuilt design prints `Domain: 12 of 29 Phase 2 rows`, naming two different
numbers. The original N is recoverable, the row count is not the new total, and
the marker is intact at both levels. The phase-1 count is the original
unrestricted marker, because the rebuild reads the phase-1 full frame, which the
restriction never touched.

---

## Documentation contract

`R/methods-conversion.R` currently documents the defect as intended behaviour.
The `@section A filtered design's domain:` block tells the caller to subset the
returned object by hand and states that the converted object answers for every
row. Both claims become false.

The rewrite replaces that one `@section` block and adds one sentence to
`@return`. Nothing else in the roxygen changes. Issue #251 has a claim on
nearby documentation text; every edit stays inside those two places, so the two
do not collide.

### The `@return` sentence

`@return` at `R/methods-conversion.R:43-50` says nothing about row count today.
The change fires on every filtered conversion, and a reader who stops at
`@return` would meet the fact only in the fourth `@section`, after two narrower
topics. So `@return` gains one sentence: a filtered input returns an object
restricted to the active domain, and it points at the
`A filtered design's domain` section for what that means per route.

### The `@section` block

The new block states, in this order:

1. The converted object represents the active domain and not the full stored
   sample.
2. How a domain arrives: `filter()` from surveytidy keeps every row and marks
   membership in a logical column named by `SURVEYCORE_DOMAIN_COL`, which holds
   `"..surveycore_domain.."`.
3. When the restriction applies: whenever that column is present. A design that
   was never filtered carries no such column and converts with no restriction.
4. That the marker column stays in the converted object's data, and that it is
   an internal marker rather than survey data. On the routes that remove rows,
   every value left in it is `TRUE`. On the two-phase route, which removes no
   row, the column is unchanged and still marks the zero-weighted rows `FALSE`.
5. That a row whose marker is `NA` counts as outside the domain.
6. That a filter matching no row still converts and that the conversion raises
   no surveycore condition. What `survey` then reports is **scoped per route**
   (F9). The blanket claim "an estimate of 0 with a standard error of 0" is
   true only on the Taylor route. Measured, with an all-`FALSE` marker:

   | Route | Rows after the restriction | What `survey::svymean()` then reports |
   |---|--:|---|
   | Taylor | 0 | 0, with a standard error of 0 |
   | non-probability, no replicate weights | 0 | 0, with a standard error of 0 — it routes into the Taylor helper |
   | replicate | 0 | an error from `survey`: `All replicates contained NAs` |
   | non-probability, replicate weights | 0 | as the replicate route — it routes into the replicate helper |
   | two-phase | unchanged, no finite probability | `NaN` |

   The documentation states the conversion is silent on every route, then names
   the three outcomes: a zero estimate with a zero standard error on the Taylor
   route and on the non-probability shape that names no replicate weights; an
   error from `survey` at estimation time on the replicate route and on the
   non-probability shape that names replicate weights; `NaN` on the two-phase
   route.

   Every row of that table is measured. `findings-edge-cases.md` §F9 measured
   the Taylor, replicate and two-phase routes, and §F12 measured the two
   non-probability shapes, which confirmed the routing inference: the shape
   naming replicate weights converts to a `svyrep.design` and errors, and the
   shape naming none converts to a `survey.design2` and answers 0 with a
   standard error of 0.
7. That the two-phase route applies the domain by weighting the excluded rows
   out rather than by removing them, so the converted object's row count does
   not change while its estimates answer for the domain. And that its point
   estimate still differs from `get_means()` on the filtered design for a
   reason independent of the domain: surveycore's two-phase estimator weights
   by the phase-1 weight column and `survey`'s two-phase object weights by the
   combined two-phase probability. The same difference sits on an unfiltered
   two-phase design. State the difference; do not cite an issue number in
   user-facing documentation.
8. What a round trip through `from_svydesign()` does and does not recover, on
   the four routes that remove rows. The rebuilt design's row count is its new
   total. The original N is unrecoverable from the object, because a `survey`
   object records a subset and not a marker. The all-`TRUE` marker column
   travels back, so the rebuilt design prints `Domain: n of n rows`, which looks
   identical to a design that was never filtered. `survey_data()`'s own
   documentation at `R/utils.R:171` promises that printing a filtered design
   shows both counts; after a round trip the two counts are the same number
   twice. A caller who needs the original N keeps the original design.
   State separately that the two-phase route is the exception: it removes no
   row, so its round trip recovers the marker at both levels and the rebuilt
   design prints two different counts.
9. That `as_tbl_svy()` hands a pre-restricted `tbl_svy` to `srvyr`, and that
   `srvyr`'s own `filter()` removes rows where surveycore's `filter()` marks a
   domain. The two verbs share a name and differ in semantics, so a caller
   chaining surveycore's `filter()` into `srvyr::filter()` is filtering an
   object that is already restricted.

Item 9 stays inside `as_svydesign()`'s own `@section`. `as_tbl_svy()` carries a
separate roxygen block and a separate `man/as_tbl_svy.Rd`, and editing it would
add a fifth file to the write surface. So the `srvyr::filter()` note is written
where the restriction is documented, and it names `as_tbl_svy()` from there.

The block names no internal helper and shows no `@` property access, per
`code-style.md`.

`devtools::document()` regenerates `man/as_svydesign.Rd` from it.

---

## Quality gates

- The converted object of a filtered design carries one row per marked row, on
  the Taylor, replicate and both non-probability shapes. On the two-phase shape
  the row count is unchanged and the count of finite probabilities equals the
  marked count (D8).
- `survey::svymean()` on the converted object of a filtered design answers the
  domain estimate, on every one of the five shapes.
- The converted object of an unfiltered design is what it is today: the same
  row count, the same columns, the same stored call, and no indexing step
  applied.
- The stored call of a converted Taylor design is the same expression before and
  after the restriction.
- `from_svydesign(as_svydesign(d))` on a filtered Taylor design returns a design
  whose `@variables` names `ids`, `strata` and `weights`.
- `as_svydesign()` on a filtered Taylor, replicate or non-probability design
  raises no condition that it does not raise on the same design unfiltered. On
  a filtered two-phase design it raises no **surveycore** condition that the
  unfiltered design does not raise; `survey`'s own untyped single-PSU warning
  may pass through (F11).
- The marker column is a name of the converted object's data on every route,
  after the restriction. On the four routes that remove rows, every value in it
  is `TRUE`. On the two-phase route, which removes no row, the column is
  unchanged and still holds `FALSE` for the zero-weighted rows.
- The marker column's type does not change the outcome: a logical, integer,
  double, character or `FALSE`/`TRUE` factor column all select the same rows,
  and none of them raises a condition (D9).
- The input design is unchanged by the call.
- One restriction helper exists, it takes one argument, and each of the three
  routes calls it once. No route contains its own copy of the mask expression,
  of the column-presence check, or of the frame-selection branch.
- `plans/error-messages.md` is byte-identical to its state on `develop`.
- `devtools::document()`, `devtools::check()` and the coverage floor in
  `.claude/rules/testing-standards.md` all hold. The check budget is the one in
  `.claude/rules/r-package-conventions.md`: 0 errors, 0 warnings, and the
  pre-approved notes only.

---

## Pipeline tier

**recommended.**

The change fails the `optional` bar on two of its four criteria, not one:

| `optional` criterion | This change |
|---|---|
| No new exported function | Passes. The helper is internal, `.`-prefixed, and `NAMESPACE` gains no entry. |
| No new error class | Passes. `plans/error-messages.md` gains no row. |
| No contract change and no numerical method change | **Fails.** The same call on the same input returns a different object, and it changes which rows that object estimates over, so a caller's point estimate moves. One mechanism trips both halves. |
| At most three files touched | **Fails.** Four files. |

Either failure alone would give `recommended`.
