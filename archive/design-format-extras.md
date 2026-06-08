# Design: format-extras — Air Formatting for Roxygen and Markdown

**Date:** 2026-06-01
**Status:** Approved
**Scope:** Extend the pre-commit formatting workflow to cover roxygen2 `@examples` blocks in `.R` files and fenced ` ```r ``` ` blocks in plain `.md` files, using Air as the single formatter throughout.

---

## Problem

Air formats `.R`, `.Rmd`, and `.qmd` files but has two blind spots:

1. **Roxygen2 `@examples` blocks** — these live inside `#'` comments and are invisible to Air's R code formatter.
2. **Plain `.md` files** — Air does not process `.md` files at all. The `plans/` spec docs and `.claude/rules/*.md` files contain ` ```r ``` ` fenced blocks that accumulate style drift over time.

The result: production R code is always Air-formatted, but the code examples in spec docs and roxygen documentation are not, leading to inconsistency between spec examples and the code the builder/tester agents produce.

---

## Approach

Use Air for everything — including the two blind spots — via an extract → Air → splice pattern:

1. Extract embedded R code from the non-R context (strip the `#' ` prefix or fence delimiters)
2. Write the extracted code to a temp `.R` file
3. Run `air format <temp>`
4. If Air succeeds (exit 0): splice the formatted code back
5. If Air fails (exit 255, parse error): skip that block, emit a warning, continue

Air is already installed at `/opt/homebrew/bin/air` (v0.7.1) and is the documented project standard. This keeps Air as the single source of formatting truth — no style divergence, no custom transformer tuning.

---

## Files

Three new files in `tools/` at the project root:

```
tools/
  format-extras.R    — R script: roxygen @examples + .md chunk formatting
  pre-commit         — complete pre-commit hook (checked in, version-controlled)
  install-hooks.sh   — one-time setup: symlinks tools/pre-commit → .git/hooks/pre-commit
```

`tools/` is added to `.Rbuildignore`. It is not part of the R package.

---

## Extraction Algorithms

### Roxygen `@examples` in `.R` files

```
1. Read all lines from the file
2. Find lines matching: ^#' @examples\s*$
3. Collect the block: all subsequent #' lines until
   the next ^#' @\w line OR a non-#' line
4. Strip the leading "#' " (or bare "#'" with no space) from each line
5. Write stripped code to a temp .R file
6. Run: air format <temp>
7. If exit 0:
     - Read the formatted temp file
     - Re-prefix each line with "#' "
     - Splice back into the original lines
   If exit 255 (parse error):
     - Leave the block unchanged
     - Record the file + approximate line range in a warnings list
8. Repeat for all @examples blocks in the file
9. Write the file back only if at least one block changed
```

Edge cases handled: multiple `@examples` blocks per file, empty blocks (skipped), blocks containing only comments (Air leaves as-is).

### Fenced ` ```r ``` ` blocks in `.md` files

```
1. Read all lines from the file
2. Find open fences matching: ^\s*```r\s*$
   (captures both top-level and indented blocks)
3. Record the leading whitespace prefix from the open fence line
4. Find the matching close fence: next line matching ^\s*```\s*$
   (with the same or lesser indentation)
5. Extract lines between open and close (exclusive)
6. Strip the same leading whitespace prefix from each content line
7. Write stripped code to a temp .R file
8. Run: air format <temp>
9. If exit 0:
     - Read the formatted temp file
     - Re-add the whitespace prefix to each formatted line
     - Splice back between the (preserved) fence lines
   If exit 255:
     - Leave the block unchanged
     - Record in warnings list
10. Write the file back only if at least one block changed
```

**Indented blocks are included.** Blocks inside bullet points (e.g., `  ```r`) are handled by stripping and re-adding the leading whitespace. This covers spec code examples that live inline within list items.

---

## Pre-commit Hook

`tools/pre-commit` replaces the existing `.git/hooks/pre-commit`. It runs four passes over staged files only:

```bash
#!/usr/bin/env bash
set -uo pipefail
ROOT=$(git rev-parse --show-toplevel)

# Pass 1 — Air: format staged .R / .Rmd / .qmd files
AIRFILES=$(git diff --cached --name-only | grep -E '\.(R|Rmd|qmd)$' || true)
if [[ -n "$AIRFILES" ]]; then
  air format $AIRFILES
  git add $AIRFILES
fi

# Pass 2 — Extras: roxygen @examples + .md R chunks
EXTRAFILES=$(git diff --cached --name-only | grep -E '\.(R|md)$' || true)
if [[ -n "$EXTRAFILES" ]]; then
  Rscript "$ROOT/tools/format-extras.R" $EXTRAFILES
  git add $EXTRAFILES
fi

# Pass 3 — jarl: lint + auto-fix staged .R files (non-blocking)
if [[ -n "$AIRFILES" ]]; then
  jarl fix $AIRFILES --allow-dirty || true
  git add $AIRFILES
fi

# Pass 4 — README staleness check (existing logic, unchanged)
README=($(git diff --cached --name-only | grep -Ei '^README\.[R]?md$' || true))
if [[ ${#README[@]} -ge 1 ]]; then
  if [[ README.Rmd -nt README.md ]]; then
    echo "README.md is out of date; please re-knit README.Rmd"
    exit 1
  elif [[ ${#README[@]} -lt 2 ]]; then
    echo "README.Rmd and README.md should both be staged"
    exit 1
  fi
fi
```

**Re-staging after each pass** ensures the formatted version (not the pre-format version) is what gets committed.

**`set -uo pipefail`** (not `-e`) allows individual passes to fail softly — the hook continues rather than aborting on a non-fatal warning.

---

## Error Handling

Parse errors are **non-blocking**. When Air cannot parse a code block, `format-extras.R`:

- Leaves that block unchanged
- Continues processing all remaining blocks and files
- Exits with code 0 (so the hook does not abort the commit)
- Prints a summary at the end:

```
⚠  1 code block skipped (Air could not parse):
   plans/spec-nonprob-jackknife.md  lines 93–102

   The block was left unformatted. To inspect the parse error:
     air format --check <your-temp-file.R>
   To bypass the hook entirely next time:
     git commit --no-verify
```

This gives the user three implicit paths without requiring an interactive prompt (which breaks in non-TTY environments): ignore it (commit proceeds), fix it (message says where), or discuss it (they're in a Claude Code session already).

---

## Scope

| File pattern | Processed by |
|---|---|
| `R/*.R`, `*.Rmd`, `*.qmd` (staged) | Air (Pass 1) |
| `R/*.R` (staged) — roxygen `@examples` | format-extras.R (Pass 2) |
| `plans/*.md`, `CLAUDE.md`, `.claude/rules/*.md` (staged) | format-extras.R (Pass 2) |
| `R/*.R` (staged) — lint rules | jarl (Pass 3) |

`.md` files NOT in scope: `README.md` (auto-generated from `README.Rmd`), `NEWS.md`, `LICENSE.md`, `man/` files.

---

## Installation

```bash
# One-time setup (run after cloning)
bash tools/install-hooks.sh
```

`install-hooks.sh` creates a symlink: `.git/hooks/pre-commit → ../../tools/pre-commit`. Because it is a symlink, edits to `tools/pre-commit` take effect immediately without re-running the install script.

The existing `.git/hooks/pre-commit` (README staleness check) is subsumed into `tools/pre-commit` — no logic is lost.

---

## `.Rbuildignore` Addition

```
^tools$
^docs/superpowers$
```

---

## Idempotency

Running the hook twice produces identical output. Air and jarl are both idempotent. The splice logic only writes files back when content changed, avoiding spurious `git add` calls.
