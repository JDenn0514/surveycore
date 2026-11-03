# Resume note — paused 2026-09-22, mid PR 5 of 9

Written before the user took the machine offline. Nothing in this arc depends
on the network right now: **no branch for PR 5 has been pushed**, so there is
no half-open pull request and no interrupted merge.

## State in one line

Four PRs merged to `develop`. PR 5 is built, committed locally and unpushed;
its gate pass and its audit were in flight when the pause began.

## Merged so far

| PR | Branch | Merge sha | Rows | Diff |
|--:|---|---|--:|---|
| 1 | `docs/oracle-rule-core` | `70bfe54` | 12/12 | +81, docs |
| 2 | `docs/oracle-rule-evidence` | `e61518a` | 6/6 | +54, docs |
| 3 | `test/replicate-oracle-silent-blocks` | `bf47f79` | 7/7 | +90/−48 |
| 4 | `test/replicate-oracle-jk1-jk2` | `d0de848` | 10/10 | +48/−21 |

`origin/develop` is at `d0de848d506feb186636898fa7726efdc8337a22`.
Zero tester BLOCKs and zero reviewer BLOCKs across all four.
`R/` is byte-identical to the pre-arc baseline `7800ea9` — nothing under `R/`
has changed in the whole arc, including through PR 4's power proof.

## Where PR 5 stands

Branch `test/replicate-oracle-jkn`, commit `0e3127ea6b5ab5c184e6a42a4bfcf131f08f67d1`,
tree `ba47cff369806d0c550db3d9ecb8f05e7f3600c1`, parent `d0de848`.
`1 file changed, 84 insertions(+)` — `tests/testthat/test-variance-replicate.R`,
append-only. **Never pushed:** `git ls-remote --heads origin test/replicate-oracle-jkn`
returns 0 rows.

Done and on disk:

- `prs/pr-5-jkn/implementation.md` — copied out of the builder's worktree
  before it was removed. The worktree is gone and pruned.
- `prs/pr-5-jkn/audit.md` — **verdict PASS, 3 of 3 rows** (2.3, 2.4, 3.1.4),
  no BLOCKs, no HOLDs, `Tree: ba47cff369806d0c550db3d9ecb8f05e7f3600c1`. Its
  `## Profile gates` section still reads **pending**, because the gate pass had
  not finished when the session paused. That section is the only thing missing
  from it.

The tester's counting work is worth keeping. It wrote two `awk` instruments in
its scratchpad — one that strips R comments while respecting quoted strings,
one that additionally tracks paren depth per line — and used them instead of
`grep`. Measured on this branch: `expect_failure` reads 6 textually and **3**
in code; `svrepdesign(` reads 13 and **11**; `rscales` reads 12 and **10**. It
then used the depth instrument to prove the wrapper nesting: three
`expect_failure(` at depth 2, each holding exactly one `expect_equal(` at depth
3, with the point estimate, stored scale, design call and ratio assertion all
at depth 2 and therefore outside every wrapper. A resuming session should reach
for the same approach rather than trusting a textual count.

In flight when the pause began, local, not needing the network:

- The full gate pass, launched detached, logging to `logs/pr5/`. Last heartbeat
  reported 2 R processes and 2377 MB free, so it was alive and healthy.

## To resume

1. Check `logs/pr5/runner.log` for `ALL GATES PASS` or `GATE FAILURE`. If the
   log stops mid-gate, the run died — relaunch it with the detached shape:

   ```
   powershell -NoProfile -Command "Start-Process -FilePath cmd.exe -ArgumentList '/c bash .claude/scripts/run-gates.sh <logdir> --skip-pkgdown > <logdir>/runner.log 2>&1' -WorkingDirectory '<repo>' -WindowStyle Hidden"
   ```

   Never run a gate in the harness's own background task tree; the memory
   watchdog kills it. Foreground or detached only, and never two at once.
   Expect `FAIL 0`, warnings 256, skips 4, passes near 11989 (PR 4 left
   11982 and this block adds 7 expectations), coverage 96.15%, and 2 NOTEs —
   `CRAN incoming feasibility` and `hidden files and directories`, both
   pre-existing on the baseline. A third NOTE blocks.
2. Send the gate table to the PR 5 tester so it can replace the pending
   section, or paste it in directly if the agent is gone — the verdict and all
   three row results are already final and must not be re-litigated.
3. Dispatch the PR 5 reviewer, then the shipper. Rows 2.3, 2.4 and 3.1.4 are
   PR 5's; rows 2.9, 2.10, 2.11, 2.15, 2.16 and all of §3.6 belong to PR 6,
   because they read the JKn and bootstrap blocks together.
4. Then PRs 6 to 9, in order. PR 9 must ship last.

## Standing facts a resuming session needs

- **A builder worktree comes up on stale `main` at `d4d1db2`.** All five
  builders so far did. Every dispatch must state the base sha and require the
  builder to verify and `git reset --hard`.
- **A builder's `implementation.md` dies with its worktree.** Copy it out
  before `git worktree remove`.
- **Run every gate yourself, detached.** Tell testers and shippers to run
  none and hand them the results.
- **The shipper opens the PR and stops.** It cannot monitor CI —
  `ScheduleWakeup` is not in its toolset. The leader watches CI and messages
  it to merge.
- **Merge without `--delete-branch`.** In this worktree the combined command
  merges and then dies in local cleanup, leaving the remote branch alive while
  reporting failure. Delete the remote branch with `git push origin --delete`,
  and reach the new tip with `git checkout --detach origin/develop`.
- **Never count constructs in `test-variance-replicate.R` with `grep -c`.**
  The file discusses its own constructs in comments. `expect_failure` reads 6
  textually and 3 as calls; `svrepdesign` reads 12 textually and 10 as calls.
  This error has been made twice and corrected twice. Parse, or strip comments
  first.
- Decisions taken during the build are in `decisions.md`: S1 gate
  carry-forward on docs-only PRs, S2 the version bump deferred to PR 9, S3 the
  test-spec's fifth-column erratum, S4 the 99-character comment, P1 the power
  proof, F2 the `other` row's reading, N1 `mse` on both sides, N2 line 174's
  missing tolerance.

## Bookkeeping not yet committed

`plans/pr-budget-calibration.md` is modified with rows for #281 to #284, and
five `plans/` files are untracked. All six are deliberate and belong to the
archive commit at the end of the arc. Do not commit them into a PR branch.
