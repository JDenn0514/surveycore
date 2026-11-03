# Request — as-svydesign-domain

## Intent
Apply a filtered design's domain restriction to the object `as_svydesign()`
returns. Today the converted object answers for the whole sample, so the point
estimate is wrong and not only the standard error. GitHub issue #245, labels
`arc:conversion`, `bug`, `tier:blocker`.

## Acceptance criteria
- A filtered Taylor design converts to an object whose `survey::svymean()`
  matches `get_means()` on the filtered design, to the SE tolerance in
  `.claude/rules/testing-surveycore.md`.
- The same holds for a filtered replicate design, a filtered twophase design,
  and both `survey_nonprob` shapes (replicate weights present, and absent).
- An unfiltered design converts unchanged and gains no subsetting.
- `as_tbl_svy()` inherits the fix.
- `from_svydesign(as_svydesign(d))` keeps working for a filtered design and for
  an unfiltered one. The round trip reads the converted object's stored call.
- The roxygen section `@section A filtered design's domain:` describes the new
  behaviour. It currently documents the bug as intended.

## Attachments
- GitHub issue #245 (full body quoted in `issue-245.md`)
- `findings-preflight.md` — three facts measured in the session before drafting

## Scope note from the user
Trimmed run. Deep Comprehension and the methods review are skipped: the issue
locks the decision and the change adds no statistical method. The spec review
runs as normal.

## Questions the issue leaves open
1. Whether the domain column is dropped from the converted object's variables
   once applied, so it cannot be mistaken for data.
2. Whether the reverse direction recovers a domain. The issue states it cannot:
   `survey` records a subset, not a domain marker.
