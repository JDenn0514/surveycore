# Audit — PR 5 — fix/svydesign-replicate-fay

**Verdict**: PASS
**Date**: 2026-09-08 (second re-audit, of fix commit `980e681`)
**Tree**: e1cadf0d53117b802617324ea498a331124413fd

## Re-audit history

1. Original audit on tree `9e4477f9...` (commit `0b40e45`): **BLOCK** —
   `test_invariants()` called twice for `as_survey_replicate()`.
2. First re-audit on tree `73b8b0a...` (commit `56cfc92`): **PASS**, with one
   non-blocking finding — row E-8 ("`as_svydesign()` converts a replicate
   design whose columns hold zeros") had no dedicated committed block. That
   finding was wrongly treated as deferrable; this is the last of five pull
   requests, so there is no later pull request to carry it to.
3. **This audit**, on tree `e1cadf0d...` (commit `980e681`): closes the E-8
   gap with block X-19. **PASS**, no open findings.

Commit `980e681` touches only `tests/testthat/test-conversion.R` (44
insertions, 0 deletions, confirmed by `git show 980e681 --stat`) — no
production code changed, so every numerical result recorded against the
prior trees still holds; only X-19 itself needed independent verification.

## Scope validated

In scope: E-8, E-9, E-10, R-1, R-2, R-3, R-4, R-5, C-8, C-9, C-17, C-18.
Regression sweep: I-1, C-10 (import); C-6, C-15 (export); snapshot count and
content; `plans/error-messages.md` row order; `test_invariants()` call
discipline; CRAN cookbook scan. All figures below were produced by running
the code directly with `pkgload::load_all(".")`, using the test-spec's own
§3 fixture recipes independently of the builder's own fixtures, not by
reading the committed test blocks.

## Per-Test Result Table

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| **X-19 (closes E-8): `as_svydesign()` on a "JK1" design whose first replicate column is all zeros raises no condition of its own** | `withCallingHandlers()` catching every warning/error class during the `as_svydesign()` call: none raised | none | — | ✓ |
| X-19: the zeros reached the exported design | `sum(sv$repweights[, 1]) == 0` | 0 | 1e-10 | ✓ |
| X-19: `survey::svymean()` raises its own `simpleWarning`, not surveycore's | message `"1 replicates gave NA results and were discarded."`, class `simpleWarning, warning, condition` — reproduced exactly, independently | survey's own condition, correctly attributed | — | ✓ |
| X-19: surveycore discards the same replicate, so the SEs still agree | point diff 0; SE diff -3.164136e-15 — matches the fix commit's reported "-3.16e-15" | 0 | 1e-10 / 1e-8 | ✓ |
| X-19: the `simpleWarning`-class muffle cannot hide a condition `as_svydesign()` itself raises | regression-checked on the FPC-drop design: the typed `surveycore_warning_replicate_fpc_dropped` warning is never classed `simpleWarning` (confirmed `inherits(w, "simpleWarning")` is `FALSE`), and it still fires under a handler while `suppressWarnings(classes = "simpleWarning")` is in effect elsewhere in the call | typed condition unreachable by a `simpleWarning`-only muffle | — | ✓ |
| E-9: Fay export, rho recovered from an independently-derived formula (not read off `sv$rho`) | `1 - sqrt(1/(scale*n_rep))` = 0.3 exactly (diff 5.6e-17) for a source built with `fay.rho = 0.3` | 0.3 | 1e-10 | ✓ |
| E-9: `sv$scale` vs `d@variables$scale` vs `src$scale` | all three identical (diff 0) | equal | 1e-10 | ✓ |
| E-9: SE parity, Fay export vs source `survey` design | diff -6.4e-15 | 0 | 1e-8 | ✓ |
| E-10: Fay design built with no explicit `scale` (constructor default `1/n_rep`) recovers rho | recorded scale 0.1666667 (`n_rep=6`); recovered rho 0 | 0 | 1e-10 | ✓ |
| E-10: SE parity | diff -2.55e-15 | 0 | 1e-8 | ✓ |
| R-1: full round trip, cell A, point/SE/CI | point 0; SE 2.2e-16; CI [0, 0] | 0 | 1e-10/1e-8/1e-6 | ✓ |
| R-2: full round trip, cell D (finished weights), point/SE | point 0; SE 0 | 0 | 1e-10/1e-8 | ✓ |
| R-3: full round trip preserves replicate count | `ncol` match TRUE | TRUE | — | ✓ |
| R-4: FPC round trip — warns, then matches pre-drop numbers | typed warning fires; point diff 0; SE diff 0 | typed warning; 0/0 | —/1e-10/1e-8 | ✓ |
| R-5: Fay round trip (§3.5 fixture, `fay.rho = 0.3`), point/SE | point diff 0; SE diff 0 | 0 | 1e-10/1e-8 | ✓ |
| C-8: Fay scale whose product with `n_rep` is below 1 → `surveycore_error_fay_rho_unrecoverable` | class raised; message shows `"0.05"`; independently-derived rho for the test-spec's literal 4-column/`scale=0.1` example is -0.581 (matches `decisions.md`'s measured figure for the same product, 0.4, via a different scale/`n_rep` pair) | class + scale text shown | — | ✓ |
| C-9: snapshot for the same, scale text rendered | snapshot byte-matches; shows `"0.05"` | matches | — | ✓ |
| C-17: Fay design built via the bare `survey_replicate()` constructor with no `scale` key → same class, message shows `"none"` | class raised; message shows `"none"` | class + "none" | — | ✓ |
| C-18: snapshot for the same | snapshot byte-matches; shows `"none"` | matches | — | ✓ |
| Both Fay arms render different scale text | `"0.05"` vs `"none"` | must differ | — | ✓ |
| Neither Fay arm carries `# nocov` | confirmed — `grep nocov` on the whole diff (including both fix commits) returns nothing | none | — | ✓ |
| Item 5: JK2's own scale claim | recorded surveycore scale 0.8; exported `sv$scale` = 1 (survey ignores the scale argument for JK2 and reports 1); JK2, ACS, successive-difference and `"other"` (no `rscales`) each threw `survey`'s own `simpleWarning` in my independent run; JK1/JKn/BRR/Fay/bootstrap did not | matches builder's claim, independently confirmed | — | ✓ |
| Item 4: all nine accepted replicate types cross both routes | for every type in `{JK1, JK2, JKn, BRR, Fay, bootstrap, ACS, successive-difference, other}`: export succeeds, `sv$type` preserved, re-import (`from_svydesign()`) preserves `type`, replicate count and row count | round trip holds for all nine | — | ✓ |
| A type outside the accepted nine is still refused at import (regression, C-10) | `surveycore_error_replicate_type_unsupported` raised on `from_svydesign()` for a `subbootstrap` source | typed class | — | ✓ |
| `tests/testthat/_snaps/conversion.md` snapshot count | 8 total, zero deletions against the `8c99271` base — neither fix commit touches the snapshot file | exactly 8 | — | ✓ |
| `plans/error-messages.md` row order | CB-1, CB-2, CB-3, CB-4, CB-5 — no gaps, no pending-rows note | sequential CB-1..CB-5 | — | ✓ |
| `devtools::document()` — no `NAMESPACE`/`man/` drift | confirmed: `git diff 8c99271..HEAD --stat -- man/ NAMESPACE DESCRIPTION` is empty | no drift | — | ✓ |
| CRAN cookbook scan on `R/methods-conversion.R`'s added lines | unaffected by either fix (both test-only commits); no `T`/`F`, no `set.seed()`, no bare `print()`/`cat()`, no `options(warn=-1)`, no `installed.packages()`, no `<<-`, no unrestored `par()`/`options()`/`setwd()`, no `mc.cores`/`makeCluster` > 2, no `@importFrom` | none | — | ✓ |
| I-1 regression: cell A import parity | point diff 0; SE diff -8.9e-16; CI diff [0, 0] | 0 | 1e-10/1e-8/1e-6 | ✓ |
| C-6 regression: FPC-drop warning class | `surveycore_warning_replicate_fpc_dropped` | typed class | — | ✓ |
| C-15 regression: repweights-empty export refusal | `surveycore_error_repweights_empty` | typed class | — | ✓ |
| `air format --check tests/testthat/test-conversion.R` | exit 0, no output | clean | — | ✓ |
| `test_invariants()` call discipline — once per constructor per file | 4 real calls: lines 121, 754 (`as_survey()`, pre-existing), 1157 (`from_svydesign()`), 2150 (`as_survey_replicate()`) | exactly 1 per constructor | — | ✓ |

## The E-8 gap — now closed by X-19

Block X-19 ("`as_svydesign()` passes a zeroed replicate column through") is
the row that was missing: a surveycore replicate design (`type = "JK1"`)
whose first replicate weight column is set entirely to zero. I re-ran it
independently, not from the committed block:

- `as_svydesign(d)` raises no condition of its own — verified with a
  `withCallingHandlers()` catching every `warning`/`error` class during the
  call; none fired.
- The zeros reach the exported object unchanged: `sum(sv$repweights[, 1])`
  is exactly 0.
- `survey::svymean()` on the exported design raises its own `simpleWarning`,
  `"1 replicates gave NA results and were discarded."` — this is `survey`'s
  variance code reacting to the zeroed replicate, not a condition from the
  conversion. Confirmed by class (`simpleWarning, warning, condition`) and
  by message text, matching the commit message's claim exactly.
- surveycore discards the same replicate internally, so the two standard
  errors still agree: point diff 0, SE diff -3.164136e-15, both well inside
  `1e-10`/`1e-8`.
- The block's `suppressWarnings(classes = "simpleWarning")` cannot hide a
  condition `as_svydesign()` itself raises: regression-checked against the
  FPC-drop warning, whose class chain (`surveycore_warning_replicate_fpc_dropped,
  rlang_warning, warning, condition`) never includes `simpleWarning`, and
  which still fires under a class-scoped muffle targeting only
  `simpleWarning`.

This is exactly the E-8 scenario the test-spec names ("a surveycore
replicate design inline whose replicate block has a zero column entry"),
built on the export route with no special-cased handling, matching §IV.2
step 6 of the spec as the commit message states. The prior audit's
non-blocking finding is resolved, not merely narrowed.

## Before/After Comparison

| Metric | Before PR (cumulative through PR 1–4, `8c99271`) | After PR (`980e681`) | Δ |
|---|---|---|---|
| tests passing | 11430 | 11538 | +108 |
| tests failing | 0 | 0 | 0 |
| tests warning | 256 (D12: gate reads "no new warning", not "zero warning") | 256 | 0 |
| coverage (package) | 96.23% | 96.24% | +0.01% |
| coverage (`R/methods-conversion.R`) | 99.72% | 99.75% | +0.03%, same 1 uncovered line (436, pre-existing, outside this PR's diff) |
| R CMD check NOTEs | 2 (pre-approved pair) | 2 (same pair) | 0 |

No regression in tests-passing or coverage. Passing count moved
11532 → 11538 (+6) from the first re-audit to this one, consistent with
X-19 adding one `test_that()` block with its own expectations and no
deletions.

## Profile gates

(Gates re-run by the dispatching agent in the foreground on tree
`e1cadf0d53117b802617324ea498a331124413fd`; not re-run here per instruction.
Logs: `.surveycore-workspace/runs/2026-09-04-svydesign-replicate-bridge/logs/pr-5-refix2/`.)

| Gate | Result | Notes |
|---|---|---|
| `devtools::document()` | PASS | no `NAMESPACE` or `man/` drift |
| `devtools::test()` | PASS | `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11538 ]` |
| `run_examples()` | PASS | exit 0 |
| `R CMD build` | PASS | tarball produced |
| `R CMD check --as-cran --no-manual` | PASS | `Status: 2 NOTEs` (pre-approved pair) |
| `pkgdown::build_site(preview = FALSE)` | PASS | exit 0 |
| `covr` | PASS | package 96.24%; `R/methods-conversion.R` 99.75%, 1 uncovered line (436, pre-existing, outside diff) |

Tree: e1cadf0d53117b802617324ea498a331124413fd

## CRAN cookbook violations

None. Both fix commits (`56cfc92`, `980e681`) touch only
`tests/testthat/test-conversion.R`, which the cookbook scan does not cover
(test code, not `R/`). `R/methods-conversion.R` is unchanged since the
original audit — re-confirmed no `T`/`F`, no `set.seed()`, no bare
`print()`/`cat()`, no `options(warn = -1)`, no `installed.packages()`, no
`<<-`, no unrestored `par()`/`options()`/`setwd()`, no writes to
`getwd()`/home, no `mc.cores`/`makeCluster` over 2, all external calls use
`::`, no `@importFrom`, no `# nocov` added anywhere in the PR's diff.

## Does the suite now hold all 58 test-spec rows?

**Yes — all 58, and every one of them now has a committed test block.**
I-1 to I-24, I-26; C-1 to C-18; E-1 to E-10; R-1 to R-5 each hold at the
stated tolerance, run directly against the merged tree. Row I-25 correctly
carries no block, as recorded in `test-spec.md` §6.4. E-8 — the row this
pull request's revisions closed — is now covered by X-19, verified above
independently rather than taken from the committed assertions.

## Findings (non-blocking)

None open.

## BLOCKs

None. Both prior BLOCKs are fixed and re-verified:

1. `test_invariants()` called twice for `as_survey_replicate()` — fixed in
   `56cfc92`; the call now appears exactly once for that constructor.
2. E-8 left uncovered with no later pull request to carry it to — fixed in
   `980e681` (block X-19); verified independently above.
