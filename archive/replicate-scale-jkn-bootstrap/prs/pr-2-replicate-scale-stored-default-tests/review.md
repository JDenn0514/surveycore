# Review — PR 2 — replicate-scale-stored-default-tests

**Verdict**: PASS
**Date**: 2026-09-29 12:40

Branch `fix/replicate-scale-stored-default-tests`, HEAD `3a79218`, tree
`b8b26aeadd67e49613d17933728dbe53adee093e`. Base `origin/develop` at
`d11d1f8`.

Rows in scope: `test-spec.md` §1 rows 1.1 to 1.5. No other row was judged.

This agent ran no gate. It read the two artifacts, the diff and the five
blocks, and it re-derived line numbers and counts with `git` and `sed`.

---

## Convergence checks

- Spec coverage: **yes**. Every spec item this PR owns has a row in the
  audit's Per-Test Result Table. E1 stored half → row 1.3; E2 → row 1.3;
  E3 → rows 1.1 and 1.3; E4 → row 1.4; E5 → row 1.5; E6 → row 1.2.
  Behaviour rules 1, 2, 3 and 4 → rows 1.4, 1.1, 1.3 and 1.2. Behaviour
  rule 6 → row 1.1's ratio clause. Quality gates 1, 2 and the stored half
  of gate 4 → rows 1.1 and 1.3. E7, behaviour rule 8 and the engine half of
  E1 belong to PR 3 and PR 4 and were not judged here.
- Test coverage of spec: **yes**. No spec contract item in PR 2's range
  lacks a test-spec scenario.
- Tolerance integrity: **yes**. See §Ruling 1.
- Scope discipline: **yes**. See §Ruling 6.
- Regression safety: **yes**. Pass count moves 12004 to 12028, and the five
  blocks carry exactly 24 expectations, counted from the source. Failures
  hold at 0, skips at 4, warnings at 256. No test outside the PR's scope
  changed state.
- Comprehension alignment: **yes**. G1 → row 1.5. G2 → row 1.2. G5 stored
  half → row 1.3. G6, G7 and G11 carry a rationale in `spec.md` §Edge cases
  and §Why `1` is right for JKn. G3, G4, G8, G9 and G10 belong to PR 1 and
  PR 4. Every assumption that reaches these five rows is in a spec contract
  or is deferred by name.

---

## Ruling 1 — the ten bare `expect_equal()` calls

**Not a Tolerance Integrity breach. Do not add `tolerance = 1e-8` in this
PR.** Three reasons, in order of weight.

**The file already states one bar, and it is the bare call.** Every
pre-existing stored-scale assertion in `tests/testthat/test-constructors.R`
is a bare `expect_equal()` — lines 594, 608, 626, 648, 691, 2186, 2239,
2624, 2639, 3277, 3290, 3303, 3317, 3329, 3342 and 3354. Line 691 is PR 1's
own retargeted block, shipped through this pipeline three days ago and
passed by PR 1's reviewer. Ten explicit tolerances in PR 2 alone would make
the file state two different bars for one quantity, in adjacent blocks. That
is the drift the arc's four errata are about, not a repair of it.

**The band is unreachable.** The stored scale is a deterministic ratio of
two integers, computed in IEEE double on both sides. The audit measured
every gap at exactly `0e+00`, so each row passes at `1e-8` and at
`tolerance = 0`. The gap a wrong default opens is `0.05` for JKn and
`0.0026` for the bootstrap — six to seven orders of magnitude above either
bar. Nothing can land between `1e-8` and `1.49e-8` relative except by
deliberate construction, so no detection power rides on the difference.

**The audit reported the spec's figure, not a looser one.** Step 2 compares
the tolerance the audit reports against the test-spec. The audit reports
`1e-8`, the test-spec says `1e-8`, and the measurement backs it. Nothing was
relaxed to make anything pass.

**The rule the builder applied, stated so later PRs can follow it.** Write
`tolerance =` where the row's own **assert** column names the number. Leave
the call bare where only the §1 preamble maps the quantity to a tolerance
row. Row 1.1's two ratio clauses name `1e-8` in the assert column, and the
block carries `tolerance = 1e-8` on both. The ten stored-scale calls take
their bar from the preamble, and they are bare. The file is consistent under
this rule, not inconsistent.

**Forward.** Rows 1.9, 3.1 and 3.2 each name a tolerance in their assert
column. PR 3 and PR 4 write those explicitly. If the house wants an explicit
tolerance on every stored-scale assertion, that is one cleanup across all
sixteen pre-existing sites plus the new ones, filed as its own issue. It is
not PR 2's to carry, and PR 5's reviewer should not reopen it.

## Ruling 2 — row 1.1 omits `rscales = rep(1, n_rep)`

**Acceptable. The row does not fix it.**

The argument appears in the row's **scenario** column and nowhere in its
**assert** column. `implementation-plan.md` PR 2 AC-1, which is the
builder's contract, does not name the argument at all. So the builder met
its criterion exactly.

The omission reaches no branch. Row 1.2 supplies a non-uniform vector of the
right length and row 1.5 supplies `NULL`; both store `scale = 1`. A uniform
vector sits between them and the constructor branches on neither uniformity
nor content — `.validate_rscales()` checks length, type, `NA` and sign only.
The audit built row 1.1's JKn design with the argument supplied and measured
the same stored value and the same silence.

Recorded as a planner-side mismatch between a scenario column and its
acceptance criterion. It is cosmetic and it costs nothing here.

## Ruling 3 — row 1.3 subselects generated columns

**It does not cross the `testing-standards.md` line. Acceptable.**

That rule forbids adding edge-case parameters to the shared generator. The
block adds none. It calls `make_survey_data()` with ordinary arguments and
narrows the selection with `all_of("repwt_1")` and
`all_of(c("repwt_1", "repwt_2"))`. The generator is untouched, which is the
whole of what the rule protects.

The block does depart from `test-spec.md` §Datasets, which assigns inline
frames to this boundary. The departure is inert. The stored default reads
`type` and the column count and reads nothing else, and `all_of()` is
strict, so a change to the generator's column names turns the block red
rather than moving the count in silence.

**One caution for PR 3.** The same shortcut is not available for rows 1.6
and 1.8. Those frames are under test through their content — an all-`NA`
outcome column, and a weight column that mixes zeros with positive values.
Neither can be reached by subselecting the generator's output. Build them
inline, as §Datasets requires.

## Ruling 4 — would the five blocks catch a wrong default?

**Yes, and P2's failure mode is structurally absent.**

No block here computes an estimate. Each one reads `@variables$scale` and
asserts it against a literal, or against a formula in an `n_rep` the block
recomputes from the frame's column names. `jkn_old` and `boot_old` are built
from `n_rep` inside the block and are never read off a design. Row 1.1 pins
`n_rep` to `20L` first, so a change to the generator turns that line red
before it can move the ratio.

`archive/replicate-oracle-tests/` P2 records that a block asserting only a
point estimate is worthless against a scale defect. These blocks assert the
scale itself, which is the quantity that moves.

The two mutation runs agree. The builder edited each switch line and ran the
file; this agent substituted the old value into each assertion by reading.
Both give disjoint red sets, JKn against bootstrap.

State the limit plainly: these five blocks prove the stored value only. They
make no claim that the value reaches the variance. Rows 2.1 and 2.2 carry
that claim and shipped in PR 1; row 2.3 carries the infinite case and
belongs to PR 4.

## Ruling 5 — scope discipline

`git diff --stat d11d1f8..HEAD` reports one file changed, 171 insertions, 0
deletions. `git diff --name-only d11d1f8..HEAD -- R/` is empty, and the same
command for `tests/testthat/_snaps/` is empty. One commit, `3a79218`, a
`test(constructors):` conventional commit. `test_invariants()` appears four
times at both `d11d1f8` and `HEAD`, at lines 22, 479, 1393 and 1754.

`implementation-plan.md` PR 2 §Files touched names
`tests/testthat/test-constructors.R` and nothing else. The write surface
matches it exactly. Nothing crept in.

---

## Cross-consistency notes

`implementation.md` and `audit.md` were written without sight of each other.
They agree on the write surface, the block span at lines 694 to 864, the
invariant count, the snapshot state, the reading of the formatting gate and
the absence of any signal. Two numbers differ, and both resolve.

**Mutation B: 8 red against 7.** The eighth is
`tests/testthat/test-constructors.R:691`, the pre-existing block PR 1
retargeted. `implementation.md`'s own table labels that line
"pre-existing". The audit's substitution was scoped to the five new blocks,
so it could not count it. The two agree once the scopes match: 7 new
bootstrap assertions plus 1 inherited. The audit judged the gap immaterial
without naming its cause; the cause is this line.

**`air` hunk count: 28 against 29.** Both agents place the first hunk at
line 1380 and put no hunk inside 694 to 864. The gate reading — the PR's own
lines are clean and the file-level failure is inherited — holds on either
count.

**Line numbers verified.** All fifteen test-file line numbers that
`implementation.md`'s two mutation tables cite are correct against the file:
727, 730, 733, 736, 767, 809 and 861 for mutation A; 691, 728, 731, 734,
741, 790, 800 and 801 for mutation B.

**One stale reference, carried forward for PR 3 and PR 4.** `spec.md` and
`implementation-plan.md` name the two switch lines as
`R/core-constructors.R:807` and `:813`. PR 1's roxygen expansion moved them.
They are now `:851` (`JKn = 1,`) and `:861`
(`bootstrap = 1 / (n_rep - 1L),`), verified here. `implementation.md` used
the current numbers. PR 3 and PR 4 must mutate 851 and 861, not 807 and 813.

**The covr "changed R/ files: 1" reading.** The audit calls it a stale local
`develop` ref artifact. Confirmed independently: the diff against `d11d1f8`
under `R/` is empty.

---

## Profile gates

Every gate carries a result. The one skip is allowed.

- pkgdown SKIPPED — scope. The write surface touches no `R/` file, no
  `vignettes/`, no `README`, no `_pkgdown.yml` and no `DESCRIPTION` field,
  so every condition in `r-package-profile.md` §pkgdown skip condition is
  met. The hard rule does not apply: the `NAMESPACE` diff is empty. The
  audit logged the skip in the required form.
- The two NOTEs are the pre-approved pair, unchanged from base.
- Coverage 96.15%, above the 95% floor, unchanged from base. It sits in the
  95 to 98 band and did not drop, so no HOLD is due. The PR adds no line
  under `R/`, so no new line can be uncovered.
- CRAN cookbook violations: None, and the audit verdict is PASS. Consistent.

---

## Decision

PASS. All five test-spec rows are covered, the write surface matches the
plan exactly, no tolerance was relaxed against the test-spec, no test
outside scope changed state, the cookbook scan is clean, and coverage holds
above the floor. The three items the tester referred up are each acceptable
as shipped, for the reasons in Rulings 1 to 3, and the two numeric
disagreements between `implementation.md` and `audit.md` both resolve to
agreement.
