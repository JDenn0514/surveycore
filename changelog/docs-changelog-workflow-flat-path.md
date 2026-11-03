# Changelog: docs/changelog-workflow-flat-path

**Branch:** `docs/changelog-workflow-flat-path`
**Status:** Complete
**Date:** 2026-09-09

## Summary

`.claude/skills/changelog-workflow.md` documented a path and an entry format
that no branch has used since 2026-08-25. It said the file goes to
`changelog/phase-{X}/{branch-name}.md`, told the reader to determine the
phase number and to ask the user when unsure, and showed a
`# type(scope): description` title with `**Date**:`, `**Phase**:`, `##
Changes` and `## Files Modified`.

Practice moved. All 30 entries added since sit directly in `changelog/`,
named `{type}-{slug}.md` after the change. They open
`# Changelog: {type}/{slug}`, carry `**Branch:**`, `**Status:**` and
`**Date:**`, and lead with `## Summary`. The last entry written into a phase
directory was `changelog/phase-2/fix-158-roxygen2-s3-exports.md`.

The stale path reached five files, because `commit-and-pr` and two other
skills repeated it rather than pointing at the reference. A branch that
followed the document produced a file in a directory nobody reads. The
release notes still found it — `/merge-main` globs `^changelog/` — so the
drift stayed invisible.

This is documentation only. No skill changes what it does.

## Files Modified

- `.claude/skills/changelog-workflow.md` — flat path and naming rule, the
  real entry format, the optional field and section table, validation rules
  renumbered for `## Summary`, and a worked example taken from a shipped
  entry
- `.claude/skills/commit-and-pr/SKILL.md` — write surface, Step 2 path, and
  the missing-entry report; Step 2 no longer asks the reader to determine a
  phase number
- `.claude/skills/auto-ship/references/section-subagent.md` — two path
  references
- `.claude/skills/implementation-workflow/references/stage-1-draft.md` — one
  path reference
- `.claude/skills/implementation-workflow/references/stage-2-review.md` — one
  path reference
- `changelog/fix-gate-1-document-drift.md` — reshaped to the documented
  format; it was written against the stale document hours earlier and was
  the newest entry a reader would copy

## Changes

- The changelog file goes to `changelog/{type}-{slug}.md`, flat, named after
  the change rather than the branch
- The phase subdirectories are marked historical, with the date of the last
  entry written into one
- The documented entry format matches the entries in the directory: title,
  field block, `## Summary`, `## Files Modified`, `## Changes`, and the
  optional `## Tests` or `## Verification`
- `**Branches:**`, `**PRs:**` and `**Issues:**` are recorded as optional
  fields, which several shipped entries already use
- The reference states what reads these files, so a skipped entry reads as
  a consequence rather than a rule: `/merge-main` drafts the `NEWS.md`
  section from every entry added since the last release tag

## Verification

`grep -rn "changelog/phase-{X}" --include="*.md" .claude/` returns nothing.
The 30 flat entries in `changelog/` all match the documented name shape.
