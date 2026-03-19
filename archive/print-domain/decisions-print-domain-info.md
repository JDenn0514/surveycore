# Decisions Log — surveycore print-domain-info

This file records planning decisions made during print-domain-info.

---

## 2026-03-03 — Domain info line in print methods (spec resolution)

### Context

Working through the adversarial spec review for `spec-print-domain-info.md`.
The key open question was how `survey_twophase` should report domain membership,
since two-phase designs have two sample sizes and domain estimation operates at
Phase 2 level.

### Questions & Decisions

**Q: For `survey_twophase`, should the domain line use Phase 1 or Phase 2 counts?**
- Options considered:
  - **Phase 1 counts:** `Domain: X of Y Phase 1 rows` — shows how many Phase 1
    rows pass the filter, but this is NOT what gets analyzed. Also redundant with
    the "Phase 1 sample size: Y" line printed immediately above.
  - **Phase 2 counts (uniform `nrow(x@data)`):** `Domain: X of Y rows` — Y equals
    Phase 1 size, creating semantic ambiguity and numeric redundancy.
  - **Phase 2 counts (explicit):** `Domain: X of Z Phase 2 rows` — shows how many
    Phase 2 rows are in-domain, matching what `analysis-means-helpers.R` actually
    estimates (`dom_ph2 <- domain[subset]`).
- **Decision:** Phase 2 counts with explicit "Phase 2 rows" label.
- **Rationale:** Analysis and variance estimation in `.twophase_mean_cell()` restrict
  domain to Phase 2 rows (line 265: `dom_ph2 <- domain[subset]`). Showing Phase 2
  domain counts makes the print output consistent with what the analysis computes.
  Phase 1 counts would be misleading and redundant with the existing Phase 1 sample
  size line.

**Q: How should `.print_domain_info()` produce Phase 2 counts for twophase?**
- Options considered:
  - Pass pre-computed `n_domain`/`n_total`/`row_label` as arguments to the helper.
  - Branch internally on `S7::S7_inherits(x, survey_twophase)`.
- **Decision:** Branch internally. The call sites for all five design types remain
  identical (`.print_domain_info(x)`); the helper detects twophase and computes
  `ph2_mask <- x@data[[x@variables$subset]]` before computing counts.
- **Rationale:** Keeps all five call sites uniform. Matches the pattern where print
  method helpers already branch on design type internally.

### Outcome

`.print_domain_info(x)` uses `nrow(x@data)` / `row_label = "rows"` for four design
types, and Phase 2 subset counts / `row_label = "Phase 2 rows"` for `survey_twophase`.

---
