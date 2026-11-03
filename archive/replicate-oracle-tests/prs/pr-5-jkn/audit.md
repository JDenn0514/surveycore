# Audit — PR 5 — test/replicate-oracle-jkn

**Verdict**: PASS
**Date**: 2026-09-22 13:13

Verdict covers the three allocated rows, PR 5's own acceptance criteria, and
the profile gates. All gates pass on tree
`ba47cff369806d0c550db3d9ecb8f05e7f3600c1`. See §Profile gates.

**Scope.** Rows 2.3, 2.4 and 3.1.4 only. Rows 2.9, 2.10, 2.11, 2.15, 2.16 and
all of §3.6 belong to PR 6, because they count the JKn block and the bootstrap
block together and the bootstrap block does not exist yet. This audit checks the
JKn half of the shape under §PR 5 acceptance criteria and counts none of those
rows against this PR.

**Diff read.** `git diff d0de848 HEAD` — one file,
`tests/testthat/test-variance-replicate.R`, +84/-0, append-only.

---

## Instruments

The file discusses its own constructs in comments, so a line-based `grep -c` is
wrong. Two instruments were used and both are recorded per count.

| Instrument | What it does |
|---|---|
| `strip.awk` | Removes R comments, respecting single- and double-quoted strings. Output piped to `grep -o`, which counts occurrences, not lines. |
| `depth.awk` | Same comment stripping, plus a running `()`/`{}`/`[]` depth counter printed at the start of each line. Used to decide what sits inside which call. |

Measured difference between the two instruments on this branch:

| Token | `grep -c` (lines, comments included) | `strip.awk` + `grep -o` (code occurrences) |
|---|--:|--:|
| `expect_failure` | 6 | **3** |
| `svrepdesign(` | 13 | **11** |
| `rscales` | 12 | **10** |
| `suppressWarnings(` | — | **0** |

No R process was started. `air format --check` is a CLI and was run.

---

## Per-Test Result Table

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| Row 2.3 — exactly one `survey::svrepdesign()` call receives `rscales`, in the JKn block | 1 | 1 hit | n/a | ✓ |
| Row 2.4 — the JKn block passes the identical literal `rscales` to both sides, written out twice; neither copy read off a design | pass | pass | n/a | ✓ |
| Row 3.1.4 — JKn: `rscales` to both sides, no-warning assertion, `survey` stored scale `1`, pinned | pass | pass | 1e-8 on the scale | ✓ |

### Row 2.3 — evidence

`strip.awk` gives 11 `svrepdesign(` call sites and 8 code lines carrying
`rscales`. Each `rscales` site was classified by reading its enclosing call with
`depth.awk`:

| Line | Delivered text | Enclosing call | Counts for 2.3? |
|---|---|---|---|
| 191 | `"with type JK2 scale= and rscales= are not needed",` | string literal in a message match | no |
| 229 | `rscales = rep(1, length(repwt_cols))` | `as_survey_nonprob(` | no |
| 624 | `rscales <- rep(1L, 5L)` | local assignment | no |
| 628 | `rscales = rscales,` | `surveycore:::.svy_rep_var(` | no |
| 638 | `rscales <- rep(1L, 5L)` | local assignment | no |
| 643 | `rscales = rscales,` | `surveycore:::.svy_rep_var(` | no |
| 840 | `rscales = rep(1, n_rep)` | `as_survey_replicate(` — surveycore side, new | no |
| 849 | `rscales = rep(1, n_rep),` | `survey::svrepdesign(` opened at 844 — new JKn block | **yes** |

One hit, and it is in the JKn block. The three pre-existing argument sites —
one `as_survey_nonprob()` and two direct `.svy_rep_var()` calls — are outside
the rule and are unchanged by this PR.

### Row 2.4 — evidence

Both copies are written out in full. Neither is stored in a variable that the
other side reads, and neither is read off a design.

surveycore side, line 840:

```
    rscales = rep(1, n_rep)
```

`survey` side, line 849:

```
      rscales = rep(1, n_rep),
```

`n_rep` is defined at line 828 from the data frame, not from a design:

```
  repwt_cols <- grep("^repwt_", names(d), value = TRUE)
  n_rep <- length(repwt_cols)
```

`d` is the `make_survey_data()` fixture. No value crosses from one side to the
other. The two literals are textually identical.

### Row 3.1.4 — evidence

| Element the row requires | Delivered line | Held? |
|---|---|---|
| Type `JKn`, fixture mode `jkn` | `type = "jkn",` (fixture, line 824); `type = "JKn",` on both sides (838, 847) | ✓ |
| `R` read from the selected columns, not hard-coded | `n_rep <- length(repwt_cols)` (828); fixture `n_psu = 20` | ✓ |
| `rscales` one per replicate, all `1`, to both sides | `rep(1, n_rep)` twice (840, 849) | ✓ |
| The block asserts no warning fires | `expect_no_warning(` at 843 wrapping the `svrepdesign()` call | ✓ |
| `survey` stored scale asserted against `1` | `expect_equal(sv$scale, 1, tolerance = 1e-8)` (855) | ✓ |
| Tolerance on the scale is the SE/variance row, `1e-8` | `tolerance = 1e-8` | ✓ |
| Pinned — no agreement claimed | three `expect_failure()` wrappers on SE and both bounds | ✓ |

The pinned comment sits one line above the scale assertion, at line 854, and is
the fixed 99-character string:

```
  # Guards survey's default; a failure means survey changed, not surveycore; SE/variance row, 1e-8.
```

Measured: 99 characters. Exact-match count (`grep -Fxc`) is **11** at HEAD and
**10** at the base `d0de848` — one added, and it is byte-identical to the ten
that already shipped. The over-80 width is decision S4 and is not a defect.

---

## PR 5 acceptance criteria — the JKn half of the shape

Counted with `depth.awk`. Depth 2 is the `test_that()` body; depth 3 is inside a
call opened at depth 2.

| Criterion | Measured | Held? |
|---|---|---|
| Three `testthat::expect_failure()` wrappers | 3 code occurrences (`strip.awk`); at lines 865, 868, 871, all at depth 2 | ✓ |
| One assertion in each wrapper | each wrapper holds exactly one `expect_equal(` at depth 3 (866, 869, 872) and closes | ✓ |
| Wrappers cover the SE and the two confidence bounds | 866 `sc_mean$se` vs `survey::SE()`, 1e-8; 869 `ci_low` vs `confint()[1]`, 1e-6; 872 `ci_high` vs `confint()[2]`, 1e-6 | ✓ |
| Point estimate outside every wrapper | line 861, depth 2, `tolerance = 1e-10` | ✓ |
| Stored-scale assertion outside every wrapper | line 855, depth 2 | ✓ |
| Design-building call outside every wrapper | `expect_no_warning(sv <- survey::svrepdesign(` at 843–852, depth 2 | ✓ |
| No-warning assertion outside every wrapper | same call, depth 2 | ✓ |
| Ratio assertion outside every wrapper | lines 879–883, depth 2, unwrapped | ✓ |
| Ratio compares the two SEs against the literal `sqrt((R - 1) / R)` at `1e-8` | `sc_mean$se / as.numeric(survey::SE(sv_mean))` against `sqrt((n_rep - 1) / n_rep)`, `tolerance = 1e-8` | ✓ |
| `mse` passed explicitly to both sides | `mse = TRUE` at 839 (surveycore) and 848 (`survey`) | ✓ |
| No `scale =` passed to `svrepdesign()` in the new block | 0 occurrences in 834–884 | ✓ |
| Skip guard inside the block | `skip_if_not_installed("survey")` at 807, depth 2 | ✓ |

### Header numbering

`grep -n "^# Block "` at HEAD and at the base, then `diff` of the two lists. The
only difference is one added line:

```
803:# Block 24: Oracle blocks for the remaining replicate types
```

It sits at the end of the file, after Block 23 (line 751). Blocks 10, 11, 12,
16, 22 and 23 keep their numbers and their line positions. No renumbering.

### Block title and comment

Title, line 806:

```
test_that("get_means() JKn SE disagrees with survey::svymean() — issue #253", {
```

It names the disagreement ("disagrees"), names issue #253, and claims no match.
It is not of the form "X matches Y".

The block comment, lines 809–818, names issue #253 and says four lines:

```
  # When issue #253 lands, delete FOUR lines: the three expect_failure()
  # wrapper lines and the ratio assertion at the end of this block. Deleting
  # only the three leaves the ratio assertion to fail against the corrected
  # default.
```

Four, with the four named individually. Not three.

### Formatting

`air format --check tests/testthat/test-variance-replicate.R` exits 0 with no
output. The file keeps CRLF line terminators throughout, as at the base.

---

## CRAN cookbook violations

None. The PR touches no file under `R/`. The write surface is one test file.
The added lines were scanned for the cookbook patterns anyway: no `T`/`F` as
logicals (`TRUE` used throughout), no `set.seed(` (the fixture takes
`seed = 15` as an argument), no bare `print()`/`cat()`, no `<<-`, no
`options(warn = -1)`, no `installed.packages()`.

| File | Line | Violation | Class |
|---|---|---|---|
| — | — | none | — |

---

## Out of scope — recorded, not counted against this PR

| Item | Why it is not a defect here |
|---|---|
| Rows 2.9, 2.10, 2.11, 2.15, 2.16, §3.6 | They count the JKn and bootstrap blocks together ("3 and 3", "1 and 1"). The bootstrap block lands in PR 6. The JKn half is measured above. |
| Rows 3.1.5, 3.1.8, 3.1.9 | bootstrap, `other`, Fay — PRs 6, 7, 8. |
| §4, §5, §6 | PR 7; shipped in PR 4; PRs 1, 2, 9. |
| Line 174, `expect_equal(sc@variables$scale, 1)` with no explicit tolerance | Finding N2, recorded, deliberately untouched. Not this PR's surface. |
| Two old BRR blocks pass `mse` to one side only | Pre-existing, out of scope. The new block passes it to both. |
| The 99-character stored-scale comment exceeds the 80-column limit | Decision S4. The three required elements do not fit in 80. |

---

## Before/After Comparison

Gate run on tree `ba47cff369806d0c550db3d9ecb8f05e7f3600c1` — the tree this
audit records.

| Metric | Before PR (PR 4) | After PR | Δ |
|---|---|---|---|
| tests passing | 11982 | 11989 | **+7** |
| failures | 0 | 0 | 0 |
| warnings | 256 | 256 | 0 |
| skips | 4 | 4 | 0 |
| coverage | 96.15% | 96.15% | 0.00 |
| R CMD check notes | 2 pre-approved | 2 pre-approved | 0 |

Baseline chain from `7800ea9`: 11941 passes, PR 3 11977, PR 4 11982, this PR
11989. Coverage holds at the baseline figure because the PR touches no file
under `R/`.

**Why a pinned block adds 7 passes and no failures.** The +7 is the new block's
whole expectation count. Three of its assertions fail by design — the standard
error and the two confidence bounds. Each failure is consumed by its own
`testthat::expect_failure()` wrapper, and the wrapper is what the suite counts.
So the suite total moves up by 7 and the failure count stays at 0. A reader who
expects "pinned" to cost failures should read it here.

## Profile gates

Run by the leader on tree `ba47cff369806d0c550db3d9ecb8f05e7f3600c1`. This
audit started no R process, by instruction: a gate pass was in flight on this
exact tree, and two agents running R at once corrupted a log set on an earlier
arc.

| Gate | Result | Notes |
|---|---|---|
| `devtools::document()` | PASS | `document()` wrote nothing |
| `devtools::test()` | PASS | `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11989 ]` |
| `devtools::run_examples()` | PASS | all examples ran |
| `R CMD build` | PASS | `surveycore_1.1.0.9000.tar.gz` |
| `R CMD check --as-cran --no-manual` | PASS | Status: 2 NOTEs — see below |
| pkgdown | SKIPPED — scope | one test file; `NAMESPACE` diff empty |
| `covr` | PASS | 96.15% |
| `air format --check` (CLI, run in this audit) | PASS | exit 0, no output, on `tests/testthat/test-variance-replicate.R` |
| CRAN cookbook scan (run in this audit) | PASS | 0 violations; no `R/` file touched |

Logs: `.surveycore-workspace/runs/2026-09-16-replicate-oracle-tests/logs/pr5/`

### Both NOTEs are pre-existing — a third blocks

Read gate 5 as "2 NOTEs, and these two". Neither is a new pattern.

| NOTE | Why it does not block |
|---|---|
| `checking CRAN incoming feasibility` | Pre-approved in `.claude/rules/r-package-conventions.md`. The package is not on CRAN. |
| `checking for hidden files and directories` | `R CMD build` finds `.git`; caused by `.Rbuildignore`. Present on the clean baseline and unfixable by this arc. |

Both are identical on the baseline and on PRs 1 to 4. A third NOTE blocks.

Tree: ba47cff369806d0c550db3d9ecb8f05e7f3600c1

## BLOCKs

None.
