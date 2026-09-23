# Review — PR 9 — docs/oracle-rule-exceptions

**Verdict**: PASS
**Date**: 2026-09-22
**Branch**: `docs/oracle-rule-exceptions` at `91236812e3dcdf7e581be58a1644b33c21ea6241`
**Base**: `d6d30c7a89c1704cf1eb35fc3520065ee3e6366d`
**Tree**: `829adc683ed44472b48f3707a36c9308c4639f78` — matches `audit.md` and
`logs/pr9/runner.log`.

This is the arc's last review. It covers PR 9 and the arc's completion
contract, `spec.md` §VIII.

---

## Convergence checks

- Spec coverage: **y**. `spec.md` §III.2's final subsection ships whole; rows
  6.15 and 6.10 validate it in `audit.md`.
- Test coverage of spec: **y**. Arc-wide, `test-spec.md` holds 72 rows, the
  plan allocates 72, and the two sets are identical — no row unallocated, none
  invented. Every allocated row is reported in its PR's audit (checked by a
  script over all nine audits; zero misses).
- Tolerance integrity: **y**. PR 9's eight rows are structural and carry
  "exact". Arc-wide the finished test file uses three tolerance values and no
  others: `1e-10` (14), `1e-8` (30), `1e-6` (26) — exactly `test-spec.md` §8's
  three rows, with no looser value anywhere.
- Scope discipline: **y**. `implementation.md` §Write surface names
  `.claude/rules/testing-surveycore.md`; the plan's Files touched names the
  same one file; `git diff d6d30c7 HEAD` returns that file and `+15/-1`.
- Regression safety: **y**. Failures 0, warnings 256, skips 4, passes 12005,
  coverage 96.15%, 2 NOTEs — every figure equal to PR 8 and to the baseline
  where the baseline applies. A zero delta is the correct result: the changed
  path is excluded by `.Rbuildignore` and opened by no test.
- Comprehension alignment: **y**. G1 to G13 each land in the rule text, in a
  block assertion, or in a deferred issue (G11 → #255). Every assumption is
  measured and reflected: no block passes `combined.weights`, every block reads
  `R` from the selected columns, `test_invariants(` appears once,
  `expect_no_warning()` covers the combined-weights heuristic in all ten quiet
  blocks. O2 was closed by decision O2 in `decisions.md`.

---

## The 18 quality gates of `spec.md` §VIII

Re-measured here unless the row says otherwise. Parse-based counts come from
`utils::getParseData()` and a walk over the parsed `test_that()` bodies, never
from `grep` on lines.

| # | Gate | Holds | Evidence |
|--:|---|---|---|
| 1 | Nine types have an oracle block | yes | Re-measured: 14 `survey::svrepdesign()` calls carry 9 distinct `type` literals — acs 2, bootstrap 1, brr 4, fay 1, jk1 1, jk2 1, jkn 1, other 1, successive-difference 2. Agrees with `pr-9/audit.md` [no such file] §3.5.3. |
| 2 | No `scale` to `svrepdesign()` | yes | Re-measured: 0 `scale` arguments across all 14 calls. Landed at PR 4 (`pr-4-jk1-jk2/audit.md` row 2.2). |
| 3 | Exactly one `rscales`, in JKn, same literal both sides | yes | Re-measured: 1 `rscales` argument, value `rep(1, n_rep)`, in the JKn block; the surveycore side of that block passes the same literal written out a second time (test file lines 830–847). PR 5 row 2.3. |
| 4 | No `suppressWarnings()` | yes | Re-measured: 0 calls. PR 4 row 2.5. |
| 5 | No value read off one design into the other; no side's scale asserted against the other's | yes | Re-measured: the 13 `sv$scale` assertions all compare against a literal, and the 4 `sc@variables$scale` assertions all compare against a literal. No assertion holds both sides. PR 8 row 2.6. |
| 6 | Every `survey`-building block asserts a condition; the three fragment blocks also assert the count | yes | Re-measured: 10 `expect_no_warning()`, 3 `capture_warnings()` + `expect_length(w, 1L)` + `expect_match()` (JK1, JK2, other), 1 `expect_error()` (Fay) = 14, one per `survey` block. None of the three fragments is the G4b "rho not relevant to JK1" trap. PRs 7 and 8. |
| 7 | Five assertions per numerical block, each stored-scale assertion commented | yes | Re-measured: 13 numerical oracle blocks, each holding `coef(sv…)`, `survey::SE(`, `ci_low`, `ci_high` and `sv$scale`; the 13 comment lines are at 43, 84, 138, 195, 269, 344, 433, 475, 517, 559, 854, 930, 1014, each immediately above its assertion at the next line. PR 7 row 2.18. |
| 8 | JKn and bootstrap: three wrappers, one ratio assertion, the #253 comment | yes | Re-measured: 6 `testthat::expect_failure()` calls, 3 in each of the two named blocks, one assertion inside each; the unwrapped ratio assertion of `sc_mean$se / survey::SE(sv_mean)` against `sqrt((n_rep - 1) / n_rep)` at `1e-8` sits outside every wrapper in both; both comments say "delete FOUR lines". PR 6 rows 2.9–2.11, 2.15, 2.16, §3.6. |
| 9 | The Fay comment | yes | Read at test file lines 1029–1037: it names issue #243, says the block compares nothing, and says the refusal half guards `survey`'s behaviour and should be read that way before being read as a surveycore regression. PR 8 row 2.12. |
| 10 | The rule section, the per-type table, the Quick Reference row, and six named elements | yes | Read the finished section whole, lines 165–312. See the element list below. |
| 11 | The full suite passes; no new failure, no new skip | yes | `logs/pr9/runner.log`: `ALL GATES PASS`, `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 12005 ]`, on tree `829adc68`. Skips equal the baseline's 4. |
| 12 | The diff lists exactly two files | yes | Arc-wide: `git diff --name-only 7800ea9 HEAD` returns `.claude/rules/testing-surveycore.md` and `tests/testthat/test-variance-replicate.R`, and nothing else. Per PR 9 the diff is one of those two, which is the plan's per-PR reading. |
| 13 | Both files pass `air format --check` | yes | Re-run here: exit 0 on the rule file, exit 0 on the test file. |
| 14 | `skip_if_not_installed("survey")` inside every `survey` block, never at file level | yes | Re-measured: 14 guards for 14 `survey` blocks; in every one the guard is the block's first statement and precedes any `survey::` call; the file holds 0 top-level expressions that are not `test_that()`. PR 8 row 2.8. |
| 15 | `test_invariants(` exactly once | yes | Re-measured: 1 call. PR 3 row 2.19. |
| 16 | 28 `test_that()` blocks | yes | Re-measured: 28 top-level `test_that()` calls, none nested. `pr-9/audit.md` [no such file] row 3.5.2. |
| 17 | JKn, bootstrap and Fay titles claim no match | yes | Titles read back from the AST: "…JKn SE **disagrees** with survey::svymean() — issue #253", "…bootstrap SE **disagrees** with survey::svymean() — issue #253", "survey::svrepdesign() **refuses** Fay without rho — Fay design". PR 8 row 2.23; finding N3 records the word filter's false positive at line 309. |
| 18 | `test-conversion.R` unchanged | yes | `git diff --stat 7800ea9 HEAD -- tests/testthat/test-conversion.R` is empty across the whole arc, and both blocks the carve-out names exist with the exact quoted titles, at lines 239 and 567. PR 2 row 6.17. |

### Gate 10, element by element

The section was written across three PRs (#281 core, #282 evidence and scope,
this PR's exceptions). Read as one finished section:

| Element gate 10 names | Where | PR |
|---|---|---|
| The split between the general rules and the `svrepdesign()`-specific ones | "Which rules reach which design", L171–176 | 1 |
| The conversion carve-out naming the two `test-conversion.R` blocks | "What the rule covers", L271–298; both titles character-exact against the file | 2 |
| The snapshot sentence about the installed `survey` version | "**The per-type table is a snapshot.**", L259–263 | 2 |
| Check the version before reading a red block as a surveycore regression | "**Read a failure against the `survey` version first.**", L265–269 | 2 |
| The two sanctioned exceptions, with #253 and #243 | "Sanctioned exceptions in `test-variance-replicate.R`", L299–312 | 9 |
| The argument-versus-literal bullet | "A formula forbidden as an argument is still allowed as an assertion literal", L207–213 | 1 |
| The §III.3 per-type table | L244–257, nine data rows, `survey` 4.5 named | 2 |
| The Quick Reference row | L13, scoping rules 2 and 3 to `svrepdesign()` | 1 |

The section is headed exactly as §III.2 requires and sits after "The both-modes
rule" (L93) and before "S7 error testing layers" (L313) — row 6.18.

I diffed the finished section line by line against `spec.md` §III.2's
block-quoted text. Four differences, all correct:

1. The heading drops the block-quote marker. Formatting, as §III.2 allows.
2. The §III.3 table and its lead-in sentence are inserted, which §III.3
   requires. The builder placed the table before the snapshot paragraph rather
   than after it, so the paragraph now follows the table it describes.
3. The "A later PR that moves surveycore's replicate path…" paragraph is
   rewrapped. Row 6.20 requires its content; the rewrap changes no word.
4. The "**The precondition is measured.**" paragraph is omitted. It cites
   `measurements.md` §M7 and `comprehension.md` §G12, both run-directory
   artifacts that die with the run. Correctly left out of a permanent rule file,
   and no row asks for it.

Nothing else differs. Decision S3's known erratum stands: gate 10 omits the
"never assert one side's stored scale against the other side's" bullet and rule
4's confidence-bound precondition. Both ship, both are checked by rows 6.19 and
6.20, and both passed at PR 1. The checking gap is closed.

---

## The two rows allocated to PR 9's rule text

**Row 6.15 — holds.** The new subsection names both exceptions, gives each the
issue that closes it (#253 for the JKn and bootstrap wrappers, #243 for the Fay
block), and states in its third sentence that anything else which breaks the
shape is a violation. Measured against the file rather than the prose: the
parse walk finds `expect_failure()` in exactly two blocks, three calls each,
and they are the two blocks the text names; the Fay block asserts the refusal
on one side and `1 / n_rep` on the other. The text describes the file it
governs.

**Row 6.10 — holds.** I listed every digit-bearing line in lines 165–312
independently of the tester. The numbers present are rule ordinals, issue
numbers (#242, #253, #243), scale formulas, the oracle versions (`survey` 4.5,
R 4.6.1) and "issue #242 survived 22 releases". That last one is a release
count. No expectation total, no run time. Issue #215's ban is met.

---

## The finished-file evidence, rows 3.5.1 to 3.5.6

The tester measured these itself rather than deferring, which was the right
call: they read a file no PR now edits, and they need R for seconds, not
minutes. I reproduced every static count from the AST and reached the same
figures — 28 blocks, 14 `survey` blocks, 9 of 9 types, 6 `expect_failure()`
calls in 2 blocks, 1 `test_invariants()`, 0 `scale`, 1 `rscales`, 0
`suppressWarnings()`. I did not re-run the two test passes; the gate log on the
same tree backs the full-suite figure and the audit records the two
single-file figures.

### Judgement on the `survey`-absent method

**Sound, and transparent about the one way it differs.** The stub proves what
row 3.5.4 asks and I would not ask for it to be redone.

`testthat::skip_if_not_installed()` (testthat 3.3.2, read here) has two exits:

```r
tryCatch(find.package(pkg), error = function(e) skip("{survey} is not installed"))
if (!requireNamespace(pkg, quietly = TRUE)) skip("{survey} cannot be loaded")
```

A machine where `survey` was never installed takes the first exit. The stub
takes the second: `find.package()` succeeds on the shadow directory,
`loadNamespace()` then fails on a package with no code, and `requireNamespace()`
returns `FALSE`. Both exits skip the same 14 blocks and run no block body, so
the two differ only in the reason string — and the audit records the string it
got, `{survey} cannot be loaded`, rather than claiming the other one. Nothing is
misreported.

On one axis the stub is the stronger test. It passes through the first check and
is caught by the second, so it proves the guard fires even when a `survey`
directory is present on the path. A genuinely absent machine short-circuits
earlier and never exercises `requireNamespace()`.

I checked the route the question asks about — whether a block could reach
`survey` without passing the guard — three ways, and found none:

- In all 14 blocks the guard is the **first** statement of the body and
  precedes every `survey::` call. Verified on the AST, not by eye.
- The file holds no top-level expression other than the 28 `test_that()` calls:
  no `library(survey)`, no file-level skip, no setup code.
- No indirect route exists. `tests/testthat/helper-*.R` names `survey`
  nowhere, and the file calls no `srvyr`, `as_svydesign()`, `from_svydesign()`
  or `as_tbl_svy()` — the surveycore functions that would reach `survey`
  internally. The empirical result agrees: 14 skipped, 14 ran, `FAIL 0`. A
  hidden route would have errored rather than skipped.

Two residual differences, both immaterial and both worth a later reader
knowing. The stub reports version `0.0.0.9000`, so a `minimum_version =`
argument would behave differently — no call in this file supplies one. And the
stub shadows `survey` for every consumer in that session; the run was filtered
to this one file, so nothing else needed it. Neither agent modified the real
library, and I confirmed the working tree is clean.

---

## The version bump — decision S2

**Correct, complete, and S2's reasoning holds better than when it was written.**

- Correct in isolation: the diff hunk is `@@ -1,6 +1,6 @@` with a single
  `-`/`+` pair on the `**Version:**` line. The `**Status:** Decided — do not
  re-litigate…` line and every other header line are untouched.
- Correct against the file's own precedent, which I checked with
  `git log -L1,6`. The file went 1.0 → 1.1 → 1.2 → 1.3. The 1.2 bump was commit
  `965ec80`, which added one whole section — the both-modes rule with its
  measured rationale — and moved the minor digit by one. This arc added one
  whole section, the oracle rule, and moves the minor digit by one. Three bumps
  for one section would have been the anomaly, not one bump for three PRs.
- Complete: no other file pins this file's version. Eleven documents under
  `.claude/` cite `testing-surveycore.md` by path and none by version, so the
  bump breaks no reference.
- Not a major bump, correctly. Nothing in the file was reversed or removed;
  content was added.

S2 recorded a leader's call taken before the finished file existed. Seeing the
finished file, the call reads right: a reader who found `1.2` above a major new
section would have no way to tell the file had moved.

---

## Cross-consistency notes

`implementation.md` and `audit.md` agree on every number they both report — 166
passes with `survey`, 14 skips without, 28 blocks, 9 of 9 types, 6
`expect_failure()` calls, 12005 suite passes, one AAPOR warning at line 798.
They reached the counts by the same instrument, so the agreement is weaker
evidence than two instruments would be; I re-derived the static counts with my
own parse walk and they match, which supplies the independent side.

The two figures neither agent could cross-check are the two test runs. The
full-suite figure is backed by `logs/pr9/gate-2-test.log` and the runner
summary on the same tree.

The pkgdown skip is inside the documented scope condition: the write surface
touches no file under `R/`, `vignettes/`, `README*`, `_pkgdown.yml` or
`DESCRIPTION`, and the `NAMESPACE` diff is empty, so the hard rule about export
changes does not bite.

The two check NOTEs are the pair `baseline.md` fixes as the arc's reading of
gate 5: `checking CRAN incoming feasibility`, which is pre-approved, and
`checking for hidden files and directories`, which `R CMD build` raises on
`.git` and which is present on the clean pre-arc baseline. I read the log
myself. Neither is a new pattern, so `signals.md` §STOP's new-NOTE trigger does
not fire. `test-spec.md` §9 note 4 names a different second NOTE and is stale
against `baseline.md`; that is a planner wording slip with no effect on any
verdict, recorded here and not routed.

Decision S1 is moot for this PR: the leader ran a full gate pass on PR 9
rather than carrying the baseline forward, so the gate table is measured and not
inherited.

---

## Findings carried out of the arc

Neither is a defect in PR 9 and neither changes this verdict.

**N1 — the two oldest BRR blocks pass `mse` to one side only.** The blocks at
lines 12 and 55 pass `mse` to `survey::svrepdesign()` and not to
`as_survey_replicate()`, which defaults it to `TRUE`. The two sides agree only
because the default happens to match. `spec.md` §IV.2 requires `mse` explicitly
on both sides, so these two blocks sit outside the contract the arc wrote.

**N2 — untoleranced surveycore-side stored-scale assertions.** `decisions.md`
records one line, 174. There are **three**: lines 174, 379 and 400, all
asserting `sc@variables$scale` against a literal with no `tolerance`, where the
neighbouring `sv$scale` assertion carries `tolerance = 1e-8`. I confirmed all
three are unchanged from the pre-arc baseline `7800ea9`, where they sat at
lines 148, 330 and 351. No numerical risk: each value is a literal from a
`switch()` arm.

**Recommendation: open one issue covering both, before the arc closes.** Not
two. N2 alone is cosmetic and would sit unworked; N1 alone leaves the tidy
undone. One issue titled for the two oldest BRR blocks, with N2's three lines as
a second bullet, is the cheap shape.

The reason to open it rather than leave it recorded is the arc's own thesis. A
test that passes for the wrong reason survives releases because nobody is
looking — issue #242 lasted 22 of them. N1 is exactly that shape: two blocks
that agree today because of a default nobody asserted. `decisions.md` will be
archived, and a finding that lives only in an archived run directory is as
invisible as no finding at all. An issue number is the difference between a
recorded gap and a tracked one.

---

## Decision

PASS. All 18 quality gates of `spec.md` §VIII hold, and I re-measured 13 of
them on the finished tree rather than inheriting them. The three-PR rule
section carries every element gate 10 enumerates plus the two S3 records as
omitted from it, and ships `spec.md` §III.2's text with formatting changes only.
The arc's 72 test-spec rows are allocated once each and every one is reported
in its PR's audit; all nine audits and all eight prior reviews read PASS. No
tolerance was relaxed anywhere in the arc, the write surface is the two files
the spec named and no third, and every suite figure is flat against a baseline
that a documentation-only change cannot move. The `survey`-absent measurement
is sound and the version bump is right.
