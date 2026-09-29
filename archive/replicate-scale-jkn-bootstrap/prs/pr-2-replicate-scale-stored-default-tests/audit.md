# Audit — PR 2 — replicate-scale-stored-default-tests

> **On the `[no such file]` marker below.** The test-spec it cites sat in the
> plans directory while the arc was in flight. Archiving moved it in beside
> this file, under the same name, so the path in the citation no longer
> resolves although the document is right here. The marker is the closer of
> the two the citation checker accepts; neither can say "archived under a
> different path". Nothing was lost.

**Verdict**: PASS
**Date**: 2026-09-29 12:05

Branch `fix/replicate-scale-stored-default-tests`, HEAD `3a79218`, base
`origin/develop` at `d11d1f8`.

Rows in scope: `plans/test-spec-replicate-scale-jkn-bootstrap.md` [no such file] §1 rows
1.1, 1.2, 1.3, 1.4 and 1.5. No other row was judged.

Write surface: `tests/testthat/test-constructors.R` only, +171 / -0, five
new blocks at lines 694–864. No file under `R/` changed
(`git diff --name-only d11d1f8..HEAD -- R/` is empty). No file under
`tests/testthat/_snaps/` changed. Both facts verified here, not taken on
report.

## Method

The gates were run in the foreground by the orchestrator and are recorded
below unchanged; this agent started no gate. For the five rows this agent
measured the constructor directly: `pkgload::load_all()`, the fixtures of
each block, and a print of every asserted quantity with its gap against the
literal the row names. The Got column below is that measurement, not a
reading of the test file. The script is
`{scratchpad}/measure.R`; every gap it printed is `0e+00`.

## Per-Test Result Table

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| 1.1 replicate count pinned | `n_rep = 20L` | `20L` | exact | ✓ |
| 1.1 JKn stored scale | `1` (gap 0e+00) | `1` | 1e-8 | ✓ |
| 1.1 bootstrap stored scale | `0.05263158` (gap 0e+00) | `1 / (n_rep - 1)` | 1e-8 | ✓ |
| 1.1 JKn ≠ old `(R-1)/R` | `expect_false(isTRUE(all.equal(.)))` holds | not equal | n/a | ✓ |
| 1.1 bootstrap ≠ old `1/R` | `expect_false(isTRUE(all.equal(.)))` holds | not equal | n/a | ✓ |
| 1.1 JKn > old | `1 > 0.95` TRUE | greater | n/a | ✓ |
| 1.1 bootstrap > old | `0.0526 > 0.05` TRUE | greater | n/a | ✓ |
| 1.1 JKn ratio to old | gap 0e+00 vs `20/19` | `n_rep / (n_rep - 1)` | 1e-8 | ✓ |
| 1.1 bootstrap ratio to old | gap 0e+00 vs `20/19` | `n_rep / (n_rep - 1)` | 1e-8 | ✓ |
| 1.1 neither construction raises a condition | conditions raised: NONE | none | exact | ✓ |
| 1.2 stored scale, non-uniform `rscales` | `1` (gap 0e+00) | `1` | 1e-8 | ✓ |
| 1.2 `rscales` stored verbatim | `identical()` TRUE, max element gap 0e+00 | supplied vector, element for element | 1e-8 | ✓ |
| 1.2 `rscales` length | `20L` | `n_rep` | exact | ✓ |
| 1.3 bootstrap at R = 2 | `1` (gap 0e+00) | `1` | 1e-8 | ✓ |
| 1.3 bootstrap at R = 1 is infinite | `is.infinite()` TRUE | TRUE | exact | ✓ |
| 1.3 bootstrap at R = 1 equals `Inf` | `identical(., Inf)` TRUE | `Inf` | exact | ✓ |
| 1.3 bootstrap at R = 1 raises no condition | conditions raised: NONE | none | exact | ✓ |
| 1.3 JKn at R = 1 | `1` (gap 0e+00) | `1` | 1e-8 | ✓ |
| 1.4 JKn explicit scale stored verbatim | gap 0e+00 vs `(n_rep-1)/n_rep` | the supplied value | 1e-8 | ✓ |
| 1.4 bootstrap explicit scale stored verbatim | gap 0e+00 vs `1/n_rep` | the supplied value | 1e-8 | ✓ |
| 1.5 stored scale, `rscales = NULL` | `1` (gap 0e+00) | `1` | 1e-8 | ✓ |
| 1.5 stored `rscales` | `NULL` | `NULL` | exact | ✓ |
| 1.5 construction raises no condition | conditions raised: NONE | none | exact | ✓ |

24 assertions across the five blocks. That is the whole of the +24 the test
gate reports, so every added assertion belongs to a row in scope and no
block added an assertion outside the five rows.

## Row-by-row fidelity against the test-spec text

| Row | Required assertion set | Present as stated |
|---|---|---|
| 1.1 | both stored defaults; `expect_false(isTRUE(all.equal(...)))` against each old value; `expect_gt()` against each old value; ratio to old equal to `n_rep/(n_rep-1)` at 1e-8 for both types; no condition | Yes — all eight clauses, and the `expect_false(isTRUE(all.equal(...)))` form is the verbatim one the row names |
| 1.2 | stored `scale` is `1`; stored `rscales` equals the supplied vector element for element; no normalisation, no folding into `scale` | Yes — vector is non-uniform (`seq(0.5, 0.95, length.out = 20)`) and of the right length |
| 1.3 | bootstrap R=2 → `1`; bootstrap R=1 → `Inf` asserted **both** by `is.infinite()` and against the literal `Inf`, and no condition; JKn R=1 → `1`; each against its own literal | Yes — the `Inf` value carries both required forms, and the no-condition clause is on the R=1 bootstrap construction where the row puts it |
| 1.4 | the stored value is the supplied one for both changed types | Yes |
| 1.5 | stored `scale` is `1`; stored `rscales` is `NULL`; no condition | Yes — all three |

**No block asserts one side against the other.** Every assertion names a
literal or a formula in `n_rep`. `jkn_old` and `boot_old` are computed from
`n_rep` in the block, never read off a design. Checked line by line across
all five blocks.

**No construction raises a condition where a row forbids one.** Three
`expect_no_condition()` wrappers sit on exactly the four constructions rows
1.1, 1.3 and 1.5 cover, and the independent measurement above confirms all
four are silent in fact.

## Would the blocks catch a wrong default?

Judged independently, by substituting the old value into each assertion.

| Reverted default | Assertions that turn red | Rows |
|---|---|---|
| JKn to `(n_rep-1)/n_rep` | 7 | 1.1 (equal, not-equal, gt, ratio), 1.2 (scale), 1.3 (JKn at R=1), 1.5 (scale) |
| bootstrap to `1/n_rep` | ≥7 | 1.1 (equal, not-equal, gt, ratio), 1.3 (R=2 value, `is.infinite()`, `== Inf`) |

The two sets are disjoint, and both `Inf` assertions of row 1.3 are in the
bootstrap set. The builder reported 7 and 8; this agent counts 7 and 7 by
substitution. The one-assertion difference is not material — the conclusion
is the same on both counts, and neither count changes a verdict.

## Tolerance integrity

No tolerance was relaxed, and none was changed from the test-spec.

One finding for the reviewer, with the measurement that settles it. The
test-spec §1 preamble puts the stored `scale` on the SE row, `1e-8`. Ten of
the stored-scale assertions carry no `tolerance =` argument and therefore
take testthat's default, measured at `1.490116e-08` on this machine — looser
than `1e-8` by a factor of 1.49. The two ratio assertions of row 1.1 do
carry `tolerance = 1e-8` explicitly.

This is not a relaxation in effect, and the measurement is the reason:
**every one of the twelve stored-scale quantities agrees with its literal to
a gap of exactly `0e+00`.** Each passes at `1e-8` as the spec writes it, and
at `tolerance = 0`. The values are bit-identical because both sides divide
the same integers in IEEE double. The gaps a wrong default would open are
`0.05` (JKn) and `0.0026` (bootstrap) — six to seven orders of magnitude
above either tolerance, so no detection power rides on the difference.

Recorded, not waived: a later reader should not take the bare `expect_equal()`
here as authority that the stored-scale bar is testthat's default. The bar is
`1e-8` and the rows meet it.

## Deviations from the test-spec text, both measured to have no effect

Two places where a block departs from its row's **scenario** column. Neither
touches an **assert** column, and each was settled by measurement rather than
by argument.

1. **Row 1.1's JKn construction passes no `rscales`.** The row's scenario
   writes `rscales = rep(1, n_rep)`. Built here with the argument supplied,
   the stored scale is `1` at a gap of `0e+00` and the construction raises
   nothing — the same two outcomes the block asserts without it. Rows 1.2
   (a non-uniform vector supplied) and 1.5 (`NULL`) bracket the argument on
   both sides and both give `1`, so a uniform vector between them can reach
   no branch those two miss. No coverage is lost.
2. **Row 1.3 builds its 1- and 2-column frames by selecting columns from
   `make_survey_data()`, not from an inline frame.** The §Datasets table
   assigns "inline data frames" to this boundary. `all_of("repwt_1")` and
   `all_of(c("repwt_1","repwt_2"))` deliver exactly R = 1 and R = 2 to the
   constructor, which is the whole of what the boundary needs. No parameter
   was added to the data generator, so the `testing-standards.md` rule this
   clause protects is not breached.

One note on row 1.4, not a deviation. The row writes "e.g. `scale = 0.25`";
the block supplies the two old default values instead, which serves the row's
own stated purpose ("the route back to the pre-change numbers") better than
an arbitrary number. Under the shipped defaults the supplied value differs
from the computed default for both types, so the row still detects a
constructor that ignored an explicit `scale`.

## CRAN cookbook violations

None.

The PR changes no file under `R/`, so the scan has no in-scope file. Scanned
the 171 added test lines anyway for all nine patterns — `T`/`F` as logicals,
`set.seed()`, bare `print()`/`cat()`, `options(warn = -1)`,
`installed.packages()`, `<<-`, unrestored `par()`/`options()`/`setwd()`,
writes to `getwd()`/home, and more than 2 cores. Zero hits.

| File | Line | Violation | Class |
|---|---|---|---|
| — | — | none | — |

## Invariants and snapshots

- `test_invariants()` appears 4 times in `test-constructors.R` at both
  `d11d1f8` and `HEAD` — one per constructor, unchanged. The five new blocks
  add no call, which is what §Invariants requires.
- No file under `tests/testthat/_snaps/` changed. Rows 1.1 to 1.5 assert no
  condition class and need no snapshot, so §Error-path pattern's two
  departures (including the `#291` gap) do not reach this PR.
- No new block title duplicates an existing one.

## Formatting

`air format --check` reports "Would reformat" on
`tests/testthat/test-constructors.R`. The same command reports the same
result on the file at base `d11d1f8`, so the failure is pre-existing. All 29
hunks `air` would rewrite start at line 1380 or later; the PR's added block
is lines 694–864, and `air` touches none of it. Under the test-spec reading
of this gate — "the files this work touches pass" — the PR's own lines are
clean and the file-level failure is inherited.

## Before/After Comparison

| Metric | Before PR | After PR | Δ |
|---|---|---|---|
| tests passing | 12004 | 12028 | +24 |
| test failures | 0 | 0 | 0 |
| test warnings | 256 | 256 | 0 |
| test skips | 4 | 4 | 0 |
| coverage | 96.15% | 96.15% | 0.00% |
| R CMD check notes | 2 | 2 | 0 |
| R CMD check errors / warnings | 0 / 0 | 0 / 0 | 0 |

Coverage holds at 96.15%, above the 95% floor and below the 98% target,
unchanged from base. No HOLD: the figure did not drop. A test-only PR that
adds no `R/` line cannot raise it.

The +24 warnings reading is 0, not 256-to-0. Clean `develop` carries 256
pre-existing AAPOR small-cell warnings and PR 2 holds at exactly 256, so the
gate reads as "no new warning".

## Profile gates

Run in the foreground by the orchestrator on tree `b8b26ae`; this agent
started no gate, to avoid two heavy R runs corrupting each other's `.Rcheck`
tree. Logs:
`.surveycore-workspace/runs/2026-09-23-replicate-scale-jkn-bootstrap/gates/pr-2/`.

| Gate | Result | Notes |
|---|---|---|
| devtools::document() | PASS | wrote nothing, at base and at HEAD |
| devtools::test() | PASS | `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 12028 ]`; base `PASS 12004`, +24 |
| devtools::run_examples() | PASS | all examples clean |
| R CMD build | PASS | tarball produced |
| R CMD check --as-cran | PASS | 0 errors, 0 warnings, 2 NOTEs — the pre-approved pair |
| pkgdown | SKIPPED — scope | test-only write surface; see below |
| covr | 96.15% | no change vs base 96.15%; floor 95% |
| CRAN cookbook scan | PASS | no in-scope `R/` file; 171 added test lines scanned, 0 hits |

**The two NOTEs are the pre-approved pair.** `checking CRAN incoming
feasibility`, pre-approved in `r-package-profile.md`; and `checking for
hidden files and directories`, the `.git` note that `.Rbuildignore` causes,
carried on `develop` and not fixable by one PR. A third NOTE would block;
there is none, and neither NOTE is new.

**pkgdown skip, and why it is allowed.** The write surface is
`tests/testthat/test-constructors.R` alone. It touches no `R/` source, no
`vignettes/`, no `README.Rmd` or `README.md`, no `_pkgdown.yml` and no
`DESCRIPTION` field, so every condition in `r-package-profile.md` §pkgdown
skip condition is met. The hard rule that forbids a skip when exports change
does not apply: the `NAMESPACE` diff is empty and no roxygen block or `man/`
page changed. CI runs a pkgdown job on the PR regardless.

**One reading carried forward.** The covr line in the gate log says
"changed R/ files: 1". That is an artifact of the coverage script diffing
against this worktree's stale local `develop` ref, which still points at
`fd621a1`, so it sees PR 1's change. PR 2 changes no `R/` file — verified
here independently with `git diff --name-only d11d1f8..HEAD -- R/`, which is
empty. The 3 uncovered lines (414, 1868, 1959) are pre-existing and sit
outside every hunk in this arc.

Tree: b8b26aeadd67e49613d17933728dbe53adee093e

## BLOCKs

None.

## HOLDs

None. The test-spec is explicit on every scenario and tolerance these five
rows need, and no oracle or dataset was unavailable.

## Verdict

PASS. All 24 assertions across rows 1.1 to 1.5 hold, measured independently
at the tolerances the test-spec states. Every profile gate is clean or
carries a justified skip. The cookbook scan is clean. Neither tests passing
nor coverage regressed.

Three items for the reviewer, none of them a failure: the ten bare
`expect_equal()` stored-scale assertions that take testthat's `1.49e-8`
default where the spec writes `1e-8` (every gap measured `0e+00`, so the
spec bar is met in fact); row 1.1's omitted `rscales = rep(1, n_rep)`; and
row 1.3's generated-frame column subselection in place of an inline frame.
