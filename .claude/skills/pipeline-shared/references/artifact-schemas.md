# Artifact Schemas

Every `.md` artifact in the workspace follows a fixed schema. Orchestrating skills validate these sections before advancing state.

## `request.md`

```
# Request — {slug}

## Intent
{1–3 sentences: what the user asked for}

## Acceptance criteria
- {bullet list of observable outcomes}

## Attachments
- {any papers, PDFs, external references the user provided}
```

## `impact.md`

```
# Impact — {slug}

## Estimated scope
- Files touched: {count and list}
- Exported functions added/changed: {list}
- New dependencies: {list or "none"}
- CRAN-relevant: {yes/no — DESCRIPTION change, export change, new vignette}

## Smallness test (criteria: pipeline-simplified/SKILL.md §Smallness criteria)
- Result: eligible-simplified | full-required
- Rationale: {one sentence}
```

## `comprehension.md` (methods-heavy only)

```
# Comprehension — {slug}

## Problem
{one paragraph in your own words}

## Formulas
{restated math; bind symbols to args/columns}

## Gotchas
- {edge case} — {what to watch for}

## Reference mapping
- {paper/package} §{section} → {design decision}

## Assumptions
- {implicit constraint} — {why it matters}
```

## `spec.md`

```
# Spec — {slug}

**Status**: DRAFT | METHODS_REVIEWED | SPEC_READY
**Target version**: X.Y.Z.9000
**PR range**: PR n–m

## Scope
### In
### Out

## Architecture
- Files touched: {list}
- Functions added: {signatures}
- Functions modified: {signatures}
- Class changes: {list or "none"}

## Function contracts
For each function:
### `fn_name(args)`
- **Signature**: {full signature}
- **Arguments**: each with semantics, NULL behavior, valid range
- **Returns**: class, shape, columns, attributes
- **Errors**: one row per named error class (see plans/error-messages.md)
- **Warnings**: one row per named warning class
- **Edge cases**: empty, single-row, all-NA, degenerate — behavior specified

## Quality gates
- {invariants that must hold}

## Pipeline tier
recommended | optional — {justification}
```

No test cases. No tolerances. No references to test-spec.md.

## `test-spec.md`

```
# Test-spec — {slug}

## Reference oracle
- {package/function/version}

## Datasets
- {dataset → purpose}

## Per-function test plan
### `fn_name`
- **Happy path**: {scenario, dataset, oracle call, tolerance}
- **Error paths**: one row per named error class
- **Edge cases**: one row per edge case from spec
- **Invariants**: `test_invariants(design)` once per constructor per file
- **Input modes**: name a mode per row only where the mode changes the answer

## Tolerances
- Point estimates: 1e-10
- SE / variance: 1e-8
- CI bounds: 1e-6
- Deviations (with justification): {list}

## Profile gates
- [ ] devtools::document() clean
- [ ] devtools::test() all pass
- [ ] devtools::run_examples() all pass
- [ ] R CMD check --as-cran (0 err, 0 warn, notes reviewed)
- [ ] pkgdown::build_site() clean
- [ ] covr::package_coverage() ≥ 95% (target 98%)
- [ ] CRAN cookbook scan clean (see r-package-profile.md)
```

No implementation hints. No file paths from `R/`.

## `implementation-plan.md`

```
# Implementation plan — {slug}

## PR map
- [ ] PR 1: feature/{branch-slug} — {one-line goal}
  - **Budget** — {n} test-spec rows | {n} criteria (see §PR budget)
  - **Tasks** — TDD sub-steps explicit
    1. Write failing test for {behavior}
    2. Implement {function}
    3. Verify test passes
    ...
  - **Acceptance criteria** — observable outcomes before merge
  - **Files touched** — exact write surface
  - **Pipeline tier**: recommended | optional
- [ ] PR 2: ...
```

### PR budget

Every PR entry states both figures, and both hold:

| Figure | Bound | How to count |
|---|---|---|
| Test-spec rows covered | 12 | The rows in `test-spec.md` this PR's acceptance criteria satisfy. Cite each by section and row. |
| Acceptance criteria | 8 | One per criterion the entry lists. |

A PR past either bound is **over-budget**, and splits before the plan reaches
PLAN_READY.

Both figures are recomputable from the artifacts — row count by cross-reference
to `test-spec.md`, criteria by counting the entry. Neither is an estimate.

Where the bound comes from: on the haven-labelled arc the row count ranks PR
size with Spearman rho 0.964 against hand-written additions.

| PR | Rows | Hand-written additions |
|---|---|---|
| #189 | 3 | 97 |
| #193 | 9 | 230 |
| #196 | 10 | 274 |
| #194 | 29 | 353 |
| #191 | 13 | 743 |
| #201 | 29 | 868 |
| #190 | 32 | 1236 |

The bound sits at 12 because the gap between the small PRs and the large ones
falls between 10 and 13 rows. Additions per row range from 12 to 57, so the row
count orders PR size reliably and predicts it only loosely.

Three measures are not budget figures. File count does not discriminate size:
PR #201 (868 additions) and PR #221 (124 additions) each touch the identical
four hand-written files. An estimated line count ran 2.5x to 6x under the real diff
across five trial plans. A task count tracks how coarsely the tasks are
written, not how large the PR is.

### PR budget calibration ledger

`plans/pr-budget-calibration.md` holds one row per merged PR. pipeline-ship
appends to it at Step 3, after the merge, when the real diff is knowable.

```
| Merged | PR | Rows | Additions | Adds/row | Tester BLOCKs | Reviewer BLOCKs | Follow-up fixes |
|---|---|---|---|---|---|---|---|
| 2026-09-08 | #241 | 9 | 232 | 25.8 | 0 | 1 | — |
```

The two BLOCK counts come from this run's own counters — Step 2c for the tester,
Step 2e for the reviewer. `Follow-up fixes` cannot be known at merge time, so it
starts as `—`.

Additions count the hand-written surface only, with the same exclusions as the
budget table above. Read them from the merge commit:

```bash
git diff --numstat "{merge_sha}^1" "{merge_sha}" -- R tests \
  ':(exclude)tests/testthat/_snaps' | awk '{a += $1} END {print a+0}'
```

The bound of 12 rests on seven PRs from one feature. Once the ledger holds 20
rows, re-derive it: sort the rows by additions, find the row count where the
small and large PRs separate, and set the bound there. Write the new figure and the
date into the budget table above, replacing the haven-labelled calibration.

Backfill `Follow-up fixes` first. For each ledger PR, count the later merged PRs
that name it:

```bash
gh pr list --state merged --limit 100 --json number,title,body --jq '.[] | select((.title + .body) | test("#241")) | .number'
```

The search also catches bookkeeping mentions: #204 and #227 both name #194
while only archiving plans. Count a follow-up fix only when the later PR
changed behaviour the ledger PR shipped.

### What the BLOCK columns are for

They test the premise the budget rests on: that a PR inside the bound draws
fewer BLOCKs and fewer follow-up fixes than one past it.

Size and rework do correlate on surveycore PRs drafted before any bound existed
— across 38 merged PRs, Spearman rho 0.575 between additions and commit count,
and 93% of the PRs over 400 additions needed a second commit against 35% of
those under it. That is correlation on PRs nobody sized deliberately, and commit
count is a proxy for rework rather than a defect count.

Two effects pull in opposite directions as the PR count rises. Each PR gets
smaller, so a reviewer holds less at once. But splitting finer makes cross-PR
coupling more likely — the failure in issue #165, where PR 3 shipped a helper
vocabulary that PR 6 needed and could not repair, because the file sat outside
PR 6's write surface. The ledger decides which effect wins here.

## `implementation.md` (per PR)

```
# Implementation — PR {n} — {slug}

## Write surface
- {file} — {created | modified | deleted}

## Summary
{what was implemented, in 3–5 bullets}

## Task checklist
- [x] {task 1}
- [x] {task 2}

## Signals raised
- {HOLD references, if any}

## Notes for tester
(Optional — neutral observations, NOT implementation details)
```

Builder does NOT write about test results here. Builder's local unit tests run; if they fail, builder iterates. Tester's audit is separate.

## `audit.md` (per PR)

```
# Audit — PR {n} — {slug}

**Verdict**: PASS | BLOCK
**Date**: {YYYY-MM-DD HH:MM}

## Per-Test Result Table
| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| {name} | {value} | {value} | {value} | ✓ / ✗ |

## Before/After Comparison
| Metric | Before PR | After PR | Δ |
|---|---|---|---|
| tests passing | {n} | {m} | +{diff} |
| coverage | {%} | {%} | {±%} |
| R CMD check notes | {n} | {m} | {diff} |

## Profile gates
| Gate | Result | Notes |
|---|---|---|
| devtools::test() | PASS/FAIL | {summary} |
| R CMD check --as-cran | PASS/FAIL | {errors, warnings, notes} |
| pkgdown | PASS/FAIL | {errored pages} |
| covr | {%} | {drop vs baseline} |
| CRAN cookbook scan | PASS/FAIL | {violations} |

Tree: {git tree hash at gate time — `git rev-parse 'HEAD^{tree}'`}

## BLOCKs (if any)
(See signals.md BLOCK schema)
```

## `review.md` (per PR)

```
# Review — PR {n} — {slug}

**Verdict**: PASS | BLOCK | STOP
**Date**: {YYYY-MM-DD HH:MM}

## Convergence checks
- Spec coverage: {implementation covers all items in spec.md §Function contracts — y/n}
- Test coverage of spec: {test-spec.md covers all items in spec.md — y/n}
- Tolerance integrity: {tester used tolerances from test-spec — y/n}
- Scope discipline: {implementation.md write surface matches plan — y/n}
- Regression safety: {audit shows no tests outside PR scope changed state — y/n}

## Cross-consistency notes
{narrative where implementation and audit disagree, if any}

## Decision
{1–3 sentences: why PASS, BLOCK, or STOP}

## STOP (if verdict=STOP)
(See signals.md STOP schema)
```

## `shipper.md` (per PR)

```
# Ship — PR {n} — {slug}

**Branch**: feature/{slug}
**PR URL**: {url}
**Merged**: {YYYY-MM-DD HH:MM}
**Merge commit**: {sha}

## Timeline
- {HH:MM} branch created
- {HH:MM} pushed
- {HH:MM} PR opened
- {HH:MM} CI green
- {HH:MM} merged

## CI gates
- {check name}: PASS

## Post-merge
- [x] Plan checkbox marked
- [x] Branch deleted (local + remote)
```

## `status.md`

Append-only log. One line per transition:

```
{timestamp ISO8601}  {state}  ({justification})
```

Example:

```
2026-04-21T14:32:11Z  NEW
2026-04-21T14:38:00Z  COMPREHENDED  (no methods — auto)
2026-04-21T15:10:22Z  SPEC_READY    (spec-review PASS)
2026-04-21T15:45:03Z  PLAN_READY    (plan-review PASS)
2026-04-21T17:55:00Z  DONE          (PR 1, PR 2 merged)
```

## `decisions.md`

Append-only log of HOLD and STOP signals and their resolutions. See `signals.md` for body schemas.
