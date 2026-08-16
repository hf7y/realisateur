#!/usr/bin/env bash
# carry-drift.sh -- a file carried onto `bashified` is a REPLICA of the one on
# `main`, byte for byte, or it is a second copy of the same fact.
#
# GUARD: does every file the bashified branch carries still match its original?
# RUNNER: .github/workflows/tests.yml -- job carry-drift, against origin/bashified
# GUARD-TEST: bin/tests/carry-drift.test.sh
# GATE: default --repo $TREE
# VERIFIED: 2026-08-16 via bash bin/carry-drift.sh (3 ok, 5 ratcheted, 0 findings) and its suite
#
# WHY IT EXISTS
# -------------
# The verb build is cut from each project's `bashified` branch, so anything an
# account must be able to run without a checkout has to be ON that branch. For
# realisateur that means a handful of files exist twice: once on `main`, where
# they are edited, and once on `bashified`, where they ship.
#
# Nothing compared them. Measured 2026-08-16, the first time anything did:
#
#   bin/closeout-lint.sh       572 lines carried vs 613 on main
#   bin/precipitation-scan.sh  395 vs 393
#   bin/reach-lint.sh          253 vs 251
#   bin/lib/conf.sh             85 vs  89
#   bin/hygiene-lint.sh        differs
#   bin/lib/cli-guard.sh       identical -- one of six
#
# None of the drift is deliberate: the carried copies are simply older, and
# they carry paragraphs `main` has since corrected -- conf.sh's copy still
# describes restamp-discipline.sh in the present tense two days after it was
# retired. An account running the carried lint is running last month's rules
# and nothing anywhere says so.
#
# Zach, 2026-08-16, deciding hf7y/realisateur#330: "it cannot be several
# copies, one per repo that will drift inevitably; this needs to be one single,
# stable location where policy changes automatically reach." One home is
# `main`. This makes every other copy mechanical: `--carry` writes them, and
# the comparison below is what stops one being edited in place.
#
# WHAT IS NOT A CARRY. A file that exists only on `bashified` -- bin/arpente,
# man/*, lib/verb.sh, the branch's own tests -- is branch-native and is not
# graded. The pairing is DERIVED (same path under bin/, else bin/retired/),
# so a new carry is guarded the day it lands with nothing to remember to add.
#
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
# `bin/gh` is also the one pair that could not be derived even if it were
# present: it must be named `gh` to shadow the real binary on PATH, and `main`
# cannot call it that without shadowing gh for everyone editing this repo.
CARRIES='
bin/gh	bin/gh-sign.sh
bin/lib/body-grammar.sh	bin/lib/body-grammar.sh
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
done < <(git -C "$ROOT" ls-tree -r --name-only "$REF" -- bin/ 2>/dev/null)

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
    mkdir -p "$CARRY_TO/${b%/*}"
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
