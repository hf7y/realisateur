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
#
# realisateur#1043: verb_set_declared reads GitHub directly now, the same
# three calls bin/cut-verb-build.sh already makes, instead of scanning
# ~/Documents/Projects -- that was host state too, same bug as PATH above.
# verb_set_ref_of/verb_set_verbs_of/verb_set_worktree_of stay local-checkout
# based; they answer a different question (see each one's own comment).

. "${BASH_SOURCE[0]%/*}/estate-set.sh"

# _verb_set_ref <dir> -- the bashified ref THIS checkout carries, local only.
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
# man/<n>.1 optional (#891). Local checkout only (propagation.test.sh, against
# this repo's own working copy).
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

# verb_set_ref_of <repo> -- the bashified ref THIS checkout declares from.
verb_set_ref_of() { _verb_set_ref "$1"; }

_verb_set_owner() { printf '%s' "${VERB_SET_OWNER:-$GH_ESTATE_OWNER}"; }

# verb_set_declared -- every declaration in the ecosystem, as <project>\t<verb>,
# sorted. Every failure path returns 6 (lib/registry-set.sh's convention) with
# NOTHING on stdout, never an empty success: BLIND must not read as "declares
# nothing" to a caller that checks output but not the exit status.
verb_set_declared() {
  local owner repos repo refs sha whole tmp rows blind=0

  owner="$(_verb_set_owner)"

  command -v gh >/dev/null 2>&1 || {
    echo "verb_set_declared: gh is not on PATH -- BLIND, not empty." >&2
    return 6
  }
  gh auth status >/dev/null 2>&1 || {
    echo "verb_set_declared: gh is not authenticated -- BLIND, not empty." >&2
    return 6
  }

  repos="$(gh repo list "$owner" --limit 200 --no-archived --json name -q '.[].name' 2>/dev/null)" || {
    echo "verb_set_declared: cannot list $owner's repositories -- BLIND, not empty." >&2
    return 6
  }
  [ -n "$repos" ] || {
    echo "verb_set_declared: $owner has no readable repositories -- BLIND, not empty." >&2
    return 6
  }

  tmp="$(mktemp -d)" || {
    echo "verb_set_declared: cannot mktemp -- refusing to run blind." >&2
    return 6
  }
  rows="$tmp/rows"; : > "$rows"

  for repo in $repos; do
    refs="$(GIT_TERMINAL_PROMPT=0 git ls-remote "https://github.com/$owner/$repo.git" refs/heads/bashified 2>/dev/null)"
    if [ $? -ne 0 ]; then
      echo "verb_set_declared: $repo: git ls-remote could not read it -- BLIND" >&2
      blind=$((blind + 1))
      continue
    fi
    sha="$(printf '%s\n' "$refs" | awk 'NR==1{print $1}')"
    [ -n "$sha" ] || continue   # no bashified branch -- normal, not blindness

    whole="$(gh api "repos/$owner/$repo/git/trees/$sha?recursive=1" -q '.tree[] | "\(.mode) \(.path)"' 2>/dev/null)"
    if [ -z "$whole" ]; then
      echo "verb_set_declared: $repo: bashified is $sha but its tree did not read -- BLIND" >&2
      blind=$((blind + 1))
      continue
    fi

    printf '%s\n' "$whole" | awk -v repo="$repo" '
      $1 == "100755" && $2 ~ /^bin\/[^\/]+$/ { print repo "\t" substr($2, 5) }
    ' | while IFS=$'\t' read -r project v; do
      [ -n "$v" ] || continue
      verb_set_is_exempt "$project" "$v" && continue
      printf '%s\t%s\n' "$project" "$v" >> "$rows"
    done
  done

  if [ "$blind" -gt 0 ]; then
    echo "verb_set_declared: $blind repositor$([ "$blind" -eq 1 ] && echo y || echo ies) did not read -- refusing to answer with a set that is short by an unknown amount." >&2
    rm -rf "$tmp"
    return 6
  fi

  sort "$rows"
  rm -rf "$tmp"
  return 0
}

# verb_set_claimants <verb> -- which projects already declare this name.
# Propagates BLIND (return 6) rather than reading it as "unclaimed".
verb_set_claimants() {
  local want="$1" out rc=0
  out="$(verb_set_declared)" || rc=$?
  [ "$rc" -eq 0 ] || return "$rc"
  printf '%s\n' "$out" | awk -F'\t' -v w="$want" '$2 == w {print $1}'
}

# verb_set_worktree_of <repo> -- where bashified is checked out, if anywhere.
# Local checkout only; answers "install INTO where on this host", not the
# estate-wide question above.
verb_set_worktree_of() {
  git -C "$1" worktree list --porcelain 2>/dev/null \
    | awk '/^worktree /{w=$2} /^branch refs\/heads\/bashified$/{print w; exit}'
}
