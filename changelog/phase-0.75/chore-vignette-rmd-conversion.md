# chore(vignette): convert vignette from Quarto (.qmd) to R Markdown (.Rmd)

**Date**: 2026-02-25
**Branch**: chore/vignette-rmd-conversion
**Phase**: Phase 0.75

## Changes

- Replace `vignettes/creating-survey-objects.qmd` with `vignettes/creating-survey-objects.Rmd`
  using standard `rmarkdown::html_vignette` output; preserves all content, structure, and
  bibliography unchanged
- Convert Quarto-specific YAML (`VignetteEngine{quarto::html}`, `format: html:`) to
  standard knitr/rmarkdown YAML (`VignetteEngine{knitr::rmarkdown}`, `output: rmarkdown::html_vignette`)
- Convert Quarto hash-pipe chunk options (`#| include: false`, `#| eval: !expr ...`) to
  standard knitr chunk header options (`include=FALSE`, `eval=requireNamespace(...)`)
- Replace Quarto cross-reference syntax (`@sec-calibrated`, `@sec-srs`) with standard
  pandoc anchor links (`[Section 6](#sec-calibrated)`, `[Section 5](#sec-srs)`)
- Update `DESCRIPTION`: `VignetteBuilder: quarto` → `VignetteBuilder: knitr`; remove
  `quarto` from Suggests; fix duplicate `survival` entry
- Update `R-CMD-check.yaml`: remove `quarto-dev/quarto-actions/setup@v2` step and
  `quarto-dev/quarto-r` extra-package; restore Windows to build vignettes normally
  (remove `--no-build-vignettes` / `--no-vignettes` flags)
- Update `.Rbuildignore` comment from "Quarto vignette build artifacts" to generic

## Files Modified

- `vignettes/creating-survey-objects.Rmd` — new file: full Rmd vignette (replaces .qmd)
- `vignettes/creating-survey-objects.qmd` — deleted
- `DESCRIPTION` — VignetteBuilder changed to knitr; quarto removed from Suggests; duplicate survival removed
- `.github/workflows/R-CMD-check.yaml` — Quarto CI setup removed; Windows vignette skip removed
- `.Rbuildignore` — comment updated
