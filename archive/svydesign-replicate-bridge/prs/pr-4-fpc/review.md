# Review — PR 4 — svydesign-replicate-bridge (`fix/svydesign-replicate-fpc`)

**Verdict**: PASS
**Date**: 2026-09-08 19:40

Scope judged: `spec.md` §I.1 rows 9 and 11 — in §IV.2 terms, steps 2, 5 and 6.
Step 4, Fay's shrinkage factor, `surveycore_error_fay_rho_unrecoverable`, row
CB-4 of `plans/error-messages.md`, and every E-8/E-9/E-10 and R-row behaviour
belong to pull request 5 and are not scored here. All of `spec.md` §III, the
import route, landed in pull requests 1 to 3 and is re-checked only for
regression.

`type = "Fay"` still fails through the export route on this tree, with
`svrepdesign.default`'s own `With type='Fay' you must supply the correct rho`.
That is the state pull request 5 closes, not a defect of this one.

Tree reviewed: `b0f56dc938d7552b74206c78dcfb6485852fc250` — equals the tree
`audit.md` names, verified with `git rev-parse 'HEAD^{tree}'`. HEAD `5b27b9b`.
`git merge-base HEAD origin/develop` is `1f15d35`, and `origin/develop` sits at
that same commit, so `git diff origin/develop` is the whole pull request.

## Convergence checks

- Spec coverage: **y**. Every in-scope step is in the diff with a committed
  block and an `audit.md` row.
  - Step 2, the replicate count check, is the route's first check
    (`R/methods-conversion.R:135`), raises `surveycore_error_repweights_empty`
    with the §V.6 export-route message, and has block X-7 (class assertion,
    message match, snapshot).
  - Step 5, the FPC drop warning, sits before the `survey::svrepdesign()` call,
    fires once per call, names the column, and has X-1 (class + snapshot), X-2
    (parity), X-4 (six types plus JKn), X-5 (the silent branch), X-6 (not
    destructive, and warns again on a second call).
  - Step 6, the call without `fpc` and without `fpctype`, is in the diff as a
    deletion, and the local `fpctype` value is gone.
  - §IV.4 and §VI property 7 have X-6; §IV.6's per-type rows have X-4 and X-5;
    §VI property 2 has X-2 (with an FPC) and X-3 (without).
  - `plans/error-messages.md` carries row CB-3 and the row 16 trigger note.
- Test coverage of spec: **y**. `test-spec.md` gives this pull request E-1 to
  E-7, C-6, C-7, C-15 and C-16, and each has a committed block: E-1 to X-5, E-2
  to X-3, E-3 to X-1 and X-2, E-4 and E-5 to X-4, E-6 and E-7 to X-6, C-6 and
  C-7 to X-1, C-15 and C-16 to X-7. Row IDs are not in the committed blocks
  (D11), so I judged the behaviour each in-scope row describes, not the block
  names. One assertion is thinner than its row asks — see Cross-consistency
  note 1.
- Tolerance integrity: **y**. See below.
- Scope discipline: **y**. See below.
- Regression safety: **y**. `FAIL 0` before and after, `WARN 256` before and
  after (D12's reading), `SKIP 4` before and after, `PASS 11366 → 11430`. The
  test file diff is 208 insertions and 0 deletions, so no block from pull
  request 1, 2 or 3 was edited; the snapshot diff is 21 insertions and 0
  deletions, so the four earlier snapshots are byte-identical and unreformatted
  and their line endings did not move. No test outside this pull request's
  scope changed state, and the 7 new `skip_if_not_installed("survey")` calls
  are block-level placement per `testing-standards.md`, not a route to a pass —
  the skip count did not move.
- Comprehension alignment: **y**. The one gotcha this pull request owns is F2,
  the two FPC shapes: `svrepdesign.default` stops for `"BRR"`, `"Fay"`,
  `"JK2"`, `"ACS"` and `"successive-difference"`, stops for `"bootstrap"`, and
  otherwise checks `length(fpc)` against `length(rscales)`. X-4 converts six of
  those types with an FPC recorded and lets no bare `survey` stop reach the
  caller. The assumption "the FPC must be dropped rather than translated, since
  surveycore would ignore it but the exported survey design would not"
  (§Assumptions, third bullet) is the behaviour X-1's `rscales` assertion
  measures.
- `audit.md` verdict: PASS.

## Tolerance integrity

No row is looser than `test-spec.md` §4, and none is looser than
`.claude/rules/testing-surveycore.md`.

| Row | `test-spec.md` §4 | `audit.md` | Committed test |
|---|---|---|---|
| E-2 point | 1e-10 | 1e-10 | `tolerance = 1e-10` |
| E-2 SE | 1e-8 | 1e-8 | `tolerance = 1e-8` |
| E-3 point | 1e-10 | 1e-10 | `tolerance = 1e-10` |
| E-3 SE | 1e-8 | 1e-8 | `tolerance = 1e-8` |
| E-6 | structural | `expect_identical` | `expect_identical` |
| E-1, E-4, E-5, E-7, C-6, C-7, C-15, C-16 | none — class, snapshot or structural | `—` | class, snapshot, `expect_identical` |

The measured differences the audit reports — point 0, SE -2.55e-15 — sit seven
orders inside the SE tolerance. X-1's extra
`expect_equal(sv$rscales, rep(1, length(d@variables$repweights)))` carries
`expect_equal()`'s default tolerance; it is an addition, not a relaxation of a
specified one.

## The drop is a drop, not a reshape

This was the finding worth looking hardest for, because a reshape to length `R`
would give the right shape and the wrong quantity (`spec.md` §IV.1, §IV.5), and
would make the exported design return standard errors surveycore does not
produce.

- The diff removes `fpc = if (!is.null(fpc_var)) x@data[[fpc_var]] else NULL,`
  and `fpctype = fpctype,` from the call and adds nothing in their place. No
  `length()`, no `rep()`, no subsetting, and no arithmetic on the FPC column
  anywhere in the route.
- The FPC column is read exactly once, as a name: `fpc_var <-
  x@variables$fpc`, used only in `is.null(fpc_var)` and in the message.
- X-1 asserts `sv$rscales` equals `rep(1, R)`. This is the assertion a reshape
  would fail: `svrepdesign.default` computes `rscales <- rscales * (1 - fpc)`
  under the default `fpctype = "fraction"`, so a translated FPC would move
  every replicate scale off 1.
- Gate 10 checked inside `.as_svydesign_replicate()` specifically, not by loose
  grep. The other `fpc` arguments in `R/methods-conversion.R` are the Taylor
  export route (line 122), the two-phase export route (258), the Taylor import
  route (505), the replicate import route's `@variables` list (734–735 —
  `fpc = NULL, fpctype = "fraction"`, which `spec.md` §III.3 requires) and the
  two-phase import route (787). None is inside the `survey::svrepdesign()`
  call, and the import route's pair is untouched by this diff.
- `R/variance-replicate.R` still holds no reference to the FPC
  (`grep -n "fpc"` returns nothing), so §IV.5's premise holds on this tree.

## The FPC survives on the surveycore design

X-6 captures `d@data` and `d@variables` before the warned call and asserts both
`expect_identical()` afterwards, then asserts `@variables$fpc` is `"fpc"`,
`@variables$fpctype` is `"fraction"`, and `"fpc" %in% names(d@data)`, then
calls again and asserts the second warning. The route writes nothing: it reads
three `@variables` keys and returns `survey::svrepdesign()`'s value. §VI
property 7 holds.

## Step order and the seam pull request 5 needs

`spec.md` §IV.2 puts step 4 between step 3 and step 5, and the code leaves that
seam open. Reading the route: the step 2 guard, then `scale_arg` (step 3), then
a blank line, then the step 5 comment block and the `if (!is.null(fpc_var))`
warning, then the call. Steps 3 and 5 are not fused, nothing between them reads
`@variables$scale`, and pull request 5 can insert the `rho` recovery and its
condition at the blank line without moving either. A file-level write-surface
check cannot see this, so I read the region.

## The warning-muffling technique

Measured on this tree rather than read, with one `Rscript` call each.

| Claim | Measurement |
|---|---|
| The typed condition's class chain never includes `simpleWarning` | `surveycore_warning_replicate_fpc_dropped, rlang_warning, warning, condition` |
| The narrow muffle cannot hide the typed condition | `suppressWarnings(as_svydesign(d), classes = "simpleWarning")` under a `surveycore_warning_replicate_fpc_dropped` calling handler: the handler fires |
| `survey` emits its own `simpleWarning` independently, and only for the three types the builder named | `JK2`, `ACS` and `successive-difference` each emit `with type ... scale= and rscales= are not needed and will be ignored`; `JK1`, `BRR` and `bootstrap` emit none |

The technique is `suppressWarnings(..., classes =)` inside
`expect_warning(class =)`. `.claude/rules/testing-standards.md` forbids
`tryCatch()` and `withCallingHandlers()` in tests; neither appears in any block
this pull request adds. The muffle is scoped by class to a base-R condition
that the typed condition cannot be, and it addresses noise from step 3, which
this pull request does not change. Not a finding.

## Message correctness

`tests/testthat/_snaps/conversion.md` holds exactly six blocks: pull request
3's four (subbootstrap, zero-row, partly named, one generated name), plus the
FPC-drop warning and the repweights-empty error. Both new messages match
`spec.md` §V.3 and §V.6's export-route block bullet for bullet, including
`{.cls survey_replicate}` rendering as `<survey_replicate>` and
`{.field {fpc_var}}` naming the dropped column. The code's `paste0()` line
breaks differ from the spec's wrapping; the concatenated strings do not. Both
`"v"` bullets are imperative and address no one — "Call
`survey::svrepdesign()` directly with `fpc` ..." and "Rebuild the design with
`as_survey_replicate()` ..." — so `code-style.md`'s bar on second person holds.

## Coverage

- Package: 96.23%, against a 96.19% baseline. Above the 95% floor, and up, not
  down.
- `R/methods-conversion.R`: 99.72%, one uncovered line. I confirmed the line
  independently without running `covr`: line 364 is the `return(NULL)` early
  exit in `.find_col_by_value()`, which is line 305 on `origin/develop`,
  shifted by 59 lines — this pull request's net insertion above it. It sits
  outside the diff ranges, which are 135–158, 169–209 and the deletion at 216.
  The trailing `# nocov` on line 365 is not a covr directive, which is why the
  line still counts as uncovered; it is pre-existing text, unchanged here.
- No `# nocov` was added: `git diff origin/develop | grep "^[+-].*nocov"`
  returns nothing.
- Every executable line this pull request adds is reached. There are four: the
  `length(rep_vars) == 0L` test and its `cli_abort()` (X-7), and the
  `!is.null(fpc_var)` test and its `cli_warn()` (X-1 through X-6, both
  branches). The count fell from 2 uncovered to 1 because the deleted
  `fpctype` if/else held the other.

## `plans/error-messages.md` discipline

- Row order reads CB-1, CB-2, CB-3, CB-5. CB-4 is absent, as pull request 5's
  scope requires.
- The pending note is narrowed from "Rows CB-3 and CB-4" to "Row CB-4 is the
  remaining export-route condition", and now says the numbering skips CB-3 to
  CB-5.
- Row 16's own table row is untouched; the extension is one bullet appended
  under the dated section, as `spec.md` §V.7 writes it. The file's three diff
  hunks all fall inside the dated section.
- Row CB-3's content is verbatim from `spec.md` §V.7 line 959. I diffed the two
  lines: the only difference is the absent trailing pipe. The row keeps its
  leading pipe and five internal pipes, so it presents six cells against a
  six-column header and GFM renders it identically to a padded row; the
  template cell contains no pipe that could shift a boundary. Cosmetic,
  confirmed, and D18 puts the fix in pull request 5 at no extra cost. Not
  scored.
- CB-2's template now reads `{cli::qty(n_collisions)}` at both occurrences.
  D17 settles this: the bare form throws an untyped `rlib_error_3_0` before the
  typed condition exists, so the spec text is the erratum and the namespaced
  form is both correct and the house rule. The row now matches the shipped
  code, and nothing else in it changed.

## Scope discipline

`implementation.md` §Write surface names four files.
`implementation-plan.md` PR 4 §Files touched names the same four.
`git diff --name-only origin/develop` lists the same four: no extras, none
missing.

| File | Insert/delete |
|---|---|
| `R/methods-conversion.R` | 65 / 6 |
| `plans/error-messages.md` | 7 / 4 |
| `tests/testthat/_snaps/conversion.md` | 21 / 0 |
| `tests/testthat/test-conversion.R` | 208 / 0 |

`man/`, `NAMESPACE` and `NEWS.md` are absent (gates 7 and 8). No change to
`R/core-classes.R`, `R/core-constructors.R` or `R/variance-replicate.R` (gate
11). No Fay code: the diff adds exactly two `class =` arguments,
`surveycore_error_repweights_empty` and
`surveycore_warning_replicate_fpc_dropped`, and no `rho` argument, no
`surveycore_error_fay_rho_unrecoverable`, and no import-route change. The two
"Fay" strings in the diff are one unchanged context line and one comment
saying Fay is out of scope. Exactly one new `test_invariants()` call, at
`test-conversion.R:2138` in X-1, for `as_survey_replicate()`; the
`from_svydesign()` call at 1157 is untouched; X-7 carries none. (The two
`as_survey()` calls at 121 and 754 predate this run.)

## Process departures recorded

- **The gates were run by the orchestrator, not the tester** (D12, D16), and
  the tester was told to run none. `tester.md` Step 1 says otherwise. Six
  background gate runs have been killed for low memory across this run, and the
  reported numbers come from foreground runs on tree `b0f56dc`, with gates 4 to
  7 rerun individually after a mid-suite kill. `audit.md` §Profile gates states
  this in its own header. Recorded as a departure from `tester.md`, not scored
  against this pull request: every gate has a result, and the tree the gates ran
  on is the tree I reviewed.
- **Gate 2 reads as "no new warning"** (D12): 256 before, 256 after.
- **Gate 9 reads as "the pull request's own files pass `air format --check`"**
  (D16): `air` is a CLI here, and the builder reports exit 0 for its two
  source files.
- **Row IDs stripped from the builder's task list** (D11): the committed blocks
  are X-1 to X-7, the builder's own names, and I judged behaviour.
- I ran no gate suite, no `R CMD check`, no `pkgdown`, no `covr` and no
  `devtools::test()`. Everything I measured came from single `Rscript` calls and
  git reads.

## Cross-consistency notes

1. **Rows E-4 and E-5 ship without their parity assertion.** `test-spec.md` §7
   writes both as "same three assertions as E-3", the third being point parity
   at 1e-10 and SE parity at 1e-8 against `get_means(d, y1)`, and
   `implementation-plan.md` PR 4's acceptance criteria repeat that for E-2 to
   E-5. Block X-4 asserts the typed warning, a returned `svyrep.design` and a
   row-count match for six types plus JKn, and no parity. `audit.md` reports
   those rows honestly — the Tolerance column reads `—` for both — so this is a
   thinner assertion set, not a misreported one, and no tolerance was loosened.

   I measured what the missing assertions would have said, on this tree, with
   the shipped fixture:

   | Type | Point diff | SE diff |
   |---|---|---|
   | `bootstrap` | 0 | -6.52e-16 |
   | `JKn` (with `rscales`) | 0 | -1.30e-15 |

   Both sit inside 1e-10 and 1e-8, so the omission hides nothing. It also
   discriminates nothing: the drop happens before the call and does not branch
   on the type, so per-type parity adds no signal over X-2 (with an FPC) and
   X-3 (without), which do assert it. Not a BLOCK — a BLOCK would re-dispatch
   the builder to add two `expect_equal()` lines whose values are already
   measured as passing, void an audit measured on this tree, and cost a full
   gate re-run on a machine that has already lost six of them.

   Worth carrying to the calibration ledger: X-4 is the block where a parity
   assertion is cheap, and `JK2` is the type where one would **fail** — SE
   0.2448 against surveycore's 0.2189, because `svrepdesign()` ignores `scale`
   and `rscales` for `JK2`, `ACS` and `successive-difference`. `test-spec.md`
   asks for parity on `bootstrap` and `JKn` only, so the test-spec is right and
   the shipped block is merely quieter. That `JK2` divergence is a property of
   step 3, which this pull request does not touch, and no row in `test-spec.md`
   claims otherwise.

2. **`set.seed(407L)` in X-7 is not a cookbook hit.** The
   `r-package-profile.md` pattern is scoped to `R/`, not to tests, and the seed
   makes the block's inline data frame reproducible. `audit.md` reports "None"
   for cookbook violations and its verdict is PASS, which is consistent; I
   re-read the four added executable lines in `R/` against every pattern in the
   table and found no hit either.

3. **`implementation.md` and `audit.md` agree on every number I can check
   without running a gate**: the four-file write surface,
   `FAIL 0 | WARN 256 | SKIP 4 | PASS 11430`, two snapshots added, 21
   insertions and 0 deletions in the snapshot file, one new `test_invariants()`
   call, and the CB row order. The builder names X-1 to X-7 and the tester
   scores E- and C- rows; the mapping is one-to-many in two places (X-1 carries
   E-3, C-6 and C-7; X-4 carries E-4 and E-5) and is complete either way.

## Decision

PASS. All seven checks are clean: no spec or test-spec gap for the behaviour
this pull request carries, no tolerance loosened, the write surface matching the
plan exactly, no cookbook violation, every profile gate with a result and a
recorded reading for the two whose stated form is already false on `develop`,
coverage above the floor and up with every added line reached, and `audit.md`
at PASS. The FPC is dropped rather than reshaped — I verified that from the
diff, from the surviving `fpc` arguments elsewhere in the file, and from X-1's
`rscales` assertion, which is the assertion a reshape would fail. The seam pull
request 5 needs is open between steps 3 and 5. The two observations above are
recorded, neither blocks.
