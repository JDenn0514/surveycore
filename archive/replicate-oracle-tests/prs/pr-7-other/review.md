# Review — PR 7 — `test/replicate-oracle-other`

**Verdict**: PASS
**Date**: 2026-09-22
**Branch**: `test/replicate-oracle-other` at `c8cb70b6f354b5cb165af1d471fa266f1055e3f6`
**Base**: `f1270827867c7712ba14159aa5660158e43864ac`
**Tree reviewed**: `11b2f6b7485aa15ea5945d219918b3fc69fbe5d9` — the same tree the
audit records and the same tree the gate runner logged.

---

## Convergence checks

| Check | Result |
|---|---|
| Spec coverage — every `spec.md` §V.8 and §IV.3 item has an audit row | yes |
| Test-spec coverage of spec — §V.8 → rows 3.1.8, 3.2, 2.17, 2.18; §IV.3 item 4 → §4 | yes |
| Implementation coverage of plan — write surface matches PR 7's "Files touched" | yes |
| Tolerance integrity | yes — no tolerance changed, widened or substituted |
| Scope discipline | yes — one file, `+59/-0`, append-only |
| Regression safety | yes — no test outside PR scope changed state |
| Comprehension alignment | yes — §G4's `other` fact and §O4's fixture question both land in the block |
| `audit.md` verdict | PASS on the three measurable rows; rows 4.1–4.3 deferred here and settled below |

---

## Rows 4.1, 4.2, 4.3 — settled: all three pass

**I re-ran the probe myself.** No gate pass was in flight, so R was free. The
script lived in the session scratchpad, outside the repository, and
`git status --porcelain` after the run is byte-identical to the status before
it: one modified and five untracked files under `plans/`, all of them pre-existing
arc bookkeeping, none of them written by me. `HEAD` and the tree hash are
unchanged.

Instrument: `pkgload::load_all()` on this worktree plus
`tests/testthat/helper-test-data.R`, eight designs built the way each block
builds its own, then `sc@variables$scale <- 2 * scale` and a second
`get_means(sc, y1, variance = c("se", "ci"))`.

My reading, at 15 significant digits:

| Type | Mode / seed | R | scale | Δ point | `identical(Δ, 0)` | Δ SE | SE ratio | Δ ci_low |
|---|---|--:|---|---|---|---|---|---|
| BRR | `brr` / 7 | 10 | `0.10` | `0` | TRUE | `0.0254446923538510` | `1.41421356237309` | `-0.0498706806112494` |
| JK1 | `jk1` / 15 | 20 | `0.95` | `0` | TRUE | `0.0994886254915372` | `1.41421356237310` | `-0.1949941228348067` |
| JK2 | `jk1` / 15 | 20 | `1.00` | `0` | TRUE | `0.1020731760330244` | `1.41421356237310` | `-0.2000597488123432` |
| JKn | `jkn` / 15 | 20 | `0.95` | `0` | TRUE | `0.0994886254915372` | `1.41421356237310` | `-0.1949941228348067` |
| bootstrap | `bootstrap` / 15 | 20 | `0.05` | `0` | TRUE | `0.0228242560289145` | `1.41421356237310` | `-0.0447347197905898` |
| ACS | `brr` / 302 | 10 | `0.40` | `0` | TRUE | `0.0595955942558190` | `1.41421356237310` | `-0.1168052183786656` |
| successive-difference | `brr` / 300 | 10 | `0.40` | `0` | TRUE | `0.0972168655802922` | `1.41421356237309` | `-0.1905415552272416` |
| `other` | `jk1` / 15 | 20 | `1.00` | `0` | TRUE | `0.1020731760330244` | `1.41421356237310` | `-0.2000597488123432` |

`Δ ci_high` is the negative of `Δ ci_low` on all eight, to every printed digit.

Aggregates:

- all `Δ` point estimates exactly `0`, and `identical(Δ, 0)` TRUE on all eight;
- `max |SE ratio − sqrt(2)| = 2.22044604925031e-16`;
- smallest `|Δ SE| = 0.0228242560289145`, which is `2282425.6 ×` the `1e-8`
  standard-error tolerance;
- smallest `|Δ bound| = 0.0447347197905898`, which is `44734.7 ×` the `1e-6`
  bound tolerance.

**Every cell of the builder's eight-by-three table reproduces digit for digit.**
Rows 4.1, 4.2 and 4.3 pass on my own measurement, not on the builder's report.

**`sqrt(2)` is the right predicted factor.** The stored scale multiplies the
variance, and the standard error is the square root of the variance, so doubling
the scale multiplies the standard error by exactly `sqrt(2)` and leaves the
point estimate untouched. The measured departure of one machine epsilon is what
an exact identity looks like in double precision.

**The figures are measured, not written from the formula.** Three relations hold
across the table that a formula-filled table would not carry for free:

1. `Δ bound = 1.959964 × Δ SE` on every row — the normal critical value. For
   bootstrap: `0.0228242560289145 × 1.959964 = 0.0447347`.
2. JK1/JKn (`scale = 0.95`) against JK2/`other` (`scale = 1`) on the same `jk1`
   data sit in the ratio `0.1020731760330244 / 0.0994886254915372 = 1.0259784`,
   which is `sqrt(1 / 0.95) = sqrt(20/19)` — the two scales' own square-root
   ratio.
3. Each type's `Δ SE` differs from the others, so no row is a copy.

**Neither flagged reading is a defect in the probe.**

- `R = 10` for BRR, ACS and successive-difference is the generator, not the
  probe. `tests/testthat/helper-test-data.R:512` returns `n_psu %/% 2L` for the
  `brr` and `fay` modes and `n_psu` for `jk1`, `jk2`, `jkn` and `bootstrap`. The
  three `brr`-fixture types therefore carry 10 columns at `n_psu = 20`, which is
  exactly what `test-spec.md` §3.1 rows 3.1.1, 3.1.6 and 3.1.7 state. I read
  `R = 10` on those three and `R = 20` on the other five, matching both.
- JKn's stored scale of `0.95 = (R-1)/R` at `R = 20` is issue #253, which the
  pinned JKn block already records in its own comment. The probe overwrites the
  stored scale whatever its value, so the defect cannot bias the measurement:
  the doubling is relative to whatever is stored, and the SE ratio came out
  `sqrt(2)` there as everywhere else.

**What this establishes for the arc.** A wrong stored scale is invisible to a
point-estimate assertion — the difference is bit-for-bit `0`, so no tolerance,
however tight, can see it — and unmissable to a standard-error or
confidence-bound assertion, by six and four and a half orders of magnitude
respectively. That is the mechanism by which issue #242 stayed green for 22
releases, and it is now measured on all eight numerical types. `spec.md` §IV.3
item 4 and `test-spec.md` §3.2 keep their measured footing.

---

## Row 2.18 — my own 13-of-13 count

**Instrument: `utils::getParseData()` on `parse(keep.source = TRUE)`, terminal
tokens with `token != "COMMENT"`**, walking the token stream for the triple
`SYMBOL "sv"` → `'$'` → `scale`. The comment side is an exact whole-line string
comparison in R, not a regular expression.

| Reading | My count |
|---|--:|
| `sv$scale` accesses in code | **13**, at lines 44, 85, 139, 196, 270, 345, 434, 476, 518, 560, 855, 931, **1015** |
| Exact canonical comment lines | **13**, at 43, 84, 138, 195, 269, 344, 433, 475, 517, 559, 854, 930, **1014** |
| `sv$scale` assertions whose immediately preceding line is that exact string | **13 of 13** |
| Distinct comment strings among the 13 | **1** |
| Lines mentioning `Guards survey` at all | **13** — so near-misses: **0** |

**None of the 13 is a paraphrase.** All 13 are one string, so the three-element
check is decided once for all of them:

    # Guards survey's default; a failure means survey changed, not surveycore; SE/variance row, 1e-8.

| Element row 2.18 requires | Text that supplies it | Present |
|---|---|---|
| Guards `survey`'s own default | `Guards survey's default` | yes |
| A failure means `survey` changed, not surveycore | `a failure means survey changed, not surveycore` | yes |
| The named tolerance row | `SE/variance row, 1e-8` | yes |

I measure the string at **97** characters and the whole line at **99** with its
two-space indent. Decisions S4 and S5 say "99 characters", which is the line —
the figure the 80-column rule measures — so their substance holds and this is
not a discrepancy.

**The three `sc@variables$scale` lines are correctly excluded.** My parse finds
16 `$scale` accesses in code: 13 on `sv` and 3 on `variables`, at lines 174, 379
and 400. Those three assert surveycore's own stored scale, which is a different
claim from pinning `survey`'s default, so row 2.18's denominator of 13 is right
and none of the three should carry the comment. Line 174's missing explicit
tolerance is finding N2 — pre-existing, outside this PR, and untouched by it.

The counting trap reproduces on my instrument, which is how I know the
instrument is reading code and not prose: `expect_failure` reads **12**
textually against **6** real calls, and `svrepdesign(` reads **15** against
**13**.

---

## Row 2.17 — three warning-count blocks, three of three

By the same parse: `testthat::capture_warnings()` **3** calls (lines 122, 179,
998), `expect_length()` **3** (131, 188, 1007), `expect_match()` **3** (132,
189, 1008), one triple per block — JK1, JK2, `other`. `expect_warning()` appears
**0** times in code and `suppressWarnings()` **0** times.

All three count assertions are `expect_length(x, 1L)` on the captured vector,
and each fragment match carries `fixed = TRUE`. The pattern is the counting one,
not a bare `expect_warning()`, which would match the fragment without counting
and so stay green when a second unexpected warning — including "Data do not look
like combined weights", the one that means the fixture moved — fires alongside.

---

## Row 3.1.8 and the block's shape

The block at lines 967–1024 carries, in order: the fixture at `jk1` / seed 15
with every argument a literal; `as_survey_replicate(type = "other", mse = TRUE)`;
`capture_warnings()` round `survey::svrepdesign(type = "other", mse = TRUE)`;
`expect_length(other_warnings, 1L)`; `expect_match(..., "scale or rscales not
specified, set to 1", fixed = TRUE)`; the commented
`expect_equal(sv$scale, 1, tolerance = 1e-8)`; then the four quantities at
`1e-10`, `1e-8`, `1e-6`, `1e-6`. Five of the five assertions `spec.md` §IV.3 and
`test-spec.md` §3.2 require.

**It did not copy the pinned shape.** `expect_failure()` has 6 real call sites
in the file, at 865, 868, 871 (JKn, opens 806) and 942, 949, 952 (bootstrap,
opens 886). None is at or after 967. The block also carries no ratio assertion,
which is correct: the ratio exists only to name the factor a wrapper cannot
report, and here the two sides agree to `2.4e-14` on the standard error.

**Neither `scale` nor `rscales` is supplied, and I checked it by parse, not by
eye.** `SYMBOL_SUB` tokens named `scale` sit at lines 627 and 642 only — the two
pre-existing blocks that call an internal variance routine and build no `survey`
design, which `test-spec.md` row 2.2's note puts outside the rule. `SYMBOL_SUB`
tokens named `rscales` sit at 229 (the two-constructor comparison block, no
oracle), 628 and 643 (the same two internal blocks), and 840 and 849 (the JKn
block, the same literal written out once per side). The `other` block holds
none. Finding F2's trap is avoided: `survey` honours a supplied `scale` for
`other` **and still raises the same warning**, so supplying one would silence
nothing and would restore the round trip the arc exists to remove. The block's
own comment states that fact, so the next reader of the §III.3 table does not
have to infer it.

---

## Placement, scope and append-only

- `# Block 24: Oracle blocks for the remaining replicate types` sits at line 803.
  Under it: JKn at 806, bootstrap at 886, `other` at 967. Third, after JKn and
  bootstrap, with Fay left for PR 8 — the order `spec.md` §II fixes.
- No `# Block N:` header is added or renumbered; the last four are 16, 22, 23, 24.
- `git diff --name-only f127082 HEAD` lists one path,
  `tests/testthat/test-variance-replicate.R`. `git diff --stat` reads
  `1 file changed, 59 insertions(+)`.
- The diff is a single hunk, `@@ -963,3 +963,62 @@`, at the end of the file. Zero
  deletions, so every line before it — the two pinned blocks and all 24 earlier
  blocks — is byte-identical to `f127082`.
- `test_invariants(` appears once in code, at line 31, inside the first BRR
  block. The new block does not repeat it, per the one-per-constructor-per-file
  rule.

The plan's "Files touched" for PR 7 names that one file. Write surface matches:
no extra file, no missing file.

---

## Tolerance integrity

Read out of the delivered block and compared against `test-spec.md` §8:

| Quantity | Delivered | §8 requires |
|---|---|---|
| Point estimate | `1e-10` | `1e-10` |
| Standard error | `1e-8` | `1e-8` |
| `ci_low`, `ci_high` | `1e-6` each | `1e-6` |
| `survey`'s stored scale | `1e-8` | `1e-8` — the standard-error and variance row |

No tolerance is looser than specified and none is omitted. Zero deletions in the
diff means no pre-existing tolerance anywhere in the file could have been
widened, and I confirmed the single-hunk shape above. §8 allows no deviation and
none was taken.

---

## Profile gates

`audit.md` left this table pending, because the tester was barred from starting
an R process while the leader's gate pass held the tree. The gate evidence
exists and is tied to the reviewed tree, so every gate has a result. Source:
`logs/pr7/runner.log`, which ends `ALL GATES PASS` and records
`Tree: 11b2f6b7485aa15ea5945d219918b3fc69fbe5d9` — the audit's tree and `HEAD`'s
tree.

| Gate | Result | Notes |
|---|---|---|
| `devtools::document()` | PASS | wrote nothing; no roxygen in the write surface |
| `devtools::test()` | PASS | `FAIL 0 | WARN 256 | SKIP 4 | PASS 12003` |
| `run_examples()` | PASS | all examples ran |
| `R CMD build` | PASS | tarball produced |
| `R CMD check --as-cran` | PASS | 2 NOTEs |
| pkgdown | SKIPPED — scope | allowed |
| covr | 96.15% | flat |
| CRAN cookbook scan | PASS | none |
| `air format --check` | PASS | exit 0 |

- **Warnings.** 256 against the base's 256. Read as "no new warning", per
  decision D12 of the `svydesign-replicate-bridge` arc: clean `develop` already
  carries 256 AAPOR small-cell warnings.
- **Passes.** 11996 → 12003, `+7`. That is exactly the number of `expect_*`
  calls my parse finds in the new block: one `expect_length`, one
  `expect_match`, five `expect_equal`. `audit.md`'s Before/After table predicted
  "9 expectations"; the prediction was wrong and the delivered count is right.
  Nothing follows from it — it is an estimate in a pending column, not a
  measurement.
- **The two NOTEs are byte-identical to the baseline's two.** I compared
  `logs/pr7/gate-5-check.log` against `logs/baseline/gate-5-check.log`:
  `checking CRAN incoming feasibility` (pre-approved) and
  `checking for hidden files and directories` naming `.git` (the known worktree
  artifact, recorded in `archive/as-svydesign-bridge/`). No new NOTE pattern, so
  no escalation.
- **The pkgdown skip is allowed and documented.** The write surface touches no
  file under `R/`, no vignette, no `README`, no `_pkgdown.yml` and no
  `DESCRIPTION`. `NAMESPACE` is not in the diff, so the hard no-skip rule for
  export changes is not triggered.
- **Coverage.** 96.15%, above the 95% floor and flat against the base. The PR
  adds test code and no source line, so there is no new line to leave uncovered.

---

## Cross-consistency notes

`implementation.md` and `audit.md` agree everywhere I can cross-check them, and
both agree with my own measurements:

- the 13 stored-scale assertion lines and the 13 comment lines — identical lists
  in both artifacts and in my parse;
- the 3 warning-count triples at 122/131/132, 179/188/189, 998/1007/1008;
- the 6 `expect_failure()` sites and the two textual trap counts, 12-against-6
  and 15-against-13;
- the eight-by-three sensitivity table, cell for cell.

Two items recorded, neither a defect in this PR:

1. `audit.md`'s "9 expectations" prediction against the measured `+7`, above.
2. The comment's 97-character string against decisions S4 and S5's "99
   characters", which is the line width. Substance unchanged.

Four items are out of this PR's scope and I did not judge them: the Fay block
(PR 8), PR 9's sanctioned-exceptions subsection, the untoleranced
`sc@variables$scale` at line 174 (N2), and the two oldest BRR blocks passing
`mse` to one side only (N1).

---

## Decision

PASS. The delivered `other` block satisfies every item of `spec.md` §V.8 and
§IV.3 and every assertion `test-spec.md` rows 3.1.8 and 3.2 require, at the
tolerances §8 fixes and with no deviation. Rows 2.17 and 2.18 pass on my own
parse of the delivered file, 3 of 3 and 13 of 13. Rows 4.1, 4.2 and 4.3 pass on
my own re-run of the sensitivity probe, which reproduces the builder's table
digit for digit on all eight numerical types and leaves the working tree
unchanged. The write surface is one file, append-only, matching the plan. Every
profile gate has a result on the reviewed tree, coverage clears the floor, and
both `R CMD check` NOTEs are the baseline's own.
