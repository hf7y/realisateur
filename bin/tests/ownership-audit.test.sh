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
own_owner() {
  local p="$1" best="" bestlen=0 pre owner rest
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
# Park another project's mechanism here.
seq 1 30 > "$T/bin/theirs-more.sh"
sed -i 's|^bin/theirs-install.sh|bin/theirs-more.sh       scheduler another effector\nbin/theirs-install.sh|' "$T/bin/lib/ownership-set.sh"
( cd "$T" && git add -A && git commit -qm park ) >/dev/null 2>&1
OUT="$(bash "$G" --repo "$T" 2>&1)"; RC=$?
has "the growth is named as a regression" "$OUT" "FLAG [regression] foreign mechanism GREW"
rc_is "parking another project's mechanism here fails the build" 1 $RC
OUT="$(bash "$G" --repo "$T" --accept 2>&1)"; RC=$?
has "--accept refuses to launder a regression" "$OUT" "REFUSED"
rc_is "...and exits non-zero doing so" 1 $RC

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
echo "== 5. --strict FAILS WHILE ANY FOREIGN MECHANISM REMAINS ==================="
T="$WORK/t5"; mk_tree "$T"
G="$(mk_guard "$WORK/g5")"
rm "$T/bin/nobodys.sh"; ( cd "$T" && git add -A && git commit -qm rm ) >/dev/null 2>&1
bash "$G" --repo "$T" --accept --quiet >/dev/null 2>&1
bash "$G" --repo "$T" --quiet >/dev/null 2>&1
rc_is "default mode is a ratchet: no regression, exit 0" 0 $?
bash "$G" --repo "$T" --strict --quiet >/dev/null 2>&1
rc_is "--strict still refuses to call 80% foreign a success" 3 $?

echo
echo "== 6. BLIND IS NEVER CLEAN, AND IS NEVER THIS REPOSITORY ==================="
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
echo "== 7. THE ARGUMENT CONTRACT ================================================"
bash "$AUD" --not-a-flag >/dev/null 2>&1; rc_is "unknown flag exits 2" 2 $?
bash "$AUD" --help >/dev/null 2>&1;       rc_is "--help exits 0" 0 $?
O="$(bash "$AUD" --help 2>&1)"
has "--help documents the BLIND exit" "$O" "BLIND"
has "--help documents the strict exit" "$O" "foreign mechanism remains"

echo
echo "== 8. WITNESS -- THE LIVE TREE (read-only) ================================="
# Not an assertion about the NUMBER. Two things that must hold at any share.
OUT="$(cd "$REPO" && bash "$AUD" --repo "$REPO" 2>&1)"; RC=$?
rc_is "the recorded baseline is honest: no regression on this branch" 0 $RC
hasnt "nothing in the live tree is unclassified" "$OUT" "FLAG [unclassified]"
(cd "$REPO" && bash "$AUD" --repo "$REPO" --strict --quiet >/dev/null 2>&1)
rc_is "and --strict is still red, because the migration has not happened" 3 $?
printf '%s\n' "$OUT" | grep -E 'FOREIGN SHARE' | sed 's/^ */  witness: /'

echo
echo "ownership-audit.test: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
exit 0
