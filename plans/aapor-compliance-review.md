# AAPOR Compliance Review — surveycore Phase 1

**Status:** Deferred — review after Phase 1 spec is finalized
**Created:** 2026-02-24
**Context:** Raised during Phase 1 spec-workflow Stage 3 issue resolution

---

## Background

During spec review, the question arose of whether surveycore's analysis
functions follow AAPOR (American Association for Public Opinion Research)
reporting standards. This document captures the gap analysis and options for
a future planning session.

---

## Relevant AAPOR Documents

- [AAPOR Best Practices for Survey and Public Opinion Research](https://www.aapor.org/Standards-Ethics/Best-Practices.aspx)
- [AAPOR Transparency Initiative Checklist](https://www.aapor.org/Transparency-Initiative/Transparency-Initiative.aspx)
- AAPOR Standard Definitions (primarily about response rates — less relevant
  for analysis functions)

**Suggested starting point for the review session:** fetch the Best Practices
and Transparency Initiative documents and assess surveycore against them
systematically.

---

## Current Compliance Gap Analysis (Phase 1 as specced)

| AAPOR Requirement | surveycore Phase 1 | Status |
|---|---|---|
| Unweighted n (sample basis) | `n` column on all functions | ✅ |
| Weighted n (population estimate) | `n_weighted` in `get_freqs()` only | ⚠️ Partial |
| Uncertainty measure (MOE or CI) | `variance` argument on all functions | ✅ |
| Clear base definition | `n` docs + `meta()$n_respondents` | ✅ |
| Design effect (DEFF) | Not in spec | ❌ Missing |
| Cell suppression for small n | Warning only, no suppression | ⚠️ Partial |

---

## Key Gaps in Detail

### 1. Design Effect (DEFF)

DEFF = Var(complex design) / Var(SRS equivalent). AAPOR recommends reporting
it so readers understand how much the sampling design inflates uncertainty
relative to a simple random sample. Many polling organizations report DEFF
alongside MOE.

**Formula:** `DEFF = se_complex² / se_srs²`

**Implementation options:**
- Add `"deff"` as a `variance` argument value (consistent with existing pattern)
- Always include in `meta(result)` for downstream consumers

**Effort:** Low — both SE values are already computed. The division is trivial.

### 2. `n_weighted` missing from 5 of 6 functions

AAPOR recommends reporting both weighted and unweighted n in published tables.
`get_freqs()` already has `n_weighted = FALSE` as an optional argument.
The other five functions expose raw count (`n`) but not weighted population
count.

**Options:**
- Add `n_weighted = FALSE` as a cross-cutting argument to all six functions
  (parallel to `get_freqs()`)
- Always include weighted n in `meta(result)` and document it there

### 3. Cell Suppression

AAPOR guidance (and many institutional standards) recommend suppressing
(replacing with `*` or `NA`) cells where unweighted n falls below a threshold.
Common thresholds: n < 5 (surveycore warning threshold), n < 30 (AAPOR
common guidance for public reporting), n < 50 (some federal agencies).

**Current behavior:** `surveycore_warning_small_cell` fires at n < 5 but does
not suppress.

**Options:**
- Add `suppress_n = NULL` argument: cells with `n < suppress_n` are replaced
  with `NA` and flagged
- Add `min_n = 5` argument that controls the warning threshold AND optionally
  suppresses
- Leave suppression to downstream consumers (they can filter on `n`)

---

## Proposed `aapor_format` Argument (for discussion)

A convenience argument that enforces a specific combination of outputs aligned
with AAPOR public reporting conventions:

```r
get_means(design, x, aapor_format = FALSE)
```

When `aapor_format = TRUE`:
- Forces `variance = c("ci", "moe")`
- Forces `n_weighted = TRUE`
- Adds `deff` column
- Fires `surveycore_warning_small_cell` at `n < 30` instead of `n < 5`

This is a convenience wrapper — all the underlying arguments already exist
independently. `aapor_format = TRUE` just sets defaults that match AAPOR
convention.

**Risks:**
- AAPOR standards evolve; hardcoding them in an argument name creates
  maintenance burden
- Different AAPOR publication types have different requirements — one flag
  may not cover all cases
- Better to document which combination of arguments produces AAPOR-compliant
  output, rather than encoding it as a flag

---

## Recommended Questions for the Review Session

1. Fetch the current AAPOR Best Practices document and do a line-by-line
   assessment against the Phase 1 spec.
2. Should `n_weighted` be a cross-cutting argument on all six functions, or
   is `get_freqs()` the only function where weighted n is conventionally
   reported?
3. Should `"deff"` be a Phase 1 addition (as a `variance` value) or deferred
   to Phase 2?
4. Is a formal `aapor_format` argument worth the maintenance cost, or is
   clear documentation of which argument combination produces AAPOR-compliant
   output sufficient?
5. What cell suppression behavior (if any) should be built into Phase 1?

---

## Decision Made in This Session

- `n` = estimation-basis count (excludes zero-weight rows) — used for
  `surveycore_warning_small_cell`
- `meta(result)$n_respondents` = raw headcount including zero-weight rows —
  always populated, accessible via `meta()`
- All AAPOR compliance additions deferred to a dedicated review session after
  Phase 1 spec is finalized
