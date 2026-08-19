# Workspace Layout

Per-request runtime artifacts live under `.surveycore-workspace/`, a gitignored directory at the repo root. Durable documentation artifacts (specs, archived plans) live in `plans/` and are committed.

## Directory structure

```
<repo-root>/
├── .surveycore-workspace/          (gitignored)
│   └── runs/
│       └── {request-id}/
│           ├── status.md           state transitions (append-only)
│           ├── request.md          user intent
│           ├── impact.md           scope assessment
│           ├── comprehension.md    optional — methods-heavy only
│           ├── spec.md             builder's input
│           ├── test-spec.md        tester's input
│           ├── methods-review.md   Stage 2 verdict
│           ├── spec-review.md      Stage 3 verdict
│           ├── implementation-plan.md   PR map + acceptance
│           ├── plan-review.md      plan review verdict
│           ├── decisions.md        HOLD/STOP resolutions log
│           └── prs/
│               └── pr-{n}-{slug}/
│                   ├── implementation.md   builder output
│                   ├── audit.md            tester output
│                   ├── review.md           reviewer output
│                   └── shipper.md          ship record
└── plans/                          (committed)
    ├── spec-{slug}.md                shipped spec, copied from workspace
    ├── test-spec-{slug}.md           shipped test-spec, copied from workspace
    ├── comprehension-{slug}.md       shipped comprehension (if exists)
    ├── implementation-plan-{slug}.md shipped plan
    └── decisions-{slug}.md           shipped decisions log
```

## Request ID

Format: `YYYY-MM-DD-{slug}` where slug is a short kebab-case name for the change. Example: `2026-04-21-get-anova`. Stable across the whole lifecycle — all artifacts for this request go in `runs/2026-04-21-get-anova/`.

The date is part of the run folder name but is NOT included in durable artifact filenames in `plans/`. Artifacts use the slug alone: `spec-{slug}.md`, not `spec-{id}.md`. This keeps `plans/` filenames readable without redundant date prefixes.

## Gitignore

Add to `.gitignore` at repo root (one line):

```
.surveycore-workspace/
```

## Lifecycle

- **At request start**: orchestrating skill creates `runs/{id}/`, writes `request.md` + `impact.md` + `status.md` (with line `NEW`)
- **During work**: agents write their outputs into the run directory. Status transitions appended to `status.md`.
- **At each freeze**: the orchestrating skill copies the durable artifacts into `plans/` with `-{slug}` suffix, so each phase's output is saved even when the next phase runs in a fresh session:
  - At SPEC_READY: `spec.md`, `test-spec.md`, `comprehension.md` (if present), `decisions.md`
  - At PLAN_READY: `implementation-plan.md`, updated `decisions.md`
  - At DONE: final `decisions.md`
  A later copy overwrites the earlier one. The workspace entry is kept for forensics.
- **Archiving**: after the final PR merges, committed artifacts in `plans/` are moved to `archive/{slug}/` per `references/archive-plans.md`. The run directory may then be deleted or moved to an archive location.

## Per-PR subdirectories

`prs/pr-{n}-{slug}/` groups builder + tester + reviewer outputs for a single PR. This is required when the implementation-plan.md has multiple PRs — each PR needs its own set of artifacts so parallel dispatch doesn't collide.

## What NOT to put in workspace

- Production code (lives in `R/`, `tests/testthat/`)
- Roxygen docs (inline in source)
- `NEWS.md` entries (committed)
- CRAN submission docs (`cran-comments.md`, committed)
