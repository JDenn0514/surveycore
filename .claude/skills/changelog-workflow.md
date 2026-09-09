# Changelog Workflow

This is a reference document, not an invocable skill. It defines the canonical
changelog format enforced by `commit-and-pr`.

Each branch adds one file under `changelog/`. `/merge-main` reads every file
added since the last release tag and drafts the `NEWS.md` section from them
(`git diff <last-tag>..develop --name-only | grep "^changelog/"`). A branch
that adds no file is invisible to the release notes.

---

## Location and Timing

```
Location:  changelog/{type}-{slug}.md
Timing:    Created LAST on the branch, BEFORE opening the PR
Populated: From git log develop..HEAD --oneline
```

The file sits directly in `changelog/`. There is no subdirectory.

- `{type}` is the Conventional Commit type of the work: `feat`, `fix`,
  `docs`, `test`, `chore`, or `refactor`.
- `{slug}` is a short kebab-case name for the change, three or four words.
  It describes the change, not the branch — orca branch names such as
  `JDenn0514/run-gates.sh-gate-1-reports-document-drift-for-a` make poor
  file names, and the branch is recorded in a field inside the file instead.

Examples from `changelog/`: `fix-design-dim.md`,
`docs-nrow-dim-stored-row-count.md`, `chore-srr-roclet-registration.md`.

The `changelog/phase-0/`, `phase-1/`, `phase-2/`, `phase-0.75/` and
feature-named subdirectories hold entries from the phase-numbered era. They
are historical. Nothing new goes in them; the last one was added
2026-08-25. Do not ask which phase the work belongs to.

---

## Entry Format

```markdown
# Changelog: {type}/{slug}

**Branch:** `{branch-name}`
**Status:** Complete
**Date:** YYYY-MM-DD

## Summary

Two to four paragraphs. State what was wrong and what the change does.
Open with `Closes #N.`, `Fixes #N.` or `Refs #N.` when an issue drove the
work. Add `###` subsections for a point that needs its own argument.

## Files Modified

- `R/[file].R` — [one sentence describing what changed in this file]
- `tests/testthat/test-[file].R` — [one sentence]

## Changes

- [Bullet derived from commit messages describing what changed]
- [One bullet per logical change, not one per commit]
```

Optional fields, in the block under the title:

| Field | Use |
|---|---|
| `**Branches:**` | Replaces `**Branch:**` when several branches shipped one feature. List them all. |
| `**PRs:**` | The PR numbers, when the entry covers more than one. |
| `**Issues:**` or `**Issue:**` | The issue numbers the work closes. |

Optional trailing sections: `## Tests` or `## Verification`, for the
measurement that backs the entry. Add one when a number is the evidence —
a benchmark, a coverage figure, a before-and-after table.

`## Files Modified` comes before `## Changes` in most entries. A long
multi-PR entry may put `## Changes` first, so the reader meets the work
before the file list.

---

## Deriving Content from Commits

Run `git log develop..HEAD --oneline` to get the commit list. Use those
messages to populate the `## Changes` section. Group related commits into
single bullets where appropriate (e.g., a sequence of "fix: " commits that
address the same issue can be one bullet).

---

## Validation Rules

These are enforced by `commit-and-pr` before a PR is opened:

1. File must exist at `changelog/{type}-{slug}.md`, directly in `changelog/`
2. File must not be empty or a stub (no `<!-- TODO -->` placeholders)
3. `## Summary` section must have at least one paragraph
4. `## Changes` section must have at least one bullet
5. `## Files Modified` section must list at least one file
6. `**Date:**` must be a real date (not a placeholder)

---

## Example

For a branch `fix/design-dim`:

```markdown
# Changelog: fix/design-dim

**Branch:** `fix/design-dim`
**Status:** Complete
**Date:** 2026-09-08

## Summary

Refs #203. `nrow()`, `ncol()` and `dim()` returned `NULL` on every survey
design class. `NULL` is the one return value that fails silently: the
objects print like data frames, `NULL` is not an error, and nothing
signalled that the answer was wrong.

## Files Modified

- `R/methods-base.R` — registers the `dim()` method the three functions read

## Changes

- Register `dim()` for `survey_base`, so `nrow()` and `ncol()` report the
  stored row and column counts
```
