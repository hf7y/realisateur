#!/usr/bin/env bash
#
# TRAPS (the rest of this header is in the vault):
# NOT WIRED TO CI: bin/thermostat-wiring.sh ITSELF. It probes the estate -- the
# scheduler checkout, the issue tracker -- which a container cannot see, so
# every ratcheted check would go BLIND and CI would be red for a reason that
# says nothing about the branch. It is a HOST gate, run where the estate exists.
# This suite is what CI can honestly assert about it.
# Offline, zero AI, no network: every case builds a throwaway copy of the
# script beside a throwaway scheduler repository, and points it at that. It
# never reads the live estate, so it says the same thing on every host and in
# CI. `gh` is forced off PATH so the provenance check is deterministically
# BLIND rather than dependent on the real tracker.

set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
is()   { [ "$2" = "$3" ] && ok "$1" || bad "$1" "expected [$3], got [$2]"; }

TMP="$(mktemp -d)" || { echo "cannot mktemp" >&2; exit 2; }
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/shim"
printf '#!/bin/sh\nexit 1\n' > "$TMP/shim/gh"
chmod +x "$TMP/shim/gh"

# --- a throwaway realisateur, holding the script under test ------------------
FAKE="$TMP/realisateur"
mkdir -p "$FAKE/bin/lib" "$FAKE/.github/workflows"
cp "$ROOT/bin/thermostat-wiring.sh" "$FAKE/bin/"
cp "$ROOT/bin/lib/cli-guard.sh"     "$FAKE/bin/lib/"
mkdir -p "$FAKE/.github/workflows"; echo 'uses: hf7y/etalon/.github/workflows/guard.yml@main' > "$FAKE/.github/workflows/prose.yml"

# --- a throwaway scheduler, in whatever state a case needs -------------------
# `conforming` builds the repo the redesign is aiming at; `current` builds the
# one that exists today. Both are real git repos, because the script asks git
# what is TRACKED -- an untracked BLOCKERS.md is a different (worse) problem
# and must not read as conformance.
mkscheduler() {
  local d="$1" shape="$2"
  rm -rf "$d"; mkdir -p "$d/schedule" "$d/bin" "$d/lib"
  git -C "$d" init -q
  git -C "$d" config user.email t@t; git -C "$d" config user.name t
  if [ "$shape" = current ]; then
    echo 'blocked on zach'      > "$d/BLOCKERS.md"
    echo 'shared sweep engine'  > "$d/lib/sweep-loop-common.sh"
    echo 'report'               > "$d/bin/morning-report.sh"
    printf 'ecosim|0|2|/x/scheduler-run ecosim batch\n' > "$d/schedule/_paced.conf"
    # A dispatcher that consults nothing about backlog: the state `setpoint`
    # exists to report.
    printf 'exec "$SELF_DIR/freeze-check.sh" "$name"\n' > "$d/bin/usage-paced-runner.sh"
  else
    # no BLOCKERS.md, no sweep loop, no human surface, no weight column,
    # and something that appends to the verdict ledger.
    printf 'ecosim|0|/x/scheduler-run ecosim batch\n' > "$d/schedule/_paced.conf"
    printf 'echo "$v" >> "$HOME/.local/share/scheduler-verdict/$p.history"\n' \
      > "$d/lib/run-record.sh"
    # Both legs of `setpoint`. Named tempo.sh only because that is what landed;
    # the check greps for the pair, not for this name.
    printf 'gh issue list --repo "$slug" --state open\n' > "$d/bin/tempo.sh"
    printf '"$SELF_DIR/tempo.sh" "$name" || continue\n' > "$d/bin/usage-paced-runner.sh"
  fi
  git -C "$d" add -A >/dev/null 2>&1
  git -C "$d" commit -qm fixture >/dev/null 2>&1
}

# run <ratchet-contents> <sched-root> [args...]
run() {
  local ratchet="$1" sched="$2"; shift 2
  printf '%s\n' "$ratchet" > "$FAKE/bin/thermostat-wiring.ratchet"
  # A `gh` that cannot answer, shimmed ahead of the real one. The provenance
  # check must be BLIND by construction here, so no case silently depends on
  # the live tracker's label state -- an earlier draft of this file set
  # PATH=/usr/bin:/bin believing that removed gh, and gh lives in /usr/bin, so
  # two cases were quietly reading the real ecosystem's issue labels.
  env PATH="$TMP/shim:$PATH" SCHED_ROOT="$sched" \
      bash "$FAKE/bin/thermostat-wiring.sh" "$@" 2>&1
}

echo "thermostat-wiring.test.sh"

CUR="$TMP/sched-current"; mkscheduler "$CUR" current
CONF="$TMP/sched-conforming"; mkscheduler "$CONF" conforming

# --- A: an empty ratchet is not a failing build ------------------------------
out="$(run '' "$CUR")"; rc=$?
is  A1 "$rc" 0
has A2 "$out" "to go"

# --- B: regression is the assertion the whole mechanism rests on -------------
out="$(run 'blockers' "$CUR")"; rc=$?
is  B1 "$rc" 1
has B2 "$out" "REGRESSION"
has B2b "$out" "blockers"

# --- C: BLIND is never success -----------------------------------------------
# `provenance` is BLIND here (no gh on PATH). Ratcheting it means the run
# cannot prove the absence of a regression, and must refuse to say it can.
out="$(run 'provenance' "$CUR")"; rc=$?
is  C1 "$rc" 2
has C2 "$out" "cannot see"
# ...but the SAME blind check, unratcheted, must not fail the build:
out="$(run '' "$CUR")"; rc=$?
is  C3 "$rc" 0

# --- D: --accept raises or refuses, never lowers -----------------------------
out="$(run 'blockers' "$CUR" --accept)"; rc=$?
is  D1 "$rc" 1
has D1b "$out" "REFUSED"
# accept against the conforming tree with `ledger` already held: every id that
# was in the ratchet must survive, even one that is currently blind.
out="$(run 'prosepriced' "$CONF" --accept)"; rc=$?
is  D2 "$rc" 0
grep -q '^prosepriced$' "$FAKE/bin/thermostat-wiring.ratchet" \
  && ok D2b || bad D2b "--accept dropped an id that was already ratcheted"

# --- E: the argument contract ------------------------------------------------
out="$(run '' "$CUR" --strict)"; rc=$?
is  E1 "$rc" 3
out="$(run '' "$CUR" --not-a-real-flag)"; rc=$?
is  E2 "$rc" 2

# --- F: the fixture the redesign is aiming at --------------------------------
# Only 8 of 9 can pass offline (provenance needs the tracker), so this asserts
# the eight that CAN, and that none of them reads as UNMET on a clean tree.
out="$(run '' "$CONF")"; rc=$?
is    F1  "$rc" 0
hasnt F1b "$out" "UNMET  blockers"
hasnt F1c "$out" "UNMET  sweeploop"
hasnt F1d "$out" "UNMET  headless"
hasnt F1e "$out" "UNMET  weight"
hasnt F1f "$out" "UNMET  ledger"
has   F1g "$out" "PASS   blockers"
has   F1h "$out" "PASS   setpoint"

# --- G: `setpoint` is a WIRING check, and both legs are load-bearing ---------
# G2 is the one that matters: a tracker-reading script the dispatcher never
# runs must read UNMET, or the check goes green on build-but-don't-wire, which
# is what it was added to catch. G3 is its mirror -- wiring without a sensor.
out="$(run '' "$CUR")"
has G1 "$out" "UNMET  setpoint"

UNWIRED="$TMP/sched-unwired"; mkscheduler "$UNWIRED" conforming
printf 'echo "the dispatcher does not run tempo"\n' > "$UNWIRED/bin/usage-paced-runner.sh"
git -C "$UNWIRED" add -A >/dev/null 2>&1
git -C "$UNWIRED" commit -qm unwired >/dev/null 2>&1
out="$(run '' "$UNWIRED")"
has G2 "$out" "UNMET  setpoint"

NOSENSOR="$TMP/sched-nosensor"; mkscheduler "$NOSENSOR" conforming
printf 'read the conf and pick an interval\n' > "$NOSENSOR/bin/tempo.sh"
git -C "$NOSENSOR" add -A >/dev/null 2>&1
git -C "$NOSENSOR" commit -qm nosensor >/dev/null 2>&1
out="$(run '' "$NOSENSOR")"
has G3 "$out" "UNMET  setpoint"

echo
summary
[ "$fail" = 0 ] || exit 1
exit 0
