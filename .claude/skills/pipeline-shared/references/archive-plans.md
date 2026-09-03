# Archive Planning Docs

Single procedure for archiving a shipped feature's documents into
`archive/{slug}/`. Used by `pipeline-ship` (Step 5) and `commit-and-pr`
(Step 12). Run it only after the final PR for the feature has merged.

It draws from two places. `plans/` holds the five documents each freeze
copies out of the run directory. The run directory holds everything else the
feature produced, and `.gitignore` excludes it, so anything left there is
lost when the directory goes.

## Inputs

- `{slug}` — the feature slug. The caller derives it:
  - pipeline-ship: from `plans/implementation-plan-{slug}.md`
  - commit-and-pr: from the branch name (`feature/get-variance` → `get-variance`)
- `{run-dir}` — the first match for `.surveycore-workspace/runs/*-{slug}/`.
  A branch driven by hand has none; steps 2 and 4 then have nothing to do.

## Procedure

1. **Create** `archive/{slug}/`.

2. **Copy the run documents.** Every `.md` under `{run-dir}`, keeping the
   `prs/pr-{n}-{slug}/` shape:

   ```bash
   find "$run" -name '*.md' ! -name 'status.md' -print0 |
     while IFS= read -r -d '' f; do
       rel=${f#"$run"/}
       mkdir -p "archive/$slug/$(dirname "$rel")"
       cp "$f" "archive/$slug/$rel"
     done
   ```

   This takes `request.md`, `impact.md`, the review documents, every per-PR
   `implementation.md`, `audit.md`, `review.md` and `shipper.md`, and any
   measurement document the run wrote. Gate logs and `status.md` stay
   untracked.

   Copy, not move: the run directory is gitignored and stays for forensics.

3. **Move the `plans/` documents.** Plain files only, never
   `error-messages.md`:

   ```bash
   find plans/ -maxdepth 1 -type f -name "*$slug*" ! -name "error-messages.md"
   ```

   `git mv` each match into `archive/{slug}/`. This catches
   `spec-{slug}.md`, `test-spec-{slug}.md`, `decisions-{slug}.md`,
   `comprehension-{slug}.md` and `implementation-plan-{slug}.md`, and keeps
   the paths `CLAUDE.md` already points at.

4. **Check the citations.**

   ```bash
   bash .claude/skills/pipeline-shared/scripts/check-citations.sh \
     "archive/$slug" "$slug"
   ```

   The script reports every cited `.md` name that resolves to no file, with
   the file and line of each citation. It holds the resolution rules; read it
   there rather than restating them.

   Exit 0 — go to step 5.

   Exit 1 — closeout stops here, before any commit. Each reported name takes
   one of two exits:

   | The document | Do this |
   |---|---|
   | exists, and belongs with the feature | put it in `{run-dir}` and run step 2 again |
   | is gone, or was never written | mark every citation of it (see below) |

   A marker goes on the citation's line, and says which case it is:

   ```
   See `measurements.md` [not archived] M11, which also records the
   No `_snaps/s7-classes.md` [no such file]: S-35 to S-37 take
   ```

   Use `[not archived]` when the document existed and the pipeline lost it.
   Use `[no such file]` when the citation names a document to say it is
   absent. Name the issue that records the loss once per file, in a block
   below the title, rather than at every site.

   A name whose every citation line carries a marker resolves. Re-run the
   script until it exits 0.

5. **Update `CLAUDE.md`**:
   - If a status table row says `planning docs in \`plans/\``, replace with
     `see \`archive/{slug}/\``
   - Reference Documents section: add
     `- \`archive/{slug}/\` — {one-line feature description} (shipped; PRs {merged PR numbers})`

6. **Commit**:

   ```bash
   git add archive/ CLAUDE.md
   git commit -m "chore(plans): archive {slug} planning docs"
   ```

7. **Report** which files were archived, and any citation marked in step 4.

## Completion criterion

`check-citations.sh` exits 0 on `archive/{slug}/`, and every document the
feature produced is either in `archive/{slug}/` or is a gate log.
