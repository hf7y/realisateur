#!/usr/bin/env bash
# branch-purge.sh -- does each bashified branch still keep its own promise?
#
# TRAPS (the rest of this header is in the vault):
# WHY THIS EXISTS
# ---------------
# Every bashified branch opens its README with "This branch is a total purge:
# it keeps the tool and nothing else." bashify.sh enforces that -- ONCE, at
# emit, against the tree it is about to commit, refusing at exit 5 if anything
# matches.
# The doctrine changed on 2026-07-30 to one noun, many verbs, so a branch
# GROWING after emit is now the expected state rather than an odd one:
# `bashify coin` adds verbs, and emit itself refuses to run against a branch
# carrying more than one because it would delete them. So the guard runs at
# the exact moment the branch is smallest, and never again over the whole
# period it is actually being added to.

set -uo pipefail

CLI_NAME='branch-purge.sh'
CLI_SUMMARY='check every bashified branch against the purge promise it makes about itself'
CLI_USAGE='  branch-purge.sh              every project with a bashified branch
  branch-purge.sh <project>   only that one
  branch-purge.sh --list      print the offending files, one per line, and exit'
CLI_FLAGS='--list'
CLI_POSITIONAL=any
CLI_EXITS='  0  every branch still keeps its promise (or is exempt, with a reason)
  1  at least one branch carries a trace it promises not to, or an exemption is stale'

SELF="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"   # bashify/
ROOT="$(cd "$SELF/.." && pwd)"                                             # realisateur/

. "$ROOT/bin/lib/conf.sh"
. "$ROOT/bin/lib/cli-guard.sh"
cli_guard "$@"
. "$SELF/lib/surface.sh"

SCHED="${BASHIFY_SCHED:-${SCHED_ROOT:-${INSTALLE_PROJECTS:-$HOME/Documents/Projects}/scheduler}}"
SKEL="$SELF/skel/lib/verb.sh"
EXEMPT="${BASHIFY_EXEMPT:-$SELF/PURGE-EXEMPT.tsv}"

LIST=0; WANT=()
for a in "$@"; do
  case "$a" in --list) LIST=1 ;; *) WANT+=("$a") ;; esac
done

[ -d "$SCHED/schedule" ] || { echo "$CLI_NAME: FATAL: no schedule dir at $SCHED/schedule" >&2; exit 1; }
[ -f "$SKEL" ] || { echo "$CLI_NAME: FATAL: no skeleton at $SKEL" >&2; exit 1; }
skel_sum="$(md5sum < "$SKEL" | cut -d' ' -f1)"

# ---- the recorded exemptions ----------------------------------------------
declare -A EX_WHY=() EX_HIT=()
if [ -f "$EXEMPT" ]; then
  while IFS=$'\t' read -r xp xf xc xw; do
    case "${xp:-}" in ''|'#'*) continue ;; esac
    EX_WHY["$xp/$xf"]="$xc: $xw"
  done < "$EXEMPT"
fi

fails=0; checked=0; exempted=0; branches=0
declare -a FAIL_ROWS=()

for conf in "$SCHED"/schedule/*.conf; do
  proj="$(basename "$conf" .conf)"
  if [ "${#WANT[@]}" -gt 0 ]; then
    printf '%s\n' "${WANT[@]}" | grep -qxF "$proj" || continue
  fi
  repo="$(conf_repo_path "$conf" || true)"
  [ -n "$repo" ] && [ -d "$repo/.git" ] || continue
  git -C "$repo" rev-parse --verify -q bashified >/dev/null 2>&1 || continue
  branches=$((branches+1))

  while read -r f; do
    [ -n "$f" ] || continue
    blob="$(git -C "$repo" show "bashified:$f" 2>/dev/null)" || continue
    printf '%s' "$blob" | grep -qiE "$SURFACE_RE_ANY" || continue
    checked=$((checked+1))

    # 1. DERIVED: the skeleton runtime, and only while byte-identical.
    if [ "$f" = 'lib/verb.sh' ]; then
      if [ "$(printf '%s\n' "$blob" | md5sum | cut -d' ' -f1)" = "$skel_sum" ]; then
        exempted=$((exempted+1)); EX_HIT["$proj/$f"]=1; continue
      fi
      FAIL_ROWS+=("$(printf '%-15s %-34s %s' "$proj" "$f" 'lib/verb.sh has DRIFTED from the skeleton -- the exemption does not apply to a modified runtime')")
      fails=$((fails+1)); continue
    fi

    # 2. RECORDED: an entry with a written justification.
    if [ -n "${EX_WHY["$proj/$f"]:-}" ]; then
      exempted=$((exempted+1)); EX_HIT["$proj/$f"]=1; continue
    fi

    hits="$(printf '%s' "$blob" | grep -ioE "$SURFACE_RE_ANY" | sort -u | tr '\n' ' ')"
    FAIL_ROWS+=("$(printf '%-15s %-34s %s' "$proj" "$f" "names: $hits")")
    fails=$((fails+1))
    [ "$LIST" = 1 ] && printf '%s\t%s\n' "$proj" "$f"
  done < <(git -C "$repo" ls-tree -r --name-only bashified 2>/dev/null)
done

[ "$LIST" = 1 ] && exit $(( fails > 0 ? 1 : 0 ))

# A name matching nothing must not exit 0 about work it never did.
if [ "$branches" = 0 ] && [ "${#WANT[@]}" -gt 0 ]; then
  echo "$CLI_NAME: no project named '${WANT[*]}' has a bashified branch -- nothing was checked." >&2
  echo "(refusing to exit 0 about a name that matches nothing)" >&2
  exit 1
fi

# ---- stale exemptions ------------------------------------------------------
stale=0
for k in "${!EX_WHY[@]}"; do
  [ -n "${EX_HIT[$k]:-}" ] && continue
  [ "$stale" = 0 ] && { echo; echo "=== STALE EXEMPTIONS ==="; \
    echo "Each names a file that no longer matches the pattern, or is no longer on"; \
    echo "the branch. An exemption outliving its reason is how a temporary"; \
    echo "divergence becomes permanent."; }
  printf '  %-42s %s\n' "$k" "${EX_WHY[$k]}"
  stale=$((stale+1))
done

echo
if [ "$fails" = 0 ]; then
  echo "OK -- $branches branch(es) checked; $exempted exempt mention(s), all with a recorded reason."
else
  echo "=== $fails FILE(S) BREAK THE PURGE PROMISE, across $branches branch(es) ==="
  echo "Each is on a branch whose README says it 'keeps the tool and nothing else'."
  echo "The emit-time guard passed because it ran before these files existed."
  echo
  printf '  %s\n' "${FAIL_ROWS[@]}"
  echo
  echo "To resolve: remove the material, or record it in"
  echo "  ${EXEMPT#"$ROOT"/}"
  echo "with a class and a justification. An exemption without a reason is just"
  echo "the guard switched off in a file nobody reads."
fi
exit $(( fails > 0 || stale > 0 ? 1 : 0 ))
