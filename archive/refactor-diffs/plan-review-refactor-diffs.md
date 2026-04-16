## Plan Review: refactor-diffs — Pass 1 (2026-04-01)

### New Issues

#### Section: PR 1 — Files

**Issue 1: `test-analysis-diffs-helpers.R` already exists with 267 lines of tests**
Severity: REQUIRED
Violates file-completeness principle: plan description could cause an implementer to overwrite or ignore existing test content.

The Files section describes `tests/testthat/test-analysis-diffs-helpers.R` as "Unit tests for the three new helpers (.extract_clean_estimates(), .extract_me_estimates(), .build_diffs_output()), including happy paths, error paths, and all edge cases from spec §5.2." The file already exists with 267 lines covering four categories:
1. `.stars_pval()` (13 test blocks)
2. `.apply_name_style(exclude)` (4 test blocks)
3. `print.survey_diffs()` (3 test blocks)
4. `DIFFS_META_KEYS` constant (1 test block)

An implementer reading the Files section description may interpret it as the intended complete content of the file and either create a fresh copy (destroying the existing tests) or at minimum be confused about what "new" means in Phase B1/C1/D1 task steps.

Options:
- **[A]** Update the Files section entry to explicitly say "Add tests to existing file; existing content (`.stars_pval()`, `.apply_name_style()`, `print.survey_diffs()`, `DIFFS_META_KEYS`) is unchanged." — Effort: low, Risk: low, Impact: prevents accidental test deletion
- **[B]** Add a note at the top of the Notes section clarifying the file is pre-populated — Effort: low, Risk: low, Impact: same protection, less visible
- **[C] Do nothing** — implementer must discover the existing content on first read; if they create a fresh file, 267 lines of tests are lost and CI breaks

**Recommendation: Option A** — Fix the description at the source; the Files section is the first place an implementer looks when planning the work.

---

#### Section: PR 1 — Tasks (F5 / Acceptance Criteria)

**Issue 2: Changelog entry path unspecified**
Severity: SUGGESTION
Violates file-completeness lens: no target path named for the changelog entry.

Task F5 says "Write `changelog/` entry (standard format, on this branch)" and the acceptance criterion says "Changelog entry written and committed on this branch." Neither specifies the file path. The existing changelog structure has entries in sub-directories by phase (`changelog/phase-1/`, `changelog/phase-2/`, `changelog/audit/`, etc.) and some top-level files (`changelog/feature-print-domain-info.md`, `changelog/chore-rename-calibrated-to-nonprob.md`). For a refactor on `refactor/analysis-diffs-helpers`, there is no existing `changelog/refactor/` directory, and it is ambiguous whether this should be:
- `changelog/refactor-analysis-diffs.md` (top-level, matches `chore-*` pattern)
- `changelog/refactor/analysis-diffs-helpers.md` (new sub-directory, matches phase pattern)

Options:
- **[A]** Specify the path in F5: `changelog/refactor-analysis-diffs.md` — Effort: low, Risk: low, Impact: implementer creates the file in one consistent place
- **[B]** Specify a new sub-directory: `changelog/refactor/analysis-diffs-helpers.md` — Effort: low, Risk: low, Impact: cleaner long-term organization if more refactor entries follow
- **[C] Do nothing** — implementer picks a path; inconsistent naming possible but not blocking

**Recommendation: Option A** — A top-level file matches the `chore-*` pattern for maintenance work that doesn't belong to a numbered phase.

---

#### Section: Acceptance Criteria

**Issue 3: ≤500 line gate is weaker than the spec's ~400 target**
Severity: SUGGESTION
The acceptance criterion `R/analysis-diffs.R ≤500 lines` gives 100 lines of slack over spec §II's stated target of `~400 lines`. A partial extraction — e.g., leaving `.extract_me_estimates()` partially inline — could produce a 490-line file that passes the gate but violates the spec's intent. The spec target of ~400 is the right anchor; the 500-line ceiling is a wide safety margin.

Options:
- **[A]** Tighten acceptance criterion to `≤450 lines` (still a buffer vs. the ~400 estimate, but cuts the slack in half) — Effort: zero (just a number change), Risk: low, Impact: earlier detection of incomplete extraction
- **[B]** Keep ≤500 as-is but add an informational note: "spec target is ~400 lines" — Effort: low, Risk: none, Impact: sets implementer expectations without hardening the gate
- **[C] Do nothing** — ≤500 is a coarse pass/fail; partial extraction passes; full extraction also passes; difference only noticed at code review

**Recommendation: Option B** — A comment costs nothing and surfaces the intent without over-tightening a metric that is inherently approximate.

---

### Section: PR Map, Dependency Ordering, Spec Coverage

No issues found.

- **PR Granularity**: Single-PR scope is correct. The three helpers must wire together in the same commit; splitting across PRs would leave `get_diffs()` broken between PRs.
- **Dependency Ordering**: A → B → C → D → E → F phasing is logical. Each phase's red-green-refactor cycle is explicit.
- **Spec Coverage**: All helpers (§3.1, §3.2, §3.3), the `get_diffs()` skeleton (§IV), testing requirements (§5.1–5.3), and quality gates (§VI) have corresponding plan tasks. The `surveycore_error_reference_row_not_found` class is already present in `R/analysis-diffs.R` (line 375) and `plans/error-messages.md` — no new error class is introduced; no update needed.
- **File Completeness**: `R/analysis-diffs-helpers.R`, `R/analysis-diffs.R`, and `tests/testthat/test-analysis-diffs-helpers.R` are all correctly identified. No `helper-test-data.R` update is needed (inline mock construction specified in Notes). NAMESPACE/man/ are confirmed unchanged by F3.

---

## Summary (Pass 1)

| Severity | Count |
|----------|-------|
| BLOCKING | 0 |
| REQUIRED | 1 |
| SUGGESTION | 2 |

**Total issues:** 3

**Overall assessment:** The plan is well-structured and faithfully covers the spec. One required clarification about a pre-existing test file prevents a potential data-loss mistake; the two suggestions are minor polish. Ready to implement after resolving Issue 1.
