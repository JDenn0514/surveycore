# Audit — PR 5 `fix/fay-rho-export`

**Verdict: PASS**

Tree: 8183fde507d9a7a3a069e40f301de9e600ec0162
HEAD: da79200. Base: develop 0b7e623 (tree dd70f9e).
Oracle: `survey` 4.5 under R 4.6.1 (confirmed on this machine), the version
the test-spec records.

## Profile gates

The orchestrator ran the gates on tree 8183fde. The tester did not re-run
them (low memory). Logs: `prs/pr-5-fay-rho-export/gates/`.

| Gate | Result | Notes |
|---|---|---|
| devtools::document() | PASS | document() wrote nothing |
| devtools::test() | PASS | FAIL 0, WARN 256, SKIP 4, PASS 12242 |
| run_examples() | PASS | all examples ran |
| R CMD build | PASS | surveycore_1.1.0.9000.tar.gz |
| R CMD check --as-cran --no-manual | PASS | Status: 2 NOTEs |
| pkgdown | PASS | site built |
| covr | PASS | 96.16% |

NOTE review:

- `checking CRAN incoming feasibility`: pre-approved.
- `checking for hidden files and directories` (`.git`): pre-existing on
  `develop`, present in the Before run, caused by `.Rbuildignore`. The PR
  does not touch it. It is the same note the as-svydesign-bridge archive
  records.

WARN 256 equals the Before count, so the PR adds no warning (decision D12 of
the svydesign-replicate-bridge archive reads gate 2 as "no new warning").

Coverage of `R/methods-conversion.R`: 99.76%, one uncovered line, 621. Line
621 is `return(NULL)`. `git blame` gives commit b1ef82dd (2026-04-01), and
line 649 on 0b7e623 holds the same text. The PR deletes 28 net lines above
it. Line 621 is the pre-existing line 649, moved. It is not new code.

## Per-test result table

Filtered run: `NOT_CRAN=true devtools::test(filter = "^conversion$")`:
845 expectations, 0 failed, 0 errors, 0 warnings, 0 skipped.
Got values for 3.1, 3.2 and 3.1a come from a separate reproduction of the
same fixtures.

| Row | Test block | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|---|
| 3.1 | exports a Fay design built with rho = 0.3 | no warning; `svyrep.design`; rho 0.3; scale 0.408163265306123 | rho 0.3; scale `1/(5*0.7^2)` = 0.408163265306122 | rho 1e-10; scale 1e-8 | ✓ |
| 3.1 | same block, mean and SE vs `get_means()` | mean diff 0; SE diff 4.2e-15 | equal | mean 1e-10; SE 1e-8 | ✓ |
| 3.1a | exports a Fay design with a domain column | rho 0.3; scale 0.204081632653061; mean diff 0; SE diff 5.1e-16 | rho 0.3; scale `1/(10*0.7^2)`; equal | rho 1e-10; scale 1e-8; mean 1e-10; SE 1e-8 | ✓ |
| 3.2 | exports a Fay design built with rho = 0 | rho 0; scale 0.2 | rho 0; scale `1/5` | rho 1e-10; scale 1e-8 | ✓ |
| 3.3 | passes no rho for a BRR design | no warning; `sv$rho` NULL | NULL | identity | ✓ |
| 3.4 | refuses a Fay design with no rho key | class CB-4; message has `rho` and `as_survey_replicate`; snapshot | same | class | ✓ |
| 3.5 | refuses a Fay design whose rho key is NULL | class CB-4; key present | same | class | ✓ |
| 3.6 | refuses a Fay design whose stored rho is 1.5 | class CB-4 | same | stored rho 1e-10; class | ✓ |
| 3.7 | refuses a Fay design that records no scale | class CB-4; snapshot; "none" match removed | same | class | ✓ |
| 4.5 | survey Fay design with rho = 1.5 | import: no condition; rho 1.5; export: CB-4 | same | rho 1e-10; class | ✓ |
| 4.5a | survey Fay design with rho set to NA | import: no condition; rho identical to NA; export: CB-4 | same | identity; class | ✓ |
| 4.5b | survey Fay design with no rho element | import: no condition; rho NULL; export: CB-4 | same | identity; class | ✓ |
| 4.7 | exports a Fay design with its scale and SE | passes; diff touches comments only | passes unchanged | unchanged (1e-10 on rho and scale) | ✓ |

`test_invariants()`: the PR adds no call. Its new blocks extend the
existing file, which already calls it per constructor.

## Tolerance integrity

Every numeric `expect_equal()` in a new or edited block sets `tolerance =`:

| Block | Assertion | Tolerance |
|---|---|---|
| rho = 0.3 | `sv$rho`; `sv$scale`; mean; SE | 1e-10; 1e-8; 1e-10; 1e-8 |
| rho = 0 | `sv$rho`; `sv$scale` | 1e-10; 1e-8 |
| domain column | `sv$rho`; `sv$scale`; mean; SE | 1e-10; 1e-8; 1e-10; 1e-8 |
| stored rho is 1.5 | `d@variables$rho` | 1e-10 |
| survey rho = 1.5 | `d@variables$rho` | 1e-10 |
| 4.7 (unchanged) | `sv$rho`; `sv$scale` x2 | 1e-10 each |

Each value equals or is tighter than the test-spec value. None is relaxed.

## Oracle rule

- No `suppressWarnings()` in any added line of `test-conversion.R`.
- `make_fay_svrep()` calls `survey::svrepdesign()` bare. A warning from it
  would raise the WARN count; the filtered run shows 0 warnings.
- The new blocks match no `survey` condition, so no class-based match of a
  `survey` condition exists.
- The export rows are round-trip rows ([round trip] in the test-spec). They
  pass no `scale` to `survey`; the route passes `rho` only.

## Snapshots (criterion 5)

`git diff 0b7e623 -- tests/testthat/_snaps/conversion.md` holds two hunks:

- new entry "as_svydesign() refuses a Fay design with no rho key";
- the rewritten entry "as_svydesign() refuses a Fay design that records no
  scale", with the new CB-4 text.

No other entry changes. The removed block "refuses a Fay design whose scale
yields no rho" had no snapshot on 0b7e623, so no entry needed deletion. The
removed block "recovers rho = 0 from the default Fay scale" is gone from the
test file.

## Acceptance criteria

| # | Check | Result |
|---|---|---|
| 1 | 3.1, 3.1a pass | ✓ |
| 2 | 3.2, 3.3 pass | ✓ |
| 3 | 3.4 to 3.7 pass | ✓ |
| 4 | 4.5, 4.5a, 4.5b pass | ✓ |
| 5 | 4.7 assertions unchanged; recover block removed; snapshot diff is the two CB-4 entries only | ✓ |
| 6 | CB-4 row restated (line 532); `{scale_txt}` occurs nowhere; the #243 sentence is at line 535 under the CB block | ✓ |
| 7 | `R/methods-conversion.R` has no text saying rho is recovered or derived from the scale (search for recover, deriv, shrink, rho; the scale is said to be computed from rho) | ✓ |
| 8 | Gates (G) | ✓ |

Files touched: the diff touches exactly the four files the plan lists.

## CRAN cookbook violations

None. Scanned the 19 added lines of `R/methods-conversion.R`.

## Before/After comparison

| Metric | Before PR (0b7e623) | After PR (8183fde) | Δ |
|---|---|---|---|
| tests passing | 12213 | 12242 | +29 |
| tests failing | 0 | 0 | 0 |
| warnings | 256 | 256 | 0 |
| skips | 4 | 4 | 0 |
| coverage | 96.16% | 96.16% | 0 |
| R CMD check notes | 2 | 2 | 0 |

Coverage is under the 98% target on both sides. It did not drop, and it is
above the 95% floor.

## HOLDs

None.
