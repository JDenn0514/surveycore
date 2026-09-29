# Review — PR 5 — replicate-scale-release-notes

**Verdict**: PASS
**Date**: 2026-09-29
**Tree**: `44ccbad187069650beb9bb411bec5ba4236d4f68`
**Branch**: `fix/replicate-scale-release-notes`, HEAD `b8feb11`
**Base**: `origin/develop` at `dde0f8a`. Arc base `076bafe` (= `d11d1f8^`).

This PR writes prose only. There is no `implementation.md`: the orchestrator
wrote the PR, because `.claude/agents/builder.md:138` forbids a builder to
modify `NEWS.md`. I judged the tree.

I ran no gate. Every gate figure below is transcribed from the orchestrator's
foreground run at `gates/pr-5/`, whose `summary.md` I read.

---

## Step 1 — Convergence

PR 5 owns `test-spec.md` §4 rows 4.5 and 4.6. Both have rows in the
`audit.md` Per-Test Result Table. The plan's row-coverage table maps all 20
test-spec rows onto the five PRs, each row once.

`implementation-plan.md` PR 5 §Files touched names `NEWS.md` and
`changelog/fix-replicate-scale-jkn-bootstrap.md`.
`git diff --stat origin/develop HEAD` returns those two files and no third:
`NEWS.md` +22, the changelog +141, 0 deletions. `git show --stat b8feb11`
agrees. No gap.

Spec §Quality gates 1 to 14 all have an owner PR and a result. Gate 9 — no
`expect_failure()` wrapper and no ratio assertion in either oracle block — I
re-measured myself, below.

---

## Step 2 — Tolerance integrity

`test-spec.md` §Tolerances maps a stored `scale`, a ratio of two stored
scales and a ratio of two standard errors to the SE row, `1e-8`. `audit.md`
reports `1e-8` on both of its numeric rows — the `(R-1)/R` variance-ratio
identity and the measured SE ratio — and `exact` on every text row. No row is
looser than the test-spec. No violation.

---

## Step 3 — Scope discipline

Write surface matches the plan exactly. No extra file, no missing file.

Nothing in this PR is an act a builder would have been stopped from doing.
The PR writes no code, no test, no spec and no `man/` file, and it touches no
file under `tests/`. `NEWS.md` is the orchestrator's by rule. The changelog
was not forbidden to a builder, but its content — the arc-wide suite counts
and coverage figures — was measurable only by the agent that ran the gates.

The working tree carries six uncommitted files under `plans/`. They are the
run's planning documents, staged for archive. None is in HEAD and none is in
this PR.

---

## Step 4 — CRAN cookbook and profile gates

`audit.md` §CRAN cookbook violations reads "None", and the verdict is PASS.
The PR modifies no file under `R/`, so the scan has no surface. That skip is
documented and allowed.

All seven profile gates carry a result. `gates/pr-5/summary.md` reads
`ALL GATES PASS`, `EXIT=0`, on the same tree hash.

Two gate readings are interpreted, and both interpretations are documented in
`test-spec.md` §How to read three gates:

- `devtools::test()` gives `WARN 256`. The 256 are pre-existing AAPOR
  small-cell warnings. The gate reads as "no new warning", and the count is
  identical at the base.
- `air format --check` is not among the seven. The PR touches no `.R` file,
  so the formatter has no surface.

---

## Step 5 — Coverage

`gate-7-covr.log` gives `COVERAGE_PCT=96.15`, identical to the base. The
floor is 95%. The PR adds no line under `R/`, so no new line can be
uncovered. Clean.

---

## Step 6 — Comprehension alignment

`comprehension.md` §Gotchas holds G1 to G11. Each reaches `spec.md`, and
each that can be tested reaches `test-spec.md`:

| Gotcha | Where it lands |
|---|---|
| G1 `rscales = NULL` loses the factor | `spec.md` E5; `test-spec.md` 1.5; the changelog's §The E5 window |
| G2 `rscales` shape unchecked | `spec.md` E6; `test-spec.md` 1.2 |
| G3, G4 the fixture is not a jackknife family | `test-spec.md` §What the oracle rows prove |
| G5 `R = 1` gives `Inf` | `spec.md` E1; `test-spec.md` 1.3, 2.3 |
| G6 `NA` replicates do not re-derive `scale` | `spec.md` §Edge cases, recorded as pre-existing, out of scope with a reason |
| G7 zero `rscales` with `mse = FALSE` | same, recorded as pre-existing |
| G8 `fpc` cannot reach the factor | `spec.md` F-7, RS-1, FP-1; `test-spec.md` 4.1 |
| G9 the two constructors diverge | `spec.md` F-8 and D1's note; `test-spec.md` 3.2, 4.2 |
| G10 no `bootstrap.average` | `spec.md` F-5, corrected against `measurements.md` M4 |
| G11 one stratum hides the defect | `spec.md` §Why `1` is right for JKn, point 2 |

No gap.

---

## Step 7 — Independent verification of the two documents

I checked each claim against the merged tree, not against the other document.

### The before/after table

| Claim | Measured | Verdict |
|---|---|---|
| JKn before `(R-1)/R` | `git show 076bafe:R/core-constructors.R` — `JKn = (n_rep - 1L) / n_rep` | true |
| JKn after `1` | `R/core-constructors.R:851` — `JKn = 1` | true |
| bootstrap before `1/R` | at `076bafe` — `bootstrap = 1 / n_rep` | true |
| bootstrap after `1/(R-1)` | `R/core-constructors.R:861` — `bootstrap = 1 / (n_rep - 1L)` | true |
| `survey` column `1` and `1/(R-1)` | `.claude/rules/testing-surveycore.md` per-type table, `survey` 4.5 | true |
| `as_survey_nonprob()` column `1` and `1/R` | `R/utils.R:1184` — `switch(type, bootstrap = 1 / R, JK1 = (R - 1) / R, JK2 = 1, JKn = 1)` | true |
| "the other seven replicate types are unchanged" | the arc diff of the switch changes two lines and no third | true |
| "both old defaults multiplied the variance by `(R-1)/R`" | JKn `((R-1)/R) / 1`; bootstrap `(1/R) / (1/(R-1))`; both `(R-1)/R` | true |

### `sqrt(19/20)` to the digit

Computed here, R 4.6.1:

```
sqrt(19/20)   = 0.97467943448089633
1/sqrt(19/20) = 1.02597835208515420
fall = 2.5321%      rise = 2.5978%
```

The changelog claims a measured ratio of `0.97467943448089656` against
`sqrt(19/20) = 0.97467943448089633`. The second figure matches my
computation digit for digit. The first traces to PR 1's `implementation.md`
line 140 and to PR 1's `review.md`, where it was measured on the arc fixture.
The two differ at the 16th digit, which is one ulp. The claim is supported.

The changelog's "about 1.8e-15" drift on a real-valued frame traces to
`measurements.md:64` (`1.776e-15`) and to PR 4's `review.md`, which
reproduced it at `1.776357e-15`. Supported.

### The percentage directions

| Figure | Every place it appears | Direction | Verdict |
|---|---|---|---|
| 2.6% | `NEWS.md:152`; `changelog/...:23` | the rise | correct |
| 2.5% | `R/core-constructors.R:1363` → `man/as_survey_nonprob.Rd:125`; `changelog/...:79`, which describes that note | the fall | correct |

`man/as_survey_replicate.Rd` carries neither figure, which is what
`test-spec.md` row 4.1 fact 8 requires. `NEWS.md` carries no 2.5% and the
nonprob help page carries no 2.6%. Each figure is in exactly one shipped
place and points the right way.

Note for a later grep: the `.Rd` escapes the sign, so the string is `2.5\%`.
A search for `2.5%` in `man/` returns nothing and is not evidence of absence.

### The E5 window

The changelog says `type = "JKn"` with `rscales = NULL` now stores
`scale = 1`, keeps `rscales = NULL`, and that the variance path reads a
`NULL` `rscales` as `rep(1, R)`, so no jackknife factor enters.

`R/variance-replicate.R:92` and `:210` both read
`if (!is.null(vars$rscales)) vars$rscales else rep(1L, n_rep)`. The
substitution is real, and with `scale = 1` the expression is an unweighted
sum of squared deviations. Before the change the same input carried
`(R-1)/R`. Every element of the section is true.

One wording nuance, not a defect. The changelog writes "`survey` refuses the
input outright". `.claude/rules/testing-surveycore.md` scopes the refusal to
JKn with combined weights and no `rscales`. surveycore's replicate weights
are combined weights, so the refusal does reach the input under discussion.
The sentence is inherited verbatim from `spec.md` E5.

### Row 4.5 — the sweep

Swept by file name against the arc base `076bafe`, as decisions item 3
requires, because every PR merged by squash.

`git diff --name-only 076bafe HEAD` gives nine files:

```
NEWS.md
R/core-constructors.R
changelog/fix-replicate-scale-jkn-bootstrap.md
man/as_survey_nonprob.Rd
man/as_survey_replicate.Rd
tests/testthat/test-analysis-corr.R
tests/testthat/test-constructors.R
tests/testthat/test-nonprob-bootstrap-variance.R
tests/testthat/test-variance-replicate.R
```

Four are under `tests/`, and they are E-2's four. The list is right.

Snapshots, measured at each of the five arc commits separately rather than as
a range:

| Commit | `_snaps/` files changed |
|---|---|
| `d11d1f8` | 0 |
| `e727001` | 0 |
| `5e7a7f9` | 0 |
| `dde0f8a` | 0 |
| `b8feb11` | 0 |

Zero at every commit. The changelog's closing claim holds.

The changelog's §Files Modified lists exactly those nine files. It matches.

### Gate 9, re-measured

I did not count with `grep -c`. I parsed
`tests/testthat/test-variance-replicate.R` with `parse()` and walked the
call tree: **0 real `expect_failure()` calls remain**. The two textual hits
at `:812` and `:869` are comments that record the history. Both block titles
now read "matches" where they read "disagrees". Both closing ratio
assertions are gone. Eight deleted lines, six assertions now unwrapped —
exactly as both documents claim.

---

## Findings

Two, neither blocking, neither a defect in PR 5.

**F1 — `.claude/rules/testing-surveycore.md` is now stale, and it is the one
document this arc left carrying a false statement about the repository.**
Lines 301 to 307 say "Two blocks in that file break the rule's normal shape
on purpose" and then describe the JKn and bootstrap blocks as wrapping three
failing assertions each. Both sentences were true at the arc base and are
false at HEAD. One sanctioned exception remains, the Fay block.

The changelog states the fact correctly — "this clears one of the two … not
both" — so nothing a user reads is wrong. The staleness sits in a rule file
that auto-loads into every agent's context, so a later agent will read that
two oracle blocks are deliberately wrong when only one is. `spec.md`
§Files touched excludes the file from the write surface and §Out does not
list the correction as deferred, so no artifact schedules it. This is a
planner omission, not a builder or orchestrator one. Correcting it inside PR
5 would breach the plan's own two-file surface, so it belongs to a follow-up
issue and not to this PR.

**F2 — "the two pre-approved notes" overstates one of the two.**
The changelog's verification list says `R CMD check --as-cran` gives "the two
pre-approved notes throughout". `gate-5-check.log` shows the two NOTEs are
"checking CRAN incoming feasibility" and "checking for hidden files and
directories" — the `.git` note. `.claude/rules/r-package-conventions.md`
pre-approves the first and "no visible binding for global variable", not the
second. The `.git` note is pre-existing, is caused by `.Rbuildignore`, is
identical at the base, and is recorded in
`archive/as-svydesign-bridge/` as a known recurrence. The check result is
clean; only the label is loose. Internal document, not user-facing.

---

## Closing judgement on the arc

**Does the shipped work deliver what `spec.md` set out to do?** Yes. The two
switch lines moved, and no third line in the switch moved. All four roxygen
edits shipped and both help pages regenerated. The eight lines came out of the
two oracle blocks and the six assertions pass unwrapped. The stored-default
tests, the nine-type table, the frame edges, the two-phase inheritance, the
`Inf`/`NaN` pair and the cross-constructor divergence all landed. The
migration note and the changelog carry every element their specs name. Suite
`FAIL 0` throughout, warnings pinned at 256 at every PR, coverage 96.15% at
every PR against a 95% floor.

**Should any of the nine errata have been a STOP?** No. Each of the nine
records an artifact that was wrong or unreachable, and in every case the
correct behaviour was undisputed. E-1 and E-2 are the closest call: they
widened the write surface from seven files to nine after the work started,
which is the shape of scope creep. They are not scope creep, because the two
extra files hold blocks asserting an identity that quality gate 6 sets out to
break. The user ruled option A on the record, and the widening was recorded
before PR 5 ran rather than discovered by it. E-9 is the one I would have
argued hardest, since substituting a 40-row seeded frame for a prescribed
four-row literal changes the fixture a tolerance rests on — but the arc paid
for that with a structural argument (every partial sum an exact integer well
under 10,800) and PR 4's reviewer reproduced the drift that the substitution
avoids. That is stronger evidence than the literal would have carried.

**Is any shipped claim unsupported by measurement?** No claim on a help page,
in `NEWS.md` or in the changelog is false. I checked every number: the
before/after table, both percentage directions, `sqrt(19/20)` to 17 digits,
the measured SE ratio, the `1.8e-15` drift, the nine-file list, the eight
deleted lines and the zero snapshot changes. Two claims are weaker than they
read, and both are named above: "`survey` refuses the input outright" is
scoped in the source rule, and "the two pre-approved notes" covers one
pre-approved note and one tolerated pre-existing note. Neither is on a help
page and neither reaches a user.

**What a reader of the archived arc most needs warned about.** I agree the
closed-count pattern is the arc's central process finding: six of the nine
errata are a count, list or fixture fixed in one artifact and addressed to a
reader forbidden to open it, and E-9's stated rule — a plan task addressed to
the builder must transcribe every closed value it requires — is the right
correction. I would add one sentence that the arc's own record does not make
loud enough: **the arc changed a published standard error and shipped no
runtime signal, by an explicit and defensible decision recorded in `spec.md`
§A runtime transition signal was weighed and declined, so a user who upgrades
and sees a 2.6% move has only `NEWS.md` to explain it.** That is the claim a
later reader is most likely to mistake for an oversight, and it is the one
place where the arc's correctness depends entirely on prose that this PR
wrote.

---

## BLOCKs

None.
