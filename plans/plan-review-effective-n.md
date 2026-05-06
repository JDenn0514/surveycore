## Plan Review: effective-n — Pass 1 (2026-05-04)

---

### New Issues

#### Section: PR Map

No issues found. A single PR for one new source file, one test file, and minor
additions to a helper file is the right granularity.

---

#### Section: Implementor Notes

No issues found. The three redirects (print method co-location,
`EFFECTIVE_N_META_KEYS` placement, `.validate_shared_args()` dummy args) are
accurate based on the codebase and prevent divergence from established
patterns.

---

#### Section: PR 1 — Files list

**Issue 1: Changelog entry file missing**
Severity: REQUIRED
Violates github-strategy.md file completeness and the project's established
per-PR changelog convention.

The project maintains `changelog/feature-{name}.md` entries (confirmed by
`changelog/feature-get-t-test-pairwise.md`, `changelog/feature-print-domain-info.md`,
etc.). The plan's Files list and the `git add` command in Step 10 both omit
`changelog/feature-effective-n.md`.

Options:
- **[A]** Add `changelog/feature-effective-n.md` to the Files list and to the
  `git add` in Step 10. Write it to the same format as the existing entries.
  — Effort: low, Risk: none, Impact: complete change record
- **[C] Do nothing** — changelog entry is omitted; post-merge record is
  incomplete.

**Recommendation: A** — The project already has this convention; follow it.

---

#### Section: PR 1 — Acceptance criteria

**Issue 2: 98%+ line coverage criterion absent**
Severity: REQUIRED
Violates testing-standards.md §1 (coverage target) and the spec's §V quality
gates.

The spec quality gates explicitly state: "Line coverage on
`R/analysis-effective-n.R` ≥ 98%." The plan's acceptance criteria checklist
does not include a coverage criterion. A PR that ships without verifying
coverage meets neither the project standard nor the spec gates.

Options:
- **[A]** Add a criterion: "Line coverage on `R/analysis-effective-n.R` ≥ 98%
  (verified via `covr::file_coverage()` or `devtools::test_coverage_file()`)."
  — Effort: trivial, Risk: none
- **[C] Do nothing** — builder may not run coverage; gap goes undetected.

**Recommendation: A** — One line closes the gap.

---

#### Section: Detailed Task Steps — Step 1, Section 3 (Error paths)

**Issue 3: EN-4 test block missing and error-messages.md scope understated**
Severity: REQUIRED
Violates testing-standards.md §2 (all error paths must be tested) and the
spec §III error table.

The spec error table lists EN-1 through EN-4. EN-4 is the `match.arg()` error
for invalid `method` values (e.g., `method = "ols"`). The plan says to add
"rows EN-1 through EN-3" to both the test file and `plans/error-messages.md`,
omitting EN-4 entirely.

Even with no custom error class, EN-4 must be documented in
`plans/error-messages.md` (one row noting base-R handling) and exercised by at
least a basic `expect_error()` test:
```r
test_that("get_effective_n() rejects invalid method value", {
  d <- as_survey(make_survey_data(), ids = psu, weights = wt,
                 strata = strata, fpc = fpc)
  expect_error(get_effective_n(d, method = "ols"))
})
```
No `class=` or snapshot needed since `match.arg()` produces a base-R error.

Options:
- **[A]** Add an EN-4 `test_that()` block to Section 3 in Step 1. Change "EN-1
  through EN-3" to "EN-1 through EN-4" in both Step 1 and Step 6.
  — Effort: low, Risk: none
- **[C] Do nothing** — EN-4 condition is untested; spec and error table are
  incomplete.

**Recommendation: A** — Two small changes; no architectural work.

---

#### Section: Detailed Task Steps — Step 4, `n_eff = n / deff` guard

**Issue 4: `is.finite(deff)` guard does not cover `deff ≤ 0`**
Severity: BLOCKING
Violates the spec §III behavior rule 5 intent and engineering-preferences.md §4
(handle edge cases).

The implementation skeleton says:
```r
use ifelse(is.finite(deff), n / deff, NA_real_)
```

In R, `is.finite(0)` = `TRUE` and `is.finite(-1)` = `TRUE`. This means:
- `deff = 0` → `n / 0` = `Inf`, not `NA_real_`
- `deff < 0` → negative `n_eff`, not `NA_real_`

Both are wrong. The spec's intent (rule 5) is that non-positive and non-finite
deff all produce `n_eff = NA_real_`. The edge case tests in section 4b assert
exactly this:
```
# deff == 0 (degenerate, method = "deff") → n_eff = NA
# deff < 0 (unstable, method = "deff") → n_eff = NA
```
With `is.finite()` as the guard, both assertions would fail.

The spec's own prose is the root cause: rule 5 says "!is.finite(deff), which
covers deff <= 0" — but that claim is wrong. `is.finite()` does not cover
negative values. The plan inherited this error from the spec.

Options:
- **[A]** Change the guard to `ifelse(is.finite(deff) & deff > 0, n / deff, NA_real_)`.
  This covers Inf, NaN, NA, 0, and negative deff. Annotate with the spec
  cross-reference. — Effort: trivial, Risk: none, Impact: correct behavior at
  all degenerate cases
- **[B]** Use `ifelse(deff > 0, n / deff, NA_real_)` (simpler, same outcome
  since NA > 0 is NA which is falsy in ifelse). Verify NA propagation is
  correct. — Effort: trivial, Risk: low
- **[C] Do nothing** — edge case tests 4b will fail; implementer must guess the
  correct guard.

**Recommendation: A** — The explicit two-condition guard is self-documenting.
Add a note to the implementation skeleton and update the spec's rule 5 wording
in decisions-effective-n.md.

---

#### Section: Detailed Task Steps — Open Questions

**Issue 5: Open question 1 (x-forwarding) must be resolved before coding starts**
Severity: REQUIRED
Violates the hard gate in the implementation-workflow skill (no implementation
begins until the plan is fully approved and open questions are resolved).

The plan says for the DEFF branch:
> "Note: to forward an already-resolved NSE argument, convert the tidy-select
> result to a symbol with `rlang::sym(x_name)` before the `get_means()` call,
> then splice with `!!`. Alternatively, call `get_means()` using the resolved
> character name directly via the formula interface — check how other helpers
> in the codebase invoke `get_means()` internally."

This is the implementation path for the core DEFF branch and cannot be deferred.
The implementor needs a decided approach before writing a single line of the
DEFF branch.

Options:
- **[A]** Resolve it now in Stage 3: inspect `analysis-variance.R` and
  `analysis-t-test.R` for precedent, record the chosen pattern in
  `plans/decisions-effective-n.md`, and update the skeleton to show the exact
  calling pattern. — Effort: low (one codebase lookup), Risk: none
- **[C] Do nothing** — implementor discovers the right approach mid-session;
  may choose inconsistently with the existing codebase.

**Recommendation: A** — This belongs in Stage 3. The answer exists in the
codebase; look it up once and record it.

---

#### Section: Open Questions / Decisions to Log

**Issue 6: Open questions 2 and 3 unlogged**
Severity: SUGGESTION
The plan has three open questions but `plans/decisions-effective-n.md` may not
yet record these as decided. Even when the answer is "follow existing
convention," a one-line decision entry prevents a future reviewer from
wondering whether the question was ever considered.

Options:
- **[A]** For questions 2 and 3, write a one-line decision entry each in
  `plans/decisions-effective-n.md` before Stage 3 closes:
  - Q2: "min_cell_n type validation — no explicit check; follows existing
    `get_*()` convention."
  - Q3: "`.apply_decimals()` integer skip — confirmed by [codebase reference]
    before implementation."
  — Effort: trivial
- **[C] Do nothing** — minor omission; questions are effectively answered in
  the plan body.

**Recommendation: A** — Two lines.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 4 |
| SUGGESTION | 1 |

**Total issues:** 6

**Overall assessment:** The plan is structurally sound — single-PR scope is
correct, TDD ordering is correct, and the three Implementor Notes accurately
redirect spec architectural choices to match codebase reality. One blocking
issue must be fixed before coding starts: the `is.finite(deff)` guard is wrong
and will cause both deff=0 and deff<0 edge case tests to fail. Four required
items (changelog file, coverage criterion, EN-4 coverage, x-forwarding
decision) are low-effort fixes. Start Stage 3 to resolve these, then proceed
to `/r-implement` or `/auto-ship`.
