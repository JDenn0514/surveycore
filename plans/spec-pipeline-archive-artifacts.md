# Spec — the pipeline archives its measurement artifacts

**Issue**: #217
**Status**: BUILT — describes what shipped
**Date**: 2026-09-03
**Slug**: `pipeline-archive-artifacts`

## Problem

A shipped feature's `archive/{slug}/` directory keeps five documents: the spec,
the test-spec, the comprehension notes, the implementation plan and the
decisions log. It keeps nothing those documents were argued from.

The cause is two narrow rules that meet:

1. Each pipeline freeze copies exactly five artifacts from the run directory
   into `plans/` (`workspace-layout.md` §Lifecycle).
2. `archive-plans.md` moves files from `plans/` whose name contains the slug.

Everything else stays in `.surveycore-workspace/`, which `.gitignore` excludes.
When the run directory is deleted, the evidence goes with it.

## Evidence

`archive/haven-labelled/decisions-haven-labelled.md` settles seven decisions,
D1 to D7, and cites eight documents for the measurements behind them. None of
the eight exists on any branch.

Two more archived files cite the same missing documents:

| File | Lost documents cited |
|---|---|
| `decisions-haven-labelled.md` | eight — `measurements.md`, `verification-d4.md`, `verification-d5.md`, `audit-empirical.md`, `audit-addendum.md`, `spec-review.md`, `plan-review.md`, `request.md` |
| `comprehension-haven-labelled.md` | three — `audit-empirical.md` (13 sites), `request.md` (6 sites), `out-of-scope-findings.md` (1 site) |
| `implementation-plan-haven-labelled.md` | one — `plan-review.md` (2 sites) |
| `test-spec-haven-labelled.md` | one — `request.md` (1 site) |

The surviving run directory holds two `implementation.md` files and fifteen
gate logs. It holds none of the nine.

This is a gap in the pipeline, not a mistake in the `haven_labelled` work.

## Decisions

| # | Question | Decision |
|---|---|---|
| A | Which run artifacts get archived? | Every `.md` in the run directory. Logs and `status.md` stay untracked. |
| B | How is a missing citation caught? | A script, run at archive time. A name that resolves nowhere halts closeout. |
| C | Where does the widened rule live? | In `archive-plans.md`, rewritten. No second procedure. |
| D | What happens to `haven-labelled`? | Every citation site gets a marker. No measurement is restated or re-derived. |

Decision B changed during the build. The design put the resolution rules in
prose for the agent to apply. `writing-skills` says to automate a mechanical
constraint and save documentation for judgement calls, and resolution is
mechanical: `check-citations.sh` now holds it, and the prose holds only the
two exits an operator chooses between.

## Design

### 1. `archive-plans.md` reads the run directory first

The procedure keeps its name, its two callers and its call sites. Its inputs
grow from one to two:

- `{slug}` — as today, derived by the caller.
- `{run-dir}` — the first match for `.surveycore-workspace/runs/*-{slug}/`.
  Absent for a branch driven by hand through `commit-and-pr`.

Steps: create the directory; copy every `.md` under `{run-dir}`, keeping the
`prs/pr-{n}-{slug}/` shape and skipping `*.log` and `status.md`; `git mv` the
`plans/*{slug}*` files as before; run the check; update `CLAUDE.md`; commit.

Copies, not moves: the run directory is gitignored and stays for forensics.

Archived run documents keep their run filenames — `request.md`,
`spec-review.md`, `prs/pr-5-from-svydesign-metadata/implementation.md`.
Citations are written as bare names, so the run names are what makes them
resolve. The five documents that arrive from `plans/` keep their existing
slug-suffixed names.

### 2. The check

`.claude/skills/pipeline-shared/scripts/check-citations.sh <archive-dir> <slug>`

It collects every inline-code span ending in `.md` across the archived
documents, and reports each name that resolves to no file, with the file and
line of every citation. Exit 1 on any such name.

Three shapes are not filenames and are skipped: a span containing a space (a
shell command), a span containing `*` (a glob), and a path starting `../`.

A name resolves when any of these finds a file:

| # | Rule | Resolves |
|---|---|---|
| 1 | `{archive-dir}/{name}` | `request.md` beside the other archived docs |
| 2 | `{archive-dir}/{stem}-{slug}.md` | a citation of `spec.md` finds `spec-haven-labelled.md` |
| 3 | any path under `{archive-dir}` ending in `/{name}` | `implementation.md` finds `prs/pr-5-…/implementation.md` |
| 4 | an exact repository path | `plans/error-messages.md`, `CLAUDE.md` |
| 5 | exactly one repository path ending in `/{name}` | `_snaps/utils.md` finds `tests/testthat/_snaps/utils.md`; bare `code-style.md` finds `.claude/rules/code-style.md` |

Rule 5 requires a unique match on purpose. A pipeline artifact name is the
case that matters: `implementation.md` names one file per feature, and many
features have one, so a repo-wide match would let this feature's citation
resolve against another feature's copy. Ambiguous names have to resolve
inside the archive directory, which rule 3 already tried.

The check reads tracked files plus untracked files that are not gitignored,
so it sees the freshly copied archive documents before the commit.

### 3. The two exits

Exit 1 stops closeout before any commit. Each reported name takes one of two
exits, and the caller surfaces the choice to the user:

| The document | Do this |
|---|---|
| exists, and belongs with the feature | put it in `{run-dir}` and run the copy step again |
| is gone, or was never written | mark every citation of it |

### 4. The markers

Two, because a citation fails to resolve for two different reasons:

```
See `measurements.md` [not archived] M11, which also records the
No `_snaps/s7-classes.md` [no such file]: S-35 to S-37 take
```

`[not archived]` — the document existed and the pipeline lost it.
`[no such file]` — the citation names a document to say it is absent.

Brackets, not parentheses, because most citations already sit inside a
parenthesis: `` (`audit-empirical.md` [not archived] §4) `` reads; the same
line with nested parentheses does not.

The check reads markers per line, not per span, so the marker can sit where
the prose wants it rather than always immediately after the backtick.

Each affected file also carries a block below its title, listing the
documents it cites that are gone and naming issue #217 once. The list entries
carry the marker too, so the notice satisfies its own check.

### 5. Measurement documents get a stated home

`workspace-layout.md` gains one rule: a document holding measured evidence
goes in the run directory, beside `spec.md`. That is what turns "every `.md`
in the run directory" into full coverage — `measurements.md` and
`verification-d4.md` were lost because no rule said where they live.

### 6. `haven-labelled` remediation

Every citation of the nine lost documents carries `[not archived]`. Four
files carry a block. The three snapshot files cited as absent carry
`[no such file]`.

Restate no measurement. Re-derive no measurement. The argument in each
decision stays checkable on its own terms; the evidence is marked absent.

The two surviving `implementation.md` files are archived retroactively, which
is what makes the 22 `implementation.md` citations resolve.

## What the check found

The design predicted eight missing documents. The check reported thirteen on
the first run against the real archive:

| Finding | Count |
|---|---|
| The eight the issue named | 8 |
| `out-of-scope-findings.md` — a ninth lost document the issue missed | 1 |
| `implementation.md` — resolved once the two survivors were archived | 1 |
| Snapshot files cited as deliberately absent | 2 |
| `tests/testthat/_snaps/conversion.md` — a stale claim: the plan and PR 5's notes both say it "is untouched", and the file does not exist | 1 |

An earlier draft of the check reported 23, of which ten were noise — six real
repo files cited by partial path, two shell commands inside backticks, one
glob, and one bare name that matched an unrelated file. Rules 3 and 5 and the
three skipped shapes came out of reading those ten.

## Verification

No R code changes, so no package gate applies.

| # | Assertion | Result |
|---|---|---|
| 1 | The copy step brings the two `implementation.md` files into `archive/haven-labelled/prs/` | pass |
| 2 | The fifteen `*.log` files stay behind | pass |
| 3 | The check reports the lost documents and halts before committing | pass — 13 names, all genuine |
| 4 | After the markers land, the check exits 0 | pass |

Assertion 4 is the one that proves the marker detection works, not just the
scan.

## Other archives

The issue said the features before `haven-labelled` lost their evidence too,
and that nobody had checked. Measured:

| Archive | Unresolved |
|---|---|
| `haven-labelled` | 0 after this work |
| `dataset-level-metadata` | 4 — `baseline.md`, `spec-review.md`, and two stale `plans/…` paths for files now in `archive/` |
| `var-extension-slot` | 2 — `implementation.md`, `plan-review.md` |
| `polychoric-performance` | 0 |

Out of scope here. Each needs the same per-citation judgement pass, and the
`plans/…` rows are a different defect: a citation whose path went stale when
the archive step moved the file.

## Known limit — naming is not citing

The check cannot tell a citation from a mention of an artifact type. Both are
an inline-code span ending `.md`.

Measured on this document. Archiving it produced 13 unresolved names, of
which 11 were not citations at all: `implementation.md` at nine sites,
`status.md` at two, `baseline.md` at one. Each names a document type, and
those documents exist — one `implementation.md` per PR, one `status.md` per
run. Marking them would put a false claim in the record, and rewording them
to drop the backticks would damage a document whose whole subject is specific
filenames.

So this document stays in `plans/`, which the check never scans. That is
also where `plans/spec-reduce-token-usage.md` sits after #157 shipped.

The rule: a document that names pipeline artifacts as types belongs in
`plans/`. A document that cites them as sources belongs in `archive/{slug}/`,
where the check holds it honest. A feature's spec, test-spec, comprehension
notes and decisions log are all the second kind. A spec about the pipeline
itself is the first.

Dogfooding the check on this document also found three defects in it, since
fixed: it flagged `` `.md` `` from prose about spans ending in `.md`, the
template `` `{archive-dir}/{stem}-{slug}.md` ``, and the elided path
`` `prs/pr-5-…/implementation.md` ``. A span holding `{`, a span holding `…`,
and a bare extension are now skipped alongside shell commands and globs.

## Out of scope

- Archiving gate logs. They stay untracked. An `audit.md` that cites a gate
  result carries the numbers, and `audit.md` is now archived.
- Recovering the nine `haven-labelled` documents. They are gone.
- Remediating `dataset-level-metadata` and `var-extension-slot`.
- Renaming the five slug-suffixed archived filenames.
- The empty `pr-3a-labelled-class-strip-setter/` directory behind #216. The
  gate 17 and gate 18 measurements were logs, and logs stay untracked.
