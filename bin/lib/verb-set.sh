#!/usr/bin/env bash
# verb-set.sh -- what verbs the ecosystem DECLARES, in one place.
#
# WHY THIS EXISTS
# ---------------
# Two callers need the same answer and were each answering it differently:
#
#   bin/install-verbs.sh   "is every declared verb actually on this host?"
#   bashify coin / emit    "is this verb name already taken?"
#
# The generator answered the second with `command -v <verb>` -- the HOST'S
# PATH. That is host state, and the declarations are repo state, so the two
# disagree whenever a verb is declared but not yet installed. On 2026-07-30
# the bashify pass installed nothing on PATH, so `command -v range` found
# nothing twice and `range` was assigned to BOTH bibliothecaire ("shelve,
# catalogue and retrieve the ecosystem's texts") and secretaire ("put the
# morning's accounts in the order a missed message costs most"). Only one can
# own the name; today secretaire's wins and bibliothecaire's verb is
# unreachable. The report for that pass says "all verbs confirmed unclaimed on
# PATH before assignment", which was true and still produced a collision --
# PATH was the wrong thing to confirm against.
#
# BUILD-DISCIPLINE's "config read from one source, not retyped per file"
# applies to a derivation as much as to a hostname, so the rule lives here and
# both callers source it.
#
# THE DECLARATION RULE
#   a project declares a verb  <=>  its `bashified` branch carries an
#   executable `bin/<name>` AND a matching `man/<name>.1`
#
# Read with `git ls-tree`, so a project needs no checkout of `bashified` for
# its verbs to count. That is what lets a bare host recover the surface: the
# declaration lives in the repository, not in ~/.local.
#
# The man-page half is the bashify contract's own shape -- every verb ships a
# page -- and it is what separates a verb from a program that merely lives in
# bin/. bibliothecaire's `bin/page92.py` is executable, has no page, and is
# correctly not a verb.
#
# USAGE
#   . "$(dirname "${BASH_SOURCE[0]}")/lib/verb-set.sh"
#   verb_set_declared                 # rows: <project>\t<verb>
#   verb_set_claimants <verb>         # projects declaring it, one per line
#
# Env: INSTALLE_PROJECTS (default ~/Documents/Projects) -- shares the name
# `installe` uses, so the checker, the generator and the installer cannot
# disagree about where projects live.

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

# verb_set_verbs_of <repo> <ref> -- the declared verbs of one project.
verb_set_verbs_of() {
  git -C "$1" ls-tree -r "$2" -- bin/ man/ 2>/dev/null | awk '
    $1 == "100755" && $2 == "blob" && $4 ~ /^bin\/[^\/]+$/ { n = substr($4, 5); exec_[n] = 1 }
    $4 ~ /^man\/[^\/]+\.1$/ { n = $4; sub(/^man\//, "", n); sub(/\.1$/, "", n); page[n] = 1 }
    END { for (n in exec_) if (n in page) print n }
  ' | sort
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
