# Skill: Pipeline Shared

Shared references for the pipeline-* family of skills: `pipeline-spec`, `pipeline-implement`, `pipeline-ship`, `pipeline-simplified`. This skill is not directly invoked; its `references/` are loaded by the orchestrating skills and by dispatched agents.

## Contents

| File | Purpose |
|---|---|
| `references/state-model.md` | Hard-gated state machine and preconditions |
| `references/signals.md` | HOLD / BLOCK / STOP vocabulary |
| `references/pipeline-isolation.md` | Information barriers between builder, tester, reviewer |
| `references/workspace-layout.md` | `.surveycore-workspace/` directory structure |
| `references/artifact-schemas.md` | Required sections for each `.md` artifact |
| `references/r-package-profile.md` | R-specific validation commands and CRAN rules |

## When reading

- Every pipeline-* skill SKILL.md links into these references for enforcement
- Every agent in `.claude/agents/` receives relevant references in its dispatch prompt

## Not in scope

- Orchestration (lives in each pipeline-* skill)
- Agent role definitions (live in `.claude/agents/`)
- Package-wide code style and testing standards (live in `.claude/rules/`)
