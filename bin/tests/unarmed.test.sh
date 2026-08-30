#!/usr/bin/env bash
set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/unarmed.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

harness_tmp
echo "unarmed.test.sh"

cat > "$T/ssh" <<'EOF'
#!/usr/bin/env bash
cat "$FACTS_FILE"
EOF
chmod +x "$T/ssh"

armed() {
  cat > "$1" <<'EOF'
SUDO ok
ROOT_PACED 1
ROOT_PROVISION 1
ROOT_REGISTRY 1
ROOT_UNARMED 1
ACCT_PACED 0
SCHED_CONFS 18
SCHED_FRAGMENT 18
SCHED_STANDING 18
ROOT_LIVENESS 1
VAULT_MODE 0700
DRAIN_CRON 1
DRAIN_BIN 1
BUILD_LIBEXEC 2
FD_ANCHOR 200
FD_PROSE 200
APMS_PROSE 200
EOF
}
unarmed() {
  cat > "$1" <<'EOF'
SUDO ok
ROOT_PACED 0
ROOT_PROVISION 0
ROOT_REGISTRY 0
ROOT_UNARMED 0
ACCT_PACED 0
SCHED_CONFS 18
SCHED_FRAGMENT 2
SCHED_STANDING 18
ROOT_LIVENESS 0
VAULT_MODE 2770
DRAIN_CRON 1
DRAIN_BIN 0
BUILD_LIBEXEC 0
FD_ANCHOR 200
FD_PROSE 404
APMS_PROSE 404
EOF
}
run() {  # run <ledger> <today> -- OUT/RC
  OUT="$(UNARMED_LEDGER="$1" UNARMED_TODAY="$2" UNARMED_HOST=fixture-host \
         UNARMED_SSH="$T/ssh" FACTS_FILE="$T/facts" "$SCRIPT" --check 2>&1)"; RC=$?
}

# mkledger <file> <row>... -- the rows under test plus a wide-windowed filler
# for every OTHER predicate; without them the growth check correctly fires on
# all of those and drowns the verdict actually under test.
mkledger() {
  local f="$1" r id fn given=' '; shift
  : > "$f"
  for r in "$@"; do printf '%s\n' "$r" >> "$f"; given="$given${r%%	*} "; done
  for fn in $(grep -oE '^probe_[a-z_]+\(\)' "$SCRIPT"); do
    id="${fn%()}"; id="${id#probe_}"; id="${id//_/-}"
    case "$given" in *" $id "*) continue ;; esac
    printf '%s\t2026-08-11\t3650d\tUNARMED\tnot under test\n' "$id" >> "$f"
  done
}

section "A. the argument contract"
"$SCRIPT" --not-a-real-flag >/dev/null 2>&1; rc "A1 unknown flag exits 2" 2 $?
"$SCRIPT" --help >/dev/null 2>&1;            rc "A2 --help exits 0" 0 $?
O="$("$SCRIPT" --help 2>&1)"
has "A3 --help documents the BLIND exit" "$O" "BLIND"
has "A4 --help says --check writes nothing" "$O" "report, write nothing"

section "B. a row that is ARMED reads green, and stays checkable"
armed "$T/facts"
mkledger "$T/L" "$(printf 'host-mode\t2026-08-11\t30d\tARMED\tthe crontab line')"
run "$T/L" 2026-08-30
has "B1 an armed row reads OK" "$OUT" "OK        host-mode"
rc  "B2 and the probe exits 0" 0 $RC
has "B3 and says the floor holds" "$OUT" "The floor holds"

unarmed "$T/facts"
run "$T/L" 2026-08-30
has "B4 disarming a row recorded ARMED is a REGRESSION" "$OUT" "REGRESSED host-mode"
has "B5 and it prints the act that clears it" "$OUT" "DO  the crontab line"
rc  "B6 and the probe exits 1" 1 $RC

section "C. an UNARMED row is silent inside its own window and red past it"
unarmed "$T/facts"
mkledger "$T/L" "$(printf 'host-mode\t2026-08-11\t30d\tUNARMED\tsudo crontab -e on monkey, add the PACED_HOST_MODE=1 row')"
run "$T/L" 2026-08-30
has "C1 inside the window the row is HELD, not red" "$OUT" "HELD      host-mode"
has "C2 and it says how long is left" "$OUT" "11d left"
rc  "C3 and the probe exits 0 -- a persisting backlog is not an alarm" 0 $RC
hasnt "C4 nothing is DONE to a held row" "$OUT" "DO  sudo crontab -e"

run "$T/L" 2026-09-30
has "C5 past its own window the row EXPIRES" "$OUT" "EXPIRED   host-mode"
has "C6 and names the act that clears it" "$OUT" "DO  sudo crontab -e on monkey, add the PACED_HOST_MODE=1 row"
has "C7 and says which window it outlived" "$OUT" "past its own 30d window"
rc  "C8 and the probe exits 1" 1 $RC

section "D. the ratchet: red when the set GROWS, never when it merely persists"
grep -v '^unarmed-cadence	' "$T/L" > "$T/Lgrew"
run "$T/Lgrew" 2026-08-30
has "D1 a predicate with no floor row is GREW" "$OUT" "GREW      unarmed-cadence"
has "D2 and the remedy is to declare it" "$OUT" "add an 'unarmed-cadence' row"
rc  "D3 growth is a finding on day one, with no window to wait out" 1 $RC

section "E. a row that blocks by omission is a finding, not a permanent alarm"
mkledger "$T/L2" "$(printf 'host-mode\t2026-08-11\t-\tUNARMED\tthe crontab line')"
run "$T/L2" 2026-08-30
has "E1 an UNARMED row declaring no window is NO-WINDOW" "$OUT" "NO-WINDOW host-mode"
has "E2 and the remedy is to declare one" "$OUT" "DEFAULT-AFTER shape"
rc  "E3 and it is a finding" 1 $RC

section "F. BLIND, never clean"
mkledger "$T/L3" "$(printf 'host-mode\t2026-08-11\t30d\tUNARMED\tthe crontab line')"
printf 'SUDO no\n' > "$T/facts"
run "$T/L3" 2026-08-30
has "F1 a host that cannot be read is BLIND, not armed" "$OUT" "BLIND     host-mode"
rc  "F2 and the probe exits 6" 6 $RC
has "F3 and refuses to call it clean" "$OUT" 'NOT "nothing new"'

cat > "$T/facts" <<'EOF'
SUDO ok
ROOT_PACED 0
ROOT_PROVISION 0
ROOT_REGISTRY 0
ROOT_UNARMED 0
ACCT_PACED 0
SCHED_CONFS 0
SCHED_FRAGMENT 0
SCHED_STANDING 0
ROOT_LIVENESS 0
VAULT_MODE 2770
DRAIN_CRON 1
DRAIN_BIN 0
BUILD_LIBEXEC 0
FD_ANCHOR 200
FD_PROSE 404
APMS_PROSE 404
EOF
mkledger "$T/L4" "$(printf 'fragment-adoption\t2026-08-13\t30d\tUNARMED\tconvert the confs')"
run "$T/L4" 2026-08-30
has "F4 zero confs is BLIND -- 0 of 0 adopted must never read as adopted" "$OUT" "BLIND     fragment-adoption"
rc  "F5 and exits 6" 6 $RC

mkledger "$T/L5" "$(printf 'ghost-row\t2026-08-13\t30d\tUNARMED\tsomething')"
run "$T/L5" 2026-08-30
has "F6 a floor row with no predicate is BLIND, not green" "$OUT" "BLIND     ghost-row"
rc  "F7 and exits 6" 6 $RC

section "G. a floor with no rows measured nothing"
printf '# only a comment\n' > "$T/L6"
run "$T/L6" 2026-08-30
rc  "G1 zero rows exits 6, not 0" 6 $RC
has "G2 and says nothing was measured" "$OUT" "names no rows"
has "G3 and that this is not clean" "$OUT" "NOT a clean result"

run "$T/does-not-exist" 2026-08-30
rc  "G4 an unreadable floor exits 6" 6 $RC
has "G5 and says nothing was compared" "$OUT" "nothing was compared"

section "H. the front-door probe reads three values, not two"
fdfacts() { armed "$T/facts"; sed -i "s/^FD_ANCHOR .*/FD_ANCHOR $1/; s/^FD_PROSE .*/FD_PROSE $2/" "$T/facts"; }
mkledger "$T/L7" "$(printf 'front-door-guard\t2026-08-17\t7d\tUNARMED\tadd the workflow to front-door')"

fdfacts 200 404
run "$T/L7" 2026-08-30
has "H1 no prose.yml on front-door is UNARMED, and past its own window" "$OUT" "EXPIRED   front-door-guard"
has "H2 and it names the act that clears it" "$OUT" "DO  add the workflow to front-door"
rc  "H3 and it is a finding" 1 $RC

fdfacts 200 200
run "$T/L7" 2026-08-30
has "H4 a prose.yml on front-door reads ARMED" "$OUT" "LOWER     front-door-guard"
hasnt "H5 and an armed row is not red" "$OUT" "EXPIRED   front-door-guard"

fdfacts 404 404
run "$T/L7" 2026-08-30
has "H6 a front-door it cannot read at all is BLIND, never UNARMED" "$OUT" "BLIND     front-door-guard"
rc  "H7 and BLIND exits 6, never 0" 6 $RC

fdfacts 200 500
run "$T/L7" 2026-08-30
has "H8 an HTTP error reading prose.yml is BLIND, never ARMED" "$OUT" "BLIND     front-door-guard"
rc  "H9 and it exits 6" 6 $RC

section "I. the shipped floor is well-formed"
LEDGER="$ROOT/lib/unarmed.tsv"
n=0; while IFS=$'\t' read -r id since window floor remedy || [ -n "$id" ]; do
  case "$id" in ''|'#'*) continue ;; esac
  n=$((n + 1))
  case "$id" in *_*) bad "I: id '$id' uses an underscore; the growth check cannot map it back" ;; esac
  case "$floor" in ARMED|UNARMED) ;; *) bad "I: '$id' floor is '$floor', not ARMED or UNARMED" ;; esac
  [ -n "$remedy" ] || bad "I: '$id' names no act that would clear it"
  grep -q "^probe_${id//-/_}()" "$SCRIPT" || bad "I: '$id' has no probe_${id//-/_} predicate"
  if [ "$floor" = UNARMED ]; then
    case "$window" in *d) ;; *) bad "I: unarmed row '$id' declares no DEFAULT-AFTER window" ;; esac
  fi
done < "$LEDGER"
[ "$n" -gt 0 ] && ok "I1 the shipped floor names $n row(s), each with a predicate, a floor and a remedy" \
               || bad "I1 the shipped floor is empty"

section "J. it is declared, so it reaches a host by a named channel"
. "$ROOT/lib/propagation-set.sh"
ch="$(prop_channel unarmed.sh 2>/dev/null)" || ch=""
eq "J1 prop_channel classifies unarmed.sh" "$ch" "local"

section "K. a fact line that reads nothing blinds its own row, not the floor (#815)"
mkdir -p "$T/stub" "$T/pin/current/verbs/libexec"
touch "$T/pin/current/verbs/libexec/unarmed.sh" "$T/pin/current/verbs/libexec/vault-spool-drain.sh"
printf '#!/usr/bin/env bash\n[ "${1:-}" = -n ] && shift\nexec "$@"\n' > "$T/stub/sudo"
printf '#!/usr/bin/env bash\nexit 1\n'                                 > "$T/stub/crontab"
printf '#!/usr/bin/env bash\nprintf 200\n'                             > "$T/stub/curl"
printf '#!/usr/bin/env bash\nexec bash -c "${!#}"\n'                   > "$T/ssh-run"
printf '#!/usr/bin/env bash\nexit 255\n'                               > "$T/ssh-dead"
chmod +x "$T"/stub/* "$T/ssh-run" "$T/ssh-dead"
mkledger "$T/L8"
runreal() {  # runreal <ssh> <build-root> -- RUNS the generated script offline, moving only the pin it reads last. A-J feed collect() a CANNED answer, so none of them can see its exit status.
  OUT="$(UNARMED_LEDGER="$T/L8" UNARMED_TODAY=2026-08-30 UNARMED_HOST=fixture-host \
         UNARMED_SCHED_ROOT="$T/no-sched" VERB_HOST_BUILD_ROOT="$2" \
         PATH="$T/stub:$PATH" UNARMED_SSH="$1" "$SCRIPT" --check 2>&1)"; RC=$?
}

runreal "$T/ssh-run" "$T/no-such-root"
has "K1 an absent build pin does not blind the rows it never touched" "$OUT" "HELD      host-mode"
has "K2 and the row that truly cannot tell still reads BLIND" "$OUT" "BLIND     libexec-payload"

runreal "$T/ssh-run" "$T/pin"
has "K3 a present build pin still yields its fact -- the guard was not deleted" "$OUT" "LOWER     libexec-payload"

runreal "$T/ssh-dead" "$T/pin"
has "K4 a transport that fails blinds every row, which is a different event" "$OUT" "BLIND     host-mode"
rc  "K5 and that exits 6" 6 $RC

echo
summary
