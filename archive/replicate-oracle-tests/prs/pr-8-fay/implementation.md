# implementation.md, PR 8, test/replicate-oracle-fay

## Write surface

| File | Action |
|---|---|
| `tests/testthat/test-variance-replicate.R` | modified, 49 lines added, 0 removed |

No other file. Nothing under `R/`. No roxygen changed, so no
`devtools::document()` run and no `NAMESPACE` or `man/` diff.

## Base

| Item | Value |
|---|---|
| Worktree came up on | `d4d1db2fe2de42243213d30c5bb56639906494b4`, stale `main` |
| Reset to | `d389bdaf514ce59c97523c63499639c532b1e519` |
| Discarded by the reset | local edits to `.claude/settings.local.json` only, 84 insertions and 91 deletions, session permission bookkeeping |
| Branch | `test/replicate-oracle-fay` |

## Summary

* Added the Fay block, fourth and last under the existing
  `# Block 24:` header, after the `other` block. No header added, nothing
  renumbered, no shipped block touched.
* The block compares nothing. It asserts `survey`'s refusal by the message
  fragment `With type='Fay' you must supply the correct rho`, and
  surveycore's stored scale against `1 / n_rep`.
* It carries no `expect_failure()`. There is no comparison to wrap.
* It carries no canonical stored-scale comment, because it asserts
  surveycore's stored scale and not `survey`'s. The count of that exact
  comment stays at 13.
* The file now holds 28 `test_that()` blocks and covers nine of the nine
  replicate types.

## The two probes, verbatim

Probe script run with `devtools::load_all()` plus
`source("tests/testthat/helper-test-data.R")`, on
`make_survey_data(n = 200, n_psu = 20, n_strata = 4, design = "replicate",
type = "fay", seed = 15)`. The script was deleted before the commit.

### Probe 1, the refusal

`survey::svrepdesign(weights = d$wt, repweights = d[, repwt_cols],
type = "Fay", data = d)` with no `rho`:

```
class: simpleError/error/condition
MSG_START>>> With type='Fay' you must supply the correct rho <<<MSG_END
```

The message is the whole message, not a fragment of a longer one. The
condition carries no class but `simpleError`, so the block matches the text.

### Probe 2, the surveycore stored scale

`as_survey_replicate(d, weights = wt, repweights = all_of(repwt_cols),
type = "Fay")`:

```
R = 10
sc scale: 0.10000000000000001
1/R     : 0.10000000000000001
identical: TRUE
```

`R` is 10, not 20: the generator returns `n_psu %/% 2` replicate columns in
the `fay` mode as it does in `brr`. `identical()` is TRUE, so the assertion
holds well inside the 1e-8 stored-scale tolerance.

### Non vacuity of both assertions

Measured in the same probe, with the expectation deliberately wrong:

| Mutation | Result |
|---|---|
| fragment changed to `With type='BRR' you must supply the correct rho` | errored as it should, the original error propagates |
| scale expectation changed to `1 / 20` | failed as it should |

Neither assertion passes on a wrong expectation.

## The instrument for every count below

One R script, deleted before the commit. It ran
`parse(file, keep.source = TRUE)`, took `utils::getParseData()` on the
result, and kept only rows with `terminal` TRUE and `token != "COMMENT"`.
Every count below reads that filtered token table, by token class:

* `SYMBOL_FUNCTION_CALL` for function calls,
* `SYMBOL_PACKAGE` for `survey::` namespace uses,
* `STR_CONST` for type strings,
* `srcref` line ranges of the top level `test_that()` calls for block
  membership.

Textual `grep` is quoted only where the task asked for the contrast. The
two the task named came out as it predicted:

| Token | Parse count | Text count |
|---|---|---|
| `expect_failure` | 6 | 12 |
| `svrepdesign` | 14 | 18 |

The parse count of `svrepdesign` is 13 on the base plus the one this block
adds. Text counts use `grep` on `readLines()` and include comment lines.

## Task 7, the five whole file figures

### 1. The skip guard, by parse

| Measure | Value | Instrument |
|---|---|---|
| `skip_if_not_installed` calls | 14 | `SYMBOL_FUNCTION_CALL` tokens |
| Blocks that call `survey` | 14 | blocks holding a `SYMBOL_PACKAGE` token `survey` |
| Calls inside a `test_that()` body | 14 of 14 | line number inside a block `srcref` |
| Blocks calling `survey` with exactly one guard | 14 of 14 | per block count |
| Blocks not calling `survey` that carry a guard | 0 | per block count |

The two counts are equal at 14, and no call sits outside a body. Textual
`grep` agrees at 14 here, because the file writes the call name in no
comment.

### 2. Types with at least one oracle block, nine of nine

Instrument: `STR_CONST` tokens, unquoted and matched exactly against the
nine type names, then mapped to block line ranges.

| Type | Blocks |
|---|---|
| BRR | 13 |
| JK1 | 1 |
| JK2 | 2 |
| JKn | 1 |
| bootstrap | 1 |
| ACS | 3 |
| successive-difference | 3 |
| other | 1 |
| Fay | 1 |

Nine of nine. Fay was the last gap and this block closes it.

### 3. The order of the four blocks under the header

Instrument: `srcref` start lines of the `test_that()` calls that begin after
the `# Block 24:` header line, 803. The file holds 7 `# Block N:` headers
and this PR added none.

| Position | Lines | Type |
|---|---|---|
| 1 | 806 to 884 | JKn |
| 2 | 886 to 965 | bootstrap |
| 3 | 967 to 1024 | other |
| 4 | 1026 to 1073 | Fay |

JKn, bootstrap, `other`, Fay. No interleaving with an earlier section.

### 4. The estimator in each of the four blocks

Instrument: `SYMBOL_FUNCTION_CALL` tokens inside each block's line range,
intersected with `get_means`, `svymean`, `get_totals`, `svytotal`.

| Block | Estimator tokens |
|---|---|
| JKn | `get_means` and `svymean` |
| bootstrap | `get_means` and `svymean` |
| other | `get_means` and `svymean` |
| Fay | none |

The three comparing blocks each estimate the mean of `y1` with
`get_means()` on the surveycore side and `survey::svymean(~y1, ...)` on the
other. The Fay block calls neither. See the note on criterion 7 below.

### 5. The titles that claim no match

Instrument: the `STR_CONST` first argument of each `test_that()` call, of
the 14 blocks that hold a `survey` namespace token, filtered to titles that
do not contain the word `matches`.

| Names issue #253 | Title |
|---|---|
| no | `get_means() BRR scale formula 1/n_rep is correct for n_rep != 4` |
| yes | `get_means() JKn SE disagrees with survey::svymean(), issue #253` |
| yes | `get_means() bootstrap SE disagrees with survey::svymean(), issue #253` |
| no | `survey::svrepdesign() refuses Fay without rho, Fay design` |

The two dash separators in the real titles are em dashes; this table writes
commas in their place, because the heredoc that wrote this file rejects the
character.

Of the three blocks the criterion names, three of three claim no match:
JKn, bootstrap, Fay. Two of two name issue #253: JKn and bootstrap. The Fay
title names the refusal and no issue number, and #243 lives in the block
comment instead.

**One extra row, reported rather than hidden.** The word filter also catches
a fourth title, `get_means() BRR scale formula 1/n_rep is correct for
n_rep != 4`. That block predates this arc and this PR does not touch it. It
claims a formula is correct, not that the two sides agree, so it is not one
of the three the criterion names. The figure is three of three on the named
blocks and four on the plain word filter.

## Task 8, the three round trip findings

I read the file once end to end and backed each finding with a parse level
check.

### Finding 1. No block passes a value read off one design into the other

Instrument: a recursive walk of the parse tree. It found every call whose
function is `svrepdesign` or `as_survey_replicate`, 40 calls in all, and
deparsed each one's arguments.

| Measure | Value |
|---|---|
| Constructor calls inspected | 40 |
| Calls whose arguments hold an `@` property read | 0 |
| Calls whose arguments hold a bare `scale =` | 0 |
| Calls whose arguments hold a `rho =` | 0 |
| Calls whose arguments hold `rscales =` | 2 |

The two `rscales` calls are the JKn block's two sides. Each writes the
literal `rep(1, n_rep)` out in full, where `n_rep` is the replicate count
read from the selected column names. Neither copy is read off a design, and
the spec allows the argument in that one block. Nothing else in the file
passes any value that came out of a design object.

### Finding 2. No block asserts one side's stored scale against the other's

Instrument: every code token named `scale`, `rscales`, `variables` or `rho`,
with its source line printed. 25 hits, on 21 distinct lines. Every stored
scale assertion in the file compares one side against a literal or against a
formula in the replicate count:

| Side read | Assertions | Right hand side |
|---|---|---|
| `sv$scale` | 13 | a literal or a formula in the replicate count |
| `sc@variables$scale` | 4 | a literal or a formula in the replicate count |

The Fay block's line 1072 is one of the four surveycore side reads:
`expect_equal(sc@variables$scale, 1 / n_rep, tolerance = 1e-8)`. No
assertion anywhere in the file has a design property on both sides. The
remaining four hits are two internal helper blocks that build a literal
`rscales <- rep(1L, 5L)` and pass it straight to `.svy_rep_var()`; no
`survey` design is involved.

### Finding 3. No shared function returns both designs

| Measure | Value | Instrument |
|---|---|---|
| Top level expressions in the test file | 28 | `parse()` |
| Of those, `test_that()` calls | 28 | first element of each call |
| Top level definitions of anything else | 0 | the difference |
| Helper files in `tests/testthat/` | 1, `helper-test-data.R` | `Sys.glob` |
| Mentions of `svrepdesign` in it | 0 | `grep` on `readLines()` |

The file defines nothing at file level, so there is no shared builder to
audit, and the one helper file never touches `survey`. Every block builds
both sides inline in its own body.

## Other whole file figures measured on the way

All by parse, `SYMBOL_FUNCTION_CALL` tokens, comments excluded:

| Measure | Value |
|---|---|
| `test_that()` blocks | 28 |
| `test_invariants(` calls | 1 |
| `suppressWarnings(` calls | 0 |
| Lines carrying the canonical stored scale comment | 13 |
| Lines longer than 80 characters | 25, all of them on the base, none added |

The canonical comment count is 13, unchanged. The Fay block adds none,
because it asserts surveycore's stored scale and not `survey`'s.

## Task checklist

* [x] 1. Probed the refusal. Message captured verbatim, class
  `simpleError`.
* [x] 2. Probed the surveycore side. Stored scale 0.1, `identical()` to
  `1 / R` at `R = 10`.
* [x] 3. Wrote the block last under the `# Block 24:` header, with both
  assertions.
* [x] 4. The comment states all three things: issue #243 and the later PR
  that adds `rho`; that the first half guards `survey`'s behaviour; and how
  to read a failure on that half.
* [x] 5. The title names the refusal and carries no issue number.
* [x] 6. Ran the single file. 0 failures.
* [x] 7. Measured and reported all five whole file figures, each with its
  instrument.
* [x] 8. Read the file once and reported the three round trip findings.
* [x] 9. Ran `air format --check` and `git diff --name-only d389bda`.
* [x] 10. Ran no full suite, no `check()`, no `document()`, no
  `run_examples()`, no `pkgdown`, no `covr`.

## Gate results I ran myself

| Command | Result |
|---|---|
| `NOT_CRAN=true Rscript -e 'testthat::test_local(filter = "variance-replicate")'` | `FAIL 0`, `WARN 1`, `SKIP 0`, `PASS 166` |
| `air format --check tests/testthat/test-variance-replicate.R` | exit 0, no output |
| `git diff --name-only d389bda` | `tests/testthat/test-variance-replicate.R`, one file |

The one warning is not mine. It fires at
`test-variance-replicate.R:798:3`, in the `get_corr()` block, and is the
pre existing AAPOR small cell warning that clean `develop` also raises.

## Criterion 7 and the Fay block, what it does instead

Criterion 7 asks that each of the four new blocks estimate the mean of `y1`
with `get_means()` on one side and `survey::svymean(~y1, ...)` on the other.
The Fay block calls neither, and the dispatch note told me to read the
clause as governing the three comparing blocks and to say here what the Fay
block does instead.

It does this:

1. It builds one fixture, the `fay` mode at seed 15, and reads the
   replicate count from the selected column names, 10 of them.
2. It calls `survey::svrepdesign()` on that fixture with `type = "Fay"` and
   no `rho`, and asserts the error message fragment. `survey` raises before
   it builds a design, so there is no `survey` design to estimate from.
3. It calls `as_survey_replicate()` on the same columns with `type = "Fay"`
   and nothing else, and asserts the stored scale is `1 / n_rep`.

So the estimator clause has nothing to bind to on this block, and the two
halves of the gap are what the block pins. This is not a HOLD. Spec section
V.9 fixes the shape as refusal only, and spec section IV states that blocks
1 to 8 are the numerical oracle blocks and that block 9 follows V.9
instead. The estimator sentence in spec section IV.1 names Fay among the
four new blocks, which reads against V.9; V.9 is the more specific rule for
this block and I followed it. I record the tension here rather than bend
the block to fit.

## Two small judgements, recorded

1. **Neither side receives `mse`.** Spec section V.9 says the surveycore
   call passes `type = "Fay"` and nothing else supplied, and describes the
   `survey` call as carrying `type = "Fay"` and no `rho`. Spec section
   IV.2's always explicit `mse` row governs the numerical blocks, which
   assert an estimate. This block asserts none, so `mse` could not reach
   any assertion on either side: `survey` raises before it reads the
   argument, and the surveycore half asserts only the stored scale. I kept
   both calls minimal, to match V.9 word for word.
2. **The block asserts no class on the returned design.** Spec section V.9
   item 2 says `as_survey_replicate()` returns a design and stores
   `scale = 1 / R`. The stored scale read is through `sc@variables$scale`,
   which cannot succeed unless the constructor returned the S7 object, so
   the return is proved by the assertion that follows it. I added no
   separate `S7_inherits()` assertion, to keep one observable behaviour per
   block.

## HOLDs

None.

## Notes for the tester

* The block's stored scale assertion carries an explicit
  `tolerance = 1e-8`. The three older surveycore side stored scale reads in
  the file, at lines 174, 379 and 400, carry no explicit tolerance. Line
  174 is finding N2 and was deliberately left alone by an earlier PR; I
  left all three untouched.
* The em dash in the block title follows the file's own precedent. Every
  other Block 24 title uses one.
* No shipped block was edited. `git diff` shows 49 added lines and 0
  removed.
