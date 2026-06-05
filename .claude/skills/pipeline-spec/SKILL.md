---
name: pipeline-spec
description: >
  Orchestrates spec drafting and review for surveycore — from NEW request through
  SPEC_READY. Runs Deep Comprehension (if methods-heavy or paper attached),
  dispatches planner to draft spec.md + test-spec.md, runs methods review and
  spec review via Explore subagents, resolves findings, advances to SPEC_READY.
  Produces artifacts builder and tester can consume independently. Use when the
  user says "start planning", "pipeline it", "new feature", "draft spec", or
  mentions a new exported function, a statistical method, or attaches a journal
  article.
---

# Skill: pipeline-spec

Drive a request from NEW → SPEC_READY. Produce `spec.md` (for builder) and `test-spec.md` (for tester) that are independently sufficient.

## When to use

- Any new exported function
- Any change to numerical behavior
- Any methodology-referencing change (papers, new estimators)
- Any public API change

For small changes (≤3 files, no algorithmic change, no new export), use `pipeline-simplified` instead.

## Preconditions

- Current state = NEW
- `request.md` exists in the run directory
- `impact.md` exists with smallness-test result = `full-required`

If preconditions fail, refuse and report to user. See `pipeline-shared/references/state-model.md §Refusal protocol`.

## Stage routing

| Stage | Purpose | Output | Next state |
|---|---|---|---|
| 0 | Deep Comprehension (if methods-heavy) | `comprehension.md` | COMPREHENDED |
| 1 | Planner drafts `spec.md` + `test-spec.md` | two artifacts | DRAFT |
| 2 | Methods review (5 lenses, methods-heavy only) | `methods-review.md` | METHODS_REVIEWED |
| 2r | Resolve methods-review findings | updated spec, updated test-spec | DRAFT (loop back) |
| 3 | Spec review (6 lenses) | `spec-review.md` | SPEC_REVIEWED |
| 3r | Resolve spec-review findings | updated spec, updated test-spec | DRAFT (loop back) |
| 4 | Freeze & advance | `status.md` → SPEC_READY | SPEC_READY |

Loops: stages 2 and 3 may loop with their resolve counterparts until verdicts PASS.

## Stage Routing (user prompt)

Determine which stage the user wants from context (current `status.md` state,
what they just said, what artifacts exist). If unclear:

```
question: "Which stage of the spec workflow?"
header: "Stage"
options:
  - label: "Stage 1 — Draft the spec"
    description: "Write spec.md and test-spec.md from the request (includes deep comprehension if methods-heavy)."
  - label: "Stage 2 — Methods review"
    description: "Run 5 methodology lenses over an existing draft (methods-heavy specs only)."
  - label: "Stage 3 — Spec review"
    description: "Run 6 spec lenses over an existing draft."
  - label: "Stage 3r — Resolve findings"
    description: "Work through open issues from methods or spec review and log decisions."
```

Then jump directly to that stage.

## Stage 0 — Deep Comprehension

Determine if methods-heavy per `planner.md §Step 0 criteria`. Also check:
- Did the user attach papers, PDFs, or markdown files of journal articles?
- If yes, how many?

**If NOT methods-heavy AND no papers attached:** auto-transition to COMPREHENDED
with status line `(no methods — auto)`.

### Single paper (exactly 1 attached) or methods-heavy with no paper

1. Dispatch `planner` agent with prompt:
   > Run Step 0 (Deep Comprehension Protocol) only. Write `comprehension.md` per
   > artifact-schemas.md. If a paper was attached, read it in full before writing.
   > Do not draft spec.md or test-spec.md yet.
   > Paper/attachment: {path or content}

2. On return, verify `comprehension.md` is coherent: problem restated, formulas
   present with symbol bindings, ≥1 gotcha, ≥1 reference mapping, assumptions
   listed. If not coherent, re-dispatch with specific feedback.

3. Append `COMPREHENDED` to `status.md`.

### Multiple papers (2+ attached)

Reading multiple full papers inside one agent context crowds out the reasoning
needed for synthesis. Use parallel extraction first:

1. **Dispatch one `extractor` agent per paper in the same turn** (parallel).
   Each extractor reads one paper in full and writes `extraction-{slug}.md` to
   the workspace run directory. Derive the slug from the sanitized filename or a
   short paper title.

2. **Verify all extractions** before continuing. Each `extraction-{slug}.md`
   must contain: ≥1 formula with symbol bindings, ≥1 gotcha, ≥1 reference
   claim. Re-dispatch any extractor that produced a thin or incomplete result.

3. **Dispatch `planner` agent for synthesis**:
   > Run Step 0 (Deep Comprehension Protocol) — synthesis pass only. All papers
   > have been pre-read by extraction agents. Their outputs are at:
   > {list all extraction-{slug}.md paths}
   >
   > Read all extractions. Synthesize into `comprehension.md` per
   > artifact-schemas.md. Pay particular attention to:
   > - Conflicts between sources (different formulas for the same quantity)
   > - Assumptions that only one paper makes explicit
   > - Gotchas that appear in multiple sources (these are especially important)
   > - Citations: aggregate all Citation sections from the extractions into a
   >   single Citations section in `comprehension.md`. Preserve any [NOT FOUND]
   >   flags exactly — do not fill them in by inference.
   >
   > Do not re-read the original papers — work only from the extractions.

4. On return, verify `comprehension.md` using the same coherence checks as the
   single-paper path. Any cross-paper conflicts the planner could not resolve
   should be written to `decisions.md` as HOLDs for the user to resolve before
   Stage 1.

5. Append `COMPREHENDED` to `status.md`.

## Stage 1 — Draft

Dispatch `planner`:

> Draft `spec.md` and `test-spec.md` per artifact-schemas.md. Independent sufficiency rule applies: neither document may reference the other. Pipeline-isolation principle in pipeline-isolation.md.

On return, verify both artifacts exist and contain all required sections (mechanical check, not a quality review).

## Stage 2 — Methods review (methods-heavy only)

Skip if not methods-heavy.

Dispatch 5 Explore subagents in parallel, one per lens:

1. **Estimator lens** — does the estimator formula in `spec.md` match the citation in `comprehension.md`? Any missing sub-cases (domain estimation, subpopulation)?
2. **Variance lens** — does the variance formula account for all design features (stratification, clustering, FPC, replicate weights)?
3. **DoF lens** — is the degrees-of-freedom formula correct? Boundary cases (single-PSU stratum, DoF → 0)?
4. **Domain lens** — what happens under zero-weight domain, all-NA domain, single-observation domain?
5. **Literature lens** — do cited sources support each design decision? Any relevant paper that contradicts the current design?

Each lens returns findings classified by `severity` (BLOCKING, REQUIRED, ADVISORY) and `type` (UNAMBIGUOUS, JUDGMENT_CALL).

Aggregate into `methods-review.md` with verdict:
- PASS — no BLOCKING, no REQUIRED-UNAMBIGUOUS findings
- BLOCK — any BLOCKING finding
- HOLD — any JUDGMENT_CALL finding (user decides)

## Stage 2r — Resolve methods findings

Two modes:

- **UNAMBIGUOUS batch**: Apply all unambiguous fixes to `spec.md`/`test-spec.md`/`comprehension.md` in one pass. Re-dispatch the affected lenses only (mini-pass) to confirm.
- **JUDGMENT_CALL per-issue**: Ask user via AskUserQuestion, one at a time. Record resolution in `decisions.md`. Apply fix. Mini-pass the affected lens.

Loop until methods-review.md verdict=PASS.

## Stage 3 — Spec review

Dispatch 6 Explore subagents in parallel, one per lens:

1. **DRY lens** — is there duplicated logic in the spec that should be a shared helper?
2. **Test Completeness lens** — 13 categories (happy path, errors per class, warnings per class, empty input, single-row, all-NA outcome, single-level grouping, zero-weight, degenerate strata, SRS vs stratified, Taylor vs replicate, two-phase, snapshot coverage)
3. **Contract Completeness lens** — every function has full Arguments / Returns / Errors / Warnings / Edge cases
4. **Edge Cases lens** — any realistic edge case not in the spec's edge-case list?
5. **Engineering Level lens** — is the design over- or under-engineered for what's needed now?
6. **API Coherence lens** — does the new API match existing surveycore conventions (naming, argument order, return shape)?

Aggregate into `spec-review.md`. Verdict rules same as Stage 2.

## Stage 3r — Resolve spec findings

Two modes from surveycore's existing spec-workflow:

- **BIG mode** (4 findings at a time, Explore enrichment): for complex resolutions. Each finding gets a mini-investigation before the fix.
- **SMALL mode** (1 finding at a time): for mechanical fixes.

Mode is chosen by finding count: >8 findings → BIG, else SMALL.

Loop until spec-review.md verdict=PASS.

## Stage 4 — Freeze

On PASS:

1. Copy `spec.md`, `test-spec.md`, `comprehension.md` (if exists) from workspace into `plans/` with `-{slug}` suffix (slug only — no date prefix)
2. Append `SPEC_READY` to `status.md`
3. Return to user with summary and next step (`pipeline-implement`)

## Signal handling

- **HOLD** from any stage → pause, write to `decisions.md`, ask user via AskUserQuestion, resume
- **STOP** → pipeline-spec cannot produce STOP; only pipeline-ship's reviewer can

## References

- `skills/pipeline-shared/references/state-model.md`
- `skills/pipeline-shared/references/signals.md`
- `skills/pipeline-shared/references/pipeline-isolation.md`
- `skills/pipeline-shared/references/artifact-schemas.md`
- `skills/pipeline-shared/references/workspace-layout.md`
- `.claude/agents/planner.md`
- `.claude/agents/extractor.md`
