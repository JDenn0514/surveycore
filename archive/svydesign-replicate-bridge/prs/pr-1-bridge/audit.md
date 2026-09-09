# Audit — PR 1 — svydesign-replicate-bridge

**Verdict**: PASS
**Date**: 2026-09-08 11:55

## Scope

In-scope test-spec rows for this PR: I-3, I-4, I-5, I-6, I-7, I-8, I-9, I-10,
I-11, I-21. All other rows (I-1, I-2, I-13 — base weight fold-in; all C-rows;
all E-rows and R-rows; the import guards) are out of scope per dispatch and
are not scored here.

## Per-Test Result Table

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| Cell C precondition: `sv$repweights` is `repweights_compressed` | TRUE | TRUE | n/a | ✓ |
| Cell C precondition: `combined.weights` TRUE | TRUE | TRUE | n/a | ✓ |
| Cell C precondition: named columns, count = n_rep | TRUE | TRUE | n/a | ✓ |
| I-3 point estimate (cell C) | 49.5297640427556 | 49.5297640427556 | 1e-10 | ✓ |
| I-3 SE (cell C) | 1.38215923246059 | 1.38215923246059 | 1e-8 | ✓ |
| Cell D precondition: not compressed, is matrix | TRUE | TRUE | n/a | ✓ |
| Cell D precondition: `combined.weights` TRUE | TRUE | TRUE | n/a | ✓ |
| Cell D precondition: unnamed columns | TRUE | TRUE | n/a | ✓ |
| I-4 point estimate (cell D) | 49.5297640427556 | 49.5297640427556 | 1e-10 | ✓ |
| I-4 SE (cell D) | 1.38215923246059 | 1.38215923246059 | 1e-8 | ✓ |
| I-5 `length(d@variables$repweights)` == `ncol(as.matrix(sv$repweights))` (cell A) | 12 | 12 | identical | ✓ |
| I-6 every `d@variables$repweights` name in `names(survey_data(d))` (cell A) | TRUE | TRUE | identical | ✓ |
| I-7 `get_means(from_svydesign(sv), y1)` raises no error (cell A) | no error | no error | identical | ✓ |
| I-8 zero-padded names, 20-replicate bootstrap design | `..surveycore_repwt_01..` … `..surveycore_repwt_20..` | same | identical | ✓ |
| I-9 unpadded names, 4-replicate `type="other"` design | `..surveycore_repwt_1..`…`_4..` | same | identical | ✓ |
| I-10 `d@variables$weights` unchanged (cell A) | `"wt"` | `"wt"` | identical | ✓ |
| I-11 `d@variables$fpc` is NULL (cell A) | NULL | NULL | identical | ✓ |
| I-11 `d@variables$fpctype` (cell A) | `"fraction"` | `"fraction"` | identical | ✓ |
| I-21 `d@variables$weights` (no `wt` column, replicate 1 = base weights) | `"..surveycore_wt.."` | `"..surveycore_wt.."` | identical | ✓ |
| I-21 weights name not in repweights set | FALSE | FALSE | identical | ✓ |
| I-21 point estimate | 0.355603882491316 | 0.355603882491316 | 1e-10 | ✓ |
| I-21 SE | 0.0849278445664181 | 0.0849278445664182 | 1e-8 | ✓ |
| `test_invariants()` for `from_svydesign()` — exactly one new call in the file | 1 (cell-A block) | 1 | identical | ✓ |
| Pre-existing `test-conversion.R` blocks unedited vs `origin/develop` | single additive hunk `@@ -1122,3 +1122,298 @@`, no deletions | unedited | identical | ✓ |

All fixtures were built from `test-spec.md` §3 recipes (`rep_bridge_taylor`,
`rep_bridge_combined`) run directly via `Rscript`, plus inline `type="other"`
constructions per each row's own setup column (I-8, I-9, I-21), oracle values
from `survey::svymean()` / `survey::SE()`. This run completed (foreground,
`devtools::load_all()` only, no build/check/covr) before the 11:33 collision
window flagged by the coordinator, and is unaffected by it.

## `test_invariants()` count

`git show origin/develop:tests/testthat/test-conversion.R | grep -n test_invariants` →
2 pre-existing calls (lines 121, 754 — `as_survey()` / `as_svydesign()` routes,
out of scope here). The merged file adds exactly one more, inside the first
block that converts a `svyrep.design` (cell A). No other new block repeats
it. Matches `test-spec.md` §10.1.

## Pre-existing test blocks unedited

`git diff origin/develop -- tests/testthat/test-conversion.R` shows exactly
one hunk: `@@ -1122,3 +1122,298 @@`, pure addition, 3 lines of trailing
context, zero deletions. (A raw byte-level `diff` against `git show
origin/develop:...` reports the whole file as changed — that is a
CRLF-vs-LF checkout artifact on this Windows worktree, not a content change;
`git diff`, which normalizes per `.gitattributes`, is the correct instrument
and confirms no edits to the pre-existing 1124 lines.)

## CRAN cookbook violations

None. Scanned every added line in `git diff origin/develop -- R/methods-conversion.R`
(54 added lines) against all nine patterns in `r-package-profile.md` §CRAN
cookbook scan — zero hits. No `@importFrom` in that file.

## Before/After Comparison

| Metric | Before PR | After PR | Δ |
|---|---|---|---|
| tests passing | 10872 | 11209 | +337 |
| test failures | 0 | 0 | 0 |
| test warnings | 256 | 256 | 0 |
| coverage | 96.19% | 96.20% | +0.01% |
| R CMD check notes | 2 | 2 | 0 |

The +337 passing tests are this PR's own new blocks plus 227 that arrived
with the `dim()` commit (#238) picked up in the rebase onto `origin/develop`
— confirmed by the coordinator, consistent with `git log` showing
`74c0913 fix(classes): register dim() for survey_base and survey_collection
(#238)` between the baseline commit and `HEAD`. Not a regression.

Coverage rose (+0.01%), so neither the HOLD threshold (drop ≥0.5% and below
98%) nor the BLOCK threshold (drop below 95%) applies.

## Profile gates

All seven gates were run by the coordinator, in the foreground, one gate at
a time, with no other R process on the machine, after an earlier
concurrent-run collision destroyed the gate-1/2/3 logs from a prior attempt.
Gates 1, 2 and 3 were re-run so the full set comes from one self-consistent
tree and one intact log set.

| Gate | Result | Notes |
|---|---|---|
| `devtools::document()` | PASS | no `NAMESPACE` or `man/` drift |
| `devtools::test()` | PASS | `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11209 ]` — failures 0, warnings exactly at the D12 baseline of 256, not above it |
| `run_examples()` | PASS | exit 0, no error, no halted execution |
| `R CMD build` | PASS | `./surveycore_1.1.0.9000.tar.gz` |
| `R CMD check --as-cran --no-manual` | PASS | `Status: 2 NOTEs` — both pre-approved (`checking CRAN incoming feasibility`; `checking for hidden files and directories` finding `.git`), 0 ERROR, 0 WARNING, no third NOTE |
| `pkgdown::build_site(preview = FALSE)` | PASS | site built, "Checking for problems" raised none, exit 0 |
| `covr::package_coverage()` | PASS | package 96.20% (baseline 96.19%, rose); `R/methods-conversion.R` 99.18%; the 2 uncovered lines (138, 305) fall outside every range this PR added (440–456, 461–479, 481–484, 486–489, 496–505) — pre-existing, not this PR's; every added line is reached; `git diff origin/develop -- R/methods-conversion.R \| grep '^+.*nocov'` returns nothing — no `# nocov` added |
| CRAN cookbook scan | PASS | 0 hits (see above) |
| `air::format_package()` | PASS | no diff |

Logs: `gate-1-document.log`, `gate-2-test.log`, `gate-3-examples.log`,
`gate-4-build.log`, `gate-5-check.log`, `gate-5-00check.log`,
`gate-6-pkgdown.log`, `gate-7-covr.log`, all in
`.surveycore-workspace/runs/2026-09-04-svydesign-replicate-bridge/logs/pr-1/`.

Tree: `4d19b55c841d731f4fe902c38ca0dc8e98df66ad`

## Verdict rationale

Every in-scope test-spec row (I-3, I-4, I-5, I-6, I-7, I-8, I-9, I-10, I-11,
I-21) passes at spec tolerance. `test_invariants()` fires exactly once for
`from_svydesign()`. Pre-existing test blocks are unedited. All seven profile
gates pass, with no new NOTE, no new warning, no coverage regression, and
every line this PR added to `R/methods-conversion.R` covered. CRAN cookbook
scan is clean. No out-of-scope behavior (fold-in, conditions, export route,
import guards) was scored against this PR, per dispatch.

## BLOCKs (if any)

None.
