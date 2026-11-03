# Audit — PR 4 — fix/svydesign-replicate-fpc

**Verdict**: PASS
**Date**: 2026-09-08

## Scope validated

E-1, E-2, E-3, E-4, E-5, E-6, E-7, C-6, C-7, C-15, C-16 (in-scope rows), plus
a regression spot-check of I-1, I-10 (pluralized message), C-10 from earlier
PRs. Out of scope and not exercised or scored: E-8, E-9, E-10, R-1 to R-5,
C-8, C-9, C-17, C-18 (all PR-5/Fay work). Confirmed none of that work is
present in this diff (`grep -n "Fay" tests/testthat/test-conversion.R`
returns nothing).

## Per-Test Result Table

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| E-1: no FPC → no warning | no warning fired; `sv` is `svyrep.design` | no warning; `svyrep.design` | — | ✓ |
| E-2: no-FPC export parity, point | diff 0 | 0 | 1e-10 | ✓ |
| E-2: no-FPC export parity, SE | diff -2.55e-15 | 0 | 1e-8 | ✓ |
| E-3: FPC + BRR warns typed class | `surveycore_warning_replicate_fpc_dropped`; `svyrep.design` returned | typed warning; conversion succeeds | — | ✓ |
| E-3: FPC + BRR parity, point/SE | diff 0 / -2.55e-15 | 0 | 1e-10 / 1e-8 | ✓ |
| E-4: FPC + bootstrap warns and converts | typed warning; `svyrep.design`; nrow match | same | — | ✓ |
| E-4 (extended): FPC + JK1, JK2, ACS, successive-difference, JKn all warn and convert | all six types: typed warning present, `svyrep.design` returned, `nrow(sv$variables) == nrow(d@data)` | same for all types incl. bootstrap | — | ✓ |
| E-5: FPC + JKn warns and converts | typed warning; `svyrep.design` | same | — | ✓ |
| E-6: design untouched after drop | `identical(survey_data(d), before)` TRUE; `identical(d@variables, before)` TRUE; `d@variables$fpc == "fpc"`; `fpctype == "fraction"` | all identical/unchanged | — (structural, `expect_identical`) | ✓ |
| E-7: warns on every call | 1st call warns typed class; 2nd call warns typed class (both muffled independently) | warns both times | — | ✓ |
| C-6: `expect_warning(result <- as_svydesign(d), class=...)` | typed class captured from return value | typed class | — | ✓ |
| C-7: snapshot shows dropped column name | snapshot text: `` ! `as_svydesign()` dropped the finite population correction column fpc. `` plus the three follow-on bullets, byte-matches `_snaps/conversion.md` | matches committed snapshot | — | ✓ |
| Muffling check (item 5): `survey` really emits its own `simpleWarning` for JK2/ACS/successive-difference independent of this change | Confirmed: JK2, ACS, successive-difference each threw a base `simpleWarning` ("...scale= and rscales= are not needed"-type message) in addition to the typed condition; BRR, bootstrap, JK1, JKn threw only the typed condition | survey's own warning present for those three types only | — | ✓ |
| Muffling check (item 5): the typed condition's class chain never includes `simpleWarning` | `surveycore_warning_replicate_fpc_dropped, rlang_warning, warning, condition` — no `simpleWarning` in the chain | typed condition unreachable by a `classes = "simpleWarning"` filter | — | ✓ (muffling is narrow; cannot hide the typed warning) |
| C-15: repweights-empty design refused on export | `class = surveycore_error_repweights_empty`; message: "The design names no replicate weight column." + two follow-on bullets | typed class + message | — | ✓ |
| C-16: snapshot for the same | snapshot text byte-matches `_snaps/conversion.md`'s second new block, including `Error in \`.as_svydesign_replicate()\`:` header | matches | — | ✓ |
| `test_invariants()` count for `as_survey_replicate()` | exactly 1 new call, at test-conversion.R:2138 (inside the X-1 block, via `make_rep_fpc()`); 0 prior calls existed for this constructor | 1 | — | ✓ |
| `test_invariants()` count for `from_svydesign()` | 0 new calls added by this PR (existing call at line 1157 predates this PR, per D10/PR-2) | 1 total, 0 added here | — | ✓ |
| §3.7 zero-replicate construction carries no `test_invariants()` call | confirmed — X-7 block has none | none | — | ✓ |
| Snapshot count in `tests/testthat/_snaps/conversion.md` | 6 total: 4 pre-existing (byte-identical, diff shows no changes to them) + 2 new (FPC-drop warning, repweights-empty error) | exactly 6 | — | ✓ |
| `plans/error-messages.md` row order | CB-1, CB-2, CB-3, CB-5 in that order; CB-4 absent; pending note names CB-4 only | same | — | ✓ |
| `plans/error-messages.md` row 16 trigger note | unedited row 16 itself, one bullet appended below the table extending its trigger description | unedited row, extended note only | — | ✓ |
| CB-2 template correction | reads `{cli::qty(n_collisions)}` (both occurrences), matching D17 | namespaced `qty()` | — | ✓ |

## Before/After Comparison

| Metric | Before PR | After PR | Δ |
|---|---|---|---|
| tests passing | 10872 (baseline `develop`) | 11430 (cumulative through PR 1–4) | +558 |
| tests failing | 0 | 0 | 0 |
| tests warning | 256 | 256 | 0 (D12: warning count gate, not zero-warning gate) |
| coverage (package) | 96.19% | 96.23% | +0.04% |
| coverage (`R/methods-conversion.R`) | not separately tracked at baseline; 99.40% before this PR (per PR-3 audit) | 99.72% | +0.32%, 1 uncovered line remains (line 364, pre-existing `.find_col_by_value()` `# nocov`-marked early exit, outside this PR's diff ranges 135–158/169–209) |
| R CMD check NOTEs | 2 (pre-approved) | 2 (same pair) | 0 |

No regression in tests-passing or coverage. Coverage rose and the one
remaining uncovered line predates this PR and is outside its diff.

## Profile gates

(Gates run by the dispatching agent in the foreground on tree
`b0f56dc938d7552b74206c78dcfb6485852fc250`; not re-run here per instruction.)

| Gate | Result | Notes |
|---|---|---|
| `devtools::document()` | PASS | no `NAMESPACE` or `man/` drift — confirmed independently: `git diff` shows zero roxygen-comment lines changed and zero `man/`/`NAMESPACE` diff for this PR |
| `devtools::test()` | PASS | `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11430 ]` |
| `run_examples()` | PASS | exit 0 |
| `R CMD build` | PASS | tarball produced |
| `R CMD check --as-cran --no-manual` | PASS | `Status: 2 NOTEs` (the pre-approved pair) |
| `pkgdown::build_site(preview = FALSE)` | PASS | exit 0 |
| `covr` | PASS | package 96.23%; `R/methods-conversion.R` 99.72% |

Tree: b0f56dc938d7552b74206c78dcfb6485852fc250

## CRAN cookbook violations

None. Manually reviewed the full diff hunks in `R/methods-conversion.R`
(lines 135–158, 169–209, plus the deletion at 216) against every pattern in
`r-package-profile.md` §CRAN cookbook scan: no bare `T`/`F`, no
`set.seed()`, no bare `print()`/`cat()`, no `options(warn = -1)`, no
`installed.packages()`, no `<<-`, no unrestored `par()`/`options()`/`setwd()`,
no writes to `getwd()`/home, no `mc.cores`/`makeCluster` over 2. All external
calls use `::`. No `@importFrom`.

## Independent verification (beyond the gate table)

Ran each in-scope scenario directly against the source loaded with
`pkgload::load_all(".")` on the merged tree, one `Rscript` call at a time:

- E-1/E-2 (no FPC): no warning fires; `svymean()` on the exported design
  matches `get_means(d, y1)` — point diff 0, SE diff -2.55e-15.
- E-3 to E-5 and the extended type sweep (item 4): built `rep_bridge_sc`/
  `make_rep_fpc`-equivalent fixtures with an FPC recorded, for `JK1`, `JK2`,
  `BRR`, `bootstrap`, `ACS`, `successive-difference`, and `JKn` (with
  `rscales`). Every type produced the typed `surveycore_warning_replicate_fpc_dropped`
  warning and returned a working `svyrep.design`. `JK2`, `ACS`, and
  `successive-difference` additionally raised a `simpleWarning` from `survey`
  itself, confirming the builder's fixture note; `JK1`, `BRR`, `bootstrap`,
  `JKn` did not.
- E-6/C-6: captured `survey_data(d)` and `d@variables` before and after the
  warned call — both `identical()`. A second call on the same object warned
  again.
- Muffling technique (item 5): confirmed `suppressWarnings(classes =
  "simpleWarning")` does not and cannot swallow the typed condition — its
  class chain is `surveycore_warning_replicate_fpc_dropped, rlang_warning,
  warning, condition`, which never includes `simpleWarning`. Not a finding.
- C-15/C-16: built the §3.7 zero-replicate-column design via the exported
  `survey_replicate()` class constructor and called `as_svydesign()` directly
  — raised `surveycore_error_repweights_empty` with the message text that
  matches the committed snapshot.
- Regression spot-check: I-1 (cell A import parity, point diff 0, SE diff
  8.88e-16) and C-10 (unsupported-type import refusal) both still pass on
  this tree.

## Findings (non-blocking)

- `plans/error-messages.md` line 530 (the CB-3 table row) is missing the
  trailing `|` that every other row in the table carries. GFM does not
  require a trailing pipe for content rows, so the table still renders, and
  the row's content (function, condition, level, class, template) is
  otherwise correct and matches the shipped code. Noting it since a later
  editor is more likely to hand-edit that row incorrectly than a padded one.
  Does not affect any test-spec row, any gate, or any tolerance — not scored
  as a defect.

## BLOCKs

None.
