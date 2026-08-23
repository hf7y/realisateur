#!/usr/bin/env bash
set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
harness_tmp

SCRIPT="$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")/check-project-busy.sh"
mkdir -p "$T/sched/schedule" "$T/homes"
mk() { mkdir -p "$T/homes/$1/.local/share/scheduler-registry"; : > "$T/sched/schedule/$1.conf"; }
run() { SCHED_ROOT="$T/sched" BUSY_HOME_ROOT="$T/homes" bash "$SCRIPT" "$@" 2>&1; }
rcof() { SCHED_ROOT="$T/sched" BUSY_HOME_ROOT="$T/homes" bash "$SCRIPT" "$@" >/dev/null 2>&1; printf '%s' "$?"; }

section "A. an unregistered name never reads as free"
rc  "A1 exit 2" 2 "$(rcof no-such-project)"
has "A2 and says why" "$(run no-such-project)" "not a scheduler-registered project"

section "B. the lock is read in the PROJECT's account, not the caller's"
mk otherproj
rc  "B1 a readable project with no lock held is free (0)" 0 "$(rcof otherproj)"

mk busyproj
lock="$T/homes/busyproj/.local/share/scheduler-registry/busyproj.lock"
: > "$lock"
exec 9<>"$lock"; flock -n 9
rc  "B2 a lock held in the OWNER's account is BUSY (1), not free" 1 "$(rcof busyproj)"
has "B3 and it names the holder" "$(run busyproj)" "BUSY"
exec 9>&-

section "C. could-not-look is not not-busy"
mk sealed
chmod 000 "$T/homes/sealed/.local/share"
out="$(run sealed)"; r="$(rcof sealed)"
chmod 755 "$T/homes/sealed/.local/share"
rc  "C1 an unreadable owner home is BLIND (6), never free" 6 "$r"
has "C2 and it refuses in those words" "$out" "Refusing to answer 'free'"

summary
