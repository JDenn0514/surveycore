# Spec — as-svydesign-bridge

**Status**: DRAFT, methodology-locked
**Revision**: 1.3 — narrowed to issue #237, 2026-09-09, per decision D-9. The
issue #198 half of this work left for the `svydesign-replicate-bridge` arc.
Revision 1.2 resolved twenty-four spec-review findings; every one that survives
the narrowing is kept below.
**Target version**: 1.1.0.9000
**PR range**: PR 1. One PR. See §Budget.
**Date**: 2026-09-09

## Document purpose

This document is the source of truth for the behaviour of `as_svydesign()` and
`as_tbl_svy()` after this change. It fixes one defect, issue #237: both
functions refuse a `survey_nonprob` design, with a message saying the object is
not a survey design. Build from this document alone.

Four decisions are settled. Do not re-open them.

- **D-2.** The plain-shape nonprob path raises a new conversion-specific
  warning class.
- **D-3.** The degrees-of-freedom difference goes in the roxygen only.
- **D-6.** The dropped domain restriction is documented here and fixed in
  issue #245. No code change.
- **D-9.** This work ships issue #237 only. Issue #198, the replicate finite
  population correction, ships as PR 4 of the `svydesign-replicate-bridge` arc,
  on branch `fix/svydesign-replicate-fpc`. §Out records what moved and where.

Measured figures below cite `measurements.md` R1 to R13. Those are console runs
from 2026-09-08 on this worktree, R 4.6.1, survey 4.5, srvyr 1.3.1.

### Where a declined review request is recorded

Two review requests that touch this document were declined. Each reason sits
where a reader would otherwise ask for it, and not in a list of its own:

| Request | Where the reason sits |
|---|---|
| Prefix CN-3's first bullet to mark it as a repeat | §CN-3, third paragraph |
| Shorten the new `@section` titles | §New roxygen sections, second note |

### Where an issue number may appear

No user-facing roxygen block in the package cites a GitHub issue number. A
search of `R/*.R` for a roxygen line holding a two-digit or longer `#` number
returns nothing. This change keeps that convention: **no roxygen block below
carries an issue number.** The facts each issue covers stay in the roxygen; the
tracker numbers do not. The issues this document cites are #237, #242, #243,
#244, #245, #246, #248 and #251.

The numbers appear in two places instead: the changelog fragment and this
document. No vignette in the package cites an issue number either, so the
vignette passage below carries none.

---

## Scope

### In

| Item | Change |
|---|---|
| `as_svydesign()` dispatch chain | Add a fourth branch for `survey_nonprob`, before the existing `else` |
| One new warning class | For the plain-shape nonprob conversion |
| `plans/error-messages.md` | Two rows: one for the existing refusal class, one for the new warning class |
| Roxygen | `as_svydesign()` and `as_tbl_svy()` |
| `vignettes/surveycore-vs-survey.Rmd` | One new subsection in §5 and one new row in the §5 table |

### Out

State each of these as out of scope. Do not touch them.

- **The replicate finite population correction, and everything built for it.**
  D-9. `.as_svydesign_replicate()` keeps its `fpc` and `fpctype` arguments in
  this change. The drop and its warning ship as PR 4 of the
  `svydesign-replicate-bridge` arc, on branch `fix/svydesign-replicate-fpc`,
  under register row **CB-3**, class `surveycore_warning_replicate_fpc_dropped`.
  Two documentation corrections that describe that warning left with it, into
  issue **#251**: the `@param fpc` and `@param fpctype` blocks of
  `as_survey_replicate()`, and the FPC line of `print(x, full = TRUE)` and
  `summary(x)` for a `survey_replicate` design. Both state that the field
  adjusts a variance, which no surveycore code does. Both must wait for the
  warning they describe, or the package would carry a claim its code does not
  support. `type = "Fay"`'s missing `rho`, issue **#243**, moved to that arc's
  PR 5 as well. Change no line for any of it.
- **The three replicate scale defaults.** `as_survey_replicate()` keeps its
  current `scale` for `JK2`, its current handling of `type = "Fay"` and its
  current `rscales` default for `JKn`. Issues #242 and #244 carry two of those
  fixes, and the other arc's PR 5 carries #243. Change no line of the `scale`
  switch at
  `R/core-constructors.R:791-807`. The nonprob route is not exposed to any of
  the three: `as_survey_nonprob()` sets `JK2`'s `scale` to 1, which is the value
  the `survey` package uses, so the two agree (R6); and it refuses a stratified
  jackknife that names no `rscales` with
  `surveycore_error_stratified_jk_rscales_unset` (R8), so no nonprob design can
  reach survey's `JKn` refusal.
- **`combined.weights`.** The bridge does not pass it and still does not pass
  it. The argument reaches the nonprob replicate route as well, because
  `surveywts::create_bootstrap_weights()` is the producer CN-3 sends a caller
  to. Issue #198 measured the effect and assigned it to that producer package,
  `JDenn0514/surveywts#101`: a producer that hands over replication factors
  rather than finished weights gets a standard error of 0.279983 against the
  correct 0.428678 (M3). Nothing in this change alters the argument.
- **`.as_svydesign_taylor()`.** No change of any kind. Branch 4b calls it as it
  stands.
- **`.as_svydesign_replicate()`.** No change of any kind. Branch 4a calls it as
  it stands, and needs none: a `survey_nonprob` design carries `fpc` `NULL` in
  both shapes and carries no `fpctype` key at all (R3), and the helper already
  defaults a missing `fpctype` to `"fraction"`
  (the helper reads the key and tolerates its absence; PR #249 rewrote that
  region, so cite the behaviour and not a line).
- **The reverse direction.** `from_svydesign()`, `from_tbl_svy()` and the three
  `.from_svydesign_*()` helpers do not change. Neither can produce a
  `survey_nonprob`, so their `@return` lines stay as they are.
- **The dropped domain restriction.** D-6. `as_svydesign()` converts the full
  stored sample on all four routes, and a filtered design's domain column
  crosses as ordinary data. Issue #245 carries the fix. This change documents
  the behaviour and alters no code.
- **`survey_collection`.** It does not inherit `survey_base`, so it reaches the
  `else` branch and gets the refusal error. That is the current behaviour and it
  stays.
- **The degrees-of-freedom difference itself.** No code reads or writes `degf`.
  The difference is documented, not changed.
- **Consolidating the eighth copy of the nonprob routing test.** The new branch
  writes `!is.null(x@variables$repweights)` in full, which is an eighth
  in-place copy of that predicate inside a `survey_nonprob` branch, and the
  CN-3 warning's first bullet is an eighth independent copy of the
  `surveycore_warning_nonprob_srs_fallback` first bullet. Both stay inline.
  Issue **#246** carries the consolidation. See §The eighth copy for the
  reasoning and the count.

### Class support matrix

| Input class | Supported before | Supported after |
|---|---|---|
| `survey_taylor` | yes | yes, unchanged |
| `survey_replicate`, no FPC named | yes | yes, unchanged |
| `survey_replicate`, FPC named | no, `survey` raises `fpc is wrong length` (M2) | no, unchanged here. The other arc's PR 4 fixes it. |
| `survey_nonprob`, replicate shape | no, surveycore refused | yes |
| `survey_nonprob`, plain shape | no, surveycore refused | yes, with a warning |
| `survey_twophase` | yes | yes, unchanged |
| anything else | refused | refused, unchanged |

---

## Architecture

### Files touched — eight

Eight rows, eight files. The figure moved three times, and every move is
recorded so a reader can check the arithmetic:

| Draft | Count | What moved it |
|---|--:|---|
| first draft | 8 | a miscount against a nine-row table |
| Stage 2r | 9 | the miscount corrected |
| Stage 3r | 13 | D-7 added `R/methods-print.R` and two test files; SR-6 added the vignette |
| this revision | 8 | D-9 removed the replicate FPC. Five files left with it: `R/core-constructors.R`, `R/methods-print.R`, `tests/testthat/test-methods-print.R`, `tests/testthat/_snaps/methods-print.md` and `man/as_survey_replicate.Rd` |

| File | What changes |
|---|---|
| `R/methods-conversion.R` | The `as_svydesign()` dispatch chain gains a `survey_nonprob` branch with the D-2 warning. Roxygen changes in the `as_svydesign()` block and the `as_tbl_svy()` block, including three new `@section` blocks. |
| `plans/error-messages.md` | Two new rows in a new dated subsection, plus one line in the Coverage Map. |
| `vignettes/surveycore-vs-survey.Rmd` | SR-6. One new row in the §5 table and one new subsection, §5.1, after it. The subsection holds the material trimmed out of the roxygen: the two degrees-of-freedom counting rules. One new code chunk, guarded with `eval=has_survey`. See §The vignette passage. |
| `tests/testthat/test-conversion.R` | New test blocks. |
| `tests/testthat/_snaps/conversion.md` | **Appended.** This file exists and holds 84 lines in 8 blocks at base `40700e3`, all `from_svydesign()` and `as_svydesign()` snapshots from the replicate-bridge arc. Two earlier revisions of this spec recorded first that it did not exist, then that it held 41 lines; both were true of an older base. Read it before writing. The new rows append and change no existing block. |
| `changelog/fix-as-svydesign-bridge.md` | **New file.** The repo keeps one changelog fragment per arc in `changelog/`. This work writes the fragment and no `NEWS.md` entry, by the user's instruction of 2026-09-09 (D-10). Base `40700e3` is the commit that backfilled two of them, and the neighbouring arc wrote `changelog/fix-svydesign-replicate-bridge.md` for its five PRs. Read that file for the shape: a header naming the branches, status, date, PRs and issues, then Summary, Changes, Files Modified and Verification. **Do not follow `.claude/skills/changelog-workflow.md`.** It is stale on both counts: it gives the path as `changelog/phase-{X}/{branch-name}.md`, and the last three arcs wrote flat files at `changelog/{slug}.md`; and its four-heading format is thinner than the one those arcs used. Its §Validation rules still apply as a floor: the file exists, is not a stub, and its Changes and Files Modified sections each carry at least one entry. An earlier revision of this spec listed no such file, which was an omission. |
| `man/as_svydesign.Rd` | Regenerated by `devtools::document()`. |
| `man/as_tbl_svy.Rd` | Regenerated by `devtools::document()`. |

The two `man/` filenames are verified against the working tree. No other
`man/` page changes.

`plans/error-messages.md` is the one file the other arc's PR 4 also writes. The
two edits do not overlap in text: PR 4 fills the reserved row CB-3 inside the
existing `### svydesign-replicate-bridge rows (2026-09-04)` subsection, and this
change appends a new subsection of its own after it. Whichever lands second
rebases on one added block.

### Functions added

None.

### Functions modified

```r
as_svydesign(x)                  # dispatch chain gains a fourth branch
as_tbl_svy(x)                    # roxygen only; no logic change
```

No signature changes. No exports added or removed. No `DESCRIPTION` change. No
S7 method changes.

### Class changes

None.

---

## Budget

| Figure | Value |
|---|--:|
| Test-spec rows in this PR | 18 |
| The bound in `artifact-schemas.md` §PR budget | 12 |

18 rows against a bound of 12. The PR is one PR and it is not split.

**D-8's original reason no longer applies.** It read: two issues rewrite the
same dispatch chain, so two concurrent PRs would share one source file. D-9 took
the second issue out, so the shared-file argument is gone. The instruction
stands on its own. The user instructed one PR twice: at the request, and again
when the orchestrator put the overage to them with the calibration behind the
bound. The overage is recorded here rather than hidden. The budget ledger,
`plans/pr-budget-calibration.md`, records the real diff after the merge; that
entry is not part of this PR's write surface.

---

## Function contracts

### `as_svydesign(x)`

- **Signature**: `as_svydesign(x)`
- **Arguments**: `x` — a survey design object. Any class that inherits
  `survey_base`. There is no default; `x` is required.
- **Returns**: a `survey` package design object. The class depends on the input
  class, and for `survey_nonprob` on the design's shape.

#### Dispatch table

The branches run in this order. Each row states the test, the internal route,
the returned class, and the condition raised.

| # | Test | Route | Returns | Condition |
|---|---|---|---|---|
| 1 | `S7::S7_inherits(x, survey_taylor)` | `.as_svydesign_taylor(x)` | `survey.design2` | none |
| 2 | `S7::S7_inherits(x, survey_replicate)` | `.as_svydesign_replicate(x)` | `svyrep.design` | none in this change |
| 3 | `S7::S7_inherits(x, survey_twophase)` | `.as_svydesign_twophase(x)` | `twophase2` | none |
| 4a | `S7::S7_inherits(x, survey_nonprob)` and `!is.null(x@variables$repweights)` | `.as_svydesign_replicate(x)` | `svyrep.design` | none |
| 4b | `S7::S7_inherits(x, survey_nonprob)` and `is.null(x@variables$repweights)` | `.as_svydesign_taylor(x)` | CN-3, then `survey.design2` | CN-3 |
| 5 | anything else | none | none | CN-1, an error |

Branch 4 is new. It goes after branch 3 and before branch 5. Rows 1, 2 and 3
are today's behaviour and this change alters none of them. Row 2 gains a
warning in another change; see §Out.

The routing key is `!is.null(x@variables$repweights)`. It is the same key that
`.mean_cell()` uses at `R/analysis-means-helpers.R:351-353` to pick the
estimator for a `survey_nonprob` design. Use that key and no other. Measured
(R3): routing on this key reproduces surveycore's own standard error in both
shapes, 0.0200827192 for the replicate shape and 0.5630671378 for the plain
shape. Sending the replicate shape through the Taylor route answers
0.5630671378, which is 28 times too large on that design.

The CN-3 warning fires in branch 4b, before the call to
`.as_svydesign_taylor()`.

#### Why the nonprob branch needs two routes and not one

`.as_svydesign_replicate()` cannot serve the plain shape. On a plain-shape
design it passes a zero-column frame as `repweights`. survey then computes
`mean(apply(repweights, 2, mean))`, which is `NaN`, and its
`combined.weights` guard evaluates `if (NA)`. The result is
a typed `surveycore_error_repweights_empty`, measured in R14. Each helper
serves only the shape it is built for.

#### The eighth copy

Two duplications ship with this branch, and both are deliberate.

1. **The routing predicate.** Seven sites in `R/` already write
   `!is.null(design@variables$repweights)` in full inside a `survey_nonprob`
   branch. The new branch is the eighth.
2. **The warning's first bullet.** All seven sites raise the
   `surveycore_warning_nonprob_srs_fallback` first bullet as an independent
   `paste0()` literal. CN-3's first bullet is the eighth copy of that text.

Both counts are verified in the working tree at base `40700e3`: a search of
`R/` for `surveycore_warning_nonprob_srs_fallback` returns exactly seven sites,
in `analysis-corr-helpers.R`, `analysis-covariance-helpers.R`,
`analysis-freqs-helpers.R`, `analysis-means-helpers.R`,
`analysis-totals-helpers.R`, `analysis-variance-helpers.R` and `glm.R`, and each
one carries the predicate.

Keep both inline. Write no helper. Reasons:

- A one-line predicate with a single call site in this PR is the premature
  abstraction that `.claude/rules/engineering-preferences.md` item 3 warns
  against.
- Extracting for one site while seven keep the inline form reads as
  consolidation without being it. The same argument rules out extracting the
  message text for one site.

Issue **#246** carries the consolidation of all eight. The debt is written down
here rather than left silent.

Note on where a shared helper would go, when #246 lands.
`.claude/rules/code-style.md` names the shared-helper file `R/07-utils.R`. That
file does not exist. The real path is `R/utils.R`. The same rule file names
`04-methods-print.R`, `00-s7-classes.R` and `05-methods-conversion.R`; the real
files are `R/methods-print.R`, `R/core-classes.R` and
`R/methods-conversion.R`. Cite the real paths. See §Rule documents that lag the
code.

#### Errors

| Class | Register row | Trigger |
|---|---|---|
| `surveycore_error_pkg_not_installed` | existing | `survey` is not installed. Unchanged. |
| `surveycore_error_not_survey_object` | CN-1 | `x` inherits none of the four design classes. |

#### Warnings

| Class | Register row | Trigger |
|---|---|---|
| `surveycore_warning_nonprob_srs_conversion` | CN-3 | `x` is a `survey_nonprob` design and `x@variables$repweights` is `NULL`. |

The warning does not stop the conversion. It fires once per call.

#### Edge cases

| Case | Behaviour |
|---|---|
| Empty input, zero rows | No constructor produces one. `.validate_data()` rejects a zero-row frame with `surveycore_error_empty_data` (`R/core-validators.R:77-80`). No S7 class validator re-checks the row count, so a later `@data` assignment is not blocked; `R/core-classes.R` holds no `nrow()` call at all. `as_svydesign()` adds no check. See §The row-count loophole. |
| Single-row input | No constructor produces one. `.validate_data()` rejects a one-row frame with `surveycore_error_single_row` (`R/core-validators.R:100-109`). The same assignment loophole applies. `as_svydesign()` adds no check. |
| All-NA outcome column | No effect. `as_svydesign()` reads no outcome column. It passes `@data` whole and the `survey` object holds the same `NA` values. |
| Single-level grouping | No effect. `as_svydesign()` has no grouping argument and reads no group state. |
| Zero-weight rows | Reachable on a `survey_nonprob` design, and only there. Converts on both shapes, with no new guard. See §A zero-weight row below the table. |
| Degenerate strata | Not reachable on the path this change touches. A `survey_nonprob` design holds `strata` `NULL` in both shapes. |
| A `select()`-narrowed design | Converts with every original column present. `as_svydesign()` reads no `visible_vars` key on any route, so the whole stored frame crosses. `surveytidy`'s `select()` is the only writer of that key; every surveycore constructor sets it to `NULL` (`R/core-constructors.R:553`, `:820`, `:1144`, `:1622`, `:1658`). `print()` honours the key (`R/methods-print.R:20-35`) and `dim()` does not, and `R/methods-compat.R:50-51` documents that choice for `dim()`. The conversion follows `dim()`. Add no code for it. |
| A zero-length `repweights` vector | Not constructible on either class that carries the key. `as_survey_replicate()` refuses a zero-column selection with `surveycore_error_repweights_empty` (`R/core-constructors.R:758-761`). `as_survey_nonprob()` refuses zero columns with the same class (`:1441-1444`) and one column with `surveycore_error_repweights_single` (`:1449-1458`), so its minimum is two. No later route can empty the key either: `update_design()` refuses a `survey_nonprob` design outright with `surveycore_error_unsupported_class` (`R/update-design.R:227-236`). So branch 4a always receives at least two columns through every supported route, and `character(0)` needs no guard. One qualifier, the same one §The row-count loophole records: a direct write into `@variables` runs no such check. Nothing measured that route, and this change adds no guard for it. |
| The `@calibration` and `@reference_sample` fields of a nonprob design | Dropped. Neither route reads either property, so both are lost on the way out, not only on the way back. See §What the forward leg drops below the table. |
| A domain-marked (filtered) design | Converts, and the returned object answers for the full stored sample. `filter()` from `surveytidy` keeps every row and marks membership in the logical column `SURVEYCORE_DOMAIN_COL`, `"..surveycore_domain.."` (`R/utils.R:344`). That column crosses as ordinary data and is never installed as the converted object's own restriction. Measured (R10) on a design filtered to `y1 > 50`: surveycore's `get_means()` gives mean 58.176655 and SE 0.725342; `survey::svymean()` on the converted object gives mean 50.761561 and SE 0.614837; `subset()` on the converted object, on the domain column, recovers 58.176655 and 0.725342 exactly. The point estimate differs, not only the standard error. Pre-existing, and it reaches all four routes. Per D-6 this change adds no code for it. Issue #245 carries the fix. Roxygen section 3 documents it. |
| A nonprob design's absent `fpctype` key | No effect, and no code for it. Measured (R3): both nonprob shapes carry `fpc` `NULL`, and neither carries an `fpctype` key at all. `.as_svydesign_replicate()` tolerates the absent key and passes no FPC when `fpc` is `NULL`, so survey's FPC block is skipped on branch 4a. Measured on base `40700e3` (R14): the nonprob replicate shape converts to a `svyrep.design` with all eight replicate columns and raises no FPC warning. PR #249 rewrote that region of the helper, so this cites the behaviour and not a line. |
| A `survey_nonprob` design with an FPC | Not reachable. Both nonprob branches of `as_survey_nonprob()` set `fpc` to `NULL` unconditionally (`R/core-constructors.R:1620` and `:1656`). Add no special case for it. |
| A `survey_nonprob` design with exactly two replicate columns | Converts by branch 4a. Two is the constructor's minimum; `surveycore_error_repweights_single` rejects one. |
| `x` is a `survey_collection` | Branch 5. It does not inherit `survey_base`. |

#### A zero-weight row

A zero-weight row reaches `as_svydesign()` on a `survey_nonprob` design. It
cannot reach it on a `survey_taylor` or a `survey_replicate` design. The
asymmetry lives in the S7 validators, and only the assignment path reaches
them. Measured (R12), on a 40-row frame with one weight set to 0:

| Action | `survey_taylor` | `survey_nonprob` |
|---|---|---|
| Construct with a zero weight | blocked | blocked |
| Write the frame back into `@data` after construction | blocked | **accepted** |

Every constructor blocks the case, because `.validate_weights()`
(`R/core-validators.R:170-184`) rejects any non-positive weight with
`surveycore_error_weights_nonpositive`. The validators differ:

- `survey_taylor` repeats the strict check at `R/core-classes.R:487-496`, and
  `survey_replicate` carries its own copy at `:688-697`. Both raise
  `surveycore_error_weights_nonpositive` for `wt_col <= 0`, so an assignment is
  blocked too.
- `survey_nonprob` checks two weaker conditions. Condition 4a rejects a
  negative weight (`surveycore_error_weights_negative`,
  `R/core-classes.R:1265-1279`). Condition 4b rejects a column with no positive
  value at all (`surveycore_error_weights_all_zero`, `:1283-1296`). A single
  zero passes both, and condition 4a's own message says "All non-NA weights
  must be non-negative (>= 0)". `plans/error-messages.md` row 33 records the
  permissiveness as deliberate.

The correction history matters here, so a later reader does not re-open it. An
earlier draft called the case unreachable on every class and cited
`R/core-classes.R:688` as the `survey_nonprob` check. That line lies inside the
`survey_replicate` validator, which begins at `:631`. R12 measured the real
reachability and reversed the earlier finding.

What the conversion then does (R12), same frame, one zero weight:

| Shape | Converts to | `survey::degf()` | `svymean()` SE | surveycore's own SE |
|---|---|--:|--:|--:|
| plain | `survey.design2` | 38 | 0.5296146428 | 0.5296146428 |
| replicate | `svyrep.design` | 7 | 0.2422736303 | 0.2422736303 |

Both shapes convert, and the standard errors still agree exactly. The
zero-weight row costs the bridge nothing. **Add no guard for it.** One
consequence reaches the documentation: `survey::degf()` gives 38 where `n - 1`
is 39, because `survey` drops a zero-weight row on the Taylor path. Roxygen
section 2 carries that qualifier.

#### The row-count loophole

R12's finding generalises, and the two row-count edge cases above were reworded
because of it. The pattern is that a class validator can be weaker than the
constructor that feeds it, and a write into `@data` after construction runs only
the validator.

For the weight sign, the gap is one class wide: `survey_taylor` and
`survey_replicate` repeat the strict check, `survey_nonprob` does not (R12).

For the row count, `R/core-classes.R` holds no `nrow()` or `NROW()` call
anywhere, so no validator on any class repeats the row-count guard. The
constructors refuse both frames, at `R/core-validators.R:77-80` and
`:100-109`.

R13 measured the route. It does not behave uniformly:

| Frame written into `@data` after construction | `survey_taylor` | `survey_nonprob` |
|---|---|---|
| one row | accepted | accepted |
| zero rows | accepted | blocked, for an unrelated reason |
| one zero weight (R12) | blocked | accepted |

The single block in the zero-row nonprob cell is incidental, not a row-count
check: a zero-row weight column holds no positive value, so condition 4b fires
there.

What a one-row design then does on the bridge (R13):

```
nrow(@data) after the write: 1
the Taylor route:            Error: Design has only one primary sampling unit
```

That is a bare message from the oracle package with no surveycore class on it,
reached through the row count rather than through any argument this change
touches.

**This change adds no guard.** A design in this state is malformed before
`as_svydesign()` sees it, so the fix belongs in the class validators. Issue
**#248** holds the root cause and carries R13's table. The earlier wording,
"not reachable", is replaced above with what the measurement supports. Do not
restore it.

#### What the forward leg drops

`as_svydesign()` drops a nonprob design's `@calibration` and
`@reference_sample` fields. Neither `.as_svydesign_taylor()` nor
`.as_svydesign_replicate()` reads either property; both read `@data` and
`@variables` only. `survey_nonprob` declares the two properties at
`R/core-classes.R:1200` and `:1203`.

The loss is therefore on the way out and not only on the way back. Roxygen
section 1 states this. An earlier draft named both fields as lost when
`from_svydesign()` rebuilds, which implies the forward leg keeps them. It does
not: they are gone as soon as the object leaves surveycore. Documentation only.
Add no code.

### `as_tbl_svy(x)`

- **Signature**: `as_tbl_svy(x)`
- **Arguments**: `x` — a survey design object.
- **Returns**: a `srvyr::tbl_svy` object.
- **Logic change**: none. Do not edit the body.

The guard at `R/methods-conversion.R:265` is
`!S7::S7_inherits(x, survey_base)`. A `survey_nonprob` design inherits
`survey_base`, so it already passes that guard. The function then calls
`srvyr::as_survey(as_svydesign(x))`, and `as_svydesign()` raised CN-1 on a
nonprob design. `as_tbl_svy()` starts accepting both nonprob shapes the moment
`as_svydesign()` does, with no edit to `as_tbl_svy()` itself.

Conditions from `as_svydesign()` propagate. A plain-shape nonprob design
therefore raises CN-3 through `as_tbl_svy()` as well.

- **Errors**: `surveycore_error_pkg_not_installed` for either missing package,
  and CN-1 for a non-design input. Both unchanged.
- **Warnings**: CN-3, propagated from `as_svydesign()`.
- **Edge cases**: the same table as `as_svydesign()`. `as_tbl_svy()` adds no
  behaviour of its own.
- **Documentation change**: the `@param x` block, two lines, at 348-349 on
  base `40700e3`. See
  §Documentation.

---

## Conditions

**Write every long message string with `paste0()` concatenation, one fragment
per source line.** That is the idiom of every existing long `cli` message in
`R/` — see `R/core-validators.R:172-183` and `R/core-classes.R:491-494`. A
string literal broken across source lines renders the same, because `cli`
collapses the embedded newline and the indentation to one space, so the
rendered text below is what the register rows record either way. Match the
file's idiom.

Write both rows into `plans/error-messages.md` before any code uses the new
class. The file's column order, used by every table in it, is:

```
| # | Function | Condition | Level | Error Class | cli Message Template |
```

Add one new dated subsection at the end of the file, after the
`### svydesign-replicate-bridge rows (2026-09-04)` block:

```
### as-svydesign-bridge rows (2026-09-09)
```

Use the ID prefix `CN`, for conversion. `CV` is covariance, not conversion.
`CN` is free: a search of the file for a row that starts `| CN-` returns
nothing, re-verified in the working tree at base `40700e3`. `CB` is in use — the
`svydesign-replicate-bridge` subsection holds CB-1, CB-2 and CB-5, and reserves
CB-3 and CB-4 — so `CN` and `CB` do not collide.

**The ID `CN-2` is not used, and the gap is deliberate.** It held the dropped
replicate FPC warning, which ships in the other arc as CB-3 with the same class
name, `surveycore_warning_replicate_fpc_dropped`. That arc's `"v"` bullet is the
better remedy: it sends the caller to `survey::svrepdesign()` with `fpc`, which
is the correction itself, where CN-2 offered only a rebuild that silences the
warning. Do not reuse the ID `CN-2`. The reserved-row precedent is the CB block
above, which skips CB-2 to CB-5 for the same reason.

Also add one line to the Coverage Map table, after its last row:

```
| `test-conversion.R` | CN-1, CN-3 |
```

### CN-1 — `surveycore_error_not_survey_object`

This class exists already and is raised at four sites. It appears nowhere in
`plans/error-messages.md`. This row records it.

The four sites, identified by function and guard rather than by line. An
earlier revision of this table gave line ranges, and one of them went stale at
the next base change while the rest of this document was corrected, which is
the drift this document warns about elsewhere. Find each site with
`grep -n surveycore_error_not_survey_object R/methods-conversion.R R/utils.R`.

| File | Function | Guard |
|---|---|---|
| `R/methods-conversion.R` | `as_svydesign()` | the `else` of the dispatch chain |
| `R/methods-conversion.R` | `as_tbl_svy()` | `!S7::S7_inherits(x, survey_base)` |
| `R/utils.R` | `survey_data()` | `!S7::S7_inherits(x, survey_base)` |
| `R/utils.R` | `survey_weighting_history()` | `!S7::S7_inherits(x, survey_base)` |

At base `40700e3` the four class lines read 88, 402, 263 and 327. The second
moved from 271 when PR #249 added 126 lines above it.

All four raise the identical two bullets:

```r
c(
  "x" = "{.arg x} must be a survey design object.",
  "i" = "Got {.cls {class(x)[[1L]]}}."
)
```

**The four messages agree, byte for byte.** So one row covers all four, and no
message text changes at any site. Nothing has to be chosen as canonical.

The row belongs to this change because the `else` branch is this change's
branch: the nonprob branch takes one input class out of it, and the message is
only correct afterwards.

Register row:

```
| CN-1 | `as_svydesign()`, `as_tbl_svy()`, `survey_data()`, `survey_weighting_history()` | `x` does not inherit `survey_base` | ERROR | `surveycore_error_not_survey_object` | `"x" = "{.arg x} must be a survey design object.", "i" = "Got {.cls {class(x)[[1L]]}}."` — the four call sites raise identical text |
```

#### Does the `else` branch's message need new text?

No. Leave it alone.

The message said `x` is not a survey design object. Issue #237's complaint is
that this was false for a `survey_nonprob` design, which does inherit
`survey_base`. The nonprob branch removes that case from the branch. What is
left is correct:

| Input reaching the `else` | Is the message true? |
|---|---|
| `data.frame` | yes |
| `character` | yes |
| `numeric`, `list`, `NULL` | yes |
| `survey_collection` | yes. A collection holds designs; it is not a design and does not inherit `survey_base`. |

### CN-3 — the plain-shape nonprob conversion (D-2)

**Class name**: `surveycore_warning_nonprob_srs_conversion`

Raised in the nonprob branch of `as_svydesign()`, when
`x@variables$repweights` is `NULL`.

The first bullet reuses the wording of `surveycore_warning_nonprob_srs_fallback`
(register row NB-2) word for word, so one concept keeps one phrasing across the
package. The second bullet carries the fact only conversion introduces: the
returned object records nothing about the approximation, so nothing warns again
downstream.

The first bullet carries no prefix marking it as a repeat. A review asked for
one, on the grounds that it would help a reader who has already met NB-2.
Declined: one concept keeps one phrasing, which D-2 settled, and a prefix is a
second phrasing of the same concept.

```r
cli::cli_warn(
  c(
    "!" = paste0(
      "{.cls survey_nonprob} object has no bootstrap replicate weights. ",
      "Standard errors use an SRS approximation that underestimates ",
      "calibration uncertainty."
    ),
    "i" = paste0(
      "The returned {.pkg survey} object records nothing about the ",
      "approximation, so no later call warns again."
    ),
    "v" = paste0(
      "Run {.fn surveywts::create_bootstrap_weights} on this design, then ",
      "convert the design it returns."
    )
  ),
  class = "surveycore_warning_nonprob_srs_conversion"
)
```

Register row:

```
| CN-3 | `as_svydesign()`, `as_tbl_svy()` | `x` is a `survey_nonprob` design with no replicate weights, and the conversion takes the plain route | WARNING | `surveycore_warning_nonprob_srs_conversion` | `"!" = "{.cls survey_nonprob} object has no bootstrap replicate weights. Standard errors use an SRS approximation that underestimates calibration uncertainty.", "i" = "The returned {.pkg survey} object records nothing about the approximation, so no later call warns again.", "v" = "Run {.fn surveywts::create_bootstrap_weights} on this design, then convert the design it returns."` |
```

This is a new class and not a re-emission of NB-2. NB-2's bullets describe
`get_*()` behaviour on a surveycore design. CN-3 describes an object leaving
surveycore's hands. A distinct class lets a caller handle the two cases apart.

#### Why the `"v"` bullet names no conversion function

The bullet says "convert the design it returns" and names no call. The reason
is that CN-3 propagates. `as_tbl_svy()` calls `as_svydesign()`, so a caller of
`as_tbl_svy()` sees CN-3 too. An earlier draft's bullet told that caller to
call `as_svydesign()` on the rebuilt design, which returns the wrong class for
their pipeline. The bullet names the surveycore-side remedy —
`surveywts::create_bootstrap_weights()` — and stops. The caller already knows
which conversion they called.

#### `{.pkg}` in the `"i"` bullet

`{.pkg survey}` is correct and stays. `.claude/rules/code-style.md`'s inline
markup table lists six forms and not `{.pkg}`, and no row in
`plans/error-messages.md` uses it today, so this is the register's first
`{.pkg}` row. The codebase's practice is already settled:
`R/methods-conversion.R:68` raises
`"{.pkg survey} must be installed to use {.fn as_svydesign}."` The rule table
is what lags. Do not edit `.claude/rules/code-style.md` in this PR. See §Rule
documents that lag the code.

---

## Documentation

### `R/methods-conversion.R` — the four roxygen blocks that change

Three blocks in the `as_svydesign()` documentation and one in the
`as_tbl_svy()` documentation. Quote each current block, then write the
replacement. Lines 33 and 42 each run into the lines below them, so the blocks
are stated whole.

#### Lines 33-36, the `as_svydesign()` description

Before:

```r
#' Converts a `survey_taylor`, `survey_replicate`, or `survey_twophase` object
#' to the corresponding `survey` package object: `svydesign`, `svrepdesign`,
#' or `twophase`. Useful for accessing `survey` package estimation functions
#' or for round-trip testing.
```

After:

```r
#' Converts a `survey_taylor`, `survey_replicate`, `survey_twophase`, or
#' `survey_nonprob` object to the corresponding `survey` package object:
#' `svydesign`, `svrepdesign`, or `twophase`. Useful for accessing `survey`
#' package estimation functions or for round-trip testing.
```

#### Line 41, the `as_svydesign()` `@param x`

Before:

```r
#' @param x A `survey_taylor`, `survey_replicate`, or `survey_twophase` object.
```

After:

```r
#' @param x A `survey_taylor`, `survey_replicate`, `survey_twophase`, or
#'   `survey_nonprob` object.
```

#### Lines 42-46, the `as_svydesign()` `@return`

Before:

```r
#' @return A `survey::svydesign`, `survey::svrepdesign`, or `survey::twophase`
#'   object. Value labels are not carried into the returned object — the
#'   `survey` package has no metadata system. To read the data back with
#'   `haven`-style classes rebuilt, use `survey_data(x, haven_class = TRUE)` on
#'   the surveycore design instead.
```

After. One sentence is inserted; the three existing sentences keep their
current wording.

```r
#' @return A `survey::svydesign`, `survey::svrepdesign`, or `survey::twophase`
#'   object. The returned class follows the input class, and for a
#'   `survey_nonprob` design it follows the design's shape: a design that names
#'   replicate weights returns a `svrepdesign`, and a design that names none
#'   returns a `svydesign`. Value labels are not carried into the returned
#'   object — the `survey` package has no metadata system. To read the data
#'   back with `haven`-style classes rebuilt, use
#'   `survey_data(x, haven_class = TRUE)` on the surveycore design instead.
```

#### The `as_tbl_svy()` `@param x`, two lines (348-349 on base `40700e3`)

Before:

```r
#' @param x A `survey_taylor`, `survey_replicate`, or `survey_twophase` object.
#'   `survey_nonprob` is not supported and will error.
```

After. The second line is deleted, not edited. It says `survey_nonprob` "is not
supported and will error", and after this change that is false.

```r
#' @param x A `survey_taylor`, `survey_replicate`, `survey_twophase`, or
#'   `survey_nonprob` object.
```

All five roxygen lines named above belong to this
change. Lines 34-36 and 43-46 rewrap with the block each one sits in.

### The two lines that must not change

| Function | Text |
|---|---|
| `from_svydesign()` `@return` | `#' @return A \`survey_taylor\`, \`survey_replicate\`, or \`survey_twophase\` object.` |
| `from_tbl_svy()` `@return` | `#' @return A \`survey_taylor\`, \`survey_replicate\`, or \`survey_twophase\` object.` |

Both stay because neither function can produce a `survey_nonprob`. Neither
`.from_svydesign_taylor()` nor `.from_svydesign_replicate()` calls
`as_survey_nonprob()`, and a `survey` object records nothing that marks a
sample as non-probability.

**Identify these two lines by their text and their enclosing function, not by
their number.** The pair has moved three times, so a number is the wrong
instrument:

| Source | `from_svydesign()` `@return` | `from_tbl_svy()` `@return` |
|---|--:|--:|
| Issue #237, as written | 344 | 535 |
| This spec at base `a7a52c0` | 344 | 588 |
| This spec at base `1f15d35` | 364 | 750 |
| This spec at base `40700e3`, current | **495** | **881** |

The pair moved four times across five PRs of the neighbouring arc: #239, then
#241 and #247, then #249 and #250. Each line reads
`#' @return A `survey_taylor`, `survey_replicate`, or `survey_twophase` object.`
and there are exactly two such lines in the file.

**Identify them by that text and by their enclosing function. Do not trust a
number in this document, including the current one.**

The forward direction has held throughout. Re-verified at base `40700e3`
(R14): `as_svydesign()` at 63, the `else` branch's error class at 88,
`.as_svydesign_taylor()` at 96, `.as_svydesign_replicate()` at 131, and roxygen
lines 33, 41 and 42.

Two forward-direction citations did move, because PR #249 added 126 lines
inside `.as_svydesign_replicate()`, which sits above `as_tbl_svy()`:

| Item | Base `1f15d35` | Base `40700e3` |
|---|--:|--:|
| `as_tbl_svy()` | 246 | 372 |
| `as_tbl_svy()`'s `@param x`, two lines | 217, 218 | 348, 349 |
| `as_tbl_svy()`'s `surveycore_error_not_survey_object` | 271 | 402 |

`.as_svydesign_replicate()`'s own internals are no longer cited by line. PR
#249 rewrote the region that held the `fpctype` default, and this spec asks for
no change to that helper.

### New roxygen sections in the `as_svydesign()` block

Add three `@section` blocks. Place all three after `@return` and before
`@examples`, in the order given here. `@section` is house style;
`R/core-constructors.R` and `R/core-classes.R` both use it.

**Length rule for all three sections.** Each one states its core fact and its
measured numbers, and stops. The worked derivation of the two
degrees-of-freedom counting rules goes in
`vignettes/surveycore-vs-survey.Rmd` §5.1. Section 2 points there with
`vignette("surveycore-vs-survey")`; one pointer per help page is enough, and
section 2 is the section whose material the vignette carries. The existing
`as_svydesign()` block runs about 32 lines. The three blocks below add 47
lines: 17, 17 and 13, counted as written. No section carries an issue number,
per §Where an issue number may appear.

The `@section` titles stay as written. An earlier review asked for shorter,
terser titles and the request was declined: the titles read as sentences on the
rendered help page, and each one names the design feature a reader is looking
for. The titles were re-checked against the prose below and they still fit.

#### Section 1 — a non-probability design

This is where the round-trip sentence lives. It goes here and nowhere else,
because this is where the reader learns that the nonprob conversion exists, and
because one fact belongs at one site. `from_svydesign()`'s roxygen does not
change.

The section links `[as_survey_nonprob()]`. That help page already explains, at
`R/core-constructors.R:1194-1212`, why the SRS approximation understates the
variance and what the bootstrap mode buys. One link reaches the fuller
explanation, so this section does not repeat it.

The second paragraph carries what the forward leg drops. Both fields are gone
before `from_svydesign()` is ever called. An earlier draft named them only among
what the round trip loses, which read as if the forward leg kept them.

```r
#' @section A non-probability design:
#' A `survey_nonprob` design converts on the shape of its weights. A design
#' that names replicate weights becomes a `svrepdesign` and keeps every
#' replicate column, so the converted object computes the replicate variance
#' surveycore computes. A design that names none becomes a `svydesign` with
#' `ids = ~1`, and the call warns: the standard errors then use a simple random
#' sample approximation that charges nothing for calibration uncertainty, and
#' the returned object records nothing about it. See [as_survey_nonprob()] for
#' the two variance modes.
#'
#' The conversion drops the design's calibration provenance and its reference
#' sample, and the round trip does not return a non-probability design.
#' `from_svydesign()` on a converted design returns a `survey_taylor` or a
#' `survey_replicate` object, because a `survey` object records nothing that
#' marks a sample as non-probability. The rebuilt design reports design-based
#' standard errors and no longer warns, on data that has not changed. Keep the
#' original object when you need any of that.
```

#### Section 2 — degrees of freedom (D-3)

This passage goes in the roxygen only. It does not go in the warning. Measured
(R3): the plain shape converts to df 39 and the replicate shape to df 7, against
`Inf` on both surveycore designs. The t/z ratio is 1.032004 and 1.206463. The
larger gap belongs to the replicate shape, which is the shape that does not
warn, so a warning would state the smaller half and miss the larger.

**Both counts carry a measured qualifier, and the passage states both.**
Neither `n - 1` nor `R - 1` holds unconditionally:

| Count | Qualifier | Measured |
|---|---|---|
| `n - 1` for the plain shape | `survey` drops a zero-weight row. `degf.survey.design2` counts clusters and strata among the rows where `weights(design, "sampling") != 0`. A 40-row design with one zero weight converts to 38, not 39. | R12 |
| `R - 1` for the replicate shape | `degf.svyrep.design` computes `qr(weights(design, "analysis"), tol = 1e-5)$rank - 1` (`R/surveyrep.R:2049-2056` in survey 4.5). 8 independent replicate columns give rank 8 and `degf()` 7; the same 8 with one an exact duplicate give rank 7 and `degf()` 6. | R9 |

The zero-weight qualifier reaches only the plain shape. The replicate shape
stays at 7 on the same zero-weight frame (R12), because
`degf.svyrep.design` reads the rank of the replicate weight matrix and not the
row count.

```r
#' @section Degrees of freedom on a converted design:
#' surveycore reports `Inf` degrees of freedom for a `survey_nonprob` design,
#' and the `survey` package computes a finite number from the converted object.
#' A 40-row design with no replicate weights converts to 39, and the same
#' design with 8 replicate weight columns converts to 7. Both counts carry a
#' qualifier. Without replicate weights the `survey` package counts the rows
#' whose weight is not zero and subtracts 1, so the same design with one
#' zero-weight row converts to 38. With replicate weights it takes the
#' numerical rank of the matrix of replicate weights and subtracts 1, so the
#' figure is `R - 1` at full column rank and lower otherwise.
#'
#' The difference reaches a result only when the caller asks for it. A default
#' `confint()` call on a `svystat` or a `svrepstat` uses `df = Inf`, so the
#' default interval from `survey::svymean()` matches surveycore's. The gap
#' appears when the caller passes `degf(design)`, or calls a `survey` function
#' that reads `degf()` itself, such as `svyglm()` or `svyttest()`. See
#' `vignette("surveycore-vs-survey")` for the two counting rules in the source.
```

#### Section 3 — a filtered design's domain (D-6)

`as_svydesign()` converts the full stored sample. A design that `filter()` has
restricted to a domain converts to an object that answers for every row, not
for the domain. Measured (R10): a design filtered to `y1 > 50` gives mean
58.176655 in surveycore and mean 50.761561 through `survey::svymean()` on the
converted object. The point estimate differs, not only the standard error.
Subsetting the converted object on the domain column recovers 58.176655
exactly.

The section names the column, so a reader can act on the advice. The column
name is available as the exported constant `SURVEYCORE_DOMAIN_COL`, which holds
`"..surveycore_domain.."` (`R/utils.R:344`).

```r
#' @section A filtered design's domain:
#' The converted object represents the full stored sample and not the active
#' domain. `filter()` from surveytidy keeps every row and marks domain
#' membership in a logical column named by `SURVEYCORE_DOMAIN_COL`, which holds
#' `"..surveycore_domain.."`. `as_svydesign()` passes that column through as
#' ordinary data and never installs it as the converted object's restriction,
#' so `survey::svymean()` on the result answers for every row. The point
#' estimate differs from the domain estimate, not the standard error alone.
#'
#' A caller who wants the domain has to subset the returned object on that
#' column: `subset(converted, ..surveycore_domain..)` does it, and reproduces
#' `get_means()` on the filtered design exactly. Calling `get_means()` on the
#' filtered design needs no subset at all.
```

`..surveycore_domain..` is a syntactic R name — two dots followed by a letter —
so the `subset()` call above needs no backticks and parses as written.

This is documentation only. Per D-6 the change adds no code for it. Issue #245
carries the fix, which reaches all four routes.

### The vignette passage — `vignettes/surveycore-vs-survey.Rmd` §5

`as_svydesign()` appears in no vignette in the package today. A search of
`vignettes/` for either conversion function returns nothing. So §5 needs two
things: one row in its comparison table, and one new subsection that introduces
the bridge before the difference makes sense.

Where each part goes:

| Part | Position |
|---|---|
| The new table row | inside the existing §5 comparison table, after the `Non-probability design` row at line 624 and before the `Manipulation` row at line 625 |
| The new subsection §5.1 | after the §5 table and before the `---` at line 628 that closes the section, so the table stays the section's overview and the detail follows it |

House style read from the file before writing: `##` for a numbered section and
`###` for a numbered subsection; `toc_depth: 3`, so §5.1 reaches the table of
contents; title case in every heading, which is this file's own convention and
not the plain sentence case the repository writing rules set for prose headings.
The setup chunk at line 19 binds
`has_survey <- requireNamespace("survey", quietly = TRUE)`, and every chunk that
needs the package carries `eval=has_survey`. The one new chunk carries it, which
is `CLAUDE.md` §CI's rule applied through the file's own variable. Do not inline
a second `requireNamespace()` call; match the file.

The passage carries no issue number, because no vignette in the package does.
It reuses `strat_sc`, built at line 106 from `apistrat`, and `api00`, already
used at line 371. Chunk labels must be unique in the file; `bridge-convert` is
free.

The new table row:

```markdown
| **Conversion to `survey`** | Is `survey` | `as_survey(svydesign(...))` | `as_svydesign()` and `from_svydesign()` |
```

The new subsection, in full:

````markdown
### 5.1 Converting a Design to a `survey` Object

`as_svydesign()` converts a surveycore design to the matching `survey` design
object. `as_tbl_svy()` does the same and then wraps the result as an `srvyr`
`tbl_svy`. Use either one to reach a `survey` function that surveycore does not
provide. `from_svydesign()` and `from_tbl_svy()` convert back.

```{r bridge-convert, eval=has_survey}
strat_conv <- surveycore::as_svydesign(strat_sc)
class(strat_conv)
svymean(~api00, strat_conv)
```

All four surveycore design classes convert. A `survey_nonprob` design converts
on the shape of its weights, and `?as_svydesign` states what that costs. One
difference is worth reading here, because the rule that produces it lives in
the `survey` package's own source.

**Degrees of freedom differ on a non-probability design.** surveycore reports
`Inf` for a `survey_nonprob` design. `survey` computes a finite number from the
converted object, by one of two counting rules. `survey::degf` for a
`svydesign` object counts distinct clusters minus distinct strata among the rows
whose sampling weight is not zero. So a 40-row non-probability design converts
to 39, and the same design with one zero-weight row converts to 38.
`survey::degf` for a `svrepdesign` object computes
`qr(weights(design, "analysis"), tol = 1e-5)$rank - 1`. So 8 independent
replicate columns give 7, and 8 columns with one an exact duplicate give 6.
The difference reaches an answer only when you ask for it: a default
`confint()` call uses `df = Inf` on both sides.
````

One chunk, and one bold item. The passage shows the conversion and then states
the one difference the roxygen defers here. The chunk calls `svymean()` bare,
which matches the neighbouring chunks: the setup chunk runs `library(survey)`
when `has_survey` is `TRUE`. It writes `surveycore::as_svydesign()` namespaced,
which also matches: the file namespaces every surveycore constructor call,
because `srvyr` exports an `as_survey()` of its own.

The introductory sentence still earns its place after the narrowing. It carries
two facts the table row does not: that every one of the four classes converts,
and that the nonprob class converts on a shape rather than on its class alone.
It then says why the one remaining item is here and not on the help page.

### `devtools::document()`

Run it before committing. Two `man/` pages regenerate: `man/as_svydesign.Rd`
and `man/as_tbl_svy.Rd`. Ship them with the source. Do not edit `NAMESPACE` by
hand; nothing in this change adds or removes an export.

---


## Quality gates

Objectively verifiable. Each line is checkable from the working tree.

- [ ] `as_svydesign()` has five branches, in the order Taylor, replicate,
      twophase, nonprob, `else`.
- [ ] The nonprob branch tests `!is.null(x@variables$repweights)` and nothing
      else.
- [ ] The nonprob branch sends the replicate shape to
      `.as_svydesign_replicate()` and the plain shape to
      `.as_svydesign_taylor()`, and raises CN-3 before the plain-shape call.
- [ ] `.as_svydesign_taylor()`, `.as_svydesign_replicate()` and
      `.as_svydesign_twophase()` are unchanged. Confirm with a line-level diff.
      The FPC work on `.as_svydesign_replicate()` belongs to another change.
- [ ] `from_svydesign()`, `from_tbl_svy()` and the three
      `.from_svydesign_*()` helpers are unchanged.
- [ ] The two reverse-direction `@return` lines are unchanged. Find them by
      text and enclosing function, and confirm with a line-level diff.
- [ ] `as_tbl_svy()`'s body is unchanged. Only its roxygen changes.
- [ ] The `as_svydesign()` roxygen block holds three `@section` blocks, and
      section 2 points at `vignette("surveycore-vs-survey")`.
- [ ] The three new `@section` blocks run 17, 17 and 13 lines, for 47.
- [ ] No roxygen line added anywhere in this change carries a GitHub issue
      number. A search of the diff's `R/` lines beginning `#'` for `#` followed
      by two or more digits returns nothing. The numbers live in the changelog
      fragment.
- [ ] Every `cli::cli_warn()` and `cli::cli_abort()` added carries a `class=`.
- [ ] Every long message string added uses `paste0()` concatenation, matching
      `R/core-validators.R:172-183`.
- [ ] `plans/error-messages.md` holds rows CN-1 and CN-3, holds no row CN-2,
      and gains one Coverage Map line for `test-conversion.R`.
- [ ] The message text at all four `surveycore_error_not_survey_object` sites
      is unchanged.
- [ ] `R/core-constructors.R` is unchanged. Its `@param fpc` and
      `@param fpctype` corrections went to issue #251.
- [ ] `R/methods-print.R` is unchanged, and
      `tests/testthat/_snaps/methods-print.md` is unchanged. The FPC output
      caveat went to issue #251.
- [ ] `vignettes/surveycore-vs-survey.Rmd` §5 gains one table row and one
      subsection, §5.1. The new chunk carries `eval=has_survey`.
- [ ] The vignette passage carries no GitHub issue number, matching every other
      vignette in the package.
- [ ] `devtools::document()` runs clean and the two `man/` pages are committed
      with the source.
- [ ] `pkgdown::build_site()` renders §5.1 and the new chunk runs.
- [ ] `NEWS.md` is unchanged. This work writes no entry there.
- [ ] `NAMESPACE` is unchanged.
- [ ] `DESCRIPTION` is unchanged.
- [ ] `air::format_package()` leaves the touched files alone.

---

## Rule documents that lag the code

Three stale entries were found while reviewing this spec. All three sit outside
this PR's scope. **Change no rule file in this PR.** They are recorded here so
a builder who reads a rule file and then the source is not left guessing which
one is right. The source is right in all three cases.

| Rule file | What it says | The real path or form |
|---|---|---|
| `.claude/rules/code-style.md:22` and `:134` | the shared-helper file is `R/07-utils.R` | `R/utils.R` |
| `.claude/rules/code-style.md:16` and `:39-41`; `.claude/rules/testing-surveycore.md:166` and `:168` | `04-methods-print.R`, `00-s7-classes.R`, `05-methods-conversion.R` | `R/methods-print.R`, `R/core-classes.R`, `R/methods-conversion.R` |
| `.claude/rules/code-style.md`, the inline-markup table | six `cli` forms, and no `{.pkg}` | `{.pkg}` is in use. `R/methods-conversion.R:68` raises `"{.pkg survey} must be installed to use {.fn as_svydesign}."` |

Every file path this document cites is the real one. The `{.pkg survey}` markup
in CN-3 stays.

---

## Pipeline tier

**recommended.**

The change alters numerical behaviour on one path: a nonprob design's converted
object now carries the estimator its shape implies, where the call used to
refuse. It adds one condition class to the public register, and it changes the
contract of an exported function to admit a fourth input class. None of that
fits the `optional` bar.
