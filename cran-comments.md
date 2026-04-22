## R CMD check results

Local macOS (arm64, R 4.5 release): 0 errors | 0 warnings | 0 notes.

win-builder R-devel: 1 NOTE, containing only the standard "New submission"
flag and a possibly-misspelled-word flag on "surveyverse" in the Description
field. "surveyverse" is the ecosystem name for the family of packages this
package is the foundation of (https://github.com/JDenn0514/surveycore and
related repositories); it is spelled correctly.

## URL notes

`urlchecker::url_check()` reports one URL with a 403 response:

- `https://electionstudies.org` in `man/anes_2024.Rd`

This is the American National Election Studies homepage. The 403 is returned
for automated requests only — the site restricts bot/checker access. The URL
is correct and accessible to human users. This is the canonical citation URL
for the ANES data.

## Package size

Installed package size is approximately 6.4 MB (5.1 MB in the `data/`
subdirectory). The package includes several bundled survey teaching datasets
(ANES, NHANES, ACS PUMS, Pew Research) that are the primary examples for the
package functionality.

## Method references

There are no published references describing the methods in this package beyond
the standard survey sampling literature (e.g., Lohr 2022, "Sampling: Design and
Analysis"). The variance estimation code is vendored from the 'survey' package
(Thomas Lumley, GPL-2/GPL-3) with full attribution in `VENDORED.md`.

## New submission

This is a new submission.
