---
name: commit-and-pr
description: >
  Commits staged changes, opens a pull request against develop, and monitors CI
  for surveycore feature branches. Does not write or edit R source files or
  test files; use r-implement for code changes first.
  Trigger when the user says "commit", "make a PR", "open PR", "submit this
  work", "PR time", "commit and PR", "commit and merge", "commit, PR, and merge",
  "ship it", or "land it".
---

# Commit and PR Skill

**Announce at start:** "Running commit-and-pr skill."

## HARD CONSTRAINT — READ THIS FIRST

**Your write surface is exactly one file:**
`changelog/phase-{X}/{branch-name}.md` — the changelog entry for this branch.
Everything else in this skill is git, `gh`, and R check commands.

If you notice code that should change, add a `TODO:` note to the PR body,
report it to the user, and ask whether to invoke `r-implement` or note it as
a TODO. Code changes belong to `r-implement`.

---

## Session Recovery — Check This Before Starting

The environment is the source of truth. Derive the resume point:

```bash
gh pr view --json state,mergedAt,url 2>/dev/null
gh run list --branch <branch-name> --limit 1
```

| Observation | Resume point |
|---|---|
| No PR for this branch | Step 1 (fresh start) |
| PR open, CI queued or running | Step 8 (monitor CI) |
| PR open, latest CI run failed | Step 9 (handoff — see `refs/ci-monitoring.md`) |
| PR open, CI passed, not merged | Step 10 |
| PR merged | Step 12 (archive), then done |

---

## Step 1: Orientation

Run these first, before anything else:

```bash
git branch --show-current
git log develop..HEAD --oneline
git status
```

**If on `main` or `develop`: STOP.** Inform the user that implementation work
must be on a feature branch cut from `develop`. Do not proceed.

**Detect merge intent:** Check whether the user's invocation included any of
these phrases: "commit and merge", "commit, PR, and merge", "ship it",
"land it". If yes, announce: "Merge after CI will be performed." Remember
this merge intent for Step 10. On a resumed session, the intent is lost —
the user re-requests the merge or runs `/merge`.

---

## Step 2: Changelog Entry (REQUIRED before any commit)

Read `.claude/skills/changelog-workflow.md` for the canonical format.

The changelog file lives at: `changelog/phase-{X}/{branch-name}.md`

Steps:
1. Determine the phase per `changelog-workflow.md` §Location and Timing —
   ask the user if unclear
2. Check if `changelog/phase-{X}/{branch-name}.md` exists
3. **If it does not exist:** create it following `changelog-workflow.md`,
   using `git log develop..HEAD --oneline` to populate the `## Changes` section
4. **If it exists:** verify it is populated — not empty, no `<!-- TODO -->`
   placeholders, `## Changes` has at least one real bullet

**If the changelog entry is missing or empty, STOP and report:**

```
No changelog entry found for this branch.

Expected: changelog/phase-{X}/{branch-name}.md

The changelog entry must be created before opening the PR.
```

Do not proceed to pre-flight or commits until the changelog entry exists and
is populated.

---

## Step 3: Pre-flight Checks

Run AFTER the changelog entry is confirmed:

```bash
Rscript -e "devtools::check()"
Rscript -e "devtools::test()"
```

**If either fails: STOP.** Inform the user of the failure. Do not proceed to
commits. Ask the user to invoke `r-implement` to fix the issue, then re-invoke
`commit-and-pr`.

Required results:
- `devtools::check()` — 0 errors, 0 warnings, ≤2 notes
- `devtools::test()` — no failures

---

## Step 4: Stage and Commit

```bash
git status
```

Review the changed files list. If any `.R` source or test files appear that
were not part of this implementation task, stop and report to the user before
staging — unexpected `.R` changes need investigation.

Stage SPECIFIC files by name — never `git add -A` or `git add .`.

Always include the changelog file in the staged set.

Commit format, valid types, and valid scopes: see github-strategy.md (Commit
Format section). End the message with the Co-Authored-By trailer the session
guidance specifies.

Pass the commit message via HEREDOC:
```bash
git commit -m "$(cat <<'EOF'
feat(variance): implement two-phase Taylor variance estimation

Co-Authored-By: <trailer from session guidance>
EOF
)"
```

**Rules:**
- Never amend; always create new commits for fixes
- Never skip pre-commit hooks (`--no-verify`)
- If a pre-commit hook fails: fix the issue, re-stage, create a NEW commit
  (do not amend)

---

## Step 5: Check for Existing PR

Before creating a PR, verify one doesn't already exist:

```bash
gh pr view 2>/dev/null && echo "PR EXISTS" || echo "NO PR"
```

If a PR already exists: report its URL and skip to Step 8 (Monitor CI).

---

## Step 6: Draft and Approve PR

PR template: see `refs/feature-pr-template.md`.

Draft a PR title (Conventional Commit format) and body following that template.
**Show the draft to the user before creating.** Ask for approval. Revise if
requested. Do NOT create the PR until the user approves.

---

## Step 7: Push and Create PR

```bash
git push -u origin <branch-name>

gh pr create \
  --base develop \
  --title "<approved-title>" \
  --body "$(cat <<'EOF'
<approved-body>
EOF
)"
```

Report the PR URL to the user.

---

## Step 8: Monitor CI

Read `refs/ci-monitoring.md` for the complete monitoring and failure-handoff
procedure (it contains Step 9). Return here for Step 10 when CI passes.

---

## Step 10: CI Passed — Merge Check

When CI passes, check the merge intent from Step 1:

- **Merge requested:** Proceed to Step 11.
- **No merge requested:** Stop after CI (see "Done without merge" below).
  When in doubt, stop after CI.

**Done without merge:**

1. Report the PR URL
2. Read the implementation plan and find the first remaining `- [ ]` section
3. Report:

   > "Next section: `branch-name` — [description]. Start a new session with
   > `/r-implement` to continue."

---

## Step 11: Optional Merge (only when merge was requested at invocation)

Invoke the `merge` skill (`/merge <prNumber>`). It verifies the PR targets
`develop`, checks CI, asks the user for explicit confirmation, and
squash-merges. If the user declines, the merge skill stops — do not retry.

After a successful merge, proceed to Step 12.

---

## Step 12: Archive Plan Files (post-merge only)

Extract the feature slug from the branch name (e.g., `feature/get-variance` →
`get-variance`, `fix/pool-pvals-edge-case` → `pool-pvals-edge-case`).

Run the archive procedure in
`.claude/skills/pipeline-shared/references/archive-plans.md`.

Its step 4 stops closeout when a cited document resolves to no file. Report
the script's output and let the user pick each name's exit; the two exits are
in `archive-plans.md` step 4.

After archiving (or skipping), read the implementation plan and report the
first remaining `- [ ]` section as the next action (same as the "Done without
merge" step above).
