# implementation.md — PR 6, `test/replicate-oracle-bootstrap`

Spec section: `spec.md` §V.5 (bootstrap), shaped by §IV.3 "The pinned blocks",
§IV.1, §IV.2, §II.

## Write surface

| File | Action |
|---|---|
| `tests/testthat/test-variance-replicate.R` | Modified — 81 lines added, 0 removed |

No other file changed. Nothing under `R/`. No roxygen changed, so
`devtools::document()` was not needed and was not run.

## Base

- Worktree came up on stale `main` at `d4d1db2fe2de42243213d30c5bb56639906494b4`.
- Reset to `bbafed090cb93a63915dd5704d1f361228e2032d` and verified.
- The reset discarded one file: a whitespace-only reformat of
  `.claude/settings.local.json` (84 insertions, 91 deletions, all re-indentation
  of the same keys). Harness noise, not work from this arc.
- Branch `test/replicate-oracle-bootstrap` cut from that sha.

## Summary

- Added one block, `get_means() bootstrap SE disagrees with survey::svymean()
  — issue #253`, immediately after the JKn block and under the existing
  `# Block 24:` header. No new header, no renumbering, no edit to the JKn block.
- The block builds both sides from the same fixture — `make_survey_data(n = 200,
  n_psu = 20, n_strata = 4, design = "replicate", type = "bootstrap",
  seed = 15)` — passing `mse = TRUE` explicitly to each side and passing no
  `scale`, no `rscales` and no `bootstrap.average`. The replicate count is read
  off the selected column names, never hard-coded.
- The two sides disagree on the standard error by the known scale factor, so
  the standard error, the lower bound and the upper bound each sit in their own
  `testthat::expect_failure()` wrapper. The point estimate, the stored-scale
  assertion, the design call and its no-warning assertion, and the ratio
  assertion all sit outside every wrapper.
- One unwrapped ratio assertion pins the failure to the known defect: it
  compares the two standard errors against the literal `sqrt((R - 1) / R)` at
  tolerance `1e-8`.
- The block comment names issue #253 and states that four lines get deleted
  when it lands — the three wrapper lines and the ratio assertion.

## The probe, to full precision

Measured on this worktree. R 4.6.1, `survey` 4.5, `options(digits = 17)`.

| Quantity | Value |
|---|---|
| Replicate count `R` read off the fixture | `20` |
| Warnings raised by `survey::svrepdesign()` | none |
| `sv$scale` | `0.052631578947368418` |
| `1 / (R - 1)` at `R = 20` | `0.052631578947368418` |
| surveycore stored scale | `0.050000000000000003` |
| surveycore point estimate | `50.436542684160358` |
| `survey` point estimate | `50.436542684160358` |
| surveycore standard error | `0.055102628456081222` |
| `survey` standard error | `0.056534103938925245` |
| Ratio, surveycore over `survey` | `0.97467943448099092` |
| `sqrt((R - 1) / R)` = `sqrt(19 / 20)` | `0.97467943448089633` |
| Ratio minus `sqrt(19 / 20)` | `9.4591001698063337e-14` |
| surveycore confidence bounds | `50.328543516932946`, `50.54454185138777` |
| `survey` confidence bounds | `50.325737876541822`, `50.547347491778893` |

Every figure agrees with §V.5 and §IV.3. The spec gives the surveycore standard
error as `0.0551026284560812`, the `survey` standard error as
`0.0565341039389252` and the ratio as `0.974679434480991` against
`sqrt(19/20) = 0.974679434480896`; all four match to the digits the spec
prints. The ratio's residual, `9.46e-14`, is about five orders of magnitude
inside the `1e-8` standard-error tolerance, so the ratio assertion passes today.
Nothing moved, so no block was adjusted to a moved number.

The gap on the standard error is `1.43e-3` in absolute terms, about five orders
of magnitude above the `1e-8` tolerance, so all three wrapped assertions fail
reliably and each wrapper passes.

## The two pinned blocks, side by side

Both measured on the committed file with `utils::getParseData()`, so a construct
named in a comment is never counted.

| Shape property (criteria 2 to 6) | JKn block, lines 806–884 | bootstrap block, lines 886–965 |
|---|---|---|
| `testthat::expect_failure()` wrappers | 3 | 3 |
| Assertions inside each wrapper | 1, 1, 1 | 1, 1, 1 |
| Point-estimate assertion outside every wrapper | yes | yes |
| Design call and its condition assertion outside every wrapper | yes — `expect_no_warning(sv <- survey::svrepdesign(...))` | yes — `expect_no_warning(sv <- survey::svrepdesign(...))` |
| Unwrapped ratio assertions against `sqrt((R - 1) / R)` at `1e-8` | 1, outside every wrapper | 1, outside every wrapper |
| Comment names issue #253 and says four lines get deleted | yes | yes |

`R` is read from the selected column names in both blocks — `n_rep <-
length(repwt_cols)` — and appears in the ratio literal as
`sqrt((n_rep - 1) / n_rep)`. Neither block hard-codes `20`.

The two blocks differ only where §V.4 and §V.5 say they differ: JKn passes
`rscales = rep(1, n_rep)` to both sides and pins `sv$scale` against `1`;
bootstrap passes no `rscales` and pins `sv$scale` against `1 / (n_rep - 1)`.

### The counting instrument

`utils::getParseData()` on the parsed file, counting `SYMBOL_FUNCTION_CALL`
tokens, with block extents taken from the top-level `srcref`s. Wrapper contents
and ratio nesting were checked by walking the abstract syntax tree, not by text.
Textual counting disagrees with parsing on this file, because the file discusses
its own constructs in comments:

| Construct | `grep -c` over the whole file | Parsed calls |
|---|---|---|
| `expect_failure` | 12 | 6 |
| `svrepdesign(` | 14 | 12 |

### The stored-scale comment

Exact-match count of the 99-character comment, by `grep -F`:

| Point | Count |
|---|---|
| Base `bbafed0` | 11 |
| After this PR | 12 |

That leaves PR 7 to reach the 13 it expects. The string was copied character
for character and was not shortened or rewrapped, even though `air` leaves it
over the 80-column limit — decision S4.

## Task checklist

- [x] 1. Probed bootstrap at seed 15 with no `scale` and no `rscales`. The call
  raises no warning and `sv$scale` reads `1 / (R - 1)` at `R = 20`.
  `bootstrap.average` was not passed.
- [x] 2. Probed the gap. Every figure matches §V.5 to the digits it prints; the
  ratio sits `9.46e-14` from `sqrt(19/20)`. No stop-and-report condition arose.
- [x] 3. Wrote the block under the existing `# Block 24:` header, after the JKn
  block. No new header, no renumbering.
- [x] 4. Gave it the JKn block's shape: bare point estimate, bare stored scale
  with its comment, bare ratio, three wrappers of one assertion each, design
  call and no-warning assertion outside every wrapper.
- [x] 5. The comment names issue #253 and says FOUR lines get deleted, naming
  the three wrappers and the ratio assertion.
- [x] 6. The title names the disagreement, names issue #253, and claims no
  match — it reads "disagrees with", not "matches".
- [x] 7. `NOT_CRAN=true Rscript -e 'testthat::test_local(filter =
  "variance-replicate")'` — `FAIL 0 | WARN 1 | SKIP 0 | PASS 157`.
- [x] 8. Counted across both pinned blocks by parsing. Three and three
  wrappers, one and one ratio assertions, both ratio assertions outside every
  wrapper.
- [x] 9. `air format --check` passes on the file; `git diff --name-only
  bbafed0` lists one file.
- [x] 10. No full suite, no `check()`, no `document()`, no `run_examples()`, no
  `pkgdown`, no `covr`.

## Verification run

```
$ NOT_CRAN=true Rscript -e 'testthat::test_local(filter = "variance-replicate")'
[ FAIL 0 | WARN 1 | SKIP 0 | PASS 157 ]
```

The one warning is pre-existing and is not from this PR's block. It fires at
`test-variance-replicate.R:798:3`, in the `get_corr()` domain block that PR 6
did not touch: the AAPOR small-cell warning, one of the 256 the arc's earlier
decisions record on clean `develop`.

```
$ air format --check tests/testthat/test-variance-replicate.R
(no output, exit 0)

$ git diff --name-only bbafed0
tests/testthat/test-variance-replicate.R

$ git diff --stat bbafed0
 tests/testthat/test-variance-replicate.R | 81 ++++++++++++++++++++++++++++++++
 1 file changed, 81 insertions(+)
```

The diff removes no line, so the JKn block and the other 23 blocks are
byte-identical to the base.

## Formatting note

The block was first written with the title on its own line, because
`test_that("get_means() bootstrap SE disagrees with survey::svymean() — issue
#253", {` runs to 85 characters. `air` rejected that shape and collapsed it back
to the one-line `test_that("...", {` form, which cannot be broken further
because the overflow lives inside a string literal. The shipped block therefore
carries the JKn block's exact one-line opening and the same two-space body
indentation. `air format --check` passes.

## Compliance self-check

Only a test file changed, so most of the CRAN list does not apply. What does:

- `TRUE` written out, never `T` — the block passes `mse = TRUE`.
- `::` on every external call: `survey::svrepdesign()`, `survey::svymean()`,
  `survey::SE()`, `testthat::expect_failure()`.
- No bare `print()` or `cat()`.
- No randomness beyond `make_survey_data(seed = 15)`, which takes its seed as a
  literal.
- No `par()`, no `options()`, no file written, no parallel worker.
- `skip_if_not_installed("survey")` sits inside the block, per
  `.claude/rules/testing-standards.md`.
- No `test_invariants()` call added. §IV.4 fixes the file's single call on the
  first BRR block, which is PR 1's surface, not this PR's.

## HOLDs

None. The spec fixed every number this block asserts, and every one of them
reproduced.

## Notes for tester

- The block's three wrappers pass only while surveycore's bootstrap scale stays
  at `1/R`. When issue #253 lands they all fail at once, together with the ratio
  assertion — four lines, as the comment says.
- `survey` 4.5 under R 4.6.1 produced every figure above. A later `survey`
  release that changes the bootstrap default turns the stored-scale assertion
  red first; that is what the 99-character comment warns about.
- `grep -c` over this file over-counts every construct the block comments
  discuss. Parse it.
