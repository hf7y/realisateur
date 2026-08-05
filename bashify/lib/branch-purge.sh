#!/usr/bin/env bash
# branch-purge.sh -- does each bashified branch still keep its own promise?
#
# WHY THIS EXISTS
# ---------------
# Every bashified branch opens its README with "This branch is a total purge:
# it keeps the tool and nothing else." bashify.sh enforces that -- ONCE, at
# emit, against the tree it is about to commit, refusing at exit 5 if anything
# matches.
#
# Nothing ever asks again.
#
# The doctrine changed on 2026-07-30 to one noun, many verbs, so a branch
# GROWING after emit is now the expected state rather than an odd one:
# `bashify coin` adds verbs, and emit itself refuses to run against a branch
# carrying more than one because it would delete them. So the guard runs at
# the exact moment the branch is smallest, and never again over the whole
# period it is actually being added to.
#
# Measured 2026-08-02, across all seven branches as they stand:
#
#   bibliothecaire 12   gardien 5   scheduler 3   senechal 2
#   ecosim 1            vim-arcade 1              realisateur 0
#
# Twenty-four files naming a vendor or an agent, on branches whose stated
# guarantee is that they contain none. This is the same shape as the runtime
# fork: a promise checked once, then left to drift, with nothing that ever
# asked whether it was still true.
#
# EXEMPTIONS ARE DERIVED WHERE POSSIBLE, RECORDED WHERE NOT
# ---------------------------------------------------------
# A guard that cries wolf is a guard someone eventually switches off -- this
# repo's own words, from the anchoring fix. Some of these mentions are
# load-bearing: lib/verb.sh's uses of "agent" ARE the documentation of the
# --summon mechanism, and deleting them deletes the explanation of how a verb
# completes itself.
#
# So there are exactly two ways to be exempt:
#
#   1. DERIVED -- lib/verb.sh, and only while BYTE-IDENTICAL to the skeleton.
#      bashify.sh already makes byte-identity load-bearing for this same
#      exemption; a looser test here would silently widen it.
#   2. RECORDED -- an entry in PURGE-EXEMPT.tsv, keyed project+path, with a
#      written justification. This is the DEPENDS.overrides.tsv pattern already
#      chosen for judgements that have no mechanical signal: the bulk stays
#      derived, the genuine judgement becomes explicit, small and reviewable.
#
# A file matching the pattern with NO exemption FAILS. A newly appearing one
# fails until a human classifies it once, which is the property that makes the
# record stay honest.
#
# AND THE EXEMPTIONS THEMSELVES ARE CHECKED. An entry naming a file that no
# longer matches, or no longer exists on the branch, is reported as STALE.
# "Retired entries actually removed, not left live" is a build-discipline row,
# and an exemption list is the single easiest place in a codebase to leave a
# dead entry standing forever.
#
# Read-only. Never writes to any repository, never checks anything out.
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

. "$ROOT/bin/lib/cli-guard.sh"
cli_guard "$@"
. "$SELF/lib/surface.sh"

SCHED="${BASHIFY_SCHED:-/home/zach/Documents/Projects/scheduler}"
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
  repo="$(grep -oP '^PROJECT_REPO_PATH=\K.*' "$conf" 2>/dev/null | tr -d '"'"'"'')"
  # Same defect closure.sh carried: the conf stores the path as a shell
  # LITERAL, so `$HOME` never expanded, `-d` failed for every project, and this
  # loop skipped all of them -- then printed "OK -- 0 branch(es) checked".
  # A purge guard that checks nothing and says OK is worse than no guard.
  repo="${repo/#\$HOME/$HOME}"
  repo="${repo/#\$\{HOME\}/$HOME}"
  [ -n "$repo" ] && [ -d "$repo/.git" ] || continue
  git -C "$repo" rev-parse --verify -q bashified >/dev/null 2>&1 || continue
  branches=$((branches+1))

  while read -r f; do
    [ -n "$f" ] || continue
    blob="$(git -C "$repo" show "bashified:$f" 2>/dev/null)" || continue
    # THE CRITERION IS INVOCATION, NOT NAMING (Zach, 2026-08-05 -- the same
    # ruling applied to lib/closure.sh; rationale in lib/surface.sh under
    # "NAMING vs INVOKING"). The branch's promise is that it DISPATCHES no
    # model. Refusing every file that merely names one is a proxy, and it is
    # the proxy that made the wrapped-script migration impossible: a script
    # cannot move onto the branch that is supposed to carry it if a vendor name
    # in a comment disqualifies it.
    #
    # Scored through a temp file because surface_invokes reads a FILE and must
    # strip comment lines to answer "does this RUN one" -- a distinction that
    # cannot be made on a blob without re-implementing it here, which is how
    # the anchoring fix reached one guard and not the other.
    # Only EXECUTABLE TEXT can dispatch anything. A man page or a CONTRACT.md
    # that writes `basheur run media-triage` in a table is documenting the
    # door, not opening it -- and scoring prose flagged exactly three such
    # files on the first run, all false. Decided by shebang or extension
    # rather than by directory, because senechal keeps scripts in health/ and
    # remedies/ and gardien keeps them in systemd/.
    # THE DRIFT CHECK RUNS FIRST, and independently of everything below.
    # It was written after the invocation filter in the first version of this
    # change, so a drifted lib/verb.sh that dispatches nothing was skipped by
    # the filter and never reached it -- the guard's own test F5 caught it.
    # Drift is not a question about vendors at all: it asks whether the shared
    # runtime on this branch is still the skeleton it claims to be, and the
    # answer must not depend on what the drifted copy happens to contain.
    if [ "$f" = 'lib/verb.sh' ]; then
      checked=$((checked+1))
      if [ "$(printf '%s\n' "$blob" | md5sum | cut -d' ' -f1)" = "$skel_sum" ]; then
        exempted=$((exempted+1)); EX_HIT["$proj/$f"]=1; continue
      fi
      FAIL_ROWS+=("$(printf '%-15s %-34s %s' "$proj" "$f" 'lib/verb.sh has DRIFTED from the skeleton -- the exemption does not apply to a modified runtime')")
      fails=$((fails+1)); continue
    fi

    # Only EXECUTABLE TEXT can dispatch. Everything else on the branch passes.
    case "$f" in
      *.sh|*.bash|*.py) is_script=1 ;;
      *.md|*.1|*.tsv|*.json|*.txt|*.conf) is_script=0 ;;
      *) case "$blob" in '#!'*) is_script=1 ;; *) is_script=0 ;; esac ;;
    esac
    [ "$is_script" = 1 ] || continue

    tmpblob="$(mktemp)"; printf '%s\n' "$blob" > "$tmpblob"
    inv="$(surface_invokes "$tmpblob")"
    rm -f "$tmpblob"
    [ "${inv:-0}" -gt 0 ] || continue
    checked=$((checked+1))

    # 2. RECORDED: an entry with a written justification.
    if [ -n "${EX_WHY["$proj/$f"]:-}" ]; then
      exempted=$((exempted+1)); EX_HIT["$proj/$f"]=1; continue
    fi

    # Report the INVOKING lines, not every vendor mention. Under the old
    # criterion "names: claude agent" was the finding; now the finding is that
    # the file runs one, and the reader needs the line that does it.
    hits="$(printf '%s\n' "$blob" | grep -vE '^[[:space:]]*#' | grep -inE "$SURFACE_RE_INVOKE" | head -2 | tr '\n' ' ')"
    FAIL_ROWS+=("$(printf '%-15s %-34s %s' "$proj" "$f" "invokes: $hits")")
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
# Zero branches is not a clean estate, it is a guard that opened nothing. This
# printed "OK -- 0 branch(es) checked" for as long as the $HOME defect above
# survived, which is exactly how it survived.
if [ "$branches" = 0 ]; then
  echo "$CLI_NAME: 0 branches checked -- no conf in $SCHED/schedule resolved to a" >&2
  echo "repository with a bashified branch. Refusing to report OK about nothing." >&2
  exit 1
fi

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
