# Request — domain-marker-logical

## Intent

Fix issue #262. Every grouped `get_*()` function reports the wrong group,
silently, when the domain marker column `SURVEYCORE_DOMAIN_COL` holds
integers rather than logicals. Eleven call sites index `design@data` with the
column directly, so `[` reads row positions in place of a mask.

The user asked to read issue #262 and apply the **error update** — the
2026-09-12 revision in the issue's §Decision history. That revision replaces
the first draft (coerce with `as.logical()` inside `.apply_domain()`) with a
Layer 1 S7 validator on `survey_base` that rejects a non-logical domain
column at the write. The coercion draft is superseded and must not be
specified.

## Acceptance criteria

- A new Layer 1 validator on `survey_base` rejects a domain marker column
  that is not logical, with the typed class
  `surveycore_error_domain_not_logical`.
- The abort lands on the line that writes the bad column, not at analysis
  time, on all four concrete design classes.
- `.apply_domain()` keeps one job: an `NA` marker resolves to `FALSE`.
- The `as.logical()` coercion at `R/methods-conversion.R:79` is removed;
  `grep -rn "as.logical(.*SURVEYCORE_DOMAIN_COL" R/` returns nothing.
- `plans/error-messages.md` carries the new row (number 102) before the code
  uses the class.
- Every grouped `get_*()` function returns the identical result on a design
  whose domain column holds an `NA` row and on the same design with that row
  `FALSE`.
- The printed `Domain: n of N` line agrees with the count the analysis
  functions use.
- `as_svydesign()` still restricts to the domain and still treats `NA` as
  outside it.
- A design with no domain column is unchanged.
- Three existing test blocks that write a non-logical domain column are
  updated: `test-analysis-quantiles.R:460`, `:849`, and
  `test-conversion.R:3357`.

## Attachments

- GitHub issue #262 (read 2026-09-12). No papers, no PDFs, no reference
  implementations.
- Issue #245 shipped; this work reverses one of its decisions (the
  conversion helper's coercion and the factor-marker test).
