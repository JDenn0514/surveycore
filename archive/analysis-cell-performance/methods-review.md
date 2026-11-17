## Methodology Review: analysis-cell-performance — Pass 1 (2026-11-10)

Scope assessment: applicable. The spec changes how six functions compute
Taylor and replicate variances, although every number must stay the same.
Lenses 1 to 6 applied. Lens 6 ran because `comprehension.md` exists. Each
lens ran as a separate agent on the spec, `comprehension.md`,
`decisions.md` and the R source.

Lens summary. No lens found a BLOCKING issue. Lenses 1, 2 and 5 confirmed,
against `R/variance-taylor.R` and `survey:::onestage`, that each column of
the stack gives its own variance when every column is finite. Lonely-PSU
handling and the FPC depend on the design only. The 64-cell blocks (D10) are
exact for finite columns. Lens 5 found that D7 is stricter than `survey`:
`survey` returns the contaminated diagonal.

### New Issues

**Issue 1: The SE step and the `.vcov` step are not limited to the Taylor route**
Lenses: 1, 2, 6
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

§II.5 step 4 says "the SE step of §III.3 runs" after every cell loop. The
§III.3 table names no route. For `get_ratios()`, `live` is "the cells that
reached call 3", which also includes replicate, nonprob-SRS and two-phase
cells. Step 5 says "`.vcov` is attached from the matrix computed in step 4.
No second joint computation runs." The replicate route has no step-4 matrix
from `.taylor_cell_se()`. comprehension.md condition 4: "The
`.svy_rep_vcov()` diagonal is not bit-identical to `.svy_rep_var()`. Fix 2
is for the Taylor route only." The 1e-12 tolerance would not catch that
drift.

Fix: step 4 and `.taylor_cell_se()` run on the Taylor route only. On the
replicate route the SE stays the per-cell `.svy_rep_var()` result, and
`.vcov` is attached as today (`.attach_joint_vcov(result, design, joint)`
with `v = NULL`). On the two-phase and nonprob-SRS routes nothing changes.
Reword step 5 to match.

**Issue 2: The test-spec domain designs miss two routes and the `NA` marker**
Lens: 4
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

Spec §I.4 and §XI gate 1 require equality with and without a domain marker
for every class and route. Test-spec §2.5 has no two-phase domain design and
no nonprob-SRS domain design. `.testhelper_mark_domain()` refuses an `NA` in
`keep`, so no test stores an `NA` marker, which the validator accepts and
`.apply_domain()` reads as `FALSE`. The helpers `make_domain_pair()` and
`set_domain_marker()` in `tests/testthat/helper-test-data.R` already build
such designs. The two-phase variant also marks a phase-1-only row `TRUE`.

Fix: add `tph_dom` (with at least one phase-1-only row marked `TRUE`) and
`np_srs_dom`. Add one `NA`-marker design per route, built with
`make_domain_pair()`, and assert its results equal the pair's `NA`-free
twin. Reword the test-spec claim to "the same object as `filter()` gives,
for a marker with no `NA`".

**Issue 3: The condition-order change names two errors and one option value**
Lenses: 2, 6
Severity: ADVISORY
Resolution type: UNAMBIGUOUS (after D9)

§X.1 carries a GAP that lists two later-cell errors. Lens 2 found more of the
same kind. `get_means()` can raise a base R error from a later cell.
`get_variance()` and `get_covariance()` raise a base R error for an `NA` base
weight inside a later cell (§X.3). A mistyped `survey.lonely.psu` value raises
`surveycore_error_lonely_psu_unknown_option`, on an `nPSU == 1` stratum only.
That abort moves to the SE step in the same way.

Fix: D9 (user, 2026-11-10) accepts errors from later cells. Remove the GAP.
State the rule in general form: any condition that a later cell raises now
comes before the moved abort. List the known cases. Add the unknown-option
abort as a second abort that moves the same way.

**Issue 4: `.taylor_cell_se()` must return an unnamed vector**
Lens: 2
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

`diag(v)` keeps names when the row and column names match, and
`.svy_multistage` sets `dimnames(v)` from `colnames(x)`. Today each cell
returns an unnamed `sqrt(max(0, v[1, 1]))`. A named SE that reaches the
result changes what `expect_equal()` compares.

Fix: the contract says the return is unnamed in every rule, and `vals` is
built without column names, or the names are removed before use.

**Issue 5: "`total_x` is finite and non-zero for a live cell" is false**
Lenses: 2, 4
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

`get_ratios()` aborts on a zero denominator only when `n_cell > 0`. With
`na.rm = FALSE`, an all-`NA` numerator and an all-zero denominator give
`n_cell == 0` and `total_x == 0`, and the cell reaches call 3. The result
stays correct, because `z` is `NA` and the finite check fails.

Fix: reword §IX to "the scaled columns can be finite only when the unscaled
columns are, so a check on the unscaled columns is safe". Add the case to
§IX edge cases (the finite check fails, each SE comes from its own call,
`.vcov` from the scaled stack). Add a test-spec scenario.

**Issue 6: The rationale for the merged `crossprod()` leaves out R's NaN/Inf check**
Lenses: 1, 5
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

§III.2 says the merged product gives the same result because both forms read
every row. R's default `matprod` checks both operands for NaN and Inf, and
when it finds one it runs the whole product in its internal long-double loop.
Today `domain %*% rep_mat` stays on BLAS when `y_safe` holds an `NA` or
`Inf`. In the merged call it does not, so the last bit of `rep_N_d` can
change. The outputs do not change: with a finite `rep_mat`, `rep_Y` is
non-finite for every replicate, so every replicate estimate is `NA`, `NaN`
or `Inf` whatever `rep_N_d` holds. Lenses 1 and 2 agree. §XV has no evidence
for this input.

Fix: replace the §III.2 sentence with this reasoning. Add test-spec rows on a
`survey_replicate` design and a replicate `survey_nonprob` design: `NA` in
`y` with `na.rm = FALSE`, and `Inf` in `y`. Each row compares `get_means()`
against the stored old results, including the count of the
domain-replicates-NA warning.

**Issue 7: §X.2 does not say that `survey` gives the same `.vcov` diagonal**
Lens: 5
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

`survey:::onestage` drops a stratum when any entry of its `p x p` block is
`NA`, so `survey::svyby(covmat = TRUE)` returns the same contaminated
diagonal. A later reader may "fix" the kept mismatch.

Fix: add one sentence to §X.2. The `se` column follows `survey`'s
one-statistic call, and `.vcov` follows `survey`'s multi-column call.

**Issue 8: The uncalibrated `get_means()` cell `df`, and the df contract, are not stated**
Lens: 3
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

§V says "do not call `.degf_taylor()`" for an uncalibrated design but does
not say what the cell returns for `df`. §I.3 says df "does not change" but
not what it is. The column narrowing depends on `.degf_taylor()` reading
only `ids[[1]]`, `strata` and `nest` (`R/analysis-helpers.R:349-380`).

Fix: state that the uncalibrated cell omits `df`. `get_means()` turns a
missing `df` into `Inf` and does not read it, and `get_quantiles()` reads
only `mean` and `se`. Add a three-row df table to §V: uncalibrated Taylor,
replicate and nonprob give `Inf`; calibrated Taylor gives
`max(1, .degf_taylor(cell rows)) - sum(QR ranks)`, clamped to at least 1
with a warning; cells of kind `"na"` give `Inf`. Add a comment requirement at
`.degf_taylor()` that names the columns it reads. In the test-spec, add
calibrated `get_means()` scenarios that pin the `df` column across a
one-stage, a strata-only, an ids-only, a no-structure and a two-stage `ids`
design.

**Issue 9: The "influence column" definition says every function applies calibration**
Lens: 1
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

§I.1 defines the influence column as the vector after
`.maybe_apply_calibration()`. `get_variance()` and `get_covariance()` do not
project (§VII; `R/analysis-variance-helpers.R:156-161`).

Fix: edit the row to "after `.maybe_apply_calibration()` where the function
applies it (not `get_variance()` or `get_covariance()`)". Add a per-function
table from comprehension.md §Influence column per function, marked
unchanged. Add: "`compute_se = FALSE` does not change the influence column
or any other cell field."

**Issue 10: The zero-combination path is not stated**
Lens: 6
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

comprehension.md §Gotchas: zero combinations give zero cells, and
`.attach_joint_vcov()` returns early (`R/analysis-helpers.R:1270-1272`). The
spec does not say that the early return still comes before any use of `v`.

Fix: with zero cells, step 4 does not run and `.attach_joint_vcov()` keeps
its early return before it reads `v`.

**Issue 11: Planner defaults are not in decisions.md**
Lens: 6
Severity: ADVISORY
Resolution type: UNAMBIGUOUS (after D10, D11)

The blocks of 64 and the domain-marker helper were planner choices with no
decisions.md entry.

Fix: done. D10 (user) and D11 (planner default) are now in `decisions.md`.
The spec marks both by their D number.

**Issue 12: Some spec claims have no pointer to their evidence**
Lens: 6
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

§III.3 "Why the finite check is needed" and "Why the blocks" cite no source
line. The same is true of the calibrated-design rows that depend on guard 1
and `qr.resid()` (`R/calibration.R:386-388, 434`), `.joint_vcov()`
(`R/analysis-helpers.R:1215-1254`), `.degf_taylor()` (`:349-380`) and
`vcov.survey_result()` (`R/analysis-methods-coef-vcov.R:452-480`). The
`get_variance()` row "`Inf` in `x`: the cell's estimate and influence column
are `NaN`" has no source in comprehension.md.

Fix: add file:line and comprehension.md condition pointers at these places.
Source the `Inf` row from the code or drop its "estimate is `NaN`" clause and
keep only "the finite check fails".

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 2 |
| ADVISORY | 10 |

**Total issues:** 12

**Verdict: FAIL** (two REQUIRED-UNAMBIGUOUS findings). The user settled the
two judgment items that the draft raised before this review (D9, D10). No
JUDGMENT_CALL is open.

**Assessment:** the method is sound and exact for finite columns. The main
risk is a literal reading that applies the Taylor SE step to the replicate
route, and the test-spec does not yet cover two routes or the `NA` marker
under domain restriction.

---

## Methodology Review: analysis-cell-performance — Pass 2, delta (2026-11-10)

Two agents. One read the 17 changed spec sections (v1.1) and checked the
claims against the R source. The other read the 13 changed test-spec
sections and `tests/testthat/helper-test-data.R`.

### Prior Issues (Pass 1)

| # | Title | Lens | Status |
|---|---|---|---|
| 1 | SE step and `.vcov` step not limited to Taylor | 1, 2, 6 | ✅ Resolved |
| 2 | Test-spec domain designs miss two routes and the `NA` marker | 4 | ✅ Resolved |
| 3 | Condition-order change names only some cases | 2, 6 | ✅ Resolved |
| 4 | `.taylor_cell_se()` must return an unnamed vector | 2 | ✅ Resolved |
| 5 | "`total_x` is finite and non-zero" is false | 2, 4 | ✅ Resolved |
| 6 | Merged `crossprod()` rationale leaves out the NaN/Inf check | 1, 5 | ✅ Resolved |
| 7 | §X.2 does not say `survey` gives the same diagonal | 5 | ✅ Resolved |
| 8 | Uncalibrated cell `df` and the df contract | 3 | ✅ Resolved |
| 9 | Influence-column definition and calibration | 1 | ✅ Resolved |
| 10 | Zero-combination path | 6 | ✅ Resolved |
| 11 | Planner defaults not in decisions.md | 6 | ✅ Resolved |
| 12 | Claims without a pointer to evidence | 6 | ✅ Resolved |

The spec agent found no new statistical error. Every route still gets an
SE and a `.vcov` as today. Both lonely-PSU aborts depend on the design only
(`R/variance-taylor.R:74-87`).

### New Issues

**Issue 13: Row 5.1.10 asserts a non-finite diagonal that is finite**
Severity: REQUIRED. Resolution type: UNAMBIGUOUS.
On the uncalibrated `means/tay_y1_na`, `.svy_onestage()` drops the one
stratum whose block holds an `NA` and rescales by `nstrat / nokstrat`. So
group A's stored diagonal is finite but differs from `se^2`. Spec §X.2
measured the same shape on uncalibrated `get_totals()` (31.14 against
41.53). Fixed: the row now asserts that the diagonal differs from `se^2`.

**Issue 14: Row 5.6.4's warning count of 1 has no fallback**
Severity: ADVISORY. Resolution type: UNAMBIGUOUS.
Fixed: if the observed count differs, assert the observed count on both
`a` and `b`, and record it in the PR.

**Issue 15: The §5.1 preamble names only group B**
Severity: ADVISORY. Resolution type: UNAMBIGUOUS.
Fixed: the preamble names group C for `ratios/tay_c_zero_den`.

**Issue 16: Document purpose does not name D11 as reopenable**
Severity: ADVISORY. Resolution type: UNAMBIGUOUS.
Fixed in the spec's Document purpose.

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 1 |
| ADVISORY | 3 |

The orchestrator applied the four fixes directly. They change test rows and
one sentence of the spec's purpose. None changes a formula, a variance
rule or a route. Under the methodology lock rule (test-plan additions and
wording do not reopen Stage 2), no pass 3 runs.

**Verdict: PASS.** Methodology locked at spec v1.1.
