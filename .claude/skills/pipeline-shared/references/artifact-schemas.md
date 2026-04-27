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

## Smallness test (see pipeline-simplified/references/smallness-test.md)
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

## Pipeline split
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
- **Invariants**: `test_invariants(design)` first assertion

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
- [ ] pkgcheck PASS
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
  - **Tasks** (2–5 min each, TDD sub-steps explicit)
    1. Write failing test for {behavior}
    2. Implement {function}
    3. Verify test passes
    ...
  - **Acceptance criteria** — observable outcomes before merge
  - **Files touched** — exact write surface
  - **Pipeline split**: recommended | optional
- [ ] PR 2: ...
```

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
| pkgcheck | PASS/FAIL | {standards violated} |
| pkgdown | PASS/FAIL | {errored pages} |
| covr | {%} | {drop vs baseline} |
| CRAN cookbook scan | PASS/FAIL | {violations} |

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
2026-04-21T17:22:18Z  PIPELINES_COMPLETE  (PR 1, PR 2 audits PASS)
2026-04-21T17:30:44Z  REVIEW_PASSED
2026-04-21T17:55:00Z  DONE
```

## `decisions.md`

Append-only log of HOLD and STOP signals and their resolutions. See `signals.md` for body schemas.
