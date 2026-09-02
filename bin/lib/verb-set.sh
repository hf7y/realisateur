#!/usr/bin/env bash
# verb-set.sh -- what verbs the ecosystem DECLARES, in one place.
#
# TRAPS (the rest of this header is in the vault):
# The generator answered the second with `command -v <verb>` -- the HOST'S
# PATH. That is host state, and the declarations are repo state, so the two
# disagree whenever a verb is declared but not yet installed -- and a verb
# nobody installed can be assigned to two projects at once. Only one can own
# the name, and
# unreachable. The report for that pass says "all verbs confirmed unclaimed on
# PATH before assignment", which was true and still produced a collision --
# PATH was the wrong thing to confirm against.

_verb_set_projects() { printf '%s' "${INSTALLE_PROJECTS:-$HOME/Documents/Projects}"; }

# A project's bashified worktree (gardien-garde, scheduler-dose, *-verbs) is a
# LINKED worktree of the same repository. Scanning it as well as its main
# checkout would declare every verb twice, and the duplicate would then read as
# a collision with itself.
_verb_set_is_linked_worktree() {
  local d="$1" gd gc
  gd="$(git -C "$d" rev-parse --path-format=absolute --git-dir 2>/dev/null)" || return 1
  gc="$(git -C "$d" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 1
  [ "$gd" != "$gc" ]
}

_verb_set_ref() {
  local d="$1" c
  for c in bashified origin/bashified; do
    git -C "$d" rev-parse --verify -q "$c^{commit}" >/dev/null 2>&1 && { printf '%s' "$c"; return 0; }
  done
  return 1
}

# verb_set_is_exempt <project> <name> -- true if bin/lib/not-a-verb.tsv names it.
_verb_set_not_a_verb_file() { printf '%s' "${VERB_NOT_A_VERB_FILE:-$(dirname "${BASH_SOURCE[0]}")/not-a-verb.tsv}"; }
verb_set_is_exempt() {
  local f p="$1" n="$2"
  f="$(_verb_set_not_a_verb_file)"
  [ -f "$f" ] || return 1
  awk -F'\t' -v p="$p" -v n="$n" \
    '!/^[[:space:]]*#/ && $1 == p && $2 == n { found = 1; exit } END { exit !found }' "$f"
}

# verb_set_verbs_of <repo> <ref> -- an executable bin/<n> declares a verb,
# man/<n>.1 optional (#891), filtered through the same opt-out as every caller.
verb_set_verbs_of() {
  local repo="$1" ref="$2" project v
  project="$(basename "$repo")"
  git -C "$repo" ls-tree -r "$ref" -- bin/ 2>/dev/null | awk '
    $1 == "100755" && $2 == "blob" && $4 ~ /^bin\/[^\/]+$/ { print substr($4, 5) }
  ' | sort | while IFS= read -r v; do
    [ -n "$v" ] || continue
    verb_set_is_exempt "$project" "$v" && continue
    printf '%s\n' "$v"
  done
}

# verb_set_ref_of <repo> -- print the bashified ref this repo declares from.
verb_set_ref_of() { _verb_set_ref "$1"; }

# verb_set_declared -- every declaration in the ecosystem, as <project>\t<verb>.
# Sorted, so callers get a stable order without re-sorting.
verb_set_declared() {
  local root d project ref verbs v
  root="$(_verb_set_projects)"
  [ -d "$root" ] || return 0
  for d in "$root"/*/; do
    d="${d%/}"
    [ -d "$d" ] || continue
    git -C "$d" rev-parse --git-dir >/dev/null 2>&1 || continue
    _verb_set_is_linked_worktree "$d" && continue
    ref="$(_verb_set_ref "$d")" || continue
    project="$(basename "$d")"
    verbs="$(verb_set_verbs_of "$d" "$ref")"
    [ -n "$verbs" ] || continue
    while read -r v; do
      [ -n "$v" ] || continue
      printf '%s\t%s\n' "$project" "$v"
    done <<< "$verbs"
  done | sort
}

# verb_set_claimants <verb> -- which projects already declare this name.
# Empty output means unclaimed. This is the check `command -v` was standing in
# for, and unlike `command -v` it is true on a host where nothing is installed.
verb_set_claimants() {
  local want="$1"
  verb_set_declared | awk -F'\t' -v w="$want" '$2 == w {print $1}'
}

# verb_set_worktree_of <repo> -- where bashified is checked out, if anywhere.
# The same lookup `installe` does, so the two agree on a verb's target.
verb_set_worktree_of() {
  git -C "$1" worktree list --porcelain 2>/dev/null \
    | awk '/^worktree /{w=$2} /^branch refs\/heads\/bashified$/{print w; exit}'
}
