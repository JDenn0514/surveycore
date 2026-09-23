# Audit — PR 8 — test/replicate-oracle-fay

**Verdict**: PASS
**Date**: 2026-09-22
**Branch**: `test/replicate-oracle-fay` at `d8c50cd`
**Base**: `d389bda`
**Diff**: `+49/-0`, one file, `tests/testthat/test-variance-replicate.R`, append-only

Tree: c23121ef6ad6423375765ffaaa277d2c4ac530eb

## Instrument and its calibration

The file discusses its own constructs in comments and in test titles, so
`grep -c` counts the wrong thing twice over: it counts matching lines, and it
counts prose. Two instruments were built and calibrated before use.

| Instrument | What it does | File |
|---|---|---|
| `strip.awk` | removes `#` comments, keeps string contents, emits `lineno TAB code` | scratchpad |
| `strip2.awk` | removes `#` comments AND string contents, emits bare code | scratchpad |
| `blocks.awk` / `perblock.awk` | paren-depth walker over `()[]{}`; maps each top-level `test_that(` span and counts tokens per span | scratchpad |

Calibration against the two known contrasts:

| Token | textual (`grep -c`) | strip.awk occurrences | strip2.awk calls | known real | agrees |
|---|--:|--:|--:|--:|---|
| `expect_failure` | 12 | 6 | 6 | 6 | yes |
| `svrepdesign` | 18 | 15 | 14 | 14 | yes |

`strip.awk` reads 15 for `svrepdesign` because one occurrence sits inside a
test title string, line 1026. `strip2.awk` removes string contents and reads
14, which is the known figure. **Every count below comes from `strip2.awk`
plus the depth walker, unless the row says otherwise.**

The walker maps 28 balanced top-level spans, end depth 0, no unclosed span.
No non-blank bare code sits outside a span — the file carries no file-level
statement at all.

## Per-Test Result Table — the ten allocated rows

| Row | Check | Got | Expected | Pass |
|---|---|---|---|---|
| 3.1.9 | Fay block: last under `# Block 24:`, error fragment, surveycore scale `1 / R` | span 1026-1073, file ends 1073; `"With type='Fay' you must supply the correct rho"`, `fixed = TRUE`; `expect_equal(sc@variables$scale, 1 / n_rep, tolerance = 1e-8)` with `n_rep <- length(repwt_cols)` | error fragment plus stored scale `1 / R` = 0.1 at R = 10 | ✓ |
| 2.12 | Fay comment names #243, says the refusal half guards `survey`, says a failure most likely means `survey` changed | all three present | pass | ✓ |
| 2.1 | nine types have an oracle block | 9 of 9 | 9 of 9 | ✓ |
| 2.7 | every `survey`-building block asserts a condition | 14 of 14 | pass | ✓ |
| 2.8 | `skip_if_not_installed("survey")` inside each block, count equals blocks calling `survey` | 14 hits, all inside spans; 14 blocks call `survey` | pass | ✓ |
| 2.20 | no shared builder, no cross-design value, no cross-design scale assertion | each of the 14 blocks builds its own fixture and both designs in its own body; no helper touches `survey` | pass | ✓ |
| 2.6 | no constructor call receives a value read off the other side | 0 hits | pass | ✓ |
| 2.21 | four new blocks under one `# Block 24:` header, order JKn, bootstrap, `other`, Fay; no header renumbered | 806, 886, 967, 1026 under the header at 803; the six baseline headers are byte-identical | pass | ✓ |
| 2.22 | the new blocks estimate the mean of `y1` with `get_means()` and `svymean(~y1, ...)` | 3 of 3 comparing blocks; the Fay block compares nothing per test-spec §3.3 | 4 of 4 as written — read as 3 of 3, see Rulings | ✓ |
| 2.23 | JKn, bootstrap and Fay titles claim no match; JKn and bootstrap also name #253; Fay names the refusal and no issue number | 3 of 3 claim no match; 2 of 2 name #253; the Fay title carries no issue number | 3 of 3 and 2 of 2 | ✓ |

**Tally: 10 of 10 pass.**

## Evidence, row by row

### Row 3.1.9 — the Fay block

The header sits at line 803, `# Block 24: Oracle blocks for the remaining
replicate types`. The Fay span is 1026-1073 and the file is 1073 lines, so the
block is last under the header and last in the file.

The error assertion, lines 1050-1060:

```
  expect_error(
    survey::svrepdesign(
      weights = d$wt,
      repweights = d[, repwt_cols],
      type = "Fay",
      data = d
    ),
    "With type='Fay' you must supply the correct rho",
    fixed = TRUE
  )
```

The stored-scale assertion, line 1072:

```
  expect_equal(sc@variables$scale, 1 / n_rep, tolerance = 1e-8)
```

`n_rep` is read, not hard-coded: `repwt_cols <- grep("^repwt_", names(d),
value = TRUE)` then `n_rep <- length(repwt_cols)`. The fixture is
`make_survey_data(n = 200, n_psu = 20, n_strata = 4, design = "replicate",
type = "fay", seed = 15)`, and `tests/testthat/helper-test-data.R` line 515
maps the `fay` mode to `n_psu %/% 2L`, so R is 10 and `1 / n_rep` is 0.1.
The tolerance is the standard-error and variance row, `1e-8`, which is what
test-spec §3 assigns to a stored-scale assertion.

Static evidence only. **The numeric confirmation comes from gate 2 of the
leader's pass** — see §Profile gates. No R process was started from this
session.

### Row 2.12 — the Fay comment

The comment carries all three elements:

```
  # This block compares nothing. survey refuses type = "Fay" without a rho
  # before it builds anything, and surveycore has no rho argument today, so
  # no comparison is possible. Issue #243 owns the gap: a later PR adds the
  # rho argument and rewrites this block into a real oracle comparison.
  #
  # The first half asserts what another package refuses to do, so that half
  # guards survey's behaviour and not surveycore's. A failure there most
  # likely means survey changed its message or dropped the requirement —
  # read it that way before reading it as a surveycore regression.
```

### Row 2.1 — nine types, nine of nine

Type read from the `type = "..."` argument of the surveycore constructor and
of `svrepdesign()` in each span that calls `survey`.

| Type | Oracle block spans |
|---|---|
| BRR | 12-53, 55-94, 239-279, 309-354 |
| JK1 | 96-148 |
| JK2 | 150-205 |
| JKn | 806-884 |
| bootstrap | 886-965 |
| ACS | 487-527, 529-569 |
| successive-difference | 403-443, 445-485 |
| other | 967-1024 |
| Fay | 1026-1073 |

Fourteen spans, nine types, every type with at least one block that calls
`survey::svrepdesign()`.

### Row 2.7 — every survey-building block asserts a condition

Fourteen spans call `svrepdesign()`. Each asserts one condition, in one of
three shapes.

| Shape | Count | Spans |
|---|--:|---|
| `expect_no_warning(sv <- survey::svrepdesign(...))` | 10 | 12, 55, 239, 309, 403, 445, 487, 529, 806, 886 |
| `capture_warnings()` + `expect_length(..., 1L)` + `expect_match(fragment, fixed = TRUE)` | 3 | 96 (JK1), 150 (JK2), 967 (`other`) |
| `expect_error(..., fragment, fixed = TRUE)` | 1 | 1026 (Fay) |

Checked that each of the ten `expect_no_warning(` calls is followed on the
next line by `sv <- survey::svrepdesign(`, so the wrapper holds the design
build and not something else. The three fragments are `guessing n=number of
replicates`, `with type JK2 scale= and rscales= are not needed`, and `scale
or rscales not specified, set to 1`. 14 of 14.

### Row 2.8 — the skip guard

`skip_if_not_installed(` appears 14 times in bare code. The per-span counts
sum to 14, so no hit sits outside a `test_that()` body; the walker also finds
no bare code at all outside a span. The 14 spans holding a hit are exactly
the 14 that call `svrepdesign()`, one hit each. Hit count equals the count of
blocks that call `survey`.

### Rows 2.20 and 2.6 — no shared builder, no round trip

Three separate measurements.

1. **Each block builds its own fixture.** `make_survey_data(` appears once in
   each of the 14 oracle spans. `svrepdesign(` appears once in each.
   `as_survey_replicate(` appears once in each.
2. **No file-level or helper builder.** The depth walker reports no non-blank
   bare code outside the 28 spans, so the file defines no function at all.
   `tests/testthat/helper-test-data.R` is the only helper file and carries
   zero hits for `svrepdesign` or `survey::`. This PR changes no helper —
   `git diff --name-only d389bda HEAD` lists one file.
3. **No cross-design value, in either direction.** Every `sv$` and `sv@`
   reference in bare code is one of the 13 stored-scale assertions, and every
   one compares against a literal or a formula in `R`:

```
 44: expect_equal(sv$scale, 1 / length(repwt_cols), tolerance = 1e-8)
 85: expect_equal(sv$scale, 1 / length(repwt_cols), tolerance = 1e-8)
139: expect_equal(sv$scale, (n_rep - 1) / n_rep, tolerance = 1e-8)
196: expect_equal(sv$scale, 1, tolerance = 1e-8)
270: expect_equal(sv$scale, 1 / length(repwt_cols), tolerance = 1e-8)
345: expect_equal(sv$scale, 1 / n_rep, tolerance = 1e-8)
434: expect_equal(sv$scale, 4 / length(repwt_cols), tolerance = 1e-8)
476: expect_equal(sv$scale, 4 / length(repwt_cols), tolerance = 1e-8)
518: expect_equal(sv$scale, 4 / length(repwt_cols), tolerance = 1e-8)
560: expect_equal(sv$scale, 4 / length(repwt_cols), tolerance = 1e-8)
855: expect_equal(sv$scale, 1, tolerance = 1e-8)
931: expect_equal(sv$scale, 1 / (n_rep - 1), tolerance = 1e-8)
1015: expect_equal(sv$scale, 1, tolerance = 1e-8)
```

   The four `sc@variables$scale` references, at 174, 379, 400 and 1072, each
   compare against a literal too: `1`, `4 / n_rep`, `4 / n_rep`, `1 / n_rep`.
   No assertion anywhere puts one side's stored scale against the other's.
   No `sv$` or `sv@` reference sits inside an argument list of
   `as_survey_replicate(`, and no `sc@` or `sc$` reference sits inside an
   argument list of `svrepdesign()` — every one of the 17 references above is
   the first argument of an `expect_equal()`, except line 796, which writes a
   domain marker in a pre-existing `get_corr()` block that builds no `survey`
   design.

The one `rscales` argument passed to both sides, in the JKn block, is the
literal `rep(1, n_rep)` written out twice, with `n_rep` read from the
selected columns. Neither copy is read off a design.

### Rows 2.21, 2.22, 2.23 — the four new blocks

Order under the single `# Block 24:` header at line 803:

| Position | Span | Title |
|--:|---|---|
| 1 | 806-884 | `get_means() JKn SE disagrees with survey::svymean() — issue #253` |
| 2 | 886-965 | `get_means() bootstrap SE disagrees with survey::svymean() — issue #253` |
| 3 | 967-1024 | `get_means() replicate SE matches survey::svymean() — other design` |
| 4 | 1026-1073 | `survey::svrepdesign() refuses Fay without rho — Fay design` |

JKn, bootstrap, `other`, Fay — the order the row asks for. No other
`# Block 24:` header exists, and the six headers on the arc baseline
`7800ea9` (Blocks 10, 11, 12, 16, 22, 23) are present with identical titles,
so nothing was renumbered.

Estimators. The three comparing blocks each call `get_means(sc, y1, variance
= c("se", "ci"))` and `survey::svymean(~y1, sv, na.rm = TRUE)`, one call each
— spans 806, 886 and 967 all read `get_means(=1 svymean(=1`. The Fay block
reads `get_means(=0 svymean(=0`.

Titles. Three of three claim no match: `disagrees` twice, `refuses` once.
Two of two name issue #253 — the JKn and bootstrap titles. The Fay title
names the refusal and carries no issue number; #243 sits in its comment, as
the row asks.

## Rulings on the two judgement calls

### Row 2.22 — read as 3 of 3, and the "4 of 4" count is a test-spec erratum

The row says the four new blocks estimate the mean of `y1` on both sides, and
gives the count as 4 of 4. **I read the estimator clause as binding on the
comparing blocks only, and I record it satisfied 3 of 3.**

The reason is inside the same document. Test-spec §3.3 states that the Fay
block "compares nothing", that `survey` refuses `type = "Fay"` without a
`rho` before it builds anything, and it lists the two assertions the block
carries — the error, and surveycore's stored scale. Neither is an estimate.
So no file that satisfies §3.3 can satisfy row 2.22's count of 4: a
`survey::svymean(~y1, sv, ...)` call in the Fay block needs an `sv` that §3.3
says cannot be built. §3.3 is the specific statement about this block and
governs; the "4 of 4" figure in the §2 table is an erratum that survived into
the frozen document, of the same kind as the seven the document already
records under §Errata.

This is a ruling, not a silent pass. The clause is met by every block that
can meet it, and the count is unmeetable by construction. A later editor who
wants row 2.22 to read literally must first close issue #243 — which is what
the Fay comment says the next PR does.

### Row 2.23 — the pre-existing BRR title does not count toward the row

A word filter over the 28 titles for no-match language returns seven hits.
Four are false positives on `matches` or `stores`. One needs a decision:

```
309: test_that("get_means() BRR scale formula 1/n_rep is correct for n_rep != 4", {
```

**It does not count toward row 2.23.** The row counts titles that claim
surveycore and `survey` do not agree. This title claims that surveycore's own
scale formula is correct — an affirmative claim about one side, with no
comparison in it. The block itself agrees with `survey` on all five
quantities: span 309-354 carries `expect_no_warning`, one `svrepdesign()`
call, `expect_equal(sv$scale, 1 / n_rep, tolerance = 1e-8)` and five
`expect_equal()` calls in total, with no `expect_failure()` wrapper. Counting
it would make the row read 4 of 4 and would contradict the row's own defect
test, which is a title of the form "X matches Y" on a block that proves a
disagreement.

This PR does not touch line 309. The row reads 3 of 3.

## Settled-convention conformance

| Convention | Measured | Verdict |
|---|---|---|
| Canonical stored-scale comment count stays 13, not 14 | 13 — lines 43, 84, 138, 195, 269, 344, 433, 475, 517, 559, 854, 930, 1014; all 13 byte-identical; the Fay block carries none | conforms |
| The comment line is 99 characters, over the 80-column limit (decisions S4, S5) | present as designed | not a defect |
| The JK2 block's `expect_equal(sc@variables$scale, 1)` carries no explicit tolerance (finding N2) | line 174, untouched by this PR | not a defect |

The 13 comments sit above the 13 `sv$scale` assertions, one per numerical
oracle block. The Fay block asserts surveycore's stored scale, not `survey`'s,
so it takes no canonical comment — and it carries none. A 14th would have
been a defect.

## CRAN cookbook violations

None. The write surface holds no file under `R/`; it is one file under
`tests/testthat/`. The 49 added lines were scanned anyway, with string
contents and comments removed: zero hits for bare `T`/`F`, `set.seed(`, bare
`print(`/`cat(`, `<<-`, `options(warn = -1)`, `installed.packages(` and
`mc.cores`.

`air format --check tests/testthat/test-variance-replicate.R` exits 0 with no
output. `air` is a CLI here, not an R package, so running it started no R
process.


## Profile gates

Run by the leader on tree `c23121ef6ad6423375765ffaaa277d2c4ac530eb` — the
tree this audit records. This session started no R process, because a gate
pass was in flight on that exact tree.

| Gate | Result | Notes |
|---|---|---|
| `devtools::document()` | PASS | `document()` wrote nothing |
| `devtools::test()` | PASS | `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 12005 ]` |
| `run_examples()` | PASS | all examples ran |
| `R CMD build` | PASS | `surveycore_1.1.0.9000.tar.gz` |
| `R CMD check --as-cran --no-manual` | PASS | Status: 2 NOTEs, and these two — see below |
| pkgdown | SKIPPED — scope | one test file; `NAMESPACE` diff empty |
| `covr` | PASS | 96.15% |
| `air format --check` | PASS | run here; CLI, not R; exit 0 on the changed file |
| CRAN cookbook scan | PASS | no `R/` file in the write surface; added lines clean |

Logs: `.surveycore-workspace/runs/2026-09-16-replicate-oracle-tests/logs/pr8/`

Tree: c23121ef6ad6423375765ffaaa277d2c4ac530eb

### The two NOTEs are both pre-existing

Read gate 5 as "2 NOTEs, and these two". A third blocks.

| NOTE | Status |
|---|---|
| `checking CRAN incoming feasibility` | pre-approved in `.claude/rules/r-package-conventions.md`; the package is not on CRAN |
| `checking for hidden files and directories` | `R CMD build` finds `.git`; caused by `.Rbuildignore`, present on the clean baseline, and this arc cannot fix it |

Both appear on the `7800ea9` baseline and on every PR from 1 to 7, unchanged.
Neither is a new pattern.

## Before/After Comparison

| Figure | Baseline (`7800ea9`) | PR 7 | This PR | Delta |
|---|---|---|---|---|
| Failures | 0 | 0 | 0 | 0 |
| Warnings | 256 | 256 | 256 | 0 |
| Skips | 4 | 4 | 4 | 0 |
| Passes | 11941 | 12003 | 12005 | **+2** |
| Coverage | 96.15% | 96.15% | 96.15% | 0.00 |
| R CMD check NOTEs | 2 | 2 | 2 | 0 |

The 256 warnings are the pre-existing AAPOR small-cell warnings. Coverage
holds at 96.15%, above the 95% floor; the PR adds no line under `R/`.

### The +2 delta is itself evidence the Fay block compares nothing

Both figures were predicted from the static read before the pass finished:
12005 passes and flat coverage. The delta is +2 and not the +7 a comparing
block contributes. A comparing block in this file carries five numerical
assertions — point, standard error, two confidence bounds, `survey`'s stored
scale — plus its condition assertion. The Fay block carries two: the refusal,
and surveycore's stored scale. The expectation count reproduces the structure
row 3.1.9 describes.

## Row 3.1.9 — the numeric half is now settled

The static read is in §Evidence above. Gate 2 ran on this exact tree with 0
failures, so against the installed `survey` the refusal fires with the message
`With type='Fay' you must supply the correct rho`, and
`sc@variables$scale` reads `1 / n_rep` = 0.1 at R = 10. Nothing rests on a
later run.

## BLOCKs

None.

## Verdict

**PASS.** Ten of ten allocated rows pass, every profile gate passes or is a
scope skip, the CRAN cookbook scan is clean, and no figure regresses against
the baseline.

Two rulings carry into the archive, recorded by the leader in the run's
`decisions.md` as S6 and N3:

- **Row 2.22** is satisfied 3 of 3 by the comparing blocks. The row's "4 of 4"
  count is a test-spec erratum: §3.3 of the same document says the Fay block
  compares nothing, so no conforming file can meet a count of 4.
- **Row 2.23** reads 3 of 3 and 2 of 2. The pre-existing title
  `get_means() BRR scale formula 1/n_rep is correct for n_rep != 4` claims a
  formula is correct, not that the two sides disagree, and does not count.

This audit is final.
