#!/usr/bin/env bash
# carry-drift.sh -- a file carried onto `bashified` is a REPLICA of the one on
# `main`, byte for byte, or it is a second copy of the same fact.
#
# GUARD: does every file the bashified branch carries still match its original?
# RUNNER: .github/workflows/tests.yml -- job `surface`, against origin/bashified
# GUARD-TEST: bin/tests/carry-drift.test.sh
# GATE: default --repo $TREE
#
# TRAPS (the rest of this header is in the vault):
# Zach, 2026-08-16, deciding hf7y/realisateur#330: "it cannot be several
# copies, one per repo that will drift inevitably; this needs to be one single,
# stable location where policy changes automatically reach." One home is
# `main`. This makes every other copy mechanical: `--carry` writes them, and
# the comparison below is what stops one being edited in place.
# CARRIES is the typed part, and it says something derivation cannot: this
# file MUST BE THERE. Derivation can only grade what is already on the branch,
# so a carry that was never made looks exactly like a file nobody wanted --
# which is #327 in one sentence: the shim merged, nothing linked it, every
# check stayed green. A declared row that is absent is a MISSING finding, and
# `--carry` creates it.

set -uo pipefail

CLI_NAME='carry-drift.sh'
CLI_SUMMARY='does every file carried onto `bashified` still match its original on main?'
CLI_USAGE='  carry-drift.sh                  report drift between main and bashified
  carry-drift.sh --repo <dir>     grade that checkout instead of this one
  carry-drift.sh --carry <dir>    write main`s copy over the bashified checkout at <dir>
  carry-drift.sh --accept         drop ratchet rows whose pair now matches'
CLI_FLAGS='--repo --carry --accept --ratchet'
CLI_POSITIONAL=any
CLI_EXITS='  0  every carried file matches, or the pairs that do not are ratcheted
  1  a carried file has drifted from its original and is not in the ratchet
  2  usage error
  3  BLIND -- no `bashified` ref to read. Never 0: could-not-look is not clean.'
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/cli-guard.sh"
cli_guard "$@"

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
RATCHET="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/carry-drift.ratchet"
CARRY_TO=''
ACCEPT=0

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)    ROOT="${2:?--repo needs a directory}"; shift ;;
    --carry)   CARRY_TO="${2:?--carry needs a directory}"; shift ;;
    --accept)  ACCEPT=1 ;;
    --ratchet) RATCHET="${2:?--ratchet needs a file}"; shift ;;
    *) printf '%s: unknown argument: %s\n' "$CLI_NAME" "$1" >&2; exit 2 ;;
  esac
  shift
done

# Rows are <path on bashified> <path on main>, and each one asserts BOTH that
# the file must exist on the branch and what it must equal.
#
CARRIES='
bin/gh	bin/gh-sign.sh
bin/lib/body-grammar.sh	bin/lib/body-grammar.sh
bin/lib/answered.sh	bin/lib/answered.sh
bin/check-project-busy	bin/check-project-busy.sh
bin/claim-drift	bin/claim-drift.sh
bin/closeout-lint	bin/closeout-lint.sh
bin/discipline	bin/discipline.sh
bin/notify-senechal	bin/notify-senechal.sh
bin/silence-audit	bin/silence-audit.sh
bin/etiquette	bin/etiquette.sh
bin/ausculte	bin/ausculte.sh
bin/lib/host-check.sh	bin/lib/host-check.sh
bin/lib/zaxon.sh	bin/lib/zaxon.sh
bin/lib/labels.tsv	bin/lib/labels.tsv
BUILD-DISCIPLINE.md	BUILD-DISCIPLINE.md
commands/cloture.md	.claude/commands/cloture.md
commands/ideate.md	.claude/commands/ideate.md
commands/reap.md	.claude/commands/reap.md
hooks/subagent-closeout.sh	hooks/subagent-closeout.sh
'

say()  { printf '%s\n' "$*"; }
row()  { printf '  %-9s %-26s %s\n' "$1" "$2" "${3:-}"; }

[ -d "$ROOT" ] || { printf '%s: BLIND: no such directory: %s\n' "$CLI_NAME" "$ROOT" >&2; exit 3; }

# origin/bashified FIRST, deliberately, and it is not a style choice: the
# build is cut from what is PUBLISHED, so a stale local `bashified` would make
# this guard grade a population the cutter never sees. Probed while writing
# this file -- the local ref here was 70fcad5, five carries behind origin, and
# the first draft reported "0 carried files" and exited 0.
REF=''
for c in origin/bashified bashified; do
  git -C "$ROOT" rev-parse --verify -q "$c^{commit}" >/dev/null 2>&1 && { REF="$c"; break; }
done
[ -n "$REF" ] || {
  printf '%s: BLIND: %s has no `bashified` ref, so nothing could be compared.\n' "$CLI_NAME" "$ROOT" >&2
  printf '%s: that is "I could not look", not "nothing has drifted".\n' "$CLI_NAME" >&2
  exit 3
}

# main_original <bashified-path> -- the file on main this one is a copy of, or
# nothing when it is branch-native.
main_original() {
  local b="$1" from to base
  while IFS=$'\t' read -r from to; do
    [ "$from" = "$b" ] && { printf '%s' "$to"; return 0; }
  done <<< "$(printf '%s' "$CARRIES" | grep -v '^[[:space:]]*$')"
  [ -f "$ROOT/$b" ] && { printf '%s' "$b"; return 0; }
  base="${b##*/}"
  [ -f "$ROOT/bin/retired/$base" ] && { printf '%s' "bin/retired/$base"; return 0; }
  return 1
}

ratcheted() {
  [ -f "$RATCHET" ] || return 1
  grep -qxF "pair $1 $2" "$RATCHET"
}

say "carry-drift -- what \`$REF\` carries from main, in $ROOT"
say ""
row STATUS "on $REF" "its one home on main"

findings=0; forgiven=0; matched=0
still_drifted=()

while read -r b; do
  [ -n "$b" ] || continue
  m="$(main_original "$b")" || continue          # branch-native, not a carry
  have="$(git -C "$ROOT" rev-parse "$REF:$b" 2>/dev/null)" || {
    row BLIND "$b" "cannot read the blob on $REF"; findings=$((findings + 1)); continue
  }
  want="$(git -C "$ROOT" hash-object -- "$ROOT/$m" 2>/dev/null)" || {
    row BLIND "$b" "cannot hash $m"; findings=$((findings + 1)); continue
  }
  if [ "$have" = "$want" ]; then
    row ok "$b" "$m"
    matched=$((matched + 1))
    continue
  fi
  still_drifted+=("$b	$m")
  if ratcheted "$b" "$m"; then
    row RATCHETED "$b" "$m -- drifted before this guard existed"
    forgiven=$((forgiven + 1))
  else
    row DRIFT "$b" "$m -- edited on one side only. Re-carry it: $CLI_NAME --carry <bashified checkout>"
    findings=$((findings + 1))
  fi
done < <(
  # bin/ is where carries live, but not ALL of them: BUILD-DISCIPLINE.md is
  # declared at the root, and scanning bin/ alone graded it in NEITHER loop --
  # this one never saw it, and the declared-but-absent loop below skips
  # anything that exists. A drifted root-level carry was silently clean.
  {
    git -C "$ROOT" ls-tree -r --name-only "$REF" -- bin/ 2>/dev/null
    printf '%s' "$CARRIES" | grep -v '^[[:space:]]*$' | cut -f1
  } | sort -u
)

# --- declared, but not there at all -----------------------------------------
while IFS=$'\t' read -r b m; do
  [ -n "$b" ] || continue
  git -C "$ROOT" rev-parse --verify -q "$REF:$b" >/dev/null 2>&1 && continue
  if [ ! -f "$ROOT/$m" ]; then
    row BLIND "$b" "declared as carried from $m, which is not in this tree either"
    findings=$((findings + 1)); continue
  fi
  still_drifted+=("$b	$m")
  if ratcheted "$b" "$m"; then
    row RATCHETED "$b" "$m -- declared, absent, forgiven"
    forgiven=$((forgiven + 1))
  else
    row MISSING "$b" "$m is declared as carried and is NOT on $REF. Nothing ships it: $CLI_NAME --carry <bashified checkout>"
    findings=$((findings + 1))
  fi
done <<< "$(printf '%s' "$CARRIES" | grep -v '^[[:space:]]*$')"

# --- --carry: write the replica. Never commits: a carry is a change to a -----
# --- deploy branch and wants the same review as any other. -------------------
if [ -n "$CARRY_TO" ]; then
  say ""
  say "-- carry (writing into $CARRY_TO; nothing is committed) --------------"
  [ -d "$CARRY_TO" ] || { printf '%s: no such directory: %s\n' "$CLI_NAME" "$CARRY_TO" >&2; exit 2; }
  skipped=0
  for pair in ${still_drifted[@]+"${still_drifted[@]}"}; do
    b="${pair%%	*}"; m="${pair##*	}"
    # A ratcheted pair is FORGIVEN, not pending. Carrying it here would smuggle
    # a reviewed change (what 13 accounts enforce) into a run whose stated job
    # is the unforgiven rows. Point --ratchet at an empty file to include them.
    if ratcheted "$b" "$m"; then skipped=$((skipped + 1)); continue; fi
    # A path with no slash (BUILD-DISCIPLINE.md) would make ${b%/*} the FILE
    # NAME, so this created a directory of that name and cp wrote inside it.
    # The carry then reported success and shipped nothing at the declared
    # path. Witness: carry-drift.sh --carry <dir> && ls -ld <dir>/*.md
    case "$b" in */*) mkdir -p "$CARRY_TO/${b%/*}" ;; esac
    cp -p -- "$ROOT/$m" "$CARRY_TO/$b" && say "  carried  $m -> $CARRY_TO/$b"
  done
  [ "$skipped" -gt 0 ] && say "  $skipped ratcheted pair(s) left alone -- forgiven, and their re-carry is its own review."
  say "  Review the diff, then commit on \`bashified\`. Re-run this to confirm."
fi

# --- --accept: the ratchet only ever loses rows ------------------------------
if [ "$ACCEPT" -eq 1 ]; then
  [ -f "$RATCHET" ] || { printf '%s: no ratchet at %s\n' "$CLI_NAME" "$RATCHET" >&2; exit 2; }
  keep="$(mktemp)" || exit 2
  dropped=0
  while IFS= read -r line; do
    case "$line" in
      'pair '*)
        set -- $line
        if printf '%s\n' ${still_drifted[@]+"${still_drifted[@]}"} | grep -qxF "$2	$3"; then
          printf '%s\n' "$line" >> "$keep"
        else
          dropped=$((dropped + 1))
        fi ;;
      *) printf '%s\n' "$line" >> "$keep" ;;
    esac
  done < "$RATCHET"
  mv -- "$keep" "$RATCHET"
  say ""
  say "-- accept: dropped $dropped row(s) that now match. Rows are never added here."
fi

say ""
say "  $matched carried file(s) match, $forgiven ratcheted, $findings finding(s)."
if [ "$findings" -eq 0 ]; then
  say "OK -- every carried file is a replica of its one home on main."
else
  say "A carried copy has been edited away from main, or main moved and the carry did not."
  say "Either way there are now two answers to one question. --carry writes the replica."
fi
exit $(( findings > 0 ? 1 : 0 ))
