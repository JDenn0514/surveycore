# Review — PR 8 — test/replicate-oracle-fay

**Verdict**: PASS
**Date**: 2026-09-22
**Branch**: `test/replicate-oracle-fay` at `d8c50cd37346631c6dbda4221f89858b22d187d6`
**Base**: `d389bdaf514ce59c97523c63499639c532b1e519`
**Tree reviewed**: `c23121ef6ad6423375765ffaaa277d2c4ac530eb` — identical to the tree
`audit.md` records and to `git rev-parse 'HEAD^{tree}'` in the worktree.

## Convergence checks

| Check | Result |
|---|---|
| Spec coverage — every `spec.md` §V.9 item has an `audit.md` row | y |
| Test-spec coverage of spec — §3.3 and row 3.1.9 cover §V.9 | y |
| Tolerance integrity — every tolerance equals the test-spec value | y |
| Scope discipline — write surface matches the plan's Files touched | y |
| Regression safety — nothing outside PR scope changed state | y |
| CRAN cookbook and profile gates | y |
| Coverage floor | y |
| Comprehension alignment | y |

## Step 1 — spec coverage

`spec.md` §V.9 states four requirements. Each has an audit row and each holds on
the tree.

| §V.9 item | Audit row | Verified here |
|---|---|---|
| `svrepdesign()` refuses Fay without `rho`; match the message text | 3.1.9 | `expect_error(..., "With type='Fay' you must supply the correct rho", fixed = TRUE)`, lines 1050-1060 |
| `as_survey_replicate()` returns a design and stores `scale = 1 / R` | 3.1.9 | `expect_equal(sc@variables$scale, 1 / n_rep, tolerance = 1e-8)`, line 1072; `n_rep <- length(repwt_cols)` |
| The comment states three things | 2.12 | lines 1029-1037 state all three: issue #243 and the later PR that adds `rho`; the first half guards `survey`; how to read a failure there |
| The title claims no match and names the refusal | 2.23 | `survey::svrepdesign() refuses Fay without rho — Fay design` |

`implementation-plan.md` PR 8 allocates ten test-spec rows. `audit.md` carries
ten rows and all ten pass. No spec item is unvalidated.

## Step 2 — tolerance integrity

`test-spec.md` §8 sets point `1e-10`, standard error and variance `1e-8`,
confidence bounds `1e-6`, and allows no deviation. A stored-scale assertion
takes the standard-error and variance row.

Measured across the whole file with `grep`: 14 hits at `1e-10`, 30 at `1e-8`, 26
at `1e-6`, and no other value. The Fay block's one numerical assertion carries
`tolerance = 1e-8`, which is the row the stored scale belongs to. No assertion
in the file is looser than its test-spec row.

## Step 3 — scope discipline

`implementation.md` §Write surface lists `tests/testthat/test-variance-replicate.R`
only. The plan's Files touched entry for PR 8 lists the same one file.
`git diff --numstat d389bda HEAD` reads `49 0 tests/testthat/test-variance-replicate.R`
— append-only, one file. No extra file, no missing file.

No regression outside scope. Against PR 7: failures 0 to 0, warnings 256 to 256,
skips 4 to 4, passes 12003 to 12005, coverage 96.15% to 96.15%, check NOTEs 2 to
2. The +2 is the Fay block's two expectations, which is the count a
non-comparing block contributes; a comparing block in this file carries five
numerical assertions plus its condition assertion.

## Step 4 — CRAN cookbook and profile gates

`audit.md` §CRAN cookbook violations reads "None" and the verdict is PASS. The
write surface holds no file under `R/`.

Every gate carries a result. `pkgdown` is `SKIPPED — scope`: the write surface
touches no file in `r-package-profile.md`'s pkgdown list, and the `NAMESPACE`
diff is empty, so the hard rule about export changes does not reach this PR.
The skip is inside the allowed set.

Two NOTEs, both pre-existing: `checking CRAN incoming feasibility`, which is
pre-approved, and `checking for hidden files and directories`, which
`.Rbuildignore` causes on `.git` and which stands on the arc baseline and on
every PR from 1 to 7. Confirmed in `logs/pr8/gate-5-check.log`. No new NOTE
pattern, so no escalation.

## Step 5 — coverage floor

`logs/pr8/gate-7-covr.log` reads `COVERAGE_PCT=96.15`, above the 95% floor and
flat against the baseline and against PR 7. The PR adds no line under `R/`, so
there are no new lines to leave uncovered.

## Step 6 — comprehension alignment

Three `comprehension.md` gotchas reach this block, and the block honours all
three:

- `R` differs by generator mode on the same `n_psu` — the block reads
  `n_rep <- length(repwt_cols)` and hard-codes no count. `fay` follows `brr`, so
  `R` is 10 and `1 / n_rep` is `0.1`.
- No block passes `combined.weights` — this one passes none.
- `test_invariants()` once per constructor per file — the file holds exactly one
  call, in the first block.

Open question O5 asked whether Fay becomes a ninth block or a comment. It is
RESOLVED in `decisions.md` as the ninth block, and that is what shipped.

## Whole-file gates — re-measured independently

This is the last PR that writes the file, so I re-measured every whole-file gate
with my own instrument rather than accepting the tester's figures.

**Instrument.** `parse(file, keep.source = TRUE)` plus `utils::getParseData()`,
keeping rows with `terminal` TRUE and `token != "COMMENT"`, so comments and
string contents are both excluded from every call count. Block membership comes
from the `srcref` line span of each top-level expression. Constructor arguments
come from a recursive walk of the parse tree, which reads named arguments off
the call object itself and never off the text. This is a different instrument
from the tester's awk strippers, so the agreement below is two instruments, not
one repeated.

| Gate | Requirement | Measured | Tester | Agrees |
|---|---|--:|--:|---|
| 1 | nine types have a block | 9 of 9 | 9 of 9 | yes |
| 2 | no `scale` to `svrepdesign()` | 0 | 0 | yes |
| 3 | one `rscales`, in JKn, same literal both sides | 1 | 1 | yes |
| 4 | no `suppressWarnings()` | 0 | 0 | yes |
| 5 | no value read off one design into the other | 0 of 40 constructor calls | 0 of 40 | yes |
| 6 | every `survey`-building block asserts a condition | 14 of 14 | 14 of 14 | yes |
| 14 | skip guard inside every block that calls `survey` | 14 hits, 14 inside spans, 14 distinct blocks, set equal to the 14 that call `survey` | 14 / 14 | yes |
| 15 | `test_invariants(` exactly once | 1, line 31 | 1 | yes |
| 16 | 28 `test_that()` blocks | 28 top-level expressions, 28 of them `test_that()`, 0 anything else | 28 | yes |
| 17 | three titles claim no match | 3 of 3, two naming #253 | 3 of 3 | yes |

Detail on the ones that carry a judgement.

**Gate 1.** Type read from `STR_CONST` tokens inside the 14 spans that call
`svrepdesign()`: BRR 1, 2, 6, 8; JK1 3; JK2 4; JKn 25; bootstrap 26; ACS 13, 14;
successive-difference 11, 12; other 27; Fay 28. Fay was the last gap.

**Gate 3.** Two `rscales =` arguments exist in the file and both are in block
25: one on `survey::svrepdesign()` and one on `as_survey_replicate()`. Each
deparses to `rep(1, n_rep)`, the identical literal written out twice. Exactly
one reaches `svrepdesign()`, which is what the gate counts.

**Gate 5.** The walk found 40 constructor calls, 26 `as_survey_replicate()` and
14 `survey::svrepdesign()`. No call has an argument containing `@`, `sv$`, `sc$`
or a `$scale` read. Zero `scale =`, zero `rho =`. Separately, all 17
stored-scale assertions in the file put a design property on the left and a
literal or a formula in `R` on the right; none has a design property on both
sides.

**Gate 6.** Ten blocks use `expect_no_warning(sv <- survey::svrepdesign(...))`;
three — JK1, JK2, `other` — use `capture_warnings()` with `expect_length(..., 1L)`
and `expect_match(fragment, fixed = TRUE)`, so the warning-count guard is present
on all three; one, Fay, uses `expect_error(fragment, fixed = TRUE)`.

**Gates 7 and 8, also final here.** All 13 numerical oracle blocks carry the
point estimate, the standard error, both confidence bounds and `survey`'s stored
scale. The two pinned blocks each carry three `expect_failure()` wrappers and one
unwrapped ratio assertion against `sqrt((R - 1) / R)`, and each comment names
issue #253 and says FOUR lines.

**The two counting traps.** My parse instrument reads `expect_failure` at 6
against a textual 12, and `svrepdesign` at 14 against a textual 18. Both match
the figures the task named, and both match the tester's `strip2.awk`. The third
trap — the `svrepdesign` occurrence inside the Fay block's title string at line
1026 — is excluded by construction here, because a `STR_CONST` token is never a
`SYMBOL_FUNCTION_CALL`.

**The canonical stored-scale comment count is 13, confirmed.** An exact-text grep
returns 13 lines: 43, 84, 138, 195, 269, 344, 433, 475, 517, 559, 854, 930, 1014.
Each sits one line above one of the 13 `sv$scale` assertions. The Fay block's
line 1072 asserts `sc@variables$scale`, surveycore's own stored scale, so it
takes no canonical comment and carries none. A 14th would have been the defect.

## Rulings on the tester's two judgement calls

### S6 — RATIFIED. Row 2.22 reads 3 of 3; the "4 of 4" count is a planner erratum.

The contradiction is real, and it is real in both documents.

In `test-spec.md`: row 2.22 asks that the four new blocks estimate the mean of
`y1` with `get_means()` on one side and `survey::svymean(~y1, ...)` on the other,
and gives the count as 4 of 4. §3.3 of the same document says the Fay block
"compares nothing", that `survey` refuses `type = "Fay"` without a `rho` before
it builds anything, and lists the block's two assertions — the refusal and
surveycore's stored scale. Neither is an estimate. A `svymean(~y1, sv, ...)` call
needs an `sv` object, and §3.3 is the statement that no `sv` can exist. The count
of four is unreachable by construction. §3.2 of the same document reinforces it:
"Fay is the fourteenth block and is not numerical", and row 2.18 sets the
stored-scale comment count at 13, which is the count that follows from Fay
asserting nothing of `survey`'s.

In `spec.md`: §IV.1's estimator sentence names Fay among the four new blocks,
which reads against §V.9's "This block compares nothing." §IV's own preamble
resolves it before §IV.1 is reached — "Blocks 1 to 8 of §V are numerical oracle
blocks. Each one satisfies every item below. Block 9 is a refusal block and
follows §V.9 instead." So the estimator sentence overreaches its own section's
scope. §V.9 governs, and the builder followed the governing rule.

**§V.9 and §3.3 agree with each other.** Both say the block compares nothing,
both name the same refusal message, and both fix the surveycore half as the
stored scale `1 / R`. The two documents the builder and the tester held
separately give the same block, which is the convergence this review exists to
check.

**Could the Fay block have carried an estimator call consistent with §V.9?** No.
The `survey` half is impossible — the constructor raises before it returns, so
there is nothing to call `svymean()` on. A one-sided `get_means(sc, y1)` call
would be possible in R, but it satisfies neither row 2.22 (which requires both
sides) nor §V.9 (which fixes the block's shape as refusal only and lists two
assertions), and it would add an unasserted estimate to a block whose whole claim
is that no comparison exists. It would also breach the one-observable-behaviour
rule in §IV.4. So there is no construction that would have made this a BLOCK.

The erratum is the planner's, it is recorded, and the count becomes literally
satisfiable only after issue #243 adds `rho`. The Fay comment already names #243
and the PR that does it.

### N3 — RATIFIED. The pre-existing BRR title does not count toward row 2.23.

The discriminator is sound. I re-read all 14 titles of the `survey`-building
blocks off the parse tree. A word filter for titles lacking "matches" returns
four: blocks 25, 26, 28 and block 8,
`get_means() BRR scale formula 1/n_rep is correct for n_rep != 4`.

Row 2.23 counts titles that claim no match **with `survey`**, and its own defect
test is "a title of the form 'X matches Y' on a block that proves a
disagreement". Block 8's title makes an affirmative claim about one side's
formula and names `survey` nowhere. The block agrees with `survey` on all five
quantities — I measured it at five `expect_equal()` calls, one
`expect_no_warning()`, one `svrepdesign()` call and zero `expect_failure()`
wrappers — so it proves agreement, not disagreement. Counting it would invert the
row's purpose.

The false positive is a property of the word filter, not of the file. The sound
discriminator is the one the tester used and N3 records: whether the block wraps
a failing comparison or asserts a refusal. Block 8 does neither. Row 2.23 reads
3 of 3 and 2 of 2. PR 8 does not touch line 309.

## The non-vacuity evidence

**Sound, and stronger than what the arc asked of earlier builders.** For an arc
about tests that pass for the wrong reason, an assertion proven able to fail is
worth more than one proven to pass, and the builder measured both halves.

| Mutation | Result | What it proves |
|---|---|---|
| fragment changed to `With type='BRR' you must supply the correct rho` | the original error propagates, the block errors | the `expect_error()` match is on the real text and not on any error |
| scale expectation changed to `1 / 20` | the assertion fails | the stored-scale assertion discriminates `R = 10` from `R = 20` |

Each mutation is the minimal one for its assertion: the first changes one token
of the matched fragment and leaves `fixed = TRUE` and the call intact, so only
the match can account for the change in outcome; the second changes the
right-hand side to the value the wrong generator mode would give, which is the
error a reader of this block is most likely to make. The `1 / 20` mutation is
the interesting one, because `R` is read from the columns rather than
hard-coded, and it is the exact confusion the spec warns about in §VII.

One limit, stated rather than held against the PR: the mutations were run in a
probe script that was deleted before the commit, so the evidence rests on
`implementation.md`'s record and cannot be re-run from the tree. That is the
arc's established pattern for probes and the figures agree with what the tree
shows statically — `1 / n_rep` with `n_rep <- length(repwt_cols)` on a `fay`
fixture, and `helper-test-data.R` mapping `fay` to `n_psu %/% 2L` — and with
gate 2 passing on this tree.

## The two builder judgements

**Neither side receives `mse` — correct.** `spec.md` §IV.2's "always, explicitly"
row sits under §IV, whose preamble excludes block 9, and §V.9 says "nothing else
supplied". Beyond the document reading, no assertion in the block could observe
`mse`: `survey` raises before it reads the argument, and the stored scale
`1 / R` does not depend on it. Passing it would have added an argument the block
cannot test and would have read against §V.9's wording.

**No separate class assertion on the returned design — correct.** `spec.md` §V.9
item 2 says the constructor "returns a design and stores `scale = 1 / R`". The
read `sc@variables$scale` cannot succeed unless the constructor returned an S7
object carrying that property, so the return is proved by the assertion that
follows. `test-spec.md` §3.3 lists two assertions and a third would exceed it,
and §IV.4 asks for one observable behaviour per block. An `S7_inherits()` line
would be a second, weaker statement of what line 1072 already proves.

## Out of scope, confirmed not this PR's defects

- PR 9's sanctioned-exceptions subsection and rows 3.5, 6.10, 6.15.
- N2, the JK2 block's untoleranced `sc@variables$scale` at line 174. Present and
  untouched; `git diff` shows 0 removed lines.
- N1, the two old BRR blocks passing `mse` to one side only.
- S4 and S5, the stored-scale comment and the pinned titles breaking the
  80-column rule. `air format --check` exits 0 on the file.

## Decision

PASS. All seven checks are clean: ten of ten audit rows pass, every whole-file
gate re-measured with an independent parse-based instrument agrees with the
tester's awk figures, no tolerance in the file is looser than its test-spec row,
the write surface is the one file the plan names, coverage holds at 96.15% with
no new `R/` line, and the two NOTEs are the two that stand on the baseline. Both
tester rulings are ratified: S6's "4 of 4" is a planner erratum that no
conforming file can meet, and N3's word filter catches a pre-existing block that
claims agreement rather than disagreement.
