# Audit — PR 9 — docs/oracle-rule-exceptions

**Verdict**: PASS
**Date**: 2026-09-22
**Branch**: `docs/oracle-rule-exceptions` at `9123681`
**Base**: `d6d30c7` (`develop` with PRs 1-8 of this arc)

Tree: 829adc683ed44472b48f3707a36c9308c4639f78

## Scope read

`git diff d6d30c7 HEAD` returns one file, `+15/-1`:
`.claude/rules/testing-surveycore.md`. The single deletion is the version
header, `1.2` -> `1.3` (decision S2 of the run's `decisions.md`; one bump at
the end of the arc in place of three along it). No row requires it and it is
not a defect.

`git diff --name-only d6d30c7 HEAD -- tests R man NAMESPACE DESCRIPTION`
returns zero lines, so `tests/testthat/test-variance-replicate.R` is
byte-identical to the base branch. Rows 3.5.1 to 3.5.6 measure that finished
file.

## Method

- Counts come from `utils::getParseData()` on `parse(keep.source = TRUE)`,
  walking each `test_that()` call's body as a language object. No textual
  count was used: on this file `expect_failure` reads 12 textually against 6
  real calls, and `svrepdesign` reads 18 against 14.
- The runs use `NOT_CRAN=true Rscript -e 'testthat::test_local(filter =
  "variance-replicate")'`.

## Per-Test Result Table

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| 3.5.1 file runs with `survey` installed | `[ FAIL 0 \| WARN 1 \| SKIP 0 \| PASS 166 ]` | 0 failures, 0 skips | exact | ✓ |
| 3.5.2 block count | 28 | 28 | exact | ✓ |
| 3.5.3 types with an oracle block | 9 of 9 | 9 of 9 | exact | ✓ |
| 3.5.4 file runs with `survey` absent | `[ FAIL 0 \| WARN 1 \| SKIP 14 \| PASS 60 ]` | every `survey` block skips, nothing fails | exact | ✓ |
| 3.5.5 new warnings in the file's own run | 0 new; 1 pre-existing | none new | exact | ✓ |
| 3.5.6 a no-warning assertion fires | none fired | none | exact | ✓ |
| 6.10 section records an expectation total or a run time | neither | none | exact | ✓ |
| 6.15 the two sanctioned exceptions, with issues | both named, #253 and #243 | present | exact | ✓ |

Tally: 8 of 8 passed.

## Evidence, row by row

### 6.15 — the two sanctioned exceptions

The delivered section, `.claude/rules/testing-surveycore.md` line 299, reads:

> ### Sanctioned exceptions in `test-variance-replicate.R`
>
> Two blocks in that file break the rule's normal shape on purpose. Both close
> with a named issue. Anything else that breaks the shape is a violation.
>
> - **The JKn and bootstrap blocks wrap three failing assertions in
>   `testthat::expect_failure()`.** surveycore's stored default disagrees with
>   `survey` today, and branch protection needs a green suite. Issue #253
>   changes the two defaults and deletes the wrappers.
> - **The Fay block compares nothing.** `survey` refuses `type = "Fay"` without
>   a `rho`, and surveycore has no `rho` argument, so the block asserts the
>   refusal on one side and the stored scale on the other. Issue #243 adds the
>   argument and rewrites the block into a real comparison.

Both exceptions are named, each carries the issue that closes it (#253, #243),
and the third sentence states that anything else that breaks the shape is a
violation. The subsection sits inside the oracle rule section, after
"What the rule covers" and before "S7 error testing layers".

Measured against the file: the parse walk finds `expect_failure()` in exactly
two blocks, 3 calls each, and both are the blocks the text names — block 25
"get_means() JKn SE disagrees with survey::svymean() — issue #253" and block
26 "get_means() bootstrap SE disagrees with survey::svymean() — issue #253".
Block 28 is "survey::svrepdesign() refuses Fay without rho — Fay design".

### 6.10 — no expectation total, no run time

I read the whole oracle rule section, lines 165 to 312, and listed every line
holding a digit. The numbers present are: rule ordinals (rules 1 to 5), issue
numbers (#242, #253, #243, #169 in the neighbouring section), scale formulas
(`1/R`, `(R-1)/R`, `4/R`, `1/(R * (1 - rho)^2)`), the oracle versions
(`survey` 4.5, R 4.6.1), and "survived 22 releases", which is a release count
and not an expectation total. No line records a count of expectations and no
line records a run time. Issue #215's ban is met.

### 3.5.1 — the run with `survey` installed

    NOT_CRAN=true Rscript -e 'testthat::test_local(filter = "variance-replicate")'
    [ FAIL 0 | WARN 1 | SKIP 0 | PASS 166 ]

0 failures and 0 skips. The one warning is row 3.5.5's, below.

### 3.5.2 — 28 blocks

`parse(keep.source = TRUE)` gives 28 top-level `test_that()` calls, and
`getParseData()` holds 28 `SYMBOL_FUNCTION_CALL` tokens with text
`test_that`, so no block is nested inside another and none is hidden in a
helper. 24 before the arc plus the four new blocks (JKn, bootstrap, other,
Fay) is 28. No reason statement is needed.

### 3.5.3 — nine of nine types

Per-block `type =` literals from the AST, crossed with the blocks whose parse
tree holds a `survey::` call:

| Type | Blocks naming the type | Oracle blocks among them |
|---|---|---|
| BRR | 1, 2, 6, 7, 8, 15, 16, 19-24 | 1, 2, 6, 8 |
| JK1 | 3 | 3 |
| JK2 | 4, 5 | 4 |
| JKn | 25 | 25 |
| bootstrap | 26 | 26 |
| ACS | 10, 13, 14 | 13, 14 |
| successive-difference | 9, 11, 12 | 11, 12 |
| other | 27 | 27 |
| Fay | 28 | 28 |

Nine types, each with at least one block that calls `survey`. 9 of 9.

### 3.5.4 — the run with `survey` absent

`survey` was left installed and the real library was not touched. I built a
scratch library and put it ahead of the real one with `R_LIBS`:

- `<scratch>/fakelib/survey/DESCRIPTION` describes a package with no code.
- `find.package("survey")` stops at that directory, `loadNamespace()` then
  fails on it, and `requireNamespace("survey", quietly = TRUE)` returns
  `FALSE` without searching on.

Probe under the setup, before the run:

    .libPaths()[1]  <scratch>/fakelib
    .libPaths()[2]  C:/Users/jdennen/AppData/Local/Programs/R/R-4.6.1/library
    find.package("survey")            -> <scratch>/fakelib/survey
    requireNamespace("survey", TRUE)  -> FALSE
    requireNamespace("testthat", TRUE)-> TRUE

The default library list on this host is that one R library, so the run
environment differs from the normal one only by the shadow.

    NOT_CRAN=true R_LIBS=<scratch>/fakelib Rscript -e 'testthat::test_local(filter = "variance-replicate")'
    [ FAIL 0 | WARN 1 | SKIP 14 | PASS 60 ]

14 skips, which equals the 14 blocks whose parse tree holds a `survey::`
call, measured independently by the AST walk. Every skip reason string is
the same:

    Reason: {survey} cannot be loaded

Skipped block lines: 13, 56, 97, 151, 240, 313, 404, 446, 488, 530, 807,
887, 968, 1027. Nothing failed.

### 3.5.5 and 3.5.6 — warnings

Both runs raise exactly one warning, at the same place:

    WARNING: 'test-variance-replicate.R:798:3'
    ! 1 cell has fewer than 30 unweighted observations. Estimates in these
      cells may be unreliable for public reporting (AAPOR guidance).
    Backtrace:
     1. surveycore::get_corr(sc, x = c(y1, y2), variance = "se")
          at test-variance-replicate.R:798:3
     2.   cli::cli_warn(...) at R/analysis-corr.R:498:5

Line 798 sits in block 24, `get_corr() replicate returns NA for domain with
fewer than 2 paired obs` — the correlation block §3.5.5 names. It is one of
the 256 pre-existing small-cell warnings and it touches no oracle block, so
it is reported and not blocked, per §10.

No new warning. No no-warning assertion fired: both runs report FAIL 0, and
the "Data do not look like combined weights" text appears in neither run's
output. No seed or warning text has to be reported under 3.5.6.

## CRAN cookbook violations

None. The diff holds no file under `R/` — one file changed,
`.claude/rules/testing-surveycore.md`, so the scan has no target.

## Before/After Comparison

| Figure | Baseline (`7800ea9`) | PR 8 | This PR | Δ |
|---|---|---|---|---|
| Failures | 0 | 0 | 0 | 0 |
| Warnings | 256 | 256 | 256 | 0 |
| Skips | 4 | 4 | 4 | 0 |
| Passes | 11941 | 12005 | 12005 | **0** |
| Coverage | 96.15% | 96.15% | 96.15% | 0.00 |
| R CMD check notes | 2 | 2 | 2 | 0 |

A zero delta is the correct result here, not a missing measurement. The only
changed path is `.claude/rules/testing-surveycore.md`, which `.Rbuildignore`
excludes from the package and which no test opens at run time, so `R/` and
`tests/` are byte-identical to PR 8. Movement in any of these figures would
mean something leaked outside the write surface.

The single-file measurements stand alongside it:
`[ FAIL 0 | WARN 1 | SKIP 0 | PASS 166 ]` with `survey` present, and
`[ FAIL 0 | WARN 1 | SKIP 14 | PASS 60 ]` with `survey` absent.

## Profile gates

Run on tree `829adc683ed44472b48f3707a36c9308c4639f78` — the tree this audit
records. All gates pass.

| Gate | Result | Notes |
|---|---|---|
| `devtools::document()` | PASS | `document()` wrote nothing |
| `devtools::test()` | PASS | `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 12005 ]` |
| `run_examples()` | PASS | all examples ran |
| `R CMD build` | PASS | `surveycore_1.1.0.9000.tar.gz` |
| `R CMD check --as-cran --no-manual` | PASS | Status: 2 NOTEs |
| pkgdown | SKIPPED — scope | the write surface is one file under `.claude/`, which `.Rbuildignore` excludes; `NAMESPACE` diff empty |
| `covr` | PASS | 96.15% |
| CRAN cookbook scan | PASS | no `R/` file in the diff |

Logs: `.surveycore-workspace/runs/2026-09-16-replicate-oracle-tests/logs/pr9/`

### Both NOTEs are pre-existing

Read gate 5 as "2 NOTEs, and these two". A third NOTE blocks.

- `checking CRAN incoming feasibility` — pre-approved in
  `r-package-conventions.md`; the package is not on CRAN.
- `checking for hidden files and directories` — `R CMD build` finds `.git`;
  caused by `.Rbuildignore`, present on the clean baseline, and this arc
  cannot fix it.

Both are identical on the baseline and on all eight earlier PRs of the arc.
Neither is a new pattern.

Tree: 829adc683ed44472b48f3707a36c9308c4639f78

## BLOCKs

None.

## Verdict

PASS. All eight allocated rows pass — 3.5.1 to 3.5.6, 6.10 and 6.15 — every
profile gate passes on the same tree, the pkgdown skip is within the
documented scope condition, and the CRAN cookbook scan has no target. This
audit is final.
