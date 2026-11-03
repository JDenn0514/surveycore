# State Model

Hard-gated per-request state machine. Each request has a run directory under `.surveycore-workspace/runs/{request-id}/` (see `workspace-layout.md`) with a `status.md` file recording transitions.

## States

```
NEW → COMPREHENDED → SPEC_READY → PLAN_READY → DONE
```

Simplified workflow uses a shorter chain:

```
NEW → PLANNED → DONE
```

(See `.claude/skills/pipeline-simplified/SKILL.md`.)

Per-PR progress between PLAN_READY and DONE is recorded in the per-PR artifacts (`implementation.md`, `audit.md`, `review.md`, `shipper.md`) and the plan checkboxes — not as pipeline states.

## Transitions and preconditions

Every transition must satisfy ALL preconditions. A skill that attempts to advance without them MUST refuse and return to the user.

### Full workflow

| From | To | Preconditions |
|---|---|---|
| NEW | COMPREHENDED | `request.md` exists. If request is methods-heavy (see planner.md), `comprehension.md` exists and is non-empty. For non-methods requests, this state is auto-entered with no artifact. |
| COMPREHENDED | SPEC_READY | `spec.md` exists. `test-spec.md` exists. `spec-review.md` verdict = PASS. If methods-heavy: `methods-review.md` verdict = PASS. |
| SPEC_READY | PLAN_READY | `implementation-plan.md` exists with a PR map. `plan-review.md` verdict = PASS. |
| PLAN_READY | DONE | For every PR in the plan: `implementation.md` exists, `audit.md` verdict = PASS, `review.md` verdict = PASS, PR merged to `develop`, plan checkbox `[x]` marked. All worktrees cleaned up. |

### Simplified workflow

| From | To | Preconditions |
|---|---|---|
| NEW | PLANNED | `request.md` exists with acceptance criteria. `impact.md` exists (scope ≤3 files, no algorithmic change). |
| PLANNED | DONE | `implementation.md` exists. `audit.md` verdict = PASS (tester is the quality gate; no separate reviewer). PR merged to `develop`. |

## Rules

1. **`status.md` is append-only.** Every transition appends a line:
   ```
   2026-04-21T14:32:11Z  SPEC_READY  (spec-review PASS, methods-review PASS)
   ```
2. **Only orchestrating skills mutate `status.md`.** Agents never write to it.
3. **BLOCK returns the PR to the builder.** Routing and the cycle limit are defined once in `signals.md §BLOCK`.
4. **STOP halts the pipeline.** A reviewer STOP terminates processing; the user must explicitly authorize resume.
5. **HOLD pauses the current state.** Recorded in `decisions.md`; user resolves; pipeline resumes from where it paused.

## Refusal protocol

If a skill or agent is invoked when preconditions are not met, it MUST:

1. Read `status.md`
2. Identify the missing precondition
3. Return to user with:
   - Current state
   - Target state requested
   - Which precondition is missing
   - What artifact or verdict is needed to satisfy it

No silent downgrades. No partial advancement.
