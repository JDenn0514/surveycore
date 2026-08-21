# Spec: Reduce token usage of the pipeline skills

**Date:** 2026-08-21
**Status:** Approved by user (design review 2026-08-21)
**Scope:** `.claude/agents/`, `.claude/skills/pipeline-*`, `.claude/rules/`, `CLAUDE.md`
**Goal:** Cut weighted token usage per feature by 50–70% with no loss of output quality.

---

## 1. Measured baseline

Source: session transcripts for the dataset-metadata feature (2026-08-19 to 2026-08-21),
five sessions, main loop + subagents.

| Metric | Value |
|---|---|
| Model turns | ~2,300 |
| Cache-read tokens | ~250M |
| Cache-write tokens | ~18M |
| Output tokens | ~2.4M |
| API-equivalent cost | ~$890 |

Cost drivers, ranked:

1. **Review-loop multiplication.** Plan review ran 7 passes. Each pass dispatched ~5
   fresh Explore agents plus a planner resolver. One session (29 subagents) ≈ $300
   equivalent.
2. **Fixed entry fee per subagent.** CLAUDE.md + all 7 rules files (~3,400 lines,
   ~30k tokens) auto-load into every dispatch. Agent defs then instruct a second
   read of `.claude/rules/`. Estimated ~70M of the 250M cache reads.
3. **Repeated heavyweight validation.** One builder ran the full test suite ~10
   times (150 turns at ~170k context each). Tester runs 8 gates; the pre-PR gate
   reruns 2 of them; GitHub CI reruns all of them.
4. **Top-tier model everywhere.** All agents, including mechanical roles, ran on
   Opus-class models.

## 2. Changes

### Group A — Model tiering

| File | Change |
|---|---|
| `.claude/agents/tester.md` | Add `model: sonnet` to frontmatter |
| `.claude/agents/shipper.md` | Add `model: sonnet` to frontmatter |
| `.claude/skills/pipeline-spec/SKILL.md` | Review-lens Explore dispatches pass `model: sonnet` |
| `.claude/skills/pipeline-implement/SKILL.md` | Same for plan-review Explore dispatches |

`builder`, `planner`, `reviewer` keep the session model (no frontmatter change).

Rationale: tester and shipper execute written checklists (gates, git mechanics).
Review-lens agents scan documents against one named criterion. None of these
need the top tier. Officially supported via the `model:` frontmatter key.

### Group B — Convergence caps on review loops

Applies to `pipeline-spec` and `pipeline-implement` SKILL.md files.

1. Hard cap: **3 review passes** per artifact. On findings after pass 3, HOLD and
   ask the user instead of running pass 4.
2. Pass 1 is the only full-panel pass (all lenses, whole document).
3. Pass 2+ are **delta passes**: at most 2 agents, and they review only the
   sections changed since the previous pass (the resolver lists changed sections).
4. Early exit: a pass whose findings require no change to the artifact ends
   the loop.

### Group C — Cut the fixed entry fee

1. **Slim the 7 rules files** from ~3,400 to ~1,000 always-loaded lines:
   - Keep in each file: the Quick Reference table plus rules not derivable
     from it.
   - Move worked examples, long code blocks, and "why" prose to
     `.claude/rules/references/{topic}.md` files, loaded only on demand.
   - Remove content duplicated between files (e.g., return-value visibility is
     stated in both `code-style.md` and `surveycore-conventions.md`); one source
     of truth, others point to it.
   - Remove content the agent can read from the repo itself (`.lintr`,
     `.editorconfig` contents).
2. **Point, do not re-read**: agent defs (`builder.md`, `tester.md`,
   `reviewer.md`) drop the "Read: .claude/rules/" instruction. The rules
   auto-load; a second read doubles the cost. Each agent def instead names the
   on-demand reference files relevant to its role and when to read them.
3. **CLAUDE.md**: no structural change (already 101 lines).

Constraint: no rule may be deleted, only moved or deduplicated. A rule that
moves to a reference file must be reachable via an explicit pointer that states
when to read it.

### Group D — Test-run and output discipline

1. `builder.md`: iterate with `devtools::test(filter = "<file>")` on the touched
   test files. Run the full suite at most twice per PR: once before handoff,
   once after a BLOCK fix.
2. `r-package-profile.md`: every gate command writes full output to a log file
   under the run workspace and returns a filtered summary to context
   (`tail`/`grep` for `FAIL|ERROR|WARNING` and the results line). The full log
   path is recorded in `audit.md` for diagnosis.
3. `pipeline-ship/SKILL.md` BLOCK handling: on tester BLOCK, **continue the same
   builder agent** (SendMessage with the BLOCK body) instead of dispatching a
   fresh builder. A fresh dispatch is used only if the original agent is gone.
   Cap unchanged: 3 cycles, then HOLD.

### Group E — Gate deduplication

1. **Remove `pkgcheck::pkgcheck()` entirely** (gate 6 in
   `r-package-profile.md`). User decision 2026-08-21: not submitting to
   rOpenSci; the check is not needed. Renumber the remaining gates.
2. **Skip the duplicate pre-PR rerun** in `pipeline-ship` Step 2e.5: the tester
   records `git rev-parse HEAD^{tree}` in `audit.md`. If the tree hash at the
   pre-PR gate matches the audit's hash, skip the rerun (it already passed on
   this exact tree). If the hash differs, run the gate as today.
3. Baseline check, post-merge regression check, and GitHub CI are unchanged.

## 3. What does not change

- builder, planner, reviewer stay on the session model.
- Every remaining gate still runs at least once per PR; CI remains the backstop.
- The builder/tester information isolation model (spec vs test-spec) is untouched.
- Snapshot rules, tolerances, and coverage floors are untouched.
- No R source or test file changes.

## 4. Validation

1. After implementation, run the pipeline on one small real change
   (Tier 3-sized).
2. Profile its transcripts with the same script
   (scratchpad `usage_profile.py`) and compare per-stage turns, cache reads,
   cache writes, and output tokens against Section 1.
3. Check `/usage` attribution after the run.
4. Success: ≥50% reduction in weighted usage; all gates pass; review verdicts
   unchanged in kind (no quality regression the reviewer or CI catches).

## 5. Risks

| Risk | Mitigation |
|---|---|
| Sonnet tester misjudges a borderline gate result | Gates are pass/fail commands; reviewer (top model) still cross-checks audit vs implementation |
| Delta review passes miss a regression in unchanged sections | Pass 1 is always full-panel; reviewer reads all artifacts at ship time |
| A moved rule stops being followed | Pointers name the trigger condition; validation run watches for style violations in the PR diff |
| Tree-hash skip misses an environment-only change | Hash mismatch forces the rerun; CI still runs everything |
