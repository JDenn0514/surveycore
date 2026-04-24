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
    ├── spec-{id}.md                shipped spec, copied from workspace
    ├── implementation-plan-{id}.md shipped plan
    └── decisions-{id}.md           shipped decisions log
```

## Request ID

Format: `YYYY-MM-DD-{slug}` where slug is a short kebab-case name for the change. Example: `2026-04-21-get-anova`. Stable across the whole lifecycle — all artifacts for this request go in `runs/2026-04-21-get-anova/`.

## Gitignore

Add to `.gitignore` at repo root (one line):

```
.surveycore-workspace/
```

## Lifecycle

- **At request start**: orchestrating skill creates `runs/{id}/`, writes `request.md` + `impact.md` + `status.md` (with line `NEW`)
- **During work**: agents write their outputs into the run directory. Status transitions appended to `status.md`.
- **At DONE**: orchestrating skill copies durable artifacts (`spec.md`, `implementation-plan.md`, `decisions.md`) into `plans/` with `-{id}` suffix. Workspace entry is kept for forensics.
- **Archiving**: after the change has been released (ships reach `main`), the run directory may be deleted or moved to an archive location. Committed artifacts in `plans/` are moved to `archive/{slug}/` per existing project convention (see CLAUDE.md reference docs).

## Per-PR subdirectories

`prs/pr-{n}-{slug}/` groups builder + tester + reviewer outputs for a single PR. This is required when the implementation-plan.md has multiple PRs — each PR needs its own set of artifacts so parallel dispatch doesn't collide.

## What NOT to put in workspace

- Production code (lives in `R/`, `tests/testthat/`)
- Roxygen docs (inline in source)
- `NEWS.md` entries (committed)
- CRAN submission docs (`cran-comments.md`, committed)
