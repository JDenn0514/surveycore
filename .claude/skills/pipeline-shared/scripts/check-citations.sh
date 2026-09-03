#!/usr/bin/env bash
# Report cited markdown documents that resolve to no file.
#
# Usage: check-citations.sh <archive-dir> <slug>
# Exit 0: every cited name resolves, or carries an exemption marker.
# Exit 1: at least one name resolves nowhere. Names and citation sites on stdout.
#
# Called by .claude/skills/pipeline-shared/references/archive-plans.md.

set -uo pipefail

dir=${1:?archive dir required}
slug=${2:?slug required}
root=$(git rev-parse --show-toplevel)

mapfile -t files < <(find "$dir" -name '*.md' -type f)
if [ ${#files[@]} -eq 0 ]; then
  echo "check-citations: no .md files in $dir"
  exit 0
fi

# Every path the repository keeps: tracked, plus untracked files that are not
# gitignored. Freshly copied archive files are in the second group, so the
# check sees them before the commit.
paths=$'\n'$(git -C "$root" ls-files --cached --others --exclude-standard)$'\n'
archived=$(printf '%s\n' "${files[@]}")

mapfile -t names < <(
  grep -ohE '`[^`]*[.]md`' "${files[@]}" | tr -d '`' | sort -u
)

unresolved=0
for name in "${names[@]}"; do
  # A backtick span is not always a filename. Skip a shell command, a glob,
  # and a path that points outside the repository.
  case $name in
    *' '* | *'*'* | ../*) continue ;;
  esac

  stem=${name%.md}

  # Resolve, in order: beside the archived docs; the slug-suffixed name the
  # freeze step produces; anywhere under the archive directory; an exact
  # repository path.
  [ -f "$dir/$name" ] && continue
  [ -f "$dir/$stem-$slug.md" ] && continue
  [[ $archived == *"/$name"* ]] && continue
  [[ $paths == *$'\n'"$name"$'\n'* ]] && continue

  # A trailing repository path resolves the name when it picks out one file:
  # `_snaps/utils.md` finds tests/testthat/_snaps/utils.md, and bare
  # `code-style.md` finds .claude/rules/code-style.md.
  #
  # Several matches mean the name is ambiguous, and a pipeline artifact name
  # is the case that matters: `implementation.md` names one file per feature,
  # so it has to be archived with this feature rather than matched against
  # another feature's copy. Ambiguous names resolve inside the archive
  # directory only, which the check above already tried.
  hits=$(printf '%s\n' "$paths" | grep -cF -- "/$name")
  [ "$hits" -eq 1 ] && continue

  # Exempt when every citation site carries a marker on its line. Two
  # markers, because a citation fails to resolve for two different reasons:
  #   `X.md` [not archived]  — the document existed and the pipeline lost it
  #   `X.md` [no such file]  — the document is cited to say it is absent
  mapfile -t sites < <(
    grep -nF -- "\`$name\`" "${files[@]}" |
      grep -vF '[not archived]' | grep -vF '[no such file]'
  )
  [ ${#sites[@]} -eq 0 ] && continue

  unresolved=$((unresolved + 1))
  echo "UNRESOLVED  $name"
  printf '    %s\n' "${sites[@]}"
done

if [ "$unresolved" -gt 0 ]; then
  echo
  echo "$unresolved cited document(s) resolve to no file."
  echo "Archive the document, or mark the citation. archive-plans.md §4."
  exit 1
fi

echo "check-citations: all cited documents resolve"
