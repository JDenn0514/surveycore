# Test-spec — replicate-supplied-args

**Status**: DRAFT
**Date**: 2026-10-01
**Revision**: 2 (2026-10-06, review Pass 1 resolved)
**Issues**: #255, and the JKn half of #244

This document tells the tester what to check and with which values. Every
value, class name, message fragment and fixture a row needs is written here.

---

## 1. Behaviour under test

`as_survey_replicate()` must treat a supplied `scale`, `rscales` and `rho` the
way `survey::svrepdesign()` does. "Supplied" means the argument is not `NULL`;
an argument passed as `NULL` explicitly counts as not supplied. `R` is the
number of replicate columns.

| Type | Supplied `scale` | Supplied `rscales` | `rscales = NULL` | Supplied `rho` | Stored `scale` when `scale` is not used |
|---|---|---|---|---|---|
| `"JK1"` | stored as given | stored as given | builds, stores `NULL` | warns, discarded | `(R - 1) / R` |
| `"JK2"` | **warns, discarded** | **warns, discarded, stores `NULL`** | builds, stores `NULL` | warns, discarded | `1` |
| `"JKn"` | stored as given | stored as given | **refused** | warns, discarded | `1` |
| `"BRR"` | **warns, discarded** | stored as given | builds, stores `NULL` | warns, discarded | `1 / R` |
| `"Fay"` | discarded, no condition | stored as given | builds, stores `NULL` | required | `1 / (R * (1 - rho)^2)` |
| `"bootstrap"` | stored as given | stored as given | builds, stores `NULL` | warns, discarded | `1 / (R - 1)` |
| `"ACS"` | **warns, discarded** | **warns, discarded, stores `NULL`** | builds, stores `NULL` | warns, discarded | `4 / R` |
| `"successive-difference"` | **warns, discarded** | **warns, discarded, stores `NULL`** | builds, stores `NULL` | warns, discarded | `4 / R` |
| `"other"` | stored as given | stored as given | builds, stores `NULL` | warns, discarded | `1` |

Bold cells are new. The others are current behaviour and must not move.

Further rules:

- One call raises at most one discard warning, naming every discarded
  argument (`scale`, `rscales`, or both).
- No warning fires when the caller supplies neither `scale` nor `rscales`, on
  any type. `survey` warns on every JK2 call; surveycore deliberately does not.
- The `rho` warning keeps its class `surveycore_warning_rho_ignored` and now
  also carries `surveycore_warning_replicate_arg_ignored`. Its message does
  not change.
- When `rho` and a discarded argument are both supplied, two warnings fire:
  the `rho` warning first, then the discard warning.
- The length and value checks on a supplied `rscales` run first, for every
  type. A malformed `rscales` is refused even for a type that ignores it.
- A JKn call with no `rscales` is refused before the `rho` warning can fire.
- `as_svydesign()` on a design built by `as_survey_replicate()` reproduces
  surveycore's point estimate and standard error for all nine types, with or
  without an explicit `scale`. It no longer makes `survey` warn about ignored
  arguments for ACS and successive-difference. `survey` still warns on every
  JK2 export.
- `as_survey_nonprob()` does not change. It still refuses JK2 and JKn with no
  `rscales`.
- The set of types that discard a supplied `scale` is the same in
  `as_survey_replicate()` and `as_svydesign()`: `"BRR"`, `"Fay"`, `"JK2"`,
  `"ACS"`, `"successive-difference"`. Only Fay's discard is silent. The set
  that discards a supplied `rscales` is `"JK2"`, `"ACS"`,
  `"successive-difference"` on both functions.
- A discarded `scale` is not checked. `NA_real_`, `Inf`, a negative number,
  `0` and a numeric vector of length `R` are all discarded the same way as
  `0.6`.

Out of scope: `update_design()` with changed replicate columns can leave a
stale stored `scale` or `rscales`. That is older than this work and belongs to
issue #300. Do not test it here.

---

## 2. Conditions inventory

| Class | Level | Raised by | Assertion pattern |
|---|---|---|---|
| `surveycore_warning_replicate_arg_ignored` | WARN | `as_survey_replicate()` — new | `expect_warning(class = )`; snapshots in rows 5.6 to 5.8 and 5.23 |
| `surveycore_warning_rho_ignored` | WARN | `as_survey_replicate()` — shipped; now carries both classes | `expect_warning(class = )` for each class |
| `surveycore_error_stratified_jk_rscales_unset` | ERROR | `as_survey_replicate()` — new call site; `as_survey_nonprob()` — unchanged | Dual: `expect_error(class = )` + `expect_snapshot(error = TRUE)` |
| `surveycore_error_rscales_length` | ERROR | existing | `expect_error(class = )`; its snapshot already exists |
| `surveycore_error_rscales_na` | ERROR | existing | `expect_error(class = )`; its snapshot already exists |
| `surveycore_error_single_row`, `surveycore_error_empty_data` | ERROR | existing | `expect_error(class = )` |

The new warning's message has three bullets. Rendered text, for checking a
snapshot by eye:

```
! `scale` and `rscales` have no effect for this replicate type and were ignored.
i For type "JK2", the design stores the type's own values, as `survey::svrepdesign()` does.
v Remove `scale` and `rscales` from the call.
```

```
! `scale` has no effect for this replicate type and was ignored.
i For type "BRR", the design stores the type's own value, as `survey::svrepdesign()` does.
v Remove `scale` from the call.
```

The new JKn refusal message from `as_survey_replicate()`:

```
x `type = "JKn"` requires `rscales`.
i JKn replicate weights are combined weights, so the stratum factor `(n_h - 1) / n_h` reaches the variance only through `rscales`. `survey::svrepdesign()` refuses the same input.
v Pass `rscales` with one entry per replicate column: `(n_h - 1) / n_h`, where `n_h` is the number of PSUs in the stratum the replicate drops a PSU from.
```

`as_survey_nonprob()` keeps its own message for the same class. Its two
existing snapshots
(`surveycore_error_stratified_jk_rscales_unset fires for JK2 with rscales =
NULL` and `surveycore_error_stratified_jk_rscales_unset fires for JKn with
rscales = NULL`) must not change.

---

## 3. Reference oracle

- `survey::svrepdesign()`, `survey::svymean()`, `survey::SE()`, `confint()`,
  read from `survey` 4.5 under R 4.6.1.
- Before writing an oracle block, build a probe design on the installed
  `survey` version and confirm the warning texts in the table below. A later
  release can change a message. When an oracle block turns red, check the
  installed `survey` version first.
- `survey`'s conditions carry no class. Match them by message text with
  `fixed = TRUE`, never by class.

`survey` warning and error texts the rows use:

| Call | `survey` condition text |
|---|---|
| `type = "BRR"`, `scale` supplied | `type='BRR' does not use 'scale=' argument` |
| `type = "JK2"`, any call | `with type JK2 scale= and rscales= are not needed and will be ignored` |
| `type = "ACS"`, `scale` or `rscales` supplied | `with type ACS scale= and rscales= are not needed and will be ignored` |
| `type = "successive-difference"`, `scale` or `rscales` supplied | `with type successive-difference scale= and rscales= are not needed and will be ignored` |
| `type = "other"`, `scale` or `rscales` not supplied | `scale or rscales not specified, set to 1` |
| `type = "JKn"`, combined weights, no `rscales` (error) | `Must provide rscales for combined JKn weights` |
| `type = "Fay"`, `scale` supplied | none |
| `type = "JK1"`, `"JKn"`, `"bootstrap"`, `scale` supplied | none |

Pass `mse = TRUE` explicitly to both sides of every oracle block. With `mse`
supplied, `survey` prints no ACS message.

### How these blocks sit with the oracle rule

`.claude/rules/testing-surveycore.md` rule 2 says "pass `scale` to neither
side". Rows 6.1 to 6.9 pass the literal `0.6` to both sides on purpose. This
does not breach the rule, for these reasons:

- Rule 2 exists so that a block cannot hand `survey` the number surveycore
  computed as its default and get it back. In these rows `0.6` is a caller
  literal written into the block. It is not read off a design, and it equals
  none of the nine defaults at `R = 20`.
- Rows 6.1 to 6.4 test a different claim from the default-scale oracle
  blocks: "both packages keep a scale the caller supplies". `survey` honours a
  supplied `scale` for JK1, JKn, bootstrap and `other` (the per-type table in
  the rule file), so each side computes with `0.6` independently, and the
  block turns red if surveycore drops or alters it.
- Rows 6.5 to 6.9 pass `0.6` to types where `survey` discards it. Here `survey`
  computes its own scale, so the comparison is independent again. The block
  turns red if surveycore keeps `0.6`, which is the defect issue #255 reports.
- Each stored scale is asserted against a literal, never against the other
  side's stored scale.

Rule 3 still holds: `rscales` goes to the `survey` side for JKn only. Rule 5
still holds: every `survey` warning is asserted by text and none is silenced.

---

## 4. Datasets

| Id | Construction | Replicate columns | Use |
|---|---|---|---|
| F1 | `make_survey_data(n = 200, n_psu = 20, n_strata = 4, design = "replicate", type = "jk1", seed = 15)` | `repwt_1` to `repwt_20`, so `R = 20` | Sections 5 and 6 |
| F2 | `make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, design = "replicate", type = "brr", seed = 430L)` | `repwt_1` to `repwt_5`, so `R = 5` | Section 7 |
| F3 | F1 with `repweights = tidyselect::all_of("repwt_1")` | `R = 1` | Row 5.24 |
| F4 | Inline: 10 rows, `y1 = rep(NA_real_, 10)`, `wt = c(2.5, 3.1, 2.8, 2.2, 3.4, 2.9, 3.6, 2.4, 3.0, 2.7)`, `repwt_i = wt * (0.9 + i / 100)` for `i` in 1 to 8 | `R = 8` | Row 5.25 |

Edge frames are built inline from F1: `F1[0, ]` (empty) and `F1[1, ]` (one
row). No one-row frame builds: the constructor refuses it with
`surveycore_error_single_row` before any type rule.

Expected stored `scale` values on F1 (`R = 20`):

| Type | Literal |
|---|---|
| `"JK1"` | `19 / 20` |
| `"JK2"` | `1` |
| `"JKn"` | `1` |
| `"BRR"` | `1 / 20` |
| `"Fay"`, `rho = 0.3` | `1 / (20 * (1 - 0.3)^2)` |
| `"bootstrap"` | `1 / 19` |
| `"ACS"` | `4 / 20` |
| `"successive-difference"` | `4 / 20` |
| `"other"` | `1` |

Expected stored `scale` values on F2 (`R = 5`): JK2 `1`, BRR `1 / 5`, Fay with
`rho = 0.3` `1 / (5 * (1 - 0.3)^2)`, ACS `4 / 5`, successive-difference
`4 / 5`.

Common literals: the supplied scale is `0.6`; the supplied JKn `rscales` is
`rep(1, R)`; a supplied discarded `rscales` is `rep(0.5, R)`; Fay uses
`rho = 0.3`.

---

## 5. `as_survey_replicate()` — `tests/testthat/test-constructors.R`

### Discarded `scale`

| Row | Scenario | Assertions |
|---|---|---|
| 5.1 | F1; for each of `"BRR"`, `"JK2"`, `"ACS"`, `"successive-difference"`: build with `scale = 0.6`, and build the same call with no `scale` | `expect_warning(class = "surveycore_warning_replicate_arg_ignored")` on the first call, result taken from its return value; stored `scale` equals the F1 literal for the type, `tolerance = 1e-8`; `expect_identical(d@variables, d_plain@variables)`; `expect_no_warning()` on the second call |
| 5.2 | F1; `"Fay"`, `rho = 0.3`, `scale = 0.6` | `expect_no_warning()`; stored `scale` equals `1 / (20 * (1 - 0.3)^2)`, `tolerance = 1e-8`. An existing block (`as_survey_replicate() discards a supplied scale for Fay with no warning`, with `scale = 99`) covers this; confirm it still passes. No new block needed |
| 5.3 | F1; `"BRR"`, `scale = 1 / 20` (equal to the default) | Still warns: `expect_warning(class = "surveycore_warning_replicate_arg_ignored")` |
| 5.4 | F1; `"BRR"`, `scale = "a"` | `expect_no_error()` around `expect_warning(class = "surveycore_warning_replicate_arg_ignored")`; stored `scale` equals `1 / 20`, `tolerance = 1e-8` |

### Discarded `rscales`

| Row | Scenario | Assertions |
|---|---|---|
| 5.5 | F1; for each of `"JK2"`, `"ACS"`, `"successive-difference"`: `rscales = rep(0.5, 20)`, and the same call with no `rscales` | `expect_warning(class = "surveycore_warning_replicate_arg_ignored")`; `expect_null(d@variables$rscales)`; `expect_identical(d@variables, d_plain@variables)`; `get_means(d, y1, variance = "se")$se` equals the same from `d_plain`, `tolerance = 1e-8` |
| 5.6 | F1; `"BRR"`, `scale = 0.6` | `expect_snapshot(d <- as_survey_replicate(...))` — the one-argument message |
| 5.7 | F1; `"JK2"`, `scale = 0.6`, `rscales = rep(0.5, 20)` | `expect_snapshot(d <- as_survey_replicate(...))` — the two-argument message, plural verbs |
| 5.8 | F1; `"ACS"`, `rscales = rep(0.5, 20)` only | `expect_snapshot(d <- as_survey_replicate(...))` — names `rscales` only |
| 5.9 | F1; for each of `"JK2"`, `"ACS"`, `"successive-difference"`: `scale = 0.6` and `rscales = rep(0.5, 20)` | `w <- testthat::capture_warnings(d <- as_survey_replicate(...))`; `expect_length(w, 1L)`; stored `scale` equals the F1 literal, `tolerance = 1e-8`; `expect_null(d@variables$rscales)` |

### Kept arguments

| Row | Scenario | Assertions |
|---|---|---|
| 5.10 | F1; for each of `"JK1"`, `"bootstrap"`, `"other"`, and `"JKn"` with `rscales = rep(1, 20)`: `scale = 0.6` | `expect_no_warning()`; stored `scale` equals `0.6`, `tolerance = 1e-8` |
| 5.11 | F1; for each of `"JK1"`, `"JKn"`, `"BRR"`, `"bootstrap"`, `"other"`, and `"Fay"` with `rho = 0.3`: `rscales = rep(0.5, 20)` | `expect_no_warning()`; `expect_identical(d@variables$rscales, rep(0.5, 20))` |

### No warning when nothing is supplied

| Row | Scenario | Assertions |
|---|---|---|
| 5.12 | F1; all nine types, no `scale`, no `rscales`; JKn gets `rscales = rep(1, 20)` (required), Fay gets `rho = 0.3` | `expect_no_warning()` for each type |
| 5.13 | F1; for each of `"BRR"`, `"JK2"`, `"ACS"`, `"successive-difference"`: `scale = NULL, rscales = NULL` passed explicitly | `expect_no_warning()` for each type |

### Checks run before the discard

| Row | Scenario | Assertions |
|---|---|---|
| 5.14 | F1; `"JK2"`, `rscales = c(1, 1)` (length 2, not 20) | `expect_no_warning(expect_error(..., class = "surveycore_error_rscales_length"))` |
| 5.15 | F1; `"ACS"`, `rscales = c(NA_real_, rep(1, 19))` | `expect_no_warning(expect_error(..., class = "surveycore_error_rscales_na"))` |

### The JKn refusal

| Row | Scenario | Assertions |
|---|---|---|
| 5.16 | F1; `"JKn"`, no `rscales` | `expect_error(class = "surveycore_error_stratified_jk_rscales_unset")` and `expect_snapshot(error = TRUE, ...)` on the same call |
| 5.17 | F1; `"JKn"`, `rscales = NULL` passed explicitly | `expect_error(class = "surveycore_error_stratified_jk_rscales_unset")` |
| 5.18 | F1; `"JKn"`, no `rscales`, `rho = 0.3` | `expect_no_warning(expect_error(..., class = "surveycore_error_stratified_jk_rscales_unset"))` — the refusal fires before the `rho` warning |
| 5.19 | `F1[1, ]`; `"JKn"`, no `rscales` | `expect_error(class = "surveycore_error_single_row")` — the frame check fires first. (The empty-frame case for JKn is already pinned by `as_survey_replicate() refuses five frames before the scale switch`; confirm it still passes.) |
| 5.20 | F1; `"JKn"`, `rscales = rep(1, 20)` | Builds; `expect_no_condition()`; stored `scale` equals `1`, `tolerance = 1e-8` |

### JK2 with no `rscales`

| Row | Scenario | Assertions |
|---|---|---|
| 5.21 | F1; `"JK2"`, no `scale`, no `rscales` | `expect_no_condition()`; `expect_null(d@variables$rscales)`; stored `scale` equals `1`, `tolerance = 1e-8` |

### The `rho` warning and the new class

| Row | Scenario | Assertions |
|---|---|---|
| 5.22 | F1; for each of the eight non-Fay types, `rho = 0.3`; JKn gets `rscales = rep(1, 20)` | `expect_warning(class = "surveycore_warning_replicate_arg_ignored")` and, on a second call, `expect_warning(class = "surveycore_warning_rho_ignored")`; `expect_null(d@variables$rho)` |
| 5.23 | F1; `"BRR"`, `rho = 0.3`, `scale = 0.6` | `expect_snapshot(d <- as_survey_replicate(...))` shows two warnings, the `rho` warning first; `w <- testthat::capture_warnings(...)`, `expect_length(w, 2L)`; stored `scale` equals `1 / 20`, `tolerance = 1e-8`. The existing snapshot for the `rho` warning on BRR alone must not change |

### Edge frames

| Row | Scenario | Assertions |
|---|---|---|
| 5.24 | F3 (`R = 1`): `"BRR"` with `scale = 0.6`; `"ACS"` with `scale = 0.6`; `"successive-difference"` with `scale = 0.6`; `"JKn"` with `rscales = 1` | The three discarding calls warn with `surveycore_warning_replicate_arg_ignored` and store `1`, `4`, `4`, `tolerance = 1e-8`; the JKn call builds with `expect_no_condition()` and stores `1`, `tolerance = 1e-8` |
| 5.25 | F4 (all-`NA` outcome, `R = 8`): `"JK2"` with `scale = 0.6` | Warns with `surveycore_warning_replicate_arg_ignored`; stored `scale` equals `1`, `tolerance = 1e-8`; `expect_true(all(is.na(d@data$y1)))` |

### `as_survey_nonprob()` stays unchanged

| Row | Scenario | Assertions |
|---|---|---|
| 5.26 | The existing blocks `surveycore_error_stratified_jk_rscales_unset fires for JK2 with rscales = NULL` and `surveycore_error_stratified_jk_rscales_unset fires for JKn with rscales = NULL` | Pass with their snapshots byte-identical. No new block |

### Closed type sets, one row for all nine types

Row 5.27 pins every member and every non-member of the two discard sets in
one block. A type added to or dropped from either set turns this row red.

| Row | Scenario | Assertions |
|---|---|---|
| 5.27 | F1; for each of the nine types: `scale = 0.6` and `rscales = rep(0.5, 20)` in the same call; Fay also gets `rho = 0.3` | Per type, from the table below. "Warns" means `expect_warning(class = "surveycore_warning_replicate_arg_ignored")` with the result taken from its return value. "None" means `expect_no_warning()`. Stored `scale` with `tolerance = 1e-8`. Stored `rscales` with `expect_identical()` for `rep(0.5, 20)` and `expect_null()` for `NULL` |

| Type | Condition | Stored `scale` | Stored `rscales` |
|---|---|---|---|
| `"JK1"` | none | `0.6` | `rep(0.5, 20)` |
| `"JK2"` | warns | `1` | `NULL` |
| `"JKn"` | none | `0.6` | `rep(0.5, 20)` |
| `"BRR"` | warns | `1 / 20` | `rep(0.5, 20)` |
| `"Fay"` | none | `1 / (20 * (1 - 0.3)^2)` | `rep(0.5, 20)` |
| `"bootstrap"` | none | `0.6` | `rep(0.5, 20)` |
| `"ACS"` | warns | `4 / 20` | `NULL` |
| `"successive-difference"` | warns | `4 / 20` | `NULL` |
| `"other"` | none | `0.6` | `rep(0.5, 20)` |

### A discarded `scale` is never checked

| Row | Scenario | Assertions |
|---|---|---|
| 5.28 | F1; loop over the five supplied values `NA_real_`, `Inf`, `-1`, `0`, `rep(0.6, 20)`. For each value: (a) `"BRR"` with `scale = <value>`, and the same call with no `scale` (`d_plain`); (b) `"Fay"` with `rho = 0.3` and `scale = <value>` | (a) `expect_warning(class = "surveycore_warning_replicate_arg_ignored")`, result taken from its return value; no error; stored `scale` equals `1 / 20`, `tolerance = 1e-8`; `expect_identical(d@variables, d_plain@variables)`. (b) `expect_no_condition()`; stored `scale` equals `1 / (20 * (1 - 0.3)^2)`, `tolerance = 1e-8` |

---

## 6. Oracle blocks — `tests/testthat/test-variance-replicate.R`

Every block: `skip_if_not_installed("survey")` inside the block; F1; both
sides built from the same frame, weight column, replicate columns, `type`,
and `mse = TRUE`. Estimates come from `get_means(sc, y1, variance = c("se",
"ci"))` and `survey::svymean(~y1, sv, na.rm = TRUE)`. Each block asserts:

- the point estimate, `tolerance = 1e-10`;
- the standard error, `tolerance = 1e-8`;
- `ci_low` and `ci_high` against `confint(sv_mean)`, `tolerance = 1e-6`;
- surveycore's stored `scale` against a literal, `tolerance = 1e-8`;
- `sv$scale` against a literal, `tolerance = 1e-8`.

Both sides use the normal interval today, so the bound assertions hold.

### A supplied scale is kept by both packages

| Row | Type | Both sides get | Expected conditions | `scale` literal, both sides | Extra assertion |
|---|---|---|---|---|---|
| 6.1 | `"JK1"` | `scale = 0.6` | none on either side (`expect_no_warning()` round each constructor) | `0.6` | SE at `0.6` divided by the SE of a surveycore design built with no `scale` equals `sqrt(0.6 / (19 / 20))`, `tolerance = 1e-8` |
| 6.2 | `"JKn"` | `scale = 0.6`, `rscales = rep(1, 20)` written as a literal on each side | none on either side | `0.6` | ratio to the default design (`rscales = rep(1, 20)`, no `scale`) equals `sqrt(0.6 / 1)`, `tolerance = 1e-8` |
| 6.3 | `"bootstrap"` | `scale = 0.6` | none on either side | `0.6` | ratio equals `sqrt(0.6 / (1 / 19))`, `tolerance = 1e-8` |
| 6.4 | `"other"` | `scale = 0.6`, no `rscales` | surveycore: none. `survey`: `w <- testthat::capture_warnings(sv <- survey::svrepdesign(...))`, `expect_length(w, 1L)`, `expect_match(w, "scale or rscales not specified, set to 1", fixed = TRUE)` | `0.6` | ratio equals `sqrt(0.6 / 1)`, `tolerance = 1e-8` |

### A supplied scale is discarded by both packages

Before this work these five rows disagreed: surveycore used `0.6` and `survey`
did not.

| Row | Type | Both sides get | surveycore condition | `survey` condition | `scale` literal, both sides |
|---|---|---|---|---|---|
| 6.5 | `"BRR"` | `scale = 0.6` | `expect_warning(class = "surveycore_warning_replicate_arg_ignored")` | exactly one warning, text `type='BRR' does not use 'scale=' argument` | `1 / 20` |
| 6.6 | `"Fay"` | `scale = 0.6`, `rho = 0.3` | none (`expect_no_warning()`) | none (`expect_no_warning()`) | `1 / (20 * (1 - 0.3)^2)` |
| 6.7 | `"JK2"` | `scale = 0.6` | `expect_warning(class = "surveycore_warning_replicate_arg_ignored")` | exactly one warning, text `with type JK2 scale= and rscales= are not needed and will be ignored` | `1` |
| 6.8 | `"ACS"` | `scale = 0.6` | `expect_warning(class = "surveycore_warning_replicate_arg_ignored")` | exactly one warning, text `with type ACS scale= and rscales= are not needed and will be ignored` | `4 / 20` |
| 6.9 | `"successive-difference"` | `scale = 0.6` | `expect_warning(class = "surveycore_warning_replicate_arg_ignored")` | exactly one warning, text `with type successive-difference scale= and rscales= are not needed and will be ignored` | `4 / 20` |

"Exactly one warning" means `testthat::capture_warnings()` round the `survey`
call, then `expect_length(w, 1L)` and `expect_match(w, <text>, fixed =
TRUE)`. A fragment match alone passes when a second, unexpected warning fires,
such as `survey`'s "Data do not look like combined weights", which means the
fixture moved.

### `survey` refuses JKn without `rscales`

| Row | Scenario | Assertions |
|---|---|---|
| 6.10 | F1; `survey::svrepdesign(type = "JKn", mse = TRUE, ...)` with no `rscales` | `expect_error(..., "Must provide rscales for combined JKn weights", fixed = TRUE)`. This guards the reason surveycore refuses the same input; a failure means `survey` changed |

Do not use `testthat::expect_failure()` in this file.

---

## 7. `as_svydesign()` — `tests/testthat/test-conversion.R`

`skip_if_not_installed("survey")` inside each block.

| Row | Scenario | Assertions |
|---|---|---|
| 7.1 | F2; all nine types built by `as_survey_replicate()` with `scale = 0.6`; JKn also gets `rscales = rep(1, 5)`; Fay also gets `rho = 0.3`. Convert each with `as_svydesign()` | The constructor warns with `surveycore_warning_replicate_arg_ignored` for `"BRR"`, `"JK2"`, `"ACS"`, `"successive-difference"`, and raises nothing for the other five. `survey::svymean(~y1, sv)` on the converted object against `get_means(d, y1, variance = "se")`: estimate `tolerance = 1e-10`, SE `tolerance = 1e-8`. `sv$scale` equals `0.6` for `"JK1"`, `"JKn"`, `"bootstrap"`, `"other"`; `1 / 5` for `"BRR"`; `1 / (5 * (1 - 0.3)^2)` for `"Fay"`; `1` for `"JK2"`; `4 / 5` for `"ACS"` and `"successive-difference"`; each `tolerance = 1e-8`. Conditions from `as_svydesign()`: for `"JK2"`, exactly one warning, text `with type JK2 scale= and rscales= are not needed and will be ignored`; for `"other"`, exactly one warning, text `scale or rscales not specified, set to 1`; for the other seven, `expect_no_warning()` |
| 7.2 | F2; for each of `"ACS"` and `"successive-difference"`: `src <- survey::svrepdesign(weights = df$wt, repweights = df[, repwt_cols], type = <type>, mse = TRUE, data = df)`; `d <- from_svydesign(src)`; `sv <- as_svydesign(d)` | `expect_no_warning()` on building `src`; `expect_identical(d@variables$rscales, rep(1, 5))` (the imported design stores an `rscales`); `expect_no_warning(sv <- as_svydesign(d))`; SE of `survey::svymean(~y1, sv)` equals SE of `survey::svymean(~y1, src)`, `tolerance = 1e-8`. Before this work the conversion raised the `not needed` warning |
| 7.3 | F2; `"JK2"` built with no `scale` and no `rscales`; convert | The constructor raises nothing; `as_svydesign()` raises exactly one warning, text `with type JK2 scale= and rscales= are not needed and will be ignored`; SE parity with `get_means()`, `tolerance = 1e-8` |
| 7.4 | F2; `"BRR"`: `src <- survey::svrepdesign(weights = df$wt, repweights = df[, repwt_cols], type = "BRR", mse = TRUE, data = df)`; `d <- from_svydesign(src)`; `sv <- as_svydesign(d)` | `expect_no_warning()` on building `src`; `d@variables$scale` equals `1 / 5`, `tolerance = 1e-8` (the imported design stores a non-`NULL` scale); `expect_no_warning(sv <- as_svydesign(d))` — a passed `scale` would raise `type='BRR' does not use 'scale=' argument`; SE of `survey::svymean(~y1, sv)` equals SE of `survey::svymean(~y1, src)`, `tolerance = 1e-8` |

Rows 7.2 and 7.4 pin the export side of the two discard sets for `"BRR"`,
`"ACS"` and `"successive-difference"`: each would make `survey` warn if the
stored value were passed. For `"Fay"` and `"JK2"`, no public result tells a
passed value from a withheld one, because `survey` discards a Fay `scale`
with no warning and warns on every JK2 call. Rows 7.1 and 7.3 still pin their
standard errors.

If `expect_identical()` in row 7.2 fails because `survey` stores `rscales` as a
different numeric type, use `expect_equal(..., tolerance = 1e-10)` and record
the reason in the block comment.

---

## 8. Existing blocks that must change (closed list)

T1 to T11 break under the new behaviour. T12 stays green but carries a stale
comment. Confirm each one is changed as described and passes, and that no
assertion in it was removed except in T4.

`tests/testthat/test-constructors.R` — each builds `type = "JKn"` with no
`rscales`, which is now refused:

| # | Block title | Expected change |
|---|---|---|
| T1 | `as_survey_replicate() JKn and bootstrap defaults rise by R/(R-1)` | JKn call gains `rscales = rep(1, n_rep)` |
| T2 | `as_survey_replicate() scale at one and two replicate columns` | the one-column JKn call gains `rscales = 1` |
| T3 | `as_survey_replicate() stores an explicit scale verbatim` | JKn call gains `rscales = rep(1, n_rep)` |
| T4 | `as_survey_replicate() JKn with rscales = NULL stores scale = 1` | deleted; rows 5.16 and 5.17 replace it |
| T5 | `as_survey_replicate() stores both changed defaults on a two-row frame` | JKn call gains `rscales = rep(1, 20)` |
| T6 | `as_survey_replicate() stores the default scale of all nine types, Fay with rho` | JKn line gains `rscales = rep(1, 20)` |
| T7 | `as_survey_replicate() warns and discards rho for the eight other types` | JKn gets `rscales = rep(1, 20)` in both loop calls |
| T8 | `as_survey_replicate() stores the rho key for every type` | JKn gets `rscales = rep(1, 20)` |
| T9 | `as_survey_replicate() raises no warning for the eight other types with no rho` | JKn gets `rscales = rep(1, 20)` |
| T10 | `as_survey_twophase() refuses a replicate phase-1 of all nine types` | JKn gets `rscales = rep(1, 5)` (that frame has 5 replicate columns) |

`tests/testthat/test-conversion.R`:

| # | Block title | Expected change |
|---|---|---|
| T11 | `every accepted replicate type crosses both conversion routes` | `rscales` passed for `"JKn"` only, no longer for `"JK2"`; the block raises no unasserted surveycore warning; the comment above the block no longer names an ACS `survey` warning |
| T12 | `as_svydesign() warns and converts for every replicate type carrying an FPC` | Comment only: it no longer says `survey` warns for "the types that ignore a scale", and says that only JK2 makes `survey` warn about ignored arguments. No assertion and no call changes; the block passes as before |

No existing block other than T1 to T12 changes, and every existing snapshot
stays unchanged. The only snapshot changes allowed are new entries for rows
5.6, 5.7, 5.8, 5.16 and 5.23.

---

## 9. Documentation checks

| Row | Check |
|---|---|
| 9.1 | `plans/error-messages.md` has a section `replicate-supplied-args rows (2026-10-01)` with rows RS-1 (`surveycore_warning_replicate_arg_ignored`), RS-2 and RS-3 (`surveycore_error_stratified_jk_rscales_unset`), and a note that FR-3 now carries both classes |
| 9.2 | `man/as_survey_replicate.Rd` names `surveycore_warning_replicate_arg_ignored`; states that JKn requires `rscales`; states the no-warning-when-nothing-supplied divergence from `survey` for JK2; no longer contains the phrase `leaves no jackknife factor` |
| 9.3 | `man/as_survey_nonprob.Rd` states that `as_survey_replicate()` accepts JK2 with no `rscales` and that `as_survey_nonprob()` keeps the refusal |
| 9.4 | `NEWS.md` development section has two Breaking-changes entries citing #255 (one also #244) and one Bug-fixes entry for `as_svydesign()` citing #255. The JKn entry (the one citing #244) carries an action clause that tells the caller to pass `rscales` with one entry per replicate column, and gives `(n_h - 1) / n_h` as the example value |
| 9.5 | `devtools::document()` produces no diff |

---

## 10. Invariants and input modes

- `test_invariants()` runs once per constructor per test file. Each of the
  three files already calls it for `as_survey_replicate()` in an earlier
  block. New blocks add no call.
- Input modes: not applicable. `as_survey_replicate()` takes a data frame only,
  and `as_svydesign()` takes a design only.

## 11. Tolerances

- Point estimates: `1e-10`
- SE / variance, and every stored or `survey` scale: `1e-8`
- CI bounds: `1e-6`
- SE ratios (rows 6.1 to 6.4): `1e-8`, the SE tolerance, because the ratio is a
  quotient of two standard errors
- Deviations: none. Every numeric `expect_equal()` names its `tolerance =`
  explicitly; none relies on the testthat default.

## 12. Profile gates

- [ ] devtools::document() clean
- [ ] devtools::test() all pass
- [ ] devtools::run_examples() all pass
- [ ] R CMD check --as-cran (0 err, 0 warn, notes reviewed)
- [ ] pkgdown::build_site() clean
- [ ] covr::package_coverage() ≥ 95% (target 98%)
- [ ] CRAN cookbook scan clean (see r-package-profile.md)

Reading the gates in this repository:

- "All pass" includes "no new warning". `develop` carries 256 pre-existing
  AAPOR small-cell warnings; the full suite must still report 256.
- Measure coverage with `NOT_CRAN=true`.
- For `R CMD check`, read the `Status:` line. A run with no `Status:` line
  died and is not a pass. The pre-existing `.git` hidden-file note is not
  caused by this work.
- `air format --check` passes on every R file the PR touches.
