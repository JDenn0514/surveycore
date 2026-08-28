# GitHub Strategy — Worked Examples and Release Detail

Detail moved out of `.claude/rules/github-strategy.md`. The decision tables
live there; this file shows how to apply them. Read this when choosing a
workflow tier for a borderline change, or when preparing a release.

---

## Workflow tier worked examples

Use these to calibrate. When in doubt about a tier, find the closest example
below.

**Tier 1 — New exported function `get_contrasts()`**
New API surface, behavior not fully specified, multiple design choices
(contrast coding, CI method, interaction with domain estimation). → spec →
implementation plan → `/r-implement`

**Tier 1 — Adding `method =` to `get_quantiles()` for interpolation strategy**
Multiple valid approaches exist in the survey literature (linear, Type 7,
Woodruff). Correct behavior is genuinely undecided until it's specified.
Feels like "one argument" but it's actually a behavioral commitment.
→ Tier 1, not Tier 2.

**Tier 2 — Adding `variance =` argument to `get_means()`**
Behavior is obvious: let the caller pick Taylor vs. replicate variance when
both are available. But the approach isn't: how does it interact with
`survey_twophase`, what's the default, what error fires when the requested
method isn't supported? Write an implementation plan to settle these before
touching code. → implementation plan → `/r-implement`

**Tier 2 → Tier 3 boundary — Adding `na.rm =` to `get_freqs()`**
One new argument, behavior obvious (`TRUE` drops NA cells). But wiring it
through all design paths and deciding whether NA gets its own frequency row
or disappears entirely isn't obvious. → Tier 2 (plan first), not Tier 3.

**Tier 3 — `get_means()` returns wrong SE when `nest = TRUE` is omitted on
NHANES data**
Clear bug, localized to the variance calculation in `R/variance-taylor.R`.
The correct behavior is known (match `survey::svymean`). Fix the logic, add
a regression test. → branch → `/r-implement` → `/commit-and-pr`

**Tier 0 — Fix a typo in the `@param fpc` description**
One-word change in roxygen comment. No branch, no PR needed. → direct commit
to `develop`

---

## Release preparation

Use `/merge-main`. It handles: NEWS.md update → version bump →
`devtools::check()` → PR `develop` → `main` → tag → post-release `.9000`
bump.

PR template for feature PRs lives in `.github/PULL_REQUEST_TEMPLATE.md`.

Hotfixes branch from `main`, merge to `main`, then also merge to `develop`
to stay in sync.

GitHub settings: allow both squash merges and merge commits; auto-delete
head branches.

| Tag | Milestone |
|-----|-----------|
| `v0.1.0` | Phase 0 complete — core infrastructure |
| `v0.2.0` | Phase 0.5 complete — surveytidy |
| `v0.3.0` | Phase 1 complete — estimation functions |
| `v0.4.0` | Phase 2 complete — regression |
| `v1.0.0` | Stable API, CRAN submission |
