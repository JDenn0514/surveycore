# Audit — PR 3 — as-svydesign-domain-replicate-nonprob

**Verdict**: PASS
**Date**: 2026-09-11

Tree: `5819738648687bc08c7a7fa40204826aaec51864`

## Scope confirmation

`git diff origin/develop...HEAD --stat` shows two files: `R/methods-conversion.R`
(4 lines changed, inside `.as_svydesign_replicate()`) and
`tests/testthat/test-conversion.R` (269 lines added). The new test section is
`# ── Domain restriction on the replicate route and both nonprob shapes ──`,
`tests/testthat/test-conversion.R:3509-3775`. `git diff origin/develop...HEAD --
tests/testthat/_snaps` is empty — no snapshot file changed.

## Per-Test Result Table

| Test (row) | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| A-2 point (`as_svydesign() converts a filtered replicate design to the domain`, line 3547) | 58.201931620013049 | 58.201931620013049 (get_means) | 1e-10 | ✓ |
| A-2 SE | 0.090101656135978 | 0.090101656135976 | 1e-8 | ✓ |
| A-2 marker present / all TRUE | TRUE / TRUE | TRUE / TRUE | exact | ✓ |
| A-2 row count | 25 | sum(mask) = 25 | exact | ✓ |
| A-3 point (`... converts a filtered replicate nonprob to the domain`, line 3593) | 54.900414525428928 | 54.900414525428928 | 1e-10 | ✓ |
| A-3 SE | 0.084776296152121 | 0.084776296152116 | 1e-8 | ✓ |
| A-3 marker present / all TRUE | TRUE / TRUE | TRUE / TRUE | exact | ✓ |
| A-3 row count | 20 | sum(mask) = 20 | exact | ✓ |
| C-2 (unfiltered replicate, no FPC, line 3614) | no condition; nrow 50 = design nrow 50; marker absent | none tolerated; row count unchanged; no marker | — | ✓ |
| C-4 (unfiltered replicate nonprob, line 3626) | no condition; nrow 40 = design nrow 40; marker absent | none tolerated; row count unchanged; no marker | — | ✓ |
| C-5 (unfiltered plain nonprob, line 3640) | exactly 1 condition, `surveycore_warning_nonprob_srs_conversion`; nrow 40 = design nrow; marker absent | that one warning tolerated, nothing else; row count unchanged; no marker | — | ✓ |
| D-2b (all-FALSE replicate, line 3660) | conversion: no condition, nrow 0; `survey::svymean()` errors `simpleError`, message "All replicates contained NAs" | no condition on conversion; untyped error, message match, no class, no snapshot | message match | ✓ |
| D-2d part 1 (all-FALSE replicate nonprob, line 3676) | no condition; nrow 0 | no condition; zero rows | — | ✓ |
| D-2d part 2 (all-FALSE plain nonprob, line 3690) | exactly 1 condition, `surveycore_warning_nonprob_srs_conversion`; nrow 0 | that warning only; zero rows | — | ✓ |
| E-2 (`as_tbl_svy()` filtered plain nonprob, line 3711) | exactly 1 condition, `surveycore_warning_nonprob_srs_conversion`; `inherits(ts,"tbl_svy")` TRUE; nrow 20 = sum(mask) 20 | warning class captured; tbl_svy; domain row count; no second snapshot | — | ✓ |
| G-1b (filtered replicate no-FPC + filtered replicate nonprob, line 3729) | both calls raise no condition | `expect_no_condition()` on both | — | ✓ |
| G-2 (filtered plain nonprob, line 3740) | exactly 1 condition, `surveycore_warning_nonprob_srs_conversion`; nrow 20 = sum(mask) 20 | fires exactly once, nothing else; domain row count | — | ✓ |
| G-3 (filtered replicate with FPC, line 3759) | exactly 1 condition, `surveycore_warning_replicate_fpc_dropped`; nrow 25 = sum(mask) 25; marker all TRUE | fires exactly once, nothing else; domain row count; result read off return value | — | ✓ |

All eleven claimed rows (A-2, A-3, C-2, C-4, C-5, D-2b, D-2d, E-2, G-1b, G-2,
G-3) map to one or more blocks in the new section, and my own fresh
`Rscript`/`devtools::load_all()` reproduction of each scenario matches the
test file's assertions exactly (see raw output retained in session scratchpad
`verify_pr3.R`). No block was found that under-asserts its row.

D-2b specifically: confirmed `expect_error()` carries no `class =` argument
and the snapshot diff for this PR is empty, so no golden file was added for
the untyped `survey` message — matches the row's requirement exactly.

G-3 specifically: `expect_warning(sv <- ..., class =
"surveycore_warning_replicate_fpc_dropped")` wraps the call, `sv` (the return
value) is what the row-count and marker assertions read, and the outer
`expect_no_warning()` tolerates nothing else. My own reproduction shows
exactly one condition fired.

`test_invariants()`: no call appears anywhere in lines 3509-3775 (the new
section). The file's six pre-existing calls (lines 121, 770, 1173, 2166, 2795,
plus one documented deliberate omission comment at 2293) are all before line
2800, i.e. unrelated to and untouched by this PR — consistent with the
once-per-constructor-per-file rule, since `as_survey_replicate()` and
`as_survey_nonprob()` were already covered earlier in the file.

## Before/After Comparison

| Metric | Before PR | After PR | Δ |
|---|---|---|---|
| tests passing | 11706 | 11749 | +43 |
| tests failing | 0 | 0 | 0 |
| warnings | 256 | 256 | 0 |
| skips | 4 | 4 | 0 |
| coverage | 96.25% | 96.25% | 0 |
| R CMD check NOTEs | 2 | 2 | 0 |

No regression in tests-passing or coverage. Coverage figure per dispatch note:
the covr summary's "changed R/ files: 2, uncovered lines in them: 4" is a
stale-local-ref misreport; verified against `origin/develop` this PR changes
one `R/` file (`R/methods-conversion.R`, 4 lines) whose only uncovered line
(573) is a pre-existing `# nocov` branch this PR does not touch.

## Profile gates

Gates were run by the orchestrator (memory-constrained host); this audit
accepts the printed summary and does not re-run them.

| Gate | Result | Notes |
|---|---|---|
| devtools::document() | PASS | document() wrote nothing |
| devtools::test() | PASS | [ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11749 ] |
| run_examples() | PASS | all examples ran |
| R CMD build | PASS | ./surveycore_1.1.0.9000.tar.gz |
| R CMD check --as-cran | PASS | 2 NOTEs: CRAN incoming feasibility (pre-approved); hidden files `.git` (pre-existing, caused by `.Rbuildignore`, accepted on every PR in this arc) |
| pkgdown | PASS | site built (run, not skipped — write surface touches `R/`) |
| covr | PASS | 96.25% |

Tree: `5819738648687bc08c7a7fa40204826aaec51864`

## CRAN cookbook violations

None. Changed `R/` file: `R/methods-conversion.R` only. The diff is:

```
-  survey::svrepdesign(
+  converted <- survey::svrepdesign(
     ...
+
+  .restrict_to_domain(converted)
```

No `T`/`F` abbreviation, no hardcoded `set.seed()`, no bare `print()`/`cat()`,
no `options(warn=-1)`, no `installed.packages()`, no `<<-`, no unrestored
`par()`/`options()`/`setwd()`, no home-directory writes, no `mc.cores`/
`makeCluster` above 2. Zero matches for any cookbook pattern.

| File | Line | Violation | Class |
|---|---|---|---|
| — | — | None | — |

## Tolerance integrity

Every numeric comparison audited (A-2, A-3 point and SE) uses exactly the
test-spec's tolerances: point 1e-10, SE 1e-8. No tolerance was loosened. Both
SE comparisons landed near floating-point noise (~1e-15), far inside 1e-8.

## Verdict

**PASS.** All eleven claimed rows are present in
`tests/testthat/test-conversion.R`, correctly assert what the test-spec
requires, and independently reproduce to the specified tolerances. No CRAN
cookbook violations (single 4-line `R/` diff). No before/after regression.
`test_invariants()` was not duplicated. D-2b and G-3 hold up under the
extra scrutiny the dispatch requested.
