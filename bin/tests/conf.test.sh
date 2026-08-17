#!/usr/bin/env bash
#
# conf.test.sh -- the defect that made propagation reach zero projects.
#
# THE LOAD-BEARING ASSERTIONS ARE A1 AND B1. A1: a conf written the way EVERY
# registered project writes it -- PROJECT_REPO_PATH="$HOME/..." -- resolves to
# a real directory. The raw `grep -oP` this replaces returned the literal
# characters `$HOME/...`, so `[ -d "$repo/.git" ]` was false for every project
# on every host and restamp-discipline.sh propagated the baseline to NOBODY
# while printing a tidy summary and exiting 0.
#
# B1: a run that reached nothing exits nonzero. Without it the fix is one bad
# conf away from silently regressing to the same shape, and the shape is the
# point: thirteen SKIP lines and exit 0 is what the defect looked like for as
# long as it lasted.
#
# Hermetic: builds its own scheduler root and its own target repos in a temp
# dir, overrides HOME and SCHED_ROOT, and never touches the live ecosystem.
#
# usage: ./bin/tests/conf.test.sh
set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$REPO/bin/lib/conf.sh"


T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
printf 'conf.sh -- test\n\n'

# --- A: expansion -------------------------------------------------------------
printf 'A. the path a real conf carries resolves (A1 is the whole defect)\n'
printf 'PROJECT_REPO_PATH="$HOME/Documents/Projects/demo"\n' > "$T/a.conf"
got="$(HOME=/tmp/fakehome conf_repo_path "$T/a.conf")"
eq "A1  \$HOME is expanded"        "$got" "/tmp/fakehome/Documents/Projects/demo"
printf 'PROJECT_REPO_PATH="${HOME}/x"\n' > "$T/b.conf"
got="$(HOME=/tmp/fakehome conf_repo_path "$T/b.conf")"
eq "A2  \${HOME} is expanded too"  "$got" "/tmp/fakehome/x"
printf 'PROJECT_REPO_PATH="/opt/absolute"\n' > "$T/c.conf"
eq "A3  an absolute path is untouched" "$(conf_repo_path "$T/c.conf")" "/opt/absolute"
# A conf is a file this repo does not own. Expansion is by name, not by eval.
printf 'PROJECT_REPO_PATH="$(touch %s/PWNED)/x"\n' "$T" > "$T/d.conf"
conf_repo_path "$T/d.conf" >/dev/null 2>&1
if [ -e "$T/PWNED" ]; then bad "A4  a conf cannot execute code through this"
else ok "A4  a conf cannot execute code through this"; fi
printf 'OTHER="x"\n' > "$T/e.conf"
conf_repo_path "$T/e.conf" >/dev/null 2>&1
eq "A5  no PROJECT_REPO_PATH returns 1" "$?" "1"

# --- B: RETIRED 2026-08-14 -----------------------------------------------------
# This section exercised restamp-discipline.sh end to end against a fixture
# ecosystem, including its "a pass that reached nothing exits nonzero" guard.
# The script is gone: `discipline` prints the one file at the point of use
#   [rest: vault:realisateur/guard-archaeology-20260817.md]

# --- C: the population ratchet -----------------------------------------------
# WHY A RATCHET AND NOT A LIST. lib/conf.sh's header used to NAME the four
# scripts still on the raw grep; by 2026-08-11 it was wrong in both directions
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
printf '\nC. no script in bin/ or bashify/ extracts PROJECT_REPO_PATH without expanding it\n'
c_bad=""
c_scanned=0
while IFS= read -r f; do
  [ -f "$REPO/$f" ] || continue
  c_scanned=$((c_scanned + 1))
  # An EXTRACTION: a non-comment line pulling the value out with a text tool.
  # `grep -q '^PROJECT_REPO_PATH='` (presence) and sourcing the conf
  # (silence-audit.sh, which expands by definition) are not extractions.
  grep -vE '^[[:space:]]*#' "$REPO/$f" \
    | grep -E 'PROJECT_REPO_PATH' \
    | grep -qE 'grep -o|sed -n|cut -d|awk' || continue
  # ...and somewhere in the same file, an expansion.
  grep -q 'conf_repo_path' "$REPO/$f" && continue
  grep -qF "'\$HOME'/*)" "$REPO/$f" && continue
  c_bad="$c_bad $f"
  # `:(glob)` so `*` stops at `/`. bin/tests/ is deliberately out: a suite that
  # QUOTES the raw grep in a fixture (deferral-ledger.test.sh does, verbatim,
  # as its example of a well-formed deferral) documents the defect rather than
  # committing it. The population is the scripts that run against the registry.
done < <(cd "$REPO" && git ls-files \
           ':(glob)bin/*.sh' ':(glob)bin/lib/*.sh' \
           ':(glob)bashify/*.sh' ':(glob)bashify/lib/*.sh' ':(glob)bashify/bin/*' \
           2>/dev/null)

if [ "$c_scanned" -eq 0 ]; then
  bad "C0  the scan found files to scan" "git ls-files matched nothing -- this checked NOTHING"
else
  ok "C0  scanned $c_scanned tracked script(s) under bin/"
fi
if [ -z "$c_bad" ]; then
  ok "C1  every extraction of PROJECT_REPO_PATH is expanded"
else
  bad "C1  every extraction of PROJECT_REPO_PATH is expanded" "unexpanded:$c_bad"
fi

# --- D: session-marker.sh, the hook that no-opped for eight days --------------
# D1 is the defect: until 2026-08-11 resolution returned nothing for every
# directory on every host, so no marker was written and scheduler's
# interactive-deferral guard read every repo as free. D3 is the half that
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
printf '\nD. session-marker.sh resolves, and says so when it cannot\n'
SM="$REPO/bin/session-marker.sh"
D="$T/sm"; mkdir -p "$D/home/Documents/Projects/demo/sub" "$D/sched/schedule"
printf 'PROJECT_REPO_PATH="$HOME/Documents/Projects/demo"\n' > "$D/sched/schedule/demo.conf"
# an underscore conf is a tier file, not a project -- it must not be resolved
printf 'PROJECT_REPO_PATH="$HOME/Documents/Projects/demo"\n' > "$D/sched/schedule/_batch.conf"

out="$(HOME="$D/home" SCHED_ROOT="$D/sched" bash "$SM" resolve "$D/home/Documents/Projects/demo/sub" 2>&1)"; rc=$?
eq "D1  a real checkout resolves (exit 0)" "$rc" "0"
eq "D1b and names the project"             "$out" "demo"

out="$(HOME="$D/home" SCHED_ROOT="$D/sched" bash "$SM" resolve "$D/home" 2>&1)"; rc=$?
eq "D2  an unrelated directory exits 1"    "$rc" "1"

# Every conf readable, every path literal-impossible: the #73 shape exactly.
mkdir -p "$D/blind/schedule"
printf 'PROJECT_REPO_PATH="$HOME/Documents/Projects/gone"\n' > "$D/blind/schedule/gone.conf"
out="$(HOME="$D/home" SCHED_ROOT="$D/blind" bash "$SM" resolve "$D/home" 2>&1)"; rc=$?
eq "D3  a registry that resolves to nothing exits 3 (BLIND)" "$rc" "3"
if printf '%s' "$out" | grep -q 'BLIND'; then
  ok "D3b and says BLIND in words, not only in a code"
else bad "D3b and says BLIND in words, not only in a code" "$out"; fi

# The hook path keeps exit 0 -- but must not keep quiet.
out="$(HOME="$D/home" SCHED_ROOT="$D/blind" CLAUDE_PROJECT_DIR="$D/home" bash "$SM" acquire </dev/null 2>&1)"; rc=$?
eq "D4  acquire still exits 0 when blind (a hook must not block a session)" "$rc" "0"
if printf '%s' "$out" | grep -q 'BLIND'; then
  ok "D4b but reports the blindness on stderr"
else bad "D4b but reports the blindness on stderr" "$out"; fi

# End to end: the marker actually lands, which is the thing that stopped.
REG="$D/registry"
HOME="$D/home" SCHED_ROOT="$D/sched" SCHEDULER_REGISTRY_DIR="$REG" \
  CLAUDE_PROJECT_DIR="$D/home/Documents/Projects/demo" bash "$SM" acquire </dev/null >/dev/null 2>&1
if [ -f "$REG/demo.interactive" ]; then
  ok "D5  acquire writes the marker a live session is supposed to leave"
else bad "D5  acquire writes the marker a live session is supposed to leave" "no $REG/demo.interactive"; fi
HOME="$D/home" SCHED_ROOT="$D/sched" SCHEDULER_REGISTRY_DIR="$REG" \
  CLAUDE_PROJECT_DIR="$D/home/Documents/Projects/demo" bash "$SM" release </dev/null >/dev/null 2>&1
if [ -f "$REG/demo.interactive" ]; then
  bad "D6  release removes it again" "marker survived release"
else ok "D6  release removes it again"; fi

summary
