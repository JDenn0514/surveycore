# Signal System

Three named signals govern all inter-agent and agent-to-user communication during pipeline execution. Every pause, block, or halt in the pipeline MUST use one of these. No ad-hoc `AskUserQuestion` calls.

Planning-stage reviews (methods review, spec review, plan review) do NOT use these signals as verdicts — they use the review verdicts defined at the bottom of this file.

## HOLD

**Emitted by:** any agent (planner, builder, tester, reviewer, shipper)
**Means:** I cannot proceed without a decision from the user.
**Outcome:** pipeline pauses at current state. User resolves. Pipeline resumes.

### Valid triggers

- **planner**: methodology ambiguity; user must choose between two defensible designs
- **builder**: spec is silent on a behavioral decision the implementation forces
- **tester**: test-spec is silent on how to handle an unanticipated numerical result (e.g., reference package errored)
- **reviewer**: cross-artifact inconsistency that may reflect a genuine choice, not a bug
- **shipper**: CI failure whose cause is unclear (flake vs real); user approval needed to retry or halt

### Required body

Write to `decisions.md` AND return to leader:

```
## HOLD — {agent} — {YYYY-MM-DD HH:MM}

**Where**: {stage, file, PR, test name as applicable}
**What**: One-sentence description of the open question
**Why I can't decide**: Which authority or input is missing
**Options** (if any): Enumerate with tradeoffs
**What I need**: One sentence — the exact input required to resume
```

## BLOCK

**Emitted by:** tester (in `audit.md`) or reviewer (in `review.md`)
**Means:** Code does not satisfy the test-spec (tester), or a convergence check failed (reviewer).
**Outcome:** builder is re-dispatched for this PR with the BLOCK body only (NOT audit.md, NOT test-spec.md — isolation preserved; see pipeline-isolation.md rule 4). A reviewer BLOCK may instead route to pipeline-spec when the defect is in the spec.

**Cycle limit (authoritative):** 3 BLOCKs per PR. BLOCKs 1 and 2 trigger re-dispatch; the 3rd escalates to HOLD with classification `repeated-block`. Other documents point here — do not restate the number elsewhere.

### Valid triggers (tester)

- A numerical test failed outside tolerance
- A named error class test failed (wrong class thrown, or no error thrown)
- `R CMD check --as-cran` has ERROR or WARNING
- `pkgdown::build_site()` errored
- Coverage dropped below 95%

### Required body

Tester writes `audit.md` with verdict=BLOCK and:

```
## BLOCK — {YYYY-MM-DD HH:MM}

**Failing scenario**: {name from test-spec, or profile command}
**Observed**: {value, class, message}
**Expected**: {value, class, tolerance}
**Classification**: numerical-miss | contract-miss | profile-fail | coverage-drop
**What builder must fix**: One sentence
```

Tester does NOT tell builder *how* to fix. Tester does NOT suggest code. Tester reports what failed against what was specified.

### Escalation

On the 3rd BLOCK for the same PR (see cycle limit above), the orchestrating skill escalates to HOLD with classification `repeated-block` and the user decides: extend cycles, re-spec, or abandon.

## STOP

**Emitted by:** reviewer only
**Means:** The change is unsafe to ship.
**Outcome:** pipeline halts entirely. User must explicitly override in `decisions.md` with justification.

### Valid triggers

- Tester relaxed a tolerance below what `test-spec.md` specified (Tolerance Integrity violation)
- Tester skipped a required test (e.g., `skip_if_not_installed()` on a non-optional gate)
- Builder implemented behavior not in the spec (scope creep introducing behavioral change)
- Builder implemented spec but audit shows a regression in a test NOT in scope for this PR
- Coverage dropped below 95% AND the uncovered lines are in new code
- Profile gate failed in a way that audit labeled as non-blocking (reviewer disagrees)

### Required body

Reviewer writes `review.md` with verdict=STOP and:

```
## STOP — {YYYY-MM-DD HH:MM}

**Category**: {tolerance-relaxation | test-skip | scope-creep | unflagged-regression | coverage-floor | gate-misclassification}
**Evidence**: direct quote or diff from the offending artifact
**Why this is unsafe**: One paragraph
**What must happen before resume**: Exact fix, as a list
```

Shipper refuses to run when the latest review.md verdict is STOP. Period.

## Resume protocol

After the user resolves a HOLD or overrides a STOP, the resolving decision is appended to `decisions.md`:

```
## Resolution — {YYYY-MM-DD HH:MM}

**Signal resolved**: {HOLD or STOP reference}
**Decision**: One sentence
**Authorized by**: user
**Resume from state**: {state name}
```

The skill then advances the pipeline from the recorded state.

## Review verdicts (planning stages)

Methods reviews, spec reviews, and plan reviews aggregate their lens findings into one of three verdicts. These are verdicts on a document, not pipeline signals — the words BLOCK and HOLD are reserved for the signals above.

| Verdict | Condition | Routing |
|---|---|---|
| **PASS** | No BLOCKING finding, no REQUIRED-UNAMBIGUOUS finding, no JUDGMENT_CALL finding | Freeze stage may run |
| **FAIL** | Any BLOCKING or REQUIRED-UNAMBIGUOUS finding | Route to the stage's resolve counterpart; loop until PASS |
| **NEEDS-DECISION** | Any JUDGMENT_CALL finding | Orchestrating skill raises a HOLD signal; user decides; then resolve and re-review |
