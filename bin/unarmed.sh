#!/usr/bin/env bash
# unarmed.sh -- has the set of built-but-unarmed mechanisms GROWN? (#754)
#
# RUNNER: no -- DEBT, not liveness. Deliberately NOT an `ausculte` row: that
# verb answers "can I stop looking right now", and debt on a liveness panel is
# what makes the panel ignorable.
# GUARD-TEST: bin/tests/unarmed.test.sh, offline behind UNARMED_SSH
# FLOOR: bin/lib/unarmed.tsv
#
# #754: a build lands in a merge -- durable, versioned, verifiable. An arming
# lands in an issue -- prose, closeable, forgettable. PACED_HOST_MODE was built
# 2026-08-11 and armed on nothing 19 days later because the two issues holding
# its cutover were closed twelve seconds apart on a misreading.
#
set -uo pipefail

CLI_NAME='unarmed.sh'
CLI_SUMMARY='is anything built and not turned on, that was not built and not turned on yesterday?'
CLI_USAGE='  unarmed.sh            --check (default): report, write nothing'
CLI_FLAGS='--check'
CLI_POSITIONAL=none
CLI_EXITS='  0  the floor holds -- nothing new, nothing past its own window
  1  findings: the set GREW, a row REGRESSED, or a row is past its DEFAULT-AFTER
  6  BLIND: a predicate could not run, or the floor names no rows. NEVER clean.'
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/cli-guard.sh"
cli_guard "$@"

HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
. "$HERE/lib/host-check.sh"

LEDGER="${UNARMED_LEDGER:-$HERE/lib/unarmed.tsv}"
HOST="${UNARMED_HOST:-monkey}"
SCHED="${UNARMED_SCHED_ROOT:-/home/scheduler/Documents/Projects/scheduler}"
NOW="$(date -u -d "${UNARMED_TODAY:-now}" +%s 2>/dev/null)" || NOW="$(date -u +%s)"

while [ $# -gt 0 ]; do
  case "$1" in --check) ;; *) cli_die "unexpected argument: $1" ;; esac; shift
done

# ---------------------------------------------------------------------------
# ONE READING, not six. Six round trips to a host that wedges every 15-25
# minutes under load can disagree with each other about the same crontab.
# ---------------------------------------------------------------------------
FACTS=''
collect() {
  local script rc
  script='
SUDO=""; sudo -n true 2>/dev/null && SUDO="sudo -n"
[ -n "$SUDO" ] || { echo "SUDO no"; exit 0; }
echo "SUDO ok"
rc="$($SUDO crontab -l 2>/dev/null)"
count() { printf "%s\n" "$rc" | grep -c -- "$1"; }
printf "ROOT_PACED %s\n"    "$(count PACED_HOST_MODE=1)"
printf "ROOT_PROVISION %s\n" "$(count selfdev-runner-provision.sh)"
printf "ROOT_UNARMED %s\n"   "$(count unarmed.sh)"
a=0
for u in $(getent passwd | awk -F: "\$3>=3000 && \$3<=3099 {print \$1}"); do
  a=$((a + $($SUDO crontab -l -u "$u" 2>/dev/null | grep -c -- PACED_HOST_MODE=1)))
done
printf "ACCT_PACED %s\n" "$a"
n=0; f=0; s=0
for c in $($SUDO sh -c "ls '"$SCHED"'/schedule/*.conf 2>/dev/null"); do
  b="${c##*/}"; case "$b" in _*) continue ;; esac
  $SUDO test -r "$c" || continue
  n=$((n + 1))
  $SUDO grep -q "@@FRAGMENT:" "$c" && f=$((f + 1))
  $SUDO grep -q "^USES_STANDING_RULES=1" "$c" && s=$((s + 1))
done
printf "SCHED_CONFS %s\nSCHED_FRAGMENT %s\nSCHED_STANDING %s\n" "$n" "$f" "$s"'
  if on_target_host "$HOST"; then
    FACTS="$(bash -c "$script" 2>/dev/null)"; rc=$?
  else
    FACTS="$(${UNARMED_SSH:-ssh} -n -o ConnectTimeout=10 -o BatchMode=yes "$HOST" "$script" 2>/dev/null)"; rc=$?
  fi
  [ "$rc" -eq 0 ] || FACTS=''
}
collect

# fact <key> -- the value, or nothing. Nothing is BLIND; it is never zero.
fact() { printf '%s\n' "$FACTS" | awk -v k="$1" '$1 == k { print $2; found = 1 } END { exit !found }'; }
host_readable() { [ -n "$FACTS" ] && [ "$(fact SUDO)" = ok ]; }

# ---------------------------------------------------------------------------
# THE PREDICATES. One probe_<id> per floor row; each prints ARMED, UNARMED or
# BLIND and a detail. Adding a row is this function plus one line in
# bin/lib/unarmed.tsv.
# ---------------------------------------------------------------------------
probe_host_mode() {
  host_readable || { echo "BLIND cannot read $HOST's crontabs"; return; }
  local r a; r="$(fact ROOT_PACED)"; a="$(fact ACCT_PACED)"
  if [ "$r" = 1 ] && [ "$a" = 0 ]; then
    echo "ARMED one root row on $HOST carries PACED_HOST_MODE=1, no account does"
  else
    echo "UNARMED PACED_HOST_MODE=1 in $r root row(s) and $a account row(s) on $HOST; the dispatcher wants exactly 1 and 0"
  fi
}

probe_runner_cadence() {
  host_readable || { echo "BLIND cannot read $HOST's crontabs"; return; }
  local n; n="$(fact ROOT_PROVISION)"
  if [ "${n:-0}" -ge 1 ]; then
    echo "ARMED selfdev-runner-provision.sh runs on root's clock on $HOST, so a dead runner is repaired not discovered"
  else
    echo "UNARMED nothing on root's clock on $HOST invokes selfdev-runner-provision.sh"
  fi
}

probe_standing_rules() {
  local n s; n="$(fact SCHED_CONFS)"; s="$(fact SCHED_STANDING)"
  { host_readable && [ "${n:-0}" -gt 0 ]; } || { echo "BLIND could not enumerate $SCHED/schedule/*.conf on $HOST"; return; }
  if [ "$s" = "$n" ]; then
    echo "ARMED all $n project conf(s) set USES_STANDING_RULES=1"
  else
    echo "UNARMED $s of $n project conf(s) set USES_STANDING_RULES=1"
  fi
}

probe_fragment_adoption() {
  local n f; n="$(fact SCHED_CONFS)"; f="$(fact SCHED_FRAGMENT)"
  { host_readable && [ "${n:-0}" -gt 0 ]; } || { echo "BLIND could not enumerate $SCHED/schedule/*.conf on $HOST"; return; }
  if [ "$f" = "$n" ]; then
    echo "ARMED all $n project conf(s) splice with @@FRAGMENT:"
  else
    echo "UNARMED $f of $n project conf(s) use @@FRAGMENT:, which bin/scheduler-run has expanded since 2026-08-13"
  fi
}

probe_unarmed_cadence() {
  host_readable || { echo "BLIND cannot read $HOST's crontabs"; return; }
  local n; n="$(fact ROOT_UNARMED)"
  if [ "${n:-0}" -ge 1 ]; then echo "ARMED this probe runs on root's clock on $HOST"
  else echo "UNARMED this probe is on no clock, so nothing reads the floor it keeps"; fi
}

# ---------------------------------------------------------------------------
findings=0; blind=0
row() { printf '  %-9s %-18s %s\n' "$1" "$2" "$3"; }
act() { printf '            DO  %s\n' "$1"; }

echo "== unarmed --check -- $HOST, floor $LEDGER =="

[ -r "$LEDGER" ] || {
  printf '%s: BLIND -- the floor at %s is unreadable, so nothing was compared.\n' "$CLI_NAME" "$LEDGER" >&2
  exit 6
}

ids=''
while IFS=$'\t' read -r id since window floor remedy || [ -n "$id" ]; do
  case "$id" in ''|'#'*) continue ;; esac
  ids="$ids $id"
  fn="probe_${id//-/_}"
  if ! declare -F "$fn" >/dev/null; then
    row BLIND "$id" "the floor names this row and no $fn predicate exists to measure it"
    blind=1; continue
  fi
  verdict="$($fn)"; state="${verdict%% *}"; detail="${verdict#* }"

  if [ "$state" = BLIND ]; then row BLIND "$id" "$detail"; blind=1; continue; fi

  if [ "$floor" = ARMED ] && [ "$state" = UNARMED ]; then
    # A ROW THAT WENT GREEN STAYS CHECKABLE. No window: the floor recorded
    # this armed, so it was turned OFF, and that is an event, not a backlog.
    row REGRESSED "$id" "$detail"; act "$remedy"; findings=1; continue
  fi
  if [ "$state" = ARMED ]; then
    if [ "$floor" = ARMED ]; then row OK "$id" "$detail"
    else row LOWER "$id" "$detail"; act "set this row's floor to ARMED in $LEDGER -- until then a later disarming cannot read as a regression"; fi
    continue
  fi

  if [ -z "$window" ] || [ "$window" = - ]; then
    row NO-WINDOW "$id" "$detail"
    act "declare this row's window in $LEDGER (DEFAULT-AFTER shape, e.g. 30d) -- a row that blocks by omission is the closeable issue again"
    findings=1; continue
  fi
  due="$(date -u -d "$since +${window%d} days" +%s 2>/dev/null)" || due=''
  if [ -z "$due" ]; then
    row BLIND "$id" "since='$since' window='$window' is not a date this could age"
    blind=1
  elif [ "$NOW" -gt "$due" ]; then
    row EXPIRED "$id" "$detail -- built $since, past its own ${window} window"
    act "$remedy"; findings=1
  else
    row HELD "$id" "$detail -- ${window} from $since, $(( (due - NOW) / 86400 ))d left"
  fi
done < "$LEDGER"

[ -n "$ids" ] || {
  printf '%s: BLIND -- the floor at %s names no rows. Nothing was measured, which is NOT a clean result.\n' "$CLI_NAME" "$LEDGER" >&2
  exit 6
}

# THE RATCHET. A predicate with no floor row is a mechanism shipped with its
# arming deferred -- the whole class #754 names -- and it is the only thing
# here that is loud on day one.
for fn in $(declare -F | awk '{ print $3 }' | grep '^probe_'); do
  id="${fn#probe_}"; id="${id//_/-}"
  case " $ids " in *" $id "*) continue ;; esac
  row GREW "$id" "$fn measures a mechanism no row in $LEDGER declares"
  act "add an '$id' row to $LEDGER: its build date, its DEFAULT-AFTER window, ARMED or UNARMED, and the act that arms it"
  findings=1
done

echo
if [ "$findings" = 1 ]; then
  echo 'FINDINGS -- the set grew, regressed, or a row outlived its own window. Named above.'
elif [ "$blind" = 1 ]; then
  echo 'BLIND -- a predicate could not run. This is NOT "nothing new".'
else
  echo 'The floor holds -- nothing new is built and unarmed, and no row is past its window.'
fi

[ "$findings" = 1 ] && exit 1
[ "$blind" = 1 ] && exit 6
exit 0
