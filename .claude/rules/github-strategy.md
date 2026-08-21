# surveycore GitHub Strategy

**Version:** 2.1
**Status:** Decided — do not re-litigate without updating this document

## Quick Reference

| Decision | Choice |
|----------|--------|
| Branching model | `develop` integration branch — features → `develop`; `develop` → `main` for releases |
| Branch naming | `feature/`, `fix/`, `hotfix/`, `docs/`, `chore/`, `refactor/` |
| Merge strategy | Squash for feature → develop; regular merge for develop → main |
| Commit format | Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `chore:`) |
| PR granularity | One PR per logical unit of work |
| Versioning | `X.Y.Z.9000` on `develop`; `X.Y.Z` on `main` after release |
| CI | R-CMD-check required on `main` and `develop`; all PRs |
| Release workflow | Use `/merge-main` |

## Workflow tiers

Choose by change size. When in doubt, go one tier higher.

| Tier | When to use | Workflow |
|------|-------------|----------|
| **1 — Full** | New phases, new exported functions, new S7 classes, anything where correct behavior is undecided | spec → implementation plan → `/r-implement` → `/commit-and-pr` |
| **2 — Plan only** | Medium bug fixes, new arguments, edge case additions — behavior obvious, approach isn't | implementation plan → `/r-implement` → `/commit-and-pr` |
| **3 — Direct** | Clear bug fixes localized to 1–2 functions, test additions, roxygen changes | branch → `/r-implement` → `/commit-and-pr` |
| **0 — Commit** | Typos, comments, `.gitignore`, README tweaks | direct commit to `develop` (no branch) |

## Branching model

```
main          ← always stable; every commit is a tagged release
  ↑
develop       ← integration branch; all feature work lands here first
  ↑
feature/*     ← individual units of work; branch from develop
hotfix/*      ← urgent fixes only; branch from main
```

Feature branches always cut from `develop` and merge back to `develop`.
Never open a feature PR directly against `main`.

### What gets a branch vs. direct push

| Change type | Branch needed? |
|-------------|----------------|
| New R source file | Yes |
| New test file | Yes |
| Any change to exported function | Yes |
| Vendor code addition | Yes |
| README / docs update | No |
| Comment or typo fix | No |
| `.Rbuildignore` / `.gitignore` | No |
| Version bump + NEWS.md (release prep) | Direct commit to `develop` |

## Branch naming

Format: `{type}/{short-description}`

| Prefix | Target | Use for |
|--------|--------|---------|
| `feature/` | `develop` | New functionality |
| `fix/` | `develop` | Bug fix in existing implementation |
| `hotfix/` | `main` | Urgent fix that can't wait for next release |
| `docs/` | `develop` | Documentation-only changes |
| `test/` | `develop` | Test-only additions or fixes |
| `chore/` | `develop` | Maintenance (CI config, build tooling) |
| `refactor/` | `develop` | Internal restructuring, no behavioral change |

## Commit format (Conventional Commits)

`{type}({scope}): {short description}`

| Type | Use for |
|------|---------|
| `feat` | New exported function, new class, new property |
| `fix` | Bug fix (behavioral change to existing code) |
| `docs` | Roxygen comments, README, vignettes, plans |
| `test` | Adding or updating tests (no production code change) |
| `chore` | CI config, DESCRIPTION, NAMESPACE, build tooling |
| `refactor` | Internal restructuring with no behavioral change |

Scopes: `classes`, `constructors`, `metadata`, `validators`, `variance`,
`analysis`, `utils`

## Merge strategy and versioning

- **Feature → develop:** squash merge; the squash commit is one conventional
  commit summarizing the PR, e.g.
  `feat(analysis): implement survey_glm() with Wald confidence intervals (#42)`.
- **Develop → main (releases only):** regular merge — avoids SHA divergence
  between the branches.
- Versions: `X.Y.Z.9000` during development on `develop`; `X.Y.Z` on `main`
  after release. Releases via `/merge-main`.

---
Worked tier examples (which tier for which change) and release detail:
`.claude/references/github-strategy-detail.md`. Read it when choosing a tier
for a borderline change or preparing a release.
