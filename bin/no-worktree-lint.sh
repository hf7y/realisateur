#!/usr/bin/env bash
# bin/no-worktree-lint.sh -- does any production script in this tree create a
# git worktree?
#
# RUNNER: bin/tests/no-worktree-lint.test.sh
# GUARD-TEST: bin/tests/no-worktree-lint.test.sh
# GATE: default
#
# TRAPS (the rest of this header is in the vault):
# Zach, 2026-08-06: "we should not have any more worktrees after tonight."
# hf7y/realisateur#69 and hf7y/scheduler#49 were filed the same evening and the
# 18 linked worktrees they surveyed were removed. Five days later there were
# 30. Nothing had gone wrong: three production scripts create worktrees as
# part of ordinary operation, so clearing the directories was undone by the
# next run of each. Removing today's instances is not the fix; the fix is that
# a new one cannot be added without this going red.
# The three, live on 2026-08-11:
#   bashify/bashify.sh            a worktree per `bashify emit`, never removed
#   bin/land-selfdev.sh           $PROJECTS/senechal-verbs, from `bashified`
#   (scheduler) bin/scheduler-dev-cycle.sh, bin/overnight-dev.sh
# It also cannot ROT: check B below fails if an allowlisted path has stopped
# matching, so an entry cannot outlive its reason. That is the half a
# ratchet's --accept normally provides, and it is the half that matters here.
#
# usage:  no-worktree-lint.sh [ROOT]
# exit:   0 clean   1 FLAGs   2 BLIND (not a git tree, or zero files scanned --

set -uo pipefail

# Resolved from cwd, not from this script's own location: a guard that falls
# back to the checkout it lives in reports on the live estate when it is
# pointed at a tree, which is the defect bin/tests/guard-estate.test.sh case F1
# exists to catch. Same resolution as bin/hardcoded-home-lint.sh.
ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -n "$ROOT" ] && [ -d "$ROOT" ] || {
  echo "BLIND: no git worktree root resolved from $PWD -- this guard could not look." >&2
  exit 2
}
cd "$ROOT" || { echo "BLIND: cannot cd to $ROOT" >&2; exit 2; }

# The pattern. `git ... worktree add` with anything (or nothing) between, so
# `git -C "$repo" worktree add` and `git worktree add` both match, and
# `git worktree remove`/`prune` -- which DELETE registrations and are the fix,
# not the defect -- do not.
PATTERN='git([[:space:]]+-[^[:space:]]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+worktree[[:space:]]+add'

# ALLOWLIST: allow <path> "<why>". Every entry must still match, or check B fails.
ALLOW_PATHS=()
ALLOW_WHY=()
allow() { ALLOW_PATHS+=("$1"); ALLOW_WHY+=("$2"); }

# Is this the tree the compiled allowlist was written for? Asked of the tree,
# not of $0: the guard is invoked by absolute path from suites and sandboxes
# that are not the repository under test.
SELF_REL="bin/no-worktree-lint.sh"
ALLOW_APPLIES=0
if [ -n "${NO_WORKTREE_ALLOW_FILE:-}" ]; then
  ALLOW_APPLIES=1
  while IFS=$'\t' read -r _p _w; do
    [ -n "${_p:-}" ] || continue
    case "$_p" in \#*) continue ;; esac
    allow "$_p" "${_w:-no reason recorded}"
  done < "$NO_WORKTREE_ALLOW_FILE"
elif git ls-files --error-unmatch "$SELF_REL" >/dev/null 2>&1; then
  ALLOW_APPLIES=1
  allow bashify/lib/sync-runtime.sh \
  "creates \$PROJECTS/<project>-verbs under --apply when no worktree already has the branch's bashified checked out (#158) -- a human review copy for the write sync performs, same shape as bashify.sh's per-emit worktree, and never created during preflight (no --apply)"
fi

# Excluded prefixes -- see the header for why each.
excluded() {
  case "$1" in
    bin/tests/*|test/*|tests/*|*/test/*|*/tests/*) return 0 ;;
    archive/*)                                    return 0 ;;
    bin/no-worktree-lint.sh)                      return 0 ;;
  esac
  return 1
}

# WHICH FILES. Tracked only, so an untracked scratch script cannot turn the
# guard red and a deleted one cannot keep it red. `*.sh` misses the
# extensionless executables in bin/, so those are selected by SHEBANG -- the
# only honest way to ask "is this shell". Same selector as
# bin/shellcheck-lint.sh, and for the same reason it was widened there.
mapfile -t FILES < <(
  {
    git ls-files '*.sh' 2>/dev/null
    while IFS= read -r f; do
      [ -f "$f" ] || continue
      case "$f" in *.sh|*.md|*.1|*.yml|*.yaml|*.json|*.tsv|*.conf) continue ;; esac
      head -c 2 "$f" 2>/dev/null | grep -q '^#!' && printf '%s\n' "$f"
    done < <(git ls-files 2>/dev/null)
  } | sort -u
)

SCANNED=(); for f in ${FILES[@]+"${FILES[@]}"}; do excluded "$f" || SCANNED+=("$f"); done

# Zero files is BLIND, never clean. `bin/tests/*.sh matched nothing` was a real
# CI defect in this repository and a lint that lints nothing is its twin.
if [ "${#SCANNED[@]}" -eq 0 ]; then
  echo "BLIND: no tracked shell file outside the test tree under $ROOT -- this guard scanned nothing."
  exit 2
fi

flags=0
echo "== A. NO PRODUCTION PATH CREATES A WORKTREE =="
echo "  root: $ROOT   scanned: ${#SCANNED[@]} tracked shell file(s)"

matches_of() {   # <file> -> "<lineno>:<line>" for each non-comment match
  grep -nE "$PATTERN" -- "$1" 2>/dev/null \
    | awk -F: '{ rest=substr($0, index($0,":")+1); sub(/^[0-9]+:/,"",rest);
                 line=rest; sub(/^[[:space:]]*/,"",line);
                 if (line !~ /^#/) print $0 }'
}

is_allowed() { local p="$1" i; for i in "${!ALLOW_PATHS[@]}"; do [ "${ALLOW_PATHS[$i]}" = "$p" ] && return 0; done; return 1; }

for f in "${SCANNED[@]}"; do
  hits="$(matches_of "$f")"
  [ -n "$hits" ] || continue
  if is_allowed "$f"; then continue; fi
  while IFS= read -r h; do
    [ -n "$h" ] || continue
    echo "FLAG [creator] $f:${h%%:*} names 'git worktree add' in a production path"
    flags=$((flags + 1))
  done <<<"$hits"
done

echo
echo "== B. EVERY ALLOWLIST ENTRY STILL EARNS ITS PLACE =="
if [ "$ALLOW_APPLIES" -eq 0 ]; then
  echo "  not applicable -- $ROOT does not track $SELF_REL, so this guard's"
  echo "  allowlist is not about this tree and nothing here is stale by it"
elif [ "${#ALLOW_PATHS[@]}" -eq 0 ]; then
  echo "  allowlist is empty -- nothing to justify"
else
  for i in "${!ALLOW_PATHS[@]}"; do
    p="${ALLOW_PATHS[$i]}"
    if [ ! -f "$p" ]; then
      echo "FLAG [stale allowlist] $p is allowlisted but does not exist -- delete the entry"
      flags=$((flags + 1))
    elif [ -z "$(matches_of "$p")" ]; then
      echo "FLAG [stale allowlist] $p is allowlisted but no longer matches -- delete the entry"
      flags=$((flags + 1))
    else
      echo "  allowed $p -- ${ALLOW_WHY[$i]}"
    fi
  done
fi

echo
echo "== C. NO WORKTREE IS ACTUALLY REGISTERED NOW =="

# #429: reads git's actual registrations; same rot discipline as check B.
WT_ALLOW_PATTERNS=()
WT_ALLOW_WHY=()
wt_allow() { WT_ALLOW_PATTERNS+=("$1"); WT_ALLOW_WHY+=("$2"); }
if [ -n "${NO_WORKTREE_WT_ALLOW_FILE:-}" ]; then
  while IFS=$'\t' read -r _p _w; do
    [ -n "${_p:-}" ] || continue
    case "$_p" in \#*) continue ;; esac
    wt_allow "$_p" "${_w:-no reason recorded}"
  done < "$NO_WORKTREE_WT_ALLOW_FILE"
fi

mapfile -t STRAY_WT < <(
  git -C "$ROOT" worktree list --porcelain 2>/dev/null \
    | awk -v m="$ROOT" '/^worktree /{p=substr($0,10); if (p != m) print p}'
)

wt_matched=()
for wt in ${STRAY_WT[@]+"${STRAY_WT[@]}"}; do
  hit=0
  for i in "${!WT_ALLOW_PATTERNS[@]}"; do
    # shellcheck disable=SC2254 # deliberate glob: the pattern IS the glob
    case "$wt" in
      ${WT_ALLOW_PATTERNS[$i]}) hit=1; wt_matched[$i]=1 ;;
    esac
  done
  if [ "$hit" -eq 1 ]; then continue; fi
  echo "FLAG [stray worktree] $wt is a registered worktree outside the main checkout"
  flags=$((flags + 1))
done

for i in "${!WT_ALLOW_PATTERNS[@]}"; do
  if [ "${wt_matched[$i]:-0}" -ne 1 ]; then
    echo "FLAG [stale worktree allowlist] ${WT_ALLOW_PATTERNS[$i]} is allowlisted but no worktree matches it -- delete the entry"
    flags=$((flags + 1))
  else
    echo "  allowed ${WT_ALLOW_PATTERNS[$i]} -- ${WT_ALLOW_WHY[$i]}"
  fi
done

if [ "${#STRAY_WT[@]}" -eq 0 ] && [ "${#WT_ALLOW_PATTERNS[@]}" -eq 0 ]; then
  echo "  0 worktree(s) registered under $ROOT besides the main checkout"
fi

echo
if [ "$flags" -gt 0 ]; then
  echo "$flags FLAG(s)."
  echo "A worktree is not forbidden because it is exotic. It is forbidden because"
  echo "the estate has already paid for one: gardien's garde.json lived only inside"
  echo "a worktree, a migration removed it, and no backup could be proved for days"
  echo "(hf7y/gardien#7). Work in a clone under mktemp and push a branch instead."
  exit 1
fi
echo "0 FLAG(s) -- no production path in $ROOT names 'git worktree add'."
exit 0
