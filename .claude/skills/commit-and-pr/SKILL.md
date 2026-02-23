---
name: commit-and-pr
description: >
  Use when work is complete and needs to be committed and submitted as a pull
  request. Trigger when the user says "commit", "make a PR", "open PR", "submit
  this work", "PR time", or "commit and PR". CRITICAL: This skill does NOT write
  or edit R source files, test files, or any source code. If code changes are
  needed before the PR, use r-implement first.
---

# Commit and PR Skill

## HARD CONSTRAINT — READ THIS FIRST

**YOU ARE A COMMIT/PR AGENT.**

You CANNOT write, edit, or create:
- `.R` source files
- `.R` test files
- Any other source code

If you notice code that should change, add a `TODO:` note to the PR body
describing the issue, and report it to the user. Do NOT touch the code.

**The ONLY files you may create or edit:**
- `changelog/phase-{X}/{branch-name}.md` — the changelog entry for this branch

If you find yourself about to use the Edit or Write tool on a `.R` file,
**stop immediately and tell the user what you found**. Ask them whether to
invoke `r-implement` to address it, or note it as a TODO in the PR.

---

## Step 1: Orientation

Run these first, before anything else:

```bash
git branch --show-current
git log main..HEAD --oneline
git status
```

**If on `main`: STOP.** Inform the user that implementation work must be on a
feature branch. Do not proceed.

---

## Step 2: Changelog Entry (REQUIRED before any commit)

Read `.claude/skills/changelog-workflow.md` for the canonical format.

The changelog file lives at: `changelog/phase-{X}/{branch-name}.md`

Steps:
1. Determine the phase from the branch name (e.g., `feature/variance-twophase`
   suggests Phase 0.75) — ask the user if unclear
2. Check if `changelog/phase-{X}/{branch-name}.md` exists
3. **If it does not exist:** create it following `changelog-workflow.md`,
   using `git log main..HEAD --oneline` to populate the `## Changes` section
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

Stage SPECIFIC files by name — never `git add -A` or `git add .`.

Always include the changelog file in the staged set.

Commit format, valid types, and valid scopes: see `github-strategy.md §6`.

Pass the commit message via HEREDOC:
```bash
git commit -m "$(cat <<'EOF'
feat(variance): implement two-phase Taylor variance estimation

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
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

If a PR already exists: report its URL and stop. Do not create a second PR.

---

## Step 6: Draft and Approve PR

PR template: see `github-strategy.md §7`.

Draft a PR title (Conventional Commit format) and body following that template.
**Show the draft to the user before creating.** Ask for approval. Revise if
requested. Do NOT create the PR until the user approves.

---

## Step 7: Push and Create PR

```bash
git push -u origin <branch-name>

gh pr create \
  --title "<approved-title>" \
  --body "$(cat <<'EOF'
<approved-body>
EOF
)"
```

Capture and report the PR URL.

---

## Step 8: Monitor CI

```bash
# Get the run ID
gh run list --branch <branch-name> --limit 3

# Watch until completion (redirect output — it's very verbose)
gh run watch <run-id> --exit-status > /dev/null 2>&1
echo "Exit: $?"
```

**If CI fails:**
1. Get the failure details:
   ```bash
   gh run view <run-id>
   gh run view <run-id> --log-failed 2>&1 | tail -40
   ```
2. Report the failure to the user
3. **DO NOT write code to fix it** — that violates the hard constraint above
4. Ask the user to invoke `r-implement` to address the failure
5. After `r-implement` reports done, re-run `commit-and-pr`

---

## Step 9: Done

When CI passes:

1. Report the PR URL
2. Read the implementation plan and find the first remaining `- [ ]` section
3. Report:

   > "Next section: `branch-name` — [description]. Start a new session with
   > `/r-implement` to continue."

**Do NOT merge the PR.** Merging is the user's decision.

---

## Quick Reference: What This Skill CAN and CANNOT Do

| Action | Allowed? |
|---|---|
| Read `.R` files to understand what was implemented | Yes |
| Create `changelog/phase-{X}/{branch-name}.md` | Yes |
| Run `devtools::check()` and `devtools::test()` | Yes |
| Stage and commit files | Yes |
| Push the branch | Yes |
| Create the PR | Yes |
| Monitor CI | Yes |
| Report CI failures | Yes |
| Write or edit `.R` source files | **NO** |
| Write or edit `.R` test files | **NO** |
| Fix failing tests | **NO** |
| Fix R CMD check errors | **NO** |
| Amend commits | **NO** |
| Merge the PR | **NO** |
