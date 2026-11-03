---
name: merge
description: >
  Merges an open pull request targeting `develop` after CI passes. Trigger on
  "merge this" or any phrase combining "merge" with a branch or PR reference
  (e.g., `/merge 42`). Never merges to `main` — use `/merge-main` for
  releases.
---

# Merge Skill

**Announce at start:** "Running merge skill."

## HARD CONSTRAINTS — READ THIS FIRST

- **Never merge to `main`.** If the PR targets `main`, abort immediately and
  redirect the user to `/merge-main`.
- **Never merge when any CI check is failing.** If CI has failures, stop and
  hand off to `r-implement`.
- **Always require explicit user confirmation** before executing the merge.
- Cannot write or edit `.R` source files or test files.

---

## Step 1 — Find the PR

```bash
gh pr view --json number,title,baseRefName,headRefName,url,statusCheckRollup
```

- If an explicit PR number was passed (e.g., `/merge 42`), use:
  ```bash
  gh pr view 42 --json number,title,baseRefName,headRefName,url,statusCheckRollup
  ```
- If no PR exists for the current branch, report:
  > "No open PR found for this branch. Open a PR first (e.g., with
  > `/commit-and-pr`), then re-invoke `/merge`."
  Stop.

Store: `prNumber`, `prTitle`, `baseRefName`, `prUrl`, `statusCheckRollup`.

---

## Step 2 — Verify target is `develop`

If `baseRefName != "develop"`:

> "PR #N targets `{baseRefName}`, not `develop`. This skill only merges
> feature branches to `develop`. For releases, use `/merge-main`."

Stop immediately.

---

## Step 3 — Check CI status

Inspect `statusCheckRollup` from Step 1:

| Check state | Action |
|---|---|
| All checks `SUCCESS` | Proceed to Step 4 |
| Any check `IN_PROGRESS` or `QUEUED` | Wait — see below |
| Any check `FAILURE` | Show failure summary, stop — see CI failure block below |
| No checks (empty rollup) | Warn user that CI has not run yet; ask whether to proceed or wait |

**Waiting for in-progress CI:**

Find the run ID from the rollup (or via `gh run list --branch <branch> --limit 1`)
and watch it:

```bash
gh run watch <run-id> --exit-status
```

This blocks until the run completes. If it exits non-zero, treat as FAILURE.

**CI failure handoff block:**

```
CI check failed for PR #N.

Failed check: <check-name>
Run URL: <run-url>

Invoke `/r-implement` to diagnose and fix the failure, then re-invoke
`/merge` after the fix is pushed and CI passes.
```

Stop.

---

## Step 4 — Confirmation gate

Show and wait for explicit user approval:

> "CI passed. PR #N (`{headRefName}` → `develop`): *{prTitle}*
>
> Squash-merge this PR?"

Do NOT proceed until the user says yes (or equivalent affirmative). If the
user says no or asks to cancel, stop and report: "Merge cancelled."

---

## Step 5 — Squash merge

The squash merge happens via the GitHub API — no local checkout is needed
for the merge itself, so run it without `--delete-branch`:

```bash
gh pr merge <prNumber> --squash
```

If the command fails, report the error verbatim and stop.

**Do not add `--delete-branch` here.** In a multi-worktree checkout it also
tries to check out the base branch (`develop`) in the current worktree as
part of local cleanup. If `develop` is already checked out in another
worktree, that checkout fails with something like `fatal: 'develop' is
already used by worktree at ...` and the branch cleanup half-fails even
though the merge itself succeeded.

**Branch cleanup** (after a successful merge):

Check `git worktree list` for a worktree other than the main working
directory that has `headRefName` checked out. If one exists, remove it
first — this is what's holding the branch checked out:

```bash
git worktree remove <worktree-path>
```

Then delete the remote and local branches:

```bash
git push origin --delete <headRefName>
git branch -D <headRefName>
```

If no worktree is involved, `git branch -D <headRefName>` can run directly
after the remote delete.

---

## Step 6 — Done

Report:

> "Merged: {prUrl}"

Then check whether an implementation plan exists in `plans/`. If one is
found, locate the first remaining `- [ ]` section and report:

> "Next section: `{branch-name}` — {description}. Start a new session with
> `/r-implement` to continue."

If no plan is found, report done with no next-step suggestion.
