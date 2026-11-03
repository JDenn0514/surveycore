# chore(pipeline): reduce token usage of the pipeline skill family

**Date**: 2026-08-22
**Branch**: JDenn0514/reduce-token-usage
**Phase**: Tooling (no package code)

## Changes

- Run the tester and shipper agents, and all review-lens Explore dispatches, on Sonnet; builder, planner, and reviewer keep the session model
- Cap review loops at 3 passes: pass 1 is the only full-panel pass, later passes are 2-agent delta passes with an early exit
- Slim the always-loaded rules from 1,822 to 652 lines; move worked examples to four on-demand files in `.claude/references/`
- Stop agents and dispatch prompts from re-reading auto-loaded rules
- Cap builder full-suite runs at 2 per PR; route all gate output through log files with filtered summaries
- Continue the SAME builder agent on tester BLOCK instead of dispatching a fresh one
- Remove the pkgcheck gate everywhere; skip the duplicate pre-PR gate rerun when the audit's tree hash matches
- Add `.claude/scripts/run-gates.sh` — all validation gates in one background command with per-gate logs and one summary table
- Ban tester sleep-poll loops and pre-PR-state reconstruction; pipeline-simplified now captures the baseline in the background and passes it to the tester
- Add `.claude/scripts/usage-profile.py` for before/after session measurement

Validated on two live pipeline-simplified runs (PRs #155, #156): tester went
from 683 turns / 92M cache-read tokens to 45 turns / 1.4M; a full
plan-build-test-ship cycle now costs ~6x less than the original configuration.

## Files Modified

- `.claude/agents/{builder,tester,reviewer,shipper,planner}.md` — model tiering, gate batching, discipline rules
- `.claude/skills/pipeline-{spec,implement,ship,simplified}/SKILL.md` — review caps, dispatch slimming, tree-hash skip, baseline capture
- `.claude/skills/pipeline-shared/references/{r-package-profile,artifact-schemas,signals}.md` — gate table, canonical runner, audit schema
- `.claude/rules/*.md` (all 7) — slimmed to decision tables with pointers
- `.claude/references/{code-style,github-strategy,r-package,testing}-detail.md` — new on-demand example files
- `.claude/scripts/{run-gates.sh,usage-profile.py}` — new tooling
- `CLAUDE.md`, `.gitattributes` — pointer line; LF for shell scripts
- `plans/spec-reduce-token-usage.md`, `plans/implementation-plan-reduce-token-usage.md` — planning docs
