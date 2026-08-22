#!/usr/bin/env bash
# delivery-audit.sh -- did the merged PRs actually take effect outside the repo?
#
# RUNNER: operator -- needs a credential and ssh to the hosts a claim names;
#   read-only everywhere, so it is safe on a clock
# GUARD-TEST: bin/tests/delivery-audit.test.sh -- 33 cases
# GATE: none -- every path calls `gh` live; the fixture is in its suite
#
# TRAPS (the rest of this header is in the vault):
# MERGED IS NOT DELIVERED. Every artifact has a place it is WRITTEN and a place
# it takes EFFECT, and nothing guarded the transition -- #436 merged and the
# host deploy never ran. A DELIVERS block says where a PR lands; this goes and
# looks, and an unmet claim means the PR is NOT done.
#
# EXISTING IS NOT CURRENT. `path:` asks only whether something is there --
# #499. `matches:<deployed-path> home:<repo-path>` asks whether the DEPLOYED
# BYTES are the ones this PR merged, graded against the release channel's own
# cadence: a mismatch is UNMET only once a build has cut since the merge,
# PENDING before that (the adoption window ausculte's propagation probe
# already grants hosts, extended here to PRs).
#
# usage and exit codes: `--help`. One source.

set -uo pipefail

CLI_NAME='delivery-audit.sh'
CLI_SUMMARY='verify the DELIVERS claims of recently merged pull requests, live'
CLI_USAGE='  delivery-audit.sh                 audit the last 28 days of merged PRs
  delivery-audit.sh --days <n>      a different window
  delivery-audit.sh --repo <o/r>    default: the remote of this checkout
  delivery-audit.sh --pr <n>        just one pull request'
CLI_FLAGS='--days --repo --pr'
CLI_POSITIONAL=any
CLI_EXITS='  0  every claim of every audited PR is met
  1  at least one claim is UNMET -- the PR is not done, and the row says why
  2  usage error
  6  BLIND -- the tracker or the host could not be read. Never 0: a claim
     that could not be checked is not a claim that was met.'
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

DA_HOST_SSH="${DA_HOST_SSH:-ssh}"
DA_SUDO="${DA_SUDO:-sudo}"   # overridable: the sealed-path cases are hermetic
DA_GH="${DA_GH:-gh}"
DA_CURL="${DA_CURL:-curl}"
DA_VERBS_STATUS_URL="${DA_VERBS_STATUS_URL:-https://hf7y.com/verbs/status.json}"
DAYS=28; REPO=""; ONE_PR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --days) DAYS="${2:-}"; shift 2 ;;
    --repo) REPO="${2:-}"; shift 2 ;;
    --pr)   ONE_PR="${2:-}"; shift 2 ;;
    *) echo "$CLI_NAME: unexpected argument: $1" >&2; exit 2 ;;
  esac
done
case "$DAYS" in ''|*[!0-9]*) echo "$CLI_NAME: --days needs a number" >&2; exit 2 ;; esac

if [ -z "$REPO" ]; then
  REPO="$("$DA_GH" repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)"
  [ -n "$REPO" ] || { echo "$CLI_NAME: BLIND -- no --repo given and this checkout names none" >&2; exit 6; }
fi

if [ -n "$ONE_PR" ]; then
  BODIES="$("$DA_GH" api "repos/$REPO/pulls/$ONE_PR" --jq '"\(.number)\t\(.merged_at // "")\t\(.body // "" | @base64)"' 2>/dev/null)"
else
  SINCE="$(date -u -d "-$DAYS days" +%Y-%m-%d 2>/dev/null)"
  [ -n "$SINCE" ] || { echo "$CLI_NAME: BLIND -- cannot compute the window start" >&2; exit 6; }
  BODIES="$("$DA_GH" api --paginate -X GET "search/issues" -f per_page=100 -f q="repo:$REPO is:pr is:merged merged:>=$SINCE" \
            --jq '.items[] | "\(.number)\t\(.pull_request.merged_at // "")\t\(.body // "" | @base64)"' 2>/dev/null)"
fi
[ -n "$BODIES" ] || { echo "$CLI_NAME: BLIND -- $REPO returned no pull requests to audit" >&2; exit 6; }

echo "delivery-audit -- $REPO, ${ONE_PR:+PR $ONE_PR}${ONE_PR:+ }${ONE_PR:-last $DAYS days}"

met=0; unmet=0; pending=0; blind=0; audited=0; claimless=0

# The release channel's own verdict, fetched at most once and cached: a
# `matches:` claim needs to know whether a build has been CUT since the PR
# merged, not just what today's build looks like. Same source ausculte.sh's
# propagation probe reads, so the two cannot disagree about the cadence.
VERDICT_FETCHED=0
VERDICT_CUT_EPOCH=''
fetch_verdict() {
  [ "$VERDICT_FETCHED" = 1 ] && return 0
  VERDICT_FETCHED=1
  local v cut_at
  v="$("$DA_CURL" -s -m 15 "$DA_VERBS_STATUS_URL" 2>/dev/null)"
  cut_at="$(printf '%s' "$v" | jq -r '.last_cut.at // empty' 2>/dev/null)"
  [ -n "$cut_at" ] || return 1
  VERDICT_CUT_EPOCH="$(date -u -d "$cut_at" +%s 2>/dev/null)"
  [ -n "$VERDICT_CUT_EPOCH" ]
}

# Reads a file's bytes the same way the `path:` probe establishes presence --
# walking to the deepest VISIBLE ancestor so a sealed parent reads BLIND, not
# absent -- but returns the bytes on stdout when the file is there and
# readable. rc: 0 read, 1 absent, 9 blind (unreadable or behind a seal).
read_deployed() { # <host> <path>
  local where="$1" path="$2" rc
  local probe='p="$1"; if [ -e "$p" ]; then
      [ -r "$p" ] || exit 9
      cat -- "$p"; exit 0
    fi
    while [ ! -e "$p" ] && [ "$p" != / ]; do p="$(dirname "$p")"; done
    [ "$p" = "$1" ] && exit 0; [ -x "$p" ] || exit 9; exit 1'
  if [ "$where" = localhost ]; then
    bash -c "$probe" _ "$path"; rc=$?
    if [ "$rc" = 9 ] && "$DA_SUDO" -n true 2>/dev/null; then
      "$DA_SUDO" -n bash -c "$probe" _ "$path"; rc=$?
    fi
  else
    "$DA_HOST_SSH" -o BatchMode=yes "$where" "bash -s -- '$path'" <<<"$probe"; rc=$?
    if [ "$rc" = 9 ]; then
      local out
      out="$("$DA_HOST_SSH" -o BatchMode=yes "$where" \
        "sudo -n true 2>/dev/null && sudo -n bash -s -- '$path'" <<<"$probe")"; local src=$?
      "$DA_HOST_SSH" -o BatchMode=yes "$where" 'sudo -n true' >/dev/null 2>&1 && { printf '%s' "$out"; rc=$src; }
    fi
  fi
  return "$rc"
}

# A claim is met when the thing it names is THERE; a kind with no probe is
# BLIND, never met.
check_claim() { # <pr> <claim> <merged_at>
  local pr="$1" c="$2" merged_at="${3:-}"
  local host='' path='' clock='' tag='' unit='' port='' secret='' repo='' matches='' home=''
  local tok k v
  for tok in $c; do
    case "$tok" in
      host:*)    host="${tok#host:}" ;;
      path:*)    path="${tok#path:}" ;;
      clock:*)   clock="${tok#clock:}" ;;
      tag:*)     tag="${tok#tag:}" ;;
      unit:*)    unit="${tok#unit:}" ;;
      port:*)    port="${tok#port:}" ;;
      secret:*)  secret="${tok#secret:}" ;;
      repo:*)    repo="${tok#repo:}" ;;
      matches:*) matches="${tok#matches:}" ;;
      home:*)    home="${tok#home:}" ;;
    esac
  done
  local where="${host:-localhost}" rc out

  if [ -n "$matches" ] && [ -n "$home" ]; then
    # MERGED IS NOT DEPLOYED: the ledger could say a path exists, never that
    # the bytes AT it are the ones this PR merged. #499. Grading a mismatch
    # UNMET the moment it is seen would fail every PR for the day between
    # merge and the next nightly cut -- so a mismatch is only UNMET once a
    # build has actually been cut since this PR merged; before that it is
    # PENDING, the same distinction the propagation probe's adoption window
    # already makes for hosts instead of PRs.
    local repo_for_home="${repo:-$REPO}" deployed home_bytes drc
    deployed="$(read_deployed "$where" "$matches")"; drc=$?
    if [ "$drc" = 9 ]; then
      printf '  BLIND  #%s  matches:%s -- could not read the deployed file on %s\n' "$pr" "$matches" "$where"
      blind=$((blind+1)); return
    fi
    if [ "$drc" = 1 ]; then
      printf '  UNMET  #%s  matches:%s is not deployed on %s -- this PR is not done\n' "$pr" "$matches" "$where"
      unmet=$((unmet+1)); return
    fi
    home_bytes="$("$DA_GH" api "repos/$repo_for_home/contents/$home" --jq '.content // empty' 2>/dev/null | base64 -d 2>/dev/null)"
    if [ -z "$home_bytes" ]; then
      printf '  BLIND  #%s  matches:%s -- could not read home:%s from %s\n' "$pr" "$matches" "$home" "$repo_for_home"
      blind=$((blind+1)); return
    fi
    if [ "$deployed" = "$home_bytes" ]; then
      printf '  MET    #%s  matches:%s equals home:%s\n' "$pr" "$matches" "$home"
      met=$((met+1)); return
    fi
    if [ -z "$merged_at" ]; then
      printf '  BLIND  #%s  matches:%s differs from home:%s -- this PR names no merge time to age against\n' \
             "$pr" "$matches" "$home"
      blind=$((blind+1)); return
    fi
    local merge_epoch
    merge_epoch="$(date -u -d "$merged_at" +%s 2>/dev/null)"
    if [ -z "$merge_epoch" ] || ! fetch_verdict; then
      printf '  BLIND  #%s  matches:%s differs from home:%s -- could not read the release channel to tell whether a build has cut since merge\n' \
             "$pr" "$matches" "$home"
      blind=$((blind+1)); return
    fi
    if [ "$VERDICT_CUT_EPOCH" -gt "$merge_epoch" ]; then
      printf '  UNMET  #%s  matches:%s differs from home:%s, and a build has cut since this merged -- this PR is not done\n' \
             "$pr" "$matches" "$home"
      unmet=$((unmet+1))
    else
      printf '  PENDING #%s  matches:%s differs from home:%s, but no build has cut since this merged yet\n' \
             "$pr" "$matches" "$home"
      pending=$((pending+1))
    fi
    return
  fi

  if [ -n "$path" ]; then
    # ABSENT AND UNREADABLE DIFFER; `test -e` is false for both, and this read
    # the second as the first live. Walk to the deepest VISIBLE ancestor --
    # traversable -> absent, sealed -> BLIND, then escalate, since homes are
    # 0700 and every per-account claim would read BLIND forever.
    local probe='p="$1"; while [ ! -e "$p" ] && [ "$p" != / ]; do p="$(dirname "$p")"; done
      [ "$p" = "$1" ] && exit 0; [ -x "$p" ] || exit 9; exit 1'
    if [ "$where" = localhost ]; then
      bash -c "$probe" _ "$path"; rc=$?
      [ "$rc" = 9 ] && "$DA_SUDO" -n true 2>/dev/null &&
        { "$DA_SUDO" -n bash -c "$probe" _ "$path"; rc=$?; }
    else
      "$DA_HOST_SSH" -o BatchMode=yes "$where" "bash -s -- '$path'" <<<"$probe" >/dev/null 2>&1; rc=$?
      if [ "$rc" = 9 ]; then
        # `sudo -n` denied exits 1 -- ABSENT here -- so prove it ran.
        "$DA_HOST_SSH" -o BatchMode=yes "$where" \
          "sudo -n true 2>/dev/null && sudo -n bash -s -- '$path'" \
          <<<"$probe" >/dev/null 2>&1; local src=$?
        "$DA_HOST_SSH" -o BatchMode=yes "$where" 'sudo -n true' >/dev/null 2>&1 &&
          rc=$src
      fi
    fi
    case "$rc" in
      0) printf '  MET    #%s  path:%s on %s\n' "$pr" "$path" "$where"; met=$((met+1)) ;;
      9) printf '  BLIND  #%s  path:%s -- an ancestor is sealed to this prober; absence NOT established\n' \
                "$pr" "$path"; blind=$((blind+1)) ;;
      *) printf '  UNMET  #%s  path:%s is NOT on %s -- this PR is not done\n' "$pr" "$path" "$where"; unmet=$((unmet+1)) ;;
    esac
    return
  fi

  if [ -n "$clock" ] || [ -n "$tag" ]; then
    local acct="${clock%%@*}" chost="${clock##*@}"
    [ -n "$chost" ] && [ "$chost" != "$clock" ] || chost="${host:-localhost}"
    out="$("$DA_HOST_SSH" -o BatchMode=yes "$chost" "sudo -n crontab -l -u '${acct:-root}' 2>/dev/null; crontab -l 2>/dev/null" 2>/dev/null)"
    if [ -z "$out" ]; then
      printf '  BLIND  #%s  clock:%s -- could not read that crontab\n' "$pr" "$clock"; blind=$((blind+1))
    elif printf '%s' "$out" | grep -qF "${tag:-$clock}"; then
      printf '  MET    #%s  clock:%s tag:%s\n' "$pr" "${clock:-$chost}" "$tag"; met=$((met+1))
    else
      printf '  UNMET  #%s  tag:%s is in no crontab on %s -- this PR is not done\n' "$pr" "$tag" "$chost"; unmet=$((unmet+1))
    fi
    return
  fi

  if [ -n "$unit" ]; then
    out="$("$DA_HOST_SSH" -o BatchMode=yes "$where" "systemctl list-unit-files --no-legend '$unit' 2>/dev/null" 2>/dev/null)"
    if [ -n "$out" ]; then printf '  MET    #%s  unit:%s on %s\n' "$pr" "$unit" "$where"; met=$((met+1))
    else printf '  UNMET  #%s  unit:%s is not installed on %s -- this PR is not done\n' "$pr" "$unit" "$where"; unmet=$((unmet+1)); fi
    return
  fi

  if [ -n "$secret" ] && [ -n "$repo" ]; then
    if "$DA_GH" api "repos/$repo/actions/secrets/$secret" >/dev/null 2>&1; then
      printf '  MET    #%s  secret:%s on %s\n' "$pr" "$secret" "$repo"; met=$((met+1))
    else
      printf '  UNMET  #%s  secret:%s is not set on %s -- this PR is not done\n' "$pr" "$secret" "$repo"; unmet=$((unmet+1))
    fi
    return
  fi

  printf '  BLIND  #%s  no probe for this claim: %s\n' "$pr" "${c:0:60}"; blind=$((blind+1))
}

while IFS=$'\t' read -r num merged_at b64; do
  [ -n "$num" ] || continue
  audited=$((audited+1))
  body="$(printf '%s' "$b64" | base64 -d 2>/dev/null)"
  block="$(printf '%s' "$body" | tr -d '\r' | sed -n '/<!-- *DELIVERS *-->/,/<!-- *\/DELIVERS *-->/p')"
  if [ -z "$block" ]; then
    printf '  BLIND  #%s  no DELIVERS block -- merged before the ledger existed, or written past the shim\n' "$num"
    claimless=$((claimless+1)); blind=$((blind+1)); continue
  fi
  while IFS= read -r l; do
    case "$l" in
      '- none'*|'-none'*) continue ;;
      '- '*) check_claim "$num" "${l#- }" "$merged_at" ;;
    esac
  done <<<"$block"
done <<<"$BODIES"

printf '\n%d PR(s) audited; %d met, %d UNMET, %d pending, %d blind (%d carried no ledger).\n' \
  "$audited" "$met" "$unmet" "$pending" "$blind" "$claimless"
[ "$unmet" -gt 0 ] && { echo "An unmet claim means the PR is NOT done. The row names the one missing step."; exit 1; }
[ "$blind" -gt 0 ] && exit 6
exit 0
