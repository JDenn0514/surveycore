## Spec Review: print-domain-info — Pass 1 (2026-03-03)

### New Issues

#### Section: I. Scope

No new issues found.

---

#### Section: II. Architecture

No new issues found.

---

#### Section: III. Helper Specification

**Issue 1: Injection example uses `age > 65` — column does not exist in test data**
Severity: SUGGESTION
Violates engineering-preferences.md §5 (explicit over clever) — a misleading example
introduces unnecessary ambiguity during implementation.

The "Pattern for injecting domain column without surveytidy" block uses:
```r
d@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- d@data$age > 65
```
`make_survey_data()` (and by extension `make_taylor_design()`) produces columns
`psu`, `strata`, `fpc`, `wt`, `y1`, `y2`, `y3`. There is no `age` column. The
§V test blocks correctly use `d@data$y1 > 0`. The §III example contradicts that.

Options:
- **[A]** Change the §III example to `d@data$y1 > 0`, consistent with §V — Effort: low, Risk: low, Impact: removes confusion.
- **[B]** Keep `age > 65` but add a note that it is illustrative, not literal — Effort: low, Risk: low, Impact: minor.
- **[C] Do nothing** — Implementer may try `d@data$age` and get an error or NULL column assignment.

**Recommendation: A** — Use the same column name (`y1 > 0`) in both the §III example and the §V test blocks to eliminate the discrepancy.

---

**Issue 2: Pluralization of "rows" not addressed**
Severity: SUGGESTION
Violates engineering-preferences.md §4 (handle more edge cases, not fewer).

The spec mandates the output `Domain: <n_domain> of <n_total> rows`. When
`n_domain == 1` and/or `n_total == 1`, the output would read "Domain: 1 of 1
rows" — grammatically incorrect. `cli` supports `{?s}` pluralization natively.
The spec is silent on whether to use it.

Options:
- **[A]** Add `{?s}` pluralization: `"Domain: {.val {n_domain}} of {.val {n_total}} row{?s}"` — Effort: low, Risk: low, Impact: correct grammar at n=1.
- **[B]** Explicitly accept "1 of 1 rows" as acceptable (document the decision) — Effort: low, Risk: low, Impact: avoids scope creep, slightly awkward output.
- **[C] Do nothing** — Implementer must decide; snapshot tests would lock in whichever choice is made.

**Recommendation: A** — The effort is trivial and cli makes it easy. Decide now so the snapshot captures the correct form.

---

**Issue 3: Empty `@data` edge case not in edge case table**
Severity: SUGGESTION
Violates engineering-preferences.md §4 (handle more edge cases, not fewer).

The edge case table covers: column absent, all-in, all-out, NAs. It does not
cover `nrow(x@data) == 0`. If the design somehow reaches `.print_domain_info()`
with zero rows, `n_total == 0` and `n_domain == 0`, producing "Domain: 0 of 0
rows". Survey validators likely prevent 0-row designs, but the spec should
state that assumption explicitly.

Options:
- **[A]** Add a row to the edge case table: "0-row @data — not reachable via public API (validator rejects); no special handling needed" — Effort: low, Risk: low, Impact: documents the assumption.
- **[B]** Add a guard: if `n_total == 0`, suppress the domain line — Effort: low, Risk: low, Impact: defensive coding.
- **[C] Do nothing** — Leave it undefined. Unreachable in practice.

**Recommendation: A** — Document the assumption rather than leaving it implicit.

---

**Issue 4: `survey_twophase` — `n_total` semantics not clarified**
Severity: SUGGESTION
Violates engineering-preferences.md §5 (explicit over clever).

The spec defines `n_total <- nrow(x@data)` for all five design types uniformly.
For `survey_twophase`, `x@data` holds all phase-1 rows. The domain line would
therefore read "Domain: X of Y rows" where Y = phase-1 sample size. The
Phase 1 size line already prints the same Y ("Phase 1 sample size: Y"). The
domain line is semantically anchored to phase 1, not phase 2 — but the spec
does not state this or discuss whether it is the right framing.

Options:
- **[A]** Add a note in §III: "For `survey_twophase`, `n_total` = `nrow(x@data)` = the phase-1 sample. Domain membership is across phase-1 rows." — Effort: low, Risk: low, Impact: removes a semantic ambiguity that would arise during code review.
- **[B]** Use phase-2 row count for `n_total` in twophase — Effort: medium, Risk: medium, Impact: changes semantics for twophase only; requires separate logic.
- **[C] Do nothing** — Leave it implicit; implementer uses `nrow(x@data)` uniformly.

**Recommendation: A** — The uniform `nrow(x@data)` approach is fine; just document what it means for twophase so the domain line is interpretable.

---

#### Section: IV. Verbatim Console Output Examples

No new issues found.

---

#### Section: V. Testing

**Issue 5: New test blocks are missing `withr::local_options()`**
Severity: REQUIRED
Violates testing-surveycore.md (snapshot consistency) and the pattern
established in every other snapshot test in `test-methods-print.R`.

Every existing snapshot test in the file sets console width before snapshotting:
```r
withr::local_options(list(width = 80L, cli.width = 80L))
```
The two new test blocks shown in §V (Block 1 domain-present, Block 2
`expect_false()`) do not include this call. Without it, snapshot output width
is environment-dependent and snapshots will break on machines with different
terminal widths.

Options:
- **[A]** Add `withr::local_options(list(width = 80L, cli.width = 80L))` to all five new domain-present test blocks — Effort: low, Risk: low, Impact: snapshot stability across environments.
- **[B]** Rely on testthat's snapshot normalization — Effort: none, Risk: high, Impact: snapshot failures on narrow/wide terminals.
- **[C] Do nothing** — CI will catch it on first run.

**Recommendation: A** — Match the established pattern. This is a one-liner per block.

---

**Issue 6: No fixture for `survey_srs` domain tests — existing `make_srs_design()` creates a `survey_taylor`**
Severity: REQUIRED
Violates engineering-preferences.md §5 (explicit over clever — document assumptions).

The existing `make_srs_design()` fixture is defined in `test-methods-print.R`
with an explicit comment: "Directly constructed to bypass SRS dispatch
(as_survey() without ids/strata now creates survey_srs)." It creates a
`survey_taylor` object, not a `survey_srs`. The existing `survey_srs` tests
(#18–27) use `as_survey_srs()` inline rather than a shared fixture.

The spec's Block 1 pattern says `d <- make_taylor_design()` and implies that
analogous `make_{type}_design()` fixtures exist for all five types. For
`survey_srs`, there is no `make_srs_design()` that returns a `survey_srs`.
An implementer who uses `make_srs_design()` for the `survey_srs` domain test
would silently test the wrong class.

Options:
- **[A]** Define a `make_survey_srs_design()` local fixture (e.g., `as_survey_srs(make_survey_data(n=30, seed=42), weights=wt)`) and name it explicitly in §V — Effort: low, Risk: low, Impact: eliminates silent class mismatch.
- **[B]** Specify that the `survey_srs` domain test uses inline `as_survey_srs()` construction instead of a fixture, matching the existing #18–27 pattern — Effort: low, Risk: low, Impact: consistent with existing style for that class.
- **[C] Do nothing** — Implementer discovers the issue when `S7::S7_inherits(d, survey_srs)` fails or the snapshot shows the wrong header.

**Recommendation: B** — Match the established `survey_srs` test style (inline construction). Add a note to §V specifying this deviation from the fixture pattern.

---

**Issue 7: `survey_nonprob` has no existing print snapshot — Block 2 directive has no target**
Severity: REQUIRED
Blocks implementation — the spec says to "add the `expect_false()` assertion
to the existing block" but no default-output snapshot block exists for
`print.survey_nonprob`.

The test file (`test-methods-print.R`) ends at test #27 (`print.survey_srs —
probs_provided label`). There are zero existing snapshot tests for
`print.survey_nonprob`. The spec's snapshot update protocol states:
"Add the `expect_false()` assertion to the existing block rather than
duplicating it." For calibrated, there is no existing block to add to.

Additionally, there is no `make_calibrated_design()` fixture anywhere in the
test file. The implementer must create both the fixture and the baseline
"no domain" snapshot from scratch — but the spec neither instructs them to do
this nor provides a fixture pattern.

Options:
- **[A]** Add a subsection to §V for `survey_nonprob` specifically: define a `make_calibrated_design()` fixture (or inline construction pattern), state that both a domain-absent AND domain-present snapshot block must be created (not just the domain-present one), and note that these are net-new, not updates — Effort: low, Risk: low, Impact: fully specifies what the implementer must do.
- **[B]** Remove `survey_nonprob` from scope until its baseline print tests exist — Effort: low, Risk: low, Impact: reduces scope of this PR; follow-up PR handles calibrated.
- **[C] Do nothing** — Implementer discovers the gap at implementation time.

**Recommendation: A** — The gap is small; specifying a fixture pattern and acknowledging the new-not-updated nature of calibrated snapshots is a one-paragraph addition.

---

**Issue 8: No test blocks for the three behavioral edge cases**
Severity: SUGGESTION
Violates engineering-preferences.md §2 (more tests is better).

§III lists three edge cases with defined behavior:
1. All rows in domain (`n_domain == n_total`) — "Domain: 100 of 100 rows"
2. Zero rows in domain (`n_domain == 0`) — "Domain: 0 of 100 rows"
3. Domain column has NAs — `na.rm = TRUE` treats NAs as not-in-domain

These are all within the "column present" code branch and do not add branch
coverage. However, the behavioral correctness of `na.rm = TRUE` in particular
is only verifiable by a test — and it is not exercised by the standard
`d@data$y1 > 0` injection (which produces no NAs by construction).

Options:
- **[A]** Add one test block for the NA case specifically (inject `c(TRUE, FALSE, NA, TRUE, ...)` and assert the count excludes NAs) — Effort: low, Risk: low, Impact: verifies the only non-obvious computation in the helper.
- **[B]** Add three test blocks (all-in, all-out, NAs), one per edge case — Effort: low, Risk: low, Impact: full behavioral coverage of edge cases.
- **[C] Do nothing** — The NA behavior is documented in the spec; it's a code review item.

**Recommendation: A** — The NA test catches the only genuinely non-obvious computation (`sum(..., na.rm = TRUE)` vs `sum(...)`). All-in and all-out are less critical since they exercise the same arithmetic.

---

**Issue 9: No test block for domain + groups combination**
Severity: SUGGESTION
Violates testing-standards.md §2 (domain estimation test category for all exported functions).

§IV shows a verbatim console output example for domain + groups combined:
```
── Survey Design ─────────────
<survey_taylor> (Taylor series linearization)
Sample size: 50
Domain: 35 of 50 rows
Groups: strata
```
But no test block verifies this ordering. The groups line depends on
`length(x@groups) > 0`, which is set by `surveytidy`'s `group_by()`. The test
must inject both the domain column and groups into the design. Since `@groups`
injection requires `surveytidy` or direct S7 property assignment, a note on
how to set up this test is needed.

Options:
- **[A]** Add one snapshot test block for domain + groups, using direct `d@groups <- "strata"` assignment alongside domain column injection — Effort: low, Risk: low, Impact: verifies the domain-before-groups ordering is correct.
- **[B]** Mark this as out-of-scope since `@groups` requires surveytidy, and rely on §IV as documentation — Effort: none, Risk: low, Impact: ordering not snapshot-tested.
- **[C] Do nothing** — The ordering is verified by reading the code.

**Recommendation: A** — Direct `@groups` assignment is a single line; verifying the header ordering is worth a snapshot.

---

**Issue 10: Replicate fixture name not specified**
Severity: SUGGESTION

The test file uses `make_rep_design()` (not `make_replicate_design()`). The
spec's Block 1 pattern uses `make_taylor_design()` and says "for each of the
five design types" without naming the other fixtures. A careful reader of the
spec would write `make_replicate_design()` based on the naming pattern, which
does not exist — the correct call is `make_rep_design()`.

Options:
- **[A]** Name all five fixture functions explicitly in §V, including `make_rep_design()` for `survey_replicate` — Effort: low, Risk: low, Impact: eliminates a "function not found" error during implementation.
- **[B]** Add a note in §V: "Replicate fixture is `make_rep_design()`, not `make_replicate_design()`" — Effort: very low, Risk: low, Impact: same.
- **[C] Do nothing** — Implementer discovers via the existing fixture list at the top of the test file.

**Recommendation: B** — One-sentence note prevents a confusing "could not find function" error.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 3 |
| SUGGESTION | 7 |

**Total issues:** 10

**Overall assessment:** The spec is coherent and implementable for three of the five design types (`survey_taylor`, `survey_replicate`, `survey_twophase`). Two required gaps — the missing `survey_srs` fixture guidance and the absent `survey_nonprob` baseline snapshot context — will cause implementer confusion or silent errors. The missing `withr::local_options()` in new test blocks will break snapshot CI. Resolving these three required issues makes the spec fully implementable. The seven suggestions are genuine quality improvements but none are implementation blockers.
