#!/usr/bin/env bash
# ownership-audit.sh -- how much of realisateur is not realisateur's?
#
# RUNNER: bin/tests/ownership-audit.test.sh
# GUARD-TEST: bin/tests/ownership-audit.test.sh
# GATE: strict --repo $TREE
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
# The assertion is therefore: THE FOREIGN FOOTPRINT IS NO LARGER THAN THE LAST
# TIME SOMEONE LOOKED. A pull request that parks another project's mechanism
# here is a failing build. A pull request that moves some out lowers the bar
# permanently, because --accept only ever ratchets down.
#
# FOOTPRINT, NOT LINE COUNT, AND WHY THAT CHANGED (2026-08-11, #144)
#
# It used to be the line count, and the line count could not tell the two
# things below apart:
#
#     PARKING       another project's mechanism arrives here. New maintenance,
#                   new migration unit, exactly what this guard is for.
#     MAINTENANCE   a foreign file ALREADY HERE gets repaired, documented or
#                   tested. No new maintenance -- this repo already carries it
#                   and carries the bug with it.
#
# 74% of this repo's mechanism is foreign, so the second is not a corner case;
# it is most of the maintenance this repo can be asked to do. Measured on
# #144: the ratchet stood 12 lines above HEAD, and a pull request fixing two
# silently-discarded failures in two foreign scripts already recorded here
# came to +533 foreign lines and was arithmetically unmergeable. --accept
# could not resolve it either, by design.
#
# And the count was not merely blocking the wrong thing, it was MISSING the
# right thing: park a new 30-line foreign file while deleting 40 lines
# somewhere else and the total goes DOWN. The guard's own headline case walked
# straight through it, silently, whenever the arithmetic happened to net out.
#
# So the bar moved onto the population the ratchet already records -- the FILE
# LIST. A foreign path not in that list is PARKED and fails (R5). Growth
# inside a path already in it is maintenance: reported, every run, by name,
# and not a failure. See "WHAT STILL NOTICES" below -- the answer must not be
# "nothing", or this would be a guard that cannot refuse.
#
# ---------------------------------------------------------------------------
# THE THREE DODGES IT CLOSES, AND HOW
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
# 3. MENTION IT, CLASSIFY IT HONESTLY, AND PARK IT ANYWAY. Dodge 1 only makes
#    a new foreign file DECLARED; declaring it was never the same as being
#    allowed to add it. R5 is the bound: a foreign path that is not in the
#    ratchet's file list fails, whatever the arithmetic says.
#
# ---------------------------------------------------------------------------
# WHEN A NEW PATH IS NOT A NEW FOOTPRINT
#
# A file can be new to the tree and still not be new maintenance, when it
# would LEAVE WITH a file already recorded -- the migration this guard exists
# to keep possible carries it out in the same act. Two such relations, both
# derived, neither a hand-kept exemption list:
#
#   FOLLOWS   the ledger did not classify it directly; it took its owner from
#             another file (bin/lib/ownership-set.sh's "a suite follows its
#             subject"), and that file is recorded foreign. A test for a
#             foreign script already here is coverage of maintenance this repo
#             already owns, and refusing it would mean "you may not test the
#             foreign mechanism you are stuck with".
#
#   READ BY   a recorded foreign file OF THE SAME OWNER names it as a path.
#             The reference must carry the last two path components, not the
#             bare basename: `lib/not-a-verb.tsv` is a path, `README.md` is a
#             coincidence. Same-owner, because a file goes to ONE repo when
#             its reader does.
#
# Neither is silent. Every such path is printed, with its line count and with
# the recorded file it claims to follow, so a false attachment is on the page
# rather than inside the arithmetic.
#
# ---------------------------------------------------------------------------
# WHAT STILL NOTICES, NOW THAT GROWTH IS PERMITTED
#
# Unbounded growth inside recorded files is a real way to accrete foreign
# mechanism one line at a time, so this is the list, and it is not empty:
#
#   THE SHARE BAR, which is unchanged and still hard. Foreign lines may grow
#   but the foreign FRACTION may not. Right after an --accept that bound is
#   tight: any foreign growth not matched by realisateur growth fails. (Today
#   it is loose -- 73.6% measured against 79.7% recorded, because the
#   2026-08-08 migration was never banked. Slack in a bar is un-accepted
#   improvement, and banking it is a human running --accept, not this script
#   deciding for them.)
#
#   THE REPORT. Growth is printed as NOTE lines every run, decomposed into
#   what grew inside recorded paths and what arrived in new ones, and
#   bin/tests/ownership-audit.test.sh's witness section prints them into CI.
#
#   --strict, unchanged: exit 3 while any foreign mechanism remains at all.
#
#   AND THE NEXT --accept, which is where a human looks at the notes and
#   decides. It cannot launder anything: a parked path or a reclassification
#   is a regression and --accept refuses on a regression, so the recorded
#   file list can only gain paths that follow one already in it, and the
#   recorded SHARE can only go down.
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
# exit:   0 no regression against the ratchet (growth inside recorded paths is
#           reported as NOTE lines and is not a regression)
#         1 REGRESSION -- a foreign path was parked here, the foreign share
#           grew, or a recorded foreign file was reclassified realisateur's
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
CLI_EXITS='  0  no regression (growth inside recorded paths is a NOTE, not a finding)
  1  REGRESSION -- a foreign path was PARKED here, the foreign share grew, or
     a recorded foreign file was reclassified mine
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

# --- the ratchet, read BEFORE the population ---------------------------------
# It used to be read after, because it was only ever compared against the
# finished totals. It is now the thing that says which paths are already
# recorded, so each file has to be able to ask about itself as it is counted.
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

# --- derive the population from the tree ------------------------------------
FILES="$(git -C "$TREE" ls-files -- $OWN_AREAS 2>/dev/null)" || blind "git ls-files failed in the tree given"
[ -n "$FILES" ] || blind "the tree given has no files under any of the declared areas ($(echo $OWN_AREAS | tr '\n' ' '))"

total=0; mine=0; foreign=0; nforeign=0; nmine=0
unclassified=""
foreign_list=""
mine_list=""
recv_names=""; recv_lines=""
# rec_now  lines held TODAY by paths the ratchet already records
# rec_pairs "<owner>|<path>" for each of those, so the READ BY test below can
#           ask only same-owner recorded files without re-deriving an owner
# new_rows  "<path>|<lines>|<owner>" for each foreign path the ratchet does not
#           record. `|` is safe: git does not track a path containing one here,
#           and an owner is a single bare word by the ledger's own format.
rec_now=0; rec_pairs=""; new_rows=""

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
  # A .ratchet is a RECORD, not mechanism, and this one is a record of its own
  # measurement: it holds one line per foreign file, so counting it makes the
  # total a function of the answer. Measured while writing this: --accept
  # recorded 79.7% and the next run of the same tree reported 79.3%, purely
  # because the file had grown by 140 lines between the two. A number that
  # moves when nothing moved is not a measurement.
  case "$f" in *.ratchet) continue ;; esac
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
    case " $r_files " in
      *" $f "*) rec_now=$((rec_now + n)); rec_pairs="$rec_pairs $owner|$f" ;;
      *)        new_rows="$new_rows $f|$n|$owner" ;;
    esac
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

# --- does a new foreign path FOLLOW one already recorded? --------------------
# Prints the recorded path it follows and returns 0; returns 1 when nothing
# does, which is what makes it PARKED. See "WHEN A NEW PATH IS NOT A NEW
# FOOTPRINT" in the header for why these two relations and not a list.
follows_recorded() {
  local p="$1" o="$2" sub base pathref pair rp
  # FOLLOWS -- asked of the ledger, which owns the rule. A ledger too old to
  # answer simply does not grant this relation; inventing a second copy of the
  # derivation here is how the two answers would drift apart.
  if command -v own_derived_from >/dev/null 2>&1; then
    if sub="$(own_derived_from "$p")" && [ -n "$sub" ]; then
      case " $r_files " in *" $sub "*) printf 'follows %s\n' "$sub"; return 0 ;; esac
    fi
  fi
  # READ BY -- the last two path components, so that a reference is a path and
  # not a word that happens to collide.
  base="${p##*/}"
  pathref="${p%/*}"
  if [ "$pathref" != "$p" ]; then pathref="${pathref##*/}/$base"; else pathref="$base"; fi
  for pair in $rec_pairs; do
    [ "${pair%%|*}" = "$o" ] || continue
    rp="${pair#*|}"
    if grep -qF -- "$pathref" "$TREE/$rp" 2>/dev/null; then
      printf 'read by %s\n' "$rp"; return 0
    fi
  done
  return 1
}

regression=0
notes=0
if [ -n "$r_lines" ]; then
  # R5 -- THE FOOTPRINT. A foreign path the ratchet does not record is parked
  # here unless it follows one that it does. This is the assertion the line
  # count used to stand in for, and it is both stricter (a parked file is
  # caught even when the arithmetic nets out downwards) and narrower (it says
  # nothing about a recorded file getting longer).
  new_lines=0; att_lines=0; natt=0
  for row in $new_rows; do
    p="${row%%|*}"; rest="${row#*|}"; n="${rest%%|*}"; o="${rest##*|}"
    if rel="$(follows_recorded "$p" "$o")"; then
      att_lines=$((att_lines + n)); natt=$((natt + 1))
      say "  NOTE [new path] $p ($n lines, $o) is not in the ratchet, and $rel, which is. It leaves with it, so it is not a new footprint."
      notes=$((notes + 1))
    else
      new_lines=$((new_lines + n))
      say "FLAG [parked] $p ($n lines) is $o's mechanism and is NOT in the ratchet's file list; no recorded file of $o's reads it and it is no recorded file's suite. Something belonging to another project was parked here."
      regression=1; findings=$((findings + 1))
    fi
  done

  if [ "$share" -gt "$r_share" ]; then
    say "FLAG [regression] foreign SHARE grew: $((share/10)).$((share%10))%, bar is $((r_share/10)).$((r_share%10))%"
    regression=1; findings=$((findings + 1))
  fi
  # R4 -- the reclassification dodge. A path recorded foreign may LEAVE (that
  # is the migration this whole guard is for). It may not stay and become
  # realisateur's.
  gone=0; nrec=0
  for p in $r_files; do
    nrec=$((nrec + 1))
    if [ ! -f "$TREE/$p" ]; then gone=$((gone + 1)); continue; fi
    if row="$(own_owner "$p")"; then
      o="${row%% *}"
      if [ "$o" = "realisateur" ]; then
        say "FLAG [reclassified] $p was recorded as another project's and is now declared realisateur's, without leaving the tree. Moving a row is not moving a file."
        regression=1; findings=$((findings + 1))
      fi
    fi
  done

  # Growth is a NOTE, not a finding -- but it is never silent, and it is
  # decomposed, because "+533 lines" and "+533 lines in a file that was
  # already here" are different facts about the same number.
  if [ "$foreign" -gt "$r_lines" ]; then
    say "  NOTE [growth] the foreign surface is $foreign lines, $((foreign - r_lines)) above the $r_lines recorded. Not a regression: every line of it is inside a path this ratchet records, or in a new path that follows one."
    notes=$((notes + 1))
  fi
  say "  recorded paths hold $rec_now lines today (recorded at $r_lines across $nrec path(s), $gone of which have since left the tree)"
  [ "$natt" -gt 0 ] && say "  new paths that follow a recorded one: $att_lines lines in $natt file(s)"
  [ "$new_lines" -gt 0 ] && say "  PARKED: $new_lines lines in paths nothing here accounts for"
  say "  ratchet: share bar is $((r_share/10)).$((r_share%10))% (today $((share/10)).$((share%10))%); line baseline $r_lines (today $foreign)"
else
  say "  ratchet: none recorded yet -- run --accept to set the bar"
fi

say ""
say "ownership-audit: $findings finding(s), $notes note(s); $nforeign foreign file(s) remain"

# --- accept ------------------------------------------------------------------
if [ "$ACCEPT" -eq 1 ]; then
  # WHAT --accept CAN AND CANNOT DO, since growth is now permitted and the
  # recorded LINE COUNT can therefore go up. The bars are the other two, and
  # neither can be worsened by accepting: the share can only fall, because a
  # risen share is a regression and this refuses on a regression; and the file
  # list can only gain a path that FOLLOWS one already in it, because a parked
  # path is a regression too. The line count is a baseline to measure growth
  # from, not a bar -- see the header.
  if [ "$regression" -eq 1 ]; then
    say "REFUSED: --accept does not record a parked path, a risen share or a reclassification as the new normal. Fix the regression first."
    exit 1
  fi
  if [ -n "$unclassified" ]; then
    say "REFUSED: --accept with unclassified files would record a number that is missing some of the tree."
    exit 1
  fi
  {
    printf '# ownership-audit.ratchet -- the foreign surface when last accepted.\n'
    printf '# The SHARE and the FILE LIST are bars and --accept only ever improves\n'
    printf '# them; the line count is the baseline growth is measured from.\n'
    printf '# See bin/ownership-audit.sh.\n'
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
