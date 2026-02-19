# surveycore GitHub Strategy

**Version:** 1.0
**Created:** February 2025
**Status:** Decided — do not re-litigate without updating this document

---

## Quick Reference

| Decision | Choice |
|----------|--------|
| Repository scope | Single repo (`surveycore` only); split when Phase 0.5 begins |
| Starting point | Tag current state `v0.0.0-pre`, continue on `main` |
| Branch protection | CI status checks required; direct push allowed |
| Visibility | Private now; public when `v0.1.0` is tagged |
| Branching model | GitHub Flow — feature branch + self-PR per component |
| Branch naming | `feature/`, `fix/`, `docs/`, `chore/` |
| Phase transitions | Tag each phase completion (`v0.1.0`, `v0.2.0`, etc.) |
| Long-lived branches | None — `main` is always in-progress |
| Commit format | Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `chore:`) |
| PR template | Lightweight checklist (see below) |
| Merge strategy | Squash and merge |
| PR granularity | One PR per test file; split large components |
| Versioning | `0.0.0.9000` → `0.1.0` (Phase 0) → `0.2.0` (Phase 0.5) → `1.0.0` |
| CI setup order | R-CMD-check now → coverage at first tests → pkgdown at Phase 0 done |
| Public release trigger | `v0.1.0` tag exists = flip repo public |
| NEWS.md | Semi-automated from `git log --oneline` of `feat:` and `fix:` commits |

---

## 1. Repository Structure

### Current state
The `surveycore` repo is the only repo. It contains:
- Example datasets (ANES, GSS, Pew, NHANES, ACS PUMS)
- `plans/` documentation
- `DESCRIPTION`, `NAMESPACE`
- No R implementation source yet

### Immediate action: tag before implementation starts
```bash
git tag v0.0.0-pre
git push origin v0.0.0-pre
```
This preserves the pre-implementation baseline permanently. Future work builds forward from here.

### Multi-package future (Phase 0.5+)
When `surveytidy` begins:
1. Decide between **multi-repo** (one repo per package — CRAN-aligned, clean separation) and **monorepo** (all packages in subdirectories — easier cross-package changes). This decision is deferred until then.
2. Do NOT create empty `surveytidy`, `surveyweights`, or `surveyverse` repos now.

---

## 2. Branch Protection

### Settings to configure in GitHub → Settings → Branches → Branch protection rules for `main`:
- **Require status checks to pass before merging:** ✅ (R-CMD-check must be green)
- **Require branches to be up to date before merging:** ✅
- **Require pull request reviews before merging:** ❌ (solo author; add when collaborators join)
- **Allow force pushes:** ❌
- **Allow deletions:** ❌

This means: you CAN push directly to `main` for trivial changes (docs, README tweaks), but CI will flag you immediately if the build is broken. Large components go through a PR.

### Upgrade path
When the first external contributor joins: enable "Require PR reviews (1 reviewer)" and switch from direct push to PR-only on `main`.

---

## 3. Branching Model (GitHub Flow)

### The rule
Every non-trivial change lives on a feature branch and merges via a self-PR. Trivial changes (typos, comment fixes, README edits) can push directly to `main`.

### Branch lifecycle
```
main
 └── feature/s7-classes         # create branch
      └── (commits)
      └── (CI passes)
      └── (self-PR opened)
      └── (checklist checked off)
      └── (squash merge to main)
      └── (branch deleted)
```

### What gets a branch vs. direct push
| Change type | Branch needed? |
|-------------|---------------|
| New R source file | Yes |
| New test file | Yes |
| Any change to exported function | Yes |
| Vendor code addition | Yes |
| README / docs update | No |
| Comment or typo fix | No |
| DESCRIPTION metadata | No |
| `.Rbuildignore` / `.gitignore` | No |

---

## 4. Branch Naming

Format: `{type}/{short-description}`

| Prefix | Use for |
|--------|---------|
| `feature/` | New functionality (new R file, new exported function) |
| `fix/` | Bug fix in existing implementation |
| `docs/` | Documentation-only changes (roxygen, README, vignettes) |
| `test/` | Test-only additions or fixes |
| `chore/` | Maintenance (CI config, DESCRIPTION, build tooling) |
| `refactor/` | Internal restructuring with no behavioral change |

### Examples
```
feature/s7-classes
feature/metadata-system
feature/as-survey
feature/as-survey-rep
feature/as-survey-twophase
feature/print-methods
feature/conversion-to-svydesign
feature/variance-estimation-taylor
fix/weights-validator-zero-check
test/variance-numerical-comparison
chore/r-cmd-check-workflow
docs/readme-usage-examples
```

---

## 5. Component-to-PR Mapping (Phase 0)

The implementation plan has 9 components of varying size. **One PR per test file** is the granularity heuristic. Large components are split; small ones stay together.

| Implementation Plan Component | PRs | Branch names |
|-------------------------------|-----|-------------|
| Component 1: S7 Classes | 1 | `feature/s7-classes` |
| Component 2: Metadata System | 2 | `feature/metadata-extractors`, `feature/metadata-setters` |
| Component 3: Constructors | 3 | `feature/as-survey`, `feature/as-survey-rep`, `feature/as-survey-twophase` |
| Component 4: Update Design | 1 | `feature/update-design` |
| Component 5: Print Methods | 1 | `feature/print-methods` |
| Component 6: Validators | 1 | `feature/validators` |
| Conversion (05-methods-conversion.R) | 2 | `feature/conversion-to-survey`, `feature/conversion-from-survey` |
| Variance Estimation | 2 | `feature/variance-taylor`, `feature/variance-replicate` |
| Test infrastructure | 1 | `feature/test-helpers` |

**Approximate total: ~15 PRs for Phase 0.** Each is a focused, reviewable unit.

---

## 6. Commit Message Format (Conventional Commits)

### Format
```
{type}({scope}): {short description}

[optional body]

[optional footer(s)]
```

### Types
| Type | Use for |
|------|---------|
| `feat` | New exported function, new class, new property |
| `fix` | Bug fix (behavioral change to existing code) |
| `docs` | Roxygen comments, README, vignettes, plans |
| `test` | Adding or updating tests (no production code change) |
| `chore` | CI config, DESCRIPTION, NAMESPACE, build tooling |
| `refactor` | Internal restructuring with no behavioral change |
| `perf` | Performance improvement (Phase 3+) |

### Scopes (optional but useful)
Use the file/module name as scope: `classes`, `constructors`, `metadata`, `validators`, `print`, `variance`, `conversion`

### Examples
```
feat(classes): add survey_base abstract S7 class with 5 properties
feat(constructors): implement as_survey() with tidy-select interface
feat(constructors): implement as_survey_rep() with repweights tidy-select
fix(validators): reject weights=0 in as_survey() with typed error class
test(constructors): add numerical comparison vs survey::svymean for NHANES
docs(constructors): add tidy-select examples to as_survey() roxygen
chore(ci): add R-CMD-check GitHub Actions workflow
chore(description): bump version to 0.1.0 for Phase 0 release
```

### Squash merge commit message
When squashing a PR, the squash commit message becomes the single entry on `main`. Write it as a conventional commit summarizing the whole PR:
```
feat(classes): implement all S7 class definitions with validators (#4)
```
GitHub auto-appends `(#PR_NUMBER)` if you set the PR title as a conventional commit.

---

## 7. PR Template

Create `.github/PULL_REQUEST_TEMPLATE.md`:

```markdown
## What

<!-- One sentence: what does this PR add or fix? -->

## Checklist

- [ ] Tests written and passing (`devtools::test()`)
- [ ] R CMD check: 0 errors, 0 warnings (`devtools::check()`)
- [ ] Roxygen docs updated and `devtools::document()` run
- [ ] `plans/error-messages.md` updated (if new errors/warnings added)
- [ ] `VENDORED.md` updated (if variance code vendored in this PR)
- [ ] PR title is a valid Conventional Commit (`feat(scope): description`)
```

The last item ensures the squash commit message on `main` will be correctly formatted.

---

## 8. Merge Strategy

**Squash and merge** on all PRs. Configure in GitHub → Settings → Pull Requests:
- [x] Allow squash merging
- [ ] Allow merge commits *(disable)*
- [ ] Allow rebase merging *(disable)*
- [x] Automatically delete head branches

This means:
- `main` history = one line per PR (one line per logical unit of work)
- WIP commits, `fix typo`, `oops` commits on feature branches are invisible to `main`
- Full granular history is preserved on the PR page, not polluting `main`

---

## 9. Phase Transitions

### Tagging convention
At the completion of each phase (all quality gates from formal spec Section 10.1 pass):

```bash
# Phase 0 complete
git tag -a v0.1.0 -m "Phase 0 complete: S7 classes, metadata, constructors, variance estimation"
git push origin v0.1.0
```

### Version → phase mapping
| Tag | DESCRIPTION version | What it means |
|-----|---------------------|---------------|
| `v0.0.0-pre` | `0.0.0.9000` | Pre-implementation baseline (datasets + docs only) |
| `v0.1.0` | `0.1.0` | Phase 0 complete — core infrastructure, repo goes public |
| `v0.2.0` | `0.2.0` | Phase 0.5 complete — surveytidy dplyr verbs |
| `v0.3.0` | `0.3.0` | Phase 1 complete — estimation functions |
| `v0.4.0` | `0.4.0` | Phase 2 complete — regression |
| `v1.0.0` | `1.0.0` | Stable API, CRAN submission |

### Dev version during a phase
Between tags, DESCRIPTION carries the `.9000` suffix:
```
Version: 0.1.0.9000  # during Phase 0.5 development
```

---

## 10. CI/CD Workflows

### Setup timeline
| Workflow | When to set up | Trigger |
|----------|----------------|---------|
| `R-CMD-check.yaml` | Day 1 (now) | Push to any branch, PR to `main` |
| `test-coverage.yaml` | When first test file exists | Push to `main`, PRs |
| `pkgdown.yaml` | Phase 0 completion (when docs exist) | Push to `main` only |

### R-CMD-check matrix (standard r-lib template)
```yaml
# .github/workflows/R-CMD-check.yaml
# Use: usethis::use_github_action_check_standard()
# Matrix: {os: [ubuntu-latest, windows-latest, macos-latest], r: [release, devel]}
```

### Required status check for branch protection
Set `R-CMD-check (ubuntu-latest, release)` as the required status check. Windows and macOS checks are informational — they should pass, but a Windows-only failure on a Linux-passing check shouldn't block a merge.

---

## 11. Public Release Process

### When the v0.1.0 tag is ready
1. All Phase 0 quality gates pass (formal spec Section 10.1)
2. Run `devtools::check()` → 0 errors, 0 warnings, ≤2 notes (standard CRAN notes are OK)
3. Write NEWS.md:
   ```bash
   git log --oneline v0.0.0-pre..HEAD | grep -E "^[a-f0-9]+ (feat|fix)" | head -50
   ```
   Copy `feat:` lines as `## New features`, `fix:` lines as `## Bug fixes`
4. Bump DESCRIPTION: `Version: 0.1.0`
5. Commit: `chore(description): bump version to 0.1.0 for Phase 0 release`
6. Tag: `git tag -a v0.1.0 -m "Phase 0 complete"`
7. Push tag: `git push origin v0.1.0`
8. **Flip repo to public** in GitHub → Settings → Danger Zone → Change visibility
9. Create a GitHub Release from the tag with NEWS.md content as the release body

### README at public launch
The README must include:
- Installation: `pak::pak("yourusername/surveycore")`
- What Phase 0 provides (classes, metadata, constructors)
- What's coming (estimation functions in Phase 1)
- Link to pkgdown site

---

## 12. What Is NOT Decided Here

The following are out of scope for this document and should be decided separately:

- **Multi-repo vs. monorepo** for the full surveyverse ecosystem (defer to Phase 0.5)
- **CRAN submission strategy** (timing, CRAN policies, reverse dependency checks)
- **Contributor guidelines** (`CONTRIBUTING.md`) — needed before external contributors join
- **Code of Conduct** — needed before going public if you want community contributions
- **GitHub Discussions / Issues templates** — nice to have at public launch
- **pkgdown site domain** (GitHub Pages default vs. custom domain)

---

## 13. Immediate Action Items (Day 1)

In order:

1. `git tag v0.0.0-pre && git push origin v0.0.0-pre`
2. Set repo to **Private** in GitHub settings (if not already)
3. Create `.github/PULL_REQUEST_TEMPLATE.md` (content in Section 7)
4. Run `usethis::use_github_action_check_standard()` → commit as `chore(ci): add R-CMD-check workflow`
5. Configure branch protection for `main` (Section 2 settings)
6. Disable "Allow merge commits" and "Allow rebase merging" in GitHub Settings → Pull Requests (Section 8)
7. Enable "Automatically delete head branches" in GitHub Settings → Pull Requests
8. Start `feature/test-helpers` branch (helper-test-data.R is prerequisite for all test files)
