#!/usr/bin/env bash
#
# verbs-refresh.test.sh -- witness for bin/verbs-refresh.sh.
#
#
# ON H, because it is the design constraint: a second implementation of the
# atomic switch would be a second answer to "which build am I on". The case
# asserts mechanically that the switch came from the delegate, not from here.
#
set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
REPO_BIN="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_BIN/verbs-refresh.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

# Build a fixture root pinned to build $1, with a working verb link.
fixture() {
  root="$T/$2/root"; bin="$T/$2/bin"
  # ${T:?} so a fixture name that somehow arrives empty cannot make this
  # `rm -rf /` -- SC2115, and the one line in this file that could hurt.
  rm -rf "${T:?}/$2"; mkdir -p "$root/$1/p/bin" "$bin"
  : > "$root/$1/p/bin/goodverb"; chmod +x "$root/$1/p/bin/goodverb"
  ln -s "$1" "$root/current"
  ln -s "$root/current/p/bin/goodverb" "$bin/goodverb"
}

# The delegate stub. Its exit status IS the --check answer; it records every
# call so H can assert delegation, and it moves `current` on --apply the way
# the real tool does.
STUB_LOG="$T/ivb.log"; : > "$STUB_LOG"
mkstub() { # $1 = exit code for --check, $2 = build id to switch to on --apply
  cat > "$T/ivb" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "$STUB_LOG"
case "\$1" in
  --check) exit $1 ;;
  --latest)
    mkdir -p "\$BUILD_ROOT_FIXTURE/$2/p/bin"
    ln -sfn "$2" "\$BUILD_ROOT_FIXTURE/current.tmp"
    mv -Tf "\$BUILD_ROOT_FIXTURE/current.tmp" "\$BUILD_ROOT_FIXTURE/current"
    exit 0 ;;
esac
exit 0
EOF
  chmod +x "$T/ivb"
}

run() { # $1 = fixture name, rest = args
  local f="$1"; shift
  BUILD_ROOT="$T/$f/root" VERB_BIN="$T/$f/bin" \
    BUILD_ROOT_FIXTURE="$T/$f/root" INSTALL_VERB_BUILD="$T/ivb" \
    "$SCRIPT" "$@" 2>&1
}

TODAY="$(date -u +%Y-%m-%dT000000Z)"

# --- A: current, fresh, healthy links ---------------------------------------
fixture "$TODAY" a; mkstub 0 unused
out="$(run a)"; run a >/dev/null 2>&1; got=$?
has "A: names the build it is on"   "$out" "on build $TODAY"
has "A: reports nothing newer"      "$out" "no newer build"
hasnt "A: does not cry STALE"       "$out" "STALE"
rc   "A: exits 0" 0 "$got"
q="$(run a --quiet 2>&1)"
[ -z "$q" ] && ok "A: --quiet is SILENT when all is well" \
             || bad "A: --quiet printed '$q'"

# --- B: a newer build exists ------------------------------------------------
fixture "$TODAY" b; mkstub 1 unused
out="$(run b)"; run b >/dev/null 2>&1; got=$?
has "B: reports NEWER" "$out" "NEWER"
rc   "B: exits 1" 1 "$got"
# CHECK_TTL_HOURS=0 so the stamp the runs above just wrote does not suppress
# the channel check. --quiet MUST be able to say "a newer build is available";
# the first version could not, because it skipped the network entirely, and
# this assertion is what caught it.
rm -f "$T/b/root/.verbs-refresh-last-check"
qout="$(BUILD_ROOT="$T/b/root" VERB_BIN="$T/b/bin" INSTALL_VERB_BUILD="$T/ivb" \
        CHECK_TTL_HOURS=0 "$SCRIPT" --quiet 2>&1)"
has "B: --quiet CAN report a newer build"            "$qout" "newer build is available"
has "B: --quiet prescribes --apply, which can fix it" "$qout" "--apply"

# --- J: the TTL stamp bounds login cost, and never fakes an all-clear -------
# Within the TTL the channel is not consulted. The requirement is that a
# skipped check is NOT REPORTED as up to date -- it is simply not claimed.
# The TTL applies to --quiet only (a report the human asked for always looks),
# so this case must use --quiet or it asserts nothing at all.
fixture "$TODAY" j; mkstub 1 unused
touch "$T/j/root/.verbs-refresh-last-check"
jout="$(BUILD_ROOT="$T/j/root" VERB_BIN="$T/j/bin" INSTALL_VERB_BUILD="$T/ivb" \
        CHECK_TTL_HOURS=99 "$SCRIPT" --quiet 2>&1)"
[ -z "$jout" ] && ok "J: within the TTL, --quiet consults no channel and says nothing" \
               || bad "J: --quiet spoke within the TTL: '$jout'"
hasnt "J: a skipped check never claims up to date" "$jout" "up to date"
# ...and the same fixture, TTL expired, DOES nag. Pins that the TTL delays the
# warning rather than suppressing it forever.
jout2="$(BUILD_ROOT="$T/j/root" VERB_BIN="$T/j/bin" INSTALL_VERB_BUILD="$T/ivb" \
         CHECK_TTL_HOURS=0 "$SCRIPT" --quiet 2>&1)"
has "J: once the TTL expires the nag fires" "$jout2" "newer build is available"

# --- C: up to date, but ancient ---------------------------------------------
fixture 2020-01-01T000000Z c; mkstub 0 unused
out="$(run c)"; run c >/dev/null 2>&1; got=$?
has "C: reports STALE despite nothing newer" "$out" "STALE"
has "C: and says the cutter may have stopped" "$out" "cutter has stopped"
rc   "C: exits 1" 1 "$got"

# --- D: a dangling link is named (PATH skips it silently) -------------------
fixture "$TODAY" d; mkstub 0 unused
ln -s "$T/d/root/current/p/bin/gone" "$T/d/bin/ghostverb"
out="$(run d)"; run d >/dev/null 2>&1; got=$?
has "D: names the dangling verb" "$out" "DANGLING ghostverb"
rc   "D: exits 1" 1 "$got"
has "I: --quiet does NOT prescribe --apply for a dangling link" \
    "$(run d --quiet 2>&1)" "will NOT fix these"

# --- E: an off-channel link is named and left alone -------------------------
fixture "$TODAY" e; mkstub 0 unused
ln -s "$T/e/root/$TODAY/p/bin/goodverb" "$T/e/bin/pinnedverb"
before="$(readlink "$T/e/bin/pinnedverb")"
out="$(run e)"; run e >/dev/null 2>&1; got=$?
has "E: names the off-channel verb" "$out" "OFF-CHANNEL pinnedverb"
has "E: and says installe owns it"  "$out" "installe owns it"
rc   "E: exits 1" 1 "$got"
[ "$(readlink "$T/e/bin/pinnedverb")" = "$before" ] \
  && ok "E: the off-channel link was NOT clobbered" \
  || bad "E: the off-channel link was rewritten"

# --- F/G: BLIND is never 0 --------------------------------------------------
mkstub 0 unused
BUILD_ROOT="$T/nonexistent" "$SCRIPT" >/dev/null 2>&1
rc "F: no build root exits 6 BLIND" 6 "$?"
fixture "$TODAY" f2; rm "$T/f2/root/current"; mkdir -p "$T/f2/root/current"
run f2 >/dev/null 2>&1
rc "F: an unpinned current exits 6 BLIND" 6 "$?"
fixture "$TODAY" g; mkstub 3 unused
out="$(run g)"; run g >/dev/null 2>&1; got=$?
rc   "G: an unreachable channel exits 6 BLIND" 6 "$got"
has  "G: and says so rather than 'up to date'" "$out" "BLIND, not up to date"

# --- H: --apply delegates the switch, and performs none of its own ----------
fixture 2020-01-01T000000Z h; mkstub 1 2030-06-06T000000Z
: > "$STUB_LOG"
out="$(run h --apply)"
has "H: --apply reports the pull"          "$out" "pulling the newest build"
has "H: delegate was called with --latest --apply" "$(cat "$STUB_LOG")" "--latest --apply"
[ "$(readlink "$T/h/root/current")" = "2030-06-06T000000Z" ] \
  && ok "H: current moved -- and the delegate is what moved it" \
  || bad "H: current did not move"
hasnt "H: verbs-refresh.sh contains no atomic switch of its own" \
      "$(grep -v '^#' "$SCRIPT" | grep -E 'mv -Tf|ln -sfn' || true)" "current"

echo
summary
