# Audit — PR 1 fay-rho-constructor

**Verdict**: PASS
**Branch**: feature/fay-rho-constructor, HEAD f8f78d8 (re-audit; first audit on 025ae7d), base develop 0691dbd
**Tree**: a11fe29e6efdef378603fc922820d5968aa3e4f2
**Rows**: §1 1.1, 1.2, 1.4a, 1.5, 1.7, 1.10, 1.11; §6 6.1, 6.8, 6.9, 6.14
**Oracle version**: survey 4.5 (matches the version test-spec.md records)

## Profile gates

The orchestrator ran the gates on this tree. The tester did not re-run them (low memory on the host).
Logs: `prs/pr-1-fay-rho-constructor/gates/`.

| Gate | Result | Notes |
|---|---|---|
| devtools::document() | PASS | wrote nothing |
| devtools::test() | PASS | FAIL 0, WARN 256, SKIP 4, PASS 12129 |
| run_examples() | PASS | the Fay example (`rho = 0.5`) ran; gate-3 log line 167 |
| R CMD build | PASS | surveycore_1.1.0.9000.tar.gz |
| R CMD check --as-cran --no-manual | PASS | 0 errors, 0 warnings, 2 NOTEs: CRAN incoming feasibility (pre-approved); hidden `.git` (pre-existing, accepted per plan criterion G4) |
| pkgdown build_site | PASS | site built |
| covr (NOT_CRAN=true) | PASS | 96.15%; see §Coverage of new lines |
| G7 air format --check | PASS (PR lines) | see §air |
| G8 snapshots | PASS | only the named entries changed |
| G9 files touched | PASS | the diff lists exactly the nine files in the plan |

Tree: a11fe29e6efdef378603fc922820d5968aa3e4f2

### air

- `air format --check` (air 0.11.0) passes on `R/core-constructors.R`, `R/utils.R`, `tests/testthat/test-conversion.R` and `tests/testthat/test-variance-replicate.R`.
- It flags `tests/testthat/test-constructors.R`. The same file at 0691dbd is flagged too.
- Formatting both copies gives 60 hunks each. Every hunk on the branch is the develop hunk moved down 163 lines, which is the size of this PR's insertion. The first hunk is at line 1869 (1706 on develop). The PR's edits sit at lines 975 to 1172. No air change touches a PR line.

### Coverage of new lines

Uncovered lines named by covr, checked against the diff hunks of 0691dbd...HEAD:

| Line | In PR diff? | Note |
|---|---|---|
| core-constructors.R:414 | no | pre-existing |
| core-constructors.R:902 | yes | `"a value of length 0"` branch of `{rho_txt}`. Row 1.9 (`rho = numeric(0)`) reaches it; the plan assigns row 1.9 to PR 2. Not a regression: coverage holds at 96.15% |
| core-constructors.R:1981 | no | pre-existing |
| core-constructors.R:2072 | no | pre-existing |
| utils.R:377 | no | pre-existing |
| utils.R:487 | no | pre-existing |

## Per-test result table

Filtered run `devtools::test(filter = "^(constructors|conversion|variance-replicate)$")`, NOT_CRAN=true: constructors 815 expectations, 0 failed; conversion 802, 0 failed; variance-replicate 192, 0 failed. Values below are from a direct probe on FT (R = 20).

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| 1.1 Fay rho=0.3: `@variables$rho` | 0.3 | 0.3 | 1e-10 (set in the test since f8f78d8; on 025ae7d the line set none, so the default of about 1.49e-8 applied) | ✓ (diff 0) |
| 1.1 Fay rho=0.3: `@variables$scale` | 0.10204081632653063 | 1/(20*0.7^2) = 0.10204081632653063 | 1e-8 | ✓ (diff 0) |
| 1.1 Fay rho=0.3: `@variables$type` | "Fay" | "Fay" | identical | ✓ |
| 1.2 nine-type default block, Fay line at rho=0.3 | block 10/10 pass | Fay `1/(n_rep*(1-0.3)^2)`; other 8 lines unchanged (diff shows) | Fay line: 1e-8 (set in the test since f8f78d8; on 025ae7d the line set none, so the default of about 1.49e-8 applied). The eight other lines set none and are unchanged from develop | ✓ (diff 0) |
| 1.4a formal names | data, weights, repweights, type, rho, scale, rscales, fpc, fpctype, mse, calibration | same | identical | ✓ |
| 1.5 Fay, no rho: class | surveycore_error_fay_rho_missing | same | class | ✓ |
| 1.5 snapshot | FR-1 text, names `rho` | FR-1 template in plans/error-messages.md | snapshot | ✓ |
| 1.7 Fay rho=1.5: class | surveycore_error_fay_rho_invalid | same | class | ✓ |
| 1.7 snapshot | FR-2 text, "Got <numeric>: 1.5." | FR-2 template | snapshot | ✓ |
| 1.10 JK1 rho=0.3 | warn rho_ignored; rho NULL; scale 0.95 identical to no-rho call | same | identical | ✓ |
| 1.10 JK2 | warn; NULL; 1 identical | same | identical | ✓ |
| 1.10 JKn | warn; NULL; 1 identical | same | identical | ✓ |
| 1.10 BRR | warn; NULL; 0.05 identical | same | identical | ✓ |
| 1.10 bootstrap | warn; NULL; 1/19 identical | same | identical | ✓ |
| 1.10 ACS | warn; NULL; 0.2 identical | same | identical | ✓ |
| 1.10 successive-difference | warn; NULL; 0.2 identical | same | identical | ✓ |
| 1.10 other | warn; NULL; 1 identical | same | identical | ✓ |
| 1.11 BRR rho=0.3 warning snapshot | FR-3 text | FR-3 template | snapshot | ✓ |
| 6.1 `rho` entry: Fay requires it, range `[0, 1)`, scale `1 / (R * (1 - rho)^2)` | present in man/as_survey_replicate.Rd | present | text | ✓ |
| 6.8 Fay example with rho runs under run_examples() | ran (gate 3) | runs | gate | ✓ |
| 6.9 layout sentence: two-PSU-per-stratum, Hadamard-balanced, not checked; exact for totals, first-order for means and ratios | present | present | text | ✓ |
| 6.14 `type` stays "Fay" at rho = 0, unlike `survey::as.svrepdesign()` which relabels it "BRR" | present | present | text | ✓ |

### Acceptance criterion 7 (kept and deleted Fay blocks)

| Block | State | Result |
|---|---|---|
| "as_svydesign() recovers rho = 0 from the default Fay scale" | kept, `rho = 0` added | 5/5 pass |
| "every accepted replicate type crosses both conversion routes" | kept, `rho` passed for Fay | 54/54 pass |
| "survey::svrepdesign() refuses Fay without rho — Fay design" | kept, `rho = 0`, comment replaced | 2/2 pass |
| "as_svydesign() refuses a Fay design whose scale yields no rho" | deleted | absent from run; snapshot entry removed from `_snaps/conversion.md` |

Criteria 1 to 8: all met. No new `test_invariants()` call was added.

## CRAN cookbook violations

None. Scanned the added code lines and roxygen lines of `R/core-constructors.R` and `R/utils.R`.

## Before/After comparison

| Metric | Before PR (develop 0691dbd) | After PR (9e2900f) | Δ |
|---|---|---|---|
| tests passing | 12100 | 12129 | +29 |
| test failures | 0 | 0 | 0 |
| test warnings | 256 | 256 | 0 |
| skips | 4 | 4 | 0 |
| coverage | 96.15% | 96.15% | 0 |
| R CMD check notes | 2 | 2 | 0 |

## Re-audit on f8f78d8

- A reviewer STOP (tolerance integrity) found that the first audit, on 025ae7d, gave rows 1.1 (`rho`) and 1.2 (Fay line) tolerances that the tests did not set. Those two `expect_equal()` calls set no `tolerance`, so testthat applied its default of about 1.49e-8.
- Commit f8f78d8 (tree a11fe29e6efdef378603fc922820d5968aa3e4f2) adds `tolerance = 1e-10` to `expect_equal(d@variables$rho, 0.3, ...)` and `tolerance = 1e-8` to the nine-type block's Fay line. `git diff 025ae7d f8f78d8` shows one file, `tests/testthat/test-constructors.R`, with 6 insertions and 2 deletions, and no other change.
- Rows 1.1 and 1.2 above now state the tolerance each line sets. Both match the test-spec: 1e-10 for a point value, 1e-8 for a stored scale. The measured difference on both lines is 0.
- The orchestrator's filtered constructors run on f8f78d8: FAIL 0, PASS 799. The tester started no R process for this re-audit.
- air on the f8f78d8 copy of `test-constructors.R`: the first change is at line 1873, which is the develop hunk moved down by the 4 added lines. No air change touches a PR line.
- The gate table above still shows the 9e2900f run. The orchestrator replaces it with the rerun on a11fe29.

## Observations (not blocking)

- Three new test titles exceed 80 characters. air does not rewrap strings, so gate G7 does not see them.
