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

Drive a request from NEW → SPEC_READY. Produce `spec-{id}.md` (for builder)
and `test-spec-{id}.md` (for tester) that are independently sufficient.

## When to use

- Any new exported function
- Any change to numerical behavior (new estimator, modified formula)
- Any methodology-referencing change (attached papers, new variance approach)
- Any public API change

For small changes (≤3 files, no algorithmic change, no new export), use
`pipeline-simplified` instead.

## Preconditions

- Current state = NEW (or first run — workspace not yet created)
- User has described what they want
- Any attached papers or PDFs are available

## Stage routing

| Stage | Purpose | Output | Next state |
|---|---|---|---|
| 0 | Deep Comprehension (if methods-heavy or paper attached) | `comprehension.md` | COMPREHENDED |
| 1 | Planner drafts `spec-{id}.md` + `test-spec-{id}.md` | two artifacts | DRAFT |
| 2 | Methods review (5 lenses + Literature lens) | `spec-methods-review-{id}.md` | METHODS_REVIEWED |
| 2r | Resolve methods findings | updated spec + test-spec | DRAFT (loop) |
| 3 | Spec review (6 lenses) | `spec-review-{id}.md` | SPEC_REVIEWED |
| 3r | Resolve spec findings | updated spec + test-spec | DRAFT (loop) |
| 4 | Freeze & advance | status → SPEC_READY | SPEC_READY |

Stages 2 and 3 may loop with their resolve counterparts until verdict PASS.

## Stage Routing (user prompt)

Determine which stage the user wants from context (current `status.md` state,
what they just said, what artifacts exist). If unclear:

```
question: "Which stage of the spec workflow?"
header: "Stage"
options:
  - label: "Stage 0 — Deep Comprehension (paper/methods-heavy)"
    description: "Extract formulas, gotchas, and reference mappings from an attached paper or PDF. Produces comprehension.md before drafting begins."
  - label: "Stage 1 — Draft the spec"
    description: "Write spec-{id}.md and test-spec-{id}.md from the request (includes deep comprehension if methods-heavy)."
  - label: "Stage 2 — Methods review"
    description: "Run methodology lenses over an existing draft. Includes Literature Lens if comprehension.md exists."
  - label: "Stage 3 — Spec review"
    description: "Run 6 spec lenses over an existing draft."
  - label: "Stage 3r — Resolve findings"
    description: "Work through open issues from methods or spec review and log decisions."
```

Then jump directly to that stage.

## Setup (before Stage 0)

1. Determine `{id}` — infer from user's description (e.g., "survey-glm" →
   `survey-glm`, "calibration" → `calibration`). Ask if ambiguous.
2. Create workspace directory: `.pipeline-workspace/runs/{YYYY-MM-DD-id}/`
3. Write `request.md` from the user's description (per `artifact-schemas.md`).
4. Write `impact.md` — assess scope. Set smallness test result.
5. Append `NEW` to `status.md`.

## Stage 0 — Deep Comprehension

Read `spec-workflow/references/stage-0-comprehension.md` for the full protocol.

Determine if methods-heavy per the "When to run" criteria in that file. Also
check:
- Did the user attach papers, PDFs, or markdown files of journal articles?
- If yes, how many?

**If NOT methods-heavy AND no papers attached:** auto-transition to COMPREHENDED
with status line `(no methods — auto)`.

### Single paper (exactly 1 attached) or methods-heavy with no paper

1. Dispatch `planner` agent:
   > Run Stage 0 (Deep Comprehension) per
   > `.claude/skills/spec-workflow/references/stage-0-comprehension.md`.
   > Write `comprehension.md` to the workspace run directory.
   > If a paper was attached, read it in full before writing.
   > Do not draft spec-{id}.md or test-spec-{id}.md yet.
   > Paper/attachment: {path or content}

2. On return, verify `comprehension.md` is coherent: problem restated, formulas
   present with symbol bindings, ≥1 gotcha, ≥1 reference mapping, assumptions
   listed. If not coherent, re-dispatch with specific feedback.

3. Append `COMPREHENDED` to `status.md`.

### Multiple papers (2+ attached)

Reading multiple full papers inside one agent context crowds out the reasoning
needed for synthesis. Use parallel extraction first:

1. **Dispatch one `extractor` agent per paper in the same turn** (parallel).
   Each extractor reads one paper in full and writes
   `extraction-{slug}.md` to the workspace run directory. Derive the slug from
   the sanitized filename or a short paper title.

2. **Verify all extractions** before continuing. Each `extraction-{slug}.md`
   must contain: ≥1 formula with symbol bindings, ≥1 gotcha, ≥1 reference
   claim. Re-dispatch any extractor that produced a thin or incomplete result.

3. **Dispatch `planner` agent for synthesis**:
   > Run Stage 0 (Deep Comprehension) — synthesis pass only. All papers have
   > been pre-read by extraction agents. Their outputs are at:
   > {list all extraction-{slug}.md paths}
   >
   > Read all extractions. Synthesize into `comprehension.md` per
   > `.claude/skills/spec-workflow/references/stage-0-comprehension.md`
   > §Output structure. Pay particular attention to:
   > - Conflicts between sources (different formulas for the same quantity)
   > - Assumptions that only one paper makes explicit
   > - Gotchas that appear in multiple sources (these are especially important)
   > - Citations: aggregate all Citation sections from the extractions into a
   >   single Citations section. Preserve any [NOT FOUND] flags exactly.
   >
   > Do not re-read the original papers — work only from the extractions.

4. On return, verify `comprehension.md` using the same coherence checks as the
   single-paper path. Any cross-paper conflicts the planner could not resolve
   should be written to `decisions-{id}.md` as HOLDs for the user to resolve
   before Stage 1.

5. Append `COMPREHENDED` to `status.md`.

## Stage 1 — Draft

Read `spec-workflow/references/stage-1-draft.md` for the full protocol before
dispatching. The key constraint: Stage 1 must produce TWO artifacts:
- `plans/spec-{id}.md` — behavioral contract (builder's input)
- `plans/test-spec-{id}.md` — validation scenarios (tester's input)

Dispatch `planner`:

> Draft `spec-{id}.md` and `test-spec-{id}.md` per
> `.claude/skills/spec-workflow/references/stage-1-draft.md`.
> Two-artifact rule applies: neither document may reference the other.
> {If comprehension.md exists: "Read comprehension.md at [path] before drafting."}

On return, verify both artifacts exist and contain all required sections
(mechanical check — not a quality review). Append `DRAFT` to `status.md`.

## Stage 2 — Methods review

Read `spec-workflow/references/stage-2-methods-review.md` for the full
protocol. Self-assess applicability using the Trigger Condition in that file.

If applicable, dispatch 5–6 Explore subagents in parallel (one per lens),
collecting results into `plans/spec-methods-review-{id}.md`. Include Lens 6
(Literature Cross-Check) if `comprehension.md` exists.

Aggregate findings with verdict:
- **PASS** — no BLOCKING, no REQUIRED-UNAMBIGUOUS findings
- **BLOCK** — any BLOCKING finding
- **HOLD** — any JUDGMENT_CALL finding (user decides)

If not applicable: append `(Stage 2 N/A — {reason})` to `status.md`.

## Stage 2r — Resolve methods findings

Read `spec-workflow/references/stage-2-methods-resolve.md` for the full
protocol.

Two modes:
- **UNAMBIGUOUS batch**: Apply all unambiguous fixes in one pass. Re-run
  affected lenses only (mini-pass) to confirm.
- **JUDGMENT_CALL per-issue**: Ask user via `AskUserQuestion`, one at a time.
  Record resolution in `decisions-{id}.md`. Apply fix. Mini-pass affected lens.

Loop until `spec-methods-review-{id}.md` verdict = PASS.

## Stage 3 — Spec review

Read `spec-workflow/references/stage-3-review.md` for the full protocol.

Dispatch 6 Explore subagents in parallel (one per lens). Aggregate into
`plans/spec-review-{id}.md`. Verdict rules same as Stage 2.

## Stage 3r — Resolve spec findings

Read `spec-workflow/references/stage-4-resolve.md` for the full protocol.

Use BIG mode (>8 findings) or SMALL mode (≤8 findings). Loop until
`spec-review-{id}.md` verdict = PASS.

## Stage 4 — Freeze & advance

On PASS from both Stage 2 (if applicable) and Stage 3:

1. Verify `plans/spec-{id}.md` and `plans/test-spec-{id}.md` both exist and
   are finalized.
2. Copy `comprehension.md` to `plans/comprehension-{id}.md` if present.
3. Append `SPEC_READY` to `status.md`.
4. Return to user:
   > "spec-{id}.md and test-spec-{id}.md are SPEC_READY. Next step:
   > run `/pipeline-implement` to draft the PR map."

## Signal handling

- **HOLD** from any stage → pause, write to `decisions-{id}.md`, ask user
  via `AskUserQuestion`, resume
- **BLOCK** from methodology review → route to Stage 2r
- **STOP** → pipeline-spec cannot produce STOP; only pipeline-ship's reviewer
  can issue a STOP

## References

- `skills/pipeline-shared/references/state-model.md`
- `skills/pipeline-shared/references/signals.md`
- `skills/pipeline-shared/references/pipeline-isolation.md`
- `skills/pipeline-shared/references/artifact-schemas.md`
- `skills/pipeline-shared/references/workspace-layout.md`
- `skills/spec-workflow/references/stage-0-comprehension.md`
- `skills/spec-workflow/references/stage-1-draft.md`
- `skills/spec-workflow/references/stage-2-methods-review.md`
- `skills/spec-workflow/references/stage-2-methods-resolve.md`
- `skills/spec-workflow/references/stage-3-review.md`
- `skills/spec-workflow/references/stage-4-resolve.md`
- `.claude/agents/planner.md`
- `.claude/agents/extractor.md`
