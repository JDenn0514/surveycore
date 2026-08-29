# Decisions — var-extension-slot

## 2026-08-27 — PR scope: Proposal A only
- **Question**: Should this PR ship both Proposal A (extension slot) and
  Proposal B (`measure`), or just Proposal A now?
- **Resolution**: Proposal A only. `measure` is independent, not
  time-sensitive, and is deferred to a separate future request.
- **Why**: keeps this PR minimal and focused on beating the frozen-property
  deadline; avoids bundling an unrelated design decision (inferred vs.
  required `measure`, whether analysis functions should act on it) into a
  time-sensitive PR.

## 2026-08-27 — Slot shape: flat named list, no namespacing
- **Question**: What shape should the Proposal A extension slot take?
- **Resolution**: A flat named list per variable
  (`set_var_extra(design, col = list(role = "free_text"))`), not namespaced
  by package.
- **Why**: simplest shape; matches the issue's own preference for a slot
  that never needs revision. Namespacing solves a collision problem with no
  demonstrated instance yet.

## 2026-08-28 — Plan-review Pass 1 resolution (batch, Auto Mode)
- **Question**: How to resolve the 15 findings (0 blocking, 3 required, 12
  suggestion) from the 5-lens plan review?
- **Resolution**: Resolved all 15 directly, in one pass, without a
  per-issue `AskUserQuestion` prompt for each. Edits applied to
  `implementation-plan.md` (→ v1.1) and additively to `test-spec.md` (→
  v1.1, one new §Class/foundation table, no other change). Full itemized
  resolution is recorded in `plan-review.md` §Resolution.
- **Why**: every finding had exactly one reasonable fix with no genuine
  design trade-off to weigh (missing test coverage, a misnamed file path,
  a wording inconsistency, an under-scheduled test class) — none of them
  met the HOLD bar ("methodology genuinely ambiguous, user must make a
  judgment call") from `signals.md`. Auto Mode was active for this
  session, which directs making the reasonable call on this class of
  finding rather than pausing for confirmation on each one.
