# Spec — replicate-supplied-args

**Status**: DRAFT
**Date**: 2026-10-01
**Revision**: 2 (2026-10-06, spec review Pass 1 resolved)
**Target version**: 1.1.0.9000
**PR range**: PR 1–3 (the implementation plan fixes the split)
**Issues**: #255, and the JKn half of #244 (closed into #255)
**Locked decisions**: D1, D4, D7, D8 and D10 in `plans/issue-cleanup.md`. This
spec applies them and does not re-decide them. Section XI records the seven
choices this spec makes where those decisions are silent.

## Document purpose

This document is the behavioural contract for the work. It states what
`as_survey_replicate()` and `as_svydesign()` do with a supplied `scale`,
`rscales` and `rho`, which conditions they raise, and which files change. It is
the only input the builder reads. Every closed value the builder needs is
written out here.

---

## I. Scope

### In

| # | Deliverable |
|---|---|
| S1 | `as_survey_replicate()` discards a supplied `scale` for `"BRR"`, `"JK2"`, `"ACS"` and `"successive-difference"`, stores the type's own value, and warns. |
| S2 | `as_survey_replicate()` discards a supplied `rscales` for `"JK2"`, `"ACS"` and `"successive-difference"`, stores `NULL`, and warns in the same condition as S1. |
| S3 | `"Fay"` keeps its current behaviour: a supplied `scale` is discarded with no condition. A supplied `rscales` is kept. |
| S4 | `as_survey_replicate()` raises no new condition when the caller supplies neither `scale` nor `rscales`, on all nine types (D8). |
| S5 | `as_survey_replicate(type = "JKn")` with `rscales = NULL` is refused with `surveycore_error_stratified_jk_rscales_unset` (D4). |
| S6 | `as_survey_replicate(type = "JK2")` with `rscales = NULL` still builds and raises nothing. |
| S7 | The shipped `rho` warning keeps its class `surveycore_warning_rho_ignored` and gains the new class as a second class. Its message does not change. |
| S8 | `as_svydesign()` stops passing `scale` to `survey::svrepdesign()` for `"BRR"`, `"Fay"`, `"JK2"`, `"ACS"` and `"successive-difference"`, and stops passing `rscales` for `"JK2"`, `"ACS"` and `"successive-difference"` (D10). |
| S9 | `plans/error-messages.md` gains the new rows before any code changes. |
| S10 | Roxygen for `as_survey_replicate()` (`@param scale`, `@param rscales`) and `as_survey_nonprob()` states the new facts. `man/` is regenerated. |
| S11 | `NEWS.md` records the behaviour change. |

### Out

- `as_survey_nonprob()` code. It keeps refusing both `"JK2"` and `"JKn"` when
  `rscales` is `NULL`, and keeps its own scale defaults (D1). Only its roxygen
  changes.
- Validation of a supplied `scale` for the four types that honour it (JK1,
  JKn, bootstrap, other). `as_survey_replicate()` has no `scale` check today
  (a negative or non-numeric value is stored). This work adds none.
- `survey`'s acceptance of an `rscales` of length 1. `survey::svrepdesign()`
  accepts length 1 or `R`; surveycore refuses length 1 when `R > 1` with
  `surveycore_error_rscales_length`. This divergence is older than this work.
- `survey`'s unconditional JK2 warning on the export route. `as_svydesign()`
  on any JK2 design still gets the bare `survey` warning
  `with type JK2 scale= and rscales= are not needed and will be ignored`,
  because `survey` raises it whatever the call passes. surveycore does not
  muffle it.
- Designs that store a `scale` or `rscales` that `survey` overrides. Such a
  design can come from `survey_replicate()` called directly, from a design
  saved before this work, or from a `survey_nonprob` JK2 design, which must
  store a non-unit `rscales`. `as_svydesign()` cannot make `survey` use those
  values, so the exported standard error differs from surveycore's. This is
  older than this work. A follow-up issue is suggested; this work changes no
  number on that route.
- `bootstrap.average` (D5 leaves it out).
- `from_svydesign()`. It builds with `survey_replicate()` directly and does
  not reach the code this work changes.
- Vignettes. None calls `as_survey_replicate(type = "JKn")`, and the one JK2
  call (`vignettes/getting-started.Rmd`) passes no `rscales`.
- `.claude/rules/testing-surveycore.md`. No edit to the oracle rule.
- `update_design()` with changed replicate columns. It can leave a stored
  `scale` or `rscales` that no longer fits the new replicate count. This is
  older than this work and belongs to issue #300. This work does not touch
  `update_design()`.

### Type support matrix after this work

`R` is the number of replicate columns. "Supplied" means the argument is not
`NULL`. An argument passed as `NULL` explicitly counts as not supplied.

| Type | Supplied `scale` | Supplied `rscales` | `rscales = NULL` | Supplied `rho` | Stored `scale` when `scale` is not used |
|---|---|---|---|---|---|
| `"JK1"` | stored as given | stored as given | builds, stores `NULL` | warn, discard (shipped) | `(R - 1) / R` |
| `"JK2"` | **warn, discard** | **warn, discard, store `NULL`** | builds, stores `NULL` | warn, discard (shipped) | `1` |
| `"JKn"` | stored as given | stored as given | **refused** | warn, discard (shipped) | `1` |
| `"BRR"` | **warn, discard** | stored as given | builds, stores `NULL` | warn, discard (shipped) | `1 / R` |
| `"Fay"` | discard, no condition (shipped) | stored as given | builds, stores `NULL` | required (shipped) | `1 / (R * (1 - rho)^2)` |
| `"bootstrap"` | stored as given | stored as given | builds, stores `NULL` | warn, discard (shipped) | `1 / (R - 1)` |
| `"ACS"` | **warn, discard** | **warn, discard, store `NULL`** | builds, stores `NULL` | warn, discard (shipped) | `4 / R` |
| `"successive-difference"` | **warn, discard** | **warn, discard, store `NULL`** | builds, stores `NULL` | warn, discard (shipped) | `4 / R` |
| `"other"` | stored as given | stored as given | builds, stores `NULL` | warn, discard (shipped) | `1` |

Bold cells are new behaviour. Every other cell is the behaviour on `develop`
today and must not change.

---

## II. Architecture

### Files touched

| File | Change |
|---|---|
| `plans/error-messages.md` | New section with rows RS-1, RS-2, RS-3; updated trigger note for FR-3. First change in the work. |
| `R/utils.R` | Two new internal predicates, `.replicate_ignores_scale()` and `.replicate_ignores_rscales()` (Functions added). |
| `R/core-constructors.R` | `as_survey_replicate()` body and roxygen; `as_survey_nonprob()` roxygen only. |
| `R/methods-conversion.R` | `.as_svydesign_replicate()`: the `scale` and `rscales` arguments it passes, through the two predicates, and the comment above them. |
| `man/as_survey_replicate.Rd` | Regenerated by `devtools::document()`. |
| `man/as_survey_nonprob.Rd` | Regenerated by `devtools::document()`. |
| `NEWS.md` | Two Breaking-changes entries and one Bug-fixes entry (Section IX). |
| `tests/testthat/test-constructors.R` | New blocks; retargets listed in Section X. |
| `tests/testthat/test-conversion.R` | New blocks; one retarget listed in Section X. |
| `tests/testthat/test-variance-replicate.R` | New blocks. |
| `tests/testthat/_snaps/constructors.md` | New snapshot entries only. |

No other file changes. `NAMESPACE` does not change (no export changes).
`DESCRIPTION` does not change.

### Functions added

Two internal predicates. Each holds one closed set of type names, so the
constructor and the export route read the same set (decision D-g). Both go in
`R/utils.R`, because each has a call site in two files
(`R/core-constructors.R` and `R/methods-conversion.R`), and
`.claude/rules/code-style.md` puts a helper used in two or more files in the
shared utils file. Neither is exported. Neither gets roxygen; each gets a
comment header in the style of `.is_stratified_jk()`.

```r
# ── .replicate_ignores_scale() ───────────────────────────────────────────────
#
# Returns TRUE for the replicate types whose scale survey::svrepdesign()
# computes itself and does not take from the caller. Call sites:
# as_survey_replicate() and .as_svydesign_replicate().
.replicate_ignores_scale <- function(type) {
  type %in% c("BRR", "Fay", "JK2", "ACS", "successive-difference")
}

# ── .replicate_ignores_rscales() ─────────────────────────────────────────────
#
# Returns TRUE for the replicate types whose rscales survey::svrepdesign()
# sets to rep(1, R) and does not take from the caller. Call sites:
# as_survey_replicate() and .as_svydesign_replicate().
.replicate_ignores_rscales <- function(type) {
  type %in% c("JK2", "ACS", "successive-difference")
}
```

Contract for both:

| Input `type` | Return |
|---|---|
| A character scalar | `TRUE` or `FALSE` |
| `NULL` | `logical(0)` |
| A character vector of length `n` | A logical vector of length `n` |

The predicates do no `NULL` handling of their own. A caller that can pass a
`NULL` type wraps the call in `isTRUE()`. The export route does this (Section
IV). The constructor does not need to, because `type` is a character scalar
after `match.arg()`.

`"Fay"` is in the scale set because both packages discard a supplied Fay
`scale`. The constructor discards it silently, through the Fay step, and the
export route passes `scale = NULL`. The constructor's discard step excludes
`"Fay"` from the warning by an explicit test (Section III, step 9).

The JKn test is written inline as `identical(type, "JKn")`.
`.is_stratified_jk()` stays as it is, in `R/core-constructors.R`, with its one
call site in `as_survey_nonprob()`.

### Functions modified

- `as_survey_replicate(data, weights, repweights, type, rho, scale, rscales,
  fpc, fpctype, mse, calibration)`. Signature unchanged.
- `as_svydesign(x)`. Signature unchanged. The change is inside the replicate
  route, which `survey_replicate` designs and `survey_nonprob` designs with
  replicate weights both take.

### Class changes

None. No S7 class, property or validator changes. The `@variables` key set of
a `survey_replicate` is unchanged.

---

## III. `as_survey_replicate()` contract

### Signature

```r
as_survey_replicate(
  data,
  weights,
  repweights,
  type = c(
    "JK1", "JK2", "JKn", "BRR", "Fay", "bootstrap", "ACS",
    "successive-difference", "other"
  ),
  rho = NULL,
  scale = NULL,
  rscales = NULL,
  fpc = NULL,
  fpctype = c("fraction", "correction"),
  mse = TRUE,
  calibration = NULL
)
```

Unchanged from `develop`.

### Arguments (changed semantics only)

| Argument | Type | Default | Semantics after this work |
|---|---|---|---|
| `scale` | numeric scalar or `NULL` | `NULL` | Stored as given for `"JK1"`, `"JKn"`, `"bootstrap"`, `"other"`. Discarded with `surveycore_warning_replicate_arg_ignored` for `"BRR"`, `"JK2"`, `"ACS"`, `"successive-difference"`. Discarded with no condition for `"Fay"`. A discarded value is not checked: any non-`NULL` value, of any class, counts as supplied. A supplied value equal to the type's own value still counts as supplied and still warns. |
| `rscales` | numeric vector of length `R`, or `NULL` | `NULL` | Checked first by the existing length and NA/negative checks, for every type. Then: stored as given for `"JK1"`, `"JKn"`, `"BRR"`, `"Fay"`, `"bootstrap"`, `"other"`. Discarded with `surveycore_warning_replicate_arg_ignored` for `"JK2"`, `"ACS"`, `"successive-difference"`; the design stores `NULL`. Required for `"JKn"`: `NULL` is refused. |
| `rho` | numeric scalar or `NULL` | `NULL` | Unchanged. The non-Fay warning gains a second class (S7). |

### Order of checks

The function runs its steps in this order. Steps marked NEW are added; every
other step exists today and keeps its position.

1. `match.arg()` on `type` and `fpctype`.
2. `.validate_data_frame(data)` — empty data, single row, duplicate names,
   not a data frame.
3. Strip `haven_labelled` columns.
4. Resolve `weights`, `repweights` (empty selection refused), `fpc`.
5. Validate the weights column, the replicate columns, the FPC column.
6. `.validate_rscales(rscales, n_rep)` — length, then NA/negative/non-numeric.
   This runs on the supplied value for every type, including the three types
   that later discard it.
7. **NEW — JKn refusal.** If `type` is `"JKn"` and `rscales` is `NULL`, abort
   with `surveycore_error_stratified_jk_rscales_unset` (Section III.Errors).
   This step runs before the `rho` step, so a JKn call that also supplies
   `rho` raises the error and no warning.
8. The Fay step (unchanged): refuse a missing or invalid `rho`; set
   `scale <- 1 / (n_rep * (1 - rho)^2)`, which discards a supplied `scale`
   with no condition. For every other type, a supplied `rho` raises the `rho`
   warning (now with two classes) and is set to `NULL`.
9. **NEW — discard step.** Build `ignored`, a character vector:
   - add `"scale"` when `.replicate_ignores_scale(type)` is `TRUE`, `type` is
     not `"Fay"`, and `scale` is not `NULL`;
   - add `"rscales"` when `.replicate_ignores_rscales(type)` is `TRUE` and
     `rscales` is not `NULL`.

   The `"Fay"` exclusion is written as `!identical(type, "Fay")` in the
   `"scale"` condition. It is necessary: step 8 has already set `scale` to the
   Fay value, so without the exclusion every Fay call would warn. The
   resulting warning set for `"scale"` is `"BRR"`, `"JK2"`, `"ACS"`,
   `"successive-difference"`, and the set for `"rscales"` is `"JK2"`,
   `"ACS"`, `"successive-difference"`.

   ```r
   ignored <- character(0)
   if (
     .replicate_ignores_scale(type) &&
       !identical(type, "Fay") &&
       !is.null(scale)
   ) {
     ignored <- c(ignored, "scale")
   }
   if (.replicate_ignores_rscales(type) && !is.null(rscales)) {
     ignored <- c(ignored, "rscales")
   }
   ```

   The order inside `ignored` is always `"scale"` then `"rscales"`. When
   `ignored` has length 1 or 2, raise one warning,
   `surveycore_warning_replicate_arg_ignored`, naming every entry. Then set
   each named argument to `NULL`. When `ignored` has length 0, raise nothing.
10. The default-scale `switch()` (unchanged). It now runs for every discarded
    `scale`, so the stored value is the type's own value from the table in
    Section I.
11. Build `@variables`, metadata, calibration check, construct (unchanged).

One call raises at most two warnings: the `rho` warning from step 8, then the
discard warning from step 9. Both carry the class
`surveycore_warning_replicate_arg_ignored`.

### Returns

A `survey_replicate` object, visible. The `@variables` list has the same keys
as today: `weights`, `repweights`, `type`, `scale`, `rscales`, `fpc`,
`fpctype`, `mse`, `rho`, `visible_vars`.

Equality property: for a type that discards an argument, the `@variables` of a
design built with the argument supplied is `identical()` to the `@variables` of
the same call with that argument left out. Only `@call` differs.

### Errors

| Class | Trigger | Message template | Status |
|---|---|---|---|
| `surveycore_error_stratified_jk_rscales_unset` | `type` is `"JKn"` and `rscales` is `NULL` (not supplied, or supplied as `NULL`), after step 6 | `"x" = "{.code type = \"JKn\"} requires {.arg rscales}."`, `"i" = "JKn replicate weights are combined weights, so the stratum factor {.code (n_h - 1) / n_h} reaches the variance only through {.arg rscales}. {.fn survey::svrepdesign} refuses the same input."`, `"v" = "Pass {.arg rscales} with one entry per replicate column: {.code (n_h - 1) / n_h}, where {.code n_h} is the number of PSUs in the stratum the replicate drops a PSU from."` | Existing class, new call site (register row RS-2) |
| `surveycore_error_rscales_length` | Supplied `rscales` length is not `R`, any type | unchanged | Existing |
| `surveycore_error_rscales_na` | Supplied `rscales` has NA, negative or non-numeric values, any type | unchanged | Existing |
| `surveycore_error_fay_rho_missing`, `surveycore_error_fay_rho_invalid` | unchanged | unchanged | Existing |
| All data, weights, repweights, fpc and calibration errors | unchanged | unchanged | Existing |

The JKn message is written for this call site only. `as_survey_nonprob()`
raises the same class with its own message, which does not change (Section
XI, decision D-d).

### Warnings

| Class(es) | Trigger | Message template |
|---|---|---|
| `surveycore_warning_replicate_arg_ignored` | Step 9: `ignored` has length 1 or 2 | `"!" = "{.arg {ignored}} {?has/have} no effect for this replicate type and {?was/were} ignored."`, `"i" = "For type {.val {type}}, the design stores the type's own {cli::qty(n_ignored)}value{?s}, as {.fn survey::svrepdesign} does."`, `"v" = "Remove {.arg {ignored}} from the call."` |
| `c("surveycore_warning_rho_ignored", "surveycore_warning_replicate_arg_ignored")` | `type` is not `"Fay"` and `rho` is not `NULL` (unchanged trigger) | unchanged (register row FR-3) |

Bindings for the new warning: `{ignored}` is the character vector from step 9
(`"scale"`, `"rscales"`, or `c("scale", "rscales")`); `{n_ignored}` is
`length(ignored)`; `{type}` is the type after `match.arg()`. The "!" bullet
has no substitution between `{ignored}` and the two plural markers, so both
markers take their quantity from `length(ignored)`. Rendered for
`type = "JK2"` with both arguments supplied:

```
! `scale` and `rscales` have no effect for this replicate type and were ignored.
i For type "JK2", the design stores the type's own values, as `survey::svrepdesign()` does.
v Remove `scale` and `rscales` from the call.
```

Rendered for `type = "BRR"` with `scale` supplied:

```
! `scale` has no effect for this replicate type and was ignored.
i For type "BRR", the design stores the type's own value, as `survey::svrepdesign()` does.
v Remove `scale` from the call.
```

No warning fires when the caller supplies neither `scale` nor `rscales`, on any
type (D8). This differs from `survey::svrepdesign()`, which warns for every
JK2 call.

### Edge cases

| Case | Behaviour |
|---|---|
| Empty data frame, any type | `surveycore_error_empty_data`, before step 7. A JKn call with no `rscales` raises this class, not the JKn refusal. |
| Single-row data frame, any type | `surveycore_error_single_row`, before step 7. No one-row frame builds. |
| `repweights` selects no column, type `"JKn"` | `surveycore_error_repweights_empty`, before step 7. |
| All-zero or mixed zero weights, type `"JKn"` with no `rscales` | The weights error, before step 7. |
| All-`NA` outcome column | Builds. Steps 7 and 9 do not read outcome columns. |
| One replicate column (`R = 1`) | `"BRR"` with a supplied `scale` warns and stores `1`. `"ACS"` and `"successive-difference"` warn and store `4`. `"JKn"` builds with `rscales = 1` and stores `scale = 1`. `"bootstrap"` with a supplied `scale` stores it, and with none stores `Inf` (unchanged). |
| `scale = NULL` or `rscales = NULL` passed explicitly | Same as not supplied: no warning. For `"JKn"`, `rscales = NULL` is refused. |
| Supplied `scale` equal to the type's own value | Still supplied: warns for the four discarding types. |
| Supplied `scale` that is not numeric (for example `"a"`) for a discarding type | Discarded with the warning; never checked. |
| Supplied `scale` of `NA_real_`, `Inf`, a negative number, `0`, or a numeric vector of length `R`, for a discarding type | Each is a non-`NULL` value, so each counts as supplied. For `"BRR"`, `"JK2"`, `"ACS"` and `"successive-difference"`: discarded with `surveycore_warning_replicate_arg_ignored`, and the design stores the type's own value. For `"Fay"`: discarded with no condition, and the design stores the Fay value. No check runs on the value: no error, and no condition other than the discard warning. |
| Supplied `rscales` of the wrong length for `"JK2"`, `"ACS"` or `"successive-difference"` | `surveycore_error_rscales_length` at step 6; no warning. |
| Supplied `rscales` with an `NA` for a discarding type | `surveycore_error_rscales_na` at step 6; no warning. |
| `"JKn"` with `rscales = NULL` and `rho` supplied | The JKn refusal only. No `rho` warning. |
| `"BRR"` with both `rho` and `scale` supplied | Two warnings, in this order: the `rho` warning, then the discard warning naming `scale`. |
| `"JK2"`, `"ACS"` or `"successive-difference"` with `scale`, `rscales` and `rho` supplied | Two warnings: the `rho` warning, then one discard warning naming `scale` and `rscales`. |
| `"Fay"` with `scale` supplied | No condition; stores the Fay scale (unchanged). |
| `"BRR"` or `"Fay"` with `rscales` supplied | Stored as given; no condition. |
| Single-level grouping, degenerate strata | Not applicable: the constructor reads no strata or groups. |

### Roxygen facts (closed list)

`@param scale` must state each of these facts. The builder chooses the wording.
Existing facts in the paragraph stay unless this list contradicts them.

1. The four types `"JK1"`, `"JKn"`, `"bootstrap"`, `"other"` store a supplied
   `scale` as given.
2. For `"BRR"`, `"JK2"`, `"ACS"` and `"successive-difference"`, a supplied
   `scale` is ignored with a warning, and the design stores the type's own
   value. `survey::svrepdesign()` does the same.
3. For `"Fay"`, a supplied `scale` is ignored with no warning, as
   `survey::svrepdesign()` does (existing fact; keep it).
4. The warning class is `surveycore_warning_replicate_arg_ignored`.
5. Deliberate divergence (D8): surveycore warns only when the caller supplies
   `scale` or `rscales`. `survey::svrepdesign()` warns on every `"JK2"` call,
   even when the caller supplies neither. Reason: a warning that fires when the
   caller passed nothing tells the caller nothing, and unasserted warnings
   hide new ones.
6. The existing JKn sentence "`rscales = NULL` leaves no jackknife factor in
   the variance at all" is removed. In its place: `"JKn"` requires `rscales`,
   and `rscales = NULL` is refused, as `survey::svrepdesign()` refuses it for
   combined weights.
7. The existing sentence "Pass `scale` explicitly to reproduce numbers
   published before these two defaults moved" stays. It names `"JKn"` and
   `"bootstrap"`, which both keep a supplied scale.

`@param rscales` must state each of these facts:

1. Required for `"JKn"`; `NULL` is refused.
2. For `"JK2"`, `"ACS"` and `"successive-difference"`, a supplied `rscales` is
   ignored with the same warning, and the design stores `NULL`, which the
   variance treats as `rep(1, R)`. `survey::svrepdesign()` forces
   `rep(1, R)` for these types.
3. For the other five types, a supplied `rscales` is stored as given.
4. The length and value checks run on a supplied `rscales` for every type,
   including the three that ignore it.

`@param rho`: the sentence "For every other `type`, a supplied `rho` is ignored
with a warning" may add that the warning also carries the class
`surveycore_warning_replicate_arg_ignored`. Optional. It must state that for
`"JKn"` with no `rscales`, the refusal fires and no `rho` warning is raised,
where `survey::svrepdesign()` raises both.

---

## IV. `as_svydesign()` contract (replicate route)

### Signature

`as_svydesign(x)`. Unchanged.

### Behaviour change

On the replicate route, the call to `survey::svrepdesign()` passes:

| Stored `@variables$type` | `scale =` | `rscales =` | `rho =` |
|---|---|---|---|
| `"JK1"`, `"JKn"`, `"bootstrap"`, `"other"` | `x@variables$scale` | `x@variables$rscales` | `NULL` |
| `"BRR"` | `NULL` | `x@variables$rscales` | `NULL` |
| `"Fay"` | `NULL` | `x@variables$rscales` | stored `rho` (unchanged) |
| `"JK2"`, `"ACS"`, `"successive-difference"` | `NULL` | `NULL` | `NULL` |

The change from `develop`: `"JK2"`, `"ACS"` and `"successive-difference"` no
longer get the stored `scale`, and no longer get the stored `rscales`. `"BRR"`
and `"Fay"` already got `scale = NULL`. Every other argument of the call
(`weights`, `repweights`, `type`, `mse`, `data`) and every other step of the
route (empty-replicate refusal, Fay `rho` refusal, FPC drop and its warning,
domain restriction) is unchanged.

The two type tests call the shared predicates (Section II, Functions added)
in place of an inline type list. Each call is wrapped in `isTRUE()`, as the
route's type test is today, so a `NULL` stored type gives `FALSE` and does not
error at this step:

```r
scale_arg <- if (isTRUE(.replicate_ignores_scale(x@variables$type))) {
  NULL
} else {
  x@variables$scale
}
rscales_arg <- if (isTRUE(.replicate_ignores_rscales(x@variables$type))) {
  NULL
} else {
  x@variables$rscales
}
```

`scale_arg` and `rscales_arg` are the values passed as `scale =` and
`rscales =`. The predicates give the table above: the scale set is `"BRR"`,
`"Fay"`, `"JK2"`, `"ACS"`, `"successive-difference"`; the `rscales` set is
`"JK2"`, `"ACS"`, `"successive-difference"`. The constructor reads the same
two sets, which is what the numerical property below depends on.

The comment above the `scale` argument is rewritten. It must state:

- `survey::svrepdesign()` computes its own `scale` for these five types and
  its own `rscales` (`rep(1, R)`) for JK2, ACS and successive-difference;
- passing the stored value changes no number `survey` computes, and for ACS
  and successive-difference it raises `survey`'s
  `scale= and rscales= are not needed` warning;
- `survey` warns on every JK2 call regardless (D8 records the divergence).

### Returns

Unchanged: a `survey::svrepdesign` object, restricted to the active domain.

### Numerical property

For a design built by `as_survey_replicate()` after this work, of any of the
nine types, with or without an explicit `scale`, `survey::svymean()` on the
converted object returns surveycore's point estimate and standard error from
`get_means()`. This holds because a discarding type now stores the value
`survey` computes, and an honouring type passes its stored value, which
`survey` keeps.

The two halves of this work carry the property differently:

- For `"BRR"`, `"Fay"`, `"JK2"`, `"ACS"` and `"successive-difference"`,
  `survey::svrepdesign()` recomputes `scale` (and, for the last three,
  `rscales`) from the replicate count and `rho` whatever the call passes. So
  the export-route change for these five types moves no exported number. It
  removes `survey`'s "not needed" warning on ACS and successive-difference.
  The constructor change is what makes surveycore's own `get_means()` agree.
- For `"JK1"`, `"JKn"`, `"bootstrap"` and `"other"`, `survey` keeps a
  supplied `scale` and `rscales`, so passing the stored values is what makes
  the export agree.

### Conditions

No new surveycore condition. The route raises the same surveycore conditions
as today. Bare `survey` conditions after this work:

| Type | `survey` warning on export |
|---|---|
| `"JK2"` | `with type JK2 scale= and rscales= are not needed and will be ignored` (every call; unchanged) |
| `"other"` with stored `rscales = NULL` or `scale = NULL` | `scale or rscales not specified, set to 1` (unchanged) |
| `"ACS"`, `"successive-difference"` with a stored non-`NULL` `scale` or `rscales` | none (was: `with type ACS scale= and rscales= are not needed and will be ignored`) |
| all other types | none (unchanged) |

### Edge cases

| Case | Behaviour |
|---|---|
| A design imported by `from_svydesign()` from a `survey` ACS or successive-difference design (stores `rscales = rep(1, R)` and `scale = 4/R`) | Converts with no `survey` warning. Before this work it raised the `not needed` warning. |
| A `survey_nonprob` JK2 design (stores a required non-unit `rscales`) | `rscales` is no longer passed. `survey` forced `rep(1, R)` before and after, so no exported number moves. Out of scope (Section I). |
| A `survey_nonprob` JKn or bootstrap design | Unchanged: `scale` and `rscales` are passed. |
| A filtered design | Domain restriction unchanged. |

---

## V. `as_survey_nonprob()` (documentation only)

No code change. The roxygen gains one sentence in the `type` entries for
`"JK2"` (or in `@param rscales`, builder's choice) with these facts (D1):

- `as_survey_replicate()` accepts `"JK2"` with no `rscales`, as
  `survey::svrepdesign()` does;
- `as_survey_nonprob()` keeps the refusal, because `survey` has no
  non-probability design class and so is not the reference for this
  constructor.

The `surveycore_error_stratified_jk_rscales_unset` message in
`as_survey_nonprob()` does not change. Its existing snapshots must stay
byte-identical.

---

## VI. Condition register changes (`plans/error-messages.md`)

Add a new section at the end of the file, titled
`### replicate-supplied-args rows (2026-10-01)`, before any code change. The
prefix `RS` stands for replicate supplied arguments.

Intro text for the section must state: issue #255; RS-1 is the single class for
"the replicate type ignores this argument", with the argument named in the
bullet; RS-2 adds a call site to an existing class; RS-3 records the
`as_survey_nonprob()` site of the same class, which shipped without a register
row.

Variable bindings line: `{ignored}` = the discarded argument names, in the
order `"scale"`, `"rscales"`; `{n_ignored}` = `length(ignored)`; `{type}` = the
replicate type after `match.arg()`.

| # | Function | Condition | Level | Error Class | cli Message Template |
|---|---|---|---|---|---|
| RS-1 | `as_survey_replicate()` | `type` is `"BRR"`, `"JK2"`, `"ACS"` or `"successive-difference"` and `scale` is not `NULL`; or `type` is `"JK2"`, `"ACS"` or `"successive-difference"` and `rscales` is not `NULL`. One warning names every discarded argument. The design stores the type's own `scale` and `rscales = NULL`. No warning when neither is supplied (D8). Also carried as the second class of FR-3 | WARN | `surveycore_warning_replicate_arg_ignored` | the template in Section III.Warnings, verbatim |
| RS-2 | `as_survey_replicate()` | `type` is `"JKn"` and `rscales` is `NULL`. Checked after the `rscales` length and value checks and before the `rho` step | ERROR | `surveycore_error_stratified_jk_rscales_unset` | the template in Section III.Errors, verbatim |
| RS-3 | `as_survey_nonprob()` | `type` is `"JK2"` or `"JKn"` and `rscales` is `NULL`. Shipped before this work; recorded here | ERROR | `surveycore_error_stratified_jk_rscales_unset` | `"x" = "{.arg type} = {.val {type}} requires explicit {.arg rscales}.", "i" = "Stratified jackknife rscales are stratum-specific: {.code (n_h - 1) / n_h}. Supplying {.code NULL} would silently use {.code rep(1, R)}, which is statistically incorrect for JK2/JKn.", "v" = "Compute {.code rscales} as {.code (n_h - 1) / n_h} where {.code n_h} is the number of units in stratum {.code h}, indexed to replicate order."` |

Below the table, add a note under the heading the file already uses for this
purpose, written exactly as `**Updated trigger descriptions for existing
rows:**`:

- Row FR-3 (`surveycore_warning_rho_ignored`): the condition now carries two
  classes, `c("surveycore_warning_rho_ignored",
  "surveycore_warning_replicate_arg_ignored")`. The trigger and message do not
  change.

---

## VII. `cli` call shape

Both new calls follow `.claude/rules/code-style.md`: `class =` on the call,
`{.arg}` for argument names, `{.code}` for code, `{.val}` for values, `{.fn}`
for functions. The discard warning is a `cli::cli_warn()` call with the
`"!"`, `"i"`, `"v"` bullets, as the shipped `rho` warning uses. The JKn
refusal is a `cli::cli_abort()` with `"x"`, `"i"`, `"v"`.

---

## VIII. Integration

- **`survey`.** Behaviour now matches `survey:::svrepdesign.default` for every
  supplied `scale`, `rscales` and `rho` that `survey` accepts, except two
  recorded divergences: no warning when nothing is supplied (D8), and the
  `rho` warning for `"bootstrap"`, where `survey` raises nothing (shipped in
  #243, decision D6 of `plans/issue-cleanup.md`). One more difference sits
  outside that rule, because `survey` refuses the input: for `type = "JKn"`
  with `rho` supplied and `rscales = NULL`, `survey` raises its `rho` warning
  and then its error, and surveycore raises only
  `surveycore_error_stratified_jk_rscales_unset`. The refusal runs first, and
  a warning about an argument of a call that errors adds nothing (decision
  D-f).
- **surveytidy.** No contract change. surveytidy does not construct replicate
  designs.
- **Existing designs.** A design saved before this work keeps whatever it
  stored. Nothing re-runs the constructor.
- **`update_design()`.** A call that changes the replicate columns can leave a
  stored `scale` or `rscales` that no longer fits the new replicate count.
  This is older than this work and is deferred to issue #300. This work does
  not touch `update_design()`.

---

## IX. `NEWS.md` (closed list of facts)

Under `## Breaking changes` in the development section, two entries:

1. `as_survey_replicate()` now ignores a supplied `scale` for `"BRR"`,
   `"JK2"`, `"ACS"` and `"successive-difference"`, and a supplied `rscales` for
   `"JK2"`, `"ACS"` and `"successive-difference"`, as `survey::svrepdesign()`
   does. It stores the type's own value and warns with
   `surveycore_warning_replicate_arg_ignored`. A caller who passed one of these
   gets the standard error `survey` computes, which differs from the one
   surveycore returned before. Nothing changes when the caller supplies
   neither, and surveycore then raises no warning, unlike `survey` for
   `"JK2"`. `"Fay"` already ignored `scale` with no warning. The `rho`
   warning, `surveycore_warning_rho_ignored`, now also carries the new class.
   (#255)
2. `as_survey_replicate(type = "JKn")` now requires `rscales` and refuses
   `rscales = NULL` with `surveycore_error_stratified_jk_rscales_unset`, as
   `survey::svrepdesign()` refuses combined JKn weights without it. Before this
   change the design built with `rep(1, R)` and left the jackknife factor out
   of the variance. To migrate, pass `rscales` with one entry per replicate
   column, for example `(n_h - 1) / n_h`, where `n_h` is the number of PSUs in
   the stratum the replicate drops a PSU from. `"JK2"` with no `rscales` still
   builds. (#255, #244)

Under `## Bug fixes`, one entry:

3. `as_svydesign()` no longer passes `scale` to `survey::svrepdesign()` for
   `"BRR"`, `"Fay"`, `"JK2"`, `"ACS"` and `"successive-difference"`, or
   `rscales` for `"JK2"`, `"ACS"` and `"successive-difference"`. `survey`
   computes those values itself. The exported design computes the same
   numbers, and `survey` no longer warns about the ignored arguments for
   `"ACS"` and `"successive-difference"`. It still warns for every `"JK2"`
   design. (#255)

---

## X. Existing assertions this change breaks (closed list)

These eleven existing blocks fail or warn after the change. Each must be
changed in the same PR as the behaviour that breaks it. The block titles are
exact.

`tests/testthat/test-constructors.R` — each builds `type = "JKn"` with no
`rscales`, which step 7 now refuses:

| # | Block title | Change |
|---|---|---|
| X1 | `as_survey_replicate() JKn and bootstrap defaults rise by R/(R-1)` | Pass `rscales = rep(1, n_rep)` to the JKn call. Keep every assertion. |
| X2 | `as_survey_replicate() scale at one and two replicate columns` | Pass `rscales = 1` to the `d_jkn_one` call (one replicate column). |
| X3 | `as_survey_replicate() stores an explicit scale verbatim` | Pass `rscales = rep(1, n_rep)` to the JKn call. |
| X4 | `as_survey_replicate() JKn with rscales = NULL stores scale = 1` | The block asserts the opposite of the new behaviour. Delete it. The JKn refusal block replaces it. |
| X5 | `as_survey_replicate() stores both changed defaults on a two-row frame` | Pass `rscales = rep(1, n_rep)` (`n_rep` is 20) to the JKn call. |
| X6 | `as_survey_replicate() stores the default scale of all nine types, Fay with rho` | Give the JKn line `rscales = rep(1, 20)`. The helper inside the block gains an `rscales` argument, default `NULL`. |
| X7 | `as_survey_replicate() warns and discards rho for the eight other types` | Pass `rscales = rep(1, 20)` for `"JKn"` in both calls inside the loop, `NULL` for the other types. |
| X8 | `as_survey_replicate() stores the rho key for every type` | Same: `rscales = rep(1, 20)` for `"JKn"` only. |
| X9 | `as_survey_replicate() raises no warning for the eight other types with no rho` | Same: `rscales = rep(1, 20)` for `"JKn"` only. |
| X10 | `as_survey_twophase() refuses a replicate phase-1 of all nine types` | Pass `rscales` for `"JKn"` only, of length equal to the frame's replicate count (the frame has `n_psu = 10`, type `"brr"` default: 5 columns, so `rep(1, 5)`). |

`tests/testthat/test-conversion.R`:

| # | Block title | Change |
|---|---|---|
| X11 | `every accepted replicate type crosses both conversion routes` | The loop passes `rscales = rep(1, 5L)` to `"JK2"`, which now raises the discard warning outside the muffled call. Pass `rscales` for `"JKn"` only. The comment above the block names an ACS `survey` warning that no longer fires; update it. |

`rep(1, R)` changes no asserted value in X1–X3 and X5–X10: the stored `scale`
for JKn stays `1`, and the variance treats `rep(1, R)` and `NULL` alike.

One more block stays green with no edit to its code but carries a stale
comment. Update the comment only:

| # | Block title | Change |
|---|---|---|
| X12 | `as_svydesign() warns and converts for every replicate type carrying an FPC` (`test-conversion.R`) | The comment says `survey` warns for "the types that ignore a scale". After this work only JK2 makes `survey` warn about ignored arguments. Rewrite the comment to say so. No assertion and no call changes. |

The stale ACS comment above X11 is part of the X11 change, not a separate
entry.

No existing block other than X1 to X12 changes. In particular, every
`as_survey_nonprob()` block and snapshot stays byte-identical.

---

## XI. Decisions this spec makes

The locked decisions do not cover these seven points.

**D-a. The new class sits beside the `rho` class, and the `rho` warning carries
both.** The request asks for one class for "the type ignores this argument".
`surveycore_warning_rho_ignored` shipped in #243 and is pinned by existing
tests. Renaming it breaks callers. Folding `rho` into the new warning's message
changes a shipped message and its snapshot. So the `rho` warning keeps its
class and message, and gains `surveycore_warning_replicate_arg_ignored` as a
second class. One class now catches every discarded argument; the shipped
class still works.

**D-b. A discarded `rscales` is stored as `NULL`, not as `rep(1, R)`.** The
request text says "`rep(1, R)` stored". surveycore stores `NULL` for "not
supplied" on every type, and the variance treats `NULL` as `rep(1, R)`. Storing
`NULL` makes a supplied-then-discarded design identical to one where the caller
left `rscales` out, and keeps the export route from passing an `rscales` that
`survey` would warn about. The effective value is `rep(1, R)` either way. This
point is raised to the caller as a HOLD; reversing it touches step 9 and the
roxygen only.

**D-c. Checks run before the discard.** A supplied `rscales` of the wrong
length, or with an `NA`, is refused for every type, including the three that
then ignore it. This keeps the order every type already uses and keeps
one rule for "a malformed argument is an error". It refuses one input
`survey` accepts (a wrong-length `rscales` for JK2, ACS or
successive-difference), which is a caller error in any reading.

**D-d. The JKn refusal has its own message, under the shared class.** The
`as_survey_nonprob()` message says the rule holds "for JK2/JKn", which is false
for `as_survey_replicate()` (D3, D4). Changing that message would move a
shipped snapshot that D1 leaves alone. So the class is shared and each call
site keeps its own text. No shared helper is extracted: the two messages
differ.

**D-e. The export route also stops passing `rscales` for JK2, ACS and
successive-difference.** D10 names `scale` only. `survey` forces
`rscales <- rep(1, R)` for these three types, so the stored value changes no
number it computes, and a non-`NULL` value makes `survey` warn for ACS and
successive-difference. Dropping it is the same act as D10, applied to the
second argument `survey` overrides.

**D-f. The JKn refusal runs before the `rho` step, and no `rho` warning
accompanies it.** `survey` warns about `rho` and then refuses
`type = "JKn"` with no `rscales`. surveycore raises the refusal alone. D7's
parity rule covers inputs `survey` accepts, and `survey` refuses this one.
The difference is stated in §VIII and in `@param rho`.

**D-g. The two type sets live in two shared predicates.** The first draft
wrote the scale set and the `rscales` set inline, once in
`as_survey_replicate()` and once in `.as_svydesign_replicate()`. This work now
adds `.replicate_ignores_scale()` and `.replicate_ignores_rscales()` to
`R/utils.R`, and both functions call them. Three reasons:

- `.claude/rules/engineering-preferences.md` ranks DRY first. Two copies of a
  closed list drift apart when someone edits one of them.
- The numerical property in Section IV holds only while the constructor and
  the export route agree on which types discard which argument. One
  definition makes that agreement a fact of the code.
- `.is_stratified_jk()` is the precedent: a one-line type-set predicate with a
  name that says what the set means.

The scale predicate includes `"Fay"`, because both packages discard a Fay
`scale`. The constructor keeps Fay's discard silent with an explicit
`!identical(type, "Fay")` test in step 9. The alternative was a scale set
without Fay plus a separate Fay branch at the export route. It keeps two
lists where one is enough.

---

## Quality gates

Every gate is checked on the PR's own head.

- [ ] `plans/error-messages.md` carries RS-1, RS-2, RS-3 and the FR-3 note, in
      a commit that precedes or is the same as the first code change.
- [ ] `devtools::document()` leaves no diff in `man/` or `NAMESPACE`.
- [ ] The full suite (`devtools::test()`) passes with no failure.
- [ ] The full suite raises no new warning. `develop` carries 256 pre-existing
      AAPOR small-cell warnings; the count after the PR is 256.
- [ ] `R CMD check`: 0 errors, 0 warnings; notes only the pre-approved ones
      plus the pre-existing `.git` hidden-file note. Read the `Status:` line.
- [ ] `air format --check` passes on every R file the PR touches.
- [ ] Coverage with `NOT_CRAN=true` stays at or above 95%, and every new branch
      in `as_survey_replicate()` and the replicate route of `as_svydesign()` is
      reached.
- [ ] No snapshot in `tests/testthat/_snaps/` changes except new entries.
- [ ] `as_survey_nonprob()` source is byte-identical apart from roxygen lines.

## Pipeline tier

recommended — the work changes numerical behaviour of an exported constructor,
adds a typed warning class and a typed refusal, and touches more than three
files.
