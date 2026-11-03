# Review — PR 3 — replicate-scale-frame-and-type-tests

**Verdict**: PASS
**Date**: 2026-09-29 00:00

Branch `fix/replicate-scale-frame-and-type-tests`, HEAD `7c8d524`, tree
`238d54252846e5db73b623fa9114703a3bffd65c`. Base `origin/develop` at
`e727001`. Rows judged: §1 rows 1.6, 1.7, 1.8, 1.9, under errata E-5, E-6
and E-7 (all SETTLED). No gate was run by this reviewer.

## Convergence checks

- Spec coverage: **y**
- Test coverage of spec: **y**
- Tolerance integrity: **y**
- Scope discipline: **y**
- Regression safety: **y**

### Spec coverage — what PR 3 owns, and where each item lands

| `spec.md` item | test-spec row | shipped block | audit row |
|---|---|---|---|
| §Default scale table, all nine After values | 1.7 | line 973 | Row 1.7 |
| §Edge cases E7 — frame shape does not reach the default | 1.6 | line 865 | Row 1.6 |
| §Edge cases E7 — all-`NA` outcome column is an ordinary frame | 1.8 | line 1008 | Row 1.8 |
| §Errors and warnings — four refusals ahead of the switch | 1.6 | line 903 | Row 1.6 |
| §Edge cases E7 — mixed zero weight is a refusal | 1.8 | line 1048 | Row 1.8 |
| §Errors and warnings — the sixth class E-7 adds | 1.6 (E-7) | line 903 | Row 1.6, refusal 5 |
| §Behaviour rules, rule 8 — two-phase inherits `phase1$scale` | 1.9 | line 1613 | Row 1.9 |

No item in this PR's slice of `spec.md §Function contracts` is without a
test-spec row, a shipped block and an audit row. No shipped block lacks a
spec item behind it.

### Scope discipline

Re-derived, not taken on report:

- `git diff --name-only e727001..HEAD` → one path,
  `tests/testthat/test-constructors.R`. `--stat` → +260 / −0.
- `git rev-parse e727001:R HEAD:R` → `164f0348ba796fb5af5192b8b8cd6a3d260f0099`
  on both sides. The `R` subtree is byte-identical, so no `R/` line moved.
- Both commits are test-only: `bb85ca5` +209, `7c8d524` +52 / −1, each on
  the one file. The plan's Files touched for PR 3 names that one file and
  nothing else. No extra file, no missing file.
- No path under `tests/testthat/_snaps/` appears in either commit. The CRLF
  churn `implementation.md` §Verification reports was reverted before the
  commit, and the tree confirms it.
- Regression: failures 0 → 0, warnings 256 → 256, skips 4 → 4, passes
  12028 → 12065. No test outside this PR's scope changed state.

### Tolerance integrity

- Row 1.9 is the only row whose Assert column names a tolerance. It names
  `1e-8`, and both of its scale assertions carry `tolerance = 1e-8` in the
  source at lines 1649 and 1651-1655. Read in the file, not inferred.
- Rows 1.6, 1.7 and 1.8 name no tolerance in their Assert columns. Their
  assertions are bare `expect_equal()`, which is what E-5's settled
  tolerance ruling directs: write `tolerance =` where the row's Assert
  column names it, leave it bare where only the §1 preamble maps the
  quantity to a band.
- No row reports a tolerance looser than `test-spec.md` specifies. No
  Tolerance Integrity violation.

## Cross-consistency notes

`implementation.md` and `audit.md` were written without sight of each
other. They agree on every checkable fact, and I re-derived the load-bearing
ones against the worktree rather than against either document.

| Fact | implementation.md | audit.md | Worktree |
|---|---|---|---|
| Write surface | one test file, +260 / −0 | same | same |
| `R` subtree hash | `164f0348…` | `164f0348…` | same |
| `test_invariants()` count | 4 | 4 | 4 |
| `_snaps/` changed | none | none | none |
| Full suite | `FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 12065` | same | — |
| Row 1.6 blocks | assertions at 899, 900 | block at 865, refusals at 903 | 865 and 903; assertions at 899, 900 |
| Row 1.7 block | assertions at 999, 1002 | block at 977 | block at **973**; assertions at 999, 1002 |
| Row 1.8 blocks | assertions at 1042, 1043 | blocks at 1013 and 1055 | blocks at **1008** and **1048** |
| Row 1.9 block | assertions at 1649, 1650 | block at 1613 | block at 1613; assertions at 1649, 1651 |

Every assertion line number `implementation.md` cites resolves to exactly
the assertion it names. The audit's three block-header numbers each sit
4 to 7 lines below the real `test_that(` line — the tester quoted the first
line of the block body rather than the header. It names the right blocks and
the right assertions, so this is a citation offset and not a disagreement.

One genuine difference of provenance, and it is the good outcome. Erratum
E-6 sent the builder to `spec.md` §Default scale table for row 1.7's nine
values, because the builder's contract forbids `test-spec.md`. The builder
records that source. The tester records checking the same nine values
against `test-spec.md` §What this work changes. **Two artifacts, two
readers, nine values, no disagreement.** I checked the shipped block against
both tables independently:

| `type` | `spec.md` After | `test-spec.md` | Block, line 999-1007 |
|---|---|---|---|
| `JK1` | `(R - 1) / R` | `(R - 1) / R` | `(n_rep - 1L) / n_rep` |
| `JK2` | `1` | `1` | `1` |
| `JKn` | `1` | `1` | `1` |
| `BRR` | `1 / R` | `1 / R` | `1 / n_rep` |
| `Fay` | `1 / R` | `1 / R` | `1 / n_rep` |
| `bootstrap` | `1 / (R - 1)` | `1 / (R - 1)` | `1 / (n_rep - 1L)` |
| `ACS` | `4 / R` | `4 / R` | `4 / n_rep` |
| `successive-difference` | `4 / R` | `4 / R` | `4 / n_rep` |
| `other` | `1` | `1` | `1` |

Nine for nine, against both sources. The block pins `n_rep` at `20L` with
`expect_identical()` before it uses it, so a generator change surfaces as one
named failure and not as nine wrong literals. E-6's substitution cost the row
nothing.

## Ruling — the two-row substitution (E-7 correction 1)

**The two-row block is load-bearing. The substitution cost row 1.6 nothing.**

Two reasons, the first decisive.

1. **A one-row frame observes no behaviour at all.** `.validate_data()`
   Error 4 at `R/core-validators.R:100-112` refuses `nrow(data) == 1L`
   before any type branch, so there is no stored scale on a one-row frame
   for any assertion to read. The frame row 1.6 and criterion 1 asked for
   could not have caught anything, because the construction it asked for
   does not complete. Nothing was traded away.
2. **The block carries a differential that row 1.1 does not.** Row 1.1's
   frame is 200 rows at R = 20; this frame is 2 rows at R = 20. Same R,
   different `nrow`. A defect that made the default depend on the row count
   would leave row 1.1 green and turn this block red. That is a real, if
   narrow, second defect class, and it is the exact property the row exists
   to state: the default reads `type` and R and reads nothing else.

The builder's mutation check confirms the block can fail: lines 899 and 900
redden one per switch line and do not overlap, so neither assertion is
vacuous. I did not re-run it; the claim is structurally sound, because each
assertion compares a stored scale against a literal expression in `n_rep`
and never against another stored value.

## Ruling — the fifth refusal (E-7 correction 2)

Asked plainly: **is a second single-row block at a different `type` real
coverage or decoration? It is decoration, in coverage terms. Keep it anyway,
and correct the comment that defends it.**

- The guard is `.validate_data()` Error 4. Its condition is `nrow(data) ==
  1L` and its body mentions no type. `as_survey_replicate()` calls
  `.validate_data()` before it reaches the scale switch. So the new
  assertion at line 936 and the pre-existing block at line 1186 execute the
  same lines. Line coverage gained: zero.
- **The builder's stated reason is wrong.** The comment at lines 928-930
  reads: "`.validate_data()` raises Error 4 ahead of the switch, so the
  single-row refusal does not depend on `type`. The JK1 block below reaches
  the same guard from the other type; neither block repeats the other's
  coverage." The first sentence is true and it refutes the third. If the
  refusal does not depend on `type`, then the two types are not
  distinguishable inputs for this guard, and the two blocks do repeat each
  other's coverage exactly. The clause contradicts the sentence before it.
- **The block still stays**, on the ground E-7 actually gives: it completes
  the inventory of refusals that fire ahead of the switch, in validator
  order, in one place. `spec.md` §Errors and warnings listed five classes
  and called them exhaustive; it was short by this one. A reader who opens
  the refusals block now meets all five without having to know that a sixth
  lives 280 lines away in a different section of the file.

**Action, not a BLOCK:** the last clause of that comment should read that
the two blocks reach one guard and the new one exists to complete the
refusal inventory. PR 4 already writes this file; folding in a one-line
comment correction there is cheaper than a builder round trip for PR 3, and
this review authorises it so PR 4's reviewer does not read it as scope creep.

## Findings — recorded, none blocking

- **F-1 — the fifth refusal's comment contradicts itself.** Above. Correct
  the clause; do not delete the block.
- **F-2 — `audit.md` mislabels the bare tolerance.** Rows 1.6, 1.7 and 1.8
  carry "default 1e-10" in the Tolerance column. testthat's bare
  `expect_equal()` default is `1.49e-8`, not `1e-10`; `1e-10` is the
  point-estimate row of the tolerance table, which no assertion here uses.
  This is a reporting error and not a relaxation: the assertions are bare in
  the source, which is what E-5's settled ruling directs, and E-5's measured
  argument covers the band — the real gaps are `0e+00` when correct and
  0.05 or 0.0026 when wrong, four orders clear of either bar. No Tolerance
  Integrity violation. A later reader of `audit.md` should not take `1e-10`
  as the bar that was met.
- **F-3 — `air format --check` has no result in `audit.md`.** Plan AC-8 and
  `spec.md` gate 14 both name it. It is not one of the seven gates in
  `r-package-profile.md`, so the profile-gate table is complete as it
  stands, and every gate there has a result. The builder did measure it and
  reported the outcome: the file fails, it failed the same way at `e727001`,
  and of the 28 formatting hunks none falls inside the PR's added ranges
  865-1055 and 1613-1658. That is the arc's settled reading of the gate —
  "no new formatting breach", matching `archive/svydesign-replicate-bridge/`
  D16. Record the measurement in `audit.md` on the next PR rather than
  leaving the criterion unjudged.
- **F-4 — one more stale line number, of E-5's shape.** `implementation.md`
  cites the two-phase copy at `R/core-constructors.R:1199`; `spec.md`
  behaviour rule 8 and the plan cite `:1151`. The builder's number is the
  correct one — line 1198-1199 is `variables <- list(` / `phase1 =
  phase1@variables,`. Same 48-line shift E-5 records from PR 1's roxygen.
  Not a conflict between the two artifacts; the plan is the stale side.

## Profile gates and coverage

All seven gates carry a result in `audit.md §Profile gates`, and each
matches `gates/pr-3/summary.md`.

- pkgdown SKIPPED. Allowed: `r-package-profile.md` §pkgdown skip condition
  permits it when the write surface touches no `R/` file, no `man/`, no
  `NAMESPACE` and no `_pkgdown.yml`. This PR touches one test file. The hard
  rule — no skip when exports change — is not engaged: the `R` subtree hash
  is byte-identical, so no export moved. Documented skip, allowed skip.
- covr 96.15%, base 96.15%, delta 0.00. The 95% floor is clear by 1.15
  points. The 98% target is unmet before and after, and this PR neither
  causes nor widens the gap. **No coverage regression in new lines is
  possible here**: the PR adds no line under `R/`. The log's "changed R/
  files: 1" and its three uncovered lines in `R/core-constructors.R` are the
  stale-ref artifact the dispatch flags — I confirmed the subtree hash
  independently, and all three lines (414, 1868, 1959) are pre-existing.
- `R CMD check --as-cran`: 0 errors, 0 warnings, 2 NOTEs, the same two as
  base, both on the pre-approved list of
  `.claude/rules/r-package-conventions.md`.
- CRAN cookbook violations: None, and the audit verdict is PASS. Consistent.

## Comprehension alignment

`comprehension.md` exists for the arc. No gotcha in it bears on rows 1.6 to
1.9 without already being reflected in `spec.md` §Edge cases E7, §Default
scale table or behaviour rule 8. Its nearest items — the `rscales = NULL`
window (G1, deferred to #255) and the `fpc` refusal (G8, deferred to #251) —
are both explicitly out of scope in `spec.md §Out` with a named owner. No
gap.

## Decision

PASS. All seven checks are clean: every spec contract in PR 3's slice has a
test-spec row, a shipped block and an audit row; no tolerance is looser than
`test-spec.md` specifies; the write surface is the plan's one file across
both commits with a byte-identical `R` subtree; the CRAN cookbook table
reads None against a PASS audit; coverage holds at 96.15% with no new `R/`
line to regress; and `audit.md` reads PASS with no BLOCK and no HOLD. The
four findings above are reporting and comment defects with no effect on what
the suite asserts, and none is traceable to a missing spec contract or a
missing implementation detail.

---

## Forward look — what PR 4 must know

PR 4 writes `R/core-constructors.R`, `man/as_survey_nonprob.Rd`,
`tests/testthat/test-variance-replicate.R` and
`tests/testthat/test-constructors.R`. Nothing in PR 3 constrains it, and six
things make it cheaper.

1. **The switch lines are still `:851` and `:861`.** I read them:
   `JKn = 1,` at 851 and `bootstrap = 1 / (n_rep - 1L),` at 861. PR 3 moved
   no `R/` line, so E-5's correction carries into PR 4's mutation checks
   (steps 5 and 8) unchanged. Confirm the line content before editing, as
   E-5 directs.

2. **PR 4's own roxygen target is stale by the same shift.** The plan's task
   10 says `R/core-constructors.R:1306-1311` for the `as_survey_nonprob()`
   `@details` paragraph. It is at **`:1354-1359`** today — the `@details`
   block opens at 1339 and the Wu (2022) / Chen et al. (2021) sentence is at
   1357. Line 1306 holds unrelated text. Carry the corrected range in the
   dispatch. This is E-5's shape a fourth time and should be recorded as
   such in `decisions.md`.

3. **AC-4's duplication — confirmed as no re-scope, and revised.** PR 2's
   reviewer found AC-4 duplicating an assertion PR 1 shipped and ruled for a
   cross-reference comment. Confirm the ruling; the picture is larger than
   it looked, in a way that strengthens rather than weakens it.

   The duplication is **two-sided, not one-sided**. Both of AC-4's literal
   halves are already asserted somewhere:

   | AC-4 half | Already asserted at |
   |---|---|
   | replicate bootstrap stores `1 / (n_rep - 1)` | line 676 (PR 1's retarget), 728-741 and 790-801 (PR 2), and now 900, 1002, 1043, 1650 (PR 3) |
   | nonprob bootstrap stores `1 / n_rep` | line 2482, pre-existing, `expect_equal(d@variables$scale, 1 / 4)` |

   What AC-4 adds that exists nowhere is the **pairing on one frame** and the
   **SE ratio `sqrt((n_rep - 1) / n_rep)`**. That ratio needs both designs in
   hand, and the two literals are the control halves it rests on. Dropping
   either would leave the ratio free-floating. So: **no re-scope, write AC-4
   as specified.** Revise only the cross-reference — it should name two
   anchors, not one: line 1002 (the nine-type table, the canonical single pin
   of the replicate side) and line 2482 (the nonprob side). Naming PR 1's
   block at 676 alone now points at the weaker of the replicate anchors.

4. **Do not copy the JK2 block at line 652 as the template for row 3.1.**
   That pre-existing block asserts
   `expect_equal(d_rep@variables$scale, d_np@variables$scale)` — one side
   against the other, with no literal anywhere. `test-spec.md` §The oracle
   rule's further constraints forbid exactly that shape: "Never assert one
   side's stored scale against the other side's. Assert each against a
   literal." Row 3.1 is the JKn analogue of that block and a builder will
   find it first. AC-3 is written correctly (equality **and** each equals
   `1`); the risk is the template, not the criterion. Say so in the dispatch.

5. **The scope check for PR 4 is not the one PR 3 used.** PR 3's cleanest
   scope evidence was a byte-identical `R` subtree hash. PR 4 writes
   `R/core-constructors.R` legitimately, so that test will fail by design.
   The right check is that the `R/` diff touches the `@details` paragraph
   only and leaves lines 851 and 861 untouched — which is what the plan's
   task 9 asks for, stated in terms that survive the change.

6. **AC-7's `air format --check` clause is unmeetable for
   `tests/testthat/test-constructors.R` as written**, exactly as PR 3 found:
   the file fails at base with 28 hunks, and PR 4 adds rows 3.1 and 3.2 to
   it. Read the gate as "the PR's added ranges introduce no new hunk", have
   the builder measure hunks-inside-added-ranges, and have the audit
   **record the result** — PR 3's did not (F-3).

Two standing cautions carry into PR 4 unchanged. Never count constructs in
`tests/testthat/test-variance-replicate.R` with `grep -c`: that file names
its own constructs in comments and titles, so `expect_failure` reads 12
against 6 real calls and `svrepdesign` reads 18 against 14. And PR 4's new
blocks add no `test_invariants()` call in either file — the counts stay at 4
and 1. PR 3 left `test-constructors.R` at 4, and its two-phase block sits
after the block that holds the file's single `as_survey_twophase()`
invariants call, which is the correct placement; PR 4 should not disturb it.
