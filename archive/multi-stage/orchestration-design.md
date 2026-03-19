# Autonomous Skill Orchestration — Design

**Date:** 2026-03-13
**Status:** Design reference — build when sequential loop is validated

---

## Risk Assessment

### Statistical correctness: LOW RISK

The spec defines exact expected behavior. Tests compare against the `survey`
package reference implementation with tight tolerances (1e-10 for point
estimates). CI blocks on any regression. The agent isn't inventing methodology —
it's transcribing a finalized spec into code.

### Code quality: MANAGEABLE with explicit guards

The main exploit: the agent weakening tests to make CI pass instead of fixing
the code. This is the primary safeguard target (see Safeguards section).

---

## Supervision Model

**Auto-proceed (no input needed):**
- All tests pass, CI is green → merge to develop automatically
- Snapshot failures → agent updates snapshots and re-runs (this is allowed)

**Notify + hard stop (you decide):**
- r-implement fails 3 times
- Test files modified during CI-fix (non-snapshot)
- Test count drops post CI-fix
- Unexpected conflict on merge to develop
- Any CI failure after the second r-implement attempt

**Always gate (never automated):**
- Merge to `main` (releases) — never, ever automated
- Any PR where CI has failed more than once on different underlying issues

---

## Architecture: Python Orchestrator + Claude CLI Headless

### Core invocation

```bash
claude \
  --print "invoke the r-implement skill on plans/impl-multi-stage.md" \
  --allowedTools "Bash,Read,Write,Edit,Glob,Grep,Agent,Skill" \
  --cwd /path/to/worktree
```

No `--dangerouslySkipPermissions`. Use `--allowedTools` with the exact set needed.

### Minimal `--allowedTools` list (to audit empirically in MVP)

| Tool | Why needed |
|------|-----------|
| `Read` | Read plan, spec, source files |
| `Write` | Write new R source + test files |
| `Edit` | Edit existing R source + test files |
| `Glob` | Find files by pattern |
| `Grep` | Search file contents |
| `Bash` | `Rscript` (devtools), `git`, `gh`, `air` |
| `Agent` | r-implement subagent mode |
| `Skill` | Invoke the skill itself |

For `Bash`, the specific command families needed:
- `Rscript -e "devtools::test()"` / `devtools::check()` / `devtools::document()`
- `git` (branch, add, commit, push, checkout, worktree)
- `gh` (pr create, run watch, run view, pr merge, pr list)
- `air` (formatter)

**MVP action:** Run the sequential chain once with `--allowedTools` and capture
any Bash calls that still prompt. That gives the exact pre-approved list.
Configure those patterns in `.claude/settings.local.json` rather than using
`--dangerouslySkipPermissions`.

### CI monitoring

`commit-and-pr` already handles `gh run watch` internally. The orchestrator
also independently polls:
```bash
gh pr checks <PR_NUMBER> --watch
```
This gives a clean exit code (0 = pass, non-zero = fail) as the gate for
auto-merge.

### Auto-merge

`commit-and-pr` supports `mergeAfterCI` — set via the prompt:
```
"Run commit-and-pr. Merge to develop automatically after CI passes. Do not
pause for approval on the PR draft."
```

### Interactive approval checkpoints

Skills have "show draft, wait for approval" steps. In headless `--print` mode,
the prompt must include:
```
"Operating in automated mode. Proceed through all draft-review checkpoints
without pausing for user approval."
```

**MVP validation item:** Confirm the first run handles these cleanly — watch
stdout for any "waiting for input" hanging.

---

## Parallel Execution via Git Worktrees

For PRs tagged `[parallel-ok]` in the impl plan:

```
main worktree:   /Users/jacobdennen/surveycore/         (develop branch)
worktree A:      /tmp/surveycore-pr3/                   (feature/multi-stage-constructor)
worktree B:      /tmp/surveycore-pr4/                   (feature/multi-stage-variance-taylor)
worktree C:      /tmp/surveycore-pr6/                   (feature/multi-stage-glm)
```

The orchestrator:
1. Reads the plan, collects the next batch of consecutive `[parallel-ok]` `[ ]` items
2. Creates worktrees: `git worktree add /tmp/surveycore-prN feature/branch-N`
3. Runs separate `claude --print` subprocesses per worktree, concurrently
4. **Sequences merges** — one at a time with `git pull --rebase` between
5. Cleans up: `git worktree remove /tmp/surveycore-prN` after merge

### Convention for future plan documents

Tag independent PRs with `[parallel-ok]` in the PR Map. A PR gets this tag
when:
- It has no file-level overlap with other tagged items in the same batch
- Its only dependency is a PR that has already merged to develop
- It does not need another in-flight PR's output to compile or test

---

## Safeguards

### Test integrity (most critical)

During CI-fix mode, the agent must not modify test files except snapshots.
Two-layer enforcement:

**1. Prompt instruction (preventive):**
```
"Do NOT modify any test files when fixing this CI failure, except snapshot
files in tests/testthat/_snaps/. If you cannot fix the failure without
modifying tests, stop and report why. Re-read the relevant spec section
and implementation plan item before proposing any fix. Stay within the
already-agreed scope."
```

**2. Orchestrator post-hoc check (detective):**
```python
changed = subprocess.run(
    ["git", "diff", "--name-only", "HEAD"],
    capture_output=True, text=True
).stdout.splitlines()

bad = [f for f in changed
       if f.startswith("tests/testthat/")
       and not f.startswith("tests/testthat/_snaps/")]

if bad:
    notify_user(f"CI-fix modified test files: {bad}. Stopping.")
    hard_stop()
```

Also check that total `test_that()` count has not decreased post-fix.

### Other guards

| Guard | Mechanism |
|-------|-----------|
| 3-retry hard limit | r-implement enforces; orchestrator treats non-zero exit as hard stop + notify |
| Never touch main | Orchestrator hard-codes: never invoke `/merge-main` |
| Merge conflicts | Detect on `git pull --rebase` failure; notify + stop |
| macOS notifications | `osascript` at every stop point |

---

## Build Order

### Phase 1 — Sequential MVP (validate concept first)

One Python script, one cycle:
- r-implement → commit-and-pr → CI wait → auto-merge (or hard-stop + notify)

```bash
python scripts/orchestrate.py --plan plans/impl-multi-stage.md
```

Validates: `--allowedTools` list, headless approval checkpoints, `mergeAfterCI`,
test-integrity guard trigger.

### Phase 2 — Looping

Loop over all `[ ]` items sequentially. Add test-integrity check and 3-retry
hard stop. Log each cycle.

### Phase 3 — Parallel

Add worktree support for `[parallel-ok]` batches. Only after the sequential
loop is solid.

---

## Files to Create (when actually building)

| File | Contents |
|------|----------|
| `scripts/orchestrate.py` | Main orchestrator (~250 lines) |
| `scripts/notify.sh` | `osascript` wrapper (3 lines) |

Existing skills are unchanged — black boxes.
