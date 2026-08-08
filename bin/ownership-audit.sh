#!/usr/bin/env bash
# ownership-audit.sh -- how much of realisateur is not realisateur's?
#
# GUARD: what fraction of this repo's mechanism serves another project's mission?
# RUNNER: bin/tests/ownership-audit.test.sh
# GUARD-TEST: bin/tests/ownership-audit.test.sh
# GATE: strict --repo $TREE
# VERIFIED: 2026-08-08 via bash bin/ownership-audit.sh --strict (21272 of 25912 lines foreign = 82.0%, 0 unclassified, exit 3) and bash bin/tests/ownership-audit.test.sh
#
# ---------------------------------------------------------------------------
# THE QUESTION, AND THE ORDER IT HAS TO BE ASKED IN
#
# The conclusion people reach for is "realisateur should not self-dev". That
# is downstream. The premise underneath it is that most of what this repo
# holds belongs to other projects -- and if the premise is true, the
# maintenance question dissolves rather than being answered: you do not need a
# worker for mechanism you should not own.
#
# So this measures the premise, not the conclusion. It counts lines of
# mechanism, attributes each to a project by the mission test in
# bin/lib/ownership-set.sh, and reports the fraction that is somebody else's.
#
# ---------------------------------------------------------------------------
# WHY A RATCHET AND NOT A CONFORMANCE TEST
#
# Same argument bin/thermostat-wiring.sh makes, and for the same reason it was
# made there: a check that is red on day one and red for months is a document
# with an exit code, and this estate has already priced what a permanently-red
# check costs (seven suites red long enough that red stopped meaning anything;
# see pivot.sh's `ci` MOVE).
#
# A cross-repo migration is slow, needs a human at several steps, and breaks
# live paths if rushed -- install-shims.sh writes the PATH shims this estate
# runs on today. Demanding zero foreign lines by the next build would just get
# the check disabled.
#
# The assertion is therefore: THE FOREIGN SURFACE IS NO LARGER THAN THE LAST
# TIME SOMEONE LOOKED. A pull request that parks another project's mechanism
# here is a failing build. A pull request that moves some out lowers the bar
# permanently, because --accept only ever ratchets down.
#
# ---------------------------------------------------------------------------
# THE TWO DODGES IT CLOSES, AND HOW
#
# 1. ADD A FILE AND DON'T MENTION IT. The population is derived from the tree
#    (git ls-files over OWN_AREAS), never from a list. An unmatched file is
#    UNCLASSIFIED, and the bound on unclassified is zero. A list is an opt-in,
#    and the omission is the dodge -- propagation.test.sh's reasoning, reused.
#
# 2. RECLASSIFY A FOREIGN FILE AS MINE. Cheaper than moving it and it lowers
#    the number. So the ratchet records the foreign file NAMES, not just the
#    count: a path that was foreign may leave the tree (that is a migration,
#    and it is what we want), but it may not stay in the tree and become
#    realisateur's. That is R4 below, and it fails as a regression.
#
# ---------------------------------------------------------------------------
# WHAT IT DELIBERATELY DOES NOT MEASURE
#
# Prose. Root *.md and *.idea are 88% of this repo's bytes and none of it is
# mechanism; bin/markdown-cost.sh already prices prose and this would only
# produce a second answer to a question that already has one. The claim here
# is about MECHANISM ownership, and mixing the two would let a documentation
# commit move a number that is supposed to be about code.
#
# It also does not know whether the receiving project WANTS the file. It
# checks only that the receiver exists and is named. Whether senechal accepts
# install-shims.sh is a conversation, not a measurement, and pretending
# otherwise would be the "belongs elsewhere" complaint this repo's own
# doctrine rejects.
#
# usage:  ownership-audit.sh [--repo DIR] [--strict] [--accept] [--quiet]
# exit:   0 no regression against the ratchet
#         1 REGRESSION -- the foreign surface grew, or one was reclassified
#         2 BLIND -- could not read a tree or a ledger. NEVER "all clear"
#         3 --strict and foreign mechanism remains (but nothing regressed)
set -uo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
RATCHET="$ROOT/bin/ownership-audit.ratchet"

CLI_NAME='ownership-audit.sh'
CLI_SUMMARY='how much of this repo is another project'"'"'s mechanism, and has that grown?'
CLI_USAGE='  ownership-audit.sh              measure, report, fail only on regression
  ownership-audit.sh --strict     also fail while any foreign mechanism remains
  ownership-audit.sh --accept     record today'"'"'s surface as the new bar
  ownership-audit.sh --repo DIR   audit DIR instead of the current directory'
CLI_FLAGS='--strict --accept --quiet --repo'
CLI_EXITS='  0  no regression
  1  REGRESSION -- foreign surface grew, or a foreign file was reclassified mine
  2  BLIND -- no tree or no ledger to read. NEVER "all clear"
  3  --strict, and foreign mechanism remains (but nothing regressed)'
CLI_POSITIONAL='a directory (the value of --repo)'
. "$ROOT/bin/lib/cli-guard.sh"
cli_guard "$@"

STRICT=0; ACCEPT=0; QUIET=0; TREE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --strict) STRICT=1 ;;
    --accept) ACCEPT=1 ;;
    --quiet)  QUIET=1 ;;
    --repo)   shift; TREE="${1:-}" ;;
    *) : ;;
  esac
  shift
done
TREE="${TREE:-$PWD}"

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

# BLIND is printed FIRST and on its own, before any finding, and it is never
# exit 0. closeout-lint printed "13 worktrees NOT examined" one line above
# twelve false alarms and exited 0; that is the shape this avoids.
blind() { printf 'BLIND: %s\n' "$*"; printf 'ownership-audit: nothing was measured. This is NOT a clean result.\n'; exit 2; }

[ -d "$TREE/.git" ] || [ -f "$TREE/.git" ] || blind "no git repository at the tree given (--repo), so no population can be derived"
LEDGER="$TREE/bin/lib/ownership-set.sh"
[ -r "$LEDGER" ] || blind "the tree given carries no bin/lib/ownership-set.sh, so nothing can be attributed to an owner"

# shellcheck source=/dev/null
. "$LEDGER" || blind "bin/lib/ownership-set.sh could not be sourced"

# --- derive the population from the tree ------------------------------------
FILES="$(git -C "$TREE" ls-files -- $OWN_AREAS 2>/dev/null)" || blind "git ls-files failed in the tree given"
[ -n "$FILES" ] || blind "the tree given has no files under any of the declared areas ($(echo $OWN_AREAS | tr '\n' ' '))"

total=0; mine=0; foreign=0; nforeign=0; nmine=0
unclassified=""
foreign_list=""
mine_list=""
recv_names=""; recv_lines=""

add_recv() {
  local name="$1" n="$2" i=0 out_n="" out_l="" found=0
  set -- $recv_names
  for r in "$@"; do
    i=$((i+1))
    local cur; cur="$(echo $recv_lines | cut -d' ' -f$i)"
    if [ "$r" = "$name" ]; then cur=$((cur + n)); found=1; fi
    out_n="$out_n $r"; out_l="$out_l $cur"
  done
  if [ "$found" -eq 0 ]; then out_n="$out_n $name"; out_l="$out_l $n"; fi
  recv_names="$out_n"; recv_lines="$out_l"
}

while IFS= read -r f; do
  [ -n "$f" ] || continue
  [ -f "$TREE/$f" ] || continue
  n="$(wc -l < "$TREE/$f" 2>/dev/null)" || n=0
  n="${n// /}"
  total=$((total + n))
  if ! row="$(own_owner "$f")"; then
    unclassified="$unclassified $f"
    continue
  fi
  owner="${row%% *}"
  if [ "$owner" = "realisateur" ]; then
    mine=$((mine + n)); nmine=$((nmine + 1)); mine_list="$mine_list $f"
  else
    foreign=$((foreign + n)); nforeign=$((nforeign + 1))
    foreign_list="$foreign_list $f"
    add_recv "$owner" "$n"
    own_is_receiver "$owner" || say "FLAG [receiver] $f names owner '$owner', which is not declared in OWN_RECEIVERS"
  fi
done <<EOF
$FILES
EOF

[ "$total" -gt 0 ] || blind "every file in the declared areas measured zero lines"

# Per mille, not per cent: a 0.4-point improvement is a real migration and
# should be visible in the bar rather than rounded into invisibility.
share=$(( foreign * 1000 / total ))

# --- report ------------------------------------------------------------------
say "== OWNERSHIP OF MECHANISM =================================================="
say ""
say "  areas measured : $(echo $OWN_AREAS | tr '\n' ' ')"
say "  total          : $total lines"
say "  realisateur's  : $mine lines  ($nmine files)"
say "  another's      : $foreign lines  ($nforeign files)"
say ""
say "  >>> FOREIGN SHARE: $((share / 10)).$((share % 10))% of this repo's mechanism is not realisateur's."
say ""
say "  by receiver:"
i=0
set -- $recv_names
for r in "$@"; do
  i=$((i+1))
  l="$(echo $recv_lines | cut -d' ' -f$i)"
  homeless=""
  case " $OWN_HOMELESS " in *" $r "*) homeless="   <- NO REPO EXISTS TO RECEIVE THIS" ;; esac
  say "$(printf '    %-16s %6d lines%s' "$r" "$l" "$homeless")"
done
say ""

findings=0

# --- R3: unclassified is a hard zero ----------------------------------------
if [ -n "$unclassified" ]; then
  for u in $unclassified; do
    say "FLAG [unclassified] $u has no row in bin/lib/ownership-set.sh -- nobody has said whose it is"
    findings=$((findings + 1))
  done
fi

# --- the ratchet -------------------------------------------------------------
r_lines=""; r_share=""; r_files=""
if [ -r "$RATCHET" ]; then
  while read -r k v; do
    case "$k" in
      foreignlines) r_lines="$v" ;;
      foreignshare) r_share="$v" ;;
      file)         r_files="$r_files $v" ;;
    esac
  done < "$RATCHET"
fi

regression=0
if [ -n "$r_lines" ]; then
  if [ "$foreign" -gt "$r_lines" ]; then
    say "FLAG [regression] foreign mechanism GREW: $foreign lines, bar is $r_lines. Something belonging to another project was parked here."
    regression=1; findings=$((findings + 1))
  fi
  if [ "$share" -gt "$r_share" ]; then
    say "FLAG [regression] foreign SHARE grew: $((share/10)).$((share%10))%, bar is $((r_share/10)).$((r_share%10))%"
    regression=1; findings=$((findings + 1))
  fi
  # R4 -- the reclassification dodge. A path recorded foreign may LEAVE (that
  # is the migration this whole guard is for). It may not stay and become
  # realisateur's.
  for p in $r_files; do
    [ -f "$TREE/$p" ] || continue
    if row="$(own_owner "$p")"; then
      o="${row%% *}"
      if [ "$o" = "realisateur" ]; then
        say "FLAG [reclassified] $p was recorded as another project's and is now declared realisateur's, without leaving the tree. Moving a row is not moving a file."
        regression=1; findings=$((findings + 1))
      fi
    fi
  done
  say "  ratchet: bar is $r_lines lines / $((r_share/10)).$((r_share%10))%  (today: $foreign / $((share/10)).$((share%10))%)"
else
  say "  ratchet: none recorded yet -- run --accept to set the bar"
fi

say ""
say "ownership-audit: $findings finding(s); $nforeign foreign file(s) remain"

# --- accept ------------------------------------------------------------------
if [ "$ACCEPT" -eq 1 ]; then
  if [ "$regression" -eq 1 ]; then
    say "REFUSED: --accept never lowers the bar. Fix the regression first."
    exit 1
  fi
  if [ -n "$unclassified" ]; then
    say "REFUSED: --accept with unclassified files would record a number that is missing some of the tree."
    exit 1
  fi
  {
    printf '# ownership-audit.ratchet -- the foreign surface when last accepted.\n'
    printf '# Lowered by --accept, never raised by any flag. See bin/ownership-audit.sh.\n'
    printf '# accepted %s\n' "$(date -Is)"
    printf 'foreignlines %s\n' "$foreign"
    printf 'foreignshare %s\n' "$share"
    for p in $foreign_list; do printf 'file %s\n' "$p"; done
  } > "$RATCHET"
  say "accepted: $foreign lines / $((share/10)).$((share%10))% / $nforeign files recorded"
  exit 0
fi

[ "$regression" -eq 1 ] && exit 1
[ -n "$unclassified" ] && exit 1
if [ "$STRICT" -eq 1 ] && [ "$foreign" -gt 0 ]; then exit 3; fi
exit 0
