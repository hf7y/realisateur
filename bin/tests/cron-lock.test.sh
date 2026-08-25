#!/usr/bin/env bash
#
# SUBJECT: bin/lib/cron-lock.sh -- the guard that stops a clock from stacking.
#
# THE DEFECT THIS PINS, 2026-08-25. monkey-watch.sh ran from dexter's crontab
# every ten minutes with ConnectTimeout and no lock. monkey wedged mid-auth --
# TCP up, banner sent, never authenticated -- so ConnectTimeout, which bounds
# the CONNECT and not the session, expired on nothing. Every run hung, one per
# tick, nine of them before a human looked. The two other clocks in this repo
# had the same shape and had simply not been unlucky yet.
#
# So: B is the ratchet. A script that declares a cron cadence declares
# CRON_TAG, and this suite fails if such a script does not take the lock --
# which makes the next clock arrive locked instead of arriving hopeful.
#
# HERMETICITY: no network, no ssh, no crontab. A only flocks a file in $T;
# B greps the tree.

set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
LIB="$REPO/bin/lib/cron-lock.sh"
harness_tmp

echo "cron-lock.test.sh"

section "A. a second tick leaves rather than stacking"
[ -f "$LIB" ] && ok "bin/lib/cron-lock.sh is present" \
  || { bad "bin/lib/cron-lock.sh is present" "the shared guard is gone"; summary; exit 1; }

# A runner that takes the lock, then reports whether it got to do work.
cat > "$T/tick.sh" <<'INNER'
#!/usr/bin/env bash
set -uo pipefail
. "$1"
cron_lock probe
echo "WORKED"
[ -n "${2:-}" ] && sleep "$2"
exit 0
INNER
chmod +x "$T/tick.sh"
export CRON_LOCK_FILE="$T/probe.lock"

out="$(bash "$T/tick.sh" "$LIB" 2>&1)"; r=$?
rc  "A1 an uncontended tick runs" 0 "$r"
has "A2 ...and reaches its work" "$out" "WORKED"

# Hold the lock in the background, then fire a second tick into it.
bash "$T/tick.sh" "$LIB" 3 >"$T/held.out" 2>&1 &
held=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do grep -q WORKED "$T/held.out" 2>/dev/null && break; done
out="$(bash "$T/tick.sh" "$LIB" 2>&1)"; r=$?
rc    "A3 the contended tick exits 0 -- a skipped tick is not a failure" 0 "$r"
hasnt "A4 ...and never reaches its work" "$out" "WORKED"
has   "A5 ...and says why, so the log is not silent" "$out" "already in flight"
kill "$held" 2>/dev/null; wait "$held" 2>/dev/null

has "A6 the lock path carries the uid -- 13 accounts share /tmp and one would deny twelve" \
  "$(grep -v '^#' "$LIB")" 'id -u'

section "B. every clock in this repo takes it"
found=0
for f in "$REPO"/bin/*.sh; do
  grep -q '^CRON_TAG=' "$f" || continue
  found=$((found + 1))
  n="${f##*/}"
  body="$(grep -v '^[[:space:]]*#' "$f")"
  case "$body" in
    *"lib/cron-lock.sh"*) ok "$n sources the shared guard" ;;
    *) bad "$n sources the shared guard" \
         "it declares a cron cadence (CRON_TAG) and does not source bin/lib/cron-lock.sh" ;;
  esac
  case "$body" in
    *"cron_lock "*) ok "$n calls cron_lock" ;;
    *) bad "$n calls cron_lock" \
         "it sources the guard but never takes the lock, so its runs still stack" ;;
  esac
done
[ "$found" -gt 0 ] && ok "found $found script(s) declaring a cron cadence" \
  || bad "found a script declaring a cron cadence" \
         "no bin/*.sh defines CRON_TAG -- the ratchet is scanning nothing and would pass blind"

summary
