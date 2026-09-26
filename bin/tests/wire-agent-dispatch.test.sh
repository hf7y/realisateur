#!/usr/bin/env bash
# SUBJECT: bin/wire-agent-dispatch.sh. Hermetic -- AGENT_DIR is a fixture, so it
# cannot pass because dexter's /srv/agent happens to be wired already.
set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
harness_tmp
REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
WIRE="$REPO/bin/wire-agent-dispatch.sh"
FILES="nightly.sh run-agent.sh repos Dockerfile"

echo "wire-agent-dispatch.test.sh"

fresh_copies() {  # the state dexter was in on 2026-09-26: four hand-placed copies
  rm -rf "$T/srv"; mkdir -p "$T/srv"
  for f in $FILES; do cp -p "$REPO/agent/$f" "$T/srv/$f"; done
}
wire() { AGENT_DIR="$T/srv" bash "$WIRE" "$@" 2>&1; }

section "A. the argument contract"
out="$(AGENT_DIR="$T" bash "$WIRE" --nonsense 2>&1)"; rc "an unknown flag exits 2" 2 "$?"
has "...and says what it takes" "$out" "usage:"

section "B. --check changes nothing, and says the copies are unrefreshed"
fresh_copies
out="$(wire --check)"; r=$?
rc "identical copies are a GAP (4), not a pass" 4 "$r"
has "...and it says nothing refreshes them" "$out" "refreshed by nothing"
has "...and hands over the next command" "$out" "--apply"
eq "...and nothing was linked" "$(find "$T/srv" -type l | wc -l)" "0"
eq "...and no backup directory was made" "$(ls -d "$T/srv/.pre-wire" 2>/dev/null | wc -l)" "0"

section "C. --apply links all four and keeps what it replaced"
out="$(wire --apply)"; rc "--apply exits 0" 0 "$?"
eq "four symlinks" "$(find "$T/srv" -maxdepth 1 -type l | wc -l)" "4"
eq "each points into the clone" \
   "$(readlink -f "$T/srv/run-agent.sh")" "$(readlink -f "$REPO/agent/run-agent.sh")"
eq "the replaced copies are kept" "$(ls "$T/srv/.pre-wire" | wc -l)" "4"

section "D. it is idempotent -- a second run is a no-op that reports OK"
out="$(wire --check)"; rc "an already-wired host is 0" 0 "$?"
has "...and says there is nothing to do" "$out" "nothing to do."
before="$(ls "$T/srv/.pre-wire" | wc -l)"
out="$(wire --apply)"; rc "--apply on a wired host is 0" 0 "$?"
eq "...and takes no second backup" "$(ls "$T/srv/.pre-wire" | wc -l)" "$before"

section "E. a host copy that DIFFERS is refused, never adopted"
fresh_copies
printf 'a-hand-edit-nobody-recorded\n' > "$T/srv/repos"
out="$(wire --apply)"; rc "drift exits 5" 5 "$?"
has "...and says which file" "$out" "repos: a plain copy that DIFFERS"
has "...and hands over the diff command" "$out" "diff '$T/srv/repos'"
eq "...and left the drifted file exactly as it was" "$(cat "$T/srv/repos")" "a-hand-edit-nobody-recorded"
eq "...while still wiring the three that agreed" "$(find "$T/srv" -maxdepth 1 -type l | wc -l)" "3"

section "F. a nightly holding the lock stops it -- run-agent.sh is in use"
fresh_copies
: > "$T/srv/.nightly.lock"
out="$(flock "$T/srv/.nightly.lock" -c "AGENT_DIR='$T/srv' bash '$WIRE' --apply 2>&1")"; rc "a held lock exits 1" 1 "$?"
has "...and says a pass is dispatching" "$out" "it is dispatching right now"
eq "...and nothing was touched" "$(find "$T/srv" -maxdepth 1 -type l | wc -l)" "0"

section "G. a wrong host and a wrong checkout are usage errors, not silent passes"
out="$(AGENT_DIR="$T/no-such-dir" bash "$WIRE" --check 2>&1)"; rc "no /srv/agent exits 2" 2 "$?"
has "...and says this host does not dispatch" "$out" "does not dispatch"

summary
