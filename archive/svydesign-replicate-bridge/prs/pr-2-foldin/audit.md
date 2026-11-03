# Audit — PR 2 — svydesign-replicate-bridge (fix/svydesign-replicate-foldin)

**Verdict**: PASS
**Date**: 2026-09-08 (tester run)
**Base**: `develop` at `a7a52c0` (was `4a1e396`) — rebased after PR #240 landed
**HEAD**: `2825855` (was `5e048f4`)

## Scope

In-scope rows for this PR: I-1, I-2, I-12, I-13, I-14, I-15, I-16, I-17,
I-18, I-19, I-20, I-22, I-23, I-24, I-26. Confirmed-still-hold rows from PR 1:
I-3 to I-11, I-21. Row I-25 is a recorded non-reachable state (test-spec
§6.4) — its absence is not a finding.

Out of scope, not scored: every C-row (no `cli_abort()`/`cli_warn()` added by
this PR), the four import guards (PR 3), and the whole export route,
E-rows and R-rows (PR 4/5). `tests/testthat/_snaps/conversion.md` confirmed
still absent.

All fixtures were built directly from `test-spec.md` §3 recipes via
individual synchronous `Rscript` calls against the merged tree (`devtools::
load_all()`, no gates). Oracle values from `survey::svymean()` /
`survey::SE()` / `confint()`.

## Per-Test Result Table

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| I-1 Cell A precondition: compressed | TRUE | TRUE | n/a | ✓ |
| I-1 Cell A precondition: combined.weights FALSE | TRUE | TRUE | n/a | ✓ |
| I-1 Cell A precondition: unnamed | TRUE | TRUE | n/a | ✓ |
| I-1 point | 48.747582738812675 | 48.747582738812675 | 1e-10 | ✓ |
| I-1 SE | 1.310904698808327 | 1.310904698808327 | 1e-8 | ✓ |
| I-1 CI low | 46.178256741984029 | 46.178256741984029 | 1e-6 | ✓ |
| I-1 CI high | 51.316908735641320 | 51.316908735641320 | 1e-6 | ✓ |
| I-2 Cell B precondition: not compressed, matrix | TRUE | TRUE | n/a | ✓ |
| I-2 Cell B precondition: combined.weights FALSE | TRUE | TRUE | n/a | ✓ |
| I-2 Cell B precondition: unnamed | TRUE | TRUE | n/a | ✓ |
| I-2 point | 48.747582738812675 | 48.747582738812675 | 1e-10 | ✓ |
| I-2 SE | 1.310904698808327 | 1.310904698808327 | 1e-8 | ✓ |
| I-2 fold-in (`stored == sv$repweights * pweights`) | max abs diff 0 | 0 | 1e-12 | ✓ |
| I-12 combined.weights TRUE, not compressed | TRUE/TRUE | TRUE/TRUE | n/a | ✓ |
| I-12 repweights == cols | identical | identical | identical | ✓ |
| I-12 value parity | max diff 0 | 0 | 1e-12 | ✓ |
| I-13 combined.weights FALSE | TRUE | TRUE | n/a | ✓ |
| I-13 repweights == cols | identical | identical | identical | ✓ |
| I-13 stored col == source*wt | max diff 0 | 0 | 1e-12 | ✓ |
| I-13 point | diff 0 | 0 | 1e-10 | ✓ |
| I-13 SE | diff 8.88e-16 | 0 | 1e-8 | ✓ |
| I-14 compressed after `compressWeights()` | TRUE | TRUE | n/a | ✓ |
| I-14 length(repweights) == length(cols) | TRUE | TRUE | identical | ✓ |
| I-14 all names in data | TRUE | TRUE | identical | ✓ |
| I-14 point | diff 0 | 0 | 1e-10 | ✓ |
| I-14 SE | diff 1.11e-15 | 0 | 1e-8 | ✓ |
| I-15 (JK1, flat) any zero in stored block | TRUE | TRUE | n/a | ✓ |
| I-15 point / SE | diff 0 / 8.88e-16 | 0 / 0 | 1e-10 / 1e-8 | ✓ |
| I-16 (JKn, stratified) any zero | TRUE | TRUE | n/a | ✓ |
| I-16 point / SE | diff 0 / 8.88e-16 | 0 / 0 | 1e-10 / 1e-8 | ✓ |
| I-17 single-replicate name | `..surveycore_repwt_1..` | same | identical | ✓ |
| I-17 point / SE | pass | pass | 1e-10 / 1e-8 | ✓ |
| I-18 two-replicate names | `_1..`, `_2..` | same | identical | ✓ |
| I-18 point / SE | pass | pass | 1e-10 / 1e-8 | ✓ |
| I-19 NA in replicate column preserved | anyNA TRUE | TRUE | n/a | ✓ |
| I-20 rejects nonpositive base weight | class `surveycore_error_weights_nonpositive` | same class | identical | ✓ |
| I-22 base column label preserved | "Outcome variable 1 (continuous)" | non-null label | n/a | ✓ |
| I-22 no repweight cols in variable_labels | TRUE | TRUE | identical | ✓ |
| I-23 sv keeps supplied colnames (precondition) | identical | identical | identical | ✓ |
| I-23 repweights == cols; cols present in data | TRUE/TRUE | TRUE/TRUE | identical | ✓ |
| I-23 first column value parity | max diff 0 | 0 | 1e-12 | ✓ |
| I-23 point / SE | pass | pass | 1e-10 / 1e-8 | ✓ |
| I-24 repweights == cols | identical | identical | identical | ✓ |
| I-24 rw1 stored == source matrix col | max diff 0 | 0 | 1e-12 | ✓ |
| I-24 unrelated -999 values gone | TRUE | TRUE | n/a | ✓ |
| I-24 SE | pass | pass | 1e-8 | ✓ |
| I-26 any negative stored | TRUE | TRUE | n/a | ✓ |
| I-26 negative cell value parity | diff 0 | 0 | 1e-12 | ✓ |
| **Regression check — PR 1 rows** | | | | |
| I-3 (cell C) point / SE | pass | pass | 1e-10 / 1e-8 | ✓ |
| I-4 (cell D) point / SE | pass | pass | 1e-10 / 1e-8 | ✓ |
| I-5 length(repweights) == ncol(matrix) | TRUE | TRUE | identical | ✓ |
| I-6 all repweight names in data | TRUE | TRUE | identical | ✓ |
| I-7 `get_means()` raises no error | no error | no error | identical | ✓ |
| I-8 zero-padded 20-replicate names | matches | matches | identical | ✓ |
| I-9 unpadded 4-replicate names | matches | matches | identical | ✓ |
| I-10 weights col name "wt" unchanged | identical | identical | identical | ✓ |
| I-11 fpc NULL, fpctype "fraction" | matches | matches | identical | ✓ |
| I-21 weights col `..surveycore_wt..`, not in repweights | TRUE/TRUE | TRUE/TRUE | identical | ✓ |
| I-21 point / SE | pass | pass | 1e-10 / 1e-8 | ✓ |

## The fold-in assertion change (I-2 / I-13 authority check)

PR 1's cell-B block ("`from_svydesign() writes one double column per
replicate for an uncompressed source`", `tests/testthat/test-conversion.R`
line ~1240) originally asserted the stored column equalled the raw
`unclass(as.matrix(sv$repweights))` column at `tolerance = 0`. PR 2 changed
that expectation to `as.numeric(rep_mat[, j]) * as.numeric(sv$pweights)` at
`tolerance = 1e-12`.

Test-spec §6.1 row I-2 states exactly this comparison for a cell-B source
(`combined.weights = FALSE`):

```r
stored <- as.matrix(survey_data(d)[, d@variables$repweights, drop = FALSE])
expected <- as.matrix(sv$repweights) * sv$pweights
expect_equal(unname(stored), unname(expected), tolerance = 1e-12)
```

and row I-13 states the same shape for the named-column factor-form
variant (`df[[cols[1]]] * df$wt`). D2 in `decisions.md` (the fold-in
decision) and the §5 coverage matrix both hold that a `combined.weights =
FALSE` source stores replication factors, and the correct post-fold-in value
is the factor times the base weight — never the raw factor. **The builder's
new expectation is the one the test-spec requires; the old `tolerance = 0`
raw-matrix assertion was the one asserting the pre-fix (buggy) behavior.**
Changing it was correct, not a relaxation. Confirmed independently by running
the identical comparison against the merged code (I-2 row above): max
absolute difference 0, well inside `1e-12`.

No other hunk in `tests/testthat/test-conversion.R` touches a pre-existing
PR 1 block: `git diff 4a1e396 -- tests/testthat/test-conversion.R` shows
exactly three hunks — a comment-only edit at the old line 1198 (no
assertion change), the single assertion change above at line ~1259, and one
pure-addition hunk (`@@ -1417,3 +1419,460 @@`) that appends new blocks R-11
through R-23. Zero other lines of the pre-existing 1419 lines changed.

## `test_invariants()` count and placement

`git show 4a1e396:tests/testthat/test-conversion.R | grep -n test_invariants`
and the current file both return the same three lines: 121 (`as_survey()`),
754 (`as_svydesign()`), 1157. PR 2 added zero new calls — line 1157 is
untouched by PR 2's diff (outside all three of its hunks) and sits inside
the first block of the new arc's section (`# ── R-1 … R-10. from_svydesign()
— the replicate bridge (#197) ──`) that converts a `svyrep.design`. This
matches test-spec §10.1: exactly one call for `from_svydesign()`, in the
first new block that exercises the route, unchanged since PR 1 and not
repeated anywhere in PR 2's 460 added lines.

## CRAN cookbook violations

None. Scanned every added line of `git diff 4a1e396 -- R/methods-conversion.R`
(51 added lines, the fold-in block and the roxygen `@section`) against all
nine patterns in `r-package-profile.md` §CRAN cookbook scan. Zero hits. No
`@importFrom` added.

## Documentation surface (D7)

`git diff 4a1e396 -- man/` shows exactly one file changed:
`man/from_svydesign.Rd`, adding the `\section{Replicate weights}` block and
correcting the now-false "replicate weights are preserved" sentence to
"data and design variables are preserved." `NAMESPACE` is unchanged.

Note: a diff against the *current* tip of `origin/develop` (`a7a52c0`, PR
#240, merged after this branch was cut) also shows `man/survey_data.Rd`
changing. That is `develop` moving out from under this branch between
dispatch and audit, not a PR 2 defect — diffing against the stated base
`4a1e396` (dispatch baseline) shows `survey_data.Rd` untouched. Recorded so
the divergence is not misread as a regression; the shipper should treat
this the same way D15 treats a `develop` update that touches `man/` (re-run
gates against the updated tree before merge, if this branch has not already
been rebased by the time it ships).

**Update after rebase.** The coordinator rebased this branch onto `develop`
at `a7a52c0` (PR #240) rather than let a shipper bypass the up-to-date
protection. `git diff origin/develop` now shows exactly the three expected
files — `R/methods-conversion.R`, `man/from_svydesign.Rd`,
`tests/testthat/test-conversion.R` — with `man/survey_data.Rd` no longer
among them: the drift is explained and gone. New HEAD `2825855` on base
`a7a52c0`; new tree `badc400c2ac71ae8bc94738da2bcf2f3182532a8`. All seven
gates were re-run by the coordinator on the rebased tree and returned
results identical to the ones already recorded above.

## Before/After Comparison

Before column is PR 1's After (this PR's baseline, `4a1e396`), per PR 1's
`audit.md`.

| Metric | Before PR | After PR | Δ |
|---|---|---|---|
| tests passing | 11209 | 11343 | +134 |
| test failures | 0 | 0 | 0 |
| test warnings | 256 | 256 | 0 (D12: gate reads FAIL count only; warning ceiling held) |
| coverage | 96.20% | 96.20% | 0 |
| R CMD check notes | 2 | 2 | 0 |

No regression in tests-passing, coverage, or notes.

## Profile gates

Gates were run by the coordinator in the foreground, one at a time, per
this run's standing instruction (concurrent gate runs corrupted PR 1's
logs). Results as supplied:

| Gate | Result | Notes |
|---|---|---|
| `devtools::document()` | PASS | no `NAMESPACE` drift; the only changed `man/` file (against dispatch base `4a1e396`) is `from_svydesign.Rd`, matching D7 |
| `devtools::test()` | PASS | `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11343 ]` — failures 0, warnings at the D12 ceiling of 256, not above it |
| `run_examples()` | PASS | exit 0, no error, no halted execution |
| `R CMD build` | PASS | `surveycore_1.1.0.9000.tar.gz` |
| `R CMD check --as-cran --no-manual` | PASS | `Status: 2 NOTEs`, both pre-approved (`checking CRAN incoming feasibility`; `checking for hidden files and directories` finding `.git`), 0 ERROR, 0 WARNING |
| `pkgdown::build_site(preview = FALSE)` | PASS | exit 0, no errored page |
| `covr::package_coverage()` | PASS | package 96.20% (no drop vs. baseline 96.20%); `R/methods-conversion.R` 99.19%, 2 uncovered lines (138, 305) both pre-existing and outside this PR's added ranges (330–332, 340–359, 506–530); no `# nocov` added |
| CRAN cookbook scan | PASS | 0 hits (see above) |
| `air format --check <PR files>` | PASS | exits clean on this PR's two files; repository-wide drift (24 files, 2 under `R/`) is pre-existing per D16 and out of this PR's business |

Logs: `gate-1-document.log` through `gate-7-covr.log`, in
`.surveycore-workspace/runs/2026-09-04-svydesign-replicate-bridge/logs/pr-2/`.

Tree: badc400c2ac71ae8bc94738da2bcf2f3182532a8

## Verdict rationale

Every in-scope row (I-1, I-2, I-12 through I-20, I-22 through I-24, I-26)
passes at spec tolerance, independently re-derived from `test-spec.md` §3
fixture recipes and run against the merged tree. Every PR 1 row re-checked
(I-3 to I-11, I-21) still holds — no regression. The one changed assertion
(cell-B fold-in expectation) is the one test-spec §6.1/§6.3 requires; the
prior `tolerance = 0` raw-matrix assertion it replaced was the pre-fix
(incorrect) expectation, not a weakened one. `test_invariants()` for
`from_svydesign()` still fires exactly once, unmoved by this PR, at the
correct location. No pre-existing block besides that one assertion was
edited. All seven profile gates pass, with no new NOTE, no warning-count
rise, no coverage regression, and every line this PR added to
`R/methods-conversion.R` reached. CRAN cookbook scan is clean. Documentation
surface matches D7. No out-of-scope behavior (conditions, import guards,
export route, round trip) was scored against this PR.

## BLOCKs (if any)

None.
