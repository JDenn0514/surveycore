## Plan Review: print-domain-info — Pass 1 (2026-03-03)

### New Issues

#### Section: Overview / Architecture

No issues found.

---

#### Section: PR 1 — Files (Implementation Notes)

**Issue 1: `.print_domain_info()` code block uses `{row_label}` but the correcting note says to use the literal `row{?s}` form**
Severity: REQUIRED

The code block in the "Implementation notes" section shows:

```r
cli::cli_text("Domain: {.val {n_domain}} of {.val {n_total}} {row_label}")
```

where `row_label <- "row{?s}"` for the non-twophase branch. But `cli::cli_text()` does
NOT re-process `{?s}` tokens inside interpolated variable values — it processes only tokens
in the direct format string. Interpolating `{row_label}` where `row_label = "row{?s}"` would
emit the literal string `row{?s}` in the output, not the pluralized form.

The plan's own correcting note acknowledges this:

> "The spec's final code reads: `cli::cli_text("Domain: {.val {n_domain}} of
> {.val {n_total}} row{?s}")`
> This is the correct form — `cli_text()` will pluralize based on the last `{.val}` number.
> Use this literal form, not the indirect `row_label` variable approach for the pluralized
> case."

The code block and the note contradict each other. An implementer following the code block
will produce broken output (`row{?s}` printed literally). The note is buried after the block.

The correct implementation requires **two separate `cli_text()` calls** — one for twophase
("Phase 2 rows") and one for non-twophase (literal `row{?s}`) — or an `if`/`else` construct.
The plan does not show this clearly.

Options:
- **[A]** Replace the code block with a version that shows the correct if/else structure with
  two separate `cli_text()` calls (one with literal `row{?s}`, one with "Phase 2 rows") —
  Effort: low, Risk: low, Impact: implementer has an unambiguous guide
- **[B]** Keep the `row_label` variable approach but document that cli DOES support `{?s}`
  inside interpolated variables (requires verification of cli behavior) — Effort: low,
  Risk: medium, Impact: might be correct if cli recurses on interpolated values
- **[C] Do nothing** — implementer follows the code block, emits `row{?s}` literally in output,
  snapshot tests fail in a confusing way

**Recommendation: A** — The plan's own note says to use the literal form; the code block
should match that guidance to prevent the obvious mistake.

---

**Issue 2: Missing changelog entry in acceptance criteria and file list**
Severity: REQUIRED

The acceptance criteria omit the standard requirement: "Changelog entry written and committed
on this branch." The file list also does not include a `changelog/` entry file.

Every feature PR in surveycore must ship with a changelog entry per the standard workflow
(`github-strategy.md` and the stage 2 review lens §Lens 3). This applies equally to small
single-file PRs.

Options:
- **[A]** Add to acceptance criteria: "Changelog entry committed in `changelog/` on this
  branch" and add the changelog file path to the Files section — Effort: low, Risk: low,
  Impact: enforces the required release workflow artifact
- **[B] Do nothing** — the changelog is omitted and the PR will be missing a release artifact;
  the `/merge-main` workflow may fail or require a follow-up commit

**Recommendation: A** — Trivial fix; prevents the PR being blocked at merge time.

---

#### Section: PR 1 — Test Blocks (Tests 28–35)

**Issue 3: Test 31 (`survey_srs`) uses `make_survey_data(n = 30L, seed = 42L)` without specifying `n_psu` — will crash**
Severity: REQUIRED

The plan specifies:

```r
d <- as_survey_srs(make_survey_data(n = 30L, seed = 42L), weights = wt)
```

`make_survey_data()` defaults to `n_psu = 50L`. With `n = 30` and `n_psu = 50`:

1. After Hamilton allocation and `pmax(..., 1L)`, each of the 50 PSUs gets 1 row →
   `sum(psu_sizes) = 50`, but `n = 30`.
2. `remaining = 30 - 50 = -20` (negative → no further allocation), so `psu_sizes` sums
   to 50, not 30.
3. `psu_index <- rep(1:50, times = rep(1, 50))` → length 50.
4. `y1 <- rnorm(n, ...)` → length 30.
5. `data.frame(psu = ...[50], y1 = ...[30], ...)` → **"arguments imply differing number of
   rows: 50, 30"** error.

The same error is latent in the spec (`make_survey_data(n = 30, seed = 42)`), which the plan
faithfully transcribed. Both need correction.

The existing `survey_srs` test 18 uses an inline `data.frame(y = 1:10, wt = ...)` precisely
to avoid this generator for small-n cases.

Options:
- **[A]** Specify `n_psu` and `n_strata` explicitly: `make_survey_data(n = 30L, n_psu = 6L, n_strata = 2L, seed = 42L)` — Effort: low, Risk: low, Impact: test constructs the fixture correctly
- **[B]** Use the same inline construction as test 18: `as_survey_srs(make_survey_data(n = 100L, n_psu = 10L, n_strata = 2L, seed = 42L), weights = wt)` with a larger n — Effort: low, Risk: low, Impact: simpler, matches existing test 18 pattern
- **[C] Do nothing** — test 31 fails immediately at fixture construction with a data.frame error

**Recommendation: A** — Explicit small n_psu + n_strata values preserve the intent of a
compact fixture while fixing the crash. Note: update the spec as well (§V has the same error).

---

**Issue 4: `test_invariants(d)` absent from all eight new test blocks (28–35)**
Severity: REQUIRED

`testing-surveycore.md` states:

> "`test_invariants()` required as **first** assertion in every constructor test block"
> "Every `test_that()` block that creates a survey object via `as_survey()`, `as_survey_replicate()`,
> or `as_survey_twophase()` must call `test_invariants(design)` as its **first** assertion."

All eight new test blocks (28–35) create survey objects through fixture helpers
(`make_taylor_design()`, `make_rep_design()`, `make_twophase_design()`, inline `as_survey_srs()`,
inline calibrated construction) — all of which call the relevant `as_survey*` constructors
under the hood. None of the plan's code examples include `test_invariants(d)`.

Adding the domain column to `@data` via `d@data[[SURVEYCORE_DOMAIN_COL]] <- ...` does not
change the structural invariants (design variables, weight column, metadata), so
`test_invariants(d)` will pass. The call should appear **after** fixture construction but
**before** the domain column injection (to test the clean fixture) — or immediately after
construction, as in the existing tests.

Options:
- **[A]** Add `test_invariants(d)` immediately after fixture construction (before domain
  injection) in each of the eight blocks — Effort: low, Risk: low, Impact: consistent with
  existing test file; enforces the documented standard
- **[B] Do nothing** — the blocks diverge from the testing standard; if `test_invariants()`
  is later tightened, these blocks will need to be updated separately

**Recommendation: A** — One line per block; no functional risk; enforces the established
pattern.

---

#### Section: PR 1 — Acceptance Criteria

**Issue 5: Zero-domain edge case from spec §III edge case table has no test**
Severity: SUGGESTION

Spec §III edge cases include:

> `filter()` applied — zero rows in domain (`n_domain == 0`) → Line shown:
> `Domain: 0 of 100 rows`

The plan covers the NA exclusion case (test 29) but not the all-FALSE domain column case
(`sum(all_FALSE) = 0`). The zero-domain case is notable because it verifies that:
- The domain line still renders (no early-return on `n_domain == 0`)
- Pluralization: "0 of 100 rows" (not "0 of 1 row")

This is a named edge case in the spec and represents a distinct behavior from the NA case.
The existing Block 1 tests use `d@data$y1 > 0`, which will almost certainly produce
`n_domain > 0` with the seed-42 fixture.

Options:
- **[A]** Add one snapshot test (e.g., test 29a or renumber): inject
  `d@data[[SURVEYCORE_DOMAIN_COL]] <- FALSE` (all-FALSE) and `expect_snapshot(print(d))` for
  a `survey_taylor` fixture — Effort: low, Risk: low, Impact: covers the spec-named edge case
- **[B] Do nothing** — the zero-domain branch is reachable from any Block 1 test path
  (column-present branch is covered), but the specific behavior is not verified

**Recommendation: A** — The spec names this case explicitly; it costs one test block to close
the gap.

---

### Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 4 |
| SUGGESTION | 1 |

**Total issues:** 5

**Overall assessment:** The plan is structurally sound and covers the spec well — one PR,
correct call-site table, correct test numbering, and the `survey_calibrated` net-new baseline
requirement is properly handled. Four required fixes are needed before coding starts: the
`{row_label}` vs. `row{?s}` code block inconsistency will cause subtle output corruption if
the implementer follows the code block; the `make_survey_data(n = 30L)` call will crash at
test construction; `test_invariants()` is missing from all eight new blocks; and the changelog
entry is absent from the file list and acceptance criteria.

---

## Resolution: Pass 1 — All Issues Applied (2026-03-03)

| # | Title | Status |
|---|---|---|
| 1 | `{row_label}` vs. `row{?s}` inconsistency in code block | ✅ Resolved — code block replaced with correct two-branch if/else; each branch has its own `cli_text()` call; contradictory note removed |
| 2 | Missing changelog entry in acceptance criteria and file list | ✅ Resolved — `changelog/feature-print-domain-info.md` added to Files list; criterion added to acceptance criteria |
| 3 | `make_survey_data(n = 30L)` crashes (n < default n_psu = 50) | ✅ Resolved — test 31 and fixture reference table updated to `n_psu = 6L, n_strata = 2L`; warning note added to test block prose |
| 4 | `test_invariants(d)` absent from new test blocks 28–35 | ✅ Resolved — `test_invariants(d)` added after fixture construction (before domain injection) in all 8 blocks |
| 5 | Zero-domain edge case (spec §III) has no test | ✅ Resolved — test 36 added: injects `FALSE` for all rows, verifies line still renders and pluralization is correct |
