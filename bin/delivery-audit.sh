#!/usr/bin/env bash
# delivery-audit.sh -- did the merged PRs actually take effect outside the repo?
#
# RUNNER: operator -- needs a GitHub credential and ssh to the hosts a claim
#   names; read-only everywhere, so it is safe on a clock
# GUARD-TEST: bin/tests/delivery-audit.test.sh
# GATE: none -- every path calls `gh` live; the fixture is in its own suite
#
# TRAPS (the rest of this header is in the vault):
# MERGED IS NOT DELIVERED. Every artifact has a place it is WRITTEN and a
# place it takes EFFECT, and nothing here guarded the transition -- #436
# merged and the host deploy never ran. A PR's DELIVERS block says where it
# lands; this goes and looks, and an unmet claim means the PR is NOT done.
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
# Overridable so the sealed-path cases are hermetic: whether the RUNNER
# happens to hold sudo must not decide what the suite asserts.
DA_SUDO="${DA_SUDO:-sudo}"
DA_GH="${DA_GH:-gh}"
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
  BODIES="$("$DA_GH" api "repos/$REPO/pulls/$ONE_PR" --jq '"\(.number)\t\(.body // "" | @base64)"' 2>/dev/null)"
else
  SINCE="$(date -u -d "-$DAYS days" +%Y-%m-%d 2>/dev/null)"
  [ -n "$SINCE" ] || { echo "$CLI_NAME: BLIND -- cannot compute the window start" >&2; exit 6; }
  BODIES="$("$DA_GH" api --paginate -X GET "search/issues" -f per_page=100 -f q="repo:$REPO is:pr is:merged merged:>=$SINCE" \
            --jq '.items[] | "\(.number)\t\(.body // "" | @base64)"' 2>/dev/null)"
fi
[ -n "$BODIES" ] || { echo "$CLI_NAME: BLIND -- $REPO returned no pull requests to audit" >&2; exit 6; }

echo "delivery-audit -- $REPO, ${ONE_PR:+PR $ONE_PR}${ONE_PR:+ }${ONE_PR:-last $DAYS days}"

met=0; unmet=0; blind=0; audited=0; claimless=0

# A claim is met when the thing it names is THERE. A kind with no probe is
# BLIND, never met.
check_claim() { # <pr> <claim>
  local pr="$1" c="$2" host='' path='' clock='' tag='' unit='' port='' secret='' repo=''
  local tok k v
  for tok in $c; do
    case "$tok" in
      host:*)   host="${tok#host:}" ;;
      path:*)   path="${tok#path:}" ;;
      clock:*)  clock="${tok#clock:}" ;;
      tag:*)    tag="${tok#tag:}" ;;
      unit:*)   unit="${tok#unit:}" ;;
      port:*)   port="${tok#port:}" ;;
      secret:*) secret="${tok#secret:}" ;;
      repo:*)   repo="${tok#repo:}" ;;
    esac
  done
  local where="${host:-localhost}" rc out

  if [ -n "$path" ]; then
    # ABSENT AND UNREADABLE ARE DIFFERENT ANSWERS; `test -e` is false for
    # both, and this read the second as the first on its first live run.
    # Walk to the deepest VISIBLE ancestor, then ask whether we could have
    # descended: traversable and child missing -> absent; sealed -> BLIND.
    local probe='p="$1"; while [ ! -e "$p" ] && [ "$p" != / ]; do p="$(dirname "$p")"; done
      [ "$p" = "$1" ] && exit 0; [ -x "$p" ] || exit 9; exit 1'
    # A home sealed at 0700 is the COMMON shape of a per-account claim, not an
    # exotic one: probed as an ordinary user, every such claim reads BLIND
    # forever and the ledger can never say "done". Look harder before saying
    # we cannot see -- rc 9 keeps its meaning only when the escalated probe is
    # unavailable too.
    if [ "$where" = localhost ]; then
      bash -c "$probe" _ "$path"; rc=$?
      [ "$rc" = 9 ] && "$DA_SUDO" -n true 2>/dev/null &&
        { "$DA_SUDO" -n bash -c "$probe" _ "$path"; rc=$?; }
    else
      "$DA_HOST_SSH" -o BatchMode=yes "$where" "bash -s -- '$path'" <<<"$probe" >/dev/null 2>&1; rc=$?
      if [ "$rc" = 9 ]; then
        # `sudo -n` denied exits 1, which is this probe's ABSENT -- so the
        # escalation must prove it ran before its answer is believed.
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

while IFS=$'\t' read -r num b64; do
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
      '- '*) check_claim "$num" "${l#- }" ;;
    esac
  done <<<"$block"
done <<<"$BODIES"

printf '\n%d PR(s) audited; %d met, %d UNMET, %d blind (%d carried no ledger).\n' \
  "$audited" "$met" "$unmet" "$blind" "$claimless"
[ "$unmet" -gt 0 ] && { echo "An unmet claim means the PR is NOT done. The row names the one missing step."; exit 1; }
[ "$blind" -gt 0 ] && exit 6
exit 0
