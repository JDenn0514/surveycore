# Implementation — PR 5 — from-svydesign-metadata

**Branch base**: `5c8cca3`
**Commit**: `ea8016d9ee8676604e8bb0679fa2581a7c2d8fde`
**Tree**: `603b4e43365bafa5bd1dd7986bc9abbb9715afab`
**Parent**: `5c8cca34a5f797eae31dd11f7d6c7ec1d595d6b5` (direct child, as required)
**Date**: 2026-08-31

## Write surface

```
 R/methods-conversion.R           |  20 +--
 man/as_svydesign.Rd              |   5 +-
 man/as_tbl_svy.Rd                |   5 +-
 tests/testthat/test-conversion.R | 264 +++++++++++++++++++++++++++++++++++++++
 4 files changed, 285 insertions(+), 9 deletions(-)
```

- `R/methods-conversion.R` — modified
- `man/as_svydesign.Rd` — regenerated
- `man/as_tbl_svy.Rd` — regenerated
- `tests/testthat/test-conversion.R` — modified

`git diff --stat DESCRIPTION NAMESPACE` is empty. `tests/testthat/_snaps/conversion.md` [no such file]
is untouched: the file does not exist, and this PR does not create it.

## Summary

- `.from_svydesign_taylor()` and `.from_svydesign_replicate()` now strip the
  labelled class from the frame they build, then harvest that frame with
  `.extract_haven_metadata()` instead of constructing with an empty
  `survey_metadata()`. These are call sites 6 and 7 of the seven in spec
  §III.0.
- `.from_svydesign_twophase()` takes `phase1_sc@metadata` rather than
  harvesting a second time. It needs no strip: its frame comes from
  `.from_svydesign_taylor()`, already stripped.
- The strip is load bearing on its own, not only as a tidy-up.
  `.find_col_by_value()` casts every candidate column with `as.numeric()`
  (`R/methods-conversion.R:295`), which aborts with `vctrs_error_cast` on a
  labelled column. It runs before any S7 call, so the property setter added in
  an earlier PR cannot protect it.
- `@return` on `as_svydesign()` and `as_tbl_svy()` now carries the §XII.2
  boundary text and names `survey_data(x, haven_class = TRUE)` as the supported
  route.
- Ten rows C-0 to C-9 added to `tests/testthat/test-conversion.R`. Every block
  is guarded with `skip_if_not_installed("survey")`; C-8 also with
  `skip_if_not_installed("srvyr")`.

## The red run — before any change to `R/`

Command: `Rscript -e "testthat::set_max_fails(Inf); devtools::test(filter = 'conversion')"`

```
[ FAIL 11 | WARN 0 | SKIP 0 | PASS 100 ]
```

| Row | Line | Kind | What failed |
|---|---|---|---|
| C-3 | 894 | failure | `extract_val_labels(d)` length 0, expected `list(y3 = ...)` |
| C-3 | 895 | failure | `d@metadata@value_labels` is `list()` |
| C-3 | 896 | failure | `extract_var_label(d)` empty, expected two labels |
| C-4 | 916 | error | `as.numeric(col)`: `Can't convert 'x' <haven_labelled> to <double>` |
| C-5 | 949 | failure | `extract_val_labels(d)` length 0 |
| C-5 | 950 | failure | `extract_var_label(d)` empty |
| C-6 | 978 | failure | `extract_val_labels(d)` length 0 |
| C-6 | 979 | failure | `extract_var_label(d)` empty |
| C-7 | 995 | error | `surveycore_error_design_var_missing`: `ids_formula, weights_var, strata_var, and fpc_var` — see the HOLD below |
| C-8 | 1019 | failure | `extract_val_labels(d2)` length 0 |
| C-8 | 1020 | failure | `extract_var_label(d2)` empty |

C-0, C-1, C-2 and C-9 passed on the base. C-0 is discussed under
"Notes for tester"; C-1, C-2 and C-9 are guard rows that pin behaviour the
change must not disturb.

C-4's error came from `.find_col_by_value()` on the Taylor route. The fixture
builds the design with `probs = ~p` rather than `weights = ~wt`, which keeps
the weight formula out of the stored call and forces recovery by value. With
`weights = ~wt` in the call the helper is never reached and the labelled weight
column does not abort — that is why the fixture uses `probs`.

## The green run — after the change

Command: same.

```
[ FAIL 0 | WARN 0 | SKIP 1 | PASS 113 ]
```

The single skip is C-7's return leg. See the HOLD.

## Full run

`Rscript -e "devtools::test()"`

```
[ FAIL 0 | WARN 256 | SKIP 5 | PASS 10664 ]
```

| Measure | Baseline (`a23ca8b`) | This commit | Delta |
|---|---|---|---|
| failures | 0 | 0 | 0 |
| passes | 10630 | 10664 | +34 |
| warnings | 256 | 256 | 0 |
| skips | 4 | 5 | +1 — C-7 |

The 256 warnings are the pre-existing AAPOR small-cell notices.

## `document()`

`Rscript -e "devtools::document()"` rewrote `as_svydesign.Rd` and
`as_tbl_svy.Rd` and nothing else. `NAMESPACE` and `DESCRIPTION` are unchanged.
The run prints the usual `@srrstatsNA is not a known tag` lines from
`R/srr-stats-standards.R`; those predate this change and appear on `develop`.

## `check()`

`Rscript -e "devtools::check(document = FALSE)"` — 7m 18s.

```
0 errors | 0 warnings | 1 note
```

The note is `checking for hidden files and directories`, listing `.git` and the
`.check.log` I redirected output into. Both are worktree artifacts. The log
file is deleted and was never staged.

## Coverage

`NOT_CRAN=true Rscript -e "covr::package_coverage()"` → **96.17769%**.
Baseline about 96.17%; floor 95%. No fall.

## Gate 10 — how it was confirmed

Gate 10 (spec §XI.10): `@metadata@value_labels` is populated on every route
that builds a design from a frame carrying a `labels` attribute,
`from_svydesign()` included.

Confirmed three ways, one per helper:

| Helper | Row | Assertion |
|---|---|---|
| `.from_svydesign_taylor()` | C-3 | `extract_val_labels(d)` returns `list(y3 = c(No = 0, Yes = 1))`, and `d@metadata@value_labels` is asserted directly, not only through the extractor |
| `.from_svydesign_replicate()` | C-5 | `extract_val_labels(d)` returns the same list |
| `.from_svydesign_twophase()` | C-6 | `extract_val_labels(d)` returns the same list, sourced from `phase1_sc@metadata` |

`extract_val_labels()` reads `x@metadata@value_labels[[v]]` for a survey object
(`R/core-metadata.R:582`) with no fallback to the column attribute, so a green
C-3, C-5 and C-6 can only mean `@metadata` is populated. All three were red
before the change with `actual is length 0`.

Direct read for the record:

```
gate 10 — value_labels after from_svydesign():
$y3
 No Yes
  0   1
```

## C-2 — the numerical fence

`survey::svymean(~y1, as_svydesign(d))` against `get_means(d, y1, variance = "se")`
on the same labelled frame, n = 40, 10 PSUs in 2 strata.

| Estimand | surveycore | survey | Absolute difference | Tolerance |
|---|---|---|---|---|
| point | -0.11732223406853109 | -0.11732223406853111 | 1.388e-17 | 1e-10 |
| standard error | 0.15194162038636733 | 0.15194162038636733 | 0.000e+00 | 1e-8 |

The point estimates differ in the last bit; the standard errors are bit
identical.

## Task checklist

- [x] Write rows C-0 to C-4, every block guarded with `skip_if_not_installed("survey")`
- [x] Write rows C-5 to C-9, C-8 also guarded with `skip_if_not_installed("srvyr")`
- [x] Run the file and record the red run before touching `R/`
- [x] Five source edits — two strips, two harvests, one phase-1 carry-forward
- [x] Verify C-0 to C-9 pass — nine pass, C-7 held, see below
- [x] `@return` boundary text on `as_svydesign()` and `as_tbl_svy()`
- [x] `devtools::document()`, `air format`, `devtools::test()`, `devtools::check()`

## Signals raised

### HOLD — builder — 2026-08-31 — row C-7

**Where**: PR 5, `tests/testthat/test-conversion.R`, row C-7
("as_survey() to as_svydesign() to from_svydesign() keeps the labels"),
blocked by `R/methods-conversion.R:104-111`.

**What**: C-7's return leg aborts. `from_svydesign(as_svydesign(d))` raises
`surveycore_error_design_var_missing` for every Taylor design, labelled or not.
Should this PR repair it?

**Why I can't decide**: The defect has nothing to do with haven labels and the
spec does not mention it. `.as_svydesign_taylor()` calls
`survey::svydesign(ids = ids_formula, strata = .to_formula(strata_var), ...)`,
so `survey` records the local variable names in `$call`. `from_svydesign()`
then reads those names back through `.vars_from_formula()`, which returns
`all.vars()` of a bare symbol, and the S7 validator rejects `ids_formula`,
`weights_var`, `strata_var` and `fpc_var` as columns that do not exist.
Measured on an unlabelled frame at base `5c8cca3`: identical abort. Spec §XII.2
allows exactly one change to `as_svydesign()` — the `@return` text — and spec
§I "What this does NOT deliver" authorises nothing here. Note that
`plans/comprehension-haven-labelled.md:357-360` states this round trip works
today; it does not.

**Options**:

1. Repair `.as_svydesign_taylor()` so the recorded call carries real formulas,
   for instance through `bquote()` plus `eval()`. Fixes the round trip for all
   callers. Changes the `$call` that `as_svydesign()` stores, which is a
   user-visible behavioural change the spec does not sanction.
2. Repair `.from_svydesign_taylor()` so a recovered design-variable name that
   is not a column of `data` is discarded. This is what the `srvyr` route
   already does by accident — `from_tbl_svy()` reaches `NULL` for `ids` and
   recovers the weight by value, which is why C-8 passes. Cheap, and confined
   to my file. But it silently drops `ids` and `strata`, so the returned design
   estimates a different variance from the source design, with no warning.
3. Leave it and open a separate issue. What I did: C-7 keeps its two reachable
   assertions, then calls `testthat::skip()` with the reason inline. One line
   comes out when the decision lands.

**What I need**: A decision on whether the `as_svydesign()` to
`from_svydesign()` round trip is repaired in this PR, in a follow-up PR, or in
a separate issue.

## Notes for tester

- C-0 passed on the base as well as after the change. The row's premise —
  "before the fix the metadata was empty, so there was no label to show" — does
  not hold for `get_means()`. `.extract_var_meta()` falls back to the column
  attribute when `@metadata` has no entry (`R/analysis-helpers.R:160-166`), and
  the labelled column keeps its `label` and `labels` attributes through
  `survey::svydesign()` and through the strip. So the label reached the
  result's `.meta` payload either way. The row still earns its place: it proves
  the strip did not destroy the attributes the fallback needs. The rows that
  genuinely separate before from after are C-3, C-5 and C-6, because
  `extract_val_labels()` on a survey object reads `@metadata` only.
- C-1, C-2 and C-9 also passed on the base, by design — they pin behaviour the
  change must not disturb.
- `make_labelled()` from `tests/testthat/helper-test-data.R` builds the fixtures.
  No test calls `haven`, so `haven` stays in `Suggests` and no
  `skip_if_not_installed("haven")` is needed.
- No `test_invariants()` call was added. `tests/testthat/test-conversion.R`
  already calls it once for `as_survey()` at line 754.
- C-5's fixture would abort on the base whatever its weight column, because
  `.from_svydesign_replicate()` always reaches `.find_col_by_value()` and the
  helper iterates every numeric column, labelled ones included.
- The `@return` text uses an em dash, matching the spec's wording. `R CMD check`
  reports no non-ASCII note.
- Spec gates 17 and 18 (the timing ratio and the S7 version behind the setter)
  belong to the PR that added the property setter, not to this one.
