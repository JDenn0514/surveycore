# Edge-case findings — as-svydesign-domain

Measured 2026-09-09, after `spec.md` and `test-spec.md` were drafted, on the
same branch and versions as `findings-preflight.md`. Continues its numbering.

Four of these contradict the drafted spec. They are not opinions about it.

## F8 — The two-phase route does not remove rows. It sets weights to infinity.

`[.twophase` takes two different paths. On a calibrated design, or with
`drop = FALSE`, it keeps every row and marks the excluded ones by setting their
probability to `Inf`:

```r
survey:::"[.twophase"
    if (is.logical(i)) {
        x$prob[!i] <- Inf
        x$phase2$prob[!i] <- Inf
    }
```

The measured fixture takes that path. On the filtered two-phase design, with 12
of 29 phase-2 rows marked:

| Quantity | After `sv[rs, ]` |
|---|--:|
| `phase1$sample` rows | 29 |
| `phase1$full` rows | 60 |
| `length(prob)` | 29 |
| rows with `prob == Inf` | 17 |
| `svymean(~y1, .)` | 58.06658 |

The estimate is correct — the same 58.06658 the preflight measured — and the
row count does not change. `subset()` behaves the same way here, 29 rows, so
this is a property of the two-phase design and not of the operator choice.

**What this contradicts.** `spec.md` §Scope says the two-phase route delivers
"The converted object carries only the rows the domain marks". It does not.
`test-spec.md` row B-3 asserts "The converted object's phase-1 sample carries
one row per marked phase-2 row". That assertion fails: 29 against 12.

**What the spec should say instead.** The two-phase route applies the domain by
zero-weighting, and the row count is unchanged. The observable contract is the
estimate, not the shape. B-3 has to assert the count of finite probabilities,
or the estimate, and not the row count.

## F9 — An empty domain does not give "0 with a standard error of 0" on two of three routes

Measured with an all-`FALSE` mask on each route:

| Route | rows after `[` | `svymean()` |
|---|--:|---|
| Taylor | 0 | 0, SE 0 |
| replicate | 0 | **errors**: `All replicates contained NAs` |
| two-phase | 29 (see F8) | **NaN** |

`as_svydesign()` itself still raises nothing on any of the three, so D5's
decision holds as a statement about the conversion. What fails is the claim
about what happens next.

**What this contradicts.** `spec.md` §Documentation contract point 6 states the
new roxygen will say "a filter matching no row returns a zero-row object and
raises nothing, and that `survey` then reports an estimate of 0 with a standard
error of 0". That is true only on the Taylor route. `test-spec.md` row D-2
asserts it as a test. On the replicate route the same row would have to expect
an error, and on the two-phase route `NaN`.

**What the spec should say instead.** The conversion is silent on every route.
What `survey` then reports depends on the route: 0 with a zero standard error
on the Taylor route, an error from `survey` on the replicate route, `NaN` on
the two-phase route. D-2 becomes three rows, one per route, or one row that
asserts only the silence of the conversion.

## F10 — A factor marker column builds a corrupt object rather than a restricted one

`spec.md` §Function contracts states that `r & !is.na(r)` "is the whole
coercion". Measured, on the 200-row Taylor fixture where 107 rows are marked:

| Marker column type | Rows after the mask | Condition raised |
|---|--:|---|
| logical | 107 | none |
| integer `0`/`1` | 107 | none |
| double `0`/`1` | 107 | none |
| character `"TRUE"`/`"FALSE"` | — | error: `operations are possible only for numeric, logical or complex types` |
| **factor** | **200** | warning: `'&' not meaningful for factors` |

The character row errors, which is safe. The factor row does not, and what it
produces is worse than a wrong row count.

`&` on a factor warns and returns all `NA`, so the mask is a length-200 logical
of `NA`. Indexing a `survey.design2` with that mask returns an object with all
200 rows and a probability vector that is neither finite nor infinite:

```
mask class: logical   all NA: TRUE   length: 200
rows after `[`: 200
prob entries finite: 0    infinite: 0
```

Estimating on it then fails inside `survey`, with an unclassed error thrown
three frames down:

```
Error in sum(sapply(stratvars, function(m) !any(is.na(m)))) :
  invalid 'type' (list) of argument
```

So the failure is loud, eventually, and it is unclassed and far from its cause.
It does not return a silently wrong number.

**What this contradicts.** The claim that the two-term expression is sufficient
coercion. It is sufficient for integer and double, which is what the spec
argued for, and it is not sufficient for factor, which the spec did not
consider.

**What the spec should say instead.** Coerce with `as.logical()` first, then
mask. Written out, the row mask becomes:

```r
r <- as.logical(frame[[SURVEYCORE_DOMAIN_COL]])
converted[r & !is.na(r), ]
```

Measured, `as.logical()` is correct on every type the column can hold, and it
needs no new error class:

| Column | `as.logical()` | mask after `& !is.na()` |
|---|---|---|
| logical | unchanged | unchanged |
| integer `0`/`1` | `FALSE`/`TRUE` | unchanged |
| double `0`/`1` | `FALSE`/`TRUE` | unchanged |
| character `"TRUE"`/`"FALSE"` | `TRUE`/`FALSE` | correct, and no error |
| factor with levels `FALSE`/`TRUE` | `TRUE`/`FALSE` | **correct**, where `&` alone gave a corrupt object |
| factor with other levels, say `yes`/`no` | `NA` | all `FALSE` — an empty domain, which is safe and inspectable |

The one-word addition removes the corrupt-object path and the character error
together. It costs no new class, so the spec's §Out holds unchanged.

## F11 — `[.twophase` can raise an untyped warning about single-PSU strata

The same branch of `[.twophase` shown in F8 continues:

```r
    index <- is.finite(x$prob)
    psu <- !duplicated(x$phase2$cluster[index, 1])
    tt <- table(x$phase2$strata[index, 1][psu])
    if (any(tt == 1)) {
        warning(sum(tt == 1), " strata have only one PSU in this subset.")
    }
```

So a domain that leaves one PSU in a stratum makes the conversion warn, with an
untyped `simpleWarning` from `survey`. The measured fixture did not trigger it,
and a narrower domain on a stratified two-phase design would.

**What this contradicts.** `spec.md` §Function contracts states of
`as_svydesign()`: "The restriction itself raises no condition on any route and
for any domain, including the empty one (D5)", and `test-spec.md` row G-1
asserts `expect_no_condition()`. Both are false for a two-phase design whose
domain thins a stratum to one PSU.

**What the spec should say instead.** Name the warning as a pre-existing
untyped condition from `survey`, the way the existing two-phase blocks in
`test-conversion.R` already do with `suppressWarnings()`. G-1 keeps
`expect_no_condition()` for the Taylor, replicate and non-probability routes
and must not claim it for the two-phase route.

## Not a finding: two edge cases the spec handles correctly

Measured and behaving as the spec says, recorded so the resolution does not
re-open them.

| Case | Measured |
|---|---|
| Domain leaves a single PSU, Taylor route | estimate 55.53378, SE 3.1e-15. No error, no warning |
| Domain leaves a single stratum, Taylor route | estimate 51.32337, SE 1.29482. No error, no warning |
| Replicate design restricted to 3 rows with 5 replicate columns | estimate 38.13608, SE 0.61512. No error |

## F12 — The empty-domain outcome of both non-probability shapes, measured

Measured 2026-09-09, after Stage 3r applied the review findings. Closes the one
GAP the resolver refused to assert without a measurement.

The Pass 1 review recommended writing "Taylor and both non-probability shapes
give 0 with a zero standard error". That grouping is wrong. The right grouping
is by the helper each shape routes into, which is what the resolver wrote and
what the measurement confirms.

| Shape | Converted class | Rows after an all-`FALSE` mask | `svymean()` |
|---|---|--:|---|
| non-probability, names replicate weights | `svyrep.design` | 0 | errors: `All replicates contained NAs` |
| non-probability, names none | `survey.design2` | 0 | 0, SE 0 |

So the five routes fall into three outcomes, and the split follows the
converted class rather than the input class:

| Outcome | Routes |
|---|---|
| 0, SE 0 | Taylor; non-probability naming no replicate weights |
| an error from `survey` at estimation | replicate; non-probability naming replicate weights |
| `NaN` | two-phase |

The conversion itself is silent on all five, which is what D5 and D7 decide.

## F13 — The two-phase round trip recovers the domain; the other routes do not

Measured 2026-09-09, closing the one place delta pass A declined to judge.

`from_svydesign()` dispatches on `twophase2` at `R/methods-conversion.R:614`, so
a two-phase design does make the round trip. Because that route removes no rows
(F8), the round trip behaves unlike the other four.

Measured on the filtered two-phase fixture, 12 of 29 phase-2 rows marked:

| Stage | Rows | Marker column |
|---|--:|---|
| after `as_svydesign()` and the restriction | 29 in the phase-1 sample | 12 `TRUE`, 17 `FALSE` |
| after `from_svydesign()` | 60 | 28 `TRUE` of 60 |

The rebuilt design prints:

```
Domain: 12 of 29 Phase 2 rows
```

So the two-phase round trip returns a design that still knows its domain, with
the marker intact at both levels, and 60 rows rather than 29. The 28 `TRUE` at
phase 1 is the original unrestricted marker, because
`.from_svydesign_twophase()` rebuilds from the phase-1 full frame, which the
restriction never touched.

**What this contradicts.** Four claims in `spec.md`, each true for the Taylor
and replicate routes and false for the two-phase one:

- the `from_svydesign()` contract bullet, "The all-`TRUE` marker column travels
  back into the rebuilt design's `@data`, where the domain reader sees it as
  all-`TRUE`";
- the same bullet's "The rebuilt design's print output therefore carries a
  `Domain: n of n rows` line";
- §Documentation contract item 8, "The rebuilt design's row count is its new
  total";
- item 8's "The original N is unrecoverable from the object".

On the two-phase route the original N *is* recoverable, the row count is not the
new total, and the print line names two different numbers.

**What the spec should say instead.** Scope all four to the routes that remove
rows, and state the two-phase behaviour beside them: the round trip recovers the
marker at both levels because the restriction removed nothing, so the rebuilt
design is a marked design over the full frame rather than an unmarked design
over the domain.

This is the fourth consequence of F8 to surface. The pattern is consistent:
every claim written from the Taylor route needs a two-phase qualifier.
