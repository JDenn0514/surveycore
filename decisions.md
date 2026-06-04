# decisions.md — glm-nonprob-replicate

## HOLD resolved: 2026-06-03

**Pipeline stage**: reviewer → shipper

**STOP condition (OVERRIDDEN by user)**: `covr::package_coverage()` = 93.06%, below the 95% absolute floor.

**User decision (2026-06-03)**: Override accepted. The coverage shortfall is pre-existing — before this PR coverage was 93.01%; this PR raised it to 93.06% (+0.05 pp). All code added by this PR is fully covered by the 11 new test blocks. The 95%+ target remains a separate cleanup task, not a blocker for this PR.

**Pipeline resumed** — proceeding to shipper.

---

# decisions.md — corr-nonprob-latent

## HOLD resolved: 2026-06-03

**Pipeline stage**: reviewer → shipper

**STOP condition 1 (resolved)**: incorrect `implementation.md` was supplied to reviewer (stale file from a previous PR). Fixed — correct file copied from worktree.

**STOP condition 2 (OVERRIDDEN by user)**: `covr::package_coverage()` = 93.0%, below the 95% absolute floor.

**User decision (2026-06-03)**: Override accepted. The coverage shortfall is pre-existing — before this PR coverage was 90.9%; this PR raised it to 93.0% (+2.1 pp). The code added by this PR is exercised by tests. The 95%+ target is tracked as a separate cleanup task, not a blocker for this PR.

**Pipeline resumed** — proceeding to shipper after reviewer re-run with correct implementation.md.

---

# decisions.md — calibrate-survey-taylor PR 1

## HOLD resolved: 2026-06-03

**Pipeline stage**: reviewer → shipper

**STOP condition (OVERRIDDEN by user)**: `covr::package_coverage()` = 93.13%, below the 95% absolute floor.

**User decision (2026-06-03)**: Override accepted. The coverage shortfall is pre-existing — before this PR coverage was 93.06%; this PR raised it to 93.13% (+0.07 pp). All code added by this PR (`R/calibration.R` and the `@calibration` property additions) is fully covered by the 39 new test assertions. The 95%+ target is tracked as a separate cleanup task, not a blocker for this PR.

**Pipeline resumed** — proceeding to shipper.
