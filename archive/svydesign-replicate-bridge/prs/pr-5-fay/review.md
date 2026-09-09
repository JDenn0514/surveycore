# Review — PR 5 — fix/svydesign-replicate-fay

**Verdict**: PASS
**Date**: 2026-09-08 22:05 — supersedes this file's BLOCK of 21:15

**Tree**: `e1cadf0d53117b802617324ea498a331124413fd` — matches the tree
`audit.md` records. HEAD `980e681`, base `develop` at `8c99271`, unmoved, so
the branch is three commits ahead and none behind, and no rebase is involved.

The 21:15 BLOCK on tree `73b8b0af78a82d7f0502447920e309f89507262d` is closed
by commit `980e681`. §12 records the disposition. Sections 1 to 11 were
measured on the earlier tree and stand: `980e681` adds test code only, and I
re-confirmed the four figures that could have moved — the write surface, the
`test_invariants()` call count, the snapshot count, and the retention of X-18.

Scope judged: `spec.md` §I.1 row 10, and §IV.2 steps 1, 3, 4 and 7 — Fay's
shrinkage factor, its refusal, and the full round trip. Steps 2, 5 and 6
landed in pull request 4 and are re-checked here for regression only. This is
the last of the five, so quality gates 5 and 13 and observable properties 3,
8, 9 and 11 close here, and §11 below scores all twelve properties and all
thirteen gates.

Counters after this review: 1 tester BLOCK, 1 reviewer BLOCK. The cycle limit
is 3 (`signals.md`).

---

## Convergence checks

- Spec coverage: **y** — every behaviour `spec.md` §IV.2 and §IV.6 state for
  this pull request has a committed block. The one that did not, row E-8, is
  covered by block X-19 in `980e681`. See §12.
- Test coverage of spec: **y** — `test-spec.md` holds a row for every §IV.2
  and §IV.6 item this pull request carries.
- Tolerance integrity: **y** — no row loosened. Table in §2.
- Scope discipline: **y** — four files, exactly the plan's write surface.
- Regression safety: **y** — no test outside this pull request's scope changed
  state.

---

## 1. Convergence — spec, test-spec, implementation

### 1.1 The Fay recovery, derived independently

I derived the formula myself rather than reading it from `spec.md`. survey's
`svrepdesign.default` computes a Fay design's scale as

```
scale <- 1/(ncol(repweights) * (1 - rho)^2)
```

read straight out of `deparse(body(getS3method("svrepdesign", "default")))`.
Solving for `rho`: `(1 - rho)^2 = 1 / (scale * n_rep)`, so
`rho = 1 - sqrt(1 / (scale * n_rep))`. That is the line at
`R/methods-conversion.R:202`, with `n_rep` bound to `length(rep_vars)` — the
same quantity `ncol(repweights)` takes, because the route passes
`x@data[, rep_vars, drop = FALSE]`.

Run end to end on a fresh 12-replicate Fay source built with `fay.rho = 0.3`:

| Quantity | Value |
|---|---|
| Source `rho` | 0.3 |
| Source and stored scale | 0.170068 |
| `rho` derived by me from the stored scale alone | 0.30000000000000004 (diff 5.55e-17) |
| Exported design's `rho` | 0.3 |
| Exported scale minus source scale | 0 |
| Source SE, exported SE | 0.0868425492, 0.0868425492 (diff 0) |
| surveycore `get_means()` SE minus exported SE | 0 |

`spec.md` §IV.2 step 4 records scale 0.170068 for its own measurement. Mine
reproduces that figure exactly on an independently built fixture of the same
replicate count. The spec's measurement is sound.

### 1.2 The weakness the dispatch named is not present

The dispatch asked whether reading `sv$rho` off the exported object can detect
a wrong derivation. It can. `svrepdesign.default`'s return list is
`list(type=, scale=, rscales=, rho=, call=, combined.weights=)` — it stores the
`rho` it was handed, unmodified. So `sv$rho` on the object `as_svydesign()`
returns is surveycore's derived value, not survey's stored one, and the
committed blocks compare it against a literal:

- X-8: `expect_equal(sv$rho, 0.3, tolerance = 1e-10)` — 0.3 is the source's
  `fay.rho` argument, written into the test as a constant.
- X-13: `expect_equal(rt$rho, 0.5, tolerance = 1e-10)` — same shape, a
  different constant.

A wrong formula moves `sv$rho` away from the constant and both blocks fail.
Two further assertions fail with it, because survey recomputes the scale from
the `rho` it receives: `expect_equal(sv$scale, src$scale)` in X-8 and
`expect_equal(rt$scale, b$scale)` in X-13. The suite has four independent ways
to catch a wrong derivation.

The tester derived it independently as well — `audit.md` row E-9 reads "rho
recovered from an independently-derived formula (not read off `sv$rho`)", diff
5.6e-17. Three parties agree: builder, tester, reviewer.

### 1.3 Step 3 is unchanged

`R/methods-conversion.R:161-167` still reads

```r
scale_arg <- if (isTRUE(x@variables$type %in% c("BRR", "Fay"))) {
  NULL
} else {
  x@variables$scale
}
```

and the call still passes `scale = scale_arg`. The diff adds no line inside
that block. The code does not pass both `scale` and `rho` for Fay: it passes
`scale = NULL` and `rho = rho_arg`, exactly as §IV.2 step 4's "How this meets
step 3" requires. My run confirms the mechanism — the rebuilt scale equals the
stored one to 0 with no scale argument passed.

`rho = rho_arg` sits in the call unconditionally, with `rho_arg <- NULL` for
every type but Fay. `formals(svrepdesign.default)$rho` is `NULL`, and every
`rho` branch in that function guards on `!is.null(rho)`, so the explicit
`NULL` is a genuine no-op for the other eight types. §IV.3's "Passed for Fay
only" holds in behaviour.

### 1.4 Both refusal arms, and no `# nocov`

| Arm | Trigger | Class assertion | Snapshot | Scale text |
|---|---|---|---|---|
| Out of range | `as_survey_replicate(type = "Fay", scale = 0.05)`, 8 replicates | X-10 | X-10 | `"0.05"` |
| Missing scale | bare `survey_replicate()`, no `scale` key | X-11 | X-11 | `"none"` |

Both arms carry a class assertion and a snapshot, and the two snapshots render
different scale text — verified by reading
`tests/testthat/_snaps/conversion.md:63-83`. `grep nocov` over the whole diff
returns nothing. D8 is satisfied.

The two blocks each hold the class assertion and the snapshot together. D17
item 2 settles that as the house pattern — `.claude/references/testing-detail.md`
§Dual pattern shows one block — so it is not a finding.

X-10 uses `scale = 0.05` over 8 replicates where `test-spec.md` §9's C-8 prose
says `scale = 0.1` over 4. Both give the product 0.4 and the same recovered
-0.581, and §9's own "Both arms are reachable" table names the 0.05/8 pair.
The test-spec disagrees with itself; the builder followed the table. No
behavioural difference. Not a finding.

### 1.5 The one gap — closed

On the earlier tree, `test-spec.md` row E-8 — "`as_svydesign()` converts a
replicate design whose columns hold zeros", `expect_no_warning()` plus point
and SE parity — had no committed `test_that()` block. That was this review's
BLOCK. Commit `980e681` closes it with block X-19. Details in §12.

### 1.6 Implementation coverage of spec

Every step `spec.md` §IV.2 assigns to this pull request is in the merged
source, in the order the spec states: read keys (1), refuse an empty replicate
set (2, PR 4), scale argument (3), Fay recovery and refusal (4), FPC warning
(5, PR 4), the call (6), return (7). Nothing else in the route moved.

---

## 2. Tolerance integrity — clean

| Comparison | `test-spec.md` §4 | `audit.md` | Committed blocks | Verdict |
|---|---|---|---|---|
| Point estimate | 1e-10 | 1e-10 | X-8, X-9, X-12, X-13, X-14, X-15, X-16, X-18 | equal |
| Standard error | 1e-8 | 1e-8 | the same eight | equal |
| Confidence bounds | 1e-6 | 1e-6 | X-12, X-13, X-14 | equal |
| Recovered `rho`, rebuilt scale (E-9, E-10) | 1e-10 | 1e-10 | X-8, X-9, X-13 | equal |
| Structure | `expect_identical()` | `identical` | X-8, X-17, X-14 | equal |

No row is looser than `test-spec.md` specifies, and none is looser than the
`r-package-profile.md` default. No row is tighter either. The round-trip rows
— the most tolerance-sensitive in the change — carry the full 1e-10 / 1e-8 /
1e-6 triple in X-12 and X-13, and X-14 carries it through the FPC drop.

Two observations, neither a violation:

- The committed round-trip blocks report differences well inside tolerance —
  the tester measured point 0 and SE 2.2e-16 on R-1, and 0/0 on R-5. My own
  Fay run returned an SE difference of exactly 0. The tolerances are not doing
  work here, which is what `test-spec.md` §4 predicts for an exact algebraic
  inversion.
- X-8 asserts SE parity against the source `survey` design where E-9's row
  text names `get_means()`. Both are parity assertions at 1e-8, and X-9 and
  X-13 assert the `get_means()` side on the Fay branch, so the behaviour is
  covered from both ends. Under D11 I score behaviour, and the behaviour is
  covered.

---

## 3. Scope discipline — clean

| File | Plan §PR 5 Files touched | `implementation.md` write surface | `git diff --name-only origin/develop` |
|---|---|---|---|
| `R/methods-conversion.R` | yes | modified | present |
| `plans/error-messages.md` | yes | modified | present |
| `tests/testthat/test-conversion.R` | yes | modified | present |
| `tests/testthat/_snaps/conversion.md` | yes | modified | present |

Exact match. No extra file, no missing file. `NEWS.md` absent, no file under
`man/`, `NAMESPACE` and `DESCRIPTION` unchanged, and `R/core-classes.R`,
`R/core-constructors.R` and `R/variance-replicate.R` untouched.

Diff size: 459 insertions, 4 deletions. The four deletions are the three lines
of the pending-rows note plus the CB-3 line the trailing pipe replaced.

### 3.1 `plans/error-messages.md` finished state

| Check | Result |
|---|---|
| CB-1 to CB-5 in order, no gaps | lines 528, 529, 530, 531, 532 — sequential |
| CB-4 inserted between CB-3 and CB-5 | yes, verbatim from `spec.md` §V.7 |
| Pending-rows note removed | yes — no match for "remaining export-route condition" |
| CB-3's trailing pipe repaired (D18) | yes — all five rows now end with the delimiter |
| Rows 2 and 16's own table rows | untouched — the diff holds no added or removed line for either |
| The "Updated trigger descriptions" note | unchanged |

CB-2 in the file carries `{cli::qty(n_collisions)}`, the namespaced form, not
the spec's bare `{qty(...)}`. D17 item 1 settles that as a spec erratum, fixed
in the follow-up direct commit. Not a finding here.

### 3.2 Regression safety

`audit.md` re-ran I-1, C-10, C-6 and C-15 and every one held its prior state.
No test outside this pull request's scope changed pass or fail state. The test
count moved 11430 to 11532 (+102); failures held at 0; warnings held at 256,
D12's recorded baseline, so gate 2 passes on its operational reading.

The passing count fell from the blocked submission's 11542 to 11532. The
arithmetic is accounted for: the deleted `test_invariants()` call carried 16
expectations, X-18 adds 6. `implementation.md` and `audit.md` state the same
figures.

---

## 4. The tester's BLOCK, and its fix — verified

The fix is complete and narrow. `git show 56cfc92` is one file, 20 insertions
and 1 deletion:

- one line deleted, `test_invariants(d)` in the X-9 block;
- one line added to the section index comment;
- one new block, X-18, of 19 lines.

No production change. `R/methods-conversion.R`, `plans/error-messages.md` and
`_snaps/conversion.md` carry no diff between `0b40e45` and `56cfc92`.

**Call discipline on HEAD.** `test_invariants()` appears at four call sites —
lines 121, 754, 1157 and 2149 — plus one prose line at 2276 that names the
helper inside a comment. Constructors covered: `as_survey()` at 121 and 754
(both pre-existing on `develop`, out of scope for this feature),
`from_svydesign()` at 1157, `as_survey_replicate()` at 2149. One call per
constructor for the two this feature adds, in the first block that builds with
each, as `test-spec.md` §10.1 plans and `.claude/rules/testing-surveycore.md`
requires.

**The counts.** The dispatch stated the real sequence is 5 to 6 to 4. It is
not. I measured HEAD directly: 5 raw `grep` hits, 4 real calls. `audit.md`'s
correction section states raw 5 to 6 to 5 and real 4 to 5 to 4 across
`8c99271`, `0b40e45` and `56cfc92`, and gives the line numbers for each tree.
That reading is correct, it matches my own measurement of HEAD, and the audit
does not overclaim: it says its original figures were right, names the
dispatch's claim, and settles it by re-measuring both ways. The audit reads
right.

---

## 5. Quality gates 5 and 13 — both complete

**Gate 5.** Every class name in `R/methods-conversion.R`, counted:

| Class | Standing |
|---|---|
| `surveycore_error_repweights_names_lost` | CB-1, new |
| `surveycore_error_repwt_name_collision` | CB-2, new |
| `surveycore_warning_replicate_fpc_dropped` | CB-3, new |
| `surveycore_error_fay_rho_unrecoverable` | CB-4, new — this pull request |
| `surveycore_error_replicate_type_unsupported` | CB-5, new |
| `surveycore_error_empty_data` | reused, row 2 |
| `surveycore_error_repweights_empty` | reused, row 16 |
| `surveycore_error_not_survey_design` | pre-existing |
| `surveycore_error_not_survey_object` (twice) | pre-existing |
| `surveycore_error_not_tbl_svy` | pre-existing |
| `surveycore_error_pkg_not_installed` (seven times) | pre-existing |
| `surveycore_warning_twophase_method_unknown` | pre-existing |

All five new names from the dated section appear verbatim, both reused names
appear, and no other new class name is in the file. Gate 5 closes.

**Gate 13.** The `survey::svrepdesign()` call passes `rho = rho_arg` at
`R/methods-conversion.R:286`, and `rho_arg` is non-`NULL` only on the Fay
branch. I checked the call itself, not the word. And a Fay export now
succeeds: my §1.1 run converted a Fay design end to end and produced no stop.
The condition that used to fire — `if (type == "Fay" && is.null(rho))
stop(...)` — cannot be reached from this route, because the route either
supplies a `rho` in `[0, 1)` or aborts first with its own typed error. Gate 13
closes.

---

## 6. Snapshots — eight, six untouched

`tests/testthat/_snaps/conversion.md` holds exactly 8 snapshot headings. The
file's diff against `origin/develop` is 22 added lines and zero deleted, so
the six blocks pull requests 3 and 4 committed are byte-identical and
unreformatted, and the line endings did not move.

The two new messages read against `spec.md` §V.4:

- Both open the `x` bullet with "cannot recover the "Fay" shrinkage factor for
  this design", carry the two `i` bullets naming `rho` and the recorded scale,
  and close with the `v` bullet naming `as_survey_replicate()` and `scale`.
- The third bullet differs where it must: `The recorded scale is "0.05"` in
  one, `The recorded scale is "none"` in the other. `{scale_txt}` renders as a
  string on both branches, as §V.4 requires.
- The register is right: `x` and `i` declarative, `v` imperative, and no
  bullet addresses the user.

---

## 7. The second muffled warning — claim verified, muffle is narrow

X-17 wraps the export call as
`suppressWarnings(as_svydesign(d), classes = "simpleWarning")`.

**The builder's claim holds.** survey's `svrepdesign.default` ignores `scale`
for the types the builder names and reports it. `audit.md` records the
tester's independent run: JK2, ACS, successive-difference and `"other"`
without `rscales` each raised survey's own bare `simpleWarning`; JK1, JKn,
BRR, Fay and bootstrap did not. A JK2 design therefore comes back from a round
trip with scale 1, and X-17 correctly asserts the type, the replicate count
and the row count rather than the scale.

**The muffle cannot hide surveycore's own condition.** I built the typed
condition and read its class chain:

```
surveycore_warning_replicate_fpc_dropped / rlang_warning / warning / condition
```

`inherits(w, "simpleWarning")` is `FALSE`. I then raised a bare `warning()`
and the typed condition inside one
`suppressWarnings(..., classes = "simpleWarning")` and watched what escaped:
only `surveycore_warning_replicate_fpc_dropped`. The muffle is a class filter,
not a blanket, and no surveycore condition can inherit `simpleWarning` while
`cli::cli_warn()` builds it.

`suppressWarnings()` is neither `tryCatch()` nor `withCallingHandlers()`, so
`.claude/rules/testing-standards.md` is satisfied. X-17's designs record no
FPC in any case, so the typed warning is not raised there at all.

---

## 8. CRAN cookbook and profile gates

`audit.md` §CRAN cookbook violations reads "None". I re-scanned the added
lines in `R/methods-conversion.R` myself: no `T` or `F` as logicals, no
`set.seed()`, no bare `print()` or `cat()`, no `options(warn = -1)`, no
`installed.packages()`, no `<<-`, no unrestored state, no `mc.cores`, all
external calls namespaced, no `@importFrom`. The audit's verdict and its
cookbook table agree, so `reviewer.md` Step 4's misclassification trigger does
not fire.

| Gate | Result | Reading |
|---|---|---|
| `devtools::document()` | PASS | no `NAMESPACE` or `man/` drift; I confirmed the diff is empty |
| `devtools::test()` | PASS | FAIL 0, WARN 256, SKIP 4, PASS 11532 — D12's reading, warnings did not rise |
| `run_examples()` | PASS | exit 0 |
| `R CMD build` | PASS | tarball produced |
| `R CMD check --as-cran --no-manual` | PASS | 2 NOTEs, the pre-approved pair from `baseline.md`; no third pattern |
| `pkgdown::build_site()` | PASS | exit 0. Not skipped, and correctly so: the write surface touches `R/` |
| `covr` | PASS | 96.24% |
| `air format --check` on the pull request's own files | PASS | exit 0 — D16's reading |

Every gate has a result. Two carry a departure from their stated form, and
both departures are recorded decisions, not undocumented skips: gate 2 reads
as "no new warning" (D12) and gate 9 as "the pull request's own files are
air-clean" (D16). No skip is claimed under `r-package-profile.md` §pkgdown
skip condition.

**Departure from `tester.md` Step 1, recorded.** The orchestrator ran the
seven gates in the foreground, not the tester, because seven background gate
runs were killed for low memory across this run (D12, D16). The tester's own
figures come from direct `pkgload::load_all()` runs of the test-spec's fixture
recipes. The gate table in `audit.md` names the log directory,
`logs/pr-5-refix/`, and the tree hash matches the tree I am reviewing. The
evidence chain holds; the division of labour did not.

---

## 9. Coverage floor

| Measure | Value | Floor | Verdict |
|---|---|---|---|
| Package | 96.24% | 95% | PASS |
| Against this pull request's baseline | 96.23% to 96.24% | no drop | PASS |
| `R/methods-conversion.R` | 99.72% to 99.75% | — | rose |
| Uncovered lines in the file | 1, line 436 | — | pre-existing |
| `# nocov` added | none | none | PASS |

Line 436 is not new code. `git blame` puts it in PR #12
(`feat(conversion): implement from_svydesign() and from_tbl_svy()`), touched
since only by the repository-wide air formatting commit, and it already
carries a `# nocov` with the explanatory comment `testing-standards.md`
requires. It sits far outside this pull request's diff, which adds lines 169
to 240 and line 286. So `spec.md` §VII gate 3's second half — 100% of the new
lines covered — holds, and no new line is uncovered. Coverage rose in both the
package and the file.

---

## 10. Comprehension alignment

Every gotcha in `comprehension.md` has a `test-spec.md` scenario or a
`spec.md` rationale. The planner did its job. One gotcha is only half covered
in committed code, and that half is the BLOCK below:

| Gotcha | Where it lands |
|---|---|
| Unnamed replicate columns, both compress values | `spec.md` §III.2 step 6; rows I-8, I-9, I-17, I-18 — PRs 1 and 2 |
| `repweights_compressed` is a list, not a matrix | §III.2 step 2; cells A and C |
| `as.matrix()` dispatch under `requireNamespace()` | §VIII; PR 1 |
| `as.svrepdesign()` always reports the factor form | §III.2 step 9; PR 2 |
| Mechanism 2's error has no fixed direction | `test-spec.md` §4 forbids any ratio assertion; every row asserts parity only |
| Mechanism 1 raises nothing at conversion time | §III.2 steps 6 and 7 |
| `as.matrix()` does not return a plain matrix | §III.2 step 2's `unclass()`; PR 1 |
| surveycore's replicate variance never reads the FPC | §IV.5; D3; PR 4 |
| **Zero replicate weights are legal** | import half committed at `test-conversion.R:1541`; **export half is row E-8 and has no block** |
| Generated names can collide | §V.2, CB-2; PR 3 |

Every assumption is reflected in a `spec.md` contract: `x$pweights` in §III.2
step 9, the `rscales` length in §VIII, round-trip parity in §VI property 3,
and row order in §III.2 step 11.

---

## 11. Whole change — the twelve properties and the thirteen gates

### Observable properties, `spec.md` §VI

| # | Property | Status | Where it closes |
|---|---|---|---|
| 1 | Import parity | met | I-1 to I-4, PRs 1 and 2; cells A to D all committed |
| 2 | Export parity, with and without an FPC | met | PR 4's E-2 to E-5; this pull request's X-15, X-16, X-18 and X-9. The zero-column edge case of this property is the BLOCK, but the property itself holds |
| 3 | Round-trip parity | met | X-12, X-13, X-14, plus the pre-existing replicate round-trip block |
| 4 | No silent loss | met | PR 1 |
| 5 | No silent renaming | met | PR 2 |
| 6 | The export drop is loud | met | PR 4, X-1 |
| 7 | The export drop is not destructive | met | PR 4, E-6 |
| 8 | Every accepted type converts both ways | met | X-17 crosses all nine types both ways; C-10 to C-12 refuse the two survey types surveycore does not accept, and I confirmed the refusal still fires |
| 9 | A Fay design keeps its scale | met | X-8 and X-13; my own run reproduces scale and SE to 0 |
| 10 | Stored replicate columns match the source matrix | met | PRs 1 and 2 |
| 11 | A degenerate design is refused | met | C-13 to C-16, PRs 3 and 4 |
| 12 | The generated columns add no metadata | met | PR 2, `test-conversion.R:1853` |

All twelve hold.

### Quality gates, `spec.md` §VII

| # | Gate | Status |
|---|---|---|
| 1 | `R CMD check` clean | met — 0 errors, 0 warnings, the two pre-approved NOTEs |
| 2 | Full suite passes | met on D12's reading — 0 failures, warnings held at 256 |
| 3 | Coverage floor, and every new line covered | met — 96.24%, one pre-existing uncovered line |
| 4 | Every new condition typed | met — all five `cli_abort()` and `cli_warn()` calls carry `class =` |
| 5 | The condition table matches the code | met, closes here — §5 above |
| 6 | The write surface holds | met — the arc's cumulative diff names exactly the five files §II.1 lists |
| 7 | `NEWS.md` untouched | met |
| 8 | Only `man/from_svydesign.Rd` regenerates | met |
| 9 | Formatting clean | met on D16's reading |
| 10 | The FPC arguments are gone from the export call | met — the call holds no `fpc =` and no `fpctype =` |
| 11 | No class change leaked in | met |
| 12 | The docstring no longer states the false contract | met — the page says the route "transforms the replicate weights rather than preserving them" and describes the written block |
| 13 | Fay reaches survey with a shrinkage factor | met, closes here — §5 above |

All thirteen hold. Neither the properties nor the gates are what blocks this
pull request.

---

## Cross-consistency notes

`implementation.md` and `audit.md` agree everywhere I checked them against the
tree: the same four files, the same tree hash, the same test counts and the
same expectation arithmetic for the fix commit, the same eight snapshots, the
same absence of `# nocov`, and the same reading of survey's `simpleWarning`
for JK2.

They also agreed on the gap. On the blocked tree, `implementation.md` §Tests
added listed eleven blocks, X-8 to X-18, and none was E-8's scenario.
`audit.md` said so in plain words — "As committed test code, 57 of 58" — named
E-8 as the missing one, and stated that X-18 "does not substitute for E-8's
zero-value scenario". Builder and tester converged on the same set of tests,
and both recorded the same shortfall. The tester classified it non-blocking
and issued PASS.

I scored it differently, for one reason: this is the last pull request of
five, and `implementation-plan.md` §Test row allocation puts every one of the
58 rows in exactly one pull request. E-8 was in PR 5's column and nowhere
else. `audit.md`'s remedy at the time — "Recommend a future small change add
the E-8 block" — handed the row to work that was not planned, not scheduled
and not owned. That is the shape of failure `artifact-schemas.md` §PR budget
records from issue #165: a gap that falls between pull requests because no
later one owns the file. Here the file was already in this pull request's
write surface, which is why the BLOCK was cheap to close — one test block, no
production change, and the write surface did not move.

Commit `980e681` closes it, the audit now reports all 58 rows committed, and
builder, tester and reviewer agree on the merged tree.

Three smaller observations, none of them part of that BLOCK:

- **R-3's assertion runs in one direction only.** `test-spec.md` R-3 asserts
  the replicate count survives survey to surveycore to survey, with
  `ncol(as.matrix(sv_rt$repweights))`. X-17 asserts the count survives
  surveycore to survey to surveycore, for all nine types. The behaviour "the
  round trip loses no replicate" is covered; the direction differs. If the
  builder is dispatched anyway, one `expect_identical()` on the replicate count
  inside X-12 closes it exactly. Optional.
- **R-2's behaviour rests on a pre-existing block.** The finished-weight round
  trip is covered by `test-conversion.R:549`. I confirmed that block's source
  reports `combined.weights = TRUE`, uncompressed, and asserts point at 1e-10
  and SE at 1e-8 — R-2's assertions. No new block was needed and none was
  written.
- **The dispatch's "5 to 6 to 4" is wrong and the audit is right.** Recorded
  in §4 so the next reader does not re-litigate it.

---

## 12. The BLOCK, and its disposition

**Closed.** Commit `980e681` adds block X-19, "`as_svydesign()` passes a
zeroed replicate column through [numerical]", and nothing else. One file, 44
insertions, 0 deletions, no production code. The write surface does not move:
the four files are the same four the plan lists.

The four figures the fix could have disturbed, re-measured on the new tree:

| Check | Value | Verdict |
|---|---|---|
| `git diff --name-only origin/develop` | the same four files | unchanged |
| `test_invariants()` real call sites | 4 — lines 121, 754, 1157, 2149; X-19 adds none | unchanged |
| Snapshot headings in `_snaps/conversion.md` | 8, and the diff is still 22 added and 0 deleted | unchanged |
| X-18 retained | yes | unchanged |

`plans/error-messages.md` and `R/methods-conversion.R` are byte-identical to
`56cfc92`, so §5's gate 5 and gate 13 findings, §6's snapshot reading and
§3.1's condition-table checks all carry over untouched.

### 12.1 X-19 asserts the behaviour row E-8 names

The block builds a `"JK1"` design of five replicate columns with the first set
to 0, asserts the column is all zeros, asserts `expect_no_warning()` on the
`as_svydesign()` call, asserts the result is a `svyrep.design`, asserts
`sum(sv$repweights[, 1])` is 0 — the zeros reached the exported design
unchanged — and asserts parity against `get_means(d, y1, variance = "se")` at
1e-10 and 1e-8. That is `test-spec.md` row E-8's scenario and its two
tolerances, with two structural assertions on top.

`"JK1"` is a better fixture than the test-spec's bare "zero column entry",
because a JK1 replicate deletes a whole PSU, so a zeroed column is what the
method actually produces rather than a value contrived to be legal.

### 12.2 Both reported claims verified independently

I took neither claim on the builder's or the tester's word.

**The conversion itself raises nothing.** I ran `as_svydesign()` on X-19's
design under a `condition` handler that recorded every warning and every error
of any class. Nothing was raised. So `expect_no_warning()` is honest, and the
muffle in the block sits on `survey::svymean()`, one line lower, not on the
call under test.

**The muffled condition is survey's, and the muffle stays narrow.**
`survey::svymean()` raises exactly one warning here:

```
classes = simpleWarning / warning / condition
msg     = 1 replicates gave NA results and were discarded.
```

A base R `simpleWarning` from survey's variance code. §7 already established
that a `cli::cli_warn()` condition carries
`.../rlang_warning/warning/condition` and never `simpleWarning`, so
`suppressWarnings(classes = "simpleWarning")` cannot hide a surveycore
condition. The muffle is a class filter, and it is neither `tryCatch()` nor
`withCallingHandlers()`, so `.claude/rules/testing-standards.md` holds.

**The parity is not passing for the wrong reason — the load-bearing claim.**
The builder reports that surveycore discards the same replicate, and that this
is why the two standard errors agree. I tested it by computing the JK1
variance three ways by hand, outside both packages:

| Treatment of the zeroed replicate | Standard error |
|---|---|
| Discarded — variance over the 4 finite replicates | 0.27534884496187928 |
| Kept, its 0/0 estimate read as 0 | 45.112006990076537 |
| `NA` propagated | `NaN` |

Observed: surveycore 0.27534884496188244, survey 0.27534884496187928,
difference -3.164136e-15 — the figure the fix commit reports, to three
significant figures. The hand-computed discard variant matches survey's value
to the last digit.

So both sides discard the same single replicate, and the assertion is
genuinely sensitive to that: keeping the replicate moves the standard error by
a factor of 164, and propagating the `NA` gives `NaN`. Either failure mode
breaks the 1e-8 assertion loudly. The claim holds, and the parity is
substantive.

surveycore's own discard is in the source, not inferred:
`R/variance-replicate.R` holds `ok <- !is.na(thetas)`, with
`surveycore_error_all_replicates_na` for the case where every replicate is
`NA`. X-19 therefore also exercises the partial-`NA` path of that guard from
the export side.

### 12.3 The audit's closing sentence

`audit.md` now reads:

> **Yes — all 58, and every one of them now has a committed test block.**

That is the sentence the BLOCK was about, and it now says what it should. Row
I-25 still correctly carries no block, as `test-spec.md` §6.4 records. The
audit's verdict is PASS with no open findings, and its tree hash matches the
tree I reviewed.

### 12.4 How the gap arose — not a builder defect

The coordinator relayed the tester's non-blocking finding to the builder as
"an accepted replicate type that records no FPC", which is not the gap the
tester meant. The builder built what it was asked for, block X-18, and that
block guards a real behaviour — an accepted type with no FPC converts silently
and reports surveycore's numbers, a pair neither X-5 nor X-15 covered. X-18
stays. It is deliberate rather than scope creep, and it is neither an extra
file nor an extra production line.

So the record on this pull request is one tester BLOCK, for a duplicate
`test_invariants()` call, and one reviewer BLOCK, for a gap a relay error
introduced. Two BLOCKs, both closed, both by test-only commits. The cycle
limit of 3 is not reached.

### 12.5 Gates on the new tree

Re-run in the foreground by the orchestrator on tree
`e1cadf0d53117b802617324ea498a331124413fd`; logs at `logs/pr-5-refix2/`. All
seven pass: `document()` with no drift, `devtools::test()` at
FAIL 0 / WARN 256 / SKIP 4 / PASS 11538, `run_examples()` exit 0,
`R CMD build`, `R CMD check --as-cran --no-manual` at 2 NOTEs (the
pre-existing pair from `baseline.md`), `pkgdown` exit 0, and covr at 96.24%
for the package and 99.75% for `R/methods-conversion.R` with the one
pre-existing uncovered line.

The passing count moved 11532 to 11538, +6 — X-19's own expectations, with no
other block's count changing. Warnings held at 256, D12's baseline, so gate 2
passes on its recorded reading. Coverage did not move, which is expected:
X-19 asserts a pass-through that has no branch of its own, so it reaches no
new line while adding the regression guard the arc was missing. Gate 3's
second half — 100% of the new lines covered — still holds.

The same departure from `tester.md` Step 1 applies as in §8: the orchestrator
ran the gates, not the tester, because background runs were killed for low
memory (D12, D16). Recorded, not scored.

---

## Decision

PASS. All seven checks are clean.

The Fay work is correct, and I verified it independently rather than reading
it: the recovery inverts survey's own
`scale <- 1/(ncol(repweights) * (1 - rho)^2)`, an end-to-end run recovers 0.3
from a source built with `fay.rho = 0.3` and reproduces the source's scale and
standard error to 0, and the committed blocks compare `sv$rho` — the value
surveycore passes — against a literal constant, so a wrong derivation fails
four assertions. Step 3 keeps `scale = NULL` for Fay and the route passes
`rho` alone, as §IV.2 step 4 requires. Both refusal arms are reachable, each
carries a class assertion and a snapshot, the two snapshots render different
scale text, and no `# nocov` was added.

No tolerance was loosened anywhere: point 1e-10, SE 1e-8, CI 1e-6 and the
recovered-`rho` 1e-10 all match `test-spec.md` §4 exactly, including on the
round-trip rows. The write surface is the plan's four files. The cookbook scan
is clean, every profile gate has a result, and the two gates whose stated form
is already false on `develop` carry their recorded readings. Coverage is above
the floor, rose, and leaves no new line uncovered.

Quality gates 5 and 13 close here, as the plan says they must, and all twelve
observable properties in `spec.md` §VI and all thirteen quality gates in §VII
now hold across the five pull requests. The one gap I blocked on — the export
route passing a zeroed replicate column through, `test-spec.md` row E-8 — is
closed by block X-19, and I confirmed by hand that its parity assertion would
fail by a factor of 164 if either package stopped discarding the `NA`
replicate. `audit.md` is PASS with no open findings.

The change is ready to ship. Two items follow it, both already recorded
elsewhere and neither blocking: the direct commit to `develop` that owes
`NEWS.md`, D17's two `qty()` corrections and the calibration ledger row; and
the four follow-up issues in `spec.md` §IX.1 and `implementation-plan.md`
§Carried forward, including the `as_svydesign()` roxygen note for the new FPC
warning.
