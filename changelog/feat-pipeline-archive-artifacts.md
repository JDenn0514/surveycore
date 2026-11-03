# Changelog: feat/pipeline-archive-artifacts

**Branch:** `JDenn0514/the-pipeline-archives-no-measurement-artifacts-d`
**Status:** Complete
**Date:** 2026-09-03

## Summary

Closes #217. The archive step kept five documents per feature — the spec, the
test-spec, the comprehension notes, the plan and the decisions log — and
nothing those documents were argued from. Two narrow rules met: each freeze
copied exactly five artifacts into `plans/`, and the archive step moved files
from `plans/` whose name held the slug. Everything else stayed in
`.surveycore-workspace/`, which `.gitignore` excludes, and died with the run
directory.

`archive/haven-labelled/decisions-haven-labelled.md` settles seven decisions
on measured evidence and cites nine documents for it. None is in the
repository.

The fix has three parts: the archive step copies the run directory too, a
script holds closeout until every cited document resolves, and measurement
documents get a stated home so the copy reaches them.

Documentation and tooling only. Every path changed is excluded by
`.Rbuildignore` — `changelog` (line 5), `.claude` (8), `CLAUDE.md` (9),
`plans` (11), `archive` (18) — so the built package is byte-identical and no
gate figure can move.

### The check earns its place

The design put the resolution rules in prose. `writing-skills` says to
automate a mechanical constraint and keep documentation for judgement calls,
and resolution is mechanical, so `check-citations.sh` holds it. The prose
holds the two exits an operator picks between.

Automating it made it testable, and the test found more than #217 named. The
first run against the real archive reported 13 unresolved names, not 8:

| Finding | Count |
|---|---|
| The eight documents #217 named | 8 |
| `out-of-scope-findings.md` — a ninth lost document | 1 |
| `implementation.md` — resolved once the two survivors were archived | 1 |
| Snapshot files cited as deliberately absent | 2 |
| `tests/testthat/_snaps/conversion.md` — a stale claim | 1 |

The stale claim is the sharpest of these. Both the implementation plan and PR
5's notes say that file "is untouched". It does not exist. Both sites now say
so.

An earlier draft of the check reported 23 names, ten of them noise: six real
repository files cited by partial path, two shell commands inside backticks,
one glob, and one bare name that matched an unrelated file. Resolution rules 3
and 5 and the three skipped shapes came out of reading those ten.

### Rule 5 needs a unique match

A trailing repository path resolves a cited name only when it picks out one
file. `_snaps/utils.md` finds `tests/testthat/_snaps/utils.md`, and bare
`code-style.md` finds `.claude/rules/code-style.md`. Several matches mean the
name is ambiguous.

That case is the one that matters. `implementation.md` names one file per
feature, and many features have one, so a repository-wide match would let
this feature's citation resolve against another feature's copy — which is
what an earlier draft did. Ambiguous names have to resolve inside the archive
directory.

### Two markers, in brackets

A citation fails to resolve for two reasons, so there are two markers:
`[not archived]` when the document existed and the pipeline lost it, and
`[no such file]` when the citation names a document to say it is absent.

Brackets, not parentheses, because most citations already sit inside a
parenthesis. The check reads markers per line rather than per span, so the
marker sits where the prose wants it.

### Other archives, measured but not fixed

#217 said the features before `haven-labelled` lost their evidence too, and
that nobody had checked. Checked now: `dataset-level-metadata` has 4
unresolved names, `var-extension-slot` 2, `polychoric-performance` 0. Left
alone here — each needs the same per-citation judgement pass. Two of the four
are a different defect: a citation whose `plans/…` path went stale when the
archive step moved the file.

## Files Modified

- `.claude/skills/pipeline-shared/scripts/check-citations.sh` — new. Collects
  every inline-code span ending `.md` across an archive directory and reports
  each name that resolves to no file, with the file and line of every
  citation. Five resolution rules; skips spans holding a space, a `*`, or a
  leading `../`; exempts a name whose every citation line carries a marker.
  Reads tracked files plus untracked files that are not gitignored, so it sees
  freshly copied documents before the commit
- `.claude/skills/pipeline-shared/references/archive-plans.md` — takes a run
  directory as a second input; copies every `.md` under it into
  `archive/{slug}/`, keeping the `prs/pr-{n}-{slug}/` shape and skipping
  `*.log` and `status.md`; runs the check; states the two exits and the two
  markers; carries a completion criterion
- `.claude/skills/pipeline-shared/references/workspace-layout.md` — new
  §Measurement documents: a document holding measured evidence goes in the run
  directory. §Lifecycle describes the widened archive step and the check
- `.claude/skills/pipeline-ship/SKILL.md` — Step 5 takes the slug from the run
  directory when no plan file exists, and HOLDs with classification
  `unarchived-citation` when the check stops closeout
- `.claude/skills/commit-and-pr/SKILL.md` — Step 12 reports the check's output
  and lets the user pick each name's exit
- `CLAUDE.md` — the `archive/haven-labelled/` pointer says nine cited
  documents are absent and that every citation carries a marker
- `archive/haven-labelled/decisions-haven-labelled.md` — a block below the
  title listing the eight documents it cites that are gone; `[not archived]`
  at all 15 citation sites
- `archive/haven-labelled/comprehension-haven-labelled.md` — the same block
  for its three; markers at all 19 sites
- `archive/haven-labelled/implementation-plan-haven-labelled.md` — block for
  `plan-review.md`; markers at its 2 sites; `[no such file]` on the three
  snapshot files; the `_snaps/conversion.md` claim now says "is never created"
- `archive/haven-labelled/test-spec-haven-labelled.md` — block for
  `request.md`; marker at its 1 site
- `archive/haven-labelled/prs/pr-5-from-svydesign-metadata/implementation.md`,
  `.../pr-7-polychoric-whole-valued-doubles/implementation.md` — the two
  surviving per-PR notes, archived retroactively. This is what makes the 22
  `implementation.md` citations resolve. PR 5's `_snaps/conversion.md` claim
  is corrected here too
- `plans/spec-pipeline-archive-artifacts.md` — the design, updated to describe
  what shipped
- `changelog/feat-pipeline-archive-artifacts.md` — this entry

## Changes

- Widen `archive-plans.md` to copy every `.md` in the run directory into
  `archive/{slug}/`, so `request.md`, the review documents and each PR's
  `implementation.md`, `audit.md`, `review.md` and `shipper.md` survive the
  feature. Gate logs and `status.md` stay untracked
- Add `check-citations.sh` and hold closeout on any cited document that
  resolves to no file, with two exits: archive it, or mark the citation
- Give measurement documents a home in the run directory, which is what makes
  the copy rule cover them
- Mark all 54 citation sites in `archive/haven-labelled/` and list the missing
  documents below the title of each of the four affected files. No measurement
  is restated or re-derived
- Correct the `_snaps/conversion.md` claim at both sites that make it
- Archive the two surviving per-PR `implementation.md` files

## Verification

No file reaches the built package, so no package gate applies. The procedure
was verified against the real surviving run directory:

| # | Assertion | Result |
|---|---|---|
| 1 | The copy step brings the two `implementation.md` files into `archive/haven-labelled/prs/` | pass |
| 2 | The fifteen `*.log` files stay behind | pass |
| 3 | The check reports the lost documents and halts before committing | pass — 13 names, all genuine |
| 4 | After the markers land, the check exits 0 | pass |

Assertion 4 proves the marker detection, not just the scan.
