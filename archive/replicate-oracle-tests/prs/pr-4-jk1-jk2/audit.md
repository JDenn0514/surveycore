# Audit — PR 4 — test/replicate-oracle-jk1-jk2

**Verdict**: PASS
**Date**: 2026-09-22

Scope of the verdict: the ten rows allocated to this PR, plus the profile
gates. Seven rows are verified directly and pass. Three rows (5.1, 5.2, 5.3)
are recorded as deferred to the reviewer and are not counted as passes. All
gates pass on the audited tree.

Head `d266759ba26b4a52ac6e98922069ddca93f7a9ab`, base
`bf47f79f4f8de9aeead6ddce47a8472d89556eaf`. Diff: 1 file, +48/-21.

## Instruments used

This tester started no R process; the run leader held the gate pass on the
same tree. Every row below was measured with `git`, `grep`, `awk`, `sed` and
the `air` CLI. The gate figures in §Profile gates come from the leader's run
on tree `77ba0ec4cd3e0cf5427e9ba15aaf72c101668147` — the tree this audit
records, so they are results of the audited code.

- Call-site parsing for row 2.2 used an `awk` parenthesis-depth walker over
  the file, which prints each `survey::svrepdesign(` call with its full
  argument list to the matching close paren. `getParseData()` would need R
  and was not used. `grep -c` was not used for any occurrence count — the
  file carries `svrepdesign` inside comment text on two lines.
- Comment conformance used `grep -n -F` with the full literal string plus a
  per-line character count.

## Per-Test Result Table

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| 2.2 — no `survey::svrepdesign()` call receives `scale` | 0 of 10 calls | 0 hits | n/a | ✓ |
| 2.5 — `suppressWarnings(` absent from the file | 0 | 0 hits | n/a | ✓ |
| 2.25 — JK1 body computes no default-scale formula | 0 computing lines; 1 assertion literal | 0 computing lines | n/a | ✓ |
| 3.1.2 — JK1 block asserts one warning, the fragment, four quantities, stored scale `(R-1)/R` | all present; gate 2 green | all present | 1e-10 / 1e-8 / 1e-6 / 1e-8 | ✓ |
| 3.1.3 — JK2 block asserts one warning, the fragment, no `suppressWarnings`, both stored scales at `1` | all present; gate 2 green | all present | 1e-10 / 1e-8 / 1e-6 / 1e-8 | ✓ |
| 5.1 — JK1 block fails on SE and both bounds under a broken default | not measurable here | fails on 3 | n/a | deferred |
| 5.2 — JK1 point estimate still passes under a broken default | not measurable here | passes | n/a | deferred |
| 5.3 — every other block unchanged under a broken default | not measurable here | unchanged | n/a | deferred |
| 5.4 — JK1 block passes again after the revert | tree identical to base; gate 2 `FAIL 0` on this tree | passes | n/a | ✓ |
| 5.5 — no modified source file in the working tree | 0 files under `R/` | 0 | n/a | ✓ |

### Row 2.2 — evidence

The `awk` walker finds ten `survey::svrepdesign(` calls, at lines 34, 75,
123, 180, 260, 335, 424, 466, 508 and 550. Every one carries the same five
arguments and no others:

```
weights = d$wt, repweights = d[, repwt_cols], type = "...", mse = ..., data = d
```

No call receives `scale` and none receives `rscales`. Two further
`svrepdesign` strings sit inside comments (lines 153 and 312) and are not
calls.

The two pre-existing `scale = 0.2` arguments are at lines 627 and 642, both
inside `surveycore:::.svy_rep_var()` calls in `# Block 16`. They build no
`survey` design, are outside the rule per the test-spec note on row 2.2, and
are unchanged by this PR.

### Row 2.5 — evidence

`grep -c "suppressWarnings" tests/testthat/test-variance-replicate.R` returns
`0`. The diff removes both prior uses: the JK1 wrapper at old line 114 and
the JK2 wrapper at old line 162.

### Row 2.25 — evidence

The deleted line was:

```r
  jk1_scale <- (n_rep - 1L) / n_rep
```

It is gone, together with its `scale = jk1_scale` argument. Within the JK1
block (lines 96–148) `n_rep` now appears twice:

```r
108:   n_rep <- length(repwt_cols)
139:   expect_equal(sv$scale, (n_rep - 1) / n_rep, tolerance = 1e-8)
```

Line 108 reads the replicate count off the selected columns, which row 2.24
requires. Line 139 is the stored-scale assertion literal, which row 6.16 and
the settled argument-versus-literal distinction allow. No line in the block
computes the scale for use as an argument.

### Row 3.1.2 — evidence

Delivered, lines 122–147:

```r
  jk1_warnings <- testthat::capture_warnings(
    sv <- survey::svrepdesign(
      weights = d$wt,
      repweights = d[, repwt_cols],
      type = "JK1",
      mse = TRUE,
      data = d
    )
  )
  expect_length(jk1_warnings, 1L)
  expect_match(
    jk1_warnings,
    "guessing n=number of replicates",
    fixed = TRUE
  )

  # Guards survey's default; a failure means survey changed, not surveycore; SE/variance row, 1e-8.
  expect_equal(sv$scale, (n_rep - 1) / n_rep, tolerance = 1e-8)
  ...
  expect_equal(sc_mean$mean, coef(sv_mean)[["y1"]], tolerance = 1e-10)
  expect_equal(sc_mean$se, as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)
  expect_equal(sc_mean$ci_low, confint(sv_mean)[1], tolerance = 1e-6)
  expect_equal(sc_mean$ci_high, confint(sv_mean)[2], tolerance = 1e-6)
```

Exactly one warning asserted (`expect_length(..., 1L)`), the fragment matched
with `fixed = TRUE`, all four quantities present at the standing tolerances,
and `survey`'s stored scale asserted against the literal formula at `1e-8`.
`mse = TRUE` goes to both sides: the constructor at line 115, `svrepdesign()`
at line 127. Gate 2 reports `FAIL 0` on this tree, so the four numbers agree
within those tolerances.

### Row 3.1.3 — evidence

Delivered, lines 167–204. The surveycore-side stored-scale assertion is kept:

```r
174:   expect_equal(sc@variables$scale, 1)
```

and the `survey`-side assertion is added:

```r
188:   expect_length(jk2_warnings, 1L)
189:   expect_match(
190:     jk2_warnings,
191:     "with type JK2 scale= and rscales= are not needed",
192:     fixed = TRUE
193:   )
195:   # Guards survey's default; a failure means survey changed, not surveycore; SE/variance row, 1e-8.
196:   expect_equal(sv$scale, 1, tolerance = 1e-8)
```

No `suppressWarnings()` remains. Both stored-scale assertions read against a
literal `1`, so neither side is asserted against the other (row 2.6 shape).
`mse = TRUE` goes to both sides: the constructor at line 172, `svrepdesign()`
at line 184. The four quantities are at lines 201–204 at 1e-10, 1e-8, 1e-6
and 1e-6.

Observation, not a defect and not one of my rows: line 174 carries no
explicit `tolerance`, so it uses `expect_equal()`'s default. It asserts
surveycore's stored scale, not `survey`'s, so §3.2 item 5 and §8 do not reach
it. The line is unchanged from the base.

### Rows 5.1, 5.2, 5.3 — deferred, with the reason

**Not independently verifiable by the tester; the evidence is the builder's,
for the reviewer to check.**

§5 is a claim about a past experiment, not about the delivered file. It asks
what failed while the replicate constructor's JK1 default scale was
deliberately set to `1`. Reproducing it needs an edit under `R/` and an R
process. This tester was instructed to start no R process — a gate pass was
in flight on this same tree — and the experimental edit is already reverted,
so the state the rows describe no longer exists anywhere on disk.

These three rows are therefore neither passed nor failed here. The builder's
evidence sits in `implementation.md`, which the tester may not read. The
reviewer reads it and settles the rows. The completed gate run changes
nothing for them.

For the record, so a later reader can spot a contradiction: the run leader
relayed that the builder reports `FAIL 3` under the broken default, all three
in the JK1 block — the standard error and both confidence bounds — with the
point estimate still passing, and a clean revert to
`FAIL 0 | WARN 1 | PASS 143` on the single file. Nothing measured in this
audit contradicts that shape. The JK1 block's point estimate is the only one
of its four numerical assertions that does not carry the scale, and gate 2's
`FAIL 0` on the reverted tree matches the post-revert half.

### Row 5.4 — evidence (both halves hold)

The revert is complete. Subtree and blob hashes, base against head:

| Path | Base `bf47f79` | Head `d266759` | Same |
|---|---|---|---|
| `R` (tree) | `3146b739c8d173310ee6a8bfc225318fa885e757` | `3146b739c8d173310ee6a8bfc225318fa885e757` | yes |
| `man` (tree) | `f82e32a6512c8c41b146a648257fd962e2fbc614` | `f82e32a6512c8c41b146a648257fd962e2fbc614` | yes |
| `NAMESPACE` | `27c131881726a06dfc55ccdcfeb5f115a265052a` | `27c131881726a06dfc55ccdcfeb5f115a265052a` | yes |
| `DESCRIPTION` | `70660166464ffb09b2aa0ce94e6ba3973efbdb8c` | `70660166464ffb09b2aa0ce94e6ba3973efbdb8c` | yes |
| `R/core-constructors.R` (blob) | `066389be4101989349829017bd8e5a4f85a5ff79` | `066389be4101989349829017bd8e5a4f85a5ff79` | yes |

`git diff --name-only bf47f79 HEAD -- R/` lists zero files. The file that
held the experimental edit is byte-identical to the base.

The run half is now answered. Gate 2 ran `devtools::test()` on this exact
tree and reported `FAIL 0`, so the rewritten JK1 block passes after the
revert. The row is fully verified.

### Row 5.5 — evidence

`git status --porcelain -- R/` returns nothing. The full porcelain lists six
paths, all pipeline bookkeeping under `plans/`:

```
 M plans/pr-budget-calibration.md
?? plans/comprehension-replicate-oracle-tests.md
?? plans/decisions-replicate-oracle-tests.md
?? plans/implementation-plan-replicate-oracle-tests.md
?? plans/spec-replicate-oracle-tests.md
?? plans/test-spec-replicate-oracle-tests.md
```

No source file is modified.

## Settled conventions — conformance checked, not re-litigated

**The stored-scale comment.** Decision S4 fixes the comment as a
99-character string, deliberately over the 80-column limit. `grep -F` against
the full literal finds 10 exact matches, at lines 43, 84, 138, 195, 269, 344,
433, 475, 517 and 559. Each line measures 99 characters including the
two-space indent, and each is followed immediately by its stored-scale
assertion. The expected count after this PR is 10; delivered 10 of 10. Lines
138 and 195 are this PR's two new comments and match character for character.
The length is recorded, not reported as a defect.

**`mse` passed explicitly to both sides.** Both rewritten blocks do:

| Block | surveycore constructor | `survey::svrepdesign()` |
|---|---|---|
| JK1 | `mse = TRUE`, line 115 | `mse = TRUE`, line 127 |
| JK2 | `mse = TRUE`, line 172 | `mse = TRUE`, line 184 |

The JK2 `mse = TRUE` on the constructor side is new in this PR; the base
relied on the constructor default.

## Scope checks

| Check | Result |
|---|---|
| `git diff --name-only bf47f79 HEAD` | one file: `tests/testthat/test-variance-replicate.R` — no third file |
| `air format --check tests/testthat/test-variance-replicate.R` | exit 0, clean (`air` 0.11.0) |
| Rows outside this PR's allocation | not audited, not failed — §6 belongs to PRs 1, 2 and 9; §3.1.1, 3.1.6, 3.1.7 shipped in PR 3; §3.1.4, 3.1.5, 3.1.8, 3.1.9 and §4 belong to PRs 5 to 8 and do not exist yet |

## CRAN cookbook violations

None. The PR changes no file under `R/`, so the scan has an empty target set.
The 48 added lines were scanned anyway for the file-agnostic patterns —
`<<-`, `options(warn = -1)`, `installed.packages()`, `set.seed()`,
`mc.cores`, `makeCluster()` and bare `T`/`F` as logicals — with zero hits.

## Before/After Comparison

Before column is the dispatch baseline, measured on `develop` at `7800ea9`
and recorded in `baseline.md`. The pre-PR state was not reconstructed.

| Figure | Baseline (`7800ea9`) | After PR 3 | This PR | Δ vs PR 3 |
|---|---|---|---|---|
| Failures | 0 | 0 | 0 | 0 |
| Warnings | 256 | 256 | 256 | 0 |
| Skips | 4 | 4 | 4 | 0 |
| Passes | 11941 | 11977 | 11982 | **+5** |
| Coverage | 96.15% | 96.15% | 96.15% | 0.00 |
| `R CMD check` NOTEs | 2 | 2 | 2 | 0 |

Two figures need a line, because a later reader will ask about both.

**The warning count held at 256.** This PR removed the only two
`suppressWarnings()` wrappers in the file, and both wrapped a `survey` call
that genuinely warns. A bare `expect_warning()` on the fragment, or a
condition left to escape, would have raised the suite total. It did not,
because `capture_warnings()` consumes the warning while the block counts it
and matches it. That is the mechanism the oracle rule's rule 5 asks for:
assert the condition, do not silence it, and do not leak it.

**+5 net is small for a whole-block rewrite** because the rewrite deleted
assertions as well as adding them — 48 insertions against 21 deletions.

Coverage is flat, as expected: the PR adds test code and no source line. The
95% floor holds with 1.15 points of margin.

## Profile gates

Run by the run leader on tree `77ba0ec4cd3e0cf5427e9ba15aaf72c101668147` —
the tree this audit records, so these are results of the audited code.

| Gate | Result | Notes |
|---|---|---|
| `devtools::document()` | PASS | `document()` wrote nothing |
| `devtools::test()` | PASS | `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11982 ]` |
| `run_examples()` | PASS | all examples ran |
| `R CMD build` | PASS | `surveycore_1.1.0.9000.tar.gz` |
| `R CMD check --as-cran --no-manual` | PASS | Status: 2 NOTEs, both pre-existing — see below |
| pkgdown | SKIPPED — scope | one test file; `NAMESPACE` diff empty |
| `covr` | PASS | 96.15% |
| CRAN cookbook scan | PASS | no `R/` file changed; 48 added lines scanned clean |

Logs: `.surveycore-workspace/runs/2026-09-16-replicate-oracle-tests/logs/pr4/`

**Both NOTEs are pre-existing, and they are these two.** Read gate 5 as
"2 NOTEs, and these two" — a third blocks.

| NOTE | Status |
|---|---|
| `checking CRAN incoming feasibility` | pre-approved in `r-package-conventions.md`; the package is not on CRAN |
| `checking for hidden files and directories` | `R CMD build` finds `.git`; caused by `.Rbuildignore`, present on the clean baseline, and not fixable by this arc |

Both appeared identically on the baseline run and on PRs 1 to 3. Neither is a
new pattern, so neither warrants an escalation.

The 256 warnings are the pre-existing unasserted small-cell warnings on a
clean base branch (issue #167). The gate reads as "no new warning", and the
count is unchanged.

Tree: `77ba0ec4cd3e0cf5427e9ba15aaf72c101668147`

## BLOCKs

None.
