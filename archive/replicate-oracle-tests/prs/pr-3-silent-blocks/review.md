# Review — PR 3 — silent-blocks

**Verdict**: PASS
**Date**: 2026-09-22
**Branch**: `test/replicate-oracle-silent-blocks`
**HEAD**: `dadfb2b64d111f0ba48509eeb7a32530898ca285`
**Base**: `e61518a42681f87d92f52b32ec527f10a9461877`
**Tree read**: `2ac094bf91835d3af71e31aab10bc28e19882c15` — matches the `Tree:`
line in `audit.md` and the `Tree:` line in `logs/pr3/runner.log`, so the audit,
the gates and this review all read one tree.

## Convergence checks

- Spec coverage: **yes**. Every item of `spec.md` §IV.1 to §IV.4, §V.1, §V.6 and
  §V.7 that governs this PR maps to a row in the audit's table or to one of the
  two implied checks the audit records.
- Test coverage of spec: **yes** for this PR's surface. Rows 2.13, 2.14, 2.19,
  2.24, 3.1.1, 3.1.6 and 3.1.7 carry the whole of §V.1, §V.6, §V.7 and §IV.4.
  One §IV.2 item has no row — see note N1; it is not a defect in this PR.
- Tolerance integrity: **yes**. Eight new assertions, all at `1e-8`. No existing
  tolerance was widened, moved or deleted.
- Scope discipline: **yes**. One file, the file the plan names.
- Regression safety: **yes**. Failures 0, warnings 256, skips 4, all flat
  against the baseline; passes 11941 to 11977.

## What I verified myself, and not from the artifacts

### The `svrepdesign()` recount — the builder is right, the dispatch was wrong

Counted on the base file `e61518a`, twelve textual hits:

```
31  67  107  128  150  220  268  290  374  411  448  485
```

Lines 128 and 268 are comment text. The other ten are calls, and each sits in a
different `test_that()` body. **Ten calls in ten blocks, one each.** There is no
eleventh call and no block that builds two `survey` designs. The builder's
`getParseData()` count stands; the dispatch's `grep -c` figure of 11 counted a
comment line. The claim "every design-building call is asserted" therefore rests
on a true count.

### The eight blocks are the right eight, and nothing else moved

The diff carries eight hunks. Their block titles and HEAD line numbers:

| Block | Section | Type |
|---|---|---|
| 12 `get_means() … BRR design` | §V.1 | BRR |
| 55 `get_totals() … BRR design` | §V.1 | BRR |
| 212 `get_means() replicate: mse=FALSE …` | §V.1 | BRR |
| 282 `get_means() BRR scale formula … n_rep != 4` | §V.1 | BRR |
| 376 `get_means() successive-difference …` | §V.7 | successive-difference |
| 418 `get_totals() successive-difference …` | §V.7 | successive-difference |
| 460 `get_means() ACS …` | §V.6 | ACS |
| 502 `get_totals() ACS …` | §V.6 | ACS |

Four BRR, two ACS, two successive-difference. No hunk lands between lines 96 and
211, so the JK1 and JK2 blocks are untouched.

**The JK1 and JK2 breach is whole, not half-fixed.** On HEAD the JK1 block still
reads `sv <- suppressWarnings(survey::svrepdesign(` at line 119 and
`scale = jk1_scale,` at line 123; the JK2 block still reads
`suppressWarnings(` at line 162. Both survive intact for PR 4 to rewrite whole.
Nothing PR 4 must remove has been partly removed here.

### The probe backs every stored-scale literal

Each figure checked against the block's own fixture arguments, read off HEAD,
and against the generator's rule at `tests/testthat/helper-test-data.R:514`,
`brr = n_psu %/% 2L`:

| Block | `n_psu` | R implied | Probe `sv$scale` | Literal asserted | Agrees |
|---|--:|--:|--:|---|---|
| 12 | 20 | 10 | 0.1 | `1 / length(repwt_cols)` | yes |
| 55 | 20 | 10 | 0.1 | `1 / length(repwt_cols)` | yes |
| 212 | **10** | **5** | 0.2 | `1 / length(repwt_cols)` | yes |
| 282 | 20 | 10 | 0.1 | `1 / n_rep` | yes |
| 376 | 20 | 10 | 0.4 | `4 / length(repwt_cols)` | yes |
| 418 | 20 | 10 | 0.4 | `4 / length(repwt_cols)` | yes |
| 460 | 20 | 10 | 0.4 | `4 / length(repwt_cols)` | yes |
| 502 | 20 | 10 | 0.4 | `4 / length(repwt_cols)` | yes |

**The `mse = FALSE` block really does have half the replicate columns.** It
builds `make_survey_data(n = 100, n_psu = 10, n_strata = 2, type = "brr",
seed = 22)`. The generator returns `n_psu %/% 2` columns in `brr` mode, so
R = 5 and `sv$scale` = 0.2 = 1/5. The builder did not mis-read it. The seeds in
the probe table — 7, 7, 22, 99, 300, 301, 302, 303 — match the eight blocks one
for one.

The `4 / R` figures agree with the per-type table in
`.claude/rules/testing-surveycore.md`, which records `4/R` as `survey`'s default
for ACS and for successive-difference on `survey` 4.5.

### The `mse = FALSE` block still passes `mse = FALSE` to both sides

Read at lines 212 to 251. The surveycore constructor carries `mse = FALSE` at
line 230. The `survey` call, inside the new `expect_no_warning()` wrapper,
carries `mse = FALSE` at line 237. The wrapper flipped neither. The only test of
the centred branch of the replicate variance expression is intact. This is the
check a green suite cannot make, because a flipped block also passes.

### Tolerance integrity — the 48 deletions

All 48 deleted lines are the eight `survey::svrepdesign()` call bodies, six
lines each, re-added at one more level of indent inside the wrapper:

```
 8  -  sv <- survey::svrepdesign(
 8  -    weights = d$wt,
 8  -    repweights = d[, repwt_cols],
 8  -    data = d
 7  -    mse = TRUE,
 4  -    type = "BRR",
 2  -    type = "successive-difference",
 2  -    type = "ACS",
 1  -    mse = FALSE,
```

No deleted line carries `tolerance`, an assertion or a comment. Every
pre-existing tolerance in the file survives at its old value: the point
estimates at `1e-10`, the standard errors at `1e-8`, the bounds at `1e-6`. The
eight new stored-scale assertions each carry `tolerance = 1e-8`, which is
`test-spec.md` §8's standard-error and variance row and what §3.2 assertion 5
requires. None uses `1e-10`. No tolerance was widened anywhere.

### The `test_invariants()` call

One hit in the file, at line 31. The block above it opens at line 12 with
`test_that("get_means() replicate SE matches survey::svymean() — BRR design"`,
and the next `test_that(` opens at line 55, so the call sits inside the block
`spec.md` §IV.4 names. The file exercises one constructor,
`as_survey_replicate()`, so one call is the whole of the once-per-constructor-
per-file rule in `.claude/rules/testing-surveycore.md`. The file called the
helper zero times before, so this closes a standing breach.

Counts that go with it: `expect_no_warning(` 8 hits, one per edited block;
`sv$scale` 9 hits, the eight new ones plus the pre-existing JK2 assertion at
line 169 that belongs to PR 4.

## Ruling on the 99-character stored-scale comment

**Ruling: the comment stands as delivered. This is not a defect in PR 3, and I
do not require a rewrite.**

The dispatch asked me to test the builder's premise — all three facts or 80
columns, pick one — before ruling on it. I tested it by measurement, not by
impression. The premise is close to true, and the dispatch's counter-example
buys its two characters with a concession.

Measured lengths, all including the two-space indent the block body forces:

| Phrasing | Chars | Carries all three facts? |
|---|--:|---|
| Delivered: `# Guards survey's default; a failure means survey changed, not surveycore; SE/variance row, 1e-8.` | 99 | yes, in plain prose |
| Dispatch draft: `# survey's default; red here = survey changed, not surveycore; SE row, 1e-8.` | 78 | fact 1 loses its verb; `=` stands in for prose |
| `# Guards survey's default. A failure means survey changed, not surveycore.` | 76 | facts 1 and 2 only |
| `# Pins survey's default; a failure means survey changed, not surveycore; 1e-8.` | 80 | fact 3 names the value, not the row |
| `# Pins survey's default; red means survey changed, not surveycore; SE row, 1e-8.` | 82 | yes |
| `# Pins survey's default; a failure means survey changed, not surveycore; SE row, 1e-8.` | 87 | yes |

The floor for all three facts in plain prose, with the canonical words —
a verb on fact 1, "changed, not surveycore" on fact 2, and "SE row" on fact 3 —
is **82 characters**. Every form at 80 or below drops one of four things: the
verb on fact 1, the word "changed", the words "SE row", or plain punctuation in
favour of `=`.

Three reasons the delivered comment stands.

1. **Fact 3 must name the row, not just the value.** `decisions.md` E7 raised
   row 2.18 from two elements to three on purpose, and the third is "it names
   the standard-error and variance tolerance row, so a later editor does not
   widen it". A form that says `1e-8` alone, or that reads
   `survey's default;` with no verb, invites a PR 7 dispute at row 2.18, which
   counts "13 of 13, each with all three elements". A dispute there costs more
   than eight lint breaches.
2. **`red here =` fails the house writing standard**, not the reader.
   `CLAUDE.md` asks for plain punctuation, active voice and explicit articles;
   an equals sign standing in for a verb is the compression that rule names. The
   reader would survive it. The style rule I would be enforcing and the style
   rule I would be breaking are the same rule.
3. **No authority governing this PR measures column width.** The planner chose
   `air format --check` as the formatting gate (row 2.14) and it passes at exit
   0, because `air` does not rewrap comments. `lintr` is in none of the seven
   profile gates and in no CI check. Under `signals.md` a reviewer BLOCK must be
   traceable to a builder or a planner gap; the only gap here is a missing
   planner row for column width, and re-specing the arc over a comment's width
   is out of proportion to the harm.

The harm, measured: the file goes from 11 over-80 lines to 19. Of the 11
pre-existing, seven are `test_that()` titles that cannot be wrapped and three
are comments. The eight added lines are one comment repeated. `.lintr` does set
`line_length_linter(80)` and excludes only `data-raw`, so `tests/` is in scope
and the breach is real — it is simply a breach no check in this pipeline reads,
against a content requirement that three artifacts do read.

**If the leader wants the 80-column rule honoured across the arc, the cheap
route is not a PR 3 BLOCK.** It is one amendment before PR 4, which is the next
PR that writes these comments, fixing one canonical text for all 13 blocks.
`# Pins survey's default; red means survey changed, not surveycore; SE row,
1e-8.` at 82 characters is the shortest plain-prose form that keeps every
element row 2.18 counts; nothing reaches 80 without a concession. That is the
leader's call to make and no part of this verdict.

## Note N1 — `mse` is implicit on the surveycore side of two BRR blocks

`spec.md` §IV.2 asks for `mse` "always, explicitly" on both sides. The blocks at
lines 12 and 55 pass `mse = TRUE` to `survey` and pass nothing to
`as_survey_replicate()`, whose formal default is `mse = TRUE`
(`R/core-constructors.R:734`). Both sides therefore run at `TRUE` today.

This is not a defect in PR 3, for three reasons. §V.1 governs these four blocks
and says "Change nothing else"; the plan's eight acceptance criteria say nothing
about it; and no test-spec row covers it. The risk §IV.2 guards against does not
bite here either — if surveycore's default ever moved, the block would turn red
on the standard error, which is the wanted behaviour, not a silent pass.

Forward: PRs 4, 5, 7 and 8 rewrite or write blocks whole, and each of those must
pass `mse` explicitly on both sides, because §V.1's "change nothing else" does
not shield them.

## Profile gates and the CRAN cookbook

Every gate has a result, read from `logs/pr3/runner.log` on tree
`2ac094b…`, the same tree this review reads:

| Gate | Result |
|---|---|
| `devtools::document()` | PASS — wrote nothing |
| `devtools::test()` | PASS — `FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11977` |
| `run_examples()` | PASS |
| `R CMD build` | PASS |
| `R CMD check --as-cran` | PASS — Status: 2 NOTEs |
| pkgdown | SKIPPED — scope |
| `covr` | PASS — 96.15% |

**The pkgdown skip is allowed.** The write surface is one test file. It touches
no file under `R/`, no vignette, no `README*`, no `_pkgdown.yml` and no
`DESCRIPTION`, and the `NAMESPACE` diff is empty, so the profile's hard rule on
export changes does not bite. The skip is logged with its reason, as the profile
requires.

**Neither NOTE is a new pattern.** `checking CRAN incoming feasibility` is
pre-approved. `checking for hidden files and directories` is not on the
pre-approved list, but `baseline.md` records it on the clean tree at `7800ea9`
with nothing applied, and `.Rbuildignore` and `.git` cause it. `signals.md`
reserves a STOP for a **new** NOTE pattern; this one is pre-existing, so no
escalation. Read gate 5 as "2 NOTEs, and these two".

**CRAN cookbook: None.** The audit's table reads "none" and the audit verdict is
PASS, so there is no tester-classification error to escalate. No file under `R/`
is in the write surface, so the scan had no target by the letter of the rule;
the tester ran it on the 90 added lines anyway and found nothing.

## Coverage

96.15%, flat to the hundredth against the baseline's 96.15%. Above the 95%
floor. This PR adds test code and no source line, so no new line can be
uncovered and the new-code clause cannot fire. Neither the HOLD band nor the
BLOCK floor is reached.

## Comprehension alignment

`comprehension.md` exists. The gotchas that reach this PR's surface are all
carried into the frozen artifacts:

- **G6**, the combined-weights heuristic — this PR's whole subject. `spec.md`
  §IV.3 requires the no-warning assertion for exactly this reason, and
  `test-spec.md` §3.1 rows 3.1.1, 3.1.6 and 3.1.7 record it.
- **G5**, the ACS `mse` message — `spec.md` §V.6 says keep passing `mse`
  explicitly on both ACS blocks, and the delivered blocks do.
- **G3**, the point estimate cannot detect a scale defect — `spec.md` §IV.3 and
  `test-spec.md` §3.2 both require all five assertions.
- **G1**, `survey` raises no typed condition — `spec.md` §IV.3 and §VI reconcile
  the missing `class =` against both rule files.

G2, G4, G4b, G7 to G13 belong to PRs 4 to 8. No gotcha reaching PR 3 is
unaddressed.

## The planned absences — confirmed, not defects

- PR 9's sanctioned-exceptions subsection is absent. Rows 6.10 and 6.15 are its.
- The JKn, bootstrap, `other` and Fay blocks do not exist. PRs 5, 6, 7, 8.
- Row 2.13's "exactly two files" is the arc's total across nine PRs. One file is
  correct here, and the audit reads the row per PR as "no third file appears".
- Rows 3.1.2 and 3.1.3 still fail on this tree. They are PR 4's, and the audit
  records the breach rather than counting it against this PR.

## Cross-consistency notes

`implementation.md` and `audit.md` agree on every checkable figure: eight blocks,
eight hunks, their line numbers, the eight assertion texts, the one
`test_invariants()` call, the `1e-8` tolerance, the one-file write surface, and
the 99-character comment. Both flag the same line-length question and neither
tries to settle it. The builder's probe table and the tester's line-by-line read
of the delivered file were made independently and do not disagree anywhere.

The one place they differ is framing, not fact: `implementation.md` presents the
line-length breach as forced, and the measurement above shows it is forced only
at the last two characters. That difference changed no delivered line and is
settled by the ruling above.

## Decision

PASS. All seven checks are clean: the eight edited blocks are the eight §V.1,
§V.6 and §V.7 name, the JK1 and JK2 breach is whole for PR 4, every stored-scale
literal matches a measured probe figure, the `mse = FALSE` block still passes
`mse = FALSE` to both sides, no tolerance was widened or omitted, the single
`test_invariants()` call closes a standing rule breach, the gates all pass on the
audited tree, and coverage is flat above the floor. The 99-character comment
breaches an encoded style rule that no authority governing this PR measures, and
no phrasing at 80 columns keeps every element row 2.18 counts; it is not grounds
to block this PR.
