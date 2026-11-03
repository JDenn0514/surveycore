# Plan review — domain-marker-logical

**Pass**: 1 of 3 (full panel)
**Date**: 2026-09-12
**Artifact**: `implementation-plan.md` — five PRs
**Verdict**: **FAIL** — 3 REQUIRED findings, 2 suggestions. No BLOCKING finding survived verification.

Five lenses ran in parallel: PR budget, dependency ordering, acceptance
criteria, spec coverage, file completeness.

---

## Lens results

| Lens | Result |
|---|---|
| 1 — PR budget | Clean |
| 2 — Dependency ordering | Clean |
| 3 — Acceptance criteria | 2 REQUIRED, 2 suggestions |
| 4 — Spec coverage | 2 REQUIRED (after verification), 2 withdrawn |
| 5 — File completeness | Clean |

Lens 1 recomputed all ten budget figures from the artifacts. Every stated
figure matches. The five row counts sum to 44, the test-spec total, so every
row is claimed exactly once. PR 2 sits at the 12-row bound and four entries sit
at the 8-criteria bound; none is over.

Lens 2 walked the five merges in order. The suite is green at every boundary:
PR 1 holds the validator and all four existing block repairs together, and no
PR before the `.apply_domain()` change pins a count that change moves. It also
swept the rest of the suite for other marker-column writes and found every one
writes a mask with no `NA`.

Lens 5 confirmed the union of write surfaces holds every file the spec and
test-spec name. It verified that `.apply_domain()` and `.restrict_to_domain()`
both carry `@noRd`, so neither produces an `.Rd` file and neither PR needs a
`man/` entry.

---

## Findings

### F1 — REQUIRED — `.apply_domain()` on a zero-row design has no test row

Lens 4. `spec.md` §`.apply_domain(design)` §Edge cases commits to `logical(0)`
on zero-row design data. `test-spec.md` §3 holds rows 3.1 to 3.8 and none of
them builds a zero-row design. Rows 2.6 and 2.7 build a zero-row frame, but
they test the validator, not the helper's return value.

No decision in `decisions.md` cuts this row. D2 cuts seven functions from §3
and records why; the zero-row case is not among them.

PR 3 carries §3 at 8 rows against a bound of 12, so a ninth row fits.

**Fix**: add row 3.9 to `test-spec.md` §3. Claim it in PR 3. Restate PR 3's
row figure as 9 and the test-spec total as 45.

### F2 — REQUIRED — the `haven_labelled` interaction has no test row

Lens 4. `spec.md` §`survey_base` validator §Edge cases commits to a
`haven_labelled` column over a logical base passing, because the `@data`
setter strips the class before the validator reads the column.

D12 names `haven_labelled` only in passing, as the one class attribute the
setter strips. It settles the matrix case and does not settle this one.

The interaction is new. The setter's stripping is pre-existing and covered by
the haven-labelled arc, but no row anywhere tests the setter and this validator
together, and the validator is what this change adds.

PR 1 carries 11 rows against a bound of 12, so one row fits.

**Fix**: add row 2.9 to `test-spec.md` §2. Claim it in PR 1. Restate PR 1's
row figure as 12.

### F3 — REQUIRED — acceptance criteria bundle several observables under one number

Lens 3. Every entry has at least one criterion that fuses a generic
"N blocks pass" claim with separate per-row claims:

| Entry | Criterion | What it fuses |
|---|---|---|
| PR 1 | 1 | eleven blocks pass; rows 1.1–1.4's condition shape; the `test_invariants()` count |
| PR 2 | 3 | rows 1.11, 2.5 and 2.8, three unrelated assertions |
| PR 3 | 3 | rows 3.7 and 3.8 |
| PR 4 | 1 | five blocks pass; `skip_if_not_installed` placement; rows 5.2/5.4; row 5.3 |
| PR 5 | 4 | four blocks pass; rows 6.3 and 6.4 |

A criterion that names several observables reads as one against the bound of
8, so the bundling is the mechanism by which each entry stays inside it.

**Fix**: rewrite each criterion to name one observable. Where splitting pushes
an entry past 8, fold the generic "N blocks pass" umbrella into the specific
claims rather than carrying both — the umbrella asserts nothing the specific
claims leave out. Report any entry that still cannot reach 8; that entry is
genuinely over-budget and splits.

### F4 — SUGGESTION — two quality gates share one criterion

Lens 3. PR 1 criterion 4, PR 3 criterion 6 and PR 4 criterion 5 each merge
gate 2 and gate 5 into one line. Both gates are checked by reading the same
diff, so the risk is low. Resolve it inside F3's rewrite if the count allows.

### F5 — SUGGESTION — PR 3 asserts a fixture property that pays off in PR 5

Lens 3. PR 3 criterion 4 asserts that `make_domain_pair()`'s `"twophase"`
fixture places an in-domain row outside phase 2. That property exists to make
PR 5's row 4.4 meaningful. The plan justifies the forward dependency under
§Fixture ownership, and the test-spec forbids PR 5 from editing the helper, so
the criterion belongs where it is. Recorded, not actioned.

---

## Findings withdrawn on verification

Lens 4 raised these as BLOCKING. It did not read `test-spec.md` or
`decisions.md`, and both are already settled.

| Raised as | Why it is withdrawn |
|---|---|
| An ordered factor has no test row | **D13 SETTLED**: documented in the edge-case table, not tested. The check is generic and five types already establish it. |
| A one-column logical matrix, or a logical vector carrying another class attribute, has no test row | **D12 SETTLED**: the edge-case table states the check reads storage type only. Rejecting a matrix shape would widen the contract and needs its own row; no current code produces such a column. |

Lens 3 raised a third, that several criteria trace to neither a test-spec row
nor a numbered quality gate: the two `NEWS.md` entries, the design-note
rewrite, the `test_invariants()` count, and the "no file under `R/` changes"
claims. All five trace to `spec.md` §Scope §In, which is the third legitimate
source. The lens prompt named two buckets and should have named three. No
change to the plan.

---

## Routing

FAIL routes to Stage 3. F1 and F2 amend `test-spec.md` and the two PR entries
that claim the new rows. F3 rewrites acceptance criteria across all five
entries. F4 folds into F3. F5 is recorded only.

None of the three REQUIRED findings needs a user decision. Each has one
determinate fix.

---

# Pass 2 — delta

**Date**: 2026-09-14
**Scope**: the sections the pass-1 resolver changed, and nothing else. Two lenses on sonnet, per the review-loop budget.
**Verdict**: **FAIL** — 5 REQUIRED, 3 suggestions. No BLOCKING finding. Nothing structural.

## What verified clean

- **Every budget figure.** All six entries recount exactly: PR 1 at 8 rows and 8 criteria, PR 2 at 4 and 5, PR 3 at 12 and 8, PR 4 at 9 and 8, PR 5 at 5 and 8, PR 6 at 8 and 8. The rows total 46 and the row ledger claims each one exactly once.
- **Rows 2.9 and 3.9.** Both match their section's shape and voice, and the prose distinguishes each from the row a reader would confuse it with — 2.9 against 2.5, 3.9 against 2.6 and 2.7.
- **The gate-binding table.** Gate 1 to PR 5, gates 3 and 4 to PR 1, gate 13 to PR 4 and PR 5. No individually-bound gate is cited in a PR that does not hold the work.
- **§Where PR 1's accept path is proved — the load-bearing claim.** Verified row by row against `test-spec.md` §Existing blocks that change. E.1, E.2 and E.4 each write a logical marker and then assert something downstream that only runs when the write completes, so a validator that wrongly rejected a legal column fails them inside PR 1, and gate 7 catches it. E.3 writes a factor and is correctly excluded from the plan's table. PR 1 does not ship blind.
- **Stale numbering in the plan.** None. `test-spec.md` stays on the spec's three-PR numbering deliberately and says so.

## Findings

| # | Severity | Finding |
|---|---|---|
| R1 | REQUIRED | PR 1 criterion 2 fuses four claims about E.1–E.4, which do not share one assertion shape. The pass-1 bundling defect, recurring. |
| R2 | REQUIRED | §Where PR 1's accept path is proved credits rows 2.1–2.3 and 2.9 in PR 2 with the non-Taylor accept path. All four are Taylor rows; rows 2.4 and 2.8 in PR 3 carry class breadth. |
| R3 | REQUIRED | §How gates appear in the acceptance criteria says gate 2 and gate 5 sit in one folded line across all six entries. PR 2, PR 3 and PR 6 omit gate 5, and PR 6 also omits gate 6. |
| R4 | REQUIRED | D18 says row 3.9 is claimed by PR 3. Section 3 belongs to PR 4. Written against the five-way numbering, never updated. |
| R5 | REQUIRED | D19 says row 2.9 is claimed by PR 1, which now holds 8 rows. Row 2.9 belongs to PR 2. Same cause as R4. |
| S1 | SUGGESTION | PR 6 criterion 4 bundles rows 6.1 and 6.2. The test-spec presents them as a pair. |
| S2 | SUGGESTION | D20 lacks the `**Found by:**` line D17 to D19 all carry. |
| S3 | SUGGESTION | The "no file under `R/` changes" and `test_invariants()` count criteria trace to none of the three sources the plan names. Two reviewers have raised this; the plan should name the fourth source. |

## Routing

FAIL routes to Stage 3. All five REQUIRED findings have one determinate fix and none needs a user decision. R1 must not push PR 1 past 8 criteria — the fix is to reduce the criterion to its one observable, not to split it.

---

# Pass 3 — verification

**Date**: 2026-09-14
**Scope**: the six fixes from pass 2, and regression near them. One lens on sonnet.
**Verdict**: **PASS** — no finding at any severity.

All six fixes landed. PR 1 criterion 2 now carries one observable, and the
`as.integer()` wrapper claim sits with gate 3 where it belongs. The accept-path
section credits PR 2 with rows 2.2, 2.3 and 2.9 and PR 3 with rows 2.4
(replicate) and 2.8 (two-phase), matching both the row ledger and the design
class each row names in `test-spec.md` §2. All six folded gate lines list the
same set, with PR 1 the one documented exception because gate 6 holds its own
line there; no entry omits a gate and none double-counts one. D18 and D19 each
keep the figures true when they were taken and append the PR that holds the row
now. The new §What an acceptance criterion traces to names the fourth source.

Every budget figure re-derived unchanged: 8/8, 4/5, 12/8, 9/8, 5/8, 8/8. Rows
total 46. No bound is broken.

The loop ends here, at pass 3 of a maximum of 3.
