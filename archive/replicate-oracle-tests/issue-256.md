# Issue #256 — verbatim, fetched 2026-09-16

Source: https://github.com/JDenn0514/surveycore/issues/256
Title: Replicate oracle tests feed surveycore its own scale, so they cannot detect a wrong default
State at fetch: OPEN

---

**Does:** Rewrites the nine replicate oracle tests so a wrong default fails.
**When:** PR 1 of the replicate-scale arc (#257). Ship before every value fix, so the rest land as red going green.
**Decision:** Locked, D2 and D7 to D9 in `plans/issue-cleanup.md`.
**Write surface:** `tests/testthat/test-variance-replicate.R`, `.claude/rules/testing-surveycore.md`

## Summary

The replicate oracle tests pass surveycore's own `scale` into
`survey::svrepdesign()` for exactly the types where `survey` would
otherwise use its own. surveycore's number is the input, so the comparison
is a round trip and cannot disagree. That is why #242 sat undetected from
the first commit of `as_survey_replicate()` through 22 tagged releases, and
why #253 and #243 are still open.

This issue is the methodology fix. #242, #243 and #253 are the individual
values.

## The mechanism

`survey::svrepdesign()` splits the nine types in two:

- **It overrides your scale** for `BRR`, `Fay`, `JK2`, `ACS` and
  `successive-difference`. A test that passes no `scale` compares the two
  defaults directly, so a wrong surveycore default fails on the spot.
- **It uses your scale** for `JK1`, `JKn`, `bootstrap` and `other`. A test
  that passes surveycore's default in gets it back out.

Every default corrected so far was in the first group, caught by exactly
this mechanism: `BRR = 1/4` in PR #14, `ACS = 1/R` and
`successive-difference = 2/R` in PR #150. Every default still wrong is in
the second group, or had no test at all.

`tests/testthat/test-variance-replicate.R:97` states the reason for the
round trip:

```r
# Compute scale explicitly to avoid survey package "guessing" warning.
n_rep <- length(repwt_cols)
jk1_scale <- (n_rep - 1L) / n_rep
```

Silencing the `guessing` warning is reasonable. Silencing it by feeding
surveycore's own answer back in is what removed the test's power. And the
warning never justified the round trip for the other three types in that
group: `JKn` refuses without `rscales` rather than guessing (line 112),
`bootstrap` neither warns nor refuses (lines 88-95), and `other` warns about
its own unset arguments rather than about a guess (lines 123-128). Only JK1
warns that it guessed a scale.

The conversion tests cannot substitute. `as_svydesign()` passes
`x@variables$scale` into `svrepdesign()` at `R/methods-conversion.R:166`
for every type but BRR and Fay, so every `as_svydesign()` numerical test is
a round trip by construction.

## Current coverage

Oracle blocks in `tests/testthat/test-variance-replicate.R` that build a
`survey::svrepdesign()`, before this issue:

| Type | Oracle blocks | Passes surveycore's scale in? | Can detect a wrong default? |
|---|--:|---|---|
| BRR | 4 | no | yes |
| ACS | 2 | no | yes |
| successive-difference | 2 | no | yes |
| JK1 | 1 | **yes** | no |
| JK2 | 0 | — | no — added by #242 |
| JKn | 0 | — | no |
| Fay | 0 | — | no |
| bootstrap | 0 | — | no |
| other | 0 | — | no |

`survey::svrepdesign(type = "bootstrap")` appears nowhere in
`tests/testthat/`.

## Proposed rule

Add to `.claude/rules/testing-surveycore.md`, and apply it to all nine
types:

> An oracle test against `survey` must not pass surveycore a value it
> derived from surveycore, and must not pass `survey` a value it derived
> from surveycore. Build both designs from the same columns with the same
> `mse`, supply `scale` to neither, and supply `rscales` only where
> `survey` refuses without it — with a literal, not a value read off the
> surveycore design. Assert the SE, not just the point estimate: the point
> estimate reads `pweights` and is invariant to every scale defect in this
> family.

Where `survey` warns that it is guessing, capture the warning by class and
let it stand. The warning is the test telling you `survey` computed the
value itself, which is the whole point of the comparison.

### Where `rscales` goes, per type

The rule's `rscales` clause said "only where `survey` refuses without it".
D4 narrows that to **JKn alone**, and D7 adds a second constraint the clause
missed: `survey` *discards* `rscales` for JK2, ACS and successive-difference
(lines 114-121), so a block that supplies it there provokes a warning instead
of a comparison.

| Type | Supply `rscales`? | Expect from `survey` |
|---|---|---|
| JKn | yes, a literal | nothing; it refuses without one (line 112) |
| JK2, ACS, successive-difference | no | it forces `rep(1, R)` |
| JK1, BRR, Fay, bootstrap, other | no | it defaults to `rep(1, R)` |

### Warnings each block must expect

Per D8 and D9, `survey` warns where surveycore deliberately does not. Assert
the warning; do not silence it.

| Type | `survey` warns | Line |
|---|---|--:|
| JK1 | yes, always — it has no default and says it guessed | 96-106 |
| JK2 | yes, always — even when nothing was supplied | 118-119 |
| other | yes, when `scale` or `rscales` is unset | 123-128 |
| ACS | a message, that it assumed `mse = TRUE` | 161-164 |
| the rest | no | — |

The JK1 warning is the one that matters. `survey` has no JK1 default: with
combined weights it guesses `(R-1)/R`, which is surveycore's documented
default, and warns that it guessed. So the two agree on the value and differ
on the warning, and the block must expect that (D9).

## Scope

One new or rewritten oracle block per type in
`tests/testthat/test-variance-replicate.R`, nine in total, each asserting
the point estimate, the SE and both CI bounds at the tolerances in
`.claude/rules/testing-surveycore.md`. The JK1 block at line 84 is
rewritten rather than added to. The JK2 blocks arrive with #242.

Four of the nine will fail on `develop` until #242, #253 and #243 land: JK2,
JKn, bootstrap and Fay. Landing this issue first is deliberate. It turns
three open bug reports into four failing tests, which is the state the
package's "tested against `survey`" claim should have been in all along.

Eight of the nine can be written now. Only **Fay** cannot: it needs the `rho`
argument #243 adds as PR 4, because `survey` refuses `type = "Fay"` without
one (lines 10-11). The bootstrap block is writable now — D5 settled it, so
the block asserts `1/(R-1)` and goes red until #253 lands.

## Verification

- Nine oracle blocks, one per type, none passing a scale to either side.
- Grep for `scale =` inside any `test_that()` block that calls
  `svrepdesign()` returns only blocks that pass the same literal to both
  sides, as #255 requires.
- Each block asserts the warnings in the table above, by class, rather than
  suppressing them.
- With #242, #253 and #243 resolved, all nine pass.

Found while fixing #242.


