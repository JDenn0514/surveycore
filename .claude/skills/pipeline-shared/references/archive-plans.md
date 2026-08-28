# Archive Planning Docs

Single procedure for moving a shipped feature's planning docs from `plans/`
to `archive/{slug}/`. Used by `pipeline-ship` (Step 5) and `commit-and-pr`
(Step 12). Run it only after the final PR for the feature has merged.

## Inputs

- `{slug}` — the feature slug. The caller derives it:
  - pipeline-ship: from `plans/implementation-plan-{slug}.md`
  - commit-and-pr: from the branch name (`feature/get-variance` → `get-variance`)

## Procedure

1. **Find matching files** in `plans/` (plain files only, never
   `error-messages.md`):

   ```bash
   find plans/ -maxdepth 1 -type f -name "*{slug}*" ! -name "error-messages.md"
   ```

   This catches `spec-{slug}.md`, `test-spec-{slug}.md`, `decisions-{slug}.md`,
   `comprehension-{slug}.md`, `implementation-plan-{slug}.md`, etc. Files whose
   names do not contain the slug are not moved — name artifacts with the slug
   during planning so they are picked up.

   If no files match, skip the rest silently — do not prompt the user.

2. **Move**:
   a. Create `archive/{slug}/`
   b. `git mv` each matched file into `archive/{slug}/`

3. **Update `CLAUDE.md`**:
   - If a status table row says `planning docs in \`plans/\``, replace with
     `see \`archive/{slug}/\``
   - Reference Documents section: add
     `- \`archive/{slug}/\` — {one-line feature description} (shipped; PRs {merged PR numbers})`

4. **Commit**:

   ```bash
   git add CLAUDE.md
   git commit -m "chore(plans): archive {slug} planning docs"
   ```

5. **Report** which files were archived.
