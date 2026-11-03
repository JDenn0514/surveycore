# Review — PR 1 — as-svydesign-bridge

**Verdict**: PASS
**Date**: 2026-09-09 11:05

**Branch**: `fix/as-svydesign-bridge`
**HEAD**: `e45aee204814f37cd832a178a79f7c82424fdebb`
**Tree**: `424da65a0e7df17d4e9ea4d45a2a58197feb196d` — the tree the gates ran on
**Base**: `git merge-base develop HEAD` answers `40700e3`, the commit every line
citation in `spec.md` and `test-spec.md` is pinned to. `git diff 40700e3..HEAD
--stat` answers eight files, 733 insertions, 22 deletions, which is the figure
the dispatch names. Local `develop` has since moved to `dbff0d9`, so
`git diff develop..HEAD` shows 17 files; the merge-base diff is the one that
describes this PR.

**Findings**: 0 blocking, 0 integrity violations, 3 observations.

## Convergence checks

- Spec coverage: **y**
- Test coverage of spec: **y**
- Tolerance integrity: **y**
- Scope discipline: **y**
- Regression safety: **y**
- Comprehension alignment: **y**

### Step 1 — spec coverage

Every contract item in `spec.md` §Function contracts carries an `audit.md` row
or a stated reason for having none.

| Contract item | Rows |
|---|---|
| Dispatch row 4a, replicate shape to `svyrep.design` | B-1, B-2, B-5, B-9, E-4 |
| Dispatch row 4b, plain shape, CN-3 then `survey.design2` | B-3, B-4, B-6, B-10, B-11 |
| Dispatch row 5, the CN-1 refusal | E-1, E-2, E-3 |
| Warning CN-3 | B-3, B-4, C-2 |
| `as_tbl_svy()`, both shapes, warning propagates | C-1, C-2 |
| Round trip returns a probability design | D-1, D-2 |
| Dispatch rows 1, 2, 3 — unchanged by this change | pre-existing blocks; the full suite passes, +57 and no state change elsewhere |
| Error `surveycore_error_pkg_not_installed` — unchanged | pre-existing block |

Every row of the spec's §Edge cases table maps to a test row or to a written
reason in `test-spec.md` §Edge cases: zero-weight rows to B-11; the absent
`fpctype` key to B-1, B-5 and B-7; and the eleven remaining cases each carry a
reason — not constructible, no code path, or deferred to issue #245 or #248. The
degrees-of-freedom figures in the new roxygen carry no row, which
`test-spec.md` §Out of scope states with its reason: no code in this change
reads or writes a `degf` value, so a row would pin the oracle package's
arithmetic. The builder measured all four figures on the fixture and reports
them matching the section's text (`implementation.md` §Notes for tester, note
5).

### Step 2 — tolerance integrity

Verified in the test source, not from `audit.md`. All five measured rows compute
their expectation inside the block from `get_means()` on the source design, then
compare it to the oracle call on the object converted from that same design in
that same block. No row compares against a pasted literal.

| Row | Assertion in the block | Tolerance in the call | `test-spec.md` §Tolerances |
|---|---|---|---|
| B-5 | `coef(sm)[["y1"]]` against `sc$mean[[1L]]` | 1e-10 | point 1e-10 |
| B-5 | `as.numeric(survey::SE(sm))` against `sc$se[[1L]]` | 1e-8 | SE 1e-8 |
| B-6 | the same pair, plain shape | 1e-10 / 1e-8 | 1e-10 / 1e-8 |
| B-9 | `bounds[[1L]]`, `bounds[[2L]]` against `sc_ci$ci_low`, `ci_high` | 1e-6 | CI 1e-6 |
| B-10 | the same pair, plain shape | 1e-6 | CI 1e-6 |
| B-11 | mean and SE on the zero-weight fixture | 1e-10 / 1e-8 | 1e-10 / 1e-8 |

No tolerance is looser than `test-spec.md` sets, and none is tighter. Every
numeric assertion uses `expect_equal()`; class names and counts use
`expect_identical()` or `inherits()`, as §Tolerances directs.

### Step 3 — scope discipline

`git diff --name-only 40700e3..HEAD` returns exactly the eight files
`implementation-plan.md` §Files touched names, with the same actions:
`plans/error-messages.md`, `R/methods-conversion.R`,
`tests/testthat/test-conversion.R`, `tests/testthat/_snaps/conversion.md`,
`vignettes/surveycore-vs-survey.Rmd`, `changelog/fix-as-svydesign-bridge.md`
(new), `man/as_svydesign.Rd`, `man/as_tbl_svy.Rd`.

No extra file. No missing file. `NEWS.md`, `NAMESPACE`, `DESCRIPTION`,
`R/core-constructors.R`, `R/methods-print.R` and
`tests/testthat/_snaps/methods-print.md` are absent from the list, which is what
D-9 and D-10 require.

`spec.md` §Out — checked by extracting each function's text from both revisions
and comparing bytes, not by reading the diff:

| Region | Base `40700e3` against HEAD |
|---|---|
| `.as_svydesign_taylor()` | identical |
| `.as_svydesign_replicate()` | identical |
| `.as_svydesign_twophase()` | identical |
| `as_tbl_svy()`, whole function | identical |
| `from_svydesign()`, `from_tbl_svy()` | identical |
| `.from_svydesign_taylor()`, `_replicate()`, `_twophase()` | identical |
| `.find_col_by_value()` | identical |

The twophase helper is the one the new branch sits next to, and it is untouched.
The two reverse-direction `@return` lines were found by their text and their
enclosing function, never by number: exactly two lines in the file read
`@return A survey_taylor, survey_replicate, or survey_twophase object.`, they
sit above `from_svydesign()` and `from_tbl_svy()`, and both read the same at
base and at HEAD. They moved from 495 and 881 to 584 and 970 with the roxygen
this PR adds above them.

`R/methods-conversion.R` carries three hunks and no more: `@@ -30,20 +30,74 @@`
(roxygen), `@@ -79,6 +133,41 @@` (the dispatch branch) and
`@@ -345,8 +434,8 @@` (the `as_tbl_svy()` `@param x`). No body line is removed
anywhere in the file. `tests/testthat/test-conversion.R` carries two hunks: the
E-1 block extended to the dual pattern with E-2 added after it, and the append
at 2723. `tests/testthat/_snaps/conversion.md` is 19 insertions and 0 deletions,
and all eight pre-existing blocks are byte-identical.

Regression safety: `audit.md` reports +57 tests passing, WARN 256 unchanged,
SKIP 4 unchanged, and `logs/gate-2-test.log` reads
`[ FAIL 0 | WARN 256 | SKIP 4 | PASS 11595 ]`. No test outside this PR's scope
changed state.

### Step 4 — CRAN cookbook and profile gates

`audit.md` §CRAN cookbook violations reads "None". I re-scanned the added
non-roxygen lines of `R/methods-conversion.R` against all ten patterns: no hit.
The one new condition is `cli::cli_warn()` with
`class = "surveycore_warning_nonprob_srs_conversion"`, and each of its three
bullets is built with `paste0()`, one fragment per source line, as §Conditions
directs.

All seven gates carry a result and none is skipped. pkgdown ran, which the
profile requires here because `R/` and `vignettes/` both change. Read from the
logs rather than from `audit.md`:

| Gate | Log | Reading |
|---|---|---|
| document() | `gate-1-document.log` | no NAMESPACE or `man/` drift |
| test() | `gate-2-test.log` | FAIL 0, WARN 256, SKIP 4, PASS 11595 |
| run_examples() | `gate-3-examples.log` | ran |
| build | `gate-4-build.log` | tarball produced |
| check --as-cran | `gate-5-check.log` | `Status: 2 NOTEs`, 0 errors, 0 warnings |
| pkgdown | `gate-6-pkgdown.log` | `Finished building pkgdown site` |
| covr | `gate-7-covr.log` | `COVERAGE_PCT=96.24` |

The orchestrator ran the gates, not the tester. `gates-handoff.md` records the
reason — 2.06 GB free of 14.67 GB, three live worktrees, a `covr` run killed
twice, and corrupted `.Rcheck` trees from overlapping runs in the previous
pipeline run — and forbids the tester from re-running any of them. The tester
citing those results is correct here. It also ran
`devtools::test(filter = "conversion")`, which the handoff permits, and got
FAIL 0, SKIP 0, PASS 625. Zero skips shows the two `srvyr` blocks, C-1 and C-2,
ran rather than skipped.

The two notes: `checking CRAN incoming feasibility`, which
`r-package-profile.md` pre-approves, and `checking for hidden files and
directories` naming `.git`, which the Before run also carried. `.Rbuildignore`
holds `^\.github$` and no `^\.git$` entry, so `R CMD build` packs the
worktree's `.git` file. Pre-existing, outside this write surface, and this PR
cannot fix it.

### Step 5 — coverage floor

96.24%, above the 95% floor. The changed `R/` file reads 99.76%. The single
uncovered line, `R/methods-conversion.R:525`, is the `return(NULL)` early exit
of `.find_col_by_value()`; I read it, and it carries
`# nocov — callers always pass non-NULL` on the same line. That helper is
byte-identical to base and sits outside all three diff hunks. No line this PR
added is uncovered, so the STOP trigger for uncovered new code does not fire.

There is no Before figure: the low-memory watchdog killed both baseline
attempts. So the floor is judged and no delta is claimed. That is a recorded
limit in `decisions.md` §Baseline capture, not a silent gap, and
`pipeline-ship` §Step 0 holds only for a failing baseline, which this was not.

### Step 6 — comprehension alignment

Nine gotchas, G1 to G9. G1, G2, G3, G4, G8 and the FPC half of G9 all belong to
the replicate finite population correction, which `spec.md` §Out removes by D-9
and assigns to the neighbouring arc's PR 4 under row CB-3 and to issues #243
and #251. G5 and G6 are the reason the branch needs two routes, and §Why the
nonprob branch needs two routes and not one carries both; rows B-5 and B-6 test
the consequence. G7 is the round-trip loss, carried by §What the forward leg
drops, roxygen section 1, and rows D-1 and D-2.

Every assumption is either in a spec contract or deferred with a reason. The one
the spec answers rather than adopts: comprehension assumed the branch needs no
new warning class, and D-2 chose a new class, CN-3, with the reasoning in §CN-3.
The open question on `R/core-constructors.R:610-612` is deferred to issue #251
by §Out. The open question on where the degrees-of-freedom difference belongs is
settled by D-3 as roxygen section 2 plus vignette §5.1.

### Register, roxygen and documentation conventions

- `plans/error-messages.md` gains one dated subsection,
  `### as-svydesign-bridge rows (2026-09-09)`, holding rows CN-1 and CN-3 in the
  file's own six-column order, and no row CN-2. The subsection states the CN-2
  gap and its reason. One Coverage Map line, naming `test-conversion.R` against
  CN-1 and CN-3. Rows CB-1 to CB-5 are untouched.
- The three new `@section` blocks run 17, 17 and 13 lines, the figure §New
  roxygen sections states. Compared line by line against the spec's replacement
  text: 44 content lines, identical. The four replaced roxygen blocks —
  description, `@param x`, `@return`, and the `as_tbl_svy()` `@param x` — also
  match the spec's After text exactly. All three sections render in
  `man/as_svydesign.Rd`.
- No roxygen line in the diff carries an issue number. The one `#246` in the
  diff sits in a `#` source comment inside the new branch, which is where
  `spec.md` §The eighth copy asks for it.
- The eighth copy is deliberate and I raise no DRY finding. The branch writes
  `!is.null(x@variables$repweights)` inline and the CN-3 first bullet as an
  independent literal, and the source comment records both and cites issue #246.
  The debt is written where the spec says: in that comment, in `spec.md` §Out,
  and in §The eighth copy.
- The rendered snapshot text matches the CN-3 register row word for word.
- `vignettes/surveycore-vs-survey.Rmd` matches the spec's passage exactly. The
  new chunk `bridge-convert` is the file's only use of that label, carries
  `eval=has_survey` from the setup chunk at line 19, and reuses `strat_sc` from
  line 106 and `api00`.
- `changelog/fix-as-svydesign-bridge.md` exists, 145 lines, with the header plus
  Summary, Changes, Files Modified and Verification — the shape of
  `changelog/fix-svydesign-replicate-bridge.md`, which D-10 requires over
  `.claude/skills/changelog-workflow.md`. It is not a stub.

## Cross-consistency notes

Three observations. None changes the verdict, and none is a finding.

**O1 — Fixture 1's parameters differ from `test-spec.md` §Fixture 1.** The
test-spec names 40 rows at seed 7, `cal_wt` uniform on `[0.5, 2.5]`, and each
`bw_i` as `cal_wt` times a uniform draw on `[0.9, 1.1]`. `make_nonprob()` in the
test file builds the frame from `make_survey_data(n = 40, n_psu = 8,
n_strata = 2, design = "taylor", seed = 601)`, renames the lognormal `wt` to
`cal_wt`, and perturbs by `runif(0.85, 1.15)`. Every property a contract depends
on holds: 40 rows, both shapes, eight independently perturbed replicate columns
so the matrix has full column rank, `fpc` `NULL`, and no `calibration` argument.
Every numerical row computes both sides in its own block, so the draw cannot
turn a pass into a fail, and the R3 literals `test-spec.md` cites were never
assertion targets — that document names surveycore's own estimate as the oracle
for every numerical row. Using the package generator is what
`testing-standards.md` §Test data asks for. The tester recorded the seed half of
this as an observation; the distribution half is the same observation.

**O2 — the plan's replicate-column assertion is not callable as written.**
`implementation-plan.md` AC-1 and `test-spec.md` B-2 both write
`ncol(survey::weights(converted, "analysis"))`. `survey` registers a method for
the base generic `weights` and exports no function of that name, so the
namespaced call errors. The block asserts
`ncol(stats::weights(sv, "analysis"))`, which dispatches to
`weights.svyrep.design` and observes the same eight columns. A planner erratum
with an equivalent substitution; the assertion the row buys is intact.

**O3 — AC-6's note wording against the observed note set.** AC-6 reads "the two
pre-approved notes only". The run reports two notes, one pre-approved and one
pre-existing and environmental, so the criterion holds in substance — 0 errors,
0 warnings, no new note — and not in its literal wording. Already adjudicated in
`gates-handoff.md` and `decisions.md` §Baseline capture; recorded here so a
later reader does not re-open it.

## Decision

PASS. The builder and the tester converged: every one of the 18 test-spec rows
in scope is implemented as its row specifies and validated in `audit.md`, the
five measured rows compute their expectations in-block at the tolerances
`test-spec.md` sets, and the write surface is the eight files the plan names with
every function `spec.md` §Out protects byte-identical to base. All seven profile
gates pass on this tree, coverage clears the floor at 96.24% with no uncovered
line among the added ones, and `audit.md`'s verdict is PASS. The three
observations above are recorded, not raised.
