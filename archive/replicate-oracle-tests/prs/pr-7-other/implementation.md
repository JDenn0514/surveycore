# implementation.md — PR 7, `test/replicate-oracle-other`

**Branch:** `test/replicate-oracle-other`
**Base:** `f1270827867c7712ba14159aa5660158e43864ac` (`develop` with PRs 1–6 of the arc)
**Spec sections:** §V.8, §IV.1, §IV.2, §IV.3, §II

## Write surface

| File | Action |
|---|---|
| `tests/testthat/test-variance-replicate.R` | modified — one block added, 59 lines |

Nothing else. `git diff --name-only f127082` lists that one path.

Two scratch files lived outside the package, in the session scratchpad, and are
not in the repository: `probe-other.R` (task 1 and 2) and
`probe-sensitivity.R` (task 5).

## Step 0 — the base

`git rev-parse HEAD` read `d4d1db2fe2de42243213d30c5bb56639906494b4` on entry —
stale `main`, as the dispatch predicted and as all six earlier builders in this
arc saw. Reset to `f1270827867c7712ba14159aa5660158e43864ac` and verified.

The reset discarded nothing of this PR's work. One tracked file carried a local
modification, `.claude/settings.local.json` — a re-indent plus a hook path
pointing at a different machine's home directory. It was copied out before the
reset and copied back after, and it now matches `HEAD`, so `git status` reports
it clean. No `plans/` file was present in this worktree, so the dispatch's
working-tree note had nothing to protect here.

## Summary

- Added one oracle block for `type = "other"` under the existing
  `# Block 24:` header, third, immediately after the bootstrap block. No new
  header, no renumbering, no edit to the JKn or bootstrap blocks.
- The block is a plain oracle block. The two sides agree on this fixture, so it
  carries no `expect_failure()` wrapper anywhere.
- It supplies neither `scale` nor `rscales` to either side, asserts the warning
  by its message fragment **and by its count**, and asserts all four numerical
  quantities plus `survey`'s stored scale.
- Measured the scale sensitivity of all eight numerical types outside the
  package: doubling the stored scale leaves the point estimate bit-identical
  and multiplies the standard error by `sqrt(2)` on every one of the eight.
- Audited the file by parsing, not by `grep -c`: 13 stored-scale assertions, 13
  exact-match comments, 3 warning-count blocks.

## Task checklist

- [x] 1 — Probe `other` on the `jk1` fixture at seed 15, neither argument supplied
- [x] 2 — Probe the four-quantity agreement
- [x] 3 — Write the block after the bootstrap block, no wrapper
- [x] 4 — Single-file run, 0 failures
- [x] 5 — Eight-by-three sensitivity probe in a scratch script outside the package
- [x] 6 — Count the stored-scale assertions and comments by parsing
- [x] 7 — `air format --check` and `git diff --name-only f127082`
- [x] 8 — Ran no full suite, no `check()`, no `document()`, no `run_examples()`, no `pkgdown`, no `covr`

No HOLD raised.

## Task 1 and 2 — the `other` probe, full precision

Fixture: `make_survey_data(n = 200, n_psu = 20, n_strata = 4,
design = "replicate", type = "jk1", seed = 15)`. `R = 20` replicate columns,
read off the selected names.

`survey::svrepdesign(type = "other", mse = TRUE)` with **neither `scale` nor
`rscales`**:

| Reading | Value |
|---|---|
| Warning count | `1` |
| Warning message | `scale or rscales not specified, set to 1` |
| Fragment present (`fixed = TRUE`) | `TRUE` |
| `sv$scale` | `1` |
| `sv$rscales` | all `1` |
| `sv$type` | `other` |
| surveycore stored scale | `1` |

The four quantities, `get_means(sc, y1, variance = c("se", "ci"))` against
`survey::svymean(~y1, sv, na.rm = TRUE)`:

| Quantity | surveycore | `survey` | absolute difference | tolerance |
|---|---|---|---|---|
| mean | `50.4365426841603579` | `50.43654268416035791` | `0.0000000000000000e+00` | `1e-10` |
| se | `0.2464264459334238` | `0.24642644593339988` | `2.3925306180672123e-14` | `1e-8` |
| ci_low | `49.9535557252926381` | `49.95355572529268784` | `4.9737991503207013e-14` | `1e-6` |
| ci_high | `50.9195296430280777` | `50.91952964302802798` | `4.9737991503207013e-14` | `1e-6` |

`identical(sc_mean$mean, coef(sv_mean)[["y1"]])` is `TRUE` — the point estimate
agrees bit for bit, not merely inside `1e-10`. Every difference matches
`spec.md` §V.8 and the run's `measurements.md` §M8: about `2.4e-14` on the
standard error and about `5.0e-14` on each bound, each one five to eight orders
of magnitude inside its tolerance. Nothing departed, so nothing was adjusted.

**Why neither argument is supplied.** `survey` raises that same warning when a
`scale` *is* supplied for `type = "other"`, so supplying one silences nothing
and restores the round trip the arc exists to remove. Supplying `rscales`
alone likewise leaves the warning and still feeds `survey` a number this side
computed. The block's comment records this, because `spec.md` §III.3's `other`
row reads "honoured" next to four rows reading "warn, discard", which invites
the misreading that "honoured" means "silent". It does not.

## Task 5 — the eight-by-three sensitivity table

**This is a measurement deliverable, not a check on the block.** Each design is
built the way its own block builds it — BRR passes no `mse`, JKn passes
`rscales = rep(1, R)`, the other six pass `mse = TRUE`. The design's stored
scale is then overwritten with twice its value and the mean recomputed with its
standard error and both confidence bounds. Run in
`scratchpad/probe-sensitivity.R`, outside the package, against
`devtools::load_all()` on this worktree.

| Type | Fixture mode / seed | R | scale | doubled | Δ point estimate | Δ standard error | SE ratio | Δ ci_low | Δ ci_high |
|---|---|---|---|---|---|---|---|---|---|
| BRR | `brr` / 7 | 10 | `0.10` | `0.2` | `0` | `0.0254446923538510` | `1.41421356237309` | `-0.0498706806112494` | `0.0498706806112494` |
| JK1 | `jk1` / 15 | 20 | `0.95` | `1.9` | `0` | `0.0994886254915372` | `1.41421356237310` | `-0.1949941228348067` | `0.1949941228348067` |
| JK2 | `jk1` / 15 | 20 | `1.00` | `2.0` | `0` | `0.1020731760330244` | `1.41421356237310` | `-0.2000597488123432` | `0.2000597488123432` |
| JKn | `jkn` / 15 | 20 | `0.95` | `1.9` | `0` | `0.0994886254915372` | `1.41421356237310` | `-0.1949941228348067` | `0.1949941228348067` |
| bootstrap | `bootstrap` / 15 | 20 | `0.05` | `0.1` | `0` | `0.0228242560289145` | `1.41421356237310` | `-0.0447347197905898` | `0.0447347197905898` |
| ACS | `brr` / 302 | 10 | `0.40` | `0.8` | `0` | `0.0595955942558190` | `1.41421356237310` | `-0.1168052183786656` | `0.1168052183786656` |
| successive-difference | `brr` / 300 | 10 | `0.40` | `0.8` | `0` | `0.0972168655802922` | `1.41421356237309` | `-0.1905415552272416` | `0.1905415552272416` |
| `other` | `jk1` / 15 | 20 | `1.00` | `2.0` | `0` | `0.1020731760330244` | `1.41421356237310` | `-0.2000597488123432` | `0.2000597488123432` |

Aggregate checks:

| Check | Result |
|---|---|
| Every Δ point estimate exactly `0` | `TRUE` — and `identical(Δ, 0)` on all eight, not merely `abs(Δ) < 1e-10` |
| Every `abs(Δ se)` above `1e-8` | `TRUE`, smallest `0.0228242560289145` — about `2.3e6` times the tolerance |
| Every SE ratio equal to `sqrt(2)` | `TRUE` within `1e-12`; largest gap `2.22044604925031e-16`, one machine epsilon |
| Every `abs(Δ ci_low)` above `1e-6` | `TRUE`, smallest `0.0447347197905898` — about `4.5e4` times the tolerance |
| Every `abs(Δ ci_high)` above `1e-6` | `TRUE`, smallest `0.0447347197905898` |

**No type departed from the expected shape.** All eight behave identically in
kind: the point estimate is blind to the stored scale, and the standard error
and both bounds move by `sqrt(2)`, far outside every tolerance the file uses.
This is the evidence that the arc's stored-scale assertions are load-bearing —
a wrong scale is invisible to a point-estimate assertion and unmissable to a
standard-error or confidence-bound assertion, which is exactly why §IV.3 item 4
exists.

Two incidental readings, recorded because they could be misread as departures
and are not:

- `R` is `10` for BRR, ACS and successive-difference, and `20` for the rest.
  The generator returns `n_psu / 2` columns in its `brr` mode and `n_psu` in
  the others, and the ACS and successive-difference blocks build on a `brr`
  fixture. This is §IV.1.2's reason for never hard-coding the count.
- JK1 and JKn both store `0.95`, which is `(R-1)/R` at `R = 20`. For JKn that
  is the issue #253 defect the arc's pinned block already records. The
  sensitivity probe overwrites the stored scale whatever its value, so the
  defect does not disturb the measurement.

## Task 6 — the 13-of-13 audit

**Instrument: `utils::getParseData()` on `parse(keep.source = TRUE)`,
restricted to terminal tokens with `token != "COMMENT"`.** Counted by walking
the token stream for the sequence `SYMBOL "sv"`, `"$"`, `"scale"`, so a mention
of the construct inside a comment cannot be counted. The canonical comment is
counted separately by exact whole-line match, `grep -Fxc`, which is reliable
for a fixed string.

The textual trap the dispatch warns about, confirmed on the file as it now
stands:

| Construct | Textual `grep -c` | Real calls, by parse |
|---|---|---|
| `expect_failure` | 12 | 6 |
| `svrepdesign(` | 15 | 13 |

### Stored-scale assertions and their comments — 13 of 13

Every assertion of `survey`'s stored scale is `expect_equal(sv$scale, ...)`.
Each one is immediately preceded by the canonical comment, matched exactly.

| # | Comment line | Assertion line | Comment exact match |
|---|---|---|---|
| 1 | 43 | 44 | yes |
| 2 | 84 | 85 | yes |
| 3 | 138 | 139 | yes |
| 4 | 195 | 196 | yes |
| 5 | 269 | 270 | yes |
| 6 | 344 | 345 | yes |
| 7 | 433 | 434 | yes |
| 8 | 475 | 476 | yes |
| 9 | 517 | 518 | yes |
| 10 | 559 | 560 | yes |
| 11 | 854 | 855 | yes |
| 12 | 930 | 931 | yes |
| 13 | **1014** | **1015** | yes — the `other` block, added by this PR |

- `sv$scale` references in code: **13**, at lines 44, 85, 139, 196, 270, 345,
  434, 476, 518, 560, 855, 931, 1015.
- Exact-match canonical comment lines: **13**, at 43, 84, 138, 195, 269, 344,
  433, 475, 517, 559, 854, 930, 1014.
- Lines mentioning `Guards survey` at all: **13**. Near-misses: **none**. So no
  paraphrase, shortened or rewrapped copy exists anywhere in the file.
- `grep -Fxc` on the exact indented string: **12** on the base `f127082`,
  **13** after this block. The count moved by exactly one.

**All 13 comments carry all three required elements**, because all 13 are
character-for-character the same string:

    # Guards survey's default; a failure means survey changed, not surveycore; SE/variance row, 1e-8.

| Required element | Where it sits in the string |
|---|---|
| Guards `survey`'s own default | `Guards survey's default` |
| How to read a failure | `a failure means survey changed, not surveycore` |
| The named tolerance row | `SE/variance row, 1e-8` |

One note on the length. The comment measures **97** characters on its own and
**99** as a whole line with its two-space indent — the dispatch's "99
characters" is the line, not the string. Either way it exceeds the 80-column
limit deliberately, per decisions S4 and S5, and `air format --check` passes it
because `air` does not rewrap comments. It was not shortened or improved.

### Warning-count assertions — 3 of 3

Three blocks match a `survey` warning by message fragment, and all three also
assert the count. Counted by parse: `expect_length()` appears 3 times in code,
`expect_match()` 3 times, and they pair one to one.

| Block | `expect_length()` line | `expect_match()` line |
|---|---|---|
| `get_means() replicate SE matches survey::svymean() — JK1 design` | 131 | 132 |
| `get_means() replicate SE matches survey::svymean() — JK2 design` | 188 | 189 |
| `get_means() replicate SE matches survey::svymean() — other design` | **1007** | **1008** |

The new block follows the house pattern the JK1 and JK2 blocks set:
`testthat::capture_warnings()` round the `svrepdesign()` call,
`expect_length(x, 1L)` for the count, then
`expect_match(x, "...", fixed = TRUE)` for the fragment. A bare
`expect_warning()` would match the fragment without counting, and a fragment
match passes even when a second, unexpected warning fires alongside — including
the "Data do not look like combined weights" warning that means the fixture
moved.

### Not one of the 13

`sc@variables$scale` appears 3 times in code, at lines 174, 379 and 400. Those
assert **surveycore's** stored scale, not `survey`'s, so none of them is one of
the 13 and none carries the comment. Line 174 is the JK2 block's
`expect_equal(sc@variables$scale, 1)` with no explicit tolerance — finding N2,
deliberately left alone and untouched by this PR.

### Blocks not modified

The JKn and bootstrap blocks are byte-identical to `f127082`. The whole diff is
59 added lines at the end of the file and no deletion.

## Task 4 and 7 — runs

| Run | Command | Result |
|---|---|---|
| Single file | `NOT_CRAN=true Rscript -e 'testthat::test_local(filter = "variance-replicate")'` | `[ FAIL 0 | WARN 1 | SKIP 0 | PASS 164 ]` |
| Formatter | `air format --check tests/testthat/test-variance-replicate.R` | clean, exit `0`, no output |
| Diff | `git diff --name-only f127082` | `tests/testthat/test-variance-replicate.R` |

The one `WARN` is pre-existing and not from this block. It fires at
`test-variance-replicate.R:798`, inside the `get_corr()` block of Block 23, and
is the AAPOR small-cell warning from `R/analysis-corr.R:498` — one of the 256
such warnings clean `develop` already carries (decision D12 of the
`svydesign-replicate-bridge` arc).

Per task 8 I ran no full suite, no `devtools::check()`, no `document()`, no
`run_examples()`, no `pkgdown` and no `covr`. The leader runs those gates
detached.

## Line endings

The file is CRLF in the working tree, and the appended block was converted to
CRLF before appending, so `git diff` shows 59 insertions and 0 deletions rather
than rewriting the file. `.gitattributes` pins LF for `tests/testthat/_snaps/*.md`
only, which this PR does not touch.

## CRAN compliance

- [x] TRUE/FALSE used throughout — no `T`/`F`
- [x] `::` used for external calls — `testthat::capture_warnings()`,
      `survey::svrepdesign()`, `survey::svymean()`, `survey::SE()`
- [x] No bare `print()`/`cat()`
- [x] No randomness introduced — the fixture seed is a literal passed to the
      generator's own `seed =` argument
- [x] No `par()`, `options()` or `setwd()` touched, so no `on.exit()` needed
- [x] No file written, so no `tempdir()` cleanup needed
- [x] No parallelism, so the two-core cap is not reached
- [x] `devtools::document()` not run, and not required — no roxygen changed and
      the write surface holds no file under `R/`
- [x] `skip_if_not_installed("survey")` sits inside the block, per
      `.claude/rules/testing-standards.md`, not at file level

## Notes for tester

- The block's fixture is the `jk1` mode, not an `other` mode. The generator has
  none, so §V.8 builds `type = "other"` on the `jk1` replicate columns, the way
  the JK2 block does. The two blocks therefore share a fixture and report the
  same standard error, `0.2464264459334238`.
- The block reads no replicate count into a variable. §V.8's stored scale is
  the literal `1`, so `n_rep` would be assigned and never used. The JK2 block,
  whose stored scale is also `1`, omits it for the same reason.
- `air format --check` accepts the 99-character comment line. It does not
  rewrap comments, so the deliberate over-length line survives the formatter.
