# Audit — PR 4 — replicate-scale-nonprob-divergence

**Verdict**: PASS
**Date**: 2026-09-29

Scope of this audit: test-spec §2 row 2.3, §3 rows 3.1 and 3.2, §4 row 4.2.
Rows 1.x, 2.1, 2.2, 4.1 and 4.3 to 4.6 belong to other PRs in the arc and are
not judged here.

Gates: the orchestrator ran all seven in the foreground, on this tree, before
dispatch. This audit runs no gate — concurrent heavy R runs corrupt each
other's `.Rcheck` tree on this host. The gate numbers below are the
orchestrator's, transcribed. Logs:
`.surveycore-workspace/runs/2026-09-23-replicate-scale-jkn-bootstrap/gates/pr-4/`.

## Per-Test Result Table

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| 2.3 frame A premise — `scale = 1` SE is finite | `is.finite(se)` TRUE | TRUE | exact | ✓ |
| 2.3 frame A premise — `scale = 1` SE > 0 | `expect_gt(se, 0)` holds | > 0 | exact | ✓ |
| 2.3 frame A — stored scale is infinite | `is.infinite(scale)` TRUE | TRUE | exact | ✓ |
| 2.3 frame A — surveycore SE is `Inf` | `is.infinite(se)` TRUE | TRUE | exact | ✓ |
| 2.3 frame A — surveycore both bounds infinite | TRUE, TRUE | TRUE | exact | ✓ |
| 2.3 frame A — `survey` stored scale infinite | `is.infinite(sv$scale)` TRUE | TRUE | exact | ✓ |
| 2.3 frame A — `survey` SE and both bounds infinite | TRUE ×3 | TRUE | exact | ✓ |
| 2.3 frame A — `svrepdesign()` raises no warning | `expect_no_warning()` holds | no warning | n/a | ✓ |
| 2.3 frame B premise — `scale = 1` SE is exactly 0 | `expect_equal(se, 0, tolerance = 0)` holds | `0` | `0` | ✓ |
| 2.3 frame B — stored scale is infinite | `is.infinite(scale)` TRUE | TRUE | exact | ✓ |
| 2.3 frame B — surveycore SE is `NaN` | `is.nan(se)` TRUE | TRUE | exact | ✓ |
| 2.3 frame B — surveycore both bounds `NaN` | TRUE, TRUE | TRUE | exact | ✓ |
| 2.3 frame B — `survey` stored scale infinite | TRUE | TRUE | exact | ✓ |
| 2.3 frame B — `survey` SE and both bounds `NaN` | TRUE ×3 | TRUE | exact | ✓ |
| 2.3 frame B — `svrepdesign()` raises no warning | `expect_no_warning()` holds | no warning | n/a | ✓ |
| 2.3 — no condition from either construction or estimate | `expect_no_condition()` ×6 hold | none | n/a | ✓ |
| 3.1 — replicate JKn stored scale vs the literal | `1` | `1` | `1e-8` | ✓ |
| 3.1 — nonprob JKn stored scale vs the literal | `1` | `1` | `1e-8` | ✓ |
| 3.1 — the two means agree | equal | equal | `1e-10` | ✓ |
| 3.1 — the two standard errors agree | equal | equal | `1e-8` | ✓ |
| 3.2 — replicate bootstrap stored scale vs its literal | `1 / (n_rep - 1)` | `1 / (n_rep - 1)` | `1e-8` | ✓ |
| 3.2 — nonprob bootstrap stored scale vs its literal | `1 / n_rep` | `1 / n_rep` | `1e-8` | ✓ |
| 3.2 — the two means agree | equal | equal | `1e-10` | ✓ |
| 3.2 — SE ratio vs `sqrt((n_rep - 1) / n_rep)` | equal | `sqrt((n_rep - 1) / n_rep)` | `1e-8` | ✓ |
| 4.2 — element 1: `survey`'s bootstrap value | `1/(R - 1)` rendered | `1/(R - 1)` | n/a | ✓ |
| 4.2 — element 2: the matching constructor | `as_survey_replicate()` rendered | that name | n/a | ✓ |
| 4.2 — element 3: the reason for keeping `1/R` | "`survey` has no non-probability design class and so is not an oracle for one" | that reason | n/a | ✓ |
| 4.2 — element 4: the size of the divergence | "smaller … by a factor of `sqrt((R - 1)/R)`, a fall of 2.5% at `R = 20`" | `sqrt((R-1)/R)`, 2.5%, a fall | n/a | ✓ |
| 4.2 — the rendered percentage is the fall, not the rise | 2.5% | 2.5% | n/a | ✓ |
| 4.2 — no 2.6% on the page | zero hits | zero | n/a | ✓ |
| 4.2 — the Wu (2022) / Chen et al. (2021) citation survives | present, unchanged | present | n/a | ✓ |
| 6 — `test_invariants()` count unchanged | 4 in `test-constructors.R`, 1 in `test-variance-replicate.R`; the diff adds none | no new call | n/a | ✓ |

Tolerance integrity: no tolerance in this audit departs from the test-spec.
Rows 3.1 and 3.2 name their tolerances in the assert column and the block
writes each one — `1e-8` on every stored scale and on the SE and the SE
ratio, `1e-10` on the mean. Row 2.3's frame B premise carries the one
authorised deviation, `tolerance = 0`, and the block writes it. The remaining
row 2.3 assertions are `is.infinite()` and `is.nan()` predicates, which the
test-spec §Tolerances lists as exact and untolerated.

### Evidence — how row 2.3's oracle rule was judged, all five parts

| Part | Finding |
|---|---|
| 1. same inputs, `mse` explicit on both sides | Both sides take the same frame, `weights = wt` / `d$wt`, the same single replicate column, `type = "bootstrap"`, and `mse = TRUE` written out once per side. ✓ |
| 2. `scale` to neither side | Neither oracle design carries a `scale`. The two premise designs carry `scale = 1` and are compared against no `survey` design, which §The oracle rule, all five parts exempts in writing. ✓ |
| 3. `rscales` to JKn only | Neither block passes `rscales`. Both are bootstrap rows. ✓ |
| 4. assert the SE, not the point estimate alone | Each block asserts the standard error and both confidence bounds on each side. Neither block asserts a point estimate alone. ✓ |
| 5. assert the condition, do not silence it | `expect_no_warning()` wraps each of the two `svrepdesign()` calls. No `suppressWarnings()` anywhere in the added lines. ✓ |
| each side against its own literal | Every assertion is a predicate on one side's own value. No assertion compares a surveycore number against a `survey` number, and no assertion compares the two stored scales. ✓ |

The orchestrator measured on `survey` 4.5 / R 4.6.1 that `svrepdesign()`
raises nothing on either frame. Asserting no condition is the right call
here, and it is what rule 5 asks for: rule 5 requires the block to state what
`survey` does, and `expect_no_warning()` states it. The alternative — a
message-text match — has nothing to match. Had `survey` warned, the warning
would mean `survey` computed the scale itself and the comparison would be
void; the assertion is the guard against that, and it is live rather than
decorative, because `svrepdesign()` does warn on a `scale` it discards for
other types.

### Evidence — frame B's construction, judged

Frame B produces an exactly-zero replicate deviation, so it reaches the `NaN`
branch and does not test the `Inf` branch twice. Three independent grounds:

1. **The column is bit-identical.** `d$repwt_1 <- d$wt` copies the base
   weight column, so the replicate weights and the base weights are the same
   doubles.
2. **Every accumulation is an exact integer, on any route.** The block draws
   `y1` from `2:30` and `wt` from `1:9`, `n = 40`, under `set.seed(7)`. Each
   product `y * w` is at most 270 and each running sum is at most 10,800 —
   whole numbers far inside `2^53`. So the full-sample route and the
   replicate route return the identical integer numerator and the identical
   integer denominator, whatever order they add in, and the quotient is
   bit-identical. This is the property the test-spec's own four-row fixture
   was chosen for, and a 40-row whole-valued frame holds it just as firmly.
3. **The block proves it in-suite.** The premise assertion
   `expect_equal(m_one$se, 0, tolerance = 0)` passes. A frame that drifted one
   ulp off zero would turn that assertion red before the `NaN` conclusion,
   which is the ordering the test-spec asks for.

Frame A's mirror guard holds too. Its replicate column is an independent
`runif` draw, not a multiple of the weight column, so the deviation cannot be
zero by the proportionality trap the test-spec warns about; the premise
asserts `is.finite()` and `> 0` and passes.

## Before/After Comparison

| Metric | Before PR | After PR | Δ |
|---|---|---|---|
| tests passing | 12065 | 12100 | +35 |
| tests failing | 0 | 0 | 0 |
| test warnings | 256 | 256 | 0 |
| tests skipped | 4 | 4 | 0 |
| coverage | 96.15% | 96.15% | 0.00% |
| R CMD check notes | 2 | 2 | 0 |
| files under `tests/testthat/_snaps/` changed | — | 0 | 0 |

The `+35` corroborates the row-by-row reading exactly. The diff adds 35
expectations and no more: 27 in `test-variance-replicate.R` (17
`expect_true`, 6 `expect_no_condition`, 2 `expect_no_warning`, 1 `expect_gt`,
1 `expect_equal`) and 8 in `test-constructors.R` (4 per block). Every one ran
and passed, and the skip count held at 4, so neither
`skip_if_not_installed("survey")` fired.

Coverage did not move, which is expected: the PR's `R/` diff is seven roxygen
lines and no executable line. The three uncovered lines the coverage script
reports are pre-existing and outside every hunk in this arc.

## Profile gates

Run by the orchestrator in the foreground on this tree. This audit ran none.

| Gate | Result | Notes |
|---|---|---|
| devtools::document() | PASS | wrote nothing; `man/` is committed in sync |
| devtools::test() | PASS | `FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 12100`; no new warning — the 256 are pre-existing AAPOR small-cell warnings |
| devtools::run_examples() | PASS | clean |
| R CMD build | PASS | tarball produced |
| R CMD check --as-cran | PASS | 0 errors, 0 warnings, 2 NOTEs — `checking CRAN incoming feasibility` and `hidden files and directories`, the pre-approved pair, the same two as the base |
| pkgdown::build_site() | PASS | site built; run deliberately, because `man/` changed |
| covr::package_coverage() | 96.15% | no change against the base; floor 95%, target 98% |
| CRAN cookbook scan | PASS | no violations |
| air format --check (touched files) | PASS | see the finding below |

Tree: dd8c7f82f6705b3e71560e6aee9f7ecb7c70ca16

## CRAN cookbook violations

None.

Scanned the PR's changed `R/` lines — `R/core-constructors.R` is the only
`R/` file in the write surface, and its diff is seven roxygen lines. No hit
for `T`/`F` as a logical, `set.seed(`, bare `print(`/`cat(`,
`options(warn = -1)`, `installed.packages(`, `<<-`, unrestored `par(`,
`options(` or `setwd(`, a write to `getwd()` or `~`, or more than two cores.
`@importFrom` returns zero hits across all of `R/`.

DESCRIPTION is unchanged by this PR, so its field checks were not re-run.

## Findings — reported, not blocking

**F1 — row 2.3's fixture diverges from the values the test-spec prescribes.**
The test-spec fixes both frames at four rows with `y = c(1, 2, 3, 4)`,
`w = c(1, 1, 2, 2)`, frame A's replicate column `c(5, 1, 2, 2)` and frame B's
`c(1, 1, 2, 2)`. The block instead builds two seeded 40-row inline frames:
frame A from `rnorm()` and `runif()` under `set.seed(253)`, frame B from
`sample(2:30)` and `sample(1:9)` under `set.seed(7)` with the replicate
column copied from the weight column. This is a divergence in the letter of
the row and not in its substance. The test-spec attaches a reason to its
values — exact representability, so the deviation is exactly zero on frame B
and non-proportional on frame A — and both frames meet that reason, frame B
by the integer argument above and frame A by an independent draw. Both
premise assertions the row names are present in the form the row names them,
and both pass. No assertion of the row is weakened. Recorded here so the
reviewer reads the divergence from this audit rather than discovering it.

**F2 — `air format --check` reports `tests/testthat/test-constructors.R`
would reformat, and every site is pre-existing.** The base copy of the same
file at `origin/develop` already fails the same check, and all 58 sites air
would rewrite sit at line 1706 or later. The PR's own added block is lines
1007 to 1112. The other three touched files —
`tests/testthat/test-variance-replicate.R`, `R/core-constructors.R` and
`man/as_survey_nonprob.Rd` — are air-clean. Under the test-spec's reading of
the formatting gate, "the files this work touches pass `air format --check`",
the PR's own lines pass.

**F3 — context for the reviewer, from test-spec §Error-path pattern.** The
test-spec's second bullet there authorises one class-only assertion with no
snapshot behind it anywhere: `as_survey_replicate()` raising
`surveycore_error_weights_all_zero`. The gap is pre-existing, issue `#291`
owns it, and it must not be closed here, because a new snapshot would change
a file under `tests/testthat/_snaps/` and row 4.5 requires every file there
to hold its state. That assertion belongs to row 1.6, outside this audit's
four rows; it is named here only so a reviewer who meets it does not file a
defect.

## BLOCKs

None.
