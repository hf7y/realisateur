#!/usr/bin/env bash
# lib/registry-set.sh -- WHICH REPOS IS THIS ESTATE ANSWERABLE FOR? One home.
#
# The marker query was typed out FOUR times -- cut-verb-build.sh,
# registry-standup.sh, branch-protection-provision.sh and
# tests/registry-marker.test.sh -- which is the defect lib/roster-set.sh's own
# header names: "three chances to add a repo to two of them". Callers that need
# extra GraphQL fields splice them in rather than re-typing the query.
#
# TWO LISTS, AND THEY ARE NOT THE SAME LIST. The `.agent-project` registry names
# REPOS. hf7y/scheduler's schedule/ROSTER names PROJECTS, and a project is not
# its repo: `apms` is `apms-2173` (hf7y/realisateur#916). Unioning the two by
# name reports `apms` unenrolled while `apms-2173` sits in the registry. So the
# roster half is resolved through each schedule/<project>.conf's REPO_URL, which
# is the only place that mapping is written down.
#
# BLIND IS NOT EMPTY. Every function here returns 6 rather than printing nothing
# when it could not look. An empty registry tells a consumer to scan nothing,
# which reads as "everything is clean" -- the estate's signature defect.

[ -n "${REGISTRY_SET_LIB:-}" ] && return 0
REGISTRY_SET_LIB=1

. "${BASH_SOURCE[0]%/*}/estate-set.sh"
. "${BASH_SOURCE[0]%/*}/arming.sh"

REGISTRY_MARKER="${REGISTRY_MARKER:-.agent-project}"
REGISTRY_GH="${REGISTRY_GH:-${GH_BIN:-gh}}"
REGISTRY_SCHED_REPO="${REGISTRY_SCHED_REPO:-scheduler}"
# Resolved at CALL time, not source time: cut-verb-build.sh carries a
# VERB_BUILD_OWNER override and would otherwise silently query hf7y anyway.
registry_owner() { printf '%s' "${REGISTRY_OWNER:-$GH_ESTATE_OWNER}"; }

# The jq that drops archived and unmarked nodes. A caller adding fields to the
# query still filters with this, so "which repos count" has one definition.
REGISTRY_SELECT='.data.user.repositories.nodes[] | select(.marker != null and .isArchived == false)'

# registry_query [extra-node-fields] -- the marker query. Pass GraphQL field
# selections to splice into each node (registry-standup.sh wants workflow trees).
registry_query() {
  printf 'query($owner:String!){ user(login:$owner){ repositories(first:100, isFork:false, ownerAffiliations:OWNER){ nodes{ name isArchived isPrivate marker: object(expression:"HEAD:%s"){ __typename } %s } } } }' \
    "$REGISTRY_MARKER" "${1:-}"
}

# registry_repos -- marker-carrying, non-archived repo names, one per line.
registry_repos() {
  local out
  out="$("$REGISTRY_GH" api graphql -F owner="$(registry_owner)" -f query="$(registry_query)" \
           --jq "$REGISTRY_SELECT | .name" 2>/dev/null)" || return 6
  [ -n "$out" ] || return 6
  printf '%s\n' "$out" | sort -u
}

# roster_projects -- "<project>\t<repo>\t<state>", one per line, for every
# schedule/<project>.conf. ONE call: a per-conf fetch would race the same file
# against itself. `_`-prefixed confs are the rotation's own machinery, not
# projects, and are skipped exactly as enrole-selfdev.sh skips them.
roster_projects() {
  local q raw
  arming_load || return 6
  q='query($owner:String!,$repo:String!){ repository(owner:$owner,name:$repo){
       object(expression:"HEAD:schedule"){ ... on Tree { entries { name
         object { ... on Blob { text } } } } } } }'
  # REPO_URL is pulled out in jq: carrying a multi-line conf body through a
  # tab-separated record and re-splitting it downstream loses the very line
  # breaks the extraction depends on.
  raw="$("$REGISTRY_GH" api graphql -F owner="$(registry_owner)" -F repo="$REGISTRY_SCHED_REPO" -f query="$q" \
           --jq '.data.repository.object.entries[]?
                 | select(.name | endswith(".conf"))
                 | select(.name | startswith("_") | not)
                 | (.name | sub("\\.conf$"; "")) as $p
                 | ((.object.text // "") | [splits("\n")]
                    | map(select(startswith("REPO_URL="))) | last // "") as $u
                 | "\($p)\t\($u)"' 2>/dev/null)" || return 6
  [ -n "$raw" ] || return 6
  printf '%s\n' "$raw" | while IFS=$'\t' read -r p u; do
    [ -n "$p" ] || continue
    u="${u#REPO_URL=}"; u="${u%\"}"; u="${u#\"}"; u="${u%.git}"; u="${u##*/}"
    [ -n "$u" ] || u="$p"    # no REPO_URL: the project name is the best claim we have
    printf '%s\t%s\t%s\n' "$p" "$u" "$(arming_state "$p")"
  done | sort -u
}

# frame_repos -- THE FRAME: every repo this estate is answerable for, whether it
# carries the marker or is merely rostered. hf7y/realisateur#800 step 1.
frame_repos() {
  local reg ros
  reg="$(registry_repos)" || return 6
  ros="$(roster_projects)" || return 6
  { printf '%s\n' "$reg"; printf '%s\n' "$ros" | cut -f2; } | grep . | sort -u
}

# frame_unenrolled -- rostered, dispatched to, and carrying no marker, so every
# marker-derived sweep is blind to it. `dcp-gate-site` is the live example.
frame_unenrolled() {
  local reg ros
  reg="$(registry_repos)" || return 6
  ros="$(roster_projects)" || return 6
  comm -13 <(printf '%s\n' "$reg") <(printf '%s\n' "$ros" | cut -f2 | sort -u)
}
