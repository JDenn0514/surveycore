**Does:** Makes `as_survey_replicate()` handle a supplied `scale`, `rscales` and `rho` the way `survey::svrepdesign()` does.
**When:** PR 5 of the replicate-scale arc (#257), after #243. It handles every argument, so it ships once every argument exists.
**Decision:** Locked, D4, D7 and D8 in `plans/issue-cleanup.md`.
**Write surface:** `R/core-constructors.R`, `R/methods-conversion.R`, `plans/error-messages.md`, `man/as_survey_replicate.Rd`, `tests/`

## Summary

`survey::svrepdesign()` ignores a supplied `scale` and `rscales` for five
replicate types and computes its own. `as_survey_replicate()` honours them
for all nine. So for those five types, the same explicit arguments produce
different standard errors in the two packages, and surveycore raises
nothing.

This is a separate defect from #242, #253 and #243. Those are about the value
surveycore picks when the caller supplies nothing. This one appears when the
caller does supply a value, and fixing every default still leaves it.

It also carries the surviving half of #244, closed into this issue: JKn with
no `rscales` must raise, and JK2 with no `rscales` must not.

## The five types

From `survey:::svrepdesign.default`:

| Type | What `survey` does with your `scale` | Warns? |
|---|---|---|
| `BRR` | discards it, uses `1/R` | yes — `type='BRR' does not use 'scale=' argument` |
| `Fay` | discards it, uses `1/(R*(1-rho)^2)` | no |
| `JK2` | discards it, uses `1`; also forces `rscales = rep(1, R)` | yes — `scale= and rscales= are not needed and will be ignored` |
| `ACS` | discards it, uses `4/R`; also forces `rscales = rep(1, R)` | yes — same wording |
| `successive-difference` | discards it, uses `4/R`; also forces `rscales` | yes — same wording |

## Measured

Both sides given `scale = 0.6`, `rscales = rep(1, 8)`, `mse = TRUE`, on the
same frame. `n = 60`, `R = 8`, seed 11, survey 4.5, R 4.6.1, Windows. Run on
this branch, so JK2's default is already `1`.

| Type | `survey` used | surveycore SE | `survey` SE | |
|---|--:|--:|--:|---|
| JK1 | 0.6 | 0.09633605611 | 0.09633605611 | agree |
| JKn | 0.6 | 0.09633605611 | 0.09633605611 | agree |
| bootstrap | 0.6 | 0.09633605611 | 0.09633605611 | agree |
| other | 0.6 | 0.09633605611 | 0.09633605611 | agree |
| JK2 | 1 | 0.09633605611 | 0.1243693137 | **differ** |
| BRR | 0.125 | 0.09633605611 | 0.04397119253 | **differ** |
| Fay | 0.25510204 | 0.09633605611 | 0.06281598933 | **differ** |
| ACS | 0.5 | 0.09633605611 | 0.08794238506 | **differ** |
| successive-difference | 0.5 | 0.09633605611 | 0.08794238506 | **differ** |

The four agreeing rows are the types `survey` honours. They agree to 1e-8
with no tolerance drama, which is the good news in this audit: **the
variance estimator is correct and type-agnostic.** surveycore returns the
identical SE for every type at a given scale, and so does `survey` wherever
it uses the scale it was handed. Every divergence found so far is in the
scale lookup, not in the formula.

## The decision: ignore and warn, matching `survey`

D7 settles it. Discard the argument, compute the type's own value, and raise a
typed warning naming what was discarded. This reproduces `survey` for every
input `survey` accepts, which is the rule for this constructor.

The full table, read from `survey:::svrepdesign.default` by `deparse()` line:

| Type | supplied `scale` | supplied `rscales` | supplied `rho` | line |
|---|---|---|---|--:|
| BRR | warn, discard | honoured | warn, discard | 79-84 |
| Fay | discard, **no warning** | honoured | used | 86-87 |
| JK2 | warn, discard | warn, discard | warn, discard | 118-121 |
| ACS | warn, discard | warn, discard | warn, discard | 75-77, 114-116 |
| successive-difference | warn, discard | warn, discard | warn, discard | 75-77, 114-116 |
| JK1 | honoured | honoured | warn, discard | 12-14, 96 |
| JKn | honoured | **required** | warn, discard | 12-14, 107-112 |
| bootstrap | honoured | honoured | — | 88-95 |
| other | honoured | honoured | warn, discard | 15-16, 123-128 |

Fay is the one type where surveycore discards a `scale` and raises nothing,
because `survey` raises nothing there.

### One deliberate divergence: silence when the caller supplied nothing

`survey`'s JK2 branch warns unconditionally. Line 118-119 sits outside any
`is.null()` test, so `svrepdesign(type = "JK2")` with no `scale` and no
`rscales` still warns that both "are not needed and will be ignored".

surveycore warns only when the caller actually supplied one of them (D8). A
warning that fires when the user passed nothing tells the user nothing, and
#167 is open because 256 unasserted warnings already mask new ones. State this
in `@param scale`.

### The JKn refusal, from #244

Per D4, `survey` refuses JKn with no `rscales` — line 112,
`stop("Must provide rscales for combined JKn weights")` — and guesses only
when `combined.weights = FALSE`, which is not surveycore's shape.
`as_survey_replicate()` raises
`surveycore_error_stratified_jk_rscales_unset`, the class
`as_survey_nonprob()` already uses.

**JK2 must not be refused.** `survey` accepts it and forces
`rscales = rep(1, R)`. So `.is_stratified_jk()`, which covers both types,
cannot be reused as it stands: either narrow it to JKn or add a JKn-only
predicate beside it. `as_survey_nonprob()` keeps refusing both, per D1, and
that divergence gets a sentence in its roxygen.

## The export route

`as_svydesign()` needs the second half of this PR. It passes
`x@variables$scale` into `svrepdesign()` at `R/methods-conversion.R:166`
for every type but BRR and Fay, and `survey` then discards it for JK2, ACS
and successive-difference. So the exported design silently stops
reproducing surveycore's own numbers for those three types whenever the
recorded scale is not the value `survey` would compute. After #242 the JK2
case is aligned by luck; ACS and successive-difference are aligned because
their defaults were corrected in #150. An explicit non-default scale breaks
all three.

Per D10: stop passing `scale` for the five types `survey` overrides. #243
handles Fay's `rho` on the same route as PR 4.

## New register rows

`plans/error-messages.md` needs a row per discarded argument, added before the
code, per `.claude/rules/code-style.md`. Name them in the PR; one warning
class covering "the type ignores this argument" with the argument name in the
bullet is enough, rather than one class per argument per type.

## Why no test caught it

No test passes an explicit `scale` to both packages for the same type and
compares. The suite's explicit-scale tests are surveycore-only and assert
the stored property, not agreement.

## Verification

- For each of the five types, an explicit `scale` is discarded and the type's
  own value stored. BRR, JK2, ACS and successive-difference raise a typed
  warning; Fay raises nothing.
- For JK2, ACS and successive-difference, an explicit `rscales` is discarded
  and `rep(1, R)` stored, with the same warning.
- No warning fires when the caller supplies neither, on any of the nine types.
- `as_survey_replicate(type = "JKn")` with no `rscales` raises
  `surveycore_error_stratified_jk_rscales_unset`.
- `as_survey_replicate(type = "JK2")` with no `rscales` still builds.
- A `rho` supplied for any type but Fay raises a typed warning and is
  discarded.
- For each of the four honoured types, a test passes the same explicit
  `scale` to both packages and asserts the SEs agree to 1e-8. Four of these
  are the measured rows above.
- `as_svydesign()` on a design with an explicit non-default scale reproduces
  surveycore's SE, for all nine types.

Found while auditing all nine rows of the `scale` switch for #242. The JKn
refusal was #244, closed into this issue.


