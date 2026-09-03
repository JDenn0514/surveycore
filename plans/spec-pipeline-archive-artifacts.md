# Spec — the pipeline archives its measurement artifacts

**Issue**: #217
**Status**: DRAFT — awaiting user review
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

| File | Cites |
|---|---|
| `decisions-haven-labelled.md` | `measurements.md`, `verification-d4.md`, `verification-d5.md`, `audit-empirical.md`, `audit-addendum.md`, `spec-review.md`, `plan-review.md`, `request.md` |
| `comprehension-haven-labelled.md` | `audit-empirical.md` (13 sites), `request.md` (6 sites) |
| `test-spec-haven-labelled.md` | `request.md` (1 site) |

The surviving run directory holds two `implementation.md` files and fifteen
gate logs. It holds none of the eight.

This is a gap in the pipeline, not a mistake in the `haven_labelled` work. The
next feature loses its evidence the same way.

## Decisions

| # | Question | Decision |
|---|---|---|
| A | Which run artifacts get archived? | Every `.md` in the run directory. Logs and `status.md` stay untracked. |
| B | How is a missing citation caught? | A citation check at archive time. An unresolved citation halts closeout. |
| C | Where does the widened rule live? | In `archive-plans.md`, rewritten. No second procedure. |
| D | What happens to `haven-labelled`? | Each citation site gets a marker. No measurement is restated or re-derived. |

## Design

### 1. `archive-plans.md` reads the run directory first

The procedure keeps its name, its two callers and its call sites. Its inputs
grow from one to two:

- `{slug}` — as today, derived by the caller.
- `{run-dir}` — the first match for `.surveycore-workspace/runs/*-{slug}/`.
  Absent for a branch driven by hand through `commit-and-pr`.

Steps:

1. **Copy the run documents.** Copy every `*.md` under `{run-dir}` into
   `archive/{slug}/`, keeping the `prs/pr-{n}-{slug}/` subdirectory shape.
   Skip `*.log` and `status.md`. Copy, do not move: the run directory is
   gitignored and stays in place for forensics.
2. **Move the `plans/` documents.** `git mv` each `plans/*{slug}*` file into
   `archive/{slug}/`, as the procedure does today. This keeps the five
   slug-suffixed paths that `CLAUDE.md` points at.
3. **Run the citation check** (§2). An unresolved citation stops the procedure
   here, before any commit.
4. **Update `CLAUDE.md`** and commit, as the procedure does today.

When `{run-dir}` is absent, step 1 and step 3 are skipped and the procedure
behaves as it does today.

Archived run documents keep their run filenames — `request.md`,
`spec-review.md`, `prs/pr-3a-labelled-class-strip-setter/implementation.md`.
Citations are written as bare filenames, so the run names are what makes them
resolve. The five documents that arrive from `plans/` keep their existing
slug-suffixed names.

### 2. The citation check

Scan every `.md` file now in `archive/{slug}/`. Collect each inline-code span
whose content ends in `.md`:

```bash
find archive/{slug} -name '*.md' -print0 |
  xargs -0 grep -ohE '`[^`]*[.]md`' |
  tr -d '`' | sort -u
```

Resolve each name against these paths, in order. The first hit resolves it:

1. `archive/{slug}/{name}`
2. `archive/{slug}/{stem}-{slug}.md` — so a citation of `spec.md` finds
   `spec-haven-labelled.md`
3. `{name}` from the repository root — so `CLAUDE.md`,
   `.claude/rules/code-style.md` and `plans/error-messages.md` resolve

Two names are out of scope and never counted as unresolved:

- a name that starts with `../`, which points outside the repository;
- a name whose every citation site carries the not-archived marker of §4. The
  check finds the marker by the literal text `(not archived` immediately after
  the closing backtick.

A name that resolves nowhere is **unresolved**. The procedure then:

- writes the unresolved names, with the file and line of each citation, into
  `{run-dir}/decisions.md`;
- makes no commit;
- returns a HOLD to the caller with classification `unarchived-citation`.

`pipeline-ship` Step 5 and `commit-and-pr` Step 12 surface the HOLD to the
user. Two exits, both explicit:

- put the missing document in the run directory and run the procedure again;
- add the not-archived marker to the citation.

There is no third exit. The check is what makes the gap unreachable by
forgetting.

### 3. Measurement documents get a stated home

`workspace-layout.md` gains one rule: an ad-hoc measurement or verification
document goes in the run directory, next to `spec.md`. Nowhere else.

This is what turns "every `.md` in the run directory" into full coverage.
`measurements.md` and `verification-d4.md` were lost because no rule said
where they live.

### 4. The not-archived marker

One form, used everywhere:

```
`measurements.md` (not archived, #217)
```

Each affected archived file also gains a block below its title:

```
> **Unarchived sources.** This file cites `measurements.md`,
> `verification-d4.md` and `audit-empirical.md`. None of the three is in the
> repository. The pipeline gap that lost them is issue #217. The measurements
> are not restated here.
```

### 5. `haven-labelled` remediation

Add the marker at every citation site listed in the §Evidence table, and the
block below each of the three titles.

Restate no measurement. Re-derive no measurement. The argument in each
decision stays checkable on its own terms; the evidence is marked absent.

## Verification

No R code changes, so no package gate applies.

The procedure is verified by a dry run against the surviving
`2026-08-27-haven-labelled` run directory, in a scratch copy of the
repository. Three assertions:

| # | Assertion |
|---|---|
| 1 | The two `implementation.md` files arrive in `archive/haven-labelled/prs/`. |
| 2 | The fifteen `*.log` files and `status.md` do not. |
| 3 | The check reports exactly the eight unresolved names in §Evidence, and halts before committing. The six names the two `implementation.md` files cite all resolve: `decisions.md` and `spec.md` by rule 2, `NEWS.md`, `plans/error-messages.md` and the two `_snaps/*.md` files by rule 3. |

Assertion 3 runs before the marker edits of §5. After those edits, a second
run of the check reports zero unresolved names.

## Out of scope

- Archiving gate logs. They stay untracked. An `audit.md` that cites a gate
  result carries the numbers, and `audit.md` is now archived.
- Recovering the eight `haven-labelled` documents. They are gone.
- Renaming the five slug-suffixed archived filenames.
- The empty `pr-3a-labelled-class-strip-setter/` directory behind #216. The
  gate 17 and gate 18 measurements were logs, and logs stay untracked.
