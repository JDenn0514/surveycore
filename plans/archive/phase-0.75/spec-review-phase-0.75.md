# Spec Review: Phase 0.75 — Two-Phase Variance Engine

**Reviewed:** `plans/phase-0.75-formal-specification.md`
**Date:** February 2026
**Reviewer:** Claude Code (adversarial review)

---

## Round 1 Issues — All Resolved

The following 15 issues were identified in the initial review. All have been
addressed in the current spec version. Brief resolution notes are included for
traceability.

| # | Title | Severity | Resolution |
|---|-------|----------|------------|
| 1 | Warning 26 → Warning 23b systematic mis-numbering | BLOCKING | ✅ Fixed throughout; spec now says "Warning 23b" everywhere |
| 2 | Warning 25 disposition unspecified | BLOCKING | ✅ Spec now explicitly removes Warning 25 from constructor; estimation-time error is sole check |
| 3 | `.twophase_phase1_var()` matrix-building contract absent | BLOCKING | ✅ Section 4.3 now has full matrix construction spec + tech debt note |
| 4 | `.svy_recvar()` returns matrix; callers treated it as scalar | BLOCKING | ✅ `[1L, 1L]` extraction specified in Sections 4.3, 4.4, and 4.2 |
| 5 | NA influence propagation contract contradictory | REQUIRED | ✅ Section 4.2 and 4.6 now consistent: NA propagates through `.svy_recvar()` |
| 6 | `fpc2` stored but unused in variance formulas | REQUIRED | ✅ Section 4.4 now specifies Phase 2 FPC matrix construction |
| 7 | `.twophase_df()` `nest = TRUE` path untested | REQUIRED | ✅ Test block with inline nested design added to Section 9.3 |
| 8 | `surveycore_error_full_requires_phase2` conflicts with Warning 25 constructor behavior | REQUIRED | ✅ Resolved via Issue 2 decision |
| 9 | `test_invariants()` incompatible with `survey_twophase` `@variables` structure | BLOCKING | ✅ Code confirmed: `test_invariants()` already has `survey_twophase` branch (lines 253–318 in helper-test-data.R) |
| 10 | `nwtco` oracle — surveycore design structure doesn't match survey oracle | BLOCKING | ✅ Section 9.5 updated: `ids = seqno` + `strata2 = rel` now match the oracle |
| 11 | `make_survey_data(design = "twophase")` — full column specification missing | REQUIRED | ✅ Section 9.2 now has full column schema table |
| 12 | Snapshot entry to delete not precisely identified | REQUIRED | ✅ Section 3.4 now names the exact snapshot entry label |
| 13 | Oracle tests should/shouldn't call `test_invariants()` — ambiguous | SUGGESTION | ✅ Section 9.2b explicitly exempts oracle tests; rule clarified |
| 14 | `.twophase_df()` return type not specified (integer vs numeric) | SUGGESTION | ✅ `as.integer()` cast added; test uses `8L` |
| 15 | `.compute_phase2_probs()` called before `"simple"` short-circuit | SUGGESTION | ✅ Accepted as-is (recommendation B: negligible overhead) |

---

## Round 2 Issues — New

---

## Section IX — Test Generator (`make_survey_data`)

**Issue 16: `make_survey_data()` column name conflicts between spec schema and existing code**
Severity: BLOCKING
Violates engineering-preferences.md §5 (explicit over clever).

The spec's Section 9.2 column schema and usage example define column names that conflict with
the current generator:

| Column | Current generator | Spec schema |
|--------|-------------------|-------------|
| Phase 1 weight | `wt` | `weight` |
| Phase 2 indicator | `phase2_ind` | `subset` |

The usage example in Section 9.2 is:
```r
df  <- make_survey_data(design = "twophase", seed = 42)
ph1 <- as_survey(df, ids = psu, weights = weight, strata = strata, fpc = fpc)
d   <- as_survey_twophase(ph1, subset = subset, method = "approx")
```

If the existing `wt` column is not renamed to `weight`, this example fails at `weights = weight`
(column not found). Similarly, `subset = subset` fails if the column remains `phase2_ind`.

The spec says "the two-phase generator produces all columns from the Taylor variant plus the three
Phase 2 columns." This phrasing is ambiguous: does "same as Taylor variant" mean the same names
(`wt`) or a uniform new name (`weight`)?

Renaming `wt` → `weight` in the Taylor branch would break every existing test that uses
`make_survey_data(design = "taylor")` with `weights = wt`. This is a very large blast radius.

The most likely intent is that the two-phase BRANCH renames `phase2_ind` → `subset` (since
`subset` is the canonical name throughout the spec) but keeps `wt` for the weight column — making
the usage example a typo. The schema description "(same as Taylor variant)" supports this reading.

Options:
- **[A]** Spec the two-phase branch using `wt` (matching Taylor), rename `phase2_ind` → `subset`,
  add `phase1_prob` and `phase2_prob`. Fix the usage example to use `weights = wt`. Update
  `make_all_designs()` to use `subset = subset`. — Effort: low, Risk: low
- **[B]** Rename `wt` → `weight` throughout the entire generator (both taylor and twophase
  branches), fix ALL existing tests that reference `wt`. — Effort: high, Risk: high, Impact: consistent naming
- **[C] Do nothing** — The usage example in the spec is broken; implementer cannot determine
  correct column name.

**Recommendation: A** — Keep `wt` as the weight column in the generator (it matches all
existing tests). The `weight` label in the schema table is a documentation error. The
`phase2_ind` → `subset` rename is the only required change to the column layout.

---

**Issue 17: `make_all_designs()` in `helper-test-data.R` not updated — will break after Phase 0.75**
Severity: REQUIRED
Violates engineering-preferences.md §4 (handle more edge cases) and §1 (DRY).

`make_all_designs()` at line 446 of `helper-test-data.R`:
```r
twophase <- suppressWarnings(as_survey_twophase(phase1, subset = phase2_ind))
```

Phase 0.75 makes two changes that affect this line:
1. **Column rename** (per Issue 16 resolution): `phase2_ind` → `subset`. The reference
   `subset = phase2_ind` will throw "column not found."
2. **Warning 25 removal**: The `suppressWarnings()` wrapper was silencing
   `surveycore_warning_full_no_phase2` (fires because no `method` is specified and the default
   method is `"full"` with no phase 2 design info). After Warning 25 is removed, the wrapper
   suppresses nothing — but more importantly, the call may now ERROR instead of warn if `method =
   "full"` triggers `surveycore_error_full_requires_phase2` at construction time. (Depends on
   whether the error fires at construction vs. estimation time per the spec — it fires at
   estimation time, so construction would succeed.)

The spec should add `helper-test-data.R` to the affected-files list in Section 3.4:
- Remove `suppressWarnings()`
- Change `subset = phase2_ind` → `subset = subset`
- Consider adding explicit `method = "approx"` to avoid any future ambiguity

Options:
- **[A]** Add `helper-test-data.R` to Section 3.4's affected-files table with the specific
  change: `suppressWarnings(as_survey_twophase(phase1, subset = phase2_ind))` →
  `as_survey_twophase(phase1, subset = subset, method = "approx")` — Effort: low, Risk: low
- **[B]** Leave it to the implementer to discover the breakage during `devtools::test()`. — Effort: zero, Risk: high (confusing test failure)
- **[C] Do nothing** — Same as B.

**Recommendation: A** — This is one-line change in a helper file; it belongs in the spec's
affected-files list.

---

**Issue 18: `make_survey_data(design = "twophase")` Phase 2 sampling logic not described as a change**
Severity: REQUIRED
Violates engineering-preferences.md §5 (explicit over clever).

The current generator (line 146) produces Phase 2 membership via:
```r
df$phase2_ind <- runif(n) < 0.4
```
This is Bernoulli sampling — each row has a 40% chance independently of stratum.

The spec Section 9.2 states:
> "Phase 2 structure: SRS within each Phase 1 stratum at rate `phase2_frac`."

SRS within strata means: for each stratum, randomly select exactly `floor(n_stratum * phase2_frac)`
rows. This is different from Bernoulli sampling (exact count within each stratum vs. random count).
The `pbc` and `nwtco` oracle tests rely on within-stratum sampling fractions matching the `"approx"`
oracle — if the generator uses Bernoulli sampling, the oracle tests may have larger-than-expected
numerical differences.

The spec adds `phase2_frac = 0.4` as a new parameter but never states that the sampling logic must
change from Bernoulli to stratified SRS. An implementer following the spec might add the parameter
without changing the sampling method.

Options:
- **[A]** Add a sentence: "The Phase 2 indicator is computed by drawing exactly
  `floor(n_stratum * phase2_frac)` Phase 2 members from each Phase 1 stratum via `sample()`,
  replacing the current Bernoulli implementation." — Effort: low, Risk: low
- **[B]** Keep Bernoulli sampling and note that the oracle tests use real datasets (pbc, nwtco),
  not the synthetic generator, so the sampling method of the generator doesn't affect oracle
  accuracy. — Effort: low, Risk: low (oracle tests unaffected)
- **[C] Do nothing** — Implementer may or may not change the sampling method; generator behavior
  is inconsistent with spec description.

**Recommendation: B** — Oracle tests use real datasets. The synthetic generator is used only for
unit and edge-case tests, where exact stratification doesn't matter. Keep Bernoulli sampling for
simplicity and note it explicitly. The `phase2_frac = 0.4` parameter controls the target rate;
exact count vs. probability is not material for unit tests.

---

## Section IV — Architecture: Two-Phase Variance Engine

**Issue 19: Phase 2 FPC `sampsize` matrix construction unspecified**
Severity: REQUIRED
Violates engineering-preferences.md §5 (explicit over clever).

Section 4.4 specifies how to build the `popsize` matrix for the Phase 2 FPC argument passed to
`.svy_recvar()`. But `.svy_recvar()` requires a list with **both** `sampsize` and `popsize`
matrices:
- `popsize`: Phase 2 population PSU count per stratum — specified in Section 4.4 for both the
  explicit-fpc and null-fpc cases.
- `sampsize`: Phase 2 sample PSU count per stratum — **never specified**.

The `sampsize` matrix for Phase 2 is the number of unique Phase 2 PSU IDs per Phase 2 stratum
within the Phase 2 sample (rows where `subset == TRUE`). This is analogous to the Taylor engine's
sampsize computation, but the spec does not state this.

This gap means an implementer cannot build the complete `fpcs` list for `.svy_recvar()`. The
reference to "same matrix-building logic as Phase 1 FPC (via `as.fpc()` equivalent)" in the
explicit-fpc case is insufficient: `as.fpc()` is an internal `survey` function and its equivalent
logic is not described.

Options:
- **[A]** Add a bullet to Section 4.4 specifying `sampsize` construction: "The `sampsize` matrix
  is derived from the Phase 2 sample — for each Phase 2 stratum, count the unique Phase 2 PSU
  IDs among rows where `subset == TRUE`. If no Phase 2 strata or PSU IDs are specified, `fpcs` is
  `NULL` (no FPC correction)." Also replace "via `as.fpc()` equivalent" with an explicit
  description of the matrix-building logic. — Effort: low, Risk: low
- **[B]** Note: "Follow the `sampsize`/`popsize` matrix construction from `.taylor_build_inputs()`
  applied to Phase 2 rows only." — Effort: very low, Risk: medium (implementer must reverse-engineer
  from the Taylor code)
- **[C] Do nothing** — Implementer cannot complete the FPC list; will likely guess wrong.

**Recommendation: A** — The Phase 2 FPC construction is already complex; making `sampsize`
explicit prevents a likely implementation error.

---

## Section VI — Public Dispatch

**Issue 20: `test-variance-dispatch.R` — no test blocks specified for `survey_twophase` dispatch**
Severity: REQUIRED
Violates testing-standards.md (happy-path tests required for every exported function).

Section 11 quality gate states:
> "`get_means()` and `get_totals()` dispatch to `.twophase_mean()` / `.twophase_total()` for
> `survey_twophase` inputs — verified by `test-variance-dispatch.R`"

But Section 9 specifies no test blocks in `test-variance-dispatch.R` for this new branch.
Section 9.1 only lists the file as "Extracted from `test-variance-estimation.R`", implying the
existing tests are relocated but no new ones are added. A `survey_twophase` dispatch call to
`get_means()` / `get_totals()` is not covered.

Without these test blocks, the dispatch code (Section 6.2–6.3) has no unit test coverage in the
file that the quality gate cites.

Options:
- **[A]** Add a test block description to Section 9 (or an addendum in Section 6.2):
  ```r
  test_that("get_means() dispatches to .twophase_mean() for survey_twophase input", {
    # Creates a valid twophase design, calls get_means(); expects list(variable, mean, se)
  })
  test_that("get_totals() dispatches to .twophase_total() for survey_twophase input", { })
  ```
  — Effort: low, Risk: low
- **[B]** Note that the oracle tests in `test-variance-twophase.R` call `get_means()` on a
  `survey_twophase` object and thereby test the dispatch path; `test-variance-dispatch.R` doesn't
  need a separate dispatch test. — Effort: zero, Risk: low (oracle tests serve double duty)
- **[C] Do nothing** — Quality gate cites a test file for a test that isn't specified.

**Recommendation: A** — The oracle tests verify numerics; a dedicated dispatch test verifies the
dispatch path in isolation (no `skip_if_not_installed` required). Two blocks, low effort.

---

## Section IV — Architecture (minor)

**Issue 21: `w1[i]` in Phase 2 score formula — extraction path unstated**
Severity: SUGGESTION
Violates engineering-preferences.md §5 (explicit over clever).

Section 4.4 specifies the Phase 2 score for the `"full"` and `"approx"` methods as:
```
influence[i] * sqrt(phase1_prob[i])  where phase1_prob[i] = 1 / w1[i]
```

`w1[i]` is defined as "Phase 1 survey weight for row i." But `.twophase_phase2_var()` receives
`(influence, design, subset, lonely.psu)` — it does not receive a precomputed weight vector. The
function must extract `w1` from `design@data[[design@variables$phase1$weights]]`. This extraction
is not stated in the function contract.

Options:
- **[A]** Add a note to Section 4.4: "Phase 1 weights for Phase 2 rows are extracted as
  `design@data[[design@variables$phase1$weights]][subset]`." — Effort: low
- **[B]** Leave it as inferable from the S7 structure. — Effort: zero, Risk: low (any R dev
  familiar with the structure would find this)
- **[C] Do nothing** — Same as B.

**Recommendation: B** — The extraction is obvious from the design structure. Documenting it
would add noise without meaningful clarification.

---

## Summary

### Round 1 (all resolved)

| Severity | Count |
|----------|-------|
| BLOCKING | 6 |
| REQUIRED | 6 |
| SUGGESTION | 4 — 3 resolved, 1 accepted as-is |

### Round 2 (new)

| Severity | Count |
|----------|-------|
| BLOCKING | 1 |
| REQUIRED | 4 |
| SUGGESTION | 1 |

**New total issues: 6**

**Overall assessment:** The spec has been substantially improved by the Round 1 resolutions. One
new blocking issue remains: the column naming conflict between the spec schema (`weight`, `subset`)
and the existing generator (`wt`, `phase2_ind`). If left unresolved, the implementer will build a
generator whose usage example does not run. The four required issues are all low-effort additions
(one-line spec clarifications or a test block description) and should not significantly delay
implementation.
