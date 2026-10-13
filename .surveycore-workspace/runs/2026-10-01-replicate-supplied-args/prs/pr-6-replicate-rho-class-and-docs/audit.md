# Audit — PR 6: fix/replicate-rho-class-and-docs

**Verdict: PASS**

- Request: replicate-supplied-args (issue #255), last PR of the arc
- Branch: `fix/replicate-rho-class-and-docs`, HEAD `7593539`
- Tree: 4adbc7403a9bebc34b0181f2e3f5e72cbb821a1e
- Base: `origin/develop` `fa75e83`
- Rows validated: §5 5.22, 5.23, 5.26; §9 9.2, 9.3, 9.4, 9.5; decision S-1 (vignette §3.4)

## Profile gates

The leader ran the gates on tree `8192c49`. The tester did not rerun them, as the dispatch instructed. `git diff --stat 8192c49 'HEAD^{tree}'` lists one file, `changelog/fix-replicate-supplied-args.md` (4 insertions, 5 deletions). `.Rbuildignore` excludes `^changelog$`, so no gate result depends on that change.

| # | Gate | Result | Log |
|---|---|---|---|
| 1 | `devtools::document()` | PASS — wrote nothing; the working tree stays clean | `logs/gate-1-document.log` |
| 2 | `devtools::test()` | PASS — `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 12757 ]`; 256 is the pre-existing AAPOR count, so no new warning | `logs/gate-2-test.log` |
| 3 | `devtools::run_examples()` | PASS — log ends in the expected example warnings, no error | `logs/gate-3-examples.log` |
| 4 | `R CMD build` | PASS — `creating vignettes ... OK`, `surveycore_1.1.0.9000.tar.gz` built | `logs/gate-4-build.log` |
| 5 | `R CMD check --as-cran --no-manual` | PASS — `Status: 1 NOTE`; the Status line is present in both logs | `logs/gate-5-check.log`, `logs/gate-5-00check.log` |
| 6 | `pkgdown::build_site()` | PASS — site finished; `articles/creating-survey-objects.html` written. One pandoc `[WARNING] Duplicate identifier 'non-probability-samples'` in the llms step; the same line is in the pkgdown logs of PRs 1 to 4, so it is pre-existing | `logs/gate-6-pkgdown.log` |
| 7 | `covr` (`NOT_CRAN=true`) | PASS — 96.18% (`COVERAGE_PCT=96.18`), at or above the 95% floor | `logs/gate-7-covr.log` |

NOTEs:

| NOTE | Pre-approved |
|---|---|
| `checking CRAN incoming feasibility` | Yes |

The pre-existing `.git` hidden-file note did not appear in this run.

## Criterion G (plan §Standard gates)

| # | Check | Result | Evidence |
|---|---|---|---|
| G1 | `document()` leaves no diff | PASS | gate 1; `git status` clean |
| G2 | 0 failures, 256 warnings | PASS | gate 2 |
| G3 | examples clean | PASS | gate 3 |
| G4 | check Status line, notes | PASS | `Status: 1 NOTE`, CRAN incoming feasibility only |
| G5 | pkgdown no errored page | PASS | gate 6 |
| G6 | coverage ≥ 95%, no added line uncovered | PASS | 96.18%. Uncovered in `R/core-constructors.R`: 414, 2115, 2206. The PR's added `R/` lines are 619–623, 631–647, 660–662, 692–710 and 1538–1542 (roxygen) and 995–998 (the `class = c(...)` code). None is in the uncovered list |
| G7 | `air format --check` on changed `.R` files | PASS | `R/core-constructors.R`: exit 0. `tests/testthat/test-constructors.R`: exit 1 on both the `develop` blob and the HEAD blob; a formatted copy of each gives a 497-line diff with identical hunk bodies, and the first rewrite is at line 4280. The PR adds lines 2160–2276 only, so air proposes no change in the PR's lines (same reading as the PR 2 to PR 4 audits) |
| G8 | snapshots: only the named new entry | PASS | `git diff origin/develop...HEAD -- tests/testthat/_snaps/` adds one entry, "as_survey_replicate() raises the rho warning before the discard warning", and changes no existing entry. The targeted run left `_snaps/` unmodified |
| G9 | diff paths | PASS | 10 paths, none under `.surveycore-workspace/`. 8 are Files touched plus `vignettes/creating-survey-objects.Rmd` (S-1); the other 2 sit under `plans/` |
| G10 | `as_survey_nonprob()` body byte-identical to `develop` | PASS | srcref extraction from both blobs: develop lines 1637–1934, HEAD lines 1681–1978, 298 lines each, `identical()` TRUE, `cmp` byte-identical. The only nonprob change is the 5-line roxygen hunk at HEAD 1538–1542 |

## Per-test result table

The tester ran `tests/testthat/test-constructors.R` with `NOT_CRAN=true` through `testthat::test_local()` and a `ListReporter`. File totals: 334 blocks, 1142 expectations, 0 failed, 0 skipped, 0 errors, 16 warnings (part of the suite's pre-existing 256).

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| 5.22 "rho warning carries the replicate_arg_ignored class", 8 types × 3 expectations | 24 of 24 pass | both classes on the `rho` warning; `rho` stored as `NULL` | — | ✓ |
| 5.23 "raises the rho warning before the discard warning" | 3 of 3 pass; new snapshot shows the `rho` warning first, then the `scale` discard warning | 2 warnings, `rho` first, stored scale `1 / 20` | 1e-8 | ✓ |
| 5.23 "raises the rho warning and one discard warning for scale, rscales and rho together", JK2/ACS/successive-difference × 6 | 18 of 18 pass | 2 warnings, `rho` first, one plural discard warning; scale `1`, `4 / 20`, `4 / 20`; `rscales` and `rho` `NULL` | 1e-8 | ✓ |
| 5.23 existing `rho`-on-BRR snapshot unchanged | no change in `_snaps/constructors.md` beyond the one added entry | byte-identical | — | ✓ |
| 5.26 "surveycore_error_stratified_jk_rscales_unset fires for JK2 with rscales = NULL" | 2 of 2 pass; snapshot unchanged | pass, snapshot byte-identical | — | ✓ |
| 5.26 "surveycore_error_stratified_jk_rscales_unset fires for JKn with rscales = NULL" | 2 of 2 pass; snapshot unchanged | pass, snapshot byte-identical | — | ✓ |
| 9.2 `leaves no jackknife factor` in `man/as_survey_replicate.Rd` (joined with `tr '\r\n' '  '`) | 0 in HEAD Rd, 0 in roxygen source, 1 in the `develop` Rd | 0, 0, 1 | — | ✓ |
| 9.2 eleven required literals of task 5 in the Rd (`grep -ci`) | 1 each: `as given`, `the type's own value`, `discarded with no warning`, `surveycore_warning_replicate_arg_ignored`, `warns on every`, `combined weights`, `reproduce numbers published before these two defaults moved`, `required for`, `the variance treats as`, `including the three that ignore it`, `raises both` | 1 each | — | ✓ |
| 9.2 Rd states JKn requires `rscales` and the JK2 no-warning divergence | both stated in `\item{scale}` | stated | — | ✓ |
| 9.3 `non-probability design class` in `man/as_survey_nonprob.Rd` | 1; the sentence also says `as_survey_replicate()` accepts `"JK2"` with no `rscales`, as `survey::svrepdesign()` does | 1 | — | ✓ |
| 9.4 `NEWS.md` development section | two entries under `## Breaking changes` (line 73), one citing #255, one citing #255 and #244 with "pass `rscales` with one entry per replicate column, for example `(n_h - 1) / n_h`"; one `as_svydesign()` entry under `## Bug fixes` (line 160) citing #255. All three sit above `# surveycore 1.1.0` (line 438) | as specified | — | ✓ |
| 9.5 `devtools::document()` produces no diff | wrote nothing | no diff | — | ✓ |
| AC-6 changelog | `changelog/fix-replicate-supplied-args.md` has `## Summary`, `## Files Modified`, `## Changes`, `## Verification`; names #255 and #244; six branches; PRs #311, #312, #314, #315, #316 and this PR; gate figures 12757 and 96.18% | as specified | — | ✓ |
| S-1 vignette §3.4 | diff is 12 insertions, 2 deletions, all under `### 3.4 The scale and rscales arguments` (lines 345–362). States: BRR, JK2, ACS, successive-difference ignore a supplied `scale`, and JK2, ACS, successive-difference ignore a supplied `rscales`, with `surveycore_warning_replicate_arg_ignored`; `type = "JKn"` requires `rscales`; "For the other types, override `scale` or `rscales` only when your codebook's technical documentation specifies custom values". Gates 4 and 6 built it | three facts, no other change | — | ✓ |

Test hygiene checks on the added test lines:

| Check | Result |
|---|---|
| Every new `expect_equal()` carries `tolerance =` | 2 new calls, both `tolerance = 1e-8` on a stored scale (plan value 1e-8) |
| `suppressWarnings(` or `expect_failure(` in added test code (plan's check) | 0 |
| New `test_invariants()` calls | 0 |
| No row id in a new `test_that()` title | none |

## CRAN cookbook violations

None. The PR's only changed non-roxygen `R/` lines are the four lines of the `class = c("surveycore_warning_rho_ignored", "surveycore_warning_replicate_arg_ignored")` argument in `R/core-constructors.R`. No pattern of `r-package-profile.md` §CRAN cookbook scan matches them.

## Before/after comparison

| Metric | Before PR (develop after PR 5) | After PR | Δ |
|---|---|---|---|
| tests passing | 12712 | 12757 | +45 |
| test warnings | 256 | 256 | 0 |
| test failures | 0 | 0 | 0 |
| coverage | 96.18% | 96.18% | 0 |
| R CMD check notes | 1 (CRAN incoming feasibility) | 1 (CRAN incoming feasibility) | 0 |

The +45 equals the three new blocks: 24 (5.22: 8 types × 2 `expect_warning` + 1 `expect_null`) + 3 (5.23 snapshot block) + 18 (5.23 combined block: 3 types × 6). No existing block changed its expectation count.

## Notes for the reviewer

- Reviewer checklist items R5a, R3 and N1 are for the reviewer. The tester saw text in the Rd that each item looks for, but did not tick them.
- `\item{rscales}` says "For `"JKn"` and the other five types, `"JK1"`, `"BRR"`, `"Fay"`, `"bootstrap"` and `"other"`, a supplied `rscales` is stored as given". That lists six types in total, which is the right set (nine minus the three that ignore it).
