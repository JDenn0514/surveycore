# Reduce Token Usage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement `plans/spec-reduce-token-usage.md` — cut weighted token usage of the pipeline skills by 50–70% with no loss of output quality.

**Architecture:** All changes are markdown edits to `.claude/` configuration files. No R code changes. Five groups: model tiering (A), review-loop caps (B), rules slimming with on-demand references (C), test-run and output discipline (D), gate deduplication (E).

**Tech Stack:** Claude Code agent/skill markdown files. Verification is by `grep` and `wc -l`, not by a test suite.

## Global Constraints

- No rule may be deleted — only moved to a reference file or deduplicated (spec §2C).
- Moved content must be reachable via a pointer that states when to read it.
- Never use `@file` syntax in pointers (it force-loads the file). Use plain paths.
- On-demand reference files go in `.claude/references/` (NOT `.claude/rules/`, which auto-loads).
- `builder`, `planner`, `reviewer` agents keep the session model — no `model:` key.
- Always-loaded total (CLAUDE.md + `.claude/rules/*.md`) target: ≤ 700 lines (currently 1,822).
- Commit after each task with the given Conventional Commit message. This branch: `JDenn0514/reduce-token-usage`.

---

### Task 1: Model tiering (Group A)

**Files:**
- Modify: `.claude/agents/tester.md:1-5` (frontmatter)
- Modify: `.claude/agents/shipper.md:1-5` (frontmatter), `.claude/agents/shipper.md:78`
- Modify: `.claude/skills/pipeline-spec/SKILL.md` (Stage 2, Stage 3 dispatch text)
- Modify: `.claude/skills/pipeline-implement/SKILL.md` (Stage 2 dispatch text)

**Interfaces:**
- Produces: `model: sonnet` frontmatter key consumed by the Claude Code agent loader; dispatch instructions consumed by orchestrator sessions.

- [ ] **Step 1: Add `model: sonnet` to tester frontmatter**

In `.claude/agents/tester.md`, change the frontmatter to:

```yaml
---
name: tester
description: Validates a merged PR against test-spec.md. Receives only the test-spec, never spec.md or implementation.md. Runs all profile gates. Enforces Tolerance Integrity. Writes audit.md with verdict PASS or BLOCK. Dispatched by pipeline-ship and pipeline-simplified.
tools: Read, Grep, Glob, Write, Bash
model: sonnet
---
```

- [ ] **Step 2: Add `model: sonnet` to shipper frontmatter; fix stale attribution**

Same edit pattern in `.claude/agents/shipper.md` (add `model: sonnet` after `tools:`).
Also on line 78, replace `Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>` with `Co-Authored-By: Claude <noreply@anthropic.com>` (model-agnostic — the agent may run on any model).

- [ ] **Step 3: Review-lens dispatches use sonnet**

In `.claude/skills/pipeline-spec/SKILL.md`:
- Stage 2, the line "If applicable, dispatch 5–6 Explore subagents in parallel (one per lens)" → append: "Pass `model: "sonnet"` on every lens dispatch — lens agents scan a document against one named criterion and do not need the session model."
- Stage 3, the line "Dispatch 6 Explore subagents in parallel (one per lens)." → append the same sentence.

In `.claude/skills/pipeline-implement/SKILL.md` Stage 2, after "Dispatch 5 Explore subagents in parallel:" add the same sentence as a note under the lens list.

- [ ] **Step 4: Verify**

```bash
grep -l "model: sonnet" .claude/agents/tester.md .claude/agents/shipper.md
grep -c 'model: "sonnet"' .claude/skills/pipeline-spec/SKILL.md   # expect 2
grep -c 'model: "sonnet"' .claude/skills/pipeline-implement/SKILL.md  # expect 1
```

- [ ] **Step 5: Commit**

```bash
git add .claude/agents/tester.md .claude/agents/shipper.md .claude/skills/pipeline-spec/SKILL.md .claude/skills/pipeline-implement/SKILL.md
git commit -m "chore(pipeline): run tester, shipper, and review lenses on sonnet"
```

---

### Task 2: Review-loop convergence caps (Group B)

**Files:**
- Modify: `.claude/skills/pipeline-spec/SKILL.md` (Stage 2r, Stage 3r)
- Modify: `.claude/skills/pipeline-implement/SKILL.md` (Stage 3)

**Interfaces:**
- Produces: a "Review-loop budget" block reused verbatim in both files.

- [ ] **Step 1: Add the budget block to pipeline-spec**

In `.claude/skills/pipeline-spec/SKILL.md`, insert a new section immediately before "## Stage 2 — Methods review":

```markdown
## Review-loop budget (applies to Stages 2/2r and 3/3r)

Measured cost of unbounded loops: one feature ran 7 review passes (~$300
API-equivalent). These rules cap the loop:

1. **Maximum 3 passes** per review stage. If findings remain open after
   pass 3, HOLD — ask the user instead of running pass 4.
2. **Pass 1 is the only full-panel pass** (all lenses, whole document).
3. **Passes 2+ are delta passes**: at most 2 Explore agents. They review
   ONLY the sections changed by the resolver (the resolver lists changed
   section headings at the top of its response) plus the specific findings
   they verify. They do not re-read the whole document.
4. **Early exit**: a pass whose findings require no change to the artifact
   ends the loop — the verdict is PASS.
```

Then in Stage 2r and Stage 3r, append to each "Loop until ... verdict = PASS" line: "Respect the Review-loop budget above."

- [ ] **Step 2: Add the same budget to pipeline-implement**

In `.claude/skills/pipeline-implement/SKILL.md`, insert the same block (retitled "## Review-loop budget (applies to Stages 2 and 3)") before "## Stage 2 — Plan review", and append "Respect the Review-loop budget above." to the Stage 3 loop line.

- [ ] **Step 3: Verify**

```bash
grep -c "Maximum 3 passes" .claude/skills/pipeline-spec/SKILL.md .claude/skills/pipeline-implement/SKILL.md  # expect 1 each
```

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/pipeline-spec/SKILL.md .claude/skills/pipeline-implement/SKILL.md
git commit -m "chore(pipeline): cap review loops at 3 passes with delta passes"
```

---

### Task 3: Slim the rules files (Group C, part 1)

**Files:**
- Create: `.claude/references/code-style-detail.md`
- Create: `.claude/references/github-strategy-detail.md`
- Create: `.claude/references/r-package-detail.md`
- Create: `.claude/references/testing-detail.md`
- Modify: all 7 files in `.claude/rules/`
- Modify: `CLAUDE.md` (add one pointer line)

**Interfaces:**
- Produces: 4 reference files whose paths are cited by pointers in the slimmed rules files and by agent defs in Task 4. Exact paths above — Task 4 depends on them.

**Method for every file:** the slim version keeps its Quick Reference table and any rule NOT derivable from that table, as compact prose (no code blocks unless listed below). Everything moved lands in the named reference file under a heading matching its original section name. Each slim file ends with:

```markdown
---
Worked examples and rationale: `.claude/references/{name}.md`. Read it when
writing new code covered by these rules and the correct application is not
obvious from the tables above.
```

- [ ] **Step 1: Slim `code-style.md` (477 → ~140 lines) → `code-style-detail.md`**

Keep inline:
- Quick Reference table (unchanged).
- §2: accessor exception for `@data`/`@metadata` (2 lines); method file-org table; the rule "always `S7::S7_inherits(x, ClassObject)`, never a string, never `is()`" (2 lines); `@variables` all-keys rule (2 lines, no code); `@groups` reserved rule (3 bullets).
- §3: ONE compact `cli_abort()` example (the three-bullet structure with `class=`); the class naming convention lines; the cli inline markup table; the message-register bullets (4 lines).
- §4: return-visibility table; argument-order numbered list (compressed to 7 one-liners); dispatch table + this warning kept verbatim: "S3 dispatch does NOT work for S7 objects... Use a plain function with explicit `S7::S7_inherits()` type checking instead."; helper placement table.

Move to `code-style-detail.md`: §1 code examples (indentation, line length, long-signature breaks), auto-formatter/air setup, §2 wrong/right code examples, §3 good/bad error examples and the `cli_warn()` block, §4 full code examples, §5 Tooling Configuration (.lintr, .editorconfig, air commands).

- [ ] **Step 2: Slim `engineering-preferences.md` (84 → ~25 lines)**

Keep: the 5 principles, each as its heading plus its first sentence (e.g., "1. DRY — flag repetition aggressively. Duplicated logic is a bug waiting to happen."). Move to `code-style-detail.md` under "## Engineering preferences — detail": the sub-bullets and the "How to apply these during review" section.

- [ ] **Step 3: Slim `github-strategy.md` (164 → ~70 lines) → `github-strategy-detail.md`**

Keep: Quick Reference; Workflow Tiers table; branching diagram (7 lines); branch-vs-direct table; Branch Naming table; Commit Format table + scopes line; Merge Strategy (2 sentences); Versioning tables; "Use `/merge-main`" line.
Move: Worked Examples section (all 6), Release Preparation detail.

- [ ] **Step 4: Slim `r-package-conventions.md` (297 → ~80 lines) → `r-package-detail.md`**

Keep: Quick Reference; §1 rules as one-liners (param verbosity rule, @return required, @examples runnable, @family, internal-docs table); §2 export policy bullets + ":: everywhere, no @importFrom" + "NAMESPACE never edited by hand"; §3 check targets + pre-approved NOTEs table + "accept NSE notes, don't suppress" + document()/check() cadence + min-version pinning rule.
Move: all roxygen code examples, DESCRIPTION template, package-documentation template. Delete §Summary (duplicates the Quick Reference — dedup, not a move).

- [ ] **Step 5: Slim `surveycore-conventions.md` (222 → ~55 lines) → `r-package-detail.md`**

Keep: Quick Reference; naming-pattern tables (class names, function families, naming patterns); haven rule (attr-based extraction, 3 lines); export/not-export lists as two compact lines.
Move (into `r-package-detail.md` under "## surveycore documentation examples"): the long `@param` examples, `@return` example, `@seealso` block. Delete §3 (already a pointer to code-style) and the Documentation Checklist (duplicates r-package-conventions content — dedup).

- [ ] **Step 6: Slim `testing-standards.md` (286 → ~90 lines) → `testing-detail.md`**

Keep: Quick Reference; granularity + one-behavior + no-describe rules (one line each, keep the good/bad description example pair as 4 short lines); coverage target + nocov acceptable/unacceptable bullets; the three mandatory categories (names + one-line each); dual-pattern rule (2 lines, no code); snapshot update rules (3 lines); warning-capture rule (2 lines); identical-vs-equal table; data-generator requirement bullets; edge-case-inline rule (2 lines); skip block-level rule (2 lines).
Move: all multi-line code examples.

- [ ] **Step 7: Slim `testing-surveycore.md` (208 → ~90 lines) → `testing-detail.md`**

Keep: Quick Reference; file-mapping table; `test_invariants()` first-assertion rule + the 5 invariant names (already slimmed upstream — keep as is); Layer 1 vs Layer 3 rules (2 lines each, no code); `make_survey_data()` signature block + data-policy table; tolerance table.
Move (under "## surveycore test templates"): the code examples and the test-file section templates.

- [ ] **Step 8: Add pointer line to CLAUDE.md**

In `CLAUDE.md` §Reference Documents, add:
`- `.claude/references/` — worked examples and rationale moved out of `.claude/rules/`; read when a rule's application is unclear`

- [ ] **Step 9: Verify — line budget and content preservation**

```bash
wc -l CLAUDE.md .claude/rules/*.md | tail -1        # total ≤ 700
# spot-check moved content survived (one distinctive phrase per reference file):
grep -l "pipe_consistency_linter" .claude/references/code-style-detail.md
grep -l "get_contrasts" .claude/references/github-strategy-detail.md
grep -l "wtmec2yr" .claude/references/r-package-detail.md
grep -l "snapshot_review" .claude/references/testing-detail.md
# every slim rules file points at its reference:
grep -L "claude/references/" .claude/rules/*.md     # expect empty output
```

- [ ] **Step 10: Commit**

```bash
git add .claude/rules/ .claude/references/ CLAUDE.md
git commit -m "chore(rules): slim always-loaded rules to tables; move examples to .claude/references"
```

---

### Task 4: Agent defs stop re-reading rules (Group C, part 2)

**Files:**
- Modify: `.claude/agents/builder.md:16` (Receives list)
- Modify: `.claude/agents/tester.md:15` (Receives list)
- Modify: `.claude/agents/reviewer.md:20-21` (Receives list)
- Modify: `.claude/skills/pipeline-ship/SKILL.md` (§2a and §2d dispatch prompts)

**Interfaces:**
- Consumes: reference file paths created in Task 3.

- [ ] **Step 1: builder.md**

Replace the Receives bullet "`.claude/rules/` — code style, testing standards, R package conventions" with:

```markdown
- Project rules (CLAUDE.md + `.claude/rules/`) auto-load into your context — do NOT re-read them. When a rule's application is unclear, read `.claude/references/code-style-detail.md` or `.claude/references/r-package-detail.md` for worked examples.
```

- [ ] **Step 2: tester.md**

Replace the Receives bullet "`.claude/rules/` — testing standards" with the same sentence, pointing at `.claude/references/testing-detail.md`.

- [ ] **Step 3: reviewer.md**

Replace the two Receives bullets "`.claude/rules/`" and "`skills/pipeline-shared/references/` (all files)" with:

```markdown
- Project rules auto-load into your context — do NOT re-read `.claude/rules/`.
- `skills/pipeline-shared/references/signals.md`, `artifact-schemas.md`, and `r-package-profile.md` — the only shared references you need (verdict schemas, tolerance defaults, gate skip rules).
```

- [ ] **Step 4: pipeline-ship dispatch prompts**

In `.claude/skills/pipeline-ship/SKILL.md`:
- §2a builder dispatch prompt: change `> Read: .claude/agents/builder.md, .claude/rules/, r-package-profile.md` to `> Read: .claude/agents/builder.md, r-package-profile.md (rules auto-load — do not re-read .claude/rules/)`.
- §2d reviewer dispatch prompt: change `> Read: .claude/agents/reviewer.md, ALL references from pipeline-shared` to `> Read: .claude/agents/reviewer.md, plus signals.md, artifact-schemas.md, and r-package-profile.md from pipeline-shared/references`.

- [ ] **Step 5: Verify**

```bash
grep -n "do NOT re-read" .claude/agents/builder.md .claude/agents/tester.md .claude/agents/reviewer.md  # 1 hit each
grep -n "ALL references" .claude/skills/pipeline-ship/SKILL.md  # expect empty
```

- [ ] **Step 6: Commit**

```bash
git add .claude/agents/builder.md .claude/agents/tester.md .claude/agents/reviewer.md .claude/skills/pipeline-ship/SKILL.md
git commit -m "chore(agents): stop re-reading auto-loaded rules; point at on-demand references"
```

---

### Task 5: Test-run and output discipline (Group D)

**Files:**
- Modify: `.claude/agents/builder.md` (Step 2 TDD loop)
- Modify: `.claude/skills/pipeline-shared/references/r-package-profile.md` (new section)
- Modify: `.claude/agents/tester.md:56` (capture-output line)
- Modify: `.claude/skills/pipeline-ship/SKILL.md` (§2c BLOCK handling)

- [ ] **Step 1: builder full-suite budget**

In `.claude/agents/builder.md`, after the Step 2 TDD loop list, add:

```markdown
### Full-suite budget

Iterate with `devtools::test(filter = "{pattern}")` on the test files you
touch. Run the FULL suite (`devtools::test()` with no filter) at most twice
per PR: once before writing `implementation.md`, and once after a BLOCK fix.
Measured cost of ignoring this: one builder ran the full suite ~10 times in
one PR. Redirect full-suite output to a log file and read only the tail:

    Rscript -e 'devtools::test()' > .test-full.log 2>&1
    tail -25 .test-full.log
    grep -E "^(FAIL|Failure|Error)" .test-full.log

Delete `.test-full.log` before committing.
```

- [ ] **Step 2: gate output discipline in r-package-profile.md**

After the Validation commands table, add:

```markdown
## Output discipline (all gates)

Redirect every gate's full output to `{workspace-run-dir}/logs/gate-{N}.log`.
Bring into context ONLY:
- `tail -25` of the log, and
- `grep -E "FAIL|ERROR|WARNING|NOTE" ` of the log.

Record each log path in `audit.md` §Profile gates. Read a full log only when
diagnosing that gate's failure.
```

- [ ] **Step 3: tester capture line**

In `.claude/agents/tester.md`, replace "Capture full output of each command. Summaries go in `audit.md`; full logs stay in the workspace directory for forensics." with "Follow `r-package-profile.md` §Output discipline: full output to workspace log files; only the filtered summary enters context. Summaries go in `audit.md` with log paths."

- [ ] **Step 4: BLOCK continues the same builder**

In `.claude/skills/pipeline-ship/SKILL.md` §2c, replace item 2 ("If counter ≤ 3: re-dispatch builder for that PR with the BLOCK body...") with:

```markdown
2. If counter ≤ 3: send the BLOCK body (NOT the full audit.md, NOT
   test-spec.md, per signals.md) to the SAME builder agent via SendMessage —
   it keeps its context and warm cache. Dispatch a fresh builder only if the
   original agent is no longer available (e.g., session restart), passing the
   BLOCK body in the dispatch prompt.
```

- [ ] **Step 5: Verify**

```bash
grep -c "Full-suite budget" .claude/agents/builder.md          # 1
grep -c "Output discipline" .claude/skills/pipeline-shared/references/r-package-profile.md  # ≥1
grep -c "SAME builder agent" .claude/skills/pipeline-ship/SKILL.md  # 1
```

- [ ] **Step 6: Commit**

```bash
git add .claude/agents/builder.md .claude/agents/tester.md .claude/skills/pipeline-shared/references/r-package-profile.md .claude/skills/pipeline-ship/SKILL.md
git commit -m "chore(pipeline): cap full-suite runs, filter gate output, reuse builder on BLOCK"
```

---

### Task 6: Gate deduplication (Group E)

**Files:**
- Modify: `.claude/skills/pipeline-shared/references/r-package-profile.md` (remove pkgcheck gate; renumber)
- Modify: `.claude/agents/tester.md` (gate list; tree hash)
- Modify: `.claude/skills/pipeline-ship/SKILL.md` (§2e.5 tree-hash skip)
- Modify: `.claude/skills/pipeline-shared/references/artifact-schemas.md` (audit.md schema: tree-hash line)

- [ ] **Step 1: Remove pkgcheck everywhere it is a gate**

- `r-package-profile.md`: delete table row 6 (`pkgcheck::pkgcheck()`); renumber rows 7→6 (pkgdown) and 8→7 (covr); update "gate 7" in the pkgdown skip condition to "gate 6".
- `.claude/agents/tester.md` Step 1: delete the `pkgcheck::pkgcheck()` line; renumber 7→6, 8→7.
- User decision 2026-08-21: pkgcheck removed entirely — not moved to release. (`.claude/agents/shipper.md:147` already ignores pkgcheck in CI; leave it.)

- [ ] **Step 2: Tester records the tree hash**

In `.claude/agents/tester.md` Step 1, after the gate list add: "After the last gate, record `git rev-parse 'HEAD^{tree}'` in `audit.md` §Profile gates as `Tree: {hash}` — the pre-PR gate uses it to skip duplicate reruns."

In `artifact-schemas.md`, find the audit.md schema's Profile gates section and add the line `Tree: {git tree hash at gate time}` to the required fields.

- [ ] **Step 3: pre-PR gate skip in pipeline-ship**

In `.claude/skills/pipeline-ship/SKILL.md` §2e.5, before the command block add:

```markdown
Skip check first: read `Tree:` from this PR's `audit.md` and compare to
`git rev-parse 'HEAD^{tree}'` on the feature branch. If they match, the
tester already ran these gates on this exact tree — skip the rerun and
proceed to the shipper (log "pre-PR gate: SKIPPED — tree unchanged since
audit"). If they differ (or `audit.md` has no `Tree:` line), run the gate
as below.
```

- [ ] **Step 4: Verify**

```bash
grep -rn "pkgcheck" .claude/skills/pipeline-shared/references/r-package-profile.md .claude/agents/tester.md  # expect no gate rows; profile may retain zero mentions
grep -c "Tree:" .claude/agents/tester.md .claude/skills/pipeline-ship/SKILL.md  # ≥1 each
```

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/pipeline-shared/references/r-package-profile.md .claude/agents/tester.md .claude/skills/pipeline-ship/SKILL.md .claude/skills/pipeline-shared/references/artifact-schemas.md
git commit -m "chore(pipeline): drop pkgcheck gate; skip duplicate pre-PR rerun via tree hash"
```

---

### Task 7: Final verification sweep

**Files:** none created — checks only.

- [ ] **Step 1: Line budget**

```bash
wc -l CLAUDE.md .claude/rules/*.md | tail -1   # total ≤ 700
```

- [ ] **Step 2: No dangling references**

```bash
grep -rn "pkgcheck" .claude/agents/ .claude/skills/pipeline-* | grep -v "NOT a required check"  # expect empty
grep -rn "Read: .claude/rules" .claude/agents/    # expect empty
grep -rn "@\.claude" .claude/                     # no @-force-load links; expect empty
```

- [ ] **Step 3: Spec cross-check**

Re-read `plans/spec-reduce-token-usage.md` §2. Confirm every numbered item in Groups A–E maps to a completed task step. Confirm §3 ("What does not change") still holds: builder/planner/reviewer have no `model:` key; isolation rules untouched; tolerances untouched.

- [ ] **Step 4: Commit any fixes, then report**

Report to user: per-file line counts before/after, and the validation procedure from spec §4 (run one small pipeline change, profile with `usage_profile.py`, compare).
