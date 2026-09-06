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
# realisateur#1043: `verb_set_declared` used to answer "what does the estate
# declare" by scanning _verb_set_projects() (~/Documents/Projects) on
# whichever host ran it -- host state again, same shape of bug as the PATH
# one above. Measured on mandark: 6 of 12 declaring projects, only because the
# other 6 weren't cloned there, or their checkout had never fetched
# `bashified`. bin/cut-verb-build.sh already answers the identical question
# with no local checkout: `gh repo list`, `git ls-remote` for the branch sha,
# `gh api .../trees/<sha>` for the tree AT that sha. verb_set_declared now
# makes the same three calls, so the two halves of this system can no longer
# disagree about what's declared. verb_set_ref_of/verb_set_verbs_of/
# verb_set_worktree_of stay local-checkout-based on purpose -- see each
# function's own comment for why.

. "${BASH_SOURCE[0]%/*}/estate-set.sh"

# _verb_set_ref <dir> -- the bashified ref THIS checkout carries, if any.
# Local-checkout only: verb_set_ref_of/verb_set_verbs_of below use it to check
# a repo already in hand (propagation.test.sh, against this repo's own
# working copy) against its own bashified branch -- not the estate-wide
# question, which moved to the remote path (realisateur#1043).
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
# LOCAL-CHECKOUT ONLY (see the file header): a repo already in hand, read at a
# ref that is already in hand. propagation.test.sh uses this against this
# repo's OWN working copy, not against the estate.
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

# verb_set_ref_of <repo> -- print the bashified ref THIS checkout declares
# from. Local-checkout only, same reason as verb_set_verbs_of above.
verb_set_ref_of() { _verb_set_ref "$1"; }

# --- verb_set_declared: the estate-wide question, answered remotely --------
# realisateur#1043. _verb_set_owner reads GH_ESTATE_OWNER
# (bin/lib/estate-set.sh, #672/#673) rather than a second hardcoded "hf7y" --
# override with VERB_SET_OWNER, same shape as cut-verb-build.sh's
# VERB_BUILD_OWNER, so a test fixture can point this at a fake owner.
_verb_set_owner() { printf '%s' "${VERB_SET_OWNER:-$GH_ESTATE_OWNER}"; }

# verb_set_declared -- every declaration in the ecosystem, as <project>\t<verb>.
# Sorted, so callers get a stable order without re-sorting.
#
# BLIND, NOT EMPTY (same discipline as bin/cut-verb-build.sh, and the same
# convention lib/registry-set.sh already uses: every function here returns 6,
# never an empty success, when it could not look). A network hiccup or an
# unauthenticated `gh` must never read as "the estate declares nothing" --
# that is indistinguishable from a real empty estate to anything that reads
# stdout alone, so BOTH callers (bin/install-verbs.sh, bin/land-selfdev.sh via
# install-verbs.sh) must check the exit status, not just the output.
#
# Nothing is printed until every repo has been read: a `gh api .../trees`
# call late in the loop failing must not leave a caller holding a partial,
# already-emitted set it has no way to know is short.
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
    # rc read BEFORE the pipe: "no bashified branch" and "could not read this
    # repo" are both an empty sha and mean opposite things (same reasoning as
    # cut-verb-build.sh's own comment on this exact call).
    refs="$(GIT_TERMINAL_PROMPT=0 git ls-remote "https://github.com/$owner/$repo.git" refs/heads/bashified 2>/dev/null)"
    if [ $? -ne 0 ]; then
      echo "verb_set_declared: $repo: git ls-remote could not read it -- BLIND" >&2
      blind=$((blind + 1))
      continue
    fi
    sha="$(printf '%s\n' "$refs" | awk 'NR==1{print $1}')"
    [ -n "$sha" ] || continue   # no bashified branch: a normal answer, not blindness

    # VERBLESS IS NOT BLIND (cut-verb-build.sh, 2026-08-18): fetch the WHOLE
    # tree, judge the CALL by it, filter after.
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
# Empty output means unclaimed. This is the check `command -v` was standing in
# for, and unlike `command -v` it is true on a host where nothing is installed.
# Propagates verb_set_declared's BLIND (return 6) rather than reading it as
# "unclaimed" -- an unreadable estate is not evidence a name is free.
verb_set_claimants() {
  local want="$1" out rc=0
  out="$(verb_set_declared)" || rc=$?
  [ "$rc" -eq 0 ] || return "$rc"
  printf '%s\n' "$out" | awk -F'\t' -v w="$want" '$2 == w {print $1}'
}

# verb_set_worktree_of <repo> -- where bashified is checked out, if anywhere.
# The same lookup `installe` does, so the two agree on a verb's target.
# Local-checkout only, and deliberately so: this answers "where do I install
# INTO on this host", not "what does the estate declare" -- realisateur#1043
# only moved the latter.
verb_set_worktree_of() {
  git -C "$1" worktree list --porcelain 2>/dev/null \
    | awk '/^worktree /{w=$2} /^branch refs\/heads\/bashified$/{print w; exit}'
}
