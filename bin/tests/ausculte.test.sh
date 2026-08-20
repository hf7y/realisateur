#!/usr/bin/env bash
# SUBJECT: bin/ausculte.sh. Hermetic -- every composed probe is a stub and
# curl/ssh/gh are stubbed failing, so this cannot pass because the fleet
# happened to be healthy. The exit ladder IS the contract, pinned rung by rung.
set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected [$3] got [$2]"; fi; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin/lib"
cp "$HERE/../ausculte.sh" "$TMP/bin/"
cp "$HERE/../lib/cli-guard.sh" "$TMP/bin/lib/"
cp "$HERE/../lib/host-check.sh" "$TMP/bin/lib/"

stub() { printf '#!/usr/bin/env bash\nprintf "%%s\\n" "%s"\nexit %s\n' "${3:-}" "$2" > "$TMP/bin/$1"; chmod +x "$TMP/bin/$1"; }

mkdir -p "$TMP/stub"
for c in curl ssh gh; do printf '#!/usr/bin/env bash\nexit 1\n' > "$TMP/stub/$c"; chmod +x "$TMP/stub/$c"; done
run() { PATH="$TMP/stub:$PATH" bash "$TMP/bin/ausculte.sh" "$@" 2>&1; }

echo "ausculte contract"

stub decision-rot.sh 0
run rot >/dev/null; check "a clean probe exits 0" "$?" "0"

stub decision-rot.sh 1 "answered and still open"
run rot >/dev/null; check "a probe reporting rot is DOWN (5)" "$?" "5"

stub decision-rot.sh 2 "usage"
out="$(run rot)"; check "a usage error from a probe is BLIND, not DOWN" "$?" "6"
case "$out" in *"fix ausculte"*) ok "...and it says the fault is ausculte's" ;;
  *) bad "usage error names itself" "got: $out" ;; esac

rm -f "$TMP/bin/decision-rot.sh"
out="$(run rot)"; check "a missing probe is BLIND (6), never OK" "$?" "6"
case "$out" in *"NOT \"all clear\""*) ok "...and the summary refuses to read as all-clear" ;;
  *) bad "blind summary" "got: $out" ;; esac

stub decision-rot.sh 1 "rot found"
stub silence-audit.sh 2 "usage"
run rot silence >/dev/null
check "one probe DOWN and one BLIND exits DOWN" "$?" "5"

run nosuchprobe >/dev/null; check "an unknown probe is a usage error (2)" "$?" "2"

out="$(SELFDEV_LOCAL_HOSTNAME=elsewhere run arming)"; rc=$?
check "arming (remote) is BLIND when ssh can't reach monkey" "$rc" "6"
case "$out" in *"did not answer"*) ok "...and it names why" ;;
  *) bad "arming BLIND detail" "got: $out" ;; esac

printf '#!/usr/bin/env bash\necho called >> "%s/ssh_called"\nexit 255\n' "$TMP" > "$TMP/stub/ssh"
chmod +x "$TMP/stub/ssh"
printf '#!/usr/bin/env bash\nprintf "acct1 armed\\n"\nexit 0\n' > "$TMP/stub/sudo"
chmod +x "$TMP/stub/sudo"
out="$(SELFDEV_LOCAL_HOSTNAME=monkey run arming)"; rc=$?
check "arming (local) reads OK straight from the local collector" "$rc" "0"
[ -f "$TMP/ssh_called" ] \
  && bad "a local arming probe never shells out to ssh" "ssh was invoked" \
  || ok "a local arming probe never shells out to ssh"

echo
summary
