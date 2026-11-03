# Review — PR 4 — replicate-scale-nonprob-divergence

**Verdict**: PASS
**Date**: 2026-09-29
**Branch**: `fix/replicate-scale-nonprob-divergence`, HEAD `703e036`
**Base**: `origin/develop` at `5e7a7f9`
**Scope**: test-spec §2 row 2.3, §3 rows 3.1 and 3.2, §4 row 4.2

I ran no gate. I read the diff, and I took one targeted `load_all()`
measurement to settle frame B on my own instrument. Everything else in this
document is read off the artifacts and the diff.

---

## Convergence checks

### Spec coverage — the four rows PR 4 owns

| Spec item | test-spec row | audit row | Present in the diff |
|---|---|---|---|
| §Edge cases E1, `Inf` branch | 2.3 frame A | rows 1-8 | `test-variance-replicate.R` block "a moving estimate gives an infinite SE" |
| §Edge cases E1, `NaN` branch | 2.3 frame B | rows 9-15 | block "an equal estimate gives a NaN SE" |
| §Quality gates 4 | 2.3 both frames | rows 3-7, 10-14 | stored `Inf`, SE and both bounds, each side |
| §Quality gates 5 | 3.1 | rows 17-20 | block "as_survey_nonprob() matches as_survey_replicate() on JKn" |
| §Quality gates 6, stored half | 3.2 | rows 21-24 | block "as_survey_nonprob() keeps 1/R where as_survey_replicate() moved" |
| §Quality gates 8 / §`as_survey_nonprob()` roxygen, D1's four elements | 4.2 | rows 25-31 | `R/core-constructors.R:1357-1363`, `man/as_survey_nonprob.Rd` |
| §Test-file write surface, invariants rule | §Invariants | row 32 | no new call |

No spec item in PR 4's scope is missing a test-spec scenario, and no
test-spec row in PR 4's scope is missing an audit row. The four rows the
plan assigns PR 4 all land, and PR 4 claims no row that belongs to another
PR.

### Scope discipline

Plan PR 4 §Files touched names four files. The diff touches four files and
the same four.

| File | Plan | Diff |
|---|---|---|
| `R/core-constructors.R` | yes | +7 / -1, roxygen only |
| `man/as_survey_nonprob.Rd` | yes | +7 / -1, regenerated |
| `tests/testthat/test-variance-replicate.R` | yes | +146 |
| `tests/testthat/test-constructors.R` | yes | +105 |

`git diff --name-status origin/develop..HEAD` returns those four and nothing
else. No file created, none deleted, nothing under `tests/testthat/_snaps/`.
Total +265 / -2, which matches the orchestrator's figure.

I confirmed independently that neither switch line moved. The `R/` diff is
one hunk inside the `as_survey_nonprob()` `@details` paragraph. `JKn = 1,` at
`:851` and `bootstrap = 1 / (n_rep - 1L),` at `:861` — E-5's corrected
positions — appear nowhere in it.

No regression outside PR 4's scope. `FAIL 0` on both sides, `WARN 256` on
both, `SKIP 4` on both, `R CMD check` 2 NOTEs on both.

### Tolerance integrity

| Audit row | Reported | test-spec asks | Verdict |
|---|---|---|---|
| 3.1 two stored scales | `1e-8` | SE row, `1e-8` | equal |
| 3.1 mean | `1e-10` | `1e-10` | equal |
| 3.1 SE | `1e-8` | `1e-8` | equal |
| 3.2 two stored scales | `1e-8` | SE row, `1e-8` | equal |
| 3.2 SE ratio | `1e-8` | SE row, `1e-8` | equal |
| 3.2 mean | `1e-10` | not asked | extra, tighter class |
| 2.3 frame B premise | `tolerance = 0` | `tolerance = 0` | equal, and the tightest available |
| 2.3 remainder | exact predicates | §Tolerances "exact, untolerated" | equal |

No row is looser than the test-spec. Every explicit `tolerance =` in the
diff is written where the row's assert column names it, which is the rule
E-5 settled. The one addition — row 3.2's point-estimate equality at `1e-10`
— is extra coverage in the tightest band and weakens nothing.

---

## Cross-consistency — `implementation.md` against `audit.md`

The two documents were written without sight of each other. They agree on
every load-bearing number, and I reproduced the ones that matter.

| Claim | `implementation.md` | `audit.md` | My check |
|---|---|---|---|
| suite before / after | 12065 / 12100, +35 | 12065 / 12100, +35 | agree |
| what the +35 is | "the exact expectation count of the four new blocks" | 27 + 8, broken down 17 `expect_true`, 6 `expect_no_condition`, 2 `expect_no_warning`, 1 `expect_gt`, 1 `expect_equal`, plus 4 + 4 | I counted the diff by hand and reproduced every one of those five figures and the 4 + 4 |
| `survey` raises nothing on either frame | measured, `survey` 4.5 / R 4.6.1 | same, attributed to the orchestrator | `expect_no_warning()` is in the diff twice and the suite is green |
| `scale` reaches `survey` nowhere | "the only `scale` argument anywhere in them is `scale = 1` on the surveycore premise design" | oracle part 2: neither oracle design carries a `scale` | confirmed in the diff; both `svrepdesign()` calls take `weights`, `repweights`, `type`, `mse`, `data` only |
| frame B needs whole-valued data | first attempt drifted; premise read `1.78e-15`; product was `Inf` and `survey` said `NaN`, so the sides disagreed | integer-bound argument plus the in-suite premise | I reproduced the drift at `1.776357e-15` on a `runif` frame, and the `Inf` outcome it produces |
| cross-constructor numbers | `1 / 19` vs `1 / 20`, ratio `0.9746794`, fall 2.532% | rows 21-24 | the two literals are in the diff; `sqrt(19/20) = 0.9746794` |
| `test_invariants()` | 4 and 1, counted with `getParseData()` | 4 and 1, diff adds none | `getParseData()` gives 4 and 1; the diff adds zero |
| 4.2 rendered page | four elements, figure renders 2.5% | five rows, plus "no 2.6% on the page" | read the `.Rd` diff: all four elements, `sqrt((R - 1)/R)`, "a fall of 2.5% at `R = 20`", Wu (2022) / Chen et al. (2021) intact |

Two asymmetries, neither a contradiction.

1. **`audit.md` reports no mutation check.** `implementation.md` records two,
   both against `:861` and neither against `:851`, with per-assertion red
   counts. The audit's equivalent evidence is the per-test table plus the
   `+35` accounting, which I reproduced. The builder's use of `:861` rather
   than the plan's stale `:813` is E-5 honoured in practice, and it is worth
   noting that the mutation check is the only place in this PR where a wrong
   line number would have produced a silent false negative.
2. **`implementation.md` does not flag the row 2.3 fixture divergence.** It
   could not: the builder may not read `test-spec.md`, and plan AC-1 and AC-2
   never transcribe the prescribed values. See the ruling below.

Numeric discrepancies I found, both cosmetic: the two documents bracket the
inserted `test-constructors.R` block as lines 1010-1114 and 1007-1112 against
an actual 1008-1112; and the builder's cross-reference comments cite `:1001`
and `:2484` where E-8 asked for `:1002` and `:2482`. On the base tree line
1001 is exactly `expect_equal(stored("JKn"), 1)` and line 2483 is the
`test_that(` line of the nonprob default-scale block, so the builder's
citations are at least as accurate as E-8's own. E-8's substantive
requirement was that the cross-reference name **both** overlapping blocks,
and block 3.2's comment names both — the nine-type table by position and the
nonprob block by title.

---

## Ruling — F1, the row 2.3 fixture substitution

**Acceptable as built. Row 2.3 does not have to use the prescribed
four-row literals.** Three grounds, and a correction to where the divergence
comes from.

**1. The exactness is structural over the sampling ranges, not accidental to
the seed.** The test-spec attaches a reason to its literals: exact
representability on frame B and non-proportionality on frame A. Frame B draws
`y1` from `2:30` and `wt` from `1:9` at `n = 40`. Every product is at most
270 and every partial sum at most 10,800, so *every possible draw* from those
two ranges keeps both the numerator and the denominator an exact integer,
eleven orders of magnitude inside `2^53`. The property therefore does not
depend on `set.seed(7)`, and it does not depend on R's RNG — a future change
to `sample()` moves the values and cannot move the exactness. A four-row
literal is more legible; it is not more exact.

**2. The `NaN` assertion is self-proving, so the block cannot silently test
the wrong branch.** This is the decisive point against the risk named in the
dispatch. `Inf * x` is `Inf` for every non-zero finite `x` and `NaN` only at
exactly zero. So a frame B that drifted one ulp off zero turns
`expect_true(is.nan(sc_mean$se))` **red**, not green. The two blocks assert
different predicates — `is.infinite` in one, `is.nan` in the other — and a
broken frame B fails rather than duplicating frame A. The premise at
`tolerance = 0` turns red first and names the cause, which is the ordering
the test-spec asked for and got.

**3. No assertion of the row is weakened.** Both premises are present in the
exact form the row prescribes: `expect_equal(m_one$se, 0, tolerance = 0)` on
frame B, `is.finite()` plus `expect_gt(..., 0)` on frame A. Frame A's
replicate column is an independent `runif` draw and not a multiple of the
weight column, so the proportionality trap the row warns about is avoided by
construction and the premise proves it. §Datasets asks row 2.3 for inline
data frames, and both frames are inline `data.frame()` calls; only the values
differ.

**The divergence is the plan's and not the builder's.** Plan PR 4 tasks 3-4
and AC-1 and AC-2 describe "a block on frame A" and "a block on frame B" by
their premise-then-conclusion structure and never transcribe `c(1, 2, 3, 4)`,
`c(1, 1, 2, 2)` or `c(5, 1, 2, 2)`. The builder is forbidden to read
`test-spec.md`. So the prescribed fixture lived in only one artifact, and the
one the builder may not open — the same shape as E-1, E-4 and E-6 in this
arc, and as D23 in `archive/domain-marker-logical/`. The builder built
precisely what it was authorised to build. This is the sixth instance of the
pattern in this arc and it belongs in the retrospective, recorded below as
E-9. It is not a reason to re-implement a block whose behaviour I have
measured and whose every assertion passes.

Contrast with E-7, which the dispatch raises as the cautionary case. There
the substitution was forced: a one-row frame is refused by
`.validate_data()`, so the prescribed fixture could not be built at all and
the criterion asked for an impossible construction. Here the prescribed
fixture is buildable and the substituted one holds the same property for a
reason that can be stated and was measured. The two cases differ in kind.

## Independent verdict — frame B's exactly-zero deviation

**The tester's argument is correct, and the block tests the `NaN` branch.**
Measured first-hand under `load_all()` on this tree, `survey` 4.5 / R 4.6.1:

| Observable | Measured |
|---|---|
| `identical(d$repwt_1, d$wt)` | `TRUE` |
| `max(y * w)` / `sum(y * w)` / `sum(w)` | 261 / 3829 / 240 — all exact integers |
| full-sample route | `1.59541666666666674961e+01` |
| replicate route, `y %*% m / colSums(m)` | `1.59541666666666674961e+01` |
| bit-identical / deviation | `TRUE` / `0` |
| premise SE at `scale = 1` | `0`, and `se == 0` is `TRUE` |
| stored default scale | `Inf` |
| SE and both bounds at the default | `NaN`, `NaN`, `NaN` |

And the counter-check that proves the fixture is load-bearing rather than
decorative: the same shape built from `rnorm()` and `runif()` gives a premise
SE of `1.776357e-15`, not zero, and a default-scale SE of `Inf`, not `NaN`.
That reproduces the builder's first attempt to the digit. So E1's second
branch is proven, both branches of E1 are exercised, and the whole-valued
fixture is the thing that makes it so. The comment the builder left on the
block is the right guard for a later editor.

## Confirmation — the oracle rule on row 2.3, all five parts

**The tester's reading is right, and on part 2 it is not even a judgment
call.** `test-spec.md` §The oracle rule, all five parts says in writing:
"Row 2.3's premise designs carry an explicit `scale` and are compared against
no `survey` design, so rule 2 does not reach them; the row's own oracle
comparison passes no `scale` to either side." So the exemption is authorised
text, not an inference. I state the principle explicitly, as asked: **a
premise design is not an oracle comparison.** Rule 2 exists because
`svrepdesign()` honours a supplied `scale` for the bootstrap, so feeding
surveycore's default in returns it unchanged and the comparison cannot
disagree. A design built only to establish that a finite scale yields a
finite non-zero standard error on the same frame is compared against nothing
on the `survey` side, computes no number `survey` then reuses, and reaches
`survey` on no path. There is no round trip to hide.

| Part | My finding on the diff |
|---|---|
| 1. same inputs, `mse` explicit both sides | same `d`, `weights = wt` / `weights = d$wt`, `repweights = all_of("repwt_1")` / `d[, "repwt_1", drop = FALSE]`, `type = "bootstrap"`, `mse = TRUE` written once per side. ✓ |
| 2. `scale` to neither side | neither `svrepdesign()` call and neither oracle surveycore design carries `scale`. The only `scale = 1` is on the two premise designs, exempt above. ✓ |
| 3. `rscales` to JKn only | no `rscales` anywhere in either block; both are bootstrap. ✓ |
| 4. assert the SE, not the point estimate alone | SE and both bounds on both sides in both blocks; no block asserts a point estimate at all. ✓ |
| 5. assert the condition, do not silence it | `expect_no_warning()` wraps each `svrepdesign()`; no `suppressWarnings()` and no `tryCatch()` in the added lines. ✓ |
| each side against its own literal | every assertion is a predicate on one side's own value. No surveycore number is compared to a `survey` number, and the two stored scales are never compared. ✓ |

One note on rule 4's confidence-bound precondition. The degrees-of-freedom
clause in `testing-surveycore.md` does not bite here, because these bounds
are asserted by `is.infinite()` and `is.nan()` predicates rather than
numerically. A change to either side's `degf` cannot move `Inf` to finite or
`NaN` to a number, so these two blocks are immune to the failure mode that
clause warns about. Rows 2.1 and 2.2, which PR 1 shipped, are not.

## Confirmation — row 3.1 did not copy the JK2 block

**It did not.** E-8's warning is honoured. Row 3.1 writes

```r
expect_equal(d_rep@variables$scale, 1, tolerance = 1e-8)
expect_equal(d_np@variables$scale, 1, tolerance = 1e-8)
```

Each stored scale is asserted against the literal `1`. No assertion in either
new block has a `@variables$scale` on both sides, which is the shape the
pre-existing JK2 block at `test-constructors.R:652` carries and which
`testing-surveycore.md` forbids. The two estimate comparisons that do run
side against side — `m_np$mean` against `m_rep$mean` and `m_np$se` against
`m_rep$se` — are what row 3.1 asks for, and the prohibition is on stored
scales, not on estimates the row exists to prove equal. Row 3.2 takes the
same discipline: `1 / (n_rep - 1L)` and `1 / n_rep` each against its own
literal, and the ratio against `sqrt((n_rep - 1L) / n_rep)`.

---

## CRAN cookbook and profile gates

`audit.md` §CRAN cookbook violations reads "None", and the audit verdict is
PASS, so there is no PASS-with-violations contradiction. The scan is
proportionate: the `R/` diff is seven roxygen lines and no executable line,
and I confirmed that from the diff.

All seven profile gates carry a result and none is skipped. `pkgdown` ran
rather than being skipped, which is right, because `man/` changed.

| Gate | Result | Reading applied |
|---|---|---|
| `document()` | wrote nothing | `man/` committed in sync |
| `test()` | `FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 12100` | "no new warning" — the 256 are the pre-existing AAPOR small-cell warnings, per the plan's §How to read three gates |
| `run_examples()` / `build` | PASS | — |
| `R CMD check --as-cran` | 0 / 0 / 2 NOTEs | same two as the base; see the note below |
| `pkgdown::build_site()` | site built | — |
| `covr` | 96.15% | floor 95%; see below |
| CRAN cookbook | none | — |
| `air format --check` | PASS on the PR's own lines | the plan's reading: "the files this work touches"; the `test-constructors.R` finding is pre-existing at the base and every site sits past line 1700 |

**One documented-skip note, not a breach.** The two NOTEs are "checking CRAN
incoming feasibility" and "hidden files and directories". The second is not
on the pre-approved list in `.claude/rules/r-package-conventions.md`, which
names "no visible binding" and "CRAN incoming feasibility". It is the same
`.git` note that `archive/as-svydesign-bridge/` records as pre-existing, as
caused by the worktree layout and `.Rbuildignore`, and as unfixable inside a
PR. The base carries the identical pair, so PR 4 adds no note. Recorded so
PR 5, whose AC-4 says "at most the two pre-approved notes", reads its own
result the same way.

## Coverage

96.15%, unchanged against the base, floor 95%, target 98%. Above the floor
and above 95-98% only on the absolute figure, so the HOLD band does not
apply: there is no drop to confirm. **No new-line coverage question can
arise** — the PR adds no executable line under `R/`, which I verified from
the diff, so there is no new code to leave uncovered. The 0.00% delta is the
expected reading and not a stale number.

## Comprehension alignment

`comprehension.md` exists, and the two gotchas that reach PR 4's surface are
both covered by a shipped test.

| Gotcha | Where it lands |
|---|---|
| G5 — `R = 1` makes the bootstrap scale infinite; a variance reads `Inf`, or `NaN` when the deviation is zero | `spec.md` E1, test-spec row 2.3, both blocks in this PR, measured above |
| G9 — the two constructors diverge on the bootstrap after this change | `spec.md` §`as_survey_nonprob()` roxygen D1 note, rows 3.2 and 4.2, all shipped here |
| G6, G7 — `NA` replicates do not re-derive `scale`; zero `rscales` with `mse = FALSE` | `spec.md` §Edge cases records both as pre-existing engine behaviour and explicitly out of scope, with the reason |
| §Assumptions — degrees of freedom stay at `Inf` | test-spec records the precondition; PR 4's bound assertions are predicates and do not rest on it |

G1 to G4, G8, G10 and G11 belong to PR 1 to PR 3's surfaces and were closed
there. No gotcha in PR 4's scope lacks either a test or a stated rationale.

---

## Findings — recorded, none blocking

**E-9 candidate — row 2.3's fixture values live only in `test-spec.md`.**
Plan PR 4 tasks 3-4 and AC-1 and AC-2 describe both frames structurally and
transcribe none of the six prescribed values, and the builder may not read
`test-spec.md`. The row was therefore unhittable to the letter. This is the
sixth instance of the pattern in this arc. The general repair is the one E-4
and E-6 already name: **a closed prescription and the agent it binds must
live in the same artifact.** For fixtures specifically, a plan task that
depends on exact literals must carry the literals.

**F2 confirmed as pre-existing.** `air format --check` on
`tests/testthat/test-constructors.R` reports "would reformat" at the base as
well as after, and every site is past line 1700 while the PR's block is at
1008-1112. Under the plan's own reading of the formatting gate the PR's lines
pass. Both documents reached this independently.

**F3 needs no action.** The class-only assertion with no snapshot behind it
(`as_survey_replicate()` raising `surveycore_error_weights_all_zero`) is
authorised by test-spec §Error-path pattern, belongs to row 1.6 and PR 3, and
is owned by issue #291. Not a defect and not PR 4's to close.

**Cosmetic, no action.** Three line numbers are off by one to four across the
two documents and E-8 itself: the inserted block's bounds (1010-1114 and
1007-1112 against 1008-1112), and the cross-reference citations `:1001` and
`:2484` against E-8's `:1002` and `:2482`. E-8's substantive ask — name both
overlapping blocks — is met. The arc has now recorded this same
cite-the-body-not-the-header drift three times; it is not worth a fix cycle.

---

## Decision

**PASS.** The seven checks:

| Check | Result |
|---|---|
| 1. Convergence — spec, test-spec, implementation | clean; four rows, four blocks, no gap |
| 2. Tolerance integrity | clean; no row looser than the test-spec, one authorised `tolerance = 0` written as authorised |
| 3. Scope discipline | clean; four files, exactly the plan's four, no regression outside scope |
| 4. CRAN cookbook and profile gates | clean; "None", seven gates with results, no undocumented skip |
| 5. Coverage | clean; 96.15% over a 95% floor, no executable `R/` line added |
| 6. Comprehension alignment | clean; G5 and G9 both tested |
| 7. `audit.md` verdict | PASS |

The convergence point holds. Builder and tester agree on all eight
load-bearing numbers, and the three I re-measured myself — the +35
expectation count, frame B's exactly-zero deviation and the `1.776e-15` drift
on a real-valued frame — reproduce their figures. F1 is a letter divergence
that the plan caused and that weakens nothing; F2 and F3 are pre-existing and
owned. Nothing here needs a builder or a spec cycle.

---

## Forward look — what PR 5 must know

**1. E-2's four-file list is complete and correct, verified arc-wide.**
`git diff --name-only 076bafe..HEAD -- tests/` at HEAD `703e036` returns
exactly four files and no fifth:

- `tests/testthat/test-analysis-corr.R`
- `tests/testthat/test-constructors.R`
- `tests/testthat/test-nonprob-bootstrap-variance.R`
- `tests/testthat/test-variance-replicate.R`

`git diff --name-only 076bafe..HEAD -- tests/testthat/_snaps/` returns zero
files. So row 4.5's snapshot clause holds across the whole arc as it stands,
and AC-3 must be read with E-2 and E-3's four names rather than the plan's
printed two.

**2. The arc base for the sweep is `076bafe`.** PR 5 task 4 says "the commit
`develop` sat at before PR 1" and names no SHA. It is `076bafe`, which is
`d11d1f8^`. Better still, assert the four file **names** and not a commit
range: PR 4 merges by squash, which rewrites the develop-side SHAs and makes
any hard-coded range wrong while leaving the file list invariant.

**3. The arc's whole changed-file set is seven, and PR 5 makes it nine.**
Today: `R/core-constructors.R`, `man/as_survey_replicate.Rd`,
`man/as_survey_nonprob.Rd` and the four test files. PR 5 adds `NEWS.md` and
`changelog/fix-replicate-scale-jkn-bootstrap.md`. Nine is E-1's corrected
figure; `spec.md` §Architecture still prints seven and is wrong by the two
test files E-2 names.

**4. The two percentages are not interchangeable, and PR 4 has already
placed one of them.** The `as_survey_nonprob()` help page now carries the
**fall**, 2.5%, and a rendered 2.6% there is a defect. `NEWS.md` states the
**rise**, so its figure is **2.6%**, from `spec.md` behaviour rule 6. Do not
let one document borrow the other's number.

**5. Two content requirements sit in `spec.md` and in no test-spec row.**
The changelog must record the E5 window — `type = "JKn"` with
`rscales = NULL` loses its only jackknife factor, issue #255 owns the
refusal — and must say this work clears **one** of the two sanctioned
exceptions in `.claude/rules/testing-surveycore.md`, not both. The Fay block
is the other and belongs to issue #243. A report claiming both is wrong.

**6. Read a red CI against the two known external causes before treating it
as PR 5's.** `surveytidy` was archived from CRAN on 2026-09-27 and `076bafe`
is the repository-wide fix; and CRAN archived `surveycore` 1.0.0 because
`marginaleffects` 1.0.0 breaks the grouped `get_diffs()` path. Every gate
figure in this run, PR 4's included, was measured against local
`marginaleffects` 0.32.0. Under 1.0.0 the baseline is `FAIL 10`, not
`FAIL 0`, and every number needs re-measuring. Neither cause is in this
arc's write surface and neither is PR 5's to fix.

**7. The NOTE pair.** AC-4 says "at most the two pre-approved notes". The run
reports "CRAN incoming feasibility" plus the pre-existing `.git` hidden-file
note, which is not the pair
`.claude/rules/r-package-conventions.md` names. The base carries the same
two. Count it as no new note, as
`archive/as-svydesign-bridge/` did, and say so rather than filing it.
