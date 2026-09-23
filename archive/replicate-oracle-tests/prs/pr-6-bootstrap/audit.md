# audit.md — PR 6, `test/replicate-oracle-bootstrap`

**Verdict**: PASS (10 of 10 allocated rows)
**Tree**: `a8455700b9ae18c642daad8c5911799eb020ce4d`
**HEAD**: `e4d8657f0df9cf7ffc340dfb28346fc3de5019b7`
**Base**: `bbafed090cb93a63915dd5704d1f361228e2032d`
**Test-spec**: `.surveycore-workspace/runs/2026-09-16-replicate-oracle-tests/test-spec.md` [no such file]
**Diff**: `81 0 tests/testthat/test-variance-replicate.R` (`git diff --numstat`) —
append-only, zero deletions, so the JKn block is byte-identical to the base.

The verdict covers the ten allocated rows. The leader's gate pass on this tree
is clean, so the verdict stands; see §Profile gates.

## Instrument

No R process ran. A gate pass was in flight on this tree.

| Step | Instrument | File |
|---|---|---|
| Comment strip | `awk`, char walk, quote- and escape-aware | `scratchpad/strip.awk` |
| Paren depth | `awk`, running `([{` counter, depth at line start | `scratchpad/depth.awk` |
| Wrapper spans | `awk`, walks each `expect_failure(` to its matching close paren, counts inner `expect_*(` | `scratchpad/wrappers.awk` |
| Comment string | `grep -Fxc` on the 99-character literal | — |
| Format | `air format --check` (CLI, not R) | — |

Depth convention: `d0` file level, `d2` `test_that()` body level, `d3` inside a
body-level call.

**Instrument validation.** The stripper reproduces the builder's parser counts
exactly, against the `grep -c` line counts the dispatch warns about:

| Token | `grep -c` (lines) | This instrument (code calls) | Builder's parser |
|---|--:|--:|--:|
| `expect_failure(` | 12 | **6** | 6 |
| `svrepdesign(` | 14 | **12** | 12 |

Per-block code counts, whole file:

| Block | Lines | `expect_failure(` at `d2` | Inner assertions each | Unwrapped ratio assertion |
|---|---|--:|--:|--:|
| JKn (pinned, from PR 5) | 806–884 | 3 (865, 868, 871) | 1, 1, 1 | 1 (879, `d2`) |
| bootstrap (pinned, new) | 886–965 | 3 (942, 949, 952) | 1, 1, 1 | 1 (960, `d2`) |

All six wrappers in the file sit in these two blocks.

## Per-test result table

| Row | Check | Block | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|---|---|
| 3.1.5 | no-warning assertion on the design-building call | bootstrap | `expect_no_warning(sv <- survey::svrepdesign(...))` at line 920, `d2` | present | n/a | ✓ |
| 3.1.5 | `survey` stored scale against `1 / (R - 1)` | bootstrap | line 931: `expect_equal(sv$scale, 1 / (n_rep - 1), tolerance = 1e-8)` | `1 / (R - 1)`, `1e-8` | 1e-8 | ✓ |
| 3.1.5 | pinned stored-scale comment above it | bootstrap | line 930, 99 chars, exact match of the fixed string | exact | n/a | ✓ |
| 2.9 | exactly three `expect_failure()` wrappers, one assertion each | JKn | 3 wrappers at 865/868/871; inner `expect_*(` count 1, 1, 1 | 3 | n/a | ✓ |
| 2.9 | same | bootstrap | 3 wrappers at 942/949/952; inner count 1, 1, 1 | 3 | n/a | ✓ |
| 2.10 | point-estimate assertion outside every wrapper | JKn | line 861 at `d2`: `expect_equal(sc_mean$mean, coef(sv_mean)[["y1"]], tolerance = 1e-10)` | outside | 1e-10 | ✓ |
| 2.10 | same | bootstrap | line 937 at `d2`, identical form | outside | 1e-10 | ✓ |
| 2.11 | design call + condition assertion outside every wrapper | JKn | `expect_no_warning(` at 843, `d2`; `svrepdesign(` at 844, `d3`; no wrapper span covers 843–852 | outside | n/a | ✓ |
| 2.11 | same | bootstrap | `expect_no_warning(` at 920, `d2`; `svrepdesign(` at 921, `d3`; no wrapper span covers 920–928 | outside | n/a | ✓ |
| 2.15 / 3.6.1 | exactly one unwrapped ratio assertion | JKn | 1, at 879–883 | 1 | n/a | ✓ |
| 2.15 / 3.6.1 | same | bootstrap | 1, at 960–964 | 1 | n/a | ✓ |
| 3.6.2 | ratio assertion sits inside no wrapper | JKn | starts `d2` at 879; wrapper spans end at 873 | outside | n/a | ✓ |
| 3.6.2 | same | bootstrap | starts `d2` at 960; wrapper spans end at 954 | outside | n/a | ✓ |
| 3.6.3 | compares against the literal `sqrt((R - 1) / R)`, `R` read from the columns | JKn | `sqrt((n_rep - 1) / n_rep)`; `n_rep <- length(repwt_cols)`, `repwt_cols <- grep("^repwt_", names(d), value = TRUE)` | literal, `R` read | n/a | ✓ |
| 3.6.3 | same | bootstrap | identical two lines at 907–908; literal at 962 | literal, `R` read | n/a | ✓ |
| 3.6.3 | ratio is surveycore over `survey`, value below 1 | JKn | `sc_mean$se / as.numeric(survey::SE(sv_mean))` vs `sqrt(19/20) = 0.9747` | `< 1` | n/a | ✓ |
| 3.6.3 | same | bootstrap | same numerator/denominator order | `< 1` | n/a | ✓ |
| 3.6.4 | ratio assertion tolerance | JKn | `tolerance = 1e-8` (line 882) | 1e-8 | 1e-8 | ✓ |
| 3.6.4 | same | bootstrap | `tolerance = 1e-8` (line 963) | 1e-8 | 1e-8 | ✓ |
| 2.16 | comment names #253 and says FOUR lines | JKn | "When issue #253 lands, delete FOUR lines: the three expect_failure() wrapper lines and the ratio assertion at the end of this block." | #253 + four | n/a | ✓ |
| 2.16 | same | bootstrap | "When issue #253 lands, delete FOUR lines: the three expect_failure() / wrapper lines and the ratio assertion at the end of this block." | #253 + four | n/a | ✓ |

Allocated-row tally: **10 of 10 pass**. Nine rows were read on both pinned
blocks; every both-block row holds on both.

No tolerance in this PR was changed, questioned or relaxed. The three values the
blocks carry — `1e-10` point, `1e-8` standard error and stored scale, `1e-6`
confidence bounds — are the `testing-surveycore.md` rows and the test-spec
values.

**Row 3.1.5's numerical half is settled by gate 2.** The structural half is the
three rows above: the no-warning assertion, the stored-scale assertion against
`1 / (R - 1)` at `1e-8`, and the pinned comment. Gate 2 returned `FAIL 0` on
this exact tree, which proves both assertions pass against the installed
`survey`.

## This PR's own acceptance criteria

| Criterion | Evidence | Pass |
|---|---|---|
| The bootstrap block sits after the JKn block | JKn `test_that(` at 806, bootstrap at 886 | ✓ |
| Both sit under the existing `# Block 24:` header | header at line 803, unchanged from base | ✓ |
| No new `# Block N:` header | base and HEAD both list 7 headers: 10, 11, 12, 16, 22, 23, 24, at identical line numbers | ✓ |
| No header renumbered | same list, byte-identical | ✓ |
| Title names the disagreement | `get_means() bootstrap SE disagrees with survey::svymean() — issue #253` | ✓ |
| Title names issue #253 | same line | ✓ |
| Title claims no match | verb is "disagrees" | ✓ |
| `mse` explicit on both sides | `mse = TRUE` in `as_survey_replicate()` (915) and in `svrepdesign()` (925) | ✓ |
| No `scale =` in the new block | `grep` of added lines: none | ✓ |
| No `rscales` in the new block | `grep` of added lines: none (3.1.5 asks for none) | ✓ |
| No `suppressWarnings(` in the new block | `grep` of added lines: none | ✓ |
| `air format --check` | exit 0, no output | ✓ |

## Settled conventions — conformance

| Convention | Measured | Pass |
|---|---|---|
| Stored-scale comment is the fixed 99-character string | new instance at line 930 is 99 chars and an exact `grep -Fxc` match | ✓ |
| Exact matches: 12 at HEAD, 11 at base | `grep -Fxc`: HEAD 12, base 11 | ✓ |
| Line ~174 `expect_equal(sc@variables$scale, 1)` untouched | zero deletions in the diff; the line is outside the added range | n/a — finding N2, not a defect |

## CRAN cookbook violations

None. The PR modifies no file under `R/`; the write surface is one test file.

## Before/After comparison

| Figure | Baseline (`7800ea9`) | PR 3 | PR 4 | PR 5 | This PR | Δ vs PR 5 |
|---|---|---|---|---|---|---|
| Failures | 0 | 0 | 0 | 0 | 0 | 0 |
| Warnings | 256 | 256 | 256 | 256 | 256 | 0 |
| Skips | 4 | 4 | 4 | 4 | 4 | 0 |
| Passes | 11941 | 11977 | 11982 | 11989 | 11996 | **+7** |
| Coverage | 96.15% | 96.15% | 96.15% | 96.15% | 96.15% | 0.00 |
| `R CMD check` NOTEs | 2 | 2 | 2 | 2 | 2 | 0 |

**The +7 corroborates row 2.9 from a second direction.** PR 5's JKn block
contributed +7 as well. Two blocks of the same shape contribute the same
expectation count, which is what "three and three, one and one" produces at
suite level; a structural difference between them would show as a different
delta. It agrees with the depth analysis rather than replacing it.

Failures stay at 0 although six assertions in the file now fail by design. Each
one is consumed by its own `expect_failure()` wrapper, and the wrapper is what
passes.

## Profile gates

Run on tree `a8455700b9ae18c642daad8c5911799eb020ce4d` — the tree the `Tree:`
line above records. The leader ran the pass; this agent started no R process.

| Gate | Result | Notes |
|---|---|---|
| `devtools::document()` | PASS | `document()` wrote nothing |
| `devtools::test()` | PASS | `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11996 ]` |
| `run_examples()` | PASS | all examples ran |
| `R CMD build` | PASS | `surveycore_1.1.0.9000.tar.gz` |
| `R CMD check --as-cran --no-manual` | PASS | Status: 2 NOTEs |
| pkgdown | SKIPPED — scope | one test file; `NAMESPACE` diff empty |
| `covr` | PASS | 96.15% |

Logs: `.surveycore-workspace/runs/2026-09-16-replicate-oracle-tests/logs/pr6/`

### Both NOTEs are pre-existing — neither is a new pattern

| NOTE | Why it does not block |
|---|---|
| `checking CRAN incoming feasibility` | Pre-approved in `.claude/rules/r-package-conventions.md`; the package is not on CRAN |
| `checking for hidden files and directories` | `R CMD build` finds `.git`; caused by `.Rbuildignore`, present on the clean baseline, and this arc cannot fix it |

Both appear identically on the baseline and on PRs 1 to 5. Read gate 5 as
"2 NOTEs, and these two". A third NOTE blocks. The second NOTE is not a new
pattern and needs no escalation.

The pkgdown skip meets the `r-package-profile.md` scope condition: the write
surface is one file under `tests/testthat/`, it touches no file in `R/`,
`vignettes/`, `README`, `_pkgdown.yml` or `DESCRIPTION`, and the `NAMESPACE`
diff is empty, so the hard rule on changed exports does not apply.
