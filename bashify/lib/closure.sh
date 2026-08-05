#!/usr/bin/env bash
# closure.sh -- score a wrapped script's TRANSITIVE SOURCE CLOSURE, not the file.
#
# WHY THIS EXISTS
# ---------------
# The migration rule is "a wrapped script moves onto the bashified branch iff it
# passes the purge guard." The purge guard scores files INDIVIDUALLY and is
# blind to `source`. So:
#
#   scheduler/bin/scheduler-run                          scores 0   -> passes
#   scheduler/bin/scheduler-run:93  source lib/sweep-loop-common.sh
#   scheduler/lib/sweep-loop-common.sh                   scores 35  -> `claude -p`
#
# A script whose entire job is dispatching a model passes the guard, because
# the naming is one `source` away. Under the migration rule it would be
# classified CLEAN and moved onto a branch whose stated guarantee is that it
# contains no such thing -- false in exactly the way the guard exists to
# prevent. That is a FALSE NEGATIVE, and it is worse than the false-positive
# class fixed by anchoring on 2026-08-02: a false positive blocks a commit and
# gets looked at, a false negative ships.
#
# The `lib/` exclusion in surface_discover is what makes this reachable at all:
# a library is not caller-facing, so it is never discovered, so it is never
# scored -- and nothing propagated its score back to the scripts that source it.
#
# WHAT "CLOSURE" MEANS HERE, exactly
# ----------------------------------
# A script's closure is itself plus every file it sources, transitively. A
# script is movable iff EVERY member of its closure is vendor-free. Both halves
# matter, and for different reasons:
#
#   - if a sourced library names a vendor and moves too, the branch's guarantee
#     is false;
#   - if it does not move, the script on the branch sources a file that is not
#     there, and is broken.
#
# There is no third option where a dirty library is simply ignored.
#
# THE HONEST FAILURE MODE -- and it is loud
# -----------------------------------------
# `source "$CONF"` cannot be resolved from source text; the path is runtime
# state. Silently treating an unresolvable source as "no dependency" would
# rebuild the very false negative this tool exists to close, one layer down.
# Such a script is reported UNRESOLVED and is NEVER CLEAN. scheduler-run has
# one of these too, at line 44 -- so it fails this tool twice, for two
# independent reasons.
#
# Read-only. Never writes to any repository, never checks anything out.
set -uo pipefail

CLI_NAME='closure.sh'
CLI_SUMMARY='classify each wrapped script by the purge score of its transitive source closure'
CLI_USAGE='  closure.sh                 every project with a bashified branch
  closure.sh <project>...    only those
  closure.sh --tsv           machine-readable rows, no summary
  closure.sh --false-neg     ONLY the scripts the file-at-a-time guard clears
                             and the closure condemns -- the migration blocker'
CLI_FLAGS='--tsv --false-neg'
CLI_POSITIONAL=any
CLI_EXITS='  0  no script is misclassified by the file-at-a-time guard
  1  at least one false negative, unresolved source, or unreadable file'

SELF="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"   # bashify/
ROOT="$(cd "$SELF/.." && pwd)"                                             # realisateur/

. "$ROOT/bin/lib/cli-guard.sh"
cli_guard "$@"
. "$SELF/lib/surface.sh"

SCHED="${BASHIFY_SCHED:-/home/zach/Documents/Projects/scheduler}"

TSV=0; ONLY_FALSE_NEG=0; WANT=()
for a in "$@"; do
  case "$a" in
    --tsv)       TSV=1 ;;
    --false-neg) ONLY_FALSE_NEG=1 ;;
    *)           WANT+=("$a") ;;
  esac
done

[ -d "$SCHED/schedule" ] || { echo "$CLI_NAME: FATAL: no scheduler schedule dir at $SCHED/schedule" >&2; exit 1; }

# ---- source-directive extraction ------------------------------------------
# Comment lines are excluded; everything else is taken at face value. Over-
# inclusion (a `source` inside a heredoc) adds a dependency, which can only
# make a script look dirtier -- the safe direction for a guarantee of absence.
# A first cut stopped the argument at the first `)`, which truncated the very
# common `. "$(dirname "$0")/../lib/x.sh"` to `"$(dirname "$0"` and reported it
# UNRESOLVED. Take the whole remainder of the line instead and strip only what
# genuinely cannot be part of a path: a redirection, a list operator, or a
# trailing comment.
_source_args() {
  grep -vE '^[[:space:]]*#' "$1" 2>/dev/null \
    | sed -nE -e 's/^[[:space:]]*(source|\.)[[:space:]]+(.*)$/\2/p' \
              -e 's/^.*[;&][[:space:]]*(source|\.)[[:space:]]+(.*)$/\2/p' \
    | sed -E 's/[[:space:]]+[0-9]*[<>].*$//; s/[[:space:]]+(\|\||&&|;).*$//; s/[[:space:]]+#.*$//' \
    | sed -E 's/[[:space:]]+$//' \
    | grep -v '^$'
}

# _resolve <repo> <script-rel> <raw-arg>
# Prints a repo-relative path, or `!UNRESOLVED`, or `!EXTERNAL:<path>`.
#
# The variable rule is deliberate and stated: a leading `$VAR/` or `$(...)/ `
# is treated as SOME root, and the suffix after the first `/` is tried against
# every plausible root. If the argument has no `/` at all -- `source "$CONF"`
# -- there is no suffix to try and it is UNRESOLVED, full stop. This is a
# heuristic; its failure mode is a loud UNRESOLVED, never a quiet pass.
_resolve() {
  local repo="$1" rel="$2" raw="$3" sfx cand dir prev
  local V=$'\001'   # stands in for "some expansion", so it can never contain /
  raw="${raw%\"}"; raw="${raw#\"}"; raw="${raw%\'}"; raw="${raw#\'}"
  [ -n "$raw" ] || { printf '!UNRESOLVED'; return; }
  dir="$repo/$(dirname "$rel")"

  # Collapse every expansion to a single slash-free token FIRST, so that "the
  # part after the first /" means the same thing whether the root was written
  # `$SCHED_ROOT`, `${SELF}` or `$(dirname "$0")`. Looped for nesting.
  while [[ "$raw" == *'$('* || "$raw" == *'`'* ]]; do
    prev="$raw"
    raw="$(printf '%s' "$raw" | sed -E 's/\$\([^()]*\)/\x01/g; s/`[^`]*`/\x01/g')"
    [ "$raw" = "$prev" ] && break
  done
  raw="$(printf '%s' "$raw" | sed -E 's/\$\{[^}]*\}/\x01/g; s/\$[A-Za-z_][A-Za-z0-9_]*/\x01/g')"

  if [[ "$raw" != *"$V"* ]]; then
    sfx="$raw"
  else
    case "$raw" in
      */*) sfx="${raw#*/}" ;;
      # The whole argument is one expansion -- `source "$CONF"`. There is no
      # path shape to try. This is the honest UNRESOLVED, and the reason this
      # tool never silently treats a dynamic source as no dependency.
      *)   printf '!UNRESOLVED'; return ;;
    esac
    # An expansion still inside the suffix means the suffix is runtime state
    # too, not a path shape. Do not guess.
    [[ "$sfx" == *"$V"* ]] && { printf '!UNRESOLVED'; return; }
  fi

  for cand in "$dir/$sfx" "$repo/$sfx" "$dir/../$sfx" "$dir/../../$sfx" "$sfx"; do
    if [ -f "$cand" ]; then
      cand="$(readlink -f "$cand" 2>/dev/null)" || continue
      case "$cand" in
        "$repo"/*) printf '%s' "${cand#"$repo"/}"; return ;;
        *)         printf '!EXTERNAL:%s' "$cand"; return ;;
      esac
    fi
  done
  printf '!UNRESOLVED'
}

# ---- the closure ----------------------------------------------------------
# Fills CLOSURE (repo-relative members), UNRES (raw args that did not resolve),
# EXTERN (absolute paths outside the repo). Cycle-safe via SEEN.
declare -A SEEN
declare -a CLOSURE UNRES EXTERN
_closure() {
  local repo="$1" rel="$2" raw r
  [ -n "${SEEN[$rel]:-}" ] && return
  SEEN[$rel]=1
  CLOSURE+=("$rel")
  [ -r "$repo/$rel" ] || return
  while IFS= read -r raw; do
    [ -n "$raw" ] || continue
    r="$(_resolve "$repo" "$rel" "$raw")"
    case "$r" in
      '!UNRESOLVED')  UNRES+=("$rel: $raw") ;;
      '!EXTERNAL:'*)  EXTERN+=("$rel: ${r#!EXTERNAL:}") ;;
      *)              _closure "$repo" "$r" ;;
    esac
  done < <(_source_args "$repo/$rel")
}

# ---- run ------------------------------------------------------------------
[ "$TSV" = 1 ] && printf '#project\tscript\tclass\tself\tclosure\tmembers\tvia\tunresolved\n'

total=0; false_neg=0; unres_tot=0; unread=0; capped=''
declare -a FN_ROWS=() UNRES_ROWS=()
declare -A CLASS_N=()

for conf in "$SCHED"/schedule/*.conf; do
  proj="$(basename "$conf" .conf)"
  if [ "${#WANT[@]}" -gt 0 ]; then
    printf '%s\n' "${WANT[@]}" | grep -qxF "$proj" || continue
  fi
  repo="$(grep -oP '^PROJECT_REPO_PATH=\K.*' "$conf" 2>/dev/null | tr -d '"'"'"'')"
  # The confs store the path as a shell LITERAL -- `PROJECT_REPO_PATH="$HOME/..."`
  # -- because cron expands it at run time. Read statically it is the seven
  # characters `$HOME`, so `-d "$repo/.git"` failed for EVERY project and each
  # one was skipped by the `continue` below. The run then reported a partition
  # over 0 scripts and exited 0, which reads as "nothing is wrong" rather than
  # "nothing was looked at". Verified 2026-08-05 via:
  #   grep -oP '^PROJECT_REPO_PATH=\K.*' schedule/senechal.conf  ->  $HOME/...
  repo="${repo/#\$HOME/$HOME}"
  repo="${repo/#\$\{HOME\}/$HOME}"
  [ -n "$repo" ] && [ -d "$repo/.git" ] || continue
  git -C "$repo" rev-parse --verify -q bashified >/dev/null 2>&1 || continue
  repo="$(readlink -f "$repo")"

  mapfile -t scripts < <(surface_discover "$repo")
  # surface_discover caps at 60. A silent cap reads as "covered everything".
  [ "${#scripts[@]}" -ge 60 ] && capped="$capped $proj"

  for rel in ${scripts[@]+"${scripts[@]}"}; do
    SEEN=(); CLOSURE=(); UNRES=(); EXTERN=()
    _closure "$repo" "$rel"

    if [ ! -r "$repo/$rel" ]; then
      unread=$((unread+1))
      printf '%s: UNREADABLE %s/%s (tracked but not present)\n' "$CLI_NAME" "$proj" "$rel" >&2
    fi

    self_s="$(surface_score "$repo/$rel")"
    worst=0; worst_code=0; via='-'
    for m in "${CLOSURE[@]}"; do
      s="$(surface_score "$repo/$m")"
      c="$(surface_score_code "$repo/$m")"
      if [ "$s" -gt "$worst" ]; then worst="$s"; via="$m"; fi
      [ "$c" -gt "$worst_code" ] && worst_code="$c"
    done

    nunres="${#UNRES[@]}"
    if   [ "$worst_code" -gt 0 ]; then class=ESSENTIAL
    elif [ "$nunres" -gt 0 ];     then class=UNRESOLVED
    elif [ "${#EXTERN[@]}" -gt 0 ]; then class=ESCAPES
    elif [ "$worst" -gt 0 ];      then class=COMMENT-ONLY
    else class=CLEAN
    fi

    total=$((total+1))
    CLASS_N[$class]=$(( ${CLASS_N[$class]:-0} + 1 ))
    unres_tot=$((unres_tot + nunres))

    # THE FINDING: the file-at-a-time guard clears it, the closure does not.
    is_fn=0
    if [ "$self_s" = 0 ] && [ "$class" != CLEAN ]; then
      is_fn=1; false_neg=$((false_neg+1))
      FN_ROWS+=("$(printf '%-13s %-26s %-12s self=0 closure=%-3s members=%-2s via %s' \
        "$proj" "$rel" "$class" "$worst" "${#CLOSURE[@]}" "$via")")
    fi
    for u in ${UNRES[@]+"${UNRES[@]}"}; do UNRES_ROWS+=("$proj/$u"); done

    if [ "$TSV" = 1 ]; then
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$proj" "$rel" "$class" "$self_s" "$worst" "${#CLOSURE[@]}" "$via" "$nunres"
    elif [ "$ONLY_FALSE_NEG" = 0 ]; then
      printf '%-13s %-12s self=%-3s closure=%-3s members=%-2s %s\n' \
        "$proj" "$class" "$self_s" "$worst" "${#CLOSURE[@]}" "$rel"
    fi
  done
done

# A name that matches nothing must not exit 0. "Reports clean about something
# it never looked at" is this ecosystem's most-recorded failure mode, and a
# project filter is where it hides best -- the same assertion verify-sync.sh
# calls B4 and treats as load-bearing.
if [ "$total" = 0 ] && [ "${#WANT[@]}" -gt 0 ]; then
  echo "$CLI_NAME: no project named '${WANT[*]}' has a bashified branch -- nothing was scored." >&2
  echo "(refusing to exit 0 about a name that matches nothing)" >&2
  exit 1
fi

# The guard above only fired when a project FILTER was given, so the unfiltered
# run -- the one a human types -- printed an all-zero partition and exited 0.
# That is how the $HOME defect above survived: the tool reported a clean
# migration surface across the whole estate while reading no repository at all.
# Zero scripts is never an answer about the estate; it is a broken scan.
if [ "$total" = 0 ]; then
  echo "$CLI_NAME: scored 0 wrapped scripts across every conf in $SCHED/schedule." >&2
  echo "(refusing to exit 0 having read nothing -- check PROJECT_REPO_PATH resolves)" >&2
  exit 1
fi

[ "$TSV" = 1 ] && exit $(( false_neg > 0 || unres_tot > 0 || unread > 0 ? 1 : 0 ))

echo
echo "=== partition by CLOSURE, over $total wrapped scripts ==="
for k in CLEAN COMMENT-ONLY ESSENTIAL UNRESOLVED ESCAPES; do
  printf '  %-13s %s\n' "$k" "${CLASS_N[$k]:-0}"
done

echo
if [ "$false_neg" = 0 ]; then
  echo "No false negatives: every script the file-at-a-time guard clears is also"
  echo "clear under its transitive source closure."
else
  echo "=== $false_neg FALSE NEGATIVE(S) -- pass the guard, fail the closure ==="
  echo "Each of these would be classified CLEAN and MOVED by the file-at-a-time"
  echo "rule, putting a vendor-naming or unresolvable dependency onto a branch"
  echo "that guarantees it holds none. None of them may move."
  echo
  printf '  %s\n' "${FN_ROWS[@]}"
fi

if [ "$unres_tot" -gt 0 ]; then
  echo
  echo "=== $unres_tot UNRESOLVED source directive(s) ==="
  echo "The path is runtime state, so no static tool can score what is behind it."
  echo "Reported, never assumed empty -- assuming empty is the same defect one"
  echo "layer down."
  printf '  %s\n' "${UNRES_ROWS[@]}" | sort -u
fi

[ -n "$capped" ] && {
  echo
  echo "NOTE: discovery caps at 60 scripts; these hit the cap and are TRUNCATED,"
  echo "so their rows above are a lower bound:$capped"
}

exit $(( false_neg > 0 || unres_tot > 0 || unread > 0 ? 1 : 0 ))
