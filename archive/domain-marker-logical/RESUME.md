# Resume note — domain-marker-logical

**Archive note.** Citations of `plans/{spec,test-spec,decisions,
implementation-plan}-domain-marker-logical.md` below no longer resolve:
`archive-plans.md` step 3 moved those files into this directory at archive
time. They sit beside this file under the same basenames. The
`[no such file]` marker is the citation checker's vocabulary for a path that
no longer resolves, not a statement that anything was lost.

**Archive note.** `status.md` [not archived] is excluded from the archive by
`archive-plans.md` step 2, which skips it by name. It was not lost; it stays
in the gitignored run directory with the gate logs.

**Superseded 2026-09-14.** The plan reached PLAN_READY. This file previously
held a mid-review handoff; nothing in it is still pending.

The next step is `pipeline-ship`, starting at PR 1
(`fix/domain-marker-validator`). Read `status.md` [not archived] for the state trail and
`plans/implementation-plan-domain-marker-logical.md` [no such file] for the frozen plan.

One item travels into the build. PR 1 task 5 carries a HOLD: if one validator
body on `survey_base` does not deliver the abort on all four concrete design
classes, the builder stops and raises it. It does not copy the check into the
four subclass validators.
