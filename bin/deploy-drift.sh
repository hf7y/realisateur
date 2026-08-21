#!/usr/bin/env bash
# deploy-drift.sh -- answer "is every dispatcher running the code we merged?"
#
# RUNNER: operator -- probes uid 3000-3099 accounts on a shared host over ssh
# GUARD-TEST: none -- no fixture yet for a multi-account host probe; the honest fix is to build one, not to drop the check
# GATE: none -- ssh to live accounts; a sandbox can only make it lie
#
# The account list is PROBED, not retyped: dispatcher accounts on monkey are
# uid 3000-3099 (the provisioning range), and a dispatcher is an account with
# the engine checked out. A list in this file would be one more thing to
# drift.
#
# Exit 0 = every dispatcher is on origin/main. Exit 1 = at least one is not,
# and it says which. Exit 2 = the check could not run (unreachable host, no
# accounts found) -- NOT a silent pass, because "found nothing" and "nothing
# is wrong" are the failure this whole script exists to stop conflating.
set -uo pipefail

HOST="${DRIFT_HOST:-monkey}"
ENGINE="${DRIFT_ENGINE:-Documents/Projects/scheduler}"

probe() {
  ssh -o BatchMode=yes "$HOST" "bash -s" <<EOF
set -uo pipefail
found=0
while IFS=: read -r user _ uid _; do
  [ "\$uid" -ge 3000 ] 2>/dev/null || continue
  [ "\$uid" -le 3099 ] || continue
  d="/home/\$user/$ENGINE"
  sudo -u "\$user" test -d "\$d/.git" 2>/dev/null || continue
  found=1
  sudo -u "\$user" git -C "\$d" fetch --quiet origin main 2>/dev/null
  head=\$(sudo -u "\$user" git -C "\$d" rev-parse --short HEAD 2>/dev/null || echo UNKNOWN)
  ref=\$(sudo -u "\$user" git -C "\$d" rev-parse --short origin/main 2>/dev/null || echo UNKNOWN)
  # AHEAD is the difference between "behind, and will catch up by itself" and
  # "diverged, and never will". A checkout with a local commit is CLEAN, so the
  # dirty-tree signal cannot see it, and --ff-only refuses it forever.
  ahead=\$(sudo -u "\$user" git -C "\$d" rev-list --count origin/main..HEAD 2>/dev/null || echo 0)
  dirty=\$(sudo -u "\$user" git -C "\$d" status --porcelain --untracked-files=no 2>/dev/null | tr '\n' ' ')
  # ARMED is probed, not assumed: an account can have the engine checked out
  # and dispatch nothing. Four did on the first run of this script, and
  # failing on them would make this check cry wolf every night.
  armed=idle
  sudo -u "\$user" crontab -l 2>/dev/null | grep -q 'usage-paced-runner' && armed=armed
  echo "\$user \$armed \$head \$ref \$ahead \$dirty"
done < /etc/passwd
[ "\$found" = 1 ] || exit 3
EOF
}

out="$(probe)"
rc=$?

# 3 here is PRIVATE to the heredoc and this reader; a caller sees the ladder.
if [ "$rc" = 3 ]; then
  echo "FATAL: no dispatcher accounts found on $HOST (uid 3000-3099 with $ENGINE)." >&2
  echo "  This is a BLIND result, not a clean one -- the check could not see what it audits." >&2
  exit 6
fi
if [ "$rc" != 0 ] || [ -z "$out" ]; then
  echo "FATAL: could not probe $HOST (ssh rc=$rc). Nothing was verified." >&2
  exit 6
fi

drift=0
idle_drift=0
printf '%-16s %-7s %-10s %-10s %s\n' ACCOUNT ARMED HEAD ORIGIN/MAIN STATE
while read -r user armed head ref ahead dirty; do
  state="ok"
  bad=0
  if [ "$head" = UNKNOWN ] || [ "$ref" = UNKNOWN ]; then
    state="UNREADABLE"; bad=1
  elif [ "${ahead:-0}" -gt 0 ] 2>/dev/null; then
    state="DIVERGED (${ahead} local commit(s), never pushed)"; bad=1
  elif [ "$head" != "$ref" ]; then
    state="STALE"; bad=1
  fi
  if [ -n "${dirty:-}" ]; then
    state="$state; DIRTY ($dirty)"; bad=1
  fi
  # Only an ARMED account failing is a deploy failure: an idle account
  # running stale code runs nothing. Idle drift is reported, never fatal.
  if [ "$bad" = 1 ]; then
    if [ "$armed" = armed ]; then drift=1; else idle_drift=1; fi
  fi
  printf '%-16s %-7s %-10s %-10s %s\n' "$user" "$armed" "$head" "$ref" "$state"
done <<<"$out"

echo
if [ "$idle_drift" != 0 ]; then
  echo "note: idle accounts above are provisioned but dispatch nothing -- stale there is inert."
fi
if [ "$drift" != 0 ]; then
  echo "DRIFT: an ARMED dispatcher is not running origin/main." >&2
  echo "  STALE fast-forwards on its own next tick -- if it is neither DIRTY nor DIVERGED." >&2
  echo "  DIRTY will NOT pull -- frozen until the listed file is resolved." >&2
  echo "  DIVERGED will NEVER pull and shows NO dirty file: a run committed" >&2
  echo "    locally and did not push, so --ff-only refuses it permanently." >&2
  exit 1
fi
echo "Every armed dispatcher is on origin/main."
