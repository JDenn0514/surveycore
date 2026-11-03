# CI Monitoring (Steps 8–9)

## Step 8: Monitor CI

Wait for the run to appear, then watch it:

```bash
# List runs — get the run ID
gh run list --branch <branch-name> --limit 3

# Watch silently until completion — redirect output, it's very verbose
gh run watch <run-id> --exit-status > /dev/null 2>&1
echo "CI exit: $?"
```

**If CI passes:** return to SKILL.md Step 10.

**If CI fails:** proceed to Step 9.

---

## Step 9: CI Failure — Handoff to r-implement

Analyze the failure — work from the bottom of the log upward, where the actual
error almost always appears:

```bash
# Summary of which jobs and steps failed
gh run view <run-id>

# Last 40 lines of failed log (where the error usually is)
gh run view <run-id> --log-failed 2>&1 | tail -40

# If more context needed
gh run view <run-id> --log-failed 2>&1 | grep -A 5 -B 5 "Error\|FAIL\|failed"
```

Classify the failure before writing the handoff block. This helps r-implement
diagnose faster:
- **Test failure** (`devtools::test()` failing): logic issue in R source or test
- **R CMD check error**: documentation, NAMESPACE, or syntax issue
- **Platform-specific failure** (Windows or macOS only, not ubuntu-latest):
  environment issue; confirm it does not reproduce locally before handing off

Produce the handoff block per `refs/ci-handoff-template.md` and show it to
the user.

The fix itself belongs to `r-implement` — the hard constraint at the top of
SKILL.md applies here too.
