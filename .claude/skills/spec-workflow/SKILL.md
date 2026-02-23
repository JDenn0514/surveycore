---
name: spec-workflow
description: >
  Use this skill for any surveyverse planning or spec work — creating a new phase
  spec, reviewing an existing spec, building an implementation plan, or logging
  decisions. Trigger whenever the user says "next phase", "spec sheet", "finalize
  the spec", "review the plan", "implementation plan", "decision log", or references
  a phase number (e.g. "phase 1", "phase 0.5"). Also trigger when the user says
  they want to start planning or want help preparing before writing code.
---

# Surveyverse Spec Workflow

This skill governs all planning work for the surveyverse packages (`surveycore`,
`surveytidy`, etc.). It covers four stages that always happen in order:

1. **Draft** — Create the spec sheet
2. **Review** — Iteratively review and fix the spec (with decision logging)
3. **Plan** — Create the implementation plan
4. **Handoff** — Write the decisions log entry before any code is touched

Apply engineering-preferences.md at every stage.

Read the relevant stage below based on where the user is in the workflow. If
unclear, ask.

---

## Rules in Context

This skill works alongside — never instead of — the following rule files. When
reviewing a spec or plan, check compliance with all of them:

| Rule file | What it governs |
|---|---|
| `code-style.md` | Indentation, pipe, air formatter, S7 patterns, cli error structure, argument order, helper placement |
| `r-package-conventions.md` | `::` usage, NAMESPACE, roxygen2, `@return`, `@examples`, export policy |
| `surveycore-conventions.md` | Naming patterns (`get_*`, `extract_*`, `set_*`), `@family`, return visibility, haven handling |
| `testing-standards.md` | `test_that()` scope, flat structure, 98% coverage, assertion patterns, data generators |
| `testing-surveycore.md` | `test_invariants()`, layer 1 vs layer 3 error testing, `make_survey_data()`, numerical tolerances |

When a spec decision touches one of these rules, cite the rule file. When a spec
is *silent* on something these rules already define, note that the rule is
authoritative and the spec doesn't need to repeat it.

---

## Stage 1: Drafting a Spec Sheet

### Before writing anything

Ask the user:
1. Which package and phase is this for?
2. Is there an existing roadmap document to reference?
3. Are there upstream phase specs that constrain this one? (Ask them to share.)

Then read all provided context before writing a single line.

### Spec structure

Model every spec on the Phase 1 structure. Required sections:

| Section | Content |
|---|---|
| Header block | Version, date, status |
| Document Purpose | One paragraph: this is the source of truth |
| I. Scope | What this phase delivers (table), what it does NOT deliver, class/design support matrix |
| II. Architecture | File organization tree, shared helpers with signatures |
| III–N. Function specs | One section per function or component: signature, argument table, output contract, behavior rules, error table |
| Testing section | Per-function test categories, edge cases, invariant helpers |
| Quality Gates | Checklist of what "done" means — must be objectively verifiable |
| Integration section | Contracts with other packages (e.g. surveytidy) |

### Spec writing rules

- Every public function gets a full argument table with: name, type, default, and
  one-sentence description. Argument order must follow `code-style.md`: `x`/`data`
  first → required NSE → required scalar → optional NSE → optional scalar → `...`.
- Every function gets an explicit output contract: column names, types, and the
  S3 class hierarchy.
- Every error condition is listed in a table with: error class, trigger condition,
  and the message template. Class names must follow the convention in
  `code-style.md`: `"surveycore_error_{snake_case}"` or `"surveycore_warning_{snake_case}"`.
- "TBD" and "to be determined" are not allowed — if something is genuinely unknown,
  flag it explicitly as a **GAP** with `> ⚠️ GAP: [description]` so it's easy to find.
- Domain estimation and grouping behavior must be specified for every analysis
  function (do not say "see the shared helpers" without also stating the specific
  behavior for this function).
- Do NOT restate rules already defined in `code-style.md`, `r-package-conventions.md`,
  or `surveycore-conventions.md`. Reference them instead: "Error structure follows
  `code-style.md` §3."

### After the draft

Tell the user: "This is a first draft. I expect there are gaps — let's move to the
review stage to find and fix them."

---

## Stage 2: Reviewing the Spec

### Before starting review

Check for a spec-reviewer output file at `plans/spec-review-phase-{X}.md`. If it
exists, work through those issues in order rather than doing a fresh review pass —
the adversarial review has already been done. Skip to the BIG/SMALL question below,
then address each issue in the file sequentially.

If no file exists, do a fresh review using the sections below.

### Two review modes

Before starting any review, ask:

> I can work through this in one of two ways:
> 1. **BIG CHANGE** — Work through this interactively, one section at a time
>    (Architecture → Contracts → Tests → Quality Gates), with at most 4 top
>    issues per section.
> 2. **SMALL CHANGE** — Work through interactively ONE question per section.
>
> Which do you prefer?

Wait for the answer before proceeding.

### Review sections and what to evaluate

#### Architecture review

- Overall system design and component boundaries
- Dependency graph — do helpers follow the placement rule from `code-style.md`:
  inline if used in 1 file, `07-utils.R` if used in 2+ files?
- File organization tree — does it match the naming conventions in `surveycore-conventions.md`?
- Are all shared helpers specified with full signatures and return types?
- Are there DRY violations — functions with duplicated logic that should share a helper?
- Is dispatch correct per `code-style.md`: `S7::method()` for extending existing generics,
  plain function + `S7::S7_inherits()` for surveycore-owned generics?

#### Contract review

- **Argument completeness**: every argument documented with type, default, and
  one-sentence description. Survey-specific args (`nest`, `fpc`, `group`, `variance`,
  `na.rm`) get fuller treatment per `surveycore-conventions.md` §1.
- **Argument order**: follows `code-style.md` rule — `x`/`design` → required NSE →
  required scalar → optional NSE → optional scalar → `...`.
- **Output column specs**: every column named, typed, and described.
- **S3 class hierarchy**: fully specified including all parent classes (e.g.
  `c("survey_means", "survey_result", "tbl_df", "tbl", "data.frame")`).
- **Return visibility**: setters return `invisible(x)`, getters visible, constructors
  visible, print methods `invisible(x)` — per `code-style.md` §4.
- **Error table completeness**: every error class defined; every trigger condition
  covered. Class names follow `surveycore_error_{condition}` and
  `surveycore_warning_{condition}`. Every class must be added to `plans/error-messages.md`.
- **cli structure**: `"x"` + `"i"` + optional `"v"` format; `class=` on every
  `cli_abort()` and `cli_warn()` — no exceptions (per `code-style.md` §3).
- **Missing edge cases**: all-NA inputs, zero-weight rows, single-level groups,
  empty groups, domain + grouping simultaneously.
- **Consistency between related functions**: e.g. `get_means` and `get_totals`
  should handle NA and grouping identically unless there's a documented reason
  they don't.
- **`@variables` keys**: are all keys always present (never absent, value `NULL`
  when unspecified) per `code-style.md` §2?
- **S7 membership tests**: spec examples use `S7::S7_inherits(x, ClassName)` with
  class object, never a string.

#### Test review

Apply the test criteria in `testing-surveycore.md` for this section.

Check these specifically:

- **`test_invariants()` present**: every constructor test block calls it as the
  first assertion.
- **12 test categories present** for every analysis function — see `testing-surveycore.md`
  for the full list: happy path, numerical oracle (tolerances 1e-10/1e-8/1e-6), grouped
  analysis, domain estimation, variance argument, label_values, label_vars, meta() contract,
  name_style="broom", error paths, edge cases, multi-variable.
- **Error test pattern**: Layer 1 (S7 validators) → `class=` only. Layer 3 (constructors)
  → dual pattern: `expect_error(class=)` + `expect_snapshot(error=TRUE)`.
- **Other mechanics**: single behavior per `test_that()`; no `describe()` nesting;
  block-level `skip_if_not_installed()`; 98%+ coverage; `# nocov` must be justified.

#### Quality Gates review

- Are the quality gates objectively verifiable (no vague criteria like "works correctly")?
- Numerical tolerances explicitly stated (1e-10 point, 1e-8 SE, 1e-6 CI)?
- `devtools::check()` target present: 0 errors, 0 warnings, ≤2 pre-approved notes?
- All new files listed?
- `plans/error-messages.md` update in the gate list?
- `devtools::document()` cadence addressed (must run before any commit that changes
  roxygen2 content per `r-package-conventions.md`)?

### Issue format (required for every issue found)

NUMBER issues sequentially across sections. Give LETTERS to options.

```
**Issue [N]: [Short title]**

[Concrete description of the problem, with section/spec reference.
If a rule file governs this, cite it: e.g. "Violates code-style.md §3."]

Options:
- **[A]** [Description] — Effort: [low/medium/high], Risk: [low/medium/high],
  Impact: [what this affects], Maintenance: [ongoing burden]
- **[B]** [Description] — [same fields]
- **[C] Do nothing** — [consequences of not addressing this]

**Recommendation: [A/B/C]** — [Why, mapped to engineering preferences below.]

> Do you agree with option [letter], or would you prefer a different direction?
```

### Engineering preferences to apply in reviews

Map recommendations to `engineering-preferences.md` (priority order: DRY →
well-tested → engineered enough → edge cases → explicit over clever).

### After each review section

Output the section's issues (up to 4 for BIG CHANGE, 1 for SMALL CHANGE),
with all options and your recommendation. Then ask:

> "Does this look right? Any changes before I move to [next section]?"

Do not proceed to the next section until the user confirms.

### Applying fixes

When the user approves a direction, **edit the spec file immediately** — before
presenting the next issue. Do not batch fixes. Do not create a new file. After
each edit, summarize what changed in one sentence.

---

## Stage 3: Building the Implementation Plan

Only start this stage when the user explicitly says the spec is finalized.

### Plan structure

The implementation plan is a separate document from the spec. Required sections:

**Overview** — 2–3 sentences: what this plan delivers and how it relates to the spec.

**PR map** — A checkbox list of every planned PR. Use this exact format so
`r-implement` can read and check off sections:

```
- [ ] PR 1: `feature/branch-name` — one-sentence description
- [ ] PR 2: `feature/branch-name` — one-sentence description
```

Rules for the PR map:
- **One PR per logical unit of work.** For analysis functions: one PR per function
  (or tightly related pair like `get_means` + `get_totals`). Never bundle multiple
  unrelated functions into one PR because it's faster.
- Shared infrastructure (helpers, base classes, test helpers) ships in its own PR
  before the functions that depend on it.
- Stub removal is always atomic with its test migration — same PR, never separate.
  CI must be green before the stub-removal PR merges (per spec quality gates).
- No PR should contain more than ~3 new R files + their test files.
- `devtools::document()` and `devtools::check()` must pass before every PR is opened.

**Per-PR sections** — For each PR in the map:

```
### PR [N]: [Human-readable title]

**Branch:** `feature/[name]`
**Depends on:** PR [n] (or "none")

**Files:**
- `R/[file].R` — [one-sentence description]
- `tests/testthat/test-[file].R` — [one-sentence description]
- `changelog/phase-{X}/feature-[name].md` — created last, before opening PR

**Acceptance criteria:**
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] [specific test categories that must pass for this PR]
- [ ] Numerical oracle tolerance: point 1e-10, SE 1e-8 (where applicable)
- [ ] Changelog entry written and committed on this branch

**Notes:** [Any implementation details the implementor needs to know that aren't
in the spec — gotchas, ordering constraints, etc.]
```

### After the plan is drafted

Tell the user: "Review the PR map carefully — the scope of each PR is harder to
change once implementation starts. In particular, confirm that no PR bundles
functions that should be separate."

---

## Stage 4: Decisions Log Entry

Write a decisions log entry **if and only if** decisions were made in this session
that are NOT already reflected in the updated spec or implementation plan. If every
decision is captured in those documents, skip this stage.

When it is needed: this entry protects you when you look at the code six months
later and wonder why something was done a certain way.

The decisions log lives at:
- `surveycore/plans/claude-decisions-phase-{X}.md`
- `surveytidy/plans/claude-decisions-phase-{X}.md`

If the file doesn't exist, create it with a header:

```markdown
# Claude Decisions Log — [Package] Phase [X]

This file records planning decisions made during implementation of Phase [X].
Each entry corresponds to one planning session.

---
```

### What to log

Log a decision if ANY of these are true:
- You asked the user a question during planning
- You chose between two or more meaningfully different approaches
- You made a scope or behavior assumption not obvious from the spec
- You deferred something to a later phase

Do NOT log implementation details already fully determined by the spec or by a
rule file. If the answer was predetermined, there is no decision to log.

### Entry format

```markdown
## [YYYY-MM-DD] — [Component or feature planned]

### Context

[1–2 sentences: what were we trying to figure out in this session?]

### Questions & Decisions

**Q: [The question that came up]**
- Options considered:
  - **[Option A]:** [description and trade-offs]
  - **[Option B]:** [description and trade-offs]
- **Decision:** [what was decided]
- **Rationale:** [why — mapped to project constraints and engineering preferences]

### Outcome

[1 sentence: what will be built as a result of this session]

---
```

---

## Quick Reference

| User says... | Do this |
|---|---|
| "Start the next phase" / "Let's plan phase X" | Stage 1: ask for roadmap + upstream specs, then draft |
| "Review the spec" / "Check the plan" | Stage 2: ask BIG or SMALL, then review |
| "The spec looks good, build the implementation plan" | Stage 3: write the PR map |
| "Ready to start coding" / "ExitPlanMode" | Stage 4: write decisions log entry FIRST |
| "Add to the decisions log" | Stage 4 only |

---

## File Locations Reference

```
Logs: {package}/plans/claude-decisions-phase-{X}.md
Changelogs: {package}/changelog/phase-{X}/{branch-name}.md
```

Changelog entry format (written last on each branch, before opening a PR) is
defined in `changelog-workflow.md`. This skill covers the planning stage only.