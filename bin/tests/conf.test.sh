#!/usr/bin/env bash
# HERMETICITY: overrides HOME and SCHED_ROOT into a temp dir, so nothing it
# reads or writes is the live registry.
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

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$REPO/bin/lib/conf.sh"

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok    %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL  %s\n' "$1"; [ $# -gt 1 ] && printf '        %s\n' "$2"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "want [$3] got [$2]"; fi; }

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

# --- B: restamp-discipline, end to end ---------------------------------------
printf '\nB. restamp-discipline.sh against a fixture ecosystem\n'
H="$T/home"; mkdir -p "$H/Documents/Projects/demo" "$T/sched/schedule"
printf 'PROJECT_REPO_PATH="$HOME/Documents/Projects/demo"\n' > "$T/sched/schedule/demo.conf"
git -C "$H/Documents/Projects/demo" init -q
printf '# demo\n' > "$H/Documents/Projects/demo/CLAUDE.md"

out="$(HOME="$H" SCHED_ROOT="$T/sched" "$REPO/bin/restamp-discipline.sh" demo 2>&1)"; rc=$?
if printf '%s' "$out" | grep -q 'SKIP -- no git repo'; then
  bad "B1  a real checkout is not skipped" "$(printf '%s' "$out" | grep SKIP)"
else ok "B1  a real checkout is not skipped"; fi
if printf '%s' "$out" | grep -q '\$HOME'; then
  bad "B2  no literal \$HOME survives into the report"
else ok "B2  no literal \$HOME survives into the report"; fi
eq "B3  drift in a dry run exits 1" "$rc" "1"

# The regression guard: every project skipped must NOT be a clean pass.
rm -rf "$H/Documents/Projects/demo"
out="$(HOME="$H" SCHED_ROOT="$T/sched" "$REPO/bin/restamp-discipline.sh" demo 2>&1)"; rc=$?
eq "B4  a pass that reached nothing exits nonzero" "$rc" "1"
if printf '%s' "$out" | grep -q 'NOTHING WAS REACHED'; then
  ok "B4b and says so in words, not only in a code"
else bad "B4b and says so in words, not only in a code"; fi

# --- C: the population ratchet -----------------------------------------------
# WHY A RATCHET AND NOT A LIST. lib/conf.sh's header used to NAME the four
# scripts still on the raw grep; by 2026-08-11 it was wrong in both directions
# (two retired in b3fef3d, one fixed, three others never named). A list of who
# has a defect decays as fast as the code moves. So the assertion is the
# SHAPE, tree-wide. Coarse on purpose: hygiene-lint.sh and closeout-lint.sh
# expand with their own open-coded `case` blocks and pass, because this tests
# for the defect, not for one particular caller.
#
# THE POPULATION IS WHY THIS ONLY HALF-WORKED. Until 2026-08-11 the scan read
# `bin/*.sh` and `bin/lib/*.sh` and nothing else, so it was green all the while
# SIX readers in bashify/ carried the raw grep -- hf7y/realisateur#143, open
# since 2026-08-09 and describing them exactly. One of the six was
# bashify/lib/coin.sh, the ONLY door for a new verb in this ecosystem, which
# meant no new verb could be cut from any host by anyone; `bin/consigne` merged
# in #121 and reached no host's PATH for that reason (#162).
#
# A ratchet is only as good as its population, and a population that stops at a
# directory boundary is a list wearing a ratchet's clothes. bashify/ is in the
# glob now. Any future tree of scripts that reads the registry belongs here too
# -- the cost of forgetting is not a red test, it is a green one.
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
# keeps it fixed -- a registry resolving to NOTHING must be reportable as "I
# could not look", distinct from D2 ("not a registered project") and from
# success. Hook paths still exit 0 (a SessionStart hook must not block a
# session), which is why `resolve` exists to carry the honest code.
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

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
