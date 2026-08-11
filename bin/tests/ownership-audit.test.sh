#!/usr/bin/env bash
# ownership-audit.test.sh -- the suite for bin/ownership-audit.sh.
#
# HERMETICITY: every assertion about behaviour runs the guard against a
# FABRICATED tree built under mktemp -- its own git repo, its own
# bin/lib/ownership-set.sh, its own areas, its own ratchet copied in. The
# guard is pointed at it with --repo, and nothing it reports may name this
# repository. Two assertions deliberately read the LIVE tree (the ratchet
# baseline is honest, and the strict run still fails); they are marked WITNESS
# and they only read -- they never write, and they never run --accept.
#
# WHY A FABRICATED TREE AND NOT THIS ONE. The number this guard produces is
# supposed to change as mechanism migrates out. A suite that asserted "the
# share is 82.0%" would go red the first time somebody did the right thing,
# and the fix would be to edit the test -- which is the move BUILD-DISCIPLINE
# exists to prevent. So the suite asserts the guard's PROPERTIES (it derives
# from the tree, it refuses to lower the bar, it catches the reclassification
# dodge, it never grades blind as clean) and asserts about the live tree only
# things that must stay true at any share: the ratchet is not stale, and while
# any foreign mechanism remains --strict does not exit 0.
#
# IT IS WATCHED REFUSING AND WATCHED PERMITTING, which after #144 is half the
# file. A guard that only ever refuses is easy to write and worthless -- and a
# guard that stops refusing is worse than none, which is the standing argument
# in bin/tests/guard-estate.test.sh. So sections 2, 2b, 3, 4 and 6b watch it
# refuse (a parked path, a parked path paid for with a deletion elsewhere, a
# reclassification, an undone migration, an unread new file), and 5 and 6
# watch it permit (a repair inside a recorded path, a suite for a recorded
# script, a table a recorded script reads) -- with 6b differing from 6 by one
# line of reference, so "attached" is a test and not a word.
#
# usage: ./bin/tests/ownership-audit.test.sh   (exit 0 = all pass)
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AUD="$REPO/bin/ownership-audit.sh"

pass=0; fail=0
ok()  { printf '  ok   %s\n' "$*"; pass=$((pass+1)); }
bad() { printf '  FAIL %s\n' "$*"; fail=$((fail+1)); }
rc_is() { if [ "$2" = "$3" ]; then ok "$1 (rc=$3)"; else bad "$1: expected rc $2, got $3"; fi; }
has()   { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1: output did not contain '$3'" ;; esac; }
hasnt() { case "$2" in *"$3"*) bad "$1: output contained '$3' and should not have" ;; *) ok "$1" ;; esac; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- a fabricated estate ----------------------------------------------------
# Three files: one mine, one another project's, one nobody has classified.
# 10 lines / 40 lines / 5 lines, so every count below is checkable by hand.
#
# The ledger written below is a FABRICATION, not a copy, and that is the point
# (see HERMETICITY). It restates two rules from bin/lib/ownership-set.sh --
# longest-prefix lookup, and `own_derived_from`'s "a suite follows its
# subject" -- because a lookup that behaves differently from the real one
# would make every assertion here a claim about the fixture. If those two
# rules change shape in the real ledger, this fixture is the thing that has to
# change with them; nothing else in the suite hardcodes an owner.
mk_tree() {
  local t="$1"
  rm -rf "$t"; mkdir -p "$t/bin/lib" "$t/bin/tests"
  ( cd "$t" && git init -q -b main . && git config user.email t@t && git config user.name t ) >/dev/null 2>&1
  seq 1 10 > "$t/bin/mine-scan.sh"
  seq 1 40 > "$t/bin/theirs-install.sh"
  seq 1 5  > "$t/bin/nobodys.sh"
  cat > "$t/bin/lib/ownership-set.sh" <<'LEDGER'
OWN_RECEIVERS="
scheduler   hf7y/scheduler exists
"
OWN_HOMELESS=""
OWN_AREAS="
bin
"
OWN_MINE="
bin/mine-scan.sh   realisateur a sense
bin/lib            realisateur the ledger itself
"
OWN_THEIRS="
bin/theirs-install.sh  scheduler an effector
"
own_derived_from() {
  local p="$1" b cand
  case "$p" in
    bin/tests/*) : ;;
    *) return 1 ;;
  esac
  b="${p#bin/tests/}"
  b="${b%.test.sh}"; b="${b%-test.sh}"; b="${b%.sh}"
  for cand in "bin/$b.sh" "bin/lib/$b.sh" "bin/lib/$b-set.sh"; do
    [ "$cand" = "$p" ] && continue
    if own_owner "$cand" >/dev/null 2>&1; then printf '%s\n' "$cand"; return 0; fi
  done
  return 1
}
own_owner() {
  local p="$1" best="" bestlen=0 pre owner rest sub
  if sub="$(own_derived_from "$p")"; then own_owner "$sub"; return 0; fi
  while read -r pre owner rest; do
    [ -n "$pre" ] || continue
    case "$p" in
      "$pre"|"$pre"/*)
        if [ "${#pre}" -gt "$bestlen" ]; then bestlen=${#pre}; best="$owner $rest"; fi ;;
    esac
  done <<EOF
$OWN_MINE
$OWN_THEIRS
EOF
  [ -n "$best" ] || return 1
  printf '%s\n' "$best"
}
own_is_receiver() {
  local r rest
  while read -r r rest; do
    [ -n "$r" ] || continue
    [ "$r" = "$1" ] && return 0
  done <<EOF
$OWN_RECEIVERS
EOF
  return 1
}
LEDGER
  ( cd "$t" && git add -A && git commit -qm init ) >/dev/null 2>&1
}

# The guard writes its ratchet next to ITSELF, not next to the tree. So a test
# that exercises --accept has to work on a copy of the script, or it would
# rewrite the live baseline -- which would be a suite quietly lowering the bar
# it exists to protect.
mk_guard() {
  local d="$1"
  mkdir -p "$d/bin/lib"
  cp "$AUD" "$d/bin/ownership-audit.sh"
  cp "$REPO/bin/lib/cli-guard.sh" "$d/bin/lib/cli-guard.sh"
  printf '%s\n' "$d/bin/ownership-audit.sh"
}

echo "== 1. THE POPULATION COMES FROM THE TREE, NOT FROM A LIST =================="
T="$WORK/t1"; mk_tree "$T"
G="$(mk_guard "$WORK/g1")"
OUT="$(bash "$G" --repo "$T" 2>&1)"; RC=$?
# The fabricated ledger is itself a file in the tree and is itself classified
# (bin/lib -> realisateur), so the expected counts are derived from it rather
# than hardcoded. Hardcoding them would make this suite fail whenever the
# fixture ledger gained a line, which is a test asserting its own fixture.
L="$(wc -l < "$T/bin/lib/ownership-set.sh")"
has "counts the whole tree" "$OUT" "total          : $((55 + L)) lines"
has "attributes the sense to realisateur" "$OUT" "realisateur's  : $((10 + L)) lines"
has "attributes the effector to its receiver" "$OUT" "another's      : 40 lines"
has "reports a share" "$OUT" "FOREIGN SHARE:"
has "names the receiver" "$OUT" "scheduler"
has "an unlisted file is a finding, not an omission" "$OUT" "FLAG [unclassified] bin/nobodys.sh"
rc_is "unclassified exits non-zero" 1 $RC

echo
echo "== 2. A NEW FOREIGN FILE IS A FAILING BUILD ================================"
T="$WORK/t2"; mk_tree "$T"
G="$(mk_guard "$WORK/g2")"
rm "$T/bin/nobodys.sh"; ( cd "$T" && git add -A && git commit -qm rm ) >/dev/null 2>&1
bash "$G" --repo "$T" --accept --quiet >/dev/null 2>&1
rc_is "--accept on a clean tree succeeds" 0 $?
# Park another project's mechanism here. Declared honestly -- it has a row and
# a named owner, so R3 is satisfied and the ONLY thing left to catch it is the
# footprint. Declaring a parked file was never the same as being allowed to
# add one.
seq 1 30 > "$T/bin/theirs-more.sh"
sed -i 's|^bin/theirs-install.sh|bin/theirs-more.sh       scheduler another effector\nbin/theirs-install.sh|' "$T/bin/lib/ownership-set.sh"
( cd "$T" && git add -A && git commit -qm park ) >/dev/null 2>&1
OUT="$(bash "$G" --repo "$T" 2>&1)"; RC=$?
has "the parked path is named, and named as parked" "$OUT" "FLAG [parked] bin/theirs-more.sh"
hasnt "and it is not excused as growth" "$OUT" "NOTE [new path] bin/theirs-more.sh"
rc_is "parking another project's mechanism here fails the build" 1 $RC
OUT="$(bash "$G" --repo "$T" --accept 2>&1)"; RC=$?
has "--accept refuses to launder a regression" "$OUT" "REFUSED"
rc_is "...and exits non-zero doing so" 1 $RC

echo
echo "== 2b. AND IT FAILS WHEN THE ARITHMETIC NETS OUT DOWNWARDS ================="
# The case the line count could not see, and the reason the bar moved onto the
# file list. Park 30 foreign lines while deleting 35 from a foreign file that
# was already here: the total goes DOWN (40 -> 35), the share goes DOWN, R4
# does not fire -- and a whole file belonging to another project has just been
# parked here. Under the count-only bar this run was GREEN.
T="$WORK/t2b"; mk_tree "$T"
G="$(mk_guard "$WORK/g2b")"
rm "$T/bin/nobodys.sh"; ( cd "$T" && git add -A && git commit -qm rm ) >/dev/null 2>&1
bash "$G" --repo "$T" --accept --quiet >/dev/null 2>&1
seq 1 5 > "$T/bin/theirs-install.sh"
seq 1 30 > "$T/bin/theirs-more.sh"
sed -i 's|^bin/theirs-install.sh|bin/theirs-more.sh       scheduler another effector\nbin/theirs-install.sh|' "$T/bin/lib/ownership-set.sh"
( cd "$T" && git add -A && git commit -qm 'park, and pay for it out of another file' ) >/dev/null 2>&1
OUT="$(bash "$G" --repo "$T" 2>&1)"; RC=$?
has "the foreign line total actually FELL" "$OUT" "another's      : 35 lines"
has "and the parked file is caught anyway" "$OUT" "FLAG [parked] bin/theirs-more.sh"
rc_is "a parked file is not paid for with a deletion elsewhere" 1 $RC

echo
echo "== 3. THE RECLASSIFICATION DODGE ==========================================="
# Cheaper than migrating: leave the file exactly where it is and rewrite the
# row so it counts as mine. The ratchet records NAMES for this reason.
T="$WORK/t3"; mk_tree "$T"
G="$(mk_guard "$WORK/g3")"
rm "$T/bin/nobodys.sh"; ( cd "$T" && git add -A && git commit -qm rm ) >/dev/null 2>&1
bash "$G" --repo "$T" --accept --quiet >/dev/null 2>&1
sed -i 's|^bin/theirs-install.sh  scheduler an effector|bin/theirs-install.sh  realisateur suddenly ours|' "$T/bin/lib/ownership-set.sh"
sed -i 's|^bin/mine-scan.sh   realisateur a sense|bin/mine-scan.sh   realisateur a sense\n|' "$T/bin/lib/ownership-set.sh"
( cd "$T" && git add -A && git commit -qm redeclare ) >/dev/null 2>&1
OUT="$(bash "$G" --repo "$T" 2>&1)"; RC=$?
has "moving a row is not moving a file" "$OUT" "FLAG [reclassified] bin/theirs-install.sh"
rc_is "the dodge fails the build" 1 $RC

echo
echo "== 4. A REAL MIGRATION LOWERS THE BAR AND CANNOT BE UNDONE ================="
T="$WORK/t4"; mk_tree "$T"
G="$(mk_guard "$WORK/g4")"
rm "$T/bin/nobodys.sh"; ( cd "$T" && git add -A && git commit -qm rm ) >/dev/null 2>&1
bash "$G" --repo "$T" --accept --quiet >/dev/null 2>&1
git -C "$T" rm -q "bin/theirs-install.sh"
sed -i '/^bin\/theirs-install.sh/d' "$T/bin/lib/ownership-set.sh"
( cd "$T" && git add -A && git commit -qm migrated ) >/dev/null 2>&1
OUT="$(bash "$G" --repo "$T" 2>&1)"; RC=$?
rc_is "a file leaving the tree is not a regression" 0 $RC
has "the foreign surface is now empty" "$OUT" "another's      : 0 lines"
bash "$G" --repo "$T" --accept --quiet >/dev/null 2>&1
# Put it back. The bar was lowered by --accept, so restoring it is now red.
git -C "$T" checkout -q HEAD~1 -- bin/theirs-install.sh bin/lib/ownership-set.sh
( cd "$T" && git add -A && git commit -qm regressed ) >/dev/null 2>&1
OUT="$(bash "$G" --repo "$T" 2>&1)"; RC=$?
rc_is "putting it back is a failing build, not an argument" 1 $RC

echo
echo "== 5. GROWTH INSIDE A RECORDED PATH IS PERMITTED, AND IS REPORTED =========="
# 74% of the real repo's mechanism is another project's, so repairing a
# foreign file that is already here is most of the maintenance this repo can
# be asked to do -- and under the count-only bar it was arithmetically
# unmergeable (#144: twelve lines of headroom against a 533-line fix, and
# --accept refusing by design).
#
# The share bar is what still bounds this, and it bounds it TIGHTLY right
# after an accept: growing a foreign file raises the share unless realisateur
# grows too. So the fixture reproduces the real tree's situation rather than
# wishing it away -- bank some realisateur growth first, then spend the slack
# on a repair. Growth is permitted UNDER the recorded share, never through it.
T="$WORK/t5"; mk_tree "$T"
G="$(mk_guard "$WORK/g5")"
rm "$T/bin/nobodys.sh"; ( cd "$T" && git add -A && git commit -qm rm ) >/dev/null 2>&1
bash "$G" --repo "$T" --accept --quiet >/dev/null 2>&1
seq 1 400 > "$T/bin/mine-scan.sh"
( cd "$T" && git add -A && git commit -qm 'realisateur grows; the foreign share falls' ) >/dev/null 2>&1
bash "$G" --repo "$T" --quiet >/dev/null 2>&1
rc_is "banking realisateur growth is not a regression" 0 $?
seq 1 90 > "$T/bin/theirs-install.sh"
( cd "$T" && git add -A && git commit -qm 'repair the foreign script that is already here' ) >/dev/null 2>&1
OUT="$(bash "$G" --repo "$T" 2>&1)"; RC=$?
rc_is "growth inside a path the ratchet already records is not a regression" 0 $RC
has "the growth is stated, not swallowed" "$OUT" "NOTE [growth]"
has "and it says how far above the record it is" "$OUT" "50 above the 40 recorded"
hasnt "nothing is reported as a finding" "$OUT" "FLAG"

echo
echo "== 6. A NEW PATH THAT LEAVES WITH A RECORDED ONE IS NOT A NEW FOOTPRINT ===="
# Two relations, both DERIVED, neither a hand-kept exemption list. A file that
# migrates out with a recorded file adds no migration unit; refusing it would
# mean "you may not test, or feed data to, the foreign mechanism you are
# already stuck with".
T="$WORK/t6"; mk_tree "$T"
G="$(mk_guard "$WORK/g6")"
rm "$T/bin/nobodys.sh"; ( cd "$T" && git add -A && git commit -qm rm ) >/dev/null 2>&1
bash "$G" --repo "$T" --accept --quiet >/dev/null 2>&1
seq 1 400 > "$T/bin/mine-scan.sh"
( cd "$T" && git add -A && git commit -qm 'realisateur grows; the foreign share falls' ) >/dev/null 2>&1

# FOLLOWS -- a suite for a recorded foreign script. Its owner is DERIVED from
# that script by the ledger, so it is the LEDGER that says it follows it, and
# there is one copy of that rule rather than two.
seq 1 25 > "$T/bin/tests/theirs-install.test.sh"
( cd "$T" && git add -A && git commit -qm 'test the foreign script that is already here' ) >/dev/null 2>&1
OUT="$(bash "$G" --repo "$T" 2>&1)"; RC=$?
rc_is "a suite for a recorded foreign script is not a parked file" 0 $RC
has "it is named rather than absorbed" "$OUT" "NOTE [new path] bin/tests/theirs-install.test.sh"
has "...and so is the recorded path it follows" "$OUT" "follows bin/theirs-install.sh"

# READ BY -- a data file that a recorded foreign script of the SAME OWNER
# names as a path. This is bin/lib/not-a-verb.tsv's shape in #145.
printf 'exempt=lib/theirs-data.tsv\n' >> "$T/bin/theirs-install.sh"
seq 1 12 > "$T/bin/lib/theirs-data.tsv"
sed -i 's|^bin/theirs-install.sh  scheduler an effector|bin/theirs-install.sh  scheduler an effector\nbin/lib/theirs-data.tsv scheduler the table it reads|' "$T/bin/lib/ownership-set.sh"
( cd "$T" && git add -A && git commit -qm 'the table it reads' ) >/dev/null 2>&1
OUT="$(bash "$G" --repo "$T" 2>&1)"; RC=$?
rc_is "a file a recorded foreign script reads is not a parked file" 0 $RC
has "the file that reads it is named" "$OUT" "read by bin/theirs-install.sh"

echo
echo "== 6b. AND THE RELATION IS THE WHOLE OF IT ================================="
# The SAME new file, same owner, same honest ledger row -- with nothing here
# reading it. One line of difference between permitted and refused, and the
# line is the reference. Without this, "attached" would be a word rather than
# a test.
T="$WORK/t6b"; mk_tree "$T"
G="$(mk_guard "$WORK/g6b")"
rm "$T/bin/nobodys.sh"; ( cd "$T" && git add -A && git commit -qm rm ) >/dev/null 2>&1
bash "$G" --repo "$T" --accept --quiet >/dev/null 2>&1
seq 1 400 > "$T/bin/mine-scan.sh"
seq 1 12 > "$T/bin/lib/theirs-data.tsv"
sed -i 's|^bin/theirs-install.sh  scheduler an effector|bin/theirs-install.sh  scheduler an effector\nbin/lib/theirs-data.tsv scheduler the table nothing reads|' "$T/bin/lib/ownership-set.sh"
( cd "$T" && git add -A && git commit -qm 'the table nothing reads' ) >/dev/null 2>&1
OUT="$(bash "$G" --repo "$T" 2>&1)"; RC=$?
has "an unread new foreign file is parked" "$OUT" "FLAG [parked] bin/lib/theirs-data.tsv"
rc_is "...and fails the build, with the share and the count both falling" 1 $RC

echo
echo "== 7. --strict FAILS WHILE ANY FOREIGN MECHANISM REMAINS ==================="
T="$WORK/t7"; mk_tree "$T"
G="$(mk_guard "$WORK/g7")"
rm "$T/bin/nobodys.sh"; ( cd "$T" && git add -A && git commit -qm rm ) >/dev/null 2>&1
bash "$G" --repo "$T" --accept --quiet >/dev/null 2>&1
bash "$G" --repo "$T" --quiet >/dev/null 2>&1
rc_is "default mode is a ratchet: no regression, exit 0" 0 $?
bash "$G" --repo "$T" --strict --quiet >/dev/null 2>&1
rc_is "--strict still refuses to call 80% foreign a success" 3 $?

echo
echo "== 8. BLIND IS NEVER CLEAN, AND IS NEVER THIS REPOSITORY ==================="
EMPTY="$WORK/empty"; mkdir -p "$EMPTY"
( cd "$EMPTY" && git init -q -b main . ) >/dev/null 2>&1
OUT="$(bash "$AUD" --repo "$EMPTY" 2>&1)"; RC=$?
rc_is "a tree with no ledger is BLIND, exit 2" 2 $RC
has "it says so" "$OUT" "BLIND:"
has "and says explicitly that blind is not clean" "$OUT" "NOT a clean result"
hasnt "pointed elsewhere, it does not report on this repository" "$OUT" "$REPO"
NOGIT="$WORK/nogit"; mkdir -p "$NOGIT"
bash "$AUD" --repo "$NOGIT" >/dev/null 2>&1
rc_is "a non-repository is BLIND, not empty-and-fine" 2 $?

echo
echo "== 9. THE ARGUMENT CONTRACT ================================================"
bash "$AUD" --not-a-flag >/dev/null 2>&1; rc_is "unknown flag exits 2" 2 $?
bash "$AUD" --help >/dev/null 2>&1;       rc_is "--help exits 0" 0 $?
O="$(bash "$AUD" --help 2>&1)"
has "--help documents the BLIND exit" "$O" "BLIND"
has "--help documents the strict exit" "$O" "foreign mechanism remains"

echo
echo "== 10. WITNESS -- THE LIVE TREE (read-only) ================================="
# Not an assertion about the NUMBER. Two things that must hold at any share.
OUT="$(cd "$REPO" && bash "$AUD" --repo "$REPO" 2>&1)"; RC=$?
rc_is "the recorded baseline is honest: no regression on this branch" 0 $RC
hasnt "nothing in the live tree is unclassified" "$OUT" "FLAG [unclassified]"
(cd "$REPO" && bash "$AUD" --repo "$REPO" --strict --quiet >/dev/null 2>&1)
rc_is "and --strict is still red, because the migration has not happened" 3 $?
hasnt "and nothing is parked here" "$OUT" "FLAG [parked]"
printf '%s\n' "$OUT" | grep -E 'FOREIGN SHARE' | sed 's/^ */  witness: /'
# Growth is permitted, so the only thing that keeps it from being invisible is
# somebody reading it. Print every NOTE here, where CI already runs this suite
# on every pull request: a PR that grows the foreign surface says so in the
# same log that says the suite passed.
printf '%s\n' "$OUT" | grep -E '^ *NOTE \[' | sed 's/^ */  witness: /'

echo
echo "ownership-audit.test: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
exit 0
